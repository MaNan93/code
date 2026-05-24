from modeditor.utils import apply_text_edits

# Test the exact scenario from debug output
text2 = "module test (\n    clk\n    rst\n    // comment\n);\n"
print(f"Original: {repr(text2)}")
print(f"Length: {len(text2)}")

# From debug: abs_start: 22, abs_end: 29, line: '    rst'
print(f"text2[22:29]: {repr(text2[22:29])}")
print(f"Should be: {'    rst'}")

# Correct edit: replace '    rst' with '    rst,'
edits2 = [(22, 29, "    rst,")]  # Replace '    rst' with '    rst,'
result2 = apply_text_edits(text2, edits2)
print(f"After rst->rst, edit: {repr(result2)}")

# Now test with the second edit (inserting before ')')
# Position of ')' should be around index 39 (let me calculate)
for i, char in enumerate(text2):
    if char == ')':
        print(f"First ')' found at index {i}: {repr(text2[i])}")
        break

# Let's say ')' is at index 39, we want to insert before it
corrected_text = result2  # After rst->rst, edit
print(f"After rst edit: {repr(corrected_text)}")

# Now add port name before ')'
pos_of_paren = corrected_text.find(')')
print(f"Position of ')' in corrected text: {pos_of_paren}")

final_edits = [
    (pos_of_paren, pos_of_paren, ",\n    new_port")  # Insert before ')'
]
final_result = apply_text_edits(corrected_text, final_edits)
print(f"Final result: {repr(final_result)}")