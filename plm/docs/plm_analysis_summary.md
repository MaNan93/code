# PLM（PIPE Lane Mapper）工具全景分析

**最后更新**: 2026-09-26 | **基线**: 当前 `main` 分支  
**文档目标**: 记录 plm 生成器的核心原理、功能限制、术语体系，以及设计里的巧妙之处

---

## 一、工具定位

### 1.1 做什么
plm 是一个 **PIPE lane mapper RTL 代码生成器**。解决的硬件问题是：

> 多个不同宽度的 controller 共享同一组 PHY lane，需要在运行时通过一个 `mode` 输入把这些 lane 重新分配给不同的 controller；**而且正在跑数据的 controller 不能被无关的 mode 切换打扰**。

### 1.2 输入输出
```
输入：
  - controllers.csv       : 声明每个 controller 及其最大宽度
  - lane_mapping.csv      : 每个 mode 下每条 PHY lane 分给谁
  - pipe_signals.csv      : 每个走 NOV 的 PIPE 信号的属性（宽度、安全值、tie值）
  - gen_flags.txt（可选）: Qt 前端记住的生成参数。只有前端读写，CLI 不看

输出：
  - RTL/src/*.sv           : 9 个生成的模块
  - RTL/common/*.sv        : 5 个手写的公共模块（直接复制）
  - RTL/flist.f           : 文件列表（供 verilator/vcs 编译用）
  - TB/tb_pipe_lane_mapper.sv : 自检 testbench
  - TB/makefile           : VCS 仿真用的 makefile（从模板复制）
```

### 1.3 代码分层架构
```
src/plm/
├─ core/model.py          : Config / Controller / Signal / LaneGroup 数据模型 + 校验 + 拓扑分析
├─ core/paths.py          : 配置集路径解析（test/<SET>/ 或直接路径）
├─ core/gen_flags.py      : 生成 flag 的合法取值表 + arch/pclk-mode 交叉校验（无文件 I/O）
├─ core/verible.py        : verible-verilog-format 调用
├─ core/workspace.py      : CSV/工作区读写（Qt 前端用）
├─ core/generator/rtl.py  : 纯文本生成（RTL 9 个模块）
├─ core/generator/tb.py   : 纯文本生成（testbench）
├─ core/exporter.py       : 文件 I/O 编排（核心设计亮点：写到临时目录，成功后整体 os.replace，失败自动回滚）
├─ core/common/*.sv       : 5 个手写模块（pipe_lane_sel_sync 等）
├─ cli/main.py            : 统一 CLI（plm generate，plm validate）
└─ frontend/qt/           : PyQt5 GUI（唯一有效的图形前端，Web 已移除）
```

关键设计：`generator` 完全不碰文件系统，`exporter` 只负责写盘，`cli` 只负责 argparse —— 三层分工清晰，使得 `export_all()` 成为调用方统一使用的事务化输出入口。

---

## 二、生成原理详解

### 2.1 四大核心算法

#### 2.1.1 Lane 分组（`Config._build_groups()`）

这是整个设计的钥匙：

```
每条 lane 的签名 = (它在 mode0 的 owner, 在 mode1 的 owner, ... )
签名完全相同的 lane → 同一个 group
```

**为什么分组很关键**：
- 同一 group 里的 lane **永远一起换 owner**，所以共享一份选择信号、一份 NOV（non-overlap 窗口）
- NOV 电路数量 = group 数，而非 lane 数 → **大幅减少复杂度**
- mode 切换时，owner 没变的 group，它的选择信号取值不变 → `pipe_lane_sel_sync` 根本检测不到翻转，**不会进切换窗口**
- 这保证了"**只扰动变化部分**"这条核心需求，**不是靠额外互锁逻辑**，而是分组规则本身自带的性质

**对拓扑的三条硬约束**（由分组规则反推）：
- **约束 A**：同一条 controller lane 的所有驱动源必须来自同一个 group（否则汇聚 mux 的选择位来自独立 NOV，可能短暂同时有效导致数据相或）
- **约束 B**：controller 的工作时钟必须固定，只允许换宽度（不允许换时钟源，换时钟源的无毛刺切换过于复杂且无法真正保持连续工作）
- **约束 C**：controller 数量必须等于 `总lane数 / 最小分配颗粒度`（颗粒度由实际数据反推，超过则会强制破坏约束 B）

#### 2.1.2 两级选择信号

```
mode 输入
  │
  ├─> pipe_lane_mode_dec
  │    └─> dec_tgt（纯组合，mode 一变同拍跟着变）
  │         │
  │         ├────────────────────> rst_mux（直接用，复位不等 NOV）
  │         │
  │         └────────────────────> pipe_lane_sel_gen
  │                                 │
  │                                 └─> (每个 group 一个) pipe_lane_sel_sync
  │                                    (或每条非 direct lane 一个，pclk_as_phy_input 时)
  │                                      │
  │                                      └─> sel_tgt / seltgt_gN_lL
  │                                          (NOV：全 0 → 旧 owner 断 → 新 owner 接)
  │                                            │
  │                                            └──> 数据通路 / 时钟门控
```

**为什么两级**：
- `dec_tgt`：纯组合，快速反应 mode 变化，复位控制立即跟着变（不必等 NOV 完成）
- `sel_tgt`/`seltgt_gN_lL`：同步后，确保数据切换过程无毛刺，中间必须经历一段真实的全 0 窗口

#### 2.1.3 `pipe_lane_sel_sync` 的 NOV 实现（从 2 时钟扩展到 N 时钟）

核心结构（SYNC=1）：
```
每个分支 i 的电路：
  tgt[i] ──> [FF] ──┐
                    ├─> [AND] ──> [FF FF (两级同步)] ──> en[i]
  other_idle[i] ────┘
  
  其中: other_idle[i] = NOR( en[j], j ≠ i )
```

关键保证：
- `tgt` 必须是合法 one-hot（包括全 0 间隙）
- 任何时刻不会两路同时为 1（`other_idle` 保证了这一点）
- N 路形式是从 2 时钟经典结构推导的扩展（代码注释明确说了，流片前要过 CDC formal）

**SYNC=0 模式**：纯组合 `en = tgt`，只有在每个候选真的共享一个时钟域且 `tgt` 已经无毛刺时才安全。

#### 2.1.4 `pipe_lane_data_mux` 的极性归一化（最漂亮的一处）

**问题**：mux 要求"没有 owner 时输出安全值，且切换过程无毛刺"

**朴素写法的毛刺**：
```verilog
dout = (din[0] & sel[0]) | (din[1] & sel[1]) | ... | (safe & ~|sel)
```
当 `sel[0]` 拉低、`~|sel` 拉高时，是两条不同的门，中间有真空期。如果 `safe=1`（如 `txelecidle`），会出现 1→0→1 的毛刺。

**实际实现（无毛刺）**：
```verilog
acc  = OR_i( (din[i] XOR safe) AND sel[i] )
dout = acc XOR safe
```

**为什么无毛刺**：
- 选中时：两次异或抵消，最终得到 `din[i]`
- `sel` 全 0 时：`acc` 天生就是 0，出口异或得到 `safe`
- **两种情况走同一条出口电路**，没有两条支路抢时序的问题

**p2m 方向的复用**：某条 controller lane 的 mux，凡是"别的候选当选"的分支，`din` 直接填 tie 常量。"别人当选时我读到安全值"这件事是**免费得到的**，不需要额外逻辑。

---

### 2.2 两套时钟架构（生成逻辑彻底分叉）

这里的 `input` / `output` 一律以 **PHY 的 PCLK 端口方向**为准：
`pclk_as_phy_output` 是 PCLK 从 PHY 流出，`pclk_as_phy_input` 是 PCLK
流入 PHY，与 Lane Mapper 自身的端口方向无关。

| 维度 | `pclk_as_phy_output`（默认） | `pclk_as_phy_input` |
|---|---|---|
| **PCLK 谁产生** | PHY 每条 lane 各自产生 | controller 自己用外部 PLL 分频 |
| **PCLK 主路径** | `phy_pclk_out[]` → Mapper → `ctrl_pclk` | `{c}_pclk[]` → Mapper → `phy_pclk[]` |
| **返回时钟路径** | 选出的 `ctrl_pclk` 回灌到当前 owner 的 `phy_pclk_in[]` | PHY 的 `rx_clk[]` 经 Mapper 路由到 `{c}_rx_clk[]` |
| **controller 怎么用** | `clk_mux` 从当前 owner lane 选一路做 `ctrl_pclk`，再回灌 `phy_pclk_in` | controller 自己按**每条 lane 一根**送出 `{c}_pclk[]` |
| **有无 `ctrl_pclk`** | 有（顶层端口） | **没有**（既不是顶层端口也不是内部 wire） |
| **选择信号粒度** | 按 group：`sel_tgt` | 按物理 lane：`seltgt_gN_lL` |
| **同步树棵数** | 1 类（所有信号同一棵） | 2 类（`{c}_pclk` 域一棵 + `rx_clk[l]` 域一棵） |
| **关键点** | 可以按 group 共用一份选择 | 必须拆到每条 lane，因为每条 lane 最终被具体那条 lane 的时钟采样 |
| **DPR** | 从当前 mask 中最低编号 lane 的 PHY PCLK 派生 `dpr_pclk` | 外部提供自由运行的 `dpr_pclk`，并输出逐 lane `dpr_rx_clk[]` |

**为什么 `pclk_as_phy_input` 下必须拆到 lane**：
- `{c}_pclk[]` 本来就是按 lane 给的（x4+x8+x2 就是 14 根，不是 3 根）
- 数据最终被 controller **那一条具体 lane 的时钟** 采样
- 所以同步目标必须精确到那条 lane，不能拿 `{c}_pclk[0]` 代表整个 controller

**`rx_clk` 为什么需要第二棵同步树**：
- `rx_clk[l]` 是 PHY 的 CDR 恢复时钟，跟 `{c}_pclk` 没有固定相位关系，是完全独立的时钟域
- 不能直接拿同步进 `{c}_pclk` 域的信号去门控 `rx_clk[l]`，那样 `rx_clk[l]` 相对使能信号仍然是异步的
- **判断能否复用某个已同步信号的唯一标准**：两处需要的 `branch_clk` 是否完全相同

### 2.3 关键开关一览

| 开关 | 取值 | 默认值 | 作用 | 限制 |
|---|---|---|---|---|
| `--arch` | `original_pipe` / `serdes` | `original_pipe` | 纯粹是跟 `--pclk-mode` 的一致性交叉校验 | 不匹配直接报错 |
| `--pclk-mode` | `pclk_as_phy_output` / `pclk_as_phy_input` | `pclk_as_phy_output` | 选择时钟架构，生成物完全不兼容 | 必须和 `--arch` 匹配 |
| `--dpr` | flag | 关闭 | 加 DPR(诊断探针)overlay，并决定顶层 `SEL_SYNC` 的值（开为 sync，关为 comb；localparam，例化时不可覆盖） | 两种PCLK架构都支持，PHY-input模式需要外部`dpr_pclk` |
| `--verible-path` | 路径 | 无 | `verible-verilog-format` 路径 | 找不到就跳过（纯排版） |

**设计上的克制**：时钟本身的无毛刺切换（`rx_clk` / `ctrl_pclk` 的那些 `pipe_lane_sel_sync`）永远硬编码 `SYNC=1'b1`，不接 `SEL_SYNC` 参数 —— 这条安全性质不允许使用者关掉。

---

## 三、功能限制与约束

### 3.1 硬性校验规则（9 条，失败直接报错不写文件）

| # | 检查项 | 目的 | 约束来源 |
|---|---|---|---|
| 1 | mode 必须从 0 开始连续 | mode 端口按 `$clog2(模式数)` 定宽，不连续会有分支永不可达 | 编码原理 |
| 2 | `ctrl_id`/`ctrl_lane` 合法、不超 `max_width` | 基本合法性 | 定义 |
| 3 | 同一 controller 的同一条 lane 不能被两条 PHY lane 同时驱动 | 基本拓扑冲突 | 定义 |
| 4 | **同一 controller 的同一 lane 的所有驱动源必须来自同一个 group** | 跨 group 的 NOV 各自独立收敛，可能短暂同时有效 → 数据相或 | 约束 A（分组规则） |
| 5 | controller 不能在所有 mode 下都没 lane | 禁止僵尸 controller | 配置合理性 |
| 6 | **controller 的 pclk 候选数恰好为 1** | 强制"工作时钟固定，只换宽度" | 约束 B（时钟固定） |
| 7 | `controller 数 == 总lane数 // 最小颗粒度` | 数量与颗粒度对齐 | 约束 C（颗粒度对齐） |
| 8 | `max_width <= 总lane数` | 超过总 lane 数的宽度任何 mode 都分不满 | 定义 |
| 9 | **一条 PHY lane 在其 owner 持有它的所有 mode 下，ctrl lane 下标必须固定** | 生成器对每条 lane 只解析一次下标（取 owner 首次出现的 mode），其余 mode 会接到错的 controller lane 上 | 生成器实现 |

**最容易卡住的两条**：
- **检查 6**：某个 controller 在不同 mode 下拥有的最低编号 PHY lane 必须保持不变（因为工作时钟取自这条 lane）
- **检查 4**：CtrlB 的某条 lane 如果在 mode0 由 lane3(G1) 驱动，mode1 由 lane6(G2) 驱动 → 直接拒绝

### 3.2 设计层面刻意不做的事

- **不支持换时钟源**，只支持换宽度。代码里其实为多候选时钟切换留了代码骨架（`ctrl_pclk_cands()` 长度 > 1 的路径），但 `validate()` 禁止，现有配置从未真实触发，属于防御性保留的死路径。
- **不做跨 group 仲裁**，直接在拓扑层面约束掉（检查 4）。
- **不建模真实 PCIe 宽度合法性**。工具允许任意宽度（x3/x6/x12 到处都是），真实 PCIe 只允许 2 的幂。测试配置不是在建模真实 PCIe 拓扑。
- **不做系统级切换控制**。Lane Mapper 只切换 PIPE 数据、时钟和复位；不实现模式请求握手、LTSSM、链路训练、恢复策略或 `busy/done` 状态。
- **不生成 DFT 测试旁路**。当前顶层和 clock gate 均无 `test_en` 接口；工艺 ICG 的测试使能固定为 0。

### 3.3 生成器不校验的隐含假设（踩坑点）

| 假设 | 为什么重要 | 后果 |
|---|---|---|
| `mode` 由上层提供合法、无毛刺的值，并在一次切换收敛期间保持稳定 | Mapper只执行所请求的路由，不判断系统何时允许切换 | 不满足时不能保证切换目标符合上层意图 |
| owner将变化的Group在切换前已停止使用相应PIPE lane | Mapper不负责Controller/PHY静默、复位或链路恢复 | 切换期间这些Lane的数据没有功能意义 |
| `v_lane_mask` 要求按 group 粒度拉高（一个 group 里所有 lane 一起 mask） | DPR 抢占 lane 的粒度 | 违反这个约定会导致 DPR 与真实候选的视图不一致 |
| `safe_state` 和 `tie_off` 故意不做一致性校验 | 两列回答两个不同问题（换手中 vs 从没接过），不是同一件事的两种写法 | 可以各自取值，但需要使用者理解语义差异 |

`signal_type=shared` 当前只允许用于 MAC→PHY；PHY→MAC 必须是 `perlane`，
因此不存在从PHY多条Lane收敛成一个shared标量的隐含假设。

### 3.4 `sync`/`comb` 带来的语义差异

| 方面 | `sync` | `comb` |
|---|---|---|
| 选择信号流程 | 一个 one-hot → 全 0 → 另一个 one-hot（真实 NOV 窗口） | 一个 one-hot → 另一个 one-hot（直接切） |
| `safe_state` 被呈现时机 | 仅在全 0 窗口（NOV 过程中） | **从不被呈现**（never 经过全 0） |
| `tie_off` 被呈现时机 | 与同步策略无关：只用在从没被任何 lane 映射到的 controller lane 上，是纯 `assign` | 同左 |
| 安全性 | 跨时钟域安全 | 仅在所有候选共享一个时钟域时安全 |
| **例外** | 无 | unused lane 的硬 tie（纯 assign）两种都生效 |

### 3.5 已知的死代码与不对称

- ~~`SAFE_P2M` 在 RTL 里无引用~~ —— **已修复**。p2m 的 `pipe_lane_data_mux.safe()` 现在接 `SAFE_P2M`，和 m2p 侧对称；`tie_off` 只负责从没被映射过的 controller lane。改之前默认信号表里 `phy_mac_rxelecidle` 的 `safe_state=1` 是静默失效的。
- 反过来，**`gen_data_m2p()`** 里完全不读 `tie_off`（每条 PHY lane 在每个 mode 下都必须有 owner，不存在"没人用"的情况）。
- **多候选时钟切换路径**：`ctrl_pclk_cands()` 长度 > 1 的代码在 `clk_mux` 里写了，但 `validate()` 禁止这种配置，所以从未被实际触发。

### 3.6 流程层面的限制

- **RTL 和 TB 由一次 `generate` 使用同一组参数生成**；一边失败时两边旧输出都保持不变。
- **生成参数只走命令行**。`make` 靠 `Makefile` 里的 `SETFLAGS_<SET>`，Qt 前端靠 Generation 页；CLI 不读任何文件。
- **选择方式跟 `--dpr` 走**：开 DPR 为 `sync`，不开为 `comb`，没有单独的 `--sel-mode`。
- **`--dpr` 支持两种 PCLK 架构**。`pclk_as_phy_output` 下从当前Mask的PHY PCLK派生`dpr_pclk`；`pclk_as_phy_input` 下由外部提供自由运行的`dpr_pclk`，并输出逐Lane的`dpr_rx_clk`。
- **生成物的正确性完全靠仿真验证**，`Makefile` 本身不做任何检查。

---

## 四、术语表

### 核心概念

| 术语 | 含义 |
|---|---|
| **PIPE** | PHY Interface for PCI Express，MAC 与 PHY 之间的标准接口 |
| **lane mapper** | 把 PHY 物理 lane 按 mode 动态分配给各 controller 的那层电路，也就是这套 RTL 本身 |
| **mode** | 顶层输入，选择"哪一套 lane 分配方案"。取值必须从 0 开始连续 |
| **controller / ctrl** | 共享这组 PHY lane 的 MAC 侧 IP，各有自己的 `max_width` |

### Lane 相关

| 术语 | 含义 |
|---|---|
| **PHY lane / 物理 lane** | `lane_mapping.csv` 的列，编号 0..NL-1 |
| **ctrl lane / controller lane** | 单元格 `<ctrl_id>-<ctrl_lane>` 里的后半，某个 controller 自己那一侧的 lane 编号，0..max_width-1 |
| **owner** | 某个 mode 下，某条 PHY lane 归属的 controller，由 `lane_mapping.csv` 定义 |
| **lane group / G#** | 在**所有 mode 下 owner 序列完全相同**的一组 PHY lane，共享一份 NOV，记为 G0/G1/G2... |
| **direct group** | 候选数为 1 的 group（owner 永不变），直接 `assign`，没有 mux/NOV |
| **BBM lane** | **需要 NOV 的 lane**（breakbefore-make），owner 在某个 mode 切换时发生变化 |

### 切换相关

| 术语 | 含义 |
|---|---|
| **candidate / 候选** | 某个 group 在所有 mode 下出现过的 owner 集合，也叫该 group 的分支集 |
| **branch** | 数据 mux 的一条输入分支，对应一个候选 controller |
| **NOV (non-overlap)** | 切换窗口：old_owner 断开 → 全 0 安全态（旁路 safe_state/tie_off）→ new_owner 建立 |
| **dec_tgt** | 译码器纯组合输出，mode 一变同拍就变，给 `rst_mux` 用（快速的） |
| **sel_tgt** | 同步+NOV 之后的选择信号，驱动数据通路和时钟门控（慢速的、安全的） |
| **seltgt_gN_lL** | `pclk_as_phy_input` 架构下，按物理 lane 拆开的选择信号（不是 group 级） |

### 信号属性

| 术语 | 含义 |
|---|---|
| **safe_state** | 两个方向都生效：NOV 交接窗口里暂时没有 owner 时呈现的值（如 `txelecidle` 该是 1）。拼成 `SAFE_M2P` / `SAFE_P2M` |
| **tie_off** | 仅对 p2m 生效：controller 的某条 lane 在**任何** mode 下都没分到 PHY lane 时 tie 成什么。可以是整数字面量，或 `lane0`（跟随最低编号 lane） |
| **perlane** | 该信号在某个 controller 自己的各条 lane 上是独立取值 |
| **shared** | 该信号在某个 controller 自己的各条 lane 上只有一个值（如 Rate/PowerDown，整条 link 一起变） |
| **极性归一化** | `pipe_lane_data_mux` 里"入口 XOR safe、出口 XOR safe"的无毛刺结构 |

### 时钟相关

| 术语 | 含义 |
|---|---|
| **ctrl_pclk** | 仅存在于 `pclk_as_phy_output`：从当前 owner 的 PHY lane 选出来的 controller 工作时钟 |
| **{c}_pclk[]** | 仅存在于 `pclk_as_phy_input`：某个 controller 按每条 lane 一根送出的分频时钟 |
| **rx_clk** | PHY 每条 lane 的 CDR 恢复时钟，独立时钟域，不能直接复用其它域的同步信号 |
| **phy_pclk_out** | `pclk_as_phy_output` 下 PHY 每条 lane 自己产生的 PCLK |
| **phy_pclk_in** | `pclk_as_phy_output` 下驱动回 PHY 的反馈时钟（由 clk_mux 选出） |

### 配置相关

| 术语 | 含义 |
|---|---|
| **配置集 / config set** | `test/<NAME>/` 一整套（config CSVs + 生成出来的 rtl/ 和 tb/）。注：目录叫 `test/`，但代码里的术语仍是 `--config`/`CONFIGS_ROOT`，是当初刻意决定不跟着改名的 |
| **arch** | `original_pipe`（经典 PIPE PHY）/ `serdes`（SerDes 风格宏），只是 `--pclk-mode` 的交叉校验 |
| **最小颗粒度** | 某个 controller 在任何 mode 下被分配时的最小宽度，取全体最小值用来检查 controller 数量是否合理 |

### 可选特性

| 术语 | 含义 |
|---|---|
| **DPR** | **Diagnostic Probe** 诊断探针 overlay，由 `v_lane_mask` 实时抢占 lane，作为每个 group 选择向量的最高一位 |
| **v_lane_mask** | DPR 的实时掩码输入，按 PHY lane 给（每条 lane 一位），系统级使用约定：按 group 粒度拉高 |
| **dpr_pclk** | DPR 自己的工作时钟，由 clk_mux 从当前 mask 的最低编号 lane 的时钟派生 |

---

## 五、当前配置集状态

### 5.1 有效的配置集

| 名称 | 模式数 | lane 总数 | controller | 特点 | 校验 |
|---|---|---|---|---|---|
| **bifurcate** | 4 | 16 | CtrlX16(x16), CtrlX8(x8), CtrlX4a(x4), CtrlX4b(x4) | 分叉拓扑 | OK |
| **dpr** | 4 | 12 | CtrlA(x12), CtrlB(x6), CtrlC(x8), CtrlD(x3) | DPR overlay 演示 | OK |
| **finegrain** | 3 | 6 | CtrlAlpha(x3), CtrlBeta(x2), CtrlGamma(x1), CtrlDelta(x1), CtrlEpsilon(x1), CtrlZeta(x1) | 最细颗粒度（x1） | OK |
| **maxpclk** | 4 | 12 | CtrlA(x12), CtrlB(x6), CtrlC(x8), CtrlD(x3) | 演示 `pclk_as_phy_input` | OK |

---

## 六、设计里的巧妙之处（三大亮点）

### 亮点 1：分组规则自带"只扰动变化部分"

不是靠复杂的互锁逻辑或仲裁器，而是一个简单的分组规则：**同一 group 里的 lane 在所有 mode 下 owner 完全一致** → owner 不变的 group 的选择信号值永不改变 → `pipe_lane_sel_sync` 根本检测不到翻转，不会进 NOV。

这个设计示例（dpr）：mode0→mode2 只切 G2/G3，G0/G1 全程不受扰动。

### 亮点 2：极性归一化无毛刺结构

在 mux 的所有分支上都装一个"XOR safe"变压器，这样 safe 值就**天生在**每一条路线上，不需要另外分叉一条专门为"全 0"服务的支路。两个异或（入口+出口）让选中的路线自动恢复原值，未选中的路线则自动落到 safe。

这比起"(选中 AND din) OR (全0 AND safe)" 这种写法简洁得多，而且完全无毛刺。

### 亮点 3：exporter 的分阶段写入+原子替换

不是直接写到目标目录（失败时要手工清理），而是：
1. 建一个临时目录（随机名字）
2. 把所有生成物写到临时目录
3. 成功后用 `os.replace()` 整体原子替换
4. 失败或异常时自动清理临时目录，目标目录保持完整

这样任何部分失败都不会产生"半生成"的损坏输出。

---

## 七、关键术语对比

### "port" vs "ctrl's lane"

记住团队记忆里的约定：**永远不要说"port"来指 controller 的 lane 编号**。

| 概念 | 应该叫 | 不要叫 |
|---|---|---|
| 某个 controller 自己的 lane 编号（0..max_width-1） | ctrl lane / controller lane | port / 端口 |
| PHY 侧的物理 lane 编号（0..NL-1） | PHY lane / 物理 lane | 光说 lane（没加定语会有歧义） |
| 某条 PHY lane 到某条 ctrl lane 的对应关系 | 映射 / mapping | port 映射 |

**唯一的例外**：SystemVerilog 模块真正的输入输出端口（`pipe_lane_mapper` 的
顶层端口、`.sel()`/`.safe()` 这种例化端口）就是端口，照常叫 port / 端口。
要避免的是拿"端口"去指 controller 自己的 lane 编号——那是 `ctrl_lane`。

---

## 八、技术债与已知问题

### 8.1 流片前必做的事

- **N 路 `pipe_lane_sel_sync` 要过 CDC formal 验证**（代码注释明确说了）
- **`pipe_lane_clk_gate` 和 `pipe_lane_clk_or` 要用工艺库的时钟单元**（目前是行为级实现，默认有 `PIPE_USE_CLKOR_CELL` 开关可换）

### 8.2 死代码与可简化项

- 多候选时钟切换路径（`ctrl_pclk_cands()` > 1）从未被触发
- `pclk_as_phy_output` 下反馈时钟 mux 的完整实现其实只需要其中一部分（因为约束 B 禁止时钟源变化）

### 8.3 使用者容易犯的错

- **想象时钟架构而不仔细读文档**：`pclk_as_phy_input` 下 `{c}_pclk[]` 是按 lane 的，不是按 controller 的，这一点改变了整个同步策略
- **以为 `safe_state` 和 `tie_off` 是一回事**：前者是有主、正在换手，后者是压根没接过 PHY lane
- **把 `v_lane_mask` 当成"随意粒度"信号**：实际上系统级约定要按 group 拉高
- **`comb` 模式下期望 `safe_state` 生效**：`comb` 下选择信号永不经过全 0，所以不会呈现

---

## 参考文档

- `src/plm/docs/tool_usage.md` — 工具的完整使用文档（命令、参数、配置集格式）。跟着 wheel 一起打包，所以放在包里而不是仓库根的 docs/
- [design_notes.md](design_notes.md) — PIPE lane mapper 设计文档（原理、约束、实现细节）
- [tool_architecture.md](tool_architecture.md) — plm 生成器本身的架构决策记录
- `src/plm/core/model.py` — 配置解析与校验的源码（最权威的 validate() 规则）
- `src/plm/core/generator/rtl.py` — RTL 生成逻辑（极性归一化等实现细节）

---

**文档维护说明**：初稿 2026-09-15（commit `b88fc89`）；2026-09-16 按代码审查后的改动校订过一轮——新增第 9 条校验、p2m 改用 `safe_state`、`--dpr` 的架构限制、gen_flags.txt 降级为前端专用、5.1 表按实际配置重新核对。如有改动请同步更新相应章节，避免文档与代码漂移。
