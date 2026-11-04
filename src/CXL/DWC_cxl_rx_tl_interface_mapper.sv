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
// ---   $Revision: #3 $
// ---   $Id: //dwh/pcie_iip/main/fairbanks/design/CXL/DWC_cxl_rx_tl_interface_mapper.sv#3 $
// ----------------------------------------------------------------------------
// --- Module Description:
// ----------------------------------------------------------------------------
//  This module transports the data coming into the receiver (RX) side of the
//  Transaction Layer (TL) to the Application Layer (AL).
//
//  The module combines two clock domains s_core_clk and s_cxl_clk.
//  In case of CX_CXL_SYNCHRONOUS s_core_clk and s_cxl_clk have the same
//  frequency. Otherwise, when not in CX_CXL_SYNCHRONOUS, the s_core_clk cycle
//  is equal to two s_cxl_clk cycles.
//
//  The parameter INP allows to map 1, 2, or 4 input channels
//  onto either 1 or 2 output channels.
//  The input data channels (ch_data) relate to s_core_clk while the registered
//  output data (r_map_data) relate to s_cxl_clk.
//  FIFO buffers store the input messages till they are mapped to AL.
//
//  The queue_fifo_interface module combines the queue mapper, the FIFO
//  controller, and the current interface mapper into one entity that gets
//  instantiated in upper level modules. The upper level modules may be:
//  cxl_cache_h2d (host to device), cxl_cache_d2h (device to host),
//  cxl_mem_m2s (master to subordinate), or cxl_mem_s2m (subordinate to master).
//  The M2S uses the module for requests, data, and back-invalidate responses.
//  The S2M uses the module for responses, data, and back-invalidate snoops.
//  The H2D uses the module for responses, requests, and data.
//  The D2H uses the module for requests, responses, and data.
//
//  CXL has ordering requirements for H2D: a request from H2D must not pass a
//  previously or same cycle issued H2D response. Thus, in H2D, the mapper of
//  requests must prevent any requests it has from going to application layer
//  if the response mapper did not finish yet.
//
//
// ----------------------------------------------------------------------------

`include "include/DWC_pcie_ctl_all_defs.svh"
`include "CXL/pkg/DWC_cxl_pkg.svh"

`include "CXL/svif/DWC_cxl_clk_rst_if.svh"

//  The parameters are
//  TP : (T)ime of (P)ropagation from clock to Q in flip flops. Simulation only.
//       `TP defined in DWC_pcie/DWC_pcie_ctl/src/DWC_pcie_aux_cc_constants.svh
//  CW : Application (C)redit (W)idth, number of bits for AL response credits
//  ICW: (I)nput (C)redit (W)idth, number of bits for input credits
//  OCW: (O)utput (C)redit (W)idth, number of bits for output credits
//  DW : (D)ata (W)idth, number of bits for data
//  INP: number of (INP)ut channels
//  OA : number of (O)utput channels going to (A)pplication layer.
//       For INP=1, OA=1 and this single channel may have 0 or 1 credits.
//       For INP=2, OA=1 and this single channel may have 0, 1, or 2 credits.
//       For INP=4, OA=2 and each channel may have 0, 1, or 2 credits.
//  ORD: value is 1 if this channel goes first (H2D responses)
//       value is 2 if this channel is second and waits for first (H2D requests)
//       value is 0 if this channel is not related to ordering requirements
module DWC_cxl_rx_tl_interface_mapper
  import DWC_cxl_pkg::*;
#(
    parameter   TP  = `TP
  , parameter   CW  = 4
  , parameter   ICW = 4
  , parameter   OCW = 4
  , parameter   DW  = 32
  , parameter   INP = 1
  , parameter   OA  = (INP-1)/2 + 1 //  OA=1 for 1inp and 2inp,   OA=2 for 4inp
  , parameter   ORD = 0
)
(
  //  The following interface defines the clock and reset for core and cxl.
   DWC_cxl_clk_rst_if.slave_mp       b_clk
  //  inputs in s_core_clk domain
  , input   logic [INP-1:0] [DW-1:0]  ch_data         // Data from Buffer
  , input   logic [INP-1:0]           ch_valid        // Valid data indication
  //  To process ordering requirements, there are inputs from the mapper
  //  of the "first" channels coming to the "second" channels mapper
  //  fst_chnl_pending means there are pending transactions queued to fifo of
  //  "first" channel having ordering dependency
  , input   logic                     fst_chnl_pending
  //  inputs in s_cxl_clk domain
  , input   logic [OA-1:0]            AL_crd          //Credit Input from AL
  , input   logic                     ch_msg_halt     //halts sending messages
  , input   logic                     nullify_crd_cnt //clearing credit count
  , input   logic                     run_crd_cnt     //running credit count
  //  toggle_flag is synchronized with cxl_clk.
  //  At a positive edge of cxl_clk the value of toggle_flag is
  //  1 if a positive edge of core_clk precedes the positive edge of cxl_core
  //  and the value is
  //  0 if a negative edge of core_clk precedes the positive edge of cxl_core.
  , input   logic                     toggle_flag

  //  The fst_chnl_rd_cnt is an input to the case of "second" channels and it comes
  //  from the rdptr_count output of the "first" channels mapper.
  //  It is stable for the period of s_core_clk and hold the count of
  //  messages already sent on all associated "first" channels. This allows
  //  the "second" channels mapper to handle ordering dependencies.
  , input   logic           [ICW-1:0] fst_chnl_rd_cnt

  //  The two read_aux signals are inputs for the case of INP=4. They are the
  //  two outputs stored_aux coming from the INP=2 mapper. They are auxiliary
  //  pointer and enable for the Host to Device (H2D) use case. The INP=2 mapper
  //  reads the top of the FIFO as the stored_aux_ptr and sets the enable when
  //  the channel can be sent to AL from ordering perspective. This allows the
  //  INP=4 mapper to check buffer overlfow.
  , input   logic           [OCW-1:0] read_aux_ptr
  , input   logic                     read_aux_ptr_en

  //  outputs in s_core_clk domain
  , output  logic [INP-1:0]           t_code_ch_pop   // Pop signal for Buffer starting from zero
  , output  logic [INP-1:0]           s_map_ch_pop    // Pop signal for Buffer ordered to pop from buffers
  , output  logic           [ICW-1:0] stored_aux_ptr
  , output  logic                     stored_aux_ptr_ctrl_en
  //  outputs in s_cxl_clk domain
  , output  logic [OA-1:0]  [DW-1:0]  r_map_data      // Data pushed to AL
  , output  logic           [OCW-1:0] rdptr_count
);

  //============================================================================
  //  Internal signals.
  //============================================================================

  localparam  LINP  = $clog2(INP);
  localparam  LOA   = $clog2(OA);


  //============================================================================
  //  The signal ch_msg_halt_r is the registered value of ch_msg_halt at
  //  s_cxl_clk edge. The next value of ch_msg_halt_r is n_ch_msg_halt_r.
  //============================================================================
  logic                               ch_msg_halt_r;
  logic                               n_ch_msg_halt_r;

  assign n_ch_msg_halt_r  = ch_msg_halt;

  always_ff @(posedge b_clk.s_core_clk or negedge b_clk.s_core_rst_n) begin : halt_PROC
    if (!b_clk.s_core_rst_n) begin
      ch_msg_halt_r  <= # TP '0;
    end else begin
      ch_msg_halt_r  <= # TP n_ch_msg_halt_r;
    end
  end : halt_PROC




  //  allow_al_msg_snd allows or prevents messages to the application layer.
  //  When allow_al_msg_snd is 0 it stops popping new messages from the FIFO
  //  and it makes the messages going towards the application layer all zeros.
  logic                               allow_al_msg_snd;

  //  rxmapper_min[][1] means at least 2 credits available in application layer.
  //  rxmapper_min[][0] means at least 1 credit  available in application layer.
  //  They are updated with s_cxl_clk and stable for the period of s_core_clk.
  logic [OA-1:0][1:0]                 rxmapper_min;

  //  ch_rd_ptr points to the last read buffer channel. Updated on s_core_clk.
  //  For INP=1 or INP=2 we have it as 1 bit as [0:0].
  //  For INP=4 we have 2 bits as [1:0].
  //  We cannot directly use [$clog2(INP)-1:0] because it gives a wrong value
  //  for INP=1.
  //  We may use the line
  //    logic [((INP-1)/2):0]            ch_rd_ptr;
  //  which fits for Inp=1, 2, or 4 but may not generalize for other values.
  //  We may think of a generate construct
  //  generate if (INP<2)    logic                             ch_rd_ptr;
  //  else     logic [($clog2(INP)-1):0]         ch_rd_ptr;
  //  endgenerate
  //  but it does not compile correctly.
  //  Or, we may simply use a local parameter which is a very easy solution
  localparam CH_RD_PTR_SIZE = (INP<3) ? 1 : LINP;
  logic [(CH_RD_PTR_SIZE-1):0]        ch_rd_ptr;

  //  no_of_ch_rds is the number of buffer channels read in a given s_core_clk
  logic [LINP:0]                      no_of_ch_rds;

  // The following 4 signals help in calculating the number of channels to read
  logic [INP-1:0]                     ch_valid_upd_int;
  logic [INP-1:0]                     ch_valid_upd;
  logic [LINP:0]                      ch_valid_upd_sum;
  logic [OA-1:0][LOA+1:0]             ch_crd;

  //  We use the least significant bit of the data as an indicator of validity.
  logic [INP-1:0] [DW-1:0]            ch_data_nd_valid;
  //  The input messages arrive to the intermediately mapped s_map_intd_data
  //  at s_core_clk edge based on ch_rd_ptr and input data from buffer.
  logic [INP-1:0]  [DW-1:0]           s_map_intd_data;
  //  Each s_cxl_clk edge, reg_rd_ptr maps s_map_intd_data to s_map_data.
  logic [LOA:0]                       reg_rd_ptr;
  logic [OA-1:0]  [DW-1:0]            s_map_data;

  //  The mapper with ORD=2 has ordering comparison to prevent the other mapper 
  //  with ORD=1 channel from rolling over beyond its buffer depth.
  logic [INP-1:0]                     ch_ptr_comp;
  logic [INP-1:0]                     ch_vld_cmp;
  //  The mapper with ORD=1 uses the next rdptr_count and rdptr_count+INP
  logic [OCW-1:0]                     n_rdptr_count;
  logic [OCW-1:0]                     rdptr_count_plus_INP;

  //  Variable for loops in generate statements
  genvar                              g_lp_idx;
  //  Variables for loops in other statements
  int                                 loop_idx;
  int                                 o_lp_idx;
  int                                 p_lp_idx;
  int                                 s_lp_idx;

  //  Function to return its input modulo the paramter INP
  function automatic logic [(CH_RD_PTR_SIZE-1):0] MOD_INP
  (
    int a
  );
    return ( (a<INP)? CH_RD_PTR_SIZE'(a): CH_RD_PTR_SIZE'(a-INP));
  endfunction

  //============================================================================
  //  The signal allow_al_msg_snd allows or prevents sending messages to the
  //  application layer. It depends on the input ch_msg_halt.
  //============================================================================

  //============================================================================
  //  Signals related to ordering requirements between different channels.
  //  The mapper with ORD=1 has priority while the mapper with ORD=2 must
  //  wait for the "other channel (i.e. the one with ORD=1)".
  //  A mapper with ORD=0 has no ordering requirements to another mapper.
  //============================================================================
  generate
    always_comb begin
      //  Default values if all the following conditions are false
      ch_ptr_comp             = '0;
      ch_vld_cmp              = '0;
      stored_aux_ptr_ctrl_en  = '0;
      stored_aux_ptr          = '0;
      allow_al_msg_snd        = '0;
      rdptr_count_plus_INP    = rdptr_count + 'h4;
      if (ORD == 0) begin : no_order_mapper_PROC
        ch_vld_cmp              = ch_valid;
        allow_al_msg_snd        = ~(ch_msg_halt_r);
      end : no_order_mapper_PROC
      if (ORD == 1) begin : FIRST_mapper_PROC
        ch_vld_cmp              = ch_valid;

        //  allow_al_msg_snd in the mapper that goes FIRST/has priority
        //  (for example the H2D response) is disabled in a certain condition 
        //  to prevent this FIRST mapper from popping more messages from its
        //  own FIFO and incrementing its own read pointer. The condition is
        //  that we do not want the read pointer to wrap around when incremented
        //  to become a value that appears to the SECOND mapper (the one that
        //  must wait) as if the incremented value is smaller than what the
        //  SECOND mapper is currently considering. We need to stop the FIRST
        //  mapper in this way if the SECOND mapper already meets the ordering
        //  requirements but is not progressing because the application layer
        //  puts back-pressure on it. If we do not stop FIRST mappper, it will
        //  wrap around and the SECOND mapper will think it does not meet order
        //  requirement and will remain blocked which could cause the buffer of
        //  SECOND mapper to overflow.
        //  The read_aux_ptr_en comes from the mapper that goes SECOND/must wait
        //  (for example the H2D request).
        //  It is the auxiliary pointer read control enable from the SECOND
        //  mapper.
        //  If this enable is high, we check whether we have enough space to
        //  send up to INP new messages that might come on the inputs. Thus, the
        //  allow_al_msg_snd signal compares the input read_aux_ptr to the count of
        //  messages already sent on all associated channels plus INP
        //  as given by rdptr_count_plus_INP.
        //  If rdptr_count_plus_INP is less than read_aux_ptr it means that we have
        //  enough empty locations to send up to INP more and we can allow the module
        //  to send messages.
        rdptr_count_plus_INP  = rdptr_count + INP;
        allow_al_msg_snd      =   (ch_msg_halt_r)     ? '0
                                : (!read_aux_ptr_en)  ? '1
                                :           ( rdptr_count_plus_INP[OCW-1]    == read_aux_ptr[OCW-1]) ||
                                            ( rdptr_count_plus_INP[OCW-2:0]  <  read_aux_ptr[OCW-2:0]);
      end : FIRST_mapper_PROC
      else if (ORD == 2) begin : SECOND_mapper_PROC
        //  If other channel is empty, no pointer comparison required
        if(~fst_chnl_pending) ch_ptr_comp='1;
        else begin
          //  check if the pointer of messages in FIRST moved ahead of pointer
          //  of messages in SCND mapper.
          //  (check if H2D response message pointer moved ahead of H2D request
          //  message read pointer)
          //  If yes then set the corresponding ch_ptr_comp bit to 1 in order to
          //  enable sending the messages in the SCND mapper.
          for (o_lp_idx = 0; o_lp_idx<INP; o_lp_idx=o_lp_idx+1) begin
            if(fst_chnl_rd_cnt[ICW-1]==ch_data[o_lp_idx][(DW-1)])
              ch_ptr_comp[o_lp_idx]  = (fst_chnl_rd_cnt[ICW-2:0] >= ch_data[o_lp_idx][(DW-2):(DW-1-ICW+1)]);
            else
              ch_ptr_comp[o_lp_idx]  = (fst_chnl_rd_cnt[ICW-2:0] <  ch_data[o_lp_idx][(DW-2):(DW-1-ICW+1)]);
          end
        end
  
        ch_vld_cmp              = ch_valid & ch_ptr_comp;
        stored_aux_ptr_ctrl_en  = ch_vld_cmp[ch_rd_ptr];
        stored_aux_ptr          = ch_data[ch_rd_ptr][(DW-1):(DW-ICW)];
        allow_al_msg_snd        = ~(ch_msg_halt_r);
      end  : SECOND_mapper_PROC
    end
  endgenerate

  //============================================================================
  //  For each OA channel, the following module calculates the number of usable
  //  credits in AL based on the actual AL_crd input and whether there is
  //  valid data to send (indicated by the least significant bit of s_map_data)
  //  and permission to send messages to application layer (allow_al_msg_snd).
  //============================================================================
  logic [OA-1:0] s_map_data_bit0_allow;
  logic [OA-1:0] rxmapper_min_bit0;
  logic [OA-1:0] rxmapper_min_bit1;
  generate for(g_lp_idx=0; g_lp_idx<OA; g_lp_idx++) begin : credit_control
    always_comb begin
      s_map_data_bit0_allow[g_lp_idx] = s_map_data[g_lp_idx][0] & allow_al_msg_snd;
      rxmapper_min[g_lp_idx][0]       = rxmapper_min_bit0[g_lp_idx];
      rxmapper_min[g_lp_idx][1]       = rxmapper_min_bit1[g_lp_idx];
    end
  end : credit_control
  endgenerate
  //  The module outputs are s_ch_crd_rxmapper_min2 and s_ch_crd_rxmapper_min1.
  DWC_cxl_rx_tl_credit_control
  
   #(
    .CH_CRD_WD (CW)
    ) U_DWC_cxl_rx_tl_credit_control [OA-1:0] (
     .b_clk                  (b_clk)
    ,.toggle_flag            (toggle_flag)
    ,.ch_crd                 (AL_crd)
    ,.nullify_crd_cnt        (nullify_crd_cnt)
    ,.run_crd_cnt            (run_crd_cnt)
    ,.n_data_valid           (s_map_data_bit0_allow)
    ,.s_ch_crd_rxmapper_min1 (rxmapper_min_bit0)
    ,.s_ch_crd_rxmapper_min2 (rxmapper_min_bit1)
  );

  //============================================================================
  //  Signals to set the value of rdptr_count
  //============================================================================
  //  sum_valid and sum_r_valid are auxiliary variables to help calculate
  //  n_rdptr_count.
  //  We use them to loop on all the OA channels and sum the values of the valid
  //  bits.
  logic [OA-1:0][LOA:0]                 sum_valid;
  logic [OA-1:0][LOA:0]                 sum_r_valid;

  // The size casting in the assign may help to reduce linting errors
  assign  sum_valid[0][LOA:0] = (LOA+1)'(s_map_data[0][0]);
  generate for(g_lp_idx=1; g_lp_idx<OA; g_lp_idx++) begin : sum_valid_PROC
    assign sum_valid[g_lp_idx][LOA:0] = (LOA+1)'(  sum_valid[g_lp_idx-1][LOA:0]
                                                 + s_map_data[g_lp_idx][0]);
  end : sum_valid_PROC
  endgenerate

  // The size casting in the assign may help to reduce linting errors
  assign  sum_r_valid[0][LOA:0] = (LOA+1)'(r_map_data[0][0]);
  generate for(g_lp_idx=1; g_lp_idx<OA; g_lp_idx++) begin : sum_r_valid_PROC
    assign sum_r_valid[g_lp_idx][LOA:0] = (LOA+1)'(  sum_r_valid[g_lp_idx-1][LOA:0]
                                                   + r_map_data[g_lp_idx][0]);
  end : sum_r_valid_PROC
  endgenerate

  assign n_rdptr_count  = OCW'(rdptr_count + sum_valid[OA-1][LOA:0]);

  always_ff @(posedge b_clk.s_core_clk or negedge b_clk.s_core_rst_n) begin : rdptr_PROC
    if (!b_clk.s_core_rst_n) begin
      rdptr_count <= # TP '0;
    end else begin
      rdptr_count <= # TP n_rdptr_count;
    end
  end : rdptr_PROC


  //============================================================================
  //  Signals to set the new value of ch_rd_ptr based on the number of channels
  //  to be read. The maximum number of channels we can read equals INP.
  //  We compare the number of valid channels to the available credits then
  //  decide on the actual number of channels we can read.
  //============================================================================

  //  We read in a Round Robin manner out of the valid channels ch_vld_cmp
  //  starting from the current position of ch_rd_ptr. We stop if we reach a 0
  //  in ch_vld_cmp even if we do not fill all the INP channels.
  generate if(INP==1)
    assign ch_valid_upd_int[0] = ch_vld_cmp;
  else
    assign ch_valid_upd_int[0] = ch_vld_cmp[ch_rd_ptr];
  endgenerate
  generate
    for(g_lp_idx=1; g_lp_idx<INP; g_lp_idx=g_lp_idx+1) begin : ch_valid_PROC
      assign ch_valid_upd_int[g_lp_idx] =
                                ch_vld_cmp[MOD_INP(int'(ch_rd_ptr+g_lp_idx))]
                              & ch_valid_upd_int[(g_lp_idx-1)];
    end : ch_valid_PROC
  endgenerate

    //  Use a left rotator to implement the Round Robin reading based on the
    //  value of ch_rd_ptr.
    //  The size of the result is INP so we use a casting of INP'(...) to avoid
    //  any problems while linting the code.
    //  Inside the cast, we do a left rotation using a right shifter.
    //  So we use double the width of the input and shift that value to the
    //  right by (SIZE - rotation_value) to get the effect of a left rotation.

  assign ch_valid_upd = INP'({ch_valid_upd_int,ch_valid_upd_int}>>(INP-CH_RD_PTR_SIZE'(ch_rd_ptr)));

  //  Calculate the total number of valid channels
  //  The $countones function of system verilog should be synthesizable
  //  but it is not supported by all tools. So, we do it here explicitly.
  //  Instead of
  //  assign ch_valid_upd_sum = $countones(ch_valid_upd);
  //  use
  always_comb begin
    ch_valid_upd_sum  = '0;
    for (loop_idx = 0; loop_idx<INP; loop_idx=loop_idx+1) begin
      ch_valid_upd_sum = (LINP+1)'(ch_valid_upd_sum + ch_valid_upd[loop_idx]);
    end
  end

  //  Calculate the total number of available credits:
  //  If rxmapper_min[*][1] is high we add 2.
  //  If rxmapper_min[*][1] is low but rxmapper_min[*][0] is high we add 1.
  //  Otherwise, we add 0.
  //  For INP=1, OA=1 and only add1 is possible while add2 is not possible.
  //  For other values of INP, both add2 and add1 are possible for each OA.
  //  Hence the maximum value of credits is 2*OA.
  generate if(INP==1)
    assign ch_crd[0][LOA+1:0] = rxmapper_min[0][0] ? 'h1 : 'h0;
  else begin
    assign ch_crd[0][LOA+1:0] = rxmapper_min[0][1] ? 'h2 : rxmapper_min[0][0] ? 'h1 : 'h0;
    for (g_lp_idx=1; g_lp_idx<OA; g_lp_idx++) begin
      assign ch_crd[g_lp_idx][LOA+1:0] =   ch_crd[g_lp_idx-1][LOA+1:0]
                                + (rxmapper_min[g_lp_idx][1] ? 'h2 : rxmapper_min[g_lp_idx][0] ? 'h1 : 'h0);
    end
  end
  endgenerate

  //  Read 0 channels if not allowed to send messages to Application Layer
  //  Otherwise, read the smaller value of ch_valid_upd_sum and ch_crd
  //  Use a size cast to avoid linting issues.
  assign no_of_ch_rds = (!allow_al_msg_snd)                                   ? '0 :
                        (32'(ch_valid_upd_sum) > 32'(ch_crd[OA-1][LOA+1:0]))  ? (LINP+1)'(ch_crd[OA-1][LOA+1:0]) :
                                                                                ch_valid_upd_sum;

  //  We should update the ch_rd_ptr by adding the number of channels read.
  //  The addition is modulo addition which is good to correctly make it rotate
  //  in a Round Robin manner.
  //  For the case of INP=1, ch_rd_ptr remains always 0.
  generate if(INP==1) assign ch_rd_ptr  = '0;
  else
    always_ff @( posedge b_clk.s_core_clk or negedge b_clk.s_core_rst_n) begin : ch_rd_ptr_PROC
      if ( ~b_clk.s_core_rst_n)
        ch_rd_ptr      <= # TP    '0;
      else
        ch_rd_ptr      <= # TP    MOD_INP(int'(ch_rd_ptr + no_of_ch_rds));
    end : ch_rd_ptr_PROC
  endgenerate

  //============================================================================
  //  Signals to select channels to be popped
  //============================================================================

  //  We want to end up with s_map_ch_pop being equal to ch_valid_upd
  //  except that the string of 1's is only as long as no_of_ch_rds.
  //  Remember that no_of_ch_rds may be smaller than the number of 1's in
  //  the original ch_valid_upd in case (ch_valid_upd_sum > ch_crd) or if
  //  we are not allowed to send any messages to application layer.

  //  First let us get a string containing no_of_ch_rds of 1's by making a
  //  "thermometer code". Then we rotate that "thermometer code" such that the
  //  string of 1's starts at the location of ch_rd_ptr.

  always_comb begin : map_pop_PROC
    //  In a "thermometer code",
    //  the value of the input indicates the number of least significant bits
    //  in the result that should be all ones. The other most significant bits
    //  should be all zeros.
    //
    //  Start by setting all the bits to ones.
    //  Then shift left by the value of the input.
    //  The shift introduces a number of zeros on the right equal to the input.
    //  The left most bits remain all ones.
    //  Finally complement all the bits to get the desired result.

    t_code_ch_pop = ~({INP{1'b1}}<<no_of_ch_rds);

    //  Use a left rotator to implement the Round Robin reading based on the
    //  value of ch_rd_ptr.
    //  The size of the result is INP so we use a casting of INP'(...) to avoid
    //  any problems while linting the code.
    //  Inside the cast, we do a left rotation using a right shifter.
    //  So we use double the width of the input and shift that value to the
    //  right by (SIZE - rotation_value) to get the effect of a left rotation.

    s_map_ch_pop  = INP'({t_code_ch_pop,t_code_ch_pop}>>(INP-ch_rd_ptr));
  end : map_pop_PROC


  //============================================================================
  //  Signals to set the value of mapped data
  //============================================================================

  //  The s_map_ch_pop signals go to the FIFO buffers. During the same clock
  //  (of s_core_clk), the interface mapper receives the data back on ch_data.
  //  The ch_data is an array of data values holding the messages read from the
  //  FIFO at the locations enabled by s_map_ch_pop. Thus the messages start at
  //  the location indicated by the ch_rd_ptr which was used to make
  //  s_map_ch_pop.
  //
  //  We want to map these messages to the output of the interface mapper:
  //
  //  1. We start by making the array of values s_map_intd_data which should
  //  hold the messages starting from location 0. Thus, we need to rotate the
  //  ch_data array to the right (this is the opposite direction of what was
  //  done in s_map_ch_pop) by the value of ch_rd_ptr. The opposite rotation
  //  puts the values starting from location 0 in s_map_intd_data.
  //
  //  2. The s_map_data get values from s_map_intd_data based on how many
  //  messages we can send to Application Layer in each s_cxl_clk cycle.
  //
  //  3. The output r_map_data holds the values of s_map_data at the edge of the
  //  s_cxl_clk.



  //  The least significant bit of each data value should indicate whether the
  //  value is valid or not.

  generate
    for(g_lp_idx=0; g_lp_idx<INP; g_lp_idx++)  begin : valid_PROC
      assign ch_data_nd_valid[g_lp_idx][DW-1:0] = {ch_data[g_lp_idx][(DW-1):1],
                             (ch_data[g_lp_idx][0] & ch_valid_upd[g_lp_idx])};
    end : valid_PROC
  endgenerate


  //  The ch_data_nd_valid is a two-dimensional packed array.
  //  If we want to rotate by 1 location of the higher dimension, we rotate
  //  by the size of the lower dimension which is DW bits.
  //  If we want to rotate by 2 locations we rotate by 2*DW bits and so on.
  //  Right rotation:
  assign s_map_intd_data =
                (INP*DW)'({ch_data_nd_valid,ch_data_nd_valid}>>(ch_rd_ptr*DW));

  //  Each s_cxl_clk edge, reg_rd_ptr maps s_map_intd_data to s_map_data.
  //  reg_rd_ptr is always 0 in case of CX_CXL_SYNCHRONOUS when s_core_clk and
  //  s_cxl_clk have the same frequency.
  //  Otherwise, when not in CX_CXL_SYNCHRONOUS, the s_core_clk cycle is equal
  //  to two s_cxl_clk cycles. In this case, reg_rd_ptr stores the number of
  //  messages already considered for sending to AL in the first cycle of
  //  s_cxl_clk which is the first half of s_core_clk.
  //  The case INP==1 has a special treatment because the current desired
  //  behavior depends directly on toggle_flag and does not depend on s_cxl_clock
  assign reg_rd_ptr     =         '0;

  //  In the case of CX_CXL_SYNCHRONOUS there is at most one message coming on
  //  any input channel within the s_core_clk cycle (we can not have min2) and
  //  what comes on the input goes to the output in the same cycle of s_cxl_clk.
  //  We always have reg_rd_ptr=0 for CX_CXL_SYNCHRONOUS.
  //
  //  When not CX_CXL_SYNCHRONOUS then in the first cycle of s_cxl_clk we start
  //  in the state 0 (reg_rd_ptr=0) and see how many messages we have to begin
  //  mapping.
  //  Based on the number of mapped messages in the first cycle, reg_rd_ptr
  //  may move to state 1, 2,... OA or it may remain at state 0. 
  //  The new state of reg_rd_ptr together with the values
  //  of min1 and min2 govern the mapping in the second cycle. After the second
  //  cycle, reg_rd_ptr returns to state 0.
  //  rxmapper_min is stable for the whole of s_core_clk.

  //  The mapped_cnt is an auxiliary variable to count the mapped channels
  //  while looping through the statements below to assign s_map_data
  // 
  logic [(CH_RD_PTR_SIZE-1):0] mapped_cnt;
  logic                         other_OA_zero;
  generate
    always_comb begin : s_map_data_PROC
      //  default value of all 0s if all the conditions below are false.
      s_map_data = '0;
      if(allow_al_msg_snd==0) begin : allow_al_msg_snd_is_0
        s_map_data = '0;
      end : allow_al_msg_snd_is_0
      else begin : allow_al_msg_snd_is_not_0
        for (p_lp_idx=0; p_lp_idx<OA+1; p_lp_idx=p_lp_idx+1) begin : loop_reg_rd_ptr_values
          mapped_cnt = '0;
          if(reg_rd_ptr==p_lp_idx) begin : reg_rd_ptr_matches_p_lp_idx
            if(reg_rd_ptr=='0) begin : reg_rd_ptr_is_0
            //  If in state 0 and there is min1 on one of the OA then
            //  send the message on the corresponding channel
            //  and increment mapped_cnt.
              for (s_lp_idx=0; s_lp_idx<OA; s_lp_idx=s_lp_idx+1) begin : loop_OA_reg0
                if(rxmapper_min[s_lp_idx][0]) begin
                  s_map_data[s_lp_idx][DW-1:0] = s_map_intd_data[mapped_cnt][DW-1:0];
                  mapped_cnt = mapped_cnt + 'h1;
                end
              end : loop_OA_reg0
            end : reg_rd_ptr_is_0
            else begin : reg_rd_ptr_is_not_0
            //  INP==1 means at most one input message per s_core_clk. We mapped
            //  that message already with reg_rd_ptr==0, hence the following
            //  logic is for !(INP==1).
              if (!(INP==1)) begin : INP_is_not_1
                //  INP==2 means at most two input messages per s_core_clk.
                //  If we reach here, it means that we already considered 1 in the
                //  first cycle. Now check if there is min2. If yes then send the
                //  second message on the single output channel.
                if(INP==2) begin : INP_is_2
                  if(rxmapper_min[0][1])
                    s_map_data[0][DW-1:0] = s_map_intd_data[INP-1][DW-1:0];
                end : INP_is_2
                else begin : INP_is_more_than_2
                  //  If we reach this state then we have mapped at least one
                  //  message in the previous cycle and INP>2.
                  //  Now check if there is min2 on each OA. If yes then
                  //  send the remaining messages on the corresponding channel
                  //  and increment mapped_cnt.

                  //  If reg_rd_ptr is 1, it means that we mapped only 1 message
                  //  in the first cycle to a certain OA channel.
                  //  The only meaningful possibility now is to map another
                  //  message if any exist to the same OA channel assuming that
                  //  all the other OA channels have zero credits.
                  //  We use the signal other_OA_zero to check that the other
                  //  channels have zero credits.
                  //  We map the message if other_OA_zero and rxmapper indicates
                  //  min2 on the channel that already had min1
                  if(reg_rd_ptr=='h1) begin : reg_rd_ptr_is_1
                    for (s_lp_idx=0; s_lp_idx<OA; s_lp_idx=s_lp_idx+1) begin : loop_OA_reg1
                      other_OA_zero = '1;
                      for (int t_lp_idx=0; t_lp_idx<OA; t_lp_idx=t_lp_idx+1) begin
                        if(t_lp_idx!=s_lp_idx) other_OA_zero = other_OA_zero & ~rxmapper_min[t_lp_idx][0];
                      end
                      if(rxmapper_min[s_lp_idx][1]&rxmapper_min[s_lp_idx][0]&other_OA_zero) begin
                        s_map_data[s_lp_idx][DW-1:0] = s_map_intd_data[MOD_INP(int'(reg_rd_ptr+mapped_cnt))][DW-1:0];
                        mapped_cnt = mapped_cnt + 'h1;
                      end
                    end : loop_OA_reg1
                  end : reg_rd_ptr_is_1
                  else begin : reg_rd_ptr_is_more_than_1
                    //  When reg_rd_ptr is more than 1 we map the messages
                    //  to the channels that have min2 credits.
                    for (s_lp_idx=0; s_lp_idx<OA; s_lp_idx=s_lp_idx+1) begin : loop_OA_reg_more_than_1
                      if(rxmapper_min[s_lp_idx][1]&rxmapper_min[s_lp_idx][0]) begin
                        s_map_data[s_lp_idx][DW-1:0] = s_map_intd_data[MOD_INP(int'(reg_rd_ptr+mapped_cnt))][DW-1:0];
                        mapped_cnt = mapped_cnt + 'h1;
                      end
                    end : loop_OA_reg_more_than_1
                  end : reg_rd_ptr_is_more_than_1
                end : INP_is_more_than_2
              end : INP_is_not_1
            end : reg_rd_ptr_is_not_0
          end : reg_rd_ptr_matches_p_lp_idx
        end : loop_reg_rd_ptr_values
      end : allow_al_msg_snd_is_not_0
    end : s_map_data_PROC
  endgenerate

  //  The output r_map_data consumes the mapped messages on s_map_data.
  //  r_map_data is a free running signal that gets all 0s if it is not allowed
  //  to send messages to AL or if there is no valid data. Otherwise, it gets
  //  the valid data.
  generate  for (g_lp_idx=0; g_lp_idx<OA; g_lp_idx++) begin : r_map_data_PROC
    always_ff @( posedge b_clk.s_cxl_clk or negedge b_clk.s_cxl_rst_n) begin
      if ( ~b_clk.s_cxl_rst_n)
        r_map_data[g_lp_idx][DW-1:0]  <= # TP '0;
      else
        r_map_data[g_lp_idx][DW-1:0]  <= # TP (allow_al_msg_snd        == '0) ? '0  :
                                              (s_map_data[g_lp_idx][0] == '0) ? '0  :
                                                                        s_map_data[g_lp_idx][DW-1:0];
    end
  end : r_map_data_PROC
  endgenerate

endmodule
