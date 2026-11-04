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
// ---    $Revision: #7 $
// ---    $Id: //dwh/pcie_iip/main/fairbanks/design/Adm_ms/radm_demux_ctrl.sv#7 $
// -------------------------------------------------------------------------
// -------------------------------------------------------------------------
// --- Module Description:
// ----------------------------------------------------------------------------
// Description :
// Tis modules gets input from  - 
// 1. With single VC configuration, this module direct gets input TLP's from respective TLP type filter
// 2. In case of Multi VC configuration, this module gets input from VC arbiter 
//
// - This module routes the received TLP to respective destination  i.e - 
//       - TRGT0 
//       - TRGT1
//       - TRASH the TLP 
//   TLP destination received from Filter as per address decoding, mode of operation, error sceanrios etc
//  - Depends upon destination received for received TLP, TLP routes to respective TRGT interface
//  - HALT received from TRGT0 or from TRGT1 (FC type) will be forwarded to respective filter block to
//  - stop taking new TLP's 
//  - TRGT0 and TRGT1 interfaces are registered to avoid timing issues 
//  - TRGT1 logic accepts addition one cycle data after asserting the halt and storing in internal pipeline
//  - If TLP is routed to TRGT0 or TRASHED inside this module, the TLP packet order number 
//    information shared with TRGT1 interface to manage ordering sceanrio inside bridge logic
// ----------------------------------------------------------------------------
`include "include/DWC_pcie_ctl_all_defs.svh"
`include "DWC_pcie_ctl_pkg.svh"
`include "Adm_ms/radm_ms_pkg.svh"
`include "products/DWC_pcie_core_pkg.svh"

module radm_demux_ctrl
  import DWC_pcie_ctl_pkg::TP;
  import radm_ms_pkg::HW;
  import radm_ms_pkg::INT_DWIDTH;
  import radm_ms_pkg::INT_HWIDTH;
  import radm_ms_pkg::INT_HDW;
  import radm_ms_pkg::flt_q_dmux_o_s;
  import radm_ms_pkg::dmux_clkg_ctrl_s; 
  import radm_ms_pkg::flt_hdr_s; 
  import DWC_pcie_core_pkg::DW;
 

  #(
     localparam CAN_STALL     = 1,   
     localparam PIPE_DELAY    = 1   
  ) 
                        (

    // Clock and Reset
    // -------------------------------------------------------------------------------------
    input                                                                             core_clk,             // PCIE clock
    input                                                                             radm_clk_ug,          // PCIE clock ungated
    input                                                                             core_rst_n,           // Reset active low asynchronous reset
    // -------------------------------------------------------------------------------------
    // Configuration
    // -------------------------------------------------------------------------------------
    input                                                                             radm_qmode_ct_byp, 
    // -------------------------------------------------------------------------------------
    // Packet Store to Demux Interface
    // -------------------------------------------------------------------------------------
    input  flt_q_dmux_o_s                                                             flt_q_dmux_in,  // INput from Filter 
    output logic                                                                      trgt_halt, 
    // -------------------------------------------------------------------------------------
    // Demux to TRGT Interface
    // -------------------------------------------------------------------------------------
    output  logic [INT_HDW - 1 : 0]                                                   dmux_trgt1_req,  // Destination req to TRGT1
    output  logic [INT_HWIDTH - 1 : 0]                                                radm_trgt1_hdr_dmux,
    output  logic [INT_DWIDTH - 1 :0]                                                 radm_trgt1_data_dmux,
    input                                                                             stall_trgt1, 
    output  logic [INT_HDW - 1 : 0]                                                   dmux_trgt0_req,  // Destination req to TRGT0
    input                                                                             trgt0_radm_halt_int, 
    // -------------------------------------------------------------------------------------
    // Clock Gating Control Signals
    // -------------------------------------------------------------------------------------
    output dmux_clkg_ctrl_s                                                           dmux_clkg_ctrl,
    // -------------------------------------------------------------------------------------
    // Demux to Header Log Interface
    // -------------------------------------------------------------------------------------
    output  flt_q_dmux_o_s                                                            flt_q_dmux_hdr_log,
    input                                                                             log_halt
  );
  
  // -------------------------------------------------------------------------------------
  // Signals declaration
  // -------------------------------------------------------------------------------------
  logic   [1:0]                                                             flt_q_destination;
  logic                                                                     radm_trgt0_h_xfer_vld;
  logic                                                                     radm_trgt0_d_xfer_vld;
  logic                                                                     radm_trgt1_h_xfer_vld;
  logic                                                                     radm_trgt1_d_xfer_vld;
  logic                                                                     radm_trgt_tlp_trsh,trgt1_trsh_tlp_abort,radm_trgt_tlp_trsh_in;
            
  logic [INT_HWIDTH-1:0]                                                    flt_q_h_trgt0_dmux; 
  logic [INT_HWIDTH-1:0]                                                    radm_trgt0_hdr_dmux;
  logic [INT_HWIDTH-1:0]                                                    radm_trgt0_hdr_r; 
  logic [INT_HWIDTH-1:0]                                                    flt_q_h_trgt1_dmux; 
  logic [INT_DWIDTH-1:0]                                                    flt_q_d_trgt1_dmux;
  logic [INT_DWIDTH-1:0]                                                    flt_q_d_trgt0_dmux;
  logic [INT_DWIDTH-1:0]                                                    radm_trgt0_data_dmux;
  logic [INT_DWIDTH-1:0]                                                    radm_trgt0_data_r;
  flt_q_dmux_o_s                                                            flt_q_dmux_in_fifo;  // INput from Filter or from VC arbiter  (inputs are in structured format)

  logic fifo_rd_hv;
  logic fifo_rd_dv;
  logic fifo_rd_eot;
  logic radm_trgt1_ctrl_hv;
  logic radm_trgt1_ctrl_dv;
  logic radm_trgt0_ctrl_hv;
  logic radm_trgt0_ctrl_dv;
  logic radm_trgt0_ctrl_eot;
  logic radm_trgt1_ctrl_eot;
  logic radm_trgt1_ctrl_vld_in;
  logic radm_trgt0_ctrl_vld_in;
  logic radm_trgt1_ctrl_ecrc;
  logic radm_trgt0_ctrl_ecrc;
  logic radm_trgt1_ctrl_t_abort;
  logic radm_trgt1_ctrl_perr;
  logic radm_trgt0_ctrl_perr;
  logic radm_trgt0_ctrl_abort;
  logic radm_trgt1_ctrl_d_abort;
  logic radm_trgt0_ctrl_d_abort;
  logic stall_trgt0;
  // -------------------------------------------------------------------------------------
  // Types declaration
  // -------------------------------------------------------------------------------------
  // 2 phase active state
  typedef enum logic [1:0] {
    HDR_VLD   = 2'b00,
    DATA_VLD  = 2'b01
  } TRGT0_TRGT1_INTF_st;

  TRGT0_TRGT1_INTF_st                                       hdr_data_st_nxt, hdr_data_st_cur; //  FSM STATES

  assign flt_q_dmux_in_fifo     = flt_q_dmux_in;
  assign fifo_rd_hv =  flt_q_dmux_in_fifo.flt_q_hv ;
  assign fifo_rd_dv =  flt_q_dmux_in_fifo.flt_q_dv ;
  assign fifo_rd_eot =  flt_q_dmux_in_fifo.flt_q_eot ;

  logic last_tlp_had_dllp_err;
  always_ff@(posedge core_clk or negedge core_rst_n)begin
    if(!core_rst_n)begin
    last_tlp_had_dllp_err <= #TP '0;
    end else begin
      last_tlp_had_dllp_err <= #TP (flt_q_dmux_in_fifo.flt_q_dllp_abort && flt_q_dmux_in_fifo.flt_q_eot && !trgt_halt) ? 1'b1 : (flt_q_dmux_in_fifo.flt_q_hv && !trgt_halt) ? 1'b0 : last_tlp_had_dllp_err;
    end
  end


  logic trgt1_tlp_abort;
  logic trgt_tlp_abort;
  logic radm_hdr_log_tlp_abort;
  assign trgt_tlp_abort =  (flt_q_dmux_in_fifo.flt_q_tlp_abort);
  assign trgt1_tlp_abort =  (trgt_tlp_abort | trgt1_trsh_tlp_abort);
  assign radm_hdr_log_tlp_abort =  (flt_q_dmux_in_fifo.radm_hdr_log_vld | flt_q_dmux_in_fifo.flt_q_tlp_abort | trgt1_trsh_tlp_abort | radm_trgt_tlp_trsh);

  always_comb begin
    // Initialise
    flt_q_dmux_hdr_log                 = flt_q_dmux_in_fifo ;
    flt_q_dmux_hdr_log.flt_q_tlp_abort = radm_hdr_log_tlp_abort ;
  end
  // -------------------------------------------------------------------------------------
  // Active state FSM
  // -------------------------------------------------------------------------------------
  // Following FSM logic takes care to accept Header and DATA.
  // Access of current TLP keep valif till get EOT of current TLP
  // .....................................................................................

  assign flt_q_destination  = flt_q_dmux_in_fifo.flt_q_header.flt_q_destination; // DEcodes destination information from received header
  always_comb begin : signals_state_PROC
    radm_trgt0_d_xfer_vld = 1'b0;
    radm_trgt0_h_xfer_vld = 1'b0;
    radm_trgt1_d_xfer_vld = 1'b0;
    radm_trgt1_h_xfer_vld = 1'b0;
    trgt1_trsh_tlp_abort  = 1'b0;
    radm_trgt_tlp_trsh    = 1'b0;

// HDR and DATA xfer decision making as per destination info received with HV
    case (hdr_data_st_cur)
      HDR_VLD: begin
        if (fifo_rd_hv) begin
          if (flt_q_destination == `FLT_DESTINATION_TRGT1) begin
            radm_trgt1_h_xfer_vld   = 1'b1;
            radm_trgt1_d_xfer_vld   = 1'b1;
          end
          else if (flt_q_destination == `FLT_DESTINATION_TRGT0) begin
            radm_trgt0_h_xfer_vld   = 1'b1;
            radm_trgt0_d_xfer_vld   = 1'b1;
            radm_trgt1_h_xfer_vld   = radm_qmode_ct_byp; 
            radm_trgt1_d_xfer_vld   = radm_qmode_ct_byp;
            if (fifo_rd_eot) begin
              trgt1_trsh_tlp_abort  = radm_qmode_ct_byp;
            end
          end else begin
            radm_trgt1_h_xfer_vld   = radm_qmode_ct_byp;
            radm_trgt1_d_xfer_vld   = radm_qmode_ct_byp;
            if (fifo_rd_eot) begin
              radm_trgt_tlp_trsh    = ~radm_qmode_ct_byp;
              radm_trgt_tlp_trsh_in = 1'b0;
              trgt1_trsh_tlp_abort  = radm_qmode_ct_byp;
            end
          end
        end
      end

// HDR and DATA xfer decision making as per destination info received with DV/EOT
      DATA_VLD:begin
        if (fifo_rd_dv) begin
          if (flt_q_destination == `FLT_DESTINATION_TRGT1) begin
            radm_trgt1_d_xfer_vld   = 1'b1;
            end
          else if (flt_q_destination == `FLT_DESTINATION_TRGT0) begin
            radm_trgt0_d_xfer_vld   = 1'b1;
            radm_trgt1_d_xfer_vld   = radm_qmode_ct_byp;

            if (fifo_rd_eot) begin
              trgt1_trsh_tlp_abort  = radm_qmode_ct_byp;
            end
          end else begin
            radm_trgt1_d_xfer_vld   = radm_qmode_ct_byp;
            if (fifo_rd_eot) begin
              radm_trgt_tlp_trsh    = ~radm_qmode_ct_byp;
              trgt1_trsh_tlp_abort  = radm_qmode_ct_byp;
            end
          end
        end
      end
      default: begin
          radm_trgt0_d_xfer_vld     = 1'b0;
          radm_trgt0_h_xfer_vld     = 1'b0;
          radm_trgt_tlp_trsh        = 1'b0;
          trgt1_trsh_tlp_abort      = 1'b0;
          radm_trgt1_d_xfer_vld     = 1'b0;
          radm_trgt1_h_xfer_vld     = 1'b0;
       end
    endcase
  end

  always_comb begin : state_change_PROC
    hdr_data_st_nxt = hdr_data_st_cur;

    case (hdr_data_st_cur)
      HDR_VLD: begin
        if (fifo_rd_hv & fifo_rd_eot )
          hdr_data_st_nxt   = HDR_VLD;
        else if (fifo_rd_dv)  
          hdr_data_st_nxt   = DATA_VLD;
        else 
          hdr_data_st_nxt   = HDR_VLD;
      end

      DATA_VLD:begin
        if (fifo_rd_dv)
        begin
          if (fifo_rd_eot )
            hdr_data_st_nxt = HDR_VLD;
          else 
            hdr_data_st_nxt = DATA_VLD;
        end
      end
      default: 
        begin
          hdr_data_st_nxt   = hdr_data_st_cur;
        end
    endcase
  end


// Seperating data and header as per routed destination
  
  assign flt_q_d_trgt1_dmux = {
  last_tlp_had_dllp_err,
  flt_q_dmux_in_fifo.flt_q_tlp_poisoned,
  radm_trgt1_ctrl_t_abort,radm_trgt1_ctrl_perr,radm_trgt1_ctrl_ecrc,radm_trgt1_ctrl_d_abort,radm_trgt1_ctrl_eot,
  flt_q_dmux_in_fifo.flt_q_dwen,flt_q_dmux_in_fifo.flt_q_data,radm_trgt1_ctrl_dv};

  assign radm_trgt1_data_dmux = flt_q_d_trgt1_dmux;

  assign flt_q_d_trgt0_dmux = {
  last_tlp_had_dllp_err,
  flt_q_dmux_in_fifo.flt_q_tlp_poisoned,
  radm_trgt0_ctrl_d_abort,radm_trgt0_ctrl_perr,radm_trgt0_ctrl_ecrc,radm_trgt0_ctrl_abort,radm_trgt0_ctrl_eot,
  flt_q_dmux_in_fifo.flt_q_dwen,flt_q_dmux_in_fifo.flt_q_data,radm_trgt0_ctrl_dv};

  assign radm_trgt0_data_dmux = flt_q_d_trgt0_dmux;

//flt_q_dmux_in_fifo.cpl_status_trgt0 added additional seperate cpl_status_trgt0_signal to rote to TRGT0. This status has updated in trgt_pkt_store depends on received error sceanrio for NP.   
  assign flt_q_h_trgt0_dmux = {flt_q_dmux_in_fifo.flt_q_header,flt_q_dmux_in_fifo.cpl_status_trgt0,radm_trgt0_ctrl_hv};
  assign radm_trgt0_hdr_dmux = flt_q_h_trgt0_dmux;
  assign flt_q_h_trgt1_dmux = {flt_q_dmux_in_fifo.flt_q_header,3'b000,radm_trgt1_ctrl_hv};
  assign radm_trgt1_hdr_dmux = flt_q_h_trgt1_dmux;

  always_comb begin: TRGT1
    radm_trgt1_ctrl_hv   = '0;
    radm_trgt1_ctrl_dv  = '0;

    if (radm_trgt1_h_xfer_vld == 1'b1) begin
      radm_trgt1_ctrl_hv   = fifo_rd_hv;
    end
    if (radm_trgt1_d_xfer_vld == 1'b1) begin
      radm_trgt1_ctrl_dv   = fifo_rd_dv;
    end
  end
  assign radm_trgt1_ctrl_vld_in = (radm_trgt1_h_xfer_vld | radm_trgt1_d_xfer_vld); 

  assign radm_trgt1_ctrl_eot = radm_trgt1_ctrl_vld_in & fifo_rd_eot
                               ;

  assign radm_trgt1_ctrl_t_abort = radm_trgt1_ctrl_vld_in & trgt1_tlp_abort;
  assign radm_trgt1_ctrl_d_abort = radm_trgt1_ctrl_vld_in & flt_q_dmux_in_fifo.flt_q_dllp_abort;  
  assign radm_trgt1_ctrl_ecrc    = radm_trgt1_ctrl_vld_in & flt_q_dmux_in_fifo.flt_q_ecrc_err;  
  assign radm_trgt1_ctrl_perr    = radm_trgt1_ctrl_vld_in & flt_q_dmux_in_fifo.flt_q_parerr;
  assign dmux_trgt1_req      = {radm_trgt1_data_dmux,radm_trgt1_hdr_dmux};

  assign radm_trgt0_ctrl_vld_in = (radm_trgt0_h_xfer_vld | radm_trgt0_d_xfer_vld); 
// Providing common abort signal to LBC for DLLP and TLP abort 
  assign radm_trgt0_ctrl_abort   = radm_trgt0_ctrl_vld_in & (trgt_tlp_abort | 
                                                             flt_q_dmux_in_fifo.flt_q_dllp_abort
                                                             ); 

  assign radm_trgt0_ctrl_d_abort = radm_trgt0_ctrl_vld_in & flt_q_dmux_in_fifo.flt_q_dllp_abort;  
  assign radm_trgt0_ctrl_ecrc    = radm_trgt0_ctrl_vld_in & flt_q_dmux_in_fifo.flt_q_ecrc_err;  
  assign radm_trgt0_ctrl_perr    = radm_trgt0_ctrl_vld_in & flt_q_dmux_in_fifo.flt_q_parerr;

//------------------------------------------------------------------------------------
// TLP's routing to TRGT0 interface 
//------------------------------------------------------------------------------------
  always_comb begin: TRGT0
    radm_trgt0_ctrl_hv   = '0;
    radm_trgt0_ctrl_dv  = '0;

    if (radm_trgt0_h_xfer_vld == 1'b1) begin
      radm_trgt0_ctrl_hv   = fifo_rd_hv;
    end
    if (radm_trgt0_d_xfer_vld == 1'b1) begin
      radm_trgt0_ctrl_dv  = fifo_rd_dv;
    end
  end :TRGT0

  assign radm_trgt0_ctrl_eot = (radm_trgt0_h_xfer_vld | radm_trgt0_d_xfer_vld) & fifo_rd_eot;  

//-------------------------------------------------------------------------------------------
// Following logic to manage pipeliene stages if HALT asserts from TRGT1 interface 
//-------------------------------------------------------------------------------------------
  // Following sequencetial block is to - 
  // 1. Handle pipeliene sceanrio during HALT assertion from TRGT1 interface 
  // 2. Send registered output for Trashed/ TRGT0 routed Packet order number and valid signal
  // ---------------------------------------------------------------------------------------------
  always_ff @(posedge core_clk or negedge core_rst_n)
  begin
    if (core_rst_n ==1'b0) begin
      hdr_data_st_cur               <= #TP HDR_VLD;
    end else begin
      hdr_data_st_cur               <= #TP hdr_data_st_nxt;
    end
  end

// Registers output at TRGT0 interface 
  logic stall_hv_in,stall_dv_in,stallout_hdr,stallout_data;

  assign stall_hv_in = trgt0_radm_halt_int; 
  assign stall_dv_in = trgt0_radm_halt_int; 

  delay_n_w_stalling
  
  #(  .N          (PIPE_DELAY), 
      .WD         (INT_HWIDTH),
      .CAN_STALL  (CAN_STALL),
      .RESETVAL   (0)
  ) u_hdr_trgt0_stall
  (
      .clk        (core_clk),
      .rst_n      (core_rst_n),
      .clear      (1'b0),
      .stall         (stall_hv_in),
      .stallout      (stallout_hdr),
      .din        (radm_trgt0_hdr_dmux),
      .dout       (radm_trgt0_hdr_r)
    );
  
  delay_n_w_stalling
  
  #(  .N          (PIPE_DELAY), 
      .WD         (INT_DWIDTH),
      .CAN_STALL  (CAN_STALL),
      .RESETVAL   (0)

  ) u_data_trgt0_stall
  (
      .clk        (core_clk),
      .rst_n      (core_rst_n),
      .clear      (1'b0),
      .stall      (stall_dv_in),
      .stallout   (stallout_data),
      .din        (radm_trgt0_data_dmux),
      .dout       (radm_trgt0_data_r)
    );

  assign stall_trgt0 = stallout_data | stallout_hdr;
  // Stall pkt store, hv/dv/eot de-asserted
  assign trgt_halt = stall_trgt1  | stall_trgt0 | log_halt;


// --------------------------------------------------------------------------------------
// Assign Outputs
// --------------------------------------------------------------------------------------
  assign dmux_trgt0_req                 = {radm_trgt0_data_r,radm_trgt0_hdr_r}; 

  // Register out clock gating control info
  always_ff @(posedge core_clk or negedge core_rst_n) begin : proc_seq_clkg_ctrl
    if (!core_rst_n) begin
      dmux_clkg_ctrl.tlp_dropped <= #TP 0;
      dmux_clkg_ctrl.tlp_routed_to_trgt0 <= #TP 0;
    end else begin
      // Indicates TLP dropped internally, not sent to TRGT interface.
      // Valid for store/forward TRGT FIFO Queue mode.
      dmux_clkg_ctrl.tlp_dropped <= #TP radm_trgt_tlp_trsh; 
      // Indicates TLP routed to TRGT0.
      dmux_clkg_ctrl.tlp_routed_to_trgt0 <= #TP radm_trgt0_ctrl_eot;
    end  
  end

endmodule
