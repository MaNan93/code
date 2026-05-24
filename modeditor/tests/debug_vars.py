from modeditor.utils import get_module_parts, find_last_code_line_span, detect_newline, detect_indent

def debug_add_port_logic(source_text, direction, name):
    """Debug version of add_port non-ANSI logic"""
    parts = get_module_parts(source_text, None)
    module_text = parts["module_text"]
    ports_block = parts["ports_block"]

    print(f"ports_block: {repr(ports_block)}")
    print(f"module_text: {repr(module_text)}")

    # Non-ANSI logic
    newline = detect_newline(module_text)
    indent = detect_indent(ports_block)
    
    # Get the last code line in the ports block to add comma if needed
    last_span = find_last_code_line_span(ports_block)
    print(f"last_span: {last_span}")
    
    if last_span is not None:
        rel_start, rel_end = last_span
        print(f"rel_start={rel_start}, rel_end={rel_end}")
        
        abs_start = parts["mod_start"] + parts["open_idx"] + 1 + rel_start
        abs_end = parts["mod_start"] + parts["open_idx"] + 1 + rel_end
        print(f"abs_start={abs_start}, abs_end={abs_end}")
        
        line = source_text[abs_start:abs_end]
        print(f"source_text[{abs_start}:{abs_end}] = {repr(line)}")
        
        # Manual comma addition logic
        stripped_line = line.rstrip()
        print(f"line.rstrip() = {repr(stripped_line)}")
        print(f"stripped_line.endswith(',') = {stripped_line.endswith(',')}")
        
        if not stripped_line.endswith(','):
            updated = stripped_line + ',' + line[len(stripped_line):]
            print(f"line[len(stripped_line):] = {repr(line[len(stripped_line):])}")
            print(f"updated = {repr(updated)}")
            print(f"updated != line: {updated != line}")
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

debug_add_port_logic(test_module, 'input', 'enable')