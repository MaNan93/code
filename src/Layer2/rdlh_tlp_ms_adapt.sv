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
// ---    $Revision: #6 $
// ---    $Id: //dwh/pcie_iip/main/fairbanks/design/Layer2/rdlh_tlp_ms_adapt.sv#6 $
// ----------------------------------------------------------------------------
// --- Description: This module performs the following tasks.
//         - Mux between FM / NFM
//         - In NFM: 
//            * convert the per TLP nfm_rdlh_rtlh_tlp_abort vector in a NW signal
//            * detect prefix and generate nfm_rplh_rdlh_tlp_pfx
//            * generate the soh (start of header) vector instead of sot (start of tlp)
// ----------------------------------------------------------------------------
`include "include/DWC_pcie_ctl_all_defs.svh"

module rdlh_tlp_ms_adapt 
#(
parameter NW                = `CX_NW,              // Number of 32-bit DWords handled by the datapath each clock.
parameter NW_NFM            = (NW>16)? 16 : NW,    // Number of 32-bit DWords handled by the datapath each clock in Non-Flit Mode
parameter DW                = (32*NW),             // Width of datapath in bits.
parameter DW_NFM            = (32*NW_NFM),         // Width of datapath in bits in Non-Flit Mode
parameter DATA_PAR_WD       = `TRGT_DATA_PROT_WD,
parameter DATA_PAR_WD_NFM   = `NFM_TRGT_DATA_PROT_WD,
parameter DW_W_PAR          = DW + DATA_PAR_WD,
parameter DW_W_PAR_NFM      = DW_NFM + DATA_PAR_WD_NFM,
parameter RX_TLP            = `CX_RX_TLP,          // Number of TLPs that can be processed in this block in a single cycle
parameter REGOUT            = `CX_RDLH_TLP_MS_ADAPT_REGOUT, // Pipeline Enable for Layer 2 Receive module
parameter RX_TLP_NFM        = `CX_RX_TLP_NFM      // Number of TLPs that can be processed in this block in a single cycle in NFM
)
(
// ---- INPUTS  ----
input                       core_clk,
input                       core_rst_n,
input                       smlh_flit_mode_enable,            // Indicates flit mode status
input                       rplh_rdlh_pkt_dv,                 // Packet data valid
input [DW_W_PAR-1:0]        rplh_rdlh_pkt_data,               // Packet data
input [NW-1:0]              rplh_rdlh_tlp_pfx,                // Indicated DW location of prefix
input [NW-1:0]              rplh_rdlh_tlp_start,              // Indicates DW location of the 1st Base Header DW
input [NW-1:0]              rplh_rdlh_pkt_end,                // Indicates DW lacation of end of tlp
input [NW-1:0]              rplh_rdlh_tlp_idl,                // Indicates an empty DW
input                       rplh_rdlh_fm_nullified,           // The last TLP ending was Nullified by the Flit Marker
input                       rplh_rdlh_fm_poisoned,            // The last TLP ending was Poisoned by the Flit Marker
                                                   
input                       nfm_rdlh_rtlh_tlp_dv,             // Non-flit mode data valid
input [DW_W_PAR_NFM-1:0]    nfm_rdlh_rtlh_tlp_data,           // Non-flit mode data
input [NW_NFM-1:0]          nfm_rdlh_rtlh_tlp_sot,            // Non-flit mode firt DW location of a tlp (prefix or header)
input [NW_NFM-1:0]          nfm_rdlh_rtlh_tlp_eot,            // Non-flit mode DW location of end of tlp
input [RX_TLP_NFM-1:0]      nfm_rdlh_rtlh_tlp_abort,          // Non-flit mode signals a tlp is aborted
input [RX_TLP_NFM-1:0]      nfm_rdlh_nulified_tlp_err_pertlp, // Rx Nullified TLP Event per TLP for Ras D.E.S event counter

// ---- OUTPUTS ----
output                      rdlh_rtlh_tlp_dv,                 // Packet data valid
output [DW_W_PAR-1:0]       rdlh_rtlh_tlp_data,               // Packet data
output [NW-1:0]             rdlh_rtlh_tlp_pfx,                // Indicated DW location of prefix
output [NW-1:0]             rdlh_rtlh_tlp_soh,                // Indicates DW location of the 1st Base Header DW
output [NW-1:0]             rdlh_rtlh_tlp_eot,                // Indicates DW lacation of end of tlp
output [NW-1:0]             rdlh_rtlh_tlp_idl,
output [NW-1:0]             rdlh_rtlh_tlp_abort
,
output                      rdlh_rtlh_fm_nullified,           // The last TLP ending was Nullified by the Flit Marker
output                      rdlh_rtlh_fm_poisoned             // The last TLP ending was Poisoned by the Flit Marker
,
output [RX_TLP-1:0]         rdlh_nulified_tlp_err_pertlp      // Rx Nullified TLP Event per TLP for Ras D.E.S event counter
);

// non-flit mode signals generated by combinational logic
logic [NW_NFM-1:0]          nfm_rdlh_rtlh_tlp_pfx;
logic [NW_NFM-1:0]          nfm_rdlh_rtlh_tlp_soh;  // DW location of first base header DW of a tlp in non-flit mode
logic [NW_NFM-1:0]          nfm_rdlh_rtlh_tlp_idl;
logic [NW_NFM-1:0]          nfm_rdlh_rtlh_tlp_abort_nw; 

// delayed non-flit mode signals
logic                       nfm_rdlh_rtlh_tlp_dv_d;
logic [DW_W_PAR_NFM-1:0]    nfm_rdlh_rtlh_tlp_data_d;
logic [NW_NFM-1:0]          nfm_rdlh_rtlh_tlp_pfx_d;
logic [NW_NFM-1:0]          nfm_rdlh_rtlh_tlp_soh_d;
logic [NW_NFM-1:0]          nfm_rdlh_rtlh_tlp_eot_d;
logic [NW_NFM-1:0]          nfm_rdlh_rtlh_tlp_idl_d;
logic [NW_NFM-1:0]          nfm_rdlh_rtlh_tlp_abort_d;

// delayed and extended non-flit mode signals
logic [DW_W_PAR-1:0]        nfm_rdlh_rtlh_tlp_data_de;
logic [NW-1:0]              nfm_rdlh_rtlh_tlp_pfx_de;
logic [NW-1:0]              nfm_rdlh_rtlh_tlp_soh_de;
logic [NW-1:0]              nfm_rdlh_rtlh_tlp_eot_de;
logic [NW-1:0]              nfm_rdlh_rtlh_tlp_idl_de;
logic [NW-1:0]              nfm_rdlh_rtlh_tlp_abort_de;

// signals used in combinational logic
logic tlp_in_progress_r;
logic non_idle_dw;
logic tlp_in_progress;
logic pfx_in_progress_r;
logic pfx_in_progress;

// delay signals to aid QOR
logic                           mux_tlp_dv;
logic            [DW_W_PAR-1:0] mux_tlp_data;
logic                  [NW-1:0] mux_tlp_abort;
logic                  [NW-1:0] mux_tlp_soh;
logic                  [NW-1:0] mux_tlp_eot;
logic                  [NW-1:0] mux_tlp_idl;
logic                  [NW-1:0] mux_tlp_pfx;
logic              [RX_TLP-1:0] mux_nulified_tlp_err_pertlp;
logic                           mux_fm_nullified;
logic                           mux_fm_poisoned;


// Find FMT = 100 
reg [NW_NFM-1:0] raw_prefix_dw;
always_comb begin : decode_raw_prefix_dw
    for(int i = 0; i < NW_NFM; i = i + 1)
        raw_prefix_dw[i] = (nfm_rdlh_rtlh_tlp_data[32*i + 5 +: 3] == 3'b100);
end

// combinational logic to find pfx, soh and idl signals for non-flit mode
always_comb begin : gen_pfx_soh_idl_PROC
    non_idle_dw     = tlp_in_progress_r;
    tlp_in_progress = tlp_in_progress_r;
    pfx_in_progress = pfx_in_progress_r;
    nfm_rdlh_rtlh_tlp_pfx = '0;
    nfm_rdlh_rtlh_tlp_soh = '0;
    nfm_rdlh_rtlh_tlp_idl = '1; 
    for (int i=0; i<NW_NFM; i=i+1) begin
        if (nfm_rdlh_rtlh_tlp_dv) begin                // for a valid DW
            if (nfm_rdlh_rtlh_tlp_sot[i]) begin        // check for start of tlp
                tlp_in_progress = 1'b1;
                non_idle_dw     = 1'b1;
                pfx_in_progress = 1'b1;
            end
            if (non_idle_dw && pfx_in_progress) begin  // if prefix is in progress
                if (raw_prefix_dw[i]) begin            // check whether current DW is prefix
                    nfm_rdlh_rtlh_tlp_pfx[i] = 1'b1;   // if so, set prefix for this DW
                end else begin
                    nfm_rdlh_rtlh_tlp_soh[i] = 1'b1;   // otherwise, it is the first header the tlp
                    pfx_in_progress = 1'b0;            // set soh for this DW and mark that a prefix is no longer in progress
                end
            end
            if (nfm_rdlh_rtlh_tlp_eot[i]) begin        // check for end of tlp
                tlp_in_progress = 1'b0;
                pfx_in_progress = 1'b0;
            end

            nfm_rdlh_rtlh_tlp_idl[i] = ~non_idle_dw;
            non_idle_dw = tlp_in_progress;             // update the non_idle marker, this operation is done here so the
        end                                            // last DW of the tlp is not marked as idle
    end
end : gen_pfx_soh_idl_PROC


// register whether a tlp is in progress between clock cycles
always @(posedge core_clk or negedge core_rst_n) begin : tip_PROC // tlp in progress
  if (!core_rst_n) begin
    tlp_in_progress_r <= 1'b0;
  end else begin
    if (tlp_in_progress && nfm_rdlh_rtlh_tlp_dv) begin
      tlp_in_progress_r <= 1'b1;
    end else if (nfm_rdlh_rtlh_tlp_dv) begin
      tlp_in_progress_r <= 1'b0;
    end
  end
end : tip_PROC

// register whether a prefix is ongoing between clock cycles
always @(posedge core_clk or negedge core_rst_n) begin : pip_PROC // pfx in progress
  if (!core_rst_n) begin
    pfx_in_progress_r <= 1'b0;
  end else begin
    if (pfx_in_progress && nfm_rdlh_rtlh_tlp_dv) begin
      pfx_in_progress_r <= 1'b1;
    end else if (nfm_rdlh_rtlh_tlp_dv) begin
      pfx_in_progress_r <= 1'b0;
    end
  end
end : pip_PROC

// convert the per tlp abort signal to per dword (NW) signal
localparam RX_TLP_NFM_WD = (RX_TLP_NFM>1)? $clog2(RX_TLP_NFM) : 1;
logic [RX_TLP_NFM_WD-1:0] i_tlp_end;
always_comb begin : gen_pkt_edb_PROC
  i_tlp_end = '0;
  for (int i_dw=0; i_dw<NW_NFM; i_dw++) begin                                // loop through each DW postion
    if(nfm_rdlh_rtlh_tlp_eot[i_dw]) begin                                    // check for the end of a tlp
      nfm_rdlh_rtlh_tlp_abort_nw[i_dw] = nfm_rdlh_rtlh_tlp_abort[i_tlp_end]; // set the edb (DW) with the abort signal (per tlp)
      i_tlp_end = i_tlp_end+1'b1;                                            // increment the per tlp counter for every end of tlp
    end else begin
      nfm_rdlh_rtlh_tlp_abort_nw[i_dw] = 1'b0;                               // otherwise the edb signal is zero
    end
  end
end : gen_pkt_edb_PROC

localparam CTRL_BITS_WIDTH = 1 +       // dv
                             NW_NFM +  // pfx
                             NW_NFM +  // soh
                             NW_NFM +  // eot
                             NW_NFM +  // abort per nw
                             NW_NFM;   // idl


// Delay the non-flit mode signals
delay_n
 #(.N(!REGOUT), .WD(CTRL_BITS_WIDTH)) u_delay_ctrl_bits (
    .clk   (core_clk),
    .rst_n (core_rst_n),
    .clear (1'b0),
    .din   ({nfm_rdlh_rtlh_tlp_dv  ,nfm_rdlh_rtlh_tlp_pfx  , nfm_rdlh_rtlh_tlp_soh  ,nfm_rdlh_rtlh_tlp_eot,  nfm_rdlh_rtlh_tlp_idl,   nfm_rdlh_rtlh_tlp_abort_nw}),
    .dout  ({nfm_rdlh_rtlh_tlp_dv_d,nfm_rdlh_rtlh_tlp_pfx_d, nfm_rdlh_rtlh_tlp_soh_d,nfm_rdlh_rtlh_tlp_eot_d,nfm_rdlh_rtlh_tlp_idl_d, nfm_rdlh_rtlh_tlp_abort_d})
);

delay_n_w_enable
 #(.N(!REGOUT), .WD(DW_W_PAR_NFM)) u_delay_w_enable_data (
    .clk   (core_clk),
    .rst_n (core_rst_n),
    .clear (1'b0),
    .en    (nfm_rdlh_rtlh_tlp_dv),
    .din   (nfm_rdlh_rtlh_tlp_data),
    .dout  (nfm_rdlh_rtlh_tlp_data_d)
);

assign nfm_rdlh_rtlh_tlp_pfx_de  [NW-1:0]        = {{NW-NW_NFM{1'b0}}, nfm_rdlh_rtlh_tlp_pfx_d  };
assign nfm_rdlh_rtlh_tlp_soh_de  [NW-1:0]        = {{NW-NW_NFM{1'b0}}, nfm_rdlh_rtlh_tlp_soh_d  };
assign nfm_rdlh_rtlh_tlp_eot_de  [NW-1:0]        = {{NW-NW_NFM{1'b0}}, nfm_rdlh_rtlh_tlp_eot_d  };
assign nfm_rdlh_rtlh_tlp_idl_de  [NW-1:0]        = {{NW-NW_NFM{1'b1}}, nfm_rdlh_rtlh_tlp_idl_d  };
assign nfm_rdlh_rtlh_tlp_abort_de[NW-1:0]        = {{NW-NW_NFM{1'b0}}, nfm_rdlh_rtlh_tlp_abort_d};
assign nfm_rdlh_rtlh_tlp_data_de [DW-1:0]        = {{DW-DW_NFM{1'b0}}, nfm_rdlh_rtlh_tlp_data_d[DW_NFM-1:0]};
localparam RAS_ALL_0S_PROT_CODE = `CX_RAS_ALL_0S_PROT_CODE; 
assign nfm_rdlh_rtlh_tlp_data_de [DW_W_PAR-1:DW] = { nfm_rdlh_rtlh_tlp_data_d[DW_NFM +: DATA_PAR_WD_NFM] };

assign mux_tlp_dv                  = smlh_flit_mode_enable ? rplh_rdlh_pkt_dv                          : nfm_rdlh_rtlh_tlp_dv_d;
assign mux_tlp_data                = smlh_flit_mode_enable ? rplh_rdlh_pkt_data                        : nfm_rdlh_rtlh_tlp_data_de;
assign mux_tlp_abort               = smlh_flit_mode_enable ? '0                                        : nfm_rdlh_rtlh_tlp_abort_de;
assign mux_tlp_soh                 = smlh_flit_mode_enable ? rplh_rdlh_tlp_start                       : nfm_rdlh_rtlh_tlp_soh_de;
assign mux_tlp_eot                 = smlh_flit_mode_enable ? rplh_rdlh_pkt_end                         : nfm_rdlh_rtlh_tlp_eot_de;
assign mux_nulified_tlp_err_pertlp = smlh_flit_mode_enable ? {{RX_TLP-1{1'b0}},rplh_rdlh_fm_nullified} : {{RX_TLP-RX_TLP_NFM{1'b0}},nfm_rdlh_nulified_tlp_err_pertlp};
assign mux_tlp_idl                 = smlh_flit_mode_enable ? rplh_rdlh_tlp_idl                         :  nfm_rdlh_rtlh_tlp_idl_de;
assign mux_tlp_pfx                 = smlh_flit_mode_enable ? rplh_rdlh_tlp_pfx                         :  nfm_rdlh_rtlh_tlp_pfx_de;
assign mux_fm_nullified            =                            smlh_flit_mode_enable ? rplh_rdlh_fm_nullified                    :         1'b0;
assign mux_fm_poisoned             =                            smlh_flit_mode_enable ? rplh_rdlh_fm_poisoned                     :         1'b0;


// Delay the output of the MUX to aid QOR
localparam MUX_WIDTH =      1 +     // dv
                            NW +    // abort
                            NW +    // soh
                            NW +    // eot
                            NW +    // idl
                            NW      // pfx
    +RX_TLP // nulified tlp err
  +1+1    // fm nullified, fm poisoned
                    ;

//ctrl path
delay_n
 #(.N(REGOUT), .WD(MUX_WIDTH)) u_delay_mux_ctrl (
    .clk   (core_clk),
    .rst_n (core_rst_n),
    .clear (1'b0),
    .din   ({mux_tlp_dv, mux_tlp_abort, mux_tlp_soh, mux_tlp_eot, mux_tlp_idl, mux_tlp_pfx
            , mux_nulified_tlp_err_pertlp
            , mux_fm_nullified, mux_fm_poisoned
            }),
    .dout  ({rdlh_rtlh_tlp_dv, rdlh_rtlh_tlp_abort, rdlh_rtlh_tlp_soh, rdlh_rtlh_tlp_eot, rdlh_rtlh_tlp_idl, rdlh_rtlh_tlp_pfx
            , rdlh_nulified_tlp_err_pertlp
            , rdlh_rtlh_fm_nullified, rdlh_rtlh_fm_poisoned
            })
);
//data path
delay_n_w_enable
 #(.N(REGOUT), .WD(DW_W_PAR)) u_delay_mux_data (
    .clk        (core_clk),
    .rst_n      (core_rst_n),
    .clear      (1'b0),
    .en         (mux_tlp_dv),
    .din        (mux_tlp_data),
    .dout       (rdlh_rtlh_tlp_data)
);


endmodule : rdlh_tlp_ms_adapt
