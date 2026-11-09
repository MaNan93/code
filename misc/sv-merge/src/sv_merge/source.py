"""Lexical helpers; these do not evaluate SystemVerilog macros."""
import re


# String literals are matched first so quotes always win. Line comments honor
# backslash-newline continuations (IEEE 1800-2017 22.5.1) and block comments
# do not nest, matching simulator behavior. The bare `/*` alternative only
# fires when the comment never closes, which is reported as an error.
_TOKEN = re.compile(
    r'"(?:\\.|[^"\\])*"'
    r'|//[^\n\\]*(?:\\(?!\r?\n)[^\n\\]*|\\\r?\n[^\n\\]*)*'
    r'|/\*.*?\*/'
    r'|/\*',
    re.S,
)


def _mask(match):
    value = match.group(0)
    if value.startswith('"'):
        return value
    if value == '/*':
        raise ValueError('Unterminated block comment')
    return ''.join('\n' if c == '\n' else ' ' for c in value)


def _delete(match):
    value = match.group(0)
    if value.startswith('"'):
        return value
    if value == '/*':
        raise ValueError('Unterminated block comment')
    return '\n' * value.count('\n')


def mask_comments(text):
    """Hide comments while preserving offsets, newlines and quoted strings."""
    return _TOKEN.sub(_mask, text)


def strip_comments(text):
    """Remove comments while preserving line numbers and quoted strings."""
    return _TOKEN.sub(_delete, text)


def read_source(path):
    with open(path, encoding='utf-8') as stream:
        return stream.read()
