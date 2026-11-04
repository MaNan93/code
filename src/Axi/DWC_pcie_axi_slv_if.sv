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
// ---    $DateTime: 2023/12/22 07:15:34 $
// ---    $Revision: #4 $
// ---    $Id: //dwh/pcie_iip/main/fairbanks/design/Axi/DWC_pcie_axi_slv_if.sv#4 $
// -------------------------------------------------------------------------

`include "include/DWC_pcie_ctl_all_defs.svh"

`include "Axi/DWC_pcie_axi_slv_pkg.svh"

`include "Axi/svif/DWC_pcie_axi_slv_ar_if.svh"
`include "Axi/svif/DWC_pcie_axi_slv_aw_if.svh"
`include "Axi/svif/DWC_pcie_axi_slv_w_if.svh"
`include "Axi/svif/DWC_pcie_axi_slv_r_if.svh"
`include "Axi/svif/DWC_pcie_axi_slv_b_if.svh"
`include "Axi/svif/DWC_pcie_axi_dpram_if.svh"
`include "DWC_pcie_ctl_pkg.svh"

module DWC_pcie_axi_slv_if
import DWC_pcie_axi_slv_pkg::*;
  import DWC_pcie_ctl_pkg::ras_dp_err_log_t;
  import DWC_pcie_ctl_pkg::MAX_RAS_PROT_CHK_N;
  import DWC_pcie_ctl_pkg::ras_dp_err_inj_t;
  #(
    parameter CC_SLV_NUM_OUTSTND_WR_REQ       = `CC_SLV_NUM_OUTSTND_WR_REQ,
    parameter CC_SLV_NUM_OUTSTND_WR_REQ_LOG2  = `CC_SLV_NUM_OUTSTND_WR_REQ_LOG2,
    parameter CC_MAX_SLV_TAG_PW               = `CC_MAX_SLV_TAG_PW,
    parameter CX_RAS_RAM_PROT_RANGE           = `CX_RAS_RAM_PROT_RANGE,
    parameter CX_RAS_PROT_RANGE               = `CX_RAS_PROT_RANGE,
    parameter CX_RAS_PARITY_MODE              = `CX_RAS_PARITY_MODE,
    parameter SLAVE_BUS_ADDR_WIDTH            = `SLAVE_BUS_ADDR_WIDTH,
    parameter SLAVE_BUS_DATA_WIDTH            = `SLAVE_BUS_DATA_WIDTH,
    parameter CC_SLV_BUS_ADDR_WIDTH           = `CC_SLV_BUS_ADDR_WIDTH,
    parameter CC_SLV_BUS_DATA_WIDTH           = `CC_SLV_BUS_DATA_WIDTH,
    parameter CC_SLV_CDC_AR_RAM_DATA_WD_NOECC = `CC_SLV_CDC_AR_RAM_DATA_WD_NOECC,
    parameter CC_SLV_CDC_AW_RAM_DATA_WD_NOECC = `CC_SLV_CDC_AW_RAM_DATA_WD_NOECC,
    parameter CC_SLV_CDC_W_RAM_DATA_WD_NOECC  = `CC_SLV_CDC_W_RAM_DATA_WD_NOECC,
    parameter CC_SLV_CDC_R_RAM_DATA_WD_NOECC  = `CC_SLV_CDC_R_RAM_DATA_WD_NOECC,
    parameter CC_SLV_CDC_B_RAM_DATA_WD_NOECC  = `CC_SLV_CDC_B_RAM_DATA_WD_NOECC,
    parameter CC_SLV_CDC_AR_RAM_DATA_WD       = `CC_SLV_CDC_AR_RAM_DATA_WD,
    parameter CC_SLV_CDC_AR_RAM_DP            = `CC_SLV_CDC_AR_RAM_DP,
    parameter CC_SLV_CDC_AR_RAM_ADDR_WD       = `CC_SLV_CDC_AR_RAM_ADDR_WD,
    parameter CC_SLV_CDC_AR_RAM_PTR_WD        = `CC_SLV_CDC_AR_RAM_PTR_WD,
    parameter CC_SLV_CDC_AR_RAM_RD_LATENCY    = `CC_SLV_CDC_AR_RAM_RD_LATENCY,
    parameter CC_SLV_CDC_AW_RAM_DATA_WD       = `CC_SLV_CDC_AW_RAM_DATA_WD,
    parameter CC_SLV_CDC_AW_RAM_DP            = `CC_SLV_CDC_AW_RAM_DP,
    parameter CC_SLV_CDC_AW_RAM_ADDR_WD       = `CC_SLV_CDC_AW_RAM_ADDR_WD,
    parameter CC_SLV_CDC_AW_RAM_PTR_WD        = `CC_SLV_CDC_AW_RAM_PTR_WD,
    parameter CC_SLV_CDC_AW_RAM_RD_LATENCY    = `CC_SLV_CDC_AW_RAM_RD_LATENCY,
    parameter CC_SLV_CDC_W_RAM_DATA_WD        = `CC_SLV_CDC_W_RAM_DATA_WD,
    parameter CC_SLV_CDC_W_RAM_DP             = `CC_SLV_CDC_W_RAM_DP,
    parameter CC_SLV_CDC_W_RAM_ADDR_WD        = `CC_SLV_CDC_W_RAM_ADDR_WD,
    parameter CC_SLV_CDC_W_RAM_PTR_WD         = `CC_SLV_CDC_W_RAM_PTR_WD,
    parameter CC_SLV_CDC_W_RAM_RD_LATENCY     = `CC_SLV_CDC_W_RAM_RD_LATENCY,
    parameter CC_SLV_CDC_R_RAM_DATA_WD        = `CC_SLV_CDC_R_RAM_DATA_WD,
    parameter CC_SLV_CDC_R_RAM_DP             = `CC_SLV_CDC_R_RAM_DP,
    parameter CC_SLV_CDC_R_RAM_ADDR_WD        = `CC_SLV_CDC_R_RAM_ADDR_WD,
    parameter CC_SLV_CDC_R_RAM_PTR_WD         = `CC_SLV_CDC_R_RAM_PTR_WD,
    parameter CC_SLV_CDC_R_RAM_RD_LATENCY     = `CC_SLV_CDC_R_RAM_RD_LATENCY,
    parameter CC_SLV_CDC_B_RAM_DATA_WD        = `CC_SLV_CDC_B_RAM_DATA_WD,
    parameter CC_SLV_CDC_B_RAM_DP             = `CC_SLV_CDC_B_RAM_DP,
    parameter CC_SLV_CDC_B_RAM_ADDR_WD        = `CC_SLV_CDC_B_RAM_ADDR_WD,
    parameter CC_SLV_CDC_B_RAM_PTR_WD         = `CC_SLV_CDC_B_RAM_PTR_WD,
    parameter CC_SLV_CDC_B_RAM_RD_LATENCY     = `CC_SLV_CDC_B_RAM_RD_LATENCY,
    parameter SYNC_DEPTH                      = `CX_PCIE_SYNC_DEPTH

   )
   (
     input                                         slv_aclk
    ,input                                         slv_aclk_ug
    ,input                                         slv_aresetn
    ,input                                         core_clk
    ,input                                         core_rst_n

    ,DWC_pcie_axi_slv_ar_if.slv_mp                 i_slv_ar
    ,DWC_pcie_axi_slv_aw_if.slv_mp                 i_slv_aw
    ,DWC_pcie_axi_slv_w_if.slv_mp                  i_slv_w
    ,DWC_pcie_axi_slv_r_if.slv_mp                  i_slv_r
    ,DWC_pcie_axi_slv_b_if.slv_mp                  i_slv_b
  
    ,DWC_pcie_axi_slv_ar_if.mstr_mp                o_slv_ar
    ,DWC_pcie_axi_slv_aw_if.mstr_mp                o_slv_aw
    ,DWC_pcie_axi_slv_w_if.mstr_mp                 o_slv_w
    ,DWC_pcie_axi_slv_r_if.mstr_mp                 o_slv_r
    ,DWC_pcie_axi_slv_b_if.mstr_mp                 o_slv_b

   );

localparam RAS_DP_ERR_LOG_WD = $clog2(MAX_RAS_PROT_CHK_N);
localparam NUM_ADDR_PAR_BLOCKS    = SLAVE_BUS_ADDR_WIDTH / `CX_RAS_PROT_RANGE;
localparam NUM_DATA_PAR_BLOCKS    = SLAVE_BUS_DATA_WIDTH / `CX_RAS_PROT_RANGE;


/*
    AXI Slave AR Channel CDC RAM
*/

assign o_slv_ar.valid                  = i_slv_ar.valid;
assign o_slv_ar.addr                   = i_slv_ar.addr;
assign o_slv_ar.id                     = i_slv_ar.id;
assign o_slv_ar.len                    = i_slv_ar.len;
assign o_slv_ar.size                   = i_slv_ar.size;
assign o_slv_ar.burst                  = i_slv_ar.burst;
assign o_slv_ar.misc_info_type         = i_slv_ar.misc_info_type;
assign o_slv_ar.misc_info_snp          = i_slv_ar.misc_info_snp;
assign o_slv_ar.misc_info_ns           = i_slv_ar.misc_info_ns;
assign o_slv_ar.misc_info_ro           = i_slv_ar.misc_info_ro;
assign o_slv_ar.misc_info_tc           = i_slv_ar.misc_info_tc;
assign o_slv_ar.misc_info_db           = i_slv_ar.misc_info_db;
assign o_slv_ar.misc_info_func_num     = i_slv_ar.misc_info_func_num;
assign o_slv_ar.misc_info_nw           = i_slv_ar.misc_info_nw;
assign o_slv_ar.misc_info_ats          = i_slv_ar.misc_info_ats;
assign o_slv_ar.misc_info_tlpprfx      = i_slv_ar.misc_info_tlpprfx;
assign o_slv_ar.misc_info_tph          = i_slv_ar.misc_info_tph;
assign o_slv_ar.misc_info_atu_bypass   = i_slv_ar.misc_info_atu_bypass;
assign o_slv_ar.misc_info_ido          = i_slv_ar.misc_info_ido;
assign o_slv_ar.misc_info_dst_segment  = i_slv_ar.misc_info_dst_segment;
assign i_slv_ar.ready                  = o_slv_ar.ready;

/*
    AXI Slave AW Channel CDC RAM
*/

assign o_slv_aw.valid                  = i_slv_aw.valid;
assign o_slv_aw.addr                   = i_slv_aw.addr;
assign o_slv_aw.id                     = i_slv_aw.id;
assign o_slv_aw.len                    = i_slv_aw.len;
assign o_slv_aw.size                   = i_slv_aw.size;
assign o_slv_aw.burst                  = i_slv_aw.burst;
assign o_slv_aw.atop                   = i_slv_aw.atop;
assign o_slv_aw.misc_info_type         = i_slv_aw.misc_info_type;
assign o_slv_aw.misc_info_snp          = i_slv_aw.misc_info_snp;
assign o_slv_aw.misc_info_ep           = i_slv_aw.misc_info_ep;
assign o_slv_aw.misc_info_ns           = i_slv_aw.misc_info_ns;
assign o_slv_aw.misc_info_ro           = i_slv_aw.misc_info_ro;
assign o_slv_aw.misc_info_tc           = i_slv_aw.misc_info_tc;
assign o_slv_aw.misc_info_msg_code     = i_slv_aw.misc_info_msg_code;
assign o_slv_aw.misc_info_db           = i_slv_aw.misc_info_db;
assign o_slv_aw.misc_info_func_num     = i_slv_aw.misc_info_func_num;
assign o_slv_aw.misc_info_nw           = i_slv_aw.misc_info_nw;
assign o_slv_aw.misc_info_ats          = i_slv_aw.misc_info_ats;
assign o_slv_aw.misc_info_tlpprfx      = i_slv_aw.misc_info_tlpprfx;
assign o_slv_aw.misc_info_p_tag        = i_slv_aw.misc_info_p_tag;
assign o_slv_aw.misc_info_tph          = i_slv_aw.misc_info_tph;
assign o_slv_aw.misc_info_atu_bypass   = i_slv_aw.misc_info_atu_bypass;
assign o_slv_aw.misc_info_ido          = i_slv_aw.misc_info_ido;
assign o_slv_aw.misc_info_dst_segment  = i_slv_aw.misc_info_dst_segment;
assign i_slv_aw.ready                  = o_slv_aw.ready;

/*
    AXI Slave W Channel CDC RAM
*/

assign o_slv_w.valid                   = i_slv_w.valid;
assign o_slv_w.data                    = i_slv_w.data;
assign o_slv_w.strb                    = i_slv_w.strb;
assign o_slv_w.last                    = i_slv_w.last;
assign o_slv_w.misc_info_ep            = i_slv_w.misc_info_ep;
assign o_slv_w.misc_info_silentDrop    = i_slv_w.misc_info_silentDrop;
assign i_slv_w.ready                   = o_slv_w.ready;

/*
    AXI Slave R Channel CDC RAM
*/

assign i_slv_r.valid                   = o_slv_r.valid;
assign i_slv_r.id                      = o_slv_r.id;
assign i_slv_r.timeout                 = o_slv_r.timeout;
assign i_slv_r.ep                      = o_slv_r.ep;
assign i_slv_r.tc                      = o_slv_r.tc;
assign i_slv_r.ns                      = o_slv_r.ns;
assign i_slv_r.ro                      = o_slv_r.ro;
assign i_slv_r.status                  = o_slv_r.status;
assign i_slv_r.cpl                     = o_slv_r.cpl;
assign i_slv_r.ido                     = o_slv_r.ido;
assign i_slv_r.dst_segment             = o_slv_r.dst_segment;
assign i_slv_r.cpl_segment             = o_slv_r.cpl_segment;
assign i_slv_r.resp                    = o_slv_r.resp;
assign i_slv_r.data                    = o_slv_r.data;
assign i_slv_r.last                    = o_slv_r.last;
assign o_slv_r.ready                   = i_slv_r.ready;

/*
    AXI Slave B Channel CDC RAM
*/

assign i_slv_b.valid                   = o_slv_b.valid;
assign i_slv_b.id                      = o_slv_b.id;
assign i_slv_b.resp                    = o_slv_b.resp;
assign i_slv_b.timeout                 = o_slv_b.timeout;
assign i_slv_b.ep                      = o_slv_b.ep;
assign i_slv_b.tc                      = o_slv_b.tc;
assign i_slv_b.ns                      = o_slv_b.ns;
assign i_slv_b.ro                      = o_slv_b.ro;
assign i_slv_b.status                  = o_slv_b.status;
assign i_slv_b.cpl                     = o_slv_b.cpl;
assign i_slv_b.dst_segment             = o_slv_b.dst_segment;
assign i_slv_b.cpl_segment             = o_slv_b.cpl_segment;
assign o_slv_b.ready                   = i_slv_b.ready;


  // -------------------------------------------------------------------------------------
  // Functions
  // -------------------------------------------------------------------------------------

  function automatic [SLAVE_BUS_ADDR_WIDTH-1:0] fn_addr_wo_par;
    input [CC_SLV_BUS_ADDR_WIDTH-1:0] s_addr_w_par;
    integer i,j;
    begin
      for (i=0; i<NUM_ADDR_PAR_BLOCKS; i=i+1)  begin // iterate thru parity block size
       for (j=0; j<CX_RAS_PROT_RANGE; j=j+1)  begin // iterate thru parity block size bits
          fn_addr_wo_par[i*CX_RAS_PROT_RANGE +j] = s_addr_w_par[i*CX_RAS_PROT_RANGE +j +i];
        end
      end
    end
  endfunction

// Data without parity
  function automatic [SLAVE_BUS_DATA_WIDTH-1:0] fn_data_wo_par;
    input [CC_SLV_BUS_DATA_WIDTH-1:0] s_data_w_par;
    integer i,j;
    begin
      for (i=0; i<NUM_DATA_PAR_BLOCKS; i=i+1)  begin // iterate thru parity block size
       for (j=0; j<CX_RAS_PROT_RANGE; j=j+1)  begin // iterate thru parity block size bits
          fn_data_wo_par[i*CX_RAS_PROT_RANGE +j] = s_data_w_par[i*CX_RAS_PROT_RANGE +j +i];
        end
      end
    end
  endfunction

  // Data with parity
  function automatic [CC_SLV_BUS_DATA_WIDTH-1:0] fn_data_w_par;
    input [SLAVE_BUS_DATA_WIDTH-1:0] s_data_wo_par;

    integer i, j;
    reg [CX_RAS_PROT_RANGE-1:0] s_data_for_par;
    reg i_data_w_par;

    begin
    fn_data_w_par  = {CC_SLV_BUS_DATA_WIDTH{1'b0}};
    s_data_for_par = {CX_RAS_PROT_RANGE{1'b0}};

      for (i=0; i<(NUM_DATA_PAR_BLOCKS); i=i+1) begin
        for (j=0; j<CX_RAS_PROT_RANGE; j=j+1) begin
          s_data_for_par[j]=s_data_wo_par[i*`CX_RAS_PROT_RANGE +j];
          fn_data_w_par[i*CX_RAS_PROT_RANGE +j+i] = s_data_wo_par[i*CX_RAS_PROT_RANGE +j];
        end
        i_data_w_par = ^s_data_for_par;
        fn_data_w_par[(i+1)*CX_RAS_PROT_RANGE +i] = CX_RAS_PARITY_MODE^i_data_w_par;
      end
    end
  endfunction

  // Address with parity
  function automatic [CC_SLV_BUS_ADDR_WIDTH-1:0] fn_addr_w_par;
    input [SLAVE_BUS_ADDR_WIDTH-1:0] s_addr_wo_par;

    integer i, j;
    reg [CX_RAS_PROT_RANGE-1:0] s_addr_for_par;
    reg i_addr_w_par;

    begin
      fn_addr_w_par  = 0;
      s_addr_for_par = 0;

      for (i=0; i<(NUM_ADDR_PAR_BLOCKS); i=i+1) begin
         for (j=0; j<CX_RAS_PROT_RANGE; j=j+1) begin
           s_addr_for_par[j]=s_addr_wo_par[i*CX_RAS_PROT_RANGE +j];
           fn_addr_w_par[i*CX_RAS_PROT_RANGE +j+i] = s_addr_wo_par[i*CX_RAS_PROT_RANGE +j];
         end
          i_addr_w_par = ^s_addr_for_par;
          fn_addr_w_par[(i+1)*CX_RAS_PROT_RANGE +i] = CX_RAS_PARITY_MODE^i_addr_w_par;
      end
    end
  endfunction

  function automatic [NUM_ADDR_PAR_BLOCKS-1:0] fn_prot_chkin_ad;
    input [CC_SLV_BUS_ADDR_WIDTH-1:0] s_addr_w_par;
    integer i;
    begin
      for (i=0; i<NUM_ADDR_PAR_BLOCKS; i=i+1) begin
        fn_prot_chkin_ad[i] = s_addr_w_par[i*CX_RAS_PROT_RANGE + i + CX_RAS_PROT_RANGE];
      end
    end
  endfunction

  function automatic [NUM_DATA_PAR_BLOCKS-1:0] fn_prot_chkin_d;
    input [CC_SLV_BUS_DATA_WIDTH-1:0] s_data_w_par;
    integer i;
    begin
      for (i=0; i<NUM_DATA_PAR_BLOCKS; i=i+1) begin
        fn_prot_chkin_d[i] = s_data_w_par[i*CX_RAS_PROT_RANGE + i + CX_RAS_PROT_RANGE];
      end
    end
  endfunction



endmodule
