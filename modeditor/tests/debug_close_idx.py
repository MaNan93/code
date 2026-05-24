#!/usr/bin/env python3
"""Debug script to understand close_idx positioning"""

import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parent / "modeditor" / "src"))

from modeditor.utils import get_module_parts

# Non-ANSI style module
source = """module test_mod (clk, reset);
    input clk, reset;
endmodule
"""

print("Source:")
print(source)
print("\n" + "="*60)

parts = get_module_parts(source, None)

print(f"mod_start: {parts['mod_start']}")
print(f"open_idx: {parts['open_idx']}")  
print(f"close_idx: {parts['close_idx']}")
print(f"semicolon_idx: {parts['semicolon_idx']}")

print(f"\nports_block (from open_idx+1 to close_idx):")
print(repr(parts['ports_block']))

print(f"\nCharacter at close_idx: {repr(source[parts['mod_start'] + parts['close_idx']])}")
print(f"Characters around close_idx:")
close_abs = parts['mod_start'] + parts['close_idx']
for i in range(max(0, close_abs-5), min(len(source), close_abs+6)):
    print(f"  [{i:3d}]: {repr(source[i])}")
