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
// ---    $Id: //dwh/pcie_iip/main/fairbanks/design/Adm_ms/radm_cpl_tlp_check.sv#5 $
// -------------------------------------------------------------------------

// -----------------------------------------------------------------------------
// --- Module Description:
// -----------------------------------------------------------------------------
// --- Filters received completions based on contents of RADM CPL LUT
// -----------------------------------------------------------------------------

`include "include/DWC_pcie_ctl_all_defs.svh"
`include "DWC_pcie_ctl_pkg.svh"
`include "Adm_ms/radm_ms_pkg.svh"

module radm_cpl_tlp_check
  import DWC_pcie_ctl_pkg::TP;
  import DWC_pcie_ctl_pkg::TAG_SIZE;
  import DWC_pcie_ctl_pkg::NF;
  import DWC_pcie_ctl_pkg::NVF;
  import DWC_pcie_ctl_pkg::PF_WD;
  import DWC_pcie_ctl_pkg::VFI_WD;
  import DWC_pcie_ctl_pkg::VF_WD;
  import DWC_pcie_ctl_pkg::BUSNUM_WD;
  import DWC_pcie_ctl_pkg::DEVNUM_WD;  
  import DWC_pcie_ctl_pkg::NP_REQ_TX_TYPE_WD;
  import DWC_pcie_ctl_pkg::E_NP_REQ_TX_MEMRD_NON_ATS;
  import DWC_pcie_ctl_pkg::E_NP_REQ_TX_CFG_WR;
  import DWC_pcie_ctl_pkg::E_NP_REQ_TX_CFG_RD;
  import DWC_pcie_ctl_pkg::E_NP_REQ_TX_MEMRD_ATS;
  import DWC_pcie_ctl_pkg::E_NP_REQ_TX_ATOMIC;
  import DWC_pcie_ctl_pkg::E_NP_REQ_TX_DMWR;
  import radm_ms_pkg::CPL_LUT_PTR_WD;
  import radm_ms_pkg::FUNC_NUM_INDEX;
  import radm_ms_pkg::BYTECNT_INDEX;
  import radm_ms_pkg::FLT_NUM;
  import radm_ms_pkg::LOW_ADDR_INDEX2;
  import radm_ms_pkg::TC_INDEX;
  import radm_ms_pkg::ATTR_INDEX;
  import radm_ms_pkg::NP_REQ_TYPE_INDEX;
  import radm_ms_pkg::E_14BIT_TAG_INDEX;   
  import radm_ms_pkg::E_10BIT_TAG_INDEX;  
  import radm_ms_pkg::CPL_ENTRY_WIDTH;  
  // ## CPL_LUT2 ##
  import radm_ms_pkg::LOW_ADDR_WD2; 
  import radm_ms_pkg::BYTECNT_WD2;      
  import radm_ms_pkg::BYTECNT_INDEX2;   
  import radm_ms_pkg::CPL_ENTRY_WIDTH2;        
  import radm_ms_pkg::N_FLT_MASK;
  import radm_ms_pkg::HW;
  import radm_ms_pkg::RADM_HDR_PROT_WD;
(
// ---- inputs ---------------
    core_clk,
    core_rst_n,
    device_type,
    cfg_filter_rule_mask,
    cfg_pbus_dev_num,
    cfg_pbus_num,
    cfg_p2p_track_cpl_to,
    cfg_p2p_err_rpt_ctrl,
    tag_bits_13_to_10,
    filt_lut_cpl_status,
    filt_lut_dwlenEq0,
    filt_lut_hv,
    filt_lut_hdr,
    filt_lut_eot,
    filt_lut_dllp_err,
    filt_lut_ecrc_err,
    filt_lut_malform_tlp_err,
    lut_np_req_type_decoded,
    lut_vec,
    lut_vec2,
    going_to_clear_valid,
    valid,
    same_tag,
    prev_byte_len,
    prev_cpl_last,
    prev_cpl_abort,
// ---- outputs ---------------
    update_lut_content,
    cpl_last,
    cpl_eot,
    update_lut_byte_cnt,
    lut_filt_vendor_msg_id_match,
    lut_filt_cpl_abort,
    lut_filt_cpl_last,
    lut_filt_cpl_mlf_err,
    lut_filt_cpl_ur_err,
    lut_filt_cpl_ca_err,
    lut_filt_unexpected_cpl_err,
    next_byte_len,
    next_cpl_abort

);

localparam NF_WD_INT = `CX_NFUNC==1 ? 1 : $clog2(`CX_NFUNC);

// ---- inputs ---------------
input                           core_clk;
input                           core_rst_n;
input   [3:0]                   device_type;                // "static"
input   [N_FLT_MASK-1:0]        cfg_filter_rule_mask;       // "static" // PL reg outputs to control the selection of filter rules that are designed in radm_filter*
input   [DEVNUM_WD -1:0]        cfg_pbus_dev_num;           // "static" // Device number
input   [BUSNUM_WD -1:0]        cfg_pbus_num;               // "static" // Bus number
input                           cfg_p2p_track_cpl_to;       // 0: by default, do not track cpl in lut for P2P; 1: track cpl in lut for P2P
input                           cfg_p2p_err_rpt_ctrl;       // 1: by default, P2P error reporting enable; 0: P2P error reporting disable
input   [3:0]                   tag_bits_13_to_10;          // tag bit input for bit 13 down to 10.
input   [2:0]                   filt_lut_cpl_status;
input                           filt_lut_dwlenEq0;
input                                filt_lut_hv;
input   [HW+RADM_HDR_PROT_WD-1:0]    filt_lut_hdr;
input                           filt_lut_eot;
input                           filt_lut_dllp_err;         // Recall packet (Malformed TLP, etc.)
   

input                           filt_lut_ecrc_err;
input                           filt_lut_malform_tlp_err;  // Recall packet (Malformed TLP, etc.)
input   [NP_REQ_TX_TYPE_WD-1:0]   lut_np_req_type_decoded;
input   [CPL_ENTRY_WIDTH-1:0]   lut_vec;
input   [CPL_ENTRY_WIDTH2-1:0]  lut_vec2;
input                           valid;                      // Valid bits (per entry)
input                           going_to_clear_valid; 
input                           same_tag;
input   [12:0]                  prev_byte_len;
input                           prev_cpl_last;
input                           prev_cpl_abort;

// ---- outputs ---------------
output                          update_lut_content;
output                          cpl_last;
output                          cpl_eot;
output  [CPL_ENTRY_WIDTH2-1:0]   update_lut_byte_cnt;
output                          lut_filt_vendor_msg_id_match;
output                          lut_filt_cpl_abort;
output                          lut_filt_cpl_last;
output                          lut_filt_cpl_mlf_err;
output                          lut_filt_cpl_ur_err;
output                          lut_filt_cpl_ca_err;
output                          lut_filt_unexpected_cpl_err;
output [12:0]                   next_byte_len;
output                          next_cpl_abort;

wire                            cpl_bcm;
wire    [15:0]                  cpl_reqid;
wire    [9:0]                   dw_len;
wire    [TAG_SIZE-1:0]          rcvd_cpl_tlp_tag;
wire    [12:0]                  rcvd_tlp_byte_cnt;
wire    [6:0]                   rcvd_tlp_low_addr;
wire    [2:0]                   tc;
wire    [1:0]                   attr;
reg                             lut_filt_cpl_abort;
reg                             lut_filt_cpl_last;
wire    [PF_WD-1:0]             lut_pfuncid;
wire    [1:0]                   lut_attr;
wire    [2:0]                   lut_tc;
wire    [12:0]                  curnt_tlp_byte_len;
wire                            func_match;
wire                            reqid_match;
wire                            int_reqid_match;
wire                            reqid_match_lut;


// Extract fields from Completion Header
assign cpl_bcm                  = filt_lut_hdr[52];
assign cpl_reqid                = {filt_lut_hdr[71:64], filt_lut_hdr[79:72]};
assign dw_len                   = {filt_lut_hdr[17:16], filt_lut_hdr[31:24]};

assign rcvd_cpl_tlp_tag         = {tag_bits_13_to_10,filt_lut_hdr[15], filt_lut_hdr[11],filt_lut_hdr[87:80]};
// tag size is 14bit but we do not enable 14bit requester capability while LUT size is less than 1K. Only 10/8 bit requester capabilities are enabled.
wire rcvd_cpl_14bit_tag;
assign rcvd_cpl_14bit_tag       = |rcvd_cpl_tlp_tag[13:8];

assign rcvd_tlp_byte_cnt[11:0]  = {filt_lut_hdr[51:48], filt_lut_hdr[63:56]};
assign rcvd_tlp_byte_cnt[12]    =  !(|rcvd_tlp_byte_cnt[11:0]);
assign rcvd_tlp_low_addr        = filt_lut_hdr[94:88];
assign tc                       = filt_lut_hdr[14:12];
assign attr                     = filt_lut_hdr[21:20];

// Extract LUT Address
// tag size is 14bit but we do not enable 14bit requester capability while LUT size is less than 1K. Only 10/8 bit requester capabilities are enabled.
wire [TAG_SIZE-1:0] rcvd_cpl_tlp_tag_mapped;
assign rcvd_cpl_tlp_tag_mapped[7:0] = rcvd_cpl_tlp_tag[7:0];
assign rcvd_cpl_tlp_tag_mapped[13:8] = rcvd_cpl_14bit_tag ? (rcvd_cpl_tlp_tag[13:8]-6'h01) : 6'h00;

wire lut_filt_np_req_is_a_memrd  = lut_np_req_type_decoded == E_NP_REQ_TX_MEMRD_NON_ATS;
       wire lut_filt_np_req_is_a_cfg    = (lut_np_req_type_decoded == E_NP_REQ_TX_CFG_WR) || (lut_np_req_type_decoded == E_NP_REQ_TX_CFG_RD);
        wire np_req_is_a_ats    = (lut_np_req_type_decoded == E_NP_REQ_TX_MEMRD_ATS) ;
     wire np_req_is_a_atomic = (lut_np_req_type_decoded == E_NP_REQ_TX_ATOMIC) ;
 wire np_req_is_a_dmwr   = (lut_np_req_type_decoded == E_NP_REQ_TX_DMWR) ;
wire lut_filt_np_req_is_a_mem    = lut_filt_np_req_is_a_memrd
        || np_req_is_a_ats
     || np_req_is_a_atomic
 || np_req_is_a_dmwr
                                   ;

wire np_req_is_a_memrd_or_dmwr = lut_filt_np_req_is_a_memrd || np_req_is_a_dmwr;
wire np_req_is_a_cfg_or_dmwr   = lut_filt_np_req_is_a_cfg || np_req_is_a_dmwr ;

// ----------------------------------------------------------
// Decode Logic
// ----------------------------------------------------------
//
wire                            status_sc;
wire                            status_ur;
wire                            status_ca;
wire                            status_crs;
wire                            reserved_status;
wire    [1:0]                   byte_offset;

assign  status_sc               = (filt_lut_cpl_status == `SU_CPL_STATUS);  // Successful  Completion
assign  status_ur               = (filt_lut_cpl_status == `UR_CPL_STATUS);  // Unsupported Request
assign  status_ca               = (filt_lut_cpl_status == `CA_CPL_STATUS);  // Completion  Abort
assign  status_crs              = (filt_lut_cpl_status == `CRS_CPL_STATUS); // Request Retry Status
assign  reserved_status         = !(status_sc  || status_ur  || status_ca  || status_crs);

assign  byte_offset[0]          =  rcvd_tlp_low_addr[0] && !(np_req_is_a_atomic && cfg_filter_rule_mask[`CX_FLT_UNMASK_ATOMIC_SPECIFIC_RULES]) ;
assign  byte_offset[1]          =  (rcvd_tlp_low_addr[0] ^ rcvd_tlp_low_addr[1]) && !(np_req_is_a_atomic && cfg_filter_rule_mask[`CX_FLT_UNMASK_ATOMIC_SPECIFIC_RULES]) ; 

assign  curnt_tlp_byte_len      = (|byte_offset) ? {({filt_lut_dwlenEq0,dw_len} - 1'b1), byte_offset} :  {filt_lut_dwlenEq0,dw_len, byte_offset}; // (0 value means 4K)


assign  cpl_eot                 = filt_lut_eot;


assign  cpl_last                = ((curnt_tlp_byte_len >= rcvd_tlp_byte_cnt) & !cpl_bcm) | !status_sc
                                  || (np_req_is_a_ats && rcvd_tlp_byte_cnt[11:0] == {dw_len, 2'b00})
                                  ;
wire                            byte_cnt_match;
wire                            low_addr_match;
wire                            last_filter;
// When two CMPLT_D TLPs with the same tag are received together and this is
// the second TLP add the byte_length of the first TLP to the Byte Count we
// received in this TLP. It seems we are adding two different quantities since
// a byte count is normally total outstanding byte count for this
// request(unless BCM is set) and the byte length is the actual number of
// completion bytes in the TLP.
// However when checking that the byte count of a completion matches we need
// to check that byte count stored in the LUT is the same as the byte count
// received in the TLP. In the case where two TLPs are received the last
// filter must adjust it's received byte count by the amount of data received
// in the first completion before checking against the value stored in the
// LUT.
wire [12:0] total_rcvd_byte_cnt;
// spyglass disable_block W164a
// SMD: Identifies assignments in which the LHS width is less than the RHS width
// SJ: This logic is has already been expanded to 13 bits to account for
// overflow. The maximum byte count is 4096.
assign total_rcvd_byte_cnt = (same_tag && !prev_cpl_abort && last_filter) ?
    prev_byte_len + rcvd_tlp_byte_cnt :
    rcvd_tlp_byte_cnt;
// spyglass enable_block W164a
assign  last_filter = FLT_NUM == `CX_RADM_FORMQ_N_READ_PORT_VC - 1;
wire    [6:0]                   lut_low_addr;
wire    [12:0]                  remain_byte_cnt;
wire    [11:0]                  stored_byte_cnt;
wire    [CPL_ENTRY_WIDTH2-1:0]  update_lut_byte_cnt;
wire    [6:0]                   next_low_addr;
// spyglass disable_block W164a
// SMD: LHS width is less than the RHS width in assignment.
// SJ: Right side addition value can overflow but we do not need that value anymore.
assign next_low_addr            = lut_vec2[LOW_ADDR_INDEX2+LOW_ADDR_WD2-1:LOW_ADDR_INDEX2] + curnt_tlp_byte_len[6:0];
// spyglass enable_block W164a
 
assign stored_byte_cnt          = lut_vec2[BYTECNT_INDEX2+BYTECNT_WD2-1 : BYTECNT_INDEX2];

// spyglass disable_block W164a
// SMD: Identifies assignments in which the LHS width is less than the RHS width
// SJ: 'remain_byte_cnt' logic should perhaps be expanded to 14-bit to account for overflow 
assign remain_byte_cnt          = cpl_bcm ?
    ({1'b0, stored_byte_cnt} - {1'b0, total_rcvd_byte_cnt[11:0]}) :
    rcvd_tlp_byte_cnt - curnt_tlp_byte_len;  // curnt_tlp_byte_len = 00 -> means 4K,
// spyglass enable_block W164a

// The next bytecnt is the number of bytes received in this TLP
assign next_byte_len = curnt_tlp_byte_len;

assign update_lut_byte_cnt      = {remain_byte_cnt[11:0], next_low_addr};

assign  byte_cnt_match          =                                  (np_req_is_a_ats) || 
                                  (cpl_bcm | (stored_byte_cnt == total_rcvd_byte_cnt[11:0]) | cfg_filter_rule_mask[`CX_FLT_MASK_CPL_LEN_MATCH]);
assign  low_addr_match          =                                  (np_req_is_a_ats) ||
                                  (np_req_is_a_atomic && cfg_filter_rule_mask[`CX_FLT_UNMASK_ATOMIC_SPECIFIC_RULES]) ||
                                  ((np_req_is_a_memrd_or_dmwr ? rcvd_tlp_low_addr[6:0] ==
                                   lut_low_addr : rcvd_tlp_low_addr == 0)
                                   | cfg_filter_rule_mask[`CX_FLT_MASK_CPL_LEN_MATCH]);

// Lower address checking
assign lut_low_addr     = (same_tag && !prev_cpl_abort && last_filter) ?
    next_low_addr : lut_vec2[LOW_ADDR_INDEX2+LOW_ADDR_WD2-1:LOW_ADDR_INDEX2];


  assign  lut_pfuncid             = lut_vec[FUNC_NUM_INDEX -1: 0];
  assign  func_match              = (lut_pfuncid  == cpl_reqid[PF_WD-1:0])  || cfg_filter_rule_mask[`CX_FLT_MASK_CPL_FUNC_MATCH];
  assign  int_reqid_match             = (cpl_reqid[15:3] == {cfg_pbus_num, cfg_pbus_dev_num});

assign reqid_match = int_reqid_match || cfg_filter_rule_mask[`CX_FLT_MASK_CPL_REQID_MATCH ];
// cfg_p2p_track_cpl_to=0: P2P NP is not in LUT, check if reqid match core reqid for LUT update;
// cfg_p2p_track_cpl_to=1: P2P NP is in LUT, do not check if reqid match core reqid for LUT update;
assign reqid_match_lut = int_reqid_match || cfg_p2p_track_cpl_to;

assign  lut_filt_vendor_msg_id_match     = reqid_match;



wire attr_match;
wire tc_match;

assign lut_attr                 = lut_vec[ATTR_INDEX-2: TC_INDEX];
assign lut_tc                   = lut_vec[TC_INDEX-1:BYTECNT_INDEX];

assign attr_match               = (lut_attr    == attr)                                          ||  cfg_filter_rule_mask[`CX_FLT_MASK_CPL_ATTR_MATCH  ];

assign tc_match                 = (lut_tc      == tc)                                            ||  cfg_filter_rule_mask[`CX_FLT_MASK_CPL_TC_MATCH    ];

wire lut_14bit_tag_entry;
assign lut_14bit_tag_entry      = lut_vec[E_14BIT_TAG_INDEX -1 : NP_REQ_TYPE_INDEX];
wire lut_10bit_tag_entry;
assign lut_10bit_tag_entry      = lut_vec[E_10BIT_TAG_INDEX -1 : NP_REQ_TYPE_INDEX];

reg    [TAG_SIZE-1:0]            paded_rcv_tag;
always @(*) begin
  paded_rcv_tag = 0;
  paded_rcv_tag[CPL_LUT_PTR_WD-1:0] = rcvd_cpl_tlp_tag_mapped[CPL_LUT_PTR_WD-1:0];
end

assign  tag_err                 = (paded_rcv_tag != rcvd_cpl_tlp_tag_mapped) && !cfg_filter_rule_mask[`CX_FLT_MASK_CPL_TAGERR_MATCH]
                                  ;

// ----------------------------------------------------------
// Completion Filtering Logic
// ----------------------------------------------------------
// Error should be reported only one type when multiple errors happened
// within the same TLP.
// ECRC error has the highest priority
// Unexpected completion has the second highest priroity since it is unexpected,
// we will dropped it silently.
// when malformed or unsuccessful completion received, it will terminate
// current completion and send up the completions to application with status of non sucessful.
// When discard ECRC packet is desired, it will be treated as an unexpected
// completion such that the completion will be dropped silently and lookup table will not be updated.
wire  ecrc_err;
wire  valid_at_lut_addr;
wire  int_valid_at_lut_addr;

wire match_14bit_tag;
assign match_14bit_tag = (lut_14bit_tag_entry == rcvd_cpl_14bit_tag);


assign  int_valid_at_lut_addr       = valid && 
    //`ifdef CX_RADM_FILTER_TO_LUT_PIPE
    !(|going_to_clear_valid) &&
    //`endif                                   
    match_14bit_tag &&
    !(same_tag && !prev_cpl_abort && last_filter && prev_cpl_last);

// int_valid_at_lut_addr is used when update LUT. Always check if tag is entered in LUT
// valid_at_lut_addr is used to check if cpl is unexpected cpl
assign valid_at_lut_addr = cfg_filter_rule_mask[`CX_FLT_MASK_CPL_IN_LUT_CHECK] || int_valid_at_lut_addr;

assign  ecrc_err                = filt_lut_ecrc_err && !cfg_filter_rule_mask[`CX_FLT_MASK_CPL_ECRC_DISCARD ];

assign  lut_filt_unexpected_cpl_err      = ((!valid_at_lut_addr || !func_match ||
    !reqid_match || tag_err || (!byte_cnt_match || !low_addr_match ) &&
    np_req_is_a_memrd_or_dmwr)
    ) && !ecrc_err    // ECRC error has high priority than unexpected completion
    ;


assign  lut_filt_cpl_mlf_err             = 
    ( ((!byte_cnt_match || !low_addr_match) && !np_req_is_a_memrd_or_dmwr || !attr_match ||
      !tc_match
      || !np_req_is_a_cfg_or_dmwr && status_crs // when request is not a config_or_dmwr request but with CRS completion status
      ) && !lut_filt_unexpected_cpl_err );

wire    cpl_abort;
wire    cpl_abort_without_tdisp = lut_filt_unexpected_cpl_err | ecrc_err | lut_filt_cpl_mlf_err
                                    ;


assign  cpl_abort = cpl_abort_without_tdisp;

wire    next_cpl_abort;
assign  next_cpl_abort = cpl_abort;

assign  lut_filt_cpl_ur_err              = (status_ur || reserved_status) && !cpl_abort;
assign  lut_filt_cpl_ca_err              = status_ca && !cpl_abort;



// ----------------------------------------------------------
// Completion Lookup Table Update Logic
// ----------------------------------------------------------
// Don't allow this filter to generate an update when
// 1) it has the same tag as another filter and
// 2) it is not the last filter unless it has the last completion or
// 3) it is the last filter but the other filter had the last completion
wire mask_lut_update;
assign mask_lut_update = same_tag && !prev_cpl_abort && (!last_filter && !cpl_last || last_filter && prev_cpl_last);

assign  update_lut_content =
    !mask_lut_update && !cpl_abort && cpl_eot &&
    !( filt_lut_malform_tlp_err || filt_lut_dllp_err);

always @(posedge core_clk or negedge core_rst_n)
begin: OUTPUT_CONTROL_DRIVE_PROCESS
    if (!core_rst_n) begin
        lut_filt_cpl_last          <= #TP 0;
        lut_filt_cpl_abort         <= #TP 0;

    end else begin
        lut_filt_cpl_last          <= #TP cpl_last;
        lut_filt_cpl_abort         <= #TP cpl_abort; 
    end
end



/*
// Will be added updated assertion based on the current one later.
`ifdef SNPS_ASSERT_ON
`ifndef SYNTHESIS

property p_np_req_type_decoded_is_onehot;
    @(posedge core_clk) disable iff(core_rst_n !== 1'b1)
      1 |-> $onehot0(lut_np_req_type_decoded);
endproperty
ap_np_req_type_decoded_is_onehot : assert property(p_np_req_type_decoded_is_onehot) else begin
    $error("%t %m: ERROR, lut_np_req_type_decoded is supposed to be onehot0", $realtime);
    @(posedge core_clk) $finish;
end

logic [NP_REQ_TYPE_DECODED_WD-1:0] aux_lut_np_req_type_decoded;
assign aux_lut_np_req_type_decoded = (lut_np_req_type_decoded) ? lut_np_req_type_decoded : 0
                                     `ifdef CX_IS_DM_OR_RC
                                        | ((device_type == `PCIE_EP)? 1 << NP_REQ_CFG_INDEX : 0)
                                     `endif
                                     `ifdef ATS_TX_ENABLE
                                        | ((device_type == `PCIE_RC)? 1 << NP_REQ_ATS_INDEX : 0)
                                     `endif
                                     ;

covergroup cg_np_req_type_decoded @(posedge core_clk);
  option.per_instance =1;
  cp_np_req_type_decoded: coverpoint aux_lut_np_req_type_decoded
  {
    bins MemRd_req = {(1 << NP_REQ_MEMRD_INDEX)};
    bins IO_req = {(1 << NP_REQ_IO_INDEX)};
    `ifdef CX_IS_DM_OR_RC
      bins Cfg_req = {(1 << NP_REQ_CFG_INDEX)};
    `endif
    `ifdef ATS_TX_ENABLE
      bins Ats_req = {(1 << NP_REQ_ATS_INDEX)};
    `endif
    `ifdef CX_ATOMIC_ENABLE
      bins Atomic_req = {(1 << NP_REQ_ATOMIC_INDEX)};
    `endif
    `ifdef CX_DEF_MEM_WR_ENABLE
      bins DefMWr_req = {(1<< NP_REQ_DMWR_INDEX)};
    `endif
  }
endgroup // cg_np_req_type_decoded

cg_np_req_type_decoded cg_np_req_type_decoded_inst;
initial cg_np_req_type_decoded_inst=new();

covergroup cg_ats_atomic_atomic_special_rules @(posedge core_clk);
`ifdef ATS_TX_ENABLE
    cp_ats_length_special_rule : coverpoint ((np_req_is_a_ats && rcvd_tlp_byte_cnt[11:0] == {dw_len, 2'b00}) && !(((curnt_tlp_byte_len >= rcvd_tlp_byte_cnt) & !cpl_bcm) | !status_sc));
`endif
`ifdef CX_ATOMIC_ENABLE
    cp_atomic_lower_address_special_rule : coverpoint {np_req_is_a_atomic, cfg_filter_rule_mask[`CX_FLT_UNMASK_ATOMIC_SPECIFIC_RULES]} 
      {
       bins b1 = {2'b10};
       bins b2 = {2'b11};
       }
`endif
endgroup // cg_ats_length_special_rule

cg_ats_atomic_atomic_special_rules cg_ats_atomic_atomic_special_rules_inst;
initial cg_ats_atomic_atomic_special_rules_inst = new();

`ifdef ATS_TX_ENABLE
property p_np_req_is_never_ats_filter;
    @(posedge core_clk) disable iff(core_rst_n !== 1'b1)
      !cfg_filter_rule_mask[`CX_FLT_UNMASK_ATS_SPECIFIC_RULES] |-> !np_req_is_a_ats;
endproperty // p_np_req_is_never_ats_filter

ap_np_req_is_never_ats_filter : assert property(p_np_req_is_never_ats_filter) else begin
    $error("%t %m: ERROR, np_req_is_ats can't be asserted with this filter setting", $realtime);
    @(posedge core_clk) $finish;
end
`endif

property p_np_reqs_not_unknown;
    @(posedge core_clk) disable iff(core_rst_n !== 1'b1)
      1 |-> !$isunknown(np_req_is_a_memrd) 
        && !$isunknown(np_req_is_a_io) 
`ifdef CX_IS_DM_OR_RC && !$isunknown(np_req_is_a_cfg) `endif
`ifdef ATS_TX_ENABLE && !$isunknown(np_req_is_a_ats) `endif
`ifdef CX_ATOMIC_ENABLE && !$isunknown(np_req_is_a_atomic) `endif
`ifdef CX_DEF_MEM_WR_ENABLE && !$isunknown(np_req_is_a_dmwr)`endif
                                                 ;
endproperty // p_np_reqs_not_unknown

ap_np_reqs_not_unknown : assert property(p_np_reqs_not_unknown)else begin
    $error("%t %m: ERROR, np_reqs are undefined", $realtime);
    @(posedge core_clk) $finish;
end


`endif
`endif
*/

`ifndef SYNTHESIS
//VCS coverage off
//VCS coverage on
`endif // !SYNTHESIS




endmodule
