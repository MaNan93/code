`timescale 1ps/1ps

module tb_pcie_pipe_link_sv;
    localparam int NL             = 4;
    localparam int DATA_WD        = 80;
    localparam int TXEI_WD        = 4;
    localparam int DIRFEEDBACK_WD = 12;

    logic pclk_62p5 = 0, pclk_125 = 0, pclk_250 = 0, pclk_500 = 0, pclk_1000 = 0;
    always #8000 pclk_62p5 = ~pclk_62p5; // 62.5 MHz
    always #4000 pclk_125  = ~pclk_125;  // 125 MHz
    always #2000 pclk_250  = ~pclk_250;  // 250 MHz
    always #1000 pclk_500  = ~pclk_500;  // 500 MHz
    always #500  pclk_1000 = ~pclk_1000; // 1000 MHz

    // =========================================================================
    // 1. Standalone Clock Switch Check (always_latch + and, Gen1..Gen6, clk_en)
    // =========================================================================
    logic       sw_rst_n = 0;
    logic       sw_clk_en = 1;
    logic [2:0] sw_rate_req = 3'd0;
    logic       sw_pclk;
    logic [2:0] sw_active_rate;
    logic       sw_ready;
    logic       sw_gated;

    pcie_pipe_pclk_switch #(.MAX_RATE(3'd5)) u_sw_dut (
        .pclk_62p5  (pclk_62p5),
        .pclk_125   (pclk_125),
        .pclk_250   (pclk_250),
        .pclk_500   (pclk_500),
        .pclk_1000  (pclk_1000),
        .phy_rst_n  (sw_rst_n),
        .clk_en     (sw_clk_en),
        .rate_req   (sw_rate_req),
        .pclk       (sw_pclk),
        .active_rate(sw_active_rate),
        .clock_ready(sw_ready),
        .clk_gated  (sw_gated)
    );

    bit  mon_en = 0;
    time last_edge_ps = 0;
    always @(sw_pclk) begin
        if (mon_en && last_edge_ps > 0) begin
            time pw;
            pw = $time - last_edge_ps;
            if (pw < 450) begin
                $fatal(1, "Glitch/runt pulse on sw_pclk: width=%0t ps at rate=%0d", pw, sw_active_rate);
            end
        end
        last_edge_ps = $time;
    end

    // =========================================================================
    // 2. Full pcie_pipe_link DUT (Gen6 SerDes + pclk_as_phy_input + Bifurcation)
    // =========================================================================
    logic [NL-1:0]               clocks_aligned;
    logic [NL-1:0]               dsp_phy_rst_n = '0, usp_phy_rst_n = '0;
    logic [NL-1:0]               dsp_pclk, usp_pclk;
    logic [NL-1:0]               dsp_max_pclk, usp_max_pclk;
    logic [NL-1:0]               dsp_rx_clk, usp_rx_clk;
    logic [NL-1:0]               dsp_mac_phy_maxpclkreq_n = '0, usp_mac_phy_maxpclkreq_n = '0;
    logic [NL-1:0]               dsp_phy_mac_maxpclkack_n, usp_phy_mac_maxpclkack_n;
    logic [NL-1:0]               dsp_phy_ref_clk_req_n, usp_phy_ref_clk_req_n;
    logic [NL*3-1:0]             dsp_active_rate, usp_active_rate;
    logic [NL-1:0]               dsp_clock_ready, usp_clock_ready;

    logic [NL*3-1:0]             dsp_mac_phy_rate = '0, usp_mac_phy_rate = '0;
    logic [NL*4-1:0]             dsp_mac_phy_powerdown = {NL{4'd2}}, usp_mac_phy_powerdown = {NL{4'd2}};
    logic [NL-1:0]               dsp_mac_phy_asyncpowerchangeack = '0, usp_mac_phy_asyncpowerchangeack = '0;
    logic [NL*5-1:0]             dsp_mac_phy_pclk_rate = '0, usp_mac_phy_pclk_rate = '0;
    logic [NL-1:0]               dsp_mac_phy_serdes_arch = '1, usp_mac_phy_serdes_arch = '1;
    logic [NL*2-1:0]             dsp_mac_phy_width = '0, usp_mac_phy_width = '0;
    logic [NL*2-1:0]             dsp_mac_phy_rxwidth = '0, usp_mac_phy_rxwidth = '0;

    logic [NL*DATA_WD-1:0]       dsp_mac_phy_txdata = '0, usp_mac_phy_txdata = '0;
    logic [NL*TXEI_WD-1:0]       dsp_mac_phy_txelecidle = '1, usp_mac_phy_txelecidle = '1;
    logic [NL-1:0]               dsp_mac_phy_txdatavalid = '1, usp_mac_phy_txdatavalid = '1;
    logic [NL-1:0]               dsp_mac_phy_txdetectrx_loopback = '0, usp_mac_phy_txdetectrx_loopback = '0;
    logic [NL-1:0]               dsp_mac_phy_rxstandby = '0, usp_mac_phy_rxstandby = '0;
    logic [NL-1:0]               dsp_mac_phy_rxpolarity = '0, usp_mac_phy_rxpolarity = '0;
    logic [NL-1:0]               dsp_serdes_pipe_rxready = '1, usp_serdes_pipe_rxready = '1;
    logic [NL-1:0]               dsp_serdes_pipe_turnoff_lanes = '0, usp_serdes_pipe_turnoff_lanes = '0;

    logic [NL-1:0]               dsp_mac_phy_rxeqeval = '0, usp_mac_phy_rxeqeval = '0;
    logic [NL-1:0]               dsp_mac_phy_rxeqinprogress = '0, usp_mac_phy_rxeqinprogress = '0;
    logic [NL-1:0]               dsp_mac_phy_invalid_req = '0, usp_mac_phy_invalid_req = '0;
    logic [NL-1:0]               dsp_mac_phy_getlocal_pset_coef = '0, usp_mac_phy_getlocal_pset_coef = '0;
    logic [NL*6-1:0]             dsp_mac_phy_local_pset_index = '0, usp_mac_phy_local_pset_index = '0;
    logic [NL-1:0]               dsp_mac_phy_dirchange = '0, usp_mac_phy_dirchange = '0;
    logic [NL*18-1:0]            dsp_mac_phy_txdeemph = '0, usp_mac_phy_txdeemph = '0;
    logic [NL*6-1:0]             dsp_mac_phy_fs = '0, usp_mac_phy_fs = '0;
    logic [NL*6-1:0]             dsp_mac_phy_lf = '0, usp_mac_phy_lf = '0;
    logic [NL*3-1:0]             dsp_mac_phy_rxpresethint = '0, usp_mac_phy_rxpresethint = '0;
    logic [NL*3-1:0]             dsp_mac_phy_txmargin = '0, usp_mac_phy_txmargin = '0;
    logic [NL-1:0]               dsp_mac_phy_txswing = '0, usp_mac_phy_txswing = '0;
    logic [NL*8-1:0]             dsp_mac_phy_messagebus = '0, usp_mac_phy_messagebus = '0;
    logic [NL*32-1:0]            dsp_mac_phy_pipe_config_control = '0, usp_mac_phy_pipe_config_control = '0;

    logic [NL*DATA_WD-1:0]       dsp_phy_mac_rxdata, usp_phy_mac_rxdata;
    logic [NL-1:0]               dsp_phy_mac_rxvalid, usp_phy_mac_rxvalid;
    logic [NL*3-1:0]             dsp_phy_mac_rxstatus, usp_phy_mac_rxstatus;
    logic [NL-1:0]               dsp_phy_mac_rxelecidle, usp_phy_mac_rxelecidle;
    logic [NL-1:0]               dsp_phy_mac_rxstandbystatus, usp_phy_mac_rxstandbystatus;
    logic [NL-1:0]               dsp_phy_mac_phystatus, usp_phy_mac_phystatus;
    logic [NL*6-1:0]             dsp_phy_mac_localfs, usp_phy_mac_localfs;
    logic [NL*6-1:0]             dsp_phy_mac_locallf, usp_phy_mac_locallf;
    logic [NL*DIRFEEDBACK_WD-1:0] dsp_phy_mac_dirfeedback, usp_phy_mac_dirfeedback;
    logic [NL*8-1:0]             dsp_phy_mac_fomfeedback, usp_phy_mac_fomfeedback;
    logic [NL*18-1:0]            dsp_phy_mac_local_tx_pset_coef, usp_phy_mac_local_tx_pset_coef;
    logic [NL-1:0]               dsp_phy_mac_local_tx_coef_valid, usp_phy_mac_local_tx_coef_valid;
    logic [NL*8-1:0]             dsp_phy_mac_messagebus, usp_phy_mac_messagebus;
    logic [NL*32-1:0]            dsp_phy_mac_pipe_config_status, usp_phy_mac_pipe_config_status;

    // pclk_as_phy_input loopback (models controller o_pclk = max_pclk)
    assign dsp_pclk = dsp_max_pclk;
    assign usp_pclk = usp_max_pclk;

    pcie_pipe_link #(
        .NL            (NL),
        .DATA_WD       (DATA_WD),
        .TXEI_WD       (TXEI_WD),
        .DIRFEEDBACK_WD(DIRFEEDBACK_WD),
        .MAX_RATE      (3'd5)
    ) u_link (.*);

    bit sw_done = 1'b0;
    task automatic run_sw_tests();
        int rates[11] = '{1, 2, 3, 4, 5, 4, 5, 2, 0, 5, 0};
        #100ns;
        sw_rst_n = 1'b1;
        #60ns;
        mon_en = 1'b1;
        if (!sw_ready || sw_active_rate != 0) $fatal(1, "Switch reset failed");
        foreach (rates[idx]) begin
            int target = rates[idx];
            sw_rate_req = target[2:0];
            wait (sw_ready && sw_active_rate == target[2:0]);
            #30ns;
        end
        sw_clk_en = 1'b0;
        wait (sw_gated === 1'b1);
        #5ns;
        if (sw_pclk !== 1'b0) $fatal(1, "Clock not 0 while gated");
        #30ns;
        sw_clk_en = 1'b1;
        wait (sw_ready && !sw_gated);
        $display("[PASS] Clock switch Gen1..Gen6 + always_latch+and + clk_en gating");
        sw_done = 1'b1;
    endtask

    initial begin : main_seq
        logic [3:0] det_seen;
        bit seen_d2u, seen_u2d, seen_l1, seen_l2;

        fork
            run_sw_tests();
        join_none

        #100ns;
        dsp_phy_rst_n = 4'hF;
        usp_phy_rst_n = 4'hF;

        wait (clocks_aligned == 4'hF && dsp_phy_mac_phystatus == 4'h0 && usp_phy_mac_phystatus == 4'h0);
        $display("[PASS] Reset exit and Gen1 lock across 4 lanes");

        // RxDetect in P1
        dsp_mac_phy_txdetectrx_loopback = 4'hF;
        det_seen = 4'h0;
        repeat (200) begin
            @(posedge dsp_pclk[0]);
            for (int l = 0; l < NL; l++) begin
                if (dsp_phy_mac_phystatus[l] && dsp_phy_mac_rxstatus[l*3 +: 3] == 3'b011)
                    det_seen[l] = 1'b1;
            end
            if (det_seen == 4'hF) break;
        end
        dsp_mac_phy_txdetectrx_loopback = 4'h0;
        if (det_seen != 4'hF) $fatal(1, "RxDetect failed: %b", det_seen);
        $display("[PASS] RxDetect on all 4 lanes");

        // Switch to P0 & Gen6 (rate=5, 80-bit/lane)
        dsp_mac_phy_powerdown = {NL{4'd0}};
        usp_mac_phy_powerdown = {NL{4'd0}};
        dsp_mac_phy_rate      = {NL{3'd5}};
        usp_mac_phy_rate      = {NL{3'd5}};
        wait (clocks_aligned == 4'hF && dsp_active_rate == {NL{3'd5}} && usp_active_rate == {NL{3'd5}});
        #30ns;

        // EQ test at Gen6
        dsp_mac_phy_getlocal_pset_coef = 4'hF;
        dsp_mac_phy_local_pset_index[5:0] = 6'd4;
        dsp_mac_phy_rxeqinprogress = 4'hF;
        dsp_mac_phy_rxeqeval = 4'hF;
        wait (dsp_phy_mac_phystatus[0] && dsp_phy_mac_fomfeedback[7:0] == 8'h38);
        if (dsp_phy_mac_localfs[5:0] != 6'd47 || dsp_phy_mac_locallf[5:0] != 6'd15)
            $fatal(1, "Unexpected FS/LF");
        dsp_mac_phy_getlocal_pset_coef = 4'h0;
        dsp_mac_phy_rxeqeval = 4'h0;
        dsp_mac_phy_rxeqinprogress = 4'h0;
        $display("[PASS] Gen6 EQ (FS=47, LF=15, FOM=0x38, 12b dirfeedback)");

        // Gen6 80b/lane data traffic + 4b partial txelecidle
        dsp_mac_phy_txelecidle = '0;
        usp_mac_phy_txelecidle = '0;
        dsp_mac_phy_txdata[79:0]       = 80'h00A5_CAFE_BABE_1234_5678;
        usp_mac_phy_txdata[3*80 +: 80] = 80'h005A_DEAD_BEEF_8765_4321;

        seen_d2u = 0; seen_u2d = 0;
        repeat (150) begin
            @(posedge usp_rx_clk[0]);
            if (usp_phy_mac_rxvalid[0] && !usp_phy_mac_rxelecidle[0] &&
                usp_phy_mac_rxdata[79:0] == 80'h00A5_CAFE_BABE_1234_5678)
                seen_d2u = 1;
            if (dsp_phy_mac_rxvalid[3] && !dsp_phy_mac_rxelecidle[3] &&
                dsp_phy_mac_rxdata[3*80 +: 80] == 80'h005A_DEAD_BEEF_8765_4321)
                seen_u2d = 1;
            if (seen_d2u && seen_u2d) break;
        end
        if (!seen_d2u || !seen_u2d) $fatal(1, "Gen6 80b SerDes data transfer failed");

        // Partial 4-bit idle on lane 0 (4'b1100 stays active, 4'b1111 -> idle)
        dsp_mac_phy_txelecidle[3:0] = 4'b1100;
        #15ns;
        if (usp_phy_mac_rxelecidle[0]) $fatal(1, "Partial 4'b1100 prematurely asserted rxelecidle");
        dsp_mac_phy_txelecidle[3:0] = 4'b1111;
        wait (usp_phy_mac_rxelecidle[0] && !usp_phy_mac_rxvalid[0]);
        $display("[PASS] Gen6 80b bidirectional SerDes + 4b txelecidle partial-idle");

        // Per-lane Bifurcation:
        // Lanes 0,1 = Gen6 (rate=5, P0); Lane 2 = Gen3 (rate=2, P0); Lane 3 = P1 with maxpclkreq_n=1
        dsp_mac_phy_txelecidle = 16'hF000;
        usp_mac_phy_txelecidle = 16'hF000;
        dsp_mac_phy_rate = {3'd0, 3'd2, 3'd5, 3'd5};
        usp_mac_phy_rate = {3'd0, 3'd2, 3'd5, 3'd5};
        dsp_mac_phy_powerdown = {4'd2, 4'd0, 4'd0, 4'd0};
        usp_mac_phy_powerdown = {4'd2, 4'd0, 4'd0, 4'd0};
        dsp_mac_phy_maxpclkreq_n = 4'b1000;
        usp_mac_phy_maxpclkreq_n = 4'b1000;

        wait (clocks_aligned == 4'b0111 &&
              dsp_phy_mac_maxpclkack_n == 4'b1000 &&
              usp_phy_mac_maxpclkack_n == 4'b1000);

        dsp_mac_phy_txdata[1*80 +: 80] = 80'h0099_1122_3344_5566_7788;
        usp_mac_phy_txdata[2*80 +: 80] = 80'h003C_99AA_BBCC_DDEE_FF00;
        seen_l1 = 0; seen_l2 = 0;
        repeat (150) begin
            #1ns;
            if (usp_phy_mac_rxvalid[1] && usp_phy_mac_rxdata[1*80 +: 80] == 80'h0099_1122_3344_5566_7788)
                seen_l1 = 1;
            if (dsp_phy_mac_rxvalid[2] && dsp_phy_mac_rxdata[2*80 +: 80] == 80'h003C_99AA_BBCC_DDEE_FF00)
                seen_l2 = 1;
            if (seen_l1 && seen_l2) break;
        end
        if (!seen_l1 || !seen_l2) $fatal(1, "Bifurcated mixed-rate data failed");
        $display("[PASS] Per-lane bifurcation (Gen6 + Gen3 + L1 maxpclk-gated simultaneously)");

        wait (sw_done);
        $display("ALL PCIE_PIPE_LINK STANDALONE CHECKS PASSED");
        $finish;
    end

    initial begin
        #5us;
        $display("TIMEOUT WATCHDOG at %0t: aligned=%b active_dsp=%h active_usp=%h d2u_v=%b u2d_v=%b d_ei=%b u_ei=%b rx_clk=%b dsp_pclk=%b ack=%b",
                 $time, clocks_aligned, dsp_active_rate, usp_active_rate,
                 usp_phy_mac_rxvalid, dsp_phy_mac_rxvalid,
                 usp_phy_mac_rxelecidle, dsp_phy_mac_rxelecidle,
                 usp_rx_clk, dsp_pclk, dsp_phy_mac_maxpclkack_n);
        $fatal(1, "Watchdog timeout");
    end
endmodule
