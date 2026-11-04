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
// ---    $Revision: #11 $
// ---    $Id: //dwh/pcie_iip/main/fairbanks/design/Bridge/inbound/DWC_pcie_bridge_ib_wr_dcmp_inq.sv#11 $
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

`include "Bridge/inbound/DWC_pcie_bridge_atop_pkg.svh"
`include "DWC_pcie_ctl_pkg.svh"

 module DWC_pcie_bridge_ib_wr_dcmp_inq
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
    req_pkt_data,
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
    inq_pkt_data,
    inq_pkt_byte_en,
    inq_pkt_byte_len,
    inq_pkt_req_byte_len,
    inq_pkt_func_num,
    inq_pkt_out_tag,
    inq_pkt_ncbe,
    inq_pkt_last_tlp,
    inq_pkt_low_addr,
    inq_pkt_np_tlp_issued,
    // Address parity error detection
    dcmp_addr_parerr,
    dcmp_data_parerr,
    dcmp_dt_ras_dp_err_log,
    dcmp_ad_ras_dp_err_log,
    axi_bridge_ras_dp_err_inj_core_clk,

    // Tag management interface
    req_pkt_out_tag
   );

   import DWC_pcie_bridge_atop_pkg::*;

// FSM state definition
// ---------------------------------------------------------------------------------------------------------------------
localparam S_READY                           = 6'b00_0000;
localparam S_WR_NODCMP                       = 6'b00_0001;
localparam S_WR_DCMP_FIRST_TLP_INTMD_BEAT    = 6'b01_0010;
localparam S_WR_DCMP_FIRST_TLP_LAST_BEAT     = 6'b10_0010;
localparam S_WR_DCMP_LAST_TLP_FIRST_BEAT     = 6'b00_1010;
localparam S_WR_DCMP_LAST_TLP_INTMD_BEAT     = 6'b01_1010;
localparam S_WR_DCMP_LAST_TLP_LAST_BEAT      = 6'b10_1010;
localparam S_WR_DCMP_LAST_TLP_SINGLE_BEAT    = 6'b11_1010;
localparam S_WR_DCMP_LAST_TLP_EXTRA_BEAT     = 6'b10_1110;
localparam S_WR_DCMP_EXTRA_TLP_SINGLE_BEAT   = 6'b11_1110;

// Parameters depending on decomposer usage (inbound vs outbound, posted vs non-posted)
// ---------------------------------------------------------------------------------------------------------------------
parameter  NW                            = 1;                  // Number of DWORDs in data bus
parameter  PKT_HDR_WD                    = 156;
parameter  PKT_ADDR_WD                   = 64;
parameter  PKT_DATA_WD                   = 64;
parameter  PKT_BYTE_LEN_IN_WD            = 13;
parameter  PKT_BYTE_LEN_OUT_WD           = 13;
parameter  PKT_OUT_TAG_WD                = 4;
parameter  PAGE_BOUNDARY_BIT             = 13;                           // power of 2 of address boundary uncrossable + 1.
parameter  PKT_LOW_ADDR_WD               = `DC_MCB_MAX_CPL_NUM_DWORDS_WD-1;
parameter  TP                            = `TP;                          // Clock to Q delay (simulator insurance)

// Parameters set by coreConsultant
// ---------------------------------------------------------------------------------------------------------------------
localparam PF_WD                         = `CX_NFUNC_WD;                 // Width of func_num bus
localparam CC_MSTR_MTU                   = `CC_MSTR_MTU;                 // Number of functions
localparam CC_MSTR_NW                    = `CC_MSTR_NW;
localparam CX_RAS_ENA                     = |`CX_RASDP;                   // RAS.DP Enabled 0 ; Disabled 1
localparam CX_RAS_PROT_RANGE             = `CX_RAS_PROT_RANGE;
localparam CX_RAS_PARITY_MODE            = `CX_RAS_PARITY_MODE;

// Internal parameters
// ---------------------------------------------------------------------------------------------------------------------
parameter DBUS_DWORD_WD_WITH_PAR = `CC_DBUS_DWORD_WD_WITH_PAR;
parameter ADDR_WD_WO_PAR         = CX_RAS_ENA ? ((PKT_ADDR_WD >=64) ? 64:32) : PKT_ADDR_WD;
parameter ADDR_PAR_WIDTH         = PKT_ADDR_WD - ADDR_WD_WO_PAR;
parameter PKT_DATA_BYTE_WD       = PKT_DATA_WD/8;

localparam NUM_DATA_PAR_BLOCKS           = `PCIE_CORE_DATA_BUS_WD/CX_RAS_PROT_RANGE;
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
input  wire [PKT_DATA_WD -1:0]               req_pkt_data;
input  wire [7:0]                            req_pkt_byte_en;
input  wire [PKT_BYTE_LEN_IN_WD -1 :0]       req_pkt_byte_len;
input  wire [PF_WD-1:0]                      req_pkt_func_num;
input  wire [1:0]                            req_pkt_fmt;
input  wire [4:0]                            req_pkt_type;

input  wire                                  dwnstrm_pkt_halt;
output wire                                  inq_pkt_hv;
output wire                                  inq_pkt_dv;
output wire                                  inq_pkt_eot;
output wire [PKT_HDR_WD -1:0]                inq_pkt_hdr;
output wire [PKT_ADDR_WD -1:0]               inq_pkt_addr;
output wire [PKT_DATA_WD -1:0]               inq_pkt_data;
output wire [7:0]                            inq_pkt_byte_en;
output wire [PKT_BYTE_LEN_OUT_WD -1:0]       inq_pkt_byte_len;
output wire [PKT_BYTE_LEN_IN_WD -1:0]        inq_pkt_req_byte_len;
output wire [PF_WD-1:0]                      inq_pkt_func_num;
output wire [PKT_OUT_TAG_WD -1:0]            inq_pkt_out_tag;
output wire                                  inq_pkt_ncbe;
output wire                                  inq_pkt_last_tlp;
output wire [PKT_LOW_ADDR_WD -1:0]           inq_pkt_low_addr;
output wire                                  inq_pkt_np_tlp_issued;
output wire                                  dcmp_addr_parerr;
output wire                                  dcmp_data_parerr;
output ras_dp_err_log_t                      dcmp_dt_ras_dp_err_log;
output ras_dp_err_log_t                      dcmp_ad_ras_dp_err_log;
input  ras_dp_err_inj_t                      axi_bridge_ras_dp_err_inj_core_clk;

// Tag management interface
input  wire [PKT_OUT_TAG_WD -1:0]            req_pkt_out_tag;

wire   [6:0]                                 req_pkt_fmt_type;

wire   [12:0]                                s_cc_mstr_mtu_byte_len;
wire   [10:0]                                s_cc_mstr_mtu_dw_len;
wire   [10:0]                                s_cc_mstr_mtu_dw_len_addr_mask;
wire   [10:0]                                s_master_dw_page_boundary;
wire   [10:0]                                s_master_dw_page_boundary_addr_mask;

reg    [ADDR_PAR_WIDTH -1:0]                       s_calc_req_addr_par;
reg    [ADDR_PAR_WIDTH -1:0]                       s_calc_inq_addr_par;
reg    [ADDR_PAR_WIDTH-1:0][CX_RAS_PROT_RANGE-1:0] s_req_pkt_addr_nopar_int;
reg    [ADDR_PAR_WIDTH -1:0]                       s_req_pkt_addr_parity;
wire   [ADDR_PAR_WIDTH-1:0][CX_RAS_PROT_RANGE-1:0] s_inq_pkt_addr_nopar;
wire   [ADDR_PAR_WIDTH-1:0][CX_RAS_PROT_RANGE-1:0] req_pkt_addr_nopar;

reg    [5:0]                                 state;
reg    [5:0]                                 next_state;

reg    [PKT_HDR_WD -1:0]                     r_latched_pkt_hdr;
reg    [ADDR_WD_WO_PAR -1:0]                    r_latched_pkt_addr;
reg    [7:0]                                 r_latched_pkt_byte_en;
reg    [PKT_BYTE_LEN_IN_WD -1 :0]            r_latched_pkt_byte_len;
reg    [PF_WD-1:0]                           r_latched_pkt_func_num;
reg    [6:0]                                 r_latched_pkt_fmt_type;

wire                                         s_latch_req_pkt;

wire   [PKT_BYTE_LEN_IN_WD -1 :0]            s_pkt_byte_len;
wire   [PKT_BYTE_LEN_IN_WD -3 :0]            s_pkt_dw_len;
wire   [PKT_HDR_WD -1:0]                     s_pkt_hdr;
wire   [ADDR_WD_WO_PAR -1:0]                    s_pkt_addr;
wire   [7:0]                                 s_pkt_byte_en;
wire   [PF_WD-1:0]                           s_pkt_func_num;
wire   [6:0]                                 s_pkt_fmt_type;

wire                                         s_pkt_msg_req;
wire                                         s_pkt_np_req;

wire   [PKT_BYTE_LEN_IN_WD -3 :0]            s_pkt_extra_dw_len;
wire   [PKT_BYTE_LEN_IN_WD -3 :0]            s_pkt_effective_dw_len;
wire   [PKT_BYTE_LEN_IN_WD -3 :0]            s_pkt_remaining_dw_len;
reg    [PKT_BYTE_LEN_IN_WD -3 :0]            r_pkt_sent_dw_len;
wire   [PKT_BYTE_LEN_IN_WD -3 :0]            s_pkt_sent_dw_len;

wire   [10:0]                                s_pkt_dw_to_next_max_payload;
wire   [10:0]                                s_pkt_dw_to_next_max_rd_req;
wire   [10:0]                                s_pkt_dw_to_next_page_boundary;
wire   [10:0]                                s_pkt_dw_to_next_max_transfer_unit;
wire   [10:0]                                s_pkt_dw_after_next_max_transfer_unit;
wire   [10:0]                                s_pkt_dw_sent_after_current_tlp;
wire   [10:0]                                s_pkt_dw_remaining_after_current_tlp;
wire                                         s_pkt_crosses_page_boundary;
wire                                         s_pkt_exceeds_max_transfer_unit;
wire                                         s_decomposition_required;

reg    [PKT_DATA_WD -1:0]                    r_pkt_data;
wire   [2*PKT_DATA_WD -1:0]                  s_pkt_data_mux;
wire   [4:0]                                 s_pkt_data_sel;
reg    [4:0]                                 r_pkt_data_sel;

wire   [PKT_BYTE_LEN_OUT_WD -3 :0]           s_tlp_dw_len;
reg    [PKT_BYTE_LEN_OUT_WD -3 :0]           r_tlp_dw_len;
wire   [PKT_BYTE_LEN_OUT_WD -3 :0]           s_tlp_sent_dw_len;
wire   [PKT_BYTE_LEN_OUT_WD -3: 0]           s_tlp_sent_after_current_beat_dw_len;
wire   [PKT_BYTE_LEN_OUT_WD -3: 0]           s_tlp_after_current_beat_dw_len;
reg    [PKT_BYTE_LEN_OUT_WD -3 :0]           r_tlp_sent_dw_len;
wire   [PKT_BYTE_LEN_OUT_WD -3 :0]           s_tlp_remaining_dw_len;

wire   [PKT_BYTE_LEN_OUT_WD -3 :0]           s_tlp_beat_dw_len;

wire   [ADDR_WD_WO_PAR -1:0]                 s_tlp_addr;

wire                                         s_tlp_first_beat;
wire                                         s_tlp_last_beat;

wire                                         s_pkt_first_tlp;
wire                                         s_pkt_last_tlp;

reg    [PKT_OUT_TAG_WD -1:0]                 r_req_pkt_out_tag;

wire   [PKT_BYTE_LEN_OUT_WD -3:0]            s_inq_pkt_dw_len;


assign req_pkt_fmt_type  = {req_pkt_fmt, req_pkt_type};

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
    .RAS_DP_PROT_CHK_ID_BASE   (`WR_DCMP_AD_RAS_ID             )
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
// Detectecting parity on the data
// ----------------------------------------------------------------------------------------------------------------------
   wire   data_chk_en;
   wire [PKT_DATA_WD -1:0] req_pkt_data_chk;
   assign data_chk_en = req_pkt_dv & !inq_pkt_halt;
   assign req_pkt_data_chk = req_pkt_data;

   ras_dp_pipe
    #(
    .PIPELINE_TYPE             (0                                  ),
    .RESETVAL                  (0                                  ),
    .N_STAGES                  (0                                  ),
    .CAN_STALL                 (0                                  ),
    .RESET_STALL               (0                                  ),
    .BUS_PROTECT_GEN_EN        (0                                  ),
    .BUS_PROTECT_CHK_EN        (1                                  ),
    .PROT_TYPE                 (1                                  ), // 0=Ecc            1=Simple Parity
    .PROT_RANGE                (CX_RAS_PROT_RANGE                  ), // Number of bits to calculate parity or ECC on
    .PROT_WD                   (NUM_DATA_PAR_BLOCKS                ),
    .PARITY_MODE               (CX_RAS_PARITY_MODE                 ),
    .PROT_CORRECT_EN           (0                                  ),
    .TOTAL_WIDTH               (`PCIE_CORE_DATA_BUS_WD             ),
    .EXCLUDE_PROT_WIDTH        (0                                  ),
    .RAS_DP_PROT_CHK_ID_BASE   (`DCMP_DT_RAS_ID                    )
  ) u_data_chk (
    .clk                       ( in_clk                            ),
    .rst_n                     ( in_rst_n                          ),
    .din                       ( fn_data_wo_par  (req_pkt_data_chk)),
    .din_prot                  ( fn_prot_chkin_dt(req_pkt_data_chk)),
    .dout                      ( /*Not connected*/                 ),
    .dout_prot                 ( /*Not connected*/                 ),
    .en                        (1'b1                               ),
    .bypass                    (1'b0                               ),
    .stall                     (1'b0                               ),
    .stallout                  ( /*Not connected*/                 ),
    .valid_in                  ( data_chk_en                       ),
    .halt_out                  ( /*Not connected*/                 ),
    .valid_out                 ( /*Not connected*/                 ),
    .halt_in                   (1'b0                               ),
    .ras_dp_err_inband_kbd_in  (1'b0                               ),
    .ras_dp_err_inband_kbd_out ( /*Not connected*/                 ),
    .ras_dp_err_log            ( dcmp_dt_ras_dp_err_log            )
      ,
      .ras_dp_err_inj          (axi_bridge_ras_dp_err_inj_core_clk )
    );

   assign dcmp_data_parerr = dcmp_dt_ras_dp_err_log.valid;



// latch request when accepted
// ---------------------------------------------------------------------------------------------------------------------
assign s_latch_req_pkt          = (state == S_READY) && req_pkt_hv && !dwnstrm_pkt_halt;


always@(posedge in_clk or negedge in_rst_n)
  begin: R_LATCHED_PKT_SEQ_PROC
    if(!in_rst_n) begin
        r_latched_pkt_hdr          <= #TP {PKT_HDR_WD{1'b0}};
        r_latched_pkt_addr         <= #TP {PKT_ADDR_WD{1'b0}};
        r_latched_pkt_byte_en      <= #TP 8'h00;
        r_latched_pkt_func_num     <= #TP {PF_WD{1'b0}};
        r_latched_pkt_fmt_type     <= #TP 7'h00;
        r_latched_pkt_byte_len     <= #TP {PKT_BYTE_LEN_IN_WD{1'b0}};
      end else if (s_latch_req_pkt) begin
        r_latched_pkt_hdr          <= #TP req_pkt_hdr;
        r_latched_pkt_addr         <= #TP req_pkt_addr_nopar;
        r_latched_pkt_byte_en      <= #TP req_pkt_byte_en;
        r_latched_pkt_func_num     <= #TP req_pkt_func_num;
        r_latched_pkt_fmt_type     <= #TP req_pkt_fmt_type;
        r_latched_pkt_byte_len     <= #TP req_pkt_byte_len;
      end
  end


assign s_pkt_byte_len           = s_latch_req_pkt          ? req_pkt_byte_len   : r_latched_pkt_byte_len;
assign s_pkt_hdr                = s_latch_req_pkt          ? req_pkt_hdr        : r_latched_pkt_hdr;
assign s_pkt_addr               = s_latch_req_pkt          ? req_pkt_addr_nopar : r_latched_pkt_addr;
assign s_pkt_byte_en            = s_latch_req_pkt          ? req_pkt_byte_en    : r_latched_pkt_byte_en;
assign s_pkt_func_num           = s_latch_req_pkt          ? req_pkt_func_num   : r_latched_pkt_func_num;
assign s_pkt_fmt_type           = s_latch_req_pkt          ? req_pkt_fmt_type   : r_latched_pkt_fmt_type;
assign s_pkt_dw_len             = (s_pkt_fmt_type[6:0] inside {`CAS32, `CAS64}) ? (PKT_BYTE_LEN_IN_WD-2)'(s_pkt_byte_len[PKT_BYTE_LEN_IN_WD-1:2] >> 1) : s_pkt_byte_len[PKT_BYTE_LEN_IN_WD-1:2];
//assign s_pkt_dw_len             = s_pkt_byte_len[PKT_BYTE_LEN_IN_WD-1:2];

// request type decoding
// ---------------------------------------------------------------------------------------------------------------------
assign s_pkt_np_req         =        (s_pkt_fmt_type[6:0] == `IOWR)
                                  || (s_pkt_fmt_type[6:0] == `CFGWR1)
                                  || (s_pkt_fmt_type[6:0] == `CFGWR0)
                                  || (s_pkt_fmt_type[6:0] == `DMWR32)
                                  || (s_pkt_fmt_type[6:0] == `DMWR64)
                                  || (s_pkt_fmt_type[6:0] == `FETCHADD32)
                                  || (s_pkt_fmt_type[6:0] == `FETCHADD64)
                                  || (s_pkt_fmt_type[6:0] == `SWAP32)
                                  || (s_pkt_fmt_type[6:0] == `SWAP64)
                                  || (s_pkt_fmt_type[6:0] == `CAS32)
                                  || (s_pkt_fmt_type[6:0] == `CAS64)
                                                                    ;

assign s_pkt_msg_req        =       ((s_pkt_fmt_type[6:3] == `MSG_4)
                                  || (s_pkt_fmt_type[6:3] == `MSGD_4));


// s_pkt_effective_dw_len                : effective request packet length in DWs; wire requests are DW aligned but
//                                         AXI requests are data width aligned, so inbound requests may need to be
//                                         shifted by an amount equal to the difference between DW address and data
//                                         width boundary. The value of this shift needs to be added to the original
//                                         packet request length to determine if the request crosses a page boundary
// ---------------------------------------------------------------------------------------------------------------------
assign s_pkt_extra_dw_len     = CC_MSTR_NW == 32 ? {{(PKT_BYTE_LEN_IN_WD-7){1'b0}},s_pkt_addr[6:2]} :
                                CC_MSTR_NW == 16 ? {{(PKT_BYTE_LEN_IN_WD-6){1'b0}},s_pkt_addr[5:2]} :
                                CC_MSTR_NW ==  8 ? {{(PKT_BYTE_LEN_IN_WD-5){1'b0}},s_pkt_addr[4:2]} :
                                CC_MSTR_NW ==  4 ? {{(PKT_BYTE_LEN_IN_WD-4){1'b0}},s_pkt_addr[3:2]} :
                                CC_MSTR_NW ==  2 ? {{(PKT_BYTE_LEN_IN_WD-3){1'b0}},s_pkt_addr[2]  } :
                                                    {(PKT_BYTE_LEN_IN_WD-2){1'b0}};
// spyglass disable_block W164a
// SMD: Identifies assignments in which the LHS width is less than the RHS width
// SJ: The rule reports assignments where the result of an addition or subtraction operation is being assigned to a bus of the same width as the operands of the addition or subtraction operation. In this code, the value of the operands is never large enough to cause overflow.
assign s_pkt_effective_dw_len = s_pkt_dw_len + s_pkt_extra_dw_len;
// spyglass enable_block W164a

always@(posedge in_clk or negedge in_rst_n)
  begin: R_PKT_DATA_SEQ_PROC
    if (!in_rst_n) begin
      r_pkt_data <= #TP 0;
    end else begin
      if(req_pkt_dv && !inq_pkt_halt) begin
        r_pkt_data <= #TP req_pkt_data;
      end
    end
  end

generate
if (NW == 32) begin : GEN_S_PKT_DATA_SEL_NW_EQ_32
assign s_pkt_data_sel =       s_pkt_dw_to_next_max_transfer_unit[4:0];
end else if (NW == 16) begin : GEN_S_PKT_DATA_SEL_NW_EQ_16
assign s_pkt_data_sel = {1'h0,s_pkt_dw_to_next_max_transfer_unit[3:0]};
end else if (NW == 8) begin : GEN_S_PKT_DATA_SEL_NW_EQ_8
assign s_pkt_data_sel = {2'h0,s_pkt_dw_to_next_max_transfer_unit[2:0]};
end else if (NW == 4) begin : GEN_S_PKT_DATA_SEL_NW_EQ_4
assign s_pkt_data_sel = {3'h0,s_pkt_dw_to_next_max_transfer_unit[1:0]};
end else if (NW == 2) begin : GEN_S_PKT_DATA_SEL_NW_EQ_2
assign s_pkt_data_sel = {4'h0,s_pkt_dw_to_next_max_transfer_unit[0]};
end else begin : GEN_S_PKT_DATA_SEL_NW_EQ_1
assign s_pkt_data_sel = 0;
end
endgenerate

always@(posedge in_clk or negedge in_rst_n)
  begin: R_PKT_DATA_SEL_SEQ_PROC
    if (!in_rst_n) begin
      r_pkt_data_sel <= #TP '0;
    end else begin
      if (!dwnstrm_pkt_halt) begin
        if ( (state == S_WR_DCMP_LAST_TLP_EXTRA_BEAT) || (state == S_WR_DCMP_EXTRA_TLP_SINGLE_BEAT) ) begin
            r_pkt_data_sel <= #TP '0;
        end else
        if (req_pkt_dv) begin
          if( (state == S_WR_DCMP_FIRST_TLP_LAST_BEAT) || ( (state == S_READY) && (s_pkt_dw_to_next_max_transfer_unit <= NW) && s_decomposition_required ))begin
            r_pkt_data_sel <= #TP s_pkt_data_sel;
          end else if(
                      (state == S_WR_DCMP_LAST_TLP_EXTRA_BEAT) ||
                      (state == S_WR_DCMP_EXTRA_TLP_SINGLE_BEAT) ||
                      (state == S_WR_DCMP_LAST_TLP_LAST_BEAT) ||
                      (state == S_WR_DCMP_LAST_TLP_SINGLE_BEAT)

                     ) begin
            r_pkt_data_sel <= #TP '0;
          end
        end
      end
    end
  end

generate
if (NW > 1) begin : GEN_S_PKT_DATA_MUX_NW_GT_1
assign s_pkt_data_mux = {req_pkt_data,r_pkt_data};
end else begin : GEN_S_PKT_DATA_MUX_NW_EQ_1
assign s_pkt_data_mux = { {PKT_DATA_WD{1'b0}} , req_pkt_data};
end

if (NW == 32) begin : GEN_INQ_PKT_DATA_NW_EQ_32
assign inq_pkt_data     =  (r_pkt_data_sel == 5'b00000) ? s_pkt_data_mux[(DBUS_DWORD_WD_WITH_PAR*(NW+32))-1:DBUS_DWORD_WD_WITH_PAR*32] :
                           (r_pkt_data_sel == 5'b00001) ? s_pkt_data_mux[(DBUS_DWORD_WD_WITH_PAR*(NW+1 ))-1:DBUS_DWORD_WD_WITH_PAR*1 ] :
                           (r_pkt_data_sel == 5'b00010) ? s_pkt_data_mux[(DBUS_DWORD_WD_WITH_PAR*(NW+2 ))-1:DBUS_DWORD_WD_WITH_PAR*2 ] :
                           (r_pkt_data_sel == 5'b00011) ? s_pkt_data_mux[(DBUS_DWORD_WD_WITH_PAR*(NW+3 ))-1:DBUS_DWORD_WD_WITH_PAR*3 ] :
                           (r_pkt_data_sel == 5'b00100) ? s_pkt_data_mux[(DBUS_DWORD_WD_WITH_PAR*(NW+4 ))-1:DBUS_DWORD_WD_WITH_PAR*4 ] :
                           (r_pkt_data_sel == 5'b00101) ? s_pkt_data_mux[(DBUS_DWORD_WD_WITH_PAR*(NW+5 ))-1:DBUS_DWORD_WD_WITH_PAR*5 ] :
                           (r_pkt_data_sel == 5'b00110) ? s_pkt_data_mux[(DBUS_DWORD_WD_WITH_PAR*(NW+6 ))-1:DBUS_DWORD_WD_WITH_PAR*6 ] :
                           (r_pkt_data_sel == 5'b00111) ? s_pkt_data_mux[(DBUS_DWORD_WD_WITH_PAR*(NW+7 ))-1:DBUS_DWORD_WD_WITH_PAR*7 ] :
                           (r_pkt_data_sel == 5'b01000) ? s_pkt_data_mux[(DBUS_DWORD_WD_WITH_PAR*(NW+8 ))-1:DBUS_DWORD_WD_WITH_PAR*8 ] :
                           (r_pkt_data_sel == 5'b01001) ? s_pkt_data_mux[(DBUS_DWORD_WD_WITH_PAR*(NW+9 ))-1:DBUS_DWORD_WD_WITH_PAR*9 ] :
                           (r_pkt_data_sel == 5'b01010) ? s_pkt_data_mux[(DBUS_DWORD_WD_WITH_PAR*(NW+10))-1:DBUS_DWORD_WD_WITH_PAR*10] :
                           (r_pkt_data_sel == 5'b01011) ? s_pkt_data_mux[(DBUS_DWORD_WD_WITH_PAR*(NW+11))-1:DBUS_DWORD_WD_WITH_PAR*11] :
                           (r_pkt_data_sel == 5'b01100) ? s_pkt_data_mux[(DBUS_DWORD_WD_WITH_PAR*(NW+12))-1:DBUS_DWORD_WD_WITH_PAR*12] :
                           (r_pkt_data_sel == 5'b01101) ? s_pkt_data_mux[(DBUS_DWORD_WD_WITH_PAR*(NW+13))-1:DBUS_DWORD_WD_WITH_PAR*13] :
                           (r_pkt_data_sel == 5'b01110) ? s_pkt_data_mux[(DBUS_DWORD_WD_WITH_PAR*(NW+14))-1:DBUS_DWORD_WD_WITH_PAR*14] :
                           (r_pkt_data_sel == 5'b01111) ? s_pkt_data_mux[(DBUS_DWORD_WD_WITH_PAR*(NW+15))-1:DBUS_DWORD_WD_WITH_PAR*15] :
                           (r_pkt_data_sel == 5'b10000) ? s_pkt_data_mux[(DBUS_DWORD_WD_WITH_PAR*(NW+16))-1:DBUS_DWORD_WD_WITH_PAR*16] :
                           (r_pkt_data_sel == 5'b10001) ? s_pkt_data_mux[(DBUS_DWORD_WD_WITH_PAR*(NW+17))-1:DBUS_DWORD_WD_WITH_PAR*17] :
                           (r_pkt_data_sel == 5'b10010) ? s_pkt_data_mux[(DBUS_DWORD_WD_WITH_PAR*(NW+18))-1:DBUS_DWORD_WD_WITH_PAR*18] :
                           (r_pkt_data_sel == 5'b10011) ? s_pkt_data_mux[(DBUS_DWORD_WD_WITH_PAR*(NW+19))-1:DBUS_DWORD_WD_WITH_PAR*19] :
                           (r_pkt_data_sel == 5'b10100) ? s_pkt_data_mux[(DBUS_DWORD_WD_WITH_PAR*(NW+20))-1:DBUS_DWORD_WD_WITH_PAR*20] :
                           (r_pkt_data_sel == 5'b10101) ? s_pkt_data_mux[(DBUS_DWORD_WD_WITH_PAR*(NW+21))-1:DBUS_DWORD_WD_WITH_PAR*21] :
                           (r_pkt_data_sel == 5'b10110) ? s_pkt_data_mux[(DBUS_DWORD_WD_WITH_PAR*(NW+22))-1:DBUS_DWORD_WD_WITH_PAR*22] :
                           (r_pkt_data_sel == 5'b10111) ? s_pkt_data_mux[(DBUS_DWORD_WD_WITH_PAR*(NW+23))-1:DBUS_DWORD_WD_WITH_PAR*23] :
                           (r_pkt_data_sel == 5'b11000) ? s_pkt_data_mux[(DBUS_DWORD_WD_WITH_PAR*(NW+24))-1:DBUS_DWORD_WD_WITH_PAR*24] :
                           (r_pkt_data_sel == 5'b11001) ? s_pkt_data_mux[(DBUS_DWORD_WD_WITH_PAR*(NW+25))-1:DBUS_DWORD_WD_WITH_PAR*25] :
                           (r_pkt_data_sel == 5'b11010) ? s_pkt_data_mux[(DBUS_DWORD_WD_WITH_PAR*(NW+26))-1:DBUS_DWORD_WD_WITH_PAR*26] :
                           (r_pkt_data_sel == 5'b11011) ? s_pkt_data_mux[(DBUS_DWORD_WD_WITH_PAR*(NW+27))-1:DBUS_DWORD_WD_WITH_PAR*27] :
                           (r_pkt_data_sel == 5'b11100) ? s_pkt_data_mux[(DBUS_DWORD_WD_WITH_PAR*(NW+28))-1:DBUS_DWORD_WD_WITH_PAR*28] :
                           (r_pkt_data_sel == 5'b11101) ? s_pkt_data_mux[(DBUS_DWORD_WD_WITH_PAR*(NW+29))-1:DBUS_DWORD_WD_WITH_PAR*29] :
                           (r_pkt_data_sel == 5'b11110) ? s_pkt_data_mux[(DBUS_DWORD_WD_WITH_PAR*(NW+30))-1:DBUS_DWORD_WD_WITH_PAR*30] :
                           (r_pkt_data_sel == 5'b11111) ? s_pkt_data_mux[(DBUS_DWORD_WD_WITH_PAR*(NW+31))-1:DBUS_DWORD_WD_WITH_PAR*31] :
                                                          s_pkt_data_mux[(DBUS_DWORD_WD_WITH_PAR*(NW+32))-1:DBUS_DWORD_WD_WITH_PAR*32];
end else if (NW == 16) begin : GEN_INQ_PKT_DATA_NW_EQ_16
assign inq_pkt_data     =  (r_pkt_data_sel == 4'b0000) ? s_pkt_data_mux[(DBUS_DWORD_WD_WITH_PAR*(NW+16))-1:DBUS_DWORD_WD_WITH_PAR*16] :
                           (r_pkt_data_sel == 4'b0001) ? s_pkt_data_mux[(DBUS_DWORD_WD_WITH_PAR*(NW+1 ))-1:DBUS_DWORD_WD_WITH_PAR*1 ] :
                           (r_pkt_data_sel == 4'b0010) ? s_pkt_data_mux[(DBUS_DWORD_WD_WITH_PAR*(NW+2 ))-1:DBUS_DWORD_WD_WITH_PAR*2 ] :
                           (r_pkt_data_sel == 4'b0011) ? s_pkt_data_mux[(DBUS_DWORD_WD_WITH_PAR*(NW+3 ))-1:DBUS_DWORD_WD_WITH_PAR*3 ] :
                           (r_pkt_data_sel == 4'b0100) ? s_pkt_data_mux[(DBUS_DWORD_WD_WITH_PAR*(NW+4 ))-1:DBUS_DWORD_WD_WITH_PAR*4 ] :
                           (r_pkt_data_sel == 4'b0101) ? s_pkt_data_mux[(DBUS_DWORD_WD_WITH_PAR*(NW+5 ))-1:DBUS_DWORD_WD_WITH_PAR*5 ] :
                           (r_pkt_data_sel == 4'b0110) ? s_pkt_data_mux[(DBUS_DWORD_WD_WITH_PAR*(NW+6 ))-1:DBUS_DWORD_WD_WITH_PAR*6 ] :
                           (r_pkt_data_sel == 4'b0111) ? s_pkt_data_mux[(DBUS_DWORD_WD_WITH_PAR*(NW+7 ))-1:DBUS_DWORD_WD_WITH_PAR*7 ] :
                           (r_pkt_data_sel == 4'b1000) ? s_pkt_data_mux[(DBUS_DWORD_WD_WITH_PAR*(NW+8 ))-1:DBUS_DWORD_WD_WITH_PAR*8 ] :
                           (r_pkt_data_sel == 4'b1001) ? s_pkt_data_mux[(DBUS_DWORD_WD_WITH_PAR*(NW+9 ))-1:DBUS_DWORD_WD_WITH_PAR*9 ] :
                           (r_pkt_data_sel == 4'b1010) ? s_pkt_data_mux[(DBUS_DWORD_WD_WITH_PAR*(NW+10))-1:DBUS_DWORD_WD_WITH_PAR*10] :
                           (r_pkt_data_sel == 4'b1011) ? s_pkt_data_mux[(DBUS_DWORD_WD_WITH_PAR*(NW+11))-1:DBUS_DWORD_WD_WITH_PAR*11] :
                           (r_pkt_data_sel == 4'b1100) ? s_pkt_data_mux[(DBUS_DWORD_WD_WITH_PAR*(NW+12))-1:DBUS_DWORD_WD_WITH_PAR*12] :
                           (r_pkt_data_sel == 4'b1101) ? s_pkt_data_mux[(DBUS_DWORD_WD_WITH_PAR*(NW+13))-1:DBUS_DWORD_WD_WITH_PAR*13] :
                           (r_pkt_data_sel == 4'b1110) ? s_pkt_data_mux[(DBUS_DWORD_WD_WITH_PAR*(NW+14))-1:DBUS_DWORD_WD_WITH_PAR*14] :
                           (r_pkt_data_sel == 4'b1111) ? s_pkt_data_mux[(DBUS_DWORD_WD_WITH_PAR*(NW+15))-1:DBUS_DWORD_WD_WITH_PAR*15] :
                                                         s_pkt_data_mux[(DBUS_DWORD_WD_WITH_PAR*(NW+16))-1:DBUS_DWORD_WD_WITH_PAR*16];
end else if (NW == 8) begin : GEN_INQ_PKT_DATA_NW_EQ_8
assign inq_pkt_data     =  (r_pkt_data_sel == 4'b0000) ? s_pkt_data_mux[(DBUS_DWORD_WD_WITH_PAR*(NW+8 ))-1:DBUS_DWORD_WD_WITH_PAR*8 ] :
                           (r_pkt_data_sel == 4'b0001) ? s_pkt_data_mux[(DBUS_DWORD_WD_WITH_PAR*(NW+1 ))-1:DBUS_DWORD_WD_WITH_PAR*1 ] :
                           (r_pkt_data_sel == 4'b0010) ? s_pkt_data_mux[(DBUS_DWORD_WD_WITH_PAR*(NW+2 ))-1:DBUS_DWORD_WD_WITH_PAR*2 ] :
                           (r_pkt_data_sel == 4'b0011) ? s_pkt_data_mux[(DBUS_DWORD_WD_WITH_PAR*(NW+3 ))-1:DBUS_DWORD_WD_WITH_PAR*3 ] :
                           (r_pkt_data_sel == 4'b0100) ? s_pkt_data_mux[(DBUS_DWORD_WD_WITH_PAR*(NW+4 ))-1:DBUS_DWORD_WD_WITH_PAR*4 ] :
                           (r_pkt_data_sel == 4'b0101) ? s_pkt_data_mux[(DBUS_DWORD_WD_WITH_PAR*(NW+5 ))-1:DBUS_DWORD_WD_WITH_PAR*5 ] :
                           (r_pkt_data_sel == 4'b0110) ? s_pkt_data_mux[(DBUS_DWORD_WD_WITH_PAR*(NW+6 ))-1:DBUS_DWORD_WD_WITH_PAR*6 ] :
                           (r_pkt_data_sel == 4'b0111) ? s_pkt_data_mux[(DBUS_DWORD_WD_WITH_PAR*(NW+7 ))-1:DBUS_DWORD_WD_WITH_PAR*7 ] :
                                                         s_pkt_data_mux[(DBUS_DWORD_WD_WITH_PAR*(NW+8 ))-1:DBUS_DWORD_WD_WITH_PAR*8 ];
end else if (NW == 4) begin : GEN_INQ_PKT_DATA_NW_EQ_4
assign inq_pkt_data     =  (r_pkt_data_sel == 4'b0000) ? s_pkt_data_mux[(DBUS_DWORD_WD_WITH_PAR*(NW+4 ))-1:DBUS_DWORD_WD_WITH_PAR*4 ] :
                           (r_pkt_data_sel == 4'b0001) ? s_pkt_data_mux[(DBUS_DWORD_WD_WITH_PAR*(NW+1 ))-1:DBUS_DWORD_WD_WITH_PAR*1 ] :
                           (r_pkt_data_sel == 4'b0010) ? s_pkt_data_mux[(DBUS_DWORD_WD_WITH_PAR*(NW+2 ))-1:DBUS_DWORD_WD_WITH_PAR*2 ] :
                           (r_pkt_data_sel == 4'b0011) ? s_pkt_data_mux[(DBUS_DWORD_WD_WITH_PAR*(NW+3 ))-1:DBUS_DWORD_WD_WITH_PAR*3 ] :
                                                         s_pkt_data_mux[(DBUS_DWORD_WD_WITH_PAR*(NW+4 ))-1:DBUS_DWORD_WD_WITH_PAR*4 ];
end else if (NW == 2) begin : GEN_INQ_PKT_DATA_NW_EQ_2
assign inq_pkt_data     =  (r_pkt_data_sel == 4'b0000) ? s_pkt_data_mux[(DBUS_DWORD_WD_WITH_PAR*(NW+2 ))-1:DBUS_DWORD_WD_WITH_PAR*2 ] :
                           (r_pkt_data_sel == 4'b0001) ? s_pkt_data_mux[(DBUS_DWORD_WD_WITH_PAR*(NW+1 ))-1:DBUS_DWORD_WD_WITH_PAR*1 ] :
                                                         s_pkt_data_mux[(DBUS_DWORD_WD_WITH_PAR*(NW+2 ))-1:DBUS_DWORD_WD_WITH_PAR*2 ];
end else begin : GEN_INQ_PKT_DATA_NW_EQ_1
assign inq_pkt_data     = req_pkt_data;
end
endgenerate

always@(posedge in_clk or negedge in_rst_n)
  begin: IB_WR_R_PKT_SENT_DW_LEN_SEQ_PROC
    if (!in_rst_n) begin
      r_pkt_sent_dw_len <= #TP 0;
    end else begin
      if (!dwnstrm_pkt_halt) begin
        if(state == S_READY) begin
          if (s_tlp_last_beat && inq_pkt_dv) begin
            r_pkt_sent_dw_len <= #TP s_tlp_dw_len;
          end else begin
            r_pkt_sent_dw_len <= #TP 0;
          end
        end else begin
          if (s_tlp_last_beat && inq_pkt_dv) begin
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
assign s_pkt_dw_after_next_max_transfer_unit =  {{(11-(PKT_BYTE_LEN_IN_WD -2)){1'b0}},s_pkt_dw_len} - s_pkt_dw_to_next_max_transfer_unit; // DW length remaining on request after decomposition boundary
assign s_pkt_dw_sent_after_current_tlp       =  r_pkt_sent_dw_len + s_inq_pkt_dw_len;
assign s_pkt_dw_remaining_after_current_tlp  =  s_pkt_dw_len - s_pkt_dw_sent_after_current_tlp;
// spyglass enable_block W164a
assign s_pkt_crosses_page_boundary           = |s_pkt_dw_to_next_page_boundary ? (s_pkt_remaining_dw_len > s_pkt_dw_to_next_page_boundary) : 1'b0;
assign s_pkt_exceeds_max_transfer_unit       =  s_pkt_first_tlp ? s_pkt_effective_dw_len > s_cc_mstr_mtu_dw_len : s_pkt_remaining_dw_len > s_cc_mstr_mtu_dw_len;


// s_decomposition_required
// ---------------------------------------------------------------------------------------------------------------------
assign s_decomposition_required = s_pkt_msg_req? 1'b0 : s_pkt_exceeds_max_transfer_unit || s_pkt_crosses_page_boundary;


assign s_pkt_first_tlp                       =   (state == S_READY) || (state == S_WR_NODCMP) || (state == S_WR_DCMP_FIRST_TLP_INTMD_BEAT) || (state == S_WR_DCMP_FIRST_TLP_LAST_BEAT);
assign s_pkt_last_tlp                        = (((state == S_READY) || (state == S_WR_NODCMP)) && !s_decomposition_required ) ||
                                                 (state == S_WR_DCMP_LAST_TLP_EXTRA_BEAT   ) ||
                                                 (state == S_WR_DCMP_EXTRA_TLP_SINGLE_BEAT) ||
                                                 (state == S_WR_DCMP_LAST_TLP_FIRST_BEAT   ) ||
                                                 (state == S_WR_DCMP_LAST_TLP_INTMD_BEAT   ) ||
                                                 (state == S_WR_DCMP_LAST_TLP_LAST_BEAT    ) ||
                                                 (state == S_WR_DCMP_LAST_TLP_SINGLE_BEAT  );
assign s_tlp_first_beat                      =  ((state == S_READY ) && req_pkt_hv ) ||
                                                 (state == S_WR_DCMP_EXTRA_TLP_SINGLE_BEAT ) ||
                                                 (state == S_WR_DCMP_LAST_TLP_FIRST_BEAT   ) ||
                                                 (state == S_WR_DCMP_LAST_TLP_SINGLE_BEAT  );

assign s_tlp_last_beat                       = (((state == S_READY) || (state == S_WR_NODCMP)) && req_pkt_eot) ||
                                                ((state == S_READY) && (s_tlp_dw_len <= NW)) ||
                                                 (state == S_WR_DCMP_FIRST_TLP_LAST_BEAT   ) ||
                                                 (state == S_WR_DCMP_LAST_TLP_EXTRA_BEAT   ) ||
                                                 (state == S_WR_DCMP_EXTRA_TLP_SINGLE_BEAT ) ||
                                                 (state == S_WR_DCMP_LAST_TLP_LAST_BEAT    ) ||
                                                 (state == S_WR_DCMP_LAST_TLP_SINGLE_BEAT  );
assign s_tlp_dw_len                          = s_tlp_first_beat ? (s_decomposition_required ? s_pkt_dw_to_next_max_transfer_unit : s_pkt_remaining_dw_len) : r_tlp_dw_len ;

always@(posedge in_clk or negedge in_rst_n)
  begin: R_TLP_DW_LEN_SEQ_PROC
    if(!in_rst_n) begin
      r_tlp_dw_len <= #TP 0;
    end else begin
      r_tlp_dw_len <= #TP s_tlp_dw_len;
    end
  end

assign s_tlp_sent_dw_len                    = s_tlp_first_beat ? 0 : r_tlp_sent_dw_len ;
assign s_tlp_beat_dw_len                    = s_tlp_last_beat  ? s_tlp_remaining_dw_len : NW ;
// spyglass disable_block W164a
// SMD: Identifies assignments in which the LHS width is less than the RHS width
// SJ: The rule reports assignments where the result of an addition or subtraction operation is being assigned to a bus of the same width as the operands of the addition or subtraction operation. In this code, the value of the operands is never large enough to cause overflow.
assign s_tlp_sent_after_current_beat_dw_len = s_tlp_sent_dw_len + s_tlp_beat_dw_len;
assign s_tlp_after_current_beat_dw_len      = s_tlp_dw_len - s_tlp_sent_after_current_beat_dw_len;
// spyglass enable_block W164a
always@(posedge in_clk or negedge in_rst_n)
  begin: R_TLP_SENT_DW_LEN_SEQ_PROC
    if (!in_rst_n) begin
      r_tlp_sent_dw_len <= #TP 0;
    end else begin
      if ( !dwnstrm_pkt_halt && req_pkt_dv ) begin
// spyglass disable_block W164a
// SMD: Identifies assignments in which the LHS width is less than the RHS width
// SJ: The rule reports assignments where the result of an addition or subtraction operation is being assigned to a bus of the same width as the operands of the addition or subtraction operation. In this code, the value of the operands is never large enough to cause overflow.
        r_tlp_sent_dw_len <= #TP s_tlp_sent_after_current_beat_dw_len;
// spyglass enable_block W164a
      end
    end
  end

// spyglass disable_block W164a
// SMD: Identifies assignments in which the LHS width is less than the RHS width
// SJ: The rule reports assignments where the result of an addition or subtraction operation is being assigned to a bus of the same width as the operands of the addition or subtraction operation. In this code, the value of the operands is never large enough to cause overflow.
assign s_tlp_remaining_dw_len = s_tlp_dw_len - s_tlp_sent_dw_len;

assign s_tlp_addr = s_pkt_msg_req || (s_pkt_fmt_type[6:0] inside {`CAS32, `CAS64}) ? s_pkt_addr : {s_pkt_addr[ADDR_WD_WO_PAR -1:2],2'b00} + {s_pkt_sent_dw_len,2'b00};
// spyglass enable_block W164a

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
  begin: IB_WR_STATE_COMB_PROC
    next_state = state;
    if (!dwnstrm_pkt_halt) begin

      next_state = state;

      case(state)
        S_READY :
            if (req_pkt_hv) begin
              if (s_decomposition_required)begin                                                         // if decomposition is required
                if(s_pkt_dw_to_next_max_transfer_unit <= NW)begin                                        //   and the number of DW to the decomposition boundary (master MTU) is less than the data bus width (meaning the first TLP is only 1 beat long)
                  if((s_pkt_dw_after_next_max_transfer_unit) <= s_cc_mstr_mtu_dw_len) begin              //     and the lenght of the second decomposed TLP is less than master MTU (meaning there are only 2 decomposed TLPs)
                    if((s_pkt_dw_after_next_max_transfer_unit) <= NW) begin
                      if(req_pkt_eot)
                        next_state = S_WR_DCMP_EXTRA_TLP_SINGLE_BEAT;
                      else
                        next_state = S_WR_DCMP_LAST_TLP_SINGLE_BEAT;
                    end else begin
                      next_state = S_WR_DCMP_LAST_TLP_FIRST_BEAT;                                        //       then the next beat is the first beat of the last TLP
                    end
                  end
                end else begin
                  if(s_tlp_after_current_beat_dw_len <= NW) begin
                    next_state = S_WR_DCMP_FIRST_TLP_LAST_BEAT;
                  end else begin
                    next_state = S_WR_DCMP_FIRST_TLP_INTMD_BEAT;
                  end
                end
              end else if (!req_pkt_eot) begin
                next_state = S_WR_NODCMP;
              end else begin
                next_state = S_READY;
              end
            end
        S_WR_NODCMP:
            if (req_pkt_eot) begin
              next_state = S_READY;
            end
        S_WR_DCMP_FIRST_TLP_INTMD_BEAT:
            if(req_pkt_dv) begin
              if(s_tlp_after_current_beat_dw_len <= NW) begin
                next_state = S_WR_DCMP_FIRST_TLP_LAST_BEAT;
              end
            end
        S_WR_DCMP_FIRST_TLP_LAST_BEAT:
            if(req_pkt_dv) begin
              if(s_pkt_dw_remaining_after_current_tlp <= s_cc_mstr_mtu_dw_len) begin
                if((s_pkt_dw_remaining_after_current_tlp) <= NW) begin
                  if(req_pkt_eot)
                    next_state = S_WR_DCMP_EXTRA_TLP_SINGLE_BEAT;
                  else
                    next_state = S_WR_DCMP_LAST_TLP_SINGLE_BEAT;
                end else begin
                  next_state = S_WR_DCMP_LAST_TLP_FIRST_BEAT;                                        //       then the next beat is the first beat of the last TLP
                end
              end
            end
        S_WR_DCMP_LAST_TLP_FIRST_BEAT:
            if(req_pkt_dv) begin
              if(s_tlp_after_current_beat_dw_len <= NW) begin
                if(req_pkt_eot)
                  next_state = S_WR_DCMP_LAST_TLP_EXTRA_BEAT;
                else
                  next_state = S_WR_DCMP_LAST_TLP_LAST_BEAT;
              end else begin
                next_state = S_WR_DCMP_LAST_TLP_INTMD_BEAT;
              end
            end
        S_WR_DCMP_LAST_TLP_INTMD_BEAT:
            if(req_pkt_dv) begin
              if(s_tlp_after_current_beat_dw_len <= NW) begin
                if(req_pkt_eot)
                  next_state = S_WR_DCMP_LAST_TLP_EXTRA_BEAT;
                else
                  next_state = S_WR_DCMP_LAST_TLP_LAST_BEAT;
              end
            end
        S_WR_DCMP_LAST_TLP_LAST_BEAT:
            if(req_pkt_dv) begin
              next_state = S_READY;
            end
        S_WR_DCMP_LAST_TLP_SINGLE_BEAT:
            if(req_pkt_dv) begin
              next_state = S_READY;
            end
        S_WR_DCMP_LAST_TLP_EXTRA_BEAT:
              next_state = S_READY;
        S_WR_DCMP_EXTRA_TLP_SINGLE_BEAT:
              next_state = S_READY;

      endcase
    end else begin
      next_state = state;
    end
  end


assign inq_pkt_np_tlp_issued = inq_pkt_hv && !dwnstrm_pkt_halt && s_pkt_np_req;

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
assign inq_pkt_halt = dwnstrm_pkt_halt
                     || (state == S_WR_DCMP_LAST_TLP_EXTRA_BEAT)
                     || (state == S_WR_DCMP_EXTRA_TLP_SINGLE_BEAT)
                     ;


// inq_pkt_hv
// ---------------------------------------------------------------------------------------------------------------------
assign inq_pkt_hv   = ( ( state == S_READY ) && req_pkt_hv ) ||
                      ( state == S_WR_DCMP_EXTRA_TLP_SINGLE_BEAT ) ||
                      ( (
                        ( state == S_WR_DCMP_LAST_TLP_FIRST_BEAT ) ||
                        ( state == S_WR_DCMP_LAST_TLP_SINGLE_BEAT )
                      ) && inq_pkt_dv ) ;


// inq_pkt_dv
// ---------------------------------------------------------------------------------------------------------------------
assign inq_pkt_dv = ( state == S_READY ) ? req_pkt_dv : req_pkt_dv
                                                        || ( state == S_WR_DCMP_LAST_TLP_EXTRA_BEAT )
                                                        || ( state == S_WR_DCMP_EXTRA_TLP_SINGLE_BEAT )
                                                        ;


// inq_pkt_eot
// ---------------------------------------------------------------------------------------------------------------------
assign inq_pkt_eot = ((( state == S_WR_DCMP_FIRST_TLP_LAST_BEAT    ) ||
                       ( state == S_WR_DCMP_LAST_TLP_EXTRA_BEAT    ) ||
                       ( state == S_WR_DCMP_EXTRA_TLP_SINGLE_BEAT  ) ||
                       ( state == S_WR_DCMP_LAST_TLP_LAST_BEAT     ) ||
                       ( state == S_WR_DCMP_LAST_TLP_SINGLE_BEAT   )
                       ) && inq_pkt_dv ) ||
                      (( state == S_READY ) && req_pkt_eot ) ||
                      (( state == S_READY ) && s_decomposition_required && ( s_pkt_dw_to_next_max_transfer_unit <= NW ) && req_pkt_hv ) ||
                      (( state != S_READY ) && req_pkt_eot
                      && ( next_state != S_WR_DCMP_LAST_TLP_EXTRA_BEAT )
                      );


// inq_pkt_byte_len
// ---------------------------------------------------------------------------------------------------------------------
assign inq_pkt_byte_len = (s_pkt_fmt_type[6:0] inside {`CAS32, `CAS64}) ? {s_tlp_dw_len[PKT_BYTE_LEN_OUT_WD-4:0],3'b000} : {s_tlp_dw_len,2'b00};
//assign inq_pkt_byte_len = {s_tlp_dw_len,2'b00};


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
assign inq_pkt_byte_en[3:0] = s_pkt_msg_req            ? s_pkt_byte_en[3:0] :
                              s_pkt_first_tlp          ? 
                             (s_pkt_fmt_type inside {
                               `FETCHADD32
                              ,`FETCHADD64
                              ,`SWAP32
                              ,`SWAP64
                              ,`CAS32
                              ,`CAS64
                             })                        ? 4'b1111            :
                                                         s_pkt_byte_en[3:0] :
                              s_decomposition_required ? 4'b1111            :
                              s_tlp_dw_len == 1        ? s_pkt_byte_en[7:4] :
                                                         4'b1111;

assign inq_pkt_byte_en[7:4] = s_pkt_msg_req            ? s_pkt_byte_en[7:4] :
                              s_decomposition_required ? 4'b1111            :
                             (s_pkt_fmt_type inside {
                               `CAS32
                              ,`CAS64
                             })                        ? 4'b1111            :
                              s_tlp_dw_len == 1        ? 4'b0000            :
                             (s_pkt_fmt_type inside {
                               `FETCHADD32
                              ,`FETCHADD64
                              ,`SWAP32
                              ,`SWAP64
                             })                        ? 4'b1111            :

                                                         s_pkt_byte_en[7:4];


// inq_pkt_last_tlp
// ---------------------------------------------------------------------------------------------------------------------
assign inq_pkt_last_tlp = s_pkt_last_tlp;


// inq_pkt_ncbe
// ---------------------------------------------------------------------------------------------------------------------
assign inq_pkt_ncbe = 0;


// inq_pkt_out_tag
// ---------------------------------------------------------------------------------------------------------------------
assign inq_pkt_out_tag      = ( (state == S_READY ) ? req_pkt_out_tag : r_req_pkt_out_tag ) ;


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

function automatic [NUM_DATA_PAR_BLOCKS-1:0] fn_prot_chkin_dt;
    input [PKT_DATA_WD -1:0] s_data_w_par;
    integer i;
    begin
      for (i=0; i<NUM_DATA_PAR_BLOCKS; i=i+1) begin
        fn_prot_chkin_dt[i] = s_data_w_par[i*CX_RAS_PROT_RANGE + i + CX_RAS_PROT_RANGE];
      end
    end
endfunction

function automatic [`PCIE_CORE_DATA_BUS_WD-1:0] fn_data_wo_par;
   input [PKT_DATA_WD -1:0] s_data_w_par;
   integer i;
   reg [NUM_DATA_PAR_BLOCKS-1:0][CX_RAS_PROT_RANGE:0]   i_data_w_par;
   reg [NUM_DATA_PAR_BLOCKS-1:0][CX_RAS_PROT_RANGE-1:0] i_data_wo_par;
   begin
     i_data_w_par = s_data_w_par;
     for (i=0; i<NUM_DATA_PAR_BLOCKS; i=i+1)  begin // interate thru parity block size
       i_data_wo_par[i] = i_data_w_par[i][CX_RAS_PROT_RANGE-1:0];
     end
     fn_data_wo_par = i_data_wo_par;
   end
 endfunction



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
                   (state == S_WR_NODCMP                     ) ? "WR_NODCMP" :
                   (state == S_WR_DCMP_FIRST_TLP_INTMD_BEAT  ) ? "WR_DCMP_FIRST_TLP_INTMD_BEAT" :
                   (state == S_WR_DCMP_FIRST_TLP_LAST_BEAT   ) ? "WR_DCMP_FIRST_TLP_LAST_BEAT"  :
                   (state == S_WR_DCMP_LAST_TLP_FIRST_BEAT   ) ? "WR_DCMP_LAST_TLP_FIRST_BEAT"  :
                   (state == S_WR_DCMP_LAST_TLP_INTMD_BEAT   ) ? "WR_DCMP_LAST_TLP_INTMD_BEAT"  :
                   (state == S_WR_DCMP_LAST_TLP_LAST_BEAT    ) ? "WR_DCMP_LAST_TLP_LAST_BEAT"   :
                   (state == S_WR_DCMP_LAST_TLP_SINGLE_BEAT  ) ? "WR_DCMP_LAST_TLP_SINGLE_BEAT"   :
                   (state == S_WR_DCMP_LAST_TLP_EXTRA_BEAT   ) ? "WR_DCMP_LAST_TLP_EXTRA_BEAT"  :
                   (state == S_WR_DCMP_EXTRA_TLP_SINGLE_BEAT ) ? "WR_DCMP_EXTRA_TLP_SINGLE_BEAT"  :
                                                                "";

`endif // SYNTHESIS

endmodule

