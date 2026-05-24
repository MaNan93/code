from modeditor.utils import find_last_code_line_span, strip_comments

# Test the exact ports_block content
ports_block = '''    clk
    rst
    // comment
'''

print("ports_block repr:", repr(ports_block))
print("ports_block content:")
print(ports_block)
print("--- end ---")

span = find_last_code_line_span(ports_block)
print("find_last_code_line_span result:", span)

if span:
    start, end = span
    extracted = ports_block[start:end]
    print(f"Extracted span [{start}:{end}]: {repr(extracted)}")
else:
    print("No span found!")

# Also test what lines are considered code
lines = ports_block.splitlines(keepends=True)
print("\nLines breakdown:")
for i, line in enumerate(lines):
    s = line.strip()
    is_code = bool(s) and not s.startswith("//") and not s.startswith("/*") and not s.startswith("*")
    print(f"  Line {i}: {repr(line)} -> stripped: {repr(s)}, is_code: {is_code}")