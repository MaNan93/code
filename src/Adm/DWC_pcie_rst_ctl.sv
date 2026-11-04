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
// ---    $Revision: #9 $
// ---    $Id: //dwh/pcie_iip/main/fairbanks/design/Adm/DWC_pcie_rst_ctl.sv#9 $
// -------------------------------------------------------------------------
// --- Module description: Reset control 
// -----------------------------------------------------------------------------
`include "include/DWC_pcie_ctl_all_defs.svh"

 
 module DWC_pcie_rst_ctl
 #(
   parameter TP                                  = `TP
  )
  
                         (
  // -------------------------------------------------------------------------------------
  // Clocks and resets
  input                                              core_clk,    
  input                                              core_rst_n,
  // -------------------------------------------------------------------------------------
  // Link Reset Request
  input                                              smlh_req_rst_not,
  // -------------------------------------------------------------------------------------
  // Configuration interface
  input                                              cfg_fast_link_mode,
  input       [1:0]                                  cfg_fast_link_scaling_factor,
  input                                              cfg_auto_flush_en,
  input       [7:0]                                  cfg_auto_flush_timeout,
  // -------------------------------------------------------------------------------------
  // LTSSM enters the hot reset or disable state
  input                                              smlh_ltssm_in_hotrst_dis_entry,
  // Application Reset Control Interface
  input                                              app_ltssm_enable,
  output wire                                        rstctl_ltssm_enable,
  // -------------------------------------------------------------------------------------
  // Link Status Interface 
  input                                              smlh_link_up,
  input                                              rdlh_link_up,
  // -------------------------------------------------------------------------------------
  // Link Timer Interface
  input                                              cfg_link_timeout_en_n,
  // Link timeout value specified in msec
  input       [`LINK_TIMEOUT_PERIOD_WIDTH-1:0]       cfg_link_timeout_period,
  input       [2:0]                                  current_data_rate,
  // -------------------------------------------------------------------------------------
  // Transfer Pending Interface
  input                                              brdg_slv_xfer_pending,
  input                                              brdg_dbi_xfer_pending,
  input                                              edma_xfer_pending,
  input                                              brdg_mstr_xfer_pending,
  input                                              radm_idle,
  // -------------------------------------------------------------------------------------
  // Flush Control Interface
  output wire                                        rstctl_core_flush_req,
  output wire                                        rstctl_mstr_flush_req,
  output wire                                        rstctl_slv_flush_req,
  output wire                                        rstctl_flush_done,
  input                                              flush_ack,
  input                                              app_req_flush,
  // -------------------------------------------------------------------------------------
  // Reset Request Interface
  output wire                                        rstctl_req_rst_not
  );
  // -------------------------------------------------------------------------------------
  // Local parameters
  // -------------------------------------------------------------------------------------
  localparam S_IDLE                        = 3'b000;
  localparam S_FLUSH                       = 3'b001;
  localparam S_STOP_ACCEPTING              = 3'b010;
  localparam S_RESET                       = 3'b011;
  localparam S_WAIT_FLUSH_CMPLT            = 3'b100;
  // -------------------------------------------------------------------------------------
  // Regs/Wires
  // -------------------------------------------------------------------------------------
  wire                                     s_smlh_req_rst_hl;
  reg                                      r_smlh_req_rst_not;
  reg                                      rr_smlh_req_rst_not;
  wire                                     s_link_req_rst_not;

  wire                                     s_link_up;
  reg                                      r_link_up;
  wire                                     s_link_up_lh;
  reg                                      rr_link_up;

  reg                                      s_link_timeout_tmr_en;
  reg  [3:0]                               s_cntr_8;
  reg  [3:0]                               r_cntr_8;
  reg                                      s_core_clk_en;
  wire                                     r_core_clk_en;
  reg  [9:0]                               r_cntr_1024;
  reg  [3:0]                               r_cntr_16;
  wire                                     s_timer_1usec_hl;
  wire                                     s_timer_16usec_hl;

  reg  [8:0]                               r_cntr_512;
  reg                                      s_timer_1ms_hl;

  reg  [`LINK_TIMEOUT_PERIOD_WIDTH-1:0]    r_cntr_link_timeout;
  reg                                      r_link_timeout_hl;

  reg  [2:0]                               s_flush_fsm_state;
  reg  [2:0]                               r_flush_fsm_state;
  reg                                      s_core_flush_req;
  reg                                      r_core_flush_req;
  reg                                      s_mstr_flush_req;
  reg                                      r_mstr_flush_req;
  reg                                      s_slv_flush_req;
  reg                                      r_slv_flush_req;
  reg                                      s_flush_in_progress;
  reg                                      s_wait_flush_cmplt;
  reg                                      s_link_timeout_det;
  reg                                      r_link_timeout_det;
  reg                                      s_req_rst_not;
  reg                                      r_req_rst_not;
  reg                                      s_flush_req;
  reg                                      r_flush_req;
  reg                                      r_flush_done;     
  reg                                      s_flush_done;     
  
  // -------------------------------------------------------------------------------------
  // Design
  // -------------------------------------------------------------------------------------

  // -------------------------------------------------------------------------------------
  // Detect reset request.
  // Applicaton reset request sequence triggered on the negative edge of smlh_req_rst_not.
  // The negative edge is detected and maintained until the core is reset.
  always @(posedge core_clk or negedge core_rst_n) begin : proc_seq_smlh_req_rst
    if (!core_rst_n) begin
      r_smlh_req_rst_not <= # TP 1'b0; 
    end else begin
      r_smlh_req_rst_not <= # TP smlh_req_rst_not;
    end  
  end

  // Falling edge detect
  assign s_smlh_req_rst_hl = !smlh_req_rst_not && r_smlh_req_rst_not;

  // Register reset request
  always @(posedge core_clk or negedge core_rst_n) begin
    if (!core_rst_n) begin
      rr_smlh_req_rst_not <= # TP 1'b1;
    end else if (s_smlh_req_rst_hl) begin
      rr_smlh_req_rst_not <= # TP 1'b0;
    end
  end

  // Hold LTSSM in Pre_Detect.Quiet
  assign rstctl_ltssm_enable = cfg_auto_flush_en ? (rr_smlh_req_rst_not ? app_ltssm_enable : 1'b0) : app_ltssm_enable;
  // Request warm reset
  assign s_link_req_rst_not = cfg_auto_flush_en ? r_req_rst_not : rr_smlh_req_rst_not;



assign rstctl_req_rst_not = s_link_req_rst_not;


  
  wire s_radm_idle;

  assign s_radm_idle = radm_idle && !brdg_mstr_xfer_pending;

  // transfer pending indication
  wire  s_xfer_pending;
  assign s_xfer_pending = brdg_slv_xfer_pending
                          || brdg_dbi_xfer_pending
                          || edma_xfer_pending
                          || !s_radm_idle;

  // Application flush request is latched and only
  // cleared when the FSM is in the Flush state
  always @(*) begin : proc_app_flush
    if(r_flush_fsm_state == S_FLUSH)
      s_flush_req = 1'b0;
    else if(app_req_flush)
      s_flush_req = 1'b1;
    else
      s_flush_req = r_flush_req;
  end : proc_app_flush

  // Detect link up
  assign s_link_up = smlh_link_up && rdlh_link_up;

  // The link timer is disabled on link up and will be re-enabled if the core is reset.
  always @(posedge core_clk or negedge core_rst_n) begin : proc_seq_link_up
    if (!core_rst_n) begin
      r_link_up   <= # TP 1'b0; 
      r_flush_req <= # TP 1'b0;
    end else begin
      r_link_up   <= # TP s_link_up;
      r_flush_req <= # TP s_flush_req;
    end  
  end

  // Rising edge detect
  assign s_link_up_lh = s_link_up && !r_link_up;

  // Register link up status
  always @(posedge core_clk or negedge core_rst_n) begin
    if (!core_rst_n) begin
      rr_link_up <= # TP 1'b0;
    end else if (s_link_up_lh) begin
      rr_link_up <= # TP 1'b1;
    end
  end

  // -------------------------------------------------------------------------------------
  // Timer
  // The Core Base Freq is fixed for dynamic width core configurations and doubles for 
  // dynamic frequency configurations as we move from GEN1->2->3 link speeds.
  // The Core Base Freq is given by parameter CX_FREQ, the link speed is given by the
  // "current_data_rate" signal derived from the PHY PIPE interface signal "mac_phy_rate".
  // Encoding as follows:
  // CX_FREQ_1: 250MHz, CX_FREQ_2: 125MHz, CX_FREQ_3: 62.5MHz
  // For dynamic freq configs the base freq also infers the number of symbols per cycle
  // per lane, i.e. CX_FREQ_1 => 1s, _2 => 2s, _3 => 4s.
  // "current_data_rate": 0: GEN1 1: GEN2, 2: GEN3
  // For GEN3 dynamic frequency cores GEN2 and GEN2 modes must match, i.e. if GEN3 mode
  // configured for dynamic freq then GEN2 mode must also be configured for dynamic freq.
  // This rule is enforced in the packaging.
  // The following examples describe the possible dynamic core_clk freq options:
  //      Core Base Freq = CX_FREQ_3 (62.5MHz)
  //      current_data_rate = GEN1, core_clk = 62.5MHz (GEN2/3 Disabled, 4s)
  //      current_data_rate = GEN2, core_clk = 125MHz (CX_GEN2_DYNAMIC_FREQ=1, 4s)
  //      current_data_rate = GEN3, core_clk = 250MHz (CX_GEN3_DYNAMIC_FREQ=1, 4s)
  //      Core Base Freq = CX_FREQ_2 (125MHz)
  //      current_data_rate = GEN1, core_clk = 125MHz (GEN2/3 Disabled, 2s)
  //      current_data_rate = GEN2, core_clk = 250MHz (CX_GEN2_DYNAMIC_FREQ=1, 2s)
  //      current_data_rate = GEN3, core_clk = 500MHz (CX_GEN3_DYNAMIC_FREQ=1, 2s)
  //      Core Base Freq = CX_FREQ_1 (250MHz)
  //      current_data_rate = GEN1, core_clk = 250MHz, (GEN2/3 Disabled, 1s)
  //      current_data_rate = GEN1, core_clk = 250MHz (GEN2_DYNAMIC_FREQ=1, 1s)
  //      current_data_rate = GEN2, core_clk = 500MHz (GEN2_DYNAMIC_FREQ=1, 1s)
  // ---------------------------------------------------------------------------------
  // Link Timer
  always @(*) begin : proc_comb_timer_en
    s_link_timeout_tmr_en = 1'b0;

    // Enable the link timer if
    // - port logic link disable register bit is 0
    // - the timer value is not equal to zero
    // - the link is not established
    // - transfer is pending (outbound, DBI or DMA requests)
    if (!cfg_link_timeout_en_n && (cfg_link_timeout_period != 0)) begin
      if (s_xfer_pending && !rr_link_up) begin
        s_link_timeout_tmr_en = 1'b1;
      end
    end

    // For robustness re-use the timer as a watchdog timer to ensure 
    // we always exit flush mode. Provide option to disable watchdog.
    if (s_wait_flush_cmplt || 
       (s_flush_in_progress && s_xfer_pending && (cfg_auto_flush_timeout != 0))) begin
      s_link_timeout_tmr_en = 1'b1;
    end
  end

  // Depending on the link data rate enable core clock cycles to give the base clock rate,
  // i.e. enabled core clock frequency equal to the base clock frequency .

DWC_pcie_tim_gen
 #(
    .CLEAR_CNTR_TO_1 (0)
) u_gen_r_core_clk_en
(
     .clk               (core_clk)
    ,.rst_n             (core_rst_n)

    ,.current_data_rate (current_data_rate)
    ,.clr_cntr          (!s_link_timeout_tmr_en)           // clear cycle counter
    
    ,.cnt_up_en         (r_core_clk_en)  // timer count-up 
);

 // ---------------------------------------------------------------------------------
  // To generate the 1usec time base advance the counter by 1,2, or 4 every 
  // base clock period and wrap at 256.
  // The parameter CX_FREQ_MULTIPLIER is derived from CX_FREQ and is encoded as follows: 
  // CX_FREQ = 62.5MHz => CX_FREQ_MULTIPLIER=4
  // CX_FREQ = 125MHz  => CX_FREQ_MULTIPLIER=2
  // CX_FREQ = 250MHz  => CX_FREQ_MULTIPLIER=1
  // Depending on the configured base clock frequency the counter effectively
  // increments on a 250MHz period. To generate at 1 usec time base the counter 
  // wraps at 1/250MHz * 256 = 1.048usec    
  // ---------------------------------------------------------------------------------

  always @(posedge core_clk or negedge core_rst_n) begin : proc_seq_cntr_512
    if (!core_rst_n) begin
      r_cntr_512 <= # TP `CX_FREQ_MULTIPLIER;
    end else begin
// spyglass disable_block STARC05-2.11.3.1
// SMD: Combinational and sequential parts of an FSM described in same always block
// SJ: Disable this check on legacy code. 
      // Re-initialise the counter
      if (!s_link_timeout_tmr_en) begin
        r_cntr_512 <= # TP `CX_FREQ_MULTIPLIER;
      end else begin
        // Counter increments every core base clock period 
        if (r_core_clk_en) begin
          // Wrap at the msb, counter reaches msb in 2 usec
          if (r_cntr_512==256) begin
            r_cntr_512 <= # TP `CX_FREQ_MULTIPLIER;
          end else begin
            r_cntr_512 <= # TP (r_cntr_512 + `CX_FREQ_MULTIPLIER);
          end
        end
      end
    end
// spyglass enable_block STARC05-2.11.3.1
  end 

  // Generate 1 usec pulse
  assign s_timer_1usec_hl = r_cntr_512[8] & r_core_clk_en;

  // ---------------------------------------------------------------------------------
  // Generate 1.024 msec pulse
  always @(posedge core_clk or negedge core_rst_n) begin : proc_seq_cntr_1024
    if (!core_rst_n) begin
      r_cntr_1024 <= # TP 0;
      r_cntr_16 <= # TP 0;
    end else begin
// spyglass disable_block STARC05-2.11.3.1
// SMD: Combinational and sequential parts of an FSM described in same always block
// SJ: Disable this check on legacy code. 
      // Re-initialise the counter
      if (!s_link_timeout_tmr_en) begin
        r_cntr_1024 <= # TP 0;
        r_cntr_16 <= # TP 0;
      end else begin
        if (s_timer_1usec_hl) begin
          // Wrap the counter at 999
          if (r_cntr_1024==10'd999) begin
            r_cntr_1024 <= # TP 0;
          end else begin
            r_cntr_1024 <= # TP r_cntr_1024 + 1;
          end
          // Wrap the counter at 15
          if (r_cntr_16==4'd15) begin
            r_cntr_16 <= # TP 0;
          end else begin
            r_cntr_16 <= # TP r_cntr_16 + 1;
          end
        end
      end
    end
// spyglass enable_block STARC05-2.11.3.1
  end
      
  // 16 usec tick
  assign s_timer_16usec_hl = s_timer_1usec_hl && (r_cntr_16==4'd15);

//VCS coverage off
  // Scale timer if fast link mode enabled
  always @(*) begin : proc_comb_timer_1ms
    s_timer_1ms_hl = 0;   

    if (cfg_fast_link_mode) begin
      case (cfg_fast_link_scaling_factor)
        2'b01 : begin // SF = 256
          s_timer_1ms_hl =  s_timer_1usec_hl && (r_cntr_1024[1:0]==2'd3);
        end
        2'b10 : begin // SF = 64
          s_timer_1ms_hl =  s_timer_1usec_hl && (r_cntr_1024[3:0]==4'd15);
        end
        2'b11 : begin // SF = 16
          s_timer_1ms_hl =  s_timer_1usec_hl && (r_cntr_1024[5:0]==6'd63);
        end
        default : begin // SF = 1024
          s_timer_1ms_hl = s_timer_1usec_hl;
        end
      endcase
    end else begin
//VCS coverage on
      s_timer_1ms_hl =  s_timer_1usec_hl && (r_cntr_1024==10'd999);
    end
  end

  // ---------------------------------------------------------------------------------
  // cfg_link_timeout_period encoding as follows:
  // 0 = Timer disabled
  // 1 = 1 msec
  // ...
  // 255 = 255 msec
  always @(posedge core_clk or negedge core_rst_n) begin : proc_seq_cntr_link_timeout
    if (!core_rst_n) begin
      r_cntr_link_timeout <= # TP 0;
      r_link_timeout_hl   <= # TP 1'b0;
    end else begin
      // Re-initialise the counter
      if (!s_link_timeout_tmr_en) begin
        r_cntr_link_timeout <= # TP 0;
        r_link_timeout_hl   <= # TP 1'b0;
      end else begin
        if (s_timer_1ms_hl) begin
          // Wrap the counter 
          if ((s_flush_in_progress && (r_cntr_link_timeout==(cfg_auto_flush_timeout-1))) ||
              (!s_flush_in_progress && (r_cntr_link_timeout==(cfg_link_timeout_period-1)))) begin 
            r_cntr_link_timeout <= # TP 0;
            r_link_timeout_hl   <= # TP 1'b1;
          // Increment the counter
          end else begin
            r_cntr_link_timeout <= # TP r_cntr_link_timeout + 1;
          end
        end else begin
          r_link_timeout_hl <= # TP 1'b0;
        end
      end
    end
  end

  // ---------------------------------------------------------------------------------
  // Flush control FSM
  always @(*) begin : proc_comb_flsh_fsm
    // Initialise
    s_flush_fsm_state   = r_flush_fsm_state;
    s_core_flush_req    = r_core_flush_req;
    s_slv_flush_req     = r_slv_flush_req;
    s_mstr_flush_req    = r_mstr_flush_req;
    s_flush_in_progress = 1'b0;
    s_wait_flush_cmplt  = 1'b0;
    s_link_timeout_det  = r_link_timeout_det;
    s_req_rst_not       = 1'b1;
    s_flush_done        = 1'b0;
// spyglass disable_block STARC05-2.11.3.1
// SMD: Combinational and sequential parts of an FSM described in same always block
// SJ: Disable this check on legacy code. 
    case (r_flush_fsm_state)
// spyglass enable_block STARC05-2.11.3.1
      S_IDLE : begin
        // The link reset request and the link timeout events are mutually exclusive.
        // If the link timer is enabled and the timer expires or link down and flushing
        // is enabled then pending requests are automatically flushed.
        // If flushing is disabled the responsibiity for resetting the core on link down
        // is passed to the application, i.e. the user must decide when to apply
        // the core/bridge resets. The FSM is held in IDLE state.
        // Flush is triggered by 1) Application request 2) link down, 3) link timeout 4) hot reset and 
        // 5) link disable (from recovery only)
        if (r_flush_req || r_link_timeout_hl || // Reset -> Link Timeout (Not Link up)
             (cfg_auto_flush_en &&  // Enable flush prior to warm reset 
               !flush_ack && // If the controllers reset request is delayed (app_ltssm_enable -> 0) then wait for ack -> 0 before setting req -> 1
               (!rr_smlh_req_rst_not || // Link up -> Detect (Not Directed)
               (rr_link_up && smlh_ltssm_in_hotrst_dis_entry)) // Link up -> Hot Reset/Disable -> Detect (Directed)
             )
        ) begin
          // Flush transmit path. Sink requests, timeout pending completions.
          // If DMA Read Channels enabled then channels will be gracefully end with 
          // timeout error status.
          s_core_flush_req = 1'b1;
          // Sink master responses
          // If DMA Write channels enabled then channels will be gracefully end with
          // write error status 
          s_mstr_flush_req = 1'b1;
          // Wait for pending requests to complete before asserting the flush
          // request to the applicationa and stalling the slave interface.
          s_flush_fsm_state = S_FLUSH;
        end

        // Set link timeout flag
        if (r_link_timeout_hl) begin
          s_link_timeout_det = 1'b1;
        end

        // Set the link timeout flag if the application requests the flush
        if (r_flush_req) begin
          s_link_timeout_det = 1'b1;
        end

      end
      S_FLUSH : begin
        // Flush all pending requests/responses before stalling outbound transfers. 
        // To be safe only stall outbound transfers after all inbound transfers on the
        // AXI master have been flushed.
        // Any dependency between the inbound and outbound transfers can result in deadlock, 
        // e.g. inbound P's can only progress if outbound Ps make forward progress.
        // Transition to STOP_ACCEPTING when no transfers pending and link down detected or
        // no transfers pending and link timeout event detected. 
        // Force exit to the STOP_ACCEPTING state if the flush watchdog timer expires.
        if ((!s_xfer_pending && (s_link_timeout_det || !rr_smlh_req_rst_not)) || r_link_timeout_hl) begin
          s_slv_flush_req   = 1'b1;
          s_flush_fsm_state = S_STOP_ACCEPTING;
        end
        s_flush_in_progress = 1'b1;
      end
      S_STOP_ACCEPTING : begin
        if (flush_ack || r_link_timeout_hl) begin
          if (r_link_timeout_det) begin
            // Write response initiated when hv accepted at the client interface.
            // Wait for at least 16usec before exiting flush; ensures xtlh drains in flight TLPs. 
            s_flush_fsm_state  = S_WAIT_FLUSH_CMPLT;
          end else begin
            // Hold off on reset request until new requests are stalled and 
            // all pending transfers in the pipeline have completed.
            // No need to wait for xtlh to drain in flight TLPs, core will be reset.
            s_flush_fsm_state = S_RESET;
          end
        end
        s_flush_in_progress = 1'b1;
      end
      S_WAIT_FLUSH_CMPLT : begin
        if (s_timer_16usec_hl) begin
          // Return to initial conditions
          s_core_flush_req   = 1'b0;
          s_slv_flush_req    = 1'b0;
          s_mstr_flush_req   = 1'b0;
          s_link_timeout_det = 1'b0;
          s_flush_fsm_state  = S_IDLE;
          s_flush_done       = 1'b1;
        end
        s_wait_flush_cmplt  = 1'b1;
      end
      S_RESET : begin
        // If the applciation is not ready for the reset to be applied then the FSM
        // rolls back to IDLE and returns to initial conditions. 
        // Flushing will be disabled and the Slave will accept new requests, e.g. DB read/writes.
        // The core/bridge resets are held off in the clock and reset block when app_ltssm_enable=0.
        if (!app_ltssm_enable) begin
          s_core_flush_req   = 1'b0;
          s_slv_flush_req    = 1'b0;
          s_mstr_flush_req   = 1'b0;
          s_link_timeout_det = 1'b0;
          s_flush_fsm_state  = S_IDLE;
        end else begin
          s_req_rst_not = 1'b0; 
        end
      end
      default : begin
        s_core_flush_req    = 1'b0;
        s_slv_flush_req     = 1'b0;
        s_mstr_flush_req    = 1'b0;
        s_flush_in_progress = 1'b0;
        s_wait_flush_cmplt  = 1'b0;
        s_link_timeout_det  = 1'b0;
        s_req_rst_not       = 1'b1;
        s_flush_fsm_state   = S_IDLE;
        s_flush_done        = 1'b0;
      end
    endcase
  end

  always @(posedge core_clk or negedge core_rst_n) begin : proc_seq_flsh_fsm
    if (!core_rst_n) begin
      r_flush_fsm_state  <= # TP S_IDLE;
      r_core_flush_req   <= # TP 1'b0;
      r_slv_flush_req    <= # TP 1'b0;
      r_mstr_flush_req   <= # TP 1'b0;
      r_link_timeout_det <= # TP 1'b0;
      r_req_rst_not      <= # TP 1'b1;
      r_flush_done       <= # TP 1'b0;
    end else begin
      r_flush_fsm_state  <= # TP s_flush_fsm_state;
      r_core_flush_req   <= # TP s_core_flush_req;
      r_slv_flush_req    <= # TP s_slv_flush_req;
      r_mstr_flush_req   <= # TP s_mstr_flush_req;
      r_link_timeout_det <= # TP s_link_timeout_det;
      r_req_rst_not      <= # TP s_req_rst_not;
      r_flush_done       <= # TP s_flush_done;
    end  
  end

  // Assign outputs
  // If auto flushing is disabled then send the link reset request directly to the SoC 
  // clock and reset block.
  assign rstctl_core_flush_req = r_core_flush_req;
  assign rstctl_slv_flush_req  = r_slv_flush_req;
  assign rstctl_mstr_flush_req = r_mstr_flush_req;
  assign rstctl_flush_done     = r_flush_done;     




`ifndef SYNTHESIS

 wire [16*8:1] FLSH_FSM;
 assign FLSH_FSM = (r_flush_fsm_state==S_IDLE)              ? "IDLE"           :
                   (r_flush_fsm_state==S_FLUSH)             ? "FLUSH"          :
                   (r_flush_fsm_state==S_STOP_ACCEPTING)    ? "STOP_ACCEPTING" :
                   (r_flush_fsm_state==S_WAIT_FLUSH_CMPLT ) ? "WAIT1"          :
                   (r_flush_fsm_state==S_RESET)             ? "RESET"          :
                   "UNDEF";


`endif // SYNTHESIS
   
endmodule
