from modeditor.utils import get_module_parts, find_last_code_line_span, is_ansi_ports, detect_newline, detect_indent

# ANSI module
ansi_module = '''module ansi_test (
    input clk,
    output rst
);
endmodule
'''

print("=== ANSI Module Test ===")
print("Module:")
print(ansi_module)

parts = get_module_parts(ansi_module, None)
ports_block = parts["ports_block"]
module_text = parts["module_text"]

print(f"\nis_ansi_ports: {is_ansi_ports(ports_block)}")
print(f"ports_block: {repr(ports_block)}")
print(f"module_text: {repr(module_text)}")

newline = detect_newline(module_text)
indent = detect_indent(ports_block)

last_span = find_last_code_line_span(ports_block)
if last_span is not None:
    rel_start, rel_end = last_span
    abs_start = parts["mod_start"] + parts["open_idx"] + 1 + rel_start
    abs_end = parts["mod_start"] + parts["open_idx"] + 1 + rel_end
    line = source_text[abs_start:abs_end] if 'source_text' in dir() else ansi_module[abs_start:abs_end]
    print(f"\nANSI last_span: {last_span}")
    print(f"ANSI abs_start: {abs_start}, abs_end: {abs_end}")
    print(f"ANSI line = source_text[{abs_start}:{abs_end}]: {repr(line)}")
else:
    print("ANSI last_span is None")

print("\n" + "="*50)

# Non-ANSI module
non_ansi_module = '''module non_ansi_test (
    clk,
    rst
);
input clk;
input rst;
endmodule
'''

print("\n=== Non-ANSI Module Test ===")
print("Module:")
print(non_ansi_module)

parts2 = get_module_parts(non_ansi_module, None)
ports_block2 = parts2["ports_block"]
module_text2 = parts2["module_text"]

print(f"\nis_ansi_ports: {is_ansi_ports(ports_block2)}")
print(f"ports_block: {repr(ports_block2)}")
print(f"module_text: {repr(module_text2)}")

newline2 = detect_newline(module_text2)
indent2 = detect_indent(ports_block2)

last_span2 = find_last_code_line_span(ports_block2)
if last_span2 is not None:
    rel_start2, rel_end2 = last_span2
    abs_start2 = parts2["mod_start"] + parts2["open_idx"] + 1 + rel_start2
    abs_end2 = parts2["mod_start"] + parts2["open_idx"] + 1 + rel_end2
    line2 = non_ansi_module[abs_start2:abs_end2]
    print(f"\nNon-ANSI last_span: {last_span2}")
    print(f"Non-ANSI abs_start: {abs_start2}, abs_end: {abs_end2}")
    print(f"Non-ANSI line = source_text[{abs_start2}:{abs_end2}]: {repr(line2)}")
else:
    print("Non-ANSI last_span is None")