from modeditor.utils import get_module_parts, find_last_code_line_span

def debug_real_calculation(source_text):
    """Direct calculation to verify logic"""
    parts = get_module_parts(source_text, None)
    ports_block = parts["ports_block"]
    last_span = find_last_code_line_span(ports_block)
    
    if last_span is not None:
        rel_start, rel_end = last_span
        abs_start = parts["mod_start"] + parts["open_idx"] + 1 + rel_start
        abs_end = parts["mod_start"] + parts["open_idx"] + 1 + rel_end
        line = source_text[abs_start:abs_end]
        
        print(f"line = {repr(line)}")
        
        # Reproduce the exact same calculation as in add_port
        stripped_line = line.rstrip()
        print(f"stripped_line = {repr(stripped_line)}")
        
        if not stripped_line.endswith(','):
            # This is the exact calculation from add_port
            updated = stripped_line + ',' + line[len(stripped_line):]
            print(f"COMPUTED: updated = {repr(updated)}")
            print(f"MANUAL CHECK: {repr(stripped_line)} + ',' + {repr(line[len(stripped_line):])} = {repr(updated)}")
            print(f"Are they different? {updated != line}")
            
            # Let's also double-check the individual components
            print(f"DEBUG: len(stripped_line) = {len(stripped_line)}")
            print(f"DEBUG: line[{len(stripped_line)}:] = {repr(line[len(stripped_line):])}")
            
        else:
            print("Line already ends with comma")

test_module = '''module test (
    clk
    rst
);
input clk;
input rst;
endmodule
'''

debug_real_calculation(test_module)