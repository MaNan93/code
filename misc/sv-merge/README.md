# sv-merge

将 Verilog / SystemVerilog filelist 合并为单文件的 Python 工具。默认保留文件顺序、条件编译和编译指令，在引用位置递归展开字面量 include；不进行宏求值或完整语法解析。

## 使用

```bash
python3 -m pip install .
sv-merge -F src/DWC_pcie_ctl.lst -o one.sv -v
```

无需安装也可以从项目目录运行：

```bash
PYTHONPATH=src python3 -m sv_merge -F /path/to/files.f -o one.sv
```

`-F` 内的源文件和 include 目录相对于 filelist 所在目录解析；`-f` 内的源文件相对于执行目录解析。嵌套 filelist 的路径相对于包含它的列表的有效基准目录解析。支持环境变量、嵌套 `-f` / `-F`、带引号的路径、`+incdir+`、`+define+` 和显式 `-v file`。

多个 `-f` / `-F` 按命令行出现顺序处理，显式源文件参数追加到后面。重复列出的源文件仍保留。缺失输入、循环 filelist 和无法展开的 include 默认返回非零退出码。

## 合并行为

- 默认保持 filelist 顺序，不自动将头文件、package 或 undef 文件搬到其他位置。
- 对独立一行的 `` `include "file.svh" ``，依次搜索当前源文件目录和 include 目录，按实际路径展开；同名不同目录的文件不会混淆。
- 不全局去重 include。仅对完整文件受 `ifndef` / `define` / `endif` 保护、且 guard 已确定定义的情况省略重复内容。条件分支内不能确定的包含仍展开；遇到 `undef` 时撤销已知状态。
- filelist 的 `+define+NAME` / `+define+NAME=value` 按顺序写为输出开头的宏定义。带双引号的值保留空格和 `+`。这与某些仿真器“命令行定义始终覆盖源码定义”的行为不同；依赖该行为时仍需向编译器传递原宏选项。
- 不插入 `default_nettype wire`，保留源码编译指令。
- 输出不得与源文件、展开的头文件或 filelist 相同，符号链接和硬链接也会检查。先生成临时文件，全部成功后原子替换输出；失败保留原输出。
- 默认保留注释；`--strip-comments` 删除行注释和块注释，保留换行使行号稳定，字符串字面量内的 `//` 与 `/*` 原样不动，`//` 行尾反斜杠续行按 IEEE 1800 一并删除。未闭合块注释报错而不是静默吞掉。该模式下工具自身写入的注释（FILE: / include guard 提示）也省略，需要溯源时配合 `--line-directives`。
- `-y` 库目录不会自动收集，工具会警告。显式 `-v` 文件会作为源码合并，库文件按需加载的语义不会保留。

## 可选参数

| 参数 | 行为 |
| --- | --- |
| `-I DIR` | 增加 include 搜索目录，可重复 |
| `--sort-dependencies` | 显式启用 package 依赖排序，可能改变宏状态 |
| `--top FILE` | 配合排序，将匹配的文件路径或文件名移至清理文件前 |
| `--keep-includes` | 保留原始 include，仍需外部头文件和搜索目录 |
| `--no-neutralize-includes` | `--keep-includes` 的兼容别名 |
| `--line-directives` | 输出 SV `line 指令，将诊断位置映射回源文件 |
| `--strip-comments` | 删除 `//` 与 `/* */` 注释（行号保持不变，字符串字面量不动） |
| `--no-comments` | `--strip-comments` 的兼容别名 |
| `--dry-run` | 检查根输入并打印文件顺序，不写输出；不检查递归 include |
| `-v` / `--verbose` | 打印统计信息 |

可选的 package 排序识别 package 声明、import 以及 `pkg::symbol` 引用，使用稳定的原始文件次序打破并列依赖；重复 package 和依赖环报错。它基于词法扫描，不评估条件编译，因此应仅在需要时启用，并用实际编译器验证。

## 支持范围

工具接受 UTF-8 输入，不静默丢弃无法解码的字节。它不是完整的 SystemVerilog 预处理器：宏生成的 include、宏生成的编译指令、跨文件的未闭合条件编译，以及循环 include 不在支持范围内。完整 guard 循环也可能被拒绝。默认会访问条件分支中的字面量 include，即使后续编译时该分支不启用；这类工程可使用 `--keep-includes`。

多文件 compilation unit、库加载方式和工具特有选项不能全部映射到单文件。对 `__FILE__` / `__LINE__` 有要求时应启用 `--line-directives` 并验证编译器行为。生成成功只说明合并成功，不代表语法、链接或功能等价验证通过。

从 1.0 初始实现迁移时注意：默认排序、include 处理和 nettype 隔离行为已经改变。不要仅为了复现旧输出而忽略宏上下文。

## 验证

```bash
PYTHONPATH=src python3 -m unittest discover -s tests -v
vericom -2012 -sverilog one.sv
```

本次在 945 个源文件的 DWC PCIe 工程上验证：默认合并输出约 32 MiB，Vericom X-2025.06-SP1 编译结果为 0 errors、2 warnings。该结果仅适用于已验证的工程配置，不能保证任意输入零错误。

## 与 Verible 加扰配合

```bash
verible-verilog-obfuscate < one.sv > obf.sv
```

本机 Verible 加扰会破坏该工程中的宏名字拼接（双反引号）和部分宏引用。合并器的 include 展开不会展开这些宏，也不能修复加扰器的名字映射。需要用支持该工程的完整 SV 预处理器展开宏后再加扰，并重新编译验证；本机 `verible-verilog-preprocessor` 未能完成这份工程的预处理。
