# Vendored SAP fonts

These come from [SAP/theming-base-content](https://github.com/SAP/theming-base-content),
published under Apache-2.0 (see `LICENSE-Apache-2.0.txt`, copied from that
repository's `LICENSE.txt`).

| File | Upstream path | Notes |
| --- | --- | --- |
| `SAP-icons.ttf` | `content/Base/baseLib/sap_horizon/fonts/SAP-icons.ttf` | Horizon icon set, 699 glyphs. Verbatim copy. |
| `72-Regular.ttf` | `content/Base/baseLib/baseTheme/fonts/72-Regular-full.woff` | Converted, see below. |
| `72-Bold.ttf` | `content/Base/baseLib/baseTheme/fonts/72-Bold-full.woff` | Converted, see below. |

## Why the 72 files are not verbatim

Upstream ships 72 as WOFF/WOFF2 only, and Qt's `QFontDatabase` loads
TTF/OTF only -- so they are converted with fontTools (the WOFF flavour is
zlib, which needs no brotli):

```python
from fontTools.ttLib import TTFont
font = TTFont("72-Regular-full.woff")
font.flavor = None
font.save("72-Regular.ttf")
```

The conversion alone is not enough: upstream's name table carries an empty
nameID 1, so Qt reports a family of `''` for both weights -- unusable from
a stylesheet, and with no way to tell Regular from Bold apart. The name
table is therefore repaired to family `72` with proper `Regular`/`Bold`
subfamilies, and the Bold file gets `usWeightClass`/`fsSelection`/
`macStyle` set to match. No glyph outline is touched.

The icon name -> codepoint map lives in `plm.frontend.qt.widgets.sap_icons`
and is derived from upstream's
`content/Base/baseLib/baseTheme/fonts/SAP-icons.json`.

72 covers Latin only. The application's font stack keeps a CJK fallback
after it for the Chinese labels in the sidebar.
