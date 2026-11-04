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
// ---   $DateTime: 2023/12/22 07:15:34 $
// ---   $Revision: #12 $
// ---   $Id: //dwh/pcie_iip/main/fairbanks/design/CXL/DWC_cxl_mem_cache_rx_tl.sv#12 $
// -------------------------------------------------------------------------
// --- Module Description:
// ----------------------------------------------------------------------------
// CXL Transaction Layer Reciever Top Module 
// DWC_cxl_mst_link_ctrl - Manages the link control for corresponding channels - Low power FSM state 
// 
// Error Injection Mapping for the case of 68B flit (for 256B flit it is the
// same order but the sizes differ corresponding to numbers of channels in 256B)
// ras_err_inj_en[ 1: 0] - s_hreq_drsp_ram[1-0]_wr_addr        (core_clk)
// ras_err_inj_en[ 5: 2] - s_hreq_drsp_ram[3-0]_wr_addr        (core_clk)
// ras_err_inj_en[    6] - s_hd_data_ram_wr_addr               (core_clk)
// ras_err_inj_en[ 8: 7] - s_hreq_drsp_ram[1-0]_rd_addr        (core_clk)
// ras_err_inj_en[12: 9] - s_hreq_drsp_ram[3-0]_rd_addr        (core_clk)
// ras_err_inj_en[   13] - s_hd_data_ram_rd_addr               (core_clk)
// ras_err_inj_en[15:14] - s_ms_ndr_ram[1-0]_wr_addr           (core_clk)
// ras_err_inj_en[   16] - s_ms_data_ram_wr_addr               (core_clk)
// ras_err_inj_en[18:17] - s_ms_ndr_ram[1-0]_rd_addr           (core_clk)
// ras_err_inj_en[   19] - s_ms_data_ram_rd_addr               (core_clk)
// ras_err_inj_en[21:20] - s_ms_bi_ram[1-0]_wr_addr            (core_clk)
// ras_err_inj_en[23:22] - s_ms_bi_ram[1-0]_wr_addr            (core_clk)
// ----------------------------------------------------------------------------

`include "include/DWC_pcie_ctl_all_defs.svh"
`include "CXL/pkg/DWC_cxl_pkg.svh"

`include "CXL/svif/DWC_cxl_clk_rst_if.svh"
`include "CXL/svif/DWC_cxl_ram2p_if.svh"

module DWC_cxl_mem_cache_rx_tl
  import DWC_cxl_pkg::*;
#(
    parameter TP = `TP
) 
                                (
    DWC_cxl_clk_rst_if.slave_mp                             b_clk                ,                  
    DWC_cxl_rxtl_llctrl_if.rxtl_integrated_rasdp_mp         b_rxtl_llctrl        ,
    input                                                   cxl_rx_link_disable  , // RX Link Disable Request - flush RX Buffers
    input                                                   cxl_rx_active_req    , // RX Activation Request
    output                                                  cxl_rx_active_sts    , // RX Activation Status
    input                                                   cxl_device_mode      , // 0 - Endpoint; 1 - Root Complex Device
    input                                                   cxl_rx_dl_idle       , // CXL RX Data Link Layer Idle
    output logic                                            cxl_rx_tl_pending      // Indicates pending transactions in the Receive Buffers
    , output logic [(CX_CXL_RX_TL_VALID_ERR_WD-1):0]        cxl_rx_dltl_ras_valid_err
  , output logic [7:0]                                      cxl_rx_fifo_ovflw                // RAS - CLX Receiver FIFO Overflow
  , output logic [(CX_CXL_RX_TL_PTR_ERR_WD-1):0]            cxl_rx_tl_fifo_data_out_ptr_err  // RAS - CXL Receiver FIFO Pointer Error

  , DWC_cxl_app_ch_init_if.master_mp                        b_app_cache_init
  , DWC_cxl_app_ch_init_if.master_mp                        b_app_mem_init
  , DWC_cxl_app_ch_if.master_device_mp                      b_app_dev_chi           // Application Host Channel Interface
  , DWC_cxl_app_ch_if.master_host_mp                        b_app_host_chi          // Application Device Channel Interface

  ,
    output logic [CACHE_REQ_VALID_WD-1:0]                   cxl_rx_tl_cache_req_valid       ,
    output logic [CACHE_RSP_VALID_WD-1:0]                   cxl_rx_tl_cache_rsp_valid       ,
    output logic [HD_DDATA_NUM-1:0]                         cxl_rx_tl_cache_data_valid      , 
    DWC_cxl_ram2p_if.master_mp                              b_cxl_mst_hreq_drsp_ram [0:HREQ_DRSP_NUM-1] ,
    DWC_cxl_ram2p_if.master_mp                              b_cxl_mst_hrsp_dreq_ram [0:HRSP_DREQ_NUM-1] ,
    DWC_cxl_ram2p_if.master_mp                              b_cxl_mst_hd_data_ram [0:HD_DDATA_NUM-1] 
    ,
    input                                                   cxl_dltl_h2d_crc_err            //RX Data Link layer CRC Error signal - Needed for delayed msg invalidation - timing optimization

    ,
    input                                                   cxl_dltl_d2h_crc_err            //RX Data Link layer CRC Error signal - Needed for delayed msg invalidation - timing optimization 
    ,
    output logic [(MEM_NDR_VALID_WD-1)  : 0]                cxl_rx_tl_mem_ndr_valid         , // RX Credits - CXL.mem Request/Response valid
    output logic  [MS_SM_DDATA_NUM - 1: 0]                  cxl_rx_tl_mem_data_valid        , // RX Credits - CXL.mem Data valid
    output logic [(MEM_BI_VALID_WD-1)  : 0]                 cxl_rx_tl_mem_bi_valid          , // RX Credits - CXL.mem BI Snoop/Response valid

    DWC_cxl_ram2p_if.master_mp                              b_cxl_mst_ms_ndr_ram [0:MS_SM_NDR_NUM-1 ] ,
    DWC_cxl_ram2p_if.master_mp                              b_cxl_mst_ms_data_ram [0:MS_SM_DDATA_NUM-1 ]
    ,
    input                                                   cxl_dltl_m2s_crc_err            //RX Data Link layer CRC Error signal - Needed for delayed msg invalidation - timing optimization 
    
    ,
    input                                                   cxl_dltl_s2m_crc_err            //RX Data Link layer CRC Error signal - Needed for delayed msg invalidation - timing optimization 
    ,DWC_cxl_ram2p_if.master_mp                             b_cxl_mst_mrsp_ssnp_bi_ram [0:MS_BI_NUM-1]
);
  //  Variable for generate loop index
  genvar g_lp_idx;

  //  Define a macro to concatenate the check bits with the signal.
  //  The use of a macro for variable sized inputs and outputs seems easier
  //  than the use of variable sized functions/tasks.
  //
  //  For the case of DATACHK_EN, the macro actually concatenates.
  //  For no DATACHK_EN, the macro just copies the (unpacked) input
  //  into the packed result.
  //  If both were packed arrays it would have been easier to say result=value;
  //
  //  Within the definition of the macro, we use the double-tick (``) to form
  //  the names of the signals by appending the passed variable name to the
  //  text given inside the macro.
  `define CONCAT_CHK(NUM, VAL, val, HOSTDEV)                            \
  logic [(NUM-1):0][(VAL``_RX_CH_SIZE-1):0] cxl_mst_``val;              \
    for (g_lp_idx=0; g_lp_idx<NUM; g_lp_idx=g_lp_idx+1) begin           \
      assign {                                                          \
          b_app_``HOSTDEV``_chi.s_cxl_``val``_chk[g_lp_idx][(VAL``_CHK_SIZE-1):0] \
        ,                                                               \
          b_app_``HOSTDEV``_chi.s_cxl_``val[g_lp_idx][(VAL``_SIZE-1):0] \
      } = cxl_mst_``val[g_lp_idx][(VAL``_RX_CH_SIZE-1):0];              \
    end                       // End of macro definition
  `CONCAT_CHK(H2D_REQ_IFNUM, H2D_REQ, h2d_req, host)
  `CONCAT_CHK(H2D_RESP_IFNUM, H2D_RESP, h2d_resp, host)
  `CONCAT_CHK(H2D_DATA_IFNUM, H2D_DATA, h2d_data, host)

  `CONCAT_CHK(D2H_REQ_IFNUM, D2H_REQ, d2h_req, dev)
  `CONCAT_CHK(D2H_RESP_IFNUM, D2H_RESP, d2h_resp, dev)
  `CONCAT_CHK(D2H_DATA_IFNUM, D2H_DATA, d2h_data, dev)

  `CONCAT_CHK(M2S_NDR_IFNUM, M2S_NDR, m2s_req, host)
  `CONCAT_CHK(M2S_DATA_IFNUM, M2S_DATA, m2s_rwd, host)
  `CONCAT_CHK(M2S_BI_RSP_IFNUM, M2S_BI_RSP, m2s_bi_rsp, host)

  `CONCAT_CHK(S2M_NDR_IFNUM, S2M_NDR, s2m_ndr, dev)
  `CONCAT_CHK(S2M_DATA_IFNUM, S2M_DATA, s2m_drc, dev)
  `CONCAT_CHK(S2M_BI_SNP_IFNUM, S2M_BI_SNP, s2m_bi_snp, dev)


/////////////////////////////////////////////////////
// --------------------------------------------------
// common logic 
// --------------------------------------------------
logic pos_core_clk;
assign pos_core_clk = 1'b1;
assign toggle_flag_cxl_clk  = pos_core_clk; 

logic cxl_rx_link_idle_r;       // RX Link Deinitialization Acknowledge
logic cxl_rx_link_idle_s;
logic cxl_rx_link_disable_r;
logic cxl_rx_active_req_r;
logic cxl_rx_active_sts_r, cxl_rx_active_sts_nxt;

always_ff @(posedge b_clk.s_cxl_clk or negedge b_clk.s_cxl_rst_n) begin 
  if (!b_clk.s_cxl_rst_n) begin
   cxl_rx_link_disable_r <= # TP 1'b0;
   cxl_rx_active_req_r   <= # TP 1'b0;
  end else begin
   cxl_rx_link_disable_r <= # TP cxl_rx_link_disable ;
   cxl_rx_active_req_r   <= # TP cxl_rx_active_req   ;
  end
end

assign cxl_rx_active_sts = cxl_rx_active_sts_r;

always_comb begin
    // If RX Activation request is asserted then wait for interface to be initialized to reflect active status back
    if (cxl_rx_active_req_r && !cxl_rx_active_sts_r && b_app_cache_init.s_cxl_init_ack
   && b_app_mem_init.s_cxl_init_ack)
        cxl_rx_active_sts_nxt = 1'b1;
    // If RX Activation request is de-asserted then wait for RX transaction layer to indicate IDLE before reflecting the status back
    else if (!cxl_rx_active_req_r && cxl_rx_active_sts_r && cxl_rx_link_idle_r)
        cxl_rx_active_sts_nxt = 1'b0;
    else
        cxl_rx_active_sts_nxt = cxl_rx_active_sts_r;
end

always_ff @(posedge b_clk.s_core_clk or negedge b_clk.s_core_rst_n) begin 
  if (!b_clk.s_core_rst_n) begin
   cxl_rx_active_sts_r   <= # TP 1'b0;
   cxl_rx_link_idle_r    <= # TP 1'b0;
  end else begin
   cxl_rx_active_sts_r   <= # TP cxl_rx_active_sts_nxt;
   cxl_rx_link_idle_r    <= # TP cxl_rx_link_idle_s;
  end
end

// Disable cxl_rx_dl_idle when vLSM flushes the controller on entry to the RESET state
logic cxl_rx_dl_idle_s;
assign cxl_rx_dl_idle_s = cxl_rx_link_disable_r ? 1'b1 : cxl_rx_dl_idle;

///////////////////////// TL Interface ///////////////////////////////
//Interface with RX DATA Link Layer - synchronous to s_core_clk
//H2D Request(2), Response(4), Data Header(4), Data(1) Message signals
logic [(H2D_DDATA_NUM-1):0]             cxl_dltl_h2d_data_valid        ;
logic [(H2D_DDATA_NUM-1):0]             cxl_rasdp_h2d_data_valid_inv   ;   

//D2H Request(4), Response(2), Data Header(4), Data Byte en(1), Data(1) Message signals
logic [(D2H_DDATA_NUM-1):0]                 cxl_dltl_d2h_data_valid         ;
logic [(D2H_DDATA_NUM-1):0]                 cxl_dltl_d2h_byte_en_valid      ;
logic [(D2H_DDATA_NUM-1):0]                    cxl_rasdp_d2h_data_valid_inv    ; 
logic [(D2H_DDATA_NUM-1):0]                    cxl_rasdp_d2h_byte_en_valid_inv ;  
  
//M2S NDR(2), Data Header(1), Data(1), Data Byte en(1) Message signals
logic [M2S_DDATA_NUM-1:0]                      cxl_dltl_m2s_data_valid         ;
logic [M2S_DDATA_NUM-1:0]                      cxl_dltl_m2s_byte_en_valid      ;
logic [M2S_DDATA_NUM-1:0]                      cxl_rasdp_m2s_data_valid_inv    ;  
logic [M2S_DDATA_NUM-1:0]                      cxl_rasdp_m2s_byte_en_valid_inv ;  

//S2M NDR(3), Data Header(3), Data(1), Message signals
logic [(S2M_DDATA_NUM-1):0]                     cxl_dltl_s2m_data_valid         ;
logic [(S2M_DDATA_NUM-1):0]                    cxl_rasdp_s2m_data_valid_inv    ;   
  
  

assign cxl_dltl_h2d_data_valid         = b_rxtl_llctrl.s_cxl_h2d_data_valid        ;
assign cxl_rasdp_h2d_data_valid_inv    = b_rxtl_llctrl.s_cxl_h2d_data_valid_chk    ;   

assign cxl_dltl_d2h_data_valid         = b_rxtl_llctrl.s_cxl_d2h_data_valid       ;
assign cxl_dltl_d2h_byte_en_valid      = b_rxtl_llctrl.s_cxl_d2h_byte_en_valid     ;
assign cxl_rasdp_d2h_data_valid_inv    = b_rxtl_llctrl.s_cxl_d2h_data_valid_chk    ;    
assign cxl_rasdp_d2h_byte_en_valid_inv = b_rxtl_llctrl.s_cxl_d2h_byte_en_valid_chk ;  
  
assign cxl_dltl_m2s_data_valid         = b_rxtl_llctrl.s_cxl_m2s_data_valid       ;
assign cxl_dltl_m2s_byte_en_valid      = b_rxtl_llctrl.s_cxl_m2s_byte_en_valid     ;
assign cxl_rasdp_m2s_data_valid_inv    = b_rxtl_llctrl.s_cxl_m2s_data_valid_chk    ;    
assign cxl_rasdp_m2s_byte_en_valid_inv = b_rxtl_llctrl.s_cxl_m2s_byte_en_valid_chk ;  

assign cxl_dltl_s2m_data_valid         = b_rxtl_llctrl.s_cxl_s2m_data_valid        ;
assign cxl_rasdp_s2m_data_valid_inv    = b_rxtl_llctrl.s_cxl_s2m_data_valid_chk   ;   
  
  


/////////////////////////// Cache ////////////////////////////////////
logic           s_cxl_rx_tl_cache_pending       ;
logic           cxl_rx_tl_cache_pending         ;
logic           cxl_rx_tl_cache_ch_msg_halt     ;
logic           cxl_rx_tl_cache_nullify_crd     ;
logic           cxl_rx_tl_cache_run_crd_cnt     ;
logic           cxl_rx_link_cache_idle          ;
/////////////////////////////////////////////////////
// Cache Link Control FSM
/////////////////////////////////////////////////////
DWC_cxl_mst_link_ctrl
 U_DWC_cxl_rx_tl_cache_link_ctrl(
                              .clk                 (b_clk.s_cxl_clk             ) 
                             ,.rst_n               (b_clk.s_cxl_rst_n           )
                             ,.cxl_mst_req         (b_app_cache_init.s_cxl_init_req) 
                             ,.cxl_mst_ack         (b_app_cache_init.s_cxl_init_ack) 
                             ,.cxl_rx_active_req   (cxl_rx_active_req_r         )
                             ,.cxl_rx_dl_idle      (cxl_rx_dl_idle_s            )
                             ,.cxl_rx_tl_pending   (cxl_rx_tl_cache_pending     ) 
                             ,.cxl_rx_link_idle    (cxl_rx_link_cache_idle      )
                             ,.ch_msg_halt         (cxl_rx_tl_cache_ch_msg_halt )
                             ,.nullify_crd         (cxl_rx_tl_cache_nullify_crd ) 
                             ,.run_crd_cnt         (cxl_rx_tl_cache_run_crd_cnt ));
always_ff @(posedge b_clk.s_core_clk or negedge b_clk.s_core_rst_n) begin  
  if (!b_clk.s_core_rst_n) begin
  cxl_rx_tl_cache_pending     <= 1'h0;
  end else begin
  cxl_rx_tl_cache_pending     <= s_cxl_rx_tl_cache_pending;
  end 
end
/////////////////////////// Cache,EP - H2D ///////////////////////////
logic                                            cxl_mst_rx_tl_h2d_req_ovflw    ; 
logic                                            cxl_mst_rx_tl_h2d_rsp_ovflw    ; 
logic                                            cxl_mst_rx_tl_h2d_data_ovflw   ; 
logic                                            cxl_rx_tl_cache_h2d_pending    ;
logic                                            cxl_rx_tl_cache_h2d_ch_msg_halt;
logic                                            cxl_rx_tl_cache_h2d_nullify_crd;
logic                                            cxl_rx_tl_cache_h2d_run_crd_cnt;
logic [H2D_REQ_NUM-1:0]                          cxl_rx_tl_cache_h2d_req_valid  ;
logic [H2D_RESP_NUM-1:0]                         cxl_rx_tl_cache_h2d_rsp_valid  ;
logic [H2D_DDATA_NUM-1:0]                        cxl_rx_tl_cache_h2d_data_valid ;

  DWC_cxl_ram2p_if #(
      .ADDR_WIDTH(HREQ_DRSP_RX_RAM_ADDRW)
    , .DATA_WIDTH(H2D_REQ_RAM_DATAW))            b_h2d_req_ram[(HREQ_DRSP_NUM-1):0]();
  DWC_cxl_ram2p_if #(
      .ADDR_WIDTH(HRSP_DREQ_RX_RAM_ADDRW)
    , .DATA_WIDTH(H2D_RSP_RAM_DATAW))            b_h2d_resp_ram[(HRSP_DREQ_NUM-1):0]();
  DWC_cxl_ram2p_if #(
      .ADDR_WIDTH(H2D_DATA_RAM_ADDRW)
    , .DATA_WIDTH(H2D_DATA_RAM_DATAW))           b_h2d_data_ram[(H2D_DDATA_NUM-1):0]();
logic                                            cxl_mst_h2d_req_fifo_data_out_ptr_err   ;

assign cxl_rx_tl_cache_h2d_ch_msg_halt  = cxl_rx_tl_cache_ch_msg_halt       ;
assign cxl_rx_tl_cache_h2d_nullify_crd  = cxl_rx_tl_cache_nullify_crd       ;
assign cxl_rx_tl_cache_h2d_run_crd_cnt  = cxl_rx_tl_cache_run_crd_cnt       ;

  //  Make a packed array out of the unpacked interface array so that it
  //  becomes compatible with the port of the module.
  logic [(H2D_REQ_IFNUM-1):0]     cxl_mst_h2d_req_crd;
  logic [(H2D_RESP_IFNUM-1):0]    cxl_mst_h2d_resp_crd;
  logic [(H2D_DATA_IFNUM-1):0]    cxl_mst_h2d_data_crd;
  generate
    for (g_lp_idx=0; g_lp_idx<H2D_REQ_IFNUM; g_lp_idx=g_lp_idx+1) begin
      assign cxl_mst_h2d_req_crd[g_lp_idx]   =  b_app_host_chi.s_cxl_h2d_req_crd[g_lp_idx]; 
    end
  endgenerate
  generate
    for (g_lp_idx=0; g_lp_idx<H2D_RESP_IFNUM; g_lp_idx=g_lp_idx+1) begin
      assign cxl_mst_h2d_resp_crd[g_lp_idx]  =  b_app_host_chi.s_cxl_h2d_resp_crd[g_lp_idx]; 
    end
  endgenerate
  generate
    for (g_lp_idx=0; g_lp_idx<H2D_DATA_IFNUM; g_lp_idx=g_lp_idx+1) begin
      assign cxl_mst_h2d_data_crd[g_lp_idx]  =  b_app_host_chi.s_cxl_h2d_data_crd[g_lp_idx]; 
    end
  endgenerate

DWC_cxl_cache_h2d_rx_tl
 U_DWC_cxl_cache_h2d_rx_tl (
                             .b_clk                             (b_clk                          ) 
                            ,.toggle_flag_cxl_clk               (toggle_flag_cxl_clk            )
                            ,.cxl_rx_vlsm_req_flush             (cxl_rx_link_disable_r          )
                            ,.cxl_rx_tl_cache_h2d_pending       (cxl_rx_tl_cache_h2d_pending    )
                            ,.cxl_mst_rx_tl_h2d_req_ovflw       (cxl_mst_rx_tl_h2d_req_ovflw    ) 
                            ,.cxl_mst_rx_tl_h2d_rsp_ovflw       (cxl_mst_rx_tl_h2d_rsp_ovflw    ) 
                            ,.cxl_mst_rx_tl_h2d_data_ovflw      (cxl_mst_rx_tl_h2d_data_ovflw   ) 
                            ,.cxl_rx_tl_cache_h2d_ch_msg_halt   (cxl_rx_tl_cache_h2d_ch_msg_halt)
                            ,.cxl_rx_tl_cache_h2d_nullify_crd   (cxl_rx_tl_cache_h2d_nullify_crd)
                            ,.cxl_rx_tl_cache_h2d_run_crd_cnt   (cxl_rx_tl_cache_h2d_run_crd_cnt)
                            ,.cxl_rx_tl_cache_h2d_req_valid     (cxl_rx_tl_cache_h2d_req_valid  )
                            ,.cxl_rx_tl_cache_h2d_rsp_valid     (cxl_rx_tl_cache_h2d_rsp_valid  )
                            ,.cxl_rx_tl_cache_h2d_data_valid    (cxl_rx_tl_cache_h2d_data_valid )
                            ,.cxl_mst_h2d_req                   (cxl_mst_h2d_req) 
                            ,.cxl_mst_h2d_resp                  (cxl_mst_h2d_resp) 
                            ,.cxl_mst_h2d_data                  (cxl_mst_h2d_data) 
                            ,.cxl_mst_h2d_req_crd               (cxl_mst_h2d_req_crd) 
                            ,.cxl_mst_h2d_resp_crd              (cxl_mst_h2d_resp_crd) 
                            ,.cxl_mst_h2d_data_crd              (cxl_mst_h2d_data_crd) 
                            ,.cxl_dltl_h2d_crc_err              (cxl_dltl_h2d_crc_err           )
                            ,.cxl_ch_dltl_h2d_req               (b_rxtl_llctrl.cxl_ch_dltl_h2d_req) 
                            ,.cxl_ch_dltl_h2d_resp              (b_rxtl_llctrl.cxl_ch_dltl_h2d_resp) 
                            ,.cxl_ch_dltl_h2d_dhr               (b_rxtl_llctrl.cxl_ch_dltl_h2d_dhr) 
                            ,.cxl_dltl_h2d_data                 (b_rxtl_llctrl.cxl_ch_dltl_h2d_data) 
                            ,.cxl_dltl_h2d_data_valid           (cxl_dltl_h2d_data_valid) 
                            ,.cxl_mst_h2d_req_fifo_data_out_ptr_err(cxl_mst_h2d_req_fifo_data_out_ptr_err)
                            ,.b_h2d_req_ram                     (b_h2d_req_ram.master_mp)
                            ,.b_h2d_resp_ram                    (b_h2d_resp_ram.master_mp)
                            ,.b_h2d_data_ram                    (b_h2d_data_ram.master_mp)
                        );
logic                                            cxl_mst_rx_tl_d2h_req_ovflw    ; 
logic                                            cxl_mst_rx_tl_d2h_rsp_ovflw    ; 
logic                                            cxl_mst_rx_tl_d2h_data_ovflw   ; 
logic                                            cxl_rx_tl_cache_d2h_pending    ;
logic                                            cxl_rx_tl_cache_d2h_ch_msg_halt;
logic                                            cxl_rx_tl_cache_d2h_nullify_crd;
logic                                            cxl_rx_tl_cache_d2h_run_crd_cnt;
logic [D2H_REQ_NUM-1:0]                          cxl_rx_tl_cache_d2h_req_valid  ;
logic [D2H_RESP_NUM-1:0]                         cxl_rx_tl_cache_d2h_rsp_valid  ;
logic [D2H_DDATA_NUM-1:0]                        cxl_rx_tl_cache_d2h_data_valid ;

  DWC_cxl_ram2p_if #(
      .ADDR_WIDTH(HRSP_DREQ_RX_RAM_ADDRW)
    , .DATA_WIDTH(D2H_REQ_RAM_DATAW))            b_d2h_req_ram[(HRSP_DREQ_NUM-1):0]();
  DWC_cxl_ram2p_if #(
      .ADDR_WIDTH(HREQ_DRSP_RX_RAM_ADDRW)
    , .DATA_WIDTH(D2H_RSP_RAM_DATAW))            b_d2h_resp_ram[(HREQ_DRSP_NUM-1):0]();
  DWC_cxl_ram2p_if #(
      .ADDR_WIDTH(D2H_DATA_RAM_ADDRW)
    , .DATA_WIDTH(D2H_DATA_RAM_DATAW))           b_d2h_data_ram[(D2H_DDATA_NUM-1):0]();

assign cxl_rx_tl_cache_d2h_ch_msg_halt  = cxl_rx_tl_cache_ch_msg_halt       ;
assign cxl_rx_tl_cache_d2h_nullify_crd  = cxl_rx_tl_cache_nullify_crd       ;
assign cxl_rx_tl_cache_d2h_run_crd_cnt  = cxl_rx_tl_cache_run_crd_cnt       ;

  //  Make a packed array out of the unpacked interface array so that it
  //  becomes compatible with the port of the module.
  logic [(D2H_REQ_IFNUM-1):0]     cxl_mst_d2h_req_crd;
  logic [(D2H_RESP_IFNUM-1):0]    cxl_mst_d2h_resp_crd;
  logic [(D2H_DATA_IFNUM-1):0]    cxl_mst_d2h_data_crd;
  generate
    for (g_lp_idx=0; g_lp_idx<D2H_REQ_IFNUM; g_lp_idx=g_lp_idx+1) begin
      assign cxl_mst_d2h_req_crd[g_lp_idx]   =  b_app_dev_chi.s_cxl_d2h_req_crd[g_lp_idx]; 
    end
  endgenerate
  generate
    for (g_lp_idx=0; g_lp_idx<D2H_RESP_IFNUM; g_lp_idx=g_lp_idx+1) begin
      assign cxl_mst_d2h_resp_crd[g_lp_idx]  =  b_app_dev_chi.s_cxl_d2h_resp_crd[g_lp_idx]; 
    end
  endgenerate
  generate
    for (g_lp_idx=0; g_lp_idx<D2H_DATA_IFNUM; g_lp_idx=g_lp_idx+1) begin
      assign cxl_mst_d2h_data_crd[g_lp_idx]  =  b_app_dev_chi.s_cxl_d2h_data_crd[g_lp_idx]; 
    end
  endgenerate


DWC_cxl_cache_d2h_rx_tl
 U_DWC_cxl_cache_d2h_rx_tl (
                             .b_clk                             (b_clk                          ) 
                            ,.toggle_flag_cxl_clk               (toggle_flag_cxl_clk            )
                            ,.cxl_rx_vlsm_req_flush             (cxl_rx_link_disable_r          )
                            ,.cxl_rx_tl_cache_d2h_pending       (cxl_rx_tl_cache_d2h_pending    )
                            ,.cxl_mst_rx_tl_d2h_req_ovflw       (cxl_mst_rx_tl_d2h_req_ovflw    ) 
                            ,.cxl_mst_rx_tl_d2h_rsp_ovflw       (cxl_mst_rx_tl_d2h_rsp_ovflw    ) 
                            ,.cxl_mst_rx_tl_d2h_data_ovflw      (cxl_mst_rx_tl_d2h_data_ovflw   ) 
                            ,.cxl_rx_tl_cache_d2h_ch_msg_halt   (cxl_rx_tl_cache_d2h_ch_msg_halt)
                            ,.cxl_rx_tl_cache_d2h_nullify_crd   (cxl_rx_tl_cache_d2h_nullify_crd)
                            ,.cxl_rx_tl_cache_d2h_run_crd_cnt   (cxl_rx_tl_cache_d2h_run_crd_cnt)
                            ,.cxl_rx_tl_cache_d2h_req_valid     (cxl_rx_tl_cache_d2h_req_valid  )
                            ,.cxl_rx_tl_cache_d2h_rsp_valid     (cxl_rx_tl_cache_d2h_rsp_valid  )
                            ,.cxl_rx_tl_cache_d2h_data_valid    (cxl_rx_tl_cache_d2h_data_valid )
                            ,.cxl_mst_d2h_req                   (cxl_mst_d2h_req)
                            ,.cxl_mst_d2h_resp                  (cxl_mst_d2h_resp)
                            ,.cxl_mst_d2h_data                  (cxl_mst_d2h_data)
                            ,.cxl_mst_d2h_req_crd               (cxl_mst_d2h_req_crd)
                            ,.cxl_mst_d2h_resp_crd              (cxl_mst_d2h_resp_crd)
                            ,.cxl_mst_d2h_data_crd              (cxl_mst_d2h_data_crd)
                            ,.cxl_dltl_d2h_crc_err              (cxl_dltl_d2h_crc_err           )
                            ,.cxl_ch_dltl_d2h_req               (b_rxtl_llctrl.cxl_ch_dltl_d2h_req)
                            ,.cxl_ch_dltl_d2h_resp              (b_rxtl_llctrl.cxl_ch_dltl_d2h_resp)
                            ,.cxl_ch_dltl_d2h_dhr               (b_rxtl_llctrl.cxl_ch_dltl_d2h_dhr)
                            ,.cxl_dltl_d2h_data                 (b_rxtl_llctrl.cxl_ch_dltl_d2h_data)
                            ,.cxl_dltl_d2h_byte_en              (b_rxtl_llctrl.cxl_ch_dltl_d2h_byte_en)
                            ,.cxl_dltl_d2h_data_valid           (cxl_dltl_d2h_data_valid        )
                            ,.cxl_dltl_d2h_byte_en_valid        (cxl_dltl_d2h_byte_en_valid     )
                            ,.b_d2h_req_ram                     (b_d2h_req_ram.master_mp)
                            ,.b_d2h_resp_ram                    (b_d2h_resp_ram.master_mp)
                            ,.b_d2h_data_ram                    (b_d2h_data_ram.master_mp)
                            );

logic [(HREQ_DRSP_NUM-1):0][(HREQ_DRSP_RX_RAM_ADDRW-1) : 0] s_hreq_drsp_ram_wr_addr;
logic [(HRSP_DREQ_NUM-1):0][(HRSP_DREQ_RX_RAM_ADDRW-1) : 0] s_hrsp_dreq_ram_wr_addr;
logic [(HD_DDATA_NUM-1) :0][(HD_DATA_RX_RAM_ADDRW-1)   : 0] s_hd_data_ram_wr_addr  ;

logic [(HREQ_DRSP_NUM-1):0][(HREQ_DRSP_RX_RAM_ADDRW-1) : 0] s_hreq_drsp_ram_rd_addr;
logic [(HRSP_DREQ_NUM-1):0][(HRSP_DREQ_RX_RAM_ADDRW-1) : 0] s_hrsp_dreq_ram_rd_addr;
logic [(HD_DDATA_NUM-1) :0][(HD_DATA_RX_RAM_ADDRW-1)   : 0] s_hd_data_ram_rd_addr  ;

  //  Generate the signals for the Host-Request-Device-Response Ram interfaces
  generate
    for (g_lp_idx=0; g_lp_idx<HREQ_DRSP_NUM; g_lp_idx=g_lp_idx+1) begin
      always_comb begin
        //  Start by initializing all the signals to a default '0 value.
        //  Then, based on the mode being D2H or H2D,
        //  assign to the appropriate number of signals the corresponding value.
        b_cxl_mst_hreq_drsp_ram[g_lp_idx].s_ram_we    = '0;
        b_cxl_mst_hreq_drsp_ram[g_lp_idx].s_ram_rd    = '0;
        s_hreq_drsp_ram_wr_addr[g_lp_idx]             = '0;
        s_hreq_drsp_ram_rd_addr[g_lp_idx]             = '0;
        b_cxl_mst_hreq_drsp_ram[g_lp_idx].s_ram_wdata = '0;
          b_cxl_mst_hreq_drsp_ram[g_lp_idx].s_ram_we    |=  b_d2h_resp_ram[g_lp_idx].s_ram_we;
          b_cxl_mst_hreq_drsp_ram[g_lp_idx].s_ram_rd    |=  b_d2h_resp_ram[g_lp_idx].s_ram_rd;
          s_hreq_drsp_ram_wr_addr[g_lp_idx]             |=  b_d2h_resp_ram[g_lp_idx].s_ram_wr_addr;
          s_hreq_drsp_ram_rd_addr[g_lp_idx]             |=  b_d2h_resp_ram[g_lp_idx].s_ram_rd_addr;
          b_cxl_mst_hreq_drsp_ram[g_lp_idx].s_ram_wdata |=  (!cxl_device_mode) ?  '0:
                                                      {{(HREQ_DRSP_RX_RAM_DATAW-D2H_RSP_RAM_DATAW){1'b0}}
                                                                      , b_d2h_resp_ram[g_lp_idx].s_ram_wdata};
          b_d2h_resp_ram[g_lp_idx].s_ram_rdata           =  (!cxl_device_mode) ?  '0:
                                                     b_cxl_mst_hreq_drsp_ram[g_lp_idx].s_ram_rdata[D2H_RSP_RAM_DATAW-1:0];
          b_cxl_mst_hreq_drsp_ram[g_lp_idx].s_ram_we    |=  b_h2d_req_ram[g_lp_idx].s_ram_we;
          b_cxl_mst_hreq_drsp_ram[g_lp_idx].s_ram_rd    |=  b_h2d_req_ram[g_lp_idx].s_ram_rd;
          s_hreq_drsp_ram_wr_addr[g_lp_idx]             |=  b_h2d_req_ram[g_lp_idx].s_ram_wr_addr;
          s_hreq_drsp_ram_rd_addr[g_lp_idx]             |=  b_h2d_req_ram[g_lp_idx].s_ram_rd_addr;
          b_cxl_mst_hreq_drsp_ram[g_lp_idx].s_ram_wdata |=  (cxl_device_mode) ?  '0:
                                                      {{(HREQ_DRSP_RX_RAM_DATAW-H2D_REQ_RAM_DATAW){1'b0}}
                                                                      , b_h2d_req_ram[g_lp_idx].s_ram_wdata};
          b_h2d_req_ram[g_lp_idx].s_ram_rdata            =  (cxl_device_mode) ?  '0:
                                                     b_cxl_mst_hreq_drsp_ram[g_lp_idx].s_ram_rdata[H2D_REQ_RAM_DATAW-1:0];
      end
    end
  endgenerate

  //  Generate the signals for the Host-Response-Device-Request Ram interfaces
  generate
    for (g_lp_idx=0; g_lp_idx<HRSP_DREQ_NUM; g_lp_idx=g_lp_idx+1) begin
      always_comb begin
        //  Start by initializing all the signals to a default '0 value.
        //  Then, based on the mode being D2H or H2D,
        //  assign to the appropriate number of signals the corresponding value.
        b_cxl_mst_hrsp_dreq_ram[g_lp_idx].s_ram_we    = '0;
        b_cxl_mst_hrsp_dreq_ram[g_lp_idx].s_ram_rd    = '0;
        s_hrsp_dreq_ram_wr_addr[g_lp_idx]             = '0;
        s_hrsp_dreq_ram_rd_addr[g_lp_idx]             = '0;
        b_cxl_mst_hrsp_dreq_ram[g_lp_idx].s_ram_wdata = '0;
          b_cxl_mst_hrsp_dreq_ram[g_lp_idx].s_ram_we    |=  b_d2h_req_ram[g_lp_idx].s_ram_we;
          b_cxl_mst_hrsp_dreq_ram[g_lp_idx].s_ram_rd    |=  b_d2h_req_ram[g_lp_idx].s_ram_rd;
          s_hrsp_dreq_ram_wr_addr[g_lp_idx]             |=  b_d2h_req_ram[g_lp_idx].s_ram_wr_addr;
          s_hrsp_dreq_ram_rd_addr[g_lp_idx]             |=  b_d2h_req_ram[g_lp_idx].s_ram_rd_addr;
          b_cxl_mst_hrsp_dreq_ram[g_lp_idx].s_ram_wdata |=  (!cxl_device_mode) ?  '0:
                                                      {{(HRSP_DREQ_RX_RAM_DATAW-D2H_REQ_RAM_DATAW){1'b0}}
                                                                      , b_d2h_req_ram[g_lp_idx].s_ram_wdata};
          b_d2h_req_ram[g_lp_idx].s_ram_rdata            =  (!cxl_device_mode) ?  '0:
                                                     b_cxl_mst_hrsp_dreq_ram[g_lp_idx].s_ram_rdata[D2H_REQ_RAM_DATAW-1:0];
          b_cxl_mst_hrsp_dreq_ram[g_lp_idx].s_ram_we    |=  b_h2d_resp_ram[g_lp_idx].s_ram_we;
          b_cxl_mst_hrsp_dreq_ram[g_lp_idx].s_ram_rd    |=  b_h2d_resp_ram[g_lp_idx].s_ram_rd;
          s_hrsp_dreq_ram_wr_addr[g_lp_idx]             |=  b_h2d_resp_ram[g_lp_idx].s_ram_wr_addr;
          s_hrsp_dreq_ram_rd_addr[g_lp_idx]             |=  b_h2d_resp_ram[g_lp_idx].s_ram_rd_addr;
          b_cxl_mst_hrsp_dreq_ram[g_lp_idx].s_ram_wdata |=  (cxl_device_mode) ?  '0:
                                                      {{(HRSP_DREQ_RX_RAM_DATAW-H2D_RSP_RAM_DATAW){1'b0}}
                                                                      , b_h2d_resp_ram[g_lp_idx].s_ram_wdata};
          b_h2d_resp_ram[g_lp_idx].s_ram_rdata           =  (cxl_device_mode) ?  '0:
                                                     b_cxl_mst_hrsp_dreq_ram[g_lp_idx].s_ram_rdata[H2D_RSP_RAM_DATAW-1:0];
      end
    end
  endgenerate

  //  Generate the signals for the Host-Device-Data Ram interfaces
  generate
    for (g_lp_idx=0; g_lp_idx<HD_DDATA_NUM; g_lp_idx=g_lp_idx+1) begin
      always_comb begin
        //  Start by initializing all the signals to a default '0 value.
        //  Then, based on the mode being D2H or H2D,
        //  assign to the appropriate number of signals the corresponding value.
          b_cxl_mst_hd_data_ram[g_lp_idx].s_ram_we    = '0;
          b_cxl_mst_hd_data_ram[g_lp_idx].s_ram_rd    = '0;
          s_hd_data_ram_wr_addr[g_lp_idx]             = '0;
          s_hd_data_ram_rd_addr[g_lp_idx]             = '0;
          b_cxl_mst_hd_data_ram[g_lp_idx].s_ram_wdata = '0;
          b_cxl_mst_hd_data_ram[g_lp_idx].s_ram_we    |=  b_d2h_data_ram[g_lp_idx].s_ram_we;
          b_cxl_mst_hd_data_ram[g_lp_idx].s_ram_rd    |=  b_d2h_data_ram[g_lp_idx].s_ram_rd;
          s_hd_data_ram_wr_addr[g_lp_idx]             |= {{(HD_DATA_RX_RAM_ADDRW-D2H_DATA_RAM_ADDRW){1'b0}}
                                                                  , b_d2h_data_ram[g_lp_idx].s_ram_wr_addr};
          s_hd_data_ram_rd_addr[g_lp_idx]             |= {{(HD_DATA_RX_RAM_ADDRW-D2H_DATA_RAM_ADDRW){1'b0}}
                                                                  , b_d2h_data_ram[g_lp_idx].s_ram_rd_addr};
          b_cxl_mst_hd_data_ram[g_lp_idx].s_ram_wdata |=  (!cxl_device_mode) ?  '0:
                                                      {{(HD_DATA_RX_RAM_DATAW-D2H_DATA_RAM_DATAW){1'b0}}
                                                                      , b_d2h_data_ram[g_lp_idx].s_ram_wdata};
          b_d2h_data_ram[g_lp_idx].s_ram_rdata         =  (!cxl_device_mode) ?  '0:
                                                     b_cxl_mst_hd_data_ram[g_lp_idx].s_ram_rdata[D2H_DATA_RAM_DATAW-1:0];
          b_cxl_mst_hd_data_ram[g_lp_idx].s_ram_we    |=  b_h2d_data_ram[g_lp_idx].s_ram_we;
          b_cxl_mst_hd_data_ram[g_lp_idx].s_ram_rd    |=  b_h2d_data_ram[g_lp_idx].s_ram_rd;
          s_hd_data_ram_wr_addr[g_lp_idx]             |= {{(HD_DATA_RX_RAM_ADDRW-H2D_DATA_RAM_ADDRW){1'b0}}
                                                                  , b_h2d_data_ram[g_lp_idx].s_ram_wr_addr};
          s_hd_data_ram_rd_addr[g_lp_idx]             |= {{(HD_DATA_RX_RAM_ADDRW-H2D_DATA_RAM_ADDRW){1'b0}}
                                                                  , b_h2d_data_ram[g_lp_idx].s_ram_rd_addr};
          b_cxl_mst_hd_data_ram[g_lp_idx].s_ram_wdata |=  (cxl_device_mode) ?  '0:
                                                      {{(HD_DATA_RX_RAM_DATAW-H2D_DATA_RAM_DATAW){1'b0}}
                                                                      , b_h2d_data_ram[g_lp_idx].s_ram_wdata};
          b_h2d_data_ram[g_lp_idx].s_ram_rdata         =  (cxl_device_mode) ?  '0:
                                                     b_cxl_mst_hd_data_ram[g_lp_idx].s_ram_rdata[H2D_DATA_RAM_DATAW-1:0];
      end
    end
  endgenerate


// -------------------------------------------------------------------------------------
// RAM Address Parity Generator
// -------------------------------------------------------------------------------------
  logic [HREQ_DRSP_NUM-1:0]                                 hreq_drsp_ram_we;
  logic [HREQ_DRSP_NUM-1:0]                                 hreq_drsp_ram_waddr_par;
  logic [HREQ_DRSP_NUM-1:0][(HREQ_DRSP_RX_RAM_ADDRW-1):0]   hreq_drsp_ram_waddr;
  logic [HREQ_DRSP_NUM-1:0]                                 hreq_drsp_ram_rd;
  logic [HREQ_DRSP_NUM-1:0]                                 hreq_drsp_ram_raddr_par;
  logic [HREQ_DRSP_NUM-1:0][(HREQ_DRSP_RX_RAM_ADDRW-1):0]   hreq_drsp_ram_raddr;
  generate
    for (g_lp_idx=0; g_lp_idx<HREQ_DRSP_NUM; g_lp_idx=g_lp_idx+1) begin
      assign hreq_drsp_ram_we[g_lp_idx]                           = b_cxl_mst_hreq_drsp_ram[g_lp_idx].s_ram_we;
      assign b_cxl_mst_hreq_drsp_ram[g_lp_idx].s_ram_wr_addr_par  = hreq_drsp_ram_waddr_par[g_lp_idx];
      assign b_cxl_mst_hreq_drsp_ram[g_lp_idx].s_ram_wr_addr      = hreq_drsp_ram_waddr[g_lp_idx];
      assign hreq_drsp_ram_rd[g_lp_idx]                           = b_cxl_mst_hreq_drsp_ram[g_lp_idx].s_ram_rd;
      assign b_cxl_mst_hreq_drsp_ram[g_lp_idx].s_ram_rd_addr_par  = hreq_drsp_ram_raddr_par[g_lp_idx];
      assign b_cxl_mst_hreq_drsp_ram[g_lp_idx].s_ram_rd_addr      = hreq_drsp_ram_raddr[g_lp_idx];
    end
  endgenerate
  logic [HRSP_DREQ_NUM-1:0]                                 hrsp_dreq_ram_we;
  logic [HRSP_DREQ_NUM-1:0]                                 hrsp_dreq_ram_waddr_par;
  logic [HRSP_DREQ_NUM-1:0][(HRSP_DREQ_RX_RAM_ADDRW-1):0]   hrsp_dreq_ram_waddr;
  logic [HRSP_DREQ_NUM-1:0]                                 hrsp_dreq_ram_rd;
  logic [HRSP_DREQ_NUM-1:0]                                 hrsp_dreq_ram_raddr_par;
  logic [HRSP_DREQ_NUM-1:0][(HRSP_DREQ_RX_RAM_ADDRW-1):0]   hrsp_dreq_ram_raddr;
  generate
    for (g_lp_idx=0; g_lp_idx<HRSP_DREQ_NUM; g_lp_idx=g_lp_idx+1) begin
      assign hrsp_dreq_ram_we[g_lp_idx]                           = b_cxl_mst_hrsp_dreq_ram[g_lp_idx].s_ram_we;
      assign b_cxl_mst_hrsp_dreq_ram[g_lp_idx].s_ram_wr_addr_par  = hrsp_dreq_ram_waddr_par[g_lp_idx];
      assign b_cxl_mst_hrsp_dreq_ram[g_lp_idx].s_ram_wr_addr      = hrsp_dreq_ram_waddr[g_lp_idx];
      assign hrsp_dreq_ram_rd[g_lp_idx]                           = b_cxl_mst_hrsp_dreq_ram[g_lp_idx].s_ram_rd;
      assign b_cxl_mst_hrsp_dreq_ram[g_lp_idx].s_ram_rd_addr_par  = hrsp_dreq_ram_raddr_par[g_lp_idx];
      assign b_cxl_mst_hrsp_dreq_ram[g_lp_idx].s_ram_rd_addr      = hrsp_dreq_ram_raddr[g_lp_idx];
    end
  endgenerate
  logic [HD_DDATA_NUM-1:0]                                 hd_data_ram_we;
  logic [HD_DDATA_NUM-1:0]                                 hd_data_ram_waddr_par;
  logic [HD_DDATA_NUM-1:0][(HD_DATA_RX_RAM_ADDRW-1):0]     hd_data_ram_waddr;
  logic [HD_DDATA_NUM-1:0]                                 hd_data_ram_rd;
  logic [HD_DDATA_NUM-1:0]                                 hd_data_ram_raddr_par;
  logic [HD_DDATA_NUM-1:0][(HD_DATA_RX_RAM_ADDRW-1):0]     hd_data_ram_raddr;
  generate
    for (g_lp_idx=0; g_lp_idx<HD_DDATA_NUM; g_lp_idx=g_lp_idx+1) begin
      assign hd_data_ram_we[g_lp_idx]                           = b_cxl_mst_hd_data_ram[g_lp_idx].s_ram_we;
      assign b_cxl_mst_hd_data_ram[g_lp_idx].s_ram_wr_addr_par  = hd_data_ram_waddr_par[g_lp_idx];
      assign b_cxl_mst_hd_data_ram[g_lp_idx].s_ram_wr_addr      = hd_data_ram_waddr[g_lp_idx];
      assign hd_data_ram_rd[g_lp_idx]                           = b_cxl_mst_hd_data_ram[g_lp_idx].s_ram_rd;
      assign b_cxl_mst_hd_data_ram[g_lp_idx].s_ram_rd_addr_par  = hd_data_ram_raddr_par[g_lp_idx];
      assign b_cxl_mst_hd_data_ram[g_lp_idx].s_ram_rd_addr      = hd_data_ram_raddr[g_lp_idx];
    end
  endgenerate

logic cxl_mst_rx_tl_hd_req_ovflw;
logic cxl_mst_rx_tl_hd_rsp_ovflw;
logic cxl_mst_rx_tl_hd_data_ovflw;

assign cxl_mst_rx_tl_hd_req_ovflw   = cxl_device_mode ? cxl_mst_rx_tl_d2h_req_ovflw   : cxl_mst_rx_tl_h2d_req_ovflw ;
assign cxl_mst_rx_tl_hd_rsp_ovflw   = cxl_device_mode ? cxl_mst_rx_tl_d2h_rsp_ovflw   : cxl_mst_rx_tl_h2d_rsp_ovflw ;
assign cxl_mst_rx_tl_hd_data_ovflw  = cxl_device_mode ? cxl_mst_rx_tl_d2h_data_ovflw  : cxl_mst_rx_tl_h2d_data_ovflw; 
assign s_cxl_rx_tl_cache_pending    = cxl_device_mode ? cxl_rx_tl_cache_d2h_pending   : cxl_rx_tl_cache_h2d_pending;
assign cxl_rx_tl_cache_req_valid    = cxl_device_mode ? {{(CACHE_REQ_VALID_WD  - D2H_REQ_NUM ){1'b0}}, cxl_rx_tl_cache_d2h_req_valid } : {{(CACHE_REQ_VALID_WD   - H2D_REQ_NUM){1'b0}}, cxl_rx_tl_cache_h2d_req_valid };
assign cxl_rx_tl_cache_rsp_valid    = cxl_device_mode ? {{(CACHE_RSP_VALID_WD  - D2H_RESP_NUM){1'b0}}, cxl_rx_tl_cache_d2h_rsp_valid } : {{(CACHE_RSP_VALID_WD  - H2D_RESP_NUM){1'b0}}, cxl_rx_tl_cache_h2d_rsp_valid };
assign cxl_rx_tl_cache_data_valid   = cxl_device_mode ? cxl_rx_tl_cache_d2h_data_valid : cxl_rx_tl_cache_h2d_data_valid;



logic           s_cxl_rx_tl_mem_pending     ;
logic           cxl_rx_tl_mem_pending       ;
logic           cxl_rx_tl_mem_ch_msg_halt   ; 
logic           cxl_rx_tl_mem_nullify_crd   ;
logic           cxl_rx_tl_mem_run_crd_cnt   ;
logic           cxl_rx_link_mem_idle        ;

/////////////////////////////////////////////////////
// Mem Link Control FSM
/////////////////////////////////////////////////////
DWC_cxl_mst_link_ctrl
 U_DWC_cxl_rx_tl_mem_link_ctrl(
                              .clk                 (b_clk.s_cxl_clk             ) 
                             ,.rst_n               (b_clk.s_cxl_rst_n           )
                             ,.cxl_mst_req         (b_app_mem_init.s_cxl_init_req ) 
                             ,.cxl_mst_ack         (b_app_mem_init.s_cxl_init_ack ) 
                             ,.cxl_rx_active_req   (cxl_rx_active_req_r         )
                             ,.cxl_rx_dl_idle      (cxl_rx_dl_idle_s            )
                             ,.cxl_rx_tl_pending   (cxl_rx_tl_mem_pending       )
                             ,.cxl_rx_link_idle    (cxl_rx_link_mem_idle        )
                             ,.ch_msg_halt         (cxl_rx_tl_mem_ch_msg_halt   )
                             ,.nullify_crd         (cxl_rx_tl_mem_nullify_crd   ) 
                             ,.run_crd_cnt         (cxl_rx_tl_mem_run_crd_cnt   ));
always_ff @(posedge b_clk.s_core_clk or negedge b_clk.s_core_rst_n) begin  
  if (!b_clk.s_core_rst_n) begin
  cxl_rx_tl_mem_pending     <= 1'h0;
  end else begin
  cxl_rx_tl_mem_pending     <= s_cxl_rx_tl_mem_pending;
  end 
end

logic                                            cxl_mst_rx_tl_m2s_req_ovflw      ;
logic                                            cxl_mst_rx_tl_m2s_rsp_ovflw      ;
logic                                            cxl_mst_rx_tl_m2s_data_ovflw     ;
logic                                            cxl_rx_tl_mem_m2s_pending        ;
logic                                            cxl_rx_tl_mem_m2s_ch_msg_halt    ;
logic                                            cxl_rx_tl_mem_m2s_nullify_crd    ;
logic                                            cxl_rx_tl_mem_m2s_run_crd_cnt    ;
logic [(M2S_NDR_NUM-1)  : 0]                     cxl_rx_tl_mem_m2s_ndreq_valid    ;
logic [(M2S_DDATA_NUM-1)  : 0]                   cxl_rx_tl_mem_m2s_data_valid     ;
  DWC_cxl_ram2p_if #(
      .ADDR_WIDTH(MS_NDR_RX_RAM_ADDRW)
    , .DATA_WIDTH(M2S_NDR_RAM_DATAW))            b_m2s_ndreq_ram[(MS_SM_NDR_NUM-1):0]();
  DWC_cxl_ram2p_if #(
      .ADDR_WIDTH(M2S_DATA_RAM_ADDRW)
    , .DATA_WIDTH(M2S_DATA_RAM_DATAW))           b_m2s_data_ram[(M2S_DDATA_NUM-1):0]();
logic [(M2S_BI_RSP_NUM-1)  : 0]                  cxl_rx_tl_mem_m2s_bi_rsp_valid;
  DWC_cxl_ram2p_if #(
      .ADDR_WIDTH(MS_BI_RX_RAM_ADDRW)
    , .DATA_WIDTH(M2S_BI_RSP_RAM_DATAW))         b_m2s_bi_rsp_ram[(MS_BI_NUM-1):0]();


assign cxl_rx_tl_mem_m2s_ch_msg_halt = cxl_rx_tl_mem_ch_msg_halt     ;
assign cxl_rx_tl_mem_m2s_nullify_crd = cxl_rx_tl_mem_nullify_crd     ;
assign cxl_rx_tl_mem_m2s_run_crd_cnt = cxl_rx_tl_mem_run_crd_cnt     ;


  //  Make a packed array out of the unpacked interface array so that it
  //  becomes compatible with the port of the module.
  logic [(M2S_NDR_IFNUM-1):0]     cxl_mst_m2s_ndreq_crd;
  logic [(M2S_DATA_IFNUM-1):0]    cxl_mst_m2s_data_crd;
  generate
    for (g_lp_idx=0; g_lp_idx<M2S_NDR_IFNUM; g_lp_idx=g_lp_idx+1) begin
      assign cxl_mst_m2s_ndreq_crd[g_lp_idx]   =  b_app_host_chi.s_cxl_m2s_req_crd[g_lp_idx]; 
    end
  endgenerate
  generate
    for (g_lp_idx=0; g_lp_idx<M2S_DATA_IFNUM; g_lp_idx=g_lp_idx+1) begin
      assign cxl_mst_m2s_data_crd[g_lp_idx]  =  b_app_host_chi.s_cxl_m2s_rwd_crd[g_lp_idx]; 
    end
  endgenerate
  logic [(M2S_BI_RSP_IFNUM-1):0]    cxl_mst_m2s_bi_rsp_crd;
  generate
    for (g_lp_idx=0; g_lp_idx<M2S_BI_RSP_IFNUM; g_lp_idx=g_lp_idx+1) begin
      assign cxl_mst_m2s_bi_rsp_crd[g_lp_idx]  =  b_app_host_chi.s_cxl_m2s_bi_rsp_crd[g_lp_idx]; 
    end
  endgenerate



DWC_cxl_mem_m2s_rx_tl
 U_DWC_cxl_mem_m2s_rx_tl (
                             .b_clk                             (b_clk                          ) 
                            ,.toggle_flag_cxl_clk               (toggle_flag_cxl_clk            )
                            ,.cxl_rx_vlsm_req_flush             (cxl_rx_link_disable_r          )
                            ,.cxl_rx_tl_mem_m2s_pending         (cxl_rx_tl_mem_m2s_pending      )
                            ,.cxl_mst_rx_tl_m2s_ndreq_ovflw     (cxl_mst_rx_tl_m2s_req_ovflw    )
                            ,.cxl_mst_rx_tl_m2s_bi_ovflw        (cxl_mst_rx_tl_m2s_rsp_ovflw    )
                            ,.cxl_mst_rx_tl_m2s_data_ovflw      (cxl_mst_rx_tl_m2s_data_ovflw   )
                            ,.cxl_rx_tl_mem_m2s_ch_msg_halt     (cxl_rx_tl_mem_m2s_ch_msg_halt  )
                            ,.cxl_rx_tl_mem_m2s_nullify_crd     (cxl_rx_tl_mem_m2s_nullify_crd  )
                            ,.cxl_rx_tl_mem_m2s_run_crd_cnt     (cxl_rx_tl_mem_m2s_run_crd_cnt  )
                            ,.cxl_rx_tl_mem_m2s_ndreq_valid     (cxl_rx_tl_mem_m2s_ndreq_valid  )
                            ,.cxl_rx_tl_mem_m2s_data_valid      (cxl_rx_tl_mem_m2s_data_valid   )
                            ,.cxl_mst_m2s_ndreq                 (cxl_mst_m2s_req)
                            ,.cxl_mst_m2s_data                  (cxl_mst_m2s_rwd)
                            ,.cxl_mst_m2s_ndreq_crd             (cxl_mst_m2s_ndreq_crd) 
                            ,.cxl_mst_m2s_data_crd              (cxl_mst_m2s_data_crd) 
                            ,.cxl_dltl_m2s_crc_err              (cxl_dltl_m2s_crc_err           )
                            ,.cxl_ch_dltl_m2s_ndreq            (b_rxtl_llctrl.cxl_ch_dltl_m2s_req) 
                            ,.cxl_dltl_m2s_dhr                  (b_rxtl_llctrl.cxl_ch_dltl_m2s_dhr) 
                            ,.cxl_dltl_m2s_data                 (b_rxtl_llctrl.cxl_ch_dltl_m2s_data) 
                            ,.cxl_dltl_m2s_byte_en              (b_rxtl_llctrl.cxl_ch_dltl_m2s_byte_en) 
                            ,.cxl_dltl_m2s_data_valid           (cxl_dltl_m2s_data_valid        ) 
                            ,.cxl_dltl_m2s_byte_en_valid        (cxl_dltl_m2s_byte_en_valid     ) 
                            ,.cxl_mst_m2s_bi_rsp_crd             (cxl_mst_m2s_bi_rsp_crd)
                            ,.cxl_rx_tl_mem_m2s_bi_rsp_valid     (cxl_rx_tl_mem_m2s_bi_rsp_valid  )
                            ,.cxl_mst_m2s_bi_rsp                 (cxl_mst_m2s_bi_rsp)
                            ,.cxl_ch_dltl_m2s_bi_rsp            (b_rxtl_llctrl.cxl_ch_dltl_m2s_bi_rsp)
                            ,.b_m2s_ndreq_ram                   (b_m2s_ndreq_ram.master_mp)
                            ,.b_m2s_data_ram                    (b_m2s_data_ram.master_mp)
                            ,.b_m2s_bi_rsp_ram                  (b_m2s_bi_rsp_ram.master_mp)
                        );

logic                                            cxl_mst_rx_tl_s2m_req_ovflw      ;
logic                                            cxl_mst_rx_tl_s2m_rsp_ovflw      ;
logic                                            cxl_mst_rx_tl_s2m_data_ovflw     ;
logic                                            cxl_rx_tl_mem_s2m_pending        ;
logic                                            cxl_rx_tl_mem_s2m_ch_msg_halt    ;
logic                                            cxl_rx_tl_mem_s2m_nullify_crd    ;
logic                                            cxl_rx_tl_mem_s2m_run_crd_cnt    ;
logic [(S2M_NDR_NUM-1) : 0]                      cxl_rx_tl_mem_s2m_ndrsp_valid    ;
logic [(S2M_DDATA_NUM-1) : 0]                    cxl_rx_tl_mem_s2m_data_valid     ;
  DWC_cxl_ram2p_if #(
      .ADDR_WIDTH(MS_NDR_RX_RAM_ADDRW)
    , .DATA_WIDTH(S2M_NDR_RAM_DATAW))            b_s2m_ndrsp_ram[(MS_SM_NDR_NUM-1):0]();
  DWC_cxl_ram2p_if #(
      .ADDR_WIDTH(S2M_DATA_RAM_ADDRW)
    , .DATA_WIDTH(S2M_DATA_RAM_DATAW))           b_s2m_data_ram[(S2M_DDATA_NUM-1):0]();
logic [(S2M_BI_SNP_NUM-1)  : 0]                  cxl_rx_tl_mem_s2m_bi_snp_valid;
  DWC_cxl_ram2p_if #(
      .ADDR_WIDTH(MS_BI_RX_RAM_ADDRW)
    , .DATA_WIDTH(S2M_BI_SNP_RAM_DATAW))         b_s2m_bi_snp_ram[(MS_BI_NUM-1):0]();


assign cxl_rx_tl_mem_s2m_ch_msg_halt = cxl_rx_tl_mem_ch_msg_halt     ;
assign cxl_rx_tl_mem_s2m_nullify_crd = cxl_rx_tl_mem_nullify_crd     ;
assign cxl_rx_tl_mem_s2m_run_crd_cnt = cxl_rx_tl_mem_run_crd_cnt     ;

  //  Make a packed array out of the unpacked interface array so that it
  //  becomes compatible with the port of the module.
  logic [(S2M_NDR_IFNUM-1):0]     cxl_mst_s2m_ndrsp_crd;
  logic [(S2M_DATA_IFNUM-1):0]    cxl_mst_s2m_data_crd;
  generate
    for (g_lp_idx=0; g_lp_idx<S2M_NDR_IFNUM; g_lp_idx=g_lp_idx+1) begin
      assign cxl_mst_s2m_ndrsp_crd[g_lp_idx]   =  b_app_dev_chi.s_cxl_s2m_ndr_crd[g_lp_idx]; 
    end
  endgenerate
  generate
    for (g_lp_idx=0; g_lp_idx<S2M_DATA_IFNUM; g_lp_idx=g_lp_idx+1) begin
      assign cxl_mst_s2m_data_crd[g_lp_idx]  =  b_app_dev_chi.s_cxl_s2m_drc_crd[g_lp_idx]; 
    end
  endgenerate
  logic [(S2M_BI_SNP_IFNUM-1):0]    cxl_mst_s2m_bi_snp_crd;
  generate
    for (g_lp_idx=0; g_lp_idx<S2M_BI_SNP_IFNUM; g_lp_idx=g_lp_idx+1) begin
      assign cxl_mst_s2m_bi_snp_crd[g_lp_idx]  =  b_app_dev_chi.s_cxl_s2m_bi_snp_crd[g_lp_idx]; 
    end
  endgenerate

DWC_cxl_mem_s2m_rx_tl
 U_DWC_cxl_mem_s2m_rx_tl (
                             .b_clk                             (b_clk                          ) 
                            ,.toggle_flag_cxl_clk               (toggle_flag_cxl_clk            )
                            ,.cxl_rx_vlsm_req_flush             (cxl_rx_link_disable_r          )
                            ,.cxl_rx_tl_mem_s2m_pending         (cxl_rx_tl_mem_s2m_pending      )
                            ,.cxl_mst_rx_tl_s2m_bi_snp_ovflw    (cxl_mst_rx_tl_s2m_req_ovflw    )
                            ,.cxl_mst_rx_tl_s2m_ndrsp_ovflw     (cxl_mst_rx_tl_s2m_rsp_ovflw    )
                            ,.cxl_mst_rx_tl_s2m_data_ovflw      (cxl_mst_rx_tl_s2m_data_ovflw   )
                            ,.cxl_rx_tl_mem_s2m_ch_msg_halt     (cxl_rx_tl_mem_s2m_ch_msg_halt  )
                            ,.cxl_rx_tl_mem_s2m_nullify_crd     (cxl_rx_tl_mem_s2m_nullify_crd  )
                            ,.cxl_rx_tl_mem_s2m_run_crd_cnt     (cxl_rx_tl_mem_s2m_run_crd_cnt  )
                            ,.cxl_rx_tl_mem_s2m_ndrsp_valid     (cxl_rx_tl_mem_s2m_ndrsp_valid  )
                            ,.cxl_rx_tl_mem_s2m_data_valid      (cxl_rx_tl_mem_s2m_data_valid   )
                            ,.cxl_mst_s2m_ndrsp                 (cxl_mst_s2m_ndr)
                            ,.cxl_mst_s2m_data                  (cxl_mst_s2m_drc)
                            ,.cxl_mst_s2m_ndrsp_crd             (cxl_mst_s2m_ndrsp_crd)
                            ,.cxl_mst_s2m_data_crd              (cxl_mst_s2m_data_crd)
                            ,.cxl_dltl_s2m_crc_err              (cxl_dltl_s2m_crc_err           )
                            ,.cxl_ch_dltl_s2m_ndrsp             (b_rxtl_llctrl.cxl_ch_dltl_s2m_ndr)
                            ,.cxl_ch_dltl_s2m_dhr               (b_rxtl_llctrl.cxl_ch_dltl_s2m_drs)
                            ,.cxl_dltl_s2m_data                 (b_rxtl_llctrl.cxl_ch_dltl_s2m_data)
                            ,.cxl_dltl_s2m_data_valid           (cxl_dltl_s2m_data_valid        )
                            ,.cxl_rx_tl_mem_s2m_bi_snp_valid     (cxl_rx_tl_mem_s2m_bi_snp_valid  )
                            ,.cxl_mst_s2m_bi_snp                 (cxl_mst_s2m_bi_snp)
                            ,.cxl_mst_s2m_bi_snp_crd             (cxl_mst_s2m_bi_snp_crd)
                            ,.cxl_dltl_s2m_bi_snp                (b_rxtl_llctrl.cxl_ch_dltl_s2m_bi_snp)
                            ,.b_s2m_ndrsp_ram                   (b_s2m_ndrsp_ram.master_mp)
                            ,.b_s2m_data_ram                    (b_s2m_data_ram.master_mp)
                            ,.b_s2m_bi_snp_ram                  (b_s2m_bi_snp_ram.master_mp)
                            );
logic [(MS_SM_NDR_NUM-1)  :0][(MS_NDR_RX_RAM_ADDRW-1) : 0] s_ms_ndr_ram_wr_addr;
logic [(MS_SM_DDATA_NUM-1):0][(MS_DATA_RX_RAM_ADDRW-1): 0] s_ms_data_ram_wr_addr;

logic [(MS_SM_NDR_NUM-1)  :0][(MS_NDR_RX_RAM_ADDRW-1) : 0] s_ms_ndr_ram_rd_addr;
logic [(MS_SM_DDATA_NUM-1):0][(MS_DATA_RX_RAM_ADDRW-1): 0] s_ms_data_ram_rd_addr;
logic [(MS_BI_NUM-1):0][(MS_BI_RX_RAM_ADDRW-1)  : 0] s_ms_bi_ram_wr_addr;
logic [(MS_BI_NUM-1):0][(MS_BI_RX_RAM_ADDRW-1)  : 0] s_ms_bi_ram_rd_addr;



  //  Generate the signals for the M2S and S2M Request and Response Ram interfaces
  generate
    for (g_lp_idx=0; g_lp_idx<MS_NDR_NUM; g_lp_idx=g_lp_idx+1) begin
      always_comb begin
        //  Start by initializing all the signals to a default '0 value.
        //  Then, based on the mode being S2M or M2S,
        //  assign to the appropriate number of signals the corresponding value.
        b_cxl_mst_ms_ndr_ram[g_lp_idx].s_ram_we    = '0;
        b_cxl_mst_ms_ndr_ram[g_lp_idx].s_ram_rd    = '0;
        s_ms_ndr_ram_wr_addr[g_lp_idx]             = '0;
        s_ms_ndr_ram_rd_addr[g_lp_idx]             = '0;
        b_cxl_mst_ms_ndr_ram[g_lp_idx].s_ram_wdata = '0;
          b_cxl_mst_ms_ndr_ram[g_lp_idx].s_ram_we    |=  b_s2m_ndrsp_ram[g_lp_idx].s_ram_we;
          b_cxl_mst_ms_ndr_ram[g_lp_idx].s_ram_rd    |=  b_s2m_ndrsp_ram[g_lp_idx].s_ram_rd;
          s_ms_ndr_ram_wr_addr[g_lp_idx]             |=  b_s2m_ndrsp_ram[g_lp_idx].s_ram_wr_addr;
          s_ms_ndr_ram_rd_addr[g_lp_idx]             |=  b_s2m_ndrsp_ram[g_lp_idx].s_ram_rd_addr;
          b_cxl_mst_ms_ndr_ram[g_lp_idx].s_ram_wdata |=  (!cxl_device_mode) ?  '0:
                                                      {{(MS_NDR_RX_RAM_DATAW-S2M_NDR_RAM_DATAW){1'b0}}
                                                                      , b_s2m_ndrsp_ram[g_lp_idx].s_ram_wdata};
          b_cxl_mst_ms_ndr_ram[g_lp_idx].s_ram_we    |=  b_m2s_ndreq_ram[g_lp_idx].s_ram_we;
          b_cxl_mst_ms_ndr_ram[g_lp_idx].s_ram_rd    |=  b_m2s_ndreq_ram[g_lp_idx].s_ram_rd;
          s_ms_ndr_ram_wr_addr[g_lp_idx]             |=  b_m2s_ndreq_ram[g_lp_idx].s_ram_wr_addr;
          s_ms_ndr_ram_rd_addr[g_lp_idx]             |=  b_m2s_ndreq_ram[g_lp_idx].s_ram_rd_addr;
          b_cxl_mst_ms_ndr_ram[g_lp_idx].s_ram_wdata |=  (cxl_device_mode) ?  '0:
                                                      {{(MS_NDR_RX_RAM_DATAW-M2S_NDR_RAM_DATAW){1'b0}}
                                                                      , b_m2s_ndreq_ram[g_lp_idx].s_ram_wdata};
      end
    end
  endgenerate

  //  Generate the signals for the M2S and S2M data Ram interfaces
  generate
    for (g_lp_idx=0; g_lp_idx<MS_SM_DDATA_NUM; g_lp_idx=g_lp_idx+1) begin
      assign b_cxl_mst_ms_data_ram[g_lp_idx].s_ram_we                 = (
                                                                1'b0
                                                                | b_s2m_data_ram[g_lp_idx].s_ram_we
                                                                | b_m2s_data_ram[g_lp_idx].s_ram_we
                                                              );
      assign b_cxl_mst_ms_data_ram[g_lp_idx].s_ram_rd                 = (
                                                                1'b0
                                                                | b_s2m_data_ram[g_lp_idx].s_ram_rd
                                                                | b_m2s_data_ram[g_lp_idx].s_ram_rd
                                                              );
      assign s_ms_data_ram_wr_addr[g_lp_idx]                          = (
                                                                'h0
                                                                | {{(MS_DATA_RX_RAM_ADDRW-S2M_DATA_RAM_ADDRW){1'b0}}
                                                                   , b_s2m_data_ram[g_lp_idx].s_ram_wr_addr}
                                                                | {{(MS_DATA_RX_RAM_ADDRW-M2S_DATA_RAM_ADDRW){1'b0}}
                                                                   , b_m2s_data_ram[g_lp_idx].s_ram_wr_addr}
                                                              );
      assign s_ms_data_ram_rd_addr[g_lp_idx]                          = (
                                                                'h0
                                                                | {{(MS_DATA_RX_RAM_ADDRW-S2M_DATA_RAM_ADDRW){1'b0}}
                                                                   , b_s2m_data_ram[g_lp_idx].s_ram_rd_addr}
                                                                | {{(MS_DATA_RX_RAM_ADDRW-M2S_DATA_RAM_ADDRW){1'b0}}
                                                                   , b_m2s_data_ram[g_lp_idx].s_ram_rd_addr}
                                                              );

      assign b_cxl_mst_ms_data_ram[g_lp_idx].s_ram_wdata              = (cxl_device_mode ?
                                                                {{(MS_DATA_RX_RAM_DATAW-S2M_DATA_RAM_DATAW){1'b0}}
                                                                    , b_s2m_data_ram[g_lp_idx].s_ram_wdata}:
                                                                {{(MS_DATA_RX_RAM_DATAW-M2S_DATA_RAM_DATAW){1'b0}}
                                                                    , b_m2s_data_ram[g_lp_idx].s_ram_wdata});

    end
  endgenerate
 
  generate
    for (g_lp_idx=0; g_lp_idx<MS_BI_NUM; g_lp_idx=g_lp_idx+1) begin
      assign b_cxl_mst_mrsp_ssnp_bi_ram[g_lp_idx].s_ram_we  = ( '0
                                                                | b_s2m_bi_snp_ram[g_lp_idx].s_ram_we
                                                                | b_m2s_bi_rsp_ram[g_lp_idx].s_ram_we
                                                              );
      assign b_cxl_mst_mrsp_ssnp_bi_ram[g_lp_idx].s_ram_rd  = ( '0
                                                                | b_s2m_bi_snp_ram[g_lp_idx].s_ram_rd
                                                                | b_m2s_bi_rsp_ram[g_lp_idx].s_ram_rd
                                                               );

      assign s_ms_bi_ram_wr_addr[g_lp_idx]    = ('0
                                                                | b_s2m_bi_snp_ram[g_lp_idx].s_ram_wr_addr
                                                                | b_m2s_bi_rsp_ram[g_lp_idx].s_ram_wr_addr
                                                               );
      assign s_ms_bi_ram_rd_addr[g_lp_idx]    = ('0
                                                                | b_s2m_bi_snp_ram[g_lp_idx].s_ram_rd_addr
                                                                | b_m2s_bi_rsp_ram[g_lp_idx].s_ram_rd_addr
                                                               );
    end
  endgenerate



  generate
    for (g_lp_idx=0; g_lp_idx<MS_BI_NUM; g_lp_idx=g_lp_idx+1) begin
      assign b_cxl_mst_mrsp_ssnp_bi_ram[g_lp_idx].s_ram_wdata  = (cxl_device_mode ?
                                                            {{(MS_BI_RX_RAM_DATAW-S2M_BI_SNP_RAM_DATAW){1'b0}}
                                                              , b_s2m_bi_snp_ram[g_lp_idx].s_ram_wdata} :
                                                            {{(MS_BI_RX_RAM_DATAW-M2S_BI_RSP_RAM_DATAW){1'b0}}
                                                              , b_m2s_bi_rsp_ram[g_lp_idx].s_ram_wdata});
    end
  endgenerate

  logic [MS_SM_NDR_NUM-1:0]                               ms_ndr_ram_we;
  logic [MS_SM_NDR_NUM-1:0]                               ms_ndr_ram_waddr_par;
  logic [MS_SM_NDR_NUM-1:0][(MS_NDR_RX_RAM_ADDRW-1):0]    ms_ndr_ram_waddr;
  logic [MS_SM_NDR_NUM-1:0]                               ms_ndr_ram_rd;
  logic [MS_SM_NDR_NUM-1:0]                               ms_ndr_ram_raddr_par;
  logic [MS_SM_NDR_NUM-1:0][(MS_NDR_RX_RAM_ADDRW-1):0]    ms_ndr_ram_raddr;
  generate
    for (g_lp_idx=0; g_lp_idx<MS_SM_NDR_NUM; g_lp_idx=g_lp_idx+1) begin
      assign ms_ndr_ram_we[g_lp_idx]                              = b_cxl_mst_ms_ndr_ram[g_lp_idx].s_ram_we;
      assign b_cxl_mst_ms_ndr_ram[g_lp_idx].s_ram_wr_addr_par     = ms_ndr_ram_waddr_par[g_lp_idx];
      assign b_cxl_mst_ms_ndr_ram[g_lp_idx].s_ram_wr_addr         = ms_ndr_ram_waddr[g_lp_idx];
      assign ms_ndr_ram_rd[g_lp_idx]                              = b_cxl_mst_ms_ndr_ram[g_lp_idx].s_ram_rd;
      assign b_cxl_mst_ms_ndr_ram[g_lp_idx].s_ram_rd_addr_par     = ms_ndr_ram_raddr_par[g_lp_idx];
      assign b_cxl_mst_ms_ndr_ram[g_lp_idx].s_ram_rd_addr         = ms_ndr_ram_raddr[g_lp_idx];
    end
  endgenerate

  logic [MS_SM_DDATA_NUM-1:0]                               ms_data_ram_we;
  logic [MS_SM_DDATA_NUM-1:0]                               ms_data_ram_waddr_par;
  logic [MS_SM_DDATA_NUM-1:0][(MS_DATA_RX_RAM_ADDRW-1):0]   ms_data_ram_waddr;
  logic [MS_SM_DDATA_NUM-1:0]                               ms_data_ram_rd;
  logic [MS_SM_DDATA_NUM-1:0]                               ms_data_ram_raddr_par;
  logic [MS_SM_DDATA_NUM-1:0][(MS_DATA_RX_RAM_ADDRW-1):0]   ms_data_ram_raddr;
  generate
    for (g_lp_idx=0; g_lp_idx<MS_SM_DDATA_NUM; g_lp_idx=g_lp_idx+1) begin
      assign ms_data_ram_we[g_lp_idx]                              = b_cxl_mst_ms_data_ram[g_lp_idx].s_ram_we;
      assign b_cxl_mst_ms_data_ram[g_lp_idx].s_ram_wr_addr_par     = ms_data_ram_waddr_par[g_lp_idx];
      assign b_cxl_mst_ms_data_ram[g_lp_idx].s_ram_wr_addr         = ms_data_ram_waddr[g_lp_idx];
      assign ms_data_ram_rd[g_lp_idx]                              = b_cxl_mst_ms_data_ram[g_lp_idx].s_ram_rd;
      assign b_cxl_mst_ms_data_ram[g_lp_idx].s_ram_rd_addr_par     = ms_data_ram_raddr_par[g_lp_idx];
      assign b_cxl_mst_ms_data_ram[g_lp_idx].s_ram_rd_addr         = ms_data_ram_raddr[g_lp_idx];
    end
  endgenerate

  logic [MS_BI_NUM-1:0]                             mrsp_ssnp_bi_ram_we;
  logic [MS_BI_NUM-1:0]                             mrsp_ssnp_bi_ram_waddr_par;
  logic [MS_BI_NUM-1:0][(MS_BI_RX_RAM_ADDRW-1):0]   mrsp_ssnp_bi_ram_waddr;
  logic [MS_BI_NUM-1:0]                             mrsp_ssnp_bi_ram_rd;
  logic [MS_BI_NUM-1:0]                             mrsp_ssnp_bi_ram_raddr_par;
  logic [MS_BI_NUM-1:0][(MS_BI_RX_RAM_ADDRW-1):0]   mrsp_ssnp_bi_ram_raddr;
  generate
    for (g_lp_idx=0; g_lp_idx<MS_BI_NUM; g_lp_idx=g_lp_idx+1) begin
      assign mrsp_ssnp_bi_ram_we[g_lp_idx]                          = b_cxl_mst_mrsp_ssnp_bi_ram[g_lp_idx].s_ram_we;
      assign b_cxl_mst_mrsp_ssnp_bi_ram[g_lp_idx].s_ram_wr_addr_par = mrsp_ssnp_bi_ram_waddr_par[g_lp_idx];
      assign b_cxl_mst_mrsp_ssnp_bi_ram[g_lp_idx].s_ram_wr_addr     = mrsp_ssnp_bi_ram_waddr[g_lp_idx];
      assign mrsp_ssnp_bi_ram_rd[g_lp_idx]                          = b_cxl_mst_mrsp_ssnp_bi_ram[g_lp_idx].s_ram_rd;
      assign b_cxl_mst_mrsp_ssnp_bi_ram[g_lp_idx].s_ram_rd_addr_par = mrsp_ssnp_bi_ram_raddr_par[g_lp_idx];
      assign b_cxl_mst_mrsp_ssnp_bi_ram[g_lp_idx].s_ram_rd_addr     = mrsp_ssnp_bi_ram_raddr[g_lp_idx];
    end
  endgenerate


logic cxl_mst_rx_tl_ms_req_ovflw;
logic cxl_mst_rx_tl_ms_rsp_ovflw;
logic cxl_mst_rx_tl_ms_data_ovflw;

assign cxl_rx_tl_mem_ndr_valid      = cxl_device_mode ? {{(MEM_NDR_VALID_WD - S2M_NDR_NUM ){1'b0}}, cxl_rx_tl_mem_s2m_ndrsp_valid} : {{(MEM_NDR_VALID_WD - M2S_NDR_NUM ){1'b0}}, cxl_rx_tl_mem_m2s_ndreq_valid};
assign cxl_rx_tl_mem_data_valid     = cxl_device_mode ? cxl_rx_tl_mem_s2m_data_valid : cxl_rx_tl_mem_m2s_data_valid;
assign cxl_rx_tl_mem_bi_valid       = cxl_device_mode ? {{(MEM_BI_VALID_WD - S2M_BI_SNP_NUM ){1'b0}}, cxl_rx_tl_mem_s2m_bi_snp_valid} : {{(MEM_BI_VALID_WD - M2S_BI_RSP_NUM ){1'b0}}, cxl_rx_tl_mem_m2s_bi_rsp_valid};

      assign s_cxl_rx_tl_mem_pending      = cxl_device_mode ? cxl_rx_tl_mem_s2m_pending     : cxl_rx_tl_mem_m2s_pending;

  generate
    for (g_lp_idx=0; g_lp_idx<MS_SM_NDR_NUM; g_lp_idx=g_lp_idx+1) begin
      assign b_m2s_ndreq_ram[g_lp_idx].s_ram_rdata  = cxl_device_mode ?
                                                      'h0:
                                                      b_cxl_mst_ms_ndr_ram[g_lp_idx].s_ram_rdata[M2S_NDR_RAM_DATAW-1:0];
    end
    for (g_lp_idx=0; g_lp_idx<MS_SM_NDR_NUM; g_lp_idx=g_lp_idx+1) begin
      assign b_s2m_ndrsp_ram[g_lp_idx].s_ram_rdata  = cxl_device_mode ?
                                                      b_cxl_mst_ms_ndr_ram[g_lp_idx].s_ram_rdata[S2M_NDR_RAM_DATAW-1:0]:
                                                      'h0;
    end
  endgenerate

  generate
    for (g_lp_idx=0; g_lp_idx<MS_SM_DDATA_NUM; g_lp_idx=g_lp_idx+1) begin
      assign b_m2s_data_ram[g_lp_idx].s_ram_rdata   = cxl_device_mode ?
                                                      'h0:
                                                      b_cxl_mst_ms_data_ram[g_lp_idx].s_ram_rdata[M2S_DATA_RAM_DATAW-1:0];
      assign b_s2m_data_ram[g_lp_idx].s_ram_rdata   = cxl_device_mode ?
                                                      b_cxl_mst_ms_data_ram[g_lp_idx].s_ram_rdata[S2M_DATA_RAM_DATAW-1:0]:
                                                      'h0;
    end
  endgenerate

assign cxl_mst_rx_tl_ms_req_ovflw   = cxl_device_mode ? cxl_mst_rx_tl_s2m_req_ovflw   : cxl_mst_rx_tl_m2s_req_ovflw ;
assign cxl_mst_rx_tl_ms_rsp_ovflw   = cxl_device_mode ? cxl_mst_rx_tl_s2m_rsp_ovflw   : cxl_mst_rx_tl_m2s_rsp_ovflw ;
assign cxl_mst_rx_tl_ms_data_ovflw  = cxl_device_mode ? cxl_mst_rx_tl_s2m_data_ovflw  : cxl_mst_rx_tl_m2s_data_ovflw;

  generate
    for (g_lp_idx=0; g_lp_idx<MS_BI_NUM; g_lp_idx=g_lp_idx+1) begin
      assign b_m2s_bi_rsp_ram[g_lp_idx].s_ram_rdata = cxl_device_mode ?
                                                '0 :
                                                b_cxl_mst_mrsp_ssnp_bi_ram[g_lp_idx].s_ram_rdata[M2S_BI_RSP_RAM_DATAW-1:0] ;
    end
  endgenerate
  generate
    for (g_lp_idx=0; g_lp_idx<MS_BI_NUM; g_lp_idx=g_lp_idx+1) begin
      assign b_s2m_bi_snp_ram[g_lp_idx].s_ram_rdata  = cxl_device_mode ?
                                                b_cxl_mst_mrsp_ssnp_bi_ram[g_lp_idx].s_ram_rdata[S2M_BI_SNP_RAM_DATAW-1:0] :
                                                '0 ;
    end
  endgenerate

assign cxl_rx_tl_pending  =  1'b0                                         || cxl_rx_tl_cache_pending                                         || cxl_rx_tl_mem_pending ;
assign cxl_rx_link_idle_s  =  1'b1                                         && cxl_rx_link_cache_idle                                         && cxl_rx_link_mem_idle ;
logic [(CX_CXL_RX_TL_PTR_ERR_WD-1):0] s_cxl_rx_tl_fifo_data_out_ptr_err;
assign s_cxl_rx_tl_fifo_data_out_ptr_err[0] = (1'b0 | cxl_mst_h2d_req_fifo_data_out_ptr_err);


assign cxl_rx_dltl_ras_valid_err[0] = (1'b0 | (cxl_rasdp_h2d_data_valid_inv    == cxl_dltl_h2d_data_valid   )); 
assign cxl_rx_dltl_ras_valid_err[1] = (1'b0 | (cxl_rasdp_d2h_data_valid_inv    == cxl_dltl_d2h_data_valid   ));
assign cxl_rx_dltl_ras_valid_err[2] = (1'b0 | (cxl_rasdp_d2h_byte_en_valid_inv == cxl_dltl_d2h_byte_en_valid));
assign cxl_rx_dltl_ras_valid_err[3] = (1'b0 | (cxl_rasdp_m2s_data_valid_inv    == cxl_dltl_m2s_data_valid   )); 
assign cxl_rx_dltl_ras_valid_err[4] = (1'b0 | (cxl_rasdp_m2s_byte_en_valid_inv == cxl_dltl_m2s_byte_en_valid)); 
assign cxl_rx_dltl_ras_valid_err[5] = (1'b0 | (cxl_rasdp_s2m_data_valid_inv    == cxl_dltl_s2m_data_valid   )); 

// -------------------------------------------------------------------------------------
// RAS Parity Generators for RAM Protection
// -------------------------------------------------------------------------------------
DWC_cxl_mem_cache_rx_tl_ras_ms
 u_DWC_cxl_mem_cache_rx_tl_ras (
     .b_clk                         ( b_clk                                   )
    ,.hreq_drsp_ram_waddr_i         ( s_hreq_drsp_ram_wr_addr                 )
    ,.hreq_drsp_ram_raddr_i         ( s_hreq_drsp_ram_rd_addr                 )
    ,.hrsp_dreq_ram_waddr_i         ( s_hrsp_dreq_ram_wr_addr                 )
    ,.hrsp_dreq_ram_raddr_i         ( s_hrsp_dreq_ram_rd_addr                 )
    ,.hd_data_ram_waddr_i           ( s_hd_data_ram_wr_addr                   )
    ,.hd_data_ram_raddr_i           ( s_hd_data_ram_rd_addr                   )
    ,.hreq_drsp_ram_waddr_o         ( hreq_drsp_ram_waddr                     )
    ,.hreq_drsp_ram_waddr_par_o     ( hreq_drsp_ram_waddr_par                 )
    ,.hreq_drsp_ram_raddr_o         ( hreq_drsp_ram_raddr                     )
    ,.hreq_drsp_ram_raddr_par_o     ( hreq_drsp_ram_raddr_par                 )
    ,.hrsp_dreq_ram_waddr_o         ( hrsp_dreq_ram_waddr                     )
    ,.hrsp_dreq_ram_waddr_par_o     ( hrsp_dreq_ram_waddr_par                 )
    ,.hrsp_dreq_ram_raddr_par_o     ( hrsp_dreq_ram_raddr_par                 )
    ,.hrsp_dreq_ram_raddr_o         ( hrsp_dreq_ram_raddr                     )
    ,.hd_data_ram_waddr_o           ( hd_data_ram_waddr                       )
    ,.hd_data_ram_waddr_par_o       ( hd_data_ram_waddr_par                   )
    ,.hd_data_ram_raddr_o           ( hd_data_ram_raddr                       )
    ,.hd_data_ram_raddr_par_o       ( hd_data_ram_raddr_par                   )
    ,.ms_ndr_ram_waddr_i            ( s_ms_ndr_ram_wr_addr                    )
    ,.ms_ndr_ram_raddr_i            ( s_ms_ndr_ram_rd_addr                    )
    ,.ms_data_ram_waddr_i           ( s_ms_data_ram_wr_addr                   )
    ,.ms_data_ram_raddr_i           ( s_ms_data_ram_rd_addr                   )
    ,.ms_ndr_ram_waddr_o            ( ms_ndr_ram_waddr                        )
    ,.ms_ndr_ram_waddr_par_o        ( ms_ndr_ram_waddr_par                    )
    ,.ms_ndr_ram_raddr_o            ( ms_ndr_ram_raddr                        )
    ,.ms_ndr_ram_raddr_par_o        ( ms_ndr_ram_raddr_par                    )
    ,.ms_data_ram_waddr_o           ( ms_data_ram_waddr                       )
    ,.ms_data_ram_waddr_par_o       ( ms_data_ram_waddr_par                   )
    ,.ms_data_ram_raddr_o           ( ms_data_ram_raddr                       )
    ,.ms_data_ram_raddr_par_o       ( ms_data_ram_raddr_par                   )
    ,.ms_bi_ram_waddr_i             ( s_ms_bi_ram_wr_addr                     )
    ,.ms_bi_ram_raddr_i             ( s_ms_bi_ram_rd_addr                     )
    ,.mrsp_ssnp_bi_ram_waddr_o      ( mrsp_ssnp_bi_ram_waddr                  )
    ,.mrsp_ssnp_bi_ram_waddr_par_o  ( mrsp_ssnp_bi_ram_waddr_par              )
    ,.mrsp_ssnp_bi_ram_raddr_o      ( mrsp_ssnp_bi_ram_raddr                  )
    ,.mrsp_ssnp_bi_ram_raddr_par_o  ( mrsp_ssnp_bi_ram_raddr_par              )
);
logic [7:0] s_cxl_rx_fifo_ovflw;
//TODO extra filed for sm related ovflw
assign s_cxl_rx_fifo_ovflw[2:0] = {cxl_mst_rx_tl_hd_data_ovflw, cxl_mst_rx_tl_hd_rsp_ovflw, cxl_mst_rx_tl_hd_req_ovflw};
assign s_cxl_rx_fifo_ovflw[5:3] = {cxl_mst_rx_tl_ms_data_ovflw, cxl_mst_rx_tl_ms_rsp_ovflw, cxl_mst_rx_tl_ms_req_ovflw};
assign s_cxl_rx_fifo_ovflw[7:6] = 2'd0;

always_ff @(posedge b_clk.s_core_clk or negedge b_clk.s_core_rst_n) begin  
  if (!b_clk.s_core_rst_n) begin
  cxl_rx_tl_fifo_data_out_ptr_err     <= #TP {CX_CXL_RX_TL_PTR_ERR_WD{1'b0}};
  cxl_rx_fifo_ovflw                   <= #TP 8'h00;
  end else begin
  cxl_rx_tl_fifo_data_out_ptr_err     <= #TP s_cxl_rx_tl_fifo_data_out_ptr_err;
  cxl_rx_fifo_ovflw                   <= #TP s_cxl_rx_fifo_ovflw;
  end 
end

endmodule
