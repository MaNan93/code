"""Compatibility icon adapter for restored table widgets.

The original UI used an SAP icon font. The refactored UI uses Lucide SVGs;
this adapter preserves the old helper signature without restoring font assets.
"""

from plm.frontend.qt.widgets.common import load_lucide_icon

_ICON_MAP = {
    "vertical-grip": "more-horizontal",
}


def icon(name, color="#666666", size=20):
    return load_lucide_icon(_ICON_MAP.get(name, name), color=color, size=size)
