module memory(    address,
    data_in,
    data_out,
    read_write,
    chip_en
   );




  input wire [7:0] address, data_in;
  output reg [7:0] data_out;
  input wire read_write, chip_en;
  
  function automatic [1:0] bget;
	input integer index;
	assign bget = 16'h0[index*2+:2];
  endfunction
  
  reg [7:0] mem [0:255];



  always @ (address or data_in or read_write or chip_en)
    if (read_write == 1 && chip_en == 1) begin
      mem[address] = data_in;
  end

  always @ (read_write or chip_en or address)
    if (read_write == 0 && chip_en)
      data_out = mem[address];
    else
      data_out = 0;
    // Add an instance of the adder module

    /*
    Add an instance of the adder module
    */

//   addr a0 (
//     .a(a),
//     .b(b),
//     .s(s)
//   );

  addr a0 (
    .a(a),
    .b(b),
    .s(s)
  );

endmodule

module adder 
#(

    //
    //
    //
    /*

    */
    parameter WIDTH = 8,
    //
    //
    //
    /*

    */    
    localparam SWIDTH = WIDTH + 1

) (
  input wire [WIDTH-1:0] a,
  input wire [WIDTH-1:0] b,
  output wire [SWIDTH-1:0] s
);

  assign s = a + b;
endmodule