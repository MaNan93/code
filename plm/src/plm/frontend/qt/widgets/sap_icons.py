"""SAP icon font access for the Qt front end.

SAP ships its icons as a font rather than as images, so an icon here is a
glyph looked up by codepoint and painted into a pixmap at whatever colour
and size the caller wants -- a monochrome icon set that stays sharp at any
size without carrying one file per icon per colour.

The names below are upstream's own (`sap-icon--add`, `sap-icon--save`, ...)
and their codepoints come from theming-base-content's `SAP-icons.json`.
Only the icons this application actually uses are listed; to add one, look
its name up in that file and copy the codepoint across. Button, menu, tree,
and drag-handle icons must all come through this module; do not mix in Qt
platform icons or hand-drawn substitutes.
"""

from pathlib import Path

from PyQt5 import QtCore, QtGui

_FONT_DIR = Path(__file__).resolve().parent.parent / "assets" / "fonts"
ICON_FONT_PATH = _FONT_DIR / "SAP-icons.ttf"
TEXT_FONT_PATHS = (_FONT_DIR / "72-Regular.ttf", _FONT_DIR / "72-Bold.ttf")

#: SAP icon name -> codepoint, from SAP-icons.json (Horizon set).
CODEPOINTS = {
    "action-settings": 0xE0A6,
    "add": 0xE058,
    "compare": 0xE086,
    "copy": 0xE245,
    "document": 0xE172,
    "document-text": 0xE1B4,
    "edit": 0xE038,
    "exit-full-screen": 0xE1F5,
    "folder-blank": 0xE08E,
    "full-screen": 0xE166,
    "navigation-down-arrow": 0xE1E2,
    "navigation-right-arrow": 0xE066,
    "open-folder": 0xE1C9,
    "overflow": 0xE1F2,
    "refresh": 0xE010,
    "save": 0xE09A,
    "screen-split-two": 0xE240,
    "search": 0xE00D,
    "syntax": 0xE139,
    "undo": 0xE1E0,
    "vertical-grip": 0xE1FA,
}

_icon_family = None
_text_family = None


def _load_fonts():
    """Register the vendored fonts once, returning the icon family name.

    Returns None when the fonts cannot be registered -- callers fall back
    to a blank icon rather than failing, so a missing asset degrades the UI
    instead of breaking startup."""
    global _icon_family, _text_family
    if _icon_family is not None:
        return _icon_family or None

    if QtGui.QGuiApplication.instance() is None:
        # QFontDatabase needs a live QGuiApplication; touching it before
        # one exists aborts the process rather than raising. Importing this
        # module must stay safe, so bail out *without* caching -- the next
        # call, once the application is up, does the real registration.
        return None

    _icon_family = ""
    if ICON_FONT_PATH.is_file():
        font_id = QtGui.QFontDatabase.addApplicationFont(str(ICON_FONT_PATH))
        families = QtGui.QFontDatabase.applicationFontFamilies(font_id) if font_id >= 0 else []
        if families:
            _icon_family = families[0]

    families = []
    for path in TEXT_FONT_PATHS:
        if not path.is_file():
            continue
        font_id = QtGui.QFontDatabase.addApplicationFont(str(path))
        if font_id >= 0:
            families.extend(QtGui.QFontDatabase.applicationFontFamilies(font_id))
    _text_family = families[0] if families else ""

    return _icon_family or None


def text_font_family():
    """The "72" family name once registered, or "" if it is unavailable."""
    _load_fonts()
    return _text_family or ""


def icon_font(pixel_size):
    family = _load_fonts()
    if not family:
        return None
    font = QtGui.QFont(family)
    font.setPixelSize(pixel_size)
    return font


def icon(name, color="#131e29", size=22):
    """Render an SAP icon glyph into a QIcon.

    `size` is the pixmap edge; the glyph is drawn a little smaller so it
    keeps its own breathing room inside the square, matching how the web
    components inset an icon within its tap target."""
    pixmap = QtGui.QPixmap(size, size)
    pixmap.fill(QtCore.Qt.transparent)
    font = icon_font(max(8, round(size * 0.82)))
    codepoint = CODEPOINTS.get(name)
    if font is None or codepoint is None:
        return QtGui.QIcon(pixmap)
    painter = QtGui.QPainter(pixmap)
    painter.setRenderHint(QtGui.QPainter.TextAntialiasing, True)
    painter.setFont(font)
    painter.setPen(QtGui.QColor(color))
    painter.drawText(pixmap.rect(), QtCore.Qt.AlignCenter, chr(codepoint))
    painter.end()
    return QtGui.QIcon(pixmap)
