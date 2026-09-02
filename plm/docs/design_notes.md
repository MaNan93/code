# PIPE Lane Mapper 设计要点

本文档记录 `plm_gen.py` / `plm_config.py` 里几个不直接体现在代码注释中、
但对理解整体设计至关重要的原理和约束，便于以后改配置或改代码时对照。

## 1. Lane Group 是怎么划分的

`Config._build_groups()` 按"每条 lane 在所有 mode 下的 owner 序列"分组：
两条 lane 只有在**所有 mode 下 owner 完全一致**时才会被分进同一个 group。
每个 group 各自拥有一套独立的 `pipe_lane_sel_sync`，独立完成自己的 non-overlap
(NOV) 时序，group 之间互不感知、互不互锁。

这个分组规则不是任意选择，而是由一条硬约束反推出来的：**同一个 controller
端口的所有驱动源，必须来自同一个 group**（`validate()` 中已校验）。原因是
如果一个 controller 端口由跨 group 的多路 lane 驱动，那么这些驱动源各自
收敛的时刻是独立的、没有互锁关系，可能出现短暂同时有效，导致下游汇聚 mux
把两路数据相或——这个代价在 RTL 层面很难低成本解决，所以改为在拓扑层面
直接约束掉。

## 2. "动态切换"的语义：只有真正变化的部分会经历切换窗口

模式切换（比如 mode0 → mode1）不会让所有 lane 都进入 NOV 切换过程，只有
**owner 在这次切换前后确实发生变化的那些 group**，才会让自己的 `sel_tgt`
翻转、进而触发 `pipe_lane_sel_sync` 走一次 NOV 窗口。

owner 没有变化的 group，它对应的 `sel_tgt` 在切换前后取值相同，`pipe_lane_sel_sync`
检测不到翻转，根本不会进入切换窗口——这些 lane 的数据通路（`data_m2p` /
`data_p2m` 的对应分支）全程没有被扰动，仍然正常工作。

也就是说：**重新分配 PHY lane 时，不会影响已经分配且正在工作、owner 未变
的那部分 lane**。这不是靠额外互锁逻辑保证的，而是"按 owner 序列分组 + 组
间独立判断切换"这个设计本身自带的性质。第 1 节里"同一 controller 端口的
驱动源必须来自同一 group"这条约束，正是为了保证每个 group 能独立、正确地
做出"我要不要切换"的判断，不需要跟其它 group 互锁。

## 3. 工作时钟必须固定：只允许换宽度，不允许换时钟

`ctrl_pclk_src()` / `ctrl_pclk_cands()`：每个 controller 的工作时钟
(`ctrl_pclk`，**不是**参考时钟）固定使用它在当前 mode 下"组内编号最低的
那条 owned lane"的 `phy_pclk_out`。

> PIPE 规范里把这种时钟架构叫 **PCLK as PHY output**：PCLK 由 PHY 产生、
> 驱动给 MAC，而不是 MAC 给 PHY 提供参考时钟。`phy_pclk_out` 正是这个
> PHY→MAC 方向的 PCLK，`ctrl_pclk` 只是从当前 owner 所在 lane 的
> `phy_pclk_out` 里选一路——本节讨论的"工作时钟固定"，约束的正是这个
> 选择过程，而不是 PCLK 本身的产生方式。

![PCLK as PHY output：每条 PHY lane 各自产生 PCLK，clk_mux 选一路给 controller，选中的那路又回灌给 PHY 的 phy_pclk_in](images/pclk_as_phy_output.png)

**图 6**：蓝色——每条 PHY lane 各自产生自己的 PCLK（`phy_pclk_out[l]`），
这是"PCLK as PHY output"的核心：时钟由 PHY 产生、驱动出来，不是 MAC 提供
参考时钟给 PHY。橙色——`pipe_lane_clk_mux` 从当前 owner 所在 lane 的
`phy_pclk_out` 里选一路，作为这个 controller 的 `ctrl_pclk`。绿色——
controller 拿到 `ctrl_pclk` 作为自己的工作时钟。虚线——选中的这路时钟又
被送回去驱动这组 lane 的 `phy_pclk_in`，形成一个 phy→mac→phy 的环。

如果某 controller 在不同 mode 下"最低编号 owned lane"发生了变化，就说明
它在换 mode 时驱动它的工作时钟源变了，需要 `pipe_lane_sel_sync` + `pipe_lane_clk_gate` 做无
毛刺切换（先安全关断旧时钟，等新时钟稳定再打开新时钟）。

**但这类切换本质上仍是 non-overlap**：切换窗口期间 `ctrl_pclk` 完全
不翻转，controller 在这段时间里本来就等同于跟时钟断开，逻辑状态该丢的还是
会丢。也就是说无毛刺切换只解决了电路层面的问题（避免窄脉冲/亚稳态污染下
游），并不能让 controller 在切换中保持工作连续性——效果上跟"直接换时钟源、
controller 复位重来"没有本质区别，但电路复杂得多。

因此本项目的设计原则是：**模式切换时 controller 的宽度可以变，但工作时钟
不能变**——用固定时钟换宽度的方式规避上述问题，结构更简单、更容易保证正确
性。为把这条原则前移到生成阶段的硬性检查，`validate()` 中加了：

> 任何 controller 一旦出现多个 pclk 候选（即 `ctrl_pclk_cands()` 长度 > 1），
> 直接报错，禁止生成。

## 4. controller 数量要与"总 lane 数 / 最小颗粒度"对齐

即使每个 controller 各自的最低编号 lane 都固定不变，如果 controller 的
**数量**跟 PHY 的 lane 资源、最小分配颗粒度对不上，也会间接破坏第 3 节的
约束，或者造成资源浪费：

- **数量偏多**：一定有 controller 在所有配置下都分不到 lane（僵尸
  controller，`validate()` 中已有单独校验：某 controller 在所有 mode
  下都没有被使用则报错）。
- **数量偏少**：为了不浪费 lane，可能被迫在某些 mode 下让某个 controller
  拿到比"最小颗粒度"更多的 lane，从而挤压其它 controller 的分配，间接导致
  某 controller 的最低编号 owned lane 在不同 mode 下漂移——与第 3 节冲突。

例：一个 x16 PHY，如果实际用到的最小分配颗粒度是 2 lane，理想情况下最多
能同时支撑 8 个 controller；多于或少于 8 个都不满足"数量与容量对齐"这个
前提。

`Config._min_granularity()` 从 `lane_mapping.csv` 的实际数据反推每个
controller 拥有 lane 时的最小宽度，取全局最小值 `g_min`，`validate()`
中据此检查：

```
lane_count % g_min == 0                     # 否则无法被这个颗粒度均分
len(controllers) == lane_count // g_min     # 数量必须与理想值一致
```

现有的三套配置（`test_quad`：颗粒度 3、4 controller；`test_bifurcate`：
颗粒度 4、4 controller；`test_finegrain`：颗粒度 1、6 controller）均满足
此式，说明这些配置的拓扑设计本身已经符合"时钟固定、只变宽度"的原则，之前
分析出的"多候选 pclk mux 代码路径从未被真实配置触发过"并非覆盖不全，而是
拓扑本来就不需要它。

## 5. 校验规则汇总（`Config.validate()`）

**表 1**：`Config.validate()` 里的硬性检查项及各自的目的。

| 校验内容 | 目的 |
|---|---|
| mode 取值必须从 0 开始连续 | 避免译码器端口位宽不够，部分 mode 分支永远选不到 |
| lane owner 的 ctrl_id/ctrl_lane 合法性 | 防止引用未定义 controller 或超过 max_width |
| 同一 controller 端口不能被多条 lane 同时驱动 | 基本拓扑合法性 |
| 同一 controller 端口的驱动源必须来自同一 group | 保证每个 group 能独立、无需互锁地完成 NOV 判断（见第 1 节） |
| controller 不能在所有 mode 下都没有 lane | 防止声明了但完全没用到的僵尸 controller |
| controller 工作时钟候选数必须为 1 | 强制"工作时钟固定，只换宽度"（见第 3 节） |
| controller 数量必须等于 `lane_count // g_min` | 数量与颗粒度对齐，避免僵尸 controller 或被迫破坏时钟固定约束（见第 4 节） |
| controller 的 `max_width` 不能超过 PHY 总 lane 数 | 超过总 lane 数的宽度在任何 mode 下都不可能被分满，声明了也用不到（见第 9 节） |

> `tie_off` 与 `safe_state` **不**做一致性校验——见第 7 节，两者是各自只对
> 一个方向生效的独立机制，允许（也应该按需）独立取值。

## 6. 模块层次一览

```
pipe_lane_mapper_top
 ├─ u_mode_dec   (pipe_lane_mode_dec)  mode 译码，纯组合输出 dec_tgt
 ├─ u_sel_gen    (pipe_lane_sel_gen)   各 group 的 pipe_lane_sel_sync，输出同步后的 sel_tgt
 ├─ u_clk_mux    (pipe_lane_clk_mux)   controller pclk 生成 + 无毛刺切换
 ├─ u_rst_mux    (pipe_lane_rst_mux)   复位 mux，接 dec_tgt（未同步，随 mode 立即变化）
 ├─ data_m2p / data_p2m                按 sel_tgt（同步后）做数据汇聚/分发
 └─ pipe_lane_signal_pkg              公共参数/类型定义
```

`u_rst_mux` 特意接的是 `dec_tgt`（译码器原始输出）而不是 `sel_gen` 对外的
`sel_tgt`（经 `pipe_lane_sel_sync` 同步后的值），目的是让复位控制随 mode 立即变化，
不必等待 `pipe_lane_sel_sync` 完成同步和 NOV 窗口。

![dec_tgt 随 mode 立即翻转，sel_tgt 要等 NOV 窗口走完才跟上](images/dec_tgt_vs_sel_tgt.png)

**图 1**：`mode` 变化时，`dec_tgt`（纯组合）同一拍就反映新的 owner；
`sel_tgt`（`pipe_lane_sel_sync` 同步后）要先经过一段全 0 的 NOV 窗口才会
落到新值。`rst_mux` 用 `dec_tgt` 正是为了不被这段延迟拖慢复位时机。

## 7. safe_state 与 tie_off：两套独立机制，各自只对一个方向生效

`pipe_signals.csv` 里每个信号都有 `safe_state` 和 `tie_off` 两列，很容易
以为它们表达的是同一件事、理应保持一致——曾经这里就是这么假设的，还专门
加过一致性校验，后来发现是错的，已经去掉了。追踪生成器的代码会发现：
**每个方向只有一列是真正被 RTL 用上的，另一列在那个方向上是纯粹的死配置**，
两者允许、也应该按需独立取值。

### 7.1 m2p 方向：`safe_state` 生效，`tie_off` 完全不读

`pipe_lane_signal_pkg.sv` 里由所有 `mac_phy_*` 信号的 `safe_state` 拼出 `SAFE_M2P`，
直接接到每个 m2p `pipe_lane_data_mux` 的 `.safe()` 端口（`gen_data_m2p()`）。
`gen_data_m2p()` 里完全不会出现 `tie_off`——它只按 lane 遍历（每条 phy
lane 在每个 mode 下都必须有 owner，见校验规则），不存在"controller 端口
没有驱动源"这种情况，用不上 `tie_off` 这种"没人用"的语义。

### 7.2 p2m 方向：`tie_off` 生效，`safe_state`/`SAFE_P2M` 是死代码

`gen_data_p2m()` 里每个 controller 都有一个 `{c.lname}_p2m_tie`
结构体，由 `tie_off`（通过 `Signal.tie_expr()`）逐字段算出来。这个结构体
被用在**两个地方**：

1. 真正存在的 `pipe_lane_data_mux` 实例的 `.safe()` 端口（这个端口在某些 mode 下
   确实会被映射到，NOV 交接窗口用它）；
2. 端口从未被任何 lane 映射到时的直接 `assign`（不经过 `pipe_lane_data_mux`，
   见第 9 节 unused lane）。

`SAFE_P2M`（由 `safe_state` 拼出来）在这两处都没有被引用，只在
`tb_pipe_lane_mapper.sv` 里当一个初始值用（马上会被逐字段覆盖，见
`make_p2m()`/`check_mode()`），是彻头彻尾的死代码。p2m 方向的安全态
完全由 `tie_off` 一列独立决定，`safe_state` 这一列填什么，实际 RTL
行为都不受影响。

### 7.3 `tie_off` 的两个角色，只有一个跟 `--sel-mode` 有关

7.2 提到 `tie_off` 的两种用法里，第 2 种（端口从未被映射到，直接
`assign`）是一条纯组合的硬 tie，不经过 `sel_tgt`/`pipe_lane_data_mux`，不管
`--sel-mode` 是 `sync` 还是 `comb` 都完全一样地生效——**这是 unused
lane（见第 9 节）拿到正确安全值的唯一依据**。

第 1 种用法（喂给真实 `pipe_lane_data_mux` 的 `.safe()` 端口）不一样：
`pipe_lane_data_mux` 的极性归一化只在 `sel` 真的落到全 0 时才会呈现 `.safe()`
的值。而 `pipe_lane_sel_sync`（`tool/common/pipe_lane_sel_sync.sv`）的 `SYNC=0`（`comb` 模式）
是 `en = tgt` 直接透传，没有寄存器、没有同步——前提是 `tgt` 在对应时钟域
里本来就无毛刺。这个前提成立时，`sel_tgt` 从一个 one-hot 值直接切到另一
个，中间不会真的停留在全 0——也就是说 `.safe()` 的值在 `comb` 模式下压根
不会被呈现出来，天然无意义。只有 `sync` 模式（`SYNC=1`，两级同步器 + 真
正的 non-overlap）才会保证每次切换都经过一段真实的全 0 窗口，这时
`.safe()`/`tie_off` 的取值才有意义、必须遵守（呼应第 8.2 节"真正需要切换
的 group 走标准 NOV"那部分）。

![pipe_lane_data_mux 的 NOV 切换时序：sel 全 0 期间 dout 无毛刺地落在 safe 上](images/pipe_lane_data_mux_timing.png)

**图 2**：`pipe_lane_data_mux`（`safe=1`，对应 `mac_phy_txelecidle` 这类
空闲态为 1 的信号）展示的正是这段话说的现象：`sel` 落到全 0 的两段窗口
里，`dout` 干净地落在 `safe=1` 上，没有中间态毛刺——这正是
`pipe_lane_data_mux.sv` 头部注释里解释的极性归一化
（`dout = safe XOR OR_i((din[i] XOR safe) AND sel[i])`）带来的效果：
`sel` 全 0 时 OR 项结构性地恒为 0，没有额外的并行 safe 分支去跟主路径
抢时序，自然不会有毛刺。

`safe_state` 同理：它唯一生效的地方（m2p 方向的 `pipe_lane_data_mux.safe()`）
也只在 `sync` 模式下才会被真正呈现，`comb` 模式下同样无意义。

汇总：

**表 2**：`safe_state` 与 `tie_off` 各自的生效方向、角色，以及是否受
`--sel-mode` 影响。

| | 生效方向 | 角色 | 是否跟 `--sel-mode` 有关 |
|---|---|---|---|
| `safe_state` | 仅 m2p（`SAFE_M2P`） | 喂给 `pipe_lane_data_mux.safe()` | 有关——只有 `sync` 模式下才会被呈现；p2m 方向完全死代码 |
| `tie_off` (a) | 仅 p2m | unused lane 的硬 tie，纯 `assign` | 无关——任何 `--sel-mode` 下都一样生效 |
| `tie_off` (b) | 仅 p2m | 喂给 `pipe_lane_data_mux.safe()`（端口有时会被映射到） | 有关——只有 `sync` 模式下才会被呈现 |

`tie_off="lane0"` 使用的 `base_lane` 是编译期常量（取 `ctrl_pclk_cands()`
排序后最小候选）；在当前"工作时钟固定"的约束下，每个 controller 的
pclk 候选数恒为 1，`base_lane` 天然稳定，此风险已随第 3 节的校验规则
一并消除。

### 7.4 `pipe_lane_data_mux` 的极性归一化电路：为什么 `sel` 全 0 时不会有毛刺

一个直观但有问题的写法（以 N=2、WIDTH=1 为例）：

```
dout = (din[0] & sel[0]) | (din[1] & sel[1]) | (safe & ~|sel)
```

这看起来没毛病：`sel[i]=1` 就选中 `din[i]`，`sel` 全 0 就落到 `safe`。问题
出在电路的真实时序上——`sel[0]` 从 1 变 0，和 `~|sel` 从 0 变 1，是两条
不同的门算出来的信号，不是真正同时变化。中间会有一段很短的"真空期"，这
段时间里三项都读到 0。如果 `safe=0`，这个短暂的 0 没人会注意到；但如果
`safe=1`（比如 `mac_phy_txelecidle`，空闲态就是 1），这段真空期会让
`dout` 从该是 1 的 `safe` 突然掉到 0、再跳回 1——这就是一个毛刺，下游可能
把它误判成一次真实的电平变化。

`pipe_lane_data_mux.sv` 的实际写法不单独给 `safe` 搭一条抢时序的支路，而
是让每路输入天生就"自带 safe 这个选项"：

```
acc  = OR_i( (din[i] XOR safe) AND sel[i] )
dout = acc XOR safe
```

![pipe_lane_data_mux 极性归一化电路：每路 din 先跟 safe 异或、跟 sel 相与，OR 到 acc，acc 再跟 safe 异或出 dout](images/pipe_lane_data_mux_circuit.png)

**图 3**：以 N=2、WIDTH=1 为例画出的电路结构（蓝色 XOR，橙色 AND，绿色
OR）。全程只有两层异或——入口每路一次、出口一次，`sel` 全 0 时不需要另
外分叉一条支路，因为 `acc` 在没有任何一路被 `AND` 选中时天生就是 0。

- **选中某一路时**（`sel[i]=1`）：`din[i]` 先跟 `safe` 异或一次进
  `acc`，出口又跟 `safe` 异或一次——两次异或同一个 `safe` 正好抵消
  （`XOR` 是自己的逆运算：`X ⊕ safe ⊕ safe = X`），最终还是 `din[i]`
  本身。
- **`sel` 全 0 时**：没有任何一路被 AND 选中，`acc` 天生就是 0（不需要
  额外一条"判断 sel 是不是全 0"的分支），出口那次异或就变成
  `0 ⊕ safe = safe`。

两种情况走的是**同一条**最终异或电路，没有另外分叉出一条专门给 `sel=0`
用的支路，所以不存在两条支路抢时序的问题——这正是 7.3 节"`pipe_lane_data_mux`
的极性归一化只在 `sel` 真的落到全 0 时才会呈现 `.safe()` 的值"背后的电路
原理。图 2 画的正是这个电路在真实波形上的效果。

### 7.5 p2m 方向复用同一个模块：demux 只是换个角度看 mux

`pipe_lane_data_mux.sv` 头部注释里提到"demux 方向（一个 controller 端口
接收多条 phy lane）用的是同一个模块"——`gen_data_p2m()` 里每个 controller
端口都会实例化一个 `pipe_lane_data_mux`，`.din` 的每一路对应这个 group 里
的一个候选 controller（branch）：如果那个 branch 正好就是这个端口自己的
controller，`din` 接真实的 `phy_phy2mac[l]`；如果是**别的** controller，
`din` 直接填 `{c.lname}_p2m_tie`（安全值常量）。

例如 `test_quad` 里 `ctrla_phy2mac[9]`（G3 是 CtrlA/B/C/D 四路 BBM，CtrlA
是 branch0）：

```verilog
pipe_lane_data_mux #(.WIDTH(PHY2MAC_W), .N(4)) u_p2m_ctrla_9 (
    .sel (sel_tgt.g3),
    .din ({ctrla_p2m_tie, ctrla_p2m_tie, ctrla_p2m_tie, phy_phy2mac[9]}),
    .safe(ctrla_p2m_tie),
    .dout(ctrla_phy2mac[9])
);
```

![pipe_lane_data_mux 用在 p2m/demux 方向：branch0 是真实数据，branch1 的 din 直接填 safe 常量](images/pipe_lane_data_mux_demux_circuit.png)

**图 4**：灰色那条支路（branch1，代表 CtrlB 当选）的 `din[1]` 本来就等于
`safe`，所以它的 XOR 天生算出 0。`sel_tgt.g3` 选中 CtrlA 自己（branch0）
时，两次异或抵消，`ctrla_phy2mac[9]` 拿到真实的 `lane9` 数据；选中
CtrlB/C/D 中任何一个，或者 `sel` 全 0，都汇合到同一条出口异或，落在
`ctrla_p2m_tie`——"别人当选时我该读到安全值"这件事，不需要额外
逻辑，直接靠同一套极性归一化电路免费得到。

## 8. 使用场景：静态配置 vs 动态重分配

`mode` 输入和分组 NOV 是同一套机制，这里从"什么时候改 mode"这个使用场景的
角度做个归纳，方便对照第 1、2 节的分组规则去理解。RTL 本身不区分这两种场景
——是否"安全"完全由分组规则的性质保证，不依赖任何运行时判断"现在有没有
活跃 link"。

### 8.1 静态配置：没有活跃 link 时一次性配置

典型时序：保持 `ctrl_rst_n` 为 0、把 `mode` 设好，再放开 `ctrl_rst_n`（tb 里
的做法）。此时所有 controller 都还没有实际在跑数据，不存在"谁的 link 不能
被打扰"的问题。

- 每个 group 的 owner 一次性落定，`sel_tgt` 稳定到当前 mode 对应的 one-hot
  位后不再变化——效果上等同于一张固定路由表。NOV/`pipe_lane_sel_sync` 只在这一次配置
  转换里走一遍，之后闲置。
- 直连 group（如 `test_quad` 的 G0，lane0~2 恒定给 CtrlA）本来就是纯
  wire，跟 mode 无关。
- `ctrl_pclk` 本身是结构性固定的（`validate()` 强制每个 controller 只能有
  一个 pclk 候选），静态配置下也谈不上"切换"。
- 换到另一套分配方案需要整体下电、重新走"复位保持 + 改 mode + 放开复位"的
  流程。

### 8.2 动态重分配：某条 link 在跑时，把剩余 lane 重新分配给别的 controller

这是本生成器真正要解决的场景，核心保证：**改 mode 只会触碰 owner 真正变化
的 group，owner 未变的 group 全程不受扰动**（呼应第 2 节）。

- 分组规则（按"所有 mode 下 owner 序列是否完全一致"分组）保证：若某条 lane
  从 mode A 到 mode B owner 不变，其所在 group 的 `sel_tgt` 对应位不会翻转，
  `pipe_lane_sel_sync` 检测不到跳变，不会进入 NOV 窗口——该 lane 的数据通路全程未被
  扰动。
- 例（`test_quad`）：mode0→mode2 只切换 G2、G3，G0/G1 不受影响。若 CtrlA
  当时正靠 G0+G1（lane0~5）在跑，这次改 mode 完全不影响它，同时 G2/G3
  从 CtrlA 断开、切给 CtrlC。

  ![test_quad 从 mode0 切到 mode2：只有 G2、G3 经历 NOV 窗口，G0/G1 全程不受扰动](images/group_independence.png)

  **图 5**：同一次 `mode0 → mode2` 切换里，G0/G1（图中合并为一行，owner
  全程是 CtrlA）从未离开过 CtrlA，`sel_tgt` 对应位不翻转，也就没有 NOV
  窗口；只有 owner 真正变化的 G2、G3 各自独立地经历"先归零、再落到新
  owner"的窗口。这正是第 2 节说的"只有真正变化的部分会经历切换窗口"。
- "同一 controller 端口的驱动源必须来自同一 group"这条硬约束（第 1 节，
  `validate()` 强制检查）存在的意义，就是保证每个 group 能独立判断"要不要
  切"而不用跟别的 group 互锁——这是"只扰动变化部分"的前提，不是靠额外仲裁
  逻辑堆出来的。
- 真正需要切换的 group 走标准 NOV：`sel_tgt` 先归零（安全态）、旧 owner 断
  开、新 owner 建立，期间 `pipe_lane_data_mux` 保证呈现的是安全值（m2p 方向是
  `safe_state`，p2m 方向是 `tie_off`，见第 7 节），而不是悬空或两路相或——
  这个保证只在 `sync` 模式下成立，`comb` 模式下 `sel` 不会真的停在全 0，
  见第 7.3 节。

一句话：动态重分配用的就是"改 mode"这同一个操作，只是发生在有 link 已经跑
起来的时候；静态配置是同一个操作只发生一次、发生在还没有 link 跑起来的时
候。

## 9. Unused lane：端口有真实能力，只是暂时没分到 lane

一个 controller 在 `controllers.csv` 里声明的 `max_width` 是它的真实能力
（比如 x4）。哪怕能力是 x4，某个 mode 下它可能只被分到 2 条 lane（相当于
当 x2 用），端口 2、3 在这个 mode 下就是"未使用"；如果它在**所有** mode
下都只用到 2 条，端口 2、3 就是永久未使用。

这正是 `tie_off`/`p2m_tie` 机制要解决的问题——
`pipe_lane_data_p2m.sv` 里 `if not srcs: assign ... = p2m_tie`：
不管是"这个 mode 没用到"还是"所有 mode 都没用到"，只要 `port_src` 里查
不到这个 `(cid, cl)` 组合，就自动落到这条 tie-off 分支，按
`pipe_signals.csv` 里配置的 `tie_off` 语义安全 tie 掉——这条路径是纯
组合 `assign`，跟 `--sel-mode` 是 `sync` 还是 `comb` 无关（见第 7.3
节）。m2p 方向不需要特殊处理——数据是 controller 自己驱动出来的，用不
用得上是下游（PHY 侧）的事，跟本生成器无关；这种情况下 m2p 输入端口会
被空读。

每个 controller 的端口数组都按它自己真实的 `max_width` 声明，不做统一
padding，所以不存在"声明宽度超过真实能力"这种端口——每一个声明出来的
端口都对应真实硬件，区别只在于这个 mode 下有没有被分到 lane。

## 10. 另一种时钟架构：PCLK as PHY input（max_pclk）

第 3 节讲的是"PCLK as PHY output"——PHY 产生 PCLK 驱动给 MAC。PIPE 规范
还允许反过来："PCLK as PHY input"：每个 controller 自己有一路参考时钟
（这里叫 `max_pclk`，一般来自外部 PLL），driving 给 PHY。本项目把这套
架构实现成一个新的、可选的 `--pclk-mode phy-input-max-pclk`
（默认仍是 `--pclk-mode phy-output`，也就是第 3 节那套），两者互斥、
生成时二选一，`gen_clk_mux()` / `gen_top()` / `gen_tb()` 都按这个
flag 分叉，`pipe_lane_sel_gen`、`pipe_lane_data_m2p`/`p2m`
完全不受影响——这套架构只改时钟的产生/路由方式，不改数据路径的选择逻辑。

![PCLK as PHY input, max_pclk：外部 PLL 给每个 controller 一路 max_pclk，controller 自己分频出 pclk[] 送回 PHY（按 lane 无毛刺切换），PHY 的 rx_clk[] 送回给 controller（直接按 sel_tgt 选择，无需无毛刺处理）](images/pclk_max_pclk.png)

**图 7**：紫色——每个 controller 有自己独立的外部 PLL 时钟 `max_pclk`。
绿色——controller 直接用 `max_pclk` 作为 `ctrl_pclk`（没有候选可选，
单纯 passthrough），同时自己做分频（本生成器不关心这一步），分频结果
按每个端口一位的形式输出成 `{c}_pclk[]`，格式和 `{c}_mac2phy`
完全一样。橙色——`pipe_lane_clk_mux` 负责两个方向的转换：`{c}_pclk[]`
经过无毛刺切换变成 `phy_pclk_in[l]` 送给 PHY；PHY 的 `rx_clk[l]`
经过一次纯组合选择变成 `{c}_rx_clk[]` 送回 controller。蓝色——PHY。

### 10.1 `ctrl_pclk` 不再需要候选切换

第 3 节里 `ctrl_pclk` 要在多个 `phy_pclk_out` 候选之间做无毛刺切换（虽
然 `validate()` 从未真正允许这种配置存在，见第 3 节末尾）。这套新架构
里每个 controller 天生只有一路 `max_pclk`，`ctrl_pclk` 就是它的直接
passthrough，`assign ctrl_pclk = max_pclk;`，没有候选、没有切换、也不需
要 `pipe_lane_sel_sync`。`ctrl_pclk` 仍然照旧喂给 `pipe_lane_sel_gen`
内部的 `pipe_lane_sel_sync`，数据路径的 NOV 逻辑完全不变。

### 10.2 `phy_pclk_in` 为什么要按"每条物理 lane"做无毛刺切换，而不是按 group

第 3 节的 `phy_pclk_in` 无毛刺切换是按 group 做的一份，因为它选的是
`ctrl_pclk[c]`——每个 controller 只有一路，同一个候选 controller 在
同一个 group 里对所有 lane 都是同一路时钟，可以共用一组
`pipe_lane_clk_gate`。

这套新架构里 `phy_pclk_in` 选的是 `{c}_pclk[port]`——**按端口**的，
不是按 controller 的。同一个 group 里，同一个候选 controller 在不同
lane 上占用的是它自己不同的端口号，理论上（分频逻辑以后接入之后）这些
端口位的时钟可以不同。所以每条物理 lane 必须有自己独立的
`pipe_lane_sel_sync` + `pipe_lane_clk_gate` 树，`branch_clk` 接的是这
条 lane 对应的那个具体端口位，而不是一个 group 共享的信号——`tgt`
仍然可以共用 group 的 `dec_tgt.gN`（纯组合、按 mode 译码，和具体走的是
哪路时钟无关），但 `branch_clk`/`en`/`clk_gate` 都是每条 lane 独立一
份。当前（分频逻辑还没实现）同一个 controller 所有端口位事实上是同一
路时钟，这份"按 lane 独立"只是为了从设计上保证正确——真的接上分频器之
后不需要再改这部分电路。

### 10.3 `rx_clk` 为什么不需要无毛刺处理

`{c}_rx_clk[]` 的路由拓扑和 `{c}_pclk[]` 完全一样（同一个 mode 下、同
一个 owner、同一个端口号），但**不需要**做无毛刺切换：直接用已经同步
好的 `sel_tgt.gN[i]` 做一次纯组合的 AND-OR 选择——
`assign {c}_rx_clk[cl] = (rx_clk[l0] & sel_tgt.gN[i0]) | ...`——没有
`pipe_lane_clk_gate`，没有额外的同步树。这是往 controller 方向送的时
钟，不是往 PLL/PHY 的参考时钟输入方向送，容忍度不一样，所以处理方式也
更简单。

### 10.4 用法

```bash
python tool/plm_gen.py --config <SET> --pclk-mode phy-input-max-pclk
```

不加这个参数时默认还是 `phy-output`（第 3 节那套），跟之前生成的所有
配置集保持兼容。
