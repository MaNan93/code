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
// ---    $Id: //dwh/pcie_iip/main/fairbanks/design/Layer1/xmlh_byte_xmt_top.sv#4 $
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

 
 module xmlh_byte_xmt_top 
  import xmlh_pkg::*;
  import DWC_pcie_core_pkg::ltssm_state_e;
  import DWC_pcie_core_pkg::S_RCVRY_LOCK;
  import DWC_pcie_core_pkg::S_LPBK_ENTRY;
  import DWC_pcie_core_pkg::S_LPBK_ACTIVE;
  import DWC_pcie_core_pkg::S_LPBK_EXIT;
  import DWC_pcie_core_pkg::S_RCVRY_EQ0;
  import DWC_pcie_core_pkg::S_RCVRY_EQ1;
  import DWC_pcie_core_pkg::xmlh_einj_in_os_t;
    #(
      parameter int  INST = 0
    ) 
  
                           ( 
// =============================================================================
//  Clock/Reset
// =============================================================================

      input  logic                                     core_clk 
    , input  logic                                     core_rst_n 
    , input  logic                                     sticky_rst_n

// =============================================================================
//  input  logicIO Declarations
// =============================================================================

// Received TLP/DLLP Data Path from Layer2 
    , input  logic                                     xdlh_xmlh_eof                          // Indicates End of Flit 
    , input  logic                                     xdlh_xmlh_sof                          // Indicates Start of Flit 
    , input  logic  [NW-1 :0]                          xdlh_xmlh_stp_i                        // Indicates Start of TLP (1 bit per dword)
    , input  logic  [NW-1 :0]                          xdlh_xmlh_sdp_i                        // Indicates Start of DLLP (1 bit per dword)
    , input  logic  [NW-1 :0]                          xdlh_xmlh_eot_i                        // Indicates End of TLP or DLLP (1 bit per dword)
    , input  logic  [NW-1 :0]                          next_xdlh_xmlh_eot_i                   // 1cycle before of xdlh_xmlh_eot_i
    , input  logic  [NW-1 :0]                          xdlh_xmlh_pad_i                        // Indicates Pad (1 bit per dword)
    , input  logic  [NW-1 :0]                          next_xdlh_xmlh_stp_i                   // 1cycle before of xdlh_xmlh_stp_i
    , input  logic  [NW-1 :0]                          next_xdlh_xmlh_sdp_i                   // 1cycle before of xdlh_xmlh_sdp_i
    , input  logic  [DW-1:0]                           xdlh_xmlh_data_i                       // TLP/DLLP Data
    , input  logic                                     xdlh_xmlh_pkt_pending_i                // XDLH has registered packet pending transmission in Non-Flit mode. When asserted, cannot send EIOS/EIEOS. (SKP can be sent)
    , input  logic                                     xmlh_fm_pending                        // Packet pending indication in Flit mode. When asserted, cannot send EIOS/EIEOS. (SKP can be sent), Flush is not completed.
    , input  logic                                     xfsh_xmlh_buf_empty                    // Indicate xfsh_buf empty
    , input  logic                                     xmlh_fm_flush_ack                      // Flush acknowledge in Flit mode. When deasserted, cannot send EIEOS. (SKP can be sent)
    , input  logic                                     xmlh_cmd_if_lp_ack                     // Low power entry acknowledge in Flit mode. When deasserted, cannot send EIOS. (SKP can be sent)
    , input  logic  [NW-1:0]                           xdlh_xmlh_pid                          // PID location per DW on xdlh_xmlh_data[511:0]. Valid only when CXL,

// Received sending OS/Compliance pattern request from LTSSM
    , input  logic  [3:0]                              ltssm_cmd_i                            // encoded command to notify transmitter of the proper action based on LTSSM states
    , input  logic  [2:0]                              ltssm_eidle_cnt                        // 4 bits, indicates how many EIOS sets to send before returning xmtbyte_eidle_sent.  0=1 EIOS, 1=2 EIOS, etc.
    , input  logic                                     ltssm_cmd_send_eieos_for_pset_map      // send eieos continuously for pset-coef mapping
    , input  logic  [NL-1:0]                           scramble_lfsr_rollover                 // LFSR value matches seed. Used for inserting EIEOS after a sequence of 65536 uninterrupted TS1s
    , input  logic  [1:0]                              cdm_ras_des_eidle_cnt_sel              // Number of Transmit E-IDLE ordered set for Ras D.E.S Silicon Debug
                                                                                              // 0x0 : (2.5GT/s,8.0GT/s or higher) 1 or (5.0GT/s ) 2
                                                                                              // 0x1 : (2.5GT/s,8.0GT/s or higher) 4 or (5.0GT/s ) 8
                                                                                              // 0x2 : (2.5GT/s,8.0GT/s or higher) 8 or (5.0GT/s ) 16
                                                                                              // 0x3 : (2.5GT/s,8.0GT/s or higher) 16 or (5.0GT/s ) 32
    , input  logic                                     smlh_l0p_update                        // L0p Up/Downsizning request (1shot)
    , input  logic [3:0]                               ltssm_l0p_cmd                          // encoded command to notify transmitter of the proper action based on LTSSM states
    , input  logic                                     ltssm_cmd_eqts0                        // Indicates TS0 should be sent. 
    , input  logic                                     eqctl_g6_tx_ts0                        // Indicates TS0 should be sent. tx ts0. dsp until 2 ts0s rcvd in eq2 with ec = 10b. usp until 2 ts1s rcvd in eq3 with ec = 11b

// Information to make OS
    , input  logic  [7:0]                              cfg_n_fts                              // 8bits bus to specify the number of FTS we wish to receive for our receiver. Set this value on TS Flit Mode bit(Symbol3 [7:0])
    , input  logic  [7:0]                              ltssm_xlinknum                         // 8bits indicate link number to be inserted in training sequence, if ltssm_xk237_4lnknum =0
    , input  logic  [NL-1:0]                           ltssm_xk237_4lnknum                    // 1 bit per lane, 1 : K237 / 0 : send link number(ltssm_xlinknum) of TS Symbol 1[7:0]
    , input  logic  [NL-1:0]                           ltssm_xk237_4lannum                    // 1 bit per lane, 1 : K237 / 0 : send lane number of TS Symbol 2[7:0]
    , input  logic  [7:0]                              ltssm_ts_cntrl                         // training sequence control. Set this value on TS Symbol5 [7:0]
    , input  logic                                     ltssm_mod_ts                           // Tx modified TS should be sent if 1.
    , input  logic                                     ltssm_ts_alt_protocol                  // Indicates Alternate protocol is used. Replace Modified TS Symbol8-14 to ltssm_ts_alt_prot_info if this signal is 1.
    , input  logic  [55:0]                             ltssm_ts_alt_prot_info                 // Value of Modified TS Symbol8-14, if Alternate Protocol 
    , input  logic                                     ltssm_ts_auto_change                   // autonomous change/upconfig capable/select de-emphasis bit.  Set this value on TS Symbol4 [6].
    , input  logic  [4:0]                              ltssm_ts_data_rate                     // Data rate to advertise support for in the ts.  bits 4:1 of the data rate identifier field.Set this value on TS Flit Mode bit(Symbol4 [5:1])
    , input  logic                                     ltssm_ts_speed_change                  // Value to put in the speed change bit of TS ordered sets.Set this value on TS Flit Mode bit(Symbol4 [7])
    , input  logic  [NL*EQTS_WD-1:0]                   eqctl_eqts_info                        // Equalization Information, Set this value on EQ TS Symbols 6-9 of EQ TSs for Gen3 or above.
    , input  logic  [NL*TS_0_WD-1:0]                   eqctl_eqts_info_ts0                    // Equalization Information for Symbols 1-4 of EQ TS0s
    , input  logic                                     ltssm_cmd_compliance_ts1               // sending two Compliance TS1 in Polling.Compliance  
    , input  logic  [7:0]                              ltssm_compliance_set_num               // sequence setting number for sending Compliance TS1 in Polling.Compliance
    , input  logic [NL*16-1:0]                         cfg_margin_control                     // Margining Control [2:0] Receiver Number[5:3]Margin Type[6]Usage Molde[7]Rsvd[15:8]Margin Payload. This value is Control SKP Symbol13-15 of Downstream Port
    , input  logic [NL*16-1:0]                         smlh_ctlskp_info                       // Margining Status  [2:0] Receiver Number[5:3]Margin Type[6]Usage Molde[7]Rsvd[15:8]Margin Payload. This value is Control SKP Symbol13-15 of Downstream Port
    , input  logic                                     ltssm_flit_mode                        // Indicates FLIT mode supporting. Set this value on TS1 Flit Mode bit(Symbol4 [0])

// Information to make Compliance Pattern              
    , input  logic  [3:0]                              ltssm_gen4_compliance_jmp              // Gen4 compliance setting# for Jitter Measurment Pattern for Gen3/4/5
                                                                                              // ltssm_gen4_compliance_jmp
                                                                                              //  4'b0001 | lane 0-15
                                                                                              //  4'b0010 | lane 0,8
                                                                                              //  4'b0011 | lane 1,2
                                                                                              //    --
                                                                                              //  4'b1000 | lane 6,14
                                                                                              //  4'b1001 | lane 7,15
    , input  logic  [3:0]                              ltssm_gen6_compliance_tp               // Gen6 compliance setting# for Toggle Pattern  
                                                                                              // High Swing Toggle Pattern
                                                                                              //  4'b0001 | lane 0-15
                                                                                              //  4'b0010 | lane 0,8
                                                                                              //  4'b0011 | lane 1,2
                                                                                              //    --
                                                                                              //  4'b1000 | lane 6,14
                                                                                              //  4'b1001 | lane 7,15
                                                                                              // Low Swing Toggle Pattern
                                                                                              //  4'b1010 | lane 0-15
    , input  logic [NL-1:0]                            smlh_mcs_rcvd                          // detected Modified Compliance Sequence. This is one of the value on Modified Compliance patter of ERR filed [7](Pattern Lock) Gen1/2
    , input  logic [NL-1:0]                            rpipe_rxerror                          // when asserted, RMLH indicates that the receiver has detected an rx disparity or code error. This is used Modifeied Complaince pattern of ERR field [6:0] (Receiver Error count) Gen1/2
    , input  logic  [NL*TX_PSET_WD-1:0]                eqctl_pset_ltx                         // Tx preset being used per lane. Set this value ofn Compliance Pattern 128b/130b
    , input  logic  [NL*8-1:0]                         smlh_gen3_error_count_i                // per lane version of gen3 Compliance error count. Set this value on SKP Error Status Field(Symbol14/15) when Polling.Compliance

// Return sedning OS response to LTSSM
    , input  logic                                     ltssm_clear                            // used to clear persistency count when a ltssm state transition
    , input  logic                                     ltssm_dsp_g6_eq1_send_ec00             // 1, dsp xmlh starts to send 24 ts0s with ec=00b in eq1. Clear xmtbyte_ts_cnt when posedge of this signal. Restart count xmtbyte_sent_24_ts0_ec00 when posedge of this signal.
    , input  logic                                     link_rx_ts0_to_ts1_pulse               // rx ts0 to ts1 transition
    , input  logic  [NL-1:0]                           eqctl_2mask_eieos_pulse                // 2 consecutive EC TS1 rcvd pulse with a request to reset EIEOS count

// Mode/State signals
    , input  logic                                     app_sris_mode_i                        // application signal to enable the SRIS mode
    , input  logic                                     ltssm_cxl_sh_bypass                    // SyncHeader_Bypass
    , input  logic                                     cxl_mode_enable                        // Indicates whether the link should operate in CXL or PCIe mode
    , input  logic                                     cfg_fast_link_mode                     // Indicates how many TS1 are sent in Polling.Active. 0:1024(Spec) / 1:16(to reduce SIM time)
    , input  ltssm_state_e                             smlh_ltssm_state                       // LTSSM State
    , input  ltssm_state_e                             smlh_ltssm_last                        // indicates last ltssm state (not 1cycle before)
    , input  logic  [NL-1:0]                           ltssm_lpbk_slave_lut                   // lane under test for lpbk slave for Gen5 and above Rate.
    , input  logic                                     cfg_flit_sris_clocking                 // Enable SRIS mode form LTSSM for Flit Mode
    , input  logic                                     cfg_comm_clk_config                    // Enable Common Clock(Non-SRIS) mode form LTSSM for Flit Mode
    , input  logic                                     ltssm_flit_mode_enable                 // Indicates Flit Mode is enabled.
    , input  logic                                     smlh_link_up                           // Indicates LTSSM is LinkUp
    , input  logic                                     smlh_usp_sris_mode                     // Indicates Upstream port SRIS is enabled from LTSSM.
    , input  logic  [10:0]                             cfg_skip_interval                      // the number of symbol times between skip requests. Just for Gen1/2 non-SRIS.
    , input  logic                                     cfg_ext_synch                          // Extended synch for N_FTS configured in CDM
    , input  logic                                     cfg_mod_ts                             // modified ts format. Not used
    , input  logic  [5:0]                              smlh_link_mode                         // 10000 -- x16, 01000 -- x8, 00100 -- x4, 00010 -- x2, 00001 -- x1
    , input  logic  [NL-1 :0]                          ltssm_lanes_active                     // LTSSM latched lanes that are active based on the link negotiation
    , input  logic                                     ltssm_ts_cnt_en_i                      // enable TS counting logic to transmit an EIEOS every 32 or 65536 TSs
    , input  logic                                     ltssm_ts_cnt_rst                       // reset TS1/TS2 count for EIEOS interval.
    , input  logic  [7:0]                              latched_ts_nfts                        // latched number of fast training sequence number from TS ordered set of receiver
    , input  logic                                     ltssm_in_lpbk                          // LTSSM in Loopback.Active state
    , input  logic                                     ltssm_in_lpbk_active                   // LTSSM in Loopback.Active state
    , input  logic  [NL-1:0]                           lpbk_eq_lanes_active                   // One active lane from the cfg_lane_under_test
    , input  logic                                     cfg_lpbk_en                            // Remote LOOPBACK enable
    , input  logic                                     cfg_prbs_en                            // PRBS LOOPBACK enable
    , input  logic  [NL-1 :0]                          smlh_no_turnoff_lanes                  // No turnoff lanes when some lanes are disabled
    , input  logic                                     ltssm_in_lpbkentry                     // LTSSM in Loopback.Entry state
    , input  logic                                     ltssm_usp_eq_redo                      // eq redo for usp, Not used
    , input  logic                                     ltssm_in_compliance                    // LTSSM in polling.compliance state
    , input  logic  [2:0]                              current_data_rate                      // 2'b00=running at gen1 speeds, 2'b01=running at gen2 speeds, 2'b10=running at gen3 speeds, 2'b11=running at gen4 speeds
    , input  logic                                     cfg_compliance_sos                     // Send skips during Compliance or Modified Compliance pattern Gen1/2
    , input  logic [4:0]                               latched_ts_data_rate                   // latched TS sequence data rate from partner. Not used
    , input  logic  [9:0]                              ltssm_ts_data_rate_eg6                 // convert >=gen6 to one-hot, bit[5] = 1b = gen6. Not used
    , input  logic  [9:0]                              latched_ts_data_rate_eg6               // convert >=gen6 to one-hot, bit[5] = 1b = gen6. Not used
    , input  logic  [NL-1:0]                           eqctl_mask_eieos                       // Mask EIEOS when Reqcovery.Equalization. Replaces EIEOS OS Identifier with TS1 OS Identifier
    , input  logic                                     lpbk_master                            // indicates that the ltssm is the loopback master
    , input  logic  [AW-1:0]                           active_nb                              // active number of symbols per lane per clock. bit0=1s, bit1=2s, bit2=4s, bit3=8s , bit4=16s
    , input  logic                                     cfg_upstream_port                      // 1: Upstream Port / 0:Downstream Port
    , input  logic                                     ltssm_in_rcvry_cfg_idle_g3             // LTSSM in Recovery.Idle or Configuration.Idle state. Not used
    , input  logic                                     ltssm_in_rcvry_cfg_idle                // LTSSM in Recovery.Idle or Configuration.Idle state. Not used
    , input  logic [5:0]                               smlh_l0p_link_mode                     // 10000 -- x16, 01000 -- x8, 00100 -- x4, 00010 -- x2, 00001 -- x1
    , input  logic [NL-1:0]                            ltssm_l0p_lanes_active                 // LTSSM latched lanes that are active based on the link negotiation
    , input  logic                                     ltssm_l0p_cmd_4_eieos_req              // 4 eieos request at gen6 rate


// =============================================================================
// output IO Declarations
// =============================================================================
// Received TLP/DLLP Data Path from Layer2 
    , output logic                                     xmtbyte_xdlh_halt_o                     // Halt the flow of data from the xdlh
    , output logic                                     xmlh_skip_pending                       // XMLH Skip pending to XDLH TLP GEN. Request to pause TLP/DLLP sending to Layer2. Assert for sending SKIP OS for Gen1/2/3/4/5 Non-Flit, because SKP is needed to send Packet boundary.
    , output logic                                     xmtbyte_cmd_is_data                     // xmtbyte state machine is waiting for packet start or packet end. Request to send TLP/DLLP to Layer2. Deassert for sending EIE/EI OS, because EIE/EI is needed to send Packet boundary.
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
    , output logic [10:0]                              xmtbyte_ts_pcnt                         // transmit ts persistency count
    , output logic                                     xmtbyte_ts_data_diff                    // current ts data different from previous
    , output logic                                     xmtbyte_1024_ts_sent                    // 1024 ts sent in a state
    , output logic                                     xmtbyte_spd_chg_sent                    // Indicates 1 TS1/2 that speed_change bit=1 is sent.
    , output logic                                     xmtbyte_dis_link_sent                   // Indicates 1 TS1/2 that disable link=1 is sent
    , output logic                                     xmtbyte_loe_2_ts1_ec_00b_sent           // no more than 2 ts1 with ec==00b sent. This signal is only used in R.Lock (send TS1 only), so no need xmtbyte_ts1_sent
    , output logic [OS_WD-1:0]                         xmtbyte_ts1_sent                        // Indicates 1 TS1 ordered is sent (1shot. Asserted 1st cycle of a packet)
    , output logic [OS_WD-1:0]                         xmtbyte_ts2_sent                        // Indicates 1 TS2 ordered is sent (1shot. Asserted 1st cycle of a packet)
    , output logic                                     xmtbyte_fts_sent                        // Indicates all FTS is sent (1shot. Asserted 1st cycle of a packet)
    , output logic                                     xmtbyte_idle_sent                       // Indicates 1 IDLE is sent 
    , output logic                                     xmtbyte_eidle_sent                      // Indicates EIOS pattern(all continuous EIOS) is completed to send (1shot. Asserted 1st cycle of a packet)
    , output logic                                     xmtbyte_eies_sent                       // Indicates 1 EIEOS is sent (1shot. Asserted 1st cycle of a packet)
    , output logic                                     xmtbyte_skip_sent_o                     // Indicates 1 SKP OS is sent (1shot. Asserted 1st cycle of a packet)
    , output logic                                     xmtbyte_skip_insert                     // Indicates 1 SKP OS that is scheduled Periodically in DataStream , loopback lead. Not used
    , output logic                                     xmtbyte_ctlskip_sent                    // Indicates 1 Control SKP OS is sent (1shot. Asserted 1st cycle of a packet)
    , output logic                                     xmtbyte_sent_24_ts0_ec00                // Indicates 24 or above TS0 with ec=00b is sent by Downstream Port for EQ.Phase1.
    , output logic                                     xmtbyte_2_compliance_ts1_sent           // Indicates 2 Compliance TS1 ordered set has been sent based on LTSSM's command  
    , output logic                                     xmtbyte_pat_fts_sent                    // Indicates 1 FTS OS  is sent (1shot. Asserted 1st cycle of a packet)
    , output logic                                     xmtbyte_pat_eidle_start_sent            // Indicates EIOS is sent (pulse even if continus EIOS sending) (1shot. Asserted 1st cycle of a packet)
    , output logic                                     xplh_xmlh_sof                           // start of flit
    , output logic                                     xmtbyte_l0p_eidle_sent                  // Indicates EIOS pattern(all continuous EIOS) is completed to send when L0p downsizing (1shot. Asserted 1st cycle of a packet)
    , output logic [OS_WD-1:0]                         xmtbyte_l0p_ts1_sent                    // Indicates 1 TS1 ordered is sent when L0p upsizing (1shot. Asserted 1st cycle of a packet)
    , output logic [OS_WD-1:0]                         xmtbyte_l0p_ts2_sent                    // Indicates 1 TS2 ordered is sent when L0p upsizing (1shot. Asserted 1st cycle of a packet)
    , output logic                                     xmtbyte_l0p_linkwidth_changed           // Indicates L0p Up/Downsizing is completed

// Return sedning TLP/DLLP response to Layer2
    , output logic                                     xmtbyte_stp_start                       // stp starts transmission in MAC

// For Flit Performance Mesurement
    , output logic                                     xmbyte_flit_data_stream                 // Indicates DataStream and Flit Mode. 

// Flit Error injection signals
    , output ltssm_state_e                             xmtbyte_latched_loadpat_ltssmstate      // LTSSM state aligned with xmtbyte_txdata.
    , output xmlh_einj_in_os_t                         xmtbyte_einj_in_os                      // Indicates which OS is sending align with xmtbyte_txdata.

// Mode/State signals
    , output logic                                     xmtbyte_gen6_compliance_sending         // indicates sending Gen6 (Modified) compliance pattern
    , output logic                                     xmtbyte_sris_mode_enabled               // Indicates SRIS mode is enabled or app_sris_mode_i=1
    , output logic                                     xmtbyte_l0p_sris_mode_enabled           // Indicates SRIS mode is enabled or app_sris_mode_i=1
    , output logic                                     xmtbyte_l0p_state_in_upsize             // Indicates L0p upsizing netogiation is in progress. This is for Flit Performance mesurement.
    , output logic                                     xmtbyte_sris_enable                     // PIPE Interface SRISEnable
// Common signal for other than this module
    , output data_rate_enc_t                           crnt_rate                               // current data rate shortcut.


    );


// --- Set fix value to input signals which are not exist by configuration.
    logic  [6:0]                 esm_current_rate ;

// --- Set fix value to input signals which are not exist by configuration.
   assign  esm_current_rate                       = 7'h00 ;

// -----------------------------------
//  Declaration
// -----------------------------------
// common logic generated in this module
    logic  [NBIT-1:0]                          active_nb_bitmap ;                     // active number of symbols per lane bitmap
    logic  [NBK-1:0]                           active_nb_bitmapk ;                    // active number of symbols per lane bitmap (for DataK)
    logic  [NB-1:0]                            active_nb_bytemap ;                    // active number of symbols per lane bytemap
    logic                                      int_ltssm_in_lpbk ;                    // LTSSM in any Loopback state
    logic  [3:0]                               ltssm_cmd_i_d ;                        // 1cycle delay of ltssm_cmd_i
    
// Internal signals wire
    grant_t                                    next_grant ;                            // Arbitration grant (next)
    grant_t                                    crnt_grant ;                            // Arbitration grant (Current)
    logic                                      internal_txdata_dv ;                    // Data Valid, gen1/gen2: always 1, gen3: 0 for one cycle every 4*active_nb blocks
    logic                                      internal_txdata_dv_pre ;                // 1 cycle before of internal_txdata_dv
    logic                                      internal_txstartblock ;                 // Indicates the starting symbol for a 130b block
    logic                                      internal_txendblock ;                   // Indicates the ending symbol for a 130b block
    logic [4:0]                                internal_txtblock_symbol_cnt ;          // Indicates the current symbol count for a 130b block
    logic  [NL-1 :0]                           int_data_ltssm_lanes_active ;           // Data Link width (Not L0p Up/Downsize OS lane width) : LTSSM latched lanes that are active based on the link negotiation
    logic  [NL-1 :0]                           int_l0p_ltssm_lanes_active ;            // Data Link width (L0p Up/Downsize OS lane width) : LTSSM latched lanes that are active based on the link negotiation
    logic  [5:0]                               int_data_smlh_link_mode ;               // Data Link width (Not L0p Up/Downsize OS lane width) : 10000 -- x16, 01000 -- x8, 00100 -- x4, 00010 -- x2, 00001 -- x1
    logic  [NL-1 :0]                           int_data_ltssm_lanes_active_pre ;       // Data Link width (Not L0p Up/Downsize OS lane width) : LTSSM latched lanes that are active based on the link negotiation
    logic  [5:0]                               int_data_smlh_link_mode_pre ;           // Data Link width (Not L0p Up/Downsize OS lane width) : 10000 -- x16, 01000 -- x8, 00100 -- x4, 00010 -- x2, 00001 -- x1
    logic  [NL-1:0][NBIT-1:0]                  data_gen_data ;                         // TLP/DLLP Data
    logic  [NL-1:0][NBK-1:0]                   data_gen_datak ;                        // TLP/DLLP Data Kcode
    logic                                      last_chunk ;                            // Indicates the last cycle of Data Bus alignment
    logic                                      eds_ack ;                               // Indicates EDS insertion is completed
    logic  [NW-1:0]                            crnt_active_pid ;                       // Indicates current sending Data PID
    logic  [NL-1:0][NBIT-1:0]                  os_gen_data ;                           // OS Data
    logic  [NL-1:0][NBK-1:0]                   os_gen_datak ;                          // OS Data Kcode
    logic  [NL-1:0][NBLOCK-1:0][OSFLG_WD-1:0]  os_gen_ossending ;                      // Sending OS Flag 
    logic                                      os_send_done ;                          // Indicated the last cycle of a OS sending.
    logic                                      ossq_send_done ;                        // Asserted when last cycle of OSSQ sending
    skp_replace_t                              os_gen_skp_os_align_sts ;               // Indicates current sending Data have LFSR/Parity field of SKP OS
    logic                                      ts0_sending_req ;                       // Indicates Sending TS0 request 
    logic                                      ts1_sending_req ;                       // Indicates Sending TS1 request 
    logic                                      ts2_sending_req ;                       // Indicates Sending TS2 request 
    logic [3:0]                                ltssm_l0p_cmd_d ;                       // 1 cycle delay of ltssm_l0p_cmd
    l0p_state_t                                crnt_l0p_state ;                        // L0p Up/Downsizing state (current)
    grant_t                                    next_l0p_grant ;                        // Arbitration grant for L0p Up/Downsizing (Next)
    grant_t                                    crnt_l0p_grant ;                        // Arbitration grant for L0p Up/Downsizing (Current)
    logic  [NL-1:0][NBIT-1:0]                  os_gen_data_l0p ;                       // OS Data (L0p Up/Downsizing)
    logic  [NL-1:0][NBK-1:0]                   os_gen_datak_l0p ;                      // OS Data Kcode  (L0p Up/Downsizing)
    logic  [NL-1:0][NBLOCK-1:0][OSFLG_WD-1:0]  os_gen_ossending_l0p ;                  // Sending OS Flag 
    logic                                      l0p_os_send_done ;                      // Indicated the last cycle of a OS sending.
    logic                                      l0p_ossq_send_done ;                    // Asserted when last cycle of OSSQ sending(L0p)
    logic [4:0]                                l0p_crnt_ossq_num ;                     // Indicated the number of OS should be sent in current OSSQ. (0's base)
    skp_replace_t                              l0p_os_gen_skp_os_align_sts ;           // Indicates current sending Data have LFSR/Parity field of SKP OS
    logic                                      ts1_sending_req_l0p ;                   // Indicates Sending TS1 request (L0p Up/Downsizing)
    logic                                      ts2_sending_req_l0p ;                   // Indicates Sending TS2 request (L0p Up/Downsizing)
    logic                                      l0p_4_eie_for_1st ;                     // Indicates EIE is not send for L0p upsizing. In this case send 4 EIE.
    logic  [NL*EQTS_WD-1:0]                    eqctl_eqts_info_l0p ;                    // Equalization Information, Set this value on EQ TS Symbols 6-9 of EQ TSs for Gen3 or above.
    logic                                      mask_tlp_dllp_timing ;                  // FREQ_STEP Algin timing for TLP/DLLP
    logic                                      in_data_progress ;                      // Indicates Reveing TLP/DLLP from Layer2 progress
    logic                                      in_idle_data_progress ;                 // Indicates IDLE Data is transmitting
    logic                                      sris_mode_on ;                          // Indicates SRIS is on used internally. 
    logic  [NL-1:0][NBIT-1:0]                  cmp_gen_data ;                          // Pattern Data
    logic  [NL-1:0][NBK-1:0]                   cmp_gen_datak ;                         // Pattern Data Kcode
    logic  [NL-1:0][NBLOCK-1:0][OSFLG_WD-1:0]  cmp_gen_ossending ;                     // Sending OS Flag 
    logic  [NL-1:0]                            int_txcompliance ;                      // Base PIPE TxDetecteLoopback. This signal will be aligned align with Txelecidle
    logic                                      cmp_block_done ;                        // Asserted when last cycle of pattern block sending
    logic                                      dsp_tx_sris_cloking ;                   // Downstream Port SRIS Mode
    logic [4:0]                                crnt_ossq_num ;                         // Indicated the number of OS should be sent in current OSSQ. (0's base)
    logic                                      ctl_skp_enable ;                        // Indicates Control SKP should be set if 1.
    stream_t                                   next_stream ;                           // Indicates Current Stream(Data/OS/CMP or EIDLE) (Next)
    stream_t                                   crnt_stream ;                           // Indicates Current Stream(Data/OS/CMP or EIDLE) (Current)
    logic [127:0]                              eie_pat_128b130b ;                      // EIE OS data for Gen/3/4/5
    logic [127:0]                              skp_pat_128b130b ;                      // SKP OS data for Gen/3/4/5
    logic [127:0]                              eie_pat_1b1b ;                          // EIE OS data for Gen6
    logic [319:0]                              skp_pat_1b1b ;                          // SKP OS data for Gen6
    logic                                      xmtbyte_skip_sent ;                     // Indicates 1 SKP OS is sent (1shot. Asserted 1st cycle of a packet)
    logic                                      app_sris_mode ;                         // Inidcates SRIS is enabled
    logic                                      eds_inserted ;                          // Inidcates EDS is inserted
    logic                                      ltssm_1b1b_cmd_4_eieos_req ;            // Indicates send 4 cousequtive EIEOS in Gen6.
    logic                                      l0p_1b1b_upsizing_by_rcvry ;            // Indicates L0p Link width back to max width by Recovery transition.
    logic                                      mcmp_gen6_skp_in_progress  ;            // Gen6 SKP OS is sending in Modified compliance pattern (for 8S or below)
    logic                                      mcmp_gen6_skp_done ;                    // The last cycle of Gen6 SKP OS in Modified compliance pattern (for 8S or below)


// For L0p multiple instantiation
    grant_t                                    i_next_grant                     [NUM_OS_GEN-1:0] ;
    grant_t                                    i_crnt_grant                     [NUM_OS_GEN-1:0] ;
    logic                                      i_ts0_sending_req                [NUM_OS_GEN-1:0] ;
    logic                                      i_ts1_sending_req                [NUM_OS_GEN-1:0] ;
    logic                                      i_ts2_sending_req                [NUM_OS_GEN-1:0] ;
    logic                                      i_ltssm_mod_ts                   [NUM_OS_GEN-1:0] ;        // Tx modified TS should be sent if 1.
    logic  [4:0]                               i_ltssm_ts_data_rate             [NUM_OS_GEN-1:0] ;
    logic  [3:0]                               i_ltssm_cmd                      [NUM_OS_GEN-1:0] ;
    logic  [3:0]                               i_ltssm_cmd_d                    [NUM_OS_GEN-1:0] ;
    logic [NL*EQTS_WD-1:0]                     i_eqctl_eqts_info                [NUM_OS_GEN-1:0] ;
    logic                                      i_ltssm_1b1b_cmd_4_eieos_req     [NUM_OS_GEN-1:0] ;
    logic [10:0]                               o_xmtbyte_ts_pcnt                [NUM_OS_GEN-1:0] ;
    logic                                      o_xmtbyte_ts_data_diff           [NUM_OS_GEN-1:0] ;
    logic                                      o_xmtbyte_1024_ts_sent           [NUM_OS_GEN-1:0] ;
    logic                                      o_xmtbyte_spd_chg_sent           [NUM_OS_GEN-1:0] ;
    logic                                      o_xmtbyte_dis_link_sent          [NUM_OS_GEN-1:0] ;
    logic                                      o_xmtbyte_loe_2_ts1_ec_00b_sent  [NUM_OS_GEN-1:0] ;
    logic [OS_WD-1:0]                          o_xmtbyte_ts1_sent               [NUM_OS_GEN-1:0] ;
    logic [OS_WD-1:0]                          o_xmtbyte_ts2_sent               [NUM_OS_GEN-1:0] ;
    logic                                      o_xmtbyte_fts_sent               [NUM_OS_GEN-1:0] ;
    logic                                      o_xmtbyte_eidle_sent             [NUM_OS_GEN-1:0] ;
    logic                                      o_xmtbyte_eies_sent              [NUM_OS_GEN-1:0] ;
    logic                                      o_xmtbyte_skip_sent_o            [NUM_OS_GEN-1:0] ;
    logic                                      o_xmtbyte_skip_insert            [NUM_OS_GEN-1:0] ;
    logic                                      o_xmtbyte_ctlskip_sent           [NUM_OS_GEN-1:0] ;
    logic                                      o_xmtbyte_sent_24_ts0_ec00       [NUM_OS_GEN-1:0] ;
    logic                                      o_xmtbyte_2_compliance_ts1_sent  [NUM_OS_GEN-1:0] ;
    logic                                      o_xmtbyte_pat_fts_sent           [NUM_OS_GEN-1:0] ;
    logic                                      o_xmtbyte_pat_eidle_start_sent   [NUM_OS_GEN-1:0] ;
    ltssm_state_e                              o_xmtbyte_latched_loadpat_ltssmstate [NUM_OS_GEN-1:0] ;
    xmlh_einj_in_os_t                          o_xmtbyte_einj_in_os                 [NUM_OS_GEN-1:0] ;
    logic  [NL-1:0][NBIT-1:0]                  o_os_gen_data                    [NUM_OS_GEN-1:0] ;
    logic  [NL-1:0][NBK-1:0]                   o_os_gen_datak                   [NUM_OS_GEN-1:0] ;
    logic  [NL-1:0][NBLOCK-1:0][OSFLG_WD-1:0]  o_os_gen_ossending [NUM_OS_GEN-1:0] ;
    logic                                      o_os_send_done                   [NUM_OS_GEN-1:0] ;
    logic                                      o_ossq_send_done                 [NUM_OS_GEN-1:0] ;
    logic                                      o_dsp_tx_sris_cloking            [NUM_OS_GEN-1:0] ;
    logic [4:0]                                o_crnt_ossq_num                  [NUM_OS_GEN-1:0] ;
    skp_replace_t                              o_os_gen_skp_os_align_sts        [NUM_OS_GEN-1:0] ;

    logic [127:0]                              o_eie_pat_128b130b               [NUM_OS_GEN-1:0] ;
    logic [127:0]                              o_skp_pat_128b130b               [NUM_OS_GEN-1:0] ;
    logic [127:0]                              o_eie_pat_1b1b                   [NUM_OS_GEN-1:0] ;
    logic [319:0]                              o_skp_pat_1b1b                   [NUM_OS_GEN-1:0] ;
// -----------------------------------
//  Common logic
// -----------------------------------

// For rate decoding optimization.
    always_ff @( posedge core_clk or negedge core_rst_n ) begin : rate_flag_PROC
        if ( ~core_rst_n ) begin
            crnt_rate.one_hot                <= #TP 8'( 1 << GEN1_BIT) ;
            crnt_rate.eq_or_higher           <= #TP 8'h01 ;
            crnt_rate.enc_8b10b              <= #TP 1'b1 ;   
            crnt_rate.enc_128b130b           <= #TP 1'b0 ;
            crnt_rate.enc_1b1b               <= #TP 1'b0 ;    
        end
        else begin
            case( current_data_rate ) 
                `GEN2_RATE : begin     // Gen2
                            crnt_rate.one_hot                <= #TP 8'( 1 << GEN2_BIT) ;
                            crnt_rate.eq_or_higher           <= #TP 8'h03 ;
                            crnt_rate.enc_8b10b              <= #TP 1'b1 ;   
                            crnt_rate.enc_128b130b           <= #TP 1'b0 ;
                            crnt_rate.enc_1b1b               <= #TP 1'b0 ;    
                           end
                `GEN3_RATE : begin     // Gen3
                            crnt_rate.one_hot                <= #TP esm_current_rate[4] ? 8'( 1 << GEN4_BIT) : 8'( 1 << GEN3_BIT) ;  // esm_current_rate[4] indicats 16GT/s
                            crnt_rate.eq_or_higher           <= #TP esm_current_rate[4] ? 8'h0F : 8'h07 ;                            // esm_current_rate[4] indicats 16GT/s
                            crnt_rate.enc_8b10b              <= #TP 1'b0 ;   
                            crnt_rate.enc_128b130b           <= #TP 1'b1 ;
                            crnt_rate.enc_1b1b               <= #TP 1'b0 ;    
                           end
                `GEN4_RATE : begin     // Gen4
                            crnt_rate.one_hot                <= #TP 8'( 1 << GEN4_BIT) ;
                            crnt_rate.eq_or_higher           <= #TP 8'h0F ;
                            crnt_rate.enc_8b10b              <= #TP 1'b0 ;   
                            crnt_rate.enc_128b130b           <= #TP 1'b1 ;
                            crnt_rate.enc_1b1b               <= #TP 1'b0 ;    
                           end
                `GEN5_RATE : begin     // Gen5
                            crnt_rate.one_hot                <= #TP 8'( 1 << GEN5_BIT) ;
                            crnt_rate.eq_or_higher           <= #TP 8'h1F ;
                            crnt_rate.enc_8b10b              <= #TP 1'b0 ;   
                            crnt_rate.enc_128b130b           <= #TP 1'b1 ;
                            crnt_rate.enc_1b1b               <= #TP 1'b0 ;    
                           end
                `GEN6_RATE : begin     // Gen6
                            crnt_rate.one_hot                <= #TP 8'( 1 << GEN6_BIT) ;
                            crnt_rate.eq_or_higher           <= #TP 8'h3F ;
                            crnt_rate.enc_8b10b              <= #TP 1'b0 ;   
                            crnt_rate.enc_128b130b           <= #TP 1'b0 ;
                            crnt_rate.enc_1b1b               <= #TP 1'b1 ;    
                           end
                default   : begin     // Gen1
                            crnt_rate.one_hot                <= #TP 8'( 1 << GEN1_BIT) ;
                            crnt_rate.eq_or_higher           <= #TP 8'h01 ;
                            crnt_rate.enc_8b10b              <= #TP 1'b1 ;   
                            crnt_rate.enc_128b130b           <= #TP 1'b0 ;
                            crnt_rate.enc_1b1b               <= #TP 1'b0 ;    
                           end
               endcase
        end 
    end    // rate_flag_PROC


// For active_nb decoding optimization.
    always_ff @( posedge core_clk or negedge core_rst_n ) begin : active_nb_PROC
        if ( ~core_rst_n ) begin
            active_nb_bitmap              <= #TP $bits(active_nb_bitmap )'(8'hFF) ;
            active_nb_bitmapk             <= #TP $bits(active_nb_bitmapk)'(1'b1) ;
            active_nb_bytemap             <= #TP $bits(active_nb_bytemap)'(1'b1) ;
        end
        else begin
            for( int ii = 0 ; ii < NB ; ii++ ) begin
                active_nb_bitmap[ii*8 +: 8] <= #TP ( active_nb > $bits(active_nb)'( ii ) ) ? 8'hFF : 8'h00 ;
                active_nb_bytemap[ii]       <= #TP ( active_nb > $bits(active_nb)'( ii ) ) ? 1'b1  : 1'b0  ;
            end
            for( int ii = 0 ; ii < NBK ; ii++ ) begin
                if( ii == 1 ) active_nb_bitmapk[ii]       <= #TP ( active_nb > $bits(active_nb)'( ii ) || (current_data_rate >= `GEN3_RATE) ) ? 1'b1 : 1'b0 ;   // [1]: For syncheader if Gen3 or higher
                else          active_nb_bitmapk[ii]       <= #TP ( active_nb > $bits(active_nb)'( ii )                                      ) ? 1'b1 : 1'b0 ;   // other than [1]
            end
        end
   end

// LTSSM is in any Loopback state
    always_ff @( posedge core_clk or negedge core_rst_n ) begin : int_ltssm_in_lpbk_PROC
        if ( ~core_rst_n ) begin
            int_ltssm_in_lpbk             <= #TP '0 ;
        end
        else if( (smlh_ltssm_state == S_LPBK_ENTRY) || (smlh_ltssm_state == S_LPBK_ACTIVE) || (smlh_ltssm_state == S_LPBK_EXIT) )begin
            int_ltssm_in_lpbk             <= #TP 1'b1 ;
        end
        else begin
            int_ltssm_in_lpbk             <= #TP '0 ;
        end
    end

 // Delay Signals
    always @(posedge core_clk or negedge core_rst_n) begin : delay_signals_PROC
        if (!core_rst_n) begin
            ltssm_cmd_i_d              <= #TP `XMT_IN_EIDLE ;
            ltssm_l0p_cmd_d            <= #TP `NORM ;
        end
        else begin
            ltssm_cmd_i_d              <= #TP ltssm_cmd_i ;
            ltssm_l0p_cmd_d            <= #TP ltssm_l0p_cmd ;
         end
    end

// For reference for other module
    always_comb begin
        app_sris_mode  = sris_mode_on ;
        eds_inserted   = eds_ack ;
    end

 // L0p upsizing TS1 EQ field info
    always_comb begin
        for( int ii = 0 ; ii < NL ; ii++ ) begin
            eqctl_eqts_info_l0p[ii*EQTS_WD +: EQTS_WD] = '0 ;
            if( crnt_rate.enc_1b1b ) begin
                 if( next_l0p_grant[G_TS1_BIT] ) eqctl_eqts_info_l0p[ii*EQTS_WD +: EQTS_WD] = 32'h0000_0000 ;
                 if( next_l0p_grant[G_TS2_BIT] ) eqctl_eqts_info_l0p[ii*EQTS_WD +: EQTS_WD] = 32'h0000_0000 ;
            end
            else if( crnt_rate.enc_128b130b ) begin
                 if( next_l0p_grant[G_TS1_BIT] ) begin
                        eqctl_eqts_info_l0p[ii*EQTS_WD +: (EQTS_WD-1)] = $bits(EQTS_WD-1)'( 32'h0000_0000 ) ;
                        eqctl_eqts_info_l0p[ii*EQTS_WD +  (EQTS_WD-1)] = ^eqctl_eqts_info_l0p[ii*EQTS_WD +: (EQTS_WD-1)] ;
                 end
                 if( next_l0p_grant[G_TS2_BIT] ) eqctl_eqts_info_l0p[ii*EQTS_WD +: EQTS_WD] = { {3{`TS2_8B}} , 8'h00 } ;
            end
            else begin
                 if( next_l0p_grant[G_TS1_BIT] ) eqctl_eqts_info_l0p[ii*EQTS_WD +: EQTS_WD] = {4{`TS1_8B}} ;
                 if( next_l0p_grant[G_TS2_BIT] ) eqctl_eqts_info_l0p[ii*EQTS_WD +: EQTS_WD] = {4{`TS2_8B}} ;
            end
        end
    end


    always_comb begin
        l0p_1b1b_upsizing_by_rcvry = crnt_stream[DATA_STREAM_BIT] & next_grant[G_EIE_BIT] & (int_l0p_ltssm_lanes_active != ltssm_lanes_active) ;
    end
 
    always @(posedge core_clk or negedge core_rst_n) begin : ltssm_1b1b_cmd_4_eieos_req_PROC
        if (!core_rst_n) begin
            ltssm_1b1b_cmd_4_eieos_req              <= #TP '0 ;
        end
        else begin
            if( ( crnt_grant[G_EIDLE_BIT] || l0p_1b1b_upsizing_by_rcvry) && crnt_rate.enc_1b1b ) begin
                ltssm_1b1b_cmd_4_eieos_req              <= #TP 1'b1 ;
            end
            else if( ( cfg_upstream_port && ( (smlh_ltssm_state != S_LPBK_ENTRY) && (smlh_ltssm_state != S_RCVRY_LOCK) && (smlh_ltssm_state != S_RCVRY_EQ0) ) )
                 ||  (~cfg_upstream_port && ( (smlh_ltssm_state != S_LPBK_ENTRY) && (smlh_ltssm_state != S_RCVRY_LOCK) && (smlh_ltssm_state != S_RCVRY_EQ1) ) )
            ) begin
                ltssm_1b1b_cmd_4_eieos_req              <= #TP 1'b0 ;
            end
         end
    end
    always @(posedge core_clk or negedge core_rst_n) begin : l0p_4_eie_for_1st_PROC
        if (!core_rst_n) begin
            l0p_4_eie_for_1st              <= #TP '0 ;
        end
        else begin
            if( ~crnt_l0p_state[L0P_UPSIZING_BIT] ) begin
                l0p_4_eie_for_1st          <= #TP 1'b1 ;
            end
            else if( crnt_l0p_grant[G_EIE_BIT] & l0p_ossq_send_done ) begin
                l0p_4_eie_for_1st              <= #TP 1'b0 ;
            end
         end
    end


// -----------------------------------
//  Instantiation modules
// -----------------------------------

// ----------------- xmlh_arb_ctrl --------------------
     xmlh_arb_ctl
      u_xmlh_arb_ctl 
        (
          .core_clk                               ( core_clk                                  )
        , .core_rst_n                             ( core_rst_n                                )
        , .sticky_rst_n                           ( sticky_rst_n                              )
        // --- input 
        , .xdlh_xmlh_eof                          ( xdlh_xmlh_eof                             )
        , .xdlh_xmlh_sof                          ( xdlh_xmlh_sof                             )
        , .xdlh_xmlh_stp_i                        ( xdlh_xmlh_stp_i                           )
        , .xdlh_xmlh_sdp_i                        ( xdlh_xmlh_sdp_i                           )
        , .xdlh_xmlh_eot_i                        ( xdlh_xmlh_eot_i                           )
        , .next_xdlh_xmlh_eot_i                   ( next_xdlh_xmlh_eot_i                      )
        , .next_xdlh_xmlh_stp_i                   ( next_xdlh_xmlh_stp_i                      )
        , .next_xdlh_xmlh_sdp_i                   ( next_xdlh_xmlh_sdp_i                      )
        , .xdlh_xmlh_pkt_pending_i                ( xdlh_xmlh_pkt_pending_i                   )
        , .xmlh_fm_pending                        ( xmlh_fm_pending                           )
        , .xfsh_xmlh_buf_empty                    ( xfsh_xmlh_buf_empty                       )
        , .xmlh_fm_flush_ack                      ( xmlh_fm_flush_ack                         )
        , .xmlh_cmd_if_lp_ack                     ( xmlh_cmd_if_lp_ack                        )
        , .xdlh_xmlh_pid                          ( xdlh_xmlh_pid                             )
        , .ltssm_cmd_i                            ( ltssm_cmd_i                               )
        , .ltssm_cmd_i_d                          ( ltssm_cmd_i_d                             )
        , .ltssm_cmd_send_eieos_for_pset_map      ( ltssm_cmd_send_eieos_for_pset_map         )
        , .scramble_lfsr_rollover                 ( scramble_lfsr_rollover                    )
        , .smlh_l0p_update                        ( smlh_l0p_update                           )
        , .ltssm_l0p_cmd                          ( ltssm_l0p_cmd                             )
        , .ltssm_cmd_eqts0                        ( ltssm_cmd_eqts0                           )
        , .eqctl_g6_tx_ts0                        ( eqctl_g6_tx_ts0                           ) 
        , .link_rx_ts0_to_ts1_pulse               ( link_rx_ts0_to_ts1_pulse                  )
        , .ltssm_clear                            ( ltssm_clear                               )
        , .eqctl_2mask_eieos_pulse                ( eqctl_2mask_eieos_pulse                   )
        , .app_sris_mode_i                        ( app_sris_mode_i                           )
        , .ltssm_cxl_sh_bypass                    ( ltssm_cxl_sh_bypass                       )
        , .cxl_mode_enable                        ( cxl_mode_enable                           )
        , .smlh_ltssm_state                       ( smlh_ltssm_state                          )
        , .smlh_ltssm_last                        ( smlh_ltssm_last                           )
        , .ltssm_lpbk_slave_lut                   ( ltssm_lpbk_slave_lut                      )
        , .ltssm_flit_mode_enable                 ( ltssm_flit_mode_enable                    )
        , .smlh_link_up                           ( smlh_link_up                              )
        , .smlh_usp_sris_mode                     ( smlh_usp_sris_mode                        )
        , .cfg_flit_sris_clocking                 ( cfg_flit_sris_clocking                    )
        , .cfg_comm_clk_config                    ( cfg_comm_clk_config                       )
        , .cfg_skip_interval                      ( cfg_skip_interval                         )
        , .cfg_ext_synch                          ( cfg_ext_synch                             )
        , .smlh_link_mode                         ( smlh_link_mode                            )
        , .ltssm_lanes_active                     ( ltssm_lanes_active                        )
        , .ltssm_ts_cnt_en_i                      ( ltssm_ts_cnt_en_i                         )
        , .ltssm_ts_cnt_rst                       ( ltssm_ts_cnt_rst                          )
        , .int_ltssm_in_lpbk                      ( int_ltssm_in_lpbk                         )
        , .ltssm_in_lpbkentry                     ( ltssm_in_lpbkentry                        )
        , .ltssm_in_compliance                    ( ltssm_in_compliance                       )
        , .cfg_compliance_sos                     ( cfg_compliance_sos                        )
        , .eqctl_mask_eieos                       ( eqctl_mask_eieos                          )
        , .lpbk_master                            ( lpbk_master                               )
        , .active_nb                              ( active_nb                                 )
        , .cfg_upstream_port                      ( cfg_upstream_port                         )
        , .smlh_l0p_link_mode                     ( smlh_l0p_link_mode                        )
        , .ltssm_l0p_lanes_active                 ( ltssm_l0p_lanes_active                    )
        , .crnt_rate                              ( crnt_rate                                 )
        , .xmtbyte_xdlh_halt_o                    ( xmtbyte_xdlh_halt_o                       )
        , .data_gen_data                          ( data_gen_data                             )
        , .data_gen_datak                         ( data_gen_datak                            )
        , .last_chunk                             ( last_chunk                                )
        , .eds_ack                                ( eds_ack                                   )
        , .os_gen_data                            ( os_gen_data                               )
        , .os_gen_datak                           ( os_gen_datak                              )
        , .os_gen_ossending                       ( os_gen_ossending                          )
        , .os_send_done                           ( os_send_done                              )
        , .ossq_send_done                         ( ossq_send_done                            )
        , .os_gen_skp_os_align_sts                ( os_gen_skp_os_align_sts                   )
        , .os_gen_data_l0p                        ( os_gen_data_l0p                           )
        , .os_gen_datak_l0p                       ( os_gen_datak_l0p                          )
        , .os_gen_ossending_l0p                   ( os_gen_ossending_l0p                      )
        , .l0p_os_send_done                       ( l0p_os_send_done                          )
        , .l0p_ossq_send_done                     ( l0p_ossq_send_done                        )
        , .l0p_crnt_ossq_num                      ( l0p_crnt_ossq_num                         )
        , .l0p_os_gen_skp_os_align_sts            ( l0p_os_gen_skp_os_align_sts               )
        , .dsp_tx_sris_cloking                    ( dsp_tx_sris_cloking                       )
        , .crnt_ossq_num                          ( crnt_ossq_num                             )
        , .xmtbyte_fts_sent                       ( xmtbyte_fts_sent                          )
        , .cmp_gen_data                           ( cmp_gen_data                              )
        , .cmp_gen_datak                          ( cmp_gen_datak                             )
        , .cmp_gen_ossending                      ( cmp_gen_ossending                         )
        , .int_txcompliance                       ( int_txcompliance                          )
        , .cmp_block_done                         ( cmp_block_done                            )
        , .mcmp_gen6_skp_in_progress              ( mcmp_gen6_skp_in_progress                 )
        , .mcmp_gen6_skp_done                     ( mcmp_gen6_skp_done                        )

        // ---- output 
        , .xmlh_skip_pending                      ( xmlh_skip_pending                         )
        , .xmtbyte_cmd_is_data                    ( xmtbyte_cmd_is_data                       )
        , .xmlh_xfsh_last_flit                    ( xmlh_xfsh_last_flit                       )
        , .xmlh_rst_flit_alignment                ( xmlh_rst_flit_alignment                   )
        , .xmtbyte_txdata_dv                      ( xmtbyte_txdata_dv                         )
        , .xmtbyte_txdata                         ( xmtbyte_txdata                            )
        , .xmtbyte_txdatak                        ( xmtbyte_txdatak                           )
        , .xmtbyte_ossending                      ( xmtbyte_ossending                         )
        , .xmtbyte_txstartblock                   ( xmtbyte_txstartblock                      )
        , .xmtbyte_skp_os_align_sts               ( xmtbyte_skp_os_align_sts                  )
        , .xmtbyte_txelecidle                     ( xmtbyte_txelecidle                        )
        , .xmtbyte_ltssm_in_compliance            ( xmtbyte_ltssm_in_compliance               )
        , .xmtbyte_link_in_training               ( xmtbyte_link_in_training                  )
       , .xmtbyte_l0p_link_in_training            ( xmtbyte_l0p_link_in_training              )
        , .xmtbyte_g5_lpbk_deassert               ( xmtbyte_g5_lpbk_deassert                  )
        , .xmtbyte_txdetectrx_loopback            ( xmtbyte_txdetectrx_loopback               )
        , .xmtbyte_txcompliance                   ( xmtbyte_txcompliance                      )
        , .xplh_xmlh_sof                          ( xplh_xmlh_sof                             )
        , .xmtbyte_l0p_linkwidth_changed          ( xmtbyte_l0p_linkwidth_changed             )
        , .xmtbyte_stp_start                      ( xmtbyte_stp_start                         )
         , .xmbyte_flit_data_stream               ( xmbyte_flit_data_stream                   )
        , .xmtbyte_sris_mode_enabled              ( xmtbyte_sris_mode_enabled                 )
        , .xmtbyte_l0p_sris_mode_enabled          ( xmtbyte_l0p_sris_mode_enabled             )
        , .xmtbyte_l0p_state_in_upsize            ( xmtbyte_l0p_state_in_upsize               )
        , .xmtbyte_sris_enable                    ( xmtbyte_sris_enable                       )
        , .next_grant                             ( next_grant                                )
        , .crnt_grant                             ( crnt_grant                                )
        , .internal_txdata_dv                     ( internal_txdata_dv                        )
        , .internal_txdata_dv_pre                 ( internal_txdata_dv_pre                    )
        , .internal_txstartblock                  ( internal_txstartblock                     )
        , .internal_txendblock                    ( internal_txendblock                       )
        , .internal_txtblock_symbol_cnt           ( internal_txtblock_symbol_cnt              )
        , .int_data_ltssm_lanes_active            ( int_data_ltssm_lanes_active               )
        , .int_l0p_ltssm_lanes_active             ( int_l0p_ltssm_lanes_active                )
        , .int_data_smlh_link_mode                ( int_data_smlh_link_mode                   )
        , .int_data_ltssm_lanes_active_pre        ( int_data_ltssm_lanes_active_pre           )
        , .int_data_smlh_link_mode_pre            ( int_data_smlh_link_mode_pre               )
        , .crnt_l0p_state                         ( crnt_l0p_state                            )
        , .next_stream                            ( next_stream                               ) 
        , .crnt_stream                            ( crnt_stream                               ) 
        , .ctl_skp_enable                         ( ctl_skp_enable                            )
        , .ts0_sending_req                        ( ts0_sending_req                           )
        , .ts1_sending_req                        ( ts1_sending_req                           )
        , .ts2_sending_req                        ( ts2_sending_req                           )
        , .next_l0p_grant                         ( next_l0p_grant                            )
        , .crnt_l0p_grant                         ( crnt_l0p_grant                            )
        , .ts1_sending_req_l0p                    ( ts1_sending_req_l0p                       )
        , .ts2_sending_req_l0p                    ( ts2_sending_req_l0p                       )
        , .mask_tlp_dllp_timing                   ( mask_tlp_dllp_timing                      )
        , .in_data_progress                       ( in_data_progress                          )
        , .in_idle_data_progress                  ( in_idle_data_progress                     )
        , .sris_mode_on                           ( sris_mode_on                              )
        );





// ----------------- xmlh_os_gen --------------------
    always_comb begin
    // -- input to  xmlh_os_gen.sv
        i_next_grant[0]                 = next_grant ;
        i_crnt_grant[0]                 = crnt_grant ;
        i_ts0_sending_req[0]            = ts0_sending_req ;
        i_ts1_sending_req[0]            = ts1_sending_req ;
        i_ts2_sending_req[0]            = ts2_sending_req ;
        i_ltssm_mod_ts[0]               = ltssm_mod_ts ;
        i_ltssm_ts_data_rate[0]         = ltssm_ts_data_rate ;
        i_ltssm_cmd[0]                  = ltssm_cmd_i ;
        i_ltssm_cmd_d[0]                = ltssm_cmd_i_d ;
        i_eqctl_eqts_info[0]            = eqctl_eqts_info ;
        i_ltssm_1b1b_cmd_4_eieos_req[0] = ltssm_1b1b_cmd_4_eieos_req | l0p_1b1b_upsizing_by_rcvry ;

        i_next_grant[1]                 = next_l0p_grant ;
        i_crnt_grant[1]                 = crnt_l0p_grant ;
        i_ts0_sending_req[1]            = 1'b0 ;
        i_ts1_sending_req[1]            = ts1_sending_req_l0p ;
        i_ts2_sending_req[1]            = ts2_sending_req_l0p ;
        i_ltssm_mod_ts[1]               = '0 ;
        i_ltssm_ts_data_rate[1]         = ltssm_ts_data_rate ;
        i_ltssm_cmd[1]                  = ltssm_l0p_cmd ;
        i_ltssm_cmd_d[1]                = ltssm_l0p_cmd_d ;
        i_eqctl_eqts_info[1]            = eqctl_eqts_info_l0p ;
        i_ltssm_1b1b_cmd_4_eieos_req[1] = ltssm_l0p_cmd_4_eieos_req | l0p_4_eie_for_1st ;
    
    // -- output from xmlh_os_gen.sv
        xmtbyte_ts_pcnt                = (crnt_l0p_state[L0P_UPSIZING_BIT] & (ltssm_cmd_i != `SEND_TS1)) ? o_xmtbyte_ts_pcnt[1]               :  o_xmtbyte_ts_pcnt[0] ;
        xmtbyte_ts_data_diff           = (crnt_l0p_state[L0P_UPSIZING_BIT] & (ltssm_cmd_i != `SEND_TS1)) ? o_xmtbyte_ts_data_diff[1]          :  o_xmtbyte_ts_data_diff[0] ;
        xmtbyte_1024_ts_sent           =  o_xmtbyte_1024_ts_sent[0] ;
        xmtbyte_spd_chg_sent           = (crnt_l0p_state[L0P_UPSIZING_BIT] & (ltssm_cmd_i != `SEND_TS1)) ? o_xmtbyte_spd_chg_sent[1]          :  o_xmtbyte_spd_chg_sent[0] ;
        xmtbyte_dis_link_sent          = (crnt_l0p_state[L0P_UPSIZING_BIT] & (ltssm_cmd_i != `SEND_TS1)) ? o_xmtbyte_dis_link_sent[1]         :  o_xmtbyte_dis_link_sent[0] ;
        xmtbyte_loe_2_ts1_ec_00b_sent  = (crnt_l0p_state[L0P_UPSIZING_BIT] & (ltssm_cmd_i != `SEND_TS1)) ? o_xmtbyte_loe_2_ts1_ec_00b_sent[1] :  o_xmtbyte_loe_2_ts1_ec_00b_sent[0] ;
        xmtbyte_ts1_sent               =  o_xmtbyte_ts1_sent[0] ;
        xmtbyte_ts2_sent               =  o_xmtbyte_ts2_sent[0] ;
        xmtbyte_fts_sent               =  o_xmtbyte_fts_sent[0] ;
        xmtbyte_eidle_sent             =  o_xmtbyte_eidle_sent[0] ;
        xmtbyte_eies_sent              =  o_xmtbyte_eies_sent[0] ;
        xmtbyte_skip_sent              =  o_xmtbyte_skip_sent_o[0] ;
        xmtbyte_skip_sent_o            =  xmtbyte_skip_sent ;
        xmtbyte_skip_insert            =  o_xmtbyte_skip_insert[0] ;
        xmtbyte_ctlskip_sent           =  o_xmtbyte_ctlskip_sent[0] ;
        xmtbyte_sent_24_ts0_ec00       =  o_xmtbyte_sent_24_ts0_ec00[0] ;
        xmtbyte_2_compliance_ts1_sent  =  o_xmtbyte_2_compliance_ts1_sent[0] ;
        xmtbyte_pat_fts_sent           =  o_xmtbyte_pat_fts_sent[0] ;
        xmtbyte_pat_eidle_start_sent   =  o_xmtbyte_pat_eidle_start_sent[0] ;
        xmtbyte_latched_loadpat_ltssmstate = o_xmtbyte_latched_loadpat_ltssmstate[0] ;
        xmtbyte_einj_in_os                 = o_xmtbyte_einj_in_os[0] ;
        os_gen_data                    =  o_os_gen_data[0] ;
        os_gen_datak                   =  o_os_gen_datak[0] ;
        os_gen_ossending               =  o_os_gen_ossending[0] ;
        os_send_done                   =  o_os_send_done[0] ;
        ossq_send_done                 =  o_ossq_send_done[0] ;
        os_gen_skp_os_align_sts        =  o_os_gen_skp_os_align_sts[0] ;
        dsp_tx_sris_cloking            =  o_dsp_tx_sris_cloking[0] ;
        crnt_ossq_num                  =  o_crnt_ossq_num[0] ;
        eie_pat_128b130b               = o_eie_pat_128b130b[0] ;
        skp_pat_128b130b               = o_skp_pat_128b130b[0] ;
        eie_pat_1b1b                   = o_eie_pat_1b1b[0] ;
        skp_pat_1b1b                   = o_skp_pat_1b1b[0] ;
        os_gen_data_l0p                =  o_os_gen_data[1] ;
        os_gen_datak_l0p               =  o_os_gen_datak[1] ;
        os_gen_ossending_l0p           =  o_os_gen_ossending[1] ;
        l0p_os_send_done               =  o_os_send_done[1] ;
        l0p_ossq_send_done             =  o_ossq_send_done[1] ;
        l0p_os_gen_skp_os_align_sts    =  o_os_gen_skp_os_align_sts[1] ;
        l0p_crnt_ossq_num              =  o_crnt_ossq_num[1] ;

        xmtbyte_l0p_eidle_sent         =  o_xmtbyte_eidle_sent[1] ;
        xmtbyte_l0p_ts1_sent           =  o_xmtbyte_ts1_sent[1] ;
        xmtbyte_l0p_ts2_sent           =  o_xmtbyte_ts2_sent[1] ;
    end

generate
    for( genvar ii = 0 ; ii < NUM_OS_GEN ; ii++ ) begin : xmlh_og_gen_inst  // [0]: Normal OS / [1]: L0p Up/Downsizing OS
         xmlh_os_gen
           u_xmlh_os_gen
            (
              .core_clk                               ( core_clk                               )
            , .core_rst_n                             ( core_rst_n                             )
        // --- input
            , .ltssm_cmd_i                            ( i_ltssm_cmd[ii]                        )
            , .ltssm_cmd_i_d                          ( i_ltssm_cmd_d[ii]                      )
            , .ltssm_eidle_cnt                        ( ltssm_eidle_cnt                        ) 
            , .cdm_ras_des_eidle_cnt_sel              ( cdm_ras_des_eidle_cnt_sel              ) 
            , .cfg_n_fts                              ( cfg_n_fts                              ) 
            , .ltssm_xlinknum                         ( ltssm_xlinknum                         ) 
            , .ltssm_xk237_4lnknum                    ( ltssm_xk237_4lnknum                    ) 
            , .ltssm_xk237_4lannum                    ( ltssm_xk237_4lannum                    ) 
            , .ltssm_ts_cntrl                         ( ltssm_ts_cntrl                         ) 
            , .ltssm_mod_ts                           ( i_ltssm_mod_ts[ii]                     ) 
            , .ltssm_ts_alt_protocol                  ( ltssm_ts_alt_protocol                  ) 
            , .ltssm_ts_alt_prot_info                 ( ltssm_ts_alt_prot_info                 ) 
            , .ltssm_ts_auto_change                   ( ltssm_ts_auto_change                   ) 
            , .ltssm_ts_data_rate                     ( i_ltssm_ts_data_rate[ii]               ) 
            , .ltssm_ts_speed_change                  ( ltssm_ts_speed_change                  ) 
            , .eqctl_eqts_info                        ( i_eqctl_eqts_info[ii]                  ) 
            , .eqctl_eqts_info_ts0                    ( eqctl_eqts_info_ts0                    ) 
            , .ltssm_cmd_compliance_ts1               ( ltssm_cmd_compliance_ts1               )
            , .ltssm_compliance_set_num               ( ltssm_compliance_set_num               )
            , .cfg_margin_control                     ( cfg_margin_control                     ) 
            , .smlh_ctlskp_info                       ( smlh_ctlskp_info                       ) 
            , .ltssm_flit_mode                        ( ltssm_flit_mode                        ) 
            , .ltssm_clear                            ( ltssm_clear                            ) 
            , .ltssm_dsp_g6_eq1_send_ec00             ( ltssm_dsp_g6_eq1_send_ec00             ) 
            , .app_sris_mode_i                        ( app_sris_mode_i                        ) 
            , .cfg_fast_link_mode                     ( cfg_fast_link_mode                     ) 
            , .smlh_ltssm_state                       ( smlh_ltssm_state                       ) 
            , .ltssm_flit_mode_enable                 ( ltssm_flit_mode_enable                 ) 
            , .cfg_flit_sris_clocking                 ( cfg_flit_sris_clocking                 ) 
            , .cfg_comm_clk_config                    ( cfg_comm_clk_config                    ) 
            , .smlh_link_up                           ( smlh_link_up                           ) 
            , .cfg_ext_synch                          ( cfg_ext_synch                          )
            , .latched_ts_nfts                        ( latched_ts_nfts                        )
            , .int_ltssm_in_lpbk                      ( int_ltssm_in_lpbk                      ) 
            , .lpbk_eq_lanes_active                   ( lpbk_eq_lanes_active                   )
            , .ltssm_in_lpbkentry                     ( ltssm_in_lpbkentry                     )
            , .smlh_link_mode                         ( smlh_link_mode                         ) 
            , .lpbk_master                            ( lpbk_master                            ) 
            , .active_nb                              ( active_nb                              ) 
            , .cfg_upstream_port                      ( cfg_upstream_port                      ) 
            , .crnt_rate                              ( crnt_rate                              ) 
            , .active_nb_bitmap                       ( active_nb_bitmap                       ) 
            , .active_nb_bitmapk                      ( active_nb_bitmapk                      ) 
            , .next_grant                             ( i_next_grant[ii]                       ) 
            , .crnt_grant                             ( i_crnt_grant[ii]                       ) 
            , .next_stream                            ( next_stream                            ) 
            , .crnt_stream                            ( crnt_stream                            ) 
            , .internal_txdata_dv                     ( internal_txdata_dv                     ) 
            , .internal_txdata_dv_pre                 ( internal_txdata_dv_pre                 ) 
            , .ctl_skp_enable                         ( ctl_skp_enable                         ) 
            , .ts0_sending_req                        ( i_ts0_sending_req[ii]                  ) 
            , .ts1_sending_req                        ( i_ts1_sending_req[ii]                  ) 
            , .ts2_sending_req                        ( i_ts2_sending_req[ii]                  ) 
            , .ltssm_1b1b_cmd_4_eieos_req             ( i_ltssm_1b1b_cmd_4_eieos_req[ii]       ) 
            , .l0p_inst                               ( ii[0]                                  ) 

        // --- output
            , .xmtbyte_ts_pcnt                        ( o_xmtbyte_ts_pcnt[ii]                  ) 
            , .xmtbyte_ts_data_diff                   ( o_xmtbyte_ts_data_diff[ii]             ) 
            , .xmtbyte_1024_ts_sent                   ( o_xmtbyte_1024_ts_sent[ii]             ) 
            , .xmtbyte_spd_chg_sent                   ( o_xmtbyte_spd_chg_sent[ii]             ) 
            , .xmtbyte_dis_link_sent                  ( o_xmtbyte_dis_link_sent[ii]            ) 
            , .xmtbyte_loe_2_ts1_ec_00b_sent          ( o_xmtbyte_loe_2_ts1_ec_00b_sent[ii]    ) 
            , .xmtbyte_ts1_sent                       ( o_xmtbyte_ts1_sent[ii]                 ) 
            , .xmtbyte_ts2_sent                       ( o_xmtbyte_ts2_sent[ii]                 ) 
            , .xmtbyte_fts_sent                       ( o_xmtbyte_fts_sent[ii]                 ) 
            , .xmtbyte_eidle_sent                     ( o_xmtbyte_eidle_sent[ii]               ) 
            , .xmtbyte_eies_sent                      ( o_xmtbyte_eies_sent[ii]                ) 
            , .xmtbyte_skip_sent_o                    ( o_xmtbyte_skip_sent_o[ii]              ) 
            , .xmtbyte_skip_insert                    ( o_xmtbyte_skip_insert[ii]              ) 
            , .xmtbyte_ctlskip_sent                   ( o_xmtbyte_ctlskip_sent[ii]             ) 
            , .xmtbyte_sent_24_ts0_ec00               ( o_xmtbyte_sent_24_ts0_ec00[ii]         ) 
            , .xmtbyte_2_compliance_ts1_sent          ( o_xmtbyte_2_compliance_ts1_sent[ii]    )
            , .xmtbyte_pat_fts_sent                   ( o_xmtbyte_pat_fts_sent[ii]             ) 
            , .xmtbyte_pat_eidle_start_sent           ( o_xmtbyte_pat_eidle_start_sent[ii]     ) 
            , .xmtbyte_latched_loadpat_ltssmstate     ( o_xmtbyte_latched_loadpat_ltssmstate[ii] )
            , .xmtbyte_einj_in_os                     ( o_xmtbyte_einj_in_os[ii]               )
            , .os_gen_data                            ( o_os_gen_data[ii]                      ) 
            , .os_gen_datak                           ( o_os_gen_datak[ii]                     ) 
            , .os_gen_ossending                       ( o_os_gen_ossending[ii]                 ) 
            , .os_send_done                           ( o_os_send_done[ii]                     ) 
            , .ossq_send_done                         ( o_ossq_send_done[ii]                   ) 
            , .dsp_tx_sris_cloking                    ( o_dsp_tx_sris_cloking[ii]              ) 
            , .crnt_ossq_num                          ( o_crnt_ossq_num[ii]                    )
            , .os_gen_skp_os_align_sts                ( o_os_gen_skp_os_align_sts[ii]          )
            , .eie_pat_128b130b                       ( o_eie_pat_128b130b[ii]                 )
            , .skp_pat_128b130b                       ( o_skp_pat_128b130b[ii]                 )
            , .eie_pat_1b1b                           ( o_eie_pat_1b1b[ii]                     )
            , .skp_pat_1b1b                           ( o_skp_pat_1b1b[ii]                     )

        );
    end
endgenerate


// ----------------- xmlh_cmp_gen --------------------
    xmlh_cmp_gen
     u_xmlh_cmp_gen 
        (
              .core_clk                               ( core_clk                               )
            , .core_rst_n                             ( core_rst_n                             )
            //  --- input
            , .ltssm_gen4_compliance_jmp              ( ltssm_gen4_compliance_jmp              )
            , .ltssm_gen6_compliance_tp               ( ltssm_gen6_compliance_tp               )
            , .smlh_mcs_rcvd                          ( smlh_mcs_rcvd                          )
            , .rpipe_rxerror                          ( rpipe_rxerror                          )
            , .eqctl_pset_ltx                         ( eqctl_pset_ltx                         )
            , .smlh_gen3_error_count_i                ( smlh_gen3_error_count_i                )
            , .smlh_no_turnoff_lanes                  ( smlh_no_turnoff_lanes                  )
            , .active_nb                              ( active_nb                              )
            , .crnt_rate                              ( crnt_rate                              )
            , .active_nb_bitmap                       ( active_nb_bitmap                       )
            , .active_nb_bitmapk                      ( active_nb_bitmapk                      )
            , .active_nb_bytemap                      ( active_nb_bytemap                      )
            , .next_grant                             ( next_grant                             )
            , .crnt_grant                             ( crnt_grant                             )
            , .internal_txdata_dv                     ( internal_txdata_dv                     )
            , .int_data_ltssm_lanes_active            ( int_data_ltssm_lanes_active            )
            , .int_l0p_ltssm_lanes_active             ( int_l0p_ltssm_lanes_active             )
            , .sris_mode_on                           ( sris_mode_on                           )
            , .eie_pat_128b130b                       ( eie_pat_128b130b                       )
            , .skp_pat_128b130b                       ( skp_pat_128b130b                       )
            , .eie_pat_1b1b                           ( eie_pat_1b1b                           )
            , .skp_pat_1b1b                           ( skp_pat_1b1b                           )
            // --- output
            , .xmtbyte_gen6_compliance_sending        ( xmtbyte_gen6_compliance_sending        )
            , .cmp_gen_data                           ( cmp_gen_data                           )
            , .cmp_gen_datak                          ( cmp_gen_datak                          )
            , .cmp_gen_ossending                      ( cmp_gen_ossending                      )
            , .int_txcompliance                       ( int_txcompliance                       )
            , .cmp_block_done                         ( cmp_block_done                         )
            , .mcmp_gen6_skp_in_progress              ( mcmp_gen6_skp_in_progress              )
            , .mcmp_gen6_skp_done                     ( mcmp_gen6_skp_done                     )
        );
        


// ----------------- xmlh_data_gen --------------------
    xmlh_data_gen
     u_xmlh_data_gen
        (
              .core_clk                               ( core_clk                               )
            , .core_rst_n                             ( core_rst_n                             ) 
            // --- input
            , .xdlh_xmlh_stp_i                        ( xdlh_xmlh_stp_i                        )
            , .xdlh_xmlh_sdp_i                        ( xdlh_xmlh_sdp_i                        )
            , .xdlh_xmlh_eot_i                        ( xdlh_xmlh_eot_i                        )
            , .next_xdlh_xmlh_eot_i                   ( next_xdlh_xmlh_eot_i                   )
            , .xdlh_xmlh_pad_i                        ( xdlh_xmlh_pad_i                        )
            , .next_xdlh_xmlh_stp_i                   ( next_xdlh_xmlh_stp_i                   )
            , .next_xdlh_xmlh_sdp_i                   ( next_xdlh_xmlh_sdp_i                   )
            , .xdlh_xmlh_data_i                       ( xdlh_xmlh_data_i                       )
            , .xdlh_xmlh_pid                          ( xdlh_xmlh_pid                          )
            , .ltssm_cmd_i                            ( ltssm_cmd_i                            )
            , .ltssm_cxl_sh_bypass                    ( ltssm_cxl_sh_bypass                    )
            , .cxl_mode_enable                        ( cxl_mode_enable                        )
            , .smlh_ltssm_state                       ( smlh_ltssm_state                       )
            , .lpbk_master                            ( lpbk_master                            )
            , .ltssm_in_lpbk_active                   ( ltssm_in_lpbk_active                   )
            , .cfg_prbs_en                            ( cfg_prbs_en                            )
            , .active_nb                              ( active_nb                              )
            , .ltssm_flit_mode_enable                 ( ltssm_flit_mode_enable                 )
            , .crnt_rate                              ( crnt_rate                              )
            , .next_grant                             ( next_grant                             )
            , .crnt_grant                             ( crnt_grant                             )
            , .next_stream                            ( next_stream                            )
            , .crnt_stream                            ( crnt_stream                            )
            , .internal_txdata_dv                     ( internal_txdata_dv                     )
            , .internal_txdata_dv_pre                 ( internal_txdata_dv_pre                 )
            , .internal_txstartblock                  ( internal_txstartblock                  )
            , .internal_txendblock                    ( internal_txendblock                    )
            , .internal_txtblock_symbol_cnt           ( internal_txtblock_symbol_cnt           )
            , .int_data_ltssm_lanes_active            ( int_data_ltssm_lanes_active            )
            , .int_data_smlh_link_mode                ( int_data_smlh_link_mode                )
            , .int_data_ltssm_lanes_active_pre        ( int_data_ltssm_lanes_active_pre        )
            , .int_data_smlh_link_mode_pre            ( int_data_smlh_link_mode_pre            )
            , .mask_tlp_dllp_timing                   ( mask_tlp_dllp_timing                   )
            , .in_data_progress                       ( in_data_progress                       )
            , .in_idle_data_progress                  ( in_idle_data_progress                  )

            // --- output
            , .xmtbyte_xdlh_halt_o                    ( xmtbyte_xdlh_halt_o                    )
            , .xmtbyte_idle_sent                      ( xmtbyte_idle_sent                      )
            , .data_gen_data                          ( data_gen_data                          )
            , .data_gen_datak                         ( data_gen_datak                         )
            , .last_chunk                             ( last_chunk                             )
            , .eds_ack                                ( eds_ack                                )
        );




`ifndef SYNTHESIS
//VCS coverage off
wire    [(21*8)-1:0]        LTSSM_CMD;
wire    [(21*8)-1:0]        LTSSM_CMD_D;

assign  LTSSM_CMD =
               ( ltssm_cmd_i == `SEND_IDLE             ) ? "SEND_IDLE" :
               ( ltssm_cmd_i == `SEND_EIDLE            ) ? "SEND_EIDLE" :
               ( ltssm_cmd_i == `XMT_IN_EIDLE          ) ? "XMT_IN_EIDLE" :
               ( ltssm_cmd_i == `SEND_RCVR_DETECT_SEQ  ) ? "SEND_RCVR_DETECT_SEQ" :
               ( ltssm_cmd_i == `SEND_TS1              ) ? "SEND_TS1" :
               ( ltssm_cmd_i == `SEND_TS2              ) ? "SEND_TS2" :
               ( ltssm_cmd_i == `COMPLIANCE_PATTERN    ) ? "COMPLIANCE_PATTERN" :
               ( ltssm_cmd_i == `MOD_COMPL_PATTERN     ) ? "MOD_COMPL_PATTERN" :
               ( ltssm_cmd_i == `SEND_BEACON           ) ? "SEND_BEACON" :
               ( ltssm_cmd_i == `SEND_N_FTS            ) ? "SEND_N_FTS" :
               ( ltssm_cmd_i == `NORM                  ) ? "NORM" :
                                                           "Bogus";
                                                         
assign  LTSSM_CMD_D =
               ( ltssm_cmd_i_d == `SEND_IDLE             ) ? "SEND_IDLE" :
               ( ltssm_cmd_i_d == `SEND_EIDLE            ) ? "SEND_EIDLE" :
               ( ltssm_cmd_i_d == `XMT_IN_EIDLE          ) ? "XMT_IN_EIDLE" :
               ( ltssm_cmd_i_d == `SEND_RCVR_DETECT_SEQ  ) ? "SEND_RCVR_DETECT_SEQ" :
               ( ltssm_cmd_i_d == `SEND_TS1              ) ? "SEND_TS1" :
               ( ltssm_cmd_i_d == `SEND_TS2              ) ? "SEND_TS2" :
               ( ltssm_cmd_i_d == `COMPLIANCE_PATTERN    ) ? "COMPLIANCE_PATTERN" :
               ( ltssm_cmd_i_d == `MOD_COMPL_PATTERN     ) ? "MOD_COMPL_PATTERN" :
               ( ltssm_cmd_i_d == `SEND_BEACON           ) ? "SEND_BEACON" :
               ( ltssm_cmd_i_d == `SEND_N_FTS            ) ? "SEND_N_FTS" :
               ( ltssm_cmd_i_d == `NORM                  ) ? "NORM" :
                                                             "Bogus";

wire    [(21*8)-1:0]        LTSSM_L0P_CMD;

assign  LTSSM_L0P_CMD =
               ( ltssm_l0p_cmd == `SEND_IDLE             ) ? "SEND_IDLE" :
               ( ltssm_l0p_cmd == `SEND_EIDLE            ) ? "SEND_EIDLE" :
               ( ltssm_l0p_cmd == `XMT_IN_EIDLE          ) ? "XMT_IN_EIDLE" :
//             ( ltssm_l0p_cmd == `SEND_RCVR_DETECT_SEQ  ) ? "SEND_RCVR_DETECT_SEQ" :
               ( ltssm_l0p_cmd == `SEND_TS1              ) ? "SEND_TS1" :
               ( ltssm_l0p_cmd == `SEND_TS2              ) ? "SEND_TS2" :
//             ( ltssm_l0p_cmd == `COMPLIANCE_PATTERN    ) ? "COMPLIANCE_PATTERN" :
//             ( ltssm_l0p_cmd == `MOD_COMPL_PATTERN     ) ? "MOD_COMPL_PATTERN" :
//             ( ltssm_l0p_cmd == `SEND_BEACON           ) ? "SEND_BEACON" :
//             ( ltssm_l0p_cmd == `SEND_N_FTS            ) ? "SEND_N_FTS" :
               ( ltssm_l0p_cmd == `NORM                  ) ? "NORM" :
                                                             "Bogus";

//VCS coverage on
`endif // SYNTHESIS

endmodule


