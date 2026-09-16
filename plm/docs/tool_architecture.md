# plm 工具本身的架构决策记录

这份文档跟 [`design_notes.md`](design_notes.md) 不是一回事：那份讲的是
PIPE lane mapper **这套 RTL 的设计**；这份讲的是**生成/编辑这套 RTL 的
Python 工具本身**——`src/plm/` 这个包为什么长这样、几次改动背后的
取舍，是什么原因、放弃了什么选项。

写这份文档的直接原因：这些决策大多只存在于开发过程中的讨论里，没有
提交记录能查（写这份文档的时候，下面第 1、2 节说的改动都还没有
`git commit`），一旦对话历史被压缩或者开新会话，这些"为什么这么做"
的原因就没地方找了，只有"现在长这样"这个结果留在代码里，原因本身会
丢失。所以把它们落到文档里，而不是只指望聊天记录。

**这份文档记录的是决策发生时的状态，不保证是这个仓库现在的状态**——
工具本身之后可能又被继续改动（比如第 3 节提到的、Web 前端后来被整个
移除，这份文档写的时候还在）。想知道"现在到底长什么样"，永远以
`git log`、当前代码、[`CLAUDE.md`](../CLAUDE.md) 为准；这份文档只负责
"当初为什么这么决定"。

## 1. 从三个平铺脚本重构成可安装包

**背景**：最早 `tool/` 目录下是三个互相用 `sys.path.insert` 拼起来的
平铺脚本（`plm_gen_rtl.py`/`plm_gen_tb.py`/`plm_config.py`/
`plm_common.py`），外加一个 Tkinter 桌面前端（`plmConsultant.py`，
已确认没有功能依赖后直接删除）和 Web/Qt 两个前端。用户先要求按
"前端/后端"分开目录结构（`tool/backend/` + `tool/frontend/{web,qt}/`，
纯 `git mv`，没有内部重组）；之后给出了一张架构图（CLI 在最上层被
AI/Shell/CI 调用，Web 和 Qt5 是两个平级前端，都连到一个包含
parser/model/validator/generator/exporter 的 CORE，CORE 再产出
Generated Code）和一份 `pyproject.toml` + `src/` 布局的示例，要求照着
做一次更深的重构。

**明确问过用户、用户给出的三个决定**（这三条是后面所有拆分方式的
依据，不是我自己拍的）：
- CORE 内部具体怎么切分模块——用户说"你根据你对这个工具的理解划分"，
  不必照抄示例里的 parser/model/validator 这种切法。
- 要不要做统一 CLI——用户说"你决定"。
- 要不要做成真正可安装的包（`pyproject.toml` + `src/` 布局）——用户
  明确要，"加 pyproject.toml + src/ 布局"。

**`core/` 内部实际的切法**（自己的理解，不是示例的硬套）：
`model.py`（Controller/Signal/LaneGroup/Config，解析+校验+report，保持
一个文件，因为原文件内部已经组织得足够好，硬拆 parser/validator 没有
额外收益）、`paths.py`（配置集路径解析）、`verible.py`
（verible-verilog-format 调用）、`gen_flags.py`（生成 flag 的取值表，
CLI 默认值和前端编辑器两种用法故意放一个文件，因为操作的是同一份
文件格式，按"操作对象"分而不是按"谁在用"分更好找）、`workspace.py`
（CSV/工作区读写，确认过生成流程本身不用，只有前端编辑器用，但依然
算 core 而不是 frontend，因为"共享的非 UI 逻辑"是这里 core 的定义，
不是"只有生成流程用的才算 core"）、`generator/{rtl,tb}.py`（纯文本
生成，零文件 I/O）、`exporter.py`（**这次重构真正的收益所在**：把两个
老脚本 `main()` 里的文件 I/O 编排单独拆出来，不带 argparse/sys.exit，
`export_rtl()`/`export_tb()` 变成任何调用方——CLI、以后可能的测试、
别的脚本——都能直接拿来用的纯函数）。

**统一 CLI 的设计**：`plm generate rtl|tb|all --config X [...]` +
`plm validate --config X`，纯 stdlib argparse，没引入 click/typer——
这个工具依赖本来就只有 stdlib + Flask + PyQt5，为一个 CLI 单独加一个新
依赖不值得。旧的 `plm_gen_rtl.py`/`plm_gen_tb.py` 这两个脚本名**直接
retire，没做向后兼容 shim**——确认过仓库外没有任何东西依赖这两个脚本名
（只有 Makefile、两个前端、`tool_usage.md` 引用，且都在同一次改动里
一起更新了）。两个前端和 Makefile 改成用
`[sys.executable, "-m", "plm.cli.main", "generate", ...]` 调用，
**不是**用装好之后的 `plm` console-script 名字——这样只依赖解释器能
`import plm`，不依赖 venv 的 Scripts 目录在不在 PATH 上（后来证明这个
顾虑是对的，见下面第 4 节 `pip install -e .` 装完之后 Scripts 目录不在
PATH 上的实际警告）。

**明确告诉用户、用户接受的权衡**：装成可安装包之后，`pip install -e .`
从"可选"变成了"必须做一次"的前提——原来是零配置、直接 `python
tool/xxx.py` 就能跑。这是用户自己要求"真正的包"之后必然带来的代价，
当时就摊开说清楚了，不是事后才发现的副作用。

## 2. `configs/` 改名 `test/`，去掉每个子目录的 `test_` 前缀

第一步很直接：用户说"configs 这个文件夹改成 test 吧"，`git mv configs
test`，然后把 `CONFIGS_ROOT`、Makefile、文档里所有 `configs/` 的路径
引用同步改掉（注意：`CONFIGS_ROOT`/`--config`/`list_configs()` 这些
**代码里的术语名字没有改**，只是磁盘上的目录名从 `configs` 换成了
`test`——两者是分开的决定，见下一段）。

紧接着用户问了一个后续问题："每个 test_* 我们应该叫什么名字合适？叫
project 吗？"——这其实是两件独立的事，当时用问题拆开确认：

- **子目录要不要去掉 `test_` 前缀**（`test/test_quad` 读起来重复）——
  用户选"去掉前缀"，于是 `test_quad`→`quad`、`test_maxpclk`→`maxpclk`
  等，`git mv` 逐个改。
- **代码里"配置集"这个概念要不要统一改名叫 `project`**（`--config`→
  `--project`、`list_configs`→`list_projects`、`CONFIGS_ROOT`→
  `PROJECTS_ROOT` 这种大范围改名）——用户选**不改**，理由是这套术语
  本身没有歧义或错误，只是目录换了名字不代表概念也要跟着换名字，避免
  没必要的大范围改动。

**这里有个已知的滞后**：`design_notes.md` 第 1.3 节末尾举例提到的
`test_quad`/`test_bifurcate`/`test_finegrain` 这几个名字，是改名
**之前**写的，现在已经不对了（应该是 `quad`/`bifurcate`/
`finegrain`）——写这份文档的时候还没去改那处，记在这里免得又被
忘掉。

## 3. 统一入口脚本：从 `plm`（无后缀）到 `run.py`

用户嫌 `python -m plm.cli.main generate rtl --config X` 这种深路径调用
麻烦，要求"在 plm/ 下生成一个文件做工具的统一入口"。第一版做了一个
仓库根目录下、**无扩展名**、带 shebang 的文件，名字就叫 `plm`——
选择无扩展名是为了避开一个真实的坑：如果这个文件叫 `plm.py`，摆在
仓库根目录，那么从仓库根目录执行 `python -m plm.cli.main ...`
时（Makefile、两个前端都是这么调用的），Python 会把当前目录插进
`sys.path[0]`，`import plm` 就会先撞到这个 `plm.py`（一个普通模块，
没有 `cli` 子模块），而不是 `src/plm` 那个真正的包，直接炸掉——无
扩展名的文件不会被当成 `plm` 模块匹配，不会有这个问题。

但用户反馈"这个 plm 入口方案不太行"——问清楚之后，问题是**无扩展名
文件在 PowerShell 下不好直接跑**（必须手动加 `python` 前缀，跟直接用
`python -m ...` 比没省多少事，Windows 下也没法双击/关联）。给了两个
选项：Windows 批处理脚本（`.cmd`，PowerShell 里能 `.\plm.cmd` 直接跑但
只能 Windows 用）还是换一个不重名的 `.py` 文件。用户选了后者——于是
改成 `run.py`：还是自己往 `sys.path` 插入 `src/`（不依赖
`pip install -e .` 也能跑 `generate`/`validate`），但因为不叫
`plm.py`，不会有上面说的那个 `-m` 调用撞名问题。

`run.py` 最初还想承担"一个文件调 CLI + Web + Qt 三个前端"的野心（分发
`web`/`qt` 两个子命令），但这部分在这轮会话之外被用户自己简化掉了——
见第 4 节。

## 4. 会话之外发生、我这边没有做的改动（如实记录，避免下次会话误以为是我做的）

在做完上面三件事之后，中间隔了几天（本文档写于 2026-09-15，上面三件
事发生在 2026-09-11 前后），用户在这轮会话之外自己继续开发了这个
项目，回来之后我发现的、跟我记忆对不上的地方：

- **Web 前端被整个移除**：`src/plm/frontend/web/` 目录已经不存在，
  `pyproject.toml` 里 `web` 这个 optional-dependency 和 `plm-web`
  这个 console-script 都被删掉了。用户确认："我现在确实是只用 -gui
  来打开唯一的 qt 前端了"——Web 前端不再维护，Qt 桌面前端是唯一的
  GUI。
- **`run.py` 被简化**：`web`/`qt` 两个子命令分发被去掉，改成单一的
  `-gui` 参数直接启动 Qt 前端（跟上面这条一致，因为只剩一个前端，不
  需要再分发了）——这个 `-gui` 分支是我在这轮会话里帮着补上的（发现
  docstring 提到 `-gui` 但代码没实现）。
- **多了几个我没参与建过的文件/目录**：`src/plm/docs/tool_usage.md`
  （包内自带一份文档拷贝）、`src/plm/core/config/pipe_signals.csv`
  （内置默认配置）、`src/plm/frontend/qt/assets/`（图标字体等资源，
  含 `code_highlighter.py`、`sap_icons.py` 两个新 widget 文件）。这些
  东西具体做什么、为什么这么组织，我目前没有第一手信息，只是如实
  记下"存在、我没参与"，避免下次会话把这些当成我自己的历史决策去
  解释。
- **Python 环境改用 `uv` 管理**：`CLAUDE.md` 新增规定，仓库根目录跑
  `uv venv --python 3.12` 建 `.venv`，此后所有命令用 `uv run`，不再
  用裸 `python`。这轮会话里已经按这个约定把 `.venv` 建好并验证过
  `uv run python run.py ...` 可以正常工作。
- 同一批检查中发现 `test/quad` 这套示例配置目前校验不通过
  （`CtrlB[0]` 的驱动源跨了两个 lane group），还没确认这是用户正在
  改到一半的中间状态，还是需要修的问题——**没有动这份配置数据**，
  留给用户自己确认。

## 5. 去掉 `gen_flags.txt`：生成参数一律走命令行

**决定**：删掉 CLI 对 `gen_flags.txt` 的解析。`arch` / `pclk-mode` / `sel-mode` / `dpr`
四个参数到达生成器的路径只剩一条：命令行。

文件本身保留，但降级成 Qt 前端自己的记忆——只有前端读写它，用来在重开
workspace 时恢复上次的选择；前端生成时仍然把 flag 拼在命令行上。

**原来是怎么回事**：一套配置集可以在自己的 `config/gen_flags.txt` 里固定这几个
参数，`plm generate rtl/tb/all` 启动时会先做一次"丢弃式"预解析拿到 `--config`，
读出那个文件，再把里面的键值翻译成 argv token 塞在真正的 argv 前面，当作
argparse 的默认值。好处是配置集自包含——`make maxpclk` 不用记得加
`--pclk-mode pclk_as_phy_input`。

**为什么去掉**：

1. 以后主要用 Qt 前端，而前端本来就把这四个值捧在手里（Generation 页的三个
   下拉 + 一个勾选框），再绕一圈写文件、让 CLI 读回来没有意义。
2. 那套预解析机制本身不干净：一次丢弃式 `parse_known_args`、遍历 argparse 的
   私有属性 `ap._actions` 来判断哪个 key 是本子命令认识的、不认识的 key 静默丢弃。
3. 同一个文件曾经有两个读法。`load_set_flags`（CLI）原样透传 `arch`，
   `read_gen_flags`（前端）却完全由 `pclk-mode` 反推、无视文件里的 `arch` 行——
   一个只写了 `arch = serdes` 的文件会让 CLI 直接报错退出，前端却显示"未设置"。

**代价，以及怎么补的**：

| 丢掉的东西 | 补法 |
|---|---|
| 配置集自包含（`make maxpclk` 自动带对参数） | 顶层 Makefile 里的 `SETFLAGS_<SET>` 变量 |
| 回归测试知道每套样例该用什么 flag | `tests/test_core.py` 的 `SAMPLE_GEN_FLAGS` 表 |
| Qt 里重开一个 workspace 能记住上次的选择 | 保留 `config/gen_flags.txt`，但读写方换成**只有 Qt 前端**（`plm.core.workspace.read_gen_flags`/`write_gen_flags`）。CLI 完全不看这个文件——前端和别的调用方一样，把 flag 拼在命令行上。 |

这件事现在写在三个地方，各有各的消费者：`Makefile` 的 `SETFLAGS_<SET>`（给 `make`）、
`tests/test_core.py` 的 `SAMPLE_GEN_FLAGS`（给回归测试）、
`test/<SET>/config/gen_flags.txt`（给 Qt 前端）。
`test_sample_gen_flags_match_the_qt_workspace_files` 把后两者钉死，
`test_samples_exercise_both_clock_architectures_and_dpr` 守住
"至少还有样例覆盖 `pclk_as_phy_input` 和 `--dpr`"这条底线；Makefile 那份只能靠人眼。

**连带改动**：

- `plm.core.gen_flags` 从"gen_flags.txt 读写"缩成"生成 flag 的取值表 +
  `validate_arch()`"，不再有任何文件 I/O。
- `existing_line_ending()` 和 `read_gen_flags()`/`write_gen_flags()` 都搬到
  `plm.core.workspace`——工作区文件的读写归它一家，`gen_flags.py` 只剩取值表。
- `workspace_content()` / `save_workspace_content()` 的 payload 里仍然有 `gen_flags` 键，
  只是这个键现在只在前端和磁盘之间往返，不再喂给 CLI。
- Qt 的 `_run_tool` 现在自己拼 `--arch/--pclk-mode/--sel-mode/--dpr`
  （`_gen_flag_args()`），`generate tb` 那一路不传 `--sel-mode`，因为那个子命令没有这个选项。
