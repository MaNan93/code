from modeditor.utils import get_module_parts, find_last_code_line_span, detect_newline, detect_indent, apply_text_edits

# ANSI module
ansi_module = '''module ansi_test (
    input clk,
    output rst
);
endmodule
'''

print("=== ANSI Module Test ===")
parts = get_module_parts(ansi_module, None)
ports_block = parts["ports_block"]
module_text = parts["module_text"]
newline = detect_newline(module_text)
indent = detect_indent(ports_block)

last_span = find_last_code_line_span(ports_block)
rel_start, rel_end = last_span
abs_start = parts["mod_start"] + parts["open_idx"] + 1 + rel_start
abs_end = parts["mod_start"] + parts["open_idx"] + 1 + rel_end
line = ansi_module[abs_start:abs_end]

print(f"line: {repr(line)}")
print(f"len(line): {len(line)}")
print(f"line.rstrip(): {repr(line.rstrip())}")

# Build the edit
updated_line = line.rstrip() + ','
print(f"updated_line: {repr(updated_line)}")

print(f"\nApplying edit: replace [{abs_start}:{abs_end}] with {repr(updated_line)}")
edits = [(abs_start, abs_end, updated_line)]
result = apply_text_edits(ansi_module, edits)
print(f"\nResult:")
print(result)

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
parts2 = get_module_parts(non_ansi_module, None)
ports_block2 = parts2["ports_block"]
module_text2 = parts2["module_text"]
newline2 = detect_newline(module_text2)
indent2 = detect_indent(ports_block2)

last_span2 = find_last_code_line_span(ports_block2)
rel_start2, rel_end2 = last_span2
abs_start2 = parts2["mod_start"] + parts2["open_idx"] + 1 + rel_start2
abs_end2 = parts2["mod_start"] + parts2["open_idx"] + 1 + rel_end2
line2 = non_ansi_module[abs_start2:abs_end2]

print(f"line: {repr(line2)}")
print(f"len(line): {len(line2)}")
print(f"line.rstrip(): {repr(line2.rstrip())}")

# Build the edit
updated_line2 = line2.rstrip() + ','
print(f"updated_line: {repr(updated_line2)}")

print(f"\nApplying edit: replace [{abs_start2}:{abs_end2}] with {repr(updated_line2)}")
edits2 = [(abs_start2, abs_end2, updated_line2)]
result2 = apply_text_edits(non_ansi_module, edits2)
print(f"\nResult:")
print(result2)