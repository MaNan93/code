# r3 完整性检查

检查日期：2026-10-07。范围为当前 PLM 核心、CLI、PyQt5 前端、资源、内置文档和发行包。
本次沿用现有发行包版本 `1.0.5`，不变更版本号。

## 清理结果

- 删除项目悬停卡片遗留的 `hoverEntered` / `hoverLeft` 信号及发送代码；保留项目行归档、打开目录、更多菜单和重命名操作。
- 文件选择入口统一使用 `path_button`，移除 `tree_button` / `file_selector` 重复别名与重复初始化。
- 删除没有调用方的 `SHADOW_MD` / `SHADOW_LG`；保留 LaneMapping 弹出编辑器仍在使用的 `SHADOW_SM`。
- 删除没有对应控件的 `Card` 样式、重复的 ConfigTabs pane 样式和旧阴影间距注释。
- 删除闲置的 `braces.svg`、`external-link.svg`、`file.svg`，同步图标下载清单与资源测试；剩余 28 个图标均有源码引用。
- `ICON_SIZE_SM` 改为直接从设计 token 模块导入，不再通过 common 模块转导出。
- 更新内置指南中已删除的添加行工具栏、语法高亮开关、复制完整内容与文件夹工具按钮说明。

## 检查与修复

初次全量回归发现两项过时断言：卡片阴影间距、底栏状态/行数位置。
现已按 r3 行为更新断言，仍检查真实布局、无图形阴影效果、输出状态和编辑器信息。

截图脚本及 wheel 安装检查原先按同步行为使用控制器，未等待后台加载/生成完成。
现在共用 `scripts/qt_smoke_support.py` 等待工作任务与延迟校验，截图脚本也使用现行字体和图标尺寸 token。

发行包检查发现旧 `build/` 缓存将已删除的悬停卡片代码及图标重新打入 wheel。
旧缓存已移至系统临时目录备份并重新构建；wheel 检查增加前端源码/资源清单比对，
遇到缺失文件或额外旧文件会直接失败，避免发布带有过时缓存的包。

## 验证结果

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

## 工作区数据与验证边界

本地 `test/maxpclk/config/` 中 controllers、signals 和生成参数已有用户编辑。
原样运行示例黄金文件测试时，当前配置与已提交 manifest 的配置哈希不一致。
本次没有覆盖配置或重新生成用户输出。全量复测仅在黄金文件比较用例中使用临时复制的示例目录，
并以 HEAD 中的这三个配置文件还原该用例的基线；其他用例仍使用当前工作区。
因此直接对当前工作区运行 unittest，仍会报告这一个已知示例基线不一致。

跳过的一项为需显式设置 `PLM_RUN_RTL_SIM=1` 的 RTL 仿真，未执行外部仿真器验证。
Qt 检查使用 Windows offscreen 平台，字体像素渲染有限，不能据此确认真实桌面的文字观感。
首次 wheel 冒烟子进程曾在此平台原生异常退出；开启 faulthandler、将意外弹窗转为断言后复跑通过，
原生异常的根因未确认。

## 常用复查命令

```powershell
$env:QT_QPA_PLATFORM = 'offscreen'
$env:PYTHONPATH = 'src;tests'
uv run python -m unittest discover -s tests
uv build --wheel --offline
uv run python scripts/check_wheel.py dist/plm-1.0.5-py3-none-any.whl
```

删除源码或资源后，构建前需移开旧的生成目录 `build/`，避免 setuptools 带入遗留文件。
测试与构建日志、wheel、截图均保存在系统临时目录，本次提交不包含用户的示例配置编辑。
