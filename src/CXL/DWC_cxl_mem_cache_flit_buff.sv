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
// ---    $DateTime: 2024/01/19 09:25:58 $
// ---    $Revision: #4 $
// ---    $Id: //dwh/pcie_iip/main/fairbanks/design/CXL/DWC_cxl_mem_cache_flit_buff.sv#4 $
// -------------------------------------------------------------------------
// --- Module Description: CXL Flit receive buffer that aligns RPLH
// --- sub-set of SPIF interface signals to the Link Layer datapath width
// -----------------------------------------------------------------------------

`include "include/DWC_pcie_ctl_all_defs.svh"
`include "CXL/pkg/DWC_cxl_pkg.svh"
`include "CXL/svif/DWC_cxl_arb_llctrl_if.svh"
// SPIF Interface
`include "Spif/pkg/spif_pkg.svh"
`include "Spif/svif/spif_if.svh"
 
module DWC_cxl_mem_cache_flit_buff
    import spif_pkg::SID_CXL_CM;
    import spif_pkg::SID_RSVD;
    import spif_pkg::SPIF_NBYTES;
    import spif_pkg::protocol_cfg_t;
    import DWC_cxl_pkg::CXL_DATA_WD; 
    import DWC_cxl_pkg::CXL_DATA_NBYTES; 
    import DWC_cxl_pkg::ARBMUX_FLIT_WD; 
    import DWC_cxl_pkg::ARBMUX_68B_FLIT_WD; 
    import DWC_cxl_pkg::ARBMUX_DATA_WD; 
    import DWC_cxl_pkg::CXL_DATA_PROT_WD; 
    import DWC_cxl_pkg::ARBMUX_68B_DATA_WD; 

#(
    parameter TP                     = `TP                    // Clock to Q delay (simulator insurance)
) (
    // Interfaces
    spif_if.rplh_slave_mp                  b_rplh_spif     ,  // RPLH SPIF Interface
    // Inputs     
    input                                  core_clk        ,  // Core Clock
    input                                  core_rst_n      ,  // Core Reset
    input protocol_cfg_t                   cxl_protocol_cfg,  // CXL protocol CFG
    // Outputs
    DWC_cxl_arb_llctrl_if.master_rx_mp     b_rx_arb_llctrl
);

// Latency opt flit size 
localparam LOPT_FLIT_SIZE             = 1024;
localparam LOPT_DATAPATH_RATIO        = LOPT_FLIT_SIZE/CXL_DATA_WD;
localparam LOPT_PROT_SIZE             = CXL_DATA_PROT_WD * LOPT_DATAPATH_RATIO;
// STD  flit size 
localparam STD_FLIT_SIZE             = 2048;
localparam STD_DATAPATH_RATIO        = STD_FLIT_SIZE/CXL_DATA_WD;
localparam STD_PROT_SIZE             = CXL_DATA_PROT_WD * STD_DATAPATH_RATIO;



// -------------------------------------------------------------------------------------
// Flit Streaming Data Path (post-FEC)
// -------------------------------------------------------------------------------------

// The streaming datapath consists of 2 main path 
// 1- for 68B and STD 256B flit modes without accumulation (Non UCIe mode):
// in this mode, we need only to accumulate the RX data to match the link layer width (512 bits or larger)
// 2- For lopt Mode and re-ordering the flit is required (native configs): In this mode, we need to add another 
// accumulation logic in case the CXL Datapath is less than 1024 bits to accumulate the Datapath to 1024 to re-order the Lopt RX flit

logic                           stream_buff_enable       ; // Streaming buffer enable signal
logic                           stream_buff_flit_valid   ; // Streaming buffer data valid output
logic [CXL_DATA_WD-1   :0]      stream_buff_flit_data    ; // Streaming buffer data 
logic [CXL_DATA_PROT_WD-1  :0]  stream_buff_flit_data_chk; // Streaming buffer data check
logic                           stream_buff_crc_valid    ; // Streaming buffer CRC valid
logic [15:0]                    stream_buff_crc_data     ; // Streaming buffer CRC data

// Always enable streaming buffer unless the s_pl_flit_acc is asserted 

  always_comb begin 
    stream_buff_enable = 
        1'b1
;
  end

// accumulate the RX Data to CXL_DATA_WD
rplh_flit_buff
 #(
    .LL_NBYTES          ( CXL_DATA_NBYTES                     ), // Link Layer data width in bytes
    .FLIT_WIDTH         ( CXL_DATA_WD                         ), // Link Layer data width
    .FLUSH_ENABLE       ( 1                                   ), // Enable flushing of the buffer, for 68B flit mode
    .FLIT_OUT_REG       ( 0                                   )  // No reg out needed (Post FEC)
) u_stream_flit_buff (                                               
    // Interfaces                                             
    .b_rplh_spif        ( b_rplh_spif                         ),
    // Inputs                                                 
    .core_clk           ( core_clk                            ),
    .core_rst_n         ( core_rst_n                          ),
    .pcie_flit_mode     ( cxl_protocol_cfg.cxl_pcie_flit_mode ),
    .rplh_buff_enable   ( stream_buff_enable                  ),
    // Outputs                                                
    .rx_flit_valid      ( stream_buff_flit_valid              ),
    .rx_flit_data       ( stream_buff_flit_data               ),
    .rx_flit_data_chk   ( stream_buff_flit_data_chk           ),
    .rx_crc_valid       ( stream_buff_crc_valid               ),
    .rx_crc_data        ( stream_buff_crc_data                )
);

// In case Lopt reodering is required we need to accumlate 1024 bits of the flit
  
  
  // MUX Between STD and LOPT datapaths in the streaming mode
  logic                           stream_flit_valid   ; // Mux between stream lopt valid and stream buff valid
  logic [CXL_DATA_WD-1   :0]      stream_flit_data    ; // Mux between stream lopt data  and stream buff data
  logic [CXL_DATA_PROT_WD-1  :0]  stream_flit_data_chk; // Mux between stream lopt data_chk and stream buff data_chk 
  logic                           stream_crc_valid    ; // Streaming buffer CRC valid
  logic [15:0]                    stream_crc_data     ; // Streaming buffer CRC data

  always_comb begin 
      stream_flit_valid      = stream_buff_flit_valid;
      stream_flit_data       = stream_buff_flit_data;
      stream_flit_data_chk   = stream_buff_flit_data_chk;
    stream_crc_valid       = stream_buff_crc_valid; 
    stream_crc_data        = stream_buff_crc_data ;
  end

 
 


  // Note accu_flit_valid & stream_flit_valid are mutually exclusive
  always_comb begin
  
  b_rx_arb_llctrl.s_cxl_arb_mem_cache_valid    = '0;
  b_rx_arb_llctrl.s_cxl_arb_mem_cache_data     = '0;
  b_rx_arb_llctrl.s_cxl_arb_mem_cache_data_chk = '0;
    b_rx_arb_llctrl.s_cxl_arb_mem_cache_valid    |= stream_flit_valid && ( cxl_protocol_cfg.cxl_pcie_flit_mode ? 1'b1 : stream_crc_valid);
    b_rx_arb_llctrl.s_cxl_arb_mem_cache_data     |= cxl_protocol_cfg.cxl_pcie_flit_mode ? {{(ARBMUX_FLIT_WD-ARBMUX_DATA_WD){1'b0}},stream_flit_data} : {{(ARBMUX_FLIT_WD-ARBMUX_68B_FLIT_WD){1'b0}},stream_crc_data, stream_flit_data[ARBMUX_68B_DATA_WD-1:0]};
    b_rx_arb_llctrl.s_cxl_arb_mem_cache_data_chk |= stream_flit_data_chk;

    if (stream_flit_valid) begin 
      b_rx_arb_llctrl.s_cxl_arb_mem_cache_valid    |= stream_flit_valid && ( cxl_protocol_cfg.cxl_pcie_flit_mode ? 1'b1 : stream_crc_valid);
      b_rx_arb_llctrl.s_cxl_arb_mem_cache_data     |= cxl_protocol_cfg.cxl_pcie_flit_mode ? {{(ARBMUX_FLIT_WD-ARBMUX_DATA_WD){1'b0}},stream_flit_data} : {{(ARBMUX_FLIT_WD-ARBMUX_68B_FLIT_WD){1'b0}},stream_crc_data, stream_flit_data[ARBMUX_68B_DATA_WD-1:0]};
      b_rx_arb_llctrl.s_cxl_arb_mem_cache_data_chk |= stream_flit_data_chk;
    end 
  end  


endmodule // DWC_cxl_mem_cache_flit_buff

