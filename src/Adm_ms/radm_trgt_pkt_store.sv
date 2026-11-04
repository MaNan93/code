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
// ---    $DateTime: 2023/12/22 07:15:34 $
// ---    $Revision: #9 $
// ---    $Id: //dwh/pcie_iip/main/fairbanks/design/Adm_ms/radm_trgt_pkt_store.sv#9 $
// -------------------------------------------------------------------------
// Description:
// Following  FIFO to store incoming  information (HDR + DATA) and to manage credit based
// transaction before reading the TLP from formation queue.
// This FIFO is per FC in the each TRGT interfaces and can be shared with multiple VC's
// as per TRGT interface to VC configuration
//---------------------------------------------------------------------------------------

`include "include/DWC_pcie_ctl_all_defs.svh"
`include "DWC_pcie_ctl_pkg.svh"
`include "Adm_ms/radm_ms_pkg.svh"
`include "products/DWC_pcie_core_pkg.svh"

module radm_trgt_pkt_store

  ///////////////////////////////////////// 
  //import radm_ms_pkg starts
  import radm_ms_pkg::H_FIFO_DEPTH;
  import radm_ms_pkg::H_ADDR_WIDTH;
  import radm_ms_pkg::PKT_ORD_WD;
  import radm_ms_pkg::flt_hdr_s ;
  import radm_ms_pkg::trgt_fifo_rd_grnt_s;
  import radm_ms_pkg::radm_hdr_dec_com_ohc_decx_present_s;
  import radm_ms_pkg::flt_q_dmux_o_s;
  import radm_ms_pkg::flt_data_o_s;
  import radm_ms_pkg::flt_p_hdr_o_s;
  import radm_ms_pkg::hdr_destination;
  import radm_ms_pkg::radm_hdr_log_err_index;
  import radm_ms_pkg::conv_hdr_from_np_type;
  import radm_ms_pkg::conv_hdr_from_p_type;
  import radm_ms_pkg::conv_hdr_from_cpl_type;
  //calling the definitations of enum values of hdr_destination
  import radm_ms_pkg::TRGT1;
  import radm_ms_pkg::TRGT0;
  import radm_ms_pkg::TRASH;
  import radm_ms_pkg::pktstr_hlog_s;

  //import radm_ms_pkg ends
  //////////////////////////////////////////
  
  //////////////////////////////////////////
  //import DWC_pcie_ctl_pkg starts
  import DWC_pcie_ctl_pkg::TP;
  import DWC_pcie_ctl_pkg::NW;
  //import DWC_pcie_ctl_pkg ends
  /////////////////////////////////////
  
  /////////////////////////////////////
  //import DWC_pcie_core_pkg starts 
  import DWC_pcie_core_pkg::DATA_PAR_WD;
  import DWC_pcie_core_pkg::DW;
  //import DWC_pcie_core_pkg ends
  ////////////////////////////////////
  

#(
    parameter  H_FIFO_WIDTH     = 0,   // FIFO Storage Header width
    // If both storage type is zero the STR is considered for CPL type
    parameter  H_STR_P_TYPE     = 0,   // FIFO Storage for P Type Header
    parameter  H_STR_NP_TYPE    = 0,   // FIFO Storage for NP Type Header
    parameter  CPL_BYPASS       = 0,   // CPL_BYPASS_CTRL
    parameter  ST_CT_CTRL       = 0,   // 1:S&F  0:C/T
    parameter  D_FIFO_DEPTH     = 0,   // FIFO Storage needed data
    parameter  D_ADDR_WIDTH     = 0    // FIFO Storage needed data
)(
    // Clock and Reset
    // -------------------------------------------------------------------------------------
    input                                         core_clk,           // Clock input
    input                                         core_rst_n,         // Reset
    // -------------------------------------------------------------------------------------
    // Input/Output declaration
    // -------------------------------------------------------------------------------------
    input flt_data_o_s                            flt_q_data_in,
    input [H_FIFO_WIDTH-1:0]                      flt_q_hdr_in,
    input                                         trgt_halt,

    output  flt_q_dmux_o_s                        radm_trgt_fifo_out,
    output                                        radm_trgt_fifo_pipe_empty,
    output  trgt_fifo_rd_grnt_s                   trgt_fifo_hdr_data_grnt
`ifndef SYNTHESIS
  ,
    output                                        flt_pkt_num_valid,
    output  [PKT_ORD_WD-1:0]                      flt_pkt_num
`endif
);

localparam D_H_CTRL_DEPTH      = D_FIFO_DEPTH + H_FIFO_DEPTH;
localparam D_H_CTRL_ADDR_WIDTH = $clog2(D_H_CTRL_DEPTH);
localparam H_CTRL_ADDR_WIDTH   = $clog2(H_FIFO_DEPTH);
localparam EOT_FIFO_DEPTH      = H_FIFO_DEPTH+1;                // in CT we return crd at hdr, not at eot=> FIFO can have 1 extra EOT.
localparam EOT_ADDR_WIDTH      = $clog2(EOT_FIFO_DEPTH);
localparam integer REG_DELAY_DENOM = 1000;
localparam integer REG_DELAY_TIME_IN  = `TP * REG_DELAY_DENOM;


//////////////////
// Header FIFO
//////////////////
typedef struct packed {
    logic [H_FIFO_WIDTH-1:0]            flt_q_hdr_in;
} fifo_hdr_s;

fifo_hdr_s  fifo_hdr_i;
fifo_hdr_s  fifo_hdr_o;
logic       fifo_hdr_empty;
logic       fifo_hdr_full;
logic       fifo_hdr_push;
logic       fifo_hdr_pop;
logic  [2:0]     s_flt_q_cpl_status;
logic  [1:0]     s_flt_q_destination;
flt_hdr_s   s_flt_q_hdr;
fifo_hdr_s  fifo_hdr_o_dmux;   // fifo_hdr_o but keeps the header stable
flt_hdr_s   fifo_hdr_out;      // unpack flat header into the header struct
flt_hdr_s   fifo_hdr_in;      // unpack flat header into the header struct
flt_hdr_s   fifo_hdr_out_dest; // same as fifo_hdr_out but overrides destination field in case we need to drop the TLP

//////////////////
// Data FIFO
//////////////////
typedef struct packed {
    logic [NW-1:0]             flt_q_dwen;
    logic [DW+DATA_PAR_WD-1:0] flt_q_data;
} fifo_data_s;

fifo_data_s fifo_data_i;
fifo_data_s fifo_data_o;
logic       fifo_data_empty;
logic       fifo_data_full;
logic       fifo_data_push;
logic       fifo_data_pop;

///////////////////////
// Control bits FIFO
///////////////////////
// Note this could be compressed in 2-bits
typedef struct packed {
    logic  eot;
    logic  dv;
    logic  hv;
} fifo_ctrl_s;

fifo_ctrl_s fifo_ctrl_i;
fifo_ctrl_s fifo_ctrl_o;
fifo_ctrl_s fifo_ctrl_o_valid; // When the FIFO is !empty and !s_trgt_halt
logic       fifo_ctrl_empty;
logic       fifo_ctrl_full;
logic       fifo_ctrl_push;
logic       fifo_ctrl_pop;
logic       fifo_ctrl_tlp_ready; // S&F: 1 or more complete TLPs stored. C/T: always ready (fifo not empty)
logic       fifo_ctrl_o_valid_hv_ready;
logic       fifo_ctrl_o_valid_dv_ready;

///////////////////////
// EOT FIFO
///////////////////////
// In this FIFO we write eot-aligned fields
// In S&F the are available and stable during the whole TLP duration.
// In C/T they ane guaranteed only durint eot
typedef struct packed {
    logic                  radm_hdr_log_vld;
    logic                  radm_hdr_log_vld_all_fn;
    logic [4:0]            radm_hdr_log_err_index;
    logic                  flt_q_parerr;
    logic                  flt_q_tlp_poisoned;
    logic                  flt_q_ecrc_err;
    logic                  tlp_abort;
    logic                  dllp_abort;
    logic  [2:0]           flt_q_cpl_status;
    logic  [1:0]           flt_q_destination;
} fifo_eot_s;

fifo_eot_s  fifo_eot_i;
fifo_eot_s  fifo_eot_o;
logic       fifo_eot_full;
logic       fifo_eot_empty;
logic       fifo_eot_push;
logic       fifo_eot_pop;


// Drop TLPs in case of errors
logic tlp_drop_dllp_err;
logic tlp_drop_tlp_err;
logic tlp_drop_eot;
logic tlp_to_trgt0;

logic flt_q_in_hv;
logic flt_q_in_dv;
logic flt_q_in_eot;

 logic [`CX_NPRFX-1:0][31:0]                   s_tlp_prfx;
 logic [`CX_RX_HDW_MS-1:0][31:0]               s_tlp_hdr;
 logic [`CX_RX_HDW_MS-1:0]                     s_tlp_hdr_dwen;
 logic [`CX_RADM_PKT_ORD_WD-1:0]               s_tlp_p_pkt_num_unused;
 logic                                         s_trgt_halt;
 flt_q_dmux_o_s                                s_radm_trgt_fifo_out;

assign flt_q_in_hv  = flt_q_hdr_in[0];
assign flt_q_in_dv  = flt_q_data_in.flt_q_dv;
assign flt_q_in_eot = flt_q_data_in.flt_q_eot;

// FIFO empty flag
assign radm_trgt_fifo_pipe_empty =                              fifo_ctrl_empty;

generate
if (CPL_BYPASS == 0) begin : sf_or_ct_fifo_gen
    // FIFO Control Logic
    assign fifo_hdr_push  = flt_q_in_hv;
    assign fifo_hdr_pop   = !fifo_hdr_empty  & fifo_ctrl_o_valid_hv_ready;

    assign fifo_data_push = flt_q_in_dv;
    assign fifo_data_pop  = !fifo_data_empty & fifo_ctrl_o_valid_dv_ready;

    assign fifo_ctrl_push = flt_q_in_hv | flt_q_in_dv;
    assign fifo_ctrl_pop  = (fifo_ctrl_o_valid.hv | fifo_ctrl_o_valid.dv) & fifo_ctrl_tlp_ready;

    assign fifo_eot_push  = flt_q_in_eot;
    assign fifo_eot_pop   = fifo_ctrl_o_valid.eot;

    assign fifo_ctrl_tlp_ready  = (ST_CT_CTRL == 1)? !fifo_eot_empty : 1'b1 ;
    assign fifo_ctrl_o_valid_hv_ready = fifo_ctrl_tlp_ready & fifo_ctrl_o_valid.hv;
    assign fifo_ctrl_o_valid_dv_ready = fifo_ctrl_tlp_ready & fifo_ctrl_o_valid.dv;

    // RADM Credits return
    trgt_fifo_rd_grnt_s trgt_fifo_rd_vld_c;
    assign trgt_fifo_rd_vld_c.hdr_fifo_rd   = fifo_hdr_pop;
    assign trgt_fifo_rd_vld_c.data_fifo_rd  = fifo_data_pop;
    always_ff @(posedge core_clk or negedge core_rst_n) begin
        if (core_rst_n ==1'b0) begin
            trgt_fifo_hdr_data_grnt     <= #TP 'd0;
        end else begin
            trgt_fifo_hdr_data_grnt     <= #TP trgt_fifo_rd_vld_c;
        end
    end

    // Header FIFO 
    DWC_pcie_ctl_bcm64_td
     #(
        .WIDTH($bits(fifo_hdr_s)),
        .DEPTH(H_FIFO_DEPTH),
        .ERR_MODE(0),
        .RST_MODE(0),
        .ADDR_WIDTH(H_ADDR_WIDTH),
        .REG_DELAY_TIME(REG_DELAY_TIME_IN),
        .REG_DELAY_DENOM(REG_DELAY_DENOM)
    )
    u_radm_trgt_hdr_fifo(
        // Inputs
        .clk(core_clk), .rst_n(core_rst_n), .init_n(1'b1), .push_req_n(!fifo_hdr_push), .pop_req_n(!fifo_hdr_pop),
        .diag_n(1'b1), .ae_level('1), .af_thresh('1),
        .data_in(fifo_hdr_i),
        // Outputs
        .empty(fifo_hdr_empty), .almost_empty(), .full(fifo_hdr_full),
        .half_full(), .almost_full(), .error(),
        .data_out(fifo_hdr_o)
    );

    // Data FIFO
    DWC_pcie_ctl_bcm64_td
     #(
        .WIDTH($bits(fifo_data_s)),
        .DEPTH(D_FIFO_DEPTH),
        .ERR_MODE(0),
        .RST_MODE(0),
        .ADDR_WIDTH(D_ADDR_WIDTH),
        .REG_DELAY_TIME(REG_DELAY_TIME_IN),
        .REG_DELAY_DENOM(REG_DELAY_DENOM)
    )
    u_radm_trgt_data_fifo(
        // Inputs
        .clk(core_clk), .rst_n(core_rst_n), .init_n(1'b1), .push_req_n(!fifo_data_push), .pop_req_n(!fifo_data_pop),
        .diag_n(1'b1), .ae_level('1), .af_thresh('1),
        .data_in(fifo_data_i),
        // Outputs
        .empty(fifo_data_empty), .almost_empty(), .full(fifo_data_full),
        .half_full(), .almost_full(), .error(),
        .data_out(fifo_data_o)
    );

    // Control bits FIFO
    DWC_pcie_ctl_bcm64_td
     #(
       .WIDTH($bits(fifo_ctrl_s)),
       .DEPTH(D_H_CTRL_DEPTH),
       .ERR_MODE(0),
       .RST_MODE(0),
       .ADDR_WIDTH(D_H_CTRL_ADDR_WIDTH),
       .REG_DELAY_TIME(REG_DELAY_TIME_IN),
       .REG_DELAY_DENOM(REG_DELAY_DENOM)
    )
    u_radm_trgt_ctrl_fifo(
        // Inputs
       .clk(core_clk), .rst_n(core_rst_n), .init_n(1'b1), .push_req_n(!fifo_ctrl_push), .pop_req_n(!fifo_ctrl_pop),
       .diag_n(1'b1), .ae_level('1), .af_thresh('1),
       .data_in(fifo_ctrl_i),
       // Outputs
       .empty(fifo_ctrl_empty), .almost_empty(), .full(fifo_ctrl_full),
       .half_full(), .almost_full(), .error(),
       .data_out(fifo_ctrl_o)
    );
    assign fifo_ctrl_o_valid = (fifo_ctrl_empty | s_trgt_halt) ? '0 : fifo_ctrl_o;

    // EOT FIFO
    DWC_pcie_ctl_bcm64_td
     #(
       .WIDTH($bits(fifo_eot_s)),
       .DEPTH(EOT_FIFO_DEPTH),
       .ERR_MODE(0),
       .RST_MODE(0),
       .ADDR_WIDTH(EOT_ADDR_WIDTH),
       .REG_DELAY_TIME(REG_DELAY_TIME_IN),
       .REG_DELAY_DENOM(REG_DELAY_DENOM)
    )
    u_radm_trgt_eot_fifo(
        // Inputs
       .clk(core_clk), .rst_n(core_rst_n), .init_n(1'b1), .push_req_n(!fifo_eot_push), .pop_req_n(!fifo_eot_pop),
       .diag_n(1'b1), .ae_level('1), .af_thresh('1),
       .data_in(fifo_eot_i),
       // Outputs
       .empty(fifo_eot_empty), .almost_empty(), .full(fifo_eot_full),
       .half_full(), .almost_full(), .error(),
       .data_out(fifo_eot_o)
    );

    // Pack input fields into FIFO structs
    always_comb begin : pack_fifo_hdr_i_PROC
        fifo_hdr_i.flt_q_hdr_in              = flt_q_hdr_in;
    end

    always_comb begin : pack_fifo_data_i_PROC
        fifo_data_i.flt_q_dwen               = flt_q_data_in.flt_q_dwen;
        fifo_data_i.flt_q_data               = flt_q_data_in.flt_q_data;
    end

    always_comb begin : pack_fifo_ctrl_i_PROC
        fifo_ctrl_i.eot                      = flt_q_in_eot;
        fifo_ctrl_i.dv                       = flt_q_in_dv;
        fifo_ctrl_i.hv                       = flt_q_in_hv;
    end

    always_comb begin : pack_fifo_eot_i_PROC
        fifo_eot_i.radm_hdr_log_vld          = flt_q_data_in.radm_hdr_log_vld;
        fifo_eot_i.radm_hdr_log_vld_all_fn   = flt_q_data_in.radm_hdr_log_vld_all_fn;
        fifo_eot_i.radm_hdr_log_err_index    = flt_q_data_in.radm_hdr_log_err_index;
        fifo_eot_i.flt_q_parerr              = flt_q_data_in.flt_q_parerr;
        fifo_eot_i.flt_q_tlp_poisoned        = flt_q_data_in.flt_q_tlp_poisoned;
        fifo_eot_i.flt_q_ecrc_err            = flt_q_data_in.flt_q_ecrc_err;
        fifo_eot_i.tlp_abort                 = flt_q_data_in.flt_q_tlp_abort;
        fifo_eot_i.dllp_abort                = flt_q_data_in.flt_q_dllp_abort;
        fifo_eot_i.flt_q_cpl_status          = s_flt_q_cpl_status;
        fifo_eot_i.flt_q_destination         = s_flt_q_destination;
    end

    // TLP Drop Logic
    // In store and forward mode set destination to THRASH if thrashed by the
    // filter (UR/CA) or TLP is malformed or TLP is DLLP aborted. 
    // The destinaton signal controls the TLP masking in the DEMUX. 
    // In cut-thru thrashed/aborted TLPS are passed to the TRGT, abort signals valid on eot.  
    if (ST_CT_CTRL == 1) begin : sf_tlp_drop_gen
        assign tlp_drop_tlp_err   = fifo_eot_o.tlp_abort && (fifo_hdr_out.flt_q_destination inside {TRGT0, TRGT1});
        assign tlp_drop_dllp_err  = fifo_eot_o.dllp_abort;
        assign tlp_drop_eot       = (fifo_eot_o.flt_q_destination == TRASH);
        assign tlp_to_trgt0       = !fifo_eot_o.tlp_abort && (fifo_eot_o.flt_q_destination == TRGT0);

// Overwriting HDR destination information with destination information received with EOT 
// Passing CPL_status received with EOT

    always_comb begin : destn_and_cpl_status_update_sf
        fifo_hdr_out_dest = fifo_hdr_out;
        if(tlp_drop_dllp_err || tlp_drop_tlp_err || tlp_drop_eot) begin
           fifo_hdr_out_dest.flt_q_destination = TRASH;
           if (fifo_eot_pop) begin
             fifo_hdr_out_dest.flt_q_cpl_status  =  fifo_eot_o.flt_q_cpl_status;
           end
        end
        else if (tlp_to_trgt0) begin
           fifo_hdr_out_dest.flt_q_destination =  TRGT0;
           if (fifo_eot_pop) begin
             fifo_hdr_out_dest.flt_q_cpl_status  =  fifo_eot_o.flt_q_cpl_status;
           end
        end
        else if (fifo_eot_pop) begin
             fifo_hdr_out_dest.flt_q_destination =  hdr_destination'(fifo_eot_o.flt_q_destination);
             fifo_hdr_out_dest.flt_q_cpl_status  =  fifo_eot_o.flt_q_cpl_status;
        end
     end 
    end else begin  // if (ST_CT_CTRL == 0) 
    always_comb begin : dest_cpl_status_update_ct

        fifo_hdr_out_dest = fifo_hdr_out;

         if (fifo_eot_pop) begin
             fifo_hdr_out_dest.flt_q_destination =  hdr_destination'(fifo_eot_o.flt_q_destination);
             fifo_hdr_out_dest.flt_q_cpl_status  =  fifo_eot_o.flt_q_cpl_status;
        end
     end
    end


    // Following delay module is to latch header information when HV is not asserted.
    // This is requirement from XADM also to match with Gen5 implementation
    fifo_hdr_s fifo_hdr_o_r;
    delay_n_w_enable
     #(
        .N          (1),
        .WD         ($bits(fifo_hdr_s))
    ) u_hdr_latch (
        .clk        (core_clk),
        .rst_n      (core_rst_n),
        .clear      (1'b0),
        .en         (fifo_hdr_pop),
        .din        (fifo_hdr_o),
        .dout       (fifo_hdr_o_r)
    );
    assign fifo_hdr_o_dmux = (fifo_hdr_pop)? fifo_hdr_o : fifo_hdr_o_r;

    // Drive Outputs
    assign s_radm_trgt_fifo_out.flt_q_header            = fifo_hdr_out_dest;
    assign s_radm_trgt_fifo_out.flt_q_tlp_poisoned      = (fifo_eot_pop)? fifo_eot_o.flt_q_tlp_poisoned      : '0;

    assign s_radm_trgt_fifo_out.flt_q_dwen              = fifo_data_o.flt_q_dwen;
    assign s_radm_trgt_fifo_out.flt_q_data              = fifo_data_o.flt_q_data;

    assign s_radm_trgt_fifo_out.flt_q_eot               = fifo_eot_pop;
    assign s_radm_trgt_fifo_out.flt_q_dv                = fifo_data_pop;
    assign s_radm_trgt_fifo_out.flt_q_hv                = fifo_hdr_pop;

    assign s_radm_trgt_fifo_out.radm_hdr_log_err_index  = (fifo_eot_pop)? fifo_eot_o.radm_hdr_log_err_index  : '0;
    assign s_radm_trgt_fifo_out.radm_hdr_log_vld_all_fn = (fifo_eot_pop)? fifo_eot_o.radm_hdr_log_vld_all_fn : '0;
    assign s_radm_trgt_fifo_out.radm_hdr_log_vld        = (fifo_eot_pop)? fifo_eot_o.radm_hdr_log_vld        : '0;
    assign s_radm_trgt_fifo_out.flt_q_parerr            = (fifo_eot_pop)? fifo_eot_o.flt_q_parerr            : '0;
    assign s_radm_trgt_fifo_out.flt_q_ecrc_err          = (fifo_eot_pop)? fifo_eot_o.flt_q_ecrc_err          : '0;

    assign s_radm_trgt_fifo_out.flt_q_tlp_abort         =  fifo_eot_pop ? fifo_eot_o.tlp_abort               : '0;
    assign s_radm_trgt_fifo_out.flt_q_dllp_abort        =  fifo_eot_pop ? fifo_eot_o.dllp_abort              : '0;
    assign s_radm_trgt_fifo_out.cpl_status_trgt0        = fifo_eot_o.flt_q_cpl_status;


  assign radm_trgt_fifo_out = s_radm_trgt_fifo_out;
  assign s_trgt_halt = trgt_halt;


`ifndef SYNTHESIS
`endif // !SYNTHESIS

    //////////////////////////////////////////////////
    // End of common logic when TLP is in SF
    //////////////////////////////////////////////////

end else if (CPL_BYPASS == 1) begin : bypass_fifo_gen

    assign fifo_ctrl_empty  = 1'b0;
    assign fifo_hdr_pop     = 1'b0;

    assign trgt_fifo_hdr_data_grnt.hdr_fifo_rd     = 1'b1;
    assign trgt_fifo_hdr_data_grnt.data_fifo_rd    = 1'b1;

    always_comb begin : fifo_bypass_signal_update_PROC
        radm_trgt_fifo_out.flt_q_header                   = fifo_hdr_out;
        radm_trgt_fifo_out.flt_q_header.flt_q_destination = fifo_hdr_out.flt_q_destination;
        radm_trgt_fifo_out.flt_q_hv                       = flt_q_in_hv;
        radm_trgt_fifo_out.flt_q_dwen                     = flt_q_data_in.flt_q_dwen;
        radm_trgt_fifo_out.flt_q_eot                      = flt_q_data_in.flt_q_eot;
        radm_trgt_fifo_out.flt_q_dv                       = flt_q_data_in.flt_q_dv;
        radm_trgt_fifo_out.flt_q_data                     = flt_q_data_in.flt_q_data;
        radm_trgt_fifo_out.radm_hdr_log_vld_all_fn        = flt_q_data_in.radm_hdr_log_vld_all_fn;
        radm_trgt_fifo_out.radm_hdr_log_vld               = flt_q_data_in.radm_hdr_log_vld;
        radm_trgt_fifo_out.flt_q_parerr                   = (flt_q_data_in.flt_q_eot)? flt_q_data_in.flt_q_parerr           :'0;
        radm_trgt_fifo_out.flt_q_ecrc_err                 = (flt_q_data_in.flt_q_eot)? flt_q_data_in.flt_q_ecrc_err         :'0;
        radm_trgt_fifo_out.flt_q_dllp_abort               = (flt_q_data_in.flt_q_eot)? flt_q_data_in.flt_q_dllp_abort       :'0;
        radm_trgt_fifo_out.flt_q_tlp_poisoned             = (flt_q_data_in.flt_q_eot)? flt_q_data_in.flt_q_tlp_poisoned     :'0;
        radm_trgt_fifo_out.flt_q_tlp_abort                = (flt_q_data_in.flt_q_eot)? flt_q_data_in.flt_q_tlp_abort        :'0;
        radm_trgt_fifo_out.radm_hdr_log_err_index         = (flt_q_data_in.flt_q_eot)? flt_q_data_in.radm_hdr_log_err_index :'0;
        radm_trgt_fifo_out.cpl_status_trgt0               =  3'b000;
    end
end // CPL_FIFO_BYPASS
endgenerate


generate if ( CPL_BYPASS && H_STR_P_TYPE ) begin : str_bypass_p_type_gen
  assign fifo_hdr_out = conv_hdr_from_p_type(flt_q_hdr_in);
end else if ( CPL_BYPASS && H_STR_NP_TYPE ) begin : str_bypass_np_type_gen
  assign fifo_hdr_out = conv_hdr_from_np_type(flt_q_hdr_in);
end else if ( CPL_BYPASS ) begin : str_bypass_cpl_type_gen
  assign fifo_hdr_out = conv_hdr_from_cpl_type(flt_q_hdr_in);
end
endgenerate


generate if ( (CPL_BYPASS == 0) && H_STR_P_TYPE ) begin : str_p_type_gen
  assign fifo_hdr_out = conv_hdr_from_p_type(fifo_hdr_o_dmux.flt_q_hdr_in);
end else if ( (CPL_BYPASS == 0) && H_STR_NP_TYPE ) begin : str_np_type_gen
  assign fifo_hdr_out = conv_hdr_from_np_type(fifo_hdr_o_dmux.flt_q_hdr_in);
end else if ( (CPL_BYPASS == 0) ) begin : str_cpl_type_gen
  assign fifo_hdr_out = conv_hdr_from_cpl_type(fifo_hdr_o_dmux.flt_q_hdr_in);
end
endgenerate

generate if (H_STR_P_TYPE) begin : p_type_gen
  assign fifo_hdr_in = conv_hdr_from_p_type(flt_q_hdr_in);
end else if (H_STR_NP_TYPE) begin : np_type_gen
  assign fifo_hdr_in = conv_hdr_from_np_type(flt_q_hdr_in);
end else  begin : cpl_type_gen
  assign fifo_hdr_in = conv_hdr_from_cpl_type(flt_q_hdr_in);
end
endgenerate

  assign s_flt_q_cpl_status  = fifo_hdr_in.flt_q_cpl_status;
  assign s_flt_q_destination = fifo_hdr_in.flt_q_destination;


// Assign Outputs
`ifndef SYNTHESIS
  // Outputs to testbench
  
  assign flt_pkt_num_valid = radm_trgt_fifo_out.flt_q_eot  && 
                             !radm_trgt_fifo_out.flt_q_dllp_abort &&
                             !trgt_halt;

  assign flt_pkt_num       = radm_trgt_fifo_out.flt_q_header.flt_pkt_num;

`endif


// --------------------------------------------------------------------------------------
// Assign Outputs
// --------------------------------------------------------------------------------------

endmodule
