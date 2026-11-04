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
// ---    $DateTime: 2023/04/29 12:35:01 $
// ---    $Revision: #9 $
// ---    $Id: //dwh/pcie_iip/main/fairbanks/design/Bridge/inbound/DWC_pcie_bridge_ib_rd_dcmp_inq.sv#9 $
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
`include "DWC_pcie_ctl_pkg.svh"

 module DWC_pcie_bridge_ib_rd_dcmp_inq

  import DWC_pcie_ctl_pkg::ras_dp_err_log_t;
  import DWC_pcie_ctl_pkg::ras_dp_err_inj_t;

 (

    in_clk,
    in_rst_n,

    // Request packet interface
    inq_pkt_halt,
    req_pkt_hv,
    req_pkt_dv,
    req_pkt_eot,
    req_pkt_hdr,
    req_pkt_addr,
    req_pkt_byte_en,
    req_pkt_byte_len,
    req_pkt_func_num,
    req_pkt_fmt,
    req_pkt_type,
    dwnstrm_pkt_halt,
    inq_pkt_hv,
    inq_pkt_dv,
    inq_pkt_eot,
    inq_pkt_hdr,
    inq_pkt_addr,
    inq_pkt_byte_en,
    inq_pkt_byte_len,
    inq_pkt_req_byte_len,
    inq_pkt_func_num,
    inq_pkt_out_tag,
    inq_pkt_ncbe,
    inq_pkt_last_tlp,
    inq_pkt_req_byte_en,
    inq_pkt_low_addr,
    inq_pkt_np_tlp_issued,
    // Address parity error detection
    dcmp_addr_parerr,
    axi_bridge_ras_dp_err_inj_core_clk,
    dcmp_ad_ras_dp_err_log,

    // Tag management interface
    req_pkt_out_tag
   );

// FSM state definition
// ---------------------------------------------------------------------------------------------------------------------
localparam S_READY                           = 2'b00;
localparam S_RD_DCMP                         = 2'b10;
localparam S_RD_NCBE                         = 2'b11;

// Parameters depending on decomposer usage (inbound vs outbound, posted vs non-posted)
// ---------------------------------------------------------------------------------------------------------------------
parameter  NW                            = 1;                  // Number of DWORDs in data bus
parameter  PKT_HDR_WD                    = 156;
parameter  PKT_ADDR_WD                   = 64;
parameter  PKT_DATA_WD                   = 64;
parameter  PKT_BYTE_LEN_IN_WD            = 13;
parameter  PKT_BYTE_LEN_OUT_WD           = 13;
parameter  PKT_BYTE_EN_WD                = 8;
parameter  PKT_OUT_TAG_WD                = 4;
parameter  PAGE_BOUNDARY_BIT             = 13;                           // power of 2 of address boundary uncrossable + 1.
parameter  PKT_LOW_ADDR_WD               = `DC_MCB_MAX_CPL_NUM_DWORDS_WD-1;
parameter  TP                            = `TP;                          // Clock to Q delay (simulator insurance)

// Parameters set by coreConsultant
// ---------------------------------------------------------------------------------------------------------------------
localparam NF                            = `CX_NFUNC;                    // Number of functions
localparam PF_WD                         = `CX_NFUNC_WD;                 // Width of func_num bus
localparam CC_MSTR_MTU                   = `CC_MSTR_MTU;                 // Number of functions
localparam CC_MSTR_NW                    = `CC_MSTR_NW;
localparam CX_RAS_ENA                     = |`CX_RASDP;                   // RAS.DP Enabled 0 ; Disabled 1
localparam CX_RAS_PARITY_MODE            = `CX_RAS_PARITY_MODE;          //Parity mode 0 - Even; 1 - Odd

// Internal parameters
// ---------------------------------------------------------------------------------------------------------------------
parameter DBUS_DWORD_WD_WITH_PAR = `CC_DBUS_DWORD_WD_WITH_PAR;
parameter CX_RAS_PROT_RANGE      = `CX_RAS_PROT_RANGE;
parameter ADDR_WD_WO_PAR         = CX_RAS_ENA ? ((PKT_ADDR_WD >=64) ? 64:32) : PKT_ADDR_WD;
parameter ADDR_PAR_WIDTH         = PKT_ADDR_WD - ADDR_WD_WO_PAR;

localparam NUM_ADDR_PAR_BLOCKS           = ADDR_WD_WO_PAR/CX_RAS_PROT_RANGE;


input  wire                                  in_clk;
input  wire                                  in_rst_n;

// Request packet interface
output wire                                  inq_pkt_halt;
input  wire                                  req_pkt_hv;
input  wire                                  req_pkt_dv;
input  wire                                  req_pkt_eot;
input  wire [PKT_HDR_WD -1:0]                req_pkt_hdr;
input  wire [PKT_ADDR_WD -1:0]               req_pkt_addr;
input  wire [PKT_BYTE_EN_WD -1:0]            req_pkt_byte_en;
input  wire [PKT_BYTE_LEN_IN_WD -1 :0]       req_pkt_byte_len;
input  wire [PF_WD-1:0]                      req_pkt_func_num;
input  wire [1:0]                            req_pkt_fmt;
input  wire [4:0]                            req_pkt_type;

wire   [6:0]                                 req_pkt_fmt_type;


input  wire                                  dwnstrm_pkt_halt;
output wire                                  inq_pkt_hv;
output wire                                  inq_pkt_dv;
output wire                                  inq_pkt_eot;
output wire [PKT_HDR_WD -1:0]                inq_pkt_hdr;
output wire [PKT_ADDR_WD -1:0]               inq_pkt_addr;
output wire [PKT_BYTE_EN_WD -1:0]            inq_pkt_byte_en;
output wire [PKT_BYTE_LEN_OUT_WD -1:0]       inq_pkt_byte_len;
output wire [PKT_BYTE_LEN_IN_WD -1:0]        inq_pkt_req_byte_len;
output wire [PF_WD-1:0]                      inq_pkt_func_num;
output wire [PKT_OUT_TAG_WD -1:0]            inq_pkt_out_tag;
output wire                                  inq_pkt_ncbe;
output wire                                  inq_pkt_last_tlp;
output wire [PKT_BYTE_EN_WD -1:0]            inq_pkt_req_byte_en;
output wire [PKT_LOW_ADDR_WD -1:0]           inq_pkt_low_addr;
output wire                                  inq_pkt_np_tlp_issued;
output wire                                  dcmp_addr_parerr;
input ras_dp_err_inj_t                       axi_bridge_ras_dp_err_inj_core_clk;
output ras_dp_err_log_t                      dcmp_ad_ras_dp_err_log;

// Tag management interface
input  wire [PKT_OUT_TAG_WD -1:0]            req_pkt_out_tag;

wire   [12:0]                                s_cc_mstr_mtu_byte_len;
wire   [10:0]                                s_cc_mstr_mtu_dw_len;
wire   [10:0]                                s_cc_mstr_mtu_dw_len_addr_mask;
wire   [10:0]                                s_master_dw_page_boundary;
wire   [10:0]                                s_master_dw_page_boundary_addr_mask;
reg    [12:0]                                s_max_payload_dw_len;       // Max payload size for current function
reg    [10:0]                                s_max_rd_req_dw_len;        // Max read req size for current function

reg    [ADDR_PAR_WIDTH -1:0]                       s_calc_req_addr_par;
reg    [ADDR_PAR_WIDTH -1:0]                       s_calc_inq_addr_par;
reg    [ADDR_PAR_WIDTH-1:0][CX_RAS_PROT_RANGE-1:0] s_req_pkt_addr_nopar_int;
reg    [ADDR_PAR_WIDTH -1:0]                       s_req_pkt_addr_parity;
wire   [ADDR_PAR_WIDTH-1:0][CX_RAS_PROT_RANGE-1:0] s_inq_pkt_addr_nopar;
wire   [ADDR_PAR_WIDTH-1:0][CX_RAS_PROT_RANGE-1:0] req_pkt_addr_nopar;

reg    [1:0]                                 state;
reg    [1:0]                                 next_state;

reg    [PKT_HDR_WD -1:0]                     r_latched_pkt_hdr;
reg    [ADDR_WD_WO_PAR -1:0]                 r_latched_pkt_addr;
reg    [PKT_BYTE_EN_WD -1:0]                 r_latched_pkt_byte_en;
reg    [PKT_BYTE_LEN_IN_WD -1 :0]            r_latched_pkt_byte_len;
reg    [PF_WD-1:0]                           r_latched_pkt_func_num;
reg    [6:0]                                 r_latched_pkt_fmt_type;

wire                                         s_latch_req_pkt;
wire                                         s_latch_req_pkt_byte_len;

wire   [PKT_BYTE_LEN_IN_WD -1 :0]            s_pkt_byte_len;
wire   [PKT_BYTE_LEN_IN_WD -3 :0]            s_pkt_dw_len;
wire   [PKT_HDR_WD -1:0]                     s_pkt_hdr;
wire   [ADDR_WD_WO_PAR -1:0]                 s_pkt_addr;
wire   [PKT_BYTE_EN_WD -1:0]                 s_pkt_byte_en;
wire   [PF_WD-1:0]                           s_pkt_func_num;
wire   [6:0]                                 s_pkt_fmt_type;

wire   [PF_WD-1:0]                           s_pkt_func_num_max_payload;

wire   [PKT_BYTE_LEN_IN_WD -1 :0]            s_pkt_extra_byte_len;
wire   [PKT_BYTE_LEN_IN_WD -1 :0]            s_pkt_effective_byte_len;

wire   [PKT_BYTE_LEN_IN_WD -1 :0]            s_pkt_remaining_byte_len;

wire   [PKT_BYTE_LEN_IN_WD -3 :0]            s_pkt_extra_dw_len;
wire   [PKT_BYTE_LEN_IN_WD -3 :0]            s_pkt_effective_dw_len;

wire   [PKT_BYTE_LEN_IN_WD -3 :0]            s_pkt_remaining_dw_len;
reg    [PKT_BYTE_LEN_IN_WD -3 :0]            r_pkt_sent_dw_len;
wire   [PKT_BYTE_LEN_IN_WD -3 :0]            s_pkt_sent_dw_len;

wire   [10:0]                                s_pkt_dw_to_next_page_boundary;
wire   [10:0]                                s_pkt_dw_to_next_max_transfer_unit;
wire   [10:0]                                s_pkt_dw_to_next_dcmp;
wire                                         s_pkt_crosses_page_boundary;
wire                                         s_pkt_exceeds_max_transfer_unit;

wire                                         s_pkt_ncbe_det;

reg    [7:0]                                 inq_pkt_ncbe_byte_en;

wire   [PKT_BYTE_LEN_OUT_WD -3 :0]           s_tlp_dw_len;
// AA Remove: reg    [PKT_BYTE_LEN_OUT_WD -3 :0]           r_tlp_dw_len;

wire   [ADDR_WD_WO_PAR -1:0]                 s_tlp_addr;

// AA Remove: wire                                         s_tlp_single_beat;

wire                                         s_decomposition_required;
wire                                         s_pkt_first_tlp;
wire                                         s_pkt_last_tlp;

reg    [PKT_OUT_TAG_WD -1:0]                 r_req_pkt_out_tag;

wire   [PKT_BYTE_LEN_OUT_WD -3:0]            s_inq_pkt_dw_len;


wire                                         s_pkt_is_msg;

assign inq_pkt_np_tlp_issued  = inq_pkt_hv && !dwnstrm_pkt_halt;

assign s_inq_pkt_dw_len  = inq_pkt_byte_len[PKT_BYTE_LEN_OUT_WD-1:2];


// setting max transfer unit and master page boundary for inbound decomposition
// ---------------------------------------------------------------------------------------------------------------------
assign s_cc_mstr_mtu_byte_len              = CC_MSTR_MTU;
assign s_cc_mstr_mtu_dw_len                = s_cc_mstr_mtu_byte_len[12:2];
assign s_cc_mstr_mtu_dw_len_addr_mask      = s_cc_mstr_mtu_dw_len-1;
assign s_master_dw_page_boundary           = (1 << (PAGE_BOUNDARY_BIT -3));
assign s_master_dw_page_boundary_addr_mask = s_master_dw_page_boundary-1;


// Detecting address parity errors and removing parity bits from address to allow it to be used in internal calculations
// ---------------------------------------------------------------------------------------------------------------------
always @( * )
begin: ADDR_STRIP_OFF_PAR_COMB_PROC
integer i;

reg [ADDR_PAR_WIDTH-1:0][CX_RAS_PROT_RANGE:0] req_pkt_addr_int;

    req_pkt_addr_int         = req_pkt_addr;
    s_req_pkt_addr_nopar_int = {ADDR_WD_WO_PAR{1'b0}};
    s_req_pkt_addr_parity    = {ADDR_PAR_WIDTH{1'b0}};

    for(i=0; i<ADDR_PAR_WIDTH; i=i+1)begin
        s_req_pkt_addr_nopar_int[i] = req_pkt_addr_int[i][CX_RAS_PROT_RANGE-1:0];
        s_req_pkt_addr_parity[i]    = req_pkt_addr_int[i][CX_RAS_PROT_RANGE];
    end
end

assign req_pkt_addr_nopar = s_req_pkt_addr_nopar_int;

// Calculating parity for input address bus
always @( * )
begin: S_CALC_REQ_ADDR_PAR_COMB_PROC
integer i;
    s_calc_req_addr_par = 0;
    for (i=0; i<ADDR_PAR_WIDTH; i=i+1) begin
        s_calc_req_addr_par[i] = CX_RAS_PARITY_MODE ? ~(^(req_pkt_addr_nopar[i])) : ^(req_pkt_addr_nopar[i]);
    end
end

ras_dp_pipe
 #(
    .PIPELINE_TYPE             (0                              ),
    .RESETVAL                  (0                              ),
    .N_STAGES                  (0                              ),
    .CAN_STALL                 (0                              ),
    .RESET_STALL               (0                              ),
    .BUS_PROTECT_GEN_EN        (0                              ),
    .BUS_PROTECT_CHK_EN        (1                              ),
    .PROT_TYPE                 (1                              ),  // parity
    .PROT_RANGE                (CX_RAS_PROT_RANGE              ),
    .PROT_WD                   (NUM_ADDR_PAR_BLOCKS            ),
    .PARITY_MODE               (CX_RAS_PARITY_MODE             ),
    .PROT_CORRECT_EN           (0                              ),
    .TOTAL_WIDTH               (ADDR_WD_WO_PAR                 ),
    .EXCLUDE_PROT_WIDTH        (0                              ),
    .RAS_DP_PROT_CHK_ID_BASE   (`RD_DCMP_AD_RAS_ID             )
  ) u_addr_chk (
    .clk                       ( in_clk                        ),
    .rst_n                     ( in_rst_n                      ),
    .din                       ( req_pkt_addr_nopar            ),
    .din_prot                  ( s_req_pkt_addr_parity         ),
    .dout                      ( /* Not Connected */           ),
    .dout_prot                 ( /* Not Connected */           ),
    .en                        (1'b1                           ),
    .bypass                    (1'b0                           ),
    .stall                     (1'b0                           ),
    .stallout                  ( /* Not Connected */           ),
    .valid_in                  ( req_pkt_hv                    ),
    .halt_out                  ( /* Not Connected */           ),
    .valid_out                 ( /* Not Connected */           ),
    .halt_in                   (1'b0                           ),
    .ras_dp_err_inband_kbd_in  (1'b0                           ),
    .ras_dp_err_inband_kbd_out ( /* Not Connected */           ),
    .ras_dp_err_log            ( dcmp_ad_ras_dp_err_log        )
    ,
    .ras_dp_err_inj            (axi_bridge_ras_dp_err_inj_core_clk)
    );

   assign dcmp_addr_parerr = dcmp_ad_ras_dp_err_log.valid;
assign req_pkt_fmt_type  = {req_pkt_fmt, req_pkt_type};

// latch request when accepted
// ---------------------------------------------------------------------------------------------------------------------
assign s_latch_req_pkt          = (state == S_READY) && req_pkt_hv && !dwnstrm_pkt_halt;


// The packet length of outbound posted packets can be adjusted at eot due to the presence of null write strobes
// ---------------------------------------------------------------------------------------------------------------------
assign s_latch_req_pkt_byte_len =  (state == S_READY) && req_pkt_hv && !dwnstrm_pkt_halt;

always@(posedge in_clk or negedge in_rst_n)
  begin: R_LATCHED_PKT_SEQ_PROC
    if(!in_rst_n) begin
        r_latched_pkt_hdr          <= #TP 0;
        r_latched_pkt_addr         <= #TP 0;
        r_latched_pkt_byte_en      <= #TP 0;
        r_latched_pkt_func_num     <= #TP 0;
        r_latched_pkt_fmt_type <= #TP 0;
      end else if (s_latch_req_pkt) begin
        r_latched_pkt_hdr          <= #TP req_pkt_hdr;
        r_latched_pkt_addr         <= #TP req_pkt_addr_nopar;
        r_latched_pkt_byte_en      <= #TP req_pkt_byte_en;
        r_latched_pkt_func_num     <= #TP req_pkt_func_num;
        r_latched_pkt_fmt_type     <= #TP req_pkt_fmt_type;
      end
  end


always@(posedge in_clk or negedge in_rst_n)
  begin: R_LATCHED_PKT_BYTE_LEN_SEQ_PROC
    if(!in_rst_n) begin
        r_latched_pkt_byte_len     <= #TP 0;
      end else if (s_latch_req_pkt_byte_len) begin
        r_latched_pkt_byte_len     <= #TP req_pkt_byte_len;
      end
  end

assign s_pkt_byte_len           = s_latch_req_pkt_byte_len ? req_pkt_byte_len   : r_latched_pkt_byte_len;
assign s_pkt_hdr                = s_latch_req_pkt          ? req_pkt_hdr        : r_latched_pkt_hdr;
assign s_pkt_addr               = s_latch_req_pkt          ? req_pkt_addr_nopar : r_latched_pkt_addr;
assign s_pkt_byte_en            = s_latch_req_pkt          ? req_pkt_byte_en    : r_latched_pkt_byte_en;
assign s_pkt_func_num           = s_latch_req_pkt          ? req_pkt_func_num   : r_latched_pkt_func_num;
assign s_pkt_fmt_type           = s_latch_req_pkt          ? req_pkt_fmt_type   : r_latched_pkt_fmt_type;

// spyglass disable_block W164a
// SMD: Identifies assignments in which the LHS width is less than the RHS width
// SJ: The rule reports assignments where the result of an addition or subtraction operation is being assigned to a bus of the same width as the operands of the addition or subtraction operation. In this code, the value of the operands is never large enough to cause overflow.
assign s_pkt_dw_len             = s_pkt_byte_len[PKT_BYTE_LEN_IN_WD-1:2];
// spyglass enable_block W164a

// s_pkt_effective_byte_len              : effective request packet length in bytes; wire requests are DW aligned but
//                                         AXI requests are data width aligned, so inbound requests may need to be
//                                         shifted by an amount equal to the difference between DW address and data
//                                         width boundary. The value of this shift needs to be added to the original
//                                         packet request length to determine if the request crosses a page boundary
// ---------------------------------------------------------------------------------------------------------------------
assign s_pkt_extra_dw_len     = CC_MSTR_NW == 32 ? {{(PKT_BYTE_LEN_IN_WD-7){1'b0}},s_pkt_addr[6:2]} :
                                CC_MSTR_NW == 16 ? {{(PKT_BYTE_LEN_IN_WD-6){1'b0}},s_pkt_addr[5:2]} :
                                CC_MSTR_NW == 8  ? {{(PKT_BYTE_LEN_IN_WD-5){1'b0}},s_pkt_addr[4:2]} :
                                CC_MSTR_NW == 4  ? {{(PKT_BYTE_LEN_IN_WD-4){1'b0}},s_pkt_addr[3:2]} :
                                CC_MSTR_NW == 2  ? {{(PKT_BYTE_LEN_IN_WD-3){1'b0}},s_pkt_addr[2]  } :
                                                    {(PKT_BYTE_LEN_IN_WD-2){1'b0}};
// spyglass disable_block W164a
// SMD: Identifies assignments in which the LHS width is less than the RHS width
// SJ: The rule reports assignments where the result of an addition or subtraction operation is being assigned to a bus of the same width as the operands of the addition or subtraction operation. In this code, the value of the operands is never large enough to cause overflow.
assign s_pkt_effective_dw_len = s_pkt_dw_len + s_pkt_extra_dw_len;
// spyglass enable_block W164a

always@(posedge in_clk or negedge in_rst_n)
  begin: IB_RD_R_PKT_SENT_DW_LEN_SEQ_PROC
    if (!in_rst_n) begin
      r_pkt_sent_dw_len <= #TP 0;
    end else begin
      if (!dwnstrm_pkt_halt) begin
        if(state == S_READY) begin
          if (req_pkt_hv) begin
            r_pkt_sent_dw_len <= #TP s_tlp_dw_len;
          end else begin
            r_pkt_sent_dw_len <= #TP 0;
          end
        end else begin
          if (state == S_RD_DCMP) begin
// spyglass disable_block W164a
// SMD: Identifies assignments in which the LHS width is less than the RHS width
// SJ: The rule reports assignments where the result of an addition or subtraction operation is being assigned to a bus of the same width as the operands of the addition or subtraction operation. In this code, the value of the operands is never large enough to cause overflow.
            r_pkt_sent_dw_len <= #TP r_pkt_sent_dw_len + s_tlp_dw_len;
// spyglass enable_block W164a
          end
        end
      end
    end
  end


assign s_pkt_sent_dw_len                  = ( state == S_READY ) ? 0 : r_pkt_sent_dw_len;
// spyglass disable_block W164a
// SMD: Identifies assignments in which the LHS width is less than the RHS width
// SJ: The rule reports assignments where the result of an addition or subtraction operation is being assigned to a bus of the same width as the operands of the addition or subtraction operation. In this code, the value of the operands is never large enough to cause overflow.
assign s_pkt_remaining_dw_len             = s_pkt_dw_len - s_pkt_sent_dw_len;
// spyglass enable_block W164a

// s_pkt_bytes_to_next_page_boundary     : number of bytes to next page boundary
// s_pkt_bytes_to_next_max_transfer_unit : number of bytes to next max transfer unit
// s_pkt_crosses_page_boundary           : request crosses page boundary
// s_pkt_crosses_page_boundary           : request crosses page boundary
// ---------------------------------------------------------------------------------------------------------------------
// spyglass disable_block W164a
// SMD: Identifies assignments in which the LHS width is less than the RHS width
// SJ: The rule reports assignments where the result of an addition or subtraction operation is being assigned to a bus of the same width as the operands of the addition or subtraction operation. In this code, the value of the operands is never large enough to cause overflow.
assign s_pkt_dw_to_next_page_boundary        =  s_master_dw_page_boundary - (s_tlp_addr[12:2] & s_master_dw_page_boundary_addr_mask);
assign s_pkt_dw_to_next_max_transfer_unit    =  s_cc_mstr_mtu_dw_len   - (s_tlp_addr[12:2] & s_cc_mstr_mtu_dw_len_addr_mask);
// spyglass enable_block W164a
assign s_pkt_crosses_page_boundary           = |s_pkt_dw_to_next_page_boundary ? (s_pkt_remaining_dw_len > s_pkt_dw_to_next_page_boundary) : 1'b0;
assign s_pkt_exceeds_max_transfer_unit       =  s_pkt_first_tlp ? s_pkt_effective_dw_len > s_cc_mstr_mtu_dw_len : s_pkt_remaining_dw_len > s_cc_mstr_mtu_dw_len;


// s_decomposition_required
// ---------------------------------------------------------------------------------------------------------------------
assign s_decomposition_required = s_pkt_exceeds_max_transfer_unit || s_pkt_crosses_page_boundary;

assign s_pkt_dw_to_next_dcmp = s_pkt_dw_to_next_max_transfer_unit;

assign s_pkt_first_tlp                       = (state == S_READY);
assign s_pkt_last_tlp                        = !s_decomposition_required;
assign s_tlp_dw_len                          = s_decomposition_required ? s_pkt_dw_to_next_dcmp : s_pkt_remaining_dw_len;
// AA Remove: assign s_tlp_single_beat                     = 1'b1;

// AA Remove: always@(posedge in_clk or negedge in_rst_n)
// AA Remove:   begin: R_TLP_DW_LEN_SEQ_PROC
// AA Remove:     if(!in_rst_n) begin
// AA Remove:       r_tlp_dw_len <= #TP 0;
// AA Remove:     end else begin
// AA Remove:       r_tlp_dw_len <= #TP s_tlp_dw_len;
// AA Remove:     end
// AA Remove:   end

assign s_pkt_is_msg         =       (s_pkt_fmt_type[6:3] == `MSG_4);
// spyglass disable_block W164a
// SMD: Identifies assignments in which the LHS width is less than the RHS width
// SJ: The rule reports assignments where the result of an addition or subtraction operation is being assigned to a bus of the same width as the operands of the addition or subtraction operation. In this code, the value of the operands is never large enough to cause overflow.
assign s_tlp_addr = s_pkt_is_msg? s_pkt_addr :{s_pkt_addr[ADDR_WD_WO_PAR -1:2],2'b00} + {s_pkt_sent_dw_len,2'b00};
// spyglass enable_block W164a


// s_pkt_ncbe_det
// ---------------------------------------------------------------------------------------------------------------------
assign  s_pkt_ncbe_det = 1'b0;


// FSM sequential process
// ---------------------------------------------------------------------------------------------------------------------
always@(posedge in_clk or negedge in_rst_n)
  begin: STATE_SEQ_PROC
    if (!in_rst_n) begin
      state <= #TP S_READY;
    end else begin
      state <= #TP next_state;
    end
  end

// FSM combinational process
// ---------------------------------------------------------------------------------------------------------------------
always@(*)
  begin: IB_RD_STATE_COMB_PROC
    if (!dwnstrm_pkt_halt) begin

      next_state = state;

      case(state)
        S_READY :
            if (req_pkt_hv) begin
              if (s_decomposition_required) begin
                next_state = S_RD_DCMP;
              end else begin
                next_state = S_READY;
              end
            end else begin
              next_state = S_READY;
            end
        S_RD_DCMP:
            if (s_pkt_exceeds_max_transfer_unit) begin
              next_state = S_RD_DCMP;
            end else begin
              next_state = S_READY;
            end
      endcase

    end else begin
      next_state = state;
    end
  end


always@(posedge in_clk or negedge in_rst_n)
  begin: R_REQ_PKT_OUT_TAG_SEQ_PROC
    if (!in_rst_n) begin
      r_req_pkt_out_tag <= #TP 0;
    end else begin
      if ( ( state == S_READY ) && inq_pkt_hv ) begin
        r_req_pkt_out_tag <= #TP req_pkt_out_tag;
      end
    end
  end


// inq_pkt_halt
// ---------------------------------------------------------------------------------------------------------------------
assign inq_pkt_halt = ( state == S_READY ) ? dwnstrm_pkt_halt : 1'b1;


// inq_pkt_hv
// ---------------------------------------------------------------------------------------------------------------------
assign inq_pkt_hv   = ( state == S_READY ) ? req_pkt_hv && !dwnstrm_pkt_halt: 1'b1;


// inq_pkt_dv
// ---------------------------------------------------------------------------------------------------------------------
assign inq_pkt_dv = 1'b0;


// inq_pkt_eot
// ---------------------------------------------------------------------------------------------------------------------
assign inq_pkt_eot = ( state == S_READY ) ? req_pkt_eot && !dwnstrm_pkt_halt: 1'b1;


// inq_pkt_byte_len
// ---------------------------------------------------------------------------------------------------------------------
assign inq_pkt_byte_len = {s_tlp_dw_len,2'b00};


// inq_pkt_req_byte_len
// ---------------------------------------------------------------------------------------------------------------------
assign inq_pkt_req_byte_len = s_pkt_byte_len;


// inq_pkt_addr
// ---------------------------------------------------------------------------------------------------------------------
assign s_inq_pkt_addr_nopar = s_tlp_addr;

// Adding parity bits to output address
// ---------------------------------------------------------------------------------------------------------------------
always @( * )
begin : OUT_ADDR_PAR_CAL
integer i;
    s_calc_inq_addr_par = 0;
    for (i=0; i<ADDR_PAR_WIDTH; i=i+1) begin
        s_calc_inq_addr_par[i] = CX_RAS_PARITY_MODE ? ~(^(s_inq_pkt_addr_nopar[i])) : ^(s_inq_pkt_addr_nopar[i]);
    end
end

assign inq_pkt_addr = add_addr_par(s_inq_pkt_addr_nopar, s_calc_inq_addr_par);


// inq_pkt_byte_en
// ---------------------------------------------------------------------------------------------------------------------
assign inq_pkt_byte_en[3:0] = s_pkt_first_tlp          ? s_pkt_byte_en[3:0] : 4'b1111;
assign inq_pkt_byte_en[7:4] = s_decomposition_required ? 4'b1111 : s_pkt_byte_en[7:4];

// inq_pkt_req_byte_en
// ---------------------------------------------------------------------------------------------------------------------
assign inq_pkt_req_byte_en = s_pkt_byte_en;


// inq_pkt_last_tlp
// ---------------------------------------------------------------------------------------------------------------------
assign inq_pkt_last_tlp = s_pkt_last_tlp;


// inq_pkt_ncbe
// ---------------------------------------------------------------------------------------------------------------------
assign inq_pkt_ncbe = s_pkt_ncbe_det;


// inq_pkt_out_tag
// ---------------------------------------------------------------------------------------------------------------------
assign inq_pkt_out_tag      = ( state == S_READY ) && req_pkt_hv && !dwnstrm_pkt_halt ? req_pkt_out_tag : r_req_pkt_out_tag;


// inq_pkt_low_addr
// ---------------------------------------------------------------------------------------------------------------------
assign inq_pkt_low_addr = {s_pkt_addr[PKT_LOW_ADDR_WD-1:2],get_low_addr(s_pkt_byte_en[7:0])};


// inq_pkt_*
// ---------------------------------------------------------------------------------------------------------------------
assign inq_pkt_hdr          = s_pkt_hdr;
assign inq_pkt_func_num     = s_pkt_func_num;


// Auxiliary functions
// ---------------------------------------------------------------------------------------------------------------------

function automatic [ADDR_PAR_WIDTH-1:0][CX_RAS_PROT_RANGE:0] add_addr_par;
input [ADDR_PAR_WIDTH-1:0][CX_RAS_PROT_RANGE-1:0]   in_addr;
input [ADDR_PAR_WIDTH-1:0]   in_par;
integer i;
begin
    for (i=0; i<ADDR_PAR_WIDTH; i=i+1) begin
       add_addr_par[i] = {in_par[i],in_addr[i]};
    end
end
endfunction // add_addr_par


// Calculate PCIe request byte address offset
function automatic [1:0] get_low_addr;
    input   [7:0]   s_pkt_byte_en;
begin
        case (s_pkt_byte_en[3:0])
           4'b0010 :   get_low_addr = 2'b01;
           4'b1110 :   get_low_addr = 2'b01;
           4'b0110 :   get_low_addr = 2'b01;
           4'b1010 :   get_low_addr = 2'b01;
           4'b0100 :   get_low_addr = 2'b10;
           4'b1100 :   get_low_addr = 2'b10;
           4'b1000 :   get_low_addr = 2'b11;
           default :   get_low_addr = 2'b00;
        endcase
end
endfunction

`ifndef SYNTHESIS
wire    [32*8-1:0]         STATE;

assign  STATE   =  (state == S_READY                         ) ? "READY"  :
                   (state == S_RD_DCMP                       ) ? "RD_DCMP" :
                   (state == S_RD_NCBE                       ) ? "RD_NCBE" :
                                                                "";

`endif // SYNTHESIS

endmodule

