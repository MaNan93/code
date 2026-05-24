from modeditor.utils import add_port

# Test just comma addition - minimal case
test_module = '''module test (
    clk
    rst
);
input clk;
input rst;
endmodule
'''

print("Before:")
print(repr(test_module))

# We expect this to add comma to 'rst' and add 'enable' to port list and declarations
result = add_port(test_module, direction='input', name='enable')

print("\nAfter:")
print(repr(result))

print("\nFormatted After:")
print(result)

# What we hope to see:
# module test (
#     clk,
#     rst,    <-- comma added
#     enable  <-- new port
# );
# input clk;
# input rst;
# input enable;  <-- new declaration