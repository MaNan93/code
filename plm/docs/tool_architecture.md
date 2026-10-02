# PLM 工具架构

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
| `services/settings.py` | QSettings，最近项目、置顶、归档、外观、工具偏好 |
| `services/workspaces.py` | 工作区加载、保存、核心校验、生成与输出新旧判断 |
| `controllers/app_controller.py` | 项目选择、编辑保护、操作编排及列表刷新 |
| `views/` | 配置、Settings、Documentation 页面 |
| `widgets/` | 表格编辑器、日志、真实文件预览与基础控件 |
| `main_window.py`、`main.py` | 窗口装配和启动 |

Qt 直接调用核心，不拼装 CLI 子进程。Controllers、Lane Mapping、Pipe Signals
三个 CSV 进入实际编辑器；GenerationOptions 来自 Generation 页和 Formatter 偏好。
归档与置顶存入 QSettings，重命名和删除由 ProjectService 执行；刷新后保持有效
选择，无可用项目时显示空状态。

编辑采用快照历史，支持撤销与重做。切换项目等操作先处理未保存修改；磁盘签名
变化时阻止保存和生成，要求重新加载。DPR 勾选将选择方式设为 sync，架构和 PCLK
互相联动。已存在的非法配置保留原值，由核心校验报告。

Formatter 的路径和参数由 QSettings 提供给每次校验、生成和状态检查。
`None` 表示项目内置格式化参数，空字典表示 Verible 自身默认值。
仅修改外观不会覆盖 Formatter 偏好。设置变化会重新检查输出是否过期。

旧 `lanegrid`、`tables`、`settings`、`theme`、`sap_icons`、`code_highlighter`
控件及 SAP/72 字体已移除。当前文件预览使用自己的只读编辑器和高亮器；
SVG 图标与字体偏好沿用现有界面。

## 参数、入口与打包

CLI 的生成参数显式传入；Qt 在 `config/gen_flags.txt` 保存自己的四项生成选择，
CLI 不读取这个文件。Makefile 与核心样例测试各自显式指定样例所需参数。
`test/quad` 是非法拓扑的负面样例，不应为让回归通过而改写。

源码启动用 `uv run python run.py -gui`，发行包提供 `plm-gui` 和 `plm -gui`。
包内资源路径通过 `core.paths` 解析，安装后不依赖源码目录，也不要求安装包带
仓库样例。用户可以从任意位置创建或打开工作区。

包内 `src/plm/docs/` 是 GUI Documentation 的来源，更新操作说明应修改这里。
Qt 使用说明见 [qt_frontend_guide.md](../src/plm/docs/qt_frontend_guide.md)。

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

CI 覆盖 Linux/Windows、Python 3.9/3.12 的回归，并在 Linux/Windows 检查 wheel。
单独的 Linux RTL 仿真任务安装 Verilator，设置 `PLM_RUN_RTL_SIM=1` 验证 PHY input
模式 DPR 仿真。未设置此变量时，耗时仿真测试跳过；生成文本检查仍执行。

## 历史决定

工具从平铺脚本迁移为可安装包，CLI 采用标准库 argparse，避免增加 CLI 专用依赖。
源码入口命名为 `run.py`，避免 `plm.py` 遮蔽同名包，也方便 Windows 启动。
样例目录由 `configs/` 改为 `test/`，子目录去掉 `test_` 前缀；代码中的 config
术语保留。Web 前端和旧 Tkinter 前端已经移除，Qt 是唯一 GUI。
