# PLM 最终复核与发布验证（2026-10-08）

本次完成测试隔离、生成回归重构、后台任务生命周期修复以及 wheel / sdist 构建和独立安装验证。工作区与解压源码包各运行 247 条测试，均为 246 条通过、1 条可选 Verilator 仿真跳过，退出码为 0。

## 测试改动

- 自动测试改用 `tests/fixtures/samples/` 的固定输入，写入操作使用临时目录，不读取可编辑的 `test/` 示例，也不依赖 Git 历史。
- 四套正向样本覆盖两种时钟架构、DPR、分组和模式切换；`quad` 保留为负向拓扑样本。
- 生成回归检查经过审查的 RTL / TB / flist / makefile 文本 SHA-256，统一 LF 换行。manifest 的动态指纹、生成键及各文件哈希单独根据本次 generation plan 校验。
- Qt 集成测试显式使用临时项目和临时 INI 设置，恢复字体、调色板、样式、剪贴板和异常钩子，只销毁本测试创建的窗口。
- 普通集成测试隔离隐式本机 Formatter，等待 worker 和 queued callbacks 排空后恢复 patch；显式路径、缺失路径、Formatter 专用 mocks 继续验证。
- 保留有效的旧功能测试，重写依赖可编辑项目或全局状态的部分，并增加隔离、异常任务、自然退出及打包回归。

## 新确认并修复的问题

- `Worker.run()` 的 `SystemExit` / `KeyboardInterrupt` 原先绕过失败回调，残留任务和同 key 的 pending 请求；现在所有 worker 异常均经过 GUI 侧清理。
- GUI 事件循环结束后仍在运行的 worker 可能访问已销毁的 Qt signals；入口现在在 `finally` 等待线程池完成，再释放应用和窗口。实际子进程验证自然关闭时在途 worker 正常结束。
- `Makefile clean` 原先留下 TB manifest 和 makefile，现在清理完整 RTL / TB 输出目录。本次未执行示例目录删除；当前环境未运行 GNU Make。

## 文件检查范围

只读机械审计覆盖 295 个文件：`src` 104、`tests` 48、`scripts` 4、`docs` 19、现有 `test` 示例 111、根配置和入口 9。其中 `src` 包含 6 个构建元数据文件，实际运行包为 98 个源码和资源文件。

| 检查 | 数量 | 结果 |
| --- | ---: | --- |
| Python AST、编译和 Python 3.9 语法解析 | 90 | 通过 |
| 现有 SystemVerilog 的 Verible 语法解析 | 80 | 通过 |
| 严格 UTF-8 文本解码 | 281 | 通过 |
| SVG XML | 29 | 通过 |
| PNG 完整解码 | 14 | 通过 |
| JSON / TOML / CSV 解析 | 12 / 2 / 31 | 通过 |

Python 数量由 59 个应用源码、26 个测试及辅助模块、4 个脚本和 `run.py` 组成。SV 数量包括 5 个 common 模块和五套示例的 75 个现有输出文件。各检查范围相互重叠；审计前后文件 SHA-256 一致。

此范围是按文件类型进行的检查，不能等同于每个文件逐行人工审查。虚拟环境、第三方依赖、缓存、诊断日志及父目录兄弟项目未纳入；`build` / `dist` 中的发布产物另行验证。本文在文件盘点后新增，不计入上述快照。

## 全量测试与安装验证

| 验证 | 结果 |
| --- | --- |
| 工作区正式全量 unittest | 247 条，246 通过 / 1 跳过；178.806 秒 |
| 新 sdist 解压后全量 unittest | 247 条，246 通过 / 1 跳过；175.257 秒 |
| wheel 源码及资源逐字节校验 | 98 个文件通过 |
| sdist 内容及当前源码逐字节校验 | 164 个文件通过 |
| 无 Qt 的独立环境 | 真实 `plm.exe` 校验、资源加载、6 种生成组合通过 |
| 安装 Qt 后的独立环境 | GUI 入口、资源、设置、文档、4 种生成组合和原生资源释放通过 |
| `git diff --check` | 通过 |

sdist 测试所在临时目录没有 `.git` 和可编辑的 `test/`。安装验证清除项目 Python 路径与用户 site 影响，确认所有 `plm` 模块来自新环境。安装时保留原 PATH，运行安装包时将 PATH 收窄到新环境及 Windows 系统目录，避免本机 Formatter 混入 smoke。

本次实际环境为 Windows、Python 3.12.10、PyQt5 5.15.11、Qt 5.15.2。Python 3.9 仅通过语法解析，未在其解释器上执行整套测试；Linux 运行验证和可选 Verilator 仿真未执行。

工作区正式命令：

```powershell
uv run --extra qt python -X faulthandler -m unittest discover -s tests -q
```

最终先构建 sdist，再直接从新 sdist 构建 wheel，避免旧 `build/lib` 内容混入：

```powershell
uv build --sdist --out-dir dist
uv build --wheel dist/plm-1.0.5.tar.gz --out-dir dist
uv run python scripts/check_wheel.py dist/plm-1.0.5-py3-none-any.whl --sdist dist/plm-1.0.5.tar.gz
```

日志保存在 `build/verification/unittest-final.log`、`dist/build-sdist-2026-10-08.log`、`dist/build-wheel-2026-10-08.log`、`dist/check-wheel-2026-10-08.log` 和 `dist/sdist-tests-2026-10-08.log`。

## 发布产物

| 文件 | 大小 | SHA-256 |
| --- | ---: | --- |
| `dist/plm-1.0.5-py3-none-any.whl` | 203241 bytes | `e50a79fa4c47c58eb927b60aa4de0f06d6281a1457ee859e21051741f9507a5c` |
| `dist/plm-1.0.5.tar.gz` | 252372 bytes | `1463d78d42101d73dc20c6a2997517d9d5cd812fc9997999831d9647f6e8a928` |

wheel 只包含应用、运行资源和包元数据；sdist 还包含自动测试、固定 fixtures 和验证脚本。产物已在本地构建和验证，未发布到包仓库。

本轮继续工作前后，用户 `test/maxpclk/config/` 中三个已有修改文件及 `.plm-workspace` 的 SHA-256 均保持一致。
