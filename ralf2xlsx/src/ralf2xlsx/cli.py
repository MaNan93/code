#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
ralf2xlsx.py -- Synopsys RALF (Register Abstraction Layer File) -> Excel 寄存器表

    ralf2xlsx top.ralf -t <topname> -o regs.xlsx [-I incdir]...
    ralf2xlsx a.ralf b.ralf c.ralf -o outdir/   # 批量, 各自独立转换

Version History
---------------
v2.8
  - Move Summary, BlockTree and Warnings out of Excel and print them to the terminal.
  - Keep Excel focused on register data and per-block worksheets.

v2.7
  - Add BlockTree worksheet showing the instantiated system/block hierarchy.
  - Show both block instance path and block definition name (e.g. a=b => Definition a, Instance b).
  - Collapse multi-domain interfaces under one block-tree node.

v2.6
  - Generate one worksheet per instantiated block by default.
  - Only blocks reachable from the selected system/top are emitted.
  - Multi-domain blocks stay in one worksheet; Domain distinguishes interfaces.
  - Add --no-sheet-per-block to disable per-block worksheets; keep -s for compatibility.

v2.5
  - Accept multiple .ralf files on the command line. Each file is parsed
    and elaborated independently (its own definition table, own top
    selection) and gets its own .xlsx; -o/--csv are treated as an output
    directory when more than one .ralf is given.

v2.4
  - Fix Tcl '#' comment lexing: '#' starts a comment only at command start;
    literal '#' inside words/doc text no longer truncates the line or loses braces.
  - Catch XLSX/CSV output errors and return a clean tool error instead of traceback.

v2.3
  - Fix field access-mode validation: UVM and VMM RALF use different tables
    (only rw/ro/wo/w1/w1c/rc overlap). Accept the union by default; --flavor
    selects a single dialect.
  - Fix mixed-language backdoor paths: keep ONE path chain and pick the
    separator per appended segment, so a Verilog hierarchy ending in a VHDL
    signal yields a complete path instead of two halves plus a bogus warning.
    The either/or rule is enforced per construct, as the UG states.
  - Fix O(n^2) xlsx writing: assign merged ranges in bulk instead of calling
    openpyxl merge_cells() once per range.
  - Report property statements at global scope as a warning instead of an
    AttributeError traceback; main() no longer lets exceptions escape.
  - Accept "hdl_path = (...)" / "vhdl_path = (...)" with spaces around '='.

v2.2
  - Support static virtual-register address elaboration (memory/offset/increment).
  - Propagate regfile read/write restrictions to contained registers.
  - Build hierarchical Verilog HDL paths and add local/backdoor path columns.
  - Support VHDL vhdl_path hierarchy.
  - Add Shared/Domain-oriented review data and access-mode validation.
  - Ignore user_code safely; improve doc HTML-to-text conversion.
  - Preserve v2.1 fixes: block.domain selection, left_to_right gaps, change_reset,
    and single-interface bytes/endian handling.

v2.1
  - Fix block.domain elaboration.
  - Fix left_to_right field layout with explicit gaps.
  - Support change_reset overrides.
  - Fix single-interface bytes/endian handling.

v2.0
  - Lexer/parser/elaborator based RALF -> XLSX implementation.

支持的 RALF 构件 (对齐 RAL User Guide / Appendix A):
    field / register / regfile / memory / virtual register / block / system / domain
    属性: bits bytes access reset hard_reset soft_reset volatile enum constraint doc
          attributes endian left_to_right shared cover size initial coverpoint cross
          change_reset hdl_path vhdl_path user_code
    Tcl : # 注释, set / incr, source, [expr ...], 简单 for / if, 反斜杠续行

命令按 Tcl 语义在换行/分号处结束, 所以 "source x.ralf" / "bits 8" 这种不写分号的
写法也能正确解析。

输出 sheet:
    Summary      -- 源文件/顶层/统计, 各 block 基地址
    RegisterMap  -- 寄存器 x 字段 主表 (一个字段一行, 寄存器列纵向合并)
    Registers    -- 寄存器级汇总 (一个寄存器一行)
    Memories     -- 存储器
    Enums        -- 字段枚举值
    Warnings     -- 解析/展开过程中的所有告警
    (-s 时额外每个 block 一张 sheet)
"""

import argparse
import datetime
import html
import math
import os
import re
import sys
from collections import OrderedDict

VERSION = '2.8'

# ============================================================================
# 词法分析
# ============================================================================

SPECIAL = set('{};')


class Tok(object):
    __slots__ = ('kind', 'val', 'line', 'file')

    def __init__(self, kind, val, line, file):
        self.kind = kind
        self.val = val
        self.line = line                 # 逻辑行号 (反斜杠续行不计新行)
        self.file = file

    def __repr__(self):
        return '%s(%r)@%s:%d' % (self.kind, self.val, os.path.basename(self.file), self.line)


def tokenize(text, fname):
    """把 RALF 文本切成 token: '{' '}' ';' / word / paren

    行号是 *逻辑* 行号: 反斜杠续行不算换行, 这样上层可以按 Tcl 语义
    "一条命令到行尾结束" 来切分。

    Tcl 的 '#' 只有位于一条 command 的起始位置时才开始注释。比如
    "doc {status #1 register}" 里的 '#' 是普通文本，不能吞掉后面的 '}'。
    """
    toks = []
    i, n, line = 0, len(text), 1
    cmd_start = True
    while i < n:
        c = text[i]
        if c == '\\' and i + 1 < n and text[i + 1] == '\n':   # 续行: 不结束 command
            i += 2
            continue
        if c == '\n':
            line += 1
            i += 1
            cmd_start = True
            continue
        if c in ' \t\r':
            i += 1
            continue
        if c == '#' and cmd_start:                     # Tcl comment: command start only
            j = text.find('\n', i)
            i = n if j < 0 else j
            continue
        if c in SPECIAL:
            toks.append(Tok(c, c, line, fname))
            i += 1
            if c in (';', '{'):
                cmd_start = True
            elif c == '}':
                cmd_start = False
            continue
        if c == '"':                                   # 带引号字符串
            j, buf = i + 1, []
            while j < n and text[j] != '"':
                if text[j] == '\\' and j + 1 < n:
                    buf.append(text[j + 1])
                    j += 2
                    continue
                if text[j] == '\n':
                    line += 1
                buf.append(text[j])
                j += 1
            toks.append(Tok('word', ''.join(buf), line, fname))
            i = j + 1
            cmd_start = False
            continue
        if c == '(':                                   # (hdl_path) 整体作为一个 token
            depth, j = 0, i
            while j < n:
                if text[j] == '(':
                    depth += 1
                elif text[j] == ')':
                    depth -= 1
                    if depth == 0:
                        break
                elif text[j] == '\n':
                    line += 1
                j += 1
            toks.append(Tok('paren', text[i:j + 1], line, fname))
            i = j + 1
            cmd_start = False
            continue
        # 裸 word: 读到空白/特殊字符; '[' ... ']' 内部允许空白 (数组下标 / [expr ..])
        j = i
        while j < n and text[j] not in ' \t\r\n{};("':
            if text[j] == '\\' and j + 1 < n and text[j + 1] == '\n':
                break
            if text[j] == '[':
                depth = 0
                while j < n:
                    if text[j] == '[':
                        depth += 1
                    elif text[j] == ']':
                        depth -= 1
                        if depth == 0:
                            j += 1
                            break
                    elif text[j] == '\n':
                        line += 1
                    j += 1
                continue
            j += 1
        toks.append(Tok('word', text[i:j], line, fname))
        i = j
        cmd_start = False
    return toks


# ============================================================================
# 数值 / 文本辅助
# ============================================================================

BASE = {'b': 2, 'o': 8, 'd': 10, 'h': 16}
VNUM = re.compile(r"^(?P<w>\d+)?'\s*[sS]?(?P<b>[bodhBODH])(?P<v>[0-9a-fA-FxXzZ?_]+)$")


def parse_num(s):
    """解析 RALF 数字, 返回 (value|None, width|None)

    支持 8'hFF / 'h1f / 0x10 / 0b1010 / 0o17 / 十进制 / 1Fh
    """
    if s is None:
        return None, None
    s = str(s).strip().replace('_', '')
    if not s or s.lower() == 'none':
        return None, None
    m = VNUM.match(s)
    if m:
        w = int(m.group('w')) if m.group('w') else None
        v = re.sub(r'[xXzZ?]', '0', m.group('v'))
        try:
            return int(v, BASE[m.group('b').lower()]), w
        except ValueError:
            return None, w
    for pat, b in ((r'^[+-]?0[xX][0-9a-fA-F]+$', 16), (r'^[+-]?0[bB][01]+$', 2),
                   (r'^[+-]?0[oO][0-7]+$', 8)):
        if re.match(pat, s):
            return int(s, b), None
    if re.match(r'^[+-]?\d+$', s):
        return int(s, 10), None
    if re.match(r'^[0-9a-fA-F]+[hH]$', s):
        return int(s[:-1], 16), None
    return None, None


SIZE_MUL = {'k': 1024, 'K': 1024, 'M': 1 << 20, 'm': 1 << 20, 'G': 1 << 30, 'g': 1 << 30}


def parse_size(s):
    """memory size: 64k / 2M / 1024"""
    s = str(s).strip().rstrip(';')
    mul = 1
    if s and s[-1] in SIZE_MUL:
        mul = SIZE_MUL[s[-1]]
        s = s[:-1]
    v, _ = parse_num(s)
    return None if v is None else v * mul


def hexs(v, bits=32):
    if v is None:
        return ''
    return '0x%0*X' % (max(1, (bits + 3) // 4), v)


def norm_doc(s):
    """doc {} 里允许 HTML: 去标签、反转义并压成一行纯文本。"""
    text = html.unescape(s or '')
    text = re.sub(r'(?is)<br\s*/?>|</p\s*>|</div\s*>|</li\s*>', ' ', text)
    text = re.sub(r'(?is)<[^>]+>', ' ', text)
    return ' '.join(text.split())


# RALF 两套方言的 field access 表并不相同, 交集只有 rw/ro/wo/w1/w1c/rc。
# UVM: UVM RAL Generator User Guide, Appendix A "field"
UVM_ACCESS = set((
    'rw ro wo w1 w1c rc rs wrc wrs wc ws wsrc wcrs w1s w1t w0c w0s w0t '
    'w1src w1crs w0src w0crs woc wos wo1'
).split())
# VMM: VMM RAL User Guide, Appendix A "field"
VMM_ACCESS = set((
    'rw ro wo w1 ru w1c rc a1 a0 other user0 user1 user2 user3 dc'
).split())
ACCESS_SETS = {'uvm': UVM_ACCESS, 'vmm': VMM_ACCESS, 'auto': UVM_ACCESS | VMM_ACCESS}


# ============================================================================
# 数据模型
# ============================================================================

class Field(object):
    def __init__(self, name):
        self.name = name
        self.bits = None                 # 位宽 (默认 1)
        self.access = None               # rw/ro/...
        self.reset = None                # (value, raw)
        self.soft_reset = None           # (value, raw)
        self.volatile = ''
        self.enum = []                   # [(name, value)]
        self.constraints = OrderedDict()
        self.doc = ''
        self.cover = []
        self.attributes = OrderedDict()
        self.hdl = ''
        self.vhdl = ''


class Register(object):
    def __init__(self, name):
        self.name = name
        self.bytes = None
        self.left_to_right = False
        self.shared = None
        self.doc = ''
        self.cover = []
        self.attributes = OrderedDict()
        self.constraints = OrderedDict()
        self.insts = []                  # field 实例 (Inst)
        self.hdl = ''
        self.vhdl = ''


class RegFile(object):
    def __init__(self, name):
        self.name = name
        self.shared = None
        self.doc = ''
        self.constraints = OrderedDict()
        self.change_resets = []          # [(target_path, (value, raw))]
        self.insts = []                  # register 实例
        self.hdl = ''
        self.vhdl = ''


class Memory(object):
    def __init__(self, name):
        self.name = name
        self.bits = None
        self.size = None
        self.access = 'rw'
        self.initial = None
        self.shared = None
        self.doc = ''
        self.attributes = OrderedDict()
        self.hdl = ''
        self.vhdl = ''


class VReg(object):
    def __init__(self, name):
        self.name = name
        self.bytes = None
        self.left_to_right = False
        self.doc = ''
        self.insts = []
        self.hdl = ''
        self.vhdl = ''


class Map(object):
    """block/system 的一个物理接口 (domain); 单接口时 name=''"""

    def __init__(self, name=''):
        self.name = name
        self.bytes = None                # 总线宽度(字节) = 一个地址单元
        self.endian = 'little'
        self.doc = ''
        self.constraints = OrderedDict()
        self.attributes = OrderedDict()
        self.cover = []
        self.change_resets = []          # [(target_path, (value, raw))]
        self.insts = []
        self.hdl = ''
        self.vhdl = ''


class Block(object):
    def __init__(self, name, is_system=False):
        self.name = name
        self.is_system = is_system
        self.doc = ''
        self.attributes = OrderedDict()
        self.change_resets = []          # block-scope change_reset rules
        self.maps = OrderedDict()        # domain name -> Map
        self.hdl = ''
        self.vhdl = ''

    def default_map(self):
        if not self.maps:
            self.maps[''] = Map('')
        if '' in self.maps:
            return self.maps['']
        return list(self.maps.values())[0]


class Inst(object):
    """某个构件的一次实例化"""

    def __init__(self, kind, defname):
        self.kind = kind                 # field/register/regfile/memory/vreg/block/system
        self.defname = defname
        self.name = defname              # =rename 之后的实例名
        self.arr = None                  # (lo, hi) 或 None
        self.hdl = ''                   # Verilog local path
        self.vhdl = ''                  # VHDL local path
        self.offset = None               # 原始字符串 (地址单元 / bit)
        self.incr = None
        self.access_restrict = ''        # read / write
        self.mem = None                  # vreg 绑定的 memory
        self.definition = None           # 内联定义
        self.domain = ''                 # block.domain=rename
        self.line = 0
        self.file = ''


# ============================================================================
# 语法分析
# ============================================================================

class ParseError(Exception):
    pass


class Parser(object):
    def __init__(self, incdirs=None, flavor='auto'):
        self.incdirs = list(incdirs or [])
        self.flavor = flavor if flavor in ACCESS_SETS else 'auto'
        self.access_set = ACCESS_SETS[self.flavor]
        self.toks = []
        self.pos = 0
        self.env = {}
        self.warnings = []               # [(where, msg)]
        self.cur_file = '.'
        self.src_stack = []              # 递归 source 检测
        self.files = []                  # 实际读进来的文件
        self.defs = dict((k, OrderedDict()) for k in
                         ('field', 'register', 'regfile', 'memory', 'vreg', 'block', 'system'))
        self.order = []                  # 顶层出现顺序 [(kind, name)]

    # ---------------- token 流 ----------------
    def peek(self, k=0):
        i = self.pos + k
        return self.toks[i] if i < len(self.toks) else None

    def next(self):
        t = self.peek()
        if t is None:
            raise ParseError('unexpected end of file')
        self.pos += 1
        return t

    def expect(self, kind):
        t = self.next()
        if t.kind != kind:
            raise ParseError('%s:%d: expected %r, got %r' % (t.file, t.line, kind, t.val))
        return t

    def warn(self, msg, tokn=None):
        where = ''
        if tokn is not None:
            where = '%s:%d' % (os.path.basename(tokn.file), tokn.line)
        else:
            where = os.path.basename(self.cur_file)
        self.warnings.append((where, msg))

    def check_access(self, acc, raw, kw_tok):
        """UVM / VMM 的 access 表不同; auto 模式接受两者的并集。

        UVM 还允许 uvm_reg_field::define_access() 注册自定义 policy, 所以
        这里只告警, 不当成错误。
        """
        if acc in self.access_set:
            return
        other = 'vmm' if self.flavor == 'uvm' else ('uvm' if self.flavor == 'vmm' else None)
        if other and acc in ACCESS_SETS[other]:
            self.warn('access mode %s 属于 %s 方言, 当前按 --flavor %s 检查'
                      % (raw, other.upper(), self.flavor), kw_tok)
        else:
            self.warn('未知 field access mode: %s' % raw, kw_tok)

    # ---------------- 变量 / 表达式 ----------------
    def subst(self, s):
        """$var / ${var} 替换 + [expr ...] 求值"""
        if s is None:
            return None
        out = re.sub(r'\$\{(\w+)\}', lambda m: str(self.env.get(m.group(1), m.group(0))), s)
        out = re.sub(r'\$(\w+)', lambda m: str(self.env.get(m.group(1), m.group(0))), out)
        while True:
            m = re.search(r'\[\s*expr\s+([^\[\]]*)\]', out)
            if not m:
                break
            out = out[:m.start()] + str(self.safe_expr(m.group(1))) + out[m.end():]
        return out

    def safe_expr(self, e):
        """极简表达式求值 (只用于 RALF 里的 for/if/expr)"""
        e = (e or '').strip()
        e = re.sub(r"(\d*)'[sS]?([bodhBODH])([0-9a-fA-FxXzZ_]+)",
                   lambda m: str(parse_num("'%s%s" % (m.group(2), m.group(3)))[0] or 0), e)
        e = re.sub(r'\b0[xX][0-9a-fA-F]+\b', lambda m: str(int(m.group(0), 16)), e)
        e = e.replace('&&', ' and ').replace('||', ' or ')
        e = re.sub(r'(?<![=!<>])!(?!=)', ' not ', e)
        if re.search(r'[^\w\s\.\+\-\*/%()<>=!&|\^~]', e):
            self.warn('无法求值的表达式: %s' % e)
            return 0
        try:
            return eval(e, {'__builtins__': {}}, {})
        except Exception:
            self.warn('无法求值的表达式: %s' % e)
            return 0

    # ---------------- 入口 ----------------
    def parse_file(self, path):
        path = os.path.abspath(path)
        with open(path, 'r', encoding='utf-8', errors='replace') as f:
            text = f.read()
        self.toks = tokenize(text, path)
        self.pos = 0
        self.cur_file = path
        self.src_stack.append(path)
        self.files.append(path)
        self.parse_body(None)
        self.src_stack.pop()
        return self

    def find_include(self, name, base):
        cands = [name, os.path.join(os.path.dirname(base), name)]
        cands += [os.path.join(d, name) for d in self.incdirs]
        if not name.endswith('.ralf'):
            cands += [c + '.ralf' for c in list(cands)]
        for c in cands:
            if os.path.isfile(c):
                return os.path.abspath(c)
        return None

    def run_sub(self, toks, handler, *args):
        """在独立 token 流上跑一个解析函数 (用于 source / for / if)"""
        save = (self.toks, self.pos)
        self.toks, self.pos = toks, 0
        try:
            handler(*args)
        finally:
            self.toks, self.pos = save

    # ---------------- 通用: 读 header / 块 ----------------
    def read_header(self, line):
        """读该命令的 header

        Tcl 里一条命令到行尾结束, 所以除了 '{' / ';' / '}', 换行同样终止 header
        —— 这样 "bits 8" (无分号) 和 "source x.ralf" 都不会吞掉下一条命令。
        紧跟其后单独一行的 '{' 仍然算这条命令的 body。
        """
        hdr = []
        while True:
            t = self.peek()
            if t is None:
                return hdr, False
            if t.kind == '{':
                self.next()
                return hdr, True
            if t.kind == ';':
                self.next()
                return hdr, False
            if t.kind == '}':
                return hdr, False
            if t.line != line:
                return hdr, False
            hdr.append(self.next())

    def skip_block_raw(self):
        """吃掉一个 {...} 并返回内部原文"""
        depth, out = 1, []
        while depth:
            t = self.next()
            if t.kind == '{':
                depth += 1
                out.append('{')
            elif t.kind == '}':
                depth -= 1
                if depth:
                    out.append('}')
            else:
                out.append(t.val)
        return ' '.join(out).strip()

    def grab_brace_tokens(self):
        """已消费 '{', 收集到配对 '}' 的 token 列表 (不含最外层花括号)"""
        depth, out = 1, []
        while depth:
            t = self.next()
            if t.kind == '{':
                depth += 1
            elif t.kind == '}':
                depth -= 1
                if depth == 0:
                    break
            out.append(t)
        return out

    # ---------------- header 解码 ----------------
    def norm_header_tokens(self, hdr):
        """把 "vhdl_path = (..)" 里被空格拆开的 '=' 合回 'vhdl_path='。

        只对这两个关键字做, 避免动到 "name=rename" 的重命名语法。
        """
        out, i, n = [], 0, len(hdr)
        while i < n:
            t = hdr[i]
            if (t.kind == 'word' and t.val in ('hdl_path', 'vhdl_path')
                    and i + 1 < n and hdr[i + 1].kind == 'word' and hdr[i + 1].val == '='):
                out.append(Tok('word', t.val + '=', t.line, t.file))
                i += 2
                continue
            out.append(t)
            i += 1
        return out

    def decode_header(self, hdr):
        """Decode a RALF construct header.

        Supports legacy positional (hdl_path) plus explicit
        hdl_path=(...) / vhdl_path=(...) forms.
        """
        d = dict(name=None, rename=None, arr=None, hdl='', vhdl='', offset=None, incr=None,
                 access='', mem=None, extra=[], domain='')
        if not hdr:
            return d
        hdr = self.norm_header_tokens(hdr)
        first = self.subst(hdr[0].val)
        m = re.match(r'^([^\[\]=@]+)(?:=([^\[\]@]+))?(?:\[([^\]]*)\])?$', first)
        if m:
            d['name'] = m.group(1)
            d['rename'] = m.group(2)
            if m.group(3):
                d['arr'] = self.decode_range(m.group(3))
        else:
            d['name'] = first
        if d['name'] and '.' in d['name']:
            base, dom = d['name'].split('.', 1)
            d['name'], d['domain'] = base, dom

        i = 1
        while i < len(hdr):
            t = hdr[i]
            v = self.subst(t.val)
            # Newer RALF spelling: hdl_path=(...) / vhdl_path=(...)
            if t.kind == 'word' and v in ('hdl_path=', 'vhdl_path='):
                if i + 1 < len(hdr) and hdr[i + 1].kind == 'paren':
                    pv = self.subst(hdr[i + 1].val)[1:-1].strip()
                    d['hdl' if v.startswith('hdl_') else 'vhdl'] = pv
                    i += 2
                    continue
                d['extra'].append(v)
                i += 1
                continue
            if t.kind == 'paren':
                # Legacy positional path is Verilog hdl_path.
                if not d['hdl']:
                    d['hdl'] = v[1:-1].strip()
                else:
                    d['extra'].append(v)
                i += 1
                continue
            if v.startswith('@'):
                body = v[1:]
                if '+' in body:
                    body, inc = body.split('+', 1)
                    d['incr'] = inc
                d['offset'] = body
                i += 1
                continue
            if v.startswith('+'):
                d['incr'] = v[1:]
                i += 1
                continue
            if v in ('read', 'write'):
                d['access'] = v
                i += 1
                continue
            if '@' in v:                        # vreg: mem@offset[+incr]
                mem, off = v.split('@', 1)
                if '+' in off:
                    off, inc = off.split('+', 1)
                    d['incr'] = inc
                mm = re.match(r'^([^\[]+)\[([^\]]*)\]$', mem)
                d['mem'] = mm.group(1) if mm else mem
                d['offset'] = off
                i += 1
                continue
            d['extra'].append(v)
            i += 1
        return d

    def decode_range(self, s):
        s = s.strip()
        if ':' in s:
            a, b = s.split(':', 1)
            lo, _ = parse_num(self.subst(a))
            hi, _ = parse_num(self.subst(b))
            if lo is None or hi is None:
                return None
            return (min(lo, hi), max(lo, hi))
        v, _ = parse_num(self.subst(s))
        if v is None:
            return None
        return (0, v - 1)

    def num(self, s):
        return parse_num(self.subst(s))[0]

    # ---------------- 主体 ----------------
    def parse_body(self, ctx):
        """ctx: None=全局 / Map / Register / RegFile / VReg / Block"""
        while True:
            t = self.peek()
            if t is None or t.kind == '}':
                return
            if t.kind == ';':
                self.next()
                continue
            if t.kind != 'word':
                raise ParseError('%s:%d: unexpected %r' % (t.file, t.line, t.val))
            kw_tok = self.next()
            kw = kw_tok.val

            if kw == 'source':
                self.do_source(ctx, kw_tok)
            elif kw == 'set':
                name = self.next().val
                self.env[name] = self.subst(self.next().val)
                if self.peek() and self.peek().kind == ';':
                    self.next()
            elif kw == 'incr':
                name = self.next().val
                step = 1
                nt = self.peek()
                if nt and nt.kind == 'word' and nt.line == kw_tok.line and \
                        re.match(r'^-?\d+$', nt.val):
                    step = int(self.next().val)
                self.env[name] = str(int(self.env.get(name, 0)) + step)
            elif kw == 'for':
                self.do_for(ctx, kw_tok)
            elif kw == 'if':
                self.do_if(ctx, kw_tok)
            elif kw in ('puts', 'unset'):
                self.read_header(kw_tok.line)
            elif kw == 'virtual':
                nxt = self.next().val
                if nxt != 'register':
                    raise ParseError('expected "virtual register", got "virtual %s"' % nxt)
                self.do_construct('vreg', ctx, kw_tok)
            elif kw in ('field', 'register', 'regfile', 'memory', 'block', 'system'):
                self.do_construct(kw, ctx, kw_tok)
            elif kw == 'domain':
                self.do_domain(ctx, kw_tok)
            elif kw in ('hdl_path=', 'vhdl_path='):
                # Accept property-style path assignment inside a construct.
                nt = self.peek()
                target = ctx.default_map() if isinstance(ctx, Block) else ctx
                if nt and nt.kind == 'paren' and nt.line == kw_tok.line and hasattr(target, 'hdl'):
                    val = self.next().val[1:-1].strip()
                    if kw.startswith('hdl_'):
                        target.hdl = val
                    else:
                        target.vhdl = val
                    if self.peek() and self.peek().kind == ';':
                        self.next()
                else:
                    self.warn('无法解析的 %s' % kw.rstrip('='), kw_tok)
            else:
                self.do_property(kw, ctx, kw_tok)

    def do_source(self, ctx, kw_tok):
        t = self.peek()
        if t is None or t.kind != 'word' or t.line != kw_tok.line:
            self.warn('source 缺少文件名', kw_tok)
            return
        raw = self.subst(self.next().val)
        if self.peek() and self.peek().kind == ';':
            self.next()
        path = self.find_include(raw, self.cur_file)
        if not path:
            self.warn('source 找不到文件: %s' % raw, kw_tok)
            return
        if path in self.src_stack:
            self.warn('检测到递归 source, 已跳过: %s' % raw, kw_tok)
            return
        with open(path, 'r', encoding='utf-8', errors='replace') as f:
            sub = tokenize(f.read(), path)
        prev = self.cur_file
        self.cur_file = path
        self.src_stack.append(path)
        self.files.append(path)
        self.run_sub(sub, self.parse_body, ctx)
        self.src_stack.pop()
        self.cur_file = prev

    def do_for(self, ctx, kw_tok):
        groups = []
        for _ in range(4):
            while self.peek() and self.peek().kind == ';':
                self.next()
            if not self.peek() or self.peek().kind != '{':
                self.warn('无法解析的 for 循环, 已跳过', kw_tok)
                return
            self.next()
            groups.append(self.grab_brace_tokens())
        init, cond, step, body = groups
        try:
            var = init[1].val
            start = int(self.num(init[2].val))
            op = cond[1].val
            limit = int(self.num(self.subst(' '.join(x.val for x in cond[2:]))))
            inc = int(self.num(step[2].val)) if len(step) >= 3 else 1
        except Exception:
            self.warn('无法解析的 for 循环, 已跳过', kw_tok)
            return
        cmp_ = {'<': lambda a, b: a < b, '<=': lambda a, b: a <= b,
                '>': lambda a, b: a > b, '>=': lambda a, b: a >= b,
                '!=': lambda a, b: a != b}.get(op)
        if cmp_ is None or inc == 0:
            self.warn('不支持的 for 条件: %s' % op, kw_tok)
            return
        i, guard = start, 0
        while cmp_(i, limit) and guard < 100000:
            self.env[var] = str(i)
            self.run_sub(list(body), self.parse_body, ctx)
            i += inc
            guard += 1

    def do_if(self, ctx, kw_tok):
        if not self.peek() or self.peek().kind != '{':
            self.warn('无法解析的 if, 已跳过', kw_tok)
            return
        self.next()
        cond = self.grab_brace_tokens()
        if not self.peek() or self.peek().kind != '{':
            self.warn('无法解析的 if body, 已跳过', kw_tok)
            return
        self.next()
        body = self.grab_brace_tokens()
        else_body = None
        nt = self.peek()
        if nt and nt.kind == 'word' and nt.val == 'else':
            self.next()
            if self.peek() and self.peek().kind == '{':
                self.next()
                else_body = self.grab_brace_tokens()
        expr = self.subst(' '.join(t.val for t in cond))
        if bool(self.safe_expr(expr)):
            self.run_sub(list(body), self.parse_body, ctx)
        elif else_body is not None:
            self.run_sub(list(else_body), self.parse_body, ctx)

    def do_domain(self, ctx, kw_tok):
        hdr, opened = self.read_header(kw_tok.line)
        d = self.decode_header(hdr)
        if not isinstance(ctx, Block):
            raise ParseError('%s:%d: domain 只能出现在 block/system 内' %
                             (kw_tok.file, kw_tok.line))
        mp = Map(d['name'] or '')
        if '' in ctx.maps and not ctx.maps[''].insts and ctx.maps[''].bytes is None:
            del ctx.maps['']                     # 丢掉占位的默认 map
        ctx.maps[mp.name] = mp
        if opened:
            self.parse_body(mp)
            self.expect('}')

    # ---------------- 构件 ----------------
    def do_construct(self, kind, ctx, kw_tok):
        hdr, opened = self.read_header(kw_tok.line)
        d = self.decode_header(hdr)
        name = d['name']
        obj = None
        if opened:
            obj = self.new_def(kind, name)
            if hasattr(obj, 'hdl'):
                obj.hdl = d.get('hdl', '')
                obj.vhdl = d.get('vhdl', '')
            self.parse_body(obj)
            self.expect('}')

        if ctx is None:                          # 顶层定义
            if obj is None:
                if kind != 'field':              # "field tx_en;" = 1bit rw, 合法
                    self.warn('顶层 %s %s 缺少定义体, 已忽略' % (kind, name), kw_tok)
                    return
                obj = self.new_def(kind, name)
            self.defs[kind][name] = obj
            self.order.append((kind, name))
            return

        inst = Inst(kind, name)
        inst.name = d['rename'] or name
        inst.arr = d['arr']
        inst.hdl = d['hdl']
        inst.vhdl = d.get('vhdl', '')
        inst.offset = d['offset']
        inst.incr = d['incr']
        inst.access_restrict = d['access']
        inst.mem = d['mem']
        inst.domain = d['domain']
        inst.definition = obj
        inst.line = kw_tok.line
        inst.file = kw_tok.file
        if obj is not None and kind in ('block', 'system'):
            self.defs[kind][name] = obj          # 内联子 block 也登记, 便于复用
        target = ctx.default_map() if isinstance(ctx, Block) else ctx
        if hasattr(target, 'insts'):
            target.insts.append(inst)
        else:
            self.warn('%s %s 出现在不支持的上下文中' % (kind, name), kw_tok)

    def new_def(self, kind, name):
        if kind == 'field':
            return Field(name)
        if kind == 'register':
            return Register(name)
        if kind == 'regfile':
            return RegFile(name)
        if kind == 'memory':
            return Memory(name)
        if kind == 'vreg':
            return VReg(name)
        if kind in ('block', 'system'):
            b = Block(name, is_system=(kind == 'system'))
            b.maps[''] = Map('')
            return b
        raise ParseError('unknown kind %s' % kind)

    # ---------------- 属性 ----------------
    def do_property(self, kw, ctx, kw_tok):
        hdr, opened = self.read_header(kw_tok.line)
        vals = [self.subst(t.val) for t in hdr]
        if vals and vals[0] == '=':                   # "hdl_path = (..)" 带空格
            vals = vals[1:]
        v0 = vals[0] if vals else ''

        if ctx is None:
            # 全局作用域没有可以承载属性的对象, 多半是花括号不匹配。
            self.warn('顶层作用域不支持属性语句 "%s" (检查花括号是否配对)' % kw, kw_tok)
            if opened:
                self.skip_block_raw()
            return

        # 单接口 block/system 的 bytes/endian 属于其默认 physical interface。
        # domain 内 ctx 本身就是 Map。
        prop_ctx = ctx.default_map() if isinstance(ctx, Block) and kw in ('bytes', 'endian') else ctx

        if kw == 'user_code':
            # User code affects generated model classes, not register-map extraction.
            if opened:
                self.skip_block_raw()
            return

        if kw == 'change_reset':
            if opened:
                self.skip_block_raw()
            if len(vals) < 2:
                self.warn('change_reset 缺少 target/value', kw_tok)
                return
            target, raw = vals[0], vals[1]
            rule = (target, (parse_num(raw)[0], raw))
            if hasattr(ctx, 'change_resets'):
                ctx.change_resets.append(rule)
            else:
                self.warn('change_reset 出现在不支持的上下文中', kw_tok)
            return

        if kw == 'constraint':
            body = self.skip_block_raw() if opened else ''
            if hasattr(ctx, 'constraints'):
                ctx.constraints[v0 or 'c%d' % len(ctx.constraints)] = body
            return
        if kw == 'doc':
            body = self.skip_block_raw() if opened else ' '.join(vals)
            if hasattr(ctx, 'doc'):
                ctx.doc = (ctx.doc + ' ' + norm_doc(body)).strip()
            return
        if kw in ('coverpoint', 'cross'):
            if opened:
                self.skip_block_raw()
            return
        if kw == 'attributes':
            body = self.skip_block_raw() if opened else ''
            if hasattr(ctx, 'attributes'):
                for item in body.split(','):
                    parts = item.split()
                    if parts:
                        ctx.attributes[parts[0]] = ' '.join(parts[1:])
            return
        if kw == 'enum':
            body = self.skip_block_raw() if opened else ' '.join(vals)
            self.parse_enum(body, ctx, kw_tok)
            return

        if opened:                                # 未知的带块属性
            self.skip_block_raw()
            self.warn('忽略未知属性块: %s' % kw, kw_tok)
            return

        if kw == 'bits':
            ctx.bits = self.num(v0)
        elif kw == 'bytes':
            prop_ctx.bytes = self.num(v0)
        elif kw == 'size':
            ctx.size = parse_size(v0)
        elif kw == 'access':
            ctx.access = v0.lower()
            if isinstance(ctx, Field):
                self.check_access(ctx.access, v0, kw_tok)
            elif ctx.access not in ('rw', 'ro'):          # memory 只有 RAM/ROM
                self.warn('memory access 只能是 rw|ro, 得到: %s' % v0, kw_tok)
        elif kw in ('reset', 'hard_reset'):
            ctx.reset = (parse_num(v0)[0], v0)
        elif kw == 'soft_reset':
            ctx.soft_reset = (parse_num(v0)[0], v0)
        elif kw == 'volatile':
            ctx.volatile = v0 or 'yes'
        elif kw == 'initial':
            ctx.initial = v0
        elif kw == 'left_to_right':
            ctx.left_to_right = True
        elif kw == 'endian':
            prop_ctx.endian = v0
        elif kw == 'shared':
            ctx.shared = 'yes'
            # Legacy shared (hdl_path) form: read_header preserves paren text in vals.
            if v0.startswith('(') and v0.endswith(')') and hasattr(ctx, 'hdl'):
                ctx.hdl = v0[1:-1].strip()
            elif v0:
                ctx.shared = v0
        elif kw == 'cover':
            if hasattr(ctx, 'cover'):
                ctx.cover.extend(vals)
        elif kw in ('noise', 'individually_accessible'):
            pass
        elif kw in ('hdl_path', 'vhdl_path'):
            # Usually encoded in the construct header; accept property spelling too.
            target = ctx.default_map() if isinstance(ctx, Block) else ctx
            if hasattr(target, 'hdl'):
                val = v0
                if val.startswith('(') and val.endswith(')'):
                    val = val[1:-1].strip()
                if kw == 'hdl_path':
                    target.hdl = val
                else:
                    target.vhdl = val
        else:
            self.warn('忽略未知属性: %s %s' % (kw, ' '.join(vals)), kw_tok)

    def parse_enum(self, body, ctx, kw_tok=None):
        """enum { AA, BB=2, CC } / enum { OFF = 0, ON = 1 }  (= 两边可能有空格)"""
        if not hasattr(ctx, 'enum'):
            return
        nxt = 0
        for item in (body or '').split(','):
            item = item.strip().strip(';').strip()
            if not item:
                continue
            m = re.match(r'^([A-Za-z_]\w*)\s*(?:=\s*(.+))?$', item)
            if not m:
                self.warn('无法解析的 enum 项: %s' % item, kw_tok)
                continue
            val = nxt
            if m.group(2) is not None:
                v = parse_num(self.subst(m.group(2).strip()))[0]
                if v is not None:
                    val = v
            ctx.enum.append((m.group(1), val))
            nxt = val + 1


# ============================================================================
# 展开 (elaboration)
# ============================================================================

class Elaborator(object):
    """把定义 + 实例展开成扁平的寄存器/字段表。"""

    def __init__(self, parser, addr_mode='byte', expand_arrays=True):
        self.p = parser
        self.addr_mode = addr_mode
        self.expand = expand_arrays
        self.rows = []
        self.reg_rows = []
        self.mem_rows = []
        self.blk_rows = []
        self.warnings = []
        self._seen = set()
        self.reset_rules = []             # [(full_target, value, raw)]
        self.memory_index = {}            # (block_path, memory instance/def name) -> info

    def warn(self, m):
        if m not in self.warnings:
            self.warnings.append(m)

    # ---------- 地址单位 ----------
    def ubytes(self, bus):
        return 1 if self.addr_mode == 'byte' else bus

    def stride(self, width_bits, bus):
        words = max(1, int(math.ceil((width_bits / 8.0) / bus)))
        return words * bus if self.addr_mode == 'byte' else words

    # ---------- path ----------
    def fmt_path(self, path, idx=None):
        path = path or ''
        if idx is not None:
            path = path.replace('%d', str(idx)).replace('%g', str(idx))
        return path

    def seg_of(self, hdl, vhdl, owner=''):
        """一个 construct 最多贡献一个路径段, 返回 (text, lang)。

        UG 的 "either a vhdl_path or a Verilog hdl_path (not both)" 是针对
        *单个 construct* 的; Verilog 层次里挂一个 VHDL 末端信号是合法的
        混合语言设计, 不该告警。
        """
        if hdl and vhdl:
            self.warn('%s 同时指定了 hdl_path 和 vhdl_path; 同一 construct 只能二选一, '
                      '已采用 vhdl_path' % (owner or 'construct'))
            return vhdl, 'VHDL'
        if vhdl:
            return vhdl, 'VHDL'
        if hdl:
            return hdl, 'Verilog'
        return '', ''

    def seg_for(self, inst_hdl, inst_vhdl, def_hdl, def_vhdl, owner=''):
        """实例上的路径优先于定义上的; 两者是不同 construct, 不能混判。"""
        if inst_hdl or inst_vhdl:
            return self.seg_of(inst_hdl, inst_vhdl, owner)
        return self.seg_of(def_hdl, def_vhdl, owner)

    def join_seg(self, parent, seg_text, seg_lang, idx=None):
        """(text, lang) 追加一段 -> (text, lang)。

        分隔符取 *被追加段* 的语言: VHDL 用 ':' , Verilog 用 '.'
        (UG Example 10-7: vhd_top_mod:dut_blk + reg -> vhd_top_mod:dut_blk:reg)。
        混合层次因此得到一条完整路径, 例如 u_top.u_mixed:vhd_reg。
        """
        ptext, plang = parent or ('', '')
        seg_text = self.fmt_path(seg_text, idx)
        if not seg_text:
            return ptext, plang
        if not ptext:
            return seg_text, seg_lang
        sep = ':' if seg_lang == 'VHDL' else '.'
        return ptext.rstrip('.:') + sep + seg_text.lstrip('.:'), seg_lang

    def path_cols(self, path, local_text=''):
        """(text, lang) -> (Backdoor, HDL Path, VHDL Path, Local Path)

        完整路径只落在末端语言对应的那一列, 不再劈成两半。
        """
        text, lang = path or ('', '')
        if not text:
            return '', '', '', ''
        if lang == 'VHDL':
            return 'VHDL', '', text, local_text
        return 'Verilog', text, '', local_text

    # ---------- 数组 ----------
    def idxs(self, arr):
        if arr is None:
            return [None]
        return list(range(arr[0], arr[1] + 1)) if self.expand else [arr[0]]

    def anm(self, name, arr, k):
        if arr is None:
            return name
        if not self.expand:
            return '%s[%d:%d]' % (name, arr[0], arr[1])
        return '%s[%d]' % (name, k)

    # ---------- field 布局 ----------
    def layout(self, reg):
        """返回 ([(inst_name, Field, lsb, bits, field_inst)], register_width_bits)。"""
        out, items = [], []
        for inst in reg.insts:
            if inst.kind != 'field':
                continue
            fd = inst.definition or self.p.defs['field'].get(inst.defname)
            if fd is None:
                self.warn('找不到 field 定义: %s (in register %s)' % (inst.defname, reg.name))
                fd = Field(inst.defname)
            items.append((inst, fd))

        width = reg.bytes * 8 if reg.bytes else None
        if not reg.left_to_right:
            nxt = 0
            for inst, fd in items:
                bits = fd.bits or 1
                base = self.p.num(inst.offset) if inst.offset not in (None, 'none', '') else None
                if base is None:
                    base = nxt
                incr = (self.p.num(inst.incr) or bits) if inst.incr else bits
                lo = inst.arr[0] if inst.arr else 0
                cnt = (inst.arr[1] - inst.arr[0] + 1) if inst.arr else 1
                for k in self.idxs(inst.arr):
                    j = (k - lo) if k is not None else 0
                    lsb = base + j * incr
                    out.append((self.anm(inst.name, inst.arr, k), fd, lsb, bits, inst))
                nxt = base + (cnt - 1) * incr + bits
        else:
            # RALF left_to_right 的 @offset 是从最高有效位向右的距离。
            # 先构造 top-relative offsets 并计算包含 gap 的实际 span，再向 LSB 对齐。
            top_items, nxt_top, span = [], 0, 0
            for inst, fd in items:
                bits = fd.bits or 1
                off = self.p.num(inst.offset) if inst.offset not in (None, 'none', '') else None
                base = nxt_top if off is None else off
                incr = (self.p.num(inst.incr) or bits) if inst.incr else bits
                lo = inst.arr[0] if inst.arr else 0
                cnt = (inst.arr[1] - inst.arr[0] + 1) if inst.arr else 1
                for k in self.idxs(inst.arr):
                    j = (k - lo) if k is not None else 0
                    top_off = base + j * incr
                    top_items.append((self.anm(inst.name, inst.arr, k), fd, top_off, bits, inst))
                last_top = base + (cnt - 1) * incr
                nxt_top = last_top + bits
                span = max(span, nxt_top)
            for nm, fd, top_off, bits, inst in top_items:
                out.append((nm, fd, max(span - (top_off + bits), 0), bits, inst))

        if width is None:
            msb = max([l + b for _, _, l, b, _ in out] or [8])
            width = int(math.ceil(msb / 8.0)) * 8
        out.sort(key=lambda x: x[2])
        return out, width

    def _reg_def(self, inst):
        return inst.definition or self.p.defs['register'].get(inst.defname)

    # ---------- reset override ----------
    def add_reset_rules(self, base_path, rules):
        for target, (value, raw) in (rules or []):
            if not self.expand and re.search(r'\[\d+\]', target):
                self.warn('数组未展开时无法精确表示 change_reset %s; 保留原 reset' % target)
            full = '%s.%s' % (base_path, target) if base_path else target
            self.reset_rules.append((full, value, raw))

    def reset_override(self, reg_path, field_path, lsb, bits):
        for target, value, raw in reversed(self.reset_rules):
            if target == field_path:
                return value, raw
            if target == reg_path:
                if value is None:
                    return None, raw
                return (value >> lsb) & ((1 << bits) - 1), raw
        return None

    # ---------- 层次遍历 ----------
    def walk_block(self, blk, path, base_byte, parent_bytes, domain='', hpath=None):
        key = (id(blk), path, domain)
        if key in self._seen:
            self.warn('检测到重复/递归实例化, 已跳过: %s' % path)
            return
        self._seen.add(key)
        self.add_reset_rules(path, getattr(blk, 'change_resets', []))

        # 顶层独立定义自身也可能带路径 (实例化时已在 walk_map 里拼过)
        hpath = hpath or ('', '')
        if not hpath[0]:
            seg, lang = self.seg_of(getattr(blk, 'hdl', ''), getattr(blk, 'vhdl', ''), path)
            hpath = self.join_seg(hpath, seg, lang)

        if domain:
            if domain not in blk.maps:
                self.warn('找不到 domain %s (in %s)' % (domain, path))
                return
            maps = [(domain, blk.maps[domain])]
        else:
            maps = list(blk.maps.items())

        for mname, mp in maps:
            bus = mp.bytes or parent_bytes or 4
            bpath = path if not mname else '%s.%s' % (path, mname)
            if bpath != path:
                self.add_reset_rules(bpath, getattr(blk, 'change_resets', []))
            self.add_reset_rules(bpath, getattr(mp, 'change_resets', []))
            bd, hdl_c, vhdl_c, _ = self.path_cols(hpath)
            self.blk_rows.append(dict(block=bpath, kind='system' if blk.is_system else 'block',
                                      definition=blk.name,
                                      domain=mname, bus_bytes=bus, endian=mp.endian, base=base_byte,
                                      items=len(mp.insts), doc=blk.doc,
                                      backdoor=bd, hdl=hdl_c, vhdl=vhdl_c))
            self.walk_map(mp, bpath, base_byte, bus, '', mname, hpath)

    def walk_map(self, mp, bpath, base_byte, bus, prefix, domain, hpath):
        nxt_unit = 0
        pending_vregs = []
        for inst in mp.insts:
            off = inst.offset
            explicit = off not in (None, 'none', '')
            unit = self.p.num(off) if explicit else nxt_unit
            if off == 'none':
                unit = None
            elif explicit and unit is None:
                self.warn('无法解析的地址偏移 @%s (%s.%s)' % (off, bpath, inst.name))
                unit = nxt_unit

            if inst.kind == 'register':
                nxt_unit = self.emit_register(inst, bpath, base_byte, bus, prefix, domain,
                                              unit, nxt_unit, mp.endian, hpath)
            elif inst.kind == 'regfile':
                nxt_unit = self.emit_regfile(inst, bpath, base_byte, bus, prefix, domain,
                                             unit, nxt_unit, mp.endian, hpath)
            elif inst.kind == 'memory':
                nxt_unit = self.emit_memory(inst, bpath, base_byte, bus, prefix, domain,
                                            unit, nxt_unit, hpath)
            elif inst.kind == 'vreg':
                # Virtual registers do not consume block address space. Defer until all
                # memories in this map are known so source order does not matter.
                pending_vregs.append(inst)
            elif inst.kind in ('block', 'system'):
                sub = (inst.definition or self.p.defs[inst.kind].get(inst.defname)
                       or self.p.defs['block'].get(inst.defname)
                       or self.p.defs['system'].get(inst.defname))
                if sub is None:
                    self.warn('找不到 %s 定义: %s' % (inst.kind, inst.defname))
                    continue
                incr = self.p.num(inst.incr) if inst.incr else 0
                lo = inst.arr[0] if inst.arr else 0
                seg, lang = self.seg_for(inst.hdl, inst.vhdl, getattr(sub, 'hdl', ''),
                                         getattr(sub, 'vhdl', ''),
                                         '%s.%s' % (bpath, inst.name))
                for k in self.idxs(inst.arr):
                    j = (k - lo) if k is not None else 0
                    b = base_byte + ((unit or 0) + j * (incr or 0)) * self.ubytes(bus)
                    self.walk_block(sub, '%s.%s' % (bpath, self.anm(inst.name, inst.arr, k)),
                                    b, bus, inst.domain, self.join_seg(hpath, seg, lang, k))

        for inst in pending_vregs:
            self.emit_vreg(inst, bpath, base_byte, bus, prefix, domain, mp.endian, hpath)

    # ---------- register ----------
    def emit_register(self, inst, bpath, base_byte, bus, prefix, domain,
                      unit, nxt_unit, endian, parent_path):
        rd = self._reg_def(inst)
        if rd is None:
            self.warn('找不到 register 定义: %s' % inst.defname)
            return nxt_unit
        fields, width = self.layout(rd)
        naddr = self.stride(width, bus)
        incr = (self.p.num(inst.incr) or naddr) if inst.incr else naddr
        lo = inst.arr[0] if inst.arr else 0
        last = unit
        # shared 寄存器用定义里的 hdl_path, 而不是实例化处的 (UG: "used instead of")
        if getattr(rd, 'shared', None) and (getattr(rd, 'hdl', '') or getattr(rd, 'vhdl', '')):
            seg, seg_lang = self.seg_of(rd.hdl, rd.vhdl, rd.name)
        else:
            seg, seg_lang = self.seg_for(inst.hdl, inst.vhdl, getattr(rd, 'hdl', ''),
                                         getattr(rd, 'vhdl', ''), rd.name)
        for k in self.idxs(inst.arr):
            j = (k - lo) if k is not None else 0
            u = None if unit is None else unit + j * incr
            last = u
            self.emit_reg_rows(rd, self.anm(inst.name, inst.arr, k), fields, width,
                               bpath, prefix, domain, base_byte, bus, u, inst, endian,
                               parent_path, seg, seg_lang, k,
                               effective_restrict=inst.access_restrict,
                               shared=bool(getattr(rd, 'shared', None)))
        if unit is None:
            return nxt_unit
        if inst.arr and not self.expand:
            last = unit + (inst.arr[1] - inst.arr[0]) * incr
        return (last if last is not None else unit) + naddr

    def emit_reg_rows(self, rd, nm, fields, width, bpath, prefix, domain, base_byte, bus,
                      u, inst, endian, parent_path=None, seg='', seg_lang='',
                      arr_idx=None, effective_restrict='', shared=False,
                      memory='', mem_offset='', absaddr_override=None, byte_off_override=None,
                      kind='register', allow_parent_path=False):
        byte_off = (None if u is None else u * self.ubytes(bus))
        absaddr = (None if u is None else base_byte + byte_off)
        if absaddr_override is not None:
            absaddr = absaddr_override
        if byte_off_override is not None:
            byte_off = byte_off_override

        parent_path = parent_path or ('', '')
        seg = self.fmt_path(seg, arr_idx)
        reg_base = self.join_seg(parent_path, seg, seg_lang)
        # 光有父层次路径不构成完整的寄存器 backdoor path,
        # 只有本级自己带 leaf path 时才填这几列。
        if seg:
            backdoor, reg_hdl, reg_vhdl, local_path = self.path_cols(reg_base, seg)
        elif allow_parent_path and parent_path[0]:
            backdoor, reg_hdl, reg_vhdl, local_path = self.path_cols(parent_path, '')
        else:
            backdoor, reg_hdl, reg_vhdl, local_path = '', '', '', ''
        rdoc = rd.doc
        common = dict(block=bpath, domain=domain, reg=prefix + nm, regtype=rd.name,
                      kind=kind, byte_off='' if byte_off is None else hexs(byte_off),
                      addr='' if absaddr is None else hexs(absaddr), width=width,
                      shared='Yes' if shared else '', restrict=effective_restrict or '',
                      backdoor=backdoor, hdl=reg_hdl, vhdl=reg_vhdl,
                      local_path=local_path, memory=memory, mem_offset=mem_offset,
                      rdoc=rdoc, _addr=absaddr if absaddr is not None else -1)
        self.reg_rows.append(dict(common, bytes=width // 8, endian=endian,
                                  nfields=len(fields),
                                  attrs=', '.join('%s=%s' % kv for kv in rd.attributes.items()),
                                  where='%s:%d' % (os.path.basename(inst.file), inst.line)
                                        if inst.file else ''))
        if not fields:
            r = dict(common)
            r.update(field='-', msb='', lsb='', bits='', fwidth='', access='',
                     reset='', reset_raw='', soft_reset='', volatile='', enum='',
                     constr='', fdoc='')
            self.rows.append(r)
            return

        reg_path = '%s.%s%s' % (bpath, prefix, nm)
        for fname, fd, lsb, bits, finst in fields:
            msb = lsb + bits - 1
            acc = (fd.access or ('ro' if fd.name in ('unused', 'reserved') else 'rw')).upper()
            field_path = '%s.%s' % (reg_path, fname)
            ov = self.reset_override(reg_path, field_path, lsb, bits)
            if ov is not None:
                ov_val, ov_raw = ov
                rst = hexs(ov_val, bits) if ov_val is not None else ov_raw
                rst_raw = ov_raw
            elif fd.reset and fd.reset[0] is not None:
                rst, rst_raw = hexs(fd.reset[0], bits), fd.reset[1]
            elif fd.reset:
                rst, rst_raw = fd.reset[1], fd.reset[1]
            else:
                rst, rst_raw = hexs(0, bits), ''
            if fd.soft_reset and fd.soft_reset[0] is not None:
                srst = hexs(fd.soft_reset[0], bits)
            else:
                srst = fd.soft_reset[1] if fd.soft_reset else ''

            # 字段的 hdl_path 接在寄存器路径之后
            fseg, flang = self.seg_for(finst.hdl, finst.vhdl, getattr(fd, 'hdl', ''),
                                       getattr(fd, 'vhdl', ''), fname)
            fidx = None
            if finst.arr and '[' in fname:
                try:
                    fidx = int(fname.rsplit('[', 1)[1].rstrip(']'))
                except ValueError:
                    pass
            fseg = self.fmt_path(fseg, fidx)
            r = dict(common)
            if fseg:
                fb, fh, fv, floc = self.path_cols(
                    self.join_seg(reg_base, fseg, flang), fseg)
                r.update(backdoor=fb, hdl=fh, vhdl=fv, local_path=floc)
            r.update(field=fname, msb=msb, lsb=lsb,
                     bits='[%d:%d]' % (msb, lsb) if bits > 1 else '[%d]' % lsb,
                     fwidth=bits, access=acc, reset=rst, reset_raw=rst_raw,
                     soft_reset=srst, volatile=fd.volatile,
                     enum=', '.join('%s=%s' % (n, hexs(v, bits)) for n, v in fd.enum),
                     constr='; '.join(fd.constraints.keys()), fdoc=fd.doc)
            self.rows.append(r)

    # ---------- regfile ----------
    def emit_regfile(self, inst, bpath, base_byte, bus, prefix, domain,
                     unit, nxt_unit, endian, parent_path):
        rf = inst.definition or self.p.defs['regfile'].get(inst.defname)
        if rf is None:
            self.warn('找不到 regfile 定义: %s' % inst.defname)
            return nxt_unit
        span = self.rf_span(rf, bus)
        incr = (self.p.num(inst.incr) or span) if inst.incr else span
        lo = inst.arr[0] if inst.arr else 0
        last_end = nxt_unit
        if getattr(rf, 'shared', None) and (getattr(rf, 'hdl', '') or getattr(rf, 'vhdl', '')):
            rf_seg, rf_lang = self.seg_of(rf.hdl, rf.vhdl, rf.name)
        else:
            rf_seg, rf_lang = self.seg_for(inst.hdl, inst.vhdl, getattr(rf, 'hdl', ''),
                                           getattr(rf, 'vhdl', ''), rf.name)
        for k in self.idxs(inst.arr):
            j = (k - lo) if k is not None else 0
            nm = self.anm(inst.name, inst.arr, k)
            u = None if unit is None else unit + j * incr
            rf_path = self.join_seg(parent_path, rf_seg, rf_lang, k)
            rf_base_path = '%s.%s%s' % (bpath, prefix, nm)
            self.add_reset_rules(rf_base_path, getattr(rf, 'change_resets', []))
            sub_next = 0
            for ri in rf.insts:
                if ri.kind != 'register':
                    continue
                rexp = ri.offset not in (None, 'none', '')
                runit = self.p.num(ri.offset) if rexp else sub_next
                if ri.offset == 'none':
                    runit = None
                elif runit is None:
                    runit = sub_next
                abs_unit = None if (u is None or runit is None) else u + runit
                rd = self._reg_def(ri)
                if rd is None:
                    self.warn('找不到 register 定义: %s' % ri.defname)
                    continue
                fields, width = self.layout(rd)
                naddr = self.stride(width, bus)
                rincr = (self.p.num(ri.incr) or naddr) if ri.incr else naddr
                rlo = ri.arr[0] if ri.arr else 0
                r_seg, r_lang = self.seg_for(ri.hdl, ri.vhdl, getattr(rd, 'hdl', ''),
                                             getattr(rd, 'vhdl', ''), rd.name)
                eff_restrict = ri.access_restrict or inst.access_restrict
                eff_shared = bool(getattr(rd, 'shared', None) or getattr(rf, 'shared', None))
                for m in self.idxs(ri.arr):
                    jj = (m - rlo) if m is not None else 0
                    uu = None if abs_unit is None else abs_unit + jj * rincr
                    self.emit_reg_rows(rd, self.anm(ri.name, ri.arr, m), fields, width,
                                       bpath, prefix + nm + '.', domain, base_byte, bus, uu,
                                       ri, endian, rf_path, r_seg, r_lang, m,
                                       effective_restrict=eff_restrict, shared=eff_shared)
                if runit is not None:
                    cnt = (ri.arr[1] - ri.arr[0]) if ri.arr else 0
                    sub_next = runit + cnt * rincr + naddr
            if u is not None:
                last_end = u + span
        if unit is None:
            return nxt_unit
        if inst.arr and not self.expand:
            last_end = unit + (inst.arr[1] - inst.arr[0]) * incr + span
        return last_end

    def rf_span(self, rf, bus):
        nxt = 0
        for ri in rf.insts:
            if ri.kind != 'register':
                continue
            rd = self._reg_def(ri)
            if rd is None:
                continue
            _, width = self.layout(rd)
            naddr = self.stride(width, bus)
            base = self.p.num(ri.offset) if ri.offset not in (None, 'none', '') else nxt
            if base is None:
                base = nxt
            cnt = (ri.arr[1] - ri.arr[0]) if ri.arr else 0
            incr = (self.p.num(ri.incr) or naddr) if ri.incr else naddr
            nxt = base + cnt * incr + naddr
        return max(1, nxt)

    # ---------- memory / virtual register ----------
    def emit_memory(self, inst, bpath, base_byte, bus, prefix, domain,
                    unit, nxt_unit, parent_path):
        md = inst.definition or self.p.defs['memory'].get(inst.defname)
        if md is None:
            self.warn('找不到 memory 定义: %s' % inst.defname)
            return nxt_unit
        loc_units = self.stride(md.bits or 8, bus)
        naddr = (md.size or 0) * loc_units
        byte_off = None if unit is None else unit * self.ubytes(bus)
        absaddr = None if unit is None else base_byte + byte_off
        total = ''
        if md.size and md.bits:
            nbytes = md.size * md.bits / 8.0
            total = '%.3g KB' % (nbytes / 1024.0) if nbytes >= 1024 else '%d B' % nbytes
        if getattr(md, 'shared', None) and (getattr(md, 'hdl', '') or getattr(md, 'vhdl', '')):
            mseg, mlang = self.seg_of(md.hdl, md.vhdl, md.name)
        else:
            mseg, mlang = self.seg_for(inst.hdl, inst.vhdl, getattr(md, 'hdl', ''),
                                       getattr(md, 'vhdl', ''), md.name)
        if mseg:
            mem_path = self.join_seg(parent_path, mseg, mlang)
            backdoor, full_hdl, full_vhdl, local_path = self.path_cols(mem_path, mseg)
        else:
            mem_path = ('', '')
            backdoor, full_hdl, full_vhdl, local_path = '', '', '', ''
        shared = bool(getattr(md, 'shared', None))
        row = dict(block=bpath, domain=domain, name=prefix + inst.name, memtype=md.name,
                   addr='' if absaddr is None else hexs(absaddr),
                   byte_off='' if byte_off is None else hexs(byte_off),
                   size=md.size, bits=md.bits, total=total,
                   access=(inst.access_restrict or md.access or 'rw').upper(),
                   restrict=inst.access_restrict, shared='Yes' if shared else '',
                   initial=md.initial or '', backdoor=backdoor, hdl=full_hdl,
                   vhdl=full_vhdl, local_path=local_path, doc=md.doc)
        self.mem_rows.append(row)
        info = dict(row, _absaddr=absaddr, _byte_off=byte_off, _md=md, _path=mem_path,
                    _loc_byte_stride=loc_units * self.ubytes(bus),
                    _effective_access=(inst.access_restrict or md.access or 'rw').upper())
        self.memory_index[(bpath, inst.name)] = info
        self.memory_index.setdefault((bpath, inst.defname), info)
        if unit is None:
            return nxt_unit
        return unit + naddr

    def emit_vreg(self, inst, bpath, base_byte, bus, prefix, domain, endian, parent_path):
        vd = inst.definition or self.p.defs['vreg'].get(inst.defname)
        if vd is None:
            self.warn('找不到 virtual register 定义: %s' % inst.defname)
            return
        shim = Register(vd.name)
        shim.insts = vd.insts
        shim.bytes = vd.bytes
        shim.left_to_right = vd.left_to_right
        shim.doc = vd.doc
        shim.attributes = OrderedDict()
        fields, width = self.layout(shim)

        mem = self.memory_index.get((bpath, inst.mem)) if inst.mem else None
        if inst.mem and mem is None:
            self.warn('virtual register %s 找不到关联 memory: %s (in %s)' %
                      (inst.name, inst.mem, bpath))
        if mem and (mem['_md'].bits or 0) <= 0:
            self.warn('virtual register %s 的关联 memory %s 缺少 bits' % (inst.name, inst.mem))
            mem = None

        base_mem_off = self.p.num(inst.offset) if inst.offset not in (None, '') else 0
        if base_mem_off is None:
            self.warn('virtual register %s 无法解析 memory offset @%s' % (inst.name, inst.offset))
            base_mem_off = 0
        if mem:
            locs_per_vreg = max(1, int(math.ceil(float(width) / float(mem['_md'].bits))))
        else:
            locs_per_vreg = 1
        parsed_incr = self.p.num(inst.incr) if inst.incr else 0
        vincr = parsed_incr if parsed_incr else locs_per_vreg
        lo = inst.arr[0] if inst.arr else 0
        v_seg, v_lang = self.seg_for(inst.hdl, inst.vhdl, getattr(vd, 'hdl', ''),
                                     getattr(vd, 'vhdl', ''), vd.name)

        for k in self.idxs(inst.arr):
            j = (k - lo) if k is not None else 0
            moff = base_mem_off + j * vincr
            absaddr = None
            byte_off = None
            memname = inst.mem or ''
            eff_restrict = ''
            shared = False
            v_parent = parent_path
            if mem:
                if mem['_absaddr'] is not None:
                    absaddr = mem['_absaddr'] + moff * mem['_loc_byte_stride']
                if mem['_byte_off'] is not None:
                    byte_off = mem['_byte_off'] + moff * mem['_loc_byte_stride']
                eff_restrict = mem.get('restrict', '')
                shared = bool(mem.get('shared'))
                # 静态 virtual register 物理上就在这块 memory 里
                v_parent = mem.get('_path', ('', ''))
            self.emit_reg_rows(shim, self.anm(inst.name, inst.arr, k), fields, width,
                               bpath, prefix, domain, base_byte, bus, None, inst, endian,
                               v_parent, v_seg, v_lang, k,
                               effective_restrict=eff_restrict, shared=shared,
                               memory=memname, mem_offset=hexs(moff),
                               absaddr_override=absaddr, byte_off_override=byte_off,
                               kind='virtual', allow_parent_path=True)


# ============================================================================
# 表格定义
# ============================================================================

REG_COLS = [
    ('block',       'Block',          24),
    ('domain',      'Domain',         12),
    ('reg',         'Register',       30),
    ('kind',        'Kind',           10),
    ('addr',        'Address',        14),
    ('byte_off',    'Offset',         12),
    ('width',       'Width(bit)',      9),
    ('field',       'Field',          22),
    ('bits',        'Bits',           10),
    ('msb',         'MSB',             6),
    ('lsb',         'LSB',             6),
    ('fwidth',      'Size',            6),
    ('access',      'Access',          9),
    ('reset',       'Reset',          12),
    ('reset_raw',   'Reset(RALF)',    13),
    ('soft_reset',  'Soft Reset',     12),
    ('volatile',    'Volatile',        9),
    ('enum',        'Enum',           26),
    ('constr',      'Constraint',     14),
    ('shared',      'Shared',          8),
    ('restrict',    'R/W Limit',      10),
    ('memory',      'Memory',         18),
    ('mem_offset',  'Memory Offset',  14),
    ('backdoor',    'Backdoor',       10),
    ('hdl',         'HDL Path',       32),
    ('vhdl',        'VHDL Path',      32),
    ('local_path',  'Local Path',     24),
    ('fdoc',        'Field Desc',     34),
    ('rdoc',        'Register Desc',  30),
]
MERGE_KEYS = ('block', 'domain', 'reg', 'kind', 'addr', 'byte_off', 'width', 'shared',
              'restrict', 'memory', 'mem_offset', 'backdoor', 'hdl', 'vhdl', 'rdoc')
CENTER_KEYS = ('domain', 'kind', 'addr', 'byte_off', 'width', 'bits', 'msb', 'lsb', 'fwidth',
               'access', 'reset', 'reset_raw', 'soft_reset', 'volatile', 'shared', 'restrict',
               'mem_offset', 'backdoor', 'size', 'total', 'value', 'bytes', 'nfields', 'endian')
MONO_KEYS = ('addr', 'byte_off', 'reset', 'reset_raw', 'bits', 'value', 'mem_offset')

REGSUM_COLS = [
    ('block', 'Block', 24), ('domain', 'Domain', 12), ('reg', 'Register', 30),
    ('regtype', 'Type', 20), ('kind', 'Kind', 10), ('addr', 'Address', 14),
    ('byte_off', 'Offset', 12), ('bytes', 'Bytes', 7), ('width', 'Width(bit)', 10),
    ('nfields', 'Fields', 7), ('endian', 'Endian', 9), ('shared', 'Shared', 8),
    ('restrict', 'R/W Limit', 10), ('memory', 'Memory', 18),
    ('mem_offset', 'Memory Offset', 14), ('attrs', 'Attributes', 20),
    ('backdoor', 'Backdoor', 10), ('hdl', 'HDL Path', 32), ('vhdl', 'VHDL Path', 32),
    ('local_path', 'Local Path', 24), ('rdoc', 'Description', 40), ('where', 'Source', 18),
]

MEM_COLS = [
    ('block', 'Block', 24), ('domain', 'Domain', 12), ('name', 'Memory', 24),
    ('memtype', 'Type', 18), ('addr', 'Address', 14), ('byte_off', 'Offset', 12),
    ('size', 'Size(locs)', 12), ('bits', 'Width(bit)', 10), ('total', 'Total', 12),
    ('access', 'Access', 9), ('shared', 'Shared', 8), ('restrict', 'R/W Limit', 10),
    ('initial', 'Initial', 10), ('backdoor', 'Backdoor', 10), ('hdl', 'HDL Path', 32),
    ('vhdl', 'VHDL Path', 32), ('local_path', 'Local Path', 24), ('doc', 'Description', 30),
]

ENUM_COLS = [('block', 'Block', 22), ('domain', 'Domain', 12), ('reg', 'Register', 28),
             ('field', 'Field', 22), ('name', 'Enum Name', 24), ('value', 'Value', 12)]

WARN_COLS = [('kind', 'Stage', 10), ('where', 'Where', 26), ('msg', 'Warning', 100)]

BLOCKTREE_COLS = [
    ('tree', 'Block Tree', 34),
    ('kind', 'Kind', 10),
    ('definition', 'Definition', 22),
    ('instance', 'Instance Path', 34),
    ('base', 'Base Addr', 14),
    ('domains', 'Domain(s)', 18),
    ('bus_bytes', 'Bus Bytes', 14),
    ('endian', 'Endian', 12),
    ('backdoor', 'Backdoor', 10),
    ('hdl', 'HDL Path', 32),
    ('vhdl', 'VHDL Path', 32),
]


def build_block_tree_rows(blk_rows):
    """Collapse domain rows and render instantiated system/block hierarchy."""
    nodes = OrderedDict()

    for b in blk_rows:
        path = b.get('block', '')
        domain = b.get('domain', '')
        root = path
        if domain and path.endswith('.' + domain):
            root = path[:-(len(domain) + 1)]

        n = nodes.get(root)
        if n is None:
            n = dict(
                instance=root,
                kind=b.get('kind', ''),
                definition=b.get('definition', ''),
                base=b.get('base'),
                domains=[],
                bus_values=[],
                endian_values=[],
                backdoor=b.get('backdoor', ''),
                hdl=b.get('hdl', ''),
                vhdl=b.get('vhdl', ''),
            )
            nodes[root] = n

        if domain and domain not in n['domains']:
            n['domains'].append(domain)
        if b.get('bus_bytes') not in n['bus_values']:
            n['bus_values'].append(b.get('bus_bytes'))
        if b.get('endian') not in n['endian_values']:
            n['endian_values'].append(b.get('endian'))

    paths = list(nodes.keys())
    parent = {}
    children = OrderedDict((p, []) for p in paths)
    roots = []

    for p in paths:
        candidates = [q for q in paths if q != p and p.startswith(q + '.')]
        par = max(candidates, key=len) if candidates else None
        parent[p] = par
        if par is None:
            roots.append(p)
        else:
            children[par].append(p)

    out = []

    def emit(path, prefix='', is_last=True, level=0):
        n = nodes[path]
        leaf = path.rsplit('.', 1)[-1]
        if level == 0:
            tree = leaf
        else:
            tree = prefix + ('└─ ' if is_last else '├─ ') + leaf

        buses = [str(v) for v in n['bus_values'] if v is not None]
        endians = [str(v) for v in n['endian_values'] if v]
        out.append(dict(
            tree=tree,
            kind=n['kind'],
            definition=n['definition'],
            instance=n['instance'],
            base=hexs(n['base']) if n['base'] is not None else '',
            domains=', '.join(n['domains']),
            bus_bytes=', '.join(buses),
            endian=', '.join(endians),
            backdoor=n['backdoor'],
            hdl=n['hdl'],
            vhdl=n['vhdl'],
        ))

        kids = children.get(path, [])
        child_prefix = prefix + ('   ' if is_last else '│  ')
        for i, kid in enumerate(kids):
            emit(kid, child_prefix if level > 0 else '',
                 i == len(kids) - 1, level + 1)

    for i, root in enumerate(roots):
        emit(root, '', i == len(roots) - 1, 0)

    return out


def print_block_tree(blk_rows, out=sys.stderr, prefix=''):
    rows = build_block_tree_rows(blk_rows)
    if not rows:
        return
    out.write('%sBlock tree:\n' % prefix)
    for r in rows:
        extra = []
        definition = r.get('definition', '')
        instance = r.get('instance', '')
        leaf = instance.rsplit('.', 1)[-1] if instance else ''
        if definition and definition != leaf:
            extra.append('def=%s' % definition)
        if r.get('base'):
            extra.append('base=%s' % r['base'])
        if r.get('domains'):
            extra.append('domain=%s' % r['domains'])
        line = r.get('tree', '')
        if extra:
            line += '  [' + ', '.join(extra) + ']'
        out.write('%s  %s\n' % (prefix, line))


def print_summary(meta, ela, warn_rows, out=sys.stderr, prefix=''):
    out.write('%sSummary:\n' % prefix)
    out.write('%s  source: %s\n' % (prefix, meta['src']))
    out.write('%s  top: %s\n' % (prefix, meta['top']))
    out.write('%s  registers: %d | fields: %d | memories: %d | warnings: %d\n' %
              (prefix, len(ela.reg_rows), len(ela.rows), len(ela.mem_rows), len(warn_rows)))
    out.write('%s  address mode: %s\n' % (prefix, meta['addr_mode']))
    out.write('%s  arrays: %s | access dialect: %s\n' %
              (prefix, meta['arrays'], meta.get('flavor', 'auto')))


def bit_range_of(r):
    return r.get('bits', '')


# ============================================================================
# Excel 输出
# ============================================================================

def write_xlsx(path, ela, meta, warn_rows, sheet_per_block=True):
    from openpyxl import Workbook
    from openpyxl.styles import Font, PatternFill, Alignment, Border, Side
    from openpyxl.utils import get_column_letter
    from openpyxl.worksheet.cell_range import CellRange, MultiCellRange

    hdr_font = Font(bold=True, color='FFFFFF', size=10)
    hdr_fill = PatternFill('solid', fgColor='2F5597')
    reg_fill = PatternFill('solid', fgColor='DCE6F1')
    warn_fill = PatternFill('solid', fgColor='FFF2CC')
    thin = Side(style='thin', color='B7B7B7')
    border = Border(left=thin, right=thin, top=thin, bottom=thin)
    center = Alignment(horizontal='center', vertical='center')
    left = Alignment(horizontal='left', vertical='center', wrap_text=True)
    mono = Font(name='Consolas', size=10)

    wb = Workbook()

    def dump(ws, rows, cols, merge=False, fill=None):
        for j, (_, h, w) in enumerate(cols, 1):
            c = ws.cell(1, j, h)
            c.font, c.fill, c.alignment, c.border = hdr_font, hdr_fill, center, border
            ws.column_dimensions[get_column_letter(j)].width = w
        for i, row in enumerate(rows, start=2):
            for j, (key, _, _) in enumerate(cols, 1):
                c = ws.cell(i, j, row.get(key, ''))
                c.border = border
                c.alignment = center if key in CENTER_KEYS else left
                if key in MONO_KEYS:
                    c.font = mono
                if fill is not None:
                    c.fill = fill
        ws.freeze_panes = 'A2'
        ws.row_dimensions[1].height = 22
        if rows:
            ws.auto_filter.ref = 'A1:%s%d' % (get_column_letter(len(cols)), len(rows) + 1)
        if not merge or not rows:
            return
        idx = dict((k, j) for j, (k, _, _) in enumerate(cols, 1))
        n = len(rows)
        start = 2
        ranges = []
        for i in range(2, n + 2):
            cur = rows[i - 2]
            nxt = rows[i - 1] if i - 1 < n else None
            same = (nxt is not None and nxt.get('reg') == cur.get('reg')
                    and nxt.get('block') == cur.get('block')
                    and nxt.get('addr') == cur.get('addr'))
            if not same:
                if i > start:
                    for k in MERGE_KEYS:
                        if k in idx:
                            c = idx[k]
                            ranges.append(CellRange(min_col=c, max_col=c,
                                                    min_row=start, max_row=i))
                            for r in range(start + 1, i + 1):
                                ws.cell(r, c).value = None      # merge_cells 会做的事
                for k in ('block', 'reg', 'addr'):
                    if k in idx:
                        ws.cell(start, idx[k]).fill = reg_fill
                start = i + 1
        if ranges:
            # openpyxl 的 merge_cells() 是 O(n^2) 的 (每次都要跟已有区间比对),
            # 几千行就能拖到几十秒。一次性赋值: 6000 个区间 6.3s -> 0.02s。
            ws.merged_cells = MultiCellRange(ranges)

    # Excel only contains register data; terminal carries summary/tree/warnings.
    wb.remove(wb.active)

    dump(wb.create_sheet('RegisterMap'), ela.rows, REG_COLS, merge=True)
    dump(wb.create_sheet('Registers'), ela.reg_rows, REGSUM_COLS)

    if ela.mem_rows:
        dump(wb.create_sheet('Memories'), ela.mem_rows, MEM_COLS)

    enum_rows, seen = [], set()
    for r in ela.rows:
        key = (r['block'], r['reg'], r['field'])
        if r.get('enum') and key not in seen:
            seen.add(key)
            for item in r['enum'].split(', '):
                if '=' in item:
                    nm, vv = item.split('=', 1)
                    enum_rows.append(dict(block=r['block'], domain=r.get('domain', ''), reg=r['reg'],
                                          field=r['field'], name=nm, value=vv))
    if enum_rows:
        dump(wb.create_sheet('Enums'), enum_rows, ENUM_COLS)

    if sheet_per_block:
        # One worksheet per instantiated block. For a multi-domain block,
        # rows carry block paths like "soc.bridge.pci" / "soc.bridge.ahb";
        # collapse those domain-qualified paths back to the block instance
        # ("soc.bridge") so both interfaces stay in one sheet.
        block_key = {}
        for b in ela.blk_rows:
            if b.get('kind') != 'block':
                continue
            p = b.get('block', '')
            d = b.get('domain', '')
            root = p
            if d and p.endswith('.' + d):
                root = p[:-(len(d) + 1)]
            block_key[p] = root

        groups = OrderedDict()
        for r in ela.rows:
            rp = r.get('block', '')
            bname = block_key.get(rp, rp)
            groups.setdefault(bname, []).append(r)

        used = set(s.title for s in wb.worksheets)
        for bname, rows in groups.items():
            # Excel forbids [] in sheet names. Keep array instances readable:
            # soc.uart[0] -> soc.uart_0
            t = re.sub(r'\[([^\]]+)\]', r'_\1', bname)
            t = re.sub(r'[\\/*?:\[\]]', '_', t).strip('_')[-31:]
            base_t, k = t, 1
            while t in used:
                t = ('%s_%d' % (base_t, k))[-31:]
                k += 1
            used.add(t)
            dump(wb.create_sheet(t), rows, REG_COLS, merge=True)

    wb.save(path)


def write_csv(path, rows, cols):
    import csv
    with open(path, 'w', newline='', encoding='utf-8-sig') as f:
        w = csv.writer(f)
        w.writerow([h for _, h, _ in cols])
        for r in rows:
            w.writerow([r.get(k, '') for k, _, _ in cols])


def dump_text(ela, out=sys.stdout):
    """纯文本寄存器表, 方便 diff 两个版本的 RALF"""
    by_reg = OrderedDict()
    for r in ela.rows:
        by_reg.setdefault((r['block'], r['reg'], r['addr']), []).append(r)
    cur_blk = None
    for (blk, reg, addr), frows in by_reg.items():
        if blk != cur_blk:
            out.write('\n=== %s ===\n' % blk)
            cur_blk = blk
        out.write('REG %12s  %-32s %sb\n' % (addr or '-', reg, frows[0]['width']))
        for f in frows:
            if f['field'] == '-':
                continue
            out.write('    %10s %-26s %-6s reset=%s%s\n' %
                      (f['bits'], f['field'], f['access'], f['reset'],
                       ('  ' + f['enum']) if f['enum'] else ''))
    if ela.mem_rows:
        out.write('\n=== memories ===\n')
        for m in ela.mem_rows:
            out.write('MEM %12s  %-32s %s x %sb  %s\n' %
                      (m['addr'] or '-', '%s.%s' % (m['block'], m['name']),
                       m['size'], m['bits'], m['access']))


# ============================================================================
# main
# ============================================================================

def _convert_one(args, ralf_path, out_path, csv_path, label=None):
    """解析+展开+输出单个 .ralf 文件; label 非空时日志加前缀(批量模式用)"""
    prefix = ('[%s] ' % label) if label else ''

    if not os.path.isfile(ralf_path):
        sys.stderr.write('%sERROR: 文件不存在: %s\n' % (prefix, ralf_path))
        return 2

    p = Parser(incdirs=args.incdir, flavor=args.flavor)
    try:
        p.parse_file(ralf_path)
    except (ParseError, OSError) as e:
        sys.stderr.write('%sRALF 解析失败: %s\n' % (prefix, e))
        return 2
    except Exception as e:                      # 兼容性兼底: 不向用户抛 traceback
        sys.stderr.write('%sRALF 解析出错 (%s): %s\n' % (prefix, type(e).__name__, e))
        return 2

    tops = list(args.top)
    if not tops:
        systems = [n for k, n in p.order if k == 'system']
        blocks = [n for k, n in p.order if k == 'block']
        tops = systems or blocks
        if not tops:
            sys.stderr.write('%sRALF 里没有 block/system, 无法确定顶层\n' % prefix)
            return 2
        if len(tops) > 1:
            sys.stderr.write('%s[i] 未指定 -t, 展开全部 %d 个顶层: %s\n'
                             % (prefix, len(tops), ', '.join(tops)))

    base, _ = parse_num(args.base)
    ela = Elaborator(p, addr_mode=args.addr_mode,
                     expand_arrays=not args.no_expand_arrays)
    for t in tops:
        topdef = p.defs['system'].get(t) or p.defs['block'].get(t)
        if topdef is None:
            sys.stderr.write('%s找不到 top: %s (可用: %s)\n' %
                             (prefix, t, ', '.join('%s %s' % (k, n) for k, n in p.order)))
            return 2
        try:
            ela.walk_block(topdef, topdef.name, base or 0, None)
        except Exception as e:
            sys.stderr.write('%s展开 %s 出错 (%s): %s\n' % (prefix, t, type(e).__name__, e))
            return 2

    if args.sort == 'addr':
        ela.rows.sort(key=lambda r: (r['block'], r['_addr'], r['reg'],
                                     r['lsb'] if r['lsb'] != '' else 0))
        ela.reg_rows.sort(key=lambda r: (r['block'], r['_addr'], r['reg']))

    warn_rows = ([dict(kind='parse', where=w, msg=m) for w, m in p.warnings] +
                 [dict(kind='elab', where='', msg=m) for m in ela.warnings])

    if args.dump:
        dump_text(ela)

    if args.strict and warn_rows:
        sys.stderr.write('%sERROR: --strict 下有 %d 条 warning, 未生成输出\n' % (prefix, len(warn_rows)))
        return 3

    if args.check:
        return 0

    meta = dict(src=os.path.abspath(ralf_path), nfiles=len(p.files),
                top=', '.join(tops),
                time=datetime.datetime.now().strftime('%Y-%m-%d %H:%M:%S'),
                addr_mode='%s offsets (%s), base=%s' %
                          (args.addr_mode,
                           'ralgen -B / byte addressing' if args.addr_mode == 'byte'
                           else 'ralgen default / address units',
                           hexs(base or 0)),
                arrays='collapsed' if args.no_expand_arrays else 'expanded',
                flavor=args.flavor)

    if not args.quiet:
        print_summary(meta, ela, warn_rows, prefix=prefix)
        print_block_tree(ela.blk_rows, prefix=prefix)
        for w in warn_rows:
            sys.stderr.write('%s[warn] %s %s\n' %
                             (prefix, ('%s:' % w['where']) if w['where'] else '', w['msg']))

    try:
        write_xlsx(out_path, ela, meta, warn_rows, sheet_per_block=args.sheet_per_block)
    except ImportError:
        sys.stderr.write('%sERROR: 需要 openpyxl, 请先 pip install openpyxl\n' % prefix)
        return 2
    except (OSError, IOError) as e:
        sys.stderr.write('%sERROR: 无法写入 XLSX %s: %s\n' % (prefix, out_path, e))
        return 2
    except Exception as e:
        sys.stderr.write('%sERROR: Excel 输出失败 (%s): %s\n' % (prefix, type(e).__name__, e))
        return 2

    if csv_path:
        try:
            write_csv(csv_path, ela.rows, REG_COLS)
        except (OSError, IOError) as e:
            sys.stderr.write('%sERROR: 无法写入 CSV %s: %s\n' % (prefix, csv_path, e))
            return 2
        except Exception as e:
            sys.stderr.write('%sERROR: CSV 输出失败 (%s): %s\n' % (prefix, type(e).__name__, e))
            return 2

    print('%s[ok] %s' % (prefix, out_path))
    return 0


def main(argv=None):
    ap = argparse.ArgumentParser(
        description='把 Synopsys RALF 寄存器描述文件转换成 Excel 表格',
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog='例:\n'
               '  ralf2xlsx top.ralf -t soc -o regmap.xlsx\n'
               '  ralf2xlsx a.ralf b.ralf c.ralf -o outdir/   # 批量, 各自独立转换出各自的 xlsx\n'
               '  ralf2xlsx top.ralf --check --strict     # CI 里只做检查\n'
               '  ralf2xlsx top.ralf --dump > new.txt     # 文本化后 diff')
    ap.add_argument('ralf', nargs='+',
                    help='.ralf 文件; 传多个时逐个独立转换(各自的定义/顶层/输出), 不会互相合并')
    ap.add_argument('-t', '--top', action='append', default=[],
                    help='顶层 block/system 名, 可多次; 不给则展开所有顶层 system(没有则所有 block); '
                         '批量模式下对每个文件分别生效')
    ap.add_argument('-o', '--out',
                    help='输出 .xlsx: 只传一个 .ralf 时是文件名(缺省 <ralf>.xlsx); '
                         '传多个 .ralf 时是输出目录(缺省与各自源文件同目录), 每个文件各出一份同名 .xlsx')
    ap.add_argument('-I', '--incdir', action='append', default=[], help='source 搜索目录, 可多次')
    ap.add_argument('-s', '--sheet-per-block', dest='sheet_per_block', action='store_true',
                    default=True,
                    help='每个实例化 block 生成独立 sheet（默认开启；保留此选项兼容旧命令）')
    ap.add_argument('--no-sheet-per-block', dest='sheet_per_block', action='store_false',
                    help='不生成每个 block 的独立 sheet')
    ap.add_argument('--csv', help='同时输出 CSV(字段表); 语义同 -o, 多文件时是目录')
    ap.add_argument('--base', default='0', help='顶层基地址 (缺省 0), 支持 0x / Verilog 格式')
    ap.add_argument('--addr-mode', choices=('byte', 'word'), default='byte',
                    help='RALF 里 @offset 的含义: byte=字节偏移(缺省, 对应 ralgen -B / byte addressing); '
                         'word=地址单元个数(= 所在 block 的 bytes), 对应 ralgen 默认地址语义')
    ap.add_argument('--flavor', choices=('auto', 'uvm', 'vmm'), default='auto',
                    help='field access mode 按哪套方言校验: auto=UVM|VMM 并集(缺省), '
                         'uvm=只接受 UVM 表, vmm=只接受 VMM 表')
    ap.add_argument('--sort', choices=('source', 'addr'), default='source',
                    help='行顺序: source=按 RALF 出现顺序(缺省), addr=按地址')
    ap.add_argument('--no-expand-arrays', action='store_true',
                    help='数组只出一行 (name[lo:hi]), 大数组不撑爆表格')
    ap.add_argument('--check', action='store_true', help='只解析+展开, 不生成 Excel')
    ap.add_argument('--dump', action='store_true', help='把展开后的寄存器表打成纯文本')
    ap.add_argument('--strict', action='store_true', help='有 warning 即失败 (退出码 3)')
    ap.add_argument('-q', '--quiet', action='store_true', help='不打印 warning')
    args = ap.parse_args(argv)

    if len(args.ralf) == 1:
        f = args.ralf[0]
        out_path = args.out or (os.path.splitext(f)[0] + '.xlsx')
        return _convert_one(args, f, out_path, args.csv)

    out_dir = args.out
    if out_dir:
        try:
            os.makedirs(out_dir, exist_ok=True)
        except OSError as e:
            sys.stderr.write('ERROR: 无法创建输出目录 %s: %s\n' % (out_dir, e))
            return 2
    csv_dir = args.csv
    if csv_dir:
        try:
            os.makedirs(csv_dir, exist_ok=True)
        except OSError as e:
            sys.stderr.write('ERROR: 无法创建 CSV 输出目录 %s: %s\n' % (csv_dir, e))
            return 2

    worst = 0
    for f in args.ralf:
        base = os.path.splitext(os.path.basename(f))[0]
        out_path = os.path.join(out_dir, base + '.xlsx') if out_dir \
            else os.path.splitext(f)[0] + '.xlsx'
        csv_path = os.path.join(csv_dir, base + '.csv') if csv_dir else None
        rc = _convert_one(args, f, out_path, csv_path, label=os.path.basename(f))
        if rc:
            worst = rc
    return worst


if __name__ == '__main__':
    sys.exit(main())