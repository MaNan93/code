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
// ---    $DateTime: 2024/01/10 14:23:51 $
// ---    $Revision: #12 $
// ---    $Id: //dwh/pcie_iip/main/fairbanks/design/Axi/DWC_pcie_axi_misb.sv#12 $
// -------------------------------------------------------------------------
// --- Description: AXI Master Interface Safety Block Wrapper
// -------------------------------------------------------------------------

`include "include/DWC_pcie_ctl_all_defs.svh"
`include "Axi/DWC_pcie_axi_mstr_pkg.svh"
`include "DWC_pcie_ctl_pkg.svh"

module DWC_pcie_axi_misb
import DWC_pcie_axi_mstr_pkg::*;
  import DWC_pcie_ctl_pkg::ras_dp_err_log_t;
  import DWC_pcie_ctl_pkg::MAX_RAS_PROT_CHK_N;
  import DWC_pcie_ctl_pkg::ras_dp_err_inj_t;
  #(
    parameter BUS_ADDR_WIDTH          = `MASTER_BUS_ADDR_WIDTH       ,
    parameter BUS_ADDR_P_WIDTH        = `CC_MSTR_BUS_ADDR_WIDTH      ,
    parameter BUS_DATA_WIDTH          = `MASTER_BUS_DATA_WIDTH       ,
    parameter BUS_DATA_P_WIDTH        = `CC_MSTR_BUS_DATA_WIDTH      ,
    parameter AW_USER_WIDTH           = `CC_MSTR_AW_USER_WIDTH       ,
    parameter W_USER_WIDTH            = `CC_MSTR_W_USER_WIDTH        ,
    parameter AR_USER_WIDTH           = `CC_MSTR_AR_USER_WIDTH       ,
    parameter R_USER_WIDTH            = `CC_MSTR_R_USER_WIDTH        ,
    parameter B_USER_WIDTH            = `CC_MSTR_B_USER_WIDTH        ,
    parameter PRFX_PAR_WD             = `CX_PRFX_PAR_WD              ,
    parameter HP_MSTR                 = 1'b0
  )(
 // Clock and Reset
    input  logic                                      mstr_aclk      ,
    input  logic                                      mstr_arstn     ,
 // AW Channel
    input  pkg_axi_mstr_aw_s                          in_aw          ,
    input  logic [BUS_ADDR_P_WIDTH-1:0]               in_awaddr      ,
    input  logic                                      in_awready     ,
    output pkg_axi_mstr_aw_s                          out_aw         ,
    output logic [BUS_ADDR_WIDTH-1:0]                 out_awaddr     ,
    output logic                                      out_awready    ,
 // AR Channel
    input  pkg_axi_mstr_ar_s                          in_ar          ,
    input  logic [BUS_ADDR_P_WIDTH-1:0]               in_araddr      ,
    input  logic                                      in_arready     ,
    output pkg_axi_mstr_ar_s                          out_ar         ,
    output logic [BUS_ADDR_WIDTH-1:0]                 out_araddr     ,
    output logic                                      out_arready    ,
 // W Channel
    input  pkg_axi_mstr_w_s                           in_w           ,
    input  logic [BUS_DATA_P_WIDTH-1:0]               in_wdata       ,
    input  logic                                      in_wready      ,
    output pkg_axi_mstr_w_s                           out_w          ,
    output logic [BUS_DATA_WIDTH-1:0]                 out_wdata      ,
    output logic                                      out_wready     ,
 // R Channel
    input  pkg_axi_mstr_r_s                           in_r           ,
    input  logic [BUS_DATA_WIDTH-1:0]                 in_rdata       ,
    input  logic                                      in_rready      ,
    output pkg_axi_mstr_r_s                           out_r          ,
    output logic [BUS_DATA_P_WIDTH-1:0]               out_rdata      ,
    output                                            out_rready     ,
 // B Channel
    input  pkg_axi_mstr_b_s                           in_b           ,
    input  logic                                      in_bready      ,
    output pkg_axi_mstr_b_s                           out_b          ,
    output                                            out_bready
 // Parity Signals
 ,
    output logic [AW_USER_WIDTH-1:0]                  out_awuser     ,
    output logic [AR_USER_WIDTH-1:0]                  out_aruser     ,
    output logic [W_USER_WIDTH-1:0]                   out_wuser      ,
    input  logic [R_USER_WIDTH-1:0]                   in_ruser       ,
    input  logic [PRFX_PAR_WD-1:0]                    in_aw_prfx_par ,
    input  logic [PRFX_PAR_WD-1:0]                    in_ar_prfx_par ,
    output logic [PRFX_PAR_WD-1:0]                    out_aw_prfx_par,
    output logic [PRFX_PAR_WD-1:0]                    out_ar_prfx_par,
 // RASDP Status
    output logic                                      err_sts
    ,
    output ras_dp_err_log_t                           err_sts_ras_dp_err_log

  ,
    input  ras_dp_err_inj_t                           ras_dp_err_inj_mstr_aclk
    );

  localparam ECC_OR_PAR               = (`CX_AXI_IF_TYPE_OF_PROT == 2) ? 2 : 0;
  localparam PYLD1_AW_AR_USER_WIDTH   = 4 + `CC_AXI4_ENABLE_VALUE;
  localparam PYLD1_W_USER_WIDTH       = 2 + `CC_AXI3_ENABLE_VALUE;
  localparam MSTR_ID_WD               = `CC_MSTR_BUS_ID_WIDTH ;

    // Number of parity address blocks per 32/64 bit address
   localparam NUM_ADDR_PAR_BLOCKS  = `MASTER_BUS_ADDR_WIDTH/`CX_RAS_PROT_RANGE;
   localparam NUM_DATA_PAR_BLOCKS  = `MASTER_BUS_DATA_WIDTH/`CX_RAS_PROT_RANGE;
   localparam RAS_DP_ERR_LOG_WD    = $clog2(MAX_RAS_PROT_CHK_N);

  logic [`MASTER_BUS_ADDR_WIDTH-1:0]   in_awaddr_s;
  logic [`MASTER_BUS_ADDR_WIDTH-1:0]   in_araddr_s;
  logic [`MASTER_BUS_DATA_WIDTH-1:0]   in_wdata_s ;
  logic [`MASTER_BUS_DATA_WIDTH-1:0]   out_rdata_s;
  logic [`CC_MSTR_BUS_ADDRP_WIDTH-1:0] in_awaddr_p;
  logic [`CC_MSTR_BUS_ADDRP_WIDTH-1:0] in_araddr_p;
  logic [`CC_MSTR_BUS_DATAP_WIDTH-1:0] in_wdata_p ;
  logic [`CC_MSTR_BUS_DATAP_WIDTH-1:0] out_rdata_p;
  logic                                s_rpyld2   ;
  logic                                s_bpyld1   ;
  logic                                s_awprfx   ;
  logic                                s_arprfx   ;

  DWC_pcie_bridge_par_decode
  
  #(
    .CX_RAS_PROT_RANGE(`CX_RAS_PROT_RANGE),
    .DBUS_WD_NP(`MASTER_BUS_ADDR_WIDTH)
  ) u_misb_aw_decode (
    .datap_in  (in_awaddr  ),
    .data_out  (in_awaddr_s),
    .par_out   (in_awaddr_p)
  );

  DWC_pcie_bridge_par_decode
  
  #(
    .CX_RAS_PROT_RANGE(`CX_RAS_PROT_RANGE),
    .DBUS_WD_NP(`MASTER_BUS_ADDR_WIDTH)
  ) u_misb_ar_decode (
    .datap_in  (in_araddr  ),
    .data_out  (in_araddr_s),
    .par_out   (in_araddr_p)
  );

  DWC_pcie_bridge_par_decode
  
  #(
    .CX_RAS_PROT_RANGE(`CX_RAS_PROT_RANGE),
    .DBUS_WD_NP(`MASTER_BUS_DATA_WIDTH)
  ) u_misb_w_decode (
    .datap_in  (in_wdata  ),
    .data_out  (in_wdata_s),
    .par_out   (in_wdata_p)
  );
  logic rdata_chk_en;

  assign rdata_chk_en = out_r.valid & in_rready;

  ras_dp_pipe
   #(
    .PIPELINE_TYPE             (0                               ),
    .RESETVAL                  (0                               ),
    .N_STAGES                  (0                               ),
    .CAN_STALL                 (0                               ),
    .RESET_STALL               (0                               ),
    .BUS_PROTECT_GEN_EN        (0                               ), // 0: Bus Protection Generator is not present
    .BUS_PROTECT_CHK_EN        (1                               ), // 1: Bus Protection Checker is present (ECC/Parity)
    .PROT_TYPE                 (1                               ), // 0=Ecc, 1=Simple Parity
    .PROT_RANGE                (`CX_RAS_PROT_RANGE              ),
    .PROT_WD                   (NUM_DATA_PAR_BLOCKS             ),
    .PARITY_MODE               (`CX_RAS_PARITY_MODE             ),
    .PROT_CORRECT_EN           (0                               ),
    .TOTAL_WIDTH               (`MASTER_BUS_DATA_WIDTH          ),
    .EXCLUDE_PROT_WIDTH        (0                               ),
    .RAS_DP_PROT_CHK_ID_BASE   (`ERR_STS_RAS_ID                 )
  ) u_rdata_chk (
    .clk                       ( mstr_aclk                      ),
    .rst_n                     ( mstr_arstn                     ),
    .din                       ( fn_data_wo_par  (out_rdata)    ),
    .din_prot                  ( fn_prot_chkin_d (out_rdata)    ),
    .dout                      ( /* Not Connected */            ),
    .dout_prot                 ( /* Not Connected */            ),
    .en                        (1'b1                            ),
    .bypass                    (1'b0                            ),
    .stall                     (1'b0                            ),
    .stallout                  ( /* Not Connected */            ),
    .valid_in                  ( rdata_chk_en                   ),
    .halt_out                  ( /* Not Connected */            ),
    .valid_out                 ( /* Not Connected */            ),
    .halt_in                   (1'b0                            ),
    .ras_dp_err_inband_kbd_in  (1'b0                            ),
    .ras_dp_err_inband_kbd_out ( /* Not Connected */            ),
    .ras_dp_err_log            (err_sts_ras_dp_err_log          )
      ,
      .ras_dp_err_inj          (ras_dp_err_inj_mstr_aclk        )
    );
  assign err_sts = err_sts_ras_dp_err_log.valid;


  assign out_rdata_p = in_ruser[`CC_MSTR_BUS_DATA_PROT_WIDTH-1:0];
  assign out_rdata_s = in_rdata;

  DWC_pcie_bridge_par_encode
  
  #(
    .CX_RAS_PROT_RANGE(`CX_RAS_PROT_RANGE),
    .DBUS_WD_NP(`MASTER_BUS_DATA_WIDTH)
  ) u_misb_r_encode (
    .data_in   (out_rdata_s),
    .par_in    (out_rdata_p),
    .datap_out (out_rdata  )
  );

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

assign out_awaddr  = in_awaddr_s;
assign out_araddr  = in_araddr_s;
assign out_wdata   = in_wdata_s ;

assign out_awuser = in_awaddr_p;
assign out_aruser = in_araddr_p;
assign out_wuser  = in_wdata_p ;

assign out_aw_prfx_par = in_aw_prfx_par;
assign out_ar_prfx_par = in_ar_prfx_par;


function automatic [NUM_DATA_PAR_BLOCKS-1:0] fn_prot_chkin_d;
    input [BUS_DATA_P_WIDTH-1:0] s_data_w_par;
    integer i;
    begin
      for (i=0; i<NUM_DATA_PAR_BLOCKS; i=i+1) begin
        fn_prot_chkin_d[i] = s_data_w_par[i*`CX_RAS_PROT_RANGE + i + `CX_RAS_PROT_RANGE];
      end
    end
  endfunction

  function automatic [`MASTER_BUS_DATA_WIDTH-1:0] fn_data_wo_par;
    input [BUS_DATA_P_WIDTH-1:0] s_data_w_par;
    integer i,j;
    begin
      for (i=0; i<NUM_DATA_PAR_BLOCKS; i=i+1)  begin // interate thru parity block size
       for (j=0; j<`CX_RAS_PROT_RANGE; j=j+1)  begin // interate thru parity block size bits
          fn_data_wo_par[i*`CX_RAS_PROT_RANGE +j] = s_data_w_par[i*`CX_RAS_PROT_RANGE +j +i];
        end
      end
    end
  endfunction

endmodule
