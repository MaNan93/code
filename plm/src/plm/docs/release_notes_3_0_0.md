# PLM 3.0.0 更新说明

发布日期：2026-10-10。当前开发版本从 `2.0.8` 升级为 `3.0.0`。
本次合并包含 `plm-ui-refactor` 分支尚未进入 main 的界面、生成器和测试改动。
由于生成 RTL 的复位端口接口发生变化，采用大版本号。

此前的小版本改动见本文末尾的“此前的小版本更新记录”。

## 新增独立的 perst_n 复位

`perst_n` 与原有 `rst_n` 使用相同的控制器归属选择和 DPR 覆盖规则，
但两路信号独立，互不影响。新增端口如下：

| 位置 | 新端口 | 用途 |
| --- | --- | --- |
| 顶层及 connection wrapper | `<controller>_perst_n` | 每个控制器的低有效复位输入 |
| 顶层及 connection wrapper | `phy_perst_n[NL-1:0]` | 每条 PHY lane 的低有效复位输出 |
| 启用 DPR 的顶层及 wrapper | `dpr_perst_n` | DPR 通路的低有效复位输入 |
| reset mux 内部 | `ctrl_perst_n` / `phy_perst_n` | 按 lane group 路由第二路复位 |

这些端口同时适用于 bus/flat 接口和两种 PCLK 模式，无需在
`pipe_signals.csv` 增加复位行。复位通过原始目标归属 `dec_tgt` 路由；
多源选择无有效归属时输出为 0，DPR 被选中时采用 DPR 复位输入。
单源、无 DPR 的 lane group 继续直接连接唯一控制器，与原有 `phy_rst_n` 相同。
原有选择同步和时钟切换仍使用 `ctrl_rst_n`。

生成的 testbench 连接新端口，并检查各模式下的归属、独立脉冲、释放和
DPR 覆盖，统计新增 `err_perst` 类别。名称校验会阻止用户信号与这些固定端口冲突。

## Generation 命名前缀

Generation 页面新增三个输入框，保存到工作区 `config/gen_flags.txt`：

| 设置 | 作用范围 | 示例 |
| --- | --- | --- |
| `module_prefix` | 模块、公共模块、package、testbench 名称及引用 | `soc_` → `soc_pipe_lane_mapper` |
| `file_prefix` | 所有生成的 `.sv` 文件及 flist/makefile 引用 | `rtl_` → `rtl_pipe_lane_mapper.sv` |
| `macro_prefix` | 五个 PLM 宏及对应编译 define | `SOC_` → `SOC_DUMP_FSDB` |

宏清单为 `PIPE_USE_ICG_CELL`、`PIPE_ICG_CELL`、`PIPE_USE_CLKOR_CELL`、
`PIPE_CLKOR_CELL`、`DUMP_FSDB`。前三类名称的前缀分别独立设置，
按原样拼接，不自动添加下划线。空前缀保留旧名称。

输入框支持配置恢复、撤销/重做和修改状态。非法前缀在保存或替换生成结果前
报错；切换前缀会使旧输出过期，再生成时同步替换 RTL/TB 并清理旧文件名。
用户端口、信号、字段、实例和参数名称保持原样；`flist.f`、`makefile`、
`manifest.json` 的文件名也保持原样。

CLI 通过显式参数使用同样功能，仍不读取 Qt 的 `gen_flags.txt`：

```text
plm generate --config /path/to/workspace --module-prefix soc_ --file-prefix rtl_ --macro-prefix SOC_
```

前缀的字符限制、完整作用范围和集成说明见开发文档
`docs/generation_prefixes.md`。

## 界面与代码质量

- Configuration 和 Log 内容距离窗口布局边缘保留 4 个逻辑像素。
- ArtifactsPanel 四边统一为 1 像素 `#D1D9E0` 框线、16 像素圆角；
  裁剪内部内容，修复预览背景覆盖圆角框线的问题。
- 合并已有的导航图标/文字对齐、紧凑控件、表格与弹出控件尺寸、
  bus/flat 接口选项，以及 Qt 绘制性能优化。
- 清理无用导入，修复测试等待已发出信号的竞态；Windows offscreen 测试
  在字体库为空时加载真实字体，防止无文字截图误通过。
- 增加独立的面板几何、边框像素、前缀持久化与输出、复位路由及互不干扰测试。
  Artifacts 圆角测试包含取消裁剪的负向检查，确认能发现原始问题。

## 从 2.x 迁移

1. 重新生成成套 RTL/TB，更新已有顶层和 wrapper 实例的端口连接。
   每个控制器接入 `<controller>_perst_n`，接出 `phy_perst_n`；启用 DPR 时
   还需接入 `dpr_perst_n`。暂不使用第二路复位时，应将其输入连接到 `1'b1`。
   新端口始终生成，旧实例需要补充接线。
2. 不要把 `perst_n` 添加到 `pipe_signals.csv`；若已有同名自定义信号，
   需先重命名，以免与固定端口冲突。
3. 旧工作区没有前缀配置时继续使用原来的模块、文件和宏名称。设置前缀后，
   外部模块引用、编译文件列表及 ICG/clock-OR 集成的宏定义应同步更新。
   生成的 makefile 会自动使用带前缀的 `DUMP_FSDB`。
4. 生成器版本改变会使历史 manifest 过期；请重新生成，不要混用新旧 RTL/TB。

## 验证与构建

功能改动后的完整测试共 319 项：317 通过，2 项可选 RTL 仿真跳过。
前缀生成 RTL 的 Verilator 语法检查覆盖 8 种 PCLK/DPR/bus-flat 组合，均通过。
面板回归已覆盖 100%、125%、200% 缩放。

本机可选 `perst_n` 编译仿真的结果比较输出为 PASS，但 Verilator 进程随后
以 Windows 异常码 `0xC0000005` 退出，因此该项未计为通过。

发布构建使用 Python 3.12：先构建新 sdist，再从该 sdist 构建 wheel；
`scripts/check_wheel.py` 在独立环境中检查包内容、CLI 和 Qt 生成流程。

```text
uv build --sdist --python 3.12 --out-dir dist
uv build --wheel dist/plm-3.0.0.tar.gz --python 3.12 --out-dir dist
uv run --python 3.12 python scripts/check_wheel.py dist/plm-3.0.0-py3-none-any.whl --sdist dist/plm-3.0.0.tar.gz
uv pip install "dist/plm-3.0.0-py3-none-any.whl[qt]"
```

## 此前的小版本更新记录

以下记录根据发布提交、已有更新文档和本地构建产物核对。
`r4`、`r6`、`r7` 是迭代标记，其中 `r4` 沿用 `2.0.5`，不代表新的包版本。

### 2.0.8（2026-10-10，本地构建）

- 将 Configuration 和 Log 内容到窗口布局边缘的距离统一为 4px。
- ArtifactsPanel 增加四边框线，并通过裁剪内部内容补齐圆角处被覆盖的框线。
- 重新检查代码质量，增加面板几何、边框像素、真实文字绘制及交互回归测试；
  修复信号等待竞态和 Windows offscreen 字体缺失导致的测试误判。
- Generation 新增 `module_prefix`、`file_prefix`、`macro_prefix`，
  同时支持配置保存与恢复、CLI 参数和生成结果中的名称及引用更新。
- 构建并验证 `plm-2.0.8-py3-none-any.whl`；随后增加独立 `perst_n`
  复位及其测试，并重新构建验证同版本 wheel。

该版本曾在本地构建，没有独立发布提交；上述改动与新增复位接口最终一起
进入 `3.0.0` 的发布提交 `169889d`。因此 Git 中包版本从 `2.0.7`
直接变为 `3.0.0`，本文保留实际发生过的 `2.0.8` 迭代记录。

### 2.0.7（2026-10-09）

- 修复导航图标随文字及折叠状态变化而偏移的问题，让图标持续对齐折叠轨道中心。
- 统一项目行与导航项的图标、文字起点和间距，增加截图像素及双向动画回归检查。
- 发布后仍沿用 `2.0.7`，继续调整表格与 Artifacts 的样式和交互，
  优化 Qt 绘制、配置更新及预览行为，并增加性能分析脚本和测量报告。

发布提交：`25c2899`；同版本后续改动：`8aa6f51`。
详细记录：仓库 `docs/r7_release_notes.md` 和
`docs/ui_style_performance_2026-10-09.md`。

### 2.0.6 / r6（2026-10-09）

- 修复主窗口、标题栏、导航栏及 Artifacts 的布局和折叠交互，统一控件、表格、字体及图标样式。
- 采用统一冷灰色板，调整选中态、悬停态、交替行及弱化文字的对比度。
- 缓存按钮尺寸与窗口阴影，合并表格更新和校验；按需创建 Formatter 参数表，
  在独立文档对象中完成解析，减少界面加载时的重复工作。
- Generation 和 CLI 增加 Connection 的 `bus` / `flat` 接口选项，默认 `bus`；
  `flat` 将 lane 信号展平为一维向量，lane 0 位于低位。

发布提交：`fda1026`。详细记录：仓库 `docs/r6_release_notes.md`。

### 2.0.5（2026-10-08，后续沿用至 r4）

- 增加项目重新加载功能，重新读取磁盘配置并将输出标记为过期，下一次生成强制刷新。
- 修复项目菜单打开期间操作按钮隐藏、悬停状态和菜单边缘/阴影等问题。
- 同版本后续调整全局字体、控件、表格、下拉菜单、项目行及间距，统一紧凑布局。
- r4 继续统一桌面 UI 和交互，修复 Formatter 行内控件初始高度，
  清理无调用方的 API 及已被校验禁止的多源 Controller PCLK 生成分支。

发布提交：`cb5a79f`；紧凑界面改动：`54ccc0f`。
后续 r4 记录：仓库 `docs/r4_ui_changes.md`；r4 改动期间包版本仍为 `2.0.5`。

### 2.0.4（2026-10-08）

- 增加 `plm --version` 和统一的包版本导出，更新安装说明及发布检查。
- 修复 Artifacts 生成前后基线和差异预览，完善文件按需加载及对应回归测试。
- 调整界面样式、图标、设置和文档页面，改善生成过程中的显示与交互。
- 构建并验证 wheel 和 sdist。

发布提交：`5d4a484`。
