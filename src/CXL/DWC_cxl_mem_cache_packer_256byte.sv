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
// ---   $DateTime: 2024/01/22 13:12:34 $
// ---   $Author: neira $
// ---   $Id: //dwh/pcie_iip/main/fairbanks/design/CXL/DWC_cxl_mem_cache_packer_256byte.sv#6 $
// -----------------------------------------------------------------------------
`include "include/DWC_pcie_ctl_all_defs.svh"
`include "CXL/pkg/DWC_cxl_pkg.svh"
`include "CXL/svif/DWC_cxl_pack_llctrl_if.svh"
`include "CXL/svif/DWC_cxl_txtl_llctrl_if.svh"
module DWC_cxl_mem_cache_packer_256byte
    import DWC_cxl_pkg::*;
#(
  parameter TP = `TP
)
                                           (
    input                                       core_clk,                // Core clock
    input                                       core_rst_n,              // Core active low asynchronous reset
    input                                       cfg_device_mode,         // Device Mode 0: EP 1:RC
    input                                       cxl_pcie_flit_mode,      // Enable PCIe Flit mode / 256B FLit
    input                                       cxl_packer_force_crd,    // Force Credit signal
    input CRD_256B_t                            cxl_crd_arb_256B_crd,    // 256B Flit credit
    input                                       cfg_cache_poison_start,  // CachePoisonInjectionStart
    output                                      cfg_cache_poison_busy,   // CachePoisonInjectionBusy
    input                                       cfg_mem_poison_start,    // MemPoisonInjectionStart
    output                                      cfg_mem_poison_busy,     // MemPoisonInjectionBusy
    output                                      cxl_packer_empty_flit,
    DWC_cxl_txtl_llctrl_if.pack_slave_host_mp   b_txtl_host,             // Flit Packer to Transaction Layer Interface
    DWC_cxl_txtl_llctrl_if.pack_slave_dev_mp    b_txtl_dev,              // Flit Packer to Transaction Layer Interface
    DWC_cxl_pack_llctrl_if.slave_ctrl_mp        b_llctrl,                // Link Layer Controller to Flit Packer Interface
    DWC_cxl_pack_llctrl_if.master_pack_mp       b_pack                   // Flit Packer to Link Layer Controller Interface
);
//---------------------------------------------
//           Local Parameters
//---------------------------------------------
localparam DATA_HDR_Q_DEPTH   = 8;
localparam DATA_HDR_Q_ADDR_W  = $clog2(DATA_HDR_Q_DEPTH);
localparam NUM_DATA_HDR_SLOTS = (FLIT_SLOT_NUM == 8)? 2 : 1;
localparam NUM_DATA_CHUNKS    = (FLIT_SLOT_NUM == 8)? 2: 1;

//---------------------------------------------
//           TYPE DEF
//---------------------------------------------

typedef struct packed {
    logic                 Valid;
    DATA_TYPES_t          DataType;
    logic                 Be;
} DATA_HDR_Q_256B_t;

//---------------------------------------------
//           Signals
//---------------------------------------------
logic [TX_CRDIF_WIDTH-1:0]  mux_cache_req_vld_s;     // CXL.cache Request channel valid bit
logic [TX_CRDIF_WIDTH-1:0]  mux_cache_rsp_vld_s;     // CXL.cache Response channel valid bit
logic [TX_CRDIF_WIDTH-1:0]  mux_cache_hdr_vld_s;     // CXL.cache Data channel valid bit

logic [TX_CRDIF_WIDTH-1:0]  h2d_cache_req_vld_s;     // CXL.cache H2D Request channel valid bit
logic [TX_CRDIF_WIDTH-1:0]  h2d_cache_rsp_vld_s;     // CXL.cache H2D Response channel valid bit
logic [TX_CRDIF_WIDTH-1:0]  h2d_cache_hdr_vld_s;     // CXL.cache H2D Data channel valid bit
logic [TX_CRDIF_WIDTH-1:0]  d2h_cache_req_vld_s;     // CXL.cache D2H Request channel valid bit
logic [TX_CRDIF_WIDTH-1:0]  d2h_cache_rsp_vld_s;     // CXL.cache D2H Response channel valid bit
logic [TX_CRDIF_WIDTH-1:0]  d2h_cache_hdr_vld_s;     // CXL.cache D2H Data channel valid bit

// -------------------------------------------------------------------------------------
// CXL.mem Table Signals
// ------------------------------------------------------------------------------------- 
logic [TX_CRDIF_WIDTH-1:0]  mux_mem_ndr_vld_s;       // CXL.mem Request/Response channel valid bit
logic [TX_CRDIF_WIDTH-1:0]  mux_mem_hdr_vld_s;       // CXL.mem Data channel valid bit
logic [TX_CRDIF_WIDTH-1:0]  mux_mem_bi_vld_s;        // CXL.mem BI channel valid bit
logic [TX_CRDIF_WIDTH-1:0]  m2s_mem_req_vld_s;       // CXL.mem M2S Request channel valid bit
logic [TX_CRDIF_WIDTH-1:0]  m2s_mem_hdr_vld_s;       // CXL.mem M2S RwD channel valid bit

logic [TX_CRDIF_WIDTH-1:0]  m2s_mem_bi_rsp_vld_s;    // CXL.mem M2S BI-Response channel valid bit
logic [TX_CRDIF_WIDTH-1:0]  s2m_mem_rsp_vld_s;       // CXL.mem S2M Response channel valid bit
logic [TX_CRDIF_WIDTH-1:0]  s2m_mem_hdr_vld_s;       // CXL.mem S2M DRC channel valid bit
logic                       s2m_mem_pending_s;       // CXL.mem S2M Pending Message
logic [TX_CRDIF_WIDTH-1:0]  s2m_mem_bi_snp_vld_s;    // CXL.mem S2M BI-Snoop channel valid bit

logic             s_rst_msk;         // Reset Mask signal in case in case number of slots less than 8
logic             packer_halt;       // Halt the packer
logic             s_app_pending;     // Indicates app has pending traffic from any channel
DEVICE_MODE_t     s_cfg_device_mode; // Device mode
// Mem/Cache & Host/Device flits
SLOT_DESCR_256B_t data_hdr_slots        [0 : NUM_DATA_HDR_SLOTS-1]; // Data HDR Slots
SLOT_DESCR_256B_t roll_ovr_flit         [0 : FLIT_SLOT_NUM-1]; // Rollover Data Flit
SLOT_DESCR_256B_t packer_flit           [0 : FLIT_SLOT_NUM-1]; // The Output Flit
SLOT_DESCR_256B_t host_cache_flit  [0:FLIT_NUM_PAGE-1][0 : FLIT_SLOT_NUM_PAGE-1]; // Host Cache Flit
SLOT_DESCR_256B_t host_mem_flit    [0:FLIT_NUM_PAGE-1][0 : FLIT_SLOT_NUM_PAGE-1]; // Master Mem Flit
SLOT_DESCR_256B_t dev_cache_flit   [0:FLIT_NUM_PAGE-1][0 : FLIT_SLOT_NUM_PAGE-1]; // Device Cache Flit
SLOT_DESCR_256B_t dev_mem_flit     [0:FLIT_NUM_PAGE-1][0 : FLIT_SLOT_NUM_PAGE-1]; // Slave Mem Flit
SLOT_DESCR_256B_t cache_flit       [0:FLIT_NUM_PAGE-1][0 : FLIT_SLOT_NUM_PAGE-1]; // Host/Device Cache Flit
SLOT_DESCR_256B_t mem_flit         [0:FLIT_NUM_PAGE-1][0 : FLIT_SLOT_NUM_PAGE-1]; // Master/Slave Mem Flit
SLOT_DESCR_256B_t mem_cache_mux    [0:FLIT_NUM_PAGE-1][0 : FLIT_SLOT_NUM_PAGE-1]; // Mem/Cache arbitration Flit
// Slot counters to generate SOF/EOF
logic [3:0]         s_slot_idx, r_slot_idx;
logic               h_hs_slot;
CXL_SLOT_TYPES      cxl_slot_type;
// 
// rollover signals
logic [FLIT_SLOT_NUM-1 :0] s_roll_over_data_flg_n; // rollover data packing flag negate
logic [SLOT_CNT_WIDTH_PAGE-1:0] mem_cache_mux_idx;      // Packer flit idx
logic [SLOT_CNT_WIDTH-1:0] roll_over_idx;          // rollover flit idx
logic [SLOT_CNT_WIDTH  :0] s_roll_over_dec;        // decr. rollover counter (data slot sent)
logic [5-1             :0] s_roll_over_incr;       // Incr. rollover counter (Data HDR sent)
logic [6-1             :0] r_roll_over_cnt, s_roll_over_cnt_nxt; // Rollover counter

// Mem/Cache arbitration
RR_256B_ARB_STATE_t        mem_cache_arb;
RR_256B_ARB_STATE_t        s_cache_mem_arb_state_nxt;
RR_256B_ARB_STATE_t        r_cache_mem_arb_state;

logic                      data_max_en; // Can't pack data HDR rollover > 16
DATA_HDR_Q_256B_t          s_data_hdr_q [0:DATA_HDR_Q_DEPTH-1];  // Data HDR Q
DATA_HDR_Q_256B_t          r_data_hdr_q [0:DATA_HDR_Q_DEPTH-1];  // Data HDR Q
logic [DATA_HDR_Q_ADDR_W:0]s_data_hdr_q_wr_ptr, s_data_hdr_q_rd_ptr, r_data_hdr_q_wr_ptr, r_data_hdr_q_rd_ptr; // Data HDR Q Pointers, The pointer size is increased by 1 to detect FIFO full and empty 
logic                       s_debug_hdr_fifo_full, s_debug_hdr_fifo_empty;

logic                      eof, sof, mof; // End Of Flit/ Start Of Flit/ Mid Of Flit
logic                      cfg_host_cache_poison_busy, cfg_dev_cache_poison_busy, 
                           cfg_host_mem_poison_busy, cfg_dev_mem_poison_busy; // Poison Signals
                           
logic                      s_empty_flit_flg, r_empty_flit_flg; // Empty flit flag
logic                      crd_empty;                          // CRD is empty
logic                      cxl_packer_force_crd_s;             // CRD Forcing
logic                      host_cxl_tl_pending;                // Host messages are pending 
logic                      dev_cxl_tl_pending;                 // Device messages are pending 
logic                      cxl_tl_pending;                     // Messages are pending 

logic                     dev_cache_pending, dev_mem_pending, 
                          host_cache_pending, host_mem_pending,
                          cache_pending, mem_pending;
logic                     packer_data_sent;

DATA_TYPES_t  shift_chan;
logic         shift_en;

// Shift the Packer Data in case the rollover packer used the 1st channel to make the host/device packer use the 2nd data channel for 128B packer
// so the shift_en=1 if the roll_over data is sent in a specific channel type
logic shift_h2d_data;
assign shift_h2d_data = 1'b0;
logic shift_m2s_data;
assign shift_m2s_data =1'b0; 
logic shift_d2h_data;
assign shift_d2h_data = 1'b0; 
logic shift_s2m_data;
assign shift_s2m_data = 1'b0;  

assign s_cfg_device_mode =  (cfg_device_mode)? CXL_RC_H_M:CXL_EP_D_S;
assign cache_flit        = (s_cfg_device_mode == CXL_RC_H_M)? host_cache_flit  : dev_cache_flit;
assign mem_flit          = (s_cfg_device_mode == CXL_RC_H_M)? host_mem_flit    : dev_mem_flit;


// TODO make the arbitration done at SOF
// MEM cache Arbiter
//RR Arbiter between MEM and Cache flits 
always_comb begin
  s_cache_mem_arb_state_nxt = r_cache_mem_arb_state;
  mem_cache_arb             = r_cache_mem_arb_state;
  if(((r_cache_mem_arb_state == CXL_256B_MEM) & mem_pending) | (!cache_pending)) begin
    mem_cache_arb             = CXL_256B_MEM;
    s_cache_mem_arb_state_nxt = CXL_256B_CACHE;
  end
  else if (cache_pending) begin
    mem_cache_arb             = CXL_256B_CACHE;
    s_cache_mem_arb_state_nxt = CXL_256B_MEM;
  end
end

always_ff @(posedge core_clk or negedge core_rst_n) begin
  if(!core_rst_n) begin 
    r_cache_mem_arb_state <= #TP CXL_256B_MEM;
  end
  else if (!packer_halt)  begin
    r_cache_mem_arb_state <= #TP s_cache_mem_arb_state_nxt;
  end
end

assign cache_pending = 1'b0 | host_cache_pending
 | dev_cache_pending;
assign mem_pending   = 1'b0 | host_mem_pending 
 | dev_mem_pending;
assign mem_cache_mux = (mem_cache_arb == CXL_256B_CACHE)? cache_flit:mem_flit;


assign cfg_cache_poison_busy = 1'b0 | cfg_host_cache_poison_busy
 | cfg_dev_cache_poison_busy;
assign cfg_mem_poison_busy   = 1'b0 | cfg_host_mem_poison_busy 
 | cfg_dev_mem_poison_busy;

// Host Slot Packing
  logic  s_dsp_packer_en; // Enable Host packer
  assign s_dsp_packer_en = cxl_pcie_flit_mode & (s_cfg_device_mode == CXL_RC_H_M);

  DWC_cxl_mem_cache_packer_256byte_dsp
  
  u_mem_cache_packer_dsp_256byte (
    .core_clk               ( core_clk                   ),
    .core_rst_n             ( core_rst_n                 ),      
    .pack_enable            ( s_dsp_packer_en           ),      
    .cxl_packer_flit        ( packer_flit                ),       
    .cxl_prot_msg_halt      ( packer_halt                ),      
    .cxl_prot_data_halt     ( packer_halt                ),      
    .cxl_slot_type          ( cxl_slot_type              ),
    .b_llctrl               ( b_llctrl                   ),      
    .b_txtl_llctrl          ( b_txtl_host                ),
    .cxl_rst_msk            ( s_rst_msk                  ),
    .cxl_data_en            ( data_max_en                ),
    .mem_cache_arb          ( r_cache_mem_arb_state      ),
    .roll_over_cnt          ( r_roll_over_cnt            ),
    .shift_h2d_data         ( shift_h2d_data             ),      
    .cfg_cache_poison_start ( cfg_cache_poison_start     ), 
    .cfg_cache_poison_busy  ( cfg_host_cache_poison_busy ), 
    .cache_req_vld          ( h2d_cache_req_vld_s        ), 
    .cache_rsp_vld          ( h2d_cache_rsp_vld_s        ), 
    .cache_hdr_vld          ( h2d_cache_hdr_vld_s        ), 
    .cache_flit             ( host_cache_flit            ),  
    .cxl_cache_pending      ( host_cache_pending         ),  

    .shift_m2s_data         ( shift_m2s_data             ),  
    .cfg_mem_poison_start   ( cfg_mem_poison_start       ),   
    .cfg_mem_poison_busy    ( cfg_host_mem_poison_busy   ),
    .mem_req_vld            ( m2s_mem_req_vld_s          ),   
    .mem_hdr_vld            ( m2s_mem_hdr_vld_s          ),
    .mem_rsp_vld            ( m2s_mem_bi_rsp_vld_s       ),   
    .mem_flit               ( host_mem_flit              ),    
    .cxl_mem_pending        ( host_mem_pending           ),    
    .cxl_tl_pending_o       ( host_cxl_tl_pending        )

  );



// Device Slot Packing
  logic  s_usp_packer_en; // Enable Device slot packing
  assign s_usp_packer_en = cxl_pcie_flit_mode & (s_cfg_device_mode == CXL_EP_D_S);

  DWC_cxl_mem_cache_packer_256byte_usp
  
  u_mem_cache_packer_usp_256byte(
    .core_clk               ( core_clk                  ),
    .core_rst_n             ( core_rst_n                ),      
    .pack_enable            ( s_usp_packer_en           ),      
    .cxl_packer_flit        ( packer_flit               ),       
    .cxl_prot_msg_halt      ( packer_halt               ),      
    .cxl_prot_data_halt     ( packer_halt               ),      
    .cxl_slot_type          ( cxl_slot_type             ),
    .b_llctrl               ( b_llctrl                  ),      
    .b_txtl_llctrl          ( b_txtl_dev                ),
    .cxl_rst_msk            ( s_rst_msk                 ),
    .cxl_data_en            ( data_max_en               ),
    .mem_cache_arb          ( r_cache_mem_arb_state     ),
    .roll_over_cnt          ( r_roll_over_cnt            ),
    .shift_d2h_data         ( shift_d2h_data            ), 
    .cfg_cache_poison_start ( cfg_cache_poison_start    ), 
    .cfg_cache_poison_busy  ( cfg_dev_cache_poison_busy ), 
    .cache_req_vld          ( d2h_cache_req_vld_s       ), 
    .cache_rsp_vld          ( d2h_cache_rsp_vld_s       ), 
    .cache_hdr_vld          ( d2h_cache_hdr_vld_s       ), 
    .cache_flit             ( dev_cache_flit            ),
    .cxl_cache_pending      ( dev_cache_pending         ),      
    .shift_s2m_data         ( shift_s2m_data            ),
    .cfg_mem_poison_start   ( cfg_mem_poison_start      ),
    .cfg_mem_poison_busy    ( cfg_dev_mem_poison_busy   ),
    .mem_rsp_vld            ( s2m_mem_rsp_vld_s         ),
    .mem_hdr_vld            ( s2m_mem_hdr_vld_s         ),
    .mem_flit               ( dev_mem_flit              ), 
    .cxl_mem_pending        ( dev_mem_pending           ),    
    .mem_req_vld            ( s2m_mem_bi_snp_vld_s      ),
    .cxl_tl_pending_o       ( dev_cxl_tl_pending        )

  );
logic empty_flit_en_n; // Enable sending empty flits
assign empty_flit_en_n  = !s_app_pending;

// Combining and Passing app_pending signal
assign b_pack.s_cxl_app_pending = s_app_pending;
assign s_app_pending = 0
 || b_txtl_host.s_cxl_cache_app_pending 
   || b_txtl_host.s_cxl_mem_app_pending 
 || b_txtl_dev.s_cxl_cache_app_pending 
   || b_txtl_dev.s_cxl_mem_app_pending 
 ; // CX_CXL_USP_PACKER_ENABLE 


// assert the halt In case no valid HDRs and No rollover data the packer and stop sending empty slots unless the feature is enabled 
assign cxl_packer_force_crd_s = (cxl_packer_force_crd)? ((cxl_crd_arb_256B_crd.CRD_C != 'b0) || (cxl_crd_arb_256B_crd.CRD_B != 'b0) || (cxl_crd_arb_256B_crd.CRD_A != 'b0)) : 1'b0;

// This is to ensure that all CRD is flushed once the ACK flush timer is expired 
logic cxl_packer_crd_flush_s;
logic cxl_packer_crd_flush_r;
// if cxl_tl_pending this means the packer will send a protocol flit so there is no need to force send a credit flit
always_comb begin
  cxl_packer_crd_flush_s = cxl_packer_crd_flush_r;
  if (crd_empty || cxl_tl_pending)
    cxl_packer_crd_flush_s = 1'b0;   
  else if (cxl_packer_force_crd_s)
    cxl_packer_crd_flush_s = 1'b1;
    
end
always_ff @(posedge core_clk or negedge core_rst_n) begin
  if(!core_rst_n) begin 
    cxl_packer_crd_flush_r <= #TP 1'b0;
  end
  else begin
    cxl_packer_crd_flush_r <= #TP cxl_packer_crd_flush_s;
  end
end


assign packer_halt            = (
                                  (cxl_tl_pending || cxl_packer_crd_flush_s || (|r_roll_over_cnt) 
) ? 1'b0: (sof && empty_flit_en_n) 
                                ) ||
                                b_llctrl.s_cxl_ll_packer_halt || (!cxl_pcie_flit_mode);
                                
assign cxl_tl_pending         = '0 
   || host_cxl_tl_pending
 || dev_cxl_tl_pending;
                              
// Slot counter 
always_comb begin
  s_slot_idx = r_slot_idx;
  if (!packer_halt) 
    s_slot_idx = s_slot_idx + FLIT_SLOT_NUM; // addd the nubmer of slots that are sent in one cycle depending on the datapath width
end
always_ff @(posedge core_clk or negedge core_rst_n) begin
  if(!core_rst_n) begin 
    r_slot_idx <= #TP 'd0;
  end
  else begin
    r_slot_idx <= #TP s_slot_idx;
  end
end
// End Of Flit
assign eof               = s_slot_idx == 'd0;
// Mid of Flit
assign mof               = r_slot_idx == 'd8;
// Start Of Flit
assign sof               = r_slot_idx == 'd0;
// Reset packing counters after 8 slots
assign s_rst_msk         = eof | (s_slot_idx=='d8);
  assign cxl_slot_type        = (sof)? CXL_256B_SLOT_H : 
                                ( CXL_256B_SLOT_G); 
assign h_hs_slot = sof;
// ----------------------------------------------------------
// Roll Over Data Handling
//---------------------------------------------------------
assign data_max_en = (r_roll_over_cnt<=16); // Disable data HDR packing in case r_roll_over_cnt > 16

// Depending on Roll over Counter we select between slots from Slot Packer 
// and slots from Roll Over Data
// Note at SOF/MOF, H/Hs slot must contain Headers
// If s_roll_over_data_flg_n of a spcific slot = 1, the slot will be packed from the host/device packer ,else it will be packed from the rollover data
always_comb begin
  s_roll_over_data_flg_n = '1;
  if (h_hs_slot) begin
    s_roll_over_data_flg_n    = s_roll_over_data_flg_n << (r_roll_over_cnt+'d1);
    s_roll_over_data_flg_n[0] = 1'b1;
  end 
  else begin
    s_roll_over_data_flg_n = s_roll_over_data_flg_n << r_roll_over_cnt;
  end
end

// Extract Data HDRs slots from the current flit 
// in case of 8 Slot,  we can send up to 2 slots with HDRs
// in case of 4 Slot,  we can send up to 1 slots with HDRs
always_comb begin
  for (int i=0; i < NUM_DATA_HDR_SLOTS; i++) data_hdr_slots[i] = '0;
  
  for (int slot_idx=0; slot_idx < FLIT_SLOT_NUM ; slot_idx ++) begin
    if (packer_flit[slot_idx].slot_idx[3]) begin // all Data slots MSB is 1
      data_hdr_slots[slot_idx/4] = packer_flit[slot_idx];
    end
  end
end



// IF s_roll_over_data_flg_n[idx] == 1 --> Read New Data from Slot Packer
// Else We need to read Data from Roll Over
// For EOF the number of slots is reduced by 1 for CRC and Credit (last slot of the flit is RSVD for CRC and CRD)
always_comb begin
  s_roll_over_dec   = 'd0;
  s_roll_over_incr  = 'd0;
  mem_cache_mux_idx = 'd0;
  packer_data_sent  = 'd0;
  s_roll_over_cnt_nxt = r_roll_over_cnt;
  for (int slot_idx=0; slot_idx < FLIT_SLOT_NUM ; slot_idx ++) begin
    roll_over_idx     = (h_hs_slot)? (slot_idx - 'd1) : slot_idx; // -'d1 to exclude the packed H slot

    packer_flit[slot_idx]  = 'd0;
    if ((eof & (slot_idx != (FLIT_SLOT_NUM-1))) | (!eof)) begin
      if (s_roll_over_data_flg_n[slot_idx]) begin // New Slots from the Slot packer

        if (mem_cache_mux[slot_idx/4][mem_cache_mux_idx].slot_type == CXL_256B_SLOT_DATA)
          s_roll_over_dec      = s_roll_over_dec + 'd1; //dec roll_over_cnt if a data slot is sent from slot packer
        // Full data Chunk sent in the slot packer 
        if (mem_cache_mux[slot_idx/4][mem_cache_mux_idx].data_info.data_end)
          packer_data_sent = 1'b1;
        
        packer_flit[slot_idx]  = mem_cache_mux[slot_idx/4][mem_cache_mux_idx];
        mem_cache_mux_idx      = mem_cache_mux_idx + 'd1;
      end
      else begin // Roll Over Data
        s_roll_over_dec        = s_roll_over_dec + 'd1; //dec roll_over_cnt if a data slot is sent from roll_over data
        packer_flit[slot_idx]  = roll_ovr_flit[roll_over_idx];
      end
    end 
  end
// spyglass disable_block W164a
// SMD: Identifies assignments in which the LHS width is less than the RHS width
// SJ: s_roll_over_cnt_nxt max is 36, no overflow expected
  for (int i=0; i < NUM_DATA_HDR_SLOTS ; i ++) 
    s_roll_over_incr       = s_roll_over_incr + data_hdr_slots[i].Data; // inc roll_over_cnt when a DHDR is sent on packer_flit
  
  s_roll_over_cnt_nxt = s_roll_over_cnt_nxt + s_roll_over_incr - s_roll_over_dec;
// spyglass enable_block W164a

end

always_ff @(posedge core_clk or negedge core_rst_n) begin
  if(!core_rst_n) begin 
    r_roll_over_cnt <= #TP 'd0;
  end
  else if (!packer_halt) begin
    r_roll_over_cnt <= #TP s_roll_over_cnt_nxt;
  end
end
DATA_HDR_Q_256B_t ss_data_hdr_q  [0:4];
logic             ss_data_hdr_q_wr_ptr;
logic [4:0]       s_data_hdr_vld;
// Save all Data headers in a queue


// spyglass disable_block W468
// SMD: Index variable is too short
// SJ: ss_data_hdr_q_wr_ptr can access the full range in some cases
always_comb begin
  for (int i=0; i < 5; i++) ss_data_hdr_q[i] = '0;
  ss_data_hdr_q_wr_ptr = '0;
  s_data_hdr_vld       = '0;
  s_data_hdr_q         = r_data_hdr_q;
  s_data_hdr_q_wr_ptr  = r_data_hdr_q_wr_ptr;
  // Extract HDRs from the output flits 
  // We max. can have 5 HDRs per cycle in case of 1024 1 HDR followed by 4 HDRs (in 2 slots NUM_DATA_HDR_SLOTS=2)
  // or 4 HDRs in case of 512 bits (in one slot NUM_DATA_HDR_SLOTS=1)
  // create a queue of the DHDR to maintan the order of the data corresponding to each DHDR
  for (int slot_idx=0; slot_idx < NUM_DATA_HDR_SLOTS ; slot_idx ++) begin
    // Write in HDR Q
    case (data_hdr_slots[slot_idx].slot_idx[1:0])
      2'b00: begin // slot12
           //4 H2D DH
        casez (data_hdr_slots[slot_idx].data_vld)
          4'b1???: begin // 4 (max per slot) HDRS are valid
            ss_data_hdr_q[0+ss_data_hdr_q_wr_ptr] = '{1'b1, CXL_256B_CACHE_H, 1'b0};
            ss_data_hdr_q[1+ss_data_hdr_q_wr_ptr] = '{1'b1, CXL_256B_CACHE_H, 1'b0};
            ss_data_hdr_q[2+ss_data_hdr_q_wr_ptr] = '{1'b1, CXL_256B_CACHE_H, 1'b0};
            ss_data_hdr_q[3+ss_data_hdr_q_wr_ptr] = '{1'b1, CXL_256B_CACHE_H, 1'b0};
            s_data_hdr_vld                        = (ss_data_hdr_q_wr_ptr)? 5'b11111: 5'b01111;
          end
          4'b01??: begin // 3 HDRS are valid
            ss_data_hdr_q[0+ss_data_hdr_q_wr_ptr] = '{1'b1, CXL_256B_CACHE_H, 1'b0};
            ss_data_hdr_q[1+ss_data_hdr_q_wr_ptr] = '{1'b1, CXL_256B_CACHE_H, 1'b0};
            ss_data_hdr_q[2+ss_data_hdr_q_wr_ptr] = '{1'b1, CXL_256B_CACHE_H, 1'b0};
            s_data_hdr_vld                        = (ss_data_hdr_q_wr_ptr)? 5'b01111: 5'b00111;
          end
          4'b001?: begin // 2 HDRS are valid
            ss_data_hdr_q[0+ss_data_hdr_q_wr_ptr] = '{1'b1, CXL_256B_CACHE_H, 1'b0};
            ss_data_hdr_q[1+ss_data_hdr_q_wr_ptr] = '{1'b1, CXL_256B_CACHE_H, 1'b0};
            s_data_hdr_vld                        = (ss_data_hdr_q_wr_ptr)? 5'b00111: 5'b00011;
        end
          4'b0001: begin // 1 HDR is valid
            ss_data_hdr_q[ss_data_hdr_q_wr_ptr].DataType = CXL_256B_CACHE_H; 
            ss_data_hdr_q[ss_data_hdr_q_wr_ptr].Be       = 1'b0; 
            s_data_hdr_vld[ss_data_hdr_q_wr_ptr]         = 1'b1;
      end
        endcase

      end
      2'b01: begin // slot13
        //4 D2H DH
        casez (data_hdr_slots[slot_idx].data_vld)
          4'b1???: begin
            ss_data_hdr_q[0+ss_data_hdr_q_wr_ptr] = '{1'b1, CXL_256B_CACHE_D, data_hdr_slots[slot_idx].be_vld[0]};
            ss_data_hdr_q[1+ss_data_hdr_q_wr_ptr] = '{1'b1, CXL_256B_CACHE_D, data_hdr_slots[slot_idx].be_vld[1]};
            ss_data_hdr_q[2+ss_data_hdr_q_wr_ptr] = '{1'b1, CXL_256B_CACHE_D, data_hdr_slots[slot_idx].be_vld[2]};
            ss_data_hdr_q[3+ss_data_hdr_q_wr_ptr] = '{1'b1, CXL_256B_CACHE_D, data_hdr_slots[slot_idx].be_vld[3]};
            s_data_hdr_vld                        = (ss_data_hdr_q_wr_ptr)? 5'b11111: 5'b01111;
          end
          4'b01??: begin
            ss_data_hdr_q[0+ss_data_hdr_q_wr_ptr] = '{1'b1, CXL_256B_CACHE_D, data_hdr_slots[slot_idx].be_vld[0]};
            ss_data_hdr_q[1+ss_data_hdr_q_wr_ptr] = '{1'b1, CXL_256B_CACHE_D, data_hdr_slots[slot_idx].be_vld[1]};
            ss_data_hdr_q[2+ss_data_hdr_q_wr_ptr] = '{1'b1, CXL_256B_CACHE_D, data_hdr_slots[slot_idx].be_vld[2]};
            s_data_hdr_vld                        = (ss_data_hdr_q_wr_ptr)? 5'b01111: 5'b00111;
          end
          4'b001?: begin
            ss_data_hdr_q[0+ss_data_hdr_q_wr_ptr] = '{1'b1, CXL_256B_CACHE_D, data_hdr_slots[slot_idx].be_vld[0]};
            ss_data_hdr_q[1+ss_data_hdr_q_wr_ptr] = '{1'b1, CXL_256B_CACHE_D, data_hdr_slots[slot_idx].be_vld[1]};
            s_data_hdr_vld                        = (ss_data_hdr_q_wr_ptr)? 5'b00111: 5'b00011;
        end
          4'b0001: begin
            ss_data_hdr_q[ss_data_hdr_q_wr_ptr].DataType = CXL_256B_CACHE_D; 
            ss_data_hdr_q[ss_data_hdr_q_wr_ptr].Be       = data_hdr_slots[slot_idx].be_vld[0]; 
            s_data_hdr_vld[ss_data_hdr_q_wr_ptr]         = 1'b1;
        end
        endcase
      end
      2'b10: begin  //1 M2S RwD
        if (data_hdr_slots[slot_idx].data_vld[0]) begin
          ss_data_hdr_q[ss_data_hdr_q_wr_ptr].DataType = CXL_256B_MEM_M; 
          ss_data_hdr_q[ss_data_hdr_q_wr_ptr].Be       = data_hdr_slots[slot_idx].be_vld[0]; 
          s_data_hdr_vld[ss_data_hdr_q_wr_ptr]         = 1'b1;
        end
      end
      2'b11: begin  //3 S2M DRS
        casez (data_hdr_slots[slot_idx].data_vld[2:0])
          3'b1??: begin
            ss_data_hdr_q[0+ss_data_hdr_q_wr_ptr] = '{1'b1, CXL_256B_MEM_S,1'b0};
            ss_data_hdr_q[1+ss_data_hdr_q_wr_ptr] = '{1'b1, CXL_256B_MEM_S,1'b0};
            ss_data_hdr_q[2+ss_data_hdr_q_wr_ptr] = '{1'b1, CXL_256B_MEM_S,1'b0};
            s_data_hdr_vld                        = (ss_data_hdr_q_wr_ptr)? 5'b01111: 5'b00111;
          end
          3'b01?: begin
            ss_data_hdr_q[0+ss_data_hdr_q_wr_ptr] = '{1'b1, CXL_256B_MEM_S,1'b0};
            ss_data_hdr_q[1+ss_data_hdr_q_wr_ptr] = '{1'b1, CXL_256B_MEM_S,1'b0};
            s_data_hdr_vld                        = (ss_data_hdr_q_wr_ptr)? 5'b00111: 5'b00011;
        end
          3'b001: begin
            ss_data_hdr_q[ss_data_hdr_q_wr_ptr].DataType = CXL_256B_MEM_S; 
            ss_data_hdr_q[ss_data_hdr_q_wr_ptr].Be       = 1'b0; 
            s_data_hdr_vld[ss_data_hdr_q_wr_ptr]         = 1'b1;
      end
        endcase
      end
    endcase
  end
  // Push Data to the FIFO
  casez (s_data_hdr_vld)
    5'b01???: begin
      s_data_hdr_q[s_data_hdr_q_wr_ptr[DATA_HDR_Q_ADDR_W-1:0]] = ss_data_hdr_q[0];
      s_data_hdr_q_wr_ptr                                      = r_data_hdr_q_wr_ptr + 1;
      s_data_hdr_q[s_data_hdr_q_wr_ptr[DATA_HDR_Q_ADDR_W-1:0]] = ss_data_hdr_q[1];
      s_data_hdr_q_wr_ptr                                      = r_data_hdr_q_wr_ptr + 2;
      s_data_hdr_q[s_data_hdr_q_wr_ptr[DATA_HDR_Q_ADDR_W-1:0]] = ss_data_hdr_q[2];
      s_data_hdr_q_wr_ptr                                      = r_data_hdr_q_wr_ptr + 3;
      s_data_hdr_q[s_data_hdr_q_wr_ptr[DATA_HDR_Q_ADDR_W-1:0]] = ss_data_hdr_q[3];
      s_data_hdr_q_wr_ptr                                      = r_data_hdr_q_wr_ptr + 4;
    end
    5'b001??: begin
      s_data_hdr_q[s_data_hdr_q_wr_ptr[DATA_HDR_Q_ADDR_W-1:0]] = ss_data_hdr_q[0];
      s_data_hdr_q_wr_ptr =                                      r_data_hdr_q_wr_ptr + 1;
      s_data_hdr_q[s_data_hdr_q_wr_ptr[DATA_HDR_Q_ADDR_W-1:0]] = ss_data_hdr_q[1];
      s_data_hdr_q_wr_ptr                                      = r_data_hdr_q_wr_ptr + 2;
      s_data_hdr_q[s_data_hdr_q_wr_ptr[DATA_HDR_Q_ADDR_W-1:0]] = ss_data_hdr_q[2];
      s_data_hdr_q_wr_ptr                                      = r_data_hdr_q_wr_ptr + 3;
end
    5'b0001?: begin
      s_data_hdr_q[s_data_hdr_q_wr_ptr[DATA_HDR_Q_ADDR_W-1:0]] = ss_data_hdr_q[0];
      s_data_hdr_q_wr_ptr                                      = r_data_hdr_q_wr_ptr + 1;
      s_data_hdr_q[s_data_hdr_q_wr_ptr[DATA_HDR_Q_ADDR_W-1:0]] = ss_data_hdr_q[1];
      s_data_hdr_q_wr_ptr                                      = r_data_hdr_q_wr_ptr + 2;
end
    5'b00001: begin
      s_data_hdr_q[s_data_hdr_q_wr_ptr[DATA_HDR_Q_ADDR_W-1:0]] = ss_data_hdr_q[0];
      s_data_hdr_q_wr_ptr                                      = r_data_hdr_q_wr_ptr + 1;
    end
  endcase
end
// spyglass enable_block W468

assign s_debug_hdr_fifo_full  = (r_data_hdr_q_wr_ptr[DATA_HDR_Q_ADDR_W-1:0] == r_data_hdr_q_rd_ptr[DATA_HDR_Q_ADDR_W-1:0]) && (r_data_hdr_q_wr_ptr[DATA_HDR_Q_ADDR_W-1] ^ r_data_hdr_q_rd_ptr[DATA_HDR_Q_ADDR_W-1]);
assign s_debug_hdr_fifo_empty = (r_data_hdr_q_wr_ptr == r_data_hdr_q_rd_ptr);

// Save incomplete Rollover data and Byte Enable
logic [511:0] s_roll_over_data, r_roll_over_data; // Rollover Data
logic [63 :0] s_roll_over_be, r_roll_over_be;     // Rollover BE
logic [2:0]   s_last_slot_idx, r_last_slot_idx;   // Last rollover data sent
DATA_INFO_t   last_slot_info;                     // Last slot in the current flit
always_ff @(posedge core_clk or negedge core_rst_n) begin
  if(!core_rst_n) begin 
    r_roll_over_data  <= #TP 'd0;
    r_roll_over_be    <= #TP 'd0;
    r_last_slot_idx   <= #TP 'd0;
  end
  else if (!packer_halt) begin
    r_roll_over_data  <= #TP s_roll_over_data;  
    r_roll_over_be    <= #TP s_roll_over_be;  
    r_last_slot_idx   <= #TP s_last_slot_idx;  
  end
end
assign last_slot_info       = (eof)? packer_flit[FLIT_SLOT_NUM-2].data_info // last slot index that the packer pack is (FLIT_SLOT_NUM-2) as the last slot (FLIT_SLOT_NUM-1) is RSVD for CRC and CRD
                                   : packer_flit[FLIT_SLOT_NUM-1].data_info;
assign s_last_slot_idx      = (last_slot_info.data_end | (!last_slot_info.is_data))? 'd0: last_slot_info.data_slot_idx + 'd1;

// incase of incomplete rollover data, we need to store Data and BE to next cycle 
// When halt [1] is assereted (==0) this means that the 1st 512 bits are sent and no need to store them
// the halt always ==1 on the ready valid channel that is not captured and sent by the packer
  always_comb begin
    s_roll_over_data = r_roll_over_data;
    s_roll_over_be   = r_roll_over_be;
    unique case (last_slot_info.data_type) 
      CXL_256B_CACHE_H : begin 
        s_roll_over_data   = 
                              (!b_txtl_host.s_cxl_h2d_data_halt[0])? b_txtl_host.s_cxl_h2d_data[0] : r_roll_over_data;
      end
      CXL_256B_MEM_M   : begin 
        s_roll_over_data   =  
                              (!b_txtl_host.s_cxl_m2s_data_halt[0])? b_txtl_host.s_cxl_m2s_data[0] : r_roll_over_data;
        s_roll_over_be     =  
                              (!b_txtl_host.s_cxl_m2s_data_halt[0])? b_txtl_host.s_cxl_m2s_be[0] : r_roll_over_be;
      end
      CXL_256B_CACHE_D : begin
        s_roll_over_data   =  
                              (!b_txtl_dev.s_cxl_d2h_data_halt[0])? b_txtl_dev.s_cxl_d2h_data[0]: r_roll_over_data;
        s_roll_over_be     =  
                              (!b_txtl_dev.s_cxl_d2h_data_halt[0])?  b_txtl_dev.s_cxl_d2h_be[0] : r_roll_over_be;
      end
      CXL_256B_MEM_S   : begin
        s_roll_over_data   =  
                              (!b_txtl_dev.s_cxl_s2m_data_halt[0]) ? b_txtl_dev.s_cxl_s2m_data[0] : r_roll_over_data;
      end
      default          : s_roll_over_data   =  r_roll_over_data;
    endcase
  end

//-----------------------------------------------------------------------------
// Roll OVER Flit
//-------------------------------------------------------------
logic                         mem_data_chan, cache_data_chan;
logic                         is_roll_data_vld; // There is a rolldata stored inside the packer from the previous cycle
logic [511:0]                 curr_data [0: NUM_DATA_CHUNKS-1];
logic [63:0]                  curr_be [0: NUM_DATA_CHUNKS-1];
logic [1:0]                   data_hdr_num; // Number of Data chunks sent on the current cycle
DATA_HDR_Q_256B_t             s_curr_hdr_q; 
logic  [FLIT_SLOT_NUM-1:0]    roll_over_slot_vld;
logic [DATA_HDR_Q_ADDR_W:0]   ss_data_hdr_q_rd_ptr; // Data HDR Q Pointers
logic [NUM_DATA_CHUNKS : 0]   is_be;
DATA_TYPES_t                  data_types [0: NUM_DATA_CHUNKS];
SLOT_DESCR_256B_t             roll_ovr_flit_temp [0 : FLIT_SLOT_NUM-1]; // Rollover Data Flit





// No headers are packed here
// We need to create rollover Data flit based rollover counters
always_comb begin
  // Define slots that will carry rollover data based on rollover counters
  roll_over_slot_vld = {FLIT_SLOT_NUM{1'b1}};
  roll_over_slot_vld = roll_over_slot_vld << r_roll_over_cnt;
  //@SOF 1st slot must be H slot (can not carry Data)
  //@MOF 1st slot must be Hs slot (can not carry Data)
  //@EOF the last slot carry CRD and CRC info (can not carry Data)
  if (eof | h_hs_slot)
    roll_over_slot_vld [FLIT_SLOT_NUM-1] = 1'b1;
  roll_over_slot_vld = ~roll_over_slot_vld;

  data_hdr_num         = 'd0;
  cache_data_chan      = 'd0;
  mem_data_chan        = 'd0;
  // Check if roll Data is available from the previous cycle
  is_roll_data_vld     =|r_last_slot_idx;
  
  
  // In CXL, the Data size is fixed to 4 Slots + 1 BE (if exist) 
  // in case of Num of slots is 8 the packer can serve up to 3 Header from the Q 
  // 2 New Headers + 1 old Header (Started in the previous cycle)
  // in case of Num of slots is less than 8 the packer can serve up to 2 Header 
  // 1 New Headers + 1 old Header
  
  
  // First, assume there is no incomplete rollover data from previous cycle and write 
  // this data to roll_ovr_flit_temp
  for (int i=0; i < NUM_DATA_CHUNKS ; i ++) begin
// spyglass disable_block W164a
// SMD: Identifies assignments in which the LHS width is less than the RHS width
// SJ: FIFO pointers, no overflow expected
    ss_data_hdr_q_rd_ptr = r_data_hdr_q_rd_ptr + i + is_roll_data_vld;
// spyglass enable_block W164a

    s_curr_hdr_q         = r_data_hdr_q[ss_data_hdr_q_rd_ptr[DATA_HDR_Q_ADDR_W-1:0]];
    curr_data[i]         = 'd0;
    curr_be[i]           = 'd0;  
    is_be[i]             = 'd0;  
    data_types[i]        = CXL_256B_CACHE_H;// Just init.
// pack the new Headers (1 for 4spacker / 2 for 8spacker)
// spyglass disable_block W468
// SMD: Index variable is too short
// SJ: The max. number of BE that can be sent is only 2 
    unique case (s_curr_hdr_q.DataType)
      CXL_256B_CACHE_H : begin
        curr_data[i]    = b_txtl_host.s_cxl_h2d_data[cache_data_chan];
        curr_be[i]      = '0;
        data_types[i]   = s_curr_hdr_q.DataType;
        cache_data_chan = H2D_256B_DDATA_NUM-1;
      end
      CXL_256B_MEM_M   : begin 
        curr_data[i]    = b_txtl_host.s_cxl_m2s_data[mem_data_chan];
        curr_be[i]      = b_txtl_host.s_cxl_m2s_be[mem_data_chan];
        is_be[i]        = s_curr_hdr_q.Be;
        data_types[i]   = s_curr_hdr_q.DataType;
        mem_data_chan   = M2S_256B_DDATA_NUM-1;
      end
      CXL_256B_CACHE_D : begin 
        curr_data[i]    = b_txtl_dev.s_cxl_d2h_data[cache_data_chan];
        curr_be[i]      = b_txtl_dev.s_cxl_d2h_be[cache_data_chan];
        is_be[i]        = s_curr_hdr_q.Be;
        data_types[i]   = s_curr_hdr_q.DataType;
        cache_data_chan = D2H_256B_DDATA_NUM-1;
      end
      CXL_256B_MEM_S   : begin 
        curr_data[i]    = b_txtl_dev.s_cxl_s2m_data[mem_data_chan];
        curr_be[i]      = '0;
        data_types[i]   = s_curr_hdr_q.DataType;
        mem_data_chan   = S2M_256B_DDATA_NUM-1;
      end
      default : begin
        curr_data[i]    = 'd0;
        curr_be[i]      = 'd0;  
        is_be[i]        = 'd0;  
        data_types[i]   = CXL_256B_CACHE_H;// Just init.
      end
    endcase
  end
// spyglass enable_block W468

  roll_ovr_flit_temp[0]   = pack_data(curr_data[0], curr_be[0],'d0, is_be[0], data_types[0]);
  roll_ovr_flit_temp[1]   = pack_data(curr_data[0], curr_be[0],'d1, is_be[0], data_types[0]);
  roll_ovr_flit_temp[2]   = pack_data(curr_data[0], curr_be[0],'d2, is_be[0], data_types[0]);
  roll_ovr_flit_temp[3]   = pack_data(curr_data[0], curr_be[0],'d3, is_be[0], data_types[0]);
  
  
  // 2nd, Shift roll_ovr_flit_temp in case there is incomplete data from previous cycle (pack 1 old Header)
  is_be[NUM_DATA_CHUNKS]      = r_data_hdr_q[r_data_hdr_q_rd_ptr[DATA_HDR_Q_ADDR_W-1:0]].Be;
  data_types[NUM_DATA_CHUNKS] = r_data_hdr_q[r_data_hdr_q_rd_ptr[DATA_HDR_Q_ADDR_W-1:0]].DataType;
  unique case (r_last_slot_idx)
    3'h1: begin
      roll_ovr_flit[0] = roll_over_slot_vld[0]? pack_data(r_roll_over_data, r_roll_over_be,'d1, is_be[NUM_DATA_CHUNKS], data_types[NUM_DATA_CHUNKS]) : '0;
      roll_ovr_flit[1] = roll_over_slot_vld[1]? pack_data(r_roll_over_data, r_roll_over_be,'d2, is_be[NUM_DATA_CHUNKS], data_types[NUM_DATA_CHUNKS]) : '0;
      roll_ovr_flit[2] = roll_over_slot_vld[2]? pack_data(r_roll_over_data, r_roll_over_be,'d3, is_be[NUM_DATA_CHUNKS], data_types[NUM_DATA_CHUNKS]) : '0;
      roll_ovr_flit[3] = roll_over_slot_vld[3]? ((is_be[NUM_DATA_CHUNKS])? pack_data(r_roll_over_data, r_roll_over_be,'d4, is_be[NUM_DATA_CHUNKS], data_types[NUM_DATA_CHUNKS]) :
                                                   roll_ovr_flit_temp[0]) : '0;
                                                   
      for (int i =4;i<FLIT_SLOT_NUM;i++)
        roll_ovr_flit[i] = roll_over_slot_vld[i]? ((is_be[NUM_DATA_CHUNKS])?roll_ovr_flit_temp[i-4]:roll_ovr_flit_temp[i-3]) : '0;
    end
    3'h2: begin
      roll_ovr_flit[0] = roll_over_slot_vld[0]? pack_data(r_roll_over_data, r_roll_over_be,'d2, is_be[NUM_DATA_CHUNKS], data_types[NUM_DATA_CHUNKS]) : '0;
      roll_ovr_flit[1] = roll_over_slot_vld[1]? pack_data(r_roll_over_data, r_roll_over_be,'d3, is_be[NUM_DATA_CHUNKS], data_types[NUM_DATA_CHUNKS]) : '0;
      roll_ovr_flit[2] = roll_over_slot_vld[2]? ((is_be[NUM_DATA_CHUNKS])? pack_data(r_roll_over_data, r_roll_over_be,'d4, is_be[NUM_DATA_CHUNKS], data_types[NUM_DATA_CHUNKS]) :
                                                   roll_ovr_flit_temp[0]) : '0;
      for (int i =3;i<FLIT_SLOT_NUM;i++)
        roll_ovr_flit[i] = roll_over_slot_vld[i]? ((is_be[NUM_DATA_CHUNKS])?roll_ovr_flit_temp[i-3]:roll_ovr_flit_temp[i-2]): '0;
        
    end
    3'h3: begin
      roll_ovr_flit[0] = roll_over_slot_vld[0]? pack_data(r_roll_over_data, r_roll_over_be,'d3, is_be[NUM_DATA_CHUNKS], data_types[NUM_DATA_CHUNKS]) : '0;
      roll_ovr_flit[1] = roll_over_slot_vld[1]? ((is_be[NUM_DATA_CHUNKS])? pack_data(r_roll_over_data, r_roll_over_be,'d4, is_be[NUM_DATA_CHUNKS], data_types[NUM_DATA_CHUNKS]) :
                                                   roll_ovr_flit_temp[0]) : '0;
      for (int i =2;i<FLIT_SLOT_NUM;i++)
        roll_ovr_flit[i] = roll_over_slot_vld[i]? ((is_be[NUM_DATA_CHUNKS])?roll_ovr_flit_temp[i-2]:roll_ovr_flit_temp[i-1]): '0;
    end
    3'h4: begin
      roll_ovr_flit[0] = pack_data(r_roll_over_data, r_roll_over_be,'d4, is_be[NUM_DATA_CHUNKS], data_types[NUM_DATA_CHUNKS]); // BE must be 1 if r_last_slot_idx ==4
      for (int i =1;i<FLIT_SLOT_NUM;i++)
        roll_ovr_flit[i] = roll_over_slot_vld[i]? roll_ovr_flit_temp[i-1] : '0;
    end  
    default: begin // r_last_slot_idx == 0
      for (int i =0;i<FLIT_SLOT_NUM;i++)
        roll_ovr_flit[i] = roll_over_slot_vld[i]? roll_ovr_flit_temp[i] : '0;
    end    
  endcase
  
  // Check How many Data Chunks (512 bits) sent in the current cycel to free the Data HDR queue
  for (int i =0;i<FLIT_SLOT_NUM;i++)
    if (roll_ovr_flit[i].data_info.data_end)
      data_hdr_num = data_hdr_num + 'd1;
  // In case Number of slots is equal to 8 the Slot packer can send a full data chunks, so  we need to incr. the read pointer by packer_data_sent
// spyglass disable_block W164a
// SMD: Identifies assignments in which the LHS width is less than the RHS width
// SJ: FIFO pointers, no overflow expected
  s_data_hdr_q_rd_ptr = r_data_hdr_q_rd_ptr + data_hdr_num;
// spyglass enable_block W164a

end


always_ff @(posedge core_clk or negedge core_rst_n) begin
  if(!core_rst_n) begin
    for (int i=0;i<DATA_HDR_Q_DEPTH;i++)
      r_data_hdr_q[i]   <= #TP 'd0;
    r_data_hdr_q_wr_ptr <= #TP 'd0;
    r_data_hdr_q_rd_ptr <= #TP 'd0;
  end
  else if(!packer_halt) begin
    for (int i=0;i<DATA_HDR_Q_DEPTH;i++)
      r_data_hdr_q[i]   <= #TP s_data_hdr_q[i];
    r_data_hdr_q_wr_ptr <= #TP s_data_hdr_q_wr_ptr;
    r_data_hdr_q_rd_ptr <= #TP s_data_hdr_q_rd_ptr;
  end
end

// -------------------------------------------------------------------------------------
// CXL.cache H2D-D2H mux
// -------------------------------------------------------------------------------------
always_comb begin
    if (s_cfg_device_mode == CXL_RC_H_M) begin
        mux_cache_req_vld_s  = h2d_cache_req_vld_s ;
        mux_cache_rsp_vld_s  = h2d_cache_rsp_vld_s ;
        mux_cache_hdr_vld_s  = h2d_cache_hdr_vld_s ;
    end
    else begin
        mux_cache_req_vld_s  = d2h_cache_req_vld_s ;
        mux_cache_rsp_vld_s  = d2h_cache_rsp_vld_s ;
        mux_cache_hdr_vld_s  = d2h_cache_hdr_vld_s ;
    end
end


// -------------------------------------------------------------------------------------
// CXL.mem M2S-S2M mux
// -------------------------------------------------------------------------------------
always_comb begin
    if (s_cfg_device_mode == CXL_RC_H_M) begin
        mux_mem_ndr_vld_s    =    m2s_mem_req_vld_s ;
        mux_mem_hdr_vld_s    =    m2s_mem_hdr_vld_s ;
        mux_mem_bi_vld_s     = m2s_mem_bi_rsp_vld_s ;
    end
    else begin
        mux_mem_ndr_vld_s    =    s2m_mem_rsp_vld_s ;
        mux_mem_hdr_vld_s    =    s2m_mem_hdr_vld_s ;
        mux_mem_bi_vld_s     = s2m_mem_bi_snp_vld_s ;
    end
end


// Empty Flit indication 
assign crd_empty =(cxl_crd_arb_256B_crd.CRD_C == 'b0) && (cxl_crd_arb_256B_crd.CRD_B == 'b0) && (cxl_crd_arb_256B_crd.CRD_A == 'b0);
always_comb begin
  s_empty_flit_flg = r_empty_flit_flg;
  for (int i = 0;i<FLIT_SLOT_NUM;i++) begin
    if (packer_flit[i].Valid || (eof && (!crd_empty)))
      s_empty_flit_flg = 1'b0;
  end
end
always_ff @(posedge core_clk or negedge core_rst_n) begin
  if(!core_rst_n) begin
    r_empty_flit_flg <= #TP 1'b1;
  end
  else if(!packer_halt) begin
    r_empty_flit_flg <= #TP (eof)? 1'b1 : s_empty_flit_flg;
  end
end
assign cxl_packer_empty_flit = (eof)? s_empty_flit_flg : 1'b0;


// -------------------------------------------------------------------------------------
// Valid signals for credit tracking
// -------------------------------------------------------------------------------------
assign b_pack.s_cxl_cache_req_valid  = mux_cache_req_vld_s;
assign b_pack.s_cxl_cache_rsp_valid  = mux_cache_rsp_vld_s;
assign b_pack.s_cxl_cache_dhdr_valid = mux_cache_hdr_vld_s;
assign b_pack.s_cxl_mem_ndr_valid    = mux_mem_ndr_vld_s;
assign b_pack.s_cxl_mem_dr_valid     = mux_mem_hdr_vld_s;
assign b_pack.s_cxl_mem_bi_valid     = mux_mem_bi_vld_s;
// Output flit
assign b_pack.s_cxl_packer_valid        = (!packer_halt);
assign b_pack.s_cxl_packer_all_data     = !sof;
assign b_pack.s_cxl_packer_last         = eof;
assign b_pack.s_cxl_packer_idle         = (packer_flit[0].Valid |  packer_flit[1].Valid | cxl_tl_pending)? 1'b0: sof;
assign b_pack.s_cxl_packer_llctrl_halt  = !sof;
assign b_pack.s_cxl_packer_flit         = packer_flit_gen(packer_flit, cxl_crd_arb_256B_crd, sof, eof, mof, s_empty_flit_flg
);


function automatic logic [(FLIT_SLOT_NUM*128)-1:0] packer_flit_gen( 
  SLOT_DESCR_256B_t packer_flit [0:FLIT_SLOT_NUM-1],
  CRD_256B_t        cxl_crd_arb_256B_crd,
  logic             sof,
  logic             eof,
  logic             mof,
  logic             empty_flit_flg

  );
  logic [(FLIT_SLOT_NUM*128)-1:0]  s_cxl_packer_flit;
  begin
    s_cxl_packer_flit = 'b0;
    for (int i=0;i<FLIT_SLOT_NUM;i++) begin
      if(i==0 & sof) begin
        s_cxl_packer_flit[i*128 +: 128] = {packer_flit[i].Slot[0 +: 108], packer_flit[i].slot_idx, 16'h0080};
      end
      else begin
        s_cxl_packer_flit[i*128 +: 128] = (packer_flit[i].slot_type==CXL_256B_SLOT_DATA)? packer_flit[i].Slot: {packer_flit[i].Slot[0 +: 124], packer_flit[i].slot_idx};
      end
    end
    // 2B of CRD
    if (eof) begin 
      s_cxl_packer_flit[(FLIT_SLOT_NUM-1)*128 +: 2*8]        = {cxl_crd_arb_256B_crd.RSVD, cxl_crd_arb_256B_crd.CRD_C, 
                                                              cxl_crd_arb_256B_crd.CRD_B, ( (empty_flit_flg)? 5'h1 :  cxl_crd_arb_256B_crd.CRD_A)};
    end
    return s_cxl_packer_flit;
  end
endfunction

endmodule
