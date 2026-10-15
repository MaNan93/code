# Qt 深浅主题切换耗时排查（2026-10-15）

主题切换的主要耗时来自 `QApplication.setStyleSheet()` 对已有样式的重新应用。
工具设置页创建后，同一个设置窗口保留了格式化参数控件；即使返回“通用”，
这些隐藏控件仍参与全局样式更新，因此切换仍然较慢。

## 原因与修复

本机运行 Qt 5.15.2。其全局 `repolish(QApplication*)` 取出全部已缓存对象，
随后 `updateObjects()` 在处理每个对象时又递归处理其子控件。同一控件可能因
多个祖先被重复处理，产生重复的 `StyleChange`、字体更新和表格布局计算。
相关实现见 [Qt 5.15.2 源码](https://github.com/qt/qtbase/blob/v5.15.2/src/widgets/styles/qstylesheetstyle.cpp#L2562-L2582)
及[全局 repolish 入口](https://github.com/qt/qtbase/blob/v5.15.2/src/widgets/styles/qstylesheetstyle.cpp#L2750-L2758)。

工具页场景只有 674 个控件，却在一次切换中收到 9,118 次 `StyleChange`。
单独给全局样式更新分段计时时，图标换色仅约 6–7 ms；瓶颈位于样式表应用。

修复在 `services/themes.py`：暂停原本允许重绘的顶层窗口，卸载旧样式表，
再设置目标调色板和样式表，最后恢复重绘。此路径使用两轮样式更新，避免已有
样式的重复递归应用，也避免显示中间的无样式状态。原本禁用重绘的窗口保持禁用。
图标换色、文档和语法高亮刷新继续执行。

## 本机测量

Windows 11，Python 3.12.10，Qt 5.15.2，原生 `windows` 平台插件，
窗口 1280 × 800，缩放比 1.0。使用临时 DPR 示例项目及独立 QSettings。
每个场景先预热两种主题，再交替切换六次。下表为从调用切换到处理排队事件并
抓取完整一帧的中位耗时，包含主题设置写盘。隐藏原生窗口用于隔离桌面干扰，
并不代表真实显示器的呈现延迟。耗时随机器与项目大小变化，不设固定测试阈值。

| 场景 | 修复前 | 修复后 | StyleChange 次数（前 → 后） |
| --- | ---: | ---: | ---: |
| 主界面 | 412.710 ms | 90.065 ms | 4,517 → 696 |
| 设置 / 通用（未创建工具控件） | 427.371 ms | 85.233 ms | 4,853 → 760 |
| 设置 / 工具 | 1,029.143 ms | 178.453 ms | 9,118 → 1,368 |
| 工具页返回通用 | 1,016.156 ms | 180.883 ms | 9,118 → 1,368 |
| 文档 / 使用入门 | 536.311 ms | 135.164 ms | 4,676 → 730 |

原始数据：[修复前](benchmarks/theme_switch_2026-10-15_before.json)、
[修复后](benchmarks/theme_switch_2026-10-15_after.json)。
复测脚本同时处理跨页面的延迟销毁，避免将已经关闭、等待删除的控件计入下一场景。

```powershell
.\.venv\Scripts\python.exe -B scripts/profile_themes.py --iterations 6 --output docs/benchmarks/theme_switch_2026-10-15_after.json --screenshots build/theme-switch-verification
```

## 验证

- 新增基于实际 `StyleChange` 事件数的回归测试。旧实现失败（9,118 次事件），
  修复后通过；同时验证格式化参数的未保存编辑和文本选择仍保留。
- 验证切换不改变调用方已禁用的窗口重绘状态。
- 主题专项 16 项测试通过，覆盖未保存内容、撤销历史、活动单元格编辑器、
  选中内容、滚动位置、日志、产物状态、图标、差异、语法高亮与文档换色。
- 全量 369 项测试：367 通过、2 项可选 Verilator 仿真跳过。
- 修改涉及的 Python 文件通过 Ruff F/E9 检查，`git diff --check` 通过。
- 原生 Windows 平台核对主界面、通用、工具、工具返回通用及文档页面的
  深浅主题截图，共 10 张，位于 `build/theme-switch-verification/`。

本次修改源码，未重新构建或发布安装包；配置文件无需迁移。
