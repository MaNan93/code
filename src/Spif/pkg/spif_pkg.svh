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
// ---   $Id: //dwh/pcie_iip/main/fairbanks/design/Spif/pkg/spif_pkg.svh#2 $
// -----------------------------------------------------------------------------

`ifndef __GUARD__SPIF_PKG__SVH__
`define __GUARD__SPIF_PKG__SVH__

// -----------------------------------------------------------------------------
// --- Package Description:  SPIF Interface General Package
// -----------------------------------------------------------------------------
package spif_pkg;

  // Number of valid bits on interface from Link Layer to Packet Layer
  localparam SPIF_LP_NVLD = `CX_SPIF_LP_NVLD ;
  // Number of valid bits on interface from Packet Layer to Link Layer
  localparam SPIF_PL_NVLD = `CX_SPIF_PL_NVLD ;
  // Number of bytes determined by the data width for the SPIF interface
  localparam SPIF_NBYTES  = `CX_SPIF_NBYTES ;
  // Number of bits determined by the data protection width for the SPIF interface
  localparam SPIF_NDPBITS = `CX_SPIF_NDPBITS ;
  // Number of CRC bytes for CXL FLIT on the SPIF interface
  localparam SPIF_NCRC    = `CX_SPIF_NCRC ;
  // Number of DWords determined by the data width for the SPIF interface
  localparam SPIF_NWORDS  = `CX_SPIF_NWORDS ;
  // Number of DLLP bytes on the interface
  localparam SPIF_NDLLP   = `CX_SPIF_NDLLP ;
  // Number of bits determined by the data width for the SPIF Configuration Interface
  localparam SPIF_NCFG    = `CX_SPIF_NCFG  ;
  //Number of credits advertised by SPIF Configuration Interface Completer
  localparam SPIF_CFG_CRD = `CX_SPIF_CPL_CRD ;


  // Packet Layer indication to upper layers about which the protocol negotiated during initial link training.
  typedef enum logic [2:0] {
    PCIE_MODE = 3'b000, // PCIe
    STREAMING = 3'b001, // Streaming Protocol
    RSVD_010  = 3'b010, // Reserved
    CXL_MODE1 = 3'b011, // CXL.1 [Single protocol, i.e. CXL.io]
    CXL_MODE2 = 3'b100, // CXL.2 [Multi-protocol, Type 1 device]
    CXL_MODE3 = 3'b101, // CXL.3 [Multi-protocol, Type 2 device]
    CXL_MODE4 = 3'b110, // CXL.4 [Multi-protocol, Type 3 SLD device]
    CXL_MODE5 = 3'b111  // CXL.5 [Multi-protocol, Type 3 MLD device]
  } protocol_type_e;

  // Packet Layer indication to upper layers about the flit format negotiated during initial link training
  typedef enum logic [3:0] {
    FMT_NONE_FLIT = 4'b0000, // 0000b - PCIe Non-Flit Mode
    FMT_CXL_68B   = 4'b0001, // 0001b - Format 1 : CXL 68B Flit Mode without Virtual Hierarchy support (CXL1.1)
    FMT_CXL_68BVH = 4'b0010, // 0010b - Format 2 : CXL 68B Flit Mode with Virtual Hierarchy support (CXL2.0)
    FMT_PCIE_FLIT = 4'b0011, // 0011b - Format 3 : PCIe 256B Flit Mode
    FMT_CXL_256B  = 4'b0100, // 0100b - Format 4 : CXL 256B Standard Flit Mode (HBR)
    FMT_CXL_PBR   = 4'b0101, // 0101b - Format 5 : CXL 256B Standard Flit Mode (PBR)
    FMT_CXL_LOPT  = 4'b0110  // 0110b - Format 6 : CXL 256B Latency Optimized Mode
    // Other encodings are Reserved
  } protocol_fmt_e;

  // Link Layer to Packet Layer signal that indicates the Stream ID to use with
  // data. Each Stream ID maps to a unique protocol and stack.
  typedef enum logic [7:0] {
    SID_RSVD   = 8'b0000_0000, // Reserved
    SID_PCIE   = 8'b0000_0001, // PCIe 
    SID_CXL_IO = 8'b0000_0010, // CXL.io
    SID_CXL_CM = 8'b0000_0011, // CXL.cachemem
    SID_STREAM = 8'b0000_0100, // Streaming protocol (Not supported)
    SID_ALMP   = 8'b1111_1111  // ALMP (ARB/MUX Link Management Packets)
  } stream_id_e;

  // SPIF State Encodings
  typedef enum logic [3:0] {
    RESET            = 4'b0000, // Reset for State Status / NOP for State Request
    ACTIVE           = 4'b0001, // Active
    ACTIVE_L0S_PMNAK = 4'b0010, // Active.L0s for PCIe mode / Active.PMNAK for CXL mode
    DAPM             = 4'b0011, // Deepest Allowable PM State (L1 substates only)
    IDLE_L1_1        = 4'b0100, // L1.1
    IDLE_L1_2        = 4'b0101, // L1.2
    IDLE_L1_3        = 4'b0110, // L1.3
    IDLE_L1_4        = 4'b0111, // L1.4
    L2               = 4'b1000, // L2
    LINKRESET        = 4'b1001, // LinkReset
    LINKERROR        = 4'b1010, // LinkError
    RETRAIN          = 4'b1011, // Retrain
    DISABLED         = 4'b1100  // Disable
    // Other encodings are Reserved
  } state_enc_e;

  typedef struct {
    logic spif_enable        ; // SPIF Enable for the selected protocol configuration
    logic pcie_mode_enable   ; // PCIe protocol is enabled
    logic cxl_mode_enable    ; // CXL.io (CXL) protocol is enabled
    logic cxl_mem_enable     ; // CXL.mem protocol is enabled
    logic cxl_cache_enable   ; // CXL.cache protocol is enabled
    logic pcie_nfm_mode      ; // PCIe non-Flit mode
    logic pcie_flit_mode     ; // 256B Flit Mode (set with FMT_PCIE_FLIT, FMT_CXL_256B, FMT_CXL_LOPT, or FMT_CXL_PBR)
//`ifdef CX_CXL_VH_SUPPORT
    logic cxl_vh_enable      ; // CXL 68B VH Flit Mode (FMT_CXL_68BVH)
//`endif // CX_CXL_VH_SUPPORT
    logic cxl_pcie_flit_mode ; // CXL 256B Flit Mode (cxl_mode_enable && pcie_flit_mode)
  } protocol_cfg_t;

  // Link Layer Status Interface with Application Dependant Module (ADM)
  typedef struct {
    logic  [2:0]     pl_bw_ratio;
    logic  [2:0]     pl_speedmode;
    logic            pl_link_up;
    state_enc_e      pl_state_sts;
    protocol_cfg_t   pl_protocol_cfg;
  } link_adm_if_t;

endpackage // spif_pkg

`endif // __GUARD__SPIF_PKG__SVH__
