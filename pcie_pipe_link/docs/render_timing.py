"""Render the delivery timing figures as matching SVG and PNG files (Pillow)."""
from html import escape
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont


BASE = Path(__file__).resolve().parents[1]
OUT = BASE / 'docs' / 'figures'
FONT = 'C:/Windows/Fonts/msyh.ttc'
SCALE = 2
INK = '#233247'
BLUE = '#245da8'
GRAY = '#8291a3'


def render(name, title, cycles, signals, clock=None):
    left, step, top, row = 310, 82, 115, 76
    width = left + (len(cycles) - 1) * step + 96
    height = top + (len(signals) + 1) * row + 40
    img = Image.new('RGB', (width * SCALE, height * SCALE), 'white')
    draw = ImageDraw.Draw(img)
    svg = [f'<svg xmlns="http://www.w3.org/2000/svg" width="{width}" height="{height}" viewBox="0 0 {width} {height}">',
           '<rect width="100%" height="100%" fill="white"/>']

    def line(points, color=INK, thickness=2):
        draw.line([(int(x * SCALE), int(y * SCALE)) for x, y in points],
                  fill=color, width=thickness * SCALE)
        xy = ' '.join(f'{x},{y}' for x, y in points)
        svg.append(f'<polyline points="{xy}" fill="none" stroke="{color}" stroke-width="{thickness}"/>')

    def text(x, y, label, size=15, color=INK):
        draw.text((int(x * SCALE), int(y * SCALE)), label,
                  font=ImageFont.truetype(FONT, size * SCALE), fill=color)
        svg.append(f'<text x="{x}" y="{y + size}" font-family="Microsoft YaHei, sans-serif" font-size="{size}" fill="{color}">{escape(label)}</text>')

    text(24, 18, title, 23, BLUE)
    end = width - 25
    for i, cycle in enumerate(cycles):
        x = left + i * step
        text(x - 10, 86, cycle, 13, GRAY)
        line([(x, top - 4), (x, height - 25)], '#e4e9f0', 1)

    text(20, top + 7, 'PCLK', 15)
    if clock is None:
        points = [(left - 36, top + 32), (left, top + 32)]
        for i in range(len(cycles)):
            x = left + i * step
            points += [(x, top + 4), (x + step / 2, top + 4),
                       (x + step / 2, top + 32), (min(x + step, end), top + 32)]
    else:
        points = [(left - 36, top + 32)]
        state = 0
        for position, value in clock:
            x = left + position * step
            points += [(x, top + (4 if state else 32)), (x, top + (4 if value else 32))]
            state = value
        points.append((end, top + (4 if state else 32)))
    line(points, BLUE)

    for idx, (label, kind, changes) in enumerate(signals, 1):
        y = top + idx * row
        text(20, y + 7, label, 15)
        if kind == 'bit':
            current = 0
            points = [(left - 36, y + 32)]
            for cycle, value in changes:
                x = left + cycle * step
                points += [(x, y + (4 if current else 32)),
                           (x, y + (4 if value else 32))]
                current = value
            points.append((end, y + (4 if current else 32)))
            line(points, BLUE)
        else:
            start = left - 36
            for position, (cycle, value) in enumerate(changes):
                stop = left + changes[position + 1][0] * step if position + 1 < len(changes) else end
                line([(start + 7, y + 4), (stop - 7, y + 4), (stop, y + 18),
                      (stop - 7, y + 32), (start + 7, y + 32),
                      (start, y + 18), (start + 7, y + 4)], BLUE)
                text(start + 13, y + 7, value, 13, BLUE)
                start = stop
    svg.append('</svg>')
    OUT.mkdir(parents=True, exist_ok=True)
    (OUT / f'{name}.svg').write_text('\n'.join(svg), encoding='utf-8')
    img.save(OUT / f'{name}.png')


rate_clock = []
for i in range(6):
    rate_clock += [(i * 0.5, 1), (i * 0.5 + 0.25, 0)]
for i in range(39):
    rate_clock += [(5 + i * 0.125, 1), (5.0625 + i * 0.125, 0)]
render('rate_switch', 'Figure 3-1  Gen1 to Gen3 rate change (62.5 MHz to 250 MHz)', [f'T{i}' for i in range(10)], [
    ('side_mac_phy_rate', 'bus', [(-0.44, 'Gen1 (0)'), (1, 'Gen3 (2)')]),
    ('side_clock_ready', 'bit', [(-0.44, 1), (2, 0), (6, 1)]),
    ('side_active_rate', 'bus', [(-0.44, 'Gen1 (0)'), (6, 'Gen3 (2)')]),
    ('side_phy_mac_phystatus', 'bit', [(7, 1), (7.125, 0)]),
    ('RxValid / RxDataValid', 'bit', [(-0.44, 1), (1, 0), (6.5, 1)]),
    ('RxElecIdle', 'bit', [(1, 1), (6.5, 0)]),
], clock=rate_clock)

render('preset_query', 'Figure 3-2  Preset-to-coefficient conversion', ['C0', 'C1', 'C2', 'C3'], [
    ('mac_phy_getlocal_pset_coef', 'bit', [(-0.15, 1), (0.85, 0)]),
    ('local_pset_index / rate', 'bus', [(-0.44, 'valid index / rate')]),
    ('phy_mac_local_tx_coef_valid', 'bit', [(2.05, 1), (3.05, 0)]),
    ('phy_mac_local_tx_pset_coef', 'bus', [(-0.44, 'x'), (2.05, 'coeff')]),
])
render('eq_complete', 'Figure 3-3  Receiver EQ evaluation (EQ_CYCLES = 8, no competing response)',
       [f'C{i}' for i in range(11)], [
    ('mac_phy_rxeqeval', 'bit', [(-0.15, 1)]),
    ('phy_mac_fomfeedback', 'bus', [(-0.44, 'x'), (8.05, '255')]),
    ('phy_mac_dirfeedback', 'bus', [(-0.44, '0')]),
    ('phy_mac_phystatus', 'bit', [(9.05, 1), (10.05, 0)]),
])
print('Rendered 3 SVG + 3 PNG timing figures')
