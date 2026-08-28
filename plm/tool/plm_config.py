#!/usr/bin/env python3
"""
PIPE Lane Mapper generator -- config parsing, validation, and topology analysis.

Reads three CSVs and produces analysis results consumed by RTL generation.
RTL generation lives in plm_gen.py in the same directory.
"""

import csv
import sys
from pathlib import Path


def _strip_dict(row):
    """Uniformly strip whitespace (including invisible chars) from a
    DictReader row.

    Strips every key and value, and drops keys whose value is empty.
    That way downstream parsing doesn't have to worry about whitespace
    on its own.
    """
    out = {}
    for k, v in (row or {}).items():
        if k is not None:
            k = k.strip()
        if isinstance(v, str):
            v = v.strip()
        out[k] = v
    return out


def _stripped(reader):
    """Wrap a DictReader, stripping each row as it's read."""
    for r in reader:
        yield _strip_dict(r)


# ---------------------------------------------------------------- data model

class Controller:
    def __init__(self, ctrl_id, name, max_width):
        self.id = int(str(ctrl_id).strip())
        self.name = str(name).strip()
        self.max_width = int(str(max_width).strip())

    @property
    def lname(self):
        return self.name.lower()


class Signal:
    """safe_state: the value this signal should present when it has "no
    owner".

    pipe_lane_data_mux uses it for polarity normalization (XOR with SAFE going in,
    XOR with SAFE coming out), so that when sel is all-zero (the handoff
    window) the output naturally lands on the safe state. Getting this
    wrong means sending PHY / the controller a meaningful-looking fake
    command during the handoff window (e.g. txelecidle should be 1).

    Every signal in the table goes through BBM (the synchronized sel).
    Reset (phy_rst_n / ctrl_rst_n) is a separate port and isn't in this
    table.
    """

    def __init__(self, name, direction, width, safe_state, tie_off):
        self.name = str(name).strip()
        self.direction = str(direction).strip()       # mac2phy | phy2mac
        self.width = int(str(width).strip())
        ss = str(safe_state).strip()
        self.safe_state = int(ss, 0) if ss else 0
        self.tie_off = str(tie_off).strip().lower()
        if self.tie_off == "lane0":
            self.tie_value = None
        else:
            # Any integer literal Python's int(x, 0) accepts: plain decimal
            # ("0", "1"), or a prefixed literal ("0x50", "0b101"). This is
            # deliberately more general than just 0/1 -- some phy2mac
            # signals need to tie to a specific non-boolean idle pattern
            # (e.g. a messagebus idle code), not just all-zero/all-one.
            try:
                self.tie_value = int(self.tie_off, 0)
            except ValueError:
                raise ValueError(
                    f"tie_off must be 'lane0' or an integer literal "
                    f"(e.g. 0, 1, 0x50), got '{self.tie_off}'")
            if not (0 <= self.tie_value < (1 << self.width)):
                raise ValueError(
                    f"tie_off value {self.tie_value} is out of range for "
                    f"width={self.width}")

    @property
    def is_m2p(self):
        return self.direction == "mac2phy"

    @property
    def tie_is_zero(self):
        """True when this signal's tie value is a static, all-zero literal
        -- gen_data_p2m() skips emitting these explicitly and relies on the
        surrounding struct literal's `default: '0` instead."""
        return self.tie_off != "lane0" and self.tie_value == 0

    def sv_literal(self, val):
        if self.width == 1:
            return f"1'b{val}"
        return f"{self.width}'d{val}"

    def tie_expr(self, base_lane_expr):
        """Compute the SV expression for what this signal should tie to
        when it has "no owner", per tie_off semantics.

        base_lane_expr: an SV expression referencing the base lane's
        phy2mac port (e.g. "phy_phy2mac[4]" or "phy_phy2mac[active_base]");
        pass None when no base lane is available in the current context --
        tie_off=="lane0" then falls back to "'0".

        The RTL generator (gen_data_p2m) and the tb generator (gen_tb) each
        call this with a different base_lane_expr, but tie_off semantics
        should only be defined in this one place -- otherwise we risk the
        same class of bug as the earlier pipe_lane_data_mux SAFE-parameter issue,
        where two separate checks quietly drifted apart.
        """
        if self.tie_off == "lane0":
            return f"{base_lane_expr}.{self.name}" if base_lane_expr is not None else "'0"
        return self.sv_literal(self.tie_value)


class LaneGroup:
    """A set of lanes that all share the exact same owner sequence.

    Groups are derived automatically: a lane's owner sequence across all
    modes is used as its signature, and lanes with the same signature are
    bucketed together. Lanes in the same group always change owner together,
    so they share one tgt bit, one BBM, and one en group -- this is the main
    payoff versus handling lanes individually (the demo config's BBM count
    drops from 12 to 3).
    """

    def __init__(self, gid, lanes, owners_by_mode):
        self.gid = gid
        self.lanes = lanes                    # list of phy lanes
        self.owners = owners_by_mode          # {mode: ctrl_id}
        self.cands = sorted(set(owners_by_mode.values()))   # candidate ctrl_ids

    @property
    def n(self):
        return len(self.cands)

    @property
    def is_direct(self):
        return self.n == 1

    def branch_of(self, ctrl_id):
        return self.cands.index(ctrl_id)


# ---------------------------------------------------------------- parsing

class Config:
    def __init__(self, cfg_dir):
        d = Path(cfg_dir)
        self.dir = d
        self.controllers = self._load_ctrl(d / "controllers.csv")
        self.signals = self._load_sig(d / "pipe_signals.csv")
        self.modes, self.lane_count, self.mapping = \
            self._load_map(d / "lane_mapping.csv")
        self.num_ctrl = max(self.controllers) + 1
        self.groups = self._build_groups()

        # Every controller's RTL port array is declared at this uniform
        # width -- the widest controller's max_width -- for ease of
        # connection (e.g. so a x2 and a x4 controller expose same-shaped
        # buses). A narrower controller's ports at or beyond its own real
        # max_width are "fake lanes": they can never be legally assigned a
        # PHY lane (validate() still bounds lane_mapping.csv against each
        # controller's own real max_width), they exist purely as
        # declaration padding. p2m ties them off through the same
        # tie_off/safe_p2m_align path as any other unmapped port; m2p is
        # simply left unread on those extra bits.
        self.decl_width = max((c.max_width for c in self.controllers.values()),
                               default=0)

    # -- controllers.csv
    @staticmethod
    def _load_ctrl(path):
        out = {}
        for i, r in enumerate(_stripped(
                csv.DictReader(open(path, newline="", encoding="utf-8"))), start=2):
            for col in ("ctrl_id", "ctrl_name", "max_width"):
                if col not in r or not (r[col] or "").strip():
                    raise SystemExit(f"{path} line {i}: missing {col}")
            c = Controller(r["ctrl_id"], r["ctrl_name"], r["max_width"])
            if c.id in out:
                raise SystemExit(f"{path} line {i}: duplicate ctrl_id {c.id}")
            out[c.id] = c
        if not out:
            raise SystemExit(f"{path}: no controllers defined")
        return out

    # -- pipe_signals.csv
    @staticmethod
    def _load_sig(path):
        out = []
        seen = set()
        for i, r in enumerate(_stripped(
                csv.DictReader(open(path, newline="", encoding="utf-8"))), start=2):
            for col in ("signal_name", "direction", "width", "safe_state", "tie_off"):
                if col not in r or not (r[col] or "").strip():
                    raise SystemExit(f"{path} line {i}: missing {col}")
            name = r["signal_name"]
            if name in seen:
                raise SystemExit(f"{path} line {i}: signal {name} defined twice")
            seen.add(name)
            d = r["direction"]
            if d not in ("mac2phy", "phy2mac"):
                raise SystemExit(
                    f"{path} line {i}: direction='{d}' is invalid, "
                    f"must be mac2phy or phy2mac")
            try:
                s = Signal(name, d, r["width"], r["safe_state"], r["tie_off"])
            except ValueError as e:
                raise SystemExit(
                    f"{path} line {i}: signal attribute validation failed, {e}")
            if s.width < 1:
                raise SystemExit(f"{path} line {i}: width must be >= 1")
            if s.safe_state >= (1 << s.width):
                raise SystemExit(
                    f"{path} line {i}: signal {name} has safe_state="
                    f"{s.safe_state}, out of range for width={s.width}")
            out.append(s)
        if not out:
            raise SystemExit(f"{path}: no signals defined")
        return out

    # -- lane_mapping.csv
    @staticmethod
    def _load_map(path):
        rd = csv.DictReader(open(path, newline="", encoding="utf-8"))
        if rd.fieldnames is None:
            raise SystemExit(f"{path}: file is empty")
        # Strip the header: users sometimes accidentally add spaces to
        # column names.
        rd.fieldnames = [f.strip() if f else f for f in rd.fieldnames]
        if "mode" not in rd.fieldnames:
            raise SystemExit(f"{path}: header is missing the mode column")
        cols = [c for c in rd.fieldnames if c != "mode"]
        if not cols:
            raise SystemExit(f"{path}: header has no lane columns besides mode")
        lane_count = len(cols)

        modes, mapping = [], {}
        for i, r in enumerate(_stripped(rd), start=2):
            # DictReader stuffs columns beyond the header into the None key.
            # The typical scenario is copying from another config and
            # forgetting to widen the header (an 8-lane template edited into
            # 16 lanes) -- the extra data would silently get dropped,
            # producing RTL with "half the lanes missing". This must be
            # caught.
            extra = r.get(None)
            if extra:
                raise SystemExit(
                    f"{path} line {i}: row has {lane_count + len(extra)} lanes, "
                    f"but the header only defines {lane_count} "
                    f"({cols[0]}..{cols[-1]}).\n"
                    f"  extra: {', '.join(extra)}\n"
                    f"  Please extend the header to lane{lane_count + len(extra) - 1}.")
            miss = [c for c in cols if r.get(c) is None]
            if miss:
                raise SystemExit(f"{path} line {i}: missing {', '.join(miss)}")

            mv = r["mode"] or ""
            if not mv:
                raise SystemExit(f"{path} line {i}: mode is empty")
            try:
                m = int(mv)
            except ValueError:
                raise SystemExit(f"{path} line {i}: mode='{mv}' is not an integer")
            if m in mapping:
                raise SystemExit(f"{path} line {i}: mode {m} defined twice")

            per = {}
            for idx, col in enumerate(cols):
                cell = r[col]
                if not cell:
                    raise SystemExit(
                        f"{path} line {i} {col}: cell is empty. "
                        f"Every phy lane must have an owner in every mode.")
                if cell.count("-") != 1:
                    raise SystemExit(
                        f"{path} line {i} {col}: '{cell}' has the wrong format, "
                        f"expected ctrl_id-ctrl_lane (e.g. 0-5)")
                a, b = cell.split("-")
                try:
                    per[idx] = (int(a), int(b))
                except ValueError:
                    raise SystemExit(
                        f"{path} line {i} {col}: '{cell}' contains a non-integer")
            modes.append(m)
            mapping[m] = per

        if not mapping:
            raise SystemExit(f"{path}: no mode data rows")
        return sorted(modes), lane_count, mapping

    # ------------------------------------------------------------ grouping

    def _build_groups(self):
        """Group lanes by their "owner sequence across modes"."""
        sig = {}
        for l in range(self.lane_count):
            sig[l] = tuple(self.mapping[m][l][0] for m in self.modes)
        buckets = {}
        for l in range(self.lane_count):
            buckets.setdefault(sig[l], []).append(l)
        groups = []
        for gid, (s, lanes) in enumerate(
                sorted(buckets.items(), key=lambda kv: kv[1][0])):
            owners = {m: s[i] for i, m in enumerate(self.modes)}
            groups.append(LaneGroup(gid, lanes, owners))
        return groups

    def group_of_lane(self, lane):
        for g in self.groups:
            if lane in g.lanes:
                return g
        raise KeyError(lane)

    # ------------------------------------------------------------ pclk

    def ctrl_pclk_src(self):
        """ctrl_pclk_src[ctrl_id][mode] = the lowest-numbered phy lane in
        that controller's group, for that mode.

        A controller always uses the pclk of the lowest-numbered lane in
        its group. None means it wasn't assigned any lane in that mode --
        in that case the clock mux holds its previous selection; it can
        never select nothing, or the lane enables hanging off that domain
        would stall.
        """
        res = {}
        for cid in self.controllers:
            per = {}
            for m in self.modes:
                owned = [l for l in range(self.lane_count)
                         if self.mapping[m][l][0] == cid]
                per[m] = min(owned) if owned else None
            res[cid] = per
        return res

    def ctrl_pclk_cands(self):
        src = self.ctrl_pclk_src()
        return {cid: sorted({v for v in p.values() if v is not None})
                for cid, p in src.items()}

    def _min_granularity(self):
        """For each controller, the minimum width across every mode where
        it owns any lane at all.

        This represents the smallest granularity at which this controller
        is actually ever allocated lanes, and is used to work out "how many
        controllers this granularity can simultaneously feed from the
        PHY's total lane count". A controller that never owns any lane
        doesn't appear in the result (handled separately by the zombie
        check).
        """
        gran = {}
        for cid in self.controllers:
            widths = []
            for m in self.modes:
                w = sum(1 for l in range(self.lane_count)
                        if self.mapping[m][l][0] == cid)
                if w > 0:
                    widths.append(w)
            if widths:
                gran[cid] = min(widths)
        return gran

    # ------------------------------------------------------------ validation

    def validate(self):
        err = []
        cp = self.ctrl_pclk_src()

        # The mode port is declared with width $clog2(NUM_MODES), where
        # NUM_MODES is the count of distinct modes. If the mode values
        # aren't a contiguous range starting at 0, the width gets computed
        # from "count" rather than "max value + 1", and some mode values
        # would fall outside the port's width -- those case branches could
        # never be selected in hardware.
        expect = set(range(len(self.modes)))
        actual = set(self.modes)
        if actual != expect:
            err.append(
                f"mode values must be a contiguous range starting at 0, "
                f"currently {sorted(actual)}. The decoder's mode port is "
                f"declared with width $clog2(mode count); non-contiguous "
                f"values or a range not starting at 0 will leave some mode "
                f"branches unreachable in hardware.")

        # A controller's max_width can never actually be reached if it
        # exceeds the total PHY lane count -- there simply aren't enough
        # lanes in existence to assign it, in any mode, regardless of how
        # lane_mapping.csv is filled in. This is a config authoring
        # mistake, not something that should silently generate a
        # controller whose declared capability is structurally impossible.
        for cid, c in self.controllers.items():
            if c.max_width > self.lane_count:
                err.append(
                    f"{c.name}: max_width={c.max_width} exceeds the total PHY "
                    f"lane count ({self.lane_count}) declared in "
                    f"lane_mapping.csv. No mode can ever assign it that many "
                    f"lanes -- max_width can be at most {self.lane_count}.")

        for m in self.modes:
            seen = {}
            for l in range(self.lane_count):
                cid, cl = self.mapping[m][l]
                if cid not in self.controllers:
                    err.append(f"[mode {m}] lane{l}: undefined ctrl_id={cid}")
                    continue
                c = self.controllers[cid]
                if cl >= c.max_width:
                    err.append(
                        f"[mode {m}] lane{l} -> {c.name}[{cl}] "
                        f"exceeds max_width={c.max_width}")
                key = (cid, cl)
                if key in seen:
                    err.append(
                        f"[mode {m}] {self.controllers[cid].name}[{cl}] "
                        f"is driven by both lane{seen[key]} and lane{l}")
                seen[key] = l

        # Every driving source for a given controller port must come from
        # the same group. Otherwise that port's convergence mux would have
        # sel bits coming from independent BBMs in different groups -- each
        # converges on its own with no interlock between them, and they
        # could briefly both be 1 at once, causing the two data paths to be
        # OR'd together. Cross-group interlocking is too expensive to
        # implement, so this is constrained at the topology level instead.
        port_groups = {}
        for m in self.modes:
            for l in range(self.lane_count):
                cid, cl = self.mapping[m][l]
                g = self.group_of_lane(l)
                port_groups.setdefault((cid, cl), {})[g.gid] = l
        for (cid, cl), gs in sorted(port_groups.items()):
            if len(gs) > 1:
                nm = self.controllers[cid].name if cid in self.controllers \
                    else f"ctrl{cid}"
                detail = ", ".join(f"G{g}(lane{l})" for g, l in sorted(gs.items()))
                err.append(
                    f"{nm}[{cl}]'s driving sources span multiple lane groups: {detail}.\n"
                    f"    Every driving source for one controller port must come from "
                    f"the same group, otherwise the convergence mux's sel bits can't be "
                    f"guaranteed mutually exclusive. Please adjust the lane assignment.")

        for cid, per in cp.items():
            if all(v is None for v in per.values()):
                err.append(
                    f"{self.controllers[cid].name} is never assigned a lane in "
                    f"any mode; please remove it from controllers.csv")

        # The working clock must be fixed: a controller may only change
        # width in response to a mode switch, never its working clock. If
        # the lowest-numbered owned lane within its group changes across
        # modes, multiple pclk candidates appear, forcing the sel_sync +
        # clk_gate glitch-free switching logic -- but that kind of switch is
        # still fundamentally break-before-make: the controller's clock
        # stalls during the transition regardless, so it doesn't actually
        # preserve continuity of operation, it just adds complexity for no
        # real benefit. So multiple candidates are simply disallowed here,
        # pushing the constraint forward to generation time.
        cands = self.ctrl_pclk_cands()
        for cid, cs in cands.items():
            if len(cs) > 1:
                err.append(
                    f"{self.controllers[cid].name}'s working clock comes from "
                    f"different lanes{cs} across modes, which would trigger "
                    f"glitch-free clock-switching logic. This tool requires a "
                    f"controller's working clock to stay fixed and only respond "
                    f"to mode switches by changing width: please adjust the lane "
                    f"assignment so this controller's lowest-numbered owned lane "
                    f"stays the same across every mode where it's active.")

        # Controller count should align with "total PHY lane count / minimum
        # allocation granularity". The granularity is inferred from the
        # data: the minimum width a controller is ever allocated. Too many
        # controllers: some are guaranteed to never get a lane in any config
        # (wasted / zombie). Too few: to avoid wasting lanes, some
        # controller may be forced to change its lowest-numbered owned lane
        # across modes, breaking the "fixed working clock" premise above.
        # Example: an x16 PHY with a minimum granularity of 2 lanes ideally
        # supports 8 controllers; more or fewer than 8 both violate this
        # design constraint.
        gran = self._min_granularity()
        if gran:
            g_min = min(gran.values())
            if self.lane_count % g_min != 0:
                err.append(
                    f"Total PHY lane count {self.lane_count} is not divisible by "
                    f"the minimum allocation granularity {g_min} (determined by "
                    f"{self.controllers[min(gran, key=gran.get)].name}); lanes "
                    f"can't be evenly split across controllers at this granularity.")
            else:
                ideal = self.lane_count // g_min
                actual = len(self.controllers)
                if actual != ideal:
                    err.append(
                        f"Controller count ({actual}) doesn't match the ideal count "
                        f"implied by the minimum granularity "
                        f"({self.lane_count}/{g_min}={ideal}). Too many leaves some "
                        f"controllers permanently without a lane; too few may force "
                        f"some controller to change its lowest-numbered owned lane "
                        f"across modes, conflicting with the \"fixed working clock\" "
                        f"constraint.")

        return err

    # ------------------------------------------------------------ report

    def report(self):
        L = []
        cp, cc = self.ctrl_pclk_src(), self.ctrl_pclk_cands()

        L.append("Lane groups (lanes with an identical owner sequence are grouped "
                  "automatically; a group shares one BBM)")
        L.append("")
        hdr = "  Grp  lane        " + "  ".join(f"mode{m}" for m in self.modes)
        L.append(hdr)
        L.append("  " + "-" * (len(hdr) - 2))
        nbbm = 0
        for g in self.groups:
            rng = (f"{g.lanes[0]}~{g.lanes[-1]}" if len(g.lanes) > 1
                   else f"{g.lanes[0]}")
            owners = "  ".join(
                f"{self.controllers[g.owners[m]].name:<5}" for m in self.modes)
            kind = "direct" if g.is_direct else f"{g.n}-way BBM"
            if not g.is_direct:
                nbbm += 1
            L.append(f"  G{g.gid}  lane{rng:<8}  {owners}  -> {kind}")
        L.append("")
        L.append(f"  {len(self.groups)} groups total, {nbbm} need BBM")
        L.append("")

        L.append("Controller pclk source (lowest lane in the group; holds its "
                  "previous selection when not assigned a lane)")
        L.append("")
        for cid in sorted(self.controllers):
            c = self.controllers[cid]
            per = ", ".join(
                f"m{m}=" + (f"phy{v}" if v is not None else "-")
                for m, v in cp[cid].items())
            cand = cc[cid]
            kind = "direct" if len(cand) == 1 else f"{len(cand)}-way clock mux"
            fake = (f"  (declared x{self.decl_width}, ports {c.max_width}..{self.decl_width-1} are fake lanes)"
                    if self.decl_width > c.max_width else "")
            L.append(f"  {c.name:<6} x{c.max_width:<3} {per}{fake}")
            L.append(f"           candidates {cand} -> {kind}")
        L.append("")

        L.append("Signal safe states (value shown when sel is all-zero, "
                  "implemented via pipe_lane_data_mux polarity normalization)")
        L.append("")
        for s in self.signals:
            note = ""
            if s.safe_state != 0:
                note = "  <- needs polarity normalization"
            L.append(f"  {s.name:<14} {s.direction:<8} [{s.width:>2}] "
                     f"safe={s.safe_state}{note}")
        L.append("")

        L.append("Impact of mode transitions (BBM only touches these groups)")
        L.append("")
        for a in self.modes:
            for b in self.modes:
                if a == b:
                    continue
                chg = [g.gid for g in self.groups
                       if g.owners[a] != g.owners[b]]
                keep = [g.gid for g in self.groups if g.gid not in chg]
                L.append(f"  mode {a} -> {b}: switches "
                         f"{['G%d' % x for x in chg] if chg else 'none'}, "
                         f"unaffected {['G%d' % x for x in keep] if keep else 'none'}")
        return "\n".join(L)


def load(cfg_dir):
    cfg = Config(cfg_dir)
    errs = cfg.validate()
    if errs:
        print("Config validation failed:", file=sys.stderr)
        for e in errs:
            print(f"  - {e}", file=sys.stderr)
        sys.exit(1)
    return cfg


if __name__ == "__main__":
    import argparse
    ap = argparse.ArgumentParser(description="Parse and analyze a PIPE lane topology config")
    ap.add_argument("--config",
                    default=str(Path(__file__).resolve().parent / "config"))
    a = ap.parse_args()
    print(load(a.config).report())
