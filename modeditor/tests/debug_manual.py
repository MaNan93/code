from modeditor.utils import get_module_parts, find_last_code_line_span

def debug_manual_concat(source_text):
    parts = get_module_parts(source_text, None)
    ports_block = parts["ports_block"]
    last_span = find_last_code_line_span(ports_block)
    
    if last_span is not None:
        rel_start, rel_end = last_span
        abs_start = parts["mod_start"] + parts["open_idx"] + 1 + rel_start
        abs_end = parts["mod_start"] + parts["open_idx"] + 1 + rel_end
        line = source_text[abs_start:abs_end]
        
        stripped_line = line.rstrip()
        
        if not stripped_line.endswith(','):
            # Do the calculation manually
            comma = ','
            suffix = line[len(stripped_line):]
            updated = stripped_line + comma + suffix
            
            # Print step by step to make sure
            print("Step 1 - stripped_line:", repr(stripped_line))
            print("Step 2 - comma:", repr(comma))
            print("Step 3 - suffix:", repr(suffix))
            print("Step 4 - concatenation:", repr(stripped_line), "+", repr(comma), "+", repr(suffix))
            print("Step 5 - result:", repr(updated))
            print("Step 6 - original line:", repr(line))
            print("Step 7 - different?", updated != line)

test_module = '''module test (
    clk
    rst
);
input clk;
input rst;
endmodule
'''

debug_manual_concat(test_module)