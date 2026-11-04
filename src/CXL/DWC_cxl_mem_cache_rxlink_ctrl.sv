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

// -----------------------------------------------------------------------------
// --- RCS information:
// ---   $DateTime: 2023/12/22 07:15:34 $
// ---   $Revision: #13 $
// ---   $Id: //dwh/pcie_iip/main/fairbanks/design/CXL/DWC_cxl_mem_cache_rxlink_ctrl.sv#13 $
// -----------------------------------------------------------------------------
// --- Module Description:
// --- Retry Flits Detection on the ARB/MUX output after CRC check
// --- Control Flits Detection on the Link Control Flit IF
// --- Generation of the control signals on TX Link Controller IF
// -----------------------------------------------------------------------------
// --- Design Ware Core's CXL Controller RX Link Control Block 
// -----------------------------------------------------------------------------

`include "include/DWC_pcie_ctl_all_defs.svh"
`include "CXL/pkg/DWC_cxl_pkg.svh"
`include "DWC_pcie_ctl_pkg.svh"

`include "CXL/svif/DWC_cxl_rxdl_llctrl_if.svh"
`include "CXL/svif/DWC_cxl_clk_rst_if.svh"

module DWC_cxl_mem_cache_rxlink_ctrl 
import DWC_cxl_pkg::*;

#(
    parameter TP = `TP
) 
                                    (
// Inputs
  input                                                core_clk,                                // Core Clock
  input                                                core_rst_n,                              // Core Active Low Reset
  input                                                cxl_vlsm_recovery,                       // vLSM is in recovery
  input                                                cxl_pl_block_dl_init,                    // Block DL init 
  input                                                cxl_rx_crc_flit_valid,                   // CXL Flit Valid after CRC check
  input  [CXL_DATA_WD-1:0]                             cxl_rx_crc_flit_data,                    // CXL Flit Data  after CRC check
  input                                                cxl_rx_crc_error,                        // Indicates that received flit has crc error 
  input                                                cxl_rx_llctrl_flit_ctrl_en,              // RX LLCTRL Control Flit Valid
  input                                                cxl_rx_llctrl_flit_prot_en,              // RX LLCTRL Protocol Flit Valid
  input                                                cxl_rx_llctrl_flit_prot_adf,             // RX LLCTRL Protocol Flit All Data Flit(ADF) Indication
  input  [LLCTRL_FLIT_WD-1:0]                          cxl_rx_llctrl_flit_data,                 // RX LLCTRL Flit Data after RASDP check
  input  [15:0]                                        cxl_rx_crd_flit_data,                    // RX CRD Flit Data
  input                                                cxl_pcie_flit_mode,                      // PCIe Flit mode
// Outputs
// b_rxdl_llctrl Interface
  output     logic                                     cxl_rx_rcvd_retry_ack,                   // Indicates the reception of Retry Acknowledgment 
  output     logic          [MAX_RETRY_WD-1:0]         cxl_rx_rcvd_retry_ack_num_retry,         // Contains an echo of the NUM_RETRY value from the LLR.Req                          
  output     logic          [MAX_RETRY_WD-1:0]         cxl_rx_rcvd_retry_req_num_retry,         // Corresponds to NUM_RETRY field in Retry Request                           
  output     logic          [ESEQ_WD-1:0]              cxl_rx_rcvd_retry_req_eseq,              // Indicates the Requester's  Retry Sequence Number         
  output     logic                                     cxl_rx_rcvd_retry_req,                   // Indicates the reception of Retry Request                    
  output     logic          [ACK_CNT_WD-1:0]           cxl_rx_full_ack,                         // Indicates total number of flit acknowledgments being returned       
  output     logic                                     cxl_rx_rcvd_init_param_flit,             // Indicates the reception of Init control flit                           
  output     logic                                     cxl_rx_rcvd_retry_flit,                  // Indicates the reception of LLCRD control flit
  output     logic                                     cxl_rx_rcvd_non_retry,                   // Indicates that Received flit is retryable flit
//output     reg                                       cxl_rx_rcvd_llcrd_flit,                  // Indicates the reception of Retry control flit  
  output     logic                                     cxl_256b_rx_rcvd_inerr_poison,           // Poison bit indicates that the transmitting agent is in Poison state for 256B flit
  output     logic          [3:0]                      cxl_256b_rx_rcvd_inerr_poison_msg_offset, //the encoding of which of the active or upcoming messages will have poison applied.
   output CRD_256B_t                                   cxl_rx_256B_crd,                          // 256B RX credit 
                        
// CDM Interface  
  output     logic          [CXL_VERSION_WD-1:0]       cxl_rx_rcvd_init_cxl_version,            // The remote CXL version
  output     logic          [ESEQ_WD-1:0]              cxl_rx_rcvd_init_llr_wrap_value,         // Indicates the value after which LLR sequence counter should wrap to zero 
  output     logic                                     cxl_rx_control_flit_error,               // Indicates that control flit received with error
  output     logic          [MAX_REINIT_WD-1:0]        cxl_rx_rcvd_retry_req_num_phy_reinit,    // Corresponds to NUM_PHY_REINIT field in Retry Request                         
  output     logic                                     cxl_rx_rcvd_retry_ack_empty,             // Empty bit indicates that the LLR contains no valid data and therefore the NUM_RETRY value should be reset                             
  output     logic                                     cxl_rx_rcvd_retry_ack_viral,             // Viral bit indicates that the transmitting agent is in viral state                          
  output     logic          [7:0]                      cxl_rx_retry_ack_wrptr,                  // Contains the WrPtr value of the retry queue for debug purposes
  output     logic          [ESEQ_WD-1:0]              cxl_rx_retry_ack_eseq,                   // Contains the echo of the Eseq from the LLR.Req                      
  output     logic          [RBUF_ADD_WD-1:0]          cxl_rx_retry_ack_numfreebuf,             // Contains the NumFreeBuf value of the retry queue for debug purposes
 
  
  
  output     logic          [FLIT_CRD_WD-1:0]          cxl_rx_mem_cache_req_crd,                // CXL.mem/cache Request Credits
  output     logic          [FLIT_CRD_WD-1:0]          cxl_rx_mem_cache_data_crd,               // CXL.mem/cache Data Credits
  output     logic          [FLIT_CRD_WD-1:0]          cxl_rx_mem_cache_rsp_crd,                // CXL.mem/cache Response Credits
  output     logic                                     cxl_rx_ctrl_flit_valid                   // Control Flit valid
);
 
                                                                                  
// Local wires and regs
logic                       cxl_rx_ctrl_flit;                   // Error Free LLCTRL Flit received
logic       [3:0]           cxl_rx_ctrl_type;                   // LLCTRL Flit Type
logic       [3:0]           cxl_rx_ctrl_subtype;                // LLCTRL Flit SubType
logic       [2:0]           cxl_rx_ctrl_ctl_fmt;                // LLCTRL Flit CTL_FMT
logic       [63:0]          cxl_rx_ctrl_payload;                // LLCTRL Flit Payload
logic                       cxl_rx_ctrl_fmt64_chk;              // Check CTL_FMT is 64-bit in LLCTRL flit
logic                       cxl_rx_ctrl_fmt96_chk;              // Check CTL_FMT is 96-bit in LLCTRL flit
logic                       cxl_rx_ctrl_static_error;           // Check Static bits error in LLCTRL flit 

logic       [3:0]           cxl_rx_retry_type;                  // Retry LLCTRL Flit Type
logic       [3:0]           cxl_rx_retry_subtype;               // Retry LLCTRL Flit SubType
logic       [2:0]           cxl_rx_retry_ctl_fmt;               // Retry LLCTRL Flit CTL_FMT
logic       [63:0]          cxl_rx_retry_payload;               // Retry LLCTRL Flit Payload
logic                       cxl_rx_retry_fmt64_chk;             // Check CTL_FMT is 64-bit in LLCTRL Retry flit
logic                       cxl_rx_retry_frame_check;           // Check for 5 consecutive Retry.Frames before Retry.Req or Retry.Ack flit
logic       [4:0]           cxl_rx_retry_frame_count;           // Consecutive Retry.Frames Counter
logic                       cxl_rx_rcvd_retry_frame;            // Retry.Frame received
logic                       cxl_rx_retry_static_error;          // Check Static bits error in Retry flit

logic                       cxl_rx_rcvd_llcrd_flit;             // LLCRD Flit is received
logic                       cxl_rx_header_ack;                  // Acknowledge bit is set in the flit header
logic                       s_cxl_rx_llctrl_flit_prot_en;       // RX LLCTRL Protocol Flit Valid for 68B flit mode
logic [CXL_VERSION_WD-1:0]  cxl_rx_rcvd_init_cxl_version_nxt;
logic                       cxl_256b_rx_rcvd_init_param_flit;   // Indicates the reception of Init control flit  for 256B flit
logic                       cxl_256b_rx_rcvd_inerr_viral;       // Viral bit indicates that the transmitting agent is in viral state for 256B flit
logic                       cxl_256b_rx_ctrl_flit;              // Error Free LLCTRL Flit received for 256B flit
logic                       cxl_rx_ctrl_flit_nxt, cxl_rx_ctrl_flit_r;
assign s_cxl_rx_llctrl_flit_prot_en = (cxl_pcie_flit_mode)? 1'b0 : cxl_rx_llctrl_flit_prot_en;
// Error Free Link Layer Control Flit. Discard LLCTRL flits with Statis Bit Error.
assign cxl_rx_ctrl_flit       = cxl_rx_llctrl_flit_ctrl_en && !cxl_rx_ctrl_static_error;

// Retryable (non-Retry) flit Indication
assign cxl_rx_rcvd_non_retry  = (cxl_rx_ctrl_flit && (cxl_rx_ctrl_type != LLCTRL_RETRY)) || s_cxl_rx_llctrl_flit_prot_en;

// Detect Retry frame in the inbound stream - Type: Control flit; LLCTRL=RETRY; CTL_FMT=64; Reserved Bits=0;
assign cxl_rx_rcvd_retry_flit = cxl_rx_crc_flit_valid && cxl_rx_crc_flit_data[0] && (cxl_rx_retry_type == LLCTRL_RETRY) && !cxl_rx_retry_static_error && cxl_rx_retry_fmt64_chk;

// Extract LLCTRL - Type, SubType, CTL_FMT fields
assign cxl_rx_ctrl_type       = cxl_rx_llctrl_flit_data[35:32];
assign cxl_rx_ctrl_subtype    = cxl_rx_llctrl_flit_data[39:36];
assign cxl_rx_ctrl_payload    = cxl_rx_llctrl_flit_data[127:64];
assign cxl_rx_ctrl_ctl_fmt    = cxl_rx_llctrl_flit_data[7:5];
assign cxl_rx_ctrl_fmt64_chk  = (cxl_rx_ctrl_ctl_fmt == CTL_FMT_64);
assign cxl_rx_ctrl_fmt96_chk  = (cxl_rx_ctrl_ctl_fmt == CTL_FMT_96);

// Extract Retry LLCTRL - SubType and Payload fields
assign cxl_rx_retry_type      = cxl_rx_crc_flit_data[35:32];
assign cxl_rx_retry_subtype   = cxl_rx_crc_flit_data[39:36];
assign cxl_rx_retry_payload   = cxl_rx_crc_flit_data[127:64];
assign cxl_rx_retry_ctl_fmt   = cxl_rx_crc_flit_data[7:5];
assign cxl_rx_retry_fmt64_chk = (cxl_rx_retry_ctl_fmt == CTL_FMT_64);
assign cxl_rx_retry_static_error = (|cxl_rx_crc_flit_data[63:40]);
// -------------------------------------------------------------------------------------
// Control Flit Static bit error generation block.
//
// Static Error check is not performed for:
// * Static Bit check must be performed only for LLCTRL flits with 64bit payload.
// * Static Bit check must be used to increase confidence in qualifying flit as a RETRY
//   therefore Static Bit Error must be ignored for Retry.Frame flits
// -------------------------------------------------------------------------------------
assign cxl_rx_ctrl_static_error  = (|cxl_rx_llctrl_flit_data[63:40]) && cxl_rx_ctrl_fmt64_chk;

always_ff @(posedge core_clk or negedge core_rst_n) begin
    if (!core_rst_n) begin
        cxl_rx_control_flit_error <= # TP 1'b0;
    end else begin
        cxl_rx_control_flit_error <= # TP cxl_rx_llctrl_flit_ctrl_en && cxl_rx_ctrl_static_error;
    end
end
// -------------------------------------------------------------------------------------


// -------------------------------------------------------------------------------------
// INIT.Param Flit Decoding
//
// INIT.Param Flit control signals must not be registered to be aligned with Retry flits
// during initialization
// -------------------------------------------------------------------------------------

// To check Received flit is LLCTRL Init Param Flit  
assign cxl_rx_rcvd_init_param_flit = (cxl_pcie_flit_mode) ? cxl_256b_rx_rcvd_init_param_flit : 
                                      (cxl_rx_ctrl_flit && cxl_rx_ctrl_fmt64_chk && (cxl_rx_ctrl_type == LLCTRL_INIT) && (cxl_rx_ctrl_subtype == LLCTRL_INIT_PARAM));

// LLR Wrap Value is the value after which LLR sequence counter should wrap to zero. Must be valid at Init.Param cycle.
assign cxl_rx_rcvd_init_llr_wrap_value = cxl_rx_ctrl_payload[31:24];


// Interconnect Version. Used for debug purpose, latch the value.
always_comb begin
  cxl_rx_rcvd_init_cxl_version_nxt = cxl_rx_rcvd_init_cxl_version;
  if (cxl_rx_rcvd_init_param_flit)
    cxl_rx_rcvd_init_cxl_version_nxt = (cxl_pcie_flit_mode) ? 'd3 : cxl_rx_ctrl_payload[3:0];
end

always_ff @(posedge core_clk or negedge core_rst_n) begin
    if (!core_rst_n) begin
        cxl_rx_rcvd_init_cxl_version   <= # TP {CXL_VERSION_WD{1'b0}};
    end else begin
        cxl_rx_rcvd_init_cxl_version   <= # TP cxl_rx_rcvd_init_cxl_version_nxt;
    end
end
// -------------------------------------------------------------------------------------


// -------------------------------------------------------------------------------------
// LLCRD Acknowledge Decoding
// -------------------------------------------------------------------------------------

// LLCRD Flit is received
assign cxl_rx_rcvd_llcrd_flit = cxl_rx_ctrl_flit && cxl_rx_ctrl_fmt64_chk && (cxl_rx_ctrl_type == LLCTRL_LLCRD) && (cxl_rx_ctrl_subtype == LLCTRL_LLCRD_ACK);

// Flit Header Acknowledge Bit is set
assign cxl_rx_header_ack      =   cxl_rx_llctrl_flit_data[2] && !cxl_rx_llctrl_flit_prot_adf; 

// In the LLCRD flit, Full_ack is the total number of flit acknowledgments being returned.
// Must be valid on the same cycle as retryable flit valid - cxl_rx_llctrl_flit_ctrl_en or s_cxl_rx_llctrl_flit_prot_en
assign cxl_rx_full_ack = cxl_rx_rcvd_llcrd_flit ? {cxl_rx_ctrl_payload[7:4], cxl_rx_header_ack, cxl_rx_ctrl_payload[2:0]} : ((s_cxl_rx_llctrl_flit_prot_en && cxl_rx_header_ack) ? ACK_CNT_WD'(8) : ACK_CNT_WD'(0));

// Request, Data and Response Credits Decoding from the Flit Header. It is fine to delay credit returns for 1 cycle.
always_ff @(posedge core_clk or negedge core_rst_n)  begin
    if (!core_rst_n) begin
        cxl_rx_mem_cache_rsp_crd  <= # TP {FLIT_CRD_WD{1'b0}};
        cxl_rx_mem_cache_req_crd  <= # TP {FLIT_CRD_WD{1'b0}};
        cxl_rx_mem_cache_data_crd <= # TP {FLIT_CRD_WD{1'b0}};
    end else begin 
        if (cxl_rx_rcvd_llcrd_flit || s_cxl_rx_llctrl_flit_prot_en && !cxl_rx_llctrl_flit_prot_adf) begin
            cxl_rx_mem_cache_rsp_crd  <= # TP cxl_rx_llctrl_flit_data[23:20];
            cxl_rx_mem_cache_req_crd  <= # TP cxl_rx_llctrl_flit_data[27:24];   
            cxl_rx_mem_cache_data_crd <= # TP cxl_rx_llctrl_flit_data[31:28];
        end else begin
            cxl_rx_mem_cache_rsp_crd  <= # TP {FLIT_CRD_WD{1'b0}}; 
            cxl_rx_mem_cache_req_crd  <= # TP {FLIT_CRD_WD{1'b0}}; 
            cxl_rx_mem_cache_data_crd <= # TP {FLIT_CRD_WD{1'b0}}; 
        end
    end
end
// -------------------------------------------------------------------------------------


// -------------------------------------------------------------------------------------
// Retry.Req Flit Decoding
// -------------------------------------------------------------------------------------

// When Crc error is detected, received retry req signal is required to start decoding of the flits.
assign cxl_rx_rcvd_retry_req = cxl_rx_rcvd_retry_flit && (cxl_rx_retry_subtype == LLCTRL_RETRY_REQ) && cxl_rx_retry_frame_check && !cxl_pl_block_dl_init;

// Eseq indicates the expected sequence number of the next valid flit at the receiving link layer entity. Must be valid at Retry.Req cycle.
assign cxl_rx_rcvd_retry_req_eseq = cxl_rx_retry_payload[7:0];
  
// Num_retry contains the nymber count of RETRY.Req requests sent to retry the same flit. Must be latched to echo with Retry.Ack flit
always_ff @(posedge core_clk or negedge core_rst_n) begin
    if (!core_rst_n) begin
        cxl_rx_rcvd_retry_req_num_retry <= # TP {MAX_RETRY_WD{1'b0}};
    end else begin
        cxl_rx_rcvd_retry_req_num_retry <= # TP cxl_rx_rcvd_retry_req ? cxl_rx_retry_payload[20:16] : cxl_rx_rcvd_retry_req_num_retry;
    end
end
  
// Num_phy_reinit contains the number count of physical layer reinitializations generated during a LLR sequence. Used for debug purpose, latch the value.
always_ff @(posedge core_clk or negedge core_rst_n) begin
    if (!core_rst_n) begin
        cxl_rx_rcvd_retry_req_num_phy_reinit <= # TP {MAX_REINIT_WD{1'b0}};
    end else begin
        cxl_rx_rcvd_retry_req_num_phy_reinit <= # TP cxl_rx_rcvd_retry_req ? cxl_rx_retry_payload[25:21] : cxl_rx_rcvd_retry_req_num_phy_reinit;
    end
end
// -------------------------------------------------------------------------------------


// -------------------------------------------------------------------------------------
// Retry.Ack Flit Decoding
// -------------------------------------------------------------------------------------
  
// This flit is sent from the entity that is responding to an error detected at the remote entity.
assign cxl_rx_rcvd_retry_ack = cxl_rx_rcvd_retry_flit && (cxl_rx_retry_subtype == LLCTRL_RETRY_ACK) && cxl_rx_retry_frame_check;

// The Empty indicates that the LLR contains no valid data and therefore the NUM_RETRY value should be reset. Must be valid at Retry.Ack cycle.
assign cxl_rx_rcvd_retry_ack_empty = cxl_rx_rcvd_retry_ack & cxl_rx_retry_payload[0];

// The Viral bit indicates transmitting agent in a Viral state. Must be valid at Retry.Ack cycle.
assign cxl_rx_rcvd_retry_ack_viral = (cxl_pcie_flit_mode)? cxl_256b_rx_rcvd_inerr_viral: cxl_rx_rcvd_retry_ack & cxl_rx_retry_payload[1];

// Echo of the NUM_RETRY value from the LLR.Req. Must be valid at Retry.Ack cycle.
assign cxl_rx_rcvd_retry_ack_num_retry = cxl_rx_retry_payload[7:3];

  
// Echo of the Eseq from the LLR.Req. Used for debug purpose, latch the value.
always_ff @(posedge core_clk or negedge core_rst_n) begin
    if (!core_rst_n) begin
        cxl_rx_retry_ack_eseq <= # TP {ESEQ_WD{1'b0}};
    end else begin
        cxl_rx_retry_ack_eseq <= # TP cxl_rx_rcvd_retry_ack ? cxl_rx_retry_payload[23:16] : cxl_rx_retry_ack_eseq;
    end
end
  
// WrPtr value of the retry queue. Used for debug purpose, latch the value.
always_ff @(posedge core_clk or negedge core_rst_n) begin
    if (!core_rst_n) begin
        cxl_rx_retry_ack_wrptr <= # TP 8'd0;
    end else begin
        cxl_rx_retry_ack_wrptr <= # TP cxl_rx_rcvd_retry_ack ? cxl_rx_retry_payload[15:8] : cxl_rx_retry_ack_wrptr;
    end
end
  
// NumFreeBuf value of the retry queue. Used for debug purpose, latch the value.
always_ff @(posedge core_clk or negedge core_rst_n) begin
    if (!core_rst_n) begin
        cxl_rx_retry_ack_numfreebuf <= # TP 8'd0;
    end else begin
        cxl_rx_retry_ack_numfreebuf <= # TP cxl_rx_rcvd_retry_ack ? cxl_rx_retry_payload[31:24] : cxl_rx_retry_ack_numfreebuf;
    end
end
// -------------------------------------------------------------------------------------


// -------------------------------------------------------------------------------------
// RETRY.Frame Decoding
// -------------------------------------------------------------------------------------

// Retry.Frame is received
assign cxl_rx_rcvd_retry_frame = cxl_rx_rcvd_retry_flit && (cxl_rx_retry_subtype == LLCTRL_RETRY_FRAME);

// when 5 retry frames are recieved, retry req/ack flit can be decoded.
assign cxl_rx_retry_frame_check = &cxl_rx_retry_frame_count;

// cxl_rx_retry_frame_count signal is to count 5 retry frames  
always_ff @(posedge core_clk or negedge core_rst_n) begin
    if (!core_rst_n) begin
        cxl_rx_retry_frame_count <= # TP 5'd0;
    end 
    else if (cxl_vlsm_recovery || cxl_rx_crc_error) begin
        // Reset retry frame counter when link goes into a recovery or Receives Flit with CRC Error
        cxl_rx_retry_frame_count <= # TP 5'd0;
    end
    else begin 
        if (cxl_rx_rcvd_retry_frame) begin
            cxl_rx_retry_frame_count <= # TP {cxl_rx_retry_frame_count[3:0], 1'b1};
        end
        else if (cxl_rx_crc_flit_valid) begin
            cxl_rx_retry_frame_count <= # TP 5'd0;
        end
        else begin
            cxl_rx_retry_frame_count <= # TP cxl_rx_retry_frame_count;
        end
    end
end
// -------------------------------------------------------------------------------------


// -------------------------------------------------------------------------------------
// CXS+ CXL Controller Interface
// -------------------------------------------------------------------------------------
assign cxl_rx_ctrl_flit_valid  = (cxl_pcie_flit_mode)? (cxl_rx_ctrl_flit_nxt | cxl_rx_ctrl_flit_r) : 
                                  (cxl_rx_ctrl_flit && cxl_rx_ctrl_fmt64_chk && (cxl_rx_ctrl_type == LLCTRL_LLCRD) && (cxl_rx_ctrl_subtype == LLCTRL_LLCRD_ACK) && (|cxl_rx_llctrl_flit_data[31:20]));


// Credit 
// The credit should be extracted before sending the data to IDE
// This is because all IDE flits are consumbed by the IDE 
// therefore the credit of these flits will be lost in case we are checking IDE output
localparam ARBMUX_WD_RATIO = 2048 / ARBMUX_DATA_WD ;
logic       [3:0]           cxl_256b_rx_ctrl_type;                   // LLCTRL Flit Type
logic       [3:0]           cxl_256b_rx_ctrl_subtype;                // LLCTRL Flit SubType
logic       [95:0]          cxl_256b_rx_ctrl_payload;                // LLCTRL Flit Payload

logic [ARBMUX_WD_RATIO-1:0] flit_dv_cntr_r, flit_dv_cntr_nxt;
logic                       flit_dv;
logic                       sof;
logic                       eof;

assign cxl_rx_256B_crd.CRD_A = (eof)? cxl_rx_crd_flit_data [0      +: 5] : 'b0;
assign cxl_rx_256B_crd.CRD_B = (eof)? cxl_rx_crd_flit_data [(0+5)  +: 5] : 'b0;
assign cxl_rx_256B_crd.CRD_C = (eof)? cxl_rx_crd_flit_data [(0+10) +: 5] : 'b0;
assign cxl_rx_256B_crd.RSVD  = (eof)? cxl_rx_crd_flit_data [(0+15) +: 1] : 'b0;



assign flit_dv  = cxl_rx_llctrl_flit_prot_en & cxl_pcie_flit_mode;
assign sof = flit_dv && (!flit_dv_cntr_r[0]);
assign eof = flit_dv && (flit_dv_cntr_r[1:0] == 2'b01);

always_comb begin
    if (sof) begin
        flit_dv_cntr_nxt = {1'b0, {(ARBMUX_WD_RATIO-1){1'b1}}};
    end
    else if (flit_dv) begin
        flit_dv_cntr_nxt = flit_dv_cntr_r >> 1;
    end
    else begin
        flit_dv_cntr_nxt = flit_dv_cntr_r;
    end
end
always_ff @(posedge core_clk or negedge core_rst_n) begin
    if(!core_rst_n) begin
        flit_dv_cntr_r     <= # TP '0;
    end else begin
        flit_dv_cntr_r     <= # TP flit_dv_cntr_nxt;
    end
end
assign cxl_256b_rx_ctrl_flit            = sof && (cxl_rx_llctrl_flit_data[16+:4] == 4'h8); // H8 & HS8 Slot Format
assign cxl_256b_rx_ctrl_type            = cxl_rx_llctrl_flit_data[20+: 4];
assign cxl_256b_rx_ctrl_subtype         = cxl_rx_llctrl_flit_data[24+: 4];
assign cxl_256b_rx_ctrl_payload         = cxl_rx_llctrl_flit_data[32+:96];

// -------------------------------------------------------------------------------------
// Init Param Flit Decoding
// -------------------------------------------------------------------------------------
assign cxl_256b_rx_rcvd_init_param_flit = cxl_256b_rx_ctrl_flit && (cxl_256b_rx_ctrl_type == LLCTRL_INIT) && (cxl_256b_rx_ctrl_subtype == LLCTRL_INIT_PARAM);


// -------------------------------------------------------------------------------------
// Inband Error Flit Decoding
// -------------------------------------------------------------------------------------
assign cxl_256b_rx_rcvd_inerr_viral = cxl_256b_rx_ctrl_flit && (cxl_256b_rx_ctrl_type == LLCTRL_INERR) && (cxl_256b_rx_ctrl_subtype == LLCTRL_INERR_VIRAL);
assign cxl_256b_rx_rcvd_inerr_poison = cxl_256b_rx_ctrl_flit && (cxl_256b_rx_ctrl_type == LLCTRL_INERR) && (cxl_256b_rx_ctrl_subtype == LLCTRL_INERR_POISON);
assign cxl_256b_rx_rcvd_inerr_poison_msg_offset = cxl_256b_rx_ctrl_payload[3:0];


// -------------------------------------------------------------------------------------
// Gate 256B Control Flits:
// -- Viral
// -- Init Param
// -- Poison(For CHI only, for CXS we send it to the ULL)
always_comb begin
    cxl_rx_ctrl_flit_nxt = cxl_rx_ctrl_flit_r;
    if (cxl_256b_rx_rcvd_init_param_flit ||
        cxl_256b_rx_rcvd_inerr_viral
 || cxl_256b_rx_rcvd_inerr_poison )  
      cxl_rx_ctrl_flit_nxt = 1'b1;
    else if (eof) 
      cxl_rx_ctrl_flit_nxt = 1'b0;
end
// -------------------------------------------------------------------------------------

always_ff @(posedge core_clk or negedge core_rst_n) begin
    if(!core_rst_n) begin
        cxl_rx_ctrl_flit_r <= # TP '0;
    end else begin
        cxl_rx_ctrl_flit_r <= # TP cxl_rx_ctrl_flit_nxt;
    end
end

// 


endmodule
