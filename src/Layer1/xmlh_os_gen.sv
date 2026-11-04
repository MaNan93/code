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
// ---    $Id: //dwh/pcie_iip/main/fairbanks/design/Layer1/xmlh_os_gen.sv#3 $
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

 
 module xmlh_os_gen 
  import xmlh_pkg::*;
  import DWC_pcie_core_pkg::ltssm_state_e;
  import DWC_pcie_core_pkg::S_DETECT_QUIET;
  import DWC_pcie_core_pkg::S_DETECT_ACT;
  import DWC_pcie_core_pkg::S_POLL_ACTIVE;
  import DWC_pcie_core_pkg::S_POLL_COMPLIANCE;
  import DWC_pcie_core_pkg::S_PRE_DETECT_QUIET;
  import DWC_pcie_core_pkg::S_CFG_LINKWD_START;
  import DWC_pcie_core_pkg::S_CFG_LINKWD_ACEPT;
  import DWC_pcie_core_pkg::S_CFG_LANENUM_WAIT;
  import DWC_pcie_core_pkg::S_CFG_LANENUM_ACEPT;
  import DWC_pcie_core_pkg::S_CFG_COMPLETE;
  import DWC_pcie_core_pkg::S_RCVRY_LOCK;
  import DWC_pcie_core_pkg::S_RCVRY_SPEED;
  import DWC_pcie_core_pkg::S_RCVRY_RCVRCFG;
  import DWC_pcie_core_pkg::S_RCVRY_IDLE;
  import DWC_pcie_core_pkg::S_LPBK_ENTRY;
  import DWC_pcie_core_pkg::S_HOT_RESET_ENTRY;
  import DWC_pcie_core_pkg::S_HOT_RESET;
  import DWC_pcie_core_pkg::S_RCVRY_EQ0;
  import DWC_pcie_core_pkg::S_RCVRY_EQ1;
  import DWC_pcie_core_pkg::S_RCVRY_EQ2;
  import DWC_pcie_core_pkg::S_RCVRY_EQ3;
  import DWC_pcie_core_pkg::xmlh_einj_in_os_t;
    
                     (
      input  logic                                      core_clk 
    , input  logic                                      core_rst_n 

// =============================================================================
//  input IO Declarations
// =============================================================================

// Received sending OS/Compliance pattern request from LTSSM
    , input  logic  [3:0]                               ltssm_cmd_i                            // encoded command to notify transmitter of the proper action based on LTSSM states
    , input  logic  [3:0]                               ltssm_cmd_i_d                          // 1cycle delay of ltssm_cmd_i
    , input  logic  [2:0]                               ltssm_eidle_cnt                        // 4 bits, indicates how many EIOS sets to send before returning xmtbyte_eidle_sent.  0=1 EIOS, 1=2 EIOS, etc.
    , input  logic  [1:0]                               cdm_ras_des_eidle_cnt_sel              // Number of Transmit E-IDLE ordered set for Ras D.E.S Silicon Debug
                                                                                               // 0x0 : (2.5GT/s,8.0GT/s or higher) 1 or (5.0GT/s ) 2
                                                                                               // 0x1 : (2.5GT/s,8.0GT/s or higher) 4 or (5.0GT/s ) 8
                                                                                               // 0x2 : (2.5GT/s,8.0GT/s or higher) 8 or (5.0GT/s ) 16
                                                                                               // 0x3 : (2.5GT/s,8.0GT/s or higher) 16 or (5.0GT/s ) 32

// Information to make OS
    , input  logic  [7:0]                               cfg_n_fts                              // 8bits bus to specify the number of FTS we wish to receive for our receiver. Set this value on TS Flit Mode bit(Symbol3 [7:0])
    , input  logic  [7:0]                               ltssm_xlinknum                         // 8bits indicate link number to be inserted in training sequence, if ltssm_xk237_4lnknum =0
    , input  logic  [NL-1:0]                            ltssm_xk237_4lnknum                    // 1 bit per lane, 1 : K237 / 0 : send link number(ltssm_xlinknum) of TS Symbol 1[7:0]
    , input  logic  [NL-1:0]                            ltssm_xk237_4lannum                    // 1 bit per lane, 1 : K237 / 0 : send lane number of TS Symbol 2[7:0]
    , input  logic  [7:0]                               ltssm_ts_cntrl                         // training sequence control. Set this value on TS Symbol5 [7:0]
    , input  logic                                      ltssm_mod_ts                           // Tx modified TS should be sent if 1.
    , input  logic                                      ltssm_ts_alt_protocol                  // Indicates Alternate protocol is used. Replace Modified TS Symbol8-14 to ltssm_ts_alt_prot_info if this signal is 1.
    , input  logic  [55:0]                              ltssm_ts_alt_prot_info                 // Value of Modified TS Symbol8-14, if Alternate Protocol 
    , input  logic                                      ltssm_ts_auto_change                   // autonomous change/upconfig capable/select de-emphasis bit.  Set this value on TS Symbol4 [6].
    , input  logic  [4:0]                               ltssm_ts_data_rate                     // Data rate to advertise support for in the ts.  bits 4:1 of the data rate identifier field.Set this value on TS Flit Mode bit(Symbol4 [5:1])
    , input  logic                                      ltssm_ts_speed_change                  // Value to put in the speed change bit of TS ordered sets.Set this value on TS Flit Mode bit(Symbol4 [7])
    , input  logic  [NL*EQTS_WD-1:0]                    eqctl_eqts_info                        // Equalization Information, Set this value on EQ TS Symbols 6-9 of EQ TSs for Gen3 or above.
    , input  logic  [NL*TS_0_WD-1:0]                    eqctl_eqts_info_ts0                    // Equalization Information for Symbols 1-4 of EQ TS0s
    , input  logic                                      ltssm_cmd_compliance_ts1               // sending two Compliance TS1 in Polling.Compliance  
    , input  logic  [7:0]                               ltssm_compliance_set_num               // compliance setting number for sending Compliance TS1 in Polling.Compliance  
    , input  logic [NL*16-1:0]                          cfg_margin_control                     // Margining Control [2:0] Receiver Number[5:3]Margin Type[6]Usage Molde[7]Rsvd[15:8]Margin Payload. This value is Control SKP Symbol13-15 of Downstream Port
    , input  logic [NL*16-1:0]                          smlh_ctlskp_info                       // Margining Status  [2:0] Receiver Number[5:3]Margin Type[6]Usage Molde[7]Rsvd[15:8]Margin Payload. This value is Control SKP Symbol13-15 of Downstream Port
    , input  logic                                      ltssm_flit_mode                        // Indicates FLIT mode supporting. Set this value on TS1 Flit Mode bit(Symbol4 [0])

// Return sedning OS response to LTSSM
    , input  logic                                      ltssm_clear                            // used to clear persistency count when a ltssm state transition
    , input  logic                                      ltssm_dsp_g6_eq1_send_ec00             // 1, dsp xmlh starts to send 24 ts0s with ec=00b in eq1. Clear xmtbyte_ts_cnt when posedge of this signal. Restart count xmtbyte_sent_24_ts0_ec00 when posedge of this signal.

// Mode/State signals
    , input  logic                                      app_sris_mode_i                        // application signal to enable the SRIS mode
    , input  logic                                      cfg_fast_link_mode                     // Indicates how many TS1 are sent in Polling.Active. 0:1024(Spec) / 1:16(to reduce SIM time)
    , input  ltssm_state_e                              smlh_ltssm_state                       // LTSSM State
    , input  logic                                      ltssm_flit_mode_enable                 // Indicates Flit Mode is enabled.
    , input  logic                                      cfg_flit_sris_clocking                 // Enable SRIS mode form LTSSM for Flit Mode
    , input  logic                                      cfg_comm_clk_config                    // Enable Common Clock(Non-SRIS) mode form LTSSM for Flit Mode
    , input  logic                                      smlh_link_up                           // Indicates LTSSM is LinkUp when CX_FLIT_MODE_ENABLE
    , input  logic                                      cfg_ext_synch                          // Extended synch for N_FTS configured in CDM
    , input  logic  [7:0]                               latched_ts_nfts                        // latched number of fast training sequence number from TS ordered set of receiver
    , input  logic                                      int_ltssm_in_lpbk                      // LTSSM in any Loopback state
    , input  logic  [NL-1:0]                            lpbk_eq_lanes_active                   // One active lane from the cfg_lane_under_test
    , input  logic                                      ltssm_in_lpbkentry                     // LTSSM in Loopback.Entry state
    , input  logic  [5:0]                               smlh_link_mode                         // 10000 -- x16, 01000 -- x8, 00100 -- x4, 00010 -- x2, 00001 -- x1
    , input  logic                                      lpbk_master                            // indicates that the ltssm is the loopback master
    , input  logic  [AW-1:0]                            active_nb                              // active number of symbols per lane per clock. bit0=1s, bit1=2s, bit2=4s, bit3=8s , bit4=16s
    , input  logic                                      cfg_upstream_port                      // 1: Upstream Port / 0:Downstream Port
    , input  logic                                      ltssm_1b1b_cmd_4_eieos_req              // 4 eieos request at gen6 rate

// Internal xmlh_byte_xmt signals (common)
    , input  data_rate_enc_t                            crnt_rate                               // current data rate shortcut.
    , input  logic  [NBIT-1:0]                          active_nb_bitmap                        // active number of symbols per lane bitmap
    , input  logic  [NBK-1:0]                           active_nb_bitmapk                       // active number of symbols per lane bitmap (for DataK)
    
// Internal xmlh_byte_xmt signals (xmlh_os_gen (from instance 0(Normal) to instance 1(L0p))

// Internal xmlh_byte_xmt signals (xmlh_arb_ctl)
    , input  grant_t                                    next_grant                              // Arbitration grant (next)
    , input  grant_t                                    crnt_grant                              // Arbitration grant (Current)
    , input  stream_t                                   next_stream                             // Indicates Current Stream(Data/OS/CMP or EIDLE) (Next)
    , input  stream_t                                   crnt_stream                             // Indicates Current Stream(Data/OS/CMP or EIDLE) (Current)
    , input  logic                                      internal_txdata_dv                      // Data Valid, gen1/gen2: always 1, gen3: 0 for one cycle every 4*active_nb blocks
    , input  logic                                      internal_txdata_dv_pre                  // 1 cycle before of internal_txdata_dv
    , input  logic                                      ctl_skp_enable                          // Indicates Control SKP should be set if 1.
    , input  logic                                      ts0_sending_req                         // Indicates Sending TS0 request 
    , input  logic                                      ts1_sending_req                         // Indicates Sending TS1 request 
    , input  logic                                      ts2_sending_req                         // Indicates Sending TS2 request 

// Instance number
    , input  logic                                      l0p_inst                                // Instantiated this module for L0p

// =============================================================================
// output IO Declarations
// =============================================================================

// Return sedning OS response to LTSSM
    , output logic [10:0]                               xmtbyte_ts_pcnt                         // transmit ts persistency count
    , output logic                                      xmtbyte_ts_data_diff                    // current ts data different from previous
    , output logic                                      xmtbyte_1024_ts_sent                    // 1024 ts sent in a state
    , output logic                                      xmtbyte_spd_chg_sent                    // Indicates 1 TS1/2 that speed_change bit=1 is sent.
    , output logic                                      xmtbyte_dis_link_sent                   // Indicates 1 TS1/2 that disable link=1 is sent
    , output logic                                      xmtbyte_loe_2_ts1_ec_00b_sent           // no more than 2 ts1 with ec==00b sent. This signal is only used in R.Lock (send TS1 only), so no need xmtbyte_ts1_sent
    , output logic [OS_WD-1:0]                          xmtbyte_ts1_sent                        // Indicates 1 TS1 ordered is sent (1shot. Asserted 1st cycle of a packet)
    , output logic [OS_WD-1:0]                          xmtbyte_ts2_sent                        // Indicates 1 TS2 ordered is sent (1shot. Asserted 1st cycle of a packet)
    , output logic                                      xmtbyte_fts_sent                        // Indicates all FTS is sent (1shot. Asserted 1st cycle of a packet)
    , output logic                                      xmtbyte_eidle_sent                      // Indicates EIOS pattern(all continuous EIOS) is completed to send (1shot. Asserted 1st cycle of a packet)
    , output logic                                      xmtbyte_eies_sent                       // Indicates 1 EIEOS is sent (1shot. Asserted 1st cycle of a packet)
    , output logic                                      xmtbyte_skip_sent_o                     // Indicates 1 SKP OS is sent (1shot. Asserted 1st cycle of a packet)
    , output logic                                      xmtbyte_skip_insert                     // Indicates 1 SKP OS that is scheduled Periodically in DataStream , loopback lead. Not used
    , output logic                                      xmtbyte_ctlskip_sent                    // Indicates 1 Control SKP OS is sent (1shot. Asserted 1st cycle of a packet)
    , output logic                                      xmtbyte_sent_24_ts0_ec00                // Indicates 24 or above TS0 with ec=00b is sent by Downstream Port for EQ.Phase1.
    , output logic                                      xmtbyte_2_compliance_ts1_sent           // Indicates 2 Compliance TS1 ordered set has been sent based on LTSSM's command  
    , output logic                                      xmtbyte_pat_fts_sent                    // Indicates 1 FTS OS  is sent (1shot. Asserted 1st cycle of a packet)
    , output logic                                      xmtbyte_pat_eidle_start_sent            // Indicates EIOS is sent (pulse even if continus EIOS sending) (1shot. Asserted 1st cycle of a packet)

// Flit Error injection signals
    , output ltssm_state_e                              xmtbyte_latched_loadpat_ltssmstate      // LTSSM state aligned with xmtbyte_txdata.
    , output xmlh_einj_in_os_t                          xmtbyte_einj_in_os                      // Indicates which OS is sending align with xmtbyte_txdata.

// Internal xmlh_byte_xmt signals (xmlh_os_gen (from instance 0(Normal) to instance 1(L0p))

// Internal xmlh_byte_xmt signals (xmlh_arb_ctl)
    , output logic  [NL-1:0][NBIT-1:0]                  os_gen_data                             // OS Data
    , output logic  [NL-1:0][NBK-1:0]                   os_gen_datak                            // OS Data Kcode
    , output logic  [NL-1:0][NBLOCK-1:0][OSFLG_WD-1:0]  os_gen_ossending                        // Sending OS Flag 
    , output logic                                      os_send_done                            // Indicated the last cycle of a OS sending.
    , output logic                                      ossq_send_done                          // Asserted when last cycle of OSSQ sending
    , output logic                                      dsp_tx_sris_cloking                     // Downstream Port SRIS Mode
    , output logic [4:0]                                crnt_ossq_num                           // Indicated the number of OS should be sent in current OSSQ. (0's base)
    , output skp_replace_t                              os_gen_skp_os_align_sts                 // Indicates current sending Data have LFSR/Parity field of SKP OS

// Internal xmlh_byte_xmt signals (xmlh_cmp_gen)
    , output logic [127:0]                              eie_pat_128b130b                        // EIE OS data for Gen/3/4/5
    , output logic [127:0]                              skp_pat_128b130b                        // SKP OS data for Gen/3/4/5
    , output logic [127:0]                              eie_pat_1b1b                            // EIE OS data for Gen6
    , output logic [319:0]                              skp_pat_1b1b                            // SKP OS data for Gen6

    );



// -----------------------------------
//  Typedef
// -----------------------------------
  typedef struct packed {
    logic [NL-1:0][127:0]                ts0_pat ;                               // TS0 OS data 
    logic [NL-1:0][127:0]                ts1_pat ;                               // TS1 OS data 
    logic [NL-1:0][127:0]                ts2_pat ;                               // TS2 OS data 
    logic [NL-1:0][NBLOCK*128-1:0]       skp_pat ;                               // SKP OS data 
    logic [NL-1:0][127:0]                ei__pat ;                               // EI OS data 
    logic [NL-1:0][127:0]                eie_pat ;                               // EIE OS data 
    logic [NL-1:0][127:0]                eie_8sym_pat ;                          // Eight EIE Symbol data just for Gen2
    logic [NL-1:0][127:0]                fts_pat ;                               // FTS OS data 
    logic [NL-1:0][127:0]                sds_pat ;                               // SDS OS data 
    logic [NL-1:0][15:0]                 ts0_pat_k ;                             // TS0 OS datak 
    logic [NL-1:0][15:0]                 ts1_pat_k ;                             // TS1 OS datak 
    logic [NL-1:0][15:0]                 ts2_pat_k ;                             // TS2 OS datak 
    logic [NL-1:0][NBLOCK*16-1:0]        skp_pat_k ;                             // SKP OS datak 
    logic [NL-1:0][15:0]                 ei__pat_k ;                             // EI OS datak 
    logic [NL-1:0][15:0]                 eie_pat_k ;                             // EIE OS datak 
    logic [NL-1:0][15:0]                 eie_8sym_pat_k ;                        // Eight EIE Symbol datal just for Gen2
    logic [NL-1:0][15:0]                 fts_pat_k ;                             // FTS OS datak 
    logic [NL-1:0][15:0]                 sds_pat_k ;                             // SDS OS datak 
  } os_pat_t ;


// -----------------------------------
//  Declaration
// -----------------------------------
    os_pat_t                             enc_8b10b ;                             // OS Data for 8b/10b
    os_pat_t                             enc_128b130b ;                          // OS Data for 128b/130b
    os_pat_t                             enc_1b1b ;                              // OS Data for 1b/11b
    os_pat_t                             crnt_rate_os_pat ;                      // Current Rate OS
    logic [5:0]                          os_byte_count ;                         // Indicated how many OS bytes are sent
    logic                                os_send_start_wo_dv ;                   // Indicated the 1st cycle of a OS sending.(Without DataValid)
    logic                                os_send_start ;                         // Indicated the 1st cycle of a OS sending.
    logic [4:0]                          os_send_num ;                           // Indicated how many OS should by sent in this OSSQ (0's base)
    logic [NBLOCK-1:0]                   active_block ;                          // Indicated how many blocks in a cycle(bitmap). 
    logic [6:0]                          next_os_size ;                          // Indicated OS Size in byte(1's base)
    logic [6:0]                          crnt_os_size ;                          // Indicated OS Size in byte(1's base)
    logic [5:0]                          crnt_os_size_minus_nb ;                 // Indicated OS Size in byte(1's base)
    logic [4:0]                          next_ossq_num ;                         // Indicated the number of OS should be sent in current OSSQ. (0's base)

    logic [NL-1:0][NBLOCK*128-1:0]       crnt_os_pat ;                           // Current Grant OS Data
    logic [NL-1:0][NBLOCK*16-1:0]        crnt_os_pat_k ;                         // Current Grant OS K code
    logic [NL-1:0][NBIT-1:0]             shift_os_data ;                         // Shift OS Data for data width alignment
    logic [NL-1:0][NBK-1:0]              shift_os_datak ;                        // Shift OS DataK for data width alignment
    logic [NL-1:0][NBLOCK*128-1:0]       crnt_os_pat_d ;                         // 1 cycle delay of crnt_os_pat
    logic [NL-1:0][NBLOCK*128-1:0]       latched_os_data ;                       // Shift OS Data for data width alignment
    logic                                tx_os_done ;                            // Last cycle of OS send
    logic                                next_grnt_is_os ;                       // Indicates next grant is any OS
    logic                                crnt_grnt_is_os ;                       // Indicates current grant is any OS
    logic                                load_field ;                            // Indicates Loading OS field timing from LTSSM
    logic                                ltssm_cfg_state ;                       // LTSSM is in any Configuration State
    logic                                ltssm_hotreset_state ;                  // LTSSM is in any HotresetState
    logic                                ltssm_recovery_state ;                  // LTSSM is in any Recovery State
    logic                                ltssm_lpbk_entry_state ;                // LTSSM is in Loopback Entry
    logic [NL-1:0][7:0]                  ts1_sym1_link_comb ;                    // TS1 Symbol1     : Link#
    logic [NL-1:0][7:0]                  ts1_sym2_lane_comb ;                    // TS1 Symbol2     : Lane#
    grant_t                              before_grant ;                          // previous 1 current grant
    grant_t                              crnt_grant_d ;                          // 1 cycle delay current grant
    logic [NBLOCK-1:0]                   update_ts_cnt ;                         // Indicates how many TS is sent in this cycle.
    logic [OS_WD-1:0]                    xmtbyte_ts0_sent ;                      // TS0 sent flag
    logic                                int_fts_sent ;                          // FTS sent flag
    logic [13:0]                         exp_nfts ;                              // The number of FTS should be sent
    logic [13:0]                         nfts_count ;                            // The number of FTS should be sent
    logic                                nfts_expire_next ;                      // Indicates the next FTS expire N_FTS.

    logic [NL-1:0][7:0]                  ts1_sym1_link ;                         // TS1 Symbol1     : Link#
    logic [NL-1:0][7:0]                  ts1_sym2_lane ;                         // TS1 Symbol2     : Lane#
    logic [7:0]                          ts1_sym2_nfts ;                         // TS1 Symbol3     : N_FTS
    logic                                ts1_sym4_flit ;                         // TS1 Symbol4 [0]
    logic [4:0]                          ts1_sym4_rate ;                         // TS1 Symbol4 [5:1]
    logic                                ts1_sym4_bit6 ;                         // TS1 Symbol4 [6]
    logic                                sris_clocking ;                         // TS1 Symbol4 [7]
    logic                                ts1_sym4_bit7 ;                         // TS1 Symbol4 [7]
    logic [7:0]                          ts1_sym5_tctl ;                         // TS1 Symbol5     : Training Control
    logic [NL-1:0][31:0]                 ts1_sym6_to_9 ;                         // TS1 Symbol9-9 for Compliance TS1 (Gen1)
    logic [NL-1:0][EQTS_WD-1:0]          ts1_sym6_to_9_eq_normal ;               // TS1 Symbol9-9 for EQ or normal
    logic [55:0]                         mt1_sym8_to_14 ;                        // Modified TS1 Symbol8-14
    logic [NL-1:0][7:0]                  mt1_sym15_par ;                         // Modified TS1 Symbol15
    logic [NL-1:0][7:0]                  mt2_sym15_par ;                         // Modified TS1 Symbol15
    logic [NL-1:0]                       ts1_sym1_link_k ;                       // TS1 Symbol1 Kcode    : Link#
    logic [NL-1:0]                       ts1_sym2_lane_k ;                       // TS1 Symbol1 Kcode    : Lane#
    logic [NL-1:0][127:0]                st1_pat_8b10b ;                         // Standard TS1 OS data 
    logic [NL-1:0][127:0]                st2_pat_8b10b ;                         // Standard TS2 OS data 
    logic [NL-1:0][127:0]                mt1_pat_8b10b ;                         // Modified TS1 OS data 
    logic [NL-1:0][127:0]                mt2_pat_8b10b ;                         // Modified TS2 OS data 
    logic                                load_ltssm_ts_speed_change ;            // Loaded load_ltssm_ts_speed_change
    logic                                load_ltssm_mod_ts ;                     // Loaded ltssm_mod_ts
    logic                                load_ltssm_cmd_compliance_ts1 ;         // Loaded ltssm_cmd_compliance_ts1
    logic [NBLOCK-1:0]                   sending_skpend ;                        // Sending SKP End symbol on this cycle.
    logic [7:0]                          skp_symbol_128b130b ;                   // Skip Symbol for 128b/130b
    logic [7:0]                          skp_end_128b130b ;                      // Skip End for 128b/130b
    logic [NL-1:0][23:0]                 sskp_lfsr_128b130b ;                    // Standard Skip Symbol13-15 for 128b/130b
    logic [NL-1:0][15:0]                 cskp_minfo ;                            // Control Skip margin info for 128b/130b
    logic [NL-1:0][14:0]                 par_minfo ;                             // Control Skip margin info for 128b/130b for Parity calculation.
    logic [NL-1:0][4:0]                  cskp_mcrc ;                             // Control Skip margin CRC for 128b/130b
    logic [NL-1:0]                       cskp_mpar ;                             // Control Skip margin Parity for 128b/130b
    logic [NL-1:0][15:0]                 load_cskp_minfo ;                       // Loaded Control Skip margin info for 128b/130b
    logic [NL-1:0][4:0]                  load_cskp_mcrc ;                        // Loaded Control Skip margin CRC for 128b/130b
    logic [NL-1:0]                       load_cskp_mpar ;                        // Loaded Control Skip margin Parity for 128b/130b
    logic [NL-1:0][23:0]                 cskp_sym13_15_128b130b ;                // Control Skip Symbol13-15 for 128b/130b
    logic [NL-1:0][319:0]                skp_os_pat_1b1b ;                       // SKP OS data for 8b/10b
    logic [NL-1:0][7:0]                  ts1_sym1__9_1b1b ;                      // TS1 Symbol1 1b1b
    logic [NL-1:0][7:0]                  ts2_sym1__9_1b1b ;                      // TS2 Symbol1 1b1b
    logic [NL-1:0][7:0]                  ts1_sym2_10_1b1b ;                      // TS1 Symbol2 1b1b
    logic [NL-1:0][7:0]                  ts1_sym3_11_1b1b ;                      // TS2 Symbol3 1b1b
    logic [NL-1:0][7:0]                  ts1_sym4_12_1b1b ;                      // TS2 Symbol4 1b1b
    logic [NL-1:0][7:0]                  ts1_sym7_15_1b1b ;                      // TS2 Symbol7 1b1b
    logic [NL-1:0][7:0]                  ts2_sym7_15_1b1b ;                      // TS2 Symbol7 1b1b
    logic [NL-1:0][47:0]                 ts0_sym1_to_6_1b1b ;                    // TS0 Symbol1-6 1b1b
    logic [NL-1:0][7:0]                  ts0_sym7_15_1b1b ;                      // TS2 Symbol7 1b1b
    logic                                req_eq_bit ;                            // Request Equalization bit of eqctl_eqts_info
    logic [NL-1:0][3:0]                  skp_phyp_margin_type ;                  // SKP Margin Phy Payload type 1b1b
    logic [NL-1:0][23:0]                 skp_phyp_margin_info ;                  // SKP Margin Phy Payload info 1b1b
    logic [NL-1:0][3:0]                  skp_phyp_lfsr_type ;                    // SKP LFSR Phy Payload type 1b1b
    logic [NL-1:0][23:0]                 skp_phyp_lfsr_info ;                    // SKP LFSR Phy Payload info 1b1b
    logic [NL-1:0][63:0]                 skp_phyp_1b1b ;                         // SKP selected Phy Payload  1b1b
    logic                                ts0_in_proress ;                        // TS0 sending is in progress
    logic [5:0]                          ts0_ec00_count ;                        // Counter for TS0 EC00 sending
    logic                                ltssm_dsp_g6_eq1_send_ec00_d ;          // 1 cycle delay of ltssm_dsp_g6_eq1_send_ec00
    logic                                sent_comp_ts1_lat ;                     // Indicates sent Compliance TS1 once.
    logic [31:0]                         ts1_sym6_to_9_cmp_ts1 ;                 // TS1 Symbol9-9 for Compliance TS1 (Gen1)
    logic                                ltssm_cmd_compliance_ts1_1d ;           // 1cycle delay of  load_ltssm_cmd_compliance_ts1
    logic [10:0]                         xmtbyte_ts_cnt ;                        // xmtbyte_ts_cnt is purely a ts1/2 sent count. No TS content comparison to reset the count
    logic [2:0]                          ts_phase_d ;                            // Indicate current TS Phase [0]:TS0 / [1]:TS1 / [2]:TS2
// Flit Error injection signals
    ltssm_state_e                        smlh_ltssm_state_d ;                    // 1 cycle delay of smlh_ltssm_state
    ltssm_state_e                        load_smlh_ltssm_state_d ;               // Loaded smlh_ltssm_state
    xmlh_einj_in_os_t                    int_xmtbyte_einj_in_os ;                // Indicates which OS is sending before aligning with xmtbyte_txdata.
    logic  [NL-1:0]                      load_lpbk_eq_lanes_active ;             // One active lane from the cfg_lane_under_test(aligned OS boundary)
    logic                                lpbk_entry_for_lpbk_master ;                    //  Loopback for one active lane. Should send IDLE data other than active lane.
    logic                                lpbk_entry_for_eq_from_lpbk_master ;            //  Loopback for one active lane. Should send IDLE data other than active lane.
    logic  [NL-1:0]                      lpbk_entry_not_lane_under_test_for_master ;     //  Loopback for one active lane. Should send IDLE data other than active lane.

// --- Set fix value to input signals which are not exist by configuration.
    logic  [6:0]                 esm_current_rate ;

// -----------------------------------
//  Common signals
// -----------------------------------

// --- Set fix value to input signals which are not exist by configuration.
   assign  esm_current_rate                       = 7'h00 ;


    always_comb begin
        next_grnt_is_os                      = next_grant[G_EI_BIT]  | next_grant[G_EIE_BIT] | next_grant[G_EIE_8SYM_BIT] | next_grant[G_SKP_BIT] 
                                             | next_grant[G_SDS_BIT] | next_grant[G_TS0_BIT] | next_grant[G_TS1_BIT]      | next_grant[G_TS2_BIT]
                                             | next_grant[G_FTS_BIT] ;

        dsp_tx_sris_cloking                  = ~cfg_upstream_port & ( (~cfg_comm_clk_config & cfg_flit_sris_clocking)   // by Link Control Registers
                                                                       | app_sris_mode_i );                             // by User I/F
        for( int ii = 0 ; ii < NBLOCK ; ii++ ) begin
            if( ii == 0 ) active_block[ii]   = 1'b1 ;
            else          active_block[ii]   = (active_nb > 16*ii ) ;
        end
    end

    // Indicates LTSSM 
    //  - The reason why making these signals by FF is that ltssm_cmd_i is changed in 1 cycle from smlh_ltssm_state.
    //    To align ltssm_cmd_i made by FF.
    always_ff @(posedge core_clk or negedge core_rst_n) begin : state_PROC
        if (!core_rst_n) begin
            ltssm_cfg_state              <= #TP '0 ;
            ltssm_hotreset_state         <= #TP '0 ;
            ltssm_recovery_state         <= #TP '0 ;
            ltssm_lpbk_entry_state       <= #TP '0 ;
        end
        else begin
            ltssm_cfg_state              <= #TP (smlh_ltssm_state == S_CFG_LINKWD_START) | (smlh_ltssm_state == S_CFG_LINKWD_ACEPT )
                                              | (smlh_ltssm_state == S_CFG_LANENUM_WAIT) | (smlh_ltssm_state == S_CFG_LANENUM_ACEPT) 
                                              | (smlh_ltssm_state == S_CFG_COMPLETE    ) ;

            ltssm_hotreset_state         <= #TP (smlh_ltssm_state == S_HOT_RESET_ENTRY) | (smlh_ltssm_state == S_HOT_RESET) ;

            ltssm_recovery_state         <= #TP (smlh_ltssm_state == S_RCVRY_LOCK    ) | (smlh_ltssm_state == S_RCVRY_SPEED   ) 
                                             |  (smlh_ltssm_state == S_RCVRY_RCVRCFG ) | (smlh_ltssm_state == S_RCVRY_IDLE    ) 
                                             |  (smlh_ltssm_state == S_RCVRY_EQ0     ) | (smlh_ltssm_state == S_RCVRY_EQ1     ) 
                                             |  (smlh_ltssm_state == S_RCVRY_EQ2     ) | (smlh_ltssm_state == S_RCVRY_EQ3     ) ;

            ltssm_lpbk_entry_state       <= #TP (smlh_ltssm_state == S_LPBK_ENTRY) ;
        end
    end

    // Indicates previous state / Current grant is OS
    always_ff @(posedge core_clk or negedge core_rst_n) begin : grant_PROC
        if (!core_rst_n) begin
            before_grant               <= #TP G_EIDLE ;
            crnt_grant_d               <= #TP G_EIDLE ;
            crnt_grnt_is_os            <= #TP '0 ;
        end
        else begin
            if( next_grant != crnt_grant ) begin 
                    before_grant       <= #TP crnt_grant ;
            end

            crnt_grnt_is_os    <= #TP next_grnt_is_os ;
            crnt_grant_d       <= #TP crnt_grant ;
        end
    end


// -----------------------------------
//  Data Mux
// -----------------------------------

// Mux by Rate
    always_comb begin
        crnt_rate_os_pat =                                crnt_rate.enc_1b1b     ? enc_1b1b :
                                crnt_rate.enc_128b130b ? enc_128b130b :
                                                         enc_8b10b ;
    end

// Mux by current grant
    always_comb begin
        for(int ii = 0 ; ii < NL ; ii++ ) begin
            case( crnt_grant )
                G_EI_OS       : begin
                                    crnt_os_pat[ii]     = $bits(crnt_os_pat[ii])'( crnt_rate_os_pat.ei__pat[ii] ) ;
                                    crnt_os_pat_k[ii]   = $bits(crnt_os_pat_k[ii])'( crnt_rate_os_pat.ei__pat_k[ii] ) ;
                                end
                G_EIE_OS      : begin
                                    crnt_os_pat[ii]     = crnt_rate_os_pat.eie_pat[ii] ;                // 16s or lower
                                    crnt_os_pat_k[ii]   = crnt_rate_os_pat.eie_pat_k[ii] ;              // 16s or lower
                                end
                G_EIE_8SYM_OS : begin
                                    crnt_os_pat[ii]     = {NBLOCK{ crnt_rate_os_pat.eie_8sym_pat[ii] }}  ;
                                    crnt_os_pat_k[ii]   = {NBLOCK{ crnt_rate_os_pat.eie_8sym_pat_k[ii] }} ;
                                end
                G_SKP_OS      : begin
                                    crnt_os_pat[ii]     = crnt_rate_os_pat.skp_pat[ii] ;
                                    crnt_os_pat_k[ii]   = crnt_rate_os_pat.skp_pat_k[ii] ;
                                end
                G_SDS_OS      : begin
                                    crnt_os_pat[ii]     = {NBLOCK{ crnt_rate_os_pat.sds_pat[ii] }} ;
                                    crnt_os_pat_k[ii]   = {NBLOCK{ crnt_rate_os_pat.sds_pat_k[ii] }} ;
                                end
                G_TS0_OS      : begin
                                    crnt_os_pat[ii]     = {NBLOCK{ crnt_rate_os_pat.ts0_pat[ii] }} ;
                                    crnt_os_pat_k[ii]   = {NBLOCK{ crnt_rate_os_pat.ts0_pat_k[ii] }} ;
                                end
                G_TS1_OS      : begin
                                    crnt_os_pat[ii]     = {NBLOCK{ crnt_rate_os_pat.ts1_pat[ii] }} ;
                                    crnt_os_pat_k[ii]   = {NBLOCK{ crnt_rate_os_pat.ts1_pat_k[ii] }} ;
                                end
                G_TS2_OS      : begin
                                    crnt_os_pat[ii]     = {NBLOCK{ crnt_rate_os_pat.ts2_pat[ii] }} ;
                                    crnt_os_pat_k[ii]   = {NBLOCK{ crnt_rate_os_pat.ts2_pat_k[ii] }} ;
                                end
                G_FTS_OS      : begin
                                    crnt_os_pat[ii]     = {NBLOCK{ crnt_rate_os_pat.fts_pat[ii] }} ;
                                    crnt_os_pat_k[ii]   = {NBLOCK{ crnt_rate_os_pat.fts_pat_k[ii] }} ;
                                end
                default       : begin
                                    crnt_os_pat[ii]     = '0 ;
                                    crnt_os_pat_k[ii]   = '0 ;
                                end
            endcase
        end
    end


// -----------------------------------
//  Data width alignment
// -----------------------------------

// os_byte_count indicated how many OS bytes are sent
    always_ff @(posedge core_clk or negedge core_rst_n) begin : os_byte_count_PROC
        if (!core_rst_n) begin
            os_byte_count             <= #TP '0 ;
        end
        else begin
            if( ~crnt_grnt_is_os || os_send_done ) begin
                os_byte_count           <= #TP '0 ;
            end
            else if( internal_txdata_dv ) begin 
                os_byte_count           <= #TP $bits(os_byte_count)'( os_byte_count + active_nb ) ;
            end
        end
    end
    
// Data width alignment
    logic  [NBK*6-1:0]                       active_nb_bitmapk_type;                       // active number of symbols per lane bitmap (for DataK)
    always_comb begin
        for(int ii = 0 ; ii < NL ; ii++ ) begin
            shift_os_data[ii]           =                      (NBIT)'( crnt_os_pat[ii]   >> ( {os_byte_count[3:0],3'd0} ) ) ;
            shift_os_datak[ii]          = crnt_rate.enc_8b10b ? (NBK)'( crnt_os_pat_k[ii] >> (  os_byte_count[3:0]       ) ) : (NBK)'( crnt_os_pat_k[ii] ) ;

            
            os_gen_data[ii]             = (lpbk_entry_not_lane_under_test_for_master[ii] & crnt_grant[G_TS1_BIT]) ? '0 : (shift_os_data[ii]  & active_nb_bitmap) ;
            os_gen_datak[ii]            = (lpbk_entry_not_lane_under_test_for_master[ii] & crnt_grant[G_TS1_BIT]) ? '0 : (shift_os_datak[ii] & active_nb_bitmapk) ;
        end
    end

    always_comb begin
      for(int ii = 0 ; ii < NBK ; ii++ ) begin
        active_nb_bitmapk_type[(ii*6) +: 6] = {6{active_nb_bitmapk[ii]}};
      end
    end

    // Loopback for one active lane. Should send IDLE data other than active lane.
    always_comb begin
        lpbk_entry_for_lpbk_master                = (crnt_rate.enc_8b10b && (ltssm_cmd_i == `SEND_TS1) && lpbk_master && ltssm_in_lpbkentry) ;
        lpbk_entry_for_eq_from_lpbk_master        = lpbk_entry_for_lpbk_master & |load_lpbk_eq_lanes_active ;
        lpbk_entry_not_lane_under_test_for_master = {NL{lpbk_entry_for_eq_from_lpbk_master}} & ~load_lpbk_eq_lanes_active ;
    end


// -----------------------------------
//  Control signals
// -----------------------------------

// Next sending OS Size (Byte) / current OS sending size - current active_nb
    always_comb begin
        next_os_size = 7'd16 ;                                                                                                                  // almost all OS
        if( crnt_rate.enc_8b10b && (next_grant[G_EI_BIT] || next_grant[G_SKP_BIT] || next_grant[G_FTS_BIT]) )  next_os_size = 7'd4 ;            // Gen1/2 4Byte OS
        if( next_grant[G_EIE_8SYM_BIT] )                                                                       next_os_size = 7'd8 ;            // Gen2 8Byte EIE Symbol
        if( crnt_rate.enc_1b1b  &&  next_grant[G_SKP_BIT] )                                                    next_os_size = 7'd40 ;           // Gen6 SKP (8s or Lower)
    end
    
    always_ff @(posedge core_clk or negedge core_rst_n) begin : crnt_os_size_minus_nb_PROC
        if (!core_rst_n) begin
            crnt_os_size_minus_nb          <= #TP '0 ;
            crnt_os_size                   <= #TP '0 ;
        end
        else begin
            if( next_grant != crnt_grant ) begin
                crnt_os_size                   <= #TP next_os_size ;
 
                if( next_os_size <= $bits(next_os_size)'( active_nb ) ) crnt_os_size_minus_nb      <= #TP '0 ;
                else                                                    crnt_os_size_minus_nb      <= #TP $bits(crnt_os_size_minus_nb)'( next_os_size - active_nb ) ;
            end
        end
    end
   

// The number of next sending OS
    always_comb begin                                                             // Others
        next_ossq_num          = 5'd0 ;

        if( int_ltssm_in_lpbk && lpbk_master && next_grant[G_SKP_BIT] && crnt_rate.enc_1b1b ) begin       // 2 back to back SKP when Loopback.Lead
            next_ossq_num          = 5'd1 ;
        end
        if( next_grant[G_SKP_BIT] && crnt_rate.enc_8b10b && next_stream[CMP_STREAM_BIT] ) begin           // 2 back to back SKP when Gen1/2 (Modified) Compliance if Compliance SOS register is 1.
            next_ossq_num          = 5'd1 ;
        end
        if( next_grant[G_EIE_BIT] && crnt_rate.one_hot[GEN5_BIT] ) begin                                   // Gen5 EIE
            next_ossq_num          = 5'd1 ;
        end
        if( next_grant[G_SDS_BIT] && crnt_rate.enc_1b1b ) begin                                            // Gen6 SDS
            next_ossq_num          = 5'd1 ;
        end
        if( next_grant[G_EIE_BIT] && crnt_rate.enc_1b1b && (ltssm_1b1b_cmd_4_eieos_req) ) begin            // Gen6 EIE  TBD
            next_ossq_num          = 5'd3 ;
        end
        if( next_grant[G_EI_BIT] ) begin
            case( cdm_ras_des_eidle_cnt_sel ) 
                2'b00   : next_ossq_num          = l0p_inst ? crnt_rate.one_hot[GEN2_BIT] ? 5'd1 : 5'd0 : $bits(next_ossq_num)'(ltssm_eidle_cnt) ;   // No RAS DES setting (For L0p ltssm_eidle_cnt value is not correct.)
                2'b01   : next_ossq_num          = (crnt_rate.one_hot[GEN2_BIT] | (ltssm_eidle_cnt==7) ) ?   5'd7 :  5'd3 ;             // multiple 4  (RAS DES)
                2'b10   : next_ossq_num          =  crnt_rate.one_hot[GEN2_BIT]                          ?  5'd15 :  5'd7 ;             // multiple 8  (RAS DES)
                default : next_ossq_num          =  crnt_rate.one_hot[GEN2_BIT]                          ?  5'd31 : 5'd15 ;             // multiple 16 (RAS DES)
            endcase
        end
    end

    always_ff @(posedge core_clk or negedge core_rst_n) begin : crnt_ossq_num_PROC
        if (!core_rst_n) begin
            crnt_ossq_num          <= #TP '0 ;
        end
        else begin
            if( next_grant != crnt_grant ) begin
                crnt_ossq_num      <= #TP next_ossq_num ;
            end
        end
    end
    
// Phase Flags
    always_comb begin
        os_send_start   = os_send_start_wo_dv ;
        os_send_done    = (os_byte_count == crnt_os_size_minus_nb) & crnt_grnt_is_os & internal_txdata_dv ;
        ossq_send_done  = os_send_done & ( (os_send_num == crnt_ossq_num) 
                          ) ;
    end

    always_ff @(posedge core_clk or negedge core_rst_n) begin : os_send_start_wo_dv_PROC
        if (!core_rst_n) begin
            os_send_start_wo_dv          <= #TP '0 ;
        end
        else begin
            if(       next_grnt_is_os & internal_txdata_dv_pre
                && ( ~crnt_grnt_is_os || os_send_done || ~internal_txdata_dv ) ) begin
                    os_send_start_wo_dv           <= #TP 1'b1 ;
            end
            else begin
                    os_send_start_wo_dv           <= #TP 1'b0 ;
            end
        end
    end

    always_ff @(posedge core_clk or negedge core_rst_n) begin : os_send_num_PROC
        if (!core_rst_n) begin
            os_send_num          <= #TP '0 ;
        end
        else begin
            if( ~crnt_grnt_is_os || ossq_send_done || (next_grant != crnt_grant) ) begin
                os_send_num           <= #TP '0 ;
            end
            else if( os_send_done ) begin
                os_send_num      <= #TP $bits(os_send_num)'(os_send_num + 1'b1) ;
            end
        end
    end



    



    

// -----------------------------------
//  OS Data
// -----------------------------------

// Combination logic before register
    always_comb begin
        for( int ii = 0 ; ii < NL ; ii++ ) begin
            ts1_sym1_link_comb[ii]           = ltssm_xk237_4lnknum[ii] ? `PAD_8B : ltssm_xlinknum ;
            ts1_sym2_lane_comb[ii]           = ltssm_xk237_4lannum[ii] ? `PAD_8B : 8'(ii) ;
        end
            req_eq_bit                       = eqctl_eqts_info[7] ;
    end

// Loading OS field timing from LTSSM

    always_ff @(posedge core_clk or negedge core_rst_n) begin : laod_os_field_PROC
        if (!core_rst_n) begin
            for( int ii = 0 ; ii < NL ; ii++ ) begin
                ts1_sym1_link[ii]               <= #TP '0 ;
                ts1_sym2_lane[ii]               <= #TP '0 ;
                ts1_sym6_to_9_eq_normal[ii]     <= #TP '0 ;
                load_cskp_minfo[ii]             <= #TP '0 ;
                load_cskp_mcrc[ii]              <= #TP '0 ;
                load_cskp_mpar[ii]              <= #TP '0 ;
                ts1_sym1__9_1b1b[ii]            <= #TP '0 ;
                ts2_sym1__9_1b1b[ii]            <= #TP '0 ;
                ts1_sym2_10_1b1b[ii]            <= #TP '0 ;
                ts1_sym3_11_1b1b[ii]            <= #TP '0 ;
                ts1_sym4_12_1b1b[ii]            <= #TP '0 ;
                ts0_sym1_to_6_1b1b[ii]          <= #TP '0 ;
            end
                ts1_sym1_link_k                <= #TP '0 ;
                ts1_sym2_lane_k                <= #TP '0 ;
                ts1_sym2_nfts                  <= #TP '0 ;
                ts1_sym4_flit                  <= #TP '0 ;
                ts1_sym4_rate                  <= #TP '0 ;
                ts1_sym4_bit6                  <= #TP '0 ;
                sris_clocking                  <= #TP '0 ;
                ts1_sym5_tctl                  <= #TP '0 ;
                mt1_sym8_to_14                 <= #TP '0 ;
                load_ltssm_ts_speed_change     <= #TP '0 ;
                load_ltssm_mod_ts              <= #TP '0 ;
                load_ltssm_cmd_compliance_ts1  <= #TP '0 ;
                load_lpbk_eq_lanes_active      <= #TP '0 ;
        end
        else begin
            if(  (os_send_done && (ltssm_cmd_i != `SEND_IDLE) && (ltssm_cmd_i != `NORM))  // not load if ltssm_cmd is already SEND_IDLE but still sending OS by ts2_sending_extension.
              || ~crnt_grnt_is_os ) begin                                                 // not load when OS is sending
             // Per-lane field
                for( int ii = 0 ; ii < NL ; ii++ ) begin
                    ts1_sym1_link[ii]               <= #TP ts1_sym1_link_comb[ii] ;
                    ts1_sym1_link_k[ii]             <= #TP ltssm_xk237_4lnknum[ii] ? 1'b1 : 1'b0 ;
                    ts1_sym2_lane[ii]               <= #TP ts1_sym2_lane_comb[ii] ;
                    ts1_sym2_lane_k[ii]             <= #TP ltssm_xk237_4lannum[ii] ? 1'b1 : 1'b0 ;
                    ts1_sym6_to_9_eq_normal[ii]     <= #TP eqctl_eqts_info[ii*EQTS_WD +: EQTS_WD] ;
                    load_cskp_minfo[ii]             <= #TP cskp_minfo[ii] ;
                    load_cskp_mcrc[ii]              <= #TP cskp_mcrc[ii] ;
                    load_cskp_mpar[ii]              <= #TP cskp_mpar[ii] ;
                    ts1_sym1__9_1b1b[ii]            <= #TP ( ltssm_hotreset_state | ltssm_cfg_state                                                     ) ? ts1_sym1_link_comb[ii]
                                                         : ( ltssm_recovery_state | int_ltssm_in_lpbk | l0p_inst                                        ) ? eqctl_eqts_info[ii*EQTS_WD +: 8] 
                                                                                                                                                          : '0 ;
                    ts2_sym1__9_1b1b[ii]            <= #TP ( ltssm_hotreset_state | ltssm_cfg_state   | (ltssm_recovery_state & ~req_eq_bit) | l0p_inst ) ? ts1_sym1_link_comb[ii]
                                                         : ( ltssm_recovery_state                                                                       ) ? eqctl_eqts_info[ii*EQTS_WD +: 8]
                                                                                                                                                          : '0 ;
                    ts1_sym2_10_1b1b[ii]            <= #TP ( ltssm_hotreset_state | ltssm_cfg_state                                                     ) ? ts1_sym2_lane_comb[ii]
                                                         : ( ltssm_recovery_state | l0p_inst                                                            ) ? eqctl_eqts_info[ii*EQTS_WD+8 +: 8] 
                                                                                                                                                          : '0 ;
                    ts1_sym3_11_1b1b[ii]            <= #TP ( ltssm_recovery_state                  ) ? eqctl_eqts_info[ii*EQTS_WD+16 +: 8] 
                                                                                                     : '0 ;
                    ts1_sym4_12_1b1b[ii]            <= #TP ( ltssm_recovery_state                  ) ? {3'b000 , eqctl_eqts_info[ii*EQTS_WD+24 +: 5]}
                                                                                                     : '0 ;
                    ts0_sym1_to_6_1b1b[ii]          <= #TP eqctl_eqts_info_ts0[ii*TS_0_WD +: TS_0_WD] ;
                end
             // Common in all lanes field
                    ts1_sym2_nfts                   <= #TP ltssm_flit_mode_enable ? 8'h00 : cfg_n_fts ;
                    ts1_sym4_flit                   <= #TP ltssm_flit_mode ;
                    ts1_sym4_rate                   <= #TP ltssm_ts_data_rate ;
                    ts1_sym4_bit6                   <= #TP ltssm_ts_auto_change ;
                    sris_clocking                   <= #TP ( (ltssm_cfg_state | ltssm_lpbk_entry_state) & ~smlh_link_up & ~cfg_upstream_port & ~crnt_rate.enc_1b1b ) ? dsp_tx_sris_cloking : 1'b0 ;
                    ts1_sym5_tctl                   <= #TP ltssm_ts_cntrl ;
                    mt1_sym8_to_14                  <= #TP ltssm_ts_alt_protocol ? ltssm_ts_alt_prot_info : '0 ;
                    load_ltssm_ts_speed_change      <= #TP ltssm_ts_speed_change ;
                    load_ltssm_mod_ts               <= #TP ltssm_mod_ts ;
                    load_ltssm_cmd_compliance_ts1   <= #TP ltssm_cmd_compliance_ts1 ;
                    load_lpbk_eq_lanes_active       <= #TP lpbk_eq_lanes_active ;
            end
            else if( os_send_done && l0p_inst ) begin  // For L0p eqctl_eqts_info is always loaded to care recvory transition.
             // Per-lane field
                for( int ii = 0 ; ii < NL ; ii++ ) begin
                    ts1_sym6_to_9_eq_normal[ii]     <= #TP eqctl_eqts_info[ii*EQTS_WD +: EQTS_WD] ;
                end
            end
        end
    end

// Combination logic after register (to align original design)
    always_comb begin
        ts1_sym4_bit7           = sris_clocking             ? 1'b1 
                                                            : load_ltssm_ts_speed_change ;
    end

// ------------------
// ---- 8b/10b ------
// ------------------
    always_comb begin
        for( int ii = 0 ; ii < NL ; ii++ ) begin
            enc_8b10b.ts0_pat[ii]            =  '0 ;
            enc_8b10b.ts0_pat_k[ii]          =  '0 ;

            st1_pat_8b10b[ii]                =  { `TS1_8B ,                               // Symbol15   (4Ah)
                                                  `TS1_8B ,                               // Symbol14   (4Ah)
                                                  `TS1_8B ,                               // Symbol13   (4Ah)
                                                  `TS1_8B ,                               // Symbol12   (4Ah)
                                                  `TS1_8B ,                               // Symbol11   (4Ah)
                                                  `TS1_8B ,                               // Symbol10   (4Ah)
                                                  ts1_sym6_to_9[ii] ,                     // Symbol6-9
                                                  ts1_sym5_tctl ,                         // Symbol5
                                                  ts1_sym4_bit7 ,                         // Symbol4 [6]
                                                  ts1_sym4_bit6 ,                         // Symbol4 [6]
                                                  ts1_sym4_rate,                          // Symbol4 [5:1] 
                                                  ts1_sym4_flit,                          // Symbol4 [0]
                                                  ts1_sym2_nfts ,                         // Symbol3
                                                  ts1_sym2_lane[ii] ,                     // Symbol2
                                                  ts1_sym1_link[ii] ,                     // Symbol1
                                                 `COMMA_8B } ;                            // Symbol0   (BCh)

            mt1_pat_8b10b[ii]                =  {  mt1_sym15_par[ii] ,                    // Symbol15
                                                   mt1_sym8_to_14 ,                       // Symbol8-14
                                                   `TS1_8B ,                              // Symbol7
                                                   `TS1_8B ,                              // Symbol6
                                                   st1_pat_8b10b[ii][8*5 +: 8]   ,        // Symbol5
                                                   st1_pat_8b10b[ii][8*4 +: 8]   ,        // Symbol4 
                                                   st1_pat_8b10b[ii][8*1 +: 8*3] ,        // Symbol1-3
                                                  `COMMA_8B } ;                           // Symbol0      (BCh)

            enc_8b10b.ts1_pat[ii]            =  load_ltssm_mod_ts ? mt1_pat_8b10b[ii]     // Modified TS1
                                                                  : st1_pat_8b10b[ii] ;   // Standard TS1

            enc_8b10b.ts1_pat_k[ii]          =  {  13'h0000 ,                             // Symbol3-15
                                                   ts1_sym2_lane_k[ii] ,                  // Symbol2
                                                   ts1_sym1_link_k[ii] ,                  // Symbol1
                                                   1'b1 } ;                               // Symbol0
            
            st2_pat_8b10b[ii]                =  {  `TS2_8B ,                              // Symbol15   (45h)
                                                   `TS2_8B ,                              // Symbol14   (45h)
                                                   `TS2_8B ,                              // Symbol13   (45h)
                                                   `TS2_8B ,                              // Symbol12   (45h)
                                                   `TS2_8B ,                              // Symbol11   (45h)
                                                   `TS2_8B ,                              // Symbol10   (45h)
                                                   ts1_sym6_to_9_eq_normal[ii] ,          // Symbol6-9
                                                   st1_pat_8b10b[ii][8*1 +: 8*5] ,        // Symbol1-5
                                                  `COMMA_8B } ;                           // Symbol0

            mt2_pat_8b10b[ii]                =  {  mt2_sym15_par[ii] ,                    // Symbol15
                                                   mt1_pat_8b10b[ii][8*8 +: 8*7] ,        // Symbol8-14
                                                   `TS2_8B ,                              // Symbol7
                                                   `TS2_8B ,                              // Symbol6
                                                   mt1_pat_8b10b[ii][8*1 +: 8*5] ,        // Symbol1-5
                                                  `COMMA_8B } ;                           // Symbol0      (BCh)

            enc_8b10b.ts2_pat[ii]            =  load_ltssm_mod_ts ? mt2_pat_8b10b[ii]     // Modified TS2
                                                                  : st2_pat_8b10b[ii] ;   // Standard TS2


            enc_8b10b.ts2_pat_k[ii]          =  { enc_8b10b.ts1_pat_k[ii] } ;             // Symbol0-15

            enc_8b10b.skp_pat[ii]            =  $bits(enc_8b10b.skp_pat[0])'( { {3{`SKIP_8B}} ,           // Symbol1-3
                                                                                 `COMMA_8B  } ) ;         // Symbol0

            enc_8b10b.skp_pat_k[ii]          =  $bits(enc_8b10b.skp_pat_k[0])'( 4'hF ) ;

            enc_8b10b.ei__pat[ii]            =  128'( {{3{`EIDLE_8B}},                    // Symbols1-3   (7Ch)
                                                       `COMMA_8B } ) ;                    // Symbol0      (BCh)

            enc_8b10b.ei__pat_k[ii]          =  16'h000F ;



            enc_8b10b.eie_pat[ii]            =  { `TS1_8B ,                               // Symbol15
                                                  {14{`K287_8B}} ,                        // Symbols1-14  (FCh)
                                                  `COMMA_8B } ;                           // Symbol0      (BCh)

            enc_8b10b.eie_pat_k[ii]          =  16'h7FFF ;                                // All K code other than Symbol15

            enc_8b10b.eie_8sym_pat[ii]       =  128'( {8{`K287_8B}} ) ;                   // Symbols0-7   (FCh)

            enc_8b10b.eie_8sym_pat_k[ii]     =  16'h00FF ;                       
            
            enc_8b10b.fts_pat[ii]            =  128'( {{3{`FTS_8B}} ,                     // Symbols1-3   (3Ch)
                                                       `COMMA_8B  } ) ;                   // Symbol0      (BCh)

            enc_8b10b.fts_pat_k[ii]          =  16'h000F ;

            enc_8b10b.sds_pat[ii]            =  '0 ;                                      // Not applicable

            enc_8b10b.sds_pat_k[ii]          =  '0 ;                                      // Not applicable
        end
    end

    // Compliance TS1

    always_comb begin
        ts1_sym6_to_9_cmp_ts1  = { `TS1_8B , `TS1_8B , `TS1_8B , ltssm_compliance_set_num } ;
    end
    
    // even parity TS1/TS2 for Modified TS1/TS2
    // Select Compliance TS1 or Normal/EQ TS1
    always_comb begin
        for( int ii = 0 ; ii < NL ; ii++ ) begin
            mt1_sym15_par[ii]   =    mt1_pat_8b10b[ii][ 4*8+:8] ^ mt1_pat_8b10b[ii][ 5*8+:8] ^ mt1_pat_8b10b[ii][ 6*8+:8] ^ mt1_pat_8b10b[ii][7*8+:8]
                                   ^ mt1_pat_8b10b[ii][ 8*8+:8] ^ mt1_pat_8b10b[ii][ 9*8+:8] ^ mt1_pat_8b10b[ii][10*8+:8] ^ mt1_pat_8b10b[ii][11*8+:8]
                                   ^ mt1_pat_8b10b[ii][12*8+:8] ^ mt1_pat_8b10b[ii][13*8+:8] ^ mt1_pat_8b10b[ii][14*8+:8] ;

            mt2_sym15_par[ii]   =    mt2_pat_8b10b[ii][ 4*8+:8] ^ mt2_pat_8b10b[ii][ 5*8+:8] ^ mt2_pat_8b10b[ii][ 6*8+:8] ^ mt2_pat_8b10b[ii][7*8+:8]
                                   ^ mt2_pat_8b10b[ii][ 8*8+:8] ^ mt2_pat_8b10b[ii][ 9*8+:8] ^ mt2_pat_8b10b[ii][10*8+:8] ^ mt2_pat_8b10b[ii][11*8+:8]
                                   ^ mt2_pat_8b10b[ii][12*8+:8] ^ mt2_pat_8b10b[ii][13*8+:8] ^ mt2_pat_8b10b[ii][14*8+:8] ;

            ts1_sym6_to_9[ii]   = load_ltssm_cmd_compliance_ts1 ? ts1_sym6_to_9_cmp_ts1 : ts1_sym6_to_9_eq_normal[ii] ;
        end
    end
        
        
// ---------------------
// ---- 128b/130b ------
// ---------------------
    always_comb begin
        for( int ii = 0 ; ii < NL ; ii++ ) begin
            enc_128b130b.ts0_pat[ii]            =  '0 ;

            enc_128b130b.ts1_pat[ii]            =  { st1_pat_8b10b[ii][8*10 +: 8*6] ,         // Symbol10-15
                                                      ts1_sym6_to_9_eq_normal[ii] ,           // Symbol6-9
                                                      st1_pat_8b10b[ii][8*1 +: 8*5] ,         // Symbol1-5
                                                     `TS1_SYM_0 } ;                           // Symbol0      (1Eh)


            enc_128b130b.ts2_pat[ii]            =  { st2_pat_8b10b[ii][8*1 +: 8*15] ,         // Symbol1-15
                                                     `TS2_SYM_0 } ;                           // Symbol0      (3dh)

            enc_128b130b.skp_pat[ii]            =  $bits(enc_128b130b.skp_pat[0])'( 
                                                   { (ctl_skp_enable ? cskp_sym13_15_128b130b[ii] : sskp_lfsr_128b130b[ii]) ,  // Symbol13-15
                                                     skp_end_128b130b ,                                                        // Symbol12
                                                     {12{skp_symbol_128b130b}} } ) ;                                           // Symbol0-11

            enc_128b130b.ei__pat[ii]            =  {16{`EIOS_SYM_0}} ;                       // Symbol0-15 (66h)

            enc_128b130b.eie_pat[ii]            =                                                     crnt_rate.one_hot[GEN5_BIT] ? {2{32'hFFFF_FFFF ,               // Symbol 4,5,6,7,    12,13,14,15 (Gen5)
                                                                                   32'h0000_0000}} :                // Symbol 0,1,2,3,    8 ,9 ,10,11 (Gen5)
                                                     crnt_rate.one_hot[GEN4_BIT] ? {4{16'hFFFF,                     // Symbol 2,3,6,7,10,11,14,15 (Gen4, CCIX 16GT/s)
                                                                                    16'h0000}} :                    // Symbol 0,1,4,5,8 ,9 ,12,13 (Gen4, CCIX 16GT/s)

                                                                                {8{8'hFF,                           // Symbol 1,3,5,7,9,11,13,15 (Gen3)
                                                                                   8'h00}};                         // Symbol 0,2,4,6,8,10,12,14 (Gen3)


            enc_128b130b.eie_8sym_pat[ii]       =  '0 ;        // Not applicable

            enc_128b130b.fts_pat[ii]            = { 8'h8e,                                  // Symbol 15
                                                    8'h8b,                                  // Symbol 14
                                                    8'h8d,                                  // Symbol 13
                                                    8'h80,                                  // Symbol 12
                                                    8'h7f,                                  // Symbol 11
                                                    8'h88,                                  // Symbol 10
                                                    8'hec,                                  // Symbol  9
                                                    8'h6e,                                  // Symbol  8
                                                    8'h25,                                  // Symbol  7
                                                    8'hc9,                                  // Symbol  6
                                                    8'hc6,                                  // Symbol  5
                                                    8'hcc,                                  // Symbol  4
                                                    8'hc7,                                  // Symbol  3
                                                    8'h4e,                                  // Symbol  2
                                                    8'h47,                                  // Symbol  1
                                                    8'h55};                                 // Symbol  0

            enc_128b130b.sds_pat[ii]            =                                                     crnt_rate.one_hot[GEN5_BIT] ? { {15{`CX_GEN5_SDS_BODY_ENC}} ,      // Symbol1-15  (87h) (Gen5)
                                                                                         `SDS_SYM_0              } :    // Symbol0     (E1h) (Gen5)
                                                                                { {15{`SDS_SYM_1}} ,                    // Symbol1-15  (55h) (Gen3/4)
                                                                                      `SDS_SYM_0   } ;                  // Symbol0     (E1h) (Gen3/4)

            enc_128b130b.ts0_pat_k[ii]          =  16'(`SYNC_OS_BLOCK) ;
            enc_128b130b.ts1_pat_k[ii]          =  16'(`SYNC_OS_BLOCK) ;
            enc_128b130b.ts2_pat_k[ii]          =  16'(`SYNC_OS_BLOCK) ;
            enc_128b130b.skp_pat_k[ii]          =  $bits(enc_128b130b.skp_pat_k[0])'(`SYNC_OS_BLOCK) ;
            enc_128b130b.ei__pat_k[ii]          =  16'(`SYNC_OS_BLOCK) ;
            enc_128b130b.eie_pat_k[ii]          =  16'(`SYNC_OS_BLOCK) ;
            enc_128b130b.eie_8sym_pat_k[ii]     =  16'(`SYNC_OS_BLOCK) ;                  
            enc_128b130b.fts_pat_k[ii]          =  16'(`SYNC_OS_BLOCK) ;
            enc_128b130b.sds_pat_k[ii]          =  16'(`SYNC_OS_BLOCK) ;
        end
    end

    // SKP OS field info
    always_comb begin
        skp_symbol_128b130b            = crnt_rate.one_hot[GEN5_BIT] ? `CX_GEN5_SKP_ENC : `SKP_SYM_0 ;        // Gen5 : 0x99 / Gen3-4 : 0xAA
        skp_end_128b130b               = ctl_skp_enable              ? `SKP_END_CTL_SYM : `SKP_END_SYM ;      // Control SKP 0x78 : / Statndard SKP : 0xE1
    end
    always_comb begin
        for( int ii = 0 ; ii < NL ; ii++ ) begin
            sskp_lfsr_128b130b[ii]          = '0 ;                            // LSFR/Parity field are made in scramble3_skip_align module.
            cskp_minfo[ii]                  = (cfg_upstream_port) ? smlh_ctlskp_info[ii*16 +: 16] : cfg_margin_control[ii*16 +: 16];
            
            par_minfo[ii]                   = {cskp_minfo[ii][15:8] , cskp_minfo[ii][6:0]} ;
            cskp_mcrc[ii][0]                = par_minfo[ii][0] ^ par_minfo[ii][3] ^ par_minfo[ii][5] ^ par_minfo[ii][6] ^ par_minfo[ii][9]  ^ par_minfo[ii][10] ^ par_minfo[ii][11] ^ par_minfo[ii][12] ^ par_minfo[ii][13];
            cskp_mcrc[ii][1]                = par_minfo[ii][1] ^ par_minfo[ii][4] ^ par_minfo[ii][6] ^ par_minfo[ii][7] ^ par_minfo[ii][10] ^ par_minfo[ii][11] ^ par_minfo[ii][12] ^ par_minfo[ii][13] ^ par_minfo[ii][14];
            cskp_mcrc[ii][2]                = par_minfo[ii][0] ^ par_minfo[ii][2] ^ par_minfo[ii][3] ^ par_minfo[ii][6] ^ par_minfo[ii][7]  ^ par_minfo[ii][8]  ^ par_minfo[ii][9]  ^ par_minfo[ii][10] ^ par_minfo[ii][14];
            cskp_mcrc[ii][3]                = par_minfo[ii][1] ^ par_minfo[ii][3] ^ par_minfo[ii][4] ^ par_minfo[ii][7] ^ par_minfo[ii][8]  ^ par_minfo[ii][9]  ^ par_minfo[ii][10] ^ par_minfo[ii][11];
            cskp_mcrc[ii][4]                = par_minfo[ii][2] ^ par_minfo[ii][4] ^ par_minfo[ii][5] ^ par_minfo[ii][8] ^ par_minfo[ii][9]  ^ par_minfo[ii][10] ^ par_minfo[ii][11] ^ par_minfo[ii][12];

            cskp_mpar[ii]                   = (^cskp_mcrc[ii]) ^ (^cskp_minfo[ii]);
            
            cskp_sym13_15_128b130b[ii]      = { load_cskp_minfo[ii][15:8] ,              // Symbol15
                                                load_cskp_mpar[ii] ,                     // Symbol13 [7]
                                                load_cskp_minfo[ii][6:0] ,               // Symbol14 [6:0]
                                                3'b000 ,                                 // Symbol13 [7:5] Parity field are made in scramble3_skip_align module.
                                                load_cskp_mcrc[ii] } ;                   // Symbol13 [4:0]
        end
    end

    // Output for xmlh_cmp_gen
    always_comb begin
        eie_pat_128b130b                   = enc_128b130b.eie_pat[0] ; 
        skp_pat_128b130b                   = $bits(skp_pat_128b130b)'( enc_128b130b.skp_pat[0] ) ; 
    end



// ------------------
// ---- 1b/1b ------
// ------------------
    always_comb begin
        for( int ii = 0 ; ii < NL ; ii++ ) begin
            enc_1b1b.ts0_pat[ii]            =  {2{ ts0_sym7_15_1b1b[ii] ,                          // Symbol7 ,15
                                                   ts0_sym1_to_6_1b1b[ii] ,                        // Symbol1-6 , 9-14
                                                   `TS0_G6_SYM_0 } } ;                             // Symbol0 , 8

            enc_1b1b.ts1_pat[ii]            =  {2{ ts1_sym7_15_1b1b[ii] ,                          // Symbol7 ,15
                                                   4'b0000 , ts1_sym5_tctl[3:0] ,                  // Symbol6 ,14
                                                   ts1_sym4_bit7 ,                                 // Symbol5 ,13 [7]
                                                   ts1_sym4_bit6 ,                                 // Symbol5 ,13 [6]
                                                   ts1_sym4_rate ,                                 // Symbol5 ,13 [5:1]
                                                   1'b0 ,                                          // Symbol5 ,13 [0]
                                                   ts1_sym4_12_1b1b[ii] ,                          // Symbol4 ,12
                                                   ts1_sym3_11_1b1b[ii] ,                          // Symbol3 ,11
                                                   ts1_sym2_10_1b1b[ii] ,                          // Symbol2 ,10
                                                   ts1_sym1__9_1b1b[ii] ,                          // Symbol1 , 9
                                                   `TS1_G6_SYM_0 } } ;                             // Symbol0 , 8


            enc_1b1b.ts2_pat[ii]            =  {2{ ts2_sym7_15_1b1b[ii] ,                          // Symbol7 ,15
                                                   enc_1b1b.ts1_pat[ii][8*6 +: 8] ,                // Symbol6 ,12
                                                   enc_1b1b.ts1_pat[ii][8*5 +: 8] ,                // Symbol5 ,110
                                                   16'h0000 ,                                      // Symbol3-4 ,11-12
                                                   enc_1b1b.ts1_pat[ii][8*2 +: 8] ,                // Symbol2 ,10
                                                   ts2_sym1__9_1b1b[ii] ,                          // Symbol1 , 9
                                                   `TS2_G6_SYM_0 } } ;                             // Symbol0 , 8

            skp_os_pat_1b1b[ii]             = { skp_phyp_1b1b[ii] ,                                                // Symbol39-32 
                                               {2{`SKPEND_G6_S3, `SKPEND_G6_S2, `SKPEND_G6_S1, `SKPEND_G6_S0}} ,   // Symbol24-31 
                                               {12{`SKP_G6_S1, `SKP_G6_S0}} } ;                                    // Symbol0-23

            // For 8s or lower
            enc_1b1b.skp_pat[ii]            =  128'( skp_os_pat_1b1b[ii] >> ( {os_byte_count[5:4] , 7'd0} ) ) ;           // Shift per 16Byte transfer



            enc_1b1b.ei__pat[ii]            =  {8{`EIOS_G6_S1 ,                                   // Symbol1,3,5,7,9,11,13,15  (F0h)
                                                  `EIOS_G6_S0}} ;                                 // Symbol0,2,4,6,8,10,12,14  (0Fh)

            enc_1b1b.eie_pat[ii]            =  {{8{`EIEOS_G6_S8}}                                 // Symbol1,3,5,7,9,11,13,15  (FFh)
                                              , {8{`EIEOS_G6_S0}}} ;                              // Symbol0,2,4,6,8,10,12,14  (00h)

            enc_1b1b.eie_8sym_pat[ii]       =  '0 ;                                               // Not applicable

            enc_1b1b.fts_pat[ii]            =  '0 ;                                               // Not applicable

            enc_1b1b.sds_pat[ii]            =  { 4{ {3{`SDS_G6_S1}} ,                             // Symbol1-3,5-7,9-11,13-15 (C6h)
                                                       `SDS_G6_S0 } } ;                           // Symbol0  ,4  ,8   ,12    (B1h)

            enc_1b1b.ts0_pat_k[ii]          =  16'(`SYNC_OS_BLOCK) ;
            enc_1b1b.ts1_pat_k[ii]          =  16'(`SYNC_OS_BLOCK) ;
            enc_1b1b.ts2_pat_k[ii]          =  16'(`SYNC_OS_BLOCK) ;
            enc_1b1b.skp_pat_k[ii]          =  $bits(enc_1b1b.skp_pat_k[0])'(`SYNC_OS_BLOCK) ;
            enc_1b1b.ei__pat_k[ii]          =  16'(`SYNC_OS_BLOCK) ;
            enc_1b1b.eie_pat_k[ii]          =  16'(`SYNC_OS_BLOCK) ;
            enc_1b1b.eie_8sym_pat_k[ii]     =  16'(`SYNC_OS_BLOCK) ;    
            enc_1b1b.fts_pat_k[ii]          =  16'(`SYNC_OS_BLOCK) ;
            enc_1b1b.sds_pat_k[ii]          =  16'(`SYNC_OS_BLOCK) ;
        end
    end

    // even parity TS1/TS2
    always_comb begin
        for( int ii = 0 ; ii < NL ; ii++ ) begin
            ts0_sym7_15_1b1b[ii]   = enc_1b1b.ts0_pat[ii][0*8+:8] ^ enc_1b1b.ts0_pat[ii][1*8+:8] ^ enc_1b1b.ts0_pat[ii][2*8+:8] ^ enc_1b1b.ts0_pat[ii][3*8+:8]
                                    ^enc_1b1b.ts0_pat[ii][4*8+:8] ^ enc_1b1b.ts0_pat[ii][5*8+:8] ^ enc_1b1b.ts0_pat[ii][6*8+:8];

            ts1_sym7_15_1b1b[ii]   = enc_1b1b.ts1_pat[ii][0*8+:8] ^ enc_1b1b.ts1_pat[ii][1*8+:8] ^ enc_1b1b.ts1_pat[ii][2*8+:8] ^ enc_1b1b.ts1_pat[ii][3*8+:8]
                                    ^enc_1b1b.ts1_pat[ii][4*8+:8] ^ enc_1b1b.ts1_pat[ii][5*8+:8] ^ enc_1b1b.ts1_pat[ii][6*8+:8];

            ts2_sym7_15_1b1b[ii]   = enc_1b1b.ts2_pat[ii][0*8+:8] ^ enc_1b1b.ts2_pat[ii][1*8+:8] ^ enc_1b1b.ts2_pat[ii][2*8+:8] ^ enc_1b1b.ts2_pat[ii][3*8+:8]
                                    ^enc_1b1b.ts2_pat[ii][4*8+:8] ^ enc_1b1b.ts2_pat[ii][5*8+:8] ^ enc_1b1b.ts2_pat[ii][6*8+:8];

        end
    end


    // SKP OS field info
    always_comb begin
        for( int ii = 0 ; ii < NL ; ii++ ) begin
            skp_phyp_margin_type[ii]        = 4'b0000 ;          // Parity field are made in scramble3_skip_align module.

            skp_phyp_margin_info[ii]        = { load_cskp_minfo[ii][15:8] ,   // [23:16]
                                                load_cskp_minfo[ii][6:0] ,    // [15:9]
                                                load_cskp_mcrc[ii] ,          // [8:4]
                                                4'h0 }   ;                    // [3:0] Rsvd

            skp_phyp_lfsr_type[ii]          = 4'b0001 ;          // Parity field are made in scramble3_skip_align module.

            skp_phyp_lfsr_info[ii]          = '0 ;               // LSFR field are made in scramble3_skip_align module.

            skp_phyp_1b1b[ii]               = ts0_in_proress          ?  {8{8'hF0}}     
                                            : ctl_skp_enable          ?  {skp_phyp_margin_type[ii]        ,     // [63:60]
                                                                          skp_phyp_margin_info[ii][23:8]  ,     // [59:44]
                                                                          skp_phyp_margin_type[ii]        ,     // [43:40]
                                                                          skp_phyp_margin_info[ii][7:0]   ,     // [39:32]
                                                                          skp_phyp_margin_info[ii][23:16] ,     // [31:24]
                                                                          skp_phyp_margin_type[ii]        ,     // [23:20]
                                                                          skp_phyp_margin_info[ii][15:0]  ,     // [19:4]
                                                                          skp_phyp_margin_type[ii] }            // [3:0]
                                                                      :  {skp_phyp_lfsr_type[ii]          ,     // [63:60]
                                                                          skp_phyp_lfsr_info[ii][23:8]    ,     // [59:44]
                                                                          skp_phyp_lfsr_type[ii]          ,     // [43:40]
                                                                          skp_phyp_lfsr_info[ii][7:0]     ,     // [39:32]
                                                                          skp_phyp_lfsr_info[ii][23:16]   ,     // [31:24]
                                                                          skp_phyp_lfsr_type[ii]          ,     // [23:20]
                                                                          skp_phyp_lfsr_info[ii][15:0]    ,     // [19:4]
                                                                          skp_phyp_lfsr_type[ii] } ;            // [3:0]
        end
    end

    // TS0 sending is in progress for SKP PHY Payload field
    always_ff @(posedge core_clk or negedge core_rst_n) begin : ts0_in_proress_PROC
        if (!core_rst_n) begin
            ts0_in_proress          <= #TP '0 ;
        end
        else begin
            if( next_grant[G_TS0_BIT] ) begin
                ts0_in_proress          <= #TP 1'b1 ;
            end
            else if( ~next_grnt_is_os || next_grant[G_TS1_BIT] || next_grant[G_TS2_BIT] ) begin
                ts0_in_proress          <= #TP '0 ;
            end
        end
    end

    // Output for xmlh_cmp_gen
    always_comb begin
        eie_pat_1b1b                   = enc_1b1b.eie_pat[0] ; 
        skp_pat_1b1b                   = skp_os_pat_1b1b[0] ; 
    end




// -----------------------------------
//  Output each Flags
// -----------------------------------

// Simple flags
    always_comb begin
        xmtbyte_ts0_sent[0]               = os_send_start   &  (    crnt_grant[G_TS0_BIT] 
                                                               );
        xmtbyte_ts1_sent[0]               = os_send_start   & (    crnt_grant[G_TS1_BIT] | xmtbyte_ts0_sent[0]  
                                                               );
        xmtbyte_ts2_sent[0]               = os_send_start   & ( crnt_grant[G_TS2_BIT]  
                                                               );
        int_fts_sent                      = os_send_start   &  crnt_grant[G_FTS_BIT] ;
        xmtbyte_eidle_sent                = ossq_send_done  &  crnt_grant[G_EI_BIT]  ;
        xmtbyte_eies_sent                 = os_send_start   & (crnt_grant[G_EIE_BIT] | crnt_grant[G_EIE_8SYM_BIT]) ;
        xmtbyte_skip_sent_o               = os_send_start   &  crnt_grant[G_SKP_BIT] ;
        xmtbyte_skip_insert               = xmtbyte_skip_sent_o ;                           // Not used anywhere
        xmtbyte_ctlskip_sent              = xmtbyte_skip_sent_o & ctl_skp_enable ;
        xmtbyte_pat_fts_sent              = int_fts_sent ;
        xmtbyte_pat_eidle_start_sent      = os_send_start   & crnt_grant[G_EI_BIT] ;
    
    end

// SKP OS LFSR/Parity field sending flag this signal is used in scramble3_skip_align to replace correct LFSR/Parity field
    always_comb begin
        os_gen_skp_os_align_sts         = SKP_REPLACE_IDLE ;
        sending_skpend                  = '0 ;
        
        if( crnt_grant[G_SKP_BIT] && internal_txdata_dv ) begin
            if( crnt_rate.enc_128b130b && ((os_byte_count + active_nb) > 7'd12) ) begin
                     if( ctl_skp_enable )                                       os_gen_skp_os_align_sts = CNTL_SKP_128b130b ;
                else if( before_grant[G_EDS_BIT] || before_grant[G_DATA_BIT] )  os_gen_skp_os_align_sts = STNDRD_SKP_PDT_128b130b ;
                else                                                            os_gen_skp_os_align_sts = STNDRD_SKP_POS_128b130b ;
                  
                                                                                sending_skpend          = (os_byte_count > 7'd12) ? '0 : $bits(sending_skpend)'( 1'b1 ) ;   // SKP End is on Symbol 12
            end
            else if( crnt_rate.enc_1b1b ) begin
                if( ~ts0_in_proress && ((os_byte_count + active_nb) > (crnt_os_size - 7'd8)) ) begin
                     if( ctl_skp_enable )                                       os_gen_skp_os_align_sts = PPT_0_SKP_1b1b ;
                     else                                                       os_gen_skp_os_align_sts = PPT_1_SKP_1b1b ;
                end

                if( ((os_byte_count + active_nb) > (crnt_os_size - 7'd16)) && (os_byte_count < (crnt_os_size - 7'd8)) ) begin   // SKP End is on Symbol 24-31 (Last 16-8)
                                                                                sending_skpend          = 
                                                                                                                          $bits(sending_skpend)'( 1'b1 ) ; 
                end
            end
        end
    end

// Sending OS Flags [0]:SKP / [1]:SKPEND / [2]:EI / [3]:EIE / [4]:SDS
    
    always_comb begin
        os_gen_ossending = '0 ;
        
        for( int ii = 0 ; ii < NL ; ii++ ) begin
            for( int jj = 0 ; jj < NBLOCK ; jj++ ) begin
                os_gen_ossending[ii][jj][0]  = crnt_grant[G_SKP_BIT] & active_block[jj] ;                                            // SKP
                os_gen_ossending[ii][jj][1]  = sending_skpend[jj] & active_block[jj] ;                                               // SKP END
                os_gen_ossending[ii][jj][2]  = 
                                                crnt_grant[G_EI_BIT] & active_block[jj] ;

                os_gen_ossending[ii][jj][3]  = 
                                                crnt_grant[G_EIE_BIT] & active_block[jj] ;

                os_gen_ossending[ii][jj][4]  = crnt_grant[G_SDS_BIT] & active_block[jj] ;                                            // SDS
            end
        end
        
    end

// Sending all N_FTS is done
    always_comb begin
        exp_nfts              = cfg_ext_synch ? 13'd4096 : $bits(exp_nfts)'( latched_ts_nfts ) ;
        xmtbyte_fts_sent      = ( nfts_expire_next & int_fts_sent )                                                      // send the last FTS
                              | ( (exp_nfts == '0) & (ltssm_cmd_i == `SEND_N_FTS) & (ltssm_cmd_i_d != `SEND_N_FTS) )  ;  // No FTS is sent if N_FTS setting is 0.
    end

    always_ff @(posedge core_clk or negedge core_rst_n) begin : nfts_count_PROC
        if (!core_rst_n) begin
            nfts_count            <= #TP '0 ;
            nfts_expire_next      <= #TP '0 ;
        end
        else begin
            if( ~crnt_grant[G_FTS_BIT] && ~crnt_grant[G_EIE_BIT] && ~crnt_grant[G_SKP_BIT] ) begin
                nfts_count            <= #TP '0 ;
                nfts_expire_next      <= #TP '0 ;
            end
            else if( crnt_grant[G_FTS_BIT] && os_send_done ) begin
                nfts_count            <= #TP ( nfts_count != (exp_nfts - 1'b1) )        ? $bits(nfts_count)'( nfts_count + 1'b1 ) : nfts_count ;
                nfts_expire_next      <= #TP ((nfts_count + 1'b1) == (exp_nfts - 1'b1)) ? 1'b1 : 1'b0;
            end
        end
    end

// current ts data different from previous
    always_ff @(posedge core_clk or negedge core_rst_n) begin : crnt_os_pat_d_PROC
        if (!core_rst_n) begin
            for(int ii = 0 ; ii < NL ; ii++ ) begin
                crnt_os_pat_d[ii]         <= #TP '0 ;
            end
        end
        else begin
            if( internal_txdata_dv && (crnt_grant[G_TS0_BIT] ||  crnt_grant[G_TS1_BIT] || crnt_grant[G_TS2_BIT]) ) begin
                crnt_os_pat_d            <= #TP crnt_os_pat ;
            end
        end
    end

    always_ff @(posedge core_clk or negedge core_rst_n) begin : latched_os_data_PROC
        if (!core_rst_n) begin
            for(int ii = 0 ; ii < NL ; ii++ ) begin
                latched_os_data[ii]       <= #TP '0 ;
            end
        end
        else begin
            if( crnt_grant_d[G_TS0_BIT] ||  crnt_grant_d[G_TS1_BIT] || crnt_grant_d[G_TS2_BIT] ) begin
                latched_os_data          <= #TP crnt_os_pat_d ;
            end
            else if( ~crnt_grant_d[G_SKP_BIT] && ~crnt_grant_d[G_EIE_BIT] ) begin
                for(int ii = 0 ; ii < NL ; ii++ ) begin
                    latched_os_data[ii]       <= #TP '0 ;
                end
            end
        end
    end

    always_comb begin
        xmtbyte_ts_data_diff        = ( crnt_grant_d[G_TS0_BIT] | crnt_grant_d[G_TS1_BIT] | crnt_grant_d[G_TS2_BIT] )
                                    & ( crnt_os_pat_d != latched_os_data ) ;
    end


// transmit TS persistency count
    always_comb begin
        update_ts_cnt = '0 ;
             if( xmtbyte_ts1_sent | xmtbyte_ts2_sent       ) update_ts_cnt = 'd1 ;
    end
    
    always_ff @(posedge core_clk or negedge core_rst_n) begin : xmtbyte_ts_pcnt_PROC
        if (!core_rst_n) begin
            xmtbyte_ts_pcnt                   <= #TP '0 ;
            xmtbyte_loe_2_ts1_ec_00b_sent     <= #TP '0 ;
        end
        else begin
            if( ltssm_clear ) begin
                xmtbyte_ts_pcnt                   <= #TP $bits(xmtbyte_ts_pcnt)'( update_ts_cnt ) ;
                xmtbyte_loe_2_ts1_ec_00b_sent     <= #TP (ts1_sym6_to_9_eq_normal[0][1:0] == 2'b00) ;
            end
            else if( ~crnt_grnt_is_os || crnt_grant[G_FTS_BIT] || crnt_grant[G_SDS_BIT] || crnt_grant[G_EI_BIT] || crnt_grant[G_EIE_8SYM_BIT] ) begin
                xmtbyte_ts_pcnt                   <= #TP '0 ;
                xmtbyte_loe_2_ts1_ec_00b_sent     <= #TP (ts1_sym6_to_9_eq_normal[0][1:0] == 2'b00) ;
            end
            else if( xmtbyte_ts_data_diff ) begin
                xmtbyte_ts_pcnt                   <= #TP $bits(xmtbyte_ts_pcnt)'( update_ts_cnt + 1'b1 ) ;
                xmtbyte_loe_2_ts1_ec_00b_sent     <= #TP (ts1_sym6_to_9_eq_normal[0][1:0] == 2'b00) & ( (update_ts_cnt + 1'b1) <= 2) ;
            end
            else if ( (&xmtbyte_ts_pcnt != 1'b1) && os_send_start ) begin
                xmtbyte_ts_pcnt                   <= #TP $bits(xmtbyte_ts_pcnt)'( xmtbyte_ts_pcnt + update_ts_cnt ) ;
                xmtbyte_loe_2_ts1_ec_00b_sent     <= #TP (ts1_sym6_to_9_eq_normal[0][1:0] == 2'b00) & ( (xmtbyte_ts_pcnt + update_ts_cnt) <= 2) ;
            end
        end
    end


    // Encoding for transmit ts persistency count ([5] >=1024, [4] >=32, [3] >=16, [2] >=8, [1] >=2, [0] >=1)


// Gen6 TS0 sent 24 or over.
    always_ff @(posedge core_clk or negedge core_rst_n) begin : ts0_ec00_count_PROC
        if (!core_rst_n) begin
            ts0_ec00_count                    <= #TP '0 ;
            xmtbyte_sent_24_ts0_ec00          <= #TP '0 ;
        end
        else begin
            if( ~ltssm_dsp_g6_eq1_send_ec00 || ltssm_clear ) begin
                ts0_ec00_count                    <= #TP '0 ;
                xmtbyte_sent_24_ts0_ec00          <= #TP '0 ;
            end
            else if( ( |xmtbyte_ts0_sent )
                  && ( {ts0_sym1_to_6_1b1b[0][3] , ts0_sym1_to_6_1b1b[0][1]} == 2'b00 ) ) begin
                ts0_ec00_count                    <= #TP ( xmtbyte_sent_24_ts0_ec00 )                  ? ts0_ec00_count : $bits(ts0_ec00_count)'(ts0_ec00_count + update_ts_cnt) ;
                xmtbyte_sent_24_ts0_ec00          <= #TP ( (ts0_ec00_count + update_ts_cnt) >= 6'd24 ) ? 1'b1           : 1'b0 ;
            end
        end
    end

// Sent Compliance TS1 twice.
    always_ff @(posedge core_clk or negedge core_rst_n) begin : sent_comp_ts1_lat_PROC
        if (!core_rst_n) begin
            sent_comp_ts1_lat                    <= #TP '0 ;
        end
        else begin
            if( ~ltssm_cmd_compliance_ts1 || xmtbyte_2_compliance_ts1_sent ) begin
                sent_comp_ts1_lat                    <= #TP '0 ;
            end
            else if( load_ltssm_cmd_compliance_ts1 && os_send_start && crnt_grant[G_TS1_BIT] ) begin
                sent_comp_ts1_lat                    <= #TP 1'b1 ;
            end
        end
    end
    
    always_comb begin
        xmtbyte_2_compliance_ts1_sent = sent_comp_ts1_lat & load_ltssm_cmd_compliance_ts1 & os_send_start & crnt_grant[G_TS1_BIT] ;
    end


 
                
//xmtbyte_ts_cnt is purely a ts1/2 sent count. No TS content comparison to reset the count
    always_ff @(posedge core_clk or negedge core_rst_n) begin : ts_phase_d_PROC
        if (!core_rst_n) begin
            ts_phase_d                    <= #TP '0 ;
        end
        else begin
            ts_phase_d                    <= #TP { ts2_sending_req , ts1_sending_req , ts0_sending_req } ;
        end
    end
                
                
    always_ff @(posedge core_clk or negedge core_rst_n) begin : xmtbyte_ts_cnt_PROC
        if (!core_rst_n) begin
            xmtbyte_ts_cnt                    <= #TP '0 ;
            xmtbyte_1024_ts_sent              <= #TP '0 ;

        end
        else if(   ltssm_clear || ( { ts2_sending_req , ts1_sending_req , ts0_sending_req } != ts_phase_d ) ) begin
            xmtbyte_ts_cnt                    <= #TP $bits(xmtbyte_ts_cnt)'( update_ts_cnt ) ;
            xmtbyte_1024_ts_sent              <= #TP '0 ;
        end
        else if( ~crnt_grnt_is_os || crnt_grant[G_FTS_BIT] || crnt_grant[G_SDS_BIT] || crnt_grant[G_EI_BIT] || crnt_grant[G_EIE_8SYM_BIT] ) begin
            xmtbyte_ts_cnt                    <= #TP '0 ;
            xmtbyte_1024_ts_sent              <= #TP '0 ;

        end
        else if( os_send_start ) begin
            xmtbyte_ts_cnt                    <= #TP $bits(xmtbyte_ts_cnt)'( xmtbyte_ts_cnt + update_ts_cnt ) ;
            xmtbyte_1024_ts_sent              <= #TP cfg_fast_link_mode ? ( (xmtbyte_ts_cnt + update_ts_cnt) >= CNT_16   ) 
                                                                        : ( (xmtbyte_ts_cnt + update_ts_cnt) >= CNT_1024 ) ;
        end
    end


// xmtbyte_spd_chg_sent : Indicates 1 TS1/2 that speed_change bit=1 is sent.
    always_ff @(posedge core_clk or negedge core_rst_n) begin : xmtbyte_spd_chg_sent_PROC
        if (!core_rst_n) begin
            xmtbyte_spd_chg_sent              <= #TP '0 ;
        end
        else begin
            if( ( |xmtbyte_ts1_sent ) || ( |xmtbyte_ts2_sent ) ) begin
                xmtbyte_spd_chg_sent              <= #TP load_ltssm_ts_speed_change ;
            end
        end
    end

// xmtbyte_dis_link_sent : Indicates 1 TS1/2 that disable link=1 is sent
    always_ff @(posedge core_clk or negedge core_rst_n) begin : xmtbyte_dis_link_sent_PROC
        if (!core_rst_n) begin
            xmtbyte_dis_link_sent              <= #TP '0 ;
        end
        else begin
            if( ( |xmtbyte_ts1_sent ) || ( |xmtbyte_ts2_sent ) ) begin
                xmtbyte_dis_link_sent              <= #TP ts1_sym5_tctl[1] ;
            end
        end
    end


// -----------------------------------
//  Flit Error injection Flags
// -----------------------------------

    // 1cycle delay smlh_ltssm_state to align with ltssm_cmd_i 
    // Loading smlh_ltssm_state_d to align sending OS
    always_ff @(posedge core_clk or negedge core_rst_n) begin : smlh_ltssm_state_d_PROC
        if (!core_rst_n) begin
            smlh_ltssm_state_d         <= #TP S_DETECT_QUIET ;
            load_smlh_ltssm_state_d    <= #TP S_DETECT_QUIET ;
        end
        else begin
                                                                       smlh_ltssm_state_d         <= #TP smlh_ltssm_state ;
            if( os_send_done || (~crnt_grnt_is_os & next_grnt_is_os) ) load_smlh_ltssm_state_d    <= #TP smlh_ltssm_state_d ;
        end
    end

    // Each OS sending flag
    always_comb begin
        int_xmtbyte_einj_in_os.in_ts0 = crnt_grant[G_TS0_BIT] ;
        int_xmtbyte_einj_in_os.in_ts1 = crnt_grant[G_TS1_BIT] ;
        int_xmtbyte_einj_in_os.in_ts2 = crnt_grant[G_TS2_BIT] ;
        int_xmtbyte_einj_in_os.in_skp = crnt_grant[G_SKP_BIT] ;
        int_xmtbyte_einj_in_os.in_eie = crnt_grant[G_EIE_BIT] ;
        int_xmtbyte_einj_in_os.in_eid = crnt_grant[G_EI_BIT] ;
        int_xmtbyte_einj_in_os.in_sds = crnt_grant[G_SDS_BIT] ;
    end

    // Timing Alignmet with output data
    logic [5:0] xmtbyte_latched_loadpat_ltssmstate_lgc_o;
    assign xmtbyte_latched_loadpat_ltssmstate = ltssm_state_e'(xmtbyte_latched_loadpat_ltssmstate_lgc_o); // static cast for conversion to enum type
    localparam FLIT_EINJ_DLY_CYCLE  = BYTE_XMT_LATENCY ;
    localparam FLIT_EINJ_DLY_WIDTH = $bits(load_smlh_ltssm_state_d) + $bits(xmtbyte_einj_in_os) ;

    delay_n
     #(
        FLIT_EINJ_DLY_CYCLE,
        FLIT_EINJ_DLY_WIDTH
    ) u_delay_loadpat_ltssmstate (
          .clk        (core_clk)
        , .rst_n      (core_rst_n)
        , .clear      (1'b0)
        , .din        ({ load_smlh_ltssm_state_d                  , int_xmtbyte_einj_in_os } )
        , .dout       ({ xmtbyte_latched_loadpat_ltssmstate_lgc_o , xmtbyte_einj_in_os     } )
    );


endmodule
