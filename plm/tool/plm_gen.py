#!/usr/bin/env python3
"""
PIPE Lane Mapper RTL generator.

Only generates the config-dependent parts: type definitions, mode
decoding, and the instantiation/wiring of the common modules. NOV, the
synchronizer, clock gating, and the one-hot mux are all hand-written
modules under tool/common -- they don't change with the config.

Directory convention (the tool is kept separate from config instances, so
each config can be viewed/simulated independently):
    plm/
      tool/                where this file lives; only this dir is
                            hand-written and config-independent
        plm_gen.py
        plm_config.py
        common/            single source of truth for the common modules
      configs/             single entry point for every config set
        <set name>/
          config/          the three input CSVs
          rtl/             generated output: a common/ snapshot, src/, flist.f
          tb/               generated output: the testbench
"""

import argparse
import shutil
import subprocess
import sys
from pathlib import Path

SCRIPT_DIR = Path(__file__).resolve().parent  # .../plm/tool
PLM_ROOT = SCRIPT_DIR.parent  # .../plm
CONFIGS_ROOT = PLM_ROOT / "configs"  # .../plm/configs
BUILTIN_CFG = SCRIPT_DIR / "config"  # built-in default CSVs (if shipped alongside the tool)
COMMON_DIR = (
    SCRIPT_DIR / "common"
)  # hand-written common modules (config-independent, shipped with the tool)
TB_MAKEFILE = (
    SCRIPT_DIR / "tb_makefile.mk"
)  # hand-written VCS/Verdi Makefile (config-independent), copied to <set>/tb/Makefile
CSV_NAMES = ("controllers.csv", "lane_mapping.csv", "pipe_signals.csv")

sys.path.insert(0, str(SCRIPT_DIR))
from plm_config import load  # noqa: E402


def has_csvs(d):
    d = Path(d)
    return d.is_dir() and all((d / n).is_file() for n in CSV_NAMES)


def clog2(n):
    """Python equivalent of SystemVerilog's $clog2 -- the generator always
    knows the mode count at generation time, so the mode port's width can
    be computed once here and emitted as a literal, instead of carrying an
    NM parameter through every module just to recompute $clog2(NM) at
    elaboration time."""
    if n <= 1:
        return 0
    return (n - 1).bit_length()


def format_sv(text):
    """Best-effort auto-format via verible-verilog-format, if it's on PATH.

    The generator builds .sv content as hand-typed Python string literals,
    so their whitespace/alignment is only as consistent as whoever last
    edited that literal -- there's no single source of truth for spacing
    the way there is for the logic itself. Piping the final text through a
    real formatter fixes that at the one place all output funnels through,
    instead of hand-aligning every literal (impractical and easy to drift
    again on the next edit). This is cosmetic polish, not a functional
    requirement, so silently return the text unchanged if the tool isn't
    installed or fails for any reason.
    """
    exe = shutil.which("verible-verilog-format")
    if exe is None:
        return text
    try:
        # Pass/receive raw bytes rather than text=True: subprocess's text
        # mode runs stdin through the platform's default newline
        # translation, which silently turns every "\n" into "\r\n" on
        # Windows before verible ever sees it -- verible then trips its own
        # internal "formatted output doesn't match input" self-check on
        # those injected \r's and returns the input unformatted. Encoding
        # ourselves sends exactly the bytes we mean to send.
        r = subprocess.run([exe, "-"], input=text.encode("utf-8"), capture_output=True, timeout=10)
        if r.returncode == 0 and r.stdout:
            return r.stdout.decode("utf-8")
    except (OSError, subprocess.SubprocessError):
        pass
    return text


def list_configs():
    """List every subdirectory of configs/ that looks like a config set, for
    use in error messages."""
    if not CONFIGS_ROOT.is_dir():
        return []
    return sorted(p.name for p in CONFIGS_ROOT.iterdir() if p.is_dir() and has_csvs(p / "config"))


def resolve_set(arg):
    """Resolve the --config argument into (csv_dir, out_rtl).

    Convention: a config set is a directory; its generated output always
    goes to <set>/rtl/ (the testbench goes to <set>/tb/, derived by main()
    as out_rtl.parent / "tb"); CSVs are looked up in <set>/config/ first,
    then <set>/ itself.

    The --config value is first tried as a set name under configs/:
      --config demo               -> configs/demo/config/, output to configs/demo/rtl/
      --config config_multi_modes -> configs/config_multi_modes/config/
    If not found there, it's tried as a path given directly (absolute or
    relative, so directories outside configs/ also work):
      --config ../other/my_set    -> my_set/config/ (or my_set/ itself)
      --config config-1/config    -> same as above; passing the config
                                      subdirectory is attributed to its
                                      parent set
    With no --config, there's no default guess -- with multiple configs
    coexisting, guessing wrong is more trouble than just erroring out, so
    it lists the available set names under configs/ instead.
    """
    if arg is None:
        avail = list_configs()
        raise SystemExit(
            "A config set must be given via --config."
            + (
                f" Available: {', '.join(avail)}"
                if avail
                else f" There are no config sets under {CONFIGS_ROOT} yet."
            )
        )

    named = CONFIGS_ROOT / arg
    if has_csvs(named / "config"):
        return named / "config", named / "rtl"

    set_dir = Path(arg).resolve()
    if has_csvs(set_dir / "config"):
        return set_dir / "config", set_dir / "rtl"
    if has_csvs(set_dir):
        # What was passed in is some set's config subdirectory (e.g.
        # config-1/config): attribute it to the parent set, output still
        # goes to config-1/rtl
        if set_dir.name == "config" and set_dir.parent != SCRIPT_DIR:
            return set_dir, set_dir.parent / "rtl"
        return set_dir, set_dir / "rtl"
    if has_csvs(BUILTIN_CFG):
        return BUILTIN_CFG, set_dir / "rtl"

    avail = list_configs()
    raise SystemExit(
        f"Config set '{arg}' not found: no CSVs "
        f"({', '.join(CSV_NAMES)}) under any of "
        f"{named}/config, {set_dir}/config, {set_dir}."
        + (f" Available sets under {CONFIGS_ROOT}: {', '.join(avail)}" if avail else "")
    )


# ---------------------------------------------------------------- type package


def gen_pkg(cfg):
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
        L.append(f"    // Value to present when there's no owner (the NOV handoff window).")
        L.append(
            f"    // pipe_lane_data_mux uses this for polarity normalization, so sel==0 naturally lands on the safe state."
        )
        L.append(f"    localparam {tname} {cname} = '{{")
        for i, s in enumerate(sigs):
            tail = "," if i != len(sigs) - 1 else ""
            L.append(f"        {s.name}: {s.sv_literal(s.safe_state)}{tail}")
        L.append("    };")
        L.append("")

    # each group's sel type
    L.append("    // One one-hot select vector per lane group that needs NOV.")
    L.append(
        "    // Direct groups don't appear here -- the type itself shows they have no choice to make."
    )
    for g in cfg.groups:
        if g.is_direct:
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
        if not g.is_direct:
            L.append(f"        logic [{g.n-1}:0] g{g.gid};")
            any_mux = True
    if not any_mux:
        L.append("        logic dummy;   // this topology is all direct connections")
    L.append("    } lane_sel_t;")
    L.append("")
    L.append("endpackage")
    return "\n".join(L) + "\n"


# ---------------------------------------------------------------- decoder


def gen_decoder(cfg):
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
        f"    input  logic [{clog2(nm)-1}:0] mode,",
    ]
    # Output port list: sel_tgt is always present, pclk_tgt appended as
    # needed. The comma has to be inserted before the comment -- just
    # appending "," to the end of the whole line would put the comma inside
    # the "// ..." comment, leaving the actual code still missing it. So the
    # "code" and "comment" parts are assembled separately here, with the
    # comma attached to the end of the code and the comment appended after.
    ports = [("    output lane_sel_t sel_tgt", "")]
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
                    f"                // pclk_tgt stays 0; the downstream hold logic keeps the previous selection"
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


def gen_sel_gen(cfg, sel_mode="sync"):
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
                 feedback clock mux and data_m2p/data_p2m.
      dec_tgt -- the decoder's raw (unsynchronized) target, purely
                 combinational and changes immediately with mode; used by
                 rst_mux, so the new owner's reset control can follow mode
                 right away without waiting for pipe_lane_sel_sync to finish
                 cross-domain synchronization and the NOV break window.

    The controller-side pclk candidates (pclk_tgt_cX) are also produced by
    the internal decoder, but that signal is meant for
    pipe_lane_clk_mux's glitch-free controller pclk switching -- this
    module doesn't consume it itself, just passes it through.

    Each group's owner selection goes through the pipe_lane_sel_sync module
    (tool/common/pipe_lane_sel_sync.sv), whose SYNC parameter switches between two
    implementations:
      sel_mode="sync" (default) -- SYNC=1'b1, non-overlap + a
                two-stage synchronizer, safe across clock domains.
      sel_mode="comb"           -- SYNC=1'b0, en is directly tgt, pure
                combinational passthrough. Only safe when every candidate
                controller genuinely shares the same clock domain and mode
                itself is already glitch-free within that domain;
                otherwise multiple branches could briefly be 1 at once,
                and pipe_lane_data_mux would OR the two data paths together.

    This module needs ctrl_pclk as an input (pipe_lane_sel_sync's branch_clk per
    group), and ctrl_pclk is pipe_lane_clk_mux's output -- so the two
    submodules form a ring connection at the top level, but there's no
    combinational loop: ctrl_pclk only depends on the decoder's
    pclk_tgt_cX (passed through by this module), which has nothing to do
    with the sel_tgt this module produces; and sel_tgt's dependency on
    ctrl_pclk goes entirely through flops inside pipe_lane_sel_sync, so there's no
    combinational feedback.
    """
    nm = len(cfg.modes)
    NC = cfg.num_ctrl
    cc = cfg.ctrl_pclk_cands()
    muxed_c = [c for c in sorted(cfg.controllers) if len(cc[c]) > 1]
    sync_lit = "1'b1" if sel_mode == "sync" else "1'b0"

    L = [
        "// PIPE lane mapper select-generation submodule.",
        "// Decodes mode into each group's raw target dec_tgt (combinational, for rst_mux),",
        "// then uses pipe_lane_sel_sync for non-overlap + cross-clock-domain synchronization to",
        "// produce the final effective sel_tgt (for clk_mux's feedback clock mux and the data muxes).",
        "// pclk_tgt_cX is produced by the internal decoder and passed through to pipe_lane_clk_mux",
        "// for glitch-free switching of controller pclk candidates.",
        f"// Group pipe_lane_sel_sync mode: {sel_mode}"
        + (
            " (SYNC=1, safe across clock domains)"
            if sel_mode == "sync"
            else " (SYNC=0, combinational passthrough, requires candidate controllers to share one clock domain)"
        ),
        "import pipe_lane_signal_pkg::*;",
        "",
        "module pipe_lane_sel_gen #(",
        f"    parameter int NC = {NC}",
        ") (",
        f"    input  logic [{clog2(nm)-1}:0] mode,",
        "    input  logic [NC-1:0]   ctrl_pclk,",
        "    input  logic [NC-1:0]   ctrl_rst_n,",
        "",
    ]
    # Same as gen_decoder: code and comment are assembled separately, comma
    # goes at the end of the code, before the comment.
    ports = [
        (
            "    output lane_sel_t sel_tgt",
            "   // final effective selection after pipe_lane_sel_sync synchronization; used by clk_mux/data mux",
        ),
        (
            "    output lane_sel_t dec_tgt",
            "   // decoder's raw (unsynchronized) target; used by rst_mux",
        ),
    ]
    for c in muxed_c:
        ports.append(
            (
                f"    output logic [{len(cc[c])-1}:0] pclk_tgt_c{c}",
                f"   // pclk candidate for {cfg.controllers[c].name}, passed through to clk_mux",
            )
        )
    for i, (code, comment) in enumerate(ports):
        tail = "," if i != len(ports) - 1 else ""
        L.append(code + tail + comment)
    L.append(");")
    L.append("")

    # decoder instance
    L.append("    pipe_lane_mode_dec #(")
    L.append("        .NC (NC)")
    L.append("    ) u_mode_dec (")
    L.append("        .mode     (mode),")
    L.append("        .sel_tgt  (dec_tgt)" + ("," if muxed_c else ""))
    for i, c in enumerate(muxed_c):
        tail = "," if i != len(muxed_c) - 1 else ""
        L.append(f"        .pclk_tgt_c{c} (pclk_tgt_c{c}){tail}")
    L.append("    );")
    L.append("")

    L.append("    //------------------------------------------------------------")
    L.append(f"    // One pipe_lane_sel_sync per non-direct group (SYNC={sync_lit}).")
    L.append("    //------------------------------------------------------------")
    for g in cfg.groups:
        if g.is_direct:
            continue
        names = ", ".join(cfg.controllers[c].name for c in g.cands)
        L.append(f"    // G{g.gid} lane{g.lanes[0]}~{g.lanes[-1]}: {names}")
        L.append(f"    pipe_lane_sel_sync #(.N({g.n}), .SYNC({sync_lit})) u_sel_sync_g{g.gid} (")
        L.append(
            f"        .branch_clk   ({{"
            + ", ".join(f"ctrl_pclk[{c}]" for c in reversed(g.cands))
            + "}),"
        )
        L.append(
            f"        .branch_rst_n ({{"
            + ", ".join(f"ctrl_rst_n[{c}]" for c in reversed(g.cands))
            + "}),"
        )
        L.append(f"        .tgt          (dec_tgt.g{g.gid}),")
        L.append(f"        .en           (sel_tgt.g{g.gid})")
        L.append(f"    );")
        L.append("")

    L.append("endmodule")
    return "\n".join(L) + "\n"


# ---------------------------------------------------------------- clock-mux submodule


def gen_clk_mux(cfg, pclk_mode="phy-output"):
    """Controller pclk generation + feedback clock mux.

    Two mutually exclusive clock architectures, selected by pclk_mode:

    "phy-output" (default): each PHY lane generates its own PCLK
    (phy_pclk_out); this module derives ctrl_pclk from it and echoes the
    result back as phy_pclk_in. See gen_clk_mux_phy_output() below.

    "phy-input-max-pclk": each controller has its own external PLL clock
    (max_pclk) and does its own division into a per-port pclk[] that this
    module glitch-free-selects into phy_pclk_in; PHY's per-lane recovered
    rx_clk is routed the other way into each controller's own rx_clk[],
    with no glitch-free treatment. See gen_clk_mux_max_pclk() below.
    """
    if pclk_mode == "phy-input-max-pclk":
        return gen_clk_mux_max_pclk(cfg)
    return gen_clk_mux_phy_output(cfg)


def gen_clk_mux_phy_output(cfg):
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
        f"module pipe_lane_clk_mux #(",
        f"    parameter int NL = {LC},",
        f"    parameter int NC = {NC}",
        ") (",
        "    input  logic [NL-1:0] phy_pclk_out,",
        "    input  logic                  test_en,",
        "    input  logic [NC-1:0]   ctrl_rst_n,",
        "",
    ]
    for c in muxed_c:
        L.append(
            f"    input  logic [{len(cc[c])-1}:0] pclk_tgt_c{c},"
            f"   // pclk candidate target for {cfg.controllers[c].name}, from sel_gen"
        )
    L.append(
        "    input  lane_sel_t              sel_tgt,   // each group's currently effective owner selection"
    )
    L.append("")
    L.append("    output logic [NC-1:0]   ctrl_pclk,")
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
            L.append(f"    logic [{n-1}:0] pclk_tgt_hold_c{cid};")
            L.append(f"    logic [{n-1}:0] pen_c{cid};")
            L.append(f"    logic [{n-1}:0] pgated_c{cid};")
            L.append(
                f"    always_ff @(posedge phy_pclk_out[{cand[0]}] " f"or negedge ctrl_rst_n[{cid}])"
            )
            L.append(f"        if (!ctrl_rst_n[{cid}]) pclk_tgt_hold_c{cid} <= " f"{n}'b{1:0{n}b};")
            L.append(
                f"        else if (|pclk_tgt_c{cid}) pclk_tgt_hold_c{cid} <= " f"pclk_tgt_c{cid};"
            )
            L.append(f"    pipe_lane_sel_sync #(.N({n}), .SYNC(1'b1)) u_pclk_sel_sync_c{cid} (")
            L.append(
                f"        .branch_clk   ({{"
                + ", ".join(f"phy_pclk_out[{v}]" for v in reversed(cand))
                + "}),"
            )
            L.append(f"        .branch_rst_n ({{{n}{{ctrl_rst_n[{cid}]}}}}),")
            L.append(f"        .tgt          (pclk_tgt_hold_c{cid}),")
            L.append(f"        .en           (pen_c{cid})")
            L.append(f"    );")
            for i, v in enumerate(cand):
                L.append(
                    f"    pipe_lane_clk_gate u_pclk_gate_c{cid}_b{i} ("
                    f".clk_in(phy_pclk_out[{v}]), .en(pen_c{cid}[{i}]), "
                    f".test_en(test_en), .clk_out(pgated_c{cid}[{i}]));"
                )
            L.append(f"    assign ctrl_pclk[{cid}] = |pgated_c{cid};")
        L.append("")

    # feedback clock
    L.append("    //------------------------------------------------------------")
    L.append(
        "    // Feedback clock: each lane's pclk_in connects to its current owner's ctrl_pclk."
    )
    L.append(
        "    // Shares the same en group as the data path, so data and clock switch in lockstep."
    )
    L.append("    //------------------------------------------------------------")
    for g in cfg.groups:
        if g.is_direct:
            c = g.cands[0]
            for l in g.lanes:
                L.append(
                    f"    assign phy_pclk_in[{l}] = ctrl_pclk[{c}];"
                    f"  // G{g.gid} direct to {cfg.controllers[c].name}"
                )
        else:
            names = ", ".join(cfg.controllers[c].name for c in g.cands)
            L.append(f"    // G{g.gid} lane{g.lanes[0]}~{g.lanes[-1]}: {names}")
            L.append(f"    logic [{g.n-1}:0] pin_gated_g{g.gid};")
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
            L.append(f"    assign pclk_in_g{g.gid} = |pin_gated_g{g.gid};")
            for l in g.lanes:
                L.append(f"    assign phy_pclk_in[{l}] = pclk_in_g{g.gid};")
    L.append("")
    L.append("endmodule")
    return "\n".join(L) + "\n"


def gen_clk_mux_max_pclk(cfg):
    """Controller pclk generation + feedback clock mux ("PCLK as PHY input, max_pclk").

    Each controller owns an external PLL clock (max_pclk) and does its own
    division outside this generator's scope, presenting the divided result
    as its own pclk[] (one bit per its own port, same width/routing
    convention as {c.lname}_mac2phy). ctrl_pclk is therefore just max_pclk
    passed straight through -- there's no lane-derived candidate to switch
    between, unlike the phy-output scheme.

    phy_pclk_in still needs glitch-free switching for NOV groups, but
    per PHYSICAL LANE rather than per group: different lanes in the same
    group can pull from different port bits of the same candidate
    controller, so each lane gets its own pipe_lane_sel_sync instance keyed
    to that lane's own candidate port clocks (using the group's shared
    dec_tgt as the switch target -- that part is pure combinational/mode
    logic, safe to share).

    rx_clk (PHY's per-lane recovered clock) is routed the other direction
    into each controller port's own rx_clk bit. This is a plain per-mode
    selection with no glitch-free treatment (unlike pclk/phy_pclk_in) --
    see docs/design_notes.md.
    """
    LC, NC = cfg.lane_count, cfg.num_ctrl

    L = [
        "// PIPE lane mapper clock-mux submodule (PCLK as PHY input, max_pclk scheme).",
        "// Contains: ctrl_pclk passthrough, glitch-free phy_pclk_in switch, plain rx_clk routing.",
        "// The reset mux is in pipe_lane_rst_mux, the data muxes are in",
        "// pipe_lane_data_m2p / pipe_lane_data_p2m.",
        "import pipe_lane_signal_pkg::*;",
        "",
        f"module pipe_lane_clk_mux #(",
        f"    parameter int NL = {LC},",
        f"    parameter int NC = {NC}",
        ") (",
        "    input  logic [NC-1:0]   max_pclk,   // one external PLL clock per controller",
        "    input  logic             test_en,",
        "    input  logic [NC-1:0]   ctrl_rst_n,",
        "    input  lane_sel_t        dec_tgt,    // raw per-group decode target, for the per-lane pclk sync trees",
        "    input  lane_sel_t        sel_tgt,    // each group's currently effective owner selection, for rx_clk routing",
        "    input  logic [NL-1:0]   rx_clk,     // PHY's per-lane recovered clock",
    ]
    for cid in sorted(cfg.controllers):
        c = cfg.controllers[cid]
        L.append(
            f"    input  logic [{c.max_width-1}:0] {c.lname}_pclk,"
            f"   // {c.name}'s own already-divided pclk, one bit per its own port"
        )
    L.append("")
    L.append("    output logic [NC-1:0]   ctrl_pclk,")
    L.append("    output logic [NL-1:0]   phy_pclk_in,")
    for cid in sorted(cfg.controllers):
        c = cfg.controllers[cid]
        L.append(f"    output logic [{c.max_width-1}:0] {c.lname}_rx_clk,")
    L[-1] = L[-1].rstrip(",")
    L.append(");")
    L.append("")

    # ctrl_pclk: trivial passthrough, no candidate switching needed
    L.append("    //------------------------------------------------------------")
    L.append("    // ctrl_pclk: each controller's own PLL clock, passed straight through --")
    L.append("    // there's no lane-derived candidate to select between here.")
    L.append("    //------------------------------------------------------------")
    L.append("    assign ctrl_pclk = max_pclk;")
    L.append("")

    # phy_pclk_in: glitch-free, per physical lane (not per group)
    L.append("    //------------------------------------------------------------")
    L.append("    // phy_pclk_in: glitch-free per-lane select among the owning group's")
    L.append("    // candidate controllers' own port-level pclk.")
    L.append("    //------------------------------------------------------------")
    for g in cfg.groups:
        if g.is_direct:
            c = g.cands[0]
            cname = cfg.controllers[c].lname
            m0 = cfg.modes[0]
            for l in g.lanes:
                cl = cfg.mapping[m0][l][1]
                L.append(
                    f"    assign phy_pclk_in[{l}] = {cname}_pclk[{cl}];"
                    f"  // G{g.gid} direct to {cfg.controllers[c].name}"
                )
            L.append("")
        else:
            names = ", ".join(cfg.controllers[c].name for c in g.cands)
            L.append(f"    // G{g.gid} lane{g.lanes[0]}~{g.lanes[-1]}: {names}, per-lane glitch-free select")
            n = g.n
            for l in g.lanes:
                port_of_cand = {}
                for c in g.cands:
                    m = next(mm for mm in cfg.modes if g.owners[mm] == c)
                    port_of_cand[c] = cfg.mapping[m][l][1]
                L.append(f"    logic [{n-1}:0] pclk_en_g{g.gid}_l{l};")
                L.append(f"    logic [{n-1}:0] pclk_gated_g{g.gid}_l{l};")
                L.append(f"    pipe_lane_sel_sync #(.N({n}), .SYNC(1'b1)) u_pclk_sel_sync_g{g.gid}_l{l} (")
                L.append(
                    f"        .branch_clk   ({{"
                    + ", ".join(
                        f"{cfg.controllers[c].lname}_pclk[{port_of_cand[c]}]" for c in reversed(g.cands)
                    )
                    + "}),"
                )
                L.append(
                    f"        .branch_rst_n ({{"
                    + ", ".join(f"ctrl_rst_n[{c}]" for c in reversed(g.cands))
                    + "}),"
                )
                L.append(f"        .tgt          (dec_tgt.g{g.gid}),")
                L.append(f"        .en           (pclk_en_g{g.gid}_l{l})")
                L.append(f"    );")
                for i, c in enumerate(g.cands):
                    L.append(
                        f"    pipe_lane_clk_gate u_pclk_gate_g{g.gid}_l{l}_b{i} ("
                        f".clk_in({cfg.controllers[c].lname}_pclk[{port_of_cand[c]}]), "
                        f".en(pclk_en_g{g.gid}_l{l}[{i}]), "
                        f".test_en(test_en), .clk_out(pclk_gated_g{g.gid}_l{l}[{i}]));"
                    )
                L.append(f"    assign phy_pclk_in[{l}] = |pclk_gated_g{g.gid}_l{l};")
            L.append("")

    # rx_clk: plain per-controller-port selection, no glitch-free treatment
    L.append("    //------------------------------------------------------------")
    L.append("    // rx_clk: plain per-mode selection into each controller port's rx_clk bit --")
    L.append("    // no glitch-free treatment needed (see docs/design_notes.md).")
    L.append("    //------------------------------------------------------------")
    port_src = {}
    for m in cfg.modes:
        for l in range(LC):
            cid, cl = cfg.mapping[m][l]
            g = cfg.group_of_lane(l)
            b = 0 if g.is_direct else g.branch_of(cid)
            port_src.setdefault((cid, cl), set()).add((l, g.gid, b))
    for cid in sorted(cfg.controllers):
        c = cfg.controllers[cid]
        for cl in range(c.max_width):
            srcs = sorted(port_src.get((cid, cl), set()))
            if not srcs:
                L.append(f"    assign {c.lname}_rx_clk[{cl}] = 1'b0;  // never driven in any mode")
                continue
            if len(srcs) == 1 and cfg.groups[srcs[0][1]].is_direct:
                l = srcs[0][0]
                L.append(
                    f"    assign {c.lname}_rx_clk[{cl}] = rx_clk[{l}];  // direct connection to lane{l}"
                )
                continue
            gid = srcs[0][1]
            g = cfg.groups[gid]
            terms = []
            for i in range(g.n):
                hit = [s for s in srcs if s[2] == i]
                if hit:
                    terms.append(f"(rx_clk[{hit[0][0]}] & sel_tgt.g{gid}[{i}])")
            L.append(f"    assign {c.lname}_rx_clk[{cl}] = " + " | ".join(terms) + ";")
    L.append("")
    L.append("endmodule")
    return "\n".join(L) + "\n"


# ---------------------------------------------------------------- reset-mux submodule


def gen_rst_mux(cfg):
    """Each lane's phy_rst_n connects to its current owner's ctrl_rst_n.

    The input port is still called sel_tgt, but at the top level it's
    actually wired to pipe_lane_sel_gen's dec_tgt (the decoder's raw,
    unsynchronized target), not sel_gen's final external sel_tgt. This
    lets the new owner's reset control change immediately with mode,
    without waiting for pipe_lane_sel_sync to finish cross-clock-domain
    synchronization and the non-overlap window.
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
        f"module pipe_lane_rst_mux #(",
        f"    parameter int NL = {LC},",
        f"    parameter int NC = {NC}",
        ") (",
        "    input  logic [NC-1:0]   ctrl_rst_n,",
        "    input  lane_sel_t              sel_tgt,",
        "    output logic [NL-1:0] phy_rst_n",
        ");",
        "",
    ]

    for g in cfg.groups:
        if g.is_direct:
            c = g.cands[0]
            for l in g.lanes:
                L.append(
                    f"    assign phy_rst_n[{l}] = ctrl_rst_n[{c}];"
                    f"  // G{g.gid} direct to {cfg.controllers[c].name}"
                )
        else:
            names = ", ".join(cfg.controllers[c].name for c in g.cands)
            L.append(f"    // G{g.gid} lane{g.lanes[0]}~{g.lanes[-1]}: {names}")
            L.append(f"    logic rst_n_g{g.gid};")
            L.append(f"    pipe_lane_data_mux #(.WIDTH(1), .N({g.n})) u_rst_g{g.gid} (")
            L.append(f"        .sel  (sel_tgt.g{g.gid}),")
            L.append(
                f"        .din  ({{"
                + ", ".join(f"ctrl_rst_n[{c}]" for c in reversed(g.cands))
                + "}),"
            )
            L.append(f"        .safe (1'b0),")
            L.append(f"        .dout (rst_n_g{g.gid})")
            L.append(f"    );")
            for l in g.lanes:
                L.append(f"    assign phy_rst_n[{l}] = rst_n_g{g.gid};")
    L.append("")
    L.append("endmodule")
    return "\n".join(L) + "\n"


# ---------------------------------------------------------------- MAC->PHY data


def gen_data_m2p(cfg):
    """mac2phy-direction data mux."""
    LC = cfg.lane_count
    L = [
        "// PIPE lane mapper MAC->PHY data mux.",
        "// pipe_lane_data_mux performs polarity normalization internally; output is SAFE_M2P when sel is all-zero.",
        "import pipe_lane_signal_pkg::*;",
        "",
        f"module pipe_lane_data_m2p #(",
        f"    parameter int NL = {LC}",
        ") (",
        "    input  lane_sel_t              sel_tgt,",
        "    output mac2phy_lane_t [NL-1:0] phy_mac2phy,",
    ]
    for cid in sorted(cfg.controllers):
        c = cfg.controllers[cid]
        L.append(f"    input  mac2phy_lane_t [{c.max_width-1}:0] {c.lname}_mac2phy,")
    L[-1] = L[-1].rstrip(",")
    L.append(");")
    L.append("")

    for g in cfg.groups:
        for l in g.lanes:
            if g.is_direct:
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
                L.append(
                    f"    pipe_lane_data_mux #(.WIDTH(MAC2PHY_W), " f".N({g.n})) u_m2p_l{l} ("
                )
                L.append(f"        .sel  (sel_tgt.g{g.gid}),")
                L.append(f"        .din  ({{" + ", ".join(reversed(srcs)) + "}),")
                L.append(f"        .safe (SAFE_M2P),")
                L.append(f"        .dout (phy_mac2phy[{l}])")
                L.append(f"    );")
    L.append("")
    L.append("endmodule")
    return "\n".join(L) + "\n"


# ---------------------------------------------------------------- PHY->MAC data


def gen_data_p2m(cfg):
    """phy2mac-direction data mux (converges by controller port)."""
    LC = cfg.lane_count
    L = [
        "// PIPE lane mapper PHY->MAC data mux (converges by controller port).",
        "// sel_tgt's mutual exclusivity is guaranteed by pipe_lane_sel_sync. Undriven ports are tied to the safe state.",
        "import pipe_lane_signal_pkg::*;",
        "",
        f"module pipe_lane_data_p2m #(",
        f"    parameter int NL = {LC}",
        ") (",
        "    input  lane_sel_t              sel_tgt,",
        "    input  phy2mac_lane_t [NL-1:0] phy_phy2mac,",
    ]
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
        L.append(f"    }};")
        L.append("")

        for cl in range(c.max_width):
            srcs = sorted(port_src.get((cid, cl), set()))
            if not srcs:
                L.append(
                    f"    assign {c.lname}_phy2mac[{cl}] = {c.lname}_p2m_tie;"
                    f"  // never driven in any mode"
                )
                continue
            if len(srcs) == 1 and cfg.groups[srcs[0][1]].is_direct:
                l = srcs[0][0]
                L.append(
                    f"    assign {c.lname}_phy2mac[{cl}] = phy_phy2mac[{l}];"
                    f"  // direct connection to lane{l}"
                )
                continue
            gid = srcs[0][1]
            g = cfg.groups[gid]
            din = []
            for i in range(g.n):
                hit = [s for s in srcs if s[2] == i]
                if hit:
                    din.append(f"phy_phy2mac[{hit[0][0]}]")
                else:
                    din.append(f"{c.lname}_p2m_tie")
            L.append(
                f"    pipe_lane_data_mux #(.WIDTH(PHY2MAC_W), "
                f".N({g.n})) u_p2m_{c.lname}_{cl} ("
            )
            L.append(f"        .sel  (sel_tgt.g{gid}),")
            L.append(f"        .din  ({{" + ", ".join(reversed(din)) + "}),")
            L.append(f"        .safe ({c.lname}_p2m_tie),")
            L.append(f"        .dout ({c.lname}_phy2mac[{cl}])")
            L.append(f"    );")
        L.append("")

    L.append("endmodule")
    return "\n".join(L) + "\n"


# ---------------------------------------------------------------- top level


def gen_top(cfg, pclk_mode="phy-output"):
    nm = len(cfg.modes)
    LC, NC = cfg.lane_count, cfg.num_ctrl
    max_pclk_mode = pclk_mode == "phy-input-max-pclk"

    L = ["// PIPE lane mapper top level."]
    L.append("//")
    L.append("// Pure instantiation layer:")
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
    L.append("module pipe_lane_mapper_top #(")
    L.append(f"    parameter int NL = {LC},")
    L.append(f"    parameter int NC = {NC}")
    L.append(") (")
    if max_pclk_mode:
        L.append("    input  logic [NC-1:0]   max_pclk,   // one external PLL clock per controller")
        L.append("    input  logic             test_en,")
        L.append(
            "    input  logic [NC-1:0]   ctrl_rst_n,   // one per controller, already synchronized externally"
        )
        L.append(f"    input  logic [{clog2(nm)-1}:0] mode,")
        L.append("    input  logic [NL-1:0]   rx_clk,     // PHY's per-lane recovered clock")
        L.append("")
        L.append("    output logic [NC-1:0]   ctrl_pclk,")
        L.append("    output logic [NL-1:0]   phy_pclk_in,")
        L.append("    output logic [NL-1:0]   phy_rst_n,")
    else:
        L.append("    input  logic [NL-1:0] phy_pclk_out,")
        L.append("    input  logic                  test_en,")
        L.append(
            "    input  logic [NC-1:0]   ctrl_rst_n,   // one per controller, already synchronized externally"
        )
        L.append(f"    input  logic [{clog2(nm)-1}:0] mode,")
        L.append("")
        L.append("    output logic [NC-1:0]   ctrl_pclk,")
        L.append("    output logic [NL-1:0] phy_pclk_in,")
        L.append("    output logic [NL-1:0] phy_rst_n,")
    L.append("")
    L.append("    // PHY-side PIPE data")
    L.append("    output mac2phy_lane_t [NL-1:0] phy_mac2phy,")
    L.append("    input  phy2mac_lane_t [NL-1:0] phy_phy2mac,")
    L.append("")
    L.append(f"    // Controller side. Each controller's ports are declared at its own real max_width.")
    for cid in sorted(cfg.controllers):
        c = cfg.controllers[cid]
        L.append(f"    // {c.name} x{c.max_width}")
        L.append(f"    input  mac2phy_lane_t [{c.max_width-1}:0] {c.lname}_mac2phy,")
        L.append(f"    output phy2mac_lane_t [{c.max_width-1}:0] {c.lname}_phy2mac,")
        if max_pclk_mode:
            L.append(f"    input  logic [{c.max_width-1}:0] {c.lname}_pclk,")
            L.append(f"    output logic [{c.max_width-1}:0] {c.lname}_rx_clk,")
    L[-1] = L[-1].rstrip(",")
    L.append(");")
    L.append("")

    cc = cfg.ctrl_pclk_cands()
    muxed_c = [c for c in sorted(cfg.controllers) if len(cc[c]) > 1]

    # ---- internal wiring
    L.append(
        "    lane_sel_t sel_tgt;   // each group's currently effective owner selection (after pipe_lane_sel_sync)"
    )
    L.append(
        "    lane_sel_t dec_tgt;   // each group's raw decoder selection (unsynchronized), used by rst_mux"
    )
    for c in muxed_c:
        L.append(
            f"    logic [{len(cc[c])-1}:0] pclk_tgt_c{c};"
            f"   // pclk candidate target for {cfg.controllers[c].name}"
        )
    L.append("")

    # ---- select-generation submodule
    L.append("    //------------------------------------------------------------")
    L.append(
        "    // Select-generation submodule: mode decoding + group pipe_lane_sel_sync, produces sel_tgt / dec_tgt"
    )
    L.append("    //------------------------------------------------------------")
    L.append("    pipe_lane_sel_gen #(")
    L.append("        .NC (NC)")
    L.append("    ) u_sel_gen (")
    L.append("        .mode       (mode),")
    L.append("        .ctrl_pclk  (ctrl_pclk),")
    L.append("        .ctrl_rst_n (ctrl_rst_n),")
    L.append("        .sel_tgt    (sel_tgt),")
    L.append("        .dec_tgt    (dec_tgt)" + ("," if muxed_c else ""))
    for i, c in enumerate(muxed_c):
        tail = "," if i != len(muxed_c) - 1 else ""
        L.append(f"        .pclk_tgt_c{c} (pclk_tgt_c{c}){tail}")
    L.append("    );")
    L.append("")

    # ---- clock-mux submodule
    L.append("    //------------------------------------------------------------")
    L.append("    // Clock-mux submodule: ctrl_pclk generation + feedback clock mux")
    L.append("    //------------------------------------------------------------")
    L.append("    pipe_lane_clk_mux #(")
    L.append("        .NL (NL),")
    L.append("        .NC   (NC)")
    L.append("    ) u_clk_mux (")
    if max_pclk_mode:
        L.append("        .max_pclk     (max_pclk),")
        L.append("        .test_en      (test_en),")
        L.append("        .ctrl_rst_n   (ctrl_rst_n),")
        L.append("        .dec_tgt      (dec_tgt),")
        L.append("        .sel_tgt      (sel_tgt),")
        L.append("        .rx_clk       (rx_clk),")
        for cid in sorted(cfg.controllers):
            c = cfg.controllers[cid]
            L.append(f"        .{c.lname}_pclk ({c.lname}_pclk),")
        L.append("        .ctrl_pclk    (ctrl_pclk),")
        L.append("        .phy_pclk_in  (phy_pclk_in),")
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
        L.append("        .ctrl_pclk    (ctrl_pclk),")
        L.append("        .phy_pclk_in  (phy_pclk_in)")
    L.append("    );")
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
    L.append("        .sel_tgt      (sel_tgt),")
    L.append("        .phy_mac2phy  (phy_mac2phy),")
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
    L.append("        .sel_tgt      (sel_tgt),")
    L.append("        .phy_phy2mac  (phy_phy2mac),")
    for cid in sorted(cfg.controllers):
        c = cfg.controllers[cid]
        L.append(f"        .{c.lname}_phy2mac ({c.lname}_phy2mac),")
    L[-1] = L[-1].rstrip(",")
    L.append("    );")
    L.append("")

    L.append("endmodule")
    return "\n".join(L) + "\n"


# ---------------------------------------------------------------- filelist


def gen_filelist(cfg):
    """<set>/rtl/flist.f. Paths are resolved relative to flist.f's own directory.

    The common modules are copied from tool/common/ into <set>/rtl/common/
    at generation time, so flist.f can reference the sibling common/
    directory directly -- each config set is fully self-contained and
    doesn't depend on tool/'s original location.
    """
    common = [
        "pipe_lane_sync2.sv",
        "pipe_lane_sel_sync.sv",
        "pipe_lane_clk_gate.sv",
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
        "pipe_lane_mapper_top.sv",
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


# ---------------------------------------------------------------- testbench


def gen_tb(cfg, pclk_mode="phy-output"):
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
    max_pclk_mode = pclk_mode == "phy-input-max-pclk"

    # Give each lane (or, in max-pclk mode, each controller) a different
    # clock period + phase offset, to exercise asynchronous CDC. Period
    # range 3..15ns; SETTLE is the slowest period * 20 (>=3 sync stages
    # plus hold margin).
    periods = [3 + (l % 7) * 2 for l in range(LC)]
    ctrl_periods = [3 + (c % 7) * 2 for c in range(NC)]
    lane_periods = [5 + (l % 7) * 2 for l in range(LC)]  # rx_clk, offset from ctrl_periods' phase
    settle = max(ctrl_periods) * 20 if max_pclk_mode else max(periods) * 20

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
    if max_pclk_mode:
        L.append("    // Different period + phase offset per controller (max_pclk) and per")
        L.append("    // lane (rx_clk), to exercise asynchronous CDC.")
        L.append(f"    localparam int unsigned CTRL_PERIOD_NS [0:{NC-1}] = '{{")
        for i, p in enumerate(ctrl_periods):
            L.append(f"        {p}{',' if i != NC-1 else ''}")
        L.append("    };")
        L.append(f"    localparam int unsigned LANE_PERIOD_NS [0:{LC-1}] = '{{")
        for i, p in enumerate(lane_periods):
            L.append(f"        {p}{',' if i != LC-1 else ''}")
        L.append("    };")
        L.append("")
        L.append("    logic [NC-1:0] max_pclk;")
        L.append("    logic [NL-1:0] rx_clk;")
        L.append("")
        L.append("    for (genvar c = 0; c < NC; c++) begin : g_ctrl_clk")
        L.append("        initial begin")
        L.append("            max_pclk[c] = 1'b0;")
        L.append("            #(c * 0.7);")
        L.append("            forever #(CTRL_PERIOD_NS[c] / 2.0) max_pclk[c] = ~max_pclk[c];")
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
                f"    assign {c.lname}_pclk = {{{c.max_width}{{max_pclk[{c.id}]}}}};"
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
    L.append("    logic [NC-1:0]        ctrl_rst_n = '0;")
    L.append(f"    logic [{clog2(nm)-1}:0] mode = '0;")
    L.append("")
    L.append("    logic [NC-1:0]        ctrl_pclk;")
    L.append("    logic [NL-1:0]      phy_pclk_in;")
    L.append("    logic [NL-1:0]      phy_rst_n;")
    L.append("")
    L.append("    mac2phy_lane_t [NL-1:0] phy_mac2phy;")
    L.append("    phy2mac_lane_t [NL-1:0] phy_phy2mac;")
    L.append("")
    for c in ctrls:
        L.append(f"    mac2phy_lane_t [{c.max_width-1}:0] {c.lname}_mac2phy;")
        L.append(f"    phy2mac_lane_t [{c.max_width-1}:0] {c.lname}_phy2mac;")
    L.append("")

    # ---- DUT instance
    L.append("    pipe_lane_mapper_top #(")
    L.append("        .NL (NL),")
    L.append("        .NC (NC)")
    L.append("    ) dut (")
    if max_pclk_mode:
        L.append("        .max_pclk       (max_pclk),")
        L.append("        .test_en        (test_en),")
        L.append("        .ctrl_rst_n     (ctrl_rst_n),")
        L.append("        .mode           (mode),")
        L.append("        .rx_clk         (rx_clk),")
        L.append("        .ctrl_pclk      (ctrl_pclk),")
        L.append("        .phy_pclk_in    (phy_pclk_in),")
        L.append("        .phy_rst_n      (phy_rst_n),")
        L.append("        .phy_mac2phy    (phy_mac2phy),")
        L.append("        .phy_phy2mac    (phy_phy2mac),")
        for c in ctrls:
            L.append(f"        .{c.lname}_mac2phy ({c.lname}_mac2phy),")
            L.append(f"        .{c.lname}_phy2mac ({c.lname}_phy2mac),")
            L.append(f"        .{c.lname}_pclk    ({c.lname}_pclk),")
            L.append(f"        .{c.lname}_rx_clk  ({c.lname}_rx_clk),")
    else:
        L.append("        .phy_pclk_out   (phy_pclk_out),")
        L.append("        .test_en        (test_en),")
        L.append("        .ctrl_rst_n     (ctrl_rst_n),")
        L.append("        .mode           (mode),")
        L.append("        .ctrl_pclk      (ctrl_pclk),")
        L.append("        .phy_pclk_in    (phy_pclk_in),")
        L.append("        .phy_rst_n      (phy_rst_n),")
        L.append("        .phy_mac2phy    (phy_mac2phy),")
        L.append("        .phy_phy2mac    (phy_phy2mac),")
        for c in ctrls:
            L.append(f"        .{c.lname}_mac2phy ({c.lname}_mac2phy),")
            L.append(f"        .{c.lname}_phy2mac ({c.lname}_phy2mac),")
    L[-1] = L[-1].rstrip(",")
    L.append("    );")
    L.append("")

    # ---- stimulus patterns
    L.append("    //------------------------------------------------------------ stimulus patterns")
    L.append("    function automatic mac2phy_lane_t make_m2p(input int cid, input int port);")
    L.append("        mac2phy_lane_t v;")
    L.append("        v = SAFE_M2P;")
    L.append("        v.mac_phy_txdata      = {4'(cid), 20'h0, 8'(port)};")
    L.append("        v.mac_phy_txdatak     = 4'(port);")
    L.append("        v.mac_phy_txdatavalid = 1'b1;")
    L.append(
        "        v.mac_phy_txelecidle  = 1'b0;   // non-idle (may differ from the signal's safe state)"
    )
    L.append(
        "        v.mac_phy_rxstandby   = 1'b0;   // non-idle (may differ from the signal's safe state)"
    )
    L.append("        return v;")
    L.append("    endfunction")
    L.append("")
    L.append("    function automatic phy2mac_lane_t make_p2m(input int lane);")
    L.append("        phy2mac_lane_t v;")
    L.append("        v = SAFE_P2M;")
    L.append("        v.phy_mac_rxdata      = {8'hA5, 16'h0, 8'(lane)};")
    L.append("        v.phy_mac_rxdatak     = 4'(lane);")
    L.append("        v.phy_mac_rxdatavalid = 1'b1;")
    L.append(
        "        v.phy_mac_rxelecidle      = 1'b0;  // non-idle (may differ from the signal's safe state)"
    )
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
    L.append(f"        for (int l = 0; l < NL; l++) begin")
    L.append(f"            phy_phy2mac[l] = make_p2m(l);")
    L.append(f"            phy_phy2mac[l].phy_mac_phystatus = phy_phystatus_stim[l];")
    L.append(f"        end")
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

    # ---- NOV monitor
    L.append(
        "    //------------------------------------------------------------ NOV one-hot / safe-state monitor"
    )
    L.append("    int unsigned err_count = 0;")
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
    if muxed:
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
        # tautology against its own internal signal.
        muxed_ctrl_ids = sorted({c for g in muxed for c in g.cands})
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
            L.append(f"    }};")
        L.append("")

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
        L.append("            sel_snap = dut.sel_tgt;")
        L.append("            #1;")
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
            L.append(f"            end")
        L.append("        end")
        L.append("    end")
    else:
        L.append(
            "    // This topology is all direct connections; no NOV groups, nothing to monitor."
        )
    L.append("")

    # ---- check_mode
    L.append(
        "    //------------------------------------------------------------ steady-state data-routing check"
    )
    L.append("    task automatic check_mode(input int m);")
    L.append("        mac2phy_lane_t exp_m2p;")
    L.append("        phy2mac_lane_t exp_p2m;")
    L.append("        int cid, port;")
    L.append("")
    L.append("        for (int l = 0; l < NL; l++) begin")
    L.append("            cid  = owner_of(m, l);")
    L.append("            port = port_of(m, l);")
    L.append("            exp_m2p = make_m2p(cid, port);")
    L.append("            chk_m2p(phy_mac2phy[l], exp_m2p,")
    L.append(
        '                $sformatf("mode%0d lane%0d: expected ctrl%0d port%0d", m, l, cid, port));'
    )
    L.append("")
    L.append("            chk(phy_rst_n[l] == ctrl_rst_n[cid],")
    L.append(
        '                $sformatf("mode%0d lane%0d: phy_rst_n=%0b does not follow owner ctrl%0d",'
    )
    L.append("                          m, l, phy_rst_n[l], cid));")
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

    L.append("                    chk_p2m(got, exp_tie,")
    L.append(
        '                        $sformatf("mode%0d ctrl%0d[%0d]: unmapped tie-off", m, c, p));'
    )
    L.append("                end else begin")
    L.append("                    exp_p2m = make_p2m(src_lane);")
    # make_p2m() alone always leaves phy_mac_phystatus at SAFE_P2M's
    # static value; the real phy_phy2mac stimulus (see the always_comb
    # above) overrides it per-lane from phy_phystatus_stim afterwards.
    # exp_p2m must replicate that same override, or this now-comprehensive
    # per-field check spuriously fails whenever phy_phystatus_stim[src_lane]
    # is toggled non-zero during a check_mode() call.
    L.append("                    exp_p2m.phy_mac_phystatus = phy_phystatus_stim[src_lane];")
    L.append("                    chk_p2m(got, exp_p2m,")
    L.append(
        '                        $sformatf("mode%0d ctrl%0d[%0d]: expected lane%0d data", m, c, p, src_lane));'
    )
    L.append("                end")
    L.append("            end")
    L.append("        end")
    L.append("")
    L.append(
        '        $display("%0t: mode%0d checked (%0d cumulative errors)", $time, m, err_count);'
    )
    L.append("    endtask")
    L.append("")

    # ---- sequencing
    L.append("    //------------------------------------------------------------ sequencing")
    L.append(f"    localparam realtime SETTLE = {settle};")
    L.append("")
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
            f"        // toggle physical lane 0's phystatus and dynamically verify it's followed correctly"
        )
        L.append(f"        phy_phystatus_stim[0] = 1'b1; #20;")
        L.append(f"        check_mode({m});")
        L.append(f"        phy_phystatus_stim[0] = 1'b0; #20;")
        L.append(f"        check_mode({m});")
        if i < len(cfg.modes) - 1:
            L.append(f"        mode = {cfg.modes[i+1]}; #SETTLE;")
    # Switch back after the last mode, to exercise a non-adjacent jump
    if nm >= 2:
        L.append("")
        L.append(f"        // non-adjacent jump")
        L.append(f"        mode = {cfg.modes[0]}; #SETTLE; check_mode({cfg.modes[0]});")
        L.append(f"        mode = {cfg.modes[-1]}; #SETTLE; check_mode({cfg.modes[-1]});")
    L.append("")

    # ---- reset pulse checks (last mode)
    last_m = cfg.modes[-1]
    L.append(f"        // reset pulse checks in mode{last_m}")
    L.append(
        f"        // pulse each controller: its owner lanes' phy_rst_n should follow low,"
        f" non-owner lanes stay high."
    )
    for c in ctrls:
        L.append(f"        ctrl_rst_n[{c.id}] = 1'b0; #SETTLE;")
        L.append(f"        for (int l = 0; l < NL; l++) begin")
        L.append(f"            bit expect_low;")
        L.append(f"            expect_low = (owner_of({last_m}, l) == {c.id});")
        L.append(f"            chk(phy_rst_n[l] == (expect_low ? 1'b0 : 1'b1),")
        L.append(
            f'                $sformatf("mode{last_m} lane%0d: ctrl_rst_n[{c.id}]=0 pulse, '
            f"expected phy_rst_n=%0b\", l, expect_low ? 1'b0 : 1'b1));"
        )
        L.append(f"        end")
        L.append(
            f'        $display("%0t: ctrl_rst_n[{c.id}] pulse checked (%0d cumulative errors)", '
            f"$time, err_count);"
        )
        L.append(f"        ctrl_rst_n[{c.id}] = 1'b1; #SETTLE;")
        L.append(f"        check_mode({last_m});")
    L.append("")
    L.append('        if (err_count == 0) $display("TB_RESULT: PASS");')
    L.append('        else                 $display("TB_RESULT: FAIL (%0d errors)", err_count);')
    L.append("        $finish;")
    L.append("    end")
    L.append("")
    L.append("    initial begin")
    L.append("        #20000;")
    L.append('        $error("TB_RESULT: FAIL (timeout, simulation did not finish)");')
    L.append("        $finish;")
    L.append("    end")
    L.append("")
    L.append("endmodule")
    return "\n".join(L) + "\n"


# ---------------------------------------------------------------- main


def main():
    ap = argparse.ArgumentParser(description="Generate PIPE lane mapper RTL + testbench")
    ap.add_argument(
        "--config",
        default=None,
        metavar="SET",
        help="Config set directory. CSVs are looked up in <SET>/config/, "
        "then <SET>/ itself; RTL always goes to <SET>/rtl/, and the "
        "testbench always goes to <SET>/tb/. SET is first tried as a "
        "set name under configs/, then as a path if not found there; "
        "omitting --config lists the available set names.",
    )
    ap.add_argument(
        "--sel-mode",
        choices=["sync", "comb"],
        default="sync",
        help="Which SYNC parameter the group's pipe_lane_sel_sync module uses: "
        "sync=SYNC=1 (default, non-overlap + a two-stage "
        "synchronizer, safe across clock domains); "
        "comb=SYNC=0 (combinational passthrough, only safe when "
        "the candidate controllers share one clock domain)",
    )
    ap.add_argument(
        "--pclk-mode",
        choices=["phy-output", "phy-input-max-pclk"],
        default="phy-output",
        help="Which clock architecture pipe_lane_clk_mux / the top level use: "
        "phy-output (default) -- each PHY lane generates its own PCLK "
        "(phy_pclk_out); ctrl_pclk is derived from it, glitch-free, and "
        "echoed back as phy_pclk_in; "
        "phy-input-max-pclk -- each controller has its own external PLL "
        "clock (max_pclk) and does its own division into pclk[]/rx_clk[] "
        "ports; ctrl_pclk is max_pclk passed straight through, and "
        "phy_pclk_in is glitch-free-selected per physical lane from the "
        "owning candidates' pclk",
    )
    ap.add_argument("--quiet", action="store_true")
    a = ap.parse_args()

    csv_dir, out_rtl = resolve_set(a.config)
    cfg = load(csv_dir)
    src = out_rtl / "src"
    src.mkdir(parents=True, exist_ok=True)
    common_dst = out_rtl / "common"
    # Wipe and recreate rather than just mkdir -- otherwise a file that gets
    # renamed or removed from tool/common/ (e.g. onehot_mux.sv becoming
    # pipe_lane_data_mux.sv) leaves a stale copy sitting in every config
    # set's rtl/common/ forever, since copying only ever adds files.
    if common_dst.exists():
        shutil.rmtree(common_dst)
    common_dst.mkdir(parents=True, exist_ok=True)
    tb_dir = out_rtl.parent / "tb"
    tb_dir.mkdir(parents=True, exist_ok=True)

    # Copy the hand-written common modules from tool/common/ into
    # <set>/rtl/common/, so each config set is self-contained and flist.f
    # can just reference the sibling common/ directory.
    for f in COMMON_DIR.iterdir():
        if f.is_file():
            shutil.copy2(f, common_dst / f.name)

    # Same idea for the VCS/Verdi Makefile: it's config-independent (no
    # config-specific content, just relative paths), so every config set
    # gets an identical copy instead of it being hand-maintained per set
    # and silently missing wherever nobody remembered to add it.
    if TB_MAKEFILE.is_file():
        shutil.copy2(TB_MAKEFILE, tb_dir / "makefile")

    print(f"Config: {csv_dir}")
    print(f"RTL   : {out_rtl}")
    print(f"TB    : {tb_dir}")
    files = {
        src / "pipe_lane_signal_pkg.sv": gen_pkg(cfg),
        src / "pipe_lane_mode_dec.sv": gen_decoder(cfg),
        src / "pipe_lane_sel_gen.sv": gen_sel_gen(cfg, a.sel_mode),
        src / "pipe_lane_clk_mux.sv": gen_clk_mux(cfg, a.pclk_mode),
        src / "pipe_lane_rst_mux.sv": gen_rst_mux(cfg),
        src / "pipe_lane_data_m2p.sv": gen_data_m2p(cfg),
        src / "pipe_lane_data_p2m.sv": gen_data_p2m(cfg),
        src / "pipe_lane_mapper_top.sv": gen_top(cfg, a.pclk_mode),
        out_rtl / "flist.f": gen_filelist(cfg),
        tb_dir / "tb_pipe_lane_mapper.sv": gen_tb(cfg, a.pclk_mode),
    }
    for p, c in files.items():
        if p.suffix == ".sv":
            c = format_sv(c)
        p.write_text(c, encoding="utf-8")
        print(f"  generated {p}")

    if not a.quiet:
        print()
        print(cfg.report())


if __name__ == "__main__":
    main()
