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

// ----------------------------------------------------------------------------
// ---  RCS information:
// ---    $DateTime: 2023/09/27 02:27:25 $
// ---    $Revision: #4 $
// ---    $Id: //dwh/pcie_iip/main/fairbanks/design/Layer3/rtlh_pkg.svh#4 $
// ----------------------------------------------------------------------------
// --- Description:
// ----------------------------------------------------------------------------
`ifndef __GUARD__RTLH_PKG__SVH__
`define __GUARD__RTLH_PKG__SVH__

`include "products/pcie_pkg.svh"

package rtlh_pkg;
  import pcie_pkg::fc_type_e;

  // Flit mode status used in rtlh fm decoder
  typedef enum logic [1:0] {
      NOTHING,
      ONGOING
  } tlp_state_t;

  // TLP type needed for rasdes event counters
  typedef enum logic[3:0] {NO_FMT = 4'b0, MEMWR, DEFMEMWR, MEMRD, CFGWR, CFGRD, IOWR, IORD, CPLWOD, CPLWD, MSG, ATMCOP} evt_type_e;

  // this is the data passed between decoders in rtlh_qdw_extract_dec
  typedef struct packed {
      logic [1:0]                         nw;         // pending number of dws
      logic [3*32-1:0]                    data;       // pending data to be passed to next decoder
      logic [3*`CX_RAS_DWORD_PROT_WD-1:0] data_prot;  // Protection bits for data signal
      logic                               sot;        // pending sot flag
      logic                               eot;        // data pending contains eot flag and needs to be packed directly into qdw
      logic                               dllp_err;   // the pending tlp is flagged with dllp error
      tlp_state_t                         status;     // passing the status of the previous decoder
      fc_type_e                           fc;         // flow control type of pending tlp
      logic [2:0]                         vc;         // virtual channel of pending tlp
      logic                               hdr_valid;  // pending data contains header
      logic [8:0]                         dcrd_amt;   // Amount of Data Credits
      logic [10:0]                        dpsize;     // Data Payload Size
      evt_type_e                          evt_type;   // TLP type for rasdes event counter
      logic                               has_pfx;    // TLP has a prefix for rasdes event counter (note that this does not mean this qdw contains a prefix, only that the tlp it belongs to contained a prefix)
  } dec_tlp_state_t;

  // RTLH TLP extract qDW ouputs
  typedef struct packed {
      logic                                      valid;       // Valid qDW
      logic                                      sot;         // TLP starting on this qDW
      logic                                      eot;         // TLP ending on this qDW
      logic [3:0]                                dwen;        // DWord enabled
      logic [127:0]                              data;        // Data payload (i.e. TLP prefix, header and data)
      logic [DWC_pcie_core_pkg::QDW_PROT_WD-1:0] data_prot;   // Protection bits for data signal
      logic                                      hdr_valid;   // The current qDW contains the 1st DW Header
      logic [2:0]                                hdr_vc;      // VC specified in the Header 
      fc_type_e                                  hdr_fc;      // TLP type
      logic                                      dllp_err;
      logic [8:0]                                dcrd_amt;    // Amount of Data Credits
      logic [10:0]                               dpsize;      // Data Payload Size
      evt_type_e                                 evt_type;    // TLP type for rasdes event counter
      logic                                      has_pfx;     // TLP has a prefix for rasdes event counter (note that this does not mean this qdw contains a prefix, only that the tlp it belongs to contained a prefix)
  } rtlh_qdw_extract_t;

  localparam rtlh_qdw_extract_t RTLH_QDW_EXTRACT_RESET = '{default:0, hdr_fc:pcie_pkg::E_FC_NONE, evt_type:NO_FMT};  // set default of fc to non-zero enum value E_FC_NONE
  
  // Get the amount of data credits required
  function automatic [8:0] get_dcrd_amt (input logic [9:0] length, input logic [7:0] fmt_type, input logic smlh_flit_mode_enable);
      pcie_pkg::decoded_tlp_type_s dec_type;
      dec_type      = pcie_pkg::f_decode_tlp_type(fmt_type, 1'b1);
      get_dcrd_amt  = (dec_type.payload)? (length == 10'b0)? 9'd256 : ({1'b0,length[9:2]} + |length[1:0]) : 9'b0; 
  endfunction

  // Get data payload size (i.e. number of data dwords)
  function automatic [10:0] get_dpsize (input logic [9:0] length, input logic [7:0] fmt_type, input logic smlh_flit_mode_enable);
      pcie_pkg::decoded_tlp_type_s dec_type;
      dec_type      = pcie_pkg::f_decode_tlp_type(fmt_type, 1'b1);
      get_dpsize  = (dec_type.payload)? (length == 10'b0)? 11'd1024 : ({1'b0,length[9:0]}) : 11'b0; 
  endfunction

  function automatic evt_type_e get_evt_type (input logic [7:0] evt_type, input logic smlh_flit_mode_enable);
      reg [6:0] mrd32;
      if (smlh_flit_mode_enable) begin
          mrd32 = `FLIT_MRD32; 
      end else begin
          mrd32 = `MRD32;
      end
      get_evt_type = NO_FMT;
      if (!evt_type[7]) begin
          unique casez (evt_type[6:0])
              mrd32,        `MRD64                                            : get_evt_type = MEMRD;
              `MWR32,       `MWR64                                            : get_evt_type = MEMWR;
              `MSG,         `MSGD                                             : get_evt_type = MSG;
              `IOWR                                                           : get_evt_type = IOWR;
              `DMWR32,      `DMWR64                                           : get_evt_type = DEFMEMWR;
              `CFGWR1,      `CFGWR0                                           : get_evt_type = CFGWR;
              `IORD                                                           : get_evt_type = IORD;
              `MRDLK32,     `MRDLK64                                          : get_evt_type = MEMRD;   
              `CFGRD1,      `CFGRD0                                           : get_evt_type = CFGRD;       
              `FETCHADD32,  `FETCHADD64,  `SWAP32,  `SWAP64,  `CAS32, `CAS64  : get_evt_type = ATMCOP;         
              `CPL,         `CPLLK                                            : get_evt_type = CPLWOD;       
              `CPLD,        `CPLDLK                                           : get_evt_type = CPLWD;     
              default                                                         : get_evt_type = NO_FMT;   
          endcase
      end
  endfunction

  function automatic [2:0] get_VC (input [23:0] tc_vc_map, input [2:0] tc);
    case (tc)
        3'b000: get_VC = tc_vc_map[2:0];
        3'b001: get_VC = tc_vc_map[5:3];
        3'b010: get_VC = tc_vc_map[8:6];
        3'b011: get_VC = tc_vc_map[11:9];
        3'b100: get_VC = tc_vc_map[14:12];
        3'b101: get_VC = tc_vc_map[17:15];
        3'b110: get_VC = tc_vc_map[20:18];
        3'b111: get_VC = tc_vc_map[23:21];
    endcase
endfunction
endpackage
`endif // __GUARD__RTLH_PKG__SVH__
