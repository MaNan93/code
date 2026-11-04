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
// ---    $Revision: #12 $
// ---    $Id: //dwh/pcie_iip/main/fairbanks/design/Bridge/outbound/DWC_pcie_bridge_ob_p_dcmp_outq.sv#12 $
// -------------------------------------------------------------------------

// -----------------------------------------------------------------------------
// --- Module Description:
// -----------------------------------------------------------------------------
// This module contains the state machine that controls the writing into the
// queue for the decomposer.
// It also decomposes a TLP into multiple TLPs under the following conditions:
// 1. When a MemRd request is bigger than the max read request size
// 2. When a MemWr or CplD is bigger than the max payload size
// 3. When a MemRd or MemWr crosses 4k address boundary
//    *** The boundary address is a parameter that can be modified
//    *** There's an added requirement that boundary address >= max payload size
//    *** And: boundary address >= max read request size
// 4. When a completion needs to be split, it would be split at RCB boundary
//    The enforcement of this rule is automatic by how the TLPs are split.
//
// The TLP is split along max payload size (for MemWr & Cpld) boundaries or
// along max read request size (for MemRd) boundaries.  Since integer multiples
// of the max payload/read request size is 4K, the 4K address boundary rule
// is automatically satisfied when a TLP is split because of the first 2 reasons.
// If a TLP is not bigger than max payload size or max read request size, then
// a check must be done to ensure it doesn't cross 4k address boundary.  The
// TLP will be split at the 4k address boundary if it does cross it.
// Again, since RCB boundary is either 64byte or 128byte, this rule is
// is automatically satisfiied when a CplD needs to be split.
// *NOTE* The above description changes as the parameter PAGE_BOUNDARY_BIT change
// *NOTE* please see below for description of this parameter.
// *NOTE* As long as assumption #4 is satisfied, description is still valid.
//
// Furthermore, it also does some other functions:
// 1. When bus master enable is 0, no read or write request can be sent out
// 2. When there are no available tags available, no request can go out
//
// Assumptions:
// 1. Application would send full completions and not split ones or if they
//    already split it, it would be split to less than max payload size.
// 2. Global address align enable is always set ------ NOT TRUE ANYMORE
// 3. Only support input core datawidth.
// 4. PAGE_BOUNDARY_BIT >= log2(max payload size) + 1
//When Global address align = 0:
// 5. Input byte_len is actual byte + low addr offset
//When Global address align = 1:
// 5. Input byte_len is actual byte length
// 6. Input address is either, this module will NOT look at [1:0].
//
// This inQ manager manages both the header and data queue.  When enough data
// is received to send a TLP, a header is written at the same time as the last
// data entry.  This will signal the outQ manager to start reading out of the
// queue.
//
// Parameter guide:
// NO_SWAP_TAG - By default, this parameter is 0 which means that the new TLP
//              going out will use the tag provided by the tag manager.
//              When this parameter is set to 1, the incoming tag will be used
//              as the outgoing tag.
// PKT_LEN_MOD - By default, this parameter is set to 1 which means that the
//              incoming packet header's length field can change during EOT
//              and this new value is the actual length of the packet.  This is
//              required for interfacing with applications that are running in
//              bus cycle mode, so it wouldn't know the actual length of the
//              packet until at the end of the packet.
//              When this parameter is set to 0, the valid TLP length is during
//              _hv at the beginning of the packet.  Don't update during EOT
//              because the value might change to something that's not correct.
// PAGE_BOUNDARY_BIT - By default, this parameter is set to 13 which means that
//              this module will split TLP that crosses 4K address boundary.
//              Valid range for this parameter is 8 (128byte) to 13 (4Kbyte).
//
//
//  The major funcions:
//  This module converts a core TRGT1 interface to GIF interface of a master AMBA
//  1. a FIFO for data and header of a memrd/wr transaction that core receive to provide
//     a non-blocking architecture between core and one AMBA master. Other Master can get traffic through
//  2. This FIFO also does the clock domain crossing between AMBA clock and core clk.
//     Only core clk runs less than AMBA clock is supported
//  3. GIF interface control as a master is done in this block. A memRd/Wr received
//     by core will be translated into GIF master trnasaction to output to DWC GIF master module
//  4. Pipelined request transactions and response transactions are supported as long
//     as inorder services is maintain.  No AMBA out of order services are supported
//  5. A FIFO for header information of a memRd is designed in the block to handle
//     completion type of request generated to core
//
//  Limitations:
//  1. only dword aligned address is supported
//  2. Each read/write received by core will be within one burst of the AMBA transfer
//  3. Only support core data path width and AMBA data path width to be the same
//     --- UPDATED: Now supports different datapath width size
// -----------------------------------------------------------------------------

`include "include/DWC_pcie_ctl_all_defs.svh"

`include "Axi/DWC_pcie_axi_xali_pkg.svh"

 module DWC_pcie_bridge_ob_p_dcmp_outq
   import DWC_pcie_axi_xali_pkg::*;
    (
    core_clk,
    core_rst_n,

    cfg_tc_struc_vc_map,
    hf_pkt_prfx,
    hf_pkt_p_tag,
    hf_pkt_th,
    hf_pkt_ph,
    hf_pkt_st,
    hf_pkt_atu_bypass,
    hf_pkt_dst_segment,
    hf_pkt_ats,
    hf_pkt_nw,
    hf_pkt_null,
    hf_pkt_last_tlp,
    hf_pkt_axi_id,
    hf_pkt_cpl_stat,
    hf_pkt_byte_len,
    hf_pkt_tc,
    hf_pkt_ep,
    hf_pkt_silentDrop,
    hf_pkt_attr,
    hf_pkt_byte_en,
    hf_pkt_fmt,
    hf_pkt_type,
    hf_pkt_addr,
    df_pkt_data,

    outq_hf_ready,
    outq_df_ready,
    hf_pkt_valid,
    df_pkt_valid,
    dwnstrm_halt,

    outq_pkt_hv,
    outq_pkt_dv,
    outq_pkt_eot,
    outq_pkt_prfx,
    outq_pkt_p_tag,
    outq_pkt_th,
    outq_pkt_ph,
    outq_pkt_st,
    outq_pkt_atu_bypass,
    outq_pkt_dst_segment,
    outq_pkt_ats,
    outq_pkt_nw,
    outq_pkt_func_num,
    outq_pkt_cpl_stat,
    outq_pkt_byte_len,
    outq_pkt_tc,
    outq_pkt_ep,
    outq_pkt_silentDrop,
    outq_pkt_attr,
    outq_pkt_byte_en,
    outq_pkt_fmt,
    outq_pkt_type,
    outq_pkt_addr,
    outq_pkt_data,
    outq_pkt_p_rsp_valid,
    outq_pkt_p_rsp_null_or_err,
    outq_pkt_p_rsp_last,
    outq_pkt_p_rsp_vc_num,
    outq_pkt_p_rsp_id,
    outq_pkt_p_rsp_cpl_stat

   );


parameter  TP                           = `TP;
// FSM state definition
// ---------------------------------------------------------------------------------------------------------------------
localparam S_READY                       = 2'b00;
localparam S_INTMD_BEAT                  = 2'b01;
localparam S_LAST_BEAT                   = 2'b11;

localparam CC_SLV_BUS_ADDR_WIDTH             = `CC_SLV_BUS_ADDR_WIDTH;
localparam CC_PRF_TLP_DATA_WIDTH             = `CC_PRF_TLP_DATA_WIDTH;
localparam CC_SLV_BUS_ADDRP_WIDTH            = `CC_SLV_BUS_ADDRP_WIDTH;
localparam CC_PRF_TLP_NUM_WSTRBS             = `CC_PRF_TLP_NUM_WSTRBS;
localparam CC_SLV_BUS_ID_WIDTH               = `CC_SLV_BUS_ID_WIDTH;
localparam CX_NFUNC                          = `CX_NFUNC;
localparam CX_NFUNC_WD                       = `CX_NFUNC_WD;
localparam CX_NVFUNC_WD                      = `CX_NVFUNC_WD;
localparam DC_CPL_STATUS_WD                  = `DC_CPL_STATUS_WD;
localparam FIFO_BYTE_LEN_WD                  = `CC_SLV_MTU_PW < (`CX_MAX_MTU_PW+1) ? `CC_SLV_MTU_PW : `CX_MAX_MTU_PW+1;
localparam DCMP_PREFIX_WD                    = (32*`CX_NPRFX)+ `CX_PRFX_PAR_WD;
localparam ATTR_WD                           = 3;
localparam NW                                = `CC_PRF_TLP_DATA_WIDTH/(32+`DBUS_PAR_WD_PER_DW);                  // Number of DWORDs in data bus
localparam MTU_MORE_NW                       = (`CC_SLV_MTU/4 < NW) ? 0 : 1;
localparam CX_TAG_SIZE                       = `CX_TAG_SIZE;

localparam ADDR_PAR_WIDTH                 = CC_SLV_BUS_ADDRP_WIDTH;
localparam ADDR_WD_WO_PAR                 = CC_SLV_BUS_ADDR_WIDTH - ADDR_PAR_WIDTH;
localparam CX_RAS_PROT_RANGE              = `CX_RAS_PROT_RANGE;

localparam BYTE_WIDTH                        = 9;
localparam [8:0] DATA_INIT_BYTE              = `CX_RAS_PARITY_MODE ? 9'b100000000 : 9'b000000000;

input  wire                                  core_clk;
input  wire                                  core_rst_n;
input  vc_map_s                             cfg_tc_struc_vc_map;

input  wire [DCMP_PREFIX_WD-1:0]             hf_pkt_prfx;
input  wire [CX_TAG_SIZE-1:0]                hf_pkt_p_tag;
input  wire                                  hf_pkt_th;
input  wire [1:0]                            hf_pkt_ph;
input  wire [7:0]                            hf_pkt_st;
input  wire                                  hf_pkt_atu_bypass;
input  wire [8:0]                            hf_pkt_dst_segment;
input  wire [1:0]                            hf_pkt_ats;
input  wire                                  hf_pkt_nw;
input  wire                                  hf_pkt_null;
input  wire                                  hf_pkt_last_tlp;
input  wire [CC_SLV_BUS_ID_WIDTH-1:0]        hf_pkt_axi_id;
input  wire [DC_CPL_STATUS_WD-1:0]           hf_pkt_cpl_stat;
input  wire [FIFO_BYTE_LEN_WD-1:0]           hf_pkt_byte_len;
input  wire [2:0]                            hf_pkt_tc;
input  wire                                  hf_pkt_ep;
input  wire                                  hf_pkt_silentDrop;
input  wire [ATTR_WD-1:0]                    hf_pkt_attr;
input  wire [7:0]                            hf_pkt_byte_en;
input  wire [1:0]                            hf_pkt_fmt;
input  wire [4:0]                            hf_pkt_type;
input  wire [CC_SLV_BUS_ADDR_WIDTH-1:0]      hf_pkt_addr;
input  wire [CC_PRF_TLP_DATA_WIDTH -1:0]     df_pkt_data;



output wire                                  outq_hf_ready;
output wire                                  outq_df_ready;
input  wire                                  hf_pkt_valid;
input  wire                                  df_pkt_valid;
input  wire                                  dwnstrm_halt;

output wire                                  outq_pkt_hv;
output wire                                  outq_pkt_dv;
output wire                                  outq_pkt_eot;
output wire [DCMP_PREFIX_WD-1:0]             outq_pkt_prfx;
output wire [CX_TAG_SIZE-1:0]                outq_pkt_p_tag;
output wire                                  outq_pkt_th;
output wire [1:0]                            outq_pkt_ph;
output wire [7:0]                            outq_pkt_st;
output wire                                  outq_pkt_atu_bypass;
output wire [8:0]                            outq_pkt_dst_segment;
output wire [1:0]                            outq_pkt_ats;
output wire                                  outq_pkt_nw;
output wire [CX_NFUNC_WD-1:0]                outq_pkt_func_num;
output wire [DC_CPL_STATUS_WD-1:0]           outq_pkt_cpl_stat;
output wire [12:0]                           outq_pkt_byte_len;
output wire [2:0]                            outq_pkt_tc;
output wire                                  outq_pkt_ep;
output wire                                  outq_pkt_silentDrop;
output wire [ATTR_WD-1:0]                    outq_pkt_attr;
output wire [7:0]                            outq_pkt_byte_en;
output wire [1:0]                            outq_pkt_fmt;
output wire [4:0]                            outq_pkt_type;
output wire [CC_SLV_BUS_ADDR_WIDTH-1:0]      outq_pkt_addr;
output wire [CC_PRF_TLP_DATA_WIDTH-1:0]      outq_pkt_data;
output wire                                  outq_pkt_p_rsp_valid;
output wire [CC_SLV_BUS_ID_WIDTH-1:0]        outq_pkt_p_rsp_id;
output wire [DC_CPL_STATUS_WD-1:0]           outq_pkt_p_rsp_cpl_stat;
output wire                                  outq_pkt_p_rsp_null_or_err;
output wire                                  outq_pkt_p_rsp_last;
output wire [2:0]                            outq_pkt_p_rsp_vc_num;

wire                                         outq_pkt_last_tlp;

reg                                          tlp_in_proc;

wire        [FIFO_BYTE_LEN_WD-3:0]           s_hf_pkt_dw_len;
wire        [1:0]                            s_hf_pkt_fmt;
wire        [4:0]                            s_hf_pkt_type;
reg         [FIFO_BYTE_LEN_WD-3:0]           r_hf_pkt_dw_len;
wire        [FIFO_BYTE_LEN_WD-3:0]           s_pkt_sent_dw_len;
reg         [FIFO_BYTE_LEN_WD-3:0]           r_pkt_sent_dw_len;
wire                                         s_first_tlp_beat;
wire                                         s_last_tlp_beat;
wire                                         s_single_beat_tlp;

reg         [1:0]                            state;
reg         [1:0]                            next_state;

wire                                         s_msg;
wire                                         s_msg_nodata;

wire                                         s_dwnstrm_halt;
wire                                         s_err_req;
wire                                         s_out_pkt_hv;
wire                                         s_outq_pkt_dv;
wire                                         s_outq_pkt_eot;

reg         [ADDR_WD_WO_PAR-1:0]             s_outq_pkt_addr_nopar;

assign s_msg        = ( state == S_READY ) ? hf_pkt_type[4] : 
                                           s_hf_pkt_type[4] ;

assign s_msg_nodata = ( state == S_READY ) ? (hf_pkt_fmt == 2'b01) && (hf_pkt_type[4:3] == 2'b10) :
                                           (s_hf_pkt_fmt == 2'b01) && (s_hf_pkt_type[4:3] == 2'b10);

assign s_dwnstrm_halt = dwnstrm_halt ;

always@(posedge core_clk or negedge core_rst_n)
  begin: STATE_SEQ_PROC
    if(!core_rst_n) begin
      state <= #TP 2'b00;
    end else begin
      state <= #TP next_state;
    end
  end

always@(*)
  begin: NEXT_STATE_COMB_PROC
    next_state = state;
    case(state)
      S_READY       : begin
                        if (s_dwnstrm_halt) begin
                          next_state = S_READY;
                        end else begin
                          if (hf_pkt_valid && ( df_pkt_valid || s_msg_nodata || hf_pkt_null) && !s_single_beat_tlp ) begin
                            if (s_hf_pkt_dw_len - s_pkt_sent_dw_len <= 2*NW) begin
                              next_state = S_LAST_BEAT;
                            end else begin
                              next_state = S_INTMD_BEAT;
                            end
                          end else begin
                            next_state = S_READY;
                          end
                        end
                      end
      S_INTMD_BEAT  : begin
                        if (s_dwnstrm_halt) begin
                          next_state = S_INTMD_BEAT;
                        end else begin
                          if (s_hf_pkt_dw_len - s_pkt_sent_dw_len <= 2*NW) begin
                            next_state = S_LAST_BEAT;
                          end else begin
                            next_state = S_INTMD_BEAT;
                          end
                        end
                      end
      S_LAST_BEAT   : begin
                        if (s_dwnstrm_halt) begin
                          next_state = S_LAST_BEAT;
                        end else begin
                          next_state = S_READY;
                        end
                      end
      default       : next_state = S_READY;
    endcase
  end

assign s_single_beat_tlp  = ( state == S_READY ) && ( (s_hf_pkt_dw_len <= NW) || s_msg_nodata || hf_pkt_null);
assign s_first_tlp_beat   = ( state == S_READY );
assign s_last_tlp_beat    = s_single_beat_tlp || ( state == S_LAST_BEAT );

assign s_hf_pkt_dw_len    =   hf_pkt_byte_len[FIFO_BYTE_LEN_WD-1:2];
assign s_hf_pkt_fmt       =   hf_pkt_fmt;
assign s_hf_pkt_type      =   hf_pkt_type;

always@(posedge core_clk or negedge core_rst_n)
  begin: R_PKT_SENT_DW_LEN_SEQ_PROC
    if(!core_rst_n) begin
      r_pkt_sent_dw_len <= #TP 0;
    end else begin
      if ( !s_dwnstrm_halt ) begin
        if ( ( state == S_READY ) || s_last_tlp_beat ) begin
          r_pkt_sent_dw_len <= #TP MTU_MORE_NW*NW;
        end else begin
          r_pkt_sent_dw_len <= #TP r_pkt_sent_dw_len + NW;
        end
      end else begin
        r_pkt_sent_dw_len <= #TP r_pkt_sent_dw_len;
      end
    end
  end

assign s_pkt_sent_dw_len = s_first_tlp_beat ? 0 : r_pkt_sent_dw_len;

assign s_err_req = hf_pkt_cpl_stat != {DC_CPL_STATUS_WD{1'b0}};

assign s_outq_pkt_hv           =   ( state == S_READY ) && hf_pkt_valid && ( df_pkt_valid ||  s_msg_nodata );
assign s_outq_pkt_dv           = ( ( state == S_READY ) && hf_pkt_valid &&   df_pkt_valid && !s_msg_nodata ) || ( ( ( state == S_INTMD_BEAT ) || ( state == S_LAST_BEAT ) ) && df_pkt_valid );
assign s_outq_pkt_eot          = ( ( state == S_READY ) && hf_pkt_valid && ( df_pkt_valid ||  s_msg_nodata ) && s_single_beat_tlp ) || ( state == S_LAST_BEAT  );

assign outq_pkt_hv             = !s_err_req && !hf_pkt_null && s_outq_pkt_hv;
assign outq_pkt_dv             = !s_err_req && !hf_pkt_null && s_outq_pkt_dv;
assign outq_pkt_eot            = !s_err_req && !hf_pkt_null && s_outq_pkt_eot;

assign outq_pkt_prfx           = hf_pkt_prfx;
assign outq_pkt_p_tag          = hf_pkt_p_tag;
assign outq_pkt_th             = hf_pkt_th;
assign outq_pkt_ph             = hf_pkt_ph;
assign outq_pkt_st             = hf_pkt_st;
assign outq_pkt_atu_bypass     = hf_pkt_atu_bypass;
assign outq_pkt_dst_segment    = hf_pkt_dst_segment;
assign outq_pkt_ats            = hf_pkt_ats;
assign outq_pkt_nw             = hf_pkt_nw;
assign outq_pkt_last_tlp       = hf_pkt_last_tlp;
assign outq_pkt_func_num       = {CX_NFUNC_WD{1'b0}};
assign outq_pkt_cpl_stat       = hf_pkt_cpl_stat;
assign outq_pkt_byte_len       = s_msg_nodata ? 13'h0000 : {{(13-FIFO_BYTE_LEN_WD){1'b0}},hf_pkt_byte_len};
assign outq_pkt_tc             = hf_pkt_tc;
assign outq_pkt_ep             = hf_pkt_ep;
assign outq_pkt_silentDrop     = hf_pkt_silentDrop;
assign outq_pkt_attr           = hf_pkt_attr;
assign outq_pkt_byte_en        = hf_pkt_byte_en;
assign outq_pkt_fmt            = hf_pkt_fmt;
assign outq_pkt_type           = hf_pkt_type;
assign outq_pkt_addr           = hf_pkt_addr;
logic [     FIFO_BYTE_LEN_WD-3:0] s_tlp_beat_dw_len;
logic [CC_PRF_TLP_NUM_WSTRBS-1:0] s_fbe_mask;
logic [CC_PRF_TLP_NUM_WSTRBS-1:0] s_lbe_mask;
logic [CC_PRF_TLP_NUM_WSTRBS+3:0] s_aux_bytelen_mask;
logic [CC_PRF_TLP_NUM_WSTRBS-1:0] s_bytelen_mask;
logic [CC_PRF_TLP_NUM_WSTRBS-1:0] s_data_mask;
logic [CC_PRF_TLP_DATA_WIDTH-1:0] s_masked_data;

// spyglass disable_block W164a
// SMD: Identifies assignments in which the LHS width is less than the RHS width
// SJ: The rule reports assignments where the result of an addition or subtraction operation is being assigned to a bus of the same width as the operands of the addition or subtraction operation. In this code, the value of the operands is never large enough to cause overflow.
assign s_tlp_beat_dw_len  = s_hf_pkt_dw_len - s_pkt_sent_dw_len;
// spyglass enable_block W164a
assign s_fbe_mask         = s_first_tlp_beat ? s_msg ? {{(CC_PRF_TLP_NUM_WSTRBS-4){1'b0}},4'b1111} : {{(CC_PRF_TLP_NUM_WSTRBS-4){1'b0}},hf_pkt_byte_en[3:0]} : '0;
assign s_lbe_mask         = s_tlp_beat_dw_len == '0 ? '0 : outq_pkt_eot ? s_msg ? ({{(CC_PRF_TLP_NUM_WSTRBS-4){1'b0}},4'b1111} << ((s_tlp_beat_dw_len-1)*4)) : ({{(CC_PRF_TLP_NUM_WSTRBS-4){1'b0}},outq_pkt_byte_en[7:4]} << ((s_tlp_beat_dw_len-1)*4)) : '0;
generate
if(NW == 1)begin  : S_BYTELEN_MASK_GEN_NW_EQ_1
assign s_bytelen_mask     = s_first_tlp_beat || s_last_tlp_beat ? '0 : '1;
end else begin : S_BYTELEN_MASK_GEN_NW_GT_1
assign s_aux_bytelen_mask = s_tlp_beat_dw_len == '0 ? '0 : (1 << ((s_tlp_beat_dw_len-1)*4)) - 1;
assign s_bytelen_mask     = s_first_tlp_beat ? s_last_tlp_beat ? {s_aux_bytelen_mask[CC_PRF_TLP_NUM_WSTRBS-1:4],4'b0000} : {{(CC_PRF_TLP_NUM_WSTRBS-4){1'b1}},4'b0000} : s_last_tlp_beat ? s_aux_bytelen_mask[CC_PRF_TLP_NUM_WSTRBS-1:0] : {(CC_PRF_TLP_NUM_WSTRBS){1'b1}} ;
end
endgenerate
assign s_data_mask        = s_fbe_mask | s_lbe_mask | s_bytelen_mask;

always_comb begin : S_MASKED_DATA_COMB_PROC
  integer i;
  
  s_masked_data = df_pkt_data;
  
  for(i=0;i<CC_PRF_TLP_NUM_WSTRBS;i=i+1)
    if(!outq_pkt_dv || !s_data_mask[i])
      s_masked_data[i*BYTE_WIDTH+:BYTE_WIDTH] = DATA_INIT_BYTE;

end

assign outq_pkt_data           = s_masked_data;
assign outq_pkt_p_rsp_id       = hf_pkt_axi_id;
assign outq_pkt_p_rsp_cpl_stat = hf_pkt_cpl_stat;

  // Parity enable
  always @(*) begin: ADDR_STRIP_OFF_PAR_COMB_PROC
    integer i,j;
    s_outq_pkt_addr_nopar = 0;
    for (i=0; i<ADDR_PAR_WIDTH; i=i+1) begin
        for (j=0; j<CX_RAS_PROT_RANGE; j=j+1) begin
            s_outq_pkt_addr_nopar[i*CX_RAS_PROT_RANGE + j] = outq_pkt_addr[i*CX_RAS_PROT_RANGE +j +i];
        end
    end
  end



assign outq_pkt_p_rsp_valid = outq_pkt_hv && !hf_pkt_silentDrop;

assign outq_pkt_p_rsp_null_or_err = (hf_pkt_null || s_err_req || hf_pkt_silentDrop) && hf_pkt_valid && outq_hf_ready;

assign outq_pkt_p_rsp_last = outq_pkt_last_tlp;

assign outq_pkt_p_rsp_vc_num = getVcOfTc(outq_pkt_tc, cfg_tc_struc_vc_map);



assign outq_hf_ready          = hf_pkt_valid ? ( (!s_dwnstrm_halt || hf_pkt_null) && ( ( (state == S_READY) && s_single_beat_tlp ) || ( state == S_LAST_BEAT ) ) && ( df_pkt_valid || s_msg_nodata || hf_pkt_null ) ) : 1'b1;
assign outq_df_ready          = df_pkt_valid ? ( !s_dwnstrm_halt && ( hf_pkt_valid || ( state != S_READY ) ) && !s_msg_nodata && !hf_pkt_null): 1'b1;

`ifndef SYNTHESIS
wire    [32*8-1:0]         STATE;

assign  STATE   =  (state == S_READY       ) ? "READY"  :
                   (state == S_INTMD_BEAT  ) ? "INTMD_BEAT" :
                   (state == S_LAST_BEAT   ) ? "LAST_BEAT" :
                                   "";

`endif // SYNTHESIS

endmodule

