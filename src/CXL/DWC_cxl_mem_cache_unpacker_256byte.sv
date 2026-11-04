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
// ---   $Revision: #8 $
// ---   $Id: //dwh/pcie_iip/main/fairbanks/design/CXL/DWC_cxl_mem_cache_unpacker_256byte.sv#8 $
// -------------------------------------------------------------------------------------
// --- Module Description:
// -------------------------------------------------------------------------------------
// CXL Flit Unpacker for 256B Flit Mode
// -------------------------------------------------------------------------------------

`include "include/DWC_pcie_ctl_all_defs.svh"
`include "CXL/pkg/DWC_cxl_pkg.svh"
`include "CXL/svif/DWC_cxl_rxtl_llctrl_if.svh"
module DWC_cxl_mem_cache_unpacker_256byte
  import DWC_cxl_pkg::*;
#(
  parameter TP = `TP
)
                                           (
    // Inputs
    input                                         core_clk,                              // Clock
    input                                         core_rst_n,                            // Asynchronous Active Low Reset
    input                                         cxl_device_mode,                       // CXL Device Type
    input                                         cxl_mdh_disable_i,                     // Disable MDH support
    input                                         cxl_flit_valid_i,                      // Protocol Flit Valid before CRC check
    input                                         cxl_rx_crc_error_i,                    // CRC check error on the received flit
    input                                         cxl_ctrl_flit_vld_i,                   // Filtered Link Layer Control Flit
    input  [FLIT_SLOT_NUM*128-1:0]                cxl_flit_data_i,                       // Protocol Flit Data
    
    input  [HD_DDATA_NUM - 1: 0]                  cxl_tl_cache_crdret_i,                 // Transaction Layer Return Cache Data Credit
    input [MS_SM_DDATA_NUM - 1: 0]                 cxl_tl_mem_crdret_i,                   // Transaction Layer Return Mem Data Credit
    input                                         cxl_256b_rx_poison_i     ,
    input  [3:0]                                  cxl_256b_rx_poison_off_i ,                             
    // Outputs
    output reg [H2D_256B_DDATA_NUM-1:0]           cxl_h2d_poison_bit_o     , 
    output reg [D2H_256B_DDATA_NUM-1:0]           cxl_d2h_poison_bit_o     ,
    output reg [M2S_256B_DDATA_NUM-1:0]           cxl_m2s_poison_bit_o     ,
    output reg [S2M_256B_DDATA_NUM-1:0]           cxl_s2m_poison_bit_o     , 
    output [1:0]                                  cxl_rx_cache_crdret_o,                 // RX Return Cache Data Credit
    output [1:0]                                  cxl_rx_mem_crdret_o,                   // RX Return Mem Data Credit
    output                                        cxl_flit_adf_o,                        // All data flit done as Tx
    output                                        cxl_mdh_error_o,                       // MDH Error
    output                                        rsvd_enc_error_o,                      // CXL Reserved Encoding Violation
    output [1:0]                                  poisoned_data_o,                       // CXL Poison Data Detection
    DWC_cxl_rxtl_llctrl_if.master_mp              b_unpack_256B

);

// Local Parameters
localparam HDR_DATA_MAX_NUM = 8                            ;   // Maximum 8 Data Headers can be tracked at the same
localparam H2D_FMT          = 2'b00                        ;   //[two bits for H2D header  fmt,one bit for byte enable]
localparam D2H_FMT          = 2'b01                        ;   //[two bits for D2H header  fmt,one bit for byte enable]
localparam M2S_FMT          = 2'b10                        ;   //[two bits for M2S header  fmt,one bit for byte enable]
localparam S2M_FMT          = 2'b11                        ;   //[two bits for S2M header  fmt,one bit for byte enable]
localparam FMT              = 4                            ;   //[two bits for each header fmt,one bit for byte enable]
localparam BE_FMT           = 2                            ;   // bit for byte enable in   FMT[FMT - BE_FMT-1]
localparam HDR_DATA_FMT_WD  = HDR_DATA_MAX_NUM*FMT         ;   //[two bits for each header fmt,one bit for byte enable,one bit for late poison bit] 
localparam FMT_IDX_WD       = ($clog2(HDR_DATA_FMT_WD))    ;
localparam POISON_IDX_WD    = ($clog2(HDR_DATA_MAX_NUM))   ;
localparam DBE_SIZE         = 64                           ;
localparam SLOT_SIZE        = 128                          ;
localparam CHANNEL_NUM      = FLIT_SLOT_NUM/4              ;
localparam DATA_SIZE        = 512                          ;
localparam HS_SLOT_SIZE     = 96                           ;
localparam FLIT_CNTR_WD     = 4                            ;

// Declarations                     
logic [FLIT_SLOT_NUM-1:0]           cxl_flit_slf_msb_s   ;  // Vector of Slot Format MSB bits in reversed bit order
logic [FLIT_SLOT_NUM-1:0]           cxl_slot_slf_vec_s   ;  // Slots with SLF MSB bits after aligning to rollover counter and Data Headers in H-slot
logic [FLIT_SLOT_NUM-1:0]           cxl_slot_vld_vec_s   ;  // Slots valid for the decode after aligning to rollover counter
logic [FLIT_SLOT_NUM-1:0]           cxl_slot_dec_ena_s   ;  // Slots valid for the decode (non-Data Slots)
logic [SLOT_SIZE-1:0]               cxl_slot_data_s      ;  // Slot decoder - Slot Data extended to 128 bits
logic [3:0]                         cxl_slot_type_s      ;  // Slot decoder - Slot Format
logic [DATA_SIZE-1:0]               cxl_hdr_data_nxt     ;  // Header Data Shift Register - Next State
logic [DATA_SIZE-1:0]               cxl_hdr_data_r       ;  // Header Data Shift Register
logic [FLIT_CNTR_WD-1:0]            cxl_flit_cycle_nxt   ;  // Flit cycle counter in 256B Flit - Next State
logic [FLIT_CNTR_WD-1:0]            cxl_flit_cycle_r     ;  // Flit cycle counter in 256B Flit - Register State
logic                               cxl_flit_sof_s       ;  // CXL Flit SOF cycl
logic                               cxl_flit_eof_s       ;  // CXL Flit EOF cycle
logic                               rsvd_enc_error_s     ;  // Reserved Encoding Violation
logic                               mdh_indicator_s      ;  // Multi-Data-Header indecation
logic [1:0]                         poisoned_data_s      ;  // Indication of detected Poison bit in the Data Header
logic [3:0]                         cxl_hdr_data_cnt_nxt ;  // Data Header Counter - Next State
logic [3:0]                         cxl_hdr_data_cnt_r   ;  // Data Header Counter - Register State
logic [3:0]                         cxl_hdr_be_cnt_nxt   ;  // Data Header Counter - Next State
logic [3:0]                         cxl_hdr_be_cnt_r     ;  // Data Header Counter - Register State
logic [2:0]                         cxl_hdr_data_inc_s   ;  // Data Header Counter Increment
logic [HDR_DATA_FMT_WD-1:0]         cxl_hdr_data_fmt_nxt ;  // Header Data Format Type - Next State
logic [HDR_DATA_FMT_WD-1:0]         cxl_hdr_data_fmt_r   ;  // Header Data Format Type - Register State
logic [FMT*2-1:0]                   cxl_hdr_data_fmt_s   ;  // Axillary version of  Header Data Format
logic [CHANNEL_NUM-1:0]             cxl_hdr_be_fmt_s     ;  // Byte Enable Bit In The Header Data Format
logic [FMT_IDX_WD-1:0]              hdr_fmt_idx          ;  // Axillary Signal for cxl_hdr_data_fmt_nxt               
logic [HDR_DATA_MAX_NUM-1:0]        cxl_hdr_poison_nxt   ;  // Poisoned hdr location (late poison) - Next State
logic [HDR_DATA_MAX_NUM-1:0]        cxl_hdr_poison_r     ;  // Poisoned hdr location (late poison) - Register State
logic [POISON_IDX_WD-1:0]           hdr_poi_idx          ;  // Axillary Signal for cxl_hdr_poison_nxt           
logic [1:0]                         hdr_data_vld_s       ;  // Header Data Valid
logic [1:0]                         hdr_be_valid_s       ;  // Header Byte Enable Valid
logic [1023:0]                      hdr_data_s           ;  // Header Data
logic                               unpacker_flit_valid_s;  // Protocol Flit Valid or LLCTRL_IDE_MAC 256B_flit 
logic [1:0]                         late_poison_data_s   ;  // Axillary Signal for poisoned_data_o ( Late Poison Datat )
logic [5:0]                         rollover_cnt_nxt     ;  // Data Rollover Counter - Next State
logic [5:0]                         rollover_cnt_r       ;  // Data Rollover Counter - Register State
logic [5:0]                         rollover_inc_s       ;  // Data Rollover Counter Increment
logic [2:0]                         rollover_be_cnt_nxt  ;  // Byte enable Rollover Counter - Next State     
logic [2:0]                         rollover_be_cnt_r    ;  // Byte enable Rollover Counter - Register State
logic [2:0]                         data_offset_nxt      ;  // Data offset in the Header Flit - Next State
logic [2:0]                         data_offset_r        ;  // Data offset in the Header Flit - Register State
logic [2:0]                         data_offset_page_s    [0:CHANNEL_NUM-1] ;  // Page[0]for the first 4 slots and Page[1] for the last 4 slots in 1024 Datapath
logic [2:0]                         rollover_be_cnt_page_s[0:CHANNEL_NUM-1] ;  // Page[0]for the first 4 slots and Page[1] for the last 4 slots in 1024 Datapath
logic [2:0]                         rollover_be_inc_s     [0:CHANNEL_NUM-1] ;  // Byte enable Rollover Counter Increment
logic [2:0]                         rollover_dec_s        [0:CHANNEL_NUM-1] ;  // Data and Byte enable Rollover Counter Decrement
logic [DBE_SIZE-1:0]                hdr_be_data_s         [0:CHANNEL_NUM-1] ;  // Data Byte Enable
logic [DATA_SIZE-1:0]               cxl_hdr_data_page_s   [0:CHANNEL_NUM-1] ;  // Page[0]for the first 4 slots and Page[1] for the last 4 slots in 1024 Datapath

logic [H2D_256B_RESP_SIZE-1:0]     h2d_rsp_msg_s [0:H2D_256B_RESP_NUM-1]   ;
logic [H2D_256B_REQ_SIZE-1:0]      h2d_req_msg_s [0:H2D_256B_REQ_NUM-1]    ;
logic [H2D_256B_DHDR_SIZE-1:0]     h2d_hdr_msg_s [0:H2D_256B_DATA_NUM-1]   ;
                                                                           
logic [H2D_REQ_CNT_WIDTH-1:0]      h2d_req_idx_s                           ;
logic [H2D_RSP_CNT_WIDTH-1:0]      h2d_rsp_idx_s                           ;
logic [H2D_DATA_CNT_WIDTH-1:0]     h2d_hdr_idx_s                           ;
logic [M2S_256B_NDR_SIZE-1:0]      m2s_ndr_msg_s [0:M2S_256B_NDR_NUM-1]    ;
logic [M2S_256B_DHDR_SIZE-1:0]     m2s_hdr_msg_s [0:M2S_256B_DATA_NUM-1]   ;
logic [M2S_REQ_CNT_WIDTH-1:0]      m2s_ndr_idx_s                           ;                          
logic [M2S_HDR_CNT_WIDTH-1:0]      m2s_hdr_idx_s                           ;                          
logic [D2H_256B_RESP_SIZE-1:0]     d2h_rsp_msg_s [0:D2H_256B_RESP_NUM-1]   ;
logic [D2H_256B_REQ_SIZE-1:0]      d2h_req_msg_s [0:D2H_256B_REQ_NUM-1]    ;
logic [D2H_256B_DHDR_SIZE-1:0]     d2h_hdr_msg_s [0:D2H_256B_DATA_NUM-1]   ;
                                        
logic [D2H_REQ_CNT_WIDTH-1:0]      d2h_req_idx_s                           ;
logic [D2H_RSP_CNT_WIDTH-1:0]      d2h_rsp_idx_s                           ;
logic [D2H_DATA_CNT_WIDTH-1:0]     d2h_hdr_idx_s                           ;
logic [S2M_256B_NDR_SIZE-1:0]      s2m_ndr_msg_s [0:S2M_256B_NDR_NUM-1]    ;
logic [S2M_256B_DHDR_SIZE-1:0]     s2m_hdr_msg_s [0:S2M_256B_DATA_NUM-1]   ;
                                        
                                        
logic [S2M_REQ_CNT_WIDTH-1:0]      s2m_ndr_idx_s                           ;
logic [S2M_HDR_CNT_WIDTH-1:0]      s2m_hdr_idx_s                           ;
logic [(2*S2M_256B_NDR_SIZE)-1:0]  s2m_ndr_x2_msg_s                        ;
logic [M2S_256B_BI_RSP_SIZE-1:0]   m2s_bi_msg_s [0:M2S_256B_BI_RSP_NUM-1]  ;                                
logic [M2S_BI_RSP_CNT_WIDTH-1:0]   m2s_bi_idx_s                            ;
logic [S2M_256B_BI_SNP_SIZE-1:0]   s2m_bi_msg_s [0:S2M_256B_BI_SNP_NUM-1]  ;
logic [S2M_BI_SNP_CNT_WIDTH-1:0]   s2m_bi_idx_s                            ;

localparam UNPACKER_REGIN_WD = 1 + 1 + 1 + (FLIT_SLOT_NUM*128) + 1 + 4;

logic                          cxl_flit_valid_s;
logic                          cxl_rx_crc_error_s;
logic                          cxl_ctrl_flit_vld_s;
logic [FLIT_SLOT_NUM*128-1:0]  cxl_flit_data_s;
logic                          cxl_256b_rx_poison_s;
logic [3:0]                    cxl_256b_rx_poison_off_s;

delay_n
 #(
    .N     ( `CX_CXL_256B_UNPACKER_REGIN ),
    .WD    ( UNPACKER_REGIN_WD           )
) u_unpacker_regin (
  .clk   ( core_clk                 ),
  .rst_n ( core_rst_n               ),
  .clear ( 1'b0                     ),
  .din   ( {cxl_flit_valid_i,
            cxl_rx_crc_error_i,
            cxl_ctrl_flit_vld_i,
            cxl_flit_data_i,
            cxl_256b_rx_poison_i,
            cxl_256b_rx_poison_off_i}),
  .dout  ( {cxl_flit_valid_s,
            cxl_rx_crc_error_s,
            cxl_ctrl_flit_vld_s,
            cxl_flit_data_s,
            cxl_256b_rx_poison_s,
            cxl_256b_rx_poison_off_s})
);


// Protocol Flit Valid or LLCTRL_IDE_MAC 256B_flit
assign unpacker_flit_valid_s = cxl_flit_valid_s && !cxl_ctrl_flit_vld_s &&!cxl_rx_crc_error_s;
// CXL Unpacker outputs assignment
assign rsvd_enc_error_o   = unpacker_flit_valid_s ? rsvd_enc_error_s : 1'b0 ;
assign poisoned_data_o    = unpacker_flit_valid_s ? (poisoned_data_s | late_poison_data_s ) : 2'b00;

always_comb begin
 late_poison_data_s='0;
 late_poison_data_s [0] = 1'b0 
                                ||(|cxl_h2d_poison_bit_o)
                                ||(|cxl_d2h_poison_bit_o)
                                ;
 late_poison_data_s [1] = 1'b0 
                                ||(|cxl_m2s_poison_bit_o)
                                ||(|cxl_s2m_poison_bit_o)
                                ;
end

assign cxl_mdh_error_o    = cxl_mdh_disable_i && mdh_indicator_s;

// -------------------------------------------------------------------------------------
// Channel Message Outputs - Interface to RX Transaction Layer
// -------------------------------------------------------------------------------------
always_comb begin
// Device Unpacker Interface
    for (int i = 0; i < H2D_256B_RESP_NUM; i++)      begin
        b_unpack_256B.s_cxl_h2d_resp[i]                                 = '0;
        b_unpack_256B.s_cxl_h2d_resp[i][H2D_256B_RESP_SIZE-1:0]         = h2d_rsp_msg_s[i];
    end                                            
                                                   
    for (int i = 0; i < H2D_256B_REQ_NUM; i++)      begin      
        b_unpack_256B.s_cxl_h2d_req[i]                                  = '0;
        b_unpack_256B.s_cxl_h2d_req[i][H2D_256B_REQ_SIZE-1:0]           = h2d_req_msg_s[i];
    end
    
    for (int i = 0; i < H2D_256B_DATA_NUM  ; i++)   begin
        b_unpack_256B.s_cxl_h2d_dhr[i]                                  = '0;
        b_unpack_256B.s_cxl_h2d_dhr[i][H2D_256B_DHDR_SIZE-1:0]          = h2d_hdr_msg_s[i];
    end                                                                                       


    for (int i = 0; i < M2S_256B_DATA_NUM; i++)     begin      
        b_unpack_256B.s_cxl_m2s_dhr[i]                                  = '0;
        b_unpack_256B.s_cxl_m2s_dhr[i][M2S_256B_DHDR_SIZE-1:0]          = m2s_hdr_msg_s[i];
    end
        
    for (int i = 0; i < M2S_256B_NDR_NUM; i++)      begin
        b_unpack_256B.s_cxl_m2s_req[i]                                  ='0;
        b_unpack_256B.s_cxl_m2s_req[i][M2S_256B_NDR_SIZE-1:0]           = m2s_ndr_msg_s[i];
    end
     

// Host Unpacker Interface
    for (int i = 0; i < D2H_256B_REQ_NUM; i++)      begin
        b_unpack_256B.s_cxl_d2h_req[i]                                  = '0;
        b_unpack_256B.s_cxl_d2h_req[i][D2H_256B_REQ_SIZE-1:0]           = d2h_req_msg_s[i];
    end
    
    for (int i = 0; i < D2H_256B_RESP_NUM; i++)     begin
        b_unpack_256B.s_cxl_d2h_resp[i]                                 = '0;
        b_unpack_256B.s_cxl_d2h_resp[i][D2H_256B_RESP_SIZE-1:0]         = d2h_rsp_msg_s[i];
    end
    
    for (int i = 0; i < D2H_256B_DATA_NUM; i++)     begin
        b_unpack_256B.s_cxl_d2h_dhr[i]                                  = '0; 
        b_unpack_256B.s_cxl_d2h_dhr[i][D2H_256B_DHDR_SIZE-1:0]          = d2h_hdr_msg_s[i];
    end


    for (int i = 0; i < S2M_256B_NDR_NUM; i++)      begin 
        b_unpack_256B.s_cxl_s2m_ndr[i]                                  = '0;
        b_unpack_256B.s_cxl_s2m_ndr[i][S2M_256B_NDR_SIZE-1:0]           = s2m_ndr_msg_s[i];
    end                                        
                                               
    for (int i = 0; i < S2M_256B_DATA_NUM; i++)     begin
        b_unpack_256B.s_cxl_s2m_drs[i]                                  ='0;
        b_unpack_256B.s_cxl_s2m_drs[i][S2M_256B_DHDR_SIZE-1:0]          = s2m_hdr_msg_s[i];
    end                                        


    for (int i = 0; i < M2S_256B_BI_RSP_NUM; i++)   begin
        b_unpack_256B.s_cxl_m2s_bi_rsp[i]                               = '0;
        b_unpack_256B.s_cxl_m2s_bi_rsp[i][M2S_256B_BI_RSP_SIZE-1:0]     = m2s_bi_msg_s[i];
    end                                        
    
    for (int i = 0; i < S2M_256B_BI_SNP_NUM; i++)   begin
        b_unpack_256B.s_cxl_s2m_bi_snp[i]                               = '0;
        b_unpack_256B.s_cxl_s2m_bi_snp[i][S2M_256B_BI_SNP_SIZE-1:0]     = s2m_bi_msg_s[i];
    end
end

// -------------------------------------------------------------------------------------


// -------------------------------------------------------------------------------------
// Data Outputs - Interface to RX Transaction Layer
// -------------------------------------------------------------------------------------
logic [FMT-1:0] cxl_hdr_data_fmt_be_s;
always_comb begin

for (int i = 0; i < H2D_256B_DDATA_NUM ; i++) cxl_h2d_poison_bit_o[i]  = '0;
for (int i = 0; i < M2S_256B_DDATA_NUM; i++)  cxl_m2s_poison_bit_o[i]  = '0;
for (int i = 0; i < D2H_256B_DDATA_NUM; i++ ) cxl_d2h_poison_bit_o[i]  = '0;
for (int i = 0; i < S2M_256B_DDATA_NUM; i++)  cxl_s2m_poison_bit_o[i]  = '0;

  for (int i = 0; i < M2S_256B_DDATA_NUM; i++) begin
    b_unpack_256B.s_cxl_m2s_data[i]          = '0;
    b_unpack_256B.s_cxl_m2s_data_valid[i]    = '0;
    b_unpack_256B.s_cxl_m2s_byte_en[i]       = '0;
    b_unpack_256B.s_cxl_m2s_byte_en_valid[i] = '0;
  end                                          
  for (int i = 0; i < D2H_256B_DDATA_NUM; i++) begin
    b_unpack_256B.s_cxl_d2h_data[i]          = '0;
    b_unpack_256B.s_cxl_d2h_data_valid[i]    = '0;
    b_unpack_256B.s_cxl_d2h_byte_en[i]       = '0;
    b_unpack_256B.s_cxl_d2h_byte_en_valid[i] = '0;
  end
  for (int i = 0; i < H2D_256B_DDATA_NUM ; i++) begin
    b_unpack_256B.s_cxl_h2d_data[i]          = '0;
    b_unpack_256B.s_cxl_h2d_data_valid[i]    = '0;
  end 
  for (int i = 0; i < S2M_256B_DDATA_NUM; i++) begin
    b_unpack_256B.s_cxl_s2m_data[i]          = '0;
    b_unpack_256B.s_cxl_s2m_data_valid[i]    = '0;
  end

cxl_hdr_data_fmt_s = '0;
cxl_hdr_data_fmt_be_s = '0;
    case (cxl_hdr_data_cnt_r)
        4'd0: begin
        
        end                                                                    
        4'd1: begin                                                            
            cxl_hdr_data_fmt_s     = {{FMT{1'b0}},cxl_hdr_data_fmt_r[HDR_DATA_FMT_WD-1: HDR_DATA_FMT_WD-FMT]};
            b_unpack_256B.s_cxl_h2d_data_valid[0]                              = (cxl_hdr_data_fmt_s[FMT-1:FMT-2] == H2D_FMT) ? hdr_data_vld_s[0] : 1'b0;
            b_unpack_256B.s_cxl_h2d_data[0][H2D_256B_DDATA_SIZE-1:0]           = hdr_data_s[0 +: H2D_256B_DDATA_SIZE];
            cxl_h2d_poison_bit_o[0]                                            = cxl_hdr_data_fmt_s [0] & ((cxl_hdr_data_fmt_s[FMT-1:FMT-2] == H2D_FMT) ? hdr_data_vld_s[0] : 1'b0);
            b_unpack_256B.s_cxl_d2h_data_valid[0]                              = (cxl_hdr_data_fmt_s[FMT-1:FMT-2] == D2H_FMT) ? hdr_data_vld_s[0] : 1'b0;
            b_unpack_256B.s_cxl_d2h_data[0][D2H_256B_DDATA_SIZE-1:0]           = hdr_data_s[0 +: D2H_256B_DDATA_SIZE];
            b_unpack_256B.s_cxl_d2h_byte_en[0][D2H_256B_DBE_SIZE-1:0]          = hdr_be_data_s[0];
            b_unpack_256B.s_cxl_d2h_byte_en_valid[0]                           = (cxl_hdr_data_fmt_s[FMT-1:FMT-2] == D2H_FMT) ? hdr_be_valid_s[0] : 1'b0;
            cxl_d2h_poison_bit_o[0]                                            = cxl_hdr_data_fmt_s [0] & ((cxl_hdr_data_fmt_s[FMT-1:FMT-2] == D2H_FMT) ? hdr_be_valid_s[0] : 1'b0);
            b_unpack_256B.s_cxl_m2s_data_valid[0]                              = (cxl_hdr_data_fmt_s[FMT-1:FMT-2] == M2S_FMT) ? hdr_data_vld_s[0] : 1'b0;
            b_unpack_256B.s_cxl_m2s_data[0][M2S_256B_DDATA_SIZE-1:0]           = hdr_data_s[0 +: M2S_256B_DDATA_SIZE];
            b_unpack_256B.s_cxl_m2s_byte_en[0][M2S_256B_DBE_SIZE-1:0]          = hdr_be_data_s[0];
            b_unpack_256B.s_cxl_m2s_byte_en_valid[0]                           = (cxl_hdr_data_fmt_s[FMT-1:FMT-2] == M2S_FMT) ? hdr_be_valid_s[0] : 1'b0;
            cxl_m2s_poison_bit_o[0]                                            = cxl_hdr_data_fmt_s [0] & ((cxl_hdr_data_fmt_s[FMT-1:FMT-2] == M2S_FMT) ? hdr_be_valid_s[0] : 1'b0);
            b_unpack_256B.s_cxl_s2m_data_valid[0]                              = (cxl_hdr_data_fmt_s[FMT-1:FMT-2] == S2M_FMT) ? hdr_data_vld_s[0] : 1'b0;
            b_unpack_256B.s_cxl_s2m_data[0][S2M_256B_DDATA_SIZE-1:0]           = hdr_data_s[0 +: S2M_256B_DDATA_SIZE];
            cxl_s2m_poison_bit_o[0]                                            = cxl_hdr_data_fmt_s [0] & ((cxl_hdr_data_fmt_s[FMT-1:FMT-2] == S2M_FMT) ? hdr_data_vld_s[0] : 1'b0);
        end                                                                    
        default: begin                                                         
            case (cxl_hdr_data_cnt_r) 
                4'd2   : cxl_hdr_data_fmt_s = cxl_hdr_data_fmt_r[HDR_DATA_FMT_WD-1      : HDR_DATA_FMT_WD-FMT*2];//[31: 24];      
                4'd3   : cxl_hdr_data_fmt_s = cxl_hdr_data_fmt_r[HDR_DATA_FMT_WD-FMT-1  : HDR_DATA_FMT_WD-FMT*3];//[27: 20];      
                4'd4   : cxl_hdr_data_fmt_s = cxl_hdr_data_fmt_r[HDR_DATA_FMT_WD-FMT*2-1: HDR_DATA_FMT_WD-FMT*4];//[23: 16];      
                4'd5   : cxl_hdr_data_fmt_s = cxl_hdr_data_fmt_r[HDR_DATA_FMT_WD-FMT*3-1: HDR_DATA_FMT_WD-FMT*5];//[19: 12];      
                4'd6   : cxl_hdr_data_fmt_s = cxl_hdr_data_fmt_r[HDR_DATA_FMT_WD-FMT*4-1: HDR_DATA_FMT_WD-FMT*6];//[15: 8 ];      
                4'd7   : cxl_hdr_data_fmt_s = cxl_hdr_data_fmt_r[HDR_DATA_FMT_WD-FMT*5-1: HDR_DATA_FMT_WD-FMT*7];//[11: 4 ];      
                default: cxl_hdr_data_fmt_s = cxl_hdr_data_fmt_r[HDR_DATA_FMT_WD-FMT*6-1: HDR_DATA_FMT_WD-FMT*8];//[7 : 0 ];      
            endcase                                                            
            b_unpack_256B.s_cxl_h2d_data_valid[0]                              = (cxl_hdr_data_fmt_s[FMT-1:FMT-2] == H2D_FMT) ? hdr_data_vld_s[0] : 1'b0;
            b_unpack_256B.s_cxl_h2d_data[0][H2D_256B_DDATA_SIZE-1:0]           = hdr_data_s[0 +: H2D_256B_DDATA_SIZE];
            cxl_h2d_poison_bit_o[0]                                            = cxl_hdr_data_fmt_s [0] & ((cxl_hdr_data_fmt_s[FMT-1:FMT-2] == H2D_FMT) ? hdr_data_vld_s[0] : 1'b0);
            b_unpack_256B.s_cxl_d2h_data_valid[0]                              = (cxl_hdr_data_fmt_s[FMT-1:FMT-2] == D2H_FMT) ? hdr_data_vld_s[0] : 1'b0;
            b_unpack_256B.s_cxl_d2h_data[0][D2H_256B_DDATA_SIZE-1:0]           = hdr_data_s[0 +: D2H_256B_DDATA_SIZE];
            b_unpack_256B.s_cxl_d2h_byte_en[0][D2H_256B_DBE_SIZE-1:0]          = hdr_be_data_s[0];
            b_unpack_256B.s_cxl_d2h_byte_en_valid[0]                           = (cxl_hdr_data_fmt_s[FMT-1:FMT-2] == D2H_FMT) ? hdr_be_valid_s[0] : 1'b0;
            cxl_d2h_poison_bit_o[0]                                            = cxl_hdr_data_fmt_s [0] & ((cxl_hdr_data_fmt_s[FMT-1:FMT-2] == D2H_FMT) ? hdr_be_valid_s[0] : 1'b0);
            b_unpack_256B.s_cxl_m2s_data_valid[0]                              = (cxl_hdr_data_fmt_s[FMT-1:FMT-2] == M2S_FMT) ? hdr_data_vld_s[0] : 1'b0;
            b_unpack_256B.s_cxl_m2s_data[0][M2S_256B_DDATA_SIZE-1:0]           = hdr_data_s[0 +: M2S_256B_DDATA_SIZE];
            b_unpack_256B.s_cxl_m2s_byte_en[0][M2S_256B_DBE_SIZE-1:0]          = hdr_be_data_s[0];
            b_unpack_256B.s_cxl_m2s_byte_en_valid[0]                           = (cxl_hdr_data_fmt_s[FMT-1:FMT-2] == M2S_FMT) ? hdr_be_valid_s[0] : 1'b0;
            cxl_m2s_poison_bit_o[0]                                            = cxl_hdr_data_fmt_s [0] & ((cxl_hdr_data_fmt_s[FMT-1:FMT-2] == M2S_FMT) ? hdr_be_valid_s[0] : 1'b0);
            b_unpack_256B.s_cxl_s2m_data_valid[0]                              = (cxl_hdr_data_fmt_s[FMT-1:FMT-2] == S2M_FMT) ? hdr_data_vld_s[0] : 1'b0;
            b_unpack_256B.s_cxl_s2m_data[0][S2M_256B_DDATA_SIZE-1:0]           = hdr_data_s[0 +: S2M_256B_DDATA_SIZE];
            cxl_s2m_poison_bit_o[0]                                            = cxl_hdr_data_fmt_s [0] & ((cxl_hdr_data_fmt_s[FMT-1:FMT-2] == S2M_FMT) ? hdr_data_vld_s[0] : 1'b0);
        end
    endcase
end  
// -------------------------------------------------------------------------------------

// -------------------------------------------------------------------------------------
// Byte Enable bit selection
// -------------------------------------------------------------------------------------
// 1- the rollover_be_cnt_nxt will be incremented by 5 or 4 depending on the Byte Enable bit
//    of the fmt
// 2- (rollover_dec_s <= rollover_be_cnt_page_s) if no new data started 
// -------------------------------------------------------------------------------------
always_comb begin
  for (int i = 0; i < CHANNEL_NUM; i++) begin
    rollover_be_inc_s[i]   = '0;
        case (cxl_hdr_be_cnt_nxt)
        4'd0   : cxl_hdr_be_fmt_s[i] = 1'b0;
        4'd1   : cxl_hdr_be_fmt_s[i] = cxl_hdr_data_fmt_nxt[HDR_DATA_FMT_WD-        BE_FMT-1        ];//[29      ];
        4'd2   : cxl_hdr_be_fmt_s[i] = cxl_hdr_data_fmt_nxt[HDR_DATA_FMT_WD- FMT   -BE_FMT-1+(FMT*i)];//[25+FMT*i];
        4'd3   : cxl_hdr_be_fmt_s[i] = cxl_hdr_data_fmt_nxt[HDR_DATA_FMT_WD-(FMT*2)-BE_FMT-1+(FMT*i)];//[21+FMT*i];
        4'd4   : cxl_hdr_be_fmt_s[i] = cxl_hdr_data_fmt_nxt[HDR_DATA_FMT_WD-(FMT*3)-BE_FMT-1+(FMT*i)];//[17+FMT*i];
        4'd5   : cxl_hdr_be_fmt_s[i] = cxl_hdr_data_fmt_nxt[HDR_DATA_FMT_WD-(FMT*4)-BE_FMT-1+(FMT*i)];//[13+FMT*i];
        4'd6   : cxl_hdr_be_fmt_s[i] = cxl_hdr_data_fmt_nxt[HDR_DATA_FMT_WD-(FMT*5)-BE_FMT-1+(FMT*i)];//[9 +FMT*i];
        4'd7   : cxl_hdr_be_fmt_s[i] = cxl_hdr_data_fmt_nxt[HDR_DATA_FMT_WD-(FMT*6)-BE_FMT-1+(FMT*i)];//[5 +FMT*i];
        default: cxl_hdr_be_fmt_s[i] = cxl_hdr_data_fmt_nxt[HDR_DATA_FMT_WD-(FMT*7)-BE_FMT-1+(FMT*i)];//[1 +FMT*i];
        endcase
         
       
      if (rollover_dec_s[i] <= rollover_be_cnt_page_s[CHANNEL_NUM-1-i])
        rollover_be_inc_s[i]   = '0;
      else if (cxl_hdr_be_fmt_s[i])
        rollover_be_inc_s[i] = 3'd5;
         else 
        rollover_be_inc_s[i] = 3'd4;
  end           
end

// -------------------------------------------------------------------------------------
// Flit cycle counter - generates SOF and EOF markers for 256B Flit
// -------------------------------------------------------------------------------------
assign cxl_flit_sof_s       = unpacker_flit_valid_s && (cxl_flit_cycle_r   == 4'b0000);
assign cxl_flit_eof_s       = unpacker_flit_valid_s && (cxl_flit_cycle_nxt == 4'b0000);
assign cxl_flit_adf_o = (|cxl_flit_cycle_r);

always_comb begin
  // Preset Flit cycle counter
  cxl_flit_cycle_nxt = cxl_flit_cycle_r;
  // Increment flit cycle counter on every valid flit on the ARB/MUX interface
  if (unpacker_flit_valid_s) begin
    cxl_flit_cycle_nxt = cxl_flit_cycle_nxt + FLIT_SLOT_NUM;
  end
end
// --------------------------------------------------------------------------------------


// -------------------------------------------------------------------------------------
// Vector of slots with Data Header(s). Set when MSB two bits of Slot Format is 11xx.
// -------------------------------------------------------------------------------------
always_comb begin
    cxl_flit_slf_msb_s = {FLIT_SLOT_NUM{1'b0}};

    for (int i = 0; i < FLIT_SLOT_NUM; i++) begin
        // Set when SlotFmt MSB 2 bits are 1
        cxl_flit_slf_msb_s[(FLIT_SLOT_NUM-1)-i] = &cxl_flit_data_s[(i*SLOT_SIZE+2)+:2];
    end
end
// -------------------------------------------------------------------------------------


// -------------------------------------------------------------------------------------
// Slot Format vector used to select slots enabled in the flit decoding (no Data slots)
// -------------------------------------------------------------------------------------
logic  h_hs_slot;
logic  slot_type_msb;

assign h_hs_slot        = cxl_flit_sof_s;
assign slot_type_msb    = &cxl_flit_data_s[19:18];

always_comb begin
    if (unpacker_flit_valid_s && h_hs_slot) begin
        cxl_slot_vld_vec_s[FLIT_SLOT_NUM-1  ] = 1'b1;
        cxl_slot_vld_vec_s[FLIT_SLOT_NUM-2:0] = {(FLIT_SLOT_NUM-1){1'b1}} >> rollover_cnt_r;

        // If H-slot / Hs-slot contains Data Header (SlotFmt MSB 2 bits are 1) then the next 4 slots are Data slots
        if (slot_type_msb) begin
            // If H-slot / Hs-slot contains Data Header then the next for slots are guaranteed to be Data slots hence are not valid
            cxl_slot_vld_vec_s[FLIT_SLOT_NUM-2:0] = ({(FLIT_SLOT_NUM-1){1'b1}} >> rollover_cnt_r)>> 4;
        end
        // Otherwise if no Data Header in the H-slot / Hs-slot then all slots are valid
    end
    else begin
        cxl_slot_vld_vec_s = {FLIT_SLOT_NUM{1'b1}} >> rollover_cnt_r;
    end
end

always_comb begin
    if (unpacker_flit_valid_s && h_hs_slot) begin
        // If H-slot / Hs-slot contains Data Header (SlotFmt MSB 2 bits are 1) then the next 4 slots are Data slots
        if (slot_type_msb) begin
            // If H-slot / Hs-slot contains Data Header then the next for slots are guaranteed to be Data slots hence are not valid
            cxl_slot_slf_vec_s[FLIT_SLOT_NUM-1  ] = 1'b1;
            cxl_slot_slf_vec_s[FLIT_SLOT_NUM-2:0] = cxl_flit_slf_msb_s[FLIT_SLOT_NUM-2:0] & cxl_slot_vld_vec_s[FLIT_SLOT_NUM-2:0];// & (cxl_slot_vld_vec_s[FLIT_SLOT_NUM-2:0] >> 4);
        end
        // Otherwise if no Data Header in the H-slot / Hs-slot then all slots are valid
        else begin
            cxl_slot_slf_vec_s[FLIT_SLOT_NUM-1  ] = 1'b0;
            cxl_slot_slf_vec_s[FLIT_SLOT_NUM-2:0] = cxl_flit_slf_msb_s[FLIT_SLOT_NUM-2:0] & cxl_slot_vld_vec_s[FLIT_SLOT_NUM-2:0];
        end
    end
    else begin
        cxl_slot_slf_vec_s = cxl_flit_slf_msb_s & cxl_slot_vld_vec_s;
    end
end
// -------------------------------------------------------------------------------------


// -------------------------------------------------------------------------------------
// Select the slots enabled for decoding (no Data slots) based on the Slot Format Vector
// and extracted MDH and ByteEnable bits from the first 3 slots
// -------------------------------------------------------------------------------------
always_comb begin
    casez (cxl_slot_slf_vec_s)
        4'b0001: cxl_slot_dec_ena_s =  cxl_slot_vld_vec_s[3:0];
        4'b001?: cxl_slot_dec_ena_s = {cxl_slot_vld_vec_s[3:1], 1'd0};
        4'b01??: cxl_slot_dec_ena_s = {cxl_slot_vld_vec_s[3:2], 2'd0};
        4'b1???: cxl_slot_dec_ena_s = {cxl_slot_vld_vec_s[3:3], 3'd0};
        default: cxl_slot_dec_ena_s =  cxl_slot_vld_vec_s[3:0];
    endcase
end
// -------------------------------------------------------------------------------------

always_comb begin
    // Preset Rollover Counter and Error flags
    rsvd_enc_error_s = 1'b0;
    poisoned_data_s  = 2'd0;
    rollover_inc_s   = '0;
    mdh_indicator_s  = '0;
    for (int i = 0; i < CHANNEL_NUM; i++)
      rollover_dec_s[i]   = '0;

    // Preset Data Register
    cxl_hdr_data_nxt     = cxl_hdr_data_r;
    

    cxl_hdr_data_inc_s   = '0;
    cxl_hdr_data_fmt_nxt = cxl_hdr_data_fmt_r;
    cxl_hdr_poison_nxt   = cxl_hdr_poison_r;
    hdr_fmt_idx          = '0;
    hdr_poi_idx          = '0;

    // Preset Device Indexes
    h2d_req_idx_s    = '0;
    h2d_rsp_idx_s    = '0;
    h2d_hdr_idx_s    = '0;
    m2s_ndr_idx_s    = '0;
    m2s_hdr_idx_s    = '0;
    m2s_bi_idx_s     = '0;

    // Preset Host Indexes
    d2h_req_idx_s    = '0;
    d2h_rsp_idx_s    = '0;
    d2h_hdr_idx_s    = '0;
    s2m_ndr_idx_s    = '0;
    s2m_hdr_idx_s    = '0;
    s2m_bi_idx_s     = '0;
    // Preset Device Messages
    for (int i = 0; i < H2D_256B_RESP_NUM; i++)   h2d_rsp_msg_s[i] = '0;
    for (int i = 0; i < H2D_256B_REQ_NUM; i++)    h2d_req_msg_s[i] = '0;
    for (int i = 0; i < H2D_256B_DATA_NUM; i++)   h2d_hdr_msg_s[i] = '0;
    for (int i = 0; i < M2S_256B_NDR_NUM; i++)    m2s_ndr_msg_s[i] = '0;
    for (int i = 0; i < M2S_256B_DATA_NUM; i++)   m2s_hdr_msg_s[i] = '0;
    for (int i = 0; i < M2S_256B_BI_RSP_NUM; i++) m2s_bi_msg_s[i]  = '0;

    // Preset Host Messages
    for (int i = 0; i < D2H_256B_RESP_NUM; i++)   d2h_rsp_msg_s[i] = '0;
    for (int i = 0; i < D2H_256B_REQ_NUM; i++)    d2h_req_msg_s[i] = '0;
    for (int i = 0; i < D2H_256B_DATA_NUM; i++)   d2h_hdr_msg_s[i] = '0;
    for (int i = 0; i < S2M_256B_NDR_NUM; i++)    s2m_ndr_msg_s[i] = '0;
    for (int i = 0; i < S2M_256B_DATA_NUM; i++)   s2m_hdr_msg_s[i] = '0;
    for (int i = 0; i < S2M_256B_BI_SNP_NUM; i++) s2m_bi_msg_s[i]  = '0;

    for (int i = (FLIT_SLOT_NUM-1); i>= 0; i--) begin
        if ((i == (FLIT_SLOT_NUM-1)) && cxl_flit_sof_s) begin
            {cxl_slot_data_s, cxl_slot_type_s} = {20'd0, cxl_flit_data_s[16+:112]};                                   // H-slot
        end    
        else if ((i==0) & cxl_flit_eof_s) begin
          {cxl_slot_data_s, cxl_slot_type_s} = '0;                                                                    // Eof_slot --- Last slot contain CRD and FEC info  
        end
        else begin
            {cxl_slot_data_s, cxl_slot_type_s} = {4'd0, cxl_flit_data_s[((FLIT_SLOT_NUM-1)-i)*SLOT_SIZE+:SLOT_SIZE]}; // G-slot 
        end
        if (cxl_slot_dec_ena_s[i] & unpacker_flit_valid_s) begin

// -------------------------------------------------------------------------------------
// HBR Device Unpacker
// -------------------------------------------------------------------------------------
            if(!cxl_device_mode) begin 
              case (cxl_slot_type_s)
                {4'd0} : begin
                    // H0 - H2D REQ, G0 - H2D REQ + H2D RSP
                    if (cxl_slot_data_s[0]) begin
                      h2d_req_msg_s[h2d_req_idx_s][H2D_HBR_REQ_SIZE-1:0] = cxl_slot_data_s[           0+:H2D_HBR_REQ_SIZE] ; h2d_req_idx_s++;
                    end
                    if (cxl_slot_data_s[H2D_HBR_REQ_SIZE])begin
                      h2d_rsp_msg_s[h2d_rsp_idx_s][H2D_HBR_RESP_SIZE-1:0]   = cxl_slot_data_s[H2D_HBR_REQ_SIZE+:H2D_HBR_RESP_SIZE]; h2d_rsp_idx_s++;
                    end
                end
                {4'd1} : begin
                    // H1 - 2 H2D RSP, G0 - 3 H2D RSP
                    for (int k=0;k<3;k++) begin
                      if (cxl_slot_data_s[H2D_HBR_RESP_SIZE*k])begin
                        h2d_rsp_msg_s[h2d_rsp_idx_s][H2D_HBR_RESP_SIZE-1:0] = cxl_slot_data_s[H2D_HBR_RESP_SIZE*k +:H2D_HBR_RESP_SIZE]; h2d_rsp_idx_s++;
                      end
                    end
                end
                {4'd4} : begin
                    // H4 - M2S REQ, G4 - M2S REQ
                    if (cxl_slot_data_s[0]) begin
                      m2s_ndr_msg_s[m2s_ndr_idx_s][M2S_HBR_NDR_SIZE-1:0] = cxl_slot_data_s[0+:M2S_HBR_NDR_SIZE]; m2s_ndr_idx_s++;
                    end
                end
                {4'd5} : begin
                    // H5 - 2 M2S BI-RSP, G5 - 3 M2S BI-RSP
                    for (int k=0;k<3;k++) begin
                      if (cxl_slot_data_s[M2S_HBR_BI_RSP_SIZE*k])begin
                        m2s_bi_msg_s[m2s_bi_idx_s][M2S_HBR_BI_RSP_SIZE-1:0] = cxl_slot_data_s[M2S_HBR_BI_RSP_SIZE*k +:M2S_HBR_BI_RSP_SIZE]; m2s_bi_idx_s++;
                      end 
                    end
                end
               {4'd12}: begin
                    // H12 - 3 H2D DATA, G13 - 4 H2D DATA
                    for (int j = 0; j < 4; j++) begin
                        if (cxl_slot_data_s[j*H2D_HBR_DHDR_SIZE]) begin
                            h2d_hdr_msg_s[h2d_hdr_idx_s][H2D_HBR_DHDR_SIZE-1:0] = cxl_slot_data_s[j*H2D_HBR_DHDR_SIZE+:H2D_HBR_DHDR_SIZE]; h2d_hdr_idx_s++;
                            cxl_hdr_data_inc_s           = cxl_hdr_data_inc_s + 1;
                            cxl_hdr_data_fmt_nxt         = {H2D_FMT,1'b0,cxl_hdr_poison_nxt[HDR_DATA_MAX_NUM-1], cxl_hdr_data_fmt_nxt[HDR_DATA_FMT_WD-1:FMT]};
                            cxl_hdr_poison_nxt           = cxl_hdr_poison_nxt << 1;
                            mdh_indicator_s             |= (j==1);
                        end

                        rollover_inc_s     = rollover_inc_s + (cxl_slot_data_s[j*H2D_HBR_DHDR_SIZE] ? 4 : 0);
                        poisoned_data_s[0] = poisoned_data_s[0] | cxl_slot_data_s[j*H2D_HBR_DHDR_SIZE+H2D_256B_POISON_BIT];
                    end
                end
                {4'd14}: begin
                    // H14 - M2S RWD, G14 - M2S RWD
                        if (cxl_slot_data_s[0]) begin
                            m2s_hdr_msg_s[m2s_hdr_idx_s][M2S_HBR_DHDR_SIZE-1:0] = cxl_slot_data_s[0+:(M2S_HBR_DHDR_SIZE)]; m2s_hdr_idx_s ++;
                            cxl_hdr_data_inc_s           = cxl_hdr_data_inc_s + 1;
                            cxl_hdr_data_fmt_nxt         = {M2S_FMT, cxl_slot_data_s[M2S_RWD_BEB_IDX_HBR],cxl_hdr_poison_nxt[HDR_DATA_MAX_NUM-1],cxl_hdr_data_fmt_nxt[HDR_DATA_FMT_WD-1:FMT]};
                            cxl_hdr_poison_nxt           = cxl_hdr_poison_nxt << 1;                       
                        end
                        rollover_inc_s = rollover_inc_s + (cxl_slot_data_s[0] ? (4 + cxl_slot_data_s[M2S_RWD_BEB_IDX_HBR] ) : 0);
                        poisoned_data_s[1] = poisoned_data_s[1] | cxl_slot_data_s[M2S_256B_POISON_BIT];
                end
                default: begin
                end
                endcase
              end // if (!cxl_device_mode)
      // -------------------------------------------------------------------------------------
              else
// -------------------------------------------------------------------------------------
// HBR Host Unpacker
// -------------------------------------------------------------------------------------
              if (cxl_device_mode) begin
                    case (cxl_slot_type_s)
                {4'd2} : begin
                    // H2 - D2H REQ + D2H RSP, G0 - D2H REQ + 2 D2H RSP
                    if (cxl_slot_data_s[0]) begin 
                      d2h_req_msg_s[d2h_req_idx_s][D2H_HBR_REQ_SIZE-1:0] = cxl_slot_data_s[           0+:D2H_HBR_REQ_SIZE] ; d2h_req_idx_s++;
                    end
                    
                    if (cxl_slot_data_s[D2H_HBR_REQ_SIZE])begin
                      d2h_rsp_msg_s[d2h_rsp_idx_s][D2H_HBR_RESP_SIZE-1:0]= cxl_slot_data_s[D2H_HBR_REQ_SIZE+:D2H_HBR_RESP_SIZE]; d2h_rsp_idx_s++;
                    end
                    if (cxl_slot_data_s[D2H_HBR_REQ_SIZE + D2H_HBR_RESP_SIZE]) begin
                      d2h_rsp_msg_s[d2h_rsp_idx_s][D2H_HBR_RESP_SIZE-1:0] = cxl_slot_data_s[(D2H_HBR_REQ_SIZE+D2H_HBR_RESP_SIZE)+:D2H_HBR_RESP_SIZE]; d2h_rsp_idx_s++;
                    end
                end
                {4'd3} : begin
                    // H3 - 4 D2H RSP, G0 - 4 D2H RSP
                    for (int k=0;k<4;k++) begin
                      if (cxl_slot_data_s[D2H_HBR_RESP_SIZE*k])begin
                        d2h_rsp_msg_s[d2h_rsp_idx_s][D2H_HBR_RESP_SIZE-1:0] = cxl_slot_data_s[D2H_HBR_RESP_SIZE*k +:D2H_HBR_RESP_SIZE]; d2h_rsp_idx_s++;
                      end
                    end
                end
                {4'd6} : begin
                    // H7 - S2M BI-SNP, G6 - S2M BI-SNP + S2M NDR
                    if (cxl_slot_data_s[0]) begin
                      s2m_bi_msg_s[s2m_bi_idx_s][S2M_HBR_BI_SNP_SIZE-1:0] = cxl_slot_data_s[              0+:S2M_HBR_BI_SNP_SIZE]; s2m_bi_idx_s++;
                    end
                    if (cxl_slot_data_s[S2M_HBR_BI_SNP_SIZE]) begin
                      s2m_ndr_msg_s[s2m_ndr_idx_s][S2M_HBR_NDR_SIZE-1:0] = cxl_slot_data_s[S2M_HBR_BI_SNP_SIZE+:S2M_HBR_NDR_SIZE   ]; s2m_ndr_idx_s++;
                    end
                end
                {4'd7} : begin
                    // H7 - 3 S2M NDR, G7 - 3 S2M NDR
                    for(int k=0;k<3;k++) begin
                      if (cxl_slot_data_s[S2M_HBR_NDR_SIZE*k]) begin
                        s2m_ndr_msg_s[s2m_ndr_idx_s][S2M_HBR_NDR_SIZE-1:0] = cxl_slot_data_s[S2M_HBR_NDR_SIZE*k+:S2M_HBR_NDR_SIZE]; s2m_ndr_idx_s++;
                      end
                    end
                end
                {4'd13}: begin
                    // H13 - 3 D2H DATA, G12 - 4 D2H DATA
                    for (int j = 0; j < 4; j++) begin
                        if (cxl_slot_data_s[j*D2H_HBR_DHDR_SIZE]) begin
                            d2h_hdr_msg_s[d2h_hdr_idx_s][D2H_HBR_DHDR_SIZE-1:0] = cxl_slot_data_s[j*D2H_HBR_DHDR_SIZE+:D2H_HBR_DHDR_SIZE]; d2h_hdr_idx_s++;
                            cxl_hdr_data_inc_s           = cxl_hdr_data_inc_s + 1;
                            cxl_hdr_data_fmt_nxt         = {D2H_FMT,cxl_slot_data_s[j*D2H_HBR_DHDR_SIZE + D2H_HDR_BEB_IDX_HBR],cxl_hdr_poison_nxt[HDR_DATA_MAX_NUM-1],cxl_hdr_data_fmt_nxt[HDR_DATA_FMT_WD-1:FMT]};
                            cxl_hdr_poison_nxt           = cxl_hdr_poison_nxt << 1;   
                            mdh_indicator_s             |= (j==1);
                        end

                        rollover_inc_s = rollover_inc_s + (cxl_slot_data_s[j*D2H_HBR_DHDR_SIZE] ? (4 + cxl_slot_data_s[j*D2H_HBR_DHDR_SIZE + D2H_HDR_BEB_IDX_HBR] ) : 0);
                        poisoned_data_s[0] = poisoned_data_s[0] | cxl_slot_data_s[j*D2H_HBR_DHDR_SIZE+D2H_256B_POISON_BIT];
                    end
                end
                {4'd15}: begin
                    // H15 - 2 S2M DRC, G15 - 3 S2M DRC
                    for (int j = 0; j < 3; j++) begin
                        if (cxl_slot_data_s[j*S2M_HBR_DHDR_SIZE]) begin
                            s2m_hdr_msg_s[s2m_hdr_idx_s][S2M_HBR_DHDR_SIZE-1:0] = cxl_slot_data_s[j*S2M_HBR_DHDR_SIZE+:S2M_HBR_DHDR_SIZE]; s2m_hdr_idx_s++;
                            cxl_hdr_data_inc_s           = cxl_hdr_data_inc_s + 1;
                            cxl_hdr_data_fmt_nxt         = {S2M_FMT,1'b0,cxl_hdr_poison_nxt[HDR_DATA_MAX_NUM-1], cxl_hdr_data_fmt_nxt[HDR_DATA_FMT_WD-1:FMT]};
                            cxl_hdr_poison_nxt           = cxl_hdr_poison_nxt << 1;
                            mdh_indicator_s             |= (j==1);
                        end

                        rollover_inc_s = rollover_inc_s + (cxl_slot_data_s[j*S2M_HBR_DHDR_SIZE] ? 4 : 0);
                        poisoned_data_s[1] = poisoned_data_s[1] | cxl_slot_data_s[j*S2M_HBR_DHDR_SIZE+S2M_256B_POISON_BIT];
                    end
                end
                default: begin
                end
                endcase
              end // if (cxl_device_mode)
// -------------------------------------------------------------------------------------

//-------------------------------------------------------------------------------------

//-------------------------------------------------------------------------------------
// Reserved Encoding Error
//-------------------------------------------------------------------------------------
            case (cxl_slot_type_s)
              {4'd8}: begin
                if (~((i ==FLIT_SLOT_NUM-1) && h_hs_slot))
                  rsvd_enc_error_s = unpacker_flit_valid_s; // G8 rsvd
              end
              {4'd9},{4'd10},{4'd11}: begin
                rsvd_enc_error_s   = unpacker_flit_valid_s; // G9,G10,G11,H9,H10,H11 rsvd
              end
              default: begin
              end
            endcase
//-------------------------------------------------------------------------------------

        end
        else if (((i == 0) ? !cxl_flit_eof_s : 1'b1) && unpacker_flit_valid_s) begin // !cxl_slot_dec_ena_s[i]
            rollover_dec_s[0] = rollover_dec_s[0] + 1;
           


            cxl_hdr_data_nxt= {cxl_flit_data_s[((FLIT_SLOT_NUM-1)-i)*SLOT_SIZE +: SLOT_SIZE], cxl_hdr_data_nxt[(FLIT_SLOT_NUM/CHANNEL_NUM)*SLOT_SIZE-1:SLOT_SIZE]};
        end
        else if (cxl_256b_rx_poison_s & !unpacker_flit_valid_s) begin
        // - Asserting the poison bit for a specific data header according the poison offset.
        // - cxl_flit_valid_s must be zero as it is in control flit.
        // - Bit to be asserted, according to the offset and data header in the queue of DWC_cxl_mem_cache_rx_chan_dhdr_align module which can be maped by 
        //   cxl_hdr_data_cnt_r, is one bit of : {28,24,20,16,12,8,4,0} in cxl_hdr_data_fmt_nxt.
        // - In case we have a Data HDR in the queue of dhdr_aligner and late_poison indecation, we need to set the poison bit in the HDRs format 
        //   (cxl_hdr_data_fmt_nxt) directly
        // - In case we do not have a Data HDR in the queue of dhdr_aligner and late_poison indecation, we need to set the poison bit in the HDRs format 
        //   (cxl_hdr_poison_nxt) till we receive the Data HDR
// spyglass disable_block W164a
// SMD: Identifies assignments in which the LHS width is less than the RHS width
// SJ: cxl_hdr_data_fmt_nxt and cxl_hdr_poison_nxt No overflow is possible.
          if (cxl_256b_rx_poison_off_s < cxl_hdr_data_cnt_r) begin
            hdr_fmt_idx                       = (HDR_DATA_FMT_WD-1) - ((cxl_hdr_data_cnt_r-cxl_256b_rx_poison_off_s[2:0])*FMT - 1);
            cxl_hdr_data_fmt_nxt[hdr_fmt_idx] = 1'b1;
          end
          else begin
            hdr_poi_idx                       = (HDR_DATA_MAX_NUM - 1 - cxl_256b_rx_poison_off_s + cxl_hdr_data_cnt_r);
            cxl_hdr_poison_nxt[hdr_poi_idx]   = 1'b1;
          end
// spyglass enable_block W164a
    
        end
    end
end



// -------------------------------------------------------------------------------------
// Data Valid Signal
//-------------------------------------------------------------------------------------
//1- (cxl_flit_valid_s && (|data_offset_page_s[1:0])) ? 1'b1 : 1'b0) if one or three slots captured  
//   in the previus cycle 
//2- (~|data_offset_page_s[1:0])&&!rollover_be_cnt_page_s[0] if the data_offset_page_s is 4(four slots captured in the previus cycle) 
//    and still have Byte enable slot.. the valid must be in the previus cycle not in the current cycle 
// -------------------------------------------------------------------------------------
always_comb begin
  for (int i = 0; i < CHANNEL_NUM; i++) begin
    hdr_data_vld_s[i] = ((unpacker_flit_valid_s && (|data_offset_page_s[CHANNEL_NUM-1-i][1:0])) ? 1'b1 : 1'b0) |
                        ((unpacker_flit_valid_s &&(~|data_offset_page_s[CHANNEL_NUM-1-i][1:0])&&!rollover_be_cnt_page_s[CHANNEL_NUM-1-i][0] &&!h_hs_slot && !cxl_flit_eof_s && (( (i==0) ? (|rollover_cnt_r) : (rollover_dec_s[i]==4)))) ? 1'b1 : 1'b0);
  end
end
// -------------------------------------------------------------------------------------
// Byte Enable Valid Signal
//-------------------------------------------------------------------------------------
//1- ((rollover_be_cnt_page_s + data_offset_page_s ==5)
//   the byte enable slot will be in the current cycle if data captured in the previus cycle + remainder of data header is 5.
//
//   (rollover_be_cnt_page_s + data_offset_page_s ==1)
//   If we capure one data chunck in the eof cycle,three slots will be received in the sof and the data offset will be zero
//   in sof cycle as (rollover_be_cnt_page_s <= rollover_dec_s) condition was not met. 
// -------------------------------------------------------------------------------------                        
logic   cxl_fmt_be[CHANNEL_NUM-1:0];
assign  cxl_fmt_be[0] = cxl_hdr_data_fmt_s[FMT-BE_FMT-1];


always_comb begin
  for (int i = 0; i < CHANNEL_NUM; i++) begin
    hdr_be_valid_s[i] = cxl_fmt_be[i] ? (((unpacker_flit_valid_s && (|rollover_be_cnt_page_s[CHANNEL_NUM-1-i][1:0])) ? 1'b1 : 1'b0) 
                                                                                      | (((unpacker_flit_valid_s && (rollover_be_cnt_page_s[CHANNEL_NUM-1-i][2])) && (!h_hs_slot && !cxl_flit_eof_s) ) ? 1'b1 : 1'b0))
                                                                                     :hdr_data_vld_s[i];
  end
end 
// Valid Data Headers Counter


logic [CHANNEL_NUM-1:0] hdr_be_s; 
always_comb begin
hdr_be_s = '0;
  for (int i = 0; i < CHANNEL_NUM; i++) begin
    hdr_be_s[i] = cxl_fmt_be[i] ;
  end
end 

// -------------------------------------------------------------------------------------
// 1- (start_data_nxt) indicates if new data started in the current flit
// 2- cxl_hdr_be_cnt_nxt --- number of data counter will not be decremented unless new data 
//    started in the current flit 
//-------------------------------------------------------------------------------------
logic [CHANNEL_NUM-1:0] start_data_nxt;
logic [CHANNEL_NUM-1:0] start_data_r  ;
always_comb begin
  for (int i = 0; i < CHANNEL_NUM; i++) begin
    start_data_nxt[i] = (rollover_dec_s[i] > rollover_be_cnt_page_s[CHANNEL_NUM-1-i]);
  end
end
always_ff @(posedge core_clk or negedge core_rst_n) begin
    if (!core_rst_n) begin
      for (int i = 0; i < CHANNEL_NUM; i++)
        start_data_r[i]     <= #TP 0;
      cxl_hdr_be_cnt_r <= #TP 0;
    end else begin
      for (int i = 0; i < CHANNEL_NUM; i++)
        start_data_r[i]     <= #TP start_data_nxt[i];
      cxl_hdr_be_cnt_r <= #TP cxl_hdr_be_cnt_nxt;
    end
end
 
 
 
always_comb begin
// spyglass disable_block W164a
// SMD: Identifies assignments in which the LHS width is less than the RHS width
// SJ: cxl_hdr_data_cnt_nxt and cxl_hdr_be_cnt_nxt No overflow is possible.
    cxl_hdr_data_cnt_nxt = cxl_hdr_data_cnt_r + cxl_hdr_data_inc_s - (cxl_fmt_be[CHANNEL_NUM-1]? hdr_be_valid_s[CHANNEL_NUM-1]:  hdr_data_vld_s[CHANNEL_NUM-1]);
 // for (int i = 0; i < CHANNEL_NUM; i++) begin
    cxl_hdr_be_cnt_nxt = cxl_hdr_be_cnt_r + cxl_hdr_data_inc_s - start_data_r[CHANNEL_NUM-1] ;
 // end
// spyglass enable_block W164a
end


assign data_offset_page_s[CHANNEL_NUM-1] = data_offset_r;

always_comb begin
  data_offset_nxt= '0;
  if(unpacker_flit_valid_s) begin
    if(rollover_be_cnt_page_s[0] <= rollover_dec_s[CHANNEL_NUM-1]) begin
      data_offset_nxt = rollover_dec_s[CHANNEL_NUM-1]- rollover_be_cnt_page_s[0][1:0];
    end
  end else begin
    data_offset_nxt      = data_offset_r;
  end
end


// -------------------------------------------------------------------------------------
// Header Data Decoder based in the offset
// -------------------------------------------------------------------------------------
// Data Mux - data is selected based on the initial offset in the Data Header cycle.
//
// Offset represents the number of data chunks initially captured in the hdr_data_r
// in the Header cycle. For example, if offset=3 then 3 chunks of data is captured in
// hdr_data_r and we need to append only one last chunk of data from the current flit
// (cxl_flit_data_s) to complete data.
//
// -------------------------------------------------------------------------------------
assign cxl_hdr_data_page_s[CHANNEL_NUM-1] = cxl_hdr_data_r;

always_comb begin
hdr_data_s ='0;
  for (int i = 0; i < CHANNEL_NUM; i++) begin
    case (data_offset_page_s[CHANNEL_NUM-1-i][1:0])
      2'b01   : hdr_data_s[(512*i) +: 512] = {{(h_hs_slot && (i==0)) ? cxl_flit_data_s[SLOT_SIZE +: SLOT_SIZE*3] : cxl_flit_data_s[(512*i) +: SLOT_SIZE*3], cxl_hdr_data_page_s[CHANNEL_NUM-1-i][((FLIT_SLOT_NUM/CHANNEL_NUM)*SLOT_SIZE-1)-:1*SLOT_SIZE]}}; // Rollover=3
      2'b10   : hdr_data_s[(512*i) +: 512] = {{(h_hs_slot && (i==0)) ? cxl_flit_data_s[SLOT_SIZE +: SLOT_SIZE*2] : cxl_flit_data_s[(512*i) +: SLOT_SIZE*2], cxl_hdr_data_page_s[CHANNEL_NUM-1-i][((FLIT_SLOT_NUM/CHANNEL_NUM)*SLOT_SIZE-1)-:2*SLOT_SIZE]}}; // Rollover=2
      2'b11   : hdr_data_s[(512*i) +: 512] = {{(h_hs_slot && (i==0)) ? cxl_flit_data_s[SLOT_SIZE +: SLOT_SIZE*1] : cxl_flit_data_s[(512*i) +: SLOT_SIZE*1], cxl_hdr_data_page_s[CHANNEL_NUM-1-i][((FLIT_SLOT_NUM/CHANNEL_NUM)*SLOT_SIZE-1)-:3*SLOT_SIZE]}}; // Rollover=1
      default : hdr_data_s[(512*i) +: 512] = {cxl_flit_data_s[(512*i) +: 512]};
    endcase

end
end
always_comb begin
  for (int i = 0; i < CHANNEL_NUM; i++) begin
    if ((hdr_be_s[i])) begin
      case (rollover_be_cnt_page_s[CHANNEL_NUM-1-i][1:0])
          2'b01   : hdr_be_data_s[i] = {(h_hs_slot && (i==0)) ? cxl_flit_data_s[SLOT_SIZE*1 +: DBE_SIZE]   : cxl_flit_data_s[((512*i)+SLOT_SIZE*0) +: DBE_SIZE]};
          2'b10   : hdr_be_data_s[i] = {(h_hs_slot && (i==0)) ? cxl_flit_data_s[SLOT_SIZE*2 +: DBE_SIZE]   : cxl_flit_data_s[((512*i)+SLOT_SIZE*1) +: DBE_SIZE]}; 
          2'b11   : hdr_be_data_s[i] = {(h_hs_slot && (i==0)) ? cxl_flit_data_s[SLOT_SIZE*3 +: DBE_SIZE]   : cxl_flit_data_s[((512*i)+SLOT_SIZE*2) +: DBE_SIZE]};
          default : hdr_be_data_s[i] = cxl_flit_data_s[((512*i)+SLOT_SIZE*3) +: DBE_SIZE];
      endcase
  end
  else 
  hdr_be_data_s[i] = '1;
end
end
// -------------------------------------------------------------------------------------

// -------------------------------------------------------------------------------------
// Rollover Counter - change Rollover state if there is no CRC error
// -------------------------------------------------------------------------------------
always_comb begin
    if (unpacker_flit_valid_s) begin
// spyglass disable_block W164a
// SMD: Identifies assignments in which the LHS width is less than the RHS width
// SJ: The design intent never overflows the counter
      //for (int i = 0; i < CHANNEL_NUM; i++)
        rollover_cnt_nxt = (rollover_cnt_r  + rollover_inc_s - rollover_dec_s[0] );
// spyglass enable_block W164a
    end
    else begin
        rollover_cnt_nxt = rollover_cnt_r;
    end
  
end

// -------------------------------------------------------------------------------------
assign rollover_be_cnt_page_s[CHANNEL_NUM-1] = rollover_be_cnt_r;

always_comb begin
  if (unpacker_flit_valid_s) begin
// spyglass disable_block W164a
// SMD: Identifies assignments in which the LHS width is less than the RHS width
// SJ: The design intent never overflows the counter
    rollover_be_cnt_nxt = (rollover_be_cnt_page_s[0] - rollover_dec_s[CHANNEL_NUM-1]) + rollover_be_inc_s[CHANNEL_NUM-1];
// spyglass enable_block W164a
  end
  else begin
    rollover_be_cnt_nxt = rollover_be_cnt_r;
  end

end
// -------------------------------------------------------------------------------------

always_ff @(posedge core_clk or negedge core_rst_n) begin
    if (!core_rst_n) begin
        cxl_flit_cycle_r   <= # TP '0;
        rollover_cnt_r     <= # TP '0;
        rollover_be_cnt_r  <= # TP '0;
        cxl_hdr_data_r     <= # TP '0;
        cxl_hdr_data_cnt_r <= # TP '0;
        cxl_hdr_data_fmt_r <= # TP '0;
        cxl_hdr_poison_r   <= # TP '0;
        data_offset_r      <= # TP '0;
    end else begin
        cxl_flit_cycle_r   <= # TP cxl_flit_cycle_nxt  ;
        rollover_cnt_r     <= # TP rollover_cnt_nxt    ;
        rollover_be_cnt_r  <= # TP rollover_be_cnt_nxt ;
        cxl_hdr_data_r     <= # TP cxl_hdr_data_nxt    ;
        cxl_hdr_data_cnt_r <= # TP cxl_hdr_data_cnt_nxt;
        cxl_hdr_data_fmt_r <= # TP cxl_hdr_data_fmt_nxt;
        cxl_hdr_poison_r   <= # TP cxl_hdr_poison_nxt  ;
        data_offset_r      <= # TP data_offset_nxt     ;
    end
end
assign cxl_rx_cache_crdret_o = {{(2-HD_DDATA_NUM){1'b0}} , cxl_tl_cache_crdret_i};
assign cxl_rx_mem_crdret_o   = {{(2-MS_SM_DDATA_NUM){1'b0}}  , cxl_tl_mem_crdret_i  };
endmodule
