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
// ---    $Id: //dwh/pcie_iip/main/fairbanks/design/Layer1/xmlh_arb_ctl.sv#3 $
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

 
 module xmlh_arb_ctl 
  import xmlh_pkg::*;
  import DWC_pcie_core_pkg::ltssm_state_e;
  import DWC_pcie_core_pkg::S_DETECT_QUIET;
  import DWC_pcie_core_pkg::S_DETECT_ACT;
  import DWC_pcie_core_pkg::S_POLL_COMPLIANCE;
  import DWC_pcie_core_pkg::S_PRE_DETECT_QUIET;
  import DWC_pcie_core_pkg::S_DETECT_WAIT;
  import DWC_pcie_core_pkg::S_CFG_LINKWD_START;
  import DWC_pcie_core_pkg::S_CFG_LANENUM_ACEPT;
  import DWC_pcie_core_pkg::S_CFG_COMPLETE;
  import DWC_pcie_core_pkg::S_RCVRY_LOCK;
  import DWC_pcie_core_pkg::S_LPBK_ENTRY;
  import DWC_pcie_core_pkg::S_LPBK_ACTIVE;
  import DWC_pcie_core_pkg::S_LPBK_EXIT;
  import DWC_pcie_core_pkg::S_LPBK_EXIT_TIMEOUT;
  import DWC_pcie_core_pkg::S_RCVRY_EQ0;
  import DWC_pcie_core_pkg::S_RCVRY_EQ1;
  import DWC_pcie_core_pkg::S_RCVRY_EQ2;
  import DWC_pcie_core_pkg::S_RCVRY_EQ3;
  
                      (
      input  logic                                      core_clk 
    , input  logic                                      core_rst_n 
    , input  logic                                      sticky_rst_n

// =============================================================================
//  , input  logicIO Declarations
// =============================================================================

// Received TLP/DLLP Data Path from Layer2 
    , input  logic                                      xdlh_xmlh_eof                          // Indicates End of Flit 
    , input  logic                                      xdlh_xmlh_sof                          // Indicates Start of Flit 
    , input  logic  [NW-1 :0]                           xdlh_xmlh_stp_i                        // Indicates Start of TLP (1 bit per dword)
    , input  logic  [NW-1 :0]                           xdlh_xmlh_sdp_i                        // Indicates Start of DLLP (1 bit per dword)
    , input  logic  [NW-1 :0]                           xdlh_xmlh_eot_i                        // Indicates End of TLP or DLLP (1 bit per dword)
    , input  logic  [NW-1 :0]                           next_xdlh_xmlh_eot_i                   // 1cycle before of xdlh_xmlh_eot_i
    , input  logic  [NW-1 :0]                           next_xdlh_xmlh_stp_i                   // 1cycle before of xdlh_xmlh_stp_i
    , input  logic  [NW-1 :0]                           next_xdlh_xmlh_sdp_i                   // 1cycle before of xdlh_xmlh_sdp_i
    , input  logic                                      xdlh_xmlh_pkt_pending_i                // XDLH has registered packet pending transmission in Non-Flit mode. When asserted, cannot send EIOS/EIEOS. (SKP can be sent)
    , input  logic                                      xmlh_fm_pending                        // Packet pending indication in Flit mode. When asserted, cannot send EIOS/EIEOS. (SKP can be sent), Flush is not completed.
    , input  logic                                      xfsh_xmlh_buf_empty                    // Indicate xfsh_buf empty
    , input  logic                                      xmlh_fm_flush_ack                      // Flush acknowledge in Flit mode. When deasserted, cannot send EIEOS. (SKP can be sent)
    , input  logic                                      xmlh_cmd_if_lp_ack                     // Low power entry acknowledge in Flit mode. When deasserted, cannot send EIOS. (SKP can be sent)
    , input  logic  [NW-1:0]                            xdlh_xmlh_pid                          // PID location per DW on xdlh_xmlh_data[511:0]. Valid only when CXL,

// Received sending OS/Compliance pattern request from LTSSM
    , input  logic  [3:0]                               ltssm_cmd_i                            // encoded command to notify transmitter of the proper action based on LTSSM states
    , input  logic  [3:0]                               ltssm_cmd_i_d                          // 1cycle delay of ltssm_cmd_i
    , input  logic                                      ltssm_cmd_send_eieos_for_pset_map      // send eieos continuously for pset-coef mapping
    , input  logic  [NL-1:0]                            scramble_lfsr_rollover                 // LFSR value matches seed. Used for inserting EIEOS after a sequence of 65536 uninterrupted TS1s
    , input  logic                                      smlh_l0p_update                        // L0p Up/Downsizning request (1shot)
    , input  logic [3:0]                                ltssm_l0p_cmd                          // encoded command to notify transmitter of the proper action based on LTSSM states
    , input  logic                                      ltssm_cmd_eqts0                        // Indicates TS0 should be sent. 
    , input  logic                                      eqctl_g6_tx_ts0                        // Indicates TS0 should be sent. tx ts0. dsp until 2 ts0s rcvd in eq2 with ec = 10b. usp until 2 ts1s rcvd in eq3 with ec = 11b
    , input  logic                                      link_rx_ts0_to_ts1_pulse               // rx ts0 to ts1 transition

// Return sedning OS response to LTSSM
    , input  logic                                      ltssm_clear                            // used to clear persistency count when a ltssm state transition
    , input  logic  [NL-1:0]                            eqctl_2mask_eieos_pulse                // 2 consecutive EC TS1 rcvd pulse with a request to reset EIEOS count
 
// Mode/State signals
    , input  logic                                      app_sris_mode_i                        // application signal to enable the SRIS mode
    , input  logic                                      ltssm_cxl_sh_bypass                    // SyncHeader_Bypass
    , input  logic                                      cxl_mode_enable                        // Indicates whether the link should operate in CXL or PCIe mode
    , input  ltssm_state_e                              smlh_ltssm_state                       // LTSSM State
    , input  ltssm_state_e                              smlh_ltssm_last                        // indicates last ltssm state (not 1cycle before)
    , input  logic  [NL-1:0]                            ltssm_lpbk_slave_lut                   // lane under test for lpbk slave for Gen5 and above Rate.
    , input  logic                                      ltssm_flit_mode_enable                 // Indicates Flit Mode is enabled.
    , input  logic                                      smlh_link_up                           // Indicates LTSSM is LinkUp
    , input  logic                                      smlh_usp_sris_mode                     // Indicates Upstream port SRIS is enabled from LTSSM.
    , input  logic                                      cfg_flit_sris_clocking                 // Enable SRIS mode form LTSSM for Flit Mode
    , input  logic                                      cfg_comm_clk_config                    // Enable Common Clock(Non-SRIS) mode form LTSSM for Flit Mode
    , input  logic  [10:0]                              cfg_skip_interval                      // the number of symbol times between skip requests. Just for Gen1/2 non-SRIS.
    , input  logic                                      cfg_ext_synch                          // Extended synch for N_FTS configured in CDM
    , input  logic  [5:0]                               smlh_link_mode                         // 10000 -- x16, 01000 -- x8, 00100 -- x4, 00010 -- x2, 00001 -- x1
    , input  logic  [NL-1 :0]                           ltssm_lanes_active                     // LTSSM latched lanes that are active based on the link negotiation
    , input  logic                                      ltssm_ts_cnt_en_i                      // enable TS counting logic to transmit an EIEOS every 32 or 65536 TSs
    , input  logic                                      ltssm_ts_cnt_rst                       // reset TS1/TS2 count for EIEOS interval.
    , input  logic                                      int_ltssm_in_lpbk                      // LTSSM in Loopback.Active state
    , input  logic                                      ltssm_in_lpbkentry                     // LTSSM in Loopback.Entry state
    , input  logic                                      ltssm_in_compliance                    // LTSSM in polling.compliance state
    , input  logic                                      cfg_compliance_sos                     // Send skips during Compliance or Modified Compliance pattern Gen1/2
    , input  logic  [NL-1:0]                            eqctl_mask_eieos                       // Mask EIEOS when Reqcovery.Equalization. Replaces EIEOS OS Identifier with TS1 OS Identifier
    , input  logic                                      lpbk_master                            // indicates that the ltssm is the loopback master
    , input  logic  [AW-1:0]                            active_nb                              // active number of symbols per lane per clock. bit0=1s, bit1=2s, bit2=4s, bit3=8s , bit4=16s
    , input  logic                                      cfg_upstream_port                      // 1: Upstream Port / 0:Downstream Port
    , input  logic [5:0]                                smlh_l0p_link_mode                     // 10000 -- x16, 01000 -- x8, 00100 -- x4, 00010 -- x2, 00001 -- x1
    , input  logic [NL-1:0]                             ltssm_l0p_lanes_active                 // LTSSM latched lanes that are active based on the link negotiation

// Internal xmlh_byte_xmt signals (common)
    , input  data_rate_enc_t                            crnt_rate                               // current data rate shortcut.
    
// Internal xmlh_byte_xmt signals (xmlh_data_gen)
    , input  logic                                      xmtbyte_xdlh_halt_o                     // Halt the flow of data from the xdlh
    , input  logic  [NL-1:0][NBIT-1:0]                  data_gen_data                           // TLP/DLLP Data
    , input  logic  [NL-1:0][NBK-1:0]                   data_gen_datak                          // TLP/DLLP Data Kcode
    , input  logic                                      last_chunk                              // Indicates the last cycle of Data Bus alignment
    , input  logic                                      eds_ack                                 // Indicates EDS insertion is completed

// Internal xmlh_byte_xmt signals (xmlh_os_gen)
    , input  logic  [NL-1:0][NBIT-1:0]                  os_gen_data                             // OS Data
    , input  logic  [NL-1:0][NBK-1:0]                   os_gen_datak                            // OS Data Kcode
    , input  logic  [NL-1:0][NBLOCK-1:0][OSFLG_WD-1:0]  os_gen_ossending                        // Sending OS Flag 
    , input  logic                                      os_send_done                            // Indicated the last cycle of a OS sending.
    , input  logic                                      ossq_send_done                          // Asserted when last cycle of OSSQ sending
    , input  skp_replace_t                              os_gen_skp_os_align_sts                 // Indicates current sending Data have LFSR/Parity field of SKP OS
    , input  logic  [NL-1:0][NBIT-1:0]                  os_gen_data_l0p                         // OS Data (L0p Up/Downsizing)
    , input  logic  [NL-1:0][NBK-1:0]                   os_gen_datak_l0p                        // OS Data Kcode  (L0p Up/Downsizing)
    , input  logic  [NL-1:0][NBLOCK-1:0][OSFLG_WD-1:0]  os_gen_ossending_l0p                    // Sending OS Flag (L0p Up/Downsizing)
    , input  logic                                      l0p_os_send_done                        // Indicated the last cycle of a OS sending.
    , input  logic                                      l0p_ossq_send_done                      // Asserted when last cycle of OSSQ sending(L0p)
    , input  logic [4:0]                                l0p_crnt_ossq_num                       // Indicated the number of OS should be sent in current OSSQ. (0's base)
    , input  skp_replace_t                              l0p_os_gen_skp_os_align_sts             // Indicates current sending Data have LFSR/Parity field of SKP OS
    , input  logic                                      dsp_tx_sris_cloking                     // Downstream Port SRIS Mode
    , input  logic [4:0]                                crnt_ossq_num                           // Indicated the number of OS should be sent in current OSSQ. (0's base)
    , input  logic                                      xmtbyte_fts_sent                        // Indicates all FTS is sent (1shot. Asserted 1st cycle of a packet)

// Internal xmlh_byte_xmt signals (xmlh_cmp_gen)
    , input  logic  [NL-1:0][NBIT-1:0]                  cmp_gen_data                            // Pattern Data
    , input  logic  [NL-1:0][NBK-1:0]                   cmp_gen_datak                           // Pattern Data Kcode
    , input  logic  [NL-1:0][NBLOCK-1:0][OSFLG_WD-1:0]  cmp_gen_ossending                       // Pattern Data OS Flag
    , input  logic  [NL-1:0]                            int_txcompliance                        // PIPE TxCompliance signal (before FF). This signal will be aligned align with output data(xmtbyte_txdata,xmtbyte_txdatak)
    , input  logic                                      cmp_block_done                          // Asserted when last cycle of pattern block sending
    , input logic                                       mcmp_gen6_skp_in_progress               // Gen6 SKP OS is sending in Modified compliance pattern (for 8S or below)
    , input logic                                       mcmp_gen6_skp_done                      // The last cycle of Gen6 SKP OS in Modified compliance pattern (for 8S or below)



// =============================================================================
// output IO Declarations
// =============================================================================
// Received TLP/DLLP Data Path from Layer2 
    , output logic                                     xmlh_skip_pending                       // XMLH Skip pending to XDLH TLP GEN. Request to pause TLP/DLLP sending to Layer2. Assert for sending SKIP OS for Gen1/2/3/4/5 Non-Flit, because SKP is needed to send Packet boundary.
    , output logic                                     xmtbyte_cmd_is_data                     // xmtbyte state machine is waiting for packet start or packet end
    , output logic                                     xmlh_xfsh_last_flit                     // Indicate lat flit of datasteam. Used to pause TLP/DLLP from Layer2 if 32s & FREQ_STEP.
    , output logic                                     xmlh_rst_flit_alignment                 // When set to 1 indicates that the LTSSM is moving to Recovery state after completing the current packet. The arbiter must place the new flit PID from byte. Used only when CXL

// Sending TLP/DLLP  and PIPE signals to scrambler/xmlh_pipe Data Path
    , output logic                                     xmtbyte_txdata_dv                       // Data Valid, gen1/gen2: always 1, gen3: 0 for one cycle every 4*active_nb blocks
    , output logic [NL-1:0][(NB*8)-1:0]                xmtbyte_txdata                          // Transmit data to the phy
    , output logic [NL-1:0][(NBK)-1:0]                 xmtbyte_txdatak                         // Indicates which bytes are k characters.  1 bit per byte of xmtbyte_txdata
    , output logic [NL-1:0][NBLOCK-1:0][OSFLG_WD-1:0]  xmtbyte_ossending                       // Sending OS Flag 
    , output logic [NL-1:0][(TXSB_WD)-1:0]             xmtbyte_txstartblock                    // Indicates the starting symbol for a 130b block
    , output logic [NL-1:0][2:0]                       xmtbyte_skp_os_align_sts                // Indicates current sending Data have LFSR/Parity field of SKP OS. Cannot have enum packed array. So, modified logic signal.
    , output logic [NL-1:0]                            xmtbyte_txelecidle                      // Lanes to put in electrical idle
    , output logic                                     xmtbyte_ltssm_in_compliance             // Indicates LTSSM is in Compliance 1 cycle delay of ltssm_in_compliance
    , output logic                                     xmtbyte_link_in_training                // Indicates byte machine is sending training sequences or compliance pattern
    , output logic                                     xmtbyte_l0p_link_in_training            // Indicates byte machine is sending training sequences or compliance pattern
    , output logic                                     xmtbyte_g5_lpbk_deassert                // deassert loopback signal at gen5 rate in LPBK_EXIT_TIMEOUT
    , output logic                                     xmtbyte_txdetectrx_loopback             // Indicates detectrx or loopback mode
    , output logic [NL-1:0]                            xmtbyte_txcompliance                    // Set negative running disparity (for compliance pattern)

// Return sedning OS response to LTSSM
    , output logic                                     xplh_xmlh_sof                           // start of flit
    , output logic                                     xmtbyte_l0p_linkwidth_changed           // Indicates L0p Up/Downsizing is completed

// Return sedning TLP/DLLP response to Layer2
    , output logic                                     xmtbyte_stp_start                       // stp starts transmission in MAC

// For Flit Performance Mesurement
    , output logic                                     xmbyte_flit_data_stream                 // Indicates DataStream and Flit Mode. 

// Mode/State signals
    , output logic                                     xmtbyte_sris_mode_enabled               // Indicates SRIS mode is enabled
    , output logic                                     xmtbyte_l0p_sris_mode_enabled           // Indicates SRIS mode is enabled or app_sris_mode_i=1
    , output logic                                     xmtbyte_l0p_state_in_upsize             // Indicates L0p upsizing netogiation is in progress. This is for Flit Performance mesurement.
    , output logic                                     xmtbyte_sris_enable                     // PIPE Interface SRISEnable

// Internal xmlh_byte_xmt signals (common)
    , output grant_t                                   next_grant                              // Arbitration grant (next)
    , output grant_t                                   crnt_grant                              // Arbitration grant (Current)
    , output logic                                     internal_txdata_dv                      // Data Valid, gen1/gen2: always 1, gen3: 0 for one cycle every 4*active_nb blocks / Data throttling
    , output logic                                     internal_txdata_dv_pre                  // 1 cycle before of internal_txdata_dv
    , output logic                                     internal_txstartblock                   // Indicates the starting symbol for a 130b block
    , output logic                                     internal_txendblock                     // Indicates the ending symbol for a 130b block
    , output logic [4:0]                               internal_txtblock_symbol_cnt            // Indicates the current symbol count for a 130b block
    , output logic  [NL-1 :0]                          int_data_ltssm_lanes_active             // Data Link width (Not L0p Up/Downsize OS lane width) : LTSSM latched lanes that are active based on the link negotiation
    , output logic  [NL-1 :0]                          int_l0p_ltssm_lanes_active              // Data Link width (L0p Up/Downsize OS lane width) : LTSSM latched lanes that are active based on the link negotiation
    , output logic  [5:0]                              int_data_smlh_link_mode                 // Data Link width (Not L0p Up/Downsize OS lane width) : 10000 -- x16, 01000 -- x8, 00100 -- x4, 00010 -- x2, 00001 -- x1
    , output logic  [NL-1 :0]                          int_data_ltssm_lanes_active_pre         // Data Link width (Not L0p Up/Downsize OS lane width) : LTSSM latched lanes that are active based on the link negotiation
    , output logic  [5:0]                              int_data_smlh_link_mode_pre             // Data Link width (Not L0p Up/Downsize OS lane width) : 10000 -- x16, 01000 -- x8, 00100 -- x4, 00010 -- x2, 00001 -- x1
    , output l0p_state_t                               crnt_l0p_state                          // L0p Up/Downsizing state (current)

// Internal xmlh_byte_xmt signals (xmlh_os_gen)
    , output stream_t                                  next_stream                             // Indicates Current Stream(Data/OS/CMP or EIDLE) (Next)
    , output stream_t                                  crnt_stream                             // Indicates Current Stream(Data/OS/CMP or EIDLE) (Current)
    , output logic                                     ctl_skp_enable                          // Indicates Control SKP should be set if 1.
    , output logic                                     ts0_sending_req                         // Indicates Sending TS0 request 
    , output logic                                     ts1_sending_req                         // Indicates Sending TS1 request 
    , output logic                                     ts2_sending_req                         // Indicates Sending TS2 request  
    , output grant_t                                   next_l0p_grant                          // Arbitration grant for L0p Up/Downsizing (next)
    , output grant_t                                   crnt_l0p_grant                          // Arbitration grant for L0p Up/Downsizing (Current)
    , output logic                                     ts1_sending_req_l0p                     // Indicates Sending TS1 request (L0p Up/Downsizing)
    , output logic                                     ts2_sending_req_l0p                     // Indicates Sending TS2 request (L0p Up/Downsizing)

// Internal xmlh_byte_xmt signals (xmlh_data_gen)
    , output logic                                     mask_tlp_dllp_timing                    // FREQ_STEP Algin timing for TLP/DLLP
    , output logic                                     in_data_progress                        // Indicates Reveing TLP/DLLP from Layer2 progress
    , output logic                                     in_idle_data_progress                   // Indicates IDLE Data is transmitting

// Internal xmlh_byte_xmt signals (xmlh_cmp_gen)
    , output logic                                     sris_mode_on                            // Indicates SRIS is on used internally.
    );




// ---------------------------------------
// Declaration
// ---------------------------------------
    logic                            skp_os_req ;                                    // Sending SKP OS request
    logic                            eie_os_req ;                                    // Sending EIE OS request
    logic                            eie_8sym_req ;                                  // Sending eight EIE Symbol request
    logic                            sds_os_req ;                                    // Sending SDS OS request
    logic                            eds_token_req ;                                 // Sending EDS Token request
    logic                            ei__os_req ;                                    // Sending EI OS request
    logic                            ts0_os_req ;                                    // Sending TS0 OS request
    logic                            ts1_os_req ;                                    // Sending TS1 OS request
    logic                            ts2_os_req ;                                    // Sending TS2 OS request
    logic                            fts_os_req ;                                    // Sending FTS OS request
    logic                            cmp_ptn_req ;                                   // Sending Compliance Pattern request
    logic                            mcmp_ptn_req ;                                  // Sending Modified Compliance Pattern request
    logic                            eidle_req ;                                     // Keeping E-IDLE Request

    logic                            ts1_os_condition ;                              // Sending TS1 OS condition
    logic                            fts_phase_128b130b ;                            // Indicate N_FTS phase from EIEOS to SDS sending.
    logic                            os_mask_phase ;                                 // Indicate all OS should not be sent.(After SDS or SKP in datastream)
    logic  [CMD_NORM_WD:0]           waiting_tdlp_idle ;                             // If this bit is set, shall not exit Data Stream this signal is from original logic.
    logic                            ei_eie_sending_en ;                             // If this signals is 0, cannot send EI/EIE because TLP/DLLP flush is not done.
    logic                            xdlh_xmlh_pkt_pending_i_1d ;                    // 1 cycle delay of xdlh_xmlh_pkt_pending_i
    logic                            xdlh_xmlh_pkt_pending_i_2d ;                    // 2 cycle delay of xdlh_xmlh_pkt_pending_i
    logic                            xdlh_xmlh_pkt_pending ;                         // Internal use of xdlh_xmlh_pkt_pending_i

    logic  [TIMER_BITS-1:0]          symbol_count_skp_8b10b ;                        // Skip timer for 2.5 GT/s and 5 GT/s data rate
    logic  [TIMER_BITS-1:0]          symbol_interval_8b10b ;                         // The number of Symbol for SKP interaval.
    logic  [1:0]                     symbol_countup_val_8b10b ;                      // Count up value of Symbol timer (Gen2 Dynamic width : 2 / else : 1)
    logic                            skp_req_update_8b10b ;                          // SKP request of interval time 8b/10 (pulse)
    logic                            skp_req_update_dblock ;                         // SKP request of interval time Data Block(128b130b, Not datasream on FLIT) (pulse)
    logic                            skp_req_pulse ;                                 // each SKP reqest (pulse)
    logic  [4:0]                     skp_req_count ;                                 // Indicates how many SKP OS request have.

    logic  [4:0]                     eie_interval_count ;                             // EIEOS Interval count. EIEOS is sent every 32 TS0/1/2 or FTS.
    logic                            eie_interval_req ;                               // EIEOS request for EIEOS is sent every 32 TS0/1/2 or FTS.
    logic                            ltssm_in_rec_req_d ;                             // Indicates 1cycle delay LTSSM state is in any Revovery.EQ.
    logic                            eie_before_ts ;                                  // Indicates EIEOS request before sending TS1.
    logic                            eie_datastream_exit_en ;                         // Indicates EIEOS is need before 1st TS1 when exiting DataStream
    logic                            eie_cxl_nosb_ds ;                                // Indicates EIEOS request when CXL with Not Syncheader bypass in Data stream.
    logic                            eie_req_pulse ;                                  // each EIEOS reqest (pulse)
    logic                            eie_req_latch ;                                  // Latched eie_req_pulse
    logic                            eie_8sym_req_pulse ;                             // each eight EIE Symbol reqest (pulse)
    logic                            eie_8sym_req_latch ;                             // Latched eie_8sym_req_pulse
    logic                            eie_os_condition ;                               // Sending EIEOS condition is met.
    logic                            fts_req_pulse ;                                  // each FTS OS reqest (pulse)
    logic                            fts_req_latch ;                                  // Latched fts_req_pulse
    logic                            ei__os_condition ;                               // Sending EIOS condition is met.
    logic                            ei_non_cxl_nosb_ds ;                             // Indicates EIOS request other than ei_cxl_nosb_ds
    logic                            ei_cxl_nosb_ds ;                                 // Indicates EIOS request when CXL with Not Syncheader bypass in Data stream.
    logic                            ei_cxl_nosb_ds_latch ;                           // latched ei_cxl_nosb_ds
    
    logic                            sds_g45_req ;                                    // Gen4/5 SDS after SKP when Configuration/Recovery.Idle
    logic                            sds_req_pulse ;                                  // each SDS reqest (pulse)
    logic                            sds_req_latch ;                                  // Latched sds_req_pulse
    logic                            fill_gap_eios_ei ;                              // indicates EIOS sending is done, but ltssm_cmd still EIOS. need to Keep EI.

    logic                            crnt_grant_is_os ;                              // Indicates Current Grant is OS
    logic                            crnt_grant_is_data ;                            // Indicates Current Grant is Data
    logic                            crnt_grant_is_cmp ;                             // Indicates Current Grant is Compliance pattern
    logic                            crnt_grant_is_l0p_os ;                          // Indicates Current Grant is for L0p
    logic                            arb_time ;                                      // Indicates Grant can change.
    logic                            in_tdlp_wo_last_cycle_nonflit ;                 // Indicates TLP or DLLP is not sending in datastream.(Not include Last cycle for Arbitration timing)(Assert only when Non-Flit)
    logic                            in_tdlp_progress_nonflit ;                      // Indicates TLP or DLLP is not sending in datastream.(Assert only when Non-Flit)
    logic                            arb_time_datastream_nflit ;                     // Indicates non-flit datastream data switching tinimg. (Not TLP/DLLP)
    logic                            next_start_tdlp ;                               // Indicates next Cycle, TLP or DLLP sending start.
    logic                            next_end_tdlp ;                                 // Indicates next Cycle, TLP or DLLP sending end.
    logic                            crnt_end_tdlp ;                                 // Indicates current Cycle, TLP or DLLP sending end.
    logic                            in_tlp_dllp_sending ;                           // Indicates TLP or DLLP is sending.
    logic                            ts1_sending_extension ;                         // Should send TS1 even if ltssm_cmd is idle, this is timining adjustment with XPLH xdlh_xmlh_sof.
    logic                            ts2_sending_extension ;                         // Should send TS2 even if ltssm_cmd is idle, this is timining adjustment with XPLH xdlh_xmlh_sof.
    logic                            ts_masked_dstream  ;                            // Indicate ltssm_cmd is idle or Data, but masked by ts<1/2>_sending_extension 
    logic                            ts_masked_dstream_d ;                           // 1 cycle delay of ts_masked_dstream
    logic                            cmp_arb_timing ;                                // Arbitration timing for compliance pattern.
    logic  [9:0]                     flit_num_pcie ;                                 // PCIe Flit(256Byte) counter for OS insertion
    logic  [7:0]                     flit_cycle_pcie ;                               // The number of cycle in a FLIT (PCIe) (0's base)
    logic  [9:0]                     flit_interval_pcie ;                            // The number of FLIT for OS interaval depends on Lane#/Encoding. (PCIe) (0's base)
    logic                            last_flit_pcie ;                                // Indicates the last Flit(256Byte) before OS insertion
    logic                            last_flit_pcie_pre ;                            // Indicates one Flit before of the last Flit(256Byte) before OS insertion
    logic                            last_flit_pcie_2pre ;                           // Indicates two Flit before of the last Flit(256Byte) before OS insertion
    logic                            last_flit_cycle_pcie ;                          // Indicates the last cycle before OS insertion
    logic                            skp_req_flit_after_sds ;                        // SKP Reques after SDS when Flit
    logic                            skp_req_ent_dstream_8b10_flit ;                 // SKP Request when enter Datastream 8b10b flit to accellarete SKP interval to avoid SVA error.
    logic                            ltssm_in_detect ;                               // LTSSM is in any Detect state.
    logic                            flit_sds_skp_in_progress ;                      // Sending SDS -> SKP back-to-back is in progress in Flit mode.
    logic  [13:0]                    flit_num_cxl ;                                  // CXL Flit(256Byte) counter for OS insertion
    logic  [13:0]                    flit_interval_cxl_base ;                        // The number of FLIT for OS interaval depends on Lane#/Encoding. (PCIe)
    logic  [13:0]                    flit_interval_cxl ;                             // The number of FLIT for OS interaval depends on Lane#/Encoding. (PCIe)
    logic  [1:0]                     incr_flit_num_cxl ;                             // Increment valud for flit_num_cxl
    logic                            next_is_last2_flit_cxl ;                        // Indicates next FLIT is the last two FLIT before OS insertion.
    logic                            ieds_timing_cxl ;                               // Indicates Arbitration timing for iEDS replacement.
    logic  [5:0]                     flit_num_noshb_ei_eie_cxl ;                     // CXL Flit(256Byte) counter for OS insertion for EI/EIE no syncheader bypass
    logic  [5:0]                     flit_interval_noshb_ei_eie_cxl ;                // The number of FLIT for EI/EIE no syncheader bypass interaval depends on Lane#/Encoding. (PCIe)
    logic                            next_is_last2_flit_noshb_ei_eie_cxl ;           // Indicates next FLIT is the last two FLIT before OS insertion for EI/EIE no syncheader bypass.
    logic                            ieds_timing_noshb_ei_eie_cxl ;                  // Indicates Arbitration timing for iEDS replacement for EI/EIE no syncheader bypass.
    logic                            ei_eie_nosb_ds_in_progress ;                    // Indicates iEDS for EI/EIE no syncheader bypass is in progress 
    logic                            dt_data_valid_pre ;                             // Data Valid for Data throttling (1 cycler before)
    logic                            dt_data_valid ;                                 // Data Valid for Data throttling
    logic                            internal_txdata_dv_non_128b130b ;               // Data Valid for Non 128b130b encoding
    logic  [TIMER_BITS-1:0]          dblock_count_skp ;                              // Skip timer for 128b/130b data rate or 1b1b1 OS stream.
    logic  [TIMER_BITS-1:0]          dblock_interval ;                               // The number of Data Block for SKP interaval.
    logic                            skp_req_g45_before_sds ;                        // SKP Reques before SDS when Gen4/5 Non-Flit
    logic                            skp_req_g45_before_sds_latch ;                  // Latched skp_req_g45_before_sds
    logic                            skp_req_g3cxl_before_sds ;                      // SKP Reques before SDS when Gen3 CXL. This is for implementation. After SDS we cannot send SDS after 374block
    logic                            skp_req_g3cxl_before_sds_latch ;                // Latched skp_req_g3cxl_before_sds
    logic                            skp_before_sds_in_progress ;                    // Sending SKP before SDS when Gen4/5(from Spec) , Gen3 CXL(from implementation)
    logic                            os2dstream_transition ;                         // Indicate IDLE state transition from OS Stream (pulse)
    logic                            alternate_skp_phase ;                           // Indicate SKP should be send Standard and Control alternately.
    logic  [NL-1 :0]                 int_l0p_ltssm_lanes_active_pre ;                // Data Link width (L0p Up/Downsize OS lane width) : LTSSM latched lanes that are active based on the link negotiation
    logic  [5:0]                     int_l0p_smlh_link_mode_pre ;                    // Data Link width (L0p Up/Downsize OS lane width) : 10000 -- x16, 01000 -- x8, 00100 -- x4, 00010 -- x2, 00001 -- x1
    logic  [5:0]                     int_l0p_smlh_link_mode ;                        // Data Link width (L0p Up/Downsize OS lane width) : 10000 -- x16, 01000 -- x8, 00100 -- x4, 00010 -- x2, 00001 -- x1
    logic                            down_configure ;                                // Indicates Lane width is decreaseing.
    logic                            up_configure ;                                  // Indicates Lane width is increasing.
    l0p_state_t                      next_l0p_state ;                                // L0p Up/Downsizing state (next)
    logic                            l0p_arb_time ;                                  // Indicates Grant can change (for L0p).
    logic  [5:0]                     l0p_smlh_link_mode_latch ;                      // Latched smlh_l0p_link_mode
    logic  [NL-1 :0]                 l0p_ltssm_lanes_active_latch ;                  // Latched ltssm_l0p_lanes_active
    logic                            l0p_lane_upsizing_start ;                       // L0p Lane Upsizing start (pulse)
    logic                            l0p_lane_upsizing_end ;                         // L0p Lane Upsizing end (pulse)
    logic                            l0p_lane_dwsizing_start ;                       // L0p Lane Downsizing start (pulse)
    logic                            l0p_lane_dwsizing_end   ;                       // L0p Lane Downsizing end (pulse)
    logic                            l0p_lane_updw_end_by_recovery   ;               // L0p Lane Up/Downsizing end by entering recovery (pulse)
    logic                            l02recovery_chg ;                               // L0 to Recovery Change
    logic                            l0p_upsizing_sds_done ;                         // L0p upsizing SDS sending is done.

    logic                            skp_os_l0p_req ;                                // Sending SKP OS request for L0p up/dwsizing
    logic                            eie_os_l0p_req ;                                // Sending EIE OS request for L0p up/dwsizing
    logic                            sds_os_l0p_req ;                                // Sending SDS OS request for L0p up/dwsizing
    logic                            ei__os_l0p_req ;                                // Sending EI OS request  for L0p up/dwsizing
    logic                            ts1_os_l0p_req ;                                // Sending TS1 OS request for L0p up/dwsizing
    logic                            ts2_os_l0p_req ;                                // Sending TS2 OS request for L0p up/dwsizing
    logic                            l0p_ts1_sending_extension ;                     // Sending TS1 OS for L0p. This is timining adjustment with Recovery entry when upsizing
    logic                            l0p_ts2_sending_extension ;                     // Sending TS2 OS for L0p. This is timining adjustment with Recovery entry when upsizing
    logic                            eidle_l0p_req ;                                 // Keeping E-IDLE or No L0p working Request

    logic  [4:0]                     eie_interval_l0p_count ;                        // EIEOS Interval count. EIEOS is sent every 32 TS0/1/2 or FTS for L0p up/dwsizing
    logic                            eie_interval_l0p_req ;                          // EIEOS request for EIEOS is sent every 32 TS0/1/2 or FTS  for L0p up/dwsizing
    logic                            eie_req_l0p_pulse ;                             // each EIEOS reqest (pulse) for L0p up/dwsizing
    logic                            eie_req_l0p_latch ;                             // Latched eie_req_pulse for L0p up/dwsizing

    logic  [3:0]                     flit_block_count ;                              // Data Block Counter in a FLIT
    logic  [3:0]                     sds_insert_block_num ;                          // Counter value when L0p SDS insertion. depends on Lane# and Gen6(2SDS) or not(1SDS)
    logic                            sds_insert_timing ;                             // SDS insertin timing for L0p Upsizing (Before SKP OS insertion)


    logic                            dsp_sris_mode ;                                 // Downstream Port Indicates SRIS mode is enabled
  logic                              dsp_sris_mode_for_poll_comp_latch;              // Latched SRIS mode variable for Polling.Compliance state.
    logic                            int_txstartblock_wo_dv ;                        // PIPE Start Datablock for internal (pre output FF)(Without DataValid)
    logic                            int_txstartblock ;                              // PIPE Start Datablock for internal (pre output FF)
    logic                            int_txendblock_wo_g6skp_wo_dv ;                 // End Datablock for internal (not include Gen6 SKP (40Byte)(Without DataValid)
    logic                            int_txendblock_wo_g6skp ;                       // End Datablock for internal (not include Gen6 SKP (40Byte)
    logic                            g6skp_end ;                                     // Gen6 SKP (40Byte) End
    logic [4:0]                      block_cnt_128b130b ;                            // Data Block Counter
    logic [6:0]                      datavalid_cnt_128b130b ;                        // Data Valid Counter
    logic [6:0]                      g6skp_byte_cnt ;                                // Indicates Gen6 SKP OS byte which is sent.

    logic  [NL-1:0]                  int_txelecidle ;                                // Base PIPE Txelecidle. This signal will be aligned with output data(xmtbyte_txdata,xmtbyte_txdatak)
    logic  [NL-1:0]                  int_txelecile_g3_txdatavalid_sync ;             // for Timing adjustment. Gen3/4/5 upconfigura should start with 1st datavalid asserting.
    logic                            in_dead_cycle_128b130b ;                        // Asserted when 128b130b dead cycle.
    logic                            int_txdetectrx_loopback ;                       // Base PIPE TxDetecteLoopback. This signal will be aligned align with Txelecidle
    logic  [NL-1:0]                  data_aligned_txelecidle ;                       // PIPE Txelecidle. Aligned with output data in this module.
    logic  [NL-1:0]                  data_aligned_txcompliance ;                     // PIPE TxCompliance. Aligned with output data in this module.
    logic                            data_aligned_loopback ;                         // PIPE TxDetecteLoopback. Aligned with output data in this module.
    logic  [NL-1:0]                  g12_txelecidle ;                                // PIPE Txelecidle. Aligned with Gen12.
    logic  [NL-1:0]                  g12_txcompliance ;                              // PIPE TxCompliance. Aligned with Gen12.
    logic                            g12_loopback ;                                  // PIPE TxDetecteLoopback. Aligned with Gen12.
    logic  [NL-1:0]                  g3orh_txelecidle ;                              // PIPE Txelecidle. Aligned with Gen3 or higher.
    logic  [NL-1:0]                  g3orh_txcompliance ;                            // PIPE TxCompliance. Aligned with Gen3 or higher
    logic                            g3orh_loopback ;                                // PIPE TxDetecteLoopback. Aligned with Gen3 or higher
    logic  [NL-1:0]                  g3orh_txelecidle_pre ;                          // 1cycle before of g3orh_txelecidle
    logic                            lpbk_active_follower_eidle ;                    // smlh_ltssm_state is `XMT_IN_EIDLE when Loopback.Active follower. This is from original logic.
    logic                            lpbk_active_follower_eidle_set ;                // smlh_ltssm_state is `XMT_IN_EIDLE when Loopback.Active follower. This is from original logic.
    logic                            lpbk_active_follower_eidle_lat ;                // smlh_ltssm_state is `XMT_IN_EIDLE when Loopback.Active follower. This is from original logic.
    logic                            lpbk_follwer_act_exit ;                         // LTSSM is in Loopback.Active or Loopback.Exit Flower
    logic                            lpbk_follwer_act_exit_1d ;                      // 1 cycle delay of lpbk_follwer_act_exit. For timing adjustment of TxDetectLoopback and TxElecidle.
    logic                            lpbk_follwer_act_exit_2d ;                      // 2 cycle delay of lpbk_follwer_act_exit. For timing adjustment of TxDetectLoopback and TxElecidle.
    logic                            xmtbyte_txdetectrx ;                            // Indicates detectrx mode of PIPE txdtectrx_loopback.
    logic                            xmtbyte_loopback ;                              // Indicates loopback(slave) mode of PIPE txdtectrx_loopback.
    logic                            align_txos_timing ;                             // FREQ_STEP Algin timing for OS
    logic                            mask_cmp_timing ;                               // FREQ_STEP Algin timing for Compliance pattern

    logic                            stp_in_progress_d ;           
    logic                            xdlh_xmlh_eof_d ;                               //  1 cycle delay of End of Flit 



// --- Set fix value to input signals which are not exist by configuration.
    logic                       xpipe_mac_skip_req ;


// --- Set fix value to input signals which are not exist by configuration.
   assign  xpipe_mac_skip_req                   = 1'b0 ;


// ---------------------------------------
// Making Mode signals
// ---------------------------------------

// ---- Stream State ----
    always_comb begin
        case( crnt_stream ) 
            OS_STREAM    : begin
                                 if( next_grant[G_DATA_BIT] || (crnt_grant[G_SDS_BIT] && ossq_send_done))                                  next_stream = DATA_STREAM ;
                            else if( next_grant[G_EIDLE_BIT]                          )                                                    next_stream = EIDLE_STREAM ;
                            else if( next_grant[G_CMP_BIT]  || next_grant[G_MCMP_BIT] )                                                    next_stream = CMP_STREAM ;
                            else                                                                                                           next_stream = crnt_stream ;
                           end
            DATA_STREAM  : begin
                                 if( next_grant[G_EIE_BIT]  || next_grant[G_TS1_BIT]  )                                                    next_stream = OS_STREAM ;
                            else if( next_grant[G_EIDLE_BIT]                          )                                                    next_stream = EIDLE_STREAM ;
                            //else if( next_grant[G_CMP_BIT]  || next_grant[G_MCMP_BIT] )                                                    next_stream = CMP_STREAM ;  // never entry
                            else                                                                                                           next_stream = crnt_stream ;
                           end
            EIDLE_STREAM : begin
                                 if( next_grant[G_EIE_BIT]  || next_grant[G_TS1_BIT] || next_grant[G_EIE_8SYM_BIT] || next_grant[G_SKP_BIT] 
                                  || next_grant[G_FTS_BIT]  || next_grant[G_TS0_BIT] || next_grant[G_EI_BIT]      )                        next_stream = OS_STREAM ;
                            else if( next_grant[G_CMP_BIT]  || next_grant[G_MCMP_BIT] )                                                    next_stream = CMP_STREAM ;
                            else                                                                                                           next_stream = crnt_stream ;
                           end
            CMP_STREAM   : begin
                                 if( next_grant[G_EIE_BIT]  || next_grant[G_TS1_BIT]   )                                                   next_stream = OS_STREAM ;
                            else if( next_grant[G_EIDLE_BIT]                           )                                                   next_stream = EIDLE_STREAM ;
                            else                                                                                                           next_stream = crnt_stream ;
                           end
            default      :                                                                                                                 next_stream = EIDLE_STREAM ;    // never entry
        endcase
    end

    always @(posedge core_clk or negedge core_rst_n) begin : crnt_stream_PROC
        if (!core_rst_n) begin
            crnt_stream <= #TP EIDLE_STREAM ;
        end 
        else begin
            crnt_stream <= #TP next_stream ;
        end
    end
    
// ---- SRIS Mode for Doewstream Port ----
    // sticky_rst_n to not reset the sris_mode_enabled from link down reset. doing so is to keep sris_mode_enabled for Compliance and Loopback from new Core Reset
    always @(posedge core_clk or negedge sticky_rst_n) begin : dsp_sris_mode_for_poll_comp_latch_PROC
        if (!sticky_rst_n) begin
            dsp_sris_mode_for_poll_comp_latch <= #TP '0;
        end 
        else if( (smlh_ltssm_state == S_CFG_LANENUM_ACEPT) && (~smlh_link_up) ) begin
            dsp_sris_mode_for_poll_comp_latch <= #TP dsp_tx_sris_cloking;
        end
    end // dsp_sris_mode_for_poll_comp_latch_PROC

    always @(posedge core_clk or negedge core_rst_n) begin : dsp_sris_mode_PROC
        if (!core_rst_n) begin
            dsp_sris_mode <= #TP '0;
        end 
        else if(smlh_ltssm_state == S_DETECT_QUIET) begin
            dsp_sris_mode <= #TP '0;
        end
        else if(smlh_ltssm_state == S_POLL_COMPLIANCE) begin
            dsp_sris_mode <= #TP dsp_sris_mode_for_poll_comp_latch;
        end
        else if( ((smlh_ltssm_state == S_LPBK_ENTRY)  || (smlh_ltssm_state == S_CFG_LANENUM_ACEPT)) && (~smlh_link_up) ) begin
            dsp_sris_mode <= #TP dsp_tx_sris_cloking;
        end
    end // dsp_sris_mode_PROC


    always_comb begin
        xmtbyte_sris_mode_enabled       = dsp_sris_mode | smlh_usp_sris_mode ;
        sris_mode_on                    = xmtbyte_sris_mode_enabled | app_sris_mode_i ;
        xmtbyte_l0p_sris_mode_enabled   = sris_mode_on ;

    end


// ---- Link Width ----

    // internal use Link width for Data and OS(L0p)
    always_comb begin
        int_data_smlh_link_mode_pre        = int_data_smlh_link_mode ;
        int_data_ltssm_lanes_active_pre    = int_data_ltssm_lanes_active ;
        int_l0p_smlh_link_mode_pre         = int_l0p_smlh_link_mode ;
        int_l0p_ltssm_lanes_active_pre     = int_l0p_ltssm_lanes_active ;

        if( crnt_stream[EIDLE_STREAM_BIT] || in_idle_data_progress || int_ltssm_in_lpbk 
               || ( crnt_stream[OS_STREAM_BIT] && ossq_send_done && (down_configure || crnt_rate.one_hot[GEN1_BIT]) ) || ( next_grant[G_EIE_BIT] && ~crnt_grant[G_EIE_BIT] && up_configure )
               || l0p_lane_upsizing_start || l0p_lane_upsizing_end || l0p_lane_dwsizing_start || l0p_lane_dwsizing_end || l02recovery_chg 
                ) begin

            int_data_smlh_link_mode_pre        = l02recovery_chg ? smlh_link_mode
                                               : (l0p_lane_dwsizing_start | l0p_lane_upsizing_end ) ? l0p_smlh_link_mode_latch 
                                                                                                    : ( l0p_lane_upsizing_start || l0p_lane_dwsizing_end ) ? int_data_smlh_link_mode 
                                                                                                                                                            : smlh_link_mode ;
            int_data_ltssm_lanes_active_pre    = l02recovery_chg ? ltssm_lanes_active
                                               : (l0p_lane_dwsizing_start | l0p_lane_upsizing_end ) ? l0p_ltssm_lanes_active_latch 
                                                                                                    : ( l0p_lane_upsizing_start || l0p_lane_dwsizing_end ) ? int_data_ltssm_lanes_active 
                                                                                                                                                            : ltssm_lanes_active ;
            int_l0p_smlh_link_mode_pre         = l02recovery_chg ? smlh_link_mode
                                               : (l0p_lane_upsizing_start | l0p_lane_dwsizing_end ) ? l0p_smlh_link_mode_latch 
                                                                                                    : ( l0p_lane_dwsizing_start || l0p_lane_upsizing_end ) ? int_l0p_smlh_link_mode 
                                                                                                                                                            : smlh_link_mode ;
            int_l0p_ltssm_lanes_active_pre     = l02recovery_chg ? ltssm_lanes_active
                                               : (l0p_lane_upsizing_start | l0p_lane_dwsizing_end ) ? l0p_ltssm_lanes_active_latch 
                                                                                                    : ( l0p_lane_dwsizing_start || l0p_lane_upsizing_end ) ? int_l0p_ltssm_lanes_active 
                                                                                                                                                            : ltssm_lanes_active ;

        end 
    end
    
    always_comb begin
        down_configure = (smlh_link_mode < int_data_smlh_link_mode) || (ltssm_lanes_active < int_data_ltssm_lanes_active) ;
        up_configure   = (smlh_link_mode > int_data_smlh_link_mode) || (ltssm_lanes_active > int_data_ltssm_lanes_active) ;
    end

    always @(posedge core_clk or negedge core_rst_n) begin : int_data_smlh_link_mode_PROC
        if (!core_rst_n) begin
            int_data_smlh_link_mode        <= #TP '0;
            int_data_ltssm_lanes_active    <= #TP '1;
            int_l0p_smlh_link_mode         <= #TP '0;
            int_l0p_ltssm_lanes_active     <= #TP '1;
        end 
        else begin
            int_data_smlh_link_mode        <= #TP int_data_smlh_link_mode_pre ;
            int_data_ltssm_lanes_active    <= #TP int_data_ltssm_lanes_active_pre ;
            int_l0p_smlh_link_mode         <= #TP int_l0p_smlh_link_mode_pre ;
            int_l0p_ltssm_lanes_active     <= #TP int_l0p_ltssm_lanes_active_pre ;
        end 
    end // int_data_smlh_link_mode_PROC


    // Latch L0p new link width
    always @(posedge core_clk or negedge core_rst_n) begin : l0p_smlh_link_mode_latch_PROC
        if (!core_rst_n) begin
            l0p_smlh_link_mode_latch        <= #TP '0;
            l0p_ltssm_lanes_active_latch    <= #TP '0;
        end 
        else if( smlh_l0p_update ) begin
            l0p_smlh_link_mode_latch        <= #TP smlh_l0p_link_mode ;
            l0p_ltssm_lanes_active_latch    <= #TP ltssm_l0p_lanes_active ;
        end
    end

    // Recovery entry return Link width to initial link up width
    always_comb begin
        l02recovery_chg = crnt_stream[DATA_STREAM_BIT] & (next_grant[G_EIE_BIT] | next_grant[G_TS1_BIT] ) ;
    end


// ---- Phase Flag ----
    // FTS is in progress
    always @(posedge core_clk or negedge core_rst_n) begin : fts_phase_128b130b_PROC
        if (!core_rst_n) begin
            fts_phase_128b130b        <= #TP '0;
        end 
        else if( (ltssm_cmd_i == `SEND_N_FTS) && (ltssm_cmd_i_d != `SEND_N_FTS) && crnt_rate.enc_128b130b) begin
            fts_phase_128b130b        <= #TP 1'b1; 
        end
        else if( crnt_grant[G_SDS_BIT] && ossq_send_done ) begin
            fts_phase_128b130b        <= #TP 1'b0; 
        end 
    end
    
    // all OS should not be sent.(After SDS or SKP in datastream)
    always_comb begin
        os_mask_phase        = (crnt_grant[G_SDS_BIT] & ~ltssm_flit_mode_enable)
                             | (crnt_grant[G_SKP_BIT] & crnt_stream[DATA_STREAM_BIT] & (ltssm_flit_mode_enable | cxl_mode_enable) & ~crnt_rate.enc_8b10b ) ;
    end

    // IDLE Data is sending
    always_comb begin
        in_idle_data_progress  = crnt_grant[G_DATA_BIT] & (ltssm_cmd_i == `SEND_IDLE) ;
    end

// --- EI/EIE Sending Enable
// To Exit DataSteam (To Recovery or Low Power), need to wait TLP/DLLP fulshing is done.
// This flag meas exiting DataStream is Ready

    // Wait Fixed cycle this is from ltssm_cmd_is_norm of original design
    always @(posedge core_clk or negedge core_rst_n) begin : waiting_tdlp_idle_PROC
        if (!core_rst_n) begin
            waiting_tdlp_idle        <= #TP '0;
        end 
        else begin
            waiting_tdlp_idle        <= #TP  {waiting_tdlp_idle[CMD_NORM_WD-1:0], (ltssm_cmd_i == `NORM)} ;       // shift register
        end 
    end

    // --- For robustness logic.
    //      Sometimes, xdlh_xmlh_pkt_pending_i is deasserted a few cycle and asserted again when LTSSM is non L0.
    //      This bahavior cause incorrect EI/EIE sending. To avoind this, check three cycle deasserting of xdlh_xmlh_pkt_pending_i to send EI/EIE.
    always @(posedge core_clk or negedge core_rst_n) begin : xdlh_xmlh_pkt_pending_i_d_PROC
        if (!core_rst_n) begin
            xdlh_xmlh_pkt_pending_i_1d        <= #TP '0;
            xdlh_xmlh_pkt_pending_i_2d        <= #TP '0;
        end 
        else begin
            xdlh_xmlh_pkt_pending_i_1d        <= #TP xdlh_xmlh_pkt_pending_i;
            xdlh_xmlh_pkt_pending_i_2d        <= #TP xdlh_xmlh_pkt_pending_i_1d;
        end 
    end

    always_comb begin
        xdlh_xmlh_pkt_pending = xdlh_xmlh_pkt_pending_i | xdlh_xmlh_pkt_pending_i_1d | xdlh_xmlh_pkt_pending_i_2d ;
    end

    // LTSSM is in any Detect state. This is to care L0 to Detect transition by app_ltssm_enable.
    // In this case no flush/low power handsahke is excuted to upper layer. As a result neither xfsh_xmlh_buf_empty and xmlh_xfsh_last_flit are not asserted.
    // Not need to care fulsh since reset uppser layer when detect.
    always_comb begin
        ltssm_in_detect = (smlh_ltssm_state == S_DETECT_QUIET)     | (smlh_ltssm_state == S_DETECT_ACT) 
                        | (smlh_ltssm_state == S_PRE_DETECT_QUIET) | (smlh_ltssm_state == S_DETECT_WAIT) ; 
    end
    
    // --- EI/EIE Sending Enable
    always @(posedge core_clk or negedge core_rst_n) begin : ei_eie_sending_en_PROC
        if (!core_rst_n) begin
            ei_eie_sending_en        <= #TP '0;
        end 
        else if( ~next_stream[DATA_STREAM_BIT] ) begin        // can send when Non-DataStream
            ei_eie_sending_en        <= #TP 1'b1 ;
        end 
        else if( next_grant[G_EDS_BIT] ) begin                // For xdlh_xmlh_pkt_pending_i behavior of a few cycle deasserting. Keep enable to achieve sending EI/EIE OS.
            ei_eie_sending_en        <= #TP ei_eie_sending_en ;
        end 
        else if(  next_stream[DATA_STREAM_BIT]
               && (    (|waiting_tdlp_idle)                                                                               // Wait Fixed cycle this is from ltssm_cmd_is_norm of original design
                    || (~ltssm_flit_mode_enable && xdlh_xmlh_pkt_pending)                                                 // TLP or DLLP is in progress in Non Flit
                    || ( ltssm_flit_mode_enable && xmlh_fm_pending && ~ltssm_in_detect)                                   // TLP or DLLP is in progress in Flit
                    || ( ltssm_flit_mode_enable && ~xmlh_fm_flush_ack && ~xmlh_cmd_if_lp_ack && ~ltssm_in_detect)         // TLP or DLLP flush is not done.
                    ||  next_l0p_grant[G_SDS_BIT]                                                                         // When L0p upsizing and SDS is started. cannot send EI/EIE
              ) ) begin
                    ei_eie_sending_en        <= #TP '0;
        end
        else begin
                    ei_eie_sending_en        <= #TP 1'b1;
        end
    end

// --- TS2 sending extension
// This is timing adjustmnet from original design.
// When Flit mode, Start of Flit(xdlh_xmlh_sof) may not assert even if ltssm_cmd is idle(Flit sending).
// So, until xdlh_xmlh_sof is ready, this module continue to send TS2 even if ltssm_cmd is idle.

    always @(posedge core_clk or negedge core_rst_n) begin : ts2_sending_extension_PROC
        if (!core_rst_n) begin
            ts2_sending_extension        <= #TP '0;
            ts1_sending_extension        <= #TP '0;
            ts_masked_dstream_d          <= #TP '0;
        end 
        else begin
           // TS2 extention
            if( xdlh_xmlh_sof || ~ltssm_flit_mode_enable 
              || ( (ltssm_cmd_i != `SEND_TS2) && (ltssm_cmd_i != `SEND_IDLE) && (ltssm_cmd_i != `NORM) ) ) begin 
                ts2_sending_extension        <= #TP 1'b0 ;
            end 
            else if( crnt_grant[G_TS2_BIT] ) begin
                ts2_sending_extension        <= #TP 1'b1 ;
            end
            
           // TS1 extention
            if( xdlh_xmlh_sof || ~ltssm_flit_mode_enable 
              || ( (ltssm_cmd_i != `SEND_TS1) && (ltssm_cmd_i != `SEND_IDLE) && (ltssm_cmd_i != `NORM) ) ) begin 
                ts1_sending_extension        <= #TP 1'b0 ;
            end 
            else if( crnt_grant[G_TS1_BIT] && (smlh_ltssm_state == S_LPBK_ENTRY) ) begin
                ts1_sending_extension        <= #TP 1'b1 ;
            end

           // 1cycle delay
                ts_masked_dstream_d          <= #TP ts_masked_dstream;
        end
    end

    always_comb begin
        ts_masked_dstream  = ( (ltssm_cmd_i == `NORM) | (ltssm_cmd_i == `SEND_IDLE) ) & ~ts1_sending_extension & ~ts2_sending_extension ;
    end

// ---------------------------------------
// Phase counting
// ---------------------------------------

    // Data throttling Data Valid
    always_comb begin
        dt_data_valid_pre = 1'b1 ;
        dt_data_valid     = 1'b1 ;
    end

 
// 128b/130b Data Valid count
    always @(posedge core_clk or negedge core_rst_n) begin : datavalid_cnt_128b130b_PROC
        if (!core_rst_n) begin
            datavalid_cnt_128b130b <= #TP '0 ;
        end 
        else if(   &int_txelecidle || crnt_rate.enc_8b10b 
                || ( (datavalid_cnt_128b130b == 7'd64) && dt_data_valid )
                || ( (datavalid_cnt_128b130b == 7'd63) && (ltssm_cxl_sh_bypass || crnt_rate.enc_1b1b) && dt_data_valid )   // only use for xmtbyte_txelecidle_info
                                                                                                                       ) begin
            datavalid_cnt_128b130b <= #TP (g6skp_byte_cnt < 7'd16 ) ? '0 : datavalid_cnt_128b130b ;
        end
        else if( dt_data_valid ) begin
            datavalid_cnt_128b130b <= #TP (g6skp_byte_cnt < 7'd16 ) ? $bits(datavalid_cnt_128b130b)'( datavalid_cnt_128b130b + 1'b1 ) : datavalid_cnt_128b130b ;
        end
   end

    always @(posedge core_clk or negedge core_rst_n) begin : internal_txdata_dv_PROC
        if (!core_rst_n) begin
            internal_txdata_dv     <= #TP '0 ;
            internal_txdata_dv_pre <= #TP '0 ;
        end 
        else if( next_grant[G_EIDLE_BIT] ) begin
            internal_txdata_dv     <= #TP '0 ;
            internal_txdata_dv_pre <= #TP 1'b1 ;
        end
        else begin
            internal_txdata_dv     <= #TP (crnt_rate.enc_128b130b & ~ltssm_cxl_sh_bypass & (datavalid_cnt_128b130b + 1'b1) == 7'd64) ? 1'b0 : 1'b1 ;
            internal_txdata_dv_pre <= #TP (crnt_rate.enc_128b130b & ~ltssm_cxl_sh_bypass & (datavalid_cnt_128b130b + 1'b1) == 7'd63) ? 1'b0 : 1'b1 ;
        end
   end     


    //  Indicates Gen6 SKP OS byte which is sent.
    always @(posedge core_clk or negedge core_rst_n) begin : g6skp_byte_cnt_PROC
        if (!core_rst_n) begin
            g6skp_byte_cnt     <= #TP '0 ;
        end 
        else if( ~crnt_rate.enc_1b1b || ~next_grant[G_SKP_BIT] ) begin
            g6skp_byte_cnt     <= #TP '0 ;
        end
        else if( crnt_grant[G_SKP_BIT] ) begin
            g6skp_byte_cnt     <= #TP $bits(g6skp_byte_cnt)'( g6skp_byte_cnt + active_nb ) ;
        end
   end        
  
// Block phase
    always @(posedge core_clk or negedge core_rst_n) begin : block_cnt_128b130b_PROC
        if (!core_rst_n) begin
            block_cnt_128b130b <= #TP '0 ;
        end 
        else if( &int_txelecidle || ~crnt_rate.eq_or_higher[GEN3_BIT] || int_txendblock_wo_g6skp || g6skp_end || mcmp_gen6_skp_done ) begin
            block_cnt_128b130b <= #TP '0 ;
        end
        else if( internal_txdata_dv ) begin
            block_cnt_128b130b <= #TP $bits(block_cnt_128b130b)'( block_cnt_128b130b + active_nb ) ;
        end
   end

    // TxStartblcok / Endblock(for internal use) (Before output FF)
    always @(posedge core_clk or negedge core_rst_n) begin : int_txstartblock_wo_dv_PROC
        if (!core_rst_n) begin
            int_txstartblock_wo_dv              <= #TP '0 ;
            int_txendblock_wo_g6skp_wo_dv       <= #TP '0 ;
        end
        else if( next_grant[G_EIDLE_BIT] || ~crnt_rate.eq_or_higher[GEN3_BIT] ) begin
            int_txstartblock_wo_dv              <= #TP '0 ;
            int_txendblock_wo_g6skp_wo_dv       <= #TP '0 ;
        end
        else if( crnt_rate.one_hot[GEN6_BIT] && crnt_grant[G_SKP_BIT] ) begin
            int_txstartblock_wo_dv              <= #TP os_send_done ? 1'b1 : 1'b0  ;
            int_txendblock_wo_g6skp_wo_dv       <= #TP ((6)'(active_nb) >= 6'd16) ;
        end
        else if( mcmp_gen6_skp_in_progress ) begin
            int_txstartblock_wo_dv              <= #TP mcmp_gen6_skp_done ? 1'b1 : 1'b0  ;
            int_txendblock_wo_g6skp_wo_dv       <= #TP '0 ;
        end
        else begin
            int_txstartblock_wo_dv              <= #TP (~internal_txdata_dv || (internal_txdata_dv_pre && int_txendblock_wo_g6skp)) ? 1'b1 : 1'b0 ;
            int_txendblock_wo_g6skp_wo_dv       <= #TP
                                                    ((block_cnt_128b130b + active_nb) == (16 - active_nb) )  ? ( internal_txdata_dv     ? 1'b1 : 1'b0 ) : 1'b0 ;
        end
    end
    
    always_comb begin
        int_txstartblock        = int_txstartblock_wo_dv ;
        int_txendblock_wo_g6skp = int_txendblock_wo_g6skp_wo_dv ;
        g6skp_end               = crnt_rate.one_hot[GEN6_BIT] && crnt_grant[G_SKP_BIT] & os_send_done ;
    end


 
    // output signals
    always_comb begin
        internal_txstartblock             = int_txstartblock ;
        internal_txendblock               = int_txendblock_wo_g6skp ;
        internal_txtblock_symbol_cnt      = block_cnt_128b130b ;
        in_dead_cycle_128b130b            = (datavalid_cnt_128b130b == 7'd64) ;
        internal_txdata_dv_non_128b130b   = 1'b1 ;
        
    end

// PCIe Flit count
    // select FLIT Interval
    always_comb begin
        case( { sris_mode_on , crnt_rate.enc_1b1b , crnt_rate.enc_128b130b , int_data_smlh_link_mode } )
                             { 1'b0 , 1'b1 , 1'b0 , 6'd1  } : flit_interval_pcie = FLIT_INTVL_X1__1b1b_CCLK - 1'b1  ;               // Common CLK , 1b1b     , x1   (  46 )
  { 1'b0 , 1'b1 , 1'b0 , 6'd2  } : flit_interval_pcie = FLIT_INTVL_X2__1b1b_CCLK - 1'b1  ;    // Common CLK , 1b1b     , x2   (  93 )  
  { 1'b0 , 1'b1 , 1'b0 , 6'd4  } : flit_interval_pcie = FLIT_INTVL_X4__1b1b_CCLK - 1'b1  ;    // Common CLK , 1b1b     , x4   ( 187 )
  { 1'b0 , 1'b1 , 1'b0 , 6'd8  } : flit_interval_pcie = FLIT_INTVL_X8__1b1b_CCLK - 1'b1  ;    // Common CLK , 1b1b     , x8   ( 374 )
    // Common CLK , 1b1b     , x16  ( 748 )
                             { 1'b0 , 1'b0 , 1'b1 , 6'd1  } : flit_interval_pcie = FLIT_INTVL_X1__128b130b_CCLK  - 1'b1 ;           // Common CLK , 128b130b , x1   (  23 )
  { 1'b0 , 1'b0 , 1'b1 , 6'd2  } : flit_interval_pcie = FLIT_INTVL_X2__128b130b_CCLK  - 1'b1 ;    // Common CLK , 128b130b , x2   (  46 )
  { 1'b0 , 1'b0 , 1'b1 , 6'd4  } : flit_interval_pcie = FLIT_INTVL_X4__128b130b_CCLK  - 1'b1 ;    // Common CLK , 128b130b , x4   (  93 )
  { 1'b0 , 1'b0 , 1'b1 , 6'd8  } : flit_interval_pcie = FLIT_INTVL_X8__128b130b_CCLK  - 1'b1 ;    // Common CLK , 128b130b , x8   ( 187 )
    // Common CLK , 128b130b , x16  ( 374 )
                             { 1'b1 , 1'b1 , 1'b0 , 6'd1  } : flit_interval_pcie = FLIT_INTVL_X1__1b1b_SRIS  - 1'b1 ;               // SRIS       , 1b1b     , x1   (   4 )
  { 1'b1 , 1'b1 , 1'b0 , 6'd2  } : flit_interval_pcie = FLIT_INTVL_X2__1b1b_SRIS  - 1'b1 ;    // SRIS       , 1b1b     , x2   (   9 )
  { 1'b1 , 1'b1 , 1'b0 , 6'd4  } : flit_interval_pcie = FLIT_INTVL_X4__1b1b_SRIS  - 1'b1 ;    // SRIS       , 1b1b     , x4   (  18 )
  { 1'b1 , 1'b1 , 1'b0 , 6'd8  } : flit_interval_pcie = FLIT_INTVL_X8__1b1b_SRIS  - 1'b1 ;    // SRIS       , 1b1b     , x8   (  37 )
    // SRIS       , 1b1b     , x16  (  74 )
                             { 1'b1 , 1'b0 , 1'b1 , 6'd1  } : flit_interval_pcie = FLIT_INTVL_X1__128b130b_SRIS  - 1'b1 ;           // SRIS       , 128b130b , x1   (   2 )
  { 1'b1 , 1'b0 , 1'b1 , 6'd2  } : flit_interval_pcie = FLIT_INTVL_X2__128b130b_SRIS  - 1'b1 ;    // SRIS       , 128b130b , x2   (   4 )
  { 1'b1 , 1'b0 , 1'b1 , 6'd4  } : flit_interval_pcie = FLIT_INTVL_X4__128b130b_SRIS  - 1'b1 ;    // SRIS       , 128b130b , x4   (   9 )
  { 1'b1 , 1'b0 , 1'b1 , 6'd8  } : flit_interval_pcie = FLIT_INTVL_X8__128b130b_SRIS  - 1'b1 ;    // SRIS       , 128b130b , x8   (  18 )
    // SRIS       , 128b130b , x16  (  37 )
                             default                        : flit_interval_pcie = 10'h000 ;                                        // Gen1/Gen2 can always insert OS.
        endcase
    end

    // FLIT Counter (PCIe)
    always @(posedge core_clk or negedge core_rst_n) begin : flit_num_pcie_PROC
        if (!core_rst_n) begin
            flit_num_pcie               <= #TP '0 ;
            last_flit_pcie              <= #TP '0 ;
            last_flit_pcie_pre          <= #TP '0 ;
            last_flit_pcie_2pre         <= #TP '0 ;
        end
        else if( ~ltssm_flit_mode_enable || ~crnt_stream[DATA_STREAM_BIT] ) begin
            flit_num_pcie               <= #TP '0 ;
            last_flit_pcie              <= #TP '0 ;
            last_flit_pcie_pre          <= #TP '0 ;
            last_flit_pcie_2pre         <= #TP '0 ;
        end
        else if( flit_interval_pcie == '0 ) begin       // when Gen1/2 can always insert OS in FLIT boundary
            flit_num_pcie               <= #TP '0 ;
            last_flit_pcie              <= #TP 1'b1 ;
            last_flit_pcie_pre          <= #TP '0 ;
            last_flit_pcie_2pre         <= #TP '0 ;
        end
        else if( ossq_send_done ) begin
            flit_num_pcie               <= #TP '0 ;
            last_flit_pcie              <= #TP '0 ;
            last_flit_pcie_pre          <= #TP '0 ;
            last_flit_pcie_2pre         <= #TP '0 ;
        end
        else if( xdlh_xmlh_eof && last_chunk ) begin
            flit_num_pcie               <= #TP $bits(flit_num_pcie)'( flit_num_pcie + 1'b1 ) ;
            last_flit_pcie              <= #TP ( (flit_num_pcie + 1'b1) ==  flit_interval_pcie  ) ;
            last_flit_pcie_pre          <= #TP ( (flit_num_pcie + 1'b1) == (flit_interval_pcie - 1'b1) ) ;
            last_flit_pcie_2pre         <= #TP ( (flit_num_pcie + 1'b1) == (flit_interval_pcie - 2'd2) ) ;
        end
    end

    // FLIT cycle (PCIe)
    always @(posedge core_clk or negedge core_rst_n) begin : flit_cycle_pcie_PROC
        if (!core_rst_n) begin
            flit_cycle_pcie             <= #TP '0 ;
        end
        else if( ~ltssm_flit_mode_enable || ~crnt_stream[DATA_STREAM_BIT] || crnt_grant[G_SKP_BIT] ) begin
            flit_cycle_pcie             <= #TP '0 ;
        end
        else if( (xdlh_xmlh_eof && last_chunk) || xdlh_xmlh_sof ) begin
            flit_cycle_pcie             <= #TP '0 ;
        end
        else if( internal_txdata_dv ) begin
            flit_cycle_pcie             <= #TP $bits(flit_cycle_pcie)'( flit_cycle_pcie + 1'b1 ) ;
        end
    end

    // Arbitration timing for FLIT PCIe
    always_comb begin
        last_flit_cycle_pcie  = last_flit_pcie & xdlh_xmlh_eof & last_chunk ;
    end

// CXL Flit count
    // select FLIT Interval
    always_comb begin
        case( { sris_mode_on , ltssm_cxl_sh_bypass } )
            { 1'b0 , 1'b0 } : flit_interval_cxl_base = FLIT_INTVL_CXL_SYNC_CCLK  ;      // CXL / Common Clock / Not syncheader bypass
            { 1'b0 , 1'b1 } : flit_interval_cxl_base = FLIT_INTVL_CXL_SYNB_CCLK  ;      // CXL / Common Clock /     syncheader bypass
            default         : flit_interval_cxl_base = FLIT_INTVL_CXL_SYNC_SRIS  ;      // CXL / SRIS         / Not syncheader bypass  (Syncheader bypass is not supported in SRIS)
        endcase

        // For SKP or SKP/EI/EIE when syncheader bypass 
        case( int_data_smlh_link_mode )
                                 6'd2    : flit_interval_cxl    = $bits(flit_interval_cxl)'( (flit_interval_cxl_base << 1) - 1'b1 ) ;            // x2
   6'd4    : flit_interval_cxl    = $bits(flit_interval_cxl)'( (flit_interval_cxl_base << 2) - 1'b1 ) ;   // x4
   6'd8    : flit_interval_cxl    = $bits(flit_interval_cxl)'( (flit_interval_cxl_base << 3) - 1'b1 ) ;   // x8
   // x16
                                 default : flit_interval_cxl    = $bits(flit_interval_cxl)'( (flit_interval_cxl_base     ) - 1'b1 ) ;            // x1
        endcase

        // For EI/EIE when not syncheader bypass
        case( int_data_smlh_link_mode )
                                 6'd2    : flit_interval_noshb_ei_eie_cxl    = $bits(flit_interval_noshb_ei_eie_cxl)'( (4 << 1) - 1'b1 ) ;            // x2
   6'd4    : flit_interval_noshb_ei_eie_cxl    = $bits(flit_interval_noshb_ei_eie_cxl)'( (4 << 2) - 1'b1 ) ;    // x4
   6'd8    : flit_interval_noshb_ei_eie_cxl    = $bits(flit_interval_noshb_ei_eie_cxl)'( (4 << 3) - 1'b1 ) ;    // x8
    // x16
                                 default : flit_interval_noshb_ei_eie_cxl    = $bits(flit_interval_noshb_ei_eie_cxl)'( (4     ) - 1'b1 ) ;            // x1
        endcase
        
    end

    // FLIT Counter (CXL)
    always @(posedge core_clk or negedge core_rst_n) begin : flit_num_cxl_PROC
        if (!core_rst_n) begin
            flit_num_cxl                           <= #TP '0 ;
            next_is_last2_flit_cxl                 <= #TP '0 ;
            flit_num_noshb_ei_eie_cxl              <= #TP '0 ;
            next_is_last2_flit_noshb_ei_eie_cxl    <= #TP '0 ;
        end
        else if( ~cxl_mode_enable || ~crnt_stream[DATA_STREAM_BIT] || ltssm_flit_mode_enable ) begin
            flit_num_cxl               <= #TP '0 ;
            next_is_last2_flit_cxl     <= #TP '0 ;
            flit_num_noshb_ei_eie_cxl              <= #TP '0 ;
            next_is_last2_flit_noshb_ei_eie_cxl    <= #TP '0 ;
        end
        else if( ossq_send_done ) begin
            flit_num_cxl               <= #TP '0 ;
            next_is_last2_flit_cxl     <= #TP '0 ;
            flit_num_noshb_ei_eie_cxl              <= #TP '0 ;
            next_is_last2_flit_noshb_ei_eie_cxl    <= #TP '0 ;
        end
        else if( |xdlh_xmlh_pid && last_chunk && internal_txdata_dv ) begin
            flit_num_cxl                           <= #TP $bits(flit_num_cxl)'( flit_num_cxl + incr_flit_num_cxl ) ;
            next_is_last2_flit_cxl                 <= #TP ( (flit_num_cxl + incr_flit_num_cxl) == flit_interval_cxl - 1 ) ;

            flit_num_noshb_ei_eie_cxl              <= #TP   (flit_num_noshb_ei_eie_cxl == flit_interval_noshb_ei_eie_cxl ) ? '0
                                                          : $bits(flit_num_noshb_ei_eie_cxl)'( flit_num_noshb_ei_eie_cxl + incr_flit_num_cxl ) ;
            next_is_last2_flit_noshb_ei_eie_cxl    <= #TP   ( (flit_num_cxl + incr_flit_num_cxl) == flit_interval_cxl - 1 ) ? '0 
                                                          : ( (flit_num_noshb_ei_eie_cxl + incr_flit_num_cxl) == flit_interval_noshb_ei_eie_cxl - 1 ) ;
        end
    end
    
    // Increment valud for flit_num_cxl
    always_comb begin
        incr_flit_num_cxl = 2'd1 ;
    end

    // Arbitratio timing for iEDS (CXL)
    always_comb begin
        ieds_timing_cxl                    = next_is_last2_flit_cxl              & ( |xdlh_xmlh_pid ) && last_chunk ;
        ieds_timing_noshb_ei_eie_cxl       = next_is_last2_flit_noshb_ei_eie_cxl & ( |xdlh_xmlh_pid ) && last_chunk ;
    end


// TLP or DLLP is sending
    always_comb begin
        next_start_tdlp                 = (|next_xdlh_xmlh_stp_i) | (|next_xdlh_xmlh_sdp_i) ;
        next_end_tdlp                   = (next_xdlh_xmlh_eot_i > next_xdlh_xmlh_stp_i) & (next_xdlh_xmlh_eot_i > next_xdlh_xmlh_sdp_i) ;
        in_tdlp_wo_last_cycle_nonflit   = in_tdlp_progress_nonflit & in_data_progress & ~(crnt_end_tdlp && last_chunk) ;
    end

    always @(posedge core_clk or negedge core_rst_n) begin : crnt_end_tdlp_PROC
        if (!core_rst_n) begin
            crnt_end_tdlp                           <= #TP '0 ; 
        end
        else if(  ~crnt_stream[EIDLE_STREAM_BIT] ) begin  // this condition is just for clock gating.
            crnt_end_tdlp                           <= #TP next_end_tdlp ;
        end
    end

    // TLP/DLLP sending Flag
    always @(posedge core_clk or negedge core_rst_n) begin : in_tdlp_progress_nonflit_PROC
        if (!core_rst_n) begin
            in_tdlp_progress_nonflit                           <= #TP '0 ; 
        end
        else if( ltssm_flit_mode_enable || cxl_mode_enable ) begin
            in_tdlp_progress_nonflit                           <= #TP '0 ; 
        end
        else if( next_start_tdlp ) begin
            in_tdlp_progress_nonflit                           <= #TP 1'b1 ; 
        end
        else if( crnt_end_tdlp && last_chunk ) begin
            in_tdlp_progress_nonflit                           <= #TP 1'b0 ; 
        end
    end
        
    always @(posedge core_clk or negedge core_rst_n) begin : in_data_progress_PROC
        if (!core_rst_n) begin
            in_data_progress              <= #TP '0 ;
        end
        else if( ~ltssm_flit_mode_enable && ~cxl_mode_enable ) begin    // Non-Flit case
                 if( next_grant[G_DATA_BIT] && (ltssm_cmd_i != `SEND_IDLE) && next_start_tdlp ) in_data_progress              <= #TP 1'b1 ;
            else if( crnt_end_tdlp && last_chunk                                              ) in_data_progress              <= #TP 1'b0 ;
        end
        else begin                                                                             // Flit case
            if( next_grant[G_DATA_BIT] || next_grant[G_EDS_BIT] )                               in_data_progress              <= #TP 1'b1 ;
            else                                                                                in_data_progress              <= #TP 1'b0 ;
        end
    end

    // Arbitration timing (No TLP/DLLP in Datastream)
    always_comb begin
        arb_time_datastream_nflit      = ( ~ltssm_flit_mode_enable & ~cxl_mode_enable & crnt_grant[G_DATA_BIT] & ~align_txos_timing) 
                                       ?  ~in_tdlp_wo_last_cycle_nonflit : '0 ; 
    end

// Special case for loopback follower exit
    always_comb begin
        lpbk_follwer_act_exit      = ( (smlh_ltssm_state == S_LPBK_EXIT) | (smlh_ltssm_state == S_LPBK_ACTIVE) ) & ~lpbk_master ;
    end

    always @(posedge core_clk or negedge core_rst_n) begin : lpbk_follwer_act_exit_1d_PROC
        if (!core_rst_n) begin
            lpbk_follwer_act_exit_1d              <= #TP '0 ;
            lpbk_follwer_act_exit_2d              <= #TP '0 ;
        end
        else begin
            lpbk_follwer_act_exit_1d              <= #TP lpbk_follwer_act_exit ;
            lpbk_follwer_act_exit_2d              <= #TP lpbk_follwer_act_exit_1d ;
        end
    end

    always_comb begin
        align_txos_timing        = '0 ;
        mask_tlp_dllp_timing     = '0 ;
        mask_cmp_timing          = '0 ;
    end 

// Data switching timing 
    always_comb begin
       arb_time        = ossq_send_done                                                                     // Ordered Set Sequence is done.
                       | arb_time_datastream_nflit                                                          // No TLP/DLLP in Non-FLIT DataStream or Loopback DataStream
                       | eds_ack                                                                            // The last cycle of EDS Token from xmlh_data_gen
                       | ieds_timing_cxl                                                                    // CXL iEDS replacement timing
                       | ei_cxl_nosb_ds                                                                     // CXL iEDS replacement timing for EI not syncheader bypass
                       | eie_cxl_nosb_ds                                                                    // CXL iEDS replacement timing for EIE not syncheader bypass
                       | last_flit_cycle_pcie                                                               // PCIe FLIT Last cycle for OS insertion.
                       | cmp_arb_timing                                                                     // Compliance pattern block is done.
                       | crnt_stream[EIDLE_STREAM_BIT]                                                      // Any time when E-IDLE 
                       | (lpbk_follwer_act_exit_2d & ~lpbk_follwer_act_exit_1d)                             // Special case for loopback follower exit to algn TxDetectLoopback deasserting and TxElecidle asserting.
                       ;
    end

    // Arbitration timing for compliance pattern.
    always_comb begin
                                                          cmp_arb_timing = cmp_block_done ;
        if( crnt_grant[G_MCMP_BIT] & crnt_rate.enc_1b1b ) cmp_arb_timing = mcmp_gen6_skp_in_progress ? 1'b0 : int_txendblock_wo_g6skp ;
    end

 
// L0p Up/Downsizing request control
    always @(posedge core_clk or negedge core_rst_n) begin : crnt_l0p_state_PROC
        if (!core_rst_n) begin
            crnt_l0p_state              <= #TP L0P_IDLE ;
        end
        else begin
            crnt_l0p_state              <= #TP next_l0p_state ;
        end
    end
    
    always_comb begin
        case( crnt_l0p_state ) 
            L0P_IDLE     : begin
                                 if( smlh_l0p_update && ( ltssm_l0p_lanes_active > int_data_ltssm_lanes_active ) )        next_l0p_state  = L0P_UPSIZING ;
                            else if( smlh_l0p_update && ( ltssm_l0p_lanes_active < int_data_ltssm_lanes_active ) )        next_l0p_state  = L0P_DWSIZING ;
                            else                                                                                          next_l0p_state  = crnt_l0p_state ;
                           end
            L0P_UPSIZING : begin
                                 if( l0p_lane_upsizing_end || l02recovery_chg || crnt_grant[G_EIDLE_BIT] )                next_l0p_state  = L0P_IDLE ;
                            else                                                                                          next_l0p_state  = crnt_l0p_state ;
                           end
            default      : begin                  // L0P_DWSIZING
                                 if( l0p_lane_dwsizing_end || l02recovery_chg || crnt_grant[G_EIDLE_BIT] )                next_l0p_state  = L0P_IDLE ;
                            else                                                                                          next_l0p_state  = crnt_l0p_state ;
                           end
        endcase
    end

// Up/Downsiging start/end flag
    always_comb begin
        l0p_lane_upsizing_start               = crnt_l0p_state[L0P_UPSIZING_BIT] & crnt_l0p_grant[G_EIDLE_BIT] & ~skp_os_req                     // L0p Lane Upsizing start (pulse)
                                              & (  (xdlh_xmlh_eof         & last_chunk    )                                                           // End of Flit timing (other than SKP OS)                             
                                                 | (crnt_grant[G_SKP_BIT] & os_send_done  )  ) ;                                                      // SKP OS is done
        l0p_lane_upsizing_end                 = crnt_l0p_grant[G_SKP_BIT] & l0p_ossq_send_done & l0p_upsizing_sds_done ;                                                  // L0p Lane Upsizing end (pulse)   : SKP OS send all lanes at the same time.
        l0p_lane_dwsizing_start               = crnt_l0p_state[L0P_DWSIZING_BIT] & (last_flit_cycle_pcie & skp_os_req) & ~ei__os_req & (ltssm_l0p_cmd == `SEND_EIDLE);    // L0p Lane Downsizing start (pulse) : FLIT OS insertion timing.
        l0p_lane_dwsizing_end                 = crnt_l0p_grant[G_EI_BIT]  & l0p_ossq_send_done ;                                                                          // L0p Lane Downsizing end (pulse) : End EIOS sending
        l0p_lane_updw_end_by_recovery         = ( int_data_smlh_link_mode != smlh_link_mode ) & l02recovery_chg ;                                                         // Recovery Entry when L0p Up/Downsizing
        xmtbyte_l0p_linkwidth_changed         = (l0p_lane_upsizing_end & (ltssm_l0p_cmd == `SEND_IDLE))
                                              | (l0p_lane_dwsizing_end & (ltssm_l0p_cmd == `SEND_EIDLE))
                                              |  l0p_lane_updw_end_by_recovery;
    end

// Data switching timing (L0p)
    always_comb begin
       l0p_arb_time    = l0p_ossq_send_done                                                                  // Ordered Set Sequence is done.
                       | l0p_lane_upsizing_start                                                             // L0p Lane Upsizing start
                       | l0p_lane_dwsizing_start                                                             // L0p Lane Downsizing start
                       | (crnt_l0p_state[L0P_UPSIZING_BIT] & (last_flit_cycle_pcie & skp_os_req) 
                         & (l0p_ltssm_lanes_active_latch == int_l0p_ltssm_lanes_active) )                    // DataStream SKP insertion.
                       ;
    end
    


// ---------------------------------------
// Layer2 Data path I/F
// ---------------------------------------
    always @(posedge core_clk or negedge core_rst_n) begin : xmlh_skip_pending_PROC
        if (!core_rst_n) begin
            xmlh_skip_pending        <= #TP '0;
        end 
        else if( ltssm_flit_mode_enable || cxl_mode_enable || ~next_stream[DATA_STREAM_BIT] ) begin
            xmlh_skip_pending        <= #TP '0;
        end
        else begin
            xmlh_skip_pending        <= #TP skp_os_req & ~next_end_tdlp ;
        end 
    end

    always_comb begin
        xmtbyte_cmd_is_data         =  ( crnt_grant[G_DATA_BIT] | (crnt_grant[G_EDS_BIT] & cxl_mode_enable) )
                                    &  (ltssm_cmd_i != `SEND_IDLE) ;                                                     // Assert when can receive TLP/DLLP(Not IDLE pattern sending duration)
        xmlh_rst_flit_alignment     = crnt_grant[G_EI_BIT] | crnt_grant[G_EIE_BIT] | crnt_grant[G_TS0_BIT] | crnt_grant[G_TS1_BIT] | crnt_grant[G_TS2_BIT] ;

     // xmlh_xfsh_last_flit if for flushing xfsh FIFO when FREQ_STEP. This timing is from original design.
        xmlh_xfsh_last_flit         = 1'b0 ;
    end




// ---------------------------------------
// SKP OS trigger 
// ---------------------------------------

// SKP Symbol Count (8b/10b)
    // select Symbol Interval
    always_comb begin
        symbol_interval_8b10b         = sris_mode_on ? ltssm_flit_mode_enable ? SKP_INTVL_8b10b_FLIT_SRIS
                                                                              : `DEFAULT_SHORT_SKIP_INTERVAL 
                                                     : cfg_skip_interval ;

        symbol_countup_val_8b10b      = 2'b01;
    end

    // SKP Request when enter Datastream 8b10b flit to accellarete SKP interval to avoid SVA error.
    always_comb begin
        skp_req_ent_dstream_8b10_flit = ltssm_flit_mode_enable 
                                      & ( ((ltssm_cmd_i == `NORM) & (ltssm_cmd_i_d != `NORM)) | l0p_lane_upsizing_end | l0p_lane_dwsizing_end )
                                      & ( (skp_req_count == '0) | (int_data_smlh_link_mode <= 6'd2) )
                                      & sris_mode_on ;
    end

    // Symbol Counter 
    always @(posedge core_clk or negedge core_rst_n) begin : symbol_count_skp_8b10b_PROC
        if (!core_rst_n) begin
            symbol_count_skp_8b10b              <= #TP '0 ;
            skp_req_update_8b10b                <= #TP '0 ;
        end
        else if( ~crnt_rate.enc_8b10b || crnt_stream[EIDLE_STREAM_BIT] 
              || ( crnt_stream[CMP_STREAM_BIT] && ~cfg_compliance_sos )            // Not send if Compliance SOS register is not set in Gen1/2 (Modified) compliance pattern..
              || ( fts_os_req                  && ~cfg_ext_synch      )            // Not send if Extended Sync register is not set in Gen1/2 FTS sequence.
              ||   skp_req_update_8b10b  ) begin
            symbol_count_skp_8b10b              <= #TP '0 ;
            skp_req_update_8b10b                <= #TP '0 ;
        end
        else begin
            symbol_count_skp_8b10b     <= #TP   internal_txdata_dv_non_128b130b ? $bits(symbol_count_skp_8b10b)'( symbol_count_skp_8b10b + symbol_countup_val_8b10b ) : symbol_count_skp_8b10b ;
            skp_req_update_8b10b       <= #TP  (internal_txdata_dv_non_128b130b & ((symbol_count_skp_8b10b + symbol_countup_val_8b10b) >= symbol_interval_8b10b))     ? 1'b1 
                                             : (skp_req_ent_dstream_8b10_flit)                                                                                        ? 1'b1     // Send if OSstream to Datastream transition to improve avarege skp interval to escape SVA error.
                                                                                                                                                                      : 1'b0 ;
        end
    end

// SKP Data Block Count (128b/130b)
    // select Data Block Interval
    always_comb begin
        case( { sris_mode_on , crnt_rate.enc_1b1b } )
            { 1'b0 , 1'b0 } : dblock_interval   = `DEFAULT_GEN3_SKIP_INTERVAL ;             // 128b/130b Common CLK
            { 1'b1 , 1'b0 } : dblock_interval   = `DEFAULT_GEN3_SHORT_SKIP_INTERVAL ;       // 128b/130b Common SRIS
            { 1'b0 , 1'b1 } : dblock_interval   = SKP_INTVL_1b1b_DBLOCK_CCLK ;              // 1b1b Common CLK
            default         : dblock_interval   = SKP_INTVL_1b1b_DBLOCK_SRIS ;              // 1b1b Common SRIS
        endcase
    end

    // Data Block Counter 
    always @(posedge core_clk or negedge core_rst_n) begin : dblock_count_skp_PROC
        if (!core_rst_n) begin
            dblock_count_skp              <= #TP '0 ;
            skp_req_update_dblock         <= #TP '0 ;
        end
        else if( ( crnt_stream[DATA_STREAM_BIT] && ~crnt_rate.enc_128b130b )                    // Disable if DataStream and not 128b/130b
              || ( crnt_stream[DATA_STREAM_BIT] &&  ltssm_flit_mode_enable )                    // Disable if DataStream and PCIe Flit
              || ( next_grant[G_SDS_BIT]        &&  ltssm_flit_mode_enable )                    // Disable if SDS and PCIe Flit
              || ( crnt_stream[DATA_STREAM_BIT] &&  cxl_mode_enable && crnt_grant[G_SKP_BIT] )  // clear if SKP is sent DataStream and CXL
              || ( cxl_mode_enable && (crnt_grant[G_SDS_BIT] || skp_req_g3cxl_before_sds) )     // clear if SDS is sent when CXL
              || ( crnt_rate.enc_8b10b )                                                        // Disable if 8b/10b
              ||   crnt_stream[EIDLE_STREAM_BIT]                                                // Disable if E-IDLE
              ||   crnt_stream[CMP_STREAM_BIT]                                                  // Disable if Compliance pattern
              ||   skp_req_update_dblock                                                        // Clear for expiration
               ) begin
            dblock_count_skp              <= #TP '0 ;
            skp_req_update_dblock         <= #TP '0 ;
        end
        else if( int_txendblock_wo_g6skp ) begin
            dblock_count_skp              <= #TP  
                                                               $bits(dblock_count_skp)'( dblock_count_skp + 1'b1 ) ;
            skp_req_update_dblock         <= #TP ( crnt_stream[DATA_STREAM_BIT] &&  cxl_mode_enable ) ? '0 :             // CXL SKP interval is counted by Flit num
                                                ( (dblock_count_skp + 1'b1) >= dblock_interval ) ? 1'b1 : 1'b0;
        end
        else begin
            skp_req_update_dblock         <= #TP 1'b0;
        end
    end

// SKP Request : Before SDS OS sending (Control SKP OS) if Gen4/5 Non-FLIT
     always_comb begin
        os2dstream_transition      = crnt_stream[OS_STREAM_BIT] & ts_masked_dstream & ~ts_masked_dstream_d ;
        skp_req_g45_before_sds     = os2dstream_transition 
                                   & (crnt_rate.one_hot[GEN4_BIT] | crnt_rate.one_hot[GEN5_BIT])         
                                   & ~ltssm_flit_mode_enable                                                   // Not send if Flit Mode
                                   & ~(int_ltssm_in_lpbk & ~lpbk_master) ;                                     // Not send if Loopback Slave
        skp_req_g3cxl_before_sds   = os2dstream_transition 
                                   & (crnt_rate.one_hot[GEN3_BIT] & cxl_mode_enable) 
                                   & ~ltssm_flit_mode_enable                                                   // Not send if Flit Mode
                                   & ~(int_ltssm_in_lpbk & ~lpbk_master) ;                                     // Not send if Loopback Slave
        skp_req_flit_after_sds     = ltssm_flit_mode_enable & crnt_grant[G_SDS_BIT] & ossq_send_done & (skp_req_count == '0) ;
    end

    always @(posedge core_clk or negedge core_rst_n) begin : skp_req_g45_before_sds_latch_PROC
        if (!core_rst_n) begin
            skp_req_g45_before_sds_latch              <= #TP '0 ;
            skp_req_g3cxl_before_sds_latch            <= #TP '0 ;
        end
        else if( ~crnt_stream[OS_STREAM_BIT] || (arb_time && next_grant[G_SKP_BIT]) ) begin
            skp_req_g45_before_sds_latch              <= #TP '0 ;
            skp_req_g3cxl_before_sds_latch            <= #TP '0 ;
        end
        else begin
             if( skp_req_g45_before_sds ) begin
                skp_req_g45_before_sds_latch              <= #TP 1'b1 ;
             end
             if( skp_req_g3cxl_before_sds ) begin
                skp_req_g3cxl_before_sds_latch            <= #TP 1'b1 ;
             end
        end
    end

    always @(posedge core_clk or negedge core_rst_n) begin : skp_before_sds_in_progress_PROC
        if (!core_rst_n) begin
            skp_before_sds_in_progress              <= #TP '0 ;
        end
        else if( ~crnt_stream[OS_STREAM_BIT] || next_grant[G_SDS_BIT] ) begin
            skp_before_sds_in_progress              <= #TP '0 ;
        end
        else if(  (arb_time && next_grant[G_SKP_BIT]) 
               && ( (skp_req_g45_before_sds || skp_req_g45_before_sds_latch) || (skp_req_g3cxl_before_sds || skp_req_g3cxl_before_sds_latch) ) ) begin
            skp_before_sds_in_progress              <= #TP 1'b1 ;
        end
    end


 
// SKP OS Trriger (pulse)
    always_comb begin
        skp_req_pulse        = skp_req_update_8b10b                                                   // Periodically interval for Gen1/2
                             | skp_req_update_dblock                                                  // Periodically interval for Gen3/4/5 Non-Flit or Not DataSteam in Flit
                             | (last_flit_cycle_pcie & ~crnt_rate.enc_8b10b)                          // Periodically interval for PCIe Flit (Gen1/2 is not Periodically depends on skp_req_update_8b10b)
                             | skp_req_flit_after_sds                                                 // After SDS when PCIe Flit mode
                             | ieds_timing_cxl                                                        // Periodically interval for CXL Flit
                             | (skp_req_g3cxl_before_sds & (skp_req_count == '0))                     // Before SDS when Gen4/5 Non-FLIT other than FTS->SDS
                             | (skp_req_g45_before_sds & (skp_req_count == '0))                       // Before SDS when Gen4/5 Non-FLIT other than FTS->SDS
                             | (xmtbyte_fts_sent & (skp_req_count == '0) & crnt_rate.enc_8b10b) ;     // After Last FTS if Gen1/2
    end


// SKP request count
    always @(posedge core_clk or negedge core_rst_n) begin : skp_req_count_PROC
        if (!core_rst_n) begin
            skp_req_count              <= #TP '0 ;
        end
        else if( next_stream[EIDLE_STREAM_BIT] || (crnt_stream[CMP_STREAM_BIT] && (~cfg_compliance_sos || ~crnt_rate.enc_8b10b)) ) begin
            skp_req_count              <= #TP '0 ;
        end
        else if( (skp_req_count !=    '0) &&  (arb_time && next_grant[G_SKP_BIT]) && ~skp_req_pulse ) begin   // count down
            skp_req_count              <= #TP $bits(skp_req_count)'( skp_req_count - 1'b1 ) ;
        end
        else if( (skp_req_count != 5'h1F) && skp_req_pulse && ~(fts_phase_128b130b && ~cfg_ext_synch && (skp_req_count > 5'h00)) ) begin          // count up. Up to 1 when 128b/130b FTS
            if( int_ltssm_in_lpbk && lpbk_master && crnt_rate.enc_128b130b ) begin // 2 SKP in Loopback master. But not back-to-back for deskew module.
                skp_req_count              <= #TP (arb_time && next_grant[G_SKP_BIT]) ? $bits(skp_req_count)'( skp_req_count + 1'b1 ) 
                                                                                      : $bits(skp_req_count)'( skp_req_count + 2'd2 ) ;
            end
            else begin                                                                       // Other than loopback master
                skp_req_count              <= #TP (arb_time && next_grant[G_SKP_BIT]) ? skp_req_count 
                                                                                      : $bits(skp_req_count)'( skp_req_count + 2'd1 ) ;
            end
        end
    end


// SKP OS request
    always_comb begin
        skp_os_req             = 
                                  (skp_req_pulse | (|skp_req_count) ) &          // Request
                                 ~(fts_phase_128b130b & ~cfg_ext_synch) &        // Don't send if FTS phase with Extended Sync=0. (For 8b/10b, interval counter(symbol_count_skp_8b10b) is not incremented when FTS phase)
                                 ~(os_mask_phase) ;                              // Don't send after SDS or SKP in datastream
    end

// Control SKP OS Enable
    always @(posedge core_clk or negedge core_rst_n) begin : ctl_skp_enable_PROC
        if (!core_rst_n) begin
            ctl_skp_enable              <= #TP '0 ;
            alternate_skp_phase         <= #TP '0 ;
        end
        else if(  ~(ltssm_flit_mode_enable || crnt_rate.eq_or_higher[GEN4_BIT] )          // Enable when Flit or Gen4/5 Non-Flit or CCIX 16GT/s
               ||  (int_ltssm_in_lpbk & crnt_rate.enc_128b130b)                           // Standard SKP when Loopback 128b/130b
               ||  crnt_stream[EIDLE_STREAM_BIT]                                          // Clear when E-IDLE
               ) begin  
            ctl_skp_enable              <= #TP '0 ;
            alternate_skp_phase         <= #TP '0 ;
        end
        else if( crnt_rate.enc_1b1b ) begin         // When 1b1b always sending alternate control and standart SKP.
            ctl_skp_enable              <= #TP (crnt_grant[G_SKP_BIT] && os_send_done)  ? ~ctl_skp_enable 
                                                                                        :  ctl_skp_enable ;
            alternate_skp_phase         <= #TP 1'b1 ;
        end
        else begin                                 // When 128b/130b sending alternate control and standart SKP when datastream and SKP before SDS
            if( crnt_stream[DATA_STREAM_BIT] && ~next_stream[DATA_STREAM_BIT] ) begin        // Standard SKP when OS Stream 
                ctl_skp_enable              <= #TP '0 ;
                alternate_skp_phase         <= #TP '0 ;
            end
            else if( ( (skp_req_g45_before_sds || skp_req_g45_before_sds_latch) && (arb_time && next_grant[G_SKP_BIT]) )  // Before SDS when Gen4/5 Non-Flit
                 ||  (crnt_grant[G_SDS_BIT] && ltssm_flit_mode_enable )                                                   // After SDS when Flit
                 ||  (crnt_l0p_grant[G_SDS_BIT] && ltssm_flit_mode_enable )                                               // After L0p upsizing
                 ) begin
                ctl_skp_enable              <= #TP 1'b1 ;
                alternate_skp_phase         <= #TP 1'b1 ;
            end
            else begin
                if( alternate_skp_phase && crnt_grant[G_SKP_BIT] && os_send_done ) begin  
                    ctl_skp_enable              <= #TP ~ctl_skp_enable ;
                end
                if( crnt_grant[G_SDS_BIT] ) begin                         // Non-Flit L0s -> L0 case. Start froms standard SKP in this case from original design.
                    alternate_skp_phase         <= #TP 1'b1 ;
                end
            end
        end
    end


// ---------------------------------------
// EIE OS trigger 
// ---------------------------------------
// TS/FTS Counter
    always @(posedge core_clk or negedge core_rst_n) begin : eie_interval_count_PROC
        if (!core_rst_n) begin
            eie_interval_count              <= #TP '0 ;
            eie_interval_req                <= #TP '0 ;
        end
        else if(  (~ltssm_ts_cnt_en_i && ~fts_phase_128b130b)                              // Enable when TS phase or FTS Phase of 128b130b
               || ltssm_ts_cnt_rst                                                         // Reset request from LTSSM
               || (|eqctl_2mask_eieos_pulse)                                               // Received on any Lane with the Reset EIEOS Interval Count bit set.(pulse)
               || (|eqctl_mask_eieos)                                                      // Received on any Lane with the Reset EIEOS Interval Count bit set.(Level)
               || link_rx_ts0_to_ts1_pulse                                                 // Received TS1 Ordered Set after TS0 Ordered Sets when in the LTSSM Recovery.Equalization
               || (~next_stream[OS_STREAM_BIT])                                            // Clear when Non OS stream
        ) begin                    
            eie_interval_count              <= #TP '0 ;
            eie_interval_req                <= #TP '0 ;
        end
        else if( crnt_grant[G_EIE_BIT] && os_send_done ) begin
            eie_interval_count              <= #TP '0 ;
            eie_interval_req                <= #TP '0 ;
        end
        else if( (crnt_grant[G_TS0_BIT] || crnt_grant[G_TS1_BIT] || crnt_grant[G_TS2_BIT] || crnt_grant[G_FTS_BIT]) && os_send_done ) begin  
               eie_interval_count              <= #TP 
                                                                   $bits(eie_interval_count)'(eie_interval_count + 1'b1) ;
 
            if( next_grant[G_TS0_BIT] || next_grant[G_TS1_BIT] || next_grant[G_TS2_BIT] || next_grant[G_FTS_BIT] ) begin   // Next OS is 32th TS case (Not SKP inserted)
                eie_interval_req                <= #TP
                                                                      (   (eie_interval_count + 1'b1) ==  5'd31 ) ;
            end
            else begin
                eie_interval_req                <= #TP 1'b0 ;
            end
        end
        else if( (next_grant[G_TS0_BIT] || next_grant[G_TS1_BIT] || next_grant[G_TS2_BIT] || next_grant[G_FTS_BIT]) && os_send_done ) begin     // Current OS is SKP , Next OS is 32th TS
                eie_interval_req                <= #TP
                                                                        (eie_interval_count ==  5'd31) ;
        end
        else begin
            eie_interval_req                <= #TP 1'b0 ;
        end
    end

// Send EIE OS when entry Recory.RcvrLock for Recovery.EQ.
    always @(posedge core_clk or negedge core_rst_n) begin : ltssm_in_rec_req_d_PROC
        if (!core_rst_n) begin
            ltssm_in_rec_req_d              <= #TP '0 ;
        end
        else if( (smlh_ltssm_state == S_RCVRY_EQ0) || (smlh_ltssm_state == S_RCVRY_EQ1) || (smlh_ltssm_state == S_RCVRY_EQ2) || (smlh_ltssm_state == S_RCVRY_EQ3) ) begin
            ltssm_in_rec_req_d              <= #TP 1'b1 ;
        end
        else begin
            ltssm_in_rec_req_d              <= #TP 1'b0 ;
        end
    end

// EIE OS condition (pulse)
    always_comb begin
        eie_datastream_exit_en    = crnt_rate.eq_or_higher[GEN3_BIT] | (smlh_ltssm_state == S_RCVRY_LOCK) | (smlh_ltssm_state == S_CFG_LINKWD_START) ;    // Send EIE when exiting DataStream condition. Not send EIE when Gen2 Recovery.Idle -> HotReset/Disabled/Loopback

        eie_before_ts             = ( (ltssm_cmd_i == `SEND_TS1) & (ltssm_cmd_i_d != `SEND_TS1) & ~crnt_stream[DATA_STREAM_BIT] & ((smlh_ltssm_state == S_RCVRY_LOCK) | (smlh_ltssm_state == S_CFG_LINKWD_START) | crnt_stream[EIDLE_STREAM_BIT]) )   // Enter Recovery/Configuration or Exit E-IDLE(other than from Recovery.EQ)
                                  | ( (ltssm_cmd_i == `SEND_TS1) & crnt_stream[DATA_STREAM_BIT] & eie_datastream_exit_en & ~(cxl_mode_enable & ~ltssm_cxl_sh_bypass & ~ltssm_flit_mode_enable) ) ;                                                    // Transition from Datastream to OSstream.
        eie_cxl_nosb_ds           = (cxl_mode_enable & ~ltssm_cxl_sh_bypass & ~ltssm_flit_mode_enable) & crnt_stream[DATA_STREAM_BIT]                         // if CXL not syncheader Bypass Send SKP first after that send iEDS and EIE/EI. 
                                  & ieds_timing_noshb_ei_eie_cxl                                                                                              // -> This is to escape SKP interval 375Block. In CXL 68Byte file need to 374 Block interval.
                                  & (ltssm_cmd_i == `SEND_TS1)                                                                                                // -> Because of Block(16Byte) and Flit(68Byte) should be aligned to send OS.
                                  & ei_eie_sending_en &  ~os_mask_phase ;                                                                                     // -> If we insert EIE/EI before SKP, we can not meet 375Block interval.
    end

// EIE OS Trriger (pulse)
    always_comb begin
        eie_req_pulse      = crnt_rate.eq_or_higher[GEN2_BIT] & 
                           (     eie_before_ts                                                                                // EIEOS request before sending TS1
                             |   eie_cxl_nosb_ds                                                                              // EIEOS request when CXL with Not Syncheader bypass in Data stream.
                             | ( ltssm_in_rec_req_d & (smlh_ltssm_state == S_RCVRY_LOCK) )                                   // Enter Recovery.RevrLock from Recovery.EQ
                             | ( (ltssm_cmd_i == `SEND_N_FTS) & (ltssm_cmd_i_d != `SEND_N_FTS) & crnt_rate.enc_128b130b)      // Before FTS when Gen3/4/5
                             | ( xmtbyte_fts_sent & crnt_rate.enc_128b130b)                                                   // After the last FTS when Gen3/4/5
                             | (|scramble_lfsr_rollover & |eqctl_mask_eieos)                                                  // inserting EIEOS after a sequence of 65536 uninterrupted TS1s
                             | (eie_interval_req &  ~ltssm_ts_cnt_rst)                                                        // EIEOS is sent every 32 TS0/1/2 or FTS.
                             | (sds_req_pulse & int_ltssm_in_lpbk & lpbk_master)                                              // Before SDS in Loopback Master, this is implementation specific case
                           ) ;
    end


// Latched EIE OS request 
    always @(posedge core_clk or negedge core_rst_n) begin : eie_req_latch_PROC
        if (!core_rst_n) begin
            eie_req_latch              <= #TP '0 ;
        end
        else if( next_stream[EIDLE_STREAM_BIT] || next_stream[CMP_STREAM_BIT] ) begin
            eie_req_latch              <= #TP '0 ;
        end
        else if( next_grant[G_EIE_BIT] && ~ltssm_cmd_send_eieos_for_pset_map ) begin   // not lathc. if ltssm_cmd_send_eieos_for_pset_map is set, send EIEOS continuously.
            eie_req_latch              <= #TP 1'b0 ;
        end
        else if( eie_req_pulse ) begin                                            // latch
            eie_req_latch              <= #TP 1'b1 ;
        end
    end


// EIE OS request
    always_comb begin
        eie_os_condition  = (eie_req_pulse | eie_req_latch) ;

        eie_os_req       = eie_os_condition                                                                                       // Each request
                         & ei_eie_sending_en                                                                                      // To Exit DataSteam (To Recovery or Low Power), need to wait TLP/DLLP fulshing is done.
                         & ~os_mask_phase                                                                                         // all OS should not be sent.(After SDS or SKP in datastream)
                         & ~((skp_req_count != '0) & ~ltssm_flit_mode_enable & ~cxl_mode_enable & crnt_stream[DATA_STREAM_BIT]) ; // Prior SKP when Non-Flit Data stream to avoid over interval time
    end


// ---------------------------------------
// EIE 8symbol trigger 
// ---------------------------------------

// EIE 8symbol OS Trriger (pulse)
    always_comb begin
        eie_8sym_req_pulse      = crnt_rate.one_hot[GEN2_BIT] & 
                                 (ltssm_cmd_i == `SEND_N_FTS) & (ltssm_cmd_i_d != `SEND_N_FTS) ;      // Before FTS when Gen2
    end

// Latched EIE 8symbol OS request 
    always @(posedge core_clk or negedge core_rst_n) begin : eie_8sym_req_latch_PROC
        if (!core_rst_n) begin
            eie_8sym_req_latch              <= #TP '0 ;
        end
        else if( next_stream[EIDLE_STREAM_BIT] || next_stream[CMP_STREAM_BIT] ) begin
            eie_8sym_req_latch              <= #TP '0 ;
        end
        else if( next_grant[G_EIE_8SYM_BIT] ) begin                                    // not lathc
            eie_8sym_req_latch              <= #TP 1'b0 ;
        end
        else if( eie_8sym_req_pulse ) begin                                            // latch
            eie_8sym_req_latch              <= #TP 1'b1 ;
        end
    end


// EIE 8symbol request
    always_comb begin
        eie_8sym_req       = (eie_8sym_req_pulse | eie_8sym_req_latch) ;                   // Each request
    end

// ---------------------------------------
// SDS OS trigger 
// ---------------------------------------
// Gen4/5 SDS after SKP when Configuration/Recovery.Idle
    always_comb begin
        sds_g45_req         = crnt_stream[OS_STREAM_BIT] 
                            & ((ltssm_cmd_i == `SEND_IDLE) | (ltssm_cmd_i == `NORM))
                            & (crnt_grant[G_SKP_BIT] & (skp_req_count == '0) & skp_before_sds_in_progress)
                            & ~ltssm_flit_mode_enable ;
    end

// SDS OS Trriger (pulse)
    always_comb begin
        sds_req_pulse      = crnt_rate.eq_or_higher[GEN3_BIT] & ~ltssm_in_compliance & ~(int_ltssm_in_lpbk & ~lpbk_master) &            // Not send if Loopback Slave
                           (   ( os2dstream_transition & (ltssm_flit_mode_enable || (crnt_rate.one_hot[GEN3_BIT] & ~cxl_mode_enable)) ) // Immediately Enter Recovery/Configuration.Idle if Flit or Gen3
                             | sds_g45_req                                                                                              // Gen4/5 SDS after SKP when Configuration/Recovery.Idle
                             | ( xmtbyte_fts_sent & crnt_rate.enc_128b130b) ) ;                                                         // After the last FTS -> EIE when Gen3/4/5 (EIE req is also asserted at the same time. but EIE is high priority)
    end


// Latched SDS OS request 
    always @(posedge core_clk or negedge core_rst_n) begin : sds_req_latch_PROC
        if (!core_rst_n) begin
            sds_req_latch              <= #TP '0 ;
        end
        else if( next_stream[EIDLE_STREAM_BIT] || next_stream[CMP_STREAM_BIT] ) begin
            sds_req_latch              <= #TP '0 ;
        end
        else if( next_grant[G_SDS_BIT] ) begin                                    // not lathc
            sds_req_latch              <= #TP 1'b0 ;
        end
        else if( sds_req_pulse ) begin                                            // latch
            sds_req_latch              <= #TP 1'b1 ;
        end
    end

// SDS OS request
    always_comb begin
        sds_os_req       = (sds_req_pulse | sds_req_latch)                      // Each request
                         & ~os_mask_phase ;                                     // all OS should not be sent.(After SDS or SKP in datastream)
    end



// ---------------------------------------
// EDS Token trigger 
// ---------------------------------------

// EDS Token Request
    always_comb begin
        eds_token_req      = crnt_rate.enc_128b130b & ~ltssm_flit_mode_enable                                        // EDS is not required to send when loopback, But send in xmlh_data_gen.sv 
                           & (crnt_grant[G_DATA_BIT] | (crnt_stream[DATA_STREAM_BIT] & crnt_grant[G_SKP_BIT])) & 
                           (   skp_os_req                                                                            // SKP request in data stream
                             | eie_os_req                                                                            // EIE request in data stream
                             | ei__os_req ) ;                                                                        // EI request in data stream
    end

 
// ---------------------------------------
// EI OS trigger 
// ---------------------------------------

// EI OS trigger
    always_comb begin
        ei_non_cxl_nosb_ds = (ltssm_cmd_i == `SEND_EIDLE) & ~(cxl_mode_enable & ~ltssm_cxl_sh_bypass  & ~ltssm_flit_mode_enable & crnt_stream[DATA_STREAM_BIT]) ;  // Requested from LTSSM

        ei_cxl_nosb_ds     = (cxl_mode_enable & ~ltssm_cxl_sh_bypass & ~ltssm_flit_mode_enable) & crnt_stream[DATA_STREAM_BIT]    // if CXL not syncheader Bypass Send SKP first after that send iEDS and EIE/EI. 
                            & ieds_timing_noshb_ei_eie_cxl                                                                        // -> This is to escape SKP interval 375Block. In CXL 68Byte file need to 374 Block interval.
                            & (ltssm_cmd_i == `SEND_EIDLE)                                                                        // -> Because of Block(16Byte) and Flit(68Byte) should be aligned to send OS.
                            & ei_eie_sending_en & ~os_mask_phase ;                                                                // -> If we insert EIE/EI before SKP, we can not meet 375Block interval.
    end

// Latched EI OS request (only for CXL Nosyncheader bypass datastream)
    always @(posedge core_clk or negedge core_rst_n) begin : ei_cxl_nosb_ds_latch_PROC
        if (!core_rst_n) begin
            ei_cxl_nosb_ds_latch              <= #TP '0 ;
        end
        else if( next_stream[EIDLE_STREAM_BIT] || next_stream[CMP_STREAM_BIT] ) begin
            ei_cxl_nosb_ds_latch              <= #TP '0 ;
        end
        else if( next_grant[G_EI_BIT] ) begin
            ei_cxl_nosb_ds_latch              <= #TP 1'b0 ;
        end
        else if( ei_cxl_nosb_ds ) begin                                            // latch
            ei_cxl_nosb_ds_latch              <= #TP 1'b1 ;
        end
    end
    
// EI OS Request
    always_comb begin
        ei__os_condition = ~crnt_grant[G_EI_BIT] & ~fill_gap_eios_ei 
                         & ( ei_non_cxl_nosb_ds | ei_cxl_nosb_ds | ei_cxl_nosb_ds_latch ) ;

        ei__os_req         = ei_eie_sending_en & ei__os_condition & ~os_mask_phase ;
    end


// ---------------------------------------
// E-IDLE request trigger 
// ---------------------------------------

// EIOS sending is done, but ltssm_cmd still EIOS. In this gap, need to Keep EI.
    always @(posedge core_clk or negedge core_rst_n) begin : fill_gap_eios_ei_PROC
        if (!core_rst_n) begin
            fill_gap_eios_ei              <= #TP '0 ;
        end
        else if( crnt_grant[G_EI_BIT] ) begin
            fill_gap_eios_ei              <= #TP 1'b1 ;
        end
        else if( ltssm_cmd_i != `SEND_EIDLE) begin
            fill_gap_eios_ei              <= #TP 1'b0 ;
        end
    end


// E-IDLE request Request
    always_comb begin
        eidle_req         =   crnt_grant[G_EI_BIT]                             // After E-IDLE OS
                          |  fill_gap_eios_ei                                  // Gap EIOS done to ltssm_cmd change to EIDLE.
                          |  (ltssm_cmd_i == `XMT_IN_EIDLE)                    // Requested from LTSSM
                          |  (ltssm_cmd_i == `SEND_RCVR_DETECT_SEQ) ;          // Requested from LTSSM (TxDetect Loopback request is in E-IDLE)
    end
    

// ---------------------------------------
// TS0 request trigger 
// ---------------------------------------
    always_comb begin
        ts0_os_req          = ei_eie_sending_en & (ltssm_cmd_eqts0  | eqctl_g6_tx_ts0 ) & ~os_mask_phase &      
                             (ltssm_cmd_i == `SEND_TS1) ;                   // Requested from LTSSM

        ts0_sending_req     = ts0_os_req ;
    end

// ---------------------------------------
// TS1 OS request trigger 
// ---------------------------------------
    always_comb begin
        ts1_os_condition    = ~(ltssm_cmd_eqts0  | eqctl_g6_tx_ts0 ) &
                             (  (ltssm_cmd_i == `SEND_TS1)                        // Requested from LTSSM      
                               | ts1_sending_extension )    ;                     // Timing adjustment for Flit

        ts1_os_req          = ei_eie_sending_en & ~os_mask_phase & ts1_os_condition ;
                             

        ts1_sending_req     = ts1_os_req ;
    end

// ---------------------------------------
// TS2 OS request trigger 
// ---------------------------------------
    always_comb begin
        ts2_os_req          = ei_eie_sending_en & ~os_mask_phase &
                             (   (ltssm_cmd_i == `SEND_TS2)                       // Requested from LTSSM
                               | ts2_sending_extension )    ;                     // Timing adjustment for Flit

        ts2_sending_req     = ts2_os_req ;
    end


// ---------------------------------------
// FTS OS 8symbol trigger 
// ---------------------------------------
// EI OS Trriger (pulse)
    always_comb begin
        fts_req_pulse      = (ltssm_cmd_i == `SEND_N_FTS) & (ltssm_cmd_i_d != `SEND_N_FTS) ;      // Requested from LTSSM
    end

// Latched FTS OS request 
    always @(posedge core_clk or negedge core_rst_n) begin : fts_req_latch_PROC
        if (!core_rst_n) begin
            fts_req_latch              <= #TP '0 ;
        end
        else if( next_stream[EIDLE_STREAM_BIT] || next_stream[CMP_STREAM_BIT] ) begin
            fts_req_latch              <= #TP '0 ;
        end
        else if( xmtbyte_fts_sent ) begin                                         // Complete
            fts_req_latch              <= #TP 1'b0 ;
        end
        else if( fts_req_pulse ) begin                                            // latch
            fts_req_latch              <= #TP 1'b1 ;
        end
    end


// EI OS request
    always_comb begin
        fts_os_req         = (fts_req_pulse | fts_req_latch) ;                   // Each request
    end

// ---------------------------------------
// Compliance Pattern trigger
// ---------------------------------------
    always_comb begin
        cmp_ptn_req         = (ltssm_cmd_i == `COMPLIANCE_PATTERN)              // Requested from LTSSM
                            & ~mask_cmp_timing
                            ;
    end

// ---------------------------------------
// Modified Compliance Pattern trigger
// ---------------------------------------
    always_comb begin
        mcmp_ptn_req        = (ltssm_cmd_i == `MOD_COMPL_PATTERN)              // Requested from LTSSM
                            & ~mask_cmp_timing
                            ;
    end


// ---------------------------------------
// Grant signals Normal(Not L0p) 
// ---------------------------------------

// Next Grant
    always_comb begin
        next_grant = crnt_grant ;
        if( arb_time ) begin             // Grant is changed if arb_time is asserted
                  if( eidle_req     ) next_grant  = G_EIDLE ;
            else  if( eds_token_req ) next_grant  = G_EDS ;
            else  if( ei__os_req    ) next_grant  = G_EI_OS ;
            else  if( eie_os_req    ) next_grant  = G_EIE_OS ;
            else  if( eie_8sym_req  ) next_grant  = G_EIE_8SYM_OS ;
            else  if( sds_os_req    ) next_grant  = G_SDS_OS ;
            else  if( skp_os_req    ) next_grant  = G_SKP_OS ;
            else  if( ts0_os_req    ) next_grant  = G_TS0_OS ;
            else  if( ts1_os_req    ) next_grant  = G_TS1_OS ;
            else  if( ts2_os_req    ) next_grant  = G_TS2_OS ;
            else  if( fts_os_req    ) next_grant  = G_FTS_OS ;
            else  if( cmp_ptn_req   ) next_grant  = G_CMP_PTN ;
            else  if( mcmp_ptn_req  ) next_grant  = G_MCMP_PTN ;
            else                      next_grant  = G_DATA ;
        end
    end

// Current Grant
    always @(posedge core_clk or negedge core_rst_n) begin : crnt_grant_PROC
        if (!core_rst_n) begin
            crnt_grant              <= #TP G_EIDLE ;
        end
        else begin
            crnt_grant              <= #TP next_grant ;
        end
    end



// ---------------------------------------
// L0p EI OS trigger
// ---------------------------------------

// EI OS Request
    always_comb begin
        ei__os_l0p_req      = ~crnt_l0p_grant[G_EI_BIT] &     
                              (ltssm_l0p_cmd == `SEND_EIDLE) ;                  // Requested from LTSSM
    end

// ---------------------------------------
// E-IDLE request trigger 
// ---------------------------------------

// EDS Token Request
    always_comb begin
        eidle_l0p_req         =   crnt_l0p_grant[G_EI_BIT]                             // After E-IDLE OS
                              |   l0p_lane_updw_end_by_recovery                        // Go to recovery during negotiation
                              |   crnt_l0p_state[L0P_IDLE_BIT] ;                       // L0p IDLE
    end
    
    
// ---------------------------------------
// L0p EIE OS trigger
// ---------------------------------------
// TS Counter
    always @(posedge core_clk or negedge core_rst_n) begin : eie_interval_l0p_count_PROC
        if (!core_rst_n) begin
            eie_interval_l0p_count              <= #TP '0 ;
            eie_interval_l0p_req                <= #TP '0 ;
        end
        else if( ~crnt_l0p_state[L0P_UPSIZING_BIT]  ) begin                   // TS1/2 phase for upsizing
            eie_interval_l0p_count              <= #TP '0 ;
            eie_interval_l0p_req                <= #TP '0 ;
        end
        else if( crnt_l0p_grant[G_EIE_BIT] && l0p_os_send_done ) begin
            eie_interval_l0p_count              <= #TP '0 ;
            eie_interval_l0p_req                <= #TP '0 ;
        end
        else if( (crnt_l0p_grant[G_TS1_BIT] || crnt_l0p_grant[G_TS2_BIT]) && l0p_os_send_done ) begin  
               eie_interval_l0p_count              <= #TP 
                                                                      $bits(eie_interval_l0p_count)'(eie_interval_l0p_count + 1'b1) ;
 
            if( next_l0p_grant[G_TS1_BIT] || next_l0p_grant[G_TS2_BIT] ) begin   // Next OS is 32th TS case (Not SKP inserted)
                eie_interval_l0p_req                <= #TP
                                                                          (   (eie_interval_l0p_count + 1'b1) ==  5'd31 ) ;
            end
        end
        else if( (next_l0p_grant[G_TS1_BIT] || next_l0p_grant[G_TS2_BIT]) && l0p_os_send_done ) begin     // Current OS is SKP , Next OS is 32th TS
                eie_interval_l0p_req                <= #TP
                                                                          (eie_interval_l0p_count ==  5'd31) ;
        end
        else begin
            eie_interval_l0p_req                <= #TP 1'b0 ;
        end
    end
    
// EIE OS Trriger (pulse)
    always_comb begin
        eie_req_l0p_pulse      =     crnt_rate.eq_or_higher[GEN2_BIT] & 
                                 (   l0p_lane_upsizing_start                                                                        // 1st EIEOS
                                   | eie_interval_l0p_req )                                                                         // EIEOS is sent every 32 TS0/1/2 or FTS.
                                   ;
    end


// Latched EIE OS request 
    always @(posedge core_clk or negedge core_rst_n) begin : eie_req_l0p_latch_PROC
        if (!core_rst_n) begin
            eie_req_l0p_latch              <= #TP '0 ;
        end
        else if( ~next_l0p_state[L0P_UPSIZING_BIT] ) begin
            eie_req_l0p_latch              <= #TP '0 ;
        end
        else if( next_l0p_grant[G_EIE_BIT] ) begin                                        // not lathc
            eie_req_l0p_latch              <= #TP 1'b0 ;
         end
        else if(   eie_req_l0p_pulse 
               || (crnt_l0p_grant[G_EIE_BIT] & ~l0p_ossq_send_done & next_l0p_grant[G_SKP_BIT])                  // SKP interrupte during EIOSSQ. Re-start EIEOS in this case.(from Spec4.2.6.7)
               ) begin                                            // latch
            eie_req_l0p_latch              <= #TP 1'b1 ;
        end
    end


// EI OS request
    always_comb begin
        eie_os_l0p_req       = (eie_req_l0p_pulse | eie_req_l0p_latch) & ~l0p_lane_upsizing_end ;                    // Each request
    end


// ---------------------------------------
// L0p SDS OS trigger
// ---------------------------------------

// Create SDS insertion timing (before inteval period SKP OS)

    // Block count in a flit
    always @(posedge core_clk or negedge core_rst_n) begin : flit_block_count_PROC
        if (!core_rst_n) begin
            flit_block_count              <= #TP '0 ;
        end
        else if( ~crnt_l0p_state[L0P_UPSIZING_BIT] || (xdlh_xmlh_eof && last_chunk) ) begin
            flit_block_count              <= #TP '0 ;
        end
        else if( l0p_os_send_done ) begin
            flit_block_count              <= #TP 
                                                             $bits(flit_block_count)'(flit_block_count + 1'b1) ;
         end
    end

    // Insertion Block number
    always @(posedge core_clk or negedge core_rst_n) begin : sds_insert_block_num_PROC
        if (!core_rst_n) begin
            sds_insert_block_num              <= #TP '0 ;
        end
        else begin
            case ( { crnt_rate.one_hot[GEN6_BIT] , int_data_smlh_link_mode } )
                                                      //  This signal idnicats what number block in the Flit that SDS should be requested before preodical SKP OS (0's base)
                                    { 1'b0 , 6'd1  } : sds_insert_block_num  <= #TP 4'd14 ;                       // Not Gen6/x1  , SDS is 1block  / 1Flit=16Block / 15th block in the Last Flit before SKP
     { 1'b0 , 6'd2  } : sds_insert_block_num  <= #TP 4'd6 ;             // Not Gen6/x2  , SDS is 1block  / 1Flit= 8Block /  7th block in the Last Flit before SKP
     { 1'b0 , 6'd4  } : sds_insert_block_num  <= #TP 4'd2 ;             // Not Gen6/x4  , SDS is 1block  / 1Flit= 4Block /  3th block in the Last Flit before SKP
     { 1'b0 , 6'd8  } : sds_insert_block_num  <= #TP 4'd0 ;             // Not Gen6/x8  , SDS is 1block  / 1Flit= 2Block /  1st block in the Last Flit before SKP
             // Not Gen6/x16 , SDS is 1block  / 1Flit= 1Block /  1st block in the 2nd from Last Flit before SKP
                                    { 1'b1 , 6'd1  } : sds_insert_block_num  <= #TP 4'd13 ;                       //     Gen6/x1  , SDS is 2blocks / 1Flit=16Block / 14th block in the Last Flit before SKP
     { 1'b1 , 6'd2  } : sds_insert_block_num  <= #TP 4'd5 ;             //     Gen6/x2  , SDS is 2blocks / 1Flit= 8Block / 16th block in the Last Flit before SKP
     { 1'b1 , 6'd4  } : sds_insert_block_num  <= #TP 4'd1 ;             //     Gen6/x4  , SDS is 2blocks / 1Flit= 4Block /  2nd block in the Last Flit before SKP
     { 1'b1 , 6'd8  } : sds_insert_block_num  <= #TP 4'd1 ;             //     Gen6/x8  , SDS is 2blocks / 1Flit= 2Block /  2nd block in the 2nd from Last Flit before SKP
             //     Gen6/x16 , SDS is 2blocks / 1Flit= 1Block /  1st block in the 3rd from Last Flit before SKP
                                    default          : sds_insert_block_num  <= #TP 4'd0 ;                        // Never met this condition
            endcase
        end
    end
    
    // SDS insertin timing
    always_comb begin
        sds_insert_timing = '0 ;
        if( flit_block_count == sds_insert_block_num ) begin
            if(  crnt_rate.one_hot[GEN6_BIT] ) begin
                sds_insert_timing = 
                                     int_data_smlh_link_mode[3] ? last_flit_pcie_pre  :     // For x8  Gen6    / SDS is requested in the 2nd from Last Flit before SKP
                                                                  last_flit_pcie ;          // For x1/2/4 Gen6 / SDS is requested in the Last Flit before SKP
            end
            else if(crnt_rate.enc_128b130b ) begin
                sds_insert_timing = 
                                                                  last_flit_pcie ;          // For x1/2/4/8 Not Gen6 / SDS is requested in the Last Flit before SKP
            end
        end
    end

    // SDS insertin is done
    always @(posedge core_clk or negedge core_rst_n) begin : l0p_upsizing_sds_done_PROC
        if (!core_rst_n) begin
            l0p_upsizing_sds_done       <= #TP '0 ;
        end
        else if( ~crnt_l0p_state[L0P_UPSIZING_BIT] )  begin
            l0p_upsizing_sds_done       <= #TP '0 ;
        end
        else if(  ( ~crnt_rate.eq_or_higher[GEN3_BIT] && (ltssm_l0p_cmd == `SEND_IDLE)) 
               || crnt_l0p_grant[G_SDS_BIT]                                               ) begin
            l0p_upsizing_sds_done       <= #TP 1'b1 ;
        end
    end

// SDS OS request (just one chance to send SDS. That is before SKP OS.)
    always_comb begin
        sds_os_l0p_req   = crnt_rate.eq_or_higher[GEN3_BIT] 
                         & crnt_l0p_state[L0P_UPSIZING_BIT] & (ltssm_l0p_cmd == `SEND_IDLE)               // TS2 sending is completed.
                         & sds_insert_timing ;                                                            // Indicates the Datablock before SKP insertion.
    end

// ---------------------------------------
// L0p SKP OS trigger
// ---------------------------------------

// SKP OS request (Shall send SKP OS with DataStream lanes at the same time)
    always_comb begin
        skp_os_l0p_req          = crnt_l0p_state[L0P_UPSIZING_BIT] & skp_os_req & arb_time ;                             // Periodically interval for PCIe Flit
    end

// ---------------------------------------
// L0p TS1 OS trigger
// ---------------------------------------

// Sending TS1 OS for L0p. This is timining adjustment with Recovery entry when upsizing
    always @(posedge core_clk or negedge core_rst_n) begin : l0p_ts1_sending_extension_PROC
        if (!core_rst_n) begin
            l0p_ts1_sending_extension        <= #TP '0 ;
        end 
        else if( ~next_l0p_state[L0P_UPSIZING_BIT] || ts2_os_l0p_req ) begin
            l0p_ts1_sending_extension        <= #TP '0 ;
        end
        else if( ltssm_l0p_cmd == `SEND_TS1 ) begin
            l0p_ts1_sending_extension        <= #TP 1'b1 ;
        end
    end

// TS1 OS request
    always_comb begin
        ts1_os_l0p_req          = crnt_l0p_state[L0P_UPSIZING_BIT] 
                                & ( (ltssm_l0p_cmd == `SEND_TS1) | l0p_ts1_sending_extension ) ;                            // Request from LTSSM

        ts1_sending_req_l0p     = ts1_os_l0p_req ;
    end

// ---------------------------------------
// L0p TS2 OS trigger
// ---------------------------------------

// Sending TS1 OS for L0p. This is timining adjustment with Recovery entry when upsizing
    always @(posedge core_clk or negedge core_rst_n) begin : l0p_l0p_ts2_sending_extension_PROC
        if (!core_rst_n) begin
            l0p_ts2_sending_extension        <= #TP '0 ;
        end 
        else if( ~next_l0p_state[L0P_UPSIZING_BIT] ) begin
            l0p_ts2_sending_extension        <= #TP '0 ;
        end
        else if( ltssm_l0p_cmd == `SEND_TS2 ) begin
            l0p_ts2_sending_extension        <= #TP 1'b1 ;
        end
    end
    
// TS2 OS request
    always_comb begin
        ts2_os_l0p_req          =  crnt_l0p_state[L0P_UPSIZING_BIT] 
                                & ( (ltssm_l0p_cmd == `SEND_TS2) | l0p_ts2_sending_extension )                          // Request from LTSSM
                                & ~l0p_lane_upsizing_end ;

        ts2_sending_req_l0p     = ts2_os_l0p_req ;
    end


// ---------------------------------------
//  Grant signals for L0p 
// ---------------------------------------

// Next Grant
    always_comb begin
        next_l0p_grant = crnt_l0p_grant ;
        if( l0p_arb_time ) begin             // Grant is changed if arb_time is asserted
                  if( eidle_l0p_req     ) next_l0p_grant  = G_EIDLE ;
            else  if( skp_os_l0p_req    ) next_l0p_grant  = G_SKP_OS ;
            else  if( sds_os_l0p_req    ) next_l0p_grant  = G_SDS_OS ;
            else  if( ei__os_l0p_req    ) next_l0p_grant  = G_EI_OS ;
            else  if( eie_os_l0p_req    ) next_l0p_grant  = G_EIE_OS ;
            else  if( ts2_os_l0p_req    ) next_l0p_grant  = G_TS2_OS ;
            else  if( ts1_os_l0p_req    ) next_l0p_grant  = G_TS1_OS ;
            else                          next_l0p_grant  = G_EIDLE ;
        end
    end

// Current Grant
    always @(posedge core_clk or negedge core_rst_n) begin : crnt_l0p_grant_PROC
        if (!core_rst_n) begin
            crnt_l0p_grant              <= #TP G_EIDLE ;
        end
        else begin
            crnt_l0p_grant              <= #TP next_l0p_grant ;
        end
    end


// ---------------------------------------
// Output Data path
// ---------------------------------------

    // TxStartBlock
    always @(posedge core_clk or negedge core_rst_n) begin : xmtbyte_txstartblock_PROC
        if (!core_rst_n) begin
            xmtbyte_txstartblock          <= #TP '0 ;
        end
        else begin
            for( int ii = 0 ; ii < NL ; ii++ ) begin
                xmtbyte_txstartblock[ii][0]   <= #TP int_txstartblock ;
            end
        end
    end

    // Data valid
    always @(posedge core_clk or negedge core_rst_n) begin : xmtbyte_txdata_dv_PROC
        if (!core_rst_n) begin
            xmtbyte_txdata_dv          <= #TP '0 ;
        end
        else begin
            xmtbyte_txdata_dv          <= #TP internal_txdata_dv ;
        end
    end

    // Selector
    always_comb begin
        crnt_grant_is_os                     = crnt_grant[G_EI_BIT]  | crnt_grant[G_EIE_BIT] | crnt_grant[G_EIE_8SYM_BIT] | crnt_grant[G_SKP_BIT] 
                                             | crnt_grant[G_SDS_BIT] | crnt_grant[G_TS0_BIT] | crnt_grant[G_TS1_BIT]      | crnt_grant[G_TS2_BIT]
                                             | crnt_grant[G_FTS_BIT] ;
        
        crnt_grant_is_data                   = crnt_grant[G_EDS_BIT] | crnt_grant[G_DATA_BIT] ;

        crnt_grant_is_cmp                    = crnt_grant[G_CMP_BIT] | crnt_grant[G_MCMP_BIT] ;

        crnt_grant_is_l0p_os                 = crnt_l0p_grant[G_EI_BIT]  | crnt_l0p_grant[G_EIE_BIT] | crnt_l0p_grant[G_SKP_BIT] 
                                             | crnt_l0p_grant[G_SDS_BIT] | crnt_l0p_grant[G_TS1_BIT] | crnt_l0p_grant[G_TS2_BIT] ;
    end

    // Data mux
    always @(posedge core_clk or negedge core_rst_n) begin : xmtbyte_txdata_PROC
        if (!core_rst_n) begin
            for( int ii = 0 ; ii < NL ; ii++ ) begin
                xmtbyte_txdata[ii]           <= #TP '0 ;
                xmtbyte_txdatak[ii]          <= #TP '0 ;
                xmtbyte_ossending[ii]        <= #TP '0 ;
                xmtbyte_skp_os_align_sts[ii] <= #TP P_SKP_REPLACE_IDLE ;
            end
        end
        else begin
            for( int ii = 0 ; ii < NL ; ii++ ) begin
                if( int_data_ltssm_lanes_active[ii] && ~int_txelecidle[ii] ) begin
                    if( crnt_grant_is_data )  begin         // TLP/DLLP Data
                         xmtbyte_txdata[ii]              <= #TP data_gen_data[ii] ;
                         xmtbyte_txdatak[ii]             <= #TP data_gen_datak[ii] ;
                         xmtbyte_ossending[ii]           <= #TP '0 ;
                         xmtbyte_skp_os_align_sts[ii]    <= #TP P_SKP_REPLACE_IDLE ;
                    end    
                    else if( crnt_grant_is_os )  begin           // OrderSet Data
                            xmtbyte_txdata[ii]              <= #TP os_gen_data[ii] ;
                            xmtbyte_txdatak[ii]             <= #TP os_gen_datak[ii] ;
                            xmtbyte_ossending[ii]           <= #TP os_gen_ossending[ii] ;
                            xmtbyte_skp_os_align_sts[ii]    <= #TP os_gen_skp_os_align_sts ;
                    end    
                    else if( crnt_grant_is_cmp )  begin          // Compliance pattern
                            xmtbyte_txdata[ii]              <= #TP cmp_gen_data[ii] ;
                            xmtbyte_txdatak[ii]             <= #TP cmp_gen_datak[ii] ;
                            xmtbyte_ossending[ii]           <= #TP cmp_gen_ossending[ii] ;
                            xmtbyte_skp_os_align_sts[ii]    <= #TP P_SKP_REPLACE_IDLE ;
                    end    
                    else begin
                            xmtbyte_txdata[ii]              <= #TP '0 ;
                            xmtbyte_txdatak[ii]             <= #TP '0 ;
                            xmtbyte_ossending[ii]           <= #TP '0 ;
                            xmtbyte_skp_os_align_sts[ii]    <= #TP P_SKP_REPLACE_IDLE ;
                    end    
                end
                else if( int_l0p_ltssm_lanes_active[ii] && ~int_txelecidle[ii] ) begin
                         if( crnt_grant_is_l0p_os )  begin      // OrderSet Data
                            xmtbyte_txdata[ii]              <= #TP os_gen_data_l0p[ii] ;
                            xmtbyte_txdatak[ii]             <= #TP os_gen_datak_l0p[ii] ;
                            xmtbyte_ossending[ii]           <= #TP os_gen_ossending_l0p[ii] ;
                            xmtbyte_skp_os_align_sts[ii]    <= #TP l0p_os_gen_skp_os_align_sts ;
                    end    
                    else begin
                            xmtbyte_txdata[ii]              <= #TP '0 ;
                            xmtbyte_txdatak[ii]             <= #TP '0 ;
                            xmtbyte_ossending[ii]           <= #TP '0 ;
                            xmtbyte_skp_os_align_sts[ii]    <= #TP P_SKP_REPLACE_IDLE ;
                    end    
                end
                else begin
                    xmtbyte_txdata[ii]                      <= #TP '0 ;
                    xmtbyte_txdatak[ii]                     <= #TP '0 ;
                    xmtbyte_ossending[ii]                   <= #TP '0 ;
                    xmtbyte_skp_os_align_sts[ii]            <= #TP P_SKP_REPLACE_IDLE ;
                end
            end
        end
    end


    // PIPE Control signals (aligned with data)
    always @(posedge core_clk or negedge core_rst_n) begin : data_aligned_pipe_cntrol_PROC
        if (!core_rst_n) begin
            data_aligned_txelecidle              <= #TP '1 ;
            data_aligned_txcompliance            <= #TP '0 ;
            data_aligned_loopback                <= #TP '0 ;
            xmtbyte_txdetectrx                   <= #TP '0 ;
        end
        else begin
            data_aligned_txelecidle              <= #TP int_txelecidle ;
            data_aligned_txcompliance            <= #TP int_txcompliance ;
            data_aligned_loopback                <= #TP lpbk_follwer_act_exit ;                       // Loopback follower
            xmtbyte_txdetectrx                   <= #TP (ltssm_cmd_i == `SEND_RCVR_DETECT_SEQ) ;      // Receiver Detection 
        end
    end
    
// TxDetectLoopback (Detail timing adjustment is handled in xmlh_pipe.sv like phy_status handshake etc)
    always_comb begin
            xmtbyte_txdetectrx_loopback          = xmtbyte_txdetectrx | xmtbyte_loopback ;
    end

// ---------------------------
//  PIPE Control signals
// ---------------------------

// TxElecidle
    // smlh_ltssm_state is `XMT_IN_EIDLE when Loopback.Active follower. This is from original logic.
    always @(posedge core_clk or negedge core_rst_n) begin : lpbk_active_follower_eidle_lat_PROC
        if (!core_rst_n) begin
            lpbk_active_follower_eidle_lat              <= #TP '0 ;
        end
        else if( lpbk_active_follower_eidle_set ) begin
            lpbk_active_follower_eidle_lat              <= #TP 1'b1 ;
        end
        else if( lpbk_follwer_act_exit_2d && ~lpbk_follwer_act_exit_1d ) begin
            lpbk_active_follower_eidle_lat              <= #TP 1'b0 ;
        end
    end

    always_comb begin
        lpbk_active_follower_eidle_set  = ( ltssm_cmd_i == `XMT_IN_EIDLE ) & ( lpbk_follwer_act_exit )
                                        & crnt_rate.eq_or_higher[GEN5_BIT] & ( |ltssm_lpbk_slave_lut ) ;
                                        
        lpbk_active_follower_eidle      = lpbk_active_follower_eidle_set | lpbk_active_follower_eidle_lat ;
    end
    
    // Base Txelecidle. This signal is align with output data(xmtbyte_txdata,xmtbyte_txdatak)
    always @(posedge core_clk or negedge core_rst_n) begin : int_txelecile_g3_txdatavalid_sync_PROC
        if (!core_rst_n) begin
            int_txelecile_g3_txdatavalid_sync              <= #TP '0 ;
        end
        else if( crnt_rate.enc_128b130b && ~ltssm_cxl_sh_bypass ) begin
            if( internal_txdata_dv &&
               (int_data_ltssm_lanes_active < int_data_ltssm_lanes_active_pre) 
                         &&  ~crnt_stream[DATA_STREAM_BIT]
                                                                                                      ) begin   // Upconfigrure when Gen3/4/5
                int_txelecile_g3_txdatavalid_sync              <= #TP int_txelecidle ;
            end
            else if( ~internal_txdata_dv ) begin
                int_txelecile_g3_txdatavalid_sync              <= #TP '0 ;
            end
        end
        else begin
            int_txelecile_g3_txdatavalid_sync              <= #TP '0 ;
        end
    end
    
    
    always_comb begin
        for( int ii = 0 ; ii < NL ; ii++ ) begin
            int_txelecidle[ii] = 1'b1 ;
            if( ~crnt_l0p_grant[G_EIDLE_BIT] &&  int_l0p_ltssm_lanes_active[ii] & ~int_data_ltssm_lanes_active[ii]  )  int_txelecidle[ii] = 1'b0  ;                               // L0p Upsizing Lane
            if( ~crnt_grant[G_EIDLE_BIT]     &&  int_data_ltssm_lanes_active[ii] )                                     int_txelecidle[ii] = 1'b0  ;                               // Not E-dle and Lane is active
            if( ~crnt_grant[G_EIDLE_BIT]     &&  int_txelecile_g3_txdatavalid_sync[ii] )                               int_txelecidle[ii] = 1'b1  ;                               // Not E-dle and Lane is active
            if( lpbk_active_follower_eidle                                             )                               int_txelecidle[ii] = ~ltssm_lpbk_slave_lut[ii]  ;          // Loopback slave with Enhanced Link Behavior Control == 01b this is from original design
        end
    end




// Delayed Txelecidle/TxDetectloopback and Txcompliance. These signal should be aligned with scrambled data(output signalas of scrambler.) Because some latency in scramble module. 
// But, these are not input scramble module but connect to xmlh_pipe.sv directly. So should be added some latency in this module.
     
     localparam N_DELAY_CYLES_G12      = `CX_XMLH_SCRAMBLE_REGOUT;
     localparam N_DELAY_CYCLES_G3      = `CX_XMLH_GEN3_SCRAMBLE_LFSR_REGOUT
                                       + `CX_XMLH_GEN3_SCRAMBLE_REGIN 
                                       + `CX_XMLH_GEN3_SCRAMBLE_REGOUT - N_DELAY_CYLES_G12 
                                       + `CX_XMLH_PRECODING_REGOUT 
                                       + `CX_XMLH_GLAYCODING_REGOUT
                                       ;
    localparam SIG_WIDTH               =   $bits(xmtbyte_loopback)      + $bits(xmtbyte_txcompliance)      + $bits(xmtbyte_txelecidle) ;
    localparam RESET_VALUE             = { $bits(xmtbyte_loopback)'('0) , $bits(xmtbyte_txcompliance)'('0) , $bits(xmtbyte_txelecidle)'('1) } ;
    localparam SIG_WIDTH_EI            =   $bits(xmtbyte_txelecidle) ;
    localparam RESET_VALUE_EI          = { $bits(xmtbyte_txelecidle)'('1) } ;
    localparam SIG_WIDTH_CMP_LPBK      =   $bits(xmtbyte_loopback)      + $bits(xmtbyte_txcompliance)      ;
    localparam RESET_VALUE_CMP_LPBK    = { $bits(xmtbyte_loopback)'('0) , $bits(xmtbyte_txcompliance)'('0) } ;


    // For Gen1/2 delay
    delay_n
     #(N_DELAY_CYLES_G12, SIG_WIDTH, RESET_VALUE) pipe_ctl_sig_delay_g12(
      .clk        (core_clk)
    , .rst_n      (core_rst_n)
    , .clear      (1'b0)
    , .din        ({data_aligned_loopback , data_aligned_txcompliance , data_aligned_txelecidle} )
    , .dout       ({g12_loopback , g12_txcompliance , g12_txelecidle} )
    );  

generate
     if (N_DELAY_CYCLES_G3 > 0) begin : gen_delay_txelecidle_1
        // For Gen3 delay (1cycle befoer of outputs)
        delay_n
         #((N_DELAY_CYCLES_G3 -1), SIG_WIDTH_EI, RESET_VALUE_EI) pipe_ctl_sig_delay_g3_ei_pre(
          .clk        (core_clk)
        , .rst_n      (core_rst_n)
        , .clear      (1'b0)
        , .din        (   g12_txelecidle     )
        , .dout       ( g3orh_txelecidle_pre )
        );  

        // For Gen3 delay (Last 1 cycle)
        delay_n
         #( 1 , SIG_WIDTH_EI, RESET_VALUE_EI) pipe_ctl_sig_delay_g3_ei(
          .clk        (core_clk)
        , .rst_n      (core_rst_n)
        , .clear      (1'b0)
        , .din        ( g3orh_txelecidle_pre )
        , .dout       ( g3orh_txelecidle     )
        );  
    end
    else begin
        always_comb begin
            g3orh_txelecidle_pre = (N_DELAY_CYLES_G12 == '0) ? int_txelecidle : data_aligned_txelecidle ; // N_DELAY_CYLES_G12 is 0 or 1. Need to update if new PIPE-line is added for Gen1/2 scrambler.
            g3orh_txelecidle     = g12_txelecidle ;
        end
    end
endgenerate

        // For Gen3 delay
        delay_n
         #( N_DELAY_CYCLES_G3, SIG_WIDTH_CMP_LPBK, RESET_VALUE_CMP_LPBK) pipe_ctl_sig_delay_g3_cmp_lpbk(
          .clk        (core_clk)
        , .rst_n      (core_rst_n)
        , .clear      (1'b0)
        , .din        ({  g12_loopback     ,   g12_txcompliance } )
        , .dout       ({g3orh_loopback     , g3orh_txcompliance } )
        );  


    // output signals
    always_comb begin
        xmtbyte_txelecidle              = crnt_rate.eq_or_higher[GEN3_BIT] ? g3orh_txelecidle          : g12_txelecidle ;
        xmtbyte_txcompliance            = crnt_rate.eq_or_higher[GEN3_BIT] ? g3orh_txcompliance        : g12_txcompliance ;
        xmtbyte_loopback                = crnt_rate.eq_or_higher[GEN3_BIT] ? g3orh_loopback            : g12_loopback ;
    end


// ---------------------------
//  Other output signals
// ---------------------------
   
    always_comb begin


        // deassert loopback signal at gen5 rate in LPBK_EXIT_TIMEOUT
        xmtbyte_g5_lpbk_deassert               = crnt_rate.eq_or_higher[GEN5_BIT] & (&g3orh_txelecidle_pre) & (smlh_ltssm_state == S_LPBK_EXIT_TIMEOUT);

        // start of flit
        xplh_xmlh_sof                          = xdlh_xmlh_sof & ~xmtbyte_xdlh_halt_o & ltssm_flit_mode_enable ;

    end
    
        // Indicates byte machine is sending training sequences or compliance pattern
    always @(posedge core_clk or negedge core_rst_n) begin : xmtbyte_link_in_training_PROC
        if (!core_rst_n) begin
            xmtbyte_link_in_training   <= #TP '0;
        end 
        else begin
            xmtbyte_link_in_training   <= #TP crnt_grant[G_CMP_BIT] 
                                            | crnt_grant[G_MCMP_BIT] 
                                            | crnt_grant[G_EIE_BIT] 
                                            | crnt_grant[G_TS0_BIT] 
                                            | crnt_grant[G_TS1_BIT] 
                                            | crnt_grant[G_TS2_BIT] ;
        end 
    end 

        // Indicates byte machine is sending training sequences or compliance pattern
    always @(posedge core_clk or negedge core_rst_n) begin : xmtbyte_l0p_link_in_training_PROC
        if (!core_rst_n) begin
            xmtbyte_l0p_link_in_training   <= #TP '0;
        end 
        else if( crnt_rate.enc_8b10b ) begin
            xmtbyte_l0p_link_in_training   <= #TP crnt_l0p_grant[G_EIE_BIT] 
                                                | crnt_l0p_grant[G_SKP_BIT] 
                                                | crnt_l0p_grant[G_TS1_BIT] 
                                                | crnt_l0p_grant[G_TS2_BIT] ;
        end 
    end 

   // Indicates L0p upsizing netogiation is in progress. This is for Flit Performance mesurement.
    always @(posedge core_clk or negedge core_rst_n) begin : xmtbyte_l0p_state_in_upsize_PROC
        if (!core_rst_n) begin
            xmtbyte_l0p_state_in_upsize   <= #TP '0;
        end 
        else if( !next_l0p_state[L0P_UPSIZING_BIT] ) begin
            xmtbyte_l0p_state_in_upsize   <= #TP '0;
        end 
        else if( l0p_lane_upsizing_start ) begin
            xmtbyte_l0p_state_in_upsize   <= #TP 1'b1;
        end
    end 
    
    // xmtbyte_ltssm_in_compliance is just one cycle delay of ltssm_in_compliance. This is from original design.
    always @(posedge core_clk or negedge core_rst_n) begin : xmtbyte_ltssm_in_compliance_PROC
        if (!core_rst_n) begin
            xmtbyte_ltssm_in_compliance <= #TP '0;
        end 
        else begin
            xmtbyte_ltssm_in_compliance <= #TP ltssm_in_compliance ;
        end 
    end 
    
    

    // transmit STP in multiple cycles, xmtbyte_xdlh_halt must deassert after the STP completes
    //      ___________________________________________________________________
    // prog |                       
    // ------                      
    // ________________________________________________________________________
    //      | STP0      | STP0      | STP0      |          | STP1      | STP1
    // ------------------------------------------------------------------------
    //      _________________________                      ____________________
    // halt |                       | gap                  |
    // ------                       ------------------------
    assign stp_in_progress = |xdlh_xmlh_stp_i & in_tdlp_progress_nonflit & in_data_progress & crnt_grant[G_DATA_BIT] & xmtbyte_xdlh_halt_o;

    always @( posedge core_clk or negedge core_rst_n ) begin : stp_in_progress_d_PROC
        if ( ~core_rst_n ) begin
            stp_in_progress_d <= #TP '0;
            xdlh_xmlh_eof_d   <= #TP '0;
        end 
        else begin
            stp_in_progress_d <= #TP stp_in_progress;
            xdlh_xmlh_eof_d   <= #TP xdlh_xmlh_eof ;
        end
    end // stp_in_progress_d_PROC

    // for Txing STP in single cycle formula, ~stp_in_progress_d is used to fill the "halt gap" for multi-cycle in the figure above
    // because Txing STP in single cycle uses ~xmtbyte_xdlh_halt.
    assign xmtbyte_stp_start =
                                ltssm_flit_mode_enable ? (xdlh_xmlh_eof_d & ~xdlh_xmlh_eof) :                                                       // use flit_eof falling edge for the PTM marker sent, use EOF but not SOF
                               (stp_in_progress & ~stp_in_progress_d) ||                                                                            //Txing STP in multi-cycle
                               (|xdlh_xmlh_stp_i & in_tdlp_progress_nonflit & crnt_grant[G_DATA_BIT] & ~xmtbyte_xdlh_halt_o & ~stp_in_progress_d);  //Txing STP in single cycle


    always @( posedge core_clk or negedge core_rst_n ) begin : flit_sds_skp_in_progress_PROC
        if ( ~core_rst_n ) begin
            flit_sds_skp_in_progress <= #TP '0;
        end 
        else if( next_grant[G_SDS_BIT] ) begin
            flit_sds_skp_in_progress <= #TP 1'b1;
        end
        else if( next_grant[G_DATA_BIT] ) begin
            flit_sds_skp_in_progress <= #TP 1'b0;
        end
    end 
 
    // For Flit Performance Mesurement
    always_comb begin
        xmbyte_flit_data_stream = crnt_stream[DATA_STREAM_BIT] & ~flit_sds_skp_in_progress & ltssm_flit_mode_enable ;
    end

// PIPE interface SRISEnable. 
// Follow the PIPE Spec 6.1.1 SRISEnable rule.
// Default 1b.
// SRISEnable is updated to the SRIS_Mode_Enabled’s value after Configuration.Lanenum.Accept state (Configuration.Complete) or Polling.Compliance state.
// SRISEnable is updated to the TS1 negotiation result when ltssm_in_lpbkentry.
    always @(posedge core_clk or negedge core_rst_n) begin : xmtbyte_sris_enabled_PROC
        if (!core_rst_n) begin
            xmtbyte_sris_enable <= #TP 1'b1;
        end 
        else if (((smlh_ltssm_state == S_CFG_COMPLETE) || ((ltssm_in_compliance || ltssm_in_lpbkentry) && ~ltssm_clear)) && ~smlh_link_up) begin // ~ltssm_clear is used here because xmtbyte_sris_mode_enabled is updated when ltssm_clear==1b for Polling.Compliance or Loopback.Entry state entry. sris_mode_enabled is never changed once updated.
            xmtbyte_sris_enable <= #TP xmtbyte_sris_mode_enabled;
        end 
    end // xmtbyte_sris_enabled_PROC

















endmodule
