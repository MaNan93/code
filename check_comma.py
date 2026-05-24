# Check the actual character code
comma = ','
print(f"comma repr: {repr(comma)}")
print(f"comma ord: {ord(comma)}")
print(f"comma hex: {hex(ord(comma))}")
print(f"comma length: {len(comma)}")
print(f"comma == ',': {comma == ','}")

# Compare with a hardcoded comma
hardcoded = ','
print(f"\nhardcoded repr: {repr(hardcoded)}")
print(f"hardcoded ord: {ord(hardcoded)}")
print(f"comma == hardcoded: {comma == hardcoded}")

# Test concatenation
test = 'abc' + comma
print(f"\n'tabc' + comma = {repr(test)}")