# PLM Qt 前端使用指南

## 标签页说明

### Controllers

定义控制器。

| 列 | 含义 |
|---|---|
| `ctrl_id` | 从 0 开始的整数 |
| `ctrl_name` | 名字（CtrlA, CtrlB 等） |
| `max_width` | 最多支持多少条 lane |

操作：右键菜单增删行，拖动第一列改行顺序，直接编辑单元格。

### Lane Mapping

定义每个 mode 下的 lane 分配。

| 列 | 含义 |
|---|---|
| `mode` | 模式编号（0, 1, 2...） |
| `lane0`、`lane1`... | 格式 `<ctrl_id>-<ctrl_lane>` |

例：
```
mode=0  lane0=0-0  lane1=0-1  lane2=1-0
        ↓          ↓          ↓
        CtrlA[0]   CtrlA[1]   CtrlB[0]
```

操作：右键菜单增删 mode 行（"Insert mode row below" / "Delete this mode row"），
直接编辑单元格。lane 数用这一页顶部的下拉框改（x2/x4/x8/x16/x32），不是右键菜单。

### Pipe Signals

定义 PIPE 信号。

| 列 | 含义 |
|---|---|
| `signal_name` | 信号名 |
| `signal_type` | `perlane` 或 `shared`；`shared` 只允许用于 `mac2phy`，`phy2mac` 必须使用 `perlane` |
| `direction` | `mac2phy` 或 `phy2mac` |
| `width` | 位宽 |
| `safe_state` | 交接窗口里暂时没有 owner 时的值。两个方向都生效 |
| `tie_off` | 任何 mode 都分不到 lane 的那条 controller lane 读到的值。只对 `phy2mac` 生效 |

两列管的是不同的事，别混：`safe_state` 是"这条 lane 有主，只是正在换手"，
`tie_off` 是"这条 controller lane 压根没接过 PHY lane"。

常见值：
- `mac_phy_txelecidle`: safe_state=1（交接时必须是电气空闲）
- `phy_mac_rxelecidle`: safe_state=1
- `phy_mac_messagebus`: safe_state=0x50, tie_off=0x50

操作：右键菜单增删信号，拖动第一列改行顺序。

### Generation

生成参数 + 生成按钮，在同一页。

| 参数 | 可选值 |
|---|---|
| `arch` | `original_pipe` / `serdes` |
| `pclk-mode` | `pclk_as_phy_output` / `pclk_as_phy_input` |
| `sel-mode` | `sync` / `comb`（勾了 dpr 会被锁成 `sync`） |
| `dpr` | 勾选或不勾。两种 PCLK 模式都支持；`pclk_as_phy_input` 会生成外部 `dpr_pclk` 输入和逐 lane `dpr_rx_clk` 输出 |

`arch` 和 `pclk-mode` 互相联动，改一个另一个跟着变。

这四个值保存时写进 `config/gen_flags.txt`，下次打开这个 workspace 会恢复。
这个文件只有本前端读写，命令行的 `plm generate` 不看它——前端是在点按钮时
把它们拼成命令行参数传过去的。

| 按钮 | 功能 |
|---|---|
| Generate | 保存当前编辑、完整校验配置，并使用同一组参数生成 RTL 和 testbench；全部成功后一起更新输出 |

表格编辑时会实时标出常见错误；点击 **Generate** 后仍会执行完整校验。
校验失败时不会写入生成结果，具体原因显示在 LOG 页。输出文件自动写到
`<config_dir>/../rtl/` 和 `<config_dir>/../tb/`。

按钮左侧会显示当前输出状态：编辑后为 `Out of date`，已有输出与当前配置、
参数匹配时为 `Up to date`。点击 Generate 后自动完成校验、保存、生成和预览
刷新，界面只显示 `Ready`、`Out of date`、`Generating`、`Up to date`、
`Generation failed` 五种状态。输出已经完整且最新时，Generate 会直接跳过
写盘并保持 `Up to date`。
RTL 与 TB 各自带一份 `manifest.json`；两份文件的 `generation_key` 相同，
用于确认它们来自同一份配置和同一次参数组合。

> 侧边栏底部那个 **Settings** 按钮是另一回事：它开的是 verible 格式化器的
> 设置对话框，跟上面这四个生成参数无关。

## 操作步骤

1. 侧边栏点 **Open** 选 `test/<SET>/config/` 的上一级目录；或点 **New**，填写
   Project name，并在 Location 中输入/浏览选择任意父目录后新建
2. Controllers tab：填 controller 信息
3. Lane Mapping tab：填 mode 和 lane 分配
4. Pipe Signals tab：用默认值或自己改
5. Generation tab：选生成参数（不改就用默认），点 **Generate**；程序会自动校验并保存当前编辑，再同时生成 RTL 和 testbench、刷新预览

只需要保存配置、不生成RTL时，才单独使用侧边栏的 **Save**。

## 常见操作

**改 lane 数**：Lane Mapping tab 顶部的下拉框。列表里只有 2 的幂，
但工具本身支持任意宽度——从磁盘读进来的其它值会照常显示，只是下拉框不主动提供。

**改 mode 数**：Lane Mapping tab，右键增删 mode 行。

**改 signal 值**：Pipe Signals tab，编辑对应行。

**切换时钟架构**：Generation tab 改 pclk-mode，重新生成。

**打开工作区所在文件夹**：左侧 Recent 列表里那一项的三个点 → Reveal in Explorer。

## 生成文件预览

右侧浮动面板列出当前项目 `rtl/` 和 `tb/` 下的真实文件。顶部选择文件后，
内容区显示完整只读文本和行号，长行可以横向滚动。`.v`、`.sv`、`.vh`、
`.svh` 文件默认启用 Verilog 语法高亮；点击工具栏的 `{}` 图标可以关闭或恢复。

- 搜索图标打开当前文件内搜索，支持向前、向后查找，并在文件末尾循环。
- 刷新会重新读取磁盘内容，并尽量保留同一项目中选中的文件；切换项目会清除旧预览。
- 链接图标复制当前文件的完整路径，“更多”菜单可以复制完整内容。
- 编辑图标使用 Settings 中配置的外部编辑器打开当前文件；文件夹图标打开该文件所在目录。
- 展开图标放大预览，再次点击还原；侧边拖拽手柄仍可调整面板宽度。

预览本身不能修改文件。文件被删除或无法按 UTF-8 读取时会清空内容并显示提示，
可刷新列表或选择其他文件。

## 快捷键

| 快捷键 | 功能 |
|---|---|
| Ctrl+Z | 撤销 |
| Ctrl+Y / Ctrl+Shift+Z | 重做 |
| Ctrl+F | 焦点在预览面板内时，打开当前文件搜索 |
| Enter / F3 | 预览搜索：跳下一个，末尾循环 |
| Shift+Enter / Shift+F3 | 预览搜索：跳上一个，开头循环 |
| Esc | 预览搜索：关掉搜索框 |

打开 / 保存 / 新建没有快捷键，用侧边栏按钮。

## 错误处理

| 错误 | 原因 | 修复 |
|---|---|---|
| mode 不连续 | mode 有跳号 | 改成 0,1,2,3... |
| ctrl_id 越界 | 引用不存在的 controller | 检查 ctrl_id 和 max_width |
| 同一条 controller lane 被多条 PHY lane 驱动 | lane 分配冲突 | 改 lane 分配 |
| 驱动源跨 group | CtrlB[0] 来自不同 lane group | 改分配让同一条 controller lane 的所有驱动源同组 |
| 一条 PHY lane 跨 mode 换了 controller lane 下标 | 同一个 owner 在不同 mode 下把这条 lane 编到了不同位置 | 改成每个 mode 下都是同一个下标 |
| pclk 候选数 > 1 | controller 的工作时钟会变 | 确保最低编号 owned lane 不变 |

生成没有输出：检查工作区路径，并在 LOG 页查看校验或生成错误。

## 文件位置

配置文件：
```
<config_dir>/
  ├─ controllers.csv
  ├─ lane_mapping.csv
  ├─ pipe_signals.csv
  └─ gen_flags.txt
```

生成文件：
```
<config_dir>/../
  ├─ rtl/src/*.sv
  └─ tb/tb_pipe_lane_mapper.sv
```

