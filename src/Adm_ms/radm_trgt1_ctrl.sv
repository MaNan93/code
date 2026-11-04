//
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
// ---    $Revision: #9 $
// ---    $Id: //dwh/pcie_iip/main/fairbanks/design/Adm_ms/radm_trgt1_ctrl.sv#9 $
// -------------------------------------------------------------------------
// Description:
// This module interface with Application for TRGT1 interface signals.
// This module gets input from demux control logic. The TLP's are routed to TRGT1 from filter and DEMUX 
// logic. Filter logic decides destination of the TLP depends on address decoding, error conditions, 
// default target types etc. 
// This module only receives TRGT1 routed TLP.
// Inside this module following functionality has taken care - 
// 1. Manage TRGT1 halt scenario per FC per TRGT1 interface 
// 2. The TLP output from TRGT1 interface to Application. Application logic is external block if we 
// use controller for native controller application. If controller use with Synopsys AXI bridge then 
// all TRGT1 signals are connected internally to Synopsys Bridge block. 
// 3. Halt Mechanism: This module handles to latch the current data if Halt is asserted from Application 
// After asserting Halt from Application, this module accepts one more data in the pipeline as this block halts 
// sub-sequent pipelines in the sub-module after 1 clock cycle after assertion of Halt from Application
//---------------------------------------------------------------------------------------    

`include "include/DWC_pcie_ctl_all_defs.svh"
`include "DWC_pcie_ctl_pkg.svh"
`include "Adm_ms/radm_ms_pkg.svh"
`include "products/DWC_pcie_core_pkg.svh"
`include "products/pcie_pkg.svh"

module radm_trgt1_ctrl

  ///////////////////////////////////////// 
  //import radm_ms_pkg starts
  import radm_ms_pkg::ATU_IN_MIN1;
  import radm_ms_pkg::FLT_HDR_WIDTH;
  import radm_ms_pkg::FLT_HDR_PROT_WIDTH;
  import radm_ms_pkg::TRGT1_GEN_PROT_WD;
  import radm_ms_pkg::FLT_Q_ADDR_WIDTH;
  import radm_ms_pkg::INT_DWIDTH;
  import radm_ms_pkg::INT_HWIDTH;
  import radm_ms_pkg::flt_hdr_s ;
  import radm_ms_pkg::conv_hdr_to_p_type;
  import radm_ms_pkg::conv_hdr_to_np_type;
  import radm_ms_pkg::conv_hdr_to_cpl_type;
  import radm_ms_pkg::rtrgt1_tlp_out_s;
  import DWC_pcie_ctl_pkg::TP;
  //import radm_ms_pkg ends
  //////////////////////////////////////////
  
  //////////////////////////////////////////
  //import DWC_pcie_ctl_pkg starts
  import DWC_pcie_ctl_pkg::NW; 
  import DWC_pcie_ctl_pkg::NP_REQ_TX_TYPE_WD;
   import DWC_pcie_ctl_pkg::ras_dp_err_inj_t;
  import DWC_pcie_ctl_pkg::ras_dp_err_log_t;
  //import DWC_pcie_ctl_pkg ends
  /////////////////////////////////////
  
  /////////////////////////////////////
  //import DWC_pcie_core_pkg starts 
  import DWC_pcie_core_pkg::DATA_PAR_WD;
  import DWC_pcie_core_pkg::DW;
`ifndef SYNTHESIS
`endif
  //import DWC_pcie_core_pkg ends
  ////////////////////////////////////
  import pcie_pkg::*;
  #(
   parameter  FLT_H_WIDTH             = 0,   // Filter Header width
   parameter  FLT_H_PROT_WIDTH        = 0,   // Filter Header Prot width
   parameter  TRGT1_OUT_WD            = 0,   // TRGT1 output width (header + data)
   parameter  TRGT1_HDR_WD            = 0,   // TRGT1 reduced header width
   parameter  TRGT1_RHDR_WD           = 0,   // TRGT1 reduced header width
   parameter  TRGT1_H_PROT_WD         = 0,   // TRGT1 header prot width 
   // If both are zero then considered for CPL type
   parameter  H_IS_P_TYPE             = 0,   // P Type Header
   parameter  H_IS_NP_TYPE            = 0,   // NP Type Header
   parameter RAS_DP_PROT_CHK_ID_BASE  = 0,
   localparam INT_HDR_WIDTH           =   INT_HWIDTH, 
   localparam FLT_H_PROT_WD           = 0 + FLT_H_PROT_WIDTH ,
   localparam CAN_STALL               =   1,
   localparam PIPE_DELAY              =   1
  ) 
                        (


    // Input/Output Declaration
    // Clock and Reset
    // -------------------------------------------------------------------------------------
    input                                       core_clk,               // PCIE core clock
    input                                       radm_clk_ug,            // PCIE core clock ungated
    input                                       core_rst_n,             // PCIE active low asynchronous reset
    input                                       flit_mode,              // PCIE active low asynchronous reset
    // -------------------------------------------------------------------------------------
    // Input/Output Declaration 
    // -------------------------------------------------------------------------------------

    input  logic [INT_DWIDTH -1:0]                                                 radm_trgt1_data_dmux, // This input is from DEMUX control block

    input  logic [INT_HDR_WIDTH -1:0]                                              radm_trgt1_hdr_dmux, // This HDR input is from DEMUX control block
    input  logic                                                                   log_halt,
    input                                                                          trgt1_radm_intf_halt,  // INput halt as per FC type
    //---------------------------------------------------------------------------------
    //Following signals are TRGT1 interface signals. Per signal description is added in the 
    //TOP module i.e. DWC_pcie_ctl.sv
    //---------------------------------------------------------------------------------
    output logic [NP_REQ_TX_TYPE_WD-1:0]        trgt1_xadm_np_req_type,
    output logic                                stall_trgt1,
    output [TRGT1_OUT_WD-1:0]        radm_trgt1_out 
    ,
    output ras_dp_err_log_t                     ras_dp_err_log,
    input  ras_dp_err_inj_t                     ras_dp_err_inj  
  );
  localparam PROT_RANGE      = `CX_RAS_PROT_RANGE;
  localparam PROT_TYPE       = `CX_RAS_PROT_TYPE;
  localparam PARITY_MODE     = `CX_RAS_PARITY_MODE;
  localparam PROT_CORRECT_EN = PROT_TYPE? 0 : `CX_RAS_CORRECTION_EN;
  // ------------------------------------ Signal declaration ------------------------------------

  logic [INT_HDR_WIDTH-4:0]                   radm_trgt1_hdr_dmux_in; // 3 bits is to remove cpl_status_trgt0 signal width from the vector. From demux_ctrl common width declaration is used 
  logic                                         hv_in_int;
  logic [INT_HDR_WIDTH-4:0]                  radm_trgt1_hdr_r; // 3 bits is to remove cpl_status_trgt0 signal width from the vector. From demux_ctrl common width declaration is used
  logic [INT_DWIDTH -1:0]                       radm_trgt1_data_r;
  logic                                         dmux_last_tlp_had_dllp_err;
  logic                                         flt_q_dllp_abort;
  logic                                         flt_q_tlp_abort;
  logic                                         flt_q_tlp_poisoned;
  logic                                         flt_q_tlp_fm_nullified_unused;
  logic                                         flt_q_parerr;
  logic                                         flt_q_ecrc_err;
  logic                                         flt_q_eot;
  logic [NW-1:0]                                flt_q_dwen;
  logic [DW+DATA_PAR_WD-1:0]                    flt_q_data;
  logic                                         flt_q_dv;
  logic [7:0]                                   radm_trgt1_msgcode_int;
  logic [`FLT_Q_ADDR_WIDTH-1:0]                 radm_trgt1_addr_int_r;
  logic [`FLT_Q_ADDR_WIDTH-1:0]                 radm_trgt1_addr_int_ras_r;
  
  
        
  logic [ `FLT_Q_LSTDW_BE_WIDTH -1  : 0]        flt_q_last_be_in; 

  logic [ `FLT_Q_EP_WIDTH -1  : 0]              flt_q_poisoned_in; 
  
  logic [ `FLT_Q_FRSTDW_BE_WIDTH -1 :0  ]       flt_q_first_be_in;  
  logic                                         trgt1_radm_intf_halt_w_log ;
  logic [FLT_HDR_WIDTH+FLT_HDR_PROT_WIDTH-1:0]  flt_q_header;
  logic                                         flt_q_hv;
  flt_hdr_s                                     hdr_in,hdr_in_int,radm_trgt1_hdr_in;  // calling header structure
  
   logic                                        radm_trgt1_dv ;
   logic                                        radm_trgt1_hv ;
   logic                                        radm_trgt1_eot;
   logic [ATU_IN_MIN1-1:0]                      r_radm_trgt1_atu_sloc_match;
   logic [ATU_IN_MIN1-1:0]                      s_radm_trgt1_atu_sloc_match;
   logic [ATU_IN_MIN1-1:0]                      r_radm_trgt1_atu_cbuf_err;
   logic [ATU_IN_MIN1-1:0]                      s_radm_trgt1_atu_cbuf_err;
    logic   [TRGT1_H_PROT_WD-1:0]  radm_trgt1_hdr_prot;
    //logic   [TRGT1_GEN_PROT_WD-1:0]  radm_trgt1_hdr_prot_updated;
  
    logic  stall_hv_in;
    logic  stall_dv_in;
    logic  stallout_hdr;
    logic  stallout_data;
  // ---------------------------------- Signal declaration ends ----------------------------------


  assign  trgt1_radm_intf_halt_w_log = trgt1_radm_intf_halt ;

  // DPP checker for header input
  //logic [FLT_H_WIDTH+FLT_H_PROT_WD-1:0]     chk_flt_q_header;
  logic [FLT_H_WIDTH+FLT_H_PROT_WD-1:0]     chk_flt_q_header_in,radm_trgt1_hdr_vec_in,chk_flt_q_header_in_ras;
  logic [TRGT1_HDR_WD-1:0]                    radm_trgt1_hdr_vec;
  generate if ( H_IS_P_TYPE ) begin : str_bypass_p_type_gen
    assign radm_trgt1_hdr_dmux_in = {radm_trgt1_hdr_in,hv_in_int};
    assign chk_flt_q_header_in    = conv_hdr_to_p_type(flt_q_header,radm_trgt1_addr_int_r,hdr_in.flt_q_poisoned);
    assign chk_flt_q_header_in_ras = conv_hdr_to_p_type(hdr_in_int,hdr_in_int.flt_q_addr,hdr_in_int.flt_q_poisoned);
    assign radm_trgt1_hdr_vec_in  = conv_hdr_to_p_type(flt_q_header,hdr_in.flt_q_addr,flt_q_poisoned_in);
    assign radm_trgt1_hdr_vec  =  radm_trgt1_hdr_vec_in[TRGT1_HDR_WD-1:0];
    assign radm_trgt1_out      = { flt_q_data, radm_trgt1_dv, radm_trgt1_eot, flt_q_dwen, 
                                   flt_q_tlp_abort, flt_q_dllp_abort, flt_q_ecrc_err, 
                                   flt_q_poisoned_in,
 radm_trgt1_hdr_prot, 
                                   r_radm_trgt1_atu_sloc_match,
                                   r_radm_trgt1_atu_cbuf_err,
 hdr_in.flt_q_prfx, radm_trgt1_hv,  
                                    radm_trgt1_msgcode_int, 
                                    chk_flt_q_header_in[TRGT1_HDR_WD-1:0]
                                    ,log_halt
                                 };
  end else if ( H_IS_NP_TYPE ) begin : str_bypass_np_type_gen
    assign radm_trgt1_hdr_dmux_in = {radm_trgt1_hdr_in,hv_in_int};
    assign chk_flt_q_header_in = conv_hdr_to_np_type(flt_q_header,radm_trgt1_addr_int_r,hdr_in.flt_q_poisoned);
    assign radm_trgt1_hdr_vec_in  = conv_hdr_to_np_type(flt_q_header,hdr_in.flt_q_addr,flt_q_poisoned_in);
    assign chk_flt_q_header_in_ras = conv_hdr_to_np_type(hdr_in_int,hdr_in_int.flt_q_addr,hdr_in_int.flt_q_poisoned);
    assign radm_trgt1_hdr_vec  =  radm_trgt1_hdr_vec_in[TRGT1_HDR_WD-1:0];
    assign radm_trgt1_out      = { flt_q_data,radm_trgt1_dv ,radm_trgt1_eot , flt_q_dwen, 
                                   flt_q_tlp_abort, flt_q_dllp_abort, flt_q_ecrc_err, 
                                   flt_q_poisoned_in,
 radm_trgt1_hdr_prot,  
                                   r_radm_trgt1_atu_sloc_match,
                                   r_radm_trgt1_atu_cbuf_err,
 hdr_in.flt_q_prfx, radm_trgt1_hv, 
                                   radm_trgt1_msgcode_int,
                                   chk_flt_q_header_in[TRGT1_HDR_WD-1:0] 
                                   ,log_halt
                                 };    
  end else begin : str_bypass_cpl_type_gen
    assign radm_trgt1_hdr_dmux_in = {radm_trgt1_hdr_dmux[INT_HDR_WIDTH-1:4],radm_trgt1_hdr_dmux[0]};
    assign chk_flt_q_header_in = conv_hdr_to_cpl_type(flt_q_header,hdr_in.flt_q_poisoned);
    assign radm_trgt1_hdr_vec_in  = conv_hdr_to_cpl_type(flt_q_header,flt_q_poisoned_in);
    assign chk_flt_q_header_in_ras = conv_hdr_to_cpl_type(hdr_in_int,hdr_in_int.flt_q_poisoned);
    assign radm_trgt1_hdr_vec  = radm_trgt1_hdr_vec_in[TRGT1_HDR_WD-1:0];
    assign radm_trgt1_out      = { flt_q_data, radm_trgt1_dv,radm_trgt1_eot , flt_q_dwen, 
                                   flt_q_tlp_abort, flt_q_dllp_abort, flt_q_ecrc_err, 
                                   flt_q_poisoned_in,
 radm_trgt1_hdr_prot, 
 hdr_in.flt_q_prfx,
                                   radm_trgt1_hv, chk_flt_q_header_in[TRGT1_HDR_WD-1:0]
                                   ,log_halt
                                 };    
  end
  endgenerate
             ras_dp_pipe
              #(
                .PIPELINE_TYPE           (0),                       
                .RESETVAL                (0),                       
                .N_STAGES                (0),                       
                .CAN_STALL               (0),                       
                .RESET_STALL             (0),                       
                .BUS_PROTECT_GEN_EN      (0),                       
                .BUS_PROTECT_CHK_EN      (1),                       
                .PROT_TYPE               (PROT_TYPE),               
                .PROT_RANGE              (PROT_RANGE),    
                .PROT_WD                 (FLT_H_PROT_WIDTH),
                .PARITY_MODE             (PARITY_MODE),             
                .PROT_CORRECT_EN         (PROT_CORRECT_EN),         
                .TOTAL_WIDTH             (FLT_H_WIDTH),                      // Total width  
                .EXCLUDE_PROT_WIDTH      (0),
                .RAS_DP_PROT_CHK_ID_BASE (RAS_DP_PROT_CHK_ID_BASE),
                .PIPE_RAS_DP_ERR_LOG     (1)
            ) u_ras_dp_pipe_full_hdr_chk (
                .clk      (core_clk           ),
                .rst_n    (core_rst_n         ),
                .en       (1'b1               ),
                .bypass   (1'b0               ),
                .stall    (1'b0               ),
                .stallout (                   ),
                
                .valid_in (hv_in_int        ),
                .din      ({chk_flt_q_header_in_ras[FLT_H_WIDTH-1:2],2'b00}), // flt_q_destination value is passed as 0 because parity was calculated with value 0 only.           
                .din_prot (chk_flt_q_header_in_ras[FLT_H_WIDTH+FLT_H_PROT_WIDTH-1:FLT_H_WIDTH]),
                .halt_out (                   ),
                
                .valid_out(                   ),
                .dout     (                   ),
                .dout_prot(                   ),
                .halt_in  (1'b0               ),
                .ras_dp_err_inband_kbd_in(1'b0),
                .ras_dp_err_inband_kbd_out(   ),
                .ras_dp_err_log  (ras_dp_err_log )
                ,
                .ras_dp_err_inj  (ras_dp_err_inj)
                );

  assign  hdr_in = flt_q_header; // Assined received header to structure

 
            ras_dp_pipe
             #(
                .PIPELINE_TYPE           (0),                  // No pipeline only checker instance
                .RESETVAL                (0),                  
                .N_STAGES                (0),                  
                .CAN_STALL               (0),                  
                .RESET_STALL             (0),                  
                .BUS_PROTECT_GEN_EN      (1),                   
                .BUS_PROTECT_CHK_EN      (0),                  
                .PROT_TYPE               (PROT_TYPE),          // cc
                .PROT_RANGE              (PROT_RANGE),         // cc
                .PROT_WD                 (TRGT1_H_PROT_WD),
                .PARITY_MODE             (PARITY_MODE),        // cc
                .PROT_CORRECT_EN         (PROT_CORRECT_EN),    // cc
                .TOTAL_WIDTH             (TRGT1_HDR_WD-3 -1 ) ,             
                .EXCLUDE_PROT_WIDTH      (0),
                .RAS_DP_PROT_CHK_ID_BASE (0)
            ) u_ras_dp_pipe_gen_trgt1_hdr
            (
                .clk      (core_clk           ),
                .rst_n    (core_rst_n         ),
                .en       (1'b1               ),
                .bypass   (1'b0               ),
                .stall    (1'b0               ),
                .stallout (                   ),
                
                .valid_in (1'b1               ),
                .din      (radm_trgt1_hdr_vec[TRGT1_HDR_WD-2 -1 :2] ),
                .din_prot ('0                  ),
                .halt_out (                   ),
                
                .valid_out(                   ),
                .dout     (                   ),
                .dout_prot(radm_trgt1_hdr_prot   ),
                .halt_in  (1'b0               ),
                .ras_dp_err_inband_kbd_in(1'b0),
                .ras_dp_err_inband_kbd_out(   ),
                .ras_dp_err_log  ()
                ,
                .ras_dp_err_inj  ('0)
                );
    // always_comb
    // begin
    //   radm_trgt1_hdr_prot_updated = 'd0;
    //   radm_trgt1_hdr_prot_updated = {{(TRGT1_GEN_PROT_WD-TRGT1_H_PROT_WD){1'b0}},radm_trgt1_hdr_prot};
    // end     

  
  // Following sequencetial block is to - 
  // 1. Handle pipeliene sceanrio during HALT assertion from TRGT1 interface 
  // 2. Send registered output for Trashed/ TRGT0 routed Packet order number and valid signal
  // ---------------------------------------------------------------------------------------------


  // Following assignments are to seperate out signals from received header  and data from filter and send it 
  // on TRGT1 interface.  
  
  assign {
         dmux_last_tlp_had_dllp_err,
         flt_q_tlp_poisoned,
         flt_q_tlp_abort,flt_q_parerr,flt_q_ecrc_err,flt_q_dllp_abort,flt_q_eot,flt_q_dwen,flt_q_data,flt_q_dv} = radm_trgt1_data_r;

  assign {hdr_in_int,hv_in_int}  ={radm_trgt1_hdr_dmux[INT_HDR_WIDTH-1:4],radm_trgt1_hdr_dmux[0]};
  always_comb begin : TPH_ADDR_ALIGN
    radm_trgt1_hdr_in     =  hdr_in_int;

     radm_trgt1_hdr_in.flt_q_addr = hdr_in_int.flt_q_th ? {hdr_in_int.flt_q_addr[`FLT_Q_ADDR_WIDTH-1:2],2'b00} : (flit_mode && (|hdr_in_int.flt_q_ats)) ?
     {hdr_in_int.flt_q_addr[`FLT_Q_ADDR_WIDTH-1:2],2'b00} : (hdr_in_int.flt_q_ats == 2'b01) ? {hdr_in_int.flt_q_addr[ `FLT_Q_ADDR_WIDTH-1:1],1'b0} : hdr_in_int.flt_q_addr[ `FLT_Q_ADDR_WIDTH-1:0];

end



  assign {flt_q_header,flt_q_hv} = radm_trgt1_hdr_r;

  assign  radm_trgt1_dv               = flt_q_dv  ;
  assign  radm_trgt1_hv               = flt_q_hv  ;
  assign  radm_trgt1_eot              = flt_q_eot ;

     
  assign  flt_q_last_be_in            = hdr_in.flt_q_last_be; 
  assign  flt_q_poisoned_in           = (hdr_in.flt_q_poisoned | flt_q_tlp_poisoned ) && radm_trgt1_eot;
  assign  flt_q_first_be_in           = hdr_in.flt_q_first_be;  



  assign radm_trgt1_msgcode_int = {flt_q_last_be_in,flt_q_first_be_in};

  assign trgt1_xadm_np_req_type = hdr_in.lut_np_req_type;
  assign stall_hv_in =  trgt1_radm_intf_halt_w_log; 



    flt_hdr_s                           flt_q_hdr_atu;
    logic                               flt_q_hv_atu;
    logic                               radm_atu_uppr_bytes_valid;
    logic [ATU_IN_MIN1-1:0]             radm_atu_sloc_match;
    logic [ATU_IN_MIN1-1:0]             radm_atu_cbuf_err;
    logic [ATU_IN_MIN1-1:0]             conv_bin_to_onehot;

  assign {flt_q_hdr_atu,flt_q_hv_atu} = radm_trgt1_hdr_dmux_in;


// Following logic is to generate SLOC_match and cbuf_err in SLOC mode. 
// These signals needs to be send as one hot encoding i.e. single bit per region 
// Sending registered output to avoid timing issues

  always_comb begin: ATU_ASSIGNMENTS
    s_radm_trgt1_atu_sloc_match             = 0; 
    s_radm_trgt1_atu_cbuf_err               = 0; 

      conv_bin_to_onehot   = 'h1;
      s_radm_trgt1_atu_sloc_match  = (flt_q_hv_atu & flt_q_hdr_atu.radm_atu_sloc_match) ? (conv_bin_to_onehot << (flt_q_hdr_atu.radm_atu_sloc_region)) : 0;
      s_radm_trgt1_atu_cbuf_err    = flt_q_hdr_atu.radm_atu_cbuf_err   ? s_radm_trgt1_atu_sloc_match : 0;
  end


  delay_n_w_stalling
  
  #(  .N          (PIPE_DELAY), 
      .WD         (ATU_IN_MIN1),
      .CAN_STALL  (CAN_STALL),
      .RESETVAL   (0)
  ) u_sloc_trgt1_delay
  (
      .clk        (core_clk),
      .rst_n      (core_rst_n),
      .clear      (1'b0),
      .stall      (stall_hv_in),
      .stallout   (   ),
      .din        (s_radm_trgt1_atu_sloc_match),
      .dout       (r_radm_trgt1_atu_sloc_match)
    );


  delay_n_w_stalling
  
  #(  .N          (PIPE_DELAY), 
      .WD         (ATU_IN_MIN1),
      .CAN_STALL  (CAN_STALL),
      .RESETVAL   (0)
  ) u_cbuf_trgt1_delay
  (
      .clk        (core_clk),
      .rst_n      (core_rst_n),
      .clear      (1'b0),
      .stall      (stall_hv_in),
      .stallout   (   ),
      .din        (s_radm_trgt1_atu_cbuf_err),
      .dout       (r_radm_trgt1_atu_cbuf_err)
    );






  delay_n_w_stalling
  
  #(  .N          (PIPE_DELAY), 
      .WD         (INT_HDR_WIDTH-3),
      .CAN_STALL  (CAN_STALL),
      .RESETVAL   (0)
  ) u_hdr_trgt1_delay
  (
      .clk        (core_clk),
      .rst_n      (core_rst_n),
      .clear      (1'b0),
      .stall      (stall_hv_in),
      .stallout   (stallout_hdr   ),
      .din        (radm_trgt1_hdr_dmux_in),
      .dout       (radm_trgt1_hdr_r)
    );


  delay_n_w_stalling
  
  #(  .N          (PIPE_DELAY), 
      .WD         (`FLT_Q_ADDR_WIDTH),
      .CAN_STALL  (CAN_STALL),
      .RESETVAL   (0)
  ) u_hdr_trgt1_addr_delay
  (
      .clk        (core_clk),
      .rst_n      (core_rst_n),
      .clear      (1'b0),
      .stall      (stall_hv_in),
      .stallout   (),
      .din        (radm_trgt1_hdr_in.flt_q_addr),
      .dout       (radm_trgt1_addr_int_r)
    );

  delay_n_w_stalling
  
  #(  .N          (PIPE_DELAY), 
      .WD         (`FLT_Q_ADDR_WIDTH),
      .CAN_STALL  (CAN_STALL),
      .RESETVAL   (0)
  ) u_hdr_trgt1_addr_delay_ras
  (
      .clk        (core_clk),
      .rst_n      (core_rst_n),
      .clear      (1'b0),
      .stall      (stall_hv_in),
      .stallout   (),
      .din        (hdr_in_int.flt_q_addr),
      .dout       (radm_trgt1_addr_int_ras_r)
    );

assign stall_dv_in =  trgt1_radm_intf_halt_w_log; 

delay_n_w_stalling

  #(  .N          (PIPE_DELAY), 
      .WD         (INT_DWIDTH),
      .CAN_STALL  (CAN_STALL),
      .RESETVAL   (0)
  ) u_data_trgt_delay (
    .clk        (core_clk),
    .rst_n      (core_rst_n),
    .clear      (1'b0),
    .stall      (stall_dv_in),
    .stallout   (stallout_data),
    .din        (radm_trgt1_data_dmux),
    .dout       (radm_trgt1_data_r)
    );

  assign  stall_trgt1 = stallout_data | stallout_hdr;

`ifndef SYNTHESIS
// --------------------------------------------------------------------------------------
// Simulation Only Info
// --------------------------------------------------------------------------------------
//VCS coverage off
//VCS coverage on
`endif // SYNTHESIS

// --------------------------------------------------------------------------------------
// Functions
// --------------------------------------------------------------------------------------

endmodule
