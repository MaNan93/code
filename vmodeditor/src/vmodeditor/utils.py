"""Reusable utilities for Verilog/SystemVerilog parsing and module analysis.

Uses verible-verilog-syntax CST (Concrete Syntax Tree) for precise source
code navigation and editing.
"""

import json
import os
import re
import shutil
import subprocess
import tempfile
from pathlib import Path
from typing import Any, Dict, List, Optional, Set, Tuple, Union


# ---------------------------------------------------------------------------
# Verible executable
# ---------------------------------------------------------------------------

def _find_verible_binary() -> str:
    """Locate verible-verilog-syntax binary.

    Search order:
    1. VERIBLE_BIN environment variable (path to file or containing directory)
    2. System PATH via shutil.which
    3. A 'verible' directory found by walking up from this file (up to 6 levels)
    """
    name = "verible-verilog-syntax"
    # 1. Environment variable override
    if env := os.environ.get("VERIBLE_BIN", ""):
        p = Path(env)
        if p.is_file():
            return str(p)
        for ext in ("", ".exe"):
            if (c := p / (name + ext)).is_file():
                return str(c)
    # 2. System PATH
    if found := shutil.which(name):
        return found
    # 3. Walk up directory tree looking for a sibling 'verible' directory
    here = Path(__file__).resolve().parent
    for _ in range(6):
        for ext in ("", ".exe"):
            if (c := here / "verible" / (name + ext)).is_file():
                return str(c)
        here = here.parent
    # Fallback: rely on PATH at subprocess call time
    return name


VERIBLE = _find_verible_binary()


# ---------------------------------------------------------------------------
# Constants
# ---------------------------------------------------------------------------

_WIRE_DECL_RE = re.compile(
    r"^\s*(?:wire|logic|reg|bit|tri|integer|var|signed|unsigned)\b[^;\n]*;\s*$"
)

_ANY_DECL_RE = re.compile(
    r"^\s*(?:input|output|inout|ref|wire|logic|reg|bit|tri|integer|var|signed|unsigned)\b[^;\n]*;",
    re.MULTILINE,
)

_STRIP_COMMENTS_RE = re.compile(r"//[^\n]*|/\*.*?\*/", re.DOTALL)

_PORT_CONN_LINE_RE = re.compile(r"\.\s*[A-Za-z_][A-Za-z0-9_$]*\s*\(")

_DECL_KEYWORDS_RE = re.compile(
    r"^\s*(input|output|inout|ref|wire|logic|reg|bit|tri|integer|var|signed|unsigned)\b"
)

_COMMON_TYPES = frozenset({
    "wire", "reg", "logic", "bit", "tri", "supply0", "supply1",
    "triand", "trior", "trireg", "uwire", "real", "realtime",
    "integer", "time", "signed", "unsigned",
})

_KEYWORD_SET = frozenset({
    "module", "endmodule", "function", "endfunction",
    "task", "endtask", "always", "assign", "generate",
    "if", "else", "for", "case", "endcase", "begin",
    "end", "initial", "final", "class", "endclass",
    "input", "output", "inout", "wire", "reg", "logic",
    "parameter", "localparam", "integer", "bit", "tri",
    "always_ff", "always_comb", "always_latch", "string",
    "virtual", "interface", "endinterface", "program", "endprogram",
    "package", "endpackage", "config", "endconfig",
    "primitive", "endprimitive", "table", "endtable",
    "specify", "endspecify", "generate", "endgenerate",
})


# ---------------------------------------------------------------------------
# CST Traversal Utilities
# ---------------------------------------------------------------------------

def find_all(node: Any, tag: str) -> List[Dict]:
    """Find all descendant nodes with given tag (iterative DFS, left-to-right)."""
    results: List[Dict] = []
    stack = [node]
    while stack:
        n = stack.pop()
        if not isinstance(n, dict):
            continue
        if n.get("tag") == tag:
            results.append(n)
        # push children in reverse so the leftmost child is processed first
        stack.extend(
            c for c in reversed(n.get("children", [])) if isinstance(c, dict)
        )
    return results


def find_child(node: Any, tag: str) -> Optional[Dict]:
    """Find first direct child with given tag."""
    if not isinstance(node, dict):
        return None
    for c in node.get("children", []):
        if isinstance(c, dict) and c.get("tag") == tag:
            return c
    return None


def find_children(node: Any, tag: str) -> List[Dict]:
    """Find all direct children with given tag."""
    if not isinstance(node, dict):
        return []
    return [c for c in node.get("children", []) if isinstance(c, dict) and c.get("tag") == tag]


def find_descendant(node: Any, tag: str) -> Optional[Dict]:
    """Find first descendant with given tag (iterative DFS, left-to-right)."""
    stack = [node]
    while stack:
        n = stack.pop()
        if not isinstance(n, dict):
            continue
        if n.get("tag") == tag:
            return n
        # push children in reverse so the leftmost child is processed first
        stack.extend(
            c for c in reversed(n.get("children", [])) if isinstance(c, dict)
        )
    return None


def get_node_range(node: Dict) -> Tuple[int, int]:
    """Get (min_start, max_end) from all leaf nodes in subtree (iterative)."""
    if not isinstance(node, dict):
        return (999999, -1)
    if "start" in node and "end" in node:
        return (node["start"], node["end"])
    starts: List[int] = []
    ends: List[int] = []
    stack = [node]
    while stack:
        n = stack.pop()
        if not isinstance(n, dict):
            continue
        if "start" in n and "end" in n:
            starts.append(n["start"])
            ends.append(n["end"])
        else:
            stack.extend(
                c for c in reversed(n.get("children", [])) if isinstance(c, dict)
            )
    return (min(starts, default=999999), max(ends, default=-1))


# ---------------------------------------------------------------------------
# Text Utilities
# ---------------------------------------------------------------------------

def get_text(node: Dict, source: str) -> str:
    """Get text from a CST leaf node."""
    if "text" in node:
        return node["text"]
    if "start" in node and "end" in node:
        return source[node["start"]:node["end"]]
    return node.get("tag", "")


def strip_comments(text: str) -> str:
    """Remove // and /* */ comments."""
    return _STRIP_COMMENTS_RE.sub("", text)


def split_csv(value: str) -> List[str]:
    """Split by top-level commas; commas inside () [] {} are not separators."""
    depth = 0
    parts: List[str] = []
    prev = 0
    for m in re.finditer(r"[()[\]{},]", value):
        ch = m.group()
        if ch in "([{":
            depth += 1
        elif ch in ")]}":
            if depth > 0:
                depth -= 1
        elif depth == 0:  # ","
            token = value[prev:m.start()].strip()
            if token:
                parts.append(token)
            prev = m.end()
    tail = value[prev:].strip()
    if tail:
        parts.append(tail)
    return parts


def normalize_width(width: str) -> str:
    """Normalize width string to [msb:lsb] form."""
    w = width.strip()
    return "" if not w else w if w.startswith("[") else f"[{w}]"


def normalize_dimension(dimension: str) -> str:
    """Normalize dimension string to [a:b][c:d] form."""
    d = dimension.strip()
    if not d:
        return ""
    if groups := re.findall(r"\[\s*([^\]]+?)\s*\]", d):
        return "".join(f"[{g.strip()}]" for g in groups)
    parts = [p.strip() for p in split_csv(d) if p.strip()]
    return "".join(f"[{p}]" for p in parts) if parts else f"[{d}]"


def detect_indent(text: str, default: str = "    ") -> str:
    """Detect indentation from first non-empty line."""
    for ln in text.splitlines():
        if ln.strip():
            return re.match(r"\s*", ln).group(0) or default
    return default


def detect_newline(text: str) -> str:
    """Detect newline style used in text."""
    if "\r\n" in text:
        return "\r\n"
    return "\n"


def looks_like_width_or_dimension(token: str) -> bool:
    t = token.strip()
    return bool(t) and (t.startswith("[") or ":" in t)


def looks_like_name(token: str) -> bool:
    return bool(re.match(r"^`?[A-Za-z_][A-Za-z0-9_$]*$", token.strip()))


def _split_line_parts(line: str) -> Tuple[str, str, str, str]:
    """Return (core, code_no_comment, comment, newline)."""
    nl = "\r\n" if line.endswith("\r\n") else "\n" if line.endswith("\n") else ""
    core = line[:len(line) - len(nl)]
    i = core.find("//")
    return (core, core[:i].rstrip(), core[i:], nl) if i >= 0 else (core, core.rstrip(), "", nl)


def append_comma_to_port_line(line: str) -> str:
    """Append comma to code end, preserving inline comments and newline."""
    core, code, comment, newline = _split_line_parts(line)
    if code.endswith(","):
        return core + newline
    code += ","
    if comment:
        code += " " + comment.lstrip()
    return code + newline


def remove_trailing_comma_from_line(line: str) -> str:
    """Remove trailing comma from code end, preserving inline comments and newline."""
    _, code, comment, newline = _split_line_parts(line)
    code = re.sub(r",\s*$", "", code)
    if comment:
        code += " " + comment.lstrip()
    return code + newline


def get_line_spans(block_text: str) -> List[Dict[str, Any]]:
    """Split text into lines with byte-offset metadata."""
    spans: List[Dict[str, Any]] = []
    offset = 0
    for line in block_text.splitlines(keepends=True):
        no_eol = line.rstrip("\r\n")
        spans.append({
            "start": offset,
            "end_no_eol": offset + len(no_eol),
            "end_full": offset + len(line),
            "text": no_eol,
        })
        offset += len(line)
    return spans


def apply_text_edits(text: str, edits: List[Tuple[int, int, str]]) -> str:
    """Apply (start, end, replacement) edits back-to-front (avoids offset drift)."""
    for s, e, r in sorted(edits, reverse=True):
        text = text[:s] + r + text[e:]
    return text


def compose_port_decl(info: Dict[str, str]) -> str:
    """'direction [type] [width] name [dim]'."""
    return " ".join(p for p in [info["direction"], info.get("type",""), info.get("width",""), info["name"], info.get("dimension","")] if p)


def compose_wire_decl(info: Dict[str, str]) -> str:
    """'type [width] name [dim]'."""
    return " ".join(p for p in [info["type"], info.get("width",""), info["name"], info.get("dimension","")] if p)


# ---------------------------------------------------------------------------
# Verible Parser
# ---------------------------------------------------------------------------

class VeribleParser:
    """Parse SystemVerilog file using verible-verilog-syntax.

    Wraps the verible-verilog-syntax CLI tool to obtain CST JSON and provides
    methods for module discovery, port extraction, parameter extraction, and
    instance extraction.
    """

    def __init__(self, filepath: str):
        self.filepath = str(Path(filepath).resolve())
        self.source = Path(self.filepath).read_bytes().decode("utf-8")
        self._data: Optional[Dict] = None
        self._modules: Optional[List[Dict[str, Any]]] = None

    @property
    def data(self) -> Dict:
        if self._data is None:
            self._parse()
        return self._data

    def _parse(self) -> None:
        result = subprocess.run(
            [VERIBLE, "--export_json", "--printtree", self.filepath],
            capture_output=True, text=True,
        )
        try:
            raw = json.loads(result.stdout)
        except (json.JSONDecodeError, ValueError):
            stderr = result.stderr.strip() if result.stderr else result.stdout[:200]
            raise ValueError(f"verible produced invalid JSON output: {stderr}")
        for v in raw.values():
            if v is not None and "tree" in v:
                self._data = v
                return
        raise ValueError("verible returned no parse result")

    @property
    def tree(self) -> Dict:
        return self.data["tree"]

    @property
    def tokens(self) -> List[Dict]:
        return self.data.get("tokens", [])

    @property
    def errors(self) -> List[Dict]:
        return self.data.get("errors", [])

    def get_text(self, node: Dict) -> str:
        return get_text(node, self.source)

    # --- Module discovery ---

    def get_modules(self) -> List[Dict]:
        """Return list of module info dicts."""
        if self._modules is not None:
            return self._modules
        mods = find_all(self.tree, "kModuleDeclaration")
        result: List[Dict[str, Any]] = []
        for m in mods:
            header = find_child(m, "kModuleHeader")
            if not header:
                continue
            name_node = find_descendant(header, "SymbolIdentifier")
            name = self.get_text(name_node) if name_node else "<unknown>"

            # paren group (port list)
            paren = find_child(header, "kParenGroup")
            if paren:
                open_leaf = find_child(paren, "(")
                close_leaf = find_descendant(paren, ")")
                open_idx = open_leaf["start"] if open_leaf else -1
                close_idx = close_leaf["start"] if close_leaf else -1
            else:
                open_idx = close_idx = -1

            # semicolon after header
            semi = find_descendant(header, ";")
            semi_idx = semi["end"] if semi else -1

            # module boundaries (computed from leaf nodes)
            mod_start, mod_end = get_node_range(m)

            # ANSI vs non-ANSI
            is_ansi = False
            if paren:
                port_list = find_child(paren, "kPortDeclarationList")
                if port_list:
                    ansi_decls = find_children(port_list, "kPortDeclaration")
                    non_ansi_ports = find_children(port_list, "kPort")
                    is_ansi = len(ansi_decls) > 0 and len(non_ansi_ports) == 0

            # Extract ports, params, instances
            ports = self._extract_ports(m, is_ansi)
            param_names = self._extract_params(m)
            instances = self._extract_instances(m)

            result.append({
                "name": name,
                "mod_start": mod_start,
                "mod_end": mod_end,
                "open_idx": open_idx,
                "close_idx": close_idx,
                "semi_idx": semi_idx,
                "is_ansi": is_ansi,
                "cst": m,
                "ports": ports,
                "param_names": param_names,
                "instances": instances,
            })
        self._modules = result
        return result

    def _extract_ports(self, mod_node: Dict, is_ansi: bool) -> List[Dict[str, str]]:
        """Extract port info from CST."""
        ports: List[Dict[str, str]] = []
        header = find_child(mod_node, "kModuleHeader")
        if not header:
            return ports
        paren = find_child(header, "kParenGroup")
        if not paren:
            return ports

        if is_ansi:
            port_list = find_child(paren, "kPortDeclarationList")
            if not port_list:
                return ports
            for pd in find_children(port_list, "kPortDeclaration"):
                port_info = self._parse_ansi_port(pd)
                if port_info:
                    ports.append(port_info)
        else:
            port_list = find_child(paren, "kPortDeclarationList")
            if not port_list:
                return ports
            for p in find_children(port_list, "kPort"):
                id_node = find_descendant(p, "SymbolIdentifier")
                if id_node:
                    ports.append({
                        "name": self.get_text(id_node),
                        "direction": "",
                        "type": "",
                        "width": "",
                    })
            body_start = find_descendant(header, ";")
            if body_start and "end" in body_start:
                body_end = body_start["end"]
                mod_s, mod_e = get_node_range(mod_node)
                body_text = self.source[body_end:mod_e]
                for port in ports:
                    self._fill_non_ansi_port(port, body_text)

        return ports

    def _parse_ansi_port(self, pd_node: Dict) -> Optional[Dict[str, str]]:
        """Parse an ANSI kPortDeclaration node."""
        direction = ""
        ptype = ""
        width = ""
        name = ""

        # --- Direction: direct keyword child of kPortDeclaration ---
        for c in pd_node.get("children", []):
            if isinstance(c, dict) and c.get("tag") in ("input", "output", "inout", "ref"):
                direction = c["tag"]
                break

        # --- Type: keyword child of kPortDeclaration (wire/reg/…) OR
        #     kDataTypePrimitive inside kDataType (logic/bit/…) ---
        for c in pd_node.get("children", []):
            if not isinstance(c, dict):
                continue
            tag = c.get("tag", "")
            if tag in _COMMON_TYPES and tag not in ("input", "output", "inout", "ref"):
                ptype = tag
                break
            if tag == "kDataType":
                prim = find_descendant(c, "kDataTypePrimitive")
                if prim:
                    for gc in prim.get("children", []):
                        if isinstance(gc, dict) and gc.get("tag") in _COMMON_TYPES:
                            ptype = gc["tag"]
                            break
                break

        # --- Port name: last SymbolIdentifier not in keyword/type sets ---
        candidate_ids = []
        for leaf_id in find_all(pd_node, "SymbolIdentifier"):
            text = self.get_text(leaf_id).strip()
            if text not in _KEYWORD_SET and text not in _COMMON_TYPES:
                candidate_ids.append(text)
        if candidate_ids:
            name = candidate_ids[-1]

        # --- Width: source range of kPackedDimensions (precise CST path) ---
        dt = find_child(pd_node, "kDataType")
        if dt:
            packed = find_child(dt, "kPackedDimensions")
            if packed:
                ps, pe = get_node_range(packed)
                if ps < 999999 and pe > 0:
                    width = self.source[ps:pe].strip()
        # Fallback: simple regex on port text (handles edge cases)
        if not width:
            port_start, port_end = get_node_range(pd_node)
            port_text_clean = strip_comments(self.source[port_start:port_end])
            bracket_matches = re.findall(r"\[[^\]]*\]", port_text_clean)
            if bracket_matches:
                width = bracket_matches[0].strip()

        if not name:
            return None

        return {"name": name, "direction": direction, "type": ptype, "width": width}

    def _fill_non_ansi_port(self, port: Dict[str, str], body_text: str) -> None:
        """Fill direction/type/width for non-ANSI port from body declarations.

        Handles both single-port and multi-port declarations:
          input wire [7:0] address;          <- single
          input wire [7:0] address, data_in; <- multi
        """
        pname = re.escape(port["name"])
        m = re.search(
            rf"^\s*(input|output|inout|ref)"
            rf"(?:\s+(wire|reg|logic|bit|tri|integer|signed|unsigned))?"
            rf"(\s*\[[^\]]*\])?"
            rf"[^;]*?\b{pname}\b",
            body_text, re.MULTILINE,
        )
        if m:
            port["direction"] = m.group(1)
            port["type"] = m.group(2) or ""
            port["width"] = m.group(3) or ""
            port["width"] = port["width"].strip()

    def _extract_params(self, mod_node: Dict) -> List[str]:
        """Extract parameter names (excluding localparam) from CST."""
        params: List[str] = []
        header = find_child(mod_node, "kModuleHeader")
        if not header:
            return params

        for pd in find_all(header, "kParamDeclaration"):
            pd_start, pd_end = get_node_range(pd)
            pd_text = strip_comments(self.source[pd_start:pd_end])
            if re.search(r"\blocalparam\b", pd_text):
                continue
            id_node = find_descendant(pd, "SymbolIdentifier")
            if id_node:
                text = self.get_text(id_node).strip()
                if text and text not in _KEYWORD_SET:
                    params.append(text)

        return params

    def _extract_instances(self, mod_node: Dict) -> List[Dict[str, str]]:
        """Extract module instances from module body using CST traversal.

        Uses kInstantiationBase nodes from the Verible CST.  A node is treated
        as a module instantiation only when its kInstantiationType subtree
        contains a kLocalRoot (i.e. a user-defined type name); nodes with
        kDataTypePrimitive (reg/wire/logic/…) are variable declarations and
        are skipped.
        """
        instances: List[Dict[str, str]] = []
        for inst_base in find_all(mod_node, "kInstantiationBase"):
            inst_type_node = find_child(inst_base, "kInstantiationType")
            if not inst_type_node:
                continue
            # Module instantiation: kInstantiationType contains kLocalRoot
            # Variable declaration: kInstantiationType contains kDataTypePrimitive
            local_root = find_descendant(inst_type_node, "kLocalRoot")
            if not local_root:
                continue
            type_id = find_descendant(local_root, "SymbolIdentifier")
            if not type_id:
                continue
            inst_type = self.get_text(type_id)
            if inst_type in _KEYWORD_SET:
                continue
            # Each instantiated unit is a kGateInstance inside kGateInstanceRegisterVariableList
            for gate_inst in find_all(inst_base, "kGateInstance"):
                name_id = find_child(gate_inst, "SymbolIdentifier")
                if name_id:
                    inst_name = self.get_text(name_id)
                    if inst_name and inst_name not in _KEYWORD_SET:
                        instances.append({"name": inst_name, "type": inst_type})
        return instances

    def get_module(self, module_name: Optional[str] = None) -> Dict:
        """Get module info, raising error for ambiguity."""
        mods = self.get_modules()
        if not mods:
            raise ValueError("No module found in file")
        if module_name:
            for m in mods:
                if m["name"] == module_name:
                    return m
            available = ", ".join(m["name"] for m in mods)
            raise ValueError(f"Module '{module_name}' not found. Available: {available}")
        if len(mods) > 1:
            names = "\n  - ".join(m["name"] for m in mods)
            raise ValueError(f"File contains multiple modules:\n  - {names}\nPlease specify --module.")
        return mods[0]


# ---------------------------------------------------------------------------
# Spec Parsers
# ---------------------------------------------------------------------------

def parse_add_port_spec(port_csv: str) -> Dict[str, str]:
    """Parse --add-port CSV string into port info dict."""
    parts = split_csv(port_csv)
    if len(parts) < 2:
        raise ValueError("--add-port needs at least 'direction, name'")
    direction = parts[0]
    rest = parts[1:]
    typ = width = name = dimension = ""
    if len(rest) == 1:
        name = rest[0]
    elif len(rest) == 2:
        if looks_like_width_or_dimension(rest[0]) and looks_like_name(rest[1]):
            width, name = rest[0], rest[1]
        else:
            typ, name = rest[0], rest[1]
    elif len(rest) == 3:
        if rest[0] in _COMMON_TYPES and looks_like_width_or_dimension(rest[1]) and looks_like_name(rest[2]):
            typ, width, name = rest[0], rest[1], rest[2]
        elif looks_like_width_or_dimension(rest[0]) and looks_like_name(rest[1]):
            width, name, dimension = rest[0], rest[1], rest[2]
        else:
            typ, width, name = rest[0], rest[1], rest[2]
    else:
        if (len(rest) >= 3 and rest[0] in _COMMON_TYPES
                and looks_like_width_or_dimension(rest[1]) and looks_like_name(rest[2])):
            typ, width, name = rest[0], rest[1], rest[2]
            dimension = ",".join(rest[3:]).strip()
        elif looks_like_width_or_dimension(rest[0]) and looks_like_name(rest[1]):
            width, name = rest[0], rest[1]
            dimension = ",".join(rest[2:]).strip()
        else:
            typ, width, name = rest[0], rest[1], rest[2]
            dimension = ",".join(rest[3:]).strip()
    direction = direction.strip().lower()
    if direction not in {"input", "output", "inout", "ref"}:
        raise ValueError("--add-port direction must be input/output/inout/ref")
    if not name.strip():
        raise ValueError("--add-port name is required")
    return {
        "direction": direction,
        "type": typ.strip(),
        "width": normalize_width(width),
        "name": name.strip(),
        "dimension": normalize_dimension(dimension),
    }


def parse_add_wire_spec(wire_csv: str) -> Dict[str, str]:
    """Parse --add-wire CSV string into wire info dict."""
    parts = split_csv(wire_csv)
    if len(parts) == 1:
        typ, width, name, dimension = "wire", "", parts[0], ""
    elif len(parts) == 2:
        if looks_like_width_or_dimension(parts[0]) and looks_like_name(parts[1]):
            typ, width, name, dimension = "wire", parts[0], parts[1], ""
        else:
            typ, width, name, dimension = parts[0], "", parts[1], ""
    elif len(parts) == 3:
        if looks_like_width_or_dimension(parts[0]) and looks_like_name(parts[1]):
            typ, width, name, dimension = "wire", parts[0], parts[1], parts[2]
        else:
            typ, width, name, dimension = parts[0], parts[1], parts[2], ""
    else:
        if looks_like_width_or_dimension(parts[0]) and looks_like_name(parts[1]):
            typ, width, name = "wire", parts[0], parts[1]
            dimension = ",".join(parts[2:]).strip()
        else:
            typ, width, name = parts[0], parts[1], parts[2]
            dimension = ",".join(parts[3:]).strip()
    return {
        "type": typ.strip() or "wire",
        "width": normalize_width(width),
        "name": name.strip(),
        "dimension": normalize_dimension(dimension),
    }


def parse_add_inst_port_spec(csv_str: str) -> Dict[str, str]:
    """Parse --add-inst-port CSV string."""
    parts = split_csv(csv_str)
    if len(parts) < 2:
        raise ValueError("--add-inst-port needs 'instname, port[, wire]'")
    return {
        "instname": parts[0].strip(),
        "port": parts[1].strip(),
        "wire": parts[2].strip() if len(parts) >= 3 else "",
    }


def parse_rm_inst_port_spec(csv_str: str) -> Dict[str, str]:
    """Parse --rm-inst-port CSV string."""
    parts = split_csv(csv_str)
    if len(parts) != 2:
        raise ValueError("--rm-inst-port needs 'instname, name'")
    return {"instname": parts[0].strip(), "port": parts[1].strip()}


# ---------------------------------------------------------------------------
# Edit Operations
# ---------------------------------------------------------------------------

def _find_instance_in_source(source: str, instname: str) -> Tuple[int, int]:
    """Return (open_paren, close_paren) of instname's port connection list."""
    inst_m = next(
        (m for m in re.finditer(rf"\b{re.escape(instname)}\b\s*\(", source)
         if not re.match(r"^\s*//", source[source.rfind("\n", 0, m.start()) + 1 : m.start() + 1])),
        None,
    )
    if not inst_m:
        raise ValueError(f"Instance '{instname}' not found")
    o = source.index("(", inst_m.start())
    depth = 0
    for i in range(o, len(source)):
        if source[i] == "(":   depth += 1
        elif source[i] == ")":
            depth -= 1
            if not depth:
                return o, i
    raise ValueError("Instance connection list is unbalanced")


def cmd_add_port(source: str, module_info: Dict, port_spec: Union[str, Dict[str, str]]) -> str:
    """Add port(s) to module. Returns modified source."""
    info = parse_add_port_spec(port_spec) if isinstance(port_spec, str) else port_spec
    mi = module_info
    newline = detect_newline(source)

    is_ansi = mi["is_ansi"]
    open_idx = mi["open_idx"]
    close_idx = mi["close_idx"]

    if open_idx < 0 or close_idx < 0:
        raise ValueError("Cannot locate port parentheses")

    ports_text = source[open_idx + 1:close_idx]
    ports_clean = strip_comments(ports_text)

    # Idempotency check
    if re.search(rf"\b{re.escape(info['name'])}\b", ports_clean):
        return source

    indent = detect_indent(ports_text)

    if is_ansi:
        port_decl = compose_port_decl(info)
        # Scan from the end to find the last non-comment content line.
        last = next(
            (row for row in reversed(get_line_spans(ports_text))
             if (s := row["text"].strip()) and not s.startswith(("//", "/*", "*"))),
            None,
        )
        edits: List[Tuple[int, int, str]] = []

        if last:
            abs_start = open_idx + 1 + last["start"]
            abs_end = open_idx + 1 + last["end_full"]
            last_text = source[abs_start:abs_end]
            updated = append_comma_to_port_line(last_text)
            if updated != last_text:
                edits.append((abs_start, abs_end, updated))

        insert_text = newline + indent + port_decl
        edits.append((close_idx, close_idx, insert_text))

        source = apply_text_edits(source, edits)
    else:
        insert_text = newline + indent + ", " + info["name"]
        source = source[:close_idx] + insert_text + source[close_idx:]

        semi_idx = mi["semi_idx"]
        if semi_idx < 0:
            return source
        body_start = semi_idx + 1
        body_text = source[body_start:]

        body_lines = body_text.splitlines()
        new_lines: List[str] = []
        inserted = False
        decl = compose_port_decl(info) + ";"
        body_indent = detect_indent(body_text)

        for line in body_lines:
            new_lines.append(line)
            if not inserted and _DECL_KEYWORDS_RE.match(line):
                new_lines.append(body_indent + decl)
                inserted = True

        if not inserted:
            new_body = body_indent + decl + newline + body_text
            source = source[:body_start] + new_body + source[body_start + len(body_text):]
        else:
            new_body = newline.join(new_lines)
            source = source[:body_start] + new_body + source[body_start + len(body_text):]

    return source


def cmd_rm_port(source: str, module_info: Dict, name: str) -> str:
    """Remove a port from module. Returns modified source."""
    name = name.strip()
    mi = module_info
    is_ansi = mi["is_ansi"]
    open_idx = mi["open_idx"]
    close_idx = mi["close_idx"]
    semi_idx = mi["semi_idx"]
    newline = detect_newline(source)

    if open_idx < 0 or close_idx < 0:
        return source

    ports_text = source[open_idx + 1:close_idx]

    if is_ansi:
        # Single forward pass: track prev content row and whether any content
        # row exists after the target (has_next). No temporary index lists.
        name_re = re.compile(rf"\b{re.escape(name)}\b")
        target_row = prev_row = None
        has_next = False
        for row in get_line_spans(ports_text):
            s = row["text"].strip()
            if not s or s.startswith(("//", "/*", "*")):
                continue
            if target_row is None:
                if name_re.search(row["text"]):
                    target_row = row
                else:
                    prev_row = row
            else:
                has_next = True
                break

        if target_row is None:
            return source

        base = open_idx + 1
        edits: List[Tuple[int, int, str]] = []
        edits.append((base + target_row["start"], base + target_row["end_full"], ""))

        if prev_row and not has_next:
            prev_abs_start = base + prev_row["start"]
            prev_abs_end = base + prev_row["end_no_eol"]
            prev_text = source[prev_abs_start:prev_abs_end]
            updated_prev = remove_trailing_comma_from_line(prev_text)
            if updated_prev != prev_text:
                edits.append((prev_abs_start, prev_abs_end, updated_prev))

        source = apply_text_edits(source, edits)
    else:
        names = [x.strip() for x in strip_comments(ports_text).split(",") if x.strip()]
        new_names = [n for n in names if n != name]
        if len(new_names) == len(names):
            return source

        indent = detect_indent(ports_text)
        new_ports_text = ""
        for i, n in enumerate(new_names):
            new_ports_text += indent + n
            if i < len(new_names) - 1:
                new_ports_text += "," + newline
            else:
                new_ports_text += newline

        source = source[:open_idx + 1] + new_ports_text + source[close_idx:]

        if semi_idx >= 0:
            body_start = semi_idx + 1
            body_text = source[body_start:]
            body_spans = get_line_spans(body_text)
            body_edits: List[Tuple[int, int, str]] = []
            name_re = re.compile(rf"\b{re.escape(name)}\b")
            for row in body_spans:
                if re.search(
                    rf"^\s*(input|output|inout|ref|wire|logic|reg|bit|tri|integer|var|signed|unsigned)\b[^;\n]*;",
                    row["text"],
                ) and name_re.search(row["text"]):
                    body_edits.append((body_start + row["start"], body_start + row["end_full"], ""))
            if body_edits:
                source = apply_text_edits(source, body_edits)

    return source


def cmd_add_wire(source: str, module_info: Dict, wire_spec: Union[str, Dict[str, str]]) -> str:
    """Add wire/logic declaration to module body."""
    info = parse_add_wire_spec(wire_spec) if isinstance(wire_spec, str) else wire_spec
    mi = module_info
    semi_idx = mi["semi_idx"]
    newline = detect_newline(source)

    if semi_idx < 0:
        raise ValueError("Cannot locate module body")

    body_start = semi_idx + 1
    body_text = source[body_start:]

    # Idempotency check
    if re.search(
        rf"^\s*(?:input|output|inout|ref|wire|logic|reg|bit|tri|integer|var|signed|unsigned)\b[^;\n]*\b{re.escape(info['name'])}\b[^;\n]*;",
        body_text, flags=re.MULTILINE,
    ):
        return source

    decl = compose_wire_decl(info) + ";"

    matches = list(_ANY_DECL_RE.finditer(body_text))
    if matches:
        last_decl = matches[-1]
        abs_insert = body_start + last_decl.end()
        indent = re.match(r"\s*", last_decl.group(0)).group(0) or detect_indent(body_text)
    else:
        abs_insert = body_start
        indent = detect_indent(body_text)

    insert_text = newline + indent + decl
    source = source[:abs_insert] + insert_text + source[abs_insert:]
    return source


def cmd_rm_wire(source: str, module_info: Dict, name: str) -> str:
    """Remove wire/logic declaration from module body."""
    name = name.strip()
    mi = module_info
    semi_idx = mi["semi_idx"]

    if semi_idx < 0:
        return source

    body_start = semi_idx + 1
    body_text = source[body_start:]
    body_spans = get_line_spans(body_text)
    name_re = re.compile(rf"\b{re.escape(name)}\b")
    edits: List[Tuple[int, int, str]] = []

    for row in body_spans:
        if _WIRE_DECL_RE.search(row["text"]) and name_re.search(row["text"]):
            edits.append((body_start + row["start"], body_start + row["end_full"], ""))

    if not edits:
        return source
    return apply_text_edits(source, edits)


def cmd_add_inst_port(source: str, inst_port_csv: str) -> str:
    """Add .port(wire) to instance connection list."""
    spec = parse_add_inst_port_spec(inst_port_csv)
    instname, port_name, wire = spec["instname"], spec["port"], spec["wire"]
    newline = detect_newline(source)

    open_idx, close_idx = _find_instance_in_source(source, instname)
    conn_block = source[open_idx + 1:close_idx]

    # Idempotency check
    if re.search(rf"\.\s*{re.escape(port_name)}\s*\(", conn_block):
        return source

    new_conn = f".{port_name}({wire})" if wire else f".{port_name}()"
    indent = detect_indent(conn_block)
    edits: List[Tuple[int, int, str]] = []

    # Consume the iterator to find the last .port( match; then compute line
    # bounds only once for that final match instead of on every iteration.
    last_m = None
    for last_m in re.finditer(r"\.\s*[A-Za-z_][A-Za-z0-9_$]*\s*\(", conn_block):
        pass
    last_span = None
    if last_m:
        ls = conn_block.rfind("\n", 0, last_m.start()) + 1
        le = conn_block.find("\n", last_m.start())
        last_span = (ls, le if le >= 0 else len(conn_block))

    if last_span:
        abs_start = open_idx + 1 + last_span[0]
        abs_end = open_idx + 1 + last_span[1]
        line = source[abs_start:abs_end]
        updated = append_comma_to_port_line(line)
        if updated != line:
            edits.append((abs_start, abs_end, updated))

    stripped_cb = conn_block.rstrip(" \t")
    trailing_ws = len(conn_block) - len(stripped_cb)
    has_nl = stripped_cb.endswith("\n") or stripped_cb.endswith("\r")
    prefix = "" if (conn_block and has_nl) else newline
    insert_text = prefix + indent + new_conn + newline
    abs_close = close_idx - trailing_ws
    edits.append((abs_close, abs_close + trailing_ws, insert_text))

    return apply_text_edits(source, edits)


def cmd_rm_inst_port(source: str, inst_port_csv: str) -> str:
    """Remove .port() from instance connection list."""
    spec = parse_rm_inst_port_spec(inst_port_csv)
    instname, port_name = spec["instname"], spec["port"]
    newline = detect_newline(source)

    open_idx, close_idx = _find_instance_in_source(source, instname)
    conn_block = source[open_idx + 1:close_idx]
    conn_spans = get_line_spans(conn_block)

    # Single forward pass: no temporary index lists needed.
    port_re = re.compile(rf"\.\s*{re.escape(port_name)}\s*\(")
    target_row = prev_row = None
    has_next = False
    for row in conn_spans:
        if not _PORT_CONN_LINE_RE.search(row["text"]):
            continue
        if target_row is None:
            if port_re.search(row["text"]):
                target_row = row
            else:
                prev_row = row
        else:
            has_next = True
            break

    if target_row is None:
        return source

    base = open_idx + 1
    edits: List[Tuple[int, int, str]] = []
    edits.append((base + target_row["start"], base + target_row["end_full"], ""))

    if prev_row and not has_next:
        prev_abs_start = base + prev_row["start"]
        prev_abs_end = base + prev_row["end_no_eol"]
        prev_text = source[prev_abs_start:prev_abs_end]
        updated_prev = remove_trailing_comma_from_line(prev_text)
        if updated_prev != prev_text:
            edits.append((prev_abs_start, prev_abs_end, updated_prev))

    return apply_text_edits(source, edits)


# ---------------------------------------------------------------------------
# Instantiation Template
# ---------------------------------------------------------------------------

def cmd_gen_inst(module_info: Dict, include_params: bool = True,
                 instance_name: Optional[str] = None,
                 port_map: Optional[Dict[str, str]] = None) -> str:
    """Generate instantiation template for a module."""
    mod_name = module_info["name"]
    ports = module_info.get("ports", [])
    param_names = module_info.get("param_names", [])
    indent = "    "

    inst_name = (instance_name or f"u_{mod_name}").strip()
    if not inst_name:
        inst_name = f"u_{mod_name}"

    valid_ports = [p for p in ports if p.get("name", "").strip()]
    port_names = [p["name"].strip() for p in valid_ports]
    mapped_names = [
        (port_map or {}).get(pname, pname) for pname in port_names
    ]

    if include_params and param_names:
        params_to_use = param_names
    else:
        params_to_use = []

    lines: List[str] = []

    if params_to_use:
        lines.append(f"{mod_name} #(")
        for idx, pname in enumerate(params_to_use):
            comma = "," if idx < len(params_to_use) - 1 else ""
            lines.append(f"{indent}.{pname}({pname}){comma}")
        lines.append(f") {inst_name} (")
    else:
        lines.append(f"{mod_name} {inst_name} (")

    max_port_len = max((len(pname) for pname in port_names), default=0)
    max_wire_len = max((len(wname) for wname in mapped_names), default=0)

    cores: List[str] = []
    comments: List[str] = []

    for idx, p in enumerate(valid_ports):
        pname = port_names[idx]
        wire_name = mapped_names[idx]
        comma = "," if idx < len(valid_ports) - 1 else ""
        direction = p.get("direction", "").strip()
        ptype = p.get("type", "").strip()
        comment_parts = [direction] if direction else []
        if ptype:
            comment_parts.append(ptype)
        comment = "// " + " ".join(comment_parts) if comment_parts else ""
        core = f"{indent}.{pname:<{max_port_len}}({wire_name:<{max_wire_len}}){comma}"
        cores.append(core)
        comments.append(comment)

    line_width = max((len(core) for core in cores), default=0)
    for idx, core in enumerate(cores):
        comment = comments[idx]
        if comment:
            lines.append(f"{core:<{line_width}} {comment}")
        else:
            lines.append(core)

    lines.append(");")
    return "\n".join(lines)


# ---------------------------------------------------------------------------
# ModuleEditor – OOP API compatible with modeditor.ModuleEditor
# ---------------------------------------------------------------------------

class ModuleEditor:
    """Module editor using verible-verilog-syntax as parsing backend.

    Drop-in replacement for ``modeditor.ModuleEditor`` without the pyslang
    dependency.  Works on a single-module text slice so all byte offsets are
    module-relative.

    Basic usage::

        editor = ModuleEditor.from_file("path/to/file.sv", module_name="foo")
        editor.add_port({"clk": {"direction": "input", "type": "wire", "width": ""}})
        print(editor.module_text)
    """

    def __init__(self, module_text: str) -> None:
        """Initialise from raw module source text (single-module snippet)."""
        self._module_text: str = module_text
        self._cached_parts: Optional[Dict[str, Any]] = None
        self._cache_valid: bool = False

    # ------------------------------------------------------------------
    # Internal helpers
    # ------------------------------------------------------------------

    def _analyze(self) -> None:
        """Re-parse ``_module_text`` with verible via a temp file."""
        fd, tmppath = tempfile.mkstemp(suffix=".sv")
        try:
            # Write raw bytes so Verible's byte offsets stay consistent.
            with os.fdopen(fd, "wb") as fh:
                fh.write(self._module_text.encode("utf-8", errors="ignore"))
            vparser = VeribleParser(tmppath)
            modules = vparser.get_modules()
        finally:
            try:
                os.unlink(tmppath)
            except OSError:
                pass
        if not modules:
            raise ValueError("Module not found in provided text")
        self._cached_parts = modules[0]
        self._cache_valid = True

    def _get_cached_analysis(self) -> Dict[str, Any]:
        if not self._cache_valid or self._cached_parts is None:
            self._analyze()
        assert self._cached_parts is not None
        return self._cached_parts

    def _invalidate_cache(self) -> None:
        self._cache_valid = False

    @staticmethod
    def _pick_module(modules: List[Dict[str, Any]], module_name: Optional[str] = None) -> Dict[str, Any]:
        """Pick one module from *modules*, raising user-facing errors on ambiguity."""
        if not modules:
            raise ValueError("no module found in file")
        if module_name is None:
            if len(modules) > 1:
                names_str = "\n  - ".join(m["name"] for m in modules)
                raise ValueError(
                    f"file contains multiple modules:\n  - {names_str}\n"
                    "Please specify a module name with --module option."
                )
            return modules[0]
        picked = next((m for m in modules if m["name"] == module_name), None)
        if picked is None:
            available = ", ".join(m["name"] for m in modules)
            raise ValueError(
                f"Module '{module_name}' not found. "
                f"Available modules: {available}"
            )
        return picked

    @staticmethod
    def _rebase_module_info(module_info: Dict[str, Any]) -> Dict[str, Any]:
        """Convert absolute module offsets to module-relative offsets."""
        mod_start = module_info["mod_start"]
        mod_end = module_info["mod_end"]
        relative: Dict[str, Any] = dict(module_info)
        for key in ("open_idx", "close_idx", "semi_idx"):
            if relative.get(key, -1) >= 0:
                relative[key] -= mod_start
        relative["mod_start"] = 0
        relative["mod_end"] = mod_end - mod_start
        return relative

    @classmethod
    def _from_source_and_modules(
        cls,
        source_text: str,
        modules: List[Dict[str, Any]],
        module_name: Optional[str] = None,
    ) -> "ModuleEditor":
        """Create an editor from already-parsed source/modules."""
        picked = cls._pick_module(modules, module_name)
        mod_start = picked["mod_start"]
        mod_end = picked["mod_end"]
        instance = cls.__new__(cls)
        instance._module_text = source_text[mod_start:mod_end]
        instance._cached_parts = cls._rebase_module_info(picked)
        instance._cache_valid = True
        return instance

    # ------------------------------------------------------------------
    # Class methods
    # ------------------------------------------------------------------

    @classmethod
    def from_file(
        cls,
        path: "Union[Path, str]",
        module_name: Optional[str] = None,
    ) -> "ModuleEditor":
        """Create a ``ModuleEditor`` from a file path.

        Args:
            path: Path to the ``.v`` / ``.sv`` file.
            module_name: Module to edit.  Required when the file contains more
                than one module.

        Returns:
            A ``ModuleEditor`` instance whose ``_module_text`` is the extracted
            module slice with module-relative byte offsets cached.
        """
        fpath = Path(path)
        if not fpath.exists():
            raise FileNotFoundError(f"file not found: {fpath}")
        vparser = VeribleParser(str(fpath))
        return cls._from_source_and_modules(vparser.source, vparser.get_modules(), module_name)

    @classmethod
    def extract_module_text(
        cls,
        source_text: str,
        module_name: Optional[str] = None,
    ) -> "Tuple[str, Dict[str, int]]":
        """Extract a module's source slice from *source_text*.

        Returns:
            ``(module_text, offset_info)`` where ``offset_info`` contains the
            absolute ``mod_start`` / ``mod_end`` byte positions needed by
            :meth:`replace_module_text`.
        """
        fd, tmppath = tempfile.mkstemp(suffix=".sv")
        try:
            # Write raw bytes (preserve CRLF) so Verible byte offsets are valid.
            with os.fdopen(fd, "wb") as fh:
                fh.write(source_text.encode("utf-8", errors="ignore"))
            vparser = VeribleParser(tmppath)
            modules = vparser.get_modules()
        finally:
            try:
                os.unlink(tmppath)
            except OSError:
                pass

        picked = cls._pick_module(modules, module_name)
        mod_start = picked["mod_start"]
        mod_end = picked["mod_end"]
        return source_text[mod_start:mod_end], {"mod_start": mod_start, "mod_end": mod_end}

    @classmethod
    def replace_module_text(
        cls,
        source_text: str,
        offset_info: Dict[str, int],
        new_module_text: str,
    ) -> str:
        """Substitute an edited module slice back into *source_text*."""
        s = offset_info["mod_start"]
        e = offset_info["mod_end"]
        return source_text[:s] + new_module_text + source_text[e:]

    @classmethod
    def list_modules_in_file(cls, path: "Union[Path, str]") -> List[str]:
        """Return the names of all modules declared in *path*."""
        vparser = VeribleParser(str(path))
        return [m["name"] for m in vparser.get_modules()]

    # ------------------------------------------------------------------
    # Properties
    # ------------------------------------------------------------------

    @property
    def module_text(self) -> str:
        """Current (possibly edited) module source."""
        return self._module_text

    @property
    def module_name(self) -> str:
        return self._get_cached_analysis()["name"]

    @property
    def ports(self) -> List[Dict[str, Any]]:
        return self._get_cached_analysis().get("ports", [])

    @property
    def instances(self) -> List[Dict[str, Any]]:
        return self._get_cached_analysis().get("instances", [])

    @property
    def param_names(self) -> List[str]:
        return self._get_cached_analysis().get("param_names", [])

    @property
    def is_ansi(self) -> bool:
        return self._get_cached_analysis().get("is_ansi", True)

    @property
    def ports_text(self) -> str:
        parts = self._get_cached_analysis()
        o = parts.get("open_idx", -1)
        c = parts.get("close_idx", -1)
        if o < 0 or c < 0:
            return ""
        return self._module_text[o + 1 : c]

    @property
    def body_text(self) -> str:
        parts = self._get_cached_analysis()
        s = parts.get("semi_idx", -1)
        if s < 0:
            return ""
        return self._module_text[s + 1 :]

    # ------------------------------------------------------------------
    # Port editing
    # ------------------------------------------------------------------

    def add_port(
        self, port_dict: Dict[str, Dict[str, str]]
    ) -> "ModuleEditor":
        """Add ports (idempotent).

        Args:
            port_dict: ``{port_name: {direction, type, width, dimension}}``
        """
        for name, attrs in port_dict.items():
            name = name.strip()
            direction = attrs.get("direction", "").strip().lower()
            if not name:
                raise ValueError("name is required")
            if direction and direction not in {"input", "output", "inout", "ref"}:
                raise ValueError("direction must be input/output/inout/ref")
            info: Dict[str, str] = {
                "direction": direction,
                "type": attrs.get("type", "").strip(),
                "width": normalize_width(attrs.get("width", "")),
                "name": name,
                "dimension": normalize_dimension(attrs.get("dimension", "")),
            }
            parts = self._get_cached_analysis()
            self._module_text = cmd_add_port(self._module_text, parts, info)
            self._invalidate_cache()
        return self

    def rm_port(self, name: str) -> "ModuleEditor":
        """Remove a port by name (idempotent)."""
        parts = self._get_cached_analysis()
        self._module_text = cmd_rm_port(self._module_text, parts, name)
        self._invalidate_cache()
        return self

    # ------------------------------------------------------------------
    # Wire editing
    # ------------------------------------------------------------------

    def add_wire(
        self, wire_dict: Dict[str, Dict[str, str]]
    ) -> "ModuleEditor":
        """Add wire/logic declarations (idempotent).

        Args:
            wire_dict: ``{signal_name: {type, width, dimension}}``
        """
        for name, attrs in wire_dict.items():
            name = name.strip()
            if not name:
                raise ValueError("name is required")
            info: Dict[str, str] = {
                "type": attrs.get("type", "wire").strip() or "wire",
                "width": normalize_width(attrs.get("width", "")),
                "name": name,
                "dimension": normalize_dimension(attrs.get("dimension", "")),
            }
            parts = self._get_cached_analysis()
            self._module_text = cmd_add_wire(self._module_text, parts, info)
            self._invalidate_cache()
        return self

    def rm_wire(self, name: str) -> "ModuleEditor":
        """Remove a wire/logic declaration by name (idempotent)."""
        parts = self._get_cached_analysis()
        self._module_text = cmd_rm_wire(self._module_text, parts, name)
        self._invalidate_cache()
        return self

    # ------------------------------------------------------------------
    # Instance-port editing
    # ------------------------------------------------------------------

    def add_inst_port(
        self, inst_port_dict: Dict[str, Dict[str, Dict[str, str]]]
    ) -> "ModuleEditor":
        """Add ``.port(wire)`` connections to instances (idempotent).

        Args:
            inst_port_dict:
                ``{inst_name: {port_name: {"wire": signal_name}}}``
        """
        for instname, ports in inst_port_dict.items():
            for port_name, wire_info in ports.items():
                wire = wire_info.get("wire", "")
                self._module_text = cmd_add_inst_port(
                    self._module_text, f"{instname},{port_name},{wire}"
                )
                self._invalidate_cache()
        return self

    def rm_inst_port(self, *, instname: str, name: str) -> "ModuleEditor":
        """Remove a ``.port()`` connection from an instance (idempotent)."""
        self._module_text = cmd_rm_inst_port(self._module_text, f"{instname},{name}")
        self._invalidate_cache()
        return self

    # ------------------------------------------------------------------
    # Analysis / generation
    # ------------------------------------------------------------------

    def gen_inst(
        self,
        include_params: bool = True,
        instance_name: Optional[str] = None,
        port_map: Optional[Dict[str, str]] = None,
        indent: str = "    ",
    ) -> str:
        """Generate an instantiation template string."""
        parts = self._get_cached_analysis()
        return cmd_gen_inst(
            parts,
            include_params=include_params,
            instance_name=instance_name,
            port_map=port_map,
        )

    def analyze(self) -> Dict[str, Any]:
        """Return the full analysis dict for this module.

        Keys include ``name`` (module name), ``ports``, ``instances``,
        ``param_names``, ``is_ansi``, ``module_text``, ``ports_text``,
        ``body_text``, and raw offset fields.
        """
        cached = dict(self._get_cached_analysis())
        # Add convenience aliases matching modeditor's analyze() output
        cached.setdefault("module_name", cached.get("name", ""))
        cached["module_text"] = self._module_text
        o = cached.get("open_idx", -1)
        c = cached.get("close_idx", -1)
        s = cached.get("semi_idx", -1)
        cached["ports_text"] = self._module_text[o + 1 : c] if o >= 0 and c >= 0 else ""
        cached["body_text"] = self._module_text[s + 1 :] if s >= 0 else ""
        return cached

    def get_hier(self) -> Dict[str, Any]:
        """Return hierarchy info: ``{"module": name, "instances": [...]}``."""
        cached = self._get_cached_analysis()
        return {
            "module": cached.get("name", ""),
            "instances": cached.get("instances", []),
        }
