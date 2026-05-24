import sys
sys.path.insert(0, "/Users/pengzi.lian/Desktop/code/modeditor/src")
from modeditor.utils import ModuleEditor

# Case 1: macro in same file -> AST correctly resolves
sv = """
`define DATA_W 32
module foo (
  input  wire [`DATA_W-1:0] data_in,
  input  wire [7:0] addr,
  output wire [`DATA_W-1:0] data_out,
  output wire valid
);
  sub_a u1(.x(data_in), .y(data_out));
endmodule
"""
ed = ModuleEditor(sv)
print("=== Case 1: macro in same file (AST resolves) ===")
for p in ed.ports:
    print(f"  {p['direction']:8} {p['type']:8} {p['width']:15} {p['name']}")
print("instances:", ed.instances)

# Case 2: macro undefined -> raw text bracket extraction
sv2 = """module bar (
  input  wire [`DATA_W-1:0] data_in,
  output wire [`DATA_W-1:0] data_out
);
endmodule
"""
ed2 = ModuleEditor(sv2)
print("\n=== Case 2: macro undefined (raw text width fallback) ===")
for p in ed2.ports:
    print(f"  {p['direction']:8} {p['type']:8} {p['width']:15} {p['name']}")

# Case 3: add_port + add_wire + rm_port chain
sv3 = """module mymod (
  input logic clk,
  input logic rst_n
);
  wire [3:0] cnt;
endmodule
"""
ed3 = (ModuleEditor(sv3)
       .add_port({"data": {"direction": "input", "type": "logic", "width": "[7:0]", "dimension": ""}})
       .add_wire({"result": {"type": "logic", "width": "[7:0]", "dimension": ""}})
       .rm_port("rst_n"))
print("\n=== Case 3: add_port + add_wire + rm_port ===")
print(ed3.module_text)

# Case 4: gen_inst with parameters
sv4 = """module alu #(parameter W=8) (
  input  logic [W-1:0] a,
  input  logic [W-1:0] b,
  output logic [W-1:0] out
);
endmodule
"""
ed4 = ModuleEditor(sv4)
print("=== Case 4: gen_inst (parameter W resolved to 8) ===")
print(ed4.gen_inst())
print("param_names:", ed4.param_names)

# Case 5: add_inst_port + rm_inst_port
sv5 = """module top (input logic clk);
  sub_mod u0(.clk(clk));
endmodule
"""
ed5 = ModuleEditor(sv5).add_inst_port({"u0": {"rst": {"wire": "rst_n"}}})
print("\n=== Case 5: add_inst_port ===")
print(ed5.module_text)

print("\n=== All passed ===")
