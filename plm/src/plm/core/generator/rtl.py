"""
PIPE Lane Mapper RTL generator -- pure text/code generation.

Each gen_* function takes a plm.core.model.Config plus generation-mode
flags and returns the SystemVerilog text for one output file; none of
them touch the filesystem -- that's plm.core.exporter's job (writing
these strings to disk, copying the hand-written common/ modules, running
verible-verilog-format).
"""

from plm.core.paths import mode_width


def gen_pkg(cfg, dpr=False):
    L = ["package pipe_lane_signal_pkg;", ""]

    for d, tname, wname in (
        ("mac2phy", "mac2phy_lane_t", "MAC2PHY_W"),
        ("phy2mac", "phy2mac_lane_t", "PHY2MAC_W"),
    ):
        sigs = [s for s in cfg.signals if s.direction == d]
        L.append(f"    // {d} direction; signals that go through NOV are packed into one type;")
        L.append("    typedef struct packed {")
        for s in sigs:
            w = "" if s.width == 1 else f"[{s.width-1}:0] "
            L.append(f"        logic {w}{s.name};")
        L.append(f"    }} {tname};")
        L.append(f"    localparam int {wname} = $bits({tname});")
        L.append("")

    # safe-state constants
    for d, tname, cname in (
        ("mac2phy", "mac2phy_lane_t", "SAFE_M2P"),
        ("phy2mac", "phy2mac_lane_t", "SAFE_P2M"),
    ):
        sigs = [s for s in cfg.signals if s.direction == d]
        L.append("    // Value to present when there's no owner (the NOV handoff window).")
        L.append(
            "    // pipe_lane_data_mux uses this for polarity normalization, so sel==0 naturally lands on the safe state."
        )
        L.append(f"    localparam {tname} {cname} = '{{")
        for i, s in enumerate(sigs):
            tail = "," if i != len(sigs) - 1 else ""
            L.append(f"        {s.name}: {s.sv_literal(s.safe_state)}{tail}")
        L.append("    };")
        L.append("")

    # DPR-aware designs need two select types: mode_sel_t is pipe_lane_mode_dec's
    # own, unchanged, real-candidates-only one-hot (purely mode-driven); lane_sel_t
    # is the final, DPR-aware type pipe_lane_sel_gen combines it with v_lane_mask
    # into -- DPR becomes one more (the last) candidate bit in every group, so
    # every group needs a real select now, including ones that were direct
    # (single real candidate) before DPR existed.
    if dpr:
        L.append("    // Raw per-mode candidate selection, real controllers only -- pipe_lane_mode_dec's")
        L.append("    // own output type, unaware of DPR. pipe_lane_sel_gen combines this with")
        L.append("    // v_lane_mask into the DPR-aware lane_sel_t below.")
        for g in cfg.groups:
            if g.is_direct:
                c = cfg.controllers[g.cands[0]]
                L.append(f"    // G{g.gid} (lane{g.lanes[0]}~{g.lanes[-1]}): direct to {c.name}, no sel")
            else:
                names = ", ".join(f"bit{i}={cfg.controllers[c].name}" for i, c in enumerate(g.cands))
                L.append(f"    // G{g.gid} (lane{g.lanes[0]}~{g.lanes[-1]}): {names}")
        L.append("    typedef struct packed {")
        any_mode_mux = False
        for g in cfg.groups:
            if not g.is_direct:
                L.append(f"        logic [{g.n-1}:0] g{g.gid};")
                any_mode_mux = True
        if not any_mode_mux:
            L.append("        logic dummy;   // this topology is all direct connections")
        L.append("    } mode_sel_t;")
        L.append("")

    L.append(
        "    // One one-hot select vector per lane group"
        + (", DPR included as one extra (the last) candidate bit." if dpr else " that needs NOV.")
    )
    if not dpr:
        L.append(
            "    // Direct groups don't appear here -- the type itself shows they have no choice to make."
        )
    for g in cfg.groups:
        if dpr:
            names = ", ".join(f"bit{i}={cfg.controllers[c].name}" for i, c in enumerate(g.cands))
            L.append(f"    // G{g.gid} (lane{g.lanes[0]}~{g.lanes[-1]}): {names}, bit{g.n}=DPR")
        elif g.is_direct:
            c = cfg.controllers[g.cands[0]]
            L.append(
                f"    // G{g.gid} (lane{g.lanes[0]}~{g.lanes[-1]}): " f"direct to {c.name}, no sel"
            )
        else:
            names = ", ".join(f"bit{i}={cfg.controllers[c].name}" for i, c in enumerate(g.cands))
            L.append(f"    // G{g.gid} (lane{g.lanes[0]}~{g.lanes[-1]}): {names}")
    L.append("    typedef struct packed {")
    any_mux = False
    for g in cfg.groups:
        if dpr:
            L.append(f"        logic [{g.n}:0] g{g.gid};")
            any_mux = True
        elif not g.is_direct:
            L.append(f"        logic [{g.n-1}:0] g{g.gid};")
            any_mux = True
    if not any_mux:
        L.append("        logic dummy;   // this topology is all direct connections")
    L.append("    } lane_sel_t;")
    L.append("")
    L.append("endpackage")
    return "\n".join(L) + "\n"


# ---------------------------------------------------------------- decoder


def gen_decoder(cfg, dpr=False):
    nm = len(cfg.modes)
    cp = cfg.ctrl_pclk_src()
    cc = cfg.ctrl_pclk_cands()
    muxed_c = [c for c in sorted(cfg.controllers) if len(cc[c]) > 1]

    L = [
        "// mode decoding: produces each lane group's target owner, and each",
        "// controller's target pclk source. Purely combinational, no state.",
        "//",
        "// Output feeds directly into NOV's tgt port; NOV handles cross-domain",
        "// synchronization and interlocking.",
        "import pipe_lane_signal_pkg::*;",
        "",
        "module pipe_lane_mode_dec #(",
        f"    parameter int NC = {cfg.num_ctrl}   // only used by controllers with more than one candidate",
        ") (",
        f"    input logic [{mode_width(nm)-1}:0] mode,",
    ]
    # Output port list: sel_tgt is always present, pclk_tgt appended as
    # needed. The comma has to be inserted before the comment -- just
    # appending "," to the end of the whole line would put the comma inside
    # the "// ..." comment, leaving the actual code still missing it. So the
    # "code" and "comment" parts are assembled separately here, with the
    # comma attached to the end of the code and the comment appended after.
    sel_t = "mode_sel_t" if dpr else "lane_sel_t"
    ports = [(f"    output {sel_t} sel_tgt", "")]
    for c in muxed_c:
        ports.append(
            (
                f"    output logic [{len(cc[c])-1}:0] pclk_tgt_c{c}",
                f"   // pclk candidate selection for {cfg.controllers[c].name}",
            )
        )
    for i, (code, comment) in enumerate(ports):
        tail = "," if i != len(ports) - 1 else ""
        L.append(code + tail + comment)
    L.append(");")
    L.append("")

    mux_groups = [g for g in cfg.groups if not g.is_direct]
    L.append("    always_comb begin")
    L.append("        sel_tgt = '0;")
    for c in muxed_c:
        L.append(f"        pclk_tgt_c{c} = '0;")
    L.append("")
    L.append("        unique case (mode)")
    for m in cfg.modes:
        L.append(f"            {m}: begin")
        for g in mux_groups:
            b = g.branch_of(g.owners[m])
            L.append(
                f"                sel_tgt.g{g.gid} = {g.n}'b{1 << b:0{g.n}b};"
                f"  // {cfg.controllers[g.owners[m]].name}"
            )
        for c in muxed_c:
            v = cp[c][m]
            if v is None:
                L.append(
                    f"                // {cfg.controllers[c].name} isn't assigned a lane in this mode,"
                )
                L.append(
                    "                // pclk_tgt stays 0; the downstream hold logic keeps the previous selection"
                )
            else:
                b = cc[c].index(v)
                L.append(
                    f"                pclk_tgt_c{c} = "
                    f"{len(cc[c])}'b{1 << b:0{len(cc[c])}b};  // phy_pclk[{v}]"
                )
        L.append("            end")
    L.append("            default: begin")
    L.append("                sel_tgt = '0;")
    for c in muxed_c:
        L.append(f"                pclk_tgt_c{c} = '0;")
    L.append("            end")
    L.append("        endcase")
    L.append("    end")
    L.append("")
    L.append("endmodule")
    return "\n".join(L) + "\n"


# ---------------------------------------------------------------- select-generation submodule


def gen_sel_gen(cfg, sel_mode="sync", pclk_mode="pclk_as_phy_output", dpr=False):
    """Select-generation submodule: mode decoding + group pipe_lane_sel_sync, produces
    sel_tgt and dec_tgt.

    The decoder and group pipe_lane_sel_sync used to be crammed into the clock
    submodule; now they're split out into a standalone pipe_lane_sel_gen
    with a clearer responsibility: this module only answers "who should
    each group listen to right now", and doesn't touch any clock-generation
    logic.

    It exposes two target signals:
      sel_tgt -- the final, effective selection after pipe_lane_sel_sync
                 synchronization, non-overlap; used by clk_mux's
                 feedback clock mux and data_m2p/data_p2m. Only produced
                 in pclk_mode="pclk_as_phy_output" -- see below for
                 pclk_mode="pclk_as_phy_input".
      dec_tgt -- the decoder's raw (unsynchronized) target, purely
                 combinational and changes immediately with mode; used by
                 rst_mux, so the new owner's reset control can follow mode
                 right away without waiting for pipe_lane_sel_sync to finish
                 cross-domain synchronization and the NOV break window.

    In pclk_mode="pclk_as_phy_input", sel_tgt doesn't exist as a single
    per-group signal: {c.lname}_pclk[] is per-PORT, not per-controller (see
    below), so the same "one clock per candidate" shortcut that was wrong
    for phy_pclk/rx_clk is also wrong here -- a group's sel_tgt gates a
    pipe_lane_data_mux whose output is ultimately sampled by the owning
    controller using ITS OWN port's {c.lname}_pclk[port], so the select
    needs to be synchronized into that same per-port domain, not a
    per-controller stand-in. So instead of one sel_tgt.gN per group, this
    module produces one seltgt_g{gid}_l{l} per BBM LANE (mirroring
    phy_pclk's per-lane treatment), which gen_data_m2p/gen_data_p2m
    select with per lane instead of the group-shared sel_tgt.

    The controller-side pclk candidates (pclk_tgt_cX) are also produced by
    the internal decoder, but that signal is meant for
    pipe_lane_clk_mux's glitch-free controller pclk switching -- this
    module doesn't consume it itself, just passes it through.

    In pclk_mode="pclk_as_phy_input", this module also houses every
    CDC synchronizer in the design, including ones whose output isn't the
    data-path sel_tgt: rxclk_en_g{gid}_l{l} synchronizes dec_tgt.gN into
    each BBM lane's own rx_clk[l] domain (rx_clk is PHY's per-lane
    recovered clock, with no fixed phase relation to ctrl_pclk),
    for pipe_lane_clk_mux's rx_clk routing -- rx_clk flows PHY->controller,
    it is not looped back to the PHY the way phy_pclk is, so it is not
    "feedback" -- pipe_lane_clk_mux
    only does the final pipe_lane_clk_gate + assign with the already-
    synchronized enable, it doesn't instantiate pipe_lane_sel_sync itself.

    Each group's owner selection goes through the pipe_lane_sel_sync module
    (tool/backend/common/pipe_lane_sel_sync.sv), whose SYNC parameter switches between two
    implementations. Rather than baking a literal into each instance at
    generation time, every data-path pipe_lane_sel_sync in this module
    (the group/lane selects that gate sel_tgt / seltgt_gN_lL) is wired to
    one module parameter, SEL_SYNC, so the choice is a single elaboration-
    time knob on pipe_lane_sel_gen itself (and, via pipe_lane_mapper's own
    SEL_SYNC parameter, on the whole design) instead of something only
    --sel-mode can set:
      SEL_SYNC=1'b1 (default, sel_mode="sync") -- non-overlap + a
                two-stage synchronizer, safe across clock domains.
      SEL_SYNC=1'b0 (sel_mode="comb")          -- en is directly tgt, pure
                combinational passthrough. Only safe when every candidate
                controller genuinely shares the same clock domain and mode
                itself is already glitch-free within that domain;
                otherwise multiple branches could briefly be 1 at once,
                and pipe_lane_data_mux would OR the two data paths together.
    --sel-mode only picks SEL_SYNC's default value at generation time; it
    can still be overridden per-instantiation without regenerating.
    The rx_clk and controller-pclk glitch-free-switching syncs elsewhere in
    this design are NOT tied to SEL_SYNC -- those always force SYNC=1'b1,
    unconditionally, because they gate a clock rather than select data;
    that safety property isn't something the user should be able to turn
    off (see design_notes.md 4.1).

    This module needs a per-controller working-clock reference as input for
    pipe_lane_sel_sync's branch_clk. In pclk_mode="pclk_as_phy_output", that's
    ctrl_pclk (pipe_lane_clk_mux's output) -- so the two submodules form a
    ring connection at the top level, but there's no combinational loop:
    ctrl_pclk only depends on the decoder's pclk_tgt_cX (passed through by
    this module), which has nothing to do with the sel_tgt this module
    produces; and sel_tgt's dependency on ctrl_pclk goes entirely through
    flops inside pipe_lane_sel_sync, so there's no combinational feedback.

    In pclk_mode="pclk_as_phy_input", there's no separate ctrl_pclk signal
    at all: the controller already has its own working clock (it generated
    the division itself), so this module takes each controller's
    {c.lname}_pclk[] directly and uses bit 0 as that reference, instead of
    going through pipe_lane_clk_mux for a redundant single-bit relabeling.
    """
    nm = len(cfg.modes)
    NC = cfg.num_ctrl
    LC = cfg.lane_count
    cc = cfg.ctrl_pclk_cands()
    muxed_c = [c for c in sorted(cfg.controllers) if len(cc[c]) > 1]
    sync_lit = "1'b1" if sel_mode == "sync" else "1'b0"
    phy_input_mode = pclk_mode == "pclk_as_phy_input"

    L = [
        "// PIPE lane mapper select-generation submodule.",
        "// Decodes mode into each group's raw target dec_tgt (combinational, for rst_mux),",
        "// then uses pipe_lane_sel_sync for non-overlap + cross-clock-domain synchronization to",
        "// produce the final effective sel_tgt (for clk_mux's feedback clock mux and the data muxes).",
        "// pclk_tgt_cX is produced by the internal decoder and passed through to pipe_lane_clk_mux",
        "// for glitch-free switching of controller pclk candidates.",
        f"// SEL_SYNC default: {sel_mode}"
        + (
            " (1'b1, safe across clock domains)"
            if sel_mode == "sync"
            else " (1'b0, combinational passthrough, requires candidate controllers to share one clock domain)"
        ),
        "import pipe_lane_signal_pkg::*;",
        "",
        "module pipe_lane_sel_gen #(",
    ]
    L.append(f"    parameter int NC = {NC},")
    if phy_input_mode or dpr:
        L.append(f"    parameter int NL = {LC},")
    L.append(
        f"    parameter bit SEL_SYNC = {sync_lit}"
        "   // pipe_lane_sel_sync's SYNC for every data-path select in this module"
    )
    L += [
        ") (",
        f"    input logic [{mode_width(nm)-1}:0] mode,",
    ]
    if phy_input_mode:
        for cid in sorted(cfg.controllers):
            c = cfg.controllers[cid]
            L.append(
                f"    input logic [{c.max_width-1}:0] {c.lname}_pclk,"
                f"   // {c.name}'s own already-divided pclk; bit 0 is this controller's working-clock reference"
            )
    else:
        L.append("    input logic [NC-1:0] ctrl_pclk,")
    L.append("    input logic [NC-1:0] ctrl_rst_n,")
    if phy_input_mode:
        L.append("    input logic [NL-1:0] rx_clk,   // PHY's per-lane recovered clock")
    if dpr:
        L.append("    input logic [NL-1:0] v_lane_mask,")
        L.append("    input logic dpr_rst_n,")
        L.append("    input logic dpr_pclk,   // DPR's own working clock, from clk_mux")
    # Same as gen_decoder: code and comment are assembled separately, comma
    # goes at the end of the code, before the comment.
    ports = [
        (
            "    output lane_sel_t dec_tgt",
            "   // decoder's raw (unsynchronized) target"
            + (", DPR-combined; used by rst_mux" if dpr else "; used by rst_mux"),
        ),
    ]
    if not phy_input_mode:
        ports.insert(
            0,
            (
                "    output lane_sel_t sel_tgt",
                "   // final effective selection after pipe_lane_sel_sync synchronization; used by clk_mux/data mux",
            ),
        )
    for c in muxed_c:
        ports.append(
            (
                f"    output logic [{len(cc[c])-1}:0] pclk_tgt_c{c}",
                f"   // pclk candidate for {cfg.controllers[c].name}, passed through to clk_mux",
            )
        )
    if phy_input_mode:
        for g in (cfg.groups if dpr else [g for g in cfg.groups if not g.is_direct]):
            eff_n = g.n + 1 if dpr else g.n
            for l in g.lanes:
                ports.append(
                    (
                        f"    output logic [{eff_n-1}:0] seltgt_g{g.gid}_l{l}",
                        f"   // dec_tgt.g{g.gid} synchronized into this lane's owning candidate's own port clock; used by data_m2p/data_p2m",
                    )
                )
        for g in cfg.groups:
            if g.is_direct:
                continue
            for l in g.lanes:
                ports.append(
                    (
                        f"    output logic [{g.n-1}:0] rxclk_en_g{g.gid}_l{l}",
                        f"   // dec_tgt.g{g.gid} synchronized into rx_clk[{l}]'s own domain, for clk_mux's rx_clk gating",
                    )
                )
    for i, (code, comment) in enumerate(ports):
        tail = "," if i != len(ports) - 1 else ""
        L.append(code + tail + comment)
    L.append(");")
    L.append("")

    # decoder instance
    if dpr:
        L.append("    mode_sel_t dec_tgt_mode;   // decoder's own raw output, real candidates only")
    dec_out = "dec_tgt_mode" if dpr else "dec_tgt"
    L.append("    pipe_lane_mode_dec #(")
    L.append("        .NC (NC)")
    L.append("    ) u_mode_dec (")
    L.append("        .mode     (mode),")
    L.append(f"        .sel_tgt  ({dec_out})" + ("," if muxed_c else ""))
    for i, c in enumerate(muxed_c):
        tail = "," if i != len(muxed_c) - 1 else ""
        L.append(f"        .pclk_tgt_c{c} (pclk_tgt_c{c}){tail}")
    L.append("    );")
    L.append("")

    if dpr:
        L.append("    //------------------------------------------------------------")
        L.append("    // Combine each group's raw mode-based target with v_lane_mask: DPR (the")
        L.append("    // last bit, index g.n) unconditionally overrides the real candidates when")
        L.append("    // its group's mask bit is set. v_lane_mask is asserted at group")
        L.append("    // granularity (every lane in a group masked together, a system-level")
        L.append("    // usage contract, not something this generator enforces), so one")
        L.append("    // representative lane per group -- its lowest-numbered lane -- decides")
        L.append("    // the whole group.")
        L.append("    //------------------------------------------------------------")
        for g in cfg.groups:
            lane0 = g.lanes[0]
            real_part = f"dec_tgt_mode.g{g.gid}" if not g.is_direct else "1'b1"
            L.append(
                f"    assign dec_tgt.g{g.gid} = v_lane_mask[{lane0}] ? "
                f"{g.n+1}'b{1 << g.n:0{g.n+1}b} : {{1'b0, {real_part}}};"
            )
        L.append("")

    if phy_input_mode:
        L.append("    //------------------------------------------------------------")
        L.append("    // Data-path select: one pipe_lane_sel_sync per BBM LANE (not per group),")
        L.append("    // synchronizing dec_tgt.gN into that lane's owning candidate's own port")
        L.append("    // clock -- {c}_pclk is per-port, so a group-shared sel_tgt synchronized")
        L.append("    // against only one candidate port would be the wrong domain for whichever")
        L.append("    // other port that lane actually routes to.")
        L.append("    //------------------------------------------------------------")
        for g in (cfg.groups if dpr else [g for g in cfg.groups if not g.is_direct]):
            names = ", ".join(cfg.controllers[c].name for c in g.cands) + (", DPR" if dpr else "")
            L.append(f"    // G{g.gid} lane{g.lanes[0]}~{g.lanes[-1]}: {names}, per-lane select")
            n = g.n + 1 if dpr else g.n
            for l in g.lanes:
                port_of_cand = {}
                for c in g.cands:
                    m = next(mm for mm in cfg.modes if g.owners[mm] == c)
                    port_of_cand[c] = cfg.mapping[m][l][1]
                branch_clk_terms = ", ".join(
                    f"{cfg.controllers[c].lname}_pclk[{port_of_cand[c]}]" for c in reversed(g.cands)
                )
                branch_rst_terms = ", ".join(f"ctrl_rst_n[{c}]" for c in reversed(g.cands))
                if dpr:
                    branch_clk_terms = "dpr_pclk, " + branch_clk_terms
                    branch_rst_terms = "dpr_rst_n, " + branch_rst_terms
                L.append(f"    pipe_lane_sel_sync #(.N({n}), .SYNC(SEL_SYNC)) u_seltgt_sel_sync_g{g.gid}_l{l} (")
                L.append(f"        .branch_clk   ({{{branch_clk_terms}}}),")
                L.append(f"        .branch_rst_n ({{{branch_rst_terms}}}),")
                L.append(f"        .tgt          (dec_tgt.g{g.gid}),")
                L.append(f"        .en           (seltgt_g{g.gid}_l{l})")
                L.append("    );")
                L.append("")
    else:
        L.append("    //------------------------------------------------------------")
        if dpr:
            L.append("    // One pipe_lane_sel_sync per group (SYNC=SEL_SYNC), DPR included.")
        else:
            L.append("    // One pipe_lane_sel_sync per non-direct group (SYNC=SEL_SYNC).")
        L.append("    //------------------------------------------------------------")
        for g in (cfg.groups if dpr else [g for g in cfg.groups if not g.is_direct]):
            names = ", ".join(cfg.controllers[c].name for c in g.cands) + (", DPR" if dpr else "")
            L.append(f"    // G{g.gid} lane{g.lanes[0]}~{g.lanes[-1]}: {names}")
            n = g.n + 1 if dpr else g.n
            L.append(f"    pipe_lane_sel_sync #(.N({n}), .SYNC(SEL_SYNC)) u_sel_sync_g{g.gid} (")
            branch_clk_terms = ", ".join(f"ctrl_pclk[{c}]" for c in reversed(g.cands))
            branch_rst_terms = ", ".join(f"ctrl_rst_n[{c}]" for c in reversed(g.cands))
            if dpr:
                branch_clk_terms = "dpr_pclk, " + branch_clk_terms
                branch_rst_terms = "dpr_rst_n, " + branch_rst_terms
            L.append(f"        .branch_clk   ({{{branch_clk_terms}}}),")
            L.append(f"        .branch_rst_n ({{{branch_rst_terms}}}),")
            L.append(f"        .tgt          (dec_tgt.g{g.gid}),")
            L.append(f"        .en           (sel_tgt.g{g.gid})")
            L.append("    );")
            L.append("")

    if phy_input_mode:
        L.append("    //------------------------------------------------------------")
        L.append("    // rx_clk routing (PHY->controller, not feedback): one pipe_lane_sel_sync per BBM lane, synchronizing")
        L.append("    // dec_tgt.gN into that lane's own rx_clk[l] domain (rx_clk has no fixed phase")
        L.append("    // relation to {c}_pclk, unlike the rest of the PIPE-level signals).")
        L.append("    // clk_mux does the final pipe_lane_clk_gate + assign with this enable.")
        L.append("    //------------------------------------------------------------")
        for g in cfg.groups:
            if g.is_direct:
                continue
            for l in g.lanes:
                n = g.n
                L.append(f"    pipe_lane_sel_sync #(.N({n}), .SYNC(1'b1)) u_rxclk_sel_sync_g{g.gid}_l{l} (")
                L.append(f"        .branch_clk   ({{{n}{{rx_clk[{l}]}}}}),")
                L.append(
                    "        .branch_rst_n ({"
                    + ", ".join(f"ctrl_rst_n[{c}]" for c in reversed(g.cands))
                    + "}),"
                )
                # dec_tgt.gN is DPR-combined when --dpr (g.n+1 bits: real
                # candidates in the low g.n bits, DPR at bit g.n), but rx_clk
                # is never routed to DPR (no dpr_rx_clk port), so this
                # instance stays at the real, non-widened N(n) above -- slice
                # to the low n bits explicitly, rather than let the port
                # connection truncate implicitly. Those low bits are already
                # all-zero whenever the sliced-off DPR bit is the one set
                # (dec_tgt.gN is one-hot), so this correctly gates every real
                # candidate's rxclk_en off while DPR owns the lane.
                tgt_expr = f"dec_tgt.g{g.gid}[{g.n-1}:0]" if dpr else f"dec_tgt.g{g.gid}"
                L.append(f"        .tgt          ({tgt_expr}),")
                L.append(f"        .en           (rxclk_en_g{g.gid}_l{l})")
                L.append("    );")
                L.append("")

    L.append("endmodule")
    return "\n".join(L) + "\n"


# ---------------------------------------------------------------- clock-mux submodule


def gen_clk_mux(cfg, pclk_mode="pclk_as_phy_output", dpr=False):
    """Controller pclk generation + feedback clock mux.

    Two mutually exclusive clock architectures, selected by pclk_mode:

    "pclk_as_phy_output" (default): each PHY lane generates its own PCLK
    (phy_pclk_out); this module derives ctrl_pclk from it and echoes the
    result back as phy_pclk_in. See gen_clk_mux_phy_output() below.

    "pclk_as_phy_input": each controller has its own external reference
    clock and does its own division into a per-port pclk[] that this
    module glitch-free-selects into phy_pclk; PHY's per-lane recovered
    rx_clk is routed the other way into each controller's own rx_clk[].
    See gen_clk_mux_phy_input() below.
    """
    if pclk_mode == "pclk_as_phy_input":
        return gen_clk_mux_phy_input(cfg, dpr)
    return gen_clk_mux_phy_output(cfg, dpr)


def gen_glitch_free_clk_select(L, prefix, cand_clks, rst_n_expr, tgt_expr, default_bit, out_expr, test_en="test_en"):
    """Emit a glitch-free N-way clock select: a hold-until-valid register,
    one pipe_lane_sel_sync, one pipe_lane_clk_gate per candidate, and a
    final pipe_lane_clk_or -- appended to L in place, nothing returned.

    This is the one shape every "pick exactly one of N candidate clocks,
    glitch-free" site in the generator needs: a real multi-candidate
    controller's own pclk (pclk_as_phy_output's ctrl_pclk) and DPR's own
    working clock (either pclk mode) are architecturally the same circuit
    -- DPR is nothing but one more N-candidate glitch-free clock select,
    just with every PHY lane (or every lane's real_pclk[]) as its candidate
    set instead of one controller's own handful of ports. Sharing this one
    function keeps that true in the generator's own code, instead of DPR's
    version being a hand-duplicated near-copy of the real-controller one.

    cand_clks: candidate clock SV expressions, in bit order (index i is tgt
               bit i / candidate i).
    rst_n_expr: single reset expression, broadcast to every branch.
    tgt_expr: the raw (possibly momentarily-all-zero) target bus to hold --
              already declared/assigned by the caller.
    default_bit: which candidate index the hold register resets to.
    out_expr: the final single-clock signal/expression this assigns.
    """
    n = len(cand_clks)
    L.append(f"    logic [{n-1}:0] {prefix}_tgt_hold;")
    L.append(f"    logic [{n-1}:0] {prefix}_pen;")
    L.append(f"    logic [{n-1}:0] {prefix}_pgated;")
    L.append(f"    always_ff @(posedge {cand_clks[default_bit]} or negedge {rst_n_expr})")
    L.append(f"        if (!{rst_n_expr}) {prefix}_tgt_hold <= {n}'b{1 << default_bit:0{n}b};")
    L.append(f"        else if (|{tgt_expr}) {prefix}_tgt_hold <= {tgt_expr};")
    L.append(f"    pipe_lane_sel_sync #(.N({n}), .SYNC(1'b1)) u_{prefix}_sel (")
    L.append("        .branch_clk   ({" + ", ".join(reversed(cand_clks)) + "}),")
    L.append(f"        .branch_rst_n ({{{n}{{{rst_n_expr}}}}}),")
    L.append(f"        .tgt          ({prefix}_tgt_hold),")
    L.append(f"        .en           ({prefix}_pen)")
    L.append("    );")
    for i, clk in enumerate(cand_clks):
        L.append(
            f"    pipe_lane_clk_gate u_{prefix}_gate_b{i} (.clk_in({clk}), .en({prefix}_pen[{i}]), "
            f".test_en({test_en}), .clk_out({prefix}_pgated[{i}]));"
        )
    L.append(f"    pipe_lane_clk_or #(.N({n})) u_{prefix}_or (.clk_in({prefix}_pgated), .clk_out({out_expr}));")


def gen_clk_mux_phy_output(cfg, dpr=False):
    """Controller pclk generation + feedback clock mux ("PCLK as PHY output").

    The final effective owner selection for each group (sel_tgt) is now
    produced by pipe_lane_sel_gen; this module only handles two things:
      1. Glitch-free switching of controller pclk candidates:
         pclk_tgt_cX is produced by the decoder inside sel_gen and passed
         in here, but the actual switch is still performed in this module,
         because the glitch-free switch needs this module's own
         phy_pclk_out for cross-clock-domain synchronization.
      2. Feedback clock: each lane's phy_pclk_in is selected, per sel_tgt
         (sel_gen's output, passed in here as an input), to be the current
         owner's ctrl_pclk.

    Switching the controller pclk candidate always forces SYNC=1'b1 --
    that's for glitch-free switching of the clock itself, unrelated to the
    group's pipe_lane_sel_sync mode.
    """
    LC, NC = cfg.lane_count, cfg.num_ctrl
    cc = cfg.ctrl_pclk_cands()
    muxed_c = [c for c in sorted(cfg.controllers) if len(cc[c]) > 1]

    L = [
        "// PIPE lane mapper clock-mux submodule.",
        "// Contains: controller pclk generation, feedback clock mux.",
        "// Each group's final sel_tgt is produced by pipe_lane_sel_gen and passed in as an input.",
        "// The reset mux is in pipe_lane_rst_mux, the data muxes are in",
        "// pipe_lane_data_m2p / pipe_lane_data_p2m.",
        "import pipe_lane_signal_pkg::*;",
        "",
        "module pipe_lane_clk_mux #(",
        f"    parameter int NL = {LC},",
        f"    parameter int NC = {NC}",
        ") (",
        "    input logic [NL-1:0] phy_pclk_out,",
        "    input logic test_en,",
        "    input logic [NC-1:0] ctrl_rst_n,",
    ]
    for c in muxed_c:
        L.append(
            f"    input logic [{len(cc[c])-1}:0] pclk_tgt_c{c},"
            f"   // pclk candidate target for {cfg.controllers[c].name}, from sel_gen"
        )
    L.append(
        "    input lane_sel_t sel_tgt,   // each group's currently effective owner selection"
    )
    if dpr:
        L.append("    input logic [NL-1:0] v_lane_mask,")
        L.append("    input logic dpr_rst_n,")
    L.append("    output logic [NC-1:0] ctrl_pclk,")
    if dpr:
        L.append("    output logic dpr_pclk,")
    L.append("    output logic [NL-1:0] phy_pclk_in")
    L.append(");")
    L.append("")

    # ctrl_pclk
    L.append("    //------------------------------------------------------------")
    L.append("    // controller pclk: always taken from the lowest-numbered lane in its group.")
    L.append("    // Only needs a glitch-free switch when there's more than one candidate.")
    L.append("    //------------------------------------------------------------")
    for cid in sorted(cfg.controllers):
        c = cfg.controllers[cid]
        cand = cc[cid]
        if len(cand) == 1:
            L.append(f"    // {c.name}: uses phy_pclk[{cand[0]}] in every mode, direct connection")
            L.append(f"    assign ctrl_pclk[{cid}] = phy_pclk_out[{cand[0]}];")
        else:
            n = len(cand)
            L.append(
                f"    // {c.name}: {n}-way select, candidates "
                f"{', '.join(f'phy_pclk[{v}]' for v in cand)}"
            )
            gen_glitch_free_clk_select(
                L,
                f"pclk_c{cid}",
                [f"phy_pclk_out[{v}]" for v in cand],
                f"ctrl_rst_n[{cid}]",
                f"pclk_tgt_c{cid}",
                0,
                f"ctrl_pclk[{cid}]",
            )
        L.append("")

    if dpr:
        default_lane = cfg.groups[-1].lanes[0]  # last group's lowest lane
        L.append("    //------------------------------------------------------------")
        L.append("    // DPR's own working clock: from the lowest-numbered currently-masked")
        L.append("    // lane (isolate v_lane_mask's lowest set bit), glitch-free multi-candidate")
        L.append("    // select -- architecturally the exact same circuit as a real multi-")
        L.append("    // candidate controller's ctrl_pclk above, just with all NL lanes as")
        L.append(f"    // candidates. Defaults to lane{default_lane} (last group's lowest lane) when")
        L.append("    // idle (v_lane_mask all-zero).")
        L.append("    //------------------------------------------------------------")
        L.append("    logic [NL-1:0] dpr_pclk_tgt;")
        L.append("    // isolate the lowest set bit: v_lane_mask & (-v_lane_mask)")
        L.append("    assign dpr_pclk_tgt = v_lane_mask & (~v_lane_mask + 1'b1);")
        L.append("")
        gen_glitch_free_clk_select(
            L,
            "dpr_pclk",
            [f"phy_pclk_out[{l}]" for l in range(LC)],
            "dpr_rst_n",
            "dpr_pclk_tgt",
            default_lane,
            "dpr_pclk",
        )
        L.append("")

    # feedback clock
    L.append("    //------------------------------------------------------------")
    L.append(
        "    // Feedback clock: each lane's pclk_in connects to its current owner's ctrl_pclk"
        + (" (or dpr_pclk, when DPR owns it)." if dpr else ".")
    )
    L.append(
        "    // Shares the same en group as the data path, so data and clock switch in lockstep."
    )
    L.append("    //------------------------------------------------------------")
    for g in cfg.groups:
        if g.is_direct and not dpr:
            c = g.cands[0]
            for l in g.lanes:
                L.append(
                    f"    assign phy_pclk_in[{l}] = ctrl_pclk[{c}];"
                    f"  // G{g.gid} direct to {cfg.controllers[c].name}"
                )
        else:
            names = ", ".join(cfg.controllers[c].name for c in g.cands) + (", DPR" if dpr else "")
            n = g.n + 1 if dpr else g.n
            L.append(f"    // G{g.gid} lane{g.lanes[0]}~{g.lanes[-1]}: {names}")
            L.append(f"    logic [{n-1}:0] pin_gated_g{g.gid};")
            # Lanes in the same group share one set of pipe_lane_clk_gate instances, computing
            # the pclk_in_gN intermediate signal just once. Each lane is
            # assigned from that intermediate signal rather than
            # referencing each other -- phy_pclk_in is a top-level output,
            # and lanes referencing each other would be flagged as a
            # self-loop on an output port (UNOPTFLAT).
            L.append(f"    logic pclk_in_g{g.gid};")
            for i, c in enumerate(g.cands):
                L.append(
                    f"    pipe_lane_clk_gate u_pin_gate_g{g.gid}_b{i} ("
                    f".clk_in(ctrl_pclk[{c}]), .en(sel_tgt.g{g.gid}[{i}]), "
                    f".test_en(test_en), .clk_out(pin_gated_g{g.gid}[{i}]));"
                )
            if dpr:
                L.append(
                    f"    pipe_lane_clk_gate u_pin_gate_g{g.gid}_dpr ("
                    f".clk_in(dpr_pclk), .en(sel_tgt.g{g.gid}[{g.n}]), "
                    f".test_en(test_en), .clk_out(pin_gated_g{g.gid}[{g.n}]));"
                )
            L.append(
                f"    pipe_lane_clk_or #(.N({n})) u_pin_or_g{g.gid} "
                f"(.clk_in(pin_gated_g{g.gid}), .clk_out(pclk_in_g{g.gid}));"
            )
            for l in g.lanes:
                L.append(f"    assign phy_pclk_in[{l}] = pclk_in_g{g.gid};")
    L.append("")
    L.append("endmodule")
    return "\n".join(L) + "\n"


def gen_clk_mux_phy_input(cfg, dpr=False):
    """Controller pclk generation + feedback clock mux ("PCLK as PHY input").

    Each controller owns its own external reference clock and does its own
    division outside this generator's scope, presenting the divided result
    as its own pclk[] (one bit per its own port, same width/routing
    convention as {c.lname}_mac2phy). There's no separate ctrl_pclk signal
    in this scheme at all: the controller already has its own working
    clock (it generated the division itself), so pipe_lane_sel_gen takes
    each controller's {c.lname}_pclk[] directly for its own CDC sync
    reference instead of this module relabeling one bit of it as a
    dedicated ctrl_pclk output -- unlike the pclk_as_phy_output scheme, where
    ctrl_pclk is genuinely derived here (from phy_pclk_out) and has to
    flow back out to the controller.

    phy_pclk still needs glitch-free switching for NOV groups, but
    per PHYSICAL LANE rather than per group: different lanes in the same
    group can pull from different port bits of the same candidate
    controller, so each lane needs dec_tgt synchronized into that lane's
    own candidate port clocks -- exactly the same synchronization the data
    path needs for its own per-lane select (see gen_sel_gen()'s
    seltgt_g{gid}_l{l}: same tgt, same branch_clk domains), so this module
    doesn't re-synchronize dec_tgt itself -- it just reuses sel_gen's
    already-synchronized seltgt_g{gid}_l{l} as the pipe_lane_clk_gate
    enable directly.

    rx_clk (PHY's per-lane recovered clock) is routed the other direction
    into each controller port's own rx_clk bit. rx_clk[l] is its own
    independent recovered-clock domain (no fixed phase relation to
    {c.lname}_pclk, unlike the rest of the PIPE-level signals, which all
    live in {c.lname}_pclk), so this needs its own separate
    synchronization into rx_clk[l]'s own domain instead -- that's the one
    other domain family dec_tgt gets synchronized into (rxclk_en_g{gid}_l{l},
    also produced by pipe_lane_sel_gen, every CDC synchronizer in the
    design lives there). This module just takes both already-synchronized
    enables as inputs and does the final pipe_lane_clk_gate + pipe_lane_clk_or.
    """
    LC, NC = cfg.lane_count, cfg.num_ctrl

    L = [
        "// PIPE lane mapper clock-mux submodule (PCLK as PHY input scheme).",
        "// Contains: glitch-free phy_pclk switch, glitch-free rx_clk switch.",
        "// No ctrl_pclk here -- see pipe_lane_sel_gen, which uses {c}_pclk[] directly.",
        "// The reset mux is in pipe_lane_rst_mux, the data muxes are in",
        "// pipe_lane_data_m2p / pipe_lane_data_p2m.",
        "import pipe_lane_signal_pkg::*;",
        "",
        "module pipe_lane_clk_mux #(",
        f"    parameter int NL = {LC},",
        f"    parameter int NC = {NC}",
        ") (",
        "    input logic test_en,",
        "    input logic [NC-1:0] ctrl_rst_n,",
        "    input logic [NL-1:0] rx_clk,     // PHY's per-lane recovered clock",
    ]
    for cid in sorted(cfg.controllers):
        c = cfg.controllers[cid]
        L.append(
            f"    input logic [{c.max_width-1}:0] {c.lname}_pclk,"
            f"   // {c.name}'s own already-divided pclk, one bit per its own port"
        )
    for g in (cfg.groups if dpr else [g for g in cfg.groups if not g.is_direct]):
        eff_n = g.n + 1 if dpr else g.n
        for l in g.lanes:
            L.append(
                f"    input logic [{eff_n-1}:0] seltgt_g{g.gid}_l{l},"
                f"   // dec_tgt.g{g.gid} already synchronized into this lane's owning candidate's own port clock, from sel_gen -- also gates phy_pclk"
            )
    for g in cfg.groups:
        if g.is_direct:
            continue
        for l in g.lanes:
            L.append(
                f"    input logic [{g.n-1}:0] rxclk_en_g{g.gid}_l{l},"
                f"   // dec_tgt.g{g.gid} already synchronized into rx_clk[{l}]'s domain, from sel_gen"
            )
    if dpr:
        L.append("    input logic [NL-1:0] v_lane_mask,")
        L.append("    input logic dpr_rst_n,")
    L.append("    output logic [NL-1:0] phy_pclk,")
    if dpr:
        L.append("    output logic dpr_pclk,   // DPR's own working clock, derived below")
    for cid in sorted(cfg.controllers):
        c = cfg.controllers[cid]
        L.append(f"    output logic [{c.max_width-1}:0] {c.lname}_rx_clk,")
    L[-1] = L[-1].rstrip(",")
    L.append(");")
    L.append("")

    # phy_pclk: glitch-free, per physical lane (not per group). This first
    # computes each lane's REAL-candidates-only glitch-free clock (exactly
    # what this section already computed pre-DPR) into real_pclk[l] -- with
    # --dpr, DPR's own working clock is itself derived from these real_pclk[]
    # values (see below), and the final phy_pclk[l] is a 2-way overlay
    # between real_pclk[l] and dpr_pclk, reusing sel_gen's already-
    # synchronized seltgt_gN_lL (its real-candidate bits and its DPR bit are
    # already mutually exclusive -- one-hot by construction -- so no extra
    # synchronizer is needed just for this overlay).
    L.append("    //------------------------------------------------------------")
    L.append("    // phy_pclk: glitch-free per-lane select among the owning group's")
    L.append("    // candidate controllers' own port-level pclk.")
    L.append("    //------------------------------------------------------------")
    real_pclk_expr = {}  # lane -> SV expression for that lane's real-candidates-only clock
    for g in cfg.groups:
        if g.is_direct:
            c = g.cands[0]
            cname = cfg.controllers[c].lname
            m0 = cfg.modes[0]
            for l in g.lanes:
                cl = cfg.mapping[m0][l][1]
                real_pclk_expr[l] = f"{cname}_pclk[{cl}]"
                if not dpr:
                    L.append(
                        f"    assign phy_pclk[{l}] = {real_pclk_expr[l]};"
                        f"  // G{g.gid} direct to {cfg.controllers[c].name}"
                    )
            L.append("")
        else:
            names = ", ".join(cfg.controllers[c].name for c in g.cands)
            L.append(f"    // G{g.gid} lane{g.lanes[0]}~{g.lanes[-1]}: {names}, per-lane glitch-free select")
            for l in g.lanes:
                port_of_cand = {}
                for c in g.cands:
                    m = next(mm for mm in cfg.modes if g.owners[mm] == c)
                    port_of_cand[c] = cfg.mapping[m][l][1]
                L.append(f"    logic [{g.n-1}:0] pclk_gated_g{g.gid}_l{l};")
                for i, c in enumerate(g.cands):
                    L.append(
                        f"    pipe_lane_clk_gate u_pclk_gate_g{g.gid}_l{l}_b{i} ("
                        f".clk_in({cfg.controllers[c].lname}_pclk[{port_of_cand[c]}]), "
                        f".en(seltgt_g{g.gid}_l{l}[{i}]), "
                        f".test_en(test_en), .clk_out(pclk_gated_g{g.gid}_l{l}[{i}]));"
                    )
                if dpr:
                    L.append(f"    logic real_pclk_g{g.gid}_l{l};")
                    L.append(
                        f"    pipe_lane_clk_or #(.N({g.n})) u_pclk_or_g{g.gid}_l{l} "
                        f"(.clk_in(pclk_gated_g{g.gid}_l{l}), .clk_out(real_pclk_g{g.gid}_l{l}));"
                    )
                    real_pclk_expr[l] = f"real_pclk_g{g.gid}_l{l}"
                else:
                    L.append(
                        f"    pipe_lane_clk_or #(.N({g.n})) u_pclk_or_g{g.gid}_l{l} "
                        f"(.clk_in(pclk_gated_g{g.gid}_l{l}), .clk_out(phy_pclk[{l}]));"
                    )
                L.append("")

    if dpr:
        default_lane = cfg.groups[-1].lanes[0]  # last group's lowest lane
        L.append("    //------------------------------------------------------------")
        L.append("    // DPR's own working clock: from the lowest-numbered currently-masked")
        L.append("    // lane's own real-candidates-only clock (real_pclk[] above) -- same")
        L.append("    // glitch-free multi-candidate select pattern a multi-candidate")
        L.append("    // controller's own pclk generation uses in pclk_as_phy_output mode,")
        L.append("    // just with real_pclk[] as candidates instead of phy_pclk_out[].")
        L.append(f"    // Defaults to lane{default_lane} (last group's lowest lane) when idle.")
        L.append("    //------------------------------------------------------------")
        L.append("    logic [NL-1:0] real_pclk;")
        for l in range(LC):
            L.append(f"    assign real_pclk[{l}] = {real_pclk_expr[l]};")
        L.append("    logic [NL-1:0] dpr_pclk_tgt;")
        L.append("    // isolate the lowest set bit: v_lane_mask & (-v_lane_mask)")
        L.append("    assign dpr_pclk_tgt = v_lane_mask & (~v_lane_mask + 1'b1);")
        L.append("")
        gen_glitch_free_clk_select(
            L,
            "dpr_pclk",
            [f"real_pclk[{l}]" for l in range(LC)],
            "dpr_rst_n",
            "dpr_pclk_tgt",
            default_lane,
            "dpr_pclk",
        )
        L.append("")

        L.append("    //------------------------------------------------------------")
        L.append("    // Final phy_pclk: real_pclk[l] (branch 0) vs dpr_pclk (branch 1),")
        L.append("    // reusing sel_gen's already-synchronized seltgt_gN_lL directly --")
        L.append("    // no separate synchronizer needed for this overlay.")
        L.append("    //------------------------------------------------------------")
        for g in cfg.groups:
            for l in g.lanes:
                L.append(f"    logic [1:0] dpr_pclk_ovl_l{l};")
                L.append(
                    f"    pipe_lane_clk_gate u_dpr_pclk_ovl_gate_l{l}_b0 (.clk_in({real_pclk_expr[l]}), "
                    f".en(|seltgt_g{g.gid}_l{l}[{g.n-1}:0]), .test_en(test_en), "
                    f".clk_out(dpr_pclk_ovl_l{l}[0]));"
                )
                L.append(
                    f"    pipe_lane_clk_gate u_dpr_pclk_ovl_gate_l{l}_b1 (.clk_in(dpr_pclk), "
                    f".en(seltgt_g{g.gid}_l{l}[{g.n}]), .test_en(test_en), "
                    f".clk_out(dpr_pclk_ovl_l{l}[1]));"
                )
                L.append(
                    f"    pipe_lane_clk_or #(.N(2)) u_dpr_pclk_ovl_or_l{l} "
                    f"(.clk_in(dpr_pclk_ovl_l{l}), .clk_out(phy_pclk[{l}]));"
                )
                L.append("")

    # rx_clk: glitch-free, per physical lane. rx_clk[l] is its own recovered
    # clock domain (no fixed phase relation to ctrl_pclk or to any
    # other lane), so switching which candidate currently receives it needs
    # dec_tgt synchronized into rx_clk[l]'s own domain -- that synchronizer
    # (rxclk_en_g{gid}_l{l}) lives in pipe_lane_sel_gen, passed in here as
    # an input; this module only does the final clk_gate + assign.
    L.append("    //------------------------------------------------------------")
    L.append("    // rx_clk: glitch-free per-lane select, using rxclk_en_g{gid}_l{l} from")
    L.append("    // sel_gen (already synchronized into rx_clk[l]'s own domain).")
    L.append("    //------------------------------------------------------------")
    assigned_ports = set()
    for g in cfg.groups:
        if g.is_direct:
            c = g.cands[0]
            cname = cfg.controllers[c].lname
            m0 = cfg.modes[0]
            for l in g.lanes:
                cl = cfg.mapping[m0][l][1]
                L.append(
                    f"    assign {cname}_rx_clk[{cl}] = rx_clk[{l}];"
                    f"  // G{g.gid} direct to {cfg.controllers[c].name}"
                )
                assigned_ports.add((c, cl))
            L.append("")
        else:
            names = ", ".join(cfg.controllers[c].name for c in g.cands)
            L.append(f"    // G{g.gid} lane{g.lanes[0]}~{g.lanes[-1]}: {names}, per-lane glitch-free select")
            for l in g.lanes:
                port_of_cand = {}
                for c in g.cands:
                    m = next(mm for mm in cfg.modes if g.owners[mm] == c)
                    port_of_cand[c] = cfg.mapping[m][l][1]
                for i, c in enumerate(g.cands):
                    cname = cfg.controllers[c].lname
                    cl = port_of_cand[c]
                    L.append(
                        f"    pipe_lane_clk_gate u_rxclk_gate_g{g.gid}_l{l}_b{i} ("
                        f".clk_in(rx_clk[{l}]), .en(rxclk_en_g{g.gid}_l{l}[{i}]), "
                        f".test_en(test_en), .clk_out({cname}_rx_clk[{cl}]));"
                    )
                    assigned_ports.add((c, cl))
                L.append("")

    # Ports that never get a lane in any mode -- tie their rx_clk low.
    for cid in sorted(cfg.controllers):
        c = cfg.controllers[cid]
        for cl in range(c.max_width):
            if (cid, cl) not in assigned_ports:
                L.append(f"    assign {c.lname}_rx_clk[{cl}] = 1'b0;  // never driven in any mode")
    L.append("")
    L.append("endmodule")
    return "\n".join(L) + "\n"


# ---------------------------------------------------------------- reset-mux submodule


def gen_rst_mux(cfg, dpr=False):
    """Each lane's phy_rst_n connects to its current owner's ctrl_rst_n.

    The input port is still called sel_tgt, but at the top level it's
    actually wired to pipe_lane_sel_gen's dec_tgt (the decoder's raw,
    unsynchronized target), not sel_gen's final external sel_tgt. This
    lets the new owner's reset control change immediately with mode,
    without waiting for pipe_lane_sel_sync to finish cross-clock-domain
    synchronization and the non-overlap window. Same for DPR: dec_tgt
    already has DPR combined in as one more candidate (see
    pipe_lane_sel_gen), so dpr_rst_n takes over immediately too.
    """
    LC, NC = cfg.lane_count, cfg.num_ctrl

    L = [
        "// PIPE lane mapper reset-mux submodule.",
        "// Each lane's phy_rst_n connects to its current owner's ctrl_rst_n.",
        "// The input port is named sel_tgt, but at the top level it's actually wired to",
        "// pipe_lane_sel_gen's dec_tgt (the decoder's raw output, not synchronized by pipe_lane_sel_sync),",
        "// not sel_gen's final external sel_tgt -- reset follows mode directly, without waiting for pipe_lane_sel_sync.",
        "// Reuses pipe_lane_data_mux's polarity normalization: when sel_tgt is all-zero (the handoff window,",
        "// no owner), the safe state is to hold reset (0), not float or hold the previous owner.",
        "import pipe_lane_signal_pkg::*;",
        "",
        "module pipe_lane_rst_mux #(",
        f"    parameter int NL = {LC},",
        f"    parameter int NC = {NC}",
        ") (",
        "    input logic [NC-1:0] ctrl_rst_n,",
    ]
    if dpr:
        L.append("    input logic dpr_rst_n,")
    L.append("    input lane_sel_t sel_tgt,")
    L.append("    output logic [NL-1:0] phy_rst_n")
    L.append(");")
    L.append("")

    for g in cfg.groups:
        if g.is_direct and not dpr:
            c = g.cands[0]
            for l in g.lanes:
                L.append(
                    f"    assign phy_rst_n[{l}] = ctrl_rst_n[{c}];"
                    f"  // G{g.gid} direct to {cfg.controllers[c].name}"
                )
        else:
            names = ", ".join(cfg.controllers[c].name for c in g.cands) + (", DPR" if dpr else "")
            n = g.n + 1 if dpr else g.n
            L.append(f"    // G{g.gid} lane{g.lanes[0]}~{g.lanes[-1]}: {names}")
            L.append(f"    logic rst_n_g{g.gid};")
            L.append(f"    pipe_lane_data_mux #(.WIDTH(1), .N({n})) u_rst_g{g.gid} (")
            L.append(f"        .sel  (sel_tgt.g{g.gid}),")
            din_terms = ", ".join(f"ctrl_rst_n[{c}]" for c in reversed(g.cands))
            if dpr:
                din_terms = "dpr_rst_n, " + din_terms
            L.append(f"        .din  ({{{din_terms}}}),")
            L.append("        .safe (1'b0),")
            L.append(f"        .dout (rst_n_g{g.gid})")
            L.append("    );")
            for l in g.lanes:
                L.append(f"    assign phy_rst_n[{l}] = rst_n_g{g.gid};")
    L.append("")
    L.append("endmodule")
    return "\n".join(L) + "\n"


# ---------------------------------------------------------------- MAC->PHY data


def gen_data_m2p(cfg, pclk_mode="pclk_as_phy_output", dpr=False):
    """mac2phy-direction data mux.

    In pclk_mode="pclk_as_phy_input", each pipe_lane_data_mux's .sel comes
    from a per-lane seltgt_g{gid}_l{l} input instead of the group-shared
    sel_tgt -- see gen_sel_gen()'s docstring for why a group-shared select
    is the wrong domain once {c.lname}_pclk is per-port.

    When --dpr, DPR is one more (the last) branch of every group's select
    -- see pipe_lane_sel_gen -- so every group needs a real mux here now,
    including ones that were a direct (single-candidate) connection before
    DPR existed.
    """
    LC = cfg.lane_count
    phy_input_mode = pclk_mode == "pclk_as_phy_input"
    L = [
        "// PIPE lane mapper MAC->PHY data mux.",
        "// pipe_lane_data_mux performs polarity normalization internally; output is SAFE_M2P when sel is all-zero.",
        "import pipe_lane_signal_pkg::*;",
        "",
        "module pipe_lane_data_m2p #(",
        f"    parameter int NL = {LC}",
        ") (",
    ]
    if phy_input_mode:
        for g in (cfg.groups if dpr else [g for g in cfg.groups if not g.is_direct]):
            eff_n = g.n + 1 if dpr else g.n
            for l in g.lanes:
                L.append(f"    input logic [{eff_n-1}:0] seltgt_g{g.gid}_l{l},")
    else:
        L.append("    input lane_sel_t sel_tgt,")
    L.append("    output mac2phy_lane_t [NL-1:0] phy_mac2phy,")
    if dpr:
        L.append("    input mac2phy_lane_t [NL-1:0] dpr_mac2phy,")
    for cid in sorted(cfg.controllers):
        c = cfg.controllers[cid]
        L.append(f"    input mac2phy_lane_t [{c.max_width-1}:0] {c.lname}_mac2phy,")
    L[-1] = L[-1].rstrip(",")
    L.append(");")
    L.append("")

    for g in cfg.groups:
        for l in g.lanes:
            if g.is_direct and not dpr:
                c = g.cands[0]
                cl = cfg.mapping[cfg.modes[0]][l][1]
                L.append(
                    f"    assign phy_mac2phy[{l}] = "
                    f"{cfg.controllers[c].lname}_mac2phy[{cl}];  // direct connection"
                )
            else:
                srcs = []
                for c in g.cands:
                    m = next(mm for mm in cfg.modes if g.owners[mm] == c)
                    cl = cfg.mapping[m][l][1]
                    srcs.append(f"{cfg.controllers[c].lname}_mac2phy[{cl}]")
                if dpr:
                    srcs.append(f"dpr_mac2phy[{l}]")
                n = g.n + 1 if dpr else g.n
                L.append(
                    f"    pipe_lane_data_mux #(.WIDTH(MAC2PHY_W), " f".N({n})) u_m2p_l{l} ("
                )
                sel_expr = f"seltgt_g{g.gid}_l{l}" if phy_input_mode else f"sel_tgt.g{g.gid}"
                L.append(f"        .sel  ({sel_expr}),")
                L.append("        .din  ({" + ", ".join(reversed(srcs)) + "}),")
                L.append("        .safe (SAFE_M2P),")
                L.append(f"        .dout (phy_mac2phy[{l}])")
                L.append("    );")
    L.append("")
    L.append("endmodule")
    return "\n".join(L) + "\n"


# ---------------------------------------------------------------- PHY->MAC data


def gen_data_p2m(cfg, pclk_mode="pclk_as_phy_output", dpr=False):
    """phy2mac-direction data mux (converges by controller port).

    In pclk_mode="pclk_as_phy_input", there's no single group-shared select
    to use per port: a converging port's candidates can each own a
    DIFFERENT physical lane within the group (each with its own per-lane
    seltgt_g{gid}_l{l}), so this mux's .sel is assembled bit-by-bit, one
    bit per branch, from that branch's own lane's own sync result -- see
    gen_sel_gen()'s docstring for why a group-shared select is the wrong
    domain once {c.lname}_pclk is per-port.

    Real controllers' own converge logic here is otherwise untouched by
    --dpr: which lanes feed a given controller port is purely a
    lane_mapping.csv/mode fact, DPR is never in it -- there's no driver
    contention to arbitrate (DPR never competes to drive any of these
    controller ports), so the real candidates' own muxes don't need an
    extra DPR branch: sel_tgt.gN/seltgt_gN_lL's real-candidate bits are
    already all 0 whenever DPR currently owns the group (one-hot), which
    already resolves to each mux's own safe/tie value for free.

    dpr_phy2mac IS new with --dpr: a separate read-only tap DPR uses to
    observe the raw PHY signal for whichever lanes it currently owns. It
    still isn't a mux branch (no driver contention, so no
    pipe_lane_data_mux needed for it either) -- but it does need to gate on
    the SAME synchronized "DPR owns this lane" bit that already gates
    phy_mac2phy/phy_pclk_in for that lane (sel_tgt.gN[g.n] here, the top
    bit pipe_lane_sel_gen appends when --dpr), not the raw v_lane_mask
    input directly. v_lane_mask is a live, asynchronous, un-gapped signal;
    reading it straight would let dpr_phy2mac flip the instant v_lane_mask
    does, while the write side only actually hands the lane over after the
    NOV gap + synchronizer finish -- DPR would then appear to already own
    (or have already released) a lane whose data path hasn't caught up
    yet. Gating on the same synchronized bit keeps dpr_phy2mac's view of
    ownership in lockstep with what's actually happening on the wire,
    which is the entire reason that bit gets synchronized in the first
    place.

    When --dpr, every group needs its per-lane/group select input here
    (including groups that were a direct, unmuxed connection before DPR
    existed) purely so dpr_phy2mac has that bit to read -- see
    gen_data_m2p()'s docstring for the parallel reasoning on the write
    side, where those same now-2-candidate groups need a real mux too.
    """
    LC = cfg.lane_count
    phy_input_mode = pclk_mode == "pclk_as_phy_input"
    p2m_sigs_all = [s for s in cfg.signals if not s.is_m2p]
    L = [
        "// PIPE lane mapper PHY->MAC data mux (converges by controller port).",
        "// sel_tgt's mutual exclusivity is guaranteed by pipe_lane_sel_sync. Undriven ports are tied to the safe state.",
        "import pipe_lane_signal_pkg::*;",
        "",
        "module pipe_lane_data_p2m #(",
        f"    parameter int NL = {LC}",
        ") (",
    ]
    if phy_input_mode:
        for g in (cfg.groups if dpr else [g for g in cfg.groups if not g.is_direct]):
            eff_n = g.n + 1 if dpr else g.n
            for l in g.lanes:
                L.append(f"    input logic [{eff_n-1}:0] seltgt_g{g.gid}_l{l},")
    else:
        L.append("    input lane_sel_t sel_tgt,")
    L.append("    input phy2mac_lane_t [NL-1:0] phy_phy2mac,")
    if dpr:
        L.append("    output phy2mac_lane_t [NL-1:0] dpr_phy2mac,")
    for cid in sorted(cfg.controllers):
        c = cfg.controllers[cid]
        L.append(f"    output phy2mac_lane_t [{c.max_width-1}:0] {c.lname}_phy2mac,")
    L[-1] = L[-1].rstrip(",")
    L.append(");")
    L.append("")

    port_src = {}
    for m in cfg.modes:
        for l in range(LC):
            cid, cl = cfg.mapping[m][l]
            g = cfg.group_of_lane(l)
            b = 0 if g.is_direct else g.branch_of(cid)
            port_src.setdefault((cid, cl), set()).add((l, g.gid, b))
    for cid in sorted(cfg.controllers):
        c = cfg.controllers[cid]
        L.append(f"    // {c.name} x{c.max_width}")

        # Compute this controller's active lowest-numbered physical lane
        # (used for safe alignment on unused ports)
        cands = cfg.ctrl_pclk_cands()[c.id]
        base_lane = cands[0] if cands else 0

        # Dynamically resolve each signal's tie_off setting to build
        # p2m_tie (tie_off semantics are defined exactly once, in
        # Signal.tie_expr() -- this shares that same logic with the
        # expected-value assertions in gen_tb())
        p2m_signals = [s for s in cfg.signals if not s.is_m2p]
        base_lane_expr = f"phy_phy2mac[{base_lane}]"
        assign_parts = [
            f"{s.name}: {s.tie_expr(base_lane_expr)}" for s in p2m_signals if not s.tie_is_zero
        ]
        assign_parts.append("default: '0")

        L.append(f"    phy2mac_lane_t {c.lname}_p2m_tie;")
        L.append(f"    assign {c.lname}_p2m_tie = '{{")
        for part in assign_parts[:-1]:
            L.append(f"        {part},")
        L.append(f"        {assign_parts[-1]}")
        L.append("    };")
        L.append("")

        for cl in range(c.max_width):
            srcs = sorted(port_src.get((cid, cl), set()))
            if not srcs:
                L.append(
                    f"    assign {c.lname}_phy2mac[{cl}] = {c.lname}_p2m_tie;"
                    f"  // never driven in any mode"
                )
                continue
            if len(srcs) == 1 and cfg.groups[srcs[0][1]].is_direct and not dpr:
                l = srcs[0][0]
                L.append(
                    f"    assign {c.lname}_phy2mac[{cl}] = phy_phy2mac[{l}];"
                    f"  // direct connection to lane{l}"
                )
                continue
            gid = srcs[0][1]
            g = cfg.groups[gid]
            din = []
            sel_bits = []
            for i in range(g.n):
                hit = [s for s in srcs if s[2] == i]
                if hit:
                    din.append(f"phy_phy2mac[{hit[0][0]}]")
                    sel_bits.append(f"seltgt_g{gid}_l{hit[0][0]}[{i}]")
                else:
                    din.append(f"{c.lname}_p2m_tie")
                    sel_bits.append("1'b0")
            L.append(
                f"    pipe_lane_data_mux #(.WIDTH(PHY2MAC_W), "
                f".N({g.n})) u_p2m_{c.lname}_{cl} ("
            )
            if phy_input_mode:
                sel_expr = "{" + ", ".join(reversed(sel_bits)) + "}"
            elif dpr:
                # sel_tgt.g{gid} is g.n+1 bits wide with --dpr (DPR's own bit
                # appended, see pipe_lane_sel_gen) -- only the real
                # candidates' own g.n bits are relevant here; they're
                # naturally all 0 when DPR currently owns the group, so this
                # mux already falls back to the safe tie value in that case.
                sel_expr = f"sel_tgt.g{gid}[{g.n-1}:0]"
            else:
                sel_expr = f"sel_tgt.g{gid}"
            L.append(f"        .sel  ({sel_expr}),")
            L.append("        .din  ({" + ", ".join(reversed(din)) + "}),")
            L.append(f"        .safe ({c.lname}_p2m_tie),")
            L.append(f"        .dout ({c.lname}_phy2mac[{cl}])")
            L.append("    );")
        L.append("")

    if dpr:
        L.append("    //------------------------------------------------------------")
        L.append("    // PHY -> DPR: read-only tap, no pipe_lane_data_mux needed (no driver")
        L.append("    // contention) -- but gated on the SAME synchronized \"DPR owns this")
        L.append("    // lane\" bit that already gates phy_mac2phy/phy_pclk_in for it, not raw")
        L.append("    // v_lane_mask, so this tap's view of ownership stays in lockstep with")
        L.append("    // what the write side is actually doing (see this module's docstring).")
        L.append("    // Each signal's safe/tie value (same tie_off convention as an unowned")
        L.append("    // controller port) when not owned. tie_off=lane0 has no meaningful")
        L.append("    // \"DPR's own base lane\" to fall back to (DPR's owned set is a live")
        L.append("    // runtime value, not fixed), so it resolves to '0 for DPR specifically.")
        L.append("    //------------------------------------------------------------")
        dpr_tie_parts = [f"{s.name}: {s.tie_expr(None)}" for s in p2m_sigs_all if not s.tie_is_zero]
        dpr_tie_parts.append("default: '0")
        L.append("    phy2mac_lane_t dpr_p2m_tie;")
        L.append("    assign dpr_p2m_tie = '{")
        for part in dpr_tie_parts[:-1]:
            L.append(f"        {part},")
        L.append(f"        {dpr_tie_parts[-1]}")
        L.append("    };")
        for l in range(LC):
            g = cfg.group_of_lane(l)
            own_expr = f"seltgt_g{g.gid}_l{l}[{g.n}:{g.n}]" if phy_input_mode else f"sel_tgt.g{g.gid}[{g.n}:{g.n}]"
            # Same pipe_lane_data_mux shape as every real single-candidate
            # port above (e.g. a direct group's own u_p2m_{c.lname}_{cl}
            # with .N(1)) -- DPR's own p2m tap is architecturally nothing
            # but a single-candidate port converging from exactly one
            # source (this lane), so it reuses that exact same
            # instantiation instead of a bespoke ternary assign.
            L.append(f"    pipe_lane_data_mux #(.WIDTH(PHY2MAC_W), .N(1)) u_p2m_dpr_{l} (")
            L.append(f"        .sel  ({own_expr}),")
            L.append(f"        .din  ({{phy_phy2mac[{l}]}}),")
            L.append("        .safe (dpr_p2m_tie),")
            L.append(f"        .dout (dpr_phy2mac[{l}])")
            L.append("    );")
        L.append("")

    L.append("endmodule")
    return "\n".join(L) + "\n"


# ---------------------------------------------------------------- top level


def gen_top(cfg, pclk_mode="pclk_as_phy_output", sel_mode="sync", dpr=False):
    nm = len(cfg.modes)
    LC, NC = cfg.lane_count, cfg.num_ctrl
    phy_input_mode = pclk_mode == "pclk_as_phy_input"
    sync_lit = "1'b1" if sel_mode == "sync" else "1'b0"

    L = ["// PIPE lane mapper top level."]
    L.append("//")
    L.append("// Pure instantiation layer:")
    if phy_input_mode:
        L.append(
            "//   pipe_lane_sel_gen  -- mode decoding + per-lane pipe_lane_sel_sync, produces"
        )
        L.append("//                        seltgt_gN_lL / rxclk_en_gN_lL")
        L.append(
            "//   pipe_lane_clk_mux  -- glitch-free phy_pclk feedback switching + rx_clk routing"
        )
    else:
        L.append(
            "//   pipe_lane_sel_gen  -- mode decoding + group pipe_lane_sel_sync, produces sel_tgt"
        )
        L.append("//   pipe_lane_clk_mux  -- controller pclk generation + feedback clock mux")
    L.append("//   pipe_lane_rst_mux  -- reset mux")
    L.append("//   pipe_lane_data_m2p -- MAC->PHY data mux")
    L.append("//   pipe_lane_data_p2m -- PHY->MAC data mux")
    L.append("//")
    L.append(
        "// Lane grouping: lanes with the same owner sequence are grouped automatically, sharing one NOV."
    )
    L.append("//")
    for g in cfg.groups:
        rng = f"lane{g.lanes[0]}~{g.lanes[-1]}" if len(g.lanes) > 1 else f"lane{g.lanes[0]}"
        owners = " / ".join(cfg.controllers[g.owners[m]].name for m in cfg.modes)
        kind = "direct" if g.is_direct else f"{g.n}-way NOV"
        L.append(f"//   G{g.gid} {rng:<14} {owners:<24} {kind}")
    L.append("import pipe_lane_signal_pkg::*;")
    L.append("")
    L.append("module pipe_lane_mapper #(")
    L.append(f"    parameter int NL = {LC},")
    L.append(f"    parameter int NC = {NC},")
    L.append(
        f"    parameter bit SEL_SYNC = {sync_lit}"
        "   // pipe_lane_sel_gen's data-path pipe_lane_sel_sync SYNC, see there"
    )
    L.append(") (")
    if phy_input_mode:
        L.append("    input logic test_en,")
        L.append(f"    input logic [{mode_width(nm)-1}:0] mode,")
        L.append("    input logic [NL-1:0] rx_clk,     // PHY's per-lane recovered clock")
        L.append("    output logic [NL-1:0] phy_pclk,")
        L.append("    output logic [NL-1:0] phy_rst_n,")
    else:
        L.append("    input logic [NL-1:0] phy_pclk_out,")
        L.append("    input logic test_en,")
        L.append(f"    input logic [{mode_width(nm)-1}:0] mode,")
        L.append("    output logic [NL-1:0] phy_pclk_in,")
        L.append("    output logic [NL-1:0] phy_rst_n,")
    L.append("    // PHY-side PIPE data")
    L.append("    output mac2phy_lane_t [NL-1:0] phy_mac2phy,")
    L.append("    input phy2mac_lane_t [NL-1:0] phy_phy2mac,")
    if dpr:
        L.append("    // DPR (diagnostic probe): a virtual controller with link width NL,")
        L.append("    // connected 1:1 to every PHY lane -- v_lane_mask[l]=1 overrides lane l.")
        L.append("    input logic [NL-1:0] v_lane_mask,")
        L.append("    input logic dpr_rst_n,")
        L.append("    input mac2phy_lane_t [NL-1:0] dpr_mac2phy,")
        L.append("    output phy2mac_lane_t [NL-1:0] dpr_phy2mac,")
        L.append("    output logic dpr_pclk,   // DPR's own working clock, so external logic can sync to it")
    L.append("    // Controller side. Each controller's ports are declared at its own real max_width.")
    for cid in sorted(cfg.controllers):
        c = cfg.controllers[cid]
        L.append(f"    // {c.name} x{c.max_width}")
        L.append(f"    input logic {c.lname}_rst_n,   // already synchronized externally")
        L.append(f"    input mac2phy_lane_t [{c.max_width-1}:0] {c.lname}_mac2phy,")
        L.append(f"    output phy2mac_lane_t [{c.max_width-1}:0] {c.lname}_phy2mac,")
        if phy_input_mode:
            L.append(f"    input logic [{c.max_width-1}:0] {c.lname}_pclk,")
            L.append(f"    output logic [{c.max_width-1}:0] {c.lname}_rx_clk,")
        else:
            L.append(f"    output logic {c.lname}_pclk,")
    L[-1] = L[-1].rstrip(",")
    L.append(");")
    L.append("")

    cc = cfg.ctrl_pclk_cands()
    muxed_c = [c for c in sorted(cfg.controllers) if len(cc[c]) > 1]

    # ---- internal wiring
    L.append(
        "    logic [NC-1:0] ctrl_rst_n;   // reconstructed from each controller's own named port above"
    )
    L.append(
        "    assign ctrl_rst_n = {"
        + ", ".join(f"{cfg.controllers[cid].lname}_rst_n" for cid in sorted(cfg.controllers, reverse=True))
        + "};"
    )
    if not phy_input_mode:
        L.append(
            "    logic [NC-1:0] ctrl_pclk;   // driven by u_clk_mux below, flattened out to each controller's own named port"
        )
    if not phy_input_mode:
        L.append(
            "    lane_sel_t sel_tgt;   // each group's currently effective owner selection (after pipe_lane_sel_sync)"
        )
    L.append(
        "    lane_sel_t dec_tgt;   // each group's raw decoder selection (unsynchronized"
        + (", DPR-combined), used by rst_mux" if dpr else "), used by rst_mux")
    )
    for c in muxed_c:
        L.append(
            f"    logic [{len(cc[c])-1}:0] pclk_tgt_c{c};"
            f"   // pclk candidate target for {cfg.controllers[c].name}"
        )
    rxclk_lanes = []
    seltgt_lanes = []
    if phy_input_mode:
        for g in (cfg.groups if dpr else [g for g in cfg.groups if not g.is_direct]):
            eff_n = g.n + 1 if dpr else g.n
            for l in g.lanes:
                seltgt_lanes.append((g.gid, l, eff_n))
                L.append(
                    f"    logic [{eff_n-1}:0] seltgt_g{g.gid}_l{l};"
                    f"   // dec_tgt.g{g.gid} synchronized into this lane's owning candidate's own port clock"
                )
        for g in cfg.groups:
            if g.is_direct:
                continue
            for l in g.lanes:
                rxclk_lanes.append((g.gid, l, g.n))
                L.append(
                    f"    logic [{g.n-1}:0] rxclk_en_g{g.gid}_l{l};"
                    f"   // dec_tgt.g{g.gid} synchronized into rx_clk[{l}]'s domain"
                )
    L.append("")

    # ---- select-generation submodule
    L.append("    //------------------------------------------------------------")
    L.append(
        "    // Select-generation submodule: mode decoding + group pipe_lane_sel_sync, produces sel_tgt / dec_tgt"
    )
    L.append("    //------------------------------------------------------------")
    L.append("    pipe_lane_sel_gen #(")
    L.append("        .NC (NC),")
    if phy_input_mode or dpr:
        L.append("        .NL (NL),")
    L.append("        .SEL_SYNC (SEL_SYNC)")
    L.append("    ) u_sel_gen (")
    L.append("        .mode       (mode),")
    if phy_input_mode:
        for cid in sorted(cfg.controllers):
            c = cfg.controllers[cid]
            L.append(f"        .{c.lname}_pclk ({c.lname}_pclk),")
    else:
        L.append("        .ctrl_pclk  (ctrl_pclk),")
    L.append("        .ctrl_rst_n (ctrl_rst_n),")
    if phy_input_mode:
        L.append("        .rx_clk     (rx_clk),")
    else:
        L.append("        .sel_tgt    (sel_tgt),")
    if dpr:
        L.append("        .v_lane_mask (v_lane_mask),")
        L.append("        .dpr_rst_n   (dpr_rst_n),")
        L.append("        .dpr_pclk    (dpr_pclk),")
    L.append(
        "        .dec_tgt    (dec_tgt)" + ("," if (muxed_c or seltgt_lanes or rxclk_lanes) else "")
    )
    for i, c in enumerate(muxed_c):
        tail = "," if (i != len(muxed_c) - 1 or seltgt_lanes or rxclk_lanes) else ""
        L.append(f"        .pclk_tgt_c{c} (pclk_tgt_c{c}){tail}")
    for i, (gid, l, _n) in enumerate(seltgt_lanes):
        tail = "," if (i != len(seltgt_lanes) - 1 or rxclk_lanes) else ""
        L.append(f"        .seltgt_g{gid}_l{l} (seltgt_g{gid}_l{l}){tail}")
    for i, (gid, l, _n) in enumerate(rxclk_lanes):
        tail = "," if i != len(rxclk_lanes) - 1 else ""
        L.append(f"        .rxclk_en_g{gid}_l{l} (rxclk_en_g{gid}_l{l}){tail}")
    L.append("    );")
    L.append("")

    # ---- clock-mux submodule
    L.append("    //------------------------------------------------------------")
    if phy_input_mode:
        L.append("    // Clock-mux submodule: glitch-free phy_pclk feedback switching + rx_clk routing")
    else:
        L.append("    // Clock-mux submodule: ctrl_pclk generation + feedback clock mux")
    L.append("    //------------------------------------------------------------")
    L.append("    pipe_lane_clk_mux #(")
    L.append("        .NL (NL),")
    L.append("        .NC   (NC)")
    L.append("    ) u_clk_mux (")
    if phy_input_mode:
        L.append("        .test_en      (test_en),")
        L.append("        .ctrl_rst_n   (ctrl_rst_n),")
        L.append("        .rx_clk       (rx_clk),")
        for cid in sorted(cfg.controllers):
            c = cfg.controllers[cid]
            L.append(f"        .{c.lname}_pclk ({c.lname}_pclk),")
        for gid, l, _n in seltgt_lanes:
            L.append(f"        .seltgt_g{gid}_l{l} (seltgt_g{gid}_l{l}),")
        for gid, l, _n in rxclk_lanes:
            L.append(f"        .rxclk_en_g{gid}_l{l} (rxclk_en_g{gid}_l{l}),")
        if dpr:
            L.append("        .v_lane_mask  (v_lane_mask),")
            L.append("        .dpr_rst_n    (dpr_rst_n),")
            L.append("        .dpr_pclk     (dpr_pclk),")
        L.append("        .phy_pclk     (phy_pclk),")
        for cid in sorted(cfg.controllers):
            c = cfg.controllers[cid]
            L.append(f"        .{c.lname}_rx_clk ({c.lname}_rx_clk),")
        L[-1] = L[-1].rstrip(",")
    else:
        L.append("        .phy_pclk_out (phy_pclk_out),")
        L.append("        .test_en      (test_en),")
        L.append("        .ctrl_rst_n   (ctrl_rst_n),")
        for c in muxed_c:
            L.append(f"        .pclk_tgt_c{c} (pclk_tgt_c{c}),")
        L.append("        .sel_tgt      (sel_tgt),")
        if dpr:
            L.append("        .v_lane_mask  (v_lane_mask),")
            L.append("        .dpr_rst_n    (dpr_rst_n),")
        L.append("        .ctrl_pclk    (ctrl_pclk),")
        if dpr:
            L.append("        .dpr_pclk     (dpr_pclk),")
        L.append("        .phy_pclk_in  (phy_pclk_in)")
    L.append("    );")
    L.append("")

    if not phy_input_mode:
        for cid in sorted(cfg.controllers):
            c = cfg.controllers[cid]
            L.append(f"    assign {c.lname}_pclk = ctrl_pclk[{cid}];")
        L.append("")

    # ---- reset-mux submodule
    L.append("    //------------------------------------------------------------")
    L.append("    // Reset-mux submodule: phy_rst_n selects ctrl_rst_n by current owner")
    L.append(
        "    // Uses dec_tgt (the decoder's raw output, not synchronized by pipe_lane_sel_sync), not sel_tgt"
    )
    L.append("    //------------------------------------------------------------")
    L.append("    pipe_lane_rst_mux #(")
    L.append("        .NL (NL),")
    L.append("        .NC   (NC)")
    L.append("    ) u_rst_mux (")
    L.append("        .ctrl_rst_n (ctrl_rst_n),")
    if dpr:
        L.append("        .dpr_rst_n  (dpr_rst_n),")
    L.append("        .sel_tgt    (dec_tgt),")
    L.append("        .phy_rst_n  (phy_rst_n)")
    L.append("    );")
    L.append("")

    # ---- MAC->PHY data submodule
    L.append("    //------------------------------------------------------------")
    L.append("    // MAC->PHY data mux")
    L.append("    //------------------------------------------------------------")
    L.append("    pipe_lane_data_m2p #(")
    L.append("        .NL (NL)")
    L.append("    ) u_data_m2p (")
    if phy_input_mode:
        for gid, l, _n in seltgt_lanes:
            L.append(f"        .seltgt_g{gid}_l{l} (seltgt_g{gid}_l{l}),")
    else:
        L.append("        .sel_tgt      (sel_tgt),")
    L.append("        .phy_mac2phy  (phy_mac2phy),")
    if dpr:
        L.append("        .dpr_mac2phy  (dpr_mac2phy),")
    for cid in sorted(cfg.controllers):
        c = cfg.controllers[cid]
        L.append(f"        .{c.lname}_mac2phy ({c.lname}_mac2phy),")
    L[-1] = L[-1].rstrip(",")
    L.append("    );")
    L.append("")

    # ---- PHY->MAC data submodule
    L.append("    //------------------------------------------------------------")
    L.append("    // PHY->MAC data mux")
    L.append("    //------------------------------------------------------------")
    L.append("    pipe_lane_data_p2m #(")
    L.append("        .NL (NL)")
    L.append("    ) u_data_p2m (")
    if phy_input_mode:
        # data_p2m's own seltgt_gN_lL ports are at the same width as
        # everywhere else now (g.n, or g.n+1 with --dpr) -- it needs the top
        # (DPR) bit itself now, to gate dpr_phy2mac (see that module's
        # docstring), so this wires the same seltgt wire straight through
        # with no slicing, for every group seltgt_lanes covers (which
        # already includes previously-direct groups once --dpr widens them
        # into 2-candidate NOV groups).
        for gid, l, _n in seltgt_lanes:
            L.append(f"        .seltgt_g{gid}_l{l} (seltgt_g{gid}_l{l}),")
    else:
        L.append("        .sel_tgt      (sel_tgt),")
    L.append("        .phy_phy2mac  (phy_phy2mac),")
    if dpr:
        L.append("        .dpr_phy2mac  (dpr_phy2mac),")
    for cid in sorted(cfg.controllers):
        c = cfg.controllers[cid]
        L.append(f"        .{c.lname}_phy2mac ({c.lname}_phy2mac),")
    L[-1] = L[-1].rstrip(",")
    L.append("    );")
    L.append("")

    L.append("endmodule")
    return "\n".join(L) + "\n"


def gen_connection(cfg, pclk_mode="pclk_as_phy_output", dpr=False):
    """pipe_lane_mapper_connection.sv: a pure struct<->flat bridge around
    pipe_lane_mapper. The mapper's two packed-struct-array ports per side
    (PHY, and one per controller) become individual flat ports here, one
    per pipe_signals.csv row -- for integration with flows/IP that don't
    want SV struct ports.

    "perlane" signals (the default) stay an unpacked array of the
    controller's own max_width. "shared" ones collapse to a single scalar
    port per controller: a controller drives/observes one value across all
    of its own lanes (e.g. Rate/PowerDown in the real PIPE spec), so
    there's nothing to distinguish per-lane on that side.

    The PHY side is always per-lane regardless of signal_type: which
    controller owns a given PHY lane still varies by mode, so even a
    signal a controller treats as "shared" across its own lanes still
    needs its own value per PHY lane. The mapper core itself is completely
    unaware of any of this -- it still sees every signal as a plain
    per-lane struct field; "shared" is purely a wrapper-level convenience
    for whatever instantiates this file.
    """
    LC, NC = cfg.lane_count, cfg.num_ctrl
    nm = len(cfg.modes)
    phy_input_mode = pclk_mode == "pclk_as_phy_input"
    m2p_sigs = [s for s in cfg.signals if s.is_m2p]
    p2m_sigs = [s for s in cfg.signals if not s.is_m2p]

    L = ["// PIPE lane mapper connection wrapper."]
    L.append("//")
    L.append("// Pure struct<->flat bridge around pipe_lane_mapper: every pipe_signals.csv")
    L.append("// row becomes its own flat port here instead of a packed-struct field, for")
    L.append("// integration with flows/IP that don't want SV struct ports. signal_type=shared")
    L.append("// collapses a controller's own max_width lanes to one scalar port; perlane")
    L.append("// (the default) stays an unpacked array of max_width. The PHY side is always")
    L.append("// per-lane -- which controller owns a PHY lane still varies by mode, so even a")
    L.append("// \"shared\" signal still needs its own value per PHY lane there.")
    L.append("import pipe_lane_signal_pkg::*;")
    L.append("")
    L.append("module pipe_lane_mapper_connection #(")
    L.append(f"    parameter int NL = {LC},")
    L.append(f"    parameter int NC = {NC},")
    L.append("    parameter bit SEL_SYNC = 1'b1")
    L.append(") (")
    if phy_input_mode:
        L.append("    input logic test_en,")
        L.append(f"    input logic [{mode_width(nm)-1}:0] mode,")
        L.append("    input logic [NL-1:0] rx_clk,")
        L.append("    output logic [NL-1:0] phy_pclk,")
        L.append("    output logic [NL-1:0] phy_rst_n,")
    else:
        L.append("    input logic [NL-1:0] phy_pclk_out,")
        L.append("    input logic test_en,")
        L.append(f"    input logic [{mode_width(nm)-1}:0] mode,")
        L.append("    output logic [NL-1:0] phy_pclk_in,")
        L.append("    output logic [NL-1:0] phy_rst_n,")
    L.append("    // PHY-side PIPE data, flattened -- always per-lane regardless of signal_type")
    for s in m2p_sigs:
        L.append(f"    output logic [{s.width-1}:0] phy_{s.name} [0:NL-1],")
    for s in p2m_sigs:
        L.append(f"    input logic [{s.width-1}:0] phy_{s.name} [0:NL-1],")
    if dpr:
        L.append("    // DPR (diagnostic probe): a virtual controller with link width NL,")
        L.append("    // connected 1:1 to every PHY lane -- v_lane_mask[l]=1 overrides lane l.")
        L.append("    input logic [NL-1:0] v_lane_mask,")
        L.append("    input logic dpr_rst_n,")
        for s in m2p_sigs:
            if s.is_shared:
                L.append(f"    // {s.name}: shared across DPR's own lanes")
                L.append(f"    input logic [{s.width-1}:0] dpr_{s.name},")
            else:
                L.append(f"    input logic [{s.width-1}:0] dpr_{s.name} [0:NL-1],")
        for s in p2m_sigs:
            if s.is_shared:
                L.append(f"    // {s.name}: shared across DPR's own lanes")
                L.append(f"    output logic [{s.width-1}:0] dpr_{s.name},")
            else:
                L.append(f"    output logic [{s.width-1}:0] dpr_{s.name} [0:NL-1],")
        L.append("    output logic dpr_pclk,")
    L.append("    // Controller side. Each controller's ports are declared at its own real max_width.")
    for cid in sorted(cfg.controllers):
        c = cfg.controllers[cid]
        L.append(f"    // {c.name} x{c.max_width}")
        L.append(f"    input logic {c.lname}_rst_n,")
        for s in m2p_sigs:
            if s.is_shared:
                L.append(f"    // {s.name}: shared across {c.name}'s own lanes")
                L.append(f"    input logic [{s.width-1}:0] {c.lname}_{s.name},")
            else:
                L.append(f"    input logic [{s.width-1}:0] {c.lname}_{s.name} [0:{c.max_width-1}],")
        for s in p2m_sigs:
            if s.is_shared:
                L.append(f"    // {s.name}: shared across {c.name}'s own lanes")
                L.append(f"    output logic [{s.width-1}:0] {c.lname}_{s.name},")
            else:
                L.append(f"    output logic [{s.width-1}:0] {c.lname}_{s.name} [0:{c.max_width-1}],")
        if phy_input_mode:
            L.append(f"    input logic [{c.max_width-1}:0] {c.lname}_pclk,")
            L.append(f"    output logic [{c.max_width-1}:0] {c.lname}_rx_clk,")
        else:
            L.append(f"    output logic {c.lname}_pclk,")
    L[-1] = L[-1].rstrip(",")
    L.append(");")
    L.append("")

    # ---- internal struct-typed nets feeding the real DUT
    L.append("    mac2phy_lane_t [NL-1:0] w_phy_mac2phy;")
    L.append("    phy2mac_lane_t [NL-1:0] w_phy_phy2mac;")
    for cid in sorted(cfg.controllers):
        c = cfg.controllers[cid]
        L.append(f"    mac2phy_lane_t [{c.max_width-1}:0] w_{c.lname}_mac2phy;")
        L.append(f"    phy2mac_lane_t [{c.max_width-1}:0] w_{c.lname}_phy2mac;")
    if dpr:
        L.append("    mac2phy_lane_t [NL-1:0] w_dpr_mac2phy;")
        L.append("    phy2mac_lane_t [NL-1:0] w_dpr_phy2mac;")
    L.append("")

    # ---- PHY side: struct <-> flat
    L.append("    //------------------------------------------------------------")
    L.append("    // PHY side (always per-lane)")
    L.append("    //------------------------------------------------------------")
    for l in range(LC):
        for s in m2p_sigs:
            L.append(f"    assign phy_{s.name}[{l}] = w_phy_mac2phy[{l}].{s.name};")
    for l in range(LC):
        fields = ", ".join(f"{s.name}: phy_{s.name}[{l}]" for s in p2m_sigs)
        L.append(f"    assign w_phy_phy2mac[{l}] = '{{{fields}}};")
    L.append("")

    # ---- controller side: struct <-> flat, shared collapses to one scalar
    for cid in sorted(cfg.controllers):
        c = cfg.controllers[cid]
        L.append("    //------------------------------------------------------------")
        L.append(f"    // {c.name} (x{c.max_width})")
        L.append("    //------------------------------------------------------------")
        for l in range(c.max_width):
            fields = []
            for s in m2p_sigs:
                val = f"{c.lname}_{s.name}" if s.is_shared else f"{c.lname}_{s.name}[{l}]"
                fields.append(f"{s.name}: {val}")
            L.append(f"    assign w_{c.lname}_mac2phy[{l}] = '{{{', '.join(fields)}}};")
        for s in p2m_sigs:
            if s.is_shared:
                # A controller's own lanes are asserted (not checked here) to
                # agree on a shared signal's value -- lane 0 stands for all.
                L.append(f"    assign {c.lname}_{s.name} = w_{c.lname}_phy2mac[0].{s.name};")
            else:
                for l in range(c.max_width):
                    L.append(f"    assign {c.lname}_{s.name}[{l}] = w_{c.lname}_phy2mac[{l}].{s.name};")
        L.append("")

    if dpr:
        L.append("    //------------------------------------------------------------")
        L.append(f"    // DPR (x{LC}, one flat port per PHY lane, 1:1)")
        L.append("    //------------------------------------------------------------")
        for l in range(LC):
            fields = []
            for s in m2p_sigs:
                val = f"dpr_{s.name}" if s.is_shared else f"dpr_{s.name}[{l}]"
                fields.append(f"{s.name}: {val}")
            L.append(f"    assign w_dpr_mac2phy[{l}] = '{{{', '.join(fields)}}};")
        for s in p2m_sigs:
            if s.is_shared:
                L.append(f"    assign dpr_{s.name} = w_dpr_phy2mac[0].{s.name};")
            else:
                for l in range(LC):
                    L.append(f"    assign dpr_{s.name}[{l}] = w_dpr_phy2mac[{l}].{s.name};")
        L.append("")

    # ---- the real DUT
    L.append("    //------------------------------------------------------------")
    L.append("    // Real DUT")
    L.append("    //------------------------------------------------------------")
    L.append("    pipe_lane_mapper #(")
    L.append("        .NL (NL),")
    L.append("        .NC (NC),")
    L.append("        .SEL_SYNC (SEL_SYNC)")
    L.append("    ) u_pipe_lane_mapper (")
    if phy_input_mode:
        L.append("        .test_en      (test_en),")
        L.append("        .mode         (mode),")
        L.append("        .rx_clk       (rx_clk),")
        L.append("        .phy_pclk     (phy_pclk),")
        L.append("        .phy_rst_n    (phy_rst_n),")
    else:
        L.append("        .phy_pclk_out (phy_pclk_out),")
        L.append("        .test_en      (test_en),")
        L.append("        .mode         (mode),")
        L.append("        .phy_pclk_in  (phy_pclk_in),")
        L.append("        .phy_rst_n    (phy_rst_n),")
    L.append("        .phy_mac2phy  (w_phy_mac2phy),")
    L.append("        .phy_phy2mac  (w_phy_phy2mac),")
    if dpr:
        L.append("        .v_lane_mask  (v_lane_mask),")
        L.append("        .dpr_rst_n    (dpr_rst_n),")
        L.append("        .dpr_mac2phy  (w_dpr_mac2phy),")
        L.append("        .dpr_phy2mac  (w_dpr_phy2mac),")
        L.append("        .dpr_pclk     (dpr_pclk),")
    for cid in sorted(cfg.controllers):
        c = cfg.controllers[cid]
        L.append(f"        .{c.lname}_rst_n   ({c.lname}_rst_n),")
        L.append(f"        .{c.lname}_mac2phy (w_{c.lname}_mac2phy),")
        L.append(f"        .{c.lname}_phy2mac (w_{c.lname}_phy2mac),")
        if phy_input_mode:
            L.append(f"        .{c.lname}_pclk ({c.lname}_pclk),")
            L.append(f"        .{c.lname}_rx_clk ({c.lname}_rx_clk),")
        else:
            L.append(f"        .{c.lname}_pclk ({c.lname}_pclk),")
    L[-1] = L[-1].rstrip(",")
    L.append("    );")
    L.append("")
    L.append("endmodule")
    return "\n".join(L) + "\n"


# ---------------------------------------------------------------- filelist


def gen_filelist(cfg):
    """<set>/rtl/flist.f. Paths are resolved relative to flist.f's own directory.

    The common modules are copied from tool/backend/common/ into <set>/rtl/common/
    at generation time, so flist.f can reference the sibling common/
    directory directly -- each config set is fully self-contained and
    doesn't depend on tool/'s original location. The file set here doesn't
    depend on --dpr -- DPR's overlay lives inside pipe_lane_mapper.sv
    itself (see gen_dpr_overlay()), not a separate generated file.
    """
    common = [
        "pipe_lane_sync2.sv",
        "pipe_lane_sel_sync.sv",
        "pipe_lane_clk_gate.sv",
        "pipe_lane_clk_or.sv",
        "pipe_lane_data_mux.sv",
    ]
    gen = [
        "pipe_lane_signal_pkg.sv",
        "pipe_lane_mode_dec.sv",
        "pipe_lane_sel_gen.sv",
        "pipe_lane_clk_mux.sv",
        "pipe_lane_rst_mux.sv",
        "pipe_lane_data_m2p.sv",
        "pipe_lane_data_p2m.sv",
        "pipe_lane_mapper.sv",
        "pipe_lane_mapper_connection.sv",
    ]
    L = [
        "// RTL filelist. The package must come before the modules that use it.",
        "",
        "+incdir+common",
        "+incdir+src",
        "",
    ]
    for f in common:
        L.append(f"common/{f}")
    L.append("")
    for f in gen:
        L.append(f"src/{f}")
    return "\n".join(L) + "\n"
