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
// ---    $Id: //dwh/pcie_iip/main/fairbanks/design/Layer1/xmlh_data_gen.sv#4 $
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

 
 module xmlh_data_gen
    import xmlh_pkg::*;
    import DWC_pcie_core_pkg::ltssm_state_e;
    import DWC_pcie_core_pkg::S_LPBK_ACTIVE;
    import DWC_pcie_core_pkg::S_LPBK_EXIT;
    import DWC_pcie_core_pkg::S_LPBK_EXIT_TIMEOUT;
  
                         (
      input  logic                            core_clk 
    , input  logic                            core_rst_n 

// =============================================================================
//  , input  logicIO Declarations
// =============================================================================

// Received TLP/DLLP Data Path from Layer2 
    , input  logic  [NW-1 :0]                 xdlh_xmlh_stp_i                        // Indicates Start of TLP (1 bit per dword)
    , input  logic  [NW-1 :0]                 xdlh_xmlh_sdp_i                        // Indicates Start of DLLP (1 bit per dword)
    , input  logic  [NW-1 :0]                 xdlh_xmlh_eot_i                        // Indicates End of TLP or DLLP (1 bit per dword)
    , input  logic  [NW-1 :0]                 next_xdlh_xmlh_eot_i                   // 1cycle before of xdlh_xmlh_eot_i
    , input  logic  [NW-1 :0]                 xdlh_xmlh_pad_i                        // Indicates Pad (1 bit per dword)
    , input  logic  [NW-1 :0]                 next_xdlh_xmlh_stp_i                   // 1cycle before of xdlh_xmlh_stp_i
    , input  logic  [NW-1 :0]                 next_xdlh_xmlh_sdp_i                   // 1cycle before of xdlh_xmlh_sdp_i
    , input  logic  [DW-1:0]                  xdlh_xmlh_data_i                       // TLP/DLLP Data
    , input  logic  [NW-1:0]                  xdlh_xmlh_pid                          // PID location per DW on xdlh_xmlh_data[511:0]. Valid only when CXL,

// Received sending OS/Compliance pattern request from LTSSM
    , input  logic  [3:0]                     ltssm_cmd_i                            // encoded command to notify transmitter of the proper action based on LTSSM states
    
// Mode/State signals
    , input  logic                            ltssm_cxl_sh_bypass                    // SyncHeader_Bypass
    , input  logic                            cxl_mode_enable                        // Indicates whether the link should operate in CXL or PCIe mode
    , input  ltssm_state_e                    smlh_ltssm_state                       // LTSSM State
    , input  logic                            lpbk_master                            // indicates that the ltssm is the loopback master
    , input  logic                            ltssm_in_lpbk_active                   // LTSSM is loopback.active
    , input  logic                            cfg_prbs_en                            // PRBS Loopback enable
    , input  logic  [AW-1:0]                  active_nb                              // active number of symbols per lane per clock. bit0=1s, bit1=2s, bit2=4s, bit3=8s , bit4=16s
    , input  logic                            ltssm_flit_mode_enable                 // Indicates Flit Mode is enabled.

// Internal xmlh_byte_xmt signals (common)
    , input  data_rate_enc_t                  crnt_rate                               // current data rate shortcut.
    
// Internal xmlh_byte_xmt signals (xmlh_arb_ctl)
    , input  grant_t                          next_grant                              // Arbitration grant (next)
    , input  grant_t                          crnt_grant                              // Arbitration grant (Current)
    , input  stream_t                         next_stream                             // Indicates Current Stream(Data/OS/CMP or EIDLE) (Next)
    , input  stream_t                         crnt_stream                             // Indicates Current Stream(Data/OS/CMP or EIDLE) (Current)
    , input  logic                            internal_txdata_dv                      // Data Valid, gen1/gen2: always 1, gen3: 0 for one cycle every 4*active_nb blocks
    , input  logic                            internal_txdata_dv_pre                  // 1 cycle before of internal_txdata_dv
    , input  logic                            internal_txstartblock                   // Indicates the starting symbol for a 130b block
    , input  logic                            internal_txendblock                     // Indicates the ending symbol for a 130b block
    , input  logic [4:0]                      internal_txtblock_symbol_cnt            // Indicates the current symbol count for a 130b block
    , input  logic  [NL-1 :0]                 int_data_ltssm_lanes_active             // Data Link width (Not L0p Up/Downsize OS lane width) : LTSSM latched lanes that are active based on the link negotiation
    , input  logic  [5:0]                     int_data_smlh_link_mode                 // Data Link width (Not L0p Up/Downsize OS lane width) : 10000 -- x16, 01000 -- x8, 00100 -- x4, 00010 -- x2, 00001 -- x1
    , input  logic  [NL-1 :0]                 int_data_ltssm_lanes_active_pre         // Data Link width (Not L0p Up/Downsize OS lane width) : LTSSM latched lanes that are active based on the link negotiation
    , input  logic  [5:0]                     int_data_smlh_link_mode_pre             // Data Link width (Not L0p Up/Downsize OS lane width) : 10000 -- x16, 01000 -- x8, 00100 -- x4, 00010 -- x2, 00001 -- x1
    , input  logic                            mask_tlp_dllp_timing                    // FREQ_STEP Algin timing for TLP/DLLP
    , input  logic                            in_data_progress                        // Indicates Reveing TLP/DLLP from Layer2 progress
    , input  logic                            in_idle_data_progress                   // Indicates IDLE Data is transmitting
    
    
// =============================================================================
// output IO Declarations
// =============================================================================

// Received TLP/DLLP Data Path from Layer2 
    , output logic                            xmtbyte_xdlh_halt_o                     // Halt the flow of data from the xdlh

// Return sedning OS response to LTSSM
    , output logic                            xmtbyte_idle_sent                       // Indicates 1 IDLE is sent 

// Internal xmlh_byte_xmt signals (xmlh_arb_ctl)
    , output logic  [NL-1:0][NBIT-1:0]        data_gen_data                           // TLP/DLLP Data
    , output logic  [NL-1:0][NBK-1:0]         data_gen_datak                          // TLP/DLLP Data Kcode
    , output logic                            last_chunk                              // Indicates the last cycle of Data Bus alignment
    , output logic                            eds_ack                                 // Indicates EDS insertion is completed

    );





// -----------------------------------
//  Declaration
// -----------------------------------

    logic [LOG2NBYTE:0]                      crnt_xdlh_data_width_byte ;                 // Data widht(Byte) of XDLH
    logic [LOG2NW-1:0]                       crnt_msb_nw ;                               // Current MSB of NW width signals
    logic [LOG2NBYTE:0]                      next_pipe_width_byte ;                      // Current PIPE Bus width( Lane * Active NB ) (Byte unit)
    logic [LOG2NBYTE:0]                      crnt_pipe_width_byte ;                      // Current PIPE Bus width( Lane * Active NB ) (Byte unit)
    logic [LOG2NBYTE-1:0]                    next_data_byte_count ;                      // Sending to PIPE Data count against Layer2 Data 1cycle before.
    logic [LOG2NBYTE-1:0]                    data_byte_count ;                           // Sending to PIPE Data count against Layer2 Data
    logic [LOG2NBYTE-1:0]                    data_byte_count_msk_lowb ;                  // Sending to PIPE Data count against Layer2 Data (Masked not used low bit to 0)
    logic [LOG2NBYTE-1:0]                    data_width_minus_pipe_width ;               // Inidcates Data width(from XPLH) - PIP Ewidth.
    logic                                    next_grnt_is_data ;                         // Indicates next grant is any Data
    logic                                    crnt_grnt_is_data ;                         // Indicates current grant is any Data
    logic                                    next_pkt_is_early_end ;                     // Next TLP/DLLP end before all xdlh_xmlh_data_i dat is sent. 
    logic                                    early_pkt_end ;                             // TLP/DLLP end before all xdlh_xmlh_data_i dat is sent. 
    logic                                    early_pkt_done ;                            // TLP/DLLP end before all xdlh_xmlh_data_i dat is done. 
    logic [LOG2NBYTE:0]                      next_data_byte_count_plus_pipe_width ;      // Sending to PIPE Data count against Layer2 Data (Plus 1cycle)
    logic [LOG2NBYTE:0]                      data_byte_count_plus_pipe_width ;           // Sending to PIPE Data count against Layer2 Data (Plus 1cycle)
    logic  [NW-1 :0]                         int_xdlh_xmlh_pad ;                         // Indicates Pad (1 bit per dword)
    logic  [DW-1:0]                          pad_data ;                                  // TLP/DLLP Data include PAD symbols
    logic  [NBYTE-1:0]                       xdlh_xmlh_datak ;                           // kchar indicator from xdlh.  Combination of xdlh_xmlh_stp, sdp, eot, pad
    logic                                    eds_start ;                                 // Indicates 1st cycle of EDS replacement
    logic                                    eds_start_latch ;                           // Indicates 2nd or later cycle EDS replacement assert when internal bus width is 8B or 16B.
    logic                                    eds_in_progress ;                           // Indicates EDS replacement is in progress.
    logic  [DW-1:0]                          eds_symbol ;                                // EDS Token symbol
    logic  [DW-1:0]                          eds_data ;                                  // EDS Token Data
    logic  [DW-1:0]                          ieds_data ;                                 // iEDS Token Data
    logic [LOG2NBYTE-1:0]                    stored_byte_count ;                         // Stored Byte Count when EDS token.
    logic                                    null_ieds_insertion_condition ;             // Indicates syncheader bypass is disabled and x4/x2/x1.
    logic  [NW-1 :0]                         null_ieds_insertion_det ;                   // Null iEDS Token insertion is detected when syncheader bypass is disabled and x4/x2/x1.
    logic                                    null_ieds_insertion_en ;                    // Null iEDS Token insertion enable when syncheader bypass is disabled and x4/x2/x1.
    logic                                    next_block_is_null_ieds ;                   // Indicates Null Data Block is Null iEDS.
    logic                                    null_ieds_insertion_in_progress ;           // Null iEDS Token insertion is in progress when syncheader bypass is disabled.
    logic                                    last_flit_start ;                           // 1st cycle of the last flit before OS
    logic                                    last_flit_start_latched ;                   // latched last_flit_start.
    logic                                    last_flit_in_progres ;                      // flag of the last flit before OS
    logic  [2:0]                             last_flit_block_num ;                       // The number of block the last flit(depends on the number of lane)(0's base)
    logic  [2:0]                             last_flit_block_cnt ;                       // Count the number of block the last flit(depends on the number of lane)(0's base)
    logic                                    last_data_block_cycle_for_os ;              // Indicates Last Data block cycle to swich sending OS
    logic                                    null_flit_sent ;                            // Send Null FLIT CXL (pulse)
    logic  [NW-1:0]                          active_data_dw_bitmap ;                     // Indicates current active DW size (bit[0]:DW0 , bit[1]:DW1 ...)
    logic  [NW-1:0]                          next_active_data_dw ;                       // Indicates current sending Data DW
    logic  [NW-1:0]                          crnt_active_data_dw ;                       // Indicates current sending Data DW
    logic  [NW-1:0]                          crnt_active_pid ;                           // Indicates current sending Data PID

    logic  [NW-1:0]                          mask_sdp_det ;                              // Masking invalid PM DLLP. This is from original design.
    logic                                    crnt_start_pkt_vld ;                        // Masking invalid PM DLLP. This is from original design.
    logic                                    crnt_end_pkt ;                              // Masking invalid PM DLLP. This is from original design.
    logic                                    vld_pkt_in_progress ;                       // Masking invalid PM DLLP. This is from original design.
    logic                                    vld_pkt_wo_invld_dlp ;                      // Masking invalid PM DLLP. This is from original design.
    logic  [DW-1:0]                          muxed_data ;                                // Muxted TLP/DLLP Data
    logic  [NBYTE-1:0]                       muxed_datak ;                               // Muxted TLP/DLLP Data K
    logic  [NB-1:0]                          active_byte_bitmap ;                        // Active PIPE width bitmap [0]:byte0, [1]:byte1 ... [15]:byte15
    logic  [2:0]                             active_lane_code ;                          // Active lane code : 3'd0:x1, 3'd1:x2 , 3'd2:x4 , 3'd3:x8 , 3'd4:x16 
    logic  [NB-1:0][NL-1:0][NBYTE-1:0][4:0][LOG2NBYTE-1:0]     data_framing_byte_table ;                   // Selected byte number for Data framing each Byte in any the number of lane.
    logic                                    flit_lpbk_slv_halt ;                        // Indicates Loopback Slave in Flit Mode, If this signals is 1, assert xmtbyte_xdlh_halt.

// --- Set fix value to input signals which are not exist by configuration.
    logic  int_lpbk_en;
    assign int_lpbk_en = lpbk_master && ltssm_in_lpbk_active && cfg_prbs_en;

// -----------------------------------
//  Common signals
// -----------------------------------

    always_comb begin
        next_grnt_is_data                      = next_grant[G_DATA_BIT] | next_grant[G_EDS_BIT] ;
    end


    // Indicates previous state / Current grant is OS
    always_ff @(posedge core_clk or negedge core_rst_n) begin : grant_PROC
        if (!core_rst_n) begin
            crnt_grnt_is_data                    <= #TP '0 ;
        end
        else begin
            crnt_grnt_is_data                    <= #TP next_grnt_is_data ;
        end
    end
    
// -----------------------------------
//  Control signals
// -----------------------------------

    // XDLH Bus width
    always_comb begin
        crnt_xdlh_data_width_byte = $bits(crnt_xdlh_data_width_byte)'( NBYTE ) ;
        crnt_msb_nw               = $bits(crnt_msb_nw)'( NW - 1 ) ;
    end

    // PIPE Bus width
    always_comb begin
        case( active_nb )
            'd2     : next_pipe_width_byte   = $bits(next_pipe_width_byte)'( int_data_smlh_link_mode_pre << 1 ) ;        // 2s
            'd4     : next_pipe_width_byte   = $bits(next_pipe_width_byte)'( int_data_smlh_link_mode_pre << 2 ) ;        // 4s
            'd8     : next_pipe_width_byte   = $bits(next_pipe_width_byte)'( int_data_smlh_link_mode_pre << 3 ) ;        // 8s
            default : next_pipe_width_byte   = '0 ;                                                                  // Never met
        endcase
    end

    always_ff @(posedge core_clk or negedge core_rst_n) begin : crnt_pipe_width_byte_PROC
        if (!core_rst_n) begin
            crnt_pipe_width_byte             <= #TP '0 ;
            data_width_minus_pipe_width      <= #TP '0 ;
        end
        else begin
            crnt_pipe_width_byte             <= #TP next_pipe_width_byte ;
            data_width_minus_pipe_width      <= #TP $bits(data_width_minus_pipe_width)'( crnt_xdlh_data_width_byte - next_pipe_width_byte ) ;
        end
    end
    
    // Data sending count
    always_comb begin
        next_data_byte_count                   = data_byte_count ;
        next_data_byte_count_plus_pipe_width   = data_byte_count_plus_pipe_width ;

        if( ~crnt_stream[DATA_STREAM_BIT] || eds_ack ) begin
          next_data_byte_count                           = '0 ;
          next_data_byte_count_plus_pipe_width           = next_pipe_width_byte ;
        end
        else if( next_block_is_null_ieds ) begin   // For inserting iEDS block
           next_data_byte_count                           = '0 ;
           next_data_byte_count_plus_pipe_width           = next_pipe_width_byte ;
        end
        else if( crnt_grant[G_SKP_BIT] && cxl_mode_enable && ~ltssm_flit_mode_enable ) begin
           next_data_byte_count                           = stored_byte_count ;
           next_data_byte_count_plus_pipe_width           =  $bits(next_data_byte_count_plus_pipe_width)'( stored_byte_count + next_pipe_width_byte ) ;       // not used when CXL mode
        end
        else if( internal_txdata_dv && crnt_grnt_is_data && ~mask_tlp_dllp_timing 
              && (    in_data_progress 
                   || eds_in_progress
                                     ) ) begin 
            next_data_byte_count                           = ( (data_byte_count + next_pipe_width_byte) == crnt_xdlh_data_width_byte ) ? '0
                                                           :  last_chunk                                                               ? '0
                                                           : $bits(next_data_byte_count)'( data_byte_count + next_pipe_width_byte ) ;

            next_data_byte_count_plus_pipe_width           = ( data_byte_count_plus_pipe_width == crnt_xdlh_data_width_byte )          ? next_pipe_width_byte
                                                           :  last_chunk                                                               ? next_pipe_width_byte
                                                           : $bits(next_data_byte_count_plus_pipe_width)'( data_byte_count_plus_pipe_width + next_pipe_width_byte ) ;
      end
    end

    always_ff @(posedge core_clk or negedge core_rst_n) begin : data_byte_count_PROC
        if (!core_rst_n) begin
            data_byte_count                     <= #TP '0 ;
            data_byte_count_plus_pipe_width     <= #TP '0 ;
        end
        else begin
            data_byte_count                     <= #TP next_data_byte_count ;
            data_byte_count_plus_pipe_width     <= #TP next_data_byte_count_plus_pipe_width ;
        end
    end

    // TLP/DLLP end before all xdlh_xmlh_data_i dat is sent.
    always_comb begin
        next_pkt_is_early_end = (next_xdlh_xmlh_eot_i > next_xdlh_xmlh_stp_i) & (next_xdlh_xmlh_eot_i > next_xdlh_xmlh_sdp_i) & ~next_xdlh_xmlh_eot_i[crnt_msb_nw] ; // TLP/DLLP end next cycle and not start new TLP/DLLP
        early_pkt_done        = early_pkt_end & ( (xdlh_xmlh_eot_i >> data_byte_count_plus_pipe_width[LOG2NBYTE-1:2]) == '0 ) ;
    end
    
    always_ff @(posedge core_clk or negedge core_rst_n) begin : early_pkt_end_PROC
        if (!core_rst_n) begin
            early_pkt_end            <= #TP '0 ;
        end
        else begin
            if( ltssm_flit_mode_enable || cxl_mode_enable || ~crnt_stream[DATA_STREAM_BIT] || eds_ack ) begin
                early_pkt_end            <= #TP '0 ;
            end
            else if(   next_grant[G_DATA_BIT] && (ltssm_cmd_i != `SEND_IDLE) && internal_txdata_dv_pre && next_pkt_is_early_end ) begin         
                early_pkt_end            <= #TP 1'b1 ;
            end
            else begin
                early_pkt_end            <= #TP '0 ;
            end
        end
    end
    


    always_ff @(posedge core_clk or negedge core_rst_n) begin : stored_byte_count_PROC
        if (!core_rst_n) begin
            stored_byte_count             <= #TP '0 ;
        end
        else begin
            if( ~crnt_stream[DATA_STREAM_BIT] ) begin
                stored_byte_count           <= #TP '0 ;
            end
            else if( next_block_is_null_ieds || ( ~null_ieds_insertion_en & last_data_block_cycle_for_os ) ) begin
                stored_byte_count           <= #TP ( (data_byte_count + crnt_pipe_width_byte) == crnt_xdlh_data_width_byte ) ? '0
                                                 : $bits(stored_byte_count)'( data_byte_count + crnt_pipe_width_byte ) ;
            end
        end
    end            

    // Mask lower bit which are not used in the configuration to 0. This is for synthesis timing optimization.
    always_comb begin
             data_byte_count_msk_lowb            = data_byte_count ;
             data_byte_count_msk_lowb[0]         = '0 ;
    end


    always_comb begin
            last_chunk             = ( (data_byte_count_msk_lowb == data_width_minus_pipe_width) | early_pkt_done )
                                   & ~mask_tlp_dllp_timing 
                                   & internal_txdata_dv ;
    end

// -----------------------------------
//  Layer2 TLP/DLLP I/F
// -----------------------------------

    // Indicates Loopback Slave in Flit Mode, If this signals is 1, assert xmtbyte_xdlh_halt_o, not send any data from Layer2.
    always_ff @( posedge core_clk or negedge core_rst_n ) begin : flit_lpbk_slv_halt_PROC
        if ( ~core_rst_n ) begin
            flit_lpbk_slv_halt             <= #TP '0 ;
        end
        else if( ~lpbk_master && ltssm_flit_mode_enable 
              && ( (smlh_ltssm_state == S_LPBK_ACTIVE) || (smlh_ltssm_state == S_LPBK_EXIT) || (smlh_ltssm_state == S_LPBK_EXIT_TIMEOUT) ) )begin
            flit_lpbk_slv_halt             <= #TP 1'b1 ;
        end
        else begin
            flit_lpbk_slv_halt             <= #TP '0 ;
        end
    end

    always_comb begin
        xmtbyte_xdlh_halt_o     = ~crnt_grnt_is_data                                 // Current Grant is not data
                                | ~(in_data_progress & last_chunk)                   // PIPE bus width < Data Bus width
                                | mask_tlp_dllp_timing                               // FREQ_STEP Algin timing for TLP/DLLP
                                | (crnt_grant[G_EDS_BIT] & ~cxl_mode_enable)         // PCIe EDS replacement
                                | null_ieds_insertion_in_progress                    // CXL Null iEDS length cut insertion
                                | flit_lpbk_slv_halt                                 // Loopback Sleve when Flit Mode.

                                ;
    end

// -----------------------------------
//  Make K Code for Gen1/2
// -----------------------------------
    always_comb begin
        for(int ii = 0 ; ii < NW ; ii++ ) begin
            xdlh_xmlh_datak[ii*4]                =  int_xdlh_xmlh_pad[ii] | xdlh_xmlh_sdp_i[ii] | xdlh_xmlh_stp_i[ii] ;
            xdlh_xmlh_datak[ii*4 + 1]            =  int_xdlh_xmlh_pad[ii] ;
            xdlh_xmlh_datak[ii*4 + 2]            =  int_xdlh_xmlh_pad[ii] ;
            xdlh_xmlh_datak[ii*4 + 3]            =  int_xdlh_xmlh_pad[ii] | xdlh_xmlh_eot_i[ii] ;
        end
    end

// -----------------------------------
//  PAD replacement
// -----------------------------------

    // PAD request
    always_comb begin
        int_xdlh_xmlh_pad       = 
                                    (crnt_rate.enc_8b10b & |int_data_smlh_link_mode[4:3]) ? xdlh_xmlh_pad_i : 
                                    '0 ;
    end

    // PAD replacement
    always_comb begin
        pad_data       = xdlh_xmlh_data_i;
        for(int ii = 0 ; ii < NW ; ii++ ) begin
            // DW0 never repleace to PAD
            if( ii != 0 ) pad_data[ii*32 +: 32] = int_xdlh_xmlh_pad[ii] ? {`PAD_8B, `PAD_8B, `PAD_8B, `PAD_8B }
                                                                        : xdlh_xmlh_data_i[ii*32 +: 32] ;    
        end
    end




// -----------------------------------
//  EDS Token replacement
// -----------------------------------

    // Start EDS replacement point
    always_comb begin
        eds_start    = crnt_grant[G_EDS_BIT] & ~cxl_mode_enable & (
                      ((crnt_pipe_width_byte[1:0] == 2'b00) & internal_txendblock) ) ;                                      // other than above / EDS is on the last cycle of the block. (4byte or bigger data is send in a cycle)
    end

    // 2nd or later cycle EDS replacement assert when internal bus width is 8B or 16B.
    always_ff @(posedge core_clk or negedge core_rst_n) begin : eds_start_latch_PROC
        if (!core_rst_n) begin
            eds_start_latch             <= #TP '0 ;
        end
        else begin
            if( internal_txendblock ) begin
                eds_start_latch           <= #TP '0 ;
            end
            else if( eds_start ) begin 
                eds_start_latch           <= #TP 1'b1 ;
            end
        end
    end

    // EDS replacement is in progress.
    always_comb begin
        eds_in_progress = eds_start | eds_start_latch ;
    end

    // EDS Symbol Data (Placed upper 4byte of current PIPE width).
    always_ff @(posedge core_clk or negedge core_rst_n) begin : eds_symbol_PROC
        if (!core_rst_n) begin
            eds_symbol             <= #TP '0 ;
        end
        else begin
            if( next_stream[DATA_STREAM_BIT] ) begin
                if( next_pipe_width_byte <= 'd4 ) begin
                    eds_symbol             <= #TP $bits(eds_symbol)'( {`EDS_TOKEN_3, `EDS_TOKEN_2, `EDS_TOKEN_1, `EDS_TOKEN_0} ) ;
                end
                else begin
                    eds_symbol             <= #TP $bits(eds_symbol)'( {`EDS_TOKEN_3, `EDS_TOKEN_2, `EDS_TOKEN_1, `EDS_TOKEN_0} << { (next_pipe_width_byte-4) , 3'd0 } ) ;
                end
            end
        end
    end


    // EDS replacement Data
    always_comb begin
                              eds_data              = '0 ;
        if ( int_lpbk_en )begin
            eds_data              = '0 ;
        end else if( eds_in_progress )begin
            eds_data              = eds_symbol ;
        end
    end
    

    // EDS replacement is done (output to xmlh_arb_ctl
    always_comb begin
        eds_ack      =  internal_txendblock &
                      (     eds_in_progress          // PCIe EDS
                        | ( ~null_ieds_insertion_en & last_data_block_cycle_for_os )        // CXL iEDS other than Null iEDS length cut
                        | ( null_ieds_insertion_in_progress )                               // CXL iEDS Null iEDS length cut
                     ) ;
    end
    


// -----------------------------------
//  iEDS Token replacement(CXL)
// -----------------------------------

    // Fags
    always_comb begin
        null_ieds_insertion_condition  = ~ltssm_cxl_sh_bypass & ( |int_data_smlh_link_mode[2:0] ) ;   // syncheader bypass is disabled and x4/x2/x1.
        last_flit_start                =  crnt_grant[G_EDS_BIT] & cxl_mode_enable & (|crnt_active_pid) ;      // last flit start
        last_flit_in_progres           = last_flit_start | last_flit_start_latched ;
        last_data_block_cycle_for_os   = last_flit_in_progres & internal_txendblock & (last_flit_block_cnt == last_flit_block_num) ; 
        next_block_is_null_ieds        = null_ieds_insertion_en & last_data_block_cycle_for_os  ;
    end
    
    // iEDS replacement Data
    always_comb begin
        ieds_data               = xdlh_xmlh_data_i ;
        null_ieds_insertion_det = '0 ;

        // Protocol ID replacement other than Null iEDS length Cut
        for( int ii = 0 ; ii < NW ; ii++ ) begin
            if( crnt_grant[G_EDS_BIT] & cxl_mode_enable & xdlh_xmlh_pid[ii] ) begin
                case( xdlh_xmlh_data_i[ii*32 +: 16] ) 
                    16'hFFFF : ieds_data[ii*32 +: 16]       = 16'hD2D2 ;                                                                           // CXL.io 
                    16'h5555 : ieds_data[ii*32 +: 16]       = 16'h8787 ;                                                                           // CXL.cache / CXL.mem 
                    16'h9999 : begin
                               ieds_data[ii*32 +: 16]       =  null_ieds_insertion_condition                             ? 16'h9999 : 16'h4B4B ;   // Null Flit
                               null_ieds_insertion_det[ii]  = (null_ieds_insertion_condition & ~last_flit_start_latched) ? 1'b1     : '0       ;   // Null Flit
                              end
                    16'hCCCC : ieds_data[ii*32 +: 16]       = 16'h1E1E ;                                                                           // CXL ARB / ALMP
                    default  : ieds_data[ii*32 +: 16]       = xdlh_xmlh_data_i[ii*32 +: 16] ;                                                      // Other
                endcase
            end
        end

        // Protocol ID replacement other than Null iEDS length Cut
        if( null_ieds_insertion_in_progress ) begin
            ieds_data               = '0 ;
            if ( (internal_txtblock_symbol_cnt == '0) 
                      ) begin
                ieds_data[15:0]           = 16'h4B4B ;   // Null Flit iEDS
            end
        end
    end


    //  The number of block the last flit(depends on the number of lane)(0's base)
    always_ff @(posedge core_clk or negedge core_rst_n) begin : last_flit_block_num_PROC
        if (!core_rst_n) begin
            last_flit_block_num             <= #TP '0 ;
        end
        else begin
            case( int_data_smlh_link_mode_pre ) 
                6'd1    : last_flit_block_num             <= #TP 3'd4 ;     // 4 data blocks when x1.
                6'd2    : last_flit_block_num             <= #TP 3'd2 ;     // 2 data blocks when x2.
                6'd4    : last_flit_block_num             <= #TP 3'd1 ;     // 1 data blocks when x4.
                default : last_flit_block_num             <= #TP 3'd0 ;     // 0 data blocks when x8 or higher.
            endcase            
        end
    end


    // Last Flit/Null iEDS Token insertion flag(level) , Block count for the last flit
    always_ff @(posedge core_clk or negedge core_rst_n) begin : last_flit_start_latched_PROC
        if (!core_rst_n) begin
            last_flit_start_latched             <= #TP '0 ;
            last_flit_block_cnt                 <= #TP '0 ;
            null_ieds_insertion_en              <= #TP '0 ;
            null_ieds_insertion_in_progress     <= #TP '0 ;
        end
        else if( eds_ack )  begin
            last_flit_start_latched             <= #TP '0 ;
            last_flit_block_cnt                 <= #TP '0 ;
            null_ieds_insertion_en              <= #TP '0 ;
            null_ieds_insertion_in_progress     <= #TP '0 ;
        end
        else begin
            if( last_flit_start ) begin
                last_flit_start_latched             <= #TP 1'b1 ;
            end
            if( last_flit_in_progres && internal_txendblock ) begin
                last_flit_block_cnt                 <= #TP  $bits(last_flit_block_cnt)'(last_flit_block_cnt + 1'b1) ;
            end
            if( |null_ieds_insertion_det ) begin
                null_ieds_insertion_en              <= #TP 1'b1 ;
            end
            if( next_block_is_null_ieds ) begin
                null_ieds_insertion_in_progress     <= #TP 1'b1 ;
            end
        end
    end
    
    //  current sending Data PID to know last flit start pooint
    always_comb begin
        for( int ii = 0 ; ii < NW ; ii++ ) begin   // Masked upper bit by curret Data width
            if( crnt_pipe_width_byte[LOG2NBYTE:2] <= ii) active_data_dw_bitmap[ii] = '0 ;
            else                                         active_data_dw_bitmap[ii] = 1'b1 ;
        end

        next_active_data_dw =  $bits(next_active_data_dw)'( active_data_dw_bitmap  << next_data_byte_count[LOG2NBYTE-1:2] ) ;   // DW shift of current data byte

        crnt_active_pid = '0 ;
        crnt_active_pid    = xdlh_xmlh_pid & crnt_active_data_dw ;          // If 4S or above, Data width may be 1024bit
    end

    always_ff @(posedge core_clk or negedge core_rst_n) begin : crnt_active_data_dw_PROC
        if (!core_rst_n) begin
            crnt_active_data_dw            <= #TP '0 ;
        end
        else begin
            crnt_active_data_dw            <= #TP next_active_data_dw ;
        end
    end
    


// --------------------------------------------------
// Masking DLLP (this function is from original design
// --------------------------------------------------

// If DLLP is a PM DLLP {DLLP Type = 8'b0010xxxx}, check that SDP Token is
// correct with regard to current_data_rate. Mask DLLP and insert IDL if SDP
// token is incorrect for current_data_rate
    always_comb begin
       for(int ii = 0 ; ii < NW ; ii++) begin
            if( crnt_rate.enc_8b10b ) begin
                mask_sdp_det[ii] = xdlh_xmlh_sdp_i[ii] & (xdlh_xmlh_data_i[ii*32 +: 16] == `SDP_16B) & (xdlh_xmlh_data_i[ii*32+20 +: 4] == 4'b0010) ;
            end
            else begin
                mask_sdp_det[ii] = xdlh_xmlh_sdp_i[ii] & (xdlh_xmlh_data_i[ii*32 +: 8]  == `SDP_8B ) & (xdlh_xmlh_data_i[ii*32+12 +: 4] == 4'b0010) ;
            end
        end

        crnt_start_pkt_vld = (|xdlh_xmlh_stp_i) || ( (|xdlh_xmlh_sdp_i) && (mask_sdp_det == '0) ) ;
        crnt_end_pkt       = (xdlh_xmlh_eot_i > xdlh_xmlh_stp_i) & (xdlh_xmlh_eot_i > xdlh_xmlh_sdp_i) ;

    end

// vld_pkt_wo_invld_dlp is always asserted for TLPs. For DLLPs, if it is a PM
// DLLP then the SDP token is checked against the current_data_rate. If there
// is an error, IDLs are transmitted instead of the DLLP. pkt_in_progress is
// used for advancing state machine and unhalting datapath.
// valid_pkt_in_progress is used for selecting valid xmt data
    always_ff @(posedge core_clk or negedge core_rst_n) begin : vld_pkt_in_progress_PROC
        if (!core_rst_n) begin
            vld_pkt_in_progress             <= #TP '0 ;
        end
        else if( ltssm_flit_mode_enable || cxl_mode_enable ) begin    // Flit case
                vld_pkt_in_progress             <= #TP 1'b1 ;
        end
        else begin
            if( crnt_end_pkt && last_chunk )  begin
                vld_pkt_in_progress             <= #TP '0 ;
            end
            else if( crnt_start_pkt_vld ) begin
                vld_pkt_in_progress             <= #TP 1'b1 ;
            end
        end
    end
    
    always_comb begin
        vld_pkt_wo_invld_dlp = vld_pkt_in_progress | crnt_start_pkt_vld ;
    end

// -----------------------------------
//  Data Mux (EDS/iEDS/PAD)
// -----------------------------------

    always_comb begin
                                                                                         muxed_data = '0 ;
                if( ~mask_tlp_dllp_timing  & in_data_progress  & vld_pkt_wo_invld_dlp )  muxed_data = pad_data ;
                if( crnt_grant[G_EDS_BIT] & ~cxl_mode_enable )                           muxed_data = eds_data ;
                if( crnt_grant[G_EDS_BIT] &  cxl_mode_enable )                           muxed_data = ieds_data ;


                                                                                         muxed_datak = '0 ;
                if( ~mask_tlp_dllp_timing  & in_data_progress  & vld_pkt_wo_invld_dlp  ) muxed_datak = xdlh_xmlh_datak ;



    end



// -----------------------------------
//  Data Framing
// -----------------------------------

    // Selected byte number for Data framing each Byte in any the number of lane.
    always_comb begin
        for( int byte_num = 0 ; byte_num < NB ; byte_num++ ) begin
            for( int lane_num = 0 ; lane_num < NL ; lane_num++ ) begin
                for( int byte_cnt = 0 ; byte_cnt < NBYTE ; byte_cnt++ ) begin
                    data_framing_byte_table[byte_num][lane_num][byte_cnt][0]   =  (LOG2NBYTE)'( (byte_num * 1 ) + lane_num + byte_cnt ) ;         // x1 case
                    data_framing_byte_table[byte_num][lane_num][byte_cnt][1]   =  (LOG2NBYTE)'( (byte_num * 2 ) + lane_num + byte_cnt ) ;         // x2 case
                    data_framing_byte_table[byte_num][lane_num][byte_cnt][2]   =  (LOG2NBYTE)'( (byte_num * 4 ) + lane_num + byte_cnt ) ;         // x4 case
                    data_framing_byte_table[byte_num][lane_num][byte_cnt][3]   =  (LOG2NBYTE)'( (byte_num * 8 ) + lane_num + byte_cnt ) ;         // x8 case
                    data_framing_byte_table[byte_num][lane_num][byte_cnt][4]   =  (LOG2NBYTE)'( (byte_num * 16) + lane_num + byte_cnt ) ;         // x16 case
                end
            end
        end
    end


    // Active PIPE width bitmap [0]:byte0, [1]:byte1 ... [15]:byte15
    always_ff @(posedge core_clk or negedge core_rst_n) begin : active_byte_bitmap_PROC
        if (!core_rst_n) begin
            active_byte_bitmap             <= #TP '0 ;
        end
        else if( ~crnt_grnt_is_data ) begin        // this condition is just for clock gating
            for( int ii = 0 ; ii < NB ; ii++ ) begin
                active_byte_bitmap[ii]     <= #TP (active_nb > ii) ? 1'b1 : 1'b0 ;
            end
        end
    end

    // Active lane code : 3'd0:x1, 3'd1:x2 , 3'd2:x4 , 3'd3:x8 , 3'd4:x16 
    always_ff @(posedge core_clk or negedge core_rst_n) begin : active_lane_code_PROC
        if (!core_rst_n) begin
            active_lane_code             <= #TP '0 ;
        end
        else begin
            case( int_data_smlh_link_mode_pre ) 
                                    6'd1    : active_lane_code             <= #TP 3'd0 ;            // x1
   6'd2    : active_lane_code             <= #TP 3'd1 ;     // x2
   6'd4    : active_lane_code             <= #TP 3'd2 ;     // x4
   6'd8    : active_lane_code             <= #TP 3'd3 ;     // x8
                                    default : active_lane_code             <= #TP 3'd4 ;            // x16
            endcase            
        end
    end
    
    // Data Framing
    always_comb begin
        for( int lane_num = 0 ; lane_num < NL ; lane_num++ ) begin
                data_gen_data [lane_num]                    = '0 ;
                data_gen_datak[lane_num]                    = '0 ;
            for( int byte_num = 0 ; byte_num < NB ; byte_num++ ) begin
              if ( int_lpbk_en )begin
                data_gen_data [lane_num][byte_num*8 +: 8]   =  '0 ;
                data_gen_datak [lane_num][byte_num]   =  '0 ;
              end else begin
                data_gen_data [lane_num][byte_num*8 +: 8]   =  int_data_ltssm_lanes_active[lane_num] & active_byte_bitmap[byte_num] ?  muxed_data[({data_framing_byte_table[byte_num][lane_num][data_byte_count_msk_lowb][active_lane_code] , 3'd0}) +: 8] : '0 ;
                data_gen_datak[lane_num][byte_num]          =  int_data_ltssm_lanes_active[lane_num] & active_byte_bitmap[byte_num] ? muxed_datak[  data_framing_byte_table[byte_num][lane_num][data_byte_count_msk_lowb][active_lane_code]              ] : '0 ;
              end
            end

            if( ~crnt_rate.enc_8b10b ) begin
                data_gen_datak[lane_num]                    = 
                                                                                    $bits(data_gen_datak[0])'( `SYNC_DATA_BLOCK ) ;
            end
        end
        
    end



// -----------------------------------
//  Output each Flags
// -----------------------------------

    always_comb begin
            null_flit_sent     = '0 ;
        for( int ii = 0 ; ii < NW ; ii++ ) begin
            if( cxl_mode_enable & xdlh_xmlh_pid[ii] & ~xmtbyte_xdlh_halt_o & (xdlh_xmlh_data_i[ii*32 +: 16] == 16'h9999) ) begin 
                null_flit_sent    = 1'b1 ;
            end
        end
    end

    always_ff @(posedge core_clk or negedge core_rst_n) begin : xmtbyte_idle_sent_PROC
        if (!core_rst_n) begin
            xmtbyte_idle_sent             <= #TP '0 ;
        end
        else if( ( ~cxl_mode_enable && in_idle_data_progress )
               || null_flit_sent
               ) begin
            xmtbyte_idle_sent             <= #TP 1'b1 ;
        end
        else begin
            xmtbyte_idle_sent             <= #TP 1'b0 ;
        end
    end

endmodule
