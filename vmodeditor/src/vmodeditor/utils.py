"""Reusable utilities for Verilog/SystemVerilog parsing and module analysis.

Uses verible-verilog-syntax CST (Concrete Syntax Tree) for precise source
code navigation and editing.
"""

import json
import re
import shutil
import subprocess
from pathlib import Path
from typing import Any, Dict, List, Optional, Set, Tuple


# ---------------------------------------------------------------------------
# Verible executable
# ---------------------------------------------------------------------------

VERIBLE = shutil.which("verible-verilog-syntax") or r"C:\Users\man\Desktop\code\verible\verible-verilog-syntax.exe"


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

_KEYWORD_NAME_SET = frozenset({
    "module", "endmodule", "begin", "end", "if", "else",
    "for", "function", "endfunction", "task", "endtask",
    "generate", "endgenerate", "case", "endcase", "default",
})


# ---------------------------------------------------------------------------
# CST Traversal Utilities
# ---------------------------------------------------------------------------

def find_all(node: Any, tag: str) -> List[Dict]:
    """Find all descendant nodes with given tag (recursive)."""
    results: List[Dict] = []
    if not isinstance(node, dict):
        return results
    if node.get("tag") == tag:
        results.append(node)
    for c in node.get("children", []):
        if isinstance(c, dict):
            results.extend(find_all(c, tag))
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
    """Find first descendant with given tag (recursive)."""
    if not isinstance(node, dict):
        return None
    if node.get("tag") == tag:
        return node
    for c in node.get("children", []):
        if isinstance(c, dict):
            r = find_descendant(c, tag)
            if r:
                return r
    return None


def get_node_range(node: Dict) -> Tuple[int, int]:
    """Get (min_start, max_end) from all leaf nodes in subtree."""
    if not isinstance(node, dict):
        return (999999, -1)
    if "start" in node and "end" in node:
        return (node["start"], node["end"])
    starts: List[int] = []
    ends: List[int] = []
    for c in node.get("children", []):
        if isinstance(c, dict):
            s, e = get_node_range(c)
            if s < 999999:
                starts.append(s)
            if e > 0:
                ends.append(e)
        elif c is None:
            pass
    return (min(starts) if starts else 999999, max(ends) if ends else -1)


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
    width = width.strip()
    if not width:
        return ""
    if width.startswith("[") and width.endswith("]"):
        return width
    return f"[{width}]"


def normalize_dimension(dimension: str) -> str:
    """Normalize dimension string to [a:b][c:d] form."""
    dimension = dimension.strip()
    if not dimension:
        return ""
    bracket_groups = re.findall(r"\[\s*([^\]]+?)\s*\]", dimension)
    if bracket_groups:
        return "".join(f"[{grp.strip()}]" for grp in bracket_groups)
    parts = [p.strip() for p in split_csv(dimension) if p.strip()]
    if parts:
        return "".join(f"[{p}]" for p in parts)
    return f"[{dimension}]"


def detect_indent(block_text: str, default: str = "    ") -> str:
    """Detect indentation from text block."""
    for ln in block_text.splitlines():
        if not ln.strip():
            continue
        m = re.match(r"\s*", ln)
        return m.group(0) if m.group(0) else default
    return default


def detect_newline(text: str) -> str:
    """Detect newline style used in text."""
    if "\r\n" in text:
        return "\r\n"
    return "\n"


def looks_like_width_or_dimension(token: str) -> bool:
    token = token.strip()
    if not token:
        return False
    if token.startswith("[") and token.endswith("]"):
        return True
    return ":" in token


def looks_like_name(token: str) -> bool:
    return bool(re.match(r"^`?[A-Za-z_][A-Za-z0-9_$]*$", token.strip()))


def append_comma_to_port_line(line: str) -> str:
    """Append comma to code end, preserving inline comments and newline."""
    newline = ""
    if line.endswith("\r\n"):
        newline = "\r\n"
        core = line[:-2]
    elif line.endswith("\n"):
        newline = "\n"
        core = line[:-1]
    else:
        core = line
    comment_idx = core.find("//")
    if comment_idx >= 0:
        code_part = core[:comment_idx].rstrip()
        comment_part = core[comment_idx:]
    else:
        code_part = core.rstrip()
        comment_part = ""
    if code_part.endswith(","):
        return core + newline
    updated = code_part + ","
    if comment_part:
        updated += " " + comment_part.lstrip()
    return updated + newline


def remove_trailing_comma_from_line(line: str) -> str:
    """Remove trailing comma from code end, preserving inline comments and newline."""
    newline = ""
    if line.endswith("\r\n"):
        newline = "\r\n"
        core = line[:-2]
    elif line.endswith("\n"):
        newline = "\n"
        core = line[:-1]
    else:
        core = line
    comment_idx = core.find("//")
    if comment_idx >= 0:
        code_part = core[:comment_idx].rstrip()
        comment_part = core[comment_idx:]
    else:
        code_part = core.rstrip()
        comment_part = ""
    code_part = re.sub(r",\s*$", "", code_part)
    updated = code_part
    if comment_part:
        updated += " " + comment_part.lstrip()
    return updated + newline


def get_line_spans(block_text: str) -> List[Dict[str, Any]]:
    """Split text into lines, each with start/end_no_eol/end_full/text/raw."""
    lines = block_text.splitlines(keepends=True)
    spans: List[Dict[str, Any]] = []
    offset = 0
    for line in lines:
        no_eol = line.rstrip("\r\n")
        end_no_eol = offset + len(no_eol)
        end_full = offset + len(line)
        spans.append({
            "start": offset,
            "end_no_eol": end_no_eol,
            "end_full": end_full,
            "text": no_eol,
            "raw": line,
        })
        offset = end_full
    if not lines and block_text:
        spans.append({
            "start": 0,
            "end_no_eol": len(block_text),
            "end_full": len(block_text),
            "text": block_text,
            "raw": block_text,
        })
    return spans


def apply_text_edits(text: str, edits: List[Tuple[int, int, str]]) -> str:
    """Apply (start, end, replacement) edits back-to-front."""
    if not edits:
        return text
    for start, end, replacement in sorted(edits, key=lambda e: (e[0], e[1]), reverse=True):
        text = text[:start] + replacement + text[end:]
    return text


def compose_port_decl(info: Dict[str, str]) -> str:
    """Compose a port declaration string from info dict."""
    parts = [info["direction"]]
    if info.get("type"):
        parts.append(info["type"])
    if info.get("width"):
        parts.append(info["width"])
    parts.append(info["name"])
    if info.get("dimension"):
        parts.append(info["dimension"])
    return " ".join(p for p in parts if p)


def compose_wire_decl(info: Dict[str, str]) -> str:
    """Compose a wire/logic declaration string from info dict."""
    parts = [info["type"]]
    if info.get("width"):
        parts.append(info["width"])
    parts.append(info["name"])
    if info.get("dimension"):
        parts.append(info["dimension"])
    return " ".join(p for p in parts if p)


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

    @property
    def data(self) -> Dict:
        if self._data is None:
            self._parse()
        return self._data

    def _parse(self) -> None:
        result = subprocess.run(
            [VERIBLE, "--export_json", "--printtree", "--printtokens", self.filepath],
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
        mods = find_all(self.tree, "kModuleDeclaration")
        result = []
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

        port_start, port_end = get_node_range(pd_node)
        port_text = self.source[port_start:port_end]
        port_text_clean = strip_comments(port_text)

        # Direction
        for d in ("input", "output", "inout", "ref"):
            if re.search(rf"\b{d}\b", port_text_clean):
                direction = d
                break

        # Port name: the LAST SymbolIdentifier that is not a keyword or type.
        all_ids = find_all(pd_node, "SymbolIdentifier")
        candidate_ids = []
        for leaf_id in all_ids:
            text = self.get_text(leaf_id).strip()
            if text in _KEYWORD_SET or text in _COMMON_TYPES:
                ptype = text if text in _COMMON_TYPES and not ptype else ptype
                continue
            candidate_ids.append(text)

        if candidate_ids:
            name = candidate_ids[-1]

        # Width: look for bracket group [...] or [expression]
        brackets = find_all(pd_node, "kBracketGroup")
        if not brackets:
            bracket_matches = re.findall(r"\[[^\]]*\]", port_text_clean)
            if bracket_matches:
                width = bracket_matches[-1].strip()
        else:
            for bg in brackets:
                s, e = get_node_range(bg)
                width = self.source[s:e].strip()

        if not name:
            return None

        return {"name": name, "direction": direction, "type": ptype, "width": width}

    def _fill_non_ansi_port(self, port: Dict[str, str], body_text: str) -> None:
        """Fill direction/type/width for non-ANSI port from body declarations."""
        pname = re.escape(port["name"])
        m = re.search(
            rf"^\s*(input|output|inout|ref)"
            rf"(?:\s+(wire|reg|logic|bit|tri|integer|signed|unsigned))?"
            rf"(\s*\[[^\]]*\])?"
            rf"\s+{pname}\b",
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
        """Extract instances from module body via regex."""
        mod_start, mod_end = get_node_range(mod_node)
        module_text = self.source[mod_start:mod_end]

        instances: List[Dict[str, str]] = []
        for m in re.finditer(
            r"^\s*([A-Za-z_]\w*)\s+(?:#\s*\(.*?\)\s*)?([A-Za-z_]\w*)\s*\(",
            module_text,
            re.MULTILINE | re.DOTALL,
        ):
            inst_type = m.group(1)
            inst_name = m.group(2)
            if inst_type in _KEYWORD_SET:
                continue
            if inst_name in _KEYWORD_NAME_SET:
                continue
            line_start = module_text.rfind("\n", 0, m.start()) + 1
            line_prefix = module_text[line_start:m.start()].strip()
            if re.match(r"^\s*(input|output|inout|ref)\b", line_prefix):
                continue
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

def _find_matching_paren(text: str, open_idx: int) -> int:
    """Find matching ')' from open_idx '(' position."""
    stack: List[int] = []
    for idx in range(open_idx, len(text)):
        ch = text[idx]
        if ch == "(":
            stack.append(idx)
        elif ch == ")":
            if stack:
                stack.pop()
                if not stack:
                    return idx
    return -1


def _find_instance_in_source(source: str, instname: str) -> Tuple[int, int]:
    """Find instance connection bounds in source text. Returns (open_paren, close_paren)."""
    inst_m = None
    for m in re.finditer(rf"\b{re.escape(instname)}\b\s*\(", source):
        line_start = source.rfind("\n", 0, m.start()) + 1
        if re.match(r"^\s*//", source[line_start:m.start() + 1]):
            continue
        inst_m = m
        break
    if not inst_m:
        raise ValueError(f"Instance '{instname}' not found")
    open_idx = source.find("(", inst_m.start())
    close_idx = _find_matching_paren(source, open_idx)
    if close_idx < 0:
        raise ValueError("Instance connection list is unbalanced")
    return open_idx, close_idx


def cmd_add_port(source: str, module_info: Dict, port_csv: str) -> str:
    """Add port(s) to module. Returns modified source."""
    info = parse_add_port_spec(port_csv)
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
        port_spans = get_line_spans(ports_text)
        item_idxs = [
            i for i, row in enumerate(port_spans)
            if (s := row["text"].strip())
            and not s.startswith("//")
            and not s.startswith("/*")
            and not s.startswith("*")
        ]
        edits: List[Tuple[int, int, str]] = []

        if item_idxs:
            last_idx = item_idxs[-1]
            last = port_spans[last_idx]
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
        port_spans = get_line_spans(ports_text)
        item_idxs = [
            i for i, row in enumerate(port_spans)
            if (s := row["text"].strip())
            and not s.startswith("//")
            and not s.startswith("/*")
            and not s.startswith("*")
        ]
        target_idx = None
        for i in item_idxs:
            if re.search(rf"\b{re.escape(name)}\b", port_spans[i]["text"]):
                target_idx = i
                break
        if target_idx is None:
            return source

        edits: List[Tuple[int, int, str]] = []
        base = open_idx + 1
        target = port_spans[target_idx]
        edits.append((base + target["start"], base + target["end_full"], ""))

        prev_items = [i for i in item_idxs if i < target_idx]
        next_items = [i for i in item_idxs if i > target_idx]
        if prev_items and not next_items:
            prev_idx = prev_items[-1]
            prev = port_spans[prev_idx]
            prev_abs_start = base + prev["start"]
            prev_abs_end = base + prev["end_no_eol"]
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


def cmd_add_wire(source: str, module_info: Dict, wire_csv: str) -> str:
    """Add wire/logic declaration to module body."""
    info = parse_add_wire_spec(wire_csv)
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
        line_indent_match = re.match(r"\s*", last_decl.group(0))
        indent = line_indent_match.group(0) if line_indent_match and line_indent_match.group(0) else detect_indent(body_text)
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


def cmd_add_inst_port(source: str, module_info: Dict, inst_port_csv: str) -> str:
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

    last_span = None
    for m in re.finditer(r"\.\s*[A-Za-z_][A-Za-z0-9_$]*\s*\(", conn_block):
        line_start = conn_block.rfind("\n", 0, m.start()) + 1
        line_end = conn_block.find("\n", m.start())
        if line_end < 0:
            line_end = len(conn_block)
        last_span = (line_start, line_end)

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


def cmd_rm_inst_port(source: str, module_info: Dict, inst_port_csv: str) -> str:
    """Remove .port() from instance connection list."""
    spec = parse_rm_inst_port_spec(inst_port_csv)
    instname, port_name = spec["instname"], spec["port"]
    newline = detect_newline(source)

    open_idx, close_idx = _find_instance_in_source(source, instname)
    conn_block = source[open_idx + 1:close_idx]
    conn_spans = get_line_spans(conn_block)

    item_idxs: List[int] = []
    target_idx: Optional[int] = None
    for i, row in enumerate(conn_spans):
        if _PORT_CONN_LINE_RE.search(row["text"]):
            item_idxs.append(i)
            if re.search(rf"\.\s*{re.escape(port_name)}\s*\(", row["text"]):
                target_idx = i

    if target_idx is None:
        return source

    edits: List[Tuple[int, int, str]] = []
    base = open_idx + 1
    target = conn_spans[target_idx]
    edits.append((base + target["start"], base + target["end_full"], ""))

    prev_items = [i for i in item_idxs if i < target_idx]
    next_items = [i for i in item_idxs if i > target_idx]
    if prev_items and not next_items:
        prev_idx = prev_items[-1]
        prev = conn_spans[prev_idx]
        prev_abs_start = base + prev["start"]
        prev_abs_end = base + prev["end_no_eol"]
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
