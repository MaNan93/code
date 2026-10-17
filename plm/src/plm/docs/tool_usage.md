# PIPE Lane Mapper 生成器使用文档

本文档说明如何用统一的 `plm` 命令行工具，从配置文件生成 PIPE lane mapper
的 RTL 和 testbench：项目布局、配置文件格式、命令行参数、常用工作流。

**最快上手**：仓库根目录下有一个 `run.py` launcher 脚本，直接用它跑，
不需要先 `pip install -e .`（它自己会把 `src/` 加进 `sys.path`）：

```bash
uv run python run.py generate --config <SET>
uv run python run.py validate --config <SET>
uv sync --extra qt
uv run python run.py -gui     # Qt 桌面前端
```

本文档下面用的 `plm generate ...`/`plm validate ...` 命令，等价于
`python run.py generate ...`/`python run.py validate ...`；如果想装成真正的
console-script（这样任何目录下都能直接敲 `plm ...`），在仓库根目录
（`pyproject.toml` 所在目录）跑一次：

```bash
uv sync --extra qt
```

这是一次性的（装成可编辑安装），装完之后 `plm` 包才能被 `python -m
plm.cli.main` 或 `plm` console-script 找到。安装后也可以直接运行 `plm -gui` 或 `plm-gui`。

- `plm generate --config <SET>` —— 使用同一组参数生成 RTL 和 testbench
- `plm validate --config <SET>` —— 只解析并校验配置，不生成文件

RTL 与 testbench 是一组不可拆分的产物。`generate` 会先在 staging 目录完成
两边的生成；只有全部成功才一起替换 `rtl/` 和 `tb/`。任何一步失败都会
保留原有输出，避免新 RTL 搭配旧 testbench。

关键架构约束和 mode 切换规则见本文第 0.5、0.6 节；各生成模块的实现细节
记录在生成器源码和生成 RTL 的模块头注释中。

## 0. 应用场景

### 0.1 解决的问题

一个 PHY macro 有 N 条 lane，上面挂着多个 controller。不同工作模式下，
每条 PHY lane 归哪个 controller 管是不一样的——比如 x16 整块给一个 controller，
或者拆成 x8+x8 给两个。

lane 归属要在运行时随 mode 切换，夹在 controller 和 PHY 中间的那层 mux
就是 PIPE lane mapper。手写它的麻烦在于：

- **组合爆炸**。lane 数 x mode 数 x 信号数。16 条 lane、4 个 mode、38 个 PIPE 信号，
  光数据 mux 就是上千行，而且全是机械重复。
- **切换必须无重叠**。旧 owner 先撤出，中间留一段谁都不驱动的空窗，新 owner 再接上。
  少一步就是两个 controller 同时驱动同一条 lane。
- **空窗期的值不能随便给 0**。`txelecidle` 给 0 的含义是"正在发送"，
  这段时间必须给 1，否则等于在交接过程中对 PHY 下了一条假命令。
- **时钟要跟着一起换，而且不能有毛刺**。
- **改一条 lane 的分配，上面所有东西都要重新推一遍**。

这个工具把这件事从"手写 + 逐行 review"变成"改 CSV + 重新生成"。

### 0.2 什么时候用

| 场景 | 说明 |
|---|---|
| PCIe bifurcation | 一个 x16 PHY 按 mode 拆成 x16 / x8+x8 / x8+x4+x4 等若干种组合 |
| 多个 controller 共享一个 PHY macro | 几个独立 controller 分块占用同一组 lane，分法随 mode 变 |
| 需要运行时切换 lane 归属 | 不断电、不复位整条链路的前提下改分配 |
| 归属其实是静态的，但组合太多 | 每种组合单独维护一版 RTL 不现实，用一份配置生成一份带 `mode` 输入的 RTL |
| 需要诊断探针 | `--dpr` 生成一个虚拟 controller，用 `v_lane_mask` 按 Group 临时接管 lane 做观测 |

### 0.3 什么时候不用

| 情况 | 原因 |
|---|---|
| lane 归属编译期就定死，永远不变 | 直接连线，不需要 mapper |
| 只有一个 controller，宽度固定 | 同上 |
| 想要 mapper 以外的东西 | 这个工具只生成 controller 和 PHY 之间那一层。controller 本身、PHY 本身、驱动 mode 切换的软件流程，都不在范围内 |

### 0.4 输入和输出

输入——`<SET>/config/` 下三个 CSV：

| 文件 | 内容 |
|---|---|
| `controllers.csv` | 有哪些 controller，各自最多带多少条 lane |
| `lane_mapping.csv` | 每个 mode 下，每条 PHY lane 归哪个 controller 的哪条 lane |
| `pipe_signals.csv` | 要经过 mapper 的 PIPE 信号，以及各自的 `safe_state` / `tie_off` |

CLI 的生成参数（`--arch` / `--pclk-mode` / `--dpr` / `--bus-type`）需要显式传入。Qt 直接使用同样的 GenerationOptions 调用核心。
同目录下的 `gen_flags.txt` 是 Qt 前端自己的记忆，CLI 不读，见 2.4 节。

输出——`<SET>/rtl/` 和 `<SET>/tb/`：

| 产物 | 内容 |
|---|---|
| `rtl/src/*.sv` | 9 个按配置生成的模块 |
| `rtl/common/*.sv` | 5 个手写的通用模块（两级同步器、NOV 选择、时钟门控、时钟或、data mux），原样拷贝过来，每套配置自包含 |
| `rtl/flist.f` | 编译顺序（package 在前） |
| `tb/tb_pipe_lane_mapper.sv` | 自检 testbench，覆盖时钟、复位、m2p、p2m、tie_off、safe_state 六类检查 |
| `tb/makefile` | VCS/Verdi 跑仿真用 |

### 0.5 工具替你保证了什么

- **自动分组**。owner 序列完全相同的 lane 会被归成一组，一组共用一套 NOV。
  `test/bifurcate` 16 条 lane 只分出 4 组、其中 3 组需要 NOV，不是 16 套。
- **只扰动真正变化的部分**。mode 切换时，owner 没变的组完全不受影响，时钟不停、数据不断。
- **切换无重叠**（开 DPR 时）。每组一个 `pipe_lane_sel_sync`，保证任何时刻最多一个候选被使能。
  不开 DPR 时选择信号是 `mode` 的组合译码，没有这层保护，靠“只在复位期间切 mode”保证，见 0.6 节。
- **空窗值正确且无毛刺**（开 DPR 时）。`safe_state` 用极性归一化实现，不是外挂一个"全 0 时选 SAFE"的并联分支
  （那种写法在 sel 落 0 和 `~|sel` 拉高之间有一段全 0 窗口，会产生尖峰）。
- **时钟切换 glitch-free**。所有时钟选择都走 `pipe_lane_clk_gate` + `pipe_lane_clk_or`。
- **配置非法直接报错**。拓扑上做不出正确硬件的配置在生成前就被拒绝，
  不会产出一份能编过、跑起来才错的 RTL。

#### 0.5.1 模块边界与外部前置条件

Lane Mapper 只负责在 controller 与 PHY 之间切换 PIPE 数据、时钟和复位。
它不负责决定何时切换，也不实现模式请求握手、LTSSM、链路训练或恢复流程。

使用生成 RTL 时，上层必须满足以下前置条件：

| 前置条件 | 上层责任 |
|---|---|
| `mode`合法且稳定 | 只提供配置中存在的mode；输入不能有组合毛刺，并在一次切换收敛期间保持不变 |
| 变化Group可切换 | 先让owner将发生变化的Group停止使用对应PIPE lane。不开DPR时，新旧两个owner的`rst_n`在`mode`变化期间必须同时为低；开DPR时是否复位由系统方案决定 |
| 未变化Group继续工作 | 不要因为其他Group切换而停止其时钟、数据或链路 |
| 时钟和复位有效 | 按所选PCLK架构提供符合接口要求的Controller/PHY时钟与复位 |
| DPR按Group控制 | 同一Group的`v_lane_mask`只能全0或全1，不能逐Lane任意屏蔽 |
| 切换后恢复 | 新owner何时重新训练或恢复通信由Controller/PHY及上层控制决定 |

生成RTL没有`mode_req`、`busy`、`done`等系统控制接口，也不生成DFT测试旁路。
这些都不属于Lane Mapper的模块职责。

#### 0.5.2 mode 切换的基本运行规则

mode 切换不是让一条正在传输的 PCIe Link 瞬间换到另一个 controller，也不是
要求整个 mapper 一起停机。系统必须先让 **ownership 将发生变化的 Group 所涉及的
controller** 停止使用对应 PIPE lane；这些 lane 在切换期间的数据没有功能意义。
开 DPR 时由该 Group 自己完成 break-before-make；不开 DPR 时没有这一步，
新旧 owner 必须在复位中。等选择、时钟和复位稳定后，新 owner 才能重新启动链路训练。

与此同时，起始 mode 和目标 mode 之间 **owner 没有变化的 Group 是独立的**：

- 它的有效选择保持不变，不进入全 0 handoff 空窗；
- 它的 PCLK/RXCLK 不应停顿，复位不应因其他 Group 切换而改变；
- 它的 M2P/P2M 数据通路保持连续，因此其他已经工作的 PCIe Link 可以继续工作。

换句话说，`mode` 虽然是一个全局输入，但切换动作的最小影响范围是 owner 真正变化的
Group，不是整个 mapper。配置报告中的 `switches` / `unaffected` 列表就是这个边界。

上层还必须保证 `mode` 从一个合法值稳定地更新到另一个合法值，并在整个切换收敛期间
保持不变；不能让多 bit `mode` 在 mapper 输入端出现非法值或组合毛刺。生成器能隔离合法
mode A → mode B 所影响的 Group，但不能从一个不连贯的外部 `mode` 波形推断真实目标。

#### 0.5.3 DPR 屏蔽/解除屏蔽规则

DPR 的 `v_lane_mask` 同样不是要求数据瞬时切换。mask 置位后，被屏蔽 lane 按 DPR
controller 的要求通信；mask 清零后，原 controller 也要等选择、时钟、复位以及自身状态
恢复完成才重新使用该 lane。接管和归还允许存在毫秒级过渡期，过渡期间该 lane 的数据
不要求有效。

DPR 按 lane Group（即配置的最小分配颗粒度）屏蔽，不支持 Group 内逐 bit 独立屏蔽。
同一 Group 的 `v_lane_mask` 位必须全 0 或全 1；例如颗粒度为 x2 时只允许 `00`/`11`，
不允许 `01`/`10`。RTL 使用该 Group 最低编号 lane 的 mask bit 作为整个 Group 的代表位。

DPR 的隔离要求是：**只允许扰动 mask 状态发生变化的 Group**。对于 mask 保持全 0 的
未屏蔽 Group，其他 Group 的 DPR 接管或归还不得改变它的原 controller 选择、
PCLK/RXCLK、复位和 M2P/P2M 数据通路；该 Group 上已经工作的 PCIe Link 必须继续工作。

### 0.6 硬性限制

下面这些不满足，`validate` 会直接报错（最后一行除外，只给警告）：

| 限制 | 原因 |
|---|---|
| controller 的工作时钟必须固定——它在各个 mode 下最低编号的那条 owned lane 不能变 | 工作时钟会变就得上 glitch-free 时钟切换，而那种切换本身也是非重叠的，时钟照样要停，平白多一堆复杂度换不来连续性 |
| 同一条 controller lane 的所有驱动源必须来自同一个组 | 跨组的 sel 位来自互相独立的 NOV，之间没有互锁，可能短暂同时为 1，两条数据通路会被或在一起 |
| 一条 PHY lane 在其 owner 持有它的所有 mode 下，controller lane 下标必须固定 | 生成器对每条 lane 只解析一次下标，下标会动就会在其余 mode 接到错误的 controller lane 上 |
| `mode` 取值必须从 0 开始连续 | 译码器的 `mode` 端口按 `$clog2(mode 数)` 声明位宽，跳号会让部分分支永远选不到 |
| controller 数量 = PHY lane 总数 / 最小分配颗粒度（仅警告，不拦截） | 多了会有 controller 永远分不到 lane，少了会逼着某个 controller 跨 mode 换最低编号 owned lane，破坏上面的时钟固定约束 |

还有四条不报错、但用之前要知道：

- **不校验 PCIe 宽度合法性**。工具允许任意宽度，x3 / x5 / x6 都能生成；
  真实 PCIe 只允许 2 的幂（x1/x2/x4/x8/x16/x32）。`test/finegrain` 这类配置是用来压生成器的，
  不是真实拓扑。
- **选择方式由 `--dpr` 决定，不是独立参数**。开 DPR 时选择信号经同步器（`sync`），不开时为
  组合直通（`comb`）。不开 DPR 时归属只随 `mode` 变化，因此**只能在受影响的 lane 处于复位时
  切换 `mode`**；在工作中的 lane 上切 `mode`，两路数据可能短暂相或。具体要求是换 owner 的
  group 的新旧两个 controller 的 `rst_n` 同时为低。生成的 RTL 不含断言，这条约定由集成方
  遵守；生成的 testbench 按这个顺序切换，并在违反时判 FAIL。
- **不开 DPR 时 `safe_state` 的交接空窗值不会出现**。组合直通没有全 0 空窗，所以空窗值
  永远观察不到；从未被映射的 controller lane 的 `tie_off` 不受影响。
- **`--dpr` + `pclk_as_phy_input` 需要外部自由运行的 `dpr_pclk`**。生成顶层还会
  输出逐 lane 的 `dpr_rx_clk`；DPR 接管一个 group 时，数据、PCLK 和 RXCLK
  使用同一所有权切换，避免时钟与数据属于不同 owner。

## 1. 项目布局

```
plm/
├─ run.py                   统一 launcher：python run.py generate|validate|-gui ...
├─ pyproject.toml          可编辑安装（pip install -e .）的包定义
├─ src/
│  └─ plm/
│     ├─ core/              核心逻辑：解析、校验、生成、导出，前端/CLI 共用
│     │  ├─ model.py          配置文件解析与校验（Config / Controller / Signal / LaneGroup）
│     │  ├─ paths.py          配置集路径解析（PLM_ROOT/CONFIGS_ROOT/resolve_set/...）
│     │  ├─ verible.py        verible-verilog-format 自动格式化
│     │  ├─ gen_flags.py      GenerationOptions + flag 合法取值和组合规则
│     │  ├─ naming.py         模块名/文件名/宏名前缀
│     │  ├─ plan.py           GenerationPlan：RTL/TB/Report 共用的已解析计划
│     │  ├─ validation.py     format/topology/generation/output 四层校验
│     │  ├─ service.py        共用生成流程：校验、no-op 判断、导出
│     │  ├─ workspace.py      CSV/工作区读写（供 Qt 前端编辑器使用）
│     │  ├─ generator/
│     │  │  ├─ rtl.py           纯文本生成：RTL 各模块的 gen_* 函数
│     │  │  └─ tb.py            纯文本生成：testbench 的 gen_tb()
│     │  ├─ exporter.py       Manifest、自检及 export_all() 事务化写入
│     │  ├─ tb_makefile.mk    仿真用 makefile 模板，生成时复制到 tb/ 下
│     │  └─ common/           手写公共模块，生成时复制到 rtl/common/
│     │      ├─ pipe_lane_sync2.sv
│     │      ├─ pipe_lane_sel_sync.sv
│     │      ├─ pipe_lane_clk_gate.sv
│     │      ├─ pipe_lane_clk_or.sv
│     │      └─ pipe_lane_data_mux.sv
│     ├─ cli/
│     │  └─ main.py           统一 CLI：`plm generate`、`plm validate`
│     ├─ docs/
│     │  ├─ tool_usage.md       本文档
│     │  ├─ qt_frontend_guide.md Qt 前端操作说明
│     │  └─ release_note.md     版本记录与迁移方法
│     └─ frontend/
│        └─ qt/                 桌面前端（PyQt5，`pip install -e ".[qt]"`）
├─ test/
│  └─ <SET>/              一套配置集，SET 是自己起的名字（如 bifurcate）
│     ├─ config/           输入：三个 CSV（见第 2 节）
│     │  ├─ controllers.csv
│     │  ├─ lane_mapping.csv
│     │  ├─ pipe_signals.csv
│     │  └─ gen_flags.txt     Qt 前端记住的生成参数，CLI 不读（见 2.4 节）
│     ├─ rtl/               `plm generate` 的 RTL 输出（生成后出现，不纳入版本管理）
│     │  ├─ src/             生成出来的模块
│     │  ├─ common/           从 plm.core.common 复制过来的公共模块
│     │  ├─ flist.f           文件列表（供 verilator/vcs 用 -f 引用）
│     │  └─ manifest.json     配置/参数 hash 和 RTL 文件 hash
│     └─ tb/                 `plm generate` 的 testbench 输出（生成后出现，不纳入版本管理）
│        ├─ tb_pipe_lane_mapper.sv
│        ├─ makefile          从 plm.core 的 tb_makefile.mk 复制来的（VCS 仿真用）
│        └─ manifest.json     与 RTL 相同的 generation_key 和 TB 文件 hash
└─ Makefile                 批量生成所有配置集（对每套配置集各调用一次 `plm generate`）
```

一个配置集（`test/<SET>/`）只由 `config/` 下的三个 CSV 定义；
`rtl/`、`tb/` 都是生成产物，重新生成前不需要手动清理。统一的 `generate`
会在 staging 中重建生成内容，并在 RTL 与 testbench 都成功后一起更新两边。

## 2. 配置文件格式（`config/` 下三个 CSV）

RTL 和 testbench 两个生成器读的是同一份配置，格式定义如下。文件为 UTF-8 编码，
可以带 BOM（Excel 的“CSV UTF-8”导出）；`ctrl_id`、`max_width`、`width`、`mode` 和
lane 单元格里的数字只接受十进制。

### 2.1 `controllers.csv`：声明每个 controller

```csv
ctrl_id,ctrl_name,max_width
0,CtrlA,12
1,CtrlB,6
2,CtrlC,8
3,CtrlD,3
```

| 列 | 含义 |
|---|---|
| `ctrl_id` | 十进制整数，从 0 开始连续编号，唯一标识一个 controller；行的顺序不要求按编号排列 |
| `ctrl_name` | controller 名字，生成的信号名会用它的小写形式做前缀（如 `CtrlA` → `ctrla_mac2phy`） |
| `max_width` | 这个 controller 真实支持的最大 lane 数（它在 RTL 上的端口数组按这个宽度声明，不做统一 padding） |

名称必须是合法的 SystemVerilog 标识符，不能使用关键字。生成时还会检查展开后的
端口和内部信号是否重名；例如 `PHY`、`CTRL` 会与固定信号冲突，启用 DPR 时
`DPR` 也会冲突。诊断会指出引入冲突的名称。

### 2.2 `lane_mapping.csv`：每个 mode 下每条 PHY lane 分给哪个 controller 的哪条 lane

```csv
mode,lane0,lane1,lane2,lane3,...
0,0-0,0-1,0-2,0-3,...
1,0-0,0-1,0-2,1-0,...
```

- 第一行的 `lane0`、`lane1`... 是列名，列数 = PHY 总 lane 数。
- 每一行是一个 `mode` 取值（必须从 0 开始连续编号）。
- 每个单元格的值是 `<ctrl_id>-<ctrl_lane>`：这条 lane 在这个 mode 下驱动
  哪个 controller（`ctrl_id`）自己的第几条 lane（`ctrl_lane`，从 0 开始，
  不能超过该 controller 的 `max_width`）。
- 同一条 controller lane 不能在同一个 mode 下被多条 PHY lane 同时驱动。

### 2.3 `pipe_signals.csv`：声明每一个要走 NOV 的 PIPE 信号

```csv
signal_name,signal_type,direction,width,safe_state,tie_off
mac_phy_txdata,perlane,mac2phy,32,0,0
mac_phy_txelecidle,perlane,mac2phy,1,1,1
phy_mac_phystatus,perlane,phy2mac,1,0,lane0
phy_mac_messagebus,perlane,phy2mac,8,0x50,0x50
```

| 列 | 含义 |
|---|---|
| `signal_name` | 信号名，会作为对应 SystemVerilog struct 里的字段名 |
| `signal_type` | `perlane`（默认语义，每条 lane 各自独立取值）或 `shared`（同一个 controller 自己的所有 lane 只驱动一个值，比如真实 PIPE 里的 Rate/PowerDown），大小写不敏感。`shared` 只允许用于 `mac2phy`；`phy2mac` 信号必须是 `perlane`。该列只影响 `pipe_lane_mapper_connection.sv` 这个 flat 包装层怎么给 controller 生成端口——mapper 本体始终把信号作为 per-lane struct 字段处理 |
| `direction` | `mac2phy`（controller→PHY）或 `phy2mac`（PHY→controller） |
| `width` | 信号位宽 |
| `safe_state` | 该信号在"没有 owner"时应呈现的值（`pipe_lane_data_mux.safe()` 的取值）。整数字面量：十进制，或带 `0x`、`0b`、`0o` 前缀；不接受下划线分隔和 Verilog 常量写法 |
| `tie_off` | p2m 方向没分到 PHY lane 的那条 controller lane 应该 tie 成什么。要么是字面量 `lane0`（意为"跟随最低编号 lane 的值"），要么是整数字面量（同 `safe_state` 的格式），必须落在 `[0, 2^width)` 范围内 |

两个方向各需要至少一个信号。`signal_name` 不能使用 SystemVerilog 关键字，
也不能使展开后的端口重名，例如 `pclk`、`rst_n`。与架构或 DPR 有关的名称冲突
会按实际生成选项检查。

`safe_state` 与 `tie_off` 是两个方向各自独立生效的机制，不需要
（也不应该假设）两者取值一致：前者用于 Group 的无 owner 空窗，后者用于
某条 controller lane 在当前 mode 没分到 PHY lane 时的固定读值。

`phy_rst_n`/`ctrl_rst_n` 是独立复位端口，不放在这张表里。
仅 serdes 架构还提供 MAC→PHY 方向的独立 `phy_perst_n`/`ctrl_perst_n`：
每个 controller 输入自己的 `<controller>_perst_n`，PHY 侧每 lane 输出一个 `phy_perst_n`。
original_pipe 不生成这组固定端口。
两路分别按照当前 owner 的原始 `dec_tgt` 路由，不等待数据路径的同步选择或
non-overlap 窗口；多路选择为全零时，两路输出均为低电平。
启用 DPR 时使用 `dpr_rst_n`；serdes 还使用独立的 `dpr_perst_n` 作为第二路候选输入。

`pipe_lane_mapper_connection.sv` 是随 `pipe_lane_mapper.sv` 一起自动生成
的一个纯包装模块：把 mapper 本体的两个 struct 数组端口（PHY 侧一个，每个
controller 一个）展开成一个个 flat 信号端口，方便不想处理 SV struct 端口
的下游流程/IP 直接对接。`--bus-type bus`（默认）使用现有二维数组形式，
例如 `logic [W-1:0] phy_data [0:NL-1]`；`--bus-type flat` 使用一维向量，
例如 `logic [NL * W - 1:0] phy_data`。lane 0 位于低位，lane `i` 对应
`phy_data[i * W +: W]`。每个 controller 仍保留自己的命名端口，按该
controller 的 `max_width * W` 展平，不合并 controller 维度。

PHY 侧不管 `signal_type` 是什么，永远保持逐 lane 的独立值；controller
侧 `perlane` 信号使用自己的 `max_width` 条 lane；`shared mac2phy` 信号则收缩成
一个标量输入，由包装层把它复制到 controller 的每条 lane。`phy2mac` 始终
保持 per-lane，不支持 `shared`。DPR 使用相同 bus-type 规则。该选项只改变
connection 的外部端口表示，mapper 内部的 struct 端口、时钟/复位和 testbench 不变。

### 2.4 生成参数不在配置文件里

`--arch` / `--pclk-mode` / `--dpr` / `--bus-type` 在 CLI 中**必须显式从命令行传入**；Qt 从界面构造 GenerationOptions。
CLI 不读任何文件来拿它们。

| 谁来生成 | 参数从哪来 |
|---|---|
| 手敲命令行 | 自己写在命令里 |
| `make <SET>` | 顶层 `Makefile` 里的 `SETFLAGS_<SET>` 变量（见第 5 节） |
| Qt 前端 | Generation 页上的架构、PCLK、Connection 总线类型和 DPR 控件，构造 GenerationOptions 后直接调用核心 |

配置目录下还有个 `gen_flags.txt`，但那是 **Qt 前端自己的记忆**：前端保存时写、
打开 workspace 时读回来恢复上次的选择。CLI 不看它，`make` 也不看它，
所以手敲命令行或跑 `make` 时改这个文件没有任何效果。

不传就是 CLI 默认值：`--arch original_pipe --pclk-mode pclk_as_phy_output
--bus-type bus`，不开 dpr。`--arch` 和 `--pclk-mode` 只传一个时，另一个自动补全。

## 3. `plm generate`：生成匹配的 RTL 与 testbench

```bash
python -m plm.cli.main generate --config <SET> [其它参数]
plm generate --config <SET> [其它参数]
```

| 参数 | 默认值 | 说明 |
|---|---|---|
| `--config SET` | 无（必填） | 配置集名字或路径 |
| `--arch {original_pipe,serdes}` | `original_pipe` | PHY 宏类型；只传它时 pclk-mode 自动补全 |
| `--pclk-mode {pclk_as_phy_output,pclk_as_phy_input}` | `pclk_as_phy_output` | PCLK 归属架构；方向名称以 PHY 端口为视角；只传它时 arch 自动补全 |
| `--bus-type {flat,bus}` | `bus` | Connection 信号端口：flat 为一维向量，bus 为二维 lane 数组 |
| `--dpr` | 关闭 | 生成并例化 DPR overlay；同时决定选择方式（开为 sync，关为 comb） |
| `--module-prefix TEXT` | 空 | 给生成的模块名和 package 名加前缀，末尾缺 `_` 时自动补上 |
| `--file-prefix TEXT` | 空 | 给所有 `.sv` 文件名加前缀，末尾缺 `_` 时自动补上 |
| `--macro-prefix TEXT` | 空 | 给生成代码里的宏名（如 `PIPE_USE_ICG_CELL`、`DUMP_FSDB`）加前缀 |
| `--verible-path PATH` | 自动搜索 | SystemVerilog 格式化器 |
| `--verible-flags JSON` | 内置默认值 | 覆盖 Verible 参数 |
| `--quiet` | 关闭 | 不打印拓扑报告 |

同一进程内重复生成时，公共模块会复用成功的 Verible 格式化结果，缓存按
源码、格式化器二进制和有效参数区分，并限制为 32 条、8MiB。使用包装脚本
时不启用此缓存；可通过 `--verible-path` 或 Qt 设置直接指定格式化器可执行文件。

两种 `pclk-mode` 的区别：

| 模式 | PCLK 主路径 | 返回/反馈路径 | DPR |
|---|---|---|---|
| `pclk_as_phy_output` | PHY 的 `phy_pclk_out[]` 经 Mapper 选为 controller 的标量 `ctrl_pclk` | 选出的时钟回灌到当前 owner 的 `phy_pclk_in[]` | Mapper 从当前 mask 中最低编号 lane 的 PHY PCLK 派生 `dpr_pclk` |
| `pclk_as_phy_input` | controller 的逐 lane `{c}_pclk[]` 经 Mapper 送到 `phy_pclk[]` | PHY 的逐 lane `rx_clk[]` 经 Mapper 送回 `{c}_rx_clk[]` | 外部必须提供自由运行的 `dpr_pclk`，Mapper 输出 `dpr_rx_clk[]` |

因此，前者主要按 Group 选择时钟；后者的 PCLK 和返回的 RXCLK 都必须按
物理 lane 独立路由和同步。两种模式生成的端口不兼容，必须与实际 PHY 宏
接口一致。

生成器先建立统一的 `GenerationPlan`，让 RTL、TB 和 Report 使用同一份已解析
拓扑；随后在 workspace 内建立临时 staging 目录，同时生成 `rtl/` 和 `tb/`。生成完成后
写入两份 Manifest，并检查文件列表、hash、顶层模块、NL/NC 宽度和模板残留。
全部通过后才替换旧输出；生成或自检任意一步失败，旧的两套输出都保持不变。
如果现有两份 Manifest 的 `generation_key` 匹配且所有文件 hash 均通过自检，
本次操作会报告输出已是最新并跳过写盘；配置、参数或文件内容有任何变化都会重新生成。

错误按 `[format]`、`[topology]`、`[generation]`、`[output]` 分层报告。不拦截生成的
提示（目前只有 controller 数量与最小颗粒度不对齐）作为警告列在报告开头的
`Warnings` 段；`--quiet` 时改为打到 stderr。

## 4. `plm validate`

`plm validate --config <SET>` 只解析并校验配置，不写任何文件。校验通过会
打印配置报告；失败时打印所有校验错误并以非零状态退出。

## 5. 用顶层 `Makefile` 批量生成

顶层 `Makefile` 对 `test/` 下每个配置集执行一次 `plm generate`。

| 命令 | 作用 |
|---|---|
| `make` / `make all` | 生成所有配置集 |
| `make -k` | 出错后继续处理其余配置集 |
| `make <SET>` | 生成一套配置，如 `make bifurcate` |
| `make list` | 列出参与生成的配置集 |
| `make clean` | 清理所有配置集的生成物 |
| `make clean-<SET>` | 清理指定配置集 |

`GENFLAGS` 追加到本次 make 涉及的每一个 `plm generate` 命令；
`SETFLAGS_<SET>` 保存某套样例所需的非默认参数。

## 6. 仿真

`plm generate` 生成 testbench 时会把 `plm.core` 的 `tb_makefile.mk` 复制成
每个配置集的 `tb/makefile`（VCS + Verdi 流程）：

```bash
cd test/<SET>/tb
make compile   # 到 ../rtl 下用 -f flist.f 编译，产物/日志回写到 tb/
make run       # 跑仿真，日志写到 tb/sim.log
make verdi     # 打开 Verdi，加载 RTL 源码树和波形（waves.fsdb）
make clean     # 清掉编译/仿真产物
make           # 等价于 compile + run
```

`rtl/` 和 `tb/` 始终来自同一次生成，不需要人工保持参数一致。

编译时会自动打开 `+define+DUMP_FSDB`，testbench 里对应写出
`waves.fsdb`。

如果本地没有 VCS，只想用 verilator 做功能仿真，可以在
`test/<SET>/rtl` 目录下自行调用：

```bash
verilator --binary -f flist.f ../tb/tb_pipe_lane_mapper.sv --top-module tb_pipe_lane_mapper
```

生成的可执行文件位于 `obj_dir/` 下，仿真通过时 testbench 会打印
`TB_RESULT: PASS`，否则打印 `TB_RESULT: FAIL (N errors)` 并给出
`err_count`。

## 7. 生成时的终端输出

不加 `--quiet` 时，`plm generate` 会依次打印：

1. 用到的配置目录以及 RTL、TB 输出目录；
2. 自己生成的每个文件的路径；
3. `Config.report()` 给出的配置概览，包括：
   - 警告（如果有），列在最前面；
   - 各 lane group 的分组结果、每个 mode 下的 owner、是否需要 NOV；
   - 每个 controller 的工作时钟来源（各 mode 下取自哪条 lane）与
     候选数；
   - 每个信号的 `safe_state` 取值；
   - 每一对 mode 切换会影响哪些 group、哪些 group 不受影响。

配置报告只打印一次；`--quiet` 时不打印。

配置不满足 `Config.validate()` 里的任何一条硬性检查时，生成会直接
报错退出，不会写出任何文件；主要拓扑限制及其原因见第 0.6 节。
