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
// ---    $DateTime: 2023/09/27 02:27:25 $
// ---    $Revision: #4 $
// ---    $Id: //dwh/pcie_iip/main/fairbanks/design/Adm_ms/radm_hdr_log_ser.sv#4 $
// -------------------------------------------------------------------------

// -----------------------------------------------------------------------------
// --- Module Description:
// -----------------------------------------------------------------------------
// --- This module handles logging and arbitration of multiple errors from multiple targets per FC.
// --- Its main functions are:
// ---    (1) saves the incoming headers until the on issued at arbitration is finished
// ---    (2) halts other interfaces in case they have errors and there is an error processed at the output
// ---    (3) flit mode is supported
// -----------------------------------------------------------------------------

`include "include/DWC_pcie_ctl_all_defs.svh"
`include "DWC_pcie_ctl_pkg.svh"
`include "products/DWC_pcie_core_pkg.svh"
`include "Adm_ms/radm_ms_pkg.svh"
`include "products/pcie_pkg.svh"

 module radm_hdr_log_ser 
  ///////////////////////////////////////// 
  //import radm_ms_pkg starts
  import radm_ms_pkg::N_TRGT1_INTF;
  import radm_ms_pkg::FX_TLP;
  import radm_ms_pkg::CX_MAX_HDR_LOG_SZ;
  import radm_ms_pkg::FLT_Q_ADDR_WIDTH;
  import radm_ms_pkg::flt_hdr_s;

  import radm_ms_pkg::radm_hdr_dec_com_ohc_decx_present_s;
  import radm_ms_pkg::flt_q_dmux_o_s;
  import radm_ms_pkg::CX_HDR_LOG_P_FIFO_DP;
  import radm_ms_pkg::CX_HDR_LOG_CPL_FIFO_DP;
  import radm_ms_pkg::CX_HDR_LOG_NP_FIFO_DP;
  import radm_ms_pkg::radm_hdr_log_err_index;

  //import radm_ms_pkg ends
  //////////////////////////////////////////

  //////////////////////////////////////////
  //import DWC_pcie_ctl_pkg starts
  import DWC_pcie_ctl_pkg::DW;
  import DWC_pcie_ctl_pkg::PF_WD;  
  import DWC_pcie_ctl_pkg::NF;
  import DWC_pcie_ctl_pkg::NVF;  
  import DWC_pcie_ctl_pkg::VF_WD; 
  import DWC_pcie_ctl_pkg::VFI_WD;



  //import DWC_pcie_ctl_pkg ends
  /////////////////////////////////////

  /////////////////////////////////////
  //import DWC_pcie_core_pkg starts 
  import DWC_pcie_core_pkg::radm_hdr_log_s;
  //import DWC_pcie_core_pkg ends
  ////////////////////////////////////

  ///////////////////////////////////
  //import pcie_pkg starts 

  import pcie_pkg::fc_type_e;
  import pcie_pkg::E_P;
  import pcie_pkg::E_NP;
  import pcie_pkg::E_CPL;
  import pcie_pkg::E_FC_NONE;

  //import pcie_pkg ends
  ////////////////////////////////////////////

 
                          (
//---------- inputs --------------
 input  logic                                core_clk,
 input  logic                                core_rst_n,
 input  logic                                flit_mode,
 input  logic [2*NF-1:0]                     cfg_max_end2end_tlp_prfxs,
 input  flt_q_dmux_o_s [N_TRGT1_INTF-1:0]    p_radm_hdr_log_i,
 input  flt_q_dmux_o_s [N_TRGT1_INTF-1:0]    np_radm_hdr_log_i,
 input  flt_q_dmux_o_s [N_TRGT1_INTF-1:0]    cpl_radm_hdr_log_i,
 output radm_hdr_log_s                       radm_hdr_log,
 output logic                                hdr_log_idle,
 output logic [FX_TLP-1:0]                   halt_out
);
// -----------------------------------------------------------------------------
// --- Parameters
// -----------------------------------------------------------------------------

parameter INST                  = 0   ;                            // The uniquifying parameter for each port logic instance.                                     
parameter TP                    = `TP ;

// -----------------------------------------------------------------------------
// --- Local Parameters
// -----------------------------------------------------------------------------
localparam  SINGLE_INTF_WD             = $bits(p_radm_hdr_log_i[0].flt_q_header) ;
localparam  FX_TLP_WD                  = `CX_LOGBASE2(FX_TLP) ;
localparam  CX_MAX_HDR_LOG_PW          = $clog2(CX_MAX_HDR_LOG_SZ+1) ;
localparam  HDR_LOG_P_FIFO_DP          = CX_HDR_LOG_P_FIFO_DP ;
localparam  HDR_LOG_P_FIFO_ADDR_WD     = (HDR_LOG_P_FIFO_DP==1)?$clog2(HDR_LOG_P_FIFO_DP+1)    : $clog2(HDR_LOG_P_FIFO_DP);
localparam  HDR_LOG_NP_FIFO_DP         = CX_HDR_LOG_NP_FIFO_DP ;
localparam  HDR_LOG_NP_FIFO_ADDR_WD    = (HDR_LOG_NP_FIFO_DP==1)?$clog2(HDR_LOG_NP_FIFO_DP+1)  : $clog2(HDR_LOG_NP_FIFO_DP);
localparam  HDR_LOG_CPL_FIFO_DP        = 1 ;
localparam  HDR_LOG_CPL_FIFO_ADDR_WD   = (HDR_LOG_CPL_FIFO_DP==1)?$clog2(HDR_LOG_CPL_FIFO_DP+1): $clog2(HDR_LOG_CPL_FIFO_DP);
localparam integer REG_DELAY_DENOM     = 1000 ;
localparam integer REG_DELAY_TIME      = TP*REG_DELAY_DENOM ;
localparam integer REG_DELAY_TIME_FIFO = TP*REG_DELAY_DENOM ;

//------------------------------------------------------------------------
//-- Code start
//------------------------------------------------------------------------
logic [N_TRGT1_INTF*SINGLE_INTF_WD-1:0] radm_trgt1_p_hdr               ;
logic [N_TRGT1_INTF*5 -1:0]             radm_trgt1_p_err_idx           ;
logic [N_TRGT1_INTF-1:0]                radm_trgt1_p_func_specific_err ;
logic [N_TRGT1_INTF-1:0]                radm_trgt1_p_hv                ;
logic [N_TRGT1_INTF-1:0]                radm_trgt1_p_eot               ;
logic [N_TRGT1_INTF-1:0]                radm_trgt1_p_tlp_abort         ;


logic [N_TRGT1_INTF*SINGLE_INTF_WD-1:0] radm_trgt1_np_hdr               ;
logic [N_TRGT1_INTF*5 -1:0]             radm_trgt1_np_err_idx           ;
logic [N_TRGT1_INTF-1:0]                radm_trgt1_np_func_specific_err ;
logic [N_TRGT1_INTF-1:0]                radm_trgt1_np_hv                ;
logic [N_TRGT1_INTF-1:0]                radm_trgt1_np_eot               ;
logic [N_TRGT1_INTF-1:0]                radm_trgt1_np_tlp_abort         ;


logic [N_TRGT1_INTF*SINGLE_INTF_WD-1:0] radm_trgt1_cpl_hdr               ;
logic [N_TRGT1_INTF*5 -1:0]             radm_trgt1_cpl_err_idx           ;
logic [N_TRGT1_INTF-1:0]                radm_trgt1_cpl_func_specific_err ;
logic [N_TRGT1_INTF-1:0]                radm_trgt1_cpl_hv                ;
logic [N_TRGT1_INTF-1:0]                radm_trgt1_cpl_eot               ;
logic [N_TRGT1_INTF-1:0]                radm_trgt1_cpl_tlp_abort         ;

flt_q_dmux_o_s [N_TRGT1_INTF-1:0]       p_radm_hdr_log_int, np_radm_hdr_log_int, cpl_radm_hdr_log_int;
flt_hdr_s                               flt_hdr_i ;
fc_type_e                               fc_i, fc_d, fc ;
logic [4:0]                             err_idx_i, err_idx_d, err_idx ;
logic                                   func_specific_err_i, func_specific_err_d, func_specific_err ;
logic [CX_MAX_HDR_LOG_PW-1:0]           hdr_size_i, hdr_size_d, hdr_size ;
logic                                   flit_mode_d, flit_mode_out, flit_mode_picked ;
logic [FX_TLP-1:0]                      flit_mode_i ;
logic [32*CX_MAX_HDR_LOG_SZ-1:0]        log_hdr_prfx, int_log_hdr_prfx, int_log_hdr_prfx_d;
logic                                   log_valid,int_log_valid_d,int_log_valid;
logic [PF_WD -1:0]                      hdr_pf, int_hdr_pf, int_hdr_pf_d ;
logic                                   hdr_log_idle_i, hdr_log_idle_d ;
logic [N_TRGT1_INTF-1:0][63:0] p_tmp_addr;
logic [N_TRGT1_INTF-1:0][63:0] np_tmp_addr;
logic [N_TRGT1_INTF-1:0][63:0] cpl_tmp_addr;
// -------- Partial Header Encryption Start --------- //
always_comb begin
    p_radm_hdr_log_int   = p_radm_hdr_log_i   ;
    np_radm_hdr_log_int  = np_radm_hdr_log_i  ;
    cpl_radm_hdr_log_int = cpl_radm_hdr_log_i ;


end
// -------- Partial Header Encryption End --------- //

//------- Struct Assignment to signals --------
generate
    for (genvar i=0; i<N_TRGT1_INTF; i++) begin: signal_connection
        assign radm_trgt1_p_hdr[i*SINGLE_INTF_WD +:SINGLE_INTF_WD]   =  p_radm_hdr_log_int[i].flt_q_header ;
        assign radm_trgt1_p_err_idx[i*5 +:5]                         =  p_radm_hdr_log_int[i].radm_hdr_log_err_index ; 
        assign radm_trgt1_p_func_specific_err[i]                     = ~p_radm_hdr_log_int[i].radm_hdr_log_vld_all_fn ;
        assign radm_trgt1_p_hv[i]                                    =  p_radm_hdr_log_int[i].flt_q_hv;
        assign radm_trgt1_p_eot[i]                                   =  p_radm_hdr_log_int[i].flt_q_eot;
        assign radm_trgt1_p_tlp_abort[i]                             =  p_radm_hdr_log_int[i].radm_hdr_log_vld;
        
        
        assign radm_trgt1_np_hdr[i*SINGLE_INTF_WD +:SINGLE_INTF_WD]  =  np_radm_hdr_log_int[i].flt_q_header ;
        assign radm_trgt1_np_err_idx[i*5 +:5]                        =  np_radm_hdr_log_int[i].radm_hdr_log_err_index ; 
        assign radm_trgt1_np_func_specific_err[i]                    = ~np_radm_hdr_log_int[i].radm_hdr_log_vld_all_fn ; 
        assign radm_trgt1_np_hv[i]                                   =  np_radm_hdr_log_int[i].flt_q_hv;
        assign radm_trgt1_np_eot[i]                                  =  np_radm_hdr_log_int[i].flt_q_eot;
        assign radm_trgt1_np_tlp_abort[i]                            =  np_radm_hdr_log_int[i].radm_hdr_log_vld;
        
        
        assign radm_trgt1_cpl_hdr[i*SINGLE_INTF_WD +:SINGLE_INTF_WD] =  cpl_radm_hdr_log_int[i].flt_q_header ;
        assign radm_trgt1_cpl_err_idx[i*5 +:5]                       =  cpl_radm_hdr_log_int[i].radm_hdr_log_err_index ; 
        assign radm_trgt1_cpl_func_specific_err[i]                   = ~cpl_radm_hdr_log_int[i].radm_hdr_log_vld_all_fn ; 
        assign radm_trgt1_cpl_hv[i]                                  =  cpl_radm_hdr_log_int[i].flt_q_hv;
        assign radm_trgt1_cpl_eot[i]                                 =  cpl_radm_hdr_log_int[i].flt_q_eot;
        assign radm_trgt1_cpl_tlp_abort[i]                           =  cpl_radm_hdr_log_int[i].radm_hdr_log_vld;
    end
endgenerate


//------- Assignment to Output Struct --------
assign radm_hdr_log.hdr_prfx          = log_hdr_prfx;
assign radm_hdr_log.valid_pf          = log_valid;
assign radm_hdr_log.pf                = hdr_pf ;
assign radm_hdr_log.flit_mode         = flit_mode_out ;
assign radm_hdr_log.hdr_size          = hdr_size ;
assign radm_hdr_log.err_idx           = err_idx ;
assign radm_hdr_log.f_spec_err        = func_specific_err ;
assign radm_hdr_log.fc                = fc ;
assign hdr_log_idle                   = hdr_log_idle_d ;
//-------------------------- Rewiring ------------------------------------
logic [FX_TLP-1:0] [SINGLE_INTF_WD-1:0] int_radm_filter_log_in ;
fc_type_e [FX_TLP-1:0]                  int_fc, int_arb_in_fc ;
logic [FX_TLP-1:0] [4:0]                int_err_idx, int_arb_in_err_idx  ;
logic [FX_TLP-1:0]                      int_func_specific_err, int_arb_in_func_specific_err ;
logic [FX_TLP-1:0]                      int_hv,int_eot,int_tlp_abort ;
logic [FX_TLP-1:0] [SINGLE_INTF_WD-1:0] int_radm_filter_arb_in ;
logic [FX_TLP-1:0]                      int_halt,grant ;
logic [FX_TLP-1:0]                      arb_request ;
logic [FX_TLP-1:0]                      full_signal, empty_signal, pop_req_s ;
logic [`CX_LOGBASE2(FX_TLP)-1:0]        chosen_idx ;
logic                                   chosen ;

logic [FX_TLP-1:0][FX_TLP_WD-1:0]       priority_vector ; // Giving CPL higher priority


always_comb begin: Rewiring_for_TRGT1_signals
    int_radm_filter_log_in = '0 ;
    int_fc                 = {2*FX_TLP{1'b1}} ;
    priority_vector        = '0 ;
    for (int i=0; i<N_TRGT1_INTF; i++) begin
        for (int j=0; j<3; j++) begin
            if (j==0) begin
                int_radm_filter_log_in[i*3 +0] = {radm_trgt1_p_hdr[i*SINGLE_INTF_WD+:SINGLE_INTF_WD]} ;
                int_err_idx[i*3 +0]            = radm_trgt1_p_err_idx[i*5 +:5] ;
                int_func_specific_err[i*3 +0]  = radm_trgt1_p_func_specific_err[i] ;
                int_hv[i*3+0]                  = radm_trgt1_p_hv[i] ;
                int_eot[i*3+0]                 = radm_trgt1_p_eot[i] ;
                int_tlp_abort[i*3+0]           = radm_trgt1_p_tlp_abort[i] ;
                int_fc[i*3 +0]                 = E_P ;
                priority_vector[i*3 +0]        = {FX_TLP_WD{1'b1}} ; 
            end
            else if (j==1) begin
                int_radm_filter_log_in[i*3 +1] = {radm_trgt1_np_hdr[i*SINGLE_INTF_WD+:SINGLE_INTF_WD]} ;
                int_err_idx[i*3 +1]            = radm_trgt1_np_err_idx[i*5 +:5] ;
                int_func_specific_err[i*3 +1]  = radm_trgt1_np_func_specific_err[i] ;
                int_hv[i*3+1]                  = radm_trgt1_np_hv[i] ;
                int_eot[i*3+1]                 = radm_trgt1_np_eot[i] ;
                int_tlp_abort[i*3+1]           = radm_trgt1_np_tlp_abort[i] ;
                int_fc[i*3 +1]                 = E_NP ;
                priority_vector[i*3 +1]        = {FX_TLP_WD{1'b1}} ;
            end
            else begin
                int_radm_filter_log_in[i*3 +2] = {radm_trgt1_cpl_hdr[i*SINGLE_INTF_WD+:SINGLE_INTF_WD]} ;
                int_err_idx[i*3 +2]            = radm_trgt1_cpl_err_idx[i*5 +:5] ;
                int_func_specific_err[i*3 +2]  = radm_trgt1_cpl_func_specific_err[i] ;
                int_hv[i*3+2]                  = radm_trgt1_cpl_hv[i] ;
                int_eot[i*3+2]                 = radm_trgt1_cpl_eot[i] ;
                int_tlp_abort[i*3+2]           = radm_trgt1_cpl_tlp_abort[i] ;
                int_fc[i*3 +2]                 = E_CPL ;
                priority_vector[i*3 +2]        = {FX_TLP_WD{1'b0}} ; 
            end
        end
    end
end: Rewiring_for_TRGT1_signals




//----------------------- Storage and delay -------------------------------

always_comb begin
    for (int i=0; i<FX_TLP; i++) begin
         halt_out[i] = int_halt[i] && full_signal[i] ;
    end
end

// For the proposed implementation There are 2 Fifos per FC 
// 1 Fifo for Data (hdr that get updated at hv) & another fifo for Controls( signal that get updated at eot)
// In case CPL_BYPASS is enabled CPL Fifos will be mandated to be using only fifos of depth 1
generate
    for (genvar i=0; i<N_TRGT1_INTF; i++) begin: N_TRGT1_LOOP
        for (genvar j=0; j<3; j++) begin: N_FC_LOOP
            if (j==0) begin: P_FIFO
DWC_pcie_ctl_bcm64_td
 #(
    .WIDTH (        1      // arb_request
                    +5     // err_idx
                    +1     // func_spec_err
    ),
    .DEPTH           ( HDR_LOG_P_FIFO_DP      ),
    .REG_DELAY_TIME  ( REG_DELAY_TIME_FIFO    ), 
    .REG_DELAY_DENOM ( REG_DELAY_DENOM        ), 
    .ADDR_WIDTH      ( HDR_LOG_P_FIFO_ADDR_WD )
) 
u_fifo_ctrl_signals (
    .clk          ( core_clk         ),
    .rst_n        ( core_rst_n       ),
    .init_n       ( 1'b1             ),
    .push_req_n   ( ~(int_eot[i] && ~halt_out[i]) ),
    .pop_req_n    ( pop_req_s[i]     ),
    .diag_n       (1'b1         ),
    .ae_level     ( '0          ),
    .af_thresh    ( '1          ),
    .data_in      (
        {                          int_tlp_abort[i],
                                   int_err_idx[i],
                                   int_func_specific_err[i]
                                 }
    ),
    .empty        ( empty_signal[i]      ),
    .almost_empty (),
    .half_full    (),
    .almost_full  (),
    .full         ( full_signal[i]       ),
    .error        (),
    .data_out     (
        { arb_request[i],
          int_arb_in_err_idx[i],
          int_arb_in_func_specific_err[i]
        }
    )
);


DWC_pcie_ctl_bcm64_td
 #(
    .WIDTH (   
                    SINGLE_INTF_WD
                    +2     // fc
                    +1     // flit_mode
    ),
    .DEPTH           ( HDR_LOG_P_FIFO_DP      ),
    .REG_DELAY_TIME  ( REG_DELAY_TIME_FIFO    ), 
    .REG_DELAY_DENOM ( REG_DELAY_DENOM        ), 
    .ADDR_WIDTH      ( HDR_LOG_P_FIFO_ADDR_WD )
) 
u_fifo_hdr (
    .clk          ( core_clk        ),
    .rst_n        ( core_rst_n      ),
    .init_n       ( 1'b1            ),
    .push_req_n   ( ~(int_hv[i] && ~halt_out[i])    ),   //&& ~int_halt[i]
    .pop_req_n    ( pop_req_s[i]    ),
    .diag_n       (1'b1             ),
    .ae_level     ( '0              ),
    .af_thresh    ( '1              ),
    .data_in      (
        {                         
                                   
                                   int_radm_filter_log_in[i] ,
                                   int_fc[i]
                                   ,flit_mode 
                                 }
    ),
    .empty        (),
    .almost_empty (),
    .half_full    (),
    .almost_full  (),
    .full         (),
    .error        (),
    .data_out     (
        { 
          int_radm_filter_arb_in[i] ,
          int_arb_in_fc[i]
          ,flit_mode_i[i] 
        }
    )
);

            end: P_FIFO
            else if (j==1) begin: NP_FIFO
DWC_pcie_ctl_bcm64_td
 #(
    .WIDTH (        1      // arb_request
                    +5     // err_idx
                    +1     // func_spec_err
    ),
    .DEPTH           ( HDR_LOG_NP_FIFO_DP      ),
    .REG_DELAY_TIME  ( REG_DELAY_TIME_FIFO     ), 
    .REG_DELAY_DENOM ( REG_DELAY_DENOM         ), 
    .ADDR_WIDTH      ( HDR_LOG_NP_FIFO_ADDR_WD )
) 
u_fifo_ctrl_signals (
    .clk          ( core_clk         ),
    .rst_n        ( core_rst_n       ),
    .init_n       ( 1'b1             ),
    .push_req_n   (  ~(int_eot[i+1] && ~halt_out[i+1]) ),
    .pop_req_n    ( pop_req_s[i+1]     ),
    .diag_n       (1'b1         ),
    .ae_level     ( '0          ),
    .af_thresh    ( '1          ), 
    .data_in      (
        {                          int_tlp_abort[i+1],
                                   int_err_idx[i+1],
                                   int_func_specific_err[i+1]
                                 }
    ),
    .empty        ( empty_signal[i+1]),
    .almost_empty (),
    .half_full    (),
    .almost_full  ( ),
    .full         ( full_signal[i+1]       ),
    .error        (),
    .data_out     (
        { arb_request[i+1],
          int_arb_in_err_idx[i+1],
          int_arb_in_func_specific_err[i+1]
        }
    )
);


DWC_pcie_ctl_bcm64_td
 #(
    .WIDTH (   
                    SINGLE_INTF_WD
                    +2     // fc
                    +1     // flit_mode
    ),
    .DEPTH           ( HDR_LOG_NP_FIFO_DP      ),
    .REG_DELAY_TIME  ( REG_DELAY_TIME_FIFO     ), 
    .REG_DELAY_DENOM ( REG_DELAY_DENOM         ), 
    .ADDR_WIDTH      ( HDR_LOG_NP_FIFO_ADDR_WD )
) 
u_fifo_hdr (
    .clk          ( core_clk        ),
    .rst_n        ( core_rst_n      ),
    .init_n       ( 1'b1            ),
    .push_req_n   ( ~(int_hv[i+1] && ~halt_out[i+1])   ),   //&& ~int_halt[i]
    .pop_req_n    ( pop_req_s[i+1]    ),
    .diag_n       (1'b1             ),
    .ae_level     ( '0              ),
    .af_thresh    ( '1              ),
    .data_in      (
        {                         
                                   
                                   int_radm_filter_log_in[i+1] ,
                                   int_fc[i+1]
                                   ,flit_mode 
                                 }
    ),
    .empty        (),
    .almost_empty (),
    .half_full    (),
    .almost_full  (),
    .full         (),
    .error        (),
    .data_out     (
        { 
          int_radm_filter_arb_in[i+1] ,
          int_arb_in_fc[i+1]
          ,flit_mode_i[i+1] 
        }
    )
);
    
            end: NP_FIFO
            else begin: CPL_FIFO
DWC_pcie_ctl_bcm64_td
 #(
    .WIDTH (        1      // arb_request
                    +5     // err_idx
                    +1     // func_spec_err
    ),
    .DEPTH           ( HDR_LOG_CPL_FIFO_DP      ),
    .REG_DELAY_TIME  ( REG_DELAY_TIME_FIFO      ), 
    .REG_DELAY_DENOM ( REG_DELAY_DENOM          ), 
    .ADDR_WIDTH      ( HDR_LOG_CPL_FIFO_ADDR_WD )
) 
u_fifo_ctrl_signals (
    .clk          ( core_clk         ),
    .rst_n        ( core_rst_n       ),
    .init_n       ( 1'b1             ),
    .push_req_n   (  ~(int_eot[i+2] && ~halt_out[i+2]) ),
    .pop_req_n    ( pop_req_s[i+2]     ),
    .diag_n       (1'b1         ),
    .ae_level     ( '0          ),
    .af_thresh    ( '1 ),
    .data_in      (
        {                          int_tlp_abort[i+2],
                                   int_err_idx[i+2],
                                   int_func_specific_err[i+2]
                                 }
    ),
    .empty        ( empty_signal[i+2]),
    .almost_empty (),
    .half_full    (),
    .almost_full  (),
    .full         ( full_signal[i+2]       ),
    .error        (),
    .data_out     (
        { arb_request[i+2],
          int_arb_in_err_idx[i+2],
          int_arb_in_func_specific_err[i+2]
        }
    )
);


DWC_pcie_ctl_bcm64_td
 #(
    .WIDTH (   
                    SINGLE_INTF_WD
                    +2     // fc
                    +1     // flit_mode
    ),
    .DEPTH           ( HDR_LOG_CPL_FIFO_DP      ),
    .REG_DELAY_TIME  ( REG_DELAY_TIME_FIFO      ), 
    .REG_DELAY_DENOM ( REG_DELAY_DENOM          ), 
    .ADDR_WIDTH      ( HDR_LOG_CPL_FIFO_ADDR_WD )
) 
u_fifo_hdr (
    .clk          ( core_clk        ),
    .rst_n        ( core_rst_n      ),
    .init_n       ( 1'b1            ),
    .push_req_n   ( ~(int_hv[i+2] && ~halt_out[i+2])   ),   //&& ~int_halt[i]
    .pop_req_n    ( pop_req_s[i+2]    ),
    .diag_n       (1'b1             ),
    .ae_level     ( '0              ),
    .af_thresh    ( '1              ),
    .data_in      (
        {                         
                                   
                                   int_radm_filter_log_in[i+2] ,
                                   int_fc[i+2]
                                   ,flit_mode 
                                 }
    ),
    .empty        (),
    .almost_empty (),
    .half_full    (),
    .almost_full  (),
    .full         (),
    .error        (),
    .data_out     (
        { 
          int_radm_filter_arb_in[i+2] ,
          int_arb_in_fc[i+2]
          ,flit_mode_i[i+2] 
        }
    )
);

            end: CPL_FIFO
        end: N_FC_LOOP



    end: N_TRGT1_LOOP
endgenerate




//----------------------- Arbitration -------------------------------

DWC_pcie_ctl_bcmmod53
 #(
.REG_DELAY_TIME  ( REG_DELAY_TIME   ), 
.REG_DELAY_DENOM ( REG_DELAY_DENOM  ), 
.N               ( FX_TLP           ),  
.P_WIDTH         ( FX_TLP_WD        ),  
.PARK_MODE       ( 1'b0             ),
.PARK_INDEX      (   '0             ),
.OUTPUT_MODE     ( 1'b0             ),
.INDEX_WIDTH     ( FX_TLP_WD        )
)
u_arb(

.clk         ( core_clk),
.rst_n       ( core_rst_n),
.init_n      ( 1'b1),
.enable      ( 1'b1),
.request     ( (~empty_signal) & arb_request), // empty signal is used as in case all stuff are popped the last one will be on top and the arb_request(tlp_abort) will be read over and over
.prior       ( priority_vector),
.lock        ( '0             ),
.mask        ( '0             ),
.parked      (                ),
.granted     ( chosen         ),
.locked      (                ),
.grant       ( grant          ),
.grant_index ( chosen_idx     )
);



always_comb begin
    flt_hdr_i = '0 ;
    pop_req_s = {FX_TLP{1'b1}} ;
    err_idx_i = '0 ;
    func_specific_err_i = '0 ;
    fc_i       = E_FC_NONE ;
    flit_mode_picked   = '0 ;
    int_hdr_pf = '0 ;
    int_log_valid     = 1'b0 ;

    for (int i=0; i<FX_TLP; i++) begin
        int_halt [i] = ( chosen && !empty_signal[i] && arb_request[i]) && (!grant[i]) ;
        // Chosen is a one-bit signal and it will be raised in case one of the request vector is chosen
        // so the other elements of request vector will be halted in the case that they are not chosen yet (!grant[i])   
    end

    for (int i=0; i<FX_TLP; i++) begin
        // This case tells when to pop as there are three main cases
        // 1st case: when fifos are not empty and there is no error so the saved stuff will be popped and dropped
        // 2nd case: when fifos are not empty and there is at least one error so the halt signal will be used as pop signal
        // 3rd case: when fifos are empty so there is no popping at all
        case ({empty_signal[i],arb_request[i]})
            2'b00  : pop_req_s[i] = 1'b0 ;
            2'b01  : pop_req_s[i] = int_halt[i] ;
            default: pop_req_s[i] = 1'b1 ;  
        endcase
    end


    for (int i=0; i<FX_TLP; i++) begin
        if (chosen && chosen_idx==i) begin
            flt_hdr_i           = int_radm_filter_arb_in[i] ;
            err_idx_i           = int_arb_in_err_idx[i] ;
            func_specific_err_i = int_arb_in_func_specific_err[i] ;
            fc_i                = int_arb_in_fc[i] ;
            flit_mode_picked    = flit_mode_i[i] ;
            int_hdr_pf          = flt_hdr_i.flt_q_func_nmbr ;
            int_log_valid       = 1'b1 ;
        end
    end
end





radm_hdr_log_form

  u_hdr_log_form(
    .flit_mode                 ( flit_mode_picked          ),
    .cfg_max_end2end_tlp_prfxs ( cfg_max_end2end_tlp_prfxs ),
    .flt_hdr                   ( flt_hdr_i                 ),
    .log_hdr_size              ( hdr_size_i                ),
    .log_hdr_prfx              ( int_log_hdr_prfx          )
  );







delay_n_w_stalling
 #(
    .N  ( 1'b1              ),
    .CAN_STALL ( 1'b0       ),
    .WD ( 32*CX_MAX_HDR_LOG_SZ
        + PF_WD
        + 1 // Flit Mode
        + CX_MAX_HDR_LOG_PW // hdr_size
        + 5 // err_idx 
        + 1 // func_specific_err
        + 2 // fc
        + 1 // hdr_log_valid
        )
) u_delay_out(
    .clk      ( core_clk        ),
    .rst_n    ( core_rst_n      ),
    .clear    ( 1'b0            ),
    .stall    ( 1'b0            ),
    .stallout (                 ),
    .din      ( {func_specific_err_i, fc_i, err_idx_i, hdr_size_i, flit_mode_picked, int_hdr_pf  ,int_log_hdr_prfx  , int_log_valid   }    ),
    .dout     ( {func_specific_err_d, fc_d, err_idx_d, hdr_size_d, flit_mode_d     , int_hdr_pf_d,int_log_hdr_prfx_d, int_log_valid_d }    )
);


always_comb begin
    log_hdr_prfx      = int_log_hdr_prfx_d ;
    fc                = fc_d ;
    err_idx           = err_idx_d ;
    func_specific_err = func_specific_err_d ;
    log_valid         = int_log_valid_d ; 
    hdr_size          = hdr_size_d ;
    flit_mode_out     = flit_mode_d ;
    hdr_pf            = int_hdr_pf_d ;
end

//----- Header LOG IDLE LOGIC -----//

assign hdr_log_idle_i   = &empty_signal  ; // Used to signal out that no header is stored in fifos anymore 

delay_n
 #(
.N  ( 1'b1  ),
.WD ( 1     )
) u_idle_delay (
    .clk   ( core_clk        ),
    .rst_n ( core_rst_n      ),
    .clear ( 1'b0            ),
    .din   ( hdr_log_idle_i  ),
    .dout  ( hdr_log_idle_d  )
);




endmodule
