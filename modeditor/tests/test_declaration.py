from modeditor.utils import add_port

# Test a simple ANSI module
ansi_module = '''module test (
    input clk,
    output rst
);
endmodule
'''

print("Before:")
print(repr(ansi_module))

result = add_port(ansi_module, direction='input', name='data')
print("\nAfter:")
print(repr(result))

print("\nFormatted:")
print(result)