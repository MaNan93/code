# PLM 版本更新记录

本文件统一记录版本与同版本内的修订，按发布时间从新到旧排列。
后续版本更新继续修改本文件，记录改动、兼容性/迁移方法及验证结果。

## 3.0.5（2026-10-16 更新）

### 2026-10-16：方案逐项收尾与 CI 修复（源码更新）

- 文档标题采用 18/15/14px 层次，增加品牌色装饰条和原生可选择文本下方的圆角
  深色代码块；Diff 删除区域改为更淡底色，保留独立行号区及前景对比度。
- 收起日志增加清空按钮，清空同时重置状态摘要；数据行与表头补上细分割线。
- 主按钮补齐可读的按压色，并修复禁用后悬停仍被主色覆盖的问题。
- 未安装 Verible 的机器也可生成全部界面截图，验证缺失工具提示和空结果。
- 修复远端 RTL 仿真 CI 的 `sample_data` 导入失败，并补跑独立 PERST 路由仿真。
  回归矩阵增加 macOS / Python 3.12，三平台输出四档缩放报告与截图，截图任务上传完整图库。

验证：Windows 全量 391 项，389 通过、2 项可选仿真跳过；文档装饰 2 项、
工作区交互 12 项专项通过；Windows 与 WSL Linux
四档缩放各 176 个页面状态通过，Linux 无 Verible 环境的完整 43 张截图生成通过。
逐项实施记录见 `docs/UI_REDESIGN_CHECKLIST.md`，远端各任务结果见相应提交的 Actions。
主题切换完整帧中位数：主界面 89ms、参数页 175ms、预览页 197ms、文档 153ms。
配置无需迁移，未发布新安装包。

### 2026-10-15：日志动画与真实格式化预览（源码更新）

- 日志展开/收起增加 200ms 动画，可连续点击反向切换，保留高度记忆与失败时自动展开。
- Formatter 增加可编辑源码与结果双栏预览，后台使用当前未保存路径和参数调用真实
  Verible；250ms 防抖并丢弃旧结果，切走停止排队，不自动保存设置或写入项目。
- 交互预览限制 64 KiB、超时 3 秒；缺失工具、无效参数、语法错误或异常输出会清空
  旧结果并提示原因。生成器继续沿用原有格式化超时和失败回退行为，无需迁移。
- 保存时自动定位被分类或预览页隐藏的无效整数参数；截图脚本增加深浅主题预览页。
- 窗口退出子进程测试改用当前 Python 解释器，消除测试对本机 `uv` 命令的依赖。

验证：Windows 全量 387 项测试，385 通过、2 项可选 Verilator 仿真跳过；
100%、125%、150%、200% 缩放共 176 个页面状态检查通过，43 张页面截图检查通过。
WSL Ubuntu 的 Qt offscreen 全量 387 项测试同样 385 通过、2 跳过，四档缩放的
176 个页面状态通过；Linux 抓图借用 Windows 字体，未做 macOS 原生验证。
本机 Verible 验证未保存缩进参数确实改变输出、无效 SV 返回错误。六次主题切换完整帧
中位数：主界面 101 ms、参数页 173 ms、预览页 186 ms、文档 145 ms。
详见仓库 `docs/ui_polish_validation_2026-10-15.md`。本次提交源码，未构建发布安装包。

### 2026-10-15：工作区布局与编辑入口调整（源码更新）

- 日志默认收起为 34px 状态条，生成开始或失败时展开；再次展开恢复上次调整的高度。
- 增加项目路径与保存状态，配置标签改为下划线；Controller/Signals 增加行操作、
  复制与搜索，过滤不修改配置。复制时生成不重名的编号与名称，保留撤销、校验和右键操作。
- LaneMapping 合并通道数与画笔工具栏，按实际背景和选中/悬停叠色计算可读字色。
- Generation 按架构与命名分组；通用设置收拢为卡片；Formatter 支持分类和跨分类搜索，
  保存保留隐藏参数。文档改为最大宽度可收缩容器，支持 960 × 640 窗口。
- 保留配置格式、信号方向、架构/PCLK 联动及 RTL/TB 生成语义，无需迁移。

验证：全量 377 项测试，375 通过、2 项可选 Verilator 仿真跳过；新增 8 项交互回归。
原生 Windows 深浅主题及窄窗口截图检查通过。主题切换完整帧耗时中位数：
主界面 83 ms、通用 85 ms、工具 182 ms、文档 147 ms，保持上一轮性能改进。
Ruff F/E9 与 `git diff --check` 通过。详见仓库 `docs/ui_redesign_2026-10-15.md`。
本次提交源码，未重新构建发布安装包。

### 2026-10-15：深浅主题切换性能修复（本地源码修改）

- 切换主题时暂停顶层窗口重绘，卸载旧样式表后安装目标样式，避免 Qt 5
  对缓存控件及其子树反复应用样式、重复计算字体和表格布局。
- 保留原本禁用重绘的窗口状态；继续保留未保存编辑、选区、撤销历史、
  滚动位置及日志，并刷新图标、语法高亮、差异和文档颜色。
- 新增可复测的主题性能脚本和样式事件数量回归测试。Windows 原生 Qt 5.15.2
  下六次交替切换的完整帧耗时中位数：主界面 413 → 90 ms，工具页
  1,029 → 178 ms；工具页样式变更事件从 9,118 次降至 1,368 次。

验证：主题专项 16 项测试通过；全量 369 项测试，367 通过、2 项可选
Verilator 仿真跳过；原生 Windows 深浅主题截图检查通过。
修改涉及的 Python 文件通过 Ruff F/E9 检查，`git diff --check` 通过。
详见仓库 `docs/theme_switch_performance_2026-10-15.md` 与对应基准 JSON。
本次只修改本地源码，未重新构建或发布安装包；配置无需迁移。

### 2026-10-15：第一阶段 Qt 界面现代化（源码提交）

- 界面改为 13px 字号、32px 控件、16px 图标和 6px 控件圆角；保留 56px 折叠轨道、44px 标题栏及 16px 面板外圆角。
- 使用清爽中性色阶及统一面板边框，导航按钮与项目行继续共用图标、文字对齐基线。
- Generation 输入控件最大宽度为 360px，生成操作条保持可见；Formatter 按参数内容分配列宽并限制整体宽度。
- 日志显式使用等宽字体，清理开发占位标题，统一生成及前缀文案，并保留折叠导航的辅助名称。
- 更新对应的尺寸、颜色、路径省略和布局回归断言。

验证：全量 347 项测试，345 通过、2 项可选 Verilator 仿真跳过；Windows 下
125%、150%、200% 缩放检查与截图验收通过，Ruff F/E9 和 `git diff --check` 通过。
本轮更新为源码提交；10 月 13 日的本地 wheel/sdist 未包含上述 UI 改动，本轮未重新构建安装包。

### 2026-10-13：本地打包

从 `3.0.4` 升级为 `3.0.5`，基于当前源码重新构建本地 wheel 和 sdist。
同步包版本、锁文件、安装示例及独立 wheel 校验脚本中的版本断言。
本次版本更新不改变 CLI、Qt 界面或 RTL/testbench 生成行为，无需迁移配置。

验证：CLI、打包及生成回归共 24 项测试通过；使用独立环境检查 wheel/sdist
源码与资源、CLI 生成及 Qt 界面。当时仅完成本地构建，未单独提交或发布。

## 3.0.4（2026-10-11）

发布日期：2026-10-11。从 `3.0.3` 升级为 `3.0.4`。本版只调整 Qt 前端的面板层次，
功能、核心生成器和生成结果不变。

3.0.3 的靛蓝色板下，白色面板与背后的底色只有 1.13:1 的对比度，配置面板、输出面板、
产物面板和底色读起来像一整片；设置页和文档页则是整块白底直接贴着侧栏。

- 面板背后的底色（侧栏、标题栏）加深为 `#DDE2F3`，与白色面板的对比度提高到 1.29:1。
- 配置面板和输出面板加 1px 外框（`#BCC5E3`）。
- 设置页和文档页改为与配置面板同样的带外框圆角面板，返回按钮留在面板上方的底色上。
- 产物面板的外框加深，工具栏底色加深，并在左缘向配置面板投下一道柔和阴影。
- 侧栏选中项改为白色底，悬停色加深，两者在加深后的底色上都能分辨。
- muted 文字色加深为 `#596088`，在加深后的底色上保持 4.5:1 以上。

验证：全量 347 项测试，344 通过，2 跳过，1 失败（macOS 下的路径省略用例，与本版无关）。
界面在 offscreen 模式下逐页截图核对。

## 3.0.3（2026-10-11）

发布日期：2026-10-11。从 `3.0.2` 升级为 `3.0.3`。本版只改 Qt 前端的界面和文档，
核心生成器、CLI 和生成的 RTL/testbench 不变。

### 界面

- **配色改为靛蓝色板。** 主色 `#4F46E5`，侧栏、标题栏、表头和输入框的灰色带上主色
  的色调，与白色内容区拉开层次；次要文字和 Lucide 图标随之一起带色调。取值与对比度
  记录在 `docs/color_scheme_recommendation.md`。
- Generate 按钮挪到 Generation 页左下角，产物面板打开时不再被盖住。
- 表格下方新增错误摘要条：显示第一条错误和错误总数，点击跳到出错的单元格。
- 没有打开项目时四个配置页只能查看、不能编辑。
- 文档页的分页标签改为中文：使用入门、配置文件、生成命令。

### 修复

- 切换项目后，输出面板底部仍显示上一个项目的“生成完成：N 个文件”。
- 文档页里代码块前一段正文被染成代码块底色，代码行之间有条纹，末尾多一行空行。
- 设置页“浏览…”按钮文字被裁切。
- 侧栏长项目名被硬截断；现在显示省略号，悬停显示全名。
- Generate 按钮禁用时外观与可用时相同。
- 输出状态标签显示为方角。
- 设置页和文档页盖住了窗口右下角的圆角。
- 产物面板标题把文件名从中间省略（`pipe_...te.sv`），难以区分；现在保留尾部。

### 文档

- `qt_frontend_guide.md`：按实际界面改写了项目管理、lane 分配方式、lane 数选择、
  数值格式、Formatter 默认值、预览入口和设置分页名称等描述。
- `tool_usage.md`：补上三个前缀参数；注明“切换无重叠”“空窗值无毛刺”只在开 DPR 时
  成立，以及不开 DPR 时切 mode 的复位要求；修正目录树、章节编号（原 5–8 节改为
  4–7 节）和 staging 目录位置。

### 验证

`QT_QPA_PLATFORM=offscreen python -m unittest discover -s tests`：347 项，
344 通过，2 跳过，1 失败（macOS 下的 `test_toolbar_path_tracks_selection_and_elides_without_moving_buttons`，
与本版改动无关）。界面改动另在 offscreen 模式下逐页截图核对；未在 Windows/Linux
字体和真实显示器上核对。

## 3.0.2（2026-10-11）

发布日期：2026-10-11。从 `3.0.1` 升级为 `3.0.2`。本版只改 Qt 前端和生成
日志的输出方式，生成的 RTL/testbench 文本不变。

### 修复

- 校验错误标到错误的 controller 行：`controllers.csv` 的行不按 `ctrl_id`
  排序时，3.0.1 会把错误标在别的行上。
- 有未保存修改时切换项目并选择"保存"后，侧栏高亮停在旧项目。
- 在标题栏重命名项目失败（如目标名已存在）后，标题仍显示新名字。
- `test/`、`configs/` 下 CSV 不在 `config/` 子目录里的目录不再出现在
  项目列表中（它们本来就打不开）。
- 生成日志改为通过回调收集，不再在工作线程里重定向进程级 `sys.stdout`。

### 行为变化

- **保存不再要求校验通过。** 表格里有不合法的格子也能存盘，校验结果照常
  显示；生成仍要求配置合法，并在失败时定位到出错的单元格。不能写入的
  前缀（如含路径分隔符的 `file_prefix`）仍会拒绝保存。
- Generate 按钮和输出状态固定在 Generation 页底部，不随表单滚动。
- 前缀输入框里连续输入算一步撤销，不再每个字符一步。
- 新增的 mode 行使用下一个空闲的 mode 编号，并复制上一行的 lane 分配。
- 外部编辑器设置可以带参数（如 `code -g`）。
- 未保存内容的校验信息不再带内部占位路径 `<editor>/config/`。

### 验证

`QT_QPA_PLATFORM=offscreen python -m unittest discover -s tests`：341 项，
338 通过，2 跳过，1 失败（macOS 下的 `test_toolbar_path_tracks_selection_and_elides_without_moving_buttons`，
与本版改动无关）。未在无合成器的 X11 环境下验证无边框透明窗口。

## 3.0.1（2026-10-11）

发布日期：2026-10-11。从 `3.0.0` 升级为 `3.0.1`。本版去掉了 `--sel-mode`
并把顶层参数改为 `localparam`，已有的命令行脚本和例化代码需要按下面的
迁移说明调整。

### 选择方式改为由 DPR 决定

`--sel-mode` 参数、Qt Generation 页的"选择方式"下拉框和 `gen_flags.txt`
的 `sel-mode` 键已移除。开 DPR 时选择信号走 `sync`，不开时走 `comb`。
不开 DPR 时只能在受影响的 lane 处于复位时切换 `mode`。

迁移：命令行去掉 `--sel-mode`；旧 `gen_flags.txt` 里的 `sel-mode` 键会被
忽略，下次保存时消失。不开 DPR 的配置重新生成后，`pipe_lane_mapper`、
`pipe_lane_mapper_connection`、`pipe_lane_sel_gen` 的 `SEL_SYNC` 默认值从
`1'b1` 变为 `1'b0`。

`pipe_lane_mapper` 和 `pipe_lane_mapper_connection` 的 `NL`、`NC`、`SEL_SYNC`
由 `parameter` 改为 `localparam`：它们由生成时的配置固定，例化时不能再
覆盖。迁移：例化这两个模块时去掉 `#(...)` 参数列表。

不开 DPR 时生成的 testbench 改为先拉低相关 controller 的复位再切换
`mode`，并新增监视块：在未复位的 lane 上切换 `mode` 判 FAIL。生成的
可综合 RTL 不含断言。

### 其他改动

- controller 数量与最小颗粒度不对齐由报错降为警告，警告显示在报告开头的
  `Warnings` 段；`--quiet` 生成时打到 stderr。x16 拆成 x8+x4+x4 这类
  三个 controller 的拓扑现在可以生成。
- CSV 接受 UTF-8 BOM（Excel 的"CSV UTF-8"导出）。
- `--arch` / `--pclk-mode` 只传一个时自动补全另一个。
- `ctrl_id`、`max_width`、`width`、`mode`、lane 单元格只接受纯十进制；
  `safe_state`、`tie_off` 只接受十进制或 `0x`/`0b`/`0o` 字面量。`0_4`、
  `+1` 这类写法现在报格式错误。
- 全直连拓扑（如单模式配置）下 `pipe_lane_sel_gen` 的 `sel_tgt` 不再无驱动。
- 校验错误定位到正确的 controller 行（名字互为前缀时不再错位）。
- 生成时的暂存目录建在工作区内，不再要求工作区的父目录可写。
- `--config` 路径下找不到 CSV 时一律报错，不再回退到包内置配置。
- 删除 `test/quad` 示例（非法拓扑反例保留在 `tests/fixtures/samples/quad`）；
  `test/bifurcate` 的 controller 名和 mode 行顺序整理。

### 验证

`QT_QPA_PLATFORM=offscreen python -m unittest discover -s tests`：332 项，
329 通过，2 跳过，1 失败（macOS 下的 `test_toolbar_path_tracks_selection_and_elides_without_moving_buttons`，
与本版改动无关）。四套示例 × 两种时钟架构 × 开关 DPR 共 16 种组合：
Verilator `-Wall` lint 无诊断，生成的 testbench 仿真全部 PASS。未安装
verible，格式化路径未覆盖。

## 3.0.0（2026-10-10）

发布日期：2026-10-10。当前开发版本从 `2.0.8` 升级为 `3.0.0`。
本次合并包含 `plm-ui-refactor` 分支尚未进入 main 的界面、生成器和测试改动。
由于生成 RTL 的复位端口接口发生变化，采用大版本号。

2026-10-10 修订：`perst_n` 限定为 serdes 的 MAC→PHY 复位；
三类前缀自动补齐末尾 `_`；差异比较采用带红绿底色和双行号的 GitHub 风格。

### 新增独立的 perst_n 复位

`perst_n` 仅适用于 `serdes` 架构，是 MAC→PHY 方向的低有效复位。
它与原有 `rst_n` 使用相同的控制器归属选择和 DPR 覆盖规则，
但两路信号独立，互不影响。新增端口如下：

| 位置 | 新端口 | 用途 |
| --- | --- | --- |
| 顶层及 connection wrapper | `<controller>_perst_n` | 每个控制器的低有效复位输入 |
| 顶层及 connection wrapper | `phy_perst_n[NL-1:0]` | 每条 PHY lane 的低有效复位输出 |
| 启用 DPR 的顶层及 wrapper | `dpr_perst_n` | DPR 通路的低有效复位输入 |
| reset mux 内部 | `ctrl_perst_n` / `phy_perst_n` | 按 lane group 路由第二路复位 |

这些端口适用于 serdes 的 bus/flat 接口和 `pclk_as_phy_input` 模式。
`original_pipe` 不生成这组复位端口、内部连线及 testbench 检查。无需在
`pipe_signals.csv` 增加复位行。复位通过原始目标归属 `dec_tgt` 路由；
多源选择无有效归属时输出为 0，DPR 被选中时采用 DPR 复位输入。
单源、无 DPR 的 lane group 继续直接连接唯一控制器，与原有 `phy_rst_n` 相同。
原有选择同步和时钟切换仍使用 `ctrl_rst_n`。

生成的 testbench 连接新端口，并检查各模式下的归属、独立脉冲、释放和
DPR 覆盖，统计新增 `err_perst` 类别。名称校验会阻止用户信号与这些固定端口冲突。

### Generation 命名前缀

Generation 页面新增三个输入框，保存到工作区 `config/gen_flags.txt`：

| 设置 | 作用范围 | 示例 |
| --- | --- | --- |
| `module_prefix` | 模块、公共模块、package、testbench 名称及引用 | `soc` → `soc_pipe_lane_mapper` |
| `file_prefix` | 所有生成的 `.sv` 文件及 flist/makefile 引用 | `rtl` → `rtl_pipe_lane_mapper.sv` |
| `macro_prefix` | 五个 PLM 宏及对应编译 define | `SOC` → `SOC_DUMP_FSDB` |

宏清单为 `PIPE_USE_ICG_CELL`、`PIPE_ICG_CELL`、`PIPE_USE_CLKOR_CELL`、
`PIPE_CLKOR_CELL`、`DUMP_FSDB`。三类前缀分别独立设置。
非空前缀自动补齐末尾 `_`，已有末尾 `_` 时不重复添加；空前缀保留旧名称。
配置和 manifest 保留输入值，生成名称使用补齐后的前缀。

输入框支持配置恢复、撤销/重做和修改状态。非法前缀在保存或替换生成结果前
报错；切换前缀会使旧输出过期，再生成时同步替换 RTL/TB 并清理旧文件名。
用户端口、信号、字段、实例和参数名称保持原样；`flist.f`、`makefile`、
`manifest.json` 的文件名也保持原样。

CLI 通过显式参数使用同样功能，仍不读取 Qt 的 `gen_flags.txt`：

```text
plm generate --config /path/to/workspace --module-prefix soc --file-prefix rtl --macro-prefix SOC
```

前缀的字符限制、完整作用范围和集成说明见开发文档
`docs/generation_prefixes.md`。

### 界面与代码质量

- Configuration 和 Log 内容距离窗口布局边缘保留 4 个逻辑像素。
- ArtifactsPanel 四边统一为 1 像素 `#D1D9E0` 框线、16 像素圆角；
  裁剪内部内容，修复预览背景覆盖圆角框线的问题。
- 差异预览的删除行为红色、新增行为绿色、区块标题为浅蓝色；
  同时显示旧/新行号，行号栏也使用对应底色。退出差异模式恢复普通代码预览。
- 合并已有的导航图标/文字对齐、紧凑控件、表格与弹出控件尺寸、
  bus/flat 接口选项，以及 Qt 绘制性能优化。
- 清理无用导入，修复测试等待已发出信号的竞态；Windows offscreen 测试
  在字体库为空时加载真实字体，防止无文字截图误通过。
- 增加独立的面板几何、边框像素、前缀持久化与输出、复位路由及互不干扰测试。
  Artifacts 圆角测试包含取消裁剪的负向检查，确认能发现原始问题。

### 从 2.x 迁移

1. serdes 工作区重新生成成套 RTL/TB，更新已有顶层和 wrapper 实例的端口连接。
   每个控制器接入 `<controller>_perst_n`，接出 `phy_perst_n`；启用 DPR 时
   还需接入 `dpr_perst_n`。暂不使用第二路复位时，应将其输入连接到 `1'b1`。
   original_pipe 保持原有固定复位接口。
2. serdes 不要把 `perst_n` 添加到 `pipe_signals.csv`；若已有同名自定义信号，
   需先重命名，以免与固定端口冲突。
3. 旧工作区没有前缀配置时继续使用原来的模块、文件和宏名称。
   旧前缀若未以 `_` 结尾，重新生成后会补齐分隔符；已带 `_` 的配置保持原输出。
   设置前缀后，
   外部模块引用、编译文件列表及 ICG/clock-OR 集成的宏定义应同步更新。
   生成的 makefile 会自动使用带前缀的 `DUMP_FSDB`。
4. 生成器版本改变会使历史 manifest 过期；请重新生成，不要混用新旧 RTL/TB。

### 验证与构建

2026-10-10 修订后的完整测试共 321 项：319 通过，2 项可选 RTL 仿真跳过。
前缀生成 RTL 的 Verilator 语法检查覆盖 8 种 PCLK/DPR/bus-flat 组合，均通过。
面板回归已覆盖 100%、125%、200% 缩放。

此前本机可选 `perst_n` 编译仿真的结果比较输出为 PASS，但 Verilator 进程随后
以 Windows 异常码 `0xC0000005` 退出，因此该项未计为通过。

发布构建使用 Python 3.12：先构建新 sdist，再从该 sdist 构建 wheel；
`scripts/check_wheel.py` 在独立环境中检查包内容、CLI 和 Qt 生成流程。

```text
uv build --sdist --python 3.12 --out-dir dist
uv build --wheel dist/plm-3.0.0.tar.gz --python 3.12 --out-dir dist
uv run --python 3.12 python scripts/check_wheel.py dist/plm-3.0.0-py3-none-any.whl --sdist dist/plm-3.0.0.tar.gz
uv pip install "dist/plm-3.0.0-py3-none-any.whl[qt]"
```

## 2.0.8（2026-10-10，本地构建）

- 将 Configuration 和 Log 内容到窗口布局边缘的距离统一为 4px。
- ArtifactsPanel 增加四边框线，并通过裁剪内部内容补齐圆角处被覆盖的框线。
- 重新检查代码质量，增加面板几何、边框像素、真实文字绘制及交互回归测试；
  修复信号等待竞态和 Windows offscreen 字体缺失导致的测试误判。
- Generation 新增 `module_prefix`、`file_prefix`、`macro_prefix`，
  同时支持配置保存与恢复、CLI 参数和生成结果中的名称及引用更新。
- 构建并验证 `plm-2.0.8-py3-none-any.whl`；随后增加独立 `perst_n`
  复位及其测试，并重新构建验证同版本 wheel。

该版本曾在本地构建，没有独立发布提交；上述改动与新增复位接口最终一起
进入 `3.0.0` 的发布提交 `169889d`。因此 Git 中包版本从 `2.0.7`
直接变为 `3.0.0`，本文保留实际发生过的 `2.0.8` 迭代记录。

## 2.0.7（2026-10-09）

日期：2026-10-09。Python 包版本由 `2.0.6` 升级为 `2.0.7`。

- 导航按钮的图标位置与有无文字解耦，折叠动画期间使用一致的绘制区域。
- 新增派生常量 `NAV_ICON_INSET`，使图标在展开态和折叠态都对齐到 56px 折叠轨道的中心。
- 项目行使用相同的内边距和图标文字间距，文件夹图标与其他导航图标对齐，项目名称与其他导航文字对齐。
- 移除折叠态专用 padding 补丁，保留 32px 按钮、原有导航布局及标题栏切换按钮位置。
- 窗口截图像素回归覆盖全部导航项、全部项目行及双向动画；实际 Windows 窗口截图已验收。

完整测试：282 项，280 通过、2 项跳过。

```powershell
uv build
uv run python scripts/check_wheel.py dist/plm-2.0.7-py3-none-any.whl --sdist dist/plm-2.0.7.tar.gz
```

发布提交：`25c2899`；同版本后续改动：`8aa6f51`。

## 2.0.6 / r6（2026-10-09）

日期：2026-10-09。Python 包版本由 `2.0.5` 升级为 `2.0.6`。

### 本轮改动

- 修复 Qt 主窗口、标题栏、导航栏及 Artifacts 面板的布局和折叠交互；统一尺寸、字体、图标及表格卡片样式。
- 缓存按钮尺寸和窗口阴影，合并表格更新与校验，减少项目加载时的重复处理。
- 设置页按需创建 Formatter 参数表；文档在独立文档对象中完成解析和格式化后一次显示，缩短打开时间。
- 实施统一冷灰色板，区分浅蓝选中态、灰色 hover 和交替行；修正 muted 文字对比度并移除 QSS 硬编码色值。
- Generation 页和 CLI 新增 Connection 总线类型选项 `bus` / `flat`，默认 `bus`。
  - `bus` 保持现有二维数组 `logic [W-1:0] a [0:NL-1]`。
  - `flat` 将每个端口展平为一维向量 `logic [NL * W - 1:0] a`；lane 0 位于低位，lane i 对应 `[i * W +: W]`。
  - 保留各控制器独立端口，选择会保存到工作区，并参与生成状态和撤销/重做。

### 构建与验收

```powershell
uv build
uv run python scripts/check_wheel.py dist/plm-2.0.6-py3-none-any.whl --sdist dist/plm-2.0.6.tar.gz
```

发布检查覆盖包内源码及资源一致性、独立环境中的 CLI 和 Qt 入口、两种 PHY 架构、DPR、flat Connection 端口、设置页及文档页。

Git: `fda1026`.

## 2.0.5（2026-10-08，后续沿用至 r4）


- 增加项目重新加载功能，重新读取磁盘配置并将输出标记为过期，下一次生成强制刷新。
- 修复项目菜单打开期间操作按钮隐藏、悬停状态和菜单边缘/阴影等问题。
- 同版本后续调整全局字体、控件、表格、下拉菜单、项目行及间距，统一紧凑布局。
- r4 继续统一桌面 UI 和交互，修复 Formatter 行内控件初始高度，
  清理无调用方的 API 及已被校验禁止的多源 Controller PCLK 生成分支。

发布提交：`cb5a79f`；紧凑界面改动：`54ccc0f`。
后续 r4 改动详见本节下文；r4 改动期间包版本仍为 `2.0.5`。

日期：2026-10-09。r4 标记本轮桌面 UI 调整，Python 包版本沿用 `2.0.5`。

### 界面与交互

- 全局设计 token 统一系统中英文字体栈、16px 字号、圆角及按钮焦点底色。
- 图标使用 Lucide 官方 SVG：18px 图形、20px 居中容器，保留原始路径和线宽。
- 项目菜单和参数下拉列表共用白色圆角菜单、胶囊高亮与柔和阴影；删除项使用红色提示。
- 导航栏恢复分组分割线，项目之间留出 2px 间隔，更多按钮保持圆形焦点背景；折叠状态图标位置与展开状态对应。
- Artifacts 开关移至标题栏，图标与导航开关区分；预览面板采用暖灰底色，与配置页和日志面板分开。
- 设置、文档、通用、工具统一中文名称；次级页面返回箭头与标题组成一个完整按钮。
- 工具设置加宽并与标签页对齐；参数行背景连续，下拉框边界可见，文本框与下拉标签起点一致。
- Verible 在打开设置页面时自动检测，检测成功直接显示路径，移除自动检测按钮和重复成功提示。
- 删除和归档确认弹窗使用不透明白色背景；静态未修改状态隐藏，修改状态通过高亮标记显示。

### 验证

- 全量 unittest 共 270 项：267 通过、2 跳过，发现 1 处仍要求行内控件高 40px 的旧断言。
- 更新该断言为 40px 行内的 36px 控件后，生成集成测试 8 项全部通过；未重复执行全量测试。
- 原生 Windows 菜单测试 5 项通过，覆盖键盘选择、禁用项及取消选择；全量运行中的菜单字体跳过项由原生平台检查补充。
- Python 编译检查、提交差异空白检查通过。
- 原生 Windows 截图检查通过，包含设置、菜单、确认弹窗、折叠导航和 Artifacts 面板。

本轮提交包含 PLM 工作区的现有样例配置编辑与审查记录，以及对应的 CI 测试入口更新。

### R4 冗余代码清理（2026-10-09）

- 删除 `TopologyIndexes.widths` 对外字段及其仅供断言使用的检查；局部 `widths` 统计仍用于 `minimum_widths` 和拓扑校验。
- 删除未被使用的 `Config._min_granularity()` 转发方法，统一访问 `topology_indexes().minimum_widths`。
- 删除 `TaskRunner.submit()` 和 `submit_latest()` 无调用方依赖的 task ID 返回值；内部 `_prepare()` 仍返回 ID 并继续管理任务生命周期。
- 移除项目时显式释放 `takeItem()` 返回的 `QListWidgetItem`。
- 不改动 RTL/TB 生成逻辑、DPR、PCLK 模式、格式化逻辑以及 `test/` 示例数据。

### CI 行内控件高度修复

- Formatter 参数表行高保持 40px，ComboBox/LineEdit 在创建时就固定为 36px，供上下各 2px 内边距使用。
- 不再依赖 `ButtonSizingController` 在后续事件中把默认 40px 高度调整成 36px；这使 Linux/Windows 的最小高度断言一致。

### 不可达时钟分支清理

- `validate()` 已禁止任何 Controller 的 PCLK 源随 mode 变化，删除 `gen_decoder`、`gen_sel_gen`、`gen_clk_mux_phy_output` 和顶层连接中只服务于多候选 Controller PCLK 的生成分支。
- 保留 Controller 固定 PHY PCLK 直连；DPR 仍使用独立的 glitch-free 时钟选择器；两种 PCLK 架构均保留。
- 为保证 R4 已审核的 RTL golden hash 稳定，暂保留生成文件的静态注释与未使用接口参数，避免引入纯文本输出差异。

## 2.0.4（2026-10-08）


- 增加 `plm --version` 和统一的包版本导出，更新安装说明及发布检查。
- 修复 Artifacts 生成前后基线和差异预览，完善文件按需加载及对应回归测试。
- 调整界面样式、图标、设置和文档页面，改善生成过程中的显示与交互。
- 构建并验证 wheel 和 sdist。

发布提交：`5d4a484`。

## 1.0.5（2026-09-29，r3 检查于 2026-10-07）

初次重构提交：`c4e90f6`，重建 Qt 前端布局，包版本升级到 `1.0.5`。
以下保留当时的 r3 审查与验证记录；这些历史验证边界不代表当前版本的状态。

检查日期：2026-10-07。范围为当前 PLM 核心、CLI、PyQt5 前端、资源、内置文档和发行包。
本次沿用现有发行包版本 `1.0.5`，不变更版本号。

### 清理结果

- 删除项目悬停卡片遗留的 `hoverEntered` / `hoverLeft` 信号及发送代码；保留项目行归档、打开目录、更多菜单和重命名操作。
- 文件选择入口统一使用 `path_button`，移除 `tree_button` / `file_selector` 重复别名与重复初始化。
- 删除没有调用方的 `SHADOW_MD` / `SHADOW_LG`；保留 LaneMapping 弹出编辑器仍在使用的 `SHADOW_SM`。
- 删除没有对应控件的 `Card` 样式、重复的 ConfigTabs pane 样式和旧阴影间距注释。
- 删除闲置的 `braces.svg`、`external-link.svg`、`file.svg`，同步图标下载清单与资源测试；剩余 28 个图标均有源码引用。
- `ICON_SIZE_SM` 改为直接从设计 token 模块导入，不再通过 common 模块转导出。
- 更新内置指南中已删除的添加行工具栏、语法高亮开关、复制完整内容与文件夹工具按钮说明。

### 检查与修复

初次全量回归发现两项过时断言：卡片阴影间距、底栏状态/行数位置。
现已按 r3 行为更新断言，仍检查真实布局、无图形阴影效果、输出状态和编辑器信息。

截图脚本及 wheel 安装检查原先按同步行为使用控制器，未等待后台加载/生成完成。
现在共用 `scripts/qt_smoke_support.py` 等待工作任务与延迟校验，截图脚本也使用现行字体和图标尺寸 token。

发行包检查发现旧 `build/` 缓存将已删除的悬停卡片代码及图标重新打入 wheel。
旧缓存已移至系统临时目录备份并重新构建；wheel 检查增加前端源码/资源清单比对，
遇到缺失文件或额外旧文件会直接失败，避免发布带有过时缓存的包。

### 验证结果

| 检查 | 结果 |
| --- | --- |
| 全量 unittest | 185 项：184 通过、1 跳过；无失败、无错误，示例基线隔离方式见下文 |
| Python 源码语法与 QSS token 替换 | 通过 |
| 28 个保留图标的引用、存在和渲染检查 | 通过 |
| 截图脚本的页面、菜单和交互断言 | 通过，生成 14 张控件截图 |
| 离线构建 wheel | 通过，使用 uv 默认隔离构建环境 |
| 临时目录安装 wheel | CLI、Qt 资源、Settings、Documentation 和 4 种时钟/DPR 组合通过 |
| git diff --check | 通过 |

全量测试覆盖配置编辑、保存/撤销/重做、项目管理及恢复、异步任务、生成失败保护、
输出完整性与过期检测、文件浮层、搜索/Diff、侧栏、窗口与焦点反馈。

### 工作区数据与验证边界

本地 `test/maxpclk/config/` 中 controllers、signals 和生成参数已有用户编辑。
原样运行示例黄金文件测试时，当前配置与已提交 manifest 的配置哈希不一致。
本次没有覆盖配置或重新生成用户输出。全量复测仅在黄金文件比较用例中使用临时复制的示例目录，
并以 HEAD 中的这三个配置文件还原该用例的基线；其他用例仍使用当前工作区。
因此直接对当前工作区运行 unittest，仍会报告这一个已知示例基线不一致。

跳过的一项为需显式设置 `PLM_RUN_RTL_SIM=1` 的 RTL 仿真，未执行外部仿真器验证。
Qt 检查使用 Windows offscreen 平台，字体像素渲染有限，不能据此确认真实桌面的文字观感。
首次 wheel 冒烟子进程曾在此平台原生异常退出；开启 faulthandler、将意外弹窗转为断言后复跑通过，
原生异常的根因未确认。

### 常用复查命令

```powershell
$env:QT_QPA_PLATFORM = 'offscreen'
$env:PYTHONPATH = 'src;tests'
uv run python -m unittest discover -s tests
uv build --wheel --offline
uv run python scripts/check_wheel.py dist/plm-1.0.5-py3-none-any.whl
```

删除源码或资源后，构建前需移开旧的生成目录 `build/`，避免 setuptools 带入遗留文件。
测试与构建日志、wheel、截图均保存在系统临时目录，本次提交不包含用户的示例配置编辑。
