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
// ---    $Revision: #8 $
// ---    $Id: //dwh/pcie_iip/main/fairbanks/design/Layer1/scramble3_skip_align.sv#8 $
// -------------------------------------------------------------------------
// -----------------------------------------------------------------------------
// --- Module Description:
// -----------------------------------------------------------------------------
// -- When operating at 8 GT/s or above rate, if a SKP OS is being transmitted,
// -- the OS block leaves the byte_xmt block in XMLH before the correct LFSR
// -- and Data Parity values can be calculated and inserted into the SKP OS.
// -- This causes a misalignment between the actual LFSR/Parity values and
// -- the transmitted values.
// -- This module intercepts SKP Ordered Set blocks and inserts the correct
// -- LFSR and Data Parity Values when a SKP OS is detected.
// -----------------------------------------------------------------------------

`include "include/DWC_pcie_ctl_all_defs.svh"
`include "Layer1/xmlh_pkg.svh"
`include "products/DWC_pcie_core_pkg.svh"

module scramble3_skip_align
  import xmlh_pkg::*;
  #(parameter INST         = 0,
    parameter SB_WD        = `CX_MAC_SB_WD,
    parameter SH_WD        = `CX_MAC_SH_WD,
    parameter SIG_WIDTH    = 4,
    parameter DCB_WD       = (NB>=8 ? NB/8 : 1)
  )
  
                             (
    input  logic                     core_clk,
    input  logic                     core_rst_n,
// =============================================================================
//  input IO Declarations
// =============================================================================
    // Data path signals
    input   logic [SIG_WIDTH-1:0]    extra_sig,               // extra signals alignd with Data. just though in this module.
    input   logic [NBIT-1:0]         data,                    // Tx Data after scrambling
    input   logic                    data_valid,              // Tx Data Valid
    input   logic [SB_WD-1:0]        startblock,              // Tx Start Block. just though in this module.
    input   logic [SH_WD-1:0]        syncheader,              // Tx Syncheader. just though in this module.
    // LFSR/Parity
    input   logic [SB_WD-1:0]        even_parity,             // Parity bit for SKP OS Parity field.
    input   logic [22:0]             lfsr_value,              // Scramble LFSR for SKP OS LFSR field.
    // Information signals
    input   skp_replace_t            skp_os_align_sts,        // Indicates current sending Data have LFSR/Parity field of SKP OS
    input   logic  [AW-1:0]          active_nb,               // active number of symbols per lane per clock. bit0=1s, bit1=2s, bit2=4s, bit3=8s , bit4=16s
    input   data_rate_enc_t          crnt_rate_enc ,          // current data rate shortcut.

// =============================================================================
//  output IO Declarations
// =============================================================================
     // Data path signals
     output logic [DCB_WD-1:0]       scramble_dcb_det,        // Fixed 0b. Not used in Tx Side.
     output logic [SIG_WIDTH-1:0]    scramble_extra_sig,      // extra signals alignd with Data. just though in this module.
     output logic [NBIT-1:0]         scramble_data,           // Tx Data after SKP LFSR/Parity replacement.
     output logic [SB_WD-1:0]        scramble_startblock,     // Tx Start Block. just though in this module.
     output logic [SH_WD-1:0]        scramble_syncheader      // Tx Syncheader. just though in this module.
  );



// -----------------------------------
//  Declaration
// -----------------------------------
    logic [NBIT-1:0]         active_nb_bitmap ;                             // active number of symbols per lane bitmap
    logic                    use_even_parity ;                              // MSB of even_parity signal. even_parity is 2bit if 32s, but has same value in [0] and [1]
    logic [31:0]             lfsrpar_stndrd_pdt_skp_128b130b ;              // 128b/130b Standard SKP prior block is Data Block
    logic [31:0]             lfsrpar_stndrd_pos_skp_128b130b ;              // 128b/130b Standard SKP prior block is not Data Block
    logic [31:0]             lfsrpar_ctrl_skp_128b130b ;                    // 128b/130b Control SKP 
    logic [31:0]             biten_stndrd_skp_128b130b ;                    // Bit enable for 128b/130b Standard SKP for both prior block is Data Block and OS
    logic [31:0]             biten_ctrl_skp_128b130b ;                      // Bit enable for 128b/130b Control SKP 
    logic [63:0]             lfsrpar_ppt_0_skp_1b1b ;                       // 1b/1b SKP with PhyPayloadType=0
    logic [63:0]             lfsrpar_ppt_1_skp_1b1b ;                       // 1b/1b SKP with PhyPayloadType=1
    logic [3:0]              par_type_skp_1b1b ;                            // 1b/1b SKP Parity and Type field
    logic [23:0]             lfsr_skp_1b1b ;                                // 1b/1b SKP LFSR field
    logic [63:0]             bitenn_ppt_0_skp_1b1b ;                        // Bit enable for 1b/1b SKP with PhyPayloadType=0
    logic [63:0]             bitenn_ppt_1_skp_1b1b ;                        // Bit enable for 1b/1b SKP with PhyPayloadType=1
    logic [63:0]             sel_replace_skp_data ;                         // Current SKP LFSR/Parity replacement Data. Before Data shift
    logic [63:0]             sel_replace_skp_biten ;                        // Bit enable for Current SKP LFSR/Parity replacement Data. Before Data shift
    logic [NBIT-1:0]         sft_replace_skp_data ;                         // Current SKP LFSR/Parity replacement Data. After Data shift
    logic [NBIT-1:0]         sft_replace_skp_biten ;                        // Bit enable for Current SKP LFSR/Parity replacement Data. After Data shift
    logic [2:0]              replacing_cnt ;                                // Replacement counter only for taking multiple cycles to replace all LFSR/Parity field.(2s- 128b/130b, 4s- 1b1b )
    logic [AW-1:0]           lsfrpar_symbol_size ;                          // The number of symbols that have LFSR or Parity field. (4 for 128b/130b , 8 for 1b1b)


// --------------------------------------------------
//  Flags
// --------------------------------------------------
    always_comb begin
        lsfrpar_symbol_size = 
                               crnt_rate_enc.enc_1b1b ? $bits(lsfrpar_symbol_size)'( 8 ) : 
                               $bits(lsfrpar_symbol_size)'( 4 ) ;
        
        use_even_parity    = even_parity[SB_WD-1] ;
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

// --------------------------------------------------
//  Create SKP LSFR/Parity Data for each SKP
// --------------------------------------------------

    always_comb begin
                                           //    Symbol15      ,   Symbol14       ,             Symbol13                     , Symbol12
      lfsrpar_stndrd_pdt_skp_128b130b      = { lfsr_value[7:0] , lfsr_value[15:8] , use_even_parity      , lfsr_value[22:16] ,  8'h00   };
      lfsrpar_stndrd_pos_skp_128b130b      = { lfsr_value[7:0] , lfsr_value[15:8] , ~lfsr_value[22]      , lfsr_value[22:16] ,  8'h00   };
      biten_stndrd_skp_128b130b            = {     8'hFF       ,     8'hFF        ,      1'b1            ,   7'b111_1111     ,  8'h00   };
      lfsrpar_ctrl_skp_128b130b            = {     8'h00       ,     8'h00        , {3{use_even_parity}} ,     5'h00         ,  8'h00   };
      biten_ctrl_skp_128b130b              = {     8'h00       ,     8'h00        ,      3'b111          ,     5'h00         ,  8'h00   };

      par_type_skp_1b1b                    = { {3{use_even_parity}} , 1'b0 } ;
      lfsr_skp_1b1b                        = { ^lfsr_value , lfsr_value } ;

      lfsrpar_ppt_0_skp_1b1b               = {  par_type_skp_1b1b        // [63:60]
                                              , 16'h0000                 // [59:44]
                                              , par_type_skp_1b1b        // [43:40]
                                              , 8'h00                    // [39:32]
                                              , 8'h00                    // [31:24]
                                              , par_type_skp_1b1b        // [23:20]
                                              , 16'h0000                 // [19:4]
                                              , par_type_skp_1b1b  };    // [3:0]
      lfsrpar_ppt_1_skp_1b1b               = {  par_type_skp_1b1b        // [63:60]
                                              , lfsr_skp_1b1b[23:8]      // [59:44]
                                              , par_type_skp_1b1b        // [43:40]
                                              , lfsr_skp_1b1b[7:0]       // [39:32]
                                              , lfsr_skp_1b1b[23:16]     // [31:24]
                                              , par_type_skp_1b1b        // [23:20]
                                              , lfsr_skp_1b1b[15:0]      // [19:4]
                                              , par_type_skp_1b1b  };    // [3:0]

      bitenn_ppt_0_skp_1b1b                = {  4'b1110                  // [63:60]
                                              , 16'h0000                 // [59:44]
                                              , 4'b1110                  // [43:40]
                                              , 8'h00                    // [39:32]
                                              , 8'h00                    // [31:24]
                                              , 4'b1110                  // [23:20]
                                              , 16'h0000                 // [19:4]
                                              , 4'b1110            };    // [3:0]
      bitenn_ppt_1_skp_1b1b                = {  4'b1110                  // [63:60]
                                              , 16'hFFFF                 // [59:44]
                                              , 4'b1110                  // [43:40]
                                              , 8'hFF                    // [39:32]
                                              , 8'hFF                    // [31:24]
                                              , 4'b1110                  // [23:20]
                                              , 16'hFFFF                 // [19:4]
                                              , 4'b1110            };    // [3:0]
    end

// --------------------------------------------------
//  Count replacement cycle (for 2s- 128b/130b, 4s- 1b1b )
// --------------------------------------------------

    always_ff @( posedge core_clk or negedge core_rst_n ) begin : rate_flag_PROC
        if ( ~core_rst_n ) begin
            replacing_cnt                <= #TP '0 ;
        end
        else begin
            if( skp_os_align_sts == SKP_REPLACE_IDLE ) begin
                replacing_cnt            <= #TP '0 ;
            end
            else begin
                replacing_cnt            <= #TP (( replacing_cnt + active_nb ) < lsfrpar_symbol_size) ? $bits(replacing_cnt)'( replacing_cnt + active_nb ) : '0 ;
            end 
        end
    end

// ---------------------------------------------------------------
//  Select and shift Replacement LFSR/Parity Data and Bit enable
// ---------------------------------------------------------------

    // Select Data/Bit Enable by skp_os_align_sts from xmlh_byte_xmt
    always_comb begin
        case( skp_os_align_sts )
            STNDRD_SKP_PDT_128b130b : begin
                                        sel_replace_skp_data   = $bits( sel_replace_skp_data  )'( lfsrpar_stndrd_pdt_skp_128b130b ) ;
                                        sel_replace_skp_biten  = $bits( sel_replace_skp_biten )'( biten_stndrd_skp_128b130b ) ;
                                      end
            STNDRD_SKP_POS_128b130b : begin
                                        sel_replace_skp_data   = $bits( sel_replace_skp_data  )'( lfsrpar_stndrd_pos_skp_128b130b ) ;
                                        sel_replace_skp_biten  = $bits( sel_replace_skp_biten )'( biten_stndrd_skp_128b130b ) ;
                                      end
            CNTL_SKP_128b130b       : begin
                                        sel_replace_skp_data   = $bits( sel_replace_skp_data  )'( lfsrpar_ctrl_skp_128b130b ) ;
                                        sel_replace_skp_biten  = $bits( sel_replace_skp_biten )'( biten_ctrl_skp_128b130b ) ;
                                      end
            PPT_0_SKP_1b1b          : begin
                                        sel_replace_skp_data   = $bits( sel_replace_skp_data  )'( lfsrpar_ppt_0_skp_1b1b ) ;
                                        sel_replace_skp_biten  = $bits( sel_replace_skp_biten )'( bitenn_ppt_0_skp_1b1b ) ;
                                      end
            PPT_1_SKP_1b1b          : begin
                                        sel_replace_skp_data   = $bits( sel_replace_skp_data  )'( lfsrpar_ppt_1_skp_1b1b ) ;
                                        sel_replace_skp_biten  = $bits( sel_replace_skp_biten )'( bitenn_ppt_1_skp_1b1b ) ;
                                      end
            default                 : begin  // SKP_REPLACE_IDLE
                                        sel_replace_skp_data   = '0 ;
                                        sel_replace_skp_biten  = '0 ;
                                      end
       endcase
    end

    // Shift Data to align with current Data width
    always_comb begin
        sft_replace_skp_data        = $bits( sft_replace_skp_data  )'( sel_replace_skp_data  ) ;
        sft_replace_skp_biten       = $bits( sft_replace_skp_biten )'( sel_replace_skp_biten ) ;
        
        if( active_nb < lsfrpar_symbol_size ) begin
            sft_replace_skp_data        = $bits( sft_replace_skp_data  )'( sel_replace_skp_data  >> {replacing_cnt, 3'd0} ) ;   // Shift Left(byte unit)
            sft_replace_skp_biten       = $bits( sft_replace_skp_biten )'( sel_replace_skp_biten >> {replacing_cnt, 3'd0} ) ;   // Shift Left(byte unit)
        end
        
        if( active_nb > lsfrpar_symbol_size ) begin
            sft_replace_skp_data        = $bits( sft_replace_skp_data  )'( sel_replace_skp_data  << {(active_nb - lsfrpar_symbol_size) , 3'd0} ) ;   // Shift Left(byte unit)
            sft_replace_skp_biten       = $bits( sft_replace_skp_biten )'( sel_replace_skp_biten << {(active_nb - lsfrpar_symbol_size) , 3'd0} ) ;   // Shift Left(byte unit)
        end
    end

// ---------------------------------------------------------------
//  Create outpt signals
// ---------------------------------------------------------------

    always_comb begin
         scramble_dcb_det            = '0 ;           // Not used Tx side 
         scramble_extra_sig          = extra_sig ;
         scramble_startblock         = startblock ;
         scramble_syncheader         = syncheader ;

        for( int ii = 0 ; ii < NBIT ; ii++ ) begin
            scramble_data[ii]        = ( sft_replace_skp_biten[ii] & active_nb_bitmap[ii] ) ? sft_replace_skp_data[ii] : data[ii] ; 
        end
    end

endmodule // scramble3_skip_align
