# 代码审查：plm-ui-refactor

审查日期：2026-10-07。范围：当前分支 `plm-ui-refactor`（316 commits vs main，+11729/-5954）与工作区未提交改动。
环境：Windows、Python 3.12.10、PyQt5 5.15.11、`QT_QPA_PLATFORM=offscreen`、**本机装有 verible-verilog-format**。

## 1) 结论速览

| 项 | 结果 |
| --- | --- |
| 全量 unittest | **239 项：231 通过、7 失败、1 跳过** —— 与文档记录的「185 项 184 通过」不一致 |
| 失败根因 | 7 项全部是 `wait_for_idle` 10 秒超时，由**真实 verible 拖慢生成**导致，非逻辑回归 |
| 禁用 verible 复跑同一批 | 4 项全部 OK（41.8s）；启用 verible 时 1 项失败（123.3s） |
| 单次生成成本 | 触发约 41 次格式化子进程，格式化累计 77.2s / 4 个测试，单次 ~19s |
| 格式化缓存 | 在本机**命中率 0%**（verible 以 `.BAT` wrapper 提供，被缓存键主动放弃） |
| 分层与异步模型 | 方向正确、资产扎实；边界有两处没闭合（见 P0-2 / P1-2） |

审查按 P0（阻塞合入）/ P1（本轮或下轮修）/ P2（可维护性）分级。

---

## 2) P0 阻塞项

### P0-1 测试基线不可信：装了 verible 的机器上必然失败

| 文件 | 位置 |
| --- | --- |
| `tests/qt_test_support.py` | `wait_for_idle(timeout=10000)` :55-71 |
| `plm/src/plm/core/verible.py` | `format_sv()` :285 `subprocess.run(..., timeout=10)` |

现象：全量跑 7 项失败，全部 `AssertionError: Qt workers or debounced callbacks did not finish within 10 seconds`。

- `tests/test_qt_generation.py::test_both_pclk_modes_generate_with_and_without_dpr`（3 个 subTest）
- `tests/test_qt_workflow.py`：`test_application_activation_marks_modified_output_out_of_date`、`test_edit_save_validate_generate_and_show_real_artifacts`、`test_output_state_edit_undo_save_and_project_switch`、`test_output_state_generation_integrity_and_noop`

诊断证据（超时时刻快照）：无 active timer、无取消标志，仅剩一个未完成的 worker 任务，控制器停在 `gen_running=True`：

```
=== TIMEOUT === tasks: {2163885940400: [], 2163886117312: [8]} timers: 0
controller state: gen_running=True ... gen_state=generating
```

对照实验：同一批 4 个测试，`PLM_NO_VERIBLE=1` 时 `OK`（41.857s，0 次格式化调用）；启用本机 verible 时 `FAILED`（123.343s，165 次格式化调用、累计 77.2s、单次最大 0.62s）。

为什么是问题：
1) 项目文档（`QT_CODE_REVIEW.md`、`docs/r3_integrity_check.md`）记录的全绿结论是在**没有 verible** 的环境取得的，在真实开发机上不成立 —— 这个基线不能用来判断重构是否有回归。
2) `wait_for_idle` 把 10 秒写成硬编码，而"生成"的真实耗时取决于外部工具是否安装，测试稳定性被外部环境绑架。
3) 用户实际体验同样受影响：一次生成 ~19 秒，其中绝大部分是 41 次子进程启动。

建议：
1) `wait_for_idle` 的 timeout 提升为参数化（生成类调用传 60s 或按是否检测到 formatter 动态取值），并保留"超时即失败"的语义。
2) 给格式化加一条慢路径告警或在 Settings 暴露开关，别让"装了 verible 反而更慢"成为静默默认。

### P0-2 格式化缓存在本机完全失效，且失败是静默的

| 文件 | 位置 |
| --- | --- |
| `plm/src/plm/core/verible.py` | `_format_cache_key()` :182-184（`.bat` 判定） |
| `plm/src/plm/core/verible.py` | `format_sv()` :296-303（门控接线） |

1) **缓存命中率为 0**：`find_verible()` 在本机解析到 `C:\Users\1\.local\bin\verible-verilog-format.BAT`，`_FORMAT_WRAPPER_SUFFIXES` 含 `.bat`，`_format_cache_key` 直接 `return None`。整个 `_FORMAT_CACHE`（32 项 / 8MB / LRU / 锁 / TOCTOU 重检）在本机一行都没生效，5 个 `common/*.sv` 每次生成都重新跑一遍 verible。设计得很细，但被一个后缀判定整体绕过，且没有任何日志提示。

2) **缓存门控被接成了输出门控**（真实契约 bug）：

```python
same_tokens = not cache or _format_tokens(formatted) == _format_tokens(text)
if same_whitespace and same_tokens:
    ...
    return formatted     # ← 校验失败时不缓存，而是连格式化结果一起丢弃
return text              # ← 静默返回未格式化原文
```

- `cache=False`（生成文件、TB、普通调用）只做空白校验；`cache=True`（仅 `exporter.py:351` 的 `common/*.sv`）多做一次 token 校验，**校验失败就直接退回未格式化原文**。
- 与 docstring :253-257「output is cached only after the whitespace and token checks pass」矛盾：文档说只影响是否缓存，实现是不通过就不产出。
- 后果：同一份输入在两条路径下验收标准不同，一旦 verible 版本微调导致 token 边界变化，`common/` 会**静默退回未格式化**而 `src/` 正常，输出风格不一致且无告警。

建议（两处分别修）：
```python
# 1) 门控只决定是否缓存，不再决定是否产出
if same_whitespace:
    if (not cache) or _format_tokens(formatted) == _format_tokens(text):
        if cache_key is not None and cache_key == _format_cache_key(source, exe, flags):
            _cache_format(cache_key, formatted)
    return formatted
```
```python
# 2) wrapper 场景不要直接放弃缓存，改为按 wrapper 内容做标识
#    无法取得内部二进制哈希时，可用 wrapper 文件内容 + 文件大小作为兜底键，
#    或至少 warn 一次说明缓存已禁用，避免"设计了缓存却从不生效"。
```

### P0-3 退出时没有 shutdown 协同，在途 worker 会在解释器收尾阶段继续跑

| 文件 | 位置 |
| --- | --- |
| `plm/src/plm/frontend/qt/main_window.py` | `closeEvent()` :537-542 |
| `plm/src/plm/frontend/qt/controllers/project_navigation.py` | `confirm_switch()` :30-34 |
| `plm/src/plm/frontend/qt/main.py` | `main()` :48 `app.exec_()` |

`confirm_switch` 的白名单只含 `_generation_running / _save_running / _project_operation_running / _load_running`，**不含 `_validation_running`**；而校验是 350ms 防抖自动触发的，改完配置立刻关窗必然命中。

`TaskRunner` 没有 `cancel_all()` / `wait()`，`main.py` 也没有 `aboutToQuit` 钩子或 `QThreadPool.waitForDone()`。关窗 → `exec_()` 返回 → `Py_Finalize` 开始，而线程池是 C++ 线程，Python 不会 join，worker 仍在执行 Python 字节码并向已销毁的 `TaskRunner` 投递回调。典型表现是退出挂起或 `Fatal Python error: PyEval_RestoreThread`。

建议：`TaskRunner` 增加 `cancel_all()` + `wait(timeout)`，在 `QApplication.aboutToQuit` 里调用；`confirm_switch` 纳入 `_validation_running`。

---

## 3) P1 中等

| # | 位置 | 问题 | 建议 |
| --- | --- | --- | --- |
| P1-1 | `services/tasks.py:94-102`（`cancel_latest` / `submit_latest`）+ `controllers/workspace_actions.py:258-262` | `cancel_latest` 只置 `cancelled` 标志、**不从 `_latest` 摘除**，新任务一律进 `_pending`；而 `scan` 的取消点只在首尾，`output_files()`（legacy 分支 `os.walk` 整树）与 `_artifact_signature()`（全量 SHA256）内部无取消点。切换项目后旧 scan 拖住新 scan，**标题栏已是新项目、产物面板仍显示上一个项目的文件** | 长 IO 内部插入取消点；或 `cancel_latest` 直接摘除 `_latest` 让旧任务变成"跑完即丢弃"的孤儿；加超时兜底 |
| P1-2 | `services/tasks.py:47-54` | `Worker.run` 只 `except Exception`。`SystemExit` / `KeyboardInterrupt` 会让 `completed`/`failed` 都不 emit，`_tasks` 永不清理、`_latest` 永久占位，此后该 key 上所有 `submit_latest` 进 `_pending` 且**永不启动**并持续泄漏闭包 | 改为 `except BaseException` 并在 `_fail` 同样清理；或给 `_pending` 加"超时强制重排"兜底 |
| P1-3 | `core/model.py:571` | `generated_name_errors` 用 `errors.setdefault((table,row,column), ...)` 去重。实证：控制器命名为 `phy` 时实际产生 5 处冲突，只报 1 条，用户看不到冲突全貌 | 改为 `setdefault(key, []).append(...)`，UI 侧 `config_page.py:409` 同步支持一格多条 |
| P1-4 | `core/model.py:471-503` | `topology_indexes()` 是 getter 却写 `self.groups` / `self.num_ctrl`（隐式副作用，会覆盖手工设置）；`group_of_lane()` 因此从 O(G) 退化成每次全量重建，`rtl.py:1140/1244`、`tb.py:522` 在 `for m in modes: for lane in lanes:` 双层循环里调用它 → raw-Config 路径整体 O(L²M²)。另 `max(self.controllers)` 空表抛 `ValueError`（旧实现返回 `{}`） | 去掉对 `self` 的写赋值改为纯返回；`group_of_lane` 走 lazily-built 索引；`max(...)` 加空表保护并在 `validate()` 补空表诊断 |
| P1-5 | `controllers/workspace_actions.py:187,200,202` + `services/workspaces.py:83,97-133` | 一次生成 = 2 次全量产物枚举 + 2 次全量 SHA256（生成前后各哈希一遍同一批旧产物） | `generate()` 返回一份 files 复用；manifest 模式直接复用 manifest 里已有的 `_file_hash`，不要重新读盘 |
| P1-6 | `services/workspaces.py:58-64` + `controllers/project_navigation.py:168-170` | `load_with_signature` 读 3 遍（signature → load → 再 signature），打开项目 12 次文件读；且 4 个文件中**任一**在窗口期被改写就整体失败，而实际只影响部分字段。与 save/generate 用的 `signature != saved_signature` 是两套不一致的并发守卫 | 用 `(st_mtime_ns, st_size)` 或让 `workspace_content` 顺带返回快照；统一为 `WorkspaceService.revision(project)` 概念 |
| P1-7 | `controllers/workspace_actions.py:27,233,257`；`app_controller.py:103`；`project_navigation.py:166` | controller 直接下探 view 内部 widget 树（`self.config_page.artifacts_panel.selection.files`、`self.nav.project_list.project_widgets`），分层在文件结构上成立、在调用关系上不成立 | 在 `ConfigPage` / `NavPanel` 上收敛门面方法（`artifacts.set_files()`、`has_outputs()`、`select_project(name, emit)`） |
| P1-8 | `views/artifacts_panel.py:57-91` | `ArtifactsPanel` 由 3 个非 QObject mixin 拼装，直接读写宿主 `__init__` 建立的属性，依赖 MRO 尾部是 `QFrame`；任一 mixin 无法独立实例化/测试 | 改组合（`self._files = ArtifactFiles(self)`）或显式声明抽象属性 |
| P1-9 | `views/artifacts_panel.py:87` vs `app_controller.py:40` | view 自带 `TaskRunner` 发起 `artifact-read`/`artifact-diff`，controller 另有一个发起 `artifact-scan`，key 空间分裂，"刷新产物"和"读当前文件"没有跨队列先后保证 | 三合一到同一 runner，或由 panel 门面统一 cancel 三个 key |
| P1-10 | `controllers/workspace_actions.py:63-81` | `validate_current` 的 `failed` 分支在 revision 失效时不重启定时器（`finished` 分支会），状态栏会停在失败文案直到下次编辑 | `failed` 与 `finished` 用同一套收尾逻辑 |
| P1-11 | `views/artifact_files.py:79-96` | `finished` 对"读取成功但 key 既不在 contents 也不在 errors"无兜底，下一轮会再次 submit —— 当前靠路径归一化幂等不触发，是**没有防御的循环不变量** | `else: self._file_errors[key] = "无法读取该文件"` |
| P1-12 | `services/workspaces.py:112` | manifest 模式下 `manifest.json` 被当成产物列出，可被预览、可被外部编辑器改坏（之后 `read_manifests` shape 校验失败会静默 fallback 到全树遍历） | UI 层过滤元数据文件并禁止在编辑器中打开 |

---

## 4) P2 轻微（汇总）

| 位置 | 问题 |
| --- | --- |
| `views/artifact_preview.py:126,130-133` | diff 模式下先 `text = ""` 再算行数，`_file_status` 恒为 "0 行" |
| `views/artifact_preview.py:115-120,147-148` | 一次载入触发两遍全文查找 |
| `views/artifact_files.py:112-116` | `select_file` 未同步 `path_button` 的 checked 态，与树点击行为不一致 |
| `views/artifacts_panel.py:60-62` | `widthRequested` 由 `mouseMoveEvent` 高频 emit，每次都全量重排；应节流 |
| `widgets/project_list.py:158-166` | `_remove_project` 的 `takeItem` 返回值未释放，泄漏 QListWidgetItem |
| `views/nav_panel.py:251-264` | 每次项目变更全量重建 `ProjectList`；`selected_name` 缺失时静默 fallback 到首项并触发 `projectSelected` |
| `core/model.py:229-239` | `TopologyIndexes.widths` 生产代码零引用；六个字段全标 `object` |
| `core/model.py:602,789` | `validate(*, _topology=None)` 用下划线私有参数做公共 API |
| `core/model.py:362-366` | "每方向至少一个信号"在**加载期**抛 `SystemExit`，编辑器无法加载该配置来修正；`validate()` 又不检查 |
| `core/model.py:584` + `views/config_page.py:415` | `enumerate(controllers.values())` 取 CSV 行序，UI 却把 `issue.row` 当 ctrl_id 反查，controllers.csv 非升序时高亮错位 |
| `core/verible.py:161` | 操作符表里的反引号分支不可达（死分支） |
| `core/verible.py:215` | `size > MAX_BYTES` 时直接 return，同 key 旧条目不清理，残留占额 |
| `core/verible.py:264,301` | `_format_cache_key` 每次调用两遍（两遍 `path.stat()` + 读 2 字节），第二遍 TOCTOU 重检在锁外 |
| `core/verible.py:150-153` | 三个模块级全局手写 LRU，建议封装成类 |
| `frontend/qt/exceptions.py:1,9-30` | docstring 称"不终止事件循环"，但 PyQt 5.5+ 对 slot 内未捕获异常是先调 `sys.excepthook` 再 `qFatal()`；handler 只能记日志 |
| `services/tasks.py:69-72` | `submit()` 返回 `task_id` 但全项目无调用方使用 |
| `services/tasks.py:11-29` | `TaskProgress` 把 `task_id` / `signals` 暴露给业务闭包 |
| `main_window.py:587` 等 5 处 | 缺少 PEP8 要求的空行 |
| 仓库 | `plm/build/lib/plm/core/` 是未跟踪的旧代码镜像，调试时易误导（建议清理或加入 .gitignore） |

---

## 5) 已确认正确、不应误改的部分

1) `services/tasks.py` 的 `TaskCancelled` / `TaskProgress` / `submit_latest` / `_take_finished` 状态机：`test_qt_task_coalescing.py` 三个用例逐条对过，逻辑自洽，`cancel_latest` 先 pop pending 再 prepare，不堆积 orphan。
2) `services/workspaces.py:100-114` 的 `is_relative_to` 双重校验，正确防住 manifest 里的 `..` 穿越。
3) `code_preview.py` 的 `_utf16_offsets` 偏移计算正确，把 `_format` 从 O(n²) 降到 O(n)。
4) `core/generator/rtl.py:1612-1613` 的 `SEL_SYNC` 联动修复是真 bug fix（此前 `sel_mode="comb"` 时 wrapper 仍传 `SEL_SYNC=1`，与 DUT 参数不一致）。
5) `verible.py:304` 补 `UnicodeError` 捕获正确（非 UTF-8 输出原先会抛出未捕获异常）。
6) `plan.py:88` 的 `snapshot()` 解耦：`GenerationPlan` 持有深拷贝 + 独立 topology，测试用 `AssertionError` 断言零重建。
7) 缓存淘汰逻辑本身无 bug：`move_to_end` + `popitem(last=False)` + bytes 记账，守卫保证 evict 循环必然终止，锁作用域正确。

---

## 6) 建议修复顺序

1) **P0-1 / P0-2**：先让测试基线可信（参数化 timeout）+ 修缓存门控接线 + 解决 `.BAT` wrapper 下缓存失效。前者一行，后者决定这台机器上每次生成省 5 次子进程。
2) **P0-3**：补 shutdown 协同，避免退出挂起。
3) **P1-1 / P1-2**：取消语义与异常兜底（异步模型的生命周期边界）。
4) **P1-5 / P1-6**：生成与加载的 IO 放大，直接改善"一次生成 19 秒"的体感。
5) **P1-3 / P1-4**：诊断完整性与性能退化。
6) 其余 P1/P2 排到后续迭代。

## 7) 验证边界

- 全部结论基于 offscreen 平台；真实桌面的原生窗口拖拽、混合 DPI、窗口合成效果未做人工检查。
- 本次未执行 HDL 仿真（需 `PLM_RUN_RTL_SIM=1`）。
- `test/maxpclk/config/` 下 controllers.csv、gen_flags.txt、pipe_signals.csv 在审查前已有未提交修改，与已提交 manifest 不一致；本次未覆盖这些用户改动。
- 未修改任何源文件，仅新增本文件；诊断脚本写在系统临时目录。
