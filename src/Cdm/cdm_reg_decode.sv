// ------------------------------------------------------------------------------
// 
// Copyright 2002 - 2024 Synopsys, INC.
// 
// This Synopsys IP and all associated documentation are proprietary to
// Synopsys, Inc. and may only be used pursuant to the terms and conditions of a
// written license agreement with Synopsys, Inc. All other use, reproduction,
// modification, or distribution of the Synopsys IP or the associated
// documentation is strictly prohibited.
// Inclusivity & Diversity - Visit SolvNetPlus to read the "Synopsys Statement on
//            Inclusivity and Diversity" (Refer to article 000036315 at
//                        https://solvnetplus.synopsys.com)
// 
// Component Name   : DWC_pcie_ctl_cxl
// Component Version: 6.14a-lca02
// Release Type     : LCA
// Build ID         : 69.19.33.11.PCIeParseConfig_1.PCIeSimulate_24.PCIeTbCommon_85.SNPSPHYSetup_21
// ------------------------------------------------------------------------------

// -------------------------------------------------------------------------
// ---  RCS information:
// ---    $DateTime: 2023/12/22 07:15:34 $
// ---    $Revision: #18 $
// ---    $Id: //dwh/pcie_iip/main/fairbanks/design/Cdm/cdm_reg_decode.sv#18 $
// -------------------------------------------------------------------------

// -----------------------------------------------------------------------------
// --- Module Description:
// -----------------------------------------------------------------------------
// --- This module decodes the local bus address into the different CDM
// --- register blocks (default values):
// --- Configuration Regs       : 0x0 - 0x3F
// --- Capabilities Config Regs : 0x40 - 0xFF
// --- Extended Config Regs     : 0x100 - 0x1FF (`ECFG_REG_OFFSET)
// --- Port Logic Regs          : 0x700 - 0x7FF (`PL_REG_OFFSET)
// --- CRGB EDMA  Regs          : 0x970 - 0xB2C (`CRGB_REG_OFFSET)
// -----------------------------------------------------------------------------

`include "include/DWC_pcie_ctl_all_defs.svh"

 
 module cdm_reg_decode(
// -- inputs --
    core_clk,
    non_sticky_rst_n,
    lbc_cdm_addr,
    lbc_cdm_cs,
    lbc_cdm_unroll,
    pl_reg_ack,
    pl_reg_data,
    cfg_reg_ack,
    cfg_reg_data,
    cfg_cap_reg_ack,
    cfg_cap_reg_data,
    ecfg_reg_ack,
    ecfg_reg_data,
    rcrb_mbar0_reg_ack,
    rcrb_mbar0_reg_data,
    rcrb_cfg_reg_ack,
    rcrb_cfg_reg_data,
    rcrb_cfg_cap_reg_ack,
    rcrb_cfg_cap_reg_data,
    rcrb_ecfg_reg_ack,
    rcrb_ecfg_reg_data,
    upstream_port,
    atu_ctrl_reg_data,
    atu_ctrl_reg_ack,
    lbc_cdm_rcrb_wire,
    lbc_cdm_rcrb_mbar0_wire,
    lbc_cdm_rcrb_dbi,
    lbc_cdm_rcrb_mbar0_dbi,

// -- outputs --
    pl_reg_sel,
    atu_reg_sel,
    cfg_reg_sel,
    cfg_cap_reg_sel,
    ecfg_reg_sel,
    cdm_pf_ecfg_addr,
    rcrb_cfg_reg_sel,
    rcrb_cfg_cap_reg_sel,
    rcrb_ecfg_reg_sel,
    rcrb_mbar0_reg_sel,
   lbc_cdm_dbi2,
   lbc_cdm_data,
   lbc_cdm_wr,
   lbc_cdm_dbi,
   crgb_cdm_cs,
   crgb_cdm_ack,
   crgb_cdm_addr,
   crgb_cdm_wdata,
   crgb_cdm_wr,
   crgb_cdm_source,
   crgb_cdm_rdata,
    cdm_lbc_data,
    cdm_lbc_ack
);
parameter INST          = 0;                    // The uniquifying parameter for each port logic instance.
parameter TP            = `TP;                  // Clock to Q delay (simulator insurance)
parameter NF            = `CX_NFUNC;            // number of functions
parameter PF_WD         = `CX_NFUNC_WD;         // number of bits needed to represent the pf number [0..NF-1], when this block is configured for sriov it is calculated as log2(NF), hardcoded to 3 otherwise
parameter CRGB_BASE_ADDRESS   = `CRGB_BASE_ADDR; // 0x970
parameter CRGB_OFFSET         = `CRGB_RANGE;     // 0xAAC
parameter CRGB_ADDR_WIDTH     = 32;
parameter CRGB_DATA_WIDTH     = 32;
parameter CRGB_BE_WIDTH       = 04;

// ----- Inputs ---------------
input                    core_clk;              // Core clock
input                    non_sticky_rst_n;      // Reset for non-sticky registers

input   [31:0]           lbc_cdm_addr;          // Address of resource being accessed
input   [NF-1:0]         lbc_cdm_cs;            // bus strobe (indicates an active bus cycle)
input                    lbc_cdm_unroll;
input                    pl_reg_ack;
input   [31:0]           pl_reg_data;           // Returning data from Port Logic Registers
input   [NF-1:0]         cfg_reg_ack;
input   [(32*NF)-1:0]    cfg_reg_data;          // Returning data from Configuration Registers
input   [NF-1:0]         cfg_cap_reg_ack;
input   [(32*NF)-1:0]    cfg_cap_reg_data;      // Returning data from Configuration Capabilities Registers
input   [NF-1:0]         ecfg_reg_ack;
input   [(32*NF)-1:0]    ecfg_reg_data;         // Returning data from Extended Configuration Registers
input                    rcrb_mbar0_reg_ack;
input   [31:0]           rcrb_mbar0_reg_data;        // Returning data from Port Logic Registers
input                    rcrb_cfg_reg_ack;
input   [31:0]           rcrb_cfg_reg_data;          // Returning data from Configuration Registers
input                    rcrb_cfg_cap_reg_ack;
input   [31:0]           rcrb_cfg_cap_reg_data;      // Returning data from Configuration Capabilities Registers
input                    rcrb_ecfg_reg_ack;
input   [31:0]           rcrb_ecfg_reg_data;         // Returning data from Extended Configuration Registers
input                    upstream_port;
input   [31:0]           atu_ctrl_reg_data;     // Returning data from ATU CTRL REG
input                    atu_ctrl_reg_ack;


input                             lbc_cdm_dbi2;

input  [CRGB_DATA_WIDTH - 1 : 0]  lbc_cdm_data;
input  [CRGB_BE_WIDTH - 1   : 0]  lbc_cdm_wr;
input                             lbc_cdm_dbi;
input                             crgb_cdm_ack;
input  [CRGB_DATA_WIDTH - 1 :0]   crgb_cdm_rdata;
input                    lbc_cdm_rcrb_wire;               // LBC indicates to CDM that it is an RCRB wire access
input                    lbc_cdm_rcrb_mbar0_wire;         // LBC indicates to CDM that it is an RCRB MEMBAR wire access
input                    lbc_cdm_rcrb_dbi;                // LBC indicates to CDM that it is an RCRB dbi access
input                    lbc_cdm_rcrb_mbar0_dbi;          // LBC indicates to CDM that it is an RCRB MEMBAR dbi access

// ----- Outputs ---------------
output                   pl_reg_sel;            // access port logic registers
//ATU UNROLL
output                   atu_reg_sel;            // access port logic registers
output  [NF-1:0]         cfg_reg_sel;           // access cfg registers
output  [NF-1:0]         cfg_cap_reg_sel;       // access cfg capabilities registers
output  [NF-1:0]         ecfg_reg_sel;          // access extended cfg registers
output  [31:0]           cdm_pf_ecfg_addr;      // Address of resource being accessed
output                   rcrb_cfg_reg_sel;      // access cxl rcrb cfg registers
output                   rcrb_cfg_cap_reg_sel;  // access cxl rcrb cfg capabilities registers
output                   rcrb_ecfg_reg_sel;     // access cxl rcrb extended cfg registers
output                   rcrb_mbar0_reg_sel;    // access cxl rcrb membar0 registers
output                                crgb_cdm_cs;
output  [CRGB_ADDR_WIDTH - 1 : 0 ]    crgb_cdm_addr;
output  [CRGB_DATA_WIDTH - 1 : 0 ]    crgb_cdm_wdata;
output  [CRGB_BE_WIDTH - 1   : 0 ]    crgb_cdm_wr;
output                                crgb_cdm_source;
output  [(32*NF-1):0]    cdm_lbc_data;          // Data back from CDM
output  [NF-1:0]         cdm_lbc_ack;           // Acknowledge - indicates completion, read data is valid

// Registers and wires
wire                                crgb_cdm_cs;
wire  [CRGB_ADDR_WIDTH - 1 : 0 ]    crgb_cdm_addr;
wire  [CRGB_DATA_WIDTH - 1 : 0 ]    crgb_cdm_wdata;
wire  [CRGB_BE_WIDTH - 1   : 0 ]    crgb_cdm_wr;
wire                                crgb_cdm_source;
wire                     pl_reg_sel;
wire            atu_reg_sel;
wire            atu_reg_space; //ATU UNROLL
wire [NF-1:0]   int_atu_ctrl_reg_ack;
wire    [NF-1:0]         cfg_reg_sel;
wire    [NF-1:0]         cfg_cap_reg_sel;
wire    [NF-1:0]         ecfg_reg_sel;
wire    [(32*NF)-1:0]    cdm_lbc_data;
wire    [NF-1:0]         cdm_lbc_ack;

wire    [(32*NF)-1:0]    cdm_pf_data;
wire    [NF-1:0]         cdm_pf_ack;
wire    [31:0]           cdm_pf_ecfg_addr; 

wire            crgb_reg_space;
wire            pl_reg_space;
wire            cfg_reg_space;
wire            ecfg_reg_space;
wire            cdm_vf_vf_active;
wire            hit_pf_reg_space;


wire [NF-1:0]         int_pl_reg_ack;
wire [NF-1:0]         int_rcrb_mbar0_reg_ack;
wire [NF-1:0]         int_rcrb_cfg_reg_ack;
wire [NF-1:0]         int_rcrb_ecfg_reg_ack;
wire [NF-1:0]         int_rcrb_cfg_cap_reg_ack;
wire [NF-1:0]         int_crgb_cdm_ack;
wire [NF-1:0]         int_no_ack;


// =============================================================================
// Address Decode space for 4K config. space
// (1) Control registers (including Port logic) in configuration space: OFFSET = `PL_REG_OFFSET
// (2) PCIE Configuration space register space: OFFSET = `ECFG_REG_OFFSET
//    --- Address 0h and FFh: PCI Configuration Space for Legacy OS
//         (a) 0-3Fh (128 bytes) is for PCI2.3 Compatible Config Space Header
//         (b) Somewhere between 3Fh and FFh is for PCI Express Capability Structure
// (3) PCI Express Entended Configuration Space = `ECFG_REG_OFFSET
// =============================================================================
//assign access_func_num  = lbc_cdm_addr[18:16];
// ------------------------------------------------------------------------------
// DMA CRGB interface address decode
// DMA port logic address space ranges from 0x970 to 0xB2C
// ------------------------------------------------------------------------------
assign crgb_reg_space    =   (lbc_cdm_addr[19]    == 1'b1     &&  lbc_cdm_unroll)  // DMA Reg Space - unroll feature
                           | (lbc_cdm_addr[11: 0] == 12'hA6C  && !lbc_cdm_unroll); // View Port Sel Register.
assign crgb_cdm_cs       = crgb_reg_space & (|lbc_cdm_cs) /* CX_SRIOV_ENABLE */ ;
assign crgb_cdm_addr     = {lbc_cdm_addr[CRGB_ADDR_WIDTH - 1 : 1],1'b0};
assign crgb_cdm_wdata    = lbc_cdm_data[CRGB_DATA_WIDTH - 1 : 0];

  assign crgb_cdm_wr       = lbc_cdm_wr[CRGB_BE_WIDTH - 1 : 0];

assign crgb_cdm_source   = (lbc_cdm_dbi | lbc_cdm_dbi2);

// ------------------------------------------------------------------------------
// cdm_pl_reg block address decode
// ------------------------------------------------------------------------------
assign pl_reg_space    =                            !lbc_cdm_unroll &&
                          (lbc_cdm_addr[11:8] == `PL_REG_OFFSET) |      //7
                          (lbc_cdm_addr[11:8] == (`PL_REG_OFFSET + 1))  //8
                          | ((lbc_cdm_addr[11:8] == (`PL_REG_OFFSET + 2)) && (lbc_cdm_addr[7:4] < 4'h3)) // iATU (0x900 to 0x92C)

                          | ((lbc_cdm_addr[11:8] == (`PL_REG_OFFSET + 4)) && ((lbc_cdm_addr[7:4] < 4'h2)) && (lbc_cdm_addr[7:4] > 4'h0))  // APP Bus and Device Number Status (0xB10) (address 0x410 in PL - offset 4, addr 10)
                          | ((lbc_cdm_addr[11:8] == (`PL_REG_OFFSET + 4)) && (lbc_cdm_addr[7:2] == 6'b0001_11)) // 0xB1C Blocking Traffic during non-D0 state




                          | ((lbc_cdm_addr[11:8] == (`PL_REG_OFFSET + 4)) && (lbc_cdm_addr[7:3] == 5'b1000_0)) // Gen4 Lane Margining (0xB80 to 0xB87)
                          | ((lbc_cdm_addr[11:8] == (`PL_REG_OFFSET + 4)) && (lbc_cdm_addr[7:3] == 5'b1000_1)) // Gen5 Lane Margining (0xB88 to 0xB8F)
                          | ((lbc_cdm_addr[11:8] == (`PL_REG_OFFSET + 4)) && (lbc_cdm_addr[7:3] == 5'b1001_1)) // Gen6 Lane Margining (0xB98 to 0xB9F)
                          | ((lbc_cdm_addr[11:8] == (`PL_REG_OFFSET + 4)) && (lbc_cdm_addr[7:2] == 6'b1001_00)) // PIPE Related (0xB90 to 0xB93)

                          | ((lbc_cdm_addr[11:8] == (`PL_REG_OFFSET + 5)) && (lbc_cdm_addr[7:3] == 5'b0100_1))  // CXL Registers (0xC48 to 0xC4F)
                          | ((lbc_cdm_addr[11:8] == (`PL_REG_OFFSET + 5)) && (lbc_cdm_addr[7:4] < 4'h7) && (lbc_cdm_addr[7:4] > 4'h4)) // CXL Registers (0xC50 to 0xC6F)
 
                          | ((lbc_cdm_addr[11:8] == (`PL_REG_OFFSET + 5)) && (lbc_cdm_addr[7:2] == 6'b0111_11)) // DBI Function Bank Control Registers (0xC7C to 0xC7F)
                          | ((lbc_cdm_addr[11:8] == (`PL_REG_OFFSET + 5)) && (lbc_cdm_addr[7:2] == 6'h20))        // Utility register (0xC80)
                          | ((lbc_cdm_addr[11:8] == (`PL_REG_OFFSET + 5)) && (lbc_cdm_addr[7:2] == 6'h22))        // PM_UTILITY register (0xC88)
                          | ((lbc_cdm_addr[11:8] == (`PL_REG_OFFSET + 4)) && (lbc_cdm_addr[7:2] == (6)'(8'h94 >> 2))) // PORT LOGIC CONTROL 2 Register (0x494)
                          | ((lbc_cdm_addr[11:8] == (`PL_REG_OFFSET + 5)) && (lbc_cdm_addr[7:2] == (6)'(8'h94 >> 2))) // AXI Inbound Posted ID Management Control (0xC94 to 0xC97)
                          | ((lbc_cdm_addr[11:8] == (`PL_REG_OFFSET + 5)) && (lbc_cdm_addr[7:2] == (6)'(8'hA8 >> 2))) //RX Retry Buffer PL CTRL (0x5A8)
                          | ((lbc_cdm_addr[11:8] == (`PL_REG_OFFSET + 5)) && (lbc_cdm_addr[7:2] == (6)'(8'hAC >> 2)))  // PRBS (0x5ac)
                          | ((lbc_cdm_addr[11:8] == (`PL_REG_OFFSET + 4)) && ((lbc_cdm_addr[7:4] < 4'h5)) && (lbc_cdm_addr[7:4] > 4'h2)); // LTR (0xB30 to 0xB3F) + AUX_FREQ (0xB40 to 0xB43)



assign pl_reg_sel       = pl_reg_space & (|lbc_cdm_cs)
                            && !lbc_cdm_unroll
;


//ATU Unroll
assign atu_reg_space = lbc_cdm_addr[19] == 1'b0; //Addresses for ATU unroll
assign atu_reg_sel = atu_reg_space && lbc_cdm_unroll && (|lbc_cdm_cs);

assign cfg_reg_space    = lbc_cdm_addr[11:8] == `CFG_REG_OFFSET  
                           && !lbc_cdm_unroll
                          ;        
assign ecfg_reg_space   = (lbc_cdm_addr[11:8] >= `ECFG_REG_OFFSET)
                            && !lbc_cdm_unroll
                            & (lbc_cdm_addr[11:8] < `PL_REG_OFFSET)
                           ; //Port Logic Regs : 0x700
                          // DMA Port Logic Registers VSEC can be ORed to the ecfg_reg_space

wire lbc_cdm_rcrb;
wire lbc_cdm_rcrb_mbar0;
assign lbc_cdm_rcrb = lbc_cdm_rcrb_wire | lbc_cdm_rcrb_dbi;
assign lbc_cdm_rcrb_mbar0 = lbc_cdm_rcrb_mbar0_wire | lbc_cdm_rcrb_mbar0_dbi;

assign cfg_reg_sel      = ({NF{cfg_reg_space}}) & ({NF{(~|lbc_cdm_addr[7:6])}}) & lbc_cdm_cs
       & ({NF{~lbc_cdm_rcrb}} | {NF{~upstream_port}}) & {NF{~lbc_cdm_rcrb_mbar0}}
;
assign cfg_cap_reg_sel  = ({NF{cfg_reg_space}}) & ({NF{(|lbc_cdm_addr[7:6])}}) & lbc_cdm_cs
       & ({NF{~lbc_cdm_rcrb}} | {NF{~upstream_port}}) & {NF{~lbc_cdm_rcrb_mbar0}}
;
assign ecfg_reg_sel     =  ({NF{ecfg_reg_space}}) & lbc_cdm_cs
       & ({NF{~lbc_cdm_rcrb}} | {NF{~upstream_port}}) & {NF{~lbc_cdm_rcrb_mbar0}}
;
assign rcrb_cfg_reg_sel      = upstream_port & cfg_reg_space & (~|lbc_cdm_addr[7:6]) & lbc_cdm_cs[0]
       & (lbc_cdm_rcrb_wire | lbc_cdm_rcrb_dbi)
;
assign rcrb_cfg_cap_reg_sel  = upstream_port & cfg_reg_space & (|lbc_cdm_addr[7:6]) & lbc_cdm_cs[0]
       & (lbc_cdm_rcrb_wire | lbc_cdm_rcrb_dbi)
;
assign rcrb_ecfg_reg_sel     = upstream_port & ecfg_reg_space & lbc_cdm_cs[0]
       & (lbc_cdm_rcrb_wire | lbc_cdm_rcrb_dbi)
;
assign rcrb_mbar0_reg_sel  = lbc_cdm_cs[0]
       & (lbc_cdm_rcrb_mbar0_wire | lbc_cdm_rcrb_mbar0_dbi)
;


assign cdm_pf_ecfg_addr = lbc_cdm_addr ;



reg no_ack;
wire no_ack_sr_clr;
reg [NF-1:0] cs_mask_l;
always @(posedge core_clk or negedge non_sticky_rst_n)
begin
  if (~non_sticky_rst_n) 
     cs_mask_l    <= #TP 0;        
  else
     cs_mask_l <= #TP lbc_cdm_cs;
  end

wire        pl_reg_ack_int;
wire [31:0] pl_reg_data_int;
delay_n
#(
    .N(1),
    .WD(33)
) u_delay_pl_reg (
    .clk        (core_clk),
    .rst_n      (non_sticky_rst_n),
    .clear      (1'b0),
    .din        ({pl_reg_ack    , pl_reg_data     }),
    .dout       ({pl_reg_ack_int, pl_reg_data_int })
);

assign int_pl_reg_ack = cs_mask_l & {NF{pl_reg_ack_int}};
assign int_rcrb_mbar0_reg_ack = cs_mask_l & {NF{rcrb_mbar0_reg_ack}};
assign int_rcrb_cfg_reg_ack = cs_mask_l & {NF{rcrb_cfg_reg_ack}};
assign int_rcrb_ecfg_reg_ack = cs_mask_l & {NF{rcrb_ecfg_reg_ack}};
assign int_rcrb_cfg_cap_reg_ack = cs_mask_l & {NF{rcrb_cfg_cap_reg_ack}};
assign int_crgb_cdm_ack = cs_mask_l & {NF{crgb_cdm_ack}};
assign int_no_ack = cs_mask_l & {NF{no_ack}};
//ATU Unroll
assign int_atu_ctrl_reg_ack = cs_mask_l & {NF{atu_ctrl_reg_ack}};
assign no_ack_sr_clr = 1;

assign hit_pf_reg_space = (|cfg_reg_sel) | (|cfg_cap_reg_sel) | (|ecfg_reg_sel) | pl_reg_sel
                        | crgb_cdm_cs 
                        | atu_reg_sel
                        | rcrb_cfg_reg_sel
                        | rcrb_cfg_cap_reg_sel
                        | rcrb_ecfg_reg_sel
                        | rcrb_mbar0_reg_sel
                        ;
         
always @(posedge core_clk or negedge non_sticky_rst_n)
begin
    if (~non_sticky_rst_n) begin
        no_ack          <= #TP 0;
    end
    else if ( no_ack 
             ) begin
           no_ack       <= #TP 1'b0;
    end
    else if ((|lbc_cdm_cs) && no_ack_sr_clr
            ) begin
           no_ack       <= #TP ~hit_pf_reg_space
                           ;
    end

end

// Returning data mux
assign cdm_pf_data     =      (|cfg_reg_ack)       ? cfg_reg_data
                            : (|cfg_cap_reg_ack)   ? cfg_cap_reg_data
                            : (|ecfg_reg_ack)      ? ecfg_reg_data
                            : (pl_reg_ack_int)     ? {NF{pl_reg_data_int}}
                            : (crgb_cdm_ack)       ? {NF{crgb_cdm_rdata}}
                            : (atu_ctrl_reg_ack)   ? {NF{atu_ctrl_reg_data}}
                            : (|rcrb_cfg_reg_ack)      ? {NF{rcrb_cfg_reg_data}}
                            : (|rcrb_cfg_cap_reg_ack)  ? {NF{rcrb_cfg_cap_reg_data}}
                            : (|rcrb_ecfg_reg_ack)     ? {NF{rcrb_ecfg_reg_data}}
                            : (|rcrb_mbar0_reg_ack)  ? {NF{rcrb_mbar0_reg_data}}
                            : {NF{`PCIE_UNUSED_RESPONSE}};

assign cdm_lbc_data     =  
                           |cdm_pf_ack                             ? cdm_pf_data
                            : {NF{`PCIE_UNUSED_RESPONSE}};

// Returning Ack mux
assign cdm_pf_ack        = int_pl_reg_ack | cfg_reg_ack | ecfg_reg_ack | cfg_cap_reg_ack
                         | int_crgb_cdm_ack
                         | int_atu_ctrl_reg_ack
                         | int_rcrb_cfg_reg_ack
                         | int_rcrb_cfg_cap_reg_ack
                         | int_rcrb_ecfg_reg_ack
                         | int_rcrb_mbar0_reg_ack
                         ;

assign cdm_lbc_ack      =  
                           cdm_pf_ack
                         | int_no_ack;




endmodule
