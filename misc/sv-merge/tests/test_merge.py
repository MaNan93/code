import contextlib
import io
import os
from pathlib import Path
import tempfile
import unittest

from sv_merge.cli import main
from sv_merge.merger import Merger
from sv_merge.analyzer import DependencyAnalyzer


class MergeTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        self.output = self.root / 'out.sv'

    def write(self, name, text):
        path = self.root / name
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(text)
        return str(path)

    def merge(self, paths, **kwargs):
        Merger(paths, str(self.output), verbose=False, **kwargs).run()
        return self.output.read_text()

    def cli(self, *args):
        with contextlib.redirect_stdout(io.StringIO()), contextlib.redirect_stderr(io.StringIO()):
            return main(list(args))

    def test_includes_resolve_locally_and_remain_in_place(self):
        a = self.write('a/top.sv', '`define MODE 1\n`include "defs.svh"\n`undef MODE\n')
        b = self.write('b/top.sv', '`include "defs.svh"\n')
        self.write('a/defs.svh', 'local_a\n')
        self.write('b/defs.svh', 'local_b\n')
        result = self.merge([a, b])
        self.assertLess(result.index('MODE 1'), result.index('local_a'))
        self.assertLess(result.index('local_a'), result.index('undef MODE'))
        self.assertIn('local_b', result)
        self.assertNotIn('`include', result)

    def test_incdir_and_unguarded_repeat(self):
        src = self.write('top.sv', '`include "x.svh"\n`include "x.svh"\n')
        self.write('inc/x.svh', 'REPEAT\n')
        result = self.merge([src], incdirs=[str(self.root / 'inc')])
        self.assertEqual(result.count('REPEAT'), 2)

    def test_conditional_first_include_is_not_globally_deduplicated(self):
        src = self.write('top.sv', '`ifdef FEATURE\n`include "x.svh"\n`endif\n`include "x.svh"\n')
        self.write('x.svh', '`ifndef X\n`define X\nBODY\n`endif\n')
        result = self.merge([src])
        self.assertEqual(result.count('BODY'), 2)

    def test_known_guard_and_undef(self):
        src = self.write('top.sv', '`include "x.svh"\n`include "x.svh"\n`undef X\n`include "x.svh"\n')
        self.write('x.svh', '`ifndef X\n`define X\nBODY\n`endif\n')
        self.assertEqual(self.merge([src]).count('BODY'), 2)

    def test_outer_guard_else_is_not_skipped(self):
        src = self.write('top.sv', '`include "x.svh"\n`include "x.svh"\n')
        self.write('x.svh', '`ifndef X\n`define X\nA\n`else\nB\n`endif\n')
        self.assertEqual(self.merge([src]).count('`else'), 2)

    def test_comment_includes_ignored_and_trailing_comments_preserved(self):
        src = self.write('top.sv', '/*\n`include "missing"\n*/\n`include "x.svh" /* tail\nend */\n')
        self.write('x.svh', 'BODY\n')
        result = self.merge([src])
        self.assertIn('/* tail\nend */', result)
        self.assertIn('BODY', result)

    def test_missing_include_is_atomic(self):
        self.output.write_text('OLD')
        src = self.write('top.sv', '`include "missing"\n')
        with self.assertRaises(ValueError):
            self.merge([src])
        self.assertEqual(self.output.read_text(), 'OLD')
        self.assertFalse(list(self.root.glob('.sv-merge-*')))

    def test_missing_source_is_atomic(self):
        self.output.write_text('OLD')
        with self.assertRaises(OSError):
            self.merge([str(self.root / 'missing')])
        self.assertEqual(self.output.read_text(), 'OLD')

    def test_output_cannot_alias_root_or_included_source(self):
        src = self.write('top.sv', 'SOURCE\n')
        os.link(src, str(self.output))
        with self.assertRaises(ValueError):
            self.merge([src])
        self.assertEqual(Path(src).read_text(), 'SOURCE\n')
        self.output.unlink()
        self.output.write_text('HEADER\n')
        Path(src).write_text('`include "out.sv"\n')
        with self.assertRaises(ValueError):
            self.merge([src])
        self.assertEqual(self.output.read_text(), 'HEADER\n')

    def test_recursive_include_and_filelist_fail(self):
        src = self.write('top.sv', '`include "top.sv"\n')
        with self.assertRaises(ValueError):
            self.merge([src])
        flist = self.write('recursive.f', '-F recursive.f\n')
        self.assertEqual(self.cli('-F', flist, '-o', str(self.output)), 1)

    def test_filelist_defines_and_original_order(self):
        self.write('b.sv', '`default_nettype none\nmodule b; endmodule\n')
        self.write('a.svh', '`define A 1\n')
        flist = self.write('files.f', '+define+FEATURE+WIDTH=8\nb.sv\na.svh\n')
        self.assertEqual(self.cli('-F', flist, '-o', str(self.output)), 0)
        result = self.output.read_text()
        self.assertIn('`define WIDTH 8\n', result)
        self.assertIn('`define FEATURE ', result)
        self.assertLess(result.index('module b'), result.index('`define A'))
        self.assertNotIn('`default_nettype wire', result)

    def test_keep_includes_and_source_locations(self):
        src = self.write('top.sv', '`include `HEADER\n')
        with self.assertRaises(ValueError):
            self.merge([src])
        result = self.merge([src], neutralize=False, line_directives=True)
        self.assertIn('`include `HEADER', result)
        self.assertIn('`line 1 "', result)

    def test_missing_filelist_returns_failure(self):
        self.assertEqual(self.cli('-F', str(self.root / 'missing'), '-o', str(self.output)), 1)
        self.assertFalse(self.output.exists())

    def test_output_cannot_overwrite_filelist(self):
        self.write('a.sv', 'module a; endmodule\n')
        flist = self.write('files.f', 'a.sv\n')
        self.assertEqual(self.cli('-F', flist, '-o', flist), 1)
        self.assertEqual(Path(flist).read_text(), 'a.sv\n')

    def test_interleaved_filelist_flags_keep_order(self):
        self.write('a.sv', 'FIRST\n')
        self.write('b.sv', 'SECOND\n')
        a = self.write('a.f', 'a.sv\n')
        b = self.write('b.f', str(self.root / 'b.sv') + '\n')
        self.assertEqual(self.cli('-F', a, '-f', b, '-o', str(self.output)), 0)
        result = self.output.read_text()
        self.assertLess(result.index('FIRST'), result.index('SECOND'))

    def test_nested_filelists_incdir_quotes_and_defines(self):
        self.write('sub/top.sv', '`include "x.svh"\n')
        self.write('sub/inc dir/x.svh', 'BODY\n')
        self.write('sub/sub.f', '+incdir+"inc dir"\n+define+LABEL="a+b c"\ntop.sv\n')
        flist = self.write('files.f', '-F "sub/sub.f"\n')
        self.assertEqual(self.cli('-F', flist, '-o', str(self.output)), 0)
        self.assertIn('`define LABEL "a+b c"', self.output.read_text())
        self.assertIn('BODY', self.output.read_text())

    def test_repeated_filelist_is_not_silently_dropped(self):
        self.write('a.sv', 'REPEAT\n')
        self.write('sub.f', 'a.sv\n')
        flist = self.write('files.f', '-F sub.f\n-F sub.f\n')
        self.assertEqual(self.cli('-F', flist, '-o', str(self.output)), 0)
        self.assertEqual(self.output.read_text().count('REPEAT'), 2)

    def test_missing_nested_option_argument_fails(self):
        flist = self.write('files.f', '-F\n')
        self.assertEqual(self.cli('-F', flist, '-o', str(self.output)), 1)

    def test_package_sort_is_stable_and_understands_qualified_types(self):
        a = self.write('a.sv', 'package a;\n b::t x;\nendpackage\n')
        b = self.write('b.sv', 'package b; endpackage\n')
        c = self.write('c.sv', 'package c;\n b::t x;\nendpackage\n')
        analyzer = DependencyAnalyzer([a, c, b])
        analyzer.analyze()
        self.assertEqual(analyzer.topological_sort(), [b, a, c])

    def test_duplicate_packages_and_dependency_cycles_fail(self):
        a = self.write('a.sv', 'package a;\n b::t x;\nendpackage\n')
        b = self.write('b.sv', 'package b;\n a::t x;\nendpackage\n')
        analyzer = DependencyAnalyzer([a, b])
        analyzer.analyze()
        with self.assertRaises(ValueError):
            analyzer.topological_sort()
        Path(b).write_text('package a; endpackage\n')
        with self.assertRaises(ValueError):
            DependencyAnalyzer([a, b]).analyze()


if __name__ == '__main__':
    unittest.main()
