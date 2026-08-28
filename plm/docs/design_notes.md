# PIPE Lane Mapper 设计要点

本文档记录 `plm_gen.py` / `plm_config.py` 里几个不直接体现在代码注释中、
但对理解整体设计至关重要的原理和约束，便于以后改配置或改代码时对照。

## 1. Lane Group 是怎么划分的

`Config._build_groups()` 按"每条 lane 在所有 mode 下的 owner 序列"分组：
两条 lane 只有在**所有 mode 下 owner 完全一致**时才会被分进同一个 group。
每个 group 各自拥有一套独立的 `sel_sync`，独立完成自己的 break-before-make
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
翻转、进而触发 `sel_sync` 走一次 BBM 窗口。

owner 没有变化的 group，它对应的 `sel_tgt` 在切换前后取值相同，`sel_sync`
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
它在换 mode 时驱动它的工作时钟源变了，需要 `sel_sync` + `clk_gate` 做无
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

## 6. 模块层次一览

```
pipe_lane_mapper_top
 ├─ u_mode_dec   (pipe_lane_mode_dec)  mode 译码，纯组合输出 dec_tgt
 ├─ u_sel_gen    (pipe_lane_sel_gen)   各 group 的 sel_sync，输出同步后的 sel_tgt
 ├─ u_clk_mux    (pipe_lane_clk_mux)   controller pclk 生成 + 无毛刺切换
 ├─ u_rst_mux    (pipe_lane_rst_mux)   复位 mux，接 dec_tgt（未同步，随 mode 立即变化）
 ├─ data_m2p / data_p2m                按 sel_tgt（同步后）做数据汇聚/分发
 └─ pipe_pkg                            公共参数/类型定义
```

`u_rst_mux` 特意接的是 `dec_tgt`（译码器原始输出）而不是 `sel_gen` 对外的
`sel_tgt`（经 `sel_sync` 同步后的值），目的是让复位控制随 mode 立即变化，
不必等待 `sel_sync` 完成同步和 BBM 窗口。

## 7. 已知但尚未处理的风险点（记录备查）

- `tie_off`（`pipe_lane_data_p2m.sv` 实际生效）与 `pipe_pkg.sv` 里的
  `SAFE_P2M`/`safe_state`（未被引用，纯死代码）是两套独立维护的机制。
  **已部分处理**：`Config.validate()` 现在会校验 `tie_off` 取静态值
  （`"0"`/`"1"`）时是否与该信号的 `safe_state` 一致，两者不一致会在生成阶段
  直接报错（见 `plm_config.py` 里 `tie_off`/`safe_state` 一致性检查）。
  `tie_off="lane0"` 是有意的动态例外，不参与这项静态校验——`SAFE_P2M` 在
  RTL 里仍然是死代码这一点本身没有变，只是不会再悄悄跟 `tie_off` 打架了。
- `tie_off="lane0"` 使用的 `base_lane` 是编译期常量（取 `ctrl_pclk_cands()`
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
  位后不再变化——效果上等同于一张固定路由表。BBM/`sel_sync` 只在这一次配置
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
  `sel_sync` 检测不到跳变，不会进入 BBM 窗口——该 lane 的数据通路全程未被
  扰动。
- 例（demo）：mode0→mode1 只切换 G2、G3，G0/G1 不受影响。若 Ctrl0 当时正靠
  G0+G1 的 lane 在跑，这次改 mode 完全不影响它，同时 G2/G3 从 Ctrl0 断开、
  切给 Ctrl2。
- "同一 controller 端口的驱动源必须来自同一 group"这条硬约束（第 1 节，
  `validate()` 强制检查）存在的意义，就是保证每个 group 能独立判断"要不要
  切"而不用跟别的 group 互锁——这是"只扰动变化部分"的前提，不是靠额外仲裁
  逻辑堆出来的。
- 真正需要切换的 group 走标准 BBM：`sel_tgt` 先归零（安全态）、旧 owner 断
  开、新 owner 建立，期间 `onehot_mux` 保证呈现的是 `safe_state`，而不是悬
  空或两路相或。

一句话：动态重分配用的就是"改 mode"这同一个操作，只是发生在有 link 已经跑
起来的时候；静态配置是同一个操作只发生一次、发生在还没有 link 跑起来的时
候。
