# ralf2xlsx v2.7 — RALF 寄存器描述 → Excel 表格

把 Synopsys `ralgen` 用的 `.ralf` 文件解析、展开层次、算出绝对地址和位域，
输出成一份可以直接发给设计/软件的 Excel 寄存器表。

## 安装

推荐通过 wheel 安装：

```bash
pip install ralf2xlsx-*.whl
```

wheel 会自动安装运行依赖 `openpyxl`，并注册命令行入口：

```bash
ralf2xlsx --help
```

## 用法

```bash
ralf2xlsx top.ralf -t soc -o regmap.xlsx
ralf2xlsx a.ralf b.ralf c.ralf -o outdir/         # 批量独立转换
ralf2xlsx top.ralf --check --strict                # CI 卡关：解析有告警就失败
ralf2xlsx top.ralf --dump > new.txt                # 文本化后跟上一版 diff
```

| 选项 | 说明 |
| --- | --- |
| `-t, --top` | 顶层 `block` / `system` 名（同 ralgen 的 `-t`），可给多次；不给则展开所有顶层 system（没有 system 就所有 block） |
| `-o, --out` | 单文件时指定输出 `.xlsx`；多文件时指定输出目录；缺省时各文件在源文件旁生成同名 `.xlsx` |
| `-I, --incdir` | `source` 的搜索目录，可多次（同 ralgen 的 `-I`） |
| `-s, --sheet-per-block` | 每个实例化 block 生成独立 sheet（默认已开启；保留用于兼容旧命令） |
| `--no-sheet-per-block` | 关闭每个 block 的独立 sheet，只保留汇总类 sheet |
| `--csv FILE/DIR` | 额外导出字段表 CSV（UTF-8 BOM）；单文件时是文件名，多文件时是输出目录 |
| `--base ADDR` | 顶层基地址，缺省 0，支持 `0x1000` / `'h1000` |
| `--addr-mode byte\|word` | RALF 里 `@offset` 的含义，见下 |
| `--flavor auto\|uvm\|vmm` | field access mode 校验方言：默认 `auto` 接受 UVM/VMM 并集 |
| `--sort source\|addr` | 行顺序：按 RALF 出现顺序（缺省）或按地址 |
| `--no-expand-arrays` | 数组只出一行 `name[lo:hi]`，大数组不撑爆表格 |
| `--check` | 只解析 + 展开，不生成 Excel |
| `--dump` | 把展开后的寄存器表打成纯文本（便于 diff / code review） |
| `--strict` | 有 warning 即失败，退出码 3，不产出文件 |
| `-q, --quiet` | 不在终端打印 warning（仍写进 Warnings sheet） |

退出码：`0` 成功 / `2` 解析失败或缺依赖 / `3` `--strict` 下有告警。

### `--addr-mode`

RALF 的 `@offset` 单位取决于所在 block 的 `bytes`（总线宽度）：

* `byte`（缺省）：`@'h04` 就是字节偏移 0x04。手写的 / 从 IP-XACT 转来的 RALF 基本都是这种，
  对应 `ralgen -B`（`-gen_byte_addr`）生成的模型。
* `word`：`@'h04` 表示第 4 个地址单元，字节地址 = `4 × bytes`。这是 `ralgen` **不加** `-B` 时的语义。

两种模式下自动分配的地址（没写 `@` 的寄存器）都会按总线宽度对齐递增。

## 输出

| Sheet | 内容 |
| --- | --- |
| `Summary` | 源文件、包含的文件数、顶层、统计；各 block/domain 的基地址、总线宽度、endian |
| `BlockTree` | system/block 实例层级树；显示 Instance Path、Definition、Base Addr、Domain(s) 和 backdoor path。`block a=b` 会显示 Definition=`a`、Instance=`b` |
| `RegisterMap` | 全部已实例化 block 的汇总主表：一个字段一行 |
| `<block>` | **默认生成**；system 实际实例化到的每个 block 各一张 sheet。未被 system 引用或被注释掉的 block 不输出；multi-domain block 仍是一张 sheet，由 `Domain` 列区分接口 |
| `Registers` | 寄存器级汇总：一个寄存器一行，带 attributes 和在 RALF 里的行号 |
| `Memories` | 存储器：地址、深度、位宽、容量、access、initial |
| `Enums` | 字段枚举值（名字 → 值） |
| `Warnings` | 解析/展开过程中的全部告警，跟着产物走 |

主表列：Block / Domain / Register / Kind / Address / Offset / Width(bit) / Field / Bits /
MSB / LSB / Size / Access / Reset / Reset(RALF) / Soft Reset / Volatile / Enum /
Constraint / Shared / R-W Limit / Memory / Memory Offset / Backdoor / HDL Path /
VHDL Path / Local Path / Field Desc / Register Desc。

## 支持的 RALF 语法

* 构件：`field` `register` `regfile` `memory` `virtual register` `block` `system` `domain`
* 属性：`bits` `bytes` `access` `reset`/`hard_reset` `soft_reset` `volatile` `enum`
  `constraint` `doc` `attributes` `endian` `left_to_right` `shared` `size` `initial`
  `cover` `coverpoint` `cross` `noise`
* 实例化：`name=rename`、数组 `[n]` / `[m:n]`、`(hdl_path)`、`@offset`、`+incr`、
  `@none`、`read` / `write` 限定
* Tcl：`#` 注释、`set` / `incr`、`source`（`-I` 搜索 + 递归检测）、`[expr ...]`、
  简单 `for` / `if`、反斜杠续行

### 两个容易踩的语义

* **命令按 Tcl 换行/分号结束**。所以 `source x.ralf`、`bits 8` 这种不写分号的写法都能正确解析，
  `{` 另起一行也认。
* **`left_to_right`** 按 UG Example A-5 ≡ A-6 实现：从高位侧拼接，整体向 bit0 对齐
  （基准是字段总位宽，不是寄存器位宽）。`unused` / `reserved` 字段按 UG 规定记为只读。

## 已知限制

* 只覆盖 RALF 里 Tcl 的常用写法；`proc` / `switch` / `foreach` / 命令替换不支持，
  遇到不认识的东西打 warning 并跳过，不会中断（想卡死就用 `--strict`）。
* `cover` / `coverpoint` / `cross` / `constraint` 只记名字，不展开内容。
* 虚拟寄存器不占地址空间，Address 列留空；`@none` 的寄存器同理。

## 例子

`example.ralf` 覆盖了 field 复用、enum、regfile 数组、`for` 循环生成寄存器、
双 domain 的 bridge、block 数组、memory。

```bash
ralf2xlsx example.ralf -t soc -o example.xlsx -s
```


### BlockTree

生成的 Excel 会额外包含 `BlockTree` sheet，只显示从所选 top/system 实际可达的 block 实例。例如：

```text
soc
├─ uart[0]
├─ uart[1]
├─ dma
└─ bridge
```

若 RALF 中写的是 `block a=b (...) @'h4;`，tree 中的实例层级使用 `b`，同时 `Definition` 列记录 `a`。
未被 system 实例化、或在 system 中被注释掉的 block 不会出现在 BlockTree，也不会生成对应 block sheet。

> Excel sheet 名不允许使用 `[` / `]`。因此数组 block 实例 `soc.uart[0]` 在 `BlockTree` 中仍保持原始实例名，
> 对应独立 sheet 名会转换为 `soc.uart_0`。
