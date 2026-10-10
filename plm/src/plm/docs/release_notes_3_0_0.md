# PLM 3.0.0 更新说明

发布日期：2026-10-10。当前开发版本从 `2.0.8` 升级为 `3.0.0`。
本次合并包含 `plm-ui-refactor` 分支尚未进入 main 的界面、生成器和测试改动。
由于生成 RTL 的复位端口接口发生变化，采用大版本号。

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
