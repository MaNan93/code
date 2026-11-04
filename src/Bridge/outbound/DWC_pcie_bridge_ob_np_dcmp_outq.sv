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
// ---    $Revision: #10 $
// ---    $Id: //dwh/pcie_iip/main/fairbanks/design/Bridge/outbound/DWC_pcie_bridge_ob_np_dcmp_outq.sv#10 $
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


 module DWC_pcie_bridge_ob_np_dcmp_outq (

    core_clk,
    core_rst_n,

    hdf_pkt_tlp_prfx,
    hdf_pkt_th,
    hdf_pkt_ph,
    hdf_pkt_st,
    hdf_pkt_atu_bypass,
    hdf_pkt_dst_segment,
    hdf_pkt_ats,
    hdf_pkt_nw,
    hdf_pkt_first_wrp_split_xact,
    hdf_pkt_wrp_valid,
    hdf_pkt_last_tlp,
    hdf_pkt_dcmp_rd,
    hdf_pkt_serial_req,
    hdf_pkt_req_byte_len,
    hdf_pkt_in_tag,
    hdf_pkt_out_tag,
    hdf_pkt_axi_id,
    hdf_pkt_byte_len,
    hdf_pkt_tc,
    hdf_pkt_ep,
    hdf_pkt_attr,
    hdf_pkt_byte_en ,
    hdf_pkt_fmt,
    hdf_pkt_type,
    hdf_pkt_addr,
    hdf_pkt_data,
    hdf_pkt_cpl_stat,
    hdf_pkt_valid,
    outq_ready,
    //outq_use_tag,
    dwnstrm_pkt_halt,
    outq_pkt_hv,
    outq_pkt_dv,
    outq_pkt_eot,
    outq_pkt_bad_eot,
    outq_pkt_tlp_prfx,
    outq_pkt_th,
    outq_pkt_ph,
    outq_pkt_st,
    outq_pkt_atu_bypass,
    outq_pkt_dst_segment,
    outq_pkt_ats,
    outq_pkt_nw,
    outq_pkt_func_num,
    outq_pkt_first_wrp_split_xact,
    outq_pkt_wrp_valid,
    outq_pkt_last_tlp,
    outq_pkt_4rd,
    outq_pkt_dcmp_rd,
    outq_pkt_serial_req,
    outq_pkt_req_byte_len,
    outq_pkt_in_tag,
    outq_pkt_out_tag,
    outq_pkt_axi_id,
    outq_pkt_byte_len,
    outq_pkt_tc,
    outq_pkt_ep,
    outq_pkt_attr,
    outq_pkt_byte_en,
    outq_pkt_fmt,
    outq_pkt_type,
    outq_pkt_addr,
    outq_pkt_data,
    outq_pkt_cpl_stat,
    outq_pkt_np_atomic_rsp_valid,
    outq_pkt_np_atomic_rsp_id,
    cmp_sb_init_done
   );

parameter  TP                                = `TP;

// Parameters depending on decomposer usage (inbound vs outbound, posted vs non-posted)
// ---------------------------------------------------------------------------------------------------------------------
    //// Tag management parameters
localparam MAX_WIRE_5BIT_TAG                 = `CC_DMA_ENABLE_VALUE ? `CC_MAX_NON_DMA_5BIT_TAG_HIGH        : (`CX_MAX_TAG        > 31   ? 31   : `CX_MAX_TAG      );
localparam MAX_WIRE_5BIT_TAG_PW              = `CC_DMA_ENABLE_VALUE ? `CC_MAX_NON_DMA_5BIT_TAG_HIGH_WIDTH  : (`CX_LUT_PTR_WIDTH  > 5    ? 5    : `CX_LUT_PTR_WIDTH);
localparam MAX_WIRE_8BIT_TAG                 = `CC_DMA_ENABLE_VALUE ? `CC_MAX_NON_DMA_8BIT_TAG_HIGH        : (`CX_MAX_TAG        > 255  ? 255  : `CX_MAX_TAG      );
localparam MAX_WIRE_8BIT_TAG_PW              = `CC_DMA_ENABLE_VALUE ? `CC_MAX_NON_DMA_8BIT_TAG_HIGH_WIDTH  : (`CX_LUT_PTR_WIDTH  > 8    ? 8    : `CX_LUT_PTR_WIDTH);
localparam MAX_WIRE_10BIT_TAG                = `CC_DMA_ENABLE_VALUE ? `CC_MAX_NON_DMA_10BIT_TAG_HIGH       :  `CX_MAX_TAG;
localparam MAX_WIRE_10BIT_TAG_PW             = `CC_DMA_ENABLE_VALUE ? `CC_MAX_NON_DMA_10BIT_TAG_HIGH_WIDTH :  10;
localparam MAX_WIRE_TAG_PW                   = MAX_WIRE_10BIT_TAG_PW;
localparam MAX_WIRE_TAG                      = MAX_WIRE_10BIT_TAG;
localparam CC_SLV_BUS_ADDR_WIDTH             = `CC_SLV_BUS_ADDR_WIDTH;
localparam SLV_BUS_NPDATA_WIDTH              = `CC_SLV_BUS_NPDATA_WIDTH;
localparam SLV_BUS_NPDATA_WIDTH_NP           = `CC_SLV_BUS_NPDATA_WIDTH_NP;
localparam CC_SLV_BUS_ID_WIDTH               = `CC_SLV_BUS_ID_WIDTH;
localparam CC_CORE_DATA_BUS_WD               = `CC_CORE_DATA_BUS_WD;
localparam CC_MAX_SLV_TAG_PW                 = `CC_MAX_SLV_TAG_PW;
localparam CX_NFUNC_WD                       = `CX_NFUNC_WD;
localparam CX_NVFUNC_WD                      = `CX_NVFUNC_WD;
localparam DC_CPL_STATUS_WD                  = `DC_CPL_STATUS_WD;
localparam CC_SLV_MTU_PW                     = `CC_SLV_MTU_PW;
localparam FIFO_BYTE_LEN_WD                  = `CC_SLV_MTU_PW < (`CC_SLV_RD_REQ_SIZE_PW+1) ? `CC_SLV_MTU_PW : `CC_SLV_RD_REQ_SIZE_PW;
localparam DCMP_PREFIX_WD                    = (32*`CX_NPRFX)+ `CX_PRFX_PAR_WD;
localparam ADDR_PAR_WD                       = `CX_ADDR_PAR_WD;
localparam ATTR_WD                           = 3;
localparam BYTE_WIDTH                        = 9;
localparam [8:0] DATA_INIT_BYTE              = `CX_RAS_PARITY_MODE ? 9'b100000000 : 9'b000000000;
localparam SLV_BUS_NPDATA_N_BYTES            = SLV_BUS_NPDATA_WIDTH_NP/8;
localparam BUS_INIT                          = {SLV_BUS_NPDATA_N_BYTES{DATA_INIT_BYTE}};

input  wire                                  core_clk;
input  wire                                  core_rst_n;

input  wire [DCMP_PREFIX_WD-1:0]             hdf_pkt_tlp_prfx;
input  wire                                  hdf_pkt_th;
input  wire [1:0]                            hdf_pkt_ph;
input  wire [7:0]                            hdf_pkt_st;
input  wire                                  hdf_pkt_atu_bypass;
input  wire [8:0]                            hdf_pkt_dst_segment;
input  wire [1:0]                            hdf_pkt_ats;
input  wire                                  hdf_pkt_nw;
input  wire                                  hdf_pkt_first_wrp_split_xact;
input  wire                                  hdf_pkt_wrp_valid;
input  wire                                  hdf_pkt_last_tlp;
input  wire                                  hdf_pkt_dcmp_rd;
input  wire                                  hdf_pkt_serial_req;
input  wire [CC_SLV_MTU_PW-1:0]              hdf_pkt_req_byte_len;
input  wire [DC_CPL_STATUS_WD-1:0]           hdf_pkt_cpl_stat;
input  wire [FIFO_BYTE_LEN_WD-1:0]           hdf_pkt_byte_len;
input  wire [CC_MAX_SLV_TAG_PW-1:0]          hdf_pkt_in_tag;
input  wire [MAX_WIRE_TAG_PW-1:0]            hdf_pkt_out_tag;
input  wire [CC_SLV_BUS_ID_WIDTH:0]          hdf_pkt_axi_id;
input  wire [2:0]                            hdf_pkt_tc;
input  wire                                  hdf_pkt_ep;
input  wire [ATTR_WD-1:0]                    hdf_pkt_attr;
input  wire [7:0]                            hdf_pkt_byte_en;
input  wire [1:0]                            hdf_pkt_fmt;
input  wire [4:0]                            hdf_pkt_type;
input  wire [CC_SLV_BUS_ADDR_WIDTH-1:0]      hdf_pkt_addr;
input  wire [SLV_BUS_NPDATA_WIDTH-1:0]       hdf_pkt_data;
input  wire                                  hdf_pkt_valid;
output wire                                  outq_ready;
//output wire                                  outq_use_tag;

input  wire                                  dwnstrm_pkt_halt;
output wire                                  outq_pkt_hv;
output wire                                  outq_pkt_dv;
output wire                                  outq_pkt_eot;
output wire                                  outq_pkt_bad_eot;
output wire [DCMP_PREFIX_WD-1:0]             outq_pkt_tlp_prfx;
output wire                                  outq_pkt_th;
output wire [1:0]                            outq_pkt_ph;
output wire [7:0]                            outq_pkt_st;
output wire                                  outq_pkt_atu_bypass;
output wire [8:0]                            outq_pkt_dst_segment;
output wire [1:0]                            outq_pkt_ats;
output wire                                  outq_pkt_nw;
output wire [CX_NFUNC_WD-1:0]                outq_pkt_func_num;
output  wire                                 outq_pkt_first_wrp_split_xact;
output  wire                                 outq_pkt_wrp_valid;
output wire                                  outq_pkt_last_tlp;
output wire                                  outq_pkt_4rd;
output wire                                  outq_pkt_dcmp_rd;
output wire                                  outq_pkt_serial_req;
output wire [CC_SLV_MTU_PW-1:0]              outq_pkt_req_byte_len;
output wire [DC_CPL_STATUS_WD-1:0]           outq_pkt_cpl_stat;
output wire [12:0]                           outq_pkt_byte_len;
output wire [CC_MAX_SLV_TAG_PW-1:0]          outq_pkt_in_tag;
output wire [MAX_WIRE_TAG_PW-1:0]            outq_pkt_out_tag;
output wire [CC_SLV_BUS_ID_WIDTH:0]          outq_pkt_axi_id;
output wire [2:0]                            outq_pkt_tc;
output wire                                  outq_pkt_ep;
output wire [ATTR_WD-1:0]                    outq_pkt_attr;
output wire [7:0]                            outq_pkt_byte_en;
output wire [1:0]                            outq_pkt_fmt;
output wire [4:0]                            outq_pkt_type;
output wire [CC_SLV_BUS_ADDR_WIDTH-1:0]      outq_pkt_addr;
output wire [SLV_BUS_NPDATA_WIDTH-1:0]       outq_pkt_data;

input  wire                                  cmp_sb_init_done;

output wire                                  outq_pkt_np_atomic_rsp_valid;
output wire [CC_SLV_BUS_ID_WIDTH-1:0]        outq_pkt_np_atomic_rsp_id;


// Deriving output signals from pipeline delay register output
// ---------------------------------------------------------------------------------------------------------------------
assign outq_pkt_hv             =                                                     hdf_pkt_valid && cmp_sb_init_done;
assign outq_pkt_dv             =                                                     hdf_pkt_valid && cmp_sb_init_done && hdf_pkt_axi_id[CC_SLV_BUS_ID_WIDTH];
assign outq_pkt_eot            =                                                     hdf_pkt_valid && cmp_sb_init_done;
assign outq_pkt_bad_eot        =                                                     1'b0;
assign outq_pkt_addr           =                                                     hdf_pkt_addr;
assign outq_pkt_tlp_prfx       =                                                     hdf_pkt_tlp_prfx;
assign outq_pkt_th             =                                                     hdf_pkt_th;
assign outq_pkt_ph             =                                                     hdf_pkt_ph;
assign outq_pkt_st             =                                                     hdf_pkt_st;
assign outq_pkt_atu_bypass     =                                                     hdf_pkt_atu_bypass;
assign outq_pkt_dst_segment    =                                                     hdf_pkt_dst_segment;
assign outq_pkt_ats            =                                                     hdf_pkt_ats;
assign outq_pkt_nw             =                                                     hdf_pkt_nw;
assign outq_pkt_func_num       =                                                     {CX_NFUNC_WD{1'b0}};
assign outq_pkt_first_wrp_split_xact =                                               hdf_pkt_first_wrp_split_xact;
assign outq_pkt_wrp_valid            =                                               hdf_pkt_wrp_valid;
assign outq_pkt_last_tlp       =                                                     hdf_pkt_last_tlp && (hdf_pkt_dcmp_rd || !hdf_pkt_first_wrp_split_xact);
assign outq_pkt_4rd            =                                                    !hdf_pkt_axi_id[CC_SLV_BUS_ID_WIDTH] || (hdf_pkt_type[4:2] == 3'b011);
assign outq_pkt_dcmp_rd        =                                                     hdf_pkt_dcmp_rd;
assign outq_pkt_serial_req     =                                                     hdf_pkt_serial_req;
assign outq_pkt_req_byte_len   =                                                     ( hdf_pkt_type == `DMWR_TYPE ) ? 4 : (&hdf_pkt_type[3:1] & ~hdf_pkt_type[4]) ? hdf_pkt_req_byte_len >> 1 :  hdf_pkt_req_byte_len; // For atomic CAS need to predict the response size half of the origianl request
assign outq_pkt_cpl_stat       =                                                     hdf_pkt_cpl_stat;
assign outq_pkt_byte_len       =                                                     {{(13-FIFO_BYTE_LEN_WD){1'b0}},hdf_pkt_byte_len};
assign outq_pkt_in_tag         =                                                     hdf_pkt_in_tag;
assign outq_pkt_out_tag        =                                                     hdf_pkt_out_tag;
assign outq_pkt_axi_id         =                                                     hdf_pkt_axi_id;
assign outq_pkt_tc             =                                                     hdf_pkt_tc;
assign outq_pkt_ep             =                                                     hdf_pkt_ep;
assign outq_pkt_attr           =                                                     hdf_pkt_attr;
assign outq_pkt_byte_en        =                                                     hdf_pkt_byte_en;
assign outq_pkt_fmt            =                                                     hdf_pkt_fmt;
assign outq_pkt_type           =                                                     hdf_pkt_type;

assign outq_pkt_np_atomic_rsp_valid = hdf_pkt_valid && cmp_sb_init_done && hdf_pkt_last_tlp && (&hdf_pkt_type[3:2] & ~hdf_pkt_type[4]) && !dwnstrm_pkt_halt;
assign outq_pkt_np_atomic_rsp_id    = hdf_pkt_axi_id[CC_SLV_BUS_ID_WIDTH-1:0];

logic [SLV_BUS_NPDATA_N_BYTES-1:0] s_fbe_mask;
logic [SLV_BUS_NPDATA_N_BYTES-1:0] s_lbe_mask;
logic [SLV_BUS_NPDATA_N_BYTES+3:0] s_aux_bytelen_mask;
logic [SLV_BUS_NPDATA_N_BYTES-1:0] s_bytelen_mask;
logic [SLV_BUS_NPDATA_N_BYTES-1:0] s_data_mask;
logic [SLV_BUS_NPDATA_WIDTH  -1:0] s_masked_data;

logic s_atomic_req;
assign s_atomic_req       = {hdf_pkt_fmt,hdf_pkt_type} inside {`FETCHADD32, `FETCHADD64, `SWAP32, `SWAP64, `CAS32, `CAS64};
assign s_fbe_mask         =                              s_atomic_req ? {{(SLV_BUS_NPDATA_N_BYTES-4){1'b0}},4'b1111}                         : {{(SLV_BUS_NPDATA_N_BYTES-4){1'b0}},hdf_pkt_byte_en[3:0]};
assign s_lbe_mask         = hdf_pkt_byte_len == 0 ? '0 : s_atomic_req ? {{(SLV_BUS_NPDATA_N_BYTES-4){1'b0}},4'b1111} << (hdf_pkt_byte_len-4) : {{(SLV_BUS_NPDATA_N_BYTES-4){1'b0}},hdf_pkt_byte_en[7:4]} << (hdf_pkt_byte_len-4);
assign s_aux_bytelen_mask = (1 << hdf_pkt_byte_len) - 1;
assign s_bytelen_mask     = {s_aux_bytelen_mask[SLV_BUS_NPDATA_N_BYTES+3:8],4'b0000};
assign s_data_mask        = s_fbe_mask | s_lbe_mask | s_bytelen_mask;

always_comb begin : S_MASKED_DATA_COMB_PROC
  integer i;
  
  s_masked_data = hdf_pkt_data;
  
  for(i=0;i<SLV_BUS_NPDATA_N_BYTES;i=i+1)
    if(!outq_pkt_dv || !s_data_mask[i])
      s_masked_data[i*BYTE_WIDTH+:BYTE_WIDTH] = DATA_INIT_BYTE;

end

assign outq_pkt_data           =                                                     s_masked_data;

// Popping from header/data/address FIFO
// ---------------------------------------------------------------------------------------------------------------------
//assign outq_ready   = (hdf_pkt_valid ? !dwnstrm_pkt_halt : 1'b1) && tm_next_tag_vld && cmp_sb_init_done;
assign outq_ready   = (hdf_pkt_valid ? !dwnstrm_pkt_halt : 1'b1) && cmp_sb_init_done;
//assign outq_use_tag = outq_pkt_hv && !dwnstrm_pkt_halt;

endmodule

