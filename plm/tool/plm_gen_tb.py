#!/usr/bin/env python3
"""
PIPE Lane Mapper testbench generator.

Generates a self-checking testbench for a config set, written to
<SET>/tb/tb_pipe_lane_mapper.sv, plus a copy of the VCS/Verdi simulation
Makefile (tool/tb_makefile.mk) alongside it.

RTL generation is a separate tool (tool/plm_gen_rtl.py) -- run it too if
you also need <SET>/rtl/ regenerated. Pass both tools the same
--pclk-mode: the testbench instantiates the DUT with that mode's port
list, so a mismatch produces a testbench that doesn't compile against the
RTL (or, worse, compiles against a stale rtl/ from a previous run).

Directory convention -- see tool/plm_gen_rtl.py's docstring for the full
layout; this tool only touches <SET>/tb/.
"""

import argparse
import json
import shutil
import sys
from pathlib import Path

SCRIPT_DIR = Path(__file__).resolve().parent  # .../plm/tool

sys.path.insert(0, str(SCRIPT_DIR))
from plm_config import load  # noqa: E402
from plm_common import (  # noqa: E402
    TB_MAKEFILE,
    apply_set_flags,
    format_sv,
    load_set_flags,
    mode_width,
    resolve_set,
    validate_arch,
)


def _emit_clk_period_chk(L, indent, sig_expr, exp_ns_expr, ctx_expr):
    """Append a self-contained block measuring sig_expr's period (two
    consecutive posedges) and checking it against exp_ns_expr, +-20%
    tolerance -- enough to catch a wrong candidate clock (this tb's
    simulated periods differ by >=2ns by construction) without
    false-failing on jitter from whichever edge of two candidate clocks a
    glitch-free switch happens to land on. Self-contained (own begin/end,
    own locals) so it can be dropped inside any loop/case without name
    clashes with a sibling block's own t0/got_ns/exp_ns.
    """
    ind = " " * indent
    L.append(f"{ind}begin")
    L.append(f"{ind}    time t0;")
    L.append(f"{ind}    real got_ns, exp_ns;")
    L.append(f"{ind}    int unsigned err_before;")
    L.append(f"{ind}    exp_ns = {exp_ns_expr};")
    L.append(f"{ind}    @(posedge {sig_expr}); t0 = $time;")
    L.append(f"{ind}    @(posedge {sig_expr}); got_ns = $time - t0;")
    L.append(f"{ind}    err_before = err_count;")
    L.append(f"{ind}    chk((got_ns > exp_ns * 0.8) && (got_ns < exp_ns * 1.2),")
    L.append(
        f'{ind}        $sformatf("%s: measured period %0.2fns, expected ~%0.2fns", {ctx_expr}, got_ns, exp_ns));'
    )
    L.append(f"{ind}    err_clock += (err_count - err_before);")
    L.append(f"{ind}end")


def gen_tb(cfg, pclk_mode="pclk_as_phy_output", dpr=False):
    """Generate a self-checking testbench for this config set, written to
    <set>/tb/tb_pipe_lane_mapper.sv.

    Checks:
      1. Steady-state data routing matches lane_mapping.csv exactly
      2. Unmapped controller ports read back SAFE_P2M
      3. Group sel vectors are always one-hot0 (non-overlap)
      4. During the NOV handoff window (sel all-zero), phy lanes present the safe state
      5. phy_rst_n follows the current owner's ctrl_rst_n
    """
    nm = len(cfg.modes)
    LC, NC = cfg.lane_count, cfg.num_ctrl
    ctrls = [cfg.controllers[c] for c in sorted(cfg.controllers)]
    muxed = [g for g in cfg.groups if not g.is_direct]
    phy_input_mode = pclk_mode == "pclk_as_phy_input"
    # make_m2p/make_p2m below poke a few well-known real-PIPE signal names
    # (mac_phy_txdatak, phy_mac_phystatus, ...) to make the stimulus more
    # than just the one identity-encoding field -- but pipe_signals.csv is
    # fully user-defined, so a config that doesn't happen to include one of
    # these under this exact name must not reference it as a struct field
    # (a hard compile error), it must just skip that extra touch.
    sig_names = {s.name for s in cfg.signals}

    # Give each lane (or, in pclk_as_phy_input mode, each controller) a
    # different clock period + phase offset, to exercise asynchronous CDC. Period
    # range 3..15ns; SETTLE is the slowest period * 20 (>=3 sync stages
    # plus hold margin), floored at 2us so each mode gets a comfortably
    # long, easy-to-read window between transitions.
    periods = [3 + (l % 7) * 2 for l in range(LC)]
    ctrl_periods = [3 + (c % 7) * 2 for c in range(NC)]
    lane_periods = [5 + (l % 7) * 2 for l in range(LC)]  # rx_clk, offset from ctrl_periods' phase
    settle = max(2000, (max(ctrl_periods) if phy_input_mode else max(periods)) * 20)

    L = [
        "`timescale 1ns/1ps",
        "//=============================================================================",
        "// tb_pipe_lane_mapper -- self-checking functional simulation, driven by this config set's lane_mapping.csv.",
        "//",
        "// Checks:",
        "//   1. Steady-state data routing matches lane_mapping.csv exactly",
        "//   2. Unmapped controller ports read back SAFE_P2M",
        "//   3. Group sel vectors are always one-hot0 (non-overlap)",
        "//   4. During the NOV handoff window (sel all-zero), phy lanes present the safe state (txelecidle=1)",
        "//   5. phy_rst_n follows the current owner's ctrl_rst_n",
        "//=============================================================================",
        "import pipe_lane_signal_pkg::*;",
        "",
        "module tb_pipe_lane_mapper;",
        "",
    ]

    L.append(f"    localparam int NL = {LC};")
    L.append(f"    localparam int NC   = {NC};")
    L.append("")

    # ---- clocks
    L.append("    //------------------------------------------------------------ clocks")
    if phy_input_mode:
        L.append("    // Different period + phase offset per controller (its own reference")
        L.append("    // clock) and per lane (rx_clk), to exercise asynchronous CDC.")
        L.append(f"    localparam int unsigned CTRL_PERIOD_NS [0:{NC-1}] = '{{")
        for i, p in enumerate(ctrl_periods):
            L.append(f"        {p}{',' if i != NC-1 else ''}")
        L.append("    };")
        L.append(f"    localparam int unsigned LANE_PERIOD_NS [0:{LC-1}] = '{{")
        for i, p in enumerate(lane_periods):
            L.append(f"        {p}{',' if i != LC-1 else ''}")
        L.append("    };")
        L.append("")
        L.append("    logic [NC-1:0] ctrl_ref_clk;")
        L.append("    logic [NL-1:0] rx_clk;")
        L.append("")
        L.append("    for (genvar c = 0; c < NC; c++) begin : g_ctrl_clk")
        L.append("        initial begin")
        L.append("            ctrl_ref_clk[c] = 1'b0;")
        L.append("            #(c * 0.7);")
        L.append("            forever #(CTRL_PERIOD_NS[c] / 2.0) ctrl_ref_clk[c] = ~ctrl_ref_clk[c];")
        L.append("        end")
        L.append("    end")
        L.append("")
        L.append("    for (genvar l = 0; l < NL; l++) begin : g_rx_clk")
        L.append("        initial begin")
        L.append("            rx_clk[l] = 1'b0;")
        L.append("            #(l * 0.9 + 0.3);")
        L.append("            forever #(LANE_PERIOD_NS[l] / 2.0) rx_clk[l] = ~rx_clk[l];")
        L.append("        end")
        L.append("    end")
        L.append("")
        for c in ctrls:
            L.append(f"    logic [{c.max_width-1}:0] {c.lname}_pclk;")
            L.append(f"    logic [{c.max_width-1}:0] {c.lname}_rx_clk;")
            L.append(
                f"    assign {c.lname}_pclk = {{{c.max_width}{{ctrl_ref_clk[{c.id}]}}}};"
                f"  // no division modeled -- every port bit is the same undivided clock"
            )
        L.append("")
    else:
        L.append("    // Different period + phase offset per lane, to exercise asynchronous CDC.")
        L.append(f"    localparam int unsigned PERIOD_NS [0:{LC-1}] = '{{")
        for i, p in enumerate(periods):
            L.append(f"        {p}{',' if i != LC-1 else ''}")
        L.append("    };")
        L.append("")
        L.append("    logic [NL-1:0] phy_pclk_out;")
        L.append("")
        L.append("    for (genvar l = 0; l < NL; l++) begin : g_clk")
        L.append("        initial begin")
        L.append("            phy_pclk_out[l] = 1'b0;")
        L.append("            #(l * 0.7);")
        L.append("            forever #(PERIOD_NS[l] / 2.0) phy_pclk_out[l] = ~phy_pclk_out[l];")
        L.append("        end")
        L.append("    end")
        L.append("")

    # ---- DUT IO
    L.append("    //------------------------------------------------------------ DUT IO")
    L.append("    logic [NL-1:0]      phy_phystatus_stim = '0;")
    L.append("    logic                       test_en = 1'b0;")
    # ctrl_rst_n stays one packed stimulus vector here (indexed by ctrl id --
    # convenient for the reset-pulse loop below), but the DUT's own ports
    # are per-controller named signals (ctrla_rst_n, ...) now -- see the
    # DUT instance below, which wires ctrl_rst_n[cid] to each one.
    L.append("    logic [NC-1:0]        ctrl_rst_n = '0;")
    L.append(f"    logic [{mode_width(nm)-1}:0] mode = '0;")
    L.append("")
    L.append(f"    logic [NL-1:0]      {'phy_pclk' if phy_input_mode else 'phy_pclk_in'};")
    L.append("    logic [NL-1:0]      phy_rst_n;")
    L.append("")
    L.append("    mac2phy_lane_t [NL-1:0] phy_mac2phy;")
    L.append("    phy2mac_lane_t [NL-1:0] phy_phy2mac;")
    L.append("")
    for c in ctrls:
        L.append(f"    mac2phy_lane_t [{c.max_width-1}:0] {c.lname}_mac2phy;")
        L.append(f"    phy2mac_lane_t [{c.max_width-1}:0] {c.lname}_phy2mac;")
        if not phy_input_mode:
            L.append(f"    logic {c.lname}_pclk;   // {c.name}'s own derived working clock, DUT output")
    L.append("")

    if dpr:
        L.append("    // DPR (diagnostic probe): idle by default -- v_lane_mask all-zero means")
        L.append("    // it never actually overrides any lane, regardless of dpr_rst_n/dpr_mac2phy.")
        L.append("    logic [NL-1:0] v_lane_mask = '0;")
        L.append("    logic dpr_rst_n = 1'b1;")
        L.append("    mac2phy_lane_t [NL-1:0] dpr_mac2phy = '0;")
        L.append("    phy2mac_lane_t [NL-1:0] dpr_phy2mac;")
        L.append("    logic dpr_pclk;   // DPR's own derived working clock, DUT output")
        L.append("")

    # ---- DUT instance
    L.append("    pipe_lane_mapper #(")
    L.append("        .NL (NL),")
    L.append("        .NC (NC)")
    L.append("    ) dut (")
    if phy_input_mode:
        L.append("        .test_en        (test_en),")
        L.append("        .mode           (mode),")
        L.append("        .rx_clk         (rx_clk),")
        L.append("        .phy_pclk       (phy_pclk),")
        L.append("        .phy_rst_n      (phy_rst_n),")
        L.append("        .phy_mac2phy    (phy_mac2phy),")
        L.append("        .phy_phy2mac    (phy_phy2mac),")
        if dpr:
            L.append("        .v_lane_mask    (v_lane_mask),")
            L.append("        .dpr_rst_n      (dpr_rst_n),")
            L.append("        .dpr_mac2phy    (dpr_mac2phy),")
            L.append("        .dpr_phy2mac    (dpr_phy2mac),")
            L.append("        .dpr_pclk       (dpr_pclk),")
        for c in ctrls:
            L.append(f"        .{c.lname}_rst_n   (ctrl_rst_n[{c.id}]),")
            L.append(f"        .{c.lname}_mac2phy ({c.lname}_mac2phy),")
            L.append(f"        .{c.lname}_phy2mac ({c.lname}_phy2mac),")
            L.append(f"        .{c.lname}_pclk    ({c.lname}_pclk),")
            L.append(f"        .{c.lname}_rx_clk  ({c.lname}_rx_clk),")
    else:
        L.append("        .phy_pclk_out   (phy_pclk_out),")
        L.append("        .test_en        (test_en),")
        L.append("        .mode           (mode),")
        L.append("        .phy_pclk_in    (phy_pclk_in),")
        L.append("        .phy_rst_n      (phy_rst_n),")
        L.append("        .phy_mac2phy    (phy_mac2phy),")
        L.append("        .phy_phy2mac    (phy_phy2mac),")
        if dpr:
            L.append("        .v_lane_mask    (v_lane_mask),")
            L.append("        .dpr_rst_n      (dpr_rst_n),")
            L.append("        .dpr_mac2phy    (dpr_mac2phy),")
            L.append("        .dpr_phy2mac    (dpr_phy2mac),")
            L.append("        .dpr_pclk       (dpr_pclk),")
        for c in ctrls:
            L.append(f"        .{c.lname}_rst_n   (ctrl_rst_n[{c.id}]),")
            L.append(f"        .{c.lname}_mac2phy ({c.lname}_mac2phy),")
            L.append(f"        .{c.lname}_phy2mac ({c.lname}_phy2mac),")
            L.append(f"        .{c.lname}_pclk    ({c.lname}_pclk),")
    L[-1] = L[-1].rstrip(",")
    L.append("    );")
    L.append("")

    # ---- stimulus patterns
    L.append("    //------------------------------------------------------------ stimulus patterns")
    L.append("    function automatic mac2phy_lane_t make_m2p(input int cid, input int port);")
    L.append("        mac2phy_lane_t v;")
    L.append("        v = SAFE_M2P;")
    if "mac_phy_txdata" in sig_names:
        L.append("        v.mac_phy_txdata      = {4'(cid), 20'h0, 8'(port)};")
    if "mac_phy_txdatak" in sig_names:
        L.append("        v.mac_phy_txdatak     = 4'(port);")
    if "mac_phy_txdatavalid" in sig_names:
        L.append("        v.mac_phy_txdatavalid = 1'b1;")
    if "mac_phy_txelecidle" in sig_names:
        L.append(
            "        v.mac_phy_txelecidle  = 1'b0;   // non-idle (may differ from the signal's safe state)"
        )
    if "mac_phy_rxstandby" in sig_names:
        L.append(
            "        v.mac_phy_rxstandby   = 1'b0;   // non-idle (may differ from the signal's safe state)"
        )
    L.append("        return v;")
    L.append("    endfunction")
    L.append("")
    L.append("    function automatic phy2mac_lane_t make_p2m(input int lane);")
    L.append("        phy2mac_lane_t v;")
    L.append("        v = SAFE_P2M;")
    if "phy_mac_rxdata" in sig_names:
        L.append("        v.phy_mac_rxdata      = {8'hA5, 16'h0, 8'(lane)};")
    if "phy_mac_rxdatak" in sig_names:
        L.append("        v.phy_mac_rxdatak     = 4'(lane);")
    if "phy_mac_rxdatavalid" in sig_names:
        L.append("        v.phy_mac_rxdatavalid = 1'b1;")
    if "phy_mac_rxelecidle" in sig_names:
        L.append(
            "        v.phy_mac_rxelecidle      = 1'b0;  // non-idle (may differ from the signal's safe state)"
        )
    if "phy_mac_rxstandbystatus" in sig_names:
        L.append(
            "        v.phy_mac_rxstandbystatus = 1'b0;  // non-idle (may differ from the signal's safe state)"
        )
    L.append("        return v;")
    L.append("    endfunction")
    L.append("")
    L.append("    always_comb begin")
    for c in ctrls:
        L.append(
            f"        for (int p = 0; p < {c.max_width}; p++) "
            f"{c.lname}_mac2phy[p] = make_m2p({c.id}, p);"
        )
    L.append("        for (int l = 0; l < NL; l++) begin")
    L.append("            phy_phy2mac[l] = make_p2m(l);")
    if "phy_mac_phystatus" in sig_names:
        L.append("            phy_phy2mac[l].phy_mac_phystatus = phy_phystatus_stim[l];")
    L.append("        end")
    L.append("    end")
    L.append("")

    # ---- expected mapping
    L.append(
        "    //------------------------------------------------------------ expected mapping (from lane_mapping.csv)"
    )
    L.append("    function automatic int owner_of(input int m, input int l);")
    L.append("        case (m)")
    for m in cfg.modes:
        L.append(f"            {m}: case (l)")
        for l in range(LC):
            cid, _ = cfg.mapping[m][l]
            L.append(f"                {l}: return {cid};")
        L.append("                default: return -1;")
        L.append("            endcase")
    L.append("            default: return -1;")
    L.append("        endcase")
    L.append("    endfunction")
    L.append("")
    L.append("    function automatic int port_of(input int m, input int l);")
    L.append("        case (m)")
    for m in cfg.modes:
        L.append(f"            {m}: case (l)")
        for l in range(LC):
            _, cl = cfg.mapping[m][l]
            L.append(f"                {l}: return {cl};")
        L.append("                default: return -1;")
        L.append("            endcase")
    L.append("            default: return -1;")
    L.append("        endcase")
    L.append("    endfunction")
    L.append("")

    if not phy_input_mode:
        # ctrl_pclk always takes its candidate from "the lowest-numbered
        # lane in its group" (see gen_clk_mux_phy_output's own comment) --
        # this mirrors that exact rule, so the clock-frequency check below
        # knows which phy_pclk_out[] lane {c}_pclk/phy_pclk_in should
        # currently be tracking.
        L.append("    function automatic int ctrl_pclk_src_lane(input int m, input int cid);")
        L.append("        for (int l = 0; l < NL; l++)")
        L.append("            if (owner_of(m, l) == cid) return l;")
        L.append("        return -1;")
        L.append("    endfunction")
        L.append("")

    # ---- NOV monitor
    L.append(
        "    //------------------------------------------------------------ NOV one-hot / safe-state monitor"
    )
    # err_count is the aggregate used for the final TB_RESULT; each test
    # case below (clock/reset/m2p/p2m/tie_off/safe_state[/dpr]) also gets
    # its own counter, so the summary at the end can report each case's
    # own PASS/FAIL instead of one undifferentiated error count.
    # chk/chk_m2p/chk_p2m themselves are completely untouched from before
    # this per-case breakdown existed (same signatures, same bodies) --
    # every category-tracking mechanism that touched them in any way (a
    # `ref int unsigned` argument, a plain `input string` argument, a
    # module-level `string`/`int` "current category" variable chk() reads
    # internally) segfaulted verilator's own runtime once actually run
    # against this file's real scale, even though every one of them lints
    # clean and a small isolated repro of the same pattern runs fine in
    # isolation. Instead, each call site below reads err_count itself
    # (snapshot before, diff after) and bumps its own category's counter
    # by the delta -- chk() never knows or cares which category called it.
    L.append("    int unsigned err_count = 0;")
    case_names = ["clock", "reset", "m2p", "p2m", "tie_off", "safe_state"]
    if dpr:
        case_names.append("dpr")
    L.append("    int unsigned " + ", ".join(f"err_{n} = 0" for n in case_names) + ";")
    L.append("")
    L.append("    task automatic chk(input bit ok, input string msg);")
    L.append("        if (!ok) begin")
    L.append("            err_count++;")
    L.append('            $error("%0t: %s", $time, msg);')
    L.append("        end")
    L.append("    endtask")
    L.append("")

    # Per-field struct comparison, so a mismatch reports exactly which
    # signal differs (and its actual/expected values) instead of just
    # "the struct doesn't match" -- every whole-struct/multi-field
    # comparison in this tb goes through these two tasks.
    m2p_signals = [s for s in cfg.signals if s.is_m2p]
    p2m_signals_all = [s for s in cfg.signals if not s.is_m2p]
    L.append(
        "    task automatic chk_m2p(input mac2phy_lane_t got, input mac2phy_lane_t exp, input string ctx);"
    )
    for s in m2p_signals:
        L.append(f"        chk(got.{s.name} == exp.{s.name},")
        L.append(
            f'            $sformatf("%s: {s.name} mismatch, got=%0h expected=%0h", ctx, got.{s.name}, exp.{s.name}));'
        )
    L.append("    endtask")
    L.append("")
    L.append(
        "    task automatic chk_p2m(input phy2mac_lane_t got, input phy2mac_lane_t exp, input string ctx);"
    )
    for s in p2m_signals_all:
        L.append(f"        chk(got.{s.name} == exp.{s.name},")
        L.append(
            f'            $sformatf("%s: {s.name} mismatch, got=%0h expected=%0h", ctx, got.{s.name}, exp.{s.name}));'
        )
    L.append("    endtask")
    L.append("")
    if muxed or dpr:
        for g in muxed:
            lanes_str = ", ".join(str(l) for l in g.lanes)
            L.append(f"    localparam int G{g.gid}_LANES[{len(g.lanes)}] = " f"'{{{lanes_str}}};")
        L.append("")

        # Independently (not by probing DUT internals) compute, per
        # candidate controller of a muxed group, the p2m struct it should
        # present when its group's sel is all-zero. Mirrors
        # *_p2m_tie in gen_data_p2m(), built from the same
        # Signal.tie_expr(), but kept as a separate tb-side computation so
        # this is a real external check of the DUT's behavior, not a
        # tautology against its own internal signal. With --dpr, every
        # group is at least a 2-candidate one (real + DPR, see
        # gen_data_p2m) even if it was a direct (single-candidate) group
        # before DPR existed -- the dpr test below needs "should this
        # candidate read SAFE_P2M while DPR owns its lane" for every
        # controller, not just the ones already muxed absent DPR, so this
        # covers every controller in that case instead of just
        # muxed_ctrl_ids.
        muxed_ctrl_ids = sorted({c for g in muxed for c in g.cands} | (set(cfg.controllers) if dpr else set()))
        cc = cfg.ctrl_pclk_cands()
        p2m_signals = [s for s in cfg.signals if not s.is_m2p]
        for cid in muxed_ctrl_ids:
            c = cfg.controllers[cid]
            cands = cc[cid]
            base_lane = cands[0] if cands else 0
            base_lane_expr = f"phy_phy2mac[{base_lane}]"
            assign_parts = [
                f"{s.name}: {s.tie_expr(base_lane_expr)}" for s in p2m_signals if not s.tie_is_zero
            ]
            assign_parts.append("default: '0")
            L.append(f"    phy2mac_lane_t exp_safe_p2m_{c.lname};")
            L.append(f"    assign exp_safe_p2m_{c.lname} = '{{")
            for part in assign_parts[:-1]:
                L.append(f"        {part},")
            L.append(f"        {assign_parts[-1]}")
            L.append("    };")
        L.append("")

        if dpr:
            # DPR's own tie value when it doesn't own a lane -- same
            # tie_expr(None) used by gen_data_p2m()'s own dpr_p2m_tie
            # (tie_off=lane0 has no meaningful "DPR's own base lane", so
            # it resolves to '0 there too), computed independently here so
            # the dpr test below is a real external check, not a
            # tautology against the DUT's own internal tie constant.
            dpr_tie_parts = [f"{s.name}: {s.tie_expr(None)}" for s in p2m_signals if not s.tie_is_zero]
            dpr_tie_parts.append("default: '0")
            L.append("    phy2mac_lane_t exp_dpr_tie;")
            L.append("    assign exp_dpr_tie = '{")
            for part in dpr_tie_parts[:-1]:
                L.append(f"        {part},")
            L.append(f"        {dpr_tie_parts[-1]}")
            L.append("    };")
            L.append("")

        if phy_input_mode:
            # sel_tgt doesn't exist as a group-level signal in this mode --
            # each BBM lane has its own independent seltgt_g{gid}_l{l}, so
            # the monitor is per lane, not per group. Every candidate's own
            # designated port for that lane is checked individually against
            # that candidate's own bit, not gated on the whole group being
            # idle -- see gen_data_p2m()'s docstring: a port's mux output is
            # governed entirely by its own owning candidate's single bit.
            L.append("    //------------------------------------------------------------")
            L.append("    // NOV monitor: one per BBM lane (each lane's seltgt is its own")
            L.append("    // independent sync result, not shared across the group).")
            L.append("    //------------------------------------------------------------")
            for g in muxed:
                for l in g.lanes:
                    port_of_cand = {}
                    for c in g.cands:
                        m = next(mm for mm in cfg.modes if g.owners[mm] == c)
                        port_of_cand[c] = cfg.mapping[m][l][1]
                    n = g.n
                    L.append(f"    always @(dut.seltgt_g{g.gid}_l{l}) begin")
                    L.append("        if ($time == 0) begin")
                    L.append("            // skip: DUT hasn't come out of its startup X state yet")
                    L.append("        end else begin")
                    L.append(f"            logic [{n-1}:0] sel_snap;")
                    L.append("            int unsigned err_before;")
                    # dut.seltgt_g{gid}_l{l} is DPR-widened when --dpr (g.n+1
                    # bits: real candidates in the low g.n bits, DPR at bit
                    # g.n), but this monitor only cares about real-candidate
                    # ownership -- sel_snap stays at the real width above, so
                    # slice explicitly here rather than let the assignment
                    # truncate implicitly. Those low bits are already
                    # all-zero whenever the sliced-off DPR bit is the one
                    # set (seltgt is one-hot), so this correctly reads as
                    # "no real candidate owns this lane" while DPR does.
                    snap_rhs = f"dut.seltgt_g{g.gid}_l{l}[{n-1}:0]" if dpr else f"dut.seltgt_g{g.gid}_l{l}"
                    L.append(f"            sel_snap = {snap_rhs};")
                    L.append("            #1;")
                    L.append("            err_before = err_count;")
                    L.append(
                        f'            chk($onehot0(sel_snap), "seltgt_g{g.gid}_l{l} not one-hot0 (>1 branch enabled)");'
                    )
                    L.append("")
                    L.append(f"            if (sel_snap == '0 && dut.seltgt_g{g.gid}_l{l} == '0)")
                    L.append(f"                chk_m2p(phy_mac2phy[{l}], SAFE_M2P,")
                    L.append(f'                    "G{g.gid} lane{l}: sel==0 NOV gap");')
                    L.append("")
                    for i, c in enumerate(g.cands):
                        cc_ = cfg.controllers[c]
                        cl = port_of_cand[c]
                        L.append(
                            f"            if (sel_snap[{i}] == 1'b0 && dut.seltgt_g{g.gid}_l{l}[{i}] == 1'b0)"
                        )
                        L.append(
                            f"                chk_p2m({cc_.lname}_phy2mac[{cl}], exp_safe_p2m_{cc_.lname},"
                        )
                        L.append(f'                    "G{g.gid} {cc_.name}[{cl}]: not owner");')
                    L.append("            err_safe_state += (err_count - err_before);")
                    L.append("        end")
                    L.append("    end")
                    L.append("")
            L.append("")
            muxed = []  # skip the group-level monitor below

        # Precompute, per muxed group, which (controller, port) pairs are
        # actually routed through it -- validate() guarantees a port's
        # drivers never span more than one group, so this is unambiguous.
        port_group = {}
        for m in cfg.modes:
            for l in range(LC):
                cid, cl = cfg.mapping[m][l]
                g = cfg.group_of_lane(l)
                if not g.is_direct:
                    port_group[(cid, cl)] = g.gid

        if muxed:
            L.append("    always @(dut.sel_tgt) begin")
            # dut.sel_tgt's very first transition (X -> its reset value) lands
            # at time 0, before controller/phy stimulus or resets have
            # actually propagated through the DUT -- everything downstream is
            # still X at that instant. Checking then would flag that normal
            # startup transient as a failure, not a real DUT defect, so skip
            # this trigger entirely and let the real checks start once
            # check_mode() is called later in the initial block's sequencing.
            L.append("        if ($time == 0) begin")
            L.append("            // skip: DUT hasn't come out of its startup X state yet")
            L.append("        end else begin")
            # Snapshot sel_tgt immediately (it's the signal that triggered this
            # block, already valid), then let a small delay pass before
            # checking anything downstream of it. phy_mac2phy/ctrlX_phy2mac
            # are combinational functions of sel_tgt computed through the
            # DUT's pipe_lane_data_mux chain (an always_comb feeding a separate
            # continuous assign) -- reading them in the very same trigger as
            # sel_tgt's own change races that propagation, with no guarantee
            # it has settled yet.
            #
            # The #1 delay can straddle a REAL subsequent transition, not just
            # the delta-cycle settling it's meant to wait out: each group's
            # sel_tgt bits are produced by independent per-branch synchronizers
            # clocked by that branch's own controller pclk (pipe_lane_sel_sync),
            # so with 3+ branches on unrelated clocks it's easy for the very
            # next branch's synchronizer to complete its non-overlap
            # handoff within that same 1ns -- e.g. a group cycling straight from
            # its highest bit back to its lowest one (mode wrap-around) can spend
            # only a couple ns in the all-zero gap before the incoming branch's
            # enable lands. If that happens, dut.sel_tgt has already moved past
            # the snapshot by the time we check, so the snapshot's "still in the
            # gap" expectation is stale -- re-read dut.sel_tgt after the delay
            # and only assert the safe-state expectation if the group is STILL
            # all-zero there; otherwise this trigger's gap already ended and the
            # next dut.sel_tgt edge (already guaranteed, since it just changed)
            # will re-enter this block and check the new state correctly.
            L.append("            lane_sel_t sel_snap;")
            L.append("            int unsigned err_before;")
            L.append("            sel_snap = dut.sel_tgt;")
            L.append("            #1;")
            L.append("            err_before = err_count;")
            for g in muxed:
                L.append(
                    f"            chk($onehot0(sel_snap.g{g.gid}), "
                    f'"sel_tgt.g{g.gid} not one-hot0 (>1 branch enabled)");'
                )
            L.append("")
            for g in muxed:
                L.append(
                    f"            if (sel_snap.g{g.gid} == '0 && dut.sel_tgt.g{g.gid} == '0) begin"
                )
                L.append(f"                foreach (G{g.gid}_LANES[i])")
                L.append(f"                    chk_m2p(phy_mac2phy[G{g.gid}_LANES[i]], SAFE_M2P,")
                L.append(
                    f'                        $sformatf("G{g.gid} lane%0d: sel==0 NOV gap", G{g.gid}_LANES[i]));'
                )
                for (cid, cl), gid in sorted(port_group.items()):
                    if gid != g.gid:
                        continue
                    c = cfg.controllers[cid]
                    L.append(
                        f"                chk_p2m({c.lname}_phy2mac[{cl}], exp_safe_p2m_{c.lname},"
                    )
                    L.append(f'                    "G{g.gid} {c.name}[{cl}]: sel==0 NOV gap");')
                L.append("            end")
            L.append("            err_safe_state += (err_count - err_before);")
            L.append("        end")
            L.append("    end")
    else:
        L.append(
            "    // This topology is all direct connections; no NOV groups, nothing to monitor."
        )
    L.append("")

    # ---- check_mode: one task covering every per-mode test case
    # (m2p/reset/clocks/p2m/tie_off), each still counted separately via
    # chk()'s category argument. This used to be five separate tasks, one
    # per case, called in sequence from here -- but that structure
    # segfaulted verilator's own runtime on this file's actual scale (the
    # DUT's real port/struct width, not reproducible in a small isolated
    # test case); a single task, same shape this file used before this
    # test-case reporting was added, doesn't. The per-case PASS/FAIL
    # breakdown the categories give at the end doesn't need five separate
    # SV tasks to work -- chk()'s own category dispatch is what actually
    # provides it.
    L.append(
        "    //------------------------------------------------------------ steady-state data-routing check"
    )
    L.append("    task automatic check_mode(input int m);")
    L.append("        mac2phy_lane_t exp_m2p;")
    L.append("        phy2mac_lane_t exp_p2m;")
    L.append("        int cid, port;")
    L.append("        int unsigned err_before;")
    L.append("")
    L.append("        for (int l = 0; l < NL; l++) begin")
    L.append("            cid  = owner_of(m, l);")
    L.append("            port = port_of(m, l);")
    L.append("            exp_m2p = make_m2p(cid, port);")
    L.append("            err_before = err_count;")
    L.append("            chk_m2p(phy_mac2phy[l], exp_m2p,")
    L.append(
        '                $sformatf("mode%0d lane%0d: expected ctrl%0d port%0d", m, l, cid, port));'
    )
    L.append("            err_m2p += (err_count - err_before);")
    L.append("")
    L.append("            err_before = err_count;")
    L.append("            chk(phy_rst_n[l] == ctrl_rst_n[cid],")
    L.append(
        '                $sformatf("mode%0d lane%0d: phy_rst_n=%0b does not follow owner ctrl%0d",'
    )
    L.append("                          m, l, phy_rst_n[l], cid));")
    L.append("            err_reset += (err_count - err_before);")
    L.append("")
    if phy_input_mode:
        _emit_clk_period_chk(
            L,
            12,
            "phy_pclk[l]",
            "CTRL_PERIOD_NS[cid]",
            '$sformatf("mode%0d lane%0d phy_pclk", m, l)',
        )
    else:
        L.append("            begin")
        L.append("                int src_lane;")
        L.append("                src_lane = ctrl_pclk_src_lane(m, cid);")
        L.append("                if (src_lane != -1)")
        _emit_clk_period_chk(
            L,
            20,
            "phy_pclk_in[l]",
            "PERIOD_NS[src_lane]",
            '$sformatf("mode%0d lane%0d phy_pclk_in", m, l)',
        )
        L.append("            end")
    L.append("        end")
    L.append("")
    if phy_input_mode:
        # rx_clk: one shallow pass over lanes (not nested inside the
        # per-controller/per-port data loop below) -- a blocking @(posedge
        # ...) inside that loop's double for-nesting (c, then p) segfaulted
        # verilator's own runtime; a single for-loop here, same shape as
        # the per-controller pclk check below, doesn't.
        L.append("        for (int l = 0; l < NL; l++) begin")
        L.append("            int cid, port;")
        L.append("            cid  = owner_of(m, l);")
        L.append("            port = port_of(m, l);")
        L.append("            case (cid)")
        for c in ctrls:
            L.append(f"                {c.id}: begin")
            _emit_clk_period_chk(
                L,
                20,
                f"{c.lname}_rx_clk[port]",
                "LANE_PERIOD_NS[l]",
                f'$sformatf("mode%0d {c.lname}_rx_clk[%0d]", m, port)',
            )
            L.append("                end")
        L.append("            endcase")
        L.append("        end")
        L.append("")
    if not phy_input_mode:
        L.append("        for (int c = 0; c < NC; c++) begin")
        L.append("            int src_lane;")
        L.append("            src_lane = ctrl_pclk_src_lane(m, c);")
        L.append("            if (src_lane != -1) begin")
        L.append("                case (c)")
        for c in ctrls:
            L.append(f"                    {c.id}: begin")
            _emit_clk_period_chk(
                L,
                24,
                f"{c.lname}_pclk",
                "PERIOD_NS[src_lane]",
                f'$sformatf("mode%0d {c.lname}_pclk", m)',
            )
            L.append("                    end")
        L.append("                endcase")
        L.append("            end")
        L.append("        end")
        L.append("")
    L.append("        for (int c = 0; c < NC; c++) begin")
    # Each controller's port array is declared at its own real max_width
    # (no padding), so this loop bound is per-controller too -- resolved
    # the same way got/exp_p2m are, via a case(c) since the ports
    # themselves are separately-named signals, not one indexable array.
    L.append("            int max_w;")
    L.append("            case (c)")
    for c in ctrls:
        L.append(f"                {c.id}: max_w = {c.max_width};")
    L.append("                default: max_w = 0;")
    L.append("            endcase")
    L.append("            for (int p = 0; p < max_w; p++) begin")
    L.append("                int src_lane;")
    L.append("                phy2mac_lane_t got;")
    L.append("                src_lane = -1;")
    L.append("                for (int l = 0; l < NL; l++)")
    L.append("                    if (owner_of(m, l) == c && port_of(m, l) == p) src_lane = l;")
    L.append("")
    L.append("                case (c)")
    for c in ctrls:
        L.append(f"                    {c.id}: got = {c.lname}_phy2mac[p];")
    L.append("                endcase")
    L.append("")
    L.append("                if (src_lane == -1) begin")
    # Both local variable declarations go at the top of this begin block
    # (SV allows declarations interspersed with statements, but some
    # tools' parsers don't support it -- putting declarations first is
    # compatible with more tools).
    L.append("                    phy2mac_lane_t exp_tie;")
    L.append("                    int active_base;")
    L.append("                    exp_tie = SAFE_P2M;")
    L.append("                    active_base = -1;")
    L.append("                    for (int l = 0; l < NL; l++) begin")
    L.append(
        "                        if (owner_of(m, l) == c && active_base == -1) active_base = l;"
    )
    L.append("                    end")

    # Dynamically assemble the expected value exp_tie (shares
    # Signal.tie_expr() with gen_data_p2m(), so the two tie_off checks
    # can't drift apart)
    p2m_signals = [s for s in cfg.signals if not s.is_m2p]
    L.append("                    if (active_base != -1) begin")
    for s in p2m_signals:
        L.append(
            f"                        exp_tie.{s.name} = "
            f"{s.tie_expr('phy_phy2mac[active_base]')};"
        )
    L.append("                    end else begin")
    for s in p2m_signals:
        L.append(f"                        exp_tie.{s.name} = {s.tie_expr(None)};")
    L.append("                    end")

    L.append("                    err_before = err_count;")
    L.append("                    chk_p2m(got, exp_tie,")
    L.append(
        '                        $sformatf("mode%0d ctrl%0d[%0d]: unmapped tie-off", m, c, p));'
    )
    L.append("                    err_tie_off += (err_count - err_before);")
    L.append("                end else begin")
    L.append("                    exp_p2m = make_p2m(src_lane);")
    if "phy_mac_phystatus" in sig_names:
        # make_p2m() alone always leaves phy_mac_phystatus at SAFE_P2M's
        # static value; the real phy_phy2mac stimulus (see the always_comb
        # above) overrides it per-lane from phy_phystatus_stim afterwards.
        # exp_p2m must replicate that same override, or this now-comprehensive
        # per-field check spuriously fails whenever phy_phystatus_stim[src_lane]
        # is toggled non-zero during a check_mode() call.
        L.append("                    exp_p2m.phy_mac_phystatus = phy_phystatus_stim[src_lane];")
    L.append("                    err_before = err_count;")
    L.append("                    chk_p2m(got, exp_p2m,")
    L.append(
        '                        $sformatf("mode%0d ctrl%0d[%0d]: expected lane%0d data", m, c, p, src_lane));'
    )
    L.append("                    err_p2m += (err_count - err_before);")
    L.append("                end")
    L.append("            end")
    L.append("        end")
    L.append("")
    L.append(
        '        $display("%0t: mode%0d checked (%0d cumulative errors)", $time, m, err_count);'
    )
    L.append("    endtask")
    L.append("")

    if dpr:
        # DPR is idle by construction until this task actively drives
        # v_lane_mask -- one representative lane per group (a group's own
        # lowest lane), covering a direct (single real candidate) group,
        # a 2-candidate group, and an N-candidate group whenever the
        # config set has them, generalizing to any config instead of
        # hardcoding specific lane numbers.
        L.append(
            "    //------------------------------------------------------------ dpr test: DPR claims/releases a lane per group"
        )
        L.append("    task automatic check_dpr();")
        test_lanes = [g.lanes[0] for g in cfg.groups]
        L.append(f"        int test_lanes[{len(test_lanes)}] = '{{{', '.join(str(l) for l in test_lanes)}}};")
        L.append("        foreach (test_lanes[k]) begin")
        L.append("            automatic int l = test_lanes[k];")
        L.append("            automatic int oid = owner_of(mode, l);")
        L.append("            automatic int op = port_of(mode, l);")
        L.append("            automatic int unsigned err_before;")
        L.append("            v_lane_mask = '0;")
        L.append("            v_lane_mask[l] = 1'b1;")
        L.append("            #SETTLE;")
        L.append("            err_before = err_count;")
        L.append("            case (oid)")
        for c in ctrls:
            L.append(f"                {c.id}: chk_p2m({c.lname}_phy2mac[op], exp_safe_p2m_{c.lname},")
            L.append(
                f'                    $sformatf("dpr claimed lane%0d: real owner {c.name}[%0d] should read SAFE_P2M", l, op));'
            )
        L.append("                default: ;")
        L.append("            endcase")
        L.append("            chk(dpr_phy2mac[l] == phy_phy2mac[l],")
        L.append(
            '                $sformatf("dpr claimed lane%0d: dpr_phy2mac should mirror live phy_phy2mac", l));'
        )
        L.append(
            '            $display("%0t: dpr claimed lane%0d (%0d cumulative errors)", $time, l, err_count);'
        )
        L.append("            v_lane_mask = '0;")
        L.append("            #SETTLE;")
        L.append("            chk(dpr_phy2mac[l] == exp_dpr_tie,")
        L.append(
            '                $sformatf("dpr released lane%0d: dpr_phy2mac should revert to tie", l));'
        )
        L.append(
            '            $display("%0t: dpr released lane%0d (%0d cumulative errors)", $time, l, err_count);'
        )
        L.append("            err_dpr += (err_count - err_before);")
        L.append("        end")
        L.append("    endtask")
        L.append("")

    # ---- sequencing
    L.append("    //------------------------------------------------------------ sequencing")
    L.append(f"    localparam realtime SETTLE = {settle};")
    L.append("")
    # The watchdog below has to scale with SETTLE, not just be some fixed
    # number -- it needs to comfortably outlast every #SETTLE wait the
    # sequencing below actually does: 1 (initial reset) + (nm-1) mode
    # transitions + 2 for the non-adjacent jump (if nm>=2) + 2 per
    # controller for the reset-pulse checks + 2 per group for the dpr
    # test (claim + release), if --dpr. 3x that (plus a fixed pad for the
    # small non-SETTLE delays: #100, #20 phystatus toggles, and
    # check_mode()'s own per-lane/per-controller clock-period checks,
    # which each block for a couple of clock edges) keeps this from
    # nuisance-timing-out just because SETTLE (or NC) changes later.
    n_settle_waits = 1 + (nm - 1) + (2 if nm >= 2 else 0) + 2 * NC + (2 * len(cfg.groups) if dpr else 0)
    watchdog_ns = n_settle_waits * settle * 3 + 10000
    L.append("    initial begin")
    L.append("`ifdef DUMP_FSDB")
    L.append('        $fsdbDumpfile("waves.fsdb");')
    L.append('        $fsdbDumpvars(0, tb_pipe_lane_mapper, "+all");')
    L.append("`else")
    L.append('        $dumpfile("waves.vcd");')
    L.append("        $dumpvars(0, tb_pipe_lane_mapper);")
    L.append("`endif")
    L.append("")
    L.append("        ctrl_rst_n = '0;")
    L.append("        mode = '0;")
    L.append("        #100;")
    L.append("        ctrl_rst_n = '1;")
    L.append("        #SETTLE;")
    L.append("")
    for i, m in enumerate(cfg.modes):
        L.append(f"        check_mode({m});")
        L.append(
            "        // toggle physical lane 0's phystatus and dynamically verify it's followed correctly"
        )
        L.append("        phy_phystatus_stim[0] = 1'b1; #20;")
        L.append(f"        check_mode({m});")
        L.append("        phy_phystatus_stim[0] = 1'b0; #20;")
        L.append(f"        check_mode({m});")
        if i < len(cfg.modes) - 1:
            L.append(f"        mode = {cfg.modes[i+1]}; #SETTLE;")
    # Switch back after the last mode, to exercise a non-adjacent jump
    if nm >= 2:
        L.append("")
        L.append("        // non-adjacent jump")
        L.append(f"        mode = {cfg.modes[0]}; #SETTLE; check_mode({cfg.modes[0]});")
        L.append(f"        mode = {cfg.modes[-1]}; #SETTLE; check_mode({cfg.modes[-1]});")
    L.append("")

    # ---- reset pulse checks (last mode)
    last_m = cfg.modes[-1]
    L.append(f"        // reset pulse checks in mode{last_m}")
    L.append(
        "        // pulse each controller: its owner lanes' phy_rst_n should follow low,"
        " non-owner lanes stay high."
    )
    for c in ctrls:
        L.append(f"        ctrl_rst_n[{c.id}] = 1'b0; #SETTLE;")
        L.append("        begin")
        L.append("            int unsigned err_before;")
        L.append("            err_before = err_count;")
        L.append("            for (int l = 0; l < NL; l++) begin")
        L.append("                bit expect_low;")
        L.append(f"                expect_low = (owner_of({last_m}, l) == {c.id});")
        L.append('                chk(phy_rst_n[l] == (expect_low ? 1\'b0 : 1\'b1),')
        L.append(
            f'                    $sformatf("mode{last_m} lane%0d: ctrl_rst_n[{c.id}]=0 pulse, '
            f"expected phy_rst_n=%0b\", l, expect_low ? 1'b0 : 1'b1));"
        )
        L.append("            end")
        L.append("            err_reset += (err_count - err_before);")
        L.append("        end")
        L.append(
            f'        $display("%0t: ctrl_rst_n[{c.id}] pulse checked (%0d cumulative errors)", '
            f"$time, err_count);"
        )
        L.append(f"        ctrl_rst_n[{c.id}] = 1'b1; #SETTLE;")
        L.append(f"        check_mode({last_m});")
    L.append("")
    if dpr:
        L.append(f"        // dpr test, in mode{last_m}")
        L.append("        check_dpr();")
        L.append("")

    L.append('        $display("=== test case summary ===");')
    for name in case_names:
        L.append(
            f'        $display("  {name:<10}: %s (%0d errors)", '
            f'err_{name} == 0 ? "PASS" : "FAIL", err_{name});'
        )
    L.append('        if (err_count == 0) $display("TB_RESULT: PASS");')
    L.append('        else                 $display("TB_RESULT: FAIL (%0d errors)", err_count);')
    L.append("        $finish;")
    L.append("    end")
    L.append("")
    L.append("    initial begin")
    L.append(f"        #{watchdog_ns};")
    L.append('        $error("TB_RESULT: FAIL (timeout, simulation did not finish)");')
    L.append("        $finish;")
    L.append("    end")
    L.append("")
    L.append("endmodule")
    return "\n".join(L) + "\n"


# ---------------------------------------------------------------- main


def main():
    # A minimal, throwaway pre-parse just to learn --config before the real
    # parser exists, so gen_flags.txt (see plm_common.load_set_flags()) can
    # be read from that config set's own directory and folded in as
    # per-config defaults -- see apply_set_flags() for how.
    pre_ap = argparse.ArgumentParser(add_help=False)
    pre_ap.add_argument("--config", default=None)
    pre_args, _ = pre_ap.parse_known_args()
    csv_dir, out_rtl = resolve_set(pre_args.config)
    set_flags = load_set_flags(csv_dir)

    ap = argparse.ArgumentParser(description="Generate PIPE lane mapper testbench")
    ap.add_argument(
        "--config",
        default=None,
        metavar="SET",
        help="Config set directory. CSVs are looked up in <SET>/config/, "
        "then <SET>/ itself; the testbench always goes to <SET>/tb/. SET "
        "is first tried as a set name under configs/, then as a path if "
        "not found there; omitting --config lists the available set names.",
    )
    ap.add_argument(
        "--arch",
        choices=["original_pipe", "serdes"],
        default="original_pipe",
        help="Which PHY macro family this config set targets: original_pipe "
        "(only supports --pclk-mode pclk_as_phy_output) or serdes (only "
        "supports --pclk-mode pclk_as_phy_input). Purely a cross-check "
        "against --pclk-mode; must match whatever --arch this config set's "
        "RTL was (or will be) generated with (tool/plm_gen_rtl.py).",
    )
    ap.add_argument(
        "--pclk-mode",
        choices=["pclk_as_phy_output", "pclk_as_phy_input"],
        default="pclk_as_phy_output",
        help="Which clock architecture the DUT (pipe_lane_mapper) uses -- "
        "must match whatever --pclk-mode this config set's RTL was (or "
        "will be) generated with (tool/plm_gen_rtl.py), since this "
        "controls which DUT ports the testbench instantiates. "
        "pclk_as_phy_output (default) -- each PHY lane generates its own PCLK "
        "(phy_pclk_out); ctrl_pclk is derived from it, glitch-free, and "
        "echoed back as phy_pclk_in; "
        "pclk_as_phy_input -- each controller has its own external reference "
        "clock and does its own division into pclk[]/rx_clk[] "
        "ports (no separate ctrl_pclk signal); phy_pclk/rx_clk are "
        "glitch-free-selected per physical lane.",
    )
    ap.add_argument(
        "--verible-path",
        default=None,
        metavar="PATH",
        help="Path to verible-verilog-format, for auto-formatting the generated "
        ".sv file. Defaults to searching PATH for verible-verilog-format; if "
        "it can't be found there and this isn't given either, the generated "
        "file is left unformatted (this is cosmetic, not required).",
    )
    ap.add_argument(
        "--verible-flags",
        default=None,
        metavar="JSON",
        help="JSON object of verible-verilog-format flags (e.g. "
        '\'{"column_limit": "100", "wrap_end_else_clauses": "false"}\'), replacing '
        "this tool's own default flag set entirely. Advanced; normally left unset "
        "(plm_web.py's Settings panel is the usual way to change these).",
    )
    ap.add_argument(
        "--dpr",
        action="store_true",
        help="Instantiate the DUT with DPR (diagnostic probe) ports too -- must "
        "match whatever --dpr this config set's RTL was (or will be) generated "
        "with (tool/plm_gen_rtl.py). DPR is left idle by default (v_lane_mask "
        "all-zero) -- this doesn't add any DPR-specific test scenario, just "
        "matching port connectivity so the DUT elaborates.",
    )
    ap.add_argument("--quiet", action="store_true")
    a = ap.parse_args(apply_set_flags(ap, set_flags) + sys.argv[1:])
    verible_flags = json.loads(a.verible_flags) if a.verible_flags else None
    validate_arch(a.arch, a.pclk_mode)

    cfg = load(csv_dir)
    tb_dir = out_rtl.parent / "tb"
    tb_dir.mkdir(parents=True, exist_ok=True)

    # Config-independent (no config-specific content, just relative paths),
    # so every config set gets an identical copy instead of it being
    # hand-maintained per set and silently missing wherever nobody
    # remembered to add it.
    if TB_MAKEFILE.is_file():
        shutil.copy2(TB_MAKEFILE, tb_dir / "makefile")

    print(f"Config: {csv_dir}")
    print(f"TB    : {tb_dir}")
    tb_file = tb_dir / "tb_pipe_lane_mapper.sv"
    tb_file.write_text(format_sv(gen_tb(cfg, a.pclk_mode, a.dpr), a.verible_path, verible_flags), encoding="utf-8")
    print(f"  generated {tb_file}")

    if not a.quiet:
        print()
        print(cfg.report())


if __name__ == "__main__":
    main()
