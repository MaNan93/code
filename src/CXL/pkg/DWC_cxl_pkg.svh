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

// -----------------------------------------------------------------------------
// --- RCS information:
// ---   $DateTime: 2024/01/19 09:25:58 $
// ---   $Author: neira $
// ---   $Id: //dwh/pcie_iip/main/fairbanks/design/CXL/pkg/DWC_cxl_pkg.svh#18 $
// -----------------------------------------------------------------------------

`ifndef __GUARD__DWC_CXL_PKG__SVH__
`define __GUARD__DWC_CXL_PKG__SVH__

`include "Spif/pkg/spif_pkg.svh"

// -----------------------------------------------------------------------------
// --- Package Description:  CXL General Package
// -----------------------------------------------------------------------------
package DWC_cxl_pkg;

import spif_pkg::state_enc_e;
import spif_pkg::protocol_type_e;

  // Fixed Parameters
  // Init FSM state register width
  localparam INIT_STATE_WD = 8;
  // Credit Control FSM state register width
  localparam CRD_STATE_WD = 3 + 1 + 1;
  // LRSM state register width
  localparam LRSM_STATE_WD = 5;
  // LRSM Flit Generator FSM width
  localparam LRSM_FGEN_STATE_WD = 4;
  // RRSM Flit Generator FSM width
  localparam RRSM_FGEN_STATE_WD = 3;
  // RRSM state register width
  localparam RRSM_STATE_WD = 3;
  // Retry Buffer FSM Width
  localparam RBUF_STATE_WD = 3;
  // Retry Buffer Data Width
  localparam RBUF_DATA_WD = `CX_CXL_RBUF_RAM_DATAW;
  localparam RBUF_DATA_PROT_WD = `CX_CXL_RBUF_RAM_DATA_PROT_WD;
  // CXL Link Layer data width
  localparam CXL_DATA_WD = `CX_CXL_DW;
  // CXL Link Layer data width for CXL 2.0
  localparam CX_CXL_20_DW = 512;
  // CXL Link Layer data width (in bytes)
  localparam CXL_DATA_NBYTES = CXL_DATA_WD/8;
  // CXL IDE Datapath Protection
  localparam CX_CXL_IDE_FLIT_CHK_SIZE = `CX_CXL_IDE_DP_CHK_SIZE;
  // LLCTRL flit width
  localparam LLCTRL_FLIT_WD = 128;
  // Flow Control Counter Width
  localparam TX_CREDIT_WD = 10;
  // Credit Return Counter Width
  localparam RX_CREDIT_WD = 10;
  // Width of the credit return field in a flit
  localparam FLIT_CRD_WD = 4;
  // Width of credit return (less the MSB which is for decode)
  localparam CRD_RET_WD = FLIT_CRD_WD - 1;
  // Decoded Credit Width
  localparam DEC_CRD_WD = 7;
  // Slot Format Width
  localparam SLOT_FMT_WD = 3;
  // Retry Buffer Depth
  localparam RBUF_DP = 255;
  // Retry Buffer Address width
  localparam RBUF_ADD_WD = $clog2(RBUF_DP);
  // Acknowledge Counter Width
  localparam ACK_CNT_WD = 8;
  // Ack Flush Timer Width
  localparam ACK_FLUSH_TIMER_WD = 10;
  // NUM_RETRY Threshold Width
  localparam MAX_RETRY_WD = 5;
  // NUM_PHY_REINIT Threshold Width
  localparam MAX_REINIT_WD = 5;
  // Retry Timeout Width
  localparam RETRY_TIMER_WD = 16;
  // ESEQ Counter Width
  localparam ESEQ_WD = 8;
  // RX_CRC_ERROR Thresold width
  localparam MAX_RX_CRC_ERROR_WD = 10;
  // Viral LD-ID Width
  localparam VIRAL_LDID_WD = 16;

  // Configuration Register Parameters
  localparam LL_CSR_STATE_WD = 2;
  localparam CXL_VERSION_WD = 4;



localparam CXL_256B_FLIT_MODE_EN = 1;

  // Receive Queue Parameters
  localparam TX_CRDIF_WIDTH = (CXL_256B_FLIT_MODE_EN)? 6 : 4;

  localparam CACHE_DHDR_VALID_WD = (`CX_CXL_CACHE_H2D_DATA_NUM > `CX_CXL_CACHE_D2H_DATA_NUM)? `CX_CXL_CACHE_H2D_DATA_NUM : `CX_CXL_CACHE_D2H_DATA_NUM;
  localparam CACHE_REQ_VALID_WD  = (`CX_CXL_CACHE_H2D_REQ_NUM  > `CX_CXL_CACHE_D2H_REQ_NUM )? `CX_CXL_CACHE_H2D_REQ_NUM  : `CX_CXL_CACHE_D2H_REQ_NUM;
  localparam CACHE_RSP_VALID_WD  = (`CX_CXL_CACHE_H2D_RESP_NUM > `CX_CXL_CACHE_D2H_RESP_NUM)? `CX_CXL_CACHE_H2D_RESP_NUM : `CX_CXL_CACHE_D2H_RESP_NUM;
  localparam MEM_NDR_VALID_WD    = (`CX_CXL_MEM_M2S_NDR_NUM    > `CX_CXL_MEM_S2M_NDR_NUM   )? `CX_CXL_MEM_M2S_NDR_NUM    : `CX_CXL_MEM_S2M_NDR_NUM;
  localparam MEM_DR_VALID_WD     = (`CX_CXL_MEM_M2S_DATA_NUM   > `CX_CXL_MEM_S2M_DATA_NUM  )? `CX_CXL_MEM_M2S_DATA_NUM   : `CX_CXL_MEM_S2M_DATA_NUM;
  localparam MEM_BI_VALID_WD     = (`CX_CXL_MEM_M2S_BI_RSP_NUM > `CX_CXL_MEM_S2M_BI_SNP_NUM)? `CX_CXL_MEM_M2S_BI_RSP_NUM : `CX_CXL_MEM_S2M_BI_SNP_NUM;


  // FSM State Encodings
  // Link Initialization FSM encoding
  typedef enum logic [(INIT_STATE_WD - 1) : 0] {
    CXL_INIT_IDLE         = 8'b00000001, // Link initialization idle state.
    CXL_WAIT_FLIT         = 8'b00000010, // Wait to receive either Retry.Idle or Init.Param
    CXL_STALL_INIT        = 8'b00000100, // Stall sending Init.Param flit
    CXL_SEND_INIT_PARAM   = 8'b00001000, // Send Init.Param flit
    CXL_WAIT_INIT_PARAM   = 8'b00010000, // Wait to receive Init.Param flit
    CXL_STALL_INIT_CREDIT = 8'b00100000, // Stall credit initialization
    CXL_INIT_CREDIT       = 8'b01000000, // Initialize credits
    CXL_INIT_DONE         = 8'b10000000  // Initialization complete
  } init_state_e;

  // Credit Control FSM encoding
  typedef enum logic [2:0] {
      CXL_CRD_IDLE          = 3'b001,  // Idle
      CXL_REQ_LLCRD         = 3'b010,  // Request to send LLCRD flit received
      CXL_INIT_CRD          = 3'b100   // Initialize CXL.cachemem credits
  } crd_state_e;

  // LRSM Encoding
  typedef enum logic [(LRSM_STATE_WD - 1) : 0] {
      CXL_LRSM_NORMAL     = 5'b00001,
      CXL_LRSM_LLREQ      = 5'b00010,
      CXL_LRSM_IDLE       = 5'b00100,
      CXL_LRSM_PHY_REINIT = 5'b01000,
      CXL_LRSM_ABORT      = 5'b10000
  } lrsm_state_e;

  typedef enum logic [(LRSM_FGEN_STATE_WD - 1) : 0] {
    CXL_LRSM_GEN_NULL   = 4'b0001,
    CXL_LRSM_GEN_FRAME  = 4'b0010, 
    CXL_LRSM_GEN_RREQ   = 4'b0100,
    CXL_LRSM_GEN_IDLE   = 4'b1000
  } lrsm_fgen_state_e;

  // RRSM Encoding
  typedef enum logic [(RRSM_STATE_WD - 1) : 0] {
    CXL_RRSM_NORMAL = 3'b001,
    CXL_RRSM_LRACK  = 3'b010,
    CXL_RRSM_RETRY  = 3'b100
  } rrsm_state_e;

  typedef enum logic [(RRSM_FGEN_STATE_WD - 1) : 0] {
    CXL_RRSM_GEN_NULL   = 3'b001,
    CXL_RRSM_GEN_FRAME  = 3'b010, 
    CXL_RRSM_GEN_RACK   = 3'b100
  } rrsm_fgen_state_e;

  typedef enum logic [(RBUF_STATE_WD - 1) : 0] {
    CXL_RBUF_IDLE       = 3'b001,
    CXL_RBUF_READ       = 3'b010,
    CXL_RBUF_DONE       = 3'b100
  } rbuf_state_e;


  // Enumerations
  // Flit Type
  typedef enum logic {
    PROTOCOL = 1'b0,  // Flit is protocol
    CONTROL = 1'b1    // Flit is Control
  } flit_type_e;

  // LLCTRL Flit Type
  typedef enum logic [3:0] {
    LLCRD = 4'h0,
    RETRY = 4'h1,
    INIT = 4'hc
  } llctrl_type_e;

  typedef enum logic [3:0] {
    CXL_IO = 4'b0001,
    CXL_MEM_CACHE = 4'b0010
  } vlsm_inst_e;

  typedef enum logic {
    REQUEST = 1'b1,
    STATUS = 1'b0
  } almp_type_e;

// LLCTRL Flit Types
  localparam [3:0]  LLCTRL_LLCRD        = 4'b0000;
  localparam [3:0]  LLCTRL_RETRY        = 4'b0001;
  localparam [3:0]  LLCTRL_INERR        = 4'b0011;
  localparam [3:0]  LLCTRL_INIT         = 4'b1100;

  // LLCTRL Flit Sub-Types
  localparam [3:0]  LLCTRL_INIT_PARAM   = 4'b1000;
  localparam [3:0]  LLCTRL_INIT_VD      = 4'b1110;
  localparam [3:0]  LLCTRL_LLCRD_ACK    = 4'b0001;
  localparam [3:0]  LLCTRL_RETRY_IDLE   = 4'b0000;
  localparam [3:0]  LLCTRL_RETRY_REQ    = 4'b0001;
  localparam [3:0]  LLCTRL_RETRY_ACK    = 4'b0010;
  localparam [3:0]  LLCTRL_RETRY_FRAME  = 4'b0011;
  localparam [3:0]  LLCTRL_INERR_VIRAL  = 4'b0000;
  localparam [3:0]  LLCTRL_INERR_POISON = 4'b0001;
  
  // LLCTRL INIT.VD Sub-Types
  localparam [3:0]  LLCTRL_INIT_VD_IDE  = 4'b0001;
  localparam [3:0]  LLCTRL_INIT_VD_RAS  = 4'b0010;

  // LLCTRL Frame Type: 64-bit or 96-bit Payload
  localparam [2:0]  CTL_FMT_64   = 3'b000;
  localparam [2:0]  CTL_FMT_96   = 3'b001;

  // ALMP Struct
  typedef struct packed {
    logic [3:0]   b3_rsvd_bits;
    vlsm_inst_e   vlsm_inst;
    almp_type_e   almp_type;
    logic [2:0]   b2_rsvd_bits;
    state_enc_e   almp_enc; // ALMP Encoding
    logic         valid;
  } almp_struct;

  // LLCTRL Flit Struct
  typedef struct packed {
    logic [(LLCTRL_FLIT_WD / 2) - 1 : 0]  payload;      // LLCTRL Flit payload
    logic [23:0]                          zeros;        // Bits tied to 0
    logic [3:0]                           sub_type;     // LLCTRL sub-type
    llctrl_type_e                         llctrl_type;  // LLCTRL flit type
    logic [3:0]                           data_crd;     // Data Credits
    logic [3:0]                           req_crd;      // Request Credits
    logic [3:0]                           rsp_crd;      // Response Credits
    logic                                 rev_crd;      // Reverse Credits (CRV)
    logic [15:0]                          rsvd_bits;    // Reserved 
    logic                                 ack;          // Acknowledge 
    logic                                 rsvd;         // Reserved 
    flit_type_e                           flit_type;    // 0 - Protocol Flit
                                                        // 1 - Control Flit
    logic                                 valid;        // LLCTRL Flit Valid
  } llctrl_struct;

  typedef enum logic [1:0] {
      S_GRNT_IO        = 2'b00,
      S_GRNT_CACHE_MEM = 2'b01,
      S_GRNT_ALMP      = 2'b10,
      S_GRNT_NULL      = 2'b11
  } cxl_arb_grnt_t;


// ----------------------------------------------------------------------------
// vLSM Debug Information Bus
// ----------------------------------------------------------------------------
  typedef struct packed {
    /* bit 31:31 */  logic            almp_state_req  ; // Request to transmit State Request ALMP
    /* bit 30:30 */  logic            almp_state_rsp  ; // Enable State Status Response for received State Request ALMP
    /* bit 29:29 */  logic            almp_state_sts  ; // State Status Synchronization Request
    /* bit 28:28 */  logic            almp_state_err  ; // State Status Synchronization Error
    /* bit 27:27 */  logic            almp_unexp_err  ; // Unexpected ALMP Error - pulse
    /* bit 26:24 */  logic [2:0]      almp_unexp_info ; // Unexpected ALMP Error - debug information
    /* bit 23:20 */  logic [3:0]      almp_tx_fsm     ; // ALMP Generator TX FSM state
    /* bit 19:16 */  logic [3:0]      almp_rx_fsm     ; // ALMP Generator RX FSM state
    /* bit 15:12 */  state_enc_e      almp_tx_req     ; // Link vLSM State Request
    /* bit 11: 8 */  state_enc_e      almp_tx_sts     ; // Link vLSM State Status
    /* bit  7: 4 */  state_enc_e      almp_rx_req     ; // Last received State Request ALMP 
    /* bit  3: 0 */  state_enc_e      almp_rx_sts     ; // Last received State Status ALMP
  } vlsm_almp_debug_t;

  typedef struct packed {
    /* bit 31:28 */  state_enc_e      vlsm_state_rslvd        ; // Resolved Link State on exit from the recovery
    /* bit 27:24 */  state_enc_e      vlsm_state_snap         ; // Link State Sanpshot on entry to the recovery
    /* bit 23:23 */  logic            vlsm_link_stall_req     ; // Link Layer Stall Request
    /* bit 22:22 */  logic            vlsm_link_stall_ack     ; // Link Layer Stall Acknowledge
    /* bit 21:21 */  logic            vlsm_link_rx_active_req ; // Link Layer RX Active Request
    /* bit 20:20 */  logic            vlsm_link_rx_active_sts ; // Link Layer RX Active Acknowledge
    /* bit 19:19 */  logic            vlsm_link_block_dl_init ; // Link Layer Block Initialization
    /* bit 18:18 */  logic            vlsm_link_dl_active     ; // Link Layer Initialization Status
    /* bit 17: 0 */  logic [17:0]     vlsm_link_fsm           ; // Link vLSM FSM state
  } vlsm_link_debug_t;

  typedef struct packed {
    /* bit 31:31 */  logic            almp_unexp_err  ; // ALMP Unexpected error
    /* bit 30:30 */  logic            almp_repl_err   ; // ALMP Replication error
    /* bit 29:29 */  logic            pl_protocol_vld ; // Protocol Valid
    /* bit 28:26 */  protocol_type_e  pl_protocol     ; // Protocol Type
    /* bit 25:25 */  logic            pl_stall_req    ; // Physical Layer Stall Request
    /* bit 24:24 */  logic            pl_stall_ack    ; // Physical Layer Stall Acknowledge
    /* bit 23:20 */  state_enc_e      pl_state_req    ; // Physical Layer State Request
    /* bit 19:16 */  state_enc_e      pl_state_sts    ; // Physical Layer State Status
    /* bit 15:12 */  state_enc_e      mc_state_req    ; // CXL.cachemem Link Layer State Request
    /* bit 11: 8 */  state_enc_e      mc_state_sts    ; // CXL.cachemem Link Layer State Status
    /* bit  7: 4 */  state_enc_e      io_state_req    ; // CXL.io Link Layer State Request
    /* bit  3: 0 */  state_enc_e      io_state_sts    ; // CXL.io Link Layer State Status
  } vlsm_info_debug_t;

  typedef struct packed {
    /* bit 159:128 */  vlsm_info_debug_t   pl_info ; // Physical and Link Layer Common Debug Information
    /* bit 127: 96 */  vlsm_link_debug_t   mc_link ; // CXL.cachemem Link vLSM Debug Information
    /* bit  95: 64 */  vlsm_almp_debug_t   mc_almp ; // CXL.cachemem ALMP Generator Debug Information
    /* bit  63: 32 */  vlsm_link_debug_t   io_link ; // CXL.io Link vLSM Debug Information
    /* bit  31:  0 */  vlsm_almp_debug_t   io_almp ; // CXL.io ALMP Generator Debug Information
  } vlsm_debug_t;
// ----------------------------------------------------------------------------

  // Configurable Parameters
  // Enable Triplication of registers
  localparam TMR_EN = `CX_TMR_EN_VALUE;
  // Queue Sizes
  localparam CACHE_DQ_DP         = (`CX_CXL_CACHE_DQ_DP  == 4) ? 1023 : 2**(6 + `CX_CXL_CACHE_DQ_DP);
  localparam CACHE_RSPQ_DP       = (`CX_CXL_CACHE_RSP_DP == 4) ? 1023 : 2**(6 + `CX_CXL_CACHE_RSP_DP);
  localparam CACHE_REQ_DP        = (`CX_CXL_CACHE_REQ_DP == 4) ? 1023 : 2**(6 + `CX_CXL_CACHE_REQ_DP);
  localparam MEM_DQ_DP           = (`CX_CXL_MEM_DQ_DP    == 4) ? 1023 : 2**(6 + `CX_CXL_MEM_DQ_DP);
  localparam CACHE_DQ_CEIL2_DP   = 2**(6 + `CX_CXL_CACHE_DQ_DP) ;
  localparam CACHE_RSPQ_CEIL2_DP = 2**(6 + `CX_CXL_CACHE_RSP_DP);
  localparam CACHE_REQ_CEIL2_DP  = 2**(6 + `CX_CXL_CACHE_REQ_DP);
  localparam MEM_DQ_CEIL2_DP     = 2**(6 + `CX_CXL_MEM_DQ_DP)   ;
  //`ifdef CX_CXL_M2S_S2M_ENABLE
  localparam MEM_REQ_DP    = (`CX_CXL_MEM_REQ_DP   == 4) ? 1023 : 2**(6 + `CX_CXL_MEM_REQ_DP);
  localparam MEM_REQ_CEIL2_DP    = 2**(6 + `CX_CXL_MEM_REQ_DP);
  //`endif // CX_CXL_M2S_S2M_ENABLE
  //`ifdef CX_CXL_S2M_M2S_ENABLE
  localparam MEM_RSPQ_DP   = (`CX_CXL_MEM_RSP_DP   == 4) ? 1023 : 2**(6 + `CX_CXL_MEM_RSP_DP);
  localparam MEM_RSPQ_CEIL2_DP   = 2**(6 + `CX_CXL_MEM_RSP_DP);
  //`endif // CX_CXL_S2M_M2S_ENABLE
  //`ifdef CX_CXL_BI_RSP_SNP_ENABLE
  localparam MEM_BI_SNP_DP     = (`CX_CXL_MEM_BI_SNP_DP == 4) ? 1023 : 2**(6 + `CX_CXL_MEM_BI_SNP_DP);
  localparam MEM_BI_SNP_CEIL2_DP = 2**(6 + `CX_CXL_MEM_BI_SNP_DP);
  //`endif // CX_CXL_BI_RSP_SNP_ENABLE
  //`ifdef CX_CXL_BI_SNP_RSP_ENABLE
  localparam MEM_BI_RSP_DP     = (`CX_CXL_MEM_BI_RSP_DP == 4) ? 1023 : 2**(6 + `CX_CXL_MEM_BI_RSP_DP);
  localparam MEM_BI_RSP_CEIL2_DP = 2**(6 + `CX_CXL_MEM_BI_RSP_DP);
  //`endif // CX_CXL_BI_SNP_RSP_ENABLE

  localparam CXL_RBUF_SIZE = 2**`CX_CXL_RBUF_WD - 1;
  localparam CXL_RBUF_WD   = `CX_CXL_RBUF_WD;

  localparam CACHE_DATA_CRD_WD = (6 + `CX_CXL_CACHE_DQ_DP);
  localparam CACHE_RSP_CRD_WD  = (6 + `CX_CXL_CACHE_RSP_DP);
  localparam CACHE_REQ_CRD_WD  = (6 + `CX_CXL_CACHE_REQ_DP);
  localparam MEM_DATA_CRD_WD   = (6 + `CX_CXL_MEM_DQ_DP);
  localparam MEM_NDR_CRD_WD    = (6 + `CX_CXL_MEM_REQ_DP);

  localparam MEM_BI_RSP_CRD_WD             = (6 + `CX_CXL_MEM_BI_RSP_DP);
  localparam MEM_BI_SNP_CRD_WD             = (6 + `CX_CXL_MEM_BI_SNP_DP);
  localparam MEM_BI_CRD_WD                 = MEM_BI_RSP_CRD_WD;

  localparam FLIT_SLOT_NUM                 = `CX_CXL_FLIT_SLOT_NUM; // Total Number of Slots
  localparam FLIT_SLOT_NUM_PAGE            = (FLIT_SLOT_NUM>4)? 4 : FLIT_SLOT_NUM; // Numver of slots per page
  localparam FLIT_NUM_PAGE                 = (FLIT_SLOT_NUM>4)? 2 : 1; // Number of Pages per cycle
  localparam LINK_DATA_NUM                 = `CX_CXL_LINK_DATA_NUM;
//`ifdef CX_CXL_CACHE_EN
  localparam CACHE_AL_RSP_CRD_WD  = 4;
  localparam CACHE_AL_REQ_CRD_WD  = 4;
  localparam CACHE_AL_DATA_CRD_WD = 4;
  //`ifdef CX_CXL_UPSTREAM_PORT
  localparam H2D_REQ_SIZE   = `CX_CXL_CACHE_H2D_REQ_SIZE  ; 
  localparam H2D_68B_REQ_SIZE              = `CX_CXL_CACHE_68B_H2D_REQ_SIZE  ; 
  localparam H2D_HBR_REQ_SIZE              = `CX_CXL_CACHE_HBR_H2D_REQ_SIZE  ; 
  localparam H2D_PBR_REQ_SIZE              = `CX_CXL_CACHE_PBR_H2D_REQ_SIZE  ; 
  localparam H2D_256B_REQ_SIZE             = `CX_CXL_CACHE_256B_H2D_REQ_SIZE  ; 

                                                   
  localparam H2D_RESP_SIZE  = `CX_CXL_CACHE_H2D_RESP_SIZE ;
  localparam H2D_68B_RESP_SIZE             = `CX_CXL_CACHE_68B_H2D_RESP_SIZE ;
  localparam H2D_HBR_RESP_SIZE             = `CX_CXL_CACHE_HBR_H2D_RESP_SIZE ;
  localparam H2D_PBR_RESP_SIZE             = `CX_CXL_CACHE_PBR_H2D_RESP_SIZE ;
  localparam H2D_256B_RESP_SIZE            = `CX_CXL_CACHE_256B_H2D_RESP_SIZE ;
                                                   
  localparam H2D_DATA_SIZE  = `CX_CXL_CACHE_H2D_DATA_SIZE ;
  localparam H2D_68B_DATA_SIZE             = `CX_CXL_CACHE_68B_H2D_DATA_SIZE ;
  localparam H2D_HBR_DATA_SIZE             = `CX_CXL_CACHE_HBR_H2D_DATA_SIZE ;
  localparam H2D_PBR_DATA_SIZE             = `CX_CXL_CACHE_PBR_H2D_DATA_SIZE ;
  localparam H2D_256B_DATA_SIZE            = `CX_CXL_CACHE_256B_H2D_DATA_SIZE ;
                                                   
  localparam H2D_DHDR_SIZE  = `CX_CXL_CACHE_H2D_DHDR_SIZE ;
  localparam H2D_68B_DHDR_SIZE             = `CX_CXL_CACHE_68B_H2D_DHDR_SIZE ;
  localparam H2D_HBR_DHDR_SIZE             = `CX_CXL_CACHE_HBR_H2D_DHDR_SIZE ;
  localparam H2D_PBR_DHDR_SIZE             = `CX_CXL_CACHE_PBR_H2D_DHDR_SIZE ;
  localparam H2D_256B_DHDR_SIZE            = `CX_CXL_CACHE_256B_H2D_DHDR_SIZE ;
                                                   
  localparam H2D_DDATA_SIZE = `CX_CXL_CACHE_H2D_DDATA_SIZE;
  localparam H2D_68B_DDATA_SIZE            = `CX_CXL_CACHE_68B_H2D_DDATA_SIZE;
  localparam H2D_HBR_DDATA_SIZE            = `CX_CXL_CACHE_HBR_H2D_DDATA_SIZE;
  localparam H2D_PBR_DDATA_SIZE            = `CX_CXL_CACHE_PBR_H2D_DDATA_SIZE;
  localparam H2D_256B_DDATA_SIZE           = `CX_CXL_CACHE_256B_H2D_DDATA_SIZE;
                                                   
  // Protection Parameters for CHI
  localparam CX_CXL_CHI_PROT_TYPE          = (`CX_CXL_CHI_DATACHK == 1) ? 1'b1 :0;
  localparam CX_CXL_CHI_PROT_RANGE         = `CX_CXL_PROTECTION_RANGE;
  localparam CX_CXL_CHI_PROT_RANGE_WIDTH   = `CX_CXL_PROTECTION_RANGE_WIDTH;
  localparam CX_CXL_CHI_PARITY_MODE        = 1'b1;

  // Generic CXL Protection Paramters
  localparam CX_CXL_PROT_TYPE              = `CX_RAS_PROT_TYPE;
  localparam CX_CXL_PROT_RANGE             = `CX_RAS_PROT_RANGE;
  localparam CX_CXL_PROT_RANGE_WIDTH       = `RAS_BASE_PROT_WD;
  localparam CX_CXL_PARITY_MODE            = `CX_RAS_PARITY_MODE;
  
  // Generic CXL RAM Protection Parameters
  localparam CX_CXL_RAM_PROT_TYPE          = 0;
  localparam CX_CXL_RAM_PROT_RANGE         = `CX_CXL_RAM_PROTECTION_RANGE;
  localparam CX_CXL_RAM_PROT_RANGE_WIDTH   = `CX_CXL_RAM_PROTECTION_RANGE_WIDTH;
  localparam CX_CXL_RAM_PARITY_MODE        = 1'b0;
  
  localparam ALMP_PROT_W                   = (128/CX_CXL_PROT_RANGE)*CX_CXL_PROT_RANGE_WIDTH;
  
  // Flit width for RAS
  localparam CXL_DATA_PROT_WD  = (CXL_DATA_WD/CX_CXL_PROT_RANGE)*CX_CXL_PROT_RANGE_WIDTH;
  localparam LLCTRL_FLIT_CHK_SIZE = (LLCTRL_FLIT_WD/CX_CXL_PROT_RANGE)*CX_CXL_PROT_RANGE_WIDTH;

  localparam CX_CXL_PROTECTION_RANGE = `CX_CXL_PROTECTION_RANGE;
  localparam CX_CXL_PROTECTION_RANGE_WIDTH = `CX_CXL_PROTECTION_RANGE_WIDTH;
  localparam H2D_RESP_PTR_SIZE             = `CX_CXL_CACHE_H2D_RESP_PTR_SIZE; 
  localparam H2D_REQ_CHK_SIZE   = `CX_CXL_CACHE_H2D_REQ_CHK_SIZE  ; 
  localparam H2D_RESP_CHK_SIZE  = `CX_CXL_CACHE_H2D_RESP_CHK_SIZE ;
  localparam H2D_DHDR_CHK_SIZE  = `CX_CXL_CACHE_H2D_DHDR_CHK_SIZE ;
  localparam H2D_DDATA_CHK_SIZE = `CX_CXL_CACHE_H2D_DDATA_CHK_SIZE;
  localparam H2D_DATA_CHK_SIZE  = `CX_CXL_CACHE_H2D_DATA_CHK_SIZE ;
  localparam H2D_RESP_PTR_DP_SIZE = `CX_CXL_CACHE_H2D_RESP_PTR_DP_SIZE; 
  localparam H2D_REQ_FUNC_DATAW      = H2D_RESP_PTR_SIZE + H2D_REQ_SIZE;
  localparam H2D_RESP_FUNC_DATAW     = H2D_RESP_SIZE;
  localparam H2D_DATA_FUNC_DATAW     = H2D_DATA_SIZE;
  localparam H2D_REQ_RX_CH_SIZE   = H2D_REQ_SIZE + H2D_REQ_CHK_SIZE;
  localparam H2D_RESP_RX_CH_SIZE  = H2D_RESP_SIZE + H2D_RESP_CHK_SIZE;
  localparam H2D_DATA_RX_CH_SIZE  = H2D_DATA_SIZE + H2D_DATA_CHK_SIZE;
  localparam H2D_DHDR_RX_CH_SIZE  = H2D_DHDR_SIZE + H2D_DHDR_CHK_SIZE;
  localparam H2D_DDATA_RX_CH_SIZE          = H2D_DDATA_SIZE + H2D_DDATA_CHK_SIZE; ///////

  // Maximum number of H2D messages
  localparam H2D_REQ_NUM   = `CX_CXL_CACHE_H2D_REQ_NUM  ; 
  localparam H2D_68B_REQ_NUM               = `CX_CXL_CACHE_68B_H2D_REQ_NUM  ;
  localparam H2D_256B_REQ_NUM              = `CX_CXL_CACHE_256B_H2D_REQ_NUM  ; 
                                                   
  localparam H2D_RESP_NUM  = `CX_CXL_CACHE_H2D_RESP_NUM ;
  localparam H2D_68B_RESP_NUM              = `CX_CXL_CACHE_68B_H2D_RESP_NUM ;
  localparam H2D_256B_RESP_NUM             = `CX_CXL_CACHE_256B_H2D_RESP_NUM ;
                                                   
  localparam H2D_DATA_NUM                  = `CX_CXL_CACHE_H2D_DATA_NUM ;
  localparam H2D_68B_DATA_NUM              = `CX_CXL_CACHE_68B_H2D_DATA_NUM ;
  localparam H2D_256B_DATA_NUM             = `CX_CXL_CACHE_256B_H2D_DATA_NUM ;

  localparam H2D_DDATA_NUM                 = `CX_CXL_CACHE_H2D_DDATA_NUM ; 
  localparam H2D_68B_DDATA_NUM             = `CX_CXL_CACHE_68B_H2D_DDATA_NUM ; 
  localparam H2D_256B_DDATA_NUM            = `CX_CXL_CACHE_256B_H2D_DDATA_NUM ; 
  
  // Maximum number of H2D channel message interfaces
  localparam H2D_REQ_IFNUM   = `CX_CXL_CACHE_H2D_REQ_IFNUM  ; 
  localparam H2D_RESP_IFNUM  = `CX_CXL_CACHE_H2D_RESP_IFNUM ;
  localparam H2D_DATA_IFNUM  = `CX_CXL_CACHE_H2D_DATA_IFNUM ;
  //`endif
  //`ifdef CX_CXL_DOWNSTREAM_PORT
                                                   
  localparam D2H_REQ_SIZE                  = `CX_CXL_CACHE_D2H_REQ_SIZE  ; 
  localparam D2H_68B_REQ_SIZE              = `CX_CXL_CACHE_68B_D2H_REQ_SIZE  ; 
  localparam D2H_HBR_REQ_SIZE              = `CX_CXL_CACHE_HBR_D2H_REQ_SIZE  ; 
  localparam D2H_PBR_REQ_SIZE              = `CX_CXL_CACHE_PBR_D2H_REQ_SIZE  ; 
  localparam D2H_256B_REQ_SIZE             = `CX_CXL_CACHE_256B_D2H_REQ_SIZE  ;
                                                   
  localparam D2H_RESP_SIZE = `CX_CXL_CACHE_D2H_RESP_SIZE ; 
  localparam D2H_68B_RESP_SIZE             = `CX_CXL_CACHE_68B_D2H_RESP_SIZE ; 
  localparam D2H_HBR_RESP_SIZE             = `CX_CXL_CACHE_HBR_D2H_RESP_SIZE ; 
  localparam D2H_PBR_RESP_SIZE             = `CX_CXL_CACHE_PBR_D2H_RESP_SIZE ;
  localparam D2H_256B_RESP_SIZE            = `CX_CXL_CACHE_256B_D2H_RESP_SIZE ; 
                                                   
  localparam D2H_DATA_SIZE = `CX_CXL_CACHE_D2H_DATA_SIZE ; 
  localparam D2H_68B_DATA_SIZE             = `CX_CXL_CACHE_68B_D2H_DATA_SIZE ; 
  localparam D2H_HBR_DATA_SIZE             = `CX_CXL_CACHE_HBR_D2H_DATA_SIZE ; 
  localparam D2H_PBR_DATA_SIZE             = `CX_CXL_CACHE_PBR_D2H_DATA_SIZE ; 
  localparam D2H_256B_DATA_SIZE            = `CX_CXL_CACHE_256B_D2H_DATA_SIZE ; 

  localparam D2H_DHDR_SIZE = `CX_CXL_CACHE_D2H_DHDR_SIZE ; 
  localparam D2H_68B_DHDR_SIZE             = `CX_CXL_CACHE_68B_D2H_DHDR_SIZE ;
  localparam D2H_HBR_DHDR_SIZE             = `CX_CXL_CACHE_HBR_D2H_DHDR_SIZE ;
  localparam D2H_PBR_DHDR_SIZE             = `CX_CXL_CACHE_PBR_D2H_DHDR_SIZE ;
  localparam D2H_256B_DHDR_SIZE            = `CX_CXL_CACHE_256B_D2H_DHDR_SIZE ;
                                                   
  localparam D2H_DDATA_SIZE= `CX_CXL_CACHE_D2H_DDATA_SIZE;
  localparam D2H_68B_DDATA_SIZE            = `CX_CXL_CACHE_68B_D2H_DDATA_SIZE;
  localparam D2H_HBR_DDATA_SIZE            = `CX_CXL_CACHE_HBR_D2H_DDATA_SIZE;
  localparam D2H_PBR_DDATA_SIZE            = `CX_CXL_CACHE_PBR_D2H_DDATA_SIZE;
  localparam D2H_256B_DDATA_SIZE           = `CX_CXL_CACHE_256B_D2H_DDATA_SIZE;
                                                   
  localparam D2H_DBE_SIZE  = `CX_CXL_CACHE_D2H_DBE_SIZE  ; 
  localparam D2H_68B_DBE_SIZE              = `CX_CXL_CACHE_68B_D2H_DBE_SIZE  ; 
  localparam D2H_HBR_DBE_SIZE              = `CX_CXL_CACHE_HBR_D2H_DBE_SIZE  ; 
  localparam D2H_PBR_DBE_SIZE              = `CX_CXL_CACHE_PBR_D2H_DBE_SIZE  ; 
  localparam D2H_256B_DBE_SIZE             = `CX_CXL_CACHE_256B_D2H_DBE_SIZE  ; 
                                                   
  localparam D2H_REQ_CHK_SIZE   = `CX_CXL_CACHE_D2H_REQ_CHK_SIZE  ; 
  localparam D2H_RESP_CHK_SIZE  = `CX_CXL_CACHE_D2H_RESP_CHK_SIZE ;
  localparam D2H_DHDR_CHK_SIZE  = `CX_CXL_CACHE_D2H_DHDR_CHK_SIZE ;
  localparam D2H_DDATA_CHK_SIZE = `CX_CXL_CACHE_D2H_DDATA_CHK_SIZE;
  localparam D2H_DBE_CHK_SIZE   = `CX_CXL_CACHE_D2H_DBE_CHK_SIZE  ; 
  localparam D2H_DATA_CHK_SIZE  = `CX_CXL_CACHE_D2H_DATA_CHK_SIZE ;
  localparam D2H_REQ_FUNC_DATAW      = D2H_REQ_SIZE;
  localparam D2H_RESP_FUNC_DATAW     = D2H_RESP_SIZE;
  localparam D2H_DATA_FUNC_DATAW     = D2H_DATA_SIZE;
  localparam D2H_REQ_RX_CH_SIZE   = D2H_REQ_SIZE + D2H_REQ_CHK_SIZE;
  localparam D2H_RESP_RX_CH_SIZE  = D2H_RESP_SIZE + D2H_RESP_CHK_SIZE;
  localparam D2H_DATA_RX_CH_SIZE  = D2H_DATA_SIZE + D2H_DATA_CHK_SIZE;
  localparam D2H_DHDR_RX_CH_SIZE  = D2H_DHDR_SIZE + D2H_DHDR_CHK_SIZE;
  localparam D2H_DBE_RX_CH_SIZE   = D2H_DBE_SIZE + D2H_DBE_CHK_SIZE;
  localparam D2H_DDATA_RX_CH_SIZE = D2H_DDATA_SIZE + D2H_DDATA_CHK_SIZE;
  // Maximum number of D2H messages
                                                    
  localparam D2H_REQ_NUM  = `CX_CXL_CACHE_D2H_REQ_NUM  ; 
  localparam D2H_68B_REQ_NUM               = `CX_CXL_CACHE_68B_D2H_REQ_NUM  ; 
  localparam D2H_256B_REQ_NUM              = `CX_CXL_CACHE_256B_D2H_REQ_NUM  ; 
                                                    
  localparam D2H_RESP_NUM = `CX_CXL_CACHE_D2H_RESP_NUM ; 
  localparam D2H_68B_RESP_NUM              = `CX_CXL_CACHE_68B_D2H_RESP_NUM ;
  localparam D2H_256B_RESP_NUM             = `CX_CXL_CACHE_256B_D2H_RESP_NUM ;
  
  localparam D2H_DDATA_NUM                 = `CX_CXL_CACHE_D2H_DDATA_NUM ; 
  localparam D2H_68B_DDATA_NUM             = `CX_CXL_CACHE_68B_D2H_DDATA_NUM ; 
  localparam D2H_256B_DDATA_NUM            = `CX_CXL_CACHE_256B_D2H_DDATA_NUM ; 

  localparam D2H_DATA_NUM = `CX_CXL_CACHE_D2H_DATA_NUM ;
  localparam D2H_68B_DATA_NUM              = `CX_CXL_CACHE_68B_D2H_DATA_NUM ;
  localparam D2H_256B_DATA_NUM             = `CX_CXL_CACHE_256B_D2H_DATA_NUM ;
  
  // Maximum number of D2H channel message interfaces
  localparam D2H_REQ_IFNUM  = `CX_CXL_CACHE_D2H_REQ_IFNUM  ; 
  localparam D2H_RESP_IFNUM = `CX_CXL_CACHE_D2H_RESP_IFNUM ; 
  localparam D2H_DATA_IFNUM = `CX_CXL_CACHE_D2H_DATA_IFNUM ;

//`ifdef CX_CXL_MEM_EN
  localparam MEM_AL_RSP_CRD_WD  = 4;
  localparam MEM_AL_REQ_CRD_WD  = 4;
  localparam MEM_AL_DATA_CRD_WD = 4;
  localparam MEM_AL_BI_CRD_WD   = 4;
  //`ifdef CX_CXL_UPSTREAM_PORT
                                                    
  localparam M2S_NDR_SIZE  = `CX_CXL_MEM_M2S_NDR_SIZE  ; 
  localparam M2S_68B_NDR_SIZE              = `CX_CXL_MEM_68B_M2S_NDR_SIZE  ; 
  localparam M2S_HBR_NDR_SIZE              = `CX_CXL_MEM_HBR_M2S_NDR_SIZE  ; 
  localparam M2S_PBR_NDR_SIZE              = `CX_CXL_MEM_PBR_M2S_NDR_SIZE  ; 
  localparam M2S_256B_NDR_SIZE             = `CX_CXL_MEM_256B_M2S_NDR_SIZE  ; 

                                                    
  localparam M2S_DATA_SIZE = `CX_CXL_MEM_M2S_DATA_SIZE ; 
  localparam M2S_68B_DATA_SIZE             = `CX_CXL_MEM_68B_M2S_DATA_SIZE ; 
  localparam M2S_HBR_DATA_SIZE             = `CX_CXL_MEM_HBR_M2S_DATA_SIZE ; 
  localparam M2S_PBR_DATA_SIZE             = `CX_CXL_MEM_PBR_M2S_DATA_SIZE ; 
  localparam M2S_256B_DATA_SIZE            = `CX_CXL_MEM_256B_M2S_DATA_SIZE ; 
                                                 
  localparam M2S_DHDR_SIZE = `CX_CXL_MEM_M2S_DHDR_SIZE ; 
  localparam M2S_68B_DHDR_SIZE             = `CX_CXL_MEM_68B_M2S_DHDR_SIZE ; 
  localparam M2S_HBR_DHDR_SIZE             = `CX_CXL_MEM_HBR_M2S_DHDR_SIZE ; 
  localparam M2S_PBR_DHDR_SIZE             = `CX_CXL_MEM_PBR_M2S_DHDR_SIZE ; 
  localparam M2S_256B_DHDR_SIZE            = `CX_CXL_MEM_256B_M2S_DHDR_SIZE ; 
                                                    
  localparam M2S_DDATA_SIZE= `CX_CXL_MEM_M2S_DDATA_SIZE; 
  localparam M2S_68B_DDATA_SIZE            = `CX_CXL_MEM_68B_M2S_DDATA_SIZE; 
  localparam M2S_HBR_DDATA_SIZE            = `CX_CXL_MEM_HBR_M2S_DDATA_SIZE; 
  localparam M2S_PBR_DDATA_SIZE            = `CX_CXL_MEM_PBR_M2S_DDATA_SIZE; 
  localparam M2S_256B_DDATA_SIZE           = `CX_CXL_MEM_256B_M2S_DDATA_SIZE; 
                                                    
  localparam M2S_DBE_SIZE  = `CX_CXL_MEM_M2S_DBE_SIZE  ; 
  localparam M2S_68B_DBE_SIZE              = `CX_CXL_MEM_68B_M2S_DBE_SIZE  ; 
  localparam M2S_HBR_DBE_SIZE              = `CX_CXL_MEM_HBR_M2S_DBE_SIZE  ; 
  localparam M2S_PBR_DBE_SIZE              = `CX_CXL_MEM_PBR_M2S_DBE_SIZE  ; 
  localparam M2S_256B_DBE_SIZE             = `CX_CXL_MEM_256B_M2S_DBE_SIZE  ; 
                                                 
  localparam M2S_BI_RSP_SIZE   = `CX_CXL_MEM_M2S_BI_RSP_SIZE   ;
  localparam M2S_68B_BI_RSP_SIZE           = `CX_CXL_MEM_68B_M2S_BI_RSP_SIZE   ;
  localparam M2S_HBR_BI_RSP_SIZE           = `CX_CXL_MEM_HBR_M2S_BI_RSP_SIZE   ;
  localparam M2S_PBR_BI_RSP_SIZE           = `CX_CXL_MEM_PBR_M2S_BI_RSP_SIZE   ;
  localparam M2S_256B_BI_RSP_SIZE          = `CX_CXL_MEM_256B_M2S_BI_RSP_SIZE   ;

  localparam DL_ERR_INJ_EN_WD           =  20;
  localparam DL_ERR_INJ_MASK_WD         =  `CX_CXL_RAS_RX_ERR_INJ_MASK_WD;

  localparam CX_CXL_RX_DL_ERR_INJ_EN_WD = `CX_CXL_RAS_RX_DL_ERR_INJ_EN_WD;
  localparam CX_CXL_RX_TL_ERR_INJ_EN_WD = `CX_CXL_RAS_RX_TL_ERR_INJ_EN_WD;
  localparam CX_CXL_RX_ERR_INJ_EN_WD    = `CX_CXL_RAS_RX_ERR_INJ_EN_WD;
  localparam CX_CXL_RX_ERR_INJ_MASK_WD  = `CX_CXL_RAS_RX_ERR_INJ_MASK_WD;
  localparam CX_CXL_RX_TL_PTR_ERR_WD    = 1;
  localparam CX_CXL_RX_TL_VALID_ERR_WD  = 6;

  localparam M2S_NDR_CHK_SIZE   = `CX_CXL_MEM_M2S_NDR_CHK_SIZE  ; 
  localparam M2S_DHDR_CHK_SIZE  = `CX_CXL_MEM_M2S_DHDR_CHK_SIZE ;
  localparam M2S_DBE_CHK_SIZE   = `CX_CXL_MEM_M2S_DBE_CHK_SIZE  ;
  localparam M2S_DDATA_CHK_SIZE = `CX_CXL_MEM_M2S_DDATA_CHK_SIZE;
  localparam M2S_DATA_CHK_SIZE  = `CX_CXL_MEM_M2S_DATA_CHK_SIZE ;
  localparam M2S_BI_RSP_CHK_SIZE    = `CX_CXL_MEM_M2S_BI_RSP_CHK_SIZE   ;
  localparam M2S_NDR_FUNC_DATAW      = M2S_NDR_SIZE;
  localparam M2S_DATA_FUNC_DATAW     = M2S_DATA_SIZE;
  localparam M2S_NDR_RX_CH_SIZE    = M2S_NDR_SIZE + M2S_NDR_CHK_SIZE;
  localparam M2S_DATA_RX_CH_SIZE   = M2S_DATA_SIZE + M2S_DATA_CHK_SIZE;
  localparam M2S_DHDR_RX_CH_SIZE   = M2S_DHDR_SIZE + M2S_DHDR_CHK_SIZE;
  localparam M2S_DBE_RX_CH_SIZE    = M2S_DBE_SIZE + M2S_DBE_CHK_SIZE;
  localparam M2S_DDATA_RX_CH_SIZE  = M2S_DDATA_SIZE + M2S_DDATA_CHK_SIZE;
  localparam M2S_BI_RSP_RX_CH_SIZE     = M2S_BI_RSP_SIZE + M2S_BI_RSP_CHK_SIZE;

  // Maximum number of M2S messages
  localparam M2S_NDR_NUM  = `CX_CXL_MEM_M2S_NDR_NUM  ; 
  localparam M2S_68B_NDR_NUM               = `CX_CXL_MEM_68B_M2S_NDR_NUM  ; 
  localparam M2S_256B_NDR_NUM              = `CX_CXL_MEM_256B_M2S_NDR_NUM  ; 
      
  localparam M2S_DDATA_NUM                 = `CX_CXL_MEM_M2S_DDATA_NUM ; 
  localparam M2S_68B_DDATA_NUM             = `CX_CXL_MEM_68B_M2S_DDATA_NUM ; 
  localparam M2S_256B_DDATA_NUM            = `CX_CXL_MEM_256B_M2S_DDATA_NUM ;  
  
  localparam M2S_DATA_NUM = `CX_CXL_MEM_M2S_DATA_NUM ; 
  localparam M2S_68B_DATA_NUM              = `CX_CXL_MEM_68B_M2S_DATA_NUM ; 
  localparam M2S_256B_DATA_NUM             = `CX_CXL_MEM_256B_M2S_DATA_NUM ; 
  
  localparam M2S_BI_RSP_NUM   = `CX_CXL_MEM_M2S_BI_RSP_NUM   ;
  localparam M2S_68B_BI_RSP_NUM            = `CX_CXL_MEM_68B_M2S_BI_RSP_NUM   ;
  localparam M2S_256B_BI_RSP_NUM           = `CX_CXL_MEM_256B_M2S_BI_RSP_NUM   ;
  
  // Maximum number of M2S channel message interfaces
  localparam M2S_NDR_IFNUM  = `CX_CXL_MEM_M2S_NDR_IFNUM  ; 
  localparam M2S_DATA_IFNUM = `CX_CXL_MEM_M2S_DATA_IFNUM ; 
  localparam M2S_BI_RSP_IFNUM   = `CX_CXL_MEM_M2S_BI_RSP_IFNUM   ;

  //`endif
  //`ifdef CX_CXL_DOWNSTREAM_PORT
  localparam S2M_NDR_DEVLOAD_WD = 2;
  
  localparam S2M_NDR_SIZE  = `CX_CXL_MEM_S2M_NDR_SIZE  ; 
  localparam S2M_68B_NDR_SIZE              = `CX_CXL_MEM_68B_S2M_NDR_SIZE  ;
  localparam S2M_HBR_NDR_SIZE              = `CX_CXL_MEM_HBR_S2M_NDR_SIZE  ;
  localparam S2M_PBR_NDR_SIZE              = `CX_CXL_MEM_PBR_S2M_NDR_SIZE  ;
  localparam S2M_256B_NDR_SIZE             = `CX_CXL_MEM_256B_S2M_NDR_SIZE  ;
  
  localparam S2M_DATA_SIZE = `CX_CXL_MEM_S2M_DATA_SIZE ; 
  localparam S2M_68B_DATA_SIZE             = `CX_CXL_MEM_68B_S2M_DATA_SIZE ;
  localparam S2M_HBR_DATA_SIZE             = `CX_CXL_MEM_HBR_S2M_DATA_SIZE ;
  localparam S2M_PBR_DATA_SIZE             = `CX_CXL_MEM_PBR_S2M_DATA_SIZE ;
  localparam S2M_256B_DATA_SIZE            = `CX_CXL_MEM_256B_S2M_DATA_SIZE ;
                                           
  localparam S2M_DHDR_SIZE = `CX_CXL_MEM_S2M_DHDR_SIZE ; 
  localparam S2M_68B_DHDR_SIZE             = `CX_CXL_MEM_68B_S2M_DHDR_SIZE ; 
  localparam S2M_HBR_DHDR_SIZE             = `CX_CXL_MEM_HBR_S2M_DHDR_SIZE ; 
  localparam S2M_PBR_DHDR_SIZE             = `CX_CXL_MEM_PBR_S2M_DHDR_SIZE ; 
  localparam S2M_256B_DHDR_SIZE            = `CX_CXL_MEM_256B_S2M_DHDR_SIZE ; 
  
  localparam S2M_DDATA_SIZE= `CX_CXL_MEM_S2M_DDATA_SIZE; 
  localparam S2M_68B_DDATA_SIZE            = `CX_CXL_MEM_68B_S2M_DDATA_SIZE; 
  localparam S2M_HBR_DDATA_SIZE            = `CX_CXL_MEM_HBR_S2M_DDATA_SIZE; 
  localparam S2M_PBR_DDATA_SIZE            = `CX_CXL_MEM_PBR_S2M_DDATA_SIZE; 
  localparam S2M_256B_DDATA_SIZE           = `CX_CXL_MEM_256B_S2M_DDATA_SIZE; 
  
  localparam S2M_BI_SNP_SIZE   = `CX_CXL_MEM_S2M_BI_SNP_SIZE   ;
  localparam S2M_68B_BI_SNP_SIZE           = `CX_CXL_MEM_68B_S2M_BI_SNP_SIZE   ;
  localparam S2M_HBR_BI_SNP_SIZE           = `CX_CXL_MEM_HBR_S2M_BI_SNP_SIZE   ;
  localparam S2M_PBR_BI_SNP_SIZE           = `CX_CXL_MEM_PBR_S2M_BI_SNP_SIZE   ;
  localparam S2M_256B_BI_SNP_SIZE          = `CX_CXL_MEM_256B_S2M_BI_SNP_SIZE   ;
  
  localparam S2M_NDR_CHK_SIZE   = `CX_CXL_MEM_S2M_NDR_CHK_SIZE  ; 
  localparam S2M_DHDR_CHK_SIZE  = `CX_CXL_MEM_S2M_DHDR_CHK_SIZE ;
  localparam S2M_DDATA_CHK_SIZE = `CX_CXL_MEM_S2M_DDATA_CHK_SIZE;
  localparam S2M_DATA_CHK_SIZE  = `CX_CXL_MEM_S2M_DATA_CHK_SIZE ;
  localparam S2M_BI_SNP_CHK_SIZE    = `CX_CXL_MEM_S2M_BI_SNP_CHK_SIZE   ;
  localparam S2M_NDR_FUNC_DATAW    = S2M_NDR_SIZE;
  localparam S2M_DATA_FUNC_DATAW   = S2M_DATA_SIZE;
  localparam S2M_NDR_RX_CH_SIZE    = S2M_NDR_SIZE + S2M_NDR_CHK_SIZE;
  localparam S2M_DATA_RX_CH_SIZE   = S2M_DATA_SIZE + S2M_DATA_CHK_SIZE;
  localparam S2M_DHDR_RX_CH_SIZE   = S2M_DHDR_SIZE + S2M_DHDR_CHK_SIZE;
  localparam S2M_DDATA_RX_CH_SIZE  = S2M_DDATA_SIZE + S2M_DDATA_CHK_SIZE;
  localparam S2M_BI_SNP_RX_CH_SIZE     = S2M_BI_SNP_SIZE + S2M_BI_SNP_CHK_SIZE;

  // Maximum number of S2M messages
  localparam S2M_NDR_NUM  = `CX_CXL_MEM_S2M_NDR_NUM  ; 
  localparam S2M_68B_NDR_NUM               = `CX_CXL_MEM_68B_S2M_NDR_NUM  ; 
  localparam S2M_256B_NDR_NUM              = `CX_CXL_MEM_256B_S2M_NDR_NUM  ; 
  
  localparam S2M_DATA_NUM = `CX_CXL_MEM_S2M_DATA_NUM ; 
  localparam S2M_68B_DATA_NUM              = `CX_CXL_MEM_68B_S2M_DATA_NUM ; 
  localparam S2M_256B_DATA_NUM             = `CX_CXL_MEM_256B_S2M_DATA_NUM ; 
  
  localparam S2M_DDATA_NUM                  = `CX_CXL_MEM_S2M_DDATA_NUM ; 
  localparam S2M_68B_DDATA_NUM              = `CX_CXL_MEM_68B_S2M_DDATA_NUM ; 
  localparam S2M_256B_DDATA_NUM             = `CX_CXL_MEM_256B_S2M_DDATA_NUM ; 
  
  localparam S2M_BI_SNP_NUM   = `CX_CXL_MEM_S2M_BI_SNP_NUM   ;
  localparam S2M_68B_BI_SNP_NUM            = `CX_CXL_MEM_68B_S2M_BI_SNP_NUM   ;
  localparam S2M_256B_BI_SNP_NUM           = `CX_CXL_MEM_256B_S2M_BI_SNP_NUM   ;
  
  // Number of S2M channel message interfaces
  localparam S2M_NDR_IFNUM  = `CX_CXL_MEM_S2M_NDR_IFNUM  ; 
  localparam S2M_DATA_IFNUM = `CX_CXL_MEM_S2M_DATA_IFNUM ;
  localparam S2M_BI_SNP_IFNUM   = `CX_CXL_MEM_S2M_BI_SNP_IFNUM   ; 
  //`endif

  localparam MS_BI_NUM = `CX_CXL_MST_MS_BI_RAM_NUM ;

  localparam CXL_CHI_MAXCREDITS = `CX_CXL_CHI_MAXCREDITS;

  localparam H2D_REQ_VLD  = 0;
  localparam H2D_RESP_VLD = 0;
  localparam H2D_HDR_VLD  = 0;
  localparam H2D_DATA_VLD = 0;
  localparam M2S_NDR_VLD  = 0;
  localparam M2S_HDR_VLD  = 0;
  localparam M2S_DATA_VLD = 0;
  localparam M2S_BI_RSP_VLD   = 0;
  localparam D2H_REQ_VLD  = 0;
  localparam D2H_RESP_VLD = 0;
  localparam D2H_HDR_VLD  = 0;
  localparam D2H_DATA_VLD = 0;
  localparam S2M_NDR_VLD  = 0;
  localparam S2M_HDR_VLD  = 0;
  localparam S2M_DATA_VLD = 0;
  localparam S2M_BI_SNP_VLD   = 0;

       localparam HREQ_DRSP_NUM            = `CX_CXL_MST_HD_REQ_RESP_RAM_NUM;
       localparam HRSP_DREQ_NUM            = `CX_CXL_MST_HD_RESP_REQ_RAM_NUM;
       localparam HD_DDATA_NUM             = `CX_CXL_MST_HD_DDATA_RAM_NUM   ;
       localparam HREQ_DRSP_RX_RAM_ADDRW  = `CX_CXL_MST_HREQ_DRESP_RAM_ADDRW;
       localparam HREQ_DRSP_RX_RAM_DATAW  = `CX_CXL_MST_HREQ_DRESP_RAM_DATAW;
       localparam HRSP_DREQ_RX_RAM_ADDRW  = `CX_CXL_MST_HRESP_DREQ_RAM_ADDRW;
       localparam HRSP_DREQ_RX_RAM_DATAW  = `CX_CXL_MST_HRESP_DREQ_RAM_DATAW;
       localparam HD_DATA_RX_RAM_ADDRW    = `CX_CXL_MST_HD_DATA_RAM_ADDRW   ;
       localparam HD_DATA_RX_RAM_DATAW    = `CX_CXL_MST_HD_DATA_RAM_DATAW   ;

       localparam H2D_REQ_RAM_ADDRW       = `CX_CXL_MST_H2D_REQ_RAM_ADDRW   ;
       localparam H2D_REQ_RAM_DATAW       = `CX_CXL_MST_H2D_REQ_RAM_DATAW   ;
       localparam H2D_RSP_RAM_ADDRW       = `CX_CXL_MST_H2D_RESP_RAM_ADDRW  ;
       localparam H2D_RSP_RAM_DATAW       = `CX_CXL_MST_H2D_RESP_RAM_DATAW  ;
       localparam H2D_DATA_RAM_ADDRW      = `CX_CXL_MST_H2D_DATA_RAM_ADDRW  ;
       localparam H2D_DATA_RAM_DATAW      = `CX_CXL_MST_H2D_DATA_RAM_DATAW  ;

       localparam D2H_REQ_RAM_ADDRW       = `CX_CXL_MST_D2H_REQ_RAM_ADDRW   ;
       localparam D2H_REQ_RAM_DATAW       = `CX_CXL_MST_D2H_REQ_RAM_DATAW   ;
       localparam D2H_RSP_RAM_ADDRW       = `CX_CXL_MST_D2H_RESP_RAM_ADDRW  ;
       localparam D2H_RSP_RAM_DATAW       = `CX_CXL_MST_D2H_RESP_RAM_DATAW  ;
       localparam D2H_DATA_RAM_ADDRW      = `CX_CXL_MST_D2H_DATA_RAM_ADDRW  ;
       localparam D2H_DATA_RAM_DATAW      = `CX_CXL_MST_D2H_DATA_RAM_DATAW  ;
       localparam MS_SM_NDR_NUM           = `CX_CXL_MST_MS_NDR_RAM_NUM      ;
       localparam MS_NDR_NUM              =  MS_SM_NDR_NUM                  ;
       localparam MS_SM_DDATA_NUM         = `CX_CXL_MST_MS_DDATA_RAM_NUM    ;
       localparam MS_NDR_RX_RAM_ADDRW  = `CX_CXL_MST_MS_NDR_RAM_ADDRW   ;
       localparam MS_NDR_RX_RAM_DATAW  = `CX_CXL_MST_MS_NDR_RAM_DATAW   ;
       localparam MS_DATA_RX_RAM_ADDRW = `CX_CXL_MST_MS_DATA_RAM_ADDRW  ;
       localparam MS_DATA_RX_RAM_DATAW = `CX_CXL_MST_MS_DATA_RAM_DATAW  ;
       localparam MS_BI_RX_RAM_ADDRW   = `CX_CXL_MST_MS_BI_RAM_ADDRW    ;
       localparam MS_BI_RX_RAM_DATAW   = `CX_CXL_MST_MS_BI_RAM_DATAW    ;

       localparam M2S_NDR_RAM_ADDRW    = `CX_CXL_MST_M2S_REQ_RAM_ADDRW  ;
       localparam M2S_NDR_RAM_DATAW    = `CX_CXL_MST_M2S_REQ_RAM_DATAW  ;
       localparam M2S_DATA_RAM_ADDRW   = `CX_CXL_MST_M2S_DATA_RAM_ADDRW ;
       localparam M2S_DATA_RAM_DATAW   = `CX_CXL_MST_M2S_DATA_RAM_DATAW ;
       localparam M2S_BI_RSP_RAM_ADDRW     = `CX_CXL_MST_M2S_BI_RSP_RAM_ADDRW   ;
       localparam M2S_BI_RSP_RAM_DATAW     = `CX_CXL_MST_M2S_BI_RSP_RAM_DATAW   ;

       localparam S2M_NDR_RAM_ADDRW    = `CX_CXL_MST_S2M_RSP_RAM_ADDRW  ;
       localparam S2M_NDR_RAM_DATAW    = `CX_CXL_MST_S2M_RSP_RAM_DATAW  ;
       localparam S2M_DATA_RAM_ADDRW   = `CX_CXL_MST_S2M_DATA_RAM_ADDRW ;
       localparam S2M_DATA_RAM_DATAW   = `CX_CXL_MST_S2M_DATA_RAM_DATAW ;
       localparam S2M_BI_SNP_RAM_ADDRW     = `CX_CXL_MST_S2M_BI_SNP_RAM_ADDRW   ;
       localparam S2M_BI_SNP_RAM_DATAW     = `CX_CXL_MST_S2M_BI_SNP_RAM_DATAW   ;
       localparam HD_DATAW                 = `CX_CXL_SLV_HD_DATAW           ;
       localparam HD_DDATA_SIZE            = `CX_CXL_SLV_HD_DDATA_SIZE      ;
       localparam HD_DDATA_CHK_SIZE        = `CX_CXL_SLV_HD_DDATA_CHK_SIZE  ;
       localparam HD_RAM_DDATA_CHK_SIZE    = `CX_CXL_SLV_HD_RAM_DDATA_CHK_SIZE;
       localparam HD_DATA_RAM_ADDRW = `CX_CXL_SLV_HD_DATA_RAM_ADDRW  ;
       localparam HD_DATA_RAM_DATAW = `CX_CXL_SLV_HD_DATA_RAM_DATAW  ;
       localparam HD_DATA_RAM_DEPTH = `CX_CXL_SLV_HD_DATA_RAM_DEPTH  ;
       localparam MS_DATAW                 = `CX_CXL_SLV_MS_DATAW           ;
       localparam MS_DDATA_SIZE            = `CX_CXL_SLV_MS_DDATA_SIZE      ;
       localparam MS_DDATA_CHK_SIZE        = `CX_CXL_SLV_MS_DDATA_CHK_SIZE  ;
       localparam MS_RAM_DDATA_CHK_SIZE    = `CX_CXL_SLV_MS_RAM_DDATA_CHK_SIZE;
       localparam MS_DATA_RAM_ADDRW = `CX_CXL_SLV_MS_DATA_RAM_ADDRW  ;
       localparam MS_DATA_RAM_DATAW = `CX_CXL_SLV_MS_DATA_RAM_DATAW  ;
       localparam MS_DATA_RAM_DEPTH = `CX_CXL_SLV_MS_DATA_RAM_DEPTH  ;

//Poison Bit Location In Data Header 68_Byte Flit Mode 
  localparam H2D_68B_POISON_BIT  = 14;
  localparam D2H_68B_POISON_BIT  = 15;
  localparam M2S_68B_POISON_BIT  = 74;
  localparam S2M_68B_POISON_BIT  = 24;
//Poison Bit Location In Data Header 256_Byte Flit Mode
  localparam H2D_256B_POISON_BIT  = 13;
  localparam D2H_256B_POISON_BIT  = 14;
  localparam M2S_256B_POISON_BIT  = 74;
  localparam S2M_256B_POISON_BIT  = 24;

localparam M2S_OPCODE_LSB  = 1;
localparam M2S_OPCODE_MSB  = 4;
localparam M2S_BI_CONFLICT = 4'b0100;

localparam CXL_RAS_PARITY_MODE      = `CX_RAS_PARITY_MODE;

localparam CXL_RBUF_ERROR_INJ_EN    = `CX_CXL_RAS_RBUF_ERR_INJ_EN_WD;
localparam CXL_RBUF_ERROR_INJ_MASK  = `CX_CXL_RAS_RBUF_ERR_INJ_MASK_WD;

localparam CXL_RAS_TX_TL_ERR_INJ_EN    = `CX_CXL_RAS_TX_TL_ERR_INJ_EN_WD;
localparam CXL_RAS_TX_TL_ERR_INJ_MASK  = `CX_CXL_RAS_TX_TL_ERR_INJ_MASK_WD;

localparam CXL_RAS_TX_ERR_INJ_EN    = `CX_CXL_RAS_TX_ERR_INJ_EN_WD;
localparam CXL_RAS_TX_ERR_INJ_MASK  = `CX_CXL_RAS_TX_ERR_INJ_MASK_WD;

localparam CXL_RAS_ERR_INJ_EN       = `CX_CXL_RAS_ERR_INJ_EN_WD;
localparam CXL_RAS_ERR_INJ_MASK     = `CX_CXL_RAS_ERR_INJ_MASK_WD;
localparam CXL_SYNC_STAGES          = `CX_PCIE_SYNC_DEPTH;

localparam CXL_RAS_HDR_LOG_SIZE     = `CX_CXL_RAS_HDR_LOG_SIZE;

// RASDP number of uncorrectable error signals
localparam CXL_TX_TL_RAS_UNCORR_NUM            = 7;
localparam CXL_RBUF_RAS_UNCORR_NUM             = 1;
localparam CXL_LINK_IDE_RAS_UNCORR_NUM         = 0;
localparam CXL_TX_LL_RAS_UNCORR_NUM            = CXL_RBUF_RAS_UNCORR_NUM + CXL_LINK_IDE_RAS_UNCORR_NUM;
localparam CXL_TX_RAS_UNCORR_NUM               = CXL_TX_LL_RAS_UNCORR_NUM + CXL_TX_TL_RAS_UNCORR_NUM;
localparam CXL_UNPACKER_RAS_UNCORR_NUM         = 1;
localparam CXL_ULL_FDEC_RAS_UNCORR_NUM         = 0;
localparam CXL_RXLINK_CTRL_RAS_UNCORR_NUM      = 2;
localparam CXL_RX_LL_RAS_UNCORR_NUM            = CXL_UNPACKER_RAS_UNCORR_NUM + CXL_RXLINK_CTRL_RAS_UNCORR_NUM;
localparam CXL_RX_CORE_RAS_UNCORR_NUM          = CXL_RX_LL_RAS_UNCORR_NUM;
localparam CXL_RX_RAS_UNCORR_NUM               = CXL_RX_CORE_RAS_UNCORR_NUM;
localparam CXL_RAS_UNCORR_NUM                  = CXL_TX_RAS_UNCORR_NUM + CXL_RX_RAS_UNCORR_NUM + CXL_ULL_FDEC_RAS_UNCORR_NUM;

localparam CXL_RAS_COUNTERS                    = CXL_RAS_UNCORR_NUM;

// RASDP Checker Instances ID Indexing
localparam CXL_TX_H2D_REQ_RAS_ID_INDEX         = 0;
localparam CXL_TX_H2D_RESP_RAS_ID_INDEX        = CXL_TX_H2D_REQ_RAS_ID_INDEX + H2D_REQ_NUM;
localparam CXL_TX_H2D_HDR_RAS_ID_INDEX         = CXL_TX_H2D_RESP_RAS_ID_INDEX + H2D_RESP_NUM;
localparam CXL_TX_H2D_DATA_RAS_ID_INDEX        = CXL_TX_H2D_HDR_RAS_ID_INDEX + H2D_DATA_NUM;
localparam CXL_TX_M2S_NDR_RAS_ID_INDEX         = CXL_TX_H2D_DATA_RAS_ID_INDEX + H2D_DATA_NUM;
localparam CXL_TX_M2S_HDR_RAS_ID_INDEX         = CXL_TX_M2S_NDR_RAS_ID_INDEX + M2S_NDR_NUM;
localparam CXL_TX_M2S_BE_RAS_ID_INDEX          = CXL_TX_M2S_HDR_RAS_ID_INDEX + M2S_DATA_NUM;
localparam CXL_TX_M2S_DATA_RAS_ID_INDEX        = CXL_TX_M2S_BE_RAS_ID_INDEX + M2S_DATA_NUM;
localparam CXL_TX_S2M_NDR_RAS_ID_INDEX         = CXL_TX_M2S_DATA_RAS_ID_INDEX + M2S_DATA_NUM;
localparam CXL_TX_S2M_HDR_RAS_ID_INDEX         = CXL_TX_S2M_NDR_RAS_ID_INDEX + S2M_NDR_NUM;
localparam CXL_TX_S2M_DATA_RAS_ID_INDEX        = CXL_TX_S2M_HDR_RAS_ID_INDEX + S2M_DATA_NUM;
localparam CXL_TX_D2H_REQ_RAS_ID_INDEX         = CXL_TX_S2M_DATA_RAS_ID_INDEX + S2M_DATA_NUM;
localparam CXL_TX_D2H_RESP_RAS_ID_INDEX        = CXL_TX_D2H_REQ_RAS_ID_INDEX + D2H_REQ_NUM;
localparam CXL_TX_D2H_HDR_RAS_ID_INDEX         = CXL_TX_D2H_RESP_RAS_ID_INDEX + D2H_RESP_NUM;
localparam CXL_TX_D2H_BE_RAS_ID_INDEX          = CXL_TX_D2H_HDR_RAS_ID_INDEX + D2H_DATA_NUM;
localparam CXL_TX_D2H_DATA_RAS_ID_INDEX        = CXL_TX_D2H_BE_RAS_ID_INDEX + D2H_DATA_NUM;
localparam CXL_TX_S2M_BI_SNP_RAS_ID_INDEX      = CXL_TX_D2H_DATA_RAS_ID_INDEX + D2H_DATA_NUM;
localparam CXL_TX_M2S_BI_RSP_RAS_ID_INDEX      = CXL_TX_S2M_BI_SNP_RAS_ID_INDEX + S2M_BI_SNP_NUM;
localparam CXL_TX_LINK_IDE_RAS_ID_INDEX        = CXL_TX_M2S_BI_RSP_RAS_ID_INDEX + M2S_BI_RSP_NUM;
localparam CXL_TX_RBUF_RAM_RDATA_RAS_ID_INDEX  = CXL_TX_LINK_IDE_RAS_ID_INDEX + 1;
localparam CXL_RX_LINK_CTRL_RAS_ID_INDEX       = CXL_TX_RBUF_RAM_RDATA_RAS_ID_INDEX + 1;
localparam CXL_RX_UNPACKER_RAS_ID_INDEX        = CXL_RX_LINK_CTRL_RAS_ID_INDEX + 2;
localparam CXL_RX_ULL_FDEC_RAS_ID_INDEX        = CXL_RX_UNPACKER_RAS_ID_INDEX + 1;
// New Index = CXL_RX_ULL_FDEC_RAS_ID_INDEX + 1

// FIFO DEPTH + OFFLOAD_REG_SIZE + OUTPUT_REG
// + CXL TX TL REGOUT (If TL REGOUT exists) + CXL TX TL RASDP REGOUT (If RASDP REGOUT exists)
localparam H2D_MSG_CNT_WD = $clog2(CXL_CHI_MAXCREDITS + 2*H2D_RESP_NUM + 1

 + H2D_RESP_NUM) + 1;
localparam M2S_MSG_CNT_WD = $clog2(CXL_CHI_MAXCREDITS + 2*M2S_DATA_NUM + 1) + 1;

localparam CXL_IDE_DATA_WIDTH = `CX_CXL_IDE_DATA_WIDTH;
localparam CXL_IDE_RX_FLIT_PRED_LATENCY = 0;

localparam CXL_MAX_CORECLK_FREQ         = `CX_MAX_CORECLK_FREQ;

// 1us retry timeout for Request(L1) ALMP
localparam CXL_ALMP_L1REQ_TIMEOUT_VALUE = (1000*(1000_000/CXL_MAX_CORECLK_FREQ)) / 1000; // 1000*(1000_000/CXL_MAX_CORECLK_FREQ[Mhz]) / 1000 = 1000 *1ns(1000ps)
localparam CXL_ALMP_L1REQ_TIMEOUT_WIDTH = $clog2(CXL_ALMP_L1REQ_TIMEOUT_VALUE);

// 1us interval between electrical idle requests to LTSSM
localparam CXL_EIDLE_1US_TIMEOUT_VALUE  = (1000*(1000_000/CXL_MAX_CORECLK_FREQ)) / 1000;
localparam CXL_EIDLE_1US_TIMEOUT_WIDTH  = $clog2(CXL_EIDLE_1US_TIMEOUT_VALUE);


// -------------------------------------------------------------------------------------
// CXL Flit Header Format
// -------------------------------------------------------------------------------------
// Type    (1 bit ) - This field distinguishes between a Protocol or a Control Flit
// Ack     (1 bit ) - This is an acknowledgment of 8 successful flit transfers
// BE      (1 bit ) - Byte Enable
// Sz      (1 bit ) - Size 1
// ReqCrd  (4 bits) - Request Credit Return
// DataCrd (4 bits) - Data Credit Return
// RspCrd  (4 bits) - Response Credit Return
// Slot0   (3 bits) - Slot 0 Format Type
// Slot1   (3 bits) - Slot 1 Format Type
// Slot2   (3 bits) - Slot 2 Format Type
// Slot3   (3 bits) - Slot 3 Format Type
// RSVD    (4 bits) - Reserved

typedef enum logic {
   CXL_HDR_PROT = 1'b0, // This is a flit that carries CXL.cache or CXL.mem protocol related information
   CXL_HDR_CTRL = 1'b1  // This is a flit inserted by the link layer purely for link layer specific
                        // functionality. These flits are not exposed to the upper layers.
} CXL_HDR_TYPE_t;

typedef enum logic [2:0] {
    CXL_HDR_SLOT_H0 = 3'b000,
    CXL_HDR_SLOT_H1 = 3'b001,
    CXL_HDR_SLOT_H2 = 3'b010,
    CXL_HDR_SLOT_H3 = 3'b011,
    CXL_HDR_SLOT_H4 = 3'b100,
    CXL_HDR_SLOT_H5 = 3'b101,
    CXL_HDR_SLOT_H6 = 3'b110,
    CXL_HDR_SLOT_H7 = 3'b111
} CXL_HDR_SLOT_0_t;

typedef enum logic [2:0] {
    CXL_HDR_SLOT_G0 = 3'b000,
    CXL_HDR_SLOT_G1 = 3'b001,
    CXL_HDR_SLOT_G2 = 3'b010,
    CXL_HDR_SLOT_G3 = 3'b011,
    CXL_HDR_SLOT_G4 = 3'b100,
    CXL_HDR_SLOT_G5 = 3'b101,
    CXL_HDR_SLOT_G6 = 3'b110,
    CXL_HDR_SLOT_G7 = 3'b111
} CXL_HDR_SLOT_N_t;

typedef struct packed {
    logic [3:0]       DataCrd;
    logic [3:0]       ReqCrd;
    logic [3:0]       RspCrd;
    logic             RevCrd;
    logic [1:0]       RSVD_BIT17_18;
    CXL_HDR_SLOT_N_t  Slot3;
    CXL_HDR_SLOT_N_t  Slot2;
    CXL_HDR_SLOT_N_t  Slot1;
    CXL_HDR_SLOT_0_t  Slot0;
    logic             Sz;
    logic             BE;
    logic             Ack;
    logic             ProtRev;
    CXL_HDR_TYPE_t    ProtType;
} CXL_HDR_t;

typedef struct packed {
    logic [3:0]   Slot3;
    logic [3:0]   Slot2;
    logic [3:0]   Slot1;
    logic [3:0]   Slot0;
} SLOT_DATA_HDR_t;

typedef struct packed {
    logic            Valid;
    logic [3:0]      Data;
    logic [127:0]    Slot;
} SLOT_0_DESCR_t;

typedef struct packed {
    logic            Valid;
    logic [3:0]      Data;
    logic [127:0]    Slot;
} SLOT_N_DESCR_t;

typedef struct packed {
    SLOT_0_DESCR_t     Slot0;
    SLOT_N_DESCR_t     Slot1;
    SLOT_N_DESCR_t     Slot2;
    SLOT_N_DESCR_t     Slot3;
} SLOT_HDR_t;
// -------------------------------------------------------------------------------------

localparam N_DEVICES = 1;

// 256B Flit 2B Credit Return Struct
typedef struct packed {
    logic            RSVD;
    logic [4:0]      CRD_C;
    logic [4:0]      CRD_B;
    logic [4:0]      CRD_A;
} CRD_256B_t;


// ARB/MUX flit data width for 68B Flit Format
localparam ARBMUX_68B_DATA_WD  = `CX_ARBMUX_68B_DATA_WIDTH ;
localparam ARBMUX_68B_DATA_PROT_WD = ARBMUX_68B_DATA_WD/8 ;
// ARB/MUX flit data width for 256B Flit Format
localparam ARBMUX_256B_DATA_WD = `CX_ARBMUX_256B_DATA_WIDTH ;
// ARB/MUX flit data width
localparam ARBMUX_DATA_WD      = `CX_ARBMUX_DATA_WIDTH ;
// ARB/MUX flit data protection width
localparam ARBMUX_DATA_PROT_WD = ARBMUX_DATA_WD/8 ;

// ARB/MUX input interface width for 68B Flit Format (ARBMUX_68B_DATA_WD + 16-bit CRC)
localparam ARBMUX_68B_FLIT_WD  = `CX_ARBMUX_68B_FLIT_WIDTH ;
localparam ARBMUX_68B_FLIT_PROT_WD = ARBMUX_68B_FLIT_WD/8;
// ARB/MUX input interface width for 256B Flit Format (same as ARBMUX_256B_DATA_WD)
localparam ARBMUX_256B_FLIT_WD = `CX_ARBMUX_256B_FLIT_WIDTH ;
// ARB/MUX input interface width from the Controller/vLSM/IO
localparam ARBMUX_FLIT_WD      = `CX_ARBMUX_FLIT_WIDTH ;
localparam ARBMUX_FLIT_PROT_WD = `CX_ARBMUX_FLIT_PROT_WIDTH;
localparam ARBMUX_FLIT_IF_WD   = `CX_ARBMUX_FLIT_IF_WIDTH;

// ARB/MUX serializer interface width for 68B Flit Format
localparam ARBMUX_68B_XPLH_WD  = `CX_ARBMUX_68B_XPLH_WIDTH ;
// ARBMUX_68B_XPLH_WD + 16-bit PID
localparam ARBMUX_68B_PID_XPLH_WD  = `CX_ARBMUX_68B_XPLH_WIDTH + 16 ;
// ARB/MUX serializer interface width to XPLH for 256B Flit Format
localparam ARBMUX_256B_XPLH_WD = `CX_ARBMUX_256B_XPLH_WIDTH ;
// ARB/MUX serializer interface width
localparam ARBMUX_XPLH_WD      = `CX_ARBMUX_XPLH_WIDTH ;
localparam ARBMUX_XPLH_PROT_WD = `CX_ARBMUX_XPLH_PROT_WIDTH;
localparam ARBMUX_XPLH_IF_WD   = `CX_ARBMUX_XPLH_IF_WIDTH ;

// Flit IF FIFO width
localparam FLIT_IF_FIFO_WD      = ARBMUX_FLIT_WD + 7 + CXL_DATA_PROT_WD;
// Flit IF FIFO DEPTH
localparam FLIT_IF_FIFO_DEPTH   = `CX_CXL_FLIT_IF_FIFO_DEPTH;
// Flit IF FIFO Address width
localparam FLIT_IF_FIFO_LOG2    = $clog2(FLIT_IF_FIFO_DEPTH);
// Flit IF FIFO conter width
localparam FLIT_IF_FIFO_CNT_WD  = $clog2(FLIT_IF_FIFO_DEPTH+1);

// Flit Interface from vLSM and CXL Controller to XPLH ARB/MUX
typedef struct packed {
    logic                      vld;  // Flit Valid
    logic                      sof;  // Start of Flit
    logic                      eof;  // End of Flit
    logic                      efn;  // End of Flit Nullified
    logic [ARBMUX_FLIT_WD-1:0] data; // Flit Data
} arbmux_flit_if_t;

// Flit Interface after alignment to PLH data width
// For CXL2.0 it is the same as arbmux_flit_if_t for 512-bit core
// For CXL3.0 it is the same as arbmux_flit_if_t for 1024-bit and 512-bit cores
typedef struct packed {
    logic                      vld;  // Flit Valid
    logic                      sof;  // Start of Flit
    logic                      eof;  // End of Flit
    logic                      efn;  // End of Flit Nullified
    logic [ARBMUX_XPLH_WD-1:0] data; // Flit Data
} arbmux_xplh_if_t;
//-------------------------------------------------------
// 2565B packer 
//--------------------------------------------------------------

typedef enum logic [1:0] {
    CXL_256B_SLOT_G      = 2'b00,
    CXL_256B_SLOT_H      = 2'b01,
    CXL_256B_SLOT_HS     = 2'b10,
    CXL_256B_SLOT_DATA   = 2'b11
} CXL_SLOT_TYPES;
typedef enum logic [1:0] {
   CXL_256B_CACHE_H = 2'b00,
   CXL_256B_CACHE_D = 2'b01,
   CXL_256B_MEM_M   = 2'b10,
   CXL_256B_MEM_S   = 2'b11
} DATA_TYPES_t;

typedef struct packed {
    logic        is_data;
    logic        data_strt;
    logic        data_end;
    logic        is_be_slot;
    logic [1:0]  data_slot_idx;
    DATA_TYPES_t data_type;
} DATA_INFO_t;


typedef struct packed {
    logic                 Valid;
    logic [3:0]           slot_idx;
    logic [4:0]           Data;
    logic [3:0]           data_vld;
    logic [3:0]           be_vld;
    logic [127:0]         Slot;
    CXL_SLOT_TYPES        slot_type;
    DATA_INFO_t           data_info;
} SLOT_DESCR_256B_t;

typedef enum logic [1:0] {
    CXL_CACHE_REQ    = 2'b00,
    CXL_CACHE_RSP    = 2'b01,
    CXL_CACHE_DATA   = 2'b10
} CXL_CACHE_TYPES;


typedef struct packed {
    logic            data_slot_vld;
    logic [2:0]      data_slot_cont;
    logic [7:0]      data_hdr_cont;
    logic [7:0]      data_be_bitmap;
    logic [4:0]      total_data_slots;
} ROLLOVR_t;




localparam SLOT_CNT_WIDTH    =(FLIT_SLOT_NUM == 1) ? 1 : $clog2(FLIT_SLOT_NUM);
localparam SLOT_CNT_WIDTH_PAGE   =(FLIT_SLOT_NUM_PAGE == 1) ? 1 : $clog2(FLIT_SLOT_NUM_PAGE);

typedef enum logic [0:0] {
    CXL_CACHE_RR_REQ      = 1'b0,
    CXL_CACHE_RR_RSP      = 1'b1
} CXL_CACHE_RR_HDR_STATE;

typedef enum logic [0:0] {
    CXL_CACHE_RR_HDR  = 1'b0,
    CXL_CACHE_RR_DATA = 1'b1
} CXL_CACHE_RR_DATA_STATE;

typedef enum logic [0:0] {
    CXL_MEM_RR_REQ    = 1'b0,
    CXL_MEM_RR_BI     = 1'b1
} CXL_MEM_RR_HDR_STATE;

typedef enum logic [0:0] {
    CXL_MEM_RR_HDR    = 1'b0,
    CXL_MEM_RR_DATA   = 1'b1
} CXL_MEM_RR_DATA_STATE;

typedef enum logic {
   CXL_256B_CACHE = 1'b0,
   CXL_256B_MEM   = 1'b1
} RR_256B_ARB_STATE_t;

typedef enum logic {
   CXL_EP_D_S = 1'b0,
   CXL_RC_H_M = 1'b1
} DEVICE_MODE_t;

localparam H2D_REQ_CNT_WIDTH  =(H2D_256B_REQ_NUM  == 1)? 1 : $clog2(H2D_256B_REQ_NUM);
localparam H2D_RSP_CNT_WIDTH  =(H2D_256B_RESP_NUM == 1)? 1 : $clog2(H2D_256B_RESP_NUM);
localparam H2D_DATA_CNT_WIDTH =(H2D_256B_DATA_NUM == 1)? 1 : $clog2(H2D_256B_DATA_NUM);

localparam M2S_REQ_CNT_WIDTH    =(M2S_256B_NDR_NUM == 1)?    1 : $clog2(M2S_256B_NDR_NUM);
localparam M2S_BI_RSP_CNT_WIDTH =(M2S_256B_BI_RSP_NUM == 1)? 1 : $clog2(M2S_256B_BI_RSP_NUM);
localparam M2S_HDR_CNT_WIDTH    =(M2S_256B_DATA_NUM == 1)?   1 : $clog2(M2S_256B_DATA_NUM);


localparam D2H_REQ_CNT_WIDTH    =(D2H_256B_REQ_NUM  == 1)? 1 : $clog2(D2H_256B_REQ_NUM);
localparam D2H_RSP_CNT_WIDTH    =(D2H_256B_RESP_NUM == 1)? 1 : $clog2(D2H_256B_RESP_NUM);
localparam D2H_DATA_CNT_WIDTH   =(D2H_256B_DATA_NUM == 1)? 1 : $clog2(D2H_256B_DATA_NUM);


localparam S2M_REQ_CNT_WIDTH    =(S2M_256B_NDR_NUM == 1)?    1 : $clog2(S2M_256B_NDR_NUM);
localparam S2M_BI_SNP_CNT_WIDTH =(S2M_256B_BI_SNP_NUM == 1)? 1 : $clog2(S2M_256B_BI_SNP_NUM);
localparam S2M_HDR_CNT_WIDTH    =(S2M_256B_DATA_NUM == 1)?   1 : $clog2(S2M_256B_DATA_NUM);

localparam D2H_HDR_BEB_IDX_HBR  = 15; 
localparam M2S_RWD_BEB_IDX_HBR  = 75;  
localparam D2H_HDR_BEB_IDX_PBR  = 15; 
localparam M2S_RWD_BEB_IDX_PBR  = 75;
localparam D2H_HDR_BEB_IDX_256B = 15; 
localparam M2S_RWD_BEB_IDX_256B = 75;

function automatic SLOT_DESCR_256B_t pack_data( 
  logic [3:0][127:0]  data       ,
  logic [63:0]        byte_en    ,
  logic [2:0]         idx        ,
  logic               byte_en_vld,
  DATA_TYPES_t        device_mode  

);
  SLOT_DESCR_256B_t slot_curr;
  begin
    slot_curr           = 'b0;
    slot_curr.data_info.data_type  = device_mode;
    if (idx == 0) slot_curr.data_info.data_strt   = 1'b1 ;
    if (((idx == 'd3) & !byte_en_vld) | ((idx == 'd4) & byte_en_vld))
      slot_curr.data_info.data_end   = 1'b1;

    if (!idx[2]) begin   // idx < 4
      slot_curr.Valid                     = 1'b1;
      slot_curr.data_info.is_data         = 1'b1;
      slot_curr.data_info.data_slot_idx   = idx[1:0];
      slot_curr.slot_type                 = CXL_256B_SLOT_DATA;
// spyglass disable_block ImproperRangeIndex-ML
// SMD: INDEX larger than the bit width required for variable.
// SJ: The IDX max is 3 (3*16*8 = 384) less than 512
      slot_curr.Slot                      = data[idx[1:0]];
// spyglass enable_block ImproperRangeIndex-ML
    end
    else begin
      slot_curr.Valid                = 1'b1;
      slot_curr.data_info.is_data    = 1'b1;
      slot_curr.data_info.is_be_slot = 1'b1;
      slot_curr.slot_type            = CXL_256B_SLOT_DATA;
      slot_curr.Slot[63:0]           = byte_en;
    end
    return slot_curr;
  end
endfunction

function automatic logic [$clog2(8+1)-1  :0] valid_cnt (logic [8-1:0] message_vld );
  begin
    casez(message_vld)
      8'b1???_???? : valid_cnt = 'd8;
      8'b01??_???? : valid_cnt = 'd7;
      8'b001?_???? : valid_cnt = 'd6;
      8'b0001_???? : valid_cnt = 'd5;
      8'b0000_1??? : valid_cnt = 'd4;
      8'b0000_01?? : valid_cnt = 'd3;
      8'b0000_001? : valid_cnt = 'd2;
      8'b0000_0001 : valid_cnt = 'd1;
      default      : valid_cnt = 'd0;
    endcase

  end
endfunction



endpackage // DWC_cxl_pkg

`endif // __GUARD__DWC_CXL_PKG__SVH__
