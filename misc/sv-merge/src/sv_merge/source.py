"""Lexical helpers; these do not evaluate SystemVerilog macros."""
import re


def mask_comments(text):
    """Hide comments while preserving offsets, newlines and quoted strings."""
    pattern = r'"(?:\\.|[^"\\])*"|//[^\n]*|/\*.*?\*/'

    def replace(match):
        value = match.group(0)
        if value.startswith('"'):
            return value
        return ''.join('\n' if c == '\n' else ' ' for c in value)

    return re.sub(pattern, replace, text, flags=re.S)


def read_source(path):
    with open(path, encoding='utf-8') as stream:
        return stream.read()
