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
// ---    $Id: //dwh/pcie_iip/main/fairbanks/design/Layer1/xmlh_smb_einj.sv#7 $
// -------------------------------------------------------------------------
// --- Module Description: This is the module for RAS D.E.S. feature.
//                         The following functions are implemented here.
//                           - [8b/10b] Mask datak of TS1/TS2/SKP/FTS/EI ordered set
//                           - [8b/10b] Mask datak of STP/SDP/END/EDB symbol
//                           - [128b/130b] Invert sync header
// -----------------------------------------------------------------------------

`include "include/DWC_pcie_ctl_all_defs.svh"

 
 module xmlh_smb_einj #(
    parameter   INST    = 0,         // The uniquifying parameter for each port logic instance.
    parameter   TP      = `TP,       // Clock to Q delay (simulator insurance)
    parameter   NB      = `CX_NB,    // Number of symbols (bytes) per clock cycle
    parameter   NBK     = `CX_NBK,   // Number of symbols (bytes) per clock cycle for datak
    parameter   NL      = `CX_NL,    // Max number of lanes supported
    parameter   AW      = `CX_ANB_WD // Width of the active number of bytes
)
(
    input                                core_clk,
    input                                core_rst_n,
    input   [AW-1:0]                     active_nb,
    input   [2:0]                        current_data_rate,
    input                                xmtbyte_ts1_sent,
    input                                xmtbyte_ts2_sent,
    input                                xmtbyte_pat_fts_sent,
    input                                xmtbyte_pat_eidle_start_sent,
    input                                xmtbyte_skip_sent,
    input                                xmtbyte_txstartblock,
    input                                xmtbyte_txdata_dv,
    input   [(NL*NB*8)-1:0]              xmtbyte_txdata,
    input   [(NL*NBK)-1:0]               xmtbyte_txdatak_org,
    input                                cdm_ras_des_einj3_enable,
    input   [7:0]                        cdm_ras_des_einj3_count,
    input   [2:0]                        cdm_ras_des_einj3_smb_type,

// ---- outputs ---------------
    output  [(NL*NBK)-1:0]               xmtbyte_txdatak,            // Error inserted txdatak
    output  [1:0]                        xmlh_einj3_osmsk_evt
);
    // STP/SDP location 
    localparam SL = NL<=4  ? 1 : // Lane0
                    NL<=8  ? 2 : // Lane0/4
                    NL<=16 ? 4 : // Lane0/4/8/12
                             8 ; // Lane0/4/8/12/16/20/24/28
    // END/EDB location ;
    localparam EL = NL<=1  ? 1 : // Lane0
                    NL<=2  ? 2 : // Lane0/1
                    NL<=4  ? 3 : // Lane0/1/3
                    NL<=8  ? 4 : // Lane0/1/3/7
                    NL<=16 ? 6 : // Lane0/1/3/7/11/15
                             10; // Lane0/1/3/7/11/15/19/23/27/31

    localparam       LMT_TXTLP = `CX_RAS_DES_LMT_TXTLP ;
    localparam [5:0] default_stp_lane2index = {6{1'b1}} ;
    localparam [3:0] default_end_lane2index = {4{1'b1}} ;
    genvar                               idx;
    genvar                               ln;
    genvar                               ii;
    genvar                               bt;
    wire                                 int_8b10b_enable ;
    wire                                 os_start ;
    wire                                 os_16smb_end ;
    wire                                 os_4smb_end ;
    reg     [4:0]                        os_cycle_cnt ;
    reg                                  os_valid_ts1 ;
    reg                                  os_valid_ts2 ;
    reg                                  os_valid_fts ;
    reg                                  os_valid_eidle ;
    reg                                  os_valid_skip ;
    wire                                 os_valid_or ;
    wire                                 os_einj_evt ;
    wire                                 os_einj_en ;
    wire                                 os_einj_en_ts1 ;
    wire                                 os_einj_en_ts2 ;
    wire                                 os_einj_en_fts ;
    wire                                 os_einj_en_ei ;
    wire                                 os_einj_en_skp ;
    
    wire    [1:0]                        smb_einj_evt_cnt ;
    wire    [(NL*NB)-1:0]                smb_txdatak ;

    wire                                 sh_einj_en ;
    wire                                 sh_einj_evt ;
    wire                                 int_cdm_ras_des_einj3_enable ;

    generate
      if ( (LMT_TXTLP==1) && (NL*NB*8>128) ) begin : gen_einj_en_if
          assign int_cdm_ras_des_einj3_enable = 1'b0 ;
      end else begin : gen_einj_en_else
          assign int_cdm_ras_des_einj3_enable = cdm_ras_des_einj3_enable ;
      end
    endgenerate

    //-------------------------------------------
    //  Change the data order into big endian
    //-------------------------------------------
    wire                                 int_data_dv ;
    wire    [(NL*NB*8)-1:0]              int_data ;
    wire    [(NL*NB)-1:0]                int_datak_org ;
    wire    [(NL*NB)-1:0]                int_datak ;

    // int_data/int_datak : big endian
    generate
    for (bt=0; bt<NB; bt=bt+1) begin : gen_data_endian_byte
        for (ln=0; ln<NL; ln=ln+1) begin : gen_data_endian_lane
            assign int_data[(NL*bt+ln)*8 +: 8]  = xmtbyte_txdata[(NB*ln+bt)*8 +: 8] ;
            assign int_datak_org[NL*bt+ln +: 1] = xmtbyte_txdatak_org[(NBK*ln+bt) +: 1] ;
        end
    end
    endgenerate

    assign int_data_dv = xmtbyte_txdata_dv ;

    //-------------------------------------------
    //  OS mask control
    //-------------------------------------------
    assign int_8b10b_enable = (current_data_rate==`GEN1_RATE) | (current_data_rate==`GEN2_RATE) ;
    assign os_start         = xmtbyte_ts1_sent
                            | xmtbyte_ts2_sent
                            | xmtbyte_pat_fts_sent
                            | xmtbyte_pat_eidle_start_sent
                            | xmtbyte_skip_sent
                            ;

    // os_cycle_cnt will be increased to 31(over 16) after the final OS has been received.
    assign os_valid_or = os_valid_ts1 | os_valid_ts2 | os_valid_fts | os_valid_eidle | os_valid_skip;
    always @(posedge core_clk or negedge core_rst_n) begin
        if (!core_rst_n) begin
            os_cycle_cnt <= #TP 5'd0;
        end else begin
            // To deassert os_valid_*, os_cycle_cnt should be controlled during os_valid_or=1 after int_cdm_ras_des_einj3_enable=0.
            if ( int_8b10b_enable && (int_cdm_ras_des_einj3_enable || os_valid_or) ) begin
                if ( os_start ) begin
                    os_cycle_cnt <= #TP 5'd1;
                end else if ( int_data_dv && (|os_cycle_cnt) ) begin
                    os_cycle_cnt <= #TP os_cycle_cnt + 5'd1;
                end
            end else begin
                os_cycle_cnt <= #TP 5'd0;
            end
        end
    end

    assign os_16smb_end = int_data_dv & ( active_nb==1 ? os_cycle_cnt==5'd16 :
                                          active_nb==2 ? os_cycle_cnt==5'd8  :
                                          active_nb==4 ? os_cycle_cnt==5'd4  :
                                          active_nb==8 ? os_cycle_cnt==5'd2  :
                                                         os_cycle_cnt==5'd1  ) ; // active_nb>=16

    assign os_4smb_end  = int_data_dv & ( active_nb==1 ? os_cycle_cnt==5'd4 :
                                          active_nb==2 ? os_cycle_cnt==5'd2 :
                                                         os_cycle_cnt==5'd1 ) ; // active_nb>=4

    always @(posedge core_clk or negedge core_rst_n) begin
        if (!core_rst_n) begin
            os_valid_ts1   <= #TP 1'b0;
            os_valid_ts2   <= #TP 1'b0;
            os_valid_fts   <= #TP 1'b0;
            os_valid_eidle <= #TP 1'b0;
            os_valid_skip  <= #TP 1'b0;
        end else begin
            os_valid_ts1   <= #TP int_cdm_ras_des_einj3_enable && xmtbyte_ts1_sent             ? 1'b1 : os_16smb_end ? 1'b0 : os_valid_ts1   ;
            os_valid_ts2   <= #TP int_cdm_ras_des_einj3_enable && xmtbyte_ts2_sent             ? 1'b1 : os_16smb_end ? 1'b0 : os_valid_ts2   ;
            os_valid_fts   <= #TP int_cdm_ras_des_einj3_enable && xmtbyte_pat_fts_sent         ? 1'b1 : os_4smb_end  ? 1'b0 : os_valid_fts   ;
            os_valid_eidle <= #TP int_cdm_ras_des_einj3_enable && xmtbyte_pat_eidle_start_sent ? 1'b1 : os_4smb_end  ? 1'b0 : os_valid_eidle ;
            os_valid_skip  <= #TP int_cdm_ras_des_einj3_enable && xmtbyte_skip_sent            ? 1'b1 : os_4smb_end  ? 1'b0 : os_valid_skip  ;
        end
    end

    assign os_einj_en_ts1 = os_valid_ts1   & int_cdm_ras_des_einj3_enable & cdm_ras_des_einj3_smb_type==3'b001 ;
    assign os_einj_en_ts2 = os_valid_ts2   & int_cdm_ras_des_einj3_enable & cdm_ras_des_einj3_smb_type==3'b010 ;
    assign os_einj_en_fts = os_valid_fts   & int_cdm_ras_des_einj3_enable & cdm_ras_des_einj3_smb_type==3'b011 ;
    assign os_einj_en_ei  = os_valid_eidle & int_cdm_ras_des_einj3_enable & cdm_ras_des_einj3_smb_type==3'b100 ;
    assign os_einj_en_skp = os_valid_skip  & int_cdm_ras_des_einj3_enable & cdm_ras_des_einj3_smb_type==3'b111 ;

    assign os_einj_en  = int_8b10b_enable & ( os_einj_en_ts1 | os_einj_en_ts2 | os_einj_en_fts | os_einj_en_ei | os_einj_en_skp ) ;
    assign os_einj_evt = (os_einj_en_ts1 & os_16smb_end)
                       | (os_einj_en_ts2 & os_16smb_end)
                       | (os_einj_en_fts & os_4smb_end)
                       | (os_einj_en_ei  & os_4smb_end)
                       | (os_einj_en_skp & os_4smb_end);

    //-------------------------------------------
    //  STP/SDP/END/EDB mask control
    //-------------------------------------------
    // Disable DATAK EINJ for synthesis timing improvement
    assign smb_txdatak = int_datak_org;
    assign smb_einj_evt_cnt = 2'd0;

    //-------------------------------------------
    //  Sync header control
    //-------------------------------------------
    assign sh_einj_en  = ~int_8b10b_enable & int_cdm_ras_des_einj3_enable & cdm_ras_des_einj3_smb_type==3'b000 & xmtbyte_txstartblock ;
    assign sh_einj_evt = sh_einj_en ;

    //-------------------------------------------
    //  RAS D.E.S. register control
    //-------------------------------------------
    assign xmlh_einj3_osmsk_evt  = os_einj_evt ? 2'd1 :
                                   sh_einj_evt ? 2'd1 :
                                                 ( smb_einj_evt_cnt );

    // int_datak : big endian
    assign int_datak = 
                       os_einj_en        ? {(NL*NB){1'b0}} :
                       sh_einj_evt       ? ~int_datak_org :
                       |smb_einj_evt_cnt ? smb_txdatak :
                                           int_datak_org ;

    //-------------------------------------------
    //  Change the bit order into pipe
    //-------------------------------------------
    generate
    for (bt=0; bt<NB; bt=bt+1) begin : gen_data_pipe_lane
        for (ln=0; ln<NL; ln=ln+1) begin : gen_data_pipe_byte
            assign xmtbyte_txdatak[(NB*ln+bt) +: 1] = int_datak[NL*bt+ln +: 1] ;
        end
    end
    endgenerate


`ifndef SYNTHESIS
`endif

endmodule // xmlh_smb_einj
