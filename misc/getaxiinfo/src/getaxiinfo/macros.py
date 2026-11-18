"""Read object-like HDL constants and evaluate integer expressions without eval."""

import ast
import operator
import re
import sys
from typing import Dict, Optional, Tuple


TARGET_MACROS = (
    "CC_DEVICE_TYPE", "CX_NL", "CX_MAX_PCIE_SPEED", "CX_MAX_MTU",
    "CX_NFUNC", "CX_SRIOV_ENABLE", "CX_NVFUNC", "CX_INTERNAL_NVFUNC",
    "CX_EXTENSIBLE_VFUNC", "DYNAMIC_VF_ENABLE", "AMBA_INTERFACE",
    "AXI_POPULATED", "MASTER_POPULATED", "SLAVE_POPULATED",
    "DBI_4SLAVE_POPULATED", "SHARED_DBI_ENABLED", "CC_HP_MASTER",
    "AXI_MSTR_CLK_FREQ", "AXI_SLV_CLK_FREQ", "DBI_SLV_CLK_FREQ",
    "MSTR_CLK_DIFF_ENABLE", "SLV_CLK_DIFF_ENABLE",
    "MASTER_BUS_ADDR_WIDTH", "MASTER_BUS_DATA_WIDTH",
    "CC_MSTR_BUS_ADDR_WIDTH", "CC_MSTR_BUS_DATA_WIDTH", "CX_RAS_EN",
    "SLAVE_BUS_ADDR_WIDTH", "SLAVE_BUS_DATA_WIDTH",
    "CC_MSTR_BUS_ID_WIDTH", "CC_SLV_BUS_ID_WIDTH", "CC_DBI_SLV_ID_WD",
    "CC_DBI_SLV_BUS_ADDR_WIDTH", "CC_DBI_SLV_BUS_DATA_WIDTH",
    "CC_MSTR_BURST_LEN", "CC_SLV_BURST_LEN", "CC_DBI_BURST_LEN",
    "CC_MAX_MSTR_TAGS_AXI", "CC_MAX_MSTRH_TAGS_AXI", "CC_MAX_SLV_TAG",
    "CC_SLV_NUM_OUTSTND_WR_REQ", "CC_SLV_NUM_OUTSTND_CPU_WR_REQ",
    "RADM_MAX_OUTSTD_P_REQ", "CC_WR_CH_P_REQ_QUEUE_DP", "WR_CH_P_REQ_QUEUE_DP",
    "CX_AXI_RCHUNK_ENABLE", "CX_MAX_TAG", "CC_DMA_ENABLE",
    "CX_DMA_PF_ENABLE", "CC_LEGACY_DMA_MAP", "CC_NUM_DMA_RD_CHAN",
    "CC_NUM_DMA_WR_CHAN", "CC_NUM_DMA_RD_TAG", "CX_DMA_RD_LLQ", "CX_DMA_WR_LLQ",
    "CX_INTERNAL_ATU_ENABLE", "CX_ATU_NUM_INBOUND_REGIONS",
    "CX_ATU_NUM_OUTBOUND_REGIONS", "CC_UNROLL_ENABLE", "CC_UNROLL_EN",
    "ENABLE_MEM_MAP_UNROLL_DMA_REG", "ENABLE_MEM_MAP_UNROLL_ATU_REG",
    "UNROLL_FUNC_NUM", "UNROLL_BAR_NUM", "UNROLL_DMA_OFFSET_BAR",
    "UNROLL_ATU_OFFSET_BAR", "UNROLL_DMA_SIZE", "UNROLL_ATU_SIZE",
    "ENABLE_MEM_MAP_PL_REG", "PL_FUNC_NUM", "PL_BAR_NUM", "PL_OFFSET_BAR",
    "MSI_CAP_ENABLE", "MSIX_CAP_ENABLE", "VF_MSIX_CAP_ENABLE", "MSIX_TABLE_EN",
)

INDEXED_BASES = (
    "CX_MAX_VF", "MSIX_TABLE_BIR", "MSIX_TABLE_OFFSET", "MSIX_PBA_BIR",
    "MSIX_PBA_OFFSET", "MSIX_TABLE_SIZE", "VF_MSIX_TABLE_BIR",
    "VF_MSIX_TABLE_OFFSET", "VF_MSIX_PBA_BIR", "VF_MSIX_PBA_OFFSET",
)
CONTROLLER_ANCHORS = ("CC_DEVICE_TYPE", "CX_NL", "CX_MAX_PCIE_SPEED", "AMBA_INTERFACE")
BOOLEAN_MACROS = frozenset((
    "CX_SRIOV_ENABLE", "CX_EXTENSIBLE_VFUNC", "DYNAMIC_VF_ENABLE",
    "AXI_POPULATED", "MASTER_POPULATED", "SLAVE_POPULATED",
    "DBI_4SLAVE_POPULATED", "SHARED_DBI_ENABLED", "CC_HP_MASTER",
    "MSTR_CLK_DIFF_ENABLE", "SLV_CLK_DIFF_ENABLE", "CX_RAS_EN",
    "CX_AXI_RCHUNK_ENABLE", "CC_DMA_ENABLE", "CX_DMA_PF_ENABLE",
    "CC_LEGACY_DMA_MAP", "CX_INTERNAL_ATU_ENABLE", "CC_UNROLL_ENABLE",
    "CC_UNROLL_EN", "ENABLE_MEM_MAP_UNROLL_DMA_REG",
    "ENABLE_MEM_MAP_UNROLL_ATU_REG", "ENABLE_MEM_MAP_PL_REG",
    "MSI_CAP_ENABLE", "MSIX_CAP_ENABLE", "VF_MSIX_CAP_ENABLE", "MSIX_TABLE_EN",
))
# These are independent feature macros, even when their suffix is a target.
# Recognize them when no controller anchor is present, without adding them to
# the extracted/report fields.
RELATED_MACROS = frozenset((
    "VF_MSI_CAP_ENABLE", "EXT_VF_MSI_CAP_ENABLE", "EXT_VF_MSIX_CAP_ENABLE",
))
_INDEXED_RE = re.compile(
    r"(?:^|_)(" + "|".join(sorted(INDEXED_BASES, key=len, reverse=True)) + r")_(\d+)$"
)
DEFINE_RE = re.compile(r"^\s*`define\s+([A-Za-z_][A-Za-z0-9_]*)(.*)$")
_COMMENTS_RE = re.compile(r'"(?:\\.|[^"\\])*"|//[^\n]*|/\*.*?\*/', re.S)
_LITERAL_RE = re.compile(r"(?<![\w'])\d*'[sS]?[dDhHbBoO][0-9a-fA-F_xXzZ?]+")
_BINARY = {
    ast.Add: operator.add, ast.Sub: operator.sub, ast.Mult: operator.mul,
    ast.Div: lambda a, b: (abs(a) // abs(b)) * (-1 if (a < 0) != (b < 0) else 1),
    ast.BitAnd: operator.and_, ast.BitOr: operator.or_, ast.BitXor: operator.xor,
    ast.LShift: operator.lshift, ast.RShift: operator.rshift,
}
_COMPARE = {
    ast.Eq: operator.eq, ast.NotEq: operator.ne, ast.Lt: operator.lt,
    ast.LtE: operator.le, ast.Gt: operator.gt, ast.GtE: operator.ge,
}


class MacroValues(dict):
    """Raw target values, with dependency definitions and source provenance."""

    def __init__(self):
        super().__init__()
        self.definitions = {}  # type: Dict[str, str]
        self.actual_names = {}  # type: Dict[str, str]
        self.rules = {}  # type: Dict[str, str]
        self.files = []


class ParsedDefines(dict):
    """Active definitions and explicit disabled configuration placeholders.

    Placeholders never enter the definitions used to evaluate ifdef conditions.
    """

    def __init__(self):
        super().__init__()
        self.disabled = {}


def resolve_target_macro_name(name, target_set, controller_prefix=None):
    if controller_prefix is not None:
        if controller_prefix and name.startswith(controller_prefix):
            name = name[len(controller_prefix):]
        if name in target_set:
            return name
        match = _INDEXED_RE.fullmatch(name)
        return "{}_{}".format(*match.groups()) if match else None
    if name in target_set:
        return name
    for target in sorted(set(target_set) | RELATED_MACROS, key=len, reverse=True):
        if name == target or name.endswith("_" + target):
            return target if target in target_set else None
    match = _INDEXED_RE.search(name)
    return "{}_{}".format(*match.groups()) if match else None


def _strip_comments(text, keep_line_comments=False):
    def replace(match):
        value = match.group()
        return value if value.startswith('"') or (keep_line_comments and value.startswith("//")) else " " + "\n" * value.count("\n")
    return _COMMENTS_RE.sub(replace, text)


def parse_defines(file_path):
    """Honor local ifdef/ifndef/elsif/else/endif/undef and retain physical lines.

    External include files and compiler -D options are not supplied by this tool.
    """
    text = file_path.read_text(encoding="utf-8-sig")
    original = text.splitlines()
    lines = _strip_comments(text).splitlines()
    comment_lines = _strip_comments(text, keep_line_comments=True).splitlines()
    found = ParsedDefines()
    stack = []
    active = True
    i = 0
    while i < len(lines):
        line = lines[i]
        line_no = i + 1
        while line.rstrip().endswith("\\") and i + 1 < len(lines):
            line = line.rstrip()[:-1] + " " + lines[i + 1].strip()
            i += 1
        i += 1
        directive = re.match(r"^\s*`(ifdef|ifndef|elsif|else|endif|undef)\b\s*(\w*)", line)
        if directive:
            kind, name = directive.groups()
            if kind in ("ifdef", "ifndef"):
                condition = (name in found) == (kind == "ifdef")
                stack.append([active, condition])
                active = active and condition
            elif kind == "elsif" and stack:
                parent, taken = stack[-1]
                condition = not taken and name in found
                stack[-1][1] = taken or condition
                active = parent and condition
            elif kind == "else" and stack:
                parent, taken = stack[-1]
                active = parent and not taken
                stack[-1][1] = True
            elif kind == "endif" and stack:
                active = stack.pop()[0]
            elif kind == "undef" and active:
                found.pop(name, None)
                found.disabled.pop(name, None)
            continue
        disabled = re.fullmatch(r"\s*//\s*`define\s+([A-Za-z_]\w*)\s*", comment_lines[line_no - 1]) if active else None
        if disabled:
            found.disabled[disabled.group(1)] = ("0", line_no, original[line_no - 1])
        match = DEFINE_RE.match(line) if active else None
        if not match:
            continue
        name, rest = match.groups()
        # Function macros have an opening parenthesis immediately after the name.
        if rest.startswith("("):
            continue
        found[name] = (rest.strip() or "1", line_no, original[line_no - 1])
    return found


def _literal(match):
    width, value = match.group().split("'", 1)
    signed = value[0].lower() == "s"
    value = value[1:] if signed else value
    base = {"d": 10, "h": 16, "b": 2, "o": 8}[value[0].lower()]
    digits = value[1:].replace("_", "")
    if re.search("[xXzZ?]", digits):
        raise ValueError("unknown or high-impedance literal")
    number = int(digits, base)
    if width:
        bits = int(width)
        if bits < 1 or bits > 4096:
            raise ValueError("unsupported literal width")
        number &= (1 << bits) - 1
        if signed and number & (1 << (bits - 1)):
            number -= 1 << bits
    return "({})".format(number)


class NumericResolver:
    def __init__(self, values):
        self.values = values
        self.definitions = getattr(values, "definitions", values)
        self.actual_names = getattr(values, "actual_names", {})
        self.cache = {}
        self.errors = {}
        self.used = set()

    def number(self, name):
        self.used.add(name)
        if name in self.cache:
            return self.cache[name]
        actual = self.actual_names.get(name, name)
        raw = self.values.get(name)
        if raw is None:
            raw = self.definitions.get(actual)
        try:
            if raw is None:
                raise ValueError("macro not found")
            result = self._expression(raw, (actual,))
            self.cache[name] = result
            return result
        except (ValueError, TypeError, SyntaxError, ArithmeticError, RecursionError) as exc:
            self.errors[name] = str(exc) or "unsupported expression"
            self.cache[name] = None
            return None

    def _expression(self, raw, trail):
        if len(trail) > 64 or len(raw) > 16384:
            raise ValueError("macro expression too complex")
        expr = _LITERAL_RE.sub(_literal, raw)
        expr = re.sub(r"'([01])\b", r"\1", expr)
        expr = re.sub(r"`([A-Za-z_]\w*)", r"\1", expr)
        expr = expr.replace("&&", " and ").replace("||", " or ")
        expr = re.sub(r"!(?!=)", " not ", expr)
        expr = expr.replace("$clog2", "clog2")
        # Convert Verilog conditional expressions, retaining lazy branch evaluation.
        expr = expr.strip()
        while expr.startswith("(") and expr.endswith(")"):
            depth = 0
            closes_at_end = True
            for index, char in enumerate(expr):
                depth += (char == "(") - (char == ")")
                if depth == 0 and index != len(expr) - 1:
                    closes_at_end = False
                    break
            if not closes_at_end:
                break
            expr = expr[1:-1].strip()
        depth = 0
        question = None
        nesting = 0
        for index, char in enumerate(expr):
            depth += (char == "(") - (char == ")")
            if depth == 0 and char == "?":
                if question is None:
                    question = index
                nesting += 1
            elif depth == 0 and char == ":" and question is not None:
                nesting -= 1
                if nesting == 0:
                    condition = self._expression(expr[:question], trail)
                    branch = expr[question + 1:index] if condition else expr[index + 1:]
                    return self._expression(branch, trail)
        return self._node(ast.parse(expr, mode="eval").body, trail)

    def _node(self, node, trail):
        if isinstance(node, ast.Constant) and isinstance(node.value, int):
            return node.value
        if sys.version_info < (3, 8) and isinstance(node, ast.Num) and isinstance(node.n, int):
            return node.n
        if isinstance(node, ast.Name):
            name = node.id
            if name in trail:
                raise ValueError("cyclic macro reference: " + name)
            raw = self.definitions.get(name)
            if raw is None:
                raw = self.values.get(name)
            if raw is None:
                raise ValueError("unresolved macro reference: " + name)
            return self._expression(raw, trail + (name,))
        if isinstance(node, ast.UnaryOp):
            value = self._node(node.operand, trail)
            if isinstance(node.op, ast.USub):
                return -value
            if isinstance(node.op, ast.UAdd):
                return value
            if isinstance(node.op, ast.Invert):
                return ~value
            if isinstance(node.op, ast.Not):
                return int(not value)
        if isinstance(node, ast.BinOp):
            left, right = self._node(node.left, trail), self._node(node.right, trail)
            if isinstance(node.op, (ast.LShift, ast.RShift, ast.Pow)) and not 0 <= right <= 4096:
                raise ValueError("unsupported shift or exponent")
            if isinstance(node.op, ast.Pow):
                if abs(left).bit_length() * right > 4096:
                    raise ValueError("expression result too large")
                return left ** right
            if isinstance(node.op, ast.Mod):
                quotient = _BINARY[ast.Div](left, right)
                return left - quotient * right
            function = _BINARY.get(type(node.op))
            if function:
                result = function(left, right)
                if result.bit_length() > 4096:
                    raise ValueError("expression result too large")
                return result
        if isinstance(node, ast.BoolOp):
            if isinstance(node.op, ast.And):
                return int(all(self._node(value, trail) != 0 for value in node.values))
            return int(any(self._node(value, trail) != 0 for value in node.values))
        if isinstance(node, ast.Compare) and len(node.ops) == 1:
            function = _COMPARE.get(type(node.ops[0]))
            if function:
                return int(function(self._node(node.left, trail), self._node(node.comparators[0], trail)))
        if isinstance(node, ast.Call) and isinstance(node.func, ast.Name):
            if node.func.id == "clog2" and len(node.args) == 1 and not node.keywords:
                value = self._node(node.args[0], trail)
                if value >= 0:
                    return (value - 1).bit_length() if value else 0
        raise ValueError("unsupported expression")


def parse_numeric_value(raw_value: Optional[str], macros=None) -> Optional[int]:
    values = dict(macros or {})
    values["<expression>"] = raw_value
    return NumericResolver(values).number("<expression>")
