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
// ---    $Revision: #10 $ 
// ---    $Author: lnicola $ 
// ---    $Id: //dwh/pcie_iip/main/fairbanks/design/Edmapf/DWC_pcie_edmapf_crgb.sv#10 $ 
// -------------------------------------------------------------------------
`include "include/DWC_pcie_ctl_all_defs.svh"
`include "Edmapf/DWC_pcie_edmapf_pkg.svh"
`include "Edmapf/svif/DWC_pcie_edmapf_crgb_if.svh"
`include "Edmapf/svif/DWC_pcie_edmapf_ram1p_if.svh"
`include "Edmapf/svif/DWC_pcie_edmapf_aclks_if.svh"
// SNPS_SysML_CODE_START
// SNPS_SysML_CODE_END

module DWC_pcie_edmapf_crgb
  import DWC_pcie_edmapf_pkg::*;
  #(
  // ##########################################################################
  //                             Parameters Declaration                        
  // ##########################################################################
   parameter         P_CRGB_ADDR_WD = `CC_CRGB_ADDR_WIDTH
  ,parameter         P_CRGB_DATA_WD = 32
  ,parameter          P_RAM_ADDR_WD = 5
  ,parameter          P_RAM_DATA_WD = 64
  ,parameter dmaEngType_e P_CHANNEL = E_WRITE
  ,parameter   hdmaRegZones_e P_RAM = E_HDMAREGZONE_GLOBAL
  ) (
  // ##########################################################################
  //                                Ports Declaration                          
  // ##########################################################################
   DWC_pcie_edmapf_aclks_if.slave_mp  b_clk
  ,DWC_pcie_edmapf_crgb_if.slave_mp   b_crgb
  ,DWC_pcie_edmapf_ram1p_if.master_mp b_ram
  );


// SNPS_SysML_CODE_START

  // ##########################################################################
  //  This module translates a CRGB read or write into into a memory like
  //  interface. The "RAM like" interface has the following sinals
  //  rdone - read done, indicates that the read data is valid and can be
  //          latched
  //  wdone - write done, indicates that the write data arrvied the end
  //          destination so the write can be considered complete
  //  This module is parameterizable to interface the following RAMS (as
  //  as defined ivn the following e_ramtypes:
  //  - E_RAM_LL       : Linked List RAM
  //  - E_NRAM_LLQ_GLB : Linked List Queue Global RAM
  //  - E_RAM_LLQ_OVRL : Linked List Queue Overlay RAM
  //  - E_RAM_MSI      : DMA Remote Message Signaled Interrupt
  // ##########################################################################

  ///////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
  // CRGB MAPPING
  ///////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

  typedef struct packed {
    logic [        P_RAM_ADDR_WD-1:0] addr       ; // ram addr
    logic                             valid      ; // crgb access valid
    logic [$clog2(P_RAM_DATA_WD)-1:0] startBit   ; // first LSB index of valid ram block
    logic [ $clog2(P_CRGB_DATA_WD):0] startRange ; // number of non-reserved LSB in the crgb map
    logic [ $clog2(P_CRGB_DATA_WD):0] endRange   ; // number of non-reserved MSB in the crgb map
  } crgbMap_s;

  crgbMap_s s_crgb;


  /*
  * Genarate case for each ram type
  */
  generate
    case (P_RAM)

      E_HDMAREGZONE_GLOBAL     : begin : GLOBAL_GEN
        always_comb begin : s_crgb_PROC
          if (b_crgb.w_address.chanType == P_CHANNEL) begin
            case (b_crgb.w_address.slot)
              E_HDMAREG_CONTROL1 : s_crgb = '{
                addr       : b_crgb.w_address.chanNumber[P_RAM_ADDR_WD-1:0]
                ,valid      : E_TRUE
                ,startBit   : 'd0
                ,startRange : 'd7
                ,endRange   : 'd11
              };
              E_HDMAREG_FUNC_NUM : s_crgb = '{
                addr       : b_crgb.w_address.chanNumber[P_RAM_ADDR_WD-1:0]
                ,valid      : E_TRUE
                ,startBit   : 'd18
                ,startRange : 'd8
                ,endRange   : 'd9
              };
              E_HDMAREG_QOS : s_crgb = '{
                addr       : b_crgb.w_address.chanNumber[P_RAM_ADDR_WD-1:0]
                ,valid      : E_TRUE
                ,startBit   : 'd35
                ,startRange : 'd8
                ,endRange   : 'd10
              };
              default       : s_crgb = '0;
            endcase
          end else begin
            s_crgb = '0;
          end
        end
      end

      E_HDMAREGZONE_DBMNGR     : begin : DBMNGR_GEN
        always_comb begin : s_crgb_PROC
          if (b_crgb.w_address.chanType == P_CHANNEL) begin
            case (b_crgb.w_address.slot)
              E_HDMAREG_DOORBELL : s_crgb = '{
                addr       : b_crgb.w_address.chanNumber[P_RAM_ADDR_WD-1:0]
                ,valid      : E_TRUE
                ,startBit   : 'd0
                ,startRange : 'd2
                ,endRange   : 'd0
              };
              E_HDMAREG_ELEM_PF : s_crgb = '{
                addr       : b_crgb.w_address.chanNumber[P_RAM_ADDR_WD-1:0]
                ,valid      : E_TRUE
                ,startBit   : 'd2
                ,startRange : 'd7
                ,endRange   : 'd0
              };
              default       : s_crgb = '0;
            endcase
          end else begin
            s_crgb = '0;
          end
        end
      end

      E_HDMAREGZONE_LL         : begin : LL_GEN
        always_comb begin : s_crgb_PROC
          if (b_crgb.w_address.chanType == P_CHANNEL) begin
            case (b_crgb.w_address.slot)
              E_HDMAREG_CYCLE: s_crgb = '{
                addr       : b_crgb.w_address.chanNumber[P_RAM_ADDR_WD-1:0]
                ,valid      : E_TRUE
                ,startBit   : 'd0
                ,startRange : 'd2
                ,endRange   : 'd0
              };
              E_HDMAREG_LLP_LOW : s_crgb = '{
                addr       : b_crgb.w_address.chanNumber[P_RAM_ADDR_WD-1:0]
                ,valid      : E_TRUE
                ,startBit   : 'd3
                ,startRange : 'd32
                ,endRange   : 'd0
              };
              E_HDMAREG_LLP_HIGH : s_crgb = '{
                addr       : b_crgb.w_address.chanNumber[P_RAM_ADDR_WD-1:0]
                ,valid      : E_TRUE
                ,startBit   : 'd35
                ,startRange : 'd32
                ,endRange   : 'd0
              };
              default       : s_crgb = '0;
            endcase
          end else begin
            s_crgb = '0;
          end
        end
      end

      E_HDMAREGZONE_OVERLAY    : begin : OVERLAY_GEN
        always_comb begin : s_crgb_PROC
          if (b_crgb.w_address.chanType == P_CHANNEL) begin
            case (b_crgb.w_address.slot)
              E_HDMAREG_XFERSIZE ,
              E_HDMAREG_SAR_LOW  ,
              E_HDMAREG_SAR_HIGH ,
              E_HDMAREG_DAR_LOW  ,
              E_HDMAREG_DAR_HIGH : s_crgb = '{
                addr       : b_crgb.w_address.chanNumber[P_RAM_ADDR_WD-1:0]
                ,valid      : E_TRUE
                ,startBit   : (b_crgb.w_address.slot - E_HDMAREG_XFERSIZE) * 'd8
                ,startRange : 'd32
                ,endRange   : 'd0
              };
              E_HDMAREG_WATERMARK_EN : s_crgb = '{
                addr       : b_crgb.w_address.chanNumber[P_RAM_ADDR_WD-1:0]
                ,valid      : E_TRUE
                ,startBit   : (b_crgb.w_address.slot - E_HDMAREG_XFERSIZE) * 'd8
                ,startRange : 'd2
                ,endRange   : 'd0
              };
              default       : s_crgb = '0;
            endcase
          end else begin
            s_crgb = '0;
          end
        end
      end

      E_HDMAREGZONE_HANDSHAKE  : begin : HANDSHAKE_GEN
        always_comb begin : s_crgb_PROC
          if (b_crgb.w_address.chanType == P_CHANNEL) begin
            case (b_crgb.w_address.slot)
              E_HDMAREG_HANDSHAKE : s_crgb = '{
                addr       : b_crgb.w_address.chanNumber[P_RAM_ADDR_WD-1:0]
                ,valid      : E_TRUE
                ,startBit   : 'd0
                ,startRange : 'd7
                ,endRange   : 'd0
              };
              default       : s_crgb = '0;
            endcase
          end else begin
            s_crgb = '0;
          end
        end
      end

      E_HDMAREGZONE_INTERRUPTS : begin : INTERRUPTS_GEN
        always_comb begin : s_crgb_PROC
          if (b_crgb.w_address.chanType == P_CHANNEL) begin
            case (b_crgb.w_address.slot)
              E_HDMAREG_EN          : s_crgb = '{
                addr       : b_crgb.w_address.chanNumber[P_RAM_ADDR_WD-1:0]
                ,valid      : E_TRUE
                ,startBit   : 'd0
                ,startRange : 'd1
                ,endRange   : 'd0
              };
              E_HDMAREG_STATUS      : s_crgb = '{
                addr       : b_crgb.w_address.chanNumber[P_RAM_ADDR_WD-1:0]
                ,valid      : E_TRUE
                ,startBit   : 'd1
                ,startRange : $bits(chStatus_e)
                ,endRange   : 'd0
              };
              E_HDMAREG_INT_CLEAR   : s_crgb = '{
                addr       : b_crgb.w_address.chanNumber[P_RAM_ADDR_WD-1:0]
                ,valid      : E_TRUE
                ,startBit   : 'd1 + $bits(chStatus_e)
                ,startRange : $bits(intTypes_s)
                ,endRange   : 'd0
              };
              E_HDMAREG_INT_SETUP   : s_crgb = '{
                addr       : b_crgb.w_address.chanNumber[P_RAM_ADDR_WD-1:0]
                ,valid      : E_TRUE
                ,startBit   : 'd1 + $bits(chStatus_e) + $bits(intTypes_s)
                ,startRange : $bits(intTypes_s) + 2*$bits(intEn_s)
                ,endRange   : 'd0
              };
              E_HDMAREG_INT_STATUS  : s_crgb = '{
                addr       : b_crgb.w_address.chanNumber[P_RAM_ADDR_WD-1:0]
                ,valid      : E_TRUE
                ,startBit   : 'd1 + $bits(chStatus_e) + 2*$bits(intTypes_s) + 2*$bits(intEn_s)
                ,startRange : $bits(intTypes_s) + $bits(dmaErrors_e)
                ,endRange   : 'd0
              };
              default       : s_crgb = '0;
            endcase
          end else begin
            s_crgb = '0;
          end
        end
      end

      E_HDMAREGZONE_MSI        : begin : MSI_GEN
        always_comb begin : s_crgb_PROC
          if (b_crgb.w_address.chanType == P_CHANNEL) begin
            case (b_crgb.w_address.slot)
              E_HDMAREG_MSI_ADDR_STOP_LOW       ,
              E_HDMAREG_MSI_ADDR_STOP_HIGH      ,
              E_HDMAREG_MSI_ADDR_WATERMARK_LOW  ,
              E_HDMAREG_MSI_ADDR_WATERMARK_HIGH ,
              E_HDMAREG_MSI_ADDR_ABORT_LOW      ,
              E_HDMAREG_MSI_ADDR_ABORT_HIGH     : s_crgb = '{
                addr       : b_crgb.w_address.chanNumber[P_RAM_ADDR_WD-1:0]
                ,valid      : E_TRUE
                ,startBit   : (b_crgb.w_address.slot - E_HDMAREG_MSI_ADDR_STOP_LOW) * 'd8
                ,startRange : 'd32
                ,endRange   : 'd0
              };
              E_HDMAREG_MSI_MSGD : s_crgb = '{
                addr       : b_crgb.w_address.chanNumber[P_RAM_ADDR_WD-1:0]
                ,valid      : E_TRUE
                ,startBit   : (b_crgb.w_address.slot - E_HDMAREG_MSI_ADDR_STOP_LOW) * 'd8
                ,startRange : 'd16
                ,endRange   : 'd0
              };
              default       : s_crgb = '0;
            endcase
          end else begin
            s_crgb = '0;
          end
        end
      end
      `ifndef SYNTHESIS
        //VCS coverage off
      default       : begin : P_RAM_INVALID_GEN initial $error("Invalid parameter: P_RAM"); end
        //VCS coverage on
      `endif //SYNTHESIS
    endcase
  endgenerate

  ///////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
  // CRGB FSM
  ///////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

  /*
  * crgb fsm states
  */
  typedef enum logic [1:0] {
     E_IDLE // waiting for crgb
    ,E_RD   // reading from ram
    ,E_WR   // writing to ram
  } crgbfsm_e;

  crgbfsm_e r_state;
  crgbfsm_e s_state;

  logic s_idle2rd ; // new crgb req, read from ram
  logic s_rd2wr   ; // rewrite ram
  logic s_wr2idle ; // ack crgb
  logic s_rd2idle ; // ack crgb

  /*
  * crgb fsm register
  */
  always_ff @(posedge b_clk.w_aux_clk, negedge b_clk.w_reset_n) begin : r_state_PROC
    if (!b_clk.w_reset_n) begin
      r_state <= #`TP E_IDLE;
    end else begin
      r_state <= #`TP s_state;
    end
  end : r_state_PROC

  /*
  * crgb fsm transition logic
  */
  assign s_idle2rd = (r_state == E_IDLE) && s_crgb.valid  && (b_crgb.w_wren || b_crgb.w_rden);
  assign s_rd2wr   = (r_state == E_RD  ) && b_ram.w_rdone &&  b_crgb.w_wren                  ;
  assign s_wr2idle = (r_state == E_WR  ) && b_ram.w_wdone                                    ;
  assign s_rd2idle = (r_state == E_RD  ) && b_ram.w_rdone &&  b_crgb.w_rden                  ;

  /*
  * crgb fsm next state logic
  */
  always_comb begin : s_state_PROC
    case (r_state)
      default: begin // E_IDLE
        if (s_idle2rd) begin
          s_state = E_RD;
        end else begin
          s_state = r_state;
        end
      end
      E_RD: begin
        if (s_rd2idle) begin
          s_state = E_IDLE;
        end else if (s_rd2wr) begin
          s_state = E_WR;
        end else begin
          s_state = r_state;
        end
      end
      E_WR: begin
        if (s_wr2idle) begin
          s_state = E_IDLE;
        end else begin
          s_state = r_state;
        end
      end
    endcase
  end : s_state_PROC

  ///////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
  // WR MAP PROCESS
  ///////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
  localparam L_DATA_WD_DIFF = P_RAM_DATA_WD - P_CRGB_DATA_WD;
  logic [$clog2(P_RAM_DATA_WD)-1:0] s_endBit            ;
  logic [ $clog2(P_CRGB_DATA_WD):0] s_endRemainder      ;

  logic [       P_CRGB_DATA_WD-1:0] r_crgbWrValid       ;
  logic [       P_CRGB_DATA_WD-1:0] s_crgbWrValid       ;
  logic [       P_CRGB_DATA_WD-1:0] r_crgbWrData        ;
  logic [       P_CRGB_DATA_WD-1:0] s_crgbWrData        ;

  logic [       P_CRGB_DATA_WD-1:0] s_crgbWrLSBMask     ;
  logic [       P_CRGB_DATA_WD-1:0] s_crgbWrMSBMask     ;
  logic [       P_CRGB_DATA_WD-1:0] s_crgbWrLSBValid    ;
  logic [       P_CRGB_DATA_WD-1:0] s_crgbWrMSBValid    ;
  logic [       P_CRGB_DATA_WD-1:0] s_crgbWrLSBData     ;
  logic [       P_CRGB_DATA_WD-1:0] s_crgbWrMSBData     ;

  logic [       P_CRGB_DATA_WD-1:0] s_crgbRdData        ;
  logic [        P_RAM_DATA_WD-1:0] s_ramRdLSBData      ;
  logic [        P_RAM_DATA_WD-1:0] s_ramRdMSBData      ;

  always_ff @(posedge b_clk.w_aux_clk, negedge b_clk.w_reset_n) begin : r_crgbWrValid_PROC
    if (!b_clk.w_reset_n) begin
      r_crgbWrValid <= #`TP '0;
    end else begin
      if (s_idle2rd) begin
        r_crgbWrValid <= #`TP s_crgbWrValid;
      end else begin
        r_crgbWrValid <= #`TP r_crgbWrValid;
      end
    end
  end : r_crgbWrValid_PROC

  always_ff @(posedge b_clk.w_aux_clk, negedge b_clk.w_reset_n) begin : r_crgbWrData_PROC
    if (!b_clk.w_reset_n) begin
      r_crgbWrData <= #`TP '0;
    end else begin
      if (s_idle2rd) begin
        r_crgbWrData <= #`TP s_crgbWrData;
      end else begin
        r_crgbWrData <= #`TP r_crgbWrData;
      end
    end
  end : r_crgbWrData_PROC

  // SMD: Identifies assignments in which the LHS width is less than the RHS width
  // SJ:  Overflow can never happen, checked by assertion: ap_rangeOverflow
  // spyglass disable_block W164a
  assign s_endBit = ($clog2(P_RAM_DATA_WD))'(s_crgb.startBit) + ($clog2(P_RAM_DATA_WD))'(s_crgb.startRange)              ;
  // spyglass enable_block W164a
  assign s_endRemainder         = P_CRGB_DATA_WD - s_crgb.endRange                                                       ;

  // 11111111 + 00010000 =       00001111
  assign s_crgbWrLSBMask        = {P_CRGB_DATA_WD{1'b1}} + ({{P_CRGB_DATA_WD{1'b0}},1'b1} << s_crgb.startRange)          ;
  assign s_crgbWrLSBValid       = b_crgb.w_wr_mask & s_crgbWrLSBMask                                                     ;
  assign s_crgbWrLSBData        = b_crgb.w_wr_data & s_crgbWrLSBMask                                                     ;

  assign s_crgbWrMSBMask        = {P_CRGB_DATA_WD{1'b1}} + ({{P_CRGB_DATA_WD{1'b0}},1'b1} << s_crgb.endRange)            ;
  assign s_crgbWrMSBValid       = (b_crgb.w_wr_mask >> 'd16) & s_crgbWrMSBMask                                           ;
  assign s_crgbWrMSBData        = (b_crgb.w_wr_data >> 'd16) & s_crgbWrMSBMask                                           ;

  assign s_crgbWrValid          = s_crgbWrLSBValid | (s_crgbWrMSBValid << s_crgb.startRange)                             ;
  assign s_crgbWrData           = s_crgbWrLSBData  | (s_crgbWrMSBData  << s_crgb.startRange)                             ;

  assign s_ramRdLSBData         = (b_ram.w_dout >> s_crgb.startBit) & {{L_DATA_WD_DIFF{1'b0}},s_crgbWrLSBMask}           ;
  assign s_ramRdMSBData         = ((b_ram.w_dout >> s_endBit) & {{L_DATA_WD_DIFF{1'b0}},s_crgbWrMSBMask}) << 'd16        ;
  assign s_crgbRdData           = s_ramRdLSBData[P_CRGB_DATA_WD-1:0] | s_ramRdMSBData[P_CRGB_DATA_WD-1:0]                ;

  ///////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
  // DATA OVERLAP
  ///////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

  logic [P_RAM_DATA_WD-1:0] s_ramData       ;
  logic [P_RAM_DATA_WD-1:0] r_ramData       ;
  logic                     r_ramDataValid  ;
  logic [P_RAM_DATA_WD-1:0] s_crgbData2ram  ;
  logic [P_RAM_DATA_WD-1:0] s_crgbValid2ram ;

  assign s_crgbData2ram  = {{P_RAM_DATA_WD-P_CRGB_DATA_WD{1'b0}}, r_crgbWrData } << s_crgb.startBit;
  assign s_crgbValid2ram = {{P_RAM_DATA_WD-P_CRGB_DATA_WD{1'b0}}, r_crgbWrValid} << s_crgb.startBit;

  always_comb begin : s_ramData_PROC
    foreach (s_ramData[i]) begin
      if (s_crgbValid2ram[i]) begin
        s_ramData[i] = s_crgbData2ram[i];
      end else begin
        s_ramData[i] = b_ram.w_dout[i];
      end
    end
  end : s_ramData_PROC

  always_ff @(posedge b_clk.w_aux_clk, negedge b_clk.w_reset_n) begin : r_ramData_PROC
    if (!b_clk.w_reset_n) begin
      r_ramData <= #`TP '0;
      r_ramDataValid <= #`TP '0;
    end else begin
      if (s_rd2wr) begin
        r_ramData <= #`TP s_ramData;
        r_ramDataValid <= #`TP '1;
      end else begin
        r_ramData <= #`TP r_ramData;
        r_ramDataValid <= #`TP '0;
      end
    end
  end : r_ramData_PROC

  ///////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
  // RAM & CRGB DRIVER
  ///////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

  assign b_ram.w_din             = r_ramData                                                                     ;
  assign b_ram.w_addr            = s_crgb.addr                                                                   ;
  assign b_ram.w_lock            = (r_state != E_IDLE) && b_crgb.w_wren                                          ;
  assign b_ram.w_wren            = r_ramDataValid                                                                ;
  assign b_ram.w_rden            = s_idle2rd                                                                     ;

  assign b_crgb.w_rd_data        = (b_crgb.w_ack && b_crgb.w_rden) ? s_crgbRdData : {P_CRGB_DATA_WD{1'b0}}       ;
  assign b_crgb.w_ack            = s_wr2idle || s_rd2idle                                                        ;

  ///////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
  // ASSERTIONS
  ///////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

// SNPS_SysML_CODE_END

endmodule
