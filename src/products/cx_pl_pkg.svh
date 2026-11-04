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
// ---   $DateTime: 2023/12/22 07:15:34 $
// ---   $Author: lnicola $
// ---   $Id: //dwh/pcie_iip/main/fairbanks/design/products/cx_pl_pkg.svh#8 $
// -----------------------------------------------------------------------------

`ifndef __GUARD__CX_PL_PKG__SVH__
`define __GUARD__CX_PL_PKG__SVH__

// -----------------------------------------------------------------------------
// --- Package Description: Package containing common variables and functions for cx_pl
// -----------------------------------------------------------------------------
package cx_pl_pkg;

  // Transmit Path Command Interface
  typedef enum logic [2:0] {
    CMD_RESET       = 3'b000, // No valid command
    CMD_IDLE        = 3'b001, // Send IDLE Flits Originates XMLH terminates XPLH
    CMD_NOP         = 3'b010, // Send NOP FLits Originates XMLH terminates XTLH
    CMD_FLUSH_XTLH  = 3'b011, // Flush to XTLH Originates XMLH terminates XTLH
    CMD_ABANDON_LP  = 3'b111, // Abandon low power entry
    CMD_PYLD        = 3'b100, // Send Payload Flits Originates XMLH/XPLH terminates XTLH
    CMD_FLUSH_XAIM  = 3'b101, // Flush to XAIM Originates XMLH terminates XAIM
    CMD_FLUSH_APP   = 3'b110  // Flush to Application 
  } tx_cmd_e;

  // TX Command Structure
  typedef struct packed {
    tx_cmd_e  tx_cmd;     // Transmit Command Enum
    logic     req;        // Command Request set to 1 when command is valid
    logic     flit_mode;  // Flit Mode Enable
  } tx_cmd_struct;

  // DLLP Type Encoding
  typedef enum logic [7:0] {
    LINK_MANAGEMENT             = 8'b00101000,
    DATA_LINK_FEATURE           = 8'b00000010,
    PM_ENTER_L1                 = 8'b00100000,
    PM_ENTER_L23                = 8'b00100001,
    PM_ACTIVE_STATE_REQUEST_L1  = 8'b00100011,
    PM_REQUEST_ACK              = 8'b00100100,
    VENDOR                      = 8'b00110000,
    NOP_DLLP                    = 8'b00110001,
    NOP2_DLLP                   = 8'b00000000,
    INITFC1_P_VC0               = 8'b01000000,
    INITFC1_P_VC1               = 8'b01000001,
    INITFC1_P_VC2               = 8'b01000010,
    INITFC1_P_VC3               = 8'b01000011,
    INITFC1_P_VC4               = 8'b01000100,
    INITFC1_P_VC5               = 8'b01000101,
    INITFC1_P_VC6               = 8'b01000110,
    INITFC1_P_VC7               = 8'b01000111,
    INITFC1_NP_VC0              = 8'b01010000,
    INITFC1_NP_VC1              = 8'b01010001,
    INITFC1_NP_VC2              = 8'b01010010,
    INITFC1_NP_VC3              = 8'b01010011,
    INITFC1_NP_VC4              = 8'b01010100,
    INITFC1_NP_VC5              = 8'b01010101,
    INITFC1_NP_VC6              = 8'b01010110,
    INITFC1_NP_VC7              = 8'b01010111,
    INITFC1_CPL_VC0             = 8'b01100000,
    INITFC1_CPL_VC1             = 8'b01100001,
    INITFC1_CPL_VC2             = 8'b01100010,
    INITFC1_CPL_VC3             = 8'b01100011,
    INITFC1_CPL_VC4             = 8'b01100100,
    INITFC1_CPL_VC5             = 8'b01100101,
    INITFC1_CPL_VC6             = 8'b01100110,
    INITFC1_CPL_VC7             = 8'b01100111,
    INITFC2_P_VC0               = 8'b11000000,
    INITFC2_P_VC1               = 8'b11000001,
    INITFC2_P_VC2               = 8'b11000010,
    INITFC2_P_VC3               = 8'b11000011,
    INITFC2_P_VC4               = 8'b11000100,
    INITFC2_P_VC5               = 8'b11000101,
    INITFC2_P_VC6               = 8'b11000110,
    INITFC2_P_VC7               = 8'b11000111,
    INITFC2_NP_VC0              = 8'b11010000,
    INITFC2_NP_VC1              = 8'b11010001,
    INITFC2_NP_VC2              = 8'b11010010,
    INITFC2_NP_VC3              = 8'b11010011,
    INITFC2_NP_VC4              = 8'b11010100,
    INITFC2_NP_VC5              = 8'b11010101,
    INITFC2_NP_VC6              = 8'b11010110,
    INITFC2_NP_VC7              = 8'b11010111,
    INITFC2_CPL_VC0             = 8'b11100000,
    INITFC2_CPL_VC1             = 8'b11100001,
    INITFC2_CPL_VC2             = 8'b11100010,
    INITFC2_CPL_VC3             = 8'b11100011,
    INITFC2_CPL_VC4             = 8'b11100100,
    INITFC2_CPL_VC5             = 8'b11100101,
    INITFC2_CPL_VC6             = 8'b11100110,
    INITFC2_CPL_VC7             = 8'b11100111,
    UPDATEFC_P_VC0              = 8'b10000000,
    UPDATEFC_P_VC1              = 8'b10000001,
    UPDATEFC_P_VC2              = 8'b10000010,
    UPDATEFC_P_VC3              = 8'b10000011,
    UPDATEFC_P_VC4              = 8'b10000100,
    UPDATEFC_P_VC5              = 8'b10000101,
    UPDATEFC_P_VC6              = 8'b10000110,
    UPDATEFC_P_VC7              = 8'b10000111,
    UPDATEFC_NP_VC0             = 8'b10010000,
    UPDATEFC_NP_VC1             = 8'b10010001,
    UPDATEFC_NP_VC2             = 8'b10010010,
    UPDATEFC_NP_VC3             = 8'b10010011,
    UPDATEFC_NP_VC4             = 8'b10010100,
    UPDATEFC_NP_VC5             = 8'b10010101,
    UPDATEFC_NP_VC6             = 8'b10010110,
    UPDATEFC_NP_VC7             = 8'b10010111,
    UPDATEFC_CPL_VC0            = 8'b10100000,
    UPDATEFC_CPL_VC1            = 8'b10100001,
    UPDATEFC_CPL_VC2            = 8'b10100010,
    UPDATEFC_CPL_VC3            = 8'b10100011,
    UPDATEFC_CPL_VC4            = 8'b10100100,
    UPDATEFC_CPL_VC5            = 8'b10100101,
    UPDATEFC_CPL_VC6            = 8'b10100110,
    UPDATEFC_CPL_VC7            = 8'b10100111,
    DUMMY                       = 8'b11111111,
    DED_INITFC1_P_VC0           = 8'b01001000,
    DED_INITFC1_P_VC1           = 8'b01001001,
    DED_INITFC1_P_VC2           = 8'b01001010,
    DED_INITFC1_P_VC3           = 8'b01001011,
    DED_INITFC1_P_VC4           = 8'b01001100,
    DED_INITFC1_P_VC5           = 8'b01001101,
    DED_INITFC1_P_VC6           = 8'b01001110,
    DED_INITFC1_P_VC7           = 8'b01001111,
    DED_INITFC1_NP_VC0          = 8'b01011000,
    DED_INITFC1_NP_VC1          = 8'b01011001,
    DED_INITFC1_NP_VC2          = 8'b01011010,
    DED_INITFC1_NP_VC3          = 8'b01011011,
    DED_INITFC1_NP_VC4          = 8'b01011100,
    DED_INITFC1_NP_VC5          = 8'b01011101,
    DED_INITFC1_NP_VC6          = 8'b01011110,
    DED_INITFC1_NP_VC7          = 8'b01011111,
    DED_INITFC1_CPL_VC0         = 8'b01101000,
    DED_INITFC1_CPL_VC1         = 8'b01101001,
    DED_INITFC1_CPL_VC2         = 8'b01101010,
    DED_INITFC1_CPL_VC3         = 8'b01101011,
    DED_INITFC1_CPL_VC4         = 8'b01101100,
    DED_INITFC1_CPL_VC5         = 8'b01101101,
    DED_INITFC1_CPL_VC6         = 8'b01101110,
    DED_INITFC1_CPL_VC7         = 8'b01101111,
    DED_INITFC2_P_VC0           = 8'b11001000,
    DED_INITFC2_P_VC1           = 8'b11001001,
    DED_INITFC2_P_VC2           = 8'b11001010,
    DED_INITFC2_P_VC3           = 8'b11001011,
    DED_INITFC2_P_VC4           = 8'b11001100,
    DED_INITFC2_P_VC5           = 8'b11001101,
    DED_INITFC2_P_VC6           = 8'b11001110,
    DED_INITFC2_P_VC7           = 8'b11001111,
    DED_INITFC2_NP_VC0          = 8'b11011000,
    DED_INITFC2_NP_VC1          = 8'b11011001,
    DED_INITFC2_NP_VC2          = 8'b11011010,
    DED_INITFC2_NP_VC3          = 8'b11011011,
    DED_INITFC2_NP_VC4          = 8'b11011100,
    DED_INITFC2_NP_VC5          = 8'b11011101,
    DED_INITFC2_NP_VC6          = 8'b11011110,
    DED_INITFC2_NP_VC7          = 8'b11011111,
    DED_INITFC2_CPL_VC0         = 8'b11101000,
    DED_INITFC2_CPL_VC1         = 8'b11101001,
    DED_INITFC2_CPL_VC2         = 8'b11101010,
    DED_INITFC2_CPL_VC3         = 8'b11101011,
    DED_INITFC2_CPL_VC4         = 8'b11101100,
    DED_INITFC2_CPL_VC5         = 8'b11101101,
    DED_INITFC2_CPL_VC6         = 8'b11101110,
    DED_INITFC2_CPL_VC7         = 8'b11101111,
    DED_UPDATEFC_P_VC0          = 8'b10001000,
    DED_UPDATEFC_P_VC1          = 8'b10001001,
    DED_UPDATEFC_P_VC2          = 8'b10001010,
    DED_UPDATEFC_P_VC3          = 8'b10001011,
    DED_UPDATEFC_P_VC4          = 8'b10001100,
    DED_UPDATEFC_P_VC5          = 8'b10001101,
    DED_UPDATEFC_P_VC6          = 8'b10001110,
    DED_UPDATEFC_P_VC7          = 8'b10001111,
    DED_UPDATEFC_NP_VC0         = 8'b10011000,
    DED_UPDATEFC_NP_VC1         = 8'b10011001,
    DED_UPDATEFC_NP_VC2         = 8'b10011010,
    DED_UPDATEFC_NP_VC3         = 8'b10011011,
    DED_UPDATEFC_NP_VC4         = 8'b10011100,
    DED_UPDATEFC_NP_VC5         = 8'b10011101,
    DED_UPDATEFC_NP_VC6         = 8'b10011110,
    DED_UPDATEFC_NP_VC7         = 8'b10011111,
    DED_UPDATEFC_CPL_VC0        = 8'b10101000,
    DED_UPDATEFC_CPL_VC1        = 8'b10101001,
    DED_UPDATEFC_CPL_VC2        = 8'b10101010,
    DED_UPDATEFC_CPL_VC3        = 8'b10101011,
    DED_UPDATEFC_CPL_VC4        = 8'b10101100,
    DED_UPDATEFC_CPL_VC5        = 8'b10101101,
    DED_UPDATEFC_CPL_VC6        = 8'b10101110,
    DED_UPDATEFC_CPL_VC7        = 8'b10101111
  } dllp_type_e;

  function automatic bit dlp_is_update_fc (
    input dllp_type_e dllpType
  );
    begin
      dlp_is_update_fc = '0;
      dlp_is_update_fc = dllpType inside {
        UPDATEFC_P_VC0,
        UPDATEFC_P_VC1,
        UPDATEFC_P_VC2,
        UPDATEFC_P_VC3,
        UPDATEFC_P_VC4,
        UPDATEFC_P_VC5,
        UPDATEFC_P_VC6,
        UPDATEFC_P_VC7,
        UPDATEFC_NP_VC0,
        UPDATEFC_NP_VC1,
        UPDATEFC_NP_VC2,
        UPDATEFC_NP_VC3,
        UPDATEFC_NP_VC4,
        UPDATEFC_NP_VC5,
        UPDATEFC_NP_VC6,
        UPDATEFC_NP_VC7,
        UPDATEFC_CPL_VC0,
        UPDATEFC_CPL_VC1,
        UPDATEFC_CPL_VC2,
        UPDATEFC_CPL_VC3,
        UPDATEFC_CPL_VC4,
        UPDATEFC_CPL_VC5,
        UPDATEFC_CPL_VC6,
        UPDATEFC_CPL_VC7,
        DED_UPDATEFC_P_VC0,
        DED_UPDATEFC_P_VC1,
        DED_UPDATEFC_P_VC2,
        DED_UPDATEFC_P_VC3,
        DED_UPDATEFC_P_VC4,
        DED_UPDATEFC_P_VC5,
        DED_UPDATEFC_P_VC6,
        DED_UPDATEFC_P_VC7,
        DED_UPDATEFC_NP_VC0,
        DED_UPDATEFC_NP_VC1,
        DED_UPDATEFC_NP_VC2,
        DED_UPDATEFC_NP_VC3,
        DED_UPDATEFC_NP_VC4,
        DED_UPDATEFC_NP_VC5,
        DED_UPDATEFC_NP_VC6,
        DED_UPDATEFC_NP_VC7,
        DED_UPDATEFC_CPL_VC0,
        DED_UPDATEFC_CPL_VC1,
        DED_UPDATEFC_CPL_VC2,
        DED_UPDATEFC_CPL_VC3,
        DED_UPDATEFC_CPL_VC4,
        DED_UPDATEFC_CPL_VC5,
        DED_UPDATEFC_CPL_VC6,
        DED_UPDATEFC_CPL_VC7
      };
    end
    return dlp_is_update_fc;
  endfunction

  // General DLLP Struct
  typedef struct packed {
    logic [23:0]    pyld;           // DLLP Payload
    dllp_type_e     dllp_type;      // DLLP Type
    logic           valid;          // DLLP Valid Indication
  } dllp_struct;

  // Flit mode RASDES signals in xplh layer
  typedef struct packed {
    logic xplh_retry_replay_timeout;
    logic xplh_retry_replay_num_rollover;
    logic xplh_sent_ack;
    logic xplh_sent_nak;
    logic xplh_retry_flit;
  } xplh_sideband_rasdes_fm;


  // Retry Buffer Interface Struct
  typedef struct packed {
    logic [`RBUF_PW-1:0]    retryram_raddr;     // Retry Buffer Read Address
    logic [`RBUF_PW-1:0]    retryram_waddr;     // Retry Buffer Write Address
    logic [`RBUF_WIDTH-1:0] retryram_data;      // Retry Buffer Write Data
    logic                   retryram_we;        // Write enable to retry buffer RAM
    logic                   retryram_en;        // Read Enable to retry buffer RAM
  } rbuf_struct;

  typedef struct packed {
  logic [32* `CX_NW -1 : 0] data_out;           // Data to be transferred
  logic                     halt_in;            // Halt the transmission
  logic [`CX_NW - 1 : 0]    stp;                // Indicates which DW contains start of TLP
  logic [`CX_NW - 1 : 0]    eot;                // Indicates which DW contains end of TLP/DLLP
  logic [`CX_NW - 1 : 0]    sdp;                // Indicates which DW contains start of DLLP
  logic [`CX_NW - 1 : 0]    pad;                // Indicates which DW contains PAD symbol
  logic [`CX_NW - 1 : 0]    next_stp;           // Indicates the DW containing the next STP
  logic [`CX_NW - 1 : 0]    next_eot;           // Indicates the DW containing the next EOT
  logic [`CX_NW - 1 : 0]    next_sdp;           // Indicates the DW containing the next SDP
  logic                     sof;                // Start of Flit Marker
  logic [1:0]               eof;                // End of Flit Marker
  logic                     enf;                // Indicates end of a Flit containing NOP TLP's
  } xplh_sideband_struct;

  // Number of Double Words in the datapath
  localparam  P_NW  = `CX_NW;
  // Non-Flit Mode NW upper limit of 16
  localparam  P_NFM_NW = (P_NW > 16) ? 16 : P_NW;
  // Data Path Width
  localparam  P_DW  = (32*P_NW);
  localparam  P_NFM_DW  = (P_NW > 16) ? (32*16) : (32*P_NW);
  // Data Bus Parity Width
  localparam  DATA_PAR_WD = `TRGT_DATA_PROT_WD;
  localparam  NFM_DATA_PAR_WD = `NFM_TRGT_DATA_PROT_WD;
  // Data bus width including protection
  localparam  DW_W_PAR = P_DW + DATA_PAR_WD;
  localparam  NFM_DW_W_PAR = P_NFM_DW + NFM_DATA_PAR_WD;
  // Non Flit Mode retry buffer width
  localparam  P_NFM_RBUF_WD = `NFM_RBUF_WIDTH;

  // -----------------------------------------------------------------------------
  // Parameter Declarations
  // -----------------------------------------------------------------------------
  // Retry Buffer Address Width
  localparam  P_RBUF_PW                   = `RBUF_PW;
  // Retry Buffer Data Width
  localparam  P_RBUF_WD                   = `RBUF_WIDTH;
    // Retry Buffer Control Bits Width
  localparam  P_RBUF_CTRL_WD              = `CX_RBUF_CTRL_WD;
  // Retry Buffer Depth
  localparam  P_RBUF_DEPTH                = `CX_RBUF_DEPTH;
  // Retry Buffer Read Latency
  localparam  P_RBUF_READ_LATENCY         = 2;
  // Number of Virtual Channels
  localparam  P_NVC                       = `CX_NVC;
  // Parity Mode
  localparam  P_PARITY_MODE               = `CX_RAS_PARITY_MODE;
  // Protection Type
  localparam  P_PROT_TYPE                 = `CX_RAS_PROT_TYPE;
  // Protection Range
  localparam  P_PROT_RANGE                = `CX_RAS_PROT_RANGE;
  // Correction Enable
  localparam  P_PROT_CORRECT_EN           = P_PROT_TYPE ? 0 : `CX_RAS_CORRECTION_EN;
  // RAM Protection Range
  localparam  P_RAS_RAM_PROT_RANGE        = `CX_RAS_RAM_PROT_RANGE;
  // RAM Protection Type
  localparam  P_RAS_RAM_PROT_TYPE         = 0;
  // RAM Parity Mode
  localparam  P_RAS_RAM_PARITY_MODE       = 0;
  // RAM Protection Width
  localparam  P_RBUF_PROT_WD              = `RBUF_PROT_WD;
  //Flit Protection Width after stripping FEC and CRC
  localparam  P_FLIT_PROT_WD              = `CX_RAS_FLIT_PROT_WD;

  localparam P_DLP0_END = (32 * P_NW) - (128 + (3*8) + 1);
  localparam P_DLP1_END = (32 * P_NW) - (128 + (2*8) + 1);
  localparam P_DLP2_END = (32 * P_NW) - (128 + (1*8) + 1);

  // TYPE_OF_DLP_PAYLOAD Index
  localparam P_TYPE_OF_DLP = P_DLP0_END - 3;
  // REPLAY Command End
  localparam P_REPLAY_CMD_END = P_DLP0_END - 4;


  // -----------------------------------------------------------------------------
  // Gen6 Flit Width
  localparam  P_FLIT_WD = 2048;
  localparam  P_LOPT_FLIT_WD = 1024;
  // Number of Symbols per FEC group
  localparam  P_N_SYMBOLS = 84;
  // Number of Bytes in the Flit
  localparam  P_FLIT_BYTES = P_FLIT_WD / 8;

  // -----------------------------------------------------------------------------
  // Flit Mode Retry Related Parameters 
  // -----------------------------------------------------------------------------
  // Maximum sequence number
  localparam  P_MAX_SEQNUM                = 1023;
  // Sequence number width
  localparam  P_TX_SEQNUM_WD              = $clog2(P_MAX_SEQNUM);

  // Flit DW Counter
  localparam P_FLIT_DW_CNT                = 4;

  localparam P_FLIT_DW_CNT_WD             = $clog2(P_FLIT_DW_CNT);

  // -----------------------------------------------------------------------------
  // Transmitter Link Layer Physical Layer Interface Parameters
  // -----------------------------------------------------------------------------

  // -----------------------------------------------------------------------------
  // FEC Polynomials
  // -----------------------------------------------------------------------------
  localparam  [0 : P_FLIT_WD - 1] P_FEC     = { 8'h01, 8'h02, 8'h04, 8'h08, 8'h10, 8'h20, 8'h40, 8'h80, 8'h1d, 8'h3a, 8'h74, 8'he8, 8'hcd, 8'h87, 8'h13, 8'h26,
                                                8'h4c, 8'h98, 8'h2d, 8'h5a, 8'hb4, 8'h75, 8'hea, 8'hc9, 8'h8f, 8'h03, 8'h06, 8'h0c, 8'h18, 8'h30, 8'h60, 8'hc0,
                                                8'h9d, 8'h27, 8'h4e, 8'h9c, 8'h25, 8'h4a, 8'h94, 8'h35, 8'h6a, 8'hd4, 8'hb5, 8'h77, 8'hee, 8'hc1, 8'h9f, 8'h23,
                                                8'h46, 8'h8c, 8'h05, 8'h0a, 8'h14, 8'h28, 8'h50, 8'ha0, 8'h5d, 8'hba, 8'h69, 8'hd2, 8'hb9, 8'h6f, 8'hde, 8'ha1,
                                                8'h5f, 8'hbe, 8'h61, 8'hc2, 8'h99, 8'h2f, 8'h5e, 8'hbc, 8'h65, 8'hca, 8'h89, 8'h0f, 8'h1e, 8'h3c, 8'h78, 8'hf0,
                                                8'hfd, 8'he7, 8'hd3, 8'hbb, 8'h6b, 8'hd6, 8'hb1, 8'h7f, 8'hfe, 8'he1, 8'hdf, 8'ha3, 8'h5b, 8'hb6, 8'h71, 8'he2,
                                                8'hd9, 8'haf, 8'h43, 8'h86, 8'h11, 8'h22, 8'h44, 8'h88, 8'h0d, 8'h1a, 8'h34, 8'h68, 8'hd0, 8'hbd, 8'h67, 8'hce,
                                                8'h81, 8'h1f, 8'h3e, 8'h7c, 8'hf8, 8'hed, 8'hc7, 8'h93, 8'h3b, 8'h76, 8'hec, 8'hc5, 8'h97, 8'h33, 8'h66, 8'hcc,
                                                8'h85, 8'h17, 8'h2e, 8'h5c, 8'hb8, 8'h6d, 8'hda, 8'ha9, 8'h4f, 8'h9e, 8'h21, 8'h42, 8'h84, 8'h15, 8'h2a, 8'h54,
                                                8'ha8, 8'h4d, 8'h9a, 8'h29, 8'h52, 8'ha4, 8'h55, 8'haa, 8'h49, 8'h92, 8'h39, 8'h72, 8'he4, 8'hd5, 8'hb7, 8'h73,
                                                8'he6, 8'hd1, 8'hbf, 8'h63, 8'hc6, 8'h91, 8'h3f, 8'h7e, 8'hfc, 8'he5, 8'hd7, 8'hb3, 8'h7b, 8'hf6, 8'hf1, 8'hff,
                                                8'he3, 8'hdb, 8'hab, 8'h4b, 8'h96, 8'h31, 8'h62, 8'hc4, 8'h95, 8'h37, 8'h6e, 8'hdc, 8'ha5, 8'h57, 8'hae, 8'h41,
                                                8'h82, 8'h19, 8'h32, 8'h64, 8'hc8, 8'h8d, 8'h07, 8'h0e, 8'h1c, 8'h38, 8'h70, 8'he0, 8'hdd, 8'ha7, 8'h53, 8'ha6,
                                                8'h51, 8'ha2, 8'h59, 8'hb2, 8'h79, 8'hf2, 8'hf9, 8'hef, 8'hc3, 8'h9b, 8'h2b, 8'h56, 8'hac, 8'h45, 8'h8a, 8'h09,
                                                8'h12, 8'h24, 8'h48, 8'h90, 8'h3d, 8'h7a, 8'hf4, 8'hf5, 8'hf7, 8'hf3, 8'hfb, 8'heb, 8'hcb, 8'h8b, 8'h0b, 8'h16,
                                                8'h2c, 8'h58, 8'hb0, 8'h7d, 8'hfa, 8'he9, 8'hcf, 8'h83, 8'h1b, 8'h36, 8'h6c, 8'hd8, 8'had, 8'h47, 8'h8e, 8'h01};
  
  localparam  [0 : P_FLIT_WD - 1] P_INV_FEC = { 8'hff, 8'h00, 8'h01, 8'h19, 8'h02, 8'h32, 8'h1a, 8'hc6, 8'h03, 8'hdf, 8'h33, 8'hee, 8'h1b, 8'h68, 8'hc7, 8'h4b,
                                                8'h04, 8'h64, 8'he0, 8'h0e, 8'h34, 8'h8d, 8'hef, 8'h81, 8'h1c, 8'hc1, 8'h69, 8'hf8, 8'hc8, 8'h08, 8'h4c, 8'h71,
                                                8'h05, 8'h8a, 8'h65, 8'h2f, 8'he1, 8'h24, 8'h0f, 8'h21, 8'h35, 8'h93, 8'h8e, 8'hda, 8'hf0, 8'h12, 8'h82, 8'h45,
                                                8'h1d, 8'hb5, 8'hc2, 8'h7d, 8'h6a, 8'h27, 8'hf9, 8'hb9, 8'hc9, 8'h9a, 8'h09, 8'h78, 8'h4d, 8'he4, 8'h72, 8'ha6,
                                                8'h06, 8'hbf, 8'h8b, 8'h62, 8'h66, 8'hdd, 8'h30, 8'hfd, 8'he2, 8'h98, 8'h25, 8'hb3, 8'h10, 8'h91, 8'h22, 8'h88,
                                                8'h36, 8'hd0, 8'h94, 8'hce, 8'h8f, 8'h96, 8'hdb, 8'hbd, 8'hf1, 8'hd2, 8'h13, 8'h5c, 8'h83, 8'h38, 8'h46, 8'h40,
                                                8'h1e, 8'h42, 8'hb6, 8'ha3, 8'hc3, 8'h48, 8'h7e, 8'h6e, 8'h6b, 8'h3a, 8'h28, 8'h54, 8'hfa, 8'h85, 8'hba, 8'h3d,
                                                8'hca, 8'h5e, 8'h9b, 8'h9f, 8'h0a, 8'h15, 8'h79, 8'h2b, 8'h4e, 8'hd4, 8'he5, 8'hac, 8'h73, 8'hf3, 8'ha7, 8'h57,
                                                8'h07, 8'h70, 8'hc0, 8'hf7, 8'h8c, 8'h80, 8'h63, 8'h0d, 8'h67, 8'h4a, 8'hde, 8'hed, 8'h31, 8'hc5, 8'hfe, 8'h18,
                                                8'he3, 8'ha5, 8'h99, 8'h77, 8'h26, 8'hb8, 8'hb4, 8'h7c, 8'h11, 8'h44, 8'h92, 8'hd9, 8'h23, 8'h20, 8'h89, 8'h2e,
                                                8'h37, 8'h3f, 8'hd1, 8'h5b, 8'h95, 8'hbc, 8'hcf, 8'hcd, 8'h90, 8'h87, 8'h97, 8'hb2, 8'hdc, 8'hfc, 8'hbe, 8'h61,
                                                8'hf2, 8'h56, 8'hd3, 8'hab, 8'h14, 8'h2a, 8'h5d, 8'h9e, 8'h84, 8'h3c, 8'h39, 8'h53, 8'h47, 8'h6d, 8'h41, 8'ha2,
                                                8'h1f, 8'h2d, 8'h43, 8'hd8, 8'hb7, 8'h7b, 8'ha4, 8'h76, 8'hc4, 8'h17, 8'h49, 8'hec, 8'h7f, 8'h0c, 8'h6f, 8'hf6,
                                                8'h6c, 8'ha1, 8'h3b, 8'h52, 8'h29, 8'h9d, 8'h55, 8'haa, 8'hfb, 8'h60, 8'h86, 8'hb1, 8'hbb, 8'hcc, 8'h3e, 8'h5a,
                                                8'hcb, 8'h59, 8'h5f, 8'hb0, 8'h9c, 8'ha9, 8'ha0, 8'h51, 8'h0b, 8'hf5, 8'h16, 8'heb, 8'h7a, 8'h75, 8'h2c, 8'hd7,
                                                8'h4f, 8'hae, 8'hd5, 8'he9, 8'he6, 8'he7, 8'had, 8'he8, 8'h74, 8'hd6, 8'hf4, 8'hea, 8'ha8, 8'h50, 8'h58, 8'haf};
  
  // -----------------------------------------------------------------------------
  // CRC Coefficients
  // -----------------------------------------------------------------------------
  localparam P_ZERO_WD = (P_FLIT_WD - (242 * 8)) * 8;
  localparam [P_ZERO_WD - 1 : 0] P_ZERO_PAD = {P_ZERO_WD{1'b0}};
  localparam [(P_FLIT_WD * 8) - 1 : 0] P_COEF7 =  {P_ZERO_PAD,
                                                  8'ha7,8'hc6,8'h63,8'ha4,8'h52,8'h29,8'h81,8'hd5,8'h14,8'h0a,8'h05,8'h97,8'hde,8'h6f,8'ha2,8'h51,
                                                  8'ha1,8'hc5,8'hf7,8'hee,8'h77,8'hae,8'h57,8'hbe,8'h29,8'h81,8'hd5,8'hff,8'hea,8'h75,8'haf,8'hc2,
                                                  8'h95,8'hdf,8'hfa,8'h7d,8'hab,8'hc0,8'h60,8'h30,8'hb5,8'hcf,8'hf2,8'h79,8'ha9,8'hc1,8'hf5,8'hef,
                                                  8'h26,8'h13,8'h9c,8'h4e,8'h27,8'h86,8'h43,8'hb4,8'h14,8'h0a,8'h05,8'h97,8'hde,8'h6f,8'ha2,8'h51,
                                                  8'he7,8'he6,8'h73,8'hac,8'h56,8'h2b,8'h80,8'h40,8'hc9,8'hf1,8'hed,8'he3,8'he4,8'h72,8'h39,8'h89,
                                                  8'hfb,8'he8,8'h74,8'h3a,8'h1d,8'h9b,8'hd8,8'h6c,8'hb6,8'h5b,8'hb8,8'h5c,8'h2e,8'h17,8'h9e,8'h4f,
                                                  8'hfd,8'heb,8'he0,8'h70,8'h38,8'h1c,8'h0e,8'h07,8'h84,8'h42,8'h21,8'h85,8'hd7,8'hfe,8'h7f,8'haa,
                                                  8'hf7,8'hee,8'h77,8'hae,8'h57,8'hbe,8'h5f,8'hba,8'h91,8'hdd,8'hfb,8'he8,8'h74,8'h3a,8'h1d,8'h9b,
                                                  8'h45,8'hb7,8'hce,8'h67,8'ha6,8'h53,8'hbc,8'h5e,8'h42,8'h21,8'h85,8'hd7,8'hfe,8'h7f,8'haa,8'h55,
                                                  8'ha8,8'h54,8'h2a,8'h15,8'h9f,8'hda,8'h6d,8'ha3,8'h4c,8'h26,8'h13,8'h9c,8'h4e,8'h27,8'h86,8'h43,
                                                  8'hd4,8'h6a,8'h35,8'h8f,8'hd2,8'h69,8'ha1,8'hc5,8'hef,8'he2,8'h71,8'had,8'hc3,8'hf4,8'h7a,8'h3d,
                                                  8'h9a,8'h4d,8'hb3,8'hcc,8'h66,8'h33,8'h8c,8'h46,8'hcf,8'hf2,8'h79,8'ha9,8'hc1,8'hf5,8'hef,8'he2,
                                                  8'hda,8'h6d,8'ha3,8'hc4,8'h62,8'h31,8'h8d,8'hd3,8'hd4,8'h6a,8'h35,8'h8f,8'hd2,8'h69,8'ha1,8'hc5,
                                                  8'hd8,8'h6c,8'h36,8'h1b,8'h98,8'h4c,8'h26,8'h13,8'h0d,8'h93,8'hdc,8'h6e,8'h37,8'h8e,8'h47,8'hb6,
                                                  8'h3c,8'h1e,8'h0f,8'h92,8'h49,8'hb1,8'hcd,8'hf3,8'h7c,8'h3e,8'h1f,8'h9a,8'h4d,8'hb3,8'hcc,8'h66,
                                                  8'h9e,8'h4f,8'hb2,8'h59,8'hb9,8'hc9,8'hf1,8'hed,8'h72,8'h39,8'h89,8'hd1,8'hfd,8'heb,8'he0,8'h70,
                                                  8'ha5,8'hc7,8'hf6,8'h7b,8'ha8,8'h54,8'h2a,8'h15,8'h7f,8'haa,8'h55,8'hbf,8'hca,8'h65,8'ha7,8'hc6,
                                                  8'heb,8'he0,8'h70,8'h38,8'h1c,8'h0e,8'h07,8'h96,8'h5a,8'h2d,8'h83,8'hd4,8'h6a,8'h35,8'h8f,8'hd2,
                                                  8'h02,8'h01,8'h95,8'hdf,8'hfa,8'h7d,8'hab,8'hc0,8'h5f,8'hba,8'h5d,8'hbb,8'hc8,8'h64,8'h32,8'h19,
                                                  8'h5c,8'h2e,8'h17,8'h9e,8'h4f,8'hb2,8'h59,8'hb9,8'hb6,8'h5b,8'hb8,8'h5c,8'h2e,8'h17,8'h9e,8'h4f,
                                                  8'h94,8'h4a,8'h25,8'h87,8'hd6,8'h6b,8'ha0,8'h50,8'h11,8'h9d,8'hdb,8'hf8,8'h7c,8'h3e,8'h1f,8'h9a,
                                                  8'heb,8'he0,8'h70,8'h38,8'h1c,8'h0e,8'h07,8'h96,8'h4e,8'h27,8'h86,8'h43,8'hb4,8'h5a,8'h2d,8'h83,
                                                  8'h1e,8'h0f,8'h92,8'h49,8'hb1,8'hcd,8'hf3,8'hec,8'h97,8'hde,8'h6f,8'ha2,8'h51,8'hbd,8'hcb,8'hf0,
                                                  8'h73,8'hac,8'h56,8'h2b,8'h80,8'h40,8'h20,8'h10,8'h2c,8'h16,8'h0b,8'h90,8'h48,8'h24,8'h12,8'h09,
                                                  8'heb,8'he0,8'h70,8'h38,8'h1c,8'h0e,8'h07,8'h96,8'ha1,8'hc5,8'hf7,8'hee,8'h77,8'hae,8'h57,8'hbe,
                                                  8'h4a,8'h25,8'h87,8'hd6,8'h6b,8'ha0,8'h50,8'h28,8'h53,8'hbc,8'h5e,8'h2f,8'h82,8'h41,8'hb5,8'hcf,
                                                  8'h64,8'h32,8'h19,8'h99,8'hd9,8'hf9,8'he9,8'he1,8'hcd,8'hf3,8'hec,8'h76,8'h3b,8'h88,8'h44,8'h22,
                                                  8'he9,8'he1,8'he5,8'he7,8'he6,8'h73,8'hac,8'h56,8'ha7,8'hc6,8'h63,8'ha4,8'h52,8'h29,8'h81,8'hd5,
                                                  8'h64,8'h32,8'h19,8'h99,8'hd9,8'hf9,8'he9,8'he1,8'h68,8'h34,8'h1a,8'h0d,8'h93,8'hdc,8'h6e,8'h37,
                                                  8'h03,8'h94,8'h4a,8'h25,8'h87,8'hd6,8'h6b,8'ha0,8'h61,8'ha5,8'hc7,8'hf6,8'h7b,8'ha8,8'h54,8'h2a,
                                                  8'h80,8'h40,8'h20,8'h10,8'h08,8'h04,8'h02,8'h01,8'h07,8'h96,8'h4b,8'hb0,8'h58,8'h2c,8'h16,8'h0b,
                                                  8'hba,8'h5d,8'hbb,8'hc8,8'h64,8'h32,8'h19,8'h99,8'hb9,8'hc9,8'hf1,8'hed,8'he3,8'he4,8'h72,8'h39,
                                                  8'h92,8'h49,8'hb1,8'hcd,8'hf3,8'hec,8'h76,8'h3b,8'hc0,8'h60,8'h30,8'h18,8'h0c,8'h06,8'h03,8'h94,
                                                  8'ha1,8'hc5,8'hf7,8'hee,8'h77,8'hae,8'h57,8'hbe,8'h38,8'h1c,8'h0e,8'h07,8'h96,8'h4b,8'hb0,8'h58,
                                                  8'h9b,8'hd8,8'h6c,8'h36,8'h1b,8'h98,8'h4c,8'h26,8'he0,8'h70,8'h38,8'h1c,8'h0e,8'h07,8'h96,8'h4b,
                                                  8'hc0,8'h60,8'h30,8'h18,8'h0c,8'h06,8'h03,8'h94,8'h80,8'h40,8'h20,8'h10,8'h08,8'h04,8'h02,8'h01,
                                                  8'hef,8'he2,8'h71,8'had,8'hc3,8'hf4,8'h7a,8'h3d,8'h45,8'hb7,8'hce,8'h67,8'ha6,8'h53,8'hbc,8'h5e,
                                                  8'h5e,8'h2f,8'h82,8'h41,8'hb5,8'hcf,8'hf2,8'h79,8'h43,8'hb4,8'h5a,8'h2d,8'h83,8'hd4,8'h6a,8'h35,
                                                  8'hb0,8'h58,8'h2c,8'h16,8'h0b,8'h90,8'h48,8'h24,8'hf9,8'he9,8'he1,8'he5,8'he7,8'he6,8'h73,8'hac,
                                                  8'h63,8'ha4,8'h52,8'h29,8'h81,8'hd5,8'hff,8'hea,8'hb0,8'h58,8'h2c,8'h16,8'h0b,8'h90,8'h48,8'h24,
                                                  8'ha2,8'h51,8'hbd,8'hcb,8'hf0,8'h78,8'h3c,8'h1e,8'h3c,8'h1e,8'h0f,8'h92,8'h49,8'hb1,8'hcd,8'hf3,
                                                  8'h37,8'h8e,8'h47,8'hb6,8'h5b,8'hb8,8'h5c,8'h2e,8'h37,8'h8e,8'h47,8'hb6,8'h5b,8'hb8,8'h5c,8'h2e,
                                                  8'hdd,8'hfb,8'he8,8'h74,8'h3a,8'h1d,8'h9b,8'hd8,8'hf2,8'h79,8'ha9,8'hc1,8'hf5,8'hef,8'he2,8'h71,
                                                  8'hd6,8'h6b,8'ha0,8'h50,8'h28,8'h14,8'h0a,8'h05,8'h26,8'h13,8'h9c,8'h4e,8'h27,8'h86,8'h43,8'hb4,
                                                  8'h58,8'h2c,8'h16,8'h0b,8'h90,8'h48,8'h24,8'h12,8'ha6,8'h53,8'hbc,8'h5e,8'h2f,8'h82,8'h41,8'hb5,
                                                  8'h48,8'h24,8'h12,8'h09,8'h91,8'hdd,8'hfb,8'he8,8'hab,8'hc0,8'h60,8'h30,8'h18,8'h0c,8'h06,8'h03,
                                                  8'h33,8'h8c,8'h46,8'h23,8'h84,8'h42,8'h21,8'h85,8'h43,8'hb4,8'h5a,8'h2d,8'h83,8'hd4,8'h6a,8'h35,
                                                  8'h54,8'h2a,8'h15,8'h9f,8'hda,8'h6d,8'ha3,8'hc4,8'h38,8'h1c,8'h0e,8'h07,8'h96,8'h4b,8'hb0,8'h58,
                                                  8'hb8,8'h5c,8'h2e,8'h17,8'h9e,8'h4f,8'hb2,8'h59,8'h9d,8'hdb,8'hf8,8'h7c,8'h3e,8'h1f,8'h9a,8'h4d,
                                                  8'h43,8'hb4,8'h5a,8'h2d,8'h83,8'hd4,8'h6a,8'h35,8'h70,8'h38,8'h1c,8'h0e,8'h07,8'h96,8'h4b,8'hb0,
                                                  8'h4e,8'h27,8'h86,8'h43,8'hb4,8'h5a,8'h2d,8'h83,8'hbd,8'hcb,8'hf0,8'h78,8'h3c,8'h1e,8'h0f,8'h92,
                                                  8'h29,8'h81,8'hd5,8'hff,8'hea,8'h75,8'haf,8'hc2,8'h45,8'hb7,8'hce,8'h67,8'ha6,8'h53,8'hbc,8'h5e,
                                                  8'hfb,8'he8,8'h74,8'h3a,8'h1d,8'h9b,8'hd8,8'h6c,8'hc2,8'h61,8'ha5,8'hc7,8'hf6,8'h7b,8'ha8,8'h54,
                                                  8'hae,8'h57,8'hbe,8'h5f,8'hba,8'h5d,8'hbb,8'hc8,8'hee,8'h77,8'hae,8'h57,8'hbe,8'h5f,8'hba,8'h5d,
                                                  8'he7,8'he6,8'h73,8'hac,8'h56,8'h2b,8'h80,8'h40,8'hc1,8'hf5,8'hef,8'he2,8'h71,8'had,8'hc3,8'hf4,
                                                  8'h44,8'h22,8'h11,8'h9d,8'hdb,8'hf8,8'h7c,8'h3e,8'hec,8'h76,8'h3b,8'h88,8'h44,8'h22,8'h11,8'h9d,
                                                  8'hf2,8'h79,8'ha9,8'hc1,8'hf5,8'hef,8'he2,8'h71,8'hf8,8'h7c,8'h3e,8'h1f,8'h9a,8'h4d,8'hb3,8'hcc,
                                                  8'h96,8'h4b,8'hb0,8'h58,8'h2c,8'h16,8'h0b,8'h90,8'h4c,8'h26,8'h13,8'h9c,8'h4e,8'h27,8'h86,8'h43,
                                                  8'h9c,8'h4e,8'h27,8'h86,8'h43,8'hb4,8'h5a,8'h2d,8'hdf,8'hfa,8'h7d,8'hab,8'hc0,8'h60,8'h30,8'h18,
                                                  8'hdd,8'hfb,8'he8,8'h74,8'h3a,8'h1d,8'h9b,8'hd8,8'h5d,8'hbb,8'hc8,8'h64,8'h32,8'h19,8'h99,8'hd9,
                                                  8'hfc,8'h7e,8'h3f,8'h8a,8'h45,8'hb7,8'hce,8'h67,8'hb7,8'hce,8'h67,8'ha6,8'h53,8'hbc,8'h5e,8'h2f,
                                                  8'h17,8'h9e,8'h4f,8'hb2,8'h59,8'hb9,8'hc9,8'hf1,8'h14,8'h0a,8'h05,8'h97,8'hde,8'h6f,8'ha2,8'h51,
                                                  8'h57,8'hbe,8'h5f,8'hba,8'h5d,8'hbb,8'hc8,8'h64,8'h2d,8'h83,8'hd4,8'h6a,8'h35,8'h8f,8'hd2,8'h69,
                                                  8'haa,8'h55,8'hbf,8'hca,8'h65,8'ha7,8'hc6,8'h63,8'h14,8'h0a,8'h05,8'h97,8'hde,8'h6f,8'ha2,8'h51,
                                                  8'h52,8'h29,8'h81,8'hd5,8'hff,8'hea,8'h75,8'haf,8'ha0,8'h50,8'h28,8'h14,8'h0a,8'h05,8'h97,8'hde,
                                                  8'h60,8'h30,8'h18,8'h0c,8'h06,8'h03,8'h94,8'h4a,8'h5f,8'hba,8'h5d,8'hbb,8'hc8,8'h64,8'h32,8'h19,
                                                  8'h7b,8'ha8,8'h54,8'h2a,8'h15,8'h9f,8'hda,8'h6d,8'hb2,8'h59,8'hb9,8'hc9,8'hf1,8'hed,8'he3,8'he4,
                                                  8'h21,8'h85,8'hd7,8'hfe,8'h7f,8'haa,8'h55,8'hbf,8'h8c,8'h46,8'h23,8'h84,8'h42,8'h21,8'h85,8'hd7,
                                                  8'hc3,8'hf4,8'h7a,8'h3d,8'h8b,8'hd0,8'h68,8'h34,8'he9,8'he1,8'he5,8'he7,8'he6,8'h73,8'hac,8'h56,
                                                  8'h5a,8'h2d,8'h83,8'hd4,8'h6a,8'h35,8'h8f,8'hd2,8'h13,8'h9c,8'h4e,8'h27,8'h86,8'h43,8'hb4,8'h5a,
                                                  8'hcc,8'h66,8'h33,8'h8c,8'h46,8'h23,8'h84,8'h42,8'h5c,8'h2e,8'h17,8'h9e,8'h4f,8'hb2,8'h59,8'hb9,
                                                  8'h23,8'h84,8'h42,8'h21,8'h85,8'hd7,8'hfe,8'h7f,8'h05,8'h97,8'hde,8'h6f,8'ha2,8'h51,8'hbd,8'hcb,
                                                  8'h69,8'ha1,8'hc5,8'hf7,8'hee,8'h77,8'hae,8'h57,8'h71,8'had,8'hc3,8'hf4,8'h7a,8'h3d,8'h8b,8'hd0,
                                                  8'hc2,8'h61,8'ha5,8'hc7,8'hf6,8'h7b,8'ha8,8'h54,8'h53,8'hbc,8'h5e,8'h2f,8'h82,8'h41,8'hb5,8'hcf,
                                                  8'h4c,8'h26,8'h13,8'h9c,8'h4e,8'h27,8'h86,8'h43,8'hcd,8'hf3,8'hec,8'h76,8'h3b,8'h88,8'h44,8'h22,
                                                  8'h3e,8'h1f,8'h9a,8'h4d,8'hb3,8'hcc,8'h66,8'h33,8'hc5,8'hf7,8'hee,8'h77,8'hae,8'h57,8'hbe,8'h5f,
                                                  8'haa,8'h55,8'hbf,8'hca,8'h65,8'ha7,8'hc6,8'h63,8'hd1,8'hfd,8'heb,8'he0,8'h70,8'h38,8'h1c,8'h0e,
                                                  8'h31,8'h8d,8'hd3,8'hfc,8'h7e,8'h3f,8'h8a,8'h45,8'h50,8'h28,8'h14,8'h0a,8'h05,8'h97,8'hde,8'h6f,
                                                  8'h9b,8'hd8,8'h6c,8'h36,8'h1b,8'h98,8'h4c,8'h26,8'h08,8'h04,8'h02,8'h01,8'h95,8'hdf,8'hfa,8'h7d,
                                                  8'h06,8'h03,8'h94,8'h4a,8'h25,8'h87,8'hd6,8'h6b,8'haa,8'h55,8'hbf,8'hca,8'h65,8'ha7,8'hc6,8'h63,
                                                  8'hfd,8'heb,8'he0,8'h70,8'h38,8'h1c,8'h0e,8'h07,8'h57,8'hbe,8'h5f,8'hba,8'h5d,8'hbb,8'hc8,8'h64,
                                                  8'h38,8'h1c,8'h0e,8'h07,8'h96,8'h4b,8'hb0,8'h58,8'he4,8'h72,8'h39,8'h89,8'hd1,8'hfd,8'heb,8'he0,
                                                  8'h76,8'h3b,8'h88,8'h44,8'h22,8'h11,8'h9d,8'hdb,8'ha2,8'h51,8'hbd,8'hcb,8'hf0,8'h78,8'h3c,8'h1e,
                                                  8'heb,8'he0,8'h70,8'h38,8'h1c,8'h0e,8'h07,8'h96,8'h33,8'h8c,8'h46,8'h23,8'h84,8'h42,8'h21,8'h85,
                                                  8'h5a,8'h2d,8'h83,8'hd4,8'h6a,8'h35,8'h8f,8'hd2,8'h93,8'hdc,8'h6e,8'h37,8'h8e,8'h47,8'hb6,8'h5b,
                                                  8'he4,8'h72,8'h39,8'h89,8'hd1,8'hfd,8'heb,8'he0,8'h84,8'h42,8'h21,8'h85,8'hd7,8'hfe,8'h7f,8'haa,
                                                  8'h11,8'h9d,8'hdb,8'hf8,8'h7c,8'h3e,8'h1f,8'h9a,8'hb3,8'hcc,8'h66,8'h33,8'h8c,8'h46,8'h23,8'h84,
                                                  8'h89,8'hd1,8'hfd,8'heb,8'he0,8'h70,8'h38,8'h1c,8'he0,8'h70,8'h38,8'h1c,8'h0e,8'h07,8'h96,8'h4b,
                                                  8'h55,8'hbf,8'hca,8'h65,8'ha7,8'hc6,8'h63,8'ha4,8'hc2,8'h61,8'ha5,8'hc7,8'hf6,8'h7b,8'ha8,8'h54,
                                                  8'h4d,8'hb3,8'hcc,8'h66,8'h33,8'h8c,8'h46,8'h23,8'ha8,8'h54,8'h2a,8'h15,8'h9f,8'hda,8'h6d,8'ha3,
                                                  8'ha9,8'hc1,8'hf5,8'hef,8'he2,8'h71,8'had,8'hc3,8'h47,8'hb6,8'h5b,8'hb8,8'h5c,8'h2e,8'h17,8'h9e,
                                                  8'hc0,8'h60,8'h30,8'h18,8'h0c,8'h06,8'h03,8'h94,8'h85,8'hd7,8'hfe,8'h7f,8'haa,8'h55,8'hbf,8'hca,
                                                  8'hab,8'hc0,8'h60,8'h30,8'h18,8'h0c,8'h06,8'h03,8'hd7,8'hfe,8'h7f,8'haa,8'h55,8'hbf,8'hca,8'h65,
                                                  8'h9e,8'h4f,8'hb2,8'h59,8'hb9,8'hc9,8'hf1,8'hed,8'hfe,8'h7f,8'haa,8'h55,8'hbf,8'hca,8'h65,8'ha7,
                                                  8'h12,8'h09,8'h91,8'hdd,8'hfb,8'he8,8'h74,8'h3a,8'hd6,8'h6b,8'ha0,8'h50,8'h28,8'h14,8'h0a,8'h05,
                                                  8'hd3,8'hfc,8'h7e,8'h3f,8'h8a,8'h45,8'hb7,8'hce,8'hab,8'hc0,8'h60,8'h30,8'h18,8'h0c,8'h06,8'h03,
                                                  8'h7c,8'h3e,8'h1f,8'h9a,8'h4d,8'hb3,8'hcc,8'h66,8'h99,8'hd9,8'hf9,8'he9,8'he1,8'he5,8'he7,8'he6,
                                                  8'h8a,8'h45,8'hb7,8'hce,8'h67,8'ha6,8'h53,8'hbc,8'h02,8'h01,8'h95,8'hdf,8'hfa,8'h7d,8'hab,8'hc0,
                                                  8'h9b,8'hd8,8'h6c,8'h36,8'h1b,8'h98,8'h4c,8'h26,8'h8b,8'hd0,8'h68,8'h34,8'h1a,8'h0d,8'h93,8'hdc,
                                                  8'h68,8'h34,8'h1a,8'h0d,8'h93,8'hdc,8'h6e,8'h37,8'h74,8'h3a,8'h1d,8'h9b,8'hd8,8'h6c,8'h36,8'h1b,
                                                  8'ha1,8'hc5,8'hf7,8'hee,8'h77,8'hae,8'h57,8'hbe,8'hc5,8'hf7,8'hee,8'h77,8'hae,8'h57,8'hbe,8'h5f,
                                                  8'hf5,8'hef,8'he2,8'h71,8'had,8'hc3,8'hf4,8'h7a,8'hd5,8'hff,8'hea,8'h75,8'haf,8'hc2,8'h61,8'ha5,
                                                  8'h27,8'h86,8'h43,8'hb4,8'h5a,8'h2d,8'h83,8'hd4,8'he3,8'he4,8'h72,8'h39,8'h89,8'hd1,8'hfd,8'heb,
                                                  8'h1e,8'h0f,8'h92,8'h49,8'hb1,8'hcd,8'hf3,8'hec,8'h51,8'hbd,8'hcb,8'hf0,8'h78,8'h3c,8'h1e,8'h0f,
                                                  8'h2a,8'h15,8'h9f,8'hda,8'h6d,8'ha3,8'hc4,8'h62,8'hce,8'h67,8'ha6,8'h53,8'hbc,8'h5e,8'h2f,8'h82,
                                                  8'h8c,8'h46,8'h23,8'h84,8'h42,8'h21,8'h85,8'hd7,8'h06,8'h03,8'h94,8'h4a,8'h25,8'h87,8'hd6,8'h6b,
                                                  8'hb2,8'h59,8'hb9,8'hc9,8'hf1,8'hed,8'he3,8'he4,8'hd1,8'hfd,8'heb,8'he0,8'h70,8'h38,8'h1c,8'h0e,
                                                  8'h32,8'h19,8'h99,8'hd9,8'hf9,8'he9,8'he1,8'he5,8'h6a,8'h35,8'h8f,8'hd2,8'h69,8'ha1,8'hc5,8'hf7,
                                                  8'h62,8'h31,8'h8d,8'hd3,8'hfc,8'h7e,8'h3f,8'h8a,8'ha7,8'hc6,8'h63,8'ha4,8'h52,8'h29,8'h81,8'hd5,
                                                  8'h0e,8'h07,8'h96,8'h4b,8'hb0,8'h58,8'h2c,8'h16,8'hc5,8'hf7,8'hee,8'h77,8'hae,8'h57,8'hbe,8'h5f,
                                                  8'hba,8'h5d,8'hbb,8'hc8,8'h64,8'h32,8'h19,8'h99,8'h8d,8'hd3,8'hfc,8'h7e,8'h3f,8'h8a,8'h45,8'hb7,
                                                  8'h82,8'h41,8'hb5,8'hcf,8'hf2,8'h79,8'ha9,8'hc1,8'h76,8'h3b,8'h88,8'h44,8'h22,8'h11,8'h9d,8'hdb,
                                                  8'h7e,8'h3f,8'h8a,8'h45,8'hb7,8'hce,8'h67,8'ha6,8'h90,8'h48,8'h24,8'h12,8'h09,8'h91,8'hdd,8'hfb,
                                                  8'he3,8'he4,8'h72,8'h39,8'h89,8'hd1,8'hfd,8'heb,8'h44,8'h22,8'h11,8'h9d,8'hdb,8'hf8,8'h7c,8'h3e,
                                                  8'h30,8'h18,8'h0c,8'h06,8'h03,8'h94,8'h4a,8'h25,8'h88,8'h44,8'h22,8'h11,8'h9d,8'hdb,8'hf8,8'h7c,
                                                  8'h67,8'ha6,8'h53,8'hbc,8'h5e,8'h2f,8'h82,8'h41,8'hd0,8'h68,8'h34,8'h1a,8'h0d,8'h93,8'hdc,8'h6e,
                                                  8'h57,8'hbe,8'h5f,8'hba,8'h5d,8'hbb,8'hc8,8'h64,8'h85,8'hd7,8'hfe,8'h7f,8'haa,8'h55,8'hbf,8'hca,
                                                  8'h49,8'hb1,8'hcd,8'hf3,8'hec,8'h76,8'h3b,8'h88,8'haa,8'h55,8'hbf,8'hca,8'h65,8'ha7,8'hc6,8'h63,
                                                  8'hcb,8'hf0,8'h78,8'h3c,8'h1e,8'h0f,8'h92,8'h49,8'h31,8'h8d,8'hd3,8'hfc,8'h7e,8'h3f,8'h8a,8'h45,
                                                  8'he2,8'h71,8'had,8'hc3,8'hf4,8'h7a,8'h3d,8'h8b,8'h22,8'h11,8'h9d,8'hdb,8'hf8,8'h7c,8'h3e,8'h1f,
                                                  8'h2d,8'h83,8'hd4,8'h6a,8'h35,8'h8f,8'hd2,8'h69,8'h81,8'hd5,8'hff,8'hea,8'h75,8'haf,8'hc2,8'h61};
  
  localparam [(P_FLIT_WD * 8) - 1 : 0] P_COEF6 =  {P_ZERO_PAD,
                                                  8'had,8'hc3,8'hf4,8'h7a,8'h3d,8'h8b,8'hd0,8'h68,8'h2c,8'h16,8'h0b,8'h90,8'h48,8'h24,8'h12,8'h09,
                                                  8'h38,8'h1c,8'h0e,8'h07,8'h96,8'h4b,8'hb0,8'h58,8'h71,8'had,8'hc3,8'hf4,8'h7a,8'h3d,8'h8b,8'hd0,
                                                  8'h4a,8'h25,8'h87,8'hd6,8'h6b,8'ha0,8'h50,8'h28,8'hba,8'h5d,8'hbb,8'hc8,8'h64,8'h32,8'h19,8'h99,
                                                  8'hdf,8'hfa,8'h7d,8'hab,8'hc0,8'h60,8'h30,8'h18,8'h6a,8'h35,8'h8f,8'hd2,8'h69,8'ha1,8'hc5,8'hf7,
                                                  8'hb6,8'h5b,8'hb8,8'h5c,8'h2e,8'h17,8'h9e,8'h4f,8'h1d,8'h9b,8'hd8,8'h6c,8'h36,8'h1b,8'h98,8'h4c,
                                                  8'h16,8'h0b,8'h90,8'h48,8'h24,8'h12,8'h09,8'h91,8'h35,8'h8f,8'hd2,8'h69,8'ha1,8'hc5,8'hf7,8'hee,
                                                  8'h8c,8'h46,8'h23,8'h84,8'h42,8'h21,8'h85,8'hd7,8'h79,8'ha9,8'hc1,8'hf5,8'hef,8'he2,8'h71,8'had,
                                                  8'h4a,8'h25,8'h87,8'hd6,8'h6b,8'ha0,8'h50,8'h28,8'h93,8'hdc,8'h6e,8'h37,8'h8e,8'h47,8'hb6,8'h5b,
                                                  8'h78,8'h3c,8'h1e,8'h0f,8'h92,8'h49,8'hb1,8'hcd,8'hef,8'he2,8'h71,8'had,8'hc3,8'hf4,8'h7a,8'h3d,
                                                  8'hda,8'h6d,8'ha3,8'hc4,8'h62,8'h31,8'h8d,8'hd3,8'h69,8'ha1,8'hc5,8'hf7,8'hee,8'h77,8'hae,8'h57,
                                                  8'h03,8'h94,8'h4a,8'h25,8'h87,8'hd6,8'h6b,8'ha0,8'hb7,8'hce,8'h67,8'ha6,8'h53,8'hbc,8'h5e,8'h2f,
                                                  8'h1f,8'h9a,8'h4d,8'hb3,8'hcc,8'h66,8'h33,8'h8c,8'h94,8'h4a,8'h25,8'h87,8'hd6,8'h6b,8'ha0,8'h50,
                                                  8'hc2,8'h61,8'ha5,8'hc7,8'hf6,8'h7b,8'ha8,8'h54,8'h34,8'h1a,8'h0d,8'h93,8'hdc,8'h6e,8'h37,8'h8e,
                                                  8'h9a,8'h4d,8'hb3,8'hcc,8'h66,8'h33,8'h8c,8'h46,8'h92,8'h49,8'hb1,8'hcd,8'hf3,8'hec,8'h76,8'h3b,
                                                  8'hc0,8'h60,8'h30,8'h18,8'h0c,8'h06,8'h03,8'h94,8'he4,8'h72,8'h39,8'h89,8'hd1,8'hfd,8'heb,8'he0,
                                                  8'h8b,8'hd0,8'h68,8'h34,8'h1a,8'h0d,8'h93,8'hdc,8'h25,8'h87,8'hd6,8'h6b,8'ha0,8'h50,8'h28,8'h14,
                                                  8'h47,8'hb6,8'h5b,8'hb8,8'h5c,8'h2e,8'h17,8'h9e,8'hc5,8'hf7,8'hee,8'h77,8'hae,8'h57,8'hbe,8'h5f,
                                                  8'h5e,8'h2f,8'h82,8'h41,8'hb5,8'hcf,8'hf2,8'h79,8'hb3,8'hcc,8'h66,8'h33,8'h8c,8'h46,8'h23,8'h84,
                                                  8'hde,8'h6f,8'ha2,8'h51,8'hbd,8'hcb,8'hf0,8'h78,8'h11,8'h9d,8'hdb,8'hf8,8'h7c,8'h3e,8'h1f,8'h9a,
                                                  8'haf,8'hc2,8'h61,8'ha5,8'hc7,8'hf6,8'h7b,8'ha8,8'h5c,8'h2e,8'h17,8'h9e,8'h4f,8'hb2,8'h59,8'hb9,
                                                  8'h3b,8'h88,8'h44,8'h22,8'h11,8'h9d,8'hdb,8'hf8,8'h9a,8'h4d,8'hb3,8'hcc,8'h66,8'h33,8'h8c,8'h46,
                                                  8'h4a,8'h25,8'h87,8'hd6,8'h6b,8'ha0,8'h50,8'h28,8'h22,8'h11,8'h9d,8'hdb,8'hf8,8'h7c,8'h3e,8'h1f,
                                                  8'hc9,8'hf1,8'hed,8'he3,8'he4,8'h72,8'h39,8'h89,8'h0d,8'h93,8'hdc,8'h6e,8'h37,8'h8e,8'h47,8'hb6,
                                                  8'h79,8'ha9,8'hc1,8'hf5,8'hef,8'he2,8'h71,8'had,8'hf3,8'hec,8'h76,8'h3b,8'h88,8'h44,8'h22,8'h11,
                                                  8'ha5,8'hc7,8'hf6,8'h7b,8'ha8,8'h54,8'h2a,8'h15,8'h5b,8'hb8,8'h5c,8'h2e,8'h17,8'h9e,8'h4f,8'hb2,
                                                  8'h46,8'h23,8'h84,8'h42,8'h21,8'h85,8'hd7,8'hfe,8'h52,8'h29,8'h81,8'hd5,8'hff,8'hea,8'h75,8'haf,
                                                  8'h41,8'hb5,8'hcf,8'hf2,8'h79,8'ha9,8'hc1,8'hf5,8'h26,8'h13,8'h9c,8'h4e,8'h27,8'h86,8'h43,8'hb4,
                                                  8'h22,8'h11,8'h9d,8'hdb,8'hf8,8'h7c,8'h3e,8'h1f,8'hdd,8'hfb,8'he8,8'h74,8'h3a,8'h1d,8'h9b,8'hd8,
                                                  8'he4,8'h72,8'h39,8'h89,8'hd1,8'hfd,8'heb,8'he0,8'hf4,8'h7a,8'h3d,8'h8b,8'hd0,8'h68,8'h34,8'h1a,
                                                  8'h35,8'h8f,8'hd2,8'h69,8'ha1,8'hc5,8'hf7,8'hee,8'hf0,8'h78,8'h3c,8'h1e,8'h0f,8'h92,8'h49,8'hb1,
                                                  8'ha0,8'h50,8'h28,8'h14,8'h0a,8'h05,8'h97,8'hde,8'hc7,8'hf6,8'h7b,8'ha8,8'h54,8'h2a,8'h15,8'h9f,
                                                  8'h0a,8'h05,8'h97,8'hde,8'h6f,8'ha2,8'h51,8'hbd,8'h75,8'haf,8'hc2,8'h61,8'ha5,8'hc7,8'hf6,8'h7b,
                                                  8'h42,8'h21,8'h85,8'hd7,8'hfe,8'h7f,8'haa,8'h55,8'hc0,8'h60,8'h30,8'h18,8'h0c,8'h06,8'h03,8'h94,
                                                  8'h29,8'h81,8'hd5,8'hff,8'hea,8'h75,8'haf,8'hc2,8'h0e,8'h07,8'h96,8'h4b,8'hb0,8'h58,8'h2c,8'h16,
                                                  8'he5,8'he7,8'he6,8'h73,8'hac,8'h56,8'h2b,8'h80,8'hc2,8'h61,8'ha5,8'hc7,8'hf6,8'h7b,8'ha8,8'h54,
                                                  8'he1,8'he5,8'he7,8'he6,8'h73,8'hac,8'h56,8'h2b,8'h48,8'h24,8'h12,8'h09,8'h91,8'hdd,8'hfb,8'he8,
                                                  8'h68,8'h34,8'h1a,8'h0d,8'h93,8'hdc,8'h6e,8'h37,8'h64,8'h32,8'h19,8'h99,8'hd9,8'hf9,8'he9,8'he1,
                                                  8'hdb,8'hf8,8'h7c,8'h3e,8'h1f,8'h9a,8'h4d,8'hb3,8'h22,8'h11,8'h9d,8'hdb,8'hf8,8'h7c,8'h3e,8'h1f,
                                                  8'h99,8'hd9,8'hf9,8'he9,8'he1,8'he5,8'he7,8'he6,8'h42,8'h21,8'h85,8'hd7,8'hfe,8'h7f,8'haa,8'h55,
                                                  8'h41,8'hb5,8'hcf,8'hf2,8'h79,8'ha9,8'hc1,8'hf5,8'hc2,8'h61,8'ha5,8'hc7,8'hf6,8'h7b,8'ha8,8'h54,
                                                  8'h79,8'ha9,8'hc1,8'hf5,8'hef,8'he2,8'h71,8'had,8'h8b,8'hd0,8'h68,8'h34,8'h1a,8'h0d,8'h93,8'hdc,
                                                  8'h8d,8'hd3,8'hfc,8'h7e,8'h3f,8'h8a,8'h45,8'hb7,8'h67,8'ha6,8'h53,8'hbc,8'h5e,8'h2f,8'h82,8'h41,
                                                  8'h99,8'hd9,8'hf9,8'he9,8'he1,8'he5,8'he7,8'he6,8'hf1,8'hed,8'he3,8'he4,8'h72,8'h39,8'h89,8'hd1,
                                                  8'h4b,8'hb0,8'h58,8'h2c,8'h16,8'h0b,8'h90,8'h48,8'h93,8'hdc,8'h6e,8'h37,8'h8e,8'h47,8'hb6,8'h5b,
                                                  8'h96,8'h4b,8'hb0,8'h58,8'h2c,8'h16,8'h0b,8'h90,8'h24,8'h12,8'h09,8'h91,8'hdd,8'hfb,8'he8,8'h74,
                                                  8'h3f,8'h8a,8'h45,8'hb7,8'hce,8'h67,8'ha6,8'h53,8'hf1,8'hed,8'he3,8'he4,8'h72,8'h39,8'h89,8'hd1,
                                                  8'hd0,8'h68,8'h34,8'h1a,8'h0d,8'h93,8'hdc,8'h6e,8'hc6,8'h63,8'ha4,8'h52,8'h29,8'h81,8'hd5,8'hff,
                                                  8'h73,8'hac,8'h56,8'h2b,8'h80,8'h40,8'h20,8'h10,8'h2d,8'h83,8'hd4,8'h6a,8'h35,8'h8f,8'hd2,8'h69,
                                                  8'haf,8'hc2,8'h61,8'ha5,8'hc7,8'hf6,8'h7b,8'ha8,8'hee,8'h77,8'hae,8'h57,8'hbe,8'h5f,8'hba,8'h5d,
                                                  8'he2,8'h71,8'had,8'hc3,8'hf4,8'h7a,8'h3d,8'h8b,8'h4f,8'hb2,8'h59,8'hb9,8'hc9,8'hf1,8'hed,8'he3,
                                                  8'h81,8'hd5,8'hff,8'hea,8'h75,8'haf,8'hc2,8'h61,8'he7,8'he6,8'h73,8'hac,8'h56,8'h2b,8'h80,8'h40,
                                                  8'ha1,8'hc5,8'hf7,8'hee,8'h77,8'hae,8'h57,8'hbe,8'hc1,8'hf5,8'hef,8'he2,8'h71,8'had,8'hc3,8'hf4,
                                                  8'h62,8'h31,8'h8d,8'hd3,8'hfc,8'h7e,8'h3f,8'h8a,8'h4e,8'h27,8'h86,8'h43,8'hb4,8'h5a,8'h2d,8'h83,
                                                  8'hd0,8'h68,8'h34,8'h1a,8'h0d,8'h93,8'hdc,8'h6e,8'h1f,8'h9a,8'h4d,8'hb3,8'hcc,8'h66,8'h33,8'h8c,
                                                  8'hbe,8'h5f,8'hba,8'h5d,8'hbb,8'hc8,8'h64,8'h32,8'hf0,8'h78,8'h3c,8'h1e,8'h0f,8'h92,8'h49,8'hb1,
                                                  8'h03,8'h94,8'h4a,8'h25,8'h87,8'hd6,8'h6b,8'ha0,8'h8b,8'hd0,8'h68,8'h34,8'h1a,8'h0d,8'h93,8'hdc,
                                                  8'hdf,8'hfa,8'h7d,8'hab,8'hc0,8'h60,8'h30,8'h18,8'h62,8'h31,8'h8d,8'hd3,8'hfc,8'h7e,8'h3f,8'h8a,
                                                  8'he7,8'he6,8'h73,8'hac,8'h56,8'h2b,8'h80,8'h40,8'h21,8'h85,8'hd7,8'hfe,8'h7f,8'haa,8'h55,8'hbf,
                                                  8'ha7,8'hc6,8'h63,8'ha4,8'h52,8'h29,8'h81,8'hd5,8'h37,8'h8e,8'h47,8'hb6,8'h5b,8'hb8,8'h5c,8'h2e,
                                                  8'h36,8'h1b,8'h98,8'h4c,8'h26,8'h13,8'h9c,8'h4e,8'h30,8'h18,8'h0c,8'h06,8'h03,8'h94,8'h4a,8'h25,
                                                  8'h6a,8'h35,8'h8f,8'hd2,8'h69,8'ha1,8'hc5,8'hf7,8'h0a,8'h05,8'h97,8'hde,8'h6f,8'ha2,8'h51,8'hbd,
                                                  8'hcd,8'hf3,8'hec,8'h76,8'h3b,8'h88,8'h44,8'h22,8'hda,8'h6d,8'ha3,8'hc4,8'h62,8'h31,8'h8d,8'hd3,
                                                  8'h32,8'h19,8'h99,8'hd9,8'hf9,8'he9,8'he1,8'he5,8'h67,8'ha6,8'h53,8'hbc,8'h5e,8'h2f,8'h82,8'h41,
                                                  8'h03,8'h94,8'h4a,8'h25,8'h87,8'hd6,8'h6b,8'ha0,8'hdf,8'hfa,8'h7d,8'hab,8'hc0,8'h60,8'h30,8'h18,
                                                  8'h43,8'hb4,8'h5a,8'h2d,8'h83,8'hd4,8'h6a,8'h35,8'ha4,8'h52,8'h29,8'h81,8'hd5,8'hff,8'hea,8'h75,
                                                  8'hfa,8'h7d,8'hab,8'hc0,8'h60,8'h30,8'h18,8'h0c,8'h36,8'h1b,8'h98,8'h4c,8'h26,8'h13,8'h9c,8'h4e,
                                                  8'hb5,8'hcf,8'hf2,8'h79,8'ha9,8'hc1,8'hf5,8'hef,8'hc0,8'h60,8'h30,8'h18,8'h0c,8'h06,8'h03,8'h94,
                                                  8'h3a,8'h1d,8'h9b,8'hd8,8'h6c,8'h36,8'h1b,8'h98,8'h1f,8'h9a,8'h4d,8'hb3,8'hcc,8'h66,8'h33,8'h8c,
                                                  8'hdc,8'h6e,8'h37,8'h8e,8'h47,8'hb6,8'h5b,8'hb8,8'hdf,8'hfa,8'h7d,8'hab,8'hc0,8'h60,8'h30,8'h18,
                                                  8'ha2,8'h51,8'hbd,8'hcb,8'hf0,8'h78,8'h3c,8'h1e,8'h3c,8'h1e,8'h0f,8'h92,8'h49,8'hb1,8'hcd,8'hf3,
                                                  8'h46,8'h23,8'h84,8'h42,8'h21,8'h85,8'hd7,8'hfe,8'h3a,8'h1d,8'h9b,8'hd8,8'h6c,8'h36,8'h1b,8'h98,
                                                  8'h32,8'h19,8'h99,8'hd9,8'hf9,8'he9,8'he1,8'he5,8'h95,8'hdf,8'hfa,8'h7d,8'hab,8'hc0,8'h60,8'h30,
                                                  8'h53,8'hbc,8'h5e,8'h2f,8'h82,8'h41,8'hb5,8'hcf,8'h16,8'h0b,8'h90,8'h48,8'h24,8'h12,8'h09,8'h91,
                                                  8'hb3,8'hcc,8'h66,8'h33,8'h8c,8'h46,8'h23,8'h84,8'h7a,8'h3d,8'h8b,8'hd0,8'h68,8'h34,8'h1a,8'h0d,
                                                  8'h70,8'h38,8'h1c,8'h0e,8'h07,8'h96,8'h4b,8'hb0,8'hf1,8'hed,8'he3,8'he4,8'h72,8'h39,8'h89,8'hd1,
                                                  8'hf8,8'h7c,8'h3e,8'h1f,8'h9a,8'h4d,8'hb3,8'hcc,8'h37,8'h8e,8'h47,8'hb6,8'h5b,8'hb8,8'h5c,8'h2e,
                                                  8'hc6,8'h63,8'ha4,8'h52,8'h29,8'h81,8'hd5,8'hff,8'h21,8'h85,8'hd7,8'hfe,8'h7f,8'haa,8'h55,8'hbf,
                                                  8'h42,8'h21,8'h85,8'hd7,8'hfe,8'h7f,8'haa,8'h55,8'hf9,8'he9,8'he1,8'he5,8'he7,8'he6,8'h73,8'hac,
                                                  8'h0d,8'h93,8'hdc,8'h6e,8'h37,8'h8e,8'h47,8'hb6,8'h54,8'h2a,8'h15,8'h9f,8'hda,8'h6d,8'ha3,8'hc4,
                                                  8'h02,8'h01,8'h95,8'hdf,8'hfa,8'h7d,8'hab,8'hc0,8'hea,8'h75,8'haf,8'hc2,8'h61,8'ha5,8'hc7,8'hf6,
                                                  8'h5f,8'hba,8'h5d,8'hbb,8'hc8,8'h64,8'h32,8'h19,8'h27,8'h86,8'h43,8'hb4,8'h5a,8'h2d,8'h83,8'hd4,
                                                  8'h71,8'had,8'hc3,8'hf4,8'h7a,8'h3d,8'h8b,8'hd0,8'h5d,8'hbb,8'hc8,8'h64,8'h32,8'h19,8'h99,8'hd9,
                                                  8'h0b,8'h90,8'h48,8'h24,8'h12,8'h09,8'h91,8'hdd,8'hae,8'h57,8'hbe,8'h5f,8'hba,8'h5d,8'hbb,8'hc8,
                                                  8'h37,8'h8e,8'h47,8'hb6,8'h5b,8'hb8,8'h5c,8'h2e,8'hc9,8'hf1,8'hed,8'he3,8'he4,8'h72,8'h39,8'h89,
                                                  8'h22,8'h11,8'h9d,8'hdb,8'hf8,8'h7c,8'h3e,8'h1f,8'hb3,8'hcc,8'h66,8'h33,8'h8c,8'h46,8'h23,8'h84,
                                                  8'haf,8'hc2,8'h61,8'ha5,8'hc7,8'hf6,8'h7b,8'ha8,8'h9f,8'hda,8'h6d,8'ha3,8'hc4,8'h62,8'h31,8'h8d,
                                                  8'hc2,8'h61,8'ha5,8'hc7,8'hf6,8'h7b,8'ha8,8'h54,8'hbd,8'hcb,8'hf0,8'h78,8'h3c,8'h1e,8'h0f,8'h92,
                                                  8'hc0,8'h60,8'h30,8'h18,8'h0c,8'h06,8'h03,8'h94,8'h57,8'hbe,8'h5f,8'hba,8'h5d,8'hbb,8'hc8,8'h64,
                                                  8'h5c,8'h2e,8'h17,8'h9e,8'h4f,8'hb2,8'h59,8'hb9,8'had,8'hc3,8'hf4,8'h7a,8'h3d,8'h8b,8'hd0,8'h68,
                                                  8'hc0,8'h60,8'h30,8'h18,8'h0c,8'h06,8'h03,8'h94,8'h3f,8'h8a,8'h45,8'hb7,8'hce,8'h67,8'ha6,8'h53,
                                                  8'h04,8'h02,8'h01,8'h95,8'hdf,8'hfa,8'h7d,8'hab,8'h7b,8'ha8,8'h54,8'h2a,8'h15,8'h9f,8'hda,8'h6d,
                                                  8'he4,8'h72,8'h39,8'h89,8'hd1,8'hfd,8'heb,8'he0,8'hf0,8'h78,8'h3c,8'h1e,8'h0f,8'h92,8'h49,8'hb1,
                                                  8'h15,8'h9f,8'hda,8'h6d,8'ha3,8'hc4,8'h62,8'h31,8'h26,8'h13,8'h9c,8'h4e,8'h27,8'h86,8'h43,8'hb4,
                                                  8'h07,8'h96,8'h4b,8'hb0,8'h58,8'h2c,8'h16,8'h0b,8'h4e,8'h27,8'h86,8'h43,8'hb4,8'h5a,8'h2d,8'h83,
                                                  8'hf3,8'hec,8'h76,8'h3b,8'h88,8'h44,8'h22,8'h11,8'hbe,8'h5f,8'hba,8'h5d,8'hbb,8'hc8,8'h64,8'h32,
                                                  8'h3a,8'h1d,8'h9b,8'hd8,8'h6c,8'h36,8'h1b,8'h98,8'hbe,8'h5f,8'hba,8'h5d,8'hbb,8'hc8,8'h64,8'h32,
                                                  8'he3,8'he4,8'h72,8'h39,8'h89,8'hd1,8'hfd,8'heb,8'h0e,8'h07,8'h96,8'h4b,8'hb0,8'h58,8'h2c,8'h16,
                                                  8'h76,8'h3b,8'h88,8'h44,8'h22,8'h11,8'h9d,8'hdb,8'h1a,8'h0d,8'h93,8'hdc,8'h6e,8'h37,8'h8e,8'h47,
                                                  8'h8e,8'h47,8'hb6,8'h5b,8'hb8,8'h5c,8'h2e,8'h17,8'hc9,8'hf1,8'hed,8'he3,8'he4,8'h72,8'h39,8'h89,
                                                  8'h83,8'hd4,8'h6a,8'h35,8'h8f,8'hd2,8'h69,8'ha1,8'h89,8'hd1,8'hfd,8'heb,8'he0,8'h70,8'h38,8'h1c,
                                                  8'hd4,8'h6a,8'h35,8'h8f,8'hd2,8'h69,8'ha1,8'hc5,8'h68,8'h34,8'h1a,8'h0d,8'h93,8'hdc,8'h6e,8'h37,
                                                  8'h8f,8'hd2,8'h69,8'ha1,8'hc5,8'hf7,8'hee,8'h77,8'h1e,8'h0f,8'h92,8'h49,8'hb1,8'hcd,8'hf3,8'hec,
                                                  8'hfd,8'heb,8'he0,8'h70,8'h38,8'h1c,8'h0e,8'h07,8'h48,8'h24,8'h12,8'h09,8'h91,8'hdd,8'hfb,8'he8,
                                                  8'h0f,8'h92,8'h49,8'hb1,8'hcd,8'hf3,8'hec,8'h76,8'h9d,8'hdb,8'hf8,8'h7c,8'h3e,8'h1f,8'h9a,8'h4d,
                                                  8'h7e,8'h3f,8'h8a,8'h45,8'hb7,8'hce,8'h67,8'ha6,8'h17,8'h9e,8'h4f,8'hb2,8'h59,8'hb9,8'hc9,8'hf1,
                                                  8'hda,8'h6d,8'ha3,8'hc4,8'h62,8'h31,8'h8d,8'hd3,8'h1a,8'h0d,8'h93,8'hdc,8'h6e,8'h37,8'h8e,8'h47,
                                                  8'h30,8'h18,8'h0c,8'h06,8'h03,8'h94,8'h4a,8'h25,8'h22,8'h11,8'h9d,8'hdb,8'hf8,8'h7c,8'h3e,8'h1f,
                                                  8'h2c,8'h16,8'h0b,8'h90,8'h48,8'h24,8'h12,8'h09,8'h14,8'h0a,8'h05,8'h97,8'hde,8'h6f,8'ha2,8'h51,
                                                  8'h83,8'hd4,8'h6a,8'h35,8'h8f,8'hd2,8'h69,8'ha1,8'hb7,8'hce,8'h67,8'ha6,8'h53,8'hbc,8'h5e,8'h2f,
                                                  8'h3f,8'h8a,8'h45,8'hb7,8'hce,8'h67,8'ha6,8'h53,8'h27,8'h86,8'h43,8'hb4,8'h5a,8'h2d,8'h83,8'hd4,
                                                  8'h3e,8'h1f,8'h9a,8'h4d,8'hb3,8'hcc,8'h66,8'h33,8'h8b,8'hd0,8'h68,8'h34,8'h1a,8'h0d,8'h93,8'hdc,
                                                  8'h50,8'h28,8'h14,8'h0a,8'h05,8'h97,8'hde,8'h6f,8'hd7,8'hfe,8'h7f,8'haa,8'h55,8'hbf,8'hca,8'h65,
                                                  8'h6b,8'ha0,8'h50,8'h28,8'h14,8'h0a,8'h05,8'h97,8'he0,8'h70,8'h38,8'h1c,8'h0e,8'h07,8'h96,8'h4b,
                                                  8'h12,8'h09,8'h91,8'hdd,8'hfb,8'he8,8'h74,8'h3a,8'hdf,8'hfa,8'h7d,8'hab,8'hc0,8'h60,8'h30,8'h18,
                                                  8'h4f,8'hb2,8'h59,8'hb9,8'hc9,8'hf1,8'hed,8'he3,8'h92,8'h49,8'hb1,8'hcd,8'hf3,8'hec,8'h76,8'h3b,
                                                  8'h08,8'h04,8'h02,8'h01,8'h95,8'hdf,8'hfa,8'h7d,8'h92,8'h49,8'hb1,8'hcd,8'hf3,8'hec,8'h76,8'h3b,
                                                  8'h9a,8'h4d,8'hb3,8'hcc,8'h66,8'h33,8'h8c,8'h46,8'h12,8'h09,8'h91,8'hdd,8'hfb,8'he8,8'h74,8'h3a,
                                                  8'heb,8'he0,8'h70,8'h38,8'h1c,8'h0e,8'h07,8'h96,8'hdc,8'h6e,8'h37,8'h8e,8'h47,8'hb6,8'h5b,8'hb8,
                                                  8'h56,8'h2b,8'h80,8'h40,8'h20,8'h10,8'h08,8'h04,8'hf0,8'h78,8'h3c,8'h1e,8'h0f,8'h92,8'h49,8'hb1,
                                                  8'ha1,8'hc5,8'hf7,8'hee,8'h77,8'hae,8'h57,8'hbe,8'hcf,8'hf2,8'h79,8'ha9,8'hc1,8'hf5,8'hef,8'he2,
                                                  8'h4c,8'h26,8'h13,8'h9c,8'h4e,8'h27,8'h86,8'h43,8'h5c,8'h2e,8'h17,8'h9e,8'h4f,8'hb2,8'h59,8'hb9};
  
  localparam [(P_FLIT_WD * 8) - 1 : 0] P_COEF5 =  {P_ZERO_PAD,
                                                  8'h46,8'h23,8'h84,8'h42,8'h21,8'h85,8'hd7,8'hfe,8'hc9,8'hf1,8'hed,8'he3,8'he4,8'h72,8'h39,8'h89,
                                                  8'h40,8'h20,8'h10,8'h08,8'h04,8'h02,8'h01,8'h95,8'heb,8'he0,8'h70,8'h38,8'h1c,8'h0e,8'h07,8'h96,
                                                  8'h8e,8'h47,8'hb6,8'h5b,8'hb8,8'h5c,8'h2e,8'h17,8'h1f,8'h9a,8'h4d,8'hb3,8'hcc,8'h66,8'h33,8'h8c,
                                                  8'hc5,8'hf7,8'hee,8'h77,8'hae,8'h57,8'hbe,8'h5f,8'h47,8'hb6,8'h5b,8'hb8,8'h5c,8'h2e,8'h17,8'h9e,
                                                  8'hb4,8'h5a,8'h2d,8'h83,8'hd4,8'h6a,8'h35,8'h8f,8'h2d,8'h83,8'hd4,8'h6a,8'h35,8'h8f,8'hd2,8'h69,
                                                  8'h50,8'h28,8'h14,8'h0a,8'h05,8'h97,8'hde,8'h6f,8'hf4,8'h7a,8'h3d,8'h8b,8'hd0,8'h68,8'h34,8'h1a,
                                                  8'h47,8'hb6,8'h5b,8'hb8,8'h5c,8'h2e,8'h17,8'h9e,8'h6c,8'h36,8'h1b,8'h98,8'h4c,8'h26,8'h13,8'h9c,
                                                  8'h40,8'h20,8'h10,8'h08,8'h04,8'h02,8'h01,8'h95,8'hc7,8'hf6,8'h7b,8'ha8,8'h54,8'h2a,8'h15,8'h9f,
                                                  8'hcf,8'hf2,8'h79,8'ha9,8'hc1,8'hf5,8'hef,8'he2,8'hc9,8'hf1,8'hed,8'he3,8'he4,8'h72,8'h39,8'h89,
                                                  8'h0d,8'h93,8'hdc,8'h6e,8'h37,8'h8e,8'h47,8'hb6,8'h76,8'h3b,8'h88,8'h44,8'h22,8'h11,8'h9d,8'hdb,
                                                  8'h28,8'h14,8'h0a,8'h05,8'h97,8'hde,8'h6f,8'ha2,8'h8b,8'hd0,8'h68,8'h34,8'h1a,8'h0d,8'h93,8'hdc,
                                                  8'hae,8'h57,8'hbe,8'h5f,8'hba,8'h5d,8'hbb,8'hc8,8'ha2,8'h51,8'hbd,8'hcb,8'hf0,8'h78,8'h3c,8'h1e,
                                                  8'hcd,8'hf3,8'hec,8'h76,8'h3b,8'h88,8'h44,8'h22,8'h05,8'h97,8'hde,8'h6f,8'ha2,8'h51,8'hbd,8'hcb,
                                                  8'hbb,8'hc8,8'h64,8'h32,8'h19,8'h99,8'hd9,8'hf9,8'h1e,8'h0f,8'h92,8'h49,8'hb1,8'hcd,8'hf3,8'hec,
                                                  8'hdc,8'h6e,8'h37,8'h8e,8'h47,8'hb6,8'h5b,8'hb8,8'h70,8'h38,8'h1c,8'h0e,8'h07,8'h96,8'h4b,8'hb0,
                                                  8'h94,8'h4a,8'h25,8'h87,8'hd6,8'h6b,8'ha0,8'h50,8'hda,8'h6d,8'ha3,8'hc4,8'h62,8'h31,8'h8d,8'hd3,
                                                  8'h7f,8'haa,8'h55,8'hbf,8'hca,8'h65,8'ha7,8'hc6,8'h1d,8'h9b,8'hd8,8'h6c,8'h36,8'h1b,8'h98,8'h4c,
                                                  8'hac,8'h56,8'h2b,8'h80,8'h40,8'h20,8'h10,8'h08,8'h8a,8'h45,8'hb7,8'hce,8'h67,8'ha6,8'h53,8'hbc,
                                                  8'hc1,8'hf5,8'hef,8'he2,8'h71,8'had,8'hc3,8'hf4,8'h18,8'h0c,8'h06,8'h03,8'h94,8'h4a,8'h25,8'h87,
                                                  8'h53,8'hbc,8'h5e,8'h2f,8'h82,8'h41,8'hb5,8'hcf,8'h43,8'hb4,8'h5a,8'h2d,8'h83,8'hd4,8'h6a,8'h35,
                                                  8'hc6,8'h63,8'ha4,8'h52,8'h29,8'h81,8'hd5,8'hff,8'h58,8'h2c,8'h16,8'h0b,8'h90,8'h48,8'h24,8'h12,
                                                  8'h3d,8'h8b,8'hd0,8'h68,8'h34,8'h1a,8'h0d,8'h93,8'h6c,8'h36,8'h1b,8'h98,8'h4c,8'h26,8'h13,8'h9c,
                                                  8'h11,8'h9d,8'hdb,8'hf8,8'h7c,8'h3e,8'h1f,8'h9a,8'h9d,8'hdb,8'hf8,8'h7c,8'h3e,8'h1f,8'h9a,8'h4d,
                                                  8'h06,8'h03,8'h94,8'h4a,8'h25,8'h87,8'hd6,8'h6b,8'he7,8'he6,8'h73,8'hac,8'h56,8'h2b,8'h80,8'h40,
                                                  8'h44,8'h22,8'h11,8'h9d,8'hdb,8'hf8,8'h7c,8'h3e,8'h77,8'hae,8'h57,8'hbe,8'h5f,8'hba,8'h5d,8'hbb,
                                                  8'h7c,8'h3e,8'h1f,8'h9a,8'h4d,8'hb3,8'hcc,8'h66,8'h40,8'h20,8'h10,8'h08,8'h04,8'h02,8'h01,8'h95,
                                                  8'h9a,8'h4d,8'hb3,8'hcc,8'h66,8'h33,8'h8c,8'h46,8'h92,8'h49,8'hb1,8'hcd,8'hf3,8'hec,8'h76,8'h3b,
                                                  8'h12,8'h09,8'h91,8'hdd,8'hfb,8'he8,8'h74,8'h3a,8'h8e,8'h47,8'hb6,8'h5b,8'hb8,8'h5c,8'h2e,8'h17,
                                                  8'h48,8'h24,8'h12,8'h09,8'h91,8'hdd,8'hfb,8'he8,8'h3f,8'h8a,8'h45,8'hb7,8'hce,8'h67,8'ha6,8'h53,
                                                  8'h48,8'h24,8'h12,8'h09,8'h91,8'hdd,8'hfb,8'he8,8'hff,8'hea,8'h75,8'haf,8'hc2,8'h61,8'ha5,8'hc7,
                                                  8'h6a,8'h35,8'h8f,8'hd2,8'h69,8'ha1,8'hc5,8'hf7,8'h39,8'h89,8'hd1,8'hfd,8'heb,8'he0,8'h70,8'h38,
                                                  8'hbb,8'hc8,8'h64,8'h32,8'h19,8'h99,8'hd9,8'hf9,8'h34,8'h1a,8'h0d,8'h93,8'hdc,8'h6e,8'h37,8'h8e,
                                                  8'hc7,8'hf6,8'h7b,8'ha8,8'h54,8'h2a,8'h15,8'h9f,8'h47,8'hb6,8'h5b,8'hb8,8'h5c,8'h2e,8'h17,8'h9e,
                                                  8'h3f,8'h8a,8'h45,8'hb7,8'hce,8'h67,8'ha6,8'h53,8'h56,8'h2b,8'h80,8'h40,8'h20,8'h10,8'h08,8'h04,
                                                  8'h90,8'h48,8'h24,8'h12,8'h09,8'h91,8'hdd,8'hfb,8'h7b,8'ha8,8'h54,8'h2a,8'h15,8'h9f,8'hda,8'h6d,
                                                  8'h26,8'h13,8'h9c,8'h4e,8'h27,8'h86,8'h43,8'hb4,8'hc5,8'hf7,8'hee,8'h77,8'hae,8'h57,8'hbe,8'h5f,
                                                  8'hf0,8'h78,8'h3c,8'h1e,8'h0f,8'h92,8'h49,8'hb1,8'hfb,8'he8,8'h74,8'h3a,8'h1d,8'h9b,8'hd8,8'h6c,
                                                  8'hfd,8'heb,8'he0,8'h70,8'h38,8'h1c,8'h0e,8'h07,8'he2,8'h71,8'had,8'hc3,8'hf4,8'h7a,8'h3d,8'h8b,
                                                  8'h61,8'ha5,8'hc7,8'hf6,8'h7b,8'ha8,8'h54,8'h2a,8'hf4,8'h7a,8'h3d,8'h8b,8'hd0,8'h68,8'h34,8'h1a,
                                                  8'h4d,8'hb3,8'hcc,8'h66,8'h33,8'h8c,8'h46,8'h23,8'h5a,8'h2d,8'h83,8'hd4,8'h6a,8'h35,8'h8f,8'hd2,
                                                  8'h02,8'h01,8'h95,8'hdf,8'hfa,8'h7d,8'hab,8'hc0,8'hb5,8'hcf,8'hf2,8'h79,8'ha9,8'hc1,8'hf5,8'hef,
                                                  8'hda,8'h6d,8'ha3,8'hc4,8'h62,8'h31,8'h8d,8'hd3,8'h24,8'h12,8'h09,8'h91,8'hdd,8'hfb,8'he8,8'h74,
                                                  8'h3b,8'h88,8'h44,8'h22,8'h11,8'h9d,8'hdb,8'hf8,8'h7b,8'ha8,8'h54,8'h2a,8'h15,8'h9f,8'hda,8'h6d,
                                                  8'hdc,8'h6e,8'h37,8'h8e,8'h47,8'hb6,8'h5b,8'hb8,8'h39,8'h89,8'hd1,8'hfd,8'heb,8'he0,8'h70,8'h38,
                                                  8'ha0,8'h50,8'h28,8'h14,8'h0a,8'h05,8'h97,8'hde,8'h3d,8'h8b,8'hd0,8'h68,8'h34,8'h1a,8'h0d,8'h93,
                                                  8'h0f,8'h92,8'h49,8'hb1,8'hcd,8'hf3,8'hec,8'h76,8'h0c,8'h06,8'h03,8'h94,8'h4a,8'h25,8'h87,8'hd6,
                                                  8'hf0,8'h78,8'h3c,8'h1e,8'h0f,8'h92,8'h49,8'hb1,8'h08,8'h04,8'h02,8'h01,8'h95,8'hdf,8'hfa,8'h7d,
                                                  8'h1f,8'h9a,8'h4d,8'hb3,8'hcc,8'h66,8'h33,8'h8c,8'h1c,8'h0e,8'h07,8'h96,8'h4b,8'hb0,8'h58,8'h2c,
                                                  8'hf0,8'h78,8'h3c,8'h1e,8'h0f,8'h92,8'h49,8'hb1,8'heb,8'he0,8'h70,8'h38,8'h1c,8'h0e,8'h07,8'h96,
                                                  8'h34,8'h1a,8'h0d,8'h93,8'hdc,8'h6e,8'h37,8'h8e,8'hcc,8'h66,8'h33,8'h8c,8'h46,8'h23,8'h84,8'h42,
                                                  8'h42,8'h21,8'h85,8'hd7,8'hfe,8'h7f,8'haa,8'h55,8'h5c,8'h2e,8'h17,8'h9e,8'h4f,8'hb2,8'h59,8'hb9,
                                                  8'h60,8'h30,8'h18,8'h0c,8'h06,8'h03,8'h94,8'h4a,8'h42,8'h21,8'h85,8'hd7,8'hfe,8'h7f,8'haa,8'h55,
                                                  8'h2b,8'h80,8'h40,8'h20,8'h10,8'h08,8'h04,8'h02,8'h6e,8'h37,8'h8e,8'h47,8'hb6,8'h5b,8'hb8,8'h5c,
                                                  8'h20,8'h10,8'h08,8'h04,8'h02,8'h01,8'h95,8'hdf,8'h42,8'h21,8'h85,8'hd7,8'hfe,8'h7f,8'haa,8'h55,
                                                  8'h59,8'hb9,8'hc9,8'hf1,8'hed,8'he3,8'he4,8'h72,8'h05,8'h97,8'hde,8'h6f,8'ha2,8'h51,8'hbd,8'hcb,
                                                  8'hc3,8'hf4,8'h7a,8'h3d,8'h8b,8'hd0,8'h68,8'h34,8'hf3,8'hec,8'h76,8'h3b,8'h88,8'h44,8'h22,8'h11,
                                                  8'h52,8'h29,8'h81,8'hd5,8'hff,8'hea,8'h75,8'haf,8'h3a,8'h1d,8'h9b,8'hd8,8'h6c,8'h36,8'h1b,8'h98,
                                                  8'had,8'hc3,8'hf4,8'h7a,8'h3d,8'h8b,8'hd0,8'h68,8'hd2,8'h69,8'ha1,8'hc5,8'hf7,8'hee,8'h77,8'hae,
                                                  8'h56,8'h2b,8'h80,8'h40,8'h20,8'h10,8'h08,8'h04,8'h2c,8'h16,8'h0b,8'h90,8'h48,8'h24,8'h12,8'h09,
                                                  8'hfa,8'h7d,8'hab,8'hc0,8'h60,8'h30,8'h18,8'h0c,8'h0d,8'h93,8'hdc,8'h6e,8'h37,8'h8e,8'h47,8'hb6,
                                                  8'h5c,8'h2e,8'h17,8'h9e,8'h4f,8'hb2,8'h59,8'hb9,8'hdd,8'hfb,8'he8,8'h74,8'h3a,8'h1d,8'h9b,8'hd8,
                                                  8'h93,8'hdc,8'h6e,8'h37,8'h8e,8'h47,8'hb6,8'h5b,8'hc3,8'hf4,8'h7a,8'h3d,8'h8b,8'hd0,8'h68,8'h34,
                                                  8'hed,8'he3,8'he4,8'h72,8'h39,8'h89,8'hd1,8'hfd,8'h29,8'h81,8'hd5,8'hff,8'hea,8'h75,8'haf,8'hc2,
                                                  8'h6b,8'ha0,8'h50,8'h28,8'h14,8'h0a,8'h05,8'h97,8'hb2,8'h59,8'hb9,8'hc9,8'hf1,8'hed,8'he3,8'he4,
                                                  8'hcd,8'hf3,8'hec,8'h76,8'h3b,8'h88,8'h44,8'h22,8'ha3,8'hc4,8'h62,8'h31,8'h8d,8'hd3,8'hfc,8'h7e,
                                                  8'h01,8'h95,8'hdf,8'hfa,8'h7d,8'hab,8'hc0,8'h60,8'h02,8'h01,8'h95,8'hdf,8'hfa,8'h7d,8'hab,8'hc0,
                                                  8'h08,8'h04,8'h02,8'h01,8'h95,8'hdf,8'hfa,8'h7d,8'hc9,8'hf1,8'hed,8'he3,8'he4,8'h72,8'h39,8'h89,
                                                  8'h83,8'hd4,8'h6a,8'h35,8'h8f,8'hd2,8'h69,8'ha1,8'hc7,8'hf6,8'h7b,8'ha8,8'h54,8'h2a,8'h15,8'h9f,
                                                  8'h09,8'h91,8'hdd,8'hfb,8'he8,8'h74,8'h3a,8'h1d,8'h6d,8'ha3,8'hc4,8'h62,8'h31,8'h8d,8'hd3,8'hfc,
                                                  8'h68,8'h34,8'h1a,8'h0d,8'h93,8'hdc,8'h6e,8'h37,8'h84,8'h42,8'h21,8'h85,8'hd7,8'hfe,8'h7f,8'haa,
                                                  8'he2,8'h71,8'had,8'hc3,8'hf4,8'h7a,8'h3d,8'h8b,8'h3d,8'h8b,8'hd0,8'h68,8'h34,8'h1a,8'h0d,8'h93,
                                                  8'hd9,8'hf9,8'he9,8'he1,8'he5,8'he7,8'he6,8'h73,8'hb0,8'h58,8'h2c,8'h16,8'h0b,8'h90,8'h48,8'h24,
                                                  8'h74,8'h3a,8'h1d,8'h9b,8'hd8,8'h6c,8'h36,8'h1b,8'h96,8'h4b,8'hb0,8'h58,8'h2c,8'h16,8'h0b,8'h90,
                                                  8'hc4,8'h62,8'h31,8'h8d,8'hd3,8'hfc,8'h7e,8'h3f,8'h71,8'had,8'hc3,8'hf4,8'h7a,8'h3d,8'h8b,8'hd0,
                                                  8'h84,8'h42,8'h21,8'h85,8'hd7,8'hfe,8'h7f,8'haa,8'h48,8'h24,8'h12,8'h09,8'h91,8'hdd,8'hfb,8'he8,
                                                  8'hdf,8'hfa,8'h7d,8'hab,8'hc0,8'h60,8'h30,8'h18,8'h4b,8'hb0,8'h58,8'h2c,8'h16,8'h0b,8'h90,8'h48,
                                                  8'h95,8'hdf,8'hfa,8'h7d,8'hab,8'hc0,8'h60,8'h30,8'h3e,8'h1f,8'h9a,8'h4d,8'hb3,8'hcc,8'h66,8'h33,
                                                  8'h1f,8'h9a,8'h4d,8'hb3,8'hcc,8'h66,8'h33,8'h8c,8'hb4,8'h5a,8'h2d,8'h83,8'hd4,8'h6a,8'h35,8'h8f,
                                                  8'h06,8'h03,8'h94,8'h4a,8'h25,8'h87,8'hd6,8'h6b,8'h3f,8'h8a,8'h45,8'hb7,8'hce,8'h67,8'ha6,8'h53,
                                                  8'hb1,8'hcd,8'hf3,8'hec,8'h76,8'h3b,8'h88,8'h44,8'heb,8'he0,8'h70,8'h38,8'h1c,8'h0e,8'h07,8'h96,
                                                  8'h19,8'h99,8'hd9,8'hf9,8'he9,8'he1,8'he5,8'he7,8'hfb,8'he8,8'h74,8'h3a,8'h1d,8'h9b,8'hd8,8'h6c,
                                                  8'hee,8'h77,8'hae,8'h57,8'hbe,8'h5f,8'hba,8'h5d,8'h1a,8'h0d,8'h93,8'hdc,8'h6e,8'h37,8'h8e,8'h47,
                                                  8'hb8,8'h5c,8'h2e,8'h17,8'h9e,8'h4f,8'hb2,8'h59,8'hbe,8'h5f,8'hba,8'h5d,8'hbb,8'hc8,8'h64,8'h32,
                                                  8'hd6,8'h6b,8'ha0,8'h50,8'h28,8'h14,8'h0a,8'h05,8'h14,8'h0a,8'h05,8'h97,8'hde,8'h6f,8'ha2,8'h51,
                                                  8'he7,8'he6,8'h73,8'hac,8'h56,8'h2b,8'h80,8'h40,8'hc0,8'h60,8'h30,8'h18,8'h0c,8'h06,8'h03,8'h94,
                                                  8'h8e,8'h47,8'hb6,8'h5b,8'hb8,8'h5c,8'h2e,8'h17,8'he4,8'h72,8'h39,8'h89,8'hd1,8'hfd,8'heb,8'he0,
                                                  8'haf,8'hc2,8'h61,8'ha5,8'hc7,8'hf6,8'h7b,8'ha8,8'h5b,8'hb8,8'h5c,8'h2e,8'h17,8'h9e,8'h4f,8'hb2,
                                                  8'haf,8'hc2,8'h61,8'ha5,8'hc7,8'hf6,8'h7b,8'ha8,8'hc6,8'h63,8'ha4,8'h52,8'h29,8'h81,8'hd5,8'hff,
                                                  8'hf7,8'hee,8'h77,8'hae,8'h57,8'hbe,8'h5f,8'hba,8'h7e,8'h3f,8'h8a,8'h45,8'hb7,8'hce,8'h67,8'ha6,
                                                  8'h22,8'h11,8'h9d,8'hdb,8'hf8,8'h7c,8'h3e,8'h1f,8'h60,8'h30,8'h18,8'h0c,8'h06,8'h03,8'h94,8'h4a,
                                                  8'h77,8'hae,8'h57,8'hbe,8'h5f,8'hba,8'h5d,8'hbb,8'h14,8'h0a,8'h05,8'h97,8'hde,8'h6f,8'ha2,8'h51,
                                                  8'h9e,8'h4f,8'hb2,8'h59,8'hb9,8'hc9,8'hf1,8'hed,8'h5b,8'hb8,8'h5c,8'h2e,8'h17,8'h9e,8'h4f,8'hb2,
                                                  8'hfa,8'h7d,8'hab,8'hc0,8'h60,8'h30,8'h18,8'h0c,8'h20,8'h10,8'h08,8'h04,8'h02,8'h01,8'h95,8'hdf,
                                                  8'hff,8'hea,8'h75,8'haf,8'hc2,8'h61,8'ha5,8'hc7,8'h75,8'haf,8'hc2,8'h61,8'ha5,8'hc7,8'hf6,8'h7b,
                                                  8'h14,8'h0a,8'h05,8'h97,8'hde,8'h6f,8'ha2,8'h51,8'h75,8'haf,8'hc2,8'h61,8'ha5,8'hc7,8'hf6,8'h7b,
                                                  8'h12,8'h09,8'h91,8'hdd,8'hfb,8'he8,8'h74,8'h3a,8'h3f,8'h8a,8'h45,8'hb7,8'hce,8'h67,8'ha6,8'h53,
                                                  8'hf5,8'hef,8'he2,8'h71,8'had,8'hc3,8'hf4,8'h7a,8'hf4,8'h7a,8'h3d,8'h8b,8'hd0,8'h68,8'h34,8'h1a,
                                                  8'h5a,8'h2d,8'h83,8'hd4,8'h6a,8'h35,8'h8f,8'hd2,8'h5e,8'h2f,8'h82,8'h41,8'hb5,8'hcf,8'hf2,8'h79,
                                                  8'h9b,8'hd8,8'h6c,8'h36,8'h1b,8'h98,8'h4c,8'h26,8'hab,8'hc0,8'h60,8'h30,8'h18,8'h0c,8'h06,8'h03,
                                                  8'h83,8'hd4,8'h6a,8'h35,8'h8f,8'hd2,8'h69,8'ha1,8'h12,8'h09,8'h91,8'hdd,8'hfb,8'he8,8'h74,8'h3a,
                                                  8'h59,8'hb9,8'hc9,8'hf1,8'hed,8'he3,8'he4,8'h72,8'h02,8'h01,8'h95,8'hdf,8'hfa,8'h7d,8'hab,8'hc0,
                                                  8'h1d,8'h9b,8'hd8,8'h6c,8'h36,8'h1b,8'h98,8'h4c,8'h0a,8'h05,8'h97,8'hde,8'h6f,8'ha2,8'h51,8'hbd,
                                                  8'h8f,8'hd2,8'h69,8'ha1,8'hc5,8'hf7,8'hee,8'h77,8'h2d,8'h83,8'hd4,8'h6a,8'h35,8'h8f,8'hd2,8'h69,
                                                  8'h81,8'hd5,8'hff,8'hea,8'h75,8'haf,8'hc2,8'h61,8'haf,8'hc2,8'h61,8'ha5,8'hc7,8'hf6,8'h7b,8'ha8,
                                                  8'h0e,8'h07,8'h96,8'h4b,8'hb0,8'h58,8'h2c,8'h16,8'hd2,8'h69,8'ha1,8'hc5,8'hf7,8'hee,8'h77,8'hae,
                                                  8'h01,8'h95,8'hdf,8'hfa,8'h7d,8'hab,8'hc0,8'h60,8'h6b,8'ha0,8'h50,8'h28,8'h14,8'h0a,8'h05,8'h97,
                                                  8'hd1,8'hfd,8'heb,8'he0,8'h70,8'h38,8'h1c,8'h0e,8'h50,8'h28,8'h14,8'h0a,8'h05,8'h97,8'hde,8'h6f,
                                                  8'h4a,8'h25,8'h87,8'hd6,8'h6b,8'ha0,8'h50,8'h28,8'h59,8'hb9,8'hc9,8'hf1,8'hed,8'he3,8'he4,8'h72,
                                                  8'h50,8'h28,8'h14,8'h0a,8'h05,8'h97,8'hde,8'h6f,8'h55,8'hbf,8'hca,8'h65,8'ha7,8'hc6,8'h63,8'ha4,
                                                  8'h41,8'hb5,8'hcf,8'hf2,8'h79,8'ha9,8'hc1,8'hf5,8'hb3,8'hcc,8'h66,8'h33,8'h8c,8'h46,8'h23,8'h84,
                                                  8'h45,8'hb7,8'hce,8'h67,8'ha6,8'h53,8'hbc,8'h5e,8'h23,8'h84,8'h42,8'h21,8'h85,8'hd7,8'hfe,8'h7f,
                                                  8'haa,8'h55,8'hbf,8'hca,8'h65,8'ha7,8'hc6,8'h63,8'h7d,8'hab,8'hc0,8'h60,8'h30,8'h18,8'h0c,8'h06,
                                                  8'hcb,8'hf0,8'h78,8'h3c,8'h1e,8'h0f,8'h92,8'h49,8'hc5,8'hf7,8'hee,8'h77,8'hae,8'h57,8'hbe,8'h5f,
                                                  8'hfd,8'heb,8'he0,8'h70,8'h38,8'h1c,8'h0e,8'h07,8'h07,8'h96,8'h4b,8'hb0,8'h58,8'h2c,8'h16,8'h0b,
                                                  8'h1c,8'h0e,8'h07,8'h96,8'h4b,8'hb0,8'h58,8'h2c,8'h98,8'h4c,8'h26,8'h13,8'h9c,8'h4e,8'h27,8'h86,
                                                  8'h96,8'h4b,8'hb0,8'h58,8'h2c,8'h16,8'h0b,8'h90,8'h8e,8'h47,8'hb6,8'h5b,8'hb8,8'h5c,8'h2e,8'h17,
                                                  8'h98,8'h4c,8'h26,8'h13,8'h9c,8'h4e,8'h27,8'h86,8'ha5,8'hc7,8'hf6,8'h7b,8'ha8,8'h54,8'h2a,8'h15,
                                                  8'h4a,8'h25,8'h87,8'hd6,8'h6b,8'ha0,8'h50,8'h28,8'he2,8'h71,8'had,8'hc3,8'hf4,8'h7a,8'h3d,8'h8b,
                                                  8'h1b,8'h98,8'h4c,8'h26,8'h13,8'h9c,8'h4e,8'h27,8'h47,8'hb6,8'h5b,8'hb8,8'h5c,8'h2e,8'h17,8'h9e,
                                                  8'h85,8'hd7,8'hfe,8'h7f,8'haa,8'h55,8'hbf,8'hca,8'h68,8'h34,8'h1a,8'h0d,8'h93,8'hdc,8'h6e,8'h37,
                                                  8'h76,8'h3b,8'h88,8'h44,8'h22,8'h11,8'h9d,8'hdb,8'hfe,8'h7f,8'haa,8'h55,8'hbf,8'hca,8'h65,8'ha7};
  
  localparam [(P_FLIT_WD * 8) - 1 : 0] P_COEF4 =  {P_ZERO_PAD,
                                                  8'ha7,8'hc6,8'h63,8'ha4,8'h52,8'h29,8'h81,8'hd5,8'h87,8'hd6,8'h6b,8'ha0,8'h50,8'h28,8'h14,8'h0a,
                                                  8'hd7,8'hfe,8'h7f,8'haa,8'h55,8'hbf,8'hca,8'h65,8'hd5,8'hff,8'hea,8'h75,8'haf,8'hc2,8'h61,8'ha5,
                                                  8'h60,8'h30,8'h18,8'h0c,8'h06,8'h03,8'h94,8'h4a,8'h3e,8'h1f,8'h9a,8'h4d,8'hb3,8'hcc,8'h66,8'h33,
                                                  8'h91,8'hdd,8'hfb,8'he8,8'h74,8'h3a,8'h1d,8'h9b,8'h73,8'hac,8'h56,8'h2b,8'h80,8'h40,8'h20,8'h10,
                                                  8'h60,8'h30,8'h18,8'h0c,8'h06,8'h03,8'h94,8'h4a,8'hea,8'h75,8'haf,8'hc2,8'h61,8'ha5,8'hc7,8'hf6,
                                                  8'h5f,8'hba,8'h5d,8'hbb,8'hc8,8'h64,8'h32,8'h19,8'h95,8'hdf,8'hfa,8'h7d,8'hab,8'hc0,8'h60,8'h30,
                                                  8'h95,8'hdf,8'hfa,8'h7d,8'hab,8'hc0,8'h60,8'h30,8'h83,8'hd4,8'h6a,8'h35,8'h8f,8'hd2,8'h69,8'ha1,
                                                  8'hc8,8'h64,8'h32,8'h19,8'h99,8'hd9,8'hf9,8'he9,8'h35,8'h8f,8'hd2,8'h69,8'ha1,8'hc5,8'hf7,8'hee,
                                                  8'h91,8'hdd,8'hfb,8'he8,8'h74,8'h3a,8'h1d,8'h9b,8'hf9,8'he9,8'he1,8'he5,8'he7,8'he6,8'h73,8'hac,
                                                  8'h95,8'hdf,8'hfa,8'h7d,8'hab,8'hc0,8'h60,8'h30,8'haf,8'hc2,8'h61,8'ha5,8'hc7,8'hf6,8'h7b,8'ha8,
                                                  8'h29,8'h81,8'hd5,8'hff,8'hea,8'h75,8'haf,8'hc2,8'hc2,8'h61,8'ha5,8'hc7,8'hf6,8'h7b,8'ha8,8'h54,
                                                  8'h50,8'h28,8'h14,8'h0a,8'h05,8'h97,8'hde,8'h6f,8'h25,8'h87,8'hd6,8'h6b,8'ha0,8'h50,8'h28,8'h14,
                                                  8'hd4,8'h6a,8'h35,8'h8f,8'hd2,8'h69,8'ha1,8'hc5,8'h19,8'h99,8'hd9,8'hf9,8'he9,8'he1,8'he5,8'he7,
                                                  8'h18,8'h0c,8'h06,8'h03,8'h94,8'h4a,8'h25,8'h87,8'h86,8'h43,8'hb4,8'h5a,8'h2d,8'h83,8'hd4,8'h6a,
                                                  8'h12,8'h09,8'h91,8'hdd,8'hfb,8'he8,8'h74,8'h3a,8'hd5,8'hff,8'hea,8'h75,8'haf,8'hc2,8'h61,8'ha5,
                                                  8'had,8'hc3,8'hf4,8'h7a,8'h3d,8'h8b,8'hd0,8'h68,8'h4d,8'hb3,8'hcc,8'h66,8'h33,8'h8c,8'h46,8'h23,
                                                  8'ha4,8'h52,8'h29,8'h81,8'hd5,8'hff,8'hea,8'h75,8'hc4,8'h62,8'h31,8'h8d,8'hd3,8'hfc,8'h7e,8'h3f,
                                                  8'h63,8'ha4,8'h52,8'h29,8'h81,8'hd5,8'hff,8'hea,8'h56,8'h2b,8'h80,8'h40,8'h20,8'h10,8'h08,8'h04,
                                                  8'hcf,8'hf2,8'h79,8'ha9,8'hc1,8'hf5,8'hef,8'he2,8'hbf,8'hca,8'h65,8'ha7,8'hc6,8'h63,8'ha4,8'h52,
                                                  8'h86,8'h43,8'hb4,8'h5a,8'h2d,8'h83,8'hd4,8'h6a,8'h14,8'h0a,8'h05,8'h97,8'hde,8'h6f,8'ha2,8'h51,
                                                  8'hd9,8'hf9,8'he9,8'he1,8'he5,8'he7,8'he6,8'h73,8'h81,8'hd5,8'hff,8'hea,8'h75,8'haf,8'hc2,8'h61,
                                                  8'h85,8'hd7,8'hfe,8'h7f,8'haa,8'h55,8'hbf,8'hca,8'h41,8'hb5,8'hcf,8'hf2,8'h79,8'ha9,8'hc1,8'hf5,
                                                  8'hac,8'h56,8'h2b,8'h80,8'h40,8'h20,8'h10,8'h08,8'hae,8'h57,8'hbe,8'h5f,8'hba,8'h5d,8'hbb,8'hc8,
                                                  8'h2b,8'h80,8'h40,8'h20,8'h10,8'h08,8'h04,8'h02,8'h64,8'h32,8'h19,8'h99,8'hd9,8'hf9,8'he9,8'he1,
                                                  8'h9e,8'h4f,8'hb2,8'h59,8'hb9,8'hc9,8'hf1,8'hed,8'h40,8'h20,8'h10,8'h08,8'h04,8'h02,8'h01,8'h95,
                                                  8'h95,8'hdf,8'hfa,8'h7d,8'hab,8'hc0,8'h60,8'h30,8'hd2,8'h69,8'ha1,8'hc5,8'hf7,8'hee,8'h77,8'hae,
                                                  8'hb0,8'h58,8'h2c,8'h16,8'h0b,8'h90,8'h48,8'h24,8'h2d,8'h83,8'hd4,8'h6a,8'h35,8'h8f,8'hd2,8'h69,
                                                  8'hb0,8'h58,8'h2c,8'h16,8'h0b,8'h90,8'h48,8'h24,8'h26,8'h13,8'h9c,8'h4e,8'h27,8'h86,8'h43,8'hb4,
                                                  8'h1d,8'h9b,8'hd8,8'h6c,8'h36,8'h1b,8'h98,8'h4c,8'hce,8'h67,8'ha6,8'h53,8'hbc,8'h5e,8'h2f,8'h82,
                                                  8'hd6,8'h6b,8'ha0,8'h50,8'h28,8'h14,8'h0a,8'h05,8'h33,8'h8c,8'h46,8'h23,8'h84,8'h42,8'h21,8'h85,
                                                  8'h7f,8'haa,8'h55,8'hbf,8'hca,8'h65,8'ha7,8'hc6,8'h17,8'h9e,8'h4f,8'hb2,8'h59,8'hb9,8'hc9,8'hf1,
                                                  8'h42,8'h21,8'h85,8'hd7,8'hfe,8'h7f,8'haa,8'h55,8'h98,8'h4c,8'h26,8'h13,8'h9c,8'h4e,8'h27,8'h86,
                                                  8'h94,8'h4a,8'h25,8'h87,8'hd6,8'h6b,8'ha0,8'h50,8'h5a,8'h2d,8'h83,8'hd4,8'h6a,8'h35,8'h8f,8'hd2,
                                                  8'h6a,8'h35,8'h8f,8'hd2,8'h69,8'ha1,8'hc5,8'hf7,8'h77,8'hae,8'h57,8'hbe,8'h5f,8'hba,8'h5d,8'hbb,
                                                  8'h77,8'hae,8'h57,8'hbe,8'h5f,8'hba,8'h5d,8'hbb,8'hc7,8'hf6,8'h7b,8'ha8,8'h54,8'h2a,8'h15,8'h9f,
                                                  8'ha0,8'h50,8'h28,8'h14,8'h0a,8'h05,8'h97,8'hde,8'hb6,8'h5b,8'hb8,8'h5c,8'h2e,8'h17,8'h9e,8'h4f,
                                                  8'h97,8'hde,8'h6f,8'ha2,8'h51,8'hbd,8'hcb,8'hf0,8'ha5,8'hc7,8'hf6,8'h7b,8'ha8,8'h54,8'h2a,8'h15,
                                                  8'hf0,8'h78,8'h3c,8'h1e,8'h0f,8'h92,8'h49,8'hb1,8'h6b,8'ha0,8'h50,8'h28,8'h14,8'h0a,8'h05,8'h97,
                                                  8'h74,8'h3a,8'h1d,8'h9b,8'hd8,8'h6c,8'h36,8'h1b,8'h31,8'h8d,8'hd3,8'hfc,8'h7e,8'h3f,8'h8a,8'h45,
                                                  8'hd4,8'h6a,8'h35,8'h8f,8'hd2,8'h69,8'ha1,8'hc5,8'h82,8'h41,8'hb5,8'hcf,8'hf2,8'h79,8'ha9,8'hc1,
                                                  8'ha0,8'h50,8'h28,8'h14,8'h0a,8'h05,8'h97,8'hde,8'hb8,8'h5c,8'h2e,8'h17,8'h9e,8'h4f,8'hb2,8'h59,
                                                  8'h4e,8'h27,8'h86,8'h43,8'hb4,8'h5a,8'h2d,8'h83,8'h51,8'hbd,8'hcb,8'hf0,8'h78,8'h3c,8'h1e,8'h0f,
                                                  8'h06,8'h03,8'h94,8'h4a,8'h25,8'h87,8'hd6,8'h6b,8'ha8,8'h54,8'h2a,8'h15,8'h9f,8'hda,8'h6d,8'ha3,
                                                  8'h4c,8'h26,8'h13,8'h9c,8'h4e,8'h27,8'h86,8'h43,8'h76,8'h3b,8'h88,8'h44,8'h22,8'h11,8'h9d,8'hdb,
                                                  8'h7d,8'hab,8'hc0,8'h60,8'h30,8'h18,8'h0c,8'h06,8'h9f,8'hda,8'h6d,8'ha3,8'hc4,8'h62,8'h31,8'h8d,
                                                  8'h0e,8'h07,8'h96,8'h4b,8'hb0,8'h58,8'h2c,8'h16,8'h3a,8'h1d,8'h9b,8'hd8,8'h6c,8'h36,8'h1b,8'h98,
                                                  8'he7,8'he6,8'h73,8'hac,8'h56,8'h2b,8'h80,8'h40,8'h15,8'h9f,8'hda,8'h6d,8'ha3,8'hc4,8'h62,8'h31,
                                                  8'hf8,8'h7c,8'h3e,8'h1f,8'h9a,8'h4d,8'hb3,8'hcc,8'h17,8'h9e,8'h4f,8'hb2,8'h59,8'hb9,8'hc9,8'hf1,
                                                  8'h4a,8'h25,8'h87,8'hd6,8'h6b,8'ha0,8'h50,8'h28,8'h6a,8'h35,8'h8f,8'hd2,8'h69,8'ha1,8'hc5,8'hf7,
                                                  8'hc6,8'h63,8'ha4,8'h52,8'h29,8'h81,8'hd5,8'hff,8'ha7,8'hc6,8'h63,8'ha4,8'h52,8'h29,8'h81,8'hd5,
                                                  8'h0c,8'h06,8'h03,8'h94,8'h4a,8'h25,8'h87,8'hd6,8'hba,8'h5d,8'hbb,8'hc8,8'h64,8'h32,8'h19,8'h99,
                                                  8'h19,8'h99,8'hd9,8'hf9,8'he9,8'he1,8'he5,8'he7,8'h73,8'hac,8'h56,8'h2b,8'h80,8'h40,8'h20,8'h10,
                                                  8'hc5,8'hf7,8'hee,8'h77,8'hae,8'h57,8'hbe,8'h5f,8'h92,8'h49,8'hb1,8'hcd,8'hf3,8'hec,8'h76,8'h3b,
                                                  8'hf3,8'hec,8'h76,8'h3b,8'h88,8'h44,8'h22,8'h11,8'hcb,8'hf0,8'h78,8'h3c,8'h1e,8'h0f,8'h92,8'h49,
                                                  8'h48,8'h24,8'h12,8'h09,8'h91,8'hdd,8'hfb,8'he8,8'h58,8'h2c,8'h16,8'h0b,8'h90,8'h48,8'h24,8'h12,
                                                  8'h55,8'hbf,8'hca,8'h65,8'ha7,8'hc6,8'h63,8'ha4,8'h17,8'h9e,8'h4f,8'hb2,8'h59,8'hb9,8'hc9,8'hf1,
                                                  8'h4e,8'h27,8'h86,8'h43,8'hb4,8'h5a,8'h2d,8'h83,8'h2f,8'h82,8'h41,8'hb5,8'hcf,8'hf2,8'h79,8'ha9,
                                                  8'h84,8'h42,8'h21,8'h85,8'hd7,8'hfe,8'h7f,8'haa,8'hd1,8'hfd,8'heb,8'he0,8'h70,8'h38,8'h1c,8'h0e,
                                                  8'h8c,8'h46,8'h23,8'h84,8'h42,8'h21,8'h85,8'hd7,8'h50,8'h28,8'h14,8'h0a,8'h05,8'h97,8'hde,8'h6f,
                                                  8'h70,8'h38,8'h1c,8'h0e,8'h07,8'h96,8'h4b,8'hb0,8'h67,8'ha6,8'h53,8'hbc,8'h5e,8'h2f,8'h82,8'h41,
                                                  8'hda,8'h6d,8'ha3,8'hc4,8'h62,8'h31,8'h8d,8'hd3,8'hbf,8'hca,8'h65,8'ha7,8'hc6,8'h63,8'ha4,8'h52,
                                                  8'h2d,8'h83,8'hd4,8'h6a,8'h35,8'h8f,8'hd2,8'h69,8'h2a,8'h15,8'h9f,8'hda,8'h6d,8'ha3,8'hc4,8'h62,
                                                  8'he4,8'h72,8'h39,8'h89,8'hd1,8'hfd,8'heb,8'he0,8'hb5,8'hcf,8'hf2,8'h79,8'ha9,8'hc1,8'hf5,8'hef,
                                                  8'h86,8'h43,8'hb4,8'h5a,8'h2d,8'h83,8'hd4,8'h6a,8'h0a,8'h05,8'h97,8'hde,8'h6f,8'ha2,8'h51,8'hbd,
                                                  8'h15,8'h9f,8'hda,8'h6d,8'ha3,8'hc4,8'h62,8'h31,8'hc3,8'hf4,8'h7a,8'h3d,8'h8b,8'hd0,8'h68,8'h34,
                                                  8'ha5,8'hc7,8'hf6,8'h7b,8'ha8,8'h54,8'h2a,8'h15,8'he4,8'h72,8'h39,8'h89,8'hd1,8'hfd,8'heb,8'he0,
                                                  8'h24,8'h12,8'h09,8'h91,8'hdd,8'hfb,8'he8,8'h74,8'hd4,8'h6a,8'h35,8'h8f,8'hd2,8'h69,8'ha1,8'hc5,
                                                  8'hbd,8'hcb,8'hf0,8'h78,8'h3c,8'h1e,8'h0f,8'h92,8'heb,8'he0,8'h70,8'h38,8'h1c,8'h0e,8'h07,8'h96,
                                                  8'h21,8'h85,8'hd7,8'hfe,8'h7f,8'haa,8'h55,8'hbf,8'h56,8'h2b,8'h80,8'h40,8'h20,8'h10,8'h08,8'h04,
                                                  8'h13,8'h9c,8'h4e,8'h27,8'h86,8'h43,8'hb4,8'h5a,8'h89,8'hd1,8'hfd,8'heb,8'he0,8'h70,8'h38,8'h1c,
                                                  8'hfc,8'h7e,8'h3f,8'h8a,8'h45,8'hb7,8'hce,8'h67,8'h1c,8'h0e,8'h07,8'h96,8'h4b,8'hb0,8'h58,8'h2c,
                                                  8'h1d,8'h9b,8'hd8,8'h6c,8'h36,8'h1b,8'h98,8'h4c,8'h0f,8'h92,8'h49,8'hb1,8'hcd,8'hf3,8'hec,8'h76,
                                                  8'hee,8'h77,8'hae,8'h57,8'hbe,8'h5f,8'hba,8'h5d,8'hdf,8'hfa,8'h7d,8'hab,8'hc0,8'h60,8'h30,8'h18,
                                                  8'hc3,8'hf4,8'h7a,8'h3d,8'h8b,8'hd0,8'h68,8'h34,8'hcc,8'h66,8'h33,8'h8c,8'h46,8'h23,8'h84,8'h42,
                                                  8'hcf,8'hf2,8'h79,8'ha9,8'hc1,8'hf5,8'hef,8'he2,8'he0,8'h70,8'h38,8'h1c,8'h0e,8'h07,8'h96,8'h4b,
                                                  8'hfe,8'h7f,8'haa,8'h55,8'hbf,8'hca,8'h65,8'ha7,8'h8b,8'hd0,8'h68,8'h34,8'h1a,8'h0d,8'h93,8'hdc,
                                                  8'h0a,8'h05,8'h97,8'hde,8'h6f,8'ha2,8'h51,8'hbd,8'hc6,8'h63,8'ha4,8'h52,8'h29,8'h81,8'hd5,8'hff,
                                                  8'h8c,8'h46,8'h23,8'h84,8'h42,8'h21,8'h85,8'hd7,8'h67,8'ha6,8'h53,8'hbc,8'h5e,8'h2f,8'h82,8'h41,
                                                  8'h33,8'h8c,8'h46,8'h23,8'h84,8'h42,8'h21,8'h85,8'h90,8'h48,8'h24,8'h12,8'h09,8'h91,8'hdd,8'hfb,
                                                  8'hb9,8'hc9,8'hf1,8'hed,8'he3,8'he4,8'h72,8'h39,8'h2d,8'h83,8'hd4,8'h6a,8'h35,8'h8f,8'hd2,8'h69,
                                                  8'h02,8'h01,8'h95,8'hdf,8'hfa,8'h7d,8'hab,8'hc0,8'h23,8'h84,8'h42,8'h21,8'h85,8'hd7,8'hfe,8'h7f,
                                                  8'hfd,8'heb,8'he0,8'h70,8'h38,8'h1c,8'h0e,8'h07,8'hdc,8'h6e,8'h37,8'h8e,8'h47,8'hb6,8'h5b,8'hb8,
                                                  8'h09,8'h91,8'hdd,8'hfb,8'he8,8'h74,8'h3a,8'h1d,8'hc3,8'hf4,8'h7a,8'h3d,8'h8b,8'hd0,8'h68,8'h34,
                                                  8'hfd,8'heb,8'he0,8'h70,8'h38,8'h1c,8'h0e,8'h07,8'h08,8'h04,8'h02,8'h01,8'h95,8'hdf,8'hfa,8'h7d,
                                                  8'h57,8'hbe,8'h5f,8'hba,8'h5d,8'hbb,8'hc8,8'h64,8'ha3,8'hc4,8'h62,8'h31,8'h8d,8'hd3,8'hfc,8'h7e,
                                                  8'h80,8'h40,8'h20,8'h10,8'h08,8'h04,8'h02,8'h01,8'h6c,8'h36,8'h1b,8'h98,8'h4c,8'h26,8'h13,8'h9c,
                                                  8'he7,8'he6,8'h73,8'hac,8'h56,8'h2b,8'h80,8'h40,8'h06,8'h03,8'h94,8'h4a,8'h25,8'h87,8'hd6,8'h6b,
                                                  8'h5f,8'hba,8'h5d,8'hbb,8'hc8,8'h64,8'h32,8'h19,8'h16,8'h0b,8'h90,8'h48,8'h24,8'h12,8'h09,8'h91,
                                                  8'h64,8'h32,8'h19,8'h99,8'hd9,8'hf9,8'he9,8'he1,8'h90,8'h48,8'h24,8'h12,8'h09,8'h91,8'hdd,8'hfb,
                                                  8'h19,8'h99,8'hd9,8'hf9,8'he9,8'he1,8'he5,8'he7,8'h94,8'h4a,8'h25,8'h87,8'hd6,8'h6b,8'ha0,8'h50,
                                                  8'h09,8'h91,8'hdd,8'hfb,8'he8,8'h74,8'h3a,8'h1d,8'h11,8'h9d,8'hdb,8'hf8,8'h7c,8'h3e,8'h1f,8'h9a,
                                                  8'h3e,8'h1f,8'h9a,8'h4d,8'hb3,8'hcc,8'h66,8'h33,8'hc7,8'hf6,8'h7b,8'ha8,8'h54,8'h2a,8'h15,8'h9f,
                                                  8'hea,8'h75,8'haf,8'hc2,8'h61,8'ha5,8'hc7,8'hf6,8'h74,8'h3a,8'h1d,8'h9b,8'hd8,8'h6c,8'h36,8'h1b,
                                                  8'h02,8'h01,8'h95,8'hdf,8'hfa,8'h7d,8'hab,8'hc0,8'hc4,8'h62,8'h31,8'h8d,8'hd3,8'hfc,8'h7e,8'h3f,
                                                  8'he0,8'h70,8'h38,8'h1c,8'h0e,8'h07,8'h96,8'h4b,8'h67,8'ha6,8'h53,8'hbc,8'h5e,8'h2f,8'h82,8'h41,
                                                  8'h31,8'h8d,8'hd3,8'hfc,8'h7e,8'h3f,8'h8a,8'h45,8'h3f,8'h8a,8'h45,8'hb7,8'hce,8'h67,8'ha6,8'h53,
                                                  8'hb5,8'hcf,8'hf2,8'h79,8'ha9,8'hc1,8'hf5,8'hef,8'h81,8'hd5,8'hff,8'hea,8'h75,8'haf,8'hc2,8'h61,
                                                  8'hee,8'h77,8'hae,8'h57,8'hbe,8'h5f,8'hba,8'h5d,8'h4c,8'h26,8'h13,8'h9c,8'h4e,8'h27,8'h86,8'h43,
                                                  8'ha7,8'hc6,8'h63,8'ha4,8'h52,8'h29,8'h81,8'hd5,8'hcd,8'hf3,8'hec,8'h76,8'h3b,8'h88,8'h44,8'h22,
                                                  8'h94,8'h4a,8'h25,8'h87,8'hd6,8'h6b,8'ha0,8'h50,8'h39,8'h89,8'hd1,8'hfd,8'heb,8'he0,8'h70,8'h38,
                                                  8'h3e,8'h1f,8'h9a,8'h4d,8'hb3,8'hcc,8'h66,8'h33,8'h03,8'h94,8'h4a,8'h25,8'h87,8'hd6,8'h6b,8'ha0,
                                                  8'hd2,8'h69,8'ha1,8'hc5,8'hf7,8'hee,8'h77,8'hae,8'hd3,8'hfc,8'h7e,8'h3f,8'h8a,8'h45,8'hb7,8'hce,
                                                  8'h05,8'h97,8'hde,8'h6f,8'ha2,8'h51,8'hbd,8'hcb,8'h49,8'hb1,8'hcd,8'hf3,8'hec,8'h76,8'h3b,8'h88,
                                                  8'h9e,8'h4f,8'hb2,8'h59,8'hb9,8'hc9,8'hf1,8'hed,8'h91,8'hdd,8'hfb,8'he8,8'h74,8'h3a,8'h1d,8'h9b,
                                                  8'ha0,8'h50,8'h28,8'h14,8'h0a,8'h05,8'h97,8'hde,8'h17,8'h9e,8'h4f,8'hb2,8'h59,8'hb9,8'hc9,8'hf1,
                                                  8'h89,8'hd1,8'hfd,8'heb,8'he0,8'h70,8'h38,8'h1c,8'h83,8'hd4,8'h6a,8'h35,8'h8f,8'hd2,8'h69,8'ha1,
                                                  8'h07,8'h96,8'h4b,8'hb0,8'h58,8'h2c,8'h16,8'h0b,8'h93,8'hdc,8'h6e,8'h37,8'h8e,8'h47,8'hb6,8'h5b,
                                                  8'h48,8'h24,8'h12,8'h09,8'h91,8'hdd,8'hfb,8'he8,8'h01,8'h95,8'hdf,8'hfa,8'h7d,8'hab,8'hc0,8'h60,
                                                  8'h25,8'h87,8'hd6,8'h6b,8'ha0,8'h50,8'h28,8'h14,8'h2f,8'h82,8'h41,8'hb5,8'hcf,8'hf2,8'h79,8'ha9,
                                                  8'hc0,8'h60,8'h30,8'h18,8'h0c,8'h06,8'h03,8'h94,8'h5b,8'hb8,8'h5c,8'h2e,8'h17,8'h9e,8'h4f,8'hb2,
                                                  8'h55,8'hbf,8'hca,8'h65,8'ha7,8'hc6,8'h63,8'ha4,8'hb6,8'h5b,8'hb8,8'h5c,8'h2e,8'h17,8'h9e,8'h4f,
                                                  8'hec,8'h76,8'h3b,8'h88,8'h44,8'h22,8'h11,8'h9d,8'h7c,8'h3e,8'h1f,8'h9a,8'h4d,8'hb3,8'hcc,8'h66,
                                                  8'h53,8'hbc,8'h5e,8'h2f,8'h82,8'h41,8'hb5,8'hcf,8'hf9,8'he9,8'he1,8'he5,8'he7,8'he6,8'h73,8'hac,
                                                  8'hcf,8'hf2,8'h79,8'ha9,8'hc1,8'hf5,8'hef,8'he2,8'hba,8'h5d,8'hbb,8'hc8,8'h64,8'h32,8'h19,8'h99,
                                                  8'h5e,8'h2f,8'h82,8'h41,8'hb5,8'hcf,8'hf2,8'h79,8'hf1,8'hed,8'he3,8'he4,8'h72,8'h39,8'h89,8'hd1,
                                                  8'h85,8'hd7,8'hfe,8'h7f,8'haa,8'h55,8'hbf,8'hca,8'hbf,8'hca,8'h65,8'ha7,8'hc6,8'h63,8'ha4,8'h52,
                                                  8'h68,8'h34,8'h1a,8'h0d,8'h93,8'hdc,8'h6e,8'h37,8'h77,8'hae,8'h57,8'hbe,8'h5f,8'hba,8'h5d,8'hbb,
                                                  8'h1e,8'h0f,8'h92,8'h49,8'hb1,8'hcd,8'hf3,8'hec,8'h2f,8'h82,8'h41,8'hb5,8'hcf,8'hf2,8'h79,8'ha9,
                                                  8'h2a,8'h15,8'h9f,8'hda,8'h6d,8'ha3,8'hc4,8'h62,8'hbd,8'hcb,8'hf0,8'h78,8'h3c,8'h1e,8'h0f,8'h92,
                                                  8'h5e,8'h2f,8'h82,8'h41,8'hb5,8'hcf,8'hf2,8'h79,8'h25,8'h87,8'hd6,8'h6b,8'ha0,8'h50,8'h28,8'h14,
                                                  8'h20,8'h10,8'h08,8'h04,8'h02,8'h01,8'h95,8'hdf,8'hc8,8'h64,8'h32,8'h19,8'h99,8'hd9,8'hf9,8'he9};
  
  localparam [(P_FLIT_WD * 8) - 1 : 0] P_COEF3 =  {P_ZERO_PAD,
                                                  8'h3e,8'h1f,8'h9a,8'h4d,8'hb3,8'hcc,8'h66,8'h33,8'h5a,8'h2d,8'h83,8'hd4,8'h6a,8'h35,8'h8f,8'hd2,
                                                  8'hc4,8'h62,8'h31,8'h8d,8'hd3,8'hfc,8'h7e,8'h3f,8'h84,8'h42,8'h21,8'h85,8'hd7,8'hfe,8'h7f,8'haa,
                                                  8'hc1,8'hf5,8'hef,8'he2,8'h71,8'had,8'hc3,8'hf4,8'h0d,8'h93,8'hdc,8'h6e,8'h37,8'h8e,8'h47,8'hb6,
                                                  8'hb8,8'h5c,8'h2e,8'h17,8'h9e,8'h4f,8'hb2,8'h59,8'hed,8'he3,8'he4,8'h72,8'h39,8'h89,8'hd1,8'hfd,
                                                  8'h95,8'hdf,8'hfa,8'h7d,8'hab,8'hc0,8'h60,8'h30,8'hb9,8'hc9,8'hf1,8'hed,8'he3,8'he4,8'h72,8'h39,
                                                  8'h35,8'h8f,8'hd2,8'h69,8'ha1,8'hc5,8'hf7,8'hee,8'h5d,8'hbb,8'hc8,8'h64,8'h32,8'h19,8'h99,8'hd9,
                                                  8'h8b,8'hd0,8'h68,8'h34,8'h1a,8'h0d,8'h93,8'hdc,8'h46,8'h23,8'h84,8'h42,8'h21,8'h85,8'hd7,8'hfe,
                                                  8'hee,8'h77,8'hae,8'h57,8'hbe,8'h5f,8'hba,8'h5d,8'h47,8'hb6,8'h5b,8'hb8,8'h5c,8'h2e,8'h17,8'h9e,
                                                  8'hc3,8'hf4,8'h7a,8'h3d,8'h8b,8'hd0,8'h68,8'h34,8'hd2,8'h69,8'ha1,8'hc5,8'hf7,8'hee,8'h77,8'hae,
                                                  8'h39,8'h89,8'hd1,8'hfd,8'heb,8'he0,8'h70,8'h38,8'h94,8'h4a,8'h25,8'h87,8'hd6,8'h6b,8'ha0,8'h50,
                                                  8'h2e,8'h17,8'h9e,8'h4f,8'hb2,8'h59,8'hb9,8'hc9,8'h7d,8'hab,8'hc0,8'h60,8'h30,8'h18,8'h0c,8'h06,
                                                  8'hf5,8'hef,8'he2,8'h71,8'had,8'hc3,8'hf4,8'h7a,8'h9a,8'h4d,8'hb3,8'hcc,8'h66,8'h33,8'h8c,8'h46,
                                                  8'h0f,8'h92,8'h49,8'hb1,8'hcd,8'hf3,8'hec,8'h76,8'hf4,8'h7a,8'h3d,8'h8b,8'hd0,8'h68,8'h34,8'h1a,
                                                  8'h11,8'h9d,8'hdb,8'hf8,8'h7c,8'h3e,8'h1f,8'h9a,8'hbc,8'h5e,8'h2f,8'h82,8'h41,8'hb5,8'hcf,8'hf2,
                                                  8'h69,8'ha1,8'hc5,8'hf7,8'hee,8'h77,8'hae,8'h57,8'hd7,8'hfe,8'h7f,8'haa,8'h55,8'hbf,8'hca,8'h65,
                                                  8'hb4,8'h5a,8'h2d,8'h83,8'hd4,8'h6a,8'h35,8'h8f,8'h24,8'h12,8'h09,8'h91,8'hdd,8'hfb,8'he8,8'h74,
                                                  8'hfc,8'h7e,8'h3f,8'h8a,8'h45,8'hb7,8'hce,8'h67,8'h4d,8'hb3,8'hcc,8'h66,8'h33,8'h8c,8'h46,8'h23,
                                                  8'h52,8'h29,8'h81,8'hd5,8'hff,8'hea,8'h75,8'haf,8'h7e,8'h3f,8'h8a,8'h45,8'hb7,8'hce,8'h67,8'ha6,
                                                  8'h3e,8'h1f,8'h9a,8'h4d,8'hb3,8'hcc,8'h66,8'h33,8'hcb,8'hf0,8'h78,8'h3c,8'h1e,8'h0f,8'h92,8'h49,
                                                  8'h0d,8'h93,8'hdc,8'h6e,8'h37,8'h8e,8'h47,8'hb6,8'h11,8'h9d,8'hdb,8'hf8,8'h7c,8'h3e,8'h1f,8'h9a,
                                                  8'hab,8'hc0,8'h60,8'h30,8'h18,8'h0c,8'h06,8'h03,8'hf4,8'h7a,8'h3d,8'h8b,8'hd0,8'h68,8'h34,8'h1a,
                                                  8'h45,8'hb7,8'hce,8'h67,8'ha6,8'h53,8'hbc,8'h5e,8'h90,8'h48,8'h24,8'h12,8'h09,8'h91,8'hdd,8'hfb,
                                                  8'hf0,8'h78,8'h3c,8'h1e,8'h0f,8'h92,8'h49,8'hb1,8'h55,8'hbf,8'hca,8'h65,8'ha7,8'hc6,8'h63,8'ha4,
                                                  8'h31,8'h8d,8'hd3,8'hfc,8'h7e,8'h3f,8'h8a,8'h45,8'h86,8'h43,8'hb4,8'h5a,8'h2d,8'h83,8'hd4,8'h6a,
                                                  8'h44,8'h22,8'h11,8'h9d,8'hdb,8'hf8,8'h7c,8'h3e,8'h84,8'h42,8'h21,8'h85,8'hd7,8'hfe,8'h7f,8'haa,
                                                  8'hc7,8'hf6,8'h7b,8'ha8,8'h54,8'h2a,8'h15,8'h9f,8'h86,8'h43,8'hb4,8'h5a,8'h2d,8'h83,8'hd4,8'h6a,
                                                  8'ha1,8'hc5,8'hf7,8'hee,8'h77,8'hae,8'h57,8'hbe,8'h7f,8'haa,8'h55,8'hbf,8'hca,8'h65,8'ha7,8'hc6,
                                                  8'ha3,8'hc4,8'h62,8'h31,8'h8d,8'hd3,8'hfc,8'h7e,8'ha4,8'h52,8'h29,8'h81,8'hd5,8'hff,8'hea,8'h75,
                                                  8'h42,8'h21,8'h85,8'hd7,8'hfe,8'h7f,8'haa,8'h55,8'h21,8'h85,8'hd7,8'hfe,8'h7f,8'haa,8'h55,8'hbf,
                                                  8'h67,8'ha6,8'h53,8'hbc,8'h5e,8'h2f,8'h82,8'h41,8'h0f,8'h92,8'h49,8'hb1,8'hcd,8'hf3,8'hec,8'h76,
                                                  8'hb0,8'h58,8'h2c,8'h16,8'h0b,8'h90,8'h48,8'h24,8'h3f,8'h8a,8'h45,8'hb7,8'hce,8'h67,8'ha6,8'h53,
                                                  8'h2b,8'h80,8'h40,8'h20,8'h10,8'h08,8'h04,8'h02,8'h73,8'hac,8'h56,8'h2b,8'h80,8'h40,8'h20,8'h10,
                                                  8'hd8,8'h6c,8'h36,8'h1b,8'h98,8'h4c,8'h26,8'h13,8'h0b,8'h90,8'h48,8'h24,8'h12,8'h09,8'h91,8'hdd,
                                                  8'h66,8'h33,8'h8c,8'h46,8'h23,8'h84,8'h42,8'h21,8'he2,8'h71,8'had,8'hc3,8'hf4,8'h7a,8'h3d,8'h8b,
                                                  8'hc2,8'h61,8'ha5,8'hc7,8'hf6,8'h7b,8'ha8,8'h54,8'ha2,8'h51,8'hbd,8'hcb,8'hf0,8'h78,8'h3c,8'h1e,
                                                  8'hd7,8'hfe,8'h7f,8'haa,8'h55,8'hbf,8'hca,8'h65,8'h30,8'h18,8'h0c,8'h06,8'h03,8'h94,8'h4a,8'h25,
                                                  8'h88,8'h44,8'h22,8'h11,8'h9d,8'hdb,8'hf8,8'h7c,8'hca,8'h65,8'ha7,8'hc6,8'h63,8'ha4,8'h52,8'h29,
                                                  8'hf3,8'hec,8'h76,8'h3b,8'h88,8'h44,8'h22,8'h11,8'he6,8'h73,8'hac,8'h56,8'h2b,8'h80,8'h40,8'h20,
                                                  8'h51,8'hbd,8'hcb,8'hf0,8'h78,8'h3c,8'h1e,8'h0f,8'hf5,8'hef,8'he2,8'h71,8'had,8'hc3,8'hf4,8'h7a,
                                                  8'h73,8'hac,8'h56,8'h2b,8'h80,8'h40,8'h20,8'h10,8'hc0,8'h60,8'h30,8'h18,8'h0c,8'h06,8'h03,8'h94,
                                                  8'hfd,8'heb,8'he0,8'h70,8'h38,8'h1c,8'h0e,8'h07,8'hf2,8'h79,8'ha9,8'hc1,8'hf5,8'hef,8'he2,8'h71,
                                                  8'heb,8'he0,8'h70,8'h38,8'h1c,8'h0e,8'h07,8'h96,8'hbc,8'h5e,8'h2f,8'h82,8'h41,8'hb5,8'hcf,8'hf2,
                                                  8'hc3,8'hf4,8'h7a,8'h3d,8'h8b,8'hd0,8'h68,8'h34,8'h6b,8'ha0,8'h50,8'h28,8'h14,8'h0a,8'h05,8'h97,
                                                  8'h1b,8'h98,8'h4c,8'h26,8'h13,8'h9c,8'h4e,8'h27,8'hb6,8'h5b,8'hb8,8'h5c,8'h2e,8'h17,8'h9e,8'h4f,
                                                  8'haf,8'hc2,8'h61,8'ha5,8'hc7,8'hf6,8'h7b,8'ha8,8'h62,8'h31,8'h8d,8'hd3,8'hfc,8'h7e,8'h3f,8'h8a,
                                                  8'hae,8'h57,8'hbe,8'h5f,8'hba,8'h5d,8'hbb,8'hc8,8'h25,8'h87,8'hd6,8'h6b,8'ha0,8'h50,8'h28,8'h14,
                                                  8'h86,8'h43,8'hb4,8'h5a,8'h2d,8'h83,8'hd4,8'h6a,8'h6a,8'h35,8'h8f,8'hd2,8'h69,8'ha1,8'hc5,8'hf7,
                                                  8'h5c,8'h2e,8'h17,8'h9e,8'h4f,8'hb2,8'h59,8'hb9,8'hdf,8'hfa,8'h7d,8'hab,8'hc0,8'h60,8'h30,8'h18,
                                                  8'h58,8'h2c,8'h16,8'h0b,8'h90,8'h48,8'h24,8'h12,8'h6b,8'ha0,8'h50,8'h28,8'h14,8'h0a,8'h05,8'h97,
                                                  8'h35,8'h8f,8'hd2,8'h69,8'ha1,8'hc5,8'hf7,8'hee,8'h0d,8'h93,8'hdc,8'h6e,8'h37,8'h8e,8'h47,8'hb6,
                                                  8'h86,8'h43,8'hb4,8'h5a,8'h2d,8'h83,8'hd4,8'h6a,8'hd7,8'hfe,8'h7f,8'haa,8'h55,8'hbf,8'hca,8'h65,
                                                  8'h97,8'hde,8'h6f,8'ha2,8'h51,8'hbd,8'hcb,8'hf0,8'hff,8'hea,8'h75,8'haf,8'hc2,8'h61,8'ha5,8'hc7,
                                                  8'h32,8'h19,8'h99,8'hd9,8'hf9,8'he9,8'he1,8'he5,8'h13,8'h9c,8'h4e,8'h27,8'h86,8'h43,8'hb4,8'h5a,
                                                  8'hf5,8'hef,8'he2,8'h71,8'had,8'hc3,8'hf4,8'h7a,8'hb0,8'h58,8'h2c,8'h16,8'h0b,8'h90,8'h48,8'h24,
                                                  8'h27,8'h86,8'h43,8'hb4,8'h5a,8'h2d,8'h83,8'hd4,8'he1,8'he5,8'he7,8'he6,8'h73,8'hac,8'h56,8'h2b,
                                                  8'hf8,8'h7c,8'h3e,8'h1f,8'h9a,8'h4d,8'hb3,8'hcc,8'h37,8'h8e,8'h47,8'hb6,8'h5b,8'hb8,8'h5c,8'h2e,
                                                  8'h08,8'h04,8'h02,8'h01,8'h95,8'hdf,8'hfa,8'h7d,8'h70,8'h38,8'h1c,8'h0e,8'h07,8'h96,8'h4b,8'hb0,
                                                  8'h7a,8'h3d,8'h8b,8'hd0,8'h68,8'h34,8'h1a,8'h0d,8'h31,8'h8d,8'hd3,8'hfc,8'h7e,8'h3f,8'h8a,8'h45,
                                                  8'h28,8'h14,8'h0a,8'h05,8'h97,8'hde,8'h6f,8'ha2,8'h9a,8'h4d,8'hb3,8'hcc,8'h66,8'h33,8'h8c,8'h46,
                                                  8'h0c,8'h06,8'h03,8'h94,8'h4a,8'h25,8'h87,8'hd6,8'h16,8'h0b,8'h90,8'h48,8'h24,8'h12,8'h09,8'h91,
                                                  8'h62,8'h31,8'h8d,8'hd3,8'hfc,8'h7e,8'h3f,8'h8a,8'h30,8'h18,8'h0c,8'h06,8'h03,8'h94,8'h4a,8'h25,
                                                  8'hf3,8'hec,8'h76,8'h3b,8'h88,8'h44,8'h22,8'h11,8'h69,8'ha1,8'hc5,8'hf7,8'hee,8'h77,8'hae,8'h57,
                                                  8'haa,8'h55,8'hbf,8'hca,8'h65,8'ha7,8'hc6,8'h63,8'h4b,8'hb0,8'h58,8'h2c,8'h16,8'h0b,8'h90,8'h48,
                                                  8'h1d,8'h9b,8'hd8,8'h6c,8'h36,8'h1b,8'h98,8'h4c,8'h98,8'h4c,8'h26,8'h13,8'h9c,8'h4e,8'h27,8'h86,
                                                  8'h20,8'h10,8'h08,8'h04,8'h02,8'h01,8'h95,8'hdf,8'h61,8'ha5,8'hc7,8'hf6,8'h7b,8'ha8,8'h54,8'h2a,
                                                  8'h41,8'hb5,8'hcf,8'hf2,8'h79,8'ha9,8'hc1,8'hf5,8'h69,8'ha1,8'hc5,8'hf7,8'hee,8'h77,8'hae,8'h57,
                                                  8'hd3,8'hfc,8'h7e,8'h3f,8'h8a,8'h45,8'hb7,8'hce,8'h5c,8'h2e,8'h17,8'h9e,8'h4f,8'hb2,8'h59,8'hb9,
                                                  8'h5d,8'hbb,8'hc8,8'h64,8'h32,8'h19,8'h99,8'hd9,8'hfd,8'heb,8'he0,8'h70,8'h38,8'h1c,8'h0e,8'h07,
                                                  8'h63,8'ha4,8'h52,8'h29,8'h81,8'hd5,8'hff,8'hea,8'h96,8'h4b,8'hb0,8'h58,8'h2c,8'h16,8'h0b,8'h90,
                                                  8'h38,8'h1c,8'h0e,8'h07,8'h96,8'h4b,8'hb0,8'h58,8'h0c,8'h06,8'h03,8'h94,8'h4a,8'h25,8'h87,8'hd6,
                                                  8'h06,8'h03,8'h94,8'h4a,8'h25,8'h87,8'hd6,8'h6b,8'h04,8'h02,8'h01,8'h95,8'hdf,8'hfa,8'h7d,8'hab,
                                                  8'h38,8'h1c,8'h0e,8'h07,8'h96,8'h4b,8'hb0,8'h58,8'h12,8'h09,8'h91,8'hdd,8'hfb,8'he8,8'h74,8'h3a,
                                                  8'hfd,8'heb,8'he0,8'h70,8'h38,8'h1c,8'h0e,8'h07,8'h17,8'h9e,8'h4f,8'hb2,8'h59,8'hb9,8'hc9,8'hf1,
                                                  8'h2c,8'h16,8'h0b,8'h90,8'h48,8'h24,8'h12,8'h09,8'hf9,8'he9,8'he1,8'he5,8'he7,8'he6,8'h73,8'hac,
                                                  8'h5d,8'hbb,8'hc8,8'h64,8'h32,8'h19,8'h99,8'hd9,8'h31,8'h8d,8'hd3,8'hfc,8'h7e,8'h3f,8'h8a,8'h45,
                                                  8'hb6,8'h5b,8'hb8,8'h5c,8'h2e,8'h17,8'h9e,8'h4f,8'h97,8'hde,8'h6f,8'ha2,8'h51,8'hbd,8'hcb,8'hf0,
                                                  8'hd1,8'hfd,8'heb,8'he0,8'h70,8'h38,8'h1c,8'h0e,8'h9c,8'h4e,8'h27,8'h86,8'h43,8'hb4,8'h5a,8'h2d,
                                                  8'h75,8'haf,8'hc2,8'h61,8'ha5,8'hc7,8'hf6,8'h7b,8'h51,8'hbd,8'hcb,8'hf0,8'h78,8'h3c,8'h1e,8'h0f,
                                                  8'h95,8'hdf,8'hfa,8'h7d,8'hab,8'hc0,8'h60,8'h30,8'heb,8'he0,8'h70,8'h38,8'h1c,8'h0e,8'h07,8'h96,
                                                  8'h85,8'hd7,8'hfe,8'h7f,8'haa,8'h55,8'hbf,8'hca,8'h15,8'h9f,8'hda,8'h6d,8'ha3,8'hc4,8'h62,8'h31,
                                                  8'h2b,8'h80,8'h40,8'h20,8'h10,8'h08,8'h04,8'h02,8'he2,8'h71,8'had,8'hc3,8'hf4,8'h7a,8'h3d,8'h8b,
                                                  8'h49,8'hb1,8'hcd,8'hf3,8'hec,8'h76,8'h3b,8'h88,8'h22,8'h11,8'h9d,8'hdb,8'hf8,8'h7c,8'h3e,8'h1f,
                                                  8'h6a,8'h35,8'h8f,8'hd2,8'h69,8'ha1,8'hc5,8'hf7,8'hb8,8'h5c,8'h2e,8'h17,8'h9e,8'h4f,8'hb2,8'h59,
                                                  8'h0c,8'h06,8'h03,8'h94,8'h4a,8'h25,8'h87,8'hd6,8'hc4,8'h62,8'h31,8'h8d,8'hd3,8'hfc,8'h7e,8'h3f,
                                                  8'h12,8'h09,8'h91,8'hdd,8'hfb,8'he8,8'h74,8'h3a,8'hd7,8'hfe,8'h7f,8'haa,8'h55,8'hbf,8'hca,8'h65,
                                                  8'h47,8'hb6,8'h5b,8'hb8,8'h5c,8'h2e,8'h17,8'h9e,8'h69,8'ha1,8'hc5,8'hf7,8'hee,8'h77,8'hae,8'h57,
                                                  8'h77,8'hae,8'h57,8'hbe,8'h5f,8'hba,8'h5d,8'hbb,8'h6b,8'ha0,8'h50,8'h28,8'h14,8'h0a,8'h05,8'h97,
                                                  8'h36,8'h1b,8'h98,8'h4c,8'h26,8'h13,8'h9c,8'h4e,8'h66,8'h33,8'h8c,8'h46,8'h23,8'h84,8'h42,8'h21,
                                                  8'h0e,8'h07,8'h96,8'h4b,8'hb0,8'h58,8'h2c,8'h16,8'hf9,8'he9,8'he1,8'he5,8'he7,8'he6,8'h73,8'hac,
                                                  8'hfc,8'h7e,8'h3f,8'h8a,8'h45,8'hb7,8'hce,8'h67,8'h9f,8'hda,8'h6d,8'ha3,8'hc4,8'h62,8'h31,8'h8d,
                                                  8'h52,8'h29,8'h81,8'hd5,8'hff,8'hea,8'h75,8'haf,8'h85,8'hd7,8'hfe,8'h7f,8'haa,8'h55,8'hbf,8'hca,
                                                  8'ha6,8'h53,8'hbc,8'h5e,8'h2f,8'h82,8'h41,8'hb5,8'hb1,8'hcd,8'hf3,8'hec,8'h76,8'h3b,8'h88,8'h44,
                                                  8'hb6,8'h5b,8'hb8,8'h5c,8'h2e,8'h17,8'h9e,8'h4f,8'hba,8'h5d,8'hbb,8'hc8,8'h64,8'h32,8'h19,8'h99,
                                                  8'h3d,8'h8b,8'hd0,8'h68,8'h34,8'h1a,8'h0d,8'h93,8'hbc,8'h5e,8'h2f,8'h82,8'h41,8'hb5,8'hcf,8'hf2,
                                                  8'h42,8'h21,8'h85,8'hd7,8'hfe,8'h7f,8'haa,8'h55,8'h5c,8'h2e,8'h17,8'h9e,8'h4f,8'hb2,8'h59,8'hb9,
                                                  8'hae,8'h57,8'hbe,8'h5f,8'hba,8'h5d,8'hbb,8'hc8,8'h77,8'hae,8'h57,8'hbe,8'h5f,8'hba,8'h5d,8'hbb,
                                                  8'hfb,8'he8,8'h74,8'h3a,8'h1d,8'h9b,8'hd8,8'h6c,8'h6a,8'h35,8'h8f,8'hd2,8'h69,8'ha1,8'hc5,8'hf7,
                                                  8'h38,8'h1c,8'h0e,8'h07,8'h96,8'h4b,8'hb0,8'h58,8'h26,8'h13,8'h9c,8'h4e,8'h27,8'h86,8'h43,8'hb4,
                                                  8'hc8,8'h64,8'h32,8'h19,8'h99,8'hd9,8'hf9,8'he9,8'h35,8'h8f,8'hd2,8'h69,8'ha1,8'hc5,8'hf7,8'hee,
                                                  8'hce,8'h67,8'ha6,8'h53,8'hbc,8'h5e,8'h2f,8'h82,8'h16,8'h0b,8'h90,8'h48,8'h24,8'h12,8'h09,8'h91,
                                                  8'h12,8'h09,8'h91,8'hdd,8'hfb,8'he8,8'h74,8'h3a,8'h4f,8'hb2,8'h59,8'hb9,8'hc9,8'hf1,8'hed,8'he3,
                                                  8'h89,8'hd1,8'hfd,8'heb,8'he0,8'h70,8'h38,8'h1c,8'h3c,8'h1e,8'h0f,8'h92,8'h49,8'hb1,8'hcd,8'hf3,
                                                  8'h57,8'hbe,8'h5f,8'hba,8'h5d,8'hbb,8'hc8,8'h64,8'hc8,8'h64,8'h32,8'h19,8'h99,8'hd9,8'hf9,8'he9,
                                                  8'hcf,8'hf2,8'h79,8'ha9,8'hc1,8'hf5,8'hef,8'he2,8'h17,8'h9e,8'h4f,8'hb2,8'h59,8'hb9,8'hc9,8'hf1,
                                                  8'ha7,8'hc6,8'h63,8'ha4,8'h52,8'h29,8'h81,8'hd5,8'h12,8'h09,8'h91,8'hdd,8'hfb,8'he8,8'h74,8'h3a,
                                                  8'h5f,8'hba,8'h5d,8'hbb,8'hc8,8'h64,8'h32,8'h19,8'haf,8'hc2,8'h61,8'ha5,8'hc7,8'hf6,8'h7b,8'ha8,
                                                  8'h72,8'h39,8'h89,8'hd1,8'hfd,8'heb,8'he0,8'h70,8'h58,8'h2c,8'h16,8'h0b,8'h90,8'h48,8'h24,8'h12,
                                                  8'h47,8'hb6,8'h5b,8'hb8,8'h5c,8'h2e,8'h17,8'h9e,8'h53,8'hbc,8'h5e,8'h2f,8'h82,8'h41,8'hb5,8'hcf,
                                                  8'h0b,8'h90,8'h48,8'h24,8'h12,8'h09,8'h91,8'hdd,8'h79,8'ha9,8'hc1,8'hf5,8'hef,8'he2,8'h71,8'had,
                                                  8'ha1,8'hc5,8'hf7,8'hee,8'h77,8'hae,8'h57,8'hbe,8'hc8,8'h64,8'h32,8'h19,8'h99,8'hd9,8'hf9,8'he9,
                                                  8'h05,8'h97,8'hde,8'h6f,8'ha2,8'h51,8'hbd,8'hcb,8'he5,8'he7,8'he6,8'h73,8'hac,8'h56,8'h2b,8'h80,
                                                  8'h5a,8'h2d,8'h83,8'hd4,8'h6a,8'h35,8'h8f,8'hd2,8'hfa,8'h7d,8'hab,8'hc0,8'h60,8'h30,8'h18,8'h0c,
                                                  8'h02,8'h01,8'h95,8'hdf,8'hfa,8'h7d,8'hab,8'hc0,8'hcc,8'h66,8'h33,8'h8c,8'h46,8'h23,8'h84,8'h42,
                                                  8'hec,8'h76,8'h3b,8'h88,8'h44,8'h22,8'h11,8'h9d,8'hb1,8'hcd,8'hf3,8'hec,8'h76,8'h3b,8'h88,8'h44,
                                                  8'h36,8'h1b,8'h98,8'h4c,8'h26,8'h13,8'h9c,8'h4e,8'h70,8'h38,8'h1c,8'h0e,8'h07,8'h96,8'h4b,8'hb0,
                                                  8'h67,8'ha6,8'h53,8'hbc,8'h5e,8'h2f,8'h82,8'h41,8'had,8'hc3,8'hf4,8'h7a,8'h3d,8'h8b,8'hd0,8'h68,
                                                  8'h68,8'h34,8'h1a,8'h0d,8'h93,8'hdc,8'h6e,8'h37,8'h45,8'hb7,8'hce,8'h67,8'ha6,8'h53,8'hbc,8'h5e,
                                                  8'h6e,8'h37,8'h8e,8'h47,8'hb6,8'h5b,8'hb8,8'h5c,8'h3d,8'h8b,8'hd0,8'h68,8'h34,8'h1a,8'h0d,8'h93,
                                                  8'hda,8'h6d,8'ha3,8'hc4,8'h62,8'h31,8'h8d,8'hd3,8'h4c,8'h26,8'h13,8'h9c,8'h4e,8'h27,8'h86,8'h43,
                                                  8'ha6,8'h53,8'hbc,8'h5e,8'h2f,8'h82,8'h41,8'hb5,8'hc2,8'h61,8'ha5,8'hc7,8'hf6,8'h7b,8'ha8,8'h54,
                                                  8'h05,8'h97,8'hde,8'h6f,8'ha2,8'h51,8'hbd,8'hcb,8'hf4,8'h7a,8'h3d,8'h8b,8'hd0,8'h68,8'h34,8'h1a};
  
  localparam [(P_FLIT_WD * 8) - 1 : 0] P_COEF2 =  {P_ZERO_PAD,
                                                  8'h67,8'ha6,8'h53,8'hbc,8'h5e,8'h2f,8'h82,8'h41,8'h45,8'hb7,8'hce,8'h67,8'ha6,8'h53,8'hbc,8'h5e,
                                                  8'h13,8'h9c,8'h4e,8'h27,8'h86,8'h43,8'hb4,8'h5a,8'hdb,8'hf8,8'h7c,8'h3e,8'h1f,8'h9a,8'h4d,8'hb3,
                                                  8'h81,8'hd5,8'hff,8'hea,8'h75,8'haf,8'hc2,8'h61,8'hae,8'h57,8'hbe,8'h5f,8'hba,8'h5d,8'hbb,8'hc8,
                                                  8'hdd,8'hfb,8'he8,8'h74,8'h3a,8'h1d,8'h9b,8'hd8,8'h14,8'h0a,8'h05,8'h97,8'hde,8'h6f,8'ha2,8'h51,
                                                  8'h9b,8'hd8,8'h6c,8'h36,8'h1b,8'h98,8'h4c,8'h26,8'h94,8'h4a,8'h25,8'h87,8'hd6,8'h6b,8'ha0,8'h50,
                                                  8'h4d,8'hb3,8'hcc,8'h66,8'h33,8'h8c,8'h46,8'h23,8'hc8,8'h64,8'h32,8'h19,8'h99,8'hd9,8'hf9,8'he9,
                                                  8'hfc,8'h7e,8'h3f,8'h8a,8'h45,8'hb7,8'hce,8'h67,8'h1c,8'h0e,8'h07,8'h96,8'h4b,8'hb0,8'h58,8'h2c,
                                                  8'h28,8'h14,8'h0a,8'h05,8'h97,8'hde,8'h6f,8'ha2,8'h83,8'hd4,8'h6a,8'h35,8'h8f,8'hd2,8'h69,8'ha1,
                                                  8'h32,8'h19,8'h99,8'hd9,8'hf9,8'he9,8'he1,8'he5,8'h40,8'h20,8'h10,8'h08,8'h04,8'h02,8'h01,8'h95,
                                                  8'h83,8'hd4,8'h6a,8'h35,8'h8f,8'hd2,8'h69,8'ha1,8'h4e,8'h27,8'h86,8'h43,8'hb4,8'h5a,8'h2d,8'h83,
                                                  8'hdd,8'hfb,8'he8,8'h74,8'h3a,8'h1d,8'h9b,8'hd8,8'h64,8'h32,8'h19,8'h99,8'hd9,8'hf9,8'he9,8'he1,
                                                  8'h3c,8'h1e,8'h0f,8'h92,8'h49,8'hb1,8'hcd,8'hf3,8'h04,8'h02,8'h01,8'h95,8'hdf,8'hfa,8'h7d,8'hab,
                                                  8'h4d,8'hb3,8'hcc,8'h66,8'h33,8'h8c,8'h46,8'h23,8'hb1,8'hcd,8'hf3,8'hec,8'h76,8'h3b,8'h88,8'h44,
                                                  8'h63,8'ha4,8'h52,8'h29,8'h81,8'hd5,8'hff,8'hea,8'h25,8'h87,8'hd6,8'h6b,8'ha0,8'h50,8'h28,8'h14,
                                                  8'h7f,8'haa,8'h55,8'hbf,8'hca,8'h65,8'ha7,8'hc6,8'h03,8'h94,8'h4a,8'h25,8'h87,8'hd6,8'h6b,8'ha0,
                                                  8'h4e,8'h27,8'h86,8'h43,8'hb4,8'h5a,8'h2d,8'h83,8'h52,8'h29,8'h81,8'hd5,8'hff,8'hea,8'h75,8'haf,
                                                  8'h16,8'h0b,8'h90,8'h48,8'h24,8'h12,8'h09,8'h91,8'hb0,8'h58,8'h2c,8'h16,8'h0b,8'h90,8'h48,8'h24,
                                                  8'h23,8'h84,8'h42,8'h21,8'h85,8'hd7,8'hfe,8'h7f,8'hb9,8'hc9,8'hf1,8'hed,8'he3,8'he4,8'h72,8'h39,
                                                  8'had,8'hc3,8'hf4,8'h7a,8'h3d,8'h8b,8'hd0,8'h68,8'h75,8'haf,8'hc2,8'h61,8'ha5,8'hc7,8'hf6,8'h7b,
                                                  8'h3c,8'h1e,8'h0f,8'h92,8'h49,8'hb1,8'hcd,8'hf3,8'he8,8'h74,8'h3a,8'h1d,8'h9b,8'hd8,8'h6c,8'h36,
                                                  8'h4b,8'hb0,8'h58,8'h2c,8'h16,8'h0b,8'h90,8'h48,8'h3b,8'h88,8'h44,8'h22,8'h11,8'h9d,8'hdb,8'hf8,
                                                  8'hcd,8'hf3,8'hec,8'h76,8'h3b,8'h88,8'h44,8'h22,8'hf6,8'h7b,8'ha8,8'h54,8'h2a,8'h15,8'h9f,8'hda,
                                                  8'h01,8'h95,8'hdf,8'hfa,8'h7d,8'hab,8'hc0,8'h60,8'hdb,8'hf8,8'h7c,8'h3e,8'h1f,8'h9a,8'h4d,8'hb3,
                                                  8'h1b,8'h98,8'h4c,8'h26,8'h13,8'h9c,8'h4e,8'h27,8'ha1,8'hc5,8'hf7,8'hee,8'h77,8'hae,8'h57,8'hbe,
                                                  8'hd9,8'hf9,8'he9,8'he1,8'he5,8'he7,8'he6,8'h73,8'h50,8'h28,8'h14,8'h0a,8'h05,8'h97,8'hde,8'h6f,
                                                  8'h4c,8'h26,8'h13,8'h9c,8'h4e,8'h27,8'h86,8'h43,8'ha6,8'h53,8'hbc,8'h5e,8'h2f,8'h82,8'h41,8'hb5,
                                                  8'h36,8'h1b,8'h98,8'h4c,8'h26,8'h13,8'h9c,8'h4e,8'hce,8'h67,8'ha6,8'h53,8'hbc,8'h5e,8'h2f,8'h82,
                                                  8'h9f,8'hda,8'h6d,8'ha3,8'hc4,8'h62,8'h31,8'h8d,8'h7f,8'haa,8'h55,8'hbf,8'hca,8'h65,8'ha7,8'hc6,
                                                  8'h68,8'h34,8'h1a,8'h0d,8'h93,8'hdc,8'h6e,8'h37,8'h51,8'hbd,8'hcb,8'hf0,8'h78,8'h3c,8'h1e,8'h0f,
                                                  8'h5a,8'h2d,8'h83,8'hd4,8'h6a,8'h35,8'h8f,8'hd2,8'h06,8'h03,8'h94,8'h4a,8'h25,8'h87,8'hd6,8'h6b,
                                                  8'h01,8'h95,8'hdf,8'hfa,8'h7d,8'hab,8'hc0,8'h60,8'hb2,8'h59,8'hb9,8'hc9,8'hf1,8'hed,8'he3,8'he4,
                                                  8'h4f,8'hb2,8'h59,8'hb9,8'hc9,8'hf1,8'hed,8'he3,8'hb1,8'hcd,8'hf3,8'hec,8'h76,8'h3b,8'h88,8'h44,
                                                  8'h1e,8'h0f,8'h92,8'h49,8'hb1,8'hcd,8'hf3,8'hec,8'h47,8'hb6,8'h5b,8'hb8,8'h5c,8'h2e,8'h17,8'h9e,
                                                  8'h75,8'haf,8'hc2,8'h61,8'ha5,8'hc7,8'hf6,8'h7b,8'ha6,8'h53,8'hbc,8'h5e,8'h2f,8'h82,8'h41,8'hb5,
                                                  8'h37,8'h8e,8'h47,8'hb6,8'h5b,8'hb8,8'h5c,8'h2e,8'h6c,8'h36,8'h1b,8'h98,8'h4c,8'h26,8'h13,8'h9c,
                                                  8'h11,8'h9d,8'hdb,8'hf8,8'h7c,8'h3e,8'h1f,8'h9a,8'hb6,8'h5b,8'hb8,8'h5c,8'h2e,8'h17,8'h9e,8'h4f,
                                                  8'h5b,8'hb8,8'h5c,8'h2e,8'h17,8'h9e,8'h4f,8'hb2,8'h13,8'h9c,8'h4e,8'h27,8'h86,8'h43,8'hb4,8'h5a,
                                                  8'had,8'hc3,8'hf4,8'h7a,8'h3d,8'h8b,8'hd0,8'h68,8'h1b,8'h98,8'h4c,8'h26,8'h13,8'h9c,8'h4e,8'h27,
                                                  8'h1c,8'h0e,8'h07,8'h96,8'h4b,8'hb0,8'h58,8'h2c,8'h05,8'h97,8'hde,8'h6f,8'ha2,8'h51,8'hbd,8'hcb,
                                                  8'h10,8'h08,8'h04,8'h02,8'h01,8'h95,8'hdf,8'hfa,8'h14,8'h0a,8'h05,8'h97,8'hde,8'h6f,8'ha2,8'h51,
                                                  8'h30,8'h18,8'h0c,8'h06,8'h03,8'h94,8'h4a,8'h25,8'h43,8'hb4,8'h5a,8'h2d,8'h83,8'hd4,8'h6a,8'h35,
                                                  8'hf2,8'h79,8'ha9,8'hc1,8'hf5,8'hef,8'he2,8'h71,8'h8d,8'hd3,8'hfc,8'h7e,8'h3f,8'h8a,8'h45,8'hb7,
                                                  8'h4b,8'hb0,8'h58,8'h2c,8'h16,8'h0b,8'h90,8'h48,8'h8b,8'hd0,8'h68,8'h34,8'h1a,8'h0d,8'h93,8'hdc,
                                                  8'h70,8'h38,8'h1c,8'h0e,8'h07,8'h96,8'h4b,8'hb0,8'h9f,8'hda,8'h6d,8'ha3,8'hc4,8'h62,8'h31,8'h8d,
                                                  8'h83,8'hd4,8'h6a,8'h35,8'h8f,8'hd2,8'h69,8'ha1,8'ha0,8'h50,8'h28,8'h14,8'h0a,8'h05,8'h97,8'hde,
                                                  8'h89,8'hd1,8'hfd,8'heb,8'he0,8'h70,8'h38,8'h1c,8'hc4,8'h62,8'h31,8'h8d,8'hd3,8'hfc,8'h7e,8'h3f,
                                                  8'he8,8'h74,8'h3a,8'h1d,8'h9b,8'hd8,8'h6c,8'h36,8'h16,8'h0b,8'h90,8'h48,8'h24,8'h12,8'h09,8'h91,
                                                  8'h41,8'hb5,8'hcf,8'hf2,8'h79,8'ha9,8'hc1,8'hf5,8'h3c,8'h1e,8'h0f,8'h92,8'h49,8'hb1,8'hcd,8'hf3,
                                                  8'h31,8'h8d,8'hd3,8'hfc,8'h7e,8'h3f,8'h8a,8'h45,8'h0a,8'h05,8'h97,8'hde,8'h6f,8'ha2,8'h51,8'hbd,
                                                  8'h47,8'hb6,8'h5b,8'hb8,8'h5c,8'h2e,8'h17,8'h9e,8'h4e,8'h27,8'h86,8'h43,8'hb4,8'h5a,8'h2d,8'h83,
                                                  8'hd1,8'hfd,8'heb,8'he0,8'h70,8'h38,8'h1c,8'h0e,8'h32,8'h19,8'h99,8'hd9,8'hf9,8'he9,8'he1,8'he5,
                                                  8'he5,8'he7,8'he6,8'h73,8'hac,8'h56,8'h2b,8'h80,8'hd2,8'h69,8'ha1,8'hc5,8'hf7,8'hee,8'h77,8'hae,
                                                  8'h03,8'h94,8'h4a,8'h25,8'h87,8'hd6,8'h6b,8'ha0,8'hb2,8'h59,8'hb9,8'hc9,8'hf1,8'hed,8'he3,8'he4,
                                                  8'h0d,8'h93,8'hdc,8'h6e,8'h37,8'h8e,8'h47,8'hb6,8'h85,8'hd7,8'hfe,8'h7f,8'haa,8'h55,8'hbf,8'hca,
                                                  8'hc3,8'hf4,8'h7a,8'h3d,8'h8b,8'hd0,8'h68,8'h34,8'hea,8'h75,8'haf,8'hc2,8'h61,8'ha5,8'hc7,8'hf6,
                                                  8'he4,8'h72,8'h39,8'h89,8'hd1,8'hfd,8'heb,8'he0,8'hcc,8'h66,8'h33,8'h8c,8'h46,8'h23,8'h84,8'h42,
                                                  8'he0,8'h70,8'h38,8'h1c,8'h0e,8'h07,8'h96,8'h4b,8'h3f,8'h8a,8'h45,8'hb7,8'hce,8'h67,8'ha6,8'h53,
                                                  8'he8,8'h74,8'h3a,8'h1d,8'h9b,8'hd8,8'h6c,8'h36,8'h48,8'h24,8'h12,8'h09,8'h91,8'hdd,8'hfb,8'he8,
                                                  8'h96,8'h4b,8'hb0,8'h58,8'h2c,8'h16,8'h0b,8'h90,8'h4a,8'h25,8'h87,8'hd6,8'h6b,8'ha0,8'h50,8'h28,
                                                  8'h36,8'h1b,8'h98,8'h4c,8'h26,8'h13,8'h9c,8'h4e,8'h7c,8'h3e,8'h1f,8'h9a,8'h4d,8'hb3,8'hcc,8'h66,
                                                  8'hb9,8'hc9,8'hf1,8'hed,8'he3,8'he4,8'h72,8'h39,8'h83,8'hd4,8'h6a,8'h35,8'h8f,8'hd2,8'h69,8'ha1,
                                                  8'hbd,8'hcb,8'hf0,8'h78,8'h3c,8'h1e,8'h0f,8'h92,8'h2b,8'h80,8'h40,8'h20,8'h10,8'h08,8'h04,8'h02,
                                                  8'h80,8'h40,8'h20,8'h10,8'h08,8'h04,8'h02,8'h01,8'hcb,8'hf0,8'h78,8'h3c,8'h1e,8'h0f,8'h92,8'h49,
                                                  8'he9,8'he1,8'he5,8'he7,8'he6,8'h73,8'hac,8'h56,8'ha1,8'hc5,8'hf7,8'hee,8'h77,8'hae,8'h57,8'hbe,
                                                  8'h55,8'hbf,8'hca,8'h65,8'ha7,8'hc6,8'h63,8'ha4,8'he5,8'he7,8'he6,8'h73,8'hac,8'h56,8'h2b,8'h80,
                                                  8'hec,8'h76,8'h3b,8'h88,8'h44,8'h22,8'h11,8'h9d,8'hab,8'hc0,8'h60,8'h30,8'h18,8'h0c,8'h06,8'h03,
                                                  8'h72,8'h39,8'h89,8'hd1,8'hfd,8'heb,8'he0,8'h70,8'hd2,8'h69,8'ha1,8'hc5,8'hf7,8'hee,8'h77,8'hae,
                                                  8'h54,8'h2a,8'h15,8'h9f,8'hda,8'h6d,8'ha3,8'hc4,8'h22,8'h11,8'h9d,8'hdb,8'hf8,8'h7c,8'h3e,8'h1f,
                                                  8'he2,8'h71,8'had,8'hc3,8'hf4,8'h7a,8'h3d,8'h8b,8'h03,8'h94,8'h4a,8'h25,8'h87,8'hd6,8'h6b,8'ha0,
                                                  8'h8b,8'hd0,8'h68,8'h34,8'h1a,8'h0d,8'h93,8'hdc,8'h1e,8'h0f,8'h92,8'h49,8'hb1,8'hcd,8'hf3,8'hec,
                                                  8'h5a,8'h2d,8'h83,8'hd4,8'h6a,8'h35,8'h8f,8'hd2,8'h15,8'h9f,8'hda,8'h6d,8'ha3,8'hc4,8'h62,8'h31,
                                                  8'hdd,8'hfb,8'he8,8'h74,8'h3a,8'h1d,8'h9b,8'hd8,8'h02,8'h01,8'h95,8'hdf,8'hfa,8'h7d,8'hab,8'hc0,
                                                  8'h12,8'h09,8'h91,8'hdd,8'hfb,8'he8,8'h74,8'h3a,8'hd7,8'hfe,8'h7f,8'haa,8'h55,8'hbf,8'hca,8'h65,
                                                  8'hbe,8'h5f,8'hba,8'h5d,8'hbb,8'hc8,8'h64,8'h32,8'h5a,8'h2d,8'h83,8'hd4,8'h6a,8'h35,8'h8f,8'hd2,
                                                  8'h51,8'hbd,8'hcb,8'hf0,8'h78,8'h3c,8'h1e,8'h0f,8'hdb,8'hf8,8'h7c,8'h3e,8'h1f,8'h9a,8'h4d,8'hb3,
                                                  8'h59,8'hb9,8'hc9,8'hf1,8'hed,8'he3,8'he4,8'h72,8'h0f,8'h92,8'h49,8'hb1,8'hcd,8'hf3,8'hec,8'h76,
                                                  8'hed,8'he3,8'he4,8'h72,8'h39,8'h89,8'hd1,8'hfd,8'h2a,8'h15,8'h9f,8'hda,8'h6d,8'ha3,8'hc4,8'h62,
                                                  8'hb5,8'hcf,8'hf2,8'h79,8'ha9,8'hc1,8'hf5,8'hef,8'hc7,8'hf6,8'h7b,8'ha8,8'h54,8'h2a,8'h15,8'h9f,
                                                  8'h7e,8'h3f,8'h8a,8'h45,8'hb7,8'hce,8'h67,8'ha6,8'h36,8'h1b,8'h98,8'h4c,8'h26,8'h13,8'h9c,8'h4e,
                                                  8'hbf,8'hca,8'h65,8'ha7,8'hc6,8'h63,8'ha4,8'h52,8'h5a,8'h2d,8'h83,8'hd4,8'h6a,8'h35,8'h8f,8'hd2,
                                                  8'h58,8'h2c,8'h16,8'h0b,8'h90,8'h48,8'h24,8'h12,8'h82,8'h41,8'hb5,8'hcf,8'hf2,8'h79,8'ha9,8'hc1,
                                                  8'h46,8'h23,8'h84,8'h42,8'h21,8'h85,8'hd7,8'hfe,8'h1d,8'h9b,8'hd8,8'h6c,8'h36,8'h1b,8'h98,8'h4c,
                                                  8'hda,8'h6d,8'ha3,8'hc4,8'h62,8'h31,8'h8d,8'hd3,8'hce,8'h67,8'ha6,8'h53,8'hbc,8'h5e,8'h2f,8'h82,
                                                  8'h99,8'hd9,8'hf9,8'he9,8'he1,8'he5,8'he7,8'he6,8'h90,8'h48,8'h24,8'h12,8'h09,8'h91,8'hdd,8'hfb,
                                                  8'h50,8'h28,8'h14,8'h0a,8'h05,8'h97,8'hde,8'h6f,8'h61,8'ha5,8'hc7,8'hf6,8'h7b,8'ha8,8'h54,8'h2a,
                                                  8'h1e,8'h0f,8'h92,8'h49,8'hb1,8'hcd,8'hf3,8'hec,8'h85,8'hd7,8'hfe,8'h7f,8'haa,8'h55,8'hbf,8'hca,
                                                  8'h15,8'h9f,8'hda,8'h6d,8'ha3,8'hc4,8'h62,8'h31,8'h8a,8'h45,8'hb7,8'hce,8'h67,8'ha6,8'h53,8'hbc,
                                                  8'hd8,8'h6c,8'h36,8'h1b,8'h98,8'h4c,8'h26,8'h13,8'hb5,8'hcf,8'hf2,8'h79,8'ha9,8'hc1,8'hf5,8'hef,
                                                  8'h54,8'h2a,8'h15,8'h9f,8'hda,8'h6d,8'ha3,8'hc4,8'hbb,8'hc8,8'h64,8'h32,8'h19,8'h99,8'hd9,8'hf9,
                                                  8'hcc,8'h66,8'h33,8'h8c,8'h46,8'h23,8'h84,8'h42,8'h45,8'hb7,8'hce,8'h67,8'ha6,8'h53,8'hbc,8'h5e,
                                                  8'ha1,8'hc5,8'hf7,8'hee,8'h77,8'hae,8'h57,8'hbe,8'h20,8'h10,8'h08,8'h04,8'h02,8'h01,8'h95,8'hdf,
                                                  8'h90,8'h48,8'h24,8'h12,8'h09,8'h91,8'hdd,8'hfb,8'h77,8'hae,8'h57,8'hbe,8'h5f,8'hba,8'h5d,8'hbb,
                                                  8'hf8,8'h7c,8'h3e,8'h1f,8'h9a,8'h4d,8'hb3,8'hcc,8'hc8,8'h64,8'h32,8'h19,8'h99,8'hd9,8'hf9,8'he9,
                                                  8'hd6,8'h6b,8'ha0,8'h50,8'h28,8'h14,8'h0a,8'h05,8'had,8'hc3,8'hf4,8'h7a,8'h3d,8'h8b,8'hd0,8'h68,
                                                  8'h77,8'hae,8'h57,8'hbe,8'h5f,8'hba,8'h5d,8'hbb,8'h68,8'h34,8'h1a,8'h0d,8'h93,8'hdc,8'h6e,8'h37,
                                                  8'h4e,8'h27,8'h86,8'h43,8'hb4,8'h5a,8'h2d,8'h83,8'hb9,8'hc9,8'hf1,8'hed,8'he3,8'he4,8'h72,8'h39,
                                                  8'hdd,8'hfb,8'he8,8'h74,8'h3a,8'h1d,8'h9b,8'hd8,8'hcb,8'hf0,8'h78,8'h3c,8'h1e,8'h0f,8'h92,8'h49,
                                                  8'hcd,8'hf3,8'hec,8'h76,8'h3b,8'h88,8'h44,8'h22,8'hae,8'h57,8'hbe,8'h5f,8'hba,8'h5d,8'hbb,8'hc8,
                                                  8'ha0,8'h50,8'h28,8'h14,8'h0a,8'h05,8'h97,8'hde,8'h16,8'h0b,8'h90,8'h48,8'h24,8'h12,8'h09,8'h91,
                                                  8'h20,8'h10,8'h08,8'h04,8'h02,8'h01,8'h95,8'hdf,8'h16,8'h0b,8'h90,8'h48,8'h24,8'h12,8'h09,8'h91,
                                                  8'hd8,8'h6c,8'h36,8'h1b,8'h98,8'h4c,8'h26,8'h13,8'h57,8'hbe,8'h5f,8'hba,8'h5d,8'hbb,8'hc8,8'h64,
                                                  8'h35,8'h8f,8'hd2,8'h69,8'ha1,8'hc5,8'hf7,8'hee,8'hc4,8'h62,8'h31,8'h8d,8'hd3,8'hfc,8'h7e,8'h3f,
                                                  8'hcb,8'hf0,8'h78,8'h3c,8'h1e,8'h0f,8'h92,8'h49,8'h21,8'h85,8'hd7,8'hfe,8'h7f,8'haa,8'h55,8'hbf,
                                                  8'h43,8'hb4,8'h5a,8'h2d,8'h83,8'hd4,8'h6a,8'h35,8'hc6,8'h63,8'ha4,8'h52,8'h29,8'h81,8'hd5,8'hff,
                                                  8'h5d,8'hbb,8'hc8,8'h64,8'h32,8'h19,8'h99,8'hd9,8'h67,8'ha6,8'h53,8'hbc,8'h5e,8'h2f,8'h82,8'h41,
                                                  8'hee,8'h77,8'hae,8'h57,8'hbe,8'h5f,8'hba,8'h5d,8'hd8,8'h6c,8'h36,8'h1b,8'h98,8'h4c,8'h26,8'h13,
                                                  8'hd7,8'hfe,8'h7f,8'haa,8'h55,8'hbf,8'hca,8'h65,8'h18,8'h0c,8'h06,8'h03,8'h94,8'h4a,8'h25,8'h87,
                                                  8'he2,8'h71,8'had,8'hc3,8'hf4,8'h7a,8'h3d,8'h8b,8'h5b,8'hb8,8'h5c,8'h2e,8'h17,8'h9e,8'h4f,8'hb2,
                                                  8'h9a,8'h4d,8'hb3,8'hcc,8'h66,8'h33,8'h8c,8'h46,8'h9c,8'h4e,8'h27,8'h86,8'h43,8'hb4,8'h5a,8'h2d,
                                                  8'hd1,8'hfd,8'heb,8'he0,8'h70,8'h38,8'h1c,8'h0e,8'hdb,8'hf8,8'h7c,8'h3e,8'h1f,8'h9a,8'h4d,8'hb3,
                                                  8'hd9,8'hf9,8'he9,8'he1,8'he5,8'he7,8'he6,8'h73,8'h28,8'h14,8'h0a,8'h05,8'h97,8'hde,8'h6f,8'ha2,
                                                  8'ha2,8'h51,8'hbd,8'hcb,8'hf0,8'h78,8'h3c,8'h1e,8'h60,8'h30,8'h18,8'h0c,8'h06,8'h03,8'h94,8'h4a,
                                                  8'h1d,8'h9b,8'hd8,8'h6c,8'h36,8'h1b,8'h98,8'h4c,8'h9f,8'hda,8'h6d,8'ha3,8'hc4,8'h62,8'h31,8'h8d,
                                                  8'h5f,8'hba,8'h5d,8'hbb,8'hc8,8'h64,8'h32,8'h19,8'he5,8'he7,8'he6,8'h73,8'hac,8'h56,8'h2b,8'h80,
                                                  8'ha7,8'hc6,8'h63,8'ha4,8'h52,8'h29,8'h81,8'hd5,8'hea,8'h75,8'haf,8'hc2,8'h61,8'ha5,8'hc7,8'hf6,
                                                  8'hb1,8'hcd,8'hf3,8'hec,8'h76,8'h3b,8'h88,8'h44,8'h04,8'h02,8'h01,8'h95,8'hdf,8'hfa,8'h7d,8'hab,
                                                  8'h8e,8'h47,8'hb6,8'h5b,8'hb8,8'h5c,8'h2e,8'h17,8'haf,8'hc2,8'h61,8'ha5,8'hc7,8'hf6,8'h7b,8'ha8,
                                                  8'ha2,8'h51,8'hbd,8'hcb,8'hf0,8'h78,8'h3c,8'h1e,8'hab,8'hc0,8'h60,8'h30,8'h18,8'h0c,8'h06,8'h03,
                                                  8'h8b,8'hd0,8'h68,8'h34,8'h1a,8'h0d,8'h93,8'hdc,8'h42,8'h21,8'h85,8'hd7,8'hfe,8'h7f,8'haa,8'h55,
                                                  8'h1f,8'h9a,8'h4d,8'hb3,8'hcc,8'h66,8'h33,8'h8c,8'hf9,8'he9,8'he1,8'he5,8'he7,8'he6,8'h73,8'hac,
                                                  8'h22,8'h11,8'h9d,8'hdb,8'hf8,8'h7c,8'h3e,8'h1f,8'ha9,8'hc1,8'hf5,8'hef,8'he2,8'h71,8'had,8'hc3};
  
  localparam [(P_FLIT_WD * 8) - 1 : 0] P_COEF1 =  {P_ZERO_PAD,
                                                  8'h9d,8'hdb,8'hf8,8'h7c,8'h3e,8'h1f,8'h9a,8'h4d,8'h80,8'h40,8'h20,8'h10,8'h08,8'h04,8'h02,8'h01,
                                                  8'hae,8'h57,8'hbe,8'h5f,8'hba,8'h5d,8'hbb,8'hc8,8'hcd,8'hf3,8'hec,8'h76,8'h3b,8'h88,8'h44,8'h22,
                                                  8'h1b,8'h98,8'h4c,8'h26,8'h13,8'h9c,8'h4e,8'h27,8'h3b,8'h88,8'h44,8'h22,8'h11,8'h9d,8'hdb,8'hf8,
                                                  8'hea,8'h75,8'haf,8'hc2,8'h61,8'ha5,8'hc7,8'hf6,8'h08,8'h04,8'h02,8'h01,8'h95,8'hdf,8'hfa,8'h7d,
                                                  8'hea,8'h75,8'haf,8'hc2,8'h61,8'ha5,8'hc7,8'hf6,8'h93,8'hdc,8'h6e,8'h37,8'h8e,8'h47,8'hb6,8'h5b,
                                                  8'h7b,8'ha8,8'h54,8'h2a,8'h15,8'h9f,8'hda,8'h6d,8'hd9,8'hf9,8'he9,8'he1,8'he5,8'he7,8'he6,8'h73,
                                                  8'h02,8'h01,8'h95,8'hdf,8'hfa,8'h7d,8'hab,8'hc0,8'h60,8'h30,8'h18,8'h0c,8'h06,8'h03,8'h94,8'h4a,
                                                  8'h41,8'hb5,8'hcf,8'hf2,8'h79,8'ha9,8'hc1,8'hf5,8'ha8,8'h54,8'h2a,8'h15,8'h9f,8'hda,8'h6d,8'ha3,
                                                  8'h88,8'h44,8'h22,8'h11,8'h9d,8'hdb,8'hf8,8'h7c,8'ha7,8'hc6,8'h63,8'ha4,8'h52,8'h29,8'h81,8'hd5,
                                                  8'h24,8'h12,8'h09,8'h91,8'hdd,8'hfb,8'he8,8'h74,8'h0a,8'h05,8'h97,8'hde,8'h6f,8'ha2,8'h51,8'hbd,
                                                  8'h36,8'h1b,8'h98,8'h4c,8'h26,8'h13,8'h9c,8'h4e,8'h1c,8'h0e,8'h07,8'h96,8'h4b,8'hb0,8'h58,8'h2c,
                                                  8'h03,8'h94,8'h4a,8'h25,8'h87,8'hd6,8'h6b,8'ha0,8'h3e,8'h1f,8'h9a,8'h4d,8'hb3,8'hcc,8'h66,8'h33,
                                                  8'h10,8'h08,8'h04,8'h02,8'h01,8'h95,8'hdf,8'hfa,8'h31,8'h8d,8'hd3,8'hfc,8'h7e,8'h3f,8'h8a,8'h45,
                                                  8'h06,8'h03,8'h94,8'h4a,8'h25,8'h87,8'hd6,8'h6b,8'h4f,8'hb2,8'h59,8'hb9,8'hc9,8'hf1,8'hed,8'he3,
                                                  8'h9d,8'hdb,8'hf8,8'h7c,8'h3e,8'h1f,8'h9a,8'h4d,8'h76,8'h3b,8'h88,8'h44,8'h22,8'h11,8'h9d,8'hdb,
                                                  8'h7a,8'h3d,8'h8b,8'hd0,8'h68,8'h34,8'h1a,8'h0d,8'hdd,8'hfb,8'he8,8'h74,8'h3a,8'h1d,8'h9b,8'hd8,
                                                  8'hea,8'h75,8'haf,8'hc2,8'h61,8'ha5,8'hc7,8'hf6,8'hd8,8'h6c,8'h36,8'h1b,8'h98,8'h4c,8'h26,8'h13,
                                                  8'hb6,8'h5b,8'hb8,8'h5c,8'h2e,8'h17,8'h9e,8'h4f,8'h6b,8'ha0,8'h50,8'h28,8'h14,8'h0a,8'h05,8'h97,
                                                  8'hf7,8'hee,8'h77,8'hae,8'h57,8'hbe,8'h5f,8'hba,8'h94,8'h4a,8'h25,8'h87,8'hd6,8'h6b,8'ha0,8'h50,
                                                  8'h83,8'hd4,8'h6a,8'h35,8'h8f,8'hd2,8'h69,8'ha1,8'h6e,8'h37,8'h8e,8'h47,8'hb6,8'h5b,8'hb8,8'h5c,
                                                  8'hcf,8'hf2,8'h79,8'ha9,8'hc1,8'hf5,8'hef,8'he2,8'h30,8'h18,8'h0c,8'h06,8'h03,8'h94,8'h4a,8'h25,
                                                  8'hf9,8'he9,8'he1,8'he5,8'he7,8'he6,8'h73,8'hac,8'h54,8'h2a,8'h15,8'h9f,8'hda,8'h6d,8'ha3,8'hc4,
                                                  8'h94,8'h4a,8'h25,8'h87,8'hd6,8'h6b,8'ha0,8'h50,8'h2c,8'h16,8'h0b,8'h90,8'h48,8'h24,8'h12,8'h09,
                                                  8'h2b,8'h80,8'h40,8'h20,8'h10,8'h08,8'h04,8'h02,8'hfb,8'he8,8'h74,8'h3a,8'h1d,8'h9b,8'hd8,8'h6c,
                                                  8'h5f,8'hba,8'h5d,8'hbb,8'hc8,8'h64,8'h32,8'h19,8'h39,8'h89,8'hd1,8'hfd,8'heb,8'he0,8'h70,8'h38,
                                                  8'hdc,8'h6e,8'h37,8'h8e,8'h47,8'hb6,8'h5b,8'hb8,8'hef,8'he2,8'h71,8'had,8'hc3,8'hf4,8'h7a,8'h3d,
                                                  8'h14,8'h0a,8'h05,8'h97,8'hde,8'h6f,8'ha2,8'h51,8'h6e,8'h37,8'h8e,8'h47,8'hb6,8'h5b,8'hb8,8'h5c,
                                                  8'hf2,8'h79,8'ha9,8'hc1,8'hf5,8'hef,8'he2,8'h71,8'hb0,8'h58,8'h2c,8'h16,8'h0b,8'h90,8'h48,8'h24,
                                                  8'h8b,8'hd0,8'h68,8'h34,8'h1a,8'h0d,8'h93,8'hdc,8'hf1,8'hed,8'he3,8'he4,8'h72,8'h39,8'h89,8'hd1,
                                                  8'hc5,8'hf7,8'hee,8'h77,8'hae,8'h57,8'hbe,8'h5f,8'hb5,8'hcf,8'hf2,8'h79,8'ha9,8'hc1,8'hf5,8'hef,
                                                  8'hd5,8'hff,8'hea,8'h75,8'haf,8'hc2,8'h61,8'ha5,8'ha3,8'hc4,8'h62,8'h31,8'h8d,8'hd3,8'hfc,8'h7e,
                                                  8'he5,8'he7,8'he6,8'h73,8'hac,8'h56,8'h2b,8'h80,8'h89,8'hd1,8'hfd,8'heb,8'he0,8'h70,8'h38,8'h1c,
                                                  8'h1e,8'h0f,8'h92,8'h49,8'hb1,8'hcd,8'hf3,8'hec,8'hb4,8'h5a,8'h2d,8'h83,8'hd4,8'h6a,8'h35,8'h8f,
                                                  8'hd3,8'hfc,8'h7e,8'h3f,8'h8a,8'h45,8'hb7,8'hce,8'h86,8'h43,8'hb4,8'h5a,8'h2d,8'h83,8'hd4,8'h6a,
                                                  8'h2a,8'h15,8'h9f,8'hda,8'h6d,8'ha3,8'hc4,8'h62,8'h83,8'hd4,8'h6a,8'h35,8'h8f,8'hd2,8'h69,8'ha1,
                                                  8'h77,8'hae,8'h57,8'hbe,8'h5f,8'hba,8'h5d,8'hbb,8'h3c,8'h1e,8'h0f,8'h92,8'h49,8'hb1,8'hcd,8'hf3,
                                                  8'h33,8'h8c,8'h46,8'h23,8'h84,8'h42,8'h21,8'h85,8'h65,8'ha7,8'hc6,8'h63,8'ha4,8'h52,8'h29,8'h81,
                                                  8'hf2,8'h79,8'ha9,8'hc1,8'hf5,8'hef,8'he2,8'h71,8'h79,8'ha9,8'hc1,8'hf5,8'hef,8'he2,8'h71,8'had,
                                                  8'h8d,8'hd3,8'hfc,8'h7e,8'h3f,8'h8a,8'h45,8'hb7,8'h21,8'h85,8'hd7,8'hfe,8'h7f,8'haa,8'h55,8'hbf,
                                                  8'h22,8'h11,8'h9d,8'hdb,8'hf8,8'h7c,8'h3e,8'h1f,8'hb8,8'h5c,8'h2e,8'h17,8'h9e,8'h4f,8'hb2,8'h59,
                                                  8'hf5,8'hef,8'he2,8'h71,8'had,8'hc3,8'hf4,8'h7a,8'h6c,8'h36,8'h1b,8'h98,8'h4c,8'h26,8'h13,8'h9c,
                                                  8'h8e,8'h47,8'hb6,8'h5b,8'hb8,8'h5c,8'h2e,8'h17,8'h48,8'h24,8'h12,8'h09,8'h91,8'hdd,8'hfb,8'he8,
                                                  8'hc6,8'h63,8'ha4,8'h52,8'h29,8'h81,8'hd5,8'hff,8'hdc,8'h6e,8'h37,8'h8e,8'h47,8'hb6,8'h5b,8'hb8,
                                                  8'h4f,8'hb2,8'h59,8'hb9,8'hc9,8'hf1,8'hed,8'he3,8'h7d,8'hab,8'hc0,8'h60,8'h30,8'h18,8'h0c,8'h06,
                                                  8'he4,8'h72,8'h39,8'h89,8'hd1,8'hfd,8'heb,8'he0,8'h10,8'h08,8'h04,8'h02,8'h01,8'h95,8'hdf,8'hfa,
                                                  8'h3c,8'h1e,8'h0f,8'h92,8'h49,8'hb1,8'hcd,8'hf3,8'h41,8'hb5,8'hcf,8'hf2,8'h79,8'ha9,8'hc1,8'hf5,
                                                  8'h3a,8'h1d,8'h9b,8'hd8,8'h6c,8'h36,8'h1b,8'h98,8'h24,8'h12,8'h09,8'h91,8'hdd,8'hfb,8'he8,8'h74,
                                                  8'h09,8'h91,8'hdd,8'hfb,8'he8,8'h74,8'h3a,8'h1d,8'h80,8'h40,8'h20,8'h10,8'h08,8'h04,8'h02,8'h01,
                                                  8'hdc,8'h6e,8'h37,8'h8e,8'h47,8'hb6,8'h5b,8'hb8,8'hac,8'h56,8'h2b,8'h80,8'h40,8'h20,8'h10,8'h08,
                                                  8'h2b,8'h80,8'h40,8'h20,8'h10,8'h08,8'h04,8'h02,8'h98,8'h4c,8'h26,8'h13,8'h9c,8'h4e,8'h27,8'h86,
                                                  8'h67,8'ha6,8'h53,8'hbc,8'h5e,8'h2f,8'h82,8'h41,8'h5d,8'hbb,8'hc8,8'h64,8'h32,8'h19,8'h99,8'hd9,
                                                  8'h9e,8'h4f,8'hb2,8'h59,8'hb9,8'hc9,8'hf1,8'hed,8'hcb,8'hf0,8'h78,8'h3c,8'h1e,8'h0f,8'h92,8'h49,
                                                  8'h01,8'h95,8'hdf,8'hfa,8'h7d,8'hab,8'hc0,8'h60,8'h4e,8'h27,8'h86,8'h43,8'hb4,8'h5a,8'h2d,8'h83,
                                                  8'h42,8'h21,8'h85,8'hd7,8'hfe,8'h7f,8'haa,8'h55,8'ha2,8'h51,8'hbd,8'hcb,8'hf0,8'h78,8'h3c,8'h1e,
                                                  8'h94,8'h4a,8'h25,8'h87,8'hd6,8'h6b,8'ha0,8'h50,8'h64,8'h32,8'h19,8'h99,8'hd9,8'hf9,8'he9,8'he1,
                                                  8'h45,8'hb7,8'hce,8'h67,8'ha6,8'h53,8'hbc,8'h5e,8'h03,8'h94,8'h4a,8'h25,8'h87,8'hd6,8'h6b,8'ha0,
                                                  8'h93,8'hdc,8'h6e,8'h37,8'h8e,8'h47,8'hb6,8'h5b,8'h98,8'h4c,8'h26,8'h13,8'h9c,8'h4e,8'h27,8'h86,
                                                  8'h3e,8'h1f,8'h9a,8'h4d,8'hb3,8'hcc,8'h66,8'h33,8'h41,8'hb5,8'hcf,8'hf2,8'h79,8'ha9,8'hc1,8'hf5,
                                                  8'he0,8'h70,8'h38,8'h1c,8'h0e,8'h07,8'h96,8'h4b,8'hf9,8'he9,8'he1,8'he5,8'he7,8'he6,8'h73,8'hac,
                                                  8'h31,8'h8d,8'hd3,8'hfc,8'h7e,8'h3f,8'h8a,8'h45,8'h93,8'hdc,8'h6e,8'h37,8'h8e,8'h47,8'hb6,8'h5b,
                                                  8'hdc,8'h6e,8'h37,8'h8e,8'h47,8'hb6,8'h5b,8'hb8,8'hd9,8'hf9,8'he9,8'he1,8'he5,8'he7,8'he6,8'h73,
                                                  8'h7b,8'ha8,8'h54,8'h2a,8'h15,8'h9f,8'hda,8'h6d,8'h13,8'h9c,8'h4e,8'h27,8'h86,8'h43,8'hb4,8'h5a,
                                                  8'h3d,8'h8b,8'hd0,8'h68,8'h34,8'h1a,8'h0d,8'h93,8'h8a,8'h45,8'hb7,8'hce,8'h67,8'ha6,8'h53,8'hbc,
                                                  8'h49,8'hb1,8'hcd,8'hf3,8'hec,8'h76,8'h3b,8'h88,8'hc6,8'h63,8'ha4,8'h52,8'h29,8'h81,8'hd5,8'hff,
                                                  8'h7d,8'hab,8'hc0,8'h60,8'h30,8'h18,8'h0c,8'h06,8'hd8,8'h6c,8'h36,8'h1b,8'h98,8'h4c,8'h26,8'h13,
                                                  8'h5e,8'h2f,8'h82,8'h41,8'hb5,8'hcf,8'hf2,8'h79,8'hda,8'h6d,8'ha3,8'hc4,8'h62,8'h31,8'h8d,8'hd3,
                                                  8'h06,8'h03,8'h94,8'h4a,8'h25,8'h87,8'hd6,8'h6b,8'h5e,8'h2f,8'h82,8'h41,8'hb5,8'hcf,8'hf2,8'h79,
                                                  8'h30,8'h18,8'h0c,8'h06,8'h03,8'h94,8'h4a,8'h25,8'hf4,8'h7a,8'h3d,8'h8b,8'hd0,8'h68,8'h34,8'h1a,
                                                  8'h01,8'h95,8'hdf,8'hfa,8'h7d,8'hab,8'hc0,8'h60,8'h06,8'h03,8'h94,8'h4a,8'h25,8'h87,8'hd6,8'h6b,
                                                  8'hd8,8'h6c,8'h36,8'h1b,8'h98,8'h4c,8'h26,8'h13,8'h25,8'h87,8'hd6,8'h6b,8'ha0,8'h50,8'h28,8'h14,
                                                  8'ha5,8'hc7,8'hf6,8'h7b,8'ha8,8'h54,8'h2a,8'h15,8'hb6,8'h5b,8'hb8,8'h5c,8'h2e,8'h17,8'h9e,8'h4f,
                                                  8'h92,8'h49,8'hb1,8'hcd,8'hf3,8'hec,8'h76,8'h3b,8'h7c,8'h3e,8'h1f,8'h9a,8'h4d,8'hb3,8'hcc,8'h66,
                                                  8'h3d,8'h8b,8'hd0,8'h68,8'h34,8'h1a,8'h0d,8'h93,8'hb6,8'h5b,8'hb8,8'h5c,8'h2e,8'h17,8'h9e,8'h4f,
                                                  8'h19,8'h99,8'hd9,8'hf9,8'he9,8'he1,8'he5,8'he7,8'h88,8'h44,8'h22,8'h11,8'h9d,8'hdb,8'hf8,8'h7c,
                                                  8'h0c,8'h06,8'h03,8'h94,8'h4a,8'h25,8'h87,8'hd6,8'ha8,8'h54,8'h2a,8'h15,8'h9f,8'hda,8'h6d,8'ha3,
                                                  8'h13,8'h9c,8'h4e,8'h27,8'h86,8'h43,8'hb4,8'h5a,8'h42,8'h21,8'h85,8'hd7,8'hfe,8'h7f,8'haa,8'h55,
                                                  8'hc2,8'h61,8'ha5,8'hc7,8'hf6,8'h7b,8'ha8,8'h54,8'h89,8'hd1,8'hfd,8'heb,8'he0,8'h70,8'h38,8'h1c,
                                                  8'h69,8'ha1,8'hc5,8'hf7,8'hee,8'h77,8'hae,8'h57,8'h64,8'h32,8'h19,8'h99,8'hd9,8'hf9,8'he9,8'he1,
                                                  8'h70,8'h38,8'h1c,8'h0e,8'h07,8'h96,8'h4b,8'hb0,8'he1,8'he5,8'he7,8'he6,8'h73,8'hac,8'h56,8'h2b,
                                                  8'hf7,8'hee,8'h77,8'hae,8'h57,8'hbe,8'h5f,8'hba,8'hb0,8'h58,8'h2c,8'h16,8'h0b,8'h90,8'h48,8'h24,
                                                  8'h9c,8'h4e,8'h27,8'h86,8'h43,8'hb4,8'h5a,8'h2d,8'hb0,8'h58,8'h2c,8'h16,8'h0b,8'h90,8'h48,8'h24,
                                                  8'hac,8'h56,8'h2b,8'h80,8'h40,8'h20,8'h10,8'h08,8'h67,8'ha6,8'h53,8'hbc,8'h5e,8'h2f,8'h82,8'h41,
                                                  8'h2a,8'h15,8'h9f,8'hda,8'h6d,8'ha3,8'hc4,8'h62,8'h2f,8'h82,8'h41,8'hb5,8'hcf,8'hf2,8'h79,8'ha9,
                                                  8'h9f,8'hda,8'h6d,8'ha3,8'hc4,8'h62,8'h31,8'h8d,8'h7c,8'h3e,8'h1f,8'h9a,8'h4d,8'hb3,8'hcc,8'h66,
                                                  8'ha7,8'hc6,8'h63,8'ha4,8'h52,8'h29,8'h81,8'hd5,8'h06,8'h03,8'h94,8'h4a,8'h25,8'h87,8'hd6,8'h6b,
                                                  8'h38,8'h1c,8'h0e,8'h07,8'h96,8'h4b,8'hb0,8'h58,8'h5d,8'hbb,8'hc8,8'h64,8'h32,8'h19,8'h99,8'hd9,
                                                  8'h77,8'hae,8'h57,8'hbe,8'h5f,8'hba,8'h5d,8'hbb,8'h93,8'hdc,8'h6e,8'h37,8'h8e,8'h47,8'hb6,8'h5b,
                                                  8'hcd,8'hf3,8'hec,8'h76,8'h3b,8'h88,8'h44,8'h22,8'hc6,8'h63,8'ha4,8'h52,8'h29,8'h81,8'hd5,8'hff,
                                                  8'hcf,8'hf2,8'h79,8'ha9,8'hc1,8'hf5,8'hef,8'he2,8'h8f,8'hd2,8'h69,8'ha1,8'hc5,8'hf7,8'hee,8'h77,
                                                  8'hd3,8'hfc,8'h7e,8'h3f,8'h8a,8'h45,8'hb7,8'hce,8'hcb,8'hf0,8'h78,8'h3c,8'h1e,8'h0f,8'h92,8'h49,
                                                  8'h0b,8'h90,8'h48,8'h24,8'h12,8'h09,8'h91,8'hdd,8'hda,8'h6d,8'ha3,8'hc4,8'h62,8'h31,8'h8d,8'hd3,
                                                  8'hb6,8'h5b,8'hb8,8'h5c,8'h2e,8'h17,8'h9e,8'h4f,8'hf1,8'hed,8'he3,8'he4,8'h72,8'h39,8'h89,8'hd1,
                                                  8'h61,8'ha5,8'hc7,8'hf6,8'h7b,8'ha8,8'h54,8'h2a,8'h47,8'hb6,8'h5b,8'hb8,8'h5c,8'h2e,8'h17,8'h9e,
                                                  8'h85,8'hd7,8'hfe,8'h7f,8'haa,8'h55,8'hbf,8'hca,8'haa,8'h55,8'hbf,8'hca,8'h65,8'ha7,8'hc6,8'h63,
                                                  8'h56,8'h2b,8'h80,8'h40,8'h20,8'h10,8'h08,8'h04,8'h9e,8'h4f,8'hb2,8'h59,8'hb9,8'hc9,8'hf1,8'hed,
                                                  8'h07,8'h96,8'h4b,8'hb0,8'h58,8'h2c,8'h16,8'h0b,8'h74,8'h3a,8'h1d,8'h9b,8'hd8,8'h6c,8'h36,8'h1b,
                                                  8'hf3,8'hec,8'h76,8'h3b,8'h88,8'h44,8'h22,8'h11,8'h09,8'h91,8'hdd,8'hfb,8'he8,8'h74,8'h3a,8'h1d,
                                                  8'h15,8'h9f,8'hda,8'h6d,8'ha3,8'hc4,8'h62,8'h31,8'h22,8'h11,8'h9d,8'hdb,8'hf8,8'h7c,8'h3e,8'h1f,
                                                  8'h50,8'h28,8'h14,8'h0a,8'h05,8'h97,8'hde,8'h6f,8'hda,8'h6d,8'ha3,8'hc4,8'h62,8'h31,8'h8d,8'hd3,
                                                  8'hbd,8'hcb,8'hf0,8'h78,8'h3c,8'h1e,8'h0f,8'h92,8'hbe,8'h5f,8'hba,8'h5d,8'hbb,8'hc8,8'h64,8'h32,
                                                  8'h22,8'h11,8'h9d,8'hdb,8'hf8,8'h7c,8'h3e,8'h1f,8'h9a,8'h4d,8'hb3,8'hcc,8'h66,8'h33,8'h8c,8'h46,
                                                  8'h84,8'h42,8'h21,8'h85,8'hd7,8'hfe,8'h7f,8'haa,8'hd8,8'h6c,8'h36,8'h1b,8'h98,8'h4c,8'h26,8'h13,
                                                  8'h9e,8'h4f,8'hb2,8'h59,8'hb9,8'hc9,8'hf1,8'hed,8'h12,8'h09,8'h91,8'hdd,8'hfb,8'he8,8'h74,8'h3a,
                                                  8'h89,8'hd1,8'hfd,8'heb,8'he0,8'h70,8'h38,8'h1c,8'h06,8'h03,8'h94,8'h4a,8'h25,8'h87,8'hd6,8'h6b,
                                                  8'he8,8'h74,8'h3a,8'h1d,8'h9b,8'hd8,8'h6c,8'h36,8'hdc,8'h6e,8'h37,8'h8e,8'h47,8'hb6,8'h5b,8'hb8,
                                                  8'hce,8'h67,8'ha6,8'h53,8'hbc,8'h5e,8'h2f,8'h82,8'h7a,8'h3d,8'h8b,8'hd0,8'h68,8'h34,8'h1a,8'h0d,
                                                  8'h12,8'h09,8'h91,8'hdd,8'hfb,8'he8,8'h74,8'h3a,8'hde,8'h6f,8'ha2,8'h51,8'hbd,8'hcb,8'hf0,8'h78,
                                                  8'h36,8'h1b,8'h98,8'h4c,8'h26,8'h13,8'h9c,8'h4e,8'hb3,8'hcc,8'h66,8'h33,8'h8c,8'h46,8'h23,8'h84,
                                                  8'heb,8'he0,8'h70,8'h38,8'h1c,8'h0e,8'h07,8'h96,8'h09,8'h91,8'hdd,8'hfb,8'he8,8'h74,8'h3a,8'h1d,
                                                  8'h28,8'h14,8'h0a,8'h05,8'h97,8'hde,8'h6f,8'ha2,8'h76,8'h3b,8'h88,8'h44,8'h22,8'h11,8'h9d,8'hdb,
                                                  8'h7c,8'h3e,8'h1f,8'h9a,8'h4d,8'hb3,8'hcc,8'h66,8'hf5,8'hef,8'he2,8'h71,8'had,8'hc3,8'hf4,8'h7a,
                                                  8'h85,8'hd7,8'hfe,8'h7f,8'haa,8'h55,8'hbf,8'hca,8'hf9,8'he9,8'he1,8'he5,8'he7,8'he6,8'h73,8'hac,
                                                  8'h25,8'h87,8'hd6,8'h6b,8'ha0,8'h50,8'h28,8'h14,8'h84,8'h42,8'h21,8'h85,8'hd7,8'hfe,8'h7f,8'haa,
                                                  8'hb4,8'h5a,8'h2d,8'h83,8'hd4,8'h6a,8'h35,8'h8f,8'h2e,8'h17,8'h9e,8'h4f,8'hb2,8'h59,8'hb9,8'hc9,
                                                  8'h05,8'h97,8'hde,8'h6f,8'ha2,8'h51,8'hbd,8'hcb,8'h88,8'h44,8'h22,8'h11,8'h9d,8'hdb,8'hf8,8'h7c,
                                                  8'h1d,8'h9b,8'hd8,8'h6c,8'h36,8'h1b,8'h98,8'h4c,8'hf3,8'hec,8'h76,8'h3b,8'h88,8'h44,8'h22,8'h11,
                                                  8'h59,8'hb9,8'hc9,8'hf1,8'hed,8'he3,8'he4,8'h72,8'hab,8'hc0,8'h60,8'h30,8'h18,8'h0c,8'h06,8'h03,
                                                  8'h12,8'h09,8'h91,8'hdd,8'hfb,8'he8,8'h74,8'h3a,8'h63,8'ha4,8'h52,8'h29,8'h81,8'hd5,8'hff,8'hea,
                                                  8'h1e,8'h0f,8'h92,8'h49,8'hb1,8'hcd,8'hf3,8'hec,8'hb1,8'hcd,8'hf3,8'hec,8'h76,8'h3b,8'h88,8'h44,
                                                  8'he9,8'he1,8'he5,8'he7,8'he6,8'h73,8'hac,8'h56,8'hf3,8'hec,8'h76,8'h3b,8'h88,8'h44,8'h22,8'h11,
                                                  8'hca,8'h65,8'ha7,8'hc6,8'h63,8'ha4,8'h52,8'h29,8'h92,8'h49,8'hb1,8'hcd,8'hf3,8'hec,8'h76,8'h3b};
  
  localparam [(P_FLIT_WD * 8) - 1 : 0] P_COEF0 =  {P_ZERO_PAD,
                                                  8'h2d,8'h83,8'hd4,8'h6a,8'h35,8'h8f,8'hd2,8'h69,8'hcd,8'hf3,8'hec,8'h76,8'h3b,8'h88,8'h44,8'h22,
                                                  8'he5,8'he7,8'he6,8'h73,8'hac,8'h56,8'h2b,8'h80,8'h90,8'h48,8'h24,8'h12,8'h09,8'h91,8'hdd,8'hfb,
                                                  8'h88,8'h44,8'h22,8'h11,8'h9d,8'hdb,8'hf8,8'h7c,8'ha1,8'hc5,8'hf7,8'hee,8'h77,8'hae,8'h57,8'hbe,
                                                  8'h75,8'haf,8'hc2,8'h61,8'ha5,8'hc7,8'hf6,8'h7b,8'h89,8'hd1,8'hfd,8'heb,8'he0,8'h70,8'h38,8'h1c,
                                                  8'he5,8'he7,8'he6,8'h73,8'hac,8'h56,8'h2b,8'h80,8'h4e,8'h27,8'h86,8'h43,8'hb4,8'h5a,8'h2d,8'h83,
                                                  8'hf2,8'h79,8'ha9,8'hc1,8'hf5,8'hef,8'he2,8'h71,8'h9e,8'h4f,8'hb2,8'h59,8'hb9,8'hc9,8'hf1,8'hed,
                                                  8'hce,8'h67,8'ha6,8'h53,8'hbc,8'h5e,8'h2f,8'h82,8'hc3,8'hf4,8'h7a,8'h3d,8'h8b,8'hd0,8'h68,8'h34,
                                                  8'ha2,8'h51,8'hbd,8'hcb,8'hf0,8'h78,8'h3c,8'h1e,8'h24,8'h12,8'h09,8'h91,8'hdd,8'hfb,8'he8,8'h74,
                                                  8'h2e,8'h17,8'h9e,8'h4f,8'hb2,8'h59,8'hb9,8'hc9,8'h65,8'ha7,8'hc6,8'h63,8'ha4,8'h52,8'h29,8'h81,
                                                  8'h51,8'hbd,8'hcb,8'hf0,8'h78,8'h3c,8'h1e,8'h0f,8'hcc,8'h66,8'h33,8'h8c,8'h46,8'h23,8'h84,8'h42,
                                                  8'h39,8'h89,8'hd1,8'hfd,8'heb,8'he0,8'h70,8'h38,8'h4b,8'hb0,8'h58,8'h2c,8'h16,8'h0b,8'h90,8'h48,
                                                  8'h7b,8'ha8,8'h54,8'h2a,8'h15,8'h9f,8'hda,8'h6d,8'ha0,8'h50,8'h28,8'h14,8'h0a,8'h05,8'h97,8'hde,
                                                  8'haf,8'hc2,8'h61,8'ha5,8'hc7,8'hf6,8'h7b,8'ha8,8'h23,8'h84,8'h42,8'h21,8'h85,8'hd7,8'hfe,8'h7f,
                                                  8'h4b,8'hb0,8'h58,8'h2c,8'h16,8'h0b,8'h90,8'h48,8'hf1,8'hed,8'he3,8'he4,8'h72,8'h39,8'h89,8'hd1,
                                                  8'hd3,8'hfc,8'h7e,8'h3f,8'h8a,8'h45,8'hb7,8'hce,8'h04,8'h02,8'h01,8'h95,8'hdf,8'hfa,8'h7d,8'hab,
                                                  8'h87,8'hd6,8'h6b,8'ha0,8'h50,8'h28,8'h14,8'h0a,8'h2f,8'h82,8'h41,8'hb5,8'hcf,8'hf2,8'h79,8'ha9,
                                                  8'hef,8'he2,8'h71,8'had,8'hc3,8'hf4,8'h7a,8'h3d,8'h1f,8'h9a,8'h4d,8'hb3,8'hcc,8'h66,8'h33,8'h8c,
                                                  8'h3c,8'h1e,8'h0f,8'h92,8'h49,8'hb1,8'hcd,8'hf3,8'hf4,8'h7a,8'h3d,8'h8b,8'hd0,8'h68,8'h34,8'h1a,
                                                  8'h0e,8'h07,8'h96,8'h4b,8'hb0,8'h58,8'h2c,8'h16,8'hd2,8'h69,8'ha1,8'hc5,8'hf7,8'hee,8'h77,8'hae,
                                                  8'he8,8'h74,8'h3a,8'h1d,8'h9b,8'hd8,8'h6c,8'h36,8'h53,8'hbc,8'h5e,8'h2f,8'h82,8'h41,8'hb5,8'hcf,
                                                  8'hce,8'h67,8'ha6,8'h53,8'hbc,8'h5e,8'h2f,8'h82,8'hc8,8'h64,8'h32,8'h19,8'h99,8'hd9,8'hf9,8'he9,
                                                  8'h03,8'h94,8'h4a,8'h25,8'h87,8'hd6,8'h6b,8'ha0,8'hf4,8'h7a,8'h3d,8'h8b,8'hd0,8'h68,8'h34,8'h1a,
                                                  8'heb,8'he0,8'h70,8'h38,8'h1c,8'h0e,8'h07,8'h96,8'h02,8'h01,8'h95,8'hdf,8'hfa,8'h7d,8'hab,8'hc0,
                                                  8'h73,8'hac,8'h56,8'h2b,8'h80,8'h40,8'h20,8'h10,8'h86,8'h43,8'hb4,8'h5a,8'h2d,8'h83,8'hd4,8'h6a,
                                                  8'h6e,8'h37,8'h8e,8'h47,8'hb6,8'h5b,8'hb8,8'h5c,8'hf4,8'h7a,8'h3d,8'h8b,8'hd0,8'h68,8'h34,8'h1a,
                                                  8'h90,8'h48,8'h24,8'h12,8'h09,8'h91,8'hdd,8'hfb,8'h64,8'h32,8'h19,8'h99,8'hd9,8'hf9,8'he9,8'he1,
                                                  8'h52,8'h29,8'h81,8'hd5,8'hff,8'hea,8'h75,8'haf,8'hd8,8'h6c,8'h36,8'h1b,8'h98,8'h4c,8'h26,8'h13,
                                                  8'h7d,8'hab,8'hc0,8'h60,8'h30,8'h18,8'h0c,8'h06,8'h26,8'h13,8'h9c,8'h4e,8'h27,8'h86,8'h43,8'hb4,
                                                  8'hcd,8'hf3,8'hec,8'h76,8'h3b,8'h88,8'h44,8'h22,8'hd8,8'h6c,8'h36,8'h1b,8'h98,8'h4c,8'h26,8'h13,
                                                  8'h62,8'h31,8'h8d,8'hd3,8'hfc,8'h7e,8'h3f,8'h8a,8'hbb,8'hc8,8'h64,8'h32,8'h19,8'h99,8'hd9,8'hf9,
                                                  8'h3e,8'h1f,8'h9a,8'h4d,8'hb3,8'hcc,8'h66,8'h33,8'h2d,8'h83,8'hd4,8'h6a,8'h35,8'h8f,8'hd2,8'h69,
                                                  8'h34,8'h1a,8'h0d,8'h93,8'hdc,8'h6e,8'h37,8'h8e,8'h74,8'h3a,8'h1d,8'h9b,8'hd8,8'h6c,8'h36,8'h1b,
                                                  8'hcf,8'hf2,8'h79,8'ha9,8'hc1,8'hf5,8'hef,8'he2,8'h95,8'hdf,8'hfa,8'h7d,8'hab,8'hc0,8'h60,8'h30,
                                                  8'hae,8'h57,8'hbe,8'h5f,8'hba,8'h5d,8'hbb,8'hc8,8'h90,8'h48,8'h24,8'h12,8'h09,8'h91,8'hdd,8'hfb,
                                                  8'h8b,8'hd0,8'h68,8'h34,8'h1a,8'h0d,8'h93,8'hdc,8'hc9,8'hf1,8'hed,8'he3,8'he4,8'h72,8'h39,8'h89,
                                                  8'h7a,8'h3d,8'h8b,8'hd0,8'h68,8'h34,8'h1a,8'h0d,8'hae,8'h57,8'hbe,8'h5f,8'hba,8'h5d,8'hbb,8'hc8,
                                                  8'h2d,8'h83,8'hd4,8'h6a,8'h35,8'h8f,8'hd2,8'h69,8'h7b,8'ha8,8'h54,8'h2a,8'h15,8'h9f,8'hda,8'h6d,
                                                  8'h65,8'ha7,8'hc6,8'h63,8'ha4,8'h52,8'h29,8'h81,8'h81,8'hd5,8'hff,8'hea,8'h75,8'haf,8'hc2,8'h61,
                                                  8'h38,8'h1c,8'h0e,8'h07,8'h96,8'h4b,8'hb0,8'h58,8'h93,8'hdc,8'h6e,8'h37,8'h8e,8'h47,8'hb6,8'h5b,
                                                  8'h4c,8'h26,8'h13,8'h9c,8'h4e,8'h27,8'h86,8'h43,8'hec,8'h76,8'h3b,8'h88,8'h44,8'h22,8'h11,8'h9d,
                                                  8'h93,8'hdc,8'h6e,8'h37,8'h8e,8'h47,8'hb6,8'h5b,8'h2b,8'h80,8'h40,8'h20,8'h10,8'h08,8'h04,8'h02,
                                                  8'h04,8'h02,8'h01,8'h95,8'hdf,8'hfa,8'h7d,8'hab,8'h8a,8'h45,8'hb7,8'hce,8'h67,8'ha6,8'h53,8'hbc,
                                                  8'h8a,8'h45,8'hb7,8'hce,8'h67,8'ha6,8'h53,8'hbc,8'h17,8'h9e,8'h4f,8'hb2,8'h59,8'hb9,8'hc9,8'hf1,
                                                  8'hc2,8'h61,8'ha5,8'hc7,8'hf6,8'h7b,8'ha8,8'h54,8'h99,8'hd9,8'hf9,8'he9,8'he1,8'he5,8'he7,8'he6,
                                                  8'h89,8'hd1,8'hfd,8'heb,8'he0,8'h70,8'h38,8'h1c,8'hdc,8'h6e,8'h37,8'h8e,8'h47,8'hb6,8'h5b,8'hb8,
                                                  8'ha4,8'h52,8'h29,8'h81,8'hd5,8'hff,8'hea,8'h75,8'hb6,8'h5b,8'hb8,8'h5c,8'h2e,8'h17,8'h9e,8'h4f,
                                                  8'h77,8'hae,8'h57,8'hbe,8'h5f,8'hba,8'h5d,8'hbb,8'h05,8'h97,8'hde,8'h6f,8'ha2,8'h51,8'hbd,8'hcb,
                                                  8'h38,8'h1c,8'h0e,8'h07,8'h96,8'h4b,8'hb0,8'h58,8'h66,8'h33,8'h8c,8'h46,8'h23,8'h84,8'h42,8'h21,
                                                  8'h8b,8'hd0,8'h68,8'h34,8'h1a,8'h0d,8'h93,8'hdc,8'ha6,8'h53,8'hbc,8'h5e,8'h2f,8'h82,8'h41,8'hb5,
                                                  8'h94,8'h4a,8'h25,8'h87,8'hd6,8'h6b,8'ha0,8'h50,8'h38,8'h1c,8'h0e,8'h07,8'h96,8'h4b,8'hb0,8'h58,
                                                  8'h3d,8'h8b,8'hd0,8'h68,8'h34,8'h1a,8'h0d,8'h93,8'heb,8'he0,8'h70,8'h38,8'h1c,8'h0e,8'h07,8'h96,
                                                  8'h40,8'h20,8'h10,8'h08,8'h04,8'h02,8'h01,8'h95,8'h88,8'h44,8'h22,8'h11,8'h9d,8'hdb,8'hf8,8'h7c,
                                                  8'h65,8'ha7,8'hc6,8'h63,8'ha4,8'h52,8'h29,8'h81,8'h9e,8'h4f,8'hb2,8'h59,8'hb9,8'hc9,8'hf1,8'hed,
                                                  8'h7c,8'h3e,8'h1f,8'h9a,8'h4d,8'hb3,8'hcc,8'h66,8'h91,8'hdd,8'hfb,8'he8,8'h74,8'h3a,8'h1d,8'h9b,
                                                  8'h12,8'h09,8'h91,8'hdd,8'hfb,8'he8,8'h74,8'h3a,8'h4e,8'h27,8'h86,8'h43,8'hb4,8'h5a,8'h2d,8'h83,
                                                  8'hc7,8'hf6,8'h7b,8'ha8,8'h54,8'h2a,8'h15,8'h9f,8'h0c,8'h06,8'h03,8'h94,8'h4a,8'h25,8'h87,8'hd6,
                                                  8'hc0,8'h60,8'h30,8'h18,8'h0c,8'h06,8'h03,8'h94,8'hc2,8'h61,8'ha5,8'hc7,8'hf6,8'h7b,8'ha8,8'h54,
                                                  8'h25,8'h87,8'hd6,8'h6b,8'ha0,8'h50,8'h28,8'h14,8'h1a,8'h0d,8'h93,8'hdc,8'h6e,8'h37,8'h8e,8'h47,
                                                  8'h39,8'h89,8'hd1,8'hfd,8'heb,8'he0,8'h70,8'h38,8'hfd,8'heb,8'he0,8'h70,8'h38,8'h1c,8'h0e,8'h07,
                                                  8'hc5,8'hf7,8'hee,8'h77,8'hae,8'h57,8'hbe,8'h5f,8'h17,8'h9e,8'h4f,8'hb2,8'h59,8'hb9,8'hc9,8'hf1,
                                                  8'h3a,8'h1d,8'h9b,8'hd8,8'h6c,8'h36,8'h1b,8'h98,8'haa,8'h55,8'hbf,8'hca,8'h65,8'ha7,8'hc6,8'h63,
                                                  8'ha7,8'hc6,8'h63,8'ha4,8'h52,8'h29,8'h81,8'hd5,8'h5e,8'h2f,8'h82,8'h41,8'hb5,8'hcf,8'hf2,8'h79,
                                                  8'he5,8'he7,8'he6,8'h73,8'hac,8'h56,8'h2b,8'h80,8'hdd,8'hfb,8'he8,8'h74,8'h3a,8'h1d,8'h9b,8'hd8,
                                                  8'h07,8'h96,8'h4b,8'hb0,8'h58,8'h2c,8'h16,8'h0b,8'h1e,8'h0f,8'h92,8'h49,8'hb1,8'hcd,8'hf3,8'hec,
                                                  8'he5,8'he7,8'he6,8'h73,8'hac,8'h56,8'h2b,8'h80,8'h3b,8'h88,8'h44,8'h22,8'h11,8'h9d,8'hdb,8'hf8,
                                                  8'hf9,8'he9,8'he1,8'he5,8'he7,8'he6,8'h73,8'hac,8'h57,8'hbe,8'h5f,8'hba,8'h5d,8'hbb,8'hc8,8'h64,
                                                  8'he8,8'h74,8'h3a,8'h1d,8'h9b,8'hd8,8'h6c,8'h36,8'hb3,8'hcc,8'h66,8'h33,8'h8c,8'h46,8'h23,8'h84,
                                                  8'h41,8'hb5,8'hcf,8'hf2,8'h79,8'ha9,8'hc1,8'hf5,8'hbd,8'hcb,8'hf0,8'h78,8'h3c,8'h1e,8'h0f,8'h92,
                                                  8'h97,8'hde,8'h6f,8'ha2,8'h51,8'hbd,8'hcb,8'hf0,8'h15,8'h9f,8'hda,8'h6d,8'ha3,8'hc4,8'h62,8'h31,
                                                  8'h26,8'h13,8'h9c,8'h4e,8'h27,8'h86,8'h43,8'hb4,8'h0e,8'h07,8'h96,8'h4b,8'hb0,8'h58,8'h2c,8'h16,
                                                  8'hd1,8'hfd,8'heb,8'he0,8'h70,8'h38,8'h1c,8'h0e,8'h14,8'h0a,8'h05,8'h97,8'hde,8'h6f,8'ha2,8'h51,
                                                  8'h53,8'hbc,8'h5e,8'h2f,8'h82,8'h41,8'hb5,8'hcf,8'h6f,8'ha2,8'h51,8'hbd,8'hcb,8'hf0,8'h78,8'h3c,
                                                  8'he6,8'h73,8'hac,8'h56,8'h2b,8'h80,8'h40,8'h20,8'h0b,8'h90,8'h48,8'h24,8'h12,8'h09,8'h91,8'hdd,
                                                  8'h54,8'h2a,8'h15,8'h9f,8'hda,8'h6d,8'ha3,8'hc4,8'h7c,8'h3e,8'h1f,8'h9a,8'h4d,8'hb3,8'hcc,8'h66,
                                                  8'h52,8'h29,8'h81,8'hd5,8'hff,8'hea,8'h75,8'haf,8'h39,8'h89,8'hd1,8'hfd,8'heb,8'he0,8'h70,8'h38,
                                                  8'h7d,8'hab,8'hc0,8'h60,8'h30,8'h18,8'h0c,8'h06,8'hd6,8'h6b,8'ha0,8'h50,8'h28,8'h14,8'h0a,8'h05,
                                                  8'h48,8'h24,8'h12,8'h09,8'h91,8'hdd,8'hfb,8'he8,8'h1e,8'h0f,8'h92,8'h49,8'hb1,8'hcd,8'hf3,8'hec,
                                                  8'had,8'hc3,8'hf4,8'h7a,8'h3d,8'h8b,8'hd0,8'h68,8'hd7,8'hfe,8'h7f,8'haa,8'h55,8'hbf,8'hca,8'h65,
                                                  8'he9,8'he1,8'he5,8'he7,8'he6,8'h73,8'hac,8'h56,8'hc9,8'hf1,8'hed,8'he3,8'he4,8'h72,8'h39,8'h89,
                                                  8'h35,8'h8f,8'hd2,8'h69,8'ha1,8'hc5,8'hf7,8'hee,8'h5d,8'hbb,8'hc8,8'h64,8'h32,8'h19,8'h99,8'hd9,
                                                  8'h1e,8'h0f,8'h92,8'h49,8'hb1,8'hcd,8'hf3,8'hec,8'hc3,8'hf4,8'h7a,8'h3d,8'h8b,8'hd0,8'h68,8'h34,
                                                  8'hdd,8'hfb,8'he8,8'h74,8'h3a,8'h1d,8'h9b,8'hd8,8'h8b,8'hd0,8'h68,8'h34,8'h1a,8'h0d,8'h93,8'hdc,
                                                  8'hf5,8'hef,8'he2,8'h71,8'had,8'hc3,8'hf4,8'h7a,8'h60,8'h30,8'h18,8'h0c,8'h06,8'h03,8'h94,8'h4a,
                                                  8'h2b,8'h80,8'h40,8'h20,8'h10,8'h08,8'h04,8'h02,8'hf4,8'h7a,8'h3d,8'h8b,8'hd0,8'h68,8'h34,8'h1a,
                                                  8'h05,8'h97,8'hde,8'h6f,8'ha2,8'h51,8'hbd,8'hcb,8'h0e,8'h07,8'h96,8'h4b,8'hb0,8'h58,8'h2c,8'h16,
                                                  8'hfc,8'h7e,8'h3f,8'h8a,8'h45,8'hb7,8'hce,8'h67,8'hf5,8'hef,8'he2,8'h71,8'had,8'hc3,8'hf4,8'h7a,
                                                  8'ha2,8'h51,8'hbd,8'hcb,8'hf0,8'h78,8'h3c,8'h1e,8'h03,8'h94,8'h4a,8'h25,8'h87,8'hd6,8'h6b,8'ha0,
                                                  8'h28,8'h14,8'h0a,8'h05,8'h97,8'hde,8'h6f,8'ha2,8'h71,8'had,8'hc3,8'hf4,8'h7a,8'h3d,8'h8b,8'hd0,
                                                  8'h7a,8'h3d,8'h8b,8'hd0,8'h68,8'h34,8'h1a,8'h0d,8'h0f,8'h92,8'h49,8'hb1,8'hcd,8'hf3,8'hec,8'h76,
                                                  8'h7c,8'h3e,8'h1f,8'h9a,8'h4d,8'hb3,8'hcc,8'h66,8'h50,8'h28,8'h14,8'h0a,8'h05,8'h97,8'hde,8'h6f,
                                                  8'hcc,8'h66,8'h33,8'h8c,8'h46,8'h23,8'h84,8'h42,8'ha5,8'hc7,8'hf6,8'h7b,8'ha8,8'h54,8'h2a,8'h15,
                                                  8'hb7,8'hce,8'h67,8'ha6,8'h53,8'hbc,8'h5e,8'h2f,8'hae,8'h57,8'hbe,8'h5f,8'hba,8'h5d,8'hbb,8'hc8,
                                                  8'hcb,8'hf0,8'h78,8'h3c,8'h1e,8'h0f,8'h92,8'h49,8'h77,8'hae,8'h57,8'hbe,8'h5f,8'hba,8'h5d,8'hbb,
                                                  8'hf0,8'h78,8'h3c,8'h1e,8'h0f,8'h92,8'h49,8'hb1,8'h2f,8'h82,8'h41,8'hb5,8'hcf,8'hf2,8'h79,8'ha9,
                                                  8'h78,8'h3c,8'h1e,8'h0f,8'h92,8'h49,8'hb1,8'hcd,8'hb8,8'h5c,8'h2e,8'h17,8'h9e,8'h4f,8'hb2,8'h59,
                                                  8'h99,8'hd9,8'hf9,8'he9,8'he1,8'he5,8'he7,8'he6,8'h7f,8'haa,8'h55,8'hbf,8'hca,8'h65,8'ha7,8'hc6,
                                                  8'h77,8'hae,8'h57,8'hbe,8'h5f,8'hba,8'h5d,8'hbb,8'h87,8'hd6,8'h6b,8'ha0,8'h50,8'h28,8'h14,8'h0a,
                                                  8'h1b,8'h98,8'h4c,8'h26,8'h13,8'h9c,8'h4e,8'h27,8'hca,8'h65,8'ha7,8'hc6,8'h63,8'ha4,8'h52,8'h29,
                                                  8'hd2,8'h69,8'ha1,8'hc5,8'hf7,8'hee,8'h77,8'hae,8'hc9,8'hf1,8'hed,8'he3,8'he4,8'h72,8'h39,8'h89,
                                                  8'ha3,8'hc4,8'h62,8'h31,8'h8d,8'hd3,8'hfc,8'h7e,8'h62,8'h31,8'h8d,8'hd3,8'hfc,8'h7e,8'h3f,8'h8a,
                                                  8'hb2,8'h59,8'hb9,8'hc9,8'hf1,8'hed,8'he3,8'he4,8'h90,8'h48,8'h24,8'h12,8'h09,8'h91,8'hdd,8'hfb,
                                                  8'h48,8'h24,8'h12,8'h09,8'h91,8'hdd,8'hfb,8'he8,8'hf6,8'h7b,8'ha8,8'h54,8'h2a,8'h15,8'h9f,8'hda,
                                                  8'h22,8'h11,8'h9d,8'hdb,8'hf8,8'h7c,8'h3e,8'h1f,8'he0,8'h70,8'h38,8'h1c,8'h0e,8'h07,8'h96,8'h4b,
                                                  8'hc1,8'hf5,8'hef,8'he2,8'h71,8'had,8'hc3,8'hf4,8'h02,8'h01,8'h95,8'hdf,8'hfa,8'h7d,8'hab,8'hc0,
                                                  8'h80,8'h40,8'h20,8'h10,8'h08,8'h04,8'h02,8'h01,8'h33,8'h8c,8'h46,8'h23,8'h84,8'h42,8'h21,8'h85,
                                                  8'hc6,8'h63,8'ha4,8'h52,8'h29,8'h81,8'hd5,8'hff,8'h97,8'hde,8'h6f,8'ha2,8'h51,8'hbd,8'hcb,8'hf0,
                                                  8'h5d,8'hbb,8'hc8,8'h64,8'h32,8'h19,8'h99,8'hd9,8'h41,8'hb5,8'hcf,8'hf2,8'h79,8'ha9,8'hc1,8'hf5,
                                                  8'had,8'hc3,8'hf4,8'h7a,8'h3d,8'h8b,8'hd0,8'h68,8'h6c,8'h36,8'h1b,8'h98,8'h4c,8'h26,8'h13,8'h9c,
                                                  8'hb0,8'h58,8'h2c,8'h16,8'h0b,8'h90,8'h48,8'h24,8'h85,8'hd7,8'hfe,8'h7f,8'haa,8'h55,8'hbf,8'hca,
                                                  8'hcd,8'hf3,8'hec,8'h76,8'h3b,8'h88,8'h44,8'h22,8'h68,8'h34,8'h1a,8'h0d,8'h93,8'hdc,8'h6e,8'h37,
                                                  8'h48,8'h24,8'h12,8'h09,8'h91,8'hdd,8'hfb,8'he8,8'h74,8'h3a,8'h1d,8'h9b,8'hd8,8'h6c,8'h36,8'h1b,
                                                  8'hfe,8'h7f,8'haa,8'h55,8'hbf,8'hca,8'h65,8'ha7,8'hff,8'hea,8'h75,8'haf,8'hc2,8'h61,8'ha5,8'hc7,
                                                  8'h60,8'h30,8'h18,8'h0c,8'h06,8'h03,8'h94,8'h4a,8'h55,8'hbf,8'hca,8'h65,8'ha7,8'hc6,8'h63,8'ha4,
                                                  8'h47,8'hb6,8'h5b,8'hb8,8'h5c,8'h2e,8'h17,8'h9e,8'hc1,8'hf5,8'hef,8'he2,8'h71,8'had,8'hc3,8'hf4,
                                                  8'h0c,8'h06,8'h03,8'h94,8'h4a,8'h25,8'h87,8'hd6,8'hbe,8'h5f,8'hba,8'h5d,8'hbb,8'hc8,8'h64,8'h32,
                                                  8'h18,8'h0c,8'h06,8'h03,8'h94,8'h4a,8'h25,8'h87,8'h63,8'ha4,8'h52,8'h29,8'h81,8'hd5,8'hff,8'hea,
                                                  8'hc4,8'h62,8'h31,8'h8d,8'hd3,8'hfc,8'h7e,8'h3f,8'hdd,8'hfb,8'he8,8'h74,8'h3a,8'h1d,8'h9b,8'hd8,
                                                  8'hcb,8'hf0,8'h78,8'h3c,8'h1e,8'h0f,8'h92,8'h49,8'hdf,8'hfa,8'h7d,8'hab,8'hc0,8'h60,8'h30,8'h18,
                                                  8'h1e,8'h0f,8'h92,8'h49,8'hb1,8'hcd,8'hf3,8'hec,8'h20,8'h10,8'h08,8'h04,8'h02,8'h01,8'h95,8'hdf,
                                                  8'hd7,8'hfe,8'h7f,8'haa,8'h55,8'hbf,8'hca,8'h65,8'ha8,8'h54,8'h2a,8'h15,8'h9f,8'hda,8'h6d,8'ha3,
                                                  8'h06,8'h03,8'h94,8'h4a,8'h25,8'h87,8'hd6,8'h6b,8'h07,8'h96,8'h4b,8'hb0,8'h58,8'h2c,8'h16,8'h0b};
  
  // -----------------------------------------------------------------------------
  // Logic Declarations
  // -----------------------------------------------------------------------------
  typedef logic [7:0] interleave_data_t [P_N_SYMBOLS - 1 : 0];

  // Replay Command
  typedef enum logic [1:0] {
    REPLAY_00 = 2'b00,
    ACK       = 2'b01,
    NAK_10    = 2'b10,
    NAK_11    = 2'b11
  } replay_cmd_t;

  // FM Retry Struct
  typedef struct packed {
    replay_cmd_t  cmd;     // Replay Command
    logic [9:0]   seqnum;  // Sequence Number
  } fm_retry_t;

  // RPLH to XPLH Flit Mode Retry Interface
  typedef struct packed {
    logic      valid;             // When enabled this stuct contains valid data
    fm_retry_t requested;         // Requested replay command
    fm_retry_t received;          // Received  replay command
    logic      rcvd_expl_seq_num; // Non-IDLE Explicit Sequence Number Flit has been received since the last entry to IDLE Flit Handshake Phase
  } rplh_xplh_fm_retry_t;

  // RX Retr Buffer Command
  typedef enum logic [1 : 0] {
    E_IDLE    = 2'b00,
    E_STORE   = 2'b01,
    E_PROCESS = 2'b10,
    E_PURGE   = 2'b11
  } rx_rbuf_cmd_e;

  // Link Management DLLP Type Encoding
  typedef enum logic [7 : 0] {
    L0P = 8'b00000000
  } link_mng_type_e;

  // L0P Command Encoding
  typedef enum logic [3 : 0] {
    L0P_Request             = 4'b0100,
    L0P_Request_Ack         = 4'b0110,
    L0P_Request_Nak         = 4'b0111
  } l0p_cmd_e;

  // L0P DLLP Struct
  typedef struct packed {
    logic [3:0]     resp_pyld;      // L0P Response Payload
    logic [3:0]     link_width;     // Link Width
    logic [2:0]     rsvd;           // Reserved bits
    logic           priority_bit;   // L0P Priority Request
    l0p_cmd_e       l0p_cmd;        // L0P Command
    link_mng_type_e link_mng_type;  // Link Management DLLP Type
    dllp_type_e     dllp_type;      // DLLP Type
    logic           valid;          // L0P DLLP Valid Indication
  } l0p_dllp_struct;

  // L0P DLLP Acknowledge Struct
  typedef struct packed {
    l0p_cmd_e       l0p_cmd;        // L0P Command
    logic           ack;            // L0P Acknowledge
  } l0p_ack_struct;

  // Flit Mode DLLP Struct
  typedef struct packed {
    logic [23:0]    pyld;           // DLLP Payload
    dllp_type_e     dllp_type;      // DLLP Type
    logic           opt_upd_fc;     // Set to 1 to indicate an optimized update FC DLLP
  } fm_dllp_struct;

    typedef enum logic {
      NOP      = 1'b0,
      PYLD     = 1'b1
    } flit_type_enum;

    typedef struct packed {
      logic           err_inj_en;   // Indicates TX flit error injection enable
      flit_type_enum  flit_type;    // Indicates this flit type
    } flit_type_struct;

  // Transmitter Flit Structure 
  typedef struct packed {
    logic                 sof;         // Start of Flit
    logic [1 : 0]         eof;         // End of Flit
    logic                 enf;         // End NOP Flit
    logic                 data_valid;  // Data valid indication
    logic [P_DW - 1 : 0]  data;        // Flit Data
    logic                 retry_flit;  // Indicates this flit is a retry flit
    logic                 expl_flit;   // Indicates this flit should be an explicit sequence number flit
    logic                 tlp_dv;      // TLP data contained in the Flit
      flit_type_struct    flit_type_s; // Indicates TX flit error injection enable and this flit type
      logic [DATA_PAR_WD-1:0]  flit_prot; 
      logic                    ras_dp_err_inband_kbd;
  } tx_flit_struct;

  // ACK/NAK Command Struct
  typedef struct packed {
    logic [P_TX_SEQNUM_WD - 1 : 0]  ackd_seqnum;        // Latests acknowledged Sequence Number
    logic [P_TX_SEQNUM_WD - 1 : 0]  seqnum;             // ACK/NAK Sequence Number
    logic                           nak_for_nop;        // NAK for NOP Flit
    logic                           second_nak_for_nop; // Second Consecutive NAK for NOP Flit
    replay_cmd_t                    replay_cmd;         // ACK/NAK Replay Command
  } ack_nak_struct;

  // Retry Request Struct
  typedef struct packed {
    logic [P_TX_SEQNUM_WD - 1 : 0]  seqnum;             // Sequence Number for the first Replayed Flit 
    logic                           nak_for_nop;        // Request to retry a NOP Flit
    replay_cmd_t                    replay_cmd;         // ACK/NAK Replay Command
    logic                           replay_scheduled;   // Replay Scheduled Indication
  } retry_req_struct;

  // TLP status struct used in rplh_fm_pkt_finder and submodules
  typedef struct packed {
    logic        pending; // TLP in progress
    logic [4:0]  eot_flt; // Number of Flits left in order to reach the end of the TLP
    logic [2:0]  eot_dec; // Number of 256b Decoder instances left in order to reach the end of the TLP
    logic [7:0]  eot_pos; // Position of the eot within the final 256b Decoder 
  } tlp_state_t;

  // Retry Buffer Payload Flit Tracker used to de-allocate space in the retry buffer
  typedef struct packed {
    logic [P_TX_SEQNUM_WD - 1 : 0]  count;        // Number of payload flits sent since the last ACK/NAK
    logic                           valid;        // Payload count valid flag
  } payload_cnt_struct;

  typedef enum logic {
    TX_NOP = 1'b0,
    TX_PAYLOAD = 1'b1
  } nop_flag_e;

`ifndef SYNTHESIS
  typedef enum logic {
    NOP_OR_IDLE = 1'b0,
    PAYLOAD = 1'b1
  } flit_type_e;

  typedef enum logic {
    DLLP = 1'b0,
    OPT_UPD_OR_FM = 1'b1
  } dllp_pyld_e;

  typedef struct packed {
    logic [58:0][31:0]  tlpBytes;
    logic [1:0]         flitUsage;
    flit_type_e         priorPyld;
    dllp_pyld_e         dllpPyldType;
    replay_cmd_t        replayCmd;
    logic [9:0]         seqNum;
    dllp_type_e         dllpType;
    logic [23:0]        dllpPyld;
    logic               opt_upd_fc;
    logic               flit_marker;
    logic [(8*8)-1:0]   crcBytes;
    logic [(6*8)-1:0]   fecBytes;
    logic               sof;
    logic [1:0]         eof;
    logic               enf;
    logic               retry_flit;
  } flit_struct;
`endif // !SYNTHESIS


  // Even and Odd correctable errors Struct
  typedef struct packed {
  logic [15 : 0][2 : 0] fec_dec_even_b_err;    // FEC Even corrected bit errors in FEC
  logic [15 : 0][2 : 0] fec_dec_odd_b_err;    // FEC Odd corrected bit errors in FEC
  } even_odd_c_errs;
  

  function automatic even_odd_c_errs interleave_errors (
    input [2 : 0]  even_b_err,
    input [2 : 0]  odd_b_err,
    input [5 : 0]  link_width,
    input [6 : 0]  fec_dec_synd_check,
    input [1 : 0]  ecc_group_index
  );
    begin
       interleave_errors.fec_dec_even_b_err [15:0] = 'b0;
       interleave_errors.fec_dec_odd_b_err [15:0] = 'b0;
       if ((fec_dec_synd_check < 7'd83) || (fec_dec_synd_check == 7'd83 && ecc_group_index == 'b0)) begin
          unique case (link_width)
          6'b000001: begin
                     interleave_errors.fec_dec_even_b_err [0] = even_b_err;
                     interleave_errors.fec_dec_odd_b_err [0] = odd_b_err;
          end
          6'b000010: begin
                     if ((~fec_dec_synd_check[0] && ~ecc_group_index[0]) || (fec_dec_synd_check[0] && ecc_group_index[0])) begin
                     interleave_errors.fec_dec_even_b_err [0] = even_b_err;
                     interleave_errors.fec_dec_odd_b_err [0] = odd_b_err;
                     end else if ((fec_dec_synd_check[0] && ~ecc_group_index[0]) || (~fec_dec_synd_check[0] && ecc_group_index[0])) begin 
                     interleave_errors.fec_dec_even_b_err [1] = even_b_err;
                     interleave_errors.fec_dec_odd_b_err [1] = odd_b_err;
                     end
          end
          6'b000100: begin
                     if ((fec_dec_synd_check[1:0] == 2'b00 && ecc_group_index == 2'b00) || (fec_dec_synd_check[1:0] == 2'b01 && ecc_group_index == 2'b01) || (fec_dec_synd_check[1:0] == 2'b10 && ecc_group_index == 2'b10)) begin
                     interleave_errors.fec_dec_even_b_err [0] = even_b_err;
                     interleave_errors.fec_dec_odd_b_err [0] = odd_b_err;
                     end else if ((fec_dec_synd_check[1:0] == 2'b11 && ecc_group_index == 2'b00) || (fec_dec_synd_check[1:0] == 2'b00 && ecc_group_index == 2'b01) || (fec_dec_synd_check[1:0] == 2'b01 && ecc_group_index == 2'b10)) begin
                     interleave_errors.fec_dec_even_b_err [1] = even_b_err;
                     interleave_errors.fec_dec_odd_b_err [1] = odd_b_err;
                     end else if ((fec_dec_synd_check[1:0] == 2'b10 && ecc_group_index == 2'b00) || (fec_dec_synd_check[1:0] == 2'b11 && ecc_group_index == 2'b01) || (fec_dec_synd_check[1:0] == 2'b00 && ecc_group_index == 2'b10)) begin
                     interleave_errors.fec_dec_even_b_err [2] = even_b_err;
                     interleave_errors.fec_dec_odd_b_err [2] = odd_b_err;
                     end else if ((fec_dec_synd_check[1:0] == 2'b01 && ecc_group_index == 2'b00) || (fec_dec_synd_check[1:0] == 2'b10 && ecc_group_index == 2'b01) || (fec_dec_synd_check[1:0] == 2'b11 && ecc_group_index == 2'b10)) begin
                     interleave_errors.fec_dec_even_b_err [3] = even_b_err;
                     interleave_errors.fec_dec_odd_b_err [3] = odd_b_err;
                     end
          end
          6'b001000: begin
                     if ((fec_dec_synd_check[2:0] == 3'b000 && ecc_group_index == 2'b00) || (fec_dec_synd_check[2:0] == 3'b101 && ecc_group_index == 2'b01) || (fec_dec_synd_check[2:0] == 3'b010 && ecc_group_index == 2'b10)) begin
                     interleave_errors.fec_dec_even_b_err [0] = even_b_err;
                     interleave_errors.fec_dec_odd_b_err [0] = odd_b_err;
                     end else if ((fec_dec_synd_check[2:0] == 3'b011 && ecc_group_index == 2'b00) || (fec_dec_synd_check[2:0] == 3'b000 && ecc_group_index == 2'b01) || (fec_dec_synd_check[2:0] == 3'b101 && ecc_group_index == 2'b10)) begin
                     interleave_errors.fec_dec_even_b_err [1] = even_b_err;
                     interleave_errors.fec_dec_odd_b_err [1] = odd_b_err;
                     end else if ((fec_dec_synd_check[2:0] == 3'b110 && ecc_group_index == 2'b00) || (fec_dec_synd_check[2:0] == 3'b011 && ecc_group_index == 2'b01) || (fec_dec_synd_check[2:0] == 3'b000 && ecc_group_index == 2'b10)) begin
                     interleave_errors.fec_dec_even_b_err [2] = even_b_err;
                     interleave_errors.fec_dec_odd_b_err [2] = odd_b_err;
                     end else if ((fec_dec_synd_check[2:0] == 3'b001 && ecc_group_index == 2'b00) || (fec_dec_synd_check[2:0] == 3'b110 && ecc_group_index == 2'b01) || (fec_dec_synd_check[2:0] == 3'b011 && ecc_group_index == 2'b10)) begin
                     interleave_errors.fec_dec_even_b_err [3] = even_b_err;
                     interleave_errors.fec_dec_odd_b_err [3] = odd_b_err;
                     end else if ((fec_dec_synd_check[2:0] == 3'b100 && ecc_group_index == 2'b00) || (fec_dec_synd_check[2:0] == 3'b001 && ecc_group_index == 2'b01) || (fec_dec_synd_check[2:0] == 3'b110 && ecc_group_index == 2'b10)) begin
                     interleave_errors.fec_dec_even_b_err [4] = even_b_err;
                     interleave_errors.fec_dec_odd_b_err [4] = odd_b_err;
                     end else if ((fec_dec_synd_check[2:0] == 3'b111 && ecc_group_index == 2'b00) || (fec_dec_synd_check[2:0] == 3'b100 && ecc_group_index == 2'b01) || (fec_dec_synd_check[2:0] == 3'b001 && ecc_group_index == 2'b10)) begin
                     interleave_errors.fec_dec_even_b_err [5] = even_b_err;
                     interleave_errors.fec_dec_odd_b_err [5] = odd_b_err;
                     end else if ((fec_dec_synd_check[2:0] == 3'b010 && ecc_group_index == 2'b00) || (fec_dec_synd_check[2:0] == 3'b111 && ecc_group_index == 2'b01) || (fec_dec_synd_check[2:0] == 3'b100 && ecc_group_index == 2'b10)) begin
                     interleave_errors.fec_dec_even_b_err [6] = even_b_err;
                     interleave_errors.fec_dec_odd_b_err [6] = odd_b_err;
                     end else if ((fec_dec_synd_check[2:0] == 3'b101 && ecc_group_index == 2'b00) || (fec_dec_synd_check[2:0] == 3'b010 && ecc_group_index == 2'b01) || (fec_dec_synd_check[2:0] == 3'b111 && ecc_group_index == 2'b10)) begin
                     interleave_errors.fec_dec_even_b_err [7] = even_b_err;
                     interleave_errors.fec_dec_odd_b_err [7] = odd_b_err;
                     end
          end
          6'b010000: begin
                     if ((fec_dec_synd_check[3:0] == 4'b0000 && ecc_group_index == 2'b00) || (fec_dec_synd_check[3:0] == 4'b0101 && ecc_group_index == 2'b01) || (fec_dec_synd_check[3:0] == 4'b1010 && ecc_group_index == 2'b10)) begin
                     interleave_errors.fec_dec_even_b_err [0] = even_b_err;
                     interleave_errors.fec_dec_odd_b_err [0] = odd_b_err;
                     end else if ((fec_dec_synd_check[3:0] == 4'b1011 && ecc_group_index == 2'b00) || (fec_dec_synd_check[3:0] == 4'b0000 && ecc_group_index == 2'b01) || (fec_dec_synd_check[3:0] == 4'b0101 && ecc_group_index == 2'b10)) begin
                     interleave_errors.fec_dec_even_b_err [1] = even_b_err;
                     interleave_errors.fec_dec_odd_b_err [1] = odd_b_err;
                     end else if ((fec_dec_synd_check[3:0] == 4'b0110 && ecc_group_index == 2'b00) || (fec_dec_synd_check[3:0] == 4'b1011 && ecc_group_index == 2'b01) || (fec_dec_synd_check[3:0] == 4'b0000 && ecc_group_index == 2'b10)) begin
                     interleave_errors.fec_dec_even_b_err [2] = even_b_err;
                     interleave_errors.fec_dec_odd_b_err [2] = odd_b_err;
                     end else if ((fec_dec_synd_check[3:0] == 4'b0001 && ecc_group_index == 2'b00) || (fec_dec_synd_check[3:0] == 4'b0110 && ecc_group_index == 2'b01) || (fec_dec_synd_check[3:0] == 4'b1011 && ecc_group_index == 2'b10)) begin
                     interleave_errors.fec_dec_even_b_err [3] = even_b_err;
                     interleave_errors.fec_dec_odd_b_err [3] = odd_b_err;
                     end else if ((fec_dec_synd_check[3:0] == 4'b1100 && ecc_group_index == 2'b00) || (fec_dec_synd_check[3:0] == 4'b0001 && ecc_group_index == 2'b01) || (fec_dec_synd_check[3:0] == 4'b0110 && ecc_group_index == 2'b10)) begin
                     interleave_errors.fec_dec_even_b_err [4] = even_b_err;
                     interleave_errors.fec_dec_odd_b_err [4] = odd_b_err;
                     end else if ((fec_dec_synd_check[3:0] == 4'b0111 && ecc_group_index == 2'b00) || (fec_dec_synd_check[3:0] == 4'b1100 && ecc_group_index == 2'b01) || (fec_dec_synd_check[3:0] == 4'b0001 && ecc_group_index == 2'b10)) begin
                     interleave_errors.fec_dec_even_b_err [5] = even_b_err;
                     interleave_errors.fec_dec_odd_b_err [5] = odd_b_err;
                     end else if ((fec_dec_synd_check[3:0] == 4'b0010 && ecc_group_index == 2'b00) || (fec_dec_synd_check[3:0] == 4'b0111 && ecc_group_index == 2'b01) || (fec_dec_synd_check[3:0] == 4'b1100 && ecc_group_index == 2'b10)) begin
                     interleave_errors.fec_dec_even_b_err [6] = even_b_err;
                     interleave_errors.fec_dec_odd_b_err [6] = odd_b_err;
                     end else if ((fec_dec_synd_check[3:0] == 4'b1101 && ecc_group_index == 2'b00) || (fec_dec_synd_check[3:0] == 4'b0010 && ecc_group_index == 2'b01) || (fec_dec_synd_check[3:0] == 4'b0111 && ecc_group_index == 2'b10)) begin
                     interleave_errors.fec_dec_even_b_err [7] = even_b_err;
                     interleave_errors.fec_dec_odd_b_err [7] = odd_b_err;
                     end else if ((fec_dec_synd_check[3:0] == 4'b1000 && ecc_group_index == 2'b00) || (fec_dec_synd_check[3:0] == 4'b1101 && ecc_group_index == 2'b01) || (fec_dec_synd_check[3:0] == 4'b0010 && ecc_group_index == 2'b10)) begin
                     interleave_errors.fec_dec_even_b_err [8] = even_b_err;
                     interleave_errors.fec_dec_odd_b_err [8] = odd_b_err;
                     end else if ((fec_dec_synd_check[3:0] == 4'b0011 && ecc_group_index == 2'b00) || (fec_dec_synd_check[3:0] == 4'b1000 && ecc_group_index == 2'b01) || (fec_dec_synd_check[3:0] == 4'b1101 && ecc_group_index == 2'b10)) begin
                     interleave_errors.fec_dec_even_b_err [9] = even_b_err;
                     interleave_errors.fec_dec_odd_b_err [9] = odd_b_err;
                     end else if ((fec_dec_synd_check[3:0] == 4'b1110 && ecc_group_index == 2'b00) || (fec_dec_synd_check[3:0] == 4'b0011 && ecc_group_index == 2'b01) || (fec_dec_synd_check[3:0] == 4'b1000 && ecc_group_index == 2'b10)) begin
                     interleave_errors.fec_dec_even_b_err [10] = even_b_err;
                     interleave_errors.fec_dec_odd_b_err [10] = odd_b_err;
                     end else if ((fec_dec_synd_check[3:0] == 4'b1001 && ecc_group_index == 2'b00) || (fec_dec_synd_check[3:0] == 4'b1110 && ecc_group_index == 2'b01) || (fec_dec_synd_check[3:0] == 4'b0011 && ecc_group_index == 2'b10)) begin
                     interleave_errors.fec_dec_even_b_err [11] = even_b_err;
                     interleave_errors.fec_dec_odd_b_err [11] = odd_b_err;
                     end else if ((fec_dec_synd_check[3:0] == 4'b0100 && ecc_group_index == 2'b00) || (fec_dec_synd_check[3:0] == 4'b1001 && ecc_group_index == 2'b01) || (fec_dec_synd_check[3:0] == 4'b1110 && ecc_group_index == 2'b10)) begin
                     interleave_errors.fec_dec_even_b_err [12] = even_b_err;
                     interleave_errors.fec_dec_odd_b_err [12] = odd_b_err;
                     end else if ((fec_dec_synd_check[3:0] == 4'b1111&& ecc_group_index == 2'b00) || (fec_dec_synd_check[3:0] == 4'b0100 && ecc_group_index == 2'b01) || (fec_dec_synd_check[3:0] == 4'b1001 && ecc_group_index == 2'b10)) begin
                     interleave_errors.fec_dec_even_b_err [13] = even_b_err;
                     interleave_errors.fec_dec_odd_b_err [13] = odd_b_err;
                     end else if ((fec_dec_synd_check[3:0] == 4'b1010 && ecc_group_index == 2'b00) || (fec_dec_synd_check[3:0] == 4'b1111 && ecc_group_index == 2'b01) || (fec_dec_synd_check[3:0] == 4'b0100 && ecc_group_index == 2'b10)) begin
                     interleave_errors.fec_dec_even_b_err [14] = even_b_err;
                     interleave_errors.fec_dec_odd_b_err [14] = odd_b_err;
                     end else if ((fec_dec_synd_check[3:0] == 4'b0101 && ecc_group_index == 2'b00) || (fec_dec_synd_check[3:0] == 4'b1010 && ecc_group_index == 2'b01) || (fec_dec_synd_check[3:0] == 4'b1111 && ecc_group_index == 2'b10)) begin
                     interleave_errors.fec_dec_even_b_err [15] = even_b_err;
                     interleave_errors.fec_dec_odd_b_err [15] = odd_b_err;
                     end
          end
          default : begin
                     interleave_errors.fec_dec_even_b_err [15:0] = 'b0;
                     interleave_errors.fec_dec_odd_b_err [15:0] = 'b0;
          end
          endcase
      end
    end

  return interleave_errors;
  endfunction

  // -----------------------------------------------------------------------------
  // Functions
  // -----------------------------------------------------------------------------
  // Function Name  : interleave_data 
  // Description    : This function takes flit wider data vector as input.
  //                  The function generates an array of Bytes as output using the start index to step over the
  //                  input data vector in steps of 3 bytes.
  // Inputs         : data_in <logic> data vector
  //                  start_index <int> which byte to start interleaving
  // Outputs        : interleave_data <array of logic> array of bytes to input to the FEC
  function automatic interleave_data_t interleave_data (
    input [P_FLIT_WD - 1 : 0]  data_in,
    input int           start_index
  );
    begin
      for(int i = 0; i < P_N_SYMBOLS; i = i + 1) begin
        if((i == 83) && (start_index > 0))
          interleave_data[i] = 8'h00;
        else
          interleave_data[i] = data_in[(8 * (start_index + (3*i))) +: 8];
      end
    end
    return interleave_data;
  endfunction

  // Function Name  : x_minus_y_mod_1023 
  // Description    : This function returns (x-y)%1023
  // Inputs         : x <logic> 10-bit number
  //                  y <logic> 10-bit number
  // Outputs        : <logic> 10-bit wide number representing x-y modulo 1023
  function automatic [9:0] x_minus_y_mod_1023 (
    input [9:0] x, 
    input [9:0] y
  );
    return (x==10'd1023 && y==10'd0)? 0     :
                            (x >= y)? x - y : 
// spyglass disable_block W416
// SMD: Reports functions in which the range of the return type and return value of a function are not same
// SJ: Because of x and y are 10-bits wide and y>x, the result is a positive number 10-bits wide
                                      10'd1023 - y + x;
// spyglass enable_block W416
  endfunction

  function automatic bit dlp_is_vcx_init_fc(
    input dllp_type_e dllpType, // DLLP Type
    input int         vc        // Virtual Channel Number
  );
    begin
      dlp_is_vcx_init_fc = '0;
      if(vc == 0) begin
        dlp_is_vcx_init_fc = dllpType inside {
          INITFC1_P_VC0,
          INITFC1_NP_VC0,
          INITFC1_CPL_VC0,
          INITFC2_P_VC0,
          INITFC2_NP_VC0,
          INITFC2_CPL_VC0,
          DED_INITFC1_P_VC0,
          DED_INITFC1_NP_VC0,
          DED_INITFC1_CPL_VC0,
          DED_INITFC2_P_VC0,
          DED_INITFC2_NP_VC0,
          DED_INITFC2_CPL_VC0
        };
      end
      if(vc == 1) begin
        dlp_is_vcx_init_fc = dllpType inside {
          INITFC1_P_VC1,
          INITFC1_NP_VC1,
          INITFC1_CPL_VC1,
          INITFC2_P_VC1,
          INITFC2_NP_VC1,
          INITFC2_CPL_VC1,
          DED_INITFC1_P_VC1,
          DED_INITFC1_NP_VC1,
          DED_INITFC1_CPL_VC1,
          DED_INITFC2_P_VC1,
          DED_INITFC2_NP_VC1,
          DED_INITFC2_CPL_VC1
        };
      end
      if(vc == 2) begin
        dlp_is_vcx_init_fc = dllpType inside {
          INITFC1_P_VC2,
          INITFC1_NP_VC2,
          INITFC1_CPL_VC2,
          INITFC2_P_VC2,
          INITFC2_NP_VC2,
          INITFC2_CPL_VC2,
          DED_INITFC1_P_VC2,
          DED_INITFC1_NP_VC2,
          DED_INITFC1_CPL_VC2,
          DED_INITFC2_P_VC2,
          DED_INITFC2_NP_VC2,
          DED_INITFC2_CPL_VC2
        };
      end
      if(vc == 3) begin
        dlp_is_vcx_init_fc = dllpType inside {
          INITFC1_P_VC3,
          INITFC1_NP_VC3,
          INITFC1_CPL_VC3,
          INITFC2_P_VC3,
          INITFC2_NP_VC3,
          INITFC2_CPL_VC3,
          DED_INITFC1_P_VC3,
          DED_INITFC1_NP_VC3,
          DED_INITFC1_CPL_VC3,
          DED_INITFC2_P_VC3,
          DED_INITFC2_NP_VC3,
          DED_INITFC2_CPL_VC3
        };
      end
      if(vc == 4) begin
        dlp_is_vcx_init_fc = dllpType inside {
          INITFC1_P_VC4,
          INITFC1_NP_VC4,
          INITFC1_CPL_VC4,
          INITFC2_P_VC4,
          INITFC2_NP_VC4,
          INITFC2_CPL_VC4,
          DED_INITFC1_P_VC4,
          DED_INITFC1_NP_VC4,
          DED_INITFC1_CPL_VC4,
          DED_INITFC2_P_VC4,
          DED_INITFC2_NP_VC4,
          DED_INITFC2_CPL_VC4
        };
      end
      if(vc == 5) begin
        dlp_is_vcx_init_fc = dllpType inside {
          INITFC1_P_VC5,
          INITFC1_NP_VC5,
          INITFC1_CPL_VC5,
          INITFC2_P_VC5,
          INITFC2_NP_VC5,
          INITFC2_CPL_VC5,
          DED_INITFC1_P_VC5,
          DED_INITFC1_NP_VC5,
          DED_INITFC1_CPL_VC5,
          DED_INITFC2_P_VC5,
          DED_INITFC2_NP_VC5,
          DED_INITFC2_CPL_VC5
        };
      end
      if(vc == 6) begin
        dlp_is_vcx_init_fc = dllpType inside {
          INITFC1_P_VC6,
          INITFC1_NP_VC6,
          INITFC1_CPL_VC6,
          INITFC2_P_VC6,
          INITFC2_NP_VC6,
          INITFC2_CPL_VC6,
          DED_INITFC1_P_VC6,
          DED_INITFC1_NP_VC6,
          DED_INITFC1_CPL_VC6,
          DED_INITFC2_P_VC6,
          DED_INITFC2_NP_VC6,
          DED_INITFC2_CPL_VC6
        };
      end
      if(vc == 7) begin
        dlp_is_vcx_init_fc = dllpType inside {
          INITFC1_P_VC7,
          INITFC1_NP_VC7,
          INITFC1_CPL_VC7,
          INITFC2_P_VC7,
          INITFC2_NP_VC7,
          INITFC2_CPL_VC7,
          DED_INITFC1_P_VC7,
          DED_INITFC1_NP_VC7,
          DED_INITFC1_CPL_VC7,
          DED_INITFC2_P_VC7,
          DED_INITFC2_NP_VC7,
          DED_INITFC2_CPL_VC7
        };
      end
    end
    return dlp_is_vcx_init_fc;
  endfunction


endpackage // cx_pl_pkg

`endif // __GUARD__CX_PL_PKG__SVH__
