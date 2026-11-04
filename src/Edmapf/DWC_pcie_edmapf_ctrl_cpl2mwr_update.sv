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
// ---    $Revision: #14 $ 
// ---    $Author: lnicola $ 
// ---    $Id: //dwh/pcie_iip/main/fairbanks/design/Edmapf/DWC_pcie_edmapf_ctrl_cpl2mwr_update.sv#14 $ 
// -------------------------------------------------------------------------
`include "include/DWC_pcie_ctl_all_defs.svh"
`include "Edmapf/DWC_pcie_edmapf_pkg.svh"
`include "Edmapf/DWC_pcie_edmapf_rasdp_pkg.svh"
`include "Edmapf/DWC_pcie_tlp_pkg.svh"
`include "Edmapf/svif/DWC_pcie_edmapf_cdmregs_if.svh"
`include "Edmapf/svif/DWC_pcie_edmapf_aclks_if.svh"
`include "Edmapf/svif/DWC_pcie_edmapf_tlp_if.svh"
// SNPS_SysML_CODE_START
// SNPS_SysML_CODE_END

module DWC_pcie_edmapf_ctrl_cpl2mwr_update
  import DWC_pcie_edmapf_pkg::*;
  import DWC_pcie_edmapf_rasdp_pkg::*;
  import DWC_pcie_tlp_pkg::*;
  #(
  // ##########################################################################
  //                             Parameters Declaration                        
  // ##########################################################################
   parameter                 P_CHAN = 8
  ,parameter dmaEngType_e P_CHANNEL = E_WRITE
  ) (
  // ##########################################################################
  //                                Ports Declaration                          
  // ##########################################################################
   DWC_pcie_edmapf_cdmregs_if.slave_mp b_cdm
  ,DWC_pcie_edmapf_aclks_if.slave_mp   b_clk
  ,DWC_pcie_edmapf_tlp_if.master_mp    b_future
  ,DWC_pcie_edmapf_tlp_if.slave_mp     b_in
  ,DWC_pcie_edmapf_tlp_if.master_mp    b_out
  ,DWC_pcie_edmapf_tlp_if.slave_mp     b_present
  );


// SNPS_SysML_CODE_START
  localparam L_DATAWD = 32*K_NW;
  localparam L_SHIFT = $clog2(L_DATAWD/8);
  localparam L_PAR_RST = `CX_RASDP == 1 ? 3'b000 : 3'b111;
  
  localparam L_NW_LOG = $clog2(K_NW);
  

  enum logic [1:0] {
    E_CTRL_CURRENT     = 2'd0,
    E_CTRL_DELAYED     = 2'd1,
    E_CTRL_ANTECIPATED = 2'd2
  } r_shiftControler;

  enum logic [1:0] {
    E_DATA_CURRENT     = 2'd0,
    E_DATA_DELAYED     = 2'd1,
    E_DATA_ANTECIPATED = 2'd2
  } s_shiftData, r_shiftData;

  logic  [1:0] s_bytesShifting;
  logic  [1:0] r_bytesShifting;

  logic [31:0] s_tlp_payload_size_nxt;

  logic  [3:0] s_first_be;
  logic  [3:0] s_last_be;
  logic [12:0] s_nxt_byte_len;
  logic [12:0] s_nxt_byte_len_rd;
  logic [10:0] s_nxt_dw_len;
  logic [10:0] s_coreCyclesRd;
  logic [10:0] s_coreCyclesWr;

  logic [K_NW-1:0] s_dwen;
  logic [9:0]      s_remainder;
  logic [9:0]      r_dw_len;
  

  logic                 [2:0]  r_dataPar;

  logic [23:0] r_pastData;

  
  logic        r_eot_d;
  logic        r_dv_d;
  logic        s_eot;
  logic        s_dv;
  logic        s_halt;
  logic        r_filter;
  logic        s_ctrlDelayed;
  logic        s_ctrlAntecipated;
  dmaErrors_e  s_outErrors;
  logic        s_tokenOrFlag;
  
  /*
    Conecting b_in port with b_future port
  */
  always_comb begin : c_futureData_PROC
    b_future.w_data       = b_in.w_data    ;
    b_future.w_header     = b_in.w_header  ;
    b_future.w_hv         = b_in.w_hv      ;
    b_in.w_halt           = b_future.w_halt;
    b_future.w_dv         = b_in.w_dv      ;
    b_future.w_eot        = b_in.w_eot     ;
    b_future.w_headerProt = b_in.w_headerProt;
  end : c_futureData_PROC
  
  assign s_tokenOrFlag =  b_present.w_header.ctx.ctx.ovrl.token |  b_present.w_header.ctx.ctx.ovrl.stop;

  assign s_tlp_payload_size_nxt = s_tokenOrFlag ? '0 : // In case of a token issue a null read
                                  dma_fetch_tlp_calc_size
                                  (
                                   .WRITE_CH_NOT_READ_CH(P_CHANNEL == E_WRITE),

                                   .cfg_max_payload_size(b_cdm.w_cfg_max_payload_size),
                                   .cfg_max_rd_req_size(b_cdm.w_cfg_max_rd_req_size),
                                   .cfg_remote_rd_req_bridge_size(b_cdm.w_cfg_remote_rd_req_bridge_size),

                                   .pf(b_present.w_header.ctx.ctx.glb.tlpSettings.d_pf),
                                   .ctrl_ch_dar_ptr({b_present.w_header.ctx.ctx.ovrl.ovrlData.darHigh, b_present.w_header.ctx.ctx.ovrl.ovrlData.darLow}),
                                   .ctrl_ch_sar_ptr({b_present.w_header.ctx.ctx.ovrl.ovrlData.sarHigh, b_present.w_header.ctx.ctx.ovrl.ovrlData.sarLow}),
                                   .ctrl_ch_xfersize(b_present.w_header.ctx.ctx.ovrl.ovrlData.xferSize)
                                  );

  /*
    Calculating the byte enables and DW length
  */
  always_comb begin : c_calcTlpFields_PROC

    {s_last_be, s_first_be} = dma_byte_enables(
                                                .addressLow(b_present.w_header.ctx.ctx.ovrl.ovrlData.darLow)
                                                ,.payloadSize(s_tlp_payload_size_nxt)
                                              );

    s_nxt_byte_len = 13'(s_tlp_payload_size_nxt[12:0] + {10'd0, b_present.w_header.ctx.ctx.ovrl.ovrlData.darLow[1:0]});

    s_nxt_dw_len = s_tlp_payload_size_nxt == '0 ? 11'd1 : //Zero transfer size transports 1 null DW in PCIe
                   {1'b0, s_nxt_byte_len[11:2]} +
                   {10'd0, |s_nxt_byte_len[1:0]};

    s_nxt_byte_len_rd = 13'(s_tlp_payload_size_nxt[12:0] + {10'd0, b_present.w_header.ctx.ctx.ovrl.ovrlData.sarLow[1:0]});

  end : c_calcTlpFields_PROC

  /*
    Delayed version of dw_len
  */
  always_ff @(posedge b_clk.w_main_clk, negedge b_clk.w_reset_n) begin : s_dwen_Delayed_PROC
    if (!b_clk.w_reset_n) begin
      r_dw_len <= #`TP '0;
    end else if (!b_present.w_halt) begin
      if(b_out.w_hv) begin
        r_dw_len <= #`TP s_nxt_dw_len[9:0];
      end
    end
  end : s_dwen_Delayed_PROC

  /*
    Calculating dwen value
  */
  always_comb begin : c_calcDwen_PROC
    s_dwen = 'b0;
    if(s_eot) begin
      if(b_out.w_hv) begin
        s_remainder = s_nxt_dw_len[9:0];
      end else begin
        s_remainder = r_dw_len[9:0];
      end 
      s_remainder[9:L_NW_LOG] = '0;
      if(s_remainder == 0) begin
        s_dwen = '1;
      end else begin 
        for(int i = 0; i < K_NW; i++) begin
          if(i < s_remainder) begin
            s_dwen[i] = 1'b1;
          end else begin
            s_dwen[i] = 1'b0;
          end 
        end
      end
    end else begin
      s_dwen      = '1;
      s_remainder = '0;
    end      
  end : c_calcDwen_PROC  
  
  /*
    Number of cycles to send the MRd or MWr
  */
  always_comb begin : c_s_coreCyclesRd_PROC
    s_coreCyclesRd = (11)'(s_nxt_byte_len_rd[12: L_SHIFT] + |s_nxt_byte_len_rd[L_SHIFT-1:0]);
    s_coreCyclesWr = (11)'(s_nxt_byte_len[12: L_SHIFT] + |s_nxt_byte_len[L_SHIFT-1:0]);
  end : c_s_coreCyclesRd_PROC
  
  /*
    Creating a delayed version of eot
  */
  always_ff @(posedge b_clk.w_main_clk, negedge b_clk.w_reset_n) begin : s_controlSignalsDelayed_PROC
    if (!b_clk.w_reset_n) begin
      r_eot_d  <= #`TP '0;
      r_dv_d   <= #`TP '0;
    end else if (!b_out.w_halt) begin
      r_eot_d  <= #`TP b_present.w_eot;
      r_dv_d   <= #`TP b_present.w_dv;
    end
  end : s_controlSignalsDelayed_PROC
  
  /*
    Filtering a wrong eot and dv
  */
  always_ff @(posedge b_clk.w_main_clk, negedge b_clk.w_reset_n) begin : s_filterCtrl_PROC
    if (!b_clk.w_reset_n) begin
      r_filter   <= #`TP '1;
    end else if (!b_out.w_halt) begin
      if((r_shiftControler == E_CTRL_ANTECIPATED) || ((r_shiftControler == E_CTRL_CURRENT) && (s_ctrlAntecipated))) begin
        r_filter <= #`TP !b_out.w_eot;
      end else begin
        r_filter <= #`TP '1;
      end
    end
  end : s_filterCtrl_PROC
  
  /*
    Catching the error field of TLP which are being sent
  */
  always_comb begin : c_outErrors_PROC
    s_outErrors = b_out.w_header.ctx.ctx.ovrl.errors;
  end : c_outErrors_PROC
  
  /*
    Preserving the decision until the end of transmission
  */
  always_ff @(posedge b_clk.w_main_clk, negedge b_clk.w_reset_n) begin : s_shiftControler_PROC
    if (!b_clk.w_reset_n) begin
      r_shiftControler <= #`TP E_CTRL_CURRENT;
    end else if(!b_out.w_halt) begin
      if(b_out.w_eot) begin
        r_shiftControler <= #`TP E_CTRL_CURRENT;
      end else if(b_out.w_hv && (s_outErrors == E_DMAERR_NONE)) begin
        if (s_coreCyclesWr == s_coreCyclesRd) begin
          r_shiftControler <= #`TP E_CTRL_CURRENT;
        end else if (s_coreCyclesWr > s_coreCyclesRd) begin
          r_shiftControler <= #`TP E_CTRL_DELAYED;
        end else begin
          r_shiftControler <= #`TP E_CTRL_ANTECIPATED;
        end
      end
    end
  end : s_shiftControler_PROC
  
  /*
    Control delay detected
  */
  always_comb begin : c_ctrlDelayed_PROC
    s_ctrlDelayed = (s_coreCyclesWr > s_coreCyclesRd) && b_out.w_hv && (s_outErrors == E_DMAERR_NONE);
  end : c_ctrlDelayed_PROC
  
  /*
    Control delay detected
  */
  always_comb begin : c_ctrlAntecipated_PROC
    s_ctrlAntecipated = (s_coreCyclesWr < s_coreCyclesRd) && b_out.w_hv && (s_outErrors == E_DMAERR_NONE) && (s_coreCyclesWr == 'd1);
  end : c_ctrlAntecipated_PROC
  
  /*
    Generating new control signals
  */
  always_comb begin : c_controlSignals_PROC
    case(r_shiftControler)
      E_CTRL_DELAYED:
        begin
          s_dv   = r_dv_d;
          s_eot  = r_eot_d;
          s_halt = b_out.w_halt || r_eot_d;
        end
      E_CTRL_ANTECIPATED:
        begin
          s_dv   = b_in.w_dv;
          s_eot  = b_in.w_eot;
          s_halt = b_out.w_halt;
        end
      default: // E_CTRL_CURRENT
        begin
          s_dv   = (b_present.w_dv && r_filter) || s_ctrlAntecipated;
          s_eot  = (b_present.w_eot && r_filter && !s_ctrlDelayed) || s_ctrlAntecipated;
          s_halt = b_out.w_halt;
        end
    endcase
  end : c_controlSignals_PROC
  
  /*
    Storing the number of bytes to shift
  */
  always_ff @(posedge b_clk.w_main_clk, negedge b_clk.w_reset_n) begin : s_bytesShifting_PROC
    if (!b_clk.w_reset_n) begin
      r_bytesShifting <= #`TP '0;
    end else if (!b_out.w_halt) begin
      if(b_out.w_hv && (s_outErrors == E_DMAERR_NONE))
        case(s_shiftData)
          E_DATA_CURRENT    : r_bytesShifting <= #`TP '0;
          E_DATA_DELAYED    : r_bytesShifting <= #`TP 2'(b_present.w_header.ctx.ctx.ovrl.ovrlData.darLow[1:0] - b_present.w_header.ctx.ctx.ovrl.ovrlData.sarLow[1:0]);
          E_DATA_ANTECIPATED: r_bytesShifting <= #`TP 2'(b_present.w_header.ctx.ctx.ovrl.ovrlData.sarLow[1:0] - b_present.w_header.ctx.ctx.ovrl.ovrlData.darLow[1:0]);
        endcase
    end
  end : s_bytesShifting_PROC
  
  /*
    Calculating the number of bytes to shift
  */
  always_comb begin : c_s_bytesShifting_PROC
    if(b_out.w_hv && (s_outErrors == E_DMAERR_NONE)) begin
      case(s_shiftData)
        E_DATA_DELAYED              : s_bytesShifting = 2'(b_present.w_header.ctx.ctx.ovrl.ovrlData.darLow[1:0] - b_present.w_header.ctx.ctx.ovrl.ovrlData.sarLow[1:0]);
        E_DATA_ANTECIPATED          : s_bytesShifting = 2'(b_present.w_header.ctx.ctx.ovrl.ovrlData.sarLow[1:0] - b_present.w_header.ctx.ctx.ovrl.ovrlData.darLow[1:0]);
        default /* E_DATA_CURRENT */: s_bytesShifting = '0;
      endcase
    end else begin
      s_bytesShifting = r_bytesShifting;
    end
  end : c_s_bytesShifting_PROC
  
  /*
    Indicating if the data need to be anticipated or delayed
  */
  always_comb begin : c_shiftData_PROC
    if(b_out.w_hv) begin
      if (b_present.w_header.ctx.ctx.ovrl.ovrlData.darLow[1:0] == b_present.w_header.ctx.ctx.ovrl.ovrlData.sarLow[1:0]) begin
        s_shiftData = E_DATA_CURRENT;
      end else if (b_present.w_header.ctx.ctx.ovrl.ovrlData.darLow[1:0] > b_present.w_header.ctx.ctx.ovrl.ovrlData.sarLow[1:0]) begin
        s_shiftData = E_DATA_DELAYED;
      end else begin
        s_shiftData = E_DATA_ANTECIPATED;
      end
    end else begin
      s_shiftData = r_shiftData;
    end
  end : c_shiftData_PROC
  
  /*
    Preserving the decision until the end of transmission
  */
  always_ff @(posedge b_clk.w_main_clk, negedge b_clk.w_reset_n) begin : s_shiftData_PROC
    if (!b_clk.w_reset_n) begin
      r_shiftData <= #`TP E_DATA_CURRENT;
    end else if (!b_out.w_halt) begin 
      if(b_out.w_eot) begin
        r_shiftData <= #`TP E_DATA_CURRENT;
      end else if(!b_out.w_halt) begin
        r_shiftData <= #`TP s_shiftData;
      end
    end
  end : s_shiftData_PROC
  
  /*
    Storing last 3 bytes of present data
  */
  always_ff @(posedge b_clk.w_main_clk, negedge b_clk.w_reset_n) begin : s_pastData_PROC
    if (!b_clk.w_reset_n) begin
      r_pastData <= #`TP '0;
    end else if(!b_out.w_halt) begin
      if(b_out.w_eot) begin
        r_pastData <= #`TP '0;
      end else if(b_out.w_dv) begin
        r_pastData <= #`TP b_present.w_data[L_DATAWD-1:L_DATAWD-24];
      end
    end
  end : s_pastData_PROC
  
  /*
    Storing last 3 bits of present data paraty bits
  */
  always_ff @(posedge b_clk.w_main_clk, negedge b_clk.w_reset_n) begin : s_dataPar_PROC
    if (!b_clk.w_reset_n) begin
      r_dataPar <= #`TP L_PAR_RST;
    end else if(!b_out.w_halt) begin
      if(b_out.w_eot) begin
        r_dataPar <= #`TP L_PAR_RST;
      end else if(b_out.w_dv) begin
        r_dataPar <= #`TP b_present.w_data[K_COREBUSWD-1:K_COREBUSWD-3];
      end
    end
  end : s_dataPar_PROC
  
  /*
    Aligning properly the data
  */
  always_comb begin : c_dataAligner_PROC
    if (s_shiftData == E_DATA_CURRENT) begin
      b_out.w_data = b_present.w_data;
    end else if (s_shiftData == E_DATA_DELAYED) begin
      if(b_out.w_eot && (s_ctrlDelayed || (r_shiftControler == E_CTRL_DELAYED))) begin
        case(s_bytesShifting)
          2'd1:
            begin
              b_out.w_data[K_COREBUSWD-1:L_DATAWD] = {{K_COREBUSWD-L_DATAWD-1{L_PAR_RST[0]}},  r_dataPar[2] };
              b_out.w_data[L_DATAWD-1:0]           = {(L_DATAWD-8)'(0),  r_pastData[23:16]};
            end
          2'd2:
            begin
              b_out.w_data[K_COREBUSWD-1:L_DATAWD] = {{K_COREBUSWD-L_DATAWD-2{L_PAR_RST[0]}},  r_dataPar[2:1]};
              b_out.w_data[L_DATAWD-1:0]           = {(L_DATAWD-16)'(0), r_pastData[23:8]};
            end
          default: // 2'd3
            begin
              b_out.w_data[K_COREBUSWD-1:L_DATAWD] = {{K_COREBUSWD-L_DATAWD-3{L_PAR_RST[0]}},  r_dataPar[2:0]};
              b_out.w_data[L_DATAWD-1:0]           = {(L_DATAWD-24)'(0), r_pastData[23:0]};
            end
        endcase
      end else begin
        case(s_bytesShifting)
          2'd1:
            begin
              b_out.w_data[K_COREBUSWD-1:L_DATAWD] = {b_present.w_data[K_COREBUSWD-2:L_DATAWD],  r_dataPar[2] };
              b_out.w_data[L_DATAWD-1:0]           = {b_present.w_data[L_DATAWD-9:0],  r_pastData[23:16]};
            end
          2'd2:
            begin
              b_out.w_data[K_COREBUSWD-1:L_DATAWD] = {b_present.w_data[K_COREBUSWD-3:L_DATAWD],  r_dataPar[2:1]};
              b_out.w_data[L_DATAWD-1:0]           = {b_present.w_data[L_DATAWD-17:0], r_pastData[23:8]};
            end
          default: // 2'd3
            begin
              b_out.w_data[K_COREBUSWD-1:L_DATAWD] = {b_present.w_data[K_COREBUSWD-4:L_DATAWD],  r_dataPar[2:0]};
              b_out.w_data[L_DATAWD-1:0]           = {b_present.w_data[L_DATAWD-25:0], r_pastData[23:0]};
            end
        endcase
      end
    end else begin
      if(b_out.w_eot && !(s_ctrlAntecipated || (r_shiftControler == E_CTRL_ANTECIPATED))) begin
        case(s_bytesShifting)
          2'd1:
            begin
              b_out.w_data[K_COREBUSWD-1:L_DATAWD] = {L_PAR_RST[0],   b_present.w_data[K_COREBUSWD-1:L_DATAWD+1]};
              b_out.w_data[L_DATAWD-1:0]           = {8'd0,  b_present.w_data[L_DATAWD-1:8] };
            end
          2'd2:
            begin
              b_out.w_data[K_COREBUSWD-1:L_DATAWD] = {L_PAR_RST[1:0], b_present.w_data[K_COREBUSWD-1:L_DATAWD+2]};
              b_out.w_data[L_DATAWD-1:0]           = {16'd0, b_present.w_data[L_DATAWD-1:16]};
            end
          default: // 2'd3
            begin
              b_out.w_data[K_COREBUSWD-1:L_DATAWD] = {L_PAR_RST[2:0], b_present.w_data[K_COREBUSWD-1:L_DATAWD+3]};
              b_out.w_data[L_DATAWD-1:0]           = {24'd0, b_present.w_data[L_DATAWD-1:24]};
            end
        endcase
      end else begin
        case(s_bytesShifting)
          2'd1:
            begin
              b_out.w_data[K_COREBUSWD-1:L_DATAWD] = {b_future.w_data[L_DATAWD],             b_present.w_data[K_COREBUSWD-1:L_DATAWD+1]};
              b_out.w_data[L_DATAWD-1:0]           = {b_future.w_data[7:0],  b_present.w_data[L_DATAWD-1:8] };
            end
          2'd2:
            begin
              b_out.w_data[K_COREBUSWD-1:L_DATAWD] = {b_future.w_data[L_DATAWD+1: L_DATAWD], b_present.w_data[K_COREBUSWD-1:L_DATAWD+2]};
              b_out.w_data[L_DATAWD-1:0]           = {b_future.w_data[15:0], b_present.w_data[L_DATAWD-1:16]};
            end
          default: // 2'd3
            begin
              b_out.w_data[K_COREBUSWD-1:L_DATAWD] = {b_future.w_data[L_DATAWD+2: L_DATAWD], b_present.w_data[K_COREBUSWD-1:L_DATAWD+3]};
              b_out.w_data[L_DATAWD-1:0]           = {b_future.w_data[23:0], b_present.w_data[L_DATAWD-1:24]};
            end
        endcase
      end
    end
  end : c_dataAligner_PROC
  
  /*
    Driving the correct signals to generate the MWr
  */
  always_comb begin : c_drivingMwr_PROC
    b_out.w_hv                                           = b_present.w_hv && (r_shiftControler != E_CTRL_DELAYED);
    b_out.w_dv                                           = s_dv; //b_present.w_dv ;
    b_out.w_eot                                          = s_eot; //b_present.w_eot;
    b_out.w_header                                       = b_present.w_header;
    b_out.w_headerProt                                   = '0;
    b_out.w_header.header.common1.pcieTag                = '0;
    b_out.w_header.header.common1.vfunc_num              = b_present.w_header.ctx.ctx.glb.tlpSettings.d_vf[K_VFWD-2:0];
    b_out.w_header.header.common1.vfunc_active           = b_present.w_header.ctx.ctx.glb.tlpSettings.d_vf_en;
    b_out.w_header.header.common1.tc                     = b_present.w_header.ctx.ctx.glb.tlpSettings.d_tc;
    b_out.w_header.header.common1.pfunc_num [K_PFWD-1:0] = b_present.w_header.ctx.ctx.glb.tlpSettings.d_pf[K_PFWD-1:0];
    b_out.w_header.header.common1.attr                   = '{default    : '0
                                                            ,snoop      : b_present.w_header.ctx.ctx.glb.tlpSettings.d_sn
                                                            ,relaxOrder : (P_CHANNEL == E_READ) ? 1'b0 : b_present.w_header.ctx.ctx.glb.tlpSettings.d_ro
                                                            };
    b_out.w_header.header.common2.fmt                    = |b_present.w_header.ctx.ctx.ovrl.ovrlData.darHigh ? 2'b11 : 2'b10;
    b_out.w_header.header.common2.typ                    = 5'd0;
    b_out.w_header.header.common2.tph_th                 = b_present.w_header.ctx.ctx.glb.tlpSettings.d_th;
    b_out.w_header.header.common2.tph_st                 = b_present.w_header.ctx.ctx.glb.tlpSettings.d_st;
    b_out.w_header.header.common2.tph_ph                 = b_present.w_header.ctx.ctx.glb.tlpSettings.d_ph;
    b_out.w_header.header.common2.prfx                   = K_PRFXDEFAULT;
    if (s_tokenOrFlag) begin
      b_out.w_header.header.common4.req_id               = '0;
      b_out.w_header.header.common2.last_be              = 4'b0000;
      b_out.w_header.header.common2.first_be             = 4'b0000;
      b_out.w_header.header.common2.dw_len               = 10'b00_0000_0001;
    end else begin
      b_out.w_header.header.common4.req_id               = b_present.w_header.header.common2.cmpltr_id;
      b_out.w_header.header.common2.last_be              = s_last_be;
      b_out.w_header.header.common2.first_be             = s_first_be;
      b_out.w_header.header.common2.dw_len               = s_nxt_dw_len[9:0];
    end
    b_out.w_header.header.common2.cpl_status             = '0;
    b_out.w_header.header.common2.cmpltr_id              = '0;
    b_out.w_header.header.common2.byte_cnt               = '0;
    b_out.w_header.header.common2.ats                    = P_CHANNEL == E_READ ? '0 : b_present.w_header.ctx.ctx.glb.tlpSettings.d_ats;
    b_out.w_header.header.common2.addr                   = {b_present.w_header.ctx.ctx.ovrl.ovrlData.darHigh, b_present.w_header.ctx.ctx.ovrl.ovrlData.darLow[31:2], 2'd0};
    b_out.w_header.header.common4.dwen                   = s_dwen;
    b_out.w_header.header.radmPort.mem_type              = b_present.w_header.ctx.ctx.glb.tlpSettings.mtype         ;
    b_out.w_header.header.xadmPort.addr_align_en         = '0;
    b_out.w_header.header.xadmPort.atu_bypass            = '1;
    
    if (!s_tokenOrFlag) begin
      case (b_present.w_header.header.common2.cpl_status)
        E_CPL_STATUS_SC : b_out.w_header.ctx.ctx.ovrl.errors = E_DMAERR_NONE             ;
        E_CPL_STATUS_UR : b_out.w_header.ctx.ctx.ovrl.errors = E_DMAERR_DATA_CPL_UR      ;
        E_CPL_STATUS_CA : b_out.w_header.ctx.ctx.ovrl.errors = E_DMAERR_DATA_CPL_CA      ;
        default         : b_out.w_header.ctx.ctx.ovrl.errors = E_DMAERR_DATA_CPL_TIMEOUT ;
      endcase
      if (b_present.w_header.header.common2.poisoned && b_present.w_header.header.common2.cpl_status == E_CPL_STATUS_SC)
        b_out.w_header.ctx.ctx.ovrl.errors = E_DMAERR_DATA_CPL_EP;
    end
  end : c_drivingMwr_PROC
  
   /*
     Feeding halt from outcome to the previous register
   */
   always_comb begin : c_feedingHaltSignal_PROC
     b_present.w_halt = s_halt;
   end : c_feedingHaltSignal_PROC
  
  
// SNPS_SysML_CODE_END

endmodule
