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
// ---   $DateTime: 2023/09/27 02:27:25 $
// ---   $Revision: #7 $
// ---   $Id: //dwh/pcie_iip/main/fairbanks/design/CXL/DWC_cxl_mem_cache_fc.sv#7 $
// -------------------------------------------------------------------------
// --- Module Description:
// ----------------------------------------------------------------------------
// Flow Control Counters used to control the transmit interface based on the
// remote receive queues resource availability.
// ----------------------------------------------------------------------------

`include "include/DWC_pcie_ctl_all_defs.svh"
`include "CXL/pkg/DWC_cxl_pkg.svh"

module DWC_cxl_mem_cache_fc
    import DWC_cxl_pkg::*;
#(
    parameter TP = `TP
)
                               (
// Inputs ------------------------------------------------------------------------------
     input                                   core_clk                   // Core clock
    ,input                                   core_rst_n                 // Core reset
    ,input                                   cxl_device_mode            // 0 - Endpoint; 1 - Root Complex Device
    ,input                                   cxl_pcie_flit_mode         // CXL 256B Flit Mode
    ,input CRD_256B_t                        cxl_256B_rx_crdret         // RX Credit Return in 256B Flit Mode - received 2B CRD field
    ,input                                   cfg_cache_enable           // CXL.cache Enable
    ,input  [TX_CRDIF_WIDTH-1:0]             cxl_cache_data_valid       // CXL.cache data valid
    ,input  [TX_CRDIF_WIDTH-1:0]             cxl_cache_rsp_valid        // CXL.cache response valid
    ,input  [TX_CRDIF_WIDTH-1:0]             cxl_cache_req_valid        // CXL.cache request valid
    ,input                                   cfg_mem_enable             // CXL.mem Enable
    ,input  [TX_CRDIF_WIDTH-1:0]             cxl_mem_ndr_valid          // CXL.mem Request/Response valid
    ,input  [TX_CRDIF_WIDTH-1:0]             cxl_mem_data_valid         // CXL.mem data valid
    ,input  [TX_CRDIF_WIDTH-1:0]             cxl_mem_bi_valid           // CXL.mem BI-Snoop/Response valid
    ,input  [FLIT_CRD_WD-1:0]                cxl_rx_data_crd            // Data Credit Returns received
    ,input  [FLIT_CRD_WD-1:0]                cxl_rx_rsp_crd             // Response Credit Returns received
    ,input  [FLIT_CRD_WD-1:0]                cxl_rx_req_crd             // Request Credit Returns received
// Outputs -----------------------------------------------------------------------------
    ,output logic                            rsvd_crd_enc_error 

    ,output logic [TX_CREDIT_WD-1:0]         cxl_ll_cache_data_crd      // CXL.cache data credit counter
    ,output logic [TX_CREDIT_WD-1:0]         cxl_ll_cache_rsp_crd       // CXL.cache response credit counter
    ,output logic [TX_CREDIT_WD-1:0]         cxl_ll_cache_req_crd       // CXL.cache request credit counter
    ,output logic [TX_CRDIF_WIDTH-1:0]       cxl_ll_cache_req_gnt       // CXL.cache request grant
    ,output logic [TX_CRDIF_WIDTH-1:0]       cxl_ll_cache_rsp_gnt       // CXL.cache response grant
    ,output logic [TX_CRDIF_WIDTH-1:0]       cxl_ll_cache_data_gnt      // CXL.cache data grant
    ,output logic [TX_CREDIT_WD-1:0]         cxl_ll_mem_data_crd        // CXL.mem data request/response credit
    ,output logic [TX_CREDIT_WD-1:0]         cxl_ll_mem_ndr_crd         // CXL.mem no data request/response credit
    ,output logic [TX_CRDIF_WIDTH-1:0]       cxl_ll_mem_data_gnt        // CXL.mem data grant
    ,output logic [TX_CRDIF_WIDTH-1:0]       cxl_ll_mem_ndr_gnt         // CXL.mem non data request/response grant
    ,output logic [TX_CREDIT_WD-1:0]         cxl_ll_mem_bi_crd          // CXL.mem BI-Snoop/Response credit
    ,output logic [TX_CRDIF_WIDTH-1:0]       cxl_ll_mem_bi_gnt          // CXL.mem BI-Snoop/Response grant
);

// Parameter Declarations
localparam MEM   = 1'b1;
localparam CACHE = 1'b0;
localparam MEM_NDR_CHNUM = 1;// `ifdef CX_CXL_MEM_SHARED_CREDIT + 1 `endif;

logic                            rsvd_mem_crd_enc_error  ;
logic                            rsvd_cache_crd_enc_error;

logic s_rsvd_cache_data_crd_enc_error;
logic s_rsvd_cache_rsp_crd_enc_error;
logic s_rsvd_cache_req_crd_enc_error;

assign rsvd_cache_crd_enc_error = s_rsvd_cache_data_crd_enc_error || s_rsvd_cache_rsp_crd_enc_error || s_rsvd_cache_req_crd_enc_error;
logic s_rsvd_mem_ndr_crd_enc_error  ;
logic s_rsvd_mem_data_crd_enc_error ;
logic s_rsvd_mem_bi_crd_enc_error   ;
assign rsvd_mem_crd_enc_error = s_rsvd_mem_ndr_crd_enc_error|| s_rsvd_mem_data_crd_enc_error || s_rsvd_mem_bi_crd_enc_error;

assign rsvd_crd_enc_error = 1'b0 || rsvd_mem_crd_enc_error || rsvd_cache_crd_enc_error;

logic [(MEM_NDR_CHNUM*FLIT_CRD_WD)-1:0]    cxl_rx_ndr_crd;      // CXL.mem response/request received credit returns (68B Flit)

// Root-Complex receives M2S Request credits with ReqCrd field in the Flit Header
// Endpoint receives S2M Response credits with RspCrd field in the Flit Header
assign cxl_rx_ndr_crd    = cxl_device_mode ? ( cxl_rx_req_crd   ) : cxl_rx_rsp_crd;

logic [4:0]                cxl_rx_ndr_crd_256B; // CXL.mem M2S Request/S2M Response received credit returns (256B Flit)

// Root-Complex receives M2S Request credits with CRD_A field in the 2B CRD
// Endpoint receives S2M Response credits with CRD_C field in the 2B RD
assign cxl_rx_ndr_crd_256B = cxl_device_mode ? cxl_256B_rx_crdret.CRD_A : cxl_256B_rx_crdret.CRD_C;

DWC_cxl_mem_cache_fc_cnt
 #(
    .PROT  (MEM),
    .CHNUM (MEM_NDR_CHNUM)
) u_mem_req_rsp_crdcnt ( 
    .core_clk             ( core_clk                     ),
    .core_rst_n           ( core_rst_n                   ),
    .cfg_enable_i         ( cfg_mem_enable               ),
    .tx_msg_vld_i         ( cxl_mem_ndr_valid            ),
    .rx_crd_ret_i         ( cxl_rx_ndr_crd               ),
    .cxl_device_mode      ( cxl_device_mode              ),
    .cxl_pcie_flit_mode   ( cxl_pcie_flit_mode           ),
    .rx_crd_ret_256B_i    ( cxl_rx_ndr_crd_256B          ),
    .rsvd_crd_enc_error_o ( s_rsvd_mem_ndr_crd_enc_error ),
    .fc_crd_o             ( cxl_ll_mem_ndr_crd           ),
    .fc_gnt_o             ( cxl_ll_mem_ndr_gnt           )
);

logic [4:0]                cxl_rx_bi_crd_256B; // CXL.mem BI-Snoop/Response received credit returns (256B Flit)

// Root-Complex receives M2S BI-Response credits with CRD_C field in the 2B CRD
// Endpoint receives S2M BI-Snoop credits with CRD_A field in the 2B RD
assign cxl_rx_bi_crd_256B = cxl_device_mode ? cxl_256B_rx_crdret.CRD_C : cxl_256B_rx_crdret.CRD_A;

DWC_cxl_mem_cache_fc_cnt
 #(
    .PROT (MEM)
) u_mem_bi_crdcnt ( 
    .core_clk             ( core_clk                        ),
    .core_rst_n           ( core_rst_n                      ),
    .cfg_enable_i         ( cfg_mem_enable                  ),
    .tx_msg_vld_i         ( cxl_mem_bi_valid                ),
    .rx_crd_ret_i         ( '0                              ),
    .cxl_device_mode      ( cxl_device_mode                 ),
    .cxl_pcie_flit_mode   ( cxl_pcie_flit_mode              ),
    .rx_crd_ret_256B_i    ( cxl_rx_bi_crd_256B              ),
    .rsvd_crd_enc_error_o ( s_rsvd_mem_bi_crd_enc_error     ),
    .fc_crd_o             ( cxl_ll_mem_bi_crd               ),
    .fc_gnt_o             ( cxl_ll_mem_bi_gnt               )
);

DWC_cxl_mem_cache_fc_cnt
 #(
    .PROT (MEM)
) u_mem_data_crdcnt ( 
    .core_clk             ( core_clk                      ),
    .core_rst_n           ( core_rst_n                    ),
    .cfg_enable_i         ( cfg_mem_enable                ),
    .tx_msg_vld_i         ( cxl_mem_data_valid            ),
    .rx_crd_ret_i         ( cxl_rx_data_crd               ),
    .cxl_device_mode      ( cxl_device_mode               ),
    .cxl_pcie_flit_mode   ( cxl_pcie_flit_mode            ),
    .rx_crd_ret_256B_i    ( cxl_256B_rx_crdret.CRD_B      ),
    .rsvd_crd_enc_error_o ( s_rsvd_mem_data_crd_enc_error ),
    .fc_crd_o             ( cxl_ll_mem_data_crd           ),
    .fc_gnt_o             ( cxl_ll_mem_data_gnt           )
);

DWC_cxl_mem_cache_fc_cnt
 #(
    .PROT (CACHE)
) u_cache_req_crdcnt ( 
    .core_clk             ( core_clk                       ),
    .core_rst_n           ( core_rst_n                     ),
    .cfg_enable_i         ( cfg_cache_enable               ),
    .tx_msg_vld_i         ( cxl_cache_req_valid            ),
    .rx_crd_ret_i         ( cxl_rx_req_crd                 ),
    .cxl_device_mode      ( cxl_device_mode                ),
    .cxl_pcie_flit_mode   ( cxl_pcie_flit_mode             ),
    .rx_crd_ret_256B_i    ( cxl_256B_rx_crdret.CRD_A       ),
    .rsvd_crd_enc_error_o ( s_rsvd_cache_req_crd_enc_error ),
    .fc_crd_o             ( cxl_ll_cache_req_crd           ),
    .fc_gnt_o             ( cxl_ll_cache_req_gnt           )
);

DWC_cxl_mem_cache_fc_cnt
 #(
    .PROT (CACHE)
) u_cache_rsp_crdcnt ( 
    .core_clk             ( core_clk                       ),
    .core_rst_n           ( core_rst_n                     ),
    .cfg_enable_i         ( cfg_cache_enable               ),
    .tx_msg_vld_i         ( cxl_cache_rsp_valid            ),
    .rx_crd_ret_i         ( cxl_rx_rsp_crd                 ),
    .cxl_device_mode      ( cxl_device_mode                ),
    .cxl_pcie_flit_mode   ( cxl_pcie_flit_mode             ),
    .rx_crd_ret_256B_i    ( cxl_256B_rx_crdret.CRD_C       ),
    .rsvd_crd_enc_error_o ( s_rsvd_cache_rsp_crd_enc_error ),
    .fc_crd_o             ( cxl_ll_cache_rsp_crd           ),
    .fc_gnt_o             ( cxl_ll_cache_rsp_gnt           ) 
);

DWC_cxl_mem_cache_fc_cnt
 #(
    .PROT (CACHE)
) u_cache_data_crdcnt ( 
    .core_clk             ( core_clk                        ),
    .core_rst_n           ( core_rst_n                      ),
    .cfg_enable_i         ( cfg_cache_enable                ),
    .tx_msg_vld_i         ( cxl_cache_data_valid            ),
    .rx_crd_ret_i         ( cxl_rx_data_crd                 ),
    .cxl_device_mode      ( cxl_device_mode                 ),
    .cxl_pcie_flit_mode   ( cxl_pcie_flit_mode              ),
    .rx_crd_ret_256B_i    ( cxl_256B_rx_crdret.CRD_B        ),
    .rsvd_crd_enc_error_o ( s_rsvd_cache_data_crd_enc_error ),
    .fc_crd_o             ( cxl_ll_cache_data_crd           ),
    .fc_gnt_o             ( cxl_ll_cache_data_gnt           )
);

endmodule
