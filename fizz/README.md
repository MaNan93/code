# fizz - SV 文件合并工具

SV file merger with VCS Protect, Obfuscator and RLskit support. Qt (PyQt5)
desktop front end, styled on SAP Horizon design tokens (the same visual
language as the [plm](../plm) Qt frontend).

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

### As a Library

```python
from fizz.frontend.qt.main import main

main()
```

Or drive `fizz.core` directly (parsing/merging/obfuscate/vcs/rlskit/postsim
logic, with no GUI dependency) from your own script or a future CLI.

## Configuration

配置文件保存在 `~/.fizz.ini`，支持通过 GUI 的 File → preference (Ctrl+P) 进行编辑。

## Requirements

- Python >= 3.12
- PyQt5 >= 5.15 (installed automatically via `pip install fizz`)
- 可选: `verible-verilog-preprocessor`, `verible-verilog-obfuscate`, `vcs`, `curl`, `tar`, `cksum`

## License

MIT
