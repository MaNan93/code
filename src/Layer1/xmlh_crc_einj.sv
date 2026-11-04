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
// ---    $DateTime: 2023/09/27 02:27:25 $
// ---    $Revision: #6 $
// ---    $Id: //dwh/pcie_iip/main/fairbanks/design/Layer1/xmlh_crc_einj.sv#6 $
// -------------------------------------------------------------------------
// --- Module Description: This is the module for RAS D.E.S. feature.
//                         The following functions are implemented here.
//                           - Collapse the parity of 128b/130b SKP/TS ordered-set
// -----------------------------------------------------------------------------

`include "include/DWC_pcie_ctl_all_defs.svh"
`include "products/DWC_pcie_core_pkg.svh"
`include "Layer1/xmlh_pkg.svh"

 
 module xmlh_crc_einj 
 import DWC_pcie_core_pkg::ltssm_state_e;
 import DWC_pcie_core_pkg::S_POLL_COMPLIANCE;
 import xmlh_pkg::*;
 #(
    parameter   INST    = 0,              // The uniquifying parameter for each port logic instance.
    parameter   SB_WD   = `CX_MAC_SB_WD   // Number of bits of per txstartblock
)
(
    input                                core_clk,
    input                                core_rst_n,
    input   [AW-1:0]                     active_nb,
    input   [2:0]                        current_data_rate,
    input   ltssm_state_e                smlh_ltssm_state,
    input                                ltssm_flit_mode,
    input   [NL*SB_WD-1:0]               scramble_startblock,
    input   [NL*SB_WD-1:0]               scramble_ints0,                   //TS0 indicator
    input   [NL*SB_WD-1:0]               scramble_ints1,                   //TS1 indicator
    input   [NL*SB_WD-1:0]               scramble_ints2,                   //TS2 indicator
    input   [NL*SB_WD-1:0]               scramble_inskp,                   //SKP indicator
    input   [NL-1:0][2:0]                scramble_skp_os_align_sts,        //Indicates current sending Data have LFSR/Parity field of SKP OS
    input   [NL-1:0]                     scramble_data_dv,
    input   [(NL*NB*8)-1:0]              scramble_data_org,
    input   [(NL*NBK)-1:0]               scramble_datak,
    input                                cdm_ras_des_einj0_enable,
    input   [3:0]                        cdm_ras_des_einj0_crc_type,

// ---- outputs ---------------
    output  logic [(NL*NB*8)-1:0]        scramble_data,
    output                               xmlh_einj0_oscrc_evt
);

    genvar                               ii;
    reg     [3:0]                        os_cycle_cnt_p1_b ;
    reg     [3:0]                        os_cycle_cnt_p1 ;
    reg     [3:0]                        os_cycle_cnt_b ;
    reg     [3:0]                        os_cycle_cnt ;
    reg                                  data_block_sts ;
    wire                                 einj_byte0_en ;
    wire                                 einj_byte1_en ;
    wire                                 einj_byte5_en ;
    wire                                 einj_skp_en ;
    wire                                 einj_skp_byte0_en ;
    wire                                 einj_skp_byte1_en ;
    wire                                 einj_skp_byte5_en ;
    wire                                 einj_ctrl_skp_end ;
    wire                                 skp_type_matched;
    wire                                 einj_ts_en ;
    wire                                 einj_ts_byte0_en ;
    wire                                 einj_ts_byte1_en ;
    wire                                 einj_ts_byte5_en ;
    wire                                 int_128b130b_enable ;
    wire                                 pol_comp_sts ;
    logic                                int_scramble_inanyts ;
    logic                                einj_ts_1b1b_en ;
    logic                                einj_skp_1b1b_en ;                             
    logic                                einj_ts_1b1b_mask ;                            // Mask EINJ if 1st Parity has been sent w/o Einj after that EINJ eanble is set. Because Parity are on symbol 7 and 15.
    logic                                einj_skp_1b1b_mask ;                           // Mask EINJ if 1st Parity has been sent w/o Einj after that EINJ eanble is set. Because Parity several fields.
    logic                                int_1b1b_enable ;
    logic [NBIT-1:0]                     active_nb_bitmap ;                             // active number of symbols per lane bitmap
    logic [AW-1:0]                       lsfrpar_symbol_size ;                          // The number of symbols that have LFSR or Parity field. (4 for 128b/130b , 8 for 1b1b)
    logic [2:0]                          replacing_cnt ;                                // Replacement counter only for taking multiple cycles to replace all LFSR/Parity field.(2s- 128b/130b, 4s- 1b1b )
    logic [3:0]                          ts_byte_cnt ;                                  // Indicate Byte number which is send in this cycle
    logic [63:0]                         bitenn_skp_par_1b1b ;                          // Bit enable for 1b/1b SKP Parity
    logic [63:0]                         bitenn_skp_evt_1b1b ;                          // Bit enable for 1b/1b SKP Event (last parity bit in a SKP OS)
    logic [127:0]                        bitenn_ts_par_1b1b ;                           // Bit enable for 1b/1b TS  Parity
    logic [127:0]                        bitenn_ts_evt_1b1b  ;                          // Bit enable for 1b/1b TS  Event (last parity bit in a SKP OS)
    logic [NBIT-1:0]                     shift_bitenn_skp_par_1b1b ;                    // Bit enable for 1b/1b SKP Parity. After Data shift
    logic [NBIT-1:0]                     shift_bitenn_skp_evt_1b1b ;                    // Bit enable for 1b/1b SKP Event (last parity bit in a SKP OS). After Data shift
    logic [NBIT-1:0]                     shift_bitenn_ts_par_1b1b ;                     // Bit enable for 1b/1b TS  Parity. After Data shift
    logic [NBIT-1:0]                     shift_bitenn_ts_evt_1b1b  ;                    // Bit enable for 1b/1b TS  Event (last parity bit in a SKP OS). After Data shift
    logic [NBIT-1:0]                     sel_bitenn_par_1b1b ;                          // Bit enable for 1b/1b Error injection. After Mux
    logic [NBIT-1:0]                     sel_bitenn_evt_1b1b ;                          // Bit enable for 1b/1b event. After Mux
    logic                                einj_evt_1b1b1 ;                               // Event flag for Gen6 EINJ(output to Cdm)

    assign int_128b130b_enable = ((current_data_rate==`GEN3_RATE) | (current_data_rate==`GEN4_RATE) | (current_data_rate==`GEN5_RATE)) ;
    assign int_1b1b_enable = (current_data_rate==`GEN6_RATE) ;

    wire                                 int_scramble_ints0 ;
    wire                                 int_scramble_ints1 ;
    wire                                 int_scramble_ints2 ;
    wire                                 int_scramble_inskp ;
    skp_replace_t                        int_skp_os_align_sts ;


    //-------------------------------------------
    //  Flag to find Ordered Set
    //-------------------------------------------
    assign int_scramble_ints0   = scramble_ints0[0];
    assign int_scramble_ints1   = scramble_ints1[0];
    assign int_scramble_ints2   = scramble_ints2[0];
    assign int_scramble_inskp   = scramble_inskp[0];
    assign int_skp_os_align_sts = skp_replace_t'( scramble_skp_os_align_sts[0] ) ;

    // --- any TS is sending
    always_comb begin
        int_scramble_inanyts = int_scramble_ints0 | int_scramble_ints1 | int_scramble_ints2 ;
    end
    
    //-------------------------------------------
    // For Gen6, Byte Count in a block / SKP PhyPayload
    // Active NB bitmap
    //-------------------------------------------
    always_comb begin
        lsfrpar_symbol_size = $bits(lsfrpar_symbol_size)'( 8 ) ;    // used only Gen6 now
    end

    always_ff @( posedge core_clk or negedge core_rst_n ) begin : ts_byte_cnt_PROC
        if ( ~core_rst_n ) begin
            ts_byte_cnt                <= #TP '0 ;
        end
        else begin
            if( scramble_data_dv[0] ) begin
                if( |scramble_startblock ) begin
                    ts_byte_cnt            <= #TP $bits(ts_byte_cnt)'(active_nb) ;
                end
                else if( ts_byte_cnt != '0 ) begin
                    ts_byte_cnt            <= #TP $bits(ts_byte_cnt)'(ts_byte_cnt + active_nb) ;
                end 
            end
        end
    end

    always_ff @( posedge core_clk or negedge core_rst_n ) begin : replacing_cnt_PROC
        if ( ~core_rst_n ) begin
            replacing_cnt                <= #TP '0 ;
        end
        else begin
            if( (int_skp_os_align_sts != PPT_0_SKP_1b1b) && (int_skp_os_align_sts != PPT_1_SKP_1b1b) ) begin
                replacing_cnt            <= #TP '0 ;
            end
            else if( scramble_data_dv[0] ) begin
                replacing_cnt            <= #TP (( replacing_cnt + active_nb ) < lsfrpar_symbol_size) ? $bits(replacing_cnt)'( replacing_cnt + active_nb ) : '0 ;
            end 
        end
    end

    // Current active Data width bit map
    always_ff @( posedge core_clk or negedge core_rst_n ) begin : active_nb_PROC
        if ( ~core_rst_n ) begin
            active_nb_bitmap              <= #TP $bits(active_nb_bitmap )'(8'hFF) ;
        end
        else begin
            for( int ii = 0 ; ii < NB ; ii++ ) begin
                active_nb_bitmap[ii*8 +: 8] <= #TP ( active_nb > $bits(active_nb)'( ii ) ) ? 8'hFF : 8'h00 ;
            end
        end
   end

    //-------------------------------------------
    //  Count the cycle from start block
    //  This counter starts to work if scramble_startblock was asserted.
    //-------------------------------------------
    always @( * ) begin
        if ( int_128b130b_enable | int_1b1b_enable) begin
            if ( scramble_data_dv[0] ) begin
                if ( |scramble_startblock ) begin
                    os_cycle_cnt_p1_b = 4'd1;
                    os_cycle_cnt_b    = 4'd0;
                end else begin
                    os_cycle_cnt_p1_b = os_cycle_cnt_p1 + 4'd1;
                    os_cycle_cnt_b    = os_cycle_cnt_p1;
                end
            end else begin
                os_cycle_cnt_p1_b = os_cycle_cnt_p1;
                os_cycle_cnt_b    = os_cycle_cnt;
            end
        end else begin
            os_cycle_cnt_p1_b = 4'd1;
            os_cycle_cnt_b    = 4'd0;
        end
    end

    always @(posedge core_clk or negedge core_rst_n) begin
        if (!core_rst_n) begin
            os_cycle_cnt_p1 <= #TP 4'd1;
            os_cycle_cnt <= #TP 4'd0;
        end else begin
            os_cycle_cnt_p1 <= #TP os_cycle_cnt_p1_b;
            os_cycle_cnt <= #TP os_cycle_cnt_b;
        end
    end

    //-------------------------------------------------
    //  SKPOS has parity bit when:
    //    - the previous block is data stream
    //    - the state is not in the Polling.Compliance.
    //-------------------------------------------------
    // Finding data block for einj into SKPOS parity
    always @(posedge core_clk or negedge core_rst_n) begin
        if (!core_rst_n) begin
            data_block_sts <= #TP 1'b0;
        end else begin
            if ( int_128b130b_enable | int_1b1b_enable) begin
                if ( scramble_startblock[0] ) begin
                    if ( scramble_datak[1:0]==`SYNC_DATA_BLOCK ) begin
                        data_block_sts <= #TP 1'b1;
                    end else if ( !int_scramble_inskp ) begin
                        data_block_sts <= #TP 1'b0;
                    end
                end
            end else begin
                data_block_sts <= #TP 1'b0;
            end
        end
    end

    assign pol_comp_sts = (smlh_ltssm_state==S_POLL_COMPLIANCE) ;

    //-------------------------------------------
    //  Detect SKP-OS type (Standard SKP-OS or Control SKP-OS)
    //-------------------------------------------
    assign einj_ctrl_skp_end = (current_data_rate>=`GEN4_RATE | ltssm_flit_mode) ? 1'b1 : 1'b0 ;
    assign skp_type_matched  = (einj_ctrl_skp_end) ? (int_skp_os_align_sts == CNTL_SKP_128b130b) : (int_skp_os_align_sts == STNDRD_SKP_PDT_128b130b);

    //-------------------------------------------
    //  Find the location to insert errors
    //-------------------------------------------
    // SKPOS : Symbol 13 bit7 is data parity bit in Standard SKP-OS
    //       : Symbol 13 bit7,6,5 are parity bits in Control SKP-OS
    assign einj_skp_en       = cdm_ras_des_einj0_enable & (cdm_ras_des_einj0_crc_type==4'b0110) & int_128b130b_enable & data_block_sts & ~pol_comp_sts ;
    // SKP parity bit is in 1st byte
    assign einj_skp_byte0_en = einj_skp_en & int_scramble_inskp & scramble_data_dv[0] & skp_type_matched & (active_nb[0] & os_cycle_cnt_b==4'd13) ;
    // SKP parity bit is in 2nd byte
    assign einj_skp_byte1_en = einj_skp_en & int_scramble_inskp & scramble_data_dv[0] & skp_type_matched & ((active_nb[1] & os_cycle_cnt_b==4'd6)
                                                                                        |(active_nb[2] & os_cycle_cnt_b==4'd3)
                                                                                        );
    assign einj_skp_byte5_en = einj_skp_en & int_scramble_inskp & scramble_data_dv[0] & skp_type_matched & (active_nb[3] & os_cycle_cnt_b==4'd1) ;

    // TS1/TS2OS : Symbol 9 bit7 is parity bit
    assign einj_ts_en       = cdm_ras_des_einj0_enable & (cdm_ras_des_einj0_crc_type==4'b0101) & int_128b130b_enable ;
    // TS parity bit is in 1st byte
    assign einj_ts_byte0_en = einj_ts_en & (int_scramble_ints1|int_scramble_ints2) & scramble_data_dv[0] & (active_nb[0] & os_cycle_cnt_b==4'd9) ;
    // TS parity bit is in 2nd byte
    assign einj_ts_byte1_en = einj_ts_en & (int_scramble_ints1|int_scramble_ints2) & scramble_data_dv[0] & ((active_nb[1] & os_cycle_cnt_b==4'd4)
                                                                                                           |(active_nb[2] & os_cycle_cnt_b==4'd2)
                                                                                                           |(active_nb[3] & os_cycle_cnt_b==4'd1)
                                                                                                           );

    assign einj_byte0_en = einj_skp_byte0_en | einj_ts_byte0_en ;
    assign einj_byte1_en = einj_skp_byte1_en | einj_ts_byte1_en ;
    assign einj_byte5_en = einj_skp_byte5_en ;

    // ---- For Gen6 ---
    // --- Parity bits field bit enable
    always_comb begin
      bitenn_skp_par_1b1b     = {  4'b1110                     // [63:60] : Parity[2:1], Type[0]
                                 , 16'h0000                    // [59:44] : LFSR or Margin or Error Status
                                 , 4'b1110                     // [43:40] : Parity[2:1], Type[0]
                                 , 8'h00                       // [39:32] : LFSR or Margin or Error Status
                                 , 8'h00                       // [31:24] : LFSR or Margin or Error Status
                                 , 4'b1110                     // [23:20] : Parity[2:1], Type[0]
                                 , 16'h0000                    // [19:4]  : LFSR or Margin or Error Status
                                 , 4'b1110            };       // [3:0]   : Parity[2:1], Type[0]
      bitenn_skp_evt_1b1b     =    64'h8000_0000_0000_0000 ;   // [63] is the last parity bit. Assert xmlh_einj0_oscrc_evt at this point.
      bitenn_ts_par_1b1b      = {  64'hFF00_0000_0000_0000 ,   // Symbol 7/15 is the last parity bits.
                                   64'hFF00_0000_0000_0000 } ; 
      bitenn_ts_evt_1b1b      = {  64'hFF00_0000_0000_0000 ,   // Symbol 5 is the last parity bits. Assert xmlh_einj0_oscrc_evt at this point.
                                   64'h0000_0000_0000_0000 } ; 
    end

    // --- Shift Bit enable by Block counter
    always_comb begin
     // -- For SKP
        shift_bitenn_skp_par_1b1b       = $bits( shift_bitenn_skp_par_1b1b )'( bitenn_skp_par_1b1b ) ;
        shift_bitenn_skp_evt_1b1b       = $bits( shift_bitenn_skp_evt_1b1b )'( bitenn_skp_evt_1b1b ) ;
        
        if( active_nb < lsfrpar_symbol_size ) begin
            shift_bitenn_skp_par_1b1b       = $bits( shift_bitenn_skp_par_1b1b )'( bitenn_skp_par_1b1b >> {replacing_cnt, 3'd0} ) ;   // Shift right(byte unit)
            shift_bitenn_skp_evt_1b1b       = $bits( shift_bitenn_skp_evt_1b1b )'( bitenn_skp_evt_1b1b >> {replacing_cnt, 3'd0} ) ;   // Shift right(byte unit)
        end
        if( active_nb > lsfrpar_symbol_size ) begin
            shift_bitenn_skp_par_1b1b       = $bits( shift_bitenn_skp_par_1b1b )'( bitenn_skp_par_1b1b << {(active_nb - lsfrpar_symbol_size) , 3'd0} ) ;   // Shift Left(byte unit)
            shift_bitenn_skp_evt_1b1b       = $bits( shift_bitenn_skp_evt_1b1b )'( bitenn_skp_evt_1b1b << {(active_nb - lsfrpar_symbol_size) , 3'd0} ) ;   // Shift Left(byte unit)
        end

     // -- For TS
     shift_bitenn_ts_par_1b1b   = $bits( shift_bitenn_ts_par_1b1b )'( bitenn_ts_par_1b1b >> {ts_byte_cnt, 3'd0} ) ;   // Shift right(byte unit)
     shift_bitenn_ts_evt_1b1b   = $bits( shift_bitenn_ts_evt_1b1b )'( bitenn_ts_evt_1b1b >> {ts_byte_cnt, 3'd0} ) ;   // Shift right(byte unit)
    end


    // --- Error injection enable
    always_comb begin
        // SKP Error Injection enable
        einj_skp_1b1b_en      =   cdm_ras_des_einj0_enable 
                                & (cdm_ras_des_einj0_crc_type==4'b0110) 
                                & int_1b1b_enable 
                                & data_block_sts 
                                & ((int_skp_os_align_sts == PPT_0_SKP_1b1b) | (int_skp_os_align_sts == PPT_1_SKP_1b1b))
                                & scramble_data_dv[0] ;
        // TS0/1/2 Error Injection enable
        einj_ts_1b1b_en        =    cdm_ras_des_einj0_enable 
                                & (cdm_ras_des_einj0_crc_type==4'b0101) 
                                & int_1b1b_enable 
                                & int_scramble_inanyts
                                & scramble_data_dv[0] ;
    end
    
    // --- Error injection mask
    // --- Because Gen6 TS and SKP have multiple Parity Field. If cdm_ras_des_einj0_enable is set after one Parity has been set and the other Pariy has not.
    // --- Then Error is injected next SKP/TS for all parity field. Not inject error only part of Parity fields.
    always_ff @( posedge core_clk or negedge core_rst_n ) begin : einj_1b1b_mask_PROC
        if ( ~core_rst_n ) begin
            einj_ts_1b1b_mask                <= #TP '0 ;
            einj_skp_1b1b_mask               <= #TP '0 ;
        end
        else begin
            // For TS1, When 16s or wider PIPE width then never masked
                 if( scramble_data_dv[0] && ($bits(ts_byte_cnt)'(ts_byte_cnt + active_nb) == '0)             ) einj_ts_1b1b_mask <= #TP '0 ;
            else if( scramble_data_dv[0] && !einj_ts_1b1b_en && int_scramble_inanyts && (ts_byte_cnt == '0)  ) einj_ts_1b1b_mask <= #TP 1'b1 ;
            
            // For SKP, When 8s or wider PIPE width then never masked
                 if( scramble_data_dv[0] && ((replacing_cnt + active_nb ) >= lsfrpar_symbol_size)                                                         ) einj_skp_1b1b_mask <= #TP '0 ;
            else if( scramble_data_dv[0] && !einj_skp_1b1b_en && (int_skp_os_align_sts inside {PPT_0_SKP_1b1b , PPT_1_SKP_1b1b}) && (replacing_cnt == '0) ) einj_skp_1b1b_mask <= #TP 1'b1 ;
        end
    end

    // --- Select bit/event enable
    always_comb begin
        sel_bitenn_par_1b1b = '0 ;
        sel_bitenn_evt_1b1b = '0 ;
        
        if( einj_skp_1b1b_en && ~einj_ts_1b1b_mask ) begin
            sel_bitenn_par_1b1b = shift_bitenn_skp_par_1b1b & active_nb_bitmap ;
            sel_bitenn_evt_1b1b = shift_bitenn_skp_evt_1b1b & active_nb_bitmap ;
        end
        if( einj_ts_1b1b_en && ~einj_skp_1b1b_mask ) begin
            sel_bitenn_par_1b1b = shift_bitenn_ts_par_1b1b & active_nb_bitmap ;
            sel_bitenn_evt_1b1b = shift_bitenn_ts_evt_1b1b & active_nb_bitmap ;
        end
    end
    
    // ---- Event signal
    always_comb begin
        einj_evt_1b1b1  = |sel_bitenn_evt_1b1b ;
    end


    //-------------------------------------------
    //  Error injection
    //-------------------------------------------
    always_comb begin
        scramble_data = scramble_data_org ;
        
        for ( int ii = 0; ii < NL; ii++) begin : gen_scramble_data
            if( int_1b1b_enable ) begin
                for( int jj = 0 ; jj < NBIT ; jj++ ) begin
                    scramble_data[(NBIT*ii) + jj]   = sel_bitenn_par_1b1b[jj] ? ~scramble_data_org[(NBIT*ii) + jj] : scramble_data_org[(NBIT*ii) + jj] ;
                end
            end
            if( int_128b130b_enable ) begin
                    scramble_data[(NB*8)*ii    +: 8]   = einj_byte0_en ? (einj_skp_byte0_en && einj_ctrl_skp_end) ? {~scramble_data_org[(NB*8)*ii+5 +: 3], scramble_data_org[(NB*8)*ii +: 5]} : {~scramble_data_org[(NB*8)*ii+7],  scramble_data_org[(NB*8)*ii +: 7]}   : scramble_data_org[(NB*8)*ii +: 8] ; // byte0
                    scramble_data[(NB*8)*ii+8  +: 8]   = einj_byte1_en ? (einj_skp_byte1_en && einj_ctrl_skp_end) ? {~scramble_data_org[(NB*8)*ii+8+5 +: 3], scramble_data_org[(NB*8)*ii+8 +: 5]} : {~scramble_data_org[(NB*8)*ii+8+7],scramble_data_org[(NB*8)*ii+8 +: 7]} : scramble_data_org[(NB*8)*ii+8 +: 8] ; // byte1
                    scramble_data[(NB*8)*ii+16 +: 8]   = scramble_data_org[(NB*8)*ii+16 +: 8] ; // byte2
                    scramble_data[(NB*8)*ii+24 +: 8]   = scramble_data_org[(NB*8)*ii+24 +: 8] ; // byte3
                    scramble_data[(NB*8)*ii+32 +: 8]   = scramble_data_org[(NB*8)*ii+32 +: 8] ; // byte4
                    scramble_data[(NB*8)*ii+40 +: 8]   = einj_byte5_en ? (einj_ctrl_skp_end) ?  {~scramble_data_org[(NB*8)*ii+40+5 +: 3],scramble_data_org[(NB*8)*ii+40 +: 5]} : {~scramble_data_org[(NB*8)*ii+40+7],scramble_data_org[(NB*8)*ii+40 +: 7]} : scramble_data_org[(NB*8)*ii+40 +: 8] ; // byte5 

                    scramble_data[(NB*8)*ii+48 +: 8]   = scramble_data_org[(NB*8)*ii+48 +: 8] ; // byte6
                    scramble_data[(NB*8)*ii+56 +: 8]   = scramble_data_org[(NB*8)*ii+56 +: 8] ; // byte7
            end
        end
    end

    assign xmlh_einj0_oscrc_evt = einj_byte0_en | einj_byte1_en | einj_byte5_en | einj_evt_1b1b1;

endmodule // xmlh_crc_einj
