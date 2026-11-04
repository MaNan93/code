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
// ---    $DateTime: 2021/10/29 02:04:56 $
// ---    $Revision: #4 $
// ---    $Id: //dwh/pcie_iip/main/fairbanks/design/common/lcrc_einj.sv#4 $
// -------------------------------------------------------------------------
// --- Module Description: 
// --- LCRC/ECRC error injection
// -----------------------------------------------------------------------------

`include "include/DWC_pcie_ctl_all_defs.svh"

 
 module lcrc_einj
#(
    parameter TP = `TP,
    parameter CRC_MODE = `CX_XDLH,  // select appropriate functionality depending on where this module is instantiated
    parameter NW = `CX_NW,          // Number of 32-bit dwords handled by the datapath each clock.
    parameter RX_TLP_EINJ = (NW>=8) ? 2 : 1, // Number of TLPs that can be processed in this block in a single cycle (Max=2)
    parameter DW = (32*NW)          // Width of datapath in bits.
)
(
    input                   clk,
    input                   rst_n,
    input                   enable_in,
    input   [DW-1:0]        data_in,
    input   [NW-1:0]        sot_in,
    input   [NW-1:0]        eot_in,
    input   [NW-1:0]        edb_in,
    input                   cdm_ras_des_einj0_enable,
    input   [3:0]           cdm_ras_des_einj0_crc_type,
    input   [7:0]           cdm_ras_des_einj0_count,

    output  [DW-1:0]        data_out,
    output reg [2:0]        lcrc_einj_evt
);

    parameter [3:0]         CRC_TYPE  = (CRC_MODE==`CX_RDLH) ? 4'b1000 : 4'b1011 ;
    parameter               LMT_RXTLP = `CX_RAS_DES_LMT_RXTLP ;
    parameter               MAX_NW    = 16 ; // Supporting Max Number of 32-bit dwords handled by the datapath each clock.

    reg                     tlp_td_status;
    reg     [NW-1:0]        int_einj_evt ;
    wire    [NW-1:0]        last_eot;
    wire    [NW-1:0]        current_td;
    wire                    start_tlp_idle;
    wire                    int_cdm_ras_des_einj0_enable;

    wire    [NW-1:0]        find_pkt[0:3] ;

    wire    [MAX_NW-1:0]    max_valid_sot_in ; // Supporting max NW = 16DW
    wire    [NW-1:0]        valid_sot_in ;
    wire    [NW-1:0]        valid_eot_in ;
    wire    [NW-1:0]        valid_edb_in ;
    genvar                  ii ;

    assign valid_sot_in = {NW{enable_in}} & sot_in ;
    assign valid_eot_in = {NW{enable_in}} & eot_in ;
    assign valid_edb_in = {NW{enable_in}} & edb_in ;

    // Put 0's into unused field
    generate
      for ( ii=0 ; ii<MAX_NW ; ii=ii+1 ) begin : gen_max_valid_sot_in_for
        if (ii<NW) begin : gen_max_valid_sot_in_if
          assign max_valid_sot_in[ii] = valid_sot_in[ii];
        end else begin : gen_max_valid_sot_in_else
          assign max_valid_sot_in[ii] = 1'b0;
        end
      end
    endgenerate

    generate
      for ( ii=0 ; ii<NW ; ii=ii+1 ) begin : gen_current_td_last_eot_for
        if ( CRC_MODE==`CX_RDLH ) begin : gen_current_td_if
          assign current_td[ii] = 1'b1 ; // LCRC error check has no relation with td bit
        end else begin : gen_current_td_else
          assign current_td[ii] = data_in[32*ii+23] ; // sot with TD bit(ECRC) / td bit must be set to 1 to check ECRC
        end

        // last eot status, not find new sot
        if (ii==NW-1) begin : gen_last_eot_if
          assign last_eot[ii] = (valid_eot_in[ii] | valid_edb_in[ii]) ;
        end else begin : gen_last_eot_else
          assign last_eot[ii] = (valid_eot_in[ii] | valid_edb_in[ii]) & (|valid_sot_in[ii+1 +: NW-ii-1]==1'b0) ;
        end
      end
    endgenerate

    // Received the end of TLPs and start to receive idle data
    assign start_tlp_idle  = |last_eot ;

    // The current status if TLP with TD=1 was receiving
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            tlp_td_status <= #TP 1'b0 ;
        end
        else begin
            if ( start_tlp_idle ) begin
                tlp_td_status <= #TP 1'b0 ;
            end else begin
                casez ( max_valid_sot_in )
                    // Bit width at far-left should be same with MAX_NW.
                    16'b0000_0000_0000_0001 : tlp_td_status <= #TP current_td[0] ;
                    16'b0000_0000_0000_001? : tlp_td_status <= #TP current_td[1] ;
                    16'b0000_0000_0000_01?? : tlp_td_status <= #TP current_td[2] ;
                    16'b0000_0000_0000_1??? : tlp_td_status <= #TP current_td[3] ;
                    16'b0000_0000_0001_???? : tlp_td_status <= #TP current_td[4] ;
                    16'b0000_0000_001?_???? : tlp_td_status <= #TP current_td[5] ;
                    16'b0000_0000_01??_???? : tlp_td_status <= #TP current_td[6] ;
                    16'b0000_0000_1???_???? : tlp_td_status <= #TP current_td[7] ;
                    16'b0000_0001_????_???? : tlp_td_status <= #TP current_td[8] ;
                    16'b0000_001?_????_???? : tlp_td_status <= #TP current_td[9] ;
                    16'b0000_01??_????_???? : tlp_td_status <= #TP current_td[10] ;
                    16'b0000_1???_????_???? : tlp_td_status <= #TP current_td[11] ;
                    16'b0001_????_????_???? : tlp_td_status <= #TP current_td[12] ;
                    16'b001?_????_????_???? : tlp_td_status <= #TP current_td[13] ;
                    16'b01??_????_????_???? : tlp_td_status <= #TP current_td[14] ;
                    16'b1???_????_????_???? : tlp_td_status <= #TP current_td[15] ;
                    default                 : tlp_td_status <= #TP tlp_td_status ;
                endcase
            end
        end
    end

    generate
        for (ii=0 ; ii<4 ; ii=ii+1 ) begin : gen_find_pkt_for
            if ( ii<RX_TLP_EINJ ) begin : gen_find_pkt_if
              assign find_pkt[ii] = next_pkt_finder ( ii, valid_sot_in, valid_eot_in, tlp_td_status, current_td ) ;
            end else begin : gen_find_pkt_else
              assign find_pkt[ii] = {NW{1'b0}} ;
            end
        end
    endgenerate

    generate
       if ( (LMT_RXTLP==1) && (RX_TLP_EINJ>1) ) begin : gen_einj_en_if
           assign int_cdm_ras_des_einj0_enable = 1'b0 ;
       end else begin : gen_einj_en_else
           assign int_cdm_ras_des_einj0_enable = cdm_ras_des_einj0_enable ;
       end
    endgenerate

    always @( * ) begin
        if ( int_cdm_ras_des_einj0_enable && (cdm_ras_des_einj0_crc_type==CRC_TYPE) ) begin
            if ( cdm_ras_des_einj0_count==8'd1 ) begin
                int_einj_evt = find_pkt[0] ;
                if ( |find_pkt[0] ) lcrc_einj_evt = 3'd1 ;
                else                lcrc_einj_evt = 3'd0 ;
            end else if ( cdm_ras_des_einj0_count==8'd2 ) begin
                int_einj_evt = find_pkt[0] | find_pkt[1] ;
                if      ( |find_pkt[1] ) lcrc_einj_evt = 3'd2 ;
                else if ( |find_pkt[0] ) lcrc_einj_evt = 3'd1 ;
                else                     lcrc_einj_evt = 3'd0 ;
            end else if ( cdm_ras_des_einj0_count==8'd3 ) begin
                int_einj_evt = find_pkt[0] | find_pkt[1] | find_pkt[2];
                if      ( |find_pkt[2] ) lcrc_einj_evt = 3'd3 ;
                else if ( |find_pkt[1] ) lcrc_einj_evt = 3'd2 ;
                else if ( |find_pkt[0] ) lcrc_einj_evt = 3'd1 ;
                else                     lcrc_einj_evt = 3'd0 ;
            end else if ( cdm_ras_des_einj0_count>=8'd4 || cdm_ras_des_einj0_count==8'd0 ) begin
                int_einj_evt = find_pkt[0] | find_pkt[1] | find_pkt[2] | find_pkt[3] ;
                if      ( |find_pkt[3] ) lcrc_einj_evt = 3'd4 ;
                else if ( |find_pkt[2] ) lcrc_einj_evt = 3'd3 ;
                else if ( |find_pkt[1] ) lcrc_einj_evt = 3'd2 ;
                else if ( |find_pkt[0] ) lcrc_einj_evt = 3'd1 ;
                else                     lcrc_einj_evt = 3'd0 ;
            end else begin
                int_einj_evt = {NW{1'b0}} ;
                lcrc_einj_evt = 3'd0 ;
            end
        end else begin
            int_einj_evt = {NW{1'b0}} ;
            lcrc_einj_evt = 3'd0 ;
        end
    end

    generate
    for ( ii=0 ; ii<NW ; ii=ii+1 ) begin : gen_data_out
        // CRC Data corruption
        assign data_out[32*ii +: 32] = int_einj_evt[ii] ? {data_in[32*ii+1 +: 31], ~data_in[32*ii +: 1]} : data_in[32*ii +: 32] ;
    end
    endgenerate

    function automatic [NW-1:0] next_pkt_finder ;
      input  [3:0]        num ;
      input  [NW-1:0]     cur_stp ;
      input  [NW-1:0]     cur_end ;
      input               td_status ;
      input  [NW-1:0]     cur_td_status ;
      reg    [3:0]        find_cnt ;
      integer             find_loop ;
      reg                 latest_td_status ;
      reg    [NW-1:0]     next_pkt_finder_pre ;
      begin
        find_cnt = 4'd0 ;
        latest_td_status = td_status ;
        next_pkt_finder_pre = {NW{1'b0}} ;

        for ( find_loop=0 ; find_loop<NW ; find_loop=find_loop+1 ) begin
            if ( cur_end[find_loop]==1'b1 ) begin // finding end flag from current data
                if ( latest_td_status ) begin   // checking the tlp count and it's td status
                    if ( find_cnt==num ) next_pkt_finder_pre = 1'b1<<find_loop ;
                    find_cnt = find_cnt + 4'd1 ;
                end
            end else if ( cur_stp[find_loop]==1'b1 ) begin // finding start flag from current data
                latest_td_status = cur_td_status[find_loop] ;
            end
        end

        next_pkt_finder = next_pkt_finder_pre ;
      end
    endfunction

`ifndef SYNTHESIS
    wire    [NW-1:0]        find_pkt_0 ;
    wire    [NW-1:0]        find_pkt_1 ;
    wire    [NW-1:0]        find_pkt_2 ;
    wire    [NW-1:0]        find_pkt_3 ;
    
    assign find_pkt_0 = find_pkt[0];
    assign find_pkt_1 = find_pkt[1];
    assign find_pkt_2 = find_pkt[2];
    assign find_pkt_3 = find_pkt[3];
`endif // SYNTHESIS

endmodule // lcrc_einj
