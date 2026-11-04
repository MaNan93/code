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
// ---    $Revision: #8 $
// ---    $Id: //dwh/pcie_iip/main/fairbanks/design/Adm_ms/radm_trgt0_ctrl.sv#8 $
// -------------------------------------------------------------------------
// Description:
// This module takes input from demux control logic. The TLP's are routed to TRGT0 from filter and DEMUX 
// logic. Filter logic decides destination of the TLP depends on address decoding, error conditions, 
// default target types etc. 
// This module only received TRGT0 routed TLP.
// Inside this module following functioanlity has taken care - 
// 1. Manage TRGT0 halt scenario
// 2. This modules get multiple TRGT0 routed tlp inputs from different VC's of P and NP TLP's 
// 3. The packet output from TRGT0 interface to CDM/LBC logic is only one TLP at a time. i.e. LBC accepts
//    only one TLP at a time 
// 4. This module takes care of multi to 1 output to LBC interface 
// 5. If multiple inputs are receiving, this modules sends one output from received multi inputs 
// With current implementation we have considered only two inputs from VC0 and always posted TLP 
// addressed with priority 
// 6. When one input is serving other requesters from VC's will be halted and served after completion 
// of current TRGT0 TLP
//---------------------------------------------------------------------------------------    

`include "include/DWC_pcie_ctl_all_defs.svh"
`include "DWC_pcie_ctl_pkg.svh"
`include "Adm_ms/radm_ms_pkg.svh"
`include "products/DWC_pcie_core_pkg.svh"
`include "products/pcie_pkg.svh"



module radm_trgt0_ctrl

  ///////////////////////////////////////// 
  //import radm_ms_pkg starts
  import radm_ms_pkg::PKT_ORD_WD;
  import radm_ms_pkg::FLT_HDR_WIDTH;
  import radm_ms_pkg::FLT_HDR_PROT_WIDTH;
  import radm_ms_pkg::N_TRGT1_INTF;
  import radm_ms_pkg::TRGT_HDR_WD;
  import radm_ms_pkg::FLT_OUT_PROT_WD;
  import radm_ms_pkg::FLT_Q_ADDR_WIDTH;
  import radm_ms_pkg::NO_OF_TRGT0_INTF;
  import radm_ms_pkg::INT_DWIDTH;
  import radm_ms_pkg::INT_HWIDTH;
  import radm_ms_pkg::INT_HDW;
  import radm_ms_pkg::flt_hdr_s ;
  import radm_ms_pkg::trgt0_hdr_s ;
  import radm_ms_pkg::FLT_P_HDR_WIDTH ;
  import radm_ms_pkg::FLT_NP_HDR_WIDTH ;
  import radm_ms_pkg::FLT_P_HDR_PROT_WIDTH;
  import radm_ms_pkg::FLT_NP_HDR_PROT_WIDTH;
  import radm_ms_pkg::conv_hdr_to_p_type;
  import radm_ms_pkg::conv_hdr_to_np_type;
  import pcie_pkg::mode_e;
  import pcie_pkg::tlp_hdr_pkt_s;
  import pcie_pkg::f_tlp_is_fm_np_rsvd;

  //import radm_ms_pkg ends
  //////////////////////////////////////////
  
  //////////////////////////////////////////
  //import DWC_pcie_ctl_pkg starts
  import DWC_pcie_ctl_pkg::TP;
  import DWC_pcie_ctl_pkg::NW;
   import DWC_pcie_ctl_pkg::ras_dp_err_inj_t;
  import DWC_pcie_ctl_pkg::ras_dp_err_log_t;
  //import DWC_pcie_ctl_pkg ends
  /////////////////////////////////////
  
  /////////////////////////////////////
  //import DWC_pcie_core_pkg starts 
  import DWC_pcie_core_pkg::DATA_PAR_WD;
  import DWC_pcie_core_pkg::DW;
  //import DWC_pcie_core_pkg ends
  ////////////////////////////////////
  
  #(
  parameter RAS_DP_PROT_CHK_ID_BASE  = 0,
  localparam REQ_EOT = NW+DW+DATA_PAR_WD +1+INT_HWIDTH,  // Bit location of EOT encoding : TO DO : dd these param into pkg file
    localparam D_UPPR_BITS = 4 
                             + 1
  ) 
  
                        (
    // Clock and Reset
    // -------------------------------------------------------------------------------------
    input                                         core_clk,           // Clock input 
    input                                         core_rst_n,         // Reset
    // -------------------------------------------------------------------------------------
    // Input/Output declaration
    // -------------------------------------------------------------------------------------
    input   [3:0]                                 device_type,                        // "static"
    input                                         pm_l1_aspm_entr,
    input                                         flit_mode, 
    input [(NO_OF_TRGT0_INTF-1):0][INT_HDW-1:0]   dmux_trgt0_req, // TRGT0 request from DEMUX block.  
    input logic [N_TRGT1_INTF-1:0]                dmux_trgt0_p_fifo_pipe_empty,  
    input                                         trgt0_radm_halt, // HALT input from CDM/LBC module 
    output logic  [DW+DATA_PAR_WD-1:0]            radm_trgt0_data, // Data out to CDM/LBC 
    output logic                                  radm_trgt0_abort,
    output logic                                  radm_trgt0_dv,
    output logic  [NW-1:0]                        radm_trgt0_dwen,
    output logic                                  radm_trgt0_ecrc_err,
    output logic                                  radm_trgt0_eot,  // This signal indicates End Of Current TLP   
    //output logic [INT_HWIDTH-2:0]                radm_trgt0_hdr,   
    output logic [TRGT_HDR_WD-1:0]                radm_trgt0_hdr,   
    output logic                                  radm_trgt0_hv,   
    output logic                                  radm_trgt0_np_rsvd,   
    output logic [N_TRGT1_INTF-1:0]               trgt0_radm_halt_int_p, // Halt asserted for posted channel as per input HALT received from CDM/LBC 
    output logic [N_TRGT1_INTF-1:0]               trgt0_radm_halt_int_np, // Halt asserted for Non-posted channel as per input HALT received from CDM/LBC
    // Clock Gating Control Info
    output logic                                  radm_trgt0_p,
    output logic                                  radm_trgt0_np
  ,
  output ras_dp_err_log_t [NO_OF_TRGT0_INTF:0]    ras_dp_err_log
  ,
  input  ras_dp_err_inj_t                         ras_dp_err_inj  
  );
  localparam PROT_RANGE      = `CX_RAS_PROT_RANGE;
  localparam PROT_TYPE       = `CX_RAS_PROT_TYPE;
  localparam PARITY_MODE     = `CX_RAS_PARITY_MODE;
  localparam PROT_CORRECT_EN = PROT_TYPE? 0 : `CX_RAS_CORRECTION_EN;
  flt_hdr_s                                     trgt0_hdr_in; 
  trgt0_hdr_s                                   trgt0_hdr; 
  tlp_hdr_pkt_s                                 tlp_hdr_pkt;
  logic                                         trgt0_fmt2;
  logic                                         trgt0_fm_np_rsvd;
  // Internal WIRE declaration 
  flt_hdr_s [(NO_OF_TRGT0_INTF-1):0]              dmux_trgt0_req_hdr;
  logic [(NO_OF_TRGT0_INTF-1) :0]                 trgt0_radm_halt_c; 
  logic [INT_DWIDTH-1:0]                          radm_trgt0_data_c;
  logic [INT_HWIDTH-1:0]                          radm_trgt0_hdr_c;
  logic [NO_OF_TRGT0_INTF-1:0]                    req_out;
  logic [NO_OF_TRGT0_INTF-1:0]                    trgt0_req_vld,trgt0_req_vld_r,dmux_trgt0_req_eot,dmux_trgt0_req_hv;
  logic [NO_OF_TRGT0_INTF-1:0][PKT_ORD_WD-1:0]    dmux_trgt0_req_pkt_num;

  //logic [FLT_HDR_WIDTH+FLT_OUT_PROT_WD-1:0]       radm_trgt0_hdr_in;
  logic [FLT_HDR_WIDTH+FLT_HDR_PROT_WIDTH-1:0]  radm_trgt0_hdr_in;


  //`ifdef CX_IS_SW
  //`else
  // `ifdef ATS_RX_ENABLE                    
  //  `endif  // ATS_RX_ENABLE            
  //`endif  // CX_IS_SW           
  //`ifdef CX_IS_SW 
  //`else 
  //  `ifdef CX_TPH_ENABLE  
  logic                                        flt_q_th_in; 
  //  `endif // CX_TPH_ENABLE 
  //`endif  // CX_IS_SW 
  


  logic [ `FLT_Q_TYPE_WIDTH  -1 : 0 ]           flt_q_type_in;
  logic [1:0]                                   flt_q_fmt_in; 

  logic [2:0]                                   s_cpl_status;
  logic                                         s_cpl_status_su;
  logic                                         s_radm_trgt0_hv, ss_radm_trgt0_hv, s_radm_trgt0_dv, ss_radm_trgt0_dv, s_radm_trgt0_eot, ss_radm_trgt0_eot;
  logic                                         r_radm_trgt0_hv, r_radm_trgt0_dv, r_radm_trgt0_eot;
  logic [TRGT_HDR_WD+1:0]                       s_radm_trgt0_hdr, ss_radm_trgt0_hdr, r_radm_trgt0_hdr,s_radm_trgt0_hdr_in;   
  logic                                         s_radm_trgt0_ecrc_err, ss_radm_trgt0_ecrc_err, r_radm_trgt0_ecrc_err;
  logic                                         s_radm_trgt0_abort, ss_radm_trgt0_abort, r_radm_trgt0_abort;
  logic [NW-1:0]                                s_radm_trgt0_dwen, ss_radm_trgt0_dwen, r_radm_trgt0_dwen;
  logic [DW+DATA_PAR_WD-1:0]                    s_radm_trgt0_data, ss_radm_trgt0_data, r_radm_trgt0_data;
  logic                                         ss_radm_trgt0_p, r_radm_trgt0_p;
  logic   [6:0]                                 trgt0_fmt_type;
  logic                                         trgt0_tph_memwr;
  logic                                         p_vld_in,np_vld_in;

  logic                                         r_halt;
  logic                                         s_trgt0_radm_halt;

// --------------------------------------------------------------------------------------
// Design
// --------------------------------------------------------------------------------------

  // Halt NP requests when pm_l1_aspm_entr asserted.
  logic s_trgt0_radm_halt_int_np; 
  logic [(NO_OF_TRGT0_INTF-1):0][INT_HDW-1:0]   s_dmux_trgt0_req;

  assign trgt0_radm_halt_int_np = s_trgt0_radm_halt_int_np | pm_l1_aspm_entr;

  always_comb begin : proc_pm_aspm_mask_np_req
    s_dmux_trgt0_req = dmux_trgt0_req;
    for (int i=0; i<(NO_OF_TRGT0_INTF/2); i++) begin
      if (pm_l1_aspm_entr) begin
        s_dmux_trgt0_req[(2*i)+1] = '0;
      end
    end
  end

// --------------------------------------------------------------------------------------
// Extract header fields
// --------------------------------------------------------------------------------------
   assign flt_q_fmt_in    = trgt0_hdr_in.flt_q_fmt;
   assign flt_q_type_in   = trgt0_hdr_in.flt_q_type;
   assign flt_q_th_in     = trgt0_hdr_in.flt_q_th;
   assign trgt0_tph_memwr = flt_q_th_in && ((trgt0_fmt_type == `MWR32) ||
                                           (trgt0_fmt_type == `MWR64));
   assign trgt0_fmt_type  = {flt_q_fmt_in,flt_q_type_in};

  logic  device_is_ep;
  assign device_is_ep = device_type == 4'b0000;
logic [(NO_OF_TRGT0_INTF/2)-1:0] radm_trgt0_ctrl_dllp_abort_p;
logic [(NO_OF_TRGT0_INTF/2)-1:0] radm_trgt0_ctrl_eot_p;
logic [(NO_OF_TRGT0_INTF/2)-1:0] radm_trgt0_ctrl_hv_p;
logic [(NO_OF_TRGT0_INTF/2)-1:0] radm_trgt0_last_p_had_dllp_err;

localparam REQ_D_ERR = REQ_EOT + 4 ; //4 for eot, abort, ecrc, perr
localparam REQ_LAST_P_HAD_D_ERR = REQ_EOT + 5
                                    +1
                                  ; //5 for eot, abort, ecrc, perr, d_abort. 1 for fm_nullified. 1 for tlp_poisoned

always_comb
begin
    for (int j=0; j< NO_OF_TRGT0_INTF/2; j=j+1)
      begin
        radm_trgt0_last_p_had_dllp_err[j] =  dmux_trgt0_req [2*j] [REQ_LAST_P_HAD_D_ERR];
        radm_trgt0_ctrl_dllp_abort_p [j]  =  dmux_trgt0_req [2*j] [REQ_D_ERR];
        radm_trgt0_ctrl_eot_p  [j]        =  dmux_trgt0_req [2*j] [REQ_EOT];
        radm_trgt0_ctrl_hv_p [j]          =  dmux_trgt0_req [2*j] [0];
      end
end

      
  // Checker for HDR coming from filter
  logic  [(NO_OF_TRGT0_INTF/2)-1:0] [FLT_P_HDR_WIDTH+FLT_P_HDR_PROT_WIDTH-1:0]   chk_flt_p_header_in;
  logic  [(NO_OF_TRGT0_INTF/2)-1:0] [FLT_P_HDR_WIDTH+FLT_P_HDR_PROT_WIDTH-1:0]   chk_flt_p_header;
  logic  [(NO_OF_TRGT0_INTF/2)-1:0] [FLT_NP_HDR_WIDTH+FLT_NP_HDR_PROT_WIDTH-1:0] chk_flt_np_header_in;
  logic  [(NO_OF_TRGT0_INTF/2)-1:0] [FLT_NP_HDR_WIDTH+FLT_NP_HDR_PROT_WIDTH-1:0] chk_flt_np_header;
  logic [`FLT_Q_ADDR_WIDTH-1:0] func_addr_in;
  assign func_addr_in = trgt0_hdr_in.flt_q_addr;
  generate
  for (genvar i = 0; i < (NO_OF_TRGT0_INTF/2); i++) begin : gen_trgt0_flt_checker

    assign chk_flt_p_header_in[i]  = conv_hdr_to_p_type(s_dmux_trgt0_req[2*i][INT_HWIDTH-1:4],func_addr_in,trgt0_hdr_in.flt_q_poisoned);
    assign chk_flt_np_header_in[i] = conv_hdr_to_np_type(s_dmux_trgt0_req[(2*i)+1][INT_HWIDTH-1:4],func_addr_in,trgt0_hdr_in.flt_q_poisoned);

  // P Type request checker
    assign p_vld_in = s_dmux_trgt0_req[(2*i)][0] && !trgt0_radm_halt_int_p;
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
    .PROT_WD                 (FLT_P_HDR_PROT_WIDTH),
    .PARITY_MODE             (PARITY_MODE),             
    .PROT_CORRECT_EN         (PROT_CORRECT_EN),         
    .TOTAL_WIDTH             (FLT_P_HDR_WIDTH),                      // Total width  
    .EXCLUDE_PROT_WIDTH      (0),
    .RAS_DP_PROT_CHK_ID_BASE (RAS_DP_PROT_CHK_ID_BASE+(2*i)),
    .PIPE_RAS_DP_ERR_LOG     (1)
  ) u_ras_dp_pipe_flt_p_hdr_chk (
    .clk                      (core_clk           ),
    .rst_n                    (core_rst_n         ),
    .en                       (1'b1               ),
    .bypass                   (1'b0               ),
    .stall                    (1'b0               ),
    .stallout                 (                   ),
    
    .valid_in                 (p_vld_in),
    .din                      ({chk_flt_p_header_in[i][FLT_P_HDR_WIDTH-1:2],2'b00}), // flt_q_destination value is passed as 0 because parity was calculated with value 0 only. 
    .din_prot                 (chk_flt_p_header_in[i][FLT_P_HDR_WIDTH+FLT_P_HDR_PROT_WIDTH-1:FLT_P_HDR_WIDTH]),
    .halt_out                 (                   ),
    
    .valid_out                (                   ),
    .dout                     (                   ), //chk_flt_p_header[i][FLT_P_HDR_WIDTH-1:0]),
    .dout_prot                (                   ), //chk_flt_p_header[i][FLT_P_HDR_WIDTH+FLT_P_HDR_PROT_WIDTH-1:FLT_P_HDR_WIDTH]),
    .halt_in                  (1'b0               ),
    .ras_dp_err_inband_kbd_in (1'b0),
    .ras_dp_err_inband_kbd_out(   ),
    .ras_dp_err_log           (ras_dp_err_log[2*i])
    ,
    .ras_dp_err_inj           (ras_dp_err_inj)
  );
  // NP type request checker
    assign np_vld_in = s_dmux_trgt0_req[(2*i)+1][0] && !s_trgt0_radm_halt_int_np;
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
    .PROT_WD                 (FLT_NP_HDR_PROT_WIDTH),
    .PARITY_MODE             (PARITY_MODE),             
    .PROT_CORRECT_EN         (PROT_CORRECT_EN),         
    .TOTAL_WIDTH             (FLT_NP_HDR_WIDTH),                      // Total width  
    .EXCLUDE_PROT_WIDTH      (0),
    .RAS_DP_PROT_CHK_ID_BASE (RAS_DP_PROT_CHK_ID_BASE+(2*i)+1),
    .PIPE_RAS_DP_ERR_LOG     (1)
  ) u_ras_dp_pipe_flt_np_hdr_chk (
    .clk                      (core_clk           ),
    .rst_n                    (core_rst_n         ),
    .en                       (1'b1               ),
    .bypass                   (1'b0               ),
    .stall                    (1'b0               ),
    .stallout                 (                   ),
    
    .valid_in                 (np_vld_in),
    .din                      ({chk_flt_np_header_in[i][FLT_NP_HDR_WIDTH-1:2],2'b00}), // flt_q_destination value is passed as 0 because parity was calculated with value 0 only. 
    .din_prot                 (chk_flt_np_header_in[i][FLT_NP_HDR_WIDTH+FLT_NP_HDR_PROT_WIDTH-1:FLT_NP_HDR_WIDTH]),
    .halt_out                 (                   ),
    
    .valid_out                (                   ),
    .dout                     (                   ), //chk_flt_np_header[i][FLT_NP_HDR_WIDTH-1:0]),
    .dout_prot                (                   ), //chk_flt_np_header[i][FLT_NP_HDR_WIDTH+FLT_NP_HDR_PROT_WIDTH-1:FLT_NP_HDR_WIDTH]),
    .halt_in                  (1'b0               ),
    .ras_dp_err_inband_kbd_in (1'b0),
    .ras_dp_err_inband_kbd_out(   ),
    .ras_dp_err_log           (ras_dp_err_log[(2*i)+1])
    ,
    .ras_dp_err_inj           (ras_dp_err_inj)
  );
end
endgenerate

always_comb begin: CPL_status
      trgt0_hdr_in                         = radm_trgt0_hdr_in;
      trgt0_hdr_in.flt_q_cpl_status        = radm_trgt0_hdr_c[3:1]; // Received sideband signal of cpl_status merged with main hdr
end
  //--------------------------------------------------------------------
  // Following block to assert HALT signal to respetive input channels.
  // At same cycle multiple request may come input to TRGT0. Received
  // requests will serve in sequence as TRGT0 interface to CDM is single 
  // interface and inputs coming to this block is from multiple channles 
  // (posted and non-posted). At a time only one request will serve and other
  // channels will be halted.
  //-------------------------------------------------------------------
always_comb 
begin: TRGT0_DATA

  trgt0_radm_halt_c = {NO_OF_TRGT0_INTF{1'b0}};
  radm_trgt0_hdr_c  = 'd0;
  radm_trgt0_data_c = 'd0;
   for(int i=NO_OF_TRGT0_INTF-1; i >= 0; i = i - 1) begin
      dmux_trgt0_req_hdr[i] = s_dmux_trgt0_req[i][INT_HWIDTH-1:4]; // LSB is hv
      if (req_out[i]) 
      begin
      radm_trgt0_hdr_c  = s_dmux_trgt0_req[i][INT_HWIDTH-1:0]; 
      radm_trgt0_data_c = s_dmux_trgt0_req[i][INT_HDW-1:INT_HWIDTH]; 
      end
   end

 for(int i=NO_OF_TRGT0_INTF-1; i >= 0; i = i - 1) begin
   if (~s_trgt0_radm_halt)
   begin
       if (req_out[i]) 
        begin
           if (i==0)
           begin
             trgt0_radm_halt_c[i]   = 1'b0;
             trgt0_radm_halt_c[i+1] = 1'b1;
           end
           else if (i==1)
           begin
             trgt0_radm_halt_c[i]   = 1'b0;
             trgt0_radm_halt_c[i-1] = 1'b1;
           end
        end
        else 
        begin
        //  trgt0_radm_halt_c   = {NO_OF_TRGT0_INTF{1'b0}}; 
          // if packet wasn't propagated due to arbitraction (req_out[i]=0), halt that path
          trgt0_radm_halt_c[i]   = dmux_trgt0_req_hv[i] || trgt0_req_vld_r[i]; 
        end
   end
   else 
    trgt0_radm_halt_c    = {NO_OF_TRGT0_INTF{1'b1}};
 end
end



  always_ff @(posedge core_clk or negedge core_rst_n)
  begin
    if (core_rst_n ==1'b0)
    begin
      trgt0_req_vld_r          <= #TP 'd0;
    end
    else
    begin
      trgt0_req_vld_r          <=  #TP trgt0_req_vld;
    end
  end

    assign trgt0_radm_halt_int_p    = trgt0_radm_halt_c[0];  // Halt seperation per channel 
    assign s_trgt0_radm_halt_int_np = trgt0_radm_halt_c[1];
  ///////////////////////////////////////////////////////////////////////////////////////////
  // Following module latch the valif signal of respective TLP valid till eot receives of respective TLP
  //------------------------------------------------------------------------------------------
  always_comb 
  begin: TRGT0_REQ
    dmux_trgt0_req_eot   = {NO_OF_TRGT0_INTF{1'b0}};
    dmux_trgt0_req_hv    = {NO_OF_TRGT0_INTF{1'b0}};
    trgt0_req_vld        = trgt0_req_vld_r;

    for (int i=NO_OF_TRGT0_INTF-1;  i >=0; i=i-1)
    begin
  // Not all packets go to trgt0, so if we only compared pkt_num with hv=1, the np packets might be halted forever because the P before it are sent to trgt1
    // so we always assume the packet number is valid even if the hv=0
      dmux_trgt0_req_pkt_num[i] = dmux_trgt0_req_hdr[i].flt_pkt_num; 
      if (s_dmux_trgt0_req[i][0]) 
        dmux_trgt0_req_hv[i]  = 1'b1;
      if (s_dmux_trgt0_req[i][REQ_EOT])
        dmux_trgt0_req_eot[i] = 1'b1;
      if (dmux_trgt0_req_hv[i])
      begin
         if (!dmux_trgt0_req_eot[i]) 
          trgt0_req_vld[i] = 1'b1;
         else if (dmux_trgt0_req_eot[i]) 
          trgt0_req_vld[i] = 1'b0;
      end
   end
  end


  logic co, np_before_p;
  logic [PKT_ORD_WD-1:0] diff_pnp;


    assign {co,diff_pnp} = {1'b0,dmux_trgt0_req_pkt_num[1]} - {1'b0,dmux_trgt0_req_pkt_num[0]};
    // when the MSB of the difference = 1 (np_num < p_num OR np=0&p overflow) OR there is no P packet valid--> Choose NP
// when NP_before_P OR the difference is 0  and there is no P (meaning that we already sent the P with that packet number)
// when P fifo is empty and there is no valid P currently propagate the NP
    assign np_before_p = diff_pnp[PKT_ORD_WD-1] || (!(dmux_trgt0_req_hv[0] || trgt0_req_vld_r[0]) && (diff_pnp=='0 || dmux_trgt0_p_fifo_pipe_empty[0]) && !radm_trgt0_last_p_had_dllp_err[0]);

    assign req_out[0] =  !req_out[1] && (dmux_trgt0_req_hv[0] || trgt0_req_vld_r[0]); // choose P, when there is no NP chosen
    assign req_out[1] =  np_before_p && (dmux_trgt0_req_hv[1] || trgt0_req_vld_r[1]); 

// --------------------------------------------------------------------------------------
//  Generate TRGT0 interface signals
// --------------------------------------------------------------------------------------
  // Extract header

  // Reserved NP TLP decoding. Need to send reserved TLP information to LBC to provide required CPL information to TX - XADM 
  logic [2:0] s_radm_trgt0_fm_rsvd; 
  assign trgt0_fmt2 = trgt0_hdr_in.flt_q_fmt2;
  always_comb begin
     tlp_hdr_pkt = '0;
     tlp_hdr_pkt.tlp_fmt = {trgt0_fmt2,flt_q_fmt_in};
     tlp_hdr_pkt.tlp_type = flt_q_type_in;
   end
   assign s_radm_trgt0_fm_rsvd  = f_tlp_is_fm_np_rsvd(mode_e'(flit_mode), tlp_hdr_pkt);

  assign {radm_trgt0_hdr_in,
          s_radm_trgt0_hv
         } = {radm_trgt0_hdr_c[INT_HWIDTH-1:4],radm_trgt0_hdr_c[0]};

 assign s_radm_trgt0_hdr_in = trgt0_hdr;
 assign s_radm_trgt0_hdr = {trgt0_fmt2,s_radm_trgt0_fm_rsvd[1], s_radm_trgt0_hdr_in[TRGT_HDR_WD-1:0]};

  localparam TRGT_HDR_PROT_WD = (TRGT_HDR_WD / `CX_RAS_PROT_RANGE) + ((TRGT_HDR_WD % `CX_RAS_PROT_RANGE) != 0);

  // Trgt0 HDR PROT Generator
  ras_dp_pipe
   #(
    .PIPELINE_TYPE           (3),                  // No pipeline only checker instance
    .RESETVAL                (0),                  
    .N_STAGES                (1),                  
    .CAN_STALL               (0),                  
    .RESET_STALL             (0),                  
    .BUS_PROTECT_GEN_EN      (1),                   
    .BUS_PROTECT_CHK_EN      (1),                  
    .PROT_TYPE               (PROT_TYPE),          // cc
    .PROT_RANGE              (PROT_RANGE),         // cc
    .PROT_WD                 (TRGT_HDR_PROT_WD),
    .PARITY_MODE             (PARITY_MODE),        // cc
    .PROT_CORRECT_EN         (PROT_CORRECT_EN),    // cc
    .TOTAL_WIDTH             (TRGT_HDR_WD), //
    .RAS_DP_PROT_CHK_ID_BASE (RAS_DP_PROT_CHK_ID_BASE+NO_OF_TRGT0_INTF),
    .PIPE_RAS_DP_ERR_LOG     (1)
  ) u_ras_dp_pipe_trgt0_hdr
  (
    .clk                        (core_clk           ),
    .rst_n                      (core_rst_n         ),
    .en                         (!trgt0_radm_halt   ),
    .bypass                     (1'b0               ),
    .stall                      (1'b0               ),
    .stallout                   (                   ),
    
    .valid_in                   (s_radm_trgt0_hv    ),
    .din                        (s_radm_trgt0_hdr[TRGT_HDR_WD-1:0]),
    .din_prot                   ('0                 ),
    .halt_out                   (                   ),
    
    .valid_out                  (                   ),
    .dout                       (                   ),
    .dout_prot                  (                   ),
    .halt_in                    (1'b0               ),
    .ras_dp_err_inband_kbd_in   (1'b0),
    .ras_dp_err_inband_kbd_out  (   ),
    .ras_dp_err_log             (ras_dp_err_log[NO_OF_TRGT0_INTF])
    ,
    .ras_dp_err_inj             (ras_dp_err_inj)
  );


  // Extract data
  assign {s_radm_trgt0_ecrc_err,
          s_radm_trgt0_abort,
          s_radm_trgt0_eot,
          s_radm_trgt0_dwen,
          s_radm_trgt0_data,
          s_radm_trgt0_dv
         } = radm_trgt0_data_c[INT_DWIDTH-D_UPPR_BITS:0];


  // Insert an idle cycle between back to back RADM to LBC (TRGT0) transfers.
  // If the CIC is enabled then good_hv must be de-asserted when the TRGT0
  // interface is halted. The "good_hv" header info signal is used by the CIC to trap good
  // requests and route halt signals from the CIC FSM or the LBC FSM to the
  // RADM. Gating "good_hv" with the trgt0_radm_halt results in combo loop; hence all
  // TRGT0 interface signals are registered out with and idle cycle inserted between 
  // back to back transfers. In general, with and without the CIC the
  // hv/dv/eot signals must be de-asserted between TRGT0 transfers for
  // DBI/RADM arbitration to work. 
  // Note: radm_trgt0_radm_pending output is set to 0 and is redundant for
  // MS_ARCH configurations.
  always_ff @(posedge core_clk or negedge core_rst_n) begin : proc_seq_dly_eot
    if (!core_rst_n) begin
      r_halt <= #TP 1'b0;
    end else begin
      if (!trgt0_radm_halt) begin
        // Accept the next transaction from TRGT FIFO's when TRGT0 interface is not halted.
        if (r_halt) begin
          r_halt <= #TP 1'b0;
        // De-assert the header info signals on next cycle, after last beat of
        // current transaction accepted by LBC, halt any pending TRGT1 FIFO transactions.
        end else if (s_radm_trgt0_eot) begin
          r_halt <= #TP 1'b1;
        end
      end
    end  
  end

  // Internal halt or TRGT0 halt stalls TRGT FIFO transactions.
  assign s_trgt0_radm_halt      = r_halt | trgt0_radm_halt;

  // Drive TRGT0 interface signals to zero during idle cycle.
  assign ss_radm_trgt0_hv       = r_halt ? 1'b0                     : s_radm_trgt0_hv;
  assign ss_radm_trgt0_hdr      = r_halt ? 'd0                      : s_radm_trgt0_hdr;
  assign ss_radm_trgt0_ecrc_err = r_halt ? 1'b0                     : s_radm_trgt0_ecrc_err;
  assign ss_radm_trgt0_abort    = r_halt ? 1'b0                     : s_radm_trgt0_abort;
  assign ss_radm_trgt0_eot      = r_halt ? 1'b0                     : s_radm_trgt0_eot;
  assign ss_radm_trgt0_dwen     = r_halt ? {NW{1'b0}}               : s_radm_trgt0_dwen;
  assign ss_radm_trgt0_data     = r_halt ? {(DW+DATA_PAR_WD){1'b0}} : s_radm_trgt0_data; 
  assign ss_radm_trgt0_dv       = r_halt ? 1'b0                     : s_radm_trgt0_dv;
  assign ss_radm_trgt0_p        = r_halt ? 1'b0                     : req_out[0]; // 1: Posted 0: Non-Posted

  //  Register the TRGT0 interface signals
  always_ff @(posedge core_clk or negedge core_rst_n) begin : proc_seq_trgt0_intf
    if (!core_rst_n) begin
      r_radm_trgt0_hv       <= #TP 1'b0;
      r_radm_trgt0_hdr      <= #TP 'd0; 
      r_radm_trgt0_ecrc_err <= #TP 1'b0;
      r_radm_trgt0_abort    <= #TP 1'b0;
      r_radm_trgt0_eot      <= #TP 1'b0;
      r_radm_trgt0_dwen     <= #TP {NW{1'b0}};
      r_radm_trgt0_data     <= #TP {DW+DATA_PAR_WD{1'b0}};
      r_radm_trgt0_dv       <= #TP 1'b0;
      r_radm_trgt0_p        <= #TP 1'b0;
    end else begin
      if (!trgt0_radm_halt) begin
        r_radm_trgt0_hv       <= #TP ss_radm_trgt0_hv;
        r_radm_trgt0_hdr      <= #TP ss_radm_trgt0_hdr;
        r_radm_trgt0_ecrc_err <= #TP ss_radm_trgt0_ecrc_err;
        r_radm_trgt0_abort    <= #TP ss_radm_trgt0_abort;
        r_radm_trgt0_eot      <= #TP ss_radm_trgt0_eot;
        r_radm_trgt0_dwen     <= #TP ss_radm_trgt0_dwen;
        r_radm_trgt0_data     <= #TP ss_radm_trgt0_data;
        r_radm_trgt0_dv       <= #TP ss_radm_trgt0_dv;
        r_radm_trgt0_p        <= #TP ss_radm_trgt0_p;
      end
    end  
  end

 // Build header info
   assign  trgt0_hdr.hdr_dec_flt_cpltr_seg = trgt0_hdr_in.hdr_dec_flt_cpltr_seg; 
   assign  trgt0_hdr.hdr_dec_flt_dest_seg  =  trgt0_hdr_in.hdr_dec_flt_dest_seg; 
   assign  trgt0_hdr.hdr_dec_flt_reqtr_seg = trgt0_hdr_in.hdr_dec_flt_reqtr_seg;
   assign  trgt0_hdr.log_rcvd_flds         = trgt0_hdr_in.log_rcvd_flds ; 
  assign  trgt0_hdr.flt_q_cpl_last            = trgt0_hdr_in.flt_q_cpl_last;
    assign  trgt0_hdr.flt_q_ats              = trgt0_hdr_in.flt_q_ats; 
  assign  trgt0_hdr.flt_q_poisoned           = trgt0_hdr_in.flt_q_poisoned; 
  assign  trgt0_hdr.flt_q_td                 = trgt0_hdr_in.flt_q_td;

always_comb begin
    trgt0_hdr.flt_q_th               = trgt0_hdr_in.flt_q_th; 
       trgt0_hdr.flt_q_addr = trgt0_hdr_in.flt_q_th ? {trgt0_hdr_in.flt_q_addr[`FLT_Q_ADDR_WIDTH-1:2],2'b00} : (flit_mode && (|trgt0_hdr_in.flt_q_ats)) ?
       {trgt0_hdr_in.flt_q_addr[`FLT_Q_ADDR_WIDTH-1:2],2'b00} : (trgt0_hdr_in.flt_q_ats == 2'b01) ? {trgt0_hdr_in.flt_q_addr[ `FLT_Q_ADDR_WIDTH-1:1],1'b0} : trgt0_hdr_in.flt_q_addr[ `FLT_Q_ADDR_WIDTH-1:0];
     trgt0_hdr.flt_q_last_be  = trgt0_hdr_in.flt_q_last_be;   
     trgt0_hdr.flt_q_first_be = trgt0_hdr_in.flt_q_first_be;   
  // Following logic is need to consider only for EP mode of operation 
  // FOR trgt0 UR, we overload some of the address with lastdw/length
  if ( device_is_ep && (trgt0_hdr_in.flt_q_cpl_status != `SU_CPL_STATUS) )
  begin
    trgt0_hdr.flt_q_addr[10:7]  = trgt0_hdr.flt_q_last_be[3:0];
    trgt0_hdr.flt_q_addr[20:11] = trgt0_hdr.flt_q_dw_len[9:0];
  end
end

  assign  trgt0_hdr.flt_q_io_req_in_range    = trgt0_hdr_in.flt_q_io_req_in_range; 
    assign  trgt0_hdr.flt_q_rom_req_in_range = trgt0_hdr_in.flt_q_rom_req_in_range; 
    assign  trgt0_hdr.flt_q_in_membar_range  = trgt0_hdr_in.flt_q_in_membar_range;

  assign  trgt0_hdr.flt_q_dw_len             = trgt0_hdr_in.flt_q_dw_len; 
    assign  trgt0_hdr.flt_q_prfx             = trgt0_hdr_in.flt_q_prfx; 

  assign  trgt0_hdr.flt_q_cpl_status         = trgt0_hdr_in.flt_q_cpl_status;
  assign  trgt0_hdr.flt_q_func_nmbr          = trgt0_hdr_in.flt_q_func_nmbr; 
  assign  trgt0_hdr.flt_q_TAG                = (flit_mode && trgt0_tph_memwr) ? {{(`FLT_Q_TAG_WIDTH - 8){1'b0}},trgt0_hdr_in.flt_q_st} : trgt0_hdr_in.flt_q_TAG;
  assign  trgt0_hdr.flt_q_REQID              = trgt0_hdr_in.flt_q_REQID; 

  assign  trgt0_hdr.flt_q_attr               = trgt0_hdr_in.flt_q_attr; 
  assign  trgt0_hdr.flt_q_tc                 = trgt0_hdr_in.flt_q_tc; 
  assign  trgt0_hdr.flt_q_type               = trgt0_hdr_in.flt_q_type;
  assign  trgt0_hdr.flt_q_fmt                = trgt0_hdr_in.flt_q_fmt; 
  assign  trgt0_hdr.flt_q_destination        = trgt0_hdr_in.flt_q_destination; 

// --------------------------------------------------------------------------------------
// Assign Outputs
// --------------------------------------------------------------------------------------
// TRGT0 Interfce
logic  radm_trgt0_fmt2;

  assign radm_trgt0_hv       = r_radm_trgt0_hv;
  assign radm_trgt0_hdr      = r_radm_trgt0_hdr[TRGT_HDR_WD-1:0];
  assign radm_trgt0_ecrc_err = r_radm_trgt0_ecrc_err;
  assign radm_trgt0_abort    = r_radm_trgt0_abort;
  assign radm_trgt0_eot      = r_radm_trgt0_eot;
  assign radm_trgt0_dwen     = r_radm_trgt0_dwen;
  assign radm_trgt0_data     = r_radm_trgt0_data;
  assign radm_trgt0_dv       = r_radm_trgt0_dv;
  assign radm_trgt0_np_rsvd  = r_radm_trgt0_hdr[TRGT_HDR_WD];
  assign radm_trgt0_fmt2     = r_radm_trgt0_hdr[TRGT_HDR_WD+1];

  // TRGT0 Clock Gating Control Info 
  always @(posedge core_clk or negedge core_rst_n) begin : proc_seq_clkg_info
    if (!core_rst_n) begin
      radm_trgt0_p  <= #TP 1'b0;
      radm_trgt0_np <= #TP 1'b0;
    end else begin
      radm_trgt0_p  <= #TP r_radm_trgt0_eot && r_radm_trgt0_p && !trgt0_radm_halt;
      radm_trgt0_np <= #TP r_radm_trgt0_eot && !r_radm_trgt0_p && !trgt0_radm_halt;
    end  
  end

endmodule
