# PLM 截图 2026-10-16-r0

参考 `../2026-10-15/` 的覆盖范围、1280 × 800 主窗口、中文图库和 12 页概览结构，基于当前本地源码重新截图。

- 43 张页面截图，另有 `overview.png`，共 44 张 PNG；`index.html` 为图库，`manifest.json` 记录文件名、中文标题、实际尺寸及字节数。
- 覆盖深浅主题、四个配置分页、搜索、设置及格式化预览、文档、生成结果、差异、菜单与弹窗，以及 960 × 640 窄窗口。
- Windows 原生 Qt / Fusion，100% 缩放；使用临时演示项目和独立设置，实际生成 RTL / testbench，等待异步任务和动画完成。
- 本机未找到 Verible；格式化预览截图保留真实的工具缺失提示。
- 截图脚本统一解析临时目录的实际路径，避免 Windows 目录映射使差异截图的相对路径计算失败。

截图来源：`.venv/Scripts/python.exe -u -B scripts/capture_ui.py`，设置 `PLM_CAPTURE_HEADLESS=1`、`QT_QPA_PLATFORM=windows`、`QT_SCALE_FACTOR=1`、`QT_AUTO_SCREEN_SCALE_FACTOR=0`、`PLM_SCREENSHOT_DIR=docs/screenshots/2026-10-16-r0`。
