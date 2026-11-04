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
// ---    $Revision: #4 $
// ---    $Id: //dwh/pcie_iip/main/fairbanks/design/Layer1/rmlh_prbs_cmp.sv#4 $
// -------------------------------------------------------------------------
// --- Module Description: PRBS comparison
// -----------------------------------------------------------------------------

`include "include/DWC_pcie_ctl_all_defs.svh"
`include "products/DWC_pcie_core_pkg.svh"

 module rmlh_prbs_cmp 
#(
   parameter   NB      = `CX_NB   // Number of symbols (bytes) per clock cycle
  ,parameter   NBK     = `CX_NBK  // Number of symbols (bytes) per clock cycle for datak
  ,parameter   TP      = `TP      // Clock to Q delay (simulator insurance)
  ,parameter    AW      = `CX_ANB_WD               // Width of the active number of bytes

  ,parameter   RXSB_WD = `CX_MAC_SB_WD            //Width of phy_mac_rxstartblock per lane
  ,parameter   SH_WD   = `CX_MAC_SH_WD

)
(
// ---- inputs ---------------
   input                    core_clk
  ,input                    core_rst_n

  ,input    [2:0]           current_data_rate
  ,input                    smlh_lanes_active               // Which lanes are actively (begin) configured
  ,input                    ltssm_in_lpbk_active
  ,input                    ltssm_in_lpbk_active_pos
  ,input                    ltssm_in_lpbk_active_neg
  ,input                    lpbk_active
  ,input                    in_loopback
  ,input                    ltssm_lpbk_master
  ,input   [2:0]            active_nb                      // active number of symbols. bit0=1s, bit1=2s, bit2=4s, bit3=8s

  ,input                    prbs_en_int
  ,input                    clear_prbs_done
  ,input                    rpipe_rxdata_dv
  ,input  [(NB*8)-1:0]      rpipe_rxdata
  ,input  [NBK-1:0]         rpipe_rxdatak
  ,input                    wait4idle_nd
  ,input                    descrambled_rxdata_dv
  ,input  [(NB*8)-1:0]      descrambled_rxdata
  ,input  [NBK-1:0]         descrambled_rxdatak
  ,input  [RXSB_WD-1:0]     descrambled_rxstartblock
  ,input  [RXSB_WD-1:0][4:0] descrambled_rxdata_osfound

  ,output   logic   [7:0]   prbs_err_cntr

  ,output   logic           prbs_started
  ,output   logic           prbs_unexp_fail
  ,output   logic           wait4idle
);

logic               received_eios;

logic   [NB-1:0]    start_cmp;
logic   [NB-1:0]    rx_com;
logic   [NB-1:0]    rx_eios;
logic   [NB-1:0]    rx_crpt_data;
logic   [NB-1:0]    rx_skp_os;
logic   [NB-1:0]    rx_unexp_os;
logic               pre_dv_deasserted;
logic   [7:0]       dv_deasserted;
logic   [1:0]       pre_prbs_lpbk_rx_state;
logic   [1:0]       prbs_lpbk_rx_state;
logic   [NB-1:0]        start_cmp3;
logic   [SH_WD/2-1:0]   rx_eios3;
logic   [SH_WD/2-1:0]   rx_os3;
logic   [NB-1:0]        rx_crpt_data3;
logic   [1:0]           pre_prbs_lpbk_rx_state3;
logic   [1:0]           prbs_lpbk_rx_state3;
logic                   pre_dv_deasserted3;
logic   [7:0]           dv_deasserted3;

logic   [NB-1:0]    rx_ts1_com;
logic   [NB-1:0]    rx_ts1_pad;
logic   [NB-1:0]    rx_ts1_id;

localparam WAIT_PRBS_LPBK = 2'h0;
localparam WAIT_IDLE_DATA = 2'h1;
localparam CHK_RX_DATA = 2'h2;
localparam RCV_OS = 2'h3;

logic [NB-1:0]  pre_ts_rcvd;
logic [NB-1:0]  pre_com_rcvd;
logic           last_sym_com;

logic [4:0]   ts_cnt_start_val;
logic [4:0]   ts_cnt_start_val_p1;
assign ts_cnt_start_val = (active_nb[2])? 5'd3 : (active_nb[1])? 5'd7 : 5'd15;
assign ts_cnt_start_val_p1 = (active_nb[2])? 5'd4 : (active_nb[1])? 5'd8 : 5'd16;

always_comb begin
  integer j;
  for(j=0;j<NB;j=j+1)begin
    if( descrambled_rxdata_dv && (descrambled_rxdatak[j] == 1'b1 && descrambled_rxdata[j*8 +: 8] == `KCODE_8B_IDL) )begin
      rx_eios[j] = 1'b1;
    end else begin
      rx_eios[j] = 1'b0;
    end
  end
end

always_comb begin
  integer j;
  for(j=0;j<SH_WD/2;j=j+1)begin  // Waiting for idle data(syncheader=2'h2)
    if( descrambled_rxdata_dv && descrambled_rxdata[j*8 +: 8] == `EIOS_SYM_0 )begin  // 0x66 is EIOS identifier
    // EIOS
      rx_eios3[j] = 1'b1;
    end else begin
      rx_eios3[j] = 1'b0;
    end
  end
end

always_ff @(posedge core_clk, negedge core_rst_n) begin
  if( !core_rst_n )begin
    received_eios <= #TP 1'b0;
  end else begin
    if( !in_loopback )begin
      received_eios <=  #TP 1'b0;
    end else if( |rx_eios
      || |rx_eios3
    )begin
      received_eios <= #TP 1'b1;
    end
  end
end

always_comb begin
  integer i;
  if(current_data_rate <= 3'h1 && ltssm_in_lpbk_active && prbs_en_int && smlh_lanes_active)begin
    for(i=0;i<NB;i=i+1)begin
      if( rpipe_rxdata_dv && (rpipe_rxdatak[i] == 1'b1) && rpipe_rxdata[i*8 +: 8] == `KCODE_8B_COM)begin
        pre_com_rcvd[i] = 1'b1;
      end else begin
        pre_com_rcvd[i] = 1'b0;
      end
      if( ((i==0 && last_sym_com) || (i!=0 && pre_com_rcvd[i-1]) ) &&
         ( (rpipe_rxdata_dv && (rpipe_rxdatak[i] == 1'b1) && (rpipe_rxdata[i*8 +: 8] == `KCODE_8B_PAD) ) // COM->PAD
         || (rpipe_rxdata_dv && (rpipe_rxdatak[i] == 1'b0) ) )                                           // COM->not k-code
        )begin
        pre_ts_rcvd[i] = 1'b1;
      end else begin
        pre_ts_rcvd[i] = 1'b0;
      end
    end
  end else begin
    pre_com_rcvd = 0;
    pre_ts_rcvd = 0;
  end
end

always_ff @(posedge core_clk, negedge core_rst_n) begin
  if( !core_rst_n )begin
    last_sym_com <= #TP 1'b0;
  end else begin
    last_sym_com <= #TP pre_com_rcvd[NB-1];
  end
end

logic [4:0] ts_sym_cntr;
logic       wait4idle_d;

always_ff @(posedge core_clk, negedge core_rst_n) begin
  if( !core_rst_n )begin
    wait4idle_d <= #TP 1'b0;
  end else begin
    wait4idle_d <= #TP wait4idle;
  end
end

logic    ts_rcvd_in_lpbak_active;

always_comb begin
  if( !prbs_en_int || !ltssm_in_lpbk_active || (|pre_ts_rcvd) )begin
    wait4idle = 1'b0;
  end else if(ts_rcvd_in_lpbak_active && ts_sym_cntr==5'h0)begin
    wait4idle = 1'b1;
  end else begin
    wait4idle = wait4idle_d;
  end
end

always_ff @(posedge core_clk, negedge core_rst_n) begin
  if( !core_rst_n )begin
    ts_rcvd_in_lpbak_active <= #TP 1'b0;
  end else begin
    if( |pre_ts_rcvd )begin
      ts_rcvd_in_lpbak_active <= #TP 1'b1;
    end else if( ltssm_in_lpbk_active_neg )begin
      ts_rcvd_in_lpbak_active <= #TP 1'b0;
    end
  end
end

always_ff @(posedge core_clk, negedge core_rst_n) begin
  if( !core_rst_n )begin
    ts_sym_cntr <= #TP 5'h0;
  end else begin
// spyglass disable_block STARC05-2.11.3.1
// SMD: Combinational and sequential parts of an FSM described in same always block
// SJ: The rule reports a violation as the combinational and sequential parts of an FSM are described in same always block. In this code, the sequential and combinational parts of an FSM are separated. So, disable SpyGlass from reporting this error.
    if( pre_com_rcvd[0] || (last_sym_com && (|pre_ts_rcvd)) )begin  // "symbol0" or "last symbol of the data at a cycle" is COM
      ts_sym_cntr <= #TP ts_cnt_start_val;
    end else if( (|pre_com_rcvd) && (|pre_ts_rcvd) )begin // NB != 1, COM-PAD(or data) is detected at one cycle and the TS is not started from symbol0 of the data.
      ts_sym_cntr <= #TP ts_cnt_start_val_p1;
    end else if( last_sym_com && !(|pre_ts_rcvd))begin // OS, but not TS
      ts_sym_cntr <= #TP 5'h0;
    end else if( ts_sym_cntr != 5'h0 )begin
      ts_sym_cntr <= #TP ts_sym_cntr - 1'b1;
    end
// spyglass enable_block STARC05-2.11.3.1
  end
end

logic  compare_start;
assign compare_start = descrambled_rxdata_dv && (descrambled_rxdatak ==0) && (descrambled_rxdata==0) && wait4idle_nd;

logic               pre_idle_rcvd;
logic               pre_idle_rcvd3;
logic               idle_rcvd;

always_comb begin
  integer i,j;
  start_cmp = 0;
  rx_com = 0;
  rx_crpt_data =0;
  rx_skp_os =0;
  rx_unexp_os =0;
  pre_dv_deasserted = 1'b0;
  pre_idle_rcvd = 0;
  if(in_loopback && prbs_en_int && smlh_lanes_active && !received_eios)begin
    case(prbs_lpbk_rx_state)
      WAIT_PRBS_LPBK : begin
        rx_crpt_data =0;
        pre_dv_deasserted = 1'b0;
        pre_idle_rcvd = 0;
        if(ltssm_in_lpbk_active_pos && (current_data_rate == 3'h0 || current_data_rate == 3'h1))begin
          pre_prbs_lpbk_rx_state = WAIT_IDLE_DATA;
        end
        else begin
          pre_prbs_lpbk_rx_state = WAIT_PRBS_LPBK;
        end
      end
      WAIT_IDLE_DATA : begin  // LTSSM is in Loopback.active and then waiting receiving idle data(=0)
        rx_crpt_data =0;
        pre_dv_deasserted = 1'b0;
        pre_idle_rcvd = 0;
        if( compare_start )begin
          pre_prbs_lpbk_rx_state = CHK_RX_DATA;
        end else begin
          pre_prbs_lpbk_rx_state = WAIT_IDLE_DATA;
        end
      end
      CHK_RX_DATA : begin // Received idle data(=0) and checking if rxdata is not corrupted data :
        // When receiving OS or idle, then they are judged as "clean".
        // When other than above data, then they are judged as "corrupted".
        // Additionally, when rxdata_dv de-assert, it is judged as an "Unexpected error".
        rx_crpt_data =0;
        pre_dv_deasserted = 1'b0;
        start_cmp = 1'b0;
        for(i=0;i<NB;i=i+1)begin
          if( wait4idle_nd )begin
            if( !descrambled_rxdata_dv ||                                                                               // Data is not valid
               (descrambled_rxdata_dv && descrambled_rxdatak[i] == 1'b1                                                 // Receiving K code(OS)
            || (descrambled_rxdata_dv && descrambled_rxdatak[i] == 1'b0 && descrambled_rxdata[i*8 +: 8] == 8'h0)        // Receiving IDLE Data
           ) )begin
              rx_crpt_data[i] = 1'b0;
            end else begin
              rx_crpt_data[i] = 1'b1;
            end
          end else begin
            rx_crpt_data[i] = 1'b0;
          end
        end
        if( descrambled_rxdata_dv && (descrambled_rxdata == 0) )begin
          pre_idle_rcvd = 1'b1;
        end else begin
          pre_idle_rcvd = 1'b0;
        end
        if( !descrambled_rxdata_dv )begin
          pre_dv_deasserted = 1'b1;
        end else begin
          pre_dv_deasserted = 1'b0;
        end
        pre_prbs_lpbk_rx_state = CHK_RX_DATA;
        end
      default : begin
        rx_crpt_data =0;
        pre_dv_deasserted = 1'b0;
        pre_prbs_lpbk_rx_state = WAIT_PRBS_LPBK;
      end
    endcase
  end else begin // prbs_en_int = 0
    pre_prbs_lpbk_rx_state = WAIT_PRBS_LPBK;
  end
end


logic [SH_WD-1:0]       int_descrambled_rxdatak;

assign  int_descrambled_rxdatak = descrambled_rxdatak[SH_WD-1:0];

always_comb begin
  integer i,j;
  start_cmp3 = 0;
  rx_os3 = 0;
  rx_crpt_data3 = 0;
  pre_dv_deasserted3 = 1'b0;
  pre_idle_rcvd3 = 1'b0;
  if(in_loopback && prbs_en_int && smlh_lanes_active && !received_eios)begin
    case(prbs_lpbk_rx_state3)
      WAIT_PRBS_LPBK : begin
        start_cmp3 = 0;
        rx_os3 = 0;
        rx_crpt_data3 = 0;
        pre_dv_deasserted3 = 1'b0;
        pre_idle_rcvd3 = 1'b0;
        if(ltssm_in_lpbk_active_pos && (current_data_rate >= 3'h2) )begin
          pre_prbs_lpbk_rx_state3 = WAIT_IDLE_DATA;
        end else begin
          pre_prbs_lpbk_rx_state3 = WAIT_PRBS_LPBK;
        end
      end
      WAIT_IDLE_DATA : begin  // Waiting for Syncheader=2'h2
        rx_os3 = 0;
        rx_crpt_data3 = 0;
        pre_dv_deasserted3 = 1'b0;
        pre_idle_rcvd3 = 1'b0;
        for(i=0;i<SH_WD/2;i=i+1)begin  // Waiting for idle data(syncheader=2'h2)
          if( descrambled_rxdata_dv && (descrambled_rxstartblock[i] & int_descrambled_rxdatak[i*2 +:2] == `GEN3_2B_DATA_SYNC))begin
            start_cmp3[i] = 1'b1;
          end
          else begin
            start_cmp3[i] = 1'b0;
          end
        end
        if( |start_cmp3 )begin
          pre_prbs_lpbk_rx_state3 = CHK_RX_DATA;
        end
        else begin
          pre_prbs_lpbk_rx_state3 = WAIT_IDLE_DATA;
        end
      end
      CHK_RX_DATA : begin // Checking if receiving data is "clean=idle"
        start_cmp3 = 0;
        for(i=0;i<SH_WD/2;i=i+1)begin  // Waiting for idle data(syncheader=2'h2)
          if( descrambled_rxdata_dv && (descrambled_rxstartblock[i] & int_descrambled_rxdatak[i*2 +:2] == `GEN3_2B_OS_SYNC))begin
            rx_os3[i] = 1'b1;
          end else begin
            rx_os3[i] = 1'b0;
          end
        end
        if( descrambled_rxdata_dv && (descrambled_rxdata == 0) )begin
          pre_idle_rcvd3 = 1'b1;
        end else begin
          pre_idle_rcvd3 = 1'b0;
        end
        if( descrambled_rxdata_dv )begin
          pre_dv_deasserted3 = 1'b0;
        end else begin
          pre_dv_deasserted3 = 1'b1;
        end
        for(j=0;j<NB;j=j+1)begin  // Waiting for idle data(syncheader=2'h2)
          if( !descrambled_rxdata_dv ||
              (descrambled_rxdata[j*8 +: 8] == 8'h0 
           || (descrambled_rxdata[j*8 +: 8] == `GEN3_8B_SKP && (current_data_rate == 3'h2 || current_data_rate == 3'h3)) // 0xaa : SKP symbol in Gen3/4
           || (descrambled_rxdata[j*8 +: 8] == `CX_GEN5_SKP_ENC && (current_data_rate == 3'h4)) // 0x99 : SKP symbol in Gen5
           || ((descrambled_rxdata[j*8 +: 8] == `SKP_G6_S0 || descrambled_rxdata[j*8 +: 8] == `SKP_G6_S1) && (current_data_rate == 3'h5))
           || (descrambled_rxdata[j*8 +: 8] == `EIOS_SYM_0 && (current_data_rate >= 3'h2))  // 0x66 : IDLE
           ) )begin
            // 0xaa is SKP symbol in Gen3/4
            // 0x99 is SKP Symbol in Gen5 or higher
            rx_crpt_data3[j] = 1'b0;
          end else begin
            rx_crpt_data3[j] = 1'b1;
          end
        end

        if( |rx_os3 )begin
          pre_prbs_lpbk_rx_state3 = RCV_OS;
        end else begin
          pre_prbs_lpbk_rx_state3 = CHK_RX_DATA;
        end
      end
      RCV_OS : begin  // Receiving OS
        rx_os3 = 0;
        rx_crpt_data3 = 0;
        pre_idle_rcvd3 = 1'b0;
        if( descrambled_rxdata_dv )begin
          pre_dv_deasserted3 = 1'b0;
        end else begin
          pre_dv_deasserted3 = 1'b1;
        end
        for(i=0;i<SH_WD/2;i=i+1)begin  // Waiting for idle data(syncheader=2'h2)
          if( descrambled_rxdata_dv && (descrambled_rxstartblock[i] & int_descrambled_rxdatak[i*2 +:2] == `GEN3_2B_DATA_SYNC))begin
            start_cmp3[i] = 1'b1;
          end
          else begin
            start_cmp3[i] = 1'b0;
          end
        end
        if( |start_cmp3 )begin
          pre_prbs_lpbk_rx_state3 = CHK_RX_DATA;
        end else begin
          pre_prbs_lpbk_rx_state3 = RCV_OS;
        end
      end
      default : begin
        start_cmp3 = 0;
        rx_os3 = 0;
        rx_crpt_data3 = 0;
        pre_dv_deasserted3 = 1'b0;
        pre_idle_rcvd3 = 1'b0;
        pre_prbs_lpbk_rx_state3 = WAIT_PRBS_LPBK;
      end
    endcase
  end
  else begin
    pre_prbs_lpbk_rx_state3 = WAIT_PRBS_LPBK;
  end
end

// If data_dv deaaserts for 2 cycles

always_ff @(posedge core_clk, negedge core_rst_n) begin
  if( !core_rst_n )begin
    dv_deasserted3 <= #TP 8'h0;
  end else begin
    dv_deasserted3 <= #TP {dv_deasserted3[6:0],pre_dv_deasserted3};
  end
end

always_ff @(posedge core_clk, negedge core_rst_n) begin
  if( !core_rst_n )begin
    dv_deasserted <= #TP 8'h0;
  end else begin
    dv_deasserted <= #TP {dv_deasserted[6:0],pre_dv_deasserted};
  end
end

always_ff @(posedge core_clk, negedge core_rst_n) begin
  if( !core_rst_n )begin
    prbs_lpbk_rx_state <= #TP WAIT_PRBS_LPBK;
    prbs_lpbk_rx_state3 <= #TP WAIT_PRBS_LPBK;
  end
  else begin
    prbs_lpbk_rx_state <= #TP pre_prbs_lpbk_rx_state;
    prbs_lpbk_rx_state3 <= #TP pre_prbs_lpbk_rx_state3;
  end
end

always_ff @(posedge core_clk, negedge core_rst_n) begin
  if( !core_rst_n )begin
    prbs_unexp_fail <= #TP 1'b0;
  end else begin
    if( clear_prbs_done || ltssm_in_lpbk_active_pos )begin
      prbs_unexp_fail <= #TP 1'b0;
    end else if( 
    // Gen1/2
          dv_deasserted == 8'hff
       || (!in_loopback && (prbs_lpbk_rx_state == CHK_RX_DATA) )   // PRBS finished without receiving EIOS
    // Gen3-
       || dv_deasserted3 == 8'hff
       || ( !in_loopback && ((prbs_lpbk_rx_state3 == CHK_RX_DATA) || (prbs_lpbk_rx_state3 == RCV_OS)) ) // PRBS finished without receiving EIOS
    // Common
       || (smlh_lanes_active && prbs_en_int && !idle_rcvd && ltssm_in_lpbk_active_neg) // PRBS finished without receiving 0
      )begin
       prbs_unexp_fail <= #TP 1'b1;
    end
  end
end

always_ff @(posedge core_clk, negedge core_rst_n) begin
  if( !core_rst_n )begin
    prbs_err_cntr <= #TP 8'h0;
  end else begin
    if( clear_prbs_done || ltssm_in_lpbk_active_pos )begin
      prbs_err_cntr <= #TP 8'h0;
    end else if( ((current_data_rate==3'h0 || current_data_rate==3'h1) && |rx_crpt_data)
     || ((current_data_rate>=3'h2) && (|rx_crpt_data3 && !(|rx_os3)))
     )begin
// spyglass disable_block STARC05-2.11.3.1
// SMD: Combinational and sequential parts of an FSM described in same always block
// SJ: The rule reports a violation as the combinational and sequential parts of an FSM are described in same always block. In this code, the sequential and combinational parts of an FSM are separated. So, disable SpyGlass from reporting this error.
      if( prbs_err_cntr == 8'hff )begin
        prbs_err_cntr <= #TP 8'hff;
      end else begin
        prbs_err_cntr <= #TP prbs_err_cntr + 1'b1;
      end
// spyglass enable_block STARC05-2.11.3.1
    end
  end
end

always_ff @(posedge core_clk, negedge core_rst_n) begin
  if( !core_rst_n )begin
    prbs_started <= #TP 1'b0;
  end else begin
    if( clear_prbs_done || ltssm_in_lpbk_active_pos )begin
      prbs_started <= #TP 1'b0;
    end else if( lpbk_active && (
          (current_data_rate==3'h0 || current_data_rate==3'h1) && (pre_prbs_lpbk_rx_state ==CHK_RX_DATA && prbs_lpbk_rx_state==WAIT_IDLE_DATA) 
      || ((current_data_rate>=3'h2) && (pre_prbs_lpbk_rx_state3==CHK_RX_DATA && prbs_lpbk_rx_state3 ==WAIT_IDLE_DATA) )
    ) )begin
      prbs_started <= #TP 1'b1;
    end
  end
end

always_ff @(posedge core_clk, negedge core_rst_n) begin
  if( !core_rst_n )begin
    idle_rcvd <= #TP 1'b0;
  end else begin
    if( clear_prbs_done || ltssm_in_lpbk_active_pos )begin
      idle_rcvd <= #TP 1'b0;
    end else if(pre_idle_rcvd 
               || pre_idle_rcvd3
             )begin
      idle_rcvd <= #TP 1'b1;
    end
  end
end


endmodule
