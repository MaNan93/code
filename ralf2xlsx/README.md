# ralf2xlsx v2.8 — RALF 寄存器描述 → Excel 表格

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
| `--sort source\|addr` | 行顺序：按 RALF 出现顺序（缺省）；`addr` 时先按 block base address，再按 block 内寄存器绝对地址排序 |
| `--addr-map 32bit\|33bit` | 指定当前 RALF 的源地址布局，并转换为目标寄存器地址布局；不传则自动判断（见下） |
| `--show-addr-map` | 逐寄存器打印“原地址 → 转换后地址”；默认只打印一行转换统计 |
| `--full-columns` | Excel 显示全部 29 个明细列；默认 block sheet 使用 7 个常用列的精简视图（CSV 始终为全量列） |
| `--show-violatile` | 在精简 Excel 表中显示 `Volatile` 列；默认不显示 |
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

### `--addr-map`

**从 v3.0 起默认开启**，把 RALF 中按 PCI Express DM Controller Databook 原生 AXI DBI 布局
编码的地址，转换为目标寄存器地址布局，对当前整个 RALF 生效。这个工具假定每个输入的
`.ralf` 都是这两种 DBI 地址布局之一——拿来处理跟这套编码无关的普通 RALF 文件，地址也会
被悄悄转换掉，不会报错。

源布局（32bit 用第一张源表，33bit 用第二张）：

* **不传 `--addr-map`（默认）**：自动判断——扫描 RALF 里所有 `block` 定义的名字，只要有
  一个包含 `VF1_PF0` 或 `VF_PF0`（不区分大小写），就判定整个文件是 33-bit 布局；否则按
  32-bit 布局处理。
* `--addr-map 32bit` / `--addr-map 33bit`：显式指定，覆盖自动判断的结果。

终端的 `address map:` 那一行会标注这次用的布局是"自动识别"还是"`--addr-map` 指定"。默认
只显示一行转换数量统计；需要核对每个寄存器的转换明细时，再加 `--show-addr-map`。

转换支持 CDM/PCIe Configuration、MSI-X Table/PBA、iATU 和 DMA；目标布局无法无损表示的
ELBI、Port Logic 或带非零 DMA 高位地址会保留原地址并报告 warning。`--sort addr` 使用转换
后的地址排序。

## 输出

| Sheet | 内容 |
| --- | --- |
| `Overview` | 第一张 sheet，block 导航（见下） |
| `RegisterMap` | 全部已实例化 block 的汇总主表：一个字段一行；**仅 `--no-sheet-per-block` 时生成**，否则用 `<block>` 分表代替，避免两份重复数据 |
| `<block>` | **默认生成**；system 实际实例化到的每个 block 各一张 sheet。未被 system 引用或被注释掉的 block 不输出；multi-domain block 仍是一张 sheet，由 `Domain` 列区分接口 |
| `Memories` | 存储器：地址、深度、位宽、容量、access、initial |
| `Enums` | 字段枚举值（名字 → 值） |

默认 block sheet 列：Register / Address / Offset / Field / Bits / Access / Reset。
需要 `Volatile` 列时使用 `--show-violatile`。
需要 MSB/LSB、原始 reset、约束、memory 关联及 HDL/VHDL 路径等高级列时，使用
`--full-columns`。CSV 输出不受影响，始终包含全部字段。

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




### 终端输出

`Summary`、block tree 和 warnings 都只输出到终端，不再写入 Excel sheet。Excel 只保留寄存器数据相关 sheet。

示例：

```text
Summary:
  source: .../example.ralf
  top: soc
  registers: 12 | fields: 32 | memories: 2 | warnings: 0
Block tree:
  soc
  ├─ uart[0]  (base=0x00004000, def=uart)
  ├─ uart[1]  (base=0x00004400, def=uart)
  ├─ dma      (base=0x00008000)
  └─ bridge   (base=0x0000C000, domain=pci, ahb)
```

`def=` 只在实例名跟定义名不一样时才显示（比如数组展开出来的 `uart[0]`/`uart[1]`，底层定义还是叫 `uart`；或者 `block foo=my_inst` 这种改名实例化）。

解析/展开 warning 也跟在终端输出中。使用 `-q/--quiet` 可关闭这些非错误信息。

`--sort addr` 同时影响 Block tree 的兄弟节点顺序（按各自 base address 排）和 Excel 里的行/Overview 顺序，
不是只对 Excel 生效。


> `Registers` 汇总 sheet 已移除。Excel 默认只保留 `Overview`、每个 block 的独立 sheet，以及可选的 `Memories` / `Enums`；
> 只有 `--no-sheet-per-block` 时才会改成单张 `RegisterMap` 代替按 block 分表。


> Block 独立 sheet 名只使用实例名，不包含 system/父 block 路径。例如 `soc.pcie.phy` → `phy`，
> `soc.uart[0]` → `uart_0`。如果出现重名，则自动追加 `_1`、`_2` 等后缀。


> Block tree 的附加信息统一使用圆括号，并按最长 tree 文本对齐括号起始列。


### Overview

Excel 第一个 sheet 固定为 `Overview`，用于 block 导航。每个实际实例化 block 一行，
只显示 Block 和 Base Addr。点击 Block 单元格会直接跳转到对应 block sheet。
使用 `--sort addr` 时，Overview 按 block base address 排序。
