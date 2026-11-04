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
// ---    $Revision: #3 $
// ---    $Id: //dwh/pcie_iip/main/fairbanks/design/Layer1/xmlh_cmp_gen.sv#3 $
// -------------------------------------------------------------------------
// --- Module Description: Transmit MAC Layer handler Byte Transmitter
// -----------------------------------------------------------------------------
// --- Terminology
// --- chunk: The amount of data that can be transmitted by all active lanes in one clock cycle
// --- slice: The amount of data that can be transmitted by one lane in one clock cycle
// -----------------------------------------------------------------------------

`include "include/DWC_pcie_ctl_all_defs.svh"
`include "Layer1/xmlh_pkg.svh"
`include "products/DWC_pcie_core_pkg.svh"

 module xmlh_cmp_gen 
  import xmlh_pkg::*;
  (
      input  logic                                      core_clk 
    , input  logic                                      core_rst_n 

// =============================================================================
//  , input  logicIO Declarations
// =============================================================================

// Information to make Compliance Pattern
    , input  logic  [3:0]                               ltssm_gen4_compliance_jmp              // Gen4 compliance setting# for Jitter Measurment Pattern for Gen3/4/5
                                                                                               // ltssm_gen4_compliance_jmp
                                                                                               //  4'b0001 | lane 0-15
                                                                                               //  4'b0010 | lane 0,8
                                                                                               //  4'b0011 | lane 1,2
                                                                                               //    --
                                                                                               //  4'b1000 | lane 6,14
                                                                                               //  4'b1001 | lane 7,15
    , input  logic  [3:0]                               ltssm_gen6_compliance_tp               // Gen6 compliance setting# for Toggle Pattern  
                                                                                               // High Swing Toggle Pattern
                                                                                               //  4'b0001 | lane 0-15
                                                                                               //  4'b0010 | lane 0,8
                                                                                               //  4'b0011 | lane 1,2
                                                                                               //    --
                                                                                               //  4'b1000 | lane 6,14
                                                                                               //  4'b1001 | lane 7,15
                                                                                               // Low Swing Toggle Pattern
                                                                                               //  4'b1010 | lane 0-15
    , input  logic [NL-1:0]                             smlh_mcs_rcvd                          // detected Modified Compliance Sequence. This is one of the value on Modified Compliance patter of ERR filed [7](Pattern Lock) Gen1/2
    , input  logic [NL-1:0]                             rpipe_rxerror                          // when asserted, RMLH indicates that the receiver has detected an rx disparity or code error. This is used Modifeied Complaince pattern of ERR field [6:0] (Receiver Error count) Gen1/2
    , input  logic  [NL*TX_PSET_WD-1:0]                 eqctl_pset_ltx                         // Tx preset being used per lane. Set this value ofn Compliance Pattern 128b/130b
    , input  logic  [NL*8-1:0]                          smlh_gen3_error_count_i                // per lane version of gen3 Compliance error count. Set this value on SKP Error Status Field(Symbol14/15) when Polling.Compliance


// Mode/State signals
    , input  logic  [NL-1 :0]                           smlh_no_turnoff_lanes                  // No turnoff lanes when some lanes are disabled
    , input  logic  [AW-1:0]                            active_nb                              // active number of symbols per lane per clock. bit0=1s, bit1=2s, bit2=4s, bit3=8s , bit4=16s

// Internal xmlh_byte_xmt signals (common)
    , input  data_rate_enc_t                            crnt_rate                               // current data rate shortcut.
    , input  logic  [NBIT-1:0]                          active_nb_bitmap                        // active number of symbols per lane bitmap
    , input  logic  [NBK-1:0]                           active_nb_bitmapk                       // active number of symbols per lane bitmap (for DataK)
    , input  logic  [NB-1:0]                            active_nb_bytemap                       // active number of symbols per lane bytemap
    
// Internal xmlh_byte_xmt signals (xmlh_arb_ctl)
    , input  grant_t                                    next_grant                              // Arbitration grant (next)
    , input  grant_t                                    crnt_grant                              // Arbitration grant (Current)
    , input  logic                                      internal_txdata_dv                      // Data Valid, gen1/gen2: always 1, gen3: 0 for one cycle every 4*active_nb blocks
    , input  logic  [NL-1 :0]                           int_data_ltssm_lanes_active             // Data Link width (Not L0p Up/Downsize OS lane width) : LTSSM latched lanes that are active based on the link negotiation
    , input  logic  [NL-1 :0]                           int_l0p_ltssm_lanes_active              // Data Link width (L0p Up/Downsize OS lane width) : LTSSM latched lanes that are active based on the link negotiation
    , input  logic                                      sris_mode_on                            // Indicates SRIS is on used internally.

// Internal xmlh_byte_xmt signals (xmlh_os_gen)
    , input  logic [127:0]                              eie_pat_128b130b                        // EIE OS data for Gen/3/4/5
    , input  logic [127:0]                              skp_pat_128b130b                        // SKP OS data for Gen/3/4/5
    , input  logic [127:0]                              eie_pat_1b1b                            // EIE OS data for Gen6
    , input  logic [319:0]                              skp_pat_1b1b                            // SKP OS data for Gen6



// =============================================================================
// output IO Declarations
// =============================================================================

// Mode/State signals
    , output logic                                      xmtbyte_gen6_compliance_sending         // indicates sending Gen6 (Modified) compliance pattern

// Internal xmlh_byte_xmt signals (xmlh_arb_ctl)
    , output logic  [NL-1:0][NBIT-1:0]                  cmp_gen_data                            // Pattern Data
    , output logic  [NL-1:0][NBK-1:0]                   cmp_gen_datak                           // Pattern Data Kcode
    , output logic  [NL-1:0][NBLOCK-1:0][OSFLG_WD-1:0]  cmp_gen_ossending                       // Sending OS Flag 
    , output logic  [NL-1:0]                            int_txcompliance                        // PIPE TxCompliance signal (before FF). This signal will be aligned align with output data(xmtbyte_txdata,xmtbyte_txdatak)
    , output logic                                      cmp_block_done                          // Asserted when last cycle of pattern block sending
    , output logic                                      mcmp_gen6_skp_in_progress               // Gen6 SKP OS is sending in Modified compliance pattern (for 8S or below)
    , output logic                                      mcmp_gen6_skp_done                      // The last cycle of Gen6 SKP OS in Modified compliance pattern (for 8S or below)
    
    );

// -----------------------------------
//  Local parameters
// -----------------------------------
    localparam OSFLG_IDLE            = 8'b0000_0000 ;
    localparam OSFLG_SKP             = 8'b0000_0001 ;
    localparam OSFLG_SKPEND          = 8'b0000_0011 ;
    localparam OSFLG_EI              = 8'b0000_0100 ;
    localparam OSFLG_EIE             = 8'b0000_1000 ;
    localparam OSFLG_SDS             = 8'b0001_0000 ;
    
    localparam SKPEND_BM_128b130b    = 16'h1000 ;             // SKP END is  on symbol 12
    localparam SKPEND_BM_1b1b        = 40'h00_FF00_0000 ;     // SKP END are on symbol 24-31

// -----------------------------------
//  Typedef
// -----------------------------------
  typedef struct packed {
    logic [NL-1:0][NBLOCK*128-1:0]                cmp_pat ;                               // Compliance pattern Data
    logic [NL-1:0][NBLOCK*128-1:0]                mcmp_pat ;                              // Modified Compliance pattern Data
    logic [NL-1:0][NBLOCK*16-1:0]                 cmp_pat_k ;                             // Compliance pattern Data
    logic [NL-1:0][NBLOCK*16-1:0]                 mcmp_pat_k ;                            // Modified Compliance pattern Data
    logic [NL-1:0][NBLOCK*16-1:0]                 cmp_ossending ;                         // Compliance pattern Sending OS Flag 
    logic [NL-1:0][NBLOCK*16-1:0]                 mcmp_ossending ;                        // Modified Compliance pattern Sending OS Flag 
    logic [NL-1:0][NBLOCK*16-1:0]                 cmp_skpend_bm ;                         // SKP END position byte map for Compliance pattern
    logic [NL-1:0][NBLOCK*16-1:0]                 mcmp_skpend_bm ;                        // SKP END position byte map for Modified Compliance pattern
  } cmp_pat_t ;

  typedef enum logic [2:0] {
        NOT_HIT        = 3'b001 ,
        SHIFT_RIGHT    = 3'b010 ,
        SHIFT_LEFT     = 3'b100  
  }  mcmp_1b1b_hit_t;

    localparam concate_num_1b_jit      = ((128*NBLOCK)/104) + 2 ;
// -----------------------------------
//  Declaration
// -----------------------------------
    cmp_pat_t                            enc_8b10b ;                             // Compliance pattern for 8b/10b
    cmp_pat_t                            enc_128b130b ;                          // Compliance pattern for 128b/130b
    cmp_pat_t                            enc_1b1b ;                              // Compliance pattern for 1b/11b
    cmp_pat_t                            crnt_rate_cmp_pat ;                     // Current Rate pattern
    logic                                next_grnt_is_cmp ;                      // Indicates current grant is any compliance pattern
    logic                                crnt_grnt_is_cmp ;                      // Indicates current grant is any compliance pattern
    logic [5:0]                          cmp_byte_count ;                        // Indicated how many Pattern Block Data bytes are sent
    logic                                cmp_block_start ;                       // Indicated the 1st cycle of a Pattern sending.
    logic                                cmp_block_done_int ;                    // Asserted when last cycle of pattern block sending
    logic                                cmp_phase_done ;                        // Asserted when last cycle of pattern block of the Phase sending
    logic                                cmp_all_phase_done ;                    // Asserted when last cycle of pattern block of the all Phase sending
    logic [6:0]                          next_cmp_block_size ;                   // Indicated Pattern Size in byte(1's base)
    logic [5:0]                          crnt_cmp_block_size_minus_nb ;          // Indicated Pattern Size in byte(1's base)
    logic [11:0]                         crnt_cmp_phase_num ;                    // Indicated the number of Pattern pahse currenty have (0's base)
    logic [17:0]                         crnt_cmp_block_num ;                    // Indicated the number of Pattern should be sent in current Pattern. (0's base)
    logic [17:0]                         crnt_cmp_block_num_minus1 ;             // Indicated the number of Pattern should be sent in current Pattern - 1. (0's base) for timing optimization
    logic [17:0]                         crnt_cmp_block_num_minus_g6qw ;         // Indicated the number of Pattern should be sent in current Pattern - G6_BLOCK_QW_SIZE. (0's base) for timing optimization
    logic [17:0]                         cmp_send_block_num ;                    // Indicated Block already send in this phase (0's base)
    logic [17:0]                         cmp_send_block_num_plus1 ;              // Indicated Block already send in this phase (0's base)
    logic [17:0]                         cmp_send_block_num_plus_g6qw ;          // Indicated Block already send in this phase (0's base) for timing optimization.
    logic [11:0]                         cmp_send_phase_num ;                    // Indicated Phase already send in this phase (0's base)
    logic                                mcmp_send_ovrflw_1b1b ;                 // Indicated 1b1b modified compliance pattern go back to 1st block
    logic [17:0]                         added_mcmp_send_qw_num_1b1b ;           // Indicated Added QW number that arleady send modified compliance pattern.
    logic [17:0]                         next_mcmp_send_qw_num_1b1b ;            // Indicated Next QW number that arleady send modified compliance pattern.
    logic [NBLOCK*16-1:0]                osblock_syncheader ;                    // Indicated OS Syncheder
    logic [NBLOCK*16-1:0]                datablock_syncheader ;                  // Indicated Data Syncheder
    logic [17:0]                         mcmp_1b1b_eie_point ;                   // 1b1b / Modified compliance pattern / EIEOS(EIE -> SKP is SRIS) sending point
    logic [17:0]                         mcmp_1b1b_skp_point ;                   // 1b1b / Modified compliance pattern / SKP sending point
    mcmp_1b1b_hit_t                      mcmp_1b1b_eie_hit ;                     // 1b1b / Modified compliance pattern / EIEOS(EIE -> SKP is SRIS) sending timing
    mcmp_1b1b_hit_t                      mcmp_1b1b_skp_hit ;                     // 1b1b / Modified compliance pattern / SKP sending  timing
    logic                                mcmp_1b1b_any_hit ;                     // 1b1b / Modified compliance pattern / SKP or EIEOS sending timing
    logic [2:0]                          mcmp_1b1b_eie_shift_qw ;                // 1b1b / Modified compliance pattern / sending EIEOS(EIE -> SKP is SRIS) shift number(QW unit)
    logic [2:0]                          mcmp_1b1b_skp_shift_qw ;                // 1b1b / Modified compliance pattern / sending EIEOS(EIE -> SKP is SRIS) shift number(QW unit)
    logic [7:0]                          osblock_syncheader_8sunit ;             // Indicated OS Syncheder 8s unit fo Gen6 M comp
    logic [7:0]                          datablock_syncheader_8sunit ;           // Indicated Data Syncheder 8s unit fo Gen6 M comp
    logic                                mcmp_gen6_skp_det ;                     // Detect Gen6 SKP in Modified compliance pattern
    logic                                mcmp_gen6_skp_det_lat ;                 // latched mcmp_gen6_skp_det
    logic [5:0]                          mcmp_gen6_skp_cnt ;                     // Count sent SKP byte in Modified compliance pattern.

    logic [NL-1:0][NBLOCK*128-1:0]       crnt_cmp_pat ;                          // Current Grant Pattern Data
    logic [NL-1:0][NBLOCK*16-1:0]        crnt_cmp_pat_k ;                        // Current Grant Pattern K code
    logic [NL-1:0][NBLOCK*16-1:0]        crnt_cmp_ossending ;                    // Current Grant OS Flag 
    logic [NL-1:0][NBLOCK*16-1:0]        crnt_cmp_skpend_bm ;                    // SKP END position byte map for Current Grant
    logic [NL-1:0][NBIT-1:0]             shift_cmp_data ;                        // Shift Pattern Data for data width alignment
    logic [NL-1:0][NBK-1:0]              shift_cmp_datak ;                       // Shift Pattern DataK for data width alignment
    logic [NL-1:0][NBLOCK*16-1:0]        shift_cmp_ossending ;                   // Shift pattern Sending OS Flag 
    logic [NL-1:0][NBLOCK*16-1:0]        shift_cmp_skpend_bm ;                   // SKP END position byte map for Current Grant after data width alignmen

    logic [63:0]                         normal_cmp_seq_8b10b ;                  // Compliance pattern Normal sequence for 8b/10b
    logic [63:0]                         delayd_cmp_seq_8b10b ;                  // Compliance pattern Delayed sequence for 8b/10b
    logic [127:0]                        normal_mcmp_seq_8b10b ;                 // Modified Compliance pattern Normal sequence for 8b/10b
    logic [127:0]                        delayd_mcmp_seq_8b10b ;                 // Modified Compliance pattern Delayed sequence for 8b/10b
    logic [7:0]                          normal_cmp_seq_8b10b_k ;                // Compliance pattern Normal sequence for 8b/10b (K Code)
    logic [7:0]                          delayd_cmp_seq_8b10b_k ;                // Compliance pattern Delayed sequence for 8b/10b (K Code)
    logic [15:0]                         normal_mcmp_seq_8b10b_k ;               // Modified Compliance pattern Normal sequence for 8b/10b (K Code)
    logic [15:0]                         delayd_mcmp_seq_8b10b_k ;               // Modified Compliance pattern Delayed sequence for 8b/10b (K Code)
    logic [NL-1:0]                       mcmp_pattern_loc_row ;                  // Pattern Lock bit (not timing adjusted) of Modified pattern Gen1/2
    logic [NL-1:0]                       mcmp_pattern_loc_show ;                 // Pattern Lock bit (timing adjusted) of Modified pattern Gen1/2
    logic [NL-1:0][6:0]                  mcmp_err_cnt_row ;                      // Error count (not timing adjusted) for Modified pattern Gen1/2
    logic [NL-1:0][6:0]                  mcmp_err_cnt_show ;                     // Error count (timing adjusted) for Modified pattern Gen1/2

    logic [127:0]                        cmp_pat1_128b130b ;                     // Compliannce pattern 1 common in all lanes : 128b/130b
    logic [7:0][127:0]                   cmp_pat2_mod8_128b130b ;                // Compliannce pattern 2 depends on lane number mode 8 : 128b/130b
    logic [7:0][127:0]                   cmp_pat3_mod8_128b130b ;                // Compliannce pattern 2 depends on lane number mode 8 : 128b/130b
    logic [127:0]                        jitter_msrmnt_128b130b ;                // Jitter Measurement pattern common in all lanes : 128b/130b
    logic [NL-1:0]                       jitter_ptn_en_128b130b ;                // Jitter measurement pattern sending enable (per-lane) : 128b/130b
    logic [NL-1:0][7:0]                  skp_err_cnt_show ;                      // Error count (timing adjusted) for Modified pattern SKP OS : : 128b/130b
    logic [NL-1:0][127:0]                mcmp_skp_128b130b ;                     // SKP OS for Modified compliance pattern : 128b/130b

    logic [127:0]                        cmp_pat1_1b1b ;                        // Compliannce pattern 1 common in all lanes : 1b/1b
    logic [127:0]                        cmp_pat2_1b1b ;                        // Compliannce pattern 2 common in all lanes : 1b/1b
    logic [127:0]                        cmp_pat3_1b1b ;                        // Compliannce pattern 1 common in all lanes : 1b/1b
    logic [7:0][127:0]                   cmp_pat4_mod8_1sthalf_1b1b ;           // Compliannce pattern 4 depends on lane number mode 8 1st 128Byte : 1b/1b
    logic [7:0][127:0]                   cmp_pat4_mod8_2ndhalf_1b1b ;           // Compliannce pattern 4 depends on lane number mode 8 2nd 128Byte : 1b/1b
    logic [127:0]                        cmp_pat7_1b1b ;                        // Compliannce pattern 7 common in all lanes : 1b/1b
    logic [127:0]                        cmp_pat8_1b1b ;                        // Compliannce pattern 8 common in all lanes : 1b/1b
    logic [104*concate_num_1b_jit -1:0]  jitter_msrmnt_1b1b ;                   // Jitter Measurement pattern common in all lanes : 1b/1b
    logic [127:0]                        cmp_hswing_1b1b ;                      // High swing toggle pattern common in all lanes : 1b/1b
    logic [127:0]                        cmp_lswing_1b1b ;                      // Low  swing toggle pattern common in all lanes : 1b/1b
    logic [NL-1:0]                       hswing_ptn_en_1b1b ;                   // High swing pattern sending enable (per-lane) : 1b/1b
    logic                                lswing_ptn_en_1b1b ;                   // Low  swing toggle pattern common in all lanes : 1b/1b
    logic [3:0]                          shift_jitter_msrmnt_1b1b ;             // Shift Jitter Measuremnt pattern. Because the pattern length is 104bit not divied to bus width.
    logic [17:0]                         for_loop_cmp_send_block_num ;          // Sending Block Num for loop statement
    logic [NL-1:0][319:0]                mcmp_skp_1b1b ;                        // SKP OS for Modified compliance pattern : 1b/1b
    logic [3:0]                          skp_parity_type_1b1b ;                 // Phy Payload type, Parity bits of SKP OS : 1b/1b
    logic [NL-1:0][23:0]                 skp_payload_1b1b ;                     // Payload bits of SKP OS : 1b/1b
    logic [(NBLOCK*2)-1:0]               mcmp_1b1b_startblock_qw ;              // QW unit Startblock for Gen6 Modified Compliance pattern.
    logic [(NBLOCK*2)-1:0]               mcmp_1b1b_startblock_qw_lat ;          // QW unit Startblock for Gen6 Modified Compliance pattern.
    logic [NQW-1:0]                      shift_mcmp_1b1b_startblock_qw ;        // QW unit Startblock for Gen6 Modified Compliance pattern.

    logic                                cmp_txcompliance ;                     // PIPE TxCompliance : Assert when 1st cycle of Gen1/2 Compliance pattern
    logic [NL-1:0]                       turnoff_txcompliace ;                  // PIPE TxCompliance : Turn of lanes.
    logic                                latched_xmtbyte_gen6_compliance_sending ;     // indicates sending Gen6 (Modified) compliance pattern


// --- Set fix value to input signals which are not exist by configuration.



// -----------------------------------
//  Common signals
// -----------------------------------

// --- Set fix value to input signals which are not exist by configuration.


    // Common signals
    always_comb begin
        next_grnt_is_cmp                 = next_grant[G_CMP_BIT]  | next_grant[G_MCMP_BIT] ;
    end


    // Make delay signals
    always_ff @(posedge core_clk or negedge core_rst_n) begin : delay_PROC
        if (!core_rst_n) begin
            crnt_grnt_is_cmp            <= #TP '0 ;
        end
        else begin
            crnt_grnt_is_cmp            <= #TP next_grnt_is_cmp ;
        end
    end


// -----------------------------------
//  Data Mux
// -----------------------------------

// Mux by Rate
    always_comb begin
        crnt_rate_cmp_pat =                                crnt_rate.enc_1b1b     ? enc_1b1b :
                                crnt_rate.enc_128b130b ? enc_128b130b :
                                                         enc_8b10b ;
    end

// Mux by Pattern
    always_comb begin
        for(int ii = 0 ; ii < NL ; ii++ ) begin
            case( crnt_grant )
                G_CMP_PTN     : begin
                                    crnt_cmp_pat[ii]         = crnt_rate_cmp_pat.cmp_pat[ii] ;
                                    crnt_cmp_pat_k[ii]       = crnt_rate_cmp_pat.cmp_pat_k[ii] ;
                                    crnt_cmp_ossending[ii]   = crnt_rate_cmp_pat.cmp_ossending[ii] ;
                                    crnt_cmp_skpend_bm[ii]   = crnt_rate_cmp_pat.cmp_skpend_bm[ii] ;
                                end
                G_MCMP_PTN    : begin
                                    crnt_cmp_pat[ii]         = crnt_rate_cmp_pat.mcmp_pat[ii] ;
                                    crnt_cmp_pat_k[ii]       = crnt_rate_cmp_pat.mcmp_pat_k[ii] ;
                                    crnt_cmp_ossending[ii]   = crnt_rate_cmp_pat.mcmp_ossending[ii] ;
                                    crnt_cmp_skpend_bm[ii]   = crnt_rate_cmp_pat.mcmp_skpend_bm[ii] ;
                                end
                default       : begin
                                    crnt_cmp_pat[ii]         = '0 ;
                                    crnt_cmp_pat_k[ii]       = '0 ;
                                    crnt_cmp_ossending[ii]   = '0 ;
                                    crnt_cmp_skpend_bm[ii]   = '0 ;
                                end
           endcase
       end
    end



// -----------------------------------
//  Data width alignment
// -----------------------------------

// cmp_byte_count indicated how many OS bytes are sent
    always_ff @(posedge core_clk or negedge core_rst_n) begin : cmp_byte_count_PROC
        if (!core_rst_n) begin
            cmp_byte_count             <= #TP '0 ;
        end
        else begin
            if( ~crnt_grnt_is_cmp || cmp_block_done_int ) begin
                cmp_byte_count           <= #TP '0 ;
            end
            else if( internal_txdata_dv ) begin 
                cmp_byte_count           <= #TP $bits(cmp_byte_count)'( cmp_byte_count + active_nb ) ;
            end
        end
    end
    
logic [6:0] tmp_sht4type;
   assign tmp_sht4type = 6 * cmp_byte_count[3:0];
// Data width alignment
    always_comb begin
        for(int ii = 0 ; ii < NL ; ii++ ) begin
            shift_cmp_data[ii]           = (NBIT)'( crnt_cmp_pat[ii]   >> ( {cmp_byte_count[3:0] , 3'd0} ) ) ;
            shift_cmp_datak[ii]          = ( crnt_rate.enc_8b10b
                                            | (crnt_rate.enc_1b1b & crnt_grant[G_MCMP_BIT] & mcmp_1b1b_any_hit)
                                                                                                                    ) ? (NBK)'( crnt_cmp_pat_k[ii] >> ( cmp_byte_count[3:0]) ) 
                                                                                                                      : (NBK)'( crnt_cmp_pat_k[ii] );
            shift_cmp_ossending[ii]      = 
                                            (crnt_rate.enc_1b1b & crnt_grant[G_MCMP_BIT]) ? (NBLOCK*16)'( crnt_cmp_ossending[ii] >> ( {cmp_byte_count[3] , 3'd0} ) ) :    // Shift per QWord(8byte)
                                             crnt_cmp_ossending[ii] ;
                  
            shift_cmp_skpend_bm[ii]      = $bits(shift_cmp_skpend_bm[0])'( crnt_cmp_skpend_bm[ii] >> (cmp_byte_count[3:0]) ) ;

            
            cmp_gen_data[ii]             = shift_cmp_data[ii]  & active_nb_bitmap ;
            cmp_gen_datak[ii]            = shift_cmp_datak[ii] & active_nb_bitmapk ;

            for( int jj = 0 ; jj < NBLOCK ; jj++ ) begin
                cmp_gen_ossending[ii][jj]     = (OSFLG_WD)'( shift_cmp_ossending[ii][jj*16 +: 8] ) ;                          // Just check 8byte because Gen6 Modified pattern has this flags per-8byte data
                cmp_gen_ossending[ii][jj][1]  = |( shift_cmp_skpend_bm[ii][jj*16 +: 16] & (16)'( active_nb_bytemap ) ) ;      // For SKP End Flag just assert SKP END sending is in progress.
            end
        end
        
        shift_mcmp_1b1b_startblock_qw   = $bits(shift_mcmp_1b1b_startblock_qw)'( mcmp_1b1b_startblock_qw >> cmp_byte_count[3] ) ;     // QW(8byte) shift or no shift.
      
    end


// -----------------------------------
//  Control signals
// -----------------------------------

// Next sending Pattern block Size (Byte) / current Pattern sending size - current active_nb
    always_comb begin
        next_cmp_block_size              =                                                crnt_rate.enc_1b1b     ? G6_BLOCK_SIZE :    // Gen6. if 32s:32 / else:16
                                                crnt_rate.enc_128b130b ? 6'd16 :            // Gen3-5, 1 Data Block
                                                next_grant[G_MCMP_BIT] ? 6'd16              // Gen1/2 Modified pattern
                                                                       : 6'd8  ;            // Gen1/2 Normal pattern
    end

    always_ff @(posedge core_clk or negedge core_rst_n) begin : crnt_cmp_block_size_minus_nb_PROC
        if (!core_rst_n) begin
            crnt_cmp_block_size_minus_nb          <= #TP '0 ;
        end
        else begin
            if( next_cmp_block_size <= $bits(next_cmp_block_size)'( active_nb ) ) crnt_cmp_block_size_minus_nb      <= #TP '0 ;
            else                                                                  crnt_cmp_block_size_minus_nb      <= #TP $bits(crnt_cmp_block_size_minus_nb)'( next_cmp_block_size - active_nb ) ;
        end
    end

// The number of Phase this pattern have
    always_comb begin
        if( crnt_grant[G_MCMP_BIT] & crnt_rate.enc_128b130b ) begin
            if( sris_mode_on )   crnt_cmp_phase_num      =  PHASE_NUM_128b130b_SRIS - 1;     // SRIS Modifiedd pattern Gen3/4/5
            else                 crnt_cmp_phase_num      =  PHASE_NUM_128b130b_CCLK - 1;     // Common Clock Modifiedd pattern Gen3/4/5
        end
        else                     crnt_cmp_phase_num      =  1'b0 ;                     // Other 1 Phase
    end

// The number of Block this Phase have
    always_ff @(posedge core_clk or negedge core_rst_n) begin : crnt_cmp_block_num_PROC
        if (!core_rst_n) begin
            crnt_cmp_block_num                 <= #TP '0 ;
            crnt_cmp_block_num_minus1          <= #TP '0 ;
            crnt_cmp_block_num_minus_g6qw      <= #TP '0 ;
        end
        else begin
            if( ~crnt_grnt_is_cmp || cmp_all_phase_done ) begin                                     // For Phase 0
                if( next_grant[G_CMP_BIT] ) begin                                                             // Normal Compliance pattern
                         if( crnt_rate.enc_8b10b )           crnt_cmp_block_num                 <= #TP CMPSQ_BLOCK_NUM_8b10b - 1 ;                  // Gen1/2 
                    else if( crnt_rate.one_hot[GEN5_BIT] )   crnt_cmp_block_num                 <= #TP CMPSQ_BLOCK_NUM_G5 - 1 ;                     // Gen5 
                    else if( crnt_rate.enc_128b130b   )      crnt_cmp_block_num                 <= #TP CMPSQ_BLOCK_NUM_G3G4 - 1 ;                   // Gen3/4
                    else                                     crnt_cmp_block_num                 <= #TP CMPSQ_BLOCK_NUM_1b1b - 1 ;                   // Gen6 or higher
                end 
                else if( next_grant[G_MCMP_BIT] ) begin
                    if( ~sris_mode_on ) begin                                                       // Modified Compliance pattern (Common Clock)
                             if( crnt_rate.enc_8b10b )           crnt_cmp_block_num             <= #TP MCMPSQ_BLOCK_NUM_8b10b - 1 ;                 // Gen1/2 
                        else if( crnt_rate.one_hot[GEN5_BIT] )   crnt_cmp_block_num             <= #TP MCMPSQ_BLOCK_NUM_G5_CCLK_PHASE0 - 1 ;        // Gen5 
                        else if( crnt_rate.enc_128b130b   )      crnt_cmp_block_num             <= #TP MCMPSQ_BLOCK_NUM_G3G4_CCLK_PHASE0 - 1 ;      // Gen3/4
                        else begin
                                                                 crnt_cmp_block_num             <= #TP MCMPSQ_QW_NUM_1b1b_CCLK ;                    // Gen6 or higher (QW Size of all pattern)
                                                                 crnt_cmp_block_num_minus1      <= #TP MCMPSQ_QW_NUM_1b1b_CCLK - 1;                 // Gen6 or higher (QW Size of all pattern)
                                                                 crnt_cmp_block_num_minus_g6qw  <= #TP MCMPSQ_QW_NUM_1b1b_CCLK - G6_BLOCK_QW_SIZE;  // Gen6 or higher (QW Size of all pattern)
                        end
                    end
                    else begin                                                                     // Modified Compliance pattern (SRIS)
                             if( crnt_rate.enc_8b10b )           crnt_cmp_block_num             <= #TP MCMPSQ_BLOCK_NUM_8b10b - 1 ;                 // Gen1/2 
                        else if( crnt_rate.one_hot[GEN5_BIT] )   crnt_cmp_block_num             <= #TP MCMPSQ_BLOCK_NUM_G5_SRIS_PHASE0 - 1 ;        // Gen5 
                        else if( crnt_rate.enc_128b130b   )      crnt_cmp_block_num             <= #TP MCMPSQ_BLOCK_NUM_G3G4_SRIS_PHASE0 - 1 ;      // Gen3/4
                        else begin
                                                                 crnt_cmp_block_num             <= #TP MCMPSQ_QW_NUM_1b1b_SRIS ;                    // Gen6 or higher (QW Size of all pattern)
                                                                 crnt_cmp_block_num_minus1      <= #TP MCMPSQ_QW_NUM_1b1b_SRIS - 1;                 // Gen6 or higher (QW Size of all pattern)
                                                                 crnt_cmp_block_num_minus_g6qw  <= #TP MCMPSQ_QW_NUM_1b1b_SRIS - G6_BLOCK_QW_SIZE;  // Gen6 or higher (QW Size of all pattern)
                        end
                    end 
                end
            end
            else if( cmp_phase_done ) begin                                                         // For Phase1 or later (Only Modified pattern Gen3/4/5)
                if( next_grant[G_MCMP_BIT] && crnt_rate.enc_128b130b ) begin                                       // Modified Compliance pattern (Common Clock)
                         if( ~sris_mode_on )      crnt_cmp_block_num      <= #TP MCMPSQ_BLOCK_NUM_128b130b_CCLK_PHASE1 - 1 ;                // Gen3/4/5 Common CLK
                    else                          crnt_cmp_block_num      <= #TP MCMPSQ_BLOCK_NUM_128b130b_SRIS_PHASE1 - 1 ;                // Gen3/4/5 SRIS
                end 
            end
        end
    end

// Phase Flag
    always_comb begin
        cmp_block_done_int       = (cmp_byte_count == crnt_cmp_block_size_minus_nb) & crnt_grnt_is_cmp & internal_txdata_dv ;
        cmp_block_done           = cmp_block_done_int 
                                 & (mcmp_1b1b_eie_hit == NOT_HIT) & ( mcmp_1b1b_skp_hit == NOT_HIT )
                                 ;
        
        cmp_phase_done           = cmp_block_done_int & ( (cmp_send_block_num == crnt_cmp_block_num) | mcmp_send_ovrflw_1b1b 
                                                        ) ;
        
        cmp_all_phase_done       = cmp_phase_done & (cmp_send_phase_num == crnt_cmp_phase_num) ; 
    end

// Block Count
    // For Gen6 modified compliance pattern.
    // We need to support 32s for Gen6 and Gen6 SKP OS is special length(40byte).
    // So, total modified complace pattern size is not diveded to 16s or 32s(Bus width). We need to shift the pattern...
    always_comb begin
        added_mcmp_send_qw_num_1b1b    = (crnt_rate.enc_1b1b & crnt_grant[G_MCMP_BIT] & cmp_block_done_int ) ? cmp_send_block_num_plus_g6qw : cmp_send_block_num ;
        
        mcmp_send_ovrflw_1b1b          = ( added_mcmp_send_qw_num_1b1b >= crnt_cmp_block_num ) ;
        
        next_mcmp_send_qw_num_1b1b     = ~mcmp_send_ovrflw_1b1b ?  added_mcmp_send_qw_num_1b1b
                                                                : $bits(next_mcmp_send_qw_num_1b1b)'(added_mcmp_send_qw_num_1b1b - crnt_cmp_block_num) ;
    end
    
    always_ff @(posedge core_clk or negedge core_rst_n) begin : cmp_send_block_num_PROC
        if (!core_rst_n) begin
            cmp_send_block_num             <= #TP '0 ;
            cmp_send_block_num_plus1       <= #TP 'd1 ;
            cmp_send_block_num_plus_g6qw   <= #TP $bits(cmp_send_block_num_plus_g6qw)'(G6_BLOCK_QW_SIZE) ;
        end
        else begin
            if( ~crnt_grnt_is_cmp && ~crnt_grant[G_SKP_BIT] ) begin
                cmp_send_block_num          <= #TP '0 ;
                cmp_send_block_num_plus1    <= #TP 'd1 ;
                cmp_send_block_num_plus_g6qw   <= #TP $bits(cmp_send_block_num_plus_g6qw)'(G6_BLOCK_QW_SIZE) ;
            end
            else if( cmp_block_done_int ) begin
                if( crnt_rate.enc_1b1b && crnt_grant[G_MCMP_BIT] ) begin
                    cmp_send_block_num           <= #TP next_mcmp_send_qw_num_1b1b ;
                    cmp_send_block_num_plus1     <= #TP ~mcmp_send_ovrflw_1b1b ? $bits(cmp_send_block_num_plus_g6qw)'(added_mcmp_send_qw_num_1b1b + 1'b1)
                                                                               : $bits(cmp_send_block_num_plus_g6qw)'(added_mcmp_send_qw_num_1b1b - crnt_cmp_block_num_minus1) ;
                    cmp_send_block_num_plus_g6qw <= #TP ~mcmp_send_ovrflw_1b1b ? $bits(cmp_send_block_num_plus_g6qw)'(added_mcmp_send_qw_num_1b1b + G6_BLOCK_QW_SIZE)
                                                                               : $bits(cmp_send_block_num_plus_g6qw)'(added_mcmp_send_qw_num_1b1b - crnt_cmp_block_num_minus_g6qw) ;
                end
                else begin
                    cmp_send_block_num          <= #TP ( cmp_send_block_num       == crnt_cmp_block_num     ) ? 'd0
                                                                                                              : $bits(cmp_send_block_num)'( cmp_send_block_num + 1'b1 ) ;
                    cmp_send_block_num_plus1    <= #TP 'd1 ;         // not used
                end
            end
        end
    end


// Phase Count
    always_ff @(posedge core_clk or negedge core_rst_n) begin : cmp_send_phase_num_PROC
        if (!core_rst_n) begin
            cmp_send_phase_num          <= #TP '0 ;
        end
        else begin
            if( ~crnt_grnt_is_cmp || cmp_all_phase_done ) begin
                cmp_send_phase_num          <= #TP '0 ;
            end
            else if( cmp_phase_done ) begin
                cmp_send_phase_num          <= #TP $bits(cmp_send_phase_num)'( cmp_send_phase_num + 1'b1 ) ;
            end
        end
    end


// Gen6 modified compliance pattern SKP/EIE OS insertion point.
    // 1st EIEOS (Common CLK) / 1st EIEOS->SKP OS(SRIS)
    always_comb begin
        mcmp_1b1b_eie_point         = '0 ;
        mcmp_1b1b_any_hit           = (mcmp_1b1b_eie_hit != NOT_HIT) | (mcmp_1b1b_skp_hit != NOT_HIT) ;
    end

    // Looping SKP (Common CLK) / 2nd or later looping SKP OS(SRIS)
    always_ff @(posedge core_clk or negedge core_rst_n) begin : mcmp_1b1b_skp_point_PROC
        if (!core_rst_n) begin
            mcmp_1b1b_skp_point          <= #TP '0 ;      
        end
        else begin
            if( ~crnt_rate.enc_1b1b || ~crnt_grant[G_MCMP_BIT] || cmp_all_phase_done ) begin
                mcmp_1b1b_skp_point          <= #TP sris_mode_on ? 18'd71         // Before SKP : EIOS(1block(2QW) , SKP(5QW) , 0x0(2QW*32) (0's base)
                                                                 : 18'd514 ;      // Before SKP : EIOS(1block(2QW) , 0x0(2QW*256) (0's base)
            end
            else if( (cmp_send_block_num >= (mcmp_1b1b_skp_point + 5)) ) begin   // SKP is 5QW(40Byte)
                if( sris_mode_on ) mcmp_1b1b_skp_point          <= #TP ( (mcmp_1b1b_skp_point + 18'd69 ) >= MCMPSQ_QW_NUM_1b1b_SRIS ) ? 18'd71  : $bits(mcmp_1b1b_skp_point)'( mcmp_1b1b_skp_point + 18'd69 ) ;
                else               mcmp_1b1b_skp_point          <= #TP ( (mcmp_1b1b_skp_point + 18'd517) >= MCMPSQ_QW_NUM_1b1b_CCLK ) ? 18'd514 : $bits(mcmp_1b1b_skp_point)'( mcmp_1b1b_skp_point + 18'd517 ) ;
            end
        end
    end

    // Hit 1st EIEOS insertion
    always_ff @(posedge core_clk or negedge core_rst_n) begin : mcmp_1b1b_eie_hit_PROC
        if (!core_rst_n) begin
            mcmp_1b1b_eie_hit          <= #TP NOT_HIT ;      
            mcmp_1b1b_eie_shift_qw     <= #TP '0 ; 
        end
        else begin
            if( ~crnt_rate.enc_1b1b || ~next_grant[G_MCMP_BIT] ) begin
                mcmp_1b1b_eie_hit          <= #TP NOT_HIT ;      
                mcmp_1b1b_eie_shift_qw     <= #TP '0 ; 
            end
            else if( (crnt_cmp_block_num - added_mcmp_send_qw_num_1b1b) < G6_BLOCK_QW_SIZE ) begin   // Hit and shift Left(Upper QW have EIE)
                mcmp_1b1b_eie_hit         <= #TP SHIFT_LEFT ; 
                mcmp_1b1b_eie_shift_qw    <= #TP $bits(mcmp_1b1b_eie_shift_qw)'( crnt_cmp_block_num - added_mcmp_send_qw_num_1b1b ) ; 
            end                                                                                         // Hit and shift Left(Lower QW have EIE)
            else if(  (  sris_mode_on && (next_mcmp_send_qw_num_1b1b < 18'd7) )                         // SRIS         : EIE->SKP sending
                   || ( ~sris_mode_on && (next_mcmp_send_qw_num_1b1b < 18'd2) )  ) begin                // Common Clock : EIE      sending
                mcmp_1b1b_eie_hit         <= #TP SHIFT_RIGHT ; 
                mcmp_1b1b_eie_shift_qw    <= #TP $bits(mcmp_1b1b_eie_shift_qw)'( next_mcmp_send_qw_num_1b1b ) ; 
            end
            else begin
                mcmp_1b1b_eie_hit          <= #TP NOT_HIT ;      
            end
        end
    end

    // Hit looping SKP insertion
    always_ff @(posedge core_clk or negedge core_rst_n) begin : mcmp_1b1b_skp_hit_PROC
        if (!core_rst_n) begin
            mcmp_1b1b_skp_hit          <= #TP NOT_HIT ;      
            mcmp_1b1b_skp_shift_qw     <= #TP '0 ; 
        end
        else begin
            if( ~crnt_rate.enc_1b1b || ~next_grant[G_MCMP_BIT] ) begin
                mcmp_1b1b_skp_hit          <= #TP NOT_HIT ;      
                mcmp_1b1b_skp_shift_qw     <= #TP '0 ; 
            end
            else if( (mcmp_1b1b_skp_point - added_mcmp_send_qw_num_1b1b) < G6_BLOCK_QW_SIZE ) begin   // Hit and shift Left(Upper QW have SKP)
                mcmp_1b1b_skp_hit         <= #TP SHIFT_LEFT ; 
                mcmp_1b1b_skp_shift_qw    <= #TP $bits(mcmp_1b1b_skp_shift_qw)'( mcmp_1b1b_skp_point - added_mcmp_send_qw_num_1b1b ) ; 
            end
            else if( (added_mcmp_send_qw_num_1b1b - mcmp_1b1b_skp_point) < 18'd5 ) begin             // Hit and shift Right(Lower QW have SKP)
                mcmp_1b1b_skp_hit         <= #TP SHIFT_RIGHT ; 
                mcmp_1b1b_skp_shift_qw    <= #TP $bits(mcmp_1b1b_skp_shift_qw)'( added_mcmp_send_qw_num_1b1b - mcmp_1b1b_skp_point ) ; 
            end
            else begin
                mcmp_1b1b_skp_hit          <= #TP NOT_HIT ;      
            end
        end
    end


// ---------------------------------------------
//  (Modified) Compliance pattern Data
// ---------------------------------------------


// Loading OS field timing from LTSSM


// ------------------
// ---- 8b/10b ------
// ------------------

    // Common in all lanes pattern
    always_comb begin
                                   //     D10.2 ,  COM     ,  D21.5  ,  COM
        normal_cmp_seq_8b10b     = { {2{`D102_8B, `COMMA_8B, `D215_8B, `COMMA_8B}} } ;
        normal_cmp_seq_8b10b_k   = { {2{   1'b0 ,  1'b1    ,  1'b0   ,  1'b1    }} } ;

                                  //  COM*2(Sym7,6), D10.2 (Sym5), COM(Sym4), D21.5(Sym3),  COM*3(Sym2-0)
        delayd_cmp_seq_8b10b     = { {2{`COMMA_8B}}, `D102_8B    , `COMMA_8B, `D215_8B   , {3{`COMMA_8B}} }; 
        delayd_cmp_seq_8b10b_k   = {    2'b11      ,   1'b0      ,   1'b1   ,   1'b0     ,    3'b111      };

                                   //    COM*2(Sym7,6) , ERR(per-lane), D10.2(Sym3), COM(Sym2), D21.5(Sym1), COM(Sym0)
        normal_mcmp_seq_8b10b    = { {2{ {2{`COMMA_8B}},  16'b0       , `D102_8B   , `COMMA_8B, `D215_8B   , `COMMA_8B }} } ;
        normal_mcmp_seq_8b10b_k  = { {2{   2'b11       ,   2'b00      ,   1'b0     ,    1'b1  ,   1'b0     ,   1'b1    }} } ;

                                   // K28.7(EIE)(Sym15-12), COM*2(Sym11,10), ERR(per-lane), D10.2 (Sym7), COM(Sym6), D21.5(Sym4),  COM(Sym4-0)
        delayd_mcmp_seq_8b10b    = {    {4{`K287_8B}}     , {2{`COMMA_8B}} ,    16'b0     ,  `D102_8B   , `COMMA_8B, `D215_8B   , {5{`COMMA_8B}} } ;
        delayd_mcmp_seq_8b10b_k  = {      4'b1111         ,  2'b11         ,     2'b00    ,    1'b0     ,   1'b1   ,   1'b0     ,  5'b1_1111     } ;
    end

    // per-lane pattern
    always_comb begin
        for( int ii = 0 ; ii < NL ; ii++ ) begin
            if( cmp_send_block_num[2:0] == ii%8 ) begin  // delayed pattern
                enc_8b10b.cmp_pat[ii]                 =  $bits(enc_8b10b.cmp_pat[0]   )'( delayd_cmp_seq_8b10b ) ;
                enc_8b10b.cmp_pat_k[ii]               =  $bits(enc_8b10b.cmp_pat_k[0] )'( delayd_cmp_seq_8b10b_k ) ;
                enc_8b10b.mcmp_pat[ii]                =  $bits(enc_8b10b.mcmp_pat[0]  )'( delayd_mcmp_seq_8b10b ) ;
                enc_8b10b.mcmp_pat_k[ii]              =  $bits(enc_8b10b.mcmp_pat_k[0])'( delayd_mcmp_seq_8b10b_k ) ;

                enc_8b10b.mcmp_pat[ii][8*8 +: 16]     =  { 2{mcmp_pattern_loc_show[ii] , mcmp_err_cnt_show[ii]} } ;    // ERR field
            end
            else begin                                          // normal pattern
                enc_8b10b.cmp_pat[ii]                 =  $bits(enc_8b10b.cmp_pat[0]   )'( normal_cmp_seq_8b10b ) ;
                enc_8b10b.cmp_pat_k[ii]               =  $bits(enc_8b10b.cmp_pat_k[0] )'( normal_cmp_seq_8b10b_k ) ;
                enc_8b10b.mcmp_pat[ii]                =  $bits(enc_8b10b.mcmp_pat[0]  )'( normal_mcmp_seq_8b10b ) ;
                enc_8b10b.mcmp_pat_k[ii]              =  $bits(enc_8b10b.mcmp_pat_k[0])'( normal_mcmp_seq_8b10b_k ) ;

                enc_8b10b.mcmp_pat[ii][ 4*8 +: 16]    =  { 2{mcmp_pattern_loc_show[ii] , mcmp_err_cnt_show[ii]} } ;    // ERR field
                enc_8b10b.mcmp_pat[ii][12*8 +: 16]    =  { 2{mcmp_pattern_loc_show[ii] , mcmp_err_cnt_show[ii]} } ;    // ERR field
            end
            
            enc_8b10b.cmp_ossending[ii]               = '0 ;
            enc_8b10b.mcmp_ossending[ii]              = '0 ;
            enc_8b10b.cmp_skpend_bm[ii]               = '0 ;
            enc_8b10b.mcmp_skpend_bm[ii]              = '0 ;
        end
    end

   // Error field of Modified pattern
    always_ff @(posedge core_clk or negedge core_rst_n) begin : mcmp_pattern_loc_row_PROC
        if (!core_rst_n) begin
            for( int ii = 0 ; ii < NL ; ii++ ) begin
                mcmp_pattern_loc_row[ii]      <= #TP '0 ;
                mcmp_err_cnt_row[ii]          <= #TP '0 ;
            end
        end
        else begin
            if( ~crnt_grant[G_MCMP_BIT] && ~crnt_grant[G_SKP_BIT] ) begin
                for( int ii = 0 ; ii < NL ; ii++ ) begin
                    mcmp_pattern_loc_row[ii]    <= #TP '0 ;
                    mcmp_err_cnt_row[ii]        <= #TP '0 ;
                end
            end
            else begin 
                for( int ii = 0 ; ii < NL ; ii++ ) begin
                    mcmp_pattern_loc_row[ii]    <= #TP smlh_mcs_rcvd[ii] ? 1'b1 : mcmp_pattern_loc_row[ii] ;
                    mcmp_err_cnt_row[ii]        <= #TP (mcmp_pattern_loc_row[ii] & rpipe_rxerror[ii] & (mcmp_err_cnt_row[ii] != 7'h7F)) ? (7)'( mcmp_err_cnt_row[ii] + 1'b1 ) 
                                                                                                                                   : mcmp_err_cnt_row[ii] ;
                end
            end
        end
    end
   
   // Load error counter (In order to avoid to send different count number in same block when 1s.)
    always_ff @(posedge core_clk or negedge core_rst_n) begin : mcmp_err_cnt_show_PROC
        if (!core_rst_n) begin
            for( int ii = 0 ; ii < NL ; ii++ ) begin
                mcmp_pattern_loc_show[ii]         <= #TP '0 ;
                mcmp_err_cnt_show[ii]             <= #TP '0 ;
            end
        end
        else begin
            if( ~crnt_grant[G_MCMP_BIT] && ~crnt_grant[G_SKP_BIT] ) begin
                for( int ii = 0 ; ii < NL ; ii++ ) begin
                    mcmp_pattern_loc_show[ii]         <= #TP '0 ;
                    mcmp_err_cnt_show[ii]         <= #TP '0 ;
                end
            end
            else begin 
                for( int ii = 0 ; ii < NL ; ii++ ) begin
                    mcmp_pattern_loc_show[ii]   <= #TP   ( (cmp_send_block_num[2:0] != ii%8) & (cmp_byte_count[2]   == 1'b0) ) ? mcmp_pattern_loc_row[ii]    // Latch if Normal  pattern (Symbol0-3/11-8) (Error field is symbol4-5/12-13)
                                                       : ( (cmp_send_block_num[2:0] == ii%8) & (cmp_byte_count[5:3] == 3'h0))  ? mcmp_pattern_loc_row[ii]    // Latch if Delayed pattern (Symbol0-7)      (Error field is symbol8-9)
                                                                                                                               : mcmp_pattern_loc_show[ii] ; // keep
                    mcmp_err_cnt_show[ii]       <= #TP   ( (cmp_send_block_num[2:0] != ii%8) & (cmp_byte_count[2]   == 1'b0) ) ? mcmp_err_cnt_row[ii]        // Latch if Normal  pattern (Symbol0-3/11-8) (Error field is symbol4-5/12-13)
                                                       : ( (cmp_send_block_num[2:0] == ii%8) & (cmp_byte_count[5:3] == 3'h0))  ? mcmp_err_cnt_row[ii]        // Latch if Delayed pattern (Symbol0-7)      (Error field is symbol8-9)
                                                                                                                               : mcmp_err_cnt_show[ii] ;     // keep
                end
            end
        end
    end



        
// ----------------------
// ---- 128b/130b -------
// ----------------------

    // -------------------------------
    // Normal Compliance pattern
    // -------------------------------

    // Syncheader pattern
    always_comb begin
        for( int ii = 0 ; ii < NBLOCK ; ii++ ) begin
            osblock_syncheader[ii*16 +: 16]     = (16)'( `SYNC_OS_BLOCK   ) ;
            datablock_syncheader[ii*16 +: 16]   = (16)'( `SYNC_DATA_BLOCK ) ;
        end
    end

    // Common in all lanes pattern
    always_comb begin
        cmp_pat1_128b130b           = { {64{ 1'b0}} , {64{1'b1}} } ;
        jitter_msrmnt_128b130b      = { {16{8'h55}}              } ;
    end

    // Per-lane(Lane number mod 8) pattern
    always_comb begin
                                       //  Sym15 ------------------------ Sym8 , Sym7(per-lane) , Sym6 ---------------- Sym0
        cmp_pat2_mod8_128b130b[0]      = { {8{8'h00}}                          ,     8'h00      ,                    {7{8'h55}} } ;       // Lane0,8
        cmp_pat2_mod8_128b130b[1]      = { {7{8'h55}},                    8'h1E,     8'h00      , {5{8'h00}},        {2{8'hFF}} } ;       // Lane1,9
        cmp_pat2_mod8_128b130b[2]      = { {3{8'hFF}}, 8'h0F, {3{8'h00}}, 8'h2D,     8'h00      ,     8'h00 , 8'hC0, {5{8'hFF}} } ;       // Lane2,10
        cmp_pat2_mod8_128b130b[3]      = { {3{8'hFF}}, 8'h0F, {3{8'h00}}, 8'h3C,     8'h00      , {2{8'h00}}, 8'hC0, {4{8'hFF}} } ;       // Lane3,11
        cmp_pat2_mod8_128b130b[4]      = {   8'hFF   , 8'h7F, {5{8'h00}}, 8'h4B,     8'h00      ,                    {7{8'h55}} } ;       // Lane4,12
        cmp_pat2_mod8_128b130b[5]      = { {7{8'h55}},                    8'h5A,     8'h00      ,     8'h00 , 8'hE0, {5{8'hFF}} } ;       // Lane5,13
        cmp_pat2_mod8_128b130b[6]      = { {3{8'hFF}}, 8'h07, {3{8'h00}}, 8'h69,     8'h00      , {3{8'h00}}, 8'hF0, {3{8'hFF}} } ;       // Lane6,14
        cmp_pat2_mod8_128b130b[7]      = { {6{8'h00}}, 8'hF0,             8'h78,     8'h00      , {3{8'h00}}, 8'hF0, {3{8'hFF}} } ;       // Lane7,15

                                       //  Sym15 ------------------------ Sym8 , Sym7(per-lane) , Sym6 ---------------- Sym0
        cmp_pat3_mod8_128b130b[0]      = { {4{8'hFF}}, {4{8'h00}}              ,     8'h00      , {3{8'h00}}, 8'hF0, {3{8'hFF}} } ;       // Lane0,8
        cmp_pat3_mod8_128b130b[1]      = { {3{8'hFF}}, 8'h0F, {3{8'h00}}, 8'h1E,     8'h00      , {3{8'h00}}, 8'hF0, {3{8'hFF}} } ;       // Lane1,9
        cmp_pat3_mod8_128b130b[2]      = { {3{8'hFF}}, 8'h0F, {3{8'h00}}, 8'h2D,     8'h00      ,                    {7{8'h55}} } ;       // Lane2,10
        cmp_pat3_mod8_128b130b[3]      = { {7{8'h55}},                    8'h3C,     8'h00      , {3{8'h00}}, 8'hF0, {3{8'hFF}} } ;       // Lane3,11
        cmp_pat3_mod8_128b130b[4]      = { {3{8'hFF}}, 8'h0F, {3{8'h00}}, 8'h4B,     8'h00      , {3{8'h00}}, 8'hF0, {3{8'hFF}} } ;       // Lane4,12
        cmp_pat3_mod8_128b130b[5]      = { {3{8'hFF}}, 8'h0F, {3{8'h00}}, 8'h5A,     8'h00      , {3{8'h00}}, 8'hF0, {3{8'hFF}} } ;       // Lane5,13
        cmp_pat3_mod8_128b130b[6]      = { {3{8'hFF}}, 8'h0F, {3{8'h00}}, 8'h69,     8'h00      ,                    {7{8'h55}} } ;       // Lane6,14
        cmp_pat3_mod8_128b130b[7]      = { {7{8'h55}},                    8'h78,     8'h00      , {3{8'h00}}, 8'hF0, {3{8'hFF}} } ;       // Lane7,15
    end


   // Jitter measurement pattern sending enable (per-lane) 
    always_ff @(posedge core_clk or negedge core_rst_n) begin : jitter_ptn_en_128b130b_PROC
        if (!core_rst_n) begin
            jitter_ptn_en_128b130b             <= #TP '0 ;
        end
        else begin
            if( next_grant[G_CMP_BIT] ) begin
                for( int ii = 0 ; ii < NL ; ii++ ) begin
                                              if( ii%8 == 3'h0 ) jitter_ptn_en_128b130b[ii]      <= #TP (ltssm_gen4_compliance_jmp inside { 4'b0001 , 4'b0010 }) ;          // For Lane0/8
   else if( ii%8 == 3'h1 ) jitter_ptn_en_128b130b[ii]      <= #TP (ltssm_gen4_compliance_jmp inside { 4'b0001 , 4'b0011 }) ;  // For Lane1/9
   else if( ii%8 == 3'h2 ) jitter_ptn_en_128b130b[ii]      <= #TP (ltssm_gen4_compliance_jmp inside { 4'b0001 , 4'b0100 }) ;  // For Lane2/10
   else if( ii%8 == 3'h3 ) jitter_ptn_en_128b130b[ii]      <= #TP (ltssm_gen4_compliance_jmp inside { 4'b0001 , 4'b0101 }) ;  // For Lane3/11
   else if( ii%8 == 3'h4 ) jitter_ptn_en_128b130b[ii]      <= #TP (ltssm_gen4_compliance_jmp inside { 4'b0001 , 4'b0110 }) ;  // For Lane4/12
   else if( ii%8 == 3'h5 ) jitter_ptn_en_128b130b[ii]      <= #TP (ltssm_gen4_compliance_jmp inside { 4'b0001 , 4'b0111 }) ;  // For Lane5/13
   else if( ii%8 == 3'h6 ) jitter_ptn_en_128b130b[ii]      <= #TP (ltssm_gen4_compliance_jmp inside { 4'b0001 , 4'b1000 }) ;  // For Lane6/14
   else if( ii%8 == 3'h7 ) jitter_ptn_en_128b130b[ii]      <= #TP (ltssm_gen4_compliance_jmp inside { 4'b0001 , 4'b1001 }) ;  // For Lane7/15
                end
            end
        end
    end
    
    // Per-lane pattern (Normal Compliance pattern)
    always_comb begin
        for( int ii = 0 ; ii < NL ; ii++ ) begin
            case( cmp_send_block_num[5:0] )
                6'd0   : begin
                          enc_128b130b.cmp_pat[ii]           = $bits(enc_128b130b.cmp_pat[0]      )'( cmp_pat1_128b130b ) ;
                          enc_128b130b.cmp_pat_k[ii]         = $bits(enc_128b130b.cmp_pat_k[0]    )'( osblock_syncheader ) ;
                          enc_128b130b.cmp_ossending[ii]     = $bits(enc_128b130b.cmp_ossending[0])'( OSFLG_IDLE ) ;
                         end
                6'd1   : begin
                          enc_128b130b.cmp_pat[ii]           = $bits(enc_128b130b.cmp_pat[0]      )'( cmp_pat2_mod8_128b130b[ii%8] ) ;
                          enc_128b130b.cmp_pat_k[ii]         = $bits(enc_128b130b.cmp_pat_k[0]    )'( osblock_syncheader ) ;
                          enc_128b130b.cmp_ossending[ii]     = $bits(enc_128b130b.cmp_ossending[0])'( OSFLG_IDLE ) ;
                         end
                6'd2   : begin
                          enc_128b130b.cmp_pat[ii]           = $bits(enc_128b130b.cmp_pat[0]      )'( cmp_pat3_mod8_128b130b[ii%8] ) ;
                          enc_128b130b.cmp_pat_k[ii]         = $bits(enc_128b130b.cmp_pat_k[0]    )'( osblock_syncheader ) ;
                          enc_128b130b.cmp_ossending[ii]     = $bits(enc_128b130b.cmp_ossending[0])'( OSFLG_IDLE ) ;
                         end
                6'd3   : begin
                          enc_128b130b.cmp_pat[ii]           = $bits(enc_128b130b.cmp_pat[0]      )'( eie_pat_128b130b ) ;
                          enc_128b130b.cmp_pat_k[ii]         = $bits(enc_128b130b.cmp_pat_k[0]    )'( osblock_syncheader ) ;
                          enc_128b130b.cmp_ossending[ii]     = $bits(enc_128b130b.cmp_ossending[0])'( OSFLG_EIE ) ;
                         end
                6'd4   : begin
                          enc_128b130b.cmp_pat[ii]           = crnt_rate.one_hot[GEN5_BIT] ? $bits(enc_128b130b.cmp_pat[0]  )'( eie_pat_128b130b ) : '0 ;
                          enc_128b130b.cmp_pat_k[ii]         = crnt_rate.one_hot[GEN5_BIT] ? osblock_syncheader                                    : datablock_syncheader ;
                          enc_128b130b.cmp_ossending[ii]     = crnt_rate.one_hot[GEN5_BIT] ? $bits(enc_128b130b.cmp_ossending[0])'( OSFLG_EIE )    : $bits(enc_128b130b.cmp_ossending[0])'( OSFLG_IDLE ) ;
                         end
               default : begin
                          enc_128b130b.cmp_pat[ii]           = '0 ;
                          enc_128b130b.cmp_pat_k[ii]         = datablock_syncheader ;
                          enc_128b130b.cmp_ossending[ii]     = $bits(enc_128b130b.cmp_ossending[0])'( OSFLG_IDLE ) ;
                         end
            endcase

            if( cmp_send_block_num[5:0] inside {6'd1 , 6'd2}) begin
                enc_128b130b.cmp_pat[ii][7*8 +: 8]           = { eqctl_pset_ltx[ii*TX_PSET_WD +: TX_PSET_WD] , ~eqctl_pset_ltx[ii*TX_PSET_WD +: TX_PSET_WD] } ;
            end

            if( jitter_ptn_en_128b130b[ii] ) begin
                enc_128b130b.cmp_pat[ii]                     = $bits(enc_128b130b.cmp_pat[0]  )'( jitter_msrmnt_128b130b ) ;
                enc_128b130b.cmp_pat_k[ii]                   = osblock_syncheader ;
                enc_128b130b.cmp_ossending[ii]               = $bits(enc_128b130b.cmp_ossending[0])'( OSFLG_IDLE ) ;
            end

                enc_128b130b.cmp_skpend_bm[ii]               =  '0 ;       // NO SKP in compliance pattern


        end
    end
    
    // -------------------------------
    // Modified Compliance pattern
    // -------------------------------

    // Load error counter of SKP OS(In order to avoid to send different count number in same block when 1s.)
    always_ff @(posedge core_clk or negedge core_rst_n) begin : skp_err_cnt_show_PROC
        if (!core_rst_n) begin
            for( int ii = 0 ; ii < NL ; ii++ ) begin
                skp_err_cnt_show[ii]             <= #TP '0 ;
            end
        end
        else begin
            if( ~crnt_grant[G_MCMP_BIT] && ~crnt_grant[G_SKP_BIT] ) begin
                for( int ii = 0 ; ii < NL ; ii++ ) begin
                    skp_err_cnt_show[ii]         <= #TP '0 ;
                end
            end
            else begin 
                for( int ii = 0 ; ii < NL ; ii++ ) begin
                    skp_err_cnt_show[ii]       <= #TP ( crnt_rate.enc_128b130b & (cmp_byte_count    < 6'd14) ) ? smlh_gen3_error_count_i[ii*8 +: 8]   // Error field is in Symbol14/15 if Gen3/4/5
                                                    : ( crnt_rate.enc_1b1b     & (mcmp_gen6_skp_cnt < 6'd32) ) ? smlh_gen3_error_count_i[ii*8 +: 8]   // Error field is in Symbol32-39 if Gen6
                                                                                                               : skp_err_cnt_show[ii] ;               // keep
                end
            end
        end
    end


    // Per-lane pattern 
    always_comb begin
        for( int ii = 0 ; ii < NL ; ii++ ) begin
            // SKP OS
            mcmp_skp_128b130b[ii]                = skp_pat_128b130b ;                   // Symbol 0-12
            mcmp_skp_128b130b[ii][13*8 +: 8]     = 8'hAA ;                              // Symbol 13
            mcmp_skp_128b130b[ii][14*8 +: 8]     =  skp_err_cnt_show[ii] ;              // Symbol 14
            mcmp_skp_128b130b[ii][15*8 +: 8]     = ~skp_err_cnt_show[ii] ;              // Symbol 15
            
            // Modified compliance pattern
            enc_128b130b.mcmp_pat[ii]           = '0 ;
            enc_128b130b.mcmp_pat_k[ii]         = datablock_syncheader ;
            enc_128b130b.mcmp_ossending[ii]     = $bits(enc_128b130b.mcmp_ossending[0])'( OSFLG_IDLE ) ;
            enc_128b130b.mcmp_skpend_bm[ii]     = $bits(enc_128b130b.mcmp_skpend_bm[0])'( '0 ) ;

            if( (cmp_send_phase_num == '0) && (cmp_send_block_num == '0) ) begin                                       // Phase0 / Block0 = EIE
                enc_128b130b.mcmp_pat[ii]                     = $bits(enc_128b130b.mcmp_pat[0])'( eie_pat_128b130b ) ;
                enc_128b130b.mcmp_pat_k[ii]                   = osblock_syncheader ;
                enc_128b130b.mcmp_ossending[ii]               = $bits(enc_128b130b.mcmp_ossending[0])'( OSFLG_EIE ) ;
            end
            if( (cmp_send_phase_num == '0) && (cmp_send_block_num == 18'd1) && crnt_rate.one_hot[GEN5_BIT] ) begin     // Phase0 / Block1 / Gen5 = EIE
                enc_128b130b.mcmp_pat[ii]                     = $bits(enc_128b130b.mcmp_pat[0])'( eie_pat_128b130b ) ;
                enc_128b130b.mcmp_pat_k[ii]                   = osblock_syncheader ;
                enc_128b130b.mcmp_ossending[ii]               = $bits(enc_128b130b.mcmp_ossending[0])'( OSFLG_EIE ) ;
            end
            if( (cmp_send_phase_num != '0) && (cmp_send_block_num == '0) ) begin                                       // Not Phase0 / Block0 = SKP
                enc_128b130b.mcmp_pat[ii]                     = $bits(enc_128b130b.mcmp_pat[0])'( mcmp_skp_128b130b[ii] ) ;
                enc_128b130b.mcmp_pat_k[ii]                   = osblock_syncheader ;
                enc_128b130b.mcmp_ossending[ii]               = $bits(enc_128b130b.mcmp_ossending[0])'( OSFLG_SKP ) ;
                enc_128b130b.mcmp_skpend_bm[ii]               = $bits(enc_128b130b.mcmp_skpend_bm[0])'( SKPEND_BM_128b130b ) ;
            end
        end
    end




        
// ----------------------
// ---- 1b/1b     -------
// ----------------------

    // -------------------------------
    // Normal Compliance pattern
    // -------------------------------

    // Common in all lanes pattern
    always_comb begin
        cmp_pat1_1b1b               = { 64{2'b11} } ;             // Pattern 1(1 is Spec number)
        cmp_pat2_1b1b               = { 64{2'b00} } ;             // Pattern 2(2 is Spec number)
        cmp_pat3_1b1b               = { 16{8'hCC} } ;             // Pattern 3(3 is Spec number)
        cmp_pat7_1b1b               = { 64{2'b10} } ;             // Pattern 7(7 is Spec number)
        cmp_pat8_1b1b               = { 64{2'b01} } ;             // Pattern 8(8 is Spec number)
        
        jitter_msrmnt_1b1b          = { {(concate_num_1b_jit){ 104'hB5_E6_31_2F_79_8C_42_DE_63_12_B7_98_C4 }} } ;   // Jitter Measurement pattern
        cmp_hswing_1b1b             = { 16{8'h33} } ;                                                               // High swing toggle pattern 
        cmp_lswing_1b1b             = { 16{8'h66} } ;                                                               // Low  swing toggle pattern 
    end

    // Per-lane(Lane number mod 8) pattern
    always_comb begin
                                           //     Sym15 --------------------------------------- Sym0
        cmp_pat4_mod8_1sthalf_1b1b[0]      = { 128'hFF_FF_FF_FF_FF_FF_FF_FF_FF_FF_FF_FF_FF_FF_FF_FF } ;       // Lane0,8
        cmp_pat4_mod8_2ndhalf_1b1b[0]      = { 128'h5F_26_CC_65_C2_3B_C5_3F_FF_FF_FF_FF_FF_FF_FF_FF } ;       // Lane0,8
        cmp_pat4_mod8_1sthalf_1b1b[1]      = { 128'h38_DA_CC_C4_E2_3F_1D_35_3B_25_63_CC_B2_CC_FF_FF } ;       // Lane1,9
        cmp_pat4_mod8_2ndhalf_1b1b[1]      = { 128'hB1_CB_0D_33_C5_D4_EC_32_A2_AC_CC_53_DC_C6_38_B4 } ;       // Lane1,9
        cmp_pat4_mod8_1sthalf_1b1b[2]      = { 128'h52_3D_D4_99_EC_0F_3C_4E_56_00_00_00_00_00_00_00 } ;       // Lane2,10
        cmp_pat4_mod8_2ndhalf_1b1b[2]      = { 128'hA5_2A_69_C3_C9_C3_93_2F_30_CF_1C_C3_37_C0_D8_ED } ;       // Lane2,10
        cmp_pat4_mod8_1sthalf_1b1b[3]      = { 128'hE8_00_00_00_00_00_00_00_00_00_00_00_00_00_00_00 } ;       // Lane3,11
        cmp_pat4_mod8_2ndhalf_1b1b[3]      = { 128'hAC_71_6C_3C_CC_93_73_52_8E_6C_DC_0C_E7_C4_E2_D0 } ;       // Lane3,11
        cmp_pat4_mod8_1sthalf_1b1b[4]      = { 128'h93_6C_C8_3A_63_93_70_F6_6F_FF_FF_FF_FF_FF_FF_FF } ;       // Lane4,12
        cmp_pat4_mod8_2ndhalf_1b1b[4]      = { 128'h6A_65_DC_1D_A4_DD_28_F1_C3_2E_4F_2C_5C_2D_D6_C2 } ;       // Lane4,12
        cmp_pat4_mod8_1sthalf_1b1b[5]      = { 128'h33_C3_9C_6D_60_CF_71_8D_C3_35_D2_8E_3C_6D_0D_DD } ;       // Lane5,13
        cmp_pat4_mod8_2ndhalf_1b1b[5]      = { 128'h5E_C4_8C_ED_6C_4E_53_33_6D_C2_D5_3C_33_28_FC_53 } ;       // Lane5,13
        cmp_pat4_mod8_1sthalf_1b1b[6]      = { 128'h00_00_00_00_00_00_00_00_00_00_00_00_00_00_00_00 } ;       // Lane6,14
        cmp_pat4_mod8_2ndhalf_1b1b[6]      = { 128'h63_6B_31_37_20_00_00_00_00_00_00_00_00_00_00_00 } ;       // Lane6,14
        cmp_pat4_mod8_1sthalf_1b1b[7]      = { 128'hD9_C3_33_CC_A0_D3_DC_FF_FF_FF_FF_FF_FF_FF_FF_FF } ;       // Lane7,15
        cmp_pat4_mod8_2ndhalf_1b1b[7]      = { 128'h5D_2D_CD_0E_C3_23_E1_F0_8F_1D_32_8E_B3_31_39_C2 } ;       // Lane7,15
    end

   // High swing toggle pattern sending enable (per-lane) / Low swing toggle pattern sending enable (Common in all lanes)
    always_ff @(posedge core_clk or negedge core_rst_n) begin : hswing_ptn_en_1b1b_PROC
        if (!core_rst_n) begin
            hswing_ptn_en_1b1b             <= #TP '0 ;
            lswing_ptn_en_1b1b             <= #TP '0 ;
        end
        else begin
            if( next_grant[G_CMP_BIT] ) begin
                for( int ii = 0 ; ii < NL ; ii++ ) begin
                                              if( ii%8 == 3'h0 ) hswing_ptn_en_1b1b[ii]      <= #TP (ltssm_gen6_compliance_tp inside { 4'b0001 , 4'b0010 }) ;          // For Lane0/8
   else if( ii%8 == 3'h1 ) hswing_ptn_en_1b1b[ii]      <= #TP (ltssm_gen6_compliance_tp inside { 4'b0001 , 4'b0011 }) ;  // For Lane1/9
   else if( ii%8 == 3'h2 ) hswing_ptn_en_1b1b[ii]      <= #TP (ltssm_gen6_compliance_tp inside { 4'b0001 , 4'b0100 }) ;  // For Lane2/10
   else if( ii%8 == 3'h3 ) hswing_ptn_en_1b1b[ii]      <= #TP (ltssm_gen6_compliance_tp inside { 4'b0001 , 4'b0101 }) ;  // For Lane3/11
   else if( ii%8 == 3'h4 ) hswing_ptn_en_1b1b[ii]      <= #TP (ltssm_gen6_compliance_tp inside { 4'b0001 , 4'b0110 }) ;  // For Lane4/12
   else if( ii%8 == 3'h5 ) hswing_ptn_en_1b1b[ii]      <= #TP (ltssm_gen6_compliance_tp inside { 4'b0001 , 4'b0111 }) ;  // For Lane5/13
   else if( ii%8 == 3'h6 ) hswing_ptn_en_1b1b[ii]      <= #TP (ltssm_gen6_compliance_tp inside { 4'b0001 , 4'b1000 }) ;  // For Lane6/14
   else if( ii%8 == 3'h7 ) hswing_ptn_en_1b1b[ii]      <= #TP (ltssm_gen6_compliance_tp inside { 4'b0001 , 4'b1001 }) ;  // For Lane7/15
                end
                                               lswing_ptn_en_1b1b          <= #TP (ltssm_gen6_compliance_tp == 4'b1010 ) ;                   // For all lanes
            end
        end
    end

    // Per-lane pattern (Normal Compliance pattern)
    always_comb begin
        for( int ii = 0 ; ii < NL ; ii++ ) begin
            for( int jj = 0 ; jj < NBLOCK ; jj++ ) begin
                for_loop_cmp_send_block_num = (jj == 0 ) ? cmp_send_block_num : cmp_send_block_num_plus1 ;

                case( for_loop_cmp_send_block_num[7:0] )
                    8'd0   : begin
                              enc_1b1b.cmp_pat[ii][jj*128 +: 128]           = cmp_pat1_1b1b ;
                              enc_1b1b.cmp_pat_k[ii][jj*16 +: 16]           = osblock_syncheader[jj*16 +: 16] ;
                              enc_1b1b.cmp_ossending[ii][jj*16 +: 16]       = (16)'( OSFLG_IDLE ) ;
                             end
                    8'd1   : begin
                              enc_1b1b.cmp_pat[ii][jj*128 +: 128]           = cmp_pat2_1b1b ;
                              enc_1b1b.cmp_pat_k[ii][jj*16 +: 16]           = osblock_syncheader[jj*16 +: 16] ;
                              enc_1b1b.cmp_ossending[ii][jj*16 +: 16]       = (16)'( OSFLG_IDLE ) ;
                             end
                    8'd2   : begin
                              enc_1b1b.cmp_pat[ii][jj*128 +: 128]           = cmp_pat3_1b1b ;
                              enc_1b1b.cmp_pat_k[ii][jj*16 +: 16]           = osblock_syncheader[jj*16 +: 16] ;
                              enc_1b1b.cmp_ossending[ii][jj*16 +: 16]       = (16)'( OSFLG_IDLE ) ;
                             end
                    8'd3   : begin
                              enc_1b1b.cmp_pat[ii][jj*128 +: 128]           = cmp_pat3_1b1b ;
                              enc_1b1b.cmp_pat_k[ii][jj*16 +: 16]           = osblock_syncheader[jj*16 +: 16] ;
                              enc_1b1b.cmp_ossending[ii][jj*16 +: 16]       = (16)'( OSFLG_IDLE ) ;
                             end
                    8'd4   : begin
                              enc_1b1b.cmp_pat[ii][jj*128 +: 128]           = cmp_pat4_mod8_1sthalf_1b1b[ii%8] ;
                              enc_1b1b.cmp_pat_k[ii][jj*16 +: 16]           = osblock_syncheader[jj*16 +: 16] ;
                              enc_1b1b.cmp_ossending[ii][jj*16 +: 16]       = (16)'( OSFLG_IDLE ) ;
                             end
                    8'd5   : begin
                              enc_1b1b.cmp_pat[ii][jj*128 +: 128]           = cmp_pat4_mod8_2ndhalf_1b1b[ii%8] ;
                              enc_1b1b.cmp_pat_k[ii][jj*16 +: 16]           = osblock_syncheader[jj*16 +: 16] ;
                              enc_1b1b.cmp_ossending[ii][jj*16 +: 16]       = (16)'( OSFLG_IDLE ) ;
                             end
                    8'd6   : begin
                              enc_1b1b.cmp_pat[ii][jj*128 +: 128]           = eie_pat_1b1b ;
                              enc_1b1b.cmp_pat_k[ii][jj*16 +: 16]           = osblock_syncheader[jj*16 +: 16] ;
                              enc_1b1b.cmp_ossending[ii][jj*16 +: 16]       = (16)'( OSFLG_EIE ) ;
                             end
                    8'd71  : begin
                              enc_1b1b.cmp_pat[ii][jj*128 +: 128]           = cmp_pat7_1b1b ;
                              enc_1b1b.cmp_pat_k[ii][jj*16 +: 16]           = osblock_syncheader[jj*16 +: 16] ;
                              enc_1b1b.cmp_ossending[ii][jj*16 +: 16]       = (16)'( OSFLG_IDLE ) ;
                             end
                    8'd72  : begin
                              enc_1b1b.cmp_pat[ii][jj*128 +: 128]           = cmp_pat8_1b1b ;
                              enc_1b1b.cmp_pat_k[ii][jj*16 +: 16]           = osblock_syncheader[jj*16 +: 16] ;
                              enc_1b1b.cmp_ossending[ii][jj*16 +: 16]       = (16)'( OSFLG_IDLE ) ;
                             end
                   default : begin
                              enc_1b1b.cmp_pat[ii][jj*128 +: 128]           = '0 ;
                              enc_1b1b.cmp_pat_k[ii][jj*16 +: 16]           = datablock_syncheader[jj*16 +: 16] ;
                              enc_1b1b.cmp_ossending[ii][jj*16 +: 16]       = (16)'( OSFLG_IDLE ) ;
                             end
                endcase
            end
            
            if( hswing_ptn_en_1b1b[ii] ) begin
                enc_1b1b.cmp_pat[ii]                     = {NBLOCK{cmp_hswing_1b1b}} ;
                enc_1b1b.cmp_pat_k[ii]                   = osblock_syncheader ;
                enc_1b1b.cmp_ossending[ii]               = $bits(enc_1b1b.cmp_ossending[0])'( OSFLG_IDLE ) ;
            end
            if( lswing_ptn_en_1b1b ) begin
                enc_1b1b.cmp_pat[ii]                     = {NBLOCK{cmp_lswing_1b1b}} ;
                enc_1b1b.cmp_pat_k[ii]                   = osblock_syncheader ;
                enc_1b1b.cmp_ossending[ii]               = $bits(enc_1b1b.cmp_ossending[0])'( OSFLG_IDLE ) ;
            end
            if( jitter_ptn_en_128b130b[ii] ) begin
                enc_1b1b.cmp_pat[ii]                     = (128*NBLOCK)'( jitter_msrmnt_1b1b >> ( {shift_jitter_msrmnt_1b1b , 3'd0}) );
                enc_1b1b.cmp_pat_k[ii]                   = osblock_syncheader ;
                enc_1b1b.cmp_ossending[ii]               = $bits(enc_1b1b.cmp_ossending[0])'( OSFLG_IDLE ) ;
            end

                enc_1b1b.cmp_skpend_bm[ii]               = '0 ;       // NO SKP in compliance pattern
        end
    end


   // Shift Jitter Measuremnt pattern. Because the pattern length is 104bit(13Byte) not divied to bus width.
    always_ff @(posedge core_clk or negedge core_rst_n) begin : shift_jitter_msrmnt_1b1b_PROC
        if (!core_rst_n) begin
            shift_jitter_msrmnt_1b1b             <= #TP '0 ;
        end
        else begin
            if( ~crnt_grant[G_CMP_BIT] || ~crnt_rate.one_hot[GEN6_BIT] ) begin
                shift_jitter_msrmnt_1b1b             <= #TP '0 ;
            end
            else if( cmp_block_done_int ) begin
                if( shift_jitter_msrmnt_1b1b + 3*NBLOCK < 4'd13 ) shift_jitter_msrmnt_1b1b   <= #TP $bits(shift_jitter_msrmnt_1b1b)'( shift_jitter_msrmnt_1b1b + 3*NBLOCK        ) ;
                else                                              shift_jitter_msrmnt_1b1b   <= #TP $bits(shift_jitter_msrmnt_1b1b)'( shift_jitter_msrmnt_1b1b + 3*NBLOCK - 4'd13) ;
            end
        end
    end


    // -------------------------------
    // Modified Compliance pattern
    // -------------------------------
    // Syncheader pattern
    always_comb begin
        if( NBK == 2 ) begin
            osblock_syncheader_8sunit     = {4{ `SYNC_OS_BLOCK   }} ;
            datablock_syncheader_8sunit   = {4{ `SYNC_DATA_BLOCK }} ;
        end
        else if( NBK == 4 ) begin
            osblock_syncheader_8sunit     = {2{ (4)'(`SYNC_OS_BLOCK  ) }} ;
            datablock_syncheader_8sunit   = {2{ (4)'(`SYNC_DATA_BLOCK) }} ;
        end
        else begin
            osblock_syncheader_8sunit     = (8)'( `SYNC_OS_BLOCK   ) ;
            datablock_syncheader_8sunit   = (8)'( `SYNC_DATA_BLOCK ) ;
        end
    end

    // Common in all lanes pattern
    always_comb begin
        skp_parity_type_1b1b        = 4'hF ;
    end
    
    // Per-lane pattern 
    always_comb begin
        for( int ii = 0 ; ii < NL ; ii++ ) begin
            skp_payload_1b1b[ii]              = {skp_err_cnt_show[ii], ~skp_err_cnt_show[ii][7], skp_err_cnt_show[ii][6]
                                                                     , ~skp_err_cnt_show[ii][5], skp_err_cnt_show[ii][4]
                                                                     , ~skp_err_cnt_show[ii][3], skp_err_cnt_show[ii][2]
                                                                     , ~skp_err_cnt_show[ii][1], skp_err_cnt_show[ii][0] , 8'h22 } ;  // SKP Payload


            mcmp_skp_1b1b[ii][255:0]          = skp_pat_1b1b[255:0] ;                                                                                                      // Byte0 - 31
            mcmp_skp_1b1b[ii][32*8 +: 32]     = {skp_payload_1b1b[ii][23:16], skp_parity_type_1b1b       , skp_payload_1b1b[ii][15:0], skp_parity_type_1b1b     } ;        // Byte32 - 35
            mcmp_skp_1b1b[ii][36*8 +: 32]     = {skp_parity_type_1b1b        , skp_payload_1b1b[ii][23:8], skp_parity_type_1b1b      , skp_payload_1b1b[ii][7:0]} ;        // Byte36 - 39
        end
    end

    // Per-lane pattern  (Modified Compliance Pattern)
    always_comb begin
        for( int ii = 0 ; ii < NL ; ii++ ) begin
                enc_1b1b.mcmp_pat[ii]        = '0 ;
                enc_1b1b.mcmp_pat_k[ii]      = datablock_syncheader ;
                enc_1b1b.mcmp_ossending[ii]  = $bits(enc_1b1b.mcmp_ossending[0])'( OSFLG_IDLE ) ;
                enc_1b1b.mcmp_skpend_bm[ii]  =  '0 ;
                
               if( mcmp_1b1b_eie_hit == SHIFT_RIGHT ) begin
                   enc_1b1b.mcmp_pat[ii]                                       = sris_mode_on ? $bits(enc_1b1b.mcmp_pat[0]     )'( {mcmp_skp_1b1b[ii], eie_pat_1b1b} >> ({mcmp_1b1b_eie_shift_qw , 6'd0}) ) 
                                                                                              : $bits(enc_1b1b.mcmp_pat[0]     )'(                     eie_pat_1b1b  >> ({mcmp_1b1b_eie_shift_qw , 6'd0}) ) ;
                   enc_1b1b.mcmp_pat_k[ii]                                     = sris_mode_on ? $bits(enc_1b1b.mcmp_pat_k[0]   )'( { {NQW{datablock_syncheader_8sunit}}, {7{osblock_syncheader_8sunit}} } >> ({mcmp_1b1b_eie_shift_qw , 3'd0}) ) 
                                                                                              : $bits(enc_1b1b.mcmp_pat_k[0]   )'( { {NQW{datablock_syncheader_8sunit}}, {2{osblock_syncheader_8sunit}} } >> ({mcmp_1b1b_eie_shift_qw , 3'd0}) ) ;
                   enc_1b1b.mcmp_ossending[ii]                                 = sris_mode_on ? $bits(enc_1b1b.mcmp_ossending[0])'( { {5{OSFLG_SKP}}, {2{OSFLG_EIE}} } >> ({mcmp_1b1b_eie_shift_qw , 3'd0}) ) 
                                                                                              : $bits(enc_1b1b.mcmp_ossending[0])'( {                 {2{OSFLG_EIE}} } >> ({mcmp_1b1b_eie_shift_qw , 3'd0}) ) ;
                   enc_1b1b.mcmp_skpend_bm[ii]                                 = sris_mode_on ? $bits(enc_1b1b.mcmp_skpend_bm[0])'( { SKPEND_BM_1b1b, 16'h0000       } >> ({mcmp_1b1b_eie_shift_qw , 3'd0}) ) 
                                                                                              : $bits(enc_1b1b.mcmp_skpend_bm[0])'( '0 ) ;
               end
               else if( mcmp_1b1b_eie_hit == SHIFT_LEFT ) begin
                   enc_1b1b.mcmp_pat[ii]                                       = sris_mode_on ? $bits(enc_1b1b.mcmp_pat[0]     )'( {mcmp_skp_1b1b[ii], eie_pat_1b1b} << ({mcmp_1b1b_eie_shift_qw , 6'd0}) ) 
                                                                                              : $bits(enc_1b1b.mcmp_pat[0]     )'(                     eie_pat_1b1b  << ({mcmp_1b1b_eie_shift_qw , 6'd0}) ) ;
                   enc_1b1b.mcmp_pat_k[ii]                                     = sris_mode_on ? $bits(enc_1b1b.mcmp_pat_k[0]   )'( { {NQW{datablock_syncheader_8sunit}}, {7{osblock_syncheader_8sunit}} } << ({mcmp_1b1b_eie_shift_qw , 3'd0}) ) 
                                                                                              : $bits(enc_1b1b.mcmp_pat_k[0]   )'( { {NQW{datablock_syncheader_8sunit}}, {2{osblock_syncheader_8sunit}} } << ({mcmp_1b1b_eie_shift_qw , 3'd0}) ) ;
                   enc_1b1b.mcmp_ossending[ii]                                 = sris_mode_on ? $bits(enc_1b1b.mcmp_ossending[0])'( { {5{OSFLG_SKP}}, {2{OSFLG_EIE}} } << ({mcmp_1b1b_eie_shift_qw , 3'd0}) ) 
                                                                                              : $bits(enc_1b1b.mcmp_ossending[0])'( {                 {2{OSFLG_EIE}} } << ({mcmp_1b1b_eie_shift_qw , 3'd0}) ) ;
                   enc_1b1b.mcmp_skpend_bm[ii]                                 = sris_mode_on ? $bits(enc_1b1b.mcmp_skpend_bm[0])'( { SKPEND_BM_1b1b, 16'h0000       } << ({mcmp_1b1b_eie_shift_qw , 3'd0}) ) 
                                                                                              : $bits(enc_1b1b.mcmp_skpend_bm[0])'( '0 ) ;
                   for( int jj = 0 ; jj < 2*NBLOCK ; jj ++ ) begin
                       if( mcmp_1b1b_eie_shift_qw > jj ) enc_1b1b.mcmp_pat_k[ii][jj*8 +: 8]  = datablock_syncheader_8sunit ; 
                   end
               end
               else if( mcmp_1b1b_skp_hit == SHIFT_RIGHT ) begin
                   enc_1b1b.mcmp_pat[ii]                                       = $bits(enc_1b1b.mcmp_pat[0]     )'( mcmp_skp_1b1b[ii]  >> ({mcmp_1b1b_skp_shift_qw , 6'd0}) ) ;
                   enc_1b1b.mcmp_pat_k[ii]                                     = $bits(enc_1b1b.mcmp_pat_k[0]   )'( { {NQW{datablock_syncheader_8sunit}}, {5{osblock_syncheader_8sunit}} } >> ({mcmp_1b1b_skp_shift_qw , 3'd0}) ) ;
                   enc_1b1b.mcmp_ossending[ii]                                  = $bits(enc_1b1b.mcmp_ossending[0])'( {5{OSFLG_SKP}} >> ({mcmp_1b1b_skp_shift_qw , 3'd0}) ) ;
                   enc_1b1b.mcmp_skpend_bm[ii]                                  = $bits(enc_1b1b.mcmp_skpend_bm[0])'( SKPEND_BM_1b1b >> ({mcmp_1b1b_skp_shift_qw , 3'd0}) ) ;
               end
               else if( mcmp_1b1b_skp_hit == SHIFT_LEFT ) begin
                   enc_1b1b.mcmp_pat[ii]                                       = $bits(enc_1b1b.mcmp_pat[0]     )'( mcmp_skp_1b1b[ii]  << ({mcmp_1b1b_skp_shift_qw , 6'd0}) ) ;
                   enc_1b1b.mcmp_pat_k[ii]                                     = $bits(enc_1b1b.mcmp_pat_k[0]   )'( { {NQW{datablock_syncheader_8sunit}}, {5{osblock_syncheader_8sunit}} } << ({mcmp_1b1b_skp_shift_qw , 3'd0}) ) ;
                   enc_1b1b.mcmp_ossending[ii]                                 = $bits(enc_1b1b.mcmp_ossending[0])'( {5{OSFLG_SKP}} << ({mcmp_1b1b_skp_shift_qw , 3'd0}) ) ;
                   enc_1b1b.mcmp_skpend_bm[ii]                                 = $bits(enc_1b1b.mcmp_skpend_bm[0])'( SKPEND_BM_1b1b << ({mcmp_1b1b_skp_shift_qw , 3'd0}) ) ;

                   for( int jj = 0 ; jj < 2*NBLOCK ; jj ++ ) begin
                       if( mcmp_1b1b_skp_shift_qw > jj ) enc_1b1b.mcmp_pat_k[ii][jj*8 +: 8]  = datablock_syncheader_8sunit ;
                   end
               end
               
        end
    end

    // common in all lane (Start Block)
    always_comb begin
        mcmp_1b1b_startblock_qw       = mcmp_1b1b_startblock_qw_lat ;
         
        if( mcmp_1b1b_eie_hit == SHIFT_RIGHT ) begin
                                                                                                                        //   Padding      , SKP(40B) , EIE(16B)
            mcmp_1b1b_startblock_qw                                     = sris_mode_on ? $bits(mcmp_1b1b_startblock_qw )'( { {NQW{2'b01}} ,  5'h01  ,  2'b01  }   >> mcmp_1b1b_eie_shift_qw )  
                                                                                       : $bits(mcmp_1b1b_startblock_qw )'( { {NQW{2'b01}} ,            2'b01  }   >> mcmp_1b1b_eie_shift_qw ) ;
        end
        else if( mcmp_1b1b_eie_hit == SHIFT_LEFT ) begin
                                                                                                                        //   Padding      , SKP(40B) , EIE(16B)
            mcmp_1b1b_startblock_qw                                     = sris_mode_on ? $bits(mcmp_1b1b_startblock_qw )'( { {NQW{2'b01}} ,   5'h01  ,  2'b01  }   << mcmp_1b1b_eie_shift_qw )  
                                                                                       : $bits(mcmp_1b1b_startblock_qw )'( { {NQW{2'b01}} ,             2'b01  }   << mcmp_1b1b_eie_shift_qw ) ;
            for( int ii = 0 ; ii < 2*NBLOCK ; ii ++ ) begin
                if( mcmp_1b1b_eie_shift_qw > ii ) begin
                    if(  ( (mcmp_1b1b_eie_shift_qw[0] == '0) & (ii%2 == 0) )
                       ||( (mcmp_1b1b_eie_shift_qw[0] == '1) & (ii%2 == 1) ) ) begin
                         mcmp_1b1b_startblock_qw[ii] = 1'b1 ; 
                    end
                    else begin
                         mcmp_1b1b_startblock_qw[ii] = 1'b0 ; 
                    end
                end
            end
        end
        else if( mcmp_1b1b_skp_hit == SHIFT_RIGHT ) begin
                                                                                                         //     Padding    , SKP(40B) 
            mcmp_1b1b_startblock_qw                                     = $bits(mcmp_1b1b_startblock_qw )'( { {NQW{2'b01}} ,  5'h01  } >> mcmp_1b1b_skp_shift_qw ) ;
        end
        else if( mcmp_1b1b_skp_hit == SHIFT_LEFT ) begin
                                                                                                         //     Padding    , SKP(40B) 
            mcmp_1b1b_startblock_qw                                     = $bits(mcmp_1b1b_startblock_qw )'( { {NQW{2'b01}} ,  5'h01  } << mcmp_1b1b_skp_shift_qw ) ;

            for( int ii = 0 ; ii < 2*NBLOCK ; ii ++ ) begin
                if( mcmp_1b1b_skp_shift_qw > ii ) begin
                    if(  ( (mcmp_1b1b_skp_shift_qw[0] == '0) & (ii%2 == 0) )
                       ||( (mcmp_1b1b_skp_shift_qw[0] == '1) & (ii%2 == 1) ) ) begin
                         mcmp_1b1b_startblock_qw[ii] = 1'b1 ; 
                    end
                    else begin
                         mcmp_1b1b_startblock_qw[ii] = 1'b0 ; 
                    end
                end
            end
        end
    end
    
    // Latched mcmp_1b1b_startblock_qw
    always_ff @(posedge core_clk or negedge core_rst_n) begin : mcmp_1b1b_startblock_qw_lat_PROC
        if (!core_rst_n) begin
            mcmp_1b1b_startblock_qw_lat            <= #TP '0 ;
        end
        else begin
                mcmp_1b1b_startblock_qw_lat       <= #TP mcmp_1b1b_startblock_qw[(NBLOCK*2)-1] ? {NBLOCK{2'b10}}     // previous MSB is 1, next QW is 0
                                                                                               : {NBLOCK{2'b01}} ;   // previous MSB is 0, next QW is 1
        end
    end

    // SKP sending frag for making TxStartBlock
    always_comb begin
        mcmp_gen6_skp_det                 = (cmp_gen_data[0][15:0] == {`SKP_G6_S1, `SKP_G6_S0}) & crnt_grant[G_MCMP_BIT] & crnt_rate.enc_1b1b ;
        mcmp_gen6_skp_in_progress         = mcmp_gen6_skp_det | mcmp_gen6_skp_det_lat ;
    end

    always_ff @(posedge core_clk or negedge core_rst_n) begin : skp_sending_flag_PROC
        if (!core_rst_n) begin
                mcmp_gen6_skp_det_lat             <= #TP '0 ;
                mcmp_gen6_skp_cnt                 <= #TP '0 ;
                mcmp_gen6_skp_done                <= #TP '0 ;
        end
        else begin
            if( mcmp_gen6_skp_done ) begin
                mcmp_gen6_skp_det_lat             <= #TP '0 ;
                mcmp_gen6_skp_cnt                 <= #TP '0 ;
                mcmp_gen6_skp_done                <= #TP '0 ;
            end
            else if( mcmp_gen6_skp_in_progress ) begin
                mcmp_gen6_skp_det_lat             <= #TP 1'b1 ;
                mcmp_gen6_skp_cnt                 <= #TP $bits(mcmp_gen6_skp_cnt)'( mcmp_gen6_skp_cnt + active_nb ) ;
                mcmp_gen6_skp_done                <= #TP ((mcmp_gen6_skp_cnt + active_nb) == (6'd40 - active_nb) ) ;
            end
        end
    end






// ---------------------------------------------------
// ---- PIPE control signal : TxCompliance     -------
// ---------------------------------------------------


    // Assert when 1st cycle of Gen1/2 Compliance pattern
    always_ff @(posedge core_clk or negedge core_rst_n) begin : cmp_txcompliance_PROC
        if (!core_rst_n) begin
            cmp_txcompliance             <= #TP '0 ;
        end
        else begin
            if(  crnt_rate.enc_8b10b &&
               (    ( next_grant[G_CMP_BIT]  && ~crnt_grant[G_CMP_BIT]  && ~crnt_grant[G_SKP_BIT] )
                 || ( next_grant[G_MCMP_BIT] && ~crnt_grant[G_MCMP_BIT] && ~crnt_grant[G_SKP_BIT] ) )
             ) begin
                cmp_txcompliance             <= #TP 1'b1 ;
            end
            else begin
                cmp_txcompliance             <= #TP '0 ;
            end
        end
    end

    // Turn Off and ouput Tx Co,pliance
    always_comb begin
        for( int ii = 0 ; ii < NL ; ii++ ) begin
                turnoff_txcompliace[ii]          = (~int_data_ltssm_lanes_active[ii] & ~int_l0p_ltssm_lanes_active[ii] & ~smlh_no_turnoff_lanes[ii]) ? 1'b1 : 1'b0 ;


                int_txcompliance[ii]             = turnoff_txcompliace[ii] | (cmp_txcompliance ) ;
        end
    end



// ---------------------------------------------------
// ---- Mode/State                             -------
// ---------------------------------------------------
    always_ff @(posedge core_clk or negedge core_rst_n) begin : latched_xmtbyte_gen6_compliance_sending_PROC
        if (!core_rst_n) begin
            latched_xmtbyte_gen6_compliance_sending <= #TP '0;
        end 
        else if( ~crnt_rate.one_hot[GEN6_BIT] ) begin
            latched_xmtbyte_gen6_compliance_sending <= #TP '0;
        end 
        else begin
            if( crnt_grant[G_CMP_BIT] || crnt_grant[G_EI_BIT] ) begin 
                latched_xmtbyte_gen6_compliance_sending <= #TP xmtbyte_gen6_compliance_sending || latched_xmtbyte_gen6_compliance_sending;
            end else begin
                latched_xmtbyte_gen6_compliance_sending <= #TP '0;
            end
        end
    end
    assign xmtbyte_gen6_compliance_sending = (crnt_rate.one_hot[GEN6_BIT] & crnt_grant[G_CMP_BIT] ) 
                                           | latched_xmtbyte_gen6_compliance_sending;







endmodule
