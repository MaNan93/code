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
// ---    $Revision: #7 $
// ---    $Id: //dwh/pcie_iip/main/fairbanks/design/Layer3/rtlh_qdw_extract.sv#7 $
// ----------------------------------------------------------------------------
// --- Description:
// ----------------------------------------------------------------------------

`include "include/DWC_pcie_ctl_all_defs.svh"
`include "DWC_pcie_ctl_pkg.svh"
`include "products/DWC_pcie_core_pkg.svh"
`include "Layer3/rtlh_pkg.svh"
`include "products/pcie_pkg.svh"

module rtlh_qdw_extract
import DWC_pcie_core_pkg::RX_NQDW;
import rtlh_pkg::dec_tlp_state_t;
import rtlh_pkg::rtlh_qdw_extract_t;
import rtlh_pkg::evt_type_e;
import pcie_pkg::fc_type_e;
import pcie_pkg::E_FC_NONE;
#(
parameter   INST         = 0,                          // The uniquifying parameter for each port logic instance.
parameter   NW           = `CX_NW,                     // Number of 32-bit dwords handled by the datapath each clock.
parameter   DW           = NW*32,                      // Number of bits handled by the datapath on each clock cycle
parameter   TP           = `TP,                        // Clock to Q delay (simulator insurance)
parameter   RX_TLP       = `CX_RX_TLP,                 // number of TLPs which can be received in a single clock cycle
parameter   DEC_NW       = 5,                          // numder of dws handled by single decoder
parameter   DEC_DW       = DEC_NW*32,                  // data width of single decoder
parameter   NUM_DEC      = (NW + DEC_NW -1) / DEC_NW,  // number of decoders
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
input                                     rtlh_tlp_fm_nullified,  // The last TLP ending was Nullified by the Flit Marker
input                                     rtlh_tlp_fm_poisoned,   // The last TLP ending was Poisoned by the Flit Marker
input                      [NW-1:0]       rtlh_tlp_dllp_err,
input                      [DW_W_PAR-1:0] rtlh_data,              // Packet Data
input                                     rtlh_data_dv,           // Packed Data Valid
input                      [23:0]         cfg_tc_struc_vc_map,
input                                     dpc_fatal_err_gate,     // DPC trigger gating for fatal error message
input                                     dpc_nonfatal_err_gate,  // DPC trigger gating for non-fatal error message
input                                     cfg_upstream_port,      // Port logic mode (0=downstream, 1=upstream)
input                                     flit_mode_en,           // Flit Mode Enabled
// ---- outputs ---------------- 
output reg                                rtqextract_fm_nullified,
output reg                                rtqextract_fm_poisoned,
output  rtlh_qdw_extract_t [RX_NQDW-1:0]  rtqextract
);

localparam IDL_NW   = (DEC_NW*NUM_DEC) - NW;                 // number of idle dws due to the decoder not being fully utilised
localparam IDL_DW   = IDL_NW*32;                             // number of idle bits
localparam IDL_PROT = IDL_NW*`CX_RAS_DWORD_PROT_WD;  // IDL protection bits due to the decoder no being utilised
localparam DEC_PROT = 5*`CX_RAS_DWORD_PROT_WD;       // number of protection bits in one decoder

wire [NW-1:0]       rtlh_filter_soh;
wire [NW-1:0]       rtlh_filter_eot;
wire [NW-1:0]       rtlh_filter_pfx;
wire [NW-1:0]       rtlh_filter_idl;
wire                rtlh_filter_fm_nullified;
wire                rtlh_filter_fm_poisoned;
wire [NW-1:0]       rtlh_filter_dllp_err;
wire [DW_W_PAR-1:0] rtlh_filter_data;
wire                rtlh_filter_data_dv;

rtlh_tlp_filter
 u_rtlh_tlp_filter (
  // --- inputs --------------------------------------
    .core_clk                 (core_clk                ),
    .core_rst_n               (core_rst_n              ),
    .rtlh_tlp_soh             (rtlh_tlp_soh            ),
    .rtlh_tlp_eot             (rtlh_tlp_eot            ),
    .rtlh_tlp_pfx             (rtlh_tlp_pfx            ),
    .rtlh_tlp_idl             (rtlh_tlp_idl            ),
    .rtlh_tlp_fm_nullified    (rtlh_tlp_fm_nullified   ),
    .rtlh_tlp_fm_poisoned     (rtlh_tlp_fm_poisoned    ),
    .rtlh_tlp_dllp_err        (rtlh_tlp_dllp_err       ),
    .rtlh_data                (rtlh_data               ),
    .rtlh_data_dv             (rtlh_data_dv            ),
    .dpc_fatal_err_gate       (dpc_fatal_err_gate      ),
    .dpc_nonfatal_err_gate    (dpc_nonfatal_err_gate   ),
    .cfg_upstream_port        (cfg_upstream_port       ),
  // --- outputs --------------------------------------
    .rtlh_filter_soh          (rtlh_filter_soh         ),
    .rtlh_filter_eot          (rtlh_filter_eot         ),
    .rtlh_filter_pfx          (rtlh_filter_pfx         ),
    .rtlh_filter_idl          (rtlh_filter_idl         ),
    .rtlh_filter_fm_nullified (rtlh_filter_fm_nullified),
    .rtlh_filter_fm_poisoned  (rtlh_filter_fm_poisoned ),
    .rtlh_filter_dllp_err     (rtlh_filter_dllp_err    ),
    .rtlh_filter_data         (rtlh_filter_data        ),
    .rtlh_filter_data_dv      (rtlh_filter_data_dv     )
);

dec_tlp_state_t [NUM_DEC-1:0] pts;        // previous tlp state
dec_tlp_state_t [NUM_DEC-1:0] nts;        // next tlp state

rtlh_qdw_extract_t [NUM_DEC*2-1:0] qdws;

rtlh_qdw_extract_t [RX_NQDW-1:0]   o_qdws;    // out qdws

// input signals to decoder with overhead included
logic [NUM_DEC*DEC_NW-1:0]    tlp_soh;
logic [NUM_DEC*DEC_NW-1:0]    tlp_eot;
logic [NUM_DEC*DEC_NW-1:0]    tlp_pfx;
logic [NUM_DEC*DEC_NW-1:0]    tlp_idl;
logic [NUM_DEC*DEC_NW-1:0]    tlp_dllp_err;
logic [NUM_DEC*DEC_DW-1:0]    data;
logic [NUM_DEC*DEC_PROT-1:0]  data_prot;     // protection bits for the data signal

// assign input signals to these signals, note the idle dws due to decoder overhead
assign tlp_soh      =  { {IDL_NW{1'b0}},   rtlh_filter_soh     };  
assign tlp_eot      =  { {IDL_NW{1'b0}},   rtlh_filter_eot     }; 
assign tlp_pfx      =  { {IDL_NW{1'b0}},   rtlh_filter_pfx     }; 
assign tlp_idl      =  { {IDL_NW{1'b1}},   rtlh_filter_idl     };
assign tlp_dllp_err =  { {IDL_NW{1'b1}},   rtlh_filter_dllp_err};
assign data         =  { {IDL_DW{1'b0}},   rtlh_filter_data[DW-1:0]};
assign data_prot    =  { {IDL_PROT{1'b0}}, rtlh_filter_data[DW_W_PAR-1:DW]};

// instantiate decoders
genvar nd; // number of decoders
generate for (nd=0; nd<NUM_DEC; nd=nd+1) begin : gen_u_rtlh_qdw_extract_dec
    rtlh_qdw_extract_dec
     u_rtlh_qdw_extract_dec(
        // ---- inputs ---------------
        .tlp_soh              (tlp_soh      [DEC_NW*nd   +:DEC_NW   ]),        
        .tlp_eot              (tlp_eot      [DEC_NW*nd   +:DEC_NW   ]),          
        .tlp_pfx              (tlp_pfx      [DEC_NW*nd   +:DEC_NW   ]),          
        .tlp_idl              (tlp_idl      [DEC_NW*nd   +:DEC_NW   ]),
        .tlp_dllp_err         (tlp_dllp_err [DEC_NW*nd   +:DEC_NW   ]),
        .data                 (data         [DEC_DW*nd   +:DEC_DW   ]),         
        .data_prot            (data_prot    [DEC_PROT*nd +:DEC_PROT ]),
        .cfg_tc_struc_vc_map  (cfg_tc_struc_vc_map),
                            
        .pts                  (pts     [nd]),
        
        .flit_mode_en         (flit_mode_en),
        // ---- outputs ---------------                  
        .nts                  (nts     [nd]),
        .qdws                 (qdws    [nd*2+:2])
    );
end
endgenerate

// Connect the next state outputs to the state inputs of next decoder in the chain
generate for (nd=1; nd<NUM_DEC; nd = nd+1) begin : gen_state
    assign pts[nd] = nts[nd-1];
end
endgenerate

// ... and the state register for decoder 0
always @(posedge core_clk or negedge core_rst_n) begin : state_seq_PROC
    if( !core_rst_n ) begin
        pts[0] <= #TP dec_tlp_state_t'(0);
    end else begin
        // state register loaded from the next_state from the last 256b decoder
        if(rtlh_filter_data_dv) begin
            pts[0] <= #TP nts[NUM_DEC-1];
        end else begin
            pts[0] <= #TP pts[0];
        end
    end
end

genvar ndw; // number of qdws the decoders can produce

generate for (ndw=0; ndw<RX_NQDW; ndw=ndw+1) begin : gen_conv
    always @(posedge core_clk or negedge core_rst_n) begin : out_PROC
      if (!core_rst_n) begin
        o_qdws[ndw]       <= #TP rtlh_pkg::RTLH_QDW_EXTRACT_RESET;
      end else begin
        if ( rtlh_filter_data_dv ) begin
          o_qdws[ndw]     <= #TP qdws[ndw];
        end else begin
          o_qdws[ndw]     <= #TP rtlh_pkg::RTLH_QDW_EXTRACT_RESET; 
        end
      end
    end
  end
endgenerate

assign rtqextract  = o_qdws;

// Sideband signals for Nullified and Poisoned
always @(posedge core_clk or negedge core_rst_n) begin
    if( !core_rst_n ) begin
        rtqextract_fm_nullified <= #TP 1'b0;
        rtqextract_fm_poisoned  <= #TP 1'b0;
    end else begin
        if(rtlh_filter_data_dv) begin
            rtqextract_fm_nullified <= #TP rtlh_filter_fm_nullified;
            rtqextract_fm_poisoned  <= #TP rtlh_filter_fm_poisoned;
        end
    end
end


endmodule : rtlh_qdw_extract
