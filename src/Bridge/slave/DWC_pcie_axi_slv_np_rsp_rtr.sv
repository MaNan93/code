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
// ---    $Revision: #10 $
// ---    $Id: //dwh/pcie_iip/main/fairbanks/design/Bridge/slave/DWC_pcie_axi_slv_np_rsp_rtr.sv#10 $
// -------------------------------------------------------------------------

// --- Module Description:
// ---------------------------------------------------------------------------------------
`include "include/DWC_pcie_ctl_all_defs.svh"
`include "DWC_pcie_ctl_pkg.svh"


 module DWC_pcie_axi_slv_np_rsp_rtr
 #(
  parameter MAX_SLV_TAG                      = 4,
  parameter MAX_SLV_TAG_PW                   = 2,
  parameter CX_RAS_PROT_RANGE                = 8,
  parameter CX_RAS_PARITY_MODE               =`CX_RAS_PARITY_MODE,
  parameter SLV_BUS_DATA_WIDTH               = `CC_SLV_BUS_DATA_WIDTH,
  parameter SLAVE_BUS_DATA_WIDTH             = `SLAVE_BUS_DATA_WIDTH,
  parameter SLV_BURST_LEN_PW                 = `CC_SLV_INT_BURST_LEN_PW
  )
  (
  input                                              slv_aclk,
  input                                              slv_aresetn,
  // -------------------------------------------------------------------------------------
  // Client Non-Posted Response Interface
  input                                              nprspf_valid,
  input       [MAX_SLV_TAG_PW-1:0]                   nprspf_tag,
  input                                              nprspf_to,
  input                                              nprspf_ep,
  input       [2:0]                                  nprspf_tc,
  input                                              nprspf_ido,
  input                                              nprspf_ns,
  input                                              nprspf_ro,
  input       [2:0]                                  nprspf_status,
  input                                              nprspf_cpl,
  input       [7:0]                                  nprspf_cpl_segment,
  input       [8:0]                                  nprspf_dst_segment,
  input       [1 :0] nprspf_resp,
  input       [SLV_BUS_DATA_WIDTH-1:0]               nprspf_data,
  input                                              nprspf_last,
  output wire                                        nprsp_np_ready,
  // -------------------------------------------------------------------------------------
  // Data Bus Non-Posted Response Interface
  input                                              dbi_valid,
  input                                              dbi_last,
  input       [MAX_SLV_TAG_PW-1:0]                   dbi_tag,
  input       [1:0] dbi_resp,
  input       [31:0]                                 dbi_data,
  output wire                                        nprsp_db_ready,
  // -------------------------------------------------------------------------------------
  // Completion order information interface
  input       [MAX_SLV_TAG-1:0]                      atm_cpl_seg_halt,
  // -------------------------------------------------------------------------------------
  // Muxed Non-Posted Response Interface
  output wire                                        nprsp_valid,
  output wire [MAX_SLV_TAG_PW-1:0]                   nprsp_tag,
  output wire                                        nprsp_to,
  output wire                                        nprsp_ep,
  output wire [2:0]                                  nprsp_tc,
  output wire                                        nprsp_ido,
  output wire                                        nprsp_ns,
  output wire                                        nprsp_ro,
  output wire [2:0]                                  nprsp_status,
  output wire                                        nprsp_cpl,
  output wire [7:0]                                  nprsp_cpl_segment,
  output wire [8:0]                                  nprsp_dst_segment,
  output wire [1:0] nprsp_resp,
  output wire [SLV_BUS_DATA_WIDTH-1:0]               nprsp_data,
  output wire                                        nprsp_last,
  // DBI indication
  output wire                                        dbi_response,
  input                                              srsp_np_ready
  );
  // -------------------------------------------------------------------------------------
  // Local parameters
  // -------------------------------------------------------------------------------------
  localparam NUM_DATA_PAR_BITS   = 32/CX_RAS_PROT_RANGE;
  localparam NUM_DATA_PAR_BLOCKS = NUM_DATA_PAR_BITS;

  // {tag, resp, data}
  localparam MUX_INFO_WD = { MAX_SLV_TAG_PW
                           + 2
                           + SLV_BUS_DATA_WIDTH
// Two extra bits for dbi_resp TDISP (dbi_err_crs_ur)
                           };

  localparam RSP_INTF_WD = { 1                // rspmux_valid_dbi
                           + 1                // rspmux_valid_npf
                           + 1                // rspmux_last
                           + MUX_INFO_WD      // rspmux_intf
                           + 1                // s_nprspf_to
                           + 1                // s_nprspf_ep
                           + 3                // s_nprspf_tc
                           + 1                // s_nprspf_ido
                           + 1                // s_nprspf_ns
                           + 1                // s_nprspf_ro
                           + 3                // s_nprspf_status
                           + 1                // s_nprspf_cpl
                           + 8                // cpl_segment
                           + 9                // dst_segment
                           };
   localparam [8:0] BUS_INIT_BYTE = CX_RAS_PARITY_MODE ? 9'b100000000 : 9'b000000000;
   localparam BYTE_WD_W_PAR = 9;
  localparam PARITY_BIT = CX_RAS_PARITY_MODE ? 1'b1 : 1'b0;
   localparam [SLV_BUS_DATA_WIDTH-1:0] SLV_BUS_INIT = {SLAVE_BUS_DATA_WIDTH/8{BUS_INIT_BYTE}};


  // -------------------------------------------------------------------------------------
  // Internal Wire/Reg
  // -------------------------------------------------------------------------------------
  wire [31+NUM_DATA_PAR_BITS:0]            s_dbi_data_w_par;
  reg  [SLV_BUS_DATA_WIDTH-1:0]            s_dbi_data;
  wire [MUX_INFO_WD-1:0]                   s_nprspf_intf, s_dbi_intf;
  wire                                     rspmux_ready_dbi, rspmux_ready_npf;
  wire                                     nprsp_valid_dbi, nprsp_valid_npf;

  wire                                     s_dbi_valid_en;
  wire                                     s_dbi_valid;
  wire                                     s_nprspf_valid_en;
  wire                                     s_nprspf_valid;

  wire                                     rspmux_valid_dbi, rspmux_valid_npf, rspmux_last;
  wire [MUX_INFO_WD-1:0]                   rspmux_intf;
  wire                                     s_pdly_ready;

  wire                                     s_nprspf_ido;
  wire                                     s_nprspf_to, s_nprspf_ep, s_nprspf_ns;
  wire                                     s_nprspf_ro, s_nprspf_cpl;
  wire [2:0]                               s_nprspf_tc, s_nprspf_status;
  wire [7:0]                               s_nprspf_cpl_segment;
  wire [8:0]                               s_nprspf_dst_segment;
  wire [RSP_INTF_WD-1:0]                   s_rsp_intf;
  wire                                     pdly_halt;

  wire [RSP_INTF_WD-1:0]                   pdly_rsp_intf;
  wire                                     pdly_valid_dbi, pdly_valid_npf, pdly_last;
  wire [MUX_INFO_WD-1:0]                   pdly_intf;

  wire                                     s_pdly_valid;
  wire                                     s_srsp_np_halt;


  // -------------------------------------------------------------------------------------
  // Design
  // -------------------------------------------------------------------------------------

  // Add parity
  assign s_dbi_data_w_par = fn_data_w_par(dbi_data);
  // Pad the DB read data
  always @(*) begin : proc_comb_pad_db_data_par
    s_dbi_data                           = SLV_BUS_INIT;
    s_dbi_data[(31+NUM_DATA_PAR_BITS):0] = s_dbi_data_w_par;
  end

  // Build common interface buses
  assign s_nprspf_intf = { nprspf_tag, nprspf_resp, nprspf_data };
  assign s_dbi_intf    = { dbi_tag, dbi_resp, s_dbi_data };


  // -------------------------------------------------------------------------------------
  // Order wire and data bus responses
  // Search the ordered halt vector to establish if the DB response can be sent to the
  // AXI slave. If halted suppress the valid and de-assert the ready.
  assign s_dbi_valid_en = !atm_cpl_seg_halt[dbi_tag];
  assign s_dbi_valid    = dbi_valid && s_dbi_valid_en;

  assign s_nprspf_valid_en = !atm_cpl_seg_halt[nprspf_tag];
  assign s_nprspf_valid    = nprspf_valid && s_nprspf_valid_en;

  // Hold off out of order responses
  assign nprsp_db_ready = s_dbi_valid_en    ? rspmux_ready_dbi : 1'b0;
  assign nprsp_np_ready = s_nprspf_valid_en ? rspmux_ready_npf : 1'b0;

  // Instantiate response mux, common interface signals only
  DWC_pcie_bridge_intf_mux
  
 #(.INTF_WD                                (MUX_INFO_WD)
  ,.MULTI_BEAT                             (1)
  )
  u_rspmux
  (.clk                                    (slv_aclk)
  ,.rst_n                                  (slv_aresetn)
  // -------------------------------------------------------------------------------------
  // Interface A (Data bus Non-posted response)
  ,.valid_a                                (s_dbi_valid)
  ,.last_a                                 (dbi_last)
  ,.intf_a                                 (s_dbi_intf)
  ,.ready_a                                (rspmux_ready_dbi)
  // -------------------------------------------------------------------------------------
  // Interface B (Non-posted read response)
  ,.valid_b                                (s_nprspf_valid)
  ,.last_b                                 (nprspf_last)
  ,.intf_b                                 (s_nprspf_intf)
  ,.ready_b                                (rspmux_ready_npf)
  // -------------------------------------------------------------------------------------
  // Muxed Interface (Non-posted response)
  ,.mux_valid_a                            (rspmux_valid_dbi)
  ,.mux_valid_b                            (rspmux_valid_npf)
  ,.mux_last                               (rspmux_last)
  ,.mux_intf                               (rspmux_intf)
  ,.ready                                  (s_pdly_ready)
  );

  assign s_pdly_ready = !pdly_halt;

  // Pack response interface signals
  assign s_nprspf_to       = rspmux_valid_npf ? nprspf_to       : 1'b0;
  assign s_nprspf_ep       = rspmux_valid_npf ? nprspf_ep       : 1'b0;
  assign s_nprspf_tc       = rspmux_valid_npf ? nprspf_tc       : 3'b0;
  assign s_nprspf_ido      = rspmux_valid_npf ? nprspf_ido      : 1'b0;
  assign s_nprspf_ns       = rspmux_valid_npf ? nprspf_ns       : 1'b0;
  assign s_nprspf_ro       = rspmux_valid_npf ? nprspf_ro       : 1'b0;

  assign s_nprspf_status   = rspmux_valid_npf ? nprspf_status       :                             3'b0;

  assign s_nprspf_cpl      = rspmux_valid_npf ? nprspf_cpl      : 1'b0;
  assign s_nprspf_cpl_segment = rspmux_valid_npf ? nprspf_cpl_segment : '0;
  assign s_nprspf_dst_segment = rspmux_valid_npf ? nprspf_dst_segment : '0;
  assign s_rsp_intf = { rspmux_valid_dbi
                      , rspmux_valid_npf
                      , rspmux_last
                      , rspmux_intf
                      , s_nprspf_to
                      , s_nprspf_ep
                      , s_nprspf_tc
                      , s_nprspf_ido
                      , s_nprspf_ns
                      , s_nprspf_ro
                      , s_nprspf_status
                      , s_nprspf_cpl
                      , s_nprspf_cpl_segment
                      , s_nprspf_dst_segment
                      };

  // -------------------------------------------------------------------------------------
  // Instantiate pipe delay
  delay_1_w_stalling
  
  #(.DELAY_EN                              (1)
   ,.WD                                    (RSP_INTF_WD + 1)
   ,.CAN_STALL                             (1)
  )
  u_pdly
  (
    .clk        (slv_aclk),
    .rst_n      (slv_aresetn),
    .clear      (1'b0),
    .din        ({s_rsp_intf, (rspmux_valid_dbi & nprsp_db_ready)}), // flagged as DBI response when accepted
    .stallout   (pdly_halt),
    .dout       ({pdly_rsp_intf, dbi_response}),
    .stall      (s_srsp_np_halt)
  );

  // Assign outputs
  // Unpack
  assign { pdly_valid_dbi
         , pdly_valid_npf
         , pdly_last
         , pdly_intf
         , nprsp_to
         , nprsp_ep
         , nprsp_tc
         , nprsp_ido
         , nprsp_ns
         , nprsp_ro
         , nprsp_status
         , nprsp_cpl
         , nprsp_cpl_segment
         , nprsp_dst_segment
         } = pdly_rsp_intf;

  assign s_pdly_valid = pdly_valid_dbi || pdly_valid_npf;
  assign nprsp_valid  = s_pdly_valid;
  assign nprsp_last   = pdly_last;
  // Unpack common interface signals
  assign { nprsp_tag, nprsp_resp, nprsp_data } = pdly_intf;

  assign s_srsp_np_halt = s_pdly_valid && !srsp_np_ready;

  // -------------------------------------------------------------------------------------
  // Functions
  // -------------------------------------------------------------------------------------
  // Data with parity
  function automatic [31+NUM_DATA_PAR_BLOCKS:0] fn_data_w_par;
    input [31:0] s_data_wo_par;

    integer i, j;
    reg [CX_RAS_PROT_RANGE-1:0] s_data_for_par;

    begin
    fn_data_w_par  = {(32+NUM_DATA_PAR_BLOCKS){1'b0}};
    s_data_for_par = {CX_RAS_PROT_RANGE{1'b0}};

      for (i=0; i<(NUM_DATA_PAR_BLOCKS); i=i+1) begin
         for (j=0; j<CX_RAS_PROT_RANGE; j=j+1) begin
    s_data_for_par[j]=s_data_wo_par[i*CX_RAS_PROT_RANGE +j];
    fn_data_w_par[i*CX_RAS_PROT_RANGE +j+i] = s_data_wo_par[i*CX_RAS_PROT_RANGE +j];
         end
          fn_data_w_par[(i+1)*CX_RAS_PROT_RANGE +i] = CX_RAS_PARITY_MODE ? ~(^s_data_for_par) : ^s_data_for_par;
      end
    end
  endfunction

endmodule
