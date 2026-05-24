from modeditor.utils import get_module_parts, find_last_code_line_span, detect_newline, detect_indent, find_non_ansi_port_decl_insert

# Test non-ANSI module
test_module = '''module test (
    clk
    rst
    // comment
);

input clk;
input rst;

endmodule
'''

print("Original:")
print(test_module)

try:
    parts = get_module_parts(test_module, None)
    print("\nParts info:")
    print(f"mod_start: {parts['mod_start']}")
    print(f"open_idx: {parts['open_idx']}")
    print(f"close_idx: {parts['close_idx']}")
    print(f"semicolon_idx: {parts['semicolon_idx']}")
    print(f"ports_block: {repr(parts['ports_block'])}")
    print(f"module_text: {repr(parts['module_text'])}")

    # Simulate the logic from add_port for non-ANSI
    ports_block = parts["ports_block"]
    module_text = parts["module_text"]
    
    newline = detect_newline(module_text)
    indent = detect_indent(ports_block)
    print(f"\nnewline: {repr(newline)}")
    print(f"indent: {repr(indent)}")

    # Get the last code line in the ports block
    last_span = find_last_code_line_span(ports_block)
    print(f"\nlast_span: {last_span}")
    
    if last_span is not None:
        rel_start, rel_end = last_span
        print(f"rel_start: {rel_start}, rel_end: {rel_end}")
        
        abs_start = parts["mod_start"] + parts["open_idx"] + 1 + rel_start
        abs_end = parts["mod_start"] + parts["open_idx"] + 1 + rel_end
        print(f"abs_start: {abs_start}, abs_end: {abs_end}")
        
        line = test_module[abs_start:abs_end]
        print(f"line to edit: {repr(line)}")
        
        # Manual comma addition
        stripped_line = line.rstrip()
        if not stripped_line.endswith(','):
            updated = stripped_line + ',' + line[len(stripped_line):]
            print(f"updated line: {repr(updated)}")
            print(f"Will edit range [{abs_start}:{abs_end}] from {repr(line)} to {repr(updated)}")
        else:
            print("Line already has comma")
    
    # Check insertion point for new port
    abs_close = parts["mod_start"] + parts["close_idx"]
    print(f"\nabs_close (')' position): {abs_close}")
    print(f"Character at abs_close: {repr(test_module[abs_close])}")
    
    # Check body insertion point
    body = module_text[parts["semicolon_idx"] + 1 :]
    body_base = parts["mod_start"] + parts["semicolon_idx"] + 1
    decl_insert_abs, body_indent = find_non_ansi_port_decl_insert(body, body_base, indent)
    print(f"\nBody insertion: abs={decl_insert_abs}, indent={repr(body_indent)}")
    
except Exception as e:
    import traceback
    print(f"Error: {e}")
    traceback.print_exc()