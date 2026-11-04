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

// -------------------------------------------------------------------------------------
// --- RCS information:
// ---   $DateTime: 2023/12/22 07:15:34 $
// ---   $Revision: #5 $
// ---   $Id: //dwh/pcie_iip/main/fairbanks/design/CXL/DWC_cxl_mem_cache_unpacker_68byte.sv#5 $
// -------------------------------------------------------------------------------------
// --- Module Description:
// -------------------------------------------------------------------------------------
// CXL Flit Unpacker
// -------------------------------------------------------------------------------------

`include "include/DWC_pcie_ctl_all_defs.svh"
`include "CXL/pkg/DWC_cxl_pkg.svh"

module DWC_cxl_mem_cache_unpacker_68byte
  import DWC_cxl_pkg::*;
#(
  parameter TP = `TP
)(
    // Inputs
    input                                         core_clk,              // Clock
    input                                         core_rst_n,            // Asynchronous Active Low Reset
    input                                         cxl_device_mode,       // CXL Device Type

    input                                         cxl_flit_valid_i,      // Protocol Flit Valid before CRC check
    input  [511:0]                                cxl_flit_data_i,       // Protocol Flit Data
    input                                         cxl_rx_crc_error_i,    // CRC check error on the received flit
    input                                         cxl_mdh_disable_i,     // Disable MDH support
    input                                         cxl_tl_cache_crdret_i, // Transaction Layer Return Cache Data Credit
    input                                         cxl_tl_mem_crdret_i,   // Transaction Layer Return Mem Data Credit
    // Outputs
    output [1:0]                                  cxl_rx_cache_crdret_o, // RX Return Cache Data Credit
    output [1:0]                                  cxl_rx_mem_crdret_o,   // RX Return Mem Data Credit
    output                                        rsvd_enc_error_o,      // CXL Reserved Encoding Violation
    output [1:0]                                  poisoned_data_o,       // CXL Poison Data Detection
    output                                        cxl_mdh_error_o,       // MDH Error
    output                                        cxl_flit_adf_o,         // All Data Flit Indication
    DWC_cxl_rxtl_llctrl_if.master_mp              b_unpack_68B
);

localparam CXL_HDR_SIZE = 32;

localparam H2D_CHUNK_BIT = 13;
localparam D2H_CHUNK_BIT = 13;

typedef struct packed {
    logic [3:0]       DataCrd;
    logic [3:0]       ReqCrd;
    logic [3:0]       RspCrd;
    logic [2:0]       RSVD_BIT17_19;
    logic [2:0]       Slot3;
    logic [2:0]       Slot2;
    logic [2:0]       Slot1;
    logic [2:0]       Slot0;
    logic             Sz;
    logic             BE;
    logic             Ack;
    logic             ProtRev;
    logic             ProtType;
} CXL_HDR_t;

logic         cxl_flit_valid_crc_s;             // Flit Valid after CRC check
CXL_HDR_t     cxl_flit_hdr_s;                   // CXL Flit Header Structure
logic [2:0]   slot_sel_s;                       // Selected Slot in the for Loop
logic [8:0]   slot_idx_s;                       // Slot Index
logic [4:0]   rollover_cnt_r, rollover_cnt_nxt; // Data Rollover Counter
logic [4:0]   rollover_inc_s;                   // Data Rollover Counter Increment
logic [1:0]   rollover_dec_s;                   // Data Rollover Counter Decrement
logic         rsvd_enc_error_s;                 // Reserved Encoding Violation
logic [1:0]   poisoned_data_s;                  // Indication of detected Poison bit in the Data Header

// Message Data Flow Control
logic         hdr_mode_r, hdr_mode_nxt;         // Selects Protocol Direction based on Device Mode and Reverse Protocol bit
logic         hdr_be_r, hdr_be_nxt;             // Latch Byte Enable
logic         hdr_cache_r,  hdr_cache_nxt;      // CXL.cache message Data Flag
logic         hdr_mem_r,  hdr_mem_nxt;          // CXL.mem message Data Flag

logic [511:0] hdr_data_r, hdr_data_nxt;         // Message Data register
logic [511:0] hdr_data_s;                       // Message Data Mux output
logic         hdr_data_vld_r, hdr_data_vld_nxt; // Message Data Valid register
logic         hdr_data_vld_s;                   // Message Data Valid Mux output

logic         hdr_sz_r, hdr_sz_nxt;             // Latch Size Enable
logic [1:0]   hdr_sz_cntr_r, hdr_sz_cntr_nxt;   // 32B data transfers count
logic         hdr_sz_chunk_r, hdr_sz_chunk_nxt; // Indication of detected Chunk Valid bit in the Data Header for 32B data
logic         hdr_store32b_s;                   // Pulse signal to capture Data into hdr_data32b_r
logic [255:0] hdr_data32b_r, hdr_data32b_nxt;   // Message Data register which stores 1st half Data of 32B transactions
logic         hdr_store32b_be_s;                // Pulse signal to capture Byte Enable into hdr_be32b_r
logic [63:0]  hdr_be32b_r, hdr_be32b_nxt;       // Byte Enable  register which stores 1st half Byte Enable of 32B transactions

logic [63:0]  hdr_be_data_s;                    // Data Byte Enable
logic         hdr_be_valid_s;                   // Data Byte Enable Valid
logic [1:0]   data_offset_r, data_offset_nxt;   // Data offset in the Header Flit

logic         hdr_data_crc_s;
logic         hdr_be_crc_s;

logic [H2D_68B_RESP_SIZE-1:0] h2d_rsp_msg_s [0:H2D_68B_RESP_NUM-1];
logic [H2D_68B_REQ_SIZE-1:0]  h2d_req_msg_s [0:H2D_68B_REQ_NUM-1];
logic [H2D_68B_DHDR_SIZE-1:0] h2d_hdr_msg_s [0:H2D_68B_DATA_NUM-1];

logic [0:0] h2d_req_idx_s;
logic [1:0] h2d_rsp_idx_s;
logic [M2S_68B_NDR_SIZE-1:0]  m2s_ndr_msg_s [0:M2S_68B_NDR_NUM-1];
logic [M2S_68B_DHDR_SIZE-1:0] m2s_hdr_msg_s [0:M2S_68B_DATA_NUM-1];

logic [0:0] m2s_ndr_idx_s;
logic [D2H_68B_RESP_SIZE-1:0] d2h_rsp_msg_s [0:D2H_68B_RESP_NUM-1];
logic [D2H_68B_REQ_SIZE-1:0]  d2h_req_msg_s [0:D2H_68B_REQ_NUM-1];
logic [D2H_68B_DHDR_SIZE-1:0] d2h_hdr_msg_s [0:D2H_68B_DATA_NUM-1];

logic [1:0] d2h_req_idx_s;
logic [0:0] d2h_rsp_idx_s;
logic [S2M_68B_NDR_SIZE-1:0]  s2m_ndr_msg_s [0:S2M_68B_NDR_NUM-1];
logic [S2M_68B_DHDR_SIZE-1:0] s2m_hdr_msg_s [0:S2M_68B_DATA_NUM-1];

logic [0:0] s2m_ndr_idx_s;
logic [(2*S2M_68B_NDR_SIZE)-1:0] s2m_ndr_x2_msg_s;


// CXL Unpacker outputs assignment
assign cxl_flit_adf_o     = (|rollover_cnt_r[4:2]);
assign rsvd_enc_error_o   = cxl_flit_valid_crc_s ? rsvd_enc_error_s : 1'b0;
assign poisoned_data_o    = cxl_flit_valid_crc_s ? poisoned_data_s : 2'b00;

assign cxl_mdh_error_o    = cxl_mdh_disable_i && (1'b0
        || b_unpack_68B.s_cxl_h2d_dhr[1][0]   
        || b_unpack_68B.s_cxl_d2h_dhr[1][0]
        || b_unpack_68B.s_cxl_s2m_drs[1][0]
);

// -------------------------------------------------------------------------------------
// Channel Message Outputs - Interface to RX Transaction Layer
// -------------------------------------------------------------------------------------
always_comb begin
// Device Unpacker Interface
    
    for (int i = 0; i < H2D_RESP_NUM; i++)      
        b_unpack_68B.s_cxl_h2d_resp[i]                                = '0;
    for (int i = 0; i < H2D_68B_RESP_NUM; i++)      
        b_unpack_68B.s_cxl_h2d_resp[i][H2D_68B_RESP_SIZE-1:0]         = h2d_rsp_msg_s[i];
                                                
                                                   
    for (int i = 0; i < H2D_REQ_NUM; i++)            
        b_unpack_68B.s_cxl_h2d_req[i]                                 = '0;
    for (int i = 0; i < H2D_68B_REQ_NUM; i++)            
        b_unpack_68B.s_cxl_h2d_req[i][H2D_68B_REQ_SIZE-1:0]           = h2d_req_msg_s[i];
    
    
    for (int i = 0; i < H2D_DATA_NUM  ; i++)   
        b_unpack_68B.s_cxl_h2d_dhr[i]                                 = '0;
    for (int i = 0; i < H2D_68B_DATA_NUM  ; i++)   
        b_unpack_68B.s_cxl_h2d_dhr[i][H2D_68B_DHDR_SIZE-1:0]          = {h2d_hdr_msg_s[i][H2D_68B_DHDR_SIZE-1:1], h2d_hdr_msg_s[i][0] && !cxl_rx_crc_error_i};
                                                  
                                                   
        // Gate first 32B transaction Header       
        b_unpack_68B.s_cxl_h2d_dhr[0][0]                              = b_unpack_68B.s_cxl_h2d_dhr[0][0] && (cxl_flit_hdr_s.Sz ? 1'b1 : hdr_sz_cntr_r[0]); 
                    

    for (int i = 0; i < H2D_DDATA_NUM ; i++)  begin
        b_unpack_68B.s_cxl_h2d_data[i]                                = '0;        
        b_unpack_68B.s_cxl_h2d_data_valid[i]                          ='b0;
    end    

    for (int i = 0; i < H2D_68B_DDATA_NUM ; i++)   begin     
        b_unpack_68B.s_cxl_h2d_data[i][H2D_68B_DDATA_SIZE-1:0]        = hdr_data_s;
        b_unpack_68B.s_cxl_h2d_data_valid[i]                          = hdr_data_vld_s && hdr_cache_r && !hdr_mode_r && (hdr_data_crc_s ? !cxl_rx_crc_error_i : 1'b1);
    end                                             
                                                   
         //cxl_dltl_h2d_data_32b                                      = hdr_sz_cntr_r[1];
    for (int i = 0; i < M2S_DATA_NUM; i++) 
      b_unpack_68B.s_cxl_m2s_dhr[i]= '0;
                              
    for (int i = 0; i < M2S_68B_DATA_NUM; i++)     begin      
        b_unpack_68B.s_cxl_m2s_dhr[i][M2S_68B_DHDR_SIZE-1:0]          = {m2s_hdr_msg_s[i][M2S_68B_DHDR_SIZE-1:1], m2s_hdr_msg_s[i][0] && !cxl_rx_crc_error_i};
    end
        
    for (int i = 0; i < M2S_NDR_NUM; i++)      
        b_unpack_68B.s_cxl_m2s_req[i]                                 = '0;
    for (int i = 0; i < M2S_68B_NDR_NUM; i++)      
        b_unpack_68B.s_cxl_m2s_req[i][M2S_68B_NDR_SIZE-1:0]           = m2s_ndr_msg_s[i];
    
    for (int i = 0; i < M2S_DDATA_NUM; i++)    begin
        b_unpack_68B.s_cxl_m2s_byte_en[i]                             = '0;
        b_unpack_68B.s_cxl_m2s_byte_en_valid[i]                       = '0;
        b_unpack_68B.s_cxl_m2s_data[i]                                = '0;
        b_unpack_68B.s_cxl_m2s_data_valid[i]                          = '0;
    end

    for (int i = 0; i < M2S_68B_DDATA_NUM; i++)    begin
        b_unpack_68B.s_cxl_m2s_byte_en[i][M2S_68B_DBE_SIZE-1:0]       = hdr_be_data_s;
               
        b_unpack_68B.s_cxl_m2s_byte_en_valid[i]                       = hdr_be_valid_s && hdr_mem_r && !hdr_mode_r && (hdr_be_crc_s ? !cxl_rx_crc_error_i : 1'b1);
               
        b_unpack_68B.s_cxl_m2s_data[i][M2S_68B_DDATA_SIZE-1:0]        = hdr_data_s;
                    
        b_unpack_68B.s_cxl_m2s_data_valid[i]                          = hdr_data_vld_s && hdr_mem_r && !hdr_mode_r && (hdr_data_crc_s ? !cxl_rx_crc_error_i : 1'b1);
    end  
     
// Host Unpacker Interface

    
    for (int i = 0; i < D2H_REQ_NUM; i++)      
        b_unpack_68B.s_cxl_d2h_req[i]                                 = '0;
    for (int i = 0; i < D2H_68B_REQ_NUM; i++)      
        b_unpack_68B.s_cxl_d2h_req[i][D2H_68B_REQ_SIZE-1:0]           = d2h_req_msg_s[i];
    
    
    for (int i = 0; i < D2H_RESP_NUM; i++)     
        b_unpack_68B.s_cxl_d2h_resp[i]                                = '0;
    for (int i = 0; i < D2H_68B_RESP_NUM; i++)     
        b_unpack_68B.s_cxl_d2h_resp[i][D2H_68B_RESP_SIZE-1:0]         = d2h_rsp_msg_s[i];
    
    for (int i = 0; i < D2H_DATA_NUM; i++)     
        b_unpack_68B.s_cxl_d2h_dhr[i]                                 = '0; 
    for (int i = 0; i < D2H_68B_DATA_NUM; i++)     
        b_unpack_68B.s_cxl_d2h_dhr[i][D2H_68B_DHDR_SIZE-1:0]          = {d2h_hdr_msg_s[i][D2H_68B_DHDR_SIZE-1:1], d2h_hdr_msg_s[i][0] && !cxl_rx_crc_error_i};
    
        // Gate first 32B transaction Header
        b_unpack_68B.s_cxl_d2h_dhr[0][0]                              = b_unpack_68B.s_cxl_d2h_dhr[0][0] && (cxl_flit_hdr_s.Sz ? 1'b1 : hdr_sz_cntr_r[0]); 
    
    
    
    
    for (int i = 0; i < D2H_DDATA_NUM; i++ )   begin
        b_unpack_68B.s_cxl_d2h_byte_en[i]                             = '0;
        b_unpack_68B.s_cxl_d2h_byte_en_valid[i]                       = '0;
        b_unpack_68B.s_cxl_d2h_data[i]                                = '0;                         
        b_unpack_68B.s_cxl_d2h_data_valid[i]                          = '0;
    end
    
    
    for (int i = 0; i < D2H_68B_DDATA_NUM; i++ )   begin
        b_unpack_68B.s_cxl_d2h_byte_en[i][D2H_68B_DBE_SIZE-1:0]       = hdr_be_data_s;
        b_unpack_68B.s_cxl_d2h_byte_en_valid[i]                       = hdr_be_valid_s && hdr_cache_r && hdr_mode_r && (hdr_be_crc_s ? !cxl_rx_crc_error_i : 1'b1);
        b_unpack_68B.s_cxl_d2h_data[i][D2H_68B_DDATA_SIZE-1:0]        = hdr_data_s;
        //cxl_dltl_d2h_data_32b                                       = hdr_sz_cntr_r[1];                   
        b_unpack_68B.s_cxl_d2h_data_valid[i]                          =  hdr_data_vld_s && hdr_cache_r && hdr_mode_r && (hdr_data_crc_s ? !cxl_rx_crc_error_i : 1'b1);
    end
    
    for (int i = 0; i < S2M_NDR_NUM; i++)      
        b_unpack_68B.s_cxl_s2m_ndr[i]                                 = '0;
    for (int i = 0; i < S2M_68B_NDR_NUM; i++)      
        b_unpack_68B.s_cxl_s2m_ndr[i][S2M_68B_NDR_SIZE-1:0]           = s2m_ndr_msg_s[i];
                                            
    for (int i = 0; i < S2M_DATA_NUM; i++)
        b_unpack_68B.s_cxl_s2m_drs[i]                                 ='0;
    for (int i = 0; i < S2M_68B_DATA_NUM; i++)
        b_unpack_68B.s_cxl_s2m_drs[i][S2M_68B_DHDR_SIZE-1:0]          = {s2m_hdr_msg_s[i][S2M_68B_DHDR_SIZE-1:1], s2m_hdr_msg_s[i][0] && !cxl_rx_crc_error_i};


        // Gate first 32B transaction Header   
        b_unpack_68B.s_cxl_s2m_drs[0][0]                              = b_unpack_68B.s_cxl_s2m_drs[0][0] && (cxl_flit_hdr_s.Sz ? 1'b1 : hdr_sz_cntr_r[0]);   
        
    for (int i = 0; i < S2M_DDATA_NUM; i++)    begin
        b_unpack_68B.s_cxl_s2m_data[i]                                = '0;
        b_unpack_68B.s_cxl_s2m_data_valid[i]                          = '0;
    end
    
    for (int i = 0; i < S2M_68B_DDATA_NUM; i++)    begin
        b_unpack_68B.s_cxl_s2m_data[i][S2M_68B_DDATA_SIZE-1:0]        = hdr_data_s;
        //cxl_dltl_s2m_data_32b                                       = hdr_sz_cntr_r[1];  
        b_unpack_68B.s_cxl_s2m_data_valid[i]                          = hdr_data_vld_s && hdr_mem_r && hdr_mode_r && (hdr_data_crc_s ? !cxl_rx_crc_error_i : 1'b1);
    end
    
    for (int i = 0; i < M2S_BI_RSP_NUM; i++)   
        b_unpack_68B.s_cxl_m2s_bi_rsp[i]                              = '0;
    for (int i = 0; i < S2M_BI_SNP_NUM; i++)   
        b_unpack_68B.s_cxl_s2m_bi_snp[i]                              = '0;
end
// -------------------------------------------------------------------------------------

// Internal signals assignments
assign cxl_flit_hdr_s       = CXL_HDR_t'(cxl_flit_data_i[CXL_HDR_SIZE-1:0]);
assign cxl_flit_valid_crc_s = cxl_flit_valid_i && !cxl_rx_crc_error_i;

// -------------------------------------------------------------------------------------
// CXL Flit Unpacker
// -------------------------------------------------------------------------------------
always_comb begin
    // Preset Rollover Counter and Error flags
    rsvd_enc_error_s = 1'b0;
    poisoned_data_s  = 2'd0;
    rollover_inc_s   = '0;
    rollover_dec_s   = '0;

    // Preset Data Register
    hdr_data_nxt     = hdr_data_r;

    // Preset Device Indexes
    h2d_req_idx_s    = '0;
    h2d_rsp_idx_s    = '0;
    m2s_ndr_idx_s    = '0;

    // Preset Host Indexes
    d2h_req_idx_s    = '0;
    d2h_rsp_idx_s    = '0;
    s2m_ndr_idx_s    = '0;

    slot_sel_s       = '0;
    slot_idx_s       = '0;

    // Preset Device Messages
    for (int i = 0; i < H2D_68B_RESP_NUM; i++) h2d_rsp_msg_s[i] = '0;
    for (int i = 0; i < H2D_68B_REQ_NUM; i++)  h2d_req_msg_s[i] = '0;
    for (int i = 0; i < H2D_68B_DATA_NUM; i++) h2d_hdr_msg_s[i] = '0;
    for (int i = 0; i < M2S_68B_NDR_NUM; i++)  m2s_ndr_msg_s[i] = '0;
    for (int i = 0; i < M2S_68B_DATA_NUM; i++) m2s_hdr_msg_s[i] = '0;

    // Preset Host Messages
    for (int i = 0; i < D2H_68B_RESP_NUM; i++) d2h_rsp_msg_s[i] = '0;
    for (int i = 0; i < D2H_68B_REQ_NUM; i++)  d2h_req_msg_s[i] = '0;
    for (int i = 0; i < D2H_68B_DATA_NUM; i++) d2h_hdr_msg_s[i] = '0;
    for (int i = 0; i < S2M_68B_NDR_NUM; i++)  s2m_ndr_msg_s[i] = '0;
    for (int i = 0; i < S2M_68B_DATA_NUM; i++) s2m_hdr_msg_s[i] = '0;

    // Unpack the Protocol Flit if it is not an ADF flit
    if (cxl_flit_valid_i && !cxl_flit_adf_o) begin
      // -------------------------------------------------------------------------------------
      // Device Unpacker
      // -------------------------------------------------------------------------------------
      if (!cxl_device_mode) begin
        // Device Slot0 Rollover Counter
        case (cxl_flit_hdr_s.Slot0)
            3'b000: begin // H0 Slot - CXL.cache Req + CXL.cache Resp
                rollover_inc_s = rollover_inc_s;

                {h2d_rsp_msg_s[0], h2d_req_msg_s[0]} = cxl_flit_data_i[CXL_HDR_SIZE+:(H2D_68B_REQ_SIZE+H2D_68B_RESP_SIZE)];
                h2d_req_idx_s = 1; h2d_rsp_idx_s = 1;
            end
            3'b001: begin // H1 Slot - CXL.cache Data Header + 2 CXL.cache Resp
                if(cxl_flit_data_i[CXL_HDR_SIZE]) begin
                  rollover_inc_s = rollover_inc_s + (cxl_flit_hdr_s.Sz ? 4 : 2);
                  poisoned_data_s[0] = poisoned_data_s[0] | cxl_flit_data_i[CXL_HDR_SIZE+H2D_68B_POISON_BIT];
                end
                {h2d_rsp_msg_s[1], h2d_rsp_msg_s[0], h2d_hdr_msg_s[0]} = cxl_flit_data_i[CXL_HDR_SIZE+:(H2D_68B_DHDR_SIZE+2*H2D_68B_RESP_SIZE)];
                h2d_rsp_idx_s = 2;
            end
            3'b010: begin // H2 Slot - CXL.cache Req + CXL.cache Data Header
                if(cxl_flit_data_i[CXL_HDR_SIZE+H2D_68B_REQ_SIZE]) begin
                  rollover_inc_s = rollover_inc_s + (cxl_flit_hdr_s.Sz ? 4 : 2);
                  poisoned_data_s[0] = poisoned_data_s[0] | cxl_flit_data_i[CXL_HDR_SIZE+H2D_68B_REQ_SIZE+H2D_68B_POISON_BIT];
                end
                {h2d_hdr_msg_s[0], h2d_req_msg_s[0]} = cxl_flit_data_i[CXL_HDR_SIZE+:(H2D_68B_REQ_SIZE+H2D_68B_DHDR_SIZE)];
                h2d_req_idx_s = 1;
            end
            3'b011: begin // H3 MDH Slot - 4 CXL.cache Data Header
                for (int i = 0; i < 4; i++) begin
                    if(cxl_flit_data_i[CXL_HDR_SIZE+i*H2D_68B_DHDR_SIZE]) begin
                      rollover_inc_s = rollover_inc_s + (cxl_flit_hdr_s.Sz ? 4 : 2);
                      poisoned_data_s[0] = poisoned_data_s[0] | cxl_flit_data_i[CXL_HDR_SIZE+i*H2D_68B_DHDR_SIZE+H2D_68B_POISON_BIT];
                    end
                end

                {h2d_hdr_msg_s[3], h2d_hdr_msg_s[2], h2d_hdr_msg_s[1], h2d_hdr_msg_s[0]} = cxl_flit_data_i[CXL_HDR_SIZE+:(4*H2D_68B_DHDR_SIZE)];
            end
            3'b100: begin // H4 Slot - CXL.mem RwD Header
                if(cxl_flit_data_i[CXL_HDR_SIZE]) begin
                  rollover_inc_s = rollover_inc_s + (4 + cxl_flit_hdr_s.BE);
                  poisoned_data_s[1] = poisoned_data_s[1] | cxl_flit_data_i[CXL_HDR_SIZE+M2S_68B_POISON_BIT];
                end
                {m2s_hdr_msg_s[0]} = cxl_flit_data_i[CXL_HDR_SIZE+:(M2S_68B_DHDR_SIZE)];
            end
            3'b101: begin // H5 Slot - CXL.mem Req Only
                rollover_inc_s = rollover_inc_s;

                {m2s_ndr_msg_s[0]} = cxl_flit_data_i[CXL_HDR_SIZE+:(M2S_68B_NDR_SIZE)];
                m2s_ndr_idx_s = 1;
            end
            default: begin
                rsvd_enc_error_s = cxl_flit_valid_i;
                rollover_inc_s = rollover_inc_s;
            end
        endcase

        // Device Slot1-3 Rollover Counter
        for (int s = 0; s < 3; s++) begin
            slot_sel_s = (s == 2) ? cxl_flit_hdr_s.Slot3 : ((s == 1) ? cxl_flit_hdr_s.Slot2 : cxl_flit_hdr_s.Slot1);
            slot_idx_s = (unsigned'(s)+1)*128;

            case (slot_sel_s)
                3'b000: begin // G0 Slot - Decrement Rollover
                    rollover_dec_s = rollover_dec_s + 1;
                    if (!cxl_rx_crc_error_i) hdr_data_nxt   = {cxl_flit_data_i[slot_idx_s+:128], hdr_data_nxt[511:128]};
                end
                3'b001: begin // G1 Slot - 4 CXL.cache Resp
                    rollover_inc_s = rollover_inc_s;

                    if (cxl_flit_data_i[slot_idx_s]) h2d_rsp_msg_s[h2d_rsp_idx_s] = cxl_flit_data_i[slot_idx_s+:H2D_68B_RESP_SIZE]; slot_idx_s+=H2D_68B_RESP_SIZE; h2d_rsp_idx_s++;
                    if (cxl_flit_data_i[slot_idx_s]) h2d_rsp_msg_s[h2d_rsp_idx_s] = cxl_flit_data_i[slot_idx_s+:H2D_68B_RESP_SIZE]; slot_idx_s+=H2D_68B_RESP_SIZE; h2d_rsp_idx_s++;
                    if (cxl_flit_data_i[slot_idx_s]) h2d_rsp_msg_s[h2d_rsp_idx_s] = cxl_flit_data_i[slot_idx_s+:H2D_68B_RESP_SIZE]; slot_idx_s+=H2D_68B_RESP_SIZE; h2d_rsp_idx_s++;
                    if (cxl_flit_data_i[slot_idx_s]) h2d_rsp_msg_s[h2d_rsp_idx_s] = cxl_flit_data_i[slot_idx_s+:H2D_68B_RESP_SIZE]; slot_idx_s+=H2D_68B_RESP_SIZE; h2d_rsp_idx_s++;
                end
                3'b010: begin // G2 Slot - CXL.cache Req + CXL.cache Data Header + CXL.cache Resp
                    if(cxl_flit_data_i[slot_idx_s+H2D_68B_REQ_SIZE]) begin
                      rollover_inc_s = rollover_inc_s + (cxl_flit_hdr_s.Sz ? 4 : 2);
                      poisoned_data_s[0] = poisoned_data_s[0] | cxl_flit_data_i[slot_idx_s+H2D_68B_REQ_SIZE+H2D_68B_POISON_BIT];
                    end
                    if (cxl_flit_data_i[slot_idx_s]) h2d_req_msg_s[h2d_req_idx_s] = cxl_flit_data_i[slot_idx_s+:H2D_68B_REQ_SIZE] ; slot_idx_s+=H2D_68B_REQ_SIZE ; h2d_req_idx_s++;
                    if (cxl_flit_data_i[slot_idx_s]) h2d_hdr_msg_s[0]             = cxl_flit_data_i[slot_idx_s+:H2D_68B_DHDR_SIZE]; slot_idx_s+=H2D_68B_DHDR_SIZE;
                    if (cxl_flit_data_i[slot_idx_s]) h2d_rsp_msg_s[h2d_rsp_idx_s] = cxl_flit_data_i[slot_idx_s+:H2D_68B_RESP_SIZE]; slot_idx_s+=H2D_68B_RESP_SIZE; h2d_rsp_idx_s++;
                end
                3'b011: begin // G3 MDH Slot - 4 CXL.cache Data Header + CXL.cache Resp
                    for (int i = 0; i < 4; i++) begin
                        if(cxl_flit_data_i[slot_idx_s+i*H2D_68B_DHDR_SIZE]) begin
                          rollover_inc_s = rollover_inc_s + (cxl_flit_hdr_s.Sz ? 4 : 2);
                          poisoned_data_s[0] = poisoned_data_s[0] | cxl_flit_data_i[slot_idx_s+i*H2D_68B_DHDR_SIZE+H2D_68B_POISON_BIT];
                        end
                    end

                    {h2d_hdr_msg_s[3], h2d_hdr_msg_s[2], h2d_hdr_msg_s[1], h2d_hdr_msg_s[0]} = cxl_flit_data_i[slot_idx_s+:4*H2D_68B_DHDR_SIZE]; slot_idx_s+=(4*H2D_68B_DHDR_SIZE);
                    if (cxl_flit_data_i[slot_idx_s]) h2d_rsp_msg_s[h2d_rsp_idx_s] = cxl_flit_data_i[slot_idx_s+:H2D_68B_RESP_SIZE]; slot_idx_s+=H2D_68B_RESP_SIZE; h2d_rsp_idx_s++;
                end
                3'b100: begin // G4 Slot - CXL.mem Req + CXL.cache Data Header
                    if(cxl_flit_data_i[slot_idx_s+(M2S_68B_NDR_SIZE+1)]) begin
                      rollover_inc_s = rollover_inc_s + (cxl_flit_hdr_s.Sz ? 4 : 2); // +1 Reserved Bit
                      poisoned_data_s[0] = poisoned_data_s[0] | cxl_flit_data_i[slot_idx_s+(M2S_68B_NDR_SIZE+1)+H2D_68B_POISON_BIT];
                    end
                    if (cxl_flit_data_i[slot_idx_s]) m2s_ndr_msg_s[m2s_ndr_idx_s] = cxl_flit_data_i[slot_idx_s+:M2S_68B_NDR_SIZE] ; slot_idx_s+=(M2S_68B_NDR_SIZE+1); m2s_ndr_idx_s++;
                    if (cxl_flit_data_i[slot_idx_s]) h2d_hdr_msg_s[0]             = cxl_flit_data_i[slot_idx_s+:H2D_68B_DHDR_SIZE]; slot_idx_s+=H2D_68B_DHDR_SIZE;
                end
                3'b101: begin // G5 Slot - CXL.mem RwD Header + CXL.cache Resp
                    if(cxl_flit_data_i[slot_idx_s]) begin
                      rollover_inc_s = rollover_inc_s + (4 + cxl_flit_hdr_s.BE);
                      poisoned_data_s[1] = poisoned_data_s[1] | cxl_flit_data_i[slot_idx_s+0+M2S_68B_POISON_BIT];
                    end
                    m2s_hdr_msg_s[0]             = cxl_flit_data_i[slot_idx_s+:M2S_68B_DHDR_SIZE]; slot_idx_s+=(M2S_68B_DHDR_SIZE+1);
                    if (cxl_flit_data_i[slot_idx_s]) h2d_rsp_msg_s[h2d_rsp_idx_s] = cxl_flit_data_i[slot_idx_s+:H2D_68B_RESP_SIZE]; slot_idx_s+=H2D_68B_RESP_SIZE; h2d_rsp_idx_s++;
                end
                default: begin
                    rsvd_enc_error_s = cxl_flit_valid_i;
                    rollover_inc_s = rollover_inc_s;
                end
            endcase
        end
      end // if (!cxl_device_mode)
      // -------------------------------------------------------------------------------------
      else
      // -------------------------------------------------------------------------------------
      // Host Unpacker
      // -------------------------------------------------------------------------------------
      if (cxl_device_mode) begin
        // Host Slot0 Rollover Counter
        case (cxl_flit_hdr_s.Slot0)
            3'b000: begin // H0 Slot - CXL.cache Data Header + 2 CXL.cache Resp + CXL.mem NDR
                if(cxl_flit_data_i[CXL_HDR_SIZE]) begin
                  rollover_inc_s = rollover_inc_s + ((cxl_flit_hdr_s.Sz ? 4 : 2) + cxl_flit_hdr_s.BE);
                  poisoned_data_s[0] = poisoned_data_s[0] | cxl_flit_data_i[CXL_HDR_SIZE+D2H_68B_POISON_BIT];
                end
                {d2h_rsp_msg_s[1], d2h_rsp_msg_s[0], d2h_hdr_msg_s[0]} = cxl_flit_data_i[CXL_HDR_SIZE+:(D2H_68B_DHDR_SIZE+2*D2H_68B_RESP_SIZE)];
                s2m_ndr_msg_s[0] = cxl_flit_data_i[(CXL_HDR_SIZE+D2H_68B_DHDR_SIZE+2*D2H_68B_RESP_SIZE)+:S2M_68B_NDR_SIZE];
                s2m_ndr_idx_s = 1; // d2h_rsp_idx_s = 2; // Commented as it overflows
            end
            3'b001: begin // H1 Slot - CXL.cache Req + CXL.cache Data Header
                if(cxl_flit_data_i[CXL_HDR_SIZE+D2H_68B_REQ_SIZE]) begin
                  rollover_inc_s = rollover_inc_s + ((cxl_flit_hdr_s.Sz ? 4 : 2) + cxl_flit_hdr_s.BE);
                  poisoned_data_s[0] = poisoned_data_s[0] | cxl_flit_data_i[CXL_HDR_SIZE+D2H_68B_REQ_SIZE+D2H_68B_POISON_BIT];
                end
                {d2h_hdr_msg_s[0], d2h_req_msg_s[0]} = cxl_flit_data_i[CXL_HDR_SIZE+:(D2H_68B_REQ_SIZE+D2H_68B_DHDR_SIZE)];
                d2h_req_idx_s = 1;
            end
            3'b010: begin // H2 MDH Slot - 4 CXL.cache Data Header + CXL.cache Resp
                for (int i = 0; i < 4; i++) begin
                  if(cxl_flit_data_i[CXL_HDR_SIZE+i*D2H_68B_DHDR_SIZE])begin
                    rollover_inc_s = rollover_inc_s + (cxl_flit_hdr_s.Sz ? 4 : 2);
                    poisoned_data_s[0] = poisoned_data_s[0] | cxl_flit_data_i[CXL_HDR_SIZE+i*D2H_68B_DHDR_SIZE+D2H_68B_POISON_BIT];
                  end
                end

                {d2h_rsp_msg_s[0], d2h_hdr_msg_s[3], d2h_hdr_msg_s[2], d2h_hdr_msg_s[1], d2h_hdr_msg_s[0]} = cxl_flit_data_i[CXL_HDR_SIZE+:(4*D2H_68B_DHDR_SIZE+D2H_68B_RESP_SIZE)];
                d2h_rsp_idx_s = 1;
            end
            3'b011: begin // H3 Slot - CXL.mem DRS Header + CXL.mem NDR
              if(cxl_flit_data_i[CXL_HDR_SIZE]) begin
                rollover_inc_s = rollover_inc_s + (cxl_flit_hdr_s.Sz ? 4 : 2);
                poisoned_data_s[1] = poisoned_data_s[1] | cxl_flit_data_i[CXL_HDR_SIZE+S2M_68B_POISON_BIT];
              end
                {s2m_ndr_msg_s[0], s2m_hdr_msg_s[0]} = cxl_flit_data_i[CXL_HDR_SIZE+:(S2M_68B_DHDR_SIZE+S2M_68B_NDR_SIZE)];
                s2m_ndr_idx_s = 1;
            end
            3'b100: begin // H4 Slot - 2 CXL.mem NDR
                rollover_inc_s = rollover_inc_s;

                {s2m_ndr_msg_s[1], s2m_ndr_msg_s[0]} = s2m_ndr_msg_reorder(cxl_flit_data_i[CXL_HDR_SIZE+:(2*S2M_68B_NDR_SIZE)]);
                // s2m_ndr_idx_s = 2; // Commented as it overflows
            end
            3'b101: begin // H5 MDH Slot - 2 CXL.mem DRS Header
                for (int i = 0; i < 2; i++) begin
                  if(cxl_flit_data_i[CXL_HDR_SIZE+i*S2M_68B_DHDR_SIZE]) begin
                    rollover_inc_s = rollover_inc_s + (cxl_flit_hdr_s.Sz ? 4 : 2);
                    poisoned_data_s[1] = poisoned_data_s[1] | cxl_flit_data_i[CXL_HDR_SIZE+i*S2M_68B_DHDR_SIZE+S2M_68B_POISON_BIT];
                  end

                    {s2m_hdr_msg_s[1], s2m_hdr_msg_s[0]} = cxl_flit_data_i[CXL_HDR_SIZE+:(2*S2M_68B_DHDR_SIZE)];
                end
            end
            default: begin
                rsvd_enc_error_s = cxl_flit_valid_i;
                rollover_inc_s = rollover_inc_s;
            end
        endcase

        // Host Slot1-3 Rollover Counter
        for (int s = 0; s < 3; s++) begin
            slot_sel_s = (s == 2) ? cxl_flit_hdr_s.Slot3 : ((s == 1) ? cxl_flit_hdr_s.Slot2 : cxl_flit_hdr_s.Slot1);
            slot_idx_s = (unsigned'(s)+1)*128;

            case (slot_sel_s)
                3'b000: begin // G0 Slot - Decrement Rollover
                    rollover_dec_s = rollover_dec_s + 1;
                    if (!cxl_rx_crc_error_i) hdr_data_nxt   = {cxl_flit_data_i[slot_idx_s+:128], hdr_data_nxt[511:128]};
                end
                3'b001: begin // G1 - CXL.cache Req + 2 CXL.cache Resp
                    rollover_inc_s = rollover_inc_s;

                    if (cxl_flit_data_i[slot_idx_s]) d2h_req_msg_s[d2h_req_idx_s] = cxl_flit_data_i[slot_idx_s+:D2H_68B_REQ_SIZE ]; slot_idx_s+=D2H_68B_REQ_SIZE ; d2h_req_idx_s++;
                    if (cxl_flit_data_i[slot_idx_s]) d2h_rsp_msg_s[d2h_rsp_idx_s] = cxl_flit_data_i[slot_idx_s+:D2H_68B_RESP_SIZE]; slot_idx_s+=D2H_68B_RESP_SIZE; d2h_rsp_idx_s++;
                    if (cxl_flit_data_i[slot_idx_s]) d2h_rsp_msg_s[d2h_rsp_idx_s] = cxl_flit_data_i[slot_idx_s+:D2H_68B_RESP_SIZE]; slot_idx_s+=D2H_68B_RESP_SIZE; d2h_rsp_idx_s++;
                end
                3'b010: begin // G2 Slot - CXL.cache Req + CXL.cache Data Header + CXL.cache Resp
                    if(cxl_flit_data_i[slot_idx_s+D2H_68B_REQ_SIZE]) begin
                      rollover_inc_s = rollover_inc_s + ((cxl_flit_hdr_s.Sz ? 4 : 2) + cxl_flit_hdr_s.BE);
                      poisoned_data_s[0] = poisoned_data_s[0] | cxl_flit_data_i[slot_idx_s+D2H_68B_REQ_SIZE+D2H_68B_POISON_BIT];
                    end
                    if (cxl_flit_data_i[slot_idx_s]) d2h_req_msg_s[d2h_req_idx_s] = cxl_flit_data_i[slot_idx_s+:D2H_68B_REQ_SIZE ]; slot_idx_s+=D2H_68B_REQ_SIZE ; d2h_req_idx_s++;
                    if (cxl_flit_data_i[slot_idx_s]) d2h_hdr_msg_s[0]             = cxl_flit_data_i[slot_idx_s+:D2H_68B_DHDR_SIZE]; slot_idx_s+=D2H_68B_DHDR_SIZE;     
                    if (cxl_flit_data_i[slot_idx_s]) d2h_rsp_msg_s[d2h_rsp_idx_s] = cxl_flit_data_i[slot_idx_s+:D2H_68B_RESP_SIZE]; slot_idx_s+=D2H_68B_RESP_SIZE; d2h_rsp_idx_s++;
                end
                3'b011: begin // G3 MDH Slot - 4 CXL.cache Data Header
                    for (int i = 0; i < 4; i++) begin
                      if(cxl_flit_data_i[slot_idx_s+i*D2H_68B_DHDR_SIZE]) begin 
                        rollover_inc_s = rollover_inc_s + (cxl_flit_hdr_s.Sz ? 4 : 2);
                        poisoned_data_s[0] = poisoned_data_s[0] | cxl_flit_data_i[slot_idx_s+i*D2H_68B_DHDR_SIZE+D2H_68B_POISON_BIT];
                      end
                    end

                    {d2h_hdr_msg_s[3], d2h_hdr_msg_s[2], d2h_hdr_msg_s[1], d2h_hdr_msg_s[0]} = cxl_flit_data_i[slot_idx_s+:(4*D2H_68B_DHDR_SIZE)];
                end
                3'b100: begin // G4 Slot - CXL.mem DRS Header + 2 CXL.mem NDR
                    if (cxl_flit_data_i[slot_idx_s]) begin 
                      rollover_inc_s                                               = rollover_inc_s + (cxl_flit_hdr_s.Sz ? 4 : 2)*cxl_flit_data_i[slot_idx_s+0];
                      poisoned_data_s[1]                                           = poisoned_data_s[1] | cxl_flit_data_i[slot_idx_s+0+S2M_68B_POISON_BIT];
                      s2m_hdr_msg_s[0]                                             = cxl_flit_data_i[slot_idx_s+:S2M_68B_DHDR_SIZE]; 
                    end                                                           
                    slot_idx_s                                                    += S2M_68B_DHDR_SIZE;      
                    s2m_ndr_x2_msg_s                                               = s2m_ndr_msg_reorder(cxl_flit_data_i[slot_idx_s+:(2*S2M_68B_NDR_SIZE)]); slot_idx_s = 0;

                    if (s2m_ndr_x2_msg_s[slot_idx_s]) s2m_ndr_msg_s[s2m_ndr_idx_s] = s2m_ndr_x2_msg_s[slot_idx_s+:S2M_68B_NDR_SIZE]; slot_idx_s+=S2M_68B_NDR_SIZE; s2m_ndr_idx_s++;
                    if (s2m_ndr_x2_msg_s[slot_idx_s]) s2m_ndr_msg_s[s2m_ndr_idx_s] = s2m_ndr_x2_msg_s[slot_idx_s+:S2M_68B_NDR_SIZE]; slot_idx_s+=S2M_68B_NDR_SIZE; s2m_ndr_idx_s++;
                end
                3'b101: begin // G5 Slot - 2 CXL.mem NDR
                    rollover_inc_s = rollover_inc_s;

                    s2m_ndr_x2_msg_s = s2m_ndr_msg_reorder(cxl_flit_data_i[slot_idx_s+:(2*S2M_68B_NDR_SIZE)]); slot_idx_s = 0;

                    if (s2m_ndr_x2_msg_s[slot_idx_s]) s2m_ndr_msg_s[s2m_ndr_idx_s] = s2m_ndr_x2_msg_s[slot_idx_s+:S2M_68B_NDR_SIZE]; slot_idx_s+=S2M_68B_NDR_SIZE; s2m_ndr_idx_s++;
                    if (s2m_ndr_x2_msg_s[slot_idx_s]) s2m_ndr_msg_s[s2m_ndr_idx_s] = s2m_ndr_x2_msg_s[slot_idx_s+:S2M_68B_NDR_SIZE]; slot_idx_s+=S2M_68B_NDR_SIZE; s2m_ndr_idx_s++;
                end
                3'b110: begin // G6 Slot - 3 CXL.mem DRS Header
                    for (int i = 0; i < 3; i++) begin
                      if(cxl_flit_data_i[slot_idx_s+i*S2M_68B_DHDR_SIZE]) begin
                        rollover_inc_s = rollover_inc_s + (cxl_flit_hdr_s.Sz ? 4 : 2);
                        poisoned_data_s[1] = poisoned_data_s[1] | cxl_flit_data_i[slot_idx_s+i*S2M_68B_DHDR_SIZE+S2M_68B_POISON_BIT];
                      end
                    end

                    {s2m_hdr_msg_s[2], s2m_hdr_msg_s[1], s2m_hdr_msg_s[0]} = cxl_flit_data_i[slot_idx_s+:(3*S2M_68B_DHDR_SIZE)];
                end
                default: begin
                    rsvd_enc_error_s = cxl_flit_valid_i;
                    rollover_inc_s = rollover_inc_s;
                end
            endcase
        end
      end // if (cxl_device_mode)
      // -------------------------------------------------------------------------------------
    end // if (cxl_flit_valid_i && !cxl_flit_adf_o)
    else if (cxl_flit_valid_crc_s && cxl_flit_adf_o) begin
        // If ADF Flit capture the flit into data register if there is no CRC error
        hdr_data_nxt = cxl_flit_data_i;
    end
end // End of CXL Flit Unpacker
// -------------------------------------------------------------------------------------





// -------------------------------------------------------------------------------------
// | Legal values of Sz and BE Fields           |
// -------------------------------------------------------------------------------------
// | Type of Data Transfer | 32B Transfer | BE  |
// |-----------------------|--------------|-----|
// | CXL.cache H2D Data    | Yes          |  No |
// | CXL.mem M2S Data      |  No          | Yes |
// | CXL.cache D2H Data    | Yes          | Yes |
// | CXL.mem S2M Data      | Yes          |  No |
// -------------------------------------------------------------------------------------

logic hdr_be_data_msg_s;   // Data Message that supports Byte Enable
logic hdr_32b_data_msg_s;  // Data Message that supports Size bit

assign hdr_be_data_msg_s  = (1'b0 || d2h_hdr_msg_s[0][0]
 || m2s_hdr_msg_s[0][0] );

assign hdr_32b_data_msg_s = (1'b0 || d2h_hdr_msg_s[0][0]
 || s2m_hdr_msg_s[0][0]
 || h2d_hdr_msg_s[0][0] );
// -------------------------------------------------------------------------------------


// -------------------------------------------------------------------------------------
// Latch Byte Enable bit from the Flit Header that contains data message for which byte
// enable is possible. See table above.
// -------------------------------------------------------------------------------------
always_comb begin
    if  (cxl_flit_valid_crc_s && !cxl_flit_adf_o) begin
        hdr_be_nxt = hdr_be_data_msg_s ? cxl_flit_hdr_s.BE : 1'b0;
    end
    else begin
        hdr_be_nxt = hdr_be_r;
    end
end
// -------------------------------------------------------------------------------------

// -------------------------------------------------------------------------------------
// Latch Size bit from the Flit Header that contains data message for which 32B data
// transfes is possible. See table above.
//
// Track the number of 32B data transfers. Second 32B data transfer completes first one.
// -------------------------------------------------------------------------------------
always_comb begin
    if  (cxl_flit_valid_crc_s && !cxl_flit_adf_o) begin
        hdr_sz_nxt = hdr_32b_data_msg_s ? cxl_flit_hdr_s.Sz : 1'b1;
    end
    else begin
        hdr_sz_nxt = hdr_sz_r;
    end
end

always_comb begin
    if (cxl_flit_valid_crc_s && !cxl_flit_adf_o && !cxl_flit_hdr_s.Sz && hdr_32b_data_msg_s) begin
        hdr_sz_cntr_nxt  = hdr_sz_cntr_r[1] ? 2'd1 : (hdr_sz_cntr_r + 1);
    end
    else begin
        hdr_sz_cntr_nxt  = hdr_sz_cntr_r[1] ? 2'd0 : hdr_sz_cntr_r;
    end
end
// -------------------------------------------------------------------------------------

// -------------------------------------------------------------------------------------
// For 32B transactions, selects Upper/Lower Half based on the ChunkValid bit in the first D2H/H2D Data Header:
// * If 0, it indicates the Lower 32B
// * If 1, it indicates the Upper 32B
// Must be ignored for 64B transactions.
// -------------------------------------------------------------------------------------
always_comb begin
    if (cxl_flit_valid_crc_s && !cxl_flit_adf_o && !hdr_sz_cntr_r[0]) begin
        //
        // H2D Data transfers may be done in any order.
        // D2H Data transfers must come in natural chunk order, therefore commented.
        hdr_sz_chunk_nxt = !cxl_flit_hdr_s.Sz && (1'b0 /* || (d2h_hdr_msg_s[0][0] && d2h_hdr_msg_s[0][D2H_CHUNK_BIT]) */
 || (h2d_hdr_msg_s[0][0] && h2d_hdr_msg_s[0][H2D_CHUNK_BIT]) );
    end
    else begin
        hdr_sz_chunk_nxt = hdr_sz_chunk_r;
    end
end
// -------------------------------------------------------------------------------------


// -------------------------------------------------------------------------------------
// Latch Protocol Flags to identify the associated data as Cache or Mem
// -------------------------------------------------------------------------------------
always_comb begin
    if (cxl_flit_valid_crc_s && cxl_flit_adf_o) begin
        // If ADF Flit and no data is expected to rollover to the next flit then
        // Protocol flags needs to be reset, otherwise we should preserve the flags
        hdr_cache_nxt  = (rollover_cnt_r == 5'd4) ? 1'b0 : hdr_cache_r;
        hdr_mem_nxt    = (rollover_cnt_r == 5'd4) ? 1'b0 : hdr_mem_r  ;
    end
    else if (cxl_flit_valid_crc_s && !cxl_flit_adf_o) begin
        // If the Header flit then set the Protocol flags based on the corresponding
        // data header valid bits
        hdr_cache_nxt = 1'b0 || (cxl_device_mode ? d2h_hdr_msg_s[0][0] : h2d_hdr_msg_s[0][0]);
        // If EndPoint (device_mode=0) or Root-Complex (device_mode=1) with Non-Reversed Protocol then select m2s_hdr_msg_s
        hdr_mem_nxt   = 1'b0 || ( (cxl_device_mode) ? s2m_hdr_msg_s[0][0] : m2s_hdr_msg_s[0][0] );
    end
    else begin
        // If there is no valid flit in the cycle then preserve Protocol flags
        hdr_cache_nxt  = hdr_cache_r;
        hdr_mem_nxt    = hdr_mem_r  ;
    end
end
// -------------------------------------------------------------------------------------


// -------------------------------------------------------------------------------------
// Latch Reverse Protocol bit from the Flit Header or cxl_device_mode
// -------------------------------------------------------------------------------------
always_comb begin
    if  (cxl_flit_valid_crc_s && !cxl_flit_adf_o) begin
        hdr_mode_nxt = cxl_device_mode;
    end
    else begin
        hdr_mode_nxt = hdr_mode_r;
    end
end
// -------------------------------------------------------------------------------------


// -------------------------------------------------------------------------------------
// Data Mux - data is selected based on the initial offset in the Data Header cycle.
//
// Offset reprsents the number of data chunks initially captured in the hdr_data_r
// in the Header cycle. For example, if offset=3 then 3 chunks of data is captured in
// hdr_data_r and we need to append only one last chunk of data from the current flit
// (cxl_flit_data_i) to complete data.
//
// The appending data chunks depend on whether it is ADF or Header flit as in ADF Slot0
// carries data, while for non-ADF the data starts from Slot1.
//
// Do not use Flit Valid after CRC for timing optimization on the datapath.
//
// -------------------------------------------------------------------------------------
always_comb begin
// spyglass disable_block W164a
// SMD: Identifies assignments in which the LHS width is less than the RHS width
// SJ: Rollover decrement is always greater than the rollover counter in the Header cycle. No overflow is possible.
    data_offset_nxt = (cxl_flit_valid_crc_s && !cxl_flit_adf_o) ? (rollover_dec_s - rollover_cnt_r[1:0]) : data_offset_r;
// spyglass enable_block W164a
end

always_comb begin
    hdr_data_vld_nxt = (|rollover_cnt_nxt) || (cxl_flit_valid_crc_s && !cxl_flit_adf_o && !cxl_flit_hdr_s.Sz && data_offset_nxt[1]);
end

always_comb begin
    if (cxl_flit_adf_o) begin
        case (data_offset_r)
            2'b01  : hdr_data_s = {cxl_flit_data_i[383:0], hdr_data_r[511:384]}; // Rollover=3
            2'b10  : hdr_data_s = {cxl_flit_data_i[255:0], hdr_data_r[511:256]}; // Rollover=2
            2'b11  : hdr_data_s = {cxl_flit_data_i[127:0], hdr_data_r[511:128]}; // Rollover=1
            default: hdr_data_s = cxl_flit_data_i;                               // Rollover=4
        endcase
    end
    else begin
        if (!hdr_sz_r) begin
            // For 32B transactions, based on the data offset capture data rollovered to
            // the next Header cycle starting from Slot1.
            // If 32B data transfer interleaving is enabled then they may be done in any order
            if (hdr_sz_chunk_r)
                case (data_offset_r) // Upper 32B first
                    2'b01  : hdr_data_s = {hdr_data32b_r, cxl_flit_data_i[255:128], hdr_data_r[511:384]}; // Rollover=1
                    2'b10  : hdr_data_s = {hdr_data32b_r,                           hdr_data_r[511:256]}; // No Rollover (2 Data only)
                    2'b11  : hdr_data_s = {hdr_data32b_r,                           hdr_data_r[383:128]}; // No Rollover (2 Data + BE)
                    default: hdr_data_s = {hdr_data32b_r, cxl_flit_data_i[383:128]                     }; // Rollover=2
                endcase
            else
                case (data_offset_r)  // Lower 32B first
                    2'b01  : hdr_data_s = {cxl_flit_data_i[255:128], hdr_data_r[511:384], hdr_data32b_r}; // Rollover=1
                    2'b10  : hdr_data_s = {                          hdr_data_r[511:256], hdr_data32b_r}; // No Rollover (2 Data only)
                    2'b11  : hdr_data_s = {                          hdr_data_r[383:128], hdr_data32b_r}; // No Rollover (2 Data + BE)
                    default: hdr_data_s = {cxl_flit_data_i[383:128]                     , hdr_data32b_r}; // Rollover=2
                endcase
        end
        else
        begin
            // For 64B transactions, based on the data offset capture data rollovered to
            // the next Header cycle starting from Slot1.
            // If Data Offset = 0, there could be no rollover of data to the next Header cycle (Invalid case)
            case (data_offset_r)
                2'b01  : hdr_data_s = {cxl_flit_data_i[511:128], hdr_data_r[511:384]}; // Rollover=3
                2'b10  : hdr_data_s = {cxl_flit_data_i[383:128], hdr_data_r[511:256]}; // Rollover=2
                2'b11  : hdr_data_s = {cxl_flit_data_i[255:128], hdr_data_r[511:128]}; // Rollover=1
                default: hdr_data_s = cxl_flit_data_i; // No Rollover=0 in Header Cycle (Invalid case)
            endcase
        end
    end
end

always_comb begin
    if (cxl_flit_valid_i && cxl_flit_adf_o) begin
        hdr_data_vld_s = 1'b1;
        hdr_data_crc_s = 1'b1;
    end
    else if (!cxl_flit_adf_o) begin
        if (!hdr_sz_r) begin
            hdr_data_crc_s = !data_offset_r[1];
            case (data_offset_r)
                2'b01  : hdr_data_vld_s = cxl_flit_valid_i && hdr_data_vld_r && hdr_sz_cntr_r[1]; // 32B - Rollover=1
                2'b10  : hdr_data_vld_s =                     hdr_data_vld_r && hdr_sz_cntr_r[1] && (hdr_be_r ? cxl_flit_valid_i : 1'b1); // 32B - Rollover=0
                2'b11  : hdr_data_vld_s =                     hdr_data_vld_r && hdr_sz_cntr_r[1]; // 32B - Rollover=0
                default: hdr_data_vld_s = cxl_flit_valid_i && hdr_data_vld_r && hdr_sz_cntr_r[1]; // 32B - Rollover=2
            endcase
        end else
        begin
            hdr_data_crc_s = data_offset_r != 2'b00;
            case (data_offset_r)
                2'b01  : hdr_data_vld_s = cxl_flit_valid_i && hdr_data_vld_r; // 64B - Rollover=3
                2'b10  : hdr_data_vld_s = cxl_flit_valid_i && hdr_data_vld_r; // 64B - Rollover=2
                2'b11  : hdr_data_vld_s = cxl_flit_valid_i && hdr_data_vld_r; // 64B - Rollover=1
                default: hdr_data_vld_s = 1'b0; // No Rollover=0 in Header Cycle (Invalid case)
            endcase
        end
    end
    else begin
        hdr_data_vld_s = 1'b0;
        hdr_data_crc_s = 1'b0;
    end
end

assign hdr_store32b_s = hdr_data_vld_r && !hdr_sz_r && hdr_sz_cntr_r[0];//cxl_flit_valid_i && hdr_sz_cntr_r[0];

always_comb begin
    if (hdr_store32b_s) begin
        case (data_offset_r)
            2'b01  : hdr_data32b_nxt = {cxl_flit_data_i[255:128], hdr_data_r[511:384]}; // Rollover=1
            2'b10  : hdr_data32b_nxt =                            hdr_data_r[511:256];  // No Rollover (2 Data only)
            2'b11  : hdr_data32b_nxt =                            hdr_data_r[383:128];  // No Rollover (2 Data + BE)
            default: hdr_data32b_nxt = cxl_flit_data_i[383:128];                        // Rollover=2
        endcase
    end
    else hdr_data32b_nxt = hdr_data32b_r;
end
// -------------------------------------------------------------------------------------


// -------------------------------------------------------------------------------------
// Byte Enable - may be placed only in the Slots 1-3 in case of rollover.
//
// For 64B transactions if there is no rollover in the next cycle (rollover = 4),
// byte enable is always in the last slot - Slot3 of the current flit.
//
// For 32B transactions if there is no rollover (rollover = 0), byte enable is always
// placed in the Slot3 of the previous data: HDR-G0-G0-G0(BE).
// -------------------------------------------------------------------------------------
always_comb begin
    if (hdr_be_r) begin
        hdr_be_crc_s   = |rollover_cnt_r;
        if (!hdr_sz_r) begin
            // If Byte Enable is set then byte enable is valid of 32B data transfer:
            // * if cxl_flit_valid_i=1 and there is a rollover to the Header cycle (rollover>0) or
            // * if cxl_flit_valid_i=0 and header data register is valid with 3 data slots available in the data register
            hdr_be_valid_s = hdr_sz_cntr_r[1] && ((cxl_flit_valid_i && (|rollover_cnt_r[1:0])) || (hdr_data_vld_r && (data_offset_r == 2'b11)));

            case (rollover_cnt_r[1:0])
                2'd3   : hdr_be_data_s = cxl_flit_data_i[384+:64] | hdr_be32b_r; // Slot3 in Header Flit
                2'd2   : hdr_be_data_s = cxl_flit_data_i[256+:64] | hdr_be32b_r; // Slot2 in Header Flit
                2'd1   : hdr_be_data_s = cxl_flit_data_i[128+:64] | hdr_be32b_r; // Slot1 in Header Flit
                default: hdr_be_data_s =      hdr_data_r[384+:64] | hdr_be32b_r; // Otherwise, BE is always in Slot3 of previous flit when Sz=0
            endcase
        end else
        begin
            // If Byte Enable is set then byte enable is valid of 64B data transfer:
            // * if ADF completes data sequence (rollover=4) or
            // * if there is a rollover to the Header cycle (rollover>0)
            hdr_be_valid_s = cxl_flit_valid_i && (cxl_flit_adf_o ? (rollover_cnt_r == 5'd4) : (|rollover_cnt_r[1:0]));

            case (rollover_cnt_r)
                5'd4   : hdr_be_data_s = cxl_flit_data_i[384+:64]; // Slot3 in ADF Flit
                5'd3   : hdr_be_data_s = cxl_flit_data_i[384+:64]; // Slot3 in Header Flit
                5'd2   : hdr_be_data_s = cxl_flit_data_i[256+:64]; // Slot2 in Header Flit
                5'd1   : hdr_be_data_s = cxl_flit_data_i[128+:64]; // Slot1 in Header Flit
                default: hdr_be_data_s =      hdr_data_r[384+:64]; // Otherwise, BE is always in Slot3 of previous flit when Sz=0
            endcase
        end
    end
    else begin
        // If Byte Enable is not set then output all 1's in the data valid cycle
        hdr_be_valid_s = hdr_data_vld_s;
        hdr_be_data_s  = '1;
        hdr_be_crc_s   = hdr_data_crc_s;
    end
end

assign hdr_store32b_be_s = hdr_data_vld_r && hdr_be_r && !hdr_sz_r && hdr_sz_cntr_r[0];

always_comb begin
    if (hdr_store32b_be_s) begin
        case (data_offset_r)
            2'b01  : hdr_be32b_nxt = cxl_flit_data_i[256+:64]; // Rollover=1, Byte Enable in the Slot2 of the current flit
            2'b10  : hdr_be32b_nxt = cxl_flit_data_i[128+:64]; // No Data Rollover (only BE Rollover), Byte Enable in the Slot1 of the current flit
            2'b11  : hdr_be32b_nxt =      hdr_data_r[384+:64]; // No Rollover (2 Data + BE), Byte Enable in the Slot3 of the previous flit
            default: hdr_be32b_nxt = cxl_flit_data_i[384+:64]; // Rollover=2, Byte Enable in the Slot3 of the current flit
        endcase
    end
    else hdr_be32b_nxt = hdr_be32b_r;
end
// -------------------------------------------------------------------------------------


// -------------------------------------------------------------------------------------
// Rollover Counter - change Rollover state if there is no CRC error
// -------------------------------------------------------------------------------------
always_comb begin
    if (cxl_flit_valid_crc_s && cxl_flit_adf_o) begin
        rollover_cnt_nxt = rollover_cnt_r - 4;
    end
    else if (cxl_flit_valid_crc_s) begin
// spyglass disable_block W164a
// SMD: Identifies assignments in which the LHS width is less than the RHS width
// SJ: The design intent never overflows the counter
        rollover_cnt_nxt = (rollover_cnt_r - rollover_dec_s) + rollover_inc_s;
// spyglass enable_block W164a
    end
    else begin
        rollover_cnt_nxt = rollover_cnt_r;
    end
end
// -------------------------------------------------------------------------------------


always_ff @(posedge core_clk or negedge core_rst_n) begin
    if (!core_rst_n) begin
        rollover_cnt_r  <= # TP '0;
        hdr_mode_r      <= # TP '0;
        hdr_be_r        <= # TP '0;
        hdr_cache_r     <= # TP '0;
        hdr_mem_r       <= # TP '0;
        hdr_data_vld_r  <= # TP '0;
        hdr_data_r      <= # TP '0;
        data_offset_r   <= # TP '0;
        hdr_sz_r        <= # TP '0;
        hdr_sz_cntr_r   <= # TP '0;
        hdr_sz_chunk_r  <= # TP '0;
        hdr_data32b_r   <= # TP '0;
        hdr_be32b_r     <= # TP '0;
    end else begin
        rollover_cnt_r  <= # TP rollover_cnt_nxt;
        hdr_mode_r      <= # TP hdr_mode_nxt;
        hdr_be_r        <= # TP hdr_be_nxt;
        hdr_cache_r     <= # TP hdr_cache_nxt;
        hdr_mem_r       <= # TP hdr_mem_nxt;
        hdr_data_vld_r  <= # TP hdr_data_vld_nxt;
        hdr_data_r      <= # TP hdr_data_nxt;
        data_offset_r   <= # TP data_offset_nxt;
        hdr_sz_r        <= # TP hdr_sz_nxt;
        hdr_sz_cntr_r   <= # TP hdr_sz_cntr_nxt;
        hdr_sz_chunk_r  <= # TP hdr_sz_chunk_nxt;
        hdr_data32b_r   <= # TP hdr_data32b_nxt;
        hdr_be32b_r     <= # TP hdr_be32b_nxt;
    end
end

// -------------------------------------------------------------------------------------
// THE CODE BELOW HANDLES CREDIT RETURN FOR 32B DATA TRANSFERS
// -------------------------------------------------------------------------------------
// -------------------------------------------------------------------------------------
// CXL.cache 32B Data Transfers Counter
// -------------------------------------------------------------------------------------
logic       cxl_cache_32b_cntr_inc_r, cxl_cache_32b_cntr_inc_nxt; // Increment 32B Counter when 32B data valid on the Unpacker output
logic       cxl_cache_32b_cred_ret_s;                             // Return one additional credit for 32B data transfers
logic [8:0] cxl_cache_32b_cntr_r, cxl_cache_32b_cntr_nxt;         // Number of data in the RX Buffer shaped with 32B data transfers

assign cxl_rx_cache_crdret_o     = {cxl_cache_32b_cred_ret_s , cxl_tl_cache_crdret_i};
assign cxl_cache_32b_cred_ret_s  = cxl_tl_cache_crdret_i && ((|cxl_cache_32b_cntr_r) || cxl_cache_32b_cntr_inc_r);

always_comb begin
    if (cxl_device_mode)
        cxl_cache_32b_cntr_inc_nxt  = b_unpack_68B.s_cxl_d2h_byte_en_valid[0] && hdr_sz_cntr_r[1] && !hdr_be_crc_s;
    else
        cxl_cache_32b_cntr_inc_nxt  = b_unpack_68B.s_cxl_h2d_data_valid[0] && hdr_sz_cntr_r[1] && !hdr_data_crc_s;
end

always_comb begin
    if (cxl_cache_32b_cntr_inc_r && !cxl_tl_cache_crdret_i && !(&cxl_cache_32b_cntr_r)) begin
        cxl_cache_32b_cntr_nxt = cxl_cache_32b_cntr_r + 1;
    end
    else if (!cxl_cache_32b_cntr_inc_r && cxl_tl_cache_crdret_i && (|cxl_cache_32b_cntr_r)) begin
        cxl_cache_32b_cntr_nxt = cxl_cache_32b_cntr_r - 1;
    end
    else begin
        cxl_cache_32b_cntr_nxt = cxl_cache_32b_cntr_r;
    end
end

always_ff @(posedge core_clk or negedge core_rst_n) begin
    if (!core_rst_n) begin
        cxl_cache_32b_cntr_r     <= #TP '0;
        cxl_cache_32b_cntr_inc_r <= #TP '0;
    end
    else begin
        cxl_cache_32b_cntr_r     <= #TP cxl_cache_32b_cntr_nxt;
        cxl_cache_32b_cntr_inc_r <= #TP cxl_cache_32b_cntr_inc_nxt;
    end
end
// -------------------------------------------------------------------------------------

// -------------------------------------------------------------------------------------
// CXL.mem 32B Data Transfers Counter
// -------------------------------------------------------------------------------------
logic       cxl_mem_32b_cntr_inc_r, cxl_mem_32b_cntr_inc_nxt; // Increment 32B Counter when 32B data valid on the Unpacker output
logic [8:0] cxl_mem_32b_cntr_r, cxl_mem_32b_cntr_nxt;         // Number of data in the RX Buffer shaped with 32B data transfers
logic       cxl_mem_32b_cred_ret_s;                           // Return one additional credit for 32B data transfers

assign cxl_rx_mem_crdret_o      = {cxl_mem_32b_cred_ret_s , cxl_tl_mem_crdret_i};
assign cxl_mem_32b_cred_ret_s   = cxl_tl_mem_crdret_i && ((|cxl_mem_32b_cntr_r) || cxl_mem_32b_cntr_inc_r);

always_comb begin
    cxl_mem_32b_cntr_inc_nxt = '0;
    if (cxl_device_mode)
        cxl_mem_32b_cntr_inc_nxt  = b_unpack_68B.s_cxl_s2m_data_valid[0] && hdr_sz_cntr_r[1] && !hdr_data_crc_s;
    if (!cxl_device_mode)
        cxl_mem_32b_cntr_inc_nxt  = b_unpack_68B.s_cxl_m2s_byte_en_valid[0] && hdr_sz_cntr_r[1] && !hdr_be_crc_s;
end

always_comb begin
    if (cxl_mem_32b_cntr_inc_r && !cxl_tl_mem_crdret_i && !(&cxl_mem_32b_cntr_r)) begin
        cxl_mem_32b_cntr_nxt = cxl_mem_32b_cntr_r + 1;
    end
    else if (!cxl_mem_32b_cntr_inc_r && cxl_tl_mem_crdret_i && (|cxl_mem_32b_cntr_r)) begin
        cxl_mem_32b_cntr_nxt = cxl_mem_32b_cntr_r - 1;
    end
    else begin
        cxl_mem_32b_cntr_nxt = cxl_mem_32b_cntr_r;
    end
end

always_ff @(posedge core_clk or negedge core_rst_n) begin
    if (!core_rst_n) begin
        cxl_mem_32b_cntr_r     <= #TP '0;
        cxl_mem_32b_cntr_inc_r <= #TP '0;
    end
    else begin
        cxl_mem_32b_cntr_r     <= #TP cxl_mem_32b_cntr_nxt;
        cxl_mem_32b_cntr_inc_r <= #TP cxl_mem_32b_cntr_inc_nxt;
    end
end
// -------------------------------------------------------------------------------------



// -------------------------------------------------------------------------------------
// Function to re-order Devload for 2 S2M NDR inputs
// -------------------------------------------------------------------------------------
function automatic [(2*S2M_68B_NDR_SIZE)-1:0] s2m_ndr_msg_reorder (
    input [(2*S2M_68B_NDR_SIZE-1):0] s2m_ndr_msg
);
  begin
    s2m_ndr_msg_reorder = {s2m_ndr_msg[(S2M_68B_NDR_SIZE-S2M_NDR_DEVLOAD_WD)+:S2M_68B_NDR_SIZE], s2m_ndr_msg[(2*S2M_68B_NDR_SIZE-1)-:S2M_NDR_DEVLOAD_WD], s2m_ndr_msg[0+:(S2M_68B_NDR_SIZE-S2M_NDR_DEVLOAD_WD)]};
  end
  return s2m_ndr_msg_reorder;
endfunction
// -------------------------------------------------------------------------------------

endmodule
