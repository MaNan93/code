# PLM 样式与渲染性能分析

日期：2026-10-09。对应当前 `plm-ui-refactor` 分支，包版本仍为 2.0.7。

## 界面调整

- 主窗口默认尺寸改为 1280 × 800，最小尺寸保留 960 × 640。
- Controller、LaneMapping、Signals 删除外层表格卡片，表格占满原容器宽度。
  三张表共用 `#E5E8ED` 浅色网格；标题行只保留底部分隔线，数据区补齐左边线。
- Controller 三列等宽，标题与单元格文字左对齐。Signals 保留按内容分配列宽，
  LaneMapping 保留 lane 列和横向滚动，以保证枚举值和多通道内容可读。
- Artifacts 使用白色代码区、`#F6F8FA` 工具栏、`#D1D9E0` 分隔线、
  `#1F2328` 正文和 `#59636E` 辅助文字。配色参考
  [GitHub Primer 色彩](https://primer.style/product/primitives/color/)，语法色参考
  [Primer syntax / CodeMirror 主题](https://primer.style/product/getting-started/react/theme-reference/)。
- Artifacts 工具按钮右对齐，最右侧增加关闭按钮。关闭走现有收起动画，窄面板保留关闭和展开入口。
  底部状态栏已删除，代码区延伸到面板底部；输出状态保留在 Generation、日志和工具栏辅助信息中。
- 文件树加入 Lucide 文件夹、代码文件、JSON 文件、普通文件图标和浅色层级竖线。
  展开/折叠回调只更新目录图标，`.sv` 文件不会再被改成文件夹图标。
- Signals 的 `signal_type` 与 `direction` 改为当前值加 Lucide `arrow-right-left` 图标，
  点击或空格切换，方向键选择；悬停显示 `#F3F4F6` 胶囊背景，水平/垂直内边距为 10/4 px，
  颜色过渡为 150 ms。三张表统一 500 字重、`#475569` 表头与浅灰网格/行底色。
  Signals 前三列左对齐，后三列右对齐；信号名列的初始最小宽度提高为 256 个设计像素，仍弹性伸展。
  Artifacts 更多菜单补齐 Lucide 图标，与导航菜单共享圆角、阴影、行高和选中效果。

Lucide SVG 使用[官方图标仓库](https://github.com/lucide-icons/lucide)，并同步维护下载脚本中的资源清单。

## 测量方法

新增 `scripts/profile_ui.py`，在独立临时目录中创建测试数据，不依赖实际用户工作区。
使用原生 Windows Qt 平台和 `WA_DontShowOnScreen`，真实渲染字体、QSS、SVG 与控件。
每项先预热 3 次；优化前绘制测 60 次、更新操作测 15 次，最终复测分别为 120 次和 30 次。
正式计时未开启 cProfile；单独的 cProfile 运行用于定位热点。

前后对照测量环境：Windows 11、Python 3.12.10、Qt 5.15.2、Fusion、DPR 1.0、1200 × 800。
这是增宽到 1280 × 800 之前的对照数据；增宽版另行记录，避免混用绘制面积不同的结果。
数据：4 个 Controller、32 lane × 10 mode、100 行 Signals、100 个文件，
所选 SystemVerilog 文件包含 1004 个物理行。

绘制耗时包含 `QWidget.render()` 与画布清空；表格更新和标签切换包含处理排队事件及等待后台任务完成。
这些是本机 CPU 渲染与事件处理耗时，不是屏幕帧率、磁盘加载耗时或其他设备上的性能保证。
原始数据见 [ui_style_2026-10-09.json](benchmarks/ui_style_2026-10-09.json)。

## 结果

单位：ms，中位数。优化后 P95 也列出，便于观察波动。

| 场景 | 优化前 | 优化后 | 优化后 P95 |
|---|---:|---:|---:|
| Controller 整窗重绘 | 2.821 | 2.788 | 3.852 |
| 32-lane 页面整窗重绘 | 9.132 | 8.450 | 10.059 |
| 100 行 Signals 页面整窗重绘 | 7.355 | 5.333 | 6.584 |
| 100 行 Signals 相同数据重载 | 762.844 | 7.809 | 8.675 |
| 100 行 Signals 实际变更后刷新 | 759.808 | 8.084 | 9.816 |
| Artifacts 整窗重绘 | 8.481 | 7.618 | 11.094 |
| 1004 行语法重新高亮 | 36.641 | 11.220 | 13.073 |
| 100 文件树浮层重绘 | 1.588 | 1.351 | 1.980 |
| 菜单重绘 | 0.261 | 0.267 | 0.477 |
| 连续切换三个配置标签 | 130.525 | 25.780 | 28.140 |

主要收益是数据刷新减少约 99.0%，重新高亮减少约 69.4%。
单次重绘和标签切换的小幅变化不作为普遍性能提升结论；一次中间复测的 32-lane
重绘中位数达到 14.601 ms，说明本机调度存在波动。后续比较应保持相同平台、DPI 和测试数据，
并重复采样。

最新 1280 × 800 版本补测 60 次绘制/15 次更新：Signals 页面整窗重绘中位数为 8.584 ms，
相同数据重载为 10.964 ms、实际变更刷新为 12.043 ms。该运行同时进行 Qt 回归检查，
用于补充验证，不与上表作严格性能对比。原始数据保存在 JSON 的 `current_design_1280`。
悬停动画仅在首次交互时创建，150 ms 后结束，控件隐藏时停止；静止状态没有持续重绘。

## 热点与优化

1. **复用表格控件。** 原实现刷新先清空所有行，再逐个调用 `setCellWidget()`。
   cProfile 中此调用累计约 7.4 秒，是主要热点。现在保留行内下拉框和文本单元格，
   只增加缺失控件、更新内容和调整行数。最终两个枚举列使用单个自绘 `OptionSwitch` 按钮，
   没有菜单或每选项子按钮。实际变更场景同样受益，不靠忽略刷新取得数字。
2. **按需创建菜单。** 100 行 Signals 有 200 个行内下拉框；原先每个下拉框都会预先创建菜单。
   中间优化阶段改为首次展开才创建；最终枚举列改为无需弹出的按钮。
   Signals 页加载后整窗只有 5 个下拉控件、202 个切换按钮（含 2 个隐藏尺寸探针）和
   1 个菜单，避免大量隐藏窗口参与样式和事件遍历。
3. **减少重复代理查询。** 全局尺寸事件过滤器原先反复读取原生下拉代理，
   cProfile 中 `itemDelegate()` 累计约 4.7 秒。自绘菜单不再安装原生 popup 代理，
   其他下拉框只安装一次；尺寸已正确时不重复设置固定高度。
4. **缓存行号宽度。** 代码布局和高亮会频繁触发 `updateRequest`。
   行号宽度未变时直接返回，不重复设置 viewport margin 和行号几何；字体改变仍重新计算。

保留既有窗口阴影和 Lucide 图标缓存。菜单重绘已低于 1 ms，未为此增加新的缓存生命周期。
标签切换由中间阶段约 132 ms 降为最终约 26 ms，仍包含事件与布局处理。
保留下拉框的中间阶段结果存放在原始 JSON 的 `intermediate_dropdown_after`，避免混淆两种控件。
本轮未改成新的表格模型或减少可编辑功能。

## 冗余代码清理

- 删除 `ConfigTableCard` 包装、卡片 padding 和内层圆角 token，以及对应 QSS。
- 删除 Artifacts 底栏、进度/光标/文件格式控件、`ArtifactMetadataLabel`、信号连接和废弃状态样式。
- 删除完全透明的 toolbar 分隔器及其显示逻辑。
- 删除重复设置 Artifacts toolbar 布局的辅助方法，统一 toolbar 高度与内边距来源。
- 清理未使用的 LaneGrid spacing import，合并更新后的工具按钮样式。
- 截图脚本改为使用窗口默认尺寸；下载脚本和资源回归清单包含新增图标。

## 验证与复现

- 全量 unittest：287 项，285 通过、2 跳过。
- 1280 × 800 与悬停细化后的 Qt 回归：197 项，196 通过、1 跳过。
- 原生界面检查覆盖六列表头/数据对齐、信号名列宽、无横向溢出、胶囊背景颜色、过渡结束与隐藏时停止动画。
- 原生 Windows 菜单测试：5 项全部通过，补充 offscreen 跳过的字体像素检查。
- 表格刷新回归覆盖：控件复用、非法 CSV 值保留、刷新不触发用户修改信号、
  重排/删除后的行回调，以及刷新时关闭未提交的文本编辑器。
- 切换按钮覆盖鼠标/键盘编辑、无重复信号、刷新复用、非法值提示、重排/删除回调，以及撤销/重做/保存后重新打开。
- 已检查原生 Windows 截图：三个配置页、Artifacts、文件树、左边线、文件图标和右对齐工具栏。
- Python 语法与 `git diff --check` 通过。
- 已构建 wheel 并核对 104 个包内文件与当前源码/资源完全一致，包含新增的 Lucide 图标与切换控件。

在 `plm/` 目录运行：

```powershell
uv run python scripts/profile_ui.py --output ui-profile.json --iterations 120
uv run python scripts/profile_ui.py --output ui-profile.json --profile ui-profile.prof --screenshots ui-screenshots
uv run python -m unittest discover -s tests
$env:QT_QPA_PLATFORM = 'windows'
uv run python -m unittest discover -s tests -p test_qt_menu_style.py
```

正式计时使用不带 `--profile` 的命令，带 `--profile` 的运行仅用于查看热点。
Linux 无显示环境可以设置 `QT_QPA_PLATFORM=offscreen`；Windows 字体截图应使用原生平台。
测试不设置依赖机器速度的耗时阈值。
