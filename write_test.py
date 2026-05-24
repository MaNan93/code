import sys

# Write result to file instead of stdout
comma = ','
result = 'abc' + comma

with open('comma_test_result.txt', 'w') as f:
    f.write(f"comma repr: {repr(comma)}\n")
    f.write(f"comma ord: {ord(comma)}\n")
    f.write(f"result: {repr(result)}\n")
    f.write(f"result == 'abc,': {result == 'abc,'}\n")
    
    # Also write bytes
    comma_bytes = comma.encode('utf-8')
    result_bytes = result.encode('utf-8')
    f.write(f"\ncomma bytes: {comma_bytes}\n")
    f.write(f"comma bytes hex: {comma_bytes.hex()}\n")
    f.write(f"result bytes: {result_bytes}\n")
    f.write(f"result bytes hex: {result_bytes.hex()}\n")
    
    # Expected
    expected = 'abc,'
    expected_bytes = expected.encode('utf-8')
    f.write(f"\nexpected: {repr(expected)}\n")
    f.write(f"expected bytes: {expected_bytes}\n")
    f.write(f"expected bytes hex: {expected_bytes.hex()}\n")
    f.write(f"\nresult == expected: {result == expected}\n")
    
    # Check character by character
    f.write(f"\nCharacter by character:\n")
    for i, c in enumerate(result):
        f.write(f"  [{i}] {repr(c)} ord={ord(c)}\n")

print("Written to comma_test_result.txt")