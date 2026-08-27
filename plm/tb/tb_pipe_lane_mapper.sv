`timescale 1ns/1ps
//=============================================================================
// tb_pipe_lane_mapper -- self-checking functional testbench for the
// generated PIPE lane mapper (config/*.csv as currently checked in:
// Ctrl0 x16, Ctrl1 x8, Ctrl2 x8, Ctrl3 x4; lane_mapping.csv modes 0-3).
//
// Drives distinct data patterns into every controller port and every phy
// lane, cycles through all four modes, and checks:
//   1. steady-state data routing matches config/lane_mapping.csv exactly
//   2. unmapped controller ports read back SAFE_P2M
//   3. group sel vectors are never more than one-hot (break-before-make)
//   4. during the all-zero BBM gap, muxed phy lanes show the SAFE_M2P
//      polarity-normalized value (txelecidle=1), not stale/glitched data
//
// Not exhaustive (no CDC formal, no randomized clock jitter) -- see
// bbm_sel_onehot.sv header for what remains for signoff.
//=============================================================================
import pipe_pkg::*;

module tb_pipe_lane_mapper;

    localparam int NUM_MODES  = 4;
    localparam int LANE_COUNT = 16;
    localparam int NUM_CTRL   = 4;

    // ---------------------------------------------------------------- clocks
    // Only phy_pclk_out[0/4/8/12] actually feed ctrl_pclk / the BBM branch
    // clocks (see plm_config.report() -- every controller's pclk source is
    // direct, always the group's lowest lane). Give those four genuinely
    // different periods to exercise real async CDC; the rest just need to
    // toggle so phy_pclk_in feedback has something to show in the wave.
    localparam int unsigned PERIOD_NS [0:15] = '{
        6, 3, 4, 5, 10, 7, 8, 9, 14, 11, 12, 13, 18, 15, 16, 17
    };

    logic [LANE_COUNT-1:0] phy_pclk_out;

    for (genvar l = 0; l < LANE_COUNT; l++) begin : g_clk
        initial begin
            phy_pclk_out[l] = 1'b0;
            #(l * 0.7);   // stagger phase so lanes aren't accidentally aligned
            forever #(PERIOD_NS[l] / 2.0) phy_pclk_out[l] = ~phy_pclk_out[l];
        end
    end

    // ---------------------------------------------------------------- DUT IO
    logic                  test_en = 1'b0;
    logic [NUM_CTRL-1:0]   ctrl_rst_n = '0;
    logic [$clog2(NUM_MODES)-1:0] mode = '0;

    logic [NUM_CTRL-1:0]   ctrl_pclk;
    logic [LANE_COUNT-1:0] phy_pclk_in;
    logic [LANE_COUNT-1:0] phy_rst_n;

    mac2phy_lane_t [LANE_COUNT-1:0] phy_mac2phy;
    phy2mac_lane_t [LANE_COUNT-1:0] phy_phy2mac;

    mac2phy_lane_t [15:0] ctrl0_mac2phy;
    phy2mac_lane_t [15:0] ctrl0_phy2mac;
    mac2phy_lane_t [3:0]  ctrl1_mac2phy;
    phy2mac_lane_t [3:0]  ctrl1_phy2mac;
    mac2phy_lane_t [7:0]  ctrl2_mac2phy;
    phy2mac_lane_t [7:0]  ctrl2_phy2mac;
    mac2phy_lane_t [3:0]  ctrl3_mac2phy;
    phy2mac_lane_t [3:0]  ctrl3_phy2mac;

    pipe_lane_mapper_top #(
        .NUM_MODES  (NUM_MODES),
        .LANE_COUNT (LANE_COUNT),
        .NUM_CTRL   (NUM_CTRL)
    ) dut (
        .phy_pclk_out   (phy_pclk_out),
        .test_en        (test_en),
        .ctrl_rst_n     (ctrl_rst_n),
        .mode           (mode),
        .ctrl_pclk      (ctrl_pclk),
        .phy_pclk_in    (phy_pclk_in),
        .phy_rst_n      (phy_rst_n),
        .phy_mac2phy    (phy_mac2phy),
        .phy_phy2mac    (phy_phy2mac),
        .ctrl0_mac2phy  (ctrl0_mac2phy),
        .ctrl0_phy2mac  (ctrl0_phy2mac),
        .ctrl1_mac2phy  (ctrl1_mac2phy),
        .ctrl1_phy2mac  (ctrl1_phy2mac),
        .ctrl2_mac2phy  (ctrl2_mac2phy),
        .ctrl2_phy2mac  (ctrl2_phy2mac),
        .ctrl3_mac2phy  (ctrl3_mac2phy),
        .ctrl3_phy2mac  (ctrl3_phy2mac)
    );

    // ---------------------------------------------------------------- stimulus patterns

    function automatic mac2phy_lane_t make_m2p(input int cid, input int port);
        mac2phy_lane_t v;
        v = SAFE_M2P;
        v.mac_phy_txdata     = {4'(cid), 20'h0, 8'(port)};
        v.mac_phy_txdatak    = 4'(port);
        v.mac_phy_txdatavalid = 1'b1;
        v.mac_phy_txelecidle  = 1'b0;   // "active" -- SAFE would be 1
        v.mac_phy_rxstandby   = 1'b0;   // "active" -- SAFE would be 1
        return v;
    endfunction

    function automatic phy2mac_lane_t make_p2m(input int lane);
        phy2mac_lane_t v;
        v = SAFE_P2M;
        v.phy_mac_rxdata      = {8'hA5, 16'h0, 8'(lane)};
        v.phy_mac_rxdatak     = 4'(lane);
        v.phy_mac_rxdatavalid = 1'b1;
        v.phy_mac_rxelecidle       = 1'b0;  // "active" -- SAFE would be 1
        v.phy_mac_rxstandbystatus  = 1'b0;  // "active" -- SAFE would be 1
        return v;
    endfunction

    always_comb begin
        for (int p = 0; p < 16; p++) ctrl0_mac2phy[p] = make_m2p(0, p);
        for (int p = 0; p < 4;  p++) ctrl1_mac2phy[p] = make_m2p(1, p);
        for (int p = 0; p < 8;  p++) ctrl2_mac2phy[p] = make_m2p(2, p);
        for (int p = 0; p < 4;  p++) ctrl3_mac2phy[p] = make_m2p(3, p);
        for (int l = 0; l < 16; l++) phy_phy2mac[l]   = make_p2m(l);
    end

    // ---------------------------------------------------------------- expected mapping (transcribed from config/lane_mapping.csv)
    function automatic int owner_of(input int m, input int l);
        case (m)
            0: return 0;
            1: return (l < 8) ? 0 : 2;
            2: return (l < 8) ? 0 : (l < 12) ? 2 : 3;
            3: return (l < 4) ? 0 : (l < 8) ? 1 : (l < 12) ? 2 : 3;
            default: return -1;
        endcase
    endfunction

    function automatic int port_of(input int m, input int l);
        case (m)
            0: return l;
            1: return (l < 8) ? l : l - 8;
            2: return (l < 8) ? l : (l < 12) ? l - 8 : l - 12;
            3: return (l < 4) ? l : (l < 8) ? l - 4 : (l < 12) ? l - 8 : l - 12;
            default: return -1;
        endcase
    endfunction

    // ---------------------------------------------------------------- BBM one-hot / safe-state monitor (continuous, all modes)
    int unsigned err_count = 0;

    task automatic chk(input bit ok, input string msg);
        if (!ok) begin
            err_count++;
            $error("%0t: %s", $time, msg);
        end
    endtask

    // group -> lanes, for the safe-state-during-gap check
    localparam int G1_LANES[4] = '{4, 5, 6, 7};
    localparam int G2_LANES[4] = '{8, 9, 10, 11};
    localparam int G3_LANES[4] = '{12, 13, 14, 15};

    always @(dut.sel_tgt) begin
        chk($onehot0(dut.sel_tgt.g1), "sel_tgt.g1 not one-hot0 (>1 branch enabled at once)");
        chk($onehot0(dut.sel_tgt.g2), "sel_tgt.g2 not one-hot0 (>1 branch enabled at once)");
        chk($onehot0(dut.sel_tgt.g3), "sel_tgt.g3 not one-hot0 (>1 branch enabled at once)");

        if (dut.sel_tgt.g1 == '0)
            foreach (G1_LANES[i])
                chk(phy_mac2phy[G1_LANES[i]].mac_phy_txelecidle == 1'b1,
                    $sformatf("G1 lane%0d: sel_tgt.g1==0 but txelecidle!=1 (safe state not shown in BBM gap)", G1_LANES[i]));
        if (dut.sel_tgt.g2 == '0)
            foreach (G2_LANES[i])
                chk(phy_mac2phy[G2_LANES[i]].mac_phy_txelecidle == 1'b1,
                    $sformatf("G2 lane%0d: sel_tgt.g2==0 but txelecidle!=1 (safe state not shown in BBM gap)", G2_LANES[i]));
        if (dut.sel_tgt.g3 == '0)
            foreach (G3_LANES[i])
                chk(phy_mac2phy[G3_LANES[i]].mac_phy_txelecidle == 1'b1,
                    $sformatf("G3 lane%0d: sel_tgt.g3==0 but txelecidle!=1 (safe state not shown in BBM gap)", G3_LANES[i]));
    end

    // ---------------------------------------------------------------- steady-state data-routing check
    task automatic check_mode(input int m);
        mac2phy_lane_t exp_m2p;
        phy2mac_lane_t exp_p2m;
        int cid, port;

        for (int l = 0; l < LANE_COUNT; l++) begin
            cid  = owner_of(m, l);
            port = port_of(m, l);
            exp_m2p = make_m2p(cid, port);
            chk(phy_mac2phy[l].mac_phy_txdata == exp_m2p.mac_phy_txdata &&
                phy_mac2phy[l].mac_phy_txdatavalid == 1'b1 &&
                phy_mac2phy[l].mac_phy_txelecidle == 1'b0,
                $sformatf("mode%0d lane%0d: phy_mac2phy mismatch, expected ctrl%0d port%0d, got txdata=%0h valid=%0b elecidle=%0b",
                          m, l, cid, port, phy_mac2phy[l].mac_phy_txdata,
                          phy_mac2phy[l].mac_phy_txdatavalid, phy_mac2phy[l].mac_phy_txelecidle));

            chk(phy_rst_n[l] == ctrl_rst_n[cid],
                $sformatf("mode%0d lane%0d: phy_rst_n=%0b does not follow owner ctrl%0d's ctrl_rst_n=%0b",
                          m, l, phy_rst_n[l], cid, ctrl_rst_n[cid]));
        end

        for (int c = 0; c < NUM_CTRL; c++) begin
            int max_w;
            case (c)
                0: max_w = 16;
                1: max_w = 4;
                2: max_w = 8;
                3: max_w = 4;
            endcase
            for (int p = 0; p < max_w; p++) begin
                int src_lane;
                phy2mac_lane_t got;
                src_lane = -1;
                for (int l = 0; l < LANE_COUNT; l++)
                    if (owner_of(m, l) == c && port_of(m, l) == p) src_lane = l;

                case (c)
                    0: got = ctrl0_phy2mac[p];
                    1: got = ctrl1_phy2mac[p];
                    2: got = ctrl2_phy2mac[p];
                    3: got = ctrl3_phy2mac[p];
                endcase

                if (src_lane == -1) begin
                    chk(got == SAFE_P2M,
                        $sformatf("mode%0d ctrl%0d[%0d]: unmapped this mode but reads %p instead of SAFE_P2M",
                                  m, c, p, got));
                end else begin
                    exp_p2m = make_p2m(src_lane);
                    chk(got.phy_mac_rxdata == exp_p2m.phy_mac_rxdata &&
                        got.phy_mac_rxdatavalid == 1'b1 && got.phy_mac_rxelecidle == 1'b0,
                        $sformatf("mode%0d ctrl%0d[%0d]: expected lane%0d data %0h, got %0h valid=%0b elecidle=%0b",
                                  m, c, p, src_lane, exp_p2m.phy_mac_rxdata, got.phy_mac_rxdata,
                                  got.phy_mac_rxdatavalid, got.phy_mac_rxelecidle));
                end
            end
        end

        $display("%0t: mode%0d checked (%0d cumulative errors)", $time, m, err_count);
    endtask

    // ---------------------------------------------------------------- sequencing
    // Settle margin: 3-stage sync + hold register, slowest branch clock used
    // in any BBM is 18ns (phy12) -> a few hundred ns is generous headroom.
    localparam realtime SETTLE = 300;

    initial begin
        $dumpfile("waves.vcd");
        $dumpvars(0, tb_pipe_lane_mapper);

        ctrl_rst_n = '0;
        mode = 2'd0;
        #100;
        ctrl_rst_n = '1;
        #SETTLE;

        check_mode(0);
        mode = 2'd1; #SETTLE; check_mode(1);
        mode = 2'd2; #SETTLE; check_mode(2);
        mode = 2'd3; #SETTLE; check_mode(3);
        mode = 2'd0; #SETTLE; check_mode(0);
        mode = 2'd2; #SETTLE; check_mode(2);   // non-adjacent jump too
        mode = 2'd1; #SETTLE; check_mode(1);
        mode = 2'd3; #SETTLE; check_mode(3);

        // Targeted phy_rst_n checks, all in mode3 (owners: G0=Ctrl0 direct,
        // G1=Ctrl1, G2=Ctrl2, G3=Ctrl3).
        //
        // Pulsing the CURRENT owner's own reset also collapses that branch's
        // own sel_sync bit via the BBM (branch_rst_n forces its tgt_r/en to
        // 0), so the mux falls back to SAFE(0) regardless of which physical
        // ctrl_rst_n is wired to which din -- it can't tell a correct wiring
        // from a swapped one. Pulsing a candidate that is NOT the current
        // owner leaves sel_sync unchanged (that branch was already idle) and
        // actually exercises which physical reset the mux reads -- Ctrl0 is
        // a non-owning candidate in G1/G2/G3 during mode3, so one pulse
        // checks wiring isolation across all three BBM groups at once.
        for (int p = 0; p < 2; p++) begin
            int pulse_cid;
            pulse_cid = (p == 0) ? 1 : 0;   // p=0: owner-pulse (safe-state), p=1: non-owner-pulse (wiring isolation)
            ctrl_rst_n[pulse_cid] = 1'b0;
            #SETTLE;
            for (int l = 0; l < LANE_COUNT; l++) begin
                bit expect_low;
                expect_low = (owner_of(3, l) == pulse_cid);
                chk(phy_rst_n[l] == (expect_low ? 1'b0 : 1'b1),
                    $sformatf("mode3 lane%0d: ctrl_rst_n[%0d]=0 pulse, expected phy_rst_n=%0b (owner=%0d), got %0b",
                              l, pulse_cid, expect_low ? 1'b0 : 1'b1, owner_of(3, l), phy_rst_n[l]));
            end
            $display("%0t: ctrl_rst_n[%0d] pulse checked (%0d cumulative errors)", $time, pulse_cid, err_count);

            ctrl_rst_n[pulse_cid] = 1'b1;
            #SETTLE;
            check_mode(3);   // confirm every group's BBM is still consistent afterward
        end

        if (err_count == 0) $display("TB_RESULT: PASS");
        else                 $display("TB_RESULT: FAIL (%0d errors)", err_count);
        $finish;
    end

    initial begin
        #20000;
        $error("TB_RESULT: FAIL (timeout, simulation did not finish)");
        $finish;
    end

endmodule
