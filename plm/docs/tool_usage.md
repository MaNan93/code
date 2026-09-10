# PIPE Lane Mapper 生成器使用文档

本文档说明如何用两个独立的命令行工具，从配置文件生成 PIPE lane mapper
的 RTL 和 testbench：项目布局、配置文件格式、命令行参数、常用工作流。

- `tool/plm_gen_rtl.py` —— 只生成 RTL（`<SET>/rtl/`）
- `tool/plm_gen_tb.py` —— 只生成 testbench（`<SET>/tb/`）

两者相互独立，可以分别单独重新生成（比如只改了 `pipe_signals.csv` 的
`tie_off` 列，只需要重新生成 RTL），也可以在同一次工作流里先后各跑一次。
两者共享同一份配置文件解析逻辑（`tool/plm_config.py`），并且**都必须
用同一个 `--pclk-mode` 值**——testbench 按这个 flag 决定怎么实例化
DUT，跟 RTL 实际生成时用的 `--pclk-mode` 不一致，要么编译不过，要么
testbench 和一份过期的 RTL 对不上。把 `--pclk-mode` 写进这套配置集的
`gen_flags.txt`（见 2.4 节）是保证两边一致的推荐做法——两个工具会
自动读到同一个值，不需要在两条命令上分别手动传、也不会有传漏的风险。

架构设计本身（为什么这样设计、各模块的原理）不在本文档范围内，见
[`design_notes.md`](design_notes.md)。

## 1. 项目布局

```
plm/
├─ tool/
│  ├─ plm_gen_rtl.py     RTL 生成器（生成 <SET>/rtl/ 下的一切）
│  ├─ plm_gen_tb.py       testbench 生成器（生成 <SET>/tb/ 下的一切）
│  ├─ plm_common.py       两个生成器共用的基础设施（配置集路径解析、
│  │                       verible-verilog-format 自动格式化）
│  ├─ plm_config.py       配置文件解析与校验（Config / Controller / Signal / LaneGroup）
│  ├─ tb_makefile.mk      仿真用 makefile 模板，plm_gen_tb.py 生成时复制到 tb/ 下
│  └─ common/             手写的公共模块（不是生成出来的），plm_gen_rtl.py 生成时复制到 rtl/common/
│      ├─ pipe_lane_sync2.sv
│      ├─ pipe_lane_sel_sync.sv
│      ├─ pipe_lane_clk_gate.sv
│      ├─ pipe_lane_clk_or.sv
│      └─ pipe_lane_data_mux.sv
├─ configs/
│  └─ <SET>/              一套配置集，SET 是自己起的名字（如 test_quad）
│     ├─ config/           输入：三个 CSV + 一个可选的 flags 文件（见第 2 节）
│     │  ├─ controllers.csv
│     │  ├─ lane_mapping.csv
│     │  ├─ pipe_signals.csv
│     │  └─ gen_flags.txt     可选：这套配置集固定绑定的生成参数
│     ├─ rtl/               plm_gen_rtl.py 的输出（每次生成会被覆盖）
│     │  ├─ src/             生成出来的模块
│     │  ├─ common/           从 tool/common/ 复制过来的公共模块
│     │  └─ flist.f           文件列表（供 verilator/vcs 用 -f 引用）
│     └─ tb/                 plm_gen_tb.py 的输出
│        ├─ tb_pipe_lane_mapper.sv
│        └─ makefile          从 tool/tb_makefile.mk 复制来的（VCS 仿真用）
├─ docs/
│  ├─ design_notes.md      架构设计文档
│  └─ tool_usage.md         本文档
└─ Makefile                 批量生成所有配置集（对每套配置集各调用一次两个工具）
```

一个配置集（`configs/<SET>/`）只由 `config/` 下的三个 CSV 定义；
`rtl/`、`tb/` 都是生成产物，重新生成前不需要手动清理：`plm_gen_rtl.py`
会先把 `rtl/common/` 整个清空重建，`rtl/src/`、`flist.f` 按文件名覆盖
写入；`plm_gen_tb.py` 把 `tb/tb_pipe_lane_mapper.sv` 按文件名覆盖写入。

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
| `max_width` | 这个 controller 真实支持的最大 lane 数（端口数组按这个宽度声明，不做统一 padding） |

### 2.2 `lane_mapping.csv`：每个 mode 下每条 PHY lane 分给哪个 controller 的哪个端口

```csv
mode,lane0,lane1,lane2,lane3,...
0,0-0,0-1,0-2,0-3,...
1,0-0,0-1,0-2,1-0,...
```

- 第一行的 `lane0`、`lane1`... 是列名，列数 = PHY 总 lane 数。
- 每一行是一个 `mode` 取值（必须从 0 开始连续编号）。
- 每个单元格的值是 `<ctrl_id>-<ctrl_lane>`：这条 lane 在这个 mode 下驱动
  哪个 controller（`ctrl_id`）的第几个端口（`ctrl_lane`，从 0 开始，
  不能超过该 controller 的 `max_width`）。
- 同一个 controller 端口不能在同一个 mode 下被多条 lane 同时驱动。

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
| `signal_type` | `perlane`（默认语义，每条 lane 各自独立取值）或 `shared`（同一个 controller 自己的所有 lane 只有一个值，比如真实 PIPE 里的 Rate/PowerDown），大小写不敏感。只影响 `pipe_lane_mapper_connection.sv` 这个 flat 包装层怎么给这个 controller 生成端口——mapper 本体永远把每个信号当成 per-lane 的 struct 字段处理，因为一条 PHY lane 当前属于哪个 controller 本来就是随 mode 变的，跟"这个 controller 自己的 lane 之间是不是共享同一个值"是两回事 |
| `direction` | `mac2phy`（controller→PHY）或 `phy2mac`（PHY→controller） |
| `width` | 信号位宽 |
| `safe_state` | 该信号在"没有 owner"时应呈现的值（`pipe_lane_data_mux.safe()` 的取值）。整数字面量，支持 `int(x, 0)` 认得的写法：十进制、`0x..`、`0b..` |
| `tie_off` | p2m 方向未分到 lane 的端口应该 tie 成什么。要么是字面量 `lane0`（意为"跟随最低编号 lane 的值"），要么是整数字面量（同 `safe_state` 的格式），必须落在 `[0, 2^width)` 范围内 |

`safe_state` 与 `tie_off` 是两个方向各自独立生效的机制，不需要
（也不应该假设）两者取值一致——细节见 design_notes.md 第 3.6 节。

复位信号（`phy_rst_n`/`ctrl_rst_n`）是独立端口，不放在这张表里。

`pipe_lane_mapper_connection.sv` 是随 `pipe_lane_mapper.sv` 一起自动生成
的一个纯包装模块：把 mapper 本体的两个 struct 数组端口（PHY 侧一个，每个
controller 一个）展开成一个个 flat 信号端口，方便不想处理 SV struct 端口
的下游流程/IP 直接对接。PHY 侧不管 `signal_type` 是什么，永远是 per-lane
展开（`[NL]` 的 unpacked 数组）；controller 侧 `perlane` 信号同样展开成
该 controller 自己 `max_width` 条 lane 的数组，`shared` 信号则收缩成一个
标量端口——写方向由这个包装层把标量复制到每条 lane；读方向取 lane0 的值
作为这个标量输出（假定该 controller 自己的所有 lane 在这个信号上本来就
该一致，这个假定不由生成器校验）。

### 2.4 `gen_flags.txt`（可选）：固定这套配置集的生成参数

某套配置集如果本身就是为了演示某个非默认参数（比如 `test_maxpclk` 演示
`--pclk-mode pclk_as_phy_input`），把这个参数写进它自己的
`configs/<SET>/config/gen_flags.txt`，两个生成器都会自动读取——不需要
每次手动在命令行加、也不需要为此去改 Makefile，配置集本身就是自包含的。

```
# configs/test_maxpclk/config/gen_flags.txt
pclk-mode = pclk_as_phy_input
```

格式：每行 `key = value`，`key` 就是某个命令行参数去掉前面 `--` 之后的
名字（比如 `--pclk-mode` 对应 `pclk-mode`）；空行和 `#` 开头的注释会被
忽略。

- **两个工具共用同一个文件**：`plm_gen_rtl.py`/`plm_gen_tb.py` 各自只
  认自己定义过的那些 key，不认识的 key 直接跳过——所以像 `--sel-mode`
  这种只有 RTL 工具认的参数，写在同一个文件里也不会让 `plm_gen_tb.py`
  报错。
- **命令行显式传参优先级更高**：`gen_flags.txt` 里的值相当于这套配置集
  自己的默认值；命令行上再传一次同名参数（不管是手动敲的，还是
  Makefile 的 `GENFLAGS`/`RTL_GENFLAGS`/`TB_GENFLAGS`），会覆盖文件里
  的值。
- 取值仍然会经过正常的参数校验（比如 `--pclk-mode` 的 `choices`），写错
  了会直接报错退出，不会静默生效成别的值。

## 3. `plm_gen_rtl.py`：生成 RTL

```bash
python tool/plm_gen_rtl.py --config <SET> [其它参数]
```

| 参数 | 默认值 | 说明 |
|---|---|---|
| `--config SET` | 无（必填） | 配置集名字或路径。先按 `configs/<SET>/` 找，找不到再当作直接给的路径（相对/绝对都可）；不给这个参数会列出 `configs/` 下已有的配置集名字然后报错退出 |
| `--arch {original_pipe,serdes}` | `original_pipe` | 这套配置集针对哪种 PHY 宏：`original_pipe`（经典 PIPE PHY）只支持 `--pclk-mode pclk_as_phy_output`，`serdes`（SerDes 风格宏）只支持 `--pclk-mode pclk_as_phy_input`。纯粹是跟 `--pclk-mode` 的一致性校验，两者不匹配直接报错退出，不生成任何文件 |
| `--pclk-mode {pclk_as_phy_output,pclk_as_phy_input}` | `pclk_as_phy_output` | 选择哪种 PCLK 归属架构；两者互斥，生成的顶层端口/内部信号完全不同。含义见 design_notes.md 2.1 节。**必须和 `--arch`、以及 `plm_gen_tb.py` 用的值一致** |
| `--sel-mode {sync,comb}` | `sync` | 顶层 `pipe_lane_mapper` 的 `SEL_SYNC` 参数取什么默认值（也就是数据路径上 `pipe_lane_sel_sync` 的 `SYNC`）；`comb` 只在候选 controller 真的共享时钟域时才安全。这只是设置默认值——`SEL_SYNC` 仍然是个普通的 RTL 参数，例化时不改代码也能覆盖。含义见 design_notes.md 2.2 节。只影响 RTL，`plm_gen_tb.py` 没有这个参数。**`--dpr` 打开时必须是 `sync`**（DPR 作为 group 的额外候选分支，跟真实候选共用同一个 `SEL_SYNC`；`comb` 无法保证 DPR 分支和真实候选共享时钟域，`--dpr`+`--sel-mode comb` 会直接报错退出） |
| `--verible-path PATH` | 无 | `verible-verilog-format` 的路径，用来给生成的 `.sv` 文件自动格式化。查找优先级：`--verible-path` 显式指定 > 当前工作目录下同名文件 > `PATH` 环境变量；三处都找不到就跳过格式化（生成物功能不受影响，只是排版保持生成器原样） |
| `--quiet` | 关闭 | 不打印每个文件的生成日志和配置报告（`Config.report()`），只在出错时输出 |

`--config` 之外的所有参数都可以省略，省略即用默认值——不加
`--pclk-mode`/`--sel-mode` 生成的就是原来一直兼容的默认组合。

生成产物固定写到 `<SET>/rtl/`，跟 `--config` 传的是配置集名字还是路径
无关——即使 `--config` 给的是 `configs/` 之外的路径，也会在那个路径下
按同样的 `rtl/` 布局写产物。

示例：

```bash
# 默认参数生成 test_quad 的 RTL
python tool/plm_gen_rtl.py --config test_quad

# 生成 test_maxpclk 的 RTL——不用加 --pclk-mode，它自己的
# config/gen_flags.txt 里已经固定了 pclk_as_phy_input（见 2.4 节）
python tool/plm_gen_rtl.py --config test_maxpclk

# 命令行显式传参会覆盖 gen_flags.txt，临时切回默认的 pclk_as_phy_output 试一下：
python tool/plm_gen_rtl.py --config test_maxpclk --pclk-mode pclk_as_phy_output

# 切到组合直通的 NOV 同步，且不打印生成日志
python tool/plm_gen_rtl.py --config test_quad --sel-mode comb --quiet

# 指定 verible-verilog-format 路径做自动格式化
python tool/plm_gen_rtl.py --config test_quad --verible-path /opt/verible/bin/verible-verilog-format
```

## 4. `plm_gen_tb.py`：生成 testbench

```bash
python tool/plm_gen_tb.py --config <SET> [其它参数]
```

| 参数 | 默认值 | 说明 |
|---|---|---|
| `--config SET` | 无（必填） | 同 `plm_gen_rtl.py` 的 `--config`；testbench 固定写到 `<SET>/tb/` |
| `--arch {original_pipe,serdes}` | `original_pipe` | 同 `plm_gen_rtl.py` 的 `--arch`，纯粹是跟 `--pclk-mode` 的一致性校验。**必须和这套配置集的 RTL 是用哪个 `--arch` 生成的一致** |
| `--pclk-mode {pclk_as_phy_output,pclk_as_phy_input}` | `pclk_as_phy_output` | 决定 testbench 怎么实例化 DUT（`pipe_lane_mapper`）的端口列表。**必须和这套配置集的 RTL 是用哪个 `--pclk-mode` 生成的一致** |
| `--verible-path PATH` | 无 | 同 `plm_gen_rtl.py` 的 `--verible-path` |
| `--quiet` | 关闭 | 同 `plm_gen_rtl.py` 的 `--quiet` |

没有 `--sel-mode`：testbench 的 NOV 监控逻辑不区分 `sync`/`comb`，两种
`--sel-mode` 生成出来的 RTL 用同一份 testbench 都能跑。

生成 testbench 的同时，会把 `tool/tb_makefile.mk` 复制成
`<SET>/tb/makefile`（第 5 节仿真要用）。

示例：

```bash
# 默认参数生成 test_quad 的 testbench
python tool/plm_gen_tb.py --config test_quad

# 生成 test_maxpclk 的 testbench——同一个 gen_flags.txt 两个工具都会读，
# 所以这里也不用加 --pclk-mode，自动和它的 RTL 保持一致
python tool/plm_gen_tb.py --config test_maxpclk
```

## 5. 用顶层 `Makefile` 批量生成

顶层 `Makefile` 对 `configs/` 下每一套配置集重新跑
`tool/plm_gen_rtl.py` 和 `tool/plm_gen_tb.py`，用途：脚本/CSV 改完之后
一键把所有配置集刷新到最新，避免出现"改了脚本或 CSV，但某套配置忘了
重新生成"的漂移。

| 命令 | 作用 |
|---|---|
| `make` / `make all` | 生成所有配置集的 RTL + testbench，某一个失败就停 |
| `make -k` | 同上，但失败了继续跑完其余的 |
| `make <SET>` | 只生成某一套配置集的 RTL + testbench，如 `make test_quad` |
| `make rtl-<SET>` | 只重新生成某一套配置集的 RTL，如 `make rtl-test_quad` |
| `make tb-<SET>` | 只重新生成某一套配置集的 testbench，如 `make tb-test_quad` |
| `make list` | 列出 `configs/` 下识别到的配置集名字 |
| `make clean` | 删掉所有配置集的生成物（`rtl/`、`tb/tb_pipe_lane_mapper.sv`） |
| `make clean-<SET>` | 只删掉某一套配置集的生成物，如 `make clean-test_quad` |
| `make help` | 打印这份命令/变量说明，附带当前实际识别到的配置集名字 |

`make help` 的输出是英文的：这台机器上 `make.exe`（conda-forge 的 GNU
Make on Windows）在把 `@echo` 里的非 ASCII 字符传给 shell 时会出现乱码
——用一个只有一行 `@echo "中文"` 的最小 Makefile 单独测试过，跟这个
项目本身的内容无关，是工具链的问题。所以 `Makefile` 里所有实际会被
执行的 `@echo` 都改成了英文；文件本身的注释（不会被当命令执行，只是
被人或编辑器读取）不受影响，还是中文。

配置集会被自动发现：只要存在 `configs/<name>/config/controllers.csv`，
`<name>` 就会被当作一个配置集，不需要手改 Makefile。

### 5.1 透传参数给两个工具

这里的变量是**全局的**：适用于这一次 `make` 调用涉及的所有配置集，
用来临时试一个参数、或者需要所有配置集都统一切换某个参数时用。

```bash
make all GENFLAGS="--pclk-mode pclk_as_phy_input"   # 两个工具都收到
make all RTL_GENFLAGS="--sel-mode comb"               # 只有 plm_gen_rtl.py 收到
```

| 变量 | 传给谁 |
|---|---|
| `GENFLAGS` | `plm_gen_rtl.py` 和 `plm_gen_tb.py` 都会收到 |
| `RTL_GENFLAGS` | 只传给 `plm_gen_rtl.py` |
| `TB_GENFLAGS` | 只传给 `plm_gen_tb.py` |

如果是某个配置集自己固定要用的参数（比如 `test_maxpclk` 一直都要用
`--pclk-mode pclk_as_phy_input`），不要写在这里——那种情况写进那套
配置集自己的 `config/gen_flags.txt`（见 2.4 节），配置集自己带着走，
不需要碰 `Makefile`。这里的全局变量地位更高：命令行传的值会覆盖任何
配置集自带的 `gen_flags.txt`。

### 5.2 可覆盖的变量

| 变量 | 默认值 | 说明 |
|---|---|---|
| `PYTHON` | `python3` | 用哪个 Python 解释器跑两个生成器 |
| `GENFLAGS` | 空 | 追加给两个工具的额外参数（见 5.1 节） |
| `RTL_GENFLAGS` | 空 | 只追加给 `plm_gen_rtl.py` 的额外参数 |
| `TB_GENFLAGS` | 空 | 只追加给 `plm_gen_tb.py` 的额外参数 |

例：`make all PYTHON=/path/to/python3`。

生成物的语法/语义正确性、以及功能正确性都要靠仿真验证（第 6 节）——
`Makefile` 本身不做任何检查，只负责生成。

## 6. 仿真

`plm_gen_tb.py` 生成 testbench 时会把 `tool/tb_makefile.mk` 复制成每个
配置集的 `tb/makefile`（VCS + Verdi 流程）：

```bash
cd configs/<SET>/tb
make compile   # 到 ../rtl 下用 -f flist.f 编译，产物/日志回写到 tb/
make run       # 跑仿真，日志写到 tb/sim.log
make verdi     # 打开 Verdi，加载 RTL 源码树和波形（waves.fsdb）
make clean     # 清掉编译/仿真产物
make           # 等价于 compile + run
```

这要求这套配置集的 `rtl/` 已经用 `plm_gen_rtl.py`（或顶层 `Makefile`）
生成过，并且和 `tb/` 是用同一个 `--pclk-mode` 生成的。

编译时会自动打开 `+define+DUMP_FSDB`，testbench 里对应写出
`waves.fsdb`。

如果本地没有 VCS，只想用 verilator 做功能仿真，可以在
`configs/<SET>/rtl` 目录下自行调用：

```bash
verilator --binary -f flist.f ../tb/tb_pipe_lane_mapper.sv --top-module tb_pipe_lane_mapper
```

生成的可执行文件位于 `obj_dir/` 下，仿真通过时 testbench 会打印
`TB_RESULT: PASS`，否则打印 `TB_RESULT: FAIL (N errors)` 并给出
`err_count`。

## 7. 生成时的终端输出

不加 `--quiet` 时，两个工具都会依次打印：

1. 用到的配置目录、自己的输出目录（`plm_gen_rtl.py` 打印 RTL 目录，
   `plm_gen_tb.py` 打印 TB 目录）；
2. 自己生成的每个文件的路径；
3. `Config.report()` 给出的配置概览，包括：
   - 各 lane group 的分组结果、每个 mode 下的 owner、是否需要 NOV；
   - 每个 controller 的工作时钟来源（各 mode 下取自哪条 lane）与
     候选数；
   - 每个信号的 `safe_state` 取值；
   - 每一对 mode 切换会影响哪些 group、哪些 group 不受影响。

这份配置报告和具体生成 RTL 还是 TB 无关，两个工具各自运行时都会打印
（`--quiet` 时都不打印）。

配置不满足 `Config.validate()` 里的任何一条硬性检查时，生成会直接
报错退出，不会写出任何文件；各条检查项的目的见 design_notes.md 4.3
节表 1。
