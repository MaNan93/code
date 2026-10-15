# Qt 交互补全与验证（2026-10-15）

本轮接续工作区布局调整，补齐日志动画、真实 Formatter 预览与缩放检查。
源码版本仍为 3.0.5，配置无需迁移；本轮未重新构建发布安装包。

## 交互行为

- 日志展开/收起使用 200ms InOutCubic 动画，连续点击可反向，收起期间调整窗口后
  仍能完成关闭；重新展开保留用户设置的高度。生成失败仍自动展开。
- 工具设置增加“参数 / 效果预览”。首次进入预览才创建双栏编辑器，左侧可编辑
  两套 SV 示例，右侧显示真实 Verible 输出，保留语法高亮与深浅主题。
- 预览从当前未保存的路径和参数取得快照，250ms 防抖，在后台线程运行；同一预览
  最多一个运行任务和一个待处理任务，旧结果不能覆盖新输入。切走后停止排队。
- 预览进程超时为 3 秒，源码上限 64 KiB。参数错误、缺失工具、非零返回、空结果
  或标记流变化时清空旧结果并说明原因。生成器默认保持原有 10 秒及失败回退行为。
- 预览不保存本机设置、不写项目文件。保存时发现隐藏的无效整数参数，会返回参数页
  并搜索、定位该参数。

## 可重复检查

```powershell
.venv\Scripts\python.exe -B -m unittest discover -s tests
.venv\Scripts\python.exe -B scripts/check_ui_scaling.py --output build/scaling.json --screenshots build/scaling
.venv\Scripts\python.exe -B scripts/profile_themes.py --iterations 6 --output build/themes.json
$env:PLM_CAPTURE_HEADLESS='1'
$env:PLM_SCREENSHOT_DIR='docs/screenshot'
.venv\Scripts\python.exe -B scripts/capture_ui.py
```

缩放脚本为每个比例启动独立进程，检查 960 × 640、1280 × 800 两种窗口和深浅主题，
共 44 个页面状态/比例。覆盖四个配置页、日志、通用设置、Formatter 参数与预览、
三个文档分页；断言重要控件边界、生成表单无横向溢出、标签文字宽度、文档加载及
抓图物理尺寸与实际 DPR 一致。截图脚本使用本机 Verible 验证预览成功；需要已安装工具。

Windows 原生 Qt 使用系统字体；Linux offscreen 缩放抓图通过 `--font-dir /mnt/c/Windows/Fonts`
加载本机 Segoe UI、Consolas、微软雅黑。Linux 结果只代表 WSL 中的 Qt offscreen 与这些字体，
不代表原生 Linux 桌面窗口管理器或发行版默认字体。未进行 macOS 原生验证。

## 主题性能

原生 Windows Qt 5.15.2，每场景六次交替切换，含事件派发及完整帧抓图的中位数：

| 场景 | 耗时 |
|---|---:|
| 主界面 | 101 ms |
| 通用设置 | 91 ms |
| Formatter 参数 | 173 ms |
| Formatter 预览 | 186 ms |
| 创建预览后返回通用设置 | 176 ms |
| 文档 | 145 ms |

原始结果见 [主题切换基准](benchmarks/ui_polish_theme_switch_2026-10-15.json)。
计时受机器负载影响，不设硬性毫秒阈值；样式事件计数仍按控件数量线性增长。

## 验证结果

- Windows Python 3.12.10 全量 387 项测试：385 通过，2 项可选 Verilator 仿真跳过。
  本轮新增 10 项回归，覆盖动画中间帧/反向/缩放、严格格式化错误、防抖、后台线程、
  过期结果、未保存参数、失败清理和保存定位。
- Windows 原生 Qt 的 100%、125%、150%、200% 缩放共 176 个页面状态通过。
  每张抓图的实际 DPR 均等于请求的缩放比例。原始结果见
  [Windows 缩放检查](benchmarks/ui_scaling_windows_2026-10-15.json)。
- WSL Ubuntu / Linux Qt offscreen 的同四档缩放共 176 个页面状态通过，实际 DPR
  与请求比例一致。原始结果见 [Linux 缩放检查](benchmarks/ui_scaling_linux_2026-10-15.json)。
  Linux 没有安装原生 Verible，预览页验证的是工具缺失提示；真实格式化在 Windows 验证。
- 本机真实 Verible 验证：未保存的缩进参数从 2 改为 4 时，输出确实改变；无效 SV
  会返回错误。43 张截图覆盖深浅主题预览，结果均由本机工具生成。
- 修改的 Python 文件通过 Ruff F/E9 检查，`git diff --check` 通过。
- Linux 首轮全量检查发现窗口退出子进程测试硬依赖 `uv`。已改为使用当前解释器，
  保留调用环境的 Python 导入路径；Windows 与 Linux 的该模块 4 项回归均通过。
- 修正后 WSL Ubuntu / Python 3.10.12 全量重跑 387 项：385 通过，2 项可选
  Verilator 仿真跳过，耗时 298.502 秒。
