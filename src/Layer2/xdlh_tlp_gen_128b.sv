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
// ---    $Revision: #19 $ 
// ---    $Id: //dwh/pcie_iip/main/fairbanks/design/Layer2/xdlh_tlp_gen_128b.sv#19 $ 
// ------------------------------------------------------------------------- 
// --- Module Description: Transmit Data Link Layer TLP Generation 
//     DL Layer TLP is formed by adding sequence number and crc to each tlp 
//     that is requested from xtlh 
// --- This module handles 128b, 256b and 512b datapath widths. 
// ----------------------------------------------------------------------------- 


`include "include/DWC_pcie_ctl_all_defs.svh"
`include "products/cx_pl_pkg.svh"
`include "DWC_pcie_ctl_pkg.svh"
 
 module xdlh_tlp_gen_128b
 import cx_pl_pkg::P_NW;
 import cx_pl_pkg::P_NFM_NW;
 import cx_pl_pkg::NFM_DATA_PAR_WD;
 import cx_pl_pkg::NFM_DW_W_PAR;
 import DWC_pcie_ctl_pkg::ras_dp_err_log_t;
 import DWC_pcie_ctl_pkg::ras_dp_err_inj_t;
 ( 
    // -- inputs -- 
    core_clk, 
    core_rst_n, 
    cfg_corrupt_crc_pattern, 
    rdlh_link_up, 
    smlh_in_l0, 

    current_data_rate, 

    xdctrl_tlp_halt, 
    xmlh_skip_pending, 
    xdctrl_dllp_halt1, 
    rbuf_reply_req, 
    rbuf_xmt_dv, 
    rbuf_xmt_done, 
    rbuf_xmt_sot, 
    rbuf_xmt_eot, 
    rbuf_xmt_badeot, 

    cfg_rasdp_error_mode_en,
    cfg_rasdp_error_mode,
    xdlh_rasdp_error_mode,
    ras_dp_err_log,
    ras_dp_err_inj,
    rbuf_xmt_data, 
    rbuf_xmt_seqnum, 
    rbuf_entry_cnt, 
    rbuf_pkt_cnt, 
    rbuf_block_new_tlp, 

    xtlh_xdlh_data, 
    xtlh_xdlh_sot, 
    xtlh_xdlh_eot, 
    xtlh_xdlh_dv, 
    xtlh_xdlh_badeot, 

//`ifdef CX_TLP_PREFIX_ENABLE 
    xtlh_xdlh_tlp_len, 
    rbuf_xdlh_tlp_len, 
//`endif //   CX_TLP_PREFIX_ENABLE 
    lcrc_err_en, 

    dllp_xmt_pkt_130b, 

    dllp_xmt_pkt_10b, 
    dllp_xmt_req, 
    dllp_req_low_prior, 

    xtlh_sot_is_first, 
    xtlh_badeot, 
    xtlh_first_badeot, 
    xtlh_eot_sot, 
    xtlh_eot_sot_eot, 

    cdm_ras_des_einj0_enable,
    cdm_ras_des_einj0_count,
    cdm_ras_des_einj0_crc_type,
    cdm_ras_des_einj1_enable,
    cdm_ras_des_einj1_seq_type,
    cdm_ras_des_einj1_bad_seq,
    cdm_ras_des_einj1_count,
    cdm_ras_des_einj5_enable,
    cdm_ras_des_einj5_count,
    cdm_ras_des_einj5_tlp_type,

    lcrc_err_asserted, 
    xdlh_xtlh_halt, 
    rbuf_halt, 
    xdctrl_dllp_halt, 

    tlpgen_rbuf_data, 
    // tlpgen_rbuf_dwen, 
    tlpgen_rbuf_seqnum, 
    tlpgen_rbuf_dv, 
    tlpgen_rbuf_sot, 
    tlpgen_rbuf_eot, 
    tlpgen_rbuf_badeot, 
    tlpgen_reply_grant, 
    tlpgen_rbuf_len, 
    tlp_data, 
    tlp_dwen, 
    tlp_sot, 
    tlp_eot, 
    dllp_sdp, 
    tlp_dllp_dv,
    rbuf_replaying_out,

    tlpgen_pkt_pending, 
    xdlh_curnt_seqnum 
    ,
    xdlh_einj0_lcrc_evt,
    xdlh_einj0_fcrc_evt,
    xdlh_einj1_tx_tlp_snum_evt,
    xdlh_einj5_nultlp_evt
); 

// ============================================================================= 
// ----- parameters --------------- 
// ============================================================================= 

parameter INST    = 0;                    // The uniquifying parameter for each port logic instance. 
parameter NW    = (P_NW>16) ? P_NFM_NW : P_NW;   // Number of 32-bit dwords handled by the datapath each clock. This module supports 4, 8 and 16 
parameter DW      = (32*NW);              // Width of datapath in bits. 
parameter TP      = `TP;                  // Clock to Q delay (simulator insurance) 
parameter NW_MAX  = 16;                   // Max number of 32-bit dwords supported by this module. 

parameter DATA_PAR_WD   = NFM_DATA_PAR_WD;      // data bus parity width
parameter DW_W_PAR      = NFM_DW_W_PAR;  // Width of datapath in bits plus the parity bits.
parameter DW_WO_PAR   = (32*NW);              // Width of datapath without the parity bits.

// Encode to  1 hot to help in timing 
parameter ARB_IDLE                    = 5'b00001; 
parameter ARB_REPLY_GRNT              = 5'b00010; 
parameter ARB_RBUF_IN_XMT             = 5'b00100; 
// encoded such that the bit 3 indicates XTLH has the bus 
parameter ARB_XTLH_GRNT               = 5'b01000; 
parameter ARB_XTLH_IN_XMT             = 5'b11000; 
`define CHK_ARB_REPLY_GRNT state[1] 
`define CHK_ARB_XTLH_IN_XMT valid_state[4] 
`define CHK_HAS_BUS state[3] 

parameter RBUF_PW           = `RBUF_PW; 

parameter TX_NDLLP = `CX_TX_NDLLP; 

parameter FIFO_WIDTH  = (DW + 32 +32 + 12 +        // For data +2 crc + seqnum 
                        DATA_PAR_WD +              // for data protection code
                         11 +                      // For stp_tlp_len 
                         1 + 1 + NW + NW + NW + NW // For Control fields,
                         + 1                       // rbuf_replaying
                         );
parameter FIFO_ADDR_WIDTH = 1; 
parameter FIFO_DEPTH      = 2; 
parameter FIFO_AE_LEVEL   = 1'b1;   // Almost Empty level 
parameter FIFO_AF_LEVEL   = 1'b1;   // Almost Full level 

parameter DATAPATH_WIDTH    = (1 + 
                               11 + 
                               1 + 
                               DATA_PAR_WD +
                               DW + NW + NW + NW + 12
                               + 1 // rbuf_replaying
                               );

parameter RASDP_PIPE_DELAY = `CX_RASDP_XDLH_PIPE_EN  ;

parameter RASDP_PIPE_WIDTH = 1 + NW + NW + NW + 1 +1 + NW + NW + NW + DW + 
                               DATA_PAR_WD +
                               11 + 11 + 
                                16 + 12 +5 +12 + 5 + 1 + 1 + 1 ;

parameter NW_PRFX        = `CX_NPRFX; 
parameter TLP_PRFX_EN    = `CX_TLP_PREFIX_ENABLE_VALUE; 
parameter PRFX_ENTRIES   = (TLP_PRFX_EN==0)       ? 0 :     // no prefix
                           (NW==4)? (NW_PRFX > 4) ? 2 : 1 : // 128b
                                    (NW_PRFX > 4) ? 1 : 0 ; // 256b and 512b 

// The RBUF_DATASIZE is calculated based on CX_NW * 32 (1024) so for XDLH which is at 512 double the number of entries
parameter RBUF_DATASIZE   =  `CX_RBUF_DATASIZE ; // RBUF entries needed to hold a maximum size packet 

parameter SKIP_IDLE = 2'b00; 
parameter SKIP_2    = 2'b01; 

parameter MNW  = NW+5;  // number of dwords in the merged datapath, after insertion of one DLLP, one STP, two LCRCs, an 8 DWs input datapath can expand into 13 DWs 
parameter CW   = 5;   // control width, number of control bits {sdp, dwen, eot, sot} for one dword 

localparam TX_CRC_TLP = 2; // Number of TLPs that can be processed by the LCRC block in a single cycle

parameter CRC_LATENCY = `CX_CRC_LATENCY_XDLH; // default is 1, can be set to 2 for pipelining to ease timing 

parameter CAN_STALL = (CRC_LATENCY != 0); // always 

localparam CRC_LATENCY_M1 = CRC_LATENCY-1;  //adds a clk cycle delay if crc pipeline on; else 0 

parameter RAS_PROT_TYPE                        = `CX_RAS_PROT_TYPE;
parameter RAS_PROT_RANGE                       = `CX_RAS_PROT_RANGE;
parameter RAS_PROT_CORRECT_EN                  = `CX_RAS_CORRECTION_EN;
parameter RAS_PARITY_MODE                      = `CX_RAS_PARITY_MODE;
parameter RAS_ERROR_WD                         = 2;
parameter RAS_DP_PROT_CHK_ID_BASE_XDLH_TLP_GEN = 0;

// BCM64 transport delay parameters
localparam integer REG_DELAY_DENOM = 1000;
localparam integer REG_DELAY_TIME  = `TP * REG_DELAY_DENOM;

// ============================================================================= 
// ----- Inputs --------------- 
// ============================================================================= 
input                           core_clk; 
input                           core_rst_n; 
input   [31:0]                  cfg_corrupt_crc_pattern; 
input                           rdlh_link_up; 
input                           smlh_in_l0; 
input   [2:0]                   current_data_rate;   // 2'b00=running at gen1 speeds, 2'b01=running at gen2 speeds, 2'b10=running at gen3 speeds, 2'b11=running at gen4 speeds 
input                           xdctrl_tlp_halt; 
input                           xmlh_skip_pending; 
input                           xdctrl_dllp_halt1; 
input                           rbuf_reply_req;     // this signal is designed to block the tlp from transmitting while the retrybuffer is getting ready for reply. This is due to cycle delay of memory read 
input   [NW-1:0]                rbuf_xmt_sot; 
input                           rbuf_xmt_dv; 
input                           rbuf_xmt_done; 
input   [NW-1:0]                rbuf_xmt_eot; 
input   [NW-1:0]                rbuf_xmt_badeot;    // asserted when parity error is detected during replay 
input                           cfg_rasdp_error_mode_en;
input                           cfg_rasdp_error_mode;
output                          xdlh_rasdp_error_mode;
output ras_dp_err_log_t [1:0]   ras_dp_err_log;
input  ras_dp_err_inj_t         ras_dp_err_inj;
input   [11:0]                  rbuf_xmt_seqnum; 
input   [DW_W_PAR-1:0]          rbuf_xmt_data; 
input   [RBUF_PW :0]            rbuf_entry_cnt; 

input                           rbuf_block_new_tlp; 
input   [11:0]                  rbuf_pkt_cnt; 
input   [DW_W_PAR-1:0]          xtlh_xdlh_data; 
input   [NW-1:0]                xtlh_xdlh_sot; 
input   [NW-1:0]                xtlh_xdlh_eot; 
input                           xtlh_xdlh_dv; 
input   [NW-1:0]                xtlh_xdlh_badeot; 

input                           lcrc_err_en;        // For debug and diagnose feature, this signal enables LSB bit flip of ECRC field to a TLP that is in progress 

// `ifdef CX_TLP_PREFIX_ENABLE  
input   [10:0]                  xtlh_xdlh_tlp_len;  
input   [10:0]                  rbuf_xdlh_tlp_len; 
// `endif // CX_TLP_PREFIX_ENABLE 

input   [(64*TX_NDLLP)-1:0]     dllp_xmt_pkt_130b; 

input   [(64*TX_NDLLP)-1:0]     dllp_xmt_pkt_10b; 
input   [TX_NDLLP-1:0]          dllp_xmt_req; 
input                           dllp_req_low_prior; 

input                           xtlh_sot_is_first; 
input                           xtlh_eot_sot_eot; 
input                           xtlh_badeot; 
input                           xtlh_first_badeot; 
input                           xtlh_eot_sot; 

input                           cdm_ras_des_einj0_enable ;    // Error injection 0 enable
input   [7:0]                   cdm_ras_des_einj0_count ;     // Error injection 0 count
input   [3:0]                   cdm_ras_des_einj0_crc_type ;  // Error injection 0 CRC type
input                           cdm_ras_des_einj1_enable ;    // Error injection 1 enable
input                           cdm_ras_des_einj1_seq_type ;  // Error injection 1 seq# type
input   [12:0]                  cdm_ras_des_einj1_bad_seq ;   // Error injection 1 bad seq# value
input   [7:0]                   cdm_ras_des_einj1_count ;     // Error injection 1 count
input                           cdm_ras_des_einj5_enable ;    // Error injection 5 enable
input   [7:0]                   cdm_ras_des_einj5_count ;     // Error injection 5 count
input                           cdm_ras_des_einj5_tlp_type ;  // Error injection 5 tlp type (dup/nul)
output                          lcrc_err_asserted; // For debug and diagnose feature, this signal is a status to indicate that a TLP has been transmitted with ECRC error 
output                          xdlh_xtlh_halt; 
output                          rbuf_halt; 
output  [DW-1:0]                tlp_data; 
output  [NW-1:0]                tlp_dwen; 
output  [NW-1:0]                tlp_sot; 
output  [NW-1:0]                tlp_eot; 
output  [NW-1:0]                dllp_sdp; 
output                          tlp_dllp_dv;
output  reg                     rbuf_replaying_out;
output                          tlpgen_pkt_pending;      // TLP has been registered and is pending transmission 
// Below are interface to retrybuf block for the currnt tlp that is 
// transmitting. This interface is introduced for the purpose of saving 
// retrybuf size 
// the tlpgen data does not include crc and sequece number and the framing 
// information 
output  [DW_W_PAR-1:0]          tlpgen_rbuf_data; 
output                          tlpgen_rbuf_dv; 
output  [NW-1:0]                tlpgen_rbuf_sot; 
output  [NW-1:0]                tlpgen_rbuf_eot; 
output  [NW-1:0]                tlpgen_rbuf_badeot; 
output                          tlpgen_reply_grant; 
output  [11:0]                  tlpgen_rbuf_seqnum; 
output  [11:0]                  xdlh_curnt_seqnum; 

output  [10:0]                  tlpgen_rbuf_len; 

output                          xdctrl_dllp_halt;   // DLLP Halt is now generated here 
output  [1:0]                   xdlh_einj0_lcrc_evt;          // Error injection 0 LCRC event
output                          xdlh_einj0_fcrc_evt;          // Error injection 0 FCRC event
output  [1:0]                   xdlh_einj1_tx_tlp_snum_evt;   // Error injection 1 Seq# event
output                          xdlh_einj5_nultlp_evt;        // Error injection 5 nullified TLP event

// ============================================================================= 
// ----- Local parameter ----- 
// ============================================================================= 
localparam LMT_TXTLP = `CX_RAS_DES_LMT_TXTLP;
// ============================================================================= 
// ----- IO declaration ----- 
// ============================================================================= 
wire                            xdlh_xtlh_halt; 
wire                            rbuf_halt; 
wire   [DW-1:0]                 tlp_data; 
wire   [NW-1:0]                 tlp_dwen; 
reg    [NW-1:0]                 tlp_sot; 
reg    [NW-1:0]                 tlp_eot; 
reg    [NW-1:0]                 dllp_sdp; 

wire                            tlpgen_pkt_pending; 
wire    [DW_W_PAR-1:0]          tlpgen_rbuf_data; 
wire    [NW-1:0]                tlpgen_rbuf_sot; 
wire    [NW-1:0]                tlpgen_rbuf_eot; 
wire    [NW-1:0]                tlpgen_rbuf_badeot; 
wire                            tlpgen_rbuf_dv; 
wire    [11:0]                  tlpgen_rbuf_seqnum; 
wire    [11:0]                  xdlh_curnt_seqnum; 
wire                            tlpgen_reply_grant; 

// ============================================================================= 
// ----- internal signal declaration ---- 
// ============================================================================= 

reg     [4:0]                   state; 
reg     [4:0]                   next_state; 

reg     [11:0]                  xtlh_tlp_seqnum_0; 
wire    [11:0]                  xtlh_tlp_seqnum_org; 
wire    [11:0]                  xtlh_tlp_seqnum_0_d; 

wire                            valid_sot_is_first;
wire                            valid_eot_sot_eot;
wire                            valid_badeot;
wire                            valid_first_badeot;
wire                            valid_eot_sot;
wire    [4:0]                   valid_state;

wire    [10:0]                  valid_xtlh_xdlh_tlp_len;
wire    [10:0]                  stp_tlp_len;              // TLP Length for STP Token, valid when valid_xtlh_sot=1 
wire    [10:0]                  valid_stp_tlp_len;        // TLP Length for STP Token, valid when valid_xtlh_sot=1 
wire    [10:0]                  payload_len;              // Payload Length 
wire    [9:0]                   int_tlp_len;              // Internal TLP Header Payload Length 
wire    [1:0]                   int_tlp_fmt;              // Internal TLP Format 
wire                            int_tlp_td;               // Indicates presence of TLP Digest 
wire    [3:0]                   frame_crc;                // Frame CRC 
wire    [3:0]                   frame_crc_org;            // Frame CRC 
wire                            frame_parity;             // Frame Parity 
reg                             rbuf_block_tlp; 

wire    [NW-1:0]                int_badeot; 
wire    [NW-1:0]                int_badeot_org; 
wire                            xtlh_has_bus; 
wire                            xtlh_has_bus_d;
wire                            pipe_xtlh_has_bus; 
wire    [NW-1:0]                valid_xtlh_sot; 
wire    [NW-1:0]                valid_xtlh_eot; 
wire    [NW-1:0]                valid_rbuf_sot; 
wire    [NW-1:0]                valid_rbuf_eot; 
reg                             tlpgen_reply_grant1; 
reg                             tlpgen_reply_grant2; 

wire                            xdctrl_dllp_halt; 

wire    [15:0]                  crc_int_seqnum; 
wire    [11:0]                  int_seqnum; 
wire    [11:0]                  valid_seqnum;
wire    [15:0]                  crc_valid_seqnum; 

wire    [DW_W_PAR-1:0]          int_data;
wire    [DW_W_PAR-1:0]          int_data_chkd;
wire    [DW_W_PAR-1:0]          valid_data;
reg     [NW-1:0]                int_eot; 
reg     [NW-1:0]                int_sot; 
reg                             int_dv; 
wire                            valid_xtlh_dv;
wire                            int_valid_xtlh_dv;
wire                            valid_rbuf_dv;
wire                            crc_en; 
wire    [NW-1:0]                valid_xtlh_badeot; 
wire    [NW-1:0]                valid_rbuf_badeot; 
wire                            xtlh_eot_2; 
wire                            xtlh_eot_1; 
wire                            xtlh_badeot_1; 
wire                            xtlh_sot; 
wire                            xtlh_eot; 
wire                            rbuf_sot; 
wire                            rbuf_eot; 


wire                            block_new_tlp; 
wire                            block_new_tlp_d;

wire                            pipe_halt; 
reg                             pipe_halt_d; 

wire    [FIFO_WIDTH-1:0]        fifo_in_data; 
wire    [DW_W_PAR-1:0]          fifo_out_data; 
wire                            fifo_out_dv; 
wire    [NW-1:0]                fifo_out_sot; 
wire    [NW-1:0]                fifo_out_eot; 
wire    [NW-1:0]                fifo_out_badeot; 
wire    [11:0]                  fifo_out_seqnum; 
wire    [10:0]                  fifo_stp_tlp_len; 

wire    [31:0]                  fifo_out_crc0; 
wire    [31:0]                  fifo_out_crc1;
wire                            fifo_out_rbuf_replaying;

wire                            fifo_wr; 
wire                            fifo_rd; 
wire                            fifo_empty; 
wire                            fifo_almost_empty; 
wire                            fifo_full; 
wire                            fifo_half_full; 
wire                            fifo_almost_full; 
wire                            fifo_error; 

wire    [NW-1:0]                rasdp_badeot;
wire    [DW_W_PAR-1:0]          pipe_data;
wire    [DW_W_PAR-1:0]          pipe_data_prot;
wire    [NW-1:0]                pipe_sot; 
wire    [NW-1:0]                pipe_eot; 
wire                            pipe_dv; 
wire    [NW-1:0]                pipe_badeot; 
wire                            pipe_rbuf_replaying;

wire    [11:0]                  pipe_seqnum; 
wire    [10:0]                  pipe_stp_tlp_len; 

wire    [31:0]                  pipe_crc0; 
wire    [31:0]                  pipe_crc1; 

wire                            out_state; 

wire                            xtlh_eot_is_last; 
wire                            rbuf_eot_is_last; 
wire                            xtlh_sot_only; 
reg                             block_xtlh_dv; 
wire                            block_xtlh_dv_d;

reg                             rbuf_xmt_done_q; 
wire                            rbuf_xmt_done_ledge; 
wire                            rbuf_reply_req_int; 
wire                            rbuf_reply_req_int_d;

reg     [1:0]                   skip_cycle; 
reg     [1:0]                   next_skip_cycle; 

wire                            skip_cycle1; 
wire                            skip_cycle2; 

wire                            skip_halt; 
wire    [NW:0]                  pipe_tlp1_dwen; 
wire    [NW:0]                  pipe_tlp2_dwen; 
wire    [NW:0]                  pipe_tlp1_skip_dwen; 
wire    [NW:0]                  pipe_tlp2_skip_dwen; 

wire    [NW-1:0]                pipe_tlp_skip_dwen; 
wire    [NW-1:0]                fifo_out_tlp_dwen; 

reg                             latched_pipe_eot_halt; 
wire                            latched_pipe_eot_halt_w; 

wire                            output_skip_halt; 
reg                             pipe_dv_q; 
wire                            start_pipe_dv; 

reg                             latched_pipe_eot_last; 
reg                             latched_pipe_eot_halt_q; 
reg                             smlh_in_l0_q1; 
reg                             smlh_in_l0_q2; 
wire                            smlh_in_l0_f; 

wire                            fifo_out_skip; 
wire                            pipe_no_sot; 

wire    [11:0]                  xtlh_tlp_seqnum;
wire    [NW-1:0]                einj5_int_eot ;
wire    [NW-1:0]                int_good_eot ;
wire    [NW-1:0]                find_int_eot[0:3] ;

reg                             last_int_eot_sts;
reg                             einj0_lcrc_mask;

wire                            int_no_sot;
wire                            int_eot_is_last;
wire                            int_sot_2;
wire                            int_ignore_1st_eot;

wire                            int_eot_1;
wire                            int_eot_2;
wire    [1:0]                   einj0_lcrc_en;
wire                            einj0_fcrc_en;
wire                            einj0_lcrc_reg_en;
wire    [1:0]                   einj1_tx_tlp_seq_en;
wire                            einj1_tx_tlp_seq_sel;
wire    [1:0]                   einj1_tx_tlp_snum_evt;
wire                            einj5_nultlp_en;
wire                            einj5_ignore_eot;
wire                            int_cdm_ras_des_einj5_enable ;
wire    [1:0]                   einj0_lcrc_evt;
wire                            pipe_eot_2; 
wire                            pipe_eot_1; 
wire                            pipe_eot_is_last; 
// ----------------------------------------------- 

assign rbuf_reply_req_int = !rbuf_xmt_done_ledge & rbuf_reply_req; 

//add pipeline here, break timing loop on xdlh_rasdp_error mode for packet nullification when RASDP > 3 ( ECC )

delay_n_w_stalling
 
#(RASDP_PIPE_DELAY, RASDP_PIPE_WIDTH, 0) u1_delay (
    .clk        (core_clk),
    .rst_n      (core_rst_n),
    .stall      ( pipe_halt) ,
    .clear      (!rdlh_link_up),

    .din        ({ 
                   stp_tlp_len, xtlh_xdlh_tlp_len,
                   xtlh_xdlh_dv, xtlh_xdlh_sot,  xtlh_xdlh_eot, xtlh_xdlh_badeot, rbuf_xmt_dv, rbuf_xmt_sot, rbuf_xmt_eot, rbuf_xmt_badeot, block_new_tlp, int_data_chkd, int_seqnum, crc_int_seqnum, xtlh_sot_is_first, xtlh_eot_sot_eot, xtlh_badeot, xtlh_first_badeot, xtlh_eot_sot, xtlh_tlp_seqnum_0, state, xtlh_has_bus, block_xtlh_dv, rbuf_reply_req_int
}), 
    .stallout   (), 
    .dout       ({ 
                    valid_stp_tlp_len, valid_xtlh_xdlh_tlp_len,
                   valid_xtlh_dv, valid_xtlh_sot, valid_xtlh_eot, valid_xtlh_badeot, valid_rbuf_dv, valid_rbuf_sot, valid_rbuf_eot, valid_rbuf_badeot, block_new_tlp_d, valid_data, valid_seqnum, crc_valid_seqnum, valid_sot_is_first, valid_eot_sot_eot, valid_badeot, valid_first_badeot, valid_eot_sot, xtlh_tlp_seqnum_0_d, valid_state, xtlh_has_bus_d, block_xtlh_dv_d, rbuf_reply_req_int_d
  }) 
); 


//this is used on xdlh_xtlh_halt generation
assign xtlh_sot = |(xtlh_xdlh_sot[NW-1:0]); 


//these go to seqnum generation - seqnum is registered after it is generated, so inputs are not pipelined here
assign xtlh_badeot_1 = (^xtlh_xdlh_badeot[NW-1:0]) & (|xtlh_xdlh_badeot[NW-1:0]); 
assign xtlh_eot_2 = !(^xtlh_xdlh_eot[NW-1:0]) & (|xtlh_xdlh_eot[NW-1:0]);   // If 2 EOts, XOR is 0 and OR is 1 
assign xtlh_eot_1 =  (^xtlh_xdlh_eot[NW-1:0]) & (|xtlh_xdlh_eot[NW-1:0]);    // If 1 EOt, XOR is 1 and OR is 1 

// ----------------------------------------------- 


//these go to state machine
assign rbuf_sot = |(rbuf_xmt_sot[NW-1:0]); 
assign rbuf_eot = |(rbuf_xmt_eot[NW-1:0]); 
assign xtlh_eot = |(xtlh_xdlh_eot[NW-1:0]); 

assign xtlh_eot_is_last = xtlh_xdlh_eot > xtlh_xdlh_sot; 
assign rbuf_eot_is_last = (rbuf_xmt_eot > rbuf_xmt_sot)
                                                           | (rbuf_eot & cfg_rasdp_error_mode)
                                                          ;

assign xtlh_sot_only = (|xtlh_xdlh_sot) & !(|xtlh_xdlh_eot); 
// ----------------------------------------------- 

always @(posedge core_clk or negedge core_rst_n) 
    if (!core_rst_n) 
      rbuf_xmt_done_q  <= #TP 1'b0; 
    else 
      rbuf_xmt_done_q  <= #TP rbuf_xmt_done; 
// ----------------------------------------------- 

assign rbuf_xmt_done_ledge = !rbuf_xmt_done & rbuf_xmt_done_q; 
// ----------------------------------------------- 

always @(*) begin : state_proc 
    next_state   = state; 
    case (state) 
        ARB_IDLE: 
            if (rbuf_xmt_done_ledge | out_state ) 
                next_state   = ARB_IDLE; 
            else 
                if (rbuf_reply_req_int) 
                    next_state   = ARB_REPLY_GRNT; 
                else 
                    next_state   = ARB_XTLH_GRNT; 
        ARB_XTLH_GRNT: 
            // designed to have bus parked at XTLH. Only when reply 
            // requested, we will give the reply 
            if ((xtlh_sot_only | xtlh_eot_sot) & !block_new_tlp) // If TLP is one entry width, no need to go to XMT next_state 
                next_state   = ARB_XTLH_IN_XMT; 
            else if (rbuf_reply_req_int) 
                next_state   = ARB_IDLE; 
            else 
                next_state   = ARB_XTLH_GRNT; 
        ARB_XTLH_IN_XMT: 
            if (xtlh_eot_is_last & !rbuf_reply_req_int) 
                next_state   = ARB_XTLH_GRNT; 
            else if (xtlh_eot & rbuf_reply_req_int) 
                next_state   = ARB_IDLE; 
            else 
                next_state   = ARB_XTLH_IN_XMT; 
        ARB_REPLY_GRNT: 
            if (rbuf_xmt_done) 
                next_state   = ARB_IDLE; 
            else if (rbuf_sot & !rbuf_eot ) 
                next_state   = ARB_RBUF_IN_XMT; 
            else 
                next_state   = ARB_REPLY_GRNT; 
        ARB_RBUF_IN_XMT: 
            if (rbuf_eot_is_last) 
                next_state   = ARB_REPLY_GRNT; 
            else 
                next_state   = ARB_RBUF_IN_XMT; 
                
        // mapping ARB_IDLE to default next_state to facilitate code coverage
        default:
            if (!rbuf_reply_req_int)
                next_state       = ARB_XTLH_GRNT;
            else
                next_state       = ARB_IDLE;
    endcase 
end 

always @(posedge core_clk or negedge core_rst_n) begin
    if (!core_rst_n) 
        state           <= #TP ARB_IDLE; 
    else if (!pipe_halt) 
        state           <= #TP next_state; 
end

// ----------------------------------------------------------------------------- 
assign xtlh_has_bus = `CHK_HAS_BUS; // FSM States encoded to indicate if XTLH or Retry Buffer buffer has bus 
// ----------------------------------------------------------------------------- 

// since we check data up to the input of the CRC generation block we need to or the error mode indication from the registers
// with the last checker to make sure packets are nullified for last minute errors
wire int_cfg_rasdp_error_mode;
wire int_data_err_detect;
wire int_data_err_multpl;
logic ras_dp_err_inband_kbd_out;

reg err_pulse_gating;
assign xdlh_rasdp_error_mode = ras_dp_err_inband_kbd_out & ( xtlh_has_bus ? xtlh_xdlh_dv &!pipe_halt : rbuf_xmt_dv &!pipe_halt) & cfg_rasdp_error_mode_en;

assign int_cfg_rasdp_error_mode = cfg_rasdp_error_mode | xdlh_rasdp_error_mode;

// xmt tlp sequence number creation process 
always @(posedge core_clk or negedge core_rst_n) 
begin : xtlh_tlp_seqnum_proc 
    if (!core_rst_n) 
        xtlh_tlp_seqnum_0 <= #TP 0; 
    else if (!rdlh_link_up) 
        xtlh_tlp_seqnum_0 <= #TP 0; 
    else if ((xtlh_eot_1 & !(|xtlh_xdlh_badeot[NW-1:0]) & !xdlh_xtlh_halt & xtlh_xdlh_dv)
      )
    // seqnum can only increase when the TLH layer has not asking for 
    // nullify a TLP, in other words, to append BAD EOT and non invert 
    // CRC to the end. 
        xtlh_tlp_seqnum_0 <= #TP  xtlh_tlp_seqnum_0 + 12'h001; 
    else if ((xtlh_eot_2 & !(|xtlh_xdlh_badeot[NW-1:0]) & !xdlh_xtlh_halt & xtlh_xdlh_dv) 
      )
        //  Increase seqnum by two if two EOTs are in the entry no badeot 
        xtlh_tlp_seqnum_0 <= #TP  xtlh_tlp_seqnum_0 + 12'h002; 
    else if ((xtlh_eot_2 & xtlh_badeot_1 & !xdlh_xtlh_halt & xtlh_xdlh_dv) 
      )
        // Increase by 1 if 2 EOTs and only one badeot 
        xtlh_tlp_seqnum_0 <= #TP  xtlh_tlp_seqnum_0 + 12'h001; 
end 
// ----------------------------------------------- 


assign xtlh_tlp_seqnum_org = (xtlh_eot_sot & !xtlh_badeot | xtlh_eot_sot_eot & !xtlh_first_badeot) ? (xtlh_tlp_seqnum_0 + 1'b1) : xtlh_tlp_seqnum_0; 



// Create signal to remove dummy int_eot.
assign int_no_sot          = !(|int_sot); 
assign int_eot_is_last     = (int_sot < int_eot); 
assign int_sot_2           = !(^int_sot[NW-1:0]) & (|int_sot[NW-1:0]); // for 512b

// last_int_eot_sts indicates last int_eot
always @(posedge core_clk or negedge core_rst_n) begin
    if (!core_rst_n) begin
        last_int_eot_sts  <= #TP 1'b0; 
    end else begin 
        if (int_dv && !pipe_halt) begin
            if (int_eot_is_last) begin // 
                last_int_eot_sts  <= #TP 1'b1; 
            end else begin
                last_int_eot_sts  <= #TP 1'b0; 
            end
        end
    end 
end

assign int_ignore_1st_eot       = (int_no_sot | !int_eot_is_last | (!int_sot_2 & int_eot_2) ) & last_int_eot_sts; // 1st eot must be ignored. Please see the comment at the end of fhis file.
// Einj1 event control
assign int_eot_1                = |int_eot; // first TLP
assign int_eot_2                = |int_eot & ~(^int_eot); // second TLP
assign einj1_tx_tlp_seq_en[0]   = cdm_ras_des_einj1_enable && (cdm_ras_des_einj1_seq_type==1'b0);
assign einj1_tx_tlp_seq_en[1]   = cdm_ras_des_einj1_enable && (cdm_ras_des_einj1_seq_type==1'b0) & ((cdm_ras_des_einj1_count==8'd0)|(cdm_ras_des_einj1_count>=8'd2));

assign einj1_tx_tlp_seq_sel     = |einj1_tx_tlp_seq_en & ~(int_eot_2 & ~einj1_tx_tlp_seq_en[1]) ; // if there is a second TLP with enable[1]==0, there is no Seq# to insert errors.

// spyglass disable_block W164a
// SMD: Identifies assignments in which the LHS width is less than the RHS width
// SJ: This logic is designed to be modulo. Sequence counters are intended to
// wrap without preseveration of carry/borrow
assign xtlh_tlp_seqnum          = einj1_tx_tlp_seq_sel ? (xtlh_tlp_seqnum_org + cdm_ras_des_einj1_bad_seq[11:0]) : xtlh_tlp_seqnum_org;
// spyglass enable_block W164a
assign einj1_tx_tlp_snum_evt[0] = einj1_tx_tlp_seq_en[0] & int_eot_1 & int_dv & ~pipe_halt & !int_ignore_1st_eot;
assign einj1_tx_tlp_snum_evt[1] = einj1_tx_tlp_seq_en[1] & int_eot_2 & int_dv & ~pipe_halt;
assign xdlh_einj1_tx_tlp_snum_evt = event_countones (einj1_tx_tlp_snum_evt);

assign crc_int_seqnum = (~xtlh_has_bus ) ? {rbuf_xmt_seqnum[7:0], 4'b0, rbuf_xmt_seqnum[11:8]} 
                                                 : {xtlh_tlp_seqnum[7:0], 4'b0, xtlh_tlp_seqnum[11:8]}; 
assign int_seqnum = (~xtlh_has_bus ) ? rbuf_xmt_seqnum : xtlh_tlp_seqnum; 

assign int_data   = ~xtlh_has_bus ? rbuf_xmt_data     : xtlh_xdlh_data; 


logic [1:0] unused_stallout;
logic [1:0] unused_halt_out;
logic [1:0] unused_valid_out;
logic       unused_ras_dp_err_inband_kbd_out;

ras_dp_pipe
 #(
    .PIPELINE_TYPE           (6),
    .N_STAGES                (0),
    .CAN_STALL               (0),
    .BUS_PROTECT_GEN_EN      (0),
    .BUS_PROTECT_CHK_EN      (1),
    .PROT_TYPE               (RAS_PROT_TYPE),
    .PROT_RANGE              (RAS_PROT_RANGE),
    .PROT_WD                 (DATA_PAR_WD),
    .PARITY_MODE             (RAS_PARITY_MODE),
    .PROT_CORRECT_EN         (RAS_PROT_CORRECT_EN),
    .TOTAL_WIDTH             (DW_WO_PAR),
    .EXCLUDE_PROT_WIDTH      (0),
    .RAS_DP_PROT_CHK_ID_BASE (RAS_DP_PROT_CHK_ID_BASE_XDLH_TLP_GEN + 0)
) u_xdlh_pipe_data_protect (
    .clk                       (core_clk),
    .rst_n                     (core_rst_n),

    .din                       (pipe_data[DW_WO_PAR-1:0]),
    .din_prot                  (pipe_data[DW_W_PAR-1 : DW_WO_PAR]),

    .dout                      (pipe_data_prot[DW_WO_PAR-1:0]),
    .dout_prot                 (pipe_data_prot[DW_WO_PAR +: DATA_PAR_WD]),
    
    .en                        (1'b0),
    .bypass                    (1'b0),
    .stall                     (1'b0),
    .stallout                  (unused_stallout[0]),
    
    .valid_in                  (pipe_dv),
    .halt_out                  (unused_halt_out[0]),
    
    .valid_out                 (unused_valid_out[0]),
    .halt_in                   (1'b0),
    .ras_dp_err_inband_kbd_in  (1'b0),
    .ras_dp_err_inband_kbd_out (unused_ras_dp_err_inband_kbd_out),
    .ras_dp_err_log            (ras_dp_err_log[0])
    ,
    .ras_dp_err_inj            (ras_dp_err_inj)
);

logic int_data_chk_valid;
assign int_data_chk_valid = (xtlh_has_bus ? xtlh_xdlh_dv : rbuf_xmt_dv) && (!pipe_halt);
ras_dp_pipe
 #(
    .PIPELINE_TYPE           (6),
    .N_STAGES                (0),
    .CAN_STALL               (0),
    .BUS_PROTECT_GEN_EN      (0),
    .BUS_PROTECT_CHK_EN      (1),
    .PROT_TYPE               (RAS_PROT_TYPE),
    .PROT_RANGE              (RAS_PROT_RANGE),
    .PROT_WD                 (DATA_PAR_WD),
    .PARITY_MODE             (RAS_PARITY_MODE),
    .PROT_CORRECT_EN         (RAS_PROT_CORRECT_EN),
    .TOTAL_WIDTH             (DW),
    .EXCLUDE_PROT_WIDTH      (0),
    .RAS_DP_PROT_CHK_ID_BASE (RAS_DP_PROT_CHK_ID_BASE_XDLH_TLP_GEN + 1)
) u1_int_data_chk (
    .clk                       (core_clk),
    .rst_n                     (core_rst_n),

    .din                       (int_data[0 +: DW]),
    .din_prot                  (int_data[DW +: DATA_PAR_WD]),

    .dout                      (int_data_chkd[0 +: DW]),
    .dout_prot                 (int_data_chkd[DW +: DATA_PAR_WD]),
    
    .en                        (1'b0),
    .bypass                    (1'b0),
    .stall                     (1'b0),
    .stallout                  (unused_stallout[1]),
    
    .valid_in                  (int_data_chk_valid),
    .halt_out                  (unused_halt_out[1]),
    
    .valid_out                 (unused_valid_out[1]),
    .halt_in                   (1'b0),
    .ras_dp_err_inband_kbd_in  (1'b0),
    .ras_dp_err_inband_kbd_out (ras_dp_err_inband_kbd_out),
    .ras_dp_err_log            (ras_dp_err_log[1])
    ,
    .ras_dp_err_inj            (ras_dp_err_inj)
);



// ----------------------------------------------- 

reg  [NW_MAX-1:0] second_xtlh_eot_tmp; 
wire [NW-1:0]     second_xtlh_eot; 

wire [NW_MAX-1:0] valid_xtlh_eot_tmp; 
assign valid_xtlh_eot_tmp = { {NW_MAX-NW{1'b0}}, valid_xtlh_eot}; 

always @(valid_xtlh_eot_tmp) 
   begin 

    second_xtlh_eot_tmp = 16'b1111_1111_1111_1111; 

       case(valid_xtlh_eot_tmp) 
           16'b0000_0000_0000_1001:      second_xtlh_eot_tmp = 16'b1111_1111_1111_0111; 
           16'b0000_0000_0001_0001:      second_xtlh_eot_tmp = 16'b1111_1111_1110_1111; 
           16'b0000_0000_0010_0001:      second_xtlh_eot_tmp = 16'b1111_1111_1101_1111; 
           16'b0000_0000_0100_0001:      second_xtlh_eot_tmp = 16'b1111_1111_1011_1111; 
           16'b0000_0000_1000_0001:      second_xtlh_eot_tmp = 16'b1111_1111_0111_1111; 
           16'b0000_0001_0000_0001:      second_xtlh_eot_tmp = 16'b1111_1110_1111_1111; 
           16'b0000_0010_0000_0001:      second_xtlh_eot_tmp = 16'b1111_1101_1111_1111; 
           16'b0000_0100_0000_0001:      second_xtlh_eot_tmp = 16'b1111_1011_1111_1111; 
           16'b0000_1000_0000_0001:      second_xtlh_eot_tmp = 16'b1111_0111_1111_1111; 
           16'b0001_0000_0000_0001:      second_xtlh_eot_tmp = 16'b1110_1111_1111_1111; 
           16'b0010_0000_0000_0001:      second_xtlh_eot_tmp = 16'b1101_1111_1111_1111; 
           16'b0100_0000_0000_0001:      second_xtlh_eot_tmp = 16'b1011_1111_1111_1111; 
           16'b1000_0000_0000_0001:      second_xtlh_eot_tmp = 16'b0111_1111_1111_1111; 

           16'b0000_0000_0001_0010:      second_xtlh_eot_tmp = 16'b1111_1111_1110_1111; 
           16'b0000_0000_0010_0010:      second_xtlh_eot_tmp = 16'b1111_1111_1101_1111; 
           16'b0000_0000_0100_0010:      second_xtlh_eot_tmp = 16'b1111_1111_1011_1111; 
           16'b0000_0000_1000_0010:      second_xtlh_eot_tmp = 16'b1111_1111_0111_1111; 
           16'b0000_0001_0000_0010:      second_xtlh_eot_tmp = 16'b1111_1110_1111_1111; 
           16'b0000_0010_0000_0010:      second_xtlh_eot_tmp = 16'b1111_1101_1111_1111; 
           16'b0000_0100_0000_0010:      second_xtlh_eot_tmp = 16'b1111_1011_1111_1111; 
           16'b0000_1000_0000_0010:      second_xtlh_eot_tmp = 16'b1111_0111_1111_1111; 
           16'b0001_0000_0000_0010:      second_xtlh_eot_tmp = 16'b1110_1111_1111_1111; 
           16'b0010_0000_0000_0010:      second_xtlh_eot_tmp = 16'b1101_1111_1111_1111; 
           16'b0100_0000_0000_0010:      second_xtlh_eot_tmp = 16'b1011_1111_1111_1111; 
           16'b1000_0000_0000_0010:      second_xtlh_eot_tmp = 16'b0111_1111_1111_1111; 

           16'b0000_0000_0010_0100:      second_xtlh_eot_tmp = 16'b1111_1111_1101_1111; 
           16'b0000_0000_0100_0100:      second_xtlh_eot_tmp = 16'b1111_1111_1011_1111; 
           16'b0000_0000_1000_0100:      second_xtlh_eot_tmp = 16'b1111_1111_0111_1111; 
           16'b0000_0001_0000_0100:      second_xtlh_eot_tmp = 16'b1111_1110_1111_1111; 
           16'b0000_0010_0000_0100:      second_xtlh_eot_tmp = 16'b1111_1101_1111_1111; 
           16'b0000_0100_0000_0100:      second_xtlh_eot_tmp = 16'b1111_1011_1111_1111; 
           16'b0000_1000_0000_0100:      second_xtlh_eot_tmp = 16'b1111_0111_1111_1111; 
           16'b0001_0000_0000_0100:      second_xtlh_eot_tmp = 16'b1110_1111_1111_1111; 
           16'b0010_0000_0000_0100:      second_xtlh_eot_tmp = 16'b1101_1111_1111_1111; 
           16'b0100_0000_0000_0100:      second_xtlh_eot_tmp = 16'b1011_1111_1111_1111; 
           16'b1000_0000_0000_0100:      second_xtlh_eot_tmp = 16'b0111_1111_1111_1111; 

           16'b0000_0000_0100_1000:      second_xtlh_eot_tmp = 16'b1111_1111_1011_1111; 
           16'b0000_0000_1000_1000:      second_xtlh_eot_tmp = 16'b1111_1111_0111_1111; 
           16'b0000_0001_0000_1000:      second_xtlh_eot_tmp = 16'b1111_1110_1111_1111; 
           16'b0000_0010_0000_1000:      second_xtlh_eot_tmp = 16'b1111_1101_1111_1111; 
           16'b0000_0100_0000_1000:      second_xtlh_eot_tmp = 16'b1111_1011_1111_1111; 
           16'b0000_1000_0000_1000:      second_xtlh_eot_tmp = 16'b1111_0111_1111_1111; 
           16'b0001_0000_0000_1000:      second_xtlh_eot_tmp = 16'b1110_1111_1111_1111; 
           16'b0010_0000_0000_1000:      second_xtlh_eot_tmp = 16'b1101_1111_1111_1111; 
           16'b0100_0000_0000_1000:      second_xtlh_eot_tmp = 16'b1011_1111_1111_1111; 
           16'b1000_0000_0000_1000:      second_xtlh_eot_tmp = 16'b0111_1111_1111_1111; 

           16'b0000_0000_1001_0000:      second_xtlh_eot_tmp = 16'b1111_1111_0111_1111; 
           16'b0000_0001_0001_0000:      second_xtlh_eot_tmp = 16'b1111_1110_1111_1111; 
           16'b0000_0010_0001_0000:      second_xtlh_eot_tmp = 16'b1111_1101_1111_1111; 
           16'b0000_0100_0001_0000:      second_xtlh_eot_tmp = 16'b1111_1011_1111_1111; 
           16'b0000_1000_0001_0000:      second_xtlh_eot_tmp = 16'b1111_0111_1111_1111; 
           16'b0001_0000_0001_0000:      second_xtlh_eot_tmp = 16'b1110_1111_1111_1111; 
           16'b0010_0000_0001_0000:      second_xtlh_eot_tmp = 16'b1101_1111_1111_1111; 
           16'b0100_0000_0001_0000:      second_xtlh_eot_tmp = 16'b1011_1111_1111_1111; 
           16'b1000_0000_0001_0000:      second_xtlh_eot_tmp = 16'b0111_1111_1111_1111; 

           16'b0000_0001_0010_0000:      second_xtlh_eot_tmp = 16'b1111_1110_1111_1111; 
           16'b0000_0010_0010_0000:      second_xtlh_eot_tmp = 16'b1111_1101_1111_1111; 
           16'b0000_0100_0010_0000:      second_xtlh_eot_tmp = 16'b1111_1011_1111_1111; 
           16'b0000_1000_0010_0000:      second_xtlh_eot_tmp = 16'b1111_0111_1111_1111; 
           16'b0001_0000_0010_0000:      second_xtlh_eot_tmp = 16'b1110_1111_1111_1111; 
           16'b0010_0000_0010_0000:      second_xtlh_eot_tmp = 16'b1101_1111_1111_1111; 
           16'b0100_0000_0010_0000:      second_xtlh_eot_tmp = 16'b1011_1111_1111_1111; 
           16'b1000_0000_0010_0000:      second_xtlh_eot_tmp = 16'b0111_1111_1111_1111; 

           16'b0000_0010_0100_0000:      second_xtlh_eot_tmp = 16'b1111_1101_1111_1111; 
           16'b0000_0100_0100_0000:      second_xtlh_eot_tmp = 16'b1111_1011_1111_1111; 
           16'b0000_1000_0100_0000:      second_xtlh_eot_tmp = 16'b1111_0111_1111_1111; 
           16'b0001_0000_0100_0000:      second_xtlh_eot_tmp = 16'b1110_1111_1111_1111; 
           16'b0010_0000_0100_0000:      second_xtlh_eot_tmp = 16'b1101_1111_1111_1111; 
           16'b0100_0000_0100_0000:      second_xtlh_eot_tmp = 16'b1011_1111_1111_1111; 
           16'b1000_0000_0100_0000:      second_xtlh_eot_tmp = 16'b0111_1111_1111_1111; 

           16'b0000_0100_1000_0000:      second_xtlh_eot_tmp = 16'b1111_1011_1111_1111; 
           16'b0000_1000_1000_0000:      second_xtlh_eot_tmp = 16'b1111_0111_1111_1111; 
           16'b0001_0000_1000_0000:      second_xtlh_eot_tmp = 16'b1110_1111_1111_1111; 
           16'b0010_0000_1000_0000:      second_xtlh_eot_tmp = 16'b1101_1111_1111_1111; 
           16'b0100_0000_1000_0000:      second_xtlh_eot_tmp = 16'b1011_1111_1111_1111; 
           16'b1000_0000_1000_0000:      second_xtlh_eot_tmp = 16'b0111_1111_1111_1111; 

           16'b0000_1001_0000_0000:      second_xtlh_eot_tmp = 16'b1111_0111_1111_1111; 
           16'b0001_0001_0000_0000:      second_xtlh_eot_tmp = 16'b1110_1111_1111_1111; 
           16'b0010_0001_0000_0000:      second_xtlh_eot_tmp = 16'b1101_1111_1111_1111; 
           16'b0100_0001_0000_0000:      second_xtlh_eot_tmp = 16'b1011_1111_1111_1111; 
           16'b1000_0001_0000_0000:      second_xtlh_eot_tmp = 16'b0111_1111_1111_1111; 

           16'b0001_0010_0000_0000:      second_xtlh_eot_tmp = 16'b1110_1111_1111_1111; 
           16'b0010_0010_0000_0000:      second_xtlh_eot_tmp = 16'b1101_1111_1111_1111; 
           16'b0100_0010_0000_0000:      second_xtlh_eot_tmp = 16'b1011_1111_1111_1111; 
           16'b1000_0010_0000_0000:      second_xtlh_eot_tmp = 16'b0111_1111_1111_1111; 

           16'b0010_0100_0000_0000:      second_xtlh_eot_tmp = 16'b1101_1111_1111_1111; 
           16'b0100_0100_0000_0000:      second_xtlh_eot_tmp = 16'b1011_1111_1111_1111; 
           16'b1000_0100_0000_0000:      second_xtlh_eot_tmp = 16'b0111_1111_1111_1111; 

           16'b0100_1000_0000_0000:      second_xtlh_eot_tmp = 16'b1011_1111_1111_1111; 
           16'b1000_1000_0000_0000:      second_xtlh_eot_tmp = 16'b0111_1111_1111_1111; 

           16'b1001_0000_0000_0000:      second_xtlh_eot_tmp = 16'b0111_1111_1111_1111; 

                           default:      second_xtlh_eot_tmp = 16'b1111_1111_1111_1111; 
     endcase 
   end 

assign second_xtlh_eot = second_xtlh_eot_tmp[NW-1:0]; 

// ----------------------------------------------- 
assign rbuf_replaying = !xtlh_has_bus_d ;

always @(*) 
 begin : PROC_INT_GEN 
    int_sot = valid_xtlh_sot; 
    int_eot = valid_xtlh_eot; 
    int_dv = valid_xtlh_dv; 

    if (!xtlh_has_bus_d) 
        int_eot = valid_rbuf_eot; 
    else 
        if (valid_eot_sot_eot & block_new_tlp_d) 
            int_eot = valid_xtlh_eot & second_xtlh_eot; 
    if (!xtlh_has_bus_d) begin 
        int_sot = valid_rbuf_sot; 
        int_dv = valid_rbuf_dv; 
    end 
    else begin 
        if (rbuf_reply_req_int_d & (`CHK_ARB_XTLH_IN_XMT) & valid_eot_sot) begin 
            int_sot = {NW{1'b0}}; 
        end 
        if (block_new_tlp_d) 
            int_sot = {NW{1'b0}}; 
        if (block_xtlh_dv_d & rdlh_link_up) 
            int_dv = 1'b0; 
        if (block_new_tlp_d & valid_sot_is_first & rdlh_link_up) 
            int_dv = 1'b0; 
    end 
end 
// ----------------------------------------------- 
always @(posedge core_clk or negedge core_rst_n) 
    begin 
      if (!core_rst_n) 
      begin
        block_xtlh_dv <= #TP 1'b0; 
      end
      else 
        begin 
          if ((xtlh_eot_sot | xtlh_eot_sot_eot) & block_new_tlp & !pipe_halt) 
            block_xtlh_dv   <= #TP 1'b1; 
          else if (!block_new_tlp & !out_state ) 
            block_xtlh_dv <= #TP 1'b0; 
        end 
    end 
// ----------------------------------------------- 

assign int_badeot_org = ~xtlh_has_bus_d ? valid_rbuf_badeot : valid_xtlh_badeot; 

generate
  if ( (LMT_TXTLP==1) && (DW*4>128) ) begin : gen_einj_en
      assign int_cdm_ras_des_einj5_enable = 1'b0 ;
  end else begin : gen_einj5_en
      assign int_cdm_ras_des_einj5_enable = cdm_ras_des_einj5_enable ;
  end
endgenerate

function automatic [NW-1:0] next_end_finder ;
  input  [3:0]        num ;
  input  [NW-1:0]     cur_pkt ;
  reg    [NW-1:0]     int_next_end_finder ;
  reg    [3:0]        find_cnt ;
  integer             find_loop ;
  begin
    find_cnt = 4'd0 ;
    int_next_end_finder = {NW{1'b0}} ;

    for (find_loop=0 ; find_loop<NW ; find_loop=find_loop+1 ) begin
        if ( cur_pkt[find_loop]==1'b1 ) begin
            find_cnt = find_cnt + 4'd1 ;
            if ( find_cnt==num ) begin
                int_next_end_finder = 1'b1<<find_loop ;
            end
        end
    end
    
    next_end_finder = int_next_end_finder ;
  end
endfunction

assign find_int_eot[0] = next_end_finder ( 4'd1, int_good_eot ) ; // 1st END location
assign find_int_eot[1] = {NW{1'b0}} ; // 2nd
assign find_int_eot[2] = {NW{1'b0}} ; // 3rd
assign find_int_eot[3] = {NW{1'b0}} ; // 4th

assign einj5_int_eot = find_int_eot[0] ;

// DWC core doesn't support to send multiple nullified TLPs at one cycle.
assign einj5_ignore_eot      = (int_eot<int_sot) | (~(^int_eot) & |int_eot) ; // condition of multiple tlps in 1 cycle
assign einj5_nultlp_en       = int_cdm_ras_des_einj5_enable & cdm_ras_des_einj5_tlp_type & xtlh_has_bus_d & ~einj5_ignore_eot ;
assign xdlh_einj5_nultlp_evt = einj5_nultlp_en & |int_good_eot & int_dv & ~pipe_halt ; 
assign int_good_eot          = int_eot & ~int_badeot_org ;
assign int_badeot            = einj5_nultlp_en ? (einj5_int_eot | int_badeot_org) : int_badeot_org ;



assign xdlh_xtlh_halt = latched_pipe_eot_halt_w | skip_halt | block_xtlh_dv | fifo_full & xtlh_has_bus  | ~xtlh_has_bus | 
                        (xtlh_sot & block_new_tlp) & rdlh_link_up | xtlh_eot_sot & rbuf_reply_req_int; 

// nullify TLPs up to the point where CRC is calculated                        
wire          filt_int_dv;
wire [NW-1:0] filt_int_sot;
wire [NW-1:0] filt_int_eot;
wire [NW-1:0] filt_int_badeot; 

// Nullify and filter TLPs which were already deep in the pipe when the core
// entered RASDP error mode. 
wire          eot_detected;
wire          rasdp_filter_active;
reg           stop_data_flow_r;

function automatic [NW-1:0] filt_dups;
input [NW-1:0] data;
reg [NW-1:0] new_data;
begin
  int j;
  int first_found;
  first_found = 0;
  new_data    = 0;  
  for (j=0; j<NW; j=j+1)
  begin
    if (first_found == 0)
    begin
      new_data[j] = data[j];
      if (data[j] == 1)
        first_found = 1;
      else
        first_found = 0;
    end
    else
      new_data[j] = 0;
  end
  filt_dups = new_data;
end
endfunction 

function automatic [NW-1:0] filt_sot_after_eot;
input [NW-1:0] eot;
input [NW-1:0] sot;
reg [NW-1:0] new_data;
begin
  int j;
  int eot_found;
  eot_found = 0;
  new_data  = 0;  
  for (j=0; j<NW; j=j+1)
  begin
    if (eot_found == 0)
    begin
      new_data[j] = sot[j];
      if (eot[j] == 1)
        eot_found = 1;
      else
        eot_found = 0;
    end
    else
      new_data[j] = 0;
  end
  filt_sot_after_eot = new_data;
end
endfunction 

always @(posedge core_clk or negedge core_rst_n) 
  begin: stop_data_flow_r_PROC
    if (!core_rst_n)
      stop_data_flow_r <= #TP 1'd0;
    else if (rasdp_filter_active && !pipe_halt || int_cfg_rasdp_error_mode && !int_dv)
      stop_data_flow_r <= #TP 1'b1;
    else if (!cfg_rasdp_error_mode)
      stop_data_flow_r <= #TP 1'd0;
  end

// detect when we have already transmitted the start of the packet. This
// happens if there is no sot prior to an eot and we have an eot => the start
// of the packet has been transmitted, we started so we must finish. Wait
// until xdlh_xtlh_halt_d before supressing the interface
wire sot_transmitted;
assign sot_transmitted = int_dv && |int_eot && !(|filt_sot_after_eot(int_eot, int_sot));

reg rasdp_filter_active_r;
// Once the filter is active it remains active until there is an unhalted
// cycle rasdp_filter_active_r keeps it set. As soon as stop_data_flow_r is
// set rasdm_filter_active is cleared.
assign rasdp_filter_active  = (int_cfg_rasdp_error_mode && (eot_detected || sot_transmitted && !pipe_halt_d) || rasdp_filter_active_r) && !stop_data_flow_r;

// Once we begin to filter we must continue to do so until the
// stop_data_flow_r has kicked in to clear the interface. We can only clear
// the interface when it is not halted so we need to keep the filter active as
// long as we are halted.
always @(posedge core_clk or negedge core_rst_n) 
  begin: rasdp_filter_active_r_PROC
    if (!core_rst_n)
      rasdp_filter_active_r <= #TP 1'd0;
    else if (rasdp_filter_active)
      rasdp_filter_active_r <= #TP 1'b1;
    else if (!pipe_halt)
      rasdp_filter_active_r <= #TP 1'd0;
  end

// detect the EOT, used to trigger gating of transmit on entry to RASDP mode
// gate immediately if no data valid
// Gate if there is a new eot(use delayed halt to figure out if data is fresh)
assign eot_detected         = |int_eot & !sot_transmitted;

// make sure EOT is transformed in a bad eot if RASDP error mode is asserted
assign rasdp_badeot = int_eot & {NW{rasdp_filter_active}};

// make sure only 1 EOT / BADEOT pair moves on to comply with assumptions in the following blocks
assign filt_int_badeot      = stop_data_flow_r ? 0 : (rasdp_filter_active? filt_dups(rasdp_badeot): int_badeot);
assign filt_int_dv          = int_dv & (!stop_data_flow_r);
assign filt_int_sot         = stop_data_flow_r ? 0 : (rasdp_filter_active? filt_sot_after_eot(int_eot, int_sot): int_sot);
assign filt_int_eot         = stop_data_flow_r ? 0 : (rasdp_filter_active? filt_dups(int_eot): int_eot);



assign stp_tlp_len[10:0] = ~xtlh_has_bus ? rbuf_xdlh_tlp_len : xtlh_xdlh_tlp_len;


assign tlpgen_rbuf_len = valid_xtlh_xdlh_tlp_len;


assign crc_en = !pipe_halt; 

wire [NW-1:0] sot_to_crc; 
assign sot_to_crc  = int_sot; // Always start on first word 
wire [NW-1:0] eot_to_crc; 
assign eot_to_crc = int_eot; 

wire [TX_CRC_TLP*32-1:0] crc_result;


// ----------------------------------------------- 
lcrc
 #(.NW(NW), .NOUT(TX_CRC_TLP), .CRC_MODE(`CX_XDLH), .OPTIMIZE_FOR_1SOT_1EOT(0), .CRC_LATENCY(`CX_CRC_LATENCY_XDLH)) u_lcrc ( 

    // inputs 
    .clk                (core_clk), 
    .rst_n              (core_rst_n), 
    .enable_in          (crc_en), 
    .data_in            (valid_data[DW-1:0]), 
    .sot_in             (sot_to_crc), 
    .eot_in             (eot_to_crc), 
    .seqnum_in_0        (crc_valid_seqnum), 
    .seqnum_in_1        (16'h0), // only needed in 256b when capability to start more than one tlp on the clock cycle is added 
    // outputs 
    .crc_out          (crc_result),
    .crc_out_valid    (),
    .crc_out_match    (),  // unused when generating
    .crc_out_match_inv()  // unused when generating
); 
// -----------------------------------------------

reg [31:0] latched_crc0_result;   // latch the crc value when it is a halt start 
reg [31:0] latched_crc1_result;   // latch the crc value when it is a halt start 

always @(posedge core_clk or negedge core_rst_n) 
    if (!core_rst_n) 
        pipe_halt_d  <= #TP 0; 
    else 
        pipe_halt_d  <= #TP pipe_halt; 
// ----------------------------------------------- 

always @(posedge core_clk or negedge core_rst_n) 
    if (!core_rst_n) 
      begin 
        latched_crc0_result  <= #TP 0; 
        latched_crc1_result  <= #TP 0; 
      end 

    else if ((pipe_halt && !pipe_halt_d)  || ((CRC_LATENCY_M1==1) ? (!pipe_halt && pipe_halt_d) : 1'b0)) //updated for both crc pipeline on and off 
      begin 
        latched_crc0_result  <= #TP crc_result[31:0]; 
        latched_crc1_result  <= #TP crc_result[63:32]; 
      end 
// ----------------------------------------------- 
wire [31:0] int_crc0_result; 
wire [31:0] int_crc1_result; 

// Debug control capability added in 
wire [31:0] crc_result0_i; 
wire [31:0] crc_result1_i; 

wire        lcrc_err_asserted; 
wire        int_lcrc_err_en_mask; 
wire        int_lcrc_err_en; 
reg         int_lcrc_err_en_d; 
reg  [1:0]  lcrc_err_insert_state; 
reg  [1:0]  next_lcrc_err_insert_state; 
wire [1:0]  lcrc_err_insert; 
wire        pipe_sot_2; // for 512b
wire        pipe_ignore_1st_eot;
reg         last_pipe_eot_sts;

// LCRC error insertion must be started at the cycle doesn't have LCRC.
assign int_lcrc_err_en_mask = |pipe_eot;
assign int_lcrc_err_en = lcrc_err_en & !int_lcrc_err_en_mask;

always @(posedge core_clk or negedge core_rst_n) 
    if (!core_rst_n) begin 
        int_lcrc_err_en_d <= #TP 0; 
    end else begin 
        int_lcrc_err_en_d <= #TP int_lcrc_err_en; 
    end 
// ----------------------------------------------- 

always @(*) begin
    next_lcrc_err_insert_state = lcrc_err_insert_state;
    case ( lcrc_err_insert_state )
        2'b00 : begin // Idle
            if (int_lcrc_err_en & !int_lcrc_err_en_d) begin // rising edge of ecrc_err_en signal
                next_lcrc_err_insert_state = 2'b01;
            end
        end
        2'b01 : begin // Waiting for the target TLP
            if (lcrc_err_asserted) begin
                next_lcrc_err_insert_state = 2'b10;
            end
        end
        2'b10 : begin // Waiting for the negedge of lcrc_err_en to finish error insertion
            if (!lcrc_err_en) begin
                next_lcrc_err_insert_state = 2'b00;
            end
        end
        default : begin // Redundant
            next_lcrc_err_insert_state = 2'b00;
        end
    endcase
end

always @(posedge core_clk or negedge core_rst_n)
    if (!core_rst_n) begin
        lcrc_err_insert_state <= #TP 2'b00;
    end else begin
        lcrc_err_insert_state <= #TP next_lcrc_err_insert_state;
    end


// ----------------------------------------------- 

assign crc_result0_i[31:1]  =  int_crc0_result[31:1]; 
assign crc_result0_i[0]     = (lcrc_err_insert[0] & pipe_xtlh_has_bus) ? (!int_crc0_result[0]) : int_crc0_result[0];  // for non retry packet only 

assign crc_result1_i[31:1]  =  int_crc1_result[31:1]; 
assign crc_result1_i[0]     = (lcrc_err_insert[1] & pipe_xtlh_has_bus) ? (!int_crc1_result[0]) : int_crc1_result[0];  // for non retry packet only 

assign lcrc_err_asserted    = ((|pipe_eot & !pipe_ignore_1st_eot) | pipe_eot_2) & pipe_dv & !pipe_halt & |lcrc_err_insert & pipe_xtlh_has_bus;

// last_pipe_eot_sts indicates last pipe_eot to remove dummy pipe_eot.
always @(posedge core_clk or negedge core_rst_n) begin
    if (!core_rst_n) begin
        last_pipe_eot_sts  <= #TP 1'b0; 
    end else begin 
        if (pipe_dv && !pipe_halt) begin
            if (pipe_eot_is_last) begin // 
                last_pipe_eot_sts  <= #TP 1'b1; 
            end else begin
                last_pipe_eot_sts  <= #TP 1'b0; 
            end
        end
    end 
end

assign pipe_sot_2           = !(^pipe_sot[NW-1:0]) & (|pipe_sot[NW-1:0]); // for 512b
assign pipe_ignore_1st_eot  = (pipe_no_sot | !pipe_eot_is_last | (!pipe_sot_2 & pipe_eot_2) ) & last_pipe_eot_sts; // 1st eot must be ignored. Please see the comment at the end of fhis file.
// --------------------------------------------------- 
// Error injection feature through RAS DES registers
// --------------------------------------------------- 
// LCRC error insertion must be started at the cycle doesn't have LCRC.
always @(posedge core_clk or negedge core_rst_n) begin
    if (!core_rst_n) begin
        einj0_lcrc_mask <= #TP 1'b1; 
    end else begin 
        if ( einj0_lcrc_reg_en & !int_lcrc_err_en_mask ) begin
            einj0_lcrc_mask <= #TP 1'b0; 
        end else if (!einj0_lcrc_reg_en) begin
            einj0_lcrc_mask <= #TP 1'b1; 
        end
    end 
end

// LCRC error enable/events/insert(insertion control): The lower bit contros the error injection to lower TLPs on the data path that has multiple TLPs.
assign einj0_lcrc_reg_en    = cdm_ras_des_einj0_enable & cdm_ras_des_einj0_crc_type==4'b0000;
assign einj0_lcrc_en[0]     = !einj0_lcrc_mask & einj0_lcrc_reg_en;
assign einj0_lcrc_en[1]     = !einj0_lcrc_mask & einj0_lcrc_reg_en & ((cdm_ras_des_einj0_count==8'd0)|(cdm_ras_des_einj0_count>=8'd2));
assign einj0_lcrc_evt[0]    = einj0_lcrc_en[0] & lcrc_err_asserted & !pipe_ignore_1st_eot;
assign einj0_lcrc_evt[1]    = einj0_lcrc_en[1] & lcrc_err_asserted & pipe_eot_2;
assign lcrc_err_insert[0]   = einj0_lcrc_en[0] | lcrc_err_insert_state[0];
assign lcrc_err_insert[1]   = einj0_lcrc_en[1] | lcrc_err_insert_state[0];
assign xdlh_einj0_lcrc_evt  = event_countones(einj0_lcrc_evt);

// Function to count 1's in the input data.
function automatic [1:0] event_countones;
    input [1:0]  ec_evt;
    reg   [1:0]  ec_evt_num_reg;
    integer      ii;
    begin
        ec_evt_num_reg = 3'd0;
        for ( ii=0; ii<2 ; ii=ii+1 ) begin
// spyglass disable_block W164a
// SMD: Identifies assignments in which the LHS width is less than the RHS width
// SJ: This logic is designed to be modulo. Sequence counters are intended to
// wrap without preseveration of carry/borrow
            ec_evt_num_reg = ec_evt_num_reg + ec_evt[ii];
// spyglass enable_block W164a
        end

        event_countones = ec_evt_num_reg;
    end
endfunction


assign pipe_halt = fifo_full | skip_halt | latched_pipe_eot_halt_w; 

assign pipe_crc0 = crc_result0_i; 
assign pipe_crc1 = crc_result1_i; 

assign int_crc0_result  = (!pipe_halt && pipe_halt_d && CAN_STALL) || ((CRC_LATENCY_M1==1) ? (pipe_halt && pipe_halt_d && CAN_STALL) : 1'b0) ? latched_crc0_result : crc_result[31:0]; 
assign int_crc1_result  = (!pipe_halt && pipe_halt_d && CAN_STALL) || ((CRC_LATENCY_M1==1) ? (pipe_halt && pipe_halt_d && CAN_STALL) : 1'b0) ? latched_crc1_result : crc_result[63:32]; 

// ----------------------------------------------- 

delay_n_w_stalling
 //defined as 2 clk = crc pipeline on; 1 clk = crc pipeline off 
#(CRC_LATENCY, DATAPATH_WIDTH, 0) u0_delay ( 
    .clk        (core_clk), 
    .rst_n      (core_rst_n), 
    .stall      (pipe_halt), 
    .clear      (!rdlh_link_up), 

    .din        ({ 
                   valid_stp_tlp_len, 
                   xtlh_has_bus_d, 
                   filt_int_dv, filt_int_sot, filt_int_eot, filt_int_badeot, valid_seqnum, valid_data
                  ,rbuf_replaying
                 }), 
    .stallout   (), 
    .dout       ({ 
                   pipe_stp_tlp_len, 
                   pipe_xtlh_has_bus, 
                   pipe_dv, pipe_sot, pipe_eot, pipe_badeot, pipe_seqnum, pipe_data
                  , pipe_rbuf_replaying
                  }) 
); 
// ----------------------------------------------- 

// XDLH FIFO 
// Decode all this before FIFO to improve timing and easier synthesis 
wire pipe_badeot_2; 
wire pipe_badeot_1; 
wire pipe_sot_only; 
wire pipe_eot_sot_eot; 
wire pipe_no_eot_sot; 
wire pipe_1eot_only; 
wire pipe_sot_eot; 
wire pipe_eot_sot; 
wire pipe_or_eot; 
reg [3:0] valid_pipe_data; 
reg [3:0] all_pipe_data; 

wire [3:0] nw_pipe_all; 
wire [3:0] nw_pipe_valid; 

assign pipe_eot_2 = !(^pipe_eot[NW-1:0]) & (|pipe_eot[NW-1:0]);   // If 2 EOts, XOR is 0 and OR is 1 
assign pipe_eot_1 =  (^pipe_eot[NW-1:0]) ;    // If 1 EOt, XOR is 1 

assign pipe_badeot_2 = !(^pipe_badeot[NW-1:0]) & (|pipe_badeot[NW-1:0]); 
assign pipe_badeot_1 =  (^pipe_badeot[NW-1:0]) ; 

assign pipe_sot_only = (|pipe_sot) & !(|pipe_eot); 

assign pipe_eot_sot_eot = pipe_eot_2 & (|pipe_sot); 

assign pipe_no_eot_sot = !(|pipe_sot) & !(|pipe_eot); 

assign pipe_1eot_only = !(|pipe_sot) & pipe_eot_1; 

assign pipe_sot_eot = (|pipe_sot) & pipe_eot_1 & (pipe_sot < pipe_eot); 
assign pipe_eot_sot = (|pipe_sot) & pipe_eot_1 & (pipe_sot > pipe_eot); 

assign pipe_or_eot = |pipe_eot; 

assign pipe_eot_is_last = (pipe_sot < pipe_eot); 
assign pipe_no_sot = !(|pipe_sot); 


// dwen for different cases 

wire [NW:0] ext_tlp1_dwen; 
wire [NW:0] ext_tlp2_dwen; 
reg [NW:0] pipe_ext_tlp1_dwen; 
reg [NW:0] pipe_ext_tlp2_dwen; 

always @(*) 
begin : PROC_DWEN_GEN 
  pipe_ext_tlp1_dwen = {(NW+1){1'b0}}; 
  pipe_ext_tlp2_dwen = {(NW+1){1'b0}}; 

  if (pipe_dv & pipe_no_eot_sot) 
     begin 
       pipe_ext_tlp1_dwen = {1'b0, {NW{1'b1}}}; 
       pipe_ext_tlp2_dwen = {(NW+1){1'b0}}; 
     end 
  if (pipe_dv & pipe_sot_only) 
     begin : PROC_DWEN_1 
      integer i; 
      pipe_ext_tlp2_dwen = {(NW+1){1'b0}}; 
      pipe_ext_tlp1_dwen[NW] = 1'b0; 

       pipe_ext_tlp1_dwen[0] = pipe_sot[0]; 
       for (i=1; i<NW; i=i+1) 
         begin 
       pipe_ext_tlp1_dwen[i] = pipe_sot[i] | pipe_ext_tlp1_dwen[i-1]; 
     end 
     end 
   if (pipe_dv & pipe_1eot_only) 
     begin : PROC_DWEN_2 
      integer i; 
      pipe_ext_tlp2_dwen = {(NW+1){1'b0}}; 
      pipe_ext_tlp1_dwen[NW] = 1'b0; 

       pipe_ext_tlp1_dwen[0] = 1'b1;  // At least one DW is valid 
       for (i=1; i<NW; i=i+1) 
         begin 
      pipe_ext_tlp1_dwen[i] = !pipe_eot[i-1] & pipe_ext_tlp1_dwen[i-1]; 
     end 
     end 
   if (pipe_dv & pipe_sot_eot) 
     begin : PROC_DWEN_3 
      integer i; 
      pipe_ext_tlp2_dwen = {(NW+1){1'b0}}; 
      pipe_ext_tlp1_dwen[NW] = 1'b0; 

       pipe_ext_tlp1_dwen[0] = pipe_sot[0]; 
       for (i=1; i<NW; i=i+1) 
         begin 
      pipe_ext_tlp1_dwen[i] = !pipe_eot[i-1] & pipe_ext_tlp1_dwen[i-1] | pipe_sot[i]; 
     end 
     end 

   if (pipe_dv & pipe_eot_sot) 
     begin : PROC_DWEN_4 
      integer i; 
      integer j; 
      pipe_ext_tlp2_dwen[NW] = 1'b0; 
      pipe_ext_tlp1_dwen[NW] = 1'b0; 

       pipe_ext_tlp1_dwen[0] = 1'b1;  // At least one DW is valid 
       for (i=1; i<NW; i=i+1) 
         begin 
      pipe_ext_tlp1_dwen[i] = !pipe_eot[i-1] & pipe_ext_tlp1_dwen[i-1]; 
     end 


       for (j=1; j<NW; j=j+1) 
         begin 
       pipe_ext_tlp2_dwen[j] = pipe_sot[j] | pipe_ext_tlp2_dwen[j-1]; 
     end 
      end 
   if (pipe_dv & pipe_eot_sot_eot) 
     begin : PROC_DWEN_5 
      integer i; 
      integer j; 
      pipe_ext_tlp2_dwen[NW] = 1'b0; 
      pipe_ext_tlp1_dwen[NW] = 1'b0; 

       pipe_ext_tlp1_dwen[0] = 1'b1;  // At least one DW is valid 
       for (i=1; i<NW; i=i+1) 
         begin 
      pipe_ext_tlp1_dwen[i] = !pipe_eot[i-1] & pipe_ext_tlp1_dwen[i-1]; 
     end 

       for (j=1; j<NW; j=j+1) 
         begin 
       pipe_ext_tlp2_dwen[j] = pipe_sot[j] | pipe_ext_tlp2_dwen[j-1] & !pipe_eot[j-1]; 
     end 
      end 
end 

// ----     For new ARCH 


assign start_pipe_dv = !pipe_dv_q & pipe_dv; 

always @(posedge core_clk or negedge core_rst_n) 
      if (!core_rst_n) 
         pipe_dv_q <= #TP 1'b0; 
      else 
         pipe_dv_q <= #TP pipe_dv; 

always @(posedge core_clk or negedge core_rst_n) 
      if (!core_rst_n) 
        latched_pipe_eot_last  <= #TP 1'b0; 
    else begin 
      if (pipe_dv & !pipe_halt & !pipe_eot_is_last | pipe_dv & !out_state & fifo_empty & latched_pipe_eot_halt)  // clear at next packet or when pipeline is empty 
        latched_pipe_eot_last  <= #TP 1'b0; 
       else if (pipe_dv & !pipe_halt & pipe_eot_is_last) 
        latched_pipe_eot_last  <= #TP 1'b1; 
    end 

always @(posedge core_clk or negedge core_rst_n) 
      if (!core_rst_n) 
        latched_pipe_eot_halt  <= #TP 1'b0; 
    else begin
        if (pipe_dv & latched_pipe_eot_last & (pipe_eot_sot_eot | pipe_eot_sot) & !(!out_state & fifo_empty)) // see comment (*) at end of file 
          latched_pipe_eot_halt  <= #TP 1'b1; 
        else if (!out_state & fifo_empty & latched_pipe_eot_halt) 
      latched_pipe_eot_halt  <= #TP 1'b0; 
       end 


always @(posedge core_clk or negedge core_rst_n) 
      if (!core_rst_n) 
        latched_pipe_eot_halt_q  <= #TP 1'b0; 
       else 
        latched_pipe_eot_halt_q  <= #TP latched_pipe_eot_halt; 


assign skip_halt = skip_cycle1 ; 


assign latched_pipe_eot_halt_w = pipe_dv & latched_pipe_eot_last & (pipe_eot_sot_eot | pipe_eot_sot) & !(!out_state & fifo_empty) & !latched_pipe_eot_halt | latched_pipe_eot_halt; 


assign skip_cycle1 = xmlh_skip_pending & pipe_dv & pipe_or_eot & out_state & (skip_cycle == SKIP_IDLE); 


assign skip_cycle2 = pipe_dv & (skip_cycle == SKIP_2); 


always @(*) begin
    next_skip_cycle = SKIP_IDLE; 
    case(skip_cycle) 
       SKIP_IDLE: 
           if (xmlh_skip_pending & pipe_dv & pipe_or_eot & out_state ) 
               next_skip_cycle = SKIP_2; 

       SKIP_2: 
               next_skip_cycle = SKIP_IDLE; 

// mapping SKIP_IDLE to default state to facilitate code coverage
       default:
           if (xmlh_skip_pending & pipe_dv & pipe_or_eot & out_state ) 
               next_skip_cycle = SKIP_2; 
           else
               next_skip_cycle = SKIP_IDLE; 
    endcase 
end 

always @(posedge core_clk or negedge core_rst_n) 
    if (!core_rst_n) 
        skip_cycle <= #TP SKIP_IDLE; 
    else if (!fifo_full) 
        skip_cycle <= #TP next_skip_cycle; 


assign pipe_tlp1_dwen = (((latched_pipe_eot_halt_q | latched_pipe_eot_last) & (pipe_eot_sot_eot | pipe_eot_sot | pipe_1eot_only)) | (pipe_no_sot & start_pipe_dv)) ? {(NW+1){1'b0}} : pipe_ext_tlp1_dwen; 

assign pipe_tlp2_dwen = pipe_ext_tlp2_dwen; 

assign pipe_tlp1_skip_dwen = skip_cycle2 ? {(NW+1){1'b0}} : pipe_tlp1_dwen; 
assign pipe_tlp2_skip_dwen = skip_cycle1 ? {(NW+1){1'b0}} : pipe_tlp2_dwen; 

assign  pipe_tlp_skip_dwen = pipe_tlp1_skip_dwen[NW-1:0] | pipe_tlp2_skip_dwen[NW-1:0]; 


// XDLH FIFO 

assign fifo_in_data = { 
                       pipe_stp_tlp_len, 
                       skip_cycle1, pipe_dv, pipe_tlp_skip_dwen, pipe_sot, pipe_eot, 
                       pipe_badeot, pipe_seqnum, pipe_crc1, pipe_crc0, pipe_data_prot
                      ,pipe_rbuf_replaying
}; 

assign fifo_wr = !fifo_full & pipe_dv & ((skip_cycle == SKIP_IDLE) | skip_cycle2) & !latched_pipe_eot_halt_w; 


// ----------------------------------------------- 
DWC_pcie_ctl_bcm64_td
 #(.WIDTH(FIFO_WIDTH), 
                       .DEPTH(FIFO_DEPTH), 
                       .ERR_MODE(0), 
                       .RST_MODE(0), 
                       .ADDR_WIDTH(FIFO_ADDR_WIDTH),
                       .REG_DELAY_TIME(REG_DELAY_TIME),
                       .REG_DELAY_DENOM(REG_DELAY_DENOM)
                      ) 
// ----------------------------------------------- 

u_xdlh_merge_fifo(// Inputs 
                  .clk(core_clk), .rst_n(core_rst_n), .init_n(1'b1), .push_req_n(!fifo_wr), .pop_req_n(!fifo_rd), 
                  .diag_n(1'b1), .ae_level(FIFO_AE_LEVEL), .af_thresh(FIFO_AF_LEVEL), 
                  .data_in(fifo_in_data), 
                  // Outputs 
                  .empty(fifo_empty), .almost_empty(fifo_almost_empty), .full(fifo_full), 
                  .half_full(fifo_half_full), .almost_full(fifo_almost_full), .error(fifo_error), 
                  .data_out({ 
                             fifo_stp_tlp_len, 
                             fifo_out_skip, fifo_out_dv, fifo_out_tlp_dwen, fifo_out_sot, fifo_out_eot, 
                             fifo_out_badeot, fifo_out_seqnum, fifo_out_crc1, fifo_out_crc0, fifo_out_data 
                            ,fifo_out_rbuf_replaying 
                            }) 
                 ); 

// ----------------------------------------------- 

//  ----   Here starts XDLH merge - STP and CRC insertion on FIFO outputs   ------ 
//  ----   The DLLP Merge will be done also here instead on i xdlh_control  ------ 

wire [31:0] stp_to_merge; 
wire [31:0] stp_dw; 
wire [23:0] stp_10b_dw; 
wire        input_dv; 


// STP Token calculation 

// Calculate Frame CRC for STP Token 
assign frame_crc_org = get_frame_crc(fifo_stp_tlp_len); 
assign frame_crc = einj0_fcrc_en ?{frame_crc_org[3:1],~frame_crc_org[0]} : frame_crc_org ;

assign einj0_fcrc_en       = cdm_ras_des_einj0_enable & cdm_ras_des_einj0_crc_type==4'b0100 & (current_data_rate == `GEN3_RATE || current_data_rate == `GEN4_RATE || current_data_rate == `GEN5_RATE);
assign xdlh_einj0_fcrc_evt = einj0_fcrc_en & (|fifo_out_sot) & input_dv;
// Calculate Frame Parity for STP Token 
assign frame_parity = get_frame_parity(fifo_stp_tlp_len); 

assign stp_dw = {fifo_out_seqnum[7:0], frame_crc, fifo_out_seqnum[11:8], frame_parity, fifo_stp_tlp_len, 4'b1111}; 


assign stp_10b_dw[23:0]  = {fifo_out_seqnum[7:0], 4'b0000, fifo_out_seqnum[11:8], `STP_8B}; 


assign stp_to_merge = (current_data_rate == `GEN3_RATE || current_data_rate == `GEN4_RATE || current_data_rate == `GEN5_RATE) ? stp_dw :   {stp_10b_dw, 8'h00}; 

wire dllp_xmt_halt; 

assign xdctrl_dllp_halt = xdctrl_dllp_halt1 | dllp_xmt_halt; 



wire output_dv; 
wire output_halt; 
wire out_dllp_halt; 

wire [DW-1:0]        output_data; 
wire [NW-1:0]        output_dwen; 
wire [NW-1:0]        output_sot; 
wire [NW-1:0]        output_eot; 
wire [NW-1:0]        output_sdp; 

assign dllp_sdp = output_sdp; 
assign tlp_sot = output_sot; 
assign tlp_eot = output_eot; 
assign tlp_data = output_data; 
assign tlp_dwen = output_dwen; 
assign tlp_dllp_dv = output_dv; 

assign out_state = output_dv && !(output_sdp[0] && output_eot[1] && output_sot==0); // exclude cycles where a single DLLP starting on DW0 is transmitted - see comment (**) 

assign  fifo_rd = !fifo_empty & !xdctrl_tlp_halt & !output_halt; 

assign input_dv = !fifo_empty & fifo_out_dv & !output_skip_halt; 

wire data_rate_is_gen3; 

assign data_rate_is_gen3 = (current_data_rate == `GEN3_RATE || current_data_rate == `GEN4_RATE || current_data_rate == `GEN5_RATE); 


wire [(64*TX_NDLLP)-1:0] dllp_data; 

assign dllp_data =       ((current_data_rate == `GEN3_RATE || current_data_rate == `GEN4_RATE || current_data_rate == `GEN5_RATE) ? dllp_xmt_pkt_130b : {dllp_xmt_pkt_10b[55:0], 8'h00}); 

wire [MNW*(32+CW)-1:0] merged_edata; 
wire                   merged_edata_pkt_pending; 
// ----------------------------------------------- 

xdlh_tlp_gen_512b_merge
  u_merge( 
    .core_clk                  (core_clk), 
    .core_rst_n                (core_rst_n), 
    .input_dv                  (input_dv), 
    .input_data                (fifo_out_data[DW-1:0]), 
    .input_sot                 (fifo_out_sot), 
    .input_eot                 (fifo_out_eot), 
    .input_edb                 (fifo_out_badeot), 
    .input_dwen                (fifo_out_tlp_dwen), 
    .input_crc0                (fifo_out_crc0), 
    .input_crc1                (fifo_out_crc1), 
    .input_stp                 (stp_to_merge), 
    .input_dllp                (dllp_data), 
    .dllp_xmt_req              (dllp_xmt_req[0]), 
    .data_rate_is_gen3         (data_rate_is_gen3), 
    .xmlh_skip_pending         (fifo_out_skip & !fifo_empty), 
    .out_dllp_halt             (out_dllp_halt), 
    // ---- outputs --------------- 
    .dllp_xmt_halt             (dllp_xmt_halt), 
    .merged_edata              (merged_edata), 
    .merged_edata_pkt_pending  (merged_edata_pkt_pending) 
); 

xdlh_tlp_gen_512b_shift
  u_shift( 
    .core_clk                  (core_clk), 
    .core_rst_n                (core_rst_n), 
    .merged_edata              (merged_edata), 
    .merged_edata_pkt_pending  (merged_edata_pkt_pending), 
    .xmlh_skip_pending         (fifo_out_skip & !fifo_empty), 
    .input_halt                (xdctrl_tlp_halt), 
    .data_rate_is_gen3         (data_rate_is_gen3), 
    // ---- outputs --------------- 
    .output_data               (output_data), 
    .output_sot                (output_sot), 
    .output_eot                (output_eot), 
    .output_dwen               (output_dwen), 
    .output_sdp                (output_sdp), 
    .output_halt               (output_halt), 
    .output_dv                 (output_dv), 
    .output_skip_halt          (output_skip_halt), 
    .out_dllp_halt             (out_dllp_halt) 
   ,.tlpgen_pkt_pending        (tlpgen_pkt_pending) 
);
//-----------------------------------------------
// delay rbuf_replaying to be aligned with xdlh_tlp_gen shifted output
//-----------------------------------------------
always @(posedge core_clk or negedge core_rst_n) begin
    if (!core_rst_n)
      rbuf_replaying_out <= #TP 1'b0;
    else
      rbuf_replaying_out <= #TP fifo_out_rbuf_replaying;    
end
 
// ----------------------------------------------- 
// There are 3 reasons to block a new tlp from XTLH 
// 1: retry buffer has not room or sot buffer has no room or pkt in flight 
// exceeds the limit 
// 2: retry buffer is in reply 
// 3: xmlh LTSSM is not in L0 

// When link goes down, we need to deassert halt to ensure that all TLPs 
// fromm upper module being taken and upper pipes are empty 

// filtering smlh_in_l0 to avoid one cycle blips 

always @(posedge core_clk or negedge core_rst_n) 
    if (!core_rst_n) 
      begin 
       smlh_in_l0_q1 <= #TP 1'b0; 
       smlh_in_l0_q2 <= #TP 1'b0; 
      end 
    else 
      begin 
       smlh_in_l0_q2 <= #TP smlh_in_l0_q1; 
       smlh_in_l0_q1 <= #TP smlh_in_l0; 
      end 

assign smlh_in_l0_f = smlh_in_l0_q2 & smlh_in_l0_q1 & smlh_in_l0; 
assign block_new_tlp = rbuf_block_new_tlp | rbuf_block_tlp | !smlh_in_l0_f; 

assign rbuf_halt      = fifo_full | xtlh_has_bus | skip_halt | latched_pipe_eot_halt_w; 

assign xdlh_curnt_seqnum = valid_seqnum; 

// ----------------------------------------------------------------------------- 
// 
// There are few conditions that we need to block xtlh transmission 
// 1. when there is no enough entry available in retry buf 
// 2. When there are too many pkt in flight (>2048) 



// We need to change the logic here to block a new TLP only if there is not enough space for it the the reply buffer. 
// rbuf_entry count needs to compare to the TLP size from the XDLH instead of "max_packet_entries" 

// PCIE down not allow more than 2K packets in flight. We may be further limited by the size of the SOT buffer 
wire    [11:0]  max_pkts_in_flight; 
wire    [RBUF_PW :0]     max_packet_entries; 

assign max_pkts_in_flight = (`SOTBUF_DEPTH <= 12'h800) ? `SOTBUF_DEPTH - 1 - RASDP_PIPE_DELAY - PRFX_ENTRIES: 12'h800; 
assign max_packet_entries = RBUF_DATASIZE + RASDP_PIPE_DELAY;    // Check to make sure we have room for a MAX packet 


// Also make sure there is room for a MAX TLP 
always @(posedge core_clk or negedge core_rst_n) 
begin : rbuf_block_tlp_proc 
    if (!core_rst_n) 
        rbuf_block_tlp  <= #TP 1'b0; 
    else 
        rbuf_block_tlp  <= #TP (rbuf_entry_cnt  <= max_packet_entries) | (rbuf_pkt_cnt >= max_pkts_in_flight); 
end 



always @(posedge core_clk or negedge core_rst_n) 
    if (!core_rst_n) 
      begin 
        tlpgen_reply_grant1 <= #TP 1'b0; 
        tlpgen_reply_grant2 <= #TP 1'b0; 
      end 
   else 
     begin 
        tlpgen_reply_grant1 <= #TP `CHK_ARB_REPLY_GRNT; 
        tlpgen_reply_grant2 <= #TP tlpgen_reply_grant1; 
     end 


assign tlpgen_reply_grant   = tlpgen_reply_grant2 & `CHK_ARB_REPLY_GRNT; 

assign tlpgen_rbuf_eot      = xtlh_has_bus_d ? int_eot : {NW{1'b0}}; 
assign tlpgen_rbuf_seqnum   = xtlh_tlp_seqnum_0_d; 

assign tlpgen_rbuf_dv       = xtlh_has_bus_d & !fifo_full & int_dv & !skip_halt & !latched_pipe_eot_halt_w;
assign tlpgen_rbuf_sot      = xtlh_has_bus_d ? int_sot : {NW{1'b0}}; 
assign tlpgen_rbuf_badeot   = valid_xtlh_badeot & {NW{xtlh_has_bus_d}}; 
assign tlpgen_rbuf_data     = xtlh_has_bus_d ? valid_data : {DW_W_PAR{1'b0}} ;// xtlh_xdlh_data; 


// Function to calculate Frame CRC based on TLP Length 
function automatic [3:0] get_frame_crc; 
  input [10:0] L;   // TLP Length 
  reg   [3:0]  C;   // CRC 

  begin 
    C[0] = L[10] ^ L[7] ^ L[6] ^ L[4] ^ L[2] ^ L[1] ^ L[0]; 
    C[1] = L[10] ^ L[9] ^ L[7] ^ L[5] ^ L[4] ^ L[3] ^ L[2]; 
    C[2] = L[9]  ^ L[8] ^ L[6] ^ L[4] ^ L[3] ^ L[2] ^ L[1]; 
    C[3] = L[8]  ^ L[7] ^ L[5] ^ L[3] ^ L[2] ^ L[1] ^ L[0]; 

    get_frame_crc = C; 
  end 
endfunction 

// Function to calculate Frame Parity based on TLP Length and Frame CRC 
function automatic get_frame_parity; 
  input [10:0] L;   // TLP Length 
  reg          P;   // Parity 

  begin 
    // P = L[10] ^ L[9] ^ L[8] ^ L[7] ^ L[6] ^ L[5] 
    //   ^ L[4]  ^ L[3] ^ L[2] ^ L[1] ^ L[0] 
    //   ^ C[3]  ^ C[2] ^ C[1] ^ C[0]; 
    // This reduces to : 
    P = L[10] ^ L[9] ^ L[8] ^ L[6] ^ L[5] ^ L[2] ^ L[0]; 

    get_frame_parity = P; 
  end 
endfunction 

`ifndef SYNTHESIS

wire    [(20*8)-1:0]    TLP_GEN_STATE; 
assign  TLP_GEN_STATE = (state == ARB_IDLE)                 ? "IDLE"                 : 
                        (state == ARB_REPLY_GRNT)           ? "REPLY_GRNT"           : 
                        (state == ARB_RBUF_IN_XMT)          ? "RBUF_IN_XMT"          : 
                        (state == ARB_XTLH_GRNT)            ? "XTLH_GRNT"            : 
                        (state == ARB_XTLH_IN_XMT)          ? "XTLH_IN_XMT"          : 
                                                              "ERROR" ; 

`endif // SYNTHESIS 

endmodule
// comment (*) 
// When we have seen eot in a previous cycle (as indicated by latched_pipe_eot_last) 
// and we receive another eot (as indicated by pipe_eot_...) it means that this last eot 
// is a left over from a datapath that was interrupted (for example because of replay, 
// skip, replay buffer full, !L0) or manipulated at the time it was stored into the replay 
// buffer to retract a nullified tlp. These events create a discontinuity in the datapath 
// that cannot be handled by the tx pipeline shift logic if transmitted back to back. 
// Therefore there is a need to have logic that halts the datapath and waits for the 
// pipeline to be clear, before continuing the transmission from the point of discontinuity. 
// The discontinuity is represented by a line of datapath where the eot is not followed 
// by sot, and then on the next line an sot starting on a dw greater than dw0. 
// comment (**) 
// Dropping out_state it is necessary to allow the ARB_IDLE state to exit and proceed with 
// a replay when a continuous stream of DLLPs is being transmitted. This scenario can happen 
// for example when a VC is enabled and FC init is executed for that VC while there is TLP 
// traffic flowing on other, already enabled, VCs. 

