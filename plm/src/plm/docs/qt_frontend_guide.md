# PLM Qt 前端使用指南

Qt 前端编辑真实项目配置，并直接调用共享 PLM 核心生成 RTL 和 testbench。

## 启动与项目管理

在仓库的 `plm/` 目录执行：

```bash
uv sync --extra qt
uv run python run.py -gui
```

安装包含 Qt 依赖的发行包后，也可以使用 `plm-gui` 或 `plm -gui`。
安装包不附带仓库中的示例项目；可从任意位置打开项目或新建项目。

左上方新建入口的菜单提供新建、打开、重新加载。新建时填写项目名并选择父目录；
打开时可以选择项目根目录或其 `config/` 目录。左侧项目菜单支持重命名、置顶、
归档、打开所在文件夹和删除。置顶、归档和最近项目保存在本机 QSettings；
重命名、删除由项目服务修改实际目录。归档与删除后会重新选择可用项目；
没有可用项目时进入空状态。删除只允许带 `.plm-workspace` 标记的工作区，
并需要确认。

有未保存修改时，切换、重新加载、归档当前项目、删除当前项目或关闭窗口会提示
保存、放弃或取消。保存校验失败时保留当前项目和编辑内容。外部程序改动 CSV 或
`gen_flags.txt` 后，保存和生成会要求先重新加载，避免覆盖磁盘上的改动。

## 配置编辑

三个表格对应当前项目的三个 CSV，不使用示例卡片。使用表格工具栏添加行、
删除选中行，直接编辑单元格。编辑会实时校验；错误会标出具体单元格，
保存和生成时会再次执行完整的核心校验。

### Controllers

| 列 | 含义 |
|---|---|
| `ctrl_id` | 从 0 开始的连续整数 |
| `ctrl_name` | 控制器名称 |
| `max_width` | 控制器最多支持的 lane 数 |

### Lane Mapping

`mode` 从 0 开始连续编号；`lane0`、`lane1` 等单元格使用 `<ctrl_id>-<ctrl_lane>`。
例如 `1-0` 表示 controller 1 的 lane 0。单元格编辑器分别选择控制器与其 lane。
顶部 lane 数输入框支持 1–64，不限于 2 的幂。删除 mode 或改变 lane 数后应重新
检查分配关系。

### Pipe Signals

| 列 | 含义 |
|---|---|
| `signal_name` | PIPE 信号名称 |
| `signal_type` | `perlane` 或 `shared`；`shared` 只允许用于 `mac2phy` |
| `direction` | `mac2phy` 或 `phy2mac` |
| `width` | 信号位宽 |
| `safe_state` | 交接窗口中没有 owner 时的安全值，两个方向都生效 |
| `tie_off` | 从未分配到 PHY lane 的 controller lane 的固定值，仅对 `phy2mac` 生效 |

例如 `mac_phy_txelecidle` 的 `safe_state` 通常为 1；
`phy_mac_messagebus` 的 `safe_state` 与 `tie_off` 可以分别设置为 `0x50`。
数值编辑支持十进制、十六进制以及核心支持的 Verilog 常量语法。

## 保存与生成

Generation 页提供以下参数：

| 参数 | 选择与联动 |
|---|---|
| `arch` | 用户选择 `original_pipe` / `serdes` |
| `pclk-mode` | 只读显示，由 `arch` 自动决定：`original_pipe` → `pclk_as_phy_output`，`serdes` → `pclk_as_phy_input` |
| `sel-mode` | `sync` / `comb` |
| `dpr` | 两种 PCLK 模式都支持；启用时自动选择并锁定 `sync` |

启用 DPR 是一次可撤销的编辑。磁盘上已存在的非法参数组合会保留并提示校验错误，
不会在加载时悄悄改写。PHY input 模式的 DPR 使用外部 `dpr_pclk` 输入和逐 lane
`dpr_rx_clk` 输出。

**保存**只校验并写入 `controllers.csv`、`lane_mapping.csv`、`pipe_signals.csv`
和 `gen_flags.txt`。**生成**先保存并使用同一组 `GenerationOptions` 调用核心，
在 staging 中生成并检查整套 RTL/TB，成功后更新输出。失败时保留旧输出；
具体错误与真实生成记录显示在底部日志面板。

`gen_flags.txt` 只供 Qt 前端记住生成选择；CLI 不读取它，CLI 参数需要显式传入。
Verible 设置保存在本机，不写入这个项目文件。

生成状态包括尚未生成、输出已过期、输出已是最新、配置有误、生成中和生成失败。
状态同时检查配置、生成参数、格式化器身份与参数，以及输出文件内容。
单独保存不会让旧输出变成最新；撤销到匹配现有输出的配置会恢复最新状态。
输出被修改、删除或 manifest 损坏后会显示过期；重新生成可修复。
完整且最新的输出会跳过写盘。

输出位于项目根目录的 `rtl/` 与 `tb/`，包括 SystemVerilog、文件列表及
`manifest.json`。RTL 和 TB manifest 的 `generation_key` 相同，确认它们来自
同一配置和参数组合。

## 文件预览

右侧面板列出真实 `rtl/`、`tb/` 文件。选择文件后显示完整只读内容和行号，
长行可横向滚动。Verilog 文件默认启用语法高亮，`{}` 按钮可切换。

- 搜索按钮打开当前文件内搜索，支持向前、向后及循环查找。
- 刷新重新读取磁盘，并尽量保持当前项目中选中的文件。
- 链接按钮复制完整文件路径；更多菜单可复制完整内容。
- 编辑按钮通过 Settings 中配置的编辑器打开文件；文件夹按钮打开所在目录。
- 展开按钮放大预览，再次点击还原；拖拽手柄可调整宽度。

切换项目会清除旧预览。文件无法读取时显示原因，不保留旧文件内容。

## Settings 与 Documentation

Settings 有 General、Appearance、Formatter 三个分页。默认编辑器在 General 中设置。
字体、字号、外部编辑器和 Verible 设置均保存在本机，重启后恢复。
Documentation 内置当前工具说明和本指南，安装包中也可使用。

Formatter 可浏览选择 `verible-verilog-format`，也可自动检测；路径留空时使用
核心的自动查找。参数表可编辑核心支持的对齐、缩进、布尔、整数和字符串参数。
空白参数不传给工具，使用 Verible 自身默认值。

- “项目默认参数”采用核心内置 `DEFAULT_VERIBLE_FLAGS`。
- “使用 Verible 默认参数”清空显式参数，传入空字典。
- 修改后点击“保存设置”才会生效；修改外观不会覆盖未修改的格式化设置。

保存 Formatter 设置会立即重新检查输出状态，下次生成应用新参数。
显式指定的工具不可用时保留生成器原始排版，并在日志中说明。

## 快捷键与常见错误

| 快捷键 | 功能 |
|---|---|
| Ctrl+Z | 撤销配置编辑 |
| Ctrl+Y / Ctrl+Shift+Z | 重做 |
| Ctrl+F | 焦点在预览面板内时打开搜索 |
| Enter / F3 | 下一个匹配，末尾循环 |
| Shift+Enter / Shift+F3 | 上一个匹配，开头循环 |
| Esc | 关闭预览搜索 |

打开、保存、新建通过界面入口操作。

| 错误 | 检查项 |
|---|---|
| mode 不连续 | 改为 0、1、2 等连续编号 |
| ctrl_id 越界 | 控制器编号及 `max_width` |
| 同一 controller lane 被重复驱动 | 当前 mode 下的 lane 分配 |
| 驱动源跨 group | 同一 controller lane 的所有驱动源应在同一组 |
| 同一 PHY lane 在不同 mode 换 controller lane 下标 | 同一 owner 的 lane 下标保持一致 |
| PCLK 候选数大于 1 | 最低编号 owned lane 是否保持一致 |

出现错误时先查看单元格提示和底部日志，再修正配置并重新保存或生成。
