# Code workspace

工作区包含九个独立项目仓库，以及由本仓库管理的 `misc/`。独立项目不再由
`code` 仓库重复跟踪，也不使用 Git 子模块。

| 目录 | 远端 |
| --- | --- |
| `cellgen/` | https://github.com/MaNan93/cellgen |
| `csrgen/` | https://github.com/MaNan93/csrgen |
| `ef/` | https://github.com/MaNan93/ef |
| `fizz/` | https://github.com/MaNan93/fizz |
| `pciegen/` | https://github.com/MaNan93/pciegen |
| `plm/` | https://github.com/MaNan93/plm |
| `ralf2xlsx/` | https://github.com/MaNan93/ralf2xlsx |
| `ramgen/` | https://github.com/MaNan93/ramgen |
| `vutils/` | https://github.com/MaNan93/vutils |
| `misc/` | 本仓库：https://github.com/MaNan93/code |

克隆本仓库后，在仓库根目录执行以下 PowerShell 命令，即可恢复九个项目：

```powershell
$projects = 'cellgen', 'csrgen', 'ef', 'fizz', 'pciegen', 'plm', 'ralf2xlsx', 'ramgen', 'vutils'
foreach ($project in $projects) {
    git clone "https://github.com/MaNan93/$project.git" $project
}
```

各独立项目在自己的目录中提交和推送；修改其他工具及资料时，在 `code` 中提交。
`pciegen` 的源码运行依赖同级的 `ramgen`、`vutils`，保留上述平级布局。
其余工具、原有示例及共享 Verible 程序见 [misc 说明](misc/README.md)。

## 统一运行

进入对应项目仓库后，统一使用 `uv run <工具名> ...`。各仓库的 `.python-version`
选择 Python 3.12，`uv.lock` 锁定依赖；可先执行 `uv sync --locked` 准备环境。

| 仓库 | 查看运行方式 |
| --- | --- |
| `cellgen/` | `uv run cellgen --help` |
| `csrgen/` | `uv run csrgen --help` |
| `ef/` | `uv run ef --help` |
| `fizz/` | `uv run fizz --help` |
| `pciegen/` | `uv run pciegen --help` |
| `plm/` | `uv run plm --help` |
| `ralf2xlsx/` | `uv run ralf2xlsx --help` |
| `ramgen/` | `uv run ramgen --help` |
| `vutils/` | `uv run vutils --help` |

Qt 界面分别通过 `uv run fizz` 和 `uv run plm-gui` 启动，无需额外的 uv 安装参数。
pciegen 通过 `uv run pciegen --project <工程目录>` 指定实际 PCIe 输入工程，
其余参数以各工具 `--help` 为准。PLM wheel 安装的 Qt 依赖仍为可选项。
