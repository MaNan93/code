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
// ---    $Revision: #14 $
// ---    $Id: //dwh/pcie_iip/main/fairbanks/design/Layer2/rdlh_tlp_extract.sv#14 $
// -------------------------------------------------------------------------
// --- Module Description: Receive Data Link Layer TLP Extraction
// --- 1. Extract a TLP from a DLLP
// --- 2. Remove the LCRC and sequence number
// --- 3. Generate ACK/NAK/DupACK transmit request
// --- 4. Detect DLLP layer TLP error (LCRC error and sequence error)
// --- 5. Report bad TLP error and drop nullified TLP
// -----------------------------------------------------------------------------

`include "include/DWC_pcie_ctl_all_defs.svh"

 
 module rdlh_tlp_extract(
    core_clk,
    core_rst_n,
    rdlh_link_up,
    rplh_rdlh_tlp_start,
    rplh_rdlh_pkt_end,
    rplh_rdlh_pkt_edb,
    rplh_rdlh_pkt_data,
    rplh_rdlh_pkt_dv,
    rplh_rdlh_pkt_err,
    rplh_rdlh_nak,
    nak_scheduled,
    ras_rdlh_prot_disable,
    ras_err_inj_en_array,
    ras_err_inj_mask,
    cdm_ras_des_einj0_enable,
    cdm_ras_des_einj0_crc_type,
    cdm_ras_des_einj0_count,

    // ------------- outputs --------------
    ras_stat_rdlh_tlp_extract_corr,
    ras_stat_rdlh_tlp_extract_uncorr,
    rdlh_ptm_sot,
    rdlh_ptm_multi_cycle,
    rdlh_ptm_request,
    rdlh_ptm_response,
    rdlh_duplicate_tlp,
    rdlh_req2send_ack,
    rdlh_req2send_ack_due2dup,
    rdlh_req2send_nack,
    rdlh_req_acknack_seqnum,
`ifndef SYNTHESIS
`endif // SYNTHESIS
    rdlh_rtlh_tlp_data,
    rdlh_rtlh_tlp_dv,
    rdlh_rtlh_tlp_sot,
    rdlh_rtlh_tlp_eot,
    rdlh_rtlh_tlp_abort,
    ras_err_inj_done,    
    rdlh_bad_tlp_err
    ,
    rdlh_bad_tlp_err_pertlp,
    rdlh_lcrc_tlp_err_pertlp,
    rdlh_nulified_tlp_err_pertlp,
    rdlh_duplicate_tlp_err_pertlp
    ,
    rdlh_einj0_lcrc_evt
);

// =============================================================================
// Parameters
// =============================================================================
//
parameter   INST               = 0;                        // The uniquifying parameter for each port logic instance.
parameter   NW                 = (`CX_NW>16)? 16 : `CX_NW; // Number of 32-bit dwords handled by the datapath each clock.
parameter   DW                 = (32*NW);                  // Width of datapath in bits.
parameter   TP                 = `TP;                      // Clock to Q delay (simulator insurance)
parameter   CRC_LATENCY        = `CX_CRC_LATENCY_RDLH;     //adds a clk cycle delay if crc pipeline on. Min at least '1' delay

localparam SHIFT_SIZE          = (NW==1) ? 8 : 40; 
localparam RX_TLP_NFM          = `CX_RX_TLP_NFM;           // Number of TLPs that can be processed in this block in a single cycle
localparam RX_TLP_LOG2         = (RX_TLP_NFM==4) ? 2 : 1;
localparam CRC_LATENCY_M1      = CRC_LATENCY-1;            //adds a clk cycle '-1' delay if crc pipeline on. Min at least '0' delay

parameter DATA_PROT_WD        = `NFM_TRGT_DATA_PROT_WD;

parameter RAS_PROT_RANGE      = `CX_RAS_PROT_RANGE;
parameter RAS_PROT_TYPE       = `CX_RAS_PROT_TYPE;
parameter RAS_PROT_CORRECT_EN = `CX_RAS_CORRECTION_EN; 
parameter RAS_PARITY_MODE     = `CX_RAS_PARITY_MODE;
parameter ERROR_INJ_EN_WD     = `CX_RAS_ERROR_INJ_EN_WD;
parameter ERROR_INJ_MASK_WD   = `CX_RAS_ERROR_INJ_MASK_WD;


// =============================================================================
// inputs
// =============================================================================
input                   core_clk;             // core running clock
input                   core_rst_n;           // Core reset
input                   rdlh_link_up;         // Data link layer link up indication from RDLH link control state
input   [NW-1:0]        rplh_rdlh_tlp_start;  // MAC packet start
input   [NW-1:0]        rplh_rdlh_pkt_end;    // 4bits to indicate the dword location of END or EBD,  MAC packet END
input   [NW-1:0]        rplh_rdlh_pkt_edb;    // MAC packet end with EDB
input   [DW-1:0]        rplh_rdlh_pkt_data;   // MAC packet data
input                   rplh_rdlh_pkt_dv;     // MAC packet data valid
input   [NW-1:0]        rplh_rdlh_pkt_err;    // MAC packet error
input   [NW-1:0]        rplh_rdlh_nak;        // MAC packet error
input                   nak_scheduled;        // dllp generation block requests nak is scheduled to be transmitted
input                   ras_rdlh_prot_disable;
input  [ERROR_INJ_EN_WD  -1:0]  ras_err_inj_en_array;
input  [ERROR_INJ_MASK_WD-1:0]  ras_err_inj_mask;
input                   cdm_ras_des_einj0_enable;   // Error injection 0 enable
input   [3:0]           cdm_ras_des_einj0_crc_type; // Error injection 0 CRC type selector
input   [7:0]           cdm_ras_des_einj0_count;    // Error injection 0 count

// =============================================================================
// Outputs
// =============================================================================
output                  ras_stat_rdlh_tlp_extract_corr;  //error flags for the RAS statistics counters
output                  ras_stat_rdlh_tlp_extract_uncorr;  //error flags for the RAS statistics counters

output                  rdlh_ptm_sot;
output                  rdlh_ptm_multi_cycle;
output                  rdlh_ptm_request;
output                  rdlh_ptm_response;
output                  rdlh_duplicate_tlp;

output                  rdlh_req2send_ack;          // Control signal to request the transmission of an ACK
output                  rdlh_req2send_ack_due2dup;  // Control signal to request the transmission of an ACK due to duplicate. 
                                                    // When rdlh_req2send_ack_due2dup is asserted the rdlh_req2send_ack is asserted
output                  rdlh_req2send_nack;         // Control signal to request the transmission of a NACK
output  [11:0]          rdlh_req_acknack_seqnum;    // ACK/NACK sequence number
`ifndef SYNTHESIS
`endif // SYNTHESIS
output  [DW+DATA_PROT_WD-1:0] rdlh_rtlh_tlp_data;   // TLP packet data
output                  rdlh_rtlh_tlp_dv;           // TLP packet data valid indication signal
output  [NW-1:0]        rdlh_rtlh_tlp_sot;          // TLP packet start indication signal
output  [NW-1:0]        rdlh_rtlh_tlp_eot;          // TLP packet end indication signal
output [RX_TLP_NFM-1:0] rdlh_rtlh_tlp_abort;        // TLP packet abort due to DLLP layer error detected
output                  ras_err_inj_done;           // Error injection was performed
output                  rdlh_bad_tlp_err;           // Report to CDM that there is an error detected at DLLP layer
output [RX_TLP_NFM-1:0] rdlh_bad_tlp_err_pertlp;        // Puls : Rx Bad TLP Event per TLP for Ras D.E.S event counter
output [RX_TLP_NFM-1:0] rdlh_lcrc_tlp_err_pertlp;       // Puls : Rx LCRC Error TLP Event per TLP for Ras D.E.S event counter
output [RX_TLP_NFM-1:0] rdlh_nulified_tlp_err_pertlp;   // Puls : Rx Nullified TLP Event per TLP for Ras D.E.S event counter
output [RX_TLP_NFM-1:0] rdlh_duplicate_tlp_err_pertlp;  // Puls : Rx Duplicate TLP Event per TLP for Ras D.E.S event counter
output  [2:0]           rdlh_einj0_lcrc_evt;        // Error injection 0 event flag



// =============================================================================
// IO declaration
// =============================================================================
reg                     rdlh_req2send_ack;
reg                     rdlh_req2send_ack_due2dup;
reg                     rdlh_req2send_nack;
reg      [11:0]         rdlh_req_acknack_seqnum;
reg                     rdlh_clear_nak_scheduled;
wire[DW+DATA_PROT_WD-1:0]rdlh_rtlh_tlp_data;
wire                    rdlh_rtlh_tlp_dv;
wire     [NW-1:0]       rdlh_rtlh_tlp_sot;
wire     [NW-1:0]       rdlh_rtlh_tlp_eot;
wire   [RX_TLP_NFM-1:0] rdlh_rtlh_tlp_abort;
reg                     rdlh_bad_tlp_err;
`ifndef SYNTHESIS
`endif // SYNTHESIS

// =============================================================================
// internal signals declaration
// =============================================================================
wire     [NW-1:0]        tlp_aligned_sot;
wire     [NW-1:0]        tlp_aligned_eot;
wire                     tlp_aligned_short_sc; // single cycle 1 or 2 DW TLP
wire                     tlp_aligned_short_mc; // multi cycle 2 DW TLP
reg     [RX_TLP_NFM-1:0] tlp_aligned_abort_vec;
wire     [NW-1:0]        lcrc_aligned_eot;
wire                     tlp_aligned_badeot;
wire                     tlp_aligned_pkterr;
wire                     tlp_aligned_dv;
wire    [DW+DATA_PROT_WD-1:0] tlp_aligned_data;

//secondary delay signals to allow for pipelined crc on/off
reg     [NW-1:0]        tlp_aligned_sot_d;
reg     [NW-1:0]        tlp_aligned_eot_d;
reg     [NW-1:0]        lcrc_aligned_eot_d;
reg                     tlp_aligned_badeot_pre;
reg                     tlp_aligned_pkterr_d;
reg                     tlp_aligned_dv_d;
reg     [DW+DATA_PROT_WD-1:0]  tlp_aligned_data_d;

reg     [11:0]          tlp_extracted_seqnum_pre;

// Delayed version of inputs to line up with CRC
wire    [NW-1:0]        pipe_rdlh_tlp_start;
wire    [NW-1:0]        pipe_rdlh_pkt_end;
wire    [NW-1:0]        pipe_rdlh_pkt_edb;
wire    [DW-1:0]        tmp_pipe_rdlh_pkt_data;
wire    [DW+DATA_PROT_WD-1:0] pipe_rdlh_pkt_data;
wire                    pipe_rdlh_pkt_dv;
wire    [NW-1:0]        pipe_rdlh_pkterr;
wire    [NW-1:0]        pipe_rdlh_nak;

wire     [11:0]         tlp_extracted_seqnum;

reg                     packet_in_progress;
reg                     ant_packet_in_progress;
reg     [11:0]          tlp_expected_seqnum;
reg     [11:0]          tlp_seqnum;
wire    [NW-1:0]        pipe_eot;
reg     [DW+DATA_PROT_WD-1:0] pipe_pkt_data_d;
wire    [DW+DATA_PROT_WD-1:0] chk_pipe_pkt_data_d;
reg     [NW-1:0]        pipe_pkt_start_d;
reg                     pipe_nack;

wire                    or_aligned_eot;
logic   [NW-1:0]        tmp_aligned_sot;
logic   [NW-1:0]        tmp_aligned_eot;
logic   [NW-1:0]        tmp_aligned_badeot;
wire    [DW-1:0]        tmp_aligned_data;
wire                    tmp_aligned_dv;
wire                    tmp_aligned_short_sc;
wire                    tmp_aligned_short_mc;

reg [12*RX_TLP_NFM-1:0] seqnum_vec;
wire one_ends, two_ends, three_ends, four_ends;
wire one_sots, two_sots, three_sots, four_sots;

//--------------------------------
reg    [RX_TLP_NFM-1:0] rdlh_bad_tlp_err_pertlp;
reg    [RX_TLP_NFM-1:0] rdlh_lcrc_tlp_err_pertlp;
reg    [RX_TLP_NFM-1:0] rdlh_nulified_tlp_err_pertlp;
reg    [RX_TLP_NFM-1:0] rdlh_duplicate_tlp_err_pertlp;
// if RAS is used then prot_tmp_aligned_data is tmp_aligned_data with the associated protection code
// if RAS is not used then is just a buffer for tmp_aligned_data 
wire [DW+DATA_PROT_WD-1:0] prot_tmp_aligned_data;

parameter N_CYCLE_DELAY     = `CX_RDLH_REGIN;

parameter CTRL_DATAPATH_WIDTH    = (3*NW) + (2*NW) + 1;

  localparam RAS_ALL_0S_PROT_CODE = `CX_RAS_ALL_0S_PROT_CODE; 
  localparam [DATA_PROT_WD-1:0] ALL_0S_PROT_CODE = RAS_ALL_0S_PROT_CODE[DATA_PROT_WD-1:0];
  wire ras_rdlh_prot_disable;
  reg pipe_rdlh_pkt_dv_1d;
  wire pipe_pkt_data_d_err_multpl;
  wire pipe_pkt_data_d_err_detect;


wire              ras_stat_rdlh_tlp_extract_corr;  //error flags for the RAS statistics counters
wire              ras_stat_rdlh_tlp_extract_uncorr;  //error flags for the RAS statistics counters

assign ras_stat_rdlh_tlp_extract_corr =   { pipe_pkt_data_d_err_detect && pipe_rdlh_pkt_dv_1d};
assign ras_stat_rdlh_tlp_extract_uncorr = { pipe_pkt_data_d_err_multpl && pipe_rdlh_pkt_dv_1d};

  always @(posedge core_clk or negedge core_rst_n) 
  begin: pipe_rdlh_pkt_dv_1d_PROC
    if (!core_rst_n)
      pipe_rdlh_pkt_dv_1d <= #TP 1'b0;
    else
      pipe_rdlh_pkt_dv_1d <= #TP pipe_rdlh_pkt_dv;
  end

//Error Injection Done
wire ras_err_inj_done;
wire ras_err_inj_done_rdlh_pkt_data;
wire ras_err_inj_done_extract_dataout_gen;
assign ras_err_inj_done = ras_err_inj_done_rdlh_pkt_data
                          || ras_err_inj_done_extract_dataout_gen
                          ;



// Signals after input masking
wire   [NW-1:0]       int_rplh_rdlh_tlp_start;
wire   [NW-1:0]       int_rplh_rdlh_pkt_end;
wire   [NW-1:0]       int_rplh_rdlh_pkt_edb;

// Signals before output masking
wire   [NW-1:0]       int_tlp_aligned_sot;
wire   [NW-1:0]       int_tlp_aligned_eot;
wire [RX_TLP_NFM-1:0] int_tlp_aligned_abort_vec;

assign int_rplh_rdlh_tlp_start   = rplh_rdlh_tlp_start;
assign int_rplh_rdlh_pkt_end     = rplh_rdlh_pkt_end  ;
assign int_rplh_rdlh_pkt_edb     = rplh_rdlh_pkt_edb  ;

assign int_tlp_aligned_sot       = tlp_aligned_sot      ;
assign int_tlp_aligned_eot       = tlp_aligned_eot      ;
assign int_tlp_aligned_abort_vec = tlp_aligned_abort_vec;


// CTRL Path
delay_n
 #(.N(N_CYCLE_DELAY), .WD(CTRL_DATAPATH_WIDTH)) u_delay (
    .clk        (core_clk),
    .rst_n      (core_rst_n),
    .clear      (1'b0),
    .din        ({rplh_rdlh_pkt_dv, int_rplh_rdlh_tlp_start, int_rplh_rdlh_pkt_end, int_rplh_rdlh_pkt_edb, rplh_rdlh_pkt_err, rplh_rdlh_nak}),

    .dout       ({pipe_rdlh_pkt_dv, pipe_rdlh_tlp_start, pipe_rdlh_pkt_end, pipe_rdlh_pkt_edb, pipe_rdlh_pkterr, pipe_rdlh_nak})
);

delay_n_w_enable
 #(.N(N_CYCLE_DELAY), .WD(DW)) u_delay_w_enable (
    .clk        (core_clk),
    .rst_n      (core_rst_n),
    .clear      (1'b0),
    .en         (rplh_rdlh_pkt_dv),
    .din        (rplh_rdlh_pkt_data),

    .dout       (tmp_pipe_rdlh_pkt_data)
);

assign pipe_eot = (pipe_rdlh_pkt_end | pipe_rdlh_pkt_edb);

wire                  ptm_sot;
wire                  ptm_multi_cycle;
wire                  ptm_request;
wire                  ptm_response;
wire [RX_TLP_NFM-1:0] ptm_abort;

ptm_rx_msg_decode
 u_ptm_rx_msg_decode (
    // inputs
    .core_clk           (core_clk), 
    .core_rst_n         (core_rst_n),
    .tlp_sot            (rdlh_rtlh_tlp_sot),
    .tlp_data           (rdlh_rtlh_tlp_data[DW-1:0]),
    .tlp_dv             (rdlh_rtlh_tlp_dv),
    .tlp_eot            (rdlh_rtlh_tlp_eot),
    .tlp_error          (ptm_abort),
    .tlp_halt           (1'b0),
    // outputs
    .ptm_sot            (ptm_sot),
    .ptm_multi_cycle    (ptm_multi_cycle),
    .ptm_request        (ptm_request),
    .ptm_response       (ptm_response)
);
assign    rdlh_ptm_sot         = ptm_sot;
assign    rdlh_ptm_multi_cycle = ptm_multi_cycle;
assign    rdlh_ptm_request     = ptm_request;
assign    rdlh_ptm_response    = ptm_response;


// =============================================================================
// Beneath are the design for crc calculation
//
// Delay and shift the incoming data to pass to CRC block with sequence
// number not STP symbol
wire [DW-1:0]         data_to_crc_org;
wire [DW-1:0]         data_to_crc;
wire [NW-1:0]         sot_to_crc;
wire [NW-1:0]         eot_to_crc;
wire                  dv_to_crc;
wire [NW-1:0]         valid_start;
wire [RX_TLP_NFM-1:0] crc_match_vec, crc_match_inv_vec;
wire [RX_TLP_NFM-1:0] org_crc_match_vec, org_crc_match_inv_vec;

assign data_to_crc_org = pipe_rdlh_pkt_data[DW-1:0];
assign dv_to_crc   = pipe_rdlh_pkt_dv;

assign sot_to_crc = valid_start;
//--------------------------------
lcrc_einj
 #(.CRC_MODE(`CX_RDLH), .NW(NW)) u_lcrc_einj (
    // inputs
    .clk                          (core_clk),
    .rst_n                        (core_rst_n),
    .enable_in                    (dv_to_crc),
    .data_in                      (data_to_crc_org),
    .sot_in                       (sot_to_crc),
    .eot_in                       (eot_to_crc),
    .edb_in                       ({NW{1'b0}}),
    .cdm_ras_des_einj0_enable     (cdm_ras_des_einj0_enable),
    .cdm_ras_des_einj0_crc_type   (cdm_ras_des_einj0_crc_type),
    .cdm_ras_des_einj0_count      (cdm_ras_des_einj0_count),
    // outputs
    .data_out                     (data_to_crc),
    .lcrc_einj_evt                (rdlh_einj0_lcrc_evt)
);


// Generate the protection code for the data that is going to be passed to the LCRC module
  bus_protect_gen
   #(
    .PROT_TYPE            ( RAS_PROT_TYPE   ),
    .PROT_RANGE           ( RAS_PROT_RANGE  ),
    .PROT_WD              ( DATA_PROT_WD    ),
    .DATA_WD              ( DW              ),
    .PARITY_MODE          ( RAS_PARITY_MODE )
   ) u_pipe_rdlh_pkt_data_gen ( 
      .gen          ( 1'b1                                     ), 
      .datain       ( tmp_pipe_rdlh_pkt_data[DW-1:0]           ),
      .core_clk              (core_clk  ),
      .core_rst_n            (core_rst_n),
      .error_inj_mask        (ras_err_inj_mask[DATA_PROT_WD+DW-1:0]),
      .error_inj_en          (ras_err_inj_en_array[37]),
      .error_inj_data_valid  (pipe_rdlh_pkt_dv & (|valid_start)),
      .error_inj_eot         (|pipe_eot),
      .error_inj_done        (ras_err_inj_done_rdlh_pkt_data),  
      .chkout       ( pipe_rdlh_pkt_data[DW+DATA_PROT_WD-1:DW] ),
      .dataout      ( pipe_rdlh_pkt_data[DW-1:0]               ) 
    );


lcrc
 #(.NW(NW), .NOUT(RX_TLP_NFM), .CRC_MODE(`CX_RDLH), .OPTIMIZE_FOR_1SOT_1EOT(0), .CRC_LATENCY(`CX_CRC_LATENCY_RDLH)) u_lcrc (
    // inputs
    .clk                (core_clk), 
    .rst_n              (core_rst_n),
    .enable_in          (dv_to_crc),
    .data_in            (data_to_crc),
    .sot_in             (sot_to_crc),
    .eot_in             (eot_to_crc),
    .seqnum_in_0        (16'h0),
    .seqnum_in_1        (16'h0),
    // outputs
    .crc_out            (),
    .crc_out_valid      (),
    .crc_out_match      (org_crc_match_vec),
    .crc_out_match_inv  (org_crc_match_inv_vec)
);

assign crc_match_vec     = (tlp_aligned_short_mc)? org_crc_match_vec & {{RX_TLP_NFM-1{1'b1}}, 1'b0} :                     // the short TLP cannot be masked so make sure it is aborted
                           (tlp_aligned_short_sc)? {1'b0 ,org_crc_match_vec[RX_TLP_NFM-1:1] } : // shift out the first bit corresponding to the masked short TLP
                                                   org_crc_match_vec;

assign crc_match_inv_vec = (tlp_aligned_short_mc)? org_crc_match_inv_vec & {{RX_TLP_NFM-1{1'b1}}, 1'b0} :                     // the short TLP cannot be masked so make sure it is aborted
                           (tlp_aligned_short_sc)? {1'b0 ,org_crc_match_inv_vec[RX_TLP_NFM-1:1] } : // shift out the first bit corresponding to the masked short TLP
                                                   org_crc_match_inv_vec;

//--------------------------------


wire [NW-1:0] inval_start;
wire [NW-1:0] l_pkt_in_progress;
wire [NW-1:0] l_pkt_in_progress_m1;
reg [NW-1:0] ant_valid_start, ant_inval_start, ant_l_pkt_in_progress, ant_l_pkt_in_progress_m1, ant_eot_to_crc;
wire [NW-1:0] pipe_ant_valid_start, pipe_ant_inval_start, pipe_ant_l_pkt_in_progress, pipe_ant_l_pkt_in_progress_m1, pipe_ant_eot_to_crc;

// decode valid start/end
always @(*) begin : dec_valid_start_end
    integer i;
    reg [NW+2:0] i_pkt_end;
    reg [NW+2:0] i_pkt_err;
    // Extend tlp_end by 3 symbols. We need to look for an end in the current DW
    // + the three above it up to the end of the current data before deciding if
    // a start is valid or not.  Minimum size of TLP is 5DW. Therefore a start
    // is only valid when followed by at least 3DW which do not have an end.
    i_pkt_end = {3'b0, int_rplh_rdlh_pkt_end | int_rplh_rdlh_pkt_edb};
    i_pkt_err = {3'b0, rplh_rdlh_pkt_err};

    ant_valid_start[0] = int_rplh_rdlh_tlp_start[0] && i_pkt_end[0 +: 4] == 0 && i_pkt_err[0 +: 4] == 0 && !ant_packet_in_progress;
    ant_inval_start[0] = int_rplh_rdlh_tlp_start[0] && (i_pkt_end[0 +: 4] != 0 || i_pkt_err[0 +: 4] != 0) && !ant_packet_in_progress;
    ant_l_pkt_in_progress[0] = ant_valid_start[0] ? 1 : (int_rplh_rdlh_pkt_end[0] || int_rplh_rdlh_pkt_edb[0]) ? 0 : ant_packet_in_progress;
    for(i = 1; i< NW; i = i + 1) begin
        ant_valid_start[i] = int_rplh_rdlh_tlp_start[i] && i_pkt_end[i +: 4] == 0 && i_pkt_err[i +: 4] == 0 && !ant_l_pkt_in_progress[i-1];
        ant_inval_start[i] = int_rplh_rdlh_tlp_start[i] && (i_pkt_end[i +: 4] != 0 || i_pkt_err[i +: 4] != 0) && !ant_l_pkt_in_progress[i-1];
        ant_l_pkt_in_progress[i] = ant_valid_start[i] ? 1 : (int_rplh_rdlh_pkt_end[i] || int_rplh_rdlh_pkt_edb[i]) ? 0 : ant_l_pkt_in_progress[i-1];
    end

    // ant_l_pkt_in_progress_m1[i] indicates that a TLP was in progress in DW[i-1]
    ant_l_pkt_in_progress_m1 = {ant_l_pkt_in_progress[NW-2:0], ant_packet_in_progress};
    ant_eot_to_crc = ant_l_pkt_in_progress_m1 & (int_rplh_rdlh_pkt_end | int_rplh_rdlh_pkt_edb);
end

delay_n
 #(.N(1), .WD(5*NW)) u_delay_2 (
    .clk        (core_clk),
    .rst_n      (core_rst_n),
    .clear      (1'b0),
    .din        ({ant_valid_start, ant_inval_start, ant_l_pkt_in_progress, ant_l_pkt_in_progress_m1, ant_eot_to_crc}),
    .dout       ({pipe_ant_valid_start, pipe_ant_inval_start, pipe_ant_l_pkt_in_progress, pipe_ant_l_pkt_in_progress_m1, pipe_ant_eot_to_crc})
);

assign {valid_start, inval_start, l_pkt_in_progress, l_pkt_in_progress_m1, eot_to_crc} = {pipe_ant_valid_start, pipe_ant_inval_start, pipe_ant_l_pkt_in_progress, pipe_ant_l_pkt_in_progress_m1, pipe_ant_eot_to_crc};
//--------------------------------

wire   tlp_inval_start;
assign tlp_inval_start        = |inval_start;

reg [NW-1:0] invalid_end;
//--------------------------------

always @(posedge core_clk or negedge core_rst_n)
if (!core_rst_n)  begin
  pipe_pkt_data_d            <= #TP {                                      ALL_0S_PROT_CODE,
                                      {DW{1'b0}}};
        pipe_pkt_start_d           <= #TP 0;
        pipe_nack                  <= #TP 0;
end else begin
    if (pipe_rdlh_pkt_dv) begin
        pipe_pkt_data_d            <= #TP pipe_rdlh_pkt_data;
        pipe_pkt_start_d           <= #TP valid_start;
        pipe_nack                  <= #TP tlp_inval_start | (|pipe_rdlh_nak) | (|invalid_end);
    end else
        pipe_nack                  <= #TP |pipe_rdlh_nak;
end

// check the data from the pipe_pkt_data_d before using it
    wire [DATA_PROT_WD-1:0] chk_pipe_pkt_data_d_syndout_unc;
    bus_protect_chk
     #(
      .PROT_TYPE           ( RAS_PROT_TYPE       ), 
      .PROT_RANGE          ( RAS_PROT_RANGE      ),
      .PROT_WD             ( DATA_PROT_WD        ),
      .DATA_WD             ( DW                  ),
      .PROT_CORRECT_EN     ( RAS_PROT_CORRECT_EN ),
      .PARITY_MODE         ( RAS_PARITY_MODE     ) 
     ) u_pipe_pkt_data_d_chk    ( 
      .correct_n  ( ras_rdlh_prot_disable                 ),
      .chkin      ( pipe_pkt_data_d[DW+:DATA_PROT_WD]     ),
      .datain     ( pipe_pkt_data_d[DW-1:0]               ),

      .err_detect ( pipe_pkt_data_d_err_detect            ), 
      .err_multpl ( pipe_pkt_data_d_err_multpl            ),
      .dataout    ( chk_pipe_pkt_data_d[DW-1:0]           ),
      .chkout     ( chk_pipe_pkt_data_d[DW+:DATA_PROT_WD] ),
      .syndout    ( chk_pipe_pkt_data_d_syndout_unc       )
                                );

// one bit state to indicate that we are in a packet receiving
always @(posedge core_clk or negedge core_rst_n)
if (!core_rst_n)  begin
        packet_in_progress         <= #TP 0;
end else if (!rdlh_link_up)  begin
        packet_in_progress         <= #TP 0;
end else if (pipe_rdlh_pkt_dv) begin
        packet_in_progress         <= #TP l_pkt_in_progress[NW-1]; 
end
//--------------------------------

always @(posedge core_clk or negedge core_rst_n)
if (!core_rst_n)  begin
        ant_packet_in_progress         <= #TP 0;
end else if (!rdlh_link_up)  begin
        ant_packet_in_progress         <= #TP 0;
end else if (rplh_rdlh_pkt_dv) begin
        ant_packet_in_progress         <= #TP ant_l_pkt_in_progress[NW-1]; 
end

// When a start is detected in the last two DW of the last cycle an end
// detected in the first three DW this cycle is invalid and should be masked.
always @(*) begin : check_valid_end
     integer i;
     reg [4:0] aligned_starts;
    aligned_starts = {2'b0, pipe_pkt_start_d[NW-1 -: 2], 1'b0};
    invalid_end = 0;
    for(i = 0; i < 3; i = i + 1) begin
        invalid_end[i] = pipe_eot[i] & |aligned_starts[i +: 3];
    end
end

// Short single cycle TLPs are completely masked (i.e.tmp_aligned_eot and tmp_aligned_sot). 
// Although, the lcrc is still calculating their CRC. Keep track of the masked TLP to fix lcrc outputs 
assign tmp_aligned_short_sc = |invalid_end;

// Short multi cycle TLPs cannot be masked because the sot is already out. Make sure they are aborted.
assign tmp_aligned_short_mc = pipe_eot[0] & pipe_pkt_start_d[NW-3];

assign tmp_aligned_eot    = l_pkt_in_progress_m1 & pipe_eot & ~invalid_end;
assign tmp_aligned_badeot = l_pkt_in_progress_m1 & pipe_eot & pipe_rdlh_pkt_edb & ~invalid_end;

reg tmp_aligned_eot_is_first; // when sot and eot are both present tell which one comes first
//parameter EOT_NUM_WD = (NW==8) ? 2 : 3; // 2 bits to count up to 2 in 256b, 3 bits to count up to 4 in 512b
parameter EOT_NUM_WD = 3; // 3 bits to count up to 4 in 512b
reg [EOT_NUM_WD-1:0] tmp_aligned_sot_num, tmp_aligned_eot_num, tlp_aligned_eot_num_d; // count how many sots and eots, 3 bits to count up to 4 in 512b
wire [EOT_NUM_WD-1:0] tlp_aligned_eot_num; // count how many sots and eots, 3 bits to count up to 4 in 512b
reg got_eot;
integer lower_eot;
integer upper_eot;
integer upper_sot;
reg start_after_end;
reg got_sot;

always @(*) begin : count_sots_eots
    integer i;
    tmp_aligned_sot_num = 0;
    tmp_aligned_eot_num = 0;
    got_eot = 0;
    lower_eot = 0;
    upper_eot = 0;
    start_after_end = 1'b0;
    upper_sot = 0;
    got_sot = 0;
    for(i = 0; i < NW; i = i + 1) begin
        if(tmp_aligned_eot[i]) begin// detect more than 1 TLP end in a cycle
            if(tmp_aligned_eot_num==0) begin
                lower_eot = i;
                got_eot = 1'b1;
            end else begin
                upper_eot = i;
            end
            tmp_aligned_eot_num = tmp_aligned_eot_num + 1;
        end
        if(tmp_aligned_sot[i]) begin
            if(!got_sot) begin
                got_sot = 1;
                if(i > lower_eot && got_eot) begin
                    start_after_end = 1'b1;
                end
            end else begin
                upper_sot = i;
            end
            tmp_aligned_sot_num = tmp_aligned_sot_num + 1;
        end
    end
end

assign one_ends = tmp_aligned_eot_num >= 1;
assign one_sots = tmp_aligned_sot_num >= 1;
assign two_ends = tmp_aligned_eot_num >= 2;
assign two_sots = tmp_aligned_sot_num >= 2;


assign three_ends = tmp_aligned_eot_num >= 3;
assign four_ends  = tmp_aligned_eot_num >= 4;
assign three_sots = tmp_aligned_sot_num >= 3;
assign four_sots  = tmp_aligned_sot_num >= 4;


// Get the two highest ordered starts from the previous cycle and compare with
// the ends from this cycle to validate them.
wire [1:0] tmp_start_d;
assign tmp_start_d = { pipe_pkt_start_d[NW-1], pipe_pkt_start_d[NW-2] };

// end LSB is 0 because start_d[DW-2] has already been compared with
// end_d[DW-1] before it was latched
wire [3:0] tmp_end_d;
assign tmp_end_d = { pipe_eot[2:0], 1'b0};

reg [1:0] valid_start_d;
always @(*) begin : delayed_valid_start
    integer i;
    for(i = 0; i < 2; i = i + 1) begin
        valid_start_d[i] = tmp_start_d[i] && !(|tmp_end_d[i +: 3]);
    end
end

// Gather the validated starts and use them to generate aligned(ie. << 2) sot.
assign tmp_aligned_sot = {valid_start[NW-3 : 0], valid_start_d};

assign tmp_aligned_data = { pipe_rdlh_pkt_data[DW-1 -SHIFT_SIZE:0], chk_pipe_pkt_data_d[DW-1 -: SHIFT_SIZE]};

assign tmp_aligned_dv   = (|tmp_aligned_sot || packet_in_progress) && pipe_rdlh_pkt_dv;

// Check pkterr with eot and the start from the current DW and the three below
wire [NW+2:0] tmp_aligned_start;
assign tmp_aligned_start = {pipe_rdlh_tlp_start, 3'b0};
reg [NW-1:0] tmp_aligned_pkterr;
always @(*) begin : align_pkterr
    integer i;
    for(i = 0; i < NW; i = i + 1) begin
        tmp_aligned_pkterr[i] = pipe_rdlh_pkterr[i] && pipe_eot[i] && l_pkt_in_progress_m1[i] && !(|tmp_aligned_start[i +: 4]);
    end
end

// Pull RX_TLPs sequence numbers out of the data stream.
// 1 sequence number can be handled. The location of the sequence number is
// indicated by tmp_aligned_sot, seqnum_extract_data is shifted to align the
// sequence number 
parameter SEQNUM_SHIFT = 56;
wire [DW-1:0] seqnum_extract_data;
assign seqnum_extract_data = { pipe_rdlh_pkt_data[DW-1-SEQNUM_SHIFT:0], chk_pipe_pkt_data_d[DW-1 -: SEQNUM_SHIFT]};

// In a 256 or 512-bit core we must handle two or four sequence numbers
always @(*) begin : get_rx_tlp_seqnum
    integer i;
    reg [RX_TLP_LOG2-1:0] j;
    seqnum_vec = {RX_TLP_NFM{tlp_seqnum}};
    j = 0;
    for(i = 0; i < NW; i = i + 1) begin
        if(tmp_aligned_sot[i]) begin
            seqnum_vec[12*j +: 12] = {seqnum_extract_data[i*32 +: 4], seqnum_extract_data[i*32+8 +: 8]};
            if( j < RX_TLP_NFM - 1 ) 
                j = j + 1 ;
        end
    end
end

// In a phase2 256 or 512-bit core either or both TLPs may have layer1 errors
reg [RX_TLP_NFM-1:0] tmp_aligned_pkterr_vec;
wire [RX_TLP_NFM-1:0] tlp_aligned_pkterr_vec;

// iterate over tmp_aligned_eot and pull out seperate pkterr indications
// for RX_TLP_NFM TLPs
always @(*) begin : get_rx_tlp_align_pkterr
    integer i;
    reg [RX_TLP_LOG2-1:0] j;
    tmp_aligned_pkterr_vec = 0;
    j = 0;
    for(i = 0; i < NW; i = i + 1) begin
        if(tmp_aligned_eot[i] && tmp_aligned_dv) begin
            tmp_aligned_pkterr_vec[j] = tmp_aligned_pkterr[i];
            if( j < RX_TLP_NFM - 1 ) 
                j = j + 1 ;
        end
    end
end

delay_n
 //delay: 1 clk delays standard mode,2 clk delays crc pipeline mode
#(.N(CRC_LATENCY), .WD(RX_TLP_NFM)) u_crc_rdlh_delay256 (
    .clk        (core_clk),
    .rst_n      (core_rst_n),
    .clear      (!rdlh_link_up),
    .din        (tmp_aligned_pkterr_vec),
    .dout       (tlp_aligned_pkterr_vec)
);

// ================= END of LCRC strip logic for 256 and 512-bit ARCH ==========================



// A 256 or 512-bit core has the possibility of receiving the start and end of TLP in
// a single cycle. We must detect this and extract the sequence number directly
// from the data stream in this case
// Need to not take the seqnum straight from the data stream when the end
// occurs before the start
// use tmp_aligned_sot < tmp_aligned_eot to detect when an sot occurs before an
// eot in the same cycle

reg [RX_TLP_NFM-1:0] tmp_aligned_badeot_vec;
wire [RX_TLP_NFM-1:0] tlp_aligned_badeot_vec;

// Pull RX_TLPs badeot indications out of tmp_aligned_eot[NW-1:0]. tmp_aligned_eot is
// always set on badeot. tmp_aligned_badeot contains the per NW badeot info. 
// badeot_vec[0] corresponds to the first eot(which may or may not be bad)
// badeot_vec[1] corresponds to the second eot(which may or may not be bad,
// independently)
always @(*) begin : get_rx_tlp_align_badeot
    integer i;
    reg [RX_TLP_LOG2-1:0] j;
    tmp_aligned_badeot_vec = 0;
    j = 0;
    for(i = 0; i < NW; i = i + 1) begin
        if(tmp_aligned_eot[i] && tmp_aligned_dv) begin
            tmp_aligned_badeot_vec[j] = tmp_aligned_badeot[i];
            if( j < RX_TLP_NFM - 1 ) 
                j = j + 1 ;
        end
    end
end

delay_n
 //delay: 1 clk delays standard mode,2 clk delays crc pipeline mode
#(.N(CRC_LATENCY), .WD(RX_TLP_NFM)) u_crc_rdlh_delay2 (
    .clk        (core_clk),
    .rst_n      (core_rst_n),
    .clear      (!rdlh_link_up),
    .din        (tmp_aligned_badeot_vec),
    .dout       (tlp_aligned_badeot_vec)
);


always @(posedge core_clk or negedge core_rst_n) begin : latch_seqnum_on_sot
    if (!core_rst_n)  begin
        tlp_seqnum                <= #TP 0;
    end else if(!rdlh_link_up) begin
        tlp_seqnum                <= #TP 0;
    end else begin
        // When there are multiple sots active grab the uppermost seqnum. The lower
        // must belong to a single cycle TLP and will be loaded into
        // tlp_extracted_seqnum directly from teh datapath.
        tlp_seqnum                <= #TP (|tmp_aligned_sot && tmp_aligned_dv) ? (
                                                                                 four_sots ? seqnum_vec[12*3 +: 12] : 
                                                                                 three_sots ? seqnum_vec[12*2 +: 12] : 
                                                                                 two_sots ? seqnum_vec[12*1 +: 12] : seqnum_vec[12*0 +: 12]
                                                                                 ) : tlp_seqnum;
    end
end
//--------------------------------

wire sot_is_first = !start_after_end; // for readability
//assign one_sots = |tmp_aligned_sot; // for readability
//assign one_ends = |tmp_aligned_eot; // for readability
wire [12*RX_TLP_NFM-1:0] tlp_extracted_seqnum_vec;
reg [12*RX_TLP_NFM-1:0] tlp_extracted_seqnum_vec_pre;
always @(posedge core_clk or negedge core_rst_n) begin : latch_seqnum_on_eot
    if (!core_rst_n) begin
        tlp_extracted_seqnum_vec_pre     <= #TP 0;
    end else if (!rdlh_link_up) begin
        tlp_extracted_seqnum_vec_pre     <= #TP 0;
    // Take sequence number straight from data stream if we have a single
    // cycle TLP, otherwise use value latched in tlp_seqnum. We only ever
    // update on eot, there are several scenarios
    end else if(|tmp_aligned_eot) begin
        tlp_extracted_seqnum_vec_pre[12*0 +: 12] <= #TP  sot_is_first &&   one_sots  && one_ends   ? seqnum_vec[12*0 +: 12] :  // if a TLP started and ended in this cycle, use first seq num from datapath, 
                                                                                                     tlp_seqnum;               // else use the latched seq num
        tlp_extracted_seqnum_vec_pre[12*1 +: 12] <= #TP  sot_is_first &&   two_sots  && two_ends   ? seqnum_vec[12*1 +: 12] :  // if two TLPs started and ended in this cycle, use the second seq num from datapath
                                                        !sot_is_first &&   one_sots  && two_ends   ? seqnum_vec[12*0 +: 12] :  // else if a TLP did not start but ended in this cycle and another TLP started and ended, use the first sequence number from the datapath,
                                                                                                     0;                        // else no second end, there is no seq num for this register
        tlp_extracted_seqnum_vec_pre[12*2 +: 12] <= #TP  sot_is_first &&  three_sots && three_ends ? seqnum_vec[12*2 +: 12] :
                                                        !sot_is_first &&    two_sots && three_ends ? seqnum_vec[12*1 +: 12] :
                                                                                                     0;       
        tlp_extracted_seqnum_vec_pre[12*3 +: 12] <= #TP !sot_is_first && three_sots  && four_ends  ? seqnum_vec[12*2 +: 12] :
                                                                                                     0;       
    end
end
//--------------------------------

delay_n
 //delay: 0 clk delays standard mode,1 clk delays crc pipeline mode
#(.N(CRC_LATENCY_M1), .WD(12*RX_TLP_NFM)) u_crc_rdlh_delay3 (
    .clk        (core_clk),
    .rst_n      (core_rst_n),
    .clear      (1'b0),
    .din        (tlp_extracted_seqnum_vec_pre),
    .dout       (tlp_extracted_seqnum_vec)
);
//--------------------------------

 /////////////////////////////////////////


// --------------- Error extraction -----------------------
// when PHY not reporting error and it is eot cycle:
// There are 4 sources of errors considered as bad tlp error
// 1. when CRC is not match and is not a nullified tlp
// 2. When CRC is inverted and it is not a nullified TLP
// 3. When crc is not inverted and badeot is asserted
// 4. When tlp sequence error

// Pull RX_TLPs eot indications out of tlp_aligned_eot[NW-1:0]
reg [RX_TLP_NFM-1:0] tlp_aligned_eot_vec; //  bit "i" set means i+1 eots are present
always @(*) begin : get_rx_tlp_aligned_eot
    integer i;
    reg [RX_TLP_LOG2-1:0] j;
    tlp_aligned_eot_vec = 0;
    j = 0;
    for(i = 0; i < NW; i = i + 1) begin
        if(tlp_aligned_eot[i]) begin
            tlp_aligned_eot_vec[j] = 1'b1;
            if( j < RX_TLP_NFM - 1 ) 
                j = j + 1 ;
        end
    end
end

// www: verify that tlp_aligned_eot and lcrc_aligned_eot can be merged
reg [RX_TLP_NFM-1:0] lcrc_aligned_eot_vec; //  bit "i" set means i+1 eots are present
always @(*) begin : get_rx_lcrc_aligned_eot
    integer i;
    reg [RX_TLP_LOG2-1:0] j;
    lcrc_aligned_eot_vec = 0;
    j = 0;
    for(i = 0; i < NW; i = i + 1) begin
        if(lcrc_aligned_eot[i]) begin
            lcrc_aligned_eot_vec[j] = 1'b1;
            if( j < RX_TLP_NFM - 1 ) 
                j = j + 1 ;
        end
    end
end

assign or_aligned_eot = tlp_aligned_eot_vec[0];

wire [RX_TLP_NFM-1:0] tlp_abort_vec;
wire [RX_TLP_NFM-1:0] sequence_not_eq_vec;
wire [RX_TLP_NFM-1:0] duplicate_seq_vec;
wire [RX_TLP_NFM-1:0] int_crc_err_vec;
wire [RX_TLP_NFM-1:0] sequence_err_vec;
wire [RX_TLP_NFM-1:0] nullified_tlp_vec;
wire [RX_TLP_NFM-1:0] duplicate_tlp_vec;

reg [12*RX_TLP_NFM-1:0] tlp_expected_seqnum_vec;
always @(*) begin : gen_rx_tlp_expected_seqnum_vec
    integer i;
    for(i = 0; i < RX_TLP_NFM; i = i + 1) begin
    // spyglass disable_block W164a
    // SMD: Identifies assignments in which the LHS width is less than the RHS width
    // SJ: The rule reports assignments where the result of an addition or subtraction operation is being assigned to a bus of the same width as the operands of the addition or subtraction operation. In this code, the carry or borrow bit is considered and isn't lost. So, disable SpyGlass from reporting this warning.
        tlp_expected_seqnum_vec[12*i +: 12] = tlp_expected_seqnum + i;
    // spyglass enable_block W164a    
    end
end

assign sequence_not_eq_vec[0]    =                     tlp_extracted_seqnum_vec[12*0 +: 12] != tlp_expected_seqnum_vec[12*0 +: 12];
assign sequence_not_eq_vec[1]    = tlp_abort_vec[0] ? (tlp_extracted_seqnum_vec[12*1 +: 12] != tlp_expected_seqnum_vec[12*0 +: 12]) : 
                                                      (tlp_extracted_seqnum_vec[12*1 +: 12] != tlp_expected_seqnum_vec[12*1 +: 12]);

assign duplicate_seq_vec[0]      = (tlp_expected_seqnum_vec[12*0 +: 12] - tlp_extracted_seqnum_vec[12*0 +: 12] <= 12'h800) && sequence_not_eq_vec[0];
assign duplicate_seq_vec[1]      = (tlp_expected_seqnum_vec[12*1 +: 12] - tlp_extracted_seqnum_vec[12*1 +: 12] <= 12'h800) && sequence_not_eq_vec[1];

assign sequence_not_eq_vec[2]    = (tlp_abort_vec[0] && tlp_abort_vec[1]) ? (tlp_extracted_seqnum_vec[12*2 +: 12] != tlp_expected_seqnum_vec[12*0 +: 12]) : 
                                   (tlp_abort_vec[0] || tlp_abort_vec[1]) ? (tlp_extracted_seqnum_vec[12*2 +: 12] != tlp_expected_seqnum_vec[12*1 +: 12]) :
                                                                            (tlp_extracted_seqnum_vec[12*2 +: 12] != tlp_expected_seqnum_vec[12*2 +: 12]);
assign sequence_not_eq_vec[3]    =   (tlp_abort_vec[0] && tlp_abort_vec[1] && tlp_abort_vec[2]) ? (tlp_extracted_seqnum_vec[12*3 +: 12] != tlp_expected_seqnum_vec[12*0 +: 12]) : // abort on 3 out of 3 previous pkts 
                                     ((tlp_abort_vec[0] && tlp_abort_vec[1]) || 
                                       (tlp_abort_vec[0] && tlp_abort_vec[2]) || 
                                        (tlp_abort_vec[1] && tlp_abort_vec[2]))                 ? (tlp_extracted_seqnum_vec[12*3 +: 12] != tlp_expected_seqnum_vec[12*1 +: 12]) : // abort on 2 out of 3 previous pkts
                                     (tlp_abort_vec[0] || tlp_abort_vec[1] || tlp_abort_vec[2]) ? (tlp_extracted_seqnum_vec[12*3 +: 12] != tlp_expected_seqnum_vec[12*2 +: 12]) : // abort on 1 out of 3 previous pkts
                                                                                                  (tlp_extracted_seqnum_vec[12*3 +: 12] != tlp_expected_seqnum_vec[12*3 +: 12]) ; // abort on 0 out of 3 previous pkts
assign duplicate_seq_vec[2]      = (tlp_expected_seqnum_vec[12*2 +: 12] - tlp_extracted_seqnum_vec[12*2 +: 12] <= 12'h800) && sequence_not_eq_vec[2];
assign duplicate_seq_vec[3]      = (tlp_expected_seqnum_vec[12*3 +: 12] - tlp_extracted_seqnum_vec[12*3 +: 12] <= 12'h800) && sequence_not_eq_vec[3];

assign int_crc_err_vec           = (~crc_match_vec & ~crc_match_inv_vec) |          // bad crc
                                   (crc_match_inv_vec & ~tlp_aligned_badeot_vec) |  // inverted CRC not nullifed
                                   (tlp_aligned_badeot_vec & ~crc_match_inv_vec);   // badeot not inverted CRC
assign sequence_err_vec          = sequence_not_eq_vec & ~duplicate_seq_vec;
assign nullified_tlp_vec         = crc_match_inv_vec & tlp_aligned_badeot_vec;
assign tlp_abort_vec             = int_crc_err_vec | sequence_err_vec | tlp_aligned_pkterr_vec | duplicate_seq_vec | nullified_tlp_vec;

//mask duplicate if current or previous TLP in clk cycle has error
assign duplicate_tlp_vec[0] = duplicate_seq_vec[0] & ~int_crc_err_vec[0]    & ~tlp_aligned_pkterr_vec[0]    & ~nullified_tlp_vec[0];
assign duplicate_tlp_vec[1] = duplicate_seq_vec[1] & ~|int_crc_err_vec[1:0] & ~|tlp_aligned_pkterr_vec[1:0] & ~|nullified_tlp_vec[1:0];
assign duplicate_tlp_vec[2] = duplicate_seq_vec[2] & ~|int_crc_err_vec[2:0] & ~|tlp_aligned_pkterr_vec[2:0] & ~|nullified_tlp_vec[2:0];
assign duplicate_tlp_vec[3] = duplicate_seq_vec[3] & ~|int_crc_err_vec[3:0] & ~|tlp_aligned_pkterr_vec[3:0] & ~|nullified_tlp_vec[3:0];


// Count how many tlp aborts do we have for the given number of tlp ends
reg [EOT_NUM_WD-1:0] tlp_abort_num;
always @(*) begin : gen_tlp_abort_num
    integer i;
    reg [(1<<EOT_NUM_WD)-1:0] tlp_abort_int; // wide enough to match tlp_abort_num
    tlp_abort_int = 0;
    tlp_abort_int[RX_TLP_NFM-1:0] = tlp_abort_vec;
    tlp_abort_num = 0;
    if(tlp_aligned_eot_num>0) begin
        for(i=1; i<=RX_TLP_NFM; i=i+1) begin
            if(i<=tlp_aligned_eot_num) begin
                if( tlp_abort_int[i-1] )
                    tlp_abort_num = tlp_abort_num + 1'b1;
            end
        end
    end
end


wire [RX_TLP_NFM-1:0] ptm_tlp_abort_vec;
assign ptm_tlp_abort_vec         = int_crc_err_vec | sequence_err_vec | tlp_aligned_pkterr_vec | nullified_tlp_vec;

//wire   ptm_tlp_abort_0;
//wire   ptm_tlp_abort_1;

//assign ptm_tlp_abort_0 =
//    int_crc_err_0 || sequence_err_0 ||
//    tlp_aligned_pkterr_0 || 
//    nullified_tlp_0;

//assign ptm_tlp_abort_1 =
//    int_crc_err_1 || sequence_err_1 ||
//    tlp_aligned_pkterr_1 || 
//    nullified_tlp_1;

// Calculate how much tlp_expected_seqnum should be increased by. It is never
// incremented when tlp_abort_vec[0] is set. It may increment by 1 or two depending
// on the number of valid TLPs which complete in a cycle
reg [EOT_NUM_WD-1:0] tlp_expected_seqnum_inc;
always @(*) begin
    tlp_expected_seqnum_inc = 0;
    if(tlp_aligned_eot_num>0) begin
// spyglass disable_block W164a
// SMD: Identifies assignments in which the LHS width is less than the RHS width
// SJ: This logic is designed to be modulo. seqnum counters are intended to
// wrap without preseveration of carry/borrow
        tlp_expected_seqnum_inc = tlp_aligned_eot_num - tlp_abort_num;
// spyglass enable_block W164a
    end
end

// this process is used to store the expected sequence number based on last good tlp received.
always@(posedge core_clk or negedge core_rst_n)
    if (!core_rst_n)
        tlp_expected_seqnum         <= #TP 12'b0;
    else if (!rdlh_link_up)
        tlp_expected_seqnum         <= #TP 12'b0;
    else 
// spyglass disable_block W164a
// SMD: Identifies assignments in which the LHS width is less than the RHS width
// SJ: This logic is designed to be modulo. seqnum counters are intended to
// wrap without preseveration of carry/borrow
      tlp_expected_seqnum           <= #TP tlp_expected_seqnum + tlp_expected_seqnum_inc;
// spyglass enable_block W164a



// For ack or nack notification to xdlh
// based on the current tlp received, we need to decide whether to ack or
// nack this tlp. A flag is set to issue notification
wire [RX_TLP_NFM-1:0] good_tlps   = tlp_aligned_eot_vec & ~tlp_abort_vec;
wire [RX_TLP_NFM-1:0] bad_tlps    = (tlp_aligned_pkterr_vec | int_crc_err_vec |(sequence_err_vec & ~tlp_aligned_badeot_vec)) & lcrc_aligned_eot_vec;
wire [RX_TLP_NFM-1:0] dup_tlps   = tlp_aligned_eot_vec & duplicate_tlp_vec;

wire nak_scheduled_or_going_to_be_scheduled  = nak_scheduled || rdlh_req2send_nack;
reg  clear_nak_scheduled_on_the_fly;
reg  good_tlp_found;
// In case a bad TLP is received after a good TLP and NAK_SCHEDULED flag is set, we need to treat the bad TLP
// as the NAK_SCHEDULED was clear (it would be cleared "on the fly").
always_comb begin : clear_nak_flag_PROC
    integer i;
    good_tlp_found = 1'b0;
    clear_nak_scheduled_on_the_fly = 1'b0;
    for(i=0; i < RX_TLP_NFM; i++)begin
        if(good_tlps[i])begin
            good_tlp_found = 1'b1;
        end
        if(good_tlp_found && bad_tlps[i])begin
            clear_nak_scheduled_on_the_fly = 1'b1;
        end
    end
end : clear_nak_flag_PROC

// NAK is requested if at least a bad TLP has been received for which the NAK_SCHEDULED flag is clear (or gets cleared "on the fly")
wire nak_flag = (bad_tlps != '0) && (!nak_scheduled_or_going_to_be_scheduled || rdlh_req2send_ack || clear_nak_scheduled_on_the_fly);

// ACK is requested if no NAK is requested and at least one good TLP has been received. Note that ack_flag can go high together
// with dup_flag. This situation means that the last TLP is a duplicate, but the NAK_SCHEDULED flag must be cleared anyway.
wire ack_flag = (good_tlps != '0) && !nak_flag;

// An ACK for duplicate is requested if no NAK is requested and there is a duplicate TLP that is more recent than a good TLP.
wire dup_flag = (dup_tlps > good_tlps) && !nak_flag;



// ------------------- Output Drives ------------------------------
wire [RX_TLP_NFM-1:0] rdlh_bad_tlp_err_vec;

assign rdlh_bad_tlp_err_vec = (tlp_aligned_eot_vec & (int_crc_err_vec | (sequence_err_vec & ~nullified_tlp_vec  & ~{RX_TLP_NFM{rdlh_req2send_nack}} & ~{RX_TLP_NFM{(~rdlh_req2send_ack & nak_scheduled )}})) & ~tlp_aligned_pkterr_vec);

// outputs drive process for passing good tlp to tlp layer
always@(posedge core_clk or negedge core_rst_n)
    if (!core_rst_n)  begin
        rdlh_bad_tlp_err            <= #TP 0;
    end else begin
        // PHY errors are not reported here, when two TLPs end report errors in either TLP
        rdlh_bad_tlp_err            <= #TP    |rdlh_bad_tlp_err_vec;
    end




// According to spec, we will need to ack on duplicates then drop them
// NOTE: Since we don't abort these duplicates until the end, the consumer
// must have overflow protection, as flow control has been compromised

//// Iterate over the eots and align the abort with the corresponding EOT
always @(*) begin : get_rx_tlp_align_abort
    integer i;
    reg [RX_TLP_LOG2-1:0] j;
    tlp_aligned_abort_vec = 0;
    j = 0;
    for(i = 0; i < NW; i = i + 1) begin
        if(tlp_aligned_eot[i]) begin
            tlp_aligned_abort_vec[j] = tlp_abort_vec[j];
            if( j < RX_TLP_NFM - 1 ) 
                j = j + 1 ;
        end
    end
end

reg [RX_TLP_NFM-1:0] ptm_tmp_aligned_abort;

always @(*) begin : align_abort
    integer i;
    reg [RX_TLP_LOG2-1:0] j;
    ptm_tmp_aligned_abort = 0;
    j = 0;
    for(i = 0; i < NW; i = i + 1) begin
        if(tlp_aligned_eot[i]) begin
            ptm_tmp_aligned_abort[j] = ptm_tlp_abort_vec[j];
            if( j < RX_TLP_NFM - 1 ) 
                j = j + 1 ;
        end
    end
end

reg [RX_TLP_NFM-1:0] ptm_tlp_aligned_abort;
assign ptm_tlp_aligned_abort       = ptm_tmp_aligned_abort;

always@(posedge core_clk or negedge core_rst_n)
    if (!core_rst_n)  begin
        rdlh_req2send_ack           <= #TP 0;
        rdlh_req2send_ack_due2dup   <= #TP 0;
        rdlh_req2send_nack          <= #TP 0;
        rdlh_req_acknack_seqnum     <= #TP {12{1'b1}};
        rdlh_clear_nak_scheduled    <= #TP 1'b0;
`ifndef SYNTHESIS
`endif // SYNTHESIS
    end else begin
        rdlh_req2send_ack         <= #TP (ack_flag || dup_flag) && !pipe_nack;
        rdlh_req2send_ack_due2dup <= #TP dup_flag;
        rdlh_clear_nak_scheduled <= #TP ack_flag;
        rdlh_req2send_nack       <= #TP nak_flag || pipe_nack ;
`ifndef SYNTHESIS
`endif // SYNTHESIS

        // rdlh_req_acknack_seqnum is one behind tlp_expected_seqnum.  
        // When two valid TLPs are received it should be set to
        // tlp_expected_seqnum + 1 since tlp_expected_seqnum will be
        // incrementing by 2.
        // Otherwise just load it with tlp_expected_seqnum when a single valid
        // TLP is received
        if (tlp_expected_seqnum_inc == 4)
           rdlh_req_acknack_seqnum  <= #TP tlp_expected_seqnum + 3;
        else if (tlp_expected_seqnum_inc == 3)
           rdlh_req_acknack_seqnum  <= #TP tlp_expected_seqnum + 2;
        else 
        if (tlp_expected_seqnum_inc == 2)
           rdlh_req_acknack_seqnum  <= #TP tlp_expected_seqnum + 1;
        else if (tlp_expected_seqnum_inc == 1)
           rdlh_req_acknack_seqnum  <= #TP tlp_expected_seqnum; 
    end

// Event flags for Ras D.E.S event counter when ARC_256 is enabled.
always@(posedge core_clk or negedge core_rst_n)
    if (!core_rst_n)  begin
        rdlh_bad_tlp_err_pertlp        <= #TP 0;
        rdlh_lcrc_tlp_err_pertlp       <= #TP 0;
        rdlh_nulified_tlp_err_pertlp   <= #TP 0;
        rdlh_duplicate_tlp_err_pertlp  <= #TP 0;
    end else begin
        // Rx Bad TLP Event per TLP
        rdlh_bad_tlp_err_pertlp          <= #TP rdlh_bad_tlp_err_vec;
        // Rx LCRC Error TLP
        rdlh_lcrc_tlp_err_pertlp         <= #TP tlp_aligned_eot_vec & int_crc_err_vec & ~tlp_aligned_pkterr_vec ;
        // Rx Nullified TLP
        rdlh_nulified_tlp_err_pertlp     <= #TP nullified_tlp_vec;
        // Rx Duplicate TLP
        rdlh_duplicate_tlp_err_pertlp    <= #TP tlp_aligned_eot_vec & duplicate_tlp_vec;
    end



// Making rdlh_duplicate_tlp aligned with rdlh_ptm_response
  assign rdlh_duplicate_tlp = `CX_RDLH_TLP_EXTRACT_REGOUT ? rdlh_req2send_ack_due2dup // using the registered version of (dup_flag)/(dup_flag & or_aligned_eot) in case of CX_RDLH_TLP_EXTRACT_REGOUT is exist in rdlh_ptm_response drivers delay path 
                                                          : dup_flag;

// ================= Common Code ===============================================
// =============================================================================
// Output functions
// =============================================================================
//second delay to allow for pipelined crc
always @(posedge core_clk or negedge core_rst_n)
    if (!core_rst_n)  begin
        tlp_aligned_dv_d            <= #TP 0;
        tlp_aligned_data_d          <= #TP {                                             ALL_0S_PROT_CODE,
                                             {DW{1'b0}}
                                           };
        tlp_aligned_sot_d           <= #TP 0;
        tlp_aligned_eot_d           <= #TP 0;
        lcrc_aligned_eot_d          <= #TP 0;
    end else if (!rdlh_link_up)  begin
        tlp_aligned_dv_d            <= #TP 0;
        tlp_aligned_data_d          <= #TP {                                             ALL_0S_PROT_CODE,
                                             {DW{1'b0}}
                                           };
        tlp_aligned_sot_d           <= #TP 0;
        tlp_aligned_eot_d           <= #TP 0;
        lcrc_aligned_eot_d          <= #TP 0;
    end else begin
        // when tlp start on the 3DW, after stripping off the seqnum and
        // STP, we will align tlp data with start pkt in next clock cycle.
        // This is the reason that we do not have dv assert at the
        // pipe_rdlh_tlp_start[3] cycle
        tlp_aligned_dv_d            <= #TP tmp_aligned_dv;
        tlp_aligned_sot_d           <= #TP (tmp_aligned_sot & {NW{tmp_aligned_dv}}) ;

        tlp_aligned_eot_d           <= #TP (tmp_aligned_eot & {NW{tmp_aligned_dv}});
        lcrc_aligned_eot_d          <= #TP (eot_to_crc & {NW{tmp_aligned_dv}});
        if (tmp_aligned_dv)
           tlp_aligned_data_d       <= #TP prot_tmp_aligned_data;
    end

delay_n
 //delay: 0 clk delays standard mode,1 clk delays crc pipeline mode
#(.N(CRC_LATENCY_M1), .WD(1+NW+NW+NW)) u_crc_rdlh_delay5 (
    .clk        (core_clk),
    .rst_n      (core_rst_n),
    .clear      (1'b0),
    .din        ({tlp_aligned_dv_d, tlp_aligned_sot_d, tlp_aligned_eot_d, lcrc_aligned_eot_d}),
    .dout       ({tlp_aligned_dv, tlp_aligned_sot, tlp_aligned_eot, lcrc_aligned_eot})
);

delay_n_w_enable
 //delay: 0 clk delays standard mode,1 clk delays crc pipeline mode
#(.N(CRC_LATENCY_M1), .WD(DW+DATA_PROT_WD)) u_crc_rdlh_delay5_w_enable (
    .clk        (core_clk),
    .rst_n      (core_rst_n),
    .clear      (1'b0),
    .en         (tlp_aligned_dv_d),
    .din        (tlp_aligned_data_d),
    .dout       (tlp_aligned_data)
);

delay_n
 //delay: 1 clk delays standard mode,2 clk delays crc pipeline mode
#(.N(CRC_LATENCY), .WD(2)) u_crc_rdlh_delay_short_tlp (
    .clk        (core_clk),
    .rst_n      (core_rst_n),
    .clear      (!rdlh_link_up),
    .din        ({tmp_aligned_short_sc, tmp_aligned_short_mc}),
    .dout       ({tlp_aligned_short_sc, tlp_aligned_short_mc})
);

// register in same way the additional variables that are only relevant for 256b and 512b 
always @(posedge core_clk or negedge core_rst_n)
    if (!core_rst_n)  begin
        tlp_aligned_eot_num_d       <= #TP 0;
    end else if (!rdlh_link_up)  begin
        tlp_aligned_eot_num_d       <= #TP 0;
    end else begin
        tlp_aligned_eot_num_d       <= #TP (tmp_aligned_eot_num & {EOT_NUM_WD{tmp_aligned_dv}});
    end

delay_n
 
#(.N(CRC_LATENCY_M1), .WD(EOT_NUM_WD)) u_crc_rdlh_delay6 (
    .clk        (core_clk),
    .rst_n      (core_rst_n),
    .clear      (1'b0),
    .din        ({tlp_aligned_eot_num_d}),
    .dout       ({tlp_aligned_eot_num})
);
//--------------------------------


  bus_protect_gen
   #(
    .PROT_TYPE            ( RAS_PROT_TYPE   ),
    .PROT_RANGE           ( RAS_PROT_RANGE  ),
    .PROT_WD              ( DATA_PROT_WD    ),
    .DATA_WD              ( DW              ),
    .PARITY_MODE          ( RAS_PARITY_MODE )
   ) u_rdlh_tlp_extract_dataout_gen ( 
      .gen          ( 1'b1                                      ), 
      .datain       ( tmp_aligned_data[DW-1:0]                  ),
      .core_clk              (core_clk  ),
      .core_rst_n            (core_rst_n),
      .error_inj_mask        (ras_err_inj_mask[DATA_PROT_WD+DW-1:0]),
      .error_inj_en          (ras_err_inj_en_array[54]),
      .error_inj_data_valid  (tmp_aligned_dv),
      .error_inj_eot         (|tmp_aligned_eot),
      .error_inj_done        (ras_err_inj_done_extract_dataout_gen),  

      .chkout       ( prot_tmp_aligned_data[DW +: DATA_PROT_WD] ),
      .dataout      ( prot_tmp_aligned_data[DW-1:0]             ) 
    );


// optional delay to get complete output clocked
parameter OUTPUT_CTRL_DATAPATH_WIDTH    = (2*NW) + 1 + RX_TLP_NFM;
delay_n

#(.N(`CX_RDLH_TLP_EXTRACT_REGOUT), .WD(OUTPUT_CTRL_DATAPATH_WIDTH)) u1_delay (
    .clk        (core_clk),
    .rst_n      (core_rst_n),
    .clear      (1'b0),
    .din        ({int_tlp_aligned_sot, int_tlp_aligned_eot, tlp_aligned_dv, int_tlp_aligned_abort_vec}),
    .dout       ({rdlh_rtlh_tlp_sot, rdlh_rtlh_tlp_eot, rdlh_rtlh_tlp_dv, rdlh_rtlh_tlp_abort})
);

delay_n_w_enable

#(.N(`CX_RDLH_TLP_EXTRACT_REGOUT), .WD(DW + DATA_PROT_WD)) u1_delay_w_enable (
    .clk        (core_clk),
    .rst_n      (core_rst_n),
    .clear      (1'b0),
    .en         (tlp_aligned_dv),
    .din        (tlp_aligned_data),
    .dout       (rdlh_rtlh_tlp_data)
);

// optional delay to get complete output clocked
delay_n

#(.N(`CX_RDLH_TLP_EXTRACT_REGOUT), .WD(RX_TLP_NFM)) u_ptm_delay (
    .clk        (core_clk),
    .rst_n      (core_rst_n),
    .clear      (1'b0),
    .din        ({ptm_tlp_aligned_abort}),
    .dout       ({ptm_abort})
);
//--------------------------------

//--------------------------------
endmodule
//--------------------------------
