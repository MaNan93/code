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
// ---    $Revision: #6 $
// ---    $Id: //dwh/pcie_iip/main/fairbanks/design/Cdm/cdm_rasdes_ecnt.sv#6 $
// -------------------------------------------------------------------------
// --- Module Description:
// -----------------------------------------------------------------------------
// --- This module is common event counter for RAS D.E.S.
// -----------------------------------------------------------------------------

`include "include/DWC_pcie_ctl_all_defs.svh"

 
 module cdm_rasdes_ecnt
#(
    parameter INST        = 0,                                          // The uniquifying parameter for each port logic instance.
    parameter TP          = `TP,                                        // Clock to Q delay (simulator insurance)
    parameter EVT_WDTH    = 1,                                          // Event width
    parameter RAM_ENABLE  = 0,                                          // Enable RAM control 
    parameter RAM_DEPTH   = 0,                                          // [RAM mode only] Depth of implemented RAM
    parameter FF_CNT_WDTH = 8                                           // [FF mode only] Bit width of common counter
)
(
// -------------- Inputs ---------------
    input                              aux_clk,                         // Clock
    input                              sticky_rst_n,                    // Reset sticky registers only
    input                              ec_type,                         // Event type  0:pulse / 1:level(count posedge)
    input                              ec_en,                           // Event counter enable
    input                              ec_clr,                          // Event counter clear flag
    input                              ec_clr_all,                      // Event counter clear flag for all event counter
    input  [31:0]                      ec_evt,                          // Event signal

// -------------- Outputs ---------------
    output [31:0]                      ec_cnt                           // Event counter
) ;
    parameter INT_RAM_DEPTH = RAM_DEPTH < 4 ? 4 :                       // The value of RAM depth is replaced to minimum 4.
                                              RAM_DEPTH ;               // The reason is from the Small RAM mode of RAM controller.
                                                                        // (If DEPTH is 4, The end of RAM address is 3)
    parameter CNT_WDTH = RAM_ENABLE==0 ? FF_CNT_WDTH :                  // Max value of common counter
                                         get_cnt_width ( EVT_WDTH, INT_RAM_DEPTH );

    function automatic [31:0] get_cnt_width ( input [31:0] f_evt_width, input [31:0] f_ram_depth );
      integer kk;
      integer ram_max_cnt;
// spyglass disable_block W164a
// SMD: Identifies assignments in which the LHS width is less than the RHS width
// SJ: The multiplication of ram_max_cnt insures that the MSB will be 0 in which case the addition cannot overflow. Because of the maximum value for f_evt_width is 16.
      ram_max_cnt = f_evt_width * f_ram_depth;
// spyglass enable_block W164a
      get_cnt_width = 1;
// spyglass disable_block STARC05-2.9.1.2b
// SMD: for construct has non-constant terminating condition.
// SJ:  The for loop is used to set parameters. It's defined after compilation.
      for ( kk=2; kk<=ram_max_cnt ; kk=kk*2 ) begin
        get_cnt_width = get_cnt_width + 1;
      end
// spyglass enable_block STARC05-2.9.1.2b
    endfunction

// -------------- Internal signals --------------
    genvar                             ii;
    reg   [CNT_WDTH-1:0]               int_ec_cnt ;
    reg   [EVT_WDTH-1:0]               int_ec_evt_1d ;
    wire  [EVT_WDTH-1:0]               int_ec_evt;               // Event signal
    wire  [EVT_WDTH-1:0]               int_ec_evt_p1s ;          // posedge cycle
    wire  [EVT_WDTH-1:0]               int_ec_evt_1s ;
    wire                               ec_cnt_ovf ;
    wire                               int_ec_en ;
    wire                               int_ec_clr ;

// -------------- Common logic --------------
    assign int_ec_evt = ec_evt[EVT_WDTH-1:0];
    assign int_ec_en  = ec_en ;
    assign int_ec_clr = ec_clr | ec_clr_all ;
    assign int_ec_evt_1s = (ec_type==0) ? int_ec_evt     :       // pulse
                           (ec_type==1) ? int_ec_evt_p1s :       // posedge of level signal
                                          {EVT_WDTH{1'b1}} ;     // unused

    assign ec_cnt_ovf = (~int_ec_cnt) < int_ec_evt_num(int_ec_evt_1s) ;

    always @(posedge aux_clk or negedge sticky_rst_n) begin
        if (!sticky_rst_n) begin
            int_ec_cnt <= #TP {CNT_WDTH{1'b0}} ;
        end else begin
            if ( int_ec_clr ) begin
                if ( int_ec_en ) begin
                    int_ec_cnt <= #TP int_ec_evt_num(int_ec_evt_1s) ;
                end else begin
                    int_ec_cnt <= #TP {CNT_WDTH{1'b0}} ;
                end
            end else if ( int_ec_en ) begin
                if ( ec_cnt_ovf ) begin
                    int_ec_cnt <= #TP {CNT_WDTH{1'b1}} ; // ccx_line: ;"This line has been verified on an unit level testbench."
                end else begin
// spyglass disable_block W164a
// SMD: Identifies assignments in which the LHS width is less than the RHS width
// SJ: The loss is avoided by the overflow control (ec_cnt_ovf).
                    int_ec_cnt <= #TP int_ec_cnt + int_ec_evt_num(int_ec_evt_1s) ;
// spyglass enable_block W164a
                end
            end
        end
    end

    generate
      for (ii=0 ; ii<32 ; ii=ii+1 ) begin : gen_ec_cnt_for
        if ( ii<CNT_WDTH ) begin : gen_ec_cnt_if
          assign ec_cnt[ii] = int_ec_cnt[ii] ;
        end else begin : gen_ec_cnt_else
          assign ec_cnt[ii] = 1'b0 ;
        end
      end
    endgenerate

    function automatic [CNT_WDTH-1:0] int_ec_evt_num ( input [EVT_WDTH-1:0] int_ec_evt );
        reg   [CNT_WDTH-1:0]  int_ec_evt_num_reg ;
        integer               jj ;
        begin
            int_ec_evt_num_reg = {CNT_WDTH{1'b0}} ;
            for ( jj=0; jj<EVT_WDTH ; jj=jj+1 ) begin
                if ( (&int_ec_evt_num_reg)==1'b0 ) begin
// spyglass disable_block W164a
// SMD: Identifies assignments in which the LHS width is less than the RHS width
// SJ: The loss is avoided by the overflow control (ec_cnt_ovf).
                    int_ec_evt_num_reg = int_ec_evt_num_reg + int_ec_evt[jj] ;
// spyglass enable_block W164a
                end
            end

            int_ec_evt_num = int_ec_evt_num_reg ;
        end
    endfunction

// -------------- Posedge event logic --------------
// It is expected int_ec_evt_1d is removed by synthesis tools when pulse type is selected.
    always @(posedge aux_clk or negedge sticky_rst_n) begin
        if (!sticky_rst_n) begin
            int_ec_evt_1d <= #TP {EVT_WDTH{1'b0}} ;
        end else begin
            int_ec_evt_1d <= #TP int_ec_evt ;
        end
    end

    assign int_ec_evt_p1s = int_ec_evt & (~int_ec_evt_1d) ;

endmodule //cdm_rasdes_ecnt 
