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
// ---    $DateTime: 2023/04/29 12:35:01 $
// ---    $Revision: #4 $
// ---    $Id: //dwh/pcie_iip/main/fairbanks/design/Bridge/inbound/DWC_pcie_bridge_ib_wr_dcmp.sv#4 $
// -------------------------------------------------------------------------

// -----------------------------------------------------------------------------
// --- Module Description:
// -----------------------------------------------------------------------------
//  The major funcions:
//  This module converts a core TRGT1 interface to GIF interface of a master AXI
//  1. a FIFO for data and header of a memrd/wr transaction that core receive to provide
//     a non-blocking architecture between core and one AXI master. Other Master can get traffic through
//  2. This FIFO also does the clock domain crossing between AXI clock and core clk. Only core clk runs less than AXI clock is supported
//  3. GIF interface control as a master is done in this block. A memRd/Wr received by core will be translated into GIF master trnasaction
//     to output to DWC GIF master module
//  4. Pipelined request transactions and response transactions are supported as long as inorder services is maintain.
//     No AXI out of order services are supported
//  5. A FIFO for header information of a memRd is designed in the block to handle completion type of request generated to core
//     When a response
//
//  Limitations:
//  1. only dword aligned address is supported
//  2. Each read/write received by core will be within one burst of the AXI transfer
//  3. Only support core data path width and AXI data path width to be the same
// -----------------------------------------------------------------------------

`include "include/DWC_pcie_ctl_all_defs.svh"
`include "DWC_pcie_ctl_pkg.svh"

 module DWC_pcie_bridge_ib_wr_dcmp
  import DWC_pcie_ctl_pkg::ras_dp_err_log_t;
  import DWC_pcie_ctl_pkg::ras_dp_err_inj_t;
 (

    in_clk,
    in_rst_n,
    
    // Request packet interface
    dcmp_pkt_halt,
    req_pkt_hv,
    req_pkt_dv,
    req_pkt_eot,
    req_pkt_hdr,
    req_pkt_addr,
    req_pkt_data,
    req_pkt_byte_en,
    req_pkt_byte_len,
    req_pkt_func_num,
    req_pkt_out_tag,
    req_pkt_fmt,
    req_pkt_type,

    dwnstrm_pkt_halt,
    dcmp_pkt_hv,
    dcmp_pkt_dv,
    dcmp_pkt_eot,
    dcmp_pkt_hdr,
    dcmp_pkt_addr,
    dcmp_pkt_data,
    dcmp_pkt_byte_en,
    dcmp_pkt_byte_len,
    dcmp_pkt_req_byte_len,
    dcmp_pkt_func_num,
    dcmp_pkt_out_tag,
    dcmp_pkt_ncbe,
    dcmp_pkt_last_tlp,
    dcmp_pkt_low_addr,
    dcmp_pkt_np_tlp_issued
    
    ,dcmp_addr_parerr
    ,dcmp_data_parerr
    ,dcmp_dt_ras_dp_err_log
    ,dcmp_ad_ras_dp_err_log
    ,axi_bridge_ras_dp_err_inj_core_clk
   );
                         
// Parameters depending on decomposer usage (inbound vs outbound, posted vs non-posted)
// ---------------------------------------------------------------------------------------------------------------------
parameter  PKT_OUT_TAG_WD                = 4;
parameter  NW                            = 1;                  
parameter  NF                            = 1;
parameter  PKT_HDR_WD                    = 156;
parameter  PKT_ADDR_WD                   = 64;
parameter  IN_PKT_DATA_WD                = 32;
parameter  OUT_PKT_DATA_WD               = 64;
parameter  PKT_BYTE_LEN_IN_WD            = 13;
parameter  PKT_BYTE_LEN_OUT_WD           = 13;
parameter  PF_WD                         = 1;
parameter  PAGE_BOUNDARY_BIT             = 13;                           // power of 2 of address boundary uncrossable + 1.
parameter  PKT_LOW_ADDR_WD               = 16;
parameter  TP                            = `TP;


// Port declaration
// ---------------------------------------------------------------------------------------------------------------------
input  wire                                  in_clk;                       // Inbound and outbound direction
input  wire                                  in_rst_n;                     // Inbound and outbound direction
    
    // Request packet interface
output wire                                  dcmp_pkt_halt;
input  wire                                  req_pkt_hv;
input  wire                                  req_pkt_dv;
input  wire                                  req_pkt_eot;
input  wire [PKT_HDR_WD -1:0]                req_pkt_hdr;
input  wire [PKT_ADDR_WD -1:0]               req_pkt_addr;
input  wire [IN_PKT_DATA_WD -1:0]            req_pkt_data;
input  wire [7:0]                            req_pkt_byte_en;
input  wire [PKT_BYTE_LEN_IN_WD -1 :0]       req_pkt_byte_len;
input  wire [PF_WD-1:0]                      req_pkt_func_num;
input  wire [PKT_OUT_TAG_WD-1:0]             req_pkt_out_tag;
input  wire [1:0]                            req_pkt_fmt;
input  wire [4:0]                            req_pkt_type;

input  wire                                  dwnstrm_pkt_halt;
output wire                                  dcmp_pkt_hv;
output wire                                  dcmp_pkt_dv;
output wire                                  dcmp_pkt_eot;
output wire [PKT_HDR_WD -1:0]                dcmp_pkt_hdr;
output wire [PKT_ADDR_WD -1:0]               dcmp_pkt_addr;
output wire [OUT_PKT_DATA_WD -1:0]           dcmp_pkt_data;
output wire [7:0]                            dcmp_pkt_byte_en;
output wire [PKT_BYTE_LEN_OUT_WD -1:0]       dcmp_pkt_byte_len;
output wire [PKT_BYTE_LEN_IN_WD -1:0]        dcmp_pkt_req_byte_len;
output wire [PF_WD -1:0]                     dcmp_pkt_func_num;
output wire [PKT_OUT_TAG_WD -1:0]            dcmp_pkt_out_tag;
output wire                                  dcmp_pkt_ncbe;                // Inbound direction only
output wire                                  dcmp_pkt_last_tlp;            // Outbound direction only
output wire [PKT_LOW_ADDR_WD -1:0]           dcmp_pkt_low_addr;
output wire                                  dcmp_pkt_np_tlp_issued;

output wire                                  dcmp_addr_parerr;
output wire                                  dcmp_data_parerr;
output ras_dp_err_log_t                      dcmp_dt_ras_dp_err_log;
output ras_dp_err_log_t                      dcmp_ad_ras_dp_err_log;
input  ras_dp_err_inj_t                      axi_bridge_ras_dp_err_inj_core_clk;

// In queue output wire declaration
// ---------------------------------------------------------------------------------------------------------------------
wire                          s_req_pkt_hv;       //dv coming from upconverter
wire                          s_req_pkt_dv;       //dv coming from upconverter
wire                          s_req_pkt_eot;    //eot coming from upconverter
wire [OUT_PKT_DATA_WD-1:0]    s_req_pkt_data;   //data coming from upconverter

assign s_req_pkt_data  = req_pkt_data;
assign s_req_pkt_hv    = req_pkt_hv;
assign s_req_pkt_dv    = req_pkt_dv;
assign s_req_pkt_eot   = req_pkt_eot;

// Input queue instantiation
// ---------------------------------------------------------------------------------------------------------------------
DWC_pcie_bridge_ib_wr_dcmp_inq

  #(
    .NW                       ( NW                          ),
    .PKT_HDR_WD               ( PKT_HDR_WD                  ),
    .PKT_ADDR_WD              ( PKT_ADDR_WD                 ),
    .PKT_DATA_WD              ( OUT_PKT_DATA_WD             ),
    .PKT_BYTE_LEN_IN_WD       ( PKT_BYTE_LEN_IN_WD          ),
    .PKT_BYTE_LEN_OUT_WD      ( PKT_BYTE_LEN_OUT_WD         ),
    .PKT_OUT_TAG_WD           ( PKT_OUT_TAG_WD              ),
    .PKT_LOW_ADDR_WD          ( PKT_LOW_ADDR_WD             ),
    .PAGE_BOUNDARY_BIT        ( PAGE_BOUNDARY_BIT           )
   )
   u_inq
   ( 
    .in_clk                   ( in_clk                      ),
    .in_rst_n                 ( in_rst_n                    ),
    
    // Request packet interface
    .inq_pkt_halt             ( dcmp_pkt_halt               ),
    .req_pkt_hv               ( s_req_pkt_hv                ),
    .req_pkt_dv               ( s_req_pkt_dv                ),
    .req_pkt_eot              ( s_req_pkt_eot               ),
    .req_pkt_hdr              ( req_pkt_hdr                 ),
    .req_pkt_addr             ( req_pkt_addr                ),
    .req_pkt_data             ( s_req_pkt_data              ),
    .req_pkt_byte_en          ( req_pkt_byte_en             ),
    .req_pkt_byte_len         ( req_pkt_byte_len            ),
    .req_pkt_func_num         ( req_pkt_func_num            ),
    .req_pkt_fmt              ( req_pkt_fmt                 ),
    .req_pkt_type             ( req_pkt_type                ),
    
    .dwnstrm_pkt_halt         ( dwnstrm_pkt_halt            ),
    .inq_pkt_hv               ( dcmp_pkt_hv                 ),
    .inq_pkt_dv               ( dcmp_pkt_dv                 ),
    .inq_pkt_eot              ( dcmp_pkt_eot                ),
    .inq_pkt_hdr              ( dcmp_pkt_hdr                ),
    .inq_pkt_addr             ( dcmp_pkt_addr               ),
    .inq_pkt_data             ( dcmp_pkt_data               ),
    .inq_pkt_byte_en          ( dcmp_pkt_byte_en            ),
    .inq_pkt_byte_len         ( dcmp_pkt_byte_len           ),
    .inq_pkt_req_byte_len     ( dcmp_pkt_req_byte_len       ),
    .inq_pkt_func_num         ( dcmp_pkt_func_num           ),
    .inq_pkt_out_tag          ( dcmp_pkt_out_tag            ),
    .inq_pkt_ncbe             ( dcmp_pkt_ncbe               ),
    .inq_pkt_last_tlp         ( dcmp_pkt_last_tlp           ),
    .inq_pkt_low_addr         ( dcmp_pkt_low_addr           ),
    .inq_pkt_np_tlp_issued    ( dcmp_pkt_np_tlp_issued      ),
    
    .dcmp_addr_parerr         ( dcmp_addr_parerr            ),
    .dcmp_data_parerr         (dcmp_data_parerr             ),
    .dcmp_dt_ras_dp_err_log   ( dcmp_dt_ras_dp_err_log      ),
    .dcmp_ad_ras_dp_err_log   ( dcmp_ad_ras_dp_err_log      ),
    .axi_bridge_ras_dp_err_inj_core_clk (axi_bridge_ras_dp_err_inj_core_clk),

    // Tag management interface
    .req_pkt_out_tag          ( req_pkt_out_tag             )
   );

endmodule

