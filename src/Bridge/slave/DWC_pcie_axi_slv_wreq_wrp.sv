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
// ---    $Id: //dwh/pcie_iip/main/fairbanks/design/Bridge/slave/DWC_pcie_axi_slv_wreq_wrp.sv#7 $
// -------------------------------------------------------------------------

`include "include/DWC_pcie_ctl_all_defs.svh"
`include "DWC_pcie_ctl_pkg.svh"


 module DWC_pcie_axi_slv_wreq_wrp
  import DWC_pcie_ctl_pkg::ras_dp_err_log_t;
  import DWC_pcie_ctl_pkg::MAX_RAS_PROT_CHK_N;
  import DWC_pcie_ctl_pkg::RAS_ERROR_LOG_WD;
  import DWC_pcie_ctl_pkg::ras_dp_err_inj_t;
 #(
    parameter SLV_BUS_ADDR_WIDTH            = 36,
    parameter SLAVE_BUS_ADDR_WIDTH          = 32,
    parameter CX_RAS_PROT_RANGE             = `CX_RAS_PROT_RANGE,
    parameter CX_RAS_PARITY_MODE            = `CX_RAS_PARITY_MODE,
    parameter SLV_BUS_ID_WIDTH              = 3,
    parameter SLV_BURST_LEN_PW              = 4,
    parameter TP                            = `TP
   )
   (
   input                                    slv_aclk,
   input                                    slv_aresetn,
   // -------------------------------------------------------------------------------------
   // AXI write request interface
   input                                    wif_valid,
   input [SLV_BUS_ADDR_WIDTH-1:0]           wif_addr,
   input [SLV_BURST_LEN_PW-1:0]             wif_len,
   input [2:0]                              wif_size,
   input [1:0]                              wif_burst,
   input                                    wif_last,
  // -------------------------------------------------------------------------------------
  // -------------------------------------------------------------------------------------
  // Address parity error interface
  output wire                               wwrp_addr_parerr,
  output ras_dp_err_log_t                   wwrp_ad_ras_dp_err_log,
    input  ras_dp_err_inj_t                    ras_dp_err_inj_slv_aclk,
   // -------------------------------------------------------------------------------------
   // Wrap partition
   output wire [SLV_BUS_ADDR_WIDTH-1:0]     wwrp_addr,
   output wire [SLV_BURST_LEN_PW-1:0]       wwrp_len,
   output wire                              wwrp_last,
   output wire                              wwrp_first_wrp_split_xact,
   output wire                              wwrp_valid,
   input                                    dwalgn_ready
   );

   // -------------------------------------------------------------------------------------
   // Local parameters

   // Burst encoding
   localparam WRAP = `WRAP;
   localparam INCR = `INCR;

   // Write Request Channel FSM's
   localparam S_RQ_INCR1 = 1'b0;
   localparam S_RQ_INCR2 = 1'b1;

  localparam ADDR_PAR_BLOCK_SIZE  = SLAVE_BUS_ADDR_WIDTH/CX_RAS_PROT_RANGE;
  localparam RAS_DP_ERR_LOG_WD = $clog2(MAX_RAS_PROT_CHK_N);

   // -------------------------------------------------------------------------------------
   // Request info
   wire [SLAVE_BUS_ADDR_WIDTH-1:0]          s_wif_addr;
   wire [SLAVE_BUS_ADDR_WIDTH-1:0]          s_wrap_bndry_wo_par;
   wire [3:0]                               s_wrap_beat_offset;

   // -------------------------------------------------------------------------------------
   // FSM states
   reg                                      r_rq_wrap_st;
   reg                                      s_rq_wrap_st;

   // -------------------------------------------------------------------------------------
   // Partitioned requests
   wire [3:0]                               s_incr1_len;
   wire [3:0]                               s_incr2_len;

   // -------------------------------------------------------------------------------------
   // Control signals
   wire                                     s_valid;
   wire                                     s_wrap_valid;
   wire                                     s_wrap_split;
   reg                                      r_incr1_sel;
   wire                                     s_incr1_last_beat;
   reg  [3:0]                               r_wrap_beat_cnt;
   reg  [3:0]                               s_wrap_beat_cnt;

   // -------------------------------------------------------------------------------------
   // Output drivers
   reg  [SLAVE_BUS_ADDR_WIDTH-1:0]          s_wwrp_addr_wo_par;
   wire [SLV_BUS_ADDR_WIDTH-1:0]            s_wwrp_addr;
   reg  [SLV_BURST_LEN_PW-1:0]              s_wwrp_len;
   reg                                      s_wwrp_last;
   reg                                      s_wwrp_first_wrp_split_xact;

   // -------------------------------------------------------------------------------------
   // Parity check
  wire                                     s_first_beat;
  reg                                      r_first_beat;
  ras_dp_err_log_t                         s_wwrp_ad_ras_dp_err_log;

   // Extract start address
   assign s_wif_addr = fn_addr_wo_par(wif_addr);

   // Wrap boundary
   assign s_wrap_bndry_wo_par = s_wif_addr &  (~({{SLAVE_BUS_ADDR_WIDTH-SLV_BURST_LEN_PW{1'b0}},wif_len} << wif_size));
   wire [SLAVE_BUS_ADDR_WIDTH-1:0] s_wif_addr_adj;
   assign s_wif_addr_adj = s_wif_addr >> wif_size;

   generate if (SLV_BURST_LEN_PW > 4) begin : BEAT_OFFSET_BURST_LEN_PW_BIGGER_THAN_4
     // Request beat offset to the wrap boundary
     assign s_wrap_beat_offset = s_wif_addr_adj[3:0] & wif_len[3:0];

     // Lenght of each split INCR transaction
     assign s_incr1_len = ~s_wrap_beat_offset & wif_len[3:0];
   end else begin : BEAT_OFFSET_BURST_LEN_PW_SMALLER_OR_EQUAL_THAN_4
     // Request beat offset to the wrap boundary
     assign s_wrap_beat_offset = s_wif_addr_adj[3:0] & {{4-SLV_BURST_LEN_PW{1'b0}}, wif_len};

     // Lenght of each split INCR transaction
     assign s_incr1_len = ~s_wrap_beat_offset & {{4-SLV_BURST_LEN_PW{1'b0}}, wif_len};
   end
   endgenerate

   assign s_incr2_len = s_wrap_beat_offset - 1'b1;

   assign s_valid = wif_valid && dwalgn_ready;

   // Wrap data beat
   assign s_wrap_valid = (wif_burst==WRAP) && s_valid;

   // Wrap detection
   assign  wwrp_valid = s_wrap_valid && s_wrap_split;

   // WRAP write data beat counter
   always @(*)
   begin : proc_comb_wrap_beat_cnt
      if (s_wrap_valid) begin
         if (wif_last)
            s_wrap_beat_cnt = 4'd0;
         else
            s_wrap_beat_cnt = r_wrap_beat_cnt + 1;
      end else begin
         s_wrap_beat_cnt = r_wrap_beat_cnt;
      end
   end

   always @(posedge slv_aclk or negedge slv_aresetn)
   begin : proc_seq_wrap_beat_cnt
      if (!slv_aresetn)
         r_wrap_beat_cnt <= # TP 4'd0;
      else
         r_wrap_beat_cnt <= # TP s_wrap_beat_cnt;
   end


   // Flag last write data beat
   assign s_incr1_last_beat = s_wrap_beat_cnt==(s_incr1_len+1);

   // Signal last wrap data beat
   assign s_wrap_last = s_wrap_valid && wif_last;



   always @(posedge slv_aclk or negedge slv_aresetn) begin : proc_seq_r_first_beat
     if (!slv_aresetn) begin
       r_first_beat <= # TP 1'b1;
     end else if (s_valid && wif_last) begin
       r_first_beat <= # TP 1'b1;
     end else if (s_valid) begin
       r_first_beat <= # TP 1'b0;
     end
   end

   assign s_first_beat = s_valid && r_first_beat;

   // Check parity for the lowest block size.
   // Parity is recalculated after the low address is modified.

  ras_dp_pipe
   #(
     .PIPELINE_TYPE             (0                         ),
     .RESETVAL                  (0                         ),
     .N_STAGES                  (0                         ),
     .CAN_STALL                 (0                         ),
     .RESET_STALL               (0                         ),
     .BUS_PROTECT_GEN_EN        (0                         ),
     .BUS_PROTECT_CHK_EN        (1                         ),
     .PROT_TYPE                 (1                         ),
     .PROT_RANGE                (CX_RAS_PROT_RANGE         ),
     .PROT_WD                   (ADDR_PAR_BLOCK_SIZE       ),
     .PARITY_MODE               (CX_RAS_PARITY_MODE        ),
     .PROT_CORRECT_EN           (0                         ),
     .TOTAL_WIDTH               (SLAVE_BUS_ADDR_WIDTH      ),
     .EXCLUDE_PROT_WIDTH        (0                         ),
     .RAS_DP_PROT_CHK_ID_BASE   (`WWRP_AD_RAS_ID           )
   ) u_addr_chk (
     .clk                       (slv_aclk                  ),
     .rst_n                     (slv_aresetn               ),
     .din                       (fn_addr_wo_par  (wif_addr)),
     .din_prot                  (fn_prot_chkin_ad(wif_addr)),
     .dout                      ( /* Not Connected */      ),
     .dout_prot                 ( /* Not Connected */      ),
     .en                        (1'b1                      ),
     .bypass                    (1'b0                      ),
     .stall                     (1'b0                      ),
     .stallout                  ( /* Not Connected */      ),
     .valid_in                  (s_first_beat              ),
     .halt_out                  ( /* Not Connected */      ),
     .valid_out                 ( /* Not Connected */      ),
     .halt_in                   (1'b0                      ),
     .ras_dp_err_inband_kbd_in  (1'b0                      ),
     .ras_dp_err_inband_kbd_out ( /* Not Connected */      ),
     .ras_dp_err_log            (s_wwrp_ad_ras_dp_err_log  )
       ,
       .ras_dp_err_inj          (ras_dp_err_inj_slv_aclk)
     );

   assign wwrp_addr_parerr = s_wwrp_ad_ras_dp_err_log.valid;
   assign wwrp_ad_ras_dp_err_log = s_wwrp_ad_ras_dp_err_log;


   // Write Request State Machine
   //
   // S_RQ_INCR1
   //   The system is either idle or is processing the first incr request as consequence of wrap
   //   split. The FSM will fall into S_RQ_INCR2 state when the last data beat of the first split
   //   request.
   //
   // S_RQ_INCR2
   //   Second split request is being processed. The system will back to S_RQ_INCR1 when the last
   //   write data beat is acepted on the slave port.
   always @(*)
   begin : proc_comb_wr_wrap_st

      case (r_rq_wrap_st)
         S_RQ_INCR1:
         begin
            if (s_incr1_last_beat)
               s_rq_wrap_st = S_RQ_INCR2;
            else
               s_rq_wrap_st = S_RQ_INCR1;
         end

         S_RQ_INCR2:
         begin
            if (s_wrap_last)
               s_rq_wrap_st = S_RQ_INCR1;
            else
               s_rq_wrap_st = S_RQ_INCR2;
         end

         default : begin
            s_rq_wrap_st = S_RQ_INCR1;
         end
      endcase
   end

   always @(posedge slv_aclk or negedge slv_aresetn)
   begin : proc_seq_wr_wrap_st
      if (!slv_aresetn)
         r_rq_wrap_st <= # TP S_RQ_INCR1;
      else
         r_rq_wrap_st <= # TP s_rq_wrap_st;
   end


   // Active request selector. When a wrap is pslit into two smaller incr request one should set
   // the address and the lenght of the request being issued.
   always @(posedge slv_aclk or negedge slv_aresetn)
   begin : proc_seq_incr1_sel
      if (!slv_aresetn)
         r_incr1_sel <= # TP 1'b1;
      else begin
         if (s_rq_wrap_st==S_RQ_INCR2)
            r_incr1_sel <= # TP 1'b0;
         else if (s_rq_wrap_st==S_RQ_INCR1)
            r_incr1_sel <= # TP 1'b1;
      end
   end

   // Determine on whether the the current request will get split or not
   assign s_wrap_split = (wif_burst==WRAP) && (s_wif_addr != s_wrap_bndry_wo_par);

   // Set the address of the active request
   always @(*)
   begin : proc_comb_wwrp_addr_wo_par
      if (s_wrap_split) begin
         if (r_incr1_sel)
            s_wwrp_addr_wo_par = s_wif_addr;
         else
            s_wwrp_addr_wo_par = s_wrap_bndry_wo_par;
      end else begin
         s_wwrp_addr_wo_par = s_wif_addr;
      end
   end


   assign s_wwrp_addr =  fn_addr_w_par(s_wwrp_addr_wo_par);

   assign wwrp_addr = s_wwrp_addr;


   // Set the lenght of the active request
   generate if (SLV_BURST_LEN_PW > 4) begin : LEN_OFFSET_BURST_LEN_PW_BIGGER_THAN_4
     always @(*)
     begin : proc_comb_wwrp_len
        if (s_wrap_split) begin
           if (r_incr1_sel)
              s_wwrp_len = { {SLV_BURST_LEN_PW-4{1'b0}}, s_incr1_len};
           else
              s_wwrp_len = { {SLV_BURST_LEN_PW-4{1'b0}}, s_incr2_len};
        end else begin
           s_wwrp_len = wif_len;
        end
     end
   end else begin : LEN_OFFSET_BURST_LEN_PW_SMALLER_OR_EQUAL_THAN_4
     always @(*)
     begin : proc_comb_wwrp_len
        if (s_wrap_split) begin
           if (r_incr1_sel)
              s_wwrp_len = s_incr1_len[SLV_BURST_LEN_PW-1:0];
           else
              s_wwrp_len = s_incr2_len[SLV_BURST_LEN_PW-1:0];
        end else begin
           s_wwrp_len = wif_len;
        end
     end
   end
   endgenerate

   assign wwrp_len = s_wwrp_len;


   // Signal the last data beat being issued
   always @(*)
   begin : proc_comb_wwrp_last
      if (s_wrap_split) begin
         if (r_incr1_sel)
            s_wwrp_last = s_wrap_valid && s_incr1_last_beat;
         else
            s_wwrp_last = wif_last;
      end else begin
         s_wwrp_last = wif_last;
      end
   end

   assign wwrp_last = s_wwrp_last;

   // Set on whether the request response pulse should be filtered or not. Wrap requests are split
   // internally so that two TLPs will be issued to the PCIe wire (if MTU is not reached). As a
   // consequence, two responses will be received. In this scneario the first response should be
   // filtered internally so that AXI master will only get one response, for the original request
   always @(*)
   begin : proc_comb_wwrp_first_wrp_split_xact
      if (r_incr1_sel && s_wrap_split) begin
         s_wwrp_first_wrp_split_xact = 1'b1;
      end else begin
         s_wwrp_first_wrp_split_xact = 1'b0;
      end
   end

   assign wwrp_first_wrp_split_xact  = s_wwrp_first_wrp_split_xact;

   // Requests downstream treated as INCRs
   assign wrpreq_burst = INCR;



  // -------------------------------------------------------------------------------------
  // Functions
  // -------------------------------------------------------------------------------------
  // Address without parity
  function automatic [SLAVE_BUS_ADDR_WIDTH-1:0] fn_addr_wo_par;
    input [SLV_BUS_ADDR_WIDTH-1:0] s_addr_w_par;
    integer i,j;
    begin
      for (i=0; i<ADDR_PAR_BLOCK_SIZE; i=i+1)  begin // interate thru parity block size
       for (j=0; j<CX_RAS_PROT_RANGE; j=j+1)  begin // interate thru parity block size bits
          fn_addr_wo_par[i*CX_RAS_PROT_RANGE +j] = s_addr_w_par[i*CX_RAS_PROT_RANGE +j +i];
        end
      end
    end
  endfunction

  // Address with parity
  function automatic [SLV_BUS_ADDR_WIDTH-1:0] fn_addr_w_par;
    input [SLAVE_BUS_ADDR_WIDTH-1:0] s_addr_wo_par;

    integer i, j;
    reg [CX_RAS_PROT_RANGE-1:0] s_addr_for_par;

    begin
    fn_addr_w_par  = {SLV_BUS_ADDR_WIDTH{1'b0}};
    s_addr_for_par = {CX_RAS_PROT_RANGE{1'b0}};

      for (i=0; i<(ADDR_PAR_BLOCK_SIZE); i=i+1) begin
         for (j=0; j<CX_RAS_PROT_RANGE; j=j+1) begin
     s_addr_for_par[j]=s_addr_wo_par[i*CX_RAS_PROT_RANGE +j];
     fn_addr_w_par[i*CX_RAS_PROT_RANGE +j+i] = s_addr_wo_par[i*CX_RAS_PROT_RANGE +j];
         end
          fn_addr_w_par[(i+1)*CX_RAS_PROT_RANGE +i] = CX_RAS_PARITY_MODE ? ~(^s_addr_for_par) : ^s_addr_for_par;
      end
    end
  endfunction

  function automatic [ADDR_PAR_BLOCK_SIZE-1:0] fn_prot_chkin_ad;
    input [SLV_BUS_ADDR_WIDTH-1:0] s_addr_w_par;
    integer i;
    begin
      for (i=0; i<ADDR_PAR_BLOCK_SIZE; i=i+1) begin
        fn_prot_chkin_ad[i] = s_addr_w_par[i*CX_RAS_PROT_RANGE + i + CX_RAS_PROT_RANGE];
      end
    end
  endfunction

endmodule
