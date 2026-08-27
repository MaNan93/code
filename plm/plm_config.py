#!/usr/bin/env python3
"""
PIPE Lane Mapper 生成器 —— 配置解析、校验与拓扑分析。

输入三张 CSV，输出分析结果供 RTL 生成使用。
RTL 生成在同目录的 plm_gen.py。
"""

import csv
import sys
from pathlib import Path


def _strip_dict(row):
    """对 DictReader 的行做统一的空白去除（含不可见字符）。

    strip 所有 key 和 value，过滤掉值为空的 key。
    这样后续解析不必各自关心空白问题。
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
    """包装 DictReader，逐行 strip。"""
    for r in reader:
        yield _strip_dict(r)


# ---------------------------------------------------------------- 数据结构

class Controller:
    def __init__(self, ctrl_id, name, max_width):
        self.id = int(str(ctrl_id).strip())
        self.name = str(name).strip()
        self.max_width = int(str(max_width).strip())

    @property
    def lname(self):
        return self.name.lower()


class Signal:
    """safe_state: 该信号「无 owner」时应呈现的值。

    onehot_mux 用它做极性归一化（进门 ^SAFE、出门 ^SAFE），
    使 sel 全 0（交接窗口）时输出天然落到安全态。填错等于在交接窗口里
    向 PHY / controller 发一个有实意的假指令（例如 txelecidle 该是 1）。

    表里所有信号都走 BBM（同步后的 sel）。复位 phy_rst_n / ctrl_rst_n
    是独立端口，不进本表。
    """

    def __init__(self, name, direction, width, safe_state, tie_off):
        self.name = str(name).strip()
        self.direction = str(direction).strip()       # mac2phy | phy2mac
        self.width = int(str(width).strip())
        ss = str(safe_state).strip()
        self.safe_state = int(ss, 0) if ss else 0
        self.tie_off = str(tie_off).strip().lower()
        if self.tie_off not in ("0", "1", "lane0"):
            raise ValueError(f"tie_off 只能为 '0', '1' 或 'lane0'，当前为 '{self.tie_off}'")

    @property
    def is_m2p(self):
        return self.direction == "mac2phy"

    def sv_literal(self, val):
        if self.width == 1:
            return f"1'b{val}"
        return f"{self.width}'d{val}"


class LaneGroup:
    """归属序列完全相同的一组 lane。

    组是自动推出来的：某条 lane 在各 mode 下的 owner 序列作为签名，
    签名相同的归为一组。同组 lane 永远整组一起换 owner，
    因此共享一位 tgt、一个 BBM、一组 en —— 这是相比按 lane 处理
    的主要收益（主配置 BBM 数量从 12 降到 3）。
    """

    def __init__(self, gid, lanes, owners_by_mode):
        self.gid = gid
        self.lanes = lanes                    # phy lane 列表
        self.owners = owners_by_mode          # {mode: ctrl_id}
        self.cands = sorted(set(owners_by_mode.values()))   # 候选 ctrl_id

    @property
    def n(self):
        return len(self.cands)

    @property
    def is_direct(self):
        return self.n == 1

    def branch_of(self, ctrl_id):
        return self.cands.index(ctrl_id)


# ---------------------------------------------------------------- 解析

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

    # -- controllers.csv
    @staticmethod
    def _load_ctrl(path):
        out = {}
        for i, r in enumerate(_stripped(
                csv.DictReader(open(path, newline=""))), start=2):
            for col in ("ctrl_id", "ctrl_name", "max_width"):
                if col not in r or not (r[col] or "").strip():
                    raise SystemExit(f"{path} 第 {i} 行: 缺少 {col}")
            c = Controller(r["ctrl_id"], r["ctrl_name"], r["max_width"])
            if c.id in out:
                raise SystemExit(f"{path} 第 {i} 行: ctrl_id {c.id} 重复")
            out[c.id] = c
        if not out:
            raise SystemExit(f"{path}: 没有任何 controller")
        return out

    # -- pipe_signals.csv
    @staticmethod
    def _load_sig(path):
        out = []
        seen = set()
        for i, r in enumerate(_stripped(
                csv.DictReader(open(path, newline=""))), start=2):
            for col in ("signal_name", "direction", "width", "safe_state", "tie_off"):
                if col not in r or not (r[col] or "").strip():
                    raise SystemExit(f"{path} 第 {i} 行: 缺少 {col}")
            name = r["signal_name"]
            if name in seen:
                raise SystemExit(f"{path} 第 {i} 行: 信号 {name} 重复定义")
            seen.add(name)
            d = r["direction"]
            if d not in ("mac2phy", "phy2mac"):
                raise SystemExit(
                    f"{path} 第 {i} 行: direction='{d}' 非法，"
                    f"应为 mac2phy 或 phy2mac")
            try:
                s = Signal(name, d, r["width"], r["safe_state"], r["tie_off"])
            except ValueError as e:
                raise SystemExit(
                    f"{path} 第 {i} 行: 信号属性校验失败，{e}")
            if s.width < 1:
                raise SystemExit(f"{path} 第 {i} 行: width 必须 >= 1")
            if s.safe_state >= (1 << s.width):
                raise SystemExit(
                    f"{path} 第 {i} 行: 信号 {name} 的 safe_state="
                    f"{s.safe_state} 超出 width={s.width} 的范围")
            out.append(s)
        if not out:
            raise SystemExit(f"{path}: 没有任何信号")
        return out

    # -- lane_mapping.csv
    @staticmethod
    def _load_map(path):
        rd = csv.DictReader(open(path, newline=""))
        if rd.fieldnames is None:
            raise SystemExit(f"{path}: 文件为空")
        # 表头 strip：用户可能不小心在列名里加了空格
        rd.fieldnames = [f.strip() if f else f for f in rd.fieldnames]
        if "mode" not in rd.fieldnames:
            raise SystemExit(f"{path}: 表头缺少 mode 列")
        cols = [c for c in rd.fieldnames if c != "mode"]
        if not cols:
            raise SystemExit(f"{path}: 表头里除 mode 外没有 lane 列")
        lane_count = len(cols)

        modes, mapping = [], {}
        for i, r in enumerate(_stripped(rd), start=2):
            # DictReader 把超出表头的列塞进 None 键。典型场景是从别的配置
            # 改过来忘了扩表头（8 lane 模板改 16 lane），多出来的数据会被
            # 静默丢弃，生成一份「少了一半 lane」的 RTL —— 必须拦住。
            extra = r.get(None)
            if extra:
                raise SystemExit(
                    f"{path} 第 {i} 行: 数据有 {lane_count + len(extra)} 个 lane，"
                    f"但表头只定义了 {lane_count} 个 "
                    f"({cols[0]}..{cols[-1]})。\n"
                    f"  多出来的: {', '.join(extra)}\n"
                    f"  请把表头补全到 lane{lane_count + len(extra) - 1}。")
            miss = [c for c in cols if r.get(c) is None]
            if miss:
                raise SystemExit(f"{path} 第 {i} 行: 缺少 {', '.join(miss)}")

            mv = r["mode"] or ""
            if not mv:
                raise SystemExit(f"{path} 第 {i} 行: mode 为空")
            try:
                m = int(mv)
            except ValueError:
                raise SystemExit(f"{path} 第 {i} 行: mode='{mv}' 不是整数")
            if m in mapping:
                raise SystemExit(f"{path} 第 {i} 行: mode {m} 重复定义")

            per = {}
            for idx, col in enumerate(cols):
                cell = r[col]
                if not cell:
                    raise SystemExit(
                        f"{path} 第 {i} 行 {col}: 格子为空。"
                        f"每条 phy lane 在每个 mode 下都必须有 owner。")
                if cell.count("-") != 1:
                    raise SystemExit(
                        f"{path} 第 {i} 行 {col}: '{cell}' 格式不对，"
                        f"应为 ctrl_id-ctrl_lane（例如 0-5）")
                a, b = cell.split("-")
                try:
                    per[idx] = (int(a), int(b))
                except ValueError:
                    raise SystemExit(
                        f"{path} 第 {i} 行 {col}: '{cell}' 含非整数")
            modes.append(m)
            mapping[m] = per

        if not mapping:
            raise SystemExit(f"{path}: 没有任何 mode 数据行")
        return sorted(modes), lane_count, mapping

    # ------------------------------------------------------------ 分组

    def _build_groups(self):
        """按「各 mode 下的 owner 序列」给 lane 分组。"""
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
        """ctrl_pclk_src[ctrl_id][mode] = 该 mode 下组内最低 phy lane。

        controller 固定使用它组内最低编号 lane 的 pclk。
        某 mode 下没分到 lane 时为 None —— 此时时钟 mux 保持上次选择，
        不能选空，否则挂在该域的 lane 使能会停摆。
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

    # ------------------------------------------------------------ 校验

    def validate(self):
        err = []
        cp = self.ctrl_pclk_src()

        # mode 端口按 $clog2(NUM_MODES) 声明位宽，NUM_MODES 取的是 mode 个数。
        # 若取值不是从 0 开始的连续整数，位宽会按「个数」而不是「最大值+1」
        # 计算，某些 mode 值会落在端口位宽之外，对应的 case 分支永远选不到。
        expect = set(range(len(self.modes)))
        actual = set(self.modes)
        if actual != expect:
            err.append(
                f"mode 取值必须是从 0 开始的连续整数，当前为 {sorted(actual)}。"
                f"译码器的 mode 端口按 $clog2(mode 个数) 声明位宽，"
                f"非连续或不从 0 开始会导致部分 mode 分支的值超出端口位宽，"
                f"在硬件上永远无法选中。")

        for m in self.modes:
            seen = {}
            for l in range(self.lane_count):
                cid, cl = self.mapping[m][l]
                if cid not in self.controllers:
                    err.append(f"[mode {m}] lane{l}: 未定义的 ctrl_id={cid}")
                    continue
                c = self.controllers[cid]
                if cl >= c.max_width:
                    err.append(
                        f"[mode {m}] lane{l} -> {c.name}[{cl}] "
                        f"超过 max_width={c.max_width}")
                key = (cid, cl)
                if key in seen:
                    err.append(
                        f"[mode {m}] {self.controllers[cid].name}[{cl}] "
                        f"被 lane{seen[key]} 和 lane{l} 同时驱动")
                seen[key] = l

        # 同一 controller 端口的所有驱动源必须来自同一个 group。
        # 否则该端口的汇聚 mux 的 sel 各位来自不同 group 的独立 BBM，
        # 它们各自收敛、互相之间没有互锁，可能短暂同时为 1，
        # 导致两路数据相或。跨组互锁实现代价太高，改为约束拓扑。
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
                    f"{nm}[{cl}] 的驱动源跨越多个 lane group: {detail}。\n"
                    f"    同一 controller 端口的所有驱动源必须来自同一个 group，"
                    f"否则汇聚 mux 的 sel 无法保证互斥。请调整 lane 分配。")

        for cid, per in cp.items():
            if all(v is None for v in per.values()):
                err.append(
                    f"{self.controllers[cid].name} 在所有 mode 下都没分到 lane，"
                    f"请从 controllers.csv 中移除")

        return err

    # ------------------------------------------------------------ 报告

    def report(self):
        L = []
        cp, cc = self.ctrl_pclk_src(), self.ctrl_pclk_cands()

        L.append("lane 分组（归属序列相同的 lane 自动成组，组共享一个 BBM）")
        L.append("")
        hdr = "  组  lane        " + "  ".join(f"mode{m}" for m in self.modes)
        L.append(hdr)
        L.append("  " + "-" * (len(hdr) - 2))
        nbbm = 0
        for g in self.groups:
            rng = (f"{g.lanes[0]}~{g.lanes[-1]}" if len(g.lanes) > 1
                   else f"{g.lanes[0]}")
            owners = "  ".join(
                f"{self.controllers[g.owners[m]].name:<5}" for m in self.modes)
            kind = "直连" if g.is_direct else f"{g.n} 选 1 BBM"
            if not g.is_direct:
                nbbm += 1
            L.append(f"  G{g.gid}  lane{rng:<8}  {owners}  -> {kind}")
        L.append("")
        L.append(f"  共 {len(self.groups)} 组，需要 BBM 的 {nbbm} 组")
        L.append("")

        L.append("controller pclk 来源（组内最低 lane，未分到 lane 时保持上次选择）")
        L.append("")
        for cid in sorted(self.controllers):
            c = self.controllers[cid]
            per = ", ".join(
                f"m{m}=" + (f"phy{v}" if v is not None else "-")
                for m, v in cp[cid].items())
            cand = cc[cid]
            kind = "直连" if len(cand) == 1 else f"{len(cand)} 选 1 时钟 mux"
            L.append(f"  {c.name:<6} x{c.max_width:<3} {per}")
            L.append(f"           候选 {cand} -> {kind}")
        L.append("")

        L.append("信号安全态（sel 全 0 时呈现的值，由 onehot_mux 极性归一化实现）")
        L.append("")
        for s in self.signals:
            note = ""
            if s.safe_state != 0:
                note = "  <- 需要极性归一化"
            L.append(f"  {s.name:<14} {s.direction:<8} [{s.width:>2}] "
                     f"safe={s.safe_state}{note}")
        L.append("")

        L.append("mode 转换影响（BBM 只会动到这些组）")
        L.append("")
        for a in self.modes:
            for b in self.modes:
                if a == b:
                    continue
                chg = [g.gid for g in self.groups
                       if g.owners[a] != g.owners[b]]
                keep = [g.gid for g in self.groups if g.gid not in chg]
                L.append(f"  mode {a} -> {b}: 切换 "
                         f"{['G%d' % x for x in chg] if chg else '无'}，"
                         f"不受影响 {['G%d' % x for x in keep] if keep else '无'}")
        return "\n".join(L)


def load(cfg_dir):
    cfg = Config(cfg_dir)
    errs = cfg.validate()
    if errs:
        print("配置校验失败：", file=sys.stderr)
        for e in errs:
            print(f"  - {e}", file=sys.stderr)
        sys.exit(1)
    return cfg


if __name__ == "__main__":
    import argparse
    ap = argparse.ArgumentParser(description="解析并分析 PIPE lane 拓扑配置")
    ap.add_argument("--config",
                    default=str(Path(__file__).resolve().parent / "config"))
    a = ap.parse_args()
    print(load(a.config).report())
