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
// --- RCS information:
// ---   $DateTime: 2023/11/28 03:44:34 $
// ---   $Revision: #15 $
// ---   $Id: //dwh/pcie_iip/main/fairbanks/design/CXL/DWC_cxl_mem_cache_ras.sv#15 $
// -------------------------------------------------------------------------
// --- Module Description:
// ----------------------------------------------------------------------------
// CXL Controller RAS Module
//
// CXL RX Valid Bit Error Mapping generated in RX TL
// ras_stat_cxl_vld_err[0] - H2D DATA
// ras_stat_cxl_vld_err[1] - D2H DATA
// ras_stat_cxl_vld_err[2] - D2H BE
// ras_stat_cxl_vld_err[3] - M2S DATA
// ras_stat_cxl_vld_err[4] - M2S BE
// ras_stat_cxl_vld_err[5] - S2M DATA
//
// CXL RX FIFO Pointer Read Error
// cxl_rx_fifo_ptr_err_i[0] - H2D REQ
//
// ----------------------------------------------------------------------------

`include "include/DWC_pcie_ctl_all_defs.svh"
`include "CXL/pkg/DWC_cxl_pkg.svh"

`include "CXL/svif/DWC_cxl_clk_rst_if.svh"

module DWC_cxl_mem_cache_ras 
    import DWC_cxl_pkg::*;
#(
    parameter TP = `TP
) (
    DWC_cxl_clk_rst_if.slave_mp             b_clk,                     // Clock and Reset interface
    input                                   cfg_dev_mode,              // Device Mode: 1 - Host, 0 - Device
    input                                   cfg_viral_enable,          // Viral Capability is Enabled
    input                                   cfg_viral_status,          // Viral Status bit in DVSEC Register
    input                                   cfg_pl_reg_viral_status,   // Viral Status bit in PL Register
    input [16:0]                            cfg_uncorr_error_mask,     // Uncorrectable Error Status Mask register
    input [16:0]                            cfg_uncorr_error_severity, // Uncorrectable Error Status Severity register 
    input [6:0]                             cfg_corr_error_mask,       // Correctable Error Status Mask register
    input                                   cfg_poison_enable,         // Poison Enabled
    input                                   cxl_lrsm_retry_hit,        // LRSM Retry Threshold Hit
    input                                   cxl_lrsm_reinit_hit,       // LRSM Reinit Threshold Hit
    input                                   cxl_lrsm_uc_err,           // LRSM Uncorrectable Error Flag
    input                                   cxl_lrsm_abort_state,      // LRSM FSM is in ABORT state
    input                                   cxl_ack_cnt_ovflw,         // Ack Counter Overflow
    input                                   cxl_rbuf_eseq_ovflw,       // Retry buffer ESEQ Overflow
    input                                   cxl_init_retry_error,      // Link Init Retryable Flit Error
    input                                   cxl_init_multi_error,      // Link Init Multiple Init.Param Error
    input                                   cxl_rx_ll_flit_error,      // Receiver LL Control Flit error
    input                                   cxl_rsvd_crd_enc_error,  // CXL Reserved Credit Encoding Error
    input [5:0]                             cxl_rx_ll_crdret_error,  // CXL Credit Return Overflow
    input                                   cxl_rx_retry_ack_viral,  // Retry.Ack flit is received with Viral Status
    input [7:0]                             cxl_rx_fifo_ovflw_i,     // Transmitter Channel Message FIFO Overflow
    input [7:0]                             cxl_tx_fifo_ovflw_i,     // Receiver Message FIFO Overflow
    input [CX_CXL_RX_TL_PTR_ERR_WD-1:0]     cxl_rx_fifo_ptr_err_i,   // Receiver Message FIFO pointer read error
    input                                   cxl_rx_mdh_error_i,      // RAS - Multi-Data Header received when MDH is disabled
    input                                   cxl_rx_crc_error_hit_i,  // RAS - CXL Receiver CRC Error thresold Hit 
    input                                   cxl_rx_rsvd_enc_error_i, // RAS - CXL Receiver Slot Reserved Fields Encoding Violation 
    input [511:0]                           cxl_rx_flit_data_i,      // RAS - CXL Receiver Data Flit

    input                                   cxl_rx_cache_poison_i,   // RAS - CXL.cache Poisoned Data Received
    input                                   cxl_rx_mem_poison_i,     // RAS - CXL.mem Poisoned Data Received
    input                                   cxl_viral_request,        // Viral Mode request from the Application
    // -------------------------------------------------------------------------------------
    // RASDP Interface
    // -------------------------------------------------------------------------------------
    input  [1:0]                            cxl_ras_stat_rx_corr,    // Correctable Error from RASDP Glue Logic
    input  [7:0]                            cxl_ras_stat_rx_uncorr,  // Uncorrectable Error from RASDP Glue Logic
    input  [CXL_RAS_HDR_LOG_SIZE-1:0]       cxl_ras_stat_rx_hdr_log, // Header Log from RASDP Glue Logic
    input  [CX_CXL_RX_TL_VALID_ERR_WD-1:0]  ras_stat_cxl_vld_err,    // CXL RX Valid Bit Error
    input  [CXL_TX_RAS_UNCORR_NUM-1:0]      ras_stat_cxl_tx_uncorr,  // RASDP Uncorrectable Errors on Tx Path
    input  [CXL_RX_RAS_UNCORR_NUM-1:0]      ras_stat_cxl_rx_uncorr,  // RASDP Uncorrectable Errors on Rx Path

    output [31:0]                           cfg_cxl_fatal_error_o,   // CXL Fatal Error Register
    output                                  cfg_viral_status_set_o,  // Set Viral Status bit in Device Register 
    output                                  cxl_viral_status_set_o,  // Trigger Viral Mode notification in CXL Controller
    output                                  cfg_pl_reg_viral_status_set_o,  // Set Viral Status bit in pl Register
    output [16:0]                           ras_uncorr_sts_o,        // Uncorrectable Error Status Register
    output [6:0]                            ras_corr_sts_o,          // Correctable Error Status Register
    output [511:0]                          ras_header_log_o         // RAS Header Log Register
);

logic [6:0]   corr_err_sts_r, corr_err_sts_nxt;     // Correctable Error Status Register
logic [16:0]  uncorr_err_sts_r, uncorr_err_sts_nxt; // Uncorrectable Error Status Register
logic [16:0]  cfg_uncorr_error_mask_n;              // Uncorrectable Error Status Mask register
logic [6:0]   cfg_corr_error_mask_n;                // Correctable Error Status Mask register
logic [16:0]  ras_uncorr_fatal_err_s;               // Uncorrectable Fatal Error (Uncorrectable error with the corresponding severity bit is set)
logic [511:0] ras_header_log_r, ras_header_log_nxt; // RAS Header Log Register
logic [31:0]  fatal_error_r, fatal_error_nxt;       // CXL Fatal Error Register
logic [7:0]   cxl_ras_stat_rx_uncorr_r;             // Register CXS RAS Interface inputs
logic [CXL_RAS_HDR_LOG_SIZE-1:0] cxl_ras_stat_rx_hdr_log_r; // Register Header Log from RASDP Glue Logic
logic         cxs_ull_viral_r, cxs_ull_viral_nxt; // CXS RX ENDERROR received to trigger Viral

//Uncorrectable Fatal Error (Uncorrectable error with the corresponding severity bit is set)
assign ras_uncorr_fatal_err_s = ras_uncorr_sts_o & cfg_uncorr_error_severity;

//Uncorrectable Error Status masking register
assign cfg_uncorr_error_mask_n = ~cfg_uncorr_error_mask;

//Correctable Error Status masking register
assign cfg_corr_error_mask_n = ~cfg_corr_error_mask;

//CXS uncorrectable and correcatble Error status after maskig

//Recieved ENDERROR triggers Viral but doesn't trigger uncorrectable fatal error, the INIT.VD RAS message received later should specify uncorrectable error state
assign cfg_viral_status_set_o = (!cfg_viral_status) & ((cfg_viral_enable  & (|ras_uncorr_fatal_err_s)) | cxs_ull_viral_r);

assign cfg_cxl_fatal_error_o = fatal_error_r;
//update pl reg viral notification when (viral enable and UIE) or (recieved viral from link partner) triggered
// Recieved ENDERROR triggers Viral but doesn't trigger uncorrectable fatal error, the INIT.VD RAS message received later should specify uncorrectable error state
assign cfg_pl_reg_viral_status_set_o = (!cfg_pl_reg_viral_status) & ((cfg_viral_enable && (|ras_uncorr_fatal_err_s)) | fatal_error_r[0] | cxs_ull_viral_r);
//Send Viral Notification to TX CXS through ENDERROR, except for the case when ENDERROR is already received from RX CXS
//Send viral notification when (viral enable and UIE) triggered
assign cxl_viral_status_set_o = (!cfg_viral_status) & ((cfg_viral_enable  & (|ras_uncorr_fatal_err_s)) | cxs_ull_viral_r);

assign ras_corr_sts_o   = corr_err_sts_r;
assign ras_uncorr_sts_o = uncorr_err_sts_r;
assign ras_header_log_o = ras_header_log_r;

always_comb begin
// Bit 0 (RW1CS) Cache_Data_ECC: Internal Data ECC error on CXL.cache.
// Bit 1 (RW1CS) Mem_Data_ECC: Internal Data ECC error on CXL.mem.
// Bit 2 (RW1CS) CRC_Threshold: CRC Threshold Hit
// Bit 3 (RW1CS) Retry_Threshold: Retry Threshold Hit
// Bit 4 (RW1CS) Cache_Poison_Received: Received Poison from the peer on CXL.cache.
// Bit 5 (RW1CS) Mem_Poison_Received: Received Poison from the peer on CXL.mem.
// Bit 6 (RW1CS) Physical_Layer_Error: Received error indication from Physical Layer
    corr_err_sts_nxt = corr_err_sts_r;

    corr_err_sts_nxt[0] = cxl_ras_stat_rx_corr[0] && cfg_corr_error_mask_n[0];
    corr_err_sts_nxt[1] = cxl_ras_stat_rx_corr[1] && cfg_corr_error_mask_n[1];
    corr_err_sts_nxt[2] = cxl_rx_crc_error_hit_i  && cfg_corr_error_mask_n[2];
    corr_err_sts_nxt[3] = cxl_lrsm_retry_hit && cfg_corr_error_mask_n[3];
    corr_err_sts_nxt[4] = cfg_poison_enable && cxl_rx_cache_poison_i && cfg_corr_error_mask_n[4]; // If poison bit set treat as Correctable Error
    corr_err_sts_nxt[5] = cfg_poison_enable && cxl_rx_mem_poison_i && cfg_corr_error_mask_n[5];  // If poison bit set treat as Correctable Error
end

always_comb begin
// Bit  0 (RW1CS) Cache_Data_Parity: Internal Data Parity error on CXL.cache. Header Log contains H2D Data Header.
// Bit  1 (RW1CS) Cache_Address _Parity: Internal Address Parity error on CXL.cache. Header Log contains H2D Data Header.
// Bit  2 (RW1CS) Cache_BE_Parity: Internal Byte Enable Parity error on CXL.cache. Header Log contains H2D Data Header.
// Bit  3 (RW1CS) Cache_Data_ECC: Internal Data ECC error on CXL.cache. Header Log contains H2D Data Header.
// Bit  4 (RW1CS) Mem_Data_Parity: Internal Data Parity error on CXL.mem. Header Log contains M2S RwD Data Header.
// Bit  5 (RW1CS) Mem_Address_Parity: Internal Address Parity error on CXL.mem. If Bit 0 of Header Log is '0, rest of Header Log
//                contains M2S Req. If Bit 0 of Header Log is '1, rest of Header Log contains M2S RwD Data Header.
// Bit  6 (RW1CS) Mem_BE_Parity: Internal Byte Enable Parity error on CXL.mem. Header Log contains M2S RwD Data Header.
// Bit  7 (RW1CS) Mem_Data_ECC: Internal Data ECC error on CXL.mem. Header Log contains M2S RwD Data Header.
// Bit  8 (RW1CS) REINIT_Threshold: REINIT Threshold Hit. Header Log not applicable.
// Bit  9 (RW1CS) Rsvd_Encoding_Violation: Received unrecognized encoding. Header Log contains the entire flit received.
// Bit 10 (RW1CS) Poison_Received: Received Poison from the peer. Header Log contains the entire flit received.
// Bit 11 (RW1CS) Receiver_Overflow: First 3b of the Header Log are relevant and should be interpreted as such:
//                3'b000 --> D2H Req
//                3'b001 --> D2H Rsp
//                3'b010 --> D2H Data
//                3'b100 --> S2M NDR
//                3'b101 --> S2M DRS
//                The above shows which buffer had the overflow
    uncorr_err_sts_nxt = uncorr_err_sts_r;
    uncorr_err_sts_nxt[0]  = cxl_ras_stat_rx_uncorr_r[0] && cfg_uncorr_error_mask_n[0];
    uncorr_err_sts_nxt[1]  = cxl_ras_stat_rx_uncorr_r[1] && cfg_uncorr_error_mask_n[1];
    uncorr_err_sts_nxt[2]  = cxl_ras_stat_rx_uncorr_r[2] && cfg_uncorr_error_mask_n[2];
    uncorr_err_sts_nxt[3]  = cxl_ras_stat_rx_uncorr_r[3] && cfg_uncorr_error_mask_n[3];

    uncorr_err_sts_nxt[4]  = cxl_ras_stat_rx_uncorr_r[4] && cfg_uncorr_error_mask_n[4];
    uncorr_err_sts_nxt[5]  = cxl_ras_stat_rx_uncorr_r[5] && cfg_uncorr_error_mask_n[5];
    uncorr_err_sts_nxt[6]  = cxl_ras_stat_rx_uncorr_r[6] && cfg_uncorr_error_mask_n[6];
    uncorr_err_sts_nxt[7]  = cxl_ras_stat_rx_uncorr_r[7] && cfg_uncorr_error_mask_n[7];


    uncorr_err_sts_nxt[8]  = cxl_lrsm_reinit_hit && cfg_uncorr_error_mask_n[8];
    uncorr_err_sts_nxt[9]  = cxl_rx_rsvd_enc_error_i && cfg_uncorr_error_mask_n[9];
    // If poison bit is not set treat poison detection as Uncorrectable Error
    uncorr_err_sts_nxt[10] = !cfg_poison_enable && (1'b0 || cxl_rx_cache_poison_i || cxl_rx_mem_poison_i) && cfg_uncorr_error_mask_n[10];
    uncorr_err_sts_nxt[11] = ((|cxl_rx_fifo_ovflw_i) || (|cxl_tx_fifo_ovflw_i)) && cfg_uncorr_error_mask_n[11];
    uncorr_err_sts_nxt[12] = 1'b0 && cfg_uncorr_error_mask_n[12]; // Reserved
    uncorr_err_sts_nxt[13] = 1'b0 && cfg_uncorr_error_mask_n[13]; // Reserved
    uncorr_err_sts_nxt[14] = (|cfg_cxl_fatal_error_o[31:2]) && cfg_uncorr_error_mask_n[14];
end

// RAS Header Log file based on the first detected error
always_comb begin
    ras_header_log_nxt = '0;

        casez (uncorr_err_sts_nxt)
            17'b?_????_????_????_???1, // Bit  0 (RW1CS) Cache_Data_Parity
            17'b?_????_????_????_??10, // Bit  1 (RW1CS) Cache_Address_Parity
            17'b?_????_????_????_?100, // Bit  2 (RW1CS) Cache_BE_Parity
            17'b?_????_????_????_1000, // Bit  3 (RW1CS) Cache_Data_ECC
            17'b?_????_????_???1_0000, // Bit  4 (RW1CS) Mem_Data_Parity
            17'b?_????_????_??10_0000, // Bit  5 (RW1CS) Mem_Address_Parity
            17'b?_????_????_?100_0000, // Bit  6 (RW1CS) Mem_BE_Parity
            17'b?_????_????_1000_0000: // Bit  7 (RW1CS) Mem_Data_ECC
            begin
                    ras_header_log_nxt = {{(512-CXL_RAS_HDR_LOG_SIZE){1'b0}}, cxl_ras_stat_rx_hdr_log_r};
            end
            17'b?_????_??10_0000_0000: begin // Bit  9 (RW1CS) Rsvd_Encoding_Violation
                ras_header_log_nxt = cxl_rx_flit_data_i;
            end
            17'b?_????_1000_0000_0000: begin
                casez (cxl_rx_fifo_ovflw_i)
                    8'b???????1: ras_header_log_nxt[2:0] = 3'b000; // D2H/H2D Request
                    8'b??????10: ras_header_log_nxt[2:0] = 3'b001; // D2H/H2D Response
                    8'b?????100: ras_header_log_nxt[2:0] = 3'b010; // D2H/H2D Data
                    8'b????1000: ras_header_log_nxt[2:0] = 3'b011; // S2M BI-Snoop/M2S Request
                    8'b???10000: ras_header_log_nxt[2:0] = 3'b100; // S2M Response/M2S BI-Response
                    8'b??100000: ras_header_log_nxt[2:0] = 3'b101; // S2M/M2S Data
                    8'b?1000000: ras_header_log_nxt[2:0] = 3'b110; // Reversed Protocol: S2M Response/M2S Request
                    8'b10000000: ras_header_log_nxt[2:0] = 3'b111; // Reversed Protocol: S2M/M2S Data
                    default    : ras_header_log_nxt[2:0] = 3'b111; // Transmitter Buffer Overflow
                endcase
                
                casez (cxl_tx_fifo_ovflw_i)
                    8'b???????1 : ras_header_log_nxt[5:3] = 3'b000; // D2H/H2D Request
                    8'b??????10 : ras_header_log_nxt[5:3] = 3'b001; // D2H/H2D Response
                    8'b????1000 : ras_header_log_nxt[5:3] = 3'b010; // D2H/H2D Data
                    8'b?????100 : ras_header_log_nxt[5:3] = 3'b011; // D2H/H2D Header
                    8'b???10000 : ras_header_log_nxt[5:3] = 3'b100; // S2M BI-Snoop/M2S Request
                    8'b??100000 : ras_header_log_nxt[5:3] = 3'b101; // S2M Response/M2S BI-Response
                    8'b10000000 : ras_header_log_nxt[5:3] = 3'b110; // S2M/M2S Data
                    8'b?1000000 : ras_header_log_nxt[5:3] = 3'b111; // S2M/M2S Header
                    default     : ras_header_log_nxt[5:3] = 3'b111; // Receiver Buffer Overflow
                endcase
            end
            default: ras_header_log_nxt = '0;
        endcase
end

always_comb begin
// Bit    0   (RO) Retry_Ack_Viral: Retry.Ack control flit is received with Viral status. Valid if Viral is enabled.
// Bit    1   (RO) N/A: Resereved
// Bit    2   (RO) LL_Static_Bit_Error: Static bit error is detected in the received LL Control Flit.
// Bit    3   (RO) LRSM_Abort: LRSM FSM reached Abort state.
// Bit    4   (RO) LRSM_Ack_Error: Unexpected Retry.Ack flit is received.
// Bit    5   (RO) RSVD_CRD_ENC_Error: CXL Reserved Credit Encoding Error.
// Bit    6   (RO) CXL_CXS_FIFO_Overflow: CXL CXS FIFO Overflow.
// Bit    7   (RO) RX_RASDP_Error: RASDP Uncorrectable Error is detected on Rx Path.
// Bit    8   (RO) N/A: Resereved
// Bit    9   (RO) N/A: Resereved
// Bit   10   (RO) LL_Init_Param_Error: Non-Retry flits received before LLCTRL-INIT.Param flit.
// Bit   11   (RO) LL_Multi_Init_Param: Receipt of an LLCTRL-INIT.Param flit after an LLCTRL-INIT.Param flit has already been received.
// Bit   12   (RO) Retry_Ack_Overflow: Acknowledge Counter Overflow.
// Bits 18-13 (RO) LL_RX_CreditReturn_Error: CXL Receiver Credit Returm Error:
//                   Bit 0 - Mem BI Credit Return Overflow
//                   Bit 1 - Cache Request Credit Return Overflow
//                   Bit 2 - Cache Response Credit Return Overflow
//                   Bit 3 - Cache Data Credit Return Overflow
//                   Bit 4 - Mem NDR/RequestOnly Credit Return Overflow
//                   Bit 5 - Mem DRC/RwD Credit Return Overflow
// Bit   19   (RO) N/A: Reserved
// Bit   20   (RO) N/A: Reserved
// Bit   21   (RO) App_Viral_Request: Set this bit if the Applications requests to trigger Viral Mode in CXL Controller.
// Bit   22   (RO) H2D_Ordering_Violation: H2D Response/Request ordering violation detected.
// Bit   23   (RO) TX_RASDP_Error: RASDP Uncorrectable Error is detected on Tx Path
// Bit   24   (RO) Cache_Data_Valid_Error: H2D/D2H Data Valid Error.
// Bit   25   (RO) Mem_Data_Valid_Error: M2S/S2M Data Valid Error.
// Bit   26   (RO) MDH_Error: Multi-Data Header is received when MDH is disabled.
// Bit   27   (RO) IDE_TX_SecureIF_Error: IDE TX Data Protection Error on Secure IF.
// Bit   28   (RO) IDE_TX_PlainIF_Error: IDE TX Data Protection Error on Plain IF.
// Bit   29   (RO) IDE_RX_SecureIF_Error: IDE RX Data Protection Error on Secure IF.
// Bit   30   (RO) IDE_RX_PlainIF_Error: IDE RX Data Protection Error on Plain IF.
    fatal_error_nxt        = fatal_error_r;

    fatal_error_nxt[0]     = cxl_rx_retry_ack_viral;
    fatal_error_nxt[1]     = '0;
    fatal_error_nxt[2]     = cxl_rx_ll_flit_error;
    fatal_error_nxt[3]     = cxl_lrsm_uc_err & cxl_lrsm_abort_state;
    fatal_error_nxt[4]     = cxl_lrsm_uc_err & ~cxl_lrsm_abort_state;
    fatal_error_nxt[5]     = cxl_rsvd_crd_enc_error;
    fatal_error_nxt[7]    = |ras_stat_cxl_rx_uncorr; //Ored logic of the RX uncorrectable errors 
    fatal_error_nxt[10]    = cxl_init_retry_error;
    fatal_error_nxt[11]    = cxl_init_multi_error;
    fatal_error_nxt[12]    = cxl_ack_cnt_ovflw;//cxl_rbuf_eseq_ovflw;
    // This is to preserve bits 18-14 as defined before in CXL 2.0
    fatal_error_nxt[13]    = cxl_rx_ll_crdret_error[5];
    fatal_error_nxt[18:14] = cxl_rx_ll_crdret_error[4:0];
    fatal_error_nxt[21]    = cxl_viral_request && cfg_viral_enable;
    fatal_error_nxt[22]    = cxl_rx_fifo_ptr_err_i[0];
    fatal_error_nxt[23]    = |ras_stat_cxl_tx_uncorr; //Ored logic of the TX uncorrectable errors 
    fatal_error_nxt[24]    = ras_stat_cxl_vld_err[0] || ras_stat_cxl_vld_err[1] || (cfg_dev_mode && ras_stat_cxl_vld_err[2]);
    fatal_error_nxt[25]    = ras_stat_cxl_vld_err[3] || ras_stat_cxl_vld_err[5] || (!cfg_dev_mode && ras_stat_cxl_vld_err[4]);
    fatal_error_nxt[26]    = cxl_rx_mdh_error_i;
end


// Recieving CXS ENDERROR should trigger Viral without updating Fatal Error Register
always_comb begin
  cxs_ull_viral_nxt = 1'b0;
end

always_ff @(posedge b_clk.s_core_clk or negedge b_clk.s_core_rst_n) begin
    if (!b_clk.s_core_rst_n) begin
        fatal_error_r             <= #TP '0;
        corr_err_sts_r            <= #TP '0;
        uncorr_err_sts_r          <= #TP '0;
        ras_header_log_r          <= #TP '0;
        cxs_ull_viral_r           <= #TP '0;
        cxl_ras_stat_rx_uncorr_r  <= #TP '0;
        cxl_ras_stat_rx_hdr_log_r <= #TP '0;
    end
    else begin
        fatal_error_r             <= #TP fatal_error_nxt;
        corr_err_sts_r            <= #TP corr_err_sts_nxt;
        uncorr_err_sts_r          <= #TP uncorr_err_sts_nxt;
        ras_header_log_r          <= #TP ras_header_log_nxt;
        cxs_ull_viral_r           <= #TP cxs_ull_viral_nxt;
        cxl_ras_stat_rx_uncorr_r  <= #TP cxl_ras_stat_rx_uncorr;
        cxl_ras_stat_rx_hdr_log_r <= #TP cxl_ras_stat_rx_hdr_log;
    end
end


endmodule
