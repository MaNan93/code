# PIPE Lane Mapper 设计要点

本文档记录 `plm_gen.py` / `plm_config.py` 里几个不直接体现在代码注释中、
但对理解整体设计至关重要的原理和约束，便于以后改配置或改代码时对照。

## 1. Lane Group 是怎么划分的

`Config._build_groups()` 按"每条 lane 在所有 mode 下的 owner 序列"分组：
两条 lane 只有在**所有 mode 下 owner 完全一致**时才会被分进同一个 group。
每个 group 各自拥有一套独立的 `pipe_lane_sel_sync`，独立完成自己的 break-before-make
(BBM) 时序，group 之间互不感知、互不互锁。

这个分组规则不是任意选择，而是由一条硬约束反推出来的：**同一个 controller
端口的所有驱动源，必须来自同一个 group**（`validate()` 中已校验）。原因是
如果一个 controller 端口由跨 group 的多路 lane 驱动，那么这些驱动源各自
收敛的时刻是独立的、没有互锁关系，可能出现短暂同时有效，导致下游汇聚 mux
把两路数据相或——这个代价在 RTL 层面很难低成本解决，所以改为在拓扑层面
直接约束掉。

## 2. "动态切换"的语义：只有真正变化的部分会经历切换窗口

模式切换（比如 mode0 → mode1）不会让所有 lane 都进入 BBM 切换过程，只有
**owner 在这次切换前后确实发生变化的那些 group**，才会让自己的 `sel_tgt`
翻转、进而触发 `pipe_lane_sel_sync` 走一次 BBM 窗口。

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

如果某 controller 在不同 mode 下"最低编号 owned lane"发生了变化，就说明
它在换 mode 时驱动它的工作时钟源变了，需要 `pipe_lane_sel_sync` + `pipe_lane_clk_gate` 做无
毛刺切换（先安全关断旧时钟，等新时钟稳定再打开新时钟）。

**但这类切换本质上仍是 break-before-make**：切换窗口期间 `ctrl_pclk` 完全
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

两套现有配置（`demo`：颗粒度 4、4 controller；`config_multi_modes`：颗粒
度 2、2 controller）均满足此式，说明这两套配置的拓扑设计本身已经符合
"时钟固定、只变宽度"的原则，之前分析出的"多候选 pclk mux 代码路径从未被
真实配置触发过"并非覆盖不全，而是拓扑本来就不需要它。

## 5. 校验规则汇总（`Config.validate()`）

| 校验内容 | 目的 |
|---|---|
| mode 取值必须从 0 开始连续 | 避免译码器端口位宽不够，部分 mode 分支永远选不到 |
| lane owner 的 ctrl_id/ctrl_lane 合法性 | 防止引用未定义 controller 或超过 max_width |
| 同一 controller 端口不能被多条 lane 同时驱动 | 基本拓扑合法性 |
| 同一 controller 端口的驱动源必须来自同一 group | 保证每个 group 能独立、无需互锁地完成 BBM 判断（见第 1 节） |
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
不必等待 `pipe_lane_sel_sync` 完成同步和 BBM 窗口。

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

`gen_data_p2m()` 里每个 controller 都有一个 `{c.lname}_safe_p2m_align`
结构体，由 `tie_off`（通过 `Signal.tie_expr()`）逐字段算出来。这个结构体
被用在**两个地方**：

1. 真正存在的 `pipe_lane_data_mux` 实例的 `.safe()` 端口（这个端口在某些 mode 下
   确实会被映射到，BBM 交接窗口用它）；
2. 端口从未被任何 lane 映射到时的直接 `assign`（不经过 `pipe_lane_data_mux`，
   见第 9.1 节 unused lane）。

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
正的 break-before-make）才会保证每次切换都经过一段真实的全 0 窗口，这时
`.safe()`/`tie_off` 的取值才有意义、必须遵守（呼应第 8.2 节"真正需要切换
的 group 走标准 BBM"那部分）。

`safe_state` 同理：它唯一生效的地方（m2p 方向的 `pipe_lane_data_mux.safe()`）
也只在 `sync` 模式下才会被真正呈现，`comb` 模式下同样无意义。

汇总：

| | 生效方向 | 角色 | 是否跟 `--sel-mode` 有关 |
|---|---|---|---|
| `safe_state` | 仅 m2p（`SAFE_M2P`） | 喂给 `pipe_lane_data_mux.safe()` | 有关——只有 `sync` 模式下才会被呈现；p2m 方向完全死代码 |
| `tie_off` (a) | 仅 p2m | unused lane 的硬 tie，纯 `assign` | 无关——任何 `--sel-mode` 下都一样生效 |
| `tie_off` (b) | 仅 p2m | 喂给 `pipe_lane_data_mux.safe()`（端口有时会被映射到） | 有关——只有 `sync` 模式下才会被呈现 |

`tie_off="lane0"` 使用的 `base_lane` 是编译期常量（取 `ctrl_pclk_cands()`
排序后最小候选）；在当前"工作时钟固定"的约束下，每个 controller 的
pclk 候选数恒为 1，`base_lane` 天然稳定，此风险已随第 3 节的校验规则
一并消除。

## 8. 使用场景：静态配置 vs 动态重分配

`mode` 输入和分组 BBM 是同一套机制，这里从"什么时候改 mode"这个使用场景的
角度做个归纳，方便对照第 1、2 节的分组规则去理解。RTL 本身不区分这两种场景
——是否"安全"完全由分组规则的性质保证，不依赖任何运行时判断"现在有没有
活跃 link"。

### 8.1 静态配置：没有活跃 link 时一次性配置

典型时序：保持 `ctrl_rst_n` 为 0、把 `mode` 设好，再放开 `ctrl_rst_n`（tb 里
的做法）。此时所有 controller 都还没有实际在跑数据，不存在"谁的 link 不能
被打扰"的问题。

- 每个 group 的 owner 一次性落定，`sel_tgt` 稳定到当前 mode 对应的 one-hot
  位后不再变化——效果上等同于一张固定路由表。BBM/`pipe_lane_sel_sync` 只在这一次配置
  转换里走一遍，之后闲置。
- 直连 group（如 demo 的 G0）本来就是纯 wire，跟 mode 无关。
- `ctrl_pclk` 本身是结构性固定的（`validate()` 强制每个 controller 只能有
  一个 pclk 候选），静态配置下也谈不上"切换"。
- 换到另一套分配方案需要整体下电、重新走"复位保持 + 改 mode + 放开复位"的
  流程。

### 8.2 动态重分配：某条 link 在跑时，把剩余 lane 重新分配给别的 controller

这是本生成器真正要解决的场景，核心保证：**改 mode 只会触碰 owner 真正变化
的 group，owner 未变的 group 全程不受扰动**（呼应第 2 节）。

- 分组规则（按"所有 mode 下 owner 序列是否完全一致"分组）保证：若某条 lane
  从 mode A 到 mode B owner 不变，其所在 group 的 `sel_tgt` 对应位不会翻转，
  `pipe_lane_sel_sync` 检测不到跳变，不会进入 BBM 窗口——该 lane 的数据通路全程未被
  扰动。
- 例（demo）：mode0→mode1 只切换 G2、G3，G0/G1 不受影响。若 Ctrl0 当时正靠
  G0+G1 的 lane 在跑，这次改 mode 完全不影响它，同时 G2/G3 从 Ctrl0 断开、
  切给 Ctrl2。
- "同一 controller 端口的驱动源必须来自同一 group"这条硬约束（第 1 节，
  `validate()` 强制检查）存在的意义，就是保证每个 group 能独立判断"要不要
  切"而不用跟别的 group 互锁——这是"只扰动变化部分"的前提，不是靠额外仲裁
  逻辑堆出来的。
- 真正需要切换的 group 走标准 BBM：`sel_tgt` 先归零（安全态）、旧 owner 断
  开、新 owner 建立，期间 `pipe_lane_data_mux` 保证呈现的是安全值（m2p 方向是
  `safe_state`，p2m 方向是 `tie_off`，见第 7 节），而不是悬空或两路相或——
  这个保证只在 `sync` 模式下成立，`comb` 模式下 `sel` 不会真的停在全 0，
  见第 7.3 节。

一句话：动态重分配用的就是"改 mode"这同一个操作，只是发生在有 link 已经跑
起来的时候；静态配置是同一个操作只发生一次、发生在还没有 link 跑起来的时
候。

## 9. Unused lane vs Fake lane：两种"端口没数据"的场景

一个 controller 端口没有真实数据，可能是两种完全不同的原因造成的——虽然
两者最终都会落进同一条 tie-off 代码路径，但产生的原因、是否随配置变化，
是两回事，容易混为一谈。

### 9.1 Unused lane（未使用端口）：真实端口，只是没分到 lane

一个 controller 在 `controllers.csv` 里声明的 `max_width` 是它的真实能力
（比如 x4）。哪怕能力是 x4，某个 mode 下它可能只被分到 2 条 lane（相当于
当 x2 用），端口 2、3 在这个 mode 下就是"未使用"；如果它在**所有** mode
下都只用到 2 条，端口 2、3 就是永久未使用。

这正是 `tie_off`/`safe_p2m_align` 机制本来就要解决的问题——
`pipe_lane_data_p2m.sv` 里 `if not srcs: assign ... = safe_p2m_align`：
不管是"这个 mode 没用到"还是"所有 mode 都没用到"，只要 `port_src` 里查
不到这个 `(cid, cl)` 组合（且 `cl` 在这个 controller 真实的 `max_width`
范围内），就自动落到这条 tie-off 分支，按 `pipe_signals.csv` 里配置的
`tie_off` 语义安全 tie 掉——这条路径是纯组合 `assign`，跟 `--sel-mode`
是 `sync` 还是 `comb` 无关（见第 7.3 节）。m2p 方向不需要特殊处理——数据
是 controller 自己驱动出来的，用不用得上是下游（PHY 侧）的事，跟本生成器
无关。

### 9.2 Fake lane（伪端口）：端口本身不对应任何真实硬件

跟 unused lane 完全不同的另一件事：为了"连接方便"，本生成器把**同一个
配置集里所有 controller 的端口数组，统一声明成这个配置集里最宽 controller
的宽度**（`Config.decl_width = max(所有 controller 的 max_width)`），而
不是各自声明成自己的真实宽度。

例如 `config_multi_modes` 里 PCIe_x4（真实 x4）和 USB_x2（真实 x2）搭配：
USB_x2 的端口数组也被声明成 x4（`usb_x2_mac2phy[3:0]` /
`usb_x2_phy2mac[3:0]`），端口 2、3 是**假的**——`lane_mapping.csv` 永远
不可能合法地把哪条 lane 分给 USB_x2 的端口 2 或 3（`validate()` 仍然按它
自己真实的 `max_width=2` 校验合法性，见第 5 节表格），这两个端口自始至终
不对应任何真实硬件，纯粹是为了让不同宽度的 controller 在顶层暴露出同样
形状的总线，方便连接。

Fake lane 跟 unused lane 的处理**不一样**：p2m 方向 fake lane 直接
`assign ... = '0`，不走 `tie_off`/`safe_p2m_align`——它不是"这个端口目
前没人用"，而是"这个端口从概念上就不存在"，没有理由跟着 `tie_off` 里为
真实端口配置的安全值走（比如某信号 `tie_off=1`，对一个从不存在的端口
没有意义）。`gen_tb()` 的 `check_mode()` 用每个 controller 的真实
`max_width` 区分"`p >= real_max_w`"（fake，期望全 0）和"`p < real_max_w`
但没有 `src_lane`"（unused，期望 `tie_expr()` 算出的值），避免两处判断
分叉。m2p 方向同样不处理：这几个输入端口直接空读（Verilator 会报
`UNUSEDSIGNAL`，属预期，不用管）。

### 9.3 两者的本质区别

| | Unused lane | Fake lane |
|---|---|---|
| 是否计入该 controller 的 `max_width` | 是，在真实能力范围内 | 否，超出真实能力，纯声明填充 |
| 产生原因 | 某 controller 在某个（或所有）mode 下没分到那么多 lane | 同配置集里各 controller 宽度不一致，为统一声明宽度而补齐 |
| p2m tie-off | 按 `tie_off`/`safe_p2m_align` 逐字段取值 | 直接 tie 到 `'0`，不看 `tie_off` |
| m2p | 不处理，controller 自己驱动，用不用是下游的事 | 不处理，输入端口空读 |
| 随配置变化吗 | 会——换一套 `lane_mapping.csv` 分配方案，未使用的端口可能变多/变少 | 不会——只要 `controllers.csv` 里各 controller 的 `max_width` 不变，哪些端口是 fake 就不变 |
| 依据 | `lane_mapping.csv` 的实际分配结果 | `Config.decl_width`（编译期从 `controllers.csv` 算出） |
