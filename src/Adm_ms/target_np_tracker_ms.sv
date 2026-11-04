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
// ---    $DateTime: 2023/04/29 12:35:01 $
// ---    $Revision: #3 $
// ---    $Id: //dwh/pcie_iip/main/fairbanks/design/Adm_ms/target_np_tracker_ms.sv#3 $
// -------------------------------------------------------------------------
// Module Description:
// -------------------------------------------------------------------------
`include "include/DWC_pcie_ctl_all_defs.svh"

 
 module target_np_tracker_ms
  #(
    // -------------------------------------------------------------------------------------
    // Parameters modified by an instantiation parameter assignment
    // -------------------------------------------------------------------------------------
    parameter TARGET_CPL_LUT_ENABLE    = 1,
    parameter DMA_ENABLE               = 1,
    parameter NVC_POP_PER_CYCLE        = 1,
    parameter H_VC                     = 7,
    parameter L_VC                     = 0,
    parameter REMOTE_MAX_TAG_PLUS_1    = 4,

    parameter TP                       = `TP,
    parameter NVC                      = `CX_NVC,
    parameter NVC_POP                  = NVC_POP_PER_CYCLE,
    parameter CNT_WD                   = `CX_LOGBASE2(REMOTE_MAX_TAG_PLUS_1) + 1,
    parameter INC_WD                   = `CX_LOGBASE2(NVC_POP_PER_CYCLE) + 1,
    parameter DEC_WD                   = 2
    )
   
                              (
    // -------------------------------------------------------------------------------------
    // Clocks and resets
    // -------------------------------------------------------------------------------------
    input                  core_clk ,
    input                  core_rst_n ,

    // -------------------------------------------------------------------------------------
    // Dynamic inputs
    // -------------------------------------------------------------------------------------
    input                  dyn_target_cpl_lut_enable,
    input                  dyn_dma_enable,
    input [3:0]            dyn_h_vc,               // 8VC + 1 DMA possible groups 
    input [3:0]            dyn_l_vc, 
    input [CNT_WD-1:0]     dyn_remote_max_tag_plus_1,

    // -------------------------------------------------------------------------------------
    // RTGT1 interface trasaction throttling
    // -------------------------------------------------------------------------------------
    input                  radm_trgt1_dma_grant,       // DMA lookupid granted
    input                  radm_trgt1_dma_cpl_rlsd,    // DMA lookupid released
    output                 trgt_lut_dma_pkt_halt,      // Target LUT pkt halt to DMA

    input [(NVC*3)-1:0]    radm_grant_tlp_type,        // RADM order lookupid granted
    input [NVC-1:0]        client_lookupid_rlsd,       // Target LUT lookupid released using the client interface 
    input [NVC-1:0]        port_logic_delete_lookupid, // App lookupid released using the port logic register
    output                 trgt_lut_order_pkt_halt     // Target LUT pkt halt to radm_order

    );


// ####################################
// RTL
// ####################################

// ### NP_tracker control signals ###
reg [CNT_WD-1:0] trgt_lookupid_used;
reg [INC_WD-1:0] inc_lookupid_used;  // we can grant pop more than one vc per cycle. 
reg [DEC_WD-1:0] dec_lookupid_used;  // trgt_cpl_lut releases 1/2 lookupid per clycle; DMA releases 1 lookupid per cycle => Only 2 bits needed
reg int_trgt_lut_order_pkt_halt;
reg int_trgt_lut_dma_pkt_halt;

wire int_radm_trgt1_dma_grant;
wire int_radm_trgt1_dma_cpl_rlsd;
wire [(NVC*3)-1:0] int_radm_grant_tlp_type;
wire [NVC-1:0] int_client_lookupid_rlsd;
wire [NVC-1:0] int_port_logic_delete_lookupid;

// ### Add register for QOR
reg [NVC-1:0] client_lookupid_rlsd_reg;

always @(posedge core_clk or negedge core_rst_n)
begin
   if(!core_rst_n)
      client_lookupid_rlsd_reg <= #TP 0;
   else begin
      client_lookupid_rlsd_reg <= #TP client_lookupid_rlsd; 
   end
end

// ### Protection: Mux to disable the inputs ###
assign int_radm_grant_tlp_type         = ((TARGET_CPL_LUT_ENABLE != 0) && dyn_target_cpl_lut_enable) ? radm_grant_tlp_type        : {(NVC*3){1'b0}};
assign int_client_lookupid_rlsd        = ((TARGET_CPL_LUT_ENABLE != 0) && dyn_target_cpl_lut_enable) ? client_lookupid_rlsd_reg   : {(NVC){1'b0}};
assign int_port_logic_delete_lookupid  = ((TARGET_CPL_LUT_ENABLE != 0) && dyn_target_cpl_lut_enable) ? port_logic_delete_lookupid : {(NVC){1'b0}};

assign int_radm_trgt1_dma_grant        = ((DMA_ENABLE != 0) && dyn_dma_enable) ? radm_trgt1_dma_grant    : 1'b0;
assign int_radm_trgt1_dma_cpl_rlsd     = ((DMA_ENABLE != 0) && dyn_dma_enable) ? radm_trgt1_dma_cpl_rlsd : 1'b0;

// spyglass disable_block W164a
// SMD: Identifies assignments in which the LHS width is less than the RHS width
// SJ: The inc_/dec_ signals are already sized to account for the maximum
// number of simultaneous requests (log2(H_VC-L_VC) >= CNT_WD/INT_WD/DWC_WD)
// ### Increment ###
always @(*) begin 
   integer i;

   inc_lookupid_used = 0 + int_radm_trgt1_dma_grant;
   // Maximum inc_lookupid_used = 9 = (8NVC + 1 DMA) => enough 4bits WD
   // Go through all NP VC. Technically only 1 VC popped per cycle
   for(i=L_VC;i<(H_VC+1);i++) begin
      if((i>=dyn_l_vc) && (i<(dyn_h_vc+1))) // Added to allow dynamic VC groups
         inc_lookupid_used = inc_lookupid_used + int_radm_grant_tlp_type[i*3+1];
   end // for
end

// ### Decrement ###
// ###spyglass disable_block W164b
always @(*) begin 
   integer i;

   dec_lookupid_used = 0 + int_radm_trgt1_dma_cpl_rlsd;
   // Maximum dec_lookupid_used = 3 = (1 CORE + 1 APP + 1 DMA) => enough 4bits WD   
   // Go through all NP VC. 
   for(i=L_VC;i<(H_VC+1);i++) begin
      if((i>=dyn_l_vc) && (i<(dyn_h_vc+1))) // Added to allow dynamic VC groups
         dec_lookupid_used = dec_lookupid_used + int_client_lookupid_rlsd[i] + int_port_logic_delete_lookupid[i]; 
   end // for
end
// ###spyglass enable_block W164b

// ### Counter ###
always @(posedge core_clk or negedge core_rst_n)
begin

   if(!core_rst_n)
      trgt_lookupid_used <= #TP 0;
   else begin
      trgt_lookupid_used <= #TP trgt_lookupid_used + inc_lookupid_used - dec_lookupid_used; 
   end
end
// spyglass enable_block W164a

wire   inc_greater_dec;
assign inc_greater_dec=(inc_lookupid_used>dec_lookupid_used);

wire disable_cond; // To increase robustness and legibility. No needed
assign disable_cond = (dyn_remote_max_tag_plus_1==2);

// ### Order Conditions ###
always @(*) begin
// For NVC_POP=1, DMA_ENABLE=1
// cond1: trgt_lookupid_used=MAX-2 radm_grant_tlp_type=1 radm_trgt1_dma_grant=1 int_client_lookupid_rlsd=0 int_port_logic_delete_lookupid=0 int_radm_trgt1_dma_cpl_rlsd=0
// cond2: trgt_lookupid_used=MAX-1 radm_grant_tlp_type=1 radm_trgt1_dma_grant=0 int_client_lookupid_rlsd=0 int_port_logic_delete_lookupid=0 int_radm_trgt1_dma_cpl_rlsd=0 
// cond3: trgt_lookupid_used=MAX   radm_grant_tlp_type=x radm_trgt1_dma_grant=x int_client_lookupid_rlsd=x int_port_logic_delete_lookupid=x int_radm_trgt1_dma_cpl_rlsd=x 

   int_trgt_lut_order_pkt_halt = 0;
   int_trgt_lut_order_pkt_halt = ((trgt_lookupid_used==(dyn_remote_max_tag_plus_1-(NVC_POP+DMA_ENABLE))) && (  (inc_lookupid_used-dec_lookupid_used)==(NVC_POP+DMA_ENABLE))         ) || 
                                 ((trgt_lookupid_used==(dyn_remote_max_tag_plus_1- NVC_POP            )) && ((((inc_lookupid_used-dec_lookupid_used)>= NVC_POP) && inc_greater_dec))) ||
                                 ( trgt_lookupid_used>=(dyn_remote_max_tag_plus_1));
end

// ### DMA Conditions ###
always @(*) begin
// For NVC_POP=1, DMA_ENABLE=1
// cond1: trgt_lookupid_used=MAX-3 radm_grant_tlp_type=1        radm_trgt1_dma_grant=1 int_client_lookupid_rlsd=0 int_port_logic_delete_lookupid=0 int_radm_trgt1_dma_cpl_rlsd=0
// cond2: trgt_lookupid_used=MAX-2 radm_grant_tlp_type=1 AND/OR radm_trgt1_dma_grant=1 int_client_lookupid_rlsd=0 int_port_logic_delete_lookupid=0 int_radm_trgt1_dma_cpl_rlsd=0 
// cond3: trgt_lookupid_used=MAX-1 radm_grant_tlp_type=x        radm_trgt1_dma_grant=x int_client_lookupid_rlsd=x int_port_logic_delete_lookupid=x int_radm_trgt1_dma_cpl_rlsd=x 

   int_trgt_lut_dma_pkt_halt = 0;

   if(dyn_target_cpl_lut_enable) begin
      int_trgt_lut_dma_pkt_halt = ((trgt_lookupid_used==(dyn_remote_max_tag_plus_1-(NVC_POP+DMA_ENABLE+1))) && (  (inc_lookupid_used-dec_lookupid_used)==(NVC_POP+DMA_ENABLE))) && !disable_cond  || 
                                  ((trgt_lookupid_used==(dyn_remote_max_tag_plus_1-(NVC_POP+DMA_ENABLE  ))) && ((((inc_lookupid_used-dec_lookupid_used)>= NVC_POP) && inc_greater_dec)))    ||
                                  ( trgt_lookupid_used>=(dyn_remote_max_tag_plus_1- NVC_POP));
   end else begin
      int_trgt_lut_dma_pkt_halt = ((trgt_lookupid_used==(dyn_remote_max_tag_plus_1- DMA_ENABLE           )) && ((((inc_lookupid_used-dec_lookupid_used)>= DMA_ENABLE) && inc_greater_dec))) ||
                                  ( trgt_lookupid_used>=(dyn_remote_max_tag_plus_1));
   end
end

// ### Protection: Mux to disable the outputs ###
assign trgt_lut_order_pkt_halt = ((TARGET_CPL_LUT_ENABLE != 0) && dyn_target_cpl_lut_enable) ? int_trgt_lut_order_pkt_halt : 1'b0;
assign trgt_lut_dma_pkt_halt   = ((DMA_ENABLE != 0)            && dyn_dma_enable)            ? int_trgt_lut_dma_pkt_halt   : 1'b0;



endmodule // target_np_tracker_ms
