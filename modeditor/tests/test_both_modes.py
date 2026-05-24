from modeditor.utils import add_port

# Test ANSI module
ansi_module = '''module ansi_test (
    input clk,
    output rst
);
endmodule
'''

print("=== ANSI Module Test ===")
print("Before:")
print(ansi_module)

result_ansi = add_port(ansi_module, direction='input', name='data')
print("After adding 'data':")
print(result_ansi)

print("\n" + "="*50)

# Test Non-ANSI module  
non_ansi_module = '''module non_ansi_test (
    clk,
    rst
);
input clk;
input rst;
endmodule
'''

print("\n=== Non-ANSI Module Test ===")
print("Before:")
print(non_ansi_module)

result_non_ansi = add_port(non_ansi_module, direction='input', name='data')
print("After adding 'data':")
print(result_non_ansi)