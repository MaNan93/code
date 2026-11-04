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
// ---    $DateTime: 2023/11/20 06:15:14 $
// ---    $Revision: #4 $
// ---    $Id: //dwh/pcie_iip/main/fairbanks/design/Cdm/cdm_flit_err_inj_reg.sv#4 $
// ------------------------------------------------------------------------- 
// ----------------------------------------------------------------------------- 
// --- Module Description: 
// ----------------------------------------------------------------------------- 
// --- This module contains Flit Error Injection Extended Capability. 
// --- This capability is optional. This capability is permitted in Downstream Ports, in Function 0 of an Upstream Port, and inRCRBs.  
// --- This capability is not permitted in other Functions. 
// ----------------------------------------------------------------------------- 
 
`include "include/DWC_pcie_ctl_all_defs.svh" 
 
 module cdm_flit_err_inj_reg 
 #( 
    parameter INST                    = 0,                            // The uniquifying parameter for each port logic instance. 
    parameter FUNC_NUM                = 0,                            // uniquifying parameter per function 
    parameter NR_REGS_FLIT_ERR_INJ    = 9,                            // Number of registers per capability 
    parameter RCRB                    = 0,                            // if RCRB == 1, u_rcrb_cdm_ecfg_reg/cdm_flit_err_inj_reg instance 
                                                                      // if RCRB == 0, u_cdm_ecfg_reg/cdm_flit_err_inj_reg instance 
    parameter TP                      = `TP                           // RTL Design Clock to Q output delay (simulator safety) 
) 

                             ( 
    // -------------- Inputs ---------------- 
    input                                core_clk,                                        // Core Clock 
    input                                non_sticky_rst_n,                                // Non-Sticky Reset 
    input                                sticky_rst_n,                                    // Sticky Reset   
                                                                                          
    input  [31:0]                        lbc_cdm_data,                                    // Write Data 
    input                                lbc_cdm_dbi,                                     // DBI Access 
    input                                dbi_ro_wr_en,                                    // DBI Write Enable of ReadOnly registers 
                                                                                          
    input  [3:0]                         flit_write_pulse,                                // Write Byte Enable 
    input  [NR_REGS_FLIT_ERR_INJ-1:0]    flit_err_inj_reg_id,                            // Flit err_inj Extended Capability Register ID 
    input  [3:0]                         device_type,
    input                                cxl_rcrb_enable,   
    input [1:0]                          cfg_flit_err_tx_inj_sts, 
    input [1:0]                          cfg_flit_err_rx_inj_sts,      
    input [1:0]                          cfg_ordr_set_tx_inj_sts_ts0, 
    input [1:0]                          cfg_ordr_set_tx_inj_sts_ts1, 
    input [1:0]                          cfg_ordr_set_tx_inj_sts_ts2, 
    input [1:0]                          cfg_ordr_set_tx_inj_sts_skp, 
    input [1:0]                          cfg_ordr_set_tx_inj_sts_eieos, 
    input [1:0]                          cfg_ordr_set_tx_inj_sts_eios, 
    input [1:0]                          cfg_ordr_set_tx_inj_sts_sds, 
    input [1:0]                          cfg_ordr_set_tx_inj_sts_poll, 
    input [1:0]                          cfg_ordr_set_tx_inj_sts_cfg, 
    input [1:0]                          cfg_ordr_set_tx_inj_sts_l0, 
    input [1:0]                          cfg_ordr_set_tx_inj_sts_non_eq_recov, 
    input [1:0]                          cfg_ordr_set_tx_inj_sts_recov_eq_ph_1_0, 
    input [1:0]                          cfg_ordr_set_tx_inj_sts_recov_eq_ph_2, 
    input [1:0]                          cfg_ordr_set_tx_inj_sts_recov_eq_ph_3, 
    input [1:0]                          cfg_ordr_set_rx_inj_sts_ts0, 
    input [1:0]                          cfg_ordr_set_rx_inj_sts_ts1, 
    input [1:0]                          cfg_ordr_set_rx_inj_sts_ts2, 
    input [1:0]                          cfg_ordr_set_rx_inj_sts_skp, 
    input [1:0]                          cfg_ordr_set_rx_inj_sts_eieos, 
    input [1:0]                          cfg_ordr_set_rx_inj_sts_eios, 
    input [1:0]                          cfg_ordr_set_rx_inj_sts_sds, 
    input [1:0]                          cfg_ordr_set_rx_inj_sts_poll, 
    input [1:0]                          cfg_ordr_set_rx_inj_sts_cfg, 
    input [1:0]                          cfg_ordr_set_rx_inj_sts_l0, 
    input [1:0]                          cfg_ordr_set_rx_inj_sts_non_eq_recov, 
    input [1:0]                          cfg_ordr_set_rx_inj_sts_recov_eq_ph_1_0, 
    input [1:0]                          cfg_ordr_set_rx_inj_sts_recov_eq_ph_2, 
    input [1:0]                          cfg_ordr_set_rx_inj_sts_recov_eq_ph_3, 
     
    output reg                           cfg_flit_err_inj_en, 
    output reg                           cfg_inj_err_tx_flit_ind, 
    output reg                           cfg_inj_err_rx_flit_ind, 
    output reg [12:0]                    cfg_flit_err_inj_en_data_rate, 
    output reg [4:0]                     cfg_inj_err_num,
    output reg [7:0]                     cfg_inj_err_spacing,
    output reg [2:0]                     cfg_flit_type_inj,       
    output reg [2:0]                     cfg_consec_err_inj, 
    output reg [1:0]                     cfg_curr_inj_err_type, 
    output reg [6:0]                     cfg_flit_err_off, 
    output reg [7:0]                     cfg_err_mag, 
    output reg                           cfg_ordr_set_err_inj_en, 
    output reg                           cfg_inj_err_tx_ordr_set_ind, 
    output wire                          cfg_inj_err_rx_ordr_set_ind, 
    output reg [4:0]                     cfg_ordr_set_inj_err_num, 
    output reg [7:0]                     cfg_ordr_set_inj_err_spacing, 
    output reg                           cfg_inj_err_ts0_os, 
    output reg                           cfg_inj_err_ts1_os, 
    output reg                           cfg_inj_err_ts2_os, 
    output reg                           cfg_inj_err_skp_os, 
    output reg                           cfg_inj_err_eieos_os, 
    output reg                           cfg_inj_err_eios_os, 
    output reg                           cfg_inj_err_sds_os, 
    output reg                           cfg_inj_err_poll_st, 
    output reg                           cfg_inj_err_cfg_st, 
    output reg                           cfg_inj_err_l0_st, 
    output reg                           cfg_inj_err_non_eq_recov_st, 
    output reg                           cfg_inj_err_recov_eq_ph_1_0, 
    output reg                           cfg_inj_err_recov_eq_ph_2, 
    output reg                           cfg_inj_err_recov_eq_ph_3, 
    output reg [15:0]                    cfg_err_inj_bytes, 
    output reg [15:0]                    cfg_err_inj_lane_num, 
    output reg [31:0]                    flit_err_inj_reg_data 
     
); 
 
wire    [7:0]        flit_err_inj_reg_03, flit_err_inj_reg_02, flit_err_inj_reg_01, flit_err_inj_reg_00; 
wire    [7:0]        flit_err_inj_reg_07, flit_err_inj_reg_06, flit_err_inj_reg_05, flit_err_inj_reg_04; 
wire    [7:0]        flit_err_inj_reg_11, flit_err_inj_reg_10, flit_err_inj_reg_09, flit_err_inj_reg_08; 
wire    [7:0]        flit_err_inj_reg_15, flit_err_inj_reg_14, flit_err_inj_reg_13, flit_err_inj_reg_12; 
wire    [7:0]        flit_err_inj_reg_19, flit_err_inj_reg_18, flit_err_inj_reg_17, flit_err_inj_reg_16; 
wire    [7:0]        flit_err_inj_reg_23, flit_err_inj_reg_22, flit_err_inj_reg_21, flit_err_inj_reg_20; 
wire    [7:0]        flit_err_inj_reg_27, flit_err_inj_reg_26, flit_err_inj_reg_25, flit_err_inj_reg_24; 
wire    [7:0]        flit_err_inj_reg_31, flit_err_inj_reg_30, flit_err_inj_reg_29, flit_err_inj_reg_28; 
wire    [7:0]        flit_err_inj_reg_35, flit_err_inj_reg_34, flit_err_inj_reg_33, flit_err_inj_reg_32; 
 
wire   int_lbc_cdm_dbi; 
assign int_lbc_cdm_dbi    = lbc_cdm_dbi & dbi_ro_wr_en; 

wire   pcie_sw_down;
wire   rc_device;
assign pcie_sw_down     = (device_type == `PCIE_SW_DOWN);
assign rc_device        = (device_type == `PCIE_RC);
 
// ============================================================================= 
//Flit Error Injection Extended Capability 
// ============================================================================= 
 
// ----------------------------------------------------------------------------- 
// Flit Error Injection Extended Capability Header Register 
// ----------------------------------------------------------------------------- 
// flit_err_inj_reg_id   - 0 
// PCIE Offset           - `FLIT_ERROR_INJECTION_PTR + 00h 
// length                - 4 byte 
// Cfig register         - flit_err_inj_reg_03, flit_err_inj_reg_02, flit_err_inj_reg_01, flit_err_inj_reg_00 
// register              - Flit  Flit Error Injection Extended Capability ID [15:0]   : RO 
//                       - Capability Version [19:16]                                 : RO 
//                       - Next Capability Offset [31:20]                             : RO 
// ----------------------------------------------------------------------------- 
 
reg    [15:0]                      flit_err_inj_cap_id ;                     // Flit Error Injection Extended Capability ID [15:0] 
reg    [3:0]                       flit_err_inj_ver ;                        // Capability Version [19:16] 
reg    [11:0]                      flit_err_inj_next_ptr ;                   // Next Capability Offset [31:20] 
reg                                flit_err_inj_next_ptr_updated;            // Asserted when Flit Performance Measurement Extended Capability header has been changed by a DBI write 
 
always @(posedge core_clk or negedge sticky_rst_n) begin : flit_err_inj_cap_id_ver_PROC 
   if (!sticky_rst_n) begin 
      flit_err_inj_cap_id     <= #TP `PCIE_FLIT_ERROR_INJECTION_ECAP_ID  ; 
      flit_err_inj_ver        <= #TP `PCIE_FLIT_ERROR_INJECTION_ECAP_VER  ; 
   end 
   // Read-Only registers, but writable through DBI 
   else begin 
        flit_err_inj_cap_id[7:0]   <= #TP (flit_err_inj_reg_id[0] & flit_write_pulse[0] & int_lbc_cdm_dbi ) ? lbc_cdm_data[7:0]   : flit_err_inj_cap_id[7:0] ; 
        flit_err_inj_cap_id[15:8]  <= #TP (flit_err_inj_reg_id[0] & flit_write_pulse[1] & int_lbc_cdm_dbi ) ? lbc_cdm_data[15:8]  : flit_err_inj_cap_id[15:8] ; 
        flit_err_inj_ver           <= #TP (flit_err_inj_reg_id[0] & flit_write_pulse[2] & int_lbc_cdm_dbi ) ? lbc_cdm_data[19:16] : flit_err_inj_ver ; 
   end 
end 
 
 
// Remember if the user updates the next pointer 
always @( posedge core_clk or negedge sticky_rst_n ) begin : flit_err_inj_next_ptr_updated_PROC 
   if ( !sticky_rst_n ) begin 
      flit_err_inj_next_ptr_updated <= #TP 1'b0; 
   end else if (flit_err_inj_reg_id[0] && int_lbc_cdm_dbi && |flit_write_pulse[3:2]) begin 
      flit_err_inj_next_ptr_updated <= #TP 1'b1; 
   end 
end 
 
 
// Next Pointer logic 
always @( posedge core_clk or negedge sticky_rst_n ) begin : flit_err_inj_next_ptr_PROC 
   if ( !sticky_rst_n ) begin 
      flit_err_inj_next_ptr[11:0] <= #TP `FLIT_ERROR_INJECTION_NEXT_PTR; 
   end else if(flit_err_inj_reg_id[0] && int_lbc_cdm_dbi) begin 
      flit_err_inj_next_ptr[3:0]  <= #TP (flit_write_pulse[2]) ? lbc_cdm_data[23:20] : flit_err_inj_next_ptr[3:0]; 
      flit_err_inj_next_ptr[11:4] <= #TP (flit_write_pulse[3]) ? lbc_cdm_data[31:24] : flit_err_inj_next_ptr[11:4]; 
   end else if ((rc_device || pcie_sw_down )&& !flit_err_inj_next_ptr_updated ) begin
      flit_err_inj_next_ptr[11:0]  <= #TP `DM_RP_FLIT_ERROR_INJECTION_NEXT_PTR ;
   end else if (!flit_err_inj_next_ptr_updated) begin 
      flit_err_inj_next_ptr[11:0]  <= #TP (cxl_rcrb_enable && |RCRB ) ?  `RCRB_FLIT_ERROR_INJECTION_NEXT_PTR  : 
                                            `FLIT_ERROR_INJECTION_NEXT_PTR ; 
   end 
end 
assign {flit_err_inj_reg_03, flit_err_inj_reg_02, flit_err_inj_reg_01, flit_err_inj_reg_00} = { flit_err_inj_next_ptr, 
                                                                                                flit_err_inj_ver, 
                                                                                                flit_err_inj_cap_id 
                                                                                              }; 
// ----------------------------------------------------------------------------- 
// Flit Flit Error Injection Capability Register 
// ----------------------------------------------------------------------------- 
// flit_err_inj_reg_id   - 1 
// PCIE Offset           - `FLIT_ERROR_INJECTION_PTR + 04h 
// length                - 4 byte 
// Cfig register         - flit_err_inj_reg_07, flit_err_inj_reg_06, flit_err_inj_reg_05, flit_err_inj_reg_04 
// register              - Rsvdp [31:0] 
// -----------------------------------------------------------------------------     
assign {flit_err_inj_reg_07,flit_err_inj_reg_06,flit_err_inj_reg_05,flit_err_inj_reg_04} =  {32{1'b0}}   ;    

// ----------------------------------------------------------------------------- 
// Flit Error Injection Control 1 Register 
// -----------------------------------------------------------------------------  
// flit_err_inj_reg_id   - 2 
// PCIE Offset           - `FLIT_ERROR_INJECTION_PTR + 08h 
// length                - 4 byte 
// Cfig register         - flit_err_inj_reg_11, flit_err_inj_reg_10, flit_err_inj_reg_09, flit_err_inj_reg_08  
// register              - Flit Error Injection Enable  [0]              :  RW 
//                       - Inject Errors on Transmitted Flits [1]        :  RW
//                       - Inject Errors on Received Flits    [2]        :  RW 
//                       - Flit Error Injection Enable Data Rate [8:3]   :  RW 
//                       - Flit Error Injection Enable Data Rate [15:9]  :  Rsvdp 
//                       - Number of Errors Injected [20:16]             :  RWS 
//                       - Spacing Between Injected Errors [28:21]       :  RW 
//                       - Injection on Flit Type [31:29]                :  RWS 
// ----------------------------------------------------------------------------- 
reg [5:0] cfg_flit_err_inj_en_data_rate_rw;

always @(posedge core_clk or negedge non_sticky_rst_n) begin : flit_err_inj_cntrl_1_reg_non_sticky_PROC 
   if (!non_sticky_rst_n) begin 
      cfg_flit_err_inj_en                     <= #TP 1'b0      ; 
      cfg_inj_err_tx_flit_ind                 <= #TP 1'b0      ; 
      cfg_inj_err_rx_flit_ind                 <= #TP 1'b0      ; 
      cfg_flit_err_inj_en_data_rate_rw        <= #TP 6'b0      ; 
      cfg_inj_err_spacing                     <= #TP 8'b0      ; 
end       
   else  begin                                      
      cfg_flit_err_inj_en                     <= #TP (flit_err_inj_reg_id[2] & flit_write_pulse[0] ) ? lbc_cdm_data[0]       : cfg_flit_err_inj_en; 
      cfg_inj_err_tx_flit_ind                 <= #TP (flit_err_inj_reg_id[2] & flit_write_pulse[0] ) ? lbc_cdm_data[1]       : cfg_inj_err_tx_flit_ind;  
      cfg_inj_err_rx_flit_ind                 <= #TP (flit_err_inj_reg_id[2] & flit_write_pulse[0] ) ? lbc_cdm_data[2]       : cfg_inj_err_rx_flit_ind;  
      cfg_flit_err_inj_en_data_rate_rw [4:0]  <= #TP (flit_err_inj_reg_id[2] & flit_write_pulse[0] ) ? lbc_cdm_data[7:3]     : cfg_flit_err_inj_en_data_rate_rw[4:0]; 
      cfg_flit_err_inj_en_data_rate_rw [5]    <= #TP (flit_err_inj_reg_id[2] & flit_write_pulse[1] ) ? lbc_cdm_data[8]       : cfg_flit_err_inj_en_data_rate_rw[5];    
      cfg_inj_err_spacing[2:0]                <= #TP (flit_err_inj_reg_id[2] & flit_write_pulse[2] ) ? lbc_cdm_data[23:21]   : cfg_inj_err_spacing[2:0];
      cfg_inj_err_spacing[7:3]                <= #TP (flit_err_inj_reg_id[2] & flit_write_pulse[3] ) ? lbc_cdm_data[28:24]   : cfg_inj_err_spacing[7:3];       
   end  
end  
 
always @(posedge core_clk or negedge sticky_rst_n) begin : flit_err_inj_cntrl_1_reg_sticky_PROC 
   if (!sticky_rst_n) begin 
      cfg_inj_err_num                         <= #TP 5'b0      ; 
      cfg_flit_type_inj                       <= #TP 3'b0      ; 
end                                           
   else  begin                                            
      cfg_inj_err_num                         <= #TP (flit_err_inj_reg_id[2] & flit_write_pulse[2] ) ? lbc_cdm_data[20:16]   : cfg_inj_err_num   ; 
      cfg_flit_type_inj                       <= #TP (flit_err_inj_reg_id[2] & flit_write_pulse[3] ) ? lbc_cdm_data[31:29]   : cfg_flit_type_inj ;       
   end  
end 

assign cfg_flit_err_inj_en_data_rate = {7'b0, cfg_flit_err_inj_en_data_rate_rw};

assign {flit_err_inj_reg_11, flit_err_inj_reg_10, flit_err_inj_reg_09, flit_err_inj_reg_08} =  { cfg_flit_type_inj, 
                                                                                                 cfg_inj_err_spacing, 
                                                                                                 cfg_inj_err_num, 
                                                                                                 cfg_flit_err_inj_en_data_rate, 
                                                                                                 cfg_inj_err_rx_flit_ind, 
                                                                                                 cfg_inj_err_tx_flit_ind, 
                                                                                                 cfg_flit_err_inj_en }; 
                                                                                                  
// ----------------------------------------------------------------------------- 
// Flit Error Injection Control 2 Register 
// -----------------------------------------------------------------------------  
// flit_err_inj_reg_id   - 3 
// PCIE Offset           - `FLIT_ERROR_INJECTION_PTR + 0Ch 
// length                - 4 byte 
// Cfig register         - flit_err_inj_reg_15, flit_err_inj_reg_14, flit_err_inj_reg_13, flit_err_inj_reg_12  
// register              - Consecutive Error Injection  [2:0]              :  RW 
//                       - Error Type Being Injected [4:3]                 :  RW 
//                       - Error Offset within Flit  [11:5]                :  RW 
//                       - Error Magnitude [19:12]                         :  RW 
//                       - RsvdP [31:20] 
// ----------------------------------------------------------------------------- 
 
always @(posedge core_clk or negedge non_sticky_rst_n) begin : flit_err_inj_cntrl_2_reg_PROC 
   if (!non_sticky_rst_n) begin 
      cfg_consec_err_inj                    <= #TP 3'b0      ; 
      cfg_curr_inj_err_type                 <= #TP 2'b0      ; 
      cfg_flit_err_off                      <= #TP 7'b0      ; 
      cfg_err_mag                           <= #TP 8'b0      ; 
      end 
   else  begin 
      cfg_consec_err_inj                    <= #TP  (flit_err_inj_reg_id[3] & flit_write_pulse[0] ) ? lbc_cdm_data[2:0]     : cfg_consec_err_inj;  
      cfg_curr_inj_err_type                 <= #TP  (flit_err_inj_reg_id[3] & flit_write_pulse[0] ) ? lbc_cdm_data[4:3]     : cfg_curr_inj_err_type;   
      cfg_flit_err_off [2:0]                <= #TP  (flit_err_inj_reg_id[3] & flit_write_pulse[0] ) ? lbc_cdm_data[7:5]     : cfg_flit_err_off[2:0]; 
      cfg_flit_err_off [6:3]                <= #TP  (flit_err_inj_reg_id[3] & flit_write_pulse[1] ) ? lbc_cdm_data[11:8]    : cfg_flit_err_off[6:3]; 
      cfg_err_mag[3:0]                      <= #TP  (flit_err_inj_reg_id[3] & flit_write_pulse[1] ) ? lbc_cdm_data[15:12]   : cfg_err_mag[3:0]; 
      cfg_err_mag[7:4]                      <= #TP  (flit_err_inj_reg_id[3] & flit_write_pulse[2] ) ? lbc_cdm_data[19:16]   : cfg_err_mag[7:4];       
   end 
end 
assign {flit_err_inj_reg_15, flit_err_inj_reg_14, flit_err_inj_reg_13, flit_err_inj_reg_12} =  { {12{1'b0}},  
                                                                                                cfg_err_mag, 
                                                                                                cfg_flit_err_off, 
                                                                                                cfg_curr_inj_err_type, 
                                                                                                cfg_consec_err_inj }; 
  
// ----------------------------------------------------------------------------- 
// Flit Error Injection Status Register 
// -----------------------------------------------------------------------------  
// flit_err_inj_reg_id   - 4 
// PCIE Offset           - `FLIT_ERROR_INJECTION_PTR + 10h 
// length                - 4 byte 
// Cfig register         - flit_err_inj_reg_19, flit_err_inj_reg_18, flit_err_inj_reg_17, flit_err_inj_reg_16  
// register              - Flit Error Tx Injection Status [1:0]       :  RO 
//                       - Flit Error Rx Injection Status [3:2]       :  RO 
//                       - RsvdP [31:4]                                
// ----------------------------------------------------------------------------  
 
assign {flit_err_inj_reg_19, flit_err_inj_reg_18, flit_err_inj_reg_17, flit_err_inj_reg_16} =  { {28{1'b0}}, 
                                                                                                 cfg_flit_err_rx_inj_sts, 
                                                                                                 cfg_flit_err_tx_inj_sts }; 
                                                                                                   
// ----------------------------------------------------------------------------- 
// Ordered Set Error Injection Control 1 Register 
// -----------------------------------------------------------------------------  
// flit_err_inj_reg_id   - 5 
// PCIE Offset           - `FLIT_ERROR_INJECTION_PTR + 14h 
// length                - 4 byte 
// Cfig register         - flit_err_inj_reg_23, flit_err_inj_reg_22, flit_err_inj_reg_21, flit_err_inj_reg_20    
// register              - Ordered Set Error Injection Enable [0]             : RWS 
//                       - Inject Errors on Transmitted Ordered Sets [1]      : RWS  
//                       - Inject Errors on Received Ordered Sets [2]         : Hardwired to 0 
//                       - Number of Errors injected [7:3]                    : RWS 
//                       - Spacing Between Injected Errors [15:8]             : RWS 
//                       - Inject Error on TS0 OS                             : RWS 
//                       - Inject Error on TS1 OS                             : RWS 
//                       - Inject Error on TS2 OS                             : RWS 
//                       - Inject Error on SKP OS                             : RWS 
//                       - Inject Error on EIEOS OS                           : RWS 
//                       - Inject Error on EIOS OS                            : RWS 
//                       - Inject Error on SDS OS                             : RWS 
//                       - Inject Error in Polling State                      : RWS 
//                       - Inject Error in Configuration                      : RWS 
//                       - Inject Error in L0 state                           : RWS 
//                       - Inject Error in non-EQ Recovery state              : RWS 
//                       - Inject Error in Recovery.Equalization Phase 0 and 1: RWS 
//                       - Inject Error in Recovery.Equalization Phase 2      : RWS 
//                       - Inject Error in Recovery.Equalization Phase 3      : RWS 
//                       - RsvdP [31:30]                                
// ----------------------------------------------------------------------------  

assign cfg_inj_err_rx_ordr_set_ind = 1'b0;
                                                                                             
always @(posedge core_clk or negedge sticky_rst_n) begin : ord_set_err_inj_cntrl_1_reg_PROC 
   if (!sticky_rst_n) begin 
           cfg_ordr_set_err_inj_en                     <= #TP 1'b0      ; 
           cfg_inj_err_tx_ordr_set_ind                 <= #TP 1'b0      ; 
           cfg_ordr_set_inj_err_num                    <= #TP 5'b0      ; 
           cfg_ordr_set_inj_err_spacing                <= #TP 8'b0      ;  
           cfg_inj_err_ts0_os                          <= #TP 1'b0      ; 
           cfg_inj_err_ts1_os                          <= #TP 1'b0      ; 
           cfg_inj_err_ts2_os                          <= #TP 1'b0      ; 
           cfg_inj_err_skp_os                          <= #TP 1'b0      ; 
           cfg_inj_err_eieos_os                        <= #TP 1'b0      ; 
           cfg_inj_err_eios_os                         <= #TP 1'b0      ; 
           cfg_inj_err_sds_os                          <= #TP 1'b0      ; 
           cfg_inj_err_poll_st                         <= #TP 1'b0      ; 
           cfg_inj_err_cfg_st                          <= #TP 1'b0      ; 
           cfg_inj_err_l0_st                           <= #TP 1'b0      ; 
           cfg_inj_err_non_eq_recov_st                 <= #TP 1'b0      ; 
           cfg_inj_err_recov_eq_ph_1_0                 <= #TP 1'b0      ; 
           cfg_inj_err_recov_eq_ph_2                   <= #TP 1'b0      ; 
           cfg_inj_err_recov_eq_ph_3                   <= #TP 1'b0      ; 
end 
  else begin    
           cfg_ordr_set_err_inj_en                     <= #TP  (flit_err_inj_reg_id[5] & flit_write_pulse[0] ) ? lbc_cdm_data[0]     : cfg_ordr_set_err_inj_en; 
           cfg_inj_err_tx_ordr_set_ind                 <= #TP  (flit_err_inj_reg_id[5] & flit_write_pulse[0] ) ? lbc_cdm_data[1]: cfg_inj_err_tx_ordr_set_ind ; 
           cfg_ordr_set_inj_err_num                    <= #TP  (flit_err_inj_reg_id[5] & flit_write_pulse[0] ) ? lbc_cdm_data[7:3]    : cfg_ordr_set_inj_err_num;  
           cfg_ordr_set_inj_err_spacing                <= #TP  (flit_err_inj_reg_id[5] & flit_write_pulse[1] ) ? lbc_cdm_data[15:8]   : cfg_ordr_set_inj_err_spacing; 
           cfg_inj_err_ts0_os                          <= #TP  (flit_err_inj_reg_id[5] & flit_write_pulse[2] ) ? lbc_cdm_data[16]     : cfg_inj_err_ts0_os         ; 
           cfg_inj_err_ts1_os                          <= #TP  (flit_err_inj_reg_id[5] & flit_write_pulse[2] ) ? lbc_cdm_data[17]     : cfg_inj_err_ts1_os         ; 
           cfg_inj_err_ts2_os                          <= #TP  (flit_err_inj_reg_id[5] & flit_write_pulse[2] ) ? lbc_cdm_data[18]     : cfg_inj_err_ts2_os         ; 
           cfg_inj_err_skp_os                          <= #TP  (flit_err_inj_reg_id[5] & flit_write_pulse[2] ) ? lbc_cdm_data[19]     : cfg_inj_err_skp_os         ; 
           cfg_inj_err_eieos_os                        <= #TP  (flit_err_inj_reg_id[5] & flit_write_pulse[2] ) ? lbc_cdm_data[20]     : cfg_inj_err_eieos_os       ; 
           cfg_inj_err_eios_os                         <= #TP  (flit_err_inj_reg_id[5] & flit_write_pulse[2] ) ? lbc_cdm_data[21]     : cfg_inj_err_eios_os        ; 
           cfg_inj_err_sds_os                          <= #TP  (flit_err_inj_reg_id[5] & flit_write_pulse[2] ) ? lbc_cdm_data[22]     : cfg_inj_err_sds_os         ; 
           cfg_inj_err_poll_st                         <= #TP  (flit_err_inj_reg_id[5] & flit_write_pulse[2] ) ? lbc_cdm_data[23]     : cfg_inj_err_poll_st        ; 
           cfg_inj_err_cfg_st                          <= #TP  (flit_err_inj_reg_id[5] & flit_write_pulse[3] ) ? lbc_cdm_data[24]     : cfg_inj_err_cfg_st         ; 
           cfg_inj_err_l0_st                           <= #TP  (flit_err_inj_reg_id[5] & flit_write_pulse[3] ) ? lbc_cdm_data[25]     : cfg_inj_err_l0_st          ; 
           cfg_inj_err_non_eq_recov_st                 <= #TP  (flit_err_inj_reg_id[5] & flit_write_pulse[3] ) ? lbc_cdm_data[26]     : cfg_inj_err_non_eq_recov_st; 
           cfg_inj_err_recov_eq_ph_1_0                 <= #TP  (flit_err_inj_reg_id[5] & flit_write_pulse[3] ) ? lbc_cdm_data[27]     : cfg_inj_err_recov_eq_ph_1_0; 
           cfg_inj_err_recov_eq_ph_2                   <= #TP  (flit_err_inj_reg_id[5] & flit_write_pulse[3] ) ? lbc_cdm_data[28]     : cfg_inj_err_recov_eq_ph_2  ; 
           cfg_inj_err_recov_eq_ph_3                   <= #TP  (flit_err_inj_reg_id[5] & flit_write_pulse[3] ) ? lbc_cdm_data[29]     : cfg_inj_err_recov_eq_ph_3  ; 
   end            
end    
assign {flit_err_inj_reg_23, flit_err_inj_reg_22, flit_err_inj_reg_21, flit_err_inj_reg_20} =  { {2{1'b0}}, 
                                                                                                cfg_inj_err_recov_eq_ph_3, 
                                                                                                cfg_inj_err_recov_eq_ph_2, 
                                                                                                cfg_inj_err_recov_eq_ph_1_0, 
                                                                                                cfg_inj_err_non_eq_recov_st, 
                                                                                                cfg_inj_err_l0_st, 
                                                                                                cfg_inj_err_cfg_st, 
                                                                                                cfg_inj_err_poll_st, 
                                                                                                cfg_inj_err_sds_os,
                                                                                                cfg_inj_err_eios_os,
                                                                                                cfg_inj_err_eieos_os, 
                                                                                                cfg_inj_err_skp_os, 
                                                                                                cfg_inj_err_ts2_os, 
                                                                                                cfg_inj_err_ts1_os, 
                                                                                                cfg_inj_err_ts0_os, 
                                                                                                cfg_ordr_set_inj_err_spacing, 
                                                                                                cfg_ordr_set_inj_err_num, 
                                                                                                cfg_inj_err_rx_ordr_set_ind, 
                                                                                                cfg_inj_err_tx_ordr_set_ind, 
                                                                                                cfg_ordr_set_err_inj_en}; 
                                                                                                    
                                                                                              
// ----------------------------------------------------------------------------- 
// Ordered Set Error Injection Control 2 Register 
// -----------------------------------------------------------------------------  
// flit_err_inj_reg_id   - 6 
// PCIE Offset           - `FLIT_ERROR_INJECTION_PTR + 18h 
// length                - 4 byte 
// Cfig register         - flit_err_inj_reg_27, flit_err_inj_reg_26, flit_err_inj_reg_25, flit_err_inj_reg_24    
// register              - cfg_err_inj_bytes [15:0]                    : RWS 
//                       - Lane Number for Error Injection [31:16]     : RWS 
// ----------------------------------------------------------------------------- 
  
always @(posedge core_clk or negedge sticky_rst_n) begin : ord_set_err_inj_cntrl_2_reg_PROC 
   if (!sticky_rst_n) begin 
   cfg_err_inj_bytes         <= #TP 16'b0      ; 
   cfg_err_inj_lane_num      <= #TP 16'b0      ; 
   end else begin 
   cfg_err_inj_bytes[7:0]          <= #TP  (flit_err_inj_reg_id[6] & flit_write_pulse[0] ) ? lbc_cdm_data[7:0]     : cfg_err_inj_bytes[7:0];  
   cfg_err_inj_bytes[15:8]         <= #TP  (flit_err_inj_reg_id[6] & flit_write_pulse[1] ) ? lbc_cdm_data[15:8]     : cfg_err_inj_bytes[15:8]; 
   cfg_err_inj_lane_num[7:0]       <= #TP  (flit_err_inj_reg_id[6] & flit_write_pulse[2] ) ? lbc_cdm_data[23:16]    : cfg_err_inj_lane_num[7:0];      
   cfg_err_inj_lane_num[15:8]      <= #TP  (flit_err_inj_reg_id[6] & flit_write_pulse[3] ) ? lbc_cdm_data[31:24]    : cfg_err_inj_lane_num[15:8];     
 end 
end 
assign {flit_err_inj_reg_27, flit_err_inj_reg_26, flit_err_inj_reg_25, flit_err_inj_reg_24} =  { cfg_err_inj_lane_num, cfg_err_inj_bytes }; 
 
 
// ----------------------------------------------------------------------------- 
// Ordered Set Error Tx Injection Status Register 
// -----------------------------------------------------------------------------  
// flit_err_inj_reg_id   - 7 
// PCIE Offset           - `FLIT_ERROR_INJECTION_PTR + 1Ch 
// length                - 4 byte 
// Cfig register         - flit_err_inj_reg_31, flit_err_inj_reg_30, flit_err_inj_reg_29, flit_err_inj_reg_28    
// register              - Tx Injection Status TS0                                  [1:0]     : ROS 
//                       - Tx Injection Status TS1                                  [3:2]     : ROS 
//                       - Tx Injection Status TS2                                  [5:4]     : ROS 
//                       - Tx Injection Status SKP                                  [7:6]     : ROS 
//                       - Tx Injection Status EIEOS                                [9:8]     : ROS 
//                       - Tx Injection Status EIOS                                 [11:10]   : ROS 
//                       - Tx Injection Status SDS                                  [13:12]   : ROS 
//                       - Tx Injection Status Polling                              [15:14]   : ROS 
//                       - Tx Injection Status Configuration                        [17:16]   : ROS 
//                       - Tx Injection Status L0                                   [19:18]   : ROS 
//                       - Tx Injection Status non-EQ Recovery                      [21:19]   : ROS 
//                       - Tx Injection Status Recovery.Equalization Phase 0 and 1  [23:22]   : ROS 
//                       - Tx Injection Status Recovery.Equalization Phase 2        [25:24]   : ROS 
//                       - Tx Injection Status Recovery.Equalization Phase 3        [27:26]   : ROS 
//                       - RsvdP [31:28] 
// ----------------------------------------------------------------------------- 
 
assign {flit_err_inj_reg_31, flit_err_inj_reg_30, flit_err_inj_reg_29, flit_err_inj_reg_28 } =  { {4{1'b0}},  
                                                                                                   cfg_ordr_set_tx_inj_sts_recov_eq_ph_3, 
                                                                                                   cfg_ordr_set_tx_inj_sts_recov_eq_ph_2, 
                                                                                                   cfg_ordr_set_tx_inj_sts_recov_eq_ph_1_0, 
                                                                                                   cfg_ordr_set_tx_inj_sts_non_eq_recov, 
                                                                                                   cfg_ordr_set_tx_inj_sts_l0, 
                                                                                                   cfg_ordr_set_tx_inj_sts_cfg, 
                                                                                                   cfg_ordr_set_tx_inj_sts_poll, 
                                                                                                   cfg_ordr_set_tx_inj_sts_sds, 
                                                                                                   cfg_ordr_set_tx_inj_sts_eios, 
                                                                                                   cfg_ordr_set_tx_inj_sts_eieos, 
                                                                                                   cfg_ordr_set_tx_inj_sts_skp, 
                                                                                                   cfg_ordr_set_tx_inj_sts_ts2, 
                                                                                                   cfg_ordr_set_tx_inj_sts_ts1, 
                                                                                                   cfg_ordr_set_tx_inj_sts_ts0}; 
 
                                                                                                    
// ----------------------------------------------------------------------------- 
// Ordered Set Error Rx Injection Status Register 
// -----------------------------------------------------------------------------  
// flit_err_inj_reg_id   - 8 
// PCIE Offset           - `FLIT_ERROR_INJECTION_PTR + 20h 
// length                - 4 byte 
// Cfig register         - flit_err_inj_reg_35, flit_err_inj_reg_34, flit_err_inj_reg_22, flit_err_inj_reg_32    
// register              - Rx Injection Status TS0                                  [1:0]     : ROS 
//                       - Rx Injection Status TS1                                  [3:2]     : ROS 
//                       - Rx Injection Status TS2                                  [5:4]     : ROS 
//                       - Rx Injection Status SKP                                  [7:6]     : ROS 
//                       - Rx Injection Status EIEOS                                [9:8]     : ROS 
//                       - Rx Injection Status EIOS                                 [11:10]   : ROS 
//                       - Rx Injection Status SDS                                  [13:12]   : ROS 
//                       - Rx Injection Status Polling                              [15:14]   : ROS 
//                       - Rx Injection Status Configuration                        [17:16]   : ROS 
//                       - Rx Injection Status L0                                   [19:18]   : ROS 
//                       - Rx Injection Status non-EQ Recovery                      [21:19]   : ROS 
//                       - Rx Injection Status Recovery.Equalization Phase 0 and 1  [23:22]   : ROS 
//                       - Rx Injection Status Recovery.Equalization Phase 2        [25:24]   : ROS 
//                       - Rx Injection Status Recovery.Equalization Phase 3        [27:26]   : ROS 
//                       - RsvdP [31:28] 
// ----------------------------------------------------------------------------- 
 
assign {flit_err_inj_reg_35, flit_err_inj_reg_34, flit_err_inj_reg_33, flit_err_inj_reg_32} =  {
                                                                                                   {4{1'b0}},
                                                                                                   cfg_ordr_set_rx_inj_sts_recov_eq_ph_3, 
                                                                                                   cfg_ordr_set_rx_inj_sts_recov_eq_ph_2, 
                                                                                                   cfg_ordr_set_rx_inj_sts_recov_eq_ph_1_0, 
                                                                                                   cfg_ordr_set_rx_inj_sts_non_eq_recov, 
                                                                                                   cfg_ordr_set_rx_inj_sts_l0, 
                                                                                                   cfg_ordr_set_rx_inj_sts_cfg, 
                                                                                                   cfg_ordr_set_rx_inj_sts_poll, 
                                                                                                   cfg_ordr_set_rx_inj_sts_sds, 
                                                                                                   cfg_ordr_set_rx_inj_sts_eios, 
                                                                                                   cfg_ordr_set_rx_inj_sts_eieos, 
                                                                                                   cfg_ordr_set_rx_inj_sts_skp, 
                                                                                                   cfg_ordr_set_rx_inj_sts_ts2, 
                                                                                                   cfg_ordr_set_rx_inj_sts_ts1, 
                                                                                                   cfg_ordr_set_rx_inj_sts_ts0};                                                                                                     
                                                                                                     
 // ----------------------------------------------------------------------------- 
// Register Read Operation 
// ----------------------------------------------------------------------------- 
 
always @(*) 
begin : read_data_PROC 
    unique case (1'b1) 
    flit_err_inj_reg_id[0]   : flit_err_inj_reg_data = {flit_err_inj_reg_03, flit_err_inj_reg_02, flit_err_inj_reg_01, flit_err_inj_reg_00};   // 0x00 
    flit_err_inj_reg_id[1]   : flit_err_inj_reg_data = {flit_err_inj_reg_07, flit_err_inj_reg_06, flit_err_inj_reg_05, flit_err_inj_reg_04};   // 0x04 
    flit_err_inj_reg_id[2]   : flit_err_inj_reg_data = {flit_err_inj_reg_11, flit_err_inj_reg_10, flit_err_inj_reg_09, flit_err_inj_reg_08};   // 0x08 
    flit_err_inj_reg_id[3]   : flit_err_inj_reg_data = {flit_err_inj_reg_15, flit_err_inj_reg_14, flit_err_inj_reg_13, flit_err_inj_reg_12};   // 0x0C 
    flit_err_inj_reg_id[4]   : flit_err_inj_reg_data = {flit_err_inj_reg_19, flit_err_inj_reg_18, flit_err_inj_reg_17, flit_err_inj_reg_16};   // 0x10 
    flit_err_inj_reg_id[5]   : flit_err_inj_reg_data = {flit_err_inj_reg_23, flit_err_inj_reg_22, flit_err_inj_reg_21, flit_err_inj_reg_20};   // 0x14 
    flit_err_inj_reg_id[6]   : flit_err_inj_reg_data = {flit_err_inj_reg_27, flit_err_inj_reg_26, flit_err_inj_reg_25, flit_err_inj_reg_24};   // 0x18     
    flit_err_inj_reg_id[7]   : flit_err_inj_reg_data = {flit_err_inj_reg_31, flit_err_inj_reg_30, flit_err_inj_reg_29, flit_err_inj_reg_28};   // 0x1C     
    flit_err_inj_reg_id[8]   : flit_err_inj_reg_data = {flit_err_inj_reg_35, flit_err_inj_reg_34, flit_err_inj_reg_33, flit_err_inj_reg_32};   // 0x20     
    
    default          : flit_err_inj_reg_data = `PCIE_UNUSED_RESPONSE; 
    endcase 
end 
 
 
endmodule  
  
