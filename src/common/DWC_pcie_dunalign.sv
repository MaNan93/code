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
// ---    $DateTime: 2023/04/29 12:35:01 $
// ---    $Revision: #7 $
// ---    $Id: //dwh/pcie_iip/main/fairbanks/design/common/DWC_pcie_dunalign.sv#7 $
// -------------------------------------------------------------------------
//  This module realigns (packs) input data based on input data strobes.
// ----------------------------------------------------------------------------

`include "include/DWC_pcie_ctl_all_defs.svh"

 
 module DWC_pcie_dunalign (
            clk,
            rst_n,
            init_n,
            data_rdy_in,
            data_vld_in,
            params_in,
            data_last_in,
            addr_in,
            burst_len_in,
            size_in,
            data_in,
            data_rdy_out,
            data_vld_out,
            params_out,
            data_last_out,
            data_out,
            resp_in_progress
            );

   // External Parameters
   parameter PW     =   16 ;     // Extra Parameters Width
   parameter AXI_ADDR_OFSET_WD     =   8 ;     // Address Width
   parameter BW     =   9 ;     // Max burst length width
   parameter SW     =   3 ;     // Size Width
   parameter AXI_DBUS_WD     = 128 ;     // Width Of Data In Bits
   parameter NS     =   32;     // Number Data Strobes Per Data
   parameter LS     =   5 ;     // Log2(Number Data Strobes Per Data)
   parameter IS_DBI =   0 ;

   // Internal Parameters
   parameter DATA_BYTE_WD_W_PARITY = AXI_DBUS_WD/NS;
   parameter TP = `TP;

   localparam OS = AXI_DBUS_WD;
   localparam OB = AXI_DBUS_WD - NS;
   localparam SS = NS;
   localparam PM = `CX_RAS_PARITY_MODE ? 1'b1 : 1'b0 ; //Parity Mode

localparam SLV_BUS_ID_WIDTH     = `CC_SLV_BUS_ID_WIDTH;
localparam PARAMS_CPL_STAT_HIGH = PW-SLV_BUS_ID_WIDTH-10 -1;
localparam PARAMS_CPL_STAT_LOW  = PARAMS_CPL_STAT_HIGH-2;
localparam PARAMS_TO            = PW-SLV_BUS_ID_WIDTH-3 ;

 // ===============================================================================================
  // ==================  Inputs ========================
  // ===============================================================================================
   input                            clk;                // Sys Clock
   input                            rst_n;              // Async Reset
   input                            init_n;             // Sync Init
   input                            data_rdy_in;        // Data Ready In
   input                            data_vld_in;        // Data Valid In
   input [PW-1:0]                   params_in;          // Extra Parameters In
   input                            data_last_in;       // Data Last In
   input [AXI_ADDR_OFSET_WD -1:0]   addr_in;            // Address In
   input [BW -1:0]                  burst_len_in;       // Byte Count In
   input [SW -1:0]                  size_in;            // Size In
   input [AXI_DBUS_WD -1:0]         data_in;            // Data In

  // ===============================================================================================
  // ==================  Outputs  ========================
  // ===============================================================================================
   output                          data_rdy_out;       // Data Ready Out
   output                          data_vld_out;       // Data Valid Out
   output [PW -1:0]                params_out;         // Extra Parameters Out
   output                          data_last_out;      // Data Last Out
   output [AXI_DBUS_WD -1:0]       data_out;           // Data
   output                          resp_in_progress;   // Data

  // ===============================================================================================
  // ==================  Internal IO declarations  ========================
  // ===============================================================================================
   wire                            data_rdy_out;       // Data Ready Out
   wire                            data_vld_out;       // Data Valid Out
   wire                            data_last_out;      // Data Last Out
   wire   [AXI_DBUS_WD -1:0]       data_out;           // Data
  // ===============================================================================================

  // ===============================================================================================
  // ==================  Internal signals  declarations  ========================
  // ===============================================================================================
   reg [AXI_DBUS_WD -1 :0]           shift_data_d;
   wire                              stall_required;
   wire [LS :0]                      resp_size_in_bytes;
   reg  [LS :0]                      latchd_resp_size_in_bytes;
   wire [BW -1 :0]                   next_remain_byte_cnt;
   reg  [BW -1 :0]                   remain_byte_cnt;
   reg  [LS -1 :0]                   shifted_byte_cnt;
   wire [LS -1 :0]                   next_shifted_byte_cnt;
   reg                               resp_in_progress;

   reg                               latchd_data_last_in;
   reg                               latchd_stall_required;
   wire                              resp_in_one_cycle;
   wire                              all_data_shifted_out;
   wire  [LS :0]                     start_shift_cnt;
   reg   [PW -1:0]                   latchd_params_in;         // Extra Parameters Out
   reg  [AXI_ADDR_OFSET_WD -1:0]     latchd_addr_in;           // Address In
   reg   [SW -1:0]                   latchd_size_in;           // Size In
   reg  [AXI_DBUS_WD -1:0]           latchd_data_in;
   reg                               shift_data_valid;
   reg                               last_shift;
   reg                               start_overflow;

   wire [AXI_DBUS_WD -1:0]           v_data_in;            // Data In

   wire [6:0]                        tmp_addr_in;
   wire [AXI_DBUS_WD -1 :0]          valid_latchd_data;
   wire [(2*AXI_DBUS_WD) -1 :0]      tmp_cat_data;
   wire [2:0]                        params_out_cpl_stat;
   wire                              params_out_to;
  // ===============================================================================================


  // New Design start
  // ===============================================================================================
   assign v_data_in = data_vld_in ? data_in : assm_parity_data({AXI_DBUS_WD-SS{1'b0}}, {NS{PM}});


  // ===============================================================================================
  // Control section
  // ===============================================================================================

  // latch the information at the every load of the shift register
  always@(posedge clk or negedge rst_n)
   if(~rst_n) begin
      latchd_data_last_in <= # TP 1'b0;
   end else if (!init_n) begin
      latchd_data_last_in <= # TP 1'b0;
   end else if (data_vld_in && data_rdy_out) begin
      latchd_data_last_in <= # TP data_last_in;
   end else if (data_vld_out && data_rdy_in && data_last_out ) begin
      latchd_data_last_in <= # TP 1'b0;
   end

  // latch the information at the begining of a burst
  always@(posedge clk or negedge rst_n)
   if(~rst_n) begin
      latchd_addr_in <= # TP 'd0;
      latchd_params_in <= # TP 'd0;
      latchd_stall_required <= # TP 1'b0;
      latchd_size_in <= # TP 'd0;
      latchd_resp_size_in_bytes <= # TP 'd0;
   end else if (!init_n) begin
      latchd_addr_in <= # TP 'd0;
      latchd_params_in <= # TP 'd0;
      latchd_stall_required <= # TP 1'b0;
      latchd_size_in <= # TP 'd0;
      latchd_resp_size_in_bytes <= # TP 'd0;
   end else if (data_vld_in && data_rdy_out && !resp_in_progress) begin
      latchd_addr_in <= # TP addr_in;
      latchd_params_in <= # TP params_in;
      latchd_stall_required <= # TP stall_required;
      latchd_size_in <= # TP size_in;
      latchd_resp_size_in_bytes <= # TP resp_size_in_bytes;
   end
  // When the size of the read request does not match the data bus width, then we may require to stall the GIF interface
  assign resp_size_in_bytes = (1'b1 << size_in);

  // when read request size is less than the response's total size;
  //assign resp_in_one_cycle  = ((burst_len_in  + addr_in[LS -1 :0]) <= resp_size_in_bytes) ;
  assign resp_in_one_cycle  = (burst_len_in == 0);

  // Decide where or not we need to shift in a data and stall the input cycle before all data has been shifted out
  assign stall_required  = (resp_size_in_bytes < NS) && !resp_in_one_cycle;

  // Design a counter to keep track of whether or not all data has been shifted out
  always@(posedge clk or negedge rst_n)
  if(~rst_n)
     shifted_byte_cnt <= # TP {LS{1'b0}};
  else if (!init_n)
     shifted_byte_cnt <= # TP {LS{1'b0}};
  else if (data_vld_out && data_rdy_in )
     shifted_byte_cnt <= # TP next_shifted_byte_cnt;

  // spyglass disable_block W164a
  // SMD: Identifies assignments in which the LHS width is less than the RHS width
  // SJ: The rule reports assignments where the result of an addition or subtraction operation is being assigned to a bus of the same width as the operands of the addition or subtraction operation. In this code, the value of the operands is never large enough to cause overflow.
  assign next_shifted_byte_cnt =  resp_in_progress ? (shifted_byte_cnt + latchd_resp_size_in_bytes[LS-1:0]) : start_shift_cnt[LS -1 :0];
  // spyglass enable_block W164a

  generate
  if ((IS_DBI==1) || (`CC_SLV_NW==1))
  begin : generate_strt_of_NW1
    always@(posedge clk or negedge rst_n)
    begin: start_overflow_PROC
      if(~rst_n)
        start_overflow <= # TP 1'b0;
      else if (!init_n)
        start_overflow <= # TP 1'b0;
      else if (!resp_in_progress )
        //start_overflow <= start_shift_cnt[LS] && (|start_shift_cnt[LS -1 :0]);
      start_overflow <= # TP 1'b0;
      else if (resp_in_progress && data_vld_in && data_rdy_out )
        start_overflow <= # TP 1'b0;
    end
  end
  endgenerate

  generate
  if ((IS_DBI==0) && (`CC_SLV_NW>1))
  begin : generate_strt_of_NW2_4_8
    always@(posedge clk or negedge rst_n)
    begin
      if(~rst_n)
        start_overflow <= # TP 1'b0;
      else if (!init_n)
        start_overflow <= # TP 1'b0;
      else if (!resp_in_progress )
        //start_overflow <= start_shift_cnt[LS] && (|start_shift_cnt[LS -1 :0]);
      start_overflow <= # TP start_shift_cnt[LS] ;
      else if (resp_in_progress && data_vld_in && data_rdy_out )
        start_overflow <= # TP 1'b0;
    end
  end
  endgenerate

  reg latchd_data_not_valid;

  generate
  if ((IS_DBI==0) && (`CC_SLV_NW==4))
  begin : gen_latchd_data_not_valid_NW4
    always@(posedge clk or negedge rst_n)
    begin
      if(~rst_n)
        latchd_data_not_valid <= # TP 1'b0;
      else if (!init_n)
        latchd_data_not_valid <= # TP 1'b0;
      else if (!resp_in_progress )
        latchd_data_not_valid <= # TP ((addr_in[3:2] == 2'b10) && (size_in == 3'b001)) ; // 2bytes size with address offsetted by 8
      else if (resp_in_progress && data_vld_in && data_rdy_out )
        latchd_data_not_valid <= # TP 1'b0;
    end
  end
  endgenerate

  generate
  if ((IS_DBI==0) && (`CC_SLV_NW==8))
  begin : gen_latchd_data_not_valid_NW8
    always@(posedge clk or negedge rst_n)
    begin
      if(~rst_n)
        latchd_data_not_valid <= # TP 1'b0;
      else if (!resp_in_progress )
        latchd_data_not_valid <= # TP ((addr_in[4:2] == 3'b010) && (size_in == 3'b001)) ; // 2bytes size with address offsetted by 8
      else if (resp_in_progress && data_vld_in && data_rdy_out )
        latchd_data_not_valid <= # TP 1'b0;
    end
  end
  endgenerate

  generate
  if ((IS_DBI==0) && (`CC_SLV_NW==16))
  begin : gen_latchd_data_not_valid_NW16
    always@(posedge clk or negedge rst_n)
    begin
      if(~rst_n)
        latchd_data_not_valid <= # TP 1'b0;
      else if (!resp_in_progress )
        latchd_data_not_valid <= # TP ((addr_in[5:2] == 4'b0010) && (size_in == 3'b001)) ; // 2bytes size with address offsetted by 8
      else if (resp_in_progress && data_vld_in && data_rdy_out )
        latchd_data_not_valid <= # TP 1'b0;
    end
  end
  endgenerate

  generate
  if ((IS_DBI==0) && (`CC_SLV_NW==32))
  begin : gen_latchd_data_not_valid_NW32
    always@(posedge clk or negedge rst_n)
    begin
      if(~rst_n)
        latchd_data_not_valid <= # TP 1'b0;
      else if (!resp_in_progress )
        latchd_data_not_valid <= # TP ((addr_in[6:2] == 5'b00010) && (size_in == 3'b001)) ; // 2bytes size with address offsetted by 8
      else if (resp_in_progress && data_vld_in && data_rdy_out )
        latchd_data_not_valid <= # TP 1'b0;
    end
  end
  endgenerate

  generate
  if ((IS_DBI==1) || (`CC_SLV_NW==1))
  begin : gen_shift_data_valid_NW1
    always@(posedge clk or negedge rst_n)
    begin
      if(~rst_n)
        shift_data_valid <= # TP 1'b0;
      else if (!init_n)
        shift_data_valid <= # TP 1'b0;
      else if (data_vld_in && data_rdy_out && ((resp_in_progress && (remain_byte_cnt != 0)) | (!start_shift_cnt[2] && !resp_in_one_cycle && !resp_in_progress)))
        shift_data_valid <= # TP 1'b1;
      else if (((last_shift  && resp_in_progress) || data_last_out) && data_vld_out && data_rdy_in)
        shift_data_valid <= # TP 1'b0;
    end
  end
  endgenerate

  generate
  if ((IS_DBI==0) && (`CC_SLV_NW>1))
  begin : gen_shift_data_valid_NW2_4_8
    always@(posedge clk or negedge rst_n)
    begin
      if(~rst_n)
        shift_data_valid <= # TP 1'b0;
      else if (!init_n)
        shift_data_valid <= # TP 1'b0;
      else if ((data_vld_in && data_rdy_out) || (last_shift && latchd_data_last_in) || (start_overflow && data_vld_out && data_rdy_in && data_vld_in && !latchd_data_last_in))
        shift_data_valid <= # TP 1'b1;
      else if (((last_shift  && resp_in_progress) || data_last_out || (start_overflow && !data_vld_in && !latchd_data_last_in)) && data_vld_out && data_rdy_in)
        shift_data_valid <= # TP 1'b0;
    end
  end
  endgenerate

 // Design a count to keep track of how many bytes have left for a burst, this will last until the last byte shifted out AXI bus
  always@(posedge clk or negedge rst_n)
   if(~rst_n)
      remain_byte_cnt <= # TP {BW{1'b0}};
   else if (!init_n)
      remain_byte_cnt <= # TP {BW{1'b0}};
   else if (data_vld_out && data_last_out && data_rdy_in)
      remain_byte_cnt <= # TP {BW{1'b0}};
   else if (data_vld_out && data_rdy_in)
      remain_byte_cnt <= # TP next_remain_byte_cnt;

  assign next_remain_byte_cnt = resp_in_progress ? (remain_byte_cnt - 1) : burst_len_in -1;

 // a flag to identify the last shift
  // When a burst started, it will shift to the low address of dword amount; PCIe core completion has already done dword alignment
  // spyglass disable_block W164a
  // SMD: Identifies assignments in which the LHS width is less than the RHS width
  // SJ: The rule reports assignments where the result of an addition or subtraction operation is being assigned to a bus of the same width as the operands of the addition or subtraction operation. In this code, the value of the operands is never large enough to cause overflow.
  assign start_shift_cnt = ({1'b0, addr_in[LS -1 : 0]} + resp_size_in_bytes);
  // spyglass enable_block W164a

generate
if ((IS_DBI==0) && (`CC_SLV_NW==32))
begin : gen_last_shift_NW32
  always@(shifted_byte_cnt or latchd_size_in)
  begin
         case (latchd_size_in)
         3'h0:
             last_shift = &shifted_byte_cnt;
         3'h1:
             last_shift = &shifted_byte_cnt[LS -1 :1];
         3'h2:
             last_shift = &shifted_byte_cnt[LS -1 :2];
         3'h3:
             last_shift = &shifted_byte_cnt[LS -1 :3];
         3'h4:
             last_shift = &shifted_byte_cnt[LS -1 :4];
         3'h5:
             last_shift = &shifted_byte_cnt[LS -1 :5];
         3'h6:
             last_shift = &shifted_byte_cnt[LS -1 :6];
         default:
             last_shift = 1'b1;
         endcase
  end
end
endgenerate

generate
if ((IS_DBI==0) && (`CC_SLV_NW==16))
begin : gen_last_shift_NW16
  always@(shifted_byte_cnt or latchd_size_in)
  begin
         case (latchd_size_in)
         3'h0:
             last_shift = &shifted_byte_cnt;
         3'h1:
             last_shift = &shifted_byte_cnt[LS -1 :1];
         3'h2:
             last_shift = &shifted_byte_cnt[LS -1 :2];
         3'h3:
             last_shift = &shifted_byte_cnt[LS -1 :3];
         3'h4:
             last_shift = &shifted_byte_cnt[LS -1 :4];
         3'h5:
             last_shift = &shifted_byte_cnt[LS -1 :5];
         default:
             last_shift = 1'b1;
         endcase
  end
end
endgenerate

generate
if ((IS_DBI==0) && (`CC_SLV_NW==8))
begin : gen_last_shift_NW8
  always@(shifted_byte_cnt or latchd_size_in)
  begin
         case (latchd_size_in)
         3'h0:
             last_shift = &shifted_byte_cnt;
         3'h1:
             last_shift = &shifted_byte_cnt[LS -1 :1];
         3'h2:
             last_shift = &shifted_byte_cnt[LS -1 :2];
         3'h3:
             last_shift = &shifted_byte_cnt[LS -1 :3];
         3'h4:
             last_shift = &shifted_byte_cnt[LS -1 :4];
         default:
             last_shift = 1'b1;
         endcase
  end
end
endgenerate

generate
if ((IS_DBI==0) && (`CC_SLV_NW==4))
begin : gen_last_shift_NW4
  always@(shifted_byte_cnt or latchd_size_in)
  begin
         case (latchd_size_in)
         3'h0:
             last_shift = &shifted_byte_cnt;
         3'h1:
             last_shift = &shifted_byte_cnt[LS -1 :1];
         3'h2:
             last_shift = &shifted_byte_cnt[LS -1 :2];
         3'h3:
             last_shift = &shifted_byte_cnt[LS -1 :3];
         default:
             last_shift = 1'b1;
         endcase
  end
end
endgenerate
// This is not a support bus width

generate
if ((IS_DBI==0) && (`CC_SLV_NW==2))
begin : gen_last_shift_NW2
  always@(shifted_byte_cnt or latchd_size_in)
  begin
         case (latchd_size_in)
         3'h0:
             last_shift = &shifted_byte_cnt;
         3'h1:
             last_shift = &shifted_byte_cnt[LS -1 :1];
         3'h2:
             last_shift = &shifted_byte_cnt[LS -1 :2];
         default:
             last_shift = 1'b1;
         endcase
  end
end
endgenerate

generate
if ((IS_DBI==1) || (`CC_SLV_NW==1))
begin : gen_last_shift_NW1
  always@(shifted_byte_cnt or latchd_size_in or resp_in_progress or start_shift_cnt)
  begin
      if (!resp_in_progress)
         last_shift =  start_shift_cnt[2];
      else
         case (latchd_size_in)
         3'h0:
             last_shift = &shifted_byte_cnt;
         3'h1:
             last_shift = &shifted_byte_cnt[1];
         default:
             last_shift = 1'b1;
         endcase
  end
end
endgenerate

  assign all_data_shifted_out   = (last_shift || (remain_byte_cnt == 0)) && resp_in_progress ;

// state bit design
  always@(posedge clk or negedge rst_n)
  if(~rst_n)
     resp_in_progress <= # TP 1'b0;
  else if (!init_n)
     resp_in_progress <= # TP 1'b0;
  else if (data_vld_out && data_last_out && data_rdy_in)
     resp_in_progress <= # TP 1'b0;
  else if (data_vld_in && data_rdy_out && !resp_in_progress)
     resp_in_progress <= # TP 1'b1;

  // Output to stall the GIF interface
  assign data_rdy_out   = (data_rdy_in && (all_data_shifted_out || start_overflow || !shift_data_valid) && !latchd_data_last_in && resp_in_progress)
                           || (data_rdy_in && !resp_in_progress);  // when it is last shift, we can load shift register again only when no extra cycle at the last of a transfer

  // Output to control the valid cycle time
  assign data_vld_out   = (data_vld_in && !resp_in_progress)
                          || (resp_in_progress && !latchd_stall_required && (data_vld_in | ((remain_byte_cnt == 0) && latchd_data_last_in)))  // there could be an extra in unstal led case
                          || (resp_in_progress && latchd_stall_required && ((shift_data_valid && !(start_overflow && !data_vld_in && !latchd_data_last_in))
                          || (data_vld_in & !shift_data_valid)));

  // Output to control the valid last cycle time
  assign data_last_out  = ((remain_byte_cnt == 0) && resp_in_progress) || (!resp_in_progress && (burst_len_in == 0));
  // Output data bus formation
  // ================ loading the shift registers ================

  generate
  if ((IS_DBI==0) && (`CC_SLV_NW==2))
  begin : gen_latch_data_in_NW2
    always@(posedge clk or negedge rst_n)
    begin
      if(~rst_n) begin
        latchd_data_in <= # TP assm_parity_data({AXI_DBUS_WD-SS{1'b0}}, {NS{PM}});
      end else if (!init_n) begin
        latchd_data_in <= # TP assm_parity_data({AXI_DBUS_WD-SS{1'b0}}, {NS{PM}});
      end else if ((data_vld_in && data_rdy_out) || (start_overflow && !latchd_data_last_in && data_vld_in && data_rdy_in)) begin
        latchd_data_in <= # TP v_data_in;
      end
    end
  end
  endgenerate

  generate
  if ((IS_DBI==1) || (`CC_SLV_NW!=2))
  begin : gen_latch_data_in_NW1_4_8_16
    always@(posedge clk or negedge rst_n)
    begin
      if(~rst_n) begin
        latchd_data_in <= # TP assm_parity_data({AXI_DBUS_WD-SS{1'b0}}, {NS{PM}});
      end else if (!init_n) begin
        latchd_data_in <= # TP assm_parity_data({AXI_DBUS_WD-SS{1'b0}}, {NS{PM}});
      end else if (data_vld_in && data_rdy_out) begin
        latchd_data_in <= # TP v_data_in;
      end
    end
  end
  endgenerate


  reg [AXI_DBUS_WD -1 :0]           int_shift_data;

generate
if (`CC_SLV_NW==32)
begin : gen_int_shift_data_NW32

  assign tmp_addr_in  = (!resp_in_progress) ? addr_in[6:0] : latchd_addr_in[6:0];

  assign valid_latchd_data = ((!resp_in_progress || (start_overflow && latchd_data_not_valid)) ? v_data_in : latchd_data_in);

  assign tmp_cat_data = {v_data_in, valid_latchd_data};


  always@(*)
  begin
     case (tmp_addr_in[6:2])
     5'b00000:
        int_shift_data  = tmp_cat_data[ (2*AXI_DBUS_WD) -1 : AXI_DBUS_WD];
     5'b00001:
        int_shift_data  = tmp_cat_data[((2*AXI_DBUS_WD) - (4*DATA_BYTE_WD_W_PARITY) -1) : AXI_DBUS_WD - (4*DATA_BYTE_WD_W_PARITY)];
     5'b00010:
        int_shift_data  = tmp_cat_data[((2*AXI_DBUS_WD) - (8*DATA_BYTE_WD_W_PARITY) -1) : AXI_DBUS_WD - (8*DATA_BYTE_WD_W_PARITY)];
     5'b00011:
        int_shift_data  = tmp_cat_data[((2*AXI_DBUS_WD) - (12*DATA_BYTE_WD_W_PARITY) -1) : AXI_DBUS_WD - (12*DATA_BYTE_WD_W_PARITY)];
     5'b00100:
        int_shift_data  = tmp_cat_data[((2*AXI_DBUS_WD) - (16*DATA_BYTE_WD_W_PARITY) -1) : AXI_DBUS_WD - (16*DATA_BYTE_WD_W_PARITY)];
     5'b00101:
        int_shift_data  = tmp_cat_data[((2*AXI_DBUS_WD) - (20*DATA_BYTE_WD_W_PARITY) -1) : AXI_DBUS_WD - (20*DATA_BYTE_WD_W_PARITY)];
     5'b00110:
        int_shift_data  = tmp_cat_data[((2*AXI_DBUS_WD) - (24*DATA_BYTE_WD_W_PARITY) -1) : AXI_DBUS_WD - (24*DATA_BYTE_WD_W_PARITY)];
     5'b00111:
        int_shift_data  = tmp_cat_data[((2*AXI_DBUS_WD) - (28*DATA_BYTE_WD_W_PARITY) -1) : AXI_DBUS_WD - (28*DATA_BYTE_WD_W_PARITY)];
     5'b01000:
        int_shift_data  = tmp_cat_data[((2*AXI_DBUS_WD) - (32*DATA_BYTE_WD_W_PARITY) -1) : AXI_DBUS_WD - (32*DATA_BYTE_WD_W_PARITY)];
     5'b01001:
        int_shift_data  = tmp_cat_data[((2*AXI_DBUS_WD) - (36*DATA_BYTE_WD_W_PARITY) -1) : AXI_DBUS_WD - (36*DATA_BYTE_WD_W_PARITY)];
     5'b01010:
        int_shift_data  = tmp_cat_data[((2*AXI_DBUS_WD) - (40*DATA_BYTE_WD_W_PARITY) -1) : AXI_DBUS_WD - (40*DATA_BYTE_WD_W_PARITY)];
     5'b01011:
        int_shift_data  = tmp_cat_data[((2*AXI_DBUS_WD) - (44*DATA_BYTE_WD_W_PARITY) -1) : AXI_DBUS_WD - (44*DATA_BYTE_WD_W_PARITY)];
     5'b01100:
        int_shift_data  = tmp_cat_data[((2*AXI_DBUS_WD) - (48*DATA_BYTE_WD_W_PARITY) -1) : AXI_DBUS_WD - (48*DATA_BYTE_WD_W_PARITY)];
     5'b01101:
        int_shift_data  = tmp_cat_data[((2*AXI_DBUS_WD) - (52*DATA_BYTE_WD_W_PARITY) -1) : AXI_DBUS_WD - (52*DATA_BYTE_WD_W_PARITY)];
     5'b01110:
        int_shift_data  = tmp_cat_data[((2*AXI_DBUS_WD) - (56*DATA_BYTE_WD_W_PARITY) -1) : AXI_DBUS_WD - (56*DATA_BYTE_WD_W_PARITY)];
     5'b01111:
        int_shift_data  = tmp_cat_data[((2*AXI_DBUS_WD) - (60*DATA_BYTE_WD_W_PARITY) -1) : AXI_DBUS_WD - (60*DATA_BYTE_WD_W_PARITY)];
     5'b10000:
        int_shift_data  = tmp_cat_data[((2*AXI_DBUS_WD) - (64*DATA_BYTE_WD_W_PARITY) -1) : AXI_DBUS_WD - (64*DATA_BYTE_WD_W_PARITY)];
     5'b10001:
        int_shift_data  = tmp_cat_data[((2*AXI_DBUS_WD) - (68*DATA_BYTE_WD_W_PARITY) -1) : AXI_DBUS_WD - (68*DATA_BYTE_WD_W_PARITY)];
     5'b10010:
        int_shift_data  = tmp_cat_data[((2*AXI_DBUS_WD) - (72*DATA_BYTE_WD_W_PARITY) -1) : AXI_DBUS_WD - (72*DATA_BYTE_WD_W_PARITY)];
     5'b10011:
        int_shift_data  = tmp_cat_data[((2*AXI_DBUS_WD) - (76*DATA_BYTE_WD_W_PARITY) -1) : AXI_DBUS_WD - (76*DATA_BYTE_WD_W_PARITY)];
     5'b10100:
        int_shift_data  = tmp_cat_data[((2*AXI_DBUS_WD) - (80*DATA_BYTE_WD_W_PARITY) -1) : AXI_DBUS_WD - (80*DATA_BYTE_WD_W_PARITY)];
     5'b10101:
        int_shift_data  = tmp_cat_data[((2*AXI_DBUS_WD) - (84*DATA_BYTE_WD_W_PARITY) -1) : AXI_DBUS_WD - (84*DATA_BYTE_WD_W_PARITY)];
     5'b10110:
        int_shift_data  = tmp_cat_data[((2*AXI_DBUS_WD) - (88*DATA_BYTE_WD_W_PARITY) -1) : AXI_DBUS_WD - (88*DATA_BYTE_WD_W_PARITY)];
     5'b10111:
        int_shift_data  = tmp_cat_data[((2*AXI_DBUS_WD) - (92*DATA_BYTE_WD_W_PARITY) -1) : AXI_DBUS_WD - (92*DATA_BYTE_WD_W_PARITY)];
     5'b11000:
        int_shift_data  = tmp_cat_data[((2*AXI_DBUS_WD) - (96*DATA_BYTE_WD_W_PARITY) -1) : AXI_DBUS_WD - (96*DATA_BYTE_WD_W_PARITY)];
     5'b11001:
        int_shift_data  = tmp_cat_data[((2*AXI_DBUS_WD) - (100*DATA_BYTE_WD_W_PARITY) -1) : AXI_DBUS_WD - (100*DATA_BYTE_WD_W_PARITY)];
     5'b11010:
        int_shift_data  = tmp_cat_data[((2*AXI_DBUS_WD) - (104*DATA_BYTE_WD_W_PARITY) -1) : AXI_DBUS_WD - (104*DATA_BYTE_WD_W_PARITY)];
     5'b11011:
        int_shift_data  = tmp_cat_data[((2*AXI_DBUS_WD) - (108*DATA_BYTE_WD_W_PARITY) -1) : AXI_DBUS_WD - (108*DATA_BYTE_WD_W_PARITY)];
     5'b11100:
        int_shift_data  = tmp_cat_data[((2*AXI_DBUS_WD) - (112*DATA_BYTE_WD_W_PARITY) -1) : AXI_DBUS_WD - (112*DATA_BYTE_WD_W_PARITY)];
     5'b11101:
        int_shift_data  = tmp_cat_data[((2*AXI_DBUS_WD) - (116*DATA_BYTE_WD_W_PARITY) -1) : AXI_DBUS_WD - (116*DATA_BYTE_WD_W_PARITY)];
     5'b11110:
        int_shift_data  = tmp_cat_data[((2*AXI_DBUS_WD) - (120*DATA_BYTE_WD_W_PARITY) -1) : AXI_DBUS_WD - (120*DATA_BYTE_WD_W_PARITY)];
     5'b11111:
         int_shift_data  = tmp_cat_data[((2*AXI_DBUS_WD) - (124*DATA_BYTE_WD_W_PARITY) -1) : AXI_DBUS_WD - (124*DATA_BYTE_WD_W_PARITY)];
     default:
        int_shift_data  = tmp_cat_data[ (2*AXI_DBUS_WD) -1 : AXI_DBUS_WD];
     endcase
  end

end
endgenerate

generate
if (`CC_SLV_NW==16)
begin : gen_int_shift_data_NW16

  assign tmp_addr_in  = (!resp_in_progress) ? (7)'(addr_in[5:0]) : (7)'(latchd_addr_in[5:0]);

  assign valid_latchd_data = ((!resp_in_progress || (start_overflow && latchd_data_not_valid)) ? v_data_in : latchd_data_in);

  assign tmp_cat_data = {v_data_in, valid_latchd_data};


  always@(*)
  begin
     case (tmp_addr_in[5:2])
     4'b0000:
        int_shift_data  = tmp_cat_data[ (2*AXI_DBUS_WD) -1 : AXI_DBUS_WD];
     4'b0001:
        int_shift_data  = tmp_cat_data[((2*AXI_DBUS_WD) - (4*DATA_BYTE_WD_W_PARITY) -1) : AXI_DBUS_WD - (4*DATA_BYTE_WD_W_PARITY)];
     4'b0010:
        int_shift_data  = tmp_cat_data[((2*AXI_DBUS_WD) - (8*DATA_BYTE_WD_W_PARITY) -1) : AXI_DBUS_WD - (8*DATA_BYTE_WD_W_PARITY)];
     4'b0011:
        int_shift_data  = tmp_cat_data[((2*AXI_DBUS_WD) - (12*DATA_BYTE_WD_W_PARITY) -1) : AXI_DBUS_WD - (12*DATA_BYTE_WD_W_PARITY)];
     4'b0100:
        int_shift_data  = tmp_cat_data[((2*AXI_DBUS_WD) - (16*DATA_BYTE_WD_W_PARITY) -1) : AXI_DBUS_WD - (16*DATA_BYTE_WD_W_PARITY)];
     4'b0101:
        int_shift_data  = tmp_cat_data[((2*AXI_DBUS_WD) - (20*DATA_BYTE_WD_W_PARITY) -1) : AXI_DBUS_WD - (20*DATA_BYTE_WD_W_PARITY)];
     4'b0110:
        int_shift_data  = tmp_cat_data[((2*AXI_DBUS_WD) - (24*DATA_BYTE_WD_W_PARITY) -1) : AXI_DBUS_WD - (24*DATA_BYTE_WD_W_PARITY)];
     4'b0111:
        int_shift_data  = tmp_cat_data[((2*AXI_DBUS_WD) - (28*DATA_BYTE_WD_W_PARITY) -1) : AXI_DBUS_WD - (28*DATA_BYTE_WD_W_PARITY)];
     4'b1000:
        int_shift_data  = tmp_cat_data[((2*AXI_DBUS_WD) - (32*DATA_BYTE_WD_W_PARITY) -1) : AXI_DBUS_WD - (32*DATA_BYTE_WD_W_PARITY)];
     4'b1001:
        int_shift_data  = tmp_cat_data[((2*AXI_DBUS_WD) - (36*DATA_BYTE_WD_W_PARITY) -1) : AXI_DBUS_WD - (36*DATA_BYTE_WD_W_PARITY)];
     4'b1010:
        int_shift_data  = tmp_cat_data[((2*AXI_DBUS_WD) - (40*DATA_BYTE_WD_W_PARITY) -1) : AXI_DBUS_WD - (40*DATA_BYTE_WD_W_PARITY)];
     4'b1011:
        int_shift_data  = tmp_cat_data[((2*AXI_DBUS_WD) - (44*DATA_BYTE_WD_W_PARITY) -1) : AXI_DBUS_WD - (44*DATA_BYTE_WD_W_PARITY)];
     4'b1100:
        int_shift_data  = tmp_cat_data[((2*AXI_DBUS_WD) - (48*DATA_BYTE_WD_W_PARITY) -1) : AXI_DBUS_WD - (48*DATA_BYTE_WD_W_PARITY)];
     4'b1101:
        int_shift_data  = tmp_cat_data[((2*AXI_DBUS_WD) - (52*DATA_BYTE_WD_W_PARITY) -1) : AXI_DBUS_WD - (52*DATA_BYTE_WD_W_PARITY)];
     4'b1110:
        int_shift_data  = tmp_cat_data[((2*AXI_DBUS_WD) - (56*DATA_BYTE_WD_W_PARITY) -1) : AXI_DBUS_WD - (56*DATA_BYTE_WD_W_PARITY)];
     4'b1111:
        int_shift_data  = tmp_cat_data[((2*AXI_DBUS_WD) - (60*DATA_BYTE_WD_W_PARITY) -1) : AXI_DBUS_WD - (60*DATA_BYTE_WD_W_PARITY)];
     default:
        int_shift_data  = tmp_cat_data[ (2*AXI_DBUS_WD) -1 : AXI_DBUS_WD];
     endcase
  end

end
endgenerate

generate
if (`CC_SLV_NW==8)
begin : gen_int_shift_data_NW8

  assign tmp_addr_in  = (!resp_in_progress) ? (7)'(addr_in[4:0]) : (7)'(latchd_addr_in[4:0]);

  assign valid_latchd_data = ((!resp_in_progress || (start_overflow && latchd_data_not_valid)) ? v_data_in : latchd_data_in);

  assign tmp_cat_data = {v_data_in, valid_latchd_data};


  always@(*)
  begin
     case (tmp_addr_in[4:2])
     3'b000:
        int_shift_data  = tmp_cat_data[(2*AXI_DBUS_WD) -1 : AXI_DBUS_WD];
     3'b001:
        int_shift_data  = tmp_cat_data[((2*AXI_DBUS_WD) - (4*DATA_BYTE_WD_W_PARITY) -1) : AXI_DBUS_WD - (4*DATA_BYTE_WD_W_PARITY)];
     3'b010:
        int_shift_data  = tmp_cat_data[((2*AXI_DBUS_WD) - (8*DATA_BYTE_WD_W_PARITY) -1) : AXI_DBUS_WD - (8*DATA_BYTE_WD_W_PARITY)];
     3'b011:
        int_shift_data  = tmp_cat_data[((2*AXI_DBUS_WD) - (12*DATA_BYTE_WD_W_PARITY) -1) : AXI_DBUS_WD - (12*DATA_BYTE_WD_W_PARITY)];
     3'b100:
        int_shift_data  = tmp_cat_data[((2*AXI_DBUS_WD) - (16*DATA_BYTE_WD_W_PARITY) -1) : AXI_DBUS_WD - (16*DATA_BYTE_WD_W_PARITY)];
     3'b101:
        int_shift_data  = tmp_cat_data[((2*AXI_DBUS_WD) - (20*DATA_BYTE_WD_W_PARITY) -1) : AXI_DBUS_WD - (20*DATA_BYTE_WD_W_PARITY)];
     3'b110:
        int_shift_data  = tmp_cat_data[((2*AXI_DBUS_WD) - (24*DATA_BYTE_WD_W_PARITY) -1) : AXI_DBUS_WD - (24*DATA_BYTE_WD_W_PARITY)];
     3'b111:
        int_shift_data  = tmp_cat_data[((2*AXI_DBUS_WD) - (28*DATA_BYTE_WD_W_PARITY) -1) : AXI_DBUS_WD - (28*DATA_BYTE_WD_W_PARITY)];
     default:
        int_shift_data  = tmp_cat_data[(2*AXI_DBUS_WD) -1 : AXI_DBUS_WD];
     endcase
  end


end
endgenerate

generate
if ((IS_DBI==0) && (`CC_SLV_NW==4))
begin : gen_int_shift_data_NW4

  assign tmp_addr_in  = (!resp_in_progress) ? (7)'(addr_in[3:0]) : (7)'(latchd_addr_in[3:0]);

  assign valid_latchd_data = ((!resp_in_progress || (start_overflow && latchd_data_not_valid)) ? v_data_in : latchd_data_in);


  assign tmp_cat_data = {v_data_in, valid_latchd_data};

  always@(*)
  begin
     case (tmp_addr_in[3:2])
     2'b00:
        int_shift_data  = tmp_cat_data[(2*AXI_DBUS_WD) -1 : AXI_DBUS_WD];
     2'b01:
        int_shift_data  = tmp_cat_data[((2*AXI_DBUS_WD) - (4*DATA_BYTE_WD_W_PARITY) -1) : AXI_DBUS_WD - (4*DATA_BYTE_WD_W_PARITY)];
     2'b10:
        int_shift_data  = tmp_cat_data[((2*AXI_DBUS_WD) - (8*DATA_BYTE_WD_W_PARITY) -1) : AXI_DBUS_WD - (8*DATA_BYTE_WD_W_PARITY)];
     2'b11:
        int_shift_data  = tmp_cat_data[((2*AXI_DBUS_WD) - (12*DATA_BYTE_WD_W_PARITY) -1) : AXI_DBUS_WD - (12*DATA_BYTE_WD_W_PARITY)];
     default:
        int_shift_data  = tmp_cat_data[(2*AXI_DBUS_WD) -1 : AXI_DBUS_WD];
     endcase
  end
end
endgenerate


generate
if ((IS_DBI==0) && (`CC_SLV_NW==2))
begin : gen_int_shift_data_NW2

  assign tmp_addr_in  = (!resp_in_progress) ? (7)'(addr_in[2:0]) : (7)'(latchd_addr_in[2:0]);

  assign valid_latchd_data = (!resp_in_progress) ? v_data_in : latchd_data_in;

  assign tmp_cat_data = {v_data_in, valid_latchd_data};

  always@(*)
  begin
     if(tmp_addr_in[2])
        int_shift_data  = tmp_cat_data[((2*AXI_DBUS_WD) - (4*DATA_BYTE_WD_W_PARITY) -1) : AXI_DBUS_WD - (4*DATA_BYTE_WD_W_PARITY)];
     else
        int_shift_data  = tmp_cat_data[(2*AXI_DBUS_WD) -1 : AXI_DBUS_WD];
  end
end

endgenerate


generate
if ((IS_DBI==1) || (`CC_SLV_NW==1))
begin : gen_int_shift_data_NW1
  always@ (v_data_in)
    int_shift_data  = v_data_in;
end
endgenerate

  logic [SW -1:0]               s_size_in;
  logic [AXI_ADDR_OFSET_WD-1:0] first_beat_lower_lim;
  logic [AXI_ADDR_OFSET_WD-1:0] first_beat_upper_lim;
  logic [AXI_ADDR_OFSET_WD-1:0] inc_beat_lower_lim;
  logic [AXI_ADDR_OFSET_WD-1:0] inc_beat_upper_lim;
  logic [AXI_ADDR_OFSET_WD-1:0] upper_beat_lim;
  logic [AXI_ADDR_OFSET_WD-1:0] lower_beat_lim;
  logic [NS-1:0]                byte_valid;

  assign s_size_in = resp_in_progress ? latchd_size_in : size_in;

  assign first_beat_lower_lim = addr_in;

generate
if (`CC_SLV_NW==32)
begin : gen_first_beat_upper_lim_NW32
  always_comb begin : first_beat_upper_lim_NW32_comb_proc
    case(size_in)
      0       : first_beat_upper_lim = {addr_in[AXI_ADDR_OFSET_WD-1:0]};
      1       : first_beat_upper_lim = {addr_in[AXI_ADDR_OFSET_WD-1:1],1'h0}+1;
      2       : first_beat_upper_lim = {addr_in[AXI_ADDR_OFSET_WD-1:2],2'h0}+3;
      3       : first_beat_upper_lim = {addr_in[AXI_ADDR_OFSET_WD-1:3],3'h0}+7;
      4       : first_beat_upper_lim = {addr_in[AXI_ADDR_OFSET_WD-1:4],4'h0}+15;
      5       : first_beat_upper_lim = {addr_in[AXI_ADDR_OFSET_WD-1:5],5'h0}+31;
      6       : first_beat_upper_lim = {addr_in[AXI_ADDR_OFSET_WD-1:6],6'h0}+63;
      7       : first_beat_upper_lim =                                       127;
    endcase
  end
end
endgenerate

generate
if (`CC_SLV_NW==16)
begin : gen_first_beat_upper_lim_NW16
  always_comb begin : first_beat_upper_lim_NW16_comb_proc
    case(size_in)
      0       : first_beat_upper_lim = {addr_in[AXI_ADDR_OFSET_WD-1:0]};
      1       : first_beat_upper_lim = {addr_in[AXI_ADDR_OFSET_WD-1:1],1'h0}+1;
      2       : first_beat_upper_lim = {addr_in[AXI_ADDR_OFSET_WD-1:2],2'h0}+3;
      3       : first_beat_upper_lim = {addr_in[AXI_ADDR_OFSET_WD-1:3],3'h0}+7;
      4       : first_beat_upper_lim = {addr_in[AXI_ADDR_OFSET_WD-1:4],4'h0}+15;
      5       : first_beat_upper_lim = {addr_in[AXI_ADDR_OFSET_WD-1:5],5'h0}+31;
      6       : first_beat_upper_lim =                                       63;
      default : first_beat_upper_lim =                                       63;
    endcase
  end
end
endgenerate

generate
if (`CC_SLV_NW==8)
begin : gen_first_beat_upper_lim_NW8
  always_comb begin : first_beat_upper_lim_NW8_comb_proc
    case(size_in)
      0       : first_beat_upper_lim = {addr_in[AXI_ADDR_OFSET_WD-1:0]};
      1       : first_beat_upper_lim = {addr_in[AXI_ADDR_OFSET_WD-1:1],1'h0}+1;
      2       : first_beat_upper_lim = {addr_in[AXI_ADDR_OFSET_WD-1:2],2'h0}+3;
      3       : first_beat_upper_lim = {addr_in[AXI_ADDR_OFSET_WD-1:3],3'h0}+7;
      4       : first_beat_upper_lim = {addr_in[AXI_ADDR_OFSET_WD-1:4],4'h0}+15;
      5       : first_beat_upper_lim =                                       31;
      default : first_beat_upper_lim =                                       31;
    endcase
  end
end
endgenerate

generate
if (`CC_SLV_NW==4)
begin : gen_first_beat_upper_lim_NW4
  always_comb begin : first_beat_upper_lim_NW4_comb_proc
    case(size_in)
      0       : first_beat_upper_lim = {addr_in[AXI_ADDR_OFSET_WD-1:0]};
      1       : first_beat_upper_lim = {addr_in[AXI_ADDR_OFSET_WD-1:1],1'h0}+1;
      2       : first_beat_upper_lim = {addr_in[AXI_ADDR_OFSET_WD-1:2],2'h0}+3;
      3       : first_beat_upper_lim = {addr_in[AXI_ADDR_OFSET_WD-1:3],3'h0}+7;
      4       : first_beat_upper_lim =                                       15;
      default : first_beat_upper_lim =                                       15;
    endcase
  end
end
endgenerate

generate
if (`CC_SLV_NW==2)
begin : gen_first_beat_upper_lim_NW2
  always_comb begin : first_beat_upper_lim_NW2_comb_proc
    case(size_in)
      0       : first_beat_upper_lim = {addr_in[AXI_ADDR_OFSET_WD-1:0]};
      1       : first_beat_upper_lim = {addr_in[AXI_ADDR_OFSET_WD-1:1],1'h0}+1;
      2       : first_beat_upper_lim = {addr_in[AXI_ADDR_OFSET_WD-1:2],2'h0}+3;
      3       : first_beat_upper_lim =                                       7;
      default : first_beat_upper_lim =                                       7;
    endcase
  end
end
endgenerate

generate
if (`CC_SLV_NW==1)
begin : gen_first_beat_upper_lim_NW1
  always_comb begin : first_beat_upper_lim_NW1_comb_proc
    case(size_in)
      0       : first_beat_upper_lim = {addr_in[AXI_ADDR_OFSET_WD-1:0]};
      1       : first_beat_upper_lim = {addr_in[AXI_ADDR_OFSET_WD-1:1],1'h0}+1;
      2       : first_beat_upper_lim =                                       3;
      default : first_beat_upper_lim =                                       3;
    endcase
  end
end
endgenerate


  always@(posedge clk or negedge rst_n) begin : inc_beat_lim_seq_proc
    if(~rst_n) begin
      inc_beat_lower_lim <= # TP '0;
      inc_beat_upper_lim <= # TP '0;
    end else if (!init_n) begin
      inc_beat_lower_lim <= # TP '0;
      inc_beat_upper_lim <= # TP '0;
    end else if (data_vld_out && data_rdy_in ) begin
      inc_beat_lower_lim <= # TP upper_beat_lim + 1;
      inc_beat_upper_lim <= # TP upper_beat_lim + (1 << s_size_in);
    end
  end

  assign lower_beat_lim = resp_in_progress ? inc_beat_lower_lim : first_beat_lower_lim;
  assign upper_beat_lim = resp_in_progress ? inc_beat_upper_lim : first_beat_upper_lim;
    
  always_comb begin : byte_valid_comb_proc
    integer i;
    
    byte_valid = '0;
    
    for(i=0;i<NS;i=i+1)
      byte_valid[i] = (i>=lower_beat_lim) && (i<=upper_beat_lim);

  end    
    
  logic [AXI_DBUS_WD -1 :0]           s_data_out;
  logic [AXI_DBUS_WD -1 :0]           int_data_out;

  assign int_data_out        = (latchd_stall_required && resp_in_progress && shift_data_valid) ? shift_data_d : int_shift_data;

  always_comb begin : s_data_out_comb_proc
    integer i;
    
    s_data_out = assm_parity_data({AXI_DBUS_WD-SS{1'b0}}, {NS{PM}});
    for(i=0;i<NS;i=i+1)
      if(byte_valid[i])begin
        s_data_out[i*DATA_BYTE_WD_W_PARITY+:DATA_BYTE_WD_W_PARITY] = int_data_out[i*DATA_BYTE_WD_W_PARITY+:DATA_BYTE_WD_W_PARITY];
      end else begin
        if(|params_out_cpl_stat || params_out_to)begin
          s_data_out[i*DATA_BYTE_WD_W_PARITY+:DATA_BYTE_WD_W_PARITY] = {PM,8'hff};
        end else begin
          s_data_out[i*DATA_BYTE_WD_W_PARITY+:DATA_BYTE_WD_W_PARITY] = {PM,8'h00};
        end
      end  

  end
  
  assign data_out = s_data_out;

  always@(posedge clk or negedge rst_n)
   if(~rst_n) begin
     shift_data_d <= # TP assm_parity_data({AXI_DBUS_WD-SS{1'b0}}, {NS{PM}});
   end else if (!init_n) begin
     shift_data_d <= # TP assm_parity_data({AXI_DBUS_WD-SS{1'b0}}, {NS{PM}});
   end else if ((data_vld_in && data_rdy_out ) || (last_shift && latchd_data_last_in && data_rdy_in) || (start_overflow && !latchd_data_last_in && data_rdy_in))
      shift_data_d <= # TP int_shift_data;


  assign params_out   = (resp_in_progress) ? latchd_params_in : params_in;
  assign params_out_cpl_stat = params_out[PARAMS_CPL_STAT_HIGH:PARAMS_CPL_STAT_LOW];
  assign params_out_to       = params_out[PARAMS_TO];

   function automatic [OS-1:0] assm_parity_data;
      input [OB-1:0]    a;      // input
      input [SS-1:0]    b;      // input
      reg [OS-1:0]      z;
      integer         i,j;
      begin
         z = {OS{1'b0}};
         for (i=0 ; i < SS ; i=i+1) begin
            for (j=0 ; j < 8 ; j=j+1) begin
               z[(i*9)+j] = a[(i*8)+j];
            end
            z[((i*9)+8)] = b[i];
         end
         assm_parity_data = z;
      end
   endfunction
  // ===============================================================================================
  // Design End
  // ===============================================================================================
endmodule

