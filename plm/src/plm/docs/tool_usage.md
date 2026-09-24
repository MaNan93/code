# PIPE Lane Mapper 生成器使用文档

本文档说明如何用统一的 `plm` 命令行工具，从配置文件生成 PIPE lane mapper
的 RTL 和 testbench：项目布局、配置文件格式、命令行参数、常用工作流。

**最快上手**：仓库根目录下有一个 `run.py` launcher 脚本，直接用它跑，
不需要先 `pip install -e .`（它自己会把 `src/` 加进 `sys.path`）：

```bash
python run.py generate rtl --config <SET>
python run.py generate tb  --config <SET>
python run.py generate all --config <SET>
python run.py validate     --config <SET>
python run.py -gui            # Qt 桌面前端，需要先 pip install -e ".[qt]"
```

本文档下面用的 `plm generate ...`/`plm validate ...` 命令，等价于
`python run.py generate ...`/`python run.py validate ...`；如果想装成真正的
console-script（这样任何目录下都能直接敲 `plm ...`），在仓库根目录
（`pyproject.toml` 所在目录）跑一次：

```bash
pip install -e .
```

这是一次性的（装成可编辑安装），装完之后 `plm` 包才能被 `python -m
plm.cli.main` 或 `plm` console-script 找到。安装后也可以直接运行 `plm -gui`。

- `plm generate rtl --config <SET>` —— 只生成 RTL（`<SET>/rtl/`）
- `plm generate tb --config <SET>` —— 只生成 testbench（`<SET>/tb/`）
- `plm generate all --config <SET>` —— RTL + testbench 都生成
- `plm validate --config <SET>` —— 只解析+校验配置，不生成任何文件

`generate rtl`/`generate tb` 相互独立，可以分别单独重新生成（比如只改了
`pipe_signals.csv` 的 `tie_off` 列，只需要重新生成 RTL），也可以用
`generate all` 在同一次调用里先后各跑一次。三者共享同一份配置文件解析
逻辑（`plm.core.model`），并且 RTL 和 testbench **都必须用同一个
`--pclk-mode` 值**——testbench 按这个 flag 决定怎么实例化 DUT，跟 RTL
实际生成时用的 `--pclk-mode` 不一致，要么编译不过，要么 testbench 和一份
过期的 RTL 对不上。最省心的做法是用 `generate all`：一次调用里 RTL 和 testbench 用的是同一组
参数，不会传漏。分开跑 `generate rtl` / `generate tb` 时，`--pclk-mode`
（和 `--dpr`）必须自己保证两边一样。

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

生成参数（`--arch` / `--pclk-mode` / `--sel-mode` / `--dpr`）只在命令行上给。
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
- **切换无重叠**。每组一个 `pipe_lane_sel_sync`，保证任何时刻最多一个候选被使能。
- **空窗值正确且无毛刺**。`safe_state` 用极性归一化实现，不是外挂一个"全 0 时选 SAFE"的并联分支
  （那种写法在 sel 落 0 和 `~|sel` 拉高之间有一段全 0 窗口，会产生尖峰）。
- **时钟切换 glitch-free**。所有时钟选择都走 `pipe_lane_clk_gate` + `pipe_lane_clk_or`。
- **配置非法直接报错**。拓扑上做不出正确硬件的配置在生成前就被拒绝，
  不会产出一份能编过、跑起来才错的 RTL。

#### 0.5.1 mode 切换的基本运行规则

mode 切换不是让一条正在传输的 PCIe Link 瞬间换到另一个 controller，也不是
要求整个 mapper 一起停机。系统必须先让 **ownership 将发生变化的 Group 所涉及的
controller** 停止使用对应 PIPE lane；这些 lane 在切换期间的数据没有功能意义，
随后由该 Group 自己完成 break-before-make，等选择、时钟和复位稳定后，新 owner
才能重新启动链路训练。

与此同时，起始 mode 和目标 mode 之间 **owner 没有变化的 Group 是独立的**：

- 它的有效选择保持不变，不进入全 0 handoff 空窗；
- 它的 PCLK/RXCLK 不应停顿，复位不应因其他 Group 切换而改变；
- 它的 M2P/P2M 数据通路保持连续，因此其他已经工作的 PCIe Link 可以继续工作。

换句话说，`mode` 虽然是一个全局输入，但切换动作的最小影响范围是 owner 真正变化的
Group，不是整个 mapper。配置报告中的 `switches` / `unaffected` 列表就是这个边界。

上层还必须保证 `mode` 从一个合法值稳定地更新到另一个合法值，并在整个切换收敛期间
保持不变；不能让多 bit `mode` 在 mapper 输入端出现非法值或组合毛刺。生成器能隔离合法
mode A → mode B 所影响的 Group，但不能从一个不连贯的外部 `mode` 波形推断真实目标。

#### 0.5.2 DPR 屏蔽/解除屏蔽规则

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

下面这些不满足，`validate` 会直接报错：

| 限制 | 原因 |
|---|---|
| controller 的工作时钟必须固定——它在各个 mode 下最低编号的那条 owned lane 不能变 | 工作时钟会变就得上 glitch-free 时钟切换，而那种切换本身也是非重叠的，时钟照样要停，平白多一堆复杂度换不来连续性 |
| 同一条 controller lane 的所有驱动源必须来自同一个组 | 跨组的 sel 位来自互相独立的 NOV，之间没有互锁，可能短暂同时为 1，两条数据通路会被或在一起 |
| 一条 PHY lane 在其 owner 持有它的所有 mode 下，controller lane 下标必须固定 | 生成器对每条 lane 只解析一次下标，下标会动就会在其余 mode 接到错误的 controller lane 上 |
| `mode` 取值必须从 0 开始连续 | 译码器的 `mode` 端口按 `$clog2(mode 数)` 声明位宽，跳号会让部分分支永远选不到 |
| controller 数量 = PHY lane 总数 / 最小分配颗粒度 | 多了会有 controller 永远分不到 lane，少了会逼着某个 controller 跨 mode 换最低编号 owned lane，破坏上面的时钟固定约束 |

还有三条不报错、但用之前要知道：

- **不校验 PCIe 宽度合法性**。工具允许任意宽度，x3 / x5 / x6 都能生成；
  真实 PCIe 只允许 2 的幂（x1/x2/x4/x8/x16/x32）。`test/finegrain` 这类配置是用来压生成器的，
  不是真实拓扑。
- **`--sel-mode comb` 下 `safe_state` / `tie_off` 不会真正出现**。组合直通没有全 0 空窗，
  所以空窗值永远观察不到。只有候选 controller 确实在同一个时钟域才能用 `comb`。
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
│     │  ├─ gen_flags.py      生成 flag 的合法取值表 + arch/pclk-mode 交叉校验
│     │  ├─ workspace.py      CSV/工作区读写（供 Qt 前端编辑器使用）
│     │  ├─ generator/
│     │  │  ├─ rtl.py           纯文本生成：RTL 各模块的 gen_* 函数
│     │  │  └─ tb.py            纯文本生成：testbench 的 gen_tb()
│     │  ├─ exporter.py       文件 I/O 编排：export_rtl()/export_tb()（写 <SET>/rtl|tb/）
│     │  ├─ tb_makefile.mk    仿真用 makefile 模板，export_tb() 生成时复制到 tb/ 下
│     │  └─ common/           手写的公共模块（不是生成出来的），export_rtl() 生成时复制到 rtl/common/
│     │      ├─ pipe_lane_sync2.sv
│     │      ├─ pipe_lane_sel_sync.sv
│     │      ├─ pipe_lane_clk_gate.sv
│     │      ├─ pipe_lane_clk_or.sv
│     │      └─ pipe_lane_data_mux.sv
│     ├─ cli/
│     │  └─ main.py           统一 CLI：`plm generate rtl|tb|all`、`plm validate`
│     └─ frontend/
│        └─ qt/                 桌面前端（PyQt5，`pip install -e ".[qt]"`）
├─ test/
│  └─ <SET>/              一套配置集，SET 是自己起的名字（如 quad）
│     ├─ config/           输入：三个 CSV（见第 2 节）
│     │  ├─ controllers.csv
│     │  ├─ lane_mapping.csv
│     │  ├─ pipe_signals.csv
│     │  └─ gen_flags.txt     Qt 前端记住的生成参数，CLI 不读（见 2.4 节）
│     ├─ rtl/               `plm generate rtl` 的输出（每次生成会被覆盖）
│     │  ├─ src/             生成出来的模块
│     │  ├─ common/           从 plm.core.common 复制过来的公共模块
│     │  └─ flist.f           文件列表（供 verilator/vcs 用 -f 引用）
│     └─ tb/                 `plm generate tb` 的输出
│        ├─ tb_pipe_lane_mapper.sv
│        └─ makefile          从 plm.core 的 tb_makefile.mk 复制来的（VCS 仿真用）
│     └─ docs/
│        ├─ tool_usage.md       本文档
│        └─ qt_frontend_guide.md Qt 前端操作说明
└─ Makefile                 批量生成所有配置集（对每套配置集各调用一次 `plm generate`）
```

一个配置集（`test/<SET>/`）只由 `config/` 下的三个 CSV 定义；
`rtl/`、`tb/` 都是生成产物，重新生成前不需要手动清理：`generate rtl`
会先把 `rtl/common/` 整个清空重建，`rtl/src/`、`flist.f` 按文件名覆盖
写入；`generate tb` 把 `tb/tb_pipe_lane_mapper.sv` 按文件名覆盖写入。

## 2. 配置文件格式（`config/` 下三个 CSV）

两个生成器读的是同一份配置，格式定义如下。

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
| `ctrl_id` | 整数，从 0 开始，唯一标识一个 controller |
| `ctrl_name` | controller 名字，生成的信号名会用它的小写形式做前缀（如 `CtrlA` → `ctrla_mac2phy`） |
| `max_width` | 这个 controller 真实支持的最大 lane 数（它在 RTL 上的端口数组按这个宽度声明，不做统一 padding） |

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
| `safe_state` | 该信号在"没有 owner"时应呈现的值（`pipe_lane_data_mux.safe()` 的取值）。整数字面量，支持 `int(x, 0)` 认得的写法：十进制、`0x..`、`0b..` |
| `tie_off` | p2m 方向没分到 PHY lane 的那条 controller lane 应该 tie 成什么。要么是字面量 `lane0`（意为"跟随最低编号 lane 的值"），要么是整数字面量（同 `safe_state` 的格式），必须落在 `[0, 2^width)` 范围内 |

`safe_state` 与 `tie_off` 是两个方向各自独立生效的机制，不需要
（也不应该假设）两者取值一致：前者用于 Group 的无 owner 空窗，后者用于
某条 controller lane 在当前 mode 没分到 PHY lane 时的固定读值。

复位信号（`phy_rst_n`/`ctrl_rst_n`）是独立端口，不放在这张表里。

`pipe_lane_mapper_connection.sv` 是随 `pipe_lane_mapper.sv` 一起自动生成
的一个纯包装模块：把 mapper 本体的两个 struct 数组端口（PHY 侧一个，每个
controller 一个）展开成一个个 flat 信号端口，方便不想处理 SV struct 端口
的下游流程/IP 直接对接。PHY 侧不管 `signal_type` 是什么，永远是 per-lane
展开（`[NL]` 的 unpacked 数组）；controller 侧 `perlane` 信号同样展开成
该 controller 自己 `max_width` 条 lane 的数组；`shared mac2phy` 信号则收缩成
一个标量输入，由包装层把它复制到 controller 的每条 lane。`phy2mac` 始终
展开为 per-lane 数组，不支持 `shared`。

### 2.4 生成参数不在配置文件里

`--arch` / `--pclk-mode` / `--sel-mode` / `--dpr` 这四个参数**只能在命令行上给**。
CLI 不读任何文件来拿它们。

| 谁来生成 | 参数从哪来 |
|---|---|
| 手敲命令行 | 自己写在命令里 |
| `make <SET>` | 顶层 `Makefile` 里的 `SETFLAGS_<SET>` 变量（见 6.1 节） |
| Qt 前端 | Generation 页上的三个下拉 + dpr 勾选框，点 Generate 时拼进命令行 |

配置目录下还有个 `gen_flags.txt`，但那是 **Qt 前端自己的记忆**：前端保存时写、
打开 workspace 时读回来恢复上次的选择。CLI 不看它，`make` 也不看它，
所以手敲命令行或跑 `make` 时改这个文件没有任何效果。

不传就是 CLI 默认值：`--arch original_pipe --pclk-mode pclk_as_phy_output
--sel-mode sync`，不开 dpr。

## 3. `plm generate rtl`：生成 RTL

```bash
python -m plm.cli.main generate rtl --config <SET> [其它参数]
# 装了包之后，也可以用 console-script：
plm generate rtl --config <SET> [其它参数]
```

| 参数 | 默认值 | 说明 |
|---|---|---|
| `--config SET` | 无（必填） | 配置集名字或路径。先按 `test/<SET>/` 找，找不到再当作直接给的路径（相对/绝对都可）；不给这个参数会列出 `test/` 下已有的配置集名字然后报错退出 |
| `--arch {original_pipe,serdes}` | `original_pipe` | 这套配置集针对哪种 PHY 宏：`original_pipe`（经典 PIPE PHY）只支持 `--pclk-mode pclk_as_phy_output`，`serdes`（SerDes 风格宏）只支持 `--pclk-mode pclk_as_phy_input`。纯粹是跟 `--pclk-mode` 的一致性校验，两者不匹配直接报错退出，不生成任何文件 |
| `--pclk-mode {pclk_as_phy_output,pclk_as_phy_input}` | `pclk_as_phy_output` | 选择哪种 PCLK 归属架构；两者互斥，生成的顶层端口/内部信号完全不同。`output` 模式由 PHY 提供 PCLK，`input` 模式由 controller 提供逐 lane PCLK。**必须和 `--arch`、以及 `generate tb` 用的值一致** |
| `--sel-mode {sync,comb}` | `sync` | 顶层 `pipe_lane_mapper` 的 `SEL_SYNC` 参数取什么默认值（也就是数据路径上 `pipe_lane_sel_sync` 的 `SYNC`）；`comb` 只在候选 controller 真的共享时钟域且 `mode` 无毛刺时才安全。这只是设置默认值——`SEL_SYNC` 仍然是个普通的 RTL 参数，例化时不改代码也能覆盖。只影响 RTL，`generate tb` 没有这个参数。**`--dpr` 打开时必须是 `sync`**（DPR 作为 group 的额外候选分支，跟真实候选共用同一个 `SEL_SYNC`；`comb` 无法保证 DPR 分支和真实候选共享时钟域，`--dpr`+`--sel-mode comb` 会直接报错退出） |
| `--verible-path PATH` | 无 | `verible-verilog-format` 的路径，用来给生成的 `.sv` 文件自动格式化。查找优先级：`--verible-path` 显式指定 > 当前工作目录下同名文件 > `PATH` 环境变量；三处都找不到就跳过格式化（生成物功能不受影响，只是排版保持生成器原样） |
| `--quiet` | 关闭 | 不打印每个文件的生成日志和配置报告（`Config.report()`），只在出错时输出 |

`--config` 之外的所有参数都可以省略，省略即用默认值——不加
`--pclk-mode`/`--sel-mode` 生成的就是原来一直兼容的默认组合。

生成产物固定写到 `<SET>/rtl/`，跟 `--config` 传的是配置集名字还是路径
无关——即使 `--config` 给的是 `test/` 之外的路径，也会在那个路径下
按同样的 `rtl/` 布局写产物。

示例：

```bash
# 默认参数生成 quad 的 RTL
plm generate rtl --config quad

# 生成 maxpclk 的 RTL——这套配置演示的就是另一套时钟架构，
# 所以必须显式传参（见 2.4 节）
plm generate rtl --config maxpclk

# 临时切回默认的 pclk_as_phy_output 试一下：
plm generate rtl --config maxpclk --pclk-mode pclk_as_phy_output

# 切到组合直通的 NOV 同步，且不打印生成日志
plm generate rtl --config quad --sel-mode comb --quiet

# 指定 verible-verilog-format 路径做自动格式化
plm generate rtl --config quad --verible-path /opt/verible/bin/verible-verilog-format
```

## 4. `plm generate tb`：生成 testbench

```bash
python -m plm.cli.main generate tb --config <SET> [其它参数]
plm generate tb --config <SET> [其它参数]
```

| 参数 | 默认值 | 说明 |
|---|---|---|
| `--config SET` | 无（必填） | 同 `generate rtl` 的 `--config`；testbench 固定写到 `<SET>/tb/` |
| `--arch {original_pipe,serdes}` | `original_pipe` | 同 `generate rtl` 的 `--arch`，纯粹是跟 `--pclk-mode` 的一致性校验。**必须和这套配置集的 RTL 是用哪个 `--arch` 生成的一致** |
| `--pclk-mode {pclk_as_phy_output,pclk_as_phy_input}` | `pclk_as_phy_output` | 决定 testbench 怎么实例化 DUT（`pipe_lane_mapper`）的端口列表。**必须和这套配置集的 RTL 是用哪个 `--pclk-mode` 生成的一致** |
| `--verible-path PATH` | 无 | 同 `generate rtl` 的 `--verible-path` |
| `--quiet` | 关闭 | 同 `generate rtl` 的 `--quiet` |

没有 `--sel-mode`：testbench 的 NOV 监控逻辑不区分 `sync`/`comb`，两种
`--sel-mode` 生成出来的 RTL 用同一份 testbench 都能跑。

生成 testbench 的同时，会把 `plm.core` 的 `tb_makefile.mk` 复制成
`<SET>/tb/makefile`（第 6 节仿真要用）。

示例：

```bash
# 默认参数生成 quad 的 testbench
plm generate tb --config quad

# 生成 maxpclk 的 testbench——要和它的 RTL 用同一个 --pclk-mode，
# 分开跑就得自己传对（用 generate all 就不用操心）
plm generate tb --config maxpclk
```

## 5. `plm generate all` / `plm validate`

`plm generate all --config <SET> [其它参数]` 依次跑 `generate rtl` 再
`generate tb`，接受两者参数的并集（`--sel-mode` 只影响 RTL 那一步）。

`plm validate --config <SET>` 只解析 + 校验配置（`Config.validate()`），
不写任何文件——适合在 CI 里快速检查某套配置集本身是否合法，不需要真的
跑一次生成。校验通过会打印 `OK -- config is valid.` 和 `Config.report()`
的配置概览；不通过则打印每一条校验错误并以非零状态退出。

## 6. 用顶层 `Makefile` 批量生成

顶层 `Makefile` 对 `test/` 下每一套配置集重新跑 `plm generate rtl`
和 `plm generate tb`（通过 `python -m plm.cli.main`），用途：脚本/CSV
改完之后一键把所有配置集刷新到最新，避免出现"改了脚本或 CSV，但某套
配置忘了重新生成"的漂移。

| 命令 | 作用 |
|---|---|
| `make` / `make all` | 生成所有配置集的 RTL + testbench，某一个失败就停 |
| `make -k` | 同上，但失败了继续跑完其余的 |
| `make <SET>` | 只生成某一套配置集的 RTL + testbench，如 `make quad` |
| `make rtl-<SET>` | 只重新生成某一套配置集的 RTL，如 `make rtl-quad` |
| `make tb-<SET>` | 只重新生成某一套配置集的 testbench，如 `make tb-quad` |
| `make list` | 列出 `test/` 下识别到的配置集名字 |
| `make clean` | 删掉所有配置集的生成物（`rtl/`、`tb/tb_pipe_lane_mapper.sv`） |
| `make clean-<SET>` | 只删掉某一套配置集的生成物，如 `make clean-quad` |
| `make help` | 打印这份命令/变量说明，附带当前实际识别到的配置集名字 |

`make help` 的输出是英文的：这台机器上 `make.exe`（conda-forge 的 GNU
Make on Windows）在把 `@echo` 里的非 ASCII 字符传给 shell 时会出现乱码
——用一个只有一行 `@echo "中文"` 的最小 Makefile 单独测试过，跟这个
项目本身的内容无关，是工具链的问题。所以 `Makefile` 里所有实际会被
执行的 `@echo` 都改成了英文；文件本身的注释（不会被当命令执行，只是
被人或编辑器读取）不受影响，还是中文。

配置集会被自动发现：只要存在 `test/<name>/config/controllers.csv`，
`<name>` 就会被当作一个配置集，不需要手改 Makefile。

### 6.1 透传参数给两个子命令

这里的变量是**全局的**：适用于这一次 `make` 调用涉及的所有配置集，
用来临时试一个参数、或者需要所有配置集都统一切换某个参数时用。

```bash
make all GENFLAGS="--pclk-mode pclk_as_phy_input"   # 两个子命令都收到
make all RTL_GENFLAGS="--sel-mode comb"               # 只有 generate rtl 收到
```

| 变量 | 传给谁 |
|---|---|
| `GENFLAGS` | `generate rtl` 和 `generate tb` 都会收到 |
| `RTL_GENFLAGS` | 只传给 `generate rtl` |
| `TB_GENFLAGS` | 只传给 `generate tb` |

某个配置集自己固定要用的参数（比如 `maxpclk` 一直都要用
`--pclk-mode pclk_as_phy_input`）写在 `Makefile` 里的 `SETFLAGS_<SET>` 变量上：

```make
SETFLAGS_maxpclk := --arch serdes --pclk-mode pclk_as_phy_input
SETFLAGS_dpr     := --dpr
```

加一套需要非默认参数的配置集时，记得在这里补一行，否则 `make <SET>` 会用
默认参数生成它。上面那三个全局变量追加在 `SETFLAGS_<SET>` 后面，所以可以
临时覆盖。

### 6.2 可覆盖的变量

| 变量 | 默认值 | 说明 |
|---|---|---|
| `PYTHON` | `uv run python` | 用哪个 Python 解释器跑 `plm.cli.main` |
| `GENFLAGS` | 空 | 追加给两个子命令的额外参数（见 6.1 节） |
| `RTL_GENFLAGS` | 空 | 只追加给 `generate rtl` 的额外参数 |
| `TB_GENFLAGS` | 空 | 只追加给 `generate tb` 的额外参数 |

例：`make all PYTHON=/path/to/python3`。

生成物的语法/语义正确性、以及功能正确性都要靠仿真验证（第 7 节）——
`Makefile` 本身不做任何检查，只负责生成。

## 7. 仿真

`generate tb` 生成 testbench 时会把 `plm.core` 的 `tb_makefile.mk` 复制成
每个配置集的 `tb/makefile`（VCS + Verdi 流程）：

```bash
cd test/<SET>/tb
make compile   # 到 ../rtl 下用 -f flist.f 编译，产物/日志回写到 tb/
make run       # 跑仿真，日志写到 tb/sim.log
make verdi     # 打开 Verdi，加载 RTL 源码树和波形（waves.fsdb）
make clean     # 清掉编译/仿真产物
make           # 等价于 compile + run
```

这要求这套配置集的 `rtl/` 已经用 `plm generate rtl`（或顶层 `Makefile`）
生成过，并且和 `tb/` 是用同一个 `--pclk-mode` 生成的。

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

## 8. 生成时的终端输出

不加 `--quiet` 时，`generate rtl`/`generate tb` 都会依次打印：

1. 用到的配置目录、自己的输出目录（`generate rtl` 打印 RTL 目录，
   `generate tb` 打印 TB 目录）；
2. 自己生成的每个文件的路径；
3. `Config.report()` 给出的配置概览，包括：
   - 各 lane group 的分组结果、每个 mode 下的 owner、是否需要 NOV；
   - 每个 controller 的工作时钟来源（各 mode 下取自哪条 lane）与
     候选数；
   - 每个信号的 `safe_state` 取值；
   - 每一对 mode 切换会影响哪些 group、哪些 group 不受影响。

这份配置报告和具体生成 RTL 还是 TB 无关，`generate rtl`/`generate tb`
各自运行时都会打印（`--quiet` 时都不打印）。

配置不满足 `Config.validate()` 里的任何一条硬性检查时，生成会直接
报错退出，不会写出任何文件；主要拓扑限制及其原因见第 0.6 节。
