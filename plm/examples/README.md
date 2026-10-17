# 可编辑示例

更新日期：2026-10-17。每套示例的输入位于 `<示例>/config/`；生成后才出现同级
`rtl/` 和 `tb/`，这些输出不进入版本管理。自动测试使用独立的
[`tests/fixtures/`](../tests/fixtures/README.md)，不会覆盖这里的配置。

## 启动与生成

在仓库的 `plm/` 目录执行：

```powershell
uv sync --extra qt --locked
uv run plm validate --config dpr
uv run plm generate --config dpr --dpr
uv run python run.py -gui
```

| 示例 | 用途 | 相对 CLI 默认值需要追加的选项 |
| --- | --- | --- |
| `bifurcate` | 通道分组与模式切换 | 无 |
| `dpr` | DPR overlay | `--dpr` |
| `finegrain` | 较细颗粒度的通道映射 | 无 |
| `maxpclk` | PHY input 时钟架构 | `--arch serdes --pclk-mode pclk_as_phy_input` |

例如生成 `maxpclk`：

```powershell
uv run plm generate --config maxpclk --arch serdes --pclk-mode pclk_as_phy_input
```

CLI 不读取 `config/gen_flags.txt`；该文件只记忆 Qt 中保存的生成选择。
命令行的 DPR、架构、Connection 总线类型及命名前缀应通过相应参数传入。
只传 `--arch serdes` 时，CLI 也会自动选择匹配的 PCLK 模式。

安装 GNU Make 的环境可使用 `make list`、`make <示例>` 或 `make`。
顶层 Makefile 已为 `dpr` 和 `maxpclk` 配置对应选项。Windows 未安装 Make 时，
直接使用以上 CLI 命令；`make clean` 只删除示例的 `rtl/`、`tb/` 输出。

## 从旧目录迁移

示例已从 `test/<示例>/config/` 原样移动到 `examples/<示例>/config/`。

- 按名称调用的 `--config dpr`、`make dpr` 无需更改。
- 写死的 `test/dpr` 或 `test/dpr/config` 改为 `examples/dpr` 或
  `examples/dpr/config`；下游 RTL/TB 引用路径也相应更新。
- Qt 自动发现 `examples/`，仍兼容已有旧 `test/`、`configs/` 下的工作区，
  也可通过“打开项目”选择任意外部工作区。
- wheel 和源码发行包不包含可编辑示例；安装包用户可创建或打开自己的工作区。

完整参数见[工具使用说明](../src/plm/docs/tool_usage.md)，
操作方式见[Qt 使用指南](../src/plm/docs/qt_frontend_guide.md)。
