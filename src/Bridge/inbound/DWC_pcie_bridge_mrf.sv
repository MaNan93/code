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
// ---    $DateTime: 2023/12/22 07:15:34 $
// ---    $Revision: #21 $
// ---    $Id: //dwh/pcie_iip/main/fairbanks/design/Bridge/inbound/DWC_pcie_bridge_mrf.sv#21 $
// ---------------------------------------------------------------------------------------
// Module Description:
//
// ---------------------------------------------------------------------------------------
`include "include/DWC_pcie_ctl_all_defs.svh"
`include "Bridge/inbound/DWC_pcie_bridge_ib_pkg.svh"

`include "Bridge/inbound/DWC_pcie_bridge_atop_pkg.svh"
`include "DWC_pcie_ctl_pkg.svh"
 module DWC_pcie_bridge_mrf

  import DWC_pcie_bridge_atop_pkg::*;
  import DWC_pcie_bridge_ib_pkg::*;
  import DWC_pcie_ctl_pkg::ras_dp_err_log_t;
  import DWC_pcie_ctl_pkg::MAX_RAS_PROT_CHK_N;
  import DWC_pcie_ctl_pkg::RAS_ERROR_LOG_WD;
  import DWC_pcie_ctl_pkg::ras_dp_err_inj_t;
  #(
    parameter MRF_WR_NOT_RD_QUEUE          = 1'b1,  //When 1 it's on the write path, when 0 it's on the read path
    parameter DC_INBD_HEADER_PNP_WD        = `DC_INBD_HEADER_PNP_WD,
    parameter DC_INBD_HEADER_PNP_WD_NP     = `DC_INBD_HEADER_PNP_WD_NP,
    parameter DC_INBD_MISCINFO_WD          = `DC_INBD_MISCINFO_WD,
    parameter MSTR_DATA_WD_GT_CORE_DATA_WD = `CC_MSTR_BUS_DATA_WIDTH > `CC_CORE_DATA_BUS_WD,
    parameter CORE_REQ_DATA_BUS_WD         = MSTR_DATA_WD_GT_CORE_DATA_WD ? `CC_MSTR_BUS_DATA_WIDTH : `CC_CORE_DATA_BUS_WD,
    parameter CORE_REQ_DATA_BUS_WD_NP      = MSTR_DATA_WD_GT_CORE_DATA_WD ?  `MASTER_BUS_DATA_WIDTH : `PCIE_CORE_DATA_BUS_WD,
    parameter CC_CORE_ADDR_BUS_WD          = `CC_CORE_ADDR_BUS_WD,
    parameter CC_CORE_ADDR_BUS_WD_NP       = `FLT_Q_ADDR_WIDTH,
    parameter CX_RAS_RAM_PROT_RANGE        = `CX_RAS_RAM_PROT_RANGE,
    parameter CX_RAS_PROT_RANGE            = `CX_RAS_PROT_RANGE,
    parameter CX_RAS_PARITY_MODE           = `CX_RAS_PARITY_MODE,
    parameter IB_REQ_CDC_RAM_DP            = 12,
    parameter IB_REQ_CDC_RAM_ADDR_WD       = 4,
    parameter IB_REQ_CDC_RAM_DATA_WD       = 100,
    parameter IB_REQ_CDC_RAM_DATA_WD_NOECC = 100,
    parameter IB_REQ_CDC_RAM_RD_LATENCY    = 1,
    parameter CC_MRF_C2A_FIFO_SYNC_REGS    = 2, // double registered CDC
    parameter CC_MRF_A2C_FIFO_SYNC_REGS    = 2, // double registered CDC
    parameter CC_MRF_C2A_FIFO_HOLD_RD_ADDR = 1, //If the full flag is used the push interface will clobber the held read data.
    parameter CC_MAX_MSTR_TAG_P            = `CC_MAX_MSTR_TAG_PW,
    parameter CC_CORE_DATA_BUS_WD          = `CC_CORE_DATA_BUS_WD,
    parameter REQ_NW                       = MSTR_DATA_WD_GT_CORE_DATA_WD ? `CC_MSTR_NW : `CX_NW,
    parameter CC_MSTR_BUS_DATA_WIDTH       = `CC_MSTR_BUS_DATA_WIDTH,
    parameter CC_MSTR_BUS_WSTRB_WIDTH      = `CC_MSTR_BUS_WSTRB_WIDTH,
    parameter CC_MSTR_BUS_ADDR_WIDTH       = `CC_MSTR_BUS_ADDR_WIDTH,
    parameter CC_MAX_MSTR_TAG_PW           = `CC_MAX_MSTR_TAG_PW,
    parameter CC_MSTR_BE_CTRL_WIDTH        = `CC_MSTR_BE_CTRL_WIDTH,
    parameter CC_MSTR_NW                   = `CC_MSTR_NW,
    parameter CC_MSTR_NUM_CONV_WD          = `CC_MSTR_NUM_CONV_WD,
    parameter CX_NW                        = `CX_NW,
    parameter CC_MSTR_MTU_PW               = `CC_MSTR_MTU_PW,
    parameter CORE_REQ_DATA_BUS_WSTRB_WD   = MSTR_DATA_WD_GT_CORE_DATA_WD ? `CC_MSTR_BUS_WSTRB_WIDTH : `CC_CORE_DATA_BUS_WSTRB_WD,
    parameter CC_RDQ_RAM_DAWD              = `DC_INBD_HEADER_PNP_WD,
    parameter NUM_CONV_WIDTH               = `CC_MSTR_CONV_FAC_WIDTH,

    parameter MSTR_ADDR_WD_WO_PAR          = `MASTER_BUS_ADDR_WIDTH,
    parameter RAS_DP_ID                    = 3,
    parameter RAM_RAS_DP_ID                = 0,

    // -------------------------------------------------------------------------------------
    // Parameters not modified by an instantiation parameter assignment
    // -------------------------------------------------------------------------------------
    parameter TP       = `TP
    )
   
                             (
        input                                     mstr_aclk, // Bridge Master Interface Clock
        input                                     mstr_arstn, // Bridge Master Clock Reset
        input                                     core_clk,
        input                                     core_rstn,

    //2pRAM interface
        output wire [IB_REQ_CDC_RAM_ADDR_WD-1:0]  mrf_c2a_ram_addra,
        output wire [IB_REQ_CDC_RAM_ADDR_WD-1:0]  mrf_c2a_ram_addrb,
        output wire                               mrf_c2a_ram_wea,
        output wire                               mrf_c2a_ram_enb,
        input [IB_REQ_CDC_RAM_DATA_WD-1:0]        mrf_c2a_ram_doutb,
        output wire [IB_REQ_CDC_RAM_DATA_WD-1:0]  mrf_c2a_ram_dina,
  // ---------------------------------------------------------------------------
  // RAS.DP register interface
  // ---------------------------------------------------------------------------
        input                                     cfg_ras_correct,
        output wire                               mrf_ras_recc_corr_cnt_pulse,
        output wire                               mrf_ras_recc_ucorr_cnt_pulse,
        output wire [IB_REQ_CDC_RAM_ADDR_WD-1:0]  mrf_ras_recc_cnt_addr,
        output wire                               mstr_req_addr_parerr,
        output wire                               mstr_req_data_parerr,
        output ras_dp_err_log_t                   mrf_recc_cnt_ras_dp_err_log,
        output ras_dp_err_log_t                   mstr_req_ad_ras_dp_err_log,
        output ras_dp_err_log_t                   mstr_req_dt_ras_dp_err_log,
    input  ras_dp_err_inj_t                         axi_bridge_ras_dp_err_inj_core_clk,
    input  ras_dp_err_inj_t                         ras_dp_err_inj_mstr_aclk,

        // Input TLP interface
        input [DC_INBD_HEADER_PNP_WD-1:0]         inbd_hdr_pnp,
        input [CC_CORE_DATA_BUS_WD-1:0]           inbd_data_pnp,
        output wire                               inbd_halt_pnp,

        //Interface with the master completion buffer @ mstr_aclk
        output wire                               mrf_reqmcb_np_valid,
        output wire [CC_MAX_MSTR_TAG_PW-1:0]      mrf_reqmcb_mstrid,
        output wire                               mrf_reqmcb_last,
        output                                    mrf_reqmcb_atomic,
        input                                     arbmcb_halt_mrf,

        // Interface with the AXI master
        // AMBA master request interface
        output wire [CC_MSTR_BUS_ADDR_WIDTH-1:0]  maddr, // GIF interface signals. Refer to an internal spec.
        output wire                               mstrobe, // Control strobe to indicate read or write
        output wire                               mstrobe_last, // Control strobe to indicate last beat of formed TLP.
        output wire [CC_MSTR_MTU_PW -1:0]         mlen, // Request burst length in byte
        output wire [CC_MSTR_BUS_DATA_WIDTH-1:0]  mdata, // Request burst data
        output wire [CC_MSTR_BUS_WSTRB_WIDTH-1:0] mbe, // Request burst data byte enable (strobes). Here we only Support dword aligned transfer
        output wire [CC_MSTR_BE_CTRL_WIDTH-1:0]   mbe_ctrl, // byte enable ctrl for NCBE
        output wire [CC_MAX_MSTR_TAG_PW-1 :0]     mid, // Request a burst with ID
        output wire                               mabort, // Aborted request (TLP, DLLP)
        output wire                               mlast, // last decomposed TLP
        output wire [DC_INBD_MISCINFO_WD-1:0]     mmisc, //Bundles all misc info buses
        input                                     saccept // Slave accept the master request

    );

   ///////////////////////////////
   // Internal parameters
   ///////////////////////////////

   localparam S_REQ_IDLE             = 1'b0;
   localparam S_REQ_WR_BURST         = 1'b1;

   localparam REQ_DP_WIDTH = 3+
                             CC_MAX_MSTR_TAG_PW +
                             CC_MSTR_BUS_ADDR_WIDTH +
                             CC_MSTR_MTU_PW +
                             CC_MSTR_BUS_WSTRB_WIDTH +
                             CC_MSTR_BE_CTRL_WIDTH +
                             1+
                             DC_INBD_MISCINFO_WD +
                             CC_MSTR_BUS_DATA_WIDTH;
   localparam C2A_FIFO_TST_MODE  = 0;
   localparam REQ_N_CYCLE_DELAY  = 1;
   localparam REQ_CAN_STALL      = 1;

   localparam ADDR_PAR_WD          = CC_MSTR_BUS_ADDR_WIDTH - MSTR_ADDR_WD_WO_PAR;
   localparam ADDR_PAR_CALC_WIDTH  = 8; // Just the lower 2 MSB addr bits are manipulated, so parity checking is limited to 8 bits
   // Number of parity address blocks per 32/64 bit address
   localparam NUM_ADDR_PAR_BLOCKS  = CC_CORE_ADDR_BUS_WD_NP/CX_RAS_PROT_RANGE;
   // Number of parity data blocks
   localparam NUM_DATA_PAR_BLOCKS  = CORE_REQ_DATA_BUS_WD_NP/CX_RAS_PROT_RANGE;
   localparam RAS_DP_ERR_LOG_WD = $clog2(MAX_RAS_PROT_CHK_N);

   localparam [8:0] INIT_BYTE = `CX_RAS_PARITY_MODE ? 9'b100000000 : 9'b000000000;
   localparam DATA_N_BYTES    = CC_CORE_DATA_BUS_WD/9;
   localparam [CC_MSTR_BUS_ADDR_WIDTH -1:0] ADDR_BUS_INIT = {MSTR_ADDR_WD_WO_PAR/8{INIT_BYTE}};

   localparam INBD_HDR_PNP_BIT_LEN = (((`INBD_HDR_PNP_RANGE_DW_LEN_HIGH) - (`INBD_HDR_PNP_RANGE_DW_LEN_LOW)) + 5);
   localparam [7:0] ATOP_CAS_32  = 32 ;
   localparam [7:0] ATOP_CAS_64  = 64 ;
   localparam [7:0] ATOP_CAS_96  = 96 ;
   localparam [7:0] ATOP_CAS_128 = 128;
   localparam [8:0] ATOP_CAS_256 = 256;
// Bit length of data with or without RAS -> 1 parity bit for 8 bits of data
   localparam [7:0] ATOP_CAS_32_R  = 36 ;
   localparam [7:0] ATOP_CAS_64_R  = 72 ;
   localparam [7:0] ATOP_CAS_96_R  = 108;
   localparam [7:0] ATOP_CAS_128_R = 144;
   localparam [8:0] ATOP_CAS_256_R = 288;
   ///////////////////////////////
   // Internal signals
   ///////////////////////////////

   // Logics
   wire                                       low;   // Logic "0"
   wire                                       high;  // Logic "1"


   // Internal state machine
   reg                                        r_mstr_req_state;
   reg                                        s_mstr_req_state;

   //Up-convertion related signals
   reg  [DC_INBD_HEADER_PNP_WD-1:0]           uc_inbd_hdr_pnp;
   wire [DC_INBD_HEADER_PNP_WD_NP-1:0]        s_uc_inbd_hdr_pnp;
   reg  [DC_INBD_HEADER_PNP_WD-1:0]           r_inbd_hdr_pnp;
   wire [CORE_REQ_DATA_BUS_WD-1:0]            uc_inbd_data_pnp;
   wire [CORE_REQ_DATA_BUS_WD_NP-1:0]         s_uc_inbd_data_pnp;
   wire                                       uc_inbd_halt_pnp;
   wire                                       uc_hv;
   wire                                       uc_dv;
   wire                                       uc_eot;
   wire [CC_MSTR_NW-1:0]                      uc_dwen;

   // CDC related signals
   wire                                       c2a_push_req_n;
   wire [IB_REQ_CDC_RAM_DATA_WD_NOECC-1:0]    c2a_push_data;
   wire                                       c2a_push_f;
   wire                                       c2a_data_valid;
   wire [IB_REQ_CDC_RAM_DATA_WD_NOECC-1:0]    c2a_pop_data;
   wire [DC_INBD_HEADER_PNP_WD_NP-1:0]        w_c2a_pop_data;
   wire [DC_INBD_HEADER_PNP_WD_NP-1:0]        s_cdc_inbd_hdr_pnp;
   wire [CORE_REQ_DATA_BUS_WD_NP-1:0]         s_cdc_inbd_data_pnp;
   wire [DC_INBD_HEADER_PNP_WD-1:0]           ss_cdc_inbd_hdr_pnp;
   wire [CORE_REQ_DATA_BUS_WD-1:0]            ss_cdc_inbd_data_pnp;
   wire                                       c2a_ready;

   //Decoded signals from the inbound bus
   wire                                       mstr_req_hv;
   wire                                       mstr_req_dv;
   wire                                       mstr_req_eot;
   wire [1:0]                                 mstr_req_fmt;
   wire [4:0]                                 mstr_req_type;

   reg [CC_MSTR_BUS_ADDR_WIDTH -1:0]          mstr_req_addr;
   wire [1:0]                                 mstr_req_addr_low;
   wire [9:0]                                 r_mstr_req_dw_len;
   reg [CC_MSTR_BUS_ADDR_WIDTH -1:0]          r_mstr_req_addr;
   wire [1:0]                                 r_mstr_req_addr_low;
   wire [9:0]                                 mstr_req_dw_len;
   wire [3:0]                                 mstr_req_first_be;
   wire [3:0]                                 mstr_req_last_be;
   wire [3:0]                                 r_mstr_req_first_be;
   wire [3:0]                                 r_mstr_req_last_be;

   //Derived signals from the request interface
   wire                                       mstr_req_rd;
   wire                                       mstr_req_msg;
   wire                                       r_mstr_req_msg;
   wire                                       mstr_req_msgd;
   wire                                       r_mstr_req_msgd;
   wire                                       mstr_req_hdr_uppr_bytes_valid;
   wire                                       r_mstr_req_hdr_uppr_bytes_valid;


   //Latched version of the inbound bus
   reg [DC_INBD_HEADER_PNP_WD-1:0]            r_cdc_inbd_hdr_pnp;
   wire [DC_INBD_HEADER_PNP_WD-1:0]           cdc_inbd_hdr_pnp;
   reg [CORE_REQ_DATA_BUS_WD-1:0]             r_cdc_inbd_data_pnp;
   wire [CORE_REQ_DATA_BUS_WD-1:0]            cdc_inbd_data_pnp;
   wire                                       cdc_inbd_halt_pnp;
   wire                                       cdc_inbd_halt_pnp_mcb;

   //Parity calculations / Check
   wire                                       mstr_calc_new_parity;
   reg                                        r_mstr_calc_new_parity;

   wire [CORE_REQ_DATA_BUS_WD-1:0]            ctrl_mdata;

   //state machine generated signals
   wire                                       ctrl_state_idle;
   wire                                       ctrl_state_wr;
   wire                                       ctrl_mstrobe;
   wire                                       ctrl_mstrobe_last;
   reg [CC_MSTR_BUS_ADDR_WIDTH-1:0]           ctrl_maddr;
   wire [CC_MAX_MSTR_TAG_PW -1 :0]            ctrl_mid;
   wire                                       ctrl_mlast_tlp;
   wire [12:0]                                ctrl_mlen;
   wire [CORE_REQ_DATA_BUS_WSTRB_WD-1:0]      ctrl_mbe;
   wire [CC_MSTR_BE_CTRL_WIDTH -1:0]          ctrl_mbe_ctrl;
   wire                                       ctrl_mabort;


   wire [DC_INBD_MISCINFO_WD-1:0]             ctrl_mmisc;

   //Inbound header generated by the FSM
   wire [DC_INBD_HEADER_PNP_WD-1:0]           ctrl_inbd_hdr_pnp;

   //Signals below are FSM generated signals, to be bundled in the misc inf
   wire                                       ctrl_wr_dvld;

   //Decoded message type
   wire                                       ctrl_req_msg;
   wire                                       ctrl_req_msgd;

   //Signals after the data conversion
   wire                                       dc_mstrobe;
   wire                                       dc_mstrobe_last;
   wire [CC_MSTR_BUS_ADDR_WIDTH-1:0]          dc_maddr;
   wire [CC_MAX_MSTR_TAG_PW-1 :0]             dc_mid;
   wire                                       dc_mlast_tlp;
   wire [CC_MSTR_MTU_PW -1:0]                 dc_mlen;
   wire [CC_MSTR_BUS_WSTRB_WIDTH -1:0]        dc_mbe;
   wire [CC_MSTR_BE_CTRL_WIDTH -1:0]          dc_mbe_ctrl;
   wire                                       dc_mabort;
   wire [DC_INBD_MISCINFO_WD-1:0]             dc_mmisc;
   wire [CC_MSTR_BUS_DATA_WIDTH-1:0]          dc_mdata;
   wire                                       dc_saccept;

   //Delay stalling signals
   wire                                       req_halt_in;
   wire                                       st_req_halt_out;
   wire                                       st_saccept;
   wire [REQ_DP_WIDTH -1:0]                   st_req_stall_din;    // Request stall data in
   wire [REQ_DP_WIDTH -1:0]                   st_req_stall_dout;   // Request stall data out
   reg [REQ_DP_WIDTH-2:0]                     r_st_req_stall_dout;

   // Do not delete these signals; they aren't used inside the module but they are being probed
   // by the performance (latency) testbench
   wire                                       uc_inbd_hv;
   wire                                       uc_inbd_dv;
   wire                                       uc_inbd_eot;

   // Input related signals
   logic [DC_INBD_HEADER_PNP_WD-1:0]          s_inbd_hdr_pnp;
   logic [CC_CORE_DATA_BUS_WD-1:0]            s_inbd_data_pnp;
   logic                                      s_inbd_halt_pnp;


   /////////////////////////////
   //  Internal design
   ////////////////////////////
   assign low  = 1'b0;
   assign high = 1'b1;

  enum logic [1:0] {ATOP_STORE, ATOP_FEEDTHROUGH, ATOP_HALT} mrf_atop_state, mrf_atop_next_state;
  generate
    if (MRF_WR_NOT_RD_QUEUE) begin : gen_fsm_wrq
      // FSM for atomic CAS requests
      // When in the presence of a CAS Atomic operation with an address not aligned to the total size of the data there is a need to reverse the Compare and Swap value.
      // In a case where the data width is greater than the bus width, the oncoming pieces of the Compare value need to be buffered, then sent after the Swap value.
      // If the bus width is greater or equal than the data width, the two values can be simple swapped.
    
      logic                                    s_atop_cas;
      logic                                    s_atop_inbd_hv;
      logic                                    s_atop_inbd_dv;
      logic                                    s_atop_inbd_eot;
      logic                                    s_atop_addr_nalign;
      pkg_atop_fmt_type_e                      s_atop_fmt_type;
      logic [INBD_HDR_PNP_BIT_LEN:0]           s_atop_bit_len;
      logic [INBD_HDR_PNP_BIT_LEN-1:0]         s_atop_bit_half_len, r_atop_bit_half_len;
      logic [$clog2(INBD_HDR_PNP_BIT_LEN):0]   s_atop_bit_len_log2;
      logic [143:0]                            s_atop_memdata, r_atop_memdata;
      logic [7:0]                              r_atop_memdata_addr;
       
      logic [DC_INBD_HEADER_PNP_WD-1:0]        r_atop_inbd_hdr_pnp [3:0];
    
      logic                                    s_atop_cas_naligned_nhalt;
      logic                                    s_atop_dt_len_gt_bus_wd;
  
      assign s_atop_cas          = s_atop_fmt_type inside {
                                     CAS32
                                    ,CAS64};
      assign s_atop_bit_len_log2 = ($clog2(INBD_HDR_PNP_BIT_LEN) + 1)'(log2((`CC_MSTR_MTU_PW)'(s_atop_bit_len >> 4)));
  
      assign s_atop_inbd_hv      = inbd_hdr_pnp[`INBD_HDR_PNP_RANGE_HV_HIGH:`INBD_HDR_PNP_RANGE_HV_LOW];
      assign s_atop_inbd_dv      = inbd_hdr_pnp[`INBD_HDR_PNP_RANGE_DV_HIGH:`INBD_HDR_PNP_RANGE_DV_LOW];
      assign s_atop_inbd_eot     = inbd_hdr_pnp[`INBD_HDR_PNP_RANGE_EOT_HIGH:`INBD_HDR_PNP_RANGE_EOT_LOW];
      assign s_atop_bit_len      = (INBD_HDR_PNP_BIT_LEN+1)'(inbd_hdr_pnp[`INBD_HDR_PNP_RANGE_DW_LEN_HIGH:`INBD_HDR_PNP_RANGE_DW_LEN_LOW] << 5);
      assign s_atop_addr_nalign  = s_atop_bit_len_log2 == 2 ? inbd_hdr_pnp[`INBD_HDR_PNP_RANGE_ADDR_LOW + 2] :
                                   s_atop_bit_len_log2 == 3 ? inbd_hdr_pnp[`INBD_HDR_PNP_RANGE_ADDR_LOW + 3] :
                                   s_atop_bit_len_log2 == 4 ? inbd_hdr_pnp[`INBD_HDR_PNP_RANGE_ADDR_LOW + 4] :
                                   s_atop_bit_len_log2 == 5 ? inbd_hdr_pnp[`INBD_HDR_PNP_RANGE_ADDR_LOW + 5] :
                                   '0;
      assign s_atop_fmt_type     = pkg_atop_fmt_type_e'({inbd_hdr_pnp[`INBD_HDR_PNP_RANGE_FMT_HIGH:`INBD_HDR_PNP_RANGE_FMT_LOW], inbd_hdr_pnp[`INBD_HDR_PNP_RANGE_TYPE_HIGH:`INBD_HDR_PNP_RANGE_TYPE_LOW]});
      assign s_atop_bit_half_len = (s_atop_inbd_hv & mrf_atop_state == ATOP_STORE) ? (INBD_HDR_PNP_BIT_LEN)'(s_atop_bit_len >> 1) : r_atop_bit_half_len;
  
      assign s_atop_cas_naligned_nhalt = s_atop_cas & s_atop_addr_nalign & s_atop_inbd_dv;
      assign s_atop_dt_len_gt_bus_wd   = s_atop_bit_len > `PCIE_CORE_DATA_BUS_WD;

      always_ff @(posedge core_clk or negedge core_rstn) begin : seq_atop_half_len
        if (!core_rstn) begin
          r_atop_bit_half_len <= #TP '0;
        end else begin
          if (s_atop_inbd_hv)
            r_atop_bit_half_len <= #TP s_atop_bit_half_len;
        end
      end
  
      always_ff @(posedge core_clk or negedge core_rstn) begin : seq_atop_state
        if (!core_rstn) begin 
          mrf_atop_state <= #TP ATOP_STORE;
        end else begin
          mrf_atop_state <= #TP mrf_atop_next_state;
        end
      end
  
      always_comb begin : comb_atop_next_state
        mrf_atop_next_state = mrf_atop_state;
        if (!s_inbd_halt_pnp) begin
          case(mrf_atop_state)
            ATOP_STORE:
              if (s_atop_cas_naligned_nhalt && s_atop_dt_len_gt_bus_wd) begin
                if (r_atop_memdata_addr == 8'(s_atop_bit_half_len - `PCIE_CORE_DATA_BUS_WD)) begin
                  mrf_atop_next_state = ATOP_FEEDTHROUGH;
                end
              end else begin
                mrf_atop_next_state = ATOP_STORE;
              end
            ATOP_FEEDTHROUGH:
              if (s_atop_inbd_eot) begin
                mrf_atop_next_state = ATOP_HALT;
              end
            ATOP_HALT:
              if (r_atop_memdata_addr == 8'(s_atop_bit_half_len - `PCIE_CORE_DATA_BUS_WD)) begin
                mrf_atop_next_state = ATOP_STORE;
              end
            default:
              mrf_atop_next_state = ATOP_STORE;
          endcase
        end
      end
  
      always_comb begin : comb_atop_s_data
        case(mrf_atop_state)
          ATOP_STORE:
            if (s_atop_cas_naligned_nhalt) begin
              if (!s_atop_dt_len_gt_bus_wd) begin
                s_inbd_data_pnp = s_atop_bit_len == ATOP_CAS_64  ? {{(DATA_N_BYTES- 8){INIT_BYTE}},inbd_data_pnp[0 +: ATOP_CAS_32_R ],inbd_data_pnp[ATOP_CAS_32_R  +: ATOP_CAS_32_R ]} :
 s_atop_bit_len == ATOP_CAS_128 ? {{(DATA_N_BYTES-16){INIT_BYTE}},inbd_data_pnp[0 +: ATOP_CAS_64_R ],inbd_data_pnp[ATOP_CAS_64_R  +: ATOP_CAS_64_R ]} :
 s_atop_bit_len == ATOP_CAS_256 ? {{(DATA_N_BYTES-32){INIT_BYTE}},inbd_data_pnp[0 +: ATOP_CAS_128_R],inbd_data_pnp[ATOP_CAS_128_R +: ATOP_CAS_128_R]} :
                                  '0;
              end else begin
                s_inbd_data_pnp = '0;
              end
            end else begin
              s_inbd_data_pnp = inbd_data_pnp;
            end
          ATOP_FEEDTHROUGH:
            s_inbd_data_pnp = inbd_data_pnp;
          ATOP_HALT:
            s_inbd_data_pnp =



                              '0;
          default:
            s_inbd_data_pnp = '0;
        endcase
      end
  
      always_ff @(posedge core_clk or negedge core_rstn) begin
        if (!core_rstn) begin
          r_atop_memdata_addr <= #TP '0;
        end else begin
          if (((mrf_atop_state == ATOP_STORE && s_atop_cas_naligned_nhalt && !s_inbd_halt_pnp && s_atop_dt_len_gt_bus_wd) || (mrf_atop_state == ATOP_HALT && !s_inbd_halt_pnp)) && (mrf_atop_state == mrf_atop_next_state)) begin
            r_atop_memdata_addr <= #TP r_atop_memdata_addr + `PCIE_CORE_DATA_BUS_WD;
          end else if (mrf_atop_state != mrf_atop_next_state) begin
            r_atop_memdata_addr <= #TP '0;
          end else begin
            r_atop_memdata_addr <= #TP r_atop_memdata_addr;
          end
        end
      end
  
      always_comb begin : comb_atop_datamem
        s_atop_memdata = r_atop_memdata;
        case(mrf_atop_state)
          ATOP_STORE:
            if (s_atop_cas_naligned_nhalt && !s_inbd_halt_pnp && s_atop_dt_len_gt_bus_wd) begin
              case(r_atop_memdata_addr)




                                    default     : s_atop_memdata                                       = r_atop_memdata;
              endcase
            end else begin
              s_atop_memdata = r_atop_memdata;
            end
          ATOP_FEEDTHROUGH, ATOP_HALT:
            s_atop_memdata = r_atop_memdata;
          default: 
            s_atop_memdata = '0;
        endcase
      end
  
      always_ff @(posedge core_clk or negedge core_rstn) begin : seq_atop_memdata
        if (!core_rstn) begin
          r_atop_memdata  <= #TP '0;
        end else begin
          r_atop_memdata  <= #TP s_atop_memdata;
        end
      end
   
      always_comb begin : comb_atop_hdr
        case(mrf_atop_state)
          ATOP_STORE:
            s_inbd_hdr_pnp = (s_atop_cas_naligned_nhalt & s_atop_dt_len_gt_bus_wd) ? '0 : inbd_hdr_pnp;
          ATOP_FEEDTHROUGH:
            s_inbd_hdr_pnp = !s_atop_inbd_dv ? inbd_hdr_pnp : ((s_atop_bit_half_len == `PCIE_CORE_DATA_BUS_WD) ? r_atop_inbd_hdr_pnp[0] : ((s_atop_bit_half_len == `PCIE_CORE_DATA_BUS_WD*2) ? r_atop_inbd_hdr_pnp[1] : r_atop_inbd_hdr_pnp[3]));
          ATOP_HALT:
            s_inbd_hdr_pnp = (s_atop_bit_half_len == `PCIE_CORE_DATA_BUS_WD) ? r_atop_inbd_hdr_pnp[0] : ((s_atop_bit_half_len == `PCIE_CORE_DATA_BUS_WD*2) ? r_atop_inbd_hdr_pnp[1] : r_atop_inbd_hdr_pnp[3]);
          default:
            s_inbd_hdr_pnp = inbd_hdr_pnp;
        endcase
      end
   
      always_ff @(posedge core_clk or negedge core_rstn) begin : seq_atop_hdr
        if (!core_rstn) begin
          for (int i = 0; i<4; i = i+1) begin : gen_reset_r_hdr
            r_atop_inbd_hdr_pnp[i]  <= #TP '0;
          end
        end else begin
          if (!s_inbd_halt_pnp && (s_atop_inbd_dv || mrf_atop_state == ATOP_HALT)) begin
            r_atop_inbd_hdr_pnp[0]  <= #TP inbd_hdr_pnp;
            for (int i = 1; i<4; i = i+1) begin : gen_reg_hdr
              r_atop_inbd_hdr_pnp[i] <= #TP r_atop_inbd_hdr_pnp[(i-1)];
            end
          end
        end
      end
  
      assign inbd_halt_pnp = mrf_atop_state == ATOP_HALT ? '1 : s_inbd_halt_pnp;
    end else begin : gen_nofsm_rdq
      assign s_inbd_hdr_pnp  = inbd_hdr_pnp;
      assign s_inbd_data_pnp = inbd_data_pnp;
      assign inbd_halt_pnp   = s_inbd_halt_pnp;
    end
  endgenerate

   generate
      if (MSTR_DATA_WD_GT_CORE_DATA_WD && MRF_WR_NOT_RD_QUEUE) begin : gen_up_convert

         DWC_pcie_bridge_upcnvrt
         
           #(
             .IW(`CC_CORE_DATA_BUS_WD),
             .OW(CC_MSTR_BUS_DATA_WIDTH),
             .NW(CC_MSTR_NUM_CONV_WD),
             .DWEN_IN(CX_NW),
             .DWEN_OUT(CC_MSTR_NW)
             )
         u_uc(
              .clk                (core_clk),
              .rst_n              (core_rstn),
              .halt_in            (uc_inbd_halt_pnp),
              .data_valid_in      (s_inbd_hdr_pnp[`INBD_HDR_PNP_RANGE_DV_HIGH:`INBD_HDR_PNP_RANGE_DV_LOW]),
              .data_pkt_eot       (s_inbd_hdr_pnp[`INBD_HDR_PNP_RANGE_EOT_HIGH:`INBD_HDR_PNP_RANGE_EOT_LOW]),
              .data_in            (s_inbd_data_pnp),
              // SMD: Self determined expression present in the design
              // SJ: This self determined expression is over integers where no overflow is possbile with used configuration parameters
              // spyglass disable_block SelfDeterminedExpr-ML
              .dwen_in            (s_inbd_hdr_pnp[`INBD_HDR_PNP_RANGE_DWEN_HIGH:`INBD_HDR_PNP_RANGE_DWEN_LOW]),
              // spyglass enable_block SelfDeterminedExpr-ML
              .hv_in              (s_inbd_hdr_pnp[`INBD_HDR_PNP_RANGE_HV_HIGH:`INBD_HDR_PNP_RANGE_HV_LOW]),

              .halt_out           (s_inbd_halt_pnp),
              .data_valid_out     (uc_dv),
              .data_out           (uc_inbd_data_pnp),
              .dwen_out           (uc_dwen),
              .data_pkt_eot_out   (uc_eot),
              .hv_out             (uc_hv)
              );

         always @ ( * ) begin : PROC_comb_hdr_assg

            //Most Header's fields are only valid on HV
            if (s_inbd_hdr_pnp[`INBD_HDR_PNP_RANGE_HV_HIGH:`INBD_HDR_PNP_RANGE_HV_LOW])
              uc_inbd_hdr_pnp = s_inbd_hdr_pnp;
            else
              uc_inbd_hdr_pnp = r_inbd_hdr_pnp;

            uc_inbd_hdr_pnp[`INBD_HDR_PNP_RANGE_HV_HIGH:`INBD_HDR_PNP_RANGE_HV_LOW]   = uc_hv;
            uc_inbd_hdr_pnp[`INBD_HDR_PNP_RANGE_DV_HIGH:`INBD_HDR_PNP_RANGE_DV_LOW]   = uc_dv;
            uc_inbd_hdr_pnp[`INBD_HDR_PNP_RANGE_EOT_HIGH:`INBD_HDR_PNP_RANGE_EOT_LOW]  = uc_eot;
            //dwen is not used
            //uc_inbd_hdr_pnp[`INBD_HDR_PNP_RANGE_DWEN_HIGH:`INBD_HDR_PNP_RANGE_DWEN_LOW] = uc_dwen;

            // SMD: Self determined expression present in the design
            // SJ: This self determined expression is over integers where no overflow is possbile with used configuration parameters
            // spyglass disable_block SelfDeterminedExpr-ML

            uc_inbd_hdr_pnp[`INBD_HDR_PNP_RANGE_DLLP_ABORT_HIGH:`INBD_HDR_PNP_RANGE_DLLP_ABORT_LOW] = s_inbd_hdr_pnp[`INBD_HDR_PNP_RANGE_DLLP_ABORT_HIGH:`INBD_HDR_PNP_RANGE_DLLP_ABORT_LOW];
            uc_inbd_hdr_pnp[`INBD_HDR_PNP_RANGE_TLP_ABORT_HIGH:`INBD_HDR_PNP_RANGE_TLP_ABORT_LOW]   = s_inbd_hdr_pnp[`INBD_HDR_PNP_RANGE_TLP_ABORT_HIGH:`INBD_HDR_PNP_RANGE_TLP_ABORT_LOW];
            uc_inbd_hdr_pnp[`INBD_HDR_PNP_RANGE_ECRC_ABORT_HIGH:`INBD_HDR_PNP_RANGE_ECRC_ABORT_LOW] = s_inbd_hdr_pnp[`INBD_HDR_PNP_RANGE_ECRC_ABORT_HIGH:`INBD_HDR_PNP_RANGE_ECRC_ABORT_LOW];

            //MCB's request signal is valid only on hv
            if(!uc_hv)
              uc_inbd_hdr_pnp[`INBD_HDR_PNP_RANGE_MCB_NP_VALID_HIGH:`INBD_HDR_PNP_RANGE_MCB_NP_VALID_LOW] = s_inbd_hdr_pnp[`INBD_HDR_PNP_RANGE_MCB_NP_VALID_HIGH:`INBD_HDR_PNP_RANGE_MCB_NP_VALID_LOW];
            // spyglass enable_block SelfDeterminedExpr-ML
         end

         always @ (posedge core_clk or negedge core_rstn) begin : PROC_seq_uc_hdr_reg
            if (!core_rstn) begin
               r_inbd_hdr_pnp <= #TP {DC_INBD_HEADER_PNP_WD{1'b0}};
            end else begin
               if (s_inbd_hdr_pnp[`INBD_HDR_PNP_RANGE_HV_HIGH:`INBD_HDR_PNP_RANGE_HV_LOW])
                 r_inbd_hdr_pnp <= #TP s_inbd_hdr_pnp;
            end
         end

      end else if (MRF_WR_NOT_RD_QUEUE) begin : gen_no_up_convert
         assign s_inbd_halt_pnp = uc_inbd_halt_pnp;
         always @ ( * ) begin : PROC_comb_hdr_pnp
            uc_inbd_hdr_pnp   = s_inbd_hdr_pnp;
            //Not used in these configurations
            r_inbd_hdr_pnp = {DC_INBD_HEADER_PNP_WD{1'b0}};
         end
         assign uc_inbd_data_pnp = s_inbd_data_pnp;
      end else begin : gen_up_convert_2
         assign s_inbd_halt_pnp = uc_inbd_halt_pnp;
         always @ ( * ) begin : PROC_comb_hdr_pnp_2
            uc_inbd_hdr_pnp   = s_inbd_hdr_pnp;
            //Not used in these configurations
            r_inbd_hdr_pnp = {DC_INBD_HEADER_PNP_WD{1'b0}};
         end
         assign uc_inbd_data_pnp = {CORE_REQ_DATA_BUS_WD{1'b0}};
      end
   endgenerate

   localparam L_U1_CDC_WD = DC_INBD_HEADER_PNP_WD+CORE_REQ_DATA_BUS_WD;

   typedef struct packed {
     logic                   vld;
     logic [L_U1_CDC_WD-1:0] chanl;
     logic                   rdy;
   } rs_t;

   struct packed {
     rs_t src;
     rs_t dest;
   } w_u1_cdc;

   // -------------------------------------------------------------------------------------
   // PCIe to Bridge Master Clock Crossing FIFO Control block (optional)
   // -------------------------------------------------------------------------------------
       wire [CC_CORE_ADDR_BUS_WD-1:0]  uc_inbd_addr_pnp;
       wire                            uc_inbd_addr_chk_en;

       assign uc_inbd_addr_pnp = uc_inbd_hdr_pnp[`INBD_HDR_PNP_RANGE_ADDR_HIGH:`INBD_HDR_PNP_RANGE_ADDR_LOW];

       assign uc_inbd_addr_chk_en = uc_inbd_hdr_pnp[`INBD_HDR_PNP_RANGE_HV_HIGH:`INBD_HDR_PNP_RANGE_HV_LOW] & !uc_inbd_halt_pnp;

       ras_dp_pipe
        #(
         .PIPELINE_TYPE             (0                                 ),
         .RESETVAL                  (0                                 ),
         .N_STAGES                  (0                                 ),
         .CAN_STALL                 (0                                 ),
         .RESET_STALL               (0                                 ),
         .BUS_PROTECT_GEN_EN        (0                                 ),
         .BUS_PROTECT_CHK_EN        (1                                 ),
         .PROT_TYPE                 (1                                 ),
         .PROT_RANGE                (CX_RAS_PROT_RANGE                 ),
         .PROT_WD                   (NUM_ADDR_PAR_BLOCKS               ),
         .PARITY_MODE               (CX_RAS_PARITY_MODE                ),
         .PROT_CORRECT_EN           (0                                 ),
         .TOTAL_WIDTH               (CC_CORE_ADDR_BUS_WD_NP            ),
         .EXCLUDE_PROT_WIDTH        (0                                 ),
         .RAS_DP_PROT_CHK_ID_BASE   (RAS_DP_ID                         )
       ) u_addr_chk (
         .clk                       (core_clk                         ),
         .rst_n                     (core_rstn                        ),
         .din                       (fn_addr_wo_par  (uc_inbd_addr_pnp)),
         .din_prot                  (fn_prot_chkin_ad(uc_inbd_addr_pnp)),
         .dout                      ( /* Not connected */              ),
         .dout_prot                 ( /* Not connected */              ),
         .en                        (1'b1                              ),
         .bypass                    (1'b0                              ),
         .stall                     (1'b0                              ),
         .stallout                  ( /* Not connected */              ),
         .valid_in                  (uc_inbd_addr_chk_en               ),
         .halt_out                  ( /* Not connected */              ),
         .valid_out                 ( /* Not connected */              ),
         .halt_in                   (1'b0                              ),
         .ras_dp_err_inband_kbd_in  (1'b0                              ),
         .ras_dp_err_inband_kbd_out ( /* Not connected */              ),
         .ras_dp_err_log            (mstr_req_ad_ras_dp_err_log        )
           ,
           .ras_dp_err_inj          (axi_bridge_ras_dp_err_inj_core_clk)
         );

         assign mstr_req_addr_parerr = mstr_req_ad_ras_dp_err_log.valid;

   // strip out parity bits before push it into the RAM
   assign s_uc_inbd_hdr_pnp = {
                               uc_inbd_hdr_pnp[DC_INBD_HEADER_PNP_WD-1:`INBD_HDR_PNP_RANGE_ADDR_HIGH+1],//spyglass disable SelfDeterminedExpr-ML
                               fn_addr_wo_par(uc_inbd_addr_pnp),
                               uc_inbd_hdr_pnp[`INBD_HDR_PNP_RANGE_ADDR_LOW-1:0]//spyglass disable SelfDeterminedExpr-ML
                              };


   generate
     if (MRF_WR_NOT_RD_QUEUE) begin : gen_nopar_push_data
       wire   uc_inbd_data_chk_en;
       assign uc_inbd_data_chk_en  = uc_inbd_hdr_pnp[`INBD_HDR_PNP_RANGE_DV_HIGH:`INBD_HDR_PNP_RANGE_DV_LOW] & !uc_inbd_halt_pnp;

       ras_dp_pipe
        #(
         .PIPELINE_TYPE             (0                                 ),
         .RESETVAL                  (0                                 ),
         .N_STAGES                  (0                                 ),
         .CAN_STALL                 (0                                 ),
         .RESET_STALL               (0                                 ),
         .BUS_PROTECT_GEN_EN        (0                                 ),
         .BUS_PROTECT_CHK_EN        (1                                 ),
         .PROT_TYPE                 (1                                 ),
         .PROT_RANGE                (CX_RAS_PROT_RANGE                 ),
         .PROT_WD                   (NUM_DATA_PAR_BLOCKS               ),
         .PARITY_MODE               (CX_RAS_PARITY_MODE                ),
         .PROT_CORRECT_EN           (0                                 ),
         .TOTAL_WIDTH               (CORE_REQ_DATA_BUS_WD_NP           ),
         .EXCLUDE_PROT_WIDTH        (0                                 ),
         .RAS_DP_PROT_CHK_ID_BASE   (`MSTR_REQ_DT_RAS_ID               )
       ) u_data_chk (
         .clk                       (core_clk                         ),
         .rst_n                     (core_rstn                         ),
         .din                       (fn_data_wo_par  (uc_inbd_data_pnp)),
         .din_prot                  (fn_prot_chkin_dt(uc_inbd_data_pnp)),
         .dout                      (  /* Not connected */             ),
         .dout_prot                 (  /* Not connected */             ),
         .en                        (1'b1                              ),
         .bypass                    (1'b0                              ),
         .stall                     (1'b0                              ),
         .stallout                  (  /* Not connected */             ),
         .valid_in                  (uc_inbd_data_chk_en               ),
         .halt_out                  (  /* Not connected */             ),
         .valid_out                 (  /* Not connected */             ),
         .halt_in                   (1'b0                              ),
         .ras_dp_err_inband_kbd_in  (1'b0                              ),
         .ras_dp_err_inband_kbd_out (  /* Not connected */             ),
         .ras_dp_err_log            (mstr_req_dt_ras_dp_err_log        )
           ,
           .ras_dp_err_inj          (axi_bridge_ras_dp_err_inj_core_clk )
         );

       assign mstr_req_data_parerr = mstr_req_dt_ras_dp_err_log.valid;
       // strip out parity bits before push it into the RAM
       assign s_uc_inbd_data_pnp = fn_data_wo_par(uc_inbd_data_pnp);
     end else begin : gen_nopar_push_data_rdq
        assign mstr_req_data_parerr = 1'b0;
        assign mstr_req_dt_ras_dp_err_log = ({{RAS_ERROR_LOG_WD{1'b0}},1'b0});
     end
   endgenerate

   generate
      if (MRF_WR_NOT_RD_QUEUE) begin : gen_push_data
         assign c2a_push_data = {
                                 s_uc_inbd_hdr_pnp,
                                 s_uc_inbd_data_pnp
                                 };
      end else begin : gen_push_data_rdq
         assign c2a_push_data = fn_rd_cdc_ram_opt(s_uc_inbd_hdr_pnp);

      end
   endgenerate

   assign uc_inbd_halt_pnp  = c2a_push_f;
   assign c2a_push_req_n = !(!c2a_push_f && (uc_inbd_hdr_pnp[`INBD_HDR_PNP_RANGE_HV_HIGH:`INBD_HDR_PNP_RANGE_HV_LOW] || uc_inbd_hdr_pnp[`INBD_HDR_PNP_RANGE_DV_HIGH:`INBD_HDR_PNP_RANGE_DV_LOW]));

   // Do not delete these signals; they aren't used inside the module but they are being probed
   // by the performance (latency) testbench
   assign uc_inbd_hv  = uc_inbd_hdr_pnp[`INBD_HDR_PNP_RANGE_HV_HIGH:`INBD_HDR_PNP_RANGE_HV_LOW];
   assign uc_inbd_dv  = uc_inbd_hdr_pnp[`INBD_HDR_PNP_RANGE_DV_HIGH:`INBD_HDR_PNP_RANGE_DV_LOW];
   assign uc_inbd_eot = uc_inbd_hdr_pnp[`INBD_HDR_PNP_RANGE_EOT_HIGH:`INBD_HDR_PNP_RANGE_EOT_LOW];




   DWC_pcie_bridge_async_fifo_ram_latency
   
     #(
       .DATA_WIDTH                        (IB_REQ_CDC_RAM_DATA_WD_NOECC)
       ,.ECC_WIDTH                        (IB_REQ_CDC_RAM_DATA_WD - IB_REQ_CDC_RAM_DATA_WD_NOECC)
       ,.CX_RAS_RAM_PROT_RANGE            (CX_RAS_RAM_PROT_RANGE)
       ,.DEPTH                            (IB_REQ_CDC_RAM_DP)
       ,.RAM_ADDR_WIDTH                   (IB_REQ_CDC_RAM_ADDR_WD)
       ,.COUNT_WIDTH                      (IB_REQ_CDC_RAM_ADDR_WD+1)//spyglass disable SelfDeterminedExpr-ML
       ,.PUSH_AE_LVL                      (1)
       ,.PUSH_AF_LVL                      (1)
       ,.POP_AE_LVL                       (1)
       ,.POP_AF_LVL                       (1)
       ,.ERR_MODE                         (0)
       ,.PUSH_SYNC                        (CC_MRF_A2C_FIFO_SYNC_REGS)
       ,.POP_SYNC                         (CC_MRF_C2A_FIFO_SYNC_REGS)
       ,.HOLD_RD_ADDR                     (CC_MRF_C2A_FIFO_HOLD_RD_ADDR)
       ,.RAS_DP_ID                        (RAM_RAS_DP_ID)
       ,.RAM_RD_LATENCY                   (IB_REQ_CDC_RAM_RD_LATENCY)
       )
   u_c2a
     (
      .clk_push                           (core_clk)
      ,.rst_push_n                        (core_rstn)
      ,.clk_pop                           (mstr_aclk)
      ,.rst_pop_n                         (mstr_arstn)
      ,.cfg_ras_correct                   (cfg_ras_correct)
      ,.ras_recc_corr_cnt_pulse           (mrf_ras_recc_corr_cnt_pulse)
      ,.ras_recc_ucorr_cnt_pulse          (mrf_ras_recc_ucorr_cnt_pulse)
      ,.ras_recc_cnt_addr                 (mrf_ras_recc_cnt_addr)
      ,.recc_cnt_ras_dp_err_log           (mrf_recc_cnt_ras_dp_err_log)
      ,.ras_dp_err_inj                    (ras_dp_err_inj_mstr_aclk)
      // External FIFO RAM interface
      ,.asfifo_wen                        (mrf_c2a_ram_wea)
      ,.asfifo_waddr                      (mrf_c2a_ram_addra)
      ,.asfifo_wdata                      (mrf_c2a_ram_dina)
      ,.asfifo_raddr                      (mrf_c2a_ram_addrb)
      ,.asfifo_ren                        (mrf_c2a_ram_enb)
      ,.rdata                             (mrf_c2a_ram_doutb)
      // Master response push interface
      ,.push_req_n                        (c2a_push_req_n)
      ,.push_data                         (c2a_push_data)
      ,.asfifo_f                          (c2a_push_f)
      ,.asfifo_af                         (/*UNCONNECTED*/)
      // Master response pop interface
      ,.ready                             (c2a_ready)
      ,.asfifo_e                          (/*UNCONNECTED*/)
      ,.asfifo_pop_valid                  (c2a_data_valid)
      ,.asfifo_pop_data                   (c2a_pop_data)
      );


   assign c2a_ready = !cdc_inbd_halt_pnp;

   generate
      if (MRF_WR_NOT_RD_QUEUE) begin : gen_pop_data
         assign {s_cdc_inbd_hdr_pnp,
                 s_cdc_inbd_data_pnp} = c2a_pop_data;

         // generate parity bits and interleave them after RAM pop
         // SMD: Self determined expression present in the design
         // SJ: This self determined expression is over integers where no overflow is possbile with used configuration parameters
         // spyglass disable_block SelfDeterminedExpr-ML
         assign ss_cdc_inbd_hdr_pnp = {
                                       s_cdc_inbd_hdr_pnp[DC_INBD_HEADER_PNP_WD_NP-1:(`INBD_HDR_PNP_RANGE_ADDR_LOW+CC_CORE_ADDR_BUS_WD_NP)],
                                       fn_addr_w_par(s_cdc_inbd_hdr_pnp[`INBD_HDR_PNP_RANGE_ADDR_LOW+:CC_CORE_ADDR_BUS_WD_NP]),
                                       s_cdc_inbd_hdr_pnp[`INBD_HDR_PNP_RANGE_ADDR_LOW-1:0]
                                       };
         // spyglass enable_block SelfDeterminedExpr-ML

         assign ss_cdc_inbd_data_pnp = fn_data_w_par(s_cdc_inbd_data_pnp);
         assign {cdc_inbd_hdr_pnp,
                 cdc_inbd_data_pnp} = {ss_cdc_inbd_hdr_pnp, ss_cdc_inbd_data_pnp} &
                                      {(DC_INBD_HEADER_PNP_WD + CORE_REQ_DATA_BUS_WD){c2a_data_valid}};
      end else begin : gen_pop_data_rdq
         assign w_c2a_pop_data = fn_rd_cdc_ram_reconstruction(c2a_pop_data);
         // generate parity bits and interleave them after RAM pop
         // SMD: Self determined expression present in the design
         // SJ: This self determined expression is over integers where no overflow is possbile with used configuration parameters
         // spyglass disable_block SelfDeterminedExpr-ML
         assign ss_cdc_inbd_hdr_pnp = {
                                       w_c2a_pop_data[DC_INBD_HEADER_PNP_WD_NP-1:(`INBD_HDR_PNP_RANGE_ADDR_LOW+CC_CORE_ADDR_BUS_WD_NP)],
                                       fn_addr_w_par(w_c2a_pop_data[`INBD_HDR_PNP_RANGE_ADDR_LOW+:CC_CORE_ADDR_BUS_WD_NP]),
                                       w_c2a_pop_data[`INBD_HDR_PNP_RANGE_ADDR_LOW-1:0]
                                       };
         // spyglass enable_block SelfDeterminedExpr-ML

         assign cdc_inbd_hdr_pnp = ss_cdc_inbd_hdr_pnp &
                                   {DC_INBD_HEADER_PNP_WD{c2a_data_valid}};
         assign cdc_inbd_data_pnp = {CORE_REQ_DATA_BUS_WD{1'b0}};
      end
   endgenerate



// In case of down conversion and atomic operations, this is to send the request to MCB as early as possible
logic req_active_dc;

always @ (posedge mstr_aclk or negedge mstr_arstn) begin : PROC_seq_dc_trck
   if (!mstr_arstn) begin
      req_active_dc <= #TP '0;
   end else begin
      if (cdc_inbd_halt_pnp & !st_req_halt_out & cdc_inbd_hdr_pnp[`INBD_HDR_PNP_RANGE_MCB_NP_VALID_HIGH:`INBD_HDR_PNP_RANGE_MCB_NP_VALID_LOW] && ({mstr_req_fmt, mstr_req_type} inside {`FETCHADD32, `FETCHADD64, `SWAP32, `SWAP64, `CAS32, `CAS64, `DMWR32, `DMWR64}))
        req_active_dc <= #TP '1;
      else if (!cdc_inbd_halt_pnp & !st_req_halt_out & req_active_dc)
        req_active_dc <= #TP '0;
   end
end

   // Checks if the request is one of an atomic operation
   assign mrf_reqmcb_atomic   = {mstr_req_fmt, mstr_req_type} inside {`FETCHADD32, `FETCHADD64, `SWAP32, `SWAP64, `CAS32, `CAS64};

  wire mrf_reqmcb_dmwr;
  assign mrf_reqmcb_dmwr   = {mstr_req_fmt, mstr_req_type} inside {`DMWR32, `DMWR64};

   //Registers the transaction in the MCB
  assign mrf_reqmcb_np_valid =   cdc_inbd_hdr_pnp[`INBD_HDR_PNP_RANGE_MCB_NP_VALID_HIGH:`INBD_HDR_PNP_RANGE_MCB_NP_VALID_LOW]
                                 && cdc_inbd_hdr_pnp[`INBD_HDR_PNP_RANGE_HV_HIGH:`INBD_HDR_PNP_RANGE_HV_LOW] && ((!req_active_dc && !st_req_halt_out) || (!cdc_inbd_halt_pnp_mcb && !mrf_reqmcb_atomic && !mrf_reqmcb_dmwr ))
                                 && c2a_data_valid 
                                 ; //spyglass disable SelfDeterminedExpr-ML

   assign mrf_reqmcb_mstrid   = cdc_inbd_hdr_pnp[`INBD_HDR_PNP_RANGE_LOOKUP_ID_HIGH:`INBD_HDR_PNP_RANGE_LOOKUP_ID_LOW]; //spyglass disable SelfDeterminedExpr-ML
   assign mrf_reqmcb_last     = cdc_inbd_hdr_pnp[`INBD_HDR_PNP_RANGE_DECMP_LAST_HIGH:`INBD_HDR_PNP_RANGE_DECMP_LAST_LOW]; //spyglass disable SelfDeterminedExpr-ML


   //Retrives the signals from the packed bus
   //empty invalidates the packet, to avoid repeating it twice (use delayed empty, it rises with last data)
   assign mstr_req_hv         = cdc_inbd_hdr_pnp[`INBD_HDR_PNP_RANGE_HV_HIGH:`INBD_HDR_PNP_RANGE_HV_LOW] && c2a_data_valid && !arbmcb_halt_mrf; //spyglass disable SelfDeterminedExpr-ML
   assign mstr_req_dv         = cdc_inbd_hdr_pnp[`INBD_HDR_PNP_RANGE_DV_HIGH:`INBD_HDR_PNP_RANGE_DV_LOW] && c2a_data_valid && !arbmcb_halt_mrf; //spyglass disable SelfDeterminedExpr-ML
   assign mstr_req_eot        = cdc_inbd_hdr_pnp[`INBD_HDR_PNP_RANGE_EOT_HIGH:`INBD_HDR_PNP_RANGE_EOT_LOW] && c2a_data_valid && !arbmcb_halt_mrf; //spyglass disable SelfDeterminedExpr-ML
   assign mstr_req_fmt        = cdc_inbd_hdr_pnp[`INBD_HDR_PNP_RANGE_FMT_HIGH:`INBD_HDR_PNP_RANGE_FMT_LOW]; //spyglass disable SelfDeterminedExpr-ML
   assign mstr_req_type       = cdc_inbd_hdr_pnp[`INBD_HDR_PNP_RANGE_TYPE_HIGH:`INBD_HDR_PNP_RANGE_TYPE_LOW]; //spyglass disable SelfDeterminedExpr-ML
   generate
      if (CC_MSTR_BUS_ADDR_WIDTH > CC_CORE_ADDR_BUS_WD) begin : gen_mstr_req_addr_mstrwd_gtd_corewd
         always @ ( * ) begin
            mstr_req_addr                            = ADDR_BUS_INIT;
            mstr_req_addr[CC_CORE_ADDR_BUS_WD-1:0]   = cdc_inbd_hdr_pnp[CC_CORE_ADDR_BUS_WD+`INBD_HDR_PNP_RANGE_ADDR_LOW-1:`INBD_HDR_PNP_RANGE_ADDR_LOW]; //spyglass disable SelfDeterminedExpr-ML
         end
         always @ ( * ) begin
            r_mstr_req_addr                          = ADDR_BUS_INIT;
            r_mstr_req_addr[CC_CORE_ADDR_BUS_WD-1:0] = r_cdc_inbd_hdr_pnp[CC_CORE_ADDR_BUS_WD+`INBD_HDR_PNP_RANGE_ADDR_LOW-1:`INBD_HDR_PNP_RANGE_ADDR_LOW]; //spyglass disable SelfDeterminedExpr-ML
         end
      end else begin : gen_mstr_req_addr
         always @ ( * ) begin
            mstr_req_addr                             = ADDR_BUS_INIT;
            mstr_req_addr[CC_MSTR_BUS_ADDR_WIDTH-1:0] = cdc_inbd_hdr_pnp[CC_MSTR_BUS_ADDR_WIDTH+`INBD_HDR_PNP_RANGE_ADDR_LOW-1:`INBD_HDR_PNP_RANGE_ADDR_LOW]; //spyglass disable SelfDeterminedExpr-ML
         end
         always @ ( * ) begin
            r_mstr_req_addr                             = ADDR_BUS_INIT;
            r_mstr_req_addr[CC_MSTR_BUS_ADDR_WIDTH-1:0] = r_cdc_inbd_hdr_pnp[CC_MSTR_BUS_ADDR_WIDTH+`INBD_HDR_PNP_RANGE_ADDR_LOW-1:`INBD_HDR_PNP_RANGE_ADDR_LOW]; //spyglass disable SelfDeterminedExpr-ML
         end

      end
   endgenerate
   //DW length as coded INBD_HDR_PNP_RANGE_DW_LEN_* is from the orginal(not decomposed) request
   assign r_mstr_req_dw_len  = r_cdc_inbd_hdr_pnp[`INBD_HDR_PNP_RANGE_DECMP_BELEN_HIGH-1:`INBD_HDR_PNP_RANGE_DECMP_BELEN_LOW+2]; //spyglass disable SelfDeterminedExpr-ML
   assign mstr_req_first_be   = cdc_inbd_hdr_pnp[`INBD_HDR_PNP_RANGE_FIRST_BE_HIGH:`INBD_HDR_PNP_RANGE_FIRST_BE_LOW]; //spyglass disable SelfDeterminedExpr-ML
   assign r_mstr_req_first_be = r_cdc_inbd_hdr_pnp[`INBD_HDR_PNP_RANGE_FIRST_BE_HIGH:`INBD_HDR_PNP_RANGE_FIRST_BE_LOW]; //spyglass disable SelfDeterminedExpr-ML
   assign mstr_req_last_be    = cdc_inbd_hdr_pnp[`INBD_HDR_PNP_RANGE_LAST_BE_HIGH:`INBD_HDR_PNP_RANGE_LAST_BE_LOW]; //spyglass disable SelfDeterminedExpr-ML
   assign r_mstr_req_last_be  = r_cdc_inbd_hdr_pnp[`INBD_HDR_PNP_RANGE_LAST_BE_HIGH:`INBD_HDR_PNP_RANGE_LAST_BE_LOW]; //spyglass disable SelfDeterminedExpr-ML
   assign mstr_req_hdr_uppr_bytes_valid    = cdc_inbd_hdr_pnp[`INBD_HDR_PNP_RANGE_HDR_UPPR_BYTES_VALID_HIGH:`INBD_HDR_PNP_RANGE_HDR_UPPR_BYTES_VALID_LOW]; //spyglass disable SelfDeterminedExpr-ML
   assign r_mstr_req_hdr_uppr_bytes_valid  = r_cdc_inbd_hdr_pnp[`INBD_HDR_PNP_RANGE_HDR_UPPR_BYTES_VALID_HIGH:`INBD_HDR_PNP_RANGE_HDR_UPPR_BYTES_VALID_LOW]; //spyglass disable SelfDeterminedExpr-ML

   generate
   if (MRF_WR_NOT_RD_QUEUE) begin : gen_mstr_addr_wrq
     assign mstr_req_addr_low   = mstr_req_msg ? mstr_req_addr[1:0] : get_low_addr(mstr_req_first_be);
     assign r_mstr_req_addr_low = r_mstr_req_msg ? r_mstr_req_addr[1:0] : get_low_addr(r_mstr_req_first_be);
   end else begin : gen_mstr_addr_rdq
     assign mstr_req_addr_low   = get_low_addr(mstr_req_first_be);
     assign r_mstr_req_addr_low = get_low_addr(r_mstr_req_first_be);
   end
   endgenerate

   //DW length as coded INBD_HDR_PNP_RANGE_DW_LEN_* is from the orginal(not decomposed) request
   wire mstr_req_dw_len_crry_b;
   assign {mstr_req_dw_len_crry_b,
           mstr_req_dw_len}    = {1'b0,cdc_inbd_hdr_pnp[`INBD_HDR_PNP_RANGE_DECMP_BELEN_HIGH-1:`INBD_HDR_PNP_RANGE_DECMP_BELEN_LOW+2]} +    //spyglass disable SelfDeterminedExpr-ML
                                 {{10{1'b0}},|cdc_inbd_hdr_pnp[`INBD_HDR_PNP_RANGE_DECMP_BELEN_LOW+1:`INBD_HDR_PNP_RANGE_DECMP_BELEN_LOW]}; //spyglass disable SelfDeterminedExpr-ML

   //Derived signals from the packed bus
   assign mstr_req_rd      = (({mstr_req_fmt, mstr_req_type} == `MRDLK32) ||
                              ({mstr_req_fmt, mstr_req_type} == `MRDLK64) ||
                              ({mstr_req_fmt, mstr_req_type} == `MRD32)   ||
                              ({mstr_req_fmt, mstr_req_type} == `MRD64)   ||
                              ({mstr_req_fmt, mstr_req_type} == `IORD)    ||
                              ({mstr_req_fmt, mstr_req_type} == `CFGRD0)  ||
                              ({mstr_req_fmt, mstr_req_type} == `CFGRD1)
                              );

   generate
   if (MRF_WR_NOT_RD_QUEUE) begin : gen_mstr_msg_wrq
     assign mstr_req_msg   = ({mstr_req_fmt, mstr_req_type[4:3]} == `MSG_4) || ({mstr_req_fmt, mstr_req_type[4:3]} == `MSGD_4);
     assign r_mstr_req_msg = ({r_cdc_inbd_hdr_pnp[`INBD_HDR_PNP_RANGE_FMT_HIGH:`INBD_HDR_PNP_RANGE_FMT_LOW],r_cdc_inbd_hdr_pnp[`INBD_HDR_PNP_RANGE_TYPE_HIGH:(`INBD_HDR_PNP_RANGE_TYPE_LOW+3)]} == `MSG_4) ||//spyglass disable SelfDeterminedExpr-ML
                             ({r_cdc_inbd_hdr_pnp[`INBD_HDR_PNP_RANGE_FMT_HIGH:`INBD_HDR_PNP_RANGE_FMT_LOW],r_cdc_inbd_hdr_pnp[`INBD_HDR_PNP_RANGE_TYPE_HIGH:(`INBD_HDR_PNP_RANGE_TYPE_LOW+3)]} == `MSGD_4); //spyglass disable SelfDeterminedExpr-ML
   end else begin : gen_mstr_msg_rdq
     assign mstr_req_msg   = 1'b0;
     assign r_mstr_req_msg = 1'b0;
   end
   endgenerate


   assign mstr_req_msgd =    ({mstr_req_fmt, mstr_req_type[4:3]} == `MSGD_4);
   assign r_mstr_req_msgd =  ({r_cdc_inbd_hdr_pnp[`INBD_HDR_PNP_RANGE_FMT_HIGH:`INBD_HDR_PNP_RANGE_FMT_LOW],r_cdc_inbd_hdr_pnp[`INBD_HDR_PNP_RANGE_TYPE_HIGH:(`INBD_HDR_PNP_RANGE_TYPE_LOW+3)]} == `MSGD_4); //spyglass disable SelfDeterminedExpr-ML


   generate
   if (MRF_WR_NOT_RD_QUEUE) begin : gen_mstr_req_state
      // Following state is used to control the AXI/AHB master interface
      always @(posedge mstr_aclk or negedge mstr_arstn)
        begin :  PROC_seq_MASTER_FSM
           if (!mstr_arstn)
             r_mstr_req_state       <= #TP S_REQ_IDLE;
           else if (!cdc_inbd_halt_pnp)
             r_mstr_req_state       <= #TP s_mstr_req_state;
        end

      // AMP2:  State should never transition to a new state when mstr_req_cycle_halt is asserted;
      always @( * )
        begin:  PROC_comb_MASTER_FSM
            case  (r_mstr_req_state)
           S_REQ_IDLE:
              if (mstr_req_hv  & !mstr_req_rd & !mstr_req_eot)
                s_mstr_req_state      = S_REQ_WR_BURST;
              else
                s_mstr_req_state      = S_REQ_IDLE;
           S_REQ_WR_BURST:
              if (mstr_req_eot )
                s_mstr_req_state      = S_REQ_IDLE;
              else
                s_mstr_req_state      = S_REQ_WR_BURST;
           default:
             s_mstr_req_state         = S_REQ_IDLE;
           endcase
        end
   end
   endgenerate

   generate
   if (MRF_WR_NOT_RD_QUEUE) begin : gen_cdc_hdr_wrq

      always @ (posedge mstr_aclk or negedge mstr_arstn) begin : PROC_seq_state_out_wr
         if (!mstr_arstn) begin
            r_cdc_inbd_hdr_pnp  <= #TP {DC_INBD_HEADER_PNP_WD{1'b0}};
            r_cdc_inbd_data_pnp <= #TP {CORE_REQ_DATA_BUS_WD{1'b0}};
            r_mstr_calc_new_parity <= #TP 1'b0;
         end else begin
            if (!st_req_halt_out & (r_mstr_req_state == S_REQ_IDLE)) begin
               if (cdc_inbd_hdr_pnp[`INBD_HDR_PNP_RANGE_HV_HIGH:`INBD_HDR_PNP_RANGE_HV_LOW]) begin
                 r_mstr_calc_new_parity <= #TP mstr_calc_new_parity;
               end
               foreach (cdc_inbd_hdr_pnp[i]) begin
                 //most of the fields must be qualified with HV
                  if ((cdc_inbd_hdr_pnp[`INBD_HDR_PNP_RANGE_HV_HIGH:`INBD_HDR_PNP_RANGE_HV_LOW]) ||
                      //these are the exceptions
                      // spyglass disable_block SelfDeterminedExpr-ML
                      // SMD: Self determined expression present in the design.
                      // SJ:  Loss of precision is not possible, these are bounded design constants
                      (i == `INBD_HDR_PNP_RANGE_HV_LOW) ||
                      (i == `INBD_HDR_PNP_RANGE_DV_LOW) ||
                      (i == `INBD_HDR_PNP_RANGE_EOT_LOW) ||
                      (i == `INBD_HDR_PNP_RANGE_DLLP_ABORT_LOW) ||
                      (i == `INBD_HDR_PNP_RANGE_TLP_ABORT_LOW) ||
                      (i == `INBD_HDR_PNP_RANGE_ECRC_ABORT_LOW)
                      // spyglass enable_block SelfDeterminedExpr-ML
                      ) begin
                    r_cdc_inbd_hdr_pnp[i]  <= #TP cdc_inbd_hdr_pnp[i] ;
                  end

               end //foreach

               r_cdc_inbd_data_pnp <= #TP cdc_inbd_data_pnp;
            end
         end
      end // block: PROC_seq_state_out

   end else begin : gen_cdc_hdr_rdq

      always @ (posedge mstr_aclk or negedge mstr_arstn) begin : PROC_seq_state_out_rd
         if (!mstr_arstn) begin
            r_cdc_inbd_hdr_pnp  <= #TP {DC_INBD_HEADER_PNP_WD{1'b0}};
            r_cdc_inbd_data_pnp <= #TP {CORE_REQ_DATA_BUS_WD{1'b0}};
         end else begin
            if (!st_req_halt_out) begin

               foreach (cdc_inbd_hdr_pnp[i]) begin

                 //most of the fields must be qualified with HV
                  if ((cdc_inbd_hdr_pnp[`INBD_HDR_PNP_RANGE_HV_HIGH:`INBD_HDR_PNP_RANGE_HV_LOW]) ||
                      //these are the exceptions
                      // spyglass disable_block SelfDeterminedExpr-ML
                      // SMD: Self determined expression present in the design.
                      // SJ:  Loss of precision is not possible, these are bounded design constants
                      (i == `INBD_HDR_PNP_RANGE_HV_LOW) ||
                      (i == `INBD_HDR_PNP_RANGE_DV_LOW) ||
                      (i == `INBD_HDR_PNP_RANGE_EOT_LOW) ||
                      (i == `INBD_HDR_PNP_RANGE_DLLP_ABORT_LOW) ||
                      (i == `INBD_HDR_PNP_RANGE_TLP_ABORT_LOW) ||
                      (i == `INBD_HDR_PNP_RANGE_ECRC_ABORT_LOW)
                      // spyglass enable_block SelfDeterminedExpr-ML
                      ) begin
                    r_cdc_inbd_hdr_pnp[i]  <= #TP cdc_inbd_hdr_pnp[i] ;
                  end

               end //foreach

               r_cdc_inbd_data_pnp <= #TP cdc_inbd_data_pnp;
            end
         end
      end // block: PROC_seq_state_out

   end
   endgenerate


   // =====================================================================================
   // Parity error detection and calculation
   // =====================================================================================
   assign mstr_calc_new_parity   = (ADDR_PAR_WD != 0) ?
                                   (CX_RAS_PARITY_MODE ? ~(^{mstr_req_addr[ADDR_PAR_CALC_WIDTH -1:2], mstr_req_addr_low[1:0]}) : ^{mstr_req_addr[ADDR_PAR_CALC_WIDTH -1:2], mstr_req_addr_low[1:0]})
                                   : 1'b0;



// =====================================================================================
// State machine outputs
// =====================================================================================
   generate
   if (MRF_WR_NOT_RD_QUEUE) begin : gen_ctrl_st_wrq
      assign ctrl_state_idle = (r_mstr_req_state == S_REQ_IDLE);
      assign ctrl_state_wr = (r_mstr_req_state == S_REQ_WR_BURST);
   end else begin : gen_ctrl_st_rdq
      assign ctrl_state_idle = 1'b1;
      assign ctrl_state_wr = 1'b0;
   end
   endgenerate

   generate
      if (MRF_WR_NOT_RD_QUEUE) begin : gen_ctrl_strb_wrq
        assign ctrl_mstrobe  = ((ctrl_state_idle & mstr_req_hv & !mstr_req_rd) |
                                (ctrl_state_wr & mstr_req_dv));
      end else begin : gen_ctrl_strb_rdq
        assign ctrl_mstrobe  = (mstr_req_hv & mstr_req_rd & ctrl_state_idle);
      end
   endgenerate

   // Last beat of TLP
   assign ctrl_mstrobe_last = mstr_req_eot;

   generate
   if (MRF_WR_NOT_RD_QUEUE) begin : gen_ctrl_maddr_wrq
      always @ ( * ) begin : PROC_comb_ctrl_maddr_wr
         ctrl_maddr   = (ctrl_state_idle) ? {mstr_req_addr[CC_MSTR_BUS_ADDR_WIDTH -1 :2], mstr_req_addr_low} :
                        {r_mstr_req_addr[CC_MSTR_BUS_ADDR_WIDTH -1 :2], r_mstr_req_addr_low};
         ctrl_maddr[ADDR_PAR_CALC_WIDTH] = (ctrl_state_idle) ? mstr_calc_new_parity : r_mstr_calc_new_parity;
      end
   end else begin : gen_ctrl_maddr_rdq
      always @ ( * ) begin : PROC_comb_ctrl_maddr_rd
         ctrl_maddr   = {mstr_req_addr[CC_MSTR_BUS_ADDR_WIDTH -1 :2], mstr_req_addr_low};
         ctrl_maddr[ADDR_PAR_CALC_WIDTH] = mstr_calc_new_parity;
      end
   end
   endgenerate


   assign ctrl_mid     = ctrl_inbd_hdr_pnp[`INBD_HDR_PNP_RANGE_LOOKUP_ID_HIGH:`INBD_HDR_PNP_RANGE_LOOKUP_ID_LOW]; //spyglass disable SelfDeterminedExpr-ML

   assign ctrl_mlast_tlp = ctrl_inbd_hdr_pnp[`INBD_HDR_PNP_RANGE_DECMP_LAST_HIGH:`INBD_HDR_PNP_RANGE_DECMP_LAST_LOW]; //spyglass disable SelfDeterminedExpr-ML

   generate
   if (MRF_WR_NOT_RD_QUEUE) begin : gen_ctrl_req_wrq
     assign ctrl_inbd_hdr_pnp = ctrl_state_idle ? cdc_inbd_hdr_pnp:r_cdc_inbd_hdr_pnp;
     assign ctrl_req_msg      = ctrl_state_idle ? mstr_req_msg : r_mstr_req_msg;
     assign ctrl_req_msgd     = ctrl_state_idle ? mstr_req_msgd : r_mstr_req_msgd;
   end else begin : gen_ctrl_req_rdq
     assign ctrl_inbd_hdr_pnp = cdc_inbd_hdr_pnp;
     assign ctrl_req_msg      = mstr_req_msg;
     assign ctrl_req_msgd     = mstr_req_msgd;
   end
   endgenerate

   assign ctrl_mlen      = get_byte_count(ctrl_inbd_hdr_pnp, ctrl_req_msg, ctrl_req_msgd);

   generate
      if(REQ_NW==32)begin : gen_padd_32_strb
         wire [127:0] padded_wstrb; // ready to support 1024bits wide bus
         assign padded_wstrb = (ctrl_state_idle && mstr_req_msg && !mstr_req_fmt[1] && !mstr_req_hdr_uppr_bytes_valid) ? 0
                              : (ctrl_state_idle && mstr_req_msg && !mstr_req_fmt[1] && mstr_req_hdr_uppr_bytes_valid) ? {120'b0, 8'hff}
                              : (!mstr_req_msg && mstr_req_eot && ctrl_state_idle && mstr_req_dw_len[4:0] == 1)  ? {124'b0, mstr_req_first_be}
                              : (!mstr_req_msg && mstr_req_eot && ctrl_state_idle && mstr_req_dw_len[4:0] == 2)  ? {120'b0, mstr_req_last_be,                                    mstr_req_first_be}
                              : (!mstr_req_msg && mstr_req_eot && ctrl_state_idle && mstr_req_dw_len[4:0] == 3)  ? {116'b0, mstr_req_last_be,  4'hF                             ,mstr_req_first_be}
                              : (!mstr_req_msg && mstr_req_eot && ctrl_state_idle && mstr_req_dw_len[4:0] == 4)  ? {112'b0, mstr_req_last_be,  8'hFF                            ,mstr_req_first_be}
                              : (!mstr_req_msg && mstr_req_eot && ctrl_state_idle && mstr_req_dw_len[4:0] == 5)  ? {108'b0, mstr_req_last_be, 12'hFFF                           ,mstr_req_first_be}
                              : (!mstr_req_msg && mstr_req_eot && ctrl_state_idle && mstr_req_dw_len[4:0] == 6)  ? {104'b0, mstr_req_last_be, 16'hFFFF                          ,mstr_req_first_be}
                              : (!mstr_req_msg && mstr_req_eot && ctrl_state_idle && mstr_req_dw_len[4:0] == 7)  ? {100'b0, mstr_req_last_be, 20'hFFFFF                         ,mstr_req_first_be}
                              : (!mstr_req_msg && mstr_req_eot && ctrl_state_idle && mstr_req_dw_len[4:0] == 8)  ? { 96'b0, mstr_req_last_be, 24'hFFFFFF                        ,mstr_req_first_be}
                              : (!mstr_req_msg && mstr_req_eot && ctrl_state_idle && mstr_req_dw_len[4:0] == 9)  ? { 92'b0, mstr_req_last_be, 28'hFFFFFFF                       ,mstr_req_first_be}
                              : (!mstr_req_msg && mstr_req_eot && ctrl_state_idle && mstr_req_dw_len[4:0] == 10) ? { 88'b0, mstr_req_last_be, 32'hFFFFFFFF                      ,mstr_req_first_be}
                              : (!mstr_req_msg && mstr_req_eot && ctrl_state_idle && mstr_req_dw_len[4:0] == 11) ? { 84'b0, mstr_req_last_be, 36'hFFFFFFFFF                     ,mstr_req_first_be}
                              : (!mstr_req_msg && mstr_req_eot && ctrl_state_idle && mstr_req_dw_len[4:0] == 12) ? { 80'b0, mstr_req_last_be, 40'hFFFFFFFFFF                    ,mstr_req_first_be}
                              : (!mstr_req_msg && mstr_req_eot && ctrl_state_idle && mstr_req_dw_len[4:0] == 13) ? { 76'b0, mstr_req_last_be, 44'hFFFFFFFFFFF                   ,mstr_req_first_be}
                              : (!mstr_req_msg && mstr_req_eot && ctrl_state_idle && mstr_req_dw_len[4:0] == 14) ? { 72'b0, mstr_req_last_be, 48'hFFFFFFFFFFFF                  ,mstr_req_first_be}
                              : (!mstr_req_msg && mstr_req_eot && ctrl_state_idle && mstr_req_dw_len[4:0] == 15) ? { 68'b0, mstr_req_last_be, 52'hFFFFFFFFFFFFF                 ,mstr_req_first_be}
                              : (!mstr_req_msg && mstr_req_eot && ctrl_state_idle && mstr_req_dw_len[4:0] == 16) ? { 64'b0, mstr_req_last_be, 56'hFFFFFFFFFFFFFF                ,mstr_req_first_be}
                              : (!mstr_req_msg && mstr_req_eot && ctrl_state_idle && mstr_req_dw_len[4:0] == 17) ? { 60'b0, mstr_req_last_be, 60'hFFFFFFFFFFFFFFF               ,mstr_req_first_be}
                              : (!mstr_req_msg && mstr_req_eot && ctrl_state_idle && mstr_req_dw_len[4:0] == 18) ? { 56'b0, mstr_req_last_be, 64'hFFFFFFFFFFFFFFFF              ,mstr_req_first_be}
                              : (!mstr_req_msg && mstr_req_eot && ctrl_state_idle && mstr_req_dw_len[4:0] == 19) ? { 52'b0, mstr_req_last_be, 68'hFFFFFFFFFFFFFFFFF             ,mstr_req_first_be}
                              : (!mstr_req_msg && mstr_req_eot && ctrl_state_idle && mstr_req_dw_len[4:0] == 20) ? { 48'b0, mstr_req_last_be, 72'hFFFFFFFFFFFFFFFFFF            ,mstr_req_first_be}
                              : (!mstr_req_msg && mstr_req_eot && ctrl_state_idle && mstr_req_dw_len[4:0] == 21) ? { 44'b0, mstr_req_last_be, 76'hFFFFFFFFFFFFFFFFFFF           ,mstr_req_first_be}
                              : (!mstr_req_msg && mstr_req_eot && ctrl_state_idle && mstr_req_dw_len[4:0] == 22) ? { 40'b0, mstr_req_last_be, 80'hFFFFFFFFFFFFFFFFFFFF          ,mstr_req_first_be}
                              : (!mstr_req_msg && mstr_req_eot && ctrl_state_idle && mstr_req_dw_len[4:0] == 23) ? { 36'b0, mstr_req_last_be, 84'hFFFFFFFFFFFFFFFFFFFFF         ,mstr_req_first_be}
                              : (!mstr_req_msg && mstr_req_eot && ctrl_state_idle && mstr_req_dw_len[4:0] == 24) ? { 32'b0, mstr_req_last_be, 88'hFFFFFFFFFFFFFFFFFFFFFF        ,mstr_req_first_be}
                              : (!mstr_req_msg && mstr_req_eot && ctrl_state_idle && mstr_req_dw_len[4:0] == 25) ? { 28'b0, mstr_req_last_be, 92'hFFFFFFFFFFFFFFFFFFFFFFF       ,mstr_req_first_be}
                              : (!mstr_req_msg && mstr_req_eot && ctrl_state_idle && mstr_req_dw_len[4:0] == 26) ? { 24'b0, mstr_req_last_be, 96'hFFFFFFFFFFFFFFFFFFFFFFFF      ,mstr_req_first_be}
                              : (!mstr_req_msg && mstr_req_eot && ctrl_state_idle && mstr_req_dw_len[4:0] == 27) ? { 20'b0, mstr_req_last_be,100'hFFFFFFFFFFFFFFFFFFFFFFFFF     ,mstr_req_first_be}
                              : (!mstr_req_msg && mstr_req_eot && ctrl_state_idle && mstr_req_dw_len[4:0] == 28) ? { 16'b0, mstr_req_last_be,104'hFFFFFFFFFFFFFFFFFFFFFFFFFF    ,mstr_req_first_be}
                              : (!mstr_req_msg && mstr_req_eot && ctrl_state_idle && mstr_req_dw_len[4:0] == 29) ? { 12'b0, mstr_req_last_be,108'hFFFFFFFFFFFFFFFFFFFFFFFFFFF   ,mstr_req_first_be}
                              : (!mstr_req_msg && mstr_req_eot && ctrl_state_idle && mstr_req_dw_len[4:0] == 30) ? {  8'b0, mstr_req_last_be,112'hFFFFFFFFFFFFFFFFFFFFFFFFFFFF  ,mstr_req_first_be}
                              : (!mstr_req_msg && mstr_req_eot && ctrl_state_idle && mstr_req_dw_len[4:0] == 31) ? {  4'b0, mstr_req_last_be,116'hFFFFFFFFFFFFFFFFFFFFFFFFFFFFF ,mstr_req_first_be}
                              : (!mstr_req_msg && mstr_req_eot && ctrl_state_idle && mstr_req_dw_len[4:0] == 0)  ? {        mstr_req_last_be,120'hFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF,mstr_req_first_be}
                              : (mstr_req_msg && mstr_req_eot && ctrl_state_idle && mstr_req_dw_len[4:0] ==  1) ? {124'b0,   4'hF}
                              : (mstr_req_msg && mstr_req_eot && ctrl_state_idle && mstr_req_dw_len[4:0] ==  2) ? {120'b0,   8'hFF}
                              : (mstr_req_msg && mstr_req_eot && ctrl_state_idle && mstr_req_dw_len[4:0] ==  3) ? {116'b0,  12'hFFF}
                              : (mstr_req_msg && mstr_req_eot && ctrl_state_idle && mstr_req_dw_len[4:0] ==  4) ? {112'b0,  16'hFFFF}
                              : (mstr_req_msg && mstr_req_eot && ctrl_state_idle && mstr_req_dw_len[4:0] ==  5) ? {108'b0,  20'hFFFFF}
                              : (mstr_req_msg && mstr_req_eot && ctrl_state_idle && mstr_req_dw_len[4:0] ==  6) ? {104'b0,  24'hFFFFFF}
                              : (mstr_req_msg && mstr_req_eot && ctrl_state_idle && mstr_req_dw_len[4:0] ==  7) ? {100'b0,  28'hFFFFFFF}
                              : (mstr_req_msg && mstr_req_eot && ctrl_state_idle && mstr_req_dw_len[4:0] ==  8) ? { 96'b0,  32'hFFFFFFFF}
                              : (mstr_req_msg && mstr_req_eot && ctrl_state_idle && mstr_req_dw_len[4:0] ==  9) ? { 92'b0,  36'hFFFFFFFFF}
                              : (mstr_req_msg && mstr_req_eot && ctrl_state_idle && mstr_req_dw_len[4:0] == 10) ? { 88'b0,  40'hFFFFFFFFFF}
                              : (mstr_req_msg && mstr_req_eot && ctrl_state_idle && mstr_req_dw_len[4:0] == 11) ? { 84'b0,  44'hFFFFFFFFFFF}
                              : (mstr_req_msg && mstr_req_eot && ctrl_state_idle && mstr_req_dw_len[4:0] == 12) ? { 80'b0,  48'hFFFFFFFFFFFF}
                              : (mstr_req_msg && mstr_req_eot && ctrl_state_idle && mstr_req_dw_len[4:0] == 13) ? { 76'b0,  52'hFFFFFFFFFFFFF}
                              : (mstr_req_msg && mstr_req_eot && ctrl_state_idle && mstr_req_dw_len[4:0] == 14) ? { 72'b0,  56'hFFFFFFFFFFFFFF}
                              : (mstr_req_msg && mstr_req_eot && ctrl_state_idle && mstr_req_dw_len[4:0] == 15) ? { 68'b0,  60'hFFFFFFFFFFFFFFF}
                              : (mstr_req_msg && mstr_req_eot && ctrl_state_idle && mstr_req_dw_len[4:0] == 16) ? { 64'b0,  64'hFFFFFFFFFFFFFFFF}
                              : (mstr_req_msg && mstr_req_eot && ctrl_state_idle && mstr_req_dw_len[4:0] == 17) ? { 60'b0,  68'hFFFFFFFFFFFFFFFFF}
                              : (mstr_req_msg && mstr_req_eot && ctrl_state_idle && mstr_req_dw_len[4:0] == 18) ? { 56'b0,  72'hFFFFFFFFFFFFFFFFFF}
                              : (mstr_req_msg && mstr_req_eot && ctrl_state_idle && mstr_req_dw_len[4:0] == 19) ? { 52'b0,  76'hFFFFFFFFFFFFFFFFFFF}
                              : (mstr_req_msg && mstr_req_eot && ctrl_state_idle && mstr_req_dw_len[4:0] == 20) ? { 48'b0,  80'hFFFFFFFFFFFFFFFFFFFF}
                              : (mstr_req_msg && mstr_req_eot && ctrl_state_idle && mstr_req_dw_len[4:0] == 21) ? { 44'b0,  84'hFFFFFFFFFFFFFFFFFFFFF}
                              : (mstr_req_msg && mstr_req_eot && ctrl_state_idle && mstr_req_dw_len[4:0] == 22) ? { 40'b0,  88'hFFFFFFFFFFFFFFFFFFFFFF}
                              : (mstr_req_msg && mstr_req_eot && ctrl_state_idle && mstr_req_dw_len[4:0] == 23) ? { 36'b0,  92'hFFFFFFFFFFFFFFFFFFFFFFF}
                              : (mstr_req_msg && mstr_req_eot && ctrl_state_idle && mstr_req_dw_len[4:0] == 24) ? { 32'b0,  96'hFFFFFFFFFFFFFFFFFFFFFFFF}
                              : (mstr_req_msg && mstr_req_eot && ctrl_state_idle && mstr_req_dw_len[4:0] == 25) ? { 28'b0, 100'hFFFFFFFFFFFFFFFFFFFFFFFFF}
                              : (mstr_req_msg && mstr_req_eot && ctrl_state_idle && mstr_req_dw_len[4:0] == 26) ? { 24'b0, 104'hFFFFFFFFFFFFFFFFFFFFFFFFFF}
                              : (mstr_req_msg && mstr_req_eot && ctrl_state_idle && mstr_req_dw_len[4:0] == 27) ? { 20'b0, 108'hFFFFFFFFFFFFFFFFFFFFFFFFFFF}
                              : (mstr_req_msg && mstr_req_eot && ctrl_state_idle && mstr_req_dw_len[4:0] == 28) ? { 16'b0, 112'hFFFFFFFFFFFFFFFFFFFFFFFFFFFF}
                              : (mstr_req_msg && mstr_req_eot && ctrl_state_idle && mstr_req_dw_len[4:0] == 29) ? { 12'b0, 116'hFFFFFFFFFFFFFFFFFFFFFFFFFFFFF}
                              : (mstr_req_msg && mstr_req_eot && ctrl_state_idle && mstr_req_dw_len[4:0] == 30) ? {  8'b0, 120'hFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF}
                              : (mstr_req_msg && mstr_req_eot && ctrl_state_idle && mstr_req_dw_len[4:0] == 31) ? {  4'b0, 124'hFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF}
                              : (mstr_req_msg && mstr_req_eot && ctrl_state_idle && mstr_req_dw_len[4:0] ==  0) ? {        128'hFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF}

                              : (mstr_req_msg && mstr_req_eot && r_mstr_req_dw_len[4:0] ==  1) ? {124'b0,   4'hF}
                              : (mstr_req_msg && mstr_req_eot && r_mstr_req_dw_len[4:0] ==  2) ? {120'b0,   8'hFF}
                              : (mstr_req_msg && mstr_req_eot && r_mstr_req_dw_len[4:0] ==  3) ? {116'b0,  12'hFFF}
                              : (mstr_req_msg && mstr_req_eot && r_mstr_req_dw_len[4:0] ==  4) ? {112'b0,  16'hFFFF}
                              : (mstr_req_msg && mstr_req_eot && r_mstr_req_dw_len[4:0] ==  5) ? {108'b0,  20'hFFFFF}
                              : (mstr_req_msg && mstr_req_eot && r_mstr_req_dw_len[4:0] ==  6) ? {104'b0,  24'hFFFFFF}
                              : (mstr_req_msg && mstr_req_eot && r_mstr_req_dw_len[4:0] ==  7) ? {100'b0,  28'hFFFFFFF}
                              : (mstr_req_msg && mstr_req_eot && r_mstr_req_dw_len[4:0] ==  8) ? { 96'b0,  32'hFFFFFFFF}
                              : (mstr_req_msg && mstr_req_eot && r_mstr_req_dw_len[4:0] ==  9) ? { 92'b0,  36'hFFFFFFFFF}
                              : (mstr_req_msg && mstr_req_eot && r_mstr_req_dw_len[4:0] == 10) ? { 88'b0,  40'hFFFFFFFFFF}
                              : (mstr_req_msg && mstr_req_eot && r_mstr_req_dw_len[4:0] == 11) ? { 84'b0,  44'hFFFFFFFFFFF}
                              : (mstr_req_msg && mstr_req_eot && r_mstr_req_dw_len[4:0] == 12) ? { 80'b0,  48'hFFFFFFFFFFFF}
                              : (mstr_req_msg && mstr_req_eot && r_mstr_req_dw_len[4:0] == 13) ? { 76'b0,  52'hFFFFFFFFFFFFF}
                              : (mstr_req_msg && mstr_req_eot && r_mstr_req_dw_len[4:0] == 14) ? { 72'b0,  56'hFFFFFFFFFFFFFF}
                              : (mstr_req_msg && mstr_req_eot && r_mstr_req_dw_len[4:0] == 15) ? { 68'b0,  60'hFFFFFFFFFFFFFFF}
                              : (mstr_req_msg && mstr_req_eot && r_mstr_req_dw_len[4:0] == 16) ? { 64'b0,  64'hFFFFFFFFFFFFFFFF}
                              : (mstr_req_msg && mstr_req_eot && r_mstr_req_dw_len[4:0] == 17) ? { 60'b0,  68'hFFFFFFFFFFFFFFFFF}
                              : (mstr_req_msg && mstr_req_eot && r_mstr_req_dw_len[4:0] == 18) ? { 56'b0,  72'hFFFFFFFFFFFFFFFFFF}
                              : (mstr_req_msg && mstr_req_eot && r_mstr_req_dw_len[4:0] == 19) ? { 52'b0,  76'hFFFFFFFFFFFFFFFFFFF}
                              : (mstr_req_msg && mstr_req_eot && r_mstr_req_dw_len[4:0] == 20) ? { 48'b0,  80'hFFFFFFFFFFFFFFFFFFFF}
                              : (mstr_req_msg && mstr_req_eot && r_mstr_req_dw_len[4:0] == 21) ? { 44'b0,  84'hFFFFFFFFFFFFFFFFFFFFF}
                              : (mstr_req_msg && mstr_req_eot && r_mstr_req_dw_len[4:0] == 22) ? { 40'b0,  88'hFFFFFFFFFFFFFFFFFFFFFF}
                              : (mstr_req_msg && mstr_req_eot && r_mstr_req_dw_len[4:0] == 23) ? { 36'b0,  92'hFFFFFFFFFFFFFFFFFFFFFFF}
                              : (mstr_req_msg && mstr_req_eot && r_mstr_req_dw_len[4:0] == 24) ? { 32'b0,  96'hFFFFFFFFFFFFFFFFFFFFFFFF}
                              : (mstr_req_msg && mstr_req_eot && r_mstr_req_dw_len[4:0] == 25) ? { 28'b0, 100'hFFFFFFFFFFFFFFFFFFFFFFFFF}
                              : (mstr_req_msg && mstr_req_eot && r_mstr_req_dw_len[4:0] == 26) ? { 24'b0, 104'hFFFFFFFFFFFFFFFFFFFFFFFFFF}
                              : (mstr_req_msg && mstr_req_eot && r_mstr_req_dw_len[4:0] == 27) ? { 20'b0, 108'hFFFFFFFFFFFFFFFFFFFFFFFFFFF}
                              : (mstr_req_msg && mstr_req_eot && r_mstr_req_dw_len[4:0] == 28) ? { 16'b0, 112'hFFFFFFFFFFFFFFFFFFFFFFFFFFFF}
                              : (mstr_req_msg && mstr_req_eot && r_mstr_req_dw_len[4:0] == 29) ? { 12'b0, 116'hFFFFFFFFFFFFFFFFFFFFFFFFFFFFF}
                              : (mstr_req_msg && mstr_req_eot && r_mstr_req_dw_len[4:0] == 30) ? {  8'b0, 120'hFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF}
                              : (mstr_req_msg && mstr_req_eot && r_mstr_req_dw_len[4:0] == 31) ? {  4'b0, 124'hFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF}
                              : (mstr_req_msg && mstr_req_eot && r_mstr_req_dw_len[4:0] ==  0) ? {        128'hFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF}

                              : (mstr_req_eot && r_mstr_req_dw_len[4:0] ==  1) ? {124'b0, r_mstr_req_last_be}
                              : (mstr_req_eot && r_mstr_req_dw_len[4:0] ==  2) ? {120'b0, r_mstr_req_last_be,  4'hF}
                              : (mstr_req_eot && r_mstr_req_dw_len[4:0] ==  3) ? {116'b0, r_mstr_req_last_be,  8'hFF}
                              : (mstr_req_eot && r_mstr_req_dw_len[4:0] ==  4) ? {112'b0, r_mstr_req_last_be, 12'hFFF}
                              : (mstr_req_eot && r_mstr_req_dw_len[4:0] ==  5) ? {108'b0, r_mstr_req_last_be, 16'hFFFF}
                              : (mstr_req_eot && r_mstr_req_dw_len[4:0] ==  6) ? {104'b0, r_mstr_req_last_be, 20'hFFFFF}
                              : (mstr_req_eot && r_mstr_req_dw_len[4:0] ==  7) ? {100'b0, r_mstr_req_last_be, 24'hFFFFFF}
                              : (mstr_req_eot && r_mstr_req_dw_len[4:0] ==  8) ? { 96'b0, r_mstr_req_last_be, 28'hFFFFFFF}
                              : (mstr_req_eot && r_mstr_req_dw_len[4:0] ==  9) ? { 92'b0, r_mstr_req_last_be, 32'hFFFFFFFF}
                              : (mstr_req_eot && r_mstr_req_dw_len[4:0] == 10) ? { 88'b0, r_mstr_req_last_be, 36'hFFFFFFFFF}
                              : (mstr_req_eot && r_mstr_req_dw_len[4:0] == 11) ? { 84'b0, r_mstr_req_last_be, 40'hFFFFFFFFFF}
                              : (mstr_req_eot && r_mstr_req_dw_len[4:0] == 12) ? { 80'b0, r_mstr_req_last_be, 44'hFFFFFFFFFFF}
                              : (mstr_req_eot && r_mstr_req_dw_len[4:0] == 13) ? { 76'b0, r_mstr_req_last_be, 48'hFFFFFFFFFFFF}
                              : (mstr_req_eot && r_mstr_req_dw_len[4:0] == 14) ? { 72'b0, r_mstr_req_last_be, 52'hFFFFFFFFFFFFF}
                              : (mstr_req_eot && r_mstr_req_dw_len[4:0] == 15) ? { 68'b0, r_mstr_req_last_be, 56'hFFFFFFFFFFFFFF}
                              : (mstr_req_eot && r_mstr_req_dw_len[4:0] == 16) ? { 64'b0, r_mstr_req_last_be, 60'hFFFFFFFFFFFFFFF}
                              : (mstr_req_eot && r_mstr_req_dw_len[4:0] == 17) ? { 60'b0, r_mstr_req_last_be, 64'hFFFFFFFFFFFFFFFF}
                              : (mstr_req_eot && r_mstr_req_dw_len[4:0] == 18) ? { 56'b0, r_mstr_req_last_be, 68'hFFFFFFFFFFFFFFFFF}
                              : (mstr_req_eot && r_mstr_req_dw_len[4:0] == 19) ? { 52'b0, r_mstr_req_last_be, 72'hFFFFFFFFFFFFFFFFFF}
                              : (mstr_req_eot && r_mstr_req_dw_len[4:0] == 20) ? { 48'b0, r_mstr_req_last_be, 76'hFFFFFFFFFFFFFFFFFFF}
                              : (mstr_req_eot && r_mstr_req_dw_len[4:0] == 21) ? { 44'b0, r_mstr_req_last_be, 80'hFFFFFFFFFFFFFFFFFFFF}
                              : (mstr_req_eot && r_mstr_req_dw_len[4:0] == 22) ? { 40'b0, r_mstr_req_last_be, 84'hFFFFFFFFFFFFFFFFFFFFF}
                              : (mstr_req_eot && r_mstr_req_dw_len[4:0] == 23) ? { 36'b0, r_mstr_req_last_be, 88'hFFFFFFFFFFFFFFFFFFFFFF}
                              : (mstr_req_eot && r_mstr_req_dw_len[4:0] == 24) ? { 32'b0, r_mstr_req_last_be, 92'hFFFFFFFFFFFFFFFFFFFFFFF}
                              : (mstr_req_eot && r_mstr_req_dw_len[4:0] == 25) ? { 28'b0, r_mstr_req_last_be, 96'hFFFFFFFFFFFFFFFFFFFFFFFF}
                              : (mstr_req_eot && r_mstr_req_dw_len[4:0] == 26) ? { 24'b0, r_mstr_req_last_be,100'hFFFFFFFFFFFFFFFFFFFFFFFFF}
                              : (mstr_req_eot && r_mstr_req_dw_len[4:0] == 27) ? { 20'b0, r_mstr_req_last_be,104'hFFFFFFFFFFFFFFFFFFFFFFFFFF}
                              : (mstr_req_eot && r_mstr_req_dw_len[4:0] == 28) ? { 16'b0, r_mstr_req_last_be,108'hFFFFFFFFFFFFFFFFFFFFFFFFFFF}
                              : (mstr_req_eot && r_mstr_req_dw_len[4:0] == 29) ? { 12'b0, r_mstr_req_last_be,112'hFFFFFFFFFFFFFFFFFFFFFFFFFFFF}
                              : (mstr_req_eot && r_mstr_req_dw_len[4:0] == 30) ? {  8'b0, r_mstr_req_last_be,116'hFFFFFFFFFFFFFFFFFFFFFFFFFFFFF}
                              : (mstr_req_eot && r_mstr_req_dw_len[4:0] == 31) ? {  4'b0, r_mstr_req_last_be,120'hFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF}
                              : (mstr_req_eot && r_mstr_req_dw_len[4:0] ==  0) ? {        r_mstr_req_last_be,124'hFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF}
                              : (!mstr_req_msg && !mstr_req_eot && ctrl_state_idle) ? {124'hFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF, mstr_req_first_be}
                              : 128'hFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF;

         assign ctrl_mbe = padded_wstrb[CORE_REQ_DATA_BUS_WSTRB_WD -1 :0];

      end else if(REQ_NW==16)begin : gen_padd_16_strb
         wire [63:0] padded_wstrb; // ready to support 512bits wide bus
         assign padded_wstrb = (ctrl_state_idle && mstr_req_msg && !mstr_req_fmt[1] && !mstr_req_hdr_uppr_bytes_valid) ? 0
                              : (ctrl_state_idle && mstr_req_msg && !mstr_req_fmt[1] && mstr_req_hdr_uppr_bytes_valid) ? {56'b0, 8'hff}
                              : (!mstr_req_msg && mstr_req_eot && ctrl_state_idle && mstr_req_dw_len[3:0] == 1)  ? {60'b0, mstr_req_first_be}
                              : (!mstr_req_msg && mstr_req_eot && ctrl_state_idle && mstr_req_dw_len[3:0] == 2)  ? {56'b0, mstr_req_last_be,                   mstr_req_first_be}
                              : (!mstr_req_msg && mstr_req_eot && ctrl_state_idle && mstr_req_dw_len[3:0] == 3)  ? {52'b0, mstr_req_last_be, 4'hF             ,mstr_req_first_be}
                              : (!mstr_req_msg && mstr_req_eot && ctrl_state_idle && mstr_req_dw_len[3:0] == 4)  ? {48'b0, mstr_req_last_be, 8'hFF            ,mstr_req_first_be}
                              : (!mstr_req_msg && mstr_req_eot && ctrl_state_idle && mstr_req_dw_len[3:0] == 5)  ? {44'b0, mstr_req_last_be,12'hFFF           ,mstr_req_first_be}
                              : (!mstr_req_msg && mstr_req_eot && ctrl_state_idle && mstr_req_dw_len[3:0] == 6)  ? {40'b0, mstr_req_last_be,16'hFFFF          ,mstr_req_first_be}
                              : (!mstr_req_msg && mstr_req_eot && ctrl_state_idle && mstr_req_dw_len[3:0] == 7)  ? {36'b0, mstr_req_last_be,20'hFFFFF         ,mstr_req_first_be}
                              : (!mstr_req_msg && mstr_req_eot && ctrl_state_idle && mstr_req_dw_len[3:0] == 8)  ? {32'b0, mstr_req_last_be,24'hFFFFFF        ,mstr_req_first_be}
                              : (!mstr_req_msg && mstr_req_eot && ctrl_state_idle && mstr_req_dw_len[3:0] == 9)  ? {28'b0, mstr_req_last_be,28'hFFFFFFF       ,mstr_req_first_be}
                              : (!mstr_req_msg && mstr_req_eot && ctrl_state_idle && mstr_req_dw_len[3:0] == 10) ? {24'b0, mstr_req_last_be,32'hFFFFFFFF      ,mstr_req_first_be}
                              : (!mstr_req_msg && mstr_req_eot && ctrl_state_idle && mstr_req_dw_len[3:0] == 11) ? {20'b0, mstr_req_last_be,36'hFFFFFFFFF     ,mstr_req_first_be}
                              : (!mstr_req_msg && mstr_req_eot && ctrl_state_idle && mstr_req_dw_len[3:0] == 12) ? {16'b0, mstr_req_last_be,40'hFFFFFFFFFF    ,mstr_req_first_be}
                              : (!mstr_req_msg && mstr_req_eot && ctrl_state_idle && mstr_req_dw_len[3:0] == 13) ? {12'b0, mstr_req_last_be,44'hFFFFFFFFFFF   ,mstr_req_first_be}
                              : (!mstr_req_msg && mstr_req_eot && ctrl_state_idle && mstr_req_dw_len[3:0] == 14) ? { 8'b0, mstr_req_last_be,48'hFFFFFFFFFFFF  ,mstr_req_first_be}
                              : (!mstr_req_msg && mstr_req_eot && ctrl_state_idle && mstr_req_dw_len[3:0] == 15) ? { 4'b0, mstr_req_last_be,52'hFFFFFFFFFFFFF ,mstr_req_first_be}
                              : (!mstr_req_msg && mstr_req_eot && ctrl_state_idle && mstr_req_dw_len[3:0] == 0)  ? {       mstr_req_last_be,56'hFFFFFFFFFFFFFF,mstr_req_first_be}
                              : (mstr_req_msg && mstr_req_eot && ctrl_state_idle && mstr_req_dw_len[3:0] == 1)  ? {60'b0,  4'hF}
                              : (mstr_req_msg && mstr_req_eot && ctrl_state_idle && mstr_req_dw_len[3:0] == 2)  ? {56'b0,  8'hFF}
                              : (mstr_req_msg && mstr_req_eot && ctrl_state_idle && mstr_req_dw_len[3:0] == 3)  ? {52'b0, 12'hFFF}
                              : (mstr_req_msg && mstr_req_eot && ctrl_state_idle && mstr_req_dw_len[3:0] == 4)  ? {48'b0, 16'hFFFF}
                              : (mstr_req_msg && mstr_req_eot && ctrl_state_idle && mstr_req_dw_len[3:0] == 5)  ? {44'b0, 20'hFFFFF}
                              : (mstr_req_msg && mstr_req_eot && ctrl_state_idle && mstr_req_dw_len[3:0] == 6)  ? {40'b0, 24'hFFFFFF}
                              : (mstr_req_msg && mstr_req_eot && ctrl_state_idle && mstr_req_dw_len[3:0] == 7)  ? {36'b0, 28'hFFFFFFF}
                              : (mstr_req_msg && mstr_req_eot && ctrl_state_idle && mstr_req_dw_len[3:0] == 8)  ? {32'b0, 32'hFFFFFFFF}
                              : (mstr_req_msg && mstr_req_eot && ctrl_state_idle && mstr_req_dw_len[3:0] == 9)  ? {28'b0, 36'hFFFFFFFFF}
                              : (mstr_req_msg && mstr_req_eot && ctrl_state_idle && mstr_req_dw_len[3:0] == 10) ? {24'b0, 40'hFFFFFFFFFF}
                              : (mstr_req_msg && mstr_req_eot && ctrl_state_idle && mstr_req_dw_len[3:0] == 11) ? {20'b0, 44'hFFFFFFFFFFF}
                              : (mstr_req_msg && mstr_req_eot && ctrl_state_idle && mstr_req_dw_len[3:0] == 12) ? {16'b0, 48'hFFFFFFFFFFFF}
                              : (mstr_req_msg && mstr_req_eot && ctrl_state_idle && mstr_req_dw_len[3:0] == 13) ? {12'b0, 52'hFFFFFFFFFFFFF}
                              : (mstr_req_msg && mstr_req_eot && ctrl_state_idle && mstr_req_dw_len[3:0] == 14) ? { 8'b0, 56'hFFFFFFFFFFFFFF}
                              : (mstr_req_msg && mstr_req_eot && ctrl_state_idle && mstr_req_dw_len[3:0] == 15) ? { 4'b0, 60'hFFFFFFFFFFFFFFF}
                              : (mstr_req_msg && mstr_req_eot && ctrl_state_idle && mstr_req_dw_len[3:0] == 0)  ? {       64'hFFFFFFFFFFFFFFFF}

                              : (mstr_req_msg && mstr_req_eot && r_mstr_req_dw_len[3:0] == 1)  ? {60'b0,  4'hF}
                              : (mstr_req_msg && mstr_req_eot && r_mstr_req_dw_len[3:0] == 2)  ? {56'b0,  8'hFF}
                              : (mstr_req_msg && mstr_req_eot && r_mstr_req_dw_len[3:0] == 3)  ? {52'b0, 12'hFFF}
                              : (mstr_req_msg && mstr_req_eot && r_mstr_req_dw_len[3:0] == 4)  ? {48'b0, 16'hFFFF}
                              : (mstr_req_msg && mstr_req_eot && r_mstr_req_dw_len[3:0] == 5)  ? {44'b0, 20'hFFFFF}
                              : (mstr_req_msg && mstr_req_eot && r_mstr_req_dw_len[3:0] == 6)  ? {40'b0, 24'hFFFFFF}
                              : (mstr_req_msg && mstr_req_eot && r_mstr_req_dw_len[3:0] == 7)  ? {36'b0, 28'hFFFFFFF}
                              : (mstr_req_msg && mstr_req_eot && r_mstr_req_dw_len[3:0] == 8)  ? {32'b0, 32'hFFFFFFFF}
                              : (mstr_req_msg && mstr_req_eot && r_mstr_req_dw_len[3:0] == 9)  ? {28'b0, 36'hFFFFFFFFF}
                              : (mstr_req_msg && mstr_req_eot && r_mstr_req_dw_len[3:0] == 10) ? {24'b0, 40'hFFFFFFFFFF}
                              : (mstr_req_msg && mstr_req_eot && r_mstr_req_dw_len[3:0] == 11) ? {20'b0, 44'hFFFFFFFFFFF}
                              : (mstr_req_msg && mstr_req_eot && r_mstr_req_dw_len[3:0] == 12) ? {16'b0, 48'hFFFFFFFFFFFF}
                              : (mstr_req_msg && mstr_req_eot && r_mstr_req_dw_len[3:0] == 13) ? {12'b0, 52'hFFFFFFFFFFFFF}
                              : (mstr_req_msg && mstr_req_eot && r_mstr_req_dw_len[3:0] == 14) ? { 8'b0, 56'hFFFFFFFFFFFFFF}
                              : (mstr_req_msg && mstr_req_eot && r_mstr_req_dw_len[3:0] == 15) ? { 4'b0, 60'hFFFFFFFFFFFFFFF}
                              : (mstr_req_msg && mstr_req_eot && r_mstr_req_dw_len[3:0] == 0)  ? {       64'hFFFFFFFFFFFFFFFF}

                              : (mstr_req_eot && r_mstr_req_dw_len[3:0] == 1)  ? {60'b0, r_mstr_req_last_be}
                              : (mstr_req_eot && r_mstr_req_dw_len[3:0] == 2)  ? {56'b0, r_mstr_req_last_be, 4'hF}
                              : (mstr_req_eot && r_mstr_req_dw_len[3:0] == 3)  ? {52'b0, r_mstr_req_last_be, 8'hFF}
                              : (mstr_req_eot && r_mstr_req_dw_len[3:0] == 4)  ? {48'b0, r_mstr_req_last_be,12'hFFF}
                              : (mstr_req_eot && r_mstr_req_dw_len[3:0] == 5)  ? {44'b0, r_mstr_req_last_be,16'hFFFF}
                              : (mstr_req_eot && r_mstr_req_dw_len[3:0] == 6)  ? {40'b0, r_mstr_req_last_be,20'hFFFFF}
                              : (mstr_req_eot && r_mstr_req_dw_len[3:0] == 7)  ? {36'b0, r_mstr_req_last_be,24'hFFFFFF}
                              : (mstr_req_eot && r_mstr_req_dw_len[3:0] == 8)  ? {32'b0, r_mstr_req_last_be,28'hFFFFFFF}
                              : (mstr_req_eot && r_mstr_req_dw_len[3:0] == 9)  ? {28'b0, r_mstr_req_last_be,32'hFFFFFFFF}
                              : (mstr_req_eot && r_mstr_req_dw_len[3:0] == 10) ? {24'b0, r_mstr_req_last_be,36'hFFFFFFFFF}
                              : (mstr_req_eot && r_mstr_req_dw_len[3:0] == 11) ? {20'b0, r_mstr_req_last_be,40'hFFFFFFFFFF}
                              : (mstr_req_eot && r_mstr_req_dw_len[3:0] == 12) ? {16'b0, r_mstr_req_last_be,44'hFFFFFFFFFFF}
                              : (mstr_req_eot && r_mstr_req_dw_len[3:0] == 13) ? {12'b0, r_mstr_req_last_be,48'hFFFFFFFFFFFF}
                              : (mstr_req_eot && r_mstr_req_dw_len[3:0] == 14) ? { 8'b0, r_mstr_req_last_be,52'hFFFFFFFFFFFFF}
                              : (mstr_req_eot && r_mstr_req_dw_len[3:0] == 15) ? { 4'b0, r_mstr_req_last_be,56'hFFFFFFFFFFFFFF}
                              : (mstr_req_eot && r_mstr_req_dw_len[3:0] == 0) ? {        r_mstr_req_last_be,60'hFFFFFFFFFFFFFFF}
                              : (!mstr_req_msg && !mstr_req_eot && ctrl_state_idle) ? {60'hFFFFFFFFFFFFFFF, mstr_req_first_be}
                              : 64'hFFFFFFFFFFFFFFFF;

         assign ctrl_mbe = padded_wstrb[CORE_REQ_DATA_BUS_WSTRB_WD -1 :0];

      end else if(REQ_NW==8)begin : gen_padd_8_strb
         wire [31:0] padded_wstrb; // ready to support 256bits wide bus
         assign padded_wstrb = (ctrl_state_idle && mstr_req_msg && !mstr_req_fmt[1] && !mstr_req_hdr_uppr_bytes_valid) ? 0
                              : (ctrl_state_idle && mstr_req_msg && !mstr_req_fmt[1] && mstr_req_hdr_uppr_bytes_valid) ? {24'b0, 8'hff}
                              : (!mstr_req_msg && mstr_req_eot && ctrl_state_idle && mstr_req_dw_len[2:0] == 1) ? {28'b0, mstr_req_first_be}
                              : (!mstr_req_msg && mstr_req_eot && ctrl_state_idle && mstr_req_dw_len[2:0] == 2) ? {24'b0, mstr_req_last_be,           mstr_req_first_be}
                              : (!mstr_req_msg && mstr_req_eot && ctrl_state_idle && mstr_req_dw_len[2:0] == 3) ? {20'b0, mstr_req_last_be, 4'hF     ,mstr_req_first_be}
                              : (!mstr_req_msg && mstr_req_eot && ctrl_state_idle && mstr_req_dw_len[2:0] == 4) ? {16'b0, mstr_req_last_be, 8'hFF    ,mstr_req_first_be}
                              : (!mstr_req_msg && mstr_req_eot && ctrl_state_idle && mstr_req_dw_len[2:0] == 5) ? {12'b0, mstr_req_last_be,12'hFFF   ,mstr_req_first_be}
                              : (!mstr_req_msg && mstr_req_eot && ctrl_state_idle && mstr_req_dw_len[2:0] == 6) ? { 8'b0, mstr_req_last_be,16'hFFFF  ,mstr_req_first_be}
                              : (!mstr_req_msg && mstr_req_eot && ctrl_state_idle && mstr_req_dw_len[2:0] == 7) ? { 4'b0, mstr_req_last_be,20'hFFFFF ,mstr_req_first_be}
                              : (!mstr_req_msg && mstr_req_eot && ctrl_state_idle && mstr_req_dw_len[2:0] == 0) ? {       mstr_req_last_be,24'hFFFFFF,mstr_req_first_be}
                              : (mstr_req_msg && mstr_req_eot && ctrl_state_idle && mstr_req_dw_len[2:0] == 1) ? {28'b0,  4'hF}
                              : (mstr_req_msg && mstr_req_eot && ctrl_state_idle && mstr_req_dw_len[2:0] == 2) ? {24'b0,  8'hFF}
                              : (mstr_req_msg && mstr_req_eot && ctrl_state_idle && mstr_req_dw_len[2:0] == 3) ? {20'b0, 12'hFFF}
                              : (mstr_req_msg && mstr_req_eot && ctrl_state_idle && mstr_req_dw_len[2:0] == 4) ? {16'b0, 16'hFFFF}
                              : (mstr_req_msg && mstr_req_eot && ctrl_state_idle && mstr_req_dw_len[2:0] == 5) ? {12'b0, 20'hFFFFF}
                              : (mstr_req_msg && mstr_req_eot && ctrl_state_idle && mstr_req_dw_len[2:0] == 6) ? { 8'b0, 24'hFFFFFF}
                              : (mstr_req_msg && mstr_req_eot && ctrl_state_idle && mstr_req_dw_len[2:0] == 7) ? { 4'b0, 28'hFFFFFFF}
                              : (mstr_req_msg && mstr_req_eot && ctrl_state_idle && mstr_req_dw_len[2:0] == 0) ? {       32'hFFFFFFFF}

                              : (mstr_req_msg && mstr_req_eot && r_mstr_req_dw_len[2:0] == 1) ? {28'b0,  4'hF}
                              : (mstr_req_msg && mstr_req_eot && r_mstr_req_dw_len[2:0] == 2) ? {24'b0,  8'hFF}
                              : (mstr_req_msg && mstr_req_eot && r_mstr_req_dw_len[2:0] == 3) ? {20'b0, 12'hFFF}
                              : (mstr_req_msg && mstr_req_eot && r_mstr_req_dw_len[2:0] == 4) ? {16'b0, 16'hFFFF}
                              : (mstr_req_msg && mstr_req_eot && r_mstr_req_dw_len[2:0] == 5) ? {12'b0, 20'hFFFFF}
                              : (mstr_req_msg && mstr_req_eot && r_mstr_req_dw_len[2:0] == 6) ? { 8'b0, 24'hFFFFFF}
                              : (mstr_req_msg && mstr_req_eot && r_mstr_req_dw_len[2:0] == 7) ? { 4'b0, 28'hFFFFFFF}
                              : (mstr_req_msg && mstr_req_eot && r_mstr_req_dw_len[2:0] == 0) ? {       32'hFFFFFFFF}

                              : (mstr_req_eot && r_mstr_req_dw_len[2:0] == 1) ? {28'b0, r_mstr_req_last_be}
                              : (mstr_req_eot && r_mstr_req_dw_len[2:0] == 2) ? {24'b0, r_mstr_req_last_be, 4'hF}
                              : (mstr_req_eot && r_mstr_req_dw_len[2:0] == 3) ? {20'b0, r_mstr_req_last_be, 8'hFF}
                              : (mstr_req_eot && r_mstr_req_dw_len[2:0] == 4) ? {16'b0, r_mstr_req_last_be,12'hFFF}
                              : (mstr_req_eot && r_mstr_req_dw_len[2:0] == 5) ? {12'b0, r_mstr_req_last_be,16'hFFFF}
                              : (mstr_req_eot && r_mstr_req_dw_len[2:0] == 6) ? { 8'b0, r_mstr_req_last_be,20'hFFFFF}
                              : (mstr_req_eot && r_mstr_req_dw_len[2:0] == 7) ? { 4'b0, r_mstr_req_last_be,24'hFFFFFF}
                              : (mstr_req_eot && r_mstr_req_dw_len[2:0] == 0) ? {       r_mstr_req_last_be,28'hFFFFFFF}
                              : (!mstr_req_msg && !mstr_req_eot && ctrl_state_idle) ? {28'hFFFFFFF, mstr_req_first_be}
                              : 32'hFFFFFFFF;

         assign ctrl_mbe = padded_wstrb[CORE_REQ_DATA_BUS_WSTRB_WD -1 :0];

      end else if (REQ_NW==4) begin : gen_padd_4_strb
         wire [31:0] padded_wstrb; // ready to support 256bits wide bus
         assign padded_wstrb = (ctrl_state_idle && mstr_req_msg && !mstr_req_fmt[1] && !mstr_req_hdr_uppr_bytes_valid) ? 0
                              : (ctrl_state_idle && mstr_req_msg && !mstr_req_fmt[1] && mstr_req_hdr_uppr_bytes_valid) ? {24'b0, 8'hff}
                              : (!mstr_req_msg && mstr_req_eot && ctrl_state_idle && mstr_req_dw_len[1:0] == 1) ? {28'b0, mstr_req_first_be}
                              : (!mstr_req_msg && mstr_req_eot && ctrl_state_idle && mstr_req_dw_len[1:0] == 2) ? {24'b0, mstr_req_last_be,     mstr_req_first_be}
                              : (!mstr_req_msg && mstr_req_eot && ctrl_state_idle && mstr_req_dw_len[1:0] == 3) ? {20'b0, mstr_req_last_be,4'hF,mstr_req_first_be}
                              : (!mstr_req_msg && mstr_req_eot && ctrl_state_idle && mstr_req_dw_len[1:0] == 0) ? {16'b0, mstr_req_last_be,8'hFF,mstr_req_first_be}
                              : (mstr_req_msg && mstr_req_eot && ctrl_state_idle && mstr_req_dw_len[1:0] == 1) ? {28'b0, 4'hF}
                              : (mstr_req_msg && mstr_req_eot && ctrl_state_idle && mstr_req_dw_len[1:0] == 2) ? {24'b0, 8'hFF}
                              : (mstr_req_msg && mstr_req_eot && ctrl_state_idle && mstr_req_dw_len[1:0] == 3) ? {20'b0, 12'hFFF}
                              : (mstr_req_msg && mstr_req_eot && ctrl_state_idle && mstr_req_dw_len[1:0] == 0) ? {16'b0, 16'hFFFF}

                              : (mstr_req_msg && mstr_req_eot && r_mstr_req_dw_len[1:0] == 1) ? {28'b0, 4'hF}
                              : (mstr_req_msg && mstr_req_eot && r_mstr_req_dw_len[1:0] == 2) ? {24'b0, 8'hFF}
                              : (mstr_req_msg && mstr_req_eot && r_mstr_req_dw_len[1:0] == 3) ? {20'b0, 12'hFFF}
                              : (mstr_req_msg && mstr_req_eot && r_mstr_req_dw_len[1:0] == 0) ? {16'b0, 16'hFFFF}

                              : (mstr_req_eot && r_mstr_req_dw_len[1:0] == 1) ? {28'b0, r_mstr_req_last_be}
                              : (mstr_req_eot && r_mstr_req_dw_len[1:0] == 2) ? {24'b0, r_mstr_req_last_be, 4'hF}
                              : (mstr_req_eot && r_mstr_req_dw_len[1:0] == 3) ? {20'b0, r_mstr_req_last_be, 8'hFF}
                              : (mstr_req_eot && r_mstr_req_dw_len[1:0] == 0) ? {16'b0, r_mstr_req_last_be, 12'hFFF}
                              : (!mstr_req_msg && !mstr_req_eot && ctrl_state_idle) ? {28'hFFFFFFF, mstr_req_first_be}
                              : 32'hFFFFFFFF;

         assign ctrl_mbe = padded_wstrb[CORE_REQ_DATA_BUS_WSTRB_WD -1 :0];

      end else if (REQ_NW==2) begin : gen_padd_2_strb

         assign ctrl_mbe = (ctrl_state_idle && mstr_req_msg && !mstr_req_fmt[1] && !mstr_req_hdr_uppr_bytes_valid) ? 0
                              : (ctrl_state_idle && mstr_req_msg && !mstr_req_fmt[1] && mstr_req_hdr_uppr_bytes_valid) ? {8'hff}
                              : (!mstr_req_msg && mstr_req_eot && ctrl_state_idle && mstr_req_dw_len[1]) ? {mstr_req_last_be,     mstr_req_first_be}
                              : (!mstr_req_msg && mstr_req_eot && ctrl_state_idle && !mstr_req_dw_len[1]) ? {4'b0, mstr_req_first_be}
                              : (!mstr_req_msg && !mstr_req_eot && ctrl_state_idle) ? {4'hF, mstr_req_first_be}
                              : (mstr_req_msg && mstr_req_eot && ctrl_state_idle && mstr_req_dw_len[0]) ? {4'b0, 4'hF}  // odd case
                              : (mstr_req_msg && mstr_req_eot && ctrl_state_idle && !mstr_req_dw_len[0]) ? {8'hFF} // even case

                              : (mstr_req_msg && mstr_req_eot &&  r_mstr_req_dw_len[0]) ? {4'b0, 4'hF}  // odd case
                              : (mstr_req_msg && mstr_req_eot &&  !r_mstr_req_dw_len[0]) ? {8'hFF} // even case

                              : (mstr_req_eot && r_mstr_req_dw_len[0]) ? {4'b0, r_mstr_req_last_be}  // odd case
                              : (mstr_req_eot && !r_mstr_req_dw_len[0]) ? {r_mstr_req_last_be, 4'hF} // even case
                              : 8'hFF;

      end else if (REQ_NW==1) begin : gen_padd_1_strb

         assign ctrl_mbe = (ctrl_state_idle && mstr_req_msg && !mstr_req_fmt[1] && !mstr_req_hdr_uppr_bytes_valid) ? 0
                              : (ctrl_state_idle && mstr_req_msg && !mstr_req_fmt[1] && mstr_req_hdr_uppr_bytes_valid) ? {4'hf}
                              : (!mstr_req_msg && ctrl_state_idle) ? mstr_req_first_be

                              : (mstr_req_msg && mstr_req_eot ) ? 4'hF

                              : (mstr_req_eot) ? r_mstr_req_last_be
                              : 4'hF;

      end
   endgenerate

   // SMD: Self determined expression present in the design
   // SJ: This self determined expression is over integers where no overflow is possbile with used configuration parameters
   // spyglass disable_block SelfDeterminedExpr-ML
   assign ctrl_mbe_ctrl =  ctrl_state_idle ? (mstr_req_msg ? {CC_MSTR_BE_CTRL_WIDTH{1'b1}} : cdc_inbd_hdr_pnp[`INBD_HDR_PNP_RANGE_DECMP_BECTRL_HIGH:`INBD_HDR_PNP_RANGE_DECMP_BECTRL_LOW]) :
                          (r_mstr_req_msg ? {CC_MSTR_BE_CTRL_WIDTH{1'b1}} : r_cdc_inbd_hdr_pnp[`INBD_HDR_PNP_RANGE_DECMP_BECTRL_HIGH:`INBD_HDR_PNP_RANGE_DECMP_BECTRL_LOW]);
   // spyglass enable_block SelfDeterminedExpr-ML

   // convert the PCIe dword length to AXI/AHB burst len.
   // Note: Burst len (ctrl_mlen) == 0 means 1 burst

   assign ctrl_mabort   = ctrl_state_idle ?   cdc_inbd_hdr_pnp[`INBD_HDR_PNP_RANGE_TLP_ABORT_HIGH:`INBD_HDR_PNP_RANGE_TLP_ABORT_LOW] ||   cdc_inbd_hdr_pnp[`INBD_HDR_PNP_RANGE_DLLP_ABORT_HIGH:`INBD_HDR_PNP_RANGE_DLLP_ABORT_LOW] :
                                            r_cdc_inbd_hdr_pnp[`INBD_HDR_PNP_RANGE_TLP_ABORT_HIGH:`INBD_HDR_PNP_RANGE_TLP_ABORT_LOW] || r_cdc_inbd_hdr_pnp[`INBD_HDR_PNP_RANGE_DLLP_ABORT_HIGH:`INBD_HDR_PNP_RANGE_DLLP_ABORT_LOW] ;

   assign ctrl_mdata = cdc_inbd_data_pnp;

   assign ctrl_mmisc[`MSTR_MISCINF_RANGE_REQ_DMA_HIGH:`MSTR_MISCINF_RANGE_REQ_DMA_LOW]   = ctrl_inbd_hdr_pnp[`INBD_HDR_PNP_RANGE_REQ_DMA_HIGH:`INBD_HDR_PNP_RANGE_REQ_DMA_LOW]; //spyglass disable SelfDeterminedExpr-ML
   assign ctrl_mmisc[`MSTR_MISCINF_RANGE_REQ_DMA_CHAN_HIGH:`MSTR_MISCINF_RANGE_REQ_DMA_CHAN_LOW]   = ctrl_inbd_hdr_pnp[`INBD_HDR_PNP_RANGE_REQ_DMA_CHAN_HIGH:`INBD_HDR_PNP_RANGE_REQ_DMA_CHAN_LOW]; //spyglass disable SelfDeterminedExpr-ML
   assign ctrl_mmisc[`MSTR_MISCINF_RANGE_MEM_TYPE_HIGH:`MSTR_MISCINF_RANGE_MEM_TYPE_LOW] = ctrl_inbd_hdr_pnp[`INBD_HDR_PNP_RANGE_MEM_TYPE_HIGH:`INBD_HDR_PNP_RANGE_MEM_TYPE_LOW]; //spyglass disable SelfDeterminedExpr-ML
   assign ctrl_mmisc[`MSTR_MISCINF_RANGE_TLP_TYPE_HIGH:`MSTR_MISCINF_RANGE_TLP_TYPE_LOW] = ctrl_inbd_hdr_pnp[`INBD_HDR_PNP_RANGE_TYPE_HIGH:`INBD_HDR_PNP_RANGE_TYPE_LOW]; //spyglass disable SelfDeterminedExpr-ML
   assign ctrl_mmisc[`MSTR_MISCINF_RANGE_TLP_FMT_HIGH :`MSTR_MISCINF_RANGE_TLP_FMT_LOW ] = ctrl_inbd_hdr_pnp[`INBD_HDR_PNP_RANGE_FMT_HIGH:`INBD_HDR_PNP_RANGE_FMT_LOW]; //spyglass disable SelfDeterminedExpr-ML
   assign ctrl_mmisc[`MSTR_MISCINF_RANGE_ATS_HIGH:`MSTR_MISCINF_RANGE_ATS_LOW]           = ctrl_inbd_hdr_pnp[`INBD_HDR_PNP_RANGE_ATS_HIGH:`INBD_HDR_PNP_RANGE_ATS_LOW]; //spyglass disable SelfDeterminedExpr-ML
   assign ctrl_mmisc[`MSTR_MISCINF_RANGE_NW_HIGH:`MSTR_MISCINF_RANGE_NW_LOW ]            = ctrl_inbd_hdr_pnp[`INBD_HDR_PNP_RANGE_NW_HIGH:`INBD_HDR_PNP_RANGE_NW_LOW]; //spyglass disable SelfDeterminedExpr-ML
   assign ctrl_mmisc[`MSTR_MISCINF_RANGE_CXLSRC_HIGH:`MSTR_MISCINF_RANGE_CXLSRC_LOW ]    = ctrl_inbd_hdr_pnp[`INBD_HDR_PNP_RANGE_CXLSRC_HIGH:`INBD_HDR_PNP_RANGE_CXLSRC_LOW]; //spyglass disable SelfDeterminedExpr-ML
   assign ctrl_mmisc[`MSTR_MISCINF_RANGE_FUNC_NUM_HIGH:`MSTR_MISCINF_RANGE_FUNC_NUM_LOW] = ctrl_inbd_hdr_pnp[`INBD_HDR_PNP_RANGE_FUNC_NUM_HIGH:`INBD_HDR_PNP_RANGE_FUNC_NUM_LOW]; //spyglass disable SelfDeterminedExpr-ML
   assign ctrl_mmisc[`MSTR_MISCINF_RANGE_TLP_TAG_HIGH:`MSTR_MISCINF_RANGE_TLP_TAG_LOW]      = ctrl_inbd_hdr_pnp[`INBD_HDR_PNP_RANGE_TAG_HIGH:`INBD_HDR_PNP_RANGE_TAG_LOW]; //spyglass disable SelfDeterminedExpr-ML
   assign ctrl_mmisc[`MSTR_MISCINF_RANGE_REQID_HIGH:`MSTR_MISCINF_RANGE_REQID_LOW  ]        = ctrl_inbd_hdr_pnp[`INBD_HDR_PNP_RANGE_REQID_HIGH:`INBD_HDR_PNP_RANGE_REQID_LOW]; //spyglass disable SelfDeterminedExpr-ML
   assign ctrl_mmisc[`MSTR_MISCINF_RANGE_TC_HIGH   :`MSTR_MISCINF_RANGE_TC_LOW     ]        = ctrl_inbd_hdr_pnp[`INBD_HDR_PNP_RANGE_TC_HIGH:`INBD_HDR_PNP_RANGE_TC_LOW]; //spyglass disable SelfDeterminedExpr-ML
   assign {ctrl_mmisc[`MSTR_MISCINF_RANGE_TLP_ATTR_IDO_HIGH:`MSTR_MISCINF_RANGE_TLP_ATTR_IDO_LOW],
           ctrl_mmisc[`MSTR_MISCINF_RANGE_TLP_ATTR_RO_HIGH:`MSTR_MISCINF_RANGE_TLP_ATTR_RO_LOW],
           ctrl_mmisc[`MSTR_MISCINF_RANGE_TLP_ATTR_NS_HIGH:`MSTR_MISCINF_RANGE_TLP_ATTR_NS_LOW]}  = ctrl_inbd_hdr_pnp[`INBD_HDR_PNP_RANGE_ATTR_HIGH:`INBD_HDR_PNP_RANGE_ATTR_LOW]; //spyglass disable SelfDeterminedExpr-ML
   assign ctrl_mmisc[`MSTR_MISCINF_RANGE_ROM_IN_RANGE_HIGH   :`MSTR_MISCINF_RANGE_ROM_IN_RANGE_LOW   ]= ctrl_inbd_hdr_pnp[`INBD_HDR_PNP_RANGE_ROM_IN_RANGE_HIGH:`INBD_HDR_PNP_RANGE_ROM_IN_RANGE_LOW]; //spyglass disable SelfDeterminedExpr-ML
   assign ctrl_mmisc[`MSTR_MISCINF_RANGE_IO_REQ_IN_RANGE_HIGH:`MSTR_MISCINF_RANGE_IO_REQ_IN_RANGE_LOW]= ctrl_inbd_hdr_pnp[`INBD_HDR_PNP_RANGE_IO_REQ_IN_RANGE_HIGH:`INBD_HDR_PNP_RANGE_IO_REQ_IN_RANGE_LOW]; //spyglass disable SelfDeterminedExpr-ML
   assign ctrl_mmisc[`MSTR_MISCINF_RANGE_IN_MEMBAR_RANGE_HIGH:`MSTR_MISCINF_RANGE_IN_MEMBAR_RANGE_LOW]= ctrl_inbd_hdr_pnp[`INBD_HDR_PNP_RANGE_IN_MEMBAR_RANGE_HIGH:`INBD_HDR_PNP_RANGE_IN_MEMBAR_RANGE_LOW]; //spyglass disable SelfDeterminedExpr-ML
   assign ctrl_mmisc[`MSTR_MISCINF_RANGE_BYTE_LEN_LBITS_HIGH :`MSTR_MISCINF_RANGE_BYTE_LEN_LBITS_LOW ]= ctrl_mlen[2:0]; //spyglass disable SelfDeterminedExpr-ML
   assign ctrl_mmisc[`MSTR_MISCINF_RANGE_LAST_BE_HIGH        :`MSTR_MISCINF_RANGE_LAST_BE_LOW        ]= ctrl_inbd_hdr_pnp[`INBD_HDR_PNP_RANGE_LAST_BE_HIGH:`INBD_HDR_PNP_RANGE_LAST_BE_LOW]; //spyglass disable SelfDeterminedExpr-ML
   assign ctrl_mmisc[`MSTR_MISCINF_RANGE_FIRST_BE_HIGH       :`MSTR_MISCINF_RANGE_FIRST_BE_LOW       ]= ctrl_inbd_hdr_pnp[`INBD_HDR_PNP_RANGE_FIRST_BE_HIGH:`INBD_HDR_PNP_RANGE_FIRST_BE_LOW]; //spyglass disable SelfDeterminedExpr-ML
   assign ctrl_mmisc[`MSTR_MISCINF_RANGE_TLP_PRFX_HIGH       :`MSTR_MISCINF_RANGE_TLP_PRFX_LOW       ]= ctrl_inbd_hdr_pnp[`INBD_HDR_PNP_RANGE_TLP_PRFX_HIGH:`INBD_HDR_PNP_RANGE_TLP_PRFX_LOW]; //spyglass disable SelfDeterminedExpr-ML
   assign ctrl_mmisc[`MSTR_MISCINF_RANGE_TPH_SET_HIGH:`MSTR_MISCINF_RANGE_TPH_SET_LOW]       = ctrl_inbd_hdr_pnp[`INBD_HDR_PNP_RANGE_TPH_SET_HIGH:`INBD_HDR_PNP_RANGE_TPH_SET_LOW]; //spyglass disable SelfDeterminedExpr-ML
   assign ctrl_mmisc[`MSTR_MISCINF_RANGE_TPH_PH_HIGH:`MSTR_MISCINF_RANGE_TPH_PH_LOW]         = ctrl_inbd_hdr_pnp[`INBD_HDR_PNP_RANGE_TPH_PH_HIGH:`INBD_HDR_PNP_RANGE_TPH_PH_LOW]; //spyglass disable SelfDeterminedExpr-ML
   assign ctrl_mmisc[`MSTR_MISCINF_RANGE_TPH_TH_HIGH:`MSTR_MISCINF_RANGE_TPH_TH_LOW]         = ctrl_inbd_hdr_pnp[`INBD_HDR_PNP_RANGE_TPH_TH_HIGH:`INBD_HDR_PNP_RANGE_TPH_TH_LOW]; //spyglass disable SelfDeterminedExpr-ML
   assign ctrl_mmisc[`MSTR_MISCINF_RANGE_RESERV_HIGH:`MSTR_MISCINF_RANGE_RESERV_LOW]         = 3'b000; //spyglass disable SelfDeterminedExpr-ML

   assign ctrl_mmisc[`MSTR_MISCINF_RANGE_PSEQ_HIGH:`MSTR_MISCINF_RANGE_PSEQ_LOW]             = ctrl_inbd_hdr_pnp[`INBD_HDR_PNP_RANGE_SEQ_HIGH:`INBD_HDR_PNP_RANGE_SEQ_LOW]; //spyglass disable SelfDeterminedExpr-ML
   assign ctrl_mmisc[`MSTR_MISCINF_RANGE_HDR_UPPR_BYTES_VALID_HIGH:`MSTR_MISCINF_RANGE_HDR_UPPR_BYTES_VALID_LOW]    = ctrl_inbd_hdr_pnp[`INBD_HDR_PNP_RANGE_HDR_UPPR_BYTES_VALID_HIGH:`INBD_HDR_PNP_RANGE_HDR_UPPR_BYTES_VALID_LOW]; //spyglass disable SelfDeterminedExpr-ML
   assign ctrl_mmisc[`MSTR_MISCINF_RANGE_DWLEN_HIGH:`MSTR_MISCINF_RANGE_DWLEN_LOW]           = ctrl_inbd_hdr_pnp[`INBD_HDR_PNP_RANGE_DW_LEN_LOW+:2]; //spyglass disable SelfDeterminedExpr-ML
   assign ctrl_mmisc[`MSTR_MISCINF_RANGE_EP_HIGH]    = ctrl_inbd_hdr_pnp[`INBD_HDR_PNP_RANGE_POISONED_HIGH]; //spyglass disable SelfDeterminedExpr-ML
   assign ctrl_mmisc[`MSTR_MISCINF_RANGE_DST_SEGMENT_HIGH:`MSTR_MISCINF_RANGE_DST_SEGMENT_LOW] = ctrl_inbd_hdr_pnp[`INBD_HDR_PNP_RANGE_DST_SEGMENT_HIGH:`INBD_HDR_PNP_RANGE_DST_SEGMENT_LOW]; //spyglass disable SelfDeterminedExpr-ML
   assign ctrl_mmisc[`MSTR_MISCINF_RANGE_REQ_SEGMENT_HIGH:`MSTR_MISCINF_RANGE_REQ_SEGMENT_LOW] = ctrl_inbd_hdr_pnp[`INBD_HDR_PNP_RANGE_REQ_SEGMENT_HIGH:`INBD_HDR_PNP_RANGE_REQ_SEGMENT_LOW]; //spyglass disable SelfDeterminedExpr-ML
   //*****************************************
   // Down converter stage
   //*****************************************

generate
   if ((`MASTER_BUS_DATA_WIDTH < `PCIE_CORE_DATA_BUS_WD) && MRF_WR_NOT_RD_QUEUE) begin : gen_down_convert
//`ifdef CX_ATOMIC_ENABLE
//      localparam CC_MSTR_BUS_DATA_HALF_WIDTH = (CC_MSTR_BUS_DATA_WIDTH >> 1);
//
//      logic                              s_cas_valid ;
//      logic                              s_mlen_log2 ;
//      logic [2:0]                        r_cas_cntr  ;
//      logic [CORE_REQ_DATA_BUS_WD-1:0]   s_ctrl_mdata;
//      logic [CC_MSTR_BUS_DATA_WIDTH-1:0] s_dc_mdata  ;
//
//      assign s_cas_valid = pkg_atop_fmt_type_e'({ctrl_mmisc[`MSTR_MISCINF_RANGE_TLP_FMT_HIGH:`MSTR_MISCINF_RANGE_TLP_FMT_LOW], ctrl_mmisc[`MSTR_MISCINF_RANGE_TLP_TYPE_HIGH:`MSTR_MISCINF_RANGE_TLP_TYPE_LOW]}) inside {CAS32,CAS64};
//      assign s_mlen_log2 = log2((`CC_MSTR_MTU_PW)'(ctrl_mlen));
//
//      always @(posedge mstr_aclk or negedge mstr_arstn) begin : proc_cas_addr
//        if(!mstr_arstn) begin
//          r_cas_cntr <= #TP '0;
//        end else begin
//          if(s_cas_valid)
//            r_cas_cntr <= #TP r_cas_cntr + 1'b1;
//          else
//            r_cas_cntr <= #TP '0;
//        end
//      end
//
//      assign s_ctrl_mdata = ((ctrl_mlen >= (CC_CORE_DATA_BUS_WD >> 3)) & (ctrl_mlen > (CC_MSTR_BUS_DATA_WIDTH >> 3))) ? (r_cas_cntr ? 
//                            {{CC_MSTR_BUS_DATA_HALF_WIDTH{1'b0}},ctrl_mdata[CC_MSTR_BUS_DATA_HALF_WIDTH+:CC_MSTR_BUS_DATA_HALF_WIDTH]} : 
//                            {{CC_MSTR_BUS_DATA_HALF_WIDTH{1'b0}},ctrl_mdata[0+:CC_MSTR_BUS_DATA_HALF_WIDTH]}) : 
//                             ctrl_mdata;
//
//      
//      // Down conversion only exists on the read path
//      assign ctrl_wr_dvld = (ctrl_mstrobe && (|ctrl_mbe || mstr_req_eot));
//      DWC_pcie_gsdwncnvrt
//        #(
//          CORE_REQ_DATA_BUS_WD,
//          CORE_REQ_DATA_BUS_WSTRB_WD,
//          CC_MSTR_BUS_DATA_WIDTH,
//          NUM_CONV_WIDTH
//          )
//      u_dc (
//            .clk              (mstr_aclk),
//            .rst_n            (mstr_arstn),
//            .init_n           (high),
//
//            .data_vld_in      (ctrl_wr_dvld),
//            .data_last_in     (ctrl_mstrobe_last),
//            .data_strb_in     (ctrl_mbe),
//            .data_in          (s_ctrl_mdata),
//
//            .pop_data         (dc_saccept),
//            .data_accept      (st_saccept),
//
//            .data_vld_out     (dc_mstrobe),
//            .data_last_out    (dc_mstrobe_last),
//            .data_strb_out    (dc_mbe),
//            .data_out         (s_dc_mdata)
//            );
//
//      assign dc_mdata = ((mlen >= CC_MSTR_BUS_DATA_WIDTH) & mlast) ? ctrl_mdata[CC_MSTR_BUS_DATA_WIDTH-1:0] : s_dc_mdata;
//
//`else // !CX_ATOMIC_ENABLE
      // Down conversion only exists on the read path
      assign ctrl_wr_dvld = (ctrl_mstrobe && (|ctrl_mbe || mstr_req_eot));
      DWC_pcie_gsdwncnvrt
      
        #(
          CORE_REQ_DATA_BUS_WD,
          CORE_REQ_DATA_BUS_WSTRB_WD,
          CC_MSTR_BUS_DATA_WIDTH,
          NUM_CONV_WIDTH
          )
      u_dc (
            .clk              (mstr_aclk),
            .rst_n            (mstr_arstn),
            .init_n           (high),

            .data_vld_in      (ctrl_wr_dvld),
            .data_last_in     (ctrl_mstrobe_last),
            .data_strb_in     (ctrl_mbe),
            .data_in          (ctrl_mdata),

            .pop_data         (dc_saccept),
            .data_accept      (st_saccept),

            .data_vld_out     (dc_mstrobe),
            .data_last_out    (dc_mstrobe_last),
            .data_strb_out    (dc_mbe),
            .data_out         (dc_mdata)
            );
//`endif // CX_ATOMIC_ENABLE
   end else begin : gen_no_down_convert
      assign ctrl_wr_dvld = 1'b0;
      assign dc_mstrobe   = ctrl_mstrobe;
      assign dc_mstrobe_last = ctrl_mstrobe_last;
      assign dc_mbe       = ctrl_mbe[CC_MSTR_BUS_WSTRB_WIDTH-1:0];
      assign dc_mdata     = ctrl_mdata[CC_MSTR_BUS_DATA_WIDTH-1:0];
      assign dc_saccept   = high;
   end
endgenerate

   assign dc_maddr      = ctrl_maddr;
   assign dc_mid        = ctrl_mid;
   assign dc_mlast_tlp  = ctrl_mlast_tlp;
   assign dc_mlen       = ctrl_mlen[CC_MSTR_MTU_PW-1:0];
   assign dc_mbe_ctrl   = ctrl_mbe_ctrl;
   assign dc_mabort     = ctrl_mabort;
   assign dc_mmisc      = ctrl_mmisc;

   //****************************************
   // Output stalling
   //*****************************************
   // Request stall halt in
   assign req_halt_in = (!saccept & mstrobe);
   assign st_saccept = !st_req_halt_out;

   assign st_req_stall_din = {
                              dc_mstrobe,
                              dc_mstrobe_last,
                              dc_mid,
                              dc_maddr,
                              dc_mlast_tlp,
                              dc_mlen,
                              dc_mbe,
                              dc_mbe_ctrl,
                              dc_mabort,
                              dc_mmisc,
                              dc_mdata
                              };

   logic                     w_u1_st_vld_to_dest;
   logic [REQ_DP_WIDTH -1:0] w_u1_st_chanl_to_dest;

   logic                     w_u1_st_rdy_to_src;

   DWC_pcie_axi_rs
    #(
     .P_FEED_READY ( 1            )
    ,.CHAN_WD      ( REQ_DP_WIDTH )
   ) u1_st (
     .clk            ( mstr_aclk             )
    ,.rstn           ( mstr_arstn            )
    ,.clrn           ( 1'b1                  )

    ,.vld_from_src   ( dc_mstrobe            )
    ,.chanl_from_src ( st_req_stall_din      )
    ,.rdy_to_src     ( w_u1_st_rdy_to_src    )

    ,.vld_to_dest    ( w_u1_st_vld_to_dest   )
    ,.chanl_to_dest  ( w_u1_st_chanl_to_dest )
    ,.rdy_from_dest  ( ~req_halt_in          )
   );

   assign st_req_stall_dout = {w_u1_st_chanl_to_dest[REQ_DP_WIDTH-1] & w_u1_st_vld_to_dest, w_u1_st_chanl_to_dest[REQ_DP_WIDTH-2:0]};
   assign st_req_halt_out   = ~w_u1_st_rdy_to_src;

   always @ (posedge mstr_aclk or negedge mstr_arstn) begin : PROC_seq_stall
      if (!mstr_arstn) begin
         r_st_req_stall_dout <= # TP {REQ_DP_WIDTH-1{1'b0}};
      end else begin
         if (st_req_stall_dout[REQ_DP_WIDTH-1])
           r_st_req_stall_dout <= # TP st_req_stall_dout[REQ_DP_WIDTH-2:0];
      end
   end

   //st_req_stall_dout[REQ_DP_WIDTH-1] = mstrobe
   //Holds last data when mstrobe is not asserted
   //the bridge master requires it

   assign {
           mstrobe,
           mstrobe_last,
           mid,
           maddr,
           mlast,
           mlen,
           mbe,
           mbe_ctrl,
           mabort,
           mmisc,
           mdata
           } = st_req_stall_dout[REQ_DP_WIDTH-1] ? st_req_stall_dout : {1'b0, r_st_req_stall_dout};

   generate
      if ((`MASTER_BUS_DATA_WIDTH < `PCIE_CORE_DATA_BUS_WD) && MRF_WR_NOT_RD_QUEUE) begin : gen_down_convert_halt_a
         assign cdc_inbd_halt_pnp = st_req_halt_out || (ctrl_wr_dvld && !dc_saccept) || arbmcb_halt_mrf;
      end else begin : gen_no_down_convert_halt_a
         assign cdc_inbd_halt_pnp = st_req_halt_out || arbmcb_halt_mrf;
      end
   endgenerate

   //Halt without Master Completion serialization halt
   generate
      if ((`MASTER_BUS_DATA_WIDTH < `PCIE_CORE_DATA_BUS_WD) && MRF_WR_NOT_RD_QUEUE) begin : gen_down_convert_halt_b
         assign cdc_inbd_halt_pnp_mcb = st_req_halt_out || (ctrl_wr_dvld && !dc_saccept);
      end else begin : gen_no_down_convert_halt_b
         assign cdc_inbd_halt_pnp_mcb = st_req_halt_out;
      end
   endgenerate


   // -------------------------------------------------------------------------------------
   // Functions
   // -------------------------------------------------------------------------------------

   function automatic [1:0] get_low_addr;
      input   [3:0]   byte_en;
      begin
         case  (byte_en)
             4'b0010 :   get_low_addr = 2'b01;
             4'b1110 :   get_low_addr = 2'b01;
             4'b0110 :   get_low_addr = 2'b01;
             4'b1010 :   get_low_addr = 2'b01; // ccx_line: u_axi_bridge.u_ib.u_ibreq.u_rdq.u_mrf; REDUNDANT: This config decomposes NCBEs reads so this first BE value never reaches this module
             4'b0100 :   get_low_addr = 2'b10;
             4'b1100 :   get_low_addr = 2'b10;
             4'b1000 :   get_low_addr = 2'b11;
             default :  get_low_addr = 2'b0;
           endcase
         end
   endfunction


   function automatic [12:0] get_byte_count;
      input [DC_INBD_HEADER_PNP_WD-1:0]     inbd_hdr_pnp;
      input                                 req_msg;
      input                                 req_msgd;

      reg [3:0]                             first_dwen;
      reg [3:0]                             last_dwen;
      reg [12:0]                            latchd_dwlen;
      reg [12:0]                            f_length_times4;
      reg [12:0]                            f_bytelength;
      reg [2 :0]                            f_subend;
      begin

         first_dwen   = inbd_hdr_pnp[`INBD_HDR_PNP_RANGE_FIRST_BE_HIGH:`INBD_HDR_PNP_RANGE_FIRST_BE_LOW]; //spyglass disable SelfDeterminedExpr-ML
         last_dwen    = inbd_hdr_pnp[`INBD_HDR_PNP_RANGE_LAST_BE_HIGH:`INBD_HDR_PNP_RANGE_LAST_BE_LOW]; //spyglass disable SelfDeterminedExpr-ML
         //Converting bytes to words (any (n x words) + 1 or 2 or 3 bytes, rounds up in the word count)
         latchd_dwlen = ({1'b0, inbd_hdr_pnp[`INBD_HDR_PNP_RANGE_DECMP_BELEN_HIGH:`INBD_HDR_PNP_RANGE_DECMP_BELEN_LOW+2]}) + //spyglass disable SelfDeterminedExpr-ML
                        {12'd0, (|inbd_hdr_pnp[`INBD_HDR_PNP_RANGE_DECMP_BELEN_LOW+1:`INBD_HDR_PNP_RANGE_DECMP_BELEN_LOW])}; //spyglass disable SelfDeterminedExpr-ML

         if (latchd_dwlen[9:0] == 0)
           f_length_times4 = 13'd4096;
         else
           f_length_times4 = {1'b0, latchd_dwlen[9:0], 2'b0};

         f_subend = 3'b0;

         if (last_dwen == 0) begin
            case  (first_dwen)
              4'b1001, 4'b1011, 4'b1101, 4'b1111 : f_bytelength = 4;
              4'b0101, 4'b0111, 4'b1010, 4'b1110 : f_bytelength = 3;
              4'b0011, 4'b0110, 4'b1100          : f_bytelength = 2;
              4'b0000                            : f_bytelength = 0;
              default                            : f_bytelength = 1;
            endcase
         end else begin
            casez (first_dwen)
              4'b???1:
                casez (last_dwen)
                  4'b1???: f_bytelength = f_length_times4;
                  4'b01??: f_bytelength = f_length_times4 -1;
                  4'b001?: f_bytelength = f_length_times4 -2;
                  default: f_bytelength = f_length_times4 -3;
                endcase
              4'b??10:
                casez (last_dwen)
                  4'b1???: f_bytelength = f_length_times4 -1;
                  4'b01??: f_bytelength = f_length_times4 -2;
                  4'b001?: f_bytelength = f_length_times4 -3;
                  default: f_bytelength = f_length_times4 -4;
                endcase
              4'b?100:
                casez (last_dwen)
                  4'b1???: f_bytelength = f_length_times4 -2;
                  4'b01??: f_bytelength = f_length_times4 -3;
                  4'b001?: f_bytelength = f_length_times4 -4;
                  default: f_bytelength = f_length_times4 -5;
                endcase
              default:
                casez (last_dwen)
                  4'b1???: f_bytelength = f_length_times4 -3;
                  4'b01??: f_bytelength = f_length_times4 -4;
                  4'b001?: f_bytelength = f_length_times4 -5;
                  default: f_bytelength = f_length_times4 -6;
                endcase
            endcase

         end

         if (req_msgd) begin
            get_byte_count = f_length_times4; // ccx_line: u_axi_bridge.u_ib.u_ibreq.u_rdq.u_mrf; REDUNDANT: Read requests can never be messages
         end else if (req_msg) begin
            get_byte_count = {1'b0, latchd_dwlen[9:0], 2'd0};
         end else begin
            get_byte_count = f_bytelength;
         end
      end
   endfunction

  // Address without parity
  function automatic [CC_CORE_ADDR_BUS_WD_NP-1:0] fn_addr_wo_par;
    input [CC_CORE_ADDR_BUS_WD-1:0] s_addr_w_par;
    integer i,j;
    begin
      for (i=0; i<NUM_ADDR_PAR_BLOCKS; i=i+1)  begin // interate thru parity block size
       for (j=0; j<CX_RAS_PROT_RANGE; j=j+1)  begin // interate thru parity block size bits
          fn_addr_wo_par[i*CX_RAS_PROT_RANGE +j] = s_addr_w_par[i*CX_RAS_PROT_RANGE +j +i];//spyglass disable SelfDeterminedExpr-ML
        end
      end
    end
  endfunction

// Data without parity
  function automatic [CORE_REQ_DATA_BUS_WD_NP-1:0] fn_data_wo_par;
    input [CORE_REQ_DATA_BUS_WD-1:0] s_data_w_par;
    integer i,j;
    begin
      for (i=0; i<NUM_DATA_PAR_BLOCKS; i=i+1)  begin // interate thru parity block size
       for (j=0; j<CX_RAS_PROT_RANGE; j=j+1)  begin // interate thru parity block size bits
          fn_data_wo_par[i*CX_RAS_PROT_RANGE +j] = s_data_w_par[i*CX_RAS_PROT_RANGE +j +i];//spyglass disable SelfDeterminedExpr-ML
        end
      end
    end
  endfunction

  // Data with parity
  function automatic [CORE_REQ_DATA_BUS_WD-1:0] fn_data_w_par;
    input [CORE_REQ_DATA_BUS_WD_NP-1:0] s_data_wo_par;

    integer i, j;
    reg [CX_RAS_PROT_RANGE-1:0] s_data_for_par;

    begin
    fn_data_w_par  = {CORE_REQ_DATA_BUS_WD{1'b0}};
    s_data_for_par = {CX_RAS_PROT_RANGE{1'b0}};

      for (i=0; i<(NUM_DATA_PAR_BLOCKS); i=i+1) begin
        for (j=0; j<CX_RAS_PROT_RANGE; j=j+1) begin
          s_data_for_par[j]=s_data_wo_par[i*CX_RAS_PROT_RANGE +j];//spyglass disable SelfDeterminedExpr-ML
          fn_data_w_par[i*CX_RAS_PROT_RANGE +j+i] = s_data_wo_par[i*CX_RAS_PROT_RANGE +j];//spyglass disable SelfDeterminedExpr-ML
        end
        fn_data_w_par[(i+1)*CX_RAS_PROT_RANGE +i] = !(^CX_RAS_PARITY_MODE) ? ^s_data_for_par : ~(^s_data_for_par);
      end
    end
  endfunction

  // Address with parity
  function automatic [CC_CORE_ADDR_BUS_WD-1:0] fn_addr_w_par;
    input [CC_CORE_ADDR_BUS_WD_NP-1:0] s_addr_wo_par;

    integer i, j;
    reg [CX_RAS_PROT_RANGE-1:0] s_addr_for_par;

    begin
      fn_addr_w_par  = 0;
      s_addr_for_par = 0;

      for (i=0; i<(NUM_ADDR_PAR_BLOCKS); i=i+1) begin
         for (j=0; j<CX_RAS_PROT_RANGE; j=j+1) begin
           s_addr_for_par[j]=s_addr_wo_par[i*CX_RAS_PROT_RANGE +j];//spyglass disable SelfDeterminedExpr-ML
           fn_addr_w_par[i*CX_RAS_PROT_RANGE +j+i] = s_addr_wo_par[i*CX_RAS_PROT_RANGE +j];//spyglass disable SelfDeterminedExpr-ML
         end
          fn_addr_w_par[(i+1)*CX_RAS_PROT_RANGE +i] = !(^CX_RAS_PARITY_MODE) ? ^s_addr_for_par : ~(^s_addr_for_par);
      end
    end
  endfunction

  function automatic [NUM_ADDR_PAR_BLOCKS-1:0] fn_prot_chkin_ad;
    input [CC_CORE_ADDR_BUS_WD-1:0] s_addr_w_par;
    integer i;
    begin
      for (i=0; i<NUM_ADDR_PAR_BLOCKS; i=i+1) begin
        fn_prot_chkin_ad[i] = s_addr_w_par[i*CX_RAS_PROT_RANGE + i + CX_RAS_PROT_RANGE];
      end
    end
  endfunction

  function automatic [NUM_DATA_PAR_BLOCKS-1:0] fn_prot_chkin_dt;
    input [CORE_REQ_DATA_BUS_WD-1:0] s_data_w_par;
    integer i;
    begin
      for (i=0; i<NUM_DATA_PAR_BLOCKS; i=i+1) begin
        fn_prot_chkin_dt[i] = s_data_w_par[i*CX_RAS_PROT_RANGE + i + CX_RAS_PROT_RANGE];
      end
    end
  endfunction 


endmodule
