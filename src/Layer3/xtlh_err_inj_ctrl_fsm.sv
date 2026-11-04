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
// ---    $Revision: #3 $
// ---    $Id: //dwh/pcie_iip/main/fairbanks/design/Layer3/xtlh_err_inj_ctrl_fsm.sv#3 $
// -------------------------------------------------------------------------
// --- Module Description:
// --- This is the error injection control FSM which is 
// --- responsible for enabling the pipeline, generating the halt to the upstream logic and
// --- driving the flit type encoding to enable the error injection in XPLH.
// -----------------------------------------------------------------------------

`include "include/DWC_pcie_ctl_all_defs.svh"
`include "products/cx_pl_pkg.svh"
`include "Layer3/xtlh_ms_pkg.svh"
`include "DWC_pcie_ctl_pkg.svh"

module xtlh_err_inj_ctrl_fsm 
  import  cx_pl_pkg::flit_type_struct;
  import  cx_pl_pkg::flit_type_enum;
  import  cx_pl_pkg::PYLD;
  import  cx_pl_pkg::NOP;
#(
  parameter TP = `TP
) 
                              (
  input                                     core_clk,
  input                                     core_rst_n,
  input                                     flit_gen_en,                // Flit Generation Enable
  input                                     spif_enable,                // SPIF Interface Enable
  input                                     cdm_err_inj_en,             // Error Injection Enable
  input                                     cdm_tx_err_inj_en,          // Transmit Path Error Injection Enable
  input                                     dv,                         // Data Valid
  input                                     sof,                        // Start of Flit
  input   [1 : 0]                           eof,                        // End of Flit
  input                                     halt_in,                    // Downstream halt
  input                                     pipe_dv,                    // PIPE dv
  input                                     flit_tlp_dv,                // Flit Data Valid
  output  logic                             push,                       // Push Signal to the FIFO
  output  logic                             pop_n,                      // POP Signal to the FIFO (Acitve Low for pipe_w_hs)
  output  logic                             bypass_pipe,                // Bypass PIPE 
  output  logic                             xtlh_err_inj_dv,            // Output data valid to the xtlh_fm_shift_ms module
  output  flit_type_struct                  flit_type_str,              // Flit Type
  output  logic                             xtlh_err_inj_halt           // halt to the upstream Module
);

typedef enum logic {
  IDLE          = 1'b0,
  SEND_DATA     = 1'b1
} state_e;

state_e next_state, state_r;

logic           data_at_sof_s;      // Indicator for the data at sof to save a flit duration time "signal"
logic           data_at_sof_r;      // Indicator for the data at sof to save a flit duration time "register"
logic           int_push_ind;       // PIPE Push Indication
logic           int_send_ind;       // PIPE Send Indication
logic           int_pop_en;         // Pop Enable ative high signal
flit_type_enum  flit_type;          // Flit Type Enum

//------------------------------------------\\
//----- Data at Start of Flit Process ------\\
//------------------------------------------\\
always_ff @(posedge core_clk or negedge core_rst_n) begin : data_at_sof_PROC
  if(!core_rst_n)
    data_at_sof_r <= #TP 1'b0;
  else
    data_at_sof_r <= #TP data_at_sof_s;
end : data_at_sof_PROC

//------------------------------------------\\
//----- Error Injection Enable Process -----\\
//------------------------------------------\\
always_ff @(posedge core_clk or negedge core_rst_n) begin : err_inj_en_PROC
  if(!core_rst_n)
    flit_type_str.err_inj_en <= #TP 1'b0;
  else if ( !spif_enable && cdm_err_inj_en && cdm_tx_err_inj_en && eof[1])
  //The err_inj_en signal will equal 1 at the next sof after the cdm_tx_err_inj_en and the cdm_err_inj_en assertion simultaneously
    flit_type_str.err_inj_en <= #TP 1'b1;
  else if (!( !spif_enable && cdm_err_inj_en && cdm_tx_err_inj_en) && eof[1])
  //The err_inj_en signal will equal 0 at the next sof after the cdm_tx_err_inj_en and the cdm_err_inj_en de-assertion simultaneously 
    flit_type_str.err_inj_en <= #TP 1'b0;
end : err_inj_en_PROC

//------------------------------------------\\
//----------- FSM States Process -----------\\
//------------------------------------------\\
always_comb begin : state_trans_PROC
  next_state = state_r;
  case(state_r)
   SEND_DATA : begin
      if(sof && !(dv || pipe_dv || flit_tlp_dv))
        begin
          next_state = IDLE;
        end
    end
    default : begin // IDLE
      if(flit_gen_en && flit_type_str.err_inj_en && ((dv && (sof || eof[1])) || flit_tlp_dv || (pipe_dv && (eof[1]))))
        begin
          next_state = SEND_DATA;
        end
    end
  endcase
end : state_trans_PROC

always_ff @(posedge core_clk or negedge core_rst_n) begin : state_PROC
  if(!core_rst_n)
    state_r <= #TP IDLE;
  else
    state_r <= #TP next_state;
end : state_PROC

always_comb begin : fsm_out_PROC
  //Default values to prevent latches
    flit_type     = NOP;
    int_push_ind  = 1'b0;
    int_send_ind  = 1'b0;
    data_at_sof_s = 1'b0;
    bypass_pipe   = 1'b1;

  case(state_r)
   SEND_DATA : begin
        flit_type = PYLD;
        if (dv && (data_at_sof_r || (sof && !(flit_tlp_dv || pipe_dv))))
          begin
            data_at_sof_s = 1'b1;
          end
        else if(sof && !(dv || pipe_dv || flit_tlp_dv))
          begin
            flit_type = NOP;
          end
        else if(!data_at_sof_r)
          begin
            bypass_pipe  = 1'b0;
            int_push_ind = 1'b1;
            int_send_ind = 1'b1;
          end
      end
    default : begin // IDLE
      if(flit_gen_en && flit_type_str.err_inj_en)
        begin
          if((dv && sof) || flit_tlp_dv)
            begin
              data_at_sof_s = 1'b1;
              flit_type     = PYLD;
            end
          else
            begin
              bypass_pipe  = 1'b0;
              int_push_ind = 1'b1;
            end
          end
        end
  endcase
end : fsm_out_PROC

assign push                    = int_push_ind  && (!halt_in) && dv;            // Push in the FIFO if there is push indication and dv and there is no halt_in signal
assign int_pop_en              = int_send_ind  && (!halt_in) && pipe_dv;       // POP from the FIFO if there is POP indication and there is data in the FIFO and there is no halt_in signal
assign pop_n                   = !int_pop_en;                                  // Invert the POP Polarity for the pipe_w_hs FIFO
assign xtlh_err_inj_halt       = halt_in;                                      // The halt to the upstream module is the coming signal from the down stream module
assign xtlh_err_inj_dv         = bypass_pipe ? dv : (int_send_ind && pipe_dv); // The output dv is the input one if there is bypass_pipe signal 
assign flit_type_str.flit_type = flit_type_str.err_inj_en ? flit_type : NOP;   // The Flit type will be the Actual Flit type as long as the err injection is enabled, else it will be NOP

//------------------------------------------\\
//----------- Design Assertions ------------\\
//------------------------------------------\\

endmodule
