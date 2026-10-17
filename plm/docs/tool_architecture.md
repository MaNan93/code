# PLM 工具架构

更新日期：2026-10-17。

本文描述当前 Python 工具；RTL 设计规则见 [design_notes.md](design_notes.md)。
PLM 使用 `pyproject.toml` 与 `src/` 包布局，提供 CLI 和唯一的 Qt 桌面前端。
两者共享核心模型、校验、生成与事务导出，避免各自实现一套业务规则。

## 共享核心

| 模块 | 职责 |
|---|---|
| `core/model.py` | Controller、Signal、LaneGroup、Config，解析和拓扑规则 |
| `core/workspace.py` | CSV、Qt 工作区生成参数、默认配置及读写 |
| `core/gen_flags.py` | 不可变 `GenerationOptions` 和参数合法组合 |
| `core/plan.py`、`validation.py` | 构建共享 GenerationPlan，配置与输出校验 |
| `core/generator/` | RTL/TB 文本生成 |
| `core/exporter.py` | staging、输出自检、匹配 manifest 和成套替换 |
| `core/service.py` | CLI 与 Qt 共用的生成入口 |
| `core/verible.py` | 格式化器查找、参数与调用 |
| `core/paths.py` | 源码和安装包中的默认资源路径 |

导出先在 staging 中生成 RTL 和 TB，再检查文件、hash、端口、宽度与模板残留；
成功后更新两套输出。失败保留旧输出。两份 manifest 具有相同 generation key。
输出状态核对配置、参数、生成器、格式化器以及实际输出文件，不能仅凭文件存在
判定“最新”。

## Qt 分层

| 层 | 职责 |
|---|---|
| `models/` | 项目与偏好数据 |
| `services/projects.py` | 项目发现、打开、新建、重命名、删除及安全标记 |
| `services/settings.py` | QSettings，最近项目、置顶、归档、编辑器与 Formatter 偏好 |
| `services/workspaces.py` | 工作区加载、保存、核心校验、生成与输出新旧判断 |
| `controllers/app_controller.py` | 项目选择、编辑保护、操作编排及列表刷新 |
| `views/` | 配置、Settings、Documentation、日志面板与 Artifacts 页面组件 |
| `widgets/` | 表格编辑器、代码预览、选项切换与基础控件 |
| `main_window.py`、`main.py` | 窗口装配和启动 |

Qt 直接调用核心，不拼装 CLI 子进程。Controllers、Lane Mapping、Pipe Signals
三个 CSV 进入实际编辑器；GenerationOptions 来自 Generation 页和 Formatter 偏好。
归档与置顶存入 QSettings，重命名和删除由 ProjectService 执行；刷新后保持有效
选择，无可用项目时显示空状态。

编辑采用快照历史，支持撤销与重做。切换项目等操作先处理未保存修改；磁盘签名
变化时阻止保存和生成，要求重新加载。选择方式由 DPR 勾选决定（勾选为 sync，否则 comb），架构和 PCLK
互相联动。已存在的非法配置保留原值，由核心校验报告。

Formatter 的路径和参数由 QSettings 提供给每次校验、生成和状态检查。
`None` 表示项目内置格式化参数，空字典表示 Verible 自身默认值。
设置变化会重新检查输出是否过期。

旧 `settings`、`theme`、`sap_icons`、`code_highlighter` 控件及 SAP/72 字体已移除。
`lanegrid.py` 和 `tables.py` 仍由配置编辑器使用，随发行包一起提供。
当前文件预览使用自己的只读编辑器和高亮器；
界面使用 SVG 图标与固定的默认字体。
Qt 回调的未捕获异常写入 traceback 和窗口日志，事件循环继续运行。
保存时的配置校验错误通过单元格标记与日志反馈，不重复弹出模态提示。
导航栏展开宽度固定为 260px，收起后为 56px，图标按钮尺寸由共享 token 统一定义。
侧边栏与内容区通过零间距水平布局连接，展开恢复 260px 固定宽度。
主窗口默认 1280 × 800。三个配置表格移除外层卡片，Controller 限宽 800px，
Signals 和 LaneMapping 使用可用宽度，
共用浅色网格线和仅有底部分隔线的表头；Controller 三列等宽且文字左对齐。
多通道网格保留字符所需列宽，空间不足时横向滚动。
笔刷拖拽超过系统拖动阈值后生效，单击等待双击判定后涂色，双击直接编辑原值。
重新加载表格取消待涂单击；日志收起时取消其拉伸权重，窗口缩放不会再次展开。
外部改动检查在模态提示期间阻止重入，并在退出或异常时释放检查标记。
Settings 分为 General（编辑器）和 Formatter；非法参数会
切换到 Formatter 并聚焦输入框。参数控件按内容与单元格内边距自适应尺寸。
关闭二级页面清除导航激活态；Documentation 归一化章节标题、忽略代码块内
标题，表格使用内容区百分比宽度，代码块使用深色圆角背景与等宽字体。

Artifacts 使用 GitHub 浅色文件视图：白色代码区、浅灰工具栏、右对齐工具按钮和关闭按钮。
文件树显示 Lucide 图标与层级竖线；数据文件标记用于区分文件和文件夹，避免展开回调改写文件图标。
面板底部状态栏与相关元数据控件已删除，预览占满余下高度。

`EditableTable` 刷新时复用单元格控件，通过 `_building` 抑制程序更新触发用户编辑信号。
复用行控件仍按当前行号回调，插入、删除、重排和撤销后保持数据一致。
`StyledComboBox` 首次展开才创建菜单；原生下拉代理只初始化一次。
Signals 两个枚举列使用 `OptionSwitch`，单个可键盘操作的按钮绘制当前值；
12px 下拉微标在静止时隐藏、悬停时淡入，键盘聚焦时完整显示。
按钮点击循环切换选项，悬停才显示底色；刷新复用按钮并保留非法 CSV 值，复用同一数据与撤销入口。
三张配置表使用统一字重，以及随主题变化的表头、网格和交替行底色。
Signals 的文字列左对齐、数字列右对齐；信号名列采用更大的初始最小宽度并分配剩余空间。
文本 delegate 在创建编辑器和更新其几何尺寸时同步单元格对齐，避免数字在编辑时跳到左侧。
切换按钮的悬停背景为浅灰胶囊，10 px 水平/4 px 垂直内边距，150 ms 颜色过渡；
动画首次交互时才创建，控件隐藏时停止，避免后台持续重绘。
`CodePreview` 仅在行号宽度改变时重设 viewport margin，字体改变时重新计算。
性能测量使用 `scripts/profile_ui.py` 和 `scripts/profile_themes.py`，
检查入口与资料索引见 [README.md](README.md)。

## 参数、入口与打包

CLI 的生成参数显式传入；Qt 在 `config/gen_flags.txt` 保存生成选择和命名前缀，
CLI 不读取这个文件。Makefile 与核心样例测试各自显式指定样例所需参数。
非法拓扑的负面样例在 `tests/fixtures/samples/quad`，不应为让回归通过而改写。

源码启动用 `uv run python run.py -gui`，发行包提供 `plm-gui` 和 `plm -gui`。
包内资源路径通过 `core.paths` 解析，安装后不依赖源码目录，也不要求安装包带
仓库样例。用户可以从任意位置创建或打开工作区。

包内 `src/plm/docs/` 是 GUI Documentation 的来源，更新操作说明应修改这里。
Qt 使用说明见 [qt_frontend_guide.md](../src/plm/docs/qt_frontend_guide.md)。
示例布局和每套配置所需参数见[示例指南](../examples/README.md)。

## 回归与发行检查

```bash
uv sync --extra qt --locked
uv run python -m unittest discover -s tests -v
uv build --wheel
uv run python scripts/check_wheel.py
```

无显示环境需设置 `QT_QPA_PLATFORM=offscreen`。安装包检查将 wheel 安装到临时
目录，在源码目录以外执行 CLI、加载 Qt 资源和文档，并生成两种时钟架构各自
启用/禁用 DPR 的四种组合。

CI 覆盖 Linux/Windows 的 Python 3.9/3.12，以及 macOS 的 Python 3.12 回归；
三平台检查四档缩放，并在 Linux/Windows 检查 wheel。
单独的 Linux RTL 仿真任务安装 Verilator，设置 `PLM_RUN_RTL_SIM=1` 验证 PHY input
模式 DPR 与独立 PERST 路由仿真。未设置此变量时，耗时仿真测试跳过；生成文本检查仍执行。
样例快照测试禁用外部格式化器，并按统一换行的文本比较，避免本机 Verible
版本与 Windows 换行影响结果。格式化器行为另由生成集成测试覆盖。

## 历史决定

工具从平铺脚本迁移为可安装包，CLI 采用标准库 argparse，避免增加 CLI 专用依赖。
源码入口命名为 `run.py`，避免 `plm.py` 遮蔽同名包，也方便 Windows 启动。
可编辑示例统一位于 `examples/<示例>/config/`，自动测试与基线位于 `tests/`。
Qt 兼容发现已有的旧 `test/`、`configs/` 工作区；按名称调用 CLI 时从 `examples/`
解析，显式目录参数继续支持任意工作区。Web 前端和旧 Tkinter 前端已移除，Qt 是唯一 GUI。
