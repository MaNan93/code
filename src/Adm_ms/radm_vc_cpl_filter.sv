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
// ---    $DateTime: 2023/10/04 00:17:42 $
// ---    $Revision: #5 $
// ---    $Id: //dwh/pcie_iip/main/fairbanks/design/Adm_ms/radm_vc_cpl_filter.sv#5 $
// ------------------------------------------------------------------------- 
`include "include/DWC_pcie_ctl_all_defs.svh"
`include "DWC_pcie_ctl_pkg.svh"
`include "Adm_ms/radm_ms_pkg.svh"

  module radm_vc_cpl_filter
  import DWC_pcie_ctl_pkg::NF;
  import DWC_pcie_ctl_pkg::NVF;
  import DWC_pcie_ctl_pkg::PF_WD;
  import DWC_pcie_ctl_pkg::VFI_WD;
  import DWC_pcie_ctl_pkg::TP;
  import DWC_pcie_ctl_pkg::BUSNUM_WD;
  import DWC_pcie_ctl_pkg::DEVNUM_WD;  
  import DWC_pcie_ctl_pkg::NP_REQ_TX_TYPE_WD;
  import radm_ms_pkg::CPL_LUT_PTR_WD;
  import radm_ms_pkg::CPL_TRGT_INDEX;
  import radm_ms_pkg::NP_REQ_TYPE_INDEX;
  import radm_ms_pkg::CPL_ENTRY_WIDTH;  
  import radm_ms_pkg::CPL_ENTRY_WIDTH2;    
  import radm_ms_pkg::N_FLT_MASK;
  import radm_ms_pkg::RADM_FILTER_TO_LUT_PIPE;
  import radm_ms_pkg::RTLH_RADM_RID_WD;  
  import radm_ms_pkg::HW;
  import radm_ms_pkg::RADM_HDR_PROT_WD;
#(
  parameter FORMQ_RD_PORTS = `CX_RADM_FORMQ_N_READ_PORT_VC
)
                             (
  ///////////////////// inputs  /////////////////////
  input                                                core_clk,
  input                                                core_rst_n,
  input   [N_FLT_MASK-1:0]                             cfg_filter_rule_mask,    // "static" // PL reg outputs to control the selection of filter rules that are designed in radm_filter*
  input   [DEVNUM_WD -1:0]                             cfg_pbus_dev_num,           // "static" // Device number
  input   [BUSNUM_WD -1:0]                             cfg_pbus_num,               // "static" // Bus number
  input                                                cfg_p2p_track_cpl_to,       // 0: bydefault, do not track cpl in lut for P2P; 1: track cpl in lut for P2P.
  input                                                cfg_p2p_err_rpt_ctrl,       // 1: bydefault, P2P error reporting enable; 0: P2P error reporting disable.
  input   [3:0]                                        tag_bits_13_to_10,          // tag bit input for bit 13 down to 10.
  /////////////////////////////////////////////////////////////
  // completion packet interface
  input   [FORMQ_RD_PORTS-1:0][3-1:0]                  filt_lut_cpl_status,
  input   [FORMQ_RD_PORTS-1:0]                         filt_lut_dwlenEq0,
  input   [FORMQ_RD_PORTS-1:0]                         filt_lut_hv,               // When asserted; indicates the hdr valid
  input   [FORMQ_RD_PORTS-1:0][(HW+RADM_HDR_PROT_WD)-1:0]   filt_lut_hdr,              // hdr payload
  input   [FORMQ_RD_PORTS-1:0]                         filt_lut_eot,              // When asserted; indicates the tlp end
  input   [FORMQ_RD_PORTS-1:0]                         filt_lut_dllp_err,         // Indication that TLP has dllp err (valid @ EOT)
 

  input   [FORMQ_RD_PORTS-1:0]                         filt_lut_malform_tlp_err,  // Indication that TLP is malformed (valid @ HV)
  input   [FORMQ_RD_PORTS-1:0]                         filt_lut_ecrc_err,         // Indication that TLP has ECRC err (valid @ EOT)

  input                                                filt_lut_ant_formation,
  input  [FORMQ_RD_PORTS-1:0]                          filt_lut_ant_hv,
  input                                                filt_lut_formation,        // Leading queue indication from radm_formation
  ///////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
  input   [3:0]                                        device_type,                // "static"
  input                                                cdm_dpc_triggered,          // DPC has been triggered indication
  input                                                cdm_core_in_dpc,            // Core is in Downstream Port Containment mode.
  input   [FORMQ_RD_PORTS-1:0]                         valid_at_lut_addr,                      // Valid bits (per entry)
  input  [FORMQ_RD_PORTS-1:0][CPL_ENTRY_WIDTH-1:0]     cpl_lut_vec,
  input   [FORMQ_RD_PORTS-1:0][CPL_ENTRY_WIDTH2-1:0]   cpl_lut2_vec,
  output  [FORMQ_RD_PORTS-1:0][CPL_ENTRY_WIDTH2-1:0]   update_lut_byte_cnt_pipe, 
  output  [FORMQ_RD_PORTS-1:0]                         lut_filt_vendor_msg_id_match,
  output  [FORMQ_RD_PORTS-1:0]                         lut_filt_cpl_abort,
  output  [FORMQ_RD_PORTS-1:0]                         lut_filt_cpl_last,
  output  [FORMQ_RD_PORTS-1:0]                         lut_filt_cpl_mlf_err,
  output  [FORMQ_RD_PORTS-1:0]                         lut_filt_cpl_ur_err,
  output  [FORMQ_RD_PORTS-1:0]                         lut_filt_cpl_ca_err,
  output  [FORMQ_RD_PORTS-1:0]                         lut_filt_unexpected_cpl_err,
  output  [FORMQ_RD_PORTS-1:0]                         update_lut_content_pipe,
  output  [FORMQ_RD_PORTS-1:0][CPL_LUT_PTR_WD-1:0]     update_lut_addr_pipe  ,
  output  [FORMQ_RD_PORTS-1:0][NP_REQ_TX_TYPE_WD-1:0]  lut_np_req_type_decoded,
  output                                               cpl_trgt_interface_no,
  output    [FORMQ_RD_PORTS-1:0]                       cpl_last_pipe
  );

  /////////////////////////////////////////////////////////////////////////
  // Internal wires and registers
  //
  // Figure out when the LUT Filters are looking at the same tag. Each filter
  // tag is compared to the tag of the filter below it. filter 0 is compared
  // with filter FORMQ_RD_PORTS-1.
  // For the case of two filters
  // lut_addr[0] is compared with lut_addr[1] to give same_tag[0]
  // lut_addr[1] is compared with lut_addr[0] to give same_tag[1]
  // Each filter gets it's own same_tag bit as an input
  logic   [FORMQ_RD_PORTS-1:0]                      same_tag;
  // The received Byte length from the first filter needs to be passed into the other filter
  // when two filters are looking at the same tag. Any filter can be the
  // first filter depending on the formation bit(filt_lut_formation).
  // The next_byte_len output from one filter is passed to the prev_byte_len input
  // of the next.
  logic   [13*FORMQ_RD_PORTS-1:0]                   prev_byte_len;
  logic   [13*FORMQ_RD_PORTS-1:0]                   next_byte_len;
  // mask same tag when the first filter has a cpl_abort.
  logic   [FORMQ_RD_PORTS-1:0]                      prev_cpl_abort;
  logic   [FORMQ_RD_PORTS-1:0]                      next_cpl_abort;
  // When one filter detects that a completion is the last it needs to tell its
  // neighbour that the completion it has isn't valid if it has the same tag.
  // Also when both filters are looking at the same tag only the later of
  // the two should do update_lut_content. use prev_cpl_last input to filter for
  // this.
  // Completions can be checked for byte count on hv, if the byte count is
  // incorrect the completion can be ruled out and aborted immediately. When
  // looking at two completions with the same tag this applies to the eot of
  // one TLP overlapping with the hv of the second.
  // This also covers the case when the second TLP is single cycle and the eot
  // of this TLP also occurs in that cycle.
  logic  [FORMQ_RD_PORTS-1:0]                       prev_cpl_last;
  logic  [FORMQ_RD_PORTS-1:0]                       int_same_tag_reg;

  // cross connect the filter io based on the formation bit.
  logic  [FORMQ_RD_PORTS-1:0][3-1:0]                int_filt_lut_cpl_status;
  logic  [FORMQ_RD_PORTS-1:0]                       int_filt_lut_dwlenEq0;
  logic  [FORMQ_RD_PORTS-1:0][(HW+RADM_HDR_PROT_WD)-1:0] int_filt_lut_hdr;      // hdr payload
  logic  [FORMQ_RD_PORTS-1:0]                       int_filt_lut_dllp_err;         // Indication that TLP has dllp err (valid @ EOT)
 

  logic  [FORMQ_RD_PORTS-1:0]                       int_filt_lut_malform_tlp_err;  // Indication that TLP is malformed (valid @ HV)
  logic  [FORMQ_RD_PORTS-1:0]                       int_filt_lut_ecrc_err;         // Indication that TLP has ECRC err (valid @ EOT)
  logic  [FORMQ_RD_PORTS-1:0]                       int_filt_lut_hv;               // When asserted; indicates the hdr valid
  logic  [FORMQ_RD_PORTS-1:0]                       int_filt_lut_eot;              // When asserted; indicates the tlp end
  logic  [FORMQ_RD_PORTS-1:0]                       int_lut_filt_vendor_msg_id_match;
  logic  [FORMQ_RD_PORTS-1:0]                       int_lut_filt_cpl_abort;
  logic  [FORMQ_RD_PORTS-1:0]                       int_lut_filt_cpl_last;
  logic  [FORMQ_RD_PORTS-1:0]                       int_lut_filt_cpl_mlf_err;
  logic  [FORMQ_RD_PORTS-1:0]                       int_lut_filt_cpl_ur_err;
  logic  [FORMQ_RD_PORTS-1:0]                       int_lut_filt_cpl_ca_err;
  logic  [FORMQ_RD_PORTS-1:0]                       int_lut_filt_unexpected_cpl_err;

  // Only update *formation* on hv.
  logic                                             int_filt_lut_formation;
  logic                                             int_filt_lut_ant_formation;
  logic                                             int_filt_lut_formation_d;
  logic                                             filt_lut_formation_d;

  logic [FORMQ_RD_PORTS-1:0]                        valid_at_hv;
  logic [FORMQ_RD_PORTS-1:0]                        valid_at_lut_addr_reg[FORMQ_RD_PORTS-1:0];
  
  localparam UPDATE_VEC_WD = CPL_LUT_PTR_WD + 1 + 1 + CPL_ENTRY_WIDTH2;
  logic [UPDATE_VEC_WD-1:0]                         update_pipe_in[FORMQ_RD_PORTS-1:0];
  logic [UPDATE_VEC_WD-1:0]                         update_pipe_out[FORMQ_RD_PORTS-1:0];
  logic [UPDATE_VEC_WD-1:0]                         update_pipe_reg_in[FORMQ_RD_PORTS-1:0];
  logic [UPDATE_VEC_WD-1:0]                         update_pipe_reg_out[FORMQ_RD_PORTS-1:0];

  logic [FORMQ_RD_PORTS-1:0]                        update_lut_content;
  logic [FORMQ_RD_PORTS-1:0]                        update_lut_content_pipe_reg;
  logic [FORMQ_RD_PORTS-1:0][CPL_LUT_PTR_WD-1:0]    update_lut_addr;  
  logic [FORMQ_RD_PORTS-1:0][CPL_LUT_PTR_WD-1:0]    update_lut_addr_pipe_reg;  
  logic [FORMQ_RD_PORTS-1:0][CPL_ENTRY_WIDTH2-1:0]  update_lut_byte_cnt;
  logic [FORMQ_RD_PORTS-1:0][CPL_ENTRY_WIDTH2-1:0]  update_lut_byte_cnt_pipe_reg;

  logic [FORMQ_RD_PORTS-1:0]                        cpl_last;
  logic [FORMQ_RD_PORTS-1:0]                        cpl_eot; // Used if CX_TDISP_ENABLE or CX_DPC_RP_PIO_EXTNS 
  logic [FORMQ_RD_PORTS-1:0]                        cpl_last_pipe_reg;
  logic [FORMQ_RD_PORTS-1:0]                        cpl_14bit_tag;
  logic [FORMQ_RD_PORTS-1:0]                        radm_cpl_filter_malform_tlp_err;
  logic [CPL_ENTRY_WIDTH-1:0]                       lut_vec[FORMQ_RD_PORTS-1:0];
  logic [CPL_ENTRY_WIDTH2-1:0]                      lut_vec2[FORMQ_RD_PORTS-1:0];
  logic  [FORMQ_RD_PORTS-1:0][CPL_LUT_PTR_WD-1:0]   lut_addr;

  ////////////////////////////////////////////////////////////////////////
  // Logic to interconnect filters while multiple filters are there per VC
  // Interconnection of the filter is required to process the CPL TLPs of 
  // the same tags
  //
  ////////////////////////////////////////////////////////////////////////
  always @(*) begin : FILTER_INTERCONNECT
    prev_cpl_abort[0] = 0;
    same_tag[0] = 0;
    prev_byte_len[0 +: 13] = 0;
    prev_cpl_last[0] = 0;
    if(FORMQ_RD_PORTS > 1) begin
        for(int i = 1; i < FORMQ_RD_PORTS; i = i + 1) begin
            same_tag[i] = 
                lut_addr[i] == lut_addr[i-1] &&
                cpl_14bit_tag[i] == cpl_14bit_tag[i-1] &&
                int_filt_lut_hv[i] && int_filt_lut_eot[i-1] &&
                !filt_lut_dllp_err[i] && !filt_lut_dllp_err[i-1] &&
                !filt_lut_malform_tlp_err[i] && !filt_lut_malform_tlp_err[i-1] &&
                !filt_lut_ecrc_err[i] && !filt_lut_ecrc_err[i-1];
            prev_byte_len[13*i +: 13] = next_byte_len[13*(i-1) +: 13];
            prev_cpl_last[i] = cpl_last[i-1];
            prev_cpl_abort[i] = next_cpl_abort[i-1];
        end
    end
  end

  //////////////////////////////////////////////////////////////
  // Latching of the formation to filter signal indication 
  // at HV clock cycle
  //
  //////////////////////////////////////////////////////////////
  always @(posedge core_clk or negedge core_rst_n)
    if(!core_rst_n) begin
        filt_lut_formation_d <= #TP 0;
        int_filt_lut_formation_d <= #TP 0;
    end else if(|filt_lut_hv) begin
        filt_lut_formation_d <= #TP filt_lut_formation;
        int_filt_lut_formation_d <= #TP int_filt_lut_formation;
    end
  assign  int_filt_lut_formation = |filt_lut_hv ? filt_lut_formation : filt_lut_formation_d;

  // Not assuming ant_formation is always 1 cycle ahead of formation
  reg filt_lut_ant_formation_d;
  always @(posedge core_clk or negedge core_rst_n)
    if(!core_rst_n) begin
        filt_lut_ant_formation_d <= #TP 0;
    end else if(|filt_lut_ant_hv) begin
        filt_lut_ant_formation_d <= #TP filt_lut_ant_formation;
    end
  assign  int_filt_lut_ant_formation = |filt_lut_ant_hv ? filt_lut_ant_formation : filt_lut_ant_formation_d;

  //////////////////////////////////////////////////////////////////////
  // Internal mapping on the signals based on formation to filter signal
  //
  //////////////////////////////////////////////////////////////////////
/*  
//  `ifdef CX_RADM_FORMQ_N_READ_PORT_VC == 2 
//  assign int_cpl_tlp                   = int_filt_lut_formation ? { cpl_tlp[0], cpl_tlp[1] } : cpl_tlp;
    `ifdef CX_CCIX_INTERFACE_ENABLE
  assign int_ccix_tlp                  = int_filt_lut_formation ? { ccix_tlp[0], ccix_tlp[1] } : ccix_tlp;
    `endif // CX_CCIX_INTERFACE_ENABLE
  assign int_filt_lut_cpl_status                = int_filt_lut_formation ? { filt_lut_cpl_status[0], filt_lut_cpl_status[1] } : filt_lut_cpl_status;
  assign int_filt_lut_dwlenEq0                  = int_filt_lut_formation ? { filt_lut_dwlenEq0[0], filt_lut_dwlenEq0[1] } : filt_lut_dwlenEq0;
  assign int_filt_lut_hv              = int_filt_lut_formation ? { filt_lut_hv[0], filt_lut_hv[1] } : filt_lut_hv;               // When asserted; indicates the hdr valid
  assign int_filt_lut_hdr             = int_filt_lut_formation ? { filt_lut_hdr[0], filt_lut_hdr[1] } : filt_lut_hdr;      // hdr payload
  assign int_filt_lut_eot             = int_filt_lut_formation ? { filt_lut_eot[0], filt_lut_eot[1] } : filt_lut_eot;              // When asserted; indicates the tlp end
  assign int_filt_lut_dllp_err        = int_filt_lut_formation ? { filt_lut_dllp_err[0], filt_lut_dllp_err[1] } : filt_lut_dllp_err;         // Indication that TLP has dllp err (valid @ EOT)
  assign int_filt_lut_malform_tlp_err = int_filt_lut_formation ? { filt_lut_malform_tlp_err[0], filt_lut_malform_tlp_err[1] } : filt_lut_malform_tlp_err;  // Indication that TLP is malformed (valid @ HV)
  assign int_filt_lut_ecrc_err        = int_filt_lut_formation ? { filt_lut_ecrc_err[0], filt_lut_ecrc_err[1] } : filt_lut_ecrc_err;         // Indication that TLP has ECRC err (valid @ EOT)
`ifdef CX_SRIOV_ENABLE  
  assign int_filt_lut_ant_rid         = int_filt_lut_ant_formation ? { filt_lut_ant_rid[0 +: 16], filt_lut_ant_rid[16 +: 16] } : filt_lut_ant_rid;     // anticipated RID (1 clock earlier)
`endif   
  // ### Outputs from the radm_cpl_lut delayed by internal pipeline ###
  assign lut_filt_vendor_msg_id_match           = int_filt_lut_formation ? { int_lut_filt_vendor_msg_id_match[0], int_lut_filt_vendor_msg_id_match[1] } : int_lut_filt_vendor_msg_id_match;
  assign lut_filt_cpl_abort               = int_filt_lut_formation_d ? { int_lut_filt_cpl_abort[0], int_lut_filt_cpl_abort[1] } : int_lut_filt_cpl_abort;
  assign lut_filt_cpl_last                = int_filt_lut_formation_d ? { int_lut_filt_cpl_last[0], int_lut_filt_cpl_last[1] } : int_lut_filt_cpl_last;
  assign lut_filt_cpl_mlf_err                   = int_filt_lut_formation ? { int_lut_filt_cpl_mlf_err[0], int_lut_filt_cpl_mlf_err[1] } : int_lut_filt_cpl_mlf_err;
  assign lut_filt_cpl_ur_err                    = int_filt_lut_formation ? { int_lut_filt_cpl_ur_err[0], int_lut_filt_cpl_ur_err[1] } : int_lut_filt_cpl_ur_err;
  assign lut_filt_cpl_ca_err                    = int_filt_lut_formation ? { int_lut_filt_cpl_ca_err[0], int_lut_filt_cpl_ca_err[1] } : int_lut_filt_cpl_ca_err;
  assign lut_filt_unexpected_cpl_err            = int_filt_lut_formation ? { int_lut_filt_unexpected_cpl_err[0], int_lut_filt_unexpected_cpl_err[1] } : int_lut_filt_unexpected_cpl_err;
  `ifdef CX_DPC_RP_PIO_EXTNS
  assign cpl_ecrc_err                  = int_filt_lut_formation ? { int_cpl_ecrc_err[0], int_cpl_ecrc_err[1] } : int_cpl_ecrc_err;
  assign np_req_is_a_memrd             = int_filt_lut_formation ? { int_np_req_is_a_memrd[0], int_np_req_is_a_memrd[1] } : int_np_req_is_a_memrd;
  assign np_req_is_a_io                = int_filt_lut_formation ? { int_np_req_is_a_io[0], int_np_req_is_a_io[1] } : int_np_req_is_a_io;
  assign np_req_is_a_cfg               = int_filt_lut_formation ? { int_np_req_is_a_cfg[0], int_np_req_is_a_cfg[1] } : int_np_req_is_a_cfg;
  `endif // CX_DPC_RP_PIO_EXTNS
  `else

  assign int_filt_lut_tdisp_rcvd_rid_range_check_fail    =fixme
  `ifdef CX_TDISP_ENABLE
  assign lut_filt_cpl_not_in_run         = FIXMEPLEASE;
  assign lut_filt_cpl_for_ats_tbit_clear = FIXMEPLEASE;
  assign int_filt_lut_tbit                               = fixme;
  assign int_filt_lut_tdisp_cpl_for_memrd_with_tbit_set  = fixme;
  assign int_filt_lut_tdisp_cpl_for_ats_translation_with_tbit_set = fixme;

  `endif // CX_TDISP_ENABLE
*/
  assign int_filt_lut_cpl_status      =  filt_lut_cpl_status;
  assign int_filt_lut_dwlenEq0        =  filt_lut_dwlenEq0;
  assign int_filt_lut_hv              =  filt_lut_hv;               // When asserted; indicates the hdr valid
  assign int_filt_lut_hdr             =  filt_lut_hdr;      // hdr payload
  assign int_filt_lut_eot             =  filt_lut_eot;              // When asserted; indicates the tlp end
  assign int_filt_lut_dllp_err        =  filt_lut_dllp_err;         // Indication that TLP has dllp err (valid @ EOT)

  

  assign int_filt_lut_malform_tlp_err =  filt_lut_malform_tlp_err;  // Indication that TLP is malformed (valid @ HV)
  assign int_filt_lut_ecrc_err        =  filt_lut_ecrc_err;         // Indication that TLP has ECRC err (valid @ EOT)
  // ### Outputs from the radm_cpl_lut delayed by internal pipeline ###
  assign lut_filt_vendor_msg_id_match = int_lut_filt_vendor_msg_id_match;
  assign lut_filt_cpl_abort           = int_lut_filt_cpl_abort;
  assign lut_filt_cpl_last            = int_lut_filt_cpl_last;
  assign lut_filt_cpl_mlf_err         = int_lut_filt_cpl_mlf_err;
  assign lut_filt_cpl_ur_err          = int_lut_filt_cpl_ur_err;
  assign lut_filt_cpl_ca_err          = int_lut_filt_cpl_ca_err;
  assign lut_filt_unexpected_cpl_err  = int_lut_filt_unexpected_cpl_err;
//  `endif
/////////////////////////////////////////////////////////////////////////
//
// TLP check module instances based on the RTL configuration of number of 
// parallel TLP output from the CPL formation queue.
//
/////////////////////////////////////////////////////////////////////////
logic  [FORMQ_RD_PORTS-1:0] going_to_clear_valid;
logic  [FORMQ_RD_PORTS-1:0] going_to_clear_valid_reg;
logic  [FORMQ_RD_PORTS-1:0] going_to_clear_valid_at_hv;

genvar num_tlp; 
generate
for (num_tlp=0; num_tlp<FORMQ_RD_PORTS; num_tlp = num_tlp+1) begin : u_radm_cpl_filter_gen
  // vec extractor instances 
  radm_cpl_lut_vec_extractor_ms
  
  u_radm_cpl_lut_vec_extractor_ms (
  // ---- inputs ---------------
      .core_clk                   (core_clk),
      .tag_bits_13_to_10          (tag_bits_13_to_10), 
      .filt_lut_hv                (int_filt_lut_hv[num_tlp]),
      .filt_lut_hdr               (int_filt_lut_hdr[num_tlp]),
      .cpl_lut_vec                (cpl_lut_vec[num_tlp]), 
      .cpl_lut2_vec               (cpl_lut2_vec[num_tlp]), 
      .update_lut_content_pipe    (update_lut_content_pipe[num_tlp]),
      .update_lut_addr_pipe       (update_lut_addr_pipe[num_tlp]),
      .update_lut_byte_cnt_pipe   (update_lut_byte_cnt_pipe[num_tlp]),
      .update_lut_content_pipe_reg(update_lut_content_pipe_reg[num_tlp]),
      .update_lut_addr_pipe_reg   (update_lut_addr_pipe_reg[num_tlp]),
      .update_lut_byte_cnt_pipe_reg(update_lut_byte_cnt_pipe_reg[num_tlp]),
      .cpl_last_pipe               (cpl_last_pipe[num_tlp] ),
      .cpl_last_pipe_reg           (cpl_last_pipe_reg[num_tlp]),
 
  // ---- outputs ---------------
      .cpl_14bit_tag              (cpl_14bit_tag[num_tlp]),
      .lut_addr                   (lut_addr[num_tlp]),
      .lut_vec                    (lut_vec[num_tlp])
     ,.lut_vec2                   (lut_vec2[num_tlp])
    ,.going_to_clear_valid       (going_to_clear_valid[num_tlp])   

  );

  ///////////////////////////////////////////////////////////////////
  // Latching of the valid as the LUT address.
  //
  // Provides the information about the valid NP TLP content at the 
  // LUT address pointed by the received CPL TLP.
  ///////////////////////////////////////////////////////////////////  
  always @(posedge core_clk or negedge core_rst_n)
  begin : VALID_REG
      if (!core_rst_n) begin
          valid_at_lut_addr_reg[num_tlp]    <= #TP '0;
          going_to_clear_valid_reg[num_tlp] <= #TP '0;
      end else if(int_filt_lut_hv[num_tlp]) begin
          valid_at_lut_addr_reg[num_tlp]    <= #TP valid_at_lut_addr[num_tlp];
          going_to_clear_valid_reg[num_tlp] <= #TP going_to_clear_valid[num_tlp];  
      end
  end
  assign valid_at_hv[num_tlp]                = (int_filt_lut_hv[num_tlp]) ? valid_at_lut_addr[num_tlp] : valid_at_lut_addr_reg[num_tlp];
  assign going_to_clear_valid_at_hv[num_tlp] = (int_filt_lut_hv[num_tlp]) ? going_to_clear_valid[num_tlp] : going_to_clear_valid_reg[num_tlp];
 
  /////////////////////////////////////////////////////////////////////
  // Malformed TLP error condition
  //
  /////////////////////////////////////////////////////////////////////
  // Ensure that all completions, which follow TLP with error which triggers DPC, are discarded.
  // Assumption: int_filt_lut_eot is aligned with cdm_dpc_triggered || cdm_core_in_dpc => if Cpl occurs immediately after the errored TLP. then
  // this Cpl is seen to occur while core is in DPC.
  assign radm_cpl_filter_malform_tlp_err[num_tlp] = (cdm_dpc_triggered || cdm_core_in_dpc) ? int_filt_lut_eot[num_tlp] : int_filt_lut_malform_tlp_err[num_tlp];

  /////////////////////////////////////////////////////////////////////
  // Same tag logic to decide about the byte count at the tlp check 
  // module level.
  //
  //////////////////////////////////////////////////////////////////////       
  always@(*) begin
    int_same_tag_reg[num_tlp] = (num_tlp>0) ? same_tag[num_tlp] /* && cpl_tlp[num_tlp]  && cpl_tlp[num_tlp-1] */ : 1'b0;
  end
 
  /////////////////////////////////////////////////////////////////////
  // NP REQ Type decoding.
  // NP REQ type is getting stored inside the LUT with NP TLP Attributes.
  // Following logic just derive the value of the TYPE of the TLP with help
  // of funtion whose inputs are typedef and stored value from lut.
  //
  // This is getting used by tlp check module to generate few outputs and 
  // to manage the split CPL TLPs.
  /////////////////////////////////////////////////////////////////////
  assign lut_np_req_type_decoded[num_tlp] = lut_vec[num_tlp][NP_REQ_TYPE_INDEX-1:CPL_TRGT_INDEX];    
  assign cpl_trgt_interface_no            = lut_vec[num_tlp][CPL_TRGT_INDEX-1];
  /////////////////////////////////////////////////////////////////////
  // TLP check module instance
  //
  /////////////////////////////////////////////////////////////////////
radm_cpl_tlp_check

  u_radm_cpl_tlp_check (
  // ---- inputs ---------------
      .core_clk                      (core_clk),
      .core_rst_n                    (core_rst_n),
      .device_type                   (device_type),
  
      .cfg_filter_rule_mask          (cfg_filter_rule_mask),
      .cfg_pbus_dev_num              (cfg_pbus_dev_num),
      .cfg_pbus_num                  (cfg_pbus_num),
      .cfg_p2p_track_cpl_to          (cfg_p2p_track_cpl_to),
      .cfg_p2p_err_rpt_ctrl          (cfg_p2p_err_rpt_ctrl),
      .tag_bits_13_to_10             (tag_bits_13_to_10), 
      .filt_lut_cpl_status           (int_filt_lut_cpl_status[num_tlp]),
      .filt_lut_dwlenEq0             (int_filt_lut_dwlenEq0[num_tlp]),
      .filt_lut_hv                   (int_filt_lut_hv[num_tlp]),
      .filt_lut_hdr                  (int_filt_lut_hdr[num_tlp]),
      .filt_lut_eot                  (int_filt_lut_eot[num_tlp]),
      .filt_lut_dllp_err             (int_filt_lut_dllp_err[num_tlp]),

  

      .filt_lut_ecrc_err             (int_filt_lut_ecrc_err[num_tlp]),
      .filt_lut_malform_tlp_err      (radm_cpl_filter_malform_tlp_err[num_tlp]),
      .lut_np_req_type_decoded       (lut_np_req_type_decoded[num_tlp]),
      .lut_vec                       (lut_vec[num_tlp]), 
      .lut_vec2                      (lut_vec2[num_tlp]),
      .going_to_clear_valid          (going_to_clear_valid_at_hv[num_tlp]), 
      .valid                         (valid_at_hv[num_tlp]),
      .same_tag                      (int_same_tag_reg[num_tlp]),
      .prev_byte_len                 (prev_byte_len[13*num_tlp +: 13]),
      .prev_cpl_last                 (prev_cpl_last[num_tlp]),
      .prev_cpl_abort                (prev_cpl_abort[num_tlp]),
  
  // ---- outputs ---------------
      .update_lut_content            (update_lut_content[num_tlp]),
      .cpl_last                      (cpl_last[num_tlp]),
      .cpl_eot                       (cpl_eot[num_tlp]),
      .update_lut_byte_cnt           (update_lut_byte_cnt[num_tlp]),
      .lut_filt_vendor_msg_id_match  (int_lut_filt_vendor_msg_id_match[num_tlp]),
      .lut_filt_cpl_abort            (int_lut_filt_cpl_abort[num_tlp]),
      .lut_filt_cpl_last             (int_lut_filt_cpl_last[num_tlp]),
      .lut_filt_cpl_mlf_err          (int_lut_filt_cpl_mlf_err[num_tlp]),
      .lut_filt_cpl_ur_err           (int_lut_filt_cpl_ur_err[num_tlp]),
      .lut_filt_cpl_ca_err           (int_lut_filt_cpl_ca_err[num_tlp]),
      .lut_filt_unexpected_cpl_err   (int_lut_filt_unexpected_cpl_err[num_tlp]),
      .next_byte_len                 (next_byte_len[13*num_tlp +: 13]),
      .next_cpl_abort                (next_cpl_abort[num_tlp])
  );

  /////////////////////////////////////////////////////////////////////
  // Flop on the update path from tlp check module to LUT.
  // Flop is required to break the timining path between the tlp check and LUT.
  //
  /////////////////////////////////////////////////////////////////////   
  assign update_lut_addr[num_tlp] = lut_addr[num_tlp];

  assign update_pipe_in[num_tlp] = {
                                    update_lut_addr[num_tlp],
                                    cpl_last[num_tlp],
                                    update_lut_content[num_tlp]                             
                                    ,update_lut_byte_cnt[num_tlp]
                                   };

    delay_n
    
    #(RADM_FILTER_TO_LUT_PIPE, UPDATE_VEC_WD) u_pipeline_update_vec(
        .clk        (core_clk),
        .rst_n      (core_rst_n),
        .clear      (1'b0),
        .din        (update_pipe_in[num_tlp]),
        .dout       (update_pipe_out[num_tlp])
    );
    
  assign  {
        update_lut_addr_pipe[num_tlp],
        cpl_last_pipe[num_tlp],
        update_lut_content_pipe[num_tlp]                             
        ,update_lut_byte_cnt_pipe[num_tlp]
    } = update_pipe_out[num_tlp]; 

  ///////////////////////////////////////////////////////////////////
  // Flopping of the data of the previous flop output.
  // This flop data is getting used to feed back the tlp 
  // check module while it is receiving the same tag TLP with 
  // intermidiate gaps including other tag tlp.
  //
  ///////////////////////////////////////////////////////////////////
    assign update_pipe_reg_in[num_tlp] = update_pipe_out[num_tlp];

    delay_n
    
    #(RADM_FILTER_TO_LUT_PIPE, UPDATE_VEC_WD) u_pipeline_update_pipe_vec(
        .clk        (core_clk),
        .rst_n      (core_rst_n),
        .clear      (1'b0),
        .din        (update_pipe_reg_in[num_tlp]),
        .dout       (update_pipe_reg_out[num_tlp])
    );

    assign  {
        update_lut_addr_pipe_reg[num_tlp],
        cpl_last_pipe_reg[num_tlp],
        update_lut_content_pipe_reg[num_tlp]                             
        ,update_lut_byte_cnt_pipe_reg[num_tlp]
    } = update_pipe_reg_out[num_tlp];

end
endgenerate

endmodule
