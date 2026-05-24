# Simplest possible test
line = '    rst'
comma = ','
updated = line + comma
print(f"line: {repr(line)}")
print(f"comma: {repr(comma)}")
print(f"len(comma): {len(comma)}")
print(f"updated: {repr(updated)}")

# Now test with rstrip
line2 = '    rst'
updated2 = line2.rstrip() + ','
print(f"\nline2: {repr(line2)}")
print(f"updated2: {repr(updated2)}")