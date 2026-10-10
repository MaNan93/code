# fizz - SV 文件合并工具

SV file merger with VCS Protect, Obfuscator and RLskit support. Qt (PyQt5)
desktop front end, using the current [plm](../plm) visual style: a light gray
collapsible sidebar, white workspace, blue primary actions and Lucide icons.
Fizz runs independently and does not require PLM to be installed.

## Features

- **合并**：从 `generalMessage.txt` 提取 included/source file，按顺序合并为单个文件
  - 支持目录/文件名通配过滤
  - 自动注释掉 `` `include `` 行
  - 可选 verible strip-comments
  - 支持 protect pragma 插桩
- **VCS Protect**：调用 `vcs -ipprotect` 对源文件做加密保护
- **Obfuscator**：调用 `verible-verilog-obfuscate` 做混淆，支持 load_map/save_map
- **RLskit**：目录复制、打包 tar.gz、计算 cksum、可选 FTP 上传，支持 FTP 目录浏览与 Release Note 编辑
- **后仿分析**：递归搜索日志文件，提取 Timing violation 并支持 waive

## Installation

```bash
pip install fizz
```

Or from source:

```bash
cd fizz
pip install -e .
```

## Usage

### Launch GUI

```bash
fizz
```

The existing development environment can also launch it directly:

```powershell
cd D:\Users\man\Desktop\code\fizz
.\.venv\Scripts\python.exe -m fizz.frontend.qt.main
```

The five workflows are available in the sidebar. Forms scroll at smaller window
sizes; output panels can be resized by dragging their separator. Window size,
selected workflow and sidebar state are restored on the next launch.

| Shortcut | Action |
| --- | --- |
| `Ctrl+1` to `Ctrl+5` | Switch workflows |
| `Ctrl+B` | Collapse or expand the sidebar |
| `Ctrl+P` | Open settings |
| `Ctrl+S` in the Release Note editor | Save the release note |
| `F1` | Open usage documentation |

### As a Library

```python
from fizz.frontend.qt.main import main

main()
```

Or drive `fizz.core` directly (parsing/merging/obfuscate/vcs/rlskit/postsim
logic, with no GUI dependency) from your own script or a future CLI.

## Configuration

配置文件保存在 `~/.fizz.ini`，支持通过侧栏「设置」或 `Ctrl+P` 编辑。
界面布局单独使用 Qt `QSettings` 保存，不改变已有工作流配置格式。

## Frontend structure

The frontend follows PLM's separation of window composition, views, controllers,
models, services and style tokens:

```text
src/fizz/frontend/qt/
├── main.py                 # QApplication entry point
├── main_window.py          # Window chrome, navigation and page composition
├── controllers/            # Workflow actions and signal coordination
├── models/                 # Workflow metadata
├── services/               # Background tasks and layout persistence
├── styles/                 # Shared design tokens and app.qss
├── views/                  # Five workflow pages, navigation and log panels
├── widgets/                # Shared controls, icons and dialogs
└── assets/icons/           # Vendored Lucide SVG icons
```

Algorithms and configuration remain in `fizz.core`. `qt/workers.py` retains
compatibility imports for workers now implemented in `services/tasks.py`.

Run the regression suite and capture sample screens from the `fizz` directory:

```powershell
.\.venv\Scripts\python.exe -m unittest discover -s tests -v
.\.venv\Scripts\python.exe scripts/capture_ui.py --output ui-screenshots
```

Tests and captures use temporary configuration and sample files. VCS,
Obfuscator and FTP connections are mocked in regression tests; production
integration still requires the corresponding tools and server.

## Requirements

- Python >= 3.12
- PyQt5 >= 5.15 (installed automatically via `pip install fizz`)
- 可选: `verible-verilog-preprocessor`, `verible-verilog-obfuscate`, `vcs`, `curl`, `tar`, `cksum`

## License

MIT
