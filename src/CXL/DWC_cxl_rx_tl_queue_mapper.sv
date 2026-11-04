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
// ---   $DateTime: 2023/06/26 08:32:07 $
// ---   $Revision: #1 $
// ---   $Id: //dwh/pcie_iip/main/fairbanks/design/CXL/DWC_cxl_rx_tl_queue_mapper.sv#1 $
// -------------------------------------------------------------------------
// --- Module Description:
// ----------------------------------------------------------------------------
//  This module maps the input data to the different FIFO buffers of the next
//  stage in a Round Robin manner (output is s_map_data)
//
// ----------------------------------------------------------------------------

`include "include/DWC_pcie_ctl_all_defs.svh"
`include "CXL/pkg/DWC_cxl_pkg.svh"

`include "CXL/svif/DWC_cxl_clk_rst_if.svh"

//  The parameters are
//  TP : (T)ime of (P)ropagation from clock to Q in flip flops. Simulation only.
//       `TP defined in DWC_pcie/DWC_pcie_ctl/src/DWC_pcie_aux_cc_constants.svh
//  DW : (D)ata (W)idth, number of bits for data
//  NC : (N)umber of input (C)hannels
//  WR_PTR_WD: WRite PoinTeR WiDth, number of bits for pointer
module DWC_cxl_rx_tl_queue_mapper #(
    parameter TP         = `TP
  , parameter DW         = 32
  , parameter NC         = 4
  , parameter WR_PTR_WD  = 4
  ) (
    input  logic                    clk             // s_core_clk
  , input  logic                    rst_n           // s_core_rst_n
  , input  logic [NC-1:0] [DW-1:0]  data_in         // Input data from Link Layer
  , input  logic                    crc_err         // CRC Error indication

  , output logic                    s_map_pending   // Indicator for valid data
  , output logic [NC-1:0]           s_map_data_push // channels with pushed data
  , output logic [NC-1:0] [DW-1:0]  s_map_data      // Data to be pushed
  //  s_wrptr_count_nd_valids is a combinational output of the current wrptr
  //  plus the number of valid data inputs
  , output logic [WR_PTR_WD-1:0]    s_wrptr_count_nd_valids
  );

  localparam  LNC = $clog2(NC);
  localparam  LNC_CAST = (LNC==0) ? 1 : LNC;


  //============================================================================
  //  valid_count is a count of the valid current data inputs.
  //
  //  tc_vld is a "thermometer code" for valid_count. It is an auxiliary signal
  //  to calculate s_map_data_push.
  //  In a "thermometer code",
  //  the value of the input indicates the number of least significant bits
  //  in the result that should be all ones. The other most significant bits
  //  should be all zeros.
  //
  //  valid_data holds the valid data grouped together such that the first
  //  valid data is at valid_data[0], the second valid data is at valid_data[1],
  //  and so on. The remaining locations of the valid_data array should hold the
  //  data value of the most significant channel.
  //  valid_data is an auxiliary signal to calculate s_map_data.
  //============================================================================

  logic [LNC:0]             valid_count;
  logic [NC-1:0]            tc_vld;
  logic [NC-1:0] [DW-1:0]   valid_data;

  always_comb begin : group_valid_data_PROC
    //  Default values in case there is no valid data
    valid_count     = '0;
    tc_vld          = '0;
    valid_data      = {NC{data_in[NC-1][DW-1:0]}};

    for (int loop_idx=0; loop_idx<NC; loop_idx++) begin
      if (data_in[loop_idx][0]) begin
        tc_vld[LNC_CAST'(valid_count)]             = 1'b1;
        valid_data[LNC_CAST'(valid_count)][DW-1:0] = data_in[loop_idx][DW-1:0];
        valid_count                           = valid_count + 1'b1;
      end
    end
  end : group_valid_data_PROC

  // Another way to implement tc_vld is:
  // assign  tc_vld          = ~({NC{1'b1}}<<valid_count);

  //============================================================================
  //  Data is pending only if crc_err==0 and any data is valid
  //============================================================================

  always_ff @(posedge clk or negedge rst_n) begin : pending_PROC
    if (!rst_n) begin
      s_map_pending <= #TP '0;
    end else begin
      s_map_pending <= #TP  ((crc_err=='0)&(valid_count!='0));
    end
  end : pending_PROC

  //============================================================================
  //  s_wrptr_count_nd_valids changes only when crc_err==0
  //============================================================================

  //  s_wrptr_count is a pointer to the channel to be written
  logic [WR_PTR_WD-1:0]    s_wrptr_count;

  assign s_wrptr_count_nd_valids =  (crc_err)   ? s_wrptr_count :
                                                  WR_PTR_WD'(s_wrptr_count + valid_count);

  always_ff @(posedge clk or negedge rst_n) begin : wrptr_PROC
    if (!rst_n) begin
      s_wrptr_count <= #TP  '0;
    end else begin
      s_wrptr_count <= #TP  s_wrptr_count_nd_valids;
    end
  end : wrptr_PROC

  //============================================================================
  //  Pointer w_ptr to select the data. It is a "thermometer code".
  //
  //  In a "thermometer code",
  //  the value of the input indicates the number of least significant bits
  //  in the result that should be all ones. The other most significant bits
  //  should be all zeros.
  //
  //  invalid_w_ptr indicates that the w_ptr reached an invalid state which is
  //  not all 0 nor a thermometer code.
  //  An invalid state should never occur in normal operation.
  //
  //  cnt_w_ptr represents the number of ones in w_ptr
  //
  //  tc_ptr is an auxiliary signal for w_ptr.
  //  
  //============================================================================

  logic [NC-1:0]          w_ptr;
  logic                   invalid_w_ptr;
  logic [LNC:0]           cnt_w_ptr;
  logic [2*NC-1:0]        tc_ptr;

  //  To detect an invalid w_ptr we start from the most significant bit and
  //  signal an invalid code if we see a transition from 1 to 0.
  always_comb begin : invalid_w_ptr_PROC
    //  Default values in case there is no ones
    invalid_w_ptr = '0;
    for (int loop_idx=1; loop_idx<NC; loop_idx++) begin
      invalid_w_ptr = invalid_w_ptr | (w_ptr[NC-loop_idx] & ~w_ptr[NC-loop_idx-1]);
    end
  end : invalid_w_ptr_PROC


  //  Some synthesis tools do not accept the $countones of system verilog.
  //  Hence, we do it explicitly.
  always_comb begin : cnt_w_ptr_PROC
    //  Default values in case there is no ones
    cnt_w_ptr = '0;
    for (int loop_idx=0; loop_idx<NC; loop_idx++) begin
      cnt_w_ptr = (LNC+1)'(cnt_w_ptr + w_ptr[loop_idx]);
    end
  end : cnt_w_ptr_PROC

  //  To get tc_ptr, we treat the case of w_ptr being all 1 as if it is all 0.
  //  Logically, this means that if we finish all the channels (all 1) we
  //  restart again as if they are all 0.
  //  We add the count of valid data channels (valid_count) to the count of
  //  previous channels (cnt_w_ptr) and make a thermometer code of that sum.
  assign tc_ptr = (w_ptr== {NC{1'b1}})?  ~({(2*NC){1'b1}}<<(valid_count+'0)) :
                                         ~({(2*NC){1'b1}}<<(valid_count+cnt_w_ptr));

  //  w_ptr is only updated when there is no crc_err.
  //  If invalid_w_ptr is raised, we set w_ptr to 0.
  //  Otherwise, we set w_ptr to tc_ptr but taking into account that we
  //  "wrap_around" when we exceed the all 1 case.
  always_ff @(posedge clk or negedge rst_n) begin : w_ptr_PROC
    if (!rst_n) begin
      w_ptr <= #TP '0;
    end else begin
      w_ptr <= #TP  (crc_err)             ? w_ptr :
                    (invalid_w_ptr)       ? '0 :
                    (tc_ptr> {NC{1'b1}})  ? tc_ptr[2*NC-1:NC] :
                                            tc_ptr[NC-1:0];
    end
  end : w_ptr_PROC

  //============================================================================
  //  Signals to indicate which data channels are pushed as well as the data
  //  values. They are meaningful only when crc_err==0.
  //============================================================================

  //  Use a left rotator to implement the Round Robin writing based on
  //  the number of ones in w_ptr.
  //  The size of the result is NC so we use a casting of NC'(...) to
  //  avoid any problems while linting the code.
  //  Inside the cast, we do a left rotation using a right shifter.
  //  So we use double the width of the input and shift that value to the
  //  right by (SIZE - rotation_value) to get the effect of a left rotation.
  assign  s_map_data_push = (crc_err)       ? '0 :
                            (invalid_w_ptr) ? '0 :
                                      NC'({tc_vld,tc_vld}>>(NC-cnt_w_ptr));

  //  The data is represented as a two-dimensional packed array.
  //  If we want to rotate by 1 location of the higher dimension, we rotate
  //  by the size of the lower dimension which is DW bits.
  //  If we want to rotate by 2 locations we rotate by 2*DW bits and so on.
  assign  s_map_data      = (invalid_w_ptr) ? '0 :
                  (NC*DW)'({valid_data,valid_data}>>((NC-cnt_w_ptr)*DW));

endmodule
