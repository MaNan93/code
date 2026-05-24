from modeditor.utils import add_port

# Test non-ANSI module
test_module = '''module test (
    clk,
    rst
    // comment
);

input clk;
input rst;

endmodule
'''

result = add_port(test_module, direction='input', name='enable')
print("Result:")
print(result)