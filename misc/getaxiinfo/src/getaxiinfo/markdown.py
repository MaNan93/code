"""Render controller analysis as a standalone Markdown report."""

import html


def _escape(value):
    text = html.escape(str(value), quote=False)
    for character in ("\\", "`", "*", "_", "[", "]"):
        text = text.replace(character, "\\" + character)
    return text.replace("|", "&#124;").replace("\r", "").replace("\n", "<br>")


def _table(headers, rows):
    def line(row):
        return "| " + " | ".join(_escape(value) for value in row) + " |"
    return [line(headers), "| " + " | ".join("---" for _ in headers) + " |"] + [line(row) for row in rows]


def render_markdown(analysis, files=(), macro_details=(), debug=False):
    """Use the same section values and status meanings as the terminal report."""
    lines = ["# PCIe Controller Specifications", ""]
    if debug:
        lines.extend(["## SOURCE", ""])
        lines.extend("- " + _escape(path) for path in files)
        lines.append("")
    for title, fields, headers, rows in analysis["sections"]:
        lines.extend(["## " + title, ""])
        if fields:
            lines.extend(_table(("Field", "Value"), fields))
            lines.append("")
        if headers:
            lines.extend(_table(headers, rows) if rows else ["No applicable/configured rows."])
            lines.append("")
    if analysis["notes"]:
        lines.extend(["## NOTES", ""])
        lines.extend("- " + _escape(note) for note in analysis["notes"])
        lines.append("")
    if debug:
        lines.extend(["## MACRO_DETAILS", ""])
        rows = [(item["name"], item["raw"], item["resolved"], item["rule"], item["source"], item["line"])
                for item in macro_details]
        lines.extend(_table(("Macro", "Raw", "Resolved", "Rule", "Source", "Source Line"), rows))
        lines.append("")
        if analysis["trace"]:
            lines.extend(["### Derived Values", ""])
            lines.extend(_table(("Field", "Macro", "Rule", "Result"), analysis["trace"]))
            lines.append("")
    return "\n".join(lines)
