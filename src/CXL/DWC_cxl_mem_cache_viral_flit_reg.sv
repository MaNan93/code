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

// -------------------------------------------------------------------------------------
// --- RCS information:
// ---   $DateTime: 2024/01/12 11:11:14 $
// ---   $Revision: #3 $
// ---   $Id: //dwh/pcie_iip/main/fairbanks/design/CXL/DWC_cxl_mem_cache_viral_flit_reg.sv#3 $
// -------------------------------------------------------------------------------------
// --- Module Description:
// -------------------------------------------------------------------------------------
// module viral_flit_reg stores current flit in a viral flit register. 
// If there is a viral condition during a payload flit then: 
// - xplh_viral (inside xplh_retry) will insert the viral control Inband flit and halt traffic upstream until retry is done
// - once halt from Arb/Mux is deasserted, viral_flit_reg will play flit0 from viral flit reg while halting upstream CM traffic 
// If there is a viral condition and no active payload flit then an viral inband flit is inserted directly
// -------------------------------------------------------------------------------------
`include "include/DWC_pcie_ctl_all_defs.svh"
`include "CXL/pkg/DWC_cxl_pkg.svh"

module DWC_cxl_mem_cache_viral_flit_reg
    import DWC_cxl_pkg::*;
#(
    parameter TP = `TP,
    parameter P_DW = 512,
    parameter P_DW_PROT = P_DW/8
) 
                                           (
  // -------------------------------------------------------------------------------------
  // Clock and Reset
  // -------------------------------------------------------------------------------------
  input                               core_clk,
  input                               core_rst_n,
  // -------------------------------------------------------------------------------------
  // CXL viral port signal between cxl controller and xplh
  // -------------------------------------------------------------------------------------
  input                               cxl_viral_req,                // cxl viral request pulse from cxl controller
  // input flit
  input                               halt_in,
  input                               flit_in_valid,
  input                               flit_in_last,
  input                               flit_in_inprogr,
  input [CXL_DATA_WD-1 : 0]           flit_in_data,
  input [CXL_DATA_PROT_WD-1:0]        flit_in_data_chk,
  // output flow control
  output logic                        vir_inprogress_o,             // active from eof of flit0 to inband_flit and resent flit0
  output logic                        halt_o,                       // halt upstream while viral flit reg is sent
  output logic                        flit_o_en,
  // output flit played from viral flit register
  output logic                        flit_o_valid,
  output logic                        flit_o_last,
  output logic                        flit_o_inprogr,
  output logic [CXL_DATA_WD-1 : 0]    flit_o_data,
  output logic [CXL_DATA_PROT_WD-1:0] flit_o_data_chk,
  output logic                        flit_o_err,                  // indicates to xplh_retrybuf to rewind wrptr
  output logic                        flit_o_pri                   // indicates priority setting
);

// Parameter may have to come from cxl.pkg, for now fixed here
localparam  P_FLIT_DW_CNT    = 2048/P_DW;
localparam  P_FLIT_DW_CNT_WD = $clog2(P_FLIT_DW_CNT);

// -------------------------------------------------------------------------------------
//  Logic Declarations
// -------------------------------------------------------------------------------------
// FSM
typedef enum logic [1:0] {
  S_VIR_IDLE,
  S_VIR_RESEND_FLIT0,
  S_VIR_INBAND
} state_e;

state_e                               next_state, state_r;
logic                                 cxl_viral_req_nxt, cxl_viral_req_r;
logic                                 viral_in_flit0_nxt, viral_in_flit0_r;
logic                                 cxl_viral_req_done;
logic                                 cxl_vir_flit0_last;
logic                                 start_vir_inband_flit;
logic                                 buf_flit_cnt_en;
logic [P_FLIT_DW_CNT_WD- 1 : 0]       int_dw_cnt_nxt, int_dw_cnt_r;
logic [2048-1:0]                      cxl_flit_data_buf_r;
logic [256-1:0]                       cxl_flit_data_chk_buf_r;
logic [2048-1:0]                      viral_inband_data;
logic [256-1:0]                       viral_inband_data_chk;
logic [(2048/P_DW)-1 : 0]             cxl_flit_inprogr_r;


// -------------------------------------------------------------------------------------
// internal assignments
// -------------------------------------------------------------------------------------
assign vir_inprogress_o   = flit_o_err || flit_o_valid;

// viral detected during a payload flit. At flit_in_last corrupt crc in cxl_mux_flit (flit_if) and start statemachine:
assign cxl_vir_flit0_last = !halt_in && cxl_viral_req_nxt && flit_in_valid && flit_in_last && (state_r==S_VIR_IDLE);

// viral detected but no active flit or cxl_cachemem empty flit then only send viral inband control flit
assign start_vir_inband_flit = !halt_in && cxl_viral_req_nxt && !flit_in_valid && (state_r==S_VIR_IDLE);

assign cxl_viral_req_done = !halt_in && flit_o_last && (viral_in_flit0_r? (state_r==S_VIR_RESEND_FLIT0) : (state_r==S_VIR_INBAND));

assign viral_inband_data = gen_cxl_viral_flit(16'd0);


// -------------------------------------------------------------------------------------
// latch single pulse viral request, to detect pulse anywhere in flit
// -------------------------------------------------------------------------------------
always_comb begin
  if (cxl_viral_req && !cxl_viral_req_r)
    cxl_viral_req_nxt = 1'b1;
  else if (cxl_viral_req_done)
    cxl_viral_req_nxt = 1'b0;
  else
    cxl_viral_req_nxt = cxl_viral_req_r;
end

// mark if viral is detected during payload flit0
always_comb begin
  if (cxl_vir_flit0_last)
     viral_in_flit0_nxt = 1'b1;
  else if (!halt_in && flit_o_last && (state_r==S_VIR_RESEND_FLIT0))
     viral_in_flit0_nxt = 1'b0;
  else 
     viral_in_flit0_nxt = viral_in_flit0_r;
end


// -------------------------------------------------------------------------------------
// CXL VIRAL FSM
// -------------------------------------------------------------------------------------
always_comb begin: viral_fsm_PROC
  next_state = state_r;
  case (state_r)
    S_VIR_INBAND : begin
      if (!halt_in && flit_o_last) begin
        if (viral_in_flit0_r)
          next_state = S_VIR_RESEND_FLIT0;
        else
          next_state = S_VIR_IDLE; 
      end  
    end
    S_VIR_RESEND_FLIT0 : begin
      if (!halt_in && flit_o_last) 
        next_state = S_VIR_IDLE; 
    end
    default: begin
      //if viral detected in payload flit || viral and no active flit
      if (cxl_vir_flit0_last || start_vir_inband_flit)
        next_state = S_VIR_INBAND;
    end
  endcase
end


always_comb begin : fsm_out_PROC
  case (state_r)
    S_VIR_INBAND : begin
      halt_o            = 1'b1;
      flit_o_valid      = 1'b1;
      flit_o_last       = (int_dw_cnt_r == P_FLIT_DW_CNT - 1);
      flit_o_inprogr   = |int_dw_cnt_r;
      flit_o_data       = viral_inband_data[int_dw_cnt_r*P_DW +: P_DW];
      flit_o_data_chk   = viral_inband_data_chk[int_dw_cnt_r*P_DW_PROT +: P_DW_PROT];
      //set this when marked for crc corruption, retrybuf will not add crc marker into retrybuf
      flit_o_err        = 1'b0;
      flit_o_pri        = 1'b1;
      flit_o_en         = 1'b1;
    end
    S_VIR_RESEND_FLIT0 : begin
      halt_o            = 1'b1;
      flit_o_valid      = 1'b1;
      flit_o_last       = (int_dw_cnt_r == P_FLIT_DW_CNT - 1);
      flit_o_inprogr    = cxl_flit_inprogr_r[int_dw_cnt_r];
      flit_o_data       = cxl_flit_data_buf_r[int_dw_cnt_r*P_DW +: P_DW];
      flit_o_data_chk   = cxl_flit_data_chk_buf_r[int_dw_cnt_r*P_DW_PROT +: P_DW_PROT];
      flit_o_err        = 1'b0;
      flit_o_pri        = 1'b1;
      flit_o_en         = 1'b1;
    end
    default: begin
      halt_o            = 1'b0;
      flit_o_valid      = 1'b0;
      flit_o_last       = 1'b0;
      flit_o_inprogr    = 1'b0;
      flit_o_data       = '0;
      flit_o_data_chk   = '0;
      flit_o_err        = cxl_vir_flit0_last; // used to rewind wrptr in retrybuf
      flit_o_pri        = cxl_vir_flit0_last;
      flit_o_en         = 1'b0;
    end
  endcase
end : fsm_out_PROC

// -------------------------------------------------------------------------------------
// Viral Inband RASDP Protection Generation
// -------------------------------------------------------------------------------------
ras_dp_pipe
 #(
    .PIPELINE_TYPE           ( 0                       ), // Pipeline Type: delay_n
    .N_STAGES                ( 0                       ), // No Pipeline
    .BUS_PROTECT_GEN_EN      ( 1                       ), // Bus Protect Genenator is enabled
    .BUS_PROTECT_CHK_EN      ( 0                       ), // Bus Protect Checker is not enabled
    .PROT_TYPE               ( CX_CXL_PROT_TYPE        ), // Protection type
    .PROT_RANGE              ( CX_CXL_PROT_RANGE       ), // Protection range
    .TOTAL_WIDTH             ( 2048                    ), // Data width: 2048
    .PROT_WD                 ( 256                     ), // Protection code width
    .PARITY_MODE             ( CX_CXL_PARITY_MODE      ), // Parity mode
    .PROT_CORRECT_EN         ( 0                       ), // Correction is enabled
    .RAS_DP_PROT_CHK_ID_BASE ( 0                       )  // Checker ID: N/A
) u_viral_inband_flit_ras_dp_pipe (
    .clk                       ( core_clk                              ),
    .rst_n                     ( core_rst_n                            ),
    .din                       ( viral_inband_data                     ),
    .din_prot                  ( '0                                    ),
    .dout                      ( /* Unused */                          ),
    .dout_prot                 ( viral_inband_data_chk                 ),
    .en                        ( 1'b1                                  ),
    .bypass                    ( 1'b0                                  ),
    .stall                     ( 1'b0                                  ),
    .stallout                  ( /* Unused */                          ),
    .valid_in                  ( 1'b0                                  ),
    .halt_out                  ( /* Unused */                          ),
    .valid_out                 ( /* Unused */                          ),
    .halt_in                   ( 1'b0                                  ),
    .ras_dp_err_inband_kbd_in  ( 1'b0                                  ),
    .ras_dp_err_inband_kbd_out ( /* Unused */                          ),
    .ras_dp_err_log            ( /* Unused */                          )
    ,
    .ras_dp_err_inj            ( '0                                    )
);

// -------------------------------------------------------------------------------------
// Flit DW Counter 
// -------------------------------------------------------------------------------------
assign buf_flit_cnt_en = (state_r== S_VIR_RESEND_FLIT0) || flit_in_valid || (state_r== S_VIR_INBAND);

always_comb begin
  if (!halt_in && buf_flit_cnt_en)
    int_dw_cnt_nxt = int_dw_cnt_r + 1'b1;
  else
    int_dw_cnt_nxt = int_dw_cnt_r;
end


// -------------------------------------------------------------------------------------
// clocked process
// -------------------------------------------------------------------------------------
always_ff @(posedge core_clk or negedge core_rst_n) begin
  if(!core_rst_n) begin
    state_r             <= #TP S_VIR_IDLE;
    int_dw_cnt_r        <= #TP '0;
    cxl_viral_req_r     <= #TP 1'b0;
    viral_in_flit0_r    <= #TP 1'b0;
    cxl_flit_data_buf_r <= #TP '0;
    cxl_flit_data_chk_buf_r <= #TP '0;
    cxl_flit_inprogr_r  <= #TP '0;
  end else begin
    state_r             <= #TP next_state;
    int_dw_cnt_r        <= #TP int_dw_cnt_nxt;
    cxl_viral_req_r     <= #TP cxl_viral_req_nxt;
    viral_in_flit0_r    <= #TP viral_in_flit0_nxt;
    if (state_r== S_VIR_IDLE) begin
      cxl_flit_data_buf_r[int_dw_cnt_r*P_DW +: P_DW] <= #TP flit_in_data[P_DW-1:0];  // viral flit register to buffer flit0
      cxl_flit_data_chk_buf_r[int_dw_cnt_r*P_DW_PROT +: P_DW_PROT] <= #TP flit_in_data_chk[P_DW_PROT-1:0];
      cxl_flit_inprogr_r[int_dw_cnt_r] <= #TP flit_in_inprogr;
    end  
  end
end

function automatic logic [2048 - 1 : 0] gen_cxl_viral_flit (input [15:0] cxl_viral_ldid);
// flit control
  gen_cxl_viral_flit[ 5: 0]    = 6'h0;          // placeholder lower 6 bits of flit_hdr
  gen_cxl_viral_flit[ 7: 6]    = 2'b10;         // cxl type in flit_hdr
  gen_cxl_viral_flit[15: 8]    = 8'h0;          // placeholder upper 8 bits of flit hdr
  gen_cxl_viral_flit[19:16]    = 4'b1000;       // H8 slot format
  gen_cxl_viral_flit[23:20]    = 4'b0011;       // LLCTRL=Inband_error
  gen_cxl_viral_flit[27:24]    = 4'b0000;       // subtype = viral
  gen_cxl_viral_flit[31:28]    = 4'b0000;       // Reserved
  gen_cxl_viral_flit[47:32]    = cxl_viral_ldid;  //16 bit payload
  gen_cxl_viral_flit[127:48]   = 80'h0;
  gen_cxl_viral_flit[2047:128] = {(2048-128){1'b0}};
  return gen_cxl_viral_flit;
endfunction


endmodule
