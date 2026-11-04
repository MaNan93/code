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
// ---    $DateTime: 2024/01/03 02:06:32 $
// ---    $Revision: #14 $
// ---    $Id: //dwh/pcie_iip/main/fairbanks/design/Layer1/serdes_arch/serdes_pipe.sv#14 $
// --------------------------------------------------------------------------------------------
// --- Module Description: SerDes architecture top level module
// --------------------------------------------------------------------------------------------

`include "include/DWC_pcie_ctl_all_defs.svh"
`include "Layer1/serdes_arch/serdes_pipe_pkg.svh"
`include "products/DWC_pcie_core_pkg.svh"

module serdes_pipe

  import serdes_pipe_pkg::*;
  import DWC_pcie_core_pkg::ltssm_state_e;
  import DWC_pcie_core_pkg::S_POLL_COMPLIANCE;
  import DWC_pcie_core_pkg::S_RCVRY_LOCK;
  import DWC_pcie_core_pkg::S_RCVRY_EQ0;
  import DWC_pcie_core_pkg::S_RCVRY_EQ1;
  import DWC_pcie_core_pkg::S_RCVRY_EQ2;
  import DWC_pcie_core_pkg::S_RCVRY_EQ3;
  import DWC_pcie_core_pkg::S_L0;
  import DWC_pcie_core_pkg::S_LPBK_ENTRY;
  import DWC_pcie_core_pkg::S_LPBK_ACTIVE;
  import DWC_pcie_core_pkg::S_LPBK_EXIT;
  import DWC_pcie_core_pkg::S_LPBK_EXIT_TIMEOUT;
#(
  parameter int  NL   = `CX_NL,
  parameter int  INST = 0
) (
  // ------------- input -----------------
  input logic                                clk,
  input logic                                rst_n,
  input logic [NL-1:0]                       rx_clk,
  input logic [NL-1:0]                       rx_rst_n,
  input logic                                sync_hdr_bypass_en,
  input logic                                drift_buffer_en,
  input logic [NL-1:0]                       lanes_active,
  input logic                                drift_buffer_low_ptr_en,
  input logic                                drift_buffer_deskew_enable,
  input logic                                ltssm_in_lpbk_wo_l0,
  input logic [NL-1:0]                       ltssm_lanes_active,
  input ltssm_state_e                        ltssm_state,
  input logic [RATE_WD-1:0]                  pipe_rate,
  input logic [WIDTH_WD-1:0]                 pipe_width,
  input logic                                pipe_srisen,
  input logic                                flit_mode_enable,
  input logic [NL-1:0][SERDES_DATA_WD-1:0]   serdes_pipe_rxdata,
  input logic [NL-1:0]                       serdes_pipe_rxvalid,
  input logic [NL-1:0][2:0]                  serdes_pipe_rxstatus,
  input logic [NL-1:0][ORIG_DATA_WD-1:0]     orig_pipe_txdata,
  input logic [NL-1:0][PHY_NB-1:0]           orig_pipe_txdatak,
  input logic [NL-1:0]                       orig_pipe_txelecidle,
  input logic [NL-1:0]                       orig_pipe_txcompliance,
  input logic [NL-1:0]                       orig_pipe_txdetectrx_loopback,
  input logic [NL-1:0]                       orig_pipe_txdatavalid,
  input logic [NL-1:0][PHY_TXSB_WD-1:0]      orig_pipe_txstartblock,
  input logic [NL-1:0][PHY_TXSH_WD-1:0]      orig_pipe_txsyncheader,
  input logic [BAC_WD-1:0]                   orig_pipe_blockaligncontrol,
  input logic [NL-1:0]                       orig_pipe_rxpolarity,
  input logic                                orig_pipe_elasticbuffermode,
  // ------------- output ----------------
  output logic [NL-1:0][ORIG_DATA_WD-1:0]    orig_pipe_rxdata,
  output logic [NL-1:0][PHY_NB-1:0]          orig_pipe_rxdatak,
  output logic [NL-1:0]                      orig_pipe_rxvalid,
  output logic [NL-1:0]                      orig_pipe_rxdatavalid,
  output logic [NL-1:0][2:0]                 orig_pipe_rxstatus,
  output logic [NL-1:0]                      serdes_pipe_txdatavalid,
  output logic [NL-1:0][PHY_RXSB_WD-1:0]     orig_pipe_rxstartblock,
  output logic [NL-1:0][PHY_RXSH_WD-1:0]     orig_pipe_rxsyncheader,
  output logic [NL-1:0][PHY_RXSB_WD-1:0][4:0] orig_pipe_os_found,
  output logic [NL-1:0][7:0]                 drift_buffer_deskew_ptr,
  output logic [NL-1:0]                      orig_pipe_os_corrected,
  output logic [NL-1:0][SERDES_DATA_WD-1:0]  serdes_pipe_txdata,
  output logic [NL-1:0][PHY_TXEI_WD-1:0]     serdes_pipe_txelecidle,
  output logic [NL-1:0]                      serdes_pipe_txdetectrx_loopback,
  output logic [NL-1:0]                      serdes_pipe_rxready
);

// --------------------------------------------------------------------------------
//  Common control
// --------------------------------------------------------------------------------
  logic [NL-1:0][PHY_RXSB_WD-1:0]           orig_pipe_os_found_end;

  logic  loopback_state;
  assign loopback_state = (ltssm_state inside {
    S_LPBK_ENTRY, S_LPBK_ACTIVE, S_LPBK_EXIT, S_LPBK_EXIT_TIMEOUT});

  logic [RATE_WD-1:0]   pl_pipe_rate;
  logic [WIDTH_WD-1:0]  pl_pipe_width;
  logic                 pl_loopback_state;
  logic [NL-1:0]        pl_orig_pipe_txdetectrx_loopback;

  delay_n
   #(
    .N(0),
    .WD($bits({pipe_rate, pipe_width ,loopback_state, orig_pipe_txdetectrx_loopback}))
  ) u_delay_n (
    .clk(clk),
    .rst_n(rst_n),
    .clear(1'h0),
    .din({pipe_rate, pipe_width, loopback_state, orig_pipe_txdetectrx_loopback}),
    .dout({pl_pipe_rate, pl_pipe_width, pl_loopback_state, pl_orig_pipe_txdetectrx_loopback})
  );

  logic  encdec_8b10b;
  assign encdec_8b10b = (pl_pipe_rate inside {`GEN1_RATE, `GEN2_RATE});

// --------------------------------------------------------------------------------
//  Deskew control
// --------------------------------------------------------------------------------
   logic [NL-1:0]  lanes_deskew_en;

  always_comb begin: lanes_deskew_en_PROC
    logic  eq_state;
    eq_state = (ltssm_state inside {
               S_RCVRY_EQ0, S_RCVRY_EQ1, S_RCVRY_EQ2, S_RCVRY_EQ3});
    lanes_deskew_en = '0;
    if(drift_buffer_en && drift_buffer_deskew_enable) begin
      lanes_deskew_en = lanes_active;
    end
    if(eq_state) begin
      lanes_deskew_en = '0;
    end
  end

  logic [NL-1:0]  lanes_deskew_avail;
  logic [NL-1:0]  lanes_deskew_complete;
  logic [NL-1:0]  lanes_deskew_aligned;
  logic           all_lanes_deskew_avail;

  always_comb begin: all_lanes_deskew_avail_PROC
    all_lanes_deskew_avail = 1'h1;
    for(int i = 0; i < NL; i++) begin
      if(lanes_deskew_en[i]) begin
        all_lanes_deskew_avail &= lanes_deskew_avail[i];
      end
    end
  end

  always_comb begin: deskew_complete_PROC
    lanes_deskew_complete = '0;
    for(int i = 0; i < NL; i++) begin
      if(lanes_deskew_en[i]) begin
        lanes_deskew_complete[i] = all_lanes_deskew_avail;
      end
    end
  end

  logic [NL-1:0]  lanes_deskew_redo;
  logic [NL-1:0]  lanes_deskew_req;
  logic           not_all_lanes_deskew_req;
  logic [NL-1:0]  lanes_deskew_check_error;
  logic           deskew_check_rxdatavalid;
  logic [PHY_RXSB_WD-1:0] deskew_check_rxstartblock;

  // Check the drift buffer is correctly done. In the error case, the drift buffer deskew is performed again.
  // Select a reference lane from aligned lanes
  always_comb begin: deskew_check_rxpipe_PROC
    deskew_check_rxdatavalid = '0;
    deskew_check_rxstartblock = '0;
    for(int i = 0; i < NL; i++) begin
      if(lanes_deskew_en[i] && lanes_deskew_aligned[i]) begin
        deskew_check_rxdatavalid = orig_pipe_rxdatavalid[i]; 
        deskew_check_rxstartblock = orig_pipe_rxstartblock[i];
      end
    end
  end

  // Checked during deskew completion and blockaligncontrol=1
  generate
    for(genvar i = 0; i < NL; i++) begin: gen_lanes_deskew_check_error
      always_ff @(posedge clk or negedge rst_n) begin: lanes_deskew_check_error_PROC
        if (!rst_n) begin
          lanes_deskew_check_error[i] <= #`TP '0;
        end 
        else if(lanes_deskew_en[i] && lanes_deskew_aligned[i] && orig_pipe_blockaligncontrol[i]) begin
          lanes_deskew_check_error[i] <= #`TP deskew_check_rxdatavalid && (orig_pipe_rxstartblock[i] != deskew_check_rxstartblock);
        end
        else begin
          lanes_deskew_check_error[i] <= #`TP '0;
        end
      end
    end
  endgenerate

  always_comb begin: not_all_lanes_deskew_req_PROC
    logic  all_lanes_deskew_req;
    logic  all_lanes_not_deskew_req;
    all_lanes_deskew_req = 1'h1;
    all_lanes_not_deskew_req = 1'h1;
    for(int i = 0; i < NL; i++) begin
      if(lanes_deskew_en[i]) begin
        all_lanes_deskew_req &= lanes_deskew_req[i];
        all_lanes_not_deskew_req &= !lanes_deskew_req[i];
      end
    end
    not_all_lanes_deskew_req = !(all_lanes_deskew_req || all_lanes_not_deskew_req);
  end

  always_comb begin: lanes_deskew_redo_PROC
    lanes_deskew_redo = '0;
    for(int i = 0; i < NL; i++) begin
      if(lanes_deskew_en[i]) begin
        lanes_deskew_redo[i] = not_all_lanes_deskew_req || (|lanes_deskew_check_error);
      end
    end
  end

  logic  rcvry_lock_state;
  assign rcvry_lock_state = (ltssm_state inside {S_RCVRY_LOCK});

  logic  poll_compliance_state;
  assign poll_compliance_state = (ltssm_state inside {
    S_POLL_COMPLIANCE});

  logic [9:0]  skpos_interval_block_num;
  logic [9:0]  int_skpos_interval_block_num;

  assign int_skpos_interval_block_num = (ltssm_in_lpbk_wo_l0 && pipe_rate inside {`GEN6_RATE}) ? ((pipe_srisen) ? OS_INTVL_BLOCKS_X1__1b1b_SRIS : OS_INTVL_BLOCKS_X1__1b1b_CCLK) : 
                                                                                                 get_skpos_interval_block_num(ltssm_lanes_active, pipe_srisen, pipe_rate inside {`GEN6_RATE});

  function automatic logic [9:0]  get_skpos_interval_block_num (
    logic [NL-1:0]      lanes_active,
    logic               srisen,
    logic               enc_1b1b
  );
    logic [9:0]  ret;
    case({lanes_active, enc_1b1b})
 // CX_NL_GTR_8 // Common CLK , 128b130b , x16  ( 374 Flits = 374 Blocks )
       {{NL-8{1'b0}}, 8'hff, 1'b0}    : ret = OS_INTVL_BLOCKS_X8__128b130b_CCLK; // CX_NL_GTR_4 // Common CLK , 128b130b , x8   ( 187 Flits = 374 Blocks )
       {{NL-4{1'b0}}, 4'hf , 1'b0}    : ret = OS_INTVL_BLOCKS_X4__128b130b_CCLK; // CX_NL_GTR_2 // Common CLK , 128b130b , x4   (  93 Flits = 372 Blocks )
       {{NL-2{1'b0}}, 2'h3 , 1'b0}    : ret = OS_INTVL_BLOCKS_X2__128b130b_CCLK; // CX_NL_GTR_1 // Common CLK , 128b130b , x2   (  46 Flits = 368 Blocks )
                               {{NL-1{1'b0}}, 1'h1 , 1'b0}    : ret = OS_INTVL_BLOCKS_X1__128b130b_CCLK;                        // Common CLK , 128b130b , x1   (  23 Flits = 368 Blocks )
 // CX_NL_GTR_8    // Common CLK , 1b1b     , x16  ( 748 Flits = 748 Blocks )
       {{NL-8{1'b0}}, 8'hff, 1'b1}    : ret = OS_INTVL_BLOCKS_X8__1b1b_CCLK; // CX_NL_GTR_4    // Common CLK , 1b1b     , x8   ( 374 Flits = 748 Blocks )
       {{NL-4{1'b0}}, 4'hf , 1'b1}    : ret = OS_INTVL_BLOCKS_X4__1b1b_CCLK; // CX_NL_GTR_2    // Common CLK , 1b1b     , x4   ( 187 Flits = 748 Blocks )
       {{NL-2{1'b0}}, 2'h3 , 1'b1}    : ret = OS_INTVL_BLOCKS_X2__1b1b_CCLK; // CX_NL_GTR_1    // Common CLK , 1b1b     , x2   (  93 Flits = 744 Blocks )
                               {{NL-1{1'b0}}, 1'h1 , 1'b1}    : ret = OS_INTVL_BLOCKS_X1__1b1b_CCLK;                               // Common CLK , 1b1b     , x1   (  46 Flits = 736 Blocks )
      default: ret = OS_INTVL_BLOCKS_X1__1b1b_CCLK;                                                                                      // Common CLK , 1b1b     , x1   (  46 Flits = 736 Blocks )
    endcase
    if(srisen) begin
      case({lanes_active, enc_1b1b})
 // CX_NL_GTR_8 // SRIS       , 1b1b     , x16  (  74 Flits = 74 Blocks )
       {{NL-8{1'b0}}, 8'hff, 1'b1}    : ret = OS_INTVL_BLOCKS_X8__1b1b_SRIS; // CX_NL_GTR_4 // SRIS       , 1b1b     , x8   (  37 Flits = 74 Blocks )
       {{NL-4{1'b0}}, 4'hf , 1'b1}    : ret = OS_INTVL_BLOCKS_X4__1b1b_SRIS; // CX_NL_GTR_2 // SRIS       , 1b1b     , x4   (  18 Flits = 72 Blocks )
       {{NL-2{1'b0}}, 2'h3 , 1'b1}    : ret = OS_INTVL_BLOCKS_X2__1b1b_SRIS; // CX_NL_GTR_1 // SRIS       , 1b1b     , x2   (   9 Flits = 72 Blocks )
        default: ret = OS_INTVL_BLOCKS_X1__1b1b_SRIS;                                                                                   // SRIS       , 1b1b     , x1   (   4 Flits = 64 Blocks )
        // Not implemented {srisen,enc_1b1b} = {1,0}. Because this function is only used when 1b1b encoding or CXL Syncheader Bypass mode (i.e. common clock required) with flit_mode_enable = 1b.
      endcase
    end
    return ret;
  endfunction


  logic update_skpos_interval_valid;
  logic update_skpos_interval;
  logic l0_or_rcvry_lock_after_l0p;
  logic [9:0]    int_skpos_interval_block_num_l0p;
  logic [NL-1:0] lanes_active_for_l0p;
  logic [NL-1:0] eios_found, latched_eios_found_in_l0;
  logic [NL-1:0] sds_found, latched_sds_found_in_l0;
  logic [NL-1:0] eieos_found;
  logic [NL-1:0] in_datastream;
  logic [3:0]    tmp_cnt;
  logic          tmp_cnt_expired;


  always_ff @(posedge clk or negedge rst_n) begin: in_datastream_PROC
    if(!rst_n) begin
      in_datastream <= #`TP '0;
    end
    else begin
      for(int i = 0; i < NL; i++) begin
        if(!orig_pipe_rxvalid[i] || eios_found[i] || eieos_found[i]) begin
          in_datastream[i] <= #`TP '0;
        end
        if(sds_found[i]) begin
          in_datastream[i] <= #`TP '1;
        end
      end
    end
  end

  assign l0_or_rcvry_lock_after_l0p = (ltssm_state inside {S_L0}) || ((ltssm_state inside {S_RCVRY_LOCK}) && |in_datastream);
  assign tmp_cnt_expired = (tmp_cnt == 15);
  assign update_skpos_interval = tmp_cnt_expired && ((((!latched_eios_found_in_l0[0] && orig_pipe_rxvalid[0]) || (!latched_eios_found_in_l0[NL-1] && orig_pipe_rxvalid[NL-1])) 
                                                     && |latched_eios_found_in_l0)
                                                   || (((!latched_sds_found_in_l0[0] && orig_pipe_rxvalid[0]) || (!latched_sds_found_in_l0[NL-1] && orig_pipe_rxvalid[NL-1])) 
                                                     && |latched_sds_found_in_l0));
  assign int_skpos_interval_block_num_l0p = (update_skpos_interval) ? get_skpos_interval_block_num(lanes_active_for_l0p , pipe_srisen, pipe_rate inside {`GEN6_RATE}) : 0;

  always_comb begin: lanes_active_for_l0p_PROC
    lanes_active_for_l0p = '0;
    if(update_skpos_interval) begin
      if(orig_pipe_rxvalid[0]) begin
        lanes_active_for_l0p = orig_pipe_rxvalid;
      end
      else begin
        lanes_active_for_l0p = {<<{orig_pipe_rxvalid}};
      end
    end
  end

  always_ff @(posedge clk or negedge rst_n) begin: skpos_interval_block_num_PROC
    if(!rst_n) begin
      skpos_interval_block_num <= #`TP '0;
    end
    else if(!l0_or_rcvry_lock_after_l0p) begin
      skpos_interval_block_num <= #`TP int_skpos_interval_block_num;
    end
    else if(update_skpos_interval) begin
      skpos_interval_block_num <= #`TP int_skpos_interval_block_num_l0p;
    end
  end

  always_ff @(posedge clk or negedge rst_n) begin: update_skpos_interval_valid_PROC
    if(!rst_n) begin
      update_skpos_interval_valid <= #`TP '0;
    end
    else if(tmp_cnt_expired || !l0_or_rcvry_lock_after_l0p) begin
      update_skpos_interval_valid <= #`TP '0;
    end
    else if(|eios_found || |sds_found) begin
      update_skpos_interval_valid <= #`TP 1;
    end    
  end

  always_ff @(posedge clk or negedge rst_n) begin: tmp_cnt_PROC
    if(!rst_n) begin
      tmp_cnt <= #`TP '0;
    end
    else if(tmp_cnt_expired || !l0_or_rcvry_lock_after_l0p) begin
      tmp_cnt <= #`TP '0;
    end
    else if(update_skpos_interval_valid) begin
      tmp_cnt <= #`TP tmp_cnt + 1;
    end    
  end

  always_ff @(posedge clk or negedge rst_n) begin: latched_eios_found_in_l0_PROC
    if(!rst_n) begin
      latched_eios_found_in_l0 <= #`TP '0;
      latched_sds_found_in_l0  <= #`TP '0;
    end
    else if(tmp_cnt_expired || !l0_or_rcvry_lock_after_l0p) begin
      latched_eios_found_in_l0 <= #`TP '0;
      latched_sds_found_in_l0  <= #`TP '0;
    end
    else begin
      for(int i = 0; i < NL; i++) begin
        latched_eios_found_in_l0[i] <= #`TP (eios_found[i]) ? 1 : latched_eios_found_in_l0[i];
        latched_sds_found_in_l0[i]  <= #`TP (sds_found[i])  ? 1 : latched_sds_found_in_l0[i];
      end
    end    
  end

  always_comb begin: eios_found_PROC
    eios_found  = '0;
    eieos_found = '0;
    sds_found   = '0;
    for(int i = 0; i < NL; i++) begin // lane[i]
      for(int j = 0; j < PHY_RXSB_WD; j++) begin // startblock[j]
        // orig_pipe_os_found_end[i][j] is always 1 when it is in 1b1b
        eios_found[i]  = eios_found[i]  || (orig_pipe_os_found[i][j][OS_FOUND_EIOS]  && orig_pipe_os_found_end[i][j]);
        eieos_found[i] = eieos_found[i] || (orig_pipe_os_found[i][j][OS_FOUND_EIEOS] && orig_pipe_os_found_end[i][j]);
        sds_found[i]   = sds_found[i]   || (orig_pipe_os_found[i][j][OS_FOUND_SDS]   && orig_pipe_os_found_end[i][j]);
      end
    end
  end

// --------------------------------------------------------------------------------
//  SerDes PIPE lane
// --------------------------------------------------------------------------------
  generate
    for(genvar i = 0; i < NL; i++) begin: gen_serdes_pipe_lane
      serdes_pipe_lane
        u_serdes_pipe_lane (
        // ------------- input -----------------
        .clk(clk),
        .rst_n(rst_n),
        .rx_clk(rx_clk[i]),
        .rx_rst_n(rx_rst_n[i]),
        .sync_hdr_bypass_en(sync_hdr_bypass_en),
        .rcvry_lock_state(rcvry_lock_state),
        .drift_buffer_en(drift_buffer_en),
        .drift_buffer_low_ptr_en(drift_buffer_low_ptr_en),
        .deskew_en(lanes_deskew_en[i]),
        .deskew_complete(lanes_deskew_complete[i]),
        .deskew_redo(lanes_deskew_redo[i]),
        .deskew_ptr(drift_buffer_deskew_ptr[i]),
        .skpos_interval_block_num(skpos_interval_block_num),
        .poll_compliance_state(poll_compliance_state),
        .encdec_8b10b(encdec_8b10b),
        .loopback_state(pl_loopback_state),
        .pipe_rate(pl_pipe_rate),
        .pipe_width(pl_pipe_width),
        .pipe_srisen(pipe_srisen),
        .flit_mode_enable(flit_mode_enable),
        .serdes_pipe_rxdata(serdes_pipe_rxdata[i]),
        .serdes_pipe_rxvalid(serdes_pipe_rxvalid[i]),
        .serdes_pipe_rxstatus(serdes_pipe_rxstatus[i]),
        .orig_pipe_txdata(orig_pipe_txdata[i]),
        .orig_pipe_txdatak(orig_pipe_txdatak[i]),
        .orig_pipe_txelecidle(orig_pipe_txelecidle[i]),
        .orig_pipe_txcompliance(orig_pipe_txcompliance[i]),
        .orig_pipe_txdetectrx_loopback(pl_orig_pipe_txdetectrx_loopback[i]),
        .orig_pipe_txdatavalid(orig_pipe_txdatavalid[i]),
        .orig_pipe_txstartblock(orig_pipe_txstartblock[i][0]),
        .orig_pipe_txsyncheader(orig_pipe_txsyncheader[i][1:0]),
        .orig_pipe_blockaligncontrol(orig_pipe_blockaligncontrol[i]),
        .orig_pipe_rxpolarity(orig_pipe_rxpolarity[i]),
        .orig_pipe_elasticbuffermode(orig_pipe_elasticbuffermode),
        // ------------- output ----------------
        .deskew_avail(lanes_deskew_avail[i]),
        .deskew_req(lanes_deskew_req[i]),
        .deskew_aligned(lanes_deskew_aligned[i]),
        .os_corrected(orig_pipe_os_corrected[i]),
        .orig_pipe_rxdata(orig_pipe_rxdata[i]),
        .orig_pipe_rxdatak(orig_pipe_rxdatak[i]),
        .orig_pipe_rxvalid(orig_pipe_rxvalid[i]),
        .orig_pipe_rxdatavalid(orig_pipe_rxdatavalid[i]),
        .orig_pipe_rxstatus(orig_pipe_rxstatus[i]),
        .serdes_pipe_txdatavalid(serdes_pipe_txdatavalid[i]),
        .orig_pipe_rxstartblock(orig_pipe_rxstartblock[i]),
        .orig_pipe_rxsyncheader(orig_pipe_rxsyncheader[i]),
        .orig_pipe_os_found(orig_pipe_os_found[i]),
        .orig_pipe_os_found_end(orig_pipe_os_found_end[i]),
        .serdes_pipe_txdata(serdes_pipe_txdata[i]),
        .serdes_pipe_txelecidle(serdes_pipe_txelecidle[i]),
        .serdes_pipe_txdetectrx(serdes_pipe_txdetectrx_loopback[i]),
        .serdes_pipe_rxready(serdes_pipe_rxready[i])
      );
    end
  endgenerate


endmodule: serdes_pipe
