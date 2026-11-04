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
// ---    $Revision: #8 $
// ---    $Id: //dwh/pcie_iip/main/fairbanks/design/Layer3/rtlh_fc_decode.sv#8 $
// -------------------------------------------------------------------------
// --- Module Description:
// -----------------------------------------------------------------------------
// --- This module performs the decoding on received flow control packets
// -----------------------------------------------------------------------------

`include "include/DWC_pcie_ctl_all_defs.svh"
`include "products/DWC_pcie_core_pkg.svh"
 
module rtlh_fc_decode 
import DWC_pcie_core_pkg::rtlh_rfc_t;
#(
    parameter INST      = 0,                        // The uniquifying parameter for each port logic instance.
    parameter NVC       = `CX_NVC,                  // How many VCs are supported
    parameter NW        = `CX_NW,                   // Number of 32-bit dwords handled by the datapath each clock.
    parameter RX_NDLLP  = `CX_RX_NDLLP,             // Max number of DLLPs received
    parameter TP        = `TP                       // Clock to Q delay (simulator insurance)
)

                     (
// -------------------------------- Inputs ------------------------------------
input                          core_clk,               // Core clock
input                          core_rst_n,             // Core system reset

input   [23:0]                 cfg_vc_id_vc_struc_map, // map a vid to structure vid
input   [1:0]                  rdlh_rtlh_link_state,   // RDLH link up FSM current state.
input   [RX_NDLLP -1:0]        rdlh_rtlh_rcvd_dllp,    // When asserted, it indicates DLLP packet(s) received
input                          rdlh_rtlh_rcvd_dllp_fm_opt_fc_up, // When assered, indicates that we have received a FM Optimized FC update dllp packet
input   [32*RX_NDLLP -1:0]     rdlh_rtlh_dllp_content, // The received DLLP packet(s)
input   [NVC-1:0]              rtlh_fc_init1_status,
input                          flit_mode_en,

output reg  [NVC-1:0]           rx_fc1_p,
output reg  [NVC-1:0]           rx_fc1_np,
output reg  [NVC-1:0]           rx_fc1_cpl,
output reg  [NVC-1:0]           rx_fc2_p,
output reg  [NVC-1:0]           rx_fc2_np,
output reg  [NVC-1:0]           rx_fc2_cpl,
output reg  [NVC-1:0]           rx_updt_p,
output reg  [NVC-1:0]           rx_updt_np,
output reg  [NVC-1:0]           rx_updt_cpl,
output      rtlh_rfc_t          rtlh_rfc                // Received FC update: Update Transmit credit information
,output reg [RX_NDLLP -1:0]     rtlh_rcvd_ufc_perdllp   // Puls : Rx Update-FC DLLP Event per TLP for Ras D.E.S event counter
,output                         init_fc1_rcvd           // Any INITFC1 has been received
,output reg [NVC-1:0]           rx_fc1_p_shrd,
output reg  [NVC-1:0]           rx_fc1_np_shrd,
output reg  [NVC-1:0]           rx_fc1_cpl_shrd,
output reg  [NVC-1:0]           rx_fc2_p_shrd,
output reg  [NVC-1:0]           rx_fc2_np_shrd,
output reg  [NVC-1:0]           rx_fc2_cpl_shrd,
output reg  [NVC-1:0]           rx_updt_p_shrd,
output reg  [NVC-1:0]           rx_updt_np_shrd,
output reg  [NVC-1:0]           rx_updt_cpl_shrd
);

assign init_fc1_rcvd = |rx_fc1_p || |rx_fc1_np || |rx_fc1_cpl || |rx_fc1_p_shrd || |rx_fc1_np_shrd || |rx_fc1_cpl_shrd;

// -----------------------------------------------------------------------------
// --- Internal reg
// -----------------------------------------------------------------------------
reg    [RX_NDLLP*5-1:0]   rdlh_rtlh_dllp_TYPE;
reg    [RX_NDLLP*3-1:0]   rdlh_rtlh_dllp_VCID;
reg    [RX_NDLLP*3-1:0]   rdlh_rtlh_dllp_struc_VCID;
reg    [RX_NDLLP-1:0]     rcvd_fc1_p;
reg    [RX_NDLLP-1:0]     rcvd_fc1_np;
reg    [RX_NDLLP-1:0]     rcvd_fc1_cpl;
reg    [RX_NDLLP-1:0]     rcvd_fc2_p;
reg    [RX_NDLLP-1:0]     rcvd_fc2_np;
reg    [RX_NDLLP-1:0]     rcvd_fc2_cpl;
reg    [RX_NDLLP-1:0]     rcvd_updt_p;
reg    [RX_NDLLP-1:0]     rcvd_updt_np;
reg    [RX_NDLLP-1:0]     rcvd_updt_cpl;
reg    [RX_NDLLP*NVC-1:0] rcvd_fc_match;
reg    [RX_NDLLP*NVC-1:0] rcvd_fc_for_uninit_vc;
reg    [RX_NDLLP*NVC-1:0] rcvd_fc_for_init_vc;
reg                       rcvd_fc1_p_shrd;
reg                       rcvd_fc1_np_shrd;
reg                       rcvd_fc1_cpl_shrd;
reg                       rcvd_fc2_p_shrd;
reg                       rcvd_fc2_np_shrd;
reg                       rcvd_fc2_cpl_shrd;
reg                       rcvd_updt_p_shrd;
reg                       rcvd_updt_np_shrd;
reg                       rcvd_updt_cpl_shrd;

// Decode the DLLPs
always @(*) begin : DLLP_DECODE
    integer i;
    integer j;
    rcvd_fc1_p         = 0;
    rcvd_fc1_np        = 0;
    rcvd_fc1_cpl       = 0;
    rcvd_fc2_p         = 0;
    rcvd_fc2_np        = 0;
    rcvd_fc2_cpl       = 0;
    rcvd_updt_p        = 0;
    rcvd_updt_np       = 0;
    rcvd_updt_cpl      = 0; 
    rcvd_fc1_p_shrd    = 0;
    rcvd_fc1_np_shrd   = 0;
    rcvd_fc1_cpl_shrd  = 0;
    rcvd_fc2_p_shrd    = 0;
    rcvd_fc2_np_shrd   = 0;
    rcvd_fc2_cpl_shrd  = 0;
    rcvd_updt_p_shrd   = 0;
    rcvd_updt_np_shrd  = 0;
    rcvd_updt_cpl_shrd = 0;
    for(i = 0; i < RX_NDLLP; i = i + 1) begin
        rdlh_rtlh_dllp_TYPE[i*5 +: 5]       = rdlh_rtlh_dllp_content[i*32 + 3 +: 5];
        rdlh_rtlh_dllp_VCID[i*3 +: 3]       = rdlh_rtlh_dllp_content[i*32 +: 3];
        rdlh_rtlh_dllp_struc_VCID[i*3 +: 3] = { get_VCID(cfg_vc_id_vc_struc_map,rdlh_rtlh_dllp_VCID[i*3 +: 3],2),
                                                get_VCID(cfg_vc_id_vc_struc_map,rdlh_rtlh_dllp_VCID[i*3 +: 3],1),
                                                get_VCID(cfg_vc_id_vc_struc_map,rdlh_rtlh_dllp_VCID[i*3 +: 3],0)};
        for(j = 0; j < NVC; j = j + 1) begin
            rcvd_fc_match[i*NVC + j] = rdlh_rtlh_dllp_struc_VCID[i*3 +: 3] == j;
            rcvd_fc_for_uninit_vc[i*NVC + j] = rcvd_fc_match[i*NVC + j] && !rtlh_fc_init1_status[j];
            rcvd_fc_for_init_vc[i*NVC + j]   = rcvd_fc_match[i*NVC + j] && rtlh_fc_init1_status[j];
        end
        if (!flit_mode_en) begin
            if (NVC == 1) begin
                rcvd_fc1_p[i]    = rdlh_rtlh_rcvd_dllp[i] && (rdlh_rtlh_dllp_TYPE[i*5 +: 5] == `INITFC1_P)   && (rdlh_rtlh_dllp_content[i*32 +: 4] == 4'b0000);
                rcvd_fc1_np[i]   = rdlh_rtlh_rcvd_dllp[i] && (rdlh_rtlh_dllp_TYPE[i*5 +: 5] == `INITFC1_NP)  && (rdlh_rtlh_dllp_content[i*32 +: 4] == 4'b0000);
                rcvd_fc1_cpl[i]  = rdlh_rtlh_rcvd_dllp[i] && (rdlh_rtlh_dllp_TYPE[i*5 +: 5] == `INITFC1_CPL) && (rdlh_rtlh_dllp_content[i*32 +: 4] == 4'b0000);
                rcvd_fc2_p[i]    = rdlh_rtlh_rcvd_dllp[i] && (rdlh_rtlh_dllp_TYPE[i*5 +: 5] == `INITFC2_P)   && (rdlh_rtlh_dllp_content[i*32 +: 4] == 4'b0000);
                rcvd_fc2_np[i]   = rdlh_rtlh_rcvd_dllp[i] && (rdlh_rtlh_dllp_TYPE[i*5 +: 5] == `INITFC2_NP)  && (rdlh_rtlh_dllp_content[i*32 +: 4] == 4'b0000);
                rcvd_fc2_cpl[i]  = rdlh_rtlh_rcvd_dllp[i] && (rdlh_rtlh_dllp_TYPE[i*5 +: 5] == `INITFC2_CPL) && (rdlh_rtlh_dllp_content[i*32 +: 4] == 4'b0000);
                rcvd_updt_p[i]   = rdlh_rtlh_rcvd_dllp[i] && (rdlh_rtlh_dllp_TYPE[i*5 +: 5] == `UPDFC_P)     && (rdlh_rtlh_dllp_content[i*32 +: 4] == 4'b0000);
                rcvd_updt_np[i]  = rdlh_rtlh_rcvd_dllp[i] && (rdlh_rtlh_dllp_TYPE[i*5 +: 5] == `UPDFC_NP)    && (rdlh_rtlh_dllp_content[i*32 +: 4] == 4'b0000);
                rcvd_updt_cpl[i] = rdlh_rtlh_rcvd_dllp[i] && (rdlh_rtlh_dllp_TYPE[i*5 +: 5] == `UPDFC_CPL)   && (rdlh_rtlh_dllp_content[i*32 +: 4] == 4'b0000);
            end else begin
                rcvd_fc1_p[i]    = rdlh_rtlh_rcvd_dllp[i] && (rdlh_rtlh_dllp_TYPE[i*5 +: 5] == `INITFC1_P);
                rcvd_fc1_np[i]   = rdlh_rtlh_rcvd_dllp[i] && (rdlh_rtlh_dllp_TYPE[i*5 +: 5] == `INITFC1_NP);
                rcvd_fc1_cpl[i]  = rdlh_rtlh_rcvd_dllp[i] && (rdlh_rtlh_dllp_TYPE[i*5 +: 5] == `INITFC1_CPL);
                rcvd_fc2_p[i]    = rdlh_rtlh_rcvd_dllp[i] && (rdlh_rtlh_dllp_TYPE[i*5 +: 5] == `INITFC2_P);
                rcvd_fc2_np[i]   = rdlh_rtlh_rcvd_dllp[i] && (rdlh_rtlh_dllp_TYPE[i*5 +: 5] == `INITFC2_NP);
                rcvd_fc2_cpl[i]  = rdlh_rtlh_rcvd_dllp[i] && (rdlh_rtlh_dllp_TYPE[i*5 +: 5] == `INITFC2_CPL);
                rcvd_updt_p[i]   = rdlh_rtlh_rcvd_dllp[i] && (rdlh_rtlh_dllp_TYPE[i*5 +: 5] == `UPDFC_P);
                rcvd_updt_np[i]  = rdlh_rtlh_rcvd_dllp[i] && (rdlh_rtlh_dllp_TYPE[i*5 +: 5] == `UPDFC_NP);
                rcvd_updt_cpl[i] = rdlh_rtlh_rcvd_dllp[i] && (rdlh_rtlh_dllp_TYPE[i*5 +: 5] == `UPDFC_CPL);
            end
        end
    end
    if (flit_mode_en) begin
        rcvd_fc1_p[0]      = rdlh_rtlh_rcvd_dllp[0] && (rdlh_rtlh_dllp_TYPE[0*5 +: 5] == `INITFC1_P_DED);
        rcvd_fc1_np[0]     = rdlh_rtlh_rcvd_dllp[0] && (rdlh_rtlh_dllp_TYPE[0*5 +: 5] == `INITFC1_NP_DED);
        rcvd_fc1_cpl[0]    = rdlh_rtlh_rcvd_dllp[0] && (rdlh_rtlh_dllp_TYPE[0*5 +: 5] == `INITFC1_CPL_DED);
        rcvd_fc2_p[0]      = rdlh_rtlh_rcvd_dllp[0] && (rdlh_rtlh_dllp_TYPE[0*5 +: 5] == `INITFC2_P_DED);
        rcvd_fc2_np[0]     = rdlh_rtlh_rcvd_dllp[0] && (rdlh_rtlh_dllp_TYPE[0*5 +: 5] == `INITFC2_NP_DED);
        rcvd_fc2_cpl[0]    = rdlh_rtlh_rcvd_dllp[0] && (rdlh_rtlh_dllp_TYPE[0*5 +: 5] == `INITFC2_CPL_DED);
        rcvd_updt_p[0]     = rdlh_rtlh_rcvd_dllp[0] && (rdlh_rtlh_dllp_TYPE[0*5 +: 5] == `UPDFC_P_DED);
        rcvd_updt_np[0]    = rdlh_rtlh_rcvd_dllp[0] && (rdlh_rtlh_dllp_TYPE[0*5 +: 5] == `UPDFC_NP_DED);
        rcvd_updt_cpl[0]   = rdlh_rtlh_rcvd_dllp[0] && (rdlh_rtlh_dllp_TYPE[0*5 +: 5] == `UPDFC_CPL_DED);
        rcvd_fc1_p_shrd    = rdlh_rtlh_rcvd_dllp[0] && (rdlh_rtlh_dllp_TYPE[0*5 +: 5] == `INITFC1_P_SHRD);
        rcvd_fc1_np_shrd   = rdlh_rtlh_rcvd_dllp[0] && (rdlh_rtlh_dllp_TYPE[0*5 +: 5] == `INITFC1_NP_SHRD);
        rcvd_fc1_cpl_shrd  = rdlh_rtlh_rcvd_dllp[0] && (rdlh_rtlh_dllp_TYPE[0*5 +: 5] == `INITFC1_CPL_SHRD);
        rcvd_fc2_p_shrd    = rdlh_rtlh_rcvd_dllp[0] && (rdlh_rtlh_dllp_TYPE[0*5 +: 5] == `INITFC2_P_SHRD);
        rcvd_fc2_np_shrd   = rdlh_rtlh_rcvd_dllp[0] && (rdlh_rtlh_dllp_TYPE[0*5 +: 5] == `INITFC2_NP_SHRD);
        rcvd_fc2_cpl_shrd  = rdlh_rtlh_rcvd_dllp[0] && (rdlh_rtlh_dllp_TYPE[0*5 +: 5] == `INITFC2_CPL_SHRD);
        rcvd_updt_p_shrd   = rdlh_rtlh_rcvd_dllp[0] && (rdlh_rtlh_dllp_TYPE[0*5 +: 5] == `UPDFC_P_SHRD);
        rcvd_updt_np_shrd  = rdlh_rtlh_rcvd_dllp[0] && (rdlh_rtlh_dllp_TYPE[0*5 +: 5] == `UPDFC_NP_SHRD);
        rcvd_updt_cpl_shrd = rdlh_rtlh_rcvd_dllp[0] && (rdlh_rtlh_dllp_TYPE[0*5 +: 5] == `UPDFC_CPL_SHRD);
    end
end

// Drive outputs per VC
always @(*) begin : DRIVE_RX_FC_INDICATIONS
    integer i;
    rx_fc1_p = 0;
    rx_fc1_np = 0;
    rx_fc1_cpl = 0;
    rx_fc2_p = 0;
    rx_fc2_np = 0;
    rx_fc2_cpl = 0;
    rx_updt_p = 0;
    rx_updt_np = 0;
    rx_updt_cpl = 0;
    for(i = 0; i < RX_NDLLP; i = i + 1) begin
        rx_fc1_p    = rx_fc1_p    | rcvd_fc_match[i*NVC +: NVC] & {NVC{rcvd_fc1_p[i]}};
        rx_fc1_np   = rx_fc1_np   | rcvd_fc_match[i*NVC +: NVC] & {NVC{rcvd_fc1_np[i]}};
        rx_fc1_cpl  = rx_fc1_cpl  | rcvd_fc_match[i*NVC +: NVC] & {NVC{rcvd_fc1_cpl[i]}};
        rx_fc2_p    = rx_fc2_p    | rcvd_fc_match[i*NVC +: NVC] & {NVC{rcvd_fc2_p[i]}};
        rx_fc2_np   = rx_fc2_np   | rcvd_fc_match[i*NVC +: NVC] & {NVC{rcvd_fc2_np[i]}};
        rx_fc2_cpl  = rx_fc2_cpl  | rcvd_fc_match[i*NVC +: NVC] & {NVC{rcvd_fc2_cpl[i]}};
        rx_updt_p   = rx_updt_p   | rcvd_fc_match[i*NVC +: NVC] & {NVC{rcvd_updt_p[i]}};
        rx_updt_np  = rx_updt_np  | rcvd_fc_match[i*NVC +: NVC] & {NVC{rcvd_updt_np[i]}};
        rx_updt_cpl = rx_updt_cpl | rcvd_fc_match[i*NVC +: NVC] & {NVC{rcvd_updt_cpl[i]}};
    end
    rx_fc1_p_shrd    = { {RX_NDLLP-1{1'b0}}, rcvd_fc_match[0*NVC +: NVC] & rcvd_fc1_p_shrd    };
    rx_fc1_np_shrd   = { {RX_NDLLP-1{1'b0}}, rcvd_fc_match[0*NVC +: NVC] & rcvd_fc1_np_shrd   };
    rx_fc1_cpl_shrd  = { {RX_NDLLP-1{1'b0}}, rcvd_fc_match[0*NVC +: NVC] & rcvd_fc1_cpl_shrd  };
    rx_fc2_p_shrd    = { {RX_NDLLP-1{1'b0}}, rcvd_fc_match[0*NVC +: NVC] & rcvd_fc2_p_shrd    };
    rx_fc2_np_shrd   = { {RX_NDLLP-1{1'b0}}, rcvd_fc_match[0*NVC +: NVC] & rcvd_fc2_np_shrd   };
    rx_fc2_cpl_shrd  = { {RX_NDLLP-1{1'b0}}, rcvd_fc_match[0*NVC +: NVC] & rcvd_fc2_cpl_shrd  };
    rx_updt_p_shrd   = { {RX_NDLLP-1{1'b0}}, rcvd_fc_match[0*NVC +: NVC] & rcvd_updt_p_shrd   };
    rx_updt_np_shrd  = { {RX_NDLLP-1{1'b0}}, rcvd_fc_match[0*NVC +: NVC] & rcvd_updt_np_shrd  };
    rx_updt_cpl_shrd = { {RX_NDLLP-1{1'b0}}, rcvd_fc_match[0*NVC +: NVC] & rcvd_updt_cpl_shrd };
end

//
// Drive received flow control information over to XADM
//
// when fc state of fc_gen block is in fc1 init or fc update, a received fc
// dllp value will be used to update xadm fc credit account block
//
wire [RX_NDLLP-1:0] rcvd_init;
assign rcvd_init =     rcvd_fc1_p      | rcvd_fc1_np      | rcvd_fc1_cpl      | 
                       rcvd_fc2_p      | rcvd_fc2_np      | rcvd_fc2_cpl      |
  {{RX_NDLLP-1{1'b0}}, rcvd_fc1_p_shrd | rcvd_fc1_np_shrd | rcvd_fc1_cpl_shrd}| 
  {{RX_NDLLP-1{1'b0}}, rcvd_fc2_p_shrd | rcvd_fc2_np_shrd | rcvd_fc2_cpl_shrd} ;

wire [RX_NDLLP-1:0] rcvd_updt;
assign rcvd_updt =     rcvd_updt_p      | rcvd_updt_np      | rcvd_updt_cpl |
  {{RX_NDLLP-1{1'b0}}, rcvd_updt_p_shrd | rcvd_updt_np_shrd | rcvd_updt_cpl_shrd};

reg [RX_NDLLP-1:0] l_rx_rfc_upd;
always @(*) begin : FC_UPDATE
    integer i;
    for(i = 0; i < RX_NDLLP; i = i + 1) begin
        l_rx_rfc_upd[i] = |rcvd_fc_for_uninit_vc[i*NVC +: NVC] && rdlh_rtlh_rcvd_dllp[i] && rcvd_init[i] ||
                          |rcvd_fc_for_init_vc[i*NVC +: NVC]   && rdlh_rtlh_rcvd_dllp[i] && rcvd_updt[i];
    end
end

reg [2:0]     rdlh_rtlh_dllp_VCID_opt;
reg [2:0]     rdlh_rtlh_dllp_struc_VCID_opt;
reg [NVC-1:0] rcvd_fc_match_opt;
reg [NVC-1:0] rcvd_fc_for_init_vc_opt;
reg           rx_rfc_opt_upd;
always_comb begin : FC_OPT_UPDATE
    rdlh_rtlh_dllp_VCID_opt     = rdlh_rtlh_dllp_content[28 +: 3];
    rdlh_rtlh_dllp_struc_VCID_opt = { get_VCID(cfg_vc_id_vc_struc_map,rdlh_rtlh_dllp_VCID_opt,2),
                                      get_VCID(cfg_vc_id_vc_struc_map,rdlh_rtlh_dllp_VCID_opt,1),
                                      get_VCID(cfg_vc_id_vc_struc_map,rdlh_rtlh_dllp_VCID_opt,0)};
    for(int j = 0; j < NVC; j = j + 1) begin
        rcvd_fc_match_opt[j] = rdlh_rtlh_dllp_struc_VCID_opt == j;
        rcvd_fc_for_init_vc_opt[j]   = rcvd_fc_match_opt[j] && rtlh_fc_init1_status[j];
    end
    rx_rfc_opt_upd = |rcvd_fc_for_init_vc_opt  && rdlh_rtlh_rcvd_dllp_fm_opt_fc_up;
end

wire [RX_NDLLP-1:0] l_rx_rfc_upd_any;
assign l_rx_rfc_upd_any = l_rx_rfc_upd | {{RX_NDLLP-1{1'b0}},rx_rfc_opt_upd} ;

always @(posedge core_clk or negedge core_rst_n)
begin : decode_fc_updates
    if(!core_rst_n) begin
        rtlh_rfc.upd              <= #TP 0;
        rtlh_rfc.data             <= #TP 0;
        rtlh_rfc.upd_is_optimized <= #TP 0;
    end else begin
        // identify FC pkt(s) - INIT_FC1, INIT_FC2, UPDATE
        rtlh_rfc.upd              <= #TP l_rx_rfc_upd_any ;
        if(|l_rx_rfc_upd_any) begin
            rtlh_rfc.data         <= #TP rdlh_rtlh_dllp_content;
        end
        rtlh_rfc.upd_is_optimized <= #TP rx_rfc_opt_upd;
    end
end

// Event flag for RAS D.E.S
always @(posedge core_clk or negedge core_rst_n) begin
    if(!core_rst_n) begin
        rtlh_rcvd_ufc_perdllp  <= #TP 0;
    end else begin
        rtlh_rcvd_ufc_perdllp  <= #TP rcvd_updt | {{RX_NDLLP-1{1'b0}},rx_rfc_opt_upd} ;
    end
end

function automatic get_VCID;
    input [23:0] vcid_struct_map_local;
    input [2:0] strct_vcid;
    input [1:0] client_ndx;
    reg [24:0] vcid_struct_map_local_padded;
//cfg_vc_id_vc_struc_map[(3*rdlh_rtlh_dllp1_VCID) +2]
    begin
        get_VCID                    = 0;
        vcid_struct_map_local_padded= {1'b0,vcid_struct_map_local};
        case (strct_vcid)
            3'b000:  get_VCID   = vcid_struct_map_local_padded[client_ndx + (0*3)];
            3'b001:  get_VCID   = vcid_struct_map_local_padded[client_ndx + (1*3)];
            3'b010:  get_VCID   = vcid_struct_map_local_padded[client_ndx + (2*3)];
            3'b011:  get_VCID   = vcid_struct_map_local_padded[client_ndx + (3*3)];
            3'b100:  get_VCID   = vcid_struct_map_local_padded[client_ndx + (4*3)];
            3'b101:  get_VCID   = vcid_struct_map_local_padded[client_ndx + (5*3)];
            3'b110:  get_VCID   = vcid_struct_map_local_padded[client_ndx + (6*3)];
            3'b111:  get_VCID   = vcid_struct_map_local_padded[client_ndx + (7*3)];
        endcase // case(strct_vcid)
    end
endfunction

endmodule
