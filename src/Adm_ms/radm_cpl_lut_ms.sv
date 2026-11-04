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
// ---    $Revision: #10 $
// ---    $Id: //dwh/pcie_iip/main/fairbanks/design/Adm_ms/radm_cpl_lut_ms.sv#10 $
// -------------------------------------------------------------------------
`include "include/DWC_pcie_ctl_all_defs.svh"
`include "DWC_pcie_ctl_pkg.svh"
`include "products/DWC_pcie_core_pkg.svh"
`include "Adm_ms/radm_ms_pkg.svh"

module radm_cpl_lut_ms
  import DWC_pcie_ctl_pkg::TAG_SIZE;
  import DWC_pcie_ctl_pkg::NF;
  import DWC_pcie_ctl_pkg::NVF;
  import DWC_pcie_ctl_pkg::NVC;
  import DWC_pcie_ctl_pkg::PF_WD;
  import DWC_pcie_ctl_pkg::VFI_WD;
  import DWC_pcie_ctl_pkg::VF_WD;
  import DWC_pcie_ctl_pkg::TP;
  import DWC_pcie_ctl_pkg::BUSNUM_WD;
  import DWC_pcie_ctl_pkg::DEVNUM_WD;  
  import DWC_pcie_ctl_pkg::NP_REQ_TX_TYPE_WD;
  import DWC_pcie_core_pkg::xadm_radm_tx_npr_t;
  import radm_ms_pkg::CPL_LUT_PTR_WD;
  import radm_ms_pkg::CPL_LUT_FRAG_DEPTH;
  import radm_ms_pkg::NFRAG;
  import radm_ms_pkg::INT_NVF;
  import radm_ms_pkg::CPL_ENTRY_WIDTH;  
  // ## CPL_LUT2 ##
  import radm_ms_pkg::CPL_ENTRY_WIDTH2;        
  import radm_ms_pkg::N_FLT_MASK;
  import radm_ms_pkg::RTLH_RADM_RID_WD;  
  import radm_ms_pkg::TIMEOUT_GRANULARITY;
  import radm_ms_pkg::HW;
  import radm_ms_pkg::RADM_HDR_PROT_WD;
  import radm_ms_pkg::CPL_LUT_DEPTH_EXTERNAL;
  import radm_ms_pkg::N_RADM_CPL_TLP;
  import radm_ms_pkg::N_XADM_RADM_TX_NPR_IF;
  import radm_ms_pkg::FUNC_NUM_INDEX;

                        (
  ///////////////////// inputs  //////////////////////
  input                                              core_clk,                   // Core clock
  input                                              radm_clk_ug,                // ungated radm clock used to clock through anticipated RID in the radm cpl filter
  input                                              core_rst_n,
  input                                              rstctl_core_flush_req,
  input   [N_FLT_MASK-1:0]                           cfg_filter_rule_mask,       // "static"// PL reg outputs to control the selection of filter rules that are designed in radm_filter*
  input   [DEVNUM_WD -1:0]                           cfg_pbus_dev_num,           // "static" // Device number
  input   [BUSNUM_WD -1:0]                           cfg_pbus_num,               // "static" // Bus number
  input                                              cfg_p2p_track_cpl_to,       // 0: bydefault, do not track cpl in lut for P2P; 1: track cpl in lut for P2P.
  input                                              cfg_p2p_err_rpt_ctrl,       // 1: bydefault, P2P error reporting enable; 0: P2P error reporting disable.
  input   [3:0]                                      tag_bits_13_to_10,          // tag bit input for bit 13 down to 10.
  input   [3:0]                                      device_type,                // "static"
  input                                              cdm_dpc_triggered,          // DPC has been triggered indication
  input                                              cdm_core_in_dpc,            // Core is in Downstream Port Containment mode.
  input                                              cfg_dpc_cpl_cntrl,          // DPC CPL control bit from CDM. To redirect poison err to UR/CA     
  /////////// completion packet signals //////////////
  input   [N_RADM_CPL_TLP-1:0][TAG_SIZE-1:0]         cpl_tlp_ant_tag,         // CPL TLP one clock cycle Early TAG 
  input   [N_RADM_CPL_TLP-1:0][3-1:0]                filt_lut_cpl_status,
  input   [N_RADM_CPL_TLP-1:0]                       filt_lut_dwlenEq0,

  input   [N_RADM_CPL_TLP-1:0]                       filt_lut_hv,               // When asserted; indicates the hdr valid
  input   [N_RADM_CPL_TLP-1:0][(HW+RADM_HDR_PROT_WD)-1:0] filt_lut_hdr,               // hdr payload
  input   [N_RADM_CPL_TLP-1:0]                       filt_lut_eot,              // When asserted; indicates the tlp end
  input   [N_RADM_CPL_TLP-1:0]                       filt_lut_dllp_err,         // Indication that TLP has dllp err (valid @ EOT)


  input   [N_RADM_CPL_TLP-1:0]                       filt_lut_malform_tlp_err,  // Indication that TLP is malformed (valid @ HV)
  input   [N_RADM_CPL_TLP-1:0]                       filt_lut_ecrc_err,         // Indication that TLP has ECRC err (valid @ EOT)
  input   [NVC-1:0]                                  filt_lut_ant_formation,
  input   [N_RADM_CPL_TLP-1:0]                       filt_lut_ant_hv,
  input   [NVC-1:0]                                  filt_lut_formation,        // Leading queue indication from radm_formation


  /////////// transmitted NP TLP inputs /////////////
  input   xadm_radm_tx_npr_t                         xadm_radm_tx_npr,

  /////////// CPL TLP Status signals ////////////////
  output  [N_RADM_CPL_TLP-1:0]                       lut_filt_vendor_msg_id_match,
  output  [N_RADM_CPL_TLP-1:0]                       lut_filt_cpl_abort,
  output  [N_RADM_CPL_TLP-1:0]                       lut_filt_cpl_last,
  output  [N_RADM_CPL_TLP-1:0]                       lut_filt_cpl_mlf_err,
  output  [N_RADM_CPL_TLP-1:0]                       lut_filt_cpl_ur_err,
  output  [N_RADM_CPL_TLP-1:0]                       lut_filt_cpl_ca_err,
  output  [N_RADM_CPL_TLP-1:0]                       lut_filt_unexpected_cpl_err,
  output  [N_RADM_CPL_TLP-1:0][NP_REQ_TX_TYPE_WD-1:0]np_req_type,
  output                                             cpl_trgt_interface_no,
  //////////////////////// timer block signals//////////////////////
  input   [(4*NF)-1:0]                               cfg_cpl_timeout_range,      // "static" // Completion timeout ranges
  input   [NF-1:0]                                   cfg_cpl_timeout_disable,    // "static" // Completion timeout disable
  input                                              xtlh_np_tlp_early,          // an early indication from layer3 that a NP TLP has been sent
  input   [2:0]                                      current_data_rate,          // "static" // 0=running at gen1 rate, 1=running at gen2 rate, 2-gen3, 3-gen4

  output  [NF-1:0]                                   radm_cpl_pending,
  output                                             radm_cpl_lut_busy,          // CPL LUT busy indication
  output                                             radm_cpl_timeout,
  output                                             radm_cpl_timeout_cdm,       // Same information as radm_cpl_timeout but without the timeout tags flr'ed
  output  [2:0]                                      radm_timeout_cpl_tc,        // not used
  output  [2:0]                                      radm_timeout_cpl_attr,      // not used
  output  [TAG_SIZE-1:0]                             radm_timeout_cpl_tag,
  output  [PF_WD-1:0]                                radm_timeout_func_num,
  output  [11:0]                                     radm_timeout_cpl_len,
  output  logic [6:0]                                radm_timeout_low_addr,
  output  logic [NP_REQ_TX_TYPE_WD-1:0]              radm_timeout_np_req_type,  

  output  [CPL_LUT_DEPTH_EXTERNAL-1:0]               radm_cpl_lut_valid,            // completion lookup table valid indication
  
  output                                             radm_cpl_lut_pending        // pending flag for the radm cpl lut

  );

  localparam     FLIT_PREFIX = 3'b100;
  //////////////////////////////////////////////////////////////////////
  // Local wires and registers
  logic   [N_RADM_CPL_TLP-1:0]                       cpl_last_pipe;
  logic   [CPL_ENTRY_WIDTH-1:0]                      cpl_lut_error_vec;     // LUT vec  output based on the timeout address value to present it to the application. 
  logic   [CPL_ENTRY_WIDTH2-1:0]                     cpl_lut_error_vec2;    // LUT vec2 output based on the timeout address value to present it to the application. 
  logic   [N_RADM_CPL_TLP-1:0]                       cpl_lut_valid;         // Valid indication for each early tags of the CPL TLPs. 
  logic                                              cpl_lut_error_valid;   // Valid output based on the timeout address register value. 
  logic                                              flr_reset;
  logic                                              timer_freq;
  logic   [PF_WD-1:0]                                timeout_pf;
  logic   [NF-1:0]                                   func_timeout;
  logic                                              timer_expired_incr;
  logic                                              timeout_error;
  logic   [CPL_LUT_PTR_WD-1:0]                       timeout_addr;
  logic   [CPL_LUT_PTR_WD-1:0]                       timeout_addr_reg;
  logic   [N_RADM_CPL_TLP-1:0][CPL_ENTRY_WIDTH-1:0]  cpl_lut_vec;
  logic   [N_RADM_CPL_TLP-1:0][CPL_ENTRY_WIDTH2-1:0] cpl_lut2_vec;
  logic   [N_RADM_CPL_TLP-1:0]                       update_lut_content_pipe;
  logic   [N_RADM_CPL_TLP-1:0][CPL_LUT_PTR_WD-1:0]   update_lut_addr_pipe;  
  logic   [N_RADM_CPL_TLP-1:0][CPL_ENTRY_WIDTH2-1:0] update_lut_byte_cnt_pipe; 
  logic   [N_XADM_RADM_TX_NPR_IF-1:0][TAG_SIZE-1:0]           xtlh_xmt_tlp_tag;           // transmitted TLP tag
  logic   [N_XADM_RADM_TX_NPR_IF-1:0][TAG_SIZE-1:0]           xtlh_xmt_tlp_tag_mapped; 
  logic   [N_XADM_RADM_TX_NPR_IF-1:0][CPL_LUT_PTR_WD-1:0]     int_xtlh_xmt_tlp_tag;
  logic   [N_RADM_CPL_TLP-1:0][CPL_LUT_PTR_WD-1:0]   int_cpl_tlp_ant_tag;  
  logic                                              cpl_lut_empty;
  logic   [TIMEOUT_GRANULARITY-1:0]                  cpl_lut_pertag_timer_value;  



  logic  [NFRAG*CPL_LUT_FRAG_DEPTH-1:0]              radm_cpl_lut_valid_int;            // completion lookup table valid indication

  logic [N_XADM_RADM_TX_NPR_IF-1:0]                           int_update_lut_d;                   // radm_cpl_pending logic(at timer)
  logic [N_XADM_RADM_TX_NPR_IF-1:0][FUNC_NUM_INDEX-1:0]       lutin_func_num_d;                   // radm_cpl_pending logic(at timer)
  logic                                                       or_valid;

  assign or_valid           = |radm_cpl_lut_valid_int; // [NFRAG*CPL_LUT_FRAG_DEPTH-1:0]
 
  assign radm_cpl_lut_valid = radm_cpl_lut_valid_int[CPL_LUT_DEPTH_EXTERNAL-1:0]; 

  //////////////////////////////////////////////////
  // TX TAG mapping based on config.  
  //
  //////////////////////////////////////////////////
  always_comb begin
    for(int i=0;i<N_XADM_RADM_TX_NPR_IF;i=i+1) begin
      xtlh_xmt_tlp_tag[i] = xadm_radm_tx_npr.tag[i];
    end
  end

  // tag size is 14bit but we do not enable 14bit requester capability while LUT size is less than 1K. Only 10/8 bit requester capabilities are enabled.
  logic  [N_XADM_RADM_TX_NPR_IF-1:0] xtlh_xmt_14bit_tag;
  always_comb begin
    for(int i=0;i<N_XADM_RADM_TX_NPR_IF;i=i+1) begin
      xtlh_xmt_14bit_tag[i] = |xtlh_xmt_tlp_tag[i][13:8];
      xtlh_xmt_tlp_tag_mapped[i][7:0]  =  xtlh_xmt_tlp_tag[i][7:0];
      xtlh_xmt_tlp_tag_mapped[i][13:8] =  xtlh_xmt_14bit_tag[i] ? (xtlh_xmt_tlp_tag[i][13:8]- 6'h01) : 6'h00;
    end
  end
  ///////////////////////////////////////////////////////////////////
  // CPL TAG mapping based on config.  
  //
  ///////////////////////////////////////////////////////////////////
  logic   [N_XADM_RADM_TX_NPR_IF-1:0][TAG_SIZE-1:0]           cpl_tlp_ant_tag_mapped; 

  // tag size is 14bit but we do not enable 14bit requester capability while LUT size is less than 1K. Only 10/8 bit requester capabilities are enabled.
  logic  [N_XADM_RADM_TX_NPR_IF-1:0] cpl_tlp_14bit_tag;
  always_comb begin
    for(int i=0;i<N_XADM_RADM_TX_NPR_IF;i=i+1) begin
      cpl_tlp_14bit_tag[i] = |cpl_tlp_ant_tag[i][13:8];
      cpl_tlp_ant_tag_mapped[i][7:0]  =  cpl_tlp_ant_tag[i][7:0];
      cpl_tlp_ant_tag_mapped[i][13:8] =  cpl_tlp_14bit_tag[i] ? (cpl_tlp_ant_tag[i][13:8]- 6'h01) : 6'h00;
    end
  end
  ///////////////////////////////////////////////
  /// Internal early TAG and CPL TLP tag mapping
  ///////////////////////////////////////////////
  always_comb begin
    for(int k=0;k<N_XADM_RADM_TX_NPR_IF;k=k+1) begin
      int_xtlh_xmt_tlp_tag[k] =  xtlh_xmt_tlp_tag_mapped[k][CPL_LUT_PTR_WD-1:0];
    end
  end

  always_comb begin
    for(int l=0;l<N_RADM_CPL_TLP;l=l+1) begin
       int_cpl_tlp_ant_tag[l] = cpl_tlp_ant_tag_mapped[l][CPL_LUT_PTR_WD-1:0];   
    end
  end


//////////////////////////////
// NP tlp information storage
//////////////////////////////
  radm_cpl_tlp_store
  
  u_radm_cpl_tlp_store(
 // ---- inputs ---------------
  .cfg_pbus_dev_num                           (cfg_pbus_dev_num          ),           // "static" // Device number
  .cfg_pbus_num                               (cfg_pbus_num              ),           // "static" // Bus number
  .xadm_radm_tx_npr                           (xadm_radm_tx_npr          ),
  .xtlh_xmt_tlp_tag                           (int_xtlh_xmt_tlp_tag      ),  
  
  .xtlh_xmt_14bit_tag                         (xtlh_xmt_14bit_tag        ), 
  .cfg_filter_rule_mask                       (cfg_filter_rule_mask      ),

  .cpl_last_pipe                              (cpl_last_pipe             ),   
  .update_lut_content_pipe                    (update_lut_content_pipe   ),    
  .update_lut_addr_pipe                       (update_lut_addr_pipe      ),       
  .update_lut_byte_cnt_pipe                   (update_lut_byte_cnt_pipe  ),   
  .timer_freq                                 (timer_freq                ),
  .func_timeout                               (func_timeout              ),

  .timeout_pf                                 (timeout_pf                ),
  .timer_expired_incr                         (timer_expired_incr        ),
  .timeout_error                              (timeout_error             ),        
  .timeout_addr                               (timeout_addr              ),           
  .timeout_addr_reg                           (timeout_addr_reg          ),          
  .rstctl_core_flush_req                      (rstctl_core_flush_req     ),
  .cpl_tlp_ant_tag                            (int_cpl_tlp_ant_tag       ),  

  //--------------------------Output Signals-------------------------
  .cpl_lut_vec                                (cpl_lut_vec               ),     
  .cpl_lut_error_vec                          (cpl_lut_error_vec         ),     
  .cpl_lut_vec2                               (cpl_lut2_vec              ),      
  .cpl_lut_error_vec2                         (cpl_lut_error_vec2        ),     
  .cpl_lut_valid                              (cpl_lut_valid             ),       
  .cpl_lut_error_valid                        (cpl_lut_error_valid       ),
  .cpl_lut_pertag_timer_value                 (cpl_lut_pertag_timer_value),  
  .cpl_lut_empty                              (cpl_lut_empty             ), 
  .radm_cpl_lut_valid                         (radm_cpl_lut_valid_int    ),
  .int_update_lut_d                           (int_update_lut_d          ), // out, to radm_cpl_lut_timer
  .lutin_func_num_d                           (lutin_func_num_d          ), // out, to radm_cpl_lut_timer

  .core_clk                                   (core_clk                  ),                  
  .core_rst_n                                 (core_rst_n                )                 
);

////////////////////////////////
// VC based cpl filter instances
////////////////////////////////
  radm_vc_cpl_filter
  
  u_radm_vc_cpl_filter[NVC-1:0]
  (  // ---- inputs ---------------
  .core_clk                                   (core_clk                  ),
  .core_rst_n                                 (core_rst_n                ),
  .cfg_filter_rule_mask                       (cfg_filter_rule_mask      ),       
  .cfg_pbus_dev_num                           (cfg_pbus_dev_num          ),           
  .cfg_pbus_num                               (cfg_pbus_num              ),               
  .cfg_p2p_track_cpl_to                       (cfg_p2p_track_cpl_to      ),       
  .cfg_p2p_err_rpt_ctrl                       (cfg_p2p_err_rpt_ctrl      ),       
  .tag_bits_13_to_10                          (tag_bits_13_to_10         ),    
  .filt_lut_cpl_status                        (filt_lut_cpl_status       ),
  .filt_lut_dwlenEq0                          (filt_lut_dwlenEq0         ),
  .filt_lut_hv                                (filt_lut_hv               ),               
  .filt_lut_hdr                               (filt_lut_hdr              ),              
  .filt_lut_eot                               (filt_lut_eot              ),              
  .filt_lut_dllp_err                          (filt_lut_dllp_err         ),
  .filt_lut_malform_tlp_err                   (filt_lut_malform_tlp_err  ),  
  .filt_lut_ecrc_err                          (filt_lut_ecrc_err         ),        


  .filt_lut_ant_formation                     (filt_lut_ant_formation    ),
  .filt_lut_ant_hv                            (filt_lut_ant_hv           ),
  .filt_lut_formation                         (filt_lut_formation        ),        
  .device_type                                (device_type               ),     
  .cdm_dpc_triggered                          (cdm_dpc_triggered         ),          
  .cdm_core_in_dpc                            (cdm_core_in_dpc           ),   
  .valid_at_lut_addr                          (cpl_lut_valid             ),          
  .cpl_lut_vec                                (cpl_lut_vec               ),
  .cpl_lut2_vec                               (cpl_lut2_vec              ),
  .lut_filt_vendor_msg_id_match               (lut_filt_vendor_msg_id_match),
  .lut_filt_cpl_abort                         (lut_filt_cpl_abort        ),
  .lut_filt_cpl_last                          (lut_filt_cpl_last         ),
  .lut_filt_cpl_mlf_err                       (lut_filt_cpl_mlf_err      ),
  .lut_filt_cpl_ur_err                        (lut_filt_cpl_ur_err       ),
  .lut_filt_cpl_ca_err                        (lut_filt_cpl_ca_err       ),
  .lut_filt_unexpected_cpl_err                (lut_filt_unexpected_cpl_err),
  .update_lut_content_pipe                    (update_lut_content_pipe   ),
  .update_lut_addr_pipe                       (update_lut_addr_pipe      ),  
  .update_lut_byte_cnt_pipe                   (update_lut_byte_cnt_pipe  ), 
  .lut_np_req_type_decoded                    (np_req_type               ),
  .cpl_trgt_interface_no                      (cpl_trgt_interface_no     ), 
  .cpl_last_pipe                              (cpl_last_pipe             )
 );


  radm_cpl_lut_timer
  
  u_radm_cpl_lut_timer
  (  // ---- inputs ---------------                            
  .core_clk                                   (core_clk                  ),
  .radm_clk_ug                                (radm_clk_ug               ),   
  .core_rst_n                                 (core_rst_n                ),
  .cfg_cpl_timeout_range                      (cfg_cpl_timeout_range     ),
  .cfg_cpl_timeout_disable                    (cfg_cpl_timeout_disable   ),  
  .xtlh_np_tlp_early                          (xtlh_np_tlp_early         ), 
  .current_data_rate                          (current_data_rate         ),          
  .int_update_lut_d                           (int_update_lut_d          ), // in, from radm_cpl_tlp_store
  .lutin_func_num_d                           (lutin_func_num_d          ), // in, from radm_cpl_tlp_store
  .or_valid                                   (or_valid                  ), // in, = |radm_cpl_lut_valid_int
  .radm_cpl_pending                           (radm_cpl_pending          ),
  .radm_cpl_lut_busy                          (radm_cpl_lut_busy         ),
  .radm_cpl_timeout                           (radm_cpl_timeout          ),
  .radm_cpl_timeout_cdm                       (radm_cpl_timeout_cdm      ),
  .radm_timeout_cpl_tc                        (radm_timeout_cpl_tc       ),
  .radm_timeout_cpl_attr                      (radm_timeout_cpl_attr     ),
  .radm_timeout_cpl_tag                       (radm_timeout_cpl_tag      ),
  .radm_timeout_func_num                      (radm_timeout_func_num     ),
  .radm_timeout_cpl_len                       (radm_timeout_cpl_len      ),
  .radm_timeout_low_addr                      (radm_timeout_low_addr     ),
  .radm_timeout_np_req_type                   (radm_timeout_np_req_type  ),

  .radm_cpl_lut_pending                       (radm_cpl_lut_pending      ),
  .cpl_lut_empty                              (cpl_lut_empty             ),
  .update_lut_addr_pipe                       (update_lut_addr_pipe      ),
  .update_lut_content_pipe                    (update_lut_content_pipe   ),
  .cpl_last_pipe                              (cpl_last_pipe             ),   
  .cpl_lut_error_vec                          (cpl_lut_error_vec         ),
  .cpl_lut_error_vec2                         (cpl_lut_error_vec2        ),
  .cpl_lut_error_valid                        (cpl_lut_error_valid       ) ,
  .cpl_lut_pertag_timer_value                 (cpl_lut_pertag_timer_value),  
  .timer_freq                                 (timer_freq                ),
  .timeout_pf                                 (timeout_pf                ),
  .func_timeout                               (func_timeout              ),
  .timer_expired_incr                         (timer_expired_incr        ),
  .timeout_error                              (timeout_error             ),        
  .timeout_addr                               (timeout_addr              ),           
  .timeout_addr_reg                           (timeout_addr_reg          )      
);

`ifndef SYNTHESIS
//VCS coverage off
//VCS coverage on
`endif // SYNTHESIS


endmodule  
