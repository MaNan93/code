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
// ---    $Revision: #11 $
// ---    $Id: //dwh/pcie_iip/main/fairbanks/design/Bridge/slave/DWC_pcie_axi_slv_wreq_lnull.sv#11 $
// -------------------------------------------------------------------------

// --- Description:
// -------------------------------------------------------------------------
`include "include/DWC_pcie_ctl_all_defs.svh"
`include "DWC_pcie_ctl_pkg.svh"


 module DWC_pcie_axi_slv_wreq_lnull
  import DWC_pcie_ctl_pkg::ras_dp_err_log_t;
  import DWC_pcie_ctl_pkg::MAX_RAS_PROT_CHK_N;
  import DWC_pcie_ctl_pkg::RAS_ERROR_LOG_WD;
  import DWC_pcie_ctl_pkg::ras_dp_err_inj_t;
 #(
  parameter SLV_BUS_ADDR_WIDTH             = 0,
  parameter SLV_BUS_ID_WIDTH               = 0,
  parameter SLAVE_BUS_ADDR_WIDTH           = 0,
  parameter SLV_BURST_LEN_PW               = 0,
  parameter CX_RAS_PROT_RANGE              = `CX_RAS_PROT_RANGE,
  parameter CX_RAS_PARITY_MODE             = `CX_RAS_PARITY_MODE,
  parameter SLV_BUS_WSTRB_WIDTH            = 0,
  parameter SLV_BUS_WSTRB_PW               = 0,
  parameter WR_MISC_INFO_WD                = 19,
  parameter TP                             = `TP
  )
  (
  input                                              slv_aclk,
  input                                              slv_aresetn,
  // -------------------------------------------------------------------------------------
  // AXI aligned write interface
  input                                              wif_valid,
  input       [SLV_BUS_ADDR_WIDTH-1:0]               wif_addr,
  input       [2:0]                                  wif_size,
  input       [SLV_BURST_LEN_PW-1:0]                 wif_len,
  input                                              wif_last,
  input       [SLV_BUS_WSTRB_WIDTH-1:0]              wif_strb,
  input       [WR_MISC_INFO_WD-1:0]                  wif_info,
  input                                              wwrp_first_wrp_split_xact,
  input                                              wwrp_valid,
  // -------------------------------------------------------------------------------------
  // Address parity error interface
  output wire                                        lnull_addr_parerr,
  output ras_dp_err_log_t                            addr_ad_ras_dp_err_log,
  input  ras_dp_err_inj_t                            ras_dp_err_inj_slv_aclk,
  // -------------------------------------------------------------------------------------
  // Leading null write interface
  output wire                                        lnull_valid,
  output wire [SLV_BUS_ADDR_WIDTH-1:0]               lnull_addr,
  output wire [SLAVE_BUS_ADDR_WIDTH-1:0]             lnull_addr_wo_par,
  output wire [SLV_BURST_LEN_PW-1:0]                 lnull_len,
  output wire [2:0]                                  lnull_size,
  output wire [WR_MISC_INFO_WD-1:0]                  lnull_info,
  output wire                                        lnull_first_wrp_split_xact,
  output wire                                        lnull_wrp_valid,
  input                                              dwalgn_ready
  );
  // -------------------------------------------------------------------------------------
  // Local parameters
  // -------------------------------------------------------------------------------------
  localparam S_WR_IDLE = 1'b0;
  localparam S_WR_MULTI_BEAT = 1'b1;

  localparam S_IDLE = 1'b0;
  localparam S_MULTI_BEAT_VALID = 1'b1;
  localparam ATOMIC_CAS_WRAP_POS = 0;

  localparam NUM_ADDR_PAR_BLOCKS = SLAVE_BUS_ADDR_WIDTH / CX_RAS_PROT_RANGE;
  localparam RAS_DP_ERR_LOG_WD = $clog2(MAX_RAS_PROT_CHK_N);
  // -------------------------------------------------------------------------------------
  // Internal wires/regs
  // -------------------------------------------------------------------------------------
  reg                                      s_wr_fsm;
  reg                                      r_wr_fsm;
  reg                                      s_first_beat;

  reg                                      s_lnull_fsm;
  reg                                      r_lnull_fsm;
  reg                                      s_first_beat_valid;
  reg                                      s_valid;
  reg                                      s_calc_addr_len;
  reg                                      s_sz_algnd_info_sel;
  reg                                      r_sz_algnd_info_sel;
  wire                                     s_lnull;

  reg                                      s_zero_byte_transfer;

  wire [SLV_BUS_WSTRB_PW:0]                s_max_num_bytes_per_beat;
  wire [SLAVE_BUS_ADDR_WIDTH-1:0]          s_low_addr_mask;

  reg                                      r_addr_parerr;
  ras_dp_err_log_t                         r_ras_dp_err_log;
  ras_dp_err_log_t                         s_addr_ad_ras_dp_err_log;

  wire [SLAVE_BUS_ADDR_WIDTH-1:0]          s_wif_addr_no_par;
  wire [SLAVE_BUS_ADDR_WIDTH-1:0]          s_start_addr;
  wire [SLAVE_BUS_ADDR_WIDTH-1:0]          s_sz_algnd_start_addr;
  reg  [SLAVE_BUS_ADDR_WIDTH-1:0]          s_sz_algnd_addr_multi_beat;
  reg  [SLV_BURST_LEN_PW-1:0]              s_len_multi_beat;
  reg  [SLV_BURST_LEN_PW-1:0]              r_len_multi_beat;
  reg  [SLAVE_BUS_ADDR_WIDTH-1:0]          r_sz_algnd_addr_multi_beat;
  wire [SLAVE_BUS_ADDR_WIDTH-1:0]          s_sz_algnd_addr;
  wire [SLV_BUS_WSTRB_PW-1:0]              s_first_lsb_pos;
  wire [SLV_BUS_WSTRB_PW-1:0]              s_byte_offset;

  wire [SLAVE_BUS_ADDR_WIDTH-1:0]          s_unalgnd_start_addr;
  wire [SLV_BUS_ADDR_WIDTH-1:0]            s_lnull_unalgnd_addr;
  wire [SLAVE_BUS_ADDR_WIDTH-1:0]          s_lnull_unalgnd_addr_wo_par;

  wire [SLV_BURST_LEN_PW-1:0]              s_len;
  wire                                     is_msg; // 1 - if the transfer is a msg/msgd

  reg  [SLV_BUS_ADDR_WIDTH-1:0]            r_lnull_addr;
  reg  [SLAVE_BUS_ADDR_WIDTH-1:0]          r_lnull_addr_wo_par;
  reg  [SLV_BURST_LEN_PW-1:0]              r_lnull_len;
  reg  [2:0]                               r_lnull_size;
  reg  [WR_MISC_INFO_WD-1:0]               r_lnull_info;
  reg                                      r_lnull_first_wrp_split_xact;
  reg                                      r_lnull_wrp_valid;
  wire                                     s_atomic_cas_wrap;
  // -------------------------------------------------------------------------------------
  // Design
  // -------------------------------------------------------------------------------------
  // -------------------------------------------------------------------------------------
  // Write FSM
  // -------------------------------------------------------------------------------------
  always @(*) begin : proc_comb_wr_fsm
    // Initialise
    s_wr_fsm     = r_wr_fsm;
    s_first_beat = 1'b0;

    case (r_wr_fsm)
      S_WR_IDLE : begin
        s_first_beat = wif_valid;
        if (wif_valid && !wif_last) begin
          s_wr_fsm = S_WR_MULTI_BEAT;
        end
      end

      S_WR_MULTI_BEAT : begin
        s_first_beat = 1'b0;
        if (wif_last) begin
          s_wr_fsm = S_WR_IDLE;
        end
      end
    endcase
  end

  always @(posedge slv_aclk or negedge slv_aresetn) begin : proc_seq_wr_fsm
    if (!slv_aresetn) begin
     r_wr_fsm <= # TP S_WR_IDLE;
    end else if (dwalgn_ready) begin
     r_wr_fsm <= # TP s_wr_fsm;
    end
  end

  // -------------------------------------------------------------------------------------
  // Leading null beat FSM
  // -------------------------------------------------------------------------------------
  assign s_lnull = !(|wif_strb);

  always @(*) begin : proc_comb_lnull_fsm
    s_first_beat_valid   = 1'b0;
    s_valid              = 1'b0;
    s_calc_addr_len      = 1'b0;
    s_sz_algnd_info_sel  = r_sz_algnd_info_sel;
    s_zero_byte_transfer = 1'b0;
    s_lnull_fsm          = r_lnull_fsm;

    case (r_lnull_fsm)
      S_IDLE : begin
        if (wif_valid) begin
           // Transition if multi-beat transfer and first data beat valid
           if (!wif_last && !s_lnull) begin
             s_lnull_fsm = S_MULTI_BEAT_VALID;
           end
           // Leading null detected, calculate next address
           if (!wif_last && s_lnull) begin
               s_calc_addr_len     = 1'b1;
           end
           // Select the calculated address/length
           if (!wif_last) begin
             if (s_lnull) begin
               s_sz_algnd_info_sel = 1'b1;
             end
           end else begin
               s_sz_algnd_info_sel = 1'b0;
           end
           // If (a) single beat with or without data or
           // (b) multi-beat and not leading null then
           // assert first beat valid
           if (wif_last || (!wif_last && !s_lnull)) begin
             s_first_beat_valid = 1'b1;
             s_valid            = wif_valid;
           end

           // Detect single beat null transfer
           if (wif_last && s_lnull) begin
             s_zero_byte_transfer = 1'b1;
           end

        end
      end

      S_MULTI_BEAT_VALID : begin
        s_first_beat_valid = 1'b0;
        s_valid            = wif_valid;
        if (wif_last) begin
          s_sz_algnd_info_sel = 1'b0;
          s_lnull_fsm         = S_IDLE;
        end
      end
    endcase
  end

  always @(posedge slv_aclk or negedge slv_aresetn) begin : proc_seq_lnull_fsm
    if (!slv_aresetn) begin
     r_sz_algnd_info_sel <= # TP 1'b0;
     r_lnull_fsm         <= # TP 1'b0;
    end else if (dwalgn_ready)begin
     r_sz_algnd_info_sel <= # TP s_sz_algnd_info_sel;
     r_lnull_fsm         <= # TP s_lnull_fsm;
    end
  end

  // -------------------------------------------------------------------------------------
  // Strip null beats and calculate aligned address and transfer length
  // -------------------------------------------------------------------------------------
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
     .PROT_WD                   (NUM_ADDR_PAR_BLOCKS       ),
     .PARITY_MODE               (CX_RAS_PARITY_MODE        ),
     .PROT_CORRECT_EN           (0                         ),
     .TOTAL_WIDTH               (SLAVE_BUS_ADDR_WIDTH      ),
     .EXCLUDE_PROT_WIDTH        (0                         ),
     .RAS_DP_PROT_CHK_ID_BASE   (`LNULL_AD_RAS_ID          )
   ) u_chk (
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
     .ras_dp_err_log            (s_addr_ad_ras_dp_err_log    )
       ,
       .ras_dp_err_inj          (ras_dp_err_inj_slv_aclk)
     );

   assign addr_ad_ras_dp_err_log =  s_addr_ad_ras_dp_err_log;
   assign lnull_addr_parerr = s_addr_ad_ras_dp_err_log.valid;


//`ifdef CX_MULTISTREAM_ARCH
//  assign addr_ad_ras_dp_err_log = r_ras_dp_err_log;
//`endif // CX_MULTISTREAM_ARCH

  // Strip parity bits, extract address
  assign s_wif_addr_no_par = fn_addr_wo_par(wif_addr);

  // Calculate the unaligned start address.
  // If message with or without data or leading null beat then the address is not modified.

  // If Wrapping burst AtomicCompare the address is not modified.
  assign s_atomic_cas_wrap = wif_info[ATOMIC_CAS_WRAP_POS];
  assign s_first_lsb_pos = fn_lsb_pos(wif_strb);
  assign s_start_addr = (
                        (s_first_beat && s_lnull)
                         || s_atomic_cas_wrap
                        )
                        ?  s_wif_addr_no_par
                        : {s_wif_addr_no_par[SLAVE_BUS_ADDR_WIDTH-1:SLV_BUS_WSTRB_PW]
                          , s_first_lsb_pos};

  // Calculate the size aligned address and transfer length
  assign s_max_num_bytes_per_beat = (1'b1 << wif_size);
  assign s_low_addr_mask          = (s_max_num_bytes_per_beat-1);

  // if msg/msgD
  assign is_msg = (wif_info[(WR_MISC_INFO_WD - SLV_BUS_ID_WIDTH -1):(WR_MISC_INFO_WD - SLV_BUS_ID_WIDTH -2)] == 2'b10)? 1'b1 : 1'b0;
  // Align the start address to the size boundary.
  // If one beat zero byte transfer (Msg or MsgD or null MWr) then do not modify the address
  // If Wrapping burst AtomicCompare then do not modify the address
  assign s_sz_algnd_start_addr =  s_zero_byte_transfer ? s_start_addr
                                                       : (
                                                         (is_msg
                                                          || s_atomic_cas_wrap
                                                         )
                                                         ? s_wif_addr_no_par
                                                         : s_start_addr & ~s_low_addr_mask
                                                         );

  // Hold the calculated multi-beat next addr/len values
  always @(*) begin : proc_comb_sz_algn_addr
    if (s_first_beat) begin
      // Capture size aligned start address on first beat
      s_sz_algnd_addr_multi_beat = s_sz_algnd_start_addr;
      s_len_multi_beat           = wif_len;
    end else begin
      // Update addr/length per beat
      s_sz_algnd_addr_multi_beat = r_sz_algnd_addr_multi_beat;
      s_len_multi_beat           = r_len_multi_beat;
    end
  end

  // Calculate the multi-beat next addr/len values
  always @(posedge slv_aclk or negedge slv_aresetn) begin : proc_seq_sz_algnd_info
    if (!slv_aresetn) begin
       r_sz_algnd_addr_multi_beat <= # TP {SLV_BUS_ADDR_WIDTH{1'b0}};
       r_len_multi_beat           <= # TP {SLV_BURST_LEN_PW{1'b0}};
    end else if (dwalgn_ready) begin
       if (wif_valid) begin
         if (wif_last) begin
           // Initialise
           r_sz_algnd_addr_multi_beat <= # TP {SLV_BUS_ADDR_WIDTH{1'b0}};
           r_len_multi_beat           <= # TP {SLV_BURST_LEN_PW{1'b0}};
         end else if (s_calc_addr_len) begin
           // not calculated if the transaction is a msg
           if (!is_msg) begin
             // spyglass disable_block W164a
             // SMD: Identifies assignments in which the LHS width is less than the RHS width
             // SJ: The rule reports assignments where the result of an addition or subtraction operation is being assigned to a bus of the same width as the operands of the addition or subtraction operation. In this code, the value of the operands is never large enough to cause overflow.
             r_sz_algnd_addr_multi_beat <= # TP s_sz_algnd_addr_multi_beat
                                              + s_max_num_bytes_per_beat;
             // spyglass enable_block W164a
           end
           else begin
             r_sz_algnd_addr_multi_beat <= # TP s_sz_algnd_addr_multi_beat;
           end
           r_len_multi_beat           <= # TP s_len_multi_beat - 1;
         end
       end
    end
  end

  // Select the size aligned address
  assign s_sz_algnd_addr        = r_sz_algnd_info_sel ? r_sz_algnd_addr_multi_beat :
                                                        s_sz_algnd_start_addr;
  // Add byte offset to size aligned address
  assign s_byte_offset   = is_msg? {SLV_BUS_WSTRB_PW{1'b0}} : s_first_lsb_pos & s_low_addr_mask[SLV_BUS_WSTRB_PW-1:0];  // exempted for msgs
  // Calculate aligned start address
  // spyglass disable_block W164a
  // SMD: Identifies assignments in which the LHS width is less than the RHS width
  // SJ: The rule reports assignments where the result of an addition or subtraction operation is being assigned to a bus of the same width as the operands of the addition or subtraction operation. In this code, the value of the operands is never large enough to cause overflow.
  assign s_unalgnd_start_addr = s_first_beat_valid ? s_sz_algnd_addr + s_byte_offset :
                                                     {SLAVE_BUS_ADDR_WIDTH{1'b0}};
  // spyglass enable_block W164a

  // Add parity
  assign s_lnull_unalgnd_addr        = fn_addr_w_par(s_unalgnd_start_addr);
  assign s_lnull_unalgnd_addr_wo_par = s_unalgnd_start_addr;

  // Select the length
  assign s_len = r_sz_algnd_info_sel ? r_len_multi_beat : wif_len;

  // -------------------------------------------------------------------------------------
  // Align the control and sideband info with the aligned data and control signals
  // -------------------------------------------------------------------------------------
  always @(posedge slv_aclk or negedge slv_aresetn) begin : proc_seq_ctl_misc_info
    if (!slv_aresetn) begin
      r_lnull_addr                 <= # TP {SLV_BUS_ADDR_WIDTH{1'b0}};
      r_lnull_addr_wo_par          <= # TP {SLAVE_BUS_ADDR_WIDTH{1'b0}};
      r_lnull_len                  <= # TP {SLV_BURST_LEN_PW{1'b0}};
      r_lnull_size                 <= # TP 3'b0;
      r_lnull_info                 <= # TP {WR_MISC_INFO_WD{1'b0}};
      r_lnull_first_wrp_split_xact <= # TP 1'b0;
      r_lnull_wrp_valid            <= # TP 1'b0;
    end else begin
      if (s_first_beat_valid && dwalgn_ready) begin
        r_lnull_addr                 <= # TP s_lnull_unalgnd_addr;
        r_lnull_addr_wo_par          <= # TP s_lnull_unalgnd_addr_wo_par;
        r_lnull_len                  <= # TP s_len;
        r_lnull_size                 <= # TP wif_size;
        r_lnull_info                 <= # TP wif_info;
        r_lnull_first_wrp_split_xact <= # TP wwrp_first_wrp_split_xact;
        r_lnull_wrp_valid            <= # TP wwrp_valid;
      end
    end
  end

  // -------------------------------------------------------------------------------------
  // Assign outputs
  // -------------------------------------------------------------------------------------
  // Drive valid to data width aligner
  assign lnull_valid       = s_valid;
  // Control and sideband info aligned with data from data width aligner
  assign lnull_addr        = r_lnull_addr;
  assign lnull_addr_wo_par = r_lnull_addr_wo_par;
  assign lnull_len         = r_lnull_len;
  assign lnull_size        = r_lnull_size;
  assign lnull_info        = r_lnull_info;
  assign lnull_first_wrp_split_xact = r_lnull_first_wrp_split_xact;
  assign lnull_wrp_valid            = r_lnull_wrp_valid;
  
  
  // -------------------------------------------------------------------------------------
  // Functions
  // -------------------------------------------------------------------------------------
  // Returng the lsb position in the vector
  function automatic [SLV_BUS_WSTRB_PW-1:0] fn_lsb_pos;
    input [SLV_BUS_WSTRB_WIDTH-1:0] s_vec;
    reg                             s_found;
    reg [SLV_BUS_WSTRB_PW-1:0]      s_lsb_pos;

    integer j;

    begin
      s_found   = 0;
      s_lsb_pos = 'd0;

      for (j=0; j<SLV_BUS_WSTRB_WIDTH; j=j+1) begin
        if (s_vec[j]==1'b1 & s_found==1'b0) begin
          s_found=1'b1;
          s_lsb_pos=j;
        end
      end
      fn_lsb_pos = s_lsb_pos;
    end
  endfunction



  function automatic [SLAVE_BUS_ADDR_WIDTH-1:0] fn_addr_wo_par;
    input [SLV_BUS_ADDR_WIDTH-1:0] s_addr_w_par;
    integer i,j;
    begin
      fn_addr_wo_par  = {(SLAVE_BUS_ADDR_WIDTH){1'b0}};
      for (i=0; i<NUM_ADDR_PAR_BLOCKS; i=i+1)  begin // interate thru parity block size
       for (j=0; j<CX_RAS_PROT_RANGE; j=j+1)  begin // interate thru parity block size bits
          fn_addr_wo_par[i*CX_RAS_PROT_RANGE +j] = s_addr_w_par[i*CX_RAS_PROT_RANGE +j +i];
        end
      end
    end
  endfunction


  // Function adding parity
  function automatic [SLV_BUS_ADDR_WIDTH-1:0] fn_addr_w_par;
    input [SLAVE_BUS_ADDR_WIDTH-1:0] s_addr_wo_par;

    integer i, j;
    reg [CX_RAS_PROT_RANGE-1:0] s_addr_for_par;
    begin
    fn_addr_w_par  = {(SLV_BUS_ADDR_WIDTH){1'b0}};
    s_addr_for_par = {(CX_RAS_PROT_RANGE){1'b0}};

      for (i=0; i<(NUM_ADDR_PAR_BLOCKS); i=i+1) begin
         for (j=0; j<`CX_RAS_PROT_RANGE; j=j+1) begin
            s_addr_for_par[j]=s_addr_wo_par[i*CX_RAS_PROT_RANGE +j];
            fn_addr_w_par[i*CX_RAS_PROT_RANGE +j+i] = s_addr_wo_par[i*CX_RAS_PROT_RANGE +j];
         end
          fn_addr_w_par[(i+1)*CX_RAS_PROT_RANGE +i] = CX_RAS_PARITY_MODE ? ~(^s_addr_for_par) : ^s_addr_for_par;
      end
    end
  endfunction

  function automatic [NUM_ADDR_PAR_BLOCKS-1:0] fn_prot_chkin_ad;
    input [SLV_BUS_ADDR_WIDTH-1:0] s_addr_w_par;
    integer i;
    begin
      for (i=0; i<NUM_ADDR_PAR_BLOCKS; i=i+1) begin
        fn_prot_chkin_ad[i] = s_addr_w_par[i*CX_RAS_PROT_RANGE + i + CX_RAS_PROT_RANGE];
      end
    end
  endfunction

endmodule
