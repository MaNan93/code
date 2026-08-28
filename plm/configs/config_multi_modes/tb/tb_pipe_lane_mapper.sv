`timescale 1ns/1ps
//=============================================================================
// tb_pipe_lane_mapper -- self-checking functional simulation, driven by this config set's lane_mapping.csv.
//
// Checks:
//   1. Steady-state data routing matches lane_mapping.csv exactly
//   2. Unmapped controller ports read back SAFE_P2M
//   3. Group sel vectors are always one-hot0 (break-before-make)
//   4. During the BBM handoff window (sel all-zero), phy lanes present the safe state (txelecidle=1)
//   5. phy_rst_n follows the current owner's ctrl_rst_n
//=============================================================================
import pipe_pkg::*;

module tb_pipe_lane_mapper;

    localparam int NUM_MODES  = 2;
    localparam int LANE_COUNT = 4;
    localparam int NUM_CTRL   = 2;

    //------------------------------------------------------------ clocks
    // Different period + phase offset per lane, to exercise asynchronous CDC.
    localparam int unsigned PERIOD_NS [0:3] = '{
        3,
        5,
        7,
        9
    };

    logic [LANE_COUNT-1:0] phy_pclk_out;

    for (genvar l = 0; l < LANE_COUNT; l++) begin : g_clk
        initial begin
            phy_pclk_out[l] = 1'b0;
            #(l * 0.7);
            forever #(PERIOD_NS[l] / 2.0) phy_pclk_out[l] = ~phy_pclk_out[l];
        end
    end

    //------------------------------------------------------------ DUT IO
    logic [LANE_COUNT-1:0]      phy_phystatus_stim = '0;
    logic                       test_en = 1'b0;
    logic [NUM_CTRL-1:0]        ctrl_rst_n = '0;
    logic [$clog2(NUM_MODES)-1:0] mode = '0;

    logic [NUM_CTRL-1:0]        ctrl_pclk;
    logic [LANE_COUNT-1:0]      phy_pclk_in;
    logic [LANE_COUNT-1:0]      phy_rst_n;

    mac2phy_lane_t [LANE_COUNT-1:0] phy_mac2phy;
    phy2mac_lane_t [LANE_COUNT-1:0] phy_phy2mac;

    mac2phy_lane_t [3:0] pcie_x4_mac2phy;
    phy2mac_lane_t [3:0] pcie_x4_phy2mac;
    mac2phy_lane_t [3:0] usb_x2_mac2phy;
    phy2mac_lane_t [3:0] usb_x2_phy2mac;

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
        .pcie_x4_mac2phy (pcie_x4_mac2phy),
        .pcie_x4_phy2mac (pcie_x4_phy2mac),
        .usb_x2_mac2phy (usb_x2_mac2phy),
        .usb_x2_phy2mac (usb_x2_phy2mac)
    );

    //------------------------------------------------------------ stimulus patterns
    function automatic mac2phy_lane_t make_m2p(input int cid, input int port);
        mac2phy_lane_t v;
        v = SAFE_M2P;
        v.mac_phy_txdata      = {4'(cid), 20'h0, 8'(port)};
        v.mac_phy_txdatak     = 4'(port);
        v.mac_phy_txdatavalid = 1'b1;
        v.mac_phy_txelecidle  = 1'b0;   // non-idle (may differ from the signal's safe state)
        v.mac_phy_rxstandby   = 1'b0;   // non-idle (may differ from the signal's safe state)
        return v;
    endfunction

    function automatic phy2mac_lane_t make_p2m(input int lane);
        phy2mac_lane_t v;
        v = SAFE_P2M;
        v.phy_mac_rxdata      = {8'hA5, 16'h0, 8'(lane)};
        v.phy_mac_rxdatak     = 4'(lane);
        v.phy_mac_rxdatavalid = 1'b1;
        v.phy_mac_rxelecidle      = 1'b0;  // non-idle (may differ from the signal's safe state)
        v.phy_mac_rxstandbystatus = 1'b0;  // non-idle (may differ from the signal's safe state)
        return v;
    endfunction

    always_comb begin
        for (int p = 0; p < 4; p++) pcie_x4_mac2phy[p] = make_m2p(0, p);
        for (int p = 0; p < 4; p++) usb_x2_mac2phy[p] = make_m2p(1, p);
        for (int l = 0; l < LANE_COUNT; l++) begin
            phy_phy2mac[l] = make_p2m(l);
            phy_phy2mac[l].phy_mac_phystatus = phy_phystatus_stim[l];
        end
    end

    //------------------------------------------------------------ expected mapping (from lane_mapping.csv)
    function automatic int owner_of(input int m, input int l);
        case (m)
            0: case (l)
                0: return 0;
                1: return 0;
                2: return 0;
                3: return 0;
                default: return -1;
            endcase
            1: case (l)
                0: return 0;
                1: return 0;
                2: return 1;
                3: return 1;
                default: return -1;
            endcase
            default: return -1;
        endcase
    endfunction

    function automatic int port_of(input int m, input int l);
        case (m)
            0: case (l)
                0: return 0;
                1: return 1;
                2: return 2;
                3: return 3;
                default: return -1;
            endcase
            1: case (l)
                0: return 0;
                1: return 1;
                2: return 0;
                3: return 1;
                default: return -1;
            endcase
            default: return -1;
        endcase
    endfunction

    //------------------------------------------------------------ BBM one-hot / safe-state monitor
    int unsigned err_count = 0;

    task automatic chk(input bit ok, input string msg);
        if (!ok) begin
            err_count++;
            $error("%0t: %s", $time, msg);
        end
    endtask

    localparam int G1_LANES[2] = '{2, 3};

    always @(dut.sel_tgt) begin
        chk($onehot0(dut.sel_tgt.g1), "sel_tgt.g1 not one-hot0 (>1 branch enabled)");

        if (dut.sel_tgt.g1 == '0)
            foreach (G1_LANES[i])
                chk(phy_mac2phy[G1_LANES[i]].mac_phy_txelecidle == 1'b1,
                    $sformatf("G1 lane%0d: sel==0 but txelecidle!=1 (safe state not shown in BBM gap)", G1_LANES[i]));
    end

    //------------------------------------------------------------ steady-state data-routing check
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
                $sformatf("mode%0d lane%0d: phy_mac2phy mismatch, expected ctrl%0d port%0d",
                          m, l, cid, port));

            chk(phy_rst_n[l] == ctrl_rst_n[cid],
                $sformatf("mode%0d lane%0d: phy_rst_n=%0b does not follow owner ctrl%0d",
                          m, l, phy_rst_n[l], cid));
        end

        for (int c = 0; c < NUM_CTRL; c++) begin
            int max_w = 4;
            for (int p = 0; p < max_w; p++) begin
                int src_lane;
                phy2mac_lane_t got;
                src_lane = -1;
                for (int l = 0; l < LANE_COUNT; l++)
                    if (owner_of(m, l) == c && port_of(m, l) == p) src_lane = l;

                case (c)
                    0: got = pcie_x4_phy2mac[p];
                    1: got = usb_x2_phy2mac[p];
                endcase

                if (src_lane == -1) begin
                    phy2mac_lane_t exp_tie;
                    int active_base;
                    exp_tie = SAFE_P2M;
                    active_base = -1;
                    for (int l = 0; l < LANE_COUNT; l++) begin
                        if (owner_of(m, l) == c && active_base == -1) active_base = l;
                    end
                    if (active_base != -1) begin
                        exp_tie.phy_mac_rxdata = 32'd0;
                        exp_tie.phy_mac_rxdatak = 4'd0;
                        exp_tie.phy_mac_rxdatavalid = 1'b0;
                        exp_tie.phy_mac_rxstartblock = 1'b0;
                        exp_tie.phy_mac_rxsyncheader = 2'd0;
                        exp_tie.phy_mac_rxvalid = 1'b0;
                        exp_tie.phy_mac_rxstatus = 3'd0;
                        exp_tie.phy_mac_rxelecidle = 1'b1;
                        exp_tie.phy_mac_rxstandbystatus = 1'b0;
                        exp_tie.phy_mac_messagebus = 8'd80;
                        exp_tie.phy_mac_phystatus = phy_phy2mac[active_base].phy_mac_phystatus;
                        exp_tie.phy_mac_local_tx_coef_valid = 1'b0;
                        exp_tie.phy_mac_local_tx_pset_coef = 18'd0;
                        exp_tie.phy_mac_localfs = 6'd0;
                        exp_tie.phy_mac_locallf = 6'd0;
                        exp_tie.phy_mac_dirfeedback = 6'd0;
                        exp_tie.phy_mac_fomfeedback = 8'd0;
                    end else begin
                        exp_tie.phy_mac_rxdata = 32'd0;
                        exp_tie.phy_mac_rxdatak = 4'd0;
                        exp_tie.phy_mac_rxdatavalid = 1'b0;
                        exp_tie.phy_mac_rxstartblock = 1'b0;
                        exp_tie.phy_mac_rxsyncheader = 2'd0;
                        exp_tie.phy_mac_rxvalid = 1'b0;
                        exp_tie.phy_mac_rxstatus = 3'd0;
                        exp_tie.phy_mac_rxelecidle = 1'b1;
                        exp_tie.phy_mac_rxstandbystatus = 1'b0;
                        exp_tie.phy_mac_messagebus = 8'd80;
                        exp_tie.phy_mac_phystatus = '0;
                        exp_tie.phy_mac_local_tx_coef_valid = 1'b0;
                        exp_tie.phy_mac_local_tx_pset_coef = 18'd0;
                        exp_tie.phy_mac_localfs = 6'd0;
                        exp_tie.phy_mac_locallf = 6'd0;
                        exp_tie.phy_mac_dirfeedback = 6'd0;
                        exp_tie.phy_mac_fomfeedback = 8'd0;
                    end
                    chk(got == exp_tie,
                        $sformatf("mode%0d ctrl%0d[%0d]: unmapped tie-off mismatch!", m, c, p));
                end else begin
                    exp_p2m = make_p2m(src_lane);
                    chk(got.phy_mac_rxdata == exp_p2m.phy_mac_rxdata &&
                        got.phy_mac_rxdatavalid == 1'b1 && got.phy_mac_rxelecidle == 1'b0,
                        $sformatf("mode%0d ctrl%0d[%0d]: expected lane%0d data", m, c, p, src_lane));
                end
            end
        end

        $display("%0t: mode%0d checked (%0d cumulative errors)", $time, m, err_count);
    endtask

    //------------------------------------------------------------ sequencing
    localparam realtime SETTLE = 180;

    initial begin
`ifdef DUMP_FSDB
        $fsdbDumpfile("waves.fsdb");
        $fsdbDumpvars(0, tb_pipe_lane_mapper, "+all");
`else
        $dumpfile("waves.vcd");
        $dumpvars(0, tb_pipe_lane_mapper);
`endif

        ctrl_rst_n = '0;
        mode = '0;
        #100;
        ctrl_rst_n = '1;
        #SETTLE;

        check_mode(0);
        // toggle physical lane 0's phystatus and dynamically verify it's followed correctly
        phy_phystatus_stim[0] = 1'b1; #20;
        check_mode(0);
        phy_phystatus_stim[0] = 1'b0; #20;
        check_mode(0);
        mode = 1; #SETTLE;
        check_mode(1);
        // toggle physical lane 0's phystatus and dynamically verify it's followed correctly
        phy_phystatus_stim[0] = 1'b1; #20;
        check_mode(1);
        phy_phystatus_stim[0] = 1'b0; #20;
        check_mode(1);

        // non-adjacent jump
        mode = 0; #SETTLE; check_mode(0);
        mode = 1; #SETTLE; check_mode(1);

        // reset pulse checks in mode1
        // pulse each controller: its owner lanes' phy_rst_n should follow low, non-owner lanes stay high.
        ctrl_rst_n[0] = 1'b0; #SETTLE;
        for (int l = 0; l < LANE_COUNT; l++) begin
            bit expect_low;
            expect_low = (owner_of(1, l) == 0);
            chk(phy_rst_n[l] == (expect_low ? 1'b0 : 1'b1),
                $sformatf("mode1 lane%0d: ctrl_rst_n[0]=0 pulse, expected phy_rst_n=%0b", l, expect_low ? 1'b0 : 1'b1));
        end
        $display("%0t: ctrl_rst_n[0] pulse checked (%0d cumulative errors)", $time, err_count);
        ctrl_rst_n[0] = 1'b1; #SETTLE;
        check_mode(1);
        ctrl_rst_n[1] = 1'b0; #SETTLE;
        for (int l = 0; l < LANE_COUNT; l++) begin
            bit expect_low;
            expect_low = (owner_of(1, l) == 1);
            chk(phy_rst_n[l] == (expect_low ? 1'b0 : 1'b1),
                $sformatf("mode1 lane%0d: ctrl_rst_n[1]=0 pulse, expected phy_rst_n=%0b", l, expect_low ? 1'b0 : 1'b1));
        end
        $display("%0t: ctrl_rst_n[1] pulse checked (%0d cumulative errors)", $time, err_count);
        ctrl_rst_n[1] = 1'b1; #SETTLE;
        check_mode(1);

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
