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
// ---    $Revision: #9 $
// ---    $Id: //dwh/pcie_iip/main/fairbanks/design/Bridge/slave/DWC_pcie_axi_slv_err_rsp.sv#9 $
// -------------------------------------------------------------------------

// --- Module Description:
// Data bus and posted errored responses always return OK on the AXI interface.
// Non-Posted errored responses return
// - OK with all FF's in the data or
// - SLVERR or
// - DECERR
// The excpetion is poisoned responses where the raw data is returned with
// the EP flag driven in the sideband bus. The AXI response is OK.
// The non-posted error response type is translated to an AXI error response based
// on configuration info.
// The non-posted configuration retry response is passed to the AXI slave
// with CRS driven on the sideband bus.
// Flushed responses are received as timed out responses and are transalated
// accordingly.
// If to|ca|ur then generate error response else pass response info.
// If cfg_err_rsp_mode[0] = 0 then
//   - generate OK with all FF's in the data
// else
//   - generate SLVERR or DECERR depending on the error mapping control bits.
// if cfg_slv_resp_err_map[5] = 1 then if to SLVERR(10) else DECERR(11)
// if cfg_slv_resp_err_map[2] = 1 then if ca SLVERR else DECERR
// if cfg_slv_resp_err_map[1] = 1 then if ur SLVERR else DECERR
// Note: Error responses are mutually exclusive.
// -------------------------------------------------------------------------
// Macros
// CPL error response encoding
`define CPLRSP_TO  4'b1000
`define CPLRSP_CA  4'b0100
`define CPLRSP_CRS 4'b0010
`define CPLRSP_UR  4'b0001

`include "include/DWC_pcie_ctl_all_defs.svh"


 module DWC_pcie_axi_slv_err_rsp
 #(
   parameter CX_RAS_PROT_RANGE             = `CX_RAS_PROT_RANGE,
   parameter CX_RAS_PARITY_MODE            = `CX_RAS_PARITY_MODE,
  parameter SLV_BUS_DATA_WIDTH             = `CC_SLV_BUS_DATA_WIDTH,
  parameter SLV_BUS_DATA_WIDTH_NP          = `SLAVE_BUS_DATA_WIDTH
  )
  (
  // -------------------------------------------------------------------------------------
  // Error response control
  input       [4:0]                                  cfg_err_resp_mode,
  input       [5:0]                                  cfg_err_resp_map,
  input                                              dbi_response,

  // -------------------------------------------------------------------------------------
  // Non-posted response status
  input                                              atm_np_ven_id_rd,
  input       [1 :0] nprspf_resp,
  input       [2:0]                                  nprspf_status, // CA | CRS | UR
  input                                              nprspf_to,
  input       [SLV_BUS_DATA_WIDTH-1:0]               nprspf_data,
  input       [2:0]                                  pdcmp_p_rsp_cpl_stat,
  // -------------------------------------------------------------------------------------
  // AXI response interface
  output wire [`CC_AXIJ_DMWR_VALUE +1:0]             serr_np_resp,
  output wire [SLV_BUS_DATA_WIDTH-1:0]               serr_np_data,
  output wire [1:0]                                  serr_p_resp
  );
  // -------------------------------------------------------------------------------------
  // Local parameters
  // -------------------------------------------------------------------------------------
  // AXI response encoding
  localparam OKAY                    = 0;
  localparam SLVERR                  = 2;
  localparam DECERR                  = 3;
  // -------------------------------------------------------------------------------------
  // Internal Wire/Reg
  // -------------------------------------------------------------------------------------
  wire                                     s_cfg_err_rsp_global;
  wire                                     s_cfg_err_rsp_vendor_id;
  wire [1:0]                               s_cfg_err_rsp_crs;
  wire                                     s_np_ca;
  wire                                     s_np_crs;
  wire                                     s_np_ur;
  wire                                     s_np_det_err;
  wire [3:0]                               s_np_err_info;

  wire                                     s_p_ca;
  wire                                     s_p_ur;
  wire                                     s_p_det_err;
  wire [3:0]                               s_p_err_info;

  reg  [`CC_AXIJ_DMWR_VALUE +1:0]          s_np_resp;
  reg  [SLV_BUS_DATA_WIDTH-1:0]            s_np_data;

  reg  [1:0]                               s_p_resp;

  wire [SLV_BUS_DATA_WIDTH-1:0]            sdata_FFFF_FFFF;
  wire [17:0]                              sdata_0001;
  wire [SLV_BUS_DATA_WIDTH-1:0]            sdata_FFFF_0001;

  wire [1:0]                               s_nprspf_resp;


  assign sdata_FFFF_FFFF =  add_data_par({SLV_BUS_DATA_WIDTH_NP{1'b1}});
  assign sdata_0001      = {CX_RAS_PARITY_MODE,8'h00,(CX_RAS_PARITY_MODE==0),8'h01};
  assign sdata_FFFF_0001 = {sdata_FFFF_FFFF[SLV_BUS_DATA_WIDTH-1:18],sdata_0001};


  // -------------------------------------------------------------------------------------
  // Design
  // -------------------------------------------------------------------------------------
  // Extract AXI error response register bit fields
  assign s_cfg_err_rsp_global    = cfg_err_resp_mode[0];
  assign s_cfg_err_rsp_vendor_id = cfg_err_resp_mode[2];
  assign s_cfg_err_rsp_crs       = cfg_err_resp_mode[4:3];
  assign s_cfg_err_map_to        = cfg_err_resp_map[5];
  assign s_cfg_err_map_ca        = cfg_err_resp_map[2];
  assign s_cfg_err_map_crs       = cfg_err_resp_map[1];
  assign s_cfg_err_map_ur        = cfg_err_resp_map[0];



  // -------------------------------------------------------------------------------------
  // NP Error Response Maping
  // -------------------------------------------------------------------------------------

  // Detect errored completion status
  assign s_np_ca    = ( nprspf_status        ==`CA_CPL_STATUS  );
  assign s_np_crs   = ( nprspf_status        ==`CRS_CPL_STATUS );
  assign s_np_ur    = ( nprspf_status        ==`UR_CPL_STATUS  );

  // Encode AXI error response
  assign s_np_err_info    = { nprspf_to, s_np_ca, s_np_crs, s_np_ur };
  assign s_np_det_err     = |s_np_err_info;

assign s_nprspf_resp = nprspf_resp;


  always @(*) begin : proc_comb_err_np_rsp
    // Initialise
    s_np_resp = s_nprspf_resp;
    s_np_data = nprspf_data;

    // If the response is from DBI CDM access the response is OKAY or
    // SLVERR for DBI burst access
    if (dbi_response) begin
      if (s_nprspf_resp == 2'b0)
        s_np_resp = OKAY;
      else begin /* Errors, but not from TDISP */
        if (!s_cfg_err_rsp_global) begin
          s_np_resp = OKAY;
        end else if (s_cfg_err_map_ur) begin
          s_np_resp = SLVERR;
        end else begin
          s_np_resp = DECERR;
        end
        s_np_data = sdata_FFFF_FFFF;
      end
    end
    else
    if (s_np_det_err) begin
       s_np_data = sdata_FFFF_FFFF;
      case (s_np_err_info)
        `CPLRSP_TO : begin
          if (!s_cfg_err_rsp_global) begin
            s_np_resp = OKAY;
          end else if (s_cfg_err_map_to) begin
            s_np_resp = SLVERR;
          end else begin
            s_np_resp = DECERR;
          end
        end
        `CPLRSP_CA : begin
          if (!s_cfg_err_rsp_global) begin
            s_np_resp = OKAY;
          end else if (s_cfg_err_map_ca) begin
            s_np_resp = SLVERR;
          end else begin
            s_np_resp = DECERR;
          end
        end
        `CPLRSP_CRS : begin
          if(s_cfg_err_rsp_crs == 2'b00) begin            // preserve original behavior and return whatever data is received
            s_np_resp = OKAY;
            s_np_data = nprspf_data;
          end else if (s_cfg_err_rsp_crs == 2'b01) begin  // return all FFFF data including responses to vendor id requests
            s_np_resp = OKAY;
            s_np_data = sdata_FFFF_FFFF;
          end else if (s_cfg_err_rsp_crs == 2'b10) begin  // else
            s_np_resp = OKAY;
            if (atm_np_ven_id_rd) begin                   // vendor id requests are an exception and FFFF_0001 is returned instead of all FFFF
              s_np_data = sdata_FFFF_0001;
            end else begin
              s_np_data = sdata_FFFF_FFFF;
            end
          end else begin
            if (s_cfg_err_map_crs) begin
              s_np_resp = SLVERR;
            end else begin
              s_np_resp = DECERR;
            end
          end
        end
        `CPLRSP_UR : begin
          if (atm_np_ven_id_rd) begin
            if (!s_cfg_err_rsp_vendor_id) begin
              s_np_resp = OKAY;
            end else begin
              if (s_cfg_err_map_ur) begin
                s_np_resp = SLVERR;
              end else begin
                s_np_resp = DECERR;
              end
            end
          end else begin
            if (!s_cfg_err_rsp_global) begin
              s_np_resp = OKAY;
            end else if (s_cfg_err_map_ur) begin
              s_np_resp = SLVERR;
            end else begin
              s_np_resp = DECERR;
            end
          end
        end

      endcase
    end
  end

  // Assign outputs
  assign serr_np_resp = s_np_resp;
  assign serr_np_data = s_np_data;


  // -------------------------------------------------------------------------------------
  // P Error Response Maping
  // -------------------------------------------------------------------------------------

  // Detect errored completion status
  // CRS and TO do not make sense for P requests
  assign s_p_ca     = ( pdcmp_p_rsp_cpl_stat ==`CA_CPL_STATUS  );
  assign s_p_ur     = ( pdcmp_p_rsp_cpl_stat ==`UR_CPL_STATUS  );

  // Encode AXI error response
  assign s_p_err_info     = {      1'b0,  s_p_ca,     1'b0,  s_p_ur };
  assign s_p_det_err      = |s_p_err_info;

  always @(*) begin : proc_comb_err_p_rsp
    // Initialise
    s_p_resp = 2'b00;

    if (s_p_det_err) begin
      case (s_p_err_info)
        `CPLRSP_CA : begin
          if (!s_cfg_err_rsp_global) begin
            s_p_resp = OKAY;
          end else if (s_cfg_err_map_ca) begin
            s_p_resp = SLVERR;
          end else begin
            s_p_resp = DECERR;
          end
        end
        `CPLRSP_UR : begin
          if (!s_cfg_err_rsp_global) begin
            s_p_resp = OKAY;
          end else if (s_cfg_err_map_ur) begin
            s_p_resp = SLVERR;
          end else begin
            s_p_resp = DECERR;
          end
        end
        default: begin
            s_p_resp = OKAY;
        end
      endcase
    end
  end

  // Assign outputs
  assign serr_p_resp = s_p_resp;

   //Function to interleave the parity data
   function automatic [SLV_BUS_DATA_WIDTH -1:0] add_data_par;
      input [SLV_BUS_DATA_WIDTH_NP -1:0] in_data;
      integer                  i, j;
      reg [SLV_BUS_DATA_WIDTH -1:0] out_data;
      begin
         out_data = {SLV_BUS_DATA_WIDTH{1'b0}};
         for (i=0; i<(SLV_BUS_DATA_WIDTH-SLV_BUS_DATA_WIDTH_NP); i=i+1) begin
            for (j=0; j<CX_RAS_PROT_RANGE; j=j+1) begin
               out_data[i*CX_RAS_PROT_RANGE +j+i] = in_data[i*CX_RAS_PROT_RANGE +j];
            end
            out_data[(i + 1)*CX_RAS_PROT_RANGE + i] = CX_RAS_PARITY_MODE;
         end
         add_data_par = out_data;
      end
   endfunction

`ifndef SYNTHESIS
`endif

endmodule
