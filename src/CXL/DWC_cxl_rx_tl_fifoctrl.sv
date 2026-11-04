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
// --- RCS information:
// ---   $DateTime: 2023/06/26 08:32:07 $
// ---   $Revision: #4 $
// ---   $Id: //dwh/pcie_iip/main/fairbanks/design/CXL/DWC_cxl_rx_tl_fifoctrl.sv#4 $
// -------------------------------------------------------------------------
// --- Module Description:
// --- FIFO Controller 
// ----------------------------------------------------------------------------
// CXL Transaction Layer Reciever FIFO Controller 
// single clock domain fifo controller
// Supports 2 architectures of RAM interface
//  CXL_RAM_1LAT_ARCH -1 Ram Rdata is used in the very next cycle on issuing  RAM Read
//      CXL_RAM_1LAT_ARCH -0 Ram Rdata is registered and used, Ram Rdata is available in the very next cycle on issuing RAM Read
// ----------------------------------------------------------------------------

`include "include/DWC_pcie_ctl_all_defs.svh"
`include "CXL/pkg/DWC_cxl_pkg.svh"

`include "CXL/svif/DWC_cxl_clk_rst_if.svh"
`include "CXL/svif/DWC_cxl_ram2p_if.svh"

module DWC_cxl_rx_tl_fifoctrl #(
    parameter   TP        = `TP
  , parameter   DEPTH     = 16
  , parameter   ADDR_WIDTH= 4
  , parameter   DATA_SIZE = 128
  , parameter   ERR_MODE  = 2
  )(
    input                               clk
  , input                               rst_n
  , input                               fifo_push_req_n
  , input   logic [(DATA_SIZE-1) : 0]   fifo_push_data_in
  , output                              fifo_empty
  , input                               fifo_pop_req_n
  , output  logic [(DATA_SIZE-1) : 0]   fifo_data_out
  , output  logic                       fifo_pending
  , DWC_cxl_ram2p_if.master_mp          b_ram
  ); 
  import DWC_cxl_pkg::*;

  //  Internal names for the RAM interface
  //  we:       comb output, function(fifo_pop_req_n, fifo_push_req_n,fifo_full(registered)) when TMR==0
  //  wr_addr:  Registered output for TMR==0
  //  rd_addr:  Registered output for TMR==0
  //  wdata:    currently combo, comes from link and Input Mapper stage, goes to RAM
  //  rdata:    input coming from RAM
  logic                       ram_we;
  logic [(ADDR_WIDTH-1): 0]   ram_wr_addr;
  logic [(DATA_SIZE-1) : 0]   ram_wdata;
  logic                       ram_rd;
  logic [(ADDR_WIDTH-1): 0]   ram_rd_addr;
  logic [(DATA_SIZE-1) : 0]   ram_rdata;            

  //  Connect to the external interface
  //  The use of '0 ORed with the internal signals to set the external signals
  //  in the statements below prevents linting warnings due to wider b_ram
  //  interface signals defined in the top modules.
  assign b_ram.s_ram_we       = ram_we;
  assign b_ram.s_ram_wr_addr  = '0 | ram_wr_addr;
  assign b_ram.s_ram_wdata    = '0 | ram_wdata;
  assign b_ram.s_ram_rd       = ram_rd;
  assign b_ram.s_ram_rd_addr  = '0 | ram_rd_addr;
  assign ram_rdata            = b_ram.s_ram_rdata;
  //  Ignore the following two outputs at this level of the hierarchy.
  //  They are assigned correctly at the appropriate level with the check bits.
  assign b_ram.s_ram_wr_addr_par = '0;
  assign b_ram.s_ram_rd_addr_par = '0;

logic                       ram_empty       ;
logic                       ram_we_n        ;

logic [ADDR_WIDTH-1 :0 ]    ae_level        ;
logic [ADDR_WIDTH-1 :0 ]    af_thresh       ;
logic                       actual_fifo_push_req_n;
logic [1:0]                 outstanding_rds ;//increment with issue of read to ram, decrement with read from the fifo- registered version

assign ae_level  = {{ADDR_WIDTH-1{1'b0}},1'b1};
assign af_thresh = unsigned'(DEPTH-1);
assign fifo_pending = ((~ram_empty)||(outstanding_rds!='h0));
assign ram_wdata = fifo_push_data_in;
assign ram_we    = (~ram_we_n);

DWC_pcie_ctl_bcmmod06_atv
 #(.DEPTH(DEPTH),
                  .ERR_MODE(ERR_MODE), 
                  .ADDR_WIDTH(ADDR_WIDTH),
                  .TMR(TMR_EN))u_DWC_cxl_rx_tl_fifoctrl(
                                         .clk           (clk                    )
                                        ,.rst_n         (rst_n                  )
                                        ,.init_n        (1'b1                   )
                                        ,.push_req_n    (actual_fifo_push_req_n )
                                        ,.pop_req_n     (~ram_rd                )
                                        ,.diag_n        ( 1'b1                  )
                                        ,.ae_level      (ae_level               )//almost empty threshold level
                                        ,.af_thresh     (af_thresh              )//almost full threshold level
                                        ,.we_n          (ram_we_n               )
                                        ,.empty         (ram_empty              )
                                        ,.almost_empty  (                       )
                                        ,.half_full     (                       )
                                        ,.almost_full   (                       )
                                        ,.full          (                       )
                                        ,.error         (                       )
                                        ,.wr_addr       (ram_wr_addr            )
                                        ,.rd_addr       (ram_rd_addr            )
                                        ,.wrd_count     (                       )
                                        ,.nxt_empty_n   (                       )
                                        ,.nxt_full      (                       )
                                        ,.nxt_error     (                       )
                                        );


//Ram Rdata is registered and used, Ram Rdata is available in the very next cycle on issuing  RAM Read
logic                       allow_outstanding_rds;
logic                       bypass_ram      ;
logic                       ram_rd_i        ;
logic [1:0]                 rd_ptr          ; 
logic [1:0]                 wr_ptr          ; 
logic [2:0]                 reg_set_valid  ; 
logic [2:0][DATA_SIZE-1:0]  reg_set        ;

// Function to return its input modulo 3
function automatic logic [1:0] MOD_3 (
  logic [1:0] a
  );
  //  If the value is all ones return all zeros, otherwise return the value.
  return ( (a=='1)? '0 : a );
endfunction
  

always_ff @(posedge clk or negedge rst_n) begin 
  if (!rst_n) begin
        outstanding_rds    <= # TP 2'b0;
  end else if(bypass_ram==1'b1)begin
        casez({fifo_push_req_n, fifo_pop_req_n})
        'b01:begin
        outstanding_rds    <= # TP outstanding_rds+1'b1;
        end 
        'b10:begin
        outstanding_rds    <= # TP outstanding_rds-1'b1;
        end 
        endcase
  end else if(ram_rd && (fifo_pop_req_n)) begin
        outstanding_rds    <= # TP outstanding_rds+1'b1;
  end else if((~ram_rd) && (~fifo_pop_req_n)) begin
        outstanding_rds    <= # TP outstanding_rds-1'b1;
  end 
end 

assign allow_outstanding_rds  = (outstanding_rds<'h3);


assign ram_rd = ((~ram_empty)&&allow_outstanding_rds);



always_ff @(posedge clk or negedge rst_n) begin :  rx_tl_fifo_reg_proc
  if (!rst_n) begin
    ram_rd_i <= # TP 1'b0 ;
  end else begin
    ram_rd_i <= # TP ram_rd;
  end 
end : rx_tl_fifo_reg_proc

//ram_rd_i==0 allows scenario where ram_empty goes low right after 1st read, and allow_outstanding_rds allows to be written to the registers
assign bypass_ram             = ((ram_empty==1'b1)&&(ram_rd_i==0)&&(allow_outstanding_rds==1'b1));

//bypass_ram should be zero and fifo_push_req_n should be zero/active
assign actual_fifo_push_req_n = (bypass_ram || fifo_push_req_n);

always_ff @(posedge clk or negedge rst_n) begin 
  if (!rst_n) begin
        rd_ptr             <= # TP '0;
  end else begin
        rd_ptr             <= # TP (~fifo_pop_req_n)?
                                      (rd_ptr==2'h2) ? 2'h0 : (rd_ptr+2'h1)
                                    : rd_ptr;
  end 
end

always_ff @(posedge clk or negedge rst_n) begin 
  if (!rst_n) begin
        wr_ptr             <= # TP '0;
  end else begin
        wr_ptr             <= # TP ((bypass_ram && (~fifo_push_req_n))||ram_rd_i)?
                                      (wr_ptr==2'h2) ? 2'h0 : (wr_ptr+2'h1)
                                    : wr_ptr;
  end 
end 

genvar g_lp_idx;
generate for(g_lp_idx=0; g_lp_idx<3; g_lp_idx++) begin
always_ff @(posedge clk or negedge rst_n) begin 
  if (!rst_n) begin
        reg_set_valid[g_lp_idx]     <= # TP 1'b0;
  end else if(bypass_ram && (~fifo_push_req_n) && (wr_ptr==g_lp_idx)) begin
        reg_set_valid[g_lp_idx]     <= # TP 1'b1;
  end else if(ram_rd_i && (wr_ptr==g_lp_idx))begin
        reg_set_valid[g_lp_idx]     <= # TP 1'b1;
  end else if((~fifo_pop_req_n)&&(rd_ptr==g_lp_idx))begin
        reg_set_valid[g_lp_idx]     <= # TP 1'b0;
  end 
end 
end
endgenerate

assign fifo_empty = ~(|reg_set_valid);

always_ff @(posedge clk or negedge rst_n) begin 
  if (!rst_n) begin
        reg_set           <= # TP  '0;
  end else if(bypass_ram && (~fifo_push_req_n)) begin
        reg_set[MOD_3(wr_ptr)]           <= # TP fifo_push_data_in;
  end else if(ram_rd_i)begin
        reg_set[MOD_3(wr_ptr)]           <= # TP ram_rdata;
  end 
end 



assign  fifo_data_out = reg_set[MOD_3(rd_ptr)][DATA_SIZE-1:0];


endmodule
