//======================================================================
// Module : STARSKY_apb_mux_1m9s
// Function: 1 Master, 9 Slave APB mux (no PPROT/PSLVERR/PSTRB)
// Data width: fixed 32 bits
// Address width: 19 bits (0x00000 - 0x7FFFF)
// PHY0-3 : 0x00000,0x10000,0x20000,0x30000 (64KB each)
// PCIE0-3: 0x40000,0x41000,0x42000,0x43000 (4KB each)
// TOP    : 0x44000 - 0x443FF (1KB)
// Reserved addresses complete with PREADY=1 and PRDATA=0.
//======================================================================
module STARSKY_apb_mux_1m9s (
    input  wire        apb_pclk,
    input  wire        apb_presetn,
    input  wire [18:0] apb_paddr,
    input  wire        apb_psel,
    input  wire        apb_penable,
    input  wire        apb_pwrite,
    input  wire [31:0] apb_pwdata,
    output wire [31:0] apb_prdata,
    output wire        apb_pready,
    // Slave 0: PHY0
    output wire        phy0_apb_pclk,
    output wire        phy0_apb_presetn,
    output wire [15:0] phy0_apb_paddr,
    output wire        phy0_apb_psel,
    output wire        phy0_apb_penable,
    output wire        phy0_apb_pwrite,
    output wire [31:0] phy0_apb_pwdata,
    input  wire [31:0] phy0_apb_prdata,
    input  wire        phy0_apb_pready,
    // Slave 1: PHY1
    output wire        phy1_apb_pclk,
    output wire        phy1_apb_presetn,
    output wire [15:0] phy1_apb_paddr,
    output wire        phy1_apb_psel,
    output wire        phy1_apb_penable,
    output wire        phy1_apb_pwrite,
    output wire [31:0] phy1_apb_pwdata,
    input  wire [31:0] phy1_apb_prdata,
    input  wire        phy1_apb_pready,
    // Slave 2: PHY2
    output wire        phy2_apb_pclk,
    output wire        phy2_apb_presetn,
    output wire [15:0] phy2_apb_paddr,
    output wire        phy2_apb_psel,
    output wire        phy2_apb_penable,
    output wire        phy2_apb_pwrite,
    output wire [31:0] phy2_apb_pwdata,
    input  wire [31:0] phy2_apb_prdata,
    input  wire        phy2_apb_pready,
    // Slave 3: PHY3
    output wire        phy3_apb_pclk,
    output wire        phy3_apb_presetn,
    output wire [15:0] phy3_apb_paddr,
    output wire        phy3_apb_psel,
    output wire        phy3_apb_penable,
    output wire        phy3_apb_pwrite,
    output wire [31:0] phy3_apb_pwdata,
    input  wire [31:0] phy3_apb_prdata,
    input  wire        phy3_apb_pready,
    // Slave 4: PCIE0
    output wire        pcie0_apb_pclk,
    output wire        pcie0_apb_presetn,
    output wire [11:0] pcie0_apb_paddr,
    output wire        pcie0_apb_psel,
    output wire        pcie0_apb_penable,
    output wire        pcie0_apb_pwrite,
    output wire [31:0] pcie0_apb_pwdata,
    input  wire [31:0] pcie0_apb_prdata,
    input  wire        pcie0_apb_pready,
    // Slave 5: PCIE1
    output wire        pcie1_apb_pclk,
    output wire        pcie1_apb_presetn,
    output wire [11:0] pcie1_apb_paddr,
    output wire        pcie1_apb_psel,
    output wire        pcie1_apb_penable,
    output wire        pcie1_apb_pwrite,
    output wire [31:0] pcie1_apb_pwdata,
    input  wire [31:0] pcie1_apb_prdata,
    input  wire        pcie1_apb_pready,
    // Slave 6: PCIE2
    output wire        pcie2_apb_pclk,
    output wire        pcie2_apb_presetn,
    output wire [11:0] pcie2_apb_paddr,
    output wire        pcie2_apb_psel,
    output wire        pcie2_apb_penable,
    output wire        pcie2_apb_pwrite,
    output wire [31:0] pcie2_apb_pwdata,
    input  wire [31:0] pcie2_apb_prdata,
    input  wire        pcie2_apb_pready,
    // Slave 7: PCIE3
    output wire        pcie3_apb_pclk,
    output wire        pcie3_apb_presetn,
    output wire [11:0] pcie3_apb_paddr,
    output wire        pcie3_apb_psel,
    output wire        pcie3_apb_penable,
    output wire        pcie3_apb_pwrite,
    output wire [31:0] pcie3_apb_pwdata,
    input  wire [31:0] pcie3_apb_prdata,
    input  wire        pcie3_apb_pready,
    // Slave 8: TOP
    output wire        top_apb_pclk,
    output wire        top_apb_presetn,
    output wire [ 9:0] top_apb_paddr,
    output wire        top_apb_psel,
    output wire        top_apb_penable,
    output wire        top_apb_pwrite,
    output wire [31:0] top_apb_pwdata,
    input  wire [31:0] top_apb_prdata,
    input  wire        top_apb_pready
);
  wire [8:0] sel;
  // Decode address using only valid bits [18:0].
  assign sel[0] = (apb_paddr[18:16] == 3'h0);
  assign sel[1] = (apb_paddr[18:16] == 3'h1);
  assign sel[2] = (apb_paddr[18:16] == 3'h2);
  assign sel[3] = (apb_paddr[18:16] == 3'h3);
  assign sel[4] = (apb_paddr[18:12] == 7'h40);
  assign sel[5] = (apb_paddr[18:12] == 7'h41);
  assign sel[6] = (apb_paddr[18:12] == 7'h42);
  assign sel[7] = (apb_paddr[18:12] == 7'h43);
  assign sel[8] = (apb_paddr[18:10] == 9'h110);

  wire [8:0] active_sel = sel & {9{apb_psel}};
  assign phy0_apb_pclk = apb_pclk;
  assign phy0_apb_presetn = apb_presetn;
  assign phy0_apb_paddr = apb_paddr[15:0];
  assign phy0_apb_psel = active_sel[0];
  assign phy0_apb_penable = apb_penable & active_sel[0];
  assign phy0_apb_pwrite = apb_pwrite;
  assign phy0_apb_pwdata = apb_pwdata;
  assign phy1_apb_pclk = apb_pclk;
  assign phy1_apb_presetn = apb_presetn;
  assign phy1_apb_paddr = apb_paddr[15:0];
  assign phy1_apb_psel = active_sel[1];
  assign phy1_apb_penable = apb_penable & active_sel[1];
  assign phy1_apb_pwrite = apb_pwrite;
  assign phy1_apb_pwdata = apb_pwdata;
  assign phy2_apb_pclk = apb_pclk;
  assign phy2_apb_presetn = apb_presetn;
  assign phy2_apb_paddr = apb_paddr[15:0];
  assign phy2_apb_psel = active_sel[2];
  assign phy2_apb_penable = apb_penable & active_sel[2];
  assign phy2_apb_pwrite = apb_pwrite;
  assign phy2_apb_pwdata = apb_pwdata;
  assign phy3_apb_pclk = apb_pclk;
  assign phy3_apb_presetn = apb_presetn;
  assign phy3_apb_paddr = apb_paddr[15:0];
  assign phy3_apb_psel = active_sel[3];
  assign phy3_apb_penable = apb_penable & active_sel[3];
  assign phy3_apb_pwrite = apb_pwrite;
  assign phy3_apb_pwdata = apb_pwdata;
  assign pcie0_apb_pclk = apb_pclk;
  assign pcie0_apb_presetn = apb_presetn;
  assign pcie0_apb_paddr = apb_paddr[11:0];
  assign pcie0_apb_psel = active_sel[4];
  assign pcie0_apb_penable = apb_penable & active_sel[4];
  assign pcie0_apb_pwrite = apb_pwrite;
  assign pcie0_apb_pwdata = apb_pwdata;
  assign pcie1_apb_pclk = apb_pclk;
  assign pcie1_apb_presetn = apb_presetn;
  assign pcie1_apb_paddr = apb_paddr[11:0];
  assign pcie1_apb_psel = active_sel[5];
  assign pcie1_apb_penable = apb_penable & active_sel[5];
  assign pcie1_apb_pwrite = apb_pwrite;
  assign pcie1_apb_pwdata = apb_pwdata;
  assign pcie2_apb_pclk = apb_pclk;
  assign pcie2_apb_presetn = apb_presetn;
  assign pcie2_apb_paddr = apb_paddr[11:0];
  assign pcie2_apb_psel = active_sel[6];
  assign pcie2_apb_penable = apb_penable & active_sel[6];
  assign pcie2_apb_pwrite = apb_pwrite;
  assign pcie2_apb_pwdata = apb_pwdata;
  assign pcie3_apb_pclk = apb_pclk;
  assign pcie3_apb_presetn = apb_presetn;
  assign pcie3_apb_paddr = apb_paddr[11:0];
  assign pcie3_apb_psel = active_sel[7];
  assign pcie3_apb_penable = apb_penable & active_sel[7];
  assign pcie3_apb_pwrite = apb_pwrite;
  assign pcie3_apb_pwdata = apb_pwdata;
  assign top_apb_pclk = apb_pclk;
  assign top_apb_presetn = apb_presetn;
  assign top_apb_paddr = apb_paddr[9:0];
  assign top_apb_psel = active_sel[8];
  assign top_apb_penable = apb_penable & active_sel[8];
  assign top_apb_pwrite = apb_pwrite;
  assign top_apb_pwdata = apb_pwdata;

  // Only the addressed slave contributes to the read response.
  // No mapped slave: zero read data, immediate completion.
  assign apb_prdata =
        ({32{active_sel[0]}} & phy0_apb_prdata) |
        ({32{active_sel[1]}} & phy1_apb_prdata) |
        ({32{active_sel[2]}} & phy2_apb_prdata) |
        ({32{active_sel[3]}} & phy3_apb_prdata) |
        ({32{active_sel[4]}} & pcie0_apb_prdata) |
        ({32{active_sel[5]}} & pcie1_apb_prdata) |
        ({32{active_sel[6]}} & pcie2_apb_prdata) |
        ({32{active_sel[7]}} & pcie3_apb_prdata) |
        ({32{active_sel[8]}} & top_apb_prdata);

  // Idle and reserved accesses complete immediately. During a mapped
  // transfer, only the selected slave controls PREADY, including wait states.
  assign apb_pready = !(|active_sel) ||
        |(active_sel & {top_apb_pready, pcie3_apb_pready, pcie2_apb_pready,
                       pcie1_apb_pready, pcie0_apb_pready, phy3_apb_pready,
                       phy2_apb_pready, phy1_apb_pready, phy0_apb_pready});

endmodule
