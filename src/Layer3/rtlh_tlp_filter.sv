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
// ---    $DateTime: 2023/07/14 07:11:41 $
// ---    $Revision: #2 $
// ---    $Id: //dwh/pcie_iip/main/fairbanks/design/Layer3/rtlh_tlp_filter.sv#2 $
// ----------------------------------------------------------------------------
// --- Description: Detect ERR_COR Messages having ERR_NONFATAL/ERR_FATAL codes. 
// ---              According to DPC Trigger Enable field, enters DPC drop mode:
// ---               * the ERR_CORR message is forwarded to the RADM (which eventually 
// ---                 reports the event to the cdm and enters DPC mode) unaltered.
// ---               * drops any further packet by asserting dllp_err.
// ---               * resets DPC drop mode on link down (i.e. core_rst_n)
// ----------------------------------------------------------------------------

`include "include/DWC_pcie_ctl_all_defs.svh"

module rtlh_tlp_filter
#(
    parameter   NW           = `CX_NW,                     // Number of 32-bit dwords handled by the datapath each clock.
    parameter   DW           = NW*32,                      // Number of bits handled by the datapath on each clock cycle
    parameter   TP           = `TP,                        // Clock to Q delay (simulator insurance)
    parameter   DATA_PAR_WD  = `TRGT_DATA_PROT_WD,         // Data parity width
    parameter   DW_W_PAR     = DW + DATA_PAR_WD            // Data with parity bits
)

                      (
    // ---- inputs ---------------
    input                                     core_clk,
    input                                     core_rst_n,
    input                      [NW-1:0]       rtlh_tlp_soh,
    input                      [NW-1:0]       rtlh_tlp_eot,
    input                      [NW-1:0]       rtlh_tlp_pfx,
    input                      [NW-1:0]       rtlh_tlp_idl,
    input                                     rtlh_tlp_fm_nullified,
    input                                     rtlh_tlp_fm_poisoned,
    input                      [NW-1:0]       rtlh_tlp_dllp_err,
    input                      [DW_W_PAR-1:0] rtlh_data,
    input                                     rtlh_data_dv,
    input                                     dpc_fatal_err_gate,     // DPC trigger gating for fatal error message
    input                                     dpc_nonfatal_err_gate,  // DPC trigger gating for non-fatal error message
    input                                     cfg_upstream_port,     // Port logic mode (0=downstream, 1=upstream)
    // ---- outputs ---------------- 
    output                     [NW-1:0]       rtlh_filter_soh,
    output                     [NW-1:0]       rtlh_filter_eot,
    output                     [NW-1:0]       rtlh_filter_pfx,
    output                     [NW-1:0]       rtlh_filter_idl,
    output                                    rtlh_filter_fm_nullified,
    output                                    rtlh_filter_fm_poisoned,
    output                     [NW-1:0]       rtlh_filter_dllp_err,
    output                     [DW_W_PAR-1:0] rtlh_filter_data,
    output                                    rtlh_filter_data_dv
);

reg [NW-1:0] err_f_msg,  raw_err_f_msg;
reg [NW-1:0] err_nf_msg, raw_err_nf_msg;

localparam LB = 2; // LookBack: number of dwords to be latched
reg [LB-1:0]    r_soh;
reg [LB*32-1:0] r_data;
reg             r_raw_f, r_raw_nf;

// Extended vectors: concatenates latched sigals with current inputs.
wire [NW-1:-LB]    extd_soh;
wire [DW-1:-LB*32] extd_data;
assign extd_soh    = {rtlh_tlp_soh,      r_soh };
assign extd_data   = {rtlh_data[DW-1:0], r_data};

// Next vectors - LookBack values to be latched
// Note that bubbles (i.e. idl dwords during TLPs) get removed.
reg [LB-1:0]       next_soh;
reg [LB-1:0][31:0] next_data;
always_comb begin : next_lookback_PROC
    reg next_full;
    reg [$clog2(LB)-1:0] i_next;
    next_full   = 1'b0;
    i_next      = LB-1;
    next_soh    ='0;
    next_data   ='0;
    for (int i=NW-1; i>=0; i=i-1) begin
        if (!rtlh_tlp_idl[i] && !next_full) begin
            next_soh   [i_next] = rtlh_tlp_soh[i];
            next_data  [i_next] = rtlh_data[i*32 +: 32];
            next_full = i_next == '0;
            i_next = (next_full)? '0 : i_next - 1'b1;
        end
    end
    for (int i=LB-1; i>=0; i=i-1) begin
        if (!next_full) begin
            next_soh   [i_next] = r_soh[i];
            next_data  [i_next] = r_data[i*32 +: 32];
            next_full = i_next == '0;
            i_next = (next_full)? '0 : i_next - 1'b1;
        end
    end
end

always @(posedge core_clk or negedge core_rst_n) begin
    if( !core_rst_n ) begin
        r_soh        <= #TP '0;
        r_data       <= #TP '0;
        r_raw_f      <= #TP '0;
        r_raw_nf     <= #TP '0;
    end else begin
        if(rtlh_data_dv) begin
            r_soh    <= #TP next_soh;
            r_data   <= #TP next_data;
            r_raw_f  <= #TP raw_err_f_msg [NW-1];
            r_raw_nf <= #TP raw_err_nf_msg[NW-1];
        end
    end
end

// Message routing check.
wire downstream_port;
assign downstream_port = ~cfg_upstream_port;

// Detect good TLPs ending (i.e. no errors from Layer2)
wire [NW-1:0] valid_tlp_end;
wire [NW-1:0] rtlh_tlp_last_eot;
wire [NW-1:0] rtlh_tlp_last_fm_nullified;
assign rtlh_tlp_last_eot[NW-1] = rtlh_tlp_eot[NW-1];
for (genvar i=0; i<NW-1; i=i+1) begin
    assign rtlh_tlp_last_eot[i] = rtlh_tlp_eot[i] &  ~|rtlh_tlp_eot[NW-1:i+1];
end
assign rtlh_tlp_last_fm_nullified = {NW{rtlh_tlp_fm_nullified}} & rtlh_tlp_last_eot;
assign valid_tlp_end = rtlh_tlp_eot & ~rtlh_tlp_dllp_err & ~rtlh_tlp_last_fm_nullified;

// Detect ERR MSG on the 2nd Header dword and propagates the 'raw' flag up to the eot.
// Note that most checks (for example: ECRC, MAC/PCRC, unsupported OHC/trailer, Length Malformed, 
// or any other malformation) are not required because the would all represent DPC triggers. 
// But we do have to wait until the eot and make sure the TLP is not DL errored 
// (i.e. dllp_abort meaning bad lcrc, out-of-sequence,.. ) or FM_Nullified.
always_comb begin : detect_err_msg_PROC
    reg [31:0] dw1, dw2;
    reg [7:0] fmt_type, msg_code;
    err_f_msg  = '0;
    err_nf_msg = '0;
    raw_err_f_msg  = '0;
    raw_err_nf_msg = '0;
    for (int i=0; i<NW; i=i+1) begin
        dw2      = extd_data[i*32 +: 32];
        dw1      = extd_data[i*32-1 -: 32];
        fmt_type = dw1[7:0];
        msg_code = dw2[31:24];
        raw_err_f_msg [i] = (i==0)? r_raw_f  : raw_err_f_msg [i-1]; // Propagate the raw err from the previous
        raw_err_nf_msg[i] = (i==0)? r_raw_nf : raw_err_nf_msg[i-1]; // dword if the TLP is still in progress
        if (extd_soh[i-1] && !rtlh_tlp_idl[i]) begin
            // Check if this is a ERR MSG is F or NF
            // 'Raw' is because we must wait for the eot and make sure no errors from lower layers.
            raw_err_f_msg [i] = fmt_type=={1'b0, `MSG_4, `MSG_ROUT_TO_RC} && msg_code==`ERR_F;
            raw_err_nf_msg[i] = fmt_type=={1'b0, `MSG_4, `MSG_ROUT_TO_RC} && msg_code==`ERR_NF;
        end
        if (rtlh_tlp_eot[i]) begin
            // Detect the DPC event only when enabled by 'DPC Trigger Enable filed' and not already errored.
            err_f_msg [i] = dpc_fatal_err_gate  & raw_err_f_msg [i] & downstream_port & valid_tlp_end[i];
            err_nf_msg[i] = dpc_nonfatal_err_gate & raw_err_nf_msg[i] & downstream_port & valid_tlp_end[i];
            raw_err_f_msg [i] = 1'b0;
            raw_err_nf_msg[i] = 1'b0;
        end
    end
end

// Drop TLPs in DLP mode
reg r_rtlh_in_dpc_drop;
wire [NW-1:0] drop_tlps;
assign drop_tlps[0] = r_rtlh_in_dpc_drop;
for (genvar i=1; i<NW; i=i+1) begin
    assign drop_tlps[i] = r_rtlh_in_dpc_drop | (|err_f_msg[i-1:0]) | (|err_nf_msg[i-1:0]);
end

always @(posedge core_clk or negedge core_rst_n) begin
    if( !core_rst_n ) begin
        r_rtlh_in_dpc_drop        <= #TP '0;
    end else begin
        // No need to reset on link down: after DPC, we will necessarily receive core_rst_n        
        if(rtlh_data_dv) begin
            r_rtlh_in_dpc_drop    <= #TP r_rtlh_in_dpc_drop | (|err_f_msg) | (|err_nf_msg);
        end
    end
end

wire [NW-1:0] out_dllp_err;
assign out_dllp_err = rtlh_tlp_dllp_err | drop_tlps;

localparam OUT_DELAY_WD = NW       + // rtlh_tlp_soh
                          NW       + // rtlh_tlp_eot
                          NW       + // rtlh_tlp_pfx
                          NW       + // rtlh_tlp_idl
                          1        + // rtlh_tlp_fm_nullified
                          1        + // rtlh_tlp_fm_poisoned
                          NW       + // rtlh_tlp_dllp_err
                          DW_W_PAR + // rtlh_data
                          1        ; // rtlh_data_dv

// Optional output delay.
// Note except from rtlh_filter_dllp_err (which might be overwritten in case of packets to drop),
// all inputs are trasparently forwarded to outputs.
localparam REGOUT = `CX_RTLH_TLP_FILTER_MS_REGOUT;
delay_n

#(REGOUT, OUT_DELAY_WD) u_ouput_delay (
    .clk   (core_clk),
    .rst_n (core_rst_n),
    .clear (1'b0),
    .din   ({rtlh_tlp_soh,
            rtlh_tlp_eot,
            rtlh_tlp_pfx,
            rtlh_tlp_idl,
            rtlh_tlp_fm_nullified,
            rtlh_tlp_fm_poisoned,
            out_dllp_err,
            rtlh_data,
            rtlh_data_dv}),
    .dout  ({rtlh_filter_soh,
            rtlh_filter_eot,
            rtlh_filter_pfx,
            rtlh_filter_idl,
            rtlh_filter_fm_nullified,
            rtlh_filter_fm_poisoned,
            rtlh_filter_dllp_err,
            rtlh_filter_data,
            rtlh_filter_data_dv})
);

endmodule : rtlh_tlp_filter
