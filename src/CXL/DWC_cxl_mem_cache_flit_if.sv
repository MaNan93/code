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
// ---   $DateTime: 2024/02/09 06:08:36 $
// ---   $Revision: #16 $
// ---   $Id: //dwh/pcie_iip/main/fairbanks/design/CXL/DWC_cxl_mem_cache_flit_if.sv#16 $
// -------------------------------------------------------------------------
// --- Module Description:
// ----------------------------------------------------------------------------
// CXL Link Layer Flit Interface
// Arbitrates link layer control flits
// Selects between flits from retry buffer or normal flits
// Back-pressures the flit packing logic when necessary
// ----------------------------------------------------------------------------

`include "include/DWC_pcie_ctl_all_defs.svh"
`include "CXL/pkg/DWC_cxl_pkg.svh"
`include "DWC_pcie_ctl_pkg.svh"

module DWC_cxl_mem_cache_flit_if
    import DWC_cxl_pkg::*;
#(
    parameter TP = `TP
) 
                                    (
// Inputs ------------------------------------------------------------------------------
    input                                         core_clk,
    input                                         core_rst_n,
    input                                         cxl_device_mode,            // 0 - Endpoint; 1 - Root Complex Device
    input                                         cxl_pcie_flit_mode,         // CXL 256B Flit Mode
    input                                         xplh_arbmux_ctrl_pending,   // XPLH ARB/MUX pending CXL.cachemem flit indication (remove after aligning to core data width)
    input                                         cxl_link_stall_req,         // Link vLSM: Transmit path stall request
    input                                         cfg_viral_status,           // Viral status indication
    input [1:0]                                   cfg_mc_crc_err_inj,         // CacheMemCRCInjection
    input [1:0]                                   cfg_mc_crc_err_inj_cnt,     // CacheMemCRCInjection Count
    input                                         cxl_retry_normal,           // LRSM and RRSM are in Normal state
    input                                         cxl_llctrl_flit_valid,      // LLCTRL Flit valid
    input                                         cxl_llctrl_flit_sof,        // LLCTRL Flit Start of Flit`
    input                                         cxl_llctrl_flit_eof,        // LLCTRL Flit End of Flit
    input [127:0]                                 cxl_llctrl_flit,            // LLCTRL Flit
    input [CXL_DATA_PROT_WD - 1 : 0]              cxl_llctrl_flit_chk,        // LLCTRL Flit Parity
    input                                         cxl_rbuf_retry_req,         // Retry Buffer is offloading
    input                                         cxl_rbuf_flit_valid,        // Flit from retry buffer
    input [CXL_DATA_WD-1 : 0]                     cxl_rbuf_flit,              // Flit from retry buffer
    input                                         cxl_packer_flit_valid,      // Packer valid indication
    input [CXL_DATA_WD-1 : 0]                     cxl_packer_flit,            // Flit from packer
    input [CXL_DATA_PROT_WD - 1 : 0]              cxl_packer_flit_chk,        // Flit Parity from packer
    input                                         cxl_packer_all_data,        // All data flit flag
    input                                         cxl_packer_flit_last,       // Last indication
    input                                         cxl_packer_llctrl_halt,     // Packer halt to LLCTRL flit
    input                                         cxl_packer_idle,            // Packer Idle state indication
    input                                         cxl_ll_init_done,           // Initialization done
    input                                         cxl_arb_mux_halt,           // Halt from arb/mux
    input [(RBUF_ADD_WD - 1) : 0]                 cxl_ll_numfreebuf,          // Free spaces in the retry buffer
    input [(ACK_CNT_WD - 1) : 0]                  cxl_ll_full_ack,            // Full Ack counter
    input                                         cxl_ll_flit_ack,            // Ack bit in outgoing flit
// Outputs -----------------------------------------------------------------------------
    output logic                                  cxl_link_stall_ack,         // Link vLSM: Transmit path stall acknowledge
    output logic                                  cxl_retryable_flit_ena,     // Enable retryable flit based on RBUF NumFreeBuf
    output logic                                  cxl_ll_idle,                // CXL LL Controller is in Idle state
    output logic                                  cfg_mc_crc_err_inj_busy,    // CacheMemCRCInjection Busy
    output logic [(CRD_RET_WD - 1) : 0]           cxl_cache_data_crd,         // TX Decode 68B - CXL.cache Data transmitted credit
    output logic [(CRD_RET_WD - 1) : 0]           cxl_cache_req_crd,          // TX Decode 68B - CXL.cache Request transmitted credit
    output logic [(CRD_RET_WD - 1) : 0]           cxl_cache_rsp_crd,          // TX Decode 68B - CXL.cache Response transmitted credit
    output logic [(CRD_RET_WD - 1) : 0]           cxl_mem_data_crd,           // TX Decode 68B - CXL.mem Data transmitted credit
    output logic [(CRD_RET_WD - 1) : 0]           cxl_mem_req_crd,            // TX Decode 68B - CXL.mem Request transmitted credit
    output logic [(CRD_RET_WD - 1) : 0]           cxl_mem_rsp_crd,            // TX Decode 68B - CXL.mem Response transmitted credit
    output CRD_256B_t                             cxl_256B_tx_crdret,         // TX Decode 256B - transmitted 2B CRD field
    output logic                                  cxl_viral_llcrd_req,        // LLCRD Flit Insertion request in Viral state
    output logic                                  cxl_fgen_ack_timer_rst,     // Reset Acknowledge Flash Time
    output logic [(ACK_CNT_WD - 1) : 0]           cxl_fgen_full_ack,          // full ack field
    output logic                                  cxl_fgen_retryable_valid,   // retryable flit
    output logic [CXL_DATA_WD-1 : 0]              cxl_fgen_retryable_flit,    // retryable flit

    output logic                                  cxl_fgen_flit_valid,        // ARB/MUX IF - CXL Flit valid
    output logic                                  cxl_fgen_flit_sof,          // ARB/MUX IF - CXL Flit SOF Marker
    output logic                                  cxl_fgen_flit_eof,          // ARB/MUX IF - CXL Flit EOF Marker
    output logic                                  cxl_fgen_flit_enf,          // ARB/MUX IF - CXL Flit ENF Marker
    output logic                                  cxl_fgen_flit_retry,        // ARB/MUX IF - CXL Flit is replayed from Retry Buffer
    output logic [ARBMUX_FLIT_WD-1 : 0]           cxl_fgen_flit,              // ARB/MUX IF - CXL Flit data
    output logic                                  cxl_fgen_flit_err,          // ARB/MUX IF - CXL viral request in 256B mode
    output logic [CXL_DATA_PROT_WD - 1:0]         cxl_fgen_flit_chk,          // ARB/MUX IF - CXL Flit parity
    output logic                                  cxl_fgen_flit_lp_pri,       // ARB/MUX IF - LPIF priority, active high in flit_if, link_ctrl will invert to active low for SPIF_IF
    output logic [4:0]                            cxl_fgen_packer_data_en,    // Flit Packe Data Header Enable
    output logic                                  cxl_fgen_packer_halt,       // halt the packer
    output logic                                  cxl_fgen_llctrl_halt,       // LLCTRL Flit Halt
    output logic                                  cxl_fgen_rbuf_halt          // RBUF Flit Halt
);

// Declarations
logic                             cxl_viral_status_nxt;        // Viral Status next state
logic                             cxl_viral_status_r;          // Viral Status register
// Flit Interface MUX output signals
logic                             cxl_mux_flit_valid;          // Indicates that flit is valid on mux output
logic [CXL_DATA_WD-1:0]           cxl_mux_flit;                // Either Protocol or LLCTRL flit
logic [ARBMUX_FLIT_WD-1:0]        cxl_mux_flit_s;              // CXL flit data (data+crc for 68B Mode, or only data for 256B Mode)
logic [15:0]                      cxl_mux_flit_crc;            // CXL flit data protection code
logic [CXL_DATA_PROT_WD-1:0]      cxl_mux_flit_chk;            // Either Protocol or LLCTRL flit protection
logic [CXL_DATA_PROT_WD-1:0]      cxl_mux_flit_chk_s;          // Either Protocol or LLCTRL flit protection (data+crc for 68B Mode, or only data for 256B Mode)
logic                             cxl_mux_retry;               // Indicates that valid flit is a RETRY LLCTRL flit
logic                             cxl_mux_prot_flit;           // Indicates whether Protocol or LLCTRL flit is selected
logic                             cxl_mux_all_data;            // Indicates ADF flit
logic                             cxl_mux_last;                // Indicates LAST flit in the sequence
logic                             cxl_mux_rbuf_flit;           // Indicates that flit is replayed from Retry Buffer
logic                             cxl_mux_flit_err;            // Used for tagging flit where viral condition occured
logic                             cxl_mux_pri;                 // Indicates priority
// Flit Interface FIFO Control Signals
logic                             flit_fifo_we_s;              // Flit Interface FIFO - Write Enable
logic                             flit_fifo_re_s;              // Flit Interface FIFO - Read Enable
logic                             flit_fifo_full_s;            // Flit Interface FIFO - Full indication
logic                             flit_fifo_block_s;           // Flit Interface FIFO - Block any new messages on the FIFO inputs
logic                             flit_fifo_empty_s;           // Flit Interface FIFO - Empty indication
logic [FLIT_IF_FIFO_WD-1:0]       flit_fifo_din_s;             // Flit Interface FIFO - Data Input
logic [FLIT_IF_FIFO_WD-1:0]       flit_fifo_dout_s;            // Flit Interface FIFO - Data Output
// Flit Interface FIFO Output Signals (same as MUX output)
logic                             flit_fifo_valid_s;           // CXL Flit valid
logic [ARBMUX_FLIT_WD-1:0]        flit_fifo_data_s;            // CXL Flit data
logic [ARBMUX_FLIT_WD-1:0]        flit_fifo_data_err_s;        // CXL Flit with corrupted data (CRC error)
logic                             flit_fifo_retry_s;           // Indicates that valid flit is a RETRY LLCTRL flit
logic                             flit_fifo_prot_s;            // Indicates whether Protocol or LLCTRL flit is selected
logic                             flit_fifo_all_data_s;        // Indicates ADF flit
logic                             flit_fifo_last_s;            // Indicates LAST flit in the sequence
logic                             flit_fifo_rbuf_s;            // Indicates that flit is replayed from Retry Buffer
logic                             flit_fifo_cntr_inc_s;        // Increment Flit FIFO counter when retryable flit is pushed into the FIFO
logic                             flit_fifo_cntr_dec_s;        // Decrement Flit FIFO counter when retryable flit is poped from the FIFO
logic [FLIT_IF_FIFO_CNT_WD-1:0]   flit_fifo_cntr_nxt;          // Retryable flits counter in the Flit FIFO - next state
logic [FLIT_IF_FIFO_CNT_WD-1:0]   flit_fifo_cntr_r;            // Retryable flits counter in the Flit FIFO - register
logic [FLIT_IF_FIFO_CNT_WD-1:0]   flit_fifo_prot_nxt;          // Number of protocol flits in the Flit FIFO - next state
logic [FLIT_IF_FIFO_CNT_WD-1:0]   flit_fifo_prot_r;            // Number of protocol flits in the Flit FIFO - register
logic                             flit_fifo_flit_err;          // Error tag for viral
logic                             flit_fifo_pri;               // priority
logic                             cxl_fgen_retryable_valid_s;
// NumFreeBuf Adjastement Signals
logic                             cxl_ll_numfreebuf_ovflw_s;    // Free spaces in the retry buffer (overflow)
logic [(RBUF_ADD_WD - 1) : 0]     cxl_ll_numfreebuf_s;          // Free spaces in the retry buffer
logic                             cxl_link_stall_req_s;

logic                             cxl_mux_256B_flit_valid;      // cxl_mux_256 between llctrl and packer flit
logic                             cxl_mux_256B_last;
logic                             cxl_mux_256B_all_data;
logic [CXL_DATA_WD-1 : 0]         cxl_mux_256B_flit;
logic [CXL_DATA_PROT_WD-1:0]      cxl_mux_256B_flit_chk;
logic                             cxl_vir_flitreg_en;           // viral flit_reg flits enabled to send downstream
logic                             cxl_vir_flitreg_valid;        // viral flit_reg valid
logic                             cxl_vir_flitreg_last;
logic                             cxl_vir_flitreg_all_data;
logic [CXL_DATA_WD-1 : 0]         cxl_vir_flitreg_data;
logic [CXL_DATA_PROT_WD-1:0]      cxl_vir_flitreg_data_chk;
logic                             cxl_vir_flit0_eof;            // marks eof of current flit0 where the viral happened, added to fifo
logic                             cxl_vir_flitreg_pri;
logic                             cxl_vir_flitreg_halt;         // halt upstream while flit_reg is resending flit0
logic                             cxl_vir_inprogress;
logic [CXL_DATA_PROT_WD-1:0]      cxl_fgen_flit_chk_s;          // ARB/MUX Internal CXL Flit parity
logic [CXL_DATA_WD-1 : 0]         cxl_packer_flit_s;


// Enable retryable flit (protocol or LLCRD) when there is enough space in the Retry Buffer
assign cxl_retryable_flit_ena     = (cxl_ll_numfreebuf_s == 2) ? (|cxl_ll_full_ack) & !(cxl_mux_prot_flit & cxl_mux_flit_valid) : (cxl_ll_numfreebuf_s > 2);

// LLCTRL Flit Halt
assign cxl_fgen_llctrl_halt       = flit_fifo_block_s || cxl_packer_llctrl_halt || cxl_vir_flitreg_halt;
// RBUF Flit Halt  
assign cxl_fgen_rbuf_halt         = flit_fifo_block_s;
// ARB/MUX Interface Flit  
assign cxl_fgen_flit_valid        = cxl_pcie_flit_mode ? flit_fifo_valid_s                : flit_fifo_valid_s;
assign cxl_fgen_flit_sof          = cxl_pcie_flit_mode ? !flit_fifo_all_data_s            : flit_fifo_valid_s;
assign cxl_fgen_flit_eof          = cxl_pcie_flit_mode ? flit_fifo_last_s                 : flit_fifo_valid_s;
assign cxl_fgen_flit_enf          = 1'b0;
assign cxl_fgen_flit              = cxl_pcie_flit_mode ? flit_fifo_data_s                 : flit_fifo_data_err_s;
assign cxl_fgen_flit_chk          = cxl_fgen_flit_chk_s;
assign cxl_fgen_flit_retry        = cxl_pcie_flit_mode ? 1'b0                             : flit_fifo_rbuf_s;
assign cxl_fgen_flit_lp_pri       = cxl_pcie_flit_mode ? (flit_fifo_pri && flit_fifo_valid_s) : 1'b0;
assign cxl_fgen_flit_err          = cxl_pcie_flit_mode ? (flit_fifo_flit_err && flit_fifo_re_s && cxl_fgen_retryable_valid_s) : 1'b0;
// RBUF Interface Flit
assign cxl_fgen_retryable_valid_s = flit_fifo_valid_s && !flit_fifo_retry_s && !flit_fifo_rbuf_s && !cxl_arb_mux_halt;
assign cxl_fgen_retryable_valid   = cxl_pcie_flit_mode ? 1'b0                             : cxl_fgen_retryable_valid_s;
assign cxl_fgen_retryable_flit    = flit_fifo_data_s[CXL_DATA_WD-1:0];
// Overwrite Flit type of the hdr in 256B flit mode
assign cxl_packer_flit_s          = cxl_packer_flit;


// -------------------------------------------------------------------------------------
// Viral Mode Detection
// -------------------------------------------------------------------------------------
always_comb begin
    // Viral Status Detected, enable CRC error injection in the next flit
    if (cfg_viral_status && !cxl_viral_status_r)
        cxl_viral_status_nxt = 1'b1;
    // Exit from Viral Mode when CRC error is injected
    else if (cxl_viral_status_r && flit_fifo_re_s && cxl_fgen_retryable_valid_s)
        cxl_viral_status_nxt = 1'b0;
    else
        cxl_viral_status_nxt = cxl_viral_status_r;
end

always_ff @(posedge core_clk or negedge core_rst_n) begin
    if(!core_rst_n) begin
        cxl_viral_status_r  <= # TP 1'b0;
    end else begin
        cxl_viral_status_r  <= # TP cxl_viral_status_nxt;
    end
end
// -------------------------------------------------------------------------------------

// If there is no traffic to send, the transmitter requests LLCRD flit to insert CRC error.
assign cxl_viral_llcrd_req = cxl_pcie_flit_mode? 1'b0 : (cxl_viral_status_r && !cxl_fgen_retryable_valid_s);


// -------------------------------------------------------------------------------------
// CXL.Cache/Mem CRC Error Injection Mode
// -------------------------------------------------------------------------------------
logic       cxl_mc_crc_err_inj_en_r, cxl_mc_crc_err_inj_en_s;       // Enable CRC Error Injection
logic [1:0] cxl_mc_crc_err_inj_cnt_r, cxl_mc_crc_err_inj_cnt_nxt;   // CRC Error Injection Counter
logic [2:0] cxl_crc_err_inj_mask;                                   // CRC Error Injection Mask 
logic [2:0] cxl_crc_err_inj_bits;                                   // CRC Error Injection Bits

assign cxl_mc_crc_err_inj_en_s = |cfg_mc_crc_err_inj;
assign cfg_mc_crc_err_inj_busy = cxl_mc_crc_err_inj_en_r & (|cxl_mc_crc_err_inj_cnt_r);
assign cxl_crc_err_inj_bits    = cxl_crc_err_inj_mask & {3{flit_fifo_prot_s}};

always_comb begin
    if (cxl_mc_crc_err_inj_en_s && !cxl_mc_crc_err_inj_en_r) begin
        cxl_mc_crc_err_inj_cnt_nxt = cfg_mc_crc_err_inj_cnt;
    end
    else if (cxl_mc_crc_err_inj_en_r && flit_fifo_re_s && flit_fifo_prot_s && (|cxl_mc_crc_err_inj_cnt_r)) begin
        cxl_mc_crc_err_inj_cnt_nxt = cxl_mc_crc_err_inj_cnt_r - 'd1;
    end
    else begin
        cxl_mc_crc_err_inj_cnt_nxt = cxl_mc_crc_err_inj_cnt_r;
    end
end

always_comb begin
    if (cfg_mc_crc_err_inj_busy) begin
        case (cfg_mc_crc_err_inj)
            2'b01  : cxl_crc_err_inj_mask = 3'b001; // Single bit flipped in the CRC field
            2'b10  : cxl_crc_err_inj_mask = 3'b011; // 2 bits flipped in the CRC field
            2'b11  : cxl_crc_err_inj_mask = 3'b111; // 3 bits flipped in the CRC field
            default: cxl_crc_err_inj_mask = 3'b000; // Disable. No CRC errors are injected
        endcase
    end
    else cxl_crc_err_inj_mask = 3'b000;
end

always_ff @(posedge core_clk or negedge core_rst_n) begin
    if(!core_rst_n) begin
        cxl_mc_crc_err_inj_en_r   <= # TP 1'b0;
        cxl_mc_crc_err_inj_cnt_r  <= # TP '0;
    end else begin
        cxl_mc_crc_err_inj_en_r   <= # TP cxl_mc_crc_err_inj_en_s;
        cxl_mc_crc_err_inj_cnt_r  <= # TP cxl_mc_crc_err_inj_cnt_nxt;
    end
end
// -------------------------------------------------------------------------------------


// -------------------------------------------------------------------------------------
// Generate Flit Packer control signals
// -------------------------------------------------------------------------------------
// Back-Pressure the Flit Packer when
// 1) Shallow FIFO is full
// 2) Link Initialization is not complete
// 3) Num of free elements in the Retry Buffer is 1
// 4) Num of free elements in the Retry Buffer is 2 and Acknowledge bit is not set in the flit header
// 5) When both LRSM and RRSM are not in NORMAL state
// 6) When LLCRD flit is pending and flit is not ADF flit
// 7) When IDE is enabled Controller never knows how many flits are accumulated in the IDE Core.
//    We must assume worst case scenario and halt IDE Secure IF if less than 8 flits remained in the Retry Buffer
assign cxl_fgen_packer_halt = cxl_pcie_flit_mode ? (flit_fifo_block_s || cxl_llctrl_flit_valid || !cxl_ll_init_done || cxl_vir_flitreg_halt) :
                               ( flit_fifo_block_s || (cxl_packer_llctrl_halt ? 1'b0 : (cxl_llctrl_flit_valid || !cxl_retry_normal)) || !cxl_ll_init_done 
 || (cxl_ll_numfreebuf_s < 2) || ((cxl_ll_numfreebuf_s == 2) && !cxl_ll_flit_ack)
 
                               );

// Adjust number of free elements in RBUF with a number of retryable flits captured in the Shallow FIFO
assign {cxl_ll_numfreebuf_ovflw_s, cxl_ll_numfreebuf_s} = ({1'b0, cxl_ll_numfreebuf} - flit_fifo_cntr_r);

always_comb begin
    cxl_fgen_packer_data_en = 5'b00000;

    if (cxl_ll_numfreebuf_s > 3) begin
        case (cxl_ll_numfreebuf_s)
            'd4: cxl_fgen_packer_data_en = 5'b00001;
            'd5: cxl_fgen_packer_data_en = 5'b00011;
            'd6: cxl_fgen_packer_data_en = 5'b00111;
            'd7: cxl_fgen_packer_data_en = 5'b01111;
            default: cxl_fgen_packer_data_en = 5'b11111;
        endcase
    end
end
// -------------------------------------------------------------------------------------

// -------------------------------------------------------------------------------------
// viral flit reg - replay flit0, after viral happened in current flit
// -------------------------------------------------------------------------------------
assign cxl_mux_256B_flit_valid = cxl_llctrl_flit_valid? 1'b1                      : cxl_packer_flit_valid;
assign cxl_mux_256B_flit       = cxl_llctrl_flit_valid? {{(CXL_DATA_WD-128){1'b0}}, cxl_llctrl_flit} : cxl_packer_flit_s;
assign cxl_mux_256B_flit_chk   = cxl_llctrl_flit_valid? cxl_llctrl_flit_chk       : cxl_packer_flit_chk;
assign cxl_mux_256B_all_data   = cxl_llctrl_flit_valid? !cxl_llctrl_flit_sof      : cxl_packer_all_data;
assign cxl_mux_256B_last       = cxl_llctrl_flit_valid? cxl_llctrl_flit_eof       : cxl_packer_flit_last;

DWC_cxl_mem_cache_viral_flit_reg
 #(
  .P_DW                 ( CXL_DATA_WD )
) u_viral_flit_reg (
  .core_clk             ( core_clk                     ),
  .core_rst_n           ( core_rst_n                   ),
  .cxl_viral_req        ( cfg_viral_status             ),
  .halt_in              ( flit_fifo_block_s            ),
  .flit_in_valid        ( cxl_mux_256B_flit_valid      ),
  .flit_in_last         ( cxl_mux_256B_last            ),
  .flit_in_inprogr      ( cxl_mux_256B_all_data        ),
  .flit_in_data         ( cxl_mux_256B_flit            ),
  .flit_in_data_chk     ( cxl_mux_256B_flit_chk        ),
  // outputs
  .halt_o               ( cxl_vir_flitreg_halt         ),
  .vir_inprogress_o     ( cxl_vir_inprogress           ),
  .flit_o_en            ( cxl_vir_flitreg_en           ),
  .flit_o_valid         ( cxl_vir_flitreg_valid        ),
  .flit_o_last          ( cxl_vir_flitreg_last         ),
  .flit_o_inprogr       ( cxl_vir_flitreg_all_data     ),
  .flit_o_data          ( cxl_vir_flitreg_data         ),
  .flit_o_data_chk      ( cxl_vir_flitreg_data_chk     ),
  .flit_o_err           ( cxl_vir_flit0_eof            ),
  .flit_o_pri           ( cxl_vir_flitreg_pri          )
);

// -------------------------------------------------------------------------------------
// Flit mux - selects either flits from retry buffer, or control flits, or protocol flits
// -------------------------------------------------------------------------------------
always_comb begin : flit_mux_proc
    // Block 68B Flit datapath in 256B Flit Mode
    if (cxl_pcie_flit_mode) begin
        if (cxl_vir_flitreg_en) begin
            cxl_mux_flit_valid = cxl_vir_flitreg_valid;
            cxl_mux_flit       = cxl_vir_flitreg_data;
            cxl_mux_flit_chk   = cxl_vir_flitreg_data_chk;
            cxl_mux_retry      = 1'b0;
            cxl_mux_prot_flit  = 1'b1;
            cxl_mux_all_data   = cxl_vir_flitreg_all_data;
            cxl_mux_last       = cxl_vir_flitreg_last;
            cxl_mux_rbuf_flit  = 1'b0;
            cxl_mux_flit_err   = cxl_vir_flit0_eof;
            cxl_mux_pri        = 1'b1;
        end
        else if (cxl_llctrl_flit_valid) begin
            cxl_mux_flit_valid = 1'b1;
            cxl_mux_flit       = {{(CXL_DATA_WD-128){1'b0}}, cxl_llctrl_flit};
            cxl_mux_flit_chk   = cxl_llctrl_flit_chk;
            cxl_mux_retry      = 1'b0;
            cxl_mux_prot_flit  = 1'b1;
            cxl_mux_all_data   = !cxl_llctrl_flit_sof;
            cxl_mux_last       = cxl_llctrl_flit_eof;
            cxl_mux_rbuf_flit  = 1'b0;
            cxl_mux_flit_err   = cxl_vir_flit0_eof;
            cxl_mux_pri        = cxl_vir_flitreg_pri;
        end
        else 
        begin
            cxl_mux_flit_valid = cxl_packer_flit_valid;
            cxl_mux_flit       = cxl_packer_flit_s;
            cxl_mux_flit_chk   = cxl_packer_flit_chk;
            cxl_mux_retry      = 1'b0;
            cxl_mux_prot_flit  = 1'b1;
            cxl_mux_all_data   = cxl_packer_all_data;
            cxl_mux_last       = cxl_packer_flit_last;
            cxl_mux_rbuf_flit  = 1'b0;
            cxl_mux_flit_err   = cxl_vir_flit0_eof;
            cxl_mux_pri        = cxl_vir_flitreg_pri;
        end
    end
    else
    // For 68B Flit datapath, there's no protection 
    // If RRSM is replaying flits from Retry Buffer
    // then give priority to RBUF interface
    if (cxl_rbuf_retry_req) begin
        cxl_mux_flit_valid = cxl_rbuf_flit_valid;
        cxl_mux_flit       = {{(CXL_DATA_WD-512){1'b0}},cxl_rbuf_flit};
        cxl_mux_flit_chk   = '0;
        cxl_mux_retry      = 1'b0;
        cxl_mux_prot_flit  = 1'b0;
        cxl_mux_all_data   = 1'b0;
        cxl_mux_last       = 1'b1;
        cxl_mux_rbuf_flit  = 1'b1;
        cxl_mux_flit_err   = 1'b0;
        cxl_mux_pri        = 1'b0;
    end
    else
    // If there is a valid Link Control flit pending
    // then give priority to LLCTRL interface
    if (cxl_llctrl_flit_valid && !cxl_fgen_llctrl_halt) begin
        cxl_mux_flit_valid = cxl_llctrl_flit_valid;
        cxl_mux_flit       = {{(CXL_DATA_WD-128){1'b0}}, cxl_llctrl_flit[127:0]};
        cxl_mux_flit_chk   = '0;
        cxl_mux_retry      = cxl_llctrl_flit[35:32] == RETRY;
        cxl_mux_prot_flit  = 1'b0;
        cxl_mux_all_data   = 1'b0;
        cxl_mux_last       = 1'b1;
        cxl_mux_rbuf_flit  = 1'b0;
        cxl_mux_flit_err   = 1'b0;
        cxl_mux_pri        = 1'b0;
    end
    // Otherwise give priority to Flit Packer Interface
    else begin
        cxl_mux_flit_valid = cxl_packer_flit_valid && !cxl_fgen_packer_halt;
        cxl_mux_flit       = cxl_packer_flit_s;
        cxl_mux_flit_chk   = '0;
        cxl_mux_retry      = 1'b0;
        cxl_mux_prot_flit  = 1'b1;
        cxl_mux_all_data   = cxl_packer_all_data;
        cxl_mux_last       = cxl_packer_flit_last;
        cxl_mux_rbuf_flit  = 1'b0;
        cxl_mux_flit_err   = 1'b0;
        cxl_mux_pri        = 1'b0;
    end
end : flit_mux_proc
// -------------------------------------------------------------------------------------


// -------------------------------------------------------------------------------------
// Instantiation of output flit CRC generator
DWC_cxl_mem_cache_crc
 u_flit_ecc_gen (
    .cxl_flit_data_i (cxl_mux_flit[ARBMUX_68B_DATA_WD-1:0]),
    .cxl_crc_data_o  (cxl_mux_flit_crc)
);
// -------------------------------------------------------------------------------------


// -------------------------------------------------------------------------------------
// Instantiate FIFO controller
// -------------------------------------------------------------------------------------
// Block new messages to be captured into the FIFO on entry to the Recovery or Hot-Reset/Link Disable or when VLSM is not in Active state
assign flit_fifo_block_s = flit_fifo_full_s || cxl_link_stall_req_s;
assign flit_fifo_we_s    = cxl_mux_flit_valid && !flit_fifo_block_s;
// Flush the FIFO on entry to Link Disable or Hot-Reset even if ARB/MUX halt is asserted
assign flit_fifo_re_s    = !cxl_arb_mux_halt && !flit_fifo_empty_s ;
assign flit_fifo_valid_s = !flit_fifo_empty_s ;

assign cxl_mux_flit_s     = {{(ARBMUX_FLIT_WD - ARBMUX_68B_FLIT_WD){1'b0}},cxl_mux_flit_crc, cxl_mux_flit[ARBMUX_68B_DATA_WD-1:0]};
assign cxl_mux_flit_chk_s = (cxl_pcie_flit_mode)? {{(ARBMUX_FLIT_PROT_WD - ARBMUX_DATA_PROT_WD){1'b1}},cxl_mux_flit_chk} : {{(ARBMUX_FLIT_PROT_WD - ARBMUX_68B_DATA_PROT_WD){1'b1}}, cxl_mux_flit_chk[ARBMUX_68B_DATA_PROT_WD-1:0]};


assign flit_fifo_din_s = {cxl_mux_pri, cxl_mux_flit_err, cxl_mux_rbuf_flit, cxl_mux_last, cxl_mux_all_data, cxl_mux_retry, cxl_mux_prot_flit, cxl_mux_flit_s , cxl_mux_flit_chk_s}; 
assign {flit_fifo_pri, flit_fifo_flit_err, flit_fifo_rbuf_s, flit_fifo_last_s, flit_fifo_all_data_s, flit_fifo_retry_s, flit_fifo_prot_s, flit_fifo_data_s , cxl_fgen_flit_chk_s} = flit_fifo_dout_s;
assign flit_fifo_data_err_s = {{(ARBMUX_FLIT_WD-ARBMUX_68B_FLIT_WD){1'b0}},flit_fifo_data_s[ARBMUX_68B_FLIT_WD-1:ARBMUX_68B_FLIT_WD-3] ^ ({~flit_fifo_retry_s & cxl_viral_status_r, 2'b00} | (flit_fifo_prot_s ? cxl_crc_err_inj_bits : 3'b000)), flit_fifo_data_s[ARBMUX_68B_FLIT_WD-4:0]}; 

DWC_pcie_ctl_bcm65_td
 #(
    .WIDTH            ( FLIT_IF_FIFO_WD         ),
    .DEPTH            ( FLIT_IF_FIFO_DEPTH      ),
    .ADDR_WIDTH       ( FLIT_IF_FIFO_LOG2       ),
    .AE_LEVEL         ( 1                       ),
    .AF_LEVEL         ( 1                       ),
    .ERR_MODE         ( 0                       ),
    .RST_MODE         ( 0                       ),
    .REG_DELAY_TIME   ( 1                       ),
    .REG_DELAY_DENOM  ( 10                      )
) u_flit_fifo (
    .clk              ( core_clk                ),
    .rst_n            ( core_rst_n              ),
    .init_n           ( 1'b1                    ),
    .push_req_n       ( ~flit_fifo_we_s         ),
    .pop_req_n        ( ~flit_fifo_re_s         ),
    .diag_n           ( 1'b1                    ),
    .data_in          ( flit_fifo_din_s         ),
    .empty            ( flit_fifo_empty_s       ),
    .almost_empty     (                         ),
    .half_full        (                         ),
    .almost_full      (                         ),
    .full             ( flit_fifo_full_s        ),
    .error            (                         ),
    .data_out         ( flit_fifo_dout_s        )
);

// Retryable Flits Counter in the FIFO
assign flit_fifo_cntr_inc_s = flit_fifo_we_s && !cxl_mux_rbuf_flit && (!cxl_mux_retry || cxl_mux_all_data);
assign flit_fifo_cntr_dec_s = flit_fifo_re_s && !flit_fifo_rbuf_s && (!flit_fifo_retry_s || flit_fifo_all_data_s);

// Count number of retryable flits in the Flit FIFO to adjust Num_Free_Buf
always_comb begin
    if (cxl_pcie_flit_mode) // Disable the counter in 256B Flit Mode
        flit_fifo_cntr_nxt = '0;
    else
    if (flit_fifo_cntr_inc_s && !flit_fifo_cntr_dec_s)
        flit_fifo_cntr_nxt = flit_fifo_cntr_r + 'd1;
    else if (!flit_fifo_cntr_inc_s && flit_fifo_cntr_dec_s)
        flit_fifo_cntr_nxt = flit_fifo_cntr_r - 'd1;
    else
        flit_fifo_cntr_nxt = flit_fifo_cntr_r;
end

always_ff @(posedge core_clk or negedge core_rst_n) begin
    if(!core_rst_n) begin
        flit_fifo_cntr_r <= # TP '0;
    end else begin
        flit_fifo_cntr_r <= # TP flit_fifo_cntr_nxt;
    end
end

// Count number of protocol flits in the Flit FIFO
always_comb begin
    if ((flit_fifo_we_s && cxl_mux_prot_flit) && !(flit_fifo_re_s && flit_fifo_prot_s))
        flit_fifo_prot_nxt = flit_fifo_prot_r + 'd1;
    else if (!(flit_fifo_we_s && cxl_mux_prot_flit) && (flit_fifo_re_s && flit_fifo_prot_s))
        flit_fifo_prot_nxt = flit_fifo_prot_r - 'd1;
    else
        flit_fifo_prot_nxt = flit_fifo_prot_r;
end

always_ff @(posedge core_clk or negedge core_rst_n) begin
    if(!core_rst_n) begin
        flit_fifo_prot_r <= # TP '0;
    end else begin
        flit_fifo_prot_r <= # TP flit_fifo_prot_nxt;
    end
end
// -------------------------------------------------------------------------------------


// -------------------------------------------------------------------------------------
// Decode transmit flit to extract Credit Return fields when capturing a flit in the
// output FIFO. When IDE is enabled, the Credit Return fields are extracted on the
// IDE plain interface for the protocol flits (before encryption). Otherwise the flit is
// decoded on the output of the Flit Interface MUX.
// -------------------------------------------------------------------------------------
logic          cxl_hdr_flit_valid;
logic [127:0]  cxl_hdr_flit;
logic          cxl_hdr_all_data;
logic          cxl_hdr_flit_halt;

//TODO Handel CRD with IDE for 256B case
always_comb begin
    // If valid flit on the Flit Interface MUX that is not replayed from Retry Buffer then
    // decode the flit. If IDE is enabled, decode only Link Control flits.
    //In case of 256B flit mode the CRD info alwyas @ last slot
    // We need to ignore the CRD in case cxl_mux_flit_err is asserted as this flit will be dropped by the packet layer
    cxl_hdr_flit_valid = (cxl_pcie_flit_mode)?  cxl_mux_flit_valid & cxl_mux_last & (!cxl_mux_flit_err) :
                        (cxl_mux_flit_valid && !cxl_mux_rbuf_flit) ;
    // In case of 256B flit mode the credit is in the last slot
    cxl_hdr_flit       = (cxl_pcie_flit_mode)?  cxl_mux_flit[(128*(FLIT_SLOT_NUM-1)) +: 128] : cxl_mux_flit[127:0];
    cxl_hdr_all_data   = (cxl_pcie_flit_mode)? 1'b0 : cxl_mux_all_data;
    cxl_hdr_flit_halt  = flit_fifo_block_s;

end


DWC_cxl_mem_cache_tx_decode
 u_tx_decode (
    .cxl_device_mode          ( cxl_device_mode        ),
    .cxl_flit_valid           ( cxl_hdr_flit_valid     ),
    .cxl_flit_data            ( cxl_hdr_flit[127:0]    ),
    .cxl_flit_all_data        ( cxl_hdr_all_data       ),
    .cxl_flit_halt            ( cxl_hdr_flit_halt      ),
    .cxl_pcie_flit_mode       ( cxl_pcie_flit_mode     ),
    .cxl_256B_tx_crdret       ( cxl_256B_tx_crdret     ),
    .cxl_ack_timer_rst        ( cxl_fgen_ack_timer_rst ),
    .cxl_full_ack             ( cxl_fgen_full_ack      )
    // Outputs
    ,
    .cxl_cache_data_crd       ( cxl_cache_data_crd     ),
    .cxl_cache_req_crd        ( cxl_cache_req_crd      ),
    .cxl_cache_rsp_crd        ( cxl_cache_rsp_crd      )
    ,
    .cxl_mem_req_crd          ( cxl_mem_req_crd        ),
    .cxl_mem_rsp_crd          ( cxl_mem_rsp_crd        ),
    .cxl_mem_data_crd         ( cxl_mem_data_crd       )
);
// -------------------------------------------------------------------------------------


// -------------------------------------------------------------------------------------
// LL Controller Idle state indication
// -------------------------------------------------------------------------------------
// Idle condition must persist for 8 cycles to guarantee there are no transactions remained in
// Transaction Layer and IDE Core.
logic [2:0]  cxl_ll_idle_cntr_r, cxl_ll_idle_cntr_nxt;
logic        cxl_ll_idle_cntr_done_s;

delay_n
 #(
    .N        (1),
    .WD       (1),
    .RESETVAL (1'b1)
) u_delay_ll_idle (
    .clk   (core_clk),
    .rst_n (core_rst_n),
    .clear (1'b0),
    .din   (cxl_ll_idle_cntr_done_s),
    .dout  (cxl_ll_idle)
);

assign cxl_ll_idle_cntr_done_s = &cxl_ll_idle_cntr_r;

always_comb begin
    if (!cxl_packer_idle || ((|flit_fifo_prot_r) && !cxl_link_stall_req))
       cxl_ll_idle_cntr_nxt = '0;
    else if (!cxl_ll_idle_cntr_done_s)
       cxl_ll_idle_cntr_nxt = cxl_ll_idle_cntr_r + 1;
    else
       cxl_ll_idle_cntr_nxt = cxl_ll_idle_cntr_r;
end

always_ff @(posedge core_clk or negedge core_rst_n) begin
    if(!core_rst_n) begin
        cxl_ll_idle_cntr_r <= # TP '0;
    end else begin
        cxl_ll_idle_cntr_r <= # TP cxl_ll_idle_cntr_nxt;
    end
end
// -------------------------------------------------------------------------------------


// -------------------------------------------------------------------------------------
// Link Stall Request for 256B Flit Mode
// -------------------------------------------------------------------------------------
logic  cxl_link_stall_req_r;
logic  cxl_link_stall_req_nxt;

assign cxl_link_stall_req_s   = cxl_pcie_flit_mode ? cxl_link_stall_req_r : cxl_link_stall_req;

always_comb begin
    // If there is no flit in progress on the FIFO interface then assert stall_req flag
    // otherwise wait for EOF cycle to be captured into FIFO before asserting stall_req flag
    // do not stall if viral is in progress
    if (cxl_link_stall_req && !cxl_link_stall_req_r)
        cxl_link_stall_req_nxt = (cxl_mux_flit_valid || cxl_mux_all_data) ? (cxl_mux_last && !flit_fifo_full_s && !cxl_vir_inprogress) : 1'b1;
    // Reset stall_req flag when stall_req is de-asserted on LPIF interface
    else if (!cxl_link_stall_req && cxl_link_stall_req_r)
        cxl_link_stall_req_nxt = 1'b0;
    else
        cxl_link_stall_req_nxt = cxl_link_stall_req_r;
end

always_ff @(posedge core_clk or negedge core_rst_n) begin
    if(!core_rst_n) begin
        cxl_link_stall_req_r <= # TP 1'b0;
    end else begin
        cxl_link_stall_req_r <= # TP cxl_link_stall_req_nxt;
    end
end

always_ff @(posedge core_clk or negedge core_rst_n) begin
    if(!core_rst_n) begin
        cxl_link_stall_ack <= # TP 1'b0;
    end else begin
        cxl_link_stall_ack <= # TP cxl_link_stall_req_s && flit_fifo_empty_s && !xplh_arbmux_ctrl_pending;
    end
end
// -------------------------------------------------------------------------------------

endmodule
