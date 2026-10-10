# Qt panel requirements and regression checks

These checks record the current panel requirements. Historical font and control
sizes are not used to redefine the current UI.

| Behavior | Required result | Coverage |
| --- | --- | --- |
| Configuration and log content | 4 logical pixels from the title bar, navigation rail, right edge and bottom of the visible window shell | Resize, maximize/restore, log toggle and sidebar animation |
| Artifacts position | Right aligned with ConfigPage; same top and height | Log hidden, resize, drawer maximize/restore |
| Artifacts outline | 1 logical pixel, `#D1D9E0`, all four sides, continuous 16 pixel corner arcs | Rendered pixels with a real loaded file, scrollbars and search |
| Artifacts width | Default 380 pixels; drag minimum 300 pixels; restore the chosen width after maximize | Mouse events and button clicks |
| Artifacts file contents | Retained through close/reopen, resize and maximize | Real asynchronous file read and repeated transitions |
| Source text | Loaded code is visibly painted, not just stored in QTextDocument | Rendered source pixels using real fonts |
| Animation completion | Accept an already emitted completion signal | Delivered, queued and missing signal cases |

`tests/test_qt_panel_contracts.py` measures final widget coordinates and rendered
pixels rather than reading the implementation's tokens or margin setters. Its
negative control removes content clipping and requires the corner assertion to
detect the original preview-over-border bug.

The shared fixture loads installed Segoe UI/Consolas fonts if the Windows
offscreen plugin starts with an empty font database, and removes only those
application fonts during cleanup. This prevents blank text rendering from
silently passing visual tests.

The outline check samples each complete corner arc. It uses physical image
coordinates and a bounded color tolerance for antialiasing at fractional DPI.

Run from `plm` in PowerShell:

```powershell
$env:PYTHONPATH = 'tests'
uv run --locked --extra qt python -m unittest test_qt_panel_contracts test_qt_test_isolation -v
uv run --locked --extra qt python -m unittest discover -s tests -q
```

For DPI coverage, run the panel module in separate processes with
`QT_ENABLE_HIGHDPI_SCALING=1` and `QT_SCALE_FACTOR=1.25` or `2`.

The offscreen Qt plugin has a small virtual screen and can maximize below a
window's minimum size. The window-state test restores that minimum before
checking layout at high DPI. These tests cover Fusion rendering and widget
behavior; native Windows screen composition still needs a visual check after
restarting the GUI.
