from modeditor.utils import apply_text_edits

# Simple test of apply_text_edits
text = "hello world\nthis is a test\nend here"
print(f"Original: {repr(text)}")

# Replace "world" with "world," at positions [6:11]
edits = [(6, 11, "world,")]
result = apply_text_edits(text, edits)
print(f"After edit [6:11] 'world'->'world,': {repr(result)}")

# Test multiple edits
text2 = "module test (\n    clk\n    rst\n    // comment\n);\n"
print(f"\nOriginal: {repr(text2)}")

# Edit "rst" to "rst," at positions [22:25] and insert "    new_port" before ")" at position 36
# Actually let me check the actual positions first
print(f"Character at pos 22: {repr(text2[22])}")
print(f"Characters [22:25]: {repr(text2[22:25])}")  # Should be 'rst'
print(f"Character at pos 36: {repr(text2[36])}")    # Should be ')'

edits2 = [
    (22, 25, "rst,"),  # Change "rst" to "rst,"
    (36, 36, "\n    new_port")  # Insert before ')'
]
result2 = apply_text_edits(text2, edits2)
print(f"After multiple edits: {repr(result2)}")