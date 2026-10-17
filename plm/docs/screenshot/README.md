# 最新 Qt 界面截图

更新日期：2026-10-17。与本轮代码审查修复、工具参数按需编辑及包内操作说明同步。

- [index.html](index.html)：43 张截图的浏览入口。
- [manifest.json](manifest.json)：文件名和实际图片尺寸。
- PNG 覆盖深浅主题、四个配置页、设置和格式化预览、文档、Artifacts、菜单、
  弹窗及 960 × 640 窄窗口。

截图使用 Windows Qt / Fusion 和独立的临时演示项目，实际生成 RTL/TB，等待
后台任务和动画完成；不修改 `examples/` 或 `tests/fixtures/`。
重新生成的方法见 [文档索引](../README.md)。本目录是唯一维护的界面图库。
