from modeditor.utils import get_module_parts, find_last_code_line_span

def debug_add_port_logic_v2(source_text):
    """More explicit debugging"""
    parts = get_module_parts(source_text, None)

    # Non-ANSI logic
    ports_block = parts["ports_block"]
    last_span = find_last_code_line_span(ports_block)
    
    if last_span is not None:
        rel_start, rel_end = last_span
        
        abs_start = parts["mod_start"] + parts["open_idx"] + 1 + rel_start
        abs_end = parts["mod_start"] + parts["open_idx"] + 1 + rel_end
        
        line = source_text[abs_start:abs_end]
        print(f"EXACT LINE CONTENT: {repr(line)}")
        print(f"LINE LENGTH: {len(line)}")
        
        # Show each character with its index
        print("CHARACTER BREAKDOWN:")
        for i, char in enumerate(line):
            print(f"  [{i}] {repr(char)}")
        
        # Debug the comma logic step by step
        print("\nSTEP BY STEP DEBUG:")
        stripped_line = line.rstrip()
        print(f"1. line.rstrip() = {repr(stripped_line)}")
        print(f"2. len(stripped_line) = {len(stripped_line)}")
        print(f"3. stripped_line.endswith(',') = {stripped_line.endswith(',')}")
        
        if not stripped_line.endswith(','):
            slice_part = line[len(stripped_line):]
            print(f"4. line[len(stripped_line):] = line[{len(stripped_line)}:] = {repr(slice_part)}")
            updated = stripped_line + ',' + slice_part
            print(f"5. FINAL updated = {repr(stripped_line)} + ',' + {repr(slice_part)} = {repr(updated)}")
            print(f"6. updated != line: {updated != line}")
        else:
            print("Line already has comma, no update needed")

# Test with our example
test_module = '''module test (
    clk
    rst
);
input clk;
input rst;
endmodule
'''

debug_add_port_logic_v2(test_module)