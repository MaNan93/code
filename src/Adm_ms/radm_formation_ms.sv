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
// --   RCS information:
// ---    $DateTime: 2023/10/19 08:40:05 $
// ---    $Revision: #5 $
// ---    $Id: //dwh/pcie_iip/main/fairbanks/design/Adm_ms/radm_formation_ms.sv#5 $
// -------------------------------------------------------------------------
// -----------------------------------------------------------------------------
// --- Module Description:
// -----------------------------------------------------------------------------
// 
// - Module instances the three formation queue one each per FC type.
// - Module manages the routing of the input QDWs to respective queues based on type of QDW.
//
// -----------------------------------------------------------------------------
`include "include/DWC_pcie_ctl_all_defs.svh"
`include "products/pcie_pkg.svh"
`include "DWC_pcie_ctl_pkg.svh"
`include "products/DWC_pcie_core_pkg.svh"
`include "Adm_ms/radm_ms_pkg.svh"

module  radm_formation_ms
  import pcie_pkg::E_P;
  import pcie_pkg::E_NP;
  import pcie_pkg::E_CPL;
  import DWC_pcie_ctl_pkg::NW;
  import DWC_pcie_ctl_pkg::DW;
  import DWC_pcie_ctl_pkg::DCA_WD;
  import DWC_pcie_core_pkg::RX_NQDW;
  import DWC_pcie_core_pkg::QDW_DW;
  import DWC_pcie_core_pkg::QDW_PAR;
  import DWC_pcie_ctl_pkg::ras_dp_err_log_t;
  import DWC_pcie_ctl_pkg::ras_dp_err_inj_t;
  import radm_ms_pkg::radm_form_s;
  import radm_ms_pkg::NQW;
  import radm_ms_pkg::NQW_R;
  import radm_ms_pkg::NHW;
  import radm_ms_pkg::PKT_ORD_WD;
  import radm_ms_pkg::HW;
  import radm_ms_pkg::RADM_HDR_PROT_WD;
#(
  /////////////////////////////////////////////////
  // parameter override from top file.
  //
  /////////////////////////////////////////////////
  parameter DATA_PROT_WD        = `TRGT_DATA_PROT_WD,
  parameter RAS_DP_PROT_CHK_ID_BASE  = 0,
  parameter FORMQ_RD_PORTS      = `CX_RADM_FORMQ_N_READ_PORT_VC,
  parameter RAM_WD_P            = `RAM_WD_VC0_P,
  parameter RAM_DP_P            = `RAM_DP_VC0_P,
  parameter RAM_PW_P            = `RAM_PW_VC0_P ,
  parameter RAM_WD_NP           = `RAM_WD_VC0_NP,
  parameter RAM_DP_NP           = `RAM_DP_VC0_NP,
  parameter RAM_PW_NP           = `RAM_PW_VC0_NP,
  parameter RAM_WD_CPL          = `RAM_WD_VC0_CPL,
  parameter RAM_DP_CPL          = `RAM_DP_VC0_CPL,
  parameter RAM_PW_CPL          = `RAM_PW_VC0_CPL
)

                           (
  //--------------------- inputs --------------------------------------------
  input   [RX_NQDW-1:0][QDW_DW+QDW_PAR-1:0]              hdec_form_nqdw_data,          // Generic data qdword (prefix/hdr/payload) of TLP packet
  input   [RX_NQDW-1:0][4-1:0]                           hdec_form_nqdw_ddwen,         // Dword enable of the data bus
  input   [RX_NQDW-1:0][4-1:0]                           hdec_form_nqdw_hdwen,         // Dword enable of the header bus
  input   [RX_NQDW-1:0]                                  hdec_form_nqdw_hv_p,          // Header is valid in this qdword
  input   [RX_NQDW-1:0]                                  hdec_form_nqdw_dv_p,          // Payload is valid in this qdword
  input   [RX_NQDW-1:0]                                  hdec_form_nqdw_eot_p,         // End of TLP indication
  input   [RX_NQDW-1:0]                                  hdec_form_nqdw_hv_np,         // Header is valid in this qdword
  input   [RX_NQDW-1:0]                                  hdec_form_nqdw_dv_np,         // Payload is valid in this qdword
  input   [RX_NQDW-1:0]                                  hdec_form_nqdw_eot_np,        // End of TLP indication
  input   [RX_NQDW-1:0]                                  hdec_form_nqdw_hv_cpl,        // Header is valid in this qdword
  input   [RX_NQDW-1:0]                                  hdec_form_nqdw_dv_cpl,        // Payload is valid in this qdword
  input   [RX_NQDW-1:0]                                  hdec_form_nqdw_eot_cpl,       // End of TLP indication
  input   [RX_NQDW-1:0]                                  hdec_form_nqdw_dllp_err,      // Indicates current packet should be dropped because of DLLP layer err
  input   [RX_NQDW-1:0]                                  hdec_form_nqdw_fm_poisoned,   // Indicates last tlp ends with poisoned flit marker
  input   [RX_NQDW-1:0]                                  hdec_form_nqdw_fm_nullified,  // Indicates last tlp ends with nullified flit marker
  input   [RX_NQDW-1:0][PKT_ORD_WD-1:0]                  hdec_form_p_pkt_order_num,
  input   [RX_NQDW-1:0]                                  hdec_form_prefix_qdw,    
  input   [2:0]                                          hdec_form_discard_prefixes, 
  input   [RX_NQDW-1:0]                                  hdec_form_mac_ecrc_qdw,       // mac/pcrc or ECRC only QDW.  
  

  //----------------------outputs -------------------------------------------
  // Dual port memory interface signals
  output  [NQW*RAM_PW_P-1:0]                             radm_formqram_addra_p,        // RAM write address
  output  [NQW-1:0]                                      radm_formqram_ena_p,          // RAM enable A
  output  [NQW-1:0]                                      radm_formqram_wea_p,          // RAM write enable A
  output  [NQW*RAM_WD_P-1:0]                             radm_formqram_dina_p,         // RAM write data A
  output  [NQW*RAM_PW_P-1:0]                             radm_formqram_addrb_p,        // RAM read address B
  output  [NQW-1:0]                                      radm_formqram_enb_p,          // RAM enable B
  input   [NQW*RAM_WD_P-1:0]                             formqram_radm_doutb_p,        // RAM read data B

  output  [NQW*RAM_PW_NP-1:0]                            radm_formqram_addra_np,       // RAM write address
  output  [NQW-1:0]                                      radm_formqram_ena_np,         // RAM enable A
  output  [NQW-1:0]                                      radm_formqram_wea_np,         // RAM write enable A
  output  [NQW*RAM_WD_NP-1:0]                            radm_formqram_dina_np,        // RAM write data A
  output  [NQW*RAM_PW_NP-1:0]                            radm_formqram_addrb_np,       // RAM read address B
  output  [NQW-1:0]                                      radm_formqram_enb_np,         // RAM enable B
  input   [NQW*RAM_WD_NP-1:0]                            formqram_radm_doutb_np,       // RAM read data B

  output  [NQW*RAM_PW_CPL-1:0]                           radm_formqram_addra_cpl,      // RAM write address
  output  [NQW-1:0]                                      radm_formqram_ena_cpl,        // RAM enable A
  output  [NQW-1:0]                                      radm_formqram_wea_cpl,        // RAM write enable A
  output  [NQW*RAM_WD_CPL-1:0]                           radm_formqram_dina_cpl,       // RAM write data A
  output  [NQW*RAM_PW_CPL-1:0]                           radm_formqram_addrb_cpl,      // RAM read address B
  output  [NQW-1:0]                                      radm_formqram_enb_cpl,        // RAM enable Buu
  input   [NQW*RAM_WD_CPL-1:0]                           formqram_radm_doutb_cpl,      // RAM read data B

  //----------------------filter interface signals---------------------------
  output  radm_form_s [2:0][FORMQ_RD_PORTS-1:0]          rxq_tlp,                      // FormationQ TLP interface
  input               [2:0]                              outqmgr_form_halt,            // Halt signals

  output  [FORMQ_RD_PORTS-1:0]                           radm_rtlh_h_ca_p,             // Credit allocated (header)
  output  [FORMQ_RD_PORTS-1:0]                           radm_rtlh_h_ca_np,            // Credit allocated (header)
  output  [FORMQ_RD_PORTS-1:0]                           radm_rtlh_h_ca_cpl,           // Credit allocated (header)
  output  [DCA_WD-1:0]                                   radm_rtlh_d_ca_p,             // Credit allocated (data)
  output  [DCA_WD-1:0]                                   radm_rtlh_d_ca_np,            // Credit allocated (data)
  output  [DCA_WD-1:0]                                   radm_rtlh_d_ca_cpl,           // Credit allocated (data)
  
  output                                                 radm_formq_overflow_p, 
  output                                                 radm_formq_overflow_np, 
  output                                                 radm_formq_overflow_cpl, 

  output ras_dp_err_log_t                                ras_dp_err_log,
  output logic                  [9:0]                    out_ras_dp_wake_up,
  input  ras_dp_err_inj_t                                ras_dp_err_inj,
  input                                                  flit_mode_en,
  input                                                  radm_clk_ug,
  input                                                  core_clk,
  input                                                  core_rst_n
);

 


logic   [RX_NQDW-1:0][PKT_ORD_WD-1:0]                  hdec_form_p_pkt_order_num_p;

localparam  N_FC                 = 3;                 // 3 FC per VC
localparam  N_FC_CHK             = 3;                 // 3 checkers per FC
localparam  N_RADM_FORMQ_FCS_CKH = N_FC*N_FC_CHK;     // total checkers 
localparam  RAS_DP_PROT_CHK_ID_BASE_P   = 0*(2*NQW+NQW_R) + RAS_DP_PROT_CHK_ID_BASE;
localparam  RAS_DP_PROT_CHK_ID_BASE_NP  = 1*(2*NQW+NQW_R) + RAS_DP_PROT_CHK_ID_BASE_P;
localparam  RAS_DP_PROT_CHK_ID_BASE_CPL = 1*(2*NQW+NQW_R) + RAS_DP_PROT_CHK_ID_BASE_NP;

ras_dp_err_inj_t                    ras_dp_err_inj_formq;

ras_dp_err_log_t  [N_FC_CHK-1:0]    ras_dp_err_log_p;
ras_dp_err_log_t  [N_FC_CHK-1:0]    ras_dp_err_log_np;
ras_dp_err_log_t  [N_FC_CHK-1:0]    ras_dp_err_log_cpl;

logic             [2:0]             p_out_ras_dp_wake_up;
logic             [2:0]             np_out_ras_dp_wake_up;
logic             [2:0]             cpl_out_ras_dp_wake_up;

assign out_ras_dp_wake_up[8:0] = {cpl_out_ras_dp_wake_up, np_out_ras_dp_wake_up, p_out_ras_dp_wake_up};
ras_dp_err_mgr
 #(
    .BLOCK_RAS_DP_PROT_CHK_N         (N_RADM_FORMQ_FCS_CKH),
    .CAN_RECEIVE_LONG_ERR_LOG_FORMAT (1)
) u_ras_dp_err_mgr_formation (
    .clk                (core_clk),
    .rst_n              (core_rst_n),
    .out_ras_dp_wake_up (out_ras_dp_wake_up[9]),
    .in_ras_dp_err_inj  (ras_dp_err_inj),
    .out_ras_dp_err_inj (ras_dp_err_inj_formq),
    .in_ras_dp_err_log  ({ras_dp_err_log_cpl, ras_dp_err_log_np, ras_dp_err_log_p }),
    .out_ras_dp_err_log (ras_dp_err_log)
);

always_comb begin
  for(int i=0; i<RX_NQDW ; i++) begin
    // P pkt value comes incremental with EOT if no DLLP error. So no increment in this case.
    if(hdec_form_nqdw_eot_p[i] && !hdec_form_nqdw_dllp_err[i] && !hdec_form_nqdw_fm_nullified[i])
      hdec_form_p_pkt_order_num_p[i] = hdec_form_p_pkt_order_num[i];
    else
      // We need to mark P PKTs with starting number 1 so increment by 1.
      hdec_form_p_pkt_order_num_p[i] = hdec_form_p_pkt_order_num[i] + 1'b1;
  end
end   
  
// Formation queue instance for P TLP TYPE
radm_formation_queue_ms
 
  #(   
    .RAS_DP_PROT_CHK_ID_BASE (RAS_DP_PROT_CHK_ID_BASE_P),
    .RAM_WD(RAM_WD_P),
   .RAM_WD_NO_ECC(`RAM_WD_VC0_P_NO_ECC),
   .RAM_DP(RAM_DP_P),
   .RAM_PW(RAM_PW_P)
   ) u_radm_formation_queue_p
   (
  .core_clk                          (core_clk                         ),
  .radm_clk_ug                       (radm_clk_ug                      ),
  .core_rst_n                        (core_rst_n                       ),
  .flit_mode_en                      (flit_mode_en                     ),  
  .hdec_form_nqdw_data               (hdec_form_nqdw_data              ),        
  .hdec_form_nqdw_ddwen              (hdec_form_nqdw_ddwen             ),         
  .hdec_form_nqdw_hdwen              (hdec_form_nqdw_hdwen             ),       
  .hdec_form_nqdw_hv                 (hdec_form_nqdw_hv_p              ),          
  .hdec_form_nqdw_dv                 (hdec_form_nqdw_dv_p              ),          
  .hdec_form_nqdw_eot                (hdec_form_nqdw_eot_p             ),         
  .hdec_form_nqdw_dllp_err           (hdec_form_nqdw_dllp_err          ),  
  .hdec_form_nqdw_fm_poisoned        (hdec_form_nqdw_fm_poisoned       ),
  .hdec_form_nqdw_fm_nullified       (hdec_form_nqdw_fm_nullified      ),
  .hdec_form_p_pkt_order_num         (hdec_form_p_pkt_order_num_p        ),  
  .hdec_form_prefix_qdw              (hdec_form_prefix_qdw             ),
  .hdec_form_discard_prefixes        (hdec_form_discard_prefixes[0]    ), 
  .hdec_form_mac_ecrc_qdw            (hdec_form_mac_ecrc_qdw),            
  
  .radm_formqram_addra               (radm_formqram_addra_p            ),         
  .radm_formqram_ena                 (radm_formqram_ena_p              ),           
  .radm_formqram_wea                 (radm_formqram_wea_p              ),           
  .radm_formqram_dina                (radm_formqram_dina_p             ),          
  .radm_formqram_addrb               (radm_formqram_addrb_p            ),         
  .radm_formqram_enb                 (radm_formqram_enb_p              ),           
  .formqram_radm_doutb               (formqram_radm_doutb_p            ),         

  .rxq_tlp                           (rxq_tlp[E_P]                     ),
  .filt_form_halt_en                 (outqmgr_form_halt[E_P]           ),     

  .dllp_error_pkt_drop_en            (1'b1                             ),  
  .radm_rtlh_h_ca                    (radm_rtlh_h_ca_p                 ),              
  .radm_rtlh_d_ca                    (radm_rtlh_d_ca_p                 ),
  .radm_formq_overflow_ms            (radm_formq_overflow_p            )
  ,
  .ras_dp_err_log                    (ras_dp_err_log_p                 ),
  .out_ras_dp_wake_up                (p_out_ras_dp_wake_up             )
  ,
  .ras_dp_err_inj                    (ras_dp_err_inj_formq             )

);

// Formation queue instance for NP TLP TYPE   
radm_formation_queue_ms
 
  #(   
    .RAS_DP_PROT_CHK_ID_BASE (RAS_DP_PROT_CHK_ID_BASE_NP),
   .RAM_WD(RAM_WD_NP),
   .RAM_WD_NO_ECC(`RAM_WD_VC0_NP_NO_ECC),
   .RAM_DP(RAM_DP_NP),
   .RAM_PW(RAM_PW_NP)
   ) u_radm_formation_queue_np

   (
  .core_clk                          (core_clk                         ),
  .radm_clk_ug                       (radm_clk_ug                      ),
  .core_rst_n                        (core_rst_n                       ),
  .flit_mode_en                      (flit_mode_en                     ),  
  .hdec_form_nqdw_data               (hdec_form_nqdw_data              ),        
  .hdec_form_nqdw_ddwen              (hdec_form_nqdw_ddwen             ),         
  .hdec_form_nqdw_hdwen              (hdec_form_nqdw_hdwen             ),       
  .hdec_form_nqdw_hv                 (hdec_form_nqdw_hv_np             ),          
  .hdec_form_nqdw_dv                 (hdec_form_nqdw_dv_np             ),          
  .hdec_form_nqdw_eot                (hdec_form_nqdw_eot_np            ),         
  .hdec_form_nqdw_dllp_err           (hdec_form_nqdw_dllp_err          ),    
    .hdec_form_nqdw_fm_poisoned      (hdec_form_nqdw_fm_poisoned       ),
    .hdec_form_nqdw_fm_nullified     (hdec_form_nqdw_fm_nullified      ),
  .hdec_form_p_pkt_order_num         (hdec_form_p_pkt_order_num        ),  
  .hdec_form_prefix_qdw              (hdec_form_prefix_qdw             ),
  .hdec_form_discard_prefixes        (hdec_form_discard_prefixes[1]    ), 
  .hdec_form_mac_ecrc_qdw            (hdec_form_mac_ecrc_qdw),            
  
  .radm_formqram_addra               (radm_formqram_addra_np           ),         
  .radm_formqram_ena                 (radm_formqram_ena_np             ),           
  .radm_formqram_wea                 (radm_formqram_wea_np             ),           
  .radm_formqram_dina                (radm_formqram_dina_np            ),          
  .radm_formqram_addrb               (radm_formqram_addrb_np           ),         
  .radm_formqram_enb                 (radm_formqram_enb_np             ),           
  .formqram_radm_doutb               (formqram_radm_doutb_np           ),         

  .rxq_tlp                           (rxq_tlp[E_NP]                    ),
  .filt_form_halt_en                 (outqmgr_form_halt[E_NP]          ),   

  .dllp_error_pkt_drop_en            (1'b1                             ),  
  .radm_rtlh_h_ca                    (radm_rtlh_h_ca_np                ),              
  .radm_rtlh_d_ca                    (radm_rtlh_d_ca_np                ),             
  .radm_formq_overflow_ms            (radm_formq_overflow_np           )
  ,
  .ras_dp_err_log                    (ras_dp_err_log_np                ),
  .out_ras_dp_wake_up                (np_out_ras_dp_wake_up            )
  ,
  .ras_dp_err_inj                    (ras_dp_err_inj_formq             )
);

// Formation queue instance for CPL TLP TYPE
radm_formation_queue_ms
 
  #(   
    .RAS_DP_PROT_CHK_ID_BASE (RAS_DP_PROT_CHK_ID_BASE_CPL),
   .RAM_WD(RAM_WD_CPL),
   .RAM_WD_NO_ECC(`RAM_WD_VC0_CPL_NO_ECC),
   .RAM_DP(RAM_DP_CPL),
   .RAM_PW(RAM_PW_CPL)
   ) u_radm_formation_queue_cpl
   (
  .core_clk                          (core_clk                         ),
  .radm_clk_ug                       (radm_clk_ug                      ),
  .core_rst_n                        (core_rst_n                       ),
  .flit_mode_en                      (flit_mode_en                     ),  
  .hdec_form_nqdw_data               (hdec_form_nqdw_data              ),        
  .hdec_form_nqdw_ddwen              (hdec_form_nqdw_ddwen             ),         
  .hdec_form_nqdw_hdwen              (hdec_form_nqdw_hdwen             ),       
  .hdec_form_nqdw_hv                 (hdec_form_nqdw_hv_cpl            ),          
  .hdec_form_nqdw_dv                 (hdec_form_nqdw_dv_cpl            ),          
  .hdec_form_nqdw_eot                (hdec_form_nqdw_eot_cpl           ),         
  .hdec_form_nqdw_dllp_err           (hdec_form_nqdw_dllp_err          ),    
  .hdec_form_nqdw_fm_poisoned        (hdec_form_nqdw_fm_poisoned       ),
  .hdec_form_nqdw_fm_nullified       (hdec_form_nqdw_fm_nullified      ),
  .hdec_form_p_pkt_order_num         (hdec_form_p_pkt_order_num        ),  
  .hdec_form_prefix_qdw              (hdec_form_prefix_qdw             ),
  .hdec_form_discard_prefixes        (hdec_form_discard_prefixes[2]    ), 
  .hdec_form_mac_ecrc_qdw            (hdec_form_mac_ecrc_qdw           ),        
  
  .radm_formqram_addra               (radm_formqram_addra_cpl          ),         
  .radm_formqram_ena                 (radm_formqram_ena_cpl            ),           
  .radm_formqram_wea                 (radm_formqram_wea_cpl            ),           
  .radm_formqram_dina                (radm_formqram_dina_cpl           ),          
  .radm_formqram_addrb               (radm_formqram_addrb_cpl          ),         
  .radm_formqram_enb                 (radm_formqram_enb_cpl            ),           
  .formqram_radm_doutb               (formqram_radm_doutb_cpl          ),         

  .rxq_tlp                           (rxq_tlp[E_CPL]                   ),
  .filt_form_halt_en                 (outqmgr_form_halt[E_CPL]         ),     

  .dllp_error_pkt_drop_en            (1'b1                             ),  
  .radm_rtlh_h_ca                    (radm_rtlh_h_ca_cpl               ),              
  .radm_rtlh_d_ca                    (radm_rtlh_d_ca_cpl               ),             
  .radm_formq_overflow_ms            (radm_formq_overflow_cpl          )
  ,
  .ras_dp_err_log                    (ras_dp_err_log_cpl               ),
  .out_ras_dp_wake_up                (cpl_out_ras_dp_wake_up           )
  ,
  .ras_dp_err_inj                    (ras_dp_err_inj_formq             )
);

endmodule
