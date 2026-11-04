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
// ---    $Revision: #4 $
// ---    $Id: //dwh/pcie_iip/main/fairbanks/design/Adm_ms/target_cpl_lut_ms.sv#4 $
// -------------------------------------------------------------------------

// -----------------------------------------------------------------------------
// --- Module Description:
// -----------------------------------------------------------------------------
// --- This module handles parsing of transmit CPL Transactions (TLPs).
// --- Its main functions are:
// ---    (1) Store entries for each non-posted requested received
// ---    (2) Match transmitted completions with outstanding read requests
// ---    (3) Report completion timeout
// -----------------------------------------------------------------------------

`include "include/DWC_pcie_ctl_all_defs.svh"

 
 module target_cpl_lut_ms (
//---------- inputs --------------
    core_clk,
    core_rst_n,
    cfg_tc_struc_vc_map,
    device_type,
    trgt1_radm_halt,
    radm_trgt1_hv,
    radm_trgt1_eot,
    radm_trgt1_ecrc_err,
    radm_trgt1_tlp_abort,
    radm_trgt1_dllp_abort,
    radm_trgt1_fmt,
    radm_trgt1_type,
    radm_trgt1_tc,
    radm_trgt1_attr,
    radm_trgt1_reqid,
    radm_trgt1_req_segment,
    radm_trgt1_tag,
    radm_trgt1_dw_len,
    radm_trgt1_first_be,
    radm_trgt1_last_be,
    radm_trgt1_addr,
    radm_trgt1_func_num,
    radm_trgt1_at,

    // transmit completion request interface
    xadm_client_halt,
    client_tlp_hv,
    client_tlp_eot,
    client_tlp_bad_eot,
    client_tlp_fmt,
    client_tlp_type,
    client_cpl_bcm,
    client_cpl_status,
    client_tlp_byte_len,
    client_cpl_lookup_id,

    cfg_trgt_cpl_lut_delete_entry,
    flit_mode,
    cfg_rcb_128,

    current_data_rate,


    radm_grant_tlp_type,
    trgt_lut_trgt1_radm_pkt_halt,
    radm_trgt1_dma_grant,
    radm_trgt1_dma_cpl_rlsd,
    trgt_lut_dma_pkt_halt,
    // ------ Outputs ------
    // Tag ID control output
    trgt_lookup_id,
    trgt_lookup_empty,
    trgt_cpl_lut_empty,

    // Completion header information output
    client_cpl_byte_cnt,
    client_tlp_tc,
    client_tlp_req_seqment,
    client_tlp_attr,
    client_cpl_req_id,
    client_cpl_tag,
    client_cpl_low_addr,
    client_cpl_type,

    cfg_remote_max_bridge_tag,

     // Indicates to the received ompletion is the last one
     radm_trgt1_cpl_lookup_id_rlsd,
     // Indicates non-posted TLP
     radm_trgt1_lookup_id_consmd,
    // completion timeout error report interface
    trgt_cpl_timeout,
    trgt_timeout_cpl_tc,
    trgt_timeout_cpl_attr,
    trgt_timeout_cpl_len,
    trgt_timeout_lookup_id,
    trgt_timeout_cpl_func_num
);
parameter INST                  = 0;                            // The uniquifying parameter for each port logic instance.

// -----------------------------------------------------------------------------
// --- Parameters
// -----------------------------------------------------------------------------
parameter TRGT_CPL_LUT_ENTRY_WD = `TRGT_CPL_LUT_ENTRY_WD;
parameter NB                    = `CX_NB;                        // Number of symbols (bytes) per clock cycle
parameter NVC                   = `CX_NVC;                       // Number of virtual channels
parameter CPL_LUT_DEPTH         = `CX_REMOTE_MAX_TAG +1;         // number of max tag that this core is configured to run
parameter CPL_LUT_PTR_WD        = `CX_REMOTE_LUT_PTR_WIDTH;      // Number of bits needed to index completion table
parameter REMOTE_LOOKUPID_WD    = `CX_REMOTE_LOOKUPID_WD;        // Number of bits needed to index completion table
parameter TIMEOUT_GRANULARITY   = `CX_TIMEOUT_GRANULARITY;       // Width of timeout value (granularity)
                                                                 // Completion timer value scaled down by dividing the granularity. Min > CPL_LUT_PTR_WD
parameter CPL_TIMEOUT_VALUE_INT = `CX_TRGT_CPL_BASE_TIMER_VALUE;
parameter CPL_TIMER_TW          = `CX_TRGT_CPL_BASE_TIMER_TW;    // timer width of the timeout value
parameter TP                    = `TP;                           // Clock to Q delay (simulator insurance)
parameter NF                    = `CX_NFUNC;                     // Number of function supported
parameter PF_WD                 = `CX_NFUNC_WD;                  // Width of virtual function number signal
parameter   BUSNUM_WD           = `CX_BUSNUM_WD;    // A vector width for bus number that we supported per function. Normally this value is 8bits. But for the multiple functions that we support, if a per function per bus number is selected by customer, then this bus width will be 64bits because of TLP with func number 0-7 can be received even if the NF is set less than 8.
parameter   DEVNUM_WD    = `CX_DEVNUM_WD;               // A vector width for dev number that we supported per function. Normally this value is 5bits. But for the multiple functions that we support, if a per function per bus number is selected by customer, then this bus width will be 39 because of TLP with func number 0-7 can be received even if the NF is set less than 8.

localparam TIMEOUT_ONLY_INFORMATIVE_IN_TRGT_CPL_LUT = 1; // NO DELETE ENTRY in TRGT_CPL_LUT

localparam TAG_SIZE              = `CX_TAG_SIZE;

localparam CNT_WD                = `CX_LOGBASE2(CPL_LUT_DEPTH)+1;
// Prefix params from RX side 
parameter   PRFX_W_PAR      = `FLT_Q_PRFX_WIDTH;
parameter   PRFX_PROT_WD    = `CX_RX_PRFX_PAR_WD;
parameter   PRFX_WO_PAR     =  PRFX_W_PAR - PRFX_PROT_WD;

// Prefix params from TX side  (calculated exactly sa RX, so they will match)
// Note that CX_TLP_PREFIX_ENABLE is not Enabled for CX_IDE_ENABLE==1, so:
// CX_IDE_ENABLE==1 --> CX_TLP_PREFIX_ENABLE==1 (default) --> PRFX_DW === PRFX_W_PAR
parameter   NW_PRFX         = `CX_NPRFX;
parameter   PRFX_PAR_WD     = `CX_PRFX_PAR_WD;
parameter   CX_TLP_PREFIX_ENABLE_VALUE = `CX_TLP_PREFIX_ENABLE_VALUE;
parameter   PRFX_DW         = (`CC_DEVICE_TYPE==`CC_SW) ? ((32*NW_PRFX)+ PRFX_PAR_WD) : (CX_TLP_PREFIX_ENABLE_VALUE ? (32*NW_PRFX)+ PRFX_PAR_WD : 32);
parameter   RAS_PROT_RANGE       = `CX_RAS_PROT_RANGE;
parameter   RAS_PROT_TYPE        = `CX_RAS_PROT_TYPE;
parameter   RAS_PARITY_MODE      = `CX_RAS_PARITY_MODE;
parameter   ERROR_INJ_EN_WD      = `CX_RAS_ERROR_INJ_EN_WD;
parameter   ERROR_INJ_MASK_WD    = `CX_RAS_ERROR_INJ_MASK_WD;

// -------------------------------- Inputs -------------------------------------
//
input               core_clk;
input               core_rst_n;

input [23:0]        cfg_tc_struc_vc_map;          // Index by TC, returns structure VC ID number
input [3:0]         device_type;
input               trgt1_radm_halt;
input               radm_trgt1_hv;
input               radm_trgt1_eot;
input               radm_trgt1_ecrc_err;
input               radm_trgt1_tlp_abort;
input               radm_trgt1_dllp_abort;
input   [1:0]       radm_trgt1_fmt;
input   [4:0]       radm_trgt1_type;
input   [2:0]       radm_trgt1_tc;
input   [`TCTF_ATTRIBUTE]       radm_trgt1_attr;
input   [15:0]      radm_trgt1_reqid;
input   [9-1:0]     radm_trgt1_req_segment ;
input   [TAG_SIZE-1:0] radm_trgt1_tag;
input   [9:0]       radm_trgt1_dw_len;
input   [3:0]       radm_trgt1_first_be;
input   [3:0]       radm_trgt1_last_be;
input   [6:0]       radm_trgt1_addr;
input [PF_WD-1:0]   radm_trgt1_func_num;
input   [1:0]       radm_trgt1_at;

input               xadm_client_halt;
input               client_tlp_hv;
input               client_tlp_eot;
input               client_tlp_bad_eot;                        // nullified TLP should be ignored
input   [1:0]       client_tlp_fmt;
input   [4:0]       client_tlp_type;
input   [REMOTE_LOOKUPID_WD-1:0] client_cpl_lookup_id;
input   [12:0]      client_tlp_byte_len;
input               client_cpl_bcm;
input   [2:0]       client_cpl_status;

input   [31:0]      cfg_trgt_cpl_lut_delete_entry;            // (PL) trgt_cpl_lut delete one entry
input              flit_mode;                                 // If set link is operating in flit mode
input               cfg_rcb_128;
input   [2:0]       current_data_rate;                          // 0=running at gen1 speeds, 1=running at gen2 speeds, 2-gen3, 3-gen4


input   [CPL_LUT_PTR_WD-1:0]       cfg_remote_max_bridge_tag;

input  [(NVC*3)-1:0]               radm_grant_tlp_type;
// -------------------------Outputs --------------------------------------------
output  [REMOTE_LOOKUPID_WD-1:0] trgt_lookup_id; 
output              trgt_lookup_empty;
output              trgt_cpl_lut_empty;

output  [11:0]      client_cpl_byte_cnt;
output  [2:0]       client_tlp_tc;
output  [`TCTF_ATTRIBUTE]       client_tlp_attr;
output  [9-1:0]     client_tlp_req_seqment ;
output  [15:0]      client_cpl_req_id;
output  [TAG_SIZE-1:0] client_cpl_tag;
output  [6:0]       client_cpl_low_addr;
output              client_cpl_type;



// Indicates to the received ompletion is the last one
output [NVC-1:0]    radm_trgt1_cpl_lookup_id_rlsd;
output              radm_trgt1_lookup_id_consmd;
output              trgt_cpl_timeout;
output  [2:0]       trgt_timeout_cpl_tc;
output  [PF_WD-1:0] trgt_timeout_cpl_func_num;
output  [`TCTF_ATTRIBUTE]       trgt_timeout_cpl_attr;
output  [11:0]      trgt_timeout_cpl_len;
output  [REMOTE_LOOKUPID_WD-1:0] trgt_timeout_lookup_id; 

output  [(NVC*3)-1:0]      trgt_lut_trgt1_radm_pkt_halt;
input                      radm_trgt1_dma_grant;
input                      radm_trgt1_dma_cpl_rlsd;
output                     trgt_lut_dma_pkt_halt;
  

logic                       trgt_cpl_timeout;
logic   [2:0]               trgt_timeout_cpl_tc;
logic   [PF_WD-1:0]         trgt_timeout_cpl_func_num;
wire  [PF_WD-1:0]         timeout_cpl_func_num;


// -------------------------- Internal Signals  --------------------------------
wire                last_avail_tag;
wire                last_cpl;
wire                np;
wire                tlp_is_np;
wire                init_wr;
wire                last_clr;
wire [CPL_LUT_PTR_WD-1:0]        muxd_update_addr;

wire   [31:0]       wCPL_TIMEOUT_VALUE;
wire   [31:0]       wCPL_TIMEOUT_VALUE_INT;
wire   [31:0]       wCM_TRGT_CPL_BASE_TIMER_VALUE_RATEA;
wire   [31:0]       wCM_TRGT_CPL_BASE_TIMER_VALUE_RATEB;

assign wCM_TRGT_CPL_BASE_TIMER_VALUE_RATEA = `CM_TRGT_CPL_BASE_TIMER_VALUE_RATEA;
assign wCM_TRGT_CPL_BASE_TIMER_VALUE_RATEB = `CM_TRGT_CPL_BASE_TIMER_VALUE_RATEB;

assign  wCPL_TIMEOUT_VALUE_INT = CPL_TIMEOUT_VALUE_INT;
assign  wCPL_TIMEOUT_VALUE     = wCPL_TIMEOUT_VALUE_INT;

assign client_cpl_type = ({client_tlp_fmt, client_tlp_type} == `CPLLK)
                          | ({client_tlp_fmt, client_tlp_type} == `CPLDLK)
                          | ({client_tlp_fmt, client_tlp_type} == `CPL)
                          | ({client_tlp_fmt, client_tlp_type} == `CPLD);

wire trgt1_cpl_type;
assign trgt1_cpl_type             = (({radm_trgt1_fmt,radm_trgt1_type} == `CPLLK) | ({radm_trgt1_fmt,radm_trgt1_type} == `CPLDLK)  ||
                                      ({radm_trgt1_fmt,radm_trgt1_type} == `CPL) | ({radm_trgt1_fmt,radm_trgt1_type} == `CPLD));
logic    latchd_cpl_type;
logic    latchd_last_cpl;

//  ---- Last byte calculation  -------
// -- f_last_cpl --
// This completion is the last for the request when the length, bytecount,
// and lower addr[1:0] fields imply that this completion contains the full
// amount of data to satisfy the original request.  If the BCM bit is set,
// this packet cannot possibly be the last completion packet.
function automatic f_last_cpl;
input   [9:0]   pkt_length;
input   [11:0]  pkt_bytecount;
input           pkt_bcm;
input   [1:0]   pkt_lwr_addr;
input   [2:0]   pkt_cplstatus;

logic             length_1k;              // If the length field represents 1K Dwords
logic     [10:0]  fld_length;             // The length field, including 1K
                                        // compensation
logic             bytecount_4k;           // If the bytecount field represents 4K
                                        // bytes
logic     [12:0]  fld_bytecount;          // The bytecount field, including 4K
                                        // compensation
logic     [12:0]  len_m_bytecount;        // Length field (in bytes) minus the
                                        // bytecount field
logic     [2:0]   lwr_addr_p_3;           // lower 2 bits of the lower address
                                        // field plus 3
logic             last_cpl_cond1;         // Last completion condition 1 (<= addr+3)
logic             last_cpl_cond2;         // Last completion condition 2 (>= addr)
logic             len_m_bc_lt_8;          // Length minus bytecount is less than 8
                                        // - used to minimize comparison logic

begin
    // Determine the real length of the packet by handling the all 0's case
    length_1k       = (pkt_length == 10'd0);
    fld_length      = {length_1k, pkt_length};
    // Determine the real bytecount of the packet by handling the all 0's case
    bytecount_4k    = (pkt_bytecount == 12'd0);
    fld_bytecount   = {bytecount_4k, pkt_bytecount};

    // If the following equation is satisfied, this is the last completion
    // packet:
    //    (length-1)*4 - lwr_addr + 1 <= bytecount <= (length)*4 - lwr_addr
    // Simplifying:
    // length*4 - bytecount <= lwr_addr + 3
    //     AND
    // length*4 - bytecount >= lwr_addr

    // Length minus bytecount field (usually negative, max positive value: 6,
    // max negative value: 4 - 4096 = -4092 = 13'b1_0000_0000_0100)
    // spyglass disable_block W164a
    // SMD: Identifies assignments in which the LHS width is less than the RHS width
    // SJ: This logic is has already been expanded to 13 bits to account for
    // overflow. The maximum byte count is 4096.
    len_m_bytecount = {fld_length, 2'b00} - fld_bytecount;
    // spyglass enable_block W164a

    // Lower 2 bits of the lower address field plus 3 (max value: 6)
    lwr_addr_p_3    = pkt_lwr_addr + 2'd3;

    // Verify length - bytecount is less than 8 to flush out negative numbers
    // and cases that definitely don't count (last completion will have
    // length-bytecount between 0 and 6)
    len_m_bc_lt_8   = (len_m_bytecount[12:3] == 0);

    // length*4 - bytecount <= lwr_addr + 3
    last_cpl_cond1  = len_m_bc_lt_8 & (len_m_bytecount[2:0] <= lwr_addr_p_3);

    // length*4 - bytecount >= lwr_addr
    last_cpl_cond2  = (len_m_bc_lt_8 & (len_m_bytecount[2:0] >= {1'b0, pkt_lwr_addr}));

    // This function is asserted when the completion being processed is the
    // last completion for the request - to satisfy this, the two "last
    // completion conditions" must be true.
    // If the packet has the BCM bit set, it can't be the last
    // completion.
    f_last_cpl      = (pkt_cplstatus != `SU_CPL_STATUS) |
                      (last_cpl_cond1 & last_cpl_cond2) & ~pkt_bcm;
end
endfunction // last_cpl

//---- Find next free TCB entry ---------------------------
logic [CPL_LUT_PTR_WD-1:0]        tcb_addr;
logic [CPL_LUT_DEPTH-1:0]         tcb_table;
logic [TRGT_CPL_LUT_ENTRY_WD-1:0] tct_table [0:CPL_LUT_DEPTH-1];
wire                            trgt_lookup_empty;
logic [REMOTE_LOOKUPID_WD-1:0]    latchd_next_avail_id;
wire  tag_not_available;
logic [CPL_LUT_PTR_WD:0]          tag_used_cnt;
wire  [CPL_LUT_PTR_WD-1:0]      timeout_addr;

assign trgt_cpl_lut_empty = (tag_used_cnt == 0);

assign trgt_lookup_empty = !(( (tag_used_cnt >= cfg_remote_max_bridge_tag+1 ) || (tag_used_cnt >=  CPL_LUT_DEPTH)) && tlp_is_np && radm_trgt1_hv);

integer idx;

always @(tcb_table or latchd_next_avail_id )
begin
    tcb_addr = 0;
    for (idx = CPL_LUT_DEPTH-1; idx >= 0; idx = idx - 1) begin
        if (~tcb_table[idx] & (latchd_next_avail_id != idx))
            tcb_addr = idx;
    end
end

wire [REMOTE_LOOKUPID_WD-1:0] trgt_lookup_id;

logic [CPL_LUT_PTR_WD:0] cfg_remote_max_bridge_tag_exp; // expanded to the width of tag_used_cnt
always @(*) begin : EXPAND_RMT_MAX_TAG
  cfg_remote_max_bridge_tag_exp = 0;
  cfg_remote_max_bridge_tag_exp[CPL_LUT_PTR_WD-1:0] = cfg_remote_max_bridge_tag;
end
assign tag_not_available = (tag_used_cnt > cfg_remote_max_bridge_tag_exp) | (init_wr & last_avail_tag);
assign last_avail_tag = (tag_used_cnt == cfg_remote_max_bridge_tag_exp);

logic [31:0] cfg_trgt_cpl_lut_delete_entry; // INPUT

wire delete_entry_en_1cycle;
wire delete_entry_en_1cycle_tcb_validated;
wire [CPL_LUT_PTR_WD-1:0] delete_entry_lookup_id;
wire [TRGT_CPL_LUT_ENTRY_WD-1:0] delete_entry_data;

assign delete_entry_en_1cycle = cfg_trgt_cpl_lut_delete_entry[31]; // Port Logic Register guarantees this bit is only set 1clk if WR_enble. See cdm_pl_reg.
assign delete_entry_lookup_id = cfg_trgt_cpl_lut_delete_entry[CPL_LUT_PTR_WD-1:0];
assign delete_entry_data      = tct_table[delete_entry_lookup_id];
assign delete_entry_en_1cycle_tcb_validated = delete_entry_en_1cycle & tcb_table[delete_entry_lookup_id];

assign last_clr = ((client_cpl_type & last_cpl & client_tlp_hv) | (!client_tlp_hv & latchd_cpl_type & latchd_last_cpl))
                   & !client_tlp_bad_eot & client_tlp_eot & !xadm_client_halt;

wire   last_clr_validated;
assign last_clr_validated = last_clr && tcb_table[muxd_update_addr];

always @(posedge core_clk or negedge core_rst_n)
begin
    if (~core_rst_n)
        tag_used_cnt <= #TP 0;

// it doesn't take into accout delete_entry_lookup_id == trgt_lookup_id.
// Condition {WR,CLR,Delete_entry} 3 possible agents
// Condition 100
    else if ((init_wr & !last_clr_validated) & !(delete_entry_en_1cycle_tcb_validated)) 
        tag_used_cnt <= #TP tag_used_cnt +1;
// Conditions 101 or 110 => tag_used_cnt <= #TP tag_used_cnt +0;
// Condition 111
    else if ((init_wr & (last_clr_validated & tcb_table[muxd_update_addr])) & (delete_entry_en_1cycle_tcb_validated)) 
            if (delete_entry_lookup_id == muxd_update_addr)      
               tag_used_cnt <= #TP tag_used_cnt;
            else
               tag_used_cnt <= #TP tag_used_cnt -1;
// Condition 000 => tag_used_cnt <= #TP tag_used_cnt +0;
// Condition 001
    else if ((!init_wr & !last_clr_validated) & (delete_entry_en_1cycle_tcb_validated)) 
        tag_used_cnt <= #TP tag_used_cnt -1;
// Condition 010
    else if ((!init_wr & (last_clr_validated & tcb_table[muxd_update_addr])) & !(delete_entry_en_1cycle_tcb_validated)) 
        tag_used_cnt <= #TP tag_used_cnt -1;
// Condition 011
    else if ((!init_wr & (last_clr_validated & tcb_table[muxd_update_addr])) & (delete_entry_en_1cycle_tcb_validated)) begin 
            if (delete_entry_lookup_id == muxd_update_addr)      
               tag_used_cnt <= #TP tag_used_cnt -1;
            else
               tag_used_cnt <= #TP tag_used_cnt -2; 
    end 
end

always @(posedge core_clk or negedge core_rst_n)
begin
    if (~core_rst_n) begin
        latchd_next_avail_id <= #TP 0;
    end else if (delete_entry_en_1cycle_tcb_validated & tag_not_available) begin
        latchd_next_avail_id <= #TP 0; 
        latchd_next_avail_id[CPL_LUT_PTR_WD-1:0] <= #TP delete_entry_lookup_id;
    end else if (last_clr_validated & tag_not_available) begin
        latchd_next_avail_id <= #TP 0;
        latchd_next_avail_id[CPL_LUT_PTR_WD-1:0] <= #TP muxd_update_addr;
    end else if (init_wr) begin
        latchd_next_avail_id <= #TP 0;
        latchd_next_avail_id[CPL_LUT_PTR_WD-1:0] <= #TP tcb_addr;
    end
end

assign trgt_lookup_id = latchd_next_avail_id;

//---- Initialize TCT entry -------------------------------
logic [2:0] np_decrvalue;
always @(radm_trgt1_first_be or radm_trgt1_last_be) begin
    // In order to determine the actual byte count requested, we look at the
    // length field and the first and last BE fields.  This comes from the
    // PCI-E spec table 2-21, p. 93 (as updated in Errata C6)
    // Packets with Last DW BE == 0000 will always have 1 in the length
    // field, so they are treated as a decrement as well
    casez ({radm_trgt1_first_be, radm_trgt1_last_be})
        8'b???1_1???, 8'b1??1_0000: np_decrvalue = 0;
        8'b???1_01??, 8'b??10_1???,
        8'b01?1_0000, 8'b1?10_0000: np_decrvalue = 1;
        8'b???1_001?, 8'b??10_01??,
        8'b?100_1???, 8'b0011_0000,
        8'b0110_0000, 8'b1100_0000: np_decrvalue = 2;
        8'b??10_0001, 8'b?100_001?,
        8'b1000_01??:               np_decrvalue = 4;
        8'b?100_0001, 8'b1000_001?: np_decrvalue = 5;
        8'b1000_0001:               np_decrvalue = 6;
        default:                    np_decrvalue = 3;
    endcase
end // always @ (radm_trgt1_first_be or radm_trgt1_last_be)

assign  np = (
//`ifdef CX_FLIT_MODE_ENABLE
//              ( flit_mode && {radm_trgt1_fmt, radm_trgt1_type} == `FLIT_MRD32) ||
//              (!flit_mode && {radm_trgt1_fmt, radm_trgt1_type} == `MRD32) ||
//`else // CX_FLIT_MODE_ENABLE
              ({radm_trgt1_fmt, radm_trgt1_type} == `MRD32)      ||
//`endif // CX_FLIT_MODE_ENABLE               
              ({radm_trgt1_fmt, radm_trgt1_type} == `MRD64)      ||
              ({radm_trgt1_fmt, radm_trgt1_type} == `DMWR32)     ||
              ({radm_trgt1_fmt, radm_trgt1_type} == `DMWR64)     ||
              ({radm_trgt1_fmt, radm_trgt1_type} == `MRDLK32)    ||
              ({radm_trgt1_fmt, radm_trgt1_type} == `MRDLK64)    ||
              ({radm_trgt1_fmt, radm_trgt1_type} == `IORD)       ||
              ({radm_trgt1_fmt, radm_trgt1_type} == `IOWR)       ||
              ({radm_trgt1_fmt, radm_trgt1_type} == `CFGRD0)     ||
              ({radm_trgt1_fmt, radm_trgt1_type} == `CFGWR0)     ||
              ({radm_trgt1_fmt, radm_trgt1_type} == `CFGRD1)     ||
              ({radm_trgt1_fmt, radm_trgt1_type} == `CFGWR1))    ||
              ({radm_trgt1_fmt, radm_trgt1_type} == `FETCHADD64) ||
              ({radm_trgt1_fmt, radm_trgt1_type} == `FETCHADD32) ||
              ({radm_trgt1_fmt, radm_trgt1_type} == `SWAP64)     ||
              ({radm_trgt1_fmt, radm_trgt1_type} == `SWAP32)     ||
              ({radm_trgt1_fmt, radm_trgt1_type} == `CAS32)      ||
              ({radm_trgt1_fmt, radm_trgt1_type} == `CAS64);

// As AtomicOp's can be more than 1 DWORD, we must hold the np
// flag until EOT at least.
logic latchd_np;

always @ (posedge core_clk or negedge core_rst_n)
begin
  if(!core_rst_n)
    latchd_np <= #TP 1'b0;
  else
    if(radm_trgt1_hv)
      latchd_np <= #TP np;
end

assign tlp_is_np = radm_trgt1_hv ? np : latchd_np;

wire  mem_rd;
assign mem_rd = (
//`ifdef CX_FLIT_MODE_ENABLE
//                ( flit_mode && {radm_trgt1_fmt, radm_trgt1_type} == `FLIT_MRD32) ||
//                (!flit_mode && {radm_trgt1_fmt, radm_trgt1_type} == `MRD32) ||
//`else // CX_FLIT_MODE_ENABLE
                ({radm_trgt1_fmt, radm_trgt1_type} == `MRD32)      ||
//`endif // CX_FLIT_MODE_ENABLE
                ({radm_trgt1_fmt, radm_trgt1_type} == `MRD64)   ||
                ({radm_trgt1_fmt, radm_trgt1_type} == `MRDLK32) ||
                ({radm_trgt1_fmt, radm_trgt1_type} == `MRDLK64));

wire atomic_fa_or_swp;
assign atomic_fa_or_swp = ({radm_trgt1_fmt, radm_trgt1_type} == `FETCHADD64)   ||
                          ({radm_trgt1_fmt, radm_trgt1_type} == `FETCHADD32)   ||
                          ({radm_trgt1_fmt, radm_trgt1_type} == `SWAP64)       ||
                          ({radm_trgt1_fmt, radm_trgt1_type} == `SWAP32);

wire atomic_cas;
assign atomic_cas = ({radm_trgt1_fmt, radm_trgt1_type} == `CAS32)   ||
                    ({radm_trgt1_fmt, radm_trgt1_type} == `CAS64);

// Byte count requested by the NP transaction.  As long as direct_length_n >
// np_decrvalue, it is not necessary to check for the all 0's case of
// direct_length_n.  The result of this is 0 if 4K bytes are requested
// By spec, this field should always be 4 unless it is a memory read
// completion

// spyglass disable_block W164a
// SMD: Identifies assignments in which the LHS width is less than the RHS width
// SJ: This Byte count value is unsigned and the maximum value is 4096,
// preserving borrow due to underflow is not required.
wire [11:0] np_bc_memrd;
assign np_bc_memrd  = {radm_trgt1_dw_len, 2'b00} - {9'd0, np_decrvalue};
// spyglass enable_block W164a
wire [11:0] np_bc_atomic_fa_or_swap;
assign np_bc_atomic_fa_or_swap = {radm_trgt1_dw_len, 2'b00};
wire [11:0] np_bc_atomic_cas;
assign np_bc_atomic_cas = {1'b0,radm_trgt1_dw_len, 1'b0}; // CAS CPL byte lenght is request length/2
wire [11:0] np_bytecount;
assign np_bytecount = mem_rd           ? np_bc_memrd             :
                      atomic_fa_or_swp ? np_bc_atomic_fa_or_swap :
                      atomic_cas       ? np_bc_atomic_cas        :
                      12'd4;

// The lower address bits for the first byte of data returned are called
// the alignment.  The lower 2 bits depend on the first DW Byte Enable field

// According to the spec, the Lower Address field is set to 0's for all
// types of Completions other than Memory Read Completions
wire [6:0]   np_alignment;          // The lower address bits for the first
                                    // byte of data to be returned
wire [11:0] rcb_minus_bc;

// CPL to translation requests have a lower address set to RCB - bytecount
// to maintaind RCB sematics
assign rcb_minus_bc = (cfg_rcb_128 ? 128 : 64) - np_bytecount;

assign np_alignment[1:0] = (radm_trgt1_at == 2'b01) ? 2'b00 :
                           mem_rd ? ((radm_trgt1_first_be[1:0] == 2'b10   ? 2'b01 : 2'b00) |
                                     (radm_trgt1_first_be[2:0] == 3'b100  ? 2'b10 : 2'b00) |
                                     (radm_trgt1_first_be[3:0] == 4'b1000 ? 2'b11 : 2'b00))
                                  : 2'b00;
assign np_alignment[6:2] = (radm_trgt1_at == 2'b01) ? rcb_minus_bc[6:2] :
                           mem_rd ? radm_trgt1_addr[6:2] : 5'b00000;
// Initialize the TCT at the end of the packet when we know that there
// was no error on the TLP and the TCT is not empty.
assign init_wr = radm_trgt1_eot & ~radm_trgt1_tlp_abort &
               ~radm_trgt1_dllp_abort & !trgt1_radm_halt & tlp_is_np & trgt_lookup_empty;


// Indicates that request is non-posted transaction
   wire   radm_trgt1_lookup_id_consmd;
   // This signal is almost the same of init_wr, but without halt condition!
   // Note: this signal is used only for eDMA, which requires the signaling to
   // be on hv rather than on eot. This makes a difference for DMWR/Atomic
   // This poses a limitation: we cannot have aborted (tlp or dllp) NPR.
   // This is never the case as the NP Queue is always S/F and aborted tlps
   // get discarded internally, unless the filter is configured in non default
   // way, which is not supported in this case.
   assign radm_trgt1_lookup_id_consmd = ~radm_trgt1_tlp_abort & ~radm_trgt1_dllp_abort  & radm_trgt1_hv & tlp_is_np;


wire [TRGT_CPL_LUT_ENTRY_WD -1:0] init_data;
logic [15:0]                  ltchd_radm_trgt1_reqid;
logic [TAG_SIZE-1:0]          ltchd_radm_trgt1_tag;
logic [11:0]                  ltchd_np_bytecount;
logic [6:0]                   ltchd_np_alignment;
logic [2:0]                   ltchd_radm_trgt1_tc;
logic [`TCTF_ATTRIBUTE]       ltchd_radm_trgt1_attr;
logic [9-1:0]                 ltchd_radm_trgt1_req_segment;
logic [PF_WD-1:0]             ltchd_radm_trgt1_func_num;
logic [1:0]              ltchd_radm_trgt1_at;



always@(posedge core_clk or negedge core_rst_n)
begin
  if (!core_rst_n)
  begin
    ltchd_radm_trgt1_reqid        <= #TP 0;
    ltchd_radm_trgt1_tag          <= #TP 0;
    ltchd_np_bytecount            <= #TP 0;
    ltchd_np_alignment            <= #TP 0;
    ltchd_radm_trgt1_tc           <= #TP 0;
    ltchd_radm_trgt1_attr         <= #TP 0;
    ltchd_radm_trgt1_req_segment  <= #TP 0;
    ltchd_radm_trgt1_func_num     <= #TP 0;
    ltchd_radm_trgt1_at           <= #TP 0;
  end
  else if (radm_trgt1_hv)
  begin
    ltchd_radm_trgt1_reqid        <= #TP radm_trgt1_reqid;
    ltchd_radm_trgt1_tag          <= #TP radm_trgt1_tag;
    ltchd_np_bytecount            <= #TP np_bytecount;
    ltchd_np_alignment            <= #TP np_alignment;
    ltchd_radm_trgt1_tc           <= #TP radm_trgt1_tc;
    ltchd_radm_trgt1_attr         <= #TP radm_trgt1_attr;
    ltchd_radm_trgt1_req_segment  <= #TP radm_trgt1_req_segment;
    ltchd_radm_trgt1_func_num     <= #TP radm_trgt1_func_num;
    ltchd_radm_trgt1_at           <= #TP radm_trgt1_at;
  end
end

assign init_data[`TCTF_REQID]       = (radm_trgt1_eot && !radm_trgt1_hv) ? ltchd_radm_trgt1_reqid        : radm_trgt1_reqid;
assign init_data[`TCTF_TAG]         = (radm_trgt1_eot && !radm_trgt1_hv) ? ltchd_radm_trgt1_tag          : radm_trgt1_tag;
assign init_data[`TCTF_BYTECOUNT]   = (radm_trgt1_eot && !radm_trgt1_hv) ? ltchd_np_bytecount            : np_bytecount;
assign init_data[`TCTF_ALIGNMENT]   = (radm_trgt1_eot && !radm_trgt1_hv) ? ltchd_np_alignment            : np_alignment;
assign init_data[`TCTF_TRAFFICCLASS]= (radm_trgt1_eot && !radm_trgt1_hv) ? ltchd_radm_trgt1_tc           : radm_trgt1_tc;
assign init_data[`TCTF_ATTRIBUTE]   = (radm_trgt1_eot && !radm_trgt1_hv) ? ltchd_radm_trgt1_attr         : radm_trgt1_attr;              
assign init_data[`TCTF_PF]          = (radm_trgt1_eot && !radm_trgt1_hv) ? ltchd_radm_trgt1_func_num     : radm_trgt1_func_num;
assign init_data[`TCTF_SEGREQ]      = (radm_trgt1_eot && !radm_trgt1_hv) ? ltchd_radm_trgt1_req_segment  : radm_trgt1_req_segment;
assign init_data[`TCTF_AT]          = (radm_trgt1_eot && !radm_trgt1_hv) ? ltchd_radm_trgt1_at           : radm_trgt1_at;

wire [TRGT_CPL_LUT_ENTRY_WD-1:0] update_data;

assign  last_cpl = (client_tlp_fmt == 0)  | (f_last_cpl(client_tlp_byte_len[11:2], client_cpl_byte_cnt, client_cpl_bcm, client_cpl_low_addr[1:0], client_cpl_status));

//---- Timeout errors --------
wire                               timeout_error;
logic   [TIMEOUT_GRANULARITY-1:0]    pertag_timer[CPL_LUT_DEPTH -1:0];  // Timeout values
logic   [CPL_TIMER_TW-1:0]           timer;
wire                               timer_expired;
wire  [TRGT_CPL_LUT_ENTRY_WD-1:0]  timeout_vec;


//---- Clear TCT entry when last completion driven --------
wire [CPL_LUT_PTR_WD-1:0]          update_addr;
logic  [TRGT_CPL_LUT_ENTRY_WD-1:0]   latchd_update_data;
logic  [CPL_LUT_PTR_WD-1:0]          latchd_update_addr;
wire [TRGT_CPL_LUT_ENTRY_WD-1:0]   muxd_update_data;
wire [REMOTE_LOOKUPID_WD:0]        timer_offset_pad;

assign update_addr = client_cpl_lookup_id[CPL_LUT_PTR_WD-1:0];

always @(posedge core_clk or negedge core_rst_n)
begin
    if (~core_rst_n) begin
        latchd_last_cpl     <= #TP 0;
        latchd_update_data  <= #TP 0;
        latchd_update_addr  <= #TP 0;
        latchd_cpl_type     <= #TP 0;
    end else if (client_tlp_hv & !xadm_client_halt) begin
        latchd_last_cpl     <= #TP last_cpl & client_cpl_type;
        latchd_update_data  <= #TP update_data;
        latchd_update_addr  <= #TP update_addr;
        latchd_cpl_type     <= #TP client_cpl_type;
    end
end

always @(posedge core_clk or negedge core_rst_n)
begin
    if (~core_rst_n)
        tcb_table <= #TP 0;
    else begin
        // Set TCB bit when entry initialized
        if (init_wr)
            tcb_table[trgt_lookup_id[CPL_LUT_PTR_WD-1:0]] <= #TP 1'b1;

        // Clear TCB entry when last completion driven
        if (last_clr_validated)
            tcb_table[muxd_update_addr]                   <= #TP 1'b0;

        // Port Logic delete entry action
        if (delete_entry_en_1cycle_tcb_validated)
            tcb_table[delete_entry_lookup_id]             <= #TP 1'b0;
    end
end

//---- Read TCT entry -------------------------------------
wire [CPL_LUT_PTR_WD-1:0]        read_addr;
assign read_addr = client_cpl_lookup_id[CPL_LUT_PTR_WD-1:0];
wire [TRGT_CPL_LUT_ENTRY_WD-1:0] read_data;
assign read_data = tct_table[read_addr];

assign client_cpl_req_id               = read_data[`TCTF_REQID];
assign client_cpl_tag                  = read_data[`TCTF_TAG];
assign client_cpl_byte_cnt             = read_data[`TCTF_BYTECOUNT];
assign client_tlp_tc                   = read_data[`TCTF_TRAFFICCLASS];
assign client_tlp_attr                 = read_data[`TCTF_ATTRIBUTE];
assign client_tlp_req_seqment          = read_data[`TCTF_SEGREQ] ;

logic  [6:0]  ats_cpl_low_addr;
wire [1:0]  lut_at;
wire [6:0]  lut_low_addr;
wire        bytelen_eq_bytecnt;
wire [11:0] rcb_minus_cpl_byte_len;

assign lut_at                          = read_data[`TCTF_AT];
assign lut_low_addr                    = read_data[`TCTF_ALIGNMENT];
assign bytelen_eq_bytecnt              = (client_cpl_byte_cnt == client_tlp_byte_len[11:0]);
assign rcb_minus_cpl_byte_len          = (cfg_rcb_128 ? 128 : 64) - client_tlp_byte_len[11:0];

always@(*)
begin
  if(bytelen_eq_bytecnt)
    ats_cpl_low_addr = lut_low_addr;
  else
    ats_cpl_low_addr = rcb_minus_cpl_byte_len[6:0];
end

assign client_cpl_low_addr[6:0]        = (lut_at == 2'b01) ? ats_cpl_low_addr :
                                                             read_data[`TCTF_ALIGNMENT];



//---- Update TCT entry -----------------------------------
assign update_data[`TCTF_PF]            = read_data[`TCTF_PF];
assign update_data[`TCTF_REQID]         = read_data[`TCTF_REQID];
assign update_data[`TCTF_TAG]           = read_data[`TCTF_TAG];
// spyglass disable_block W164a
// SMD: Identifies assignments in which the LHS width is less than the RHS width
// SJ: This Byte count value is unsigned and the maximum value is 4096,
// preserving borrow due to underflow is not required.
assign update_data[`TCTF_BYTECOUNT]     = read_data[`TCTF_BYTECOUNT] - client_tlp_byte_len[11:0] + client_cpl_low_addr[1:0];
// spyglass enable_block W164a
// when RCB is 64bytes, then the bit7 should toggle
wire   rcb_addr_toggle;
// spyglass disable_block W164a
// SMD: Identifies assignments in which the LHS width is less than the RHS width
// SJ: This field is aligned to the width of the lower address
// preserving borrow due to overflow is not required.
wire [4:0] tmp_low_addr;
// Because byte_len is dword aligned already from the client interface
assign tmp_low_addr                     = client_cpl_low_addr[6:2] + client_tlp_byte_len[6:2];
// spyglass enable_block W164a

assign rcb_addr_toggle                  = tmp_low_addr[4];

assign update_data[`TCTF_ALIGNMENT]     = {rcb_addr_toggle, 6'b0};
assign update_data[`TCTF_TRAFFICCLASS]  = read_data[`TCTF_TRAFFICCLASS];
assign update_data[`TCTF_ATTRIBUTE]     = read_data[`TCTF_ATTRIBUTE];
assign update_data[`TCTF_SEGREQ]        = read_data[`TCTF_SEGREQ];
assign update_data[`TCTF_AT]            = read_data[`TCTF_AT];

wire   update_wr;
assign update_wr = ((client_tlp_hv & client_cpl_type) | (!client_tlp_hv & latchd_cpl_type)) & !client_tlp_bad_eot & client_tlp_eot & !xadm_client_halt;

assign muxd_update_data = (client_tlp_hv) ? update_data : latchd_update_data;
assign muxd_update_addr = (client_tlp_hv) ? update_addr : latchd_update_addr;

//---- TCT table   ----------------------------------------
// Register-based TCT table

always @(posedge core_clk or negedge core_rst_n)
begin : TCT_TABLE_PROCESS
integer i;
    if (!core_rst_n)
        for (i=0; i<CPL_LUT_DEPTH; i=i+1)
            tct_table[i]        <= #TP 0;
    else begin
        if (init_wr)
            tct_table[trgt_lookup_id[CPL_LUT_PTR_WD-1:0]] <= #TP init_data;
        if (update_wr)
            tct_table[muxd_update_addr]                   <= #TP muxd_update_data;
    end
end

// ------ Completion timeout detection -------
//

DWC_pcie_tim_gen
 #(
    .CLEAR_CNTR_TO_1(0)
) u_gen_timer_freq
(
     .clk               (core_clk)
    ,.rst_n             (core_rst_n)

    ,.current_data_rate (current_data_rate)
    ,.clr_cntr          (1'b0)        // clear cycle counter(not used in this timer)
    
    ,.cnt_up_en         (timer_freq)  // timer count-up 
);


logic [CPL_LUT_PTR_WD:0] timeout_addr_mapped;
assign timeout_addr_mapped = (timer[CPL_LUT_PTR_WD-1:0] <= (CPL_LUT_DEPTH-1)) ? {1'b0, timer[CPL_LUT_PTR_WD-1:0]} : CPL_LUT_DEPTH-1;

assign timeout_addr  = timeout_addr_mapped[CPL_LUT_PTR_WD-1:0];
assign timeout_vec   = tct_table[timeout_addr];
assign timeout_error = tcb_table[timeout_addr] && (&pertag_timer[timeout_addr]);

// for 1s product at 250Mhz, base timer times out at 4ms based on current defines in adm_defs.vh
wire    [CPL_TIMER_TW-1:0]      cpl_timeout_value_wire;

assign  cpl_timeout_value_wire  =( CPL_LUT_DEPTH == 10'd768 ) ? wCPL_TIMEOUT_VALUE -255 : wCPL_TIMEOUT_VALUE -1;
assign timer_expired = (timer == cpl_timeout_value_wire) & timer_freq;

always @(posedge core_clk or negedge core_rst_n)
begin
    if (!core_rst_n) begin
        timer   <= #TP 0;
    end else if (((~(|tcb_table))) || timer_expired) begin
            timer   <= #TP timer_freq ? 0 : timer;
        end else begin
            timer     <= #TP timer + (timer_freq ? 1'b1 : 1'b0);
        end
    end

// make sure that each cycle of the timer is a full two clocks
wire   timer_expired_incr;
logic    timer_expired_window;
assign timer_expired_incr = timer_expired_window & timer_freq;

// use the timer to create a window as wide as the number of entries in the table
always @(posedge core_clk or negedge core_rst_n)
begin
    if (!core_rst_n) begin
        timer_expired_window     <= #TP 0;
    end else if (timer_expired) begin
        timer_expired_window     <= #TP 1;
    end else if ((&timer[CPL_LUT_PTR_WD-1:0]) & timer_expired_incr) begin
        timer_expired_window     <= #TP 0;
    end
end

always @(posedge core_clk or negedge core_rst_n)
begin: TRANSACTION_TIMEOUT_PROCESS
integer i;
    if (!core_rst_n) begin
        // can't do this if the TIMER is a RAM
        for (i=0; i<CPL_LUT_DEPTH; i=i+1)
            pertag_timer[i]     <= #TP 0;
    end else begin
        // completion timeout occured
        if (timeout_error)
            pertag_timer[timeout_addr] <= #TP 0;

        // Initialize the TCT at the end of the packet when we know that there
        // was no error on the TLP and the TCT is not empty.
        if (init_wr)
            pertag_timer[trgt_lookup_id[CPL_LUT_PTR_WD-1:0]] <= #TP 0;

        // pkt received on client i/f
        if (update_wr)
            pertag_timer[muxd_update_addr] <= #TP 0;

        // timer timeout occurred
        if (tcb_table[timeout_addr] && timer_expired_incr && !timeout_error)
            pertag_timer[timeout_addr] <= #TP  pertag_timer[timeout_addr] + 1'b1;

        // Port Logic delete entry action
        if (delete_entry_en_1cycle_tcb_validated)
            pertag_timer[delete_entry_lookup_id] <= #TP 1'b0;

    end
end

assign timer_offset_pad = {{REMOTE_LOOKUPID_WD+1-CPL_LUT_PTR_WD{1'b0}}, timeout_addr};

assign timeout_cpl_func_num = timeout_vec[`TCTF_PF];
logic  [`TCTF_ATTRIBUTE]  trgt_timeout_cpl_attr;
logic  [11:0] trgt_timeout_cpl_len;
logic  [REMOTE_LOOKUPID_WD-1:0]  trgt_timeout_lookup_id;
always @(posedge core_clk or negedge core_rst_n)
begin: OUTPUT_CONTROL_DRIVE_PROCESS
    if (!core_rst_n)
    begin
        trgt_cpl_timeout            <= #TP 0;
        trgt_timeout_cpl_tc         <= #TP 0;
        trgt_timeout_cpl_attr       <= #TP 0;
        trgt_timeout_cpl_func_num    <= #TP 0;
        trgt_timeout_cpl_len        <= #TP 0;
        trgt_timeout_lookup_id      <= #TP 0;

    end
    else
    begin
        trgt_cpl_timeout            <= #TP timeout_error;
        trgt_timeout_cpl_len        <= #TP timeout_vec[`TCTF_BYTECOUNT];
        trgt_timeout_cpl_attr       <= #TP timeout_vec[`TCTF_ATTRIBUTE];
        trgt_timeout_cpl_tc         <= #TP timeout_vec[`TCTF_TRAFFICCLASS];
        trgt_timeout_cpl_func_num   <= #TP timeout_vec[`TCTF_PF];
        trgt_timeout_lookup_id      <= #TP timer_offset_pad[REMOTE_LOOKUPID_WD-1:0];
    end
end

// Outputs of the target_cpl_lut module
logic [(NVC*3)-1:0]        trgt_lut_trgt1_radm_pkt_halt;
logic                      trgt_lut_dma_pkt_halt;
// Outputs of the target_np_tracker_ms module
logic                    int_trgt_lut_order_pkt_halt;
logic                      int_trgt_lut_dma_pkt_halt;

// ### Mapping last_clr_validated and delete_entry_en_1cycle -> NVC structure 
function automatic [2:0] vc_from_tc;
    input   [23:0]  cfg_tc_struc_vc_map;  // TC to VC Structure mapping
    input   [2:0]   tc;             // Traffic class
    begin

        case  (tc)
            3'b000:     vc_from_tc = cfg_tc_struc_vc_map[ 2: 0];
            3'b001:     vc_from_tc = cfg_tc_struc_vc_map[ 5: 3];
            3'b010:     vc_from_tc = cfg_tc_struc_vc_map[ 8: 6];
            3'b011:     vc_from_tc = cfg_tc_struc_vc_map[11: 9];
            3'b100:     vc_from_tc = cfg_tc_struc_vc_map[14:12];
            3'b101:     vc_from_tc = cfg_tc_struc_vc_map[17:15];
            3'b110:     vc_from_tc = cfg_tc_struc_vc_map[20:18];
            3'b111:     vc_from_tc = cfg_tc_struc_vc_map[23:21];
        endcase // case
    end
endfunction // vc_from_tc   

// Indicates to the received ompletion is the last one
logic [NVC-1:0] radm_trgt1_cpl_lookup_id_rlsd;
logic [NVC-1:0] last_clr_nvc_struct;
always @ (last_clr_validated or cfg_tc_struc_vc_map or read_data) begin
   logic [NVC-1:0] i;
   i    = {NVC{1'b0}};
   i[0] = last_clr_validated;
   last_clr_nvc_struct = i << vc_from_tc(cfg_tc_struc_vc_map, read_data[`TCTF_TRAFFICCLASS]);      
end
assign radm_trgt1_cpl_lookup_id_rlsd = last_clr_nvc_struct; // | delete_entry_en_1cycle_nvc_struct

logic [NVC-1:0] delete_entry_en_1cycle_nvc_struct;
always @ (delete_entry_en_1cycle_tcb_validated or cfg_tc_struc_vc_map or delete_entry_data) begin
   logic [NVC-1:0] i;
   i    = {NVC{1'b0}};
   i[0] = delete_entry_en_1cycle_tcb_validated; 
   delete_entry_en_1cycle_nvc_struct = i << vc_from_tc(cfg_tc_struc_vc_map, delete_entry_data[`TCTF_TRAFFICCLASS]);      
end

   target_np_tracker_ms
   
     #(
       .TARGET_CPL_LUT_ENABLE (1            ),
       .DMA_ENABLE            (1            ),
       .NVC_POP_PER_CYCLE     (1            ),
       .H_VC                  (NVC-1        ), // NVC= 1 2 3 4 5 6 7 8 VC=0...7 // NVC-1 
       .L_VC                  (0            ), // 0
       .REMOTE_MAX_TAG_PLUS_1 (CPL_LUT_DEPTH)  // 2,4,8...CPL_LUT_DEPTH 

       ) u_target_np_tracker_ms
       (
        .core_clk                      (core_clk                           ),
        .core_rst_n                    (core_rst_n                         ),

// ### DYNAMIC PARAMETERS ###
        .dyn_target_cpl_lut_enable     (1'b1                               ), // Internally and gated with the TARGET_CPL_LUT_ENABLE parameter
        .dyn_dma_enable                (1'b1                               ), // Internally and gated with the DMA_ENABLE parameter
        .dyn_h_vc                      (NVC-4'b1                           ), // NVC= 1 2 3 4 5 6 7 8 VC=0...7 
        .dyn_l_vc                      (4'b0                               ),
        .dyn_remote_max_tag_plus_1     (CPL_LUT_DEPTH[CNT_WD-1:0]          ), // CX_REMOTE_MAX_TAG+1 

// ### DMA I/F ### it should be enabled for only 1 group
        .radm_trgt1_dma_grant          (radm_trgt1_dma_grant               ),
        .radm_trgt1_dma_cpl_rlsd       (radm_trgt1_dma_cpl_rlsd            ),
        .trgt_lut_dma_pkt_halt         (int_trgt_lut_dma_pkt_halt          ),

// ### TARGET_CPL_LUT I/F ###
        .radm_grant_tlp_type           (radm_grant_tlp_type                ),
        .client_lookupid_rlsd          (last_clr_nvc_struct                ),
        .port_logic_delete_lookupid    (delete_entry_en_1cycle_nvc_struct  ),
        .trgt_lut_order_pkt_halt       (int_trgt_lut_order_pkt_halt        )

    );

   // ### Expand int_trgt_lut_order_pkt_halt to all NVC ###
   always @(*) begin
      integer i;

      trgt_lut_trgt1_radm_pkt_halt = 0;
      // Go through all NP VC assigning int_trgt_lut_order_pkt_halt
      for(i=0;i<NVC;i++) begin
         trgt_lut_trgt1_radm_pkt_halt[i*3+1] = int_trgt_lut_order_pkt_halt;
      end // for
   end

   assign trgt_lut_dma_pkt_halt = int_trgt_lut_dma_pkt_halt;


endmodule
