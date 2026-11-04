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

// ---------------------------------------------------------------------------------------
// ---  RCS information:
// ---    $DateTime: 2024/01/12 11:11:14 $
// ---    $Revision: #8 $
// ---    $Id: //dwh/pcie_iip/main/fairbanks/design/Axi/DWC_pcie_axi_gm_mcb_arb.sv#8 $
// ---------------------------------------------------------------------------------------
// Module Description:
// Master Completion Buffer response interface multiplexing
// ---------------------------------------------------------------------------------------
`include "include/DWC_pcie_ctl_all_defs.svh"

 
 module DWC_pcie_axi_gm_mcb_arb
  #(
    parameter RESP_MISC_INFO_WD = `MSTR_RESP_MISC_INFO_WD,
    parameter TX_TLP_PREFIX_WD  = (32*`CX_NPRFX)+ `CX_PRFX_PAR_WD,
    parameter AXI_ID_WIDTH      = `CC_MAX_MSTR_TAG_PW,
    parameter AXI_STRB_WIDTH    = `CC_MSTR_BUS_WSTRB_WIDTH,
    parameter AXI_DATA_WIDTH    = `CC_MSTR_BUS_DATA_WIDTH,
    // -------------------------------------------------------------------------------------
    // Parameters not modified by an instantiation parameter assignment
    // -------------------------------------------------------------------------------------
    parameter TP       = 0.1

    )
   
                                 (
    input                              clk,
    input                              rstn,

    input                              wrq_svalid,
    input                              wrq_slast,
    input [RESP_MISC_INFO_WD-1:0]      wrq_smisc_info,
    input [2:0]                        wrq_sresp,
    input [`DC_CPL_STATUS_WD-1:0]      wrq_smisc_info_cpl_stat,
    input [AXI_ID_WIDTH-1:0]           wrq_sid,
    input [AXI_STRB_WIDTH -1:0]        wrq_sbyte_en,
    output reg                         wrq_mready,

    input                              rdq_svalid,
    input [AXI_DATA_WIDTH-1:0]         rdq_sdata,
    input                              rdq_slast,
    input [RESP_MISC_INFO_WD-1:0]      rdq_smisc_info,
    input [2:0]                        rdq_sresp,
    input [`DC_CPL_STATUS_WD-1:0]      rdq_smisc_info_cpl_stat,
    input [AXI_ID_WIDTH-1:0]           rdq_sid,
    input [AXI_STRB_WIDTH -1:0]        rdq_sbyte_en,
    output reg                         rdq_mready,

    output logic                         svalid,
    output logic                         slast,
    output logic [AXI_DATA_WIDTH-1:0]    sdata,
    output logic [RESP_MISC_INFO_WD-1:0] smisc_info,
    output logic [2:0]                   sresp,
    output logic [`DC_CPL_STATUS_WD-1:0] smisc_info_cpl_stat,
    output logic [AXI_ID_WIDTH-1:0]      sid,
    output logic [AXI_STRB_WIDTH -1:0]   sbyte_en,
    input                                mready
    );

   localparam [8:0] AXI_DATA_INIT_BYTE = `CX_RAS_PARITY_MODE ? 9'b100000000 : 9'b000000000;
   localparam       AXI_BYTE_LEN = 9;


   localparam AXI_DATA_N_BYTES   = `MASTER_BUS_DATA_WIDTH/8;

   always @ ( * ) begin : PROC_comb_sel_read_write
      integer i,j;
      if (wrq_svalid) begin
         wrq_mready = mready ;
         rdq_mready = 1'b0;
         svalid     = wrq_svalid    ;
         slast      = wrq_slast     ;
         smisc_info = wrq_smisc_info;
         sresp      = wrq_sresp;
         smisc_info_cpl_stat = wrq_smisc_info_cpl_stat;
         sid      = wrq_sid;
         sbyte_en =  wrq_sbyte_en;

      end else begin // if (r_wrq_sel)

         wrq_mready = 1'b0;
         rdq_mready = mready;

         svalid     = rdq_svalid    ;
         slast      = rdq_slast     ;
         smisc_info = rdq_smisc_info;
         sbyte_en = rdq_sbyte_en;
         sresp    = rdq_sresp;
         smisc_info_cpl_stat = rdq_smisc_info_cpl_stat;
         sid      = rdq_sid;

      end
   end


   logic [AXI_STRB_WIDTH-1:0][AXI_BYTE_LEN-1:0] rdq_sdata_sliced;
   logic [AXI_STRB_WIDTH-1:0][AXI_BYTE_LEN-1:0] sdata_sliced    ;
   assign rdq_sdata_sliced = rdq_sdata   ;
   assign sdata            = sdata_sliced;
   always_comb begin : sdata_sliced_PROC
     foreach (sdata_sliced[i]) begin
       if (rdq_sbyte_en[i] && !wrq_svalid) begin
         sdata_sliced[i] = rdq_sdata_sliced[i];
       end else begin
         sdata_sliced[i] = AXI_DATA_INIT_BYTE;
       end
     end
   end


endmodule


