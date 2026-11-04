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

// --------------------------------------------------------------------------
// ---  RCS information:
// ---    $DateTime: 2023/06/26 08:32:07 $
// ---    $Revision: #4 $
// ---    $Id: //dwh/pcie_iip/main/fairbanks/design/Cdm/cdm_flit_prf_msur_reg.sv#4 $
// -------------------------------------------------------------------------
// ----------------------------------------------------------------------------- 
// --- Module Description: 
// ----------------------------------------------------------------------------- 
// --- This module contains Flit Performance Measurement Extended Capability. 
// --- The Flit Performance Measurement Extended Capability is instantiated for Ports and RCRBs that support Flit Mode. 
// --- This capability is optional. This capability is permitted in Downstream Ports, in Function 0 of an Upstream Port, and in  
//     RCRBs. This capability is not permitted in other Functions.. 
// ----------------------------------------------------------------------------- 
 
`include "include/DWC_pcie_ctl_all_defs.svh" 
 `include "products/DWC_pcie_core_pkg.svh"

 module cdm_flit_prf_msur_reg 
import DWC_pcie_core_pkg::latency_tracking_status_e;
import DWC_pcie_core_pkg::DONE;
import DWC_pcie_core_pkg::ERROR;
import DWC_pcie_core_pkg::IDLE;
#( 
    parameter INST                    = 0,                            // The uniquifying parameter for each port logic instance. 
    parameter FUNC_NUM                = 0,                            // uniquifying parameter per function 
    parameter NR_REGS_FLIT_PERF_MESUR = 4,                            // Number of registers per capability 
    parameter RCRB                    = 0,                            // if RCRB == 1, u_rcrb_cdm_ecfg_reg/cdm_flit_prf_msur_reg instance 
                                                                      // if RCRB == 0, u_cdm_ecfg_reg/cdm_flit_prf_msur_reg instance 
    parameter TP                      = `TP                           // RTL Design Clock to Q output delay (simulator safety) 
) 

                             ( 
    // -------------- Inputs ---------------- 
    input                                core_clk,                    // Core Clock 
    input                                non_sticky_rst_n,            // Non-Sticky Reset 
    input                                sticky_rst_n,                // Sticky Reset   
    input                                cdm_clk_g,                  // gated version of the aux_clk_g, based on access activity to cdm, enable signal comes from lbc                                   
    input  [31:0]                        lbc_cdm_data,                // Write Data 
    input                                lbc_cdm_dbi,                 // DBI Access 
    input                                dbi_ro_wr_en,                // DBI Write Enable of ReadOnly registers 
                                         
    input  [3:0]                         flit_write_pulse,            // Write Byte Enable 
    input  [NR_REGS_FLIT_PERF_MESUR-1:0] flit_perf_msur_reg_id,        // Flit perf_msur Extended Capability Register ID 
    input  [3:0]                         device_type,      
    input                                cxl_rcrb_enable, 
    input                                cfg_msi_en_pf0 ,                 
    input                                cfg_msix_en_pf0, 

    input  latency_tracking_status_e     flit_latency_status,
    input  [15:0]                        flit_latency_value,
    input  latency_tracking_status_e     ltssm_st_trans1_status,
    input  latency_tracking_status_e     ltssm_st_trans2_status,
    input  latency_tracking_status_e     ltssm_st_trans3_status,
    input  latency_tracking_status_e     ltssm_st_trans4_status,
    input  latency_tracking_status_e     ltssm_st_trans5_status,
    input  [15:0]                        ltssm_st_trans_latency, 
  
        // -------------- Outputs -------------- 
    output reg [31:0]                     flit_perf_msur_reg_data        ,    
    output reg [9:0]                      flit_perf_interr_vec           ,     
    output     [2:0]                      ltssm_trck_reg_cnt             , 
    output reg [2:0]                      flit_response_type             ,
    output reg [1:0]                      flit_type_measured             ,
    output reg                            cfg_track_mode                 ,
    output reg [4:0]                      Ltssm_state_trans_trck         , 
    output reg                            trg_evnt_interr                ,
    output reg                            cfg_flit_latency_msi                 

    ,output reg                            sts_1_ltssm_trg_evnt_interr     
    ,output reg                            cfg_sts_1_ltssm_latency_msi     

);                                                         
 
// -------------- Internal Signals -------------- 
wire    [7:0]        flit_perf_msur_reg_03, flit_perf_msur_reg_02, flit_perf_msur_reg_01, flit_perf_msur_reg_00; 
wire    [7:0]        flit_perf_msur_reg_07, flit_perf_msur_reg_06, flit_perf_msur_reg_05, flit_perf_msur_reg_04; 
wire    [7:0]        flit_perf_msur_reg_11, flit_perf_msur_reg_10, flit_perf_msur_reg_09, flit_perf_msur_reg_08; 
wire    [7:0]        flit_perf_msur_reg_15, flit_perf_msur_reg_14, flit_perf_msur_reg_13, flit_perf_msur_reg_12; 

latency_tracking_status_e     flit_latency_status_r;
reg     [4:0]        flit_latency_trck;
reg     [1:0]        flit_latency_trck_sts;
reg     [15:0]       flit_trck_cnt;
logic                flit_latency_measurement_en_r;
logic                clr_flit_latency_trck;
logic                flit_trck_overflow;
logic                 interr_trg_evnt_flit, interr_trg_evnt_flit_s, interr_trg_evnt_flit_d;
logic   [5:0]        flit_interrupt_threshold;
logic   [8:0]        ltssm_lwr_3_interrupt_threshold;
logic   [15:0]       ltssm_upr_2_interrupt_threshold;
logic                trg_evnt_interr_d;

reg     [1:0]        sts_1_ltssm_latency_trck_sts;
reg     [4:0]        sts_1_ltssm_latency_trck;
reg     [15:0]       sts_1_ltssm_st_trans_trck_cnt;
latency_tracking_status_e    sts_1_ltssm_trans_trck_status;
logic                sts_1_ltssm_latency_trck_en;
logic                 sts_1_trg_evnt, sts_1_trg_evnt_s, sts_1_trg_evnt_d;
logic   [15:0]       sts_1_ltssm_interrupt_threshold;
logic                sts_1_ltssm_st_cnt_overflow;
logic                sts_1_ltssm_trg_evnt_interr_d;
wire    [7:0]        flit_perf_msur_reg_19, flit_perf_msur_reg_18, flit_perf_msur_reg_17, flit_perf_msur_reg_16; 
 
wire   int_lbc_cdm_dbi; 
assign int_lbc_cdm_dbi    = lbc_cdm_dbi & dbi_ro_wr_en; 

wire   pcie_sw_down;
wire   rc_device;
assign pcie_sw_down     = (device_type == `PCIE_SW_DOWN);
assign rc_device        = (device_type == `PCIE_RC);
// ============================================================================= 
// Flit Performance Measurement Extended Capability 
// ============================================================================= 
 
// ----------------------------------------------------------------------------- 
// Flit Performance Measurement Extended Capability Header Register 
// ----------------------------------------------------------------------------- 
// flit_perf_msur_reg_id - 0 
// PCIE Offset           - `FLIT_PERFORMANCE_MEASUREMENT_PTR + 00h 
// length                - 4 byte 
// Cfig register         - flit_perf_msur_reg_03, flit_perf_msur_reg_02, flit_perf_msur_reg_01, flit_perf_msur_reg_00 
// register              - Flit Performance Measurement Extended Capability ID [15:0] : RO 
//                       - Capability Version [19:16]                                 : RO 
//                       - Next Capability Offset [31:20]                             : RO 
// ----------------------------------------------------------------------------- 
reg    [15:0]                      flit_perf_msur_cap_id ;                     // Flit Performance Measurement Extended Capability ID [15:0] 
reg    [3:0]                       flit_perf_msur_ver ;                        // Capability Version [19:16] 
reg    [11:0]                      flit_perf_msur_next_ptr ;                   // Next Capability Offset [31:20] 
reg                                flit_perf_msur_next_ptr_updated;            // Asserted when Flit Performance Measurement Extended Capability header has been changed by a DBI write 
 
always @(posedge cdm_clk_g or negedge sticky_rst_n) begin : flit_perf_msur_cap_id_ver_PROC 
   if (!sticky_rst_n) begin 
      flit_perf_msur_cap_id     <= #TP `PCIE_FLIT_PERFORMANCE_MEASUREMENT_ECAP_ID ; 
      flit_perf_msur_ver        <= #TP `PCIE_FLIT_PERFORMANCE_MEASUREMENT_ECAP_VER ; 
   end 
   // Read-Only registers, but writable through DBI 
   else begin 
        flit_perf_msur_cap_id[7:0]   <= #TP (flit_perf_msur_reg_id[0] & flit_write_pulse[0] & int_lbc_cdm_dbi ) ? lbc_cdm_data[7:0]   : flit_perf_msur_cap_id[7:0] ; 
        flit_perf_msur_cap_id[15:8]  <= #TP (flit_perf_msur_reg_id[0] & flit_write_pulse[1] & int_lbc_cdm_dbi ) ? lbc_cdm_data[15:8]  : flit_perf_msur_cap_id[15:8] ; 
        flit_perf_msur_ver           <= #TP (flit_perf_msur_reg_id[0] & flit_write_pulse[2] & int_lbc_cdm_dbi ) ? lbc_cdm_data[19:16] : flit_perf_msur_ver ; 
   end 
end 
 
 
// Remember if the user updates the next pointer 
always @( posedge core_clk or negedge sticky_rst_n ) begin : flit_perf_msur_next_ptr_updated_PROC 
   if ( !sticky_rst_n ) begin 
      flit_perf_msur_next_ptr_updated <= #TP 1'b0; 
   end else if (flit_perf_msur_reg_id[0] && int_lbc_cdm_dbi && |flit_write_pulse[3:2]) begin 
      flit_perf_msur_next_ptr_updated <= #TP 1'b1; 
   end 
end 
 
 
// Next Pointer logic 
always @( posedge core_clk or negedge sticky_rst_n ) begin : flit_perf_msur_next_ptr_PROC 
   if ( !sticky_rst_n ) begin 
      flit_perf_msur_next_ptr[11:0] <= #TP `FLIT_PERFORMANCE_MEASUREMENT_NEXT_PTR; 
   end else if(flit_perf_msur_reg_id[0] && int_lbc_cdm_dbi) begin 
      flit_perf_msur_next_ptr[3:0]  <= #TP (flit_write_pulse[2]) ? lbc_cdm_data[23:20] : flit_perf_msur_next_ptr[3:0]; 
      flit_perf_msur_next_ptr[11:4] <= #TP (flit_write_pulse[3]) ? lbc_cdm_data[31:24] : flit_perf_msur_next_ptr[11:4]; 
   end else if ((rc_device || pcie_sw_down )&& !flit_perf_msur_next_ptr_updated ) begin
      flit_perf_msur_next_ptr[11:0]  <= #TP `DM_RP_FLIT_PERFORMANCE_MEASUREMENT_NEXT_PTR ;
   end else if (!flit_perf_msur_next_ptr_updated) begin 
      flit_perf_msur_next_ptr[11:0]  <= #TP (cxl_rcrb_enable && |RCRB) ?  `RCRB_FLIT_PERFORMANCE_MEASUREMENT_NEXT_PTR  : 
                                              `FLIT_PERFORMANCE_MEASUREMENT_NEXT_PTR ; 
   end 
end 
assign {flit_perf_msur_reg_03, flit_perf_msur_reg_02, flit_perf_msur_reg_01, flit_perf_msur_reg_00} = { flit_perf_msur_next_ptr, 
                                                                                                flit_perf_msur_ver, 
                                                                                                flit_perf_msur_cap_id 
                                                                                              }; 
                                                                                              
 // ----------------------------------------------------------------------------- 
//  Flit Performance Measurement Capability Register
// ----------------------------------------------------------------------------- 
// flit_perf_msur_reg_id      - 1 
// PCIE Offset                - `FLIT_PERFORMANCE_MEASUREMENT_PTR + 04h 
// length                     - 4 byte 
// Cfig register              - flit_perf_msur_reg_07, flit_perf_msur_reg_06, flit_perf_msur_reg_05, flit_perf_msur_reg_04 
// register                   - Flit Performance Interrupt Vector [9:0]                 : HwInit 
//                            - LTSSM Tracking Register Count [12:10]                   : HwInit 
//                            - Rsvdp [31:13] 
// ----------------------------------------------------------------------------- 

always @(posedge cdm_clk_g or negedge sticky_rst_n) begin : flit_perf_inter_vect_ltssm_trck_reg_cnt_PROC 
   if (!sticky_rst_n) begin 
      flit_perf_interr_vec           <= #TP `PERF_INTERR_VEC ; 
   end 
   // HwInit registers. 
   else begin 
        // The following registers are clocked by cdm_clk_g which is a gated version of the core_clk used inside the CDM
        flit_perf_interr_vec[7:0]   <= #TP ( (cfg_msix_en_pf0 | cfg_msi_en_pf0 ) & (flit_perf_msur_reg_id[1] & flit_write_pulse[0] & int_lbc_cdm_dbi ) )? 
        lbc_cdm_data[7:0]    : flit_perf_interr_vec[7:0] ; 
        flit_perf_interr_vec[9:8]   <= #TP ( (cfg_msix_en_pf0 | cfg_msi_en_pf0 ) & (flit_perf_msur_reg_id[1] & flit_write_pulse[1] & int_lbc_cdm_dbi ) )? 
        lbc_cdm_data[9:8]    : flit_perf_interr_vec[9:8] ; 
      end 
end                                                                                              

assign ltssm_trck_reg_cnt = `LTSSM_TRCK_REG_CNT;  
assign {flit_perf_msur_reg_07,flit_perf_msur_reg_06,flit_perf_msur_reg_05,flit_perf_msur_reg_04} = { {19{1'b0}}, ltssm_trck_reg_cnt,flit_perf_interr_vec} ; 
 
 
 // ----------------------------------------------------------------------------- 
//  Flit Performance Measurement Control Register  
// ----------------------------------------------------------------------------- 
// flit_perf_msur_reg_id      - 2 
// PCIE Offset                - `FLIT_PERFORMANCE_MEASUREMENT_PTR + 08h 
// length                     - 4 byte 
// Cfig register              - flit_perf_msur_reg_11, flit_perf_msur_reg_10, flit_perf_msur_reg_09, flit_perf_msur_reg_08 
// register                   - Flit Latency Measurement Enable                                                                             : RW 
//                            - Flit Response Type [3:1]                                                                                    : RW 
//                               Bit 1  Flit to Ack Latency 
//                               Bit 2  Flit to Nak Latency 
//                               Bit 3  Nak to Replay Latency 
//                            - Flit Type being measured [5:4]                                                                              : RW    
//                            - Number of instances to track [10:6]                                                                         : RW 
//                            - Interrupt if delay for any tracked Flit exceeds this encoded value [13:11]                                  : RW 
//                            - LTSSM State Transition Tracker [18:14]                                                                      : RW 
//                               Bit 14  L0 to Recovery due to a Framing Error / software directed while in L0 
//                               Bit 15  L0p – Electrical Idle to start of Data Stream on Lane on an upconfig 
//                               Bit 16  L1.0 to L0 
//                               Bit 17  L1.1 to L0  
//                               Bit 18  L1.2 to L0 
//                            - Number of instances to track for LTSSM transition [23:19]                                                   : RW 
//                            - Interrupt if any of the events covered by the low 3 bits of LTSSM State Transition Tracker (bits 16:14 of     RW 
//                              this register) exceeds this encoded value [26:24]                                                           : RW 
//                            - Interrupt if any of the events covered by low 2 bits of LTSSM State Transition Tracker (bits 18:17 of this    RW 
//                              register) exceeds this value [29:27]                                                                        : RW 
//                            - RsvdP [31:30]                                                                                               : RW 
// ----------------------------------------------------------------------------- 

reg           flit_latency_measurement_en ;  
reg [2:0]     flit_resp_type              ;
reg [1:0]     flit_type_meas              ;
reg [4:0]     num_inst_trck               ;
reg [2:0]     flit_delay_trck_interr      ;
reg [4:0]     Ltssm_st_trans_trck         ;
reg [4:0]     num_inst_trck_ltssm_trans   ;
reg [2:0]     bit_16_15_14_interr_value   ;
reg [2:0]     bit_18_17_interr_value      ;

always @(posedge core_clk or negedge non_sticky_rst_n) begin : Latch_flit_type_measured_PROC
    if(!non_sticky_rst_n) begin 
    flit_type_measured    <=  #TP 'b0;
    end  else if (!flit_latency_measurement_en) begin
    flit_type_measured    <=  #TP 'b0; 
    end else if ((flit_latency_trck_sts == 2'b00) && (flit_type_meas == 2'b01 || flit_type_meas == 2'b10)) begin
    flit_type_measured    <=  #TP flit_type_meas; 
    end
end 
always @(posedge core_clk or negedge non_sticky_rst_n) begin : Latch_flit_response_type_PROC
    if(!non_sticky_rst_n) begin 
    flit_response_type    <=  #TP 'b0;
    end  else if ((!flit_latency_measurement_en) || (flit_latency_trck_sts == 2'b10) || (flit_latency_trck_sts == 2'b11)) begin
    flit_response_type    <=  #TP 'b0; 
    end else if ((flit_latency_trck_sts == 2'b00) || (flit_latency_trck_sts == 2'b01)) begin
    flit_response_type    <=  #TP flit_resp_type; 
    end
end 

assign cfg_track_mode = (num_inst_trck == 'b0) ? 1'b1 : 1'b0;  // 0 -> track the aggregate of number of instances  //  1 -> track worest case delay

always @(posedge core_clk or negedge non_sticky_rst_n) begin : ltssm_trck_en_PROC
    if(!non_sticky_rst_n) begin 
    Ltssm_state_trans_trck    <=  #TP 'b0; 
    end  else if (!flit_latency_measurement_en || (sts_1_ltssm_latency_trck_sts == 2'b10) || (sts_1_ltssm_latency_trck_sts == 2'b11) || ((num_inst_trck_ltssm_trans == 'b0) && (sts_1_ltssm_trans_trck_status == DONE))) begin
    Ltssm_state_trans_trck    <=  #TP 'b0;
    end else if (flit_latency_measurement_en && ((sts_1_ltssm_latency_trck_sts == 2'b00) || (sts_1_ltssm_latency_trck_sts == 2'b01))) begin
       if (Ltssm_st_trans_trck[0]) begin 
          Ltssm_state_trans_trck <= #TP 5'b00001;
       end else if (Ltssm_st_trans_trck[1]) begin
          Ltssm_state_trans_trck <= #TP 5'b00010;
       end else if (Ltssm_st_trans_trck[2]) begin
          Ltssm_state_trans_trck <= #TP 5'b00100;
       end  else if (Ltssm_st_trans_trck[3]) begin
          Ltssm_state_trans_trck <= #TP 5'b01000;
       end  else if (Ltssm_st_trans_trck[4]) begin
          Ltssm_state_trans_trck <= #TP 5'b10000;
       end  else begin
          Ltssm_state_trans_trck <= #TP 'b0;
       end
    end
end 

always @(posedge cdm_clk_g or negedge non_sticky_rst_n) begin : flit_perf_msur_cntrl_reg_PROC 
   if (!non_sticky_rst_n) begin 
      flit_latency_measurement_en             <= #TP 1'b0      ; 
      flit_resp_type                          <= #TP {3{1'b0}} ; 
      flit_type_meas                          <= #TP {2{1'b0}} ; 
      num_inst_trck                           <= #TP {5{1'b0}} ; 
      flit_delay_trck_interr                  <= #TP {3{1'b0}} ; 
      Ltssm_st_trans_trck                     <= #TP {5{1'b0}} ; 
      num_inst_trck_ltssm_trans               <= #TP {5{1'b0}} ; 
      bit_16_15_14_interr_value               <= #TP {3{1'b0}} ;       
      bit_18_17_interr_value                  <= #TP {3{1'b0}} ; 
   end                                   
   else begin 
      // The following registers are clocked by cdm_clk_g which is a gated version of the core_clk used inside the CDM                           
      flit_latency_measurement_en             <= #TP (flit_perf_msur_reg_id[2] & flit_write_pulse[0] ) ? lbc_cdm_data[0]     : flit_latency_measurement_en      ; 
      flit_resp_type                          <= #TP (flit_perf_msur_reg_id[2] & flit_write_pulse[0] ) ? lbc_cdm_data[3:1]   : flit_resp_type                   ;      
      flit_type_meas                          <= #TP (flit_perf_msur_reg_id[2] & flit_write_pulse[0] ) ? lbc_cdm_data[5:4]   : flit_type_meas               ; 
      num_inst_trck[1:0]                      <= #TP (flit_perf_msur_reg_id[2] & flit_write_pulse[0] ) ? lbc_cdm_data[7:6]   : num_inst_trck[1:0]               ; 
      num_inst_trck[4:2]                      <= #TP (flit_perf_msur_reg_id[2] & flit_write_pulse[1] ) ? lbc_cdm_data[10:8]  : num_inst_trck[4:2]               ; 
      flit_delay_trck_interr                  <= #TP (flit_perf_msur_reg_id[2] & flit_write_pulse[1] ) ? lbc_cdm_data[13:11] : flit_delay_trck_interr           ; 
      Ltssm_st_trans_trck[1:0]                <= #TP (flit_perf_msur_reg_id[2] & flit_write_pulse[1] ) ? lbc_cdm_data[15:14] : Ltssm_st_trans_trck[1:0]         ; 
      Ltssm_st_trans_trck[4:2]                <= #TP (flit_perf_msur_reg_id[2] & flit_write_pulse[2] ) ? lbc_cdm_data[18:16] : Ltssm_st_trans_trck[4:2]         ; 
      num_inst_trck_ltssm_trans               <= #TP (flit_perf_msur_reg_id[2] & flit_write_pulse[2] ) ? lbc_cdm_data[23:19] : num_inst_trck_ltssm_trans        ; 
      bit_16_15_14_interr_value               <= #TP (flit_perf_msur_reg_id[2] & flit_write_pulse[3] ) ? lbc_cdm_data[26:24] : bit_16_15_14_interr_value        ; 
      bit_18_17_interr_value                  <= #TP (flit_perf_msur_reg_id[2] & flit_write_pulse[3] ) ? lbc_cdm_data[29:27] : bit_18_17_interr_value           ;      
   end 
end   
 
assign {flit_perf_msur_reg_11,flit_perf_msur_reg_10,flit_perf_msur_reg_09,flit_perf_msur_reg_08} = { {2{1'b0}},  
                                                                                                      bit_18_17_interr_value, 
                                                                                                      bit_16_15_14_interr_value, 
                                                                                                      num_inst_trck_ltssm_trans, 
                                                                                                      Ltssm_st_trans_trck, 
                                                                                                      flit_delay_trck_interr, 
                                                                                                      num_inst_trck, 
                                                                                                      flit_type_meas , 
                                                                                                      flit_resp_type, 
                                                                                                      flit_latency_measurement_en } ; 
  
 
// ----------------------------------------------------------------------------- 
//  Flit Performance Measurement Status Register  
// ----------------------------------------------------------------------------- 
// flit_perf_msur_reg_id      - 3 
// PCIE Offset                - `FLIT_PERFORMANCE_MEASUREMENT_PTR + 0Ch 
// length                     - 4 byte 
// Cfig register              - flit_perf_msur_reg_15, flit_perf_msur_reg_14, flit_perf_msur_reg_13, flit_perf_msur_reg_12 
// register                   - Flit Latency Tracking Status [1:0]                     :   RO 
//                            - Flit Latency Tracking [6:2]                            :   RO 
//                            - Interrupt generated based on trigger event  7          :   RW1C 
//                            - FLIT Latency Tracking Counter [23:8]         :   RO 
//                            - RsvdP [31:24] 
// ----------------------------------------------------------------------------- 
///Clear Flit tracking latency
always @(posedge cdm_clk_g or negedge non_sticky_rst_n) begin 
    if(!non_sticky_rst_n) begin 
    flit_latency_measurement_en_r    <=  #TP 1'b0; 
    end else begin
    flit_latency_measurement_en_r    <=  #TP flit_latency_measurement_en; 
    end 
end 
assign clr_flit_latency_trck = flit_latency_measurement_en & ~flit_latency_measurement_en_r;
 ///Sample Flit tracking Status
always @(posedge core_clk or negedge non_sticky_rst_n) begin 
    if(!non_sticky_rst_n) begin 
    flit_latency_status_r    <=  #TP IDLE; 
    end else begin
    flit_latency_status_r    <=  #TP flit_latency_status; 
    end 
end 
/////////////////////////////////////////////////////////////////
///Number of instances being tracked
always @( posedge core_clk or negedge non_sticky_rst_n ) begin : flit_inst_tracked 
   if ( !non_sticky_rst_n ) begin 
      flit_latency_trck <= #TP 'b0;
   end else if (clr_flit_latency_trck) begin
      flit_latency_trck <= #TP 'b0;
   end else if(flit_latency_measurement_en && (flit_latency_trck_sts != 2'b10)) begin
      if ((flit_latency_status == DONE) && (flit_latency_trck < 5'b11111)) begin 
        flit_latency_trck <= #TP flit_latency_trck + 1'b1;
      end else if((flit_latency_status == ERROR) && (flit_latency_status_r != ERROR)) begin 
        flit_latency_trck <= #TP flit_latency_trck + 1'b1;
      end
   end
end : flit_inst_tracked
/////////////////////////////////////////////////////////////////
///Flit tracking counter
always @( posedge core_clk or negedge non_sticky_rst_n ) begin : flit_cntr_tracked 
   if ( !non_sticky_rst_n ) begin 
      flit_trck_cnt <= #TP 'b0;
   end else if (clr_flit_latency_trck) begin
      flit_trck_cnt <= #TP 'b0;
   end else if(flit_latency_measurement_en && (flit_latency_trck_sts != 2'b10)) begin
      if (flit_latency_status == DONE) begin 
         if (num_inst_trck == 'b0) begin
             if (flit_latency_value > flit_trck_cnt) begin
                flit_trck_cnt <= #TP flit_latency_value;
             end 
         end else begin
             flit_trck_cnt <= #TP flit_latency_value;
         end
      end else if((flit_latency_status == ERROR) && (flit_latency_status_r != ERROR)) begin 
         flit_trck_cnt <= #TP flit_latency_value;
      end
   end
end : flit_cntr_tracked

always @( posedge core_clk or negedge non_sticky_rst_n ) begin : flit_tracked_overflow
   if ( !non_sticky_rst_n ) begin 
      flit_trck_overflow <= #TP 'b0;
   end else if (clr_flit_latency_trck) begin
      flit_trck_overflow <= #TP 'b0;
   end else if(flit_latency_status == ERROR) begin 
      flit_trck_overflow <= #TP 1'b1;
   end
end : flit_tracked_overflow
/////////////////////////////////////////////////////////////////
///Flit latency measurement tracking status
always @( posedge core_clk or negedge non_sticky_rst_n ) begin : flit_tracking_status 
   if ( !non_sticky_rst_n ) begin 
      flit_latency_trck_sts <= #TP 2'b00; //Not Started
   end else if(clr_flit_latency_trck) begin
      flit_latency_trck_sts <= #TP 2'b00; //Not Started
   end else if(flit_latency_measurement_en) begin 
      if (flit_trck_overflow && (flit_latency_trck_sts != 2'b10)) begin
            flit_latency_trck_sts  <= #TP 2'b11 ; //Error
      end else if ((flit_latency_trck == num_inst_trck) && (num_inst_trck != 'b0)) begin
            flit_latency_trck_sts  <= #TP 2'b10 ; //Completed
      end else if (flit_latency_trck_sts != 2'b10) begin
            flit_latency_trck_sts  <= #TP 2'b01 ; //Started
      end
   end
end : flit_tracking_status
/////////////////////////////////////////////////////////////////
///Interrupt generated based on Flit latency measurement
always_comb begin : flit_interrupt_thres
    unique case(flit_delay_trck_interr)
     3'b001 : flit_interrupt_threshold = 6'd12;
     3'b010 : flit_interrupt_threshold = 6'd25;
     3'b011 : flit_interrupt_threshold = 6'd37;
    default : flit_interrupt_threshold = 6'd0; 
    endcase 
end : flit_interrupt_thres

assign interr_trg_evnt_flit_s = (flit_latency_measurement_en && ~clr_flit_latency_trck && (flit_interrupt_threshold != 'd0) && (flit_trck_cnt >= {10'd0,flit_interrupt_threshold})) ? 1'b1 : 1'b0;

always @(posedge core_clk or negedge non_sticky_rst_n) begin : flit_interrupt_pulse
  if(!non_sticky_rst_n) begin
     interr_trg_evnt_flit_d  <= 'b0;
  end else begin
     interr_trg_evnt_flit_d <= interr_trg_evnt_flit_s;
  end
end : flit_interrupt_pulse

assign interr_trg_evnt_flit = interr_trg_evnt_flit_s & ~interr_trg_evnt_flit_d;

always @(posedge core_clk or negedge non_sticky_rst_n) 
begin 
    if(!non_sticky_rst_n) begin 
    trg_evnt_interr    <=  #TP 1'b0; 
    trg_evnt_interr_d  <=  #TP 1'b0; 
    end else begin
         if (interr_trg_evnt_flit) begin
             trg_evnt_interr <= #TP 1'b1;
         end 
         else begin
            if (clr_flit_latency_trck | (flit_perf_msur_reg_id[3] & flit_write_pulse[0] & lbc_cdm_data[7] )) begin
              trg_evnt_interr  <= #TP 1'b0 ;
            end
         end 
         trg_evnt_interr_d  <=  #TP trg_evnt_interr;
     end 
end 

always @(posedge core_clk or negedge non_sticky_rst_n) begin : flit_interrupt_MSI
    if(!non_sticky_rst_n) begin 
      cfg_flit_latency_msi    <=  #TP 1'b0; 
    end else begin
      cfg_flit_latency_msi    <=  #TP trg_evnt_interr & ~trg_evnt_interr_d;
    end 
end
 
/////////////////////////////////////////////////////////////////
assign {flit_perf_msur_reg_15,flit_perf_msur_reg_14,flit_perf_msur_reg_13,flit_perf_msur_reg_12} = { {8{1'b0}},  
                                                                                                      flit_trck_cnt, 
                                                                                                      trg_evnt_interr, 
                                                                                                      flit_latency_trck, 
                                                                                                      flit_latency_trck_sts };  
// ----------------------------------------------------------------------------- 
//  LTSSM Performance Measurement Status 1 Register  
// ----------------------------------------------------------------------------- 
// flit_perf_msur_reg_id      - 4 
// PCIE Offset                - `FLIT_PERFORMANCE_MEASUREMENT_PTR + 10h 
// length                     - 4 byte 
// Cfig register              - flit_perf_msur_reg_19, flit_perf_msur_reg_18, flit_perf_msur_reg_17, flit_perf_msur_reg_16 
// register                   - LTSSM State Tracking Status [1:0]                                                                   :   ROS 
//                            - LTSSM State Tracking [6:2]                                                                          :   ROS 
//                            - Interrupt generated based on trigger event count due to LTSSM State Transition Tracking  7          :   RW1CS 
//                            - LTSSM State Transition Tracking Counter [23:8]                                                      :   ROS 
//                            - RsvdP [31:24] 
// ----------------------------------------------------------------------------- 
always_comb begin : ltssm_trans_latency_status
    unique case(Ltssm_state_trans_trck)
     5'b00001 : sts_1_ltssm_trans_trck_status = ltssm_st_trans1_status;
     5'b00010 : sts_1_ltssm_trans_trck_status = ltssm_st_trans2_status;
     5'b00100 : sts_1_ltssm_trans_trck_status = ltssm_st_trans3_status;
     5'b01000 : sts_1_ltssm_trans_trck_status = ltssm_st_trans4_status;
     5'b10000 : sts_1_ltssm_trans_trck_status = ltssm_st_trans5_status;
    default : sts_1_ltssm_trans_trck_status = IDLE; 
    endcase 
end : ltssm_trans_latency_status

always_comb begin : ltssm_trans_latency_en
    unique case(Ltssm_state_trans_trck)
     5'b00001 : sts_1_ltssm_latency_trck_en = Ltssm_st_trans_trck[0];
     5'b00010 : sts_1_ltssm_latency_trck_en = Ltssm_st_trans_trck[1];
     5'b00100 : sts_1_ltssm_latency_trck_en = Ltssm_st_trans_trck[2];
     5'b01000 : sts_1_ltssm_latency_trck_en = Ltssm_st_trans_trck[3];
     5'b10000 : sts_1_ltssm_latency_trck_en = Ltssm_st_trans_trck[4];
    default : sts_1_ltssm_latency_trck_en = 1'b0; 
    endcase 
end : ltssm_trans_latency_en
/////////////////////////////////////////////////////////////////
///Number of instances being tracked
always @( posedge core_clk or negedge sticky_rst_n ) begin : sts_1_ltssm_tracked 
   if ( !sticky_rst_n ) begin 
      sts_1_ltssm_latency_trck <= #TP 'b0;
   end else if (clr_flit_latency_trck) begin
      sts_1_ltssm_latency_trck <= #TP 'b0;
   end else if(sts_1_ltssm_latency_trck_en && (sts_1_ltssm_trans_trck_status == DONE) && (sts_1_ltssm_latency_trck < 5'b11111)) begin 
      sts_1_ltssm_latency_trck <= #TP sts_1_ltssm_latency_trck + 1'b1;
   end
end : sts_1_ltssm_tracked
/////////////////////////////////////////////////////////////////
///LTSSM S1 tracking counter
always @( posedge core_clk or negedge sticky_rst_n ) begin : sts_1_ltssm_cntr 
   if ( !sticky_rst_n ) begin 
      sts_1_ltssm_st_trans_trck_cnt <= #TP 'b0;
   end else if (clr_flit_latency_trck) begin
      sts_1_ltssm_st_trans_trck_cnt <= #TP 'b0;
   end else if(sts_1_ltssm_latency_trck_en && (sts_1_ltssm_trans_trck_status == DONE)) begin 
      if (num_inst_trck_ltssm_trans == 'b0) begin
         if (ltssm_st_trans_latency > sts_1_ltssm_st_trans_trck_cnt) begin
              sts_1_ltssm_st_trans_trck_cnt <= #TP ltssm_st_trans_latency;
         end 
      end else begin
          sts_1_ltssm_st_trans_trck_cnt <= #TP ltssm_st_trans_latency;
      end
   end
end : sts_1_ltssm_cntr
   
always @( posedge core_clk or negedge sticky_rst_n ) begin : sts_1_ltssm_cntr_overflow
   if ( !sticky_rst_n ) begin 
      sts_1_ltssm_st_cnt_overflow <= #TP 'b0;
   end else if (clr_flit_latency_trck) begin
      sts_1_ltssm_st_cnt_overflow <= #TP 'b0;
   end else if(sts_1_ltssm_trans_trck_status == ERROR) begin 
      sts_1_ltssm_st_cnt_overflow <= #TP 1'b1;
   end
end : sts_1_ltssm_cntr_overflow
/////////////////////////////////////////////////////////////////
///LTSSM S1 latency measurement tracking status
always @( posedge core_clk or negedge sticky_rst_n ) begin : sts_1_ltssm_tracking_status 
   if ( !sticky_rst_n ) begin 
      sts_1_ltssm_latency_trck_sts <= #TP 2'b00; //Not Started
   end else if(clr_flit_latency_trck) begin
      sts_1_ltssm_latency_trck_sts <= #TP 2'b00; //Not Started
   end else if(sts_1_ltssm_latency_trck_en) begin
      if (sts_1_ltssm_st_cnt_overflow) begin
            sts_1_ltssm_latency_trck_sts  <= #TP 2'b11 ; //Error
      end else if ((sts_1_ltssm_latency_trck == num_inst_trck_ltssm_trans) && (num_inst_trck_ltssm_trans != 'b0)) begin
            sts_1_ltssm_latency_trck_sts  <= #TP 2'b10 ; //Completed
      end else begin
            sts_1_ltssm_latency_trck_sts  <= #TP 2'b01 ; //Started
      end
   end
end : sts_1_ltssm_tracking_status
/////////////////////////////////////////////////////////////////
///Interrupt generated based on LTSSM S1 latency measurement
always_comb begin : ltssm_lwr_3_interrupt_thres
    unique case (bit_16_15_14_interr_value)
     3'b001 : ltssm_lwr_3_interrupt_threshold = 9'd100;
     3'b010 : ltssm_lwr_3_interrupt_threshold = 9'd200;
     3'b011 : ltssm_lwr_3_interrupt_threshold = 9'd300;
    default : ltssm_lwr_3_interrupt_threshold = 9'd0; 
    endcase 
end : ltssm_lwr_3_interrupt_thres
always_comb begin : ltssm_upr_2_interrupt_thres
    unique case(bit_18_17_interr_value)
     3'b001 : ltssm_upr_2_interrupt_threshold = 16'h3d09;    //15625
     3'b010 : ltssm_upr_2_interrupt_threshold = 16'h7a12;    //31250
     3'b011 : ltssm_upr_2_interrupt_threshold = 16'hb71b;    //46875
     3'b100 : ltssm_upr_2_interrupt_threshold = 16'hf424;    //62500
     3'b101 : ltssm_upr_2_interrupt_threshold = 16'hffff;    //78125  Need review with SEG
     3'b110 : ltssm_upr_2_interrupt_threshold = 16'hffff;    //156250 Need review with SEG
    default : ltssm_upr_2_interrupt_threshold = 16'h0000; 
    endcase 
end : ltssm_upr_2_interrupt_thres

assign sts_1_ltssm_interrupt_threshold = (|Ltssm_state_trans_trck[2:0]) ? {7'd0,ltssm_lwr_3_interrupt_threshold} : ltssm_upr_2_interrupt_threshold;
assign sts_1_trg_evnt_s = (sts_1_ltssm_latency_trck_en && ~clr_flit_latency_trck && (sts_1_ltssm_interrupt_threshold != 'd0) && (sts_1_ltssm_st_trans_trck_cnt >= sts_1_ltssm_interrupt_threshold)) ? 1'b1 : 1'b0;

always @(posedge core_clk or negedge non_sticky_rst_n) begin : sts_1_interrupt_pulse
  if(!non_sticky_rst_n) begin
     sts_1_trg_evnt_d  <= 'b0;
  end else begin
     sts_1_trg_evnt_d <= sts_1_trg_evnt_s;
  end
end : sts_1_interrupt_pulse

assign sts_1_trg_evnt = sts_1_trg_evnt_s & ~sts_1_trg_evnt_d;

always @(posedge core_clk or negedge sticky_rst_n) begin : ltssm_perf_msur_status_1_reg_PROC 
   if (!sticky_rst_n) begin 
     sts_1_ltssm_trg_evnt_interr          <= #TP 1'b0;
     sts_1_ltssm_trg_evnt_interr_d        <= #TP 1'b0; 
   end                                         
   else begin  
     if (sts_1_trg_evnt) begin
             sts_1_ltssm_trg_evnt_interr <= #TP 1'b1;
         end 
         else begin
            if (clr_flit_latency_trck | (flit_perf_msur_reg_id[4] & flit_write_pulse[0] & lbc_cdm_data[7] )) begin
              sts_1_ltssm_trg_evnt_interr  <= #TP 1'b0 ;
            end
         end 
     sts_1_ltssm_trg_evnt_interr_d        <= #TP sts_1_ltssm_trg_evnt_interr;
    end 
end    

always @(posedge core_clk or negedge non_sticky_rst_n) begin : ltssm_interrupt_MSI
    if(!non_sticky_rst_n) begin 
      cfg_sts_1_ltssm_latency_msi    <=  #TP 1'b0; 
    end else begin
      cfg_sts_1_ltssm_latency_msi    <=  #TP sts_1_ltssm_trg_evnt_interr & ~sts_1_ltssm_trg_evnt_interr_d;
    end 
end
/////////////////////////////////////////////////////////////////
   assign {flit_perf_msur_reg_19, flit_perf_msur_reg_18, flit_perf_msur_reg_17, flit_perf_msur_reg_16} = { {8{1'b0}},  
                                                                                                           sts_1_ltssm_st_trans_trck_cnt , 
                                                                                                           sts_1_ltssm_trg_evnt_interr, 
                                                                                                           sts_1_ltssm_latency_trck, 
                                                                                                           sts_1_ltssm_latency_trck_sts};  
                                                                                                       
 
                                                                                                       
                                                                                                       
 
 
 
 
 
 
 
 
// ----------------------------------------------------------------------------- 
// Register Read Operation 
// ----------------------------------------------------------------------------- 
 
always @(*) 
begin : read_data_PROC 
    unique case (1'b1) 
    flit_perf_msur_reg_id[0]   : flit_perf_msur_reg_data = {flit_perf_msur_reg_03, flit_perf_msur_reg_02, flit_perf_msur_reg_01, flit_perf_msur_reg_00};   // 0x00 
    flit_perf_msur_reg_id[1]   : flit_perf_msur_reg_data = {flit_perf_msur_reg_07, flit_perf_msur_reg_06, flit_perf_msur_reg_05, flit_perf_msur_reg_04};   // 0x04 
    flit_perf_msur_reg_id[2]   : flit_perf_msur_reg_data = {flit_perf_msur_reg_11, flit_perf_msur_reg_10, flit_perf_msur_reg_09, flit_perf_msur_reg_08};   // 0x08 
    flit_perf_msur_reg_id[3]   : flit_perf_msur_reg_data = {flit_perf_msur_reg_15, flit_perf_msur_reg_14, flit_perf_msur_reg_13, flit_perf_msur_reg_12};   // 0x0C 
    flit_perf_msur_reg_id[4]   : flit_perf_msur_reg_data = {flit_perf_msur_reg_19, flit_perf_msur_reg_18, flit_perf_msur_reg_17, flit_perf_msur_reg_16};   // 0x10 
    default          : flit_perf_msur_reg_data = `PCIE_UNUSED_RESPONSE; 
    endcase 
end 


endmodule  
  
