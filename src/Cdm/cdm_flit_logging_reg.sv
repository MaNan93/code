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
// ---    $DateTime: 2023/06/26 08:32:07 $
// ---    $Revision: #4 $
// ---    $Id: //dwh/pcie_iip/main/fairbanks/design/Cdm/cdm_flit_logging_reg.sv#4 $
// -------------------------------------------------------------------------

// -----------------------------------------------------------------------------
// --- Module Description:
// -----------------------------------------------------------------------------
// --- This module contains Flit Logging Extended Capability.
// --- The Flit Logging Extended Capability is instantiated for Ports and RCRBs that support Flit Mode.
// --- If the port is upstream, the Flit Logging Extended Capability is instantiated for physical function 0 only.
// -----------------------------------------------------------------------------

`include "include/DWC_pcie_ctl_all_defs.svh"

 module cdm_flit_logging_reg
#(
    parameter INST                 = 0,                            // The uniquifying parameter for each port logic instance.
    parameter FUNC_NUM             = 0,                            // uniquifying parameter per function 
    parameter NR_REGS_FLIT_LOGGING = `FLIT_LOGGING_SIZE >> 2,      // Number of registers per capability
    parameter RCRB                 = 0,                            // if RCRB == 1, u_rcrb_cdm_ecfg_reg/u_cdm_flit_logging_reg instance
                                                                   // if RCRB == 0, u_cdm_ecfg_reg/u_cdm_flit_logging_reg instance
    parameter TP                   = `TP                           // RTL Design Clock to Q output delay (simulator safety)
)

                            (
    // -------------- Inputs ----------------
    input                            core_clk,                    // Core Clock
    input                            non_sticky_rst_n,            // Non-Sticky Reset
    input                            sticky_rst_n,                // Sticky Reset  
    input                            cdm_clk_g,                   // gated version of the aux_clk_g, based on access activity to cdm, enable signal comes from lbc
    input [31:0]                     lbc_cdm_data,                // Write Data
    input                            lbc_cdm_dbi,                 // DBI Access
    input                            dbi_ro_wr_en,                // DBI Write Enable of ReadOnly registers
    input [3:0]                      flit_write_pulse,            // Write Byte Enable
    input [NR_REGS_FLIT_LOGGING-1:0] flit_logging_reg_id,         // Flit Logging Extended Capability Register ID
    input [3:0]                      device_type,  
    input                            cxl_rcrb_enable,
    input [63:0]                     flit_log, //LSB is the valid bit. Flit Error Log 1 Register & Flit Error Log 2 Register 
    input [2:0]                      link_wd_err_cnt_start,         // Flit Error Counter Status  Register
    input [7:0]                      flit_err_cnt,                  // Flit Error Counter Status  Register
    input [31:0]                     flit_cnt,                      // FBER Measurement Status 1  Register
    input [15:0]                     invalid_flit_cnt,              // FBER Measurement Status 2  Register
    input                            interr_trg_evnt_cnt,           // Pulse signal to set Flit Error Counter Status  Register
    input                            interr_trg_evnt_cnt_clr,       // Pulse signal to clear Flit Error Counter Status  Register
    input [15:0]                     lane_0_corr_cnt,               // FBER Measurement Status 3  Register               
    input [15:0]                     lane_1_corr_cnt,               // FBER Measurement Status 3  Register
    input [15:0]                     lane_2_corr_cnt,               // FBER Measurement Status 4  Register    
    input [15:0]                     lane_3_corr_cnt,               // FBER Measurement Status 4  Register    
    input [15:0]                     lane_4_corr_cnt,               // FBER Measurement Status 5  Register    
    input [15:0]                     lane_5_corr_cnt,               // FBER Measurement Status 5  Register   
    input [15:0]                     lane_6_corr_cnt,               // FBER Measurement Status 6  Register    
    input [15:0]                     lane_7_corr_cnt,               // FBER Measurement Status 6  Register    
    input [15:0]                     lane_8_corr_cnt,               // FBER Measurement Status 7  Register    
    input [15:0]                     lane_9_corr_cnt,               // FBER Measurement Status 7  Register    
    input [15:0]                     lane_10_corr_cnt,              // FBER Measurement Status 8  Register    
    input [15:0]                     lane_11_corr_cnt,              // FBER Measurement Status 8  Register    
    input [15:0]                     lane_12_corr_cnt,              // FBER Measurement Status 9  Register    
    input [15:0]                     lane_13_corr_cnt,              // FBER Measurement Status 9  Register    
    input [15:0]                     lane_14_corr_cnt,              // FBER Measurement Status 10 Register    
    input [15:0]                     lane_15_corr_cnt,              // FBER Measurement Status 10 Register       
    
    // -------------- Outputs --------------
    output reg [31:0]                flit_logging_reg_data         ,   // Flit Logging Register Read Data                                                                 
    output reg [7:0]                 trg_evnt_cnt                  ,   // Flit Error Counter Control Register               
    output reg [1:0]                 evnt_to_cnt                   ,   // Flit Error Counter Control Register               
    output reg                       flit_err_cnt_en               ,   // Flit Error Counter Control Register 
    output reg                       interr_trg_evnt_cnt_ind       ,   // Flit Error Counter Status Register
    output reg                       fber_measurement_en           ,   // FBER Measurement Control Register
    output reg                       clr_fber_cnt                  ,   // FBER Measurement Control Register
    output reg  [1:0]                gran_per_lane_err_rpt         ,   // FBER Measurement Control Register
    output reg                       rpt_longest_burst_vs_1st_burst,   // FBER Measurement Control Register 
    output reg                       flit_log_trg_evnt_msi,            // Flit Error Counter MSI 
    output wire                      pop_fifo_en         
    
);

// -------------- Internal Signals --------------
wire    [7:0]        flit_logging_reg_03, flit_logging_reg_02, flit_logging_reg_01, flit_logging_reg_00;
wire    [7:0]        flit_logging_reg_07, flit_logging_reg_06, flit_logging_reg_05, flit_logging_reg_04;
wire    [7:0]        flit_logging_reg_11, flit_logging_reg_10, flit_logging_reg_09, flit_logging_reg_08;
wire    [7:0]        flit_logging_reg_15, flit_logging_reg_14, flit_logging_reg_13, flit_logging_reg_12;
wire    [7:0]        flit_logging_reg_19, flit_logging_reg_18, flit_logging_reg_17, flit_logging_reg_16;
wire    [7:0]        flit_logging_reg_23, flit_logging_reg_22, flit_logging_reg_21, flit_logging_reg_20;
wire    [7:0]        flit_logging_reg_27, flit_logging_reg_26, flit_logging_reg_25, flit_logging_reg_24;
wire    [7:0]        flit_logging_reg_31, flit_logging_reg_30, flit_logging_reg_29, flit_logging_reg_28;
wire    [7:0]        flit_logging_reg_35, flit_logging_reg_34, flit_logging_reg_33, flit_logging_reg_32;
wire    [7:0]        flit_logging_reg_39, flit_logging_reg_38, flit_logging_reg_37, flit_logging_reg_36;
wire    [7:0]        flit_logging_reg_43, flit_logging_reg_42, flit_logging_reg_41, flit_logging_reg_40;
wire    [7:0]        flit_logging_reg_47, flit_logging_reg_46, flit_logging_reg_45, flit_logging_reg_44;
wire    [7:0]        flit_logging_reg_51, flit_logging_reg_50, flit_logging_reg_49, flit_logging_reg_48;
wire    [7:0]        flit_logging_reg_55, flit_logging_reg_54, flit_logging_reg_53, flit_logging_reg_52;
wire    [7:0]        flit_logging_reg_59, flit_logging_reg_58, flit_logging_reg_57, flit_logging_reg_56;
wire                 int_lbc_cdm_dbi;
wire                 pcie_sw_down;
wire                 rc_device;

assign pcie_sw_down    = (device_type == `PCIE_SW_DOWN);
assign rc_device       = (device_type == `PCIE_RC);
assign int_lbc_cdm_dbi = lbc_cdm_dbi & dbi_ro_wr_en;

// =============================================================================
// Flit Logging Extended Capability
// =============================================================================

// -----------------------------------------------------------------------------
// Flit Logging Extended Capability Header Register
// -----------------------------------------------------------------------------
// flit_logging_reg_id - 0
// PCIE Offset      - `FLIT_LOGGING_PTR + 00h
// length           - 4 byte
// Cfig register    - flit_logging_reg_03, flit_logging_reg_02, flit_logging_reg_01, flit_logging_reg_00
// register         - Flit Logging Extended Capability ID [15:0] : RO
//                  - Capability Version [19:16]                 : RO
//                  - Next Capability Offset [31:20]             : RO
// -----------------------------------------------------------------------------
reg    [15:0]                      flit_logging_cap_id ;                     // Flit Logging Extended Capability ID [15:0]
reg    [3:0]                       flit_logging_cap_ver ;                    // Capability Version [19:16]
reg    [11:0]                      flit_logging_next_ptr ;                   // Next Capability Offset [31:20]
reg                                flit_logging_next_ptr_updated;            // Asserted when Flit Logging Extended Capability header has been changed by a DBI write

always @(posedge cdm_clk_g or negedge sticky_rst_n) begin : flit_logging_cap_id_ver_PROC
   if (!sticky_rst_n) begin
      flit_logging_cap_id     <= #TP `PCIE_FLIT_LOGGING_ECAP_ID ;
      flit_logging_cap_ver    <= #TP `PCIE_FLIT_LOGGING_ECAP_VER ;
   end
   // Read-Only registers, but writable through DBI
   else begin
        flit_logging_cap_id[7:0]   <= #TP (flit_logging_reg_id[0] & flit_write_pulse[0] & int_lbc_cdm_dbi ) ? lbc_cdm_data[7:0]   : flit_logging_cap_id[7:0] ;
        flit_logging_cap_id[15:8]  <= #TP (flit_logging_reg_id[0] & flit_write_pulse[1] & int_lbc_cdm_dbi ) ? lbc_cdm_data[15:8]  : flit_logging_cap_id[15:8] ;
        flit_logging_cap_ver       <= #TP (flit_logging_reg_id[0] & flit_write_pulse[2] & int_lbc_cdm_dbi ) ? lbc_cdm_data[19:16] : flit_logging_cap_ver ;
   end
end


// Remember if the user updates the next pointer
always @( posedge core_clk or negedge sticky_rst_n ) begin : flit_logging_next_ptr_updated_PROC
   if ( !sticky_rst_n ) begin
      flit_logging_next_ptr_updated <= #TP 1'b0;
   end else if (flit_logging_reg_id[0] && int_lbc_cdm_dbi && |flit_write_pulse[3:2]) begin
      flit_logging_next_ptr_updated <= #TP 1'b1;
   end
end


// Next Pointer logic
always @( posedge core_clk or negedge sticky_rst_n ) begin : flit_logging_next_ptr_PROC
   if ( !sticky_rst_n ) begin
      flit_logging_next_ptr[11:0] <= #TP `FLIT_LOGGING_NEXT_PTR;
   end else if(flit_logging_reg_id[0] && int_lbc_cdm_dbi) begin
      flit_logging_next_ptr[3:0]  <= #TP (flit_write_pulse[2]) ? lbc_cdm_data[23:20] : flit_logging_next_ptr[3:0];
      flit_logging_next_ptr[11:4] <= #TP (flit_write_pulse[3]) ? lbc_cdm_data[31:24] : flit_logging_next_ptr[11:4];
    end else if ((rc_device || pcie_sw_down) && !flit_logging_next_ptr_updated) begin
      flit_logging_next_ptr[11:0] <= #TP `DM_RP_FLIT_LOGGING_NEXT_PTR ;
   end else if (!flit_logging_next_ptr_updated) begin
      flit_logging_next_ptr[11:0] <= #TP (cxl_rcrb_enable && |RCRB   ) ?   `RCRB_FLIT_LOGGING_NEXT_PTR  :
                                                                                         `FLIT_LOGGING_NEXT_PTR       ;
   end
end
                                                                      
assign {flit_logging_reg_03, flit_logging_reg_02, flit_logging_reg_01, flit_logging_reg_00} = { flit_logging_next_ptr,
                                                                                                flit_logging_cap_ver,
                                                                                                flit_logging_cap_id
                                                                                              };

// -----------------------------------------------------------------------------
//  Flit Error Log 1 Register
// -----------------------------------------------------------------------------
// flit_logging_reg_id      - 1
// PCIE Offset      - `FLIT_PTR + 04h
// length           - 4 byte
// Cfig register    - flit_logging_reg_07, flit_logging_reg_06, flit_logging_reg_05, flit_logging_reg_04
// register         - Flit Error Log Valid [0]                                : RW1CS
//                  - Flit Error Link Width [3:1]                             : ROS
//                  - Flit Offset from the Last Logged Flit in Error [7:4]    : ROS
//                  - Consecutive Flit Error after the Last Flit Error [12:8] : ROS
//                  - More Entries for Flit Error Log Register are Valid [13] : ROS
//                  - Unrecognized Flit [14]                                  : ROS
//                  - FEC Uncorrectable Error in Flit [15]                    : ROS
//                  - Syndrome Parity for ECC Group 0 [23:16]                 : ROS
//                  - Syndrome Check for ECC Group 0 [31:24]                  : ROS
// -----------------------------------------------------------------------------

reg       flit_err_log_valid;
reg [2:0] flit_err_link_wd;                     
reg [3:0] flit_off_lst_logged_flit_err;
reg [4:0] consec_flit_err_lst_flit_err;
reg       more_valid_flit_entries;
reg       unrecognized_flit;                  
reg       fec_uncorr_err_flit;             
reg [7:0] synd_par_ecc_grp_0;            
reg [7:0] synd_chk_ecc_grp_0;            


assign pop_fifo_en = flit_err_log_valid & flit_logging_reg_id[1] & flit_write_pulse[0] & lbc_cdm_data[0];

always @(posedge core_clk or negedge sticky_rst_n) begin : flit_err_log_valid_PROC
   if (!sticky_rst_n) begin
      flit_err_log_valid     <= #TP 1'b0 ;
   end
   else begin
     if(flit_err_log_valid) begin
       if(more_valid_flit_entries == 1'b0) begin
         flit_err_log_valid <= #TP ( flit_logging_reg_id[1] & flit_write_pulse[0] & lbc_cdm_data[0] ) ? 1'b0 : flit_err_log_valid ;
       end                                                                                                       
     end 
     else begin
       flit_err_log_valid <= #TP flit_log[0] ;
     end
   end
end

always @(posedge core_clk or negedge sticky_rst_n) begin : flit_err_log_1_PROC
    if (!sticky_rst_n) begin
      flit_err_link_wd              <= #TP {3{1'b0}} ;         
      flit_off_lst_logged_flit_err  <= #TP {4{1'b0}} ;
      consec_flit_err_lst_flit_err  <= #TP {5{1'b0}} ;
      more_valid_flit_entries       <= #TP    1'b0   ;
      unrecognized_flit             <= #TP    1'b0   ;
      fec_uncorr_err_flit           <= #TP    1'b0   ;
      synd_par_ecc_grp_0            <= #TP {8{1'b0}} ;
      synd_chk_ecc_grp_0            <= #TP {8{1'b0}} ;
    end
    else begin
        { synd_chk_ecc_grp_0          ,         
          synd_par_ecc_grp_0          ,
          fec_uncorr_err_flit         ,
          unrecognized_flit           ,
          more_valid_flit_entries     ,      
          consec_flit_err_lst_flit_err,        
          flit_off_lst_logged_flit_err,          
          flit_err_link_wd
        } <= #TP flit_log[31:1];         
    end
  end
  
assign {flit_logging_reg_07,flit_logging_reg_06,flit_logging_reg_05,flit_logging_reg_04} = { synd_chk_ecc_grp_0          ,
                                                                                             synd_par_ecc_grp_0          ,        
                                                                                             fec_uncorr_err_flit         ,
                                                                                             unrecognized_flit           ,        
                                                                                             more_valid_flit_entries     ,        
                                                                                             consec_flit_err_lst_flit_err,        
                                                                                             flit_off_lst_logged_flit_err,        
                                                                                             flit_err_link_wd            ,
                                                                                             flit_err_log_valid
                                                                                           };       

// -----------------------------------------------------------------------------
// Flit Error Log 2 Register
// -----------------------------------------------------------------------------
// flit_logging_reg_id     - 2
// PCIE Offset      - `FLIT_PTR + 08h
// length           - 4 byte
// Cfig register    - flit_logging_reg_11, flit_logging_reg_10, flit_logging_reg_09, flit_logging_reg_08
// register         - Syndrome Parity for ECC Group 1 [7:0]   : ROS
//                  - Syndrome Check for ECC Group 1  [15:8]  : ROS
//                  - Syndrome Parity for ECC Group 2 [23:16] : ROS
//                  - Syndrome Check for ECC Group 2  [31:24] : ROS

// -----------------------------------------------------------------------------

reg [7:0] synd_chk_ecc_grp_2;            
reg [7:0] synd_par_ecc_grp_2; 
reg [7:0] synd_chk_ecc_grp_1;            
reg [7:0] synd_par_ecc_grp_1; 

always @(posedge core_clk or negedge sticky_rst_n) begin : flit_err_log_2_PROC
    if (!sticky_rst_n) begin
      synd_chk_ecc_grp_2            <= #TP {8{1'b0}} ;
      synd_par_ecc_grp_2            <= #TP {8{1'b0}} ;
      synd_chk_ecc_grp_1            <= #TP {8{1'b0}} ;
      synd_par_ecc_grp_1            <= #TP {8{1'b0}} ;
    end
    else begin
        {synd_chk_ecc_grp_2,         
         synd_par_ecc_grp_2,
         synd_chk_ecc_grp_1,
         synd_par_ecc_grp_1     
        } <= #TP flit_log[63:32];        
    end
  end

assign {flit_logging_reg_11, flit_logging_reg_10, flit_logging_reg_09, flit_logging_reg_08} = {synd_chk_ecc_grp_2,
                                                                                               synd_par_ecc_grp_2,
                                                                                               synd_chk_ecc_grp_1,
                                                                                               synd_par_ecc_grp_1 
                                                                                              };
                                                              
// -----------------------------------------------------------------------------
// Flit Error Counter Control Register
// -----------------------------------------------------------------------------
// flit_logging_reg_id     - 3
// PCIE Offset      - `FLIT_PTR + 0Ch
// length           - 2 byte
// Cfig register    - flit_logging_reg_15, flit_logging_reg_14, flit_logging_reg_13, flit_logging_reg_12
// register         - Flit Error Counter Enable [0]       : RW
//                  - Flit Error Counter Interrupt Enable [1]        : RW                          
//                  - Events to count [3:2]               : RW
//                  - Trigger Event on Error Count [11:4] : RW
//                  - RsvdP [15:12]                       
// -----------------------------------------------------------------------------

// reg       flit_err_cnt_en;
// reg [1:0] evnt_to_cnt    ;
// reg [7:0] trg_evnt_cnt   ;
reg       flit_err_cnt_interr_en;

always @(posedge cdm_clk_g or negedge non_sticky_rst_n) begin : flit_err_cnt_ctrl_PROC
   if (!non_sticky_rst_n) begin
     flit_err_cnt_en <= #TP    1'b0   ;
     flit_err_cnt_interr_en <= #TP    1'b0   ;
     evnt_to_cnt     <= #TP {2{1'b0}} ;
     trg_evnt_cnt    <= #TP {8{1'b0}} ;
   end
   else begin
     flit_err_cnt_en   <= #TP (flit_logging_reg_id[3] & flit_write_pulse[0] ) ? lbc_cdm_data[0]    : flit_err_cnt_en    ;
     flit_err_cnt_interr_en   <= #TP (flit_logging_reg_id[3] & flit_write_pulse[0] ) ? lbc_cdm_data[1]    : flit_err_cnt_interr_en    ;
     evnt_to_cnt       <= #TP (flit_logging_reg_id[3] & flit_write_pulse[0] ) ? lbc_cdm_data[3:2]  : evnt_to_cnt        ;
     trg_evnt_cnt[3:0] <= #TP (flit_logging_reg_id[3] & flit_write_pulse[0] ) ? lbc_cdm_data[7:4]  : trg_evnt_cnt[3:0]  ;
     trg_evnt_cnt[7:4] <= #TP (flit_logging_reg_id[3] & flit_write_pulse[1] ) ? lbc_cdm_data[11:8] : trg_evnt_cnt[7:4]  ;
   end
end

assign {flit_logging_reg_13, flit_logging_reg_12} = { 4'b0           ,
                                                      trg_evnt_cnt   ,        
                                                      evnt_to_cnt    ,
                                                      flit_err_cnt_interr_en           ,
                                                      flit_err_cnt_en
                                                    };                                                            
                                    
// -----------------------------------------------------------------------------
// Flit Error Counter Status Register
// -----------------------------------------------------------------------------
// flit_logging_reg_id - 3
// PCIE Offset      - `FLIT_PTR + 0Ch
// length           - 2 byte
// Cfig register    - flit_logging_reg_15, flit_logging_reg_14 
// register         - Link Width when Error Counter Started [2:0]          : ROS
//                  - Interrupt Generated based on Trigger Event Count [3] : RW1CS
//                  - RsvdP [7:4] 
//                  - Flit Error Counter [15:8]                            : ??    //assume ROS                                     
// -----------------------------------------------------------------------------

// wire [2:0] link_wd_err_cnt_start  ;
// wire       interr_trg_evnt_cnt    ;
// reg        interr_trg_evnt_cnt_ind;
// wire [7:0] flit_err_cnt           ;

always @(posedge core_clk or negedge sticky_rst_n) begin : flit_log_trg_evnt_MSI
    if(!sticky_rst_n) begin 
      flit_log_trg_evnt_msi    <=  #TP 1'b0; 
    end else begin
      flit_log_trg_evnt_msi    <=  #TP flit_err_cnt_interr_en & interr_trg_evnt_cnt;
    end 
end

always @( posedge core_clk or negedge sticky_rst_n ) begin : interr_trg_evnt_cnt_ind_PROC
    if ( !sticky_rst_n ) begin
      interr_trg_evnt_cnt_ind   <= #TP 1'b0;
    end else begin
      if (interr_trg_evnt_cnt) begin
        interr_trg_evnt_cnt_ind <= #TP 1'b1;
      end 
      else begin
        if (interr_trg_evnt_cnt_clr | (flit_logging_reg_id[3] & flit_write_pulse[3] & lbc_cdm_data[19])) begin
          interr_trg_evnt_cnt_ind <= #TP 1'b0 ;
        end
      end
    end
end

assign {flit_logging_reg_15, flit_logging_reg_14} = { flit_err_cnt           ,
                                                      4'b0                   ,
                                                      interr_trg_evnt_cnt_ind, 
                                                      link_wd_err_cnt_start
                                                    }; 

// -----------------------------------------------------------------------------
// FBER Measurement Control Register
// -----------------------------------------------------------------------------
// flit_logging_reg_id     - 4
// PCIE Offset      - `FLIT_PTR + 10h
// length           - 4 byte
// Cfig register    - flit_logging_reg_19, flit_logging_reg_18, flit_logging_reg_17, flit_logging_reg_16
// register         - FBER Measurement Enable [0]                  : RW
//                  - Clear FBER Counters [1]                      : RW
//                  - Granularity of per-Lane Error reported [3:2] : RW
//                  - Report Longest Burst vs First Burst [4]      : RW
//                  - RsvdP [31:5]                                     
// -----------------------------------------------------------------------------
// reg       fber_measurement_en           ;     
// reg       clr_fber_cnt                  ;
// reg [1:0] gran_per_lane_err_rpt         ;
// reg       rpt_longest_burst_vs_1st_burst;    

always @(posedge cdm_clk_g or negedge non_sticky_rst_n) begin : fber_measurement_control_PROC
   if (!non_sticky_rst_n) begin
     fber_measurement_en            <= #TP    1'b0   ;
     clr_fber_cnt                   <= #TP    1'b0   ;
     gran_per_lane_err_rpt          <= #TP {2{1'b0}} ;
     rpt_longest_burst_vs_1st_burst <= #TP    1'b0   ;
   end
   else begin 
     // The following registers are clocked by cdm_clk_g which is a gated version of the core_clk used inside the CDM
     fber_measurement_en            <= #TP (flit_logging_reg_id[4] & flit_write_pulse[0] ) ? lbc_cdm_data[0]   : fber_measurement_en             ;
     clr_fber_cnt                   <= #TP (flit_logging_reg_id[4] & flit_write_pulse[0] ) ? lbc_cdm_data[1]   : clr_fber_cnt                    ;
     gran_per_lane_err_rpt          <= #TP (flit_logging_reg_id[4] & flit_write_pulse[0] ) ? lbc_cdm_data[3:2] : gran_per_lane_err_rpt           ;
     rpt_longest_burst_vs_1st_burst <= #TP (flit_logging_reg_id[4] & flit_write_pulse[0] ) ? lbc_cdm_data[4]   : rpt_longest_burst_vs_1st_burst  ;
   end
end

assign {flit_logging_reg_19, flit_logging_reg_18, flit_logging_reg_17, flit_logging_reg_16} = { 27'b0                          ,
                                                                                                rpt_longest_burst_vs_1st_burst ,
                                                                                                gran_per_lane_err_rpt          ,
                                                                                                1'b0                           , 
                                                                                                fber_measurement_en
                                                                                              };  
                                                              
// -----------------------------------------------------------------------------
// FBER Measurement Status 1 Register
// -----------------------------------------------------------------------------
// flit_logging_reg_id     - 5
// PCIE Offset      - `FLIT_PTR + 14h
// length           - 4 byte
// Cfig register    - flit_logging_reg_23, flit_logging_reg_22, flit_logging_reg_21, flit_logging_reg_20
// register         - Flit Counter [31:0] : ROS                                     
// -----------------------------------------------------------------------------
// wire [31:0] flit_cnt;  

assign {flit_logging_reg_23, flit_logging_reg_22, flit_logging_reg_21, flit_logging_reg_20} = { flit_cnt
                                                                                              };  
                                                              
// -----------------------------------------------------------------------------
// FBER Measurement Status 2 Register
// -----------------------------------------------------------------------------
// flit_logging_reg_id     - 6
// PCIE Offset      - `FLIT_PTR + 18h
// length           - 4 byte
// Cfig register    - flit_logging_reg_27, flit_logging_reg_26, flit_logging_reg_25, flit_logging_reg_24
// register         - Invalid Flit Counter [31:0] : ROS                                     
// -----------------------------------------------------------------------------
// wire [15:0] invalid_flit_cnt;  

assign {flit_logging_reg_27, flit_logging_reg_26, flit_logging_reg_25, flit_logging_reg_24} = { 16'b0,
                                                                                                invalid_flit_cnt
                                                                                              };  

// -----------------------------------------------------------------------------
// FBER Measurement Status 3 Register
// -----------------------------------------------------------------------------
// flit_logging_reg_id     - 7
// PCIE Offset      - `FLIT_PTR + 1Ch
// length           - 4 byte
// Cfig register    - flit_logging_reg_31, flit_logging_reg_30, flit_logging_reg_29, flit_logging_reg_28
// register         - Lane #0 Correctable Counter[15:0]  : RO
//                  - Lane #1 Correctable Counter[31:16] : RO
// -----------------------------------------------------------------------------
// wire [15:0] lane_0_corr_cnt;  
// wire [15:0] lane_1_corr_cnt;

assign {flit_logging_reg_31, flit_logging_reg_30, flit_logging_reg_29, flit_logging_reg_28} = { lane_1_corr_cnt,
                                                                                                lane_0_corr_cnt
                                                                                              }; 
 
// -----------------------------------------------------------------------------
// FBER Measurement Status 4 Register
// -----------------------------------------------------------------------------
// flit_logging_reg_id     - 8
// PCIE Offset      - `FLIT_PTR + 20h
// length           - 4 byte
// Cfig register    - flit_logging_reg_35, flit_logging_reg_34, flit_logging_reg_33, flit_logging_reg_32
// register         - Lane #2 Correctable Counter[15:0]  : RO
//                  - Lane #3 Correctable Counter[31:16] : RO
// -----------------------------------------------------------------------------
// wire [15:0] lane_2_corr_cnt;  
// wire [15:0] lane_3_corr_cnt;

assign {flit_logging_reg_35, flit_logging_reg_34, flit_logging_reg_33, flit_logging_reg_32} = { lane_3_corr_cnt,
                                                                                                lane_2_corr_cnt
                                                                                              }; 
                                                              
// -----------------------------------------------------------------------------
// FBER Measurement Status 5 Register
// -----------------------------------------------------------------------------
// flit_logging_reg_id     - 9
// PCIE Offset      - `FLIT_PTR + 24h
// length           - 4 byte
// Cfig register    - flit_logging_reg_39, flit_logging_reg_38, flit_logging_reg_37, flit_logging_reg_36
// register         - Lane #4 Correctable Counter[15:0]  : RO
//                  - Lane #5 Correctable Counter[31:16] : RO
// -----------------------------------------------------------------------------
// wire [15:0] lane_4_corr_cnt;  
// wire [15:0] lane_5_corr_cnt;

assign {flit_logging_reg_39, flit_logging_reg_38, flit_logging_reg_37, flit_logging_reg_36} = { lane_5_corr_cnt,
                                                                                                lane_4_corr_cnt
                                                                                              }; 

// -----------------------------------------------------------------------------
// FBER Measurement Status 6 Register
// -----------------------------------------------------------------------------
// flit_logging_reg_id     - 10
// PCIE Offset      - `FLIT_PTR + 28h
// length           - 4 byte
// Cfig register    - flit_logging_reg_43, flit_logging_reg_42, flit_logging_reg_41, flit_logging_reg_40
// register         - Lane #6 Correctable Counter[15:0]  : RO
//                  - Lane #7 Correctable Counter[31:16] : RO
// -----------------------------------------------------------------------------
// wire [15:0] lane_6_corr_cnt;  
// wire [15:0] lane_7_corr_cnt;

assign {flit_logging_reg_43, flit_logging_reg_42, flit_logging_reg_41, flit_logging_reg_40} = { lane_7_corr_cnt,
                                                                                                lane_6_corr_cnt
                                                                                              }; 
                                                              
// -----------------------------------------------------------------------------
// FBER Measurement Status 7 Register
// -----------------------------------------------------------------------------
// flit_logging_reg_id     - 11
// PCIE Offset      - `FLIT_PTR + 2Ch
// length           - 4 byte
// Cfig register    - flit_logging_reg_47, flit_logging_reg_46, flit_logging_reg_45, flit_logging_reg_44
// register         - Lane #8 Correctable Counter[15:0]  : RO
//                  - Lane #9 Correctable Counter[31:16] : RO
// -----------------------------------------------------------------------------
// wire [15:0] lane_8_corr_cnt;  
// wire [15:0] lane_9_corr_cnt;

assign {flit_logging_reg_47, flit_logging_reg_46, flit_logging_reg_45, flit_logging_reg_44} = { lane_9_corr_cnt,
                                                                                                lane_8_corr_cnt
                                                                                              }; 
                                                              
// -----------------------------------------------------------------------------
// FBER Measurement Status 8 Register
// -----------------------------------------------------------------------------
// flit_logging_reg_id     - 12
// PCIE Offset      - `FLIT_PTR + 30h
// length           - 4 byte
// Cfig register    - flit_logging_reg_51, flit_logging_reg_50, flit_logging_reg_49, flit_logging_reg_48
// register         - Lane #10 Correctable Counter[15:0]  : RO
//                  - Lane #11 Correctable Counter[31:16] : RO
// -----------------------------------------------------------------------------
// wire [15:0] lane_10_corr_cnt;  
// wire [15:0] lane_11_corr_cnt;

assign {flit_logging_reg_51, flit_logging_reg_50, flit_logging_reg_49, flit_logging_reg_48} = { lane_11_corr_cnt,
                                                                                                lane_10_corr_cnt
                                                                                              };      

// -----------------------------------------------------------------------------
// FBER Measurement Status 9 Register
// -----------------------------------------------------------------------------
// flit_logging_reg_id     - 13
// PCIE Offset      - `FLIT_PTR + 34h
// length           - 4 byte
// Cfig register    - flit_logging_reg_55, flit_logging_reg_54, flit_logging_reg_53, flit_logging_reg_52
// register         - Lane #12 Correctable Counter[15:0]  : RO
//                  - Lane #13 Correctable Counter[31:16] : RO
// -----------------------------------------------------------------------------
// wire [15:0] lane_12_corr_cnt;  
// wire [15:0] lane_13_corr_cnt;

assign {flit_logging_reg_55, flit_logging_reg_54, flit_logging_reg_53, flit_logging_reg_52} = { lane_13_corr_cnt,
                                                                                                lane_12_corr_cnt
                                                                                              };  
        
// -----------------------------------------------------------------------------
// FBER Measurement Status 10 Register
// -----------------------------------------------------------------------------
// flit_logging_reg_id     - 14
// PCIE Offset      - `FLIT_PTR + 38h
// length           - 4 byte
// Cfig register    - flit_logging_reg_59, flit_logging_reg_58, flit_logging_reg_57, flit_logging_reg_56
// register         - Lane #14 Correctable Counter[15:0]  : RO
//                  - Lane #15 Correctable Counter[31:16] : RO
// -----------------------------------------------------------------------------
// wire [15:0] lane_14_corr_cnt;  
// wire [15:0] lane_15_corr_cnt;

assign {flit_logging_reg_59, flit_logging_reg_58, flit_logging_reg_57, flit_logging_reg_56} = { lane_15_corr_cnt,
                                                                                                lane_14_corr_cnt
                                                                                              };         

// -----------------------------------------------------------------------------
// Register Read Operation
// -----------------------------------------------------------------------------

always @(*)
begin : read_data_PROC
    unique case (1'b1)
    flit_logging_reg_id[0]   : flit_logging_reg_data = {flit_logging_reg_03, flit_logging_reg_02, flit_logging_reg_01, flit_logging_reg_00};   // 0x00
    flit_logging_reg_id[1]   : flit_logging_reg_data = {flit_logging_reg_07, flit_logging_reg_06, flit_logging_reg_05, flit_logging_reg_04};   // 0x04
    flit_logging_reg_id[2]   : flit_logging_reg_data = {flit_logging_reg_11, flit_logging_reg_10, flit_logging_reg_09, flit_logging_reg_08};   // 0x08
    flit_logging_reg_id[3]   : flit_logging_reg_data = {flit_logging_reg_15, flit_logging_reg_14, flit_logging_reg_13, flit_logging_reg_12};   // 0x0C
    flit_logging_reg_id[4]   : flit_logging_reg_data = {flit_logging_reg_19, flit_logging_reg_18, flit_logging_reg_17, flit_logging_reg_16};   // 0x10
    flit_logging_reg_id[5]   : flit_logging_reg_data = {flit_logging_reg_23, flit_logging_reg_22, flit_logging_reg_21, flit_logging_reg_20};   // 0x14
    flit_logging_reg_id[6]   : flit_logging_reg_data = {flit_logging_reg_27, flit_logging_reg_26, flit_logging_reg_25, flit_logging_reg_24};   // 0x18    
    flit_logging_reg_id[7]   : flit_logging_reg_data = {flit_logging_reg_31, flit_logging_reg_30, flit_logging_reg_29, flit_logging_reg_28};   // 0x1C    
    flit_logging_reg_id[8]   : flit_logging_reg_data = {flit_logging_reg_35, flit_logging_reg_34, flit_logging_reg_33, flit_logging_reg_32};   // 0x20    
    flit_logging_reg_id[9]   : flit_logging_reg_data = {flit_logging_reg_39, flit_logging_reg_38, flit_logging_reg_37, flit_logging_reg_36};   // 0x24    
    flit_logging_reg_id[10]  : flit_logging_reg_data = {flit_logging_reg_43, flit_logging_reg_42, flit_logging_reg_41, flit_logging_reg_40};   // 0x28    
    flit_logging_reg_id[11]  : flit_logging_reg_data = {flit_logging_reg_47, flit_logging_reg_46, flit_logging_reg_45, flit_logging_reg_44};   // 0x2C    
    flit_logging_reg_id[12]  : flit_logging_reg_data = {flit_logging_reg_51, flit_logging_reg_50, flit_logging_reg_49, flit_logging_reg_48};   // 0x30    
    flit_logging_reg_id[13]  : flit_logging_reg_data = {flit_logging_reg_55, flit_logging_reg_54, flit_logging_reg_53, flit_logging_reg_52};   // 0x34    
    flit_logging_reg_id[14]  : flit_logging_reg_data = {flit_logging_reg_59, flit_logging_reg_58, flit_logging_reg_57, flit_logging_reg_56};   // 0x38    

    default                  : flit_logging_reg_data = `PCIE_UNUSED_RESPONSE;
    endcase
end


endmodule //cdm_flit_logging_reg
