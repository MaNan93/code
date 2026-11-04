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
// ---    $DateTime: 2023/12/22 07:15:34 $
// ---    $Revision: #5 $
// ---    $Id: //dwh/pcie_iip/main/fairbanks/design/Layer3/rtlh_qdw_extract_dec.sv#5 $
// ----------------------------------------------------------------------------
// --- Description:
// ----------------------------------------------------------------------------

`include "include/DWC_pcie_ctl_all_defs.svh"
`include "DWC_pcie_ctl_pkg.svh"
`include "Layer3/rtlh_pkg.svh"
`include "products/pcie_pkg.svh"

module rtlh_qdw_extract_dec
import pcie_pkg::decoded_tlp_type_s;
import rtlh_pkg::dec_tlp_state_t;
import rtlh_pkg::rtlh_qdw_extract_t;
import rtlh_pkg::NOTHING;
import rtlh_pkg::ONGOING;
import rtlh_pkg::evt_type_e;
import pcie_pkg::E_P;
import pcie_pkg::E_FC_NONE;
import pcie_pkg::fc_type_e;
#(
    parameter DW_PROT_WD = `CX_RAS_DWORD_PROT_WD
)

                           (
    // --- Inputs ---------------------
    input                     [23:0]               cfg_tc_struc_vc_map,
    input                                          flit_mode_en,

    input                     [4:0]                tlp_pfx,        
    input                     [4:0]                tlp_soh,          
    input                     [4:0]                tlp_eot,          
    input                     [4:0]                tlp_idl,
    input                     [4:0]                tlp_dllp_err,
    input                     [5*32-1:0]           data,         
    input                     [(5*DW_PROT_WD)-1:0] data_prot,

    input dec_tlp_state_t                          pts,           // state from previous decoder

    // --- Outputs --------------------
    output rtlh_qdw_extract_t [1:0]                qdws,          // horizontal outputs 
    output dec_tlp_state_t                         nts            // next decoder tlp state
);

// create ipg signal, if the status from the previous decoder is NOTHING or a tlp ends in the decoder, this signal marks an ipg
wire [4:0] tlp_ipg;
assign tlp_ipg = {  !tlp_pfx[4] && !tlp_soh[4],
                    !tlp_pfx[3] && !tlp_soh[3],
                    !tlp_pfx[2] && !tlp_soh[2],
                    !tlp_pfx[1] && !tlp_soh[1],
                    !tlp_pfx[0] && !tlp_soh[0]};

wire [4:0] tlp_sot;
assign tlp_sot = {  tlp_pfx[4] || tlp_soh[4],
                    tlp_pfx[3] || tlp_soh[3],
                    tlp_pfx[2] || tlp_soh[2],
                    tlp_pfx[1] || tlp_soh[1],
                    tlp_pfx[0] || tlp_soh[0]};

localparam bit PAR_MODE = (`CX_RAS_PARITY_MODE == 1)? 1'b1 : 1'b0; // the parity mode (if odd, we fill zero data with ones, if even we fill zero data with zeros)
localparam bit [1*DW_PROT_WD-1:0] DEF_PROT_1DW = {1*DW_PROT_WD{PAR_MODE}};
localparam bit [2*DW_PROT_WD-1:0] DEF_PROT_2DW = {2*DW_PROT_WD{PAR_MODE}};
localparam bit [3*DW_PROT_WD-1:0] DEF_PROT_3DW = {3*DW_PROT_WD{PAR_MODE}};
localparam bit [4*DW_PROT_WD-1:0] DEF_PROT_4DW = {4*DW_PROT_WD{PAR_MODE}};

// TLP info extracted from the 1sw Base Header DW
typedef struct packed {
    logic     [10:0] dpsize;
    evt_type_e       evt_type;
    logic      [8:0] dcrd_amt;
    logic      [2:0] vc;
    fc_type_e        fc;
} hdr_info_s;

hdr_info_s pts_hdr_info;
hdr_info_s qdw0_hdr_info;
hdr_info_s qdw1_hdr_info;
hdr_info_s nts_hdr_info;

assign pts_hdr_info   = { pts.dpsize, pts.evt_type, pts.dcrd_amt, pts.vc, pts.fc};
assign { qdws[0].dpsize, qdws[0].evt_type, qdws[0].dcrd_amt, qdws[0].hdr_vc, qdws[0].hdr_fc} = qdw0_hdr_info;
assign { qdws[1].dpsize, qdws[1].evt_type, qdws[1].dcrd_amt, qdws[1].hdr_vc, qdws[1].hdr_fc} = qdw1_hdr_info;
assign { nts.dpsize,     nts.evt_type, nts.dcrd_amt,     nts.vc,         nts.fc}         = nts_hdr_info;

// Default TLP Info value used until the base header is reached and the actual info gets extracted.
localparam hdr_info_s DEFAULT_HDR_INFO = '{ dpsize:11'b0, evt_type:evt_type_e'(0), dcrd_amt:9'b0, vc:3'b0, fc:E_FC_NONE};


// Common arguments to be passed to get_hdr_valid and get_hdr_info functions
typedef struct packed {
    logic       pts_h_val;
    logic [4:0] tlp_soh;
} ca_h_val_s;
ca_h_val_s ca_h_val;
assign ca_h_val.pts_h_val = pts.hdr_valid;
assign ca_h_val.tlp_soh   = tlp_soh;

typedef struct packed {
    dec_tlp_state_t          pts;
    logic              [4:0] tlp_soh;
    hdr_info_s         [4:0] info;
} ca_h_info_s;
ca_h_info_s ca_h_info;

decoded_tlp_type_s     [4:0] tmp_dec_type;
assign ca_h_info.pts = pts;
assign ca_h_info.tlp_soh = tlp_soh;
generate for (genvar i=0; i<5;i++) begin : gen_ca // Extract TLP info from each of the 5 DWs pretending is the 1st Base Header DW
  assign tmp_dec_type[i]            = pcie_pkg::f_decode_tlp_type(data[i*32+:8], flit_mode_en);
  assign ca_h_info.info[i].fc       = tmp_dec_type[i].fc_type;
  assign ca_h_info.info[i].vc       = rtlh_pkg::get_VC(cfg_tc_struc_vc_map, data[((i*32)+12)+:3]);
  assign ca_h_info.info[i].dcrd_amt = rtlh_pkg::get_dcrd_amt({data[((i*32)+16)+:2],data[((i*32)+24)+:8]},data[i*32+:8],flit_mode_en);
  assign ca_h_info.info[i].dpsize   = rtlh_pkg::get_dpsize({data[((i*32)+16)+:2],data[((i*32)+24)+:8]},data[i*32+:8],flit_mode_en);
  assign ca_h_info.info[i].evt_type = rtlh_pkg::get_evt_type(data[i*32+:8],flit_mode_en);
end
endgenerate

dec_tlp_state_t chk_nts;     // next decoder tlp state used only for validation purposes

always @(*) begin : next_state_status_PROC
    unique case ( 1'b1 )
      tlp_eot[4], 
      tlp_idl[4] && tlp_eot[3],
      tlp_idl[4] && tlp_idl[3] && tlp_eot[2],
      tlp_idl[4] && tlp_idl[3] && tlp_idl[2] && tlp_eot[1],
      tlp_idl[4] && tlp_idl[3] && tlp_idl[2] && tlp_idl[1] && tlp_eot[0]                        : nts.status = NOTHING;

      tlp_idl[4] && tlp_idl[3] && tlp_idl[2] && tlp_idl[1] && tlp_idl[0],
      tlp_ipg[4] && tlp_ipg[3] && tlp_ipg[2] && tlp_ipg[1] && tlp_ipg[0] && pts.status==NOTHING : nts.status = pts.eot ? NOTHING : pts.status;

                                                                                        default : nts.status = ONGOING;
    endcase
end // next_state_status_PROC

// START MARKER FOR SCRIPT GENERATED CODE. RTLH AUTO
enum int {
    i_i_i_i_i,
    s_i_i_i_i,
    i_s_i_i_i,
    d_s_i_i_i,
    i_i_s_i_i,
    i_d_s_i_i,
    e_d_s_i_i,
    d_d_s_i_i,
    i_i_i_s_i,
    i_i_d_s_i,
    i_e_d_s_i,
    s_e_d_s_i,
    i_d_d_s_i,
    e_d_d_s_i,
    d_d_d_s_i,
    i_i_i_i_s,
    i_i_i_d_s,
    i_i_e_d_s,
    s_i_e_d_s,
    i_s_e_d_s,
    d_s_e_d_s,
    i_i_d_d_s,
    i_e_d_d_s,
    s_e_d_d_s,
    i_d_d_d_s,
    e_d_d_d_s,
    d_d_d_d_s,
    i_i_i_i_e__0,
    s_i_i_i_e__0,
    i_s_i_i_e__0,
    d_s_i_i_e__0,
    i_i_s_i_e__0,
    i_d_s_i_e__0,
    e_d_s_i_e__0,
    d_d_s_i_e__0,
    i_i_i_s_e__0,
    i_i_d_s_e__0,
    i_e_d_s_e__0,
    s_e_d_s_e__0,
    i_d_d_s_e__0,
    e_d_d_s_e__0,
    d_d_d_s_e__0,
    i_i_i_i_d__0,
    i_i_i_e_d__0,
    s_i_i_e_d__0,
    i_s_i_e_d__0,
    d_s_i_e_d__0,
    i_i_s_e_d__0,
    i_d_s_e_d__0,
    e_d_s_e_d__0,
    d_d_s_e_d__0,
    i_i_i_d_d__0,
    i_i_e_d_d__0,
    s_i_e_d_d__0,
    i_s_e_d_d__0,
    d_s_e_d_d__0,
    i_i_d_d_d__0,
    i_e_d_d_d__0,
    s_e_d_d_d__0,
    i_d_d_d_d__0,
    e_d_d_d_d__0,
    d_d_d_d_d__0,
    i_i_i_i_e__1,
    s_i_i_i_e__1,
    i_s_i_i_e__1,
    d_s_i_i_e__1,
    i_i_s_i_e__1,
    i_d_s_i_e__1,
    e_d_s_i_e__1,
    d_d_s_i_e__1,
    i_i_i_s_e__1,
    i_i_d_s_e__1,
    i_e_d_s_e__1,
    s_e_d_s_e__1,
    i_d_d_s_e__1,
    e_d_d_s_e__1,
    d_d_d_s_e__1,
    i_i_i_i_d__1,
    i_i_i_e_d__1,
    s_i_i_e_d__1,
    i_s_i_e_d__1,
    d_s_i_e_d__1,
    i_i_s_e_d__1,
    i_d_s_e_d__1,
    e_d_s_e_d__1,
    d_d_s_e_d__1,
    i_i_i_d_d__1,
    i_i_e_d_d__1,
    s_i_e_d_d__1,
    i_s_e_d_d__1,
    d_s_e_d_d__1,
    i_i_d_d_d__1,
    i_e_d_d_d__1,
    s_e_d_d_d__1,
    i_d_d_d_d__1,
    e_d_d_d_d__1,
    d_d_d_d_d__1,
    i_i_i_i_e__2,
    s_i_i_i_e__2,
    i_s_i_i_e__2,
    d_s_i_i_e__2,
    i_i_s_i_e__2,
    i_d_s_i_e__2,
    e_d_s_i_e__2,
    d_d_s_i_e__2,
    i_i_i_s_e__2,
    i_i_d_s_e__2,
    i_e_d_s_e__2,
    s_e_d_s_e__2,
    i_d_d_s_e__2,
    e_d_d_s_e__2,
    d_d_d_s_e__2,
    i_i_i_i_d__2,
    i_i_i_e_d__2,
    s_i_i_e_d__2,
    i_s_i_e_d__2,
    d_s_i_e_d__2,
    i_i_s_e_d__2,
    i_d_s_e_d__2,
    e_d_s_e_d__2,
    d_d_s_e_d__2,
    i_i_i_d_d__2,
    i_i_e_d_d__2,
    s_i_e_d_d__2,
    i_s_e_d_d__2,
    d_s_e_d_d__2,
    i_i_d_d_d__2,
    i_e_d_d_d__2,
    s_e_d_d_d__2,
    i_d_d_d_d__2,
    e_d_d_d_d__2,
    d_d_d_d_d__2,
    i_i_i_i_e__3,
    s_i_i_i_e__3,
    i_s_i_i_e__3,
    d_s_i_i_e__3,
    i_i_s_i_e__3,
    i_d_s_i_e__3,
    e_d_s_i_e__3,
    d_d_s_i_e__3,
    i_i_i_s_e__3,
    i_i_d_s_e__3,
    i_e_d_s_e__3,
    s_e_d_s_e__3,
    i_d_d_s_e__3,
    e_d_d_s_e__3,
    d_d_d_s_e__3,
    i_i_i_i_d__3,
    i_i_i_e_d__3,
    s_i_i_e_d__3,
    i_s_i_e_d__3,
    d_s_i_e_d__3,
    i_i_s_e_d__3,
    i_d_s_e_d__3,
    e_d_s_e_d__3,
    d_d_s_e_d__3,
    i_i_i_d_d__3,
    i_i_e_d_d__3,
    s_i_e_d_d__3,
    i_s_e_d_d__3,
    d_s_e_d_d__3,
    i_i_d_d_d__3,
    i_e_d_d_d__3,
    s_e_d_d_d__3,
    i_d_d_d_d__3,
    e_d_d_d_d__3,
    d_d_d_d_d__3,
    x_x_x_x_x
} dec_case         ;

always @(*) begin : next_state_PROC
    dec_case          = x_x_x_x_x;
    qdws[0].valid     = 1'b0;
    qdws[0].data      = 128'b0;
    qdws[0].dwen      = 4'b0000;
    qdws[0].sot       = 1'b0;
    qdws[0].eot       = 1'b0;
    qdw0_hdr_info     = DEFAULT_HDR_INFO;
    qdws[0].has_pfx   = 1'b0;
    qdws[0].hdr_valid = 1'b0;
    qdws[0].dllp_err  = 1'b0;
    qdws[0].data_prot = DEF_PROT_4DW;

    qdws[1].valid     = 1'b0;
    qdws[1].data      = 128'b0;
    qdws[1].dwen      = 4'b0000;
    qdws[1].sot       = 1'b0;
    qdws[1].eot       = 1'b0;
    qdw1_hdr_info     = DEFAULT_HDR_INFO;
    qdws[1].has_pfx   = 1'b0;
    qdws[1].hdr_valid = 1'b0;
    qdws[1].dllp_err  = 1'b0;
    qdws[1].data_prot = DEF_PROT_4DW;

    nts.nw            = 2'd0;
    nts.data          = 96'b0;
    nts.sot           = 1'b0;
    nts.eot           = 1'b0;
    nts_hdr_info      = DEFAULT_HDR_INFO;
    nts.has_pfx       = 1'b0;
    nts.hdr_valid     = 1'b0;
    nts.dllp_err      = 1'b0;
    nts.data_prot     = DEF_PROT_3DW;
    chk_nts.status    = NOTHING;
    unique case ( 1'b1 )
      tlp_idl[0] && tlp_idl[1] && tlp_idl[2] && tlp_idl[3] && tlp_idl[4],
      // this is a special case when rdlh_rtlh_tlp_idl signal is not driven because of the RX Freq Step
      pts.status==NOTHING && tlp_ipg[0] && tlp_ipg[1] && tlp_ipg[2] && tlp_ipg[3] && tlp_ipg[4] :
        begin
          dec_case          = i_i_i_i_i;
          qdws[0].valid     = pts.eot ? 1'b1 : 1'b0;
          qdws[0].data      = pts.eot ? {32'b0,pts.data} : 128'b0;
          qdws[0].dwen      = pts.eot ? dwen_dec(pts.nw) : 4'b0000;
          qdws[0].sot       = pts.eot ? pts.sot : 1'b0;
          qdws[0].eot       = pts.eot ? 1'b1 : 1'b0;
          qdw0_hdr_info     = pts.eot ? pts_hdr_info : DEFAULT_HDR_INFO;
          qdws[0].has_pfx   = pts.eot ? pts.has_pfx : 1'b0;
          qdws[0].hdr_valid = pts.eot ? pts.hdr_valid : 1'b0;
          qdws[0].dllp_err  = pts.eot ? pts.dllp_err : 1'b0;
          qdws[0].data_prot = pts.eot ? {DEF_PROT_1DW,pts.data_prot} : DEF_PROT_4DW;

          qdws[1].valid     = 1'b0;
          qdws[1].data      = 128'b0;
          qdws[1].dwen      = 4'b0000;
          qdws[1].sot       = 1'b0;
          qdws[1].eot       = 1'b0;
          qdw1_hdr_info     = DEFAULT_HDR_INFO;
          qdws[1].has_pfx   = 1'b0;
          qdws[1].hdr_valid = 1'b0;
          qdws[1].dllp_err  = 1'b0;
          qdws[1].data_prot = DEF_PROT_4DW;

          nts.nw            = pts.eot ? 2'd0 : pts.nw;
          nts.data          = pts.eot ? 96'b0 : pts.data;
          nts.sot           = pts.eot ? 1'b0 : pts.sot;
          nts.eot           = 1'b0;
          nts_hdr_info      = pts.eot ? DEFAULT_HDR_INFO : pts_hdr_info;
          nts.has_pfx       = pts.eot ? 1'b0 : pts.has_pfx;
          nts.hdr_valid     = pts.eot ? 1'b0 : pts.hdr_valid;
          nts.dllp_err      = pts.eot ? 1'b0 : pts.dllp_err;
          nts.data_prot     = pts.eot ? DEF_PROT_3DW : pts.data_prot;
          chk_nts.status    = pts.eot ? NOTHING : pts.status;
        end

      pts.status==NOTHING && tlp_idl[0] && tlp_idl[1] && tlp_idl[2] && tlp_idl[3] && tlp_sot[4] :
        begin
          dec_case          = s_i_i_i_i;
          qdws[0].valid     = pts.eot ? 1'b1 : 1'b0;
          qdws[0].data      = pts.eot ? {32'b0,pts.data} : 128'b0;
          qdws[0].dwen      = pts.eot ? dwen_dec(pts.nw) : 4'b0000;
          qdws[0].sot       = pts.eot ? pts.sot : 1'b0;
          qdws[0].eot       = pts.eot ? 1'b1 : 1'b0;
          qdw0_hdr_info     = pts.eot ? pts_hdr_info : DEFAULT_HDR_INFO;
          qdws[0].has_pfx   = pts.eot ? pts.has_pfx : 1'b0;
          qdws[0].hdr_valid = pts.eot ? pts.hdr_valid : 1'b0;
          qdws[0].dllp_err  = pts.eot ? pts.dllp_err : 1'b0;
          qdws[0].data_prot = pts.eot ? {DEF_PROT_1DW,pts.data_prot} : DEF_PROT_4DW;

          qdws[1].valid     = 1'b0;
          qdws[1].data      = 128'b0;
          qdws[1].dwen      = 4'b0000;
          qdws[1].sot       = 1'b0;
          qdws[1].eot       = 1'b0;
          qdw1_hdr_info     = DEFAULT_HDR_INFO;
          qdws[1].has_pfx   = 1'b0;
          qdws[1].hdr_valid = 1'b0;
          qdws[1].dllp_err  = 1'b0;
          qdws[1].data_prot = DEF_PROT_4DW;

          nts.nw            = 2'd1;
          nts.data          = {64'b0,data[4*32 +: 1*32]};
          nts.sot           = 1'b1;
          nts.eot           = 1'b0;
          nts_hdr_info      = get_hdr_info (3'd4, 3'd1, 1'b0, ca_h_info);
          nts.has_pfx       = tlp_pfx[4];
          nts.hdr_valid     = get_hdr_valid (3'd4, 3'd1, 1'b0, ca_h_val);
          nts.dllp_err      = 1'b0;
          nts.data_prot     = {DEF_PROT_2DW,data_prot[4*DW_PROT_WD +: 1*DW_PROT_WD]};
          chk_nts.status    = ONGOING;
        end

      pts.status==NOTHING && tlp_idl[0] && tlp_idl[1] && tlp_idl[2] && tlp_sot[3] && tlp_idl[4] :
        begin
          dec_case          = i_s_i_i_i;
          qdws[0].valid     = pts.eot ? 1'b1 : 1'b0;
          qdws[0].data      = pts.eot ? {32'b0,pts.data} : 128'b0;
          qdws[0].dwen      = pts.eot ? dwen_dec(pts.nw) : 4'b0000;
          qdws[0].sot       = pts.eot ? pts.sot : 1'b0;
          qdws[0].eot       = pts.eot ? 1'b1 : 1'b0;
          qdw0_hdr_info     = pts.eot ? pts_hdr_info : DEFAULT_HDR_INFO;
          qdws[0].has_pfx   = pts.eot ? pts.has_pfx : 1'b0;
          qdws[0].hdr_valid = pts.eot ? pts.hdr_valid : 1'b0;
          qdws[0].dllp_err  = pts.eot ? pts.dllp_err : 1'b0;
          qdws[0].data_prot = pts.eot ? {DEF_PROT_1DW,pts.data_prot} : DEF_PROT_4DW;

          qdws[1].valid     = 1'b0;
          qdws[1].data      = 128'b0;
          qdws[1].dwen      = 4'b0000;
          qdws[1].sot       = 1'b0;
          qdws[1].eot       = 1'b0;
          qdw1_hdr_info     = DEFAULT_HDR_INFO;
          qdws[1].has_pfx   = 1'b0;
          qdws[1].hdr_valid = 1'b0;
          qdws[1].dllp_err  = 1'b0;
          qdws[1].data_prot = DEF_PROT_4DW;

          nts.nw            = 2'd1;
          nts.data          = {64'b0,data[3*32 +: 1*32]};
          nts.sot           = 1'b1;
          nts.eot           = 1'b0;
          nts_hdr_info      = get_hdr_info (3'd3, 3'd1, 1'b0, ca_h_info);
          nts.has_pfx       = tlp_pfx[3];
          nts.hdr_valid     = get_hdr_valid (3'd3, 3'd1, 1'b0, ca_h_val);
          nts.dllp_err      = 1'b0;
          nts.data_prot     = {DEF_PROT_2DW,data_prot[3*DW_PROT_WD +: 1*DW_PROT_WD]};
          chk_nts.status    = ONGOING;
        end

      pts.status==NOTHING && tlp_idl[0] && tlp_idl[1] && tlp_idl[2] && tlp_sot[3] && !tlp_idl[4] && !tlp_eot[4] :
        begin
          dec_case          = d_s_i_i_i;
          qdws[0].valid     = pts.eot ? 1'b1 : 1'b0;
          qdws[0].data      = pts.eot ? {32'b0,pts.data} : 128'b0;
          qdws[0].dwen      = pts.eot ? dwen_dec(pts.nw) : 4'b0000;
          qdws[0].sot       = pts.eot ? pts.sot : 1'b0;
          qdws[0].eot       = pts.eot ? 1'b1 : 1'b0;
          qdw0_hdr_info     = pts.eot ? pts_hdr_info : DEFAULT_HDR_INFO;
          qdws[0].has_pfx   = pts.eot ? pts.has_pfx : 1'b0;
          qdws[0].hdr_valid = pts.eot ? pts.hdr_valid : 1'b0;
          qdws[0].dllp_err  = pts.eot ? pts.dllp_err : 1'b0;
          qdws[0].data_prot = pts.eot ? {DEF_PROT_1DW,pts.data_prot} : DEF_PROT_4DW;

          qdws[1].valid     = 1'b0;
          qdws[1].data      = 128'b0;
          qdws[1].dwen      = 4'b0000;
          qdws[1].sot       = 1'b0;
          qdws[1].eot       = 1'b0;
          qdw1_hdr_info     = DEFAULT_HDR_INFO;
          qdws[1].has_pfx   = 1'b0;
          qdws[1].hdr_valid = 1'b0;
          qdws[1].dllp_err  = 1'b0;
          qdws[1].data_prot = DEF_PROT_4DW;

          nts.nw            = 2'd2;
          nts.data          = {32'b0,data[3*32 +: 2*32]};
          nts.sot           = 1'b1;
          nts.eot           = 1'b0;
          nts_hdr_info      = get_hdr_info (3'd3, 3'd2, 1'b0, ca_h_info);
          nts.has_pfx       = tlp_pfx[3];
          nts.hdr_valid     = get_hdr_valid (3'd3, 3'd2, 1'b0, ca_h_val);
          nts.dllp_err      = 1'b0;
          nts.data_prot     = {DEF_PROT_1DW,data_prot[3*DW_PROT_WD +: 2*DW_PROT_WD]};
          chk_nts.status    = ONGOING;
        end

      pts.status==NOTHING && tlp_idl[0] && tlp_idl[1] && tlp_sot[2] && tlp_idl[3] && tlp_idl[4] :
        begin
          dec_case          = i_i_s_i_i;
          qdws[0].valid     = pts.eot ? 1'b1 : 1'b0;
          qdws[0].data      = pts.eot ? {32'b0,pts.data} : 128'b0;
          qdws[0].dwen      = pts.eot ? dwen_dec(pts.nw) : 4'b0000;
          qdws[0].sot       = pts.eot ? pts.sot : 1'b0;
          qdws[0].eot       = pts.eot ? 1'b1 : 1'b0;
          qdw0_hdr_info     = pts.eot ? pts_hdr_info : DEFAULT_HDR_INFO;
          qdws[0].has_pfx   = pts.eot ? pts.has_pfx : 1'b0;
          qdws[0].hdr_valid = pts.eot ? pts.hdr_valid : 1'b0;
          qdws[0].dllp_err  = pts.eot ? pts.dllp_err : 1'b0;
          qdws[0].data_prot = pts.eot ? {DEF_PROT_1DW,pts.data_prot} : DEF_PROT_4DW;

          qdws[1].valid     = 1'b0;
          qdws[1].data      = 128'b0;
          qdws[1].dwen      = 4'b0000;
          qdws[1].sot       = 1'b0;
          qdws[1].eot       = 1'b0;
          qdw1_hdr_info     = DEFAULT_HDR_INFO;
          qdws[1].has_pfx   = 1'b0;
          qdws[1].hdr_valid = 1'b0;
          qdws[1].dllp_err  = 1'b0;
          qdws[1].data_prot = DEF_PROT_4DW;

          nts.nw            = 2'd1;
          nts.data          = {64'b0,data[2*32 +: 1*32]};
          nts.sot           = 1'b1;
          nts.eot           = 1'b0;
          nts_hdr_info      = get_hdr_info (3'd2, 3'd1, 1'b0, ca_h_info);
          nts.has_pfx       = tlp_pfx[2];
          nts.hdr_valid     = get_hdr_valid (3'd2, 3'd1, 1'b0, ca_h_val);
          nts.dllp_err      = 1'b0;
          nts.data_prot     = {DEF_PROT_2DW,data_prot[2*DW_PROT_WD +: 1*DW_PROT_WD]};
          chk_nts.status    = ONGOING;
        end

      pts.status==NOTHING && tlp_idl[0] && tlp_idl[1] && tlp_sot[2] && !tlp_idl[3] && !tlp_eot[3] && tlp_idl[4] :
        begin
          dec_case          = i_d_s_i_i;
          qdws[0].valid     = pts.eot ? 1'b1 : 1'b0;
          qdws[0].data      = pts.eot ? {32'b0,pts.data} : 128'b0;
          qdws[0].dwen      = pts.eot ? dwen_dec(pts.nw) : 4'b0000;
          qdws[0].sot       = pts.eot ? pts.sot : 1'b0;
          qdws[0].eot       = pts.eot ? 1'b1 : 1'b0;
          qdw0_hdr_info     = pts.eot ? pts_hdr_info : DEFAULT_HDR_INFO;
          qdws[0].has_pfx   = pts.eot ? pts.has_pfx : 1'b0;
          qdws[0].hdr_valid = pts.eot ? pts.hdr_valid : 1'b0;
          qdws[0].dllp_err  = pts.eot ? pts.dllp_err : 1'b0;
          qdws[0].data_prot = pts.eot ? {DEF_PROT_1DW,pts.data_prot} : DEF_PROT_4DW;

          qdws[1].valid     = 1'b0;
          qdws[1].data      = 128'b0;
          qdws[1].dwen      = 4'b0000;
          qdws[1].sot       = 1'b0;
          qdws[1].eot       = 1'b0;
          qdw1_hdr_info     = DEFAULT_HDR_INFO;
          qdws[1].has_pfx   = 1'b0;
          qdws[1].hdr_valid = 1'b0;
          qdws[1].dllp_err  = 1'b0;
          qdws[1].data_prot = DEF_PROT_4DW;

          nts.nw            = 2'd2;
          nts.data          = {32'b0,data[2*32 +: 2*32]};
          nts.sot           = 1'b1;
          nts.eot           = 1'b0;
          nts_hdr_info      = get_hdr_info (3'd2, 3'd2, 1'b0, ca_h_info);
          nts.has_pfx       = tlp_pfx[2];
          nts.hdr_valid     = get_hdr_valid (3'd2, 3'd2, 1'b0, ca_h_val);
          nts.dllp_err      = 1'b0;
          nts.data_prot     = {DEF_PROT_1DW,data_prot[2*DW_PROT_WD +: 2*DW_PROT_WD]};
          chk_nts.status    = ONGOING;
        end

      pts.status==NOTHING && tlp_idl[0] && tlp_idl[1] && tlp_sot[2] && !tlp_idl[3] && !tlp_eot[3] && tlp_eot[4] :
        begin
          dec_case          = e_d_s_i_i;
          qdws[0].valid     = 1'b1;
          qdws[0].data      = pts.eot ? {32'b0,pts.data} : {32'b0,data[2*32 +: 3*32]};
          qdws[0].dwen      = pts.eot ? dwen_dec(pts.nw) : 4'b0111;
          qdws[0].sot       = pts.eot ? pts.sot : 1'b1;
          qdws[0].eot       = 1'b1;
          qdw0_hdr_info     = pts.eot ? pts_hdr_info : get_hdr_info (3'd2, 3'd3, 1'b0, ca_h_info);
          qdws[0].has_pfx   = pts.eot ? pts.has_pfx : tlp_pfx[2];
          qdws[0].hdr_valid = pts.eot ? pts.hdr_valid : get_hdr_valid (3'd2, 3'd3, 1'b0, ca_h_val);
          qdws[0].dllp_err  = pts.eot ? pts.dllp_err : tlp_dllp_err[4];
          qdws[0].data_prot = pts.eot ? {DEF_PROT_1DW,pts.data_prot} : {DEF_PROT_1DW,data_prot[2*DW_PROT_WD +: 3*DW_PROT_WD]};

          qdws[1].valid     = pts.eot ? 1'b1 : 1'b0;
          qdws[1].data      = pts.eot ? {32'b0,data[2*32 +: 3*32]} : 128'b0;
          qdws[1].dwen      = pts.eot ? 4'b0111 : 4'b0000;
          qdws[1].sot       = pts.eot ? 1'b1 : 1'b0;
          qdws[1].eot       = pts.eot ? 1'b1 : 1'b0;
          qdw1_hdr_info     = pts.eot ? get_hdr_info (3'd2, 3'd3, 1'b0, ca_h_info) : DEFAULT_HDR_INFO;
          qdws[1].has_pfx   = pts.eot ? tlp_pfx[2] : 1'b0;
          qdws[1].hdr_valid = pts.eot ? get_hdr_valid (3'd2, 3'd3, 1'b0, ca_h_val) : 1'b0;
          qdws[1].dllp_err  = pts.eot ? tlp_dllp_err[4] : 1'b0;
          qdws[1].data_prot = pts.eot ? {DEF_PROT_1DW,data_prot[2*DW_PROT_WD +: 3*DW_PROT_WD]} : DEF_PROT_4DW;

          nts.nw            = 2'd0;
          nts.data          = 96'b0;
          nts.sot           = 1'b0;
          nts.eot           = 1'b0;
          nts_hdr_info      = DEFAULT_HDR_INFO;
          nts.has_pfx       = 1'b0;
          nts.hdr_valid     = 1'b0;
          nts.dllp_err      = 1'b0;
          nts.data_prot     = DEF_PROT_3DW;
          chk_nts.status    = NOTHING;
        end

      pts.status==NOTHING && tlp_idl[0] && tlp_idl[1] && tlp_sot[2] && !tlp_idl[3] && !tlp_eot[3] && !tlp_idl[4] && !tlp_eot[4] :
        begin
          dec_case          = d_d_s_i_i;
          qdws[0].valid     = pts.eot ? 1'b1 : 1'b0;
          qdws[0].data      = pts.eot ? {32'b0,pts.data} : 128'b0;
          qdws[0].dwen      = pts.eot ? dwen_dec(pts.nw) : 4'b0000;
          qdws[0].sot       = pts.eot ? pts.sot : 1'b0;
          qdws[0].eot       = pts.eot ? 1'b1 : 1'b0;
          qdw0_hdr_info     = pts.eot ? pts_hdr_info : DEFAULT_HDR_INFO;
          qdws[0].has_pfx   = pts.eot ? pts.has_pfx : 1'b0;
          qdws[0].hdr_valid = pts.eot ? pts.hdr_valid : 1'b0;
          qdws[0].dllp_err  = pts.eot ? pts.dllp_err : 1'b0;
          qdws[0].data_prot = pts.eot ? {DEF_PROT_1DW,pts.data_prot} : DEF_PROT_4DW;

          qdws[1].valid     = 1'b0;
          qdws[1].data      = 128'b0;
          qdws[1].dwen      = 4'b0000;
          qdws[1].sot       = 1'b0;
          qdws[1].eot       = 1'b0;
          qdw1_hdr_info     = DEFAULT_HDR_INFO;
          qdws[1].has_pfx   = 1'b0;
          qdws[1].hdr_valid = 1'b0;
          qdws[1].dllp_err  = 1'b0;
          qdws[1].data_prot = DEF_PROT_4DW;

          nts.nw            = 2'd3;
          nts.data          = data[2*32 +: 3*32];
          nts.sot           = 1'b1;
          nts.eot           = 1'b0;
          nts_hdr_info      = get_hdr_info (3'd2, 3'd3, 1'b0, ca_h_info);
          nts.has_pfx       = tlp_pfx[2];
          nts.hdr_valid     = get_hdr_valid (3'd2, 3'd3, 1'b0, ca_h_val);
          nts.dllp_err      = 1'b0;
          nts.data_prot     = data_prot[2*DW_PROT_WD +: 3*DW_PROT_WD];
          chk_nts.status    = ONGOING;
        end

      pts.status==NOTHING && tlp_idl[0] && tlp_sot[1] && tlp_idl[2] && tlp_idl[3] && tlp_idl[4] :
        begin
          dec_case          = i_i_i_s_i;
          qdws[0].valid     = pts.eot ? 1'b1 : 1'b0;
          qdws[0].data      = pts.eot ? {32'b0,pts.data} : 128'b0;
          qdws[0].dwen      = pts.eot ? dwen_dec(pts.nw) : 4'b0000;
          qdws[0].sot       = pts.eot ? pts.sot : 1'b0;
          qdws[0].eot       = pts.eot ? 1'b1 : 1'b0;
          qdw0_hdr_info     = pts.eot ? pts_hdr_info : DEFAULT_HDR_INFO;
          qdws[0].has_pfx   = pts.eot ? pts.has_pfx : 1'b0;
          qdws[0].hdr_valid = pts.eot ? pts.hdr_valid : 1'b0;
          qdws[0].dllp_err  = pts.eot ? pts.dllp_err : 1'b0;
          qdws[0].data_prot = pts.eot ? {DEF_PROT_1DW,pts.data_prot} : DEF_PROT_4DW;

          qdws[1].valid     = 1'b0;
          qdws[1].data      = 128'b0;
          qdws[1].dwen      = 4'b0000;
          qdws[1].sot       = 1'b0;
          qdws[1].eot       = 1'b0;
          qdw1_hdr_info     = DEFAULT_HDR_INFO;
          qdws[1].has_pfx   = 1'b0;
          qdws[1].hdr_valid = 1'b0;
          qdws[1].dllp_err  = 1'b0;
          qdws[1].data_prot = DEF_PROT_4DW;

          nts.nw            = 2'd1;
          nts.data          = {64'b0,data[1*32 +: 1*32]};
          nts.sot           = 1'b1;
          nts.eot           = 1'b0;
          nts_hdr_info      = get_hdr_info (3'd1, 3'd1, 1'b0, ca_h_info);
          nts.has_pfx       = tlp_pfx[1];
          nts.hdr_valid     = get_hdr_valid (3'd1, 3'd1, 1'b0, ca_h_val);
          nts.dllp_err      = 1'b0;
          nts.data_prot     = {DEF_PROT_2DW,data_prot[1*DW_PROT_WD +: 1*DW_PROT_WD]};
          chk_nts.status    = ONGOING;
        end

      pts.status==NOTHING && tlp_idl[0] && tlp_sot[1] && !tlp_idl[2] && !tlp_eot[2] && tlp_idl[3] && tlp_idl[4] :
        begin
          dec_case          = i_i_d_s_i;
          qdws[0].valid     = pts.eot ? 1'b1 : 1'b0;
          qdws[0].data      = pts.eot ? {32'b0,pts.data} : 128'b0;
          qdws[0].dwen      = pts.eot ? dwen_dec(pts.nw) : 4'b0000;
          qdws[0].sot       = pts.eot ? pts.sot : 1'b0;
          qdws[0].eot       = pts.eot ? 1'b1 : 1'b0;
          qdw0_hdr_info     = pts.eot ? pts_hdr_info : DEFAULT_HDR_INFO;
          qdws[0].has_pfx   = pts.eot ? pts.has_pfx : 1'b0;
          qdws[0].hdr_valid = pts.eot ? pts.hdr_valid : 1'b0;
          qdws[0].dllp_err  = pts.eot ? pts.dllp_err : 1'b0;
          qdws[0].data_prot = pts.eot ? {DEF_PROT_1DW,pts.data_prot} : DEF_PROT_4DW;

          qdws[1].valid     = 1'b0;
          qdws[1].data      = 128'b0;
          qdws[1].dwen      = 4'b0000;
          qdws[1].sot       = 1'b0;
          qdws[1].eot       = 1'b0;
          qdw1_hdr_info     = DEFAULT_HDR_INFO;
          qdws[1].has_pfx   = 1'b0;
          qdws[1].hdr_valid = 1'b0;
          qdws[1].dllp_err  = 1'b0;
          qdws[1].data_prot = DEF_PROT_4DW;

          nts.nw            = 2'd2;
          nts.data          = {32'b0,data[1*32 +: 2*32]};
          nts.sot           = 1'b1;
          nts.eot           = 1'b0;
          nts_hdr_info      = get_hdr_info (3'd1, 3'd2, 1'b0, ca_h_info);
          nts.has_pfx       = tlp_pfx[1];
          nts.hdr_valid     = get_hdr_valid (3'd1, 3'd2, 1'b0, ca_h_val);
          nts.dllp_err      = 1'b0;
          nts.data_prot     = {DEF_PROT_1DW,data_prot[1*DW_PROT_WD +: 2*DW_PROT_WD]};
          chk_nts.status    = ONGOING;
        end

      pts.status==NOTHING && tlp_idl[0] && tlp_sot[1] && !tlp_idl[2] && !tlp_eot[2] && tlp_eot[3] && tlp_idl[4] :
        begin
          dec_case          = i_e_d_s_i;
          qdws[0].valid     = 1'b1;
          qdws[0].data      = pts.eot ? {32'b0,pts.data} : {32'b0,data[1*32 +: 3*32]};
          qdws[0].dwen      = pts.eot ? dwen_dec(pts.nw) : 4'b0111;
          qdws[0].sot       = pts.eot ? pts.sot : 1'b1;
          qdws[0].eot       = 1'b1;
          qdw0_hdr_info     = pts.eot ? pts_hdr_info : get_hdr_info (3'd1, 3'd3, 1'b0, ca_h_info);
          qdws[0].has_pfx   = pts.eot ? pts.has_pfx : tlp_pfx[1];
          qdws[0].hdr_valid = pts.eot ? pts.hdr_valid : get_hdr_valid (3'd1, 3'd3, 1'b0, ca_h_val);
          qdws[0].dllp_err  = pts.eot ? pts.dllp_err : tlp_dllp_err[3];
          qdws[0].data_prot = pts.eot ? {DEF_PROT_1DW,pts.data_prot} : {DEF_PROT_1DW,data_prot[1*DW_PROT_WD +: 3*DW_PROT_WD]};

          qdws[1].valid     = pts.eot ? 1'b1 : 1'b0;
          qdws[1].data      = pts.eot ? {32'b0,data[1*32 +: 3*32]} : 128'b0;
          qdws[1].dwen      = pts.eot ? 4'b0111 : 4'b0000;
          qdws[1].sot       = pts.eot ? 1'b1 : 1'b0;
          qdws[1].eot       = pts.eot ? 1'b1 : 1'b0;
          qdw1_hdr_info     = pts.eot ? get_hdr_info (3'd1, 3'd3, 1'b0, ca_h_info) : DEFAULT_HDR_INFO;
          qdws[1].has_pfx   = pts.eot ? tlp_pfx[1] : 1'b0;
          qdws[1].hdr_valid = pts.eot ? get_hdr_valid (3'd1, 3'd3, 1'b0, ca_h_val) : 1'b0;
          qdws[1].dllp_err  = pts.eot ? tlp_dllp_err[3] : 1'b0;
          qdws[1].data_prot = pts.eot ? {DEF_PROT_1DW,data_prot[1*DW_PROT_WD +: 3*DW_PROT_WD]} : DEF_PROT_4DW;

          nts.nw            = 2'd0;
          nts.data          = 96'b0;
          nts.sot           = 1'b0;
          nts.eot           = 1'b0;
          nts_hdr_info      = DEFAULT_HDR_INFO;
          nts.has_pfx       = 1'b0;
          nts.hdr_valid     = 1'b0;
          nts.dllp_err      = 1'b0;
          nts.data_prot     = DEF_PROT_3DW;
          chk_nts.status    = NOTHING;
        end

      pts.status==NOTHING && tlp_idl[0] && tlp_sot[1] && !tlp_idl[2] && !tlp_eot[2] && tlp_eot[3] && tlp_sot[4] :
        begin
          dec_case          = s_e_d_s_i;
          qdws[0].valid     = 1'b1;
          qdws[0].data      = pts.eot ? {32'b0,pts.data} : {32'b0,data[1*32 +: 3*32]};
          qdws[0].dwen      = pts.eot ? dwen_dec(pts.nw) : 4'b0111;
          qdws[0].sot       = pts.eot ? pts.sot : 1'b1;
          qdws[0].eot       = 1'b1;
          qdw0_hdr_info     = pts.eot ? pts_hdr_info : get_hdr_info (3'd1, 3'd3, 1'b0, ca_h_info);
          qdws[0].has_pfx   = pts.eot ? pts.has_pfx : tlp_pfx[1];
          qdws[0].hdr_valid = pts.eot ? pts.hdr_valid : get_hdr_valid (3'd1, 3'd3, 1'b0, ca_h_val);
          qdws[0].dllp_err  = pts.eot ? pts.dllp_err : tlp_dllp_err[3];
          qdws[0].data_prot = pts.eot ? {DEF_PROT_1DW,pts.data_prot} : {DEF_PROT_1DW,data_prot[1*DW_PROT_WD +: 3*DW_PROT_WD]};

          qdws[1].valid     = pts.eot ? 1'b1 : 1'b0;
          qdws[1].data      = pts.eot ? {32'b0,data[1*32 +: 3*32]} : 128'b0;
          qdws[1].dwen      = pts.eot ? 4'b0111 : 4'b0000;
          qdws[1].sot       = pts.eot ? 1'b1 : 1'b0;
          qdws[1].eot       = pts.eot ? 1'b1 : 1'b0;
          qdw1_hdr_info     = pts.eot ? get_hdr_info (3'd1, 3'd3, 1'b0, ca_h_info) : DEFAULT_HDR_INFO;
          qdws[1].has_pfx   = pts.eot ? tlp_pfx[1] : 1'b0;
          qdws[1].hdr_valid = pts.eot ? get_hdr_valid (3'd1, 3'd3, 1'b0, ca_h_val) : 1'b0;
          qdws[1].dllp_err  = pts.eot ? tlp_dllp_err[3] : 1'b0;
          qdws[1].data_prot = pts.eot ? {DEF_PROT_1DW,data_prot[1*DW_PROT_WD +: 3*DW_PROT_WD]} : DEF_PROT_4DW;

          nts.nw            = 2'd1;
          nts.data          = {64'b0,data[4*32 +: 1*32]};
          nts.sot           = 1'b1;
          nts.eot           = 1'b0;
          nts_hdr_info      = get_hdr_info (3'd4, 3'd1, 1'b0, ca_h_info);
          nts.has_pfx       = tlp_pfx[4];
          nts.hdr_valid     = get_hdr_valid (3'd4, 3'd1, 1'b0, ca_h_val);
          nts.dllp_err      = 1'b0;
          nts.data_prot     = {DEF_PROT_2DW,data_prot[4*DW_PROT_WD +: 1*DW_PROT_WD]};
          chk_nts.status    = ONGOING;
        end

      pts.status==NOTHING && tlp_idl[0] && tlp_sot[1] && !tlp_idl[2] && !tlp_eot[2] && !tlp_idl[3] && !tlp_eot[3] && tlp_idl[4] :
        begin
          dec_case          = i_d_d_s_i;
          qdws[0].valid     = pts.eot ? 1'b1 : 1'b0;
          qdws[0].data      = pts.eot ? {32'b0,pts.data} : 128'b0;
          qdws[0].dwen      = pts.eot ? dwen_dec(pts.nw) : 4'b0000;
          qdws[0].sot       = pts.eot ? pts.sot : 1'b0;
          qdws[0].eot       = pts.eot ? 1'b1 : 1'b0;
          qdw0_hdr_info     = pts.eot ? pts_hdr_info : DEFAULT_HDR_INFO;
          qdws[0].has_pfx   = pts.eot ? pts.has_pfx : 1'b0;
          qdws[0].hdr_valid = pts.eot ? pts.hdr_valid : 1'b0;
          qdws[0].dllp_err  = pts.eot ? pts.dllp_err : 1'b0;
          qdws[0].data_prot = pts.eot ? {DEF_PROT_1DW,pts.data_prot} : DEF_PROT_4DW;

          qdws[1].valid     = 1'b0;
          qdws[1].data      = 128'b0;
          qdws[1].dwen      = 4'b0000;
          qdws[1].sot       = 1'b0;
          qdws[1].eot       = 1'b0;
          qdw1_hdr_info     = DEFAULT_HDR_INFO;
          qdws[1].has_pfx   = 1'b0;
          qdws[1].hdr_valid = 1'b0;
          qdws[1].dllp_err  = 1'b0;
          qdws[1].data_prot = DEF_PROT_4DW;

          nts.nw            = 2'd3;
          nts.data          = data[1*32 +: 3*32];
          nts.sot           = 1'b1;
          nts.eot           = 1'b0;
          nts_hdr_info      = get_hdr_info (3'd1, 3'd3, 1'b0, ca_h_info);
          nts.has_pfx       = tlp_pfx[1];
          nts.hdr_valid     = get_hdr_valid (3'd1, 3'd3, 1'b0, ca_h_val);
          nts.dllp_err      = 1'b0;
          nts.data_prot     = data_prot[1*DW_PROT_WD +: 3*DW_PROT_WD];
          chk_nts.status    = ONGOING;
        end

      pts.status==NOTHING && tlp_idl[0] && tlp_sot[1] && !tlp_idl[2] && !tlp_eot[2] && !tlp_idl[3] && !tlp_eot[3] && tlp_eot[4] :
        begin
          dec_case          = e_d_d_s_i;
          qdws[0].valid     = 1'b1;
          qdws[0].data      = pts.eot ? {32'b0,pts.data} : data[1*32 +: 4*32];
          qdws[0].dwen      = pts.eot ? dwen_dec(pts.nw) : 4'b1111;
          qdws[0].sot       = pts.eot ? pts.sot : 1'b1;
          qdws[0].eot       = 1'b1;
          qdw0_hdr_info     = pts.eot ? pts_hdr_info : get_hdr_info (3'd1, 3'd4, 1'b0, ca_h_info);
          qdws[0].has_pfx   = pts.eot ? pts.has_pfx : tlp_pfx[1];
          qdws[0].hdr_valid = pts.eot ? pts.hdr_valid : get_hdr_valid (3'd1, 3'd4, 1'b0, ca_h_val);
          qdws[0].dllp_err  = pts.eot ? pts.dllp_err : tlp_dllp_err[4];
          qdws[0].data_prot = pts.eot ? {DEF_PROT_1DW,pts.data_prot} : data_prot[1*DW_PROT_WD +: 4*DW_PROT_WD];

          qdws[1].valid     = pts.eot ? 1'b1 : 1'b0;
          qdws[1].data      = pts.eot ? data[1*32 +: 4*32] : 128'b0;
          qdws[1].dwen      = pts.eot ? 4'b1111 : 4'b0000;
          qdws[1].sot       = pts.eot ? 1'b1 : 1'b0;
          qdws[1].eot       = pts.eot ? 1'b1 : 1'b0;
          qdw1_hdr_info     = pts.eot ? get_hdr_info (3'd1, 3'd4, 1'b0, ca_h_info) : DEFAULT_HDR_INFO;
          qdws[1].has_pfx   = pts.eot ? tlp_pfx[1] : 1'b0;
          qdws[1].hdr_valid = pts.eot ? get_hdr_valid (3'd1, 3'd4, 1'b0, ca_h_val) : 1'b0;
          qdws[1].dllp_err  = pts.eot ? tlp_dllp_err[4] : 1'b0;
          qdws[1].data_prot = pts.eot ? data_prot[1*DW_PROT_WD +: 4*DW_PROT_WD] : DEF_PROT_4DW;

          nts.nw            = 2'd0;
          nts.data          = 96'b0;
          nts.sot           = 1'b0;
          nts.eot           = 1'b0;
          nts_hdr_info      = DEFAULT_HDR_INFO;
          nts.has_pfx       = 1'b0;
          nts.hdr_valid     = 1'b0;
          nts.dllp_err      = 1'b0;
          nts.data_prot     = DEF_PROT_3DW;
          chk_nts.status    = NOTHING;
        end

      pts.status==NOTHING && tlp_idl[0] && tlp_sot[1] && !tlp_idl[2] && !tlp_eot[2] && !tlp_idl[3] && !tlp_eot[3] && !tlp_idl[4] && !tlp_eot[4] :
        begin
          dec_case          = d_d_d_s_i;
          qdws[0].valid     = 1'b1;
          qdws[0].data      = pts.eot ? {32'b0,pts.data} : data[1*32 +: 4*32];
          qdws[0].dwen      = pts.eot ? dwen_dec(pts.nw) : 4'b1111;
          qdws[0].sot       = pts.eot ? pts.sot : 1'b1;
          qdws[0].eot       = pts.eot ? 1'b1 : 1'b0;
          qdw0_hdr_info     = pts.eot ? pts_hdr_info : get_hdr_info (3'd1, 3'd4, 1'b0, ca_h_info);
          qdws[0].has_pfx   = pts.eot ? pts.has_pfx : tlp_pfx[1];
          qdws[0].hdr_valid = pts.eot ? pts.hdr_valid : get_hdr_valid (3'd1, 3'd4, 1'b0, ca_h_val);
          qdws[0].dllp_err  = pts.eot ? pts.dllp_err : 1'b0;
          qdws[0].data_prot = pts.eot ? {DEF_PROT_1DW,pts.data_prot} : data_prot[1*DW_PROT_WD +: 4*DW_PROT_WD];

          qdws[1].valid     = pts.eot ? 1'b1 : 1'b0;
          qdws[1].data      = pts.eot ? data[1*32 +: 4*32] : 128'b0;
          qdws[1].dwen      = pts.eot ? 4'b1111 : 4'b0000;
          qdws[1].sot       = pts.eot ? 1'b1 : 1'b0;
          qdws[1].eot       = 1'b0;
          qdw1_hdr_info     = pts.eot ? get_hdr_info (3'd1, 3'd4, 1'b0, ca_h_info) : DEFAULT_HDR_INFO;
          qdws[1].has_pfx   = pts.eot ? tlp_pfx[1] : 1'b0;
          qdws[1].hdr_valid = pts.eot ? get_hdr_valid (3'd1, 3'd4, 1'b0, ca_h_val) : 1'b0;
          qdws[1].dllp_err  = 1'b0;
          qdws[1].data_prot = pts.eot ? data_prot[1*DW_PROT_WD +: 4*DW_PROT_WD] : DEF_PROT_4DW;

          nts.nw            = 2'd0;
          nts.data          = 96'b0;
          nts.sot           = 1'b0;
          nts.eot           = 1'b0;
          nts_hdr_info      = get_hdr_info (3'd1, 3'd4, 1'b0, ca_h_info);
          nts.has_pfx       = tlp_pfx[1];
          nts.hdr_valid     = 1'b0;
          nts.dllp_err      = 1'b0;
          nts.data_prot     = DEF_PROT_3DW;
          chk_nts.status    = ONGOING;
        end

      pts.status==NOTHING && tlp_sot[0] && tlp_idl[1] && tlp_idl[2] && tlp_idl[3] && tlp_idl[4] :
        begin
          dec_case          = i_i_i_i_s;
          qdws[0].valid     = pts.eot ? 1'b1 : 1'b0;
          qdws[0].data      = pts.eot ? {32'b0,pts.data} : 128'b0;
          qdws[0].dwen      = pts.eot ? dwen_dec(pts.nw) : 4'b0000;
          qdws[0].sot       = pts.eot ? pts.sot : 1'b0;
          qdws[0].eot       = pts.eot ? 1'b1 : 1'b0;
          qdw0_hdr_info     = pts.eot ? pts_hdr_info : DEFAULT_HDR_INFO;
          qdws[0].has_pfx   = pts.eot ? pts.has_pfx : 1'b0;
          qdws[0].hdr_valid = pts.eot ? pts.hdr_valid : 1'b0;
          qdws[0].dllp_err  = pts.eot ? pts.dllp_err : 1'b0;
          qdws[0].data_prot = pts.eot ? {DEF_PROT_1DW,pts.data_prot} : DEF_PROT_4DW;

          qdws[1].valid     = 1'b0;
          qdws[1].data      = 128'b0;
          qdws[1].dwen      = 4'b0000;
          qdws[1].sot       = 1'b0;
          qdws[1].eot       = 1'b0;
          qdw1_hdr_info     = DEFAULT_HDR_INFO;
          qdws[1].has_pfx   = 1'b0;
          qdws[1].hdr_valid = 1'b0;
          qdws[1].dllp_err  = 1'b0;
          qdws[1].data_prot = DEF_PROT_4DW;

          nts.nw            = 2'd1;
          nts.data          = {64'b0,data[0*32 +: 1*32]};
          nts.sot           = 1'b1;
          nts.eot           = 1'b0;
          nts_hdr_info      = get_hdr_info (3'd0, 3'd1, 1'b0, ca_h_info);
          nts.has_pfx       = tlp_pfx[0];
          nts.hdr_valid     = get_hdr_valid (3'd0, 3'd1, 1'b0, ca_h_val);
          nts.dllp_err      = 1'b0;
          nts.data_prot     = {DEF_PROT_2DW,data_prot[0*DW_PROT_WD +: 1*DW_PROT_WD]};
          chk_nts.status    = ONGOING;
        end

      pts.status==NOTHING && tlp_sot[0] && !tlp_idl[1] && !tlp_eot[1] && tlp_idl[2] && tlp_idl[3] && tlp_idl[4] :
        begin
          dec_case          = i_i_i_d_s;
          qdws[0].valid     = pts.eot ? 1'b1 : 1'b0;
          qdws[0].data      = pts.eot ? {32'b0,pts.data} : 128'b0;
          qdws[0].dwen      = pts.eot ? dwen_dec(pts.nw) : 4'b0000;
          qdws[0].sot       = pts.eot ? pts.sot : 1'b0;
          qdws[0].eot       = pts.eot ? 1'b1 : 1'b0;
          qdw0_hdr_info     = pts.eot ? pts_hdr_info : DEFAULT_HDR_INFO;
          qdws[0].has_pfx   = pts.eot ? pts.has_pfx : 1'b0;
          qdws[0].hdr_valid = pts.eot ? pts.hdr_valid : 1'b0;
          qdws[0].dllp_err  = pts.eot ? pts.dllp_err : 1'b0;
          qdws[0].data_prot = pts.eot ? {DEF_PROT_1DW,pts.data_prot} : DEF_PROT_4DW;

          qdws[1].valid     = 1'b0;
          qdws[1].data      = 128'b0;
          qdws[1].dwen      = 4'b0000;
          qdws[1].sot       = 1'b0;
          qdws[1].eot       = 1'b0;
          qdw1_hdr_info     = DEFAULT_HDR_INFO;
          qdws[1].has_pfx   = 1'b0;
          qdws[1].hdr_valid = 1'b0;
          qdws[1].dllp_err  = 1'b0;
          qdws[1].data_prot = DEF_PROT_4DW;

          nts.nw            = 2'd2;
          nts.data          = {32'b0,data[0*32 +: 2*32]};
          nts.sot           = 1'b1;
          nts.eot           = 1'b0;
          nts_hdr_info      = get_hdr_info (3'd0, 3'd2, 1'b0, ca_h_info);
          nts.has_pfx       = tlp_pfx[0];
          nts.hdr_valid     = get_hdr_valid (3'd0, 3'd2, 1'b0, ca_h_val);
          nts.dllp_err      = 1'b0;
          nts.data_prot     = {DEF_PROT_1DW,data_prot[0*DW_PROT_WD +: 2*DW_PROT_WD]};
          chk_nts.status    = ONGOING;
        end

      pts.status==NOTHING && tlp_sot[0] && !tlp_idl[1] && !tlp_eot[1] && tlp_eot[2] && tlp_idl[3] && tlp_idl[4] :
        begin
          dec_case          = i_i_e_d_s;
          qdws[0].valid     = 1'b1;
          qdws[0].data      = pts.eot ? {32'b0,pts.data} : {32'b0,data[0*32 +: 3*32]};
          qdws[0].dwen      = pts.eot ? dwen_dec(pts.nw) : 4'b0111;
          qdws[0].sot       = pts.eot ? pts.sot : 1'b1;
          qdws[0].eot       = 1'b1;
          qdw0_hdr_info     = pts.eot ? pts_hdr_info : get_hdr_info (3'd0, 3'd3, 1'b0, ca_h_info);
          qdws[0].has_pfx   = pts.eot ? pts.has_pfx : tlp_pfx[0];
          qdws[0].hdr_valid = pts.eot ? pts.hdr_valid : get_hdr_valid (3'd0, 3'd3, 1'b0, ca_h_val);
          qdws[0].dllp_err  = pts.eot ? pts.dllp_err : tlp_dllp_err[2];
          qdws[0].data_prot = pts.eot ? {DEF_PROT_1DW,pts.data_prot} : {DEF_PROT_1DW,data_prot[0*DW_PROT_WD +: 3*DW_PROT_WD]};

          qdws[1].valid     = pts.eot ? 1'b1 : 1'b0;
          qdws[1].data      = pts.eot ? {32'b0,data[0*32 +: 3*32]} : 128'b0;
          qdws[1].dwen      = pts.eot ? 4'b0111 : 4'b0000;
          qdws[1].sot       = pts.eot ? 1'b1 : 1'b0;
          qdws[1].eot       = pts.eot ? 1'b1 : 1'b0;
          qdw1_hdr_info     = pts.eot ? get_hdr_info (3'd0, 3'd3, 1'b0, ca_h_info) : DEFAULT_HDR_INFO;
          qdws[1].has_pfx   = pts.eot ? tlp_pfx[0] : 1'b0;
          qdws[1].hdr_valid = pts.eot ? get_hdr_valid (3'd0, 3'd3, 1'b0, ca_h_val) : 1'b0;
          qdws[1].dllp_err  = pts.eot ? tlp_dllp_err[2] : 1'b0;
          qdws[1].data_prot = pts.eot ? {DEF_PROT_1DW,data_prot[0*DW_PROT_WD +: 3*DW_PROT_WD]} : DEF_PROT_4DW;

          nts.nw            = 2'd0;
          nts.data          = 96'b0;
          nts.sot           = 1'b0;
          nts.eot           = 1'b0;
          nts_hdr_info      = DEFAULT_HDR_INFO;
          nts.has_pfx       = 1'b0;
          nts.hdr_valid     = 1'b0;
          nts.dllp_err      = 1'b0;
          nts.data_prot     = DEF_PROT_3DW;
          chk_nts.status    = NOTHING;
        end

      pts.status==NOTHING && tlp_sot[0] && !tlp_idl[1] && !tlp_eot[1] && tlp_eot[2] && tlp_idl[3] && tlp_sot[4] :
        begin
          dec_case          = s_i_e_d_s;
          qdws[0].valid     = 1'b1;
          qdws[0].data      = pts.eot ? {32'b0,pts.data} : {32'b0,data[0*32 +: 3*32]};
          qdws[0].dwen      = pts.eot ? dwen_dec(pts.nw) : 4'b0111;
          qdws[0].sot       = pts.eot ? pts.sot : 1'b1;
          qdws[0].eot       = 1'b1;
          qdw0_hdr_info     = pts.eot ? pts_hdr_info : get_hdr_info (3'd0, 3'd3, 1'b0, ca_h_info);
          qdws[0].has_pfx   = pts.eot ? pts.has_pfx : tlp_pfx[0];
          qdws[0].hdr_valid = pts.eot ? pts.hdr_valid : get_hdr_valid (3'd0, 3'd3, 1'b0, ca_h_val);
          qdws[0].dllp_err  = pts.eot ? pts.dllp_err : tlp_dllp_err[2];
          qdws[0].data_prot = pts.eot ? {DEF_PROT_1DW,pts.data_prot} : {DEF_PROT_1DW,data_prot[0*DW_PROT_WD +: 3*DW_PROT_WD]};

          qdws[1].valid     = pts.eot ? 1'b1 : 1'b0;
          qdws[1].data      = pts.eot ? {32'b0,data[0*32 +: 3*32]} : 128'b0;
          qdws[1].dwen      = pts.eot ? 4'b0111 : 4'b0000;
          qdws[1].sot       = pts.eot ? 1'b1 : 1'b0;
          qdws[1].eot       = pts.eot ? 1'b1 : 1'b0;
          qdw1_hdr_info     = pts.eot ? get_hdr_info (3'd0, 3'd3, 1'b0, ca_h_info) : DEFAULT_HDR_INFO;
          qdws[1].has_pfx   = pts.eot ? tlp_pfx[0] : 1'b0;
          qdws[1].hdr_valid = pts.eot ? get_hdr_valid (3'd0, 3'd3, 1'b0, ca_h_val) : 1'b0;
          qdws[1].dllp_err  = pts.eot ? tlp_dllp_err[2] : 1'b0;
          qdws[1].data_prot = pts.eot ? {DEF_PROT_1DW,data_prot[0*DW_PROT_WD +: 3*DW_PROT_WD]} : DEF_PROT_4DW;

          nts.nw            = 2'd1;
          nts.data          = {64'b0,data[4*32 +: 1*32]};
          nts.sot           = 1'b1;
          nts.eot           = 1'b0;
          nts_hdr_info      = get_hdr_info (3'd4, 3'd1, 1'b0, ca_h_info);
          nts.has_pfx       = tlp_pfx[4];
          nts.hdr_valid     = get_hdr_valid (3'd4, 3'd1, 1'b0, ca_h_val);
          nts.dllp_err      = 1'b0;
          nts.data_prot     = {DEF_PROT_2DW,data_prot[4*DW_PROT_WD +: 1*DW_PROT_WD]};
          chk_nts.status    = ONGOING;
        end

      pts.status==NOTHING && tlp_sot[0] && !tlp_idl[1] && !tlp_eot[1] && tlp_eot[2] && tlp_sot[3] && tlp_idl[4] :
        begin
          dec_case          = i_s_e_d_s;
          qdws[0].valid     = 1'b1;
          qdws[0].data      = pts.eot ? {32'b0,pts.data} : {32'b0,data[0*32 +: 3*32]};
          qdws[0].dwen      = pts.eot ? dwen_dec(pts.nw) : 4'b0111;
          qdws[0].sot       = pts.eot ? pts.sot : 1'b1;
          qdws[0].eot       = 1'b1;
          qdw0_hdr_info     = pts.eot ? pts_hdr_info : get_hdr_info (3'd0, 3'd3, 1'b0, ca_h_info);
          qdws[0].has_pfx   = pts.eot ? pts.has_pfx : tlp_pfx[0];
          qdws[0].hdr_valid = pts.eot ? pts.hdr_valid : get_hdr_valid (3'd0, 3'd3, 1'b0, ca_h_val);
          qdws[0].dllp_err  = pts.eot ? pts.dllp_err : tlp_dllp_err[2];
          qdws[0].data_prot = pts.eot ? {DEF_PROT_1DW,pts.data_prot} : {DEF_PROT_1DW,data_prot[0*DW_PROT_WD +: 3*DW_PROT_WD]};

          qdws[1].valid     = pts.eot ? 1'b1 : 1'b0;
          qdws[1].data      = pts.eot ? {32'b0,data[0*32 +: 3*32]} : 128'b0;
          qdws[1].dwen      = pts.eot ? 4'b0111 : 4'b0000;
          qdws[1].sot       = pts.eot ? 1'b1 : 1'b0;
          qdws[1].eot       = pts.eot ? 1'b1 : 1'b0;
          qdw1_hdr_info     = pts.eot ? get_hdr_info (3'd0, 3'd3, 1'b0, ca_h_info) : DEFAULT_HDR_INFO;
          qdws[1].has_pfx   = pts.eot ? tlp_pfx[0] : 1'b0;
          qdws[1].hdr_valid = pts.eot ? get_hdr_valid (3'd0, 3'd3, 1'b0, ca_h_val) : 1'b0;
          qdws[1].dllp_err  = pts.eot ? tlp_dllp_err[2] : 1'b0;
          qdws[1].data_prot = pts.eot ? {DEF_PROT_1DW,data_prot[0*DW_PROT_WD +: 3*DW_PROT_WD]} : DEF_PROT_4DW;

          nts.nw            = 2'd1;
          nts.data          = {64'b0,data[3*32 +: 1*32]};
          nts.sot           = 1'b1;
          nts.eot           = 1'b0;
          nts_hdr_info      = get_hdr_info (3'd3, 3'd1, 1'b0, ca_h_info);
          nts.has_pfx       = tlp_pfx[3];
          nts.hdr_valid     = get_hdr_valid (3'd3, 3'd1, 1'b0, ca_h_val);
          nts.dllp_err      = 1'b0;
          nts.data_prot     = {DEF_PROT_2DW,data_prot[3*DW_PROT_WD +: 1*DW_PROT_WD]};
          chk_nts.status    = ONGOING;
        end

      pts.status==NOTHING && tlp_sot[0] && !tlp_idl[1] && !tlp_eot[1] && tlp_eot[2] && tlp_sot[3] && !tlp_idl[4] && !tlp_eot[4] :
        begin
          dec_case          = d_s_e_d_s;
          qdws[0].valid     = 1'b1;
          qdws[0].data      = pts.eot ? {32'b0,pts.data} : {32'b0,data[0*32 +: 3*32]};
          qdws[0].dwen      = pts.eot ? dwen_dec(pts.nw) : 4'b0111;
          qdws[0].sot       = pts.eot ? pts.sot : 1'b1;
          qdws[0].eot       = 1'b1;
          qdw0_hdr_info     = pts.eot ? pts_hdr_info : get_hdr_info (3'd0, 3'd3, 1'b0, ca_h_info);
          qdws[0].has_pfx   = pts.eot ? pts.has_pfx : tlp_pfx[0];
          qdws[0].hdr_valid = pts.eot ? pts.hdr_valid : get_hdr_valid (3'd0, 3'd3, 1'b0, ca_h_val);
          qdws[0].dllp_err  = pts.eot ? pts.dllp_err : tlp_dllp_err[2];
          qdws[0].data_prot = pts.eot ? {DEF_PROT_1DW,pts.data_prot} : {DEF_PROT_1DW,data_prot[0*DW_PROT_WD +: 3*DW_PROT_WD]};

          qdws[1].valid     = pts.eot ? 1'b1 : 1'b0;
          qdws[1].data      = pts.eot ? {32'b0,data[0*32 +: 3*32]} : 128'b0;
          qdws[1].dwen      = pts.eot ? 4'b0111 : 4'b0000;
          qdws[1].sot       = pts.eot ? 1'b1 : 1'b0;
          qdws[1].eot       = pts.eot ? 1'b1 : 1'b0;
          qdw1_hdr_info     = pts.eot ? get_hdr_info (3'd0, 3'd3, 1'b0, ca_h_info) : DEFAULT_HDR_INFO;
          qdws[1].has_pfx   = pts.eot ? tlp_pfx[0] : 1'b0;
          qdws[1].hdr_valid = pts.eot ? get_hdr_valid (3'd0, 3'd3, 1'b0, ca_h_val) : 1'b0;
          qdws[1].dllp_err  = pts.eot ? tlp_dllp_err[2] : 1'b0;
          qdws[1].data_prot = pts.eot ? {DEF_PROT_1DW,data_prot[0*DW_PROT_WD +: 3*DW_PROT_WD]} : DEF_PROT_4DW;

          nts.nw            = 2'd2;
          nts.data          = {32'b0,data[3*32 +: 2*32]};
          nts.sot           = 1'b1;
          nts.eot           = 1'b0;
          nts_hdr_info      = get_hdr_info (3'd3, 3'd2, 1'b0, ca_h_info);
          nts.has_pfx       = tlp_pfx[3];
          nts.hdr_valid     = get_hdr_valid (3'd3, 3'd2, 1'b0, ca_h_val);
          nts.dllp_err      = 1'b0;
          nts.data_prot     = {DEF_PROT_1DW,data_prot[3*DW_PROT_WD +: 2*DW_PROT_WD]};
          chk_nts.status    = ONGOING;
        end

      pts.status==NOTHING && tlp_sot[0] && !tlp_idl[1] && !tlp_eot[1] && !tlp_idl[2] && !tlp_eot[2] && tlp_idl[3] && tlp_idl[4] :
        begin
          dec_case          = i_i_d_d_s;
          qdws[0].valid     = pts.eot ? 1'b1 : 1'b0;
          qdws[0].data      = pts.eot ? {32'b0,pts.data} : 128'b0;
          qdws[0].dwen      = pts.eot ? dwen_dec(pts.nw) : 4'b0000;
          qdws[0].sot       = pts.eot ? pts.sot : 1'b0;
          qdws[0].eot       = pts.eot ? 1'b1 : 1'b0;
          qdw0_hdr_info     = pts.eot ? pts_hdr_info : DEFAULT_HDR_INFO;
          qdws[0].has_pfx   = pts.eot ? pts.has_pfx : 1'b0;
          qdws[0].hdr_valid = pts.eot ? pts.hdr_valid : 1'b0;
          qdws[0].dllp_err  = pts.eot ? pts.dllp_err : 1'b0;
          qdws[0].data_prot = pts.eot ? {DEF_PROT_1DW,pts.data_prot} : DEF_PROT_4DW;

          qdws[1].valid     = 1'b0;
          qdws[1].data      = 128'b0;
          qdws[1].dwen      = 4'b0000;
          qdws[1].sot       = 1'b0;
          qdws[1].eot       = 1'b0;
          qdw1_hdr_info     = DEFAULT_HDR_INFO;
          qdws[1].has_pfx   = 1'b0;
          qdws[1].hdr_valid = 1'b0;
          qdws[1].dllp_err  = 1'b0;
          qdws[1].data_prot = DEF_PROT_4DW;

          nts.nw            = 2'd3;
          nts.data          = data[0*32 +: 3*32];
          nts.sot           = 1'b1;
          nts.eot           = 1'b0;
          nts_hdr_info      = get_hdr_info (3'd0, 3'd3, 1'b0, ca_h_info);
          nts.has_pfx       = tlp_pfx[0];
          nts.hdr_valid     = get_hdr_valid (3'd0, 3'd3, 1'b0, ca_h_val);
          nts.dllp_err      = 1'b0;
          nts.data_prot     = data_prot[0*DW_PROT_WD +: 3*DW_PROT_WD];
          chk_nts.status    = ONGOING;
        end

      pts.status==NOTHING && tlp_sot[0] && !tlp_idl[1] && !tlp_eot[1] && !tlp_idl[2] && !tlp_eot[2] && tlp_eot[3] && tlp_idl[4] :
        begin
          dec_case          = i_e_d_d_s;
          qdws[0].valid     = 1'b1;
          qdws[0].data      = pts.eot ? {32'b0,pts.data} : data[0*32 +: 4*32];
          qdws[0].dwen      = pts.eot ? dwen_dec(pts.nw) : 4'b1111;
          qdws[0].sot       = pts.eot ? pts.sot : 1'b1;
          qdws[0].eot       = 1'b1;
          qdw0_hdr_info     = pts.eot ? pts_hdr_info : get_hdr_info (3'd0, 3'd4, 1'b0, ca_h_info);
          qdws[0].has_pfx   = pts.eot ? pts.has_pfx : tlp_pfx[0];
          qdws[0].hdr_valid = pts.eot ? pts.hdr_valid : get_hdr_valid (3'd0, 3'd4, 1'b0, ca_h_val);
          qdws[0].dllp_err  = pts.eot ? pts.dllp_err : tlp_dllp_err[3];
          qdws[0].data_prot = pts.eot ? {DEF_PROT_1DW,pts.data_prot} : data_prot[0*DW_PROT_WD +: 4*DW_PROT_WD];

          qdws[1].valid     = pts.eot ? 1'b1 : 1'b0;
          qdws[1].data      = pts.eot ? data[0*32 +: 4*32] : 128'b0;
          qdws[1].dwen      = pts.eot ? 4'b1111 : 4'b0000;
          qdws[1].sot       = pts.eot ? 1'b1 : 1'b0;
          qdws[1].eot       = pts.eot ? 1'b1 : 1'b0;
          qdw1_hdr_info     = pts.eot ? get_hdr_info (3'd0, 3'd4, 1'b0, ca_h_info) : DEFAULT_HDR_INFO;
          qdws[1].has_pfx   = pts.eot ? tlp_pfx[0] : 1'b0;
          qdws[1].hdr_valid = pts.eot ? get_hdr_valid (3'd0, 3'd4, 1'b0, ca_h_val) : 1'b0;
          qdws[1].dllp_err  = pts.eot ? tlp_dllp_err[3] : 1'b0;
          qdws[1].data_prot = pts.eot ? data_prot[0*DW_PROT_WD +: 4*DW_PROT_WD] : DEF_PROT_4DW;

          nts.nw            = 2'd0;
          nts.data          = 96'b0;
          nts.sot           = 1'b0;
          nts.eot           = 1'b0;
          nts_hdr_info      = DEFAULT_HDR_INFO;
          nts.has_pfx       = 1'b0;
          nts.hdr_valid     = 1'b0;
          nts.dllp_err      = 1'b0;
          nts.data_prot     = DEF_PROT_3DW;
          chk_nts.status    = NOTHING;
        end

      pts.status==NOTHING && tlp_sot[0] && !tlp_idl[1] && !tlp_eot[1] && !tlp_idl[2] && !tlp_eot[2] && tlp_eot[3] && tlp_sot[4] :
        begin
          dec_case          = s_e_d_d_s;
          qdws[0].valid     = 1'b1;
          qdws[0].data      = pts.eot ? {32'b0,pts.data} : data[0*32 +: 4*32];
          qdws[0].dwen      = pts.eot ? dwen_dec(pts.nw) : 4'b1111;
          qdws[0].sot       = pts.eot ? pts.sot : 1'b1;
          qdws[0].eot       = 1'b1;
          qdw0_hdr_info     = pts.eot ? pts_hdr_info : get_hdr_info (3'd0, 3'd4, 1'b0, ca_h_info);
          qdws[0].has_pfx   = pts.eot ? pts.has_pfx : tlp_pfx[0];
          qdws[0].hdr_valid = pts.eot ? pts.hdr_valid : get_hdr_valid (3'd0, 3'd4, 1'b0, ca_h_val);
          qdws[0].dllp_err  = pts.eot ? pts.dllp_err : tlp_dllp_err[3];
          qdws[0].data_prot = pts.eot ? {DEF_PROT_1DW,pts.data_prot} : data_prot[0*DW_PROT_WD +: 4*DW_PROT_WD];

          qdws[1].valid     = pts.eot ? 1'b1 : 1'b0;
          qdws[1].data      = pts.eot ? data[0*32 +: 4*32] : 128'b0;
          qdws[1].dwen      = pts.eot ? 4'b1111 : 4'b0000;
          qdws[1].sot       = pts.eot ? 1'b1 : 1'b0;
          qdws[1].eot       = pts.eot ? 1'b1 : 1'b0;
          qdw1_hdr_info     = pts.eot ? get_hdr_info (3'd0, 3'd4, 1'b0, ca_h_info) : DEFAULT_HDR_INFO;
          qdws[1].has_pfx   = pts.eot ? tlp_pfx[0] : 1'b0;
          qdws[1].hdr_valid = pts.eot ? get_hdr_valid (3'd0, 3'd4, 1'b0, ca_h_val) : 1'b0;
          qdws[1].dllp_err  = pts.eot ? tlp_dllp_err[3] : 1'b0;
          qdws[1].data_prot = pts.eot ? data_prot[0*DW_PROT_WD +: 4*DW_PROT_WD] : DEF_PROT_4DW;

          nts.nw            = 2'd1;
          nts.data          = {64'b0,data[4*32 +: 1*32]};
          nts.sot           = 1'b1;
          nts.eot           = 1'b0;
          nts_hdr_info      = get_hdr_info (3'd4, 3'd1, 1'b0, ca_h_info);
          nts.has_pfx       = tlp_pfx[4];
          nts.hdr_valid     = get_hdr_valid (3'd4, 3'd1, 1'b0, ca_h_val);
          nts.dllp_err      = 1'b0;
          nts.data_prot     = {DEF_PROT_2DW,data_prot[4*DW_PROT_WD +: 1*DW_PROT_WD]};
          chk_nts.status    = ONGOING;
        end

      pts.status==NOTHING && tlp_sot[0] && !tlp_idl[1] && !tlp_eot[1] && !tlp_idl[2] && !tlp_eot[2] && !tlp_idl[3] && !tlp_eot[3] && tlp_idl[4] :
        begin
          dec_case          = i_d_d_d_s;
          qdws[0].valid     = 1'b1;
          qdws[0].data      = pts.eot ? {32'b0,pts.data} : data[0*32 +: 4*32];
          qdws[0].dwen      = pts.eot ? dwen_dec(pts.nw) : 4'b1111;
          qdws[0].sot       = pts.eot ? pts.sot : 1'b1;
          qdws[0].eot       = pts.eot ? 1'b1 : 1'b0;
          qdw0_hdr_info     = pts.eot ? pts_hdr_info : get_hdr_info (3'd0, 3'd4, 1'b0, ca_h_info);
          qdws[0].has_pfx   = pts.eot ? pts.has_pfx : tlp_pfx[0];
          qdws[0].hdr_valid = pts.eot ? pts.hdr_valid : get_hdr_valid (3'd0, 3'd4, 1'b0, ca_h_val);
          qdws[0].dllp_err  = pts.eot ? pts.dllp_err : 1'b0;
          qdws[0].data_prot = pts.eot ? {DEF_PROT_1DW,pts.data_prot} : data_prot[0*DW_PROT_WD +: 4*DW_PROT_WD];

          qdws[1].valid     = pts.eot ? 1'b1 : 1'b0;
          qdws[1].data      = pts.eot ? data[0*32 +: 4*32] : 128'b0;
          qdws[1].dwen      = pts.eot ? 4'b1111 : 4'b0000;
          qdws[1].sot       = pts.eot ? 1'b1 : 1'b0;
          qdws[1].eot       = 1'b0;
          qdw1_hdr_info     = pts.eot ? get_hdr_info (3'd0, 3'd4, 1'b0, ca_h_info) : DEFAULT_HDR_INFO;
          qdws[1].has_pfx   = pts.eot ? tlp_pfx[0] : 1'b0;
          qdws[1].hdr_valid = pts.eot ? get_hdr_valid (3'd0, 3'd4, 1'b0, ca_h_val) : 1'b0;
          qdws[1].dllp_err  = 1'b0;
          qdws[1].data_prot = pts.eot ? data_prot[0*DW_PROT_WD +: 4*DW_PROT_WD] : DEF_PROT_4DW;

          nts.nw            = 2'd0;
          nts.data          = 96'b0;
          nts.sot           = 1'b0;
          nts.eot           = 1'b0;
          nts_hdr_info      = get_hdr_info (3'd0, 3'd4, 1'b0, ca_h_info);
          nts.has_pfx       = tlp_pfx[0];
          nts.hdr_valid     = 1'b0;
          nts.dllp_err      = 1'b0;
          nts.data_prot     = DEF_PROT_3DW;
          chk_nts.status    = ONGOING;
        end

      pts.status==NOTHING && tlp_sot[0] && !tlp_idl[1] && !tlp_eot[1] && !tlp_idl[2] && !tlp_eot[2] && !tlp_idl[3] && !tlp_eot[3] && tlp_eot[4] :
        begin
          dec_case          = e_d_d_d_s;
          qdws[0].valid     = 1'b1;
          qdws[0].data      = pts.eot ? {32'b0,pts.data} : data[0*32 +: 4*32];
          qdws[0].dwen      = pts.eot ? dwen_dec(pts.nw) : 4'b1111;
          qdws[0].sot       = pts.eot ? pts.sot : 1'b1;
          qdws[0].eot       = pts.eot ? 1'b1 : 1'b0;
          qdw0_hdr_info     = pts.eot ? pts_hdr_info : get_hdr_info (3'd0, 3'd4, 1'b0, ca_h_info);
          qdws[0].has_pfx   = pts.eot ? pts.has_pfx : tlp_pfx[0];
          qdws[0].hdr_valid = pts.eot ? pts.hdr_valid : get_hdr_valid (3'd0, 3'd4, 1'b0, ca_h_val);
          qdws[0].dllp_err  = pts.eot ? pts.dllp_err : 1'b0;
          qdws[0].data_prot = pts.eot ? {DEF_PROT_1DW,pts.data_prot} : data_prot[0*DW_PROT_WD +: 4*DW_PROT_WD];

          qdws[1].valid     = 1'b1;
          qdws[1].data      = pts.eot ? data[0*32 +: 4*32] : {96'b0,data[4*32 +: 1*32]};
          qdws[1].dwen      = pts.eot ? 4'b1111 : 4'b0001;
          qdws[1].sot       = pts.eot ? 1'b1 : 1'b0;
          qdws[1].eot       = pts.eot ? 1'b0 : 1'b1;
          qdw1_hdr_info     = pts.eot ? get_hdr_info (3'd0, 3'd4, 1'b0, ca_h_info) : get_hdr_info (3'd0, 3'd5, 1'b0, ca_h_info);
          qdws[1].has_pfx   = tlp_pfx[0];
          qdws[1].hdr_valid = pts.eot ? get_hdr_valid (3'd0, 3'd4, 1'b0, ca_h_val) : get_hdr_valid (3'd4, 3'd1, 1'b0, ca_h_val);
          qdws[1].dllp_err  = pts.eot ? 1'b0 : tlp_dllp_err[4];
          qdws[1].data_prot = pts.eot ? data_prot[0*DW_PROT_WD +: 4*DW_PROT_WD] : {DEF_PROT_3DW,data_prot[4*DW_PROT_WD +: 1*DW_PROT_WD]};

          nts.nw            = pts.eot ? 2'd1 : 2'd0;
          nts.data          = pts.eot ? {64'b0,data[4*32 +: 1*32]} : 96'b0;
          nts.sot           = 1'b0;
          nts.eot           = pts.eot ? 1'b1 : 1'b0;
          nts_hdr_info      = pts.eot ? get_hdr_info (3'd0, 3'd5, 1'b0, ca_h_info) : DEFAULT_HDR_INFO;
          nts.has_pfx       = pts.eot ? tlp_pfx[0] : 1'b0;
          nts.hdr_valid     = pts.eot ? get_hdr_valid (3'd4, 3'd1, 1'b0, ca_h_val) : 1'b0;
          nts.dllp_err      = pts.eot ? tlp_dllp_err[4] : 1'b0;
          nts.data_prot     = pts.eot ? {DEF_PROT_2DW,data_prot[4*DW_PROT_WD +: 1*DW_PROT_WD]} : DEF_PROT_3DW;
          chk_nts.status    = NOTHING;
        end

      pts.status==NOTHING && tlp_sot[0] && !tlp_idl[1] && !tlp_eot[1] && !tlp_idl[2] && !tlp_eot[2] && !tlp_idl[3] && !tlp_eot[3] && !tlp_idl[4] && !tlp_eot[4] :
        begin
          dec_case          = d_d_d_d_s;
          qdws[0].valid     = 1'b1;
          qdws[0].data      = pts.eot ? {32'b0,pts.data} : data[0*32 +: 4*32];
          qdws[0].dwen      = pts.eot ? dwen_dec(pts.nw) : 4'b1111;
          qdws[0].sot       = pts.eot ? pts.sot : 1'b1;
          qdws[0].eot       = pts.eot ? 1'b1 : 1'b0;
          qdw0_hdr_info     = pts.eot ? pts_hdr_info : get_hdr_info (3'd0, 3'd4, 1'b0, ca_h_info);
          qdws[0].has_pfx   = pts.eot ? pts.has_pfx : tlp_pfx[0];
          qdws[0].hdr_valid = pts.eot ? pts.hdr_valid : get_hdr_valid (3'd0, 3'd4, 1'b0, ca_h_val);
          qdws[0].dllp_err  = pts.eot ? pts.dllp_err : 1'b0;
          qdws[0].data_prot = pts.eot ? {DEF_PROT_1DW,pts.data_prot} : data_prot[0*DW_PROT_WD +: 4*DW_PROT_WD];

          qdws[1].valid     = pts.eot ? 1'b1 : 1'b0;
          qdws[1].data      = pts.eot ? data[0*32 +: 4*32] : 128'b0;
          qdws[1].dwen      = pts.eot ? 4'b1111 : 4'b0000;
          qdws[1].sot       = pts.eot ? 1'b1 : 1'b0;
          qdws[1].eot       = 1'b0;
          qdw1_hdr_info     = pts.eot ? get_hdr_info (3'd0, 3'd4, 1'b0, ca_h_info) : DEFAULT_HDR_INFO;
          qdws[1].has_pfx   = pts.eot ? tlp_pfx[0] : 1'b0;
          qdws[1].hdr_valid = pts.eot ? get_hdr_valid (3'd0, 3'd4, 1'b0, ca_h_val) : 1'b0;
          qdws[1].dllp_err  = 1'b0;
          qdws[1].data_prot = pts.eot ? data_prot[0*DW_PROT_WD +: 4*DW_PROT_WD] : DEF_PROT_4DW;

          nts.nw            = 2'd1;
          nts.data          = {64'b0,data[4*32 +: 1*32]};
          nts.sot           = 1'b0;
          nts.eot           = 1'b0;
          nts_hdr_info      = get_hdr_info (3'd0, 3'd5, 1'b0, ca_h_info);
          nts.has_pfx       = tlp_pfx[0];
          nts.hdr_valid     = get_hdr_valid (3'd4, 3'd1, 1'b0, ca_h_val);
          nts.dllp_err      = 1'b0;
          nts.data_prot     = {DEF_PROT_2DW,data_prot[4*DW_PROT_WD +: 1*DW_PROT_WD]};
          chk_nts.status    = ONGOING;
        end

      pts.status==ONGOING && pts.nw==2'd0 && tlp_eot[0] && tlp_idl[1] && tlp_idl[2] && tlp_idl[3] && tlp_idl[4] :
        begin
          dec_case          = i_i_i_i_e__0;
          qdws[0].valid     = 1'b1;
          qdws[0].data      = {96'b0,data[0*32 +: 1*32]};
          qdws[0].dwen      = 4'b0001;
          qdws[0].sot       = 1'b0;
          qdws[0].eot       = 1'b1;
          qdw0_hdr_info     = get_hdr_info (3'd0, 3'd1, 1'b1, ca_h_info);
          qdws[0].has_pfx   = pts.has_pfx;
          qdws[0].hdr_valid = get_hdr_valid (3'd0, 3'd1, 1'b1, ca_h_val);
          qdws[0].dllp_err  = tlp_dllp_err[0];
          qdws[0].data_prot = {DEF_PROT_3DW,data_prot[0*DW_PROT_WD +: 1*DW_PROT_WD]};

          qdws[1].valid     = 1'b0;
          qdws[1].data      = 128'b0;
          qdws[1].dwen      = 4'b0000;
          qdws[1].sot       = 1'b0;
          qdws[1].eot       = 1'b0;
          qdw1_hdr_info     = DEFAULT_HDR_INFO;
          qdws[1].has_pfx   = 1'b0;
          qdws[1].hdr_valid = 1'b0;
          qdws[1].dllp_err  = 1'b0;
          qdws[1].data_prot = DEF_PROT_4DW;

          nts.nw            = 2'd0;
          nts.data          = 96'b0;
          nts.sot           = 1'b0;
          nts.eot           = 1'b0;
          nts_hdr_info      = DEFAULT_HDR_INFO;
          nts.has_pfx       = 1'b0;
          nts.hdr_valid     = 1'b0;
          nts.dllp_err      = 1'b0;
          nts.data_prot     = DEF_PROT_3DW;
          chk_nts.status    = NOTHING;
        end

      pts.status==ONGOING && pts.nw==2'd0 && tlp_eot[0] && tlp_idl[1] && tlp_idl[2] && tlp_idl[3] && tlp_sot[4] :
        begin
          dec_case          = s_i_i_i_e__0;
          qdws[0].valid     = 1'b1;
          qdws[0].data      = {96'b0,data[0*32 +: 1*32]};
          qdws[0].dwen      = 4'b0001;
          qdws[0].sot       = 1'b0;
          qdws[0].eot       = 1'b1;
          qdw0_hdr_info     = get_hdr_info (3'd0, 3'd1, 1'b1, ca_h_info);
          qdws[0].has_pfx   = pts.has_pfx;
          qdws[0].hdr_valid = get_hdr_valid (3'd0, 3'd1, 1'b1, ca_h_val);
          qdws[0].dllp_err  = tlp_dllp_err[0];
          qdws[0].data_prot = {DEF_PROT_3DW,data_prot[0*DW_PROT_WD +: 1*DW_PROT_WD]};

          qdws[1].valid     = 1'b0;
          qdws[1].data      = 128'b0;
          qdws[1].dwen      = 4'b0000;
          qdws[1].sot       = 1'b0;
          qdws[1].eot       = 1'b0;
          qdw1_hdr_info     = DEFAULT_HDR_INFO;
          qdws[1].has_pfx   = 1'b0;
          qdws[1].hdr_valid = 1'b0;
          qdws[1].dllp_err  = 1'b0;
          qdws[1].data_prot = DEF_PROT_4DW;

          nts.nw            = 2'd1;
          nts.data          = {64'b0,data[4*32 +: 1*32]};
          nts.sot           = 1'b1;
          nts.eot           = 1'b0;
          nts_hdr_info      = get_hdr_info (3'd4, 3'd1, 1'b0, ca_h_info);
          nts.has_pfx       = tlp_pfx[4];
          nts.hdr_valid     = get_hdr_valid (3'd4, 3'd1, 1'b0, ca_h_val);
          nts.dllp_err      = 1'b0;
          nts.data_prot     = {DEF_PROT_2DW,data_prot[4*DW_PROT_WD +: 1*DW_PROT_WD]};
          chk_nts.status    = ONGOING;
        end

      pts.status==ONGOING && pts.nw==2'd0 && tlp_eot[0] && tlp_idl[1] && tlp_idl[2] && tlp_sot[3] && tlp_idl[4] :
        begin
          dec_case          = i_s_i_i_e__0;
          qdws[0].valid     = 1'b1;
          qdws[0].data      = {96'b0,data[0*32 +: 1*32]};
          qdws[0].dwen      = 4'b0001;
          qdws[0].sot       = 1'b0;
          qdws[0].eot       = 1'b1;
          qdw0_hdr_info     = get_hdr_info (3'd0, 3'd1, 1'b1, ca_h_info);
          qdws[0].has_pfx   = pts.has_pfx;
          qdws[0].hdr_valid = get_hdr_valid (3'd0, 3'd1, 1'b1, ca_h_val);
          qdws[0].dllp_err  = tlp_dllp_err[0];
          qdws[0].data_prot = {DEF_PROT_3DW,data_prot[0*DW_PROT_WD +: 1*DW_PROT_WD]};

          qdws[1].valid     = 1'b0;
          qdws[1].data      = 128'b0;
          qdws[1].dwen      = 4'b0000;
          qdws[1].sot       = 1'b0;
          qdws[1].eot       = 1'b0;
          qdw1_hdr_info     = DEFAULT_HDR_INFO;
          qdws[1].has_pfx   = 1'b0;
          qdws[1].hdr_valid = 1'b0;
          qdws[1].dllp_err  = 1'b0;
          qdws[1].data_prot = DEF_PROT_4DW;

          nts.nw            = 2'd1;
          nts.data          = {64'b0,data[3*32 +: 1*32]};
          nts.sot           = 1'b1;
          nts.eot           = 1'b0;
          nts_hdr_info      = get_hdr_info (3'd3, 3'd1, 1'b0, ca_h_info);
          nts.has_pfx       = tlp_pfx[3];
          nts.hdr_valid     = get_hdr_valid (3'd3, 3'd1, 1'b0, ca_h_val);
          nts.dllp_err      = 1'b0;
          nts.data_prot     = {DEF_PROT_2DW,data_prot[3*DW_PROT_WD +: 1*DW_PROT_WD]};
          chk_nts.status    = ONGOING;
        end

      pts.status==ONGOING && pts.nw==2'd0 && tlp_eot[0] && tlp_idl[1] && tlp_idl[2] && tlp_sot[3] && !tlp_idl[4] && !tlp_eot[4] :
        begin
          dec_case          = d_s_i_i_e__0;
          qdws[0].valid     = 1'b1;
          qdws[0].data      = {96'b0,data[0*32 +: 1*32]};
          qdws[0].dwen      = 4'b0001;
          qdws[0].sot       = 1'b0;
          qdws[0].eot       = 1'b1;
          qdw0_hdr_info     = get_hdr_info (3'd0, 3'd1, 1'b1, ca_h_info);
          qdws[0].has_pfx   = pts.has_pfx;
          qdws[0].hdr_valid = get_hdr_valid (3'd0, 3'd1, 1'b1, ca_h_val);
          qdws[0].dllp_err  = tlp_dllp_err[0];
          qdws[0].data_prot = {DEF_PROT_3DW,data_prot[0*DW_PROT_WD +: 1*DW_PROT_WD]};

          qdws[1].valid     = 1'b0;
          qdws[1].data      = 128'b0;
          qdws[1].dwen      = 4'b0000;
          qdws[1].sot       = 1'b0;
          qdws[1].eot       = 1'b0;
          qdw1_hdr_info     = DEFAULT_HDR_INFO;
          qdws[1].has_pfx   = 1'b0;
          qdws[1].hdr_valid = 1'b0;
          qdws[1].dllp_err  = 1'b0;
          qdws[1].data_prot = DEF_PROT_4DW;

          nts.nw            = 2'd2;
          nts.data          = {32'b0,data[3*32 +: 2*32]};
          nts.sot           = 1'b1;
          nts.eot           = 1'b0;
          nts_hdr_info      = get_hdr_info (3'd3, 3'd2, 1'b0, ca_h_info);
          nts.has_pfx       = tlp_pfx[3];
          nts.hdr_valid     = get_hdr_valid (3'd3, 3'd2, 1'b0, ca_h_val);
          nts.dllp_err      = 1'b0;
          nts.data_prot     = {DEF_PROT_1DW,data_prot[3*DW_PROT_WD +: 2*DW_PROT_WD]};
          chk_nts.status    = ONGOING;
        end

      pts.status==ONGOING && pts.nw==2'd0 && tlp_eot[0] && tlp_idl[1] && tlp_sot[2] && tlp_idl[3] && tlp_idl[4] :
        begin
          dec_case          = i_i_s_i_e__0;
          qdws[0].valid     = 1'b1;
          qdws[0].data      = {96'b0,data[0*32 +: 1*32]};
          qdws[0].dwen      = 4'b0001;
          qdws[0].sot       = 1'b0;
          qdws[0].eot       = 1'b1;
          qdw0_hdr_info     = get_hdr_info (3'd0, 3'd1, 1'b1, ca_h_info);
          qdws[0].has_pfx   = pts.has_pfx;
          qdws[0].hdr_valid = get_hdr_valid (3'd0, 3'd1, 1'b1, ca_h_val);
          qdws[0].dllp_err  = tlp_dllp_err[0];
          qdws[0].data_prot = {DEF_PROT_3DW,data_prot[0*DW_PROT_WD +: 1*DW_PROT_WD]};

          qdws[1].valid     = 1'b0;
          qdws[1].data      = 128'b0;
          qdws[1].dwen      = 4'b0000;
          qdws[1].sot       = 1'b0;
          qdws[1].eot       = 1'b0;
          qdw1_hdr_info     = DEFAULT_HDR_INFO;
          qdws[1].has_pfx   = 1'b0;
          qdws[1].hdr_valid = 1'b0;
          qdws[1].dllp_err  = 1'b0;
          qdws[1].data_prot = DEF_PROT_4DW;

          nts.nw            = 2'd1;
          nts.data          = {64'b0,data[2*32 +: 1*32]};
          nts.sot           = 1'b1;
          nts.eot           = 1'b0;
          nts_hdr_info      = get_hdr_info (3'd2, 3'd1, 1'b0, ca_h_info);
          nts.has_pfx       = tlp_pfx[2];
          nts.hdr_valid     = get_hdr_valid (3'd2, 3'd1, 1'b0, ca_h_val);
          nts.dllp_err      = 1'b0;
          nts.data_prot     = {DEF_PROT_2DW,data_prot[2*DW_PROT_WD +: 1*DW_PROT_WD]};
          chk_nts.status    = ONGOING;
        end

      pts.status==ONGOING && pts.nw==2'd0 && tlp_eot[0] && tlp_idl[1] && tlp_sot[2] && !tlp_idl[3] && !tlp_eot[3] && tlp_idl[4] :
        begin
          dec_case          = i_d_s_i_e__0;
          qdws[0].valid     = 1'b1;
          qdws[0].data      = {96'b0,data[0*32 +: 1*32]};
          qdws[0].dwen      = 4'b0001;
          qdws[0].sot       = 1'b0;
          qdws[0].eot       = 1'b1;
          qdw0_hdr_info     = get_hdr_info (3'd0, 3'd1, 1'b1, ca_h_info);
          qdws[0].has_pfx   = pts.has_pfx;
          qdws[0].hdr_valid = get_hdr_valid (3'd0, 3'd1, 1'b1, ca_h_val);
          qdws[0].dllp_err  = tlp_dllp_err[0];
          qdws[0].data_prot = {DEF_PROT_3DW,data_prot[0*DW_PROT_WD +: 1*DW_PROT_WD]};

          qdws[1].valid     = 1'b0;
          qdws[1].data      = 128'b0;
          qdws[1].dwen      = 4'b0000;
          qdws[1].sot       = 1'b0;
          qdws[1].eot       = 1'b0;
          qdw1_hdr_info     = DEFAULT_HDR_INFO;
          qdws[1].has_pfx   = 1'b0;
          qdws[1].hdr_valid = 1'b0;
          qdws[1].dllp_err  = 1'b0;
          qdws[1].data_prot = DEF_PROT_4DW;

          nts.nw            = 2'd2;
          nts.data          = {32'b0,data[2*32 +: 2*32]};
          nts.sot           = 1'b1;
          nts.eot           = 1'b0;
          nts_hdr_info      = get_hdr_info (3'd2, 3'd2, 1'b0, ca_h_info);
          nts.has_pfx       = tlp_pfx[2];
          nts.hdr_valid     = get_hdr_valid (3'd2, 3'd2, 1'b0, ca_h_val);
          nts.dllp_err      = 1'b0;
          nts.data_prot     = {DEF_PROT_1DW,data_prot[2*DW_PROT_WD +: 2*DW_PROT_WD]};
          chk_nts.status    = ONGOING;
        end

      pts.status==ONGOING && pts.nw==2'd0 && tlp_eot[0] && tlp_idl[1] && tlp_sot[2] && !tlp_idl[3] && !tlp_eot[3] && tlp_eot[4] :
        begin
          dec_case          = e_d_s_i_e__0;
          qdws[0].valid     = 1'b1;
          qdws[0].data      = {96'b0,data[0*32 +: 1*32]};
          qdws[0].dwen      = 4'b0001;
          qdws[0].sot       = 1'b0;
          qdws[0].eot       = 1'b1;
          qdw0_hdr_info     = get_hdr_info (3'd0, 3'd1, 1'b1, ca_h_info);
          qdws[0].has_pfx   = pts.has_pfx;
          qdws[0].hdr_valid = get_hdr_valid (3'd0, 3'd1, 1'b1, ca_h_val);
          qdws[0].dllp_err  = tlp_dllp_err[0];
          qdws[0].data_prot = {DEF_PROT_3DW,data_prot[0*DW_PROT_WD +: 1*DW_PROT_WD]};

          qdws[1].valid     = 1'b1;
          qdws[1].data      = {32'b0,data[2*32 +: 3*32]};
          qdws[1].dwen      = 4'b0111;
          qdws[1].sot       = 1'b1;
          qdws[1].eot       = 1'b1;
          qdw1_hdr_info     = get_hdr_info (3'd2, 3'd3, 1'b0, ca_h_info);
          qdws[1].has_pfx   = tlp_pfx[2];
          qdws[1].hdr_valid = get_hdr_valid (3'd2, 3'd3, 1'b0, ca_h_val);
          qdws[1].dllp_err  = tlp_dllp_err[4];
          qdws[1].data_prot = {DEF_PROT_1DW,data_prot[2*DW_PROT_WD +: 3*DW_PROT_WD]};

          nts.nw            = 2'd0;
          nts.data          = 96'b0;
          nts.sot           = 1'b0;
          nts.eot           = 1'b0;
          nts_hdr_info      = DEFAULT_HDR_INFO;
          nts.has_pfx       = 1'b0;
          nts.hdr_valid     = 1'b0;
          nts.dllp_err      = 1'b0;
          nts.data_prot     = DEF_PROT_3DW;
          chk_nts.status    = NOTHING;
        end

      pts.status==ONGOING && pts.nw==2'd0 && tlp_eot[0] && tlp_idl[1] && tlp_sot[2] && !tlp_idl[3] && !tlp_eot[3] && !tlp_idl[4] && !tlp_eot[4] :
        begin
          dec_case          = d_d_s_i_e__0;
          qdws[0].valid     = 1'b1;
          qdws[0].data      = {96'b0,data[0*32 +: 1*32]};
          qdws[0].dwen      = 4'b0001;
          qdws[0].sot       = 1'b0;
          qdws[0].eot       = 1'b1;
          qdw0_hdr_info     = get_hdr_info (3'd0, 3'd1, 1'b1, ca_h_info);
          qdws[0].has_pfx   = pts.has_pfx;
          qdws[0].hdr_valid = get_hdr_valid (3'd0, 3'd1, 1'b1, ca_h_val);
          qdws[0].dllp_err  = tlp_dllp_err[0];
          qdws[0].data_prot = {DEF_PROT_3DW,data_prot[0*DW_PROT_WD +: 1*DW_PROT_WD]};

          qdws[1].valid     = 1'b0;
          qdws[1].data      = 128'b0;
          qdws[1].dwen      = 4'b0000;
          qdws[1].sot       = 1'b0;
          qdws[1].eot       = 1'b0;
          qdw1_hdr_info     = DEFAULT_HDR_INFO;
          qdws[1].has_pfx   = 1'b0;
          qdws[1].hdr_valid = 1'b0;
          qdws[1].dllp_err  = 1'b0;
          qdws[1].data_prot = DEF_PROT_4DW;

          nts.nw            = 2'd3;
          nts.data          = data[2*32 +: 3*32];
          nts.sot           = 1'b1;
          nts.eot           = 1'b0;
          nts_hdr_info      = get_hdr_info (3'd2, 3'd3, 1'b0, ca_h_info);
          nts.has_pfx       = tlp_pfx[2];
          nts.hdr_valid     = get_hdr_valid (3'd2, 3'd3, 1'b0, ca_h_val);
          nts.dllp_err      = 1'b0;
          nts.data_prot     = data_prot[2*DW_PROT_WD +: 3*DW_PROT_WD];
          chk_nts.status    = ONGOING;
        end

      pts.status==ONGOING && pts.nw==2'd0 && tlp_eot[0] && tlp_sot[1] && tlp_idl[2] && tlp_idl[3] && tlp_idl[4] :
        begin
          dec_case          = i_i_i_s_e__0;
          qdws[0].valid     = 1'b1;
          qdws[0].data      = {96'b0,data[0*32 +: 1*32]};
          qdws[0].dwen      = 4'b0001;
          qdws[0].sot       = 1'b0;
          qdws[0].eot       = 1'b1;
          qdw0_hdr_info     = get_hdr_info (3'd0, 3'd1, 1'b1, ca_h_info);
          qdws[0].has_pfx   = pts.has_pfx;
          qdws[0].hdr_valid = get_hdr_valid (3'd0, 3'd1, 1'b1, ca_h_val);
          qdws[0].dllp_err  = tlp_dllp_err[0];
          qdws[0].data_prot = {DEF_PROT_3DW,data_prot[0*DW_PROT_WD +: 1*DW_PROT_WD]};

          qdws[1].valid     = 1'b0;
          qdws[1].data      = 128'b0;
          qdws[1].dwen      = 4'b0000;
          qdws[1].sot       = 1'b0;
          qdws[1].eot       = 1'b0;
          qdw1_hdr_info     = DEFAULT_HDR_INFO;
          qdws[1].has_pfx   = 1'b0;
          qdws[1].hdr_valid = 1'b0;
          qdws[1].dllp_err  = 1'b0;
          qdws[1].data_prot = DEF_PROT_4DW;

          nts.nw            = 2'd1;
          nts.data          = {64'b0,data[1*32 +: 1*32]};
          nts.sot           = 1'b1;
          nts.eot           = 1'b0;
          nts_hdr_info      = get_hdr_info (3'd1, 3'd1, 1'b0, ca_h_info);
          nts.has_pfx       = tlp_pfx[1];
          nts.hdr_valid     = get_hdr_valid (3'd1, 3'd1, 1'b0, ca_h_val);
          nts.dllp_err      = 1'b0;
          nts.data_prot     = {DEF_PROT_2DW,data_prot[1*DW_PROT_WD +: 1*DW_PROT_WD]};
          chk_nts.status    = ONGOING;
        end

      pts.status==ONGOING && pts.nw==2'd0 && tlp_eot[0] && tlp_sot[1] && !tlp_idl[2] && !tlp_eot[2] && tlp_idl[3] && tlp_idl[4] :
        begin
          dec_case          = i_i_d_s_e__0;
          qdws[0].valid     = 1'b1;
          qdws[0].data      = {96'b0,data[0*32 +: 1*32]};
          qdws[0].dwen      = 4'b0001;
          qdws[0].sot       = 1'b0;
          qdws[0].eot       = 1'b1;
          qdw0_hdr_info     = get_hdr_info (3'd0, 3'd1, 1'b1, ca_h_info);
          qdws[0].has_pfx   = pts.has_pfx;
          qdws[0].hdr_valid = get_hdr_valid (3'd0, 3'd1, 1'b1, ca_h_val);
          qdws[0].dllp_err  = tlp_dllp_err[0];
          qdws[0].data_prot = {DEF_PROT_3DW,data_prot[0*DW_PROT_WD +: 1*DW_PROT_WD]};

          qdws[1].valid     = 1'b0;
          qdws[1].data      = 128'b0;
          qdws[1].dwen      = 4'b0000;
          qdws[1].sot       = 1'b0;
          qdws[1].eot       = 1'b0;
          qdw1_hdr_info     = DEFAULT_HDR_INFO;
          qdws[1].has_pfx   = 1'b0;
          qdws[1].hdr_valid = 1'b0;
          qdws[1].dllp_err  = 1'b0;
          qdws[1].data_prot = DEF_PROT_4DW;

          nts.nw            = 2'd2;
          nts.data          = {32'b0,data[1*32 +: 2*32]};
          nts.sot           = 1'b1;
          nts.eot           = 1'b0;
          nts_hdr_info      = get_hdr_info (3'd1, 3'd2, 1'b0, ca_h_info);
          nts.has_pfx       = tlp_pfx[1];
          nts.hdr_valid     = get_hdr_valid (3'd1, 3'd2, 1'b0, ca_h_val);
          nts.dllp_err      = 1'b0;
          nts.data_prot     = {DEF_PROT_1DW,data_prot[1*DW_PROT_WD +: 2*DW_PROT_WD]};
          chk_nts.status    = ONGOING;
        end

      pts.status==ONGOING && pts.nw==2'd0 && tlp_eot[0] && tlp_sot[1] && !tlp_idl[2] && !tlp_eot[2] && tlp_eot[3] && tlp_idl[4] :
        begin
          dec_case          = i_e_d_s_e__0;
          qdws[0].valid     = 1'b1;
          qdws[0].data      = {96'b0,data[0*32 +: 1*32]};
          qdws[0].dwen      = 4'b0001;
          qdws[0].sot       = 1'b0;
          qdws[0].eot       = 1'b1;
          qdw0_hdr_info     = get_hdr_info (3'd0, 3'd1, 1'b1, ca_h_info);
          qdws[0].has_pfx   = pts.has_pfx;
          qdws[0].hdr_valid = get_hdr_valid (3'd0, 3'd1, 1'b1, ca_h_val);
          qdws[0].dllp_err  = tlp_dllp_err[0];
          qdws[0].data_prot = {DEF_PROT_3DW,data_prot[0*DW_PROT_WD +: 1*DW_PROT_WD]};

          qdws[1].valid     = 1'b1;
          qdws[1].data      = {32'b0,data[1*32 +: 3*32]};
          qdws[1].dwen      = 4'b0111;
          qdws[1].sot       = 1'b1;
          qdws[1].eot       = 1'b1;
          qdw1_hdr_info     = get_hdr_info (3'd1, 3'd3, 1'b0, ca_h_info);
          qdws[1].has_pfx   = tlp_pfx[1];
          qdws[1].hdr_valid = get_hdr_valid (3'd1, 3'd3, 1'b0, ca_h_val);
          qdws[1].dllp_err  = tlp_dllp_err[3];
          qdws[1].data_prot = {DEF_PROT_1DW,data_prot[1*DW_PROT_WD +: 3*DW_PROT_WD]};

          nts.nw            = 2'd0;
          nts.data          = 96'b0;
          nts.sot           = 1'b0;
          nts.eot           = 1'b0;
          nts_hdr_info      = DEFAULT_HDR_INFO;
          nts.has_pfx       = 1'b0;
          nts.hdr_valid     = 1'b0;
          nts.dllp_err      = 1'b0;
          nts.data_prot     = DEF_PROT_3DW;
          chk_nts.status    = NOTHING;
        end

      pts.status==ONGOING && pts.nw==2'd0 && tlp_eot[0] && tlp_sot[1] && !tlp_idl[2] && !tlp_eot[2] && tlp_eot[3] && tlp_sot[4] :
        begin
          dec_case          = s_e_d_s_e__0;
          qdws[0].valid     = 1'b1;
          qdws[0].data      = {96'b0,data[0*32 +: 1*32]};
          qdws[0].dwen      = 4'b0001;
          qdws[0].sot       = 1'b0;
          qdws[0].eot       = 1'b1;
          qdw0_hdr_info     = get_hdr_info (3'd0, 3'd1, 1'b1, ca_h_info);
          qdws[0].has_pfx   = pts.has_pfx;
          qdws[0].hdr_valid = get_hdr_valid (3'd0, 3'd1, 1'b1, ca_h_val);
          qdws[0].dllp_err  = tlp_dllp_err[0];
          qdws[0].data_prot = {DEF_PROT_3DW,data_prot[0*DW_PROT_WD +: 1*DW_PROT_WD]};

          qdws[1].valid     = 1'b1;
          qdws[1].data      = {32'b0,data[1*32 +: 3*32]};
          qdws[1].dwen      = 4'b0111;
          qdws[1].sot       = 1'b1;
          qdws[1].eot       = 1'b1;
          qdw1_hdr_info     = get_hdr_info (3'd1, 3'd3, 1'b0, ca_h_info);
          qdws[1].has_pfx   = tlp_pfx[1];
          qdws[1].hdr_valid = get_hdr_valid (3'd1, 3'd3, 1'b0, ca_h_val);
          qdws[1].dllp_err  = tlp_dllp_err[3];
          qdws[1].data_prot = {DEF_PROT_1DW,data_prot[1*DW_PROT_WD +: 3*DW_PROT_WD]};

          nts.nw            = 2'd1;
          nts.data          = {64'b0,data[4*32 +: 1*32]};
          nts.sot           = 1'b1;
          nts.eot           = 1'b0;
          nts_hdr_info      = get_hdr_info (3'd4, 3'd1, 1'b0, ca_h_info);
          nts.has_pfx       = tlp_pfx[4];
          nts.hdr_valid     = get_hdr_valid (3'd4, 3'd1, 1'b0, ca_h_val);
          nts.dllp_err      = 1'b0;
          nts.data_prot     = {DEF_PROT_2DW,data_prot[4*DW_PROT_WD +: 1*DW_PROT_WD]};
          chk_nts.status    = ONGOING;
        end

      pts.status==ONGOING && pts.nw==2'd0 && tlp_eot[0] && tlp_sot[1] && !tlp_idl[2] && !tlp_eot[2] && !tlp_idl[3] && !tlp_eot[3] && tlp_idl[4] :
        begin
          dec_case          = i_d_d_s_e__0;
          qdws[0].valid     = 1'b1;
          qdws[0].data      = {96'b0,data[0*32 +: 1*32]};
          qdws[0].dwen      = 4'b0001;
          qdws[0].sot       = 1'b0;
          qdws[0].eot       = 1'b1;
          qdw0_hdr_info     = get_hdr_info (3'd0, 3'd1, 1'b1, ca_h_info);
          qdws[0].has_pfx   = pts.has_pfx;
          qdws[0].hdr_valid = get_hdr_valid (3'd0, 3'd1, 1'b1, ca_h_val);
          qdws[0].dllp_err  = tlp_dllp_err[0];
          qdws[0].data_prot = {DEF_PROT_3DW,data_prot[0*DW_PROT_WD +: 1*DW_PROT_WD]};

          qdws[1].valid     = 1'b0;
          qdws[1].data      = 128'b0;
          qdws[1].dwen      = 4'b0000;
          qdws[1].sot       = 1'b0;
          qdws[1].eot       = 1'b0;
          qdw1_hdr_info     = DEFAULT_HDR_INFO;
          qdws[1].has_pfx   = 1'b0;
          qdws[1].hdr_valid = 1'b0;
          qdws[1].dllp_err  = 1'b0;
          qdws[1].data_prot = DEF_PROT_4DW;

          nts.nw            = 2'd3;
          nts.data          = data[1*32 +: 3*32];
          nts.sot           = 1'b1;
          nts.eot           = 1'b0;
          nts_hdr_info      = get_hdr_info (3'd1, 3'd3, 1'b0, ca_h_info);
          nts.has_pfx       = tlp_pfx[1];
          nts.hdr_valid     = get_hdr_valid (3'd1, 3'd3, 1'b0, ca_h_val);
          nts.dllp_err      = 1'b0;
          nts.data_prot     = data_prot[1*DW_PROT_WD +: 3*DW_PROT_WD];
          chk_nts.status    = ONGOING;
        end

      pts.status==ONGOING && pts.nw==2'd0 && tlp_eot[0] && tlp_sot[1] && !tlp_idl[2] && !tlp_eot[2] && !tlp_idl[3] && !tlp_eot[3] && tlp_eot[4] :
        begin
          dec_case          = e_d_d_s_e__0;
          qdws[0].valid     = 1'b1;
          qdws[0].data      = {96'b0,data[0*32 +: 1*32]};
          qdws[0].dwen      = 4'b0001;
          qdws[0].sot       = 1'b0;
          qdws[0].eot       = 1'b1;
          qdw0_hdr_info     = get_hdr_info (3'd0, 3'd1, 1'b1, ca_h_info);
          qdws[0].has_pfx   = pts.has_pfx;
          qdws[0].hdr_valid = get_hdr_valid (3'd0, 3'd1, 1'b1, ca_h_val);
          qdws[0].dllp_err  = tlp_dllp_err[0];
          qdws[0].data_prot = {DEF_PROT_3DW,data_prot[0*DW_PROT_WD +: 1*DW_PROT_WD]};

          qdws[1].valid     = 1'b1;
          qdws[1].data      = data[1*32 +: 4*32];
          qdws[1].dwen      = 4'b1111;
          qdws[1].sot       = 1'b1;
          qdws[1].eot       = 1'b1;
          qdw1_hdr_info     = get_hdr_info (3'd1, 3'd4, 1'b0, ca_h_info);
          qdws[1].has_pfx   = tlp_pfx[1];
          qdws[1].hdr_valid = get_hdr_valid (3'd1, 3'd4, 1'b0, ca_h_val);
          qdws[1].dllp_err  = tlp_dllp_err[4];
          qdws[1].data_prot = data_prot[1*DW_PROT_WD +: 4*DW_PROT_WD];

          nts.nw            = 2'd0;
          nts.data          = 96'b0;
          nts.sot           = 1'b0;
          nts.eot           = 1'b0;
          nts_hdr_info      = DEFAULT_HDR_INFO;
          nts.has_pfx       = 1'b0;
          nts.hdr_valid     = 1'b0;
          nts.dllp_err      = 1'b0;
          nts.data_prot     = DEF_PROT_3DW;
          chk_nts.status    = NOTHING;
        end

      pts.status==ONGOING && pts.nw==2'd0 && tlp_eot[0] && tlp_sot[1] && !tlp_idl[2] && !tlp_eot[2] && !tlp_idl[3] && !tlp_eot[3] && !tlp_idl[4] && !tlp_eot[4] :
        begin
          dec_case          = d_d_d_s_e__0;
          qdws[0].valid     = 1'b1;
          qdws[0].data      = {96'b0,data[0*32 +: 1*32]};
          qdws[0].dwen      = 4'b0001;
          qdws[0].sot       = 1'b0;
          qdws[0].eot       = 1'b1;
          qdw0_hdr_info     = get_hdr_info (3'd0, 3'd1, 1'b1, ca_h_info);
          qdws[0].has_pfx   = pts.has_pfx;
          qdws[0].hdr_valid = get_hdr_valid (3'd0, 3'd1, 1'b1, ca_h_val);
          qdws[0].dllp_err  = tlp_dllp_err[0];
          qdws[0].data_prot = {DEF_PROT_3DW,data_prot[0*DW_PROT_WD +: 1*DW_PROT_WD]};

          qdws[1].valid     = 1'b1;
          qdws[1].data      = data[1*32 +: 4*32];
          qdws[1].dwen      = 4'b1111;
          qdws[1].sot       = 1'b1;
          qdws[1].eot       = 1'b0;
          qdw1_hdr_info     = get_hdr_info (3'd1, 3'd4, 1'b0, ca_h_info);
          qdws[1].has_pfx   = tlp_pfx[1];
          qdws[1].hdr_valid = get_hdr_valid (3'd1, 3'd4, 1'b0, ca_h_val);
          qdws[1].dllp_err  = 1'b0;
          qdws[1].data_prot = data_prot[1*DW_PROT_WD +: 4*DW_PROT_WD];

          nts.nw            = 2'd0;
          nts.data          = 96'b0;
          nts.sot           = 1'b0;
          nts.eot           = 1'b0;
          nts_hdr_info      = get_hdr_info (3'd1, 3'd4, 1'b0, ca_h_info);
          nts.has_pfx       = tlp_pfx[1];
          nts.hdr_valid     = 1'b0;
          nts.dllp_err      = 1'b0;
          nts.data_prot     = DEF_PROT_3DW;
          chk_nts.status    = ONGOING;
        end

      pts.status==ONGOING && pts.nw==2'd0 && !tlp_idl[0] && !tlp_eot[0] && tlp_idl[1] && tlp_idl[2] && tlp_idl[3] && tlp_idl[4] :
        begin
          dec_case          = i_i_i_i_d__0;
          qdws[0].valid     = 1'b0;
          qdws[0].data      = 128'b0;
          qdws[0].dwen      = 4'b0000;
          qdws[0].sot       = 1'b0;
          qdws[0].eot       = 1'b0;
          qdw0_hdr_info     = DEFAULT_HDR_INFO;
          qdws[0].has_pfx   = 1'b0;
          qdws[0].hdr_valid = 1'b0;
          qdws[0].dllp_err  = 1'b0;
          qdws[0].data_prot = DEF_PROT_4DW;

          qdws[1].valid     = 1'b0;
          qdws[1].data      = 128'b0;
          qdws[1].dwen      = 4'b0000;
          qdws[1].sot       = 1'b0;
          qdws[1].eot       = 1'b0;
          qdw1_hdr_info     = DEFAULT_HDR_INFO;
          qdws[1].has_pfx   = 1'b0;
          qdws[1].hdr_valid = 1'b0;
          qdws[1].dllp_err  = 1'b0;
          qdws[1].data_prot = DEF_PROT_4DW;

          nts.nw            = 2'd1;
          nts.data          = {64'b0,data[0*32 +: 1*32]};
          nts.sot           = 1'b0;
          nts.eot           = 1'b0;
          nts_hdr_info      = get_hdr_info (3'd0, 3'd1, 1'b1, ca_h_info);
          nts.has_pfx       = pts.has_pfx;
          nts.hdr_valid     = get_hdr_valid (3'd0, 3'd1, 1'b1, ca_h_val);
          nts.dllp_err      = 1'b0;
          nts.data_prot     = {DEF_PROT_2DW,data_prot[0*DW_PROT_WD +: 1*DW_PROT_WD]};
          chk_nts.status    = ONGOING;
        end

      pts.status==ONGOING && pts.nw==2'd0 && !tlp_idl[0] && !tlp_eot[0] && tlp_eot[1] && tlp_idl[2] && tlp_idl[3] && tlp_idl[4] :
        begin
          dec_case          = i_i_i_e_d__0;
          qdws[0].valid     = 1'b1;
          qdws[0].data      = {64'b0,data[0*32 +: 2*32]};
          qdws[0].dwen      = 4'b0011;
          qdws[0].sot       = 1'b0;
          qdws[0].eot       = 1'b1;
          qdw0_hdr_info     = get_hdr_info (3'd0, 3'd2, 1'b1, ca_h_info);
          qdws[0].has_pfx   = pts.has_pfx;
          qdws[0].hdr_valid = get_hdr_valid (3'd0, 3'd2, 1'b1, ca_h_val);
          qdws[0].dllp_err  = tlp_dllp_err[1];
          qdws[0].data_prot = {DEF_PROT_2DW,data_prot[0*DW_PROT_WD +: 2*DW_PROT_WD]};

          qdws[1].valid     = 1'b0;
          qdws[1].data      = 128'b0;
          qdws[1].dwen      = 4'b0000;
          qdws[1].sot       = 1'b0;
          qdws[1].eot       = 1'b0;
          qdw1_hdr_info     = DEFAULT_HDR_INFO;
          qdws[1].has_pfx   = 1'b0;
          qdws[1].hdr_valid = 1'b0;
          qdws[1].dllp_err  = 1'b0;
          qdws[1].data_prot = DEF_PROT_4DW;

          nts.nw            = 2'd0;
          nts.data          = 96'b0;
          nts.sot           = 1'b0;
          nts.eot           = 1'b0;
          nts_hdr_info      = DEFAULT_HDR_INFO;
          nts.has_pfx       = 1'b0;
          nts.hdr_valid     = 1'b0;
          nts.dllp_err      = 1'b0;
          nts.data_prot     = DEF_PROT_3DW;
          chk_nts.status    = NOTHING;
        end

      pts.status==ONGOING && pts.nw==2'd0 && !tlp_idl[0] && !tlp_eot[0] && tlp_eot[1] && tlp_idl[2] && tlp_idl[3] && tlp_sot[4] :
        begin
          dec_case          = s_i_i_e_d__0;
          qdws[0].valid     = 1'b1;
          qdws[0].data      = {64'b0,data[0*32 +: 2*32]};
          qdws[0].dwen      = 4'b0011;
          qdws[0].sot       = 1'b0;
          qdws[0].eot       = 1'b1;
          qdw0_hdr_info     = get_hdr_info (3'd0, 3'd2, 1'b1, ca_h_info);
          qdws[0].has_pfx   = pts.has_pfx;
          qdws[0].hdr_valid = get_hdr_valid (3'd0, 3'd2, 1'b1, ca_h_val);
          qdws[0].dllp_err  = tlp_dllp_err[1];
          qdws[0].data_prot = {DEF_PROT_2DW,data_prot[0*DW_PROT_WD +: 2*DW_PROT_WD]};

          qdws[1].valid     = 1'b0;
          qdws[1].data      = 128'b0;
          qdws[1].dwen      = 4'b0000;
          qdws[1].sot       = 1'b0;
          qdws[1].eot       = 1'b0;
          qdw1_hdr_info     = DEFAULT_HDR_INFO;
          qdws[1].has_pfx   = 1'b0;
          qdws[1].hdr_valid = 1'b0;
          qdws[1].dllp_err  = 1'b0;
          qdws[1].data_prot = DEF_PROT_4DW;

          nts.nw            = 2'd1;
          nts.data          = {64'b0,data[4*32 +: 1*32]};
          nts.sot           = 1'b1;
          nts.eot           = 1'b0;
          nts_hdr_info      = get_hdr_info (3'd4, 3'd1, 1'b0, ca_h_info);
          nts.has_pfx       = tlp_pfx[4];
          nts.hdr_valid     = get_hdr_valid (3'd4, 3'd1, 1'b0, ca_h_val);
          nts.dllp_err      = 1'b0;
          nts.data_prot     = {DEF_PROT_2DW,data_prot[4*DW_PROT_WD +: 1*DW_PROT_WD]};
          chk_nts.status    = ONGOING;
        end

      pts.status==ONGOING && pts.nw==2'd0 && !tlp_idl[0] && !tlp_eot[0] && tlp_eot[1] && tlp_idl[2] && tlp_sot[3] && tlp_idl[4] :
        begin
          dec_case          = i_s_i_e_d__0;
          qdws[0].valid     = 1'b1;
          qdws[0].data      = {64'b0,data[0*32 +: 2*32]};
          qdws[0].dwen      = 4'b0011;
          qdws[0].sot       = 1'b0;
          qdws[0].eot       = 1'b1;
          qdw0_hdr_info     = get_hdr_info (3'd0, 3'd2, 1'b1, ca_h_info);
          qdws[0].has_pfx   = pts.has_pfx;
          qdws[0].hdr_valid = get_hdr_valid (3'd0, 3'd2, 1'b1, ca_h_val);
          qdws[0].dllp_err  = tlp_dllp_err[1];
          qdws[0].data_prot = {DEF_PROT_2DW,data_prot[0*DW_PROT_WD +: 2*DW_PROT_WD]};

          qdws[1].valid     = 1'b0;
          qdws[1].data      = 128'b0;
          qdws[1].dwen      = 4'b0000;
          qdws[1].sot       = 1'b0;
          qdws[1].eot       = 1'b0;
          qdw1_hdr_info     = DEFAULT_HDR_INFO;
          qdws[1].has_pfx   = 1'b0;
          qdws[1].hdr_valid = 1'b0;
          qdws[1].dllp_err  = 1'b0;
          qdws[1].data_prot = DEF_PROT_4DW;

          nts.nw            = 2'd1;
          nts.data          = {64'b0,data[3*32 +: 1*32]};
          nts.sot           = 1'b1;
          nts.eot           = 1'b0;
          nts_hdr_info      = get_hdr_info (3'd3, 3'd1, 1'b0, ca_h_info);
          nts.has_pfx       = tlp_pfx[3];
          nts.hdr_valid     = get_hdr_valid (3'd3, 3'd1, 1'b0, ca_h_val);
          nts.dllp_err      = 1'b0;
          nts.data_prot     = {DEF_PROT_2DW,data_prot[3*DW_PROT_WD +: 1*DW_PROT_WD]};
          chk_nts.status    = ONGOING;
        end

      pts.status==ONGOING && pts.nw==2'd0 && !tlp_idl[0] && !tlp_eot[0] && tlp_eot[1] && tlp_idl[2] && tlp_sot[3] && !tlp_idl[4] && !tlp_eot[4] :
        begin
          dec_case          = d_s_i_e_d__0;
          qdws[0].valid     = 1'b1;
          qdws[0].data      = {64'b0,data[0*32 +: 2*32]};
          qdws[0].dwen      = 4'b0011;
          qdws[0].sot       = 1'b0;
          qdws[0].eot       = 1'b1;
          qdw0_hdr_info     = get_hdr_info (3'd0, 3'd2, 1'b1, ca_h_info);
          qdws[0].has_pfx   = pts.has_pfx;
          qdws[0].hdr_valid = get_hdr_valid (3'd0, 3'd2, 1'b1, ca_h_val);
          qdws[0].dllp_err  = tlp_dllp_err[1];
          qdws[0].data_prot = {DEF_PROT_2DW,data_prot[0*DW_PROT_WD +: 2*DW_PROT_WD]};

          qdws[1].valid     = 1'b0;
          qdws[1].data      = 128'b0;
          qdws[1].dwen      = 4'b0000;
          qdws[1].sot       = 1'b0;
          qdws[1].eot       = 1'b0;
          qdw1_hdr_info     = DEFAULT_HDR_INFO;
          qdws[1].has_pfx   = 1'b0;
          qdws[1].hdr_valid = 1'b0;
          qdws[1].dllp_err  = 1'b0;
          qdws[1].data_prot = DEF_PROT_4DW;

          nts.nw            = 2'd2;
          nts.data          = {32'b0,data[3*32 +: 2*32]};
          nts.sot           = 1'b1;
          nts.eot           = 1'b0;
          nts_hdr_info      = get_hdr_info (3'd3, 3'd2, 1'b0, ca_h_info);
          nts.has_pfx       = tlp_pfx[3];
          nts.hdr_valid     = get_hdr_valid (3'd3, 3'd2, 1'b0, ca_h_val);
          nts.dllp_err      = 1'b0;
          nts.data_prot     = {DEF_PROT_1DW,data_prot[3*DW_PROT_WD +: 2*DW_PROT_WD]};
          chk_nts.status    = ONGOING;
        end

      pts.status==ONGOING && pts.nw==2'd0 && !tlp_idl[0] && !tlp_eot[0] && tlp_eot[1] && tlp_sot[2] && tlp_idl[3] && tlp_idl[4] :
        begin
          dec_case          = i_i_s_e_d__0;
          qdws[0].valid     = 1'b1;
          qdws[0].data      = {64'b0,data[0*32 +: 2*32]};
          qdws[0].dwen      = 4'b0011;
          qdws[0].sot       = 1'b0;
          qdws[0].eot       = 1'b1;
          qdw0_hdr_info     = get_hdr_info (3'd0, 3'd2, 1'b1, ca_h_info);
          qdws[0].has_pfx   = pts.has_pfx;
          qdws[0].hdr_valid = get_hdr_valid (3'd0, 3'd2, 1'b1, ca_h_val);
          qdws[0].dllp_err  = tlp_dllp_err[1];
          qdws[0].data_prot = {DEF_PROT_2DW,data_prot[0*DW_PROT_WD +: 2*DW_PROT_WD]};

          qdws[1].valid     = 1'b0;
          qdws[1].data      = 128'b0;
          qdws[1].dwen      = 4'b0000;
          qdws[1].sot       = 1'b0;
          qdws[1].eot       = 1'b0;
          qdw1_hdr_info     = DEFAULT_HDR_INFO;
          qdws[1].has_pfx   = 1'b0;
          qdws[1].hdr_valid = 1'b0;
          qdws[1].dllp_err  = 1'b0;
          qdws[1].data_prot = DEF_PROT_4DW;

          nts.nw            = 2'd1;
          nts.data          = {64'b0,data[2*32 +: 1*32]};
          nts.sot           = 1'b1;
          nts.eot           = 1'b0;
          nts_hdr_info      = get_hdr_info (3'd2, 3'd1, 1'b0, ca_h_info);
          nts.has_pfx       = tlp_pfx[2];
          nts.hdr_valid     = get_hdr_valid (3'd2, 3'd1, 1'b0, ca_h_val);
          nts.dllp_err      = 1'b0;
          nts.data_prot     = {DEF_PROT_2DW,data_prot[2*DW_PROT_WD +: 1*DW_PROT_WD]};
          chk_nts.status    = ONGOING;
        end

      pts.status==ONGOING && pts.nw==2'd0 && !tlp_idl[0] && !tlp_eot[0] && tlp_eot[1] && tlp_sot[2] && !tlp_idl[3] && !tlp_eot[3] && tlp_idl[4] :
        begin
          dec_case          = i_d_s_e_d__0;
          qdws[0].valid     = 1'b1;
          qdws[0].data      = {64'b0,data[0*32 +: 2*32]};
          qdws[0].dwen      = 4'b0011;
          qdws[0].sot       = 1'b0;
          qdws[0].eot       = 1'b1;
          qdw0_hdr_info     = get_hdr_info (3'd0, 3'd2, 1'b1, ca_h_info);
          qdws[0].has_pfx   = pts.has_pfx;
          qdws[0].hdr_valid = get_hdr_valid (3'd0, 3'd2, 1'b1, ca_h_val);
          qdws[0].dllp_err  = tlp_dllp_err[1];
          qdws[0].data_prot = {DEF_PROT_2DW,data_prot[0*DW_PROT_WD +: 2*DW_PROT_WD]};

          qdws[1].valid     = 1'b0;
          qdws[1].data      = 128'b0;
          qdws[1].dwen      = 4'b0000;
          qdws[1].sot       = 1'b0;
          qdws[1].eot       = 1'b0;
          qdw1_hdr_info     = DEFAULT_HDR_INFO;
          qdws[1].has_pfx   = 1'b0;
          qdws[1].hdr_valid = 1'b0;
          qdws[1].dllp_err  = 1'b0;
          qdws[1].data_prot = DEF_PROT_4DW;

          nts.nw            = 2'd2;
          nts.data          = {32'b0,data[2*32 +: 2*32]};
          nts.sot           = 1'b1;
          nts.eot           = 1'b0;
          nts_hdr_info      = get_hdr_info (3'd2, 3'd2, 1'b0, ca_h_info);
          nts.has_pfx       = tlp_pfx[2];
          nts.hdr_valid     = get_hdr_valid (3'd2, 3'd2, 1'b0, ca_h_val);
          nts.dllp_err      = 1'b0;
          nts.data_prot     = {DEF_PROT_1DW,data_prot[2*DW_PROT_WD +: 2*DW_PROT_WD]};
          chk_nts.status    = ONGOING;
        end

      pts.status==ONGOING && pts.nw==2'd0 && !tlp_idl[0] && !tlp_eot[0] && tlp_eot[1] && tlp_sot[2] && !tlp_idl[3] && !tlp_eot[3] && tlp_eot[4] :
        begin
          dec_case          = e_d_s_e_d__0;
          qdws[0].valid     = 1'b1;
          qdws[0].data      = {64'b0,data[0*32 +: 2*32]};
          qdws[0].dwen      = 4'b0011;
          qdws[0].sot       = 1'b0;
          qdws[0].eot       = 1'b1;
          qdw0_hdr_info     = get_hdr_info (3'd0, 3'd2, 1'b1, ca_h_info);
          qdws[0].has_pfx   = pts.has_pfx;
          qdws[0].hdr_valid = get_hdr_valid (3'd0, 3'd2, 1'b1, ca_h_val);
          qdws[0].dllp_err  = tlp_dllp_err[1];
          qdws[0].data_prot = {DEF_PROT_2DW,data_prot[0*DW_PROT_WD +: 2*DW_PROT_WD]};

          qdws[1].valid     = 1'b1;
          qdws[1].data      = {32'b0,data[2*32 +: 3*32]};
          qdws[1].dwen      = 4'b0111;
          qdws[1].sot       = 1'b1;
          qdws[1].eot       = 1'b1;
          qdw1_hdr_info     = get_hdr_info (3'd2, 3'd3, 1'b0, ca_h_info);
          qdws[1].has_pfx   = tlp_pfx[2];
          qdws[1].hdr_valid = get_hdr_valid (3'd2, 3'd3, 1'b0, ca_h_val);
          qdws[1].dllp_err  = tlp_dllp_err[4];
          qdws[1].data_prot = {DEF_PROT_1DW,data_prot[2*DW_PROT_WD +: 3*DW_PROT_WD]};

          nts.nw            = 2'd0;
          nts.data          = 96'b0;
          nts.sot           = 1'b0;
          nts.eot           = 1'b0;
          nts_hdr_info      = DEFAULT_HDR_INFO;
          nts.has_pfx       = 1'b0;
          nts.hdr_valid     = 1'b0;
          nts.dllp_err      = 1'b0;
          nts.data_prot     = DEF_PROT_3DW;
          chk_nts.status    = NOTHING;
        end

      pts.status==ONGOING && pts.nw==2'd0 && !tlp_idl[0] && !tlp_eot[0] && tlp_eot[1] && tlp_sot[2] && !tlp_idl[3] && !tlp_eot[3] && !tlp_idl[4] && !tlp_eot[4] :
        begin
          dec_case          = d_d_s_e_d__0;
          qdws[0].valid     = 1'b1;
          qdws[0].data      = {64'b0,data[0*32 +: 2*32]};
          qdws[0].dwen      = 4'b0011;
          qdws[0].sot       = 1'b0;
          qdws[0].eot       = 1'b1;
          qdw0_hdr_info     = get_hdr_info (3'd0, 3'd2, 1'b1, ca_h_info);
          qdws[0].has_pfx   = pts.has_pfx;
          qdws[0].hdr_valid = get_hdr_valid (3'd0, 3'd2, 1'b1, ca_h_val);
          qdws[0].dllp_err  = tlp_dllp_err[1];
          qdws[0].data_prot = {DEF_PROT_2DW,data_prot[0*DW_PROT_WD +: 2*DW_PROT_WD]};

          qdws[1].valid     = 1'b0;
          qdws[1].data      = 128'b0;
          qdws[1].dwen      = 4'b0000;
          qdws[1].sot       = 1'b0;
          qdws[1].eot       = 1'b0;
          qdw1_hdr_info     = DEFAULT_HDR_INFO;
          qdws[1].has_pfx   = 1'b0;
          qdws[1].hdr_valid = 1'b0;
          qdws[1].dllp_err  = 1'b0;
          qdws[1].data_prot = DEF_PROT_4DW;

          nts.nw            = 2'd3;
          nts.data          = data[2*32 +: 3*32];
          nts.sot           = 1'b1;
          nts.eot           = 1'b0;
          nts_hdr_info      = get_hdr_info (3'd2, 3'd3, 1'b0, ca_h_info);
          nts.has_pfx       = tlp_pfx[2];
          nts.hdr_valid     = get_hdr_valid (3'd2, 3'd3, 1'b0, ca_h_val);
          nts.dllp_err      = 1'b0;
          nts.data_prot     = data_prot[2*DW_PROT_WD +: 3*DW_PROT_WD];
          chk_nts.status    = ONGOING;
        end

      pts.status==ONGOING && pts.nw==2'd0 && !tlp_idl[0] && !tlp_eot[0] && !tlp_idl[1] && !tlp_eot[1] && tlp_idl[2] && tlp_idl[3] && tlp_idl[4] :
        begin
          dec_case          = i_i_i_d_d__0;
          qdws[0].valid     = 1'b0;
          qdws[0].data      = 128'b0;
          qdws[0].dwen      = 4'b0000;
          qdws[0].sot       = 1'b0;
          qdws[0].eot       = 1'b0;
          qdw0_hdr_info     = DEFAULT_HDR_INFO;
          qdws[0].has_pfx   = 1'b0;
          qdws[0].hdr_valid = 1'b0;
          qdws[0].dllp_err  = 1'b0;
          qdws[0].data_prot = DEF_PROT_4DW;

          qdws[1].valid     = 1'b0;
          qdws[1].data      = 128'b0;
          qdws[1].dwen      = 4'b0000;
          qdws[1].sot       = 1'b0;
          qdws[1].eot       = 1'b0;
          qdw1_hdr_info     = DEFAULT_HDR_INFO;
          qdws[1].has_pfx   = 1'b0;
          qdws[1].hdr_valid = 1'b0;
          qdws[1].dllp_err  = 1'b0;
          qdws[1].data_prot = DEF_PROT_4DW;

          nts.nw            = 2'd2;
          nts.data          = {32'b0,data[0*32 +: 2*32]};
          nts.sot           = 1'b0;
          nts.eot           = 1'b0;
          nts_hdr_info      = get_hdr_info (3'd0, 3'd2, 1'b1, ca_h_info);
          nts.has_pfx       = pts.has_pfx;
          nts.hdr_valid     = get_hdr_valid (3'd0, 3'd2, 1'b1, ca_h_val);
          nts.dllp_err      = 1'b0;
          nts.data_prot     = {DEF_PROT_1DW,data_prot[0*DW_PROT_WD +: 2*DW_PROT_WD]};
          chk_nts.status    = ONGOING;
        end

      pts.status==ONGOING && pts.nw==2'd0 && !tlp_idl[0] && !tlp_eot[0] && !tlp_idl[1] && !tlp_eot[1] && tlp_eot[2] && tlp_idl[3] && tlp_idl[4] :
        begin
          dec_case          = i_i_e_d_d__0;
          qdws[0].valid     = 1'b1;
          qdws[0].data      = {32'b0,data[0*32 +: 3*32]};
          qdws[0].dwen      = 4'b0111;
          qdws[0].sot       = 1'b0;
          qdws[0].eot       = 1'b1;
          qdw0_hdr_info     = get_hdr_info (3'd0, 3'd3, 1'b1, ca_h_info);
          qdws[0].has_pfx   = pts.has_pfx;
          qdws[0].hdr_valid = get_hdr_valid (3'd0, 3'd3, 1'b1, ca_h_val);
          qdws[0].dllp_err  = tlp_dllp_err[2];
          qdws[0].data_prot = {DEF_PROT_1DW,data_prot[0*DW_PROT_WD +: 3*DW_PROT_WD]};

          qdws[1].valid     = 1'b0;
          qdws[1].data      = 128'b0;
          qdws[1].dwen      = 4'b0000;
          qdws[1].sot       = 1'b0;
          qdws[1].eot       = 1'b0;
          qdw1_hdr_info     = DEFAULT_HDR_INFO;
          qdws[1].has_pfx   = 1'b0;
          qdws[1].hdr_valid = 1'b0;
          qdws[1].dllp_err  = 1'b0;
          qdws[1].data_prot = DEF_PROT_4DW;

          nts.nw            = 2'd0;
          nts.data          = 96'b0;
          nts.sot           = 1'b0;
          nts.eot           = 1'b0;
          nts_hdr_info      = DEFAULT_HDR_INFO;
          nts.has_pfx       = 1'b0;
          nts.hdr_valid     = 1'b0;
          nts.dllp_err      = 1'b0;
          nts.data_prot     = DEF_PROT_3DW;
          chk_nts.status    = NOTHING;
        end

      pts.status==ONGOING && pts.nw==2'd0 && !tlp_idl[0] && !tlp_eot[0] && !tlp_idl[1] && !tlp_eot[1] && tlp_eot[2] && tlp_idl[3] && tlp_sot[4] :
        begin
          dec_case          = s_i_e_d_d__0;
          qdws[0].valid     = 1'b1;
          qdws[0].data      = {32'b0,data[0*32 +: 3*32]};
          qdws[0].dwen      = 4'b0111;
          qdws[0].sot       = 1'b0;
          qdws[0].eot       = 1'b1;
          qdw0_hdr_info     = get_hdr_info (3'd0, 3'd3, 1'b1, ca_h_info);
          qdws[0].has_pfx   = pts.has_pfx;
          qdws[0].hdr_valid = get_hdr_valid (3'd0, 3'd3, 1'b1, ca_h_val);
          qdws[0].dllp_err  = tlp_dllp_err[2];
          qdws[0].data_prot = {DEF_PROT_1DW,data_prot[0*DW_PROT_WD +: 3*DW_PROT_WD]};

          qdws[1].valid     = 1'b0;
          qdws[1].data      = 128'b0;
          qdws[1].dwen      = 4'b0000;
          qdws[1].sot       = 1'b0;
          qdws[1].eot       = 1'b0;
          qdw1_hdr_info     = DEFAULT_HDR_INFO;
          qdws[1].has_pfx   = 1'b0;
          qdws[1].hdr_valid = 1'b0;
          qdws[1].dllp_err  = 1'b0;
          qdws[1].data_prot = DEF_PROT_4DW;

          nts.nw            = 2'd1;
          nts.data          = {64'b0,data[4*32 +: 1*32]};
          nts.sot           = 1'b1;
          nts.eot           = 1'b0;
          nts_hdr_info      = get_hdr_info (3'd4, 3'd1, 1'b0, ca_h_info);
          nts.has_pfx       = tlp_pfx[4];
          nts.hdr_valid     = get_hdr_valid (3'd4, 3'd1, 1'b0, ca_h_val);
          nts.dllp_err      = 1'b0;
          nts.data_prot     = {DEF_PROT_2DW,data_prot[4*DW_PROT_WD +: 1*DW_PROT_WD]};
          chk_nts.status    = ONGOING;
        end

      pts.status==ONGOING && pts.nw==2'd0 && !tlp_idl[0] && !tlp_eot[0] && !tlp_idl[1] && !tlp_eot[1] && tlp_eot[2] && tlp_sot[3] && tlp_idl[4] :
        begin
          dec_case          = i_s_e_d_d__0;
          qdws[0].valid     = 1'b1;
          qdws[0].data      = {32'b0,data[0*32 +: 3*32]};
          qdws[0].dwen      = 4'b0111;
          qdws[0].sot       = 1'b0;
          qdws[0].eot       = 1'b1;
          qdw0_hdr_info     = get_hdr_info (3'd0, 3'd3, 1'b1, ca_h_info);
          qdws[0].has_pfx   = pts.has_pfx;
          qdws[0].hdr_valid = get_hdr_valid (3'd0, 3'd3, 1'b1, ca_h_val);
          qdws[0].dllp_err  = tlp_dllp_err[2];
          qdws[0].data_prot = {DEF_PROT_1DW,data_prot[0*DW_PROT_WD +: 3*DW_PROT_WD]};

          qdws[1].valid     = 1'b0;
          qdws[1].data      = 128'b0;
          qdws[1].dwen      = 4'b0000;
          qdws[1].sot       = 1'b0;
          qdws[1].eot       = 1'b0;
          qdw1_hdr_info     = DEFAULT_HDR_INFO;
          qdws[1].has_pfx   = 1'b0;
          qdws[1].hdr_valid = 1'b0;
          qdws[1].dllp_err  = 1'b0;
          qdws[1].data_prot = DEF_PROT_4DW;

          nts.nw            = 2'd1;
          nts.data          = {64'b0,data[3*32 +: 1*32]};
          nts.sot           = 1'b1;
          nts.eot           = 1'b0;
          nts_hdr_info      = get_hdr_info (3'd3, 3'd1, 1'b0, ca_h_info);
          nts.has_pfx       = tlp_pfx[3];
          nts.hdr_valid     = get_hdr_valid (3'd3, 3'd1, 1'b0, ca_h_val);
          nts.dllp_err      = 1'b0;
          nts.data_prot     = {DEF_PROT_2DW,data_prot[3*DW_PROT_WD +: 1*DW_PROT_WD]};
          chk_nts.status    = ONGOING;
        end

      pts.status==ONGOING && pts.nw==2'd0 && !tlp_idl[0] && !tlp_eot[0] && !tlp_idl[1] && !tlp_eot[1] && tlp_eot[2] && tlp_sot[3] && !tlp_idl[4] && !tlp_eot[4] :
        begin
          dec_case          = d_s_e_d_d__0;
          qdws[0].valid     = 1'b1;
          qdws[0].data      = {32'b0,data[0*32 +: 3*32]};
          qdws[0].dwen      = 4'b0111;
          qdws[0].sot       = 1'b0;
          qdws[0].eot       = 1'b1;
          qdw0_hdr_info     = get_hdr_info (3'd0, 3'd3, 1'b1, ca_h_info);
          qdws[0].has_pfx   = pts.has_pfx;
          qdws[0].hdr_valid = get_hdr_valid (3'd0, 3'd3, 1'b1, ca_h_val);
          qdws[0].dllp_err  = tlp_dllp_err[2];
          qdws[0].data_prot = {DEF_PROT_1DW,data_prot[0*DW_PROT_WD +: 3*DW_PROT_WD]};

          qdws[1].valid     = 1'b0;
          qdws[1].data      = 128'b0;
          qdws[1].dwen      = 4'b0000;
          qdws[1].sot       = 1'b0;
          qdws[1].eot       = 1'b0;
          qdw1_hdr_info     = DEFAULT_HDR_INFO;
          qdws[1].has_pfx   = 1'b0;
          qdws[1].hdr_valid = 1'b0;
          qdws[1].dllp_err  = 1'b0;
          qdws[1].data_prot = DEF_PROT_4DW;

          nts.nw            = 2'd2;
          nts.data          = {32'b0,data[3*32 +: 2*32]};
          nts.sot           = 1'b1;
          nts.eot           = 1'b0;
          nts_hdr_info      = get_hdr_info (3'd3, 3'd2, 1'b0, ca_h_info);
          nts.has_pfx       = tlp_pfx[3];
          nts.hdr_valid     = get_hdr_valid (3'd3, 3'd2, 1'b0, ca_h_val);
          nts.dllp_err      = 1'b0;
          nts.data_prot     = {DEF_PROT_1DW,data_prot[3*DW_PROT_WD +: 2*DW_PROT_WD]};
          chk_nts.status    = ONGOING;
        end

      pts.status==ONGOING && pts.nw==2'd0 && !tlp_idl[0] && !tlp_eot[0] && !tlp_idl[1] && !tlp_eot[1] && !tlp_idl[2] && !tlp_eot[2] && tlp_idl[3] && tlp_idl[4] :
        begin
          dec_case          = i_i_d_d_d__0;
          qdws[0].valid     = 1'b0;
          qdws[0].data      = 128'b0;
          qdws[0].dwen      = 4'b0000;
          qdws[0].sot       = 1'b0;
          qdws[0].eot       = 1'b0;
          qdw0_hdr_info     = DEFAULT_HDR_INFO;
          qdws[0].has_pfx   = 1'b0;
          qdws[0].hdr_valid = 1'b0;
          qdws[0].dllp_err  = 1'b0;
          qdws[0].data_prot = DEF_PROT_4DW;

          qdws[1].valid     = 1'b0;
          qdws[1].data      = 128'b0;
          qdws[1].dwen      = 4'b0000;
          qdws[1].sot       = 1'b0;
          qdws[1].eot       = 1'b0;
          qdw1_hdr_info     = DEFAULT_HDR_INFO;
          qdws[1].has_pfx   = 1'b0;
          qdws[1].hdr_valid = 1'b0;
          qdws[1].dllp_err  = 1'b0;
          qdws[1].data_prot = DEF_PROT_4DW;

          nts.nw            = 2'd3;
          nts.data          = data[0*32 +: 3*32];
          nts.sot           = 1'b0;
          nts.eot           = 1'b0;
          nts_hdr_info      = get_hdr_info (3'd0, 3'd3, 1'b1, ca_h_info);
          nts.has_pfx       = pts.has_pfx;
          nts.hdr_valid     = get_hdr_valid (3'd0, 3'd3, 1'b1, ca_h_val);
          nts.dllp_err      = 1'b0;
          nts.data_prot     = data_prot[0*DW_PROT_WD +: 3*DW_PROT_WD];
          chk_nts.status    = ONGOING;
        end

      pts.status==ONGOING && pts.nw==2'd0 && !tlp_idl[0] && !tlp_eot[0] && !tlp_idl[1] && !tlp_eot[1] && !tlp_idl[2] && !tlp_eot[2] && tlp_eot[3] && tlp_idl[4] :
        begin
          dec_case          = i_e_d_d_d__0;
          qdws[0].valid     = 1'b1;
          qdws[0].data      = data[0*32 +: 4*32];
          qdws[0].dwen      = 4'b1111;
          qdws[0].sot       = 1'b0;
          qdws[0].eot       = 1'b1;
          qdw0_hdr_info     = get_hdr_info (3'd0, 3'd4, 1'b1, ca_h_info);
          qdws[0].has_pfx   = pts.has_pfx;
          qdws[0].hdr_valid = get_hdr_valid (3'd0, 3'd4, 1'b1, ca_h_val);
          qdws[0].dllp_err  = tlp_dllp_err[3];
          qdws[0].data_prot = data_prot[0*DW_PROT_WD +: 4*DW_PROT_WD];

          qdws[1].valid     = 1'b0;
          qdws[1].data      = 128'b0;
          qdws[1].dwen      = 4'b0000;
          qdws[1].sot       = 1'b0;
          qdws[1].eot       = 1'b0;
          qdw1_hdr_info     = DEFAULT_HDR_INFO;
          qdws[1].has_pfx   = 1'b0;
          qdws[1].hdr_valid = 1'b0;
          qdws[1].dllp_err  = 1'b0;
          qdws[1].data_prot = DEF_PROT_4DW;

          nts.nw            = 2'd0;
          nts.data          = 96'b0;
          nts.sot           = 1'b0;
          nts.eot           = 1'b0;
          nts_hdr_info      = DEFAULT_HDR_INFO;
          nts.has_pfx       = 1'b0;
          nts.hdr_valid     = 1'b0;
          nts.dllp_err      = 1'b0;
          nts.data_prot     = DEF_PROT_3DW;
          chk_nts.status    = NOTHING;
        end

      pts.status==ONGOING && pts.nw==2'd0 && !tlp_idl[0] && !tlp_eot[0] && !tlp_idl[1] && !tlp_eot[1] && !tlp_idl[2] && !tlp_eot[2] && tlp_eot[3] && tlp_sot[4] :
        begin
          dec_case          = s_e_d_d_d__0;
          qdws[0].valid     = 1'b1;
          qdws[0].data      = data[0*32 +: 4*32];
          qdws[0].dwen      = 4'b1111;
          qdws[0].sot       = 1'b0;
          qdws[0].eot       = 1'b1;
          qdw0_hdr_info     = get_hdr_info (3'd0, 3'd4, 1'b1, ca_h_info);
          qdws[0].has_pfx   = pts.has_pfx;
          qdws[0].hdr_valid = get_hdr_valid (3'd0, 3'd4, 1'b1, ca_h_val);
          qdws[0].dllp_err  = tlp_dllp_err[3];
          qdws[0].data_prot = data_prot[0*DW_PROT_WD +: 4*DW_PROT_WD];

          qdws[1].valid     = 1'b0;
          qdws[1].data      = 128'b0;
          qdws[1].dwen      = 4'b0000;
          qdws[1].sot       = 1'b0;
          qdws[1].eot       = 1'b0;
          qdw1_hdr_info     = DEFAULT_HDR_INFO;
          qdws[1].has_pfx   = 1'b0;
          qdws[1].hdr_valid = 1'b0;
          qdws[1].dllp_err  = 1'b0;
          qdws[1].data_prot = DEF_PROT_4DW;

          nts.nw            = 2'd1;
          nts.data          = {64'b0,data[4*32 +: 1*32]};
          nts.sot           = 1'b1;
          nts.eot           = 1'b0;
          nts_hdr_info      = get_hdr_info (3'd4, 3'd1, 1'b0, ca_h_info);
          nts.has_pfx       = tlp_pfx[4];
          nts.hdr_valid     = get_hdr_valid (3'd4, 3'd1, 1'b0, ca_h_val);
          nts.dllp_err      = 1'b0;
          nts.data_prot     = {DEF_PROT_2DW,data_prot[4*DW_PROT_WD +: 1*DW_PROT_WD]};
          chk_nts.status    = ONGOING;
        end

      pts.status==ONGOING && pts.nw==2'd0 && !tlp_idl[0] && !tlp_eot[0] && !tlp_idl[1] && !tlp_eot[1] && !tlp_idl[2] && !tlp_eot[2] && !tlp_idl[3] && !tlp_eot[3] && tlp_idl[4] :
        begin
          dec_case          = i_d_d_d_d__0;
          qdws[0].valid     = 1'b1;
          qdws[0].data      = data[0*32 +: 4*32];
          qdws[0].dwen      = 4'b1111;
          qdws[0].sot       = 1'b0;
          qdws[0].eot       = 1'b0;
          qdw0_hdr_info     = get_hdr_info (3'd0, 3'd4, 1'b1, ca_h_info);
          qdws[0].has_pfx   = pts.has_pfx;
          qdws[0].hdr_valid = get_hdr_valid (3'd0, 3'd4, 1'b1, ca_h_val);
          qdws[0].dllp_err  = 1'b0;
          qdws[0].data_prot = data_prot[0*DW_PROT_WD +: 4*DW_PROT_WD];

          qdws[1].valid     = 1'b0;
          qdws[1].data      = 128'b0;
          qdws[1].dwen      = 4'b0000;
          qdws[1].sot       = 1'b0;
          qdws[1].eot       = 1'b0;
          qdw1_hdr_info     = DEFAULT_HDR_INFO;
          qdws[1].has_pfx   = 1'b0;
          qdws[1].hdr_valid = 1'b0;
          qdws[1].dllp_err  = 1'b0;
          qdws[1].data_prot = DEF_PROT_4DW;

          nts.nw            = 2'd0;
          nts.data          = 96'b0;
          nts.sot           = 1'b0;
          nts.eot           = 1'b0;
          nts_hdr_info      = get_hdr_info (3'd0, 3'd4, 1'b1, ca_h_info);
          nts.has_pfx       = pts.has_pfx;
          nts.hdr_valid     = 1'b0;
          nts.dllp_err      = 1'b0;
          nts.data_prot     = DEF_PROT_3DW;
          chk_nts.status    = ONGOING;
        end

      pts.status==ONGOING && pts.nw==2'd0 && !tlp_idl[0] && !tlp_eot[0] && !tlp_idl[1] && !tlp_eot[1] && !tlp_idl[2] && !tlp_eot[2] && !tlp_idl[3] && !tlp_eot[3] && tlp_eot[4] :
        begin
          dec_case          = e_d_d_d_d__0;
          qdws[0].valid     = 1'b1;
          qdws[0].data      = data[0*32 +: 4*32];
          qdws[0].dwen      = 4'b1111;
          qdws[0].sot       = 1'b0;
          qdws[0].eot       = 1'b0;
          qdw0_hdr_info     = get_hdr_info (3'd0, 3'd4, 1'b1, ca_h_info);
          qdws[0].has_pfx   = pts.has_pfx;
          qdws[0].hdr_valid = get_hdr_valid (3'd0, 3'd4, 1'b1, ca_h_val);
          qdws[0].dllp_err  = 1'b0;
          qdws[0].data_prot = data_prot[0*DW_PROT_WD +: 4*DW_PROT_WD];

          qdws[1].valid     = 1'b1;
          qdws[1].data      = {96'b0,data[4*32 +: 1*32]};
          qdws[1].dwen      = 4'b0001;
          qdws[1].sot       = 1'b0;
          qdws[1].eot       = 1'b1;
          qdw1_hdr_info     = get_hdr_info (3'd0, 3'd5, 1'b1, ca_h_info);
          qdws[1].has_pfx   = pts.has_pfx;
          qdws[1].hdr_valid = get_hdr_valid (3'd4, 3'd1, 1'b0, ca_h_val);
          qdws[1].dllp_err  = tlp_dllp_err[4];
          qdws[1].data_prot = {DEF_PROT_3DW,data_prot[4*DW_PROT_WD +: 1*DW_PROT_WD]};

          nts.nw            = 2'd0;
          nts.data          = 96'b0;
          nts.sot           = 1'b0;
          nts.eot           = 1'b0;
          nts_hdr_info      = get_hdr_info (3'd0, 3'd4, 1'b1, ca_h_info);
          nts.has_pfx       = pts.has_pfx;
          nts.hdr_valid     = 1'b0;
          nts.dllp_err      = 1'b0;
          nts.data_prot     = DEF_PROT_3DW;
          chk_nts.status    = NOTHING;
        end

      pts.status==ONGOING && pts.nw==2'd0 && !tlp_idl[0] && !tlp_eot[0] && !tlp_idl[1] && !tlp_eot[1] && !tlp_idl[2] && !tlp_eot[2] && !tlp_idl[3] && !tlp_eot[3] && !tlp_idl[4] && !tlp_eot[4] :
        begin
          dec_case          = d_d_d_d_d__0;
          qdws[0].valid     = 1'b1;
          qdws[0].data      = data[0*32 +: 4*32];
          qdws[0].dwen      = 4'b1111;
          qdws[0].sot       = 1'b0;
          qdws[0].eot       = 1'b0;
          qdw0_hdr_info     = get_hdr_info (3'd0, 3'd4, 1'b1, ca_h_info);
          qdws[0].has_pfx   = pts.has_pfx;
          qdws[0].hdr_valid = get_hdr_valid (3'd0, 3'd4, 1'b1, ca_h_val);
          qdws[0].dllp_err  = 1'b0;
          qdws[0].data_prot = data_prot[0*DW_PROT_WD +: 4*DW_PROT_WD];

          qdws[1].valid     = 1'b0;
          qdws[1].data      = 128'b0;
          qdws[1].dwen      = 4'b0000;
          qdws[1].sot       = 1'b0;
          qdws[1].eot       = 1'b0;
          qdw1_hdr_info     = DEFAULT_HDR_INFO;
          qdws[1].has_pfx   = 1'b0;
          qdws[1].hdr_valid = 1'b0;
          qdws[1].dllp_err  = 1'b0;
          qdws[1].data_prot = DEF_PROT_4DW;

          nts.nw            = 2'd1;
          nts.data          = {64'b0,data[4*32 +: 1*32]};
          nts.sot           = 1'b0;
          nts.eot           = 1'b0;
          nts_hdr_info      = get_hdr_info (3'd0, 3'd5, 1'b1, ca_h_info);
          nts.has_pfx       = pts.has_pfx;
          nts.hdr_valid     = get_hdr_valid (3'd4, 3'd1, 1'b0, ca_h_val);
          nts.dllp_err      = 1'b0;
          nts.data_prot     = {DEF_PROT_2DW,data_prot[4*DW_PROT_WD +: 1*DW_PROT_WD]};
          chk_nts.status    = ONGOING;
        end

      pts.status==ONGOING && pts.nw==2'd1 && tlp_eot[0] && tlp_idl[1] && tlp_idl[2] && tlp_idl[3] && tlp_idl[4] :
        begin
          dec_case          = i_i_i_i_e__1;
          qdws[0].valid     = 1'b1;
          qdws[0].data      = {64'b0,data[0*32 +: 1*32],pts.data[0+: 1*32]};
          qdws[0].dwen      = 4'b0011;
          qdws[0].sot       = pts.sot;
          qdws[0].eot       = 1'b1;
          qdw0_hdr_info     = get_hdr_info (3'd0, 3'd1, 1'b1, ca_h_info);
          qdws[0].has_pfx   = pts.has_pfx;
          qdws[0].hdr_valid = get_hdr_valid (3'd0, 3'd1, 1'b1, ca_h_val);
          qdws[0].dllp_err  = tlp_dllp_err[0];
          qdws[0].data_prot = {DEF_PROT_2DW,data_prot[0*DW_PROT_WD +: 1*DW_PROT_WD],pts.data_prot[0+: 1*DW_PROT_WD]};

          qdws[1].valid     = 1'b0;
          qdws[1].data      = 128'b0;
          qdws[1].dwen      = 4'b0000;
          qdws[1].sot       = 1'b0;
          qdws[1].eot       = 1'b0;
          qdw1_hdr_info     = DEFAULT_HDR_INFO;
          qdws[1].has_pfx   = 1'b0;
          qdws[1].hdr_valid = 1'b0;
          qdws[1].dllp_err  = 1'b0;
          qdws[1].data_prot = DEF_PROT_4DW;

          nts.nw            = 2'd0;
          nts.data          = 96'b0;
          nts.sot           = 1'b0;
          nts.eot           = 1'b0;
          nts_hdr_info      = DEFAULT_HDR_INFO;
          nts.has_pfx       = 1'b0;
          nts.hdr_valid     = 1'b0;
          nts.dllp_err      = 1'b0;
          nts.data_prot     = DEF_PROT_3DW;
          chk_nts.status    = NOTHING;
        end

      pts.status==ONGOING && pts.nw==2'd1 && tlp_eot[0] && tlp_idl[1] && tlp_idl[2] && tlp_idl[3] && tlp_sot[4] :
        begin
          dec_case          = s_i_i_i_e__1;
          qdws[0].valid     = 1'b1;
          qdws[0].data      = {64'b0,data[0*32 +: 1*32],pts.data[0+: 1*32]};
          qdws[0].dwen      = 4'b0011;
          qdws[0].sot       = pts.sot;
          qdws[0].eot       = 1'b1;
          qdw0_hdr_info     = get_hdr_info (3'd0, 3'd1, 1'b1, ca_h_info);
          qdws[0].has_pfx   = pts.has_pfx;
          qdws[0].hdr_valid = get_hdr_valid (3'd0, 3'd1, 1'b1, ca_h_val);
          qdws[0].dllp_err  = tlp_dllp_err[0];
          qdws[0].data_prot = {DEF_PROT_2DW,data_prot[0*DW_PROT_WD +: 1*DW_PROT_WD],pts.data_prot[0+: 1*DW_PROT_WD]};

          qdws[1].valid     = 1'b0;
          qdws[1].data      = 128'b0;
          qdws[1].dwen      = 4'b0000;
          qdws[1].sot       = 1'b0;
          qdws[1].eot       = 1'b0;
          qdw1_hdr_info     = DEFAULT_HDR_INFO;
          qdws[1].has_pfx   = 1'b0;
          qdws[1].hdr_valid = 1'b0;
          qdws[1].dllp_err  = 1'b0;
          qdws[1].data_prot = DEF_PROT_4DW;

          nts.nw            = 2'd1;
          nts.data          = {64'b0,data[4*32 +: 1*32]};
          nts.sot           = 1'b1;
          nts.eot           = 1'b0;
          nts_hdr_info      = get_hdr_info (3'd4, 3'd1, 1'b0, ca_h_info);
          nts.has_pfx       = tlp_pfx[4];
          nts.hdr_valid     = get_hdr_valid (3'd4, 3'd1, 1'b0, ca_h_val);
          nts.dllp_err      = 1'b0;
          nts.data_prot     = {DEF_PROT_2DW,data_prot[4*DW_PROT_WD +: 1*DW_PROT_WD]};
          chk_nts.status    = ONGOING;
        end

      pts.status==ONGOING && pts.nw==2'd1 && tlp_eot[0] && tlp_idl[1] && tlp_idl[2] && tlp_sot[3] && tlp_idl[4] :
        begin
          dec_case          = i_s_i_i_e__1;
          qdws[0].valid     = 1'b1;
          qdws[0].data      = {64'b0,data[0*32 +: 1*32],pts.data[0+: 1*32]};
          qdws[0].dwen      = 4'b0011;
          qdws[0].sot       = pts.sot;
          qdws[0].eot       = 1'b1;
          qdw0_hdr_info     = get_hdr_info (3'd0, 3'd1, 1'b1, ca_h_info);
          qdws[0].has_pfx   = pts.has_pfx;
          qdws[0].hdr_valid = get_hdr_valid (3'd0, 3'd1, 1'b1, ca_h_val);
          qdws[0].dllp_err  = tlp_dllp_err[0];
          qdws[0].data_prot = {DEF_PROT_2DW,data_prot[0*DW_PROT_WD +: 1*DW_PROT_WD],pts.data_prot[0+: 1*DW_PROT_WD]};

          qdws[1].valid     = 1'b0;
          qdws[1].data      = 128'b0;
          qdws[1].dwen      = 4'b0000;
          qdws[1].sot       = 1'b0;
          qdws[1].eot       = 1'b0;
          qdw1_hdr_info     = DEFAULT_HDR_INFO;
          qdws[1].has_pfx   = 1'b0;
          qdws[1].hdr_valid = 1'b0;
          qdws[1].dllp_err  = 1'b0;
          qdws[1].data_prot = DEF_PROT_4DW;

          nts.nw            = 2'd1;
          nts.data          = {64'b0,data[3*32 +: 1*32]};
          nts.sot           = 1'b1;
          nts.eot           = 1'b0;
          nts_hdr_info      = get_hdr_info (3'd3, 3'd1, 1'b0, ca_h_info);
          nts.has_pfx       = tlp_pfx[3];
          nts.hdr_valid     = get_hdr_valid (3'd3, 3'd1, 1'b0, ca_h_val);
          nts.dllp_err      = 1'b0;
          nts.data_prot     = {DEF_PROT_2DW,data_prot[3*DW_PROT_WD +: 1*DW_PROT_WD]};
          chk_nts.status    = ONGOING;
        end

      pts.status==ONGOING && pts.nw==2'd1 && tlp_eot[0] && tlp_idl[1] && tlp_idl[2] && tlp_sot[3] && !tlp_idl[4] && !tlp_eot[4] :
        begin
          dec_case          = d_s_i_i_e__1;
          qdws[0].valid     = 1'b1;
          qdws[0].data      = {64'b0,data[0*32 +: 1*32],pts.data[0+: 1*32]};
          qdws[0].dwen      = 4'b0011;
          qdws[0].sot       = pts.sot;
          qdws[0].eot       = 1'b1;
          qdw0_hdr_info     = get_hdr_info (3'd0, 3'd1, 1'b1, ca_h_info);
          qdws[0].has_pfx   = pts.has_pfx;
          qdws[0].hdr_valid = get_hdr_valid (3'd0, 3'd1, 1'b1, ca_h_val);
          qdws[0].dllp_err  = tlp_dllp_err[0];
          qdws[0].data_prot = {DEF_PROT_2DW,data_prot[0*DW_PROT_WD +: 1*DW_PROT_WD],pts.data_prot[0+: 1*DW_PROT_WD]};

          qdws[1].valid     = 1'b0;
          qdws[1].data      = 128'b0;
          qdws[1].dwen      = 4'b0000;
          qdws[1].sot       = 1'b0;
          qdws[1].eot       = 1'b0;
          qdw1_hdr_info     = DEFAULT_HDR_INFO;
          qdws[1].has_pfx   = 1'b0;
          qdws[1].hdr_valid = 1'b0;
          qdws[1].dllp_err  = 1'b0;
          qdws[1].data_prot = DEF_PROT_4DW;

          nts.nw            = 2'd2;
          nts.data          = {32'b0,data[3*32 +: 2*32]};
          nts.sot           = 1'b1;
          nts.eot           = 1'b0;
          nts_hdr_info      = get_hdr_info (3'd3, 3'd2, 1'b0, ca_h_info);
          nts.has_pfx       = tlp_pfx[3];
          nts.hdr_valid     = get_hdr_valid (3'd3, 3'd2, 1'b0, ca_h_val);
          nts.dllp_err      = 1'b0;
          nts.data_prot     = {DEF_PROT_1DW,data_prot[3*DW_PROT_WD +: 2*DW_PROT_WD]};
          chk_nts.status    = ONGOING;
        end

      pts.status==ONGOING && pts.nw==2'd1 && tlp_eot[0] && tlp_idl[1] && tlp_sot[2] && tlp_idl[3] && tlp_idl[4] :
        begin
          dec_case          = i_i_s_i_e__1;
          qdws[0].valid     = 1'b1;
          qdws[0].data      = {64'b0,data[0*32 +: 1*32],pts.data[0+: 1*32]};
          qdws[0].dwen      = 4'b0011;
          qdws[0].sot       = pts.sot;
          qdws[0].eot       = 1'b1;
          qdw0_hdr_info     = get_hdr_info (3'd0, 3'd1, 1'b1, ca_h_info);
          qdws[0].has_pfx   = pts.has_pfx;
          qdws[0].hdr_valid = get_hdr_valid (3'd0, 3'd1, 1'b1, ca_h_val);
          qdws[0].dllp_err  = tlp_dllp_err[0];
          qdws[0].data_prot = {DEF_PROT_2DW,data_prot[0*DW_PROT_WD +: 1*DW_PROT_WD],pts.data_prot[0+: 1*DW_PROT_WD]};

          qdws[1].valid     = 1'b0;
          qdws[1].data      = 128'b0;
          qdws[1].dwen      = 4'b0000;
          qdws[1].sot       = 1'b0;
          qdws[1].eot       = 1'b0;
          qdw1_hdr_info     = DEFAULT_HDR_INFO;
          qdws[1].has_pfx   = 1'b0;
          qdws[1].hdr_valid = 1'b0;
          qdws[1].dllp_err  = 1'b0;
          qdws[1].data_prot = DEF_PROT_4DW;

          nts.nw            = 2'd1;
          nts.data          = {64'b0,data[2*32 +: 1*32]};
          nts.sot           = 1'b1;
          nts.eot           = 1'b0;
          nts_hdr_info      = get_hdr_info (3'd2, 3'd1, 1'b0, ca_h_info);
          nts.has_pfx       = tlp_pfx[2];
          nts.hdr_valid     = get_hdr_valid (3'd2, 3'd1, 1'b0, ca_h_val);
          nts.dllp_err      = 1'b0;
          nts.data_prot     = {DEF_PROT_2DW,data_prot[2*DW_PROT_WD +: 1*DW_PROT_WD]};
          chk_nts.status    = ONGOING;
        end

      pts.status==ONGOING && pts.nw==2'd1 && tlp_eot[0] && tlp_idl[1] && tlp_sot[2] && !tlp_idl[3] && !tlp_eot[3] && tlp_idl[4] :
        begin
          dec_case          = i_d_s_i_e__1;
          qdws[0].valid     = 1'b1;
          qdws[0].data      = {64'b0,data[0*32 +: 1*32],pts.data[0+: 1*32]};
          qdws[0].dwen      = 4'b0011;
          qdws[0].sot       = pts.sot;
          qdws[0].eot       = 1'b1;
          qdw0_hdr_info     = get_hdr_info (3'd0, 3'd1, 1'b1, ca_h_info);
          qdws[0].has_pfx   = pts.has_pfx;
          qdws[0].hdr_valid = get_hdr_valid (3'd0, 3'd1, 1'b1, ca_h_val);
          qdws[0].dllp_err  = tlp_dllp_err[0];
          qdws[0].data_prot = {DEF_PROT_2DW,data_prot[0*DW_PROT_WD +: 1*DW_PROT_WD],pts.data_prot[0+: 1*DW_PROT_WD]};

          qdws[1].valid     = 1'b0;
          qdws[1].data      = 128'b0;
          qdws[1].dwen      = 4'b0000;
          qdws[1].sot       = 1'b0;
          qdws[1].eot       = 1'b0;
          qdw1_hdr_info     = DEFAULT_HDR_INFO;
          qdws[1].has_pfx   = 1'b0;
          qdws[1].hdr_valid = 1'b0;
          qdws[1].dllp_err  = 1'b0;
          qdws[1].data_prot = DEF_PROT_4DW;

          nts.nw            = 2'd2;
          nts.data          = {32'b0,data[2*32 +: 2*32]};
          nts.sot           = 1'b1;
          nts.eot           = 1'b0;
          nts_hdr_info      = get_hdr_info (3'd2, 3'd2, 1'b0, ca_h_info);
          nts.has_pfx       = tlp_pfx[2];
          nts.hdr_valid     = get_hdr_valid (3'd2, 3'd2, 1'b0, ca_h_val);
          nts.dllp_err      = 1'b0;
          nts.data_prot     = {DEF_PROT_1DW,data_prot[2*DW_PROT_WD +: 2*DW_PROT_WD]};
          chk_nts.status    = ONGOING;
        end

      pts.status==ONGOING && pts.nw==2'd1 && tlp_eot[0] && tlp_idl[1] && tlp_sot[2] && !tlp_idl[3] && !tlp_eot[3] && tlp_eot[4] :
        begin
          dec_case          = e_d_s_i_e__1;
          qdws[0].valid     = 1'b1;
          qdws[0].data      = {64'b0,data[0*32 +: 1*32],pts.data[0+: 1*32]};
          qdws[0].dwen      = 4'b0011;
          qdws[0].sot       = pts.sot;
          qdws[0].eot       = 1'b1;
          qdw0_hdr_info     = get_hdr_info (3'd0, 3'd1, 1'b1, ca_h_info);
          qdws[0].has_pfx   = pts.has_pfx;
          qdws[0].hdr_valid = get_hdr_valid (3'd0, 3'd1, 1'b1, ca_h_val);
          qdws[0].dllp_err  = tlp_dllp_err[0];
          qdws[0].data_prot = {DEF_PROT_2DW,data_prot[0*DW_PROT_WD +: 1*DW_PROT_WD],pts.data_prot[0+: 1*DW_PROT_WD]};

          qdws[1].valid     = 1'b1;
          qdws[1].data      = {32'b0,data[2*32 +: 3*32]};
          qdws[1].dwen      = 4'b0111;
          qdws[1].sot       = 1'b1;
          qdws[1].eot       = 1'b1;
          qdw1_hdr_info     = get_hdr_info (3'd2, 3'd3, 1'b0, ca_h_info);
          qdws[1].has_pfx   = tlp_pfx[2];
          qdws[1].hdr_valid = get_hdr_valid (3'd2, 3'd3, 1'b0, ca_h_val);
          qdws[1].dllp_err  = tlp_dllp_err[4];
          qdws[1].data_prot = {DEF_PROT_1DW,data_prot[2*DW_PROT_WD +: 3*DW_PROT_WD]};

          nts.nw            = 2'd0;
          nts.data          = 96'b0;
          nts.sot           = 1'b0;
          nts.eot           = 1'b0;
          nts_hdr_info      = DEFAULT_HDR_INFO;
          nts.has_pfx       = 1'b0;
          nts.hdr_valid     = 1'b0;
          nts.dllp_err      = 1'b0;
          nts.data_prot     = DEF_PROT_3DW;
          chk_nts.status    = NOTHING;
        end

      pts.status==ONGOING && pts.nw==2'd1 && tlp_eot[0] && tlp_idl[1] && tlp_sot[2] && !tlp_idl[3] && !tlp_eot[3] && !tlp_idl[4] && !tlp_eot[4] :
        begin
          dec_case          = d_d_s_i_e__1;
          qdws[0].valid     = 1'b1;
          qdws[0].data      = {64'b0,data[0*32 +: 1*32],pts.data[0+: 1*32]};
          qdws[0].dwen      = 4'b0011;
          qdws[0].sot       = pts.sot;
          qdws[0].eot       = 1'b1;
          qdw0_hdr_info     = get_hdr_info (3'd0, 3'd1, 1'b1, ca_h_info);
          qdws[0].has_pfx   = pts.has_pfx;
          qdws[0].hdr_valid = get_hdr_valid (3'd0, 3'd1, 1'b1, ca_h_val);
          qdws[0].dllp_err  = tlp_dllp_err[0];
          qdws[0].data_prot = {DEF_PROT_2DW,data_prot[0*DW_PROT_WD +: 1*DW_PROT_WD],pts.data_prot[0+: 1*DW_PROT_WD]};

          qdws[1].valid     = 1'b0;
          qdws[1].data      = 128'b0;
          qdws[1].dwen      = 4'b0000;
          qdws[1].sot       = 1'b0;
          qdws[1].eot       = 1'b0;
          qdw1_hdr_info     = DEFAULT_HDR_INFO;
          qdws[1].has_pfx   = 1'b0;
          qdws[1].hdr_valid = 1'b0;
          qdws[1].dllp_err  = 1'b0;
          qdws[1].data_prot = DEF_PROT_4DW;

          nts.nw            = 2'd3;
          nts.data          = data[2*32 +: 3*32];
          nts.sot           = 1'b1;
          nts.eot           = 1'b0;
          nts_hdr_info      = get_hdr_info (3'd2, 3'd3, 1'b0, ca_h_info);
          nts.has_pfx       = tlp_pfx[2];
          nts.hdr_valid     = get_hdr_valid (3'd2, 3'd3, 1'b0, ca_h_val);
          nts.dllp_err      = 1'b0;
          nts.data_prot     = data_prot[2*DW_PROT_WD +: 3*DW_PROT_WD];
          chk_nts.status    = ONGOING;
        end

      pts.status==ONGOING && pts.nw==2'd1 && tlp_eot[0] && tlp_sot[1] && tlp_idl[2] && tlp_idl[3] && tlp_idl[4] :
        begin
          dec_case          = i_i_i_s_e__1;
          qdws[0].valid     = 1'b1;
          qdws[0].data      = {64'b0,data[0*32 +: 1*32],pts.data[0+: 1*32]};
          qdws[0].dwen      = 4'b0011;
          qdws[0].sot       = pts.sot;
          qdws[0].eot       = 1'b1;
          qdw0_hdr_info     = get_hdr_info (3'd0, 3'd1, 1'b1, ca_h_info);
          qdws[0].has_pfx   = pts.has_pfx;
          qdws[0].hdr_valid = get_hdr_valid (3'd0, 3'd1, 1'b1, ca_h_val);
          qdws[0].dllp_err  = tlp_dllp_err[0];
          qdws[0].data_prot = {DEF_PROT_2DW,data_prot[0*DW_PROT_WD +: 1*DW_PROT_WD],pts.data_prot[0+: 1*DW_PROT_WD]};

          qdws[1].valid     = 1'b0;
          qdws[1].data      = 128'b0;
          qdws[1].dwen      = 4'b0000;
          qdws[1].sot       = 1'b0;
          qdws[1].eot       = 1'b0;
          qdw1_hdr_info     = DEFAULT_HDR_INFO;
          qdws[1].has_pfx   = 1'b0;
          qdws[1].hdr_valid = 1'b0;
          qdws[1].dllp_err  = 1'b0;
          qdws[1].data_prot = DEF_PROT_4DW;

          nts.nw            = 2'd1;
          nts.data          = {64'b0,data[1*32 +: 1*32]};
          nts.sot           = 1'b1;
          nts.eot           = 1'b0;
          nts_hdr_info      = get_hdr_info (3'd1, 3'd1, 1'b0, ca_h_info);
          nts.has_pfx       = tlp_pfx[1];
          nts.hdr_valid     = get_hdr_valid (3'd1, 3'd1, 1'b0, ca_h_val);
          nts.dllp_err      = 1'b0;
          nts.data_prot     = {DEF_PROT_2DW,data_prot[1*DW_PROT_WD +: 1*DW_PROT_WD]};
          chk_nts.status    = ONGOING;
        end

      pts.status==ONGOING && pts.nw==2'd1 && tlp_eot[0] && tlp_sot[1] && !tlp_idl[2] && !tlp_eot[2] && tlp_idl[3] && tlp_idl[4] :
        begin
          dec_case          = i_i_d_s_e__1;
          qdws[0].valid     = 1'b1;
          qdws[0].data      = {64'b0,data[0*32 +: 1*32],pts.data[0+: 1*32]};
          qdws[0].dwen      = 4'b0011;
          qdws[0].sot       = pts.sot;
          qdws[0].eot       = 1'b1;
          qdw0_hdr_info     = get_hdr_info (3'd0, 3'd1, 1'b1, ca_h_info);
          qdws[0].has_pfx   = pts.has_pfx;
          qdws[0].hdr_valid = get_hdr_valid (3'd0, 3'd1, 1'b1, ca_h_val);
          qdws[0].dllp_err  = tlp_dllp_err[0];
          qdws[0].data_prot = {DEF_PROT_2DW,data_prot[0*DW_PROT_WD +: 1*DW_PROT_WD],pts.data_prot[0+: 1*DW_PROT_WD]};

          qdws[1].valid     = 1'b0;
          qdws[1].data      = 128'b0;
          qdws[1].dwen      = 4'b0000;
          qdws[1].sot       = 1'b0;
          qdws[1].eot       = 1'b0;
          qdw1_hdr_info     = DEFAULT_HDR_INFO;
          qdws[1].has_pfx   = 1'b0;
          qdws[1].hdr_valid = 1'b0;
          qdws[1].dllp_err  = 1'b0;
          qdws[1].data_prot = DEF_PROT_4DW;

          nts.nw            = 2'd2;
          nts.data          = {32'b0,data[1*32 +: 2*32]};
          nts.sot           = 1'b1;
          nts.eot           = 1'b0;
          nts_hdr_info      = get_hdr_info (3'd1, 3'd2, 1'b0, ca_h_info);
          nts.has_pfx       = tlp_pfx[1];
          nts.hdr_valid     = get_hdr_valid (3'd1, 3'd2, 1'b0, ca_h_val);
          nts.dllp_err      = 1'b0;
          nts.data_prot     = {DEF_PROT_1DW,data_prot[1*DW_PROT_WD +: 2*DW_PROT_WD]};
          chk_nts.status    = ONGOING;
        end

      pts.status==ONGOING && pts.nw==2'd1 && tlp_eot[0] && tlp_sot[1] && !tlp_idl[2] && !tlp_eot[2] && tlp_eot[3] && tlp_idl[4] :
        begin
          dec_case          = i_e_d_s_e__1;
          qdws[0].valid     = 1'b1;
          qdws[0].data      = {64'b0,data[0*32 +: 1*32],pts.data[0+: 1*32]};
          qdws[0].dwen      = 4'b0011;
          qdws[0].sot       = pts.sot;
          qdws[0].eot       = 1'b1;
          qdw0_hdr_info     = get_hdr_info (3'd0, 3'd1, 1'b1, ca_h_info);
          qdws[0].has_pfx   = pts.has_pfx;
          qdws[0].hdr_valid = get_hdr_valid (3'd0, 3'd1, 1'b1, ca_h_val);
          qdws[0].dllp_err  = tlp_dllp_err[0];
          qdws[0].data_prot = {DEF_PROT_2DW,data_prot[0*DW_PROT_WD +: 1*DW_PROT_WD],pts.data_prot[0+: 1*DW_PROT_WD]};

          qdws[1].valid     = 1'b1;
          qdws[1].data      = {32'b0,data[1*32 +: 3*32]};
          qdws[1].dwen      = 4'b0111;
          qdws[1].sot       = 1'b1;
          qdws[1].eot       = 1'b1;
          qdw1_hdr_info     = get_hdr_info (3'd1, 3'd3, 1'b0, ca_h_info);
          qdws[1].has_pfx   = tlp_pfx[1];
          qdws[1].hdr_valid = get_hdr_valid (3'd1, 3'd3, 1'b0, ca_h_val);
          qdws[1].dllp_err  = tlp_dllp_err[3];
          qdws[1].data_prot = {DEF_PROT_1DW,data_prot[1*DW_PROT_WD +: 3*DW_PROT_WD]};

          nts.nw            = 2'd0;
          nts.data          = 96'b0;
          nts.sot           = 1'b0;
          nts.eot           = 1'b0;
          nts_hdr_info      = DEFAULT_HDR_INFO;
          nts.has_pfx       = 1'b0;
          nts.hdr_valid     = 1'b0;
          nts.dllp_err      = 1'b0;
          nts.data_prot     = DEF_PROT_3DW;
          chk_nts.status    = NOTHING;
        end

      pts.status==ONGOING && pts.nw==2'd1 && tlp_eot[0] && tlp_sot[1] && !tlp_idl[2] && !tlp_eot[2] && tlp_eot[3] && tlp_sot[4] :
        begin
          dec_case          = s_e_d_s_e__1;
          qdws[0].valid     = 1'b1;
          qdws[0].data      = {64'b0,data[0*32 +: 1*32],pts.data[0+: 1*32]};
          qdws[0].dwen      = 4'b0011;
          qdws[0].sot       = pts.sot;
          qdws[0].eot       = 1'b1;
          qdw0_hdr_info     = get_hdr_info (3'd0, 3'd1, 1'b1, ca_h_info);
          qdws[0].has_pfx   = pts.has_pfx;
          qdws[0].hdr_valid = get_hdr_valid (3'd0, 3'd1, 1'b1, ca_h_val);
          qdws[0].dllp_err  = tlp_dllp_err[0];
          qdws[0].data_prot = {DEF_PROT_2DW,data_prot[0*DW_PROT_WD +: 1*DW_PROT_WD],pts.data_prot[0+: 1*DW_PROT_WD]};

          qdws[1].valid     = 1'b1;
          qdws[1].data      = {32'b0,data[1*32 +: 3*32]};
          qdws[1].dwen      = 4'b0111;
          qdws[1].sot       = 1'b1;
          qdws[1].eot       = 1'b1;
          qdw1_hdr_info     = get_hdr_info (3'd1, 3'd3, 1'b0, ca_h_info);
          qdws[1].has_pfx   = tlp_pfx[1];
          qdws[1].hdr_valid = get_hdr_valid (3'd1, 3'd3, 1'b0, ca_h_val);
          qdws[1].dllp_err  = tlp_dllp_err[3];
          qdws[1].data_prot = {DEF_PROT_1DW,data_prot[1*DW_PROT_WD +: 3*DW_PROT_WD]};

          nts.nw            = 2'd1;
          nts.data          = {64'b0,data[4*32 +: 1*32]};
          nts.sot           = 1'b1;
          nts.eot           = 1'b0;
          nts_hdr_info      = get_hdr_info (3'd4, 3'd1, 1'b0, ca_h_info);
          nts.has_pfx       = tlp_pfx[4];
          nts.hdr_valid     = get_hdr_valid (3'd4, 3'd1, 1'b0, ca_h_val);
          nts.dllp_err      = 1'b0;
          nts.data_prot     = {DEF_PROT_2DW,data_prot[4*DW_PROT_WD +: 1*DW_PROT_WD]};
          chk_nts.status    = ONGOING;
        end

      pts.status==ONGOING && pts.nw==2'd1 && tlp_eot[0] && tlp_sot[1] && !tlp_idl[2] && !tlp_eot[2] && !tlp_idl[3] && !tlp_eot[3] && tlp_idl[4] :
        begin
          dec_case          = i_d_d_s_e__1;
          qdws[0].valid     = 1'b1;
          qdws[0].data      = {64'b0,data[0*32 +: 1*32],pts.data[0+: 1*32]};
          qdws[0].dwen      = 4'b0011;
          qdws[0].sot       = pts.sot;
          qdws[0].eot       = 1'b1;
          qdw0_hdr_info     = get_hdr_info (3'd0, 3'd1, 1'b1, ca_h_info);
          qdws[0].has_pfx   = pts.has_pfx;
          qdws[0].hdr_valid = get_hdr_valid (3'd0, 3'd1, 1'b1, ca_h_val);
          qdws[0].dllp_err  = tlp_dllp_err[0];
          qdws[0].data_prot = {DEF_PROT_2DW,data_prot[0*DW_PROT_WD +: 1*DW_PROT_WD],pts.data_prot[0+: 1*DW_PROT_WD]};

          qdws[1].valid     = 1'b0;
          qdws[1].data      = 128'b0;
          qdws[1].dwen      = 4'b0000;
          qdws[1].sot       = 1'b0;
          qdws[1].eot       = 1'b0;
          qdw1_hdr_info     = DEFAULT_HDR_INFO;
          qdws[1].has_pfx   = 1'b0;
          qdws[1].hdr_valid = 1'b0;
          qdws[1].dllp_err  = 1'b0;
          qdws[1].data_prot = DEF_PROT_4DW;

          nts.nw            = 2'd3;
          nts.data          = data[1*32 +: 3*32];
          nts.sot           = 1'b1;
          nts.eot           = 1'b0;
          nts_hdr_info      = get_hdr_info (3'd1, 3'd3, 1'b0, ca_h_info);
          nts.has_pfx       = tlp_pfx[1];
          nts.hdr_valid     = get_hdr_valid (3'd1, 3'd3, 1'b0, ca_h_val);
          nts.dllp_err      = 1'b0;
          nts.data_prot     = data_prot[1*DW_PROT_WD +: 3*DW_PROT_WD];
          chk_nts.status    = ONGOING;
        end

      pts.status==ONGOING && pts.nw==2'd1 && tlp_eot[0] && tlp_sot[1] && !tlp_idl[2] && !tlp_eot[2] && !tlp_idl[3] && !tlp_eot[3] && tlp_eot[4] :
        begin
          dec_case          = e_d_d_s_e__1;
          qdws[0].valid     = 1'b1;
          qdws[0].data      = {64'b0,data[0*32 +: 1*32],pts.data[0+: 1*32]};
          qdws[0].dwen      = 4'b0011;
          qdws[0].sot       = pts.sot;
          qdws[0].eot       = 1'b1;
          qdw0_hdr_info     = get_hdr_info (3'd0, 3'd1, 1'b1, ca_h_info);
          qdws[0].has_pfx   = pts.has_pfx;
          qdws[0].hdr_valid = get_hdr_valid (3'd0, 3'd1, 1'b1, ca_h_val);
          qdws[0].dllp_err  = tlp_dllp_err[0];
          qdws[0].data_prot = {DEF_PROT_2DW,data_prot[0*DW_PROT_WD +: 1*DW_PROT_WD],pts.data_prot[0+: 1*DW_PROT_WD]};

          qdws[1].valid     = 1'b1;
          qdws[1].data      = data[1*32 +: 4*32];
          qdws[1].dwen      = 4'b1111;
          qdws[1].sot       = 1'b1;
          qdws[1].eot       = 1'b1;
          qdw1_hdr_info     = get_hdr_info (3'd1, 3'd4, 1'b0, ca_h_info);
          qdws[1].has_pfx   = tlp_pfx[1];
          qdws[1].hdr_valid = get_hdr_valid (3'd1, 3'd4, 1'b0, ca_h_val);
          qdws[1].dllp_err  = tlp_dllp_err[4];
          qdws[1].data_prot = data_prot[1*DW_PROT_WD +: 4*DW_PROT_WD];

          nts.nw            = 2'd0;
          nts.data          = 96'b0;
          nts.sot           = 1'b0;
          nts.eot           = 1'b0;
          nts_hdr_info      = DEFAULT_HDR_INFO;
          nts.has_pfx       = 1'b0;
          nts.hdr_valid     = 1'b0;
          nts.dllp_err      = 1'b0;
          nts.data_prot     = DEF_PROT_3DW;
          chk_nts.status    = NOTHING;
        end

      pts.status==ONGOING && pts.nw==2'd1 && tlp_eot[0] && tlp_sot[1] && !tlp_idl[2] && !tlp_eot[2] && !tlp_idl[3] && !tlp_eot[3] && !tlp_idl[4] && !tlp_eot[4] :
        begin
          dec_case          = d_d_d_s_e__1;
          qdws[0].valid     = 1'b1;
          qdws[0].data      = {64'b0,data[0*32 +: 1*32],pts.data[0+: 1*32]};
          qdws[0].dwen      = 4'b0011;
          qdws[0].sot       = pts.sot;
          qdws[0].eot       = 1'b1;
          qdw0_hdr_info     = get_hdr_info (3'd0, 3'd1, 1'b1, ca_h_info);
          qdws[0].has_pfx   = pts.has_pfx;
          qdws[0].hdr_valid = get_hdr_valid (3'd0, 3'd1, 1'b1, ca_h_val);
          qdws[0].dllp_err  = tlp_dllp_err[0];
          qdws[0].data_prot = {DEF_PROT_2DW,data_prot[0*DW_PROT_WD +: 1*DW_PROT_WD],pts.data_prot[0+: 1*DW_PROT_WD]};

          qdws[1].valid     = 1'b1;
          qdws[1].data      = data[1*32 +: 4*32];
          qdws[1].dwen      = 4'b1111;
          qdws[1].sot       = 1'b1;
          qdws[1].eot       = 1'b0;
          qdw1_hdr_info     = get_hdr_info (3'd1, 3'd4, 1'b0, ca_h_info);
          qdws[1].has_pfx   = tlp_pfx[1];
          qdws[1].hdr_valid = get_hdr_valid (3'd1, 3'd4, 1'b0, ca_h_val);
          qdws[1].dllp_err  = 1'b0;
          qdws[1].data_prot = data_prot[1*DW_PROT_WD +: 4*DW_PROT_WD];

          nts.nw            = 2'd0;
          nts.data          = 96'b0;
          nts.sot           = 1'b0;
          nts.eot           = 1'b0;
          nts_hdr_info      = get_hdr_info (3'd1, 3'd4, 1'b0, ca_h_info);
          nts.has_pfx       = tlp_pfx[1];
          nts.hdr_valid     = 1'b0;
          nts.dllp_err      = 1'b0;
          nts.data_prot     = DEF_PROT_3DW;
          chk_nts.status    = ONGOING;
        end

      pts.status==ONGOING && pts.nw==2'd1 && !tlp_idl[0] && !tlp_eot[0] && tlp_idl[1] && tlp_idl[2] && tlp_idl[3] && tlp_idl[4] :
        begin
          dec_case          = i_i_i_i_d__1;
          qdws[0].valid     = 1'b0;
          qdws[0].data      = 128'b0;
          qdws[0].dwen      = 4'b0000;
          qdws[0].sot       = 1'b0;
          qdws[0].eot       = 1'b0;
          qdw0_hdr_info     = DEFAULT_HDR_INFO;
          qdws[0].has_pfx   = 1'b0;
          qdws[0].hdr_valid = 1'b0;
          qdws[0].dllp_err  = 1'b0;
          qdws[0].data_prot = DEF_PROT_4DW;

          qdws[1].valid     = 1'b0;
          qdws[1].data      = 128'b0;
          qdws[1].dwen      = 4'b0000;
          qdws[1].sot       = 1'b0;
          qdws[1].eot       = 1'b0;
          qdw1_hdr_info     = DEFAULT_HDR_INFO;
          qdws[1].has_pfx   = 1'b0;
          qdws[1].hdr_valid = 1'b0;
          qdws[1].dllp_err  = 1'b0;
          qdws[1].data_prot = DEF_PROT_4DW;

          nts.nw            = 2'd2;
          nts.data          = {32'b0,data[0*32 +: 1*32],pts.data[0+: 1*32]};
          nts.sot           = pts.sot;
          nts.eot           = 1'b0;
          nts_hdr_info      = get_hdr_info (3'd0, 3'd1, 1'b1, ca_h_info);
          nts.has_pfx       = pts.has_pfx;
          nts.hdr_valid     = get_hdr_valid (3'd0, 3'd1, 1'b1, ca_h_val);
          nts.dllp_err      = 1'b0;
          nts.data_prot     = {DEF_PROT_1DW,data_prot[0*DW_PROT_WD +: 1*DW_PROT_WD],pts.data_prot[0+: 1*DW_PROT_WD]};
          chk_nts.status    = ONGOING;
        end

      pts.status==ONGOING && pts.nw==2'd1 && !tlp_idl[0] && !tlp_eot[0] && tlp_eot[1] && tlp_idl[2] && tlp_idl[3] && tlp_idl[4] :
        begin
          dec_case          = i_i_i_e_d__1;
          qdws[0].valid     = 1'b1;
          qdws[0].data      = {32'b0,data[0*32 +: 2*32],pts.data[0+: 1*32]};
          qdws[0].dwen      = 4'b0111;
          qdws[0].sot       = pts.sot;
          qdws[0].eot       = 1'b1;
          qdw0_hdr_info     = get_hdr_info (3'd0, 3'd2, 1'b1, ca_h_info);
          qdws[0].has_pfx   = pts.has_pfx;
          qdws[0].hdr_valid = get_hdr_valid (3'd0, 3'd2, 1'b1, ca_h_val);
          qdws[0].dllp_err  = tlp_dllp_err[1];
          qdws[0].data_prot = {DEF_PROT_1DW,data_prot[0*DW_PROT_WD +: 2*DW_PROT_WD],pts.data_prot[0+: 1*DW_PROT_WD]};

          qdws[1].valid     = 1'b0;
          qdws[1].data      = 128'b0;
          qdws[1].dwen      = 4'b0000;
          qdws[1].sot       = 1'b0;
          qdws[1].eot       = 1'b0;
          qdw1_hdr_info     = DEFAULT_HDR_INFO;
          qdws[1].has_pfx   = 1'b0;
          qdws[1].hdr_valid = 1'b0;
          qdws[1].dllp_err  = 1'b0;
          qdws[1].data_prot = DEF_PROT_4DW;

          nts.nw            = 2'd0;
          nts.data          = 96'b0;
          nts.sot           = 1'b0;
          nts.eot           = 1'b0;
          nts_hdr_info      = DEFAULT_HDR_INFO;
          nts.has_pfx       = 1'b0;
          nts.hdr_valid     = 1'b0;
          nts.dllp_err      = 1'b0;
          nts.data_prot     = DEF_PROT_3DW;
          chk_nts.status    = NOTHING;
        end

      pts.status==ONGOING && pts.nw==2'd1 && !tlp_idl[0] && !tlp_eot[0] && tlp_eot[1] && tlp_idl[2] && tlp_idl[3] && tlp_sot[4] :
        begin
          dec_case          = s_i_i_e_d__1;
          qdws[0].valid     = 1'b1;
          qdws[0].data      = {32'b0,data[0*32 +: 2*32],pts.data[0+: 1*32]};
          qdws[0].dwen      = 4'b0111;
          qdws[0].sot       = pts.sot;
          qdws[0].eot       = 1'b1;
          qdw0_hdr_info     = get_hdr_info (3'd0, 3'd2, 1'b1, ca_h_info);
          qdws[0].has_pfx   = pts.has_pfx;
          qdws[0].hdr_valid = get_hdr_valid (3'd0, 3'd2, 1'b1, ca_h_val);
          qdws[0].dllp_err  = tlp_dllp_err[1];
          qdws[0].data_prot = {DEF_PROT_1DW,data_prot[0*DW_PROT_WD +: 2*DW_PROT_WD],pts.data_prot[0+: 1*DW_PROT_WD]};

          qdws[1].valid     = 1'b0;
          qdws[1].data      = 128'b0;
          qdws[1].dwen      = 4'b0000;
          qdws[1].sot       = 1'b0;
          qdws[1].eot       = 1'b0;
          qdw1_hdr_info     = DEFAULT_HDR_INFO;
          qdws[1].has_pfx   = 1'b0;
          qdws[1].hdr_valid = 1'b0;
          qdws[1].dllp_err  = 1'b0;
          qdws[1].data_prot = DEF_PROT_4DW;

          nts.nw            = 2'd1;
          nts.data          = {64'b0,data[4*32 +: 1*32]};
          nts.sot           = 1'b1;
          nts.eot           = 1'b0;
          nts_hdr_info      = get_hdr_info (3'd4, 3'd1, 1'b0, ca_h_info);
          nts.has_pfx       = tlp_pfx[4];
          nts.hdr_valid     = get_hdr_valid (3'd4, 3'd1, 1'b0, ca_h_val);
          nts.dllp_err      = 1'b0;
          nts.data_prot     = {DEF_PROT_2DW,data_prot[4*DW_PROT_WD +: 1*DW_PROT_WD]};
          chk_nts.status    = ONGOING;
        end

      pts.status==ONGOING && pts.nw==2'd1 && !tlp_idl[0] && !tlp_eot[0] && tlp_eot[1] && tlp_idl[2] && tlp_sot[3] && tlp_idl[4] :
        begin
          dec_case          = i_s_i_e_d__1;
          qdws[0].valid     = 1'b1;
          qdws[0].data      = {32'b0,data[0*32 +: 2*32],pts.data[0+: 1*32]};
          qdws[0].dwen      = 4'b0111;
          qdws[0].sot       = pts.sot;
          qdws[0].eot       = 1'b1;
          qdw0_hdr_info     = get_hdr_info (3'd0, 3'd2, 1'b1, ca_h_info);
          qdws[0].has_pfx   = pts.has_pfx;
          qdws[0].hdr_valid = get_hdr_valid (3'd0, 3'd2, 1'b1, ca_h_val);
          qdws[0].dllp_err  = tlp_dllp_err[1];
          qdws[0].data_prot = {DEF_PROT_1DW,data_prot[0*DW_PROT_WD +: 2*DW_PROT_WD],pts.data_prot[0+: 1*DW_PROT_WD]};

          qdws[1].valid     = 1'b0;
          qdws[1].data      = 128'b0;
          qdws[1].dwen      = 4'b0000;
          qdws[1].sot       = 1'b0;
          qdws[1].eot       = 1'b0;
          qdw1_hdr_info     = DEFAULT_HDR_INFO;
          qdws[1].has_pfx   = 1'b0;
          qdws[1].hdr_valid = 1'b0;
          qdws[1].dllp_err  = 1'b0;
          qdws[1].data_prot = DEF_PROT_4DW;

          nts.nw            = 2'd1;
          nts.data          = {64'b0,data[3*32 +: 1*32]};
          nts.sot           = 1'b1;
          nts.eot           = 1'b0;
          nts_hdr_info      = get_hdr_info (3'd3, 3'd1, 1'b0, ca_h_info);
          nts.has_pfx       = tlp_pfx[3];
          nts.hdr_valid     = get_hdr_valid (3'd3, 3'd1, 1'b0, ca_h_val);
          nts.dllp_err      = 1'b0;
          nts.data_prot     = {DEF_PROT_2DW,data_prot[3*DW_PROT_WD +: 1*DW_PROT_WD]};
          chk_nts.status    = ONGOING;
        end

      pts.status==ONGOING && pts.nw==2'd1 && !tlp_idl[0] && !tlp_eot[0] && tlp_eot[1] && tlp_idl[2] && tlp_sot[3] && !tlp_idl[4] && !tlp_eot[4] :
        begin
          dec_case          = d_s_i_e_d__1;
          qdws[0].valid     = 1'b1;
          qdws[0].data      = {32'b0,data[0*32 +: 2*32],pts.data[0+: 1*32]};
          qdws[0].dwen      = 4'b0111;
          qdws[0].sot       = pts.sot;
          qdws[0].eot       = 1'b1;
          qdw0_hdr_info     = get_hdr_info (3'd0, 3'd2, 1'b1, ca_h_info);
          qdws[0].has_pfx   = pts.has_pfx;
          qdws[0].hdr_valid = get_hdr_valid (3'd0, 3'd2, 1'b1, ca_h_val);
          qdws[0].dllp_err  = tlp_dllp_err[1];
          qdws[0].data_prot = {DEF_PROT_1DW,data_prot[0*DW_PROT_WD +: 2*DW_PROT_WD],pts.data_prot[0+: 1*DW_PROT_WD]};

          qdws[1].valid     = 1'b0;
          qdws[1].data      = 128'b0;
          qdws[1].dwen      = 4'b0000;
          qdws[1].sot       = 1'b0;
          qdws[1].eot       = 1'b0;
          qdw1_hdr_info     = DEFAULT_HDR_INFO;
          qdws[1].has_pfx   = 1'b0;
          qdws[1].hdr_valid = 1'b0;
          qdws[1].dllp_err  = 1'b0;
          qdws[1].data_prot = DEF_PROT_4DW;

          nts.nw            = 2'd2;
          nts.data          = {32'b0,data[3*32 +: 2*32]};
          nts.sot           = 1'b1;
          nts.eot           = 1'b0;
          nts_hdr_info      = get_hdr_info (3'd3, 3'd2, 1'b0, ca_h_info);
          nts.has_pfx       = tlp_pfx[3];
          nts.hdr_valid     = get_hdr_valid (3'd3, 3'd2, 1'b0, ca_h_val);
          nts.dllp_err      = 1'b0;
          nts.data_prot     = {DEF_PROT_1DW,data_prot[3*DW_PROT_WD +: 2*DW_PROT_WD]};
          chk_nts.status    = ONGOING;
        end

      pts.status==ONGOING && pts.nw==2'd1 && !tlp_idl[0] && !tlp_eot[0] && tlp_eot[1] && tlp_sot[2] && tlp_idl[3] && tlp_idl[4] :
        begin
          dec_case          = i_i_s_e_d__1;
          qdws[0].valid     = 1'b1;
          qdws[0].data      = {32'b0,data[0*32 +: 2*32],pts.data[0+: 1*32]};
          qdws[0].dwen      = 4'b0111;
          qdws[0].sot       = pts.sot;
          qdws[0].eot       = 1'b1;
          qdw0_hdr_info     = get_hdr_info (3'd0, 3'd2, 1'b1, ca_h_info);
          qdws[0].has_pfx   = pts.has_pfx;
          qdws[0].hdr_valid = get_hdr_valid (3'd0, 3'd2, 1'b1, ca_h_val);
          qdws[0].dllp_err  = tlp_dllp_err[1];
          qdws[0].data_prot = {DEF_PROT_1DW,data_prot[0*DW_PROT_WD +: 2*DW_PROT_WD],pts.data_prot[0+: 1*DW_PROT_WD]};

          qdws[1].valid     = 1'b0;
          qdws[1].data      = 128'b0;
          qdws[1].dwen      = 4'b0000;
          qdws[1].sot       = 1'b0;
          qdws[1].eot       = 1'b0;
          qdw1_hdr_info     = DEFAULT_HDR_INFO;
          qdws[1].has_pfx   = 1'b0;
          qdws[1].hdr_valid = 1'b0;
          qdws[1].dllp_err  = 1'b0;
          qdws[1].data_prot = DEF_PROT_4DW;

          nts.nw            = 2'd1;
          nts.data          = {64'b0,data[2*32 +: 1*32]};
          nts.sot           = 1'b1;
          nts.eot           = 1'b0;
          nts_hdr_info      = get_hdr_info (3'd2, 3'd1, 1'b0, ca_h_info);
          nts.has_pfx       = tlp_pfx[2];
          nts.hdr_valid     = get_hdr_valid (3'd2, 3'd1, 1'b0, ca_h_val);
          nts.dllp_err      = 1'b0;
          nts.data_prot     = {DEF_PROT_2DW,data_prot[2*DW_PROT_WD +: 1*DW_PROT_WD]};
          chk_nts.status    = ONGOING;
        end

      pts.status==ONGOING && pts.nw==2'd1 && !tlp_idl[0] && !tlp_eot[0] && tlp_eot[1] && tlp_sot[2] && !tlp_idl[3] && !tlp_eot[3] && tlp_idl[4] :
        begin
          dec_case          = i_d_s_e_d__1;
          qdws[0].valid     = 1'b1;
          qdws[0].data      = {32'b0,data[0*32 +: 2*32],pts.data[0+: 1*32]};
          qdws[0].dwen      = 4'b0111;
          qdws[0].sot       = pts.sot;
          qdws[0].eot       = 1'b1;
          qdw0_hdr_info     = get_hdr_info (3'd0, 3'd2, 1'b1, ca_h_info);
          qdws[0].has_pfx   = pts.has_pfx;
          qdws[0].hdr_valid = get_hdr_valid (3'd0, 3'd2, 1'b1, ca_h_val);
          qdws[0].dllp_err  = tlp_dllp_err[1];
          qdws[0].data_prot = {DEF_PROT_1DW,data_prot[0*DW_PROT_WD +: 2*DW_PROT_WD],pts.data_prot[0+: 1*DW_PROT_WD]};

          qdws[1].valid     = 1'b0;
          qdws[1].data      = 128'b0;
          qdws[1].dwen      = 4'b0000;
          qdws[1].sot       = 1'b0;
          qdws[1].eot       = 1'b0;
          qdw1_hdr_info     = DEFAULT_HDR_INFO;
          qdws[1].has_pfx   = 1'b0;
          qdws[1].hdr_valid = 1'b0;
          qdws[1].dllp_err  = 1'b0;
          qdws[1].data_prot = DEF_PROT_4DW;

          nts.nw            = 2'd2;
          nts.data          = {32'b0,data[2*32 +: 2*32]};
          nts.sot           = 1'b1;
          nts.eot           = 1'b0;
          nts_hdr_info      = get_hdr_info (3'd2, 3'd2, 1'b0, ca_h_info);
          nts.has_pfx       = tlp_pfx[2];
          nts.hdr_valid     = get_hdr_valid (3'd2, 3'd2, 1'b0, ca_h_val);
          nts.dllp_err      = 1'b0;
          nts.data_prot     = {DEF_PROT_1DW,data_prot[2*DW_PROT_WD +: 2*DW_PROT_WD]};
          chk_nts.status    = ONGOING;
        end

      pts.status==ONGOING && pts.nw==2'd1 && !tlp_idl[0] && !tlp_eot[0] && tlp_eot[1] && tlp_sot[2] && !tlp_idl[3] && !tlp_eot[3] && tlp_eot[4] :
        begin
          dec_case          = e_d_s_e_d__1;
          qdws[0].valid     = 1'b1;
          qdws[0].data      = {32'b0,data[0*32 +: 2*32],pts.data[0+: 1*32]};
          qdws[0].dwen      = 4'b0111;
          qdws[0].sot       = pts.sot;
          qdws[0].eot       = 1'b1;
          qdw0_hdr_info     = get_hdr_info (3'd0, 3'd2, 1'b1, ca_h_info);
          qdws[0].has_pfx   = pts.has_pfx;
          qdws[0].hdr_valid = get_hdr_valid (3'd0, 3'd2, 1'b1, ca_h_val);
          qdws[0].dllp_err  = tlp_dllp_err[1];
          qdws[0].data_prot = {DEF_PROT_1DW,data_prot[0*DW_PROT_WD +: 2*DW_PROT_WD],pts.data_prot[0+: 1*DW_PROT_WD]};

          qdws[1].valid     = 1'b1;
          qdws[1].data      = {32'b0,data[2*32 +: 3*32]};
          qdws[1].dwen      = 4'b0111;
          qdws[1].sot       = 1'b1;
          qdws[1].eot       = 1'b1;
          qdw1_hdr_info     = get_hdr_info (3'd2, 3'd3, 1'b0, ca_h_info);
          qdws[1].has_pfx   = tlp_pfx[2];
          qdws[1].hdr_valid = get_hdr_valid (3'd2, 3'd3, 1'b0, ca_h_val);
          qdws[1].dllp_err  = tlp_dllp_err[4];
          qdws[1].data_prot = {DEF_PROT_1DW,data_prot[2*DW_PROT_WD +: 3*DW_PROT_WD]};

          nts.nw            = 2'd0;
          nts.data          = 96'b0;
          nts.sot           = 1'b0;
          nts.eot           = 1'b0;
          nts_hdr_info      = DEFAULT_HDR_INFO;
          nts.has_pfx       = 1'b0;
          nts.hdr_valid     = 1'b0;
          nts.dllp_err      = 1'b0;
          nts.data_prot     = DEF_PROT_3DW;
          chk_nts.status    = NOTHING;
        end

      pts.status==ONGOING && pts.nw==2'd1 && !tlp_idl[0] && !tlp_eot[0] && tlp_eot[1] && tlp_sot[2] && !tlp_idl[3] && !tlp_eot[3] && !tlp_idl[4] && !tlp_eot[4] :
        begin
          dec_case          = d_d_s_e_d__1;
          qdws[0].valid     = 1'b1;
          qdws[0].data      = {32'b0,data[0*32 +: 2*32],pts.data[0+: 1*32]};
          qdws[0].dwen      = 4'b0111;
          qdws[0].sot       = pts.sot;
          qdws[0].eot       = 1'b1;
          qdw0_hdr_info     = get_hdr_info (3'd0, 3'd2, 1'b1, ca_h_info);
          qdws[0].has_pfx   = pts.has_pfx;
          qdws[0].hdr_valid = get_hdr_valid (3'd0, 3'd2, 1'b1, ca_h_val);
          qdws[0].dllp_err  = tlp_dllp_err[1];
          qdws[0].data_prot = {DEF_PROT_1DW,data_prot[0*DW_PROT_WD +: 2*DW_PROT_WD],pts.data_prot[0+: 1*DW_PROT_WD]};

          qdws[1].valid     = 1'b0;
          qdws[1].data      = 128'b0;
          qdws[1].dwen      = 4'b0000;
          qdws[1].sot       = 1'b0;
          qdws[1].eot       = 1'b0;
          qdw1_hdr_info     = DEFAULT_HDR_INFO;
          qdws[1].has_pfx   = 1'b0;
          qdws[1].hdr_valid = 1'b0;
          qdws[1].dllp_err  = 1'b0;
          qdws[1].data_prot = DEF_PROT_4DW;

          nts.nw            = 2'd3;
          nts.data          = data[2*32 +: 3*32];
          nts.sot           = 1'b1;
          nts.eot           = 1'b0;
          nts_hdr_info      = get_hdr_info (3'd2, 3'd3, 1'b0, ca_h_info);
          nts.has_pfx       = tlp_pfx[2];
          nts.hdr_valid     = get_hdr_valid (3'd2, 3'd3, 1'b0, ca_h_val);
          nts.dllp_err      = 1'b0;
          nts.data_prot     = data_prot[2*DW_PROT_WD +: 3*DW_PROT_WD];
          chk_nts.status    = ONGOING;
        end

      pts.status==ONGOING && pts.nw==2'd1 && !tlp_idl[0] && !tlp_eot[0] && !tlp_idl[1] && !tlp_eot[1] && tlp_idl[2] && tlp_idl[3] && tlp_idl[4] :
        begin
          dec_case          = i_i_i_d_d__1;
          qdws[0].valid     = 1'b0;
          qdws[0].data      = 128'b0;
          qdws[0].dwen      = 4'b0000;
          qdws[0].sot       = 1'b0;
          qdws[0].eot       = 1'b0;
          qdw0_hdr_info     = DEFAULT_HDR_INFO;
          qdws[0].has_pfx   = 1'b0;
          qdws[0].hdr_valid = 1'b0;
          qdws[0].dllp_err  = 1'b0;
          qdws[0].data_prot = DEF_PROT_4DW;

          qdws[1].valid     = 1'b0;
          qdws[1].data      = 128'b0;
          qdws[1].dwen      = 4'b0000;
          qdws[1].sot       = 1'b0;
          qdws[1].eot       = 1'b0;
          qdw1_hdr_info     = DEFAULT_HDR_INFO;
          qdws[1].has_pfx   = 1'b0;
          qdws[1].hdr_valid = 1'b0;
          qdws[1].dllp_err  = 1'b0;
          qdws[1].data_prot = DEF_PROT_4DW;

          nts.nw            = 2'd3;
          nts.data          = {data[0*32 +: 2*32],pts.data[0+: 1*32]};
          nts.sot           = pts.sot;
          nts.eot           = 1'b0;
          nts_hdr_info      = get_hdr_info (3'd0, 3'd2, 1'b1, ca_h_info);
          nts.has_pfx       = pts.has_pfx;
          nts.hdr_valid     = get_hdr_valid (3'd0, 3'd2, 1'b1, ca_h_val);
          nts.dllp_err      = 1'b0;
          nts.data_prot     = {data_prot[0*DW_PROT_WD +: 2*DW_PROT_WD],pts.data_prot[0+: 1*DW_PROT_WD]};
          chk_nts.status    = ONGOING;
        end

      pts.status==ONGOING && pts.nw==2'd1 && !tlp_idl[0] && !tlp_eot[0] && !tlp_idl[1] && !tlp_eot[1] && tlp_eot[2] && tlp_idl[3] && tlp_idl[4] :
        begin
          dec_case          = i_i_e_d_d__1;
          qdws[0].valid     = 1'b1;
          qdws[0].data      = {data[0*32 +: 3*32],pts.data[0+: 1*32]};
          qdws[0].dwen      = 4'b1111;
          qdws[0].sot       = pts.sot;
          qdws[0].eot       = 1'b1;
          qdw0_hdr_info     = get_hdr_info (3'd0, 3'd3, 1'b1, ca_h_info);
          qdws[0].has_pfx   = pts.has_pfx;
          qdws[0].hdr_valid = get_hdr_valid (3'd0, 3'd3, 1'b1, ca_h_val);
          qdws[0].dllp_err  = tlp_dllp_err[2];
          qdws[0].data_prot = {data_prot[0*DW_PROT_WD +: 3*DW_PROT_WD],pts.data_prot[0+: 1*DW_PROT_WD]};

          qdws[1].valid     = 1'b0;
          qdws[1].data      = 128'b0;
          qdws[1].dwen      = 4'b0000;
          qdws[1].sot       = 1'b0;
          qdws[1].eot       = 1'b0;
          qdw1_hdr_info     = DEFAULT_HDR_INFO;
          qdws[1].has_pfx   = 1'b0;
          qdws[1].hdr_valid = 1'b0;
          qdws[1].dllp_err  = 1'b0;
          qdws[1].data_prot = DEF_PROT_4DW;

          nts.nw            = 2'd0;
          nts.data          = 96'b0;
          nts.sot           = 1'b0;
          nts.eot           = 1'b0;
          nts_hdr_info      = DEFAULT_HDR_INFO;
          nts.has_pfx       = 1'b0;
          nts.hdr_valid     = 1'b0;
          nts.dllp_err      = 1'b0;
          nts.data_prot     = DEF_PROT_3DW;
          chk_nts.status    = NOTHING;
        end

      pts.status==ONGOING && pts.nw==2'd1 && !tlp_idl[0] && !tlp_eot[0] && !tlp_idl[1] && !tlp_eot[1] && tlp_eot[2] && tlp_idl[3] && tlp_sot[4] :
        begin
          dec_case          = s_i_e_d_d__1;
          qdws[0].valid     = 1'b1;
          qdws[0].data      = {data[0*32 +: 3*32],pts.data[0+: 1*32]};
          qdws[0].dwen      = 4'b1111;
          qdws[0].sot       = pts.sot;
          qdws[0].eot       = 1'b1;
          qdw0_hdr_info     = get_hdr_info (3'd0, 3'd3, 1'b1, ca_h_info);
          qdws[0].has_pfx   = pts.has_pfx;
          qdws[0].hdr_valid = get_hdr_valid (3'd0, 3'd3, 1'b1, ca_h_val);
          qdws[0].dllp_err  = tlp_dllp_err[2];
          qdws[0].data_prot = {data_prot[0*DW_PROT_WD +: 3*DW_PROT_WD],pts.data_prot[0+: 1*DW_PROT_WD]};

          qdws[1].valid     = 1'b0;
          qdws[1].data      = 128'b0;
          qdws[1].dwen      = 4'b0000;
          qdws[1].sot       = 1'b0;
          qdws[1].eot       = 1'b0;
          qdw1_hdr_info     = DEFAULT_HDR_INFO;
          qdws[1].has_pfx   = 1'b0;
          qdws[1].hdr_valid = 1'b0;
          qdws[1].dllp_err  = 1'b0;
          qdws[1].data_prot = DEF_PROT_4DW;

          nts.nw            = 2'd1;
          nts.data          = {64'b0,data[4*32 +: 1*32]};
          nts.sot           = 1'b1;
          nts.eot           = 1'b0;
          nts_hdr_info      = get_hdr_info (3'd4, 3'd1, 1'b0, ca_h_info);
          nts.has_pfx       = tlp_pfx[4];
          nts.hdr_valid     = get_hdr_valid (3'd4, 3'd1, 1'b0, ca_h_val);
          nts.dllp_err      = 1'b0;
          nts.data_prot     = {DEF_PROT_2DW,data_prot[4*DW_PROT_WD +: 1*DW_PROT_WD]};
          chk_nts.status    = ONGOING;
        end

      pts.status==ONGOING && pts.nw==2'd1 && !tlp_idl[0] && !tlp_eot[0] && !tlp_idl[1] && !tlp_eot[1] && tlp_eot[2] && tlp_sot[3] && tlp_idl[4] :
        begin
          dec_case          = i_s_e_d_d__1;
          qdws[0].valid     = 1'b1;
          qdws[0].data      = {data[0*32 +: 3*32],pts.data[0+: 1*32]};
          qdws[0].dwen      = 4'b1111;
          qdws[0].sot       = pts.sot;
          qdws[0].eot       = 1'b1;
          qdw0_hdr_info     = get_hdr_info (3'd0, 3'd3, 1'b1, ca_h_info);
          qdws[0].has_pfx   = pts.has_pfx;
          qdws[0].hdr_valid = get_hdr_valid (3'd0, 3'd3, 1'b1, ca_h_val);
          qdws[0].dllp_err  = tlp_dllp_err[2];
          qdws[0].data_prot = {data_prot[0*DW_PROT_WD +: 3*DW_PROT_WD],pts.data_prot[0+: 1*DW_PROT_WD]};

          qdws[1].valid     = 1'b0;
          qdws[1].data      = 128'b0;
          qdws[1].dwen      = 4'b0000;
          qdws[1].sot       = 1'b0;
          qdws[1].eot       = 1'b0;
          qdw1_hdr_info     = DEFAULT_HDR_INFO;
          qdws[1].has_pfx   = 1'b0;
          qdws[1].hdr_valid = 1'b0;
          qdws[1].dllp_err  = 1'b0;
          qdws[1].data_prot = DEF_PROT_4DW;

          nts.nw            = 2'd1;
          nts.data          = {64'b0,data[3*32 +: 1*32]};
          nts.sot           = 1'b1;
          nts.eot           = 1'b0;
          nts_hdr_info      = get_hdr_info (3'd3, 3'd1, 1'b0, ca_h_info);
          nts.has_pfx       = tlp_pfx[3];
          nts.hdr_valid     = get_hdr_valid (3'd3, 3'd1, 1'b0, ca_h_val);
          nts.dllp_err      = 1'b0;
          nts.data_prot     = {DEF_PROT_2DW,data_prot[3*DW_PROT_WD +: 1*DW_PROT_WD]};
          chk_nts.status    = ONGOING;
        end

      pts.status==ONGOING && pts.nw==2'd1 && !tlp_idl[0] && !tlp_eot[0] && !tlp_idl[1] && !tlp_eot[1] && tlp_eot[2] && tlp_sot[3] && !tlp_idl[4] && !tlp_eot[4] :
        begin
          dec_case          = d_s_e_d_d__1;
          qdws[0].valid     = 1'b1;
          qdws[0].data      = {data[0*32 +: 3*32],pts.data[0+: 1*32]};
          qdws[0].dwen      = 4'b1111;
          qdws[0].sot       = pts.sot;
          qdws[0].eot       = 1'b1;
          qdw0_hdr_info     = get_hdr_info (3'd0, 3'd3, 1'b1, ca_h_info);
          qdws[0].has_pfx   = pts.has_pfx;
          qdws[0].hdr_valid = get_hdr_valid (3'd0, 3'd3, 1'b1, ca_h_val);
          qdws[0].dllp_err  = tlp_dllp_err[2];
          qdws[0].data_prot = {data_prot[0*DW_PROT_WD +: 3*DW_PROT_WD],pts.data_prot[0+: 1*DW_PROT_WD]};

          qdws[1].valid     = 1'b0;
          qdws[1].data      = 128'b0;
          qdws[1].dwen      = 4'b0000;
          qdws[1].sot       = 1'b0;
          qdws[1].eot       = 1'b0;
          qdw1_hdr_info     = DEFAULT_HDR_INFO;
          qdws[1].has_pfx   = 1'b0;
          qdws[1].hdr_valid = 1'b0;
          qdws[1].dllp_err  = 1'b0;
          qdws[1].data_prot = DEF_PROT_4DW;

          nts.nw            = 2'd2;
          nts.data          = {32'b0,data[3*32 +: 2*32]};
          nts.sot           = 1'b1;
          nts.eot           = 1'b0;
          nts_hdr_info      = get_hdr_info (3'd3, 3'd2, 1'b0, ca_h_info);
          nts.has_pfx       = tlp_pfx[3];
          nts.hdr_valid     = get_hdr_valid (3'd3, 3'd2, 1'b0, ca_h_val);
          nts.dllp_err      = 1'b0;
          nts.data_prot     = {DEF_PROT_1DW,data_prot[3*DW_PROT_WD +: 2*DW_PROT_WD]};
          chk_nts.status    = ONGOING;
        end

      pts.status==ONGOING && pts.nw==2'd1 && !tlp_idl[0] && !tlp_eot[0] && !tlp_idl[1] && !tlp_eot[1] && !tlp_idl[2] && !tlp_eot[2] && tlp_idl[3] && tlp_idl[4] :
        begin
          dec_case          = i_i_d_d_d__1;
          qdws[0].valid     = 1'b1;
          qdws[0].data      = {data[0*32 +: 3*32],pts.data[0+: 1*32]};
          qdws[0].dwen      = 4'b1111;
          qdws[0].sot       = pts.sot;
          qdws[0].eot       = 1'b0;
          qdw0_hdr_info     = get_hdr_info (3'd0, 3'd3, 1'b1, ca_h_info);
          qdws[0].has_pfx   = pts.has_pfx;
          qdws[0].hdr_valid = get_hdr_valid (3'd0, 3'd3, 1'b1, ca_h_val);
          qdws[0].dllp_err  = 1'b0;
          qdws[0].data_prot = {data_prot[0*DW_PROT_WD +: 3*DW_PROT_WD],pts.data_prot[0+: 1*DW_PROT_WD]};

          qdws[1].valid     = 1'b0;
          qdws[1].data      = 128'b0;
          qdws[1].dwen      = 4'b0000;
          qdws[1].sot       = 1'b0;
          qdws[1].eot       = 1'b0;
          qdw1_hdr_info     = DEFAULT_HDR_INFO;
          qdws[1].has_pfx   = 1'b0;
          qdws[1].hdr_valid = 1'b0;
          qdws[1].dllp_err  = 1'b0;
          qdws[1].data_prot = DEF_PROT_4DW;

          nts.nw            = 2'd0;
          nts.data          = 96'b0;
          nts.sot           = 1'b0;
          nts.eot           = 1'b0;
          nts_hdr_info      = get_hdr_info (3'd0, 3'd3, 1'b1, ca_h_info);
          nts.has_pfx       = pts.has_pfx;
          nts.hdr_valid     = 1'b0;
          nts.dllp_err      = 1'b0;
          nts.data_prot     = DEF_PROT_3DW;
          chk_nts.status    = ONGOING;
        end

      pts.status==ONGOING && pts.nw==2'd1 && !tlp_idl[0] && !tlp_eot[0] && !tlp_idl[1] && !tlp_eot[1] && !tlp_idl[2] && !tlp_eot[2] && tlp_eot[3] && tlp_idl[4] :
        begin
          dec_case          = i_e_d_d_d__1;
          qdws[0].valid     = 1'b1;
          qdws[0].data      = {data[0*32 +: 3*32],pts.data[0+: 1*32]};
          qdws[0].dwen      = 4'b1111;
          qdws[0].sot       = pts.sot;
          qdws[0].eot       = 1'b0;
          qdw0_hdr_info     = get_hdr_info (3'd0, 3'd3, 1'b1, ca_h_info);
          qdws[0].has_pfx   = pts.has_pfx;
          qdws[0].hdr_valid = get_hdr_valid (3'd0, 3'd3, 1'b1, ca_h_val);
          qdws[0].dllp_err  = 1'b0;
          qdws[0].data_prot = {data_prot[0*DW_PROT_WD +: 3*DW_PROT_WD],pts.data_prot[0+: 1*DW_PROT_WD]};

          qdws[1].valid     = 1'b1;
          qdws[1].data      = {96'b0,data[3*32 +: 1*32]};
          qdws[1].dwen      = 4'b0001;
          qdws[1].sot       = 1'b0;
          qdws[1].eot       = 1'b1;
          qdw1_hdr_info     = get_hdr_info (3'd0, 3'd4, 1'b1, ca_h_info);
          qdws[1].has_pfx   = pts.has_pfx;
          qdws[1].hdr_valid = get_hdr_valid (3'd3, 3'd1, 1'b0, ca_h_val);
          qdws[1].dllp_err  = tlp_dllp_err[3];
          qdws[1].data_prot = {DEF_PROT_3DW,data_prot[3*DW_PROT_WD +: 1*DW_PROT_WD]};

          nts.nw            = 2'd0;
          nts.data          = 96'b0;
          nts.sot           = 1'b0;
          nts.eot           = 1'b0;
          nts_hdr_info      = get_hdr_info (3'd0, 3'd3, 1'b1, ca_h_info);
          nts.has_pfx       = pts.has_pfx;
          nts.hdr_valid     = 1'b0;
          nts.dllp_err      = 1'b0;
          nts.data_prot     = DEF_PROT_3DW;
          chk_nts.status    = NOTHING;
        end

      pts.status==ONGOING && pts.nw==2'd1 && !tlp_idl[0] && !tlp_eot[0] && !tlp_idl[1] && !tlp_eot[1] && !tlp_idl[2] && !tlp_eot[2] && tlp_eot[3] && tlp_sot[4] :
        begin
          dec_case          = s_e_d_d_d__1;
          qdws[0].valid     = 1'b1;
          qdws[0].data      = {data[0*32 +: 3*32],pts.data[0+: 1*32]};
          qdws[0].dwen      = 4'b1111;
          qdws[0].sot       = pts.sot;
          qdws[0].eot       = 1'b0;
          qdw0_hdr_info     = get_hdr_info (3'd0, 3'd3, 1'b1, ca_h_info);
          qdws[0].has_pfx   = pts.has_pfx;
          qdws[0].hdr_valid = get_hdr_valid (3'd0, 3'd3, 1'b1, ca_h_val);
          qdws[0].dllp_err  = 1'b0;
          qdws[0].data_prot = {data_prot[0*DW_PROT_WD +: 3*DW_PROT_WD],pts.data_prot[0+: 1*DW_PROT_WD]};

          qdws[1].valid     = 1'b1;
          qdws[1].data      = {96'b0,data[3*32 +: 1*32]};
          qdws[1].dwen      = 4'b0001;
          qdws[1].sot       = 1'b0;
          qdws[1].eot       = 1'b1;
          qdw1_hdr_info     = get_hdr_info (3'd0, 3'd4, 1'b1, ca_h_info);
          qdws[1].has_pfx   = pts.has_pfx;
          qdws[1].hdr_valid = get_hdr_valid (3'd3, 3'd1, 1'b0, ca_h_val);
          qdws[1].dllp_err  = tlp_dllp_err[3];
          qdws[1].data_prot = {DEF_PROT_3DW,data_prot[3*DW_PROT_WD +: 1*DW_PROT_WD]};

          nts.nw            = 2'd1;
          nts.data          = {64'b0,data[4*32 +: 1*32]};
          nts.sot           = 1'b1;
          nts.eot           = 1'b0;
          nts_hdr_info      = get_hdr_info (3'd4, 3'd1, 1'b0, ca_h_info);
          nts.has_pfx       = tlp_pfx[4];
          nts.hdr_valid     = get_hdr_valid (3'd4, 3'd1, 1'b0, ca_h_val);
          nts.dllp_err      = 1'b0;
          nts.data_prot     = {DEF_PROT_2DW,data_prot[4*DW_PROT_WD +: 1*DW_PROT_WD]};
          chk_nts.status    = ONGOING;
        end

      pts.status==ONGOING && pts.nw==2'd1 && !tlp_idl[0] && !tlp_eot[0] && !tlp_idl[1] && !tlp_eot[1] && !tlp_idl[2] && !tlp_eot[2] && !tlp_idl[3] && !tlp_eot[3] && tlp_idl[4] :
        begin
          dec_case          = i_d_d_d_d__1;
          qdws[0].valid     = 1'b1;
          qdws[0].data      = {data[0*32 +: 3*32],pts.data[0+: 1*32]};
          qdws[0].dwen      = 4'b1111;
          qdws[0].sot       = pts.sot;
          qdws[0].eot       = 1'b0;
          qdw0_hdr_info     = get_hdr_info (3'd0, 3'd3, 1'b1, ca_h_info);
          qdws[0].has_pfx   = pts.has_pfx;
          qdws[0].hdr_valid = get_hdr_valid (3'd0, 3'd3, 1'b1, ca_h_val);
          qdws[0].dllp_err  = 1'b0;
          qdws[0].data_prot = {data_prot[0*DW_PROT_WD +: 3*DW_PROT_WD],pts.data_prot[0+: 1*DW_PROT_WD]};

          qdws[1].valid     = 1'b0;
          qdws[1].data      = 128'b0;
          qdws[1].dwen      = 4'b0000;
          qdws[1].sot       = 1'b0;
          qdws[1].eot       = 1'b0;
          qdw1_hdr_info     = DEFAULT_HDR_INFO;
          qdws[1].has_pfx   = 1'b0;
          qdws[1].hdr_valid = 1'b0;
          qdws[1].dllp_err  = 1'b0;
          qdws[1].data_prot = DEF_PROT_4DW;

          nts.nw            = 2'd1;
          nts.data          = {64'b0,data[3*32 +: 1*32]};
          nts.sot           = 1'b0;
          nts.eot           = 1'b0;
          nts_hdr_info      = get_hdr_info (3'd0, 3'd4, 1'b1, ca_h_info);
          nts.has_pfx       = pts.has_pfx;
          nts.hdr_valid     = get_hdr_valid (3'd3, 3'd1, 1'b0, ca_h_val);
          nts.dllp_err      = 1'b0;
          nts.data_prot     = {DEF_PROT_2DW,data_prot[3*DW_PROT_WD +: 1*DW_PROT_WD]};
          chk_nts.status    = ONGOING;
        end

      pts.status==ONGOING && pts.nw==2'd1 && !tlp_idl[0] && !tlp_eot[0] && !tlp_idl[1] && !tlp_eot[1] && !tlp_idl[2] && !tlp_eot[2] && !tlp_idl[3] && !tlp_eot[3] && tlp_eot[4] :
        begin
          dec_case          = e_d_d_d_d__1;
          qdws[0].valid     = 1'b1;
          qdws[0].data      = {data[0*32 +: 3*32],pts.data[0+: 1*32]};
          qdws[0].dwen      = 4'b1111;
          qdws[0].sot       = pts.sot;
          qdws[0].eot       = 1'b0;
          qdw0_hdr_info     = get_hdr_info (3'd0, 3'd3, 1'b1, ca_h_info);
          qdws[0].has_pfx   = pts.has_pfx;
          qdws[0].hdr_valid = get_hdr_valid (3'd0, 3'd3, 1'b1, ca_h_val);
          qdws[0].dllp_err  = 1'b0;
          qdws[0].data_prot = {data_prot[0*DW_PROT_WD +: 3*DW_PROT_WD],pts.data_prot[0+: 1*DW_PROT_WD]};

          qdws[1].valid     = 1'b1;
          qdws[1].data      = {64'b0,data[3*32 +: 2*32]};
          qdws[1].dwen      = 4'b0011;
          qdws[1].sot       = 1'b0;
          qdws[1].eot       = 1'b1;
          qdw1_hdr_info     = get_hdr_info (3'd0, 3'd5, 1'b1, ca_h_info);
          qdws[1].has_pfx   = pts.has_pfx;
          qdws[1].hdr_valid = get_hdr_valid (3'd3, 3'd2, 1'b0, ca_h_val);
          qdws[1].dllp_err  = tlp_dllp_err[4];
          qdws[1].data_prot = {DEF_PROT_2DW,data_prot[3*DW_PROT_WD +: 2*DW_PROT_WD]};

          nts.nw            = 2'd0;
          nts.data          = 96'b0;
          nts.sot           = 1'b0;
          nts.eot           = 1'b0;
          nts_hdr_info      = get_hdr_info (3'd0, 3'd3, 1'b1, ca_h_info);
          nts.has_pfx       = pts.has_pfx;
          nts.hdr_valid     = 1'b0;
          nts.dllp_err      = 1'b0;
          nts.data_prot     = DEF_PROT_3DW;
          chk_nts.status    = NOTHING;
        end

      pts.status==ONGOING && pts.nw==2'd1 && !tlp_idl[0] && !tlp_eot[0] && !tlp_idl[1] && !tlp_eot[1] && !tlp_idl[2] && !tlp_eot[2] && !tlp_idl[3] && !tlp_eot[3] && !tlp_idl[4] && !tlp_eot[4] :
        begin
          dec_case          = d_d_d_d_d__1;
          qdws[0].valid     = 1'b1;
          qdws[0].data      = {data[0*32 +: 3*32],pts.data[0+: 1*32]};
          qdws[0].dwen      = 4'b1111;
          qdws[0].sot       = pts.sot;
          qdws[0].eot       = 1'b0;
          qdw0_hdr_info     = get_hdr_info (3'd0, 3'd3, 1'b1, ca_h_info);
          qdws[0].has_pfx   = pts.has_pfx;
          qdws[0].hdr_valid = get_hdr_valid (3'd0, 3'd3, 1'b1, ca_h_val);
          qdws[0].dllp_err  = 1'b0;
          qdws[0].data_prot = {data_prot[0*DW_PROT_WD +: 3*DW_PROT_WD],pts.data_prot[0+: 1*DW_PROT_WD]};

          qdws[1].valid     = 1'b0;
          qdws[1].data      = 128'b0;
          qdws[1].dwen      = 4'b0000;
          qdws[1].sot       = 1'b0;
          qdws[1].eot       = 1'b0;
          qdw1_hdr_info     = DEFAULT_HDR_INFO;
          qdws[1].has_pfx   = 1'b0;
          qdws[1].hdr_valid = 1'b0;
          qdws[1].dllp_err  = 1'b0;
          qdws[1].data_prot = DEF_PROT_4DW;

          nts.nw            = 2'd2;
          nts.data          = {32'b0,data[3*32 +: 2*32]};
          nts.sot           = 1'b0;
          nts.eot           = 1'b0;
          nts_hdr_info      = get_hdr_info (3'd0, 3'd5, 1'b1, ca_h_info);
          nts.has_pfx       = pts.has_pfx;
          nts.hdr_valid     = get_hdr_valid (3'd3, 3'd2, 1'b0, ca_h_val);
          nts.dllp_err      = 1'b0;
          nts.data_prot     = {DEF_PROT_1DW,data_prot[3*DW_PROT_WD +: 2*DW_PROT_WD]};
          chk_nts.status    = ONGOING;
        end

      pts.status==ONGOING && pts.nw==2'd2 && tlp_eot[0] && tlp_idl[1] && tlp_idl[2] && tlp_idl[3] && tlp_idl[4] :
        begin
          dec_case          = i_i_i_i_e__2;
          qdws[0].valid     = 1'b1;
          qdws[0].data      = {32'b0,data[0*32 +: 1*32],pts.data[0+: 2*32]};
          qdws[0].dwen      = 4'b0111;
          qdws[0].sot       = pts.sot;
          qdws[0].eot       = 1'b1;
          qdw0_hdr_info     = get_hdr_info (3'd0, 3'd1, 1'b1, ca_h_info);
          qdws[0].has_pfx   = pts.has_pfx;
          qdws[0].hdr_valid = get_hdr_valid (3'd0, 3'd1, 1'b1, ca_h_val);
          qdws[0].dllp_err  = tlp_dllp_err[0];
          qdws[0].data_prot = {DEF_PROT_1DW,data_prot[0*DW_PROT_WD +: 1*DW_PROT_WD],pts.data_prot[0+: 2*DW_PROT_WD]};

          qdws[1].valid     = 1'b0;
          qdws[1].data      = 128'b0;
          qdws[1].dwen      = 4'b0000;
          qdws[1].sot       = 1'b0;
          qdws[1].eot       = 1'b0;
          qdw1_hdr_info     = DEFAULT_HDR_INFO;
          qdws[1].has_pfx   = 1'b0;
          qdws[1].hdr_valid = 1'b0;
          qdws[1].dllp_err  = 1'b0;
          qdws[1].data_prot = DEF_PROT_4DW;

          nts.nw            = 2'd0;
          nts.data          = 96'b0;
          nts.sot           = 1'b0;
          nts.eot           = 1'b0;
          nts_hdr_info      = DEFAULT_HDR_INFO;
          nts.has_pfx       = 1'b0;
          nts.hdr_valid     = 1'b0;
          nts.dllp_err      = 1'b0;
          nts.data_prot     = DEF_PROT_3DW;
          chk_nts.status    = NOTHING;
        end

      pts.status==ONGOING && pts.nw==2'd2 && tlp_eot[0] && tlp_idl[1] && tlp_idl[2] && tlp_idl[3] && tlp_sot[4] :
        begin
          dec_case          = s_i_i_i_e__2;
          qdws[0].valid     = 1'b1;
          qdws[0].data      = {32'b0,data[0*32 +: 1*32],pts.data[0+: 2*32]};
          qdws[0].dwen      = 4'b0111;
          qdws[0].sot       = pts.sot;
          qdws[0].eot       = 1'b1;
          qdw0_hdr_info     = get_hdr_info (3'd0, 3'd1, 1'b1, ca_h_info);
          qdws[0].has_pfx   = pts.has_pfx;
          qdws[0].hdr_valid = get_hdr_valid (3'd0, 3'd1, 1'b1, ca_h_val);
          qdws[0].dllp_err  = tlp_dllp_err[0];
          qdws[0].data_prot = {DEF_PROT_1DW,data_prot[0*DW_PROT_WD +: 1*DW_PROT_WD],pts.data_prot[0+: 2*DW_PROT_WD]};

          qdws[1].valid     = 1'b0;
          qdws[1].data      = 128'b0;
          qdws[1].dwen      = 4'b0000;
          qdws[1].sot       = 1'b0;
          qdws[1].eot       = 1'b0;
          qdw1_hdr_info     = DEFAULT_HDR_INFO;
          qdws[1].has_pfx   = 1'b0;
          qdws[1].hdr_valid = 1'b0;
          qdws[1].dllp_err  = 1'b0;
          qdws[1].data_prot = DEF_PROT_4DW;

          nts.nw            = 2'd1;
          nts.data          = {64'b0,data[4*32 +: 1*32]};
          nts.sot           = 1'b1;
          nts.eot           = 1'b0;
          nts_hdr_info      = get_hdr_info (3'd4, 3'd1, 1'b0, ca_h_info);
          nts.has_pfx       = tlp_pfx[4];
          nts.hdr_valid     = get_hdr_valid (3'd4, 3'd1, 1'b0, ca_h_val);
          nts.dllp_err      = 1'b0;
          nts.data_prot     = {DEF_PROT_2DW,data_prot[4*DW_PROT_WD +: 1*DW_PROT_WD]};
          chk_nts.status    = ONGOING;
        end

      pts.status==ONGOING && pts.nw==2'd2 && tlp_eot[0] && tlp_idl[1] && tlp_idl[2] && tlp_sot[3] && tlp_idl[4] :
        begin
          dec_case          = i_s_i_i_e__2;
          qdws[0].valid     = 1'b1;
          qdws[0].data      = {32'b0,data[0*32 +: 1*32],pts.data[0+: 2*32]};
          qdws[0].dwen      = 4'b0111;
          qdws[0].sot       = pts.sot;
          qdws[0].eot       = 1'b1;
          qdw0_hdr_info     = get_hdr_info (3'd0, 3'd1, 1'b1, ca_h_info);
          qdws[0].has_pfx   = pts.has_pfx;
          qdws[0].hdr_valid = get_hdr_valid (3'd0, 3'd1, 1'b1, ca_h_val);
          qdws[0].dllp_err  = tlp_dllp_err[0];
          qdws[0].data_prot = {DEF_PROT_1DW,data_prot[0*DW_PROT_WD +: 1*DW_PROT_WD],pts.data_prot[0+: 2*DW_PROT_WD]};

          qdws[1].valid     = 1'b0;
          qdws[1].data      = 128'b0;
          qdws[1].dwen      = 4'b0000;
          qdws[1].sot       = 1'b0;
          qdws[1].eot       = 1'b0;
          qdw1_hdr_info     = DEFAULT_HDR_INFO;
          qdws[1].has_pfx   = 1'b0;
          qdws[1].hdr_valid = 1'b0;
          qdws[1].dllp_err  = 1'b0;
          qdws[1].data_prot = DEF_PROT_4DW;

          nts.nw            = 2'd1;
          nts.data          = {64'b0,data[3*32 +: 1*32]};
          nts.sot           = 1'b1;
          nts.eot           = 1'b0;
          nts_hdr_info      = get_hdr_info (3'd3, 3'd1, 1'b0, ca_h_info);
          nts.has_pfx       = tlp_pfx[3];
          nts.hdr_valid     = get_hdr_valid (3'd3, 3'd1, 1'b0, ca_h_val);
          nts.dllp_err      = 1'b0;
          nts.data_prot     = {DEF_PROT_2DW,data_prot[3*DW_PROT_WD +: 1*DW_PROT_WD]};
          chk_nts.status    = ONGOING;
        end

      pts.status==ONGOING && pts.nw==2'd2 && tlp_eot[0] && tlp_idl[1] && tlp_idl[2] && tlp_sot[3] && !tlp_idl[4] && !tlp_eot[4] :
        begin
          dec_case          = d_s_i_i_e__2;
          qdws[0].valid     = 1'b1;
          qdws[0].data      = {32'b0,data[0*32 +: 1*32],pts.data[0+: 2*32]};
          qdws[0].dwen      = 4'b0111;
          qdws[0].sot       = pts.sot;
          qdws[0].eot       = 1'b1;
          qdw0_hdr_info     = get_hdr_info (3'd0, 3'd1, 1'b1, ca_h_info);
          qdws[0].has_pfx   = pts.has_pfx;
          qdws[0].hdr_valid = get_hdr_valid (3'd0, 3'd1, 1'b1, ca_h_val);
          qdws[0].dllp_err  = tlp_dllp_err[0];
          qdws[0].data_prot = {DEF_PROT_1DW,data_prot[0*DW_PROT_WD +: 1*DW_PROT_WD],pts.data_prot[0+: 2*DW_PROT_WD]};

          qdws[1].valid     = 1'b0;
          qdws[1].data      = 128'b0;
          qdws[1].dwen      = 4'b0000;
          qdws[1].sot       = 1'b0;
          qdws[1].eot       = 1'b0;
          qdw1_hdr_info     = DEFAULT_HDR_INFO;
          qdws[1].has_pfx   = 1'b0;
          qdws[1].hdr_valid = 1'b0;
          qdws[1].dllp_err  = 1'b0;
          qdws[1].data_prot = DEF_PROT_4DW;

          nts.nw            = 2'd2;
          nts.data          = {32'b0,data[3*32 +: 2*32]};
          nts.sot           = 1'b1;
          nts.eot           = 1'b0;
          nts_hdr_info      = get_hdr_info (3'd3, 3'd2, 1'b0, ca_h_info);
          nts.has_pfx       = tlp_pfx[3];
          nts.hdr_valid     = get_hdr_valid (3'd3, 3'd2, 1'b0, ca_h_val);
          nts.dllp_err      = 1'b0;
          nts.data_prot     = {DEF_PROT_1DW,data_prot[3*DW_PROT_WD +: 2*DW_PROT_WD]};
          chk_nts.status    = ONGOING;
        end

      pts.status==ONGOING && pts.nw==2'd2 && tlp_eot[0] && tlp_idl[1] && tlp_sot[2] && tlp_idl[3] && tlp_idl[4] :
        begin
          dec_case          = i_i_s_i_e__2;
          qdws[0].valid     = 1'b1;
          qdws[0].data      = {32'b0,data[0*32 +: 1*32],pts.data[0+: 2*32]};
          qdws[0].dwen      = 4'b0111;
          qdws[0].sot       = pts.sot;
          qdws[0].eot       = 1'b1;
          qdw0_hdr_info     = get_hdr_info (3'd0, 3'd1, 1'b1, ca_h_info);
          qdws[0].has_pfx   = pts.has_pfx;
          qdws[0].hdr_valid = get_hdr_valid (3'd0, 3'd1, 1'b1, ca_h_val);
          qdws[0].dllp_err  = tlp_dllp_err[0];
          qdws[0].data_prot = {DEF_PROT_1DW,data_prot[0*DW_PROT_WD +: 1*DW_PROT_WD],pts.data_prot[0+: 2*DW_PROT_WD]};

          qdws[1].valid     = 1'b0;
          qdws[1].data      = 128'b0;
          qdws[1].dwen      = 4'b0000;
          qdws[1].sot       = 1'b0;
          qdws[1].eot       = 1'b0;
          qdw1_hdr_info     = DEFAULT_HDR_INFO;
          qdws[1].has_pfx   = 1'b0;
          qdws[1].hdr_valid = 1'b0;
          qdws[1].dllp_err  = 1'b0;
          qdws[1].data_prot = DEF_PROT_4DW;

          nts.nw            = 2'd1;
          nts.data          = {64'b0,data[2*32 +: 1*32]};
          nts.sot           = 1'b1;
          nts.eot           = 1'b0;
          nts_hdr_info      = get_hdr_info (3'd2, 3'd1, 1'b0, ca_h_info);
          nts.has_pfx       = tlp_pfx[2];
          nts.hdr_valid     = get_hdr_valid (3'd2, 3'd1, 1'b0, ca_h_val);
          nts.dllp_err      = 1'b0;
          nts.data_prot     = {DEF_PROT_2DW,data_prot[2*DW_PROT_WD +: 1*DW_PROT_WD]};
          chk_nts.status    = ONGOING;
        end

      pts.status==ONGOING && pts.nw==2'd2 && tlp_eot[0] && tlp_idl[1] && tlp_sot[2] && !tlp_idl[3] && !tlp_eot[3] && tlp_idl[4] :
        begin
          dec_case          = i_d_s_i_e__2;
          qdws[0].valid     = 1'b1;
          qdws[0].data      = {32'b0,data[0*32 +: 1*32],pts.data[0+: 2*32]};
          qdws[0].dwen      = 4'b0111;
          qdws[0].sot       = pts.sot;
          qdws[0].eot       = 1'b1;
          qdw0_hdr_info     = get_hdr_info (3'd0, 3'd1, 1'b1, ca_h_info);
          qdws[0].has_pfx   = pts.has_pfx;
          qdws[0].hdr_valid = get_hdr_valid (3'd0, 3'd1, 1'b1, ca_h_val);
          qdws[0].dllp_err  = tlp_dllp_err[0];
          qdws[0].data_prot = {DEF_PROT_1DW,data_prot[0*DW_PROT_WD +: 1*DW_PROT_WD],pts.data_prot[0+: 2*DW_PROT_WD]};

          qdws[1].valid     = 1'b0;
          qdws[1].data      = 128'b0;
          qdws[1].dwen      = 4'b0000;
          qdws[1].sot       = 1'b0;
          qdws[1].eot       = 1'b0;
          qdw1_hdr_info     = DEFAULT_HDR_INFO;
          qdws[1].has_pfx   = 1'b0;
          qdws[1].hdr_valid = 1'b0;
          qdws[1].dllp_err  = 1'b0;
          qdws[1].data_prot = DEF_PROT_4DW;

          nts.nw            = 2'd2;
          nts.data          = {32'b0,data[2*32 +: 2*32]};
          nts.sot           = 1'b1;
          nts.eot           = 1'b0;
          nts_hdr_info      = get_hdr_info (3'd2, 3'd2, 1'b0, ca_h_info);
          nts.has_pfx       = tlp_pfx[2];
          nts.hdr_valid     = get_hdr_valid (3'd2, 3'd2, 1'b0, ca_h_val);
          nts.dllp_err      = 1'b0;
          nts.data_prot     = {DEF_PROT_1DW,data_prot[2*DW_PROT_WD +: 2*DW_PROT_WD]};
          chk_nts.status    = ONGOING;
        end

      pts.status==ONGOING && pts.nw==2'd2 && tlp_eot[0] && tlp_idl[1] && tlp_sot[2] && !tlp_idl[3] && !tlp_eot[3] && tlp_eot[4] :
        begin
          dec_case          = e_d_s_i_e__2;
          qdws[0].valid     = 1'b1;
          qdws[0].data      = {32'b0,data[0*32 +: 1*32],pts.data[0+: 2*32]};
          qdws[0].dwen      = 4'b0111;
          qdws[0].sot       = pts.sot;
          qdws[0].eot       = 1'b1;
          qdw0_hdr_info     = get_hdr_info (3'd0, 3'd1, 1'b1, ca_h_info);
          qdws[0].has_pfx   = pts.has_pfx;
          qdws[0].hdr_valid = get_hdr_valid (3'd0, 3'd1, 1'b1, ca_h_val);
          qdws[0].dllp_err  = tlp_dllp_err[0];
          qdws[0].data_prot = {DEF_PROT_1DW,data_prot[0*DW_PROT_WD +: 1*DW_PROT_WD],pts.data_prot[0+: 2*DW_PROT_WD]};

          qdws[1].valid     = 1'b1;
          qdws[1].data      = {32'b0,data[2*32 +: 3*32]};
          qdws[1].dwen      = 4'b0111;
          qdws[1].sot       = 1'b1;
          qdws[1].eot       = 1'b1;
          qdw1_hdr_info     = get_hdr_info (3'd2, 3'd3, 1'b0, ca_h_info);
          qdws[1].has_pfx   = tlp_pfx[2];
          qdws[1].hdr_valid = get_hdr_valid (3'd2, 3'd3, 1'b0, ca_h_val);
          qdws[1].dllp_err  = tlp_dllp_err[4];
          qdws[1].data_prot = {DEF_PROT_1DW,data_prot[2*DW_PROT_WD +: 3*DW_PROT_WD]};

          nts.nw            = 2'd0;
          nts.data          = 96'b0;
          nts.sot           = 1'b0;
          nts.eot           = 1'b0;
          nts_hdr_info      = DEFAULT_HDR_INFO;
          nts.has_pfx       = 1'b0;
          nts.hdr_valid     = 1'b0;
          nts.dllp_err      = 1'b0;
          nts.data_prot     = DEF_PROT_3DW;
          chk_nts.status    = NOTHING;
        end

      pts.status==ONGOING && pts.nw==2'd2 && tlp_eot[0] && tlp_idl[1] && tlp_sot[2] && !tlp_idl[3] && !tlp_eot[3] && !tlp_idl[4] && !tlp_eot[4] :
        begin
          dec_case          = d_d_s_i_e__2;
          qdws[0].valid     = 1'b1;
          qdws[0].data      = {32'b0,data[0*32 +: 1*32],pts.data[0+: 2*32]};
          qdws[0].dwen      = 4'b0111;
          qdws[0].sot       = pts.sot;
          qdws[0].eot       = 1'b1;
          qdw0_hdr_info     = get_hdr_info (3'd0, 3'd1, 1'b1, ca_h_info);
          qdws[0].has_pfx   = pts.has_pfx;
          qdws[0].hdr_valid = get_hdr_valid (3'd0, 3'd1, 1'b1, ca_h_val);
          qdws[0].dllp_err  = tlp_dllp_err[0];
          qdws[0].data_prot = {DEF_PROT_1DW,data_prot[0*DW_PROT_WD +: 1*DW_PROT_WD],pts.data_prot[0+: 2*DW_PROT_WD]};

          qdws[1].valid     = 1'b0;
          qdws[1].data      = 128'b0;
          qdws[1].dwen      = 4'b0000;
          qdws[1].sot       = 1'b0;
          qdws[1].eot       = 1'b0;
          qdw1_hdr_info     = DEFAULT_HDR_INFO;
          qdws[1].has_pfx   = 1'b0;
          qdws[1].hdr_valid = 1'b0;
          qdws[1].dllp_err  = 1'b0;
          qdws[1].data_prot = DEF_PROT_4DW;

          nts.nw            = 2'd3;
          nts.data          = data[2*32 +: 3*32];
          nts.sot           = 1'b1;
          nts.eot           = 1'b0;
          nts_hdr_info      = get_hdr_info (3'd2, 3'd3, 1'b0, ca_h_info);
          nts.has_pfx       = tlp_pfx[2];
          nts.hdr_valid     = get_hdr_valid (3'd2, 3'd3, 1'b0, ca_h_val);
          nts.dllp_err      = 1'b0;
          nts.data_prot     = data_prot[2*DW_PROT_WD +: 3*DW_PROT_WD];
          chk_nts.status    = ONGOING;
        end

      pts.status==ONGOING && pts.nw==2'd2 && tlp_eot[0] && tlp_sot[1] && tlp_idl[2] && tlp_idl[3] && tlp_idl[4] :
        begin
          dec_case          = i_i_i_s_e__2;
          qdws[0].valid     = 1'b1;
          qdws[0].data      = {32'b0,data[0*32 +: 1*32],pts.data[0+: 2*32]};
          qdws[0].dwen      = 4'b0111;
          qdws[0].sot       = pts.sot;
          qdws[0].eot       = 1'b1;
          qdw0_hdr_info     = get_hdr_info (3'd0, 3'd1, 1'b1, ca_h_info);
          qdws[0].has_pfx   = pts.has_pfx;
          qdws[0].hdr_valid = get_hdr_valid (3'd0, 3'd1, 1'b1, ca_h_val);
          qdws[0].dllp_err  = tlp_dllp_err[0];
          qdws[0].data_prot = {DEF_PROT_1DW,data_prot[0*DW_PROT_WD +: 1*DW_PROT_WD],pts.data_prot[0+: 2*DW_PROT_WD]};

          qdws[1].valid     = 1'b0;
          qdws[1].data      = 128'b0;
          qdws[1].dwen      = 4'b0000;
          qdws[1].sot       = 1'b0;
          qdws[1].eot       = 1'b0;
          qdw1_hdr_info     = DEFAULT_HDR_INFO;
          qdws[1].has_pfx   = 1'b0;
          qdws[1].hdr_valid = 1'b0;
          qdws[1].dllp_err  = 1'b0;
          qdws[1].data_prot = DEF_PROT_4DW;

          nts.nw            = 2'd1;
          nts.data          = {64'b0,data[1*32 +: 1*32]};
          nts.sot           = 1'b1;
          nts.eot           = 1'b0;
          nts_hdr_info      = get_hdr_info (3'd1, 3'd1, 1'b0, ca_h_info);
          nts.has_pfx       = tlp_pfx[1];
          nts.hdr_valid     = get_hdr_valid (3'd1, 3'd1, 1'b0, ca_h_val);
          nts.dllp_err      = 1'b0;
          nts.data_prot     = {DEF_PROT_2DW,data_prot[1*DW_PROT_WD +: 1*DW_PROT_WD]};
          chk_nts.status    = ONGOING;
        end

      pts.status==ONGOING && pts.nw==2'd2 && tlp_eot[0] && tlp_sot[1] && !tlp_idl[2] && !tlp_eot[2] && tlp_idl[3] && tlp_idl[4] :
        begin
          dec_case          = i_i_d_s_e__2;
          qdws[0].valid     = 1'b1;
          qdws[0].data      = {32'b0,data[0*32 +: 1*32],pts.data[0+: 2*32]};
          qdws[0].dwen      = 4'b0111;
          qdws[0].sot       = pts.sot;
          qdws[0].eot       = 1'b1;
          qdw0_hdr_info     = get_hdr_info (3'd0, 3'd1, 1'b1, ca_h_info);
          qdws[0].has_pfx   = pts.has_pfx;
          qdws[0].hdr_valid = get_hdr_valid (3'd0, 3'd1, 1'b1, ca_h_val);
          qdws[0].dllp_err  = tlp_dllp_err[0];
          qdws[0].data_prot = {DEF_PROT_1DW,data_prot[0*DW_PROT_WD +: 1*DW_PROT_WD],pts.data_prot[0+: 2*DW_PROT_WD]};

          qdws[1].valid     = 1'b0;
          qdws[1].data      = 128'b0;
          qdws[1].dwen      = 4'b0000;
          qdws[1].sot       = 1'b0;
          qdws[1].eot       = 1'b0;
          qdw1_hdr_info     = DEFAULT_HDR_INFO;
          qdws[1].has_pfx   = 1'b0;
          qdws[1].hdr_valid = 1'b0;
          qdws[1].dllp_err  = 1'b0;
          qdws[1].data_prot = DEF_PROT_4DW;

          nts.nw            = 2'd2;
          nts.data          = {32'b0,data[1*32 +: 2*32]};
          nts.sot           = 1'b1;
          nts.eot           = 1'b0;
          nts_hdr_info      = get_hdr_info (3'd1, 3'd2, 1'b0, ca_h_info);
          nts.has_pfx       = tlp_pfx[1];
          nts.hdr_valid     = get_hdr_valid (3'd1, 3'd2, 1'b0, ca_h_val);
          nts.dllp_err      = 1'b0;
          nts.data_prot     = {DEF_PROT_1DW,data_prot[1*DW_PROT_WD +: 2*DW_PROT_WD]};
          chk_nts.status    = ONGOING;
        end

      pts.status==ONGOING && pts.nw==2'd2 && tlp_eot[0] && tlp_sot[1] && !tlp_idl[2] && !tlp_eot[2] && tlp_eot[3] && tlp_idl[4] :
        begin
          dec_case          = i_e_d_s_e__2;
          qdws[0].valid     = 1'b1;
          qdws[0].data      = {32'b0,data[0*32 +: 1*32],pts.data[0+: 2*32]};
          qdws[0].dwen      = 4'b0111;
          qdws[0].sot       = pts.sot;
          qdws[0].eot       = 1'b1;
          qdw0_hdr_info     = get_hdr_info (3'd0, 3'd1, 1'b1, ca_h_info);
          qdws[0].has_pfx   = pts.has_pfx;
          qdws[0].hdr_valid = get_hdr_valid (3'd0, 3'd1, 1'b1, ca_h_val);
          qdws[0].dllp_err  = tlp_dllp_err[0];
          qdws[0].data_prot = {DEF_PROT_1DW,data_prot[0*DW_PROT_WD +: 1*DW_PROT_WD],pts.data_prot[0+: 2*DW_PROT_WD]};

          qdws[1].valid     = 1'b1;
          qdws[1].data      = {32'b0,data[1*32 +: 3*32]};
          qdws[1].dwen      = 4'b0111;
          qdws[1].sot       = 1'b1;
          qdws[1].eot       = 1'b1;
          qdw1_hdr_info     = get_hdr_info (3'd1, 3'd3, 1'b0, ca_h_info);
          qdws[1].has_pfx   = tlp_pfx[1];
          qdws[1].hdr_valid = get_hdr_valid (3'd1, 3'd3, 1'b0, ca_h_val);
          qdws[1].dllp_err  = tlp_dllp_err[3];
          qdws[1].data_prot = {DEF_PROT_1DW,data_prot[1*DW_PROT_WD +: 3*DW_PROT_WD]};

          nts.nw            = 2'd0;
          nts.data          = 96'b0;
          nts.sot           = 1'b0;
          nts.eot           = 1'b0;
          nts_hdr_info      = DEFAULT_HDR_INFO;
          nts.has_pfx       = 1'b0;
          nts.hdr_valid     = 1'b0;
          nts.dllp_err      = 1'b0;
          nts.data_prot     = DEF_PROT_3DW;
          chk_nts.status    = NOTHING;
        end

      pts.status==ONGOING && pts.nw==2'd2 && tlp_eot[0] && tlp_sot[1] && !tlp_idl[2] && !tlp_eot[2] && tlp_eot[3] && tlp_sot[4] :
        begin
          dec_case          = s_e_d_s_e__2;
          qdws[0].valid     = 1'b1;
          qdws[0].data      = {32'b0,data[0*32 +: 1*32],pts.data[0+: 2*32]};
          qdws[0].dwen      = 4'b0111;
          qdws[0].sot       = pts.sot;
          qdws[0].eot       = 1'b1;
          qdw0_hdr_info     = get_hdr_info (3'd0, 3'd1, 1'b1, ca_h_info);
          qdws[0].has_pfx   = pts.has_pfx;
          qdws[0].hdr_valid = get_hdr_valid (3'd0, 3'd1, 1'b1, ca_h_val);
          qdws[0].dllp_err  = tlp_dllp_err[0];
          qdws[0].data_prot = {DEF_PROT_1DW,data_prot[0*DW_PROT_WD +: 1*DW_PROT_WD],pts.data_prot[0+: 2*DW_PROT_WD]};

          qdws[1].valid     = 1'b1;
          qdws[1].data      = {32'b0,data[1*32 +: 3*32]};
          qdws[1].dwen      = 4'b0111;
          qdws[1].sot       = 1'b1;
          qdws[1].eot       = 1'b1;
          qdw1_hdr_info     = get_hdr_info (3'd1, 3'd3, 1'b0, ca_h_info);
          qdws[1].has_pfx   = tlp_pfx[1];
          qdws[1].hdr_valid = get_hdr_valid (3'd1, 3'd3, 1'b0, ca_h_val);
          qdws[1].dllp_err  = tlp_dllp_err[3];
          qdws[1].data_prot = {DEF_PROT_1DW,data_prot[1*DW_PROT_WD +: 3*DW_PROT_WD]};

          nts.nw            = 2'd1;
          nts.data          = {64'b0,data[4*32 +: 1*32]};
          nts.sot           = 1'b1;
          nts.eot           = 1'b0;
          nts_hdr_info      = get_hdr_info (3'd4, 3'd1, 1'b0, ca_h_info);
          nts.has_pfx       = tlp_pfx[4];
          nts.hdr_valid     = get_hdr_valid (3'd4, 3'd1, 1'b0, ca_h_val);
          nts.dllp_err      = 1'b0;
          nts.data_prot     = {DEF_PROT_2DW,data_prot[4*DW_PROT_WD +: 1*DW_PROT_WD]};
          chk_nts.status    = ONGOING;
        end

      pts.status==ONGOING && pts.nw==2'd2 && tlp_eot[0] && tlp_sot[1] && !tlp_idl[2] && !tlp_eot[2] && !tlp_idl[3] && !tlp_eot[3] && tlp_idl[4] :
        begin
          dec_case          = i_d_d_s_e__2;
          qdws[0].valid     = 1'b1;
          qdws[0].data      = {32'b0,data[0*32 +: 1*32],pts.data[0+: 2*32]};
          qdws[0].dwen      = 4'b0111;
          qdws[0].sot       = pts.sot;
          qdws[0].eot       = 1'b1;
          qdw0_hdr_info     = get_hdr_info (3'd0, 3'd1, 1'b1, ca_h_info);
          qdws[0].has_pfx   = pts.has_pfx;
          qdws[0].hdr_valid = get_hdr_valid (3'd0, 3'd1, 1'b1, ca_h_val);
          qdws[0].dllp_err  = tlp_dllp_err[0];
          qdws[0].data_prot = {DEF_PROT_1DW,data_prot[0*DW_PROT_WD +: 1*DW_PROT_WD],pts.data_prot[0+: 2*DW_PROT_WD]};

          qdws[1].valid     = 1'b0;
          qdws[1].data      = 128'b0;
          qdws[1].dwen      = 4'b0000;
          qdws[1].sot       = 1'b0;
          qdws[1].eot       = 1'b0;
          qdw1_hdr_info     = DEFAULT_HDR_INFO;
          qdws[1].has_pfx   = 1'b0;
          qdws[1].hdr_valid = 1'b0;
          qdws[1].dllp_err  = 1'b0;
          qdws[1].data_prot = DEF_PROT_4DW;

          nts.nw            = 2'd3;
          nts.data          = data[1*32 +: 3*32];
          nts.sot           = 1'b1;
          nts.eot           = 1'b0;
          nts_hdr_info      = get_hdr_info (3'd1, 3'd3, 1'b0, ca_h_info);
          nts.has_pfx       = tlp_pfx[1];
          nts.hdr_valid     = get_hdr_valid (3'd1, 3'd3, 1'b0, ca_h_val);
          nts.dllp_err      = 1'b0;
          nts.data_prot     = data_prot[1*DW_PROT_WD +: 3*DW_PROT_WD];
          chk_nts.status    = ONGOING;
        end

      pts.status==ONGOING && pts.nw==2'd2 && tlp_eot[0] && tlp_sot[1] && !tlp_idl[2] && !tlp_eot[2] && !tlp_idl[3] && !tlp_eot[3] && tlp_eot[4] :
        begin
          dec_case          = e_d_d_s_e__2;
          qdws[0].valid     = 1'b1;
          qdws[0].data      = {32'b0,data[0*32 +: 1*32],pts.data[0+: 2*32]};
          qdws[0].dwen      = 4'b0111;
          qdws[0].sot       = pts.sot;
          qdws[0].eot       = 1'b1;
          qdw0_hdr_info     = get_hdr_info (3'd0, 3'd1, 1'b1, ca_h_info);
          qdws[0].has_pfx   = pts.has_pfx;
          qdws[0].hdr_valid = get_hdr_valid (3'd0, 3'd1, 1'b1, ca_h_val);
          qdws[0].dllp_err  = tlp_dllp_err[0];
          qdws[0].data_prot = {DEF_PROT_1DW,data_prot[0*DW_PROT_WD +: 1*DW_PROT_WD],pts.data_prot[0+: 2*DW_PROT_WD]};

          qdws[1].valid     = 1'b1;
          qdws[1].data      = data[1*32 +: 4*32];
          qdws[1].dwen      = 4'b1111;
          qdws[1].sot       = 1'b1;
          qdws[1].eot       = 1'b1;
          qdw1_hdr_info     = get_hdr_info (3'd1, 3'd4, 1'b0, ca_h_info);
          qdws[1].has_pfx   = tlp_pfx[1];
          qdws[1].hdr_valid = get_hdr_valid (3'd1, 3'd4, 1'b0, ca_h_val);
          qdws[1].dllp_err  = tlp_dllp_err[4];
          qdws[1].data_prot = data_prot[1*DW_PROT_WD +: 4*DW_PROT_WD];

          nts.nw            = 2'd0;
          nts.data          = 96'b0;
          nts.sot           = 1'b0;
          nts.eot           = 1'b0;
          nts_hdr_info      = DEFAULT_HDR_INFO;
          nts.has_pfx       = 1'b0;
          nts.hdr_valid     = 1'b0;
          nts.dllp_err      = 1'b0;
          nts.data_prot     = DEF_PROT_3DW;
          chk_nts.status    = NOTHING;
        end

      pts.status==ONGOING && pts.nw==2'd2 && tlp_eot[0] && tlp_sot[1] && !tlp_idl[2] && !tlp_eot[2] && !tlp_idl[3] && !tlp_eot[3] && !tlp_idl[4] && !tlp_eot[4] :
        begin
          dec_case          = d_d_d_s_e__2;
          qdws[0].valid     = 1'b1;
          qdws[0].data      = {32'b0,data[0*32 +: 1*32],pts.data[0+: 2*32]};
          qdws[0].dwen      = 4'b0111;
          qdws[0].sot       = pts.sot;
          qdws[0].eot       = 1'b1;
          qdw0_hdr_info     = get_hdr_info (3'd0, 3'd1, 1'b1, ca_h_info);
          qdws[0].has_pfx   = pts.has_pfx;
          qdws[0].hdr_valid = get_hdr_valid (3'd0, 3'd1, 1'b1, ca_h_val);
          qdws[0].dllp_err  = tlp_dllp_err[0];
          qdws[0].data_prot = {DEF_PROT_1DW,data_prot[0*DW_PROT_WD +: 1*DW_PROT_WD],pts.data_prot[0+: 2*DW_PROT_WD]};

          qdws[1].valid     = 1'b1;
          qdws[1].data      = data[1*32 +: 4*32];
          qdws[1].dwen      = 4'b1111;
          qdws[1].sot       = 1'b1;
          qdws[1].eot       = 1'b0;
          qdw1_hdr_info     = get_hdr_info (3'd1, 3'd4, 1'b0, ca_h_info);
          qdws[1].has_pfx   = tlp_pfx[1];
          qdws[1].hdr_valid = get_hdr_valid (3'd1, 3'd4, 1'b0, ca_h_val);
          qdws[1].dllp_err  = 1'b0;
          qdws[1].data_prot = data_prot[1*DW_PROT_WD +: 4*DW_PROT_WD];

          nts.nw            = 2'd0;
          nts.data          = 96'b0;
          nts.sot           = 1'b0;
          nts.eot           = 1'b0;
          nts_hdr_info      = get_hdr_info (3'd1, 3'd4, 1'b0, ca_h_info);
          nts.has_pfx       = tlp_pfx[1];
          nts.hdr_valid     = 1'b0;
          nts.dllp_err      = 1'b0;
          nts.data_prot     = DEF_PROT_3DW;
          chk_nts.status    = ONGOING;
        end

      pts.status==ONGOING && pts.nw==2'd2 && !tlp_idl[0] && !tlp_eot[0] && tlp_idl[1] && tlp_idl[2] && tlp_idl[3] && tlp_idl[4] :
        begin
          dec_case          = i_i_i_i_d__2;
          qdws[0].valid     = 1'b0;
          qdws[0].data      = 128'b0;
          qdws[0].dwen      = 4'b0000;
          qdws[0].sot       = 1'b0;
          qdws[0].eot       = 1'b0;
          qdw0_hdr_info     = DEFAULT_HDR_INFO;
          qdws[0].has_pfx   = 1'b0;
          qdws[0].hdr_valid = 1'b0;
          qdws[0].dllp_err  = 1'b0;
          qdws[0].data_prot = DEF_PROT_4DW;

          qdws[1].valid     = 1'b0;
          qdws[1].data      = 128'b0;
          qdws[1].dwen      = 4'b0000;
          qdws[1].sot       = 1'b0;
          qdws[1].eot       = 1'b0;
          qdw1_hdr_info     = DEFAULT_HDR_INFO;
          qdws[1].has_pfx   = 1'b0;
          qdws[1].hdr_valid = 1'b0;
          qdws[1].dllp_err  = 1'b0;
          qdws[1].data_prot = DEF_PROT_4DW;

          nts.nw            = 2'd3;
          nts.data          = {data[0*32 +: 1*32],pts.data[0+: 2*32]};
          nts.sot           = pts.sot;
          nts.eot           = 1'b0;
          nts_hdr_info      = get_hdr_info (3'd0, 3'd1, 1'b1, ca_h_info);
          nts.has_pfx       = pts.has_pfx;
          nts.hdr_valid     = get_hdr_valid (3'd0, 3'd1, 1'b1, ca_h_val);
          nts.dllp_err      = 1'b0;
          nts.data_prot     = {data_prot[0*DW_PROT_WD +: 1*DW_PROT_WD],pts.data_prot[0+: 2*DW_PROT_WD]};
          chk_nts.status    = ONGOING;
        end

      pts.status==ONGOING && pts.nw==2'd2 && !tlp_idl[0] && !tlp_eot[0] && tlp_eot[1] && tlp_idl[2] && tlp_idl[3] && tlp_idl[4] :
        begin
          dec_case          = i_i_i_e_d__2;
          qdws[0].valid     = 1'b1;
          qdws[0].data      = {data[0*32 +: 2*32],pts.data[0+: 2*32]};
          qdws[0].dwen      = 4'b1111;
          qdws[0].sot       = pts.sot;
          qdws[0].eot       = 1'b1;
          qdw0_hdr_info     = get_hdr_info (3'd0, 3'd2, 1'b1, ca_h_info);
          qdws[0].has_pfx   = pts.has_pfx;
          qdws[0].hdr_valid = get_hdr_valid (3'd0, 3'd2, 1'b1, ca_h_val);
          qdws[0].dllp_err  = tlp_dllp_err[1];
          qdws[0].data_prot = {data_prot[0*DW_PROT_WD +: 2*DW_PROT_WD],pts.data_prot[0+: 2*DW_PROT_WD]};

          qdws[1].valid     = 1'b0;
          qdws[1].data      = 128'b0;
          qdws[1].dwen      = 4'b0000;
          qdws[1].sot       = 1'b0;
          qdws[1].eot       = 1'b0;
          qdw1_hdr_info     = DEFAULT_HDR_INFO;
          qdws[1].has_pfx   = 1'b0;
          qdws[1].hdr_valid = 1'b0;
          qdws[1].dllp_err  = 1'b0;
          qdws[1].data_prot = DEF_PROT_4DW;

          nts.nw            = 2'd0;
          nts.data          = 96'b0;
          nts.sot           = 1'b0;
          nts.eot           = 1'b0;
          nts_hdr_info      = DEFAULT_HDR_INFO;
          nts.has_pfx       = 1'b0;
          nts.hdr_valid     = 1'b0;
          nts.dllp_err      = 1'b0;
          nts.data_prot     = DEF_PROT_3DW;
          chk_nts.status    = NOTHING;
        end

      pts.status==ONGOING && pts.nw==2'd2 && !tlp_idl[0] && !tlp_eot[0] && tlp_eot[1] && tlp_idl[2] && tlp_idl[3] && tlp_sot[4] :
        begin
          dec_case          = s_i_i_e_d__2;
          qdws[0].valid     = 1'b1;
          qdws[0].data      = {data[0*32 +: 2*32],pts.data[0+: 2*32]};
          qdws[0].dwen      = 4'b1111;
          qdws[0].sot       = pts.sot;
          qdws[0].eot       = 1'b1;
          qdw0_hdr_info     = get_hdr_info (3'd0, 3'd2, 1'b1, ca_h_info);
          qdws[0].has_pfx   = pts.has_pfx;
          qdws[0].hdr_valid = get_hdr_valid (3'd0, 3'd2, 1'b1, ca_h_val);
          qdws[0].dllp_err  = tlp_dllp_err[1];
          qdws[0].data_prot = {data_prot[0*DW_PROT_WD +: 2*DW_PROT_WD],pts.data_prot[0+: 2*DW_PROT_WD]};

          qdws[1].valid     = 1'b0;
          qdws[1].data      = 128'b0;
          qdws[1].dwen      = 4'b0000;
          qdws[1].sot       = 1'b0;
          qdws[1].eot       = 1'b0;
          qdw1_hdr_info     = DEFAULT_HDR_INFO;
          qdws[1].has_pfx   = 1'b0;
          qdws[1].hdr_valid = 1'b0;
          qdws[1].dllp_err  = 1'b0;
          qdws[1].data_prot = DEF_PROT_4DW;

          nts.nw            = 2'd1;
          nts.data          = {64'b0,data[4*32 +: 1*32]};
          nts.sot           = 1'b1;
          nts.eot           = 1'b0;
          nts_hdr_info      = get_hdr_info (3'd4, 3'd1, 1'b0, ca_h_info);
          nts.has_pfx       = tlp_pfx[4];
          nts.hdr_valid     = get_hdr_valid (3'd4, 3'd1, 1'b0, ca_h_val);
          nts.dllp_err      = 1'b0;
          nts.data_prot     = {DEF_PROT_2DW,data_prot[4*DW_PROT_WD +: 1*DW_PROT_WD]};
          chk_nts.status    = ONGOING;
        end

      pts.status==ONGOING && pts.nw==2'd2 && !tlp_idl[0] && !tlp_eot[0] && tlp_eot[1] && tlp_idl[2] && tlp_sot[3] && tlp_idl[4] :
        begin
          dec_case          = i_s_i_e_d__2;
          qdws[0].valid     = 1'b1;
          qdws[0].data      = {data[0*32 +: 2*32],pts.data[0+: 2*32]};
          qdws[0].dwen      = 4'b1111;
          qdws[0].sot       = pts.sot;
          qdws[0].eot       = 1'b1;
          qdw0_hdr_info     = get_hdr_info (3'd0, 3'd2, 1'b1, ca_h_info);
          qdws[0].has_pfx   = pts.has_pfx;
          qdws[0].hdr_valid = get_hdr_valid (3'd0, 3'd2, 1'b1, ca_h_val);
          qdws[0].dllp_err  = tlp_dllp_err[1];
          qdws[0].data_prot = {data_prot[0*DW_PROT_WD +: 2*DW_PROT_WD],pts.data_prot[0+: 2*DW_PROT_WD]};

          qdws[1].valid     = 1'b0;
          qdws[1].data      = 128'b0;
          qdws[1].dwen      = 4'b0000;
          qdws[1].sot       = 1'b0;
          qdws[1].eot       = 1'b0;
          qdw1_hdr_info     = DEFAULT_HDR_INFO;
          qdws[1].has_pfx   = 1'b0;
          qdws[1].hdr_valid = 1'b0;
          qdws[1].dllp_err  = 1'b0;
          qdws[1].data_prot = DEF_PROT_4DW;

          nts.nw            = 2'd1;
          nts.data          = {64'b0,data[3*32 +: 1*32]};
          nts.sot           = 1'b1;
          nts.eot           = 1'b0;
          nts_hdr_info      = get_hdr_info (3'd3, 3'd1, 1'b0, ca_h_info);
          nts.has_pfx       = tlp_pfx[3];
          nts.hdr_valid     = get_hdr_valid (3'd3, 3'd1, 1'b0, ca_h_val);
          nts.dllp_err      = 1'b0;
          nts.data_prot     = {DEF_PROT_2DW,data_prot[3*DW_PROT_WD +: 1*DW_PROT_WD]};
          chk_nts.status    = ONGOING;
        end

      pts.status==ONGOING && pts.nw==2'd2 && !tlp_idl[0] && !tlp_eot[0] && tlp_eot[1] && tlp_idl[2] && tlp_sot[3] && !tlp_idl[4] && !tlp_eot[4] :
        begin
          dec_case          = d_s_i_e_d__2;
          qdws[0].valid     = 1'b1;
          qdws[0].data      = {data[0*32 +: 2*32],pts.data[0+: 2*32]};
          qdws[0].dwen      = 4'b1111;
          qdws[0].sot       = pts.sot;
          qdws[0].eot       = 1'b1;
          qdw0_hdr_info     = get_hdr_info (3'd0, 3'd2, 1'b1, ca_h_info);
          qdws[0].has_pfx   = pts.has_pfx;
          qdws[0].hdr_valid = get_hdr_valid (3'd0, 3'd2, 1'b1, ca_h_val);
          qdws[0].dllp_err  = tlp_dllp_err[1];
          qdws[0].data_prot = {data_prot[0*DW_PROT_WD +: 2*DW_PROT_WD],pts.data_prot[0+: 2*DW_PROT_WD]};

          qdws[1].valid     = 1'b0;
          qdws[1].data      = 128'b0;
          qdws[1].dwen      = 4'b0000;
          qdws[1].sot       = 1'b0;
          qdws[1].eot       = 1'b0;
          qdw1_hdr_info     = DEFAULT_HDR_INFO;
          qdws[1].has_pfx   = 1'b0;
          qdws[1].hdr_valid = 1'b0;
          qdws[1].dllp_err  = 1'b0;
          qdws[1].data_prot = DEF_PROT_4DW;

          nts.nw            = 2'd2;
          nts.data          = {32'b0,data[3*32 +: 2*32]};
          nts.sot           = 1'b1;
          nts.eot           = 1'b0;
          nts_hdr_info      = get_hdr_info (3'd3, 3'd2, 1'b0, ca_h_info);
          nts.has_pfx       = tlp_pfx[3];
          nts.hdr_valid     = get_hdr_valid (3'd3, 3'd2, 1'b0, ca_h_val);
          nts.dllp_err      = 1'b0;
          nts.data_prot     = {DEF_PROT_1DW,data_prot[3*DW_PROT_WD +: 2*DW_PROT_WD]};
          chk_nts.status    = ONGOING;
        end

      pts.status==ONGOING && pts.nw==2'd2 && !tlp_idl[0] && !tlp_eot[0] && tlp_eot[1] && tlp_sot[2] && tlp_idl[3] && tlp_idl[4] :
        begin
          dec_case          = i_i_s_e_d__2;
          qdws[0].valid     = 1'b1;
          qdws[0].data      = {data[0*32 +: 2*32],pts.data[0+: 2*32]};
          qdws[0].dwen      = 4'b1111;
          qdws[0].sot       = pts.sot;
          qdws[0].eot       = 1'b1;
          qdw0_hdr_info     = get_hdr_info (3'd0, 3'd2, 1'b1, ca_h_info);
          qdws[0].has_pfx   = pts.has_pfx;
          qdws[0].hdr_valid = get_hdr_valid (3'd0, 3'd2, 1'b1, ca_h_val);
          qdws[0].dllp_err  = tlp_dllp_err[1];
          qdws[0].data_prot = {data_prot[0*DW_PROT_WD +: 2*DW_PROT_WD],pts.data_prot[0+: 2*DW_PROT_WD]};

          qdws[1].valid     = 1'b0;
          qdws[1].data      = 128'b0;
          qdws[1].dwen      = 4'b0000;
          qdws[1].sot       = 1'b0;
          qdws[1].eot       = 1'b0;
          qdw1_hdr_info     = DEFAULT_HDR_INFO;
          qdws[1].has_pfx   = 1'b0;
          qdws[1].hdr_valid = 1'b0;
          qdws[1].dllp_err  = 1'b0;
          qdws[1].data_prot = DEF_PROT_4DW;

          nts.nw            = 2'd1;
          nts.data          = {64'b0,data[2*32 +: 1*32]};
          nts.sot           = 1'b1;
          nts.eot           = 1'b0;
          nts_hdr_info      = get_hdr_info (3'd2, 3'd1, 1'b0, ca_h_info);
          nts.has_pfx       = tlp_pfx[2];
          nts.hdr_valid     = get_hdr_valid (3'd2, 3'd1, 1'b0, ca_h_val);
          nts.dllp_err      = 1'b0;
          nts.data_prot     = {DEF_PROT_2DW,data_prot[2*DW_PROT_WD +: 1*DW_PROT_WD]};
          chk_nts.status    = ONGOING;
        end

      pts.status==ONGOING && pts.nw==2'd2 && !tlp_idl[0] && !tlp_eot[0] && tlp_eot[1] && tlp_sot[2] && !tlp_idl[3] && !tlp_eot[3] && tlp_idl[4] :
        begin
          dec_case          = i_d_s_e_d__2;
          qdws[0].valid     = 1'b1;
          qdws[0].data      = {data[0*32 +: 2*32],pts.data[0+: 2*32]};
          qdws[0].dwen      = 4'b1111;
          qdws[0].sot       = pts.sot;
          qdws[0].eot       = 1'b1;
          qdw0_hdr_info     = get_hdr_info (3'd0, 3'd2, 1'b1, ca_h_info);
          qdws[0].has_pfx   = pts.has_pfx;
          qdws[0].hdr_valid = get_hdr_valid (3'd0, 3'd2, 1'b1, ca_h_val);
          qdws[0].dllp_err  = tlp_dllp_err[1];
          qdws[0].data_prot = {data_prot[0*DW_PROT_WD +: 2*DW_PROT_WD],pts.data_prot[0+: 2*DW_PROT_WD]};

          qdws[1].valid     = 1'b0;
          qdws[1].data      = 128'b0;
          qdws[1].dwen      = 4'b0000;
          qdws[1].sot       = 1'b0;
          qdws[1].eot       = 1'b0;
          qdw1_hdr_info     = DEFAULT_HDR_INFO;
          qdws[1].has_pfx   = 1'b0;
          qdws[1].hdr_valid = 1'b0;
          qdws[1].dllp_err  = 1'b0;
          qdws[1].data_prot = DEF_PROT_4DW;

          nts.nw            = 2'd2;
          nts.data          = {32'b0,data[2*32 +: 2*32]};
          nts.sot           = 1'b1;
          nts.eot           = 1'b0;
          nts_hdr_info      = get_hdr_info (3'd2, 3'd2, 1'b0, ca_h_info);
          nts.has_pfx       = tlp_pfx[2];
          nts.hdr_valid     = get_hdr_valid (3'd2, 3'd2, 1'b0, ca_h_val);
          nts.dllp_err      = 1'b0;
          nts.data_prot     = {DEF_PROT_1DW,data_prot[2*DW_PROT_WD +: 2*DW_PROT_WD]};
          chk_nts.status    = ONGOING;
        end

      pts.status==ONGOING && pts.nw==2'd2 && !tlp_idl[0] && !tlp_eot[0] && tlp_eot[1] && tlp_sot[2] && !tlp_idl[3] && !tlp_eot[3] && tlp_eot[4] :
        begin
          dec_case          = e_d_s_e_d__2;
          qdws[0].valid     = 1'b1;
          qdws[0].data      = {data[0*32 +: 2*32],pts.data[0+: 2*32]};
          qdws[0].dwen      = 4'b1111;
          qdws[0].sot       = pts.sot;
          qdws[0].eot       = 1'b1;
          qdw0_hdr_info     = get_hdr_info (3'd0, 3'd2, 1'b1, ca_h_info);
          qdws[0].has_pfx   = pts.has_pfx;
          qdws[0].hdr_valid = get_hdr_valid (3'd0, 3'd2, 1'b1, ca_h_val);
          qdws[0].dllp_err  = tlp_dllp_err[1];
          qdws[0].data_prot = {data_prot[0*DW_PROT_WD +: 2*DW_PROT_WD],pts.data_prot[0+: 2*DW_PROT_WD]};

          qdws[1].valid     = 1'b1;
          qdws[1].data      = {32'b0,data[2*32 +: 3*32]};
          qdws[1].dwen      = 4'b0111;
          qdws[1].sot       = 1'b1;
          qdws[1].eot       = 1'b1;
          qdw1_hdr_info     = get_hdr_info (3'd2, 3'd3, 1'b0, ca_h_info);
          qdws[1].has_pfx   = tlp_pfx[2];
          qdws[1].hdr_valid = get_hdr_valid (3'd2, 3'd3, 1'b0, ca_h_val);
          qdws[1].dllp_err  = tlp_dllp_err[4];
          qdws[1].data_prot = {DEF_PROT_1DW,data_prot[2*DW_PROT_WD +: 3*DW_PROT_WD]};

          nts.nw            = 2'd0;
          nts.data          = 96'b0;
          nts.sot           = 1'b0;
          nts.eot           = 1'b0;
          nts_hdr_info      = DEFAULT_HDR_INFO;
          nts.has_pfx       = 1'b0;
          nts.hdr_valid     = 1'b0;
          nts.dllp_err      = 1'b0;
          nts.data_prot     = DEF_PROT_3DW;
          chk_nts.status    = NOTHING;
        end

      pts.status==ONGOING && pts.nw==2'd2 && !tlp_idl[0] && !tlp_eot[0] && tlp_eot[1] && tlp_sot[2] && !tlp_idl[3] && !tlp_eot[3] && !tlp_idl[4] && !tlp_eot[4] :
        begin
          dec_case          = d_d_s_e_d__2;
          qdws[0].valid     = 1'b1;
          qdws[0].data      = {data[0*32 +: 2*32],pts.data[0+: 2*32]};
          qdws[0].dwen      = 4'b1111;
          qdws[0].sot       = pts.sot;
          qdws[0].eot       = 1'b1;
          qdw0_hdr_info     = get_hdr_info (3'd0, 3'd2, 1'b1, ca_h_info);
          qdws[0].has_pfx   = pts.has_pfx;
          qdws[0].hdr_valid = get_hdr_valid (3'd0, 3'd2, 1'b1, ca_h_val);
          qdws[0].dllp_err  = tlp_dllp_err[1];
          qdws[0].data_prot = {data_prot[0*DW_PROT_WD +: 2*DW_PROT_WD],pts.data_prot[0+: 2*DW_PROT_WD]};

          qdws[1].valid     = 1'b0;
          qdws[1].data      = 128'b0;
          qdws[1].dwen      = 4'b0000;
          qdws[1].sot       = 1'b0;
          qdws[1].eot       = 1'b0;
          qdw1_hdr_info     = DEFAULT_HDR_INFO;
          qdws[1].has_pfx   = 1'b0;
          qdws[1].hdr_valid = 1'b0;
          qdws[1].dllp_err  = 1'b0;
          qdws[1].data_prot = DEF_PROT_4DW;

          nts.nw            = 2'd3;
          nts.data          = data[2*32 +: 3*32];
          nts.sot           = 1'b1;
          nts.eot           = 1'b0;
          nts_hdr_info      = get_hdr_info (3'd2, 3'd3, 1'b0, ca_h_info);
          nts.has_pfx       = tlp_pfx[2];
          nts.hdr_valid     = get_hdr_valid (3'd2, 3'd3, 1'b0, ca_h_val);
          nts.dllp_err      = 1'b0;
          nts.data_prot     = data_prot[2*DW_PROT_WD +: 3*DW_PROT_WD];
          chk_nts.status    = ONGOING;
        end

      pts.status==ONGOING && pts.nw==2'd2 && !tlp_idl[0] && !tlp_eot[0] && !tlp_idl[1] && !tlp_eot[1] && tlp_idl[2] && tlp_idl[3] && tlp_idl[4] :
        begin
          dec_case          = i_i_i_d_d__2;
          qdws[0].valid     = 1'b1;
          qdws[0].data      = {data[0*32 +: 2*32],pts.data[0+: 2*32]};
          qdws[0].dwen      = 4'b1111;
          qdws[0].sot       = pts.sot;
          qdws[0].eot       = 1'b0;
          qdw0_hdr_info     = get_hdr_info (3'd0, 3'd2, 1'b1, ca_h_info);
          qdws[0].has_pfx   = pts.has_pfx;
          qdws[0].hdr_valid = get_hdr_valid (3'd0, 3'd2, 1'b1, ca_h_val);
          qdws[0].dllp_err  = 1'b0;
          qdws[0].data_prot = {data_prot[0*DW_PROT_WD +: 2*DW_PROT_WD],pts.data_prot[0+: 2*DW_PROT_WD]};

          qdws[1].valid     = 1'b0;
          qdws[1].data      = 128'b0;
          qdws[1].dwen      = 4'b0000;
          qdws[1].sot       = 1'b0;
          qdws[1].eot       = 1'b0;
          qdw1_hdr_info     = DEFAULT_HDR_INFO;
          qdws[1].has_pfx   = 1'b0;
          qdws[1].hdr_valid = 1'b0;
          qdws[1].dllp_err  = 1'b0;
          qdws[1].data_prot = DEF_PROT_4DW;

          nts.nw            = 2'd0;
          nts.data          = 96'b0;
          nts.sot           = 1'b0;
          nts.eot           = 1'b0;
          nts_hdr_info      = get_hdr_info (3'd0, 3'd2, 1'b1, ca_h_info);
          nts.has_pfx       = pts.has_pfx;
          nts.hdr_valid     = 1'b0;
          nts.dllp_err      = 1'b0;
          nts.data_prot     = DEF_PROT_3DW;
          chk_nts.status    = ONGOING;
        end

      pts.status==ONGOING && pts.nw==2'd2 && !tlp_idl[0] && !tlp_eot[0] && !tlp_idl[1] && !tlp_eot[1] && tlp_eot[2] && tlp_idl[3] && tlp_idl[4] :
        begin
          dec_case          = i_i_e_d_d__2;
          qdws[0].valid     = 1'b1;
          qdws[0].data      = {data[0*32 +: 2*32],pts.data[0+: 2*32]};
          qdws[0].dwen      = 4'b1111;
          qdws[0].sot       = pts.sot;
          qdws[0].eot       = 1'b0;
          qdw0_hdr_info     = get_hdr_info (3'd0, 3'd2, 1'b1, ca_h_info);
          qdws[0].has_pfx   = pts.has_pfx;
          qdws[0].hdr_valid = get_hdr_valid (3'd0, 3'd2, 1'b1, ca_h_val);
          qdws[0].dllp_err  = 1'b0;
          qdws[0].data_prot = {data_prot[0*DW_PROT_WD +: 2*DW_PROT_WD],pts.data_prot[0+: 2*DW_PROT_WD]};

          qdws[1].valid     = 1'b1;
          qdws[1].data      = {96'b0,data[2*32 +: 1*32]};
          qdws[1].dwen      = 4'b0001;
          qdws[1].sot       = 1'b0;
          qdws[1].eot       = 1'b1;
          qdw1_hdr_info     = get_hdr_info (3'd0, 3'd3, 1'b1, ca_h_info);
          qdws[1].has_pfx   = pts.has_pfx;
          qdws[1].hdr_valid = get_hdr_valid (3'd2, 3'd1, 1'b0, ca_h_val);
          qdws[1].dllp_err  = tlp_dllp_err[2];
          qdws[1].data_prot = {DEF_PROT_3DW,data_prot[2*DW_PROT_WD +: 1*DW_PROT_WD]};

          nts.nw            = 2'd0;
          nts.data          = 96'b0;
          nts.sot           = 1'b0;
          nts.eot           = 1'b0;
          nts_hdr_info      = get_hdr_info (3'd0, 3'd2, 1'b1, ca_h_info);
          nts.has_pfx       = pts.has_pfx;
          nts.hdr_valid     = 1'b0;
          nts.dllp_err      = 1'b0;
          nts.data_prot     = DEF_PROT_3DW;
          chk_nts.status    = NOTHING;
        end

      pts.status==ONGOING && pts.nw==2'd2 && !tlp_idl[0] && !tlp_eot[0] && !tlp_idl[1] && !tlp_eot[1] && tlp_eot[2] && tlp_idl[3] && tlp_sot[4] :
        begin
          dec_case          = s_i_e_d_d__2;
          qdws[0].valid     = 1'b1;
          qdws[0].data      = {data[0*32 +: 2*32],pts.data[0+: 2*32]};
          qdws[0].dwen      = 4'b1111;
          qdws[0].sot       = pts.sot;
          qdws[0].eot       = 1'b0;
          qdw0_hdr_info     = get_hdr_info (3'd0, 3'd2, 1'b1, ca_h_info);
          qdws[0].has_pfx   = pts.has_pfx;
          qdws[0].hdr_valid = get_hdr_valid (3'd0, 3'd2, 1'b1, ca_h_val);
          qdws[0].dllp_err  = 1'b0;
          qdws[0].data_prot = {data_prot[0*DW_PROT_WD +: 2*DW_PROT_WD],pts.data_prot[0+: 2*DW_PROT_WD]};

          qdws[1].valid     = 1'b1;
          qdws[1].data      = {96'b0,data[2*32 +: 1*32]};
          qdws[1].dwen      = 4'b0001;
          qdws[1].sot       = 1'b0;
          qdws[1].eot       = 1'b1;
          qdw1_hdr_info     = get_hdr_info (3'd0, 3'd3, 1'b1, ca_h_info);
          qdws[1].has_pfx   = pts.has_pfx;
          qdws[1].hdr_valid = get_hdr_valid (3'd2, 3'd1, 1'b0, ca_h_val);
          qdws[1].dllp_err  = tlp_dllp_err[2];
          qdws[1].data_prot = {DEF_PROT_3DW,data_prot[2*DW_PROT_WD +: 1*DW_PROT_WD]};

          nts.nw            = 2'd1;
          nts.data          = {64'b0,data[4*32 +: 1*32]};
          nts.sot           = 1'b1;
          nts.eot           = 1'b0;
          nts_hdr_info      = get_hdr_info (3'd4, 3'd1, 1'b0, ca_h_info);
          nts.has_pfx       = tlp_pfx[4];
          nts.hdr_valid     = get_hdr_valid (3'd4, 3'd1, 1'b0, ca_h_val);
          nts.dllp_err      = 1'b0;
          nts.data_prot     = {DEF_PROT_2DW,data_prot[4*DW_PROT_WD +: 1*DW_PROT_WD]};
          chk_nts.status    = ONGOING;
        end

      pts.status==ONGOING && pts.nw==2'd2 && !tlp_idl[0] && !tlp_eot[0] && !tlp_idl[1] && !tlp_eot[1] && tlp_eot[2] && tlp_sot[3] && tlp_idl[4] :
        begin
          dec_case          = i_s_e_d_d__2;
          qdws[0].valid     = 1'b1;
          qdws[0].data      = {data[0*32 +: 2*32],pts.data[0+: 2*32]};
          qdws[0].dwen      = 4'b1111;
          qdws[0].sot       = pts.sot;
          qdws[0].eot       = 1'b0;
          qdw0_hdr_info     = get_hdr_info (3'd0, 3'd2, 1'b1, ca_h_info);
          qdws[0].has_pfx   = pts.has_pfx;
          qdws[0].hdr_valid = get_hdr_valid (3'd0, 3'd2, 1'b1, ca_h_val);
          qdws[0].dllp_err  = 1'b0;
          qdws[0].data_prot = {data_prot[0*DW_PROT_WD +: 2*DW_PROT_WD],pts.data_prot[0+: 2*DW_PROT_WD]};

          qdws[1].valid     = 1'b1;
          qdws[1].data      = {96'b0,data[2*32 +: 1*32]};
          qdws[1].dwen      = 4'b0001;
          qdws[1].sot       = 1'b0;
          qdws[1].eot       = 1'b1;
          qdw1_hdr_info     = get_hdr_info (3'd0, 3'd3, 1'b1, ca_h_info);
          qdws[1].has_pfx   = pts.has_pfx;
          qdws[1].hdr_valid = get_hdr_valid (3'd2, 3'd1, 1'b0, ca_h_val);
          qdws[1].dllp_err  = tlp_dllp_err[2];
          qdws[1].data_prot = {DEF_PROT_3DW,data_prot[2*DW_PROT_WD +: 1*DW_PROT_WD]};

          nts.nw            = 2'd1;
          nts.data          = {64'b0,data[3*32 +: 1*32]};
          nts.sot           = 1'b1;
          nts.eot           = 1'b0;
          nts_hdr_info      = get_hdr_info (3'd3, 3'd1, 1'b0, ca_h_info);
          nts.has_pfx       = tlp_pfx[3];
          nts.hdr_valid     = get_hdr_valid (3'd3, 3'd1, 1'b0, ca_h_val);
          nts.dllp_err      = 1'b0;
          nts.data_prot     = {DEF_PROT_2DW,data_prot[3*DW_PROT_WD +: 1*DW_PROT_WD]};
          chk_nts.status    = ONGOING;
        end

      pts.status==ONGOING && pts.nw==2'd2 && !tlp_idl[0] && !tlp_eot[0] && !tlp_idl[1] && !tlp_eot[1] && tlp_eot[2] && tlp_sot[3] && !tlp_idl[4] && !tlp_eot[4] :
        begin
          dec_case          = d_s_e_d_d__2;
          qdws[0].valid     = 1'b1;
          qdws[0].data      = {data[0*32 +: 2*32],pts.data[0+: 2*32]};
          qdws[0].dwen      = 4'b1111;
          qdws[0].sot       = pts.sot;
          qdws[0].eot       = 1'b0;
          qdw0_hdr_info     = get_hdr_info (3'd0, 3'd2, 1'b1, ca_h_info);
          qdws[0].has_pfx   = pts.has_pfx;
          qdws[0].hdr_valid = get_hdr_valid (3'd0, 3'd2, 1'b1, ca_h_val);
          qdws[0].dllp_err  = 1'b0;
          qdws[0].data_prot = {data_prot[0*DW_PROT_WD +: 2*DW_PROT_WD],pts.data_prot[0+: 2*DW_PROT_WD]};

          qdws[1].valid     = 1'b1;
          qdws[1].data      = {96'b0,data[2*32 +: 1*32]};
          qdws[1].dwen      = 4'b0001;
          qdws[1].sot       = 1'b0;
          qdws[1].eot       = 1'b1;
          qdw1_hdr_info     = get_hdr_info (3'd0, 3'd3, 1'b1, ca_h_info);
          qdws[1].has_pfx   = pts.has_pfx;
          qdws[1].hdr_valid = get_hdr_valid (3'd2, 3'd1, 1'b0, ca_h_val);
          qdws[1].dllp_err  = tlp_dllp_err[2];
          qdws[1].data_prot = {DEF_PROT_3DW,data_prot[2*DW_PROT_WD +: 1*DW_PROT_WD]};

          nts.nw            = 2'd2;
          nts.data          = {32'b0,data[3*32 +: 2*32]};
          nts.sot           = 1'b1;
          nts.eot           = 1'b0;
          nts_hdr_info      = get_hdr_info (3'd3, 3'd2, 1'b0, ca_h_info);
          nts.has_pfx       = tlp_pfx[3];
          nts.hdr_valid     = get_hdr_valid (3'd3, 3'd2, 1'b0, ca_h_val);
          nts.dllp_err      = 1'b0;
          nts.data_prot     = {DEF_PROT_1DW,data_prot[3*DW_PROT_WD +: 2*DW_PROT_WD]};
          chk_nts.status    = ONGOING;
        end

      pts.status==ONGOING && pts.nw==2'd2 && !tlp_idl[0] && !tlp_eot[0] && !tlp_idl[1] && !tlp_eot[1] && !tlp_idl[2] && !tlp_eot[2] && tlp_idl[3] && tlp_idl[4] :
        begin
          dec_case          = i_i_d_d_d__2;
          qdws[0].valid     = 1'b1;
          qdws[0].data      = {data[0*32 +: 2*32],pts.data[0+: 2*32]};
          qdws[0].dwen      = 4'b1111;
          qdws[0].sot       = pts.sot;
          qdws[0].eot       = 1'b0;
          qdw0_hdr_info     = get_hdr_info (3'd0, 3'd2, 1'b1, ca_h_info);
          qdws[0].has_pfx   = pts.has_pfx;
          qdws[0].hdr_valid = get_hdr_valid (3'd0, 3'd2, 1'b1, ca_h_val);
          qdws[0].dllp_err  = 1'b0;
          qdws[0].data_prot = {data_prot[0*DW_PROT_WD +: 2*DW_PROT_WD],pts.data_prot[0+: 2*DW_PROT_WD]};

          qdws[1].valid     = 1'b0;
          qdws[1].data      = 128'b0;
          qdws[1].dwen      = 4'b0000;
          qdws[1].sot       = 1'b0;
          qdws[1].eot       = 1'b0;
          qdw1_hdr_info     = DEFAULT_HDR_INFO;
          qdws[1].has_pfx   = 1'b0;
          qdws[1].hdr_valid = 1'b0;
          qdws[1].dllp_err  = 1'b0;
          qdws[1].data_prot = DEF_PROT_4DW;

          nts.nw            = 2'd1;
          nts.data          = {64'b0,data[2*32 +: 1*32]};
          nts.sot           = 1'b0;
          nts.eot           = 1'b0;
          nts_hdr_info      = get_hdr_info (3'd0, 3'd3, 1'b1, ca_h_info);
          nts.has_pfx       = pts.has_pfx;
          nts.hdr_valid     = get_hdr_valid (3'd2, 3'd1, 1'b0, ca_h_val);
          nts.dllp_err      = 1'b0;
          nts.data_prot     = {DEF_PROT_2DW,data_prot[2*DW_PROT_WD +: 1*DW_PROT_WD]};
          chk_nts.status    = ONGOING;
        end

      pts.status==ONGOING && pts.nw==2'd2 && !tlp_idl[0] && !tlp_eot[0] && !tlp_idl[1] && !tlp_eot[1] && !tlp_idl[2] && !tlp_eot[2] && tlp_eot[3] && tlp_idl[4] :
        begin
          dec_case          = i_e_d_d_d__2;
          qdws[0].valid     = 1'b1;
          qdws[0].data      = {data[0*32 +: 2*32],pts.data[0+: 2*32]};
          qdws[0].dwen      = 4'b1111;
          qdws[0].sot       = pts.sot;
          qdws[0].eot       = 1'b0;
          qdw0_hdr_info     = get_hdr_info (3'd0, 3'd2, 1'b1, ca_h_info);
          qdws[0].has_pfx   = pts.has_pfx;
          qdws[0].hdr_valid = get_hdr_valid (3'd0, 3'd2, 1'b1, ca_h_val);
          qdws[0].dllp_err  = 1'b0;
          qdws[0].data_prot = {data_prot[0*DW_PROT_WD +: 2*DW_PROT_WD],pts.data_prot[0+: 2*DW_PROT_WD]};

          qdws[1].valid     = 1'b1;
          qdws[1].data      = {64'b0,data[2*32 +: 2*32]};
          qdws[1].dwen      = 4'b0011;
          qdws[1].sot       = 1'b0;
          qdws[1].eot       = 1'b1;
          qdw1_hdr_info     = get_hdr_info (3'd0, 3'd4, 1'b1, ca_h_info);
          qdws[1].has_pfx   = pts.has_pfx;
          qdws[1].hdr_valid = get_hdr_valid (3'd2, 3'd2, 1'b0, ca_h_val);
          qdws[1].dllp_err  = tlp_dllp_err[3];
          qdws[1].data_prot = {DEF_PROT_2DW,data_prot[2*DW_PROT_WD +: 2*DW_PROT_WD]};

          nts.nw            = 2'd0;
          nts.data          = 96'b0;
          nts.sot           = 1'b0;
          nts.eot           = 1'b0;
          nts_hdr_info      = get_hdr_info (3'd0, 3'd2, 1'b1, ca_h_info);
          nts.has_pfx       = pts.has_pfx;
          nts.hdr_valid     = 1'b0;
          nts.dllp_err      = 1'b0;
          nts.data_prot     = DEF_PROT_3DW;
          chk_nts.status    = NOTHING;
        end

      pts.status==ONGOING && pts.nw==2'd2 && !tlp_idl[0] && !tlp_eot[0] && !tlp_idl[1] && !tlp_eot[1] && !tlp_idl[2] && !tlp_eot[2] && tlp_eot[3] && tlp_sot[4] :
        begin
          dec_case          = s_e_d_d_d__2;
          qdws[0].valid     = 1'b1;
          qdws[0].data      = {data[0*32 +: 2*32],pts.data[0+: 2*32]};
          qdws[0].dwen      = 4'b1111;
          qdws[0].sot       = pts.sot;
          qdws[0].eot       = 1'b0;
          qdw0_hdr_info     = get_hdr_info (3'd0, 3'd2, 1'b1, ca_h_info);
          qdws[0].has_pfx   = pts.has_pfx;
          qdws[0].hdr_valid = get_hdr_valid (3'd0, 3'd2, 1'b1, ca_h_val);
          qdws[0].dllp_err  = 1'b0;
          qdws[0].data_prot = {data_prot[0*DW_PROT_WD +: 2*DW_PROT_WD],pts.data_prot[0+: 2*DW_PROT_WD]};

          qdws[1].valid     = 1'b1;
          qdws[1].data      = {64'b0,data[2*32 +: 2*32]};
          qdws[1].dwen      = 4'b0011;
          qdws[1].sot       = 1'b0;
          qdws[1].eot       = 1'b1;
          qdw1_hdr_info     = get_hdr_info (3'd0, 3'd4, 1'b1, ca_h_info);
          qdws[1].has_pfx   = pts.has_pfx;
          qdws[1].hdr_valid = get_hdr_valid (3'd2, 3'd2, 1'b0, ca_h_val);
          qdws[1].dllp_err  = tlp_dllp_err[3];
          qdws[1].data_prot = {DEF_PROT_2DW,data_prot[2*DW_PROT_WD +: 2*DW_PROT_WD]};

          nts.nw            = 2'd1;
          nts.data          = {64'b0,data[4*32 +: 1*32]};
          nts.sot           = 1'b1;
          nts.eot           = 1'b0;
          nts_hdr_info      = get_hdr_info (3'd4, 3'd1, 1'b0, ca_h_info);
          nts.has_pfx       = tlp_pfx[4];
          nts.hdr_valid     = get_hdr_valid (3'd4, 3'd1, 1'b0, ca_h_val);
          nts.dllp_err      = 1'b0;
          nts.data_prot     = {DEF_PROT_2DW,data_prot[4*DW_PROT_WD +: 1*DW_PROT_WD]};
          chk_nts.status    = ONGOING;
        end

      pts.status==ONGOING && pts.nw==2'd2 && !tlp_idl[0] && !tlp_eot[0] && !tlp_idl[1] && !tlp_eot[1] && !tlp_idl[2] && !tlp_eot[2] && !tlp_idl[3] && !tlp_eot[3] && tlp_idl[4] :
        begin
          dec_case          = i_d_d_d_d__2;
          qdws[0].valid     = 1'b1;
          qdws[0].data      = {data[0*32 +: 2*32],pts.data[0+: 2*32]};
          qdws[0].dwen      = 4'b1111;
          qdws[0].sot       = pts.sot;
          qdws[0].eot       = 1'b0;
          qdw0_hdr_info     = get_hdr_info (3'd0, 3'd2, 1'b1, ca_h_info);
          qdws[0].has_pfx   = pts.has_pfx;
          qdws[0].hdr_valid = get_hdr_valid (3'd0, 3'd2, 1'b1, ca_h_val);
          qdws[0].dllp_err  = 1'b0;
          qdws[0].data_prot = {data_prot[0*DW_PROT_WD +: 2*DW_PROT_WD],pts.data_prot[0+: 2*DW_PROT_WD]};

          qdws[1].valid     = 1'b0;
          qdws[1].data      = 128'b0;
          qdws[1].dwen      = 4'b0000;
          qdws[1].sot       = 1'b0;
          qdws[1].eot       = 1'b0;
          qdw1_hdr_info     = DEFAULT_HDR_INFO;
          qdws[1].has_pfx   = 1'b0;
          qdws[1].hdr_valid = 1'b0;
          qdws[1].dllp_err  = 1'b0;
          qdws[1].data_prot = DEF_PROT_4DW;

          nts.nw            = 2'd2;
          nts.data          = {32'b0,data[2*32 +: 2*32]};
          nts.sot           = 1'b0;
          nts.eot           = 1'b0;
          nts_hdr_info      = get_hdr_info (3'd0, 3'd4, 1'b1, ca_h_info);
          nts.has_pfx       = pts.has_pfx;
          nts.hdr_valid     = get_hdr_valid (3'd2, 3'd2, 1'b0, ca_h_val);
          nts.dllp_err      = 1'b0;
          nts.data_prot     = {DEF_PROT_1DW,data_prot[2*DW_PROT_WD +: 2*DW_PROT_WD]};
          chk_nts.status    = ONGOING;
        end

      pts.status==ONGOING && pts.nw==2'd2 && !tlp_idl[0] && !tlp_eot[0] && !tlp_idl[1] && !tlp_eot[1] && !tlp_idl[2] && !tlp_eot[2] && !tlp_idl[3] && !tlp_eot[3] && tlp_eot[4] :
        begin
          dec_case          = e_d_d_d_d__2;
          qdws[0].valid     = 1'b1;
          qdws[0].data      = {data[0*32 +: 2*32],pts.data[0+: 2*32]};
          qdws[0].dwen      = 4'b1111;
          qdws[0].sot       = pts.sot;
          qdws[0].eot       = 1'b0;
          qdw0_hdr_info     = get_hdr_info (3'd0, 3'd2, 1'b1, ca_h_info);
          qdws[0].has_pfx   = pts.has_pfx;
          qdws[0].hdr_valid = get_hdr_valid (3'd0, 3'd2, 1'b1, ca_h_val);
          qdws[0].dllp_err  = 1'b0;
          qdws[0].data_prot = {data_prot[0*DW_PROT_WD +: 2*DW_PROT_WD],pts.data_prot[0+: 2*DW_PROT_WD]};

          qdws[1].valid     = 1'b1;
          qdws[1].data      = {32'b0,data[2*32 +: 3*32]};
          qdws[1].dwen      = 4'b0111;
          qdws[1].sot       = 1'b0;
          qdws[1].eot       = 1'b1;
          qdw1_hdr_info     = get_hdr_info (3'd0, 3'd5, 1'b1, ca_h_info);
          qdws[1].has_pfx   = pts.has_pfx;
          qdws[1].hdr_valid = get_hdr_valid (3'd2, 3'd3, 1'b0, ca_h_val);
          qdws[1].dllp_err  = tlp_dllp_err[4];
          qdws[1].data_prot = {DEF_PROT_1DW,data_prot[2*DW_PROT_WD +: 3*DW_PROT_WD]};

          nts.nw            = 2'd0;
          nts.data          = 96'b0;
          nts.sot           = 1'b0;
          nts.eot           = 1'b0;
          nts_hdr_info      = get_hdr_info (3'd0, 3'd2, 1'b1, ca_h_info);
          nts.has_pfx       = pts.has_pfx;
          nts.hdr_valid     = 1'b0;
          nts.dllp_err      = 1'b0;
          nts.data_prot     = DEF_PROT_3DW;
          chk_nts.status    = NOTHING;
        end

      pts.status==ONGOING && pts.nw==2'd2 && !tlp_idl[0] && !tlp_eot[0] && !tlp_idl[1] && !tlp_eot[1] && !tlp_idl[2] && !tlp_eot[2] && !tlp_idl[3] && !tlp_eot[3] && !tlp_idl[4] && !tlp_eot[4] :
        begin
          dec_case          = d_d_d_d_d__2;
          qdws[0].valid     = 1'b1;
          qdws[0].data      = {data[0*32 +: 2*32],pts.data[0+: 2*32]};
          qdws[0].dwen      = 4'b1111;
          qdws[0].sot       = pts.sot;
          qdws[0].eot       = 1'b0;
          qdw0_hdr_info     = get_hdr_info (3'd0, 3'd2, 1'b1, ca_h_info);
          qdws[0].has_pfx   = pts.has_pfx;
          qdws[0].hdr_valid = get_hdr_valid (3'd0, 3'd2, 1'b1, ca_h_val);
          qdws[0].dllp_err  = 1'b0;
          qdws[0].data_prot = {data_prot[0*DW_PROT_WD +: 2*DW_PROT_WD],pts.data_prot[0+: 2*DW_PROT_WD]};

          qdws[1].valid     = 1'b0;
          qdws[1].data      = 128'b0;
          qdws[1].dwen      = 4'b0000;
          qdws[1].sot       = 1'b0;
          qdws[1].eot       = 1'b0;
          qdw1_hdr_info     = DEFAULT_HDR_INFO;
          qdws[1].has_pfx   = 1'b0;
          qdws[1].hdr_valid = 1'b0;
          qdws[1].dllp_err  = 1'b0;
          qdws[1].data_prot = DEF_PROT_4DW;

          nts.nw            = 2'd3;
          nts.data          = data[2*32 +: 3*32];
          nts.sot           = 1'b0;
          nts.eot           = 1'b0;
          nts_hdr_info      = get_hdr_info (3'd0, 3'd5, 1'b1, ca_h_info);
          nts.has_pfx       = pts.has_pfx;
          nts.hdr_valid     = get_hdr_valid (3'd2, 3'd3, 1'b0, ca_h_val);
          nts.dllp_err      = 1'b0;
          nts.data_prot     = data_prot[2*DW_PROT_WD +: 3*DW_PROT_WD];
          chk_nts.status    = ONGOING;
        end

      pts.status==ONGOING && pts.nw==2'd3 && tlp_eot[0] && tlp_idl[1] && tlp_idl[2] && tlp_idl[3] && tlp_idl[4] :
        begin
          dec_case          = i_i_i_i_e__3;
          qdws[0].valid     = 1'b1;
          qdws[0].data      = {data[0*32 +: 1*32],pts.data[0+: 3*32]};
          qdws[0].dwen      = 4'b1111;
          qdws[0].sot       = pts.sot;
          qdws[0].eot       = 1'b1;
          qdw0_hdr_info     = get_hdr_info (3'd0, 3'd1, 1'b1, ca_h_info);
          qdws[0].has_pfx   = pts.has_pfx;
          qdws[0].hdr_valid = get_hdr_valid (3'd0, 3'd1, 1'b1, ca_h_val);
          qdws[0].dllp_err  = tlp_dllp_err[0];
          qdws[0].data_prot = {data_prot[0*DW_PROT_WD +: 1*DW_PROT_WD],pts.data_prot[0+: 3*DW_PROT_WD]};

          qdws[1].valid     = 1'b0;
          qdws[1].data      = 128'b0;
          qdws[1].dwen      = 4'b0000;
          qdws[1].sot       = 1'b0;
          qdws[1].eot       = 1'b0;
          qdw1_hdr_info     = DEFAULT_HDR_INFO;
          qdws[1].has_pfx   = 1'b0;
          qdws[1].hdr_valid = 1'b0;
          qdws[1].dllp_err  = 1'b0;
          qdws[1].data_prot = DEF_PROT_4DW;

          nts.nw            = 2'd0;
          nts.data          = 96'b0;
          nts.sot           = 1'b0;
          nts.eot           = 1'b0;
          nts_hdr_info      = DEFAULT_HDR_INFO;
          nts.has_pfx       = 1'b0;
          nts.hdr_valid     = 1'b0;
          nts.dllp_err      = 1'b0;
          nts.data_prot     = DEF_PROT_3DW;
          chk_nts.status    = NOTHING;
        end

      pts.status==ONGOING && pts.nw==2'd3 && tlp_eot[0] && tlp_idl[1] && tlp_idl[2] && tlp_idl[3] && tlp_sot[4] :
        begin
          dec_case          = s_i_i_i_e__3;
          qdws[0].valid     = 1'b1;
          qdws[0].data      = {data[0*32 +: 1*32],pts.data[0+: 3*32]};
          qdws[0].dwen      = 4'b1111;
          qdws[0].sot       = pts.sot;
          qdws[0].eot       = 1'b1;
          qdw0_hdr_info     = get_hdr_info (3'd0, 3'd1, 1'b1, ca_h_info);
          qdws[0].has_pfx   = pts.has_pfx;
          qdws[0].hdr_valid = get_hdr_valid (3'd0, 3'd1, 1'b1, ca_h_val);
          qdws[0].dllp_err  = tlp_dllp_err[0];
          qdws[0].data_prot = {data_prot[0*DW_PROT_WD +: 1*DW_PROT_WD],pts.data_prot[0+: 3*DW_PROT_WD]};

          qdws[1].valid     = 1'b0;
          qdws[1].data      = 128'b0;
          qdws[1].dwen      = 4'b0000;
          qdws[1].sot       = 1'b0;
          qdws[1].eot       = 1'b0;
          qdw1_hdr_info     = DEFAULT_HDR_INFO;
          qdws[1].has_pfx   = 1'b0;
          qdws[1].hdr_valid = 1'b0;
          qdws[1].dllp_err  = 1'b0;
          qdws[1].data_prot = DEF_PROT_4DW;

          nts.nw            = 2'd1;
          nts.data          = {64'b0,data[4*32 +: 1*32]};
          nts.sot           = 1'b1;
          nts.eot           = 1'b0;
          nts_hdr_info      = get_hdr_info (3'd4, 3'd1, 1'b0, ca_h_info);
          nts.has_pfx       = tlp_pfx[4];
          nts.hdr_valid     = get_hdr_valid (3'd4, 3'd1, 1'b0, ca_h_val);
          nts.dllp_err      = 1'b0;
          nts.data_prot     = {DEF_PROT_2DW,data_prot[4*DW_PROT_WD +: 1*DW_PROT_WD]};
          chk_nts.status    = ONGOING;
        end

      pts.status==ONGOING && pts.nw==2'd3 && tlp_eot[0] && tlp_idl[1] && tlp_idl[2] && tlp_sot[3] && tlp_idl[4] :
        begin
          dec_case          = i_s_i_i_e__3;
          qdws[0].valid     = 1'b1;
          qdws[0].data      = {data[0*32 +: 1*32],pts.data[0+: 3*32]};
          qdws[0].dwen      = 4'b1111;
          qdws[0].sot       = pts.sot;
          qdws[0].eot       = 1'b1;
          qdw0_hdr_info     = get_hdr_info (3'd0, 3'd1, 1'b1, ca_h_info);
          qdws[0].has_pfx   = pts.has_pfx;
          qdws[0].hdr_valid = get_hdr_valid (3'd0, 3'd1, 1'b1, ca_h_val);
          qdws[0].dllp_err  = tlp_dllp_err[0];
          qdws[0].data_prot = {data_prot[0*DW_PROT_WD +: 1*DW_PROT_WD],pts.data_prot[0+: 3*DW_PROT_WD]};

          qdws[1].valid     = 1'b0;
          qdws[1].data      = 128'b0;
          qdws[1].dwen      = 4'b0000;
          qdws[1].sot       = 1'b0;
          qdws[1].eot       = 1'b0;
          qdw1_hdr_info     = DEFAULT_HDR_INFO;
          qdws[1].has_pfx   = 1'b0;
          qdws[1].hdr_valid = 1'b0;
          qdws[1].dllp_err  = 1'b0;
          qdws[1].data_prot = DEF_PROT_4DW;

          nts.nw            = 2'd1;
          nts.data          = {64'b0,data[3*32 +: 1*32]};
          nts.sot           = 1'b1;
          nts.eot           = 1'b0;
          nts_hdr_info      = get_hdr_info (3'd3, 3'd1, 1'b0, ca_h_info);
          nts.has_pfx       = tlp_pfx[3];
          nts.hdr_valid     = get_hdr_valid (3'd3, 3'd1, 1'b0, ca_h_val);
          nts.dllp_err      = 1'b0;
          nts.data_prot     = {DEF_PROT_2DW,data_prot[3*DW_PROT_WD +: 1*DW_PROT_WD]};
          chk_nts.status    = ONGOING;
        end

      pts.status==ONGOING && pts.nw==2'd3 && tlp_eot[0] && tlp_idl[1] && tlp_idl[2] && tlp_sot[3] && !tlp_idl[4] && !tlp_eot[4] :
        begin
          dec_case          = d_s_i_i_e__3;
          qdws[0].valid     = 1'b1;
          qdws[0].data      = {data[0*32 +: 1*32],pts.data[0+: 3*32]};
          qdws[0].dwen      = 4'b1111;
          qdws[0].sot       = pts.sot;
          qdws[0].eot       = 1'b1;
          qdw0_hdr_info     = get_hdr_info (3'd0, 3'd1, 1'b1, ca_h_info);
          qdws[0].has_pfx   = pts.has_pfx;
          qdws[0].hdr_valid = get_hdr_valid (3'd0, 3'd1, 1'b1, ca_h_val);
          qdws[0].dllp_err  = tlp_dllp_err[0];
          qdws[0].data_prot = {data_prot[0*DW_PROT_WD +: 1*DW_PROT_WD],pts.data_prot[0+: 3*DW_PROT_WD]};

          qdws[1].valid     = 1'b0;
          qdws[1].data      = 128'b0;
          qdws[1].dwen      = 4'b0000;
          qdws[1].sot       = 1'b0;
          qdws[1].eot       = 1'b0;
          qdw1_hdr_info     = DEFAULT_HDR_INFO;
          qdws[1].has_pfx   = 1'b0;
          qdws[1].hdr_valid = 1'b0;
          qdws[1].dllp_err  = 1'b0;
          qdws[1].data_prot = DEF_PROT_4DW;

          nts.nw            = 2'd2;
          nts.data          = {32'b0,data[3*32 +: 2*32]};
          nts.sot           = 1'b1;
          nts.eot           = 1'b0;
          nts_hdr_info      = get_hdr_info (3'd3, 3'd2, 1'b0, ca_h_info);
          nts.has_pfx       = tlp_pfx[3];
          nts.hdr_valid     = get_hdr_valid (3'd3, 3'd2, 1'b0, ca_h_val);
          nts.dllp_err      = 1'b0;
          nts.data_prot     = {DEF_PROT_1DW,data_prot[3*DW_PROT_WD +: 2*DW_PROT_WD]};
          chk_nts.status    = ONGOING;
        end

      pts.status==ONGOING && pts.nw==2'd3 && tlp_eot[0] && tlp_idl[1] && tlp_sot[2] && tlp_idl[3] && tlp_idl[4] :
        begin
          dec_case          = i_i_s_i_e__3;
          qdws[0].valid     = 1'b1;
          qdws[0].data      = {data[0*32 +: 1*32],pts.data[0+: 3*32]};
          qdws[0].dwen      = 4'b1111;
          qdws[0].sot       = pts.sot;
          qdws[0].eot       = 1'b1;
          qdw0_hdr_info     = get_hdr_info (3'd0, 3'd1, 1'b1, ca_h_info);
          qdws[0].has_pfx   = pts.has_pfx;
          qdws[0].hdr_valid = get_hdr_valid (3'd0, 3'd1, 1'b1, ca_h_val);
          qdws[0].dllp_err  = tlp_dllp_err[0];
          qdws[0].data_prot = {data_prot[0*DW_PROT_WD +: 1*DW_PROT_WD],pts.data_prot[0+: 3*DW_PROT_WD]};

          qdws[1].valid     = 1'b0;
          qdws[1].data      = 128'b0;
          qdws[1].dwen      = 4'b0000;
          qdws[1].sot       = 1'b0;
          qdws[1].eot       = 1'b0;
          qdw1_hdr_info     = DEFAULT_HDR_INFO;
          qdws[1].has_pfx   = 1'b0;
          qdws[1].hdr_valid = 1'b0;
          qdws[1].dllp_err  = 1'b0;
          qdws[1].data_prot = DEF_PROT_4DW;

          nts.nw            = 2'd1;
          nts.data          = {64'b0,data[2*32 +: 1*32]};
          nts.sot           = 1'b1;
          nts.eot           = 1'b0;
          nts_hdr_info      = get_hdr_info (3'd2, 3'd1, 1'b0, ca_h_info);
          nts.has_pfx       = tlp_pfx[2];
          nts.hdr_valid     = get_hdr_valid (3'd2, 3'd1, 1'b0, ca_h_val);
          nts.dllp_err      = 1'b0;
          nts.data_prot     = {DEF_PROT_2DW,data_prot[2*DW_PROT_WD +: 1*DW_PROT_WD]};
          chk_nts.status    = ONGOING;
        end

      pts.status==ONGOING && pts.nw==2'd3 && tlp_eot[0] && tlp_idl[1] && tlp_sot[2] && !tlp_idl[3] && !tlp_eot[3] && tlp_idl[4] :
        begin
          dec_case          = i_d_s_i_e__3;
          qdws[0].valid     = 1'b1;
          qdws[0].data      = {data[0*32 +: 1*32],pts.data[0+: 3*32]};
          qdws[0].dwen      = 4'b1111;
          qdws[0].sot       = pts.sot;
          qdws[0].eot       = 1'b1;
          qdw0_hdr_info     = get_hdr_info (3'd0, 3'd1, 1'b1, ca_h_info);
          qdws[0].has_pfx   = pts.has_pfx;
          qdws[0].hdr_valid = get_hdr_valid (3'd0, 3'd1, 1'b1, ca_h_val);
          qdws[0].dllp_err  = tlp_dllp_err[0];
          qdws[0].data_prot = {data_prot[0*DW_PROT_WD +: 1*DW_PROT_WD],pts.data_prot[0+: 3*DW_PROT_WD]};

          qdws[1].valid     = 1'b0;
          qdws[1].data      = 128'b0;
          qdws[1].dwen      = 4'b0000;
          qdws[1].sot       = 1'b0;
          qdws[1].eot       = 1'b0;
          qdw1_hdr_info     = DEFAULT_HDR_INFO;
          qdws[1].has_pfx   = 1'b0;
          qdws[1].hdr_valid = 1'b0;
          qdws[1].dllp_err  = 1'b0;
          qdws[1].data_prot = DEF_PROT_4DW;

          nts.nw            = 2'd2;
          nts.data          = {32'b0,data[2*32 +: 2*32]};
          nts.sot           = 1'b1;
          nts.eot           = 1'b0;
          nts_hdr_info      = get_hdr_info (3'd2, 3'd2, 1'b0, ca_h_info);
          nts.has_pfx       = tlp_pfx[2];
          nts.hdr_valid     = get_hdr_valid (3'd2, 3'd2, 1'b0, ca_h_val);
          nts.dllp_err      = 1'b0;
          nts.data_prot     = {DEF_PROT_1DW,data_prot[2*DW_PROT_WD +: 2*DW_PROT_WD]};
          chk_nts.status    = ONGOING;
        end

      pts.status==ONGOING && pts.nw==2'd3 && tlp_eot[0] && tlp_idl[1] && tlp_sot[2] && !tlp_idl[3] && !tlp_eot[3] && tlp_eot[4] :
        begin
          dec_case          = e_d_s_i_e__3;
          qdws[0].valid     = 1'b1;
          qdws[0].data      = {data[0*32 +: 1*32],pts.data[0+: 3*32]};
          qdws[0].dwen      = 4'b1111;
          qdws[0].sot       = pts.sot;
          qdws[0].eot       = 1'b1;
          qdw0_hdr_info     = get_hdr_info (3'd0, 3'd1, 1'b1, ca_h_info);
          qdws[0].has_pfx   = pts.has_pfx;
          qdws[0].hdr_valid = get_hdr_valid (3'd0, 3'd1, 1'b1, ca_h_val);
          qdws[0].dllp_err  = tlp_dllp_err[0];
          qdws[0].data_prot = {data_prot[0*DW_PROT_WD +: 1*DW_PROT_WD],pts.data_prot[0+: 3*DW_PROT_WD]};

          qdws[1].valid     = 1'b1;
          qdws[1].data      = {32'b0,data[2*32 +: 3*32]};
          qdws[1].dwen      = 4'b0111;
          qdws[1].sot       = 1'b1;
          qdws[1].eot       = 1'b1;
          qdw1_hdr_info     = get_hdr_info (3'd2, 3'd3, 1'b0, ca_h_info);
          qdws[1].has_pfx   = tlp_pfx[2];
          qdws[1].hdr_valid = get_hdr_valid (3'd2, 3'd3, 1'b0, ca_h_val);
          qdws[1].dllp_err  = tlp_dllp_err[4];
          qdws[1].data_prot = {DEF_PROT_1DW,data_prot[2*DW_PROT_WD +: 3*DW_PROT_WD]};

          nts.nw            = 2'd0;
          nts.data          = 96'b0;
          nts.sot           = 1'b0;
          nts.eot           = 1'b0;
          nts_hdr_info      = DEFAULT_HDR_INFO;
          nts.has_pfx       = 1'b0;
          nts.hdr_valid     = 1'b0;
          nts.dllp_err      = 1'b0;
          nts.data_prot     = DEF_PROT_3DW;
          chk_nts.status    = NOTHING;
        end

      pts.status==ONGOING && pts.nw==2'd3 && tlp_eot[0] && tlp_idl[1] && tlp_sot[2] && !tlp_idl[3] && !tlp_eot[3] && !tlp_idl[4] && !tlp_eot[4] :
        begin
          dec_case          = d_d_s_i_e__3;
          qdws[0].valid     = 1'b1;
          qdws[0].data      = {data[0*32 +: 1*32],pts.data[0+: 3*32]};
          qdws[0].dwen      = 4'b1111;
          qdws[0].sot       = pts.sot;
          qdws[0].eot       = 1'b1;
          qdw0_hdr_info     = get_hdr_info (3'd0, 3'd1, 1'b1, ca_h_info);
          qdws[0].has_pfx   = pts.has_pfx;
          qdws[0].hdr_valid = get_hdr_valid (3'd0, 3'd1, 1'b1, ca_h_val);
          qdws[0].dllp_err  = tlp_dllp_err[0];
          qdws[0].data_prot = {data_prot[0*DW_PROT_WD +: 1*DW_PROT_WD],pts.data_prot[0+: 3*DW_PROT_WD]};

          qdws[1].valid     = 1'b0;
          qdws[1].data      = 128'b0;
          qdws[1].dwen      = 4'b0000;
          qdws[1].sot       = 1'b0;
          qdws[1].eot       = 1'b0;
          qdw1_hdr_info     = DEFAULT_HDR_INFO;
          qdws[1].has_pfx   = 1'b0;
          qdws[1].hdr_valid = 1'b0;
          qdws[1].dllp_err  = 1'b0;
          qdws[1].data_prot = DEF_PROT_4DW;

          nts.nw            = 2'd3;
          nts.data          = data[2*32 +: 3*32];
          nts.sot           = 1'b1;
          nts.eot           = 1'b0;
          nts_hdr_info      = get_hdr_info (3'd2, 3'd3, 1'b0, ca_h_info);
          nts.has_pfx       = tlp_pfx[2];
          nts.hdr_valid     = get_hdr_valid (3'd2, 3'd3, 1'b0, ca_h_val);
          nts.dllp_err      = 1'b0;
          nts.data_prot     = data_prot[2*DW_PROT_WD +: 3*DW_PROT_WD];
          chk_nts.status    = ONGOING;
        end

      pts.status==ONGOING && pts.nw==2'd3 && tlp_eot[0] && tlp_sot[1] && tlp_idl[2] && tlp_idl[3] && tlp_idl[4] :
        begin
          dec_case          = i_i_i_s_e__3;
          qdws[0].valid     = 1'b1;
          qdws[0].data      = {data[0*32 +: 1*32],pts.data[0+: 3*32]};
          qdws[0].dwen      = 4'b1111;
          qdws[0].sot       = pts.sot;
          qdws[0].eot       = 1'b1;
          qdw0_hdr_info     = get_hdr_info (3'd0, 3'd1, 1'b1, ca_h_info);
          qdws[0].has_pfx   = pts.has_pfx;
          qdws[0].hdr_valid = get_hdr_valid (3'd0, 3'd1, 1'b1, ca_h_val);
          qdws[0].dllp_err  = tlp_dllp_err[0];
          qdws[0].data_prot = {data_prot[0*DW_PROT_WD +: 1*DW_PROT_WD],pts.data_prot[0+: 3*DW_PROT_WD]};

          qdws[1].valid     = 1'b0;
          qdws[1].data      = 128'b0;
          qdws[1].dwen      = 4'b0000;
          qdws[1].sot       = 1'b0;
          qdws[1].eot       = 1'b0;
          qdw1_hdr_info     = DEFAULT_HDR_INFO;
          qdws[1].has_pfx   = 1'b0;
          qdws[1].hdr_valid = 1'b0;
          qdws[1].dllp_err  = 1'b0;
          qdws[1].data_prot = DEF_PROT_4DW;

          nts.nw            = 2'd1;
          nts.data          = {64'b0,data[1*32 +: 1*32]};
          nts.sot           = 1'b1;
          nts.eot           = 1'b0;
          nts_hdr_info      = get_hdr_info (3'd1, 3'd1, 1'b0, ca_h_info);
          nts.has_pfx       = tlp_pfx[1];
          nts.hdr_valid     = get_hdr_valid (3'd1, 3'd1, 1'b0, ca_h_val);
          nts.dllp_err      = 1'b0;
          nts.data_prot     = {DEF_PROT_2DW,data_prot[1*DW_PROT_WD +: 1*DW_PROT_WD]};
          chk_nts.status    = ONGOING;
        end

      pts.status==ONGOING && pts.nw==2'd3 && tlp_eot[0] && tlp_sot[1] && !tlp_idl[2] && !tlp_eot[2] && tlp_idl[3] && tlp_idl[4] :
        begin
          dec_case          = i_i_d_s_e__3;
          qdws[0].valid     = 1'b1;
          qdws[0].data      = {data[0*32 +: 1*32],pts.data[0+: 3*32]};
          qdws[0].dwen      = 4'b1111;
          qdws[0].sot       = pts.sot;
          qdws[0].eot       = 1'b1;
          qdw0_hdr_info     = get_hdr_info (3'd0, 3'd1, 1'b1, ca_h_info);
          qdws[0].has_pfx   = pts.has_pfx;
          qdws[0].hdr_valid = get_hdr_valid (3'd0, 3'd1, 1'b1, ca_h_val);
          qdws[0].dllp_err  = tlp_dllp_err[0];
          qdws[0].data_prot = {data_prot[0*DW_PROT_WD +: 1*DW_PROT_WD],pts.data_prot[0+: 3*DW_PROT_WD]};

          qdws[1].valid     = 1'b0;
          qdws[1].data      = 128'b0;
          qdws[1].dwen      = 4'b0000;
          qdws[1].sot       = 1'b0;
          qdws[1].eot       = 1'b0;
          qdw1_hdr_info     = DEFAULT_HDR_INFO;
          qdws[1].has_pfx   = 1'b0;
          qdws[1].hdr_valid = 1'b0;
          qdws[1].dllp_err  = 1'b0;
          qdws[1].data_prot = DEF_PROT_4DW;

          nts.nw            = 2'd2;
          nts.data          = {32'b0,data[1*32 +: 2*32]};
          nts.sot           = 1'b1;
          nts.eot           = 1'b0;
          nts_hdr_info      = get_hdr_info (3'd1, 3'd2, 1'b0, ca_h_info);
          nts.has_pfx       = tlp_pfx[1];
          nts.hdr_valid     = get_hdr_valid (3'd1, 3'd2, 1'b0, ca_h_val);
          nts.dllp_err      = 1'b0;
          nts.data_prot     = {DEF_PROT_1DW,data_prot[1*DW_PROT_WD +: 2*DW_PROT_WD]};
          chk_nts.status    = ONGOING;
        end

      pts.status==ONGOING && pts.nw==2'd3 && tlp_eot[0] && tlp_sot[1] && !tlp_idl[2] && !tlp_eot[2] && tlp_eot[3] && tlp_idl[4] :
        begin
          dec_case          = i_e_d_s_e__3;
          qdws[0].valid     = 1'b1;
          qdws[0].data      = {data[0*32 +: 1*32],pts.data[0+: 3*32]};
          qdws[0].dwen      = 4'b1111;
          qdws[0].sot       = pts.sot;
          qdws[0].eot       = 1'b1;
          qdw0_hdr_info     = get_hdr_info (3'd0, 3'd1, 1'b1, ca_h_info);
          qdws[0].has_pfx   = pts.has_pfx;
          qdws[0].hdr_valid = get_hdr_valid (3'd0, 3'd1, 1'b1, ca_h_val);
          qdws[0].dllp_err  = tlp_dllp_err[0];
          qdws[0].data_prot = {data_prot[0*DW_PROT_WD +: 1*DW_PROT_WD],pts.data_prot[0+: 3*DW_PROT_WD]};

          qdws[1].valid     = 1'b1;
          qdws[1].data      = {32'b0,data[1*32 +: 3*32]};
          qdws[1].dwen      = 4'b0111;
          qdws[1].sot       = 1'b1;
          qdws[1].eot       = 1'b1;
          qdw1_hdr_info     = get_hdr_info (3'd1, 3'd3, 1'b0, ca_h_info);
          qdws[1].has_pfx   = tlp_pfx[1];
          qdws[1].hdr_valid = get_hdr_valid (3'd1, 3'd3, 1'b0, ca_h_val);
          qdws[1].dllp_err  = tlp_dllp_err[3];
          qdws[1].data_prot = {DEF_PROT_1DW,data_prot[1*DW_PROT_WD +: 3*DW_PROT_WD]};

          nts.nw            = 2'd0;
          nts.data          = 96'b0;
          nts.sot           = 1'b0;
          nts.eot           = 1'b0;
          nts_hdr_info      = DEFAULT_HDR_INFO;
          nts.has_pfx       = 1'b0;
          nts.hdr_valid     = 1'b0;
          nts.dllp_err      = 1'b0;
          nts.data_prot     = DEF_PROT_3DW;
          chk_nts.status    = NOTHING;
        end

      pts.status==ONGOING && pts.nw==2'd3 && tlp_eot[0] && tlp_sot[1] && !tlp_idl[2] && !tlp_eot[2] && tlp_eot[3] && tlp_sot[4] :
        begin
          dec_case          = s_e_d_s_e__3;
          qdws[0].valid     = 1'b1;
          qdws[0].data      = {data[0*32 +: 1*32],pts.data[0+: 3*32]};
          qdws[0].dwen      = 4'b1111;
          qdws[0].sot       = pts.sot;
          qdws[0].eot       = 1'b1;
          qdw0_hdr_info     = get_hdr_info (3'd0, 3'd1, 1'b1, ca_h_info);
          qdws[0].has_pfx   = pts.has_pfx;
          qdws[0].hdr_valid = get_hdr_valid (3'd0, 3'd1, 1'b1, ca_h_val);
          qdws[0].dllp_err  = tlp_dllp_err[0];
          qdws[0].data_prot = {data_prot[0*DW_PROT_WD +: 1*DW_PROT_WD],pts.data_prot[0+: 3*DW_PROT_WD]};

          qdws[1].valid     = 1'b1;
          qdws[1].data      = {32'b0,data[1*32 +: 3*32]};
          qdws[1].dwen      = 4'b0111;
          qdws[1].sot       = 1'b1;
          qdws[1].eot       = 1'b1;
          qdw1_hdr_info     = get_hdr_info (3'd1, 3'd3, 1'b0, ca_h_info);
          qdws[1].has_pfx   = tlp_pfx[1];
          qdws[1].hdr_valid = get_hdr_valid (3'd1, 3'd3, 1'b0, ca_h_val);
          qdws[1].dllp_err  = tlp_dllp_err[3];
          qdws[1].data_prot = {DEF_PROT_1DW,data_prot[1*DW_PROT_WD +: 3*DW_PROT_WD]};

          nts.nw            = 2'd1;
          nts.data          = {64'b0,data[4*32 +: 1*32]};
          nts.sot           = 1'b1;
          nts.eot           = 1'b0;
          nts_hdr_info      = get_hdr_info (3'd4, 3'd1, 1'b0, ca_h_info);
          nts.has_pfx       = tlp_pfx[4];
          nts.hdr_valid     = get_hdr_valid (3'd4, 3'd1, 1'b0, ca_h_val);
          nts.dllp_err      = 1'b0;
          nts.data_prot     = {DEF_PROT_2DW,data_prot[4*DW_PROT_WD +: 1*DW_PROT_WD]};
          chk_nts.status    = ONGOING;
        end

      pts.status==ONGOING && pts.nw==2'd3 && tlp_eot[0] && tlp_sot[1] && !tlp_idl[2] && !tlp_eot[2] && !tlp_idl[3] && !tlp_eot[3] && tlp_idl[4] :
        begin
          dec_case          = i_d_d_s_e__3;
          qdws[0].valid     = 1'b1;
          qdws[0].data      = {data[0*32 +: 1*32],pts.data[0+: 3*32]};
          qdws[0].dwen      = 4'b1111;
          qdws[0].sot       = pts.sot;
          qdws[0].eot       = 1'b1;
          qdw0_hdr_info     = get_hdr_info (3'd0, 3'd1, 1'b1, ca_h_info);
          qdws[0].has_pfx   = pts.has_pfx;
          qdws[0].hdr_valid = get_hdr_valid (3'd0, 3'd1, 1'b1, ca_h_val);
          qdws[0].dllp_err  = tlp_dllp_err[0];
          qdws[0].data_prot = {data_prot[0*DW_PROT_WD +: 1*DW_PROT_WD],pts.data_prot[0+: 3*DW_PROT_WD]};

          qdws[1].valid     = 1'b0;
          qdws[1].data      = 128'b0;
          qdws[1].dwen      = 4'b0000;
          qdws[1].sot       = 1'b0;
          qdws[1].eot       = 1'b0;
          qdw1_hdr_info     = DEFAULT_HDR_INFO;
          qdws[1].has_pfx   = 1'b0;
          qdws[1].hdr_valid = 1'b0;
          qdws[1].dllp_err  = 1'b0;
          qdws[1].data_prot = DEF_PROT_4DW;

          nts.nw            = 2'd3;
          nts.data          = data[1*32 +: 3*32];
          nts.sot           = 1'b1;
          nts.eot           = 1'b0;
          nts_hdr_info      = get_hdr_info (3'd1, 3'd3, 1'b0, ca_h_info);
          nts.has_pfx       = tlp_pfx[1];
          nts.hdr_valid     = get_hdr_valid (3'd1, 3'd3, 1'b0, ca_h_val);
          nts.dllp_err      = 1'b0;
          nts.data_prot     = data_prot[1*DW_PROT_WD +: 3*DW_PROT_WD];
          chk_nts.status    = ONGOING;
        end

      pts.status==ONGOING && pts.nw==2'd3 && tlp_eot[0] && tlp_sot[1] && !tlp_idl[2] && !tlp_eot[2] && !tlp_idl[3] && !tlp_eot[3] && tlp_eot[4] :
        begin
          dec_case          = e_d_d_s_e__3;
          qdws[0].valid     = 1'b1;
          qdws[0].data      = {data[0*32 +: 1*32],pts.data[0+: 3*32]};
          qdws[0].dwen      = 4'b1111;
          qdws[0].sot       = pts.sot;
          qdws[0].eot       = 1'b1;
          qdw0_hdr_info     = get_hdr_info (3'd0, 3'd1, 1'b1, ca_h_info);
          qdws[0].has_pfx   = pts.has_pfx;
          qdws[0].hdr_valid = get_hdr_valid (3'd0, 3'd1, 1'b1, ca_h_val);
          qdws[0].dllp_err  = tlp_dllp_err[0];
          qdws[0].data_prot = {data_prot[0*DW_PROT_WD +: 1*DW_PROT_WD],pts.data_prot[0+: 3*DW_PROT_WD]};

          qdws[1].valid     = 1'b1;
          qdws[1].data      = data[1*32 +: 4*32];
          qdws[1].dwen      = 4'b1111;
          qdws[1].sot       = 1'b1;
          qdws[1].eot       = 1'b1;
          qdw1_hdr_info     = get_hdr_info (3'd1, 3'd4, 1'b0, ca_h_info);
          qdws[1].has_pfx   = tlp_pfx[1];
          qdws[1].hdr_valid = get_hdr_valid (3'd1, 3'd4, 1'b0, ca_h_val);
          qdws[1].dllp_err  = tlp_dllp_err[4];
          qdws[1].data_prot = data_prot[1*DW_PROT_WD +: 4*DW_PROT_WD];

          nts.nw            = 2'd0;
          nts.data          = 96'b0;
          nts.sot           = 1'b0;
          nts.eot           = 1'b0;
          nts_hdr_info      = DEFAULT_HDR_INFO;
          nts.has_pfx       = 1'b0;
          nts.hdr_valid     = 1'b0;
          nts.dllp_err      = 1'b0;
          nts.data_prot     = DEF_PROT_3DW;
          chk_nts.status    = NOTHING;
        end

      pts.status==ONGOING && pts.nw==2'd3 && tlp_eot[0] && tlp_sot[1] && !tlp_idl[2] && !tlp_eot[2] && !tlp_idl[3] && !tlp_eot[3] && !tlp_idl[4] && !tlp_eot[4] :
        begin
          dec_case          = d_d_d_s_e__3;
          qdws[0].valid     = 1'b1;
          qdws[0].data      = {data[0*32 +: 1*32],pts.data[0+: 3*32]};
          qdws[0].dwen      = 4'b1111;
          qdws[0].sot       = pts.sot;
          qdws[0].eot       = 1'b1;
          qdw0_hdr_info     = get_hdr_info (3'd0, 3'd1, 1'b1, ca_h_info);
          qdws[0].has_pfx   = pts.has_pfx;
          qdws[0].hdr_valid = get_hdr_valid (3'd0, 3'd1, 1'b1, ca_h_val);
          qdws[0].dllp_err  = tlp_dllp_err[0];
          qdws[0].data_prot = {data_prot[0*DW_PROT_WD +: 1*DW_PROT_WD],pts.data_prot[0+: 3*DW_PROT_WD]};

          qdws[1].valid     = 1'b1;
          qdws[1].data      = data[1*32 +: 4*32];
          qdws[1].dwen      = 4'b1111;
          qdws[1].sot       = 1'b1;
          qdws[1].eot       = 1'b0;
          qdw1_hdr_info     = get_hdr_info (3'd1, 3'd4, 1'b0, ca_h_info);
          qdws[1].has_pfx   = tlp_pfx[1];
          qdws[1].hdr_valid = get_hdr_valid (3'd1, 3'd4, 1'b0, ca_h_val);
          qdws[1].dllp_err  = 1'b0;
          qdws[1].data_prot = data_prot[1*DW_PROT_WD +: 4*DW_PROT_WD];

          nts.nw            = 2'd0;
          nts.data          = 96'b0;
          nts.sot           = 1'b0;
          nts.eot           = 1'b0;
          nts_hdr_info      = get_hdr_info (3'd1, 3'd4, 1'b0, ca_h_info);
          nts.has_pfx       = tlp_pfx[1];
          nts.hdr_valid     = 1'b0;
          nts.dllp_err      = 1'b0;
          nts.data_prot     = DEF_PROT_3DW;
          chk_nts.status    = ONGOING;
        end

      pts.status==ONGOING && pts.nw==2'd3 && !tlp_idl[0] && !tlp_eot[0] && tlp_idl[1] && tlp_idl[2] && tlp_idl[3] && tlp_idl[4] :
        begin
          dec_case          = i_i_i_i_d__3;
          qdws[0].valid     = 1'b1;
          qdws[0].data      = {data[0*32 +: 1*32],pts.data[0+: 3*32]};
          qdws[0].dwen      = 4'b1111;
          qdws[0].sot       = pts.sot;
          qdws[0].eot       = 1'b0;
          qdw0_hdr_info     = get_hdr_info (3'd0, 3'd1, 1'b1, ca_h_info);
          qdws[0].has_pfx   = pts.has_pfx;
          qdws[0].hdr_valid = get_hdr_valid (3'd0, 3'd1, 1'b1, ca_h_val);
          qdws[0].dllp_err  = 1'b0;
          qdws[0].data_prot = {data_prot[0*DW_PROT_WD +: 1*DW_PROT_WD],pts.data_prot[0+: 3*DW_PROT_WD]};

          qdws[1].valid     = 1'b0;
          qdws[1].data      = 128'b0;
          qdws[1].dwen      = 4'b0000;
          qdws[1].sot       = 1'b0;
          qdws[1].eot       = 1'b0;
          qdw1_hdr_info     = DEFAULT_HDR_INFO;
          qdws[1].has_pfx   = 1'b0;
          qdws[1].hdr_valid = 1'b0;
          qdws[1].dllp_err  = 1'b0;
          qdws[1].data_prot = DEF_PROT_4DW;

          nts.nw            = 2'd0;
          nts.data          = 96'b0;
          nts.sot           = 1'b0;
          nts.eot           = 1'b0;
          nts_hdr_info      = get_hdr_info (3'd0, 3'd1, 1'b1, ca_h_info);
          nts.has_pfx       = pts.has_pfx;
          nts.hdr_valid     = 1'b0;
          nts.dllp_err      = 1'b0;
          nts.data_prot     = DEF_PROT_3DW;
          chk_nts.status    = ONGOING;
        end

      pts.status==ONGOING && pts.nw==2'd3 && !tlp_idl[0] && !tlp_eot[0] && tlp_eot[1] && tlp_idl[2] && tlp_idl[3] && tlp_idl[4] :
        begin
          dec_case          = i_i_i_e_d__3;
          qdws[0].valid     = 1'b1;
          qdws[0].data      = {data[0*32 +: 1*32],pts.data[0+: 3*32]};
          qdws[0].dwen      = 4'b1111;
          qdws[0].sot       = pts.sot;
          qdws[0].eot       = 1'b0;
          qdw0_hdr_info     = get_hdr_info (3'd0, 3'd1, 1'b1, ca_h_info);
          qdws[0].has_pfx   = pts.has_pfx;
          qdws[0].hdr_valid = get_hdr_valid (3'd0, 3'd1, 1'b1, ca_h_val);
          qdws[0].dllp_err  = 1'b0;
          qdws[0].data_prot = {data_prot[0*DW_PROT_WD +: 1*DW_PROT_WD],pts.data_prot[0+: 3*DW_PROT_WD]};

          qdws[1].valid     = 1'b1;
          qdws[1].data      = {96'b0,data[1*32 +: 1*32]};
          qdws[1].dwen      = 4'b0001;
          qdws[1].sot       = 1'b0;
          qdws[1].eot       = 1'b1;
          qdw1_hdr_info     = get_hdr_info (3'd0, 3'd2, 1'b1, ca_h_info);
          qdws[1].has_pfx   = pts.has_pfx;
          qdws[1].hdr_valid = get_hdr_valid (3'd1, 3'd1, 1'b0, ca_h_val);
          qdws[1].dllp_err  = tlp_dllp_err[1];
          qdws[1].data_prot = {DEF_PROT_3DW,data_prot[1*DW_PROT_WD +: 1*DW_PROT_WD]};

          nts.nw            = 2'd0;
          nts.data          = 96'b0;
          nts.sot           = 1'b0;
          nts.eot           = 1'b0;
          nts_hdr_info      = get_hdr_info (3'd0, 3'd1, 1'b1, ca_h_info);
          nts.has_pfx       = pts.has_pfx;
          nts.hdr_valid     = 1'b0;
          nts.dllp_err      = 1'b0;
          nts.data_prot     = DEF_PROT_3DW;
          chk_nts.status    = NOTHING;
        end

      pts.status==ONGOING && pts.nw==2'd3 && !tlp_idl[0] && !tlp_eot[0] && tlp_eot[1] && tlp_idl[2] && tlp_idl[3] && tlp_sot[4] :
        begin
          dec_case          = s_i_i_e_d__3;
          qdws[0].valid     = 1'b1;
          qdws[0].data      = {data[0*32 +: 1*32],pts.data[0+: 3*32]};
          qdws[0].dwen      = 4'b1111;
          qdws[0].sot       = pts.sot;
          qdws[0].eot       = 1'b0;
          qdw0_hdr_info     = get_hdr_info (3'd0, 3'd1, 1'b1, ca_h_info);
          qdws[0].has_pfx   = pts.has_pfx;
          qdws[0].hdr_valid = get_hdr_valid (3'd0, 3'd1, 1'b1, ca_h_val);
          qdws[0].dllp_err  = 1'b0;
          qdws[0].data_prot = {data_prot[0*DW_PROT_WD +: 1*DW_PROT_WD],pts.data_prot[0+: 3*DW_PROT_WD]};

          qdws[1].valid     = 1'b1;
          qdws[1].data      = {96'b0,data[1*32 +: 1*32]};
          qdws[1].dwen      = 4'b0001;
          qdws[1].sot       = 1'b0;
          qdws[1].eot       = 1'b1;
          qdw1_hdr_info     = get_hdr_info (3'd0, 3'd2, 1'b1, ca_h_info);
          qdws[1].has_pfx   = pts.has_pfx;
          qdws[1].hdr_valid = get_hdr_valid (3'd1, 3'd1, 1'b0, ca_h_val);
          qdws[1].dllp_err  = tlp_dllp_err[1];
          qdws[1].data_prot = {DEF_PROT_3DW,data_prot[1*DW_PROT_WD +: 1*DW_PROT_WD]};

          nts.nw            = 2'd1;
          nts.data          = {64'b0,data[4*32 +: 1*32]};
          nts.sot           = 1'b1;
          nts.eot           = 1'b0;
          nts_hdr_info      = get_hdr_info (3'd4, 3'd1, 1'b0, ca_h_info);
          nts.has_pfx       = tlp_pfx[4];
          nts.hdr_valid     = get_hdr_valid (3'd4, 3'd1, 1'b0, ca_h_val);
          nts.dllp_err      = 1'b0;
          nts.data_prot     = {DEF_PROT_2DW,data_prot[4*DW_PROT_WD +: 1*DW_PROT_WD]};
          chk_nts.status    = ONGOING;
        end

      pts.status==ONGOING && pts.nw==2'd3 && !tlp_idl[0] && !tlp_eot[0] && tlp_eot[1] && tlp_idl[2] && tlp_sot[3] && tlp_idl[4] :
        begin
          dec_case          = i_s_i_e_d__3;
          qdws[0].valid     = 1'b1;
          qdws[0].data      = {data[0*32 +: 1*32],pts.data[0+: 3*32]};
          qdws[0].dwen      = 4'b1111;
          qdws[0].sot       = pts.sot;
          qdws[0].eot       = 1'b0;
          qdw0_hdr_info     = get_hdr_info (3'd0, 3'd1, 1'b1, ca_h_info);
          qdws[0].has_pfx   = pts.has_pfx;
          qdws[0].hdr_valid = get_hdr_valid (3'd0, 3'd1, 1'b1, ca_h_val);
          qdws[0].dllp_err  = 1'b0;
          qdws[0].data_prot = {data_prot[0*DW_PROT_WD +: 1*DW_PROT_WD],pts.data_prot[0+: 3*DW_PROT_WD]};

          qdws[1].valid     = 1'b1;
          qdws[1].data      = {96'b0,data[1*32 +: 1*32]};
          qdws[1].dwen      = 4'b0001;
          qdws[1].sot       = 1'b0;
          qdws[1].eot       = 1'b1;
          qdw1_hdr_info     = get_hdr_info (3'd0, 3'd2, 1'b1, ca_h_info);
          qdws[1].has_pfx   = pts.has_pfx;
          qdws[1].hdr_valid = get_hdr_valid (3'd1, 3'd1, 1'b0, ca_h_val);
          qdws[1].dllp_err  = tlp_dllp_err[1];
          qdws[1].data_prot = {DEF_PROT_3DW,data_prot[1*DW_PROT_WD +: 1*DW_PROT_WD]};

          nts.nw            = 2'd1;
          nts.data          = {64'b0,data[3*32 +: 1*32]};
          nts.sot           = 1'b1;
          nts.eot           = 1'b0;
          nts_hdr_info      = get_hdr_info (3'd3, 3'd1, 1'b0, ca_h_info);
          nts.has_pfx       = tlp_pfx[3];
          nts.hdr_valid     = get_hdr_valid (3'd3, 3'd1, 1'b0, ca_h_val);
          nts.dllp_err      = 1'b0;
          nts.data_prot     = {DEF_PROT_2DW,data_prot[3*DW_PROT_WD +: 1*DW_PROT_WD]};
          chk_nts.status    = ONGOING;
        end

      pts.status==ONGOING && pts.nw==2'd3 && !tlp_idl[0] && !tlp_eot[0] && tlp_eot[1] && tlp_idl[2] && tlp_sot[3] && !tlp_idl[4] && !tlp_eot[4] :
        begin
          dec_case          = d_s_i_e_d__3;
          qdws[0].valid     = 1'b1;
          qdws[0].data      = {data[0*32 +: 1*32],pts.data[0+: 3*32]};
          qdws[0].dwen      = 4'b1111;
          qdws[0].sot       = pts.sot;
          qdws[0].eot       = 1'b0;
          qdw0_hdr_info     = get_hdr_info (3'd0, 3'd1, 1'b1, ca_h_info);
          qdws[0].has_pfx   = pts.has_pfx;
          qdws[0].hdr_valid = get_hdr_valid (3'd0, 3'd1, 1'b1, ca_h_val);
          qdws[0].dllp_err  = 1'b0;
          qdws[0].data_prot = {data_prot[0*DW_PROT_WD +: 1*DW_PROT_WD],pts.data_prot[0+: 3*DW_PROT_WD]};

          qdws[1].valid     = 1'b1;
          qdws[1].data      = {96'b0,data[1*32 +: 1*32]};
          qdws[1].dwen      = 4'b0001;
          qdws[1].sot       = 1'b0;
          qdws[1].eot       = 1'b1;
          qdw1_hdr_info     = get_hdr_info (3'd0, 3'd2, 1'b1, ca_h_info);
          qdws[1].has_pfx   = pts.has_pfx;
          qdws[1].hdr_valid = get_hdr_valid (3'd1, 3'd1, 1'b0, ca_h_val);
          qdws[1].dllp_err  = tlp_dllp_err[1];
          qdws[1].data_prot = {DEF_PROT_3DW,data_prot[1*DW_PROT_WD +: 1*DW_PROT_WD]};

          nts.nw            = 2'd2;
          nts.data          = {32'b0,data[3*32 +: 2*32]};
          nts.sot           = 1'b1;
          nts.eot           = 1'b0;
          nts_hdr_info      = get_hdr_info (3'd3, 3'd2, 1'b0, ca_h_info);
          nts.has_pfx       = tlp_pfx[3];
          nts.hdr_valid     = get_hdr_valid (3'd3, 3'd2, 1'b0, ca_h_val);
          nts.dllp_err      = 1'b0;
          nts.data_prot     = {DEF_PROT_1DW,data_prot[3*DW_PROT_WD +: 2*DW_PROT_WD]};
          chk_nts.status    = ONGOING;
        end

      pts.status==ONGOING && pts.nw==2'd3 && !tlp_idl[0] && !tlp_eot[0] && tlp_eot[1] && tlp_sot[2] && tlp_idl[3] && tlp_idl[4] :
        begin
          dec_case          = i_i_s_e_d__3;
          qdws[0].valid     = 1'b1;
          qdws[0].data      = {data[0*32 +: 1*32],pts.data[0+: 3*32]};
          qdws[0].dwen      = 4'b1111;
          qdws[0].sot       = pts.sot;
          qdws[0].eot       = 1'b0;
          qdw0_hdr_info     = get_hdr_info (3'd0, 3'd1, 1'b1, ca_h_info);
          qdws[0].has_pfx   = pts.has_pfx;
          qdws[0].hdr_valid = get_hdr_valid (3'd0, 3'd1, 1'b1, ca_h_val);
          qdws[0].dllp_err  = 1'b0;
          qdws[0].data_prot = {data_prot[0*DW_PROT_WD +: 1*DW_PROT_WD],pts.data_prot[0+: 3*DW_PROT_WD]};

          qdws[1].valid     = 1'b1;
          qdws[1].data      = {96'b0,data[1*32 +: 1*32]};
          qdws[1].dwen      = 4'b0001;
          qdws[1].sot       = 1'b0;
          qdws[1].eot       = 1'b1;
          qdw1_hdr_info     = get_hdr_info (3'd0, 3'd2, 1'b1, ca_h_info);
          qdws[1].has_pfx   = pts.has_pfx;
          qdws[1].hdr_valid = get_hdr_valid (3'd1, 3'd1, 1'b0, ca_h_val);
          qdws[1].dllp_err  = tlp_dllp_err[1];
          qdws[1].data_prot = {DEF_PROT_3DW,data_prot[1*DW_PROT_WD +: 1*DW_PROT_WD]};

          nts.nw            = 2'd1;
          nts.data          = {64'b0,data[2*32 +: 1*32]};
          nts.sot           = 1'b1;
          nts.eot           = 1'b0;
          nts_hdr_info      = get_hdr_info (3'd2, 3'd1, 1'b0, ca_h_info);
          nts.has_pfx       = tlp_pfx[2];
          nts.hdr_valid     = get_hdr_valid (3'd2, 3'd1, 1'b0, ca_h_val);
          nts.dllp_err      = 1'b0;
          nts.data_prot     = {DEF_PROT_2DW,data_prot[2*DW_PROT_WD +: 1*DW_PROT_WD]};
          chk_nts.status    = ONGOING;
        end

      pts.status==ONGOING && pts.nw==2'd3 && !tlp_idl[0] && !tlp_eot[0] && tlp_eot[1] && tlp_sot[2] && !tlp_idl[3] && !tlp_eot[3] && tlp_idl[4] :
        begin
          dec_case          = i_d_s_e_d__3;
          qdws[0].valid     = 1'b1;
          qdws[0].data      = {data[0*32 +: 1*32],pts.data[0+: 3*32]};
          qdws[0].dwen      = 4'b1111;
          qdws[0].sot       = pts.sot;
          qdws[0].eot       = 1'b0;
          qdw0_hdr_info     = get_hdr_info (3'd0, 3'd1, 1'b1, ca_h_info);
          qdws[0].has_pfx   = pts.has_pfx;
          qdws[0].hdr_valid = get_hdr_valid (3'd0, 3'd1, 1'b1, ca_h_val);
          qdws[0].dllp_err  = 1'b0;
          qdws[0].data_prot = {data_prot[0*DW_PROT_WD +: 1*DW_PROT_WD],pts.data_prot[0+: 3*DW_PROT_WD]};

          qdws[1].valid     = 1'b1;
          qdws[1].data      = {96'b0,data[1*32 +: 1*32]};
          qdws[1].dwen      = 4'b0001;
          qdws[1].sot       = 1'b0;
          qdws[1].eot       = 1'b1;
          qdw1_hdr_info     = get_hdr_info (3'd0, 3'd2, 1'b1, ca_h_info);
          qdws[1].has_pfx   = pts.has_pfx;
          qdws[1].hdr_valid = get_hdr_valid (3'd1, 3'd1, 1'b0, ca_h_val);
          qdws[1].dllp_err  = tlp_dllp_err[1];
          qdws[1].data_prot = {DEF_PROT_3DW,data_prot[1*DW_PROT_WD +: 1*DW_PROT_WD]};

          nts.nw            = 2'd2;
          nts.data          = {32'b0,data[2*32 +: 2*32]};
          nts.sot           = 1'b1;
          nts.eot           = 1'b0;
          nts_hdr_info      = get_hdr_info (3'd2, 3'd2, 1'b0, ca_h_info);
          nts.has_pfx       = tlp_pfx[2];
          nts.hdr_valid     = get_hdr_valid (3'd2, 3'd2, 1'b0, ca_h_val);
          nts.dllp_err      = 1'b0;
          nts.data_prot     = {DEF_PROT_1DW,data_prot[2*DW_PROT_WD +: 2*DW_PROT_WD]};
          chk_nts.status    = ONGOING;
        end

      pts.status==ONGOING && pts.nw==2'd3 && !tlp_idl[0] && !tlp_eot[0] && tlp_eot[1] && tlp_sot[2] && !tlp_idl[3] && !tlp_eot[3] && tlp_eot[4] :
        begin
          dec_case          = e_d_s_e_d__3;
          qdws[0].valid     = 1'b1;
          qdws[0].data      = {data[0*32 +: 1*32],pts.data[0+: 3*32]};
          qdws[0].dwen      = 4'b1111;
          qdws[0].sot       = pts.sot;
          qdws[0].eot       = 1'b0;
          qdw0_hdr_info     = get_hdr_info (3'd0, 3'd1, 1'b1, ca_h_info);
          qdws[0].has_pfx   = pts.has_pfx;
          qdws[0].hdr_valid = get_hdr_valid (3'd0, 3'd1, 1'b1, ca_h_val);
          qdws[0].dllp_err  = 1'b0;
          qdws[0].data_prot = {data_prot[0*DW_PROT_WD +: 1*DW_PROT_WD],pts.data_prot[0+: 3*DW_PROT_WD]};

          qdws[1].valid     = 1'b1;
          qdws[1].data      = {96'b0,data[1*32 +: 1*32]};
          qdws[1].dwen      = 4'b0001;
          qdws[1].sot       = 1'b0;
          qdws[1].eot       = 1'b1;
          qdw1_hdr_info     = get_hdr_info (3'd0, 3'd2, 1'b1, ca_h_info);
          qdws[1].has_pfx   = pts.has_pfx;
          qdws[1].hdr_valid = get_hdr_valid (3'd1, 3'd1, 1'b0, ca_h_val);
          qdws[1].dllp_err  = tlp_dllp_err[1];
          qdws[1].data_prot = {DEF_PROT_3DW,data_prot[1*DW_PROT_WD +: 1*DW_PROT_WD]};

          nts.nw            = 2'd3;
          nts.data          = data[2*32 +: 3*32];
          nts.sot           = 1'b1;
          nts.eot           = 1'b1;
          nts_hdr_info      = get_hdr_info (3'd2, 3'd3, 1'b0, ca_h_info);
          nts.has_pfx       = tlp_pfx[2];
          nts.hdr_valid     = get_hdr_valid (3'd2, 3'd3, 1'b0, ca_h_val);
          nts.dllp_err      = tlp_dllp_err[4];
          nts.data_prot     = data_prot[2*DW_PROT_WD +: 3*DW_PROT_WD];
          chk_nts.status    = NOTHING;
        end

      pts.status==ONGOING && pts.nw==2'd3 && !tlp_idl[0] && !tlp_eot[0] && tlp_eot[1] && tlp_sot[2] && !tlp_idl[3] && !tlp_eot[3] && !tlp_idl[4] && !tlp_eot[4] :
        begin
          dec_case          = d_d_s_e_d__3;
          qdws[0].valid     = 1'b1;
          qdws[0].data      = {data[0*32 +: 1*32],pts.data[0+: 3*32]};
          qdws[0].dwen      = 4'b1111;
          qdws[0].sot       = pts.sot;
          qdws[0].eot       = 1'b0;
          qdw0_hdr_info     = get_hdr_info (3'd0, 3'd1, 1'b1, ca_h_info);
          qdws[0].has_pfx   = pts.has_pfx;
          qdws[0].hdr_valid = get_hdr_valid (3'd0, 3'd1, 1'b1, ca_h_val);
          qdws[0].dllp_err  = 1'b0;
          qdws[0].data_prot = {data_prot[0*DW_PROT_WD +: 1*DW_PROT_WD],pts.data_prot[0+: 3*DW_PROT_WD]};

          qdws[1].valid     = 1'b1;
          qdws[1].data      = {96'b0,data[1*32 +: 1*32]};
          qdws[1].dwen      = 4'b0001;
          qdws[1].sot       = 1'b0;
          qdws[1].eot       = 1'b1;
          qdw1_hdr_info     = get_hdr_info (3'd0, 3'd2, 1'b1, ca_h_info);
          qdws[1].has_pfx   = pts.has_pfx;
          qdws[1].hdr_valid = get_hdr_valid (3'd1, 3'd1, 1'b0, ca_h_val);
          qdws[1].dllp_err  = tlp_dllp_err[1];
          qdws[1].data_prot = {DEF_PROT_3DW,data_prot[1*DW_PROT_WD +: 1*DW_PROT_WD]};

          nts.nw            = 2'd3;
          nts.data          = data[2*32 +: 3*32];
          nts.sot           = 1'b1;
          nts.eot           = 1'b0;
          nts_hdr_info      = get_hdr_info (3'd2, 3'd3, 1'b0, ca_h_info);
          nts.has_pfx       = tlp_pfx[2];
          nts.hdr_valid     = get_hdr_valid (3'd2, 3'd3, 1'b0, ca_h_val);
          nts.dllp_err      = 1'b0;
          nts.data_prot     = data_prot[2*DW_PROT_WD +: 3*DW_PROT_WD];
          chk_nts.status    = ONGOING;
        end

      pts.status==ONGOING && pts.nw==2'd3 && !tlp_idl[0] && !tlp_eot[0] && !tlp_idl[1] && !tlp_eot[1] && tlp_idl[2] && tlp_idl[3] && tlp_idl[4] :
        begin
          dec_case          = i_i_i_d_d__3;
          qdws[0].valid     = 1'b1;
          qdws[0].data      = {data[0*32 +: 1*32],pts.data[0+: 3*32]};
          qdws[0].dwen      = 4'b1111;
          qdws[0].sot       = pts.sot;
          qdws[0].eot       = 1'b0;
          qdw0_hdr_info     = get_hdr_info (3'd0, 3'd1, 1'b1, ca_h_info);
          qdws[0].has_pfx   = pts.has_pfx;
          qdws[0].hdr_valid = get_hdr_valid (3'd0, 3'd1, 1'b1, ca_h_val);
          qdws[0].dllp_err  = 1'b0;
          qdws[0].data_prot = {data_prot[0*DW_PROT_WD +: 1*DW_PROT_WD],pts.data_prot[0+: 3*DW_PROT_WD]};

          qdws[1].valid     = 1'b0;
          qdws[1].data      = 128'b0;
          qdws[1].dwen      = 4'b0000;
          qdws[1].sot       = 1'b0;
          qdws[1].eot       = 1'b0;
          qdw1_hdr_info     = DEFAULT_HDR_INFO;
          qdws[1].has_pfx   = 1'b0;
          qdws[1].hdr_valid = 1'b0;
          qdws[1].dllp_err  = 1'b0;
          qdws[1].data_prot = DEF_PROT_4DW;

          nts.nw            = 2'd1;
          nts.data          = {64'b0,data[1*32 +: 1*32]};
          nts.sot           = 1'b0;
          nts.eot           = 1'b0;
          nts_hdr_info      = get_hdr_info (3'd0, 3'd2, 1'b1, ca_h_info);
          nts.has_pfx       = pts.has_pfx;
          nts.hdr_valid     = get_hdr_valid (3'd1, 3'd1, 1'b0, ca_h_val);
          nts.dllp_err      = 1'b0;
          nts.data_prot     = {DEF_PROT_2DW,data_prot[1*DW_PROT_WD +: 1*DW_PROT_WD]};
          chk_nts.status    = ONGOING;
        end

      pts.status==ONGOING && pts.nw==2'd3 && !tlp_idl[0] && !tlp_eot[0] && !tlp_idl[1] && !tlp_eot[1] && tlp_eot[2] && tlp_idl[3] && tlp_idl[4] :
        begin
          dec_case          = i_i_e_d_d__3;
          qdws[0].valid     = 1'b1;
          qdws[0].data      = {data[0*32 +: 1*32],pts.data[0+: 3*32]};
          qdws[0].dwen      = 4'b1111;
          qdws[0].sot       = pts.sot;
          qdws[0].eot       = 1'b0;
          qdw0_hdr_info     = get_hdr_info (3'd0, 3'd1, 1'b1, ca_h_info);
          qdws[0].has_pfx   = pts.has_pfx;
          qdws[0].hdr_valid = get_hdr_valid (3'd0, 3'd1, 1'b1, ca_h_val);
          qdws[0].dllp_err  = 1'b0;
          qdws[0].data_prot = {data_prot[0*DW_PROT_WD +: 1*DW_PROT_WD],pts.data_prot[0+: 3*DW_PROT_WD]};

          qdws[1].valid     = 1'b1;
          qdws[1].data      = {64'b0,data[1*32 +: 2*32]};
          qdws[1].dwen      = 4'b0011;
          qdws[1].sot       = 1'b0;
          qdws[1].eot       = 1'b1;
          qdw1_hdr_info     = get_hdr_info (3'd0, 3'd3, 1'b1, ca_h_info);
          qdws[1].has_pfx   = pts.has_pfx;
          qdws[1].hdr_valid = get_hdr_valid (3'd1, 3'd2, 1'b0, ca_h_val);
          qdws[1].dllp_err  = tlp_dllp_err[2];
          qdws[1].data_prot = {DEF_PROT_2DW,data_prot[1*DW_PROT_WD +: 2*DW_PROT_WD]};

          nts.nw            = 2'd0;
          nts.data          = 96'b0;
          nts.sot           = 1'b0;
          nts.eot           = 1'b0;
          nts_hdr_info      = get_hdr_info (3'd0, 3'd1, 1'b1, ca_h_info);
          nts.has_pfx       = pts.has_pfx;
          nts.hdr_valid     = 1'b0;
          nts.dllp_err      = 1'b0;
          nts.data_prot     = DEF_PROT_3DW;
          chk_nts.status    = NOTHING;
        end

      pts.status==ONGOING && pts.nw==2'd3 && !tlp_idl[0] && !tlp_eot[0] && !tlp_idl[1] && !tlp_eot[1] && tlp_eot[2] && tlp_idl[3] && tlp_sot[4] :
        begin
          dec_case          = s_i_e_d_d__3;
          qdws[0].valid     = 1'b1;
          qdws[0].data      = {data[0*32 +: 1*32],pts.data[0+: 3*32]};
          qdws[0].dwen      = 4'b1111;
          qdws[0].sot       = pts.sot;
          qdws[0].eot       = 1'b0;
          qdw0_hdr_info     = get_hdr_info (3'd0, 3'd1, 1'b1, ca_h_info);
          qdws[0].has_pfx   = pts.has_pfx;
          qdws[0].hdr_valid = get_hdr_valid (3'd0, 3'd1, 1'b1, ca_h_val);
          qdws[0].dllp_err  = 1'b0;
          qdws[0].data_prot = {data_prot[0*DW_PROT_WD +: 1*DW_PROT_WD],pts.data_prot[0+: 3*DW_PROT_WD]};

          qdws[1].valid     = 1'b1;
          qdws[1].data      = {64'b0,data[1*32 +: 2*32]};
          qdws[1].dwen      = 4'b0011;
          qdws[1].sot       = 1'b0;
          qdws[1].eot       = 1'b1;
          qdw1_hdr_info     = get_hdr_info (3'd0, 3'd3, 1'b1, ca_h_info);
          qdws[1].has_pfx   = pts.has_pfx;
          qdws[1].hdr_valid = get_hdr_valid (3'd1, 3'd2, 1'b0, ca_h_val);
          qdws[1].dllp_err  = tlp_dllp_err[2];
          qdws[1].data_prot = {DEF_PROT_2DW,data_prot[1*DW_PROT_WD +: 2*DW_PROT_WD]};

          nts.nw            = 2'd1;
          nts.data          = {64'b0,data[4*32 +: 1*32]};
          nts.sot           = 1'b1;
          nts.eot           = 1'b0;
          nts_hdr_info      = get_hdr_info (3'd4, 3'd1, 1'b0, ca_h_info);
          nts.has_pfx       = tlp_pfx[4];
          nts.hdr_valid     = get_hdr_valid (3'd4, 3'd1, 1'b0, ca_h_val);
          nts.dllp_err      = 1'b0;
          nts.data_prot     = {DEF_PROT_2DW,data_prot[4*DW_PROT_WD +: 1*DW_PROT_WD]};
          chk_nts.status    = ONGOING;
        end

      pts.status==ONGOING && pts.nw==2'd3 && !tlp_idl[0] && !tlp_eot[0] && !tlp_idl[1] && !tlp_eot[1] && tlp_eot[2] && tlp_sot[3] && tlp_idl[4] :
        begin
          dec_case          = i_s_e_d_d__3;
          qdws[0].valid     = 1'b1;
          qdws[0].data      = {data[0*32 +: 1*32],pts.data[0+: 3*32]};
          qdws[0].dwen      = 4'b1111;
          qdws[0].sot       = pts.sot;
          qdws[0].eot       = 1'b0;
          qdw0_hdr_info     = get_hdr_info (3'd0, 3'd1, 1'b1, ca_h_info);
          qdws[0].has_pfx   = pts.has_pfx;
          qdws[0].hdr_valid = get_hdr_valid (3'd0, 3'd1, 1'b1, ca_h_val);
          qdws[0].dllp_err  = 1'b0;
          qdws[0].data_prot = {data_prot[0*DW_PROT_WD +: 1*DW_PROT_WD],pts.data_prot[0+: 3*DW_PROT_WD]};

          qdws[1].valid     = 1'b1;
          qdws[1].data      = {64'b0,data[1*32 +: 2*32]};
          qdws[1].dwen      = 4'b0011;
          qdws[1].sot       = 1'b0;
          qdws[1].eot       = 1'b1;
          qdw1_hdr_info     = get_hdr_info (3'd0, 3'd3, 1'b1, ca_h_info);
          qdws[1].has_pfx   = pts.has_pfx;
          qdws[1].hdr_valid = get_hdr_valid (3'd1, 3'd2, 1'b0, ca_h_val);
          qdws[1].dllp_err  = tlp_dllp_err[2];
          qdws[1].data_prot = {DEF_PROT_2DW,data_prot[1*DW_PROT_WD +: 2*DW_PROT_WD]};

          nts.nw            = 2'd1;
          nts.data          = {64'b0,data[3*32 +: 1*32]};
          nts.sot           = 1'b1;
          nts.eot           = 1'b0;
          nts_hdr_info      = get_hdr_info (3'd3, 3'd1, 1'b0, ca_h_info);
          nts.has_pfx       = tlp_pfx[3];
          nts.hdr_valid     = get_hdr_valid (3'd3, 3'd1, 1'b0, ca_h_val);
          nts.dllp_err      = 1'b0;
          nts.data_prot     = {DEF_PROT_2DW,data_prot[3*DW_PROT_WD +: 1*DW_PROT_WD]};
          chk_nts.status    = ONGOING;
        end

      pts.status==ONGOING && pts.nw==2'd3 && !tlp_idl[0] && !tlp_eot[0] && !tlp_idl[1] && !tlp_eot[1] && tlp_eot[2] && tlp_sot[3] && !tlp_idl[4] && !tlp_eot[4] :
        begin
          dec_case          = d_s_e_d_d__3;
          qdws[0].valid     = 1'b1;
          qdws[0].data      = {data[0*32 +: 1*32],pts.data[0+: 3*32]};
          qdws[0].dwen      = 4'b1111;
          qdws[0].sot       = pts.sot;
          qdws[0].eot       = 1'b0;
          qdw0_hdr_info     = get_hdr_info (3'd0, 3'd1, 1'b1, ca_h_info);
          qdws[0].has_pfx   = pts.has_pfx;
          qdws[0].hdr_valid = get_hdr_valid (3'd0, 3'd1, 1'b1, ca_h_val);
          qdws[0].dllp_err  = 1'b0;
          qdws[0].data_prot = {data_prot[0*DW_PROT_WD +: 1*DW_PROT_WD],pts.data_prot[0+: 3*DW_PROT_WD]};

          qdws[1].valid     = 1'b1;
          qdws[1].data      = {64'b0,data[1*32 +: 2*32]};
          qdws[1].dwen      = 4'b0011;
          qdws[1].sot       = 1'b0;
          qdws[1].eot       = 1'b1;
          qdw1_hdr_info     = get_hdr_info (3'd0, 3'd3, 1'b1, ca_h_info);
          qdws[1].has_pfx   = pts.has_pfx;
          qdws[1].hdr_valid = get_hdr_valid (3'd1, 3'd2, 1'b0, ca_h_val);
          qdws[1].dllp_err  = tlp_dllp_err[2];
          qdws[1].data_prot = {DEF_PROT_2DW,data_prot[1*DW_PROT_WD +: 2*DW_PROT_WD]};

          nts.nw            = 2'd2;
          nts.data          = {32'b0,data[3*32 +: 2*32]};
          nts.sot           = 1'b1;
          nts.eot           = 1'b0;
          nts_hdr_info      = get_hdr_info (3'd3, 3'd2, 1'b0, ca_h_info);
          nts.has_pfx       = tlp_pfx[3];
          nts.hdr_valid     = get_hdr_valid (3'd3, 3'd2, 1'b0, ca_h_val);
          nts.dllp_err      = 1'b0;
          nts.data_prot     = {DEF_PROT_1DW,data_prot[3*DW_PROT_WD +: 2*DW_PROT_WD]};
          chk_nts.status    = ONGOING;
        end

      pts.status==ONGOING && pts.nw==2'd3 && !tlp_idl[0] && !tlp_eot[0] && !tlp_idl[1] && !tlp_eot[1] && !tlp_idl[2] && !tlp_eot[2] && tlp_idl[3] && tlp_idl[4] :
        begin
          dec_case          = i_i_d_d_d__3;
          qdws[0].valid     = 1'b1;
          qdws[0].data      = {data[0*32 +: 1*32],pts.data[0+: 3*32]};
          qdws[0].dwen      = 4'b1111;
          qdws[0].sot       = pts.sot;
          qdws[0].eot       = 1'b0;
          qdw0_hdr_info     = get_hdr_info (3'd0, 3'd1, 1'b1, ca_h_info);
          qdws[0].has_pfx   = pts.has_pfx;
          qdws[0].hdr_valid = get_hdr_valid (3'd0, 3'd1, 1'b1, ca_h_val);
          qdws[0].dllp_err  = 1'b0;
          qdws[0].data_prot = {data_prot[0*DW_PROT_WD +: 1*DW_PROT_WD],pts.data_prot[0+: 3*DW_PROT_WD]};

          qdws[1].valid     = 1'b0;
          qdws[1].data      = 128'b0;
          qdws[1].dwen      = 4'b0000;
          qdws[1].sot       = 1'b0;
          qdws[1].eot       = 1'b0;
          qdw1_hdr_info     = DEFAULT_HDR_INFO;
          qdws[1].has_pfx   = 1'b0;
          qdws[1].hdr_valid = 1'b0;
          qdws[1].dllp_err  = 1'b0;
          qdws[1].data_prot = DEF_PROT_4DW;

          nts.nw            = 2'd2;
          nts.data          = {32'b0,data[1*32 +: 2*32]};
          nts.sot           = 1'b0;
          nts.eot           = 1'b0;
          nts_hdr_info      = get_hdr_info (3'd0, 3'd3, 1'b1, ca_h_info);
          nts.has_pfx       = pts.has_pfx;
          nts.hdr_valid     = get_hdr_valid (3'd1, 3'd2, 1'b0, ca_h_val);
          nts.dllp_err      = 1'b0;
          nts.data_prot     = {DEF_PROT_1DW,data_prot[1*DW_PROT_WD +: 2*DW_PROT_WD]};
          chk_nts.status    = ONGOING;
        end

      pts.status==ONGOING && pts.nw==2'd3 && !tlp_idl[0] && !tlp_eot[0] && !tlp_idl[1] && !tlp_eot[1] && !tlp_idl[2] && !tlp_eot[2] && tlp_eot[3] && tlp_idl[4] :
        begin
          dec_case          = i_e_d_d_d__3;
          qdws[0].valid     = 1'b1;
          qdws[0].data      = {data[0*32 +: 1*32],pts.data[0+: 3*32]};
          qdws[0].dwen      = 4'b1111;
          qdws[0].sot       = pts.sot;
          qdws[0].eot       = 1'b0;
          qdw0_hdr_info     = get_hdr_info (3'd0, 3'd1, 1'b1, ca_h_info);
          qdws[0].has_pfx   = pts.has_pfx;
          qdws[0].hdr_valid = get_hdr_valid (3'd0, 3'd1, 1'b1, ca_h_val);
          qdws[0].dllp_err  = 1'b0;
          qdws[0].data_prot = {data_prot[0*DW_PROT_WD +: 1*DW_PROT_WD],pts.data_prot[0+: 3*DW_PROT_WD]};

          qdws[1].valid     = 1'b1;
          qdws[1].data      = {32'b0,data[1*32 +: 3*32]};
          qdws[1].dwen      = 4'b0111;
          qdws[1].sot       = 1'b0;
          qdws[1].eot       = 1'b1;
          qdw1_hdr_info     = get_hdr_info (3'd0, 3'd4, 1'b1, ca_h_info);
          qdws[1].has_pfx   = pts.has_pfx;
          qdws[1].hdr_valid = get_hdr_valid (3'd1, 3'd3, 1'b0, ca_h_val);
          qdws[1].dllp_err  = tlp_dllp_err[3];
          qdws[1].data_prot = {DEF_PROT_1DW,data_prot[1*DW_PROT_WD +: 3*DW_PROT_WD]};

          nts.nw            = 2'd0;
          nts.data          = 96'b0;
          nts.sot           = 1'b0;
          nts.eot           = 1'b0;
          nts_hdr_info      = get_hdr_info (3'd0, 3'd1, 1'b1, ca_h_info);
          nts.has_pfx       = pts.has_pfx;
          nts.hdr_valid     = 1'b0;
          nts.dllp_err      = 1'b0;
          nts.data_prot     = DEF_PROT_3DW;
          chk_nts.status    = NOTHING;
        end

      pts.status==ONGOING && pts.nw==2'd3 && !tlp_idl[0] && !tlp_eot[0] && !tlp_idl[1] && !tlp_eot[1] && !tlp_idl[2] && !tlp_eot[2] && tlp_eot[3] && tlp_sot[4] :
        begin
          dec_case          = s_e_d_d_d__3;
          qdws[0].valid     = 1'b1;
          qdws[0].data      = {data[0*32 +: 1*32],pts.data[0+: 3*32]};
          qdws[0].dwen      = 4'b1111;
          qdws[0].sot       = pts.sot;
          qdws[0].eot       = 1'b0;
          qdw0_hdr_info     = get_hdr_info (3'd0, 3'd1, 1'b1, ca_h_info);
          qdws[0].has_pfx   = pts.has_pfx;
          qdws[0].hdr_valid = get_hdr_valid (3'd0, 3'd1, 1'b1, ca_h_val);
          qdws[0].dllp_err  = 1'b0;
          qdws[0].data_prot = {data_prot[0*DW_PROT_WD +: 1*DW_PROT_WD],pts.data_prot[0+: 3*DW_PROT_WD]};

          qdws[1].valid     = 1'b1;
          qdws[1].data      = {32'b0,data[1*32 +: 3*32]};
          qdws[1].dwen      = 4'b0111;
          qdws[1].sot       = 1'b0;
          qdws[1].eot       = 1'b1;
          qdw1_hdr_info     = get_hdr_info (3'd0, 3'd4, 1'b1, ca_h_info);
          qdws[1].has_pfx   = pts.has_pfx;
          qdws[1].hdr_valid = get_hdr_valid (3'd1, 3'd3, 1'b0, ca_h_val);
          qdws[1].dllp_err  = tlp_dllp_err[3];
          qdws[1].data_prot = {DEF_PROT_1DW,data_prot[1*DW_PROT_WD +: 3*DW_PROT_WD]};

          nts.nw            = 2'd1;
          nts.data          = {64'b0,data[4*32 +: 1*32]};
          nts.sot           = 1'b1;
          nts.eot           = 1'b0;
          nts_hdr_info      = get_hdr_info (3'd4, 3'd1, 1'b0, ca_h_info);
          nts.has_pfx       = tlp_pfx[4];
          nts.hdr_valid     = get_hdr_valid (3'd4, 3'd1, 1'b0, ca_h_val);
          nts.dllp_err      = 1'b0;
          nts.data_prot     = {DEF_PROT_2DW,data_prot[4*DW_PROT_WD +: 1*DW_PROT_WD]};
          chk_nts.status    = ONGOING;
        end

      pts.status==ONGOING && pts.nw==2'd3 && !tlp_idl[0] && !tlp_eot[0] && !tlp_idl[1] && !tlp_eot[1] && !tlp_idl[2] && !tlp_eot[2] && !tlp_idl[3] && !tlp_eot[3] && tlp_idl[4] :
        begin
          dec_case          = i_d_d_d_d__3;
          qdws[0].valid     = 1'b1;
          qdws[0].data      = {data[0*32 +: 1*32],pts.data[0+: 3*32]};
          qdws[0].dwen      = 4'b1111;
          qdws[0].sot       = pts.sot;
          qdws[0].eot       = 1'b0;
          qdw0_hdr_info     = get_hdr_info (3'd0, 3'd1, 1'b1, ca_h_info);
          qdws[0].has_pfx   = pts.has_pfx;
          qdws[0].hdr_valid = get_hdr_valid (3'd0, 3'd1, 1'b1, ca_h_val);
          qdws[0].dllp_err  = 1'b0;
          qdws[0].data_prot = {data_prot[0*DW_PROT_WD +: 1*DW_PROT_WD],pts.data_prot[0+: 3*DW_PROT_WD]};

          qdws[1].valid     = 1'b0;
          qdws[1].data      = 128'b0;
          qdws[1].dwen      = 4'b0000;
          qdws[1].sot       = 1'b0;
          qdws[1].eot       = 1'b0;
          qdw1_hdr_info     = DEFAULT_HDR_INFO;
          qdws[1].has_pfx   = 1'b0;
          qdws[1].hdr_valid = 1'b0;
          qdws[1].dllp_err  = 1'b0;
          qdws[1].data_prot = DEF_PROT_4DW;

          nts.nw            = 2'd3;
          nts.data          = data[1*32 +: 3*32];
          nts.sot           = 1'b0;
          nts.eot           = 1'b0;
          nts_hdr_info      = get_hdr_info (3'd0, 3'd4, 1'b1, ca_h_info);
          nts.has_pfx       = pts.has_pfx;
          nts.hdr_valid     = get_hdr_valid (3'd1, 3'd3, 1'b0, ca_h_val);
          nts.dllp_err      = 1'b0;
          nts.data_prot     = data_prot[1*DW_PROT_WD +: 3*DW_PROT_WD];
          chk_nts.status    = ONGOING;
        end

      pts.status==ONGOING && pts.nw==2'd3 && !tlp_idl[0] && !tlp_eot[0] && !tlp_idl[1] && !tlp_eot[1] && !tlp_idl[2] && !tlp_eot[2] && !tlp_idl[3] && !tlp_eot[3] && tlp_eot[4] :
        begin
          dec_case          = e_d_d_d_d__3;
          qdws[0].valid     = 1'b1;
          qdws[0].data      = {data[0*32 +: 1*32],pts.data[0+: 3*32]};
          qdws[0].dwen      = 4'b1111;
          qdws[0].sot       = pts.sot;
          qdws[0].eot       = 1'b0;
          qdw0_hdr_info     = get_hdr_info (3'd0, 3'd1, 1'b1, ca_h_info);
          qdws[0].has_pfx   = pts.has_pfx;
          qdws[0].hdr_valid = get_hdr_valid (3'd0, 3'd1, 1'b1, ca_h_val);
          qdws[0].dllp_err  = 1'b0;
          qdws[0].data_prot = {data_prot[0*DW_PROT_WD +: 1*DW_PROT_WD],pts.data_prot[0+: 3*DW_PROT_WD]};

          qdws[1].valid     = 1'b1;
          qdws[1].data      = data[1*32 +: 4*32];
          qdws[1].dwen      = 4'b1111;
          qdws[1].sot       = 1'b0;
          qdws[1].eot       = 1'b1;
          qdw1_hdr_info     = get_hdr_info (3'd0, 3'd5, 1'b1, ca_h_info);
          qdws[1].has_pfx   = pts.has_pfx;
          qdws[1].hdr_valid = get_hdr_valid (3'd1, 3'd4, 1'b0, ca_h_val);
          qdws[1].dllp_err  = tlp_dllp_err[4];
          qdws[1].data_prot = data_prot[1*DW_PROT_WD +: 4*DW_PROT_WD];

          nts.nw            = 2'd0;
          nts.data          = 96'b0;
          nts.sot           = 1'b0;
          nts.eot           = 1'b0;
          nts_hdr_info      = get_hdr_info (3'd0, 3'd1, 1'b1, ca_h_info);
          nts.has_pfx       = pts.has_pfx;
          nts.hdr_valid     = 1'b0;
          nts.dllp_err      = 1'b0;
          nts.data_prot     = DEF_PROT_3DW;
          chk_nts.status    = NOTHING;
        end

      pts.status==ONGOING && pts.nw==2'd3 && !tlp_idl[0] && !tlp_eot[0] && !tlp_idl[1] && !tlp_eot[1] && !tlp_idl[2] && !tlp_eot[2] && !tlp_idl[3] && !tlp_eot[3] && !tlp_idl[4] && !tlp_eot[4] :
        begin
          dec_case          = d_d_d_d_d__3;
          qdws[0].valid     = 1'b1;
          qdws[0].data      = {data[0*32 +: 1*32],pts.data[0+: 3*32]};
          qdws[0].dwen      = 4'b1111;
          qdws[0].sot       = pts.sot;
          qdws[0].eot       = 1'b0;
          qdw0_hdr_info     = get_hdr_info (3'd0, 3'd1, 1'b1, ca_h_info);
          qdws[0].has_pfx   = pts.has_pfx;
          qdws[0].hdr_valid = get_hdr_valid (3'd0, 3'd1, 1'b1, ca_h_val);
          qdws[0].dllp_err  = 1'b0;
          qdws[0].data_prot = {data_prot[0*DW_PROT_WD +: 1*DW_PROT_WD],pts.data_prot[0+: 3*DW_PROT_WD]};

          qdws[1].valid     = 1'b1;
          qdws[1].data      = data[1*32 +: 4*32];
          qdws[1].dwen      = 4'b1111;
          qdws[1].sot       = 1'b0;
          qdws[1].eot       = 1'b0;
          qdw1_hdr_info     = get_hdr_info (3'd0, 3'd5, 1'b1, ca_h_info);
          qdws[1].has_pfx   = pts.has_pfx;
          qdws[1].hdr_valid = get_hdr_valid (3'd1, 3'd4, 1'b0, ca_h_val);
          qdws[1].dllp_err  = 1'b0;
          qdws[1].data_prot = data_prot[1*DW_PROT_WD +: 4*DW_PROT_WD];

          nts.nw            = 2'd0;
          nts.data          = 96'b0;
          nts.sot           = 1'b0;
          nts.eot           = 1'b0;
          nts_hdr_info      = get_hdr_info (3'd0, 3'd5, 1'b1, ca_h_info);
          nts.has_pfx       = pts.has_pfx;
          nts.hdr_valid     = 1'b0;
          nts.dllp_err      = 1'b0;
          nts.data_prot     = DEF_PROT_3DW;
          chk_nts.status    = ONGOING;
        end

      default :
        begin
          dec_case          = x_x_x_x_x;
          qdws[0].valid     = 1'b0;
          qdws[0].data      = 128'b0;
          qdws[0].dwen      = 4'b0000;
          qdws[0].sot       = 1'b0;
          qdws[0].eot       = 1'b0;
          qdw0_hdr_info     = DEFAULT_HDR_INFO;
          qdws[0].has_pfx   = 1'b0;
          qdws[0].hdr_valid = 1'b0;
          qdws[0].dllp_err  = 1'b0;
          qdws[0].data_prot = DEF_PROT_4DW;

          qdws[1].valid     = 1'b0;
          qdws[1].data      = 128'b0;
          qdws[1].dwen      = 4'b0000;
          qdws[1].sot       = 1'b0;
          qdws[1].eot       = 1'b0;
          qdw1_hdr_info     = DEFAULT_HDR_INFO;
          qdws[1].has_pfx   = 1'b0;
          qdws[1].hdr_valid = 1'b0;
          qdws[1].dllp_err  = 1'b0;
          qdws[1].data_prot = DEF_PROT_4DW;

          nts.nw            = 2'd0;
          nts.data          = 96'b0;
          nts.sot           = 1'b0;
          nts.eot           = 1'b0;
          nts_hdr_info      = DEFAULT_HDR_INFO;
          nts.has_pfx       = 1'b0;
          nts.hdr_valid     = 1'b0;
          nts.dllp_err      = 1'b0;
          nts.data_prot     = DEF_PROT_3DW;
          chk_nts.status    = NOTHING;
        end
    endcase
end // next_state_PROC
// END MARKER FOR SCRIPT GENERATED CODE. RTLH AUTO

function automatic [3:0] dwen_dec (input logic [1:0] nw);
  dwen_dec = (nw==2'd3) ? 4'b0111 : (nw==2'd2) ? 4'b0011 : (nw==2'd1) ? 4'b0001 : 4'b0000;
endfunction

function automatic  get_hdr_valid (input logic [2:0] start, input logic [2:0] len, input logic prev, input ca_h_val_s ca_h_val);
  get_hdr_valid = (prev)? ca_h_val.pts_h_val : 1'b0;
  for (int i = 0; i <=4; i++) begin
      if (i >= start && i < start+len) begin
          get_hdr_valid = get_hdr_valid | ca_h_val.tlp_soh[i];
      end
  end
endfunction

function automatic hdr_info_s get_hdr_info (input logic [2:0] start, input logic [2:0] len, input logic prev, ca_h_info_s ca_h_info);
  get_hdr_info.fc       = (prev)? ca_h_info.pts.fc : E_FC_NONE;
  get_hdr_info.vc       = (prev)? ca_h_info.pts.vc : 3'b0;
  get_hdr_info.dcrd_amt = (prev)? ca_h_info.pts.dcrd_amt : 9'b0;
  get_hdr_info.dpsize   = (prev)? ca_h_info.pts.dpsize : 11'b0;
  get_hdr_info.evt_type = (prev)? ca_h_info.pts.evt_type : evt_type_e'(0);

  for (int i = 0; i <=4; i++) begin
      if (i >= start && i < start+len) begin
          if (ca_h_info.tlp_soh[i]) begin
              get_hdr_info.fc       = ca_h_info.info[i].fc;
              get_hdr_info.vc       = ca_h_info.info[i].vc;
              get_hdr_info.dcrd_amt = ca_h_info.info[i].dcrd_amt;
              get_hdr_info.dpsize   = ca_h_info.info[i].dpsize;
              get_hdr_info.evt_type = ca_h_info.info[i].evt_type;
          end
      end
  end
endfunction


endmodule : rtlh_qdw_extract_dec
