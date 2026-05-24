# Binary check of the comma character
comma = ','
comma_bytes = comma.encode('utf-8')
print(f"comma bytes: {comma_bytes}")
print(f"comma hex bytes: {comma_bytes.hex()}")

# Expected comma in UTF-8 is 0x2c
expected = chr(44)
print(f"\nchr(44): {repr(expected)}")
print(f"chr(44) bytes: {expected.encode('utf-8').hex()}")

# Check if they're the same
print(f"\ncomma == expected: {comma == expected}")

# Try explicit concatenation
result = ''.join(['a', 'b', 'c', comma])
print(f"\n''.join result: {repr(result)}")

# Try format
result2 = f"{'test'}{comma}"
print(f"f-string result: {repr(result2)}")