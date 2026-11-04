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
// ---    $Revision: #3 $
// ---    $Id: //dwh/pcie_iip/main/fairbanks/design/Cdm/cxl_mbar0_link_cap_reg.sv#3 $
// -------------------------------------------------------------------------

// -----------------------------------------------------------------------------
// --- Module Description:
// -----------------------------------------------------------------------------
// --- This module contains the CXL Link Layer Capability Register in the MEMBAR0
// -----------------------------------------------------------------------------

`include "include/DWC_pcie_ctl_all_defs.svh"
`include "CXL/pkg/DWC_cxl_pkg.svh"
 
module cxl_mbar0_link_cap_reg
  import DWC_cxl_pkg::*;
 #(
     parameter INST              = 0
    ,parameter NF                = `CX_NFUNC
    ,parameter [31:0] LBC_EXT_AW = `CX_LBC_EXT_AW
    ,parameter [31:0] LBC_EXT_DW = 32*`CX_LBC_NW
)

                               (
  input                                core_clk,                // Clock
  input                                non_sticky_rst_n,       // Reset non_sticky register only
  input                                sticky_rst_n,           // Reset sticky register only
  input                                rdlh_link_up,           //Goes low on hot reset (Used to load the new values programmed into ACK timer, ACK CNT)
  input                                dbi_ro_wr_en,
  input                                upstream_port,
  input                                lbc_mbar0_link_cap_access,
  input                                lbc_ext_dbi_access,  
  input   [NF-1:0]                     temp_lbc_ext_cs,
  input   [LBC_EXT_AW-1:0]             lbc_ext_addr,
  input   [LBC_EXT_DW-1:0]             lbc_ext_dout,
  input   [(LBC_EXT_DW/8)-1:0]         lbc_ext_wr,
  input                                ext_lbc_override_en,
  input   [NF-1:0]                     temp_ext_lbc_ack,
  input   [(`CX_LBC_NW*32*NF)-1:0]     temp_ext_lbc_din,  

  //--Signals for Link Layer Capability Register
  input  [3:0] mbar0_link_ver_received,              //Version of AL received from INIT.Param flit.Used for debug.
  input  [7:0] mbar0_link_llr_wrap_val_received,       //LLR Wrap value received from INIT.Param flit. Used for debug.
  input  [4:0] mbar0_link_num_retry_received,          //Num_Retry value reflected in the last Retry.Req message received. Used for debug 
  input  [4:0] mbar0_link_num_phy_reinit_received,     //Num_Phy_Reinit value reflected in the last Retry.Req message received. Used for debug  
  input  [7:0] mbar0_link_wr_ptr_received,             //Wr_Ptr value reflected in the last Retry.Ack message received 
  input  [7:0] mbar0_link_echo_eseq_received,          //Echo_Eseq value reflected in the last Retry.Ack message received  
  input  [7:0] mbar0_link_num_free_buf_received,       //Num_Free_Buf value reflected in the last Retry.Ack message received  
  //--Signals for Link Layer Control and Status Register
  input        mbar0_link_ll_reset_clr,                //controller asserts this when link layer reset is completed with ll_reset_bit set.  
  input  [1:0] mbar0_link_init_state,                  //This field reflects the current initialization status of the Link Layer  
  input  [7:0] mbar0_link_ll_retry_buffer_consumed,    //Snapshot of link layer retry buffer consumed  
  //--Signals for Link Layer Rx Credit Return Status Register
  input  [9:0] mbar0_link_rx_cache_req_credits_stat,   //Running snapshot of accumulated Cache Request credits to be returned 
  input  [9:0] mbar0_link_rx_cache_rsp_credits_stat,   //Running snapshot of accumulated Cache Response credits to be returned 
  input  [9:0] mbar0_link_rx_cache_data_credits_stat,  //Running snapshot of accumulated Cache Data credits to be returned    
  input  [9:0] mbar0_link_rx_mem_req_rsp_credits_stat, //Running snapshot of accumulated Mem Request or Response credits to be returned 
  input  [9:0] mbar0_link_rx_mem_data_credits_stat,    //Running snapshot of accumulated Mem Data credits to be returned  
  input  [9:0] mbar0_link_rx_mem_bi_credits_stat,    //Running snapshot of accumulated Mem Data credits to be returned  

  //--Signals for Link Layer Tx Credit Status Register 
  input  [9:0] mbar0_link_tx_cache_req_credits_stat,   //Running snapshot of accumulated Cache Request credits for Tx  
  input  [9:0] mbar0_link_tx_cache_rsp_credits_stat,   //Running snapshot of accumulated Cache Response credits for Tx  
  input  [9:0] mbar0_link_tx_cache_data_credits_stat,  //Running snapshot of accumulated Cache Data credits for Tx  
  input  [9:0] mbar0_link_tx_mem_req_rsp_credits_stat, //Running snapshot of accumulated Mem Request or Response credits for Tx  
  input  [9:0] mbar0_link_tx_mem_data_credits_stat,    //Running snapshot of accumulated Mem Data credits for Tx   
  input  [9:0] mbar0_link_tx_mem_bi_credits_stat,    //Running snapshot of accumulated Mem Data credits to be returned  

// Outputs

  output  [NF-1:0]                     mbar0_link_cap_lbc_ext_cs,
  output  [NF-1:0]                     mbar0_link_cap_ext_lbc_ack,
  output  [(`CX_LBC_NW*32*NF)-1:0]     mbar0_link_cap_ext_lbc_din,  

  //--Signals for Link Layer Capability Register
  output [3:0] mbar0_link_ver_supported,               //Version of AL the port is compliant with. For CXL 1.0, this should be '0001            
  output [7:0] mbar0_link_llr_wrap_val_supported,      //LLR Wrap value supported by this entity. Used for debug.
  //--Signals for Link Layer Control and Status Register
  output       mbar0_link_ll_reset,                    //Re-initialize without resetting values in sticky Registers
  output       mbar0_link_ll_init_stall,               //If set, link layer stalls the transmission of the LLCTRL-INIT.Param flit until this bit is cleared  
  output       mbar0_link_ll_crd_stall,                //If set, link layer stalls credit initialization until this bit is cleared
  //Signals for Link Layer Rx Credit Control Register
  output [9:0] mbar0_link_rx_cache_req_credits,         //Credits to advertise for Cache Request channel at init
  output [9:0] mbar0_link_rx_cache_rsp_credits,         //Credits to advertise for Cache Response channel at init
  output [9:0] mbar0_link_rx_cache_data_credits,        //Credits to advertise for Cache Data channel at init
  output [9:0] mbar0_link_rx_mem_req_rsp_credits,       //Credits to advertise for Mem Request or Response channel at init
  output [9:0] mbar0_link_rx_mem_data_credits,          //Credits to advertise for Mem Data channel at init
  output  [9:0] mbar0_link_rx_mem_bi_credits,           //Running snapshot of accumulated Mem Data credits to be returned  
  //Signals for Link Layer Ack Timer Control Register
  output [7:0] mbar0_link_ack_force_threshold,          //This specifies how many Flit Acks the Link Layer should accumulate before injecting a LLCRD
  output [9:0] mbar0_link_ack_flush_retimer             //This specifies how many link layer clock cycles the entity should wait in case of idle, before flushing accumulated Acks using a LLCRD
  //Signals for Link Layer Defeature Register
  ,output       mbar0_link_mdh_disable                   //Software needs to ensure it programs this value consistently on the UP & DP. After programming, a hot reset is required for the disable to take effect.

);

parameter TP    = `TP;                          // Clock to Q delay (simulator insurance)

wire    [7:0]   cxl_mbar0_link_cap_reg_03, cxl_mbar0_link_cap_reg_02, cxl_mbar0_link_cap_reg_01, cxl_mbar0_link_cap_reg_00;           
wire    [7:0]   cxl_mbar0_link_cap_reg_07, cxl_mbar0_link_cap_reg_06, cxl_mbar0_link_cap_reg_05, cxl_mbar0_link_cap_reg_04;
wire    [7:0]   cxl_mbar0_link_cap_reg_11, cxl_mbar0_link_cap_reg_10, cxl_mbar0_link_cap_reg_09, cxl_mbar0_link_cap_reg_08;
wire    [7:0]   cxl_mbar0_link_cap_reg_15, cxl_mbar0_link_cap_reg_14, cxl_mbar0_link_cap_reg_13, cxl_mbar0_link_cap_reg_12;
wire    [7:0]   cxl_mbar0_link_cap_reg_19, cxl_mbar0_link_cap_reg_18, cxl_mbar0_link_cap_reg_17, cxl_mbar0_link_cap_reg_16;
wire    [7:0]   cxl_mbar0_link_cap_reg_23, cxl_mbar0_link_cap_reg_22, cxl_mbar0_link_cap_reg_21, cxl_mbar0_link_cap_reg_20;
wire    [7:0]   cxl_mbar0_link_cap_reg_27, cxl_mbar0_link_cap_reg_26, cxl_mbar0_link_cap_reg_25, cxl_mbar0_link_cap_reg_24;
wire    [7:0]   cxl_mbar0_link_cap_reg_31, cxl_mbar0_link_cap_reg_30, cxl_mbar0_link_cap_reg_29, cxl_mbar0_link_cap_reg_28;
wire    [7:0]   cxl_mbar0_link_cap_reg_35, cxl_mbar0_link_cap_reg_34, cxl_mbar0_link_cap_reg_33, cxl_mbar0_link_cap_reg_32;
wire    [7:0]   cxl_mbar0_link_cap_reg_39, cxl_mbar0_link_cap_reg_38, cxl_mbar0_link_cap_reg_37, cxl_mbar0_link_cap_reg_36;
wire    [7:0]   cxl_mbar0_link_cap_reg_43, cxl_mbar0_link_cap_reg_42, cxl_mbar0_link_cap_reg_41, cxl_mbar0_link_cap_reg_40;
wire    [7:0]   cxl_mbar0_link_cap_reg_47, cxl_mbar0_link_cap_reg_46, cxl_mbar0_link_cap_reg_45, cxl_mbar0_link_cap_reg_44;
wire    [7:0]   cxl_mbar0_link_cap_reg_51, cxl_mbar0_link_cap_reg_50, cxl_mbar0_link_cap_reg_49, cxl_mbar0_link_cap_reg_48;
wire    [7:0]   cxl_mbar0_link_cap_reg_55, cxl_mbar0_link_cap_reg_54, cxl_mbar0_link_cap_reg_53, cxl_mbar0_link_cap_reg_52;


reg  [LBC_EXT_DW-1:0]      cxl_mbar0_link_cap_reg_data;  
reg                        cxl_mbar0_link_cap_reg_ack;            // 2 cycle ack for read data
wire                       int_lbc_ext_dbi;
wire                       cxl_mbar0_link_cap_reg_sel;

assign      int_lbc_ext_dbi            = lbc_ext_dbi_access & dbi_ro_wr_en;
assign      cxl_mbar0_link_cap_reg_sel = lbc_mbar0_link_cap_access & temp_lbc_ext_cs[0];

reg                       lbc_mbar0_link_cap_access_d;        // Registered version of lbc_mbar0_link_cap_access
wire                      lbc_mbar0_link_cap_access_extd;     // Extending lbc_mbar0_link_cap_access by 1 cycle so as to be able to drive a 2 cycle ack

always @(posedge core_clk or negedge non_sticky_rst_n)
begin
    if(!non_sticky_rst_n) begin
          lbc_mbar0_link_cap_access_d  <= #TP 0;
    end
    else begin
          lbc_mbar0_link_cap_access_d <= #TP lbc_mbar0_link_cap_access;
    end      
end

assign lbc_mbar0_link_cap_access_extd = (lbc_mbar0_link_cap_access | lbc_mbar0_link_cap_access_d);

//-----------------------------------------------------------------------------
//MUX THE SIGNALS
//-----------------------------------------------------------------------------

assign mbar0_link_cap_lbc_ext_cs  = lbc_mbar0_link_cap_access ? {NF{1'b0}} : temp_lbc_ext_cs;
assign mbar0_link_cap_ext_lbc_ack = (lbc_mbar0_link_cap_access_extd && !ext_lbc_override_en) ? {{{NF-1}{1'b0}},cxl_mbar0_link_cap_reg_ack} : temp_ext_lbc_ack;
assign mbar0_link_cap_ext_lbc_din = (lbc_mbar0_link_cap_access_extd && !ext_lbc_override_en) ? {{{`CX_LBC_NW*32*(NF-1)}{1'b0}},cxl_mbar0_link_cap_reg_data} : temp_ext_lbc_din; 




//------------------------------------------------------------------------------
// Generating the reg id
//------------------------------------------------------------------------------
reg [6:0]  cxl_mbar0_link_cap_reg_id;

always @(posedge core_clk or negedge non_sticky_rst_n)
begin
    if(!non_sticky_rst_n) begin
          cxl_mbar0_link_cap_reg_id    <= #TP 0;
    end
    else begin
          cxl_mbar0_link_cap_reg_id[0] <= #TP (lbc_ext_addr[11:3] == ((`CXL_RCRB_MEMBAR0_LINK_CAP_PTR + 12'h000) >> 3)) & cxl_mbar0_link_cap_reg_sel;
          cxl_mbar0_link_cap_reg_id[1] <= #TP (lbc_ext_addr[11:3] == ((`CXL_RCRB_MEMBAR0_LINK_CAP_PTR + 12'h008) >> 3)) & cxl_mbar0_link_cap_reg_sel;
          cxl_mbar0_link_cap_reg_id[2] <= #TP (lbc_ext_addr[11:3] == ((`CXL_RCRB_MEMBAR0_LINK_CAP_PTR + 12'h010) >> 3)) & cxl_mbar0_link_cap_reg_sel;
          cxl_mbar0_link_cap_reg_id[3] <= #TP (lbc_ext_addr[11:3] == ((`CXL_RCRB_MEMBAR0_LINK_CAP_PTR + 12'h018) >> 3)) & cxl_mbar0_link_cap_reg_sel;
          cxl_mbar0_link_cap_reg_id[4] <= #TP (lbc_ext_addr[11:3] == ((`CXL_RCRB_MEMBAR0_LINK_CAP_PTR + 12'h020) >> 3)) & cxl_mbar0_link_cap_reg_sel;
          cxl_mbar0_link_cap_reg_id[5] <= #TP (lbc_ext_addr[11:3] == ((`CXL_RCRB_MEMBAR0_LINK_CAP_PTR + 12'h028) >> 3)) & cxl_mbar0_link_cap_reg_sel;
          cxl_mbar0_link_cap_reg_id[6] <= #TP (lbc_ext_addr[11:3] == ((`CXL_RCRB_MEMBAR0_LINK_CAP_PTR + 12'h030) >> 3)) & cxl_mbar0_link_cap_reg_sel;    
       
    end
end

//------------------------------------------------------------------
//Generating the 2 cycle ack
//------------------------------------------------------------------
wire mbar0_link_cap_acc;
reg  mbar0_link_cap_acc_1d;
reg  int_ack;
reg  cxl_mbar0_link_cap_reg_ack_done;
reg [63:0]  cxl_mbar0_link_cap_reg_data_int;

assign mbar0_link_cap_acc = |cxl_mbar0_link_cap_reg_id;

// rising edge detect mbar0_link_cap_acc
always @(posedge core_clk or negedge sticky_rst_n) begin
   if (!sticky_rst_n) begin
      mbar0_link_cap_acc_1d    <= #TP 1'b0 ;
      int_ack                  <= #TP 1'b0 ;
    end
    else begin
       mbar0_link_cap_acc_1d    <= #TP mbar0_link_cap_acc ;
       int_ack                  <= #TP mbar0_link_cap_acc && !mbar0_link_cap_acc_1d ;
    end
end

always @(posedge core_clk or negedge sticky_rst_n) begin
    if (!sticky_rst_n) begin
        cxl_mbar0_link_cap_reg_ack        <= #TP 1'b0 ;
        cxl_mbar0_link_cap_reg_data       <= #TP 32'h0000_0000 ;
        cxl_mbar0_link_cap_reg_ack_done   <= #TP 1'b0 ;
    end
    else begin
        if ( int_ack ) begin
            cxl_mbar0_link_cap_reg_ack  <= #TP 1'b1 ;
            cxl_mbar0_link_cap_reg_data <= #TP  cxl_mbar0_link_cap_reg_data_int;
        end
        else if ( cxl_mbar0_link_cap_reg_ack_done ) begin
            cxl_mbar0_link_cap_reg_ack      <= #TP 1'b0 ;
            cxl_mbar0_link_cap_reg_ack_done <= #TP 1'b0 ;
        end
        else if ( cxl_mbar0_link_cap_reg_ack ) begin
            cxl_mbar0_link_cap_reg_ack_done <= #TP 1'b1 ;
        end
    end
end


// -----------------------------------------------------------------------------
// CXL RCRB Port Subsystem CXL Link Capability Structure - CXL Link Layer Capability Register
// -----------------------------------------------------------------------------
// cxl_mbar0_link_cap_reg_id     - 0 
// PCIE Offset      - `CXL_MEMBAR0_CACHE_MEM_LINK_PTR
// length           - 8 byte
// Cfig register    - cxl_mbar0_link_cap_reg_07, cxl_mbar0_link_cap_reg_06, cxl_mbar0_link_cap_reg_05, cxl_mbar0_link_cap_reg_04,
//                    cxl_mbar0_link_cap_reg_03, cxl_mbar0_link_cap_reg_02, cxl_mbar0_link_cap_reg_01, cxl_mbar0_link_cap_reg_00
// -----------------------------------------------------------------------------
reg  [3:0] link_ver_supported; 
reg  [7:0] link_llr_wrap_val_supported; 
assign mbar0_link_ver_supported = link_ver_supported;
assign mbar0_link_llr_wrap_val_supported = link_llr_wrap_val_supported;
always @(posedge core_clk or negedge sticky_rst_n) begin : cxl_mbar0_link_layer_cap_reg_sticky_PROC
    if (!sticky_rst_n) begin
       link_ver_supported          <= #TP `CXL_PORT_RCRB_MEMBAR0_LINK_VER_SUP;
       link_llr_wrap_val_supported <= #TP (`CX_CXL_RBUF_DEPTH - 1);
    end
    else begin
       link_ver_supported          <= #TP (cxl_mbar0_link_cap_reg_id[0] & lbc_ext_wr[0])  ? lbc_ext_dout[3:0] : link_ver_supported;
       link_llr_wrap_val_supported <= #TP (cxl_mbar0_link_cap_reg_id[0] & lbc_ext_wr[1])  ? lbc_ext_dout[15:8] : link_llr_wrap_val_supported;
    end
end

reg  [3:0] link_ver_received; 
reg  [7:0] link_llr_wrap_val_received; 
reg  [4:0] num_retry_received; 
reg  [4:0] num_phy_retinit_received; 
reg  [7:0] wr_ptr_received; 
reg  [7:0] echo_eseq_received; 
reg  [7:0] num_free_buf_received;
reg        no_ll_reset_support;
assign {cxl_mbar0_link_cap_reg_03, cxl_mbar0_link_cap_reg_02, cxl_mbar0_link_cap_reg_01, cxl_mbar0_link_cap_reg_00} = {num_phy_retinit_received[2:0], num_retry_received, link_llr_wrap_val_received, link_llr_wrap_val_supported, link_ver_received, link_ver_supported};

assign {cxl_mbar0_link_cap_reg_07, cxl_mbar0_link_cap_reg_06, cxl_mbar0_link_cap_reg_05, cxl_mbar0_link_cap_reg_04} = {5'h0, no_ll_reset_support, num_free_buf_received, echo_eseq_received, wr_ptr_received, num_phy_retinit_received[4:3]};
always @(posedge core_clk or negedge non_sticky_rst_n) begin : cxl_mbar0_link_layer_cap_reg_non_sticky_PROC
    if (!non_sticky_rst_n) begin 
       link_ver_received          <= #TP 4'h0;
       link_llr_wrap_val_received <= #TP 4'h0;
       num_retry_received         <= #TP 5'h0;
       num_phy_retinit_received   <= #TP 5'h0;
       wr_ptr_received            <= #TP 8'h0;
       echo_eseq_received         <= #TP 8'h0;
       num_free_buf_received      <= #TP 8'h0;
       no_ll_reset_support        <= #TP 1'b0;
    end else begin
       link_ver_received          <= #TP mbar0_link_ver_received;
       link_llr_wrap_val_received <= #TP mbar0_link_llr_wrap_val_received;
       num_retry_received         <= #TP mbar0_link_num_retry_received;
       num_phy_retinit_received   <= #TP mbar0_link_num_phy_reinit_received;
       wr_ptr_received            <= #TP mbar0_link_wr_ptr_received;
       echo_eseq_received         <= #TP mbar0_link_echo_eseq_received;
       num_free_buf_received      <= #TP mbar0_link_num_free_buf_received;
       no_ll_reset_support        <= #TP (cxl_mbar0_link_cap_reg_id[0] & lbc_ext_wr[7] & int_lbc_ext_dbi)  ? lbc_ext_dout[58] : no_ll_reset_support;
    end 
end

// -----------------------------------------------------------------------------
// CXL RCRB Port Subsystem CXL Link Capability Structure - CXL Link Control and Status Register
// -----------------------------------------------------------------------------
// cxl_mbar0_link_cap_reg_id     - 1 
// PCIE Offset      - `CXL_MEMBAR0_CACHE_MEM_LINK_PTR + 08h
// length           - 8 byte
// Cfig register    - cxl_mbar0_link_cap_reg_15, cxl_mbar0_link_cap_reg_14, cxl_mbar0_link_cap_reg_13, cxl_mbar0_link_cap_reg_12,
//                    cxl_mbar0_link_cap_reg_11, cxl_mbar0_link_cap_reg_10, cxl_mbar0_link_cap_reg_09, cxl_mbar0_link_cap_reg_08
// -----------------------------------------------------------------------------

reg ll_init_stall;
reg ll_crd_stall;
assign mbar0_link_ll_init_stall = ll_init_stall;
assign mbar0_link_ll_crd_stall  = ll_crd_stall;
always @(posedge core_clk or negedge sticky_rst_n) begin : cxl_mbar0_link_control_status_sticky_PROC
    if (!sticky_rst_n) begin
       ll_init_stall    <= #TP 0;
       ll_crd_stall     <= #TP 0;
    end
    else begin
       ll_init_stall <= #TP (cxl_mbar0_link_cap_reg_id[1] & lbc_ext_wr[0])  ? lbc_ext_dout[1] : ll_init_stall;
       ll_crd_stall  <= #TP (cxl_mbar0_link_cap_reg_id[1] & lbc_ext_wr[0])  ? lbc_ext_dout[2] : ll_crd_stall;
    end
end

reg  ll_reset; 
reg  [1:0] init_state; 
reg  [7:0] ll_retry_buffer_consumed;
assign mbar0_link_ll_reset = ll_reset;
assign {cxl_mbar0_link_cap_reg_11, cxl_mbar0_link_cap_reg_10, cxl_mbar0_link_cap_reg_09, cxl_mbar0_link_cap_reg_08} = {19'h0, ll_retry_buffer_consumed, init_state, ll_crd_stall, ll_init_stall, ll_reset};
assign {cxl_mbar0_link_cap_reg_15, cxl_mbar0_link_cap_reg_14, cxl_mbar0_link_cap_reg_13, cxl_mbar0_link_cap_reg_12} = 32'h0;

always @(posedge core_clk or negedge non_sticky_rst_n) begin : cxl_mbar0_link_control_status_non_sticky_PROC
    if (!non_sticky_rst_n) begin 
       ll_reset                 <= #TP 0;
       init_state               <= #TP 0;
       ll_retry_buffer_consumed <= #TP 0;
    end else begin
       ll_reset                 <= #TP ((~no_ll_reset_support) & cxl_mbar0_link_cap_reg_id[1] & lbc_ext_wr[0] & lbc_ext_dout[0]) ? 1'b1 : mbar0_link_ll_reset_clr ? 1'b0 : ll_reset;
       init_state               <= #TP mbar0_link_init_state ;
       ll_retry_buffer_consumed <= #TP mbar0_link_ll_retry_buffer_consumed ;
    end 
end 

// -----------------------------------------------------------------------------
// CXL RCRB Port Subsystem CXL Link Capability Structure - CXL Link Layer Rx Credit Control Register
// -----------------------------------------------------------------------------
// cxl_mbar0_link_cap_reg_id     - 2 
// PCIE Offset      - `CXL_MEMBAR0_CACHE_MEM_LINK_PTR + 10h
// length           - 8 byte
// Cfig register    - cxl_mbar0_link_cap_reg_23, cxl_mbar0_link_cap_reg_22, cxl_mbar0_link_cap_reg_21, cxl_mbar0_link_cap_reg_20,
//                    cxl_mbar0_link_cap_reg_19, cxl_mbar0_link_cap_reg_18, cxl_mbar0_link_cap_reg_17, cxl_mbar0_link_cap_reg_16
// -----------------------------------------------------------------------------
reg [9:0] cache_req_credits;
reg [9:0] cache_rsp_credits;
reg [9:0] cache_data_credits;
reg [9:0] mem_req_rsp_credits;
reg [9:0] mem_data_credits;
reg [9:0] mem_bi_credits;
assign mbar0_link_rx_cache_req_credits     = cache_req_credits;
assign mbar0_link_rx_cache_rsp_credits     = cache_rsp_credits;
assign mbar0_link_rx_cache_data_credits    = cache_data_credits;
assign mbar0_link_rx_mem_req_rsp_credits   = mem_req_rsp_credits;
assign mbar0_link_rx_mem_data_credits      = mem_data_credits;
assign mbar0_link_rx_mem_bi_credits        = mem_bi_credits;           //Running snapshot of accumulated Mem bi credits to be returned  
always @(posedge core_clk or negedge sticky_rst_n) begin : cxl_mbar0_link_rx_credit_ctrl_sticky_PROC
    if (!sticky_rst_n) begin
       cache_req_credits    <= #TP CACHE_REQ_DP;
       cache_rsp_credits    <= #TP CACHE_RSPQ_DP;
       cache_data_credits   <= #TP CACHE_DQ_DP;
       mem_req_rsp_credits  <= #TP MEM_RSPQ_DP;
       mem_data_credits     <= #TP MEM_DQ_DP;
    mem_bi_credits     <= #TP  MEM_BI_SNP_DP;
    end
    else begin
       cache_req_credits[7:0]    <= #TP (cxl_mbar0_link_cap_reg_id[2] & lbc_ext_wr[0]) ? lbc_ext_dout[7:0] : cache_req_credits[7:0];
       cache_req_credits[9:8]    <= #TP (cxl_mbar0_link_cap_reg_id[2] & lbc_ext_wr[1]) ? lbc_ext_dout[9:8] : cache_req_credits[9:8];
       cache_rsp_credits[5:0]    <= #TP (cxl_mbar0_link_cap_reg_id[2] & lbc_ext_wr[1]) ? lbc_ext_dout[15:10] : cache_rsp_credits[5:0];
       cache_rsp_credits[9:6]    <= #TP (cxl_mbar0_link_cap_reg_id[2] & lbc_ext_wr[2]) ? lbc_ext_dout[19:16] : cache_rsp_credits[9:6];
       cache_data_credits[3:0]   <= #TP (cxl_mbar0_link_cap_reg_id[2] & lbc_ext_wr[2]) ? lbc_ext_dout[23:20] : cache_data_credits[3:0];
       cache_data_credits[9:4]   <= #TP (cxl_mbar0_link_cap_reg_id[2] & lbc_ext_wr[3]) ? lbc_ext_dout[29:24] : cache_data_credits[9:4];
       mem_req_rsp_credits[1:0]  <= #TP (cxl_mbar0_link_cap_reg_id[2] & lbc_ext_wr[3]) ? lbc_ext_dout[31:30] : mem_req_rsp_credits[1:0];
       mem_req_rsp_credits[9:2]  <= #TP (cxl_mbar0_link_cap_reg_id[2] & lbc_ext_wr[4]) ? lbc_ext_dout[39:32] : mem_req_rsp_credits[9:2];
       mem_data_credits[7:0]     <= #TP (cxl_mbar0_link_cap_reg_id[2] & lbc_ext_wr[5]) ? lbc_ext_dout[47:40] : mem_data_credits[7:0];
       mem_data_credits[9:8]     <= #TP (cxl_mbar0_link_cap_reg_id[2] & lbc_ext_wr[6]) ? lbc_ext_dout[49:48] : mem_data_credits[9:8];
       mem_bi_credits[5:0]       <= #TP (cxl_mbar0_link_cap_reg_id[2] & lbc_ext_wr[6]) ? lbc_ext_dout[55:50] : mem_bi_credits[5:0]; 
       mem_bi_credits[9:6]       <= #TP (cxl_mbar0_link_cap_reg_id[2] & lbc_ext_wr[7]) ? lbc_ext_dout[59:56] : mem_bi_credits[9:6]; 
    end
end
assign {cxl_mbar0_link_cap_reg_19, cxl_mbar0_link_cap_reg_18, cxl_mbar0_link_cap_reg_17, cxl_mbar0_link_cap_reg_16} = {mem_req_rsp_credits[1:0], cache_data_credits, cache_rsp_credits, cache_req_credits};
assign {cxl_mbar0_link_cap_reg_23, cxl_mbar0_link_cap_reg_22, cxl_mbar0_link_cap_reg_21, cxl_mbar0_link_cap_reg_20} = { 4'h0, mem_bi_credits, mem_data_credits, mem_req_rsp_credits[9:2]};
// -----------------------------------------------------------------------------
// CXL RCRB Port Subsystem CXL Link Capability Structure - CXL Link Layer Rx Credit Return Status Register
// -----------------------------------------------------------------------------
// cxl_mbar0_link_cap_reg_id     - 3 
// PCIE Offset      - `CXL_MEMBAR0_CACHE_MEM_LINK_PTR + 18h
// length           - 8 byte
// Cfig register    - cxl_mbar0_link_cap_reg_31, cxl_mbar0_link_cap_reg_30, cxl_mbar0_link_cap_reg_29, cxl_mbar0_link_cap_reg_28,
//                    cxl_mbar0_link_cap_reg_27, cxl_mbar0_link_cap_reg_26, cxl_mbar0_link_cap_reg_25, cxl_mbar0_link_cap_reg_24
// -----------------------------------------------------------------------------
reg [9:0] cache_req_credits_sts;
reg [9:0] cache_rsp_credits_sts;
reg [9:0] cache_data_credits_sts;
reg [9:0] mem_req_rsp_credits_sts;
reg [9:0] mem_data_credits_sts;
reg [9:0] mem_bi_credits_sts;
always @(posedge core_clk or negedge non_sticky_rst_n) begin : cxl_mbar0_link_rx_credit_return_status_non_sticky_PROC
    if (!non_sticky_rst_n) begin
       cache_req_credits_sts    <= #TP '0;
       cache_rsp_credits_sts    <= #TP '0;
       cache_data_credits_sts   <= #TP '0;
       mem_req_rsp_credits_sts  <= #TP '0;
       mem_bi_credits_sts       <= #TP '0; 
       mem_data_credits_sts     <= #TP '0;
    end else begin
       cache_req_credits_sts    <= #TP mbar0_link_rx_cache_req_credits_stat;
       cache_rsp_credits_sts    <= #TP mbar0_link_rx_cache_rsp_credits_stat;
       cache_data_credits_sts   <= #TP mbar0_link_rx_cache_data_credits_stat; 
       mem_req_rsp_credits_sts  <= #TP mbar0_link_rx_mem_req_rsp_credits_stat;
       mem_data_credits_sts     <= #TP mbar0_link_rx_mem_data_credits_stat; 
       mem_bi_credits_sts       <= #TP mbar0_link_rx_mem_bi_credits_stat; 
    end
end
assign {cxl_mbar0_link_cap_reg_27, cxl_mbar0_link_cap_reg_26, cxl_mbar0_link_cap_reg_25, cxl_mbar0_link_cap_reg_24} = {mem_req_rsp_credits_sts[1:0], cache_data_credits_sts, cache_rsp_credits_sts, cache_req_credits_sts};
assign {cxl_mbar0_link_cap_reg_31, cxl_mbar0_link_cap_reg_30, cxl_mbar0_link_cap_reg_29, cxl_mbar0_link_cap_reg_28} = { 4'h0, mem_bi_credits_sts, mem_data_credits_sts, mem_req_rsp_credits_sts[9:2]};

// -----------------------------------------------------------------------------
// CXL RCRB Port Subsystem CXL Link Capability Structure - CXL Link Layer Tx Credit Status Register
// -----------------------------------------------------------------------------
// cxl_mbar0_link_cap_reg_id     - 4 
// PCIE Offset      - `CXL_MEMBAR0_CACHE_MEM_LINK_PTR + 20h
// length           - 8 byte
// Cfig register    - cxl_mbar0_link_cap_reg_39, cxl_mbar0_link_cap_reg_38, cxl_mbar0_link_cap_reg_37, cxl_mbar0_link_cap_reg_36,
//                    cxl_mbar0_link_cap_reg_35, cxl_mbar0_link_cap_reg_34, cxl_mbar0_link_cap_reg_33, cxl_mbar0_link_cap_reg_32
// -----------------------------------------------------------------------------
reg [9:0] tx_cache_req_credits_sts;
reg [9:0] tx_cache_rsp_credits_sts;
reg [9:0] tx_cache_data_credits_sts;
reg [9:0] tx_mem_req_rsp_credits_sts;
reg [9:0] tx_mem_data_credits_sts;
reg [9:0] tx_mem_bi_credits_sts;
always @(posedge core_clk or negedge non_sticky_rst_n) begin : cxl_mbar0_link_tx_credit_status_non_sticky_PROC
    if (!non_sticky_rst_n) begin
       tx_cache_req_credits_sts    <= #TP 0;
       tx_cache_rsp_credits_sts    <= #TP 0;
       tx_cache_data_credits_sts   <= #TP 0;
       tx_mem_req_rsp_credits_sts  <= #TP 0;
       tx_mem_data_credits_sts     <= #TP 0;
       tx_mem_bi_credits_sts       <= #TP 0;
    end else begin
       tx_cache_req_credits_sts    <= #TP mbar0_link_tx_cache_req_credits_stat;
       tx_cache_rsp_credits_sts    <= #TP mbar0_link_tx_cache_rsp_credits_stat;
       tx_cache_data_credits_sts   <= #TP mbar0_link_tx_cache_data_credits_stat; 
       tx_mem_req_rsp_credits_sts  <= #TP mbar0_link_tx_mem_req_rsp_credits_stat;
       tx_mem_data_credits_sts     <= #TP mbar0_link_tx_mem_data_credits_stat; 
       tx_mem_bi_credits_sts       <= #TP mbar0_link_tx_mem_bi_credits_stat;
    end
end
assign {cxl_mbar0_link_cap_reg_35, cxl_mbar0_link_cap_reg_34, cxl_mbar0_link_cap_reg_33, cxl_mbar0_link_cap_reg_32} = {tx_mem_req_rsp_credits_sts[1:0], tx_cache_data_credits_sts, tx_cache_rsp_credits_sts, tx_cache_req_credits_sts};
assign {cxl_mbar0_link_cap_reg_39, cxl_mbar0_link_cap_reg_38, cxl_mbar0_link_cap_reg_37, cxl_mbar0_link_cap_reg_36} = { 4'h0, tx_mem_bi_credits_sts, tx_mem_data_credits_sts, tx_mem_req_rsp_credits_sts[9:2]};

// -----------------------------------------------------------------------------
// CXL RCRB Port Subsystem CXL Link Capability Structure - CXL Link Layer Ack Timer Control Register
// -----------------------------------------------------------------------------
// cxl_mbar0_link_cap_reg_id     - 5 
// PCIE Offset      - `CXL_MEMBAR0_CACHE_MEM_LINK_PTR + 28h
// length           - 8 byte
// Cfig register    - cxl_mbar0_link_cap_reg_47, cxl_mbar0_link_cap_reg_46, cxl_mbar0_link_cap_reg_45, cxl_mbar0_link_cap_reg_44,
//                    cxl_mbar0_link_cap_reg_43, cxl_mbar0_link_cap_reg_42, cxl_mbar0_link_cap_reg_41, cxl_mbar0_link_cap_reg_40
// -----------------------------------------------------------------------------
reg [7:0] ack_force_threshold, ack_force_threshold_cfg_reg;
reg [9:0] ack_flush_retimer,ack_flush_retimer_cfg_reg;

assign mbar0_link_ack_force_threshold = ack_force_threshold;
assign mbar0_link_ack_flush_retimer   = ack_flush_retimer;


always @(posedge core_clk or negedge sticky_rst_n) begin : cxl_mbar0_link_ack_timer_ctrl_sticky_EP_PROC
    if (!sticky_rst_n) begin
       ack_force_threshold    <= #TP 8'd16;
       ack_flush_retimer      <= #TP 10'h20;
    end
    else begin
       ack_force_threshold    <= #TP (rdlh_link_up)  ? ack_force_threshold : ack_force_threshold_cfg_reg;
       ack_flush_retimer      <= #TP (rdlh_link_up)  ? ack_flush_retimer   : ack_flush_retimer_cfg_reg;
    end
end

always @(posedge core_clk or negedge sticky_rst_n) begin : cxl_mbar0_link_ack_timer_ctrl_sticky_cfg_reg_PROC
    if (!sticky_rst_n) begin
       ack_force_threshold_cfg_reg    <= #TP 8'd16;
       ack_flush_retimer_cfg_reg      <= #TP 10'h20;
    end
    else begin
       ack_force_threshold_cfg_reg    <= #TP (cxl_mbar0_link_cap_reg_id[5] & lbc_ext_wr[0])  ? lbc_ext_dout[7:0] : ack_force_threshold_cfg_reg;
       ack_flush_retimer_cfg_reg[7:0] <= #TP (cxl_mbar0_link_cap_reg_id[5] & lbc_ext_wr[1])  ? lbc_ext_dout[15:8] : ack_flush_retimer_cfg_reg[7:0];
       ack_flush_retimer_cfg_reg[9:8] <= #TP (cxl_mbar0_link_cap_reg_id[5] & lbc_ext_wr[2])  ? lbc_ext_dout[17:16] : ack_flush_retimer_cfg_reg[9:8];
    end
end

assign {cxl_mbar0_link_cap_reg_43, cxl_mbar0_link_cap_reg_42, cxl_mbar0_link_cap_reg_41, cxl_mbar0_link_cap_reg_40} = {14'h0, ack_flush_retimer_cfg_reg, ack_force_threshold_cfg_reg};
assign {cxl_mbar0_link_cap_reg_47, cxl_mbar0_link_cap_reg_46, cxl_mbar0_link_cap_reg_45, cxl_mbar0_link_cap_reg_44} = {32'h0};


// -----------------------------------------------------------------------------
// CXL RCRB Port Subsystem CXL Link Capability Structure - CXL Link Layer Defeature Register
// -----------------------------------------------------------------------------
// cxl_mbar0_link_cap_reg_id     - 6 
// PCIE Offset      - `CXL_MEMBAR0_CACHE_MEM_LINK_PTR + 30h
// length           - 8 byte
// Cfig register    - cxl_mbar0_link_cap_reg_55, cxl_mbar0_link_cap_reg_54, cxl_mbar0_link_cap_reg_53, cxl_mbar0_link_cap_reg_52,
//                    cxl_mbar0_link_cap_reg_51, cxl_mbar0_link_cap_reg_50, cxl_mbar0_link_cap_reg_49, cxl_mbar0_link_cap_reg_48
// -----------------------------------------------------------------------------
logic  mdh_disable;
logic  mdh_disable_reg;
assign mbar0_link_mdh_disable = mdh_disable;

always @(posedge core_clk or negedge sticky_rst_n) begin : cxl_mbar0_link_defeature_sticky_PROC
    if (!sticky_rst_n) begin
       mdh_disable   <= #TP 0;
    end
    else begin
       mdh_disable   <= #TP (rdlh_link_up)  ? mdh_disable : mdh_disable_reg;
    end
end

always @(posedge core_clk or negedge sticky_rst_n) begin : cxl_mbar0_link_defeature_sticky_reg_PROC
    if (!sticky_rst_n) begin
       mdh_disable_reg   <= #TP 0;
    end
    else begin
       mdh_disable_reg   <= #TP (cxl_mbar0_link_cap_reg_id[6] & lbc_ext_wr[0])  ? lbc_ext_dout[0] : mdh_disable_reg;  
    end
end

assign {cxl_mbar0_link_cap_reg_51, cxl_mbar0_link_cap_reg_50, cxl_mbar0_link_cap_reg_49, cxl_mbar0_link_cap_reg_48} = {31'h0, mdh_disable_reg};
assign {cxl_mbar0_link_cap_reg_55, cxl_mbar0_link_cap_reg_54, cxl_mbar0_link_cap_reg_53, cxl_mbar0_link_cap_reg_52} = 32'd0;


// =============================================================================
// Register Read Operation
// =============================================================================

always @(*)
begin : read_data_PROC
    unique case (1'b1) 
        cxl_mbar0_link_cap_reg_id[0]  : cxl_mbar0_link_cap_reg_data_int = {cxl_mbar0_link_cap_reg_07, cxl_mbar0_link_cap_reg_06, cxl_mbar0_link_cap_reg_05, cxl_mbar0_link_cap_reg_04,                                                                                  cxl_mbar0_link_cap_reg_03, cxl_mbar0_link_cap_reg_02, cxl_mbar0_link_cap_reg_01, cxl_mbar0_link_cap_reg_00};  
        cxl_mbar0_link_cap_reg_id[1]  : cxl_mbar0_link_cap_reg_data_int = {cxl_mbar0_link_cap_reg_15, cxl_mbar0_link_cap_reg_14, cxl_mbar0_link_cap_reg_13, cxl_mbar0_link_cap_reg_12,
                                                                           cxl_mbar0_link_cap_reg_11, cxl_mbar0_link_cap_reg_10, cxl_mbar0_link_cap_reg_09, cxl_mbar0_link_cap_reg_08};
        cxl_mbar0_link_cap_reg_id[2]  : cxl_mbar0_link_cap_reg_data_int = {cxl_mbar0_link_cap_reg_23, cxl_mbar0_link_cap_reg_22, cxl_mbar0_link_cap_reg_21, cxl_mbar0_link_cap_reg_20,
                                                                           cxl_mbar0_link_cap_reg_19, cxl_mbar0_link_cap_reg_18, cxl_mbar0_link_cap_reg_17, cxl_mbar0_link_cap_reg_16};
        cxl_mbar0_link_cap_reg_id[3]  : cxl_mbar0_link_cap_reg_data_int = {cxl_mbar0_link_cap_reg_31, cxl_mbar0_link_cap_reg_30, cxl_mbar0_link_cap_reg_29, cxl_mbar0_link_cap_reg_28,
                                                                           cxl_mbar0_link_cap_reg_27, cxl_mbar0_link_cap_reg_26, cxl_mbar0_link_cap_reg_25, cxl_mbar0_link_cap_reg_24};
        cxl_mbar0_link_cap_reg_id[4]  : cxl_mbar0_link_cap_reg_data_int = {cxl_mbar0_link_cap_reg_39, cxl_mbar0_link_cap_reg_38, cxl_mbar0_link_cap_reg_37, cxl_mbar0_link_cap_reg_36,
                                                                           cxl_mbar0_link_cap_reg_35, cxl_mbar0_link_cap_reg_34, cxl_mbar0_link_cap_reg_33, cxl_mbar0_link_cap_reg_32};
        cxl_mbar0_link_cap_reg_id[5]  : cxl_mbar0_link_cap_reg_data_int = {cxl_mbar0_link_cap_reg_47, cxl_mbar0_link_cap_reg_46, cxl_mbar0_link_cap_reg_45, cxl_mbar0_link_cap_reg_44,
                                                                           cxl_mbar0_link_cap_reg_43, cxl_mbar0_link_cap_reg_42, cxl_mbar0_link_cap_reg_41, cxl_mbar0_link_cap_reg_40};
        cxl_mbar0_link_cap_reg_id[6]  : cxl_mbar0_link_cap_reg_data_int = {cxl_mbar0_link_cap_reg_55, cxl_mbar0_link_cap_reg_54, cxl_mbar0_link_cap_reg_53, cxl_mbar0_link_cap_reg_52,
                                                                           cxl_mbar0_link_cap_reg_51, cxl_mbar0_link_cap_reg_50, cxl_mbar0_link_cap_reg_49, cxl_mbar0_link_cap_reg_48};
        default                       : cxl_mbar0_link_cap_reg_data_int = `PCIE_UNUSED_RESPONSE;
    endcase
end

endmodule // cxl_mbar0_link_cap_reg
