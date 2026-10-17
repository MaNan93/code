# PLM 文档与目录索引

更新日期：2026-10-17。只保留现用说明、设计资料和一套最新截图；历史修改与
迁移记录统一查看版本日志及 Git 历史。

## 当前文档

| 内容 | 入口 |
| --- | --- |
| CLI、CSV 格式与生成参数 | [工具使用说明](../src/plm/docs/tool_usage.md) |
| Qt 项目管理、表格、生成和预览 | [Qt 使用指南](../src/plm/docs/qt_frontend_guide.md) |
| 版本变更与迁移 | [版本日志](../src/plm/docs/release_note.md) |
| Python 核心与 Qt 分层 | [工具架构](tool_architecture.md) |
| RTL 原理、时钟与通道约束 | [设计要点](design_notes.md) |
| 模块名、文件名、宏名前缀 | [命名前缀](generation_prefixes.md) |
| 面板几何与像素验收要求 | [面板契约](qt_panel_contracts.md) |
| 最新深浅主题、弹窗及窄窗口截图 | [截图图库](screenshot/index.html) |

## 目录职责

```text
plm/
├─ src/plm/             应用源码、包内资源与随包文档
├─ tests/               自动回归及独立的 fixtures 测试基线
├─ test/<示例>/config/   可编辑示例的输入配置
├─ scripts/             截图、性能测量、缩放及安装包检查
└─ docs/
   ├─ images/           设计文档实际引用的硬件图
   └─ screenshot/       唯一的最新界面图库
```

`.venv/` 是本地运行环境。`build/`、`dist/`、日志、缓存和示例的 `rtl/`、`tb/`
均为可再生产物，不进入版本管理。`test/` 供人工使用，`tests/fixtures/` 是回归
基线，两者不能混用或自动同步覆盖。

## 常用检查

```powershell
uv sync --extra qt --locked
uv run python run.py -gui
uv run python -m unittest discover -s tests -v
uv run python scripts/check_ui_scaling.py --output build/ui-scaling.json
uv build
uv run python scripts/check_wheel.py
```

更新正式截图时，在项目根目录设置输出目录后执行：

```powershell
$env:PLM_SCREENSHOT_DIR = "$PWD/docs/screenshot"
$env:PLM_CAPTURE_HEADLESS = '1'
uv run python -B scripts/capture_ui.py
```

截图脚本使用临时演示项目，不修改示例配置；输出 PNG、HTML 索引及尺寸清单。
四档缩放和界面自动检查不能替代跨显示器拖动、系统窗口合成等人工检查。
