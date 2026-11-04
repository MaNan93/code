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
// ---    $Revision: #4 $
// ---    $Id: //dwh/pcie_iip/main/fairbanks/design/Adm_ms/xadm_ms_pkg.svh#4 $
// -------------------------------------------------------------------------

// ----------------------------------------------------------------------------
// --- Module Description:
//
// ----------------------------------------------------------------------------

`ifndef __GUARD__XADM_MS_PKG__SVH__
`define __GUARD__XADM_MS_PKG__SVH__

`include "products/pcie_pkg.svh"
`include "DWC_pcie_ctl_pkg.svh"

package xadm_ms_pkg;
    import DWC_pcie_ctl_pkg::RCB_DW;
    import DWC_pcie_ctl_pkg::RCB_DW_WD;
    import DWC_pcie_ctl_pkg::RX_NDLLP;
    import DWC_pcie_core_pkg::xadm_pkt_t;
    import DWC_pcie_ctl_pkg::HCRD_WD;
    import DWC_pcie_ctl_pkg::DCRD_WD;
    import pcie_pkg::tlp_hdr_pkt_s;
    import pcie_pkg::mode_e;
    import pcie_pkg::f_tlp_hdr_extract;

    
    // -----------------------------------------------------------------------------
    // Parameter Declarations
    // -----------------------------------------------------------------------------
    localparam SHR = 1;
    localparam DED = 0;
    
    // -----------------------------------------------------------------------------
    // Typedefs Declarations
    // -----------------------------------------------------------------------------
    
    // Bring credit info from XADM DLLP module to CRDT Bank
    typedef struct packed{
        logic        is_fcinit12;
        logic        h_limit;
        logic        d_limit;
        logic [7:0]  h_limit_value;
        logic [11:0] d_limit_value;
        logic        hd_scale;
        logic [1:0]  h_scale_value;
        logic [1:0]  d_scale_value;
        logic        h_is_zero; 
        logic        d_is_zero; 
        logic        h_is_infinite; 
        logic        d_is_infinite; 
        logic        is_for_shared; 
        logic        cpl_is_merged;
    } xadm_fc_update_t;
    
    // Restore credit signals for Nullified or RASDP error TLPs from XTLH
    typedef struct packed{
        logic     [HCRD_WD-1:0] hcrd;
        logic     [DCRD_WD-1:0] dcrd;
    } xadm_restore_fc_crdt_t;


    // -----------------------------------------------------------------------------
 
    // -----------------------------------------------------------------------------
    // Function Declarations
    // -----------------------------------------------------------------------------
    
    function automatic logic[10:0] get_length_dw_11b(xadm_pkt_t pkt);
        logic found;
        found = 1'b0;
        get_length_dw_11b = '0;
        for(int i = 0; i < $size(pkt.hdr_dwen); i++)begin
            if(pkt.hdr_dwen[i] && !found && pkt.hv)begin
                found = 1'b1;
                get_length_dw_11b = {1'b0, {pkt.prfx_hdr[i][17:16], pkt.prfx_hdr[i][31:24]}};
                if(get_length_dw_11b=='0)
                    get_length_dw_11b = 11'd1024;
            end
        end
    endfunction

    function automatic tlp_hdr_pkt_s f_xadm_tlp_hdr_pkt (
      input mode_e        mode,
      input xadm_pkt_t    xadm_pkt
    );
      begin
        logic  [3:0]        j;
        logic [`CX_NPRFX_XADM-1:0] [31:0] tlp_prfx_dw;
        logic [15:0] [31:0]            tlp_hdr_dw;
        localparam PRFX_EXTRA_WD = 32*(8-`CX_NPRFX_XADM);

        // Initialise values
        j           =  0;
        tlp_prfx_dw = '0;
        tlp_hdr_dw  = '0;

        // Extract Prfx + Header
        for (int i=0; i<`CX_NPRFX_XADM; i++) begin
          if (xadm_pkt.prfx_dwen[i]) begin
            tlp_prfx_dw[i] = xadm_pkt.prfx_hdr[i];
          end
          else tlp_prfx_dw[i] ='0;
        end
        for (int i=0; i<`CX_HDW; i++) begin
          if (xadm_pkt.hdr_dwen[i]) begin
            tlp_hdr_dw[j]  = xadm_pkt.prfx_hdr[i];
            j++;
          end
        end

        // Return struct
        f_xadm_tlp_hdr_pkt = f_tlp_hdr_extract(mode, {{PRFX_EXTRA_WD{1'b0}}, tlp_prfx_dw}, tlp_hdr_dw);
      end
    endfunction // f_xadm_tlp_hdr_pkt


endpackage

`endif //__GUARD__XADM_MS_PKG__SVH__
