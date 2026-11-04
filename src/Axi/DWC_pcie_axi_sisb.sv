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
// ---    $Revision: #11 $
// ---    $Id: //dwh/pcie_iip/main/fairbanks/design/Axi/DWC_pcie_axi_sisb.sv#11 $
// -------------------------------------------------------------------------
// --- Description: AXI Slave Interface Safety Block Wrapper
// -------------------------------------------------------------------------

`include "include/DWC_pcie_ctl_all_defs.svh"
`include "Axi/DWC_pcie_axi_slv_pkg.svh"
`include "DWC_pcie_ctl_pkg.svh"

module DWC_pcie_axi_sisb
import DWC_pcie_axi_slv_pkg::*;
  import DWC_pcie_ctl_pkg::ras_dp_err_log_t;
  import DWC_pcie_ctl_pkg::ras_dp_err_inj_t;
  import DWC_pcie_ctl_pkg::MAX_RAS_PROT_CHK_N;
  import DWC_pcie_ctl_pkg::RAS_ERROR_LOG_WD;
  #(
    parameter type slave_aw = pkg_axi_slv_aw_s                         ,
    parameter type slave_ar = pkg_axi_slv_ar_s                         ,
    parameter type slave_w  = pkg_axi_slv_w_s                          ,
    parameter type slave_r  = pkg_axi_slv_r_s                          ,
    parameter type slave_b  = pkg_axi_slv_b_s                          ,
    parameter DBI_SLV                 = 1'b0                           ,
    parameter BUS_ADDR_WIDTH          = `SLAVE_BUS_ADDR_WIDTH          ,
    parameter BUS_ADDR_P_WIDTH        = `CC_SLV_BUS_ADDR_WIDTH         ,
    parameter BUS_DATA_WIDTH          = `SLAVE_BUS_DATA_WIDTH          ,
    parameter BUS_DATA_P_WIDTH        = `CC_SLV_BUS_DATA_WIDTH         ,
    parameter ADDR_PARITY_WIDTH       = `CC_SLV_BUS_ADDRP_WIDTH        ,
    parameter DATA_PARITY_WIDTH       = `CC_SLV_BUS_DATAP_WIDTH        ,
    parameter ID_WIDTH                = `CC_SLV_BUS_ID_WIDTH           ,
    parameter WSTRB_WIDTH             = `CC_SLV_BUS_WSTRB_WIDTH        ,
    parameter BURST_LEN_WIDTH         = `CC_SLV_INT_BURST_LEN_PW           ,
    parameter DATA_PROT_WIDTH         = `CC_SLV_BUS_DATA_PROT_WIDTH    ,
    parameter ADDR_PROT_WIDTH         = `CC_SLV_BUS_ADDR_PROT_WIDTH    ,
    parameter AW_USER_WIDTH           = `CC_SLV_AW_USER_WIDTH          ,
    parameter W_USER_WIDTH            = `CC_SLV_W_USER_WIDTH           ,
    parameter AR_USER_WIDTH           = `CC_SLV_AR_USER_WIDTH          ,
    parameter R_USER_WIDTH            = `CC_SLV_R_USER_WIDTH           ,
    parameter B_USER_WIDTH            = `CC_SLV_B_USER_WIDTH           ,
    parameter AW_EXTRA_PYLD_WIDTH     =  DBI_SLV? `CC_DBI_SLV_AW_EXTRA_PYLD_WIDTH :`CC_SLV_AW_EXTRA_PYLD_WIDTH    ,
    parameter W_EXTRA_PYLD_WIDTH      = `CC_SLV_W_EXTRA_PYLD_WIDTH     ,
    parameter AR_EXTRA_PYLD_WIDTH     =  DBI_SLV? `CC_DBI_SLV_AR_EXTRA_PYLD_WIDTH :`CC_SLV_AR_EXTRA_PYLD_WIDTH    ,
    parameter R_EXTRA_PYLD_WIDTH      = `CC_SLV_R_EXTRA_PYLD_WIDTH     ,
    parameter B_EXTRA_PYLD_WIDTH      = `CC_SLV_B_EXTRA_PYLD_WIDTH     ,
    parameter AW_EXTRA_PYLD_PAR_WIDTH = `CC_SLV_AW_EXTRA_PYLD_PAR_WIDTH,
    parameter W_EXTRA_PYLD_PAR_WIDTH  = `CC_SLV_W_EXTRA_PYLD_PAR_WIDTH ,
    parameter AR_EXTRA_PYLD_PAR_WIDTH = `CC_SLV_AR_EXTRA_PYLD_PAR_WIDTH,
    parameter R_EXTRA_PYLD_PAR_WIDTH  = `CC_SLV_R_EXTRA_PYLD_PAR_WIDTH ,
    parameter B_EXTRA_PYLD_PAR_WIDTH  = `CC_SLV_B_EXTRA_PYLD_PAR_WIDTH ,
    parameter PRFX_PAR_WD             = `CX_PRFX_PAR_WD
  )(
 // Clock and Reset
    input  logic                               slv_aclk               ,
    input  logic                               slv_arstn              ,
 // AW Channel
    input  slave_aw                            in_aw                  ,
    input  logic [BUS_ADDR_WIDTH-1:0]          in_awaddr              ,
    input  logic                               in_awready             ,
    output slave_aw                            out_aw                 ,
    output logic [BUS_ADDR_P_WIDTH-1:0]        out_awaddr             ,
    output                                     out_awready            ,
 // AR Channel
    input  slave_ar                            in_ar                  ,
    input  logic [BUS_ADDR_WIDTH-1:0]          in_araddr              ,
    input  logic                               in_arready             ,
    output slave_ar                            out_ar                 ,
    output logic [BUS_ADDR_P_WIDTH-1:0]        out_araddr             ,
    output                                     out_arready            ,
 // W Channel
    input  slave_w                             in_w                   ,
    input  logic [BUS_DATA_WIDTH-1:0]          in_wdata               ,
    input  logic                               in_wready              ,
    output slave_w                             out_w                  ,
    output logic [BUS_DATA_P_WIDTH-1:0]        out_wdata              ,
    output                                     out_wready             ,
 // R Channel
    input  slave_r                             in_r                   ,
    input  logic [BUS_DATA_P_WIDTH-1:0]        in_rdata               ,
    input  logic                               in_rready              ,
    output slave_r                             out_r                  ,
    output logic [BUS_DATA_WIDTH-1:0]          out_rdata              ,
    output logic                               out_rready             ,
 // B Channel
    input  slave_b                             in_b                   ,
    input  logic                               in_bready              ,
    output slave_b                             out_b                  ,
    output logic                               out_bready
 // Parity Signals
 ,
    input  logic [AW_USER_WIDTH-1:0]           in_awuser              ,
    input  logic [AR_USER_WIDTH-1:0]           in_aruser              ,
    input  logic [W_USER_WIDTH-1:0]            in_wuser               ,
    output logic [R_USER_WIDTH-1:0]            out_ruser              ,
    output logic [PRFX_PAR_WD-1:0]             out_aw_prfx_par        ,
    output logic [PRFX_PAR_WD-1:0]             out_ar_prfx_par        ,
    input  logic [PRFX_PAR_WD-1:0]             in_aw_prfx_par         ,
    input  logic [PRFX_PAR_WD-1:0]             in_ar_prfx_par         ,
 // RASDP Status
    output pkg_axi_slv_par_sts                 err_sts
    ,
    output ras_dp_err_log_t                    axi_sisb_aw_ad_ras_dp_err_log,
    output ras_dp_err_log_t                    axi_sisb_ar_ad_ras_dp_err_log,
    output ras_dp_err_log_t                    axi_sisb_w_dt_ras_dp_err_log ,

    input  ras_dp_err_inj_t                    ras_dp_err_inj_slv_aclk

    );


  localparam ECC_OR_PAR               = (`CX_AXI_IF_TYPE_OF_PROT == 2) ? 2 : 0;
  localparam PYLD1_AW_AR_USER_WIDTH   = 4 + `CC_AXI4_ENABLE_VALUE;
  localparam PYLD1_W_USER_WIDTH       = 2 + `CC_AXI3_ENABLE_VALUE;

  logic [BUS_ADDR_WIDTH-1:0]    out_awaddr_s;
  logic [BUS_ADDR_WIDTH-1:0]    out_araddr_s;
  logic [BUS_DATA_WIDTH-1:0]    out_wdata_s ;
  logic [BUS_DATA_WIDTH-1:0]    in_rdata_s  ;
  logic [ADDR_PARITY_WIDTH-1:0] out_awaddr_p;
  logic [ADDR_PARITY_WIDTH-1:0] out_araddr_p;
  logic [DATA_PARITY_WIDTH-1:0] out_wdata_p ;
  logic [DATA_PARITY_WIDTH-1:0] in_rdata_p  ;

   // Number of parity address blocks per 32/64 bit address
  localparam NUM_ADDR_PAR_BLOCKS  = `SLAVE_BUS_ADDR_WIDTH / `CX_RAS_PROT_RANGE;
  localparam NUM_DATA_PAR_BLOCKS  = `SLAVE_BUS_DATA_WIDTH / `CX_RAS_PROT_RANGE;
  localparam RAS_DP_ERR_LOG_WD = $clog2(MAX_RAS_PROT_CHK_N);

  logic awaddr_chk_en;

  assign awaddr_chk_en = out_aw.valid & in_awready;

  ras_dp_pipe
   #(
    .PIPELINE_TYPE             (0                            ),
    .RESETVAL                  (0                            ),
    .N_STAGES                  (0                            ),
    .CAN_STALL                 (0                            ),
    .RESET_STALL               (0                            ),
    .BUS_PROTECT_GEN_EN        (0                            ),
    .BUS_PROTECT_CHK_EN        (1                            ),
    .PROT_TYPE                 (1                            ), // Parity mode
    .PROT_RANGE                (`CX_RAS_PROT_RANGE           ),
    .PROT_WD                   (NUM_ADDR_PAR_BLOCKS          ),
    .PARITY_MODE               (`CX_RAS_PARITY_MODE          ),
    .PROT_CORRECT_EN           (0                            ),
    .TOTAL_WIDTH               (`SLAVE_BUS_ADDR_WIDTH        ),
    .EXCLUDE_PROT_WIDTH        (0                            ),
    .RAS_DP_PROT_CHK_ID_BASE   (`SISB_AW_AD_RAS_ID           )
  ) u_waddr_chk (
    .clk                       ( slv_aclk                    ),
    .rst_n                     ( slv_arstn                   ),
    .din                       ( fn_addr_wo_par(out_awaddr)  ),
    .din_prot                  ( fn_prot_chkin_ad(out_awaddr)),
    .dout                      ( /* Not Connected */         ),
    .dout_prot                 ( /* Not Connected */         ),
    .en                        (1'b1                         ),
    .bypass                    (1'b0                         ),
    .stall                     (1'b0                         ),
    .stallout                  ( /* Not Connected */         ),
    .valid_in                  ( awaddr_chk_en               ),
    .halt_out                  ( /* Not Connected */         ),
    .valid_out                 ( /* Not Connected */         ),
    .halt_in                   (1'b0                         ),
    .ras_dp_err_inband_kbd_in  (1'b0                         ),
    .ras_dp_err_inband_kbd_out ( /* Not Connected */         ),
    .ras_dp_err_log            (axi_sisb_aw_ad_ras_dp_err_log)
      ,
      .ras_dp_err_inj          (ras_dp_err_inj_slv_aclk)
    );

    assign err_sts.awaddr_par = axi_sisb_aw_ad_ras_dp_err_log.valid;


  assign out_awaddr_s = in_awaddr;

  logic araddr_chk_en;

  assign araddr_chk_en = out_ar.valid & in_arready;

  ras_dp_pipe
   #(
    .PIPELINE_TYPE             (0                            ),
    .RESETVAL                  (0                            ),
    .N_STAGES                  (0                            ),
    .CAN_STALL                 (0                            ),
    .RESET_STALL               (0                            ),
    .BUS_PROTECT_GEN_EN        (0                            ),
    .BUS_PROTECT_CHK_EN        (1                            ),
    .PROT_TYPE                 (1                            ), // Parity mode
    .PROT_RANGE                (`CX_RAS_PROT_RANGE           ),
    .PROT_WD                   (NUM_ADDR_PAR_BLOCKS          ),
    .PARITY_MODE               (`CX_RAS_PARITY_MODE          ),
    .PROT_CORRECT_EN           (0                            ),
    .TOTAL_WIDTH               (`SLAVE_BUS_ADDR_WIDTH        ),
    .EXCLUDE_PROT_WIDTH        (0                            ),
    .RAS_DP_PROT_CHK_ID_BASE   (`SISB_AR_AD_RAS_ID           )
  ) u_raddr_chk (
    .clk                       ( slv_aclk                    ),
    .rst_n                     ( slv_arstn                   ),
    .din                       ( fn_addr_wo_par(out_araddr)  ),
    .din_prot                  ( fn_prot_chkin_ad(out_araddr)),
    .dout                      ( /* Not Connected */         ),
    .dout_prot                 ( /* Not Connected */         ),
    .en                        (1'b1                         ),
    .bypass                    (1'b0                         ),
    .stall                     (1'b0                         ),
    .stallout                  ( /* Not Connected */         ),
    .valid_in                  ( araddr_chk_en               ),
    .halt_out                  ( /* Not Connected */         ),
    .valid_out                 ( /* Not Connected */         ),
    .halt_in                   (1'b0                         ),
    .ras_dp_err_inband_kbd_in  (1'b0                         ),
    .ras_dp_err_inband_kbd_out ( /* Not Connected */         ),
    .ras_dp_err_log            (axi_sisb_ar_ad_ras_dp_err_log)
      ,
      .ras_dp_err_inj          (ras_dp_err_inj_slv_aclk      )
    );

  assign err_sts.araddr_par = axi_sisb_ar_ad_ras_dp_err_log.valid;

  assign out_araddr_s = in_araddr;
  logic wdata_chk_en;

  assign wdata_chk_en = out_w.valid & in_wready;
 ras_dp_pipe
  #(
    .PIPELINE_TYPE             (0                               ),
    .RESETVAL                  (0                               ),
    .N_STAGES                  (0                               ),
    .CAN_STALL                 (0                               ),
    .RESET_STALL               (0                               ),
    .BUS_PROTECT_GEN_EN        (0                               ),
    .BUS_PROTECT_CHK_EN        (1                               ),
    .PROT_TYPE                 (1                               ), // Parity mode
    .PROT_RANGE                (`CX_RAS_PROT_RANGE              ),
    .PROT_WD                   (NUM_DATA_PAR_BLOCKS             ),
    .PARITY_MODE               (`CX_RAS_PARITY_MODE             ),
    .PROT_CORRECT_EN           (0                               ),
    .TOTAL_WIDTH               (`SLAVE_BUS_DATA_WIDTH           ),
    .EXCLUDE_PROT_WIDTH        (0                               ),
    .RAS_DP_PROT_CHK_ID_BASE   (`SISB_W_DT_RAS_ID               )
  ) u_wdata_chk (
    .clk                       ( slv_aclk                       ),
    .rst_n                     ( slv_arstn                      ),
    .din                       ( fn_data_wo_par(out_wdata)      ),
    .din_prot                  ( fn_prot_chkin_d(out_wdata)     ),
    .dout                      ( /* Not Connected */            ),
    .dout_prot                 ( /* Not Connected */            ),
    .en                        (1'b1                            ),
    .bypass                    (1'b0                            ),
    .stall                     (1'b0                            ),
    .stallout                  ( /* Not Connected */            ),
    .valid_in                  ( wdata_chk_en                   ),
    .halt_out                  ( /* Not Connected */            ),
    .valid_out                 ( /* Not Connected */            ),
    .halt_in                   (1'b0                            ),
    .ras_dp_err_inband_kbd_in  (1'b0                            ),
    .ras_dp_err_inband_kbd_out ( /* Not Connected */            ),
    .ras_dp_err_log            (axi_sisb_w_dt_ras_dp_err_log    )
      ,
      .ras_dp_err_inj          (ras_dp_err_inj_slv_aclk         )
    );

  assign err_sts.wdata_par = axi_sisb_w_dt_ras_dp_err_log.valid;

  assign out_wdata_p = in_wuser[DATA_PARITY_WIDTH-1:0];
  assign out_wdata_s = in_wdata;

generate
  if(DBI_SLV) begin : GEN_ADDR_DBI
    assign out_awaddr = out_awaddr_s;
    assign out_araddr = out_araddr_s;
    assign out_wdata  = out_wdata_s ;
    assign in_rdata_s = in_rdata    ;
  end else begin : GEN_ADDR_SLV

  assign out_awaddr_p = in_awuser[ADDR_PARITY_WIDTH-1:0];

  DWC_pcie_bridge_par_encode
  
  #(
    .CX_RAS_PROT_RANGE(`CX_RAS_PROT_RANGE),
    .DBUS_WD_NP(BUS_ADDR_WIDTH)
  ) u_sisb_aw_encode (
    .data_in   (out_awaddr_s),
    .par_in    (out_awaddr_p),
    .datap_out (out_awaddr  )
  );

  assign out_araddr_p = in_aruser[ADDR_PARITY_WIDTH-1:0];

  DWC_pcie_bridge_par_encode
  
  #(
    .CX_RAS_PROT_RANGE(`CX_RAS_PROT_RANGE),
    .DBUS_WD_NP(BUS_ADDR_WIDTH)
  ) u_sisb_ar_encode (
    .data_in   (out_araddr_s),
    .par_in    (out_araddr_p),
    .datap_out (out_araddr  )
  );

  DWC_pcie_bridge_par_encode
  
  #(
    .CX_RAS_PROT_RANGE(`CX_RAS_PROT_RANGE),
    .DBUS_WD_NP(BUS_DATA_WIDTH)
  ) u_sisb_w_encode (
    .data_in   (out_wdata_s),
    .par_in    (out_wdata_p),
    .datap_out (out_wdata  )
  );


  DWC_pcie_bridge_par_decode
  
  #(
    .CX_RAS_PROT_RANGE(`CX_RAS_PROT_RANGE),
    .DBUS_WD_NP(BUS_DATA_WIDTH)
  ) u_misb_r_decode (
    .datap_in  (in_rdata  ),
    .data_out  (in_rdata_s),
    .par_out   (in_rdata_p)
  );

  end
endgenerate
assign out_aw = in_aw;
assign out_ar = in_ar;
assign out_w  = in_w ;
assign out_r  = in_r ;
assign out_b  = in_b ;

assign out_awready = in_awready;
assign out_arready = in_arready;
assign out_wready  = in_wready ;
assign out_rready  = in_rready ;
assign out_bready  = in_bready ;

assign out_rdata   = in_rdata_s;

assign out_ruser   = in_rdata_p;

assign out_aw_prfx_par = in_aw_prfx_par;
assign out_ar_prfx_par = in_ar_prfx_par;


  // -------------------------------------------------------------------------------------
  // Functions
  // -------------------------------------------------------------------------------------
  function automatic [`SLAVE_BUS_ADDR_WIDTH-1:0] fn_addr_wo_par;
    input [`CC_SLV_BUS_ADDR_WIDTH-1:0] s_addr_w_par;
    integer i,j;
    begin
      for (i=0; i<NUM_ADDR_PAR_BLOCKS; i=i+1)  begin // iterate thru parity block size
       for (j=0; j<`CX_RAS_PROT_RANGE; j=j+1)  begin // iterate thru parity block size bits
          fn_addr_wo_par[i*`CX_RAS_PROT_RANGE +j] = s_addr_w_par[i*`CX_RAS_PROT_RANGE +j +i];
        end
      end
    end
  endfunction

  function automatic [NUM_ADDR_PAR_BLOCKS-1:0] fn_prot_chkin_ad;
    input [`CC_SLV_BUS_ADDR_WIDTH-1:0] s_addr_w_par;
    integer i;
    begin
      for (i=0; i<NUM_ADDR_PAR_BLOCKS; i=i+1) begin
        fn_prot_chkin_ad[i] = s_addr_w_par[i*`CX_RAS_PROT_RANGE + i + `CX_RAS_PROT_RANGE];
      end
    end
  endfunction

  function automatic [NUM_DATA_PAR_BLOCKS-1:0] fn_prot_chkin_d;
    input [`CC_SLV_BUS_DATA_WIDTH-1:0] s_data_w_par;
    integer i;
    begin
      for (i=0; i<NUM_DATA_PAR_BLOCKS; i=i+1) begin
        fn_prot_chkin_d[i] = s_data_w_par[i*`CX_RAS_PROT_RANGE + i + `CX_RAS_PROT_RANGE];
      end
    end
  endfunction

  function automatic [`SLAVE_BUS_DATA_WIDTH-1:0] fn_data_wo_par;
    input [`CC_SLV_BUS_DATA_WIDTH-1:0] s_data_w_par;
    integer i,j;
    begin
      for (i=0; i<NUM_DATA_PAR_BLOCKS; i=i+1)  begin // iterate thru parity block size
       for (j=0; j<`CX_RAS_PROT_RANGE; j=j+1)  begin // iterate thru parity block size bits
          fn_data_wo_par[i*`CX_RAS_PROT_RANGE +j] = s_data_w_par[i*`CX_RAS_PROT_RANGE +j +i];
        end
      end
    end
  endfunction

endmodule
