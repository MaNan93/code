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
// --- RCS information:
// ---   $DateTime: 2023/10/03 05:48:51 $
// ---   $Revision: #2 $
// ---   $Id: //dwh/pcie_iip/main/fairbanks/design/CXL/DWC_cxl_rx_tl_queue_fifo_interface.sv#2 $
// -------------------------------------------------------------------------
// --- Module Description:
// ----------------------------------------------------------------------------
//  CXL Reciever Transaction Layer core Module
//  Used to build the H2D, D2H, M2S and S2M use cases
//  It includes a queue mapper followed by a FIFO then an interface mapper.
//  All the three are parametrized to allow the use of the current module
//  at different sizes within the upper modules.
// ----------------------------------------------------------------------------

`include "include/DWC_pcie_ctl_all_defs.svh"
`include "CXL/pkg/DWC_cxl_pkg.svh"

`include "CXL/svif/DWC_cxl_clk_rst_if.svh"
`include "CXL/svif/DWC_cxl_ram2p_if.svh"

//  The parameters are
//  TP : (T)ime of (P)ropagation from clock to Q in flip flops. Simulation only.
//       `TP defined in DWC_pcie/DWC_pcie_ctl/src/DWC_pcie_aux_cc_constants.svh
//  DW : (D)ata (W)idth, number of bits for data
//  CHNLS : Number of input Channels, minimum is 1
//  WR_PTR_WD: WRite PoinTeR WiDth, number of bits for pointer
//  USAGE: Valid values now are 0 or 2.
//         A usage value of 2 bypasses the queue mapper completely and uses only
//         the FIFO and interface mappers.
//  CW : Application (C)redit (W)idth, number of bits for AL response credits
//  ICW: (I)nput (C)redit (W)idth, number of bits for input credits
//  OCW: (O)utput (C)redit (W)idth, number of bits for output credits
//  FIFO_DEPTH      : Depth of FIFO, to be divided according to actual CHNLS
//  FIFO_ADDR_WIDTH : Address width, to be adjusted according to actual CHNLS
//  FIFO_ERR_MODE   : Error mode for FIFO
//  FIFO_INTERFACE  : Number of FIFO ports (>= CHNLS)
//  AL_IFNUM : number of output channels going to Application layer.
//    Typical values are:
//      For CHNLS==1, AL_IFNUM=1 and this single channel may have 0 or 1 credits.
//      For CHNLS==2, AL_IFNUM=1 and this single channel may have 0, 1, or 2 credits.
//      For CHNLS==4, AL_IFNUM=2 and each channel may have 0, 1, or 2 credits.
//  ORD: Ordering between two channels
//       value is 1 if this channel goes first (H2D responses)
//       value is 2 if this channel is second and waits for first (H2D requests)
//       value is 0 if this channel is not related to ordering requirements
//  F_DW   : Data width for FIFO controller.
//           It should differ from DW only in case of ORD=2 where the PTR
//           of the "first" channel is prepended to the message of the "second"
//           channel.
//  I_DW   : Data width for interface mapper.
//           It should differ from DW only in case of ORD=2 where the PTR
//           of the "first" channel is prepended to the message of the "second"
//           channel.
module DWC_cxl_rx_tl_queue_fifo_interface
  import DWC_cxl_pkg::*;
#(
    parameter TP              = `TP
  , parameter USAGE           = 0
  , parameter CHNLS           = 4
  , parameter WR_PTR_WD       = 4
  , parameter CW              = WR_PTR_WD
  , parameter ICW             = 4
  , parameter OCW             = 4
  , parameter DW              = 32
  , parameter FIFO_DEPTH      = 16
  , parameter FIFO_ADDR_WIDTH = 4
  , parameter FIFO_ERR_MODE   = 2
  , parameter FIFO_INTERFACE  = CHNLS
  , parameter AL_IFNUM        = ((CHNLS-1)/2 + 1)
  , parameter ORD             = 0
  , parameter F_DW            = DW
  , parameter I_DW            = DW
) (
    DWC_cxl_clk_rst_if.slave_mp                    b_clk
  //  Inputs to queue mapper
  , input  logic                                   crc_err
  , input  logic [(CHNLS-1):0][(DW-1):0]           data_in
  //  Inputs to FIFO
  // fifo_push is useful for USAGE==2
  , input  logic [(FIFO_INTERFACE-1):0]            fifo_push
  //  Inputs to count the credits from AL
  , input  logic [(AL_IFNUM-1):0]                 AL_crd
  , input  logic                                  ch_msg_halt
  , input  logic                                  nullify_crd_cnt
  , input  logic                                  run_crd_cnt
  //  toggle_flag is synchronized with cxl_clk.
  //  At a positive edge of cxl_clk the value of toggle_flag is
  //  1 if a positive edge of core_clk precedes the positive edge of cxl_core
  //  and the value is
  //  0 if a negative edge of core_clk precedes the positive edge of cxl_core.
  , input  logic                                  toggle_flag

  //  To process ordering requirements, there are inputs from the mapper
  //  of the "first" channels coming to the "second" channels mapper
  , input  logic [(WR_PTR_WD-1):0]                fst_wrptr_count
  //  fst_chnl_pending means there are pending transactions queued to fifo of
  //  "first" channel having ordering dependency
  , input  logic                                  fst_chnl_pending
  //  The fst_chnl_rd_cnt is an input to the case of "second" channels and it comes
  //  from the rdptr_count output of the "first" channels mapper.
  //  It is stable for the period of s_core_clk and hold the count of
  //  messages already sent on all associated "first" channels. This allows
  //  the "second" channels mapper to handle ordering dependencies.
  , input  logic           [(ICW-1):0]            fst_chnl_rd_cnt

  //  The two read_aux signals are inputs for the case of "first" channels. They are
  //  the stored_aux outputs coming from the "second" channels mapper. They are auxiliary
  //  pointer and enable for the Host to Device (H2D) use case. The "second" mapper
  //  reads the top of the FIFO as the stored_aux_ptr and sets the enable when
  //  the channel can be sent to AL from ordering perspective. This allows the
  //  "first" mapper to check buffer overlfow.
  , input  logic           [(OCW-1):0]            read_aux_ptr
  , input  logic                                  read_aux_ptr_en

  //  Outputs in s_core_clk domain
  //  Outputs from queue mapper
  , output logic [(WR_PTR_WD-1):0]                 q_map_wrptr_cnt_vld
  //  Combined output from queue mapper and FIFO
  , output logic                                   q_fifo_pending
  //  Output from FIFO alone
  , output logic [(FIFO_INTERFACE-1):0]            fifo_pending
  //  Outputs from FIFO
  , output logic [($clog2(FIFO_INTERFACE)+1):0]    fifo_net_crd
  //  RAM interface for FIFO
  , DWC_cxl_ram2p_if.master_mp                     b_ram[(FIFO_INTERFACE-1):0]
  //  Outputs from interface mapper
  //  Interface with Link layer for communicating TL layer credit release
  , output logic [(CHNLS-1):0]                    cxl_rx_tl_valid
  , output logic           [(ICW-1):0]            stored_aux_ptr
  , output logic                                  stored_aux_ptr_ctrl_en
  //  Outputs in s_cxl_clk domain
  //  Data for AL
  , output logic [(AL_IFNUM-1):0][(DW-1):0]       r_map_data
  , output logic         [(OCW-1):0]              rdptr_count
  , output logic                                  ptr_err
);
  
  //============================================================================
  // Adjusting input channels and output valids for FIFO Interface
  //============================================================================
  // The number of input channels is extended to the number of FIFO interface ports
  // Number FIFO interface ports is greater than or equal the number of link layer channels
  logic [(FIFO_INTERFACE-1):0][(DW-1):0]   data_in_s;

  always_comb begin
    data_in_s  = 0;
    for (int i=0; i < CHNLS; i=i+1) begin
      data_in_s[i]  = data_in[i];
    end
  end
  
  //============================================================================
  //  First, go through the queue mapper
  //============================================================================
  //  Outputs from queue mapper
  logic                                           q_map_pending;
  logic [(FIFO_INTERFACE-1):0]                    q_map_fifo_push;
  logic [(FIFO_INTERFACE-1):0]        [(DW-1):0]  q_map_data_out;

  //  If (USAGE==0) then there is a queue mapper
  generate if(USAGE==0) begin : Usage_0
    DWC_cxl_rx_tl_queue_mapper
     #(
        .DW(DW)
      , .NC(FIFO_INTERFACE)
      , .WR_PTR_WD(WR_PTR_WD)
      ) U_DWC_cxl_rx_tl_queue_mapper_0u(
        .clk                     (b_clk.s_core_clk)
      , .rst_n                   (b_clk.s_core_rst_n)
      , .data_in                 (data_in_s)
      , .crc_err                 (crc_err)
      , .s_map_pending           (q_map_pending)
      , .s_map_data_push         (q_map_fifo_push)
      , .s_map_data              (q_map_data_out)
      , .s_wrptr_count_nd_valids (q_map_wrptr_cnt_vld)
      );
  end : Usage_0
  else begin  : Default_case
    // We get here if USAGE==2.
    // The case of USAGE>2 should not occur.
    // Here we just bypass the queue mapper.
    assign q_map_pending            = '0;
    assign q_map_fifo_push          = fifo_push;
    assign q_map_data_out           = data_in_s;
    assign q_map_wrptr_cnt_vld      = '0;
  end : Default_case
  endgenerate

  //============================================================================
  //  Second, go through the FIFO
  //============================================================================

  // Input to FIFO from queue mapper
  logic [(FIFO_INTERFACE-1):0][(F_DW-1):0]        fifo_data_in;

  // Output from interface mapper, equal to the following fifo_pop but starts at zero.
  logic [(FIFO_INTERFACE-1):0]                    t_code_ch_pop;
  // Input to FIFO from interface mapper
  logic [(FIFO_INTERFACE-1):0]                    fifo_pop;
  // Outputs from FIFO to interface mapper
  logic [(FIFO_INTERFACE-1):0]                    fifo_empty;
  logic [(FIFO_INTERFACE-1):0][(F_DW-1):0]        fifo_data_out;

  //  Variable for loops in generate statements
  genvar                              g_lp_idx;
  //  Preparing the data going to the FIFO.
  //  For a channel where ORD is not 2, the input going to the FIFO is simply
  //  a copy of the output from queue mapper.
  //  For the "second" channel with ORD=2, we prepend the wrptr coming from the
  //  "first" channel. The most significant bit is a parity bit for the 
  //  directly following bits which hold the bits of fst_wrptr_count.
  //  The data coming from the queue mapper feed the least significant bits.
  generate
    for (g_lp_idx=0; g_lp_idx<FIFO_INTERFACE; g_lp_idx=g_lp_idx+1) begin : fifo_data_in_proc
      if (ORD!=2) assign fifo_data_in[g_lp_idx] = q_map_data_out[g_lp_idx];
      else        assign fifo_data_in[g_lp_idx] = { ^fst_wrptr_count
                                                  , fst_wrptr_count
                                                  , q_map_data_out[g_lp_idx]
                                                  };
    end : fifo_data_in_proc
  endgenerate

  localparam  ACTUAL_FIFO_DEPTH       = int'($ceil(FIFO_DEPTH/FIFO_INTERFACE));
  localparam  ACTUAL_FIFO_ADDR_WIDTH  = ((FIFO_ADDR_WIDTH-$clog2(FIFO_INTERFACE)) > $clog2(ACTUAL_FIFO_DEPTH)) ?
                                          (FIFO_ADDR_WIDTH-$clog2(FIFO_INTERFACE)) : $clog2(ACTUAL_FIFO_DEPTH);
  //  FIFO control Stage -
  //  number of instances=FIFO_INTERFACE
  DWC_cxl_rx_tl_fifoctrl
     #(
      .DEPTH       (ACTUAL_FIFO_DEPTH)
    , .ADDR_WIDTH  (ACTUAL_FIFO_ADDR_WIDTH)
    , .DATA_SIZE   (F_DW)
    , .ERR_MODE    (FIFO_ERR_MODE)
    )U_DWC_cxl_rx_tl_fifoctrl[(FIFO_INTERFACE-1):0]   (
      .clk               (b_clk.s_core_clk)
    , .rst_n             (b_clk.s_core_rst_n)
    , .fifo_push_req_n   (~q_map_fifo_push)
    , .fifo_push_data_in (fifo_data_in)
    , .fifo_empty        (fifo_empty)
    , .fifo_pop_req_n    (~fifo_pop)
    , .fifo_data_out     (fifo_data_out)
    , .fifo_pending      (fifo_pending)
    , .b_ram             (b_ram)
   );

  //  OR together all the pending bits from FIFO and from queue mapper to get
  //  the overall pending indicator.
  assign q_fifo_pending = q_map_pending | (|fifo_pending) ;

  always_comb begin : fifo_net_crd_PROC
    //  Default value
    fifo_net_crd  = '0;
    for(int lp_idx=0; lp_idx<FIFO_INTERFACE; lp_idx=lp_idx+1) begin
      //  Use a size cast to avoid linting problems
      fifo_net_crd = ($clog2(FIFO_INTERFACE)+2)'(fifo_net_crd + q_map_fifo_push[lp_idx] - fifo_pop[lp_idx]);
    end
  end : fifo_net_crd_PROC


  //============================================================================
  //  Third, go through the interface mapper
  //============================================================================

  logic [(FIFO_INTERFACE-1):0][(I_DW-1):0] inf_data_in;
  logic [(AL_IFNUM-1):0][(I_DW-1):0]       inf_data_out;

  logic [(FIFO_INTERFACE-1):0]             fifo_data_out_ptr_err;

  generate
    for (g_lp_idx=0; g_lp_idx<FIFO_INTERFACE; g_lp_idx=g_lp_idx+1) begin : divide_fifo_data_out_proc
      //  For a channel where ORD is not 2, we simply set the ptr_err to '0.
      //  For the "second" channel with ORD=2, if the FIFO is empty then there
      //  is no error. If it is not empty we compare the most significant bit
      //  (parity bit) with the XOR of the bits which hold the wrptr_count.
      if (ORD!=2) assign fifo_data_out_ptr_err[g_lp_idx] = '0;
      else assign fifo_data_out_ptr_err[g_lp_idx] = (fifo_empty[g_lp_idx]) ? '0 :
        (fifo_data_out[g_lp_idx][F_DW-1] != ^fifo_data_out[g_lp_idx][(F_DW-2):DW]);

      //  For a channel where F_DW=I_DW=DW, the following assignment just copies
      //  the bits as is. Otherwise, the bits going to interface mapper
      //  come from the least siginificant bits without the parity bits.
      assign inf_data_in[g_lp_idx] = fifo_data_out[g_lp_idx][(I_DW-1):0];
    end : divide_fifo_data_out_proc
  endgenerate

  //  An error for any channel indicates an error
  assign ptr_err = (|fifo_data_out_ptr_err);

  //  Recieve mapper & Order management
  //  Valid data is identified by fifo being not empty
  DWC_cxl_rx_tl_interface_mapper
   #(
      .CW  (CW)
    , .ICW (ICW)
    , .OCW (OCW)
    , .DW  (I_DW)
    , .INP (FIFO_INTERFACE)
    , .OA  (AL_IFNUM)
    , .ORD (ORD)
    ) U_DWC_cxl_rx_tl_interface_mapper (
      .b_clk                   (b_clk)
    //  inputs in s_core_clk domain
    , .ch_data                 (inf_data_in)
    , .ch_valid                (~fifo_empty)
    , .fst_chnl_pending        (fst_chnl_pending)
    //  inputs in s_cxl_clk domain
    , .AL_crd                  (AL_crd)
    , .ch_msg_halt             (ch_msg_halt)
    , .nullify_crd_cnt         (nullify_crd_cnt)
    , .run_crd_cnt             (run_crd_cnt)
    , .toggle_flag             (toggle_flag)
    , .fst_chnl_rd_cnt         (fst_chnl_rd_cnt)
    , .read_aux_ptr            (read_aux_ptr)
    , .read_aux_ptr_en         (read_aux_ptr_en)
    //  outputs in s_core_clk domain
    , .t_code_ch_pop           (t_code_ch_pop)
    , .s_map_ch_pop            (fifo_pop)
    , .stored_aux_ptr          (stored_aux_ptr)
    , .stored_aux_ptr_ctrl_en  (stored_aux_ptr_ctrl_en)
    //  outputs in s_cxl_clk domain
    , .r_map_data              (inf_data_out)
    , .rdptr_count             (rdptr_count)
  );

  //  valid bits towards link layer for communicating TL layer credit release
  //  s_core_clk domain
  always_ff @(posedge b_clk.s_core_clk or negedge b_clk.s_core_rst_n) begin
    if (!b_clk.s_core_rst_n) begin
      cxl_rx_tl_valid <= # TP '0;
    end else begin
      cxl_rx_tl_valid <= # TP t_code_ch_pop[(CHNLS-1):0];
    end
  end

  generate
    for (g_lp_idx=0; g_lp_idx<AL_IFNUM; g_lp_idx=g_lp_idx+1) begin : extract_data_out_proc
      //  For a channel that is "second" according to ordering requirements,
      //  I_DW is larger than DW but only the least significant DW bits of
      //  interface mapper output bits are relevant to become the r_map_data.
      //  The upper PTR_SIZE bits will be effectively thrown away by the
      //  the following assignment.
      //  For a channel where I_DW=DW, the following assignment just copies
      //  the bits to the output.
      assign r_map_data[g_lp_idx]  = inf_data_out[g_lp_idx][(DW-1):0];
    end : extract_data_out_proc
  endgenerate

endmodule
