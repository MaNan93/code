# csrgen

将 Excel 字段表转换为可综合的 **SystemVerilog APB3 寄存器模块**，生成文件为 `.sv`。
数据位宽固定 32 bit，不包含 `PSTRB`。RTL 地址位宽参数为 `AW`，默认 16。端口和内部信号统一声明为 `logic`；可写字段及 `prdata` 由时序逻辑直接驱动，不生成额外的 `*_q` 寄存器或端口连接赋值。
仅依赖 `openpyxl>=3.1,<4`，兼容你已有的 **openpyxl 3.1.5**；不使用 xlrd、xlwt。
Python 版本要求 3.10 或更高。

逐版本的改动、历史行为差异和升级说明见 [Release Notes](RELEASE_NOTES.md)，当前版本为 0.1.11。

## 直接运行

已有 openpyxl 时，可以直接运行，无需安装工具包：

```powershell
cd D:\Users\man\Desktop\code\csrgen
python csrgen.py .\examples\registers.xlsx -o .\generated\apb_csr.sv
```

指定 sheet、地址位宽、模块名和输出路径：

```powershell
python csrgen.py .\input.xlsx --sheet sheet1 --aw 20 --module device_csr -o .\generated\device_csr.sv
```

默认 `--sheet sheet1`、`--aw 16`，模块名为 `apb_csr`；输出到当前工作目录的 `apb_csr.sv`。

模块名前缀和文件名前缀分别设置，互不影响：

```powershell
python csrgen.py input.xlsx --module-prefix device --file-prefix rtl
```

上例输出 `rtl_apb_csr.sv`，文件内模块名为 `device_apb_csr`。

| 参数 | 模块名 | 文件名 |
| --- | --- | --- |
| 不指定前缀 | `apb_csr` | `apb_csr.sv` |
| `--module-prefix device` | `device_apb_csr` | `apb_csr.sv` |
| `--file-prefix rtl` | `apb_csr` | `rtl_apb_csr.sv` |
| 两者都指定 | `device_apb_csr` | `rtl_apb_csr.sv` |

前缀与 `apb_csr` 之间自动加一个 `_`。模块名必须是合法 Verilog 标识符；文件名前缀不能包含路径分隔符或非法文件名字符。
已有的 `--module/-m` 和 `--output/-o` 仍可指定完整名称；`--module` 与 `--module-prefix` 互斥，`--output` 与 `--file-prefix` 互斥。
指定完整 `--module` 且未指定输出名或文件前缀时，默认文件名仍与该完整模块名一致。

`--aw` 设置生成 RTL 的默认参数值，并检查表中的地址是否能用该位宽表示。支持 2～32 bit。
实例化 RTL 时仍可覆盖 `AW`，但须能容纳表中的所有地址。地址宽度和表格地址在 Python 生成阶段检查；RTL 不包含 `initial` 参数检查段或 `synthesis translate_off/on` 指令。
sheet 名优先精确匹配，否则忽略大小写匹配，例如默认值可以读取 `Sheet1`。

生成示例表格（内容与你提供的截图一致）：

```powershell
python csrgen.py --template .\examples\registers.xlsx
```

也可以安装为命令：

```powershell
python -m pip install -e .
csrgen input.xlsx --sheet sheet1 --aw 16 -o apb_csr.sv
```

## Excel 格式

严格按模板的固定位置读取，**不匹配或检查表头文字**：第 1 行直接跳过，第 2 行开始读取数据。

| Excel 列 | 内容 |
| --- | --- |
| B | Offset，十六进制字节地址 |
| C | signal，字段名 |
| D | Rst Value，字段复位值 |
| E | bit，字段位段 |
| F | access，访问属性 |
| G | description，可留空 |

A 列和 G 列之后的列忽略。支持空行和合并 Offset 单元格；列位置和数据起始行须保持模板格式。

| Offset(hex) | signal | Rst Value(hexadecimal) | bit | access | description |
| --- | --- | --- | --- | --- | --- |
| 0x0 | a | 1 | 0 | rw | 控制位 |
| | b | 1 | 2:1 | ro | 外部状态 |
| | c | 0 | 30:3 | rw1c | 写 1 清零 |
| 0x4 | a1 | 1 | 0 | rw | 控制位 |
| | b1 | 1 | 2:1 | ro | 外部状态 |
| | c1 | 0 | 30:3 | rw1c | 写 1 清零 |
| | reserved | 0 | 31 | ro | 保留位 |

- Offset 留空时沿用上一个 Offset；空行不影响这个规则。Offset 是**字节地址**，必须 4 字节对齐。
- Offset、复位值的文本按十六进制解析，支持 `0x10`、`10`、`FF`。Excel 数字单元格直接使用数值：数值 `10` 是十进制 10，文本 `10` 是十六进制 0x10。建议这两列设为文本格式。
- `bit` 支持 `0`、`30:3`、`[30:3]`，范围必须在 31:0 内，字段之间不能重叠。
- 复位值是**字段自身的值**，不是移位后的整寄存器值，必须能用字段宽度表示。
- 字段名必须是合法且全模块唯一的 Verilog 标识符，不能与 APB 端口、内部名称或 `*_hwset` 端口重名。
- `reserved` 可重复出现，始终按 `ro/tie0` 处理：不生成端口或存储寄存器，读回 0，软件写入忽略。
- 表中 `reserved` 的属性、复位值若填错、留空或无法解析，只输出包含行号、地址的警告，仍按 `access=ro`、复位值 0 继续生成。
- 每个地址对应完整的 32 bit 寄存器。未定义的高位、低位、字段间的空隙都自动按 `reserved` 处理，生成 RTL 时明确标注 `ro, tie0`。例如最高只定义到 bit 15，则 `[31:16]` 全部为保留位。
- `reserved` 的位段越界或与其他字段重叠仍属于结构错误，会停止生成。
- 不支持 Excel 公式，请使用明确的字面值。无效输入会报告行号和错误原因，退出码为 2。
- G 列的 description 保留为表格说明，不写入生成的 RTL。
- 所有 `csr_reg_data_0x0`、`csr_reg_data_0x4` 等 32-bit 信号按十六进制地址 offset 命名，统一在模块内部信号声明区定义，每条声明末尾标注对应的地址 offset。名称中的十六进制字母使用小写，例如地址 0x1C 对应 `csr_reg_data_0x1c`。各地址区域用一条多行 `assign` 按 bit 31 到 bit 0 拼接全部字段及补零的保留位，每行一个字段，行尾注释标明 bit 范围、复位值及访问属性。`ro` 接外部输入，其他属性的写逻辑紧随其后。中央 `always_comb` 按地址选择完整读值赋给 `csr_data`。
- 地址常量使用 `OFFSET_0x0`、`OFFSET_0x4` 等命名。字段的 bit、reset、属性只标注在拼接行尾，保留必要的时序说明，省略表格 description、重复的地址和 storage 注释。

## RTL 行为与连接

| access | 模块端口 | 行为 |
| --- | --- | --- |
| `rw` | 输出 `signal` | 异步低有效复位为表中值；APB 写入对应字段，读取当前值 |
| `ro` | 输入 `signal` | 在读 SETUP 阶段采样外部状态；软件写入忽略。表中复位值仅保留为注释，外部模块负责复位 |
| `rw1c` | 输出 `signal`，输入 `signal_hwset` | 复位为表中值；软件写 1 清对应位、写 0 保持；硬件输入为 1 时置位，硬件置位优先 |
| `rwsc` | 输出 `signal` | 写入对应字段值，写入的 1 保持一个时钟周期；下一个时钟沿自动清零，新有效写入优先 |

`rwsc` 支持单 bit 和多 bit 字段，各位独立产生一个周期的脉冲，不生成 `*_hwset` 输入。
复位为表中复位值；复位释放后，在没有有效写入的第一个时钟沿清零。SETUP、读操作、写其他地址或错误访问不会触发新脉冲。
例如字段 `start[7:4]` 标为 `rwsc`，写入 `32'h0000_00A0` 后，输出 `start[3:0]=4'b1010`，下一个没有新写入的时钟沿变为 `4'b0000`。
读取仍使用 SETUP 阶段采样的寄存器输出；若读取的采样沿同时发生自动清零，读响应保存该时钟沿清零前的值。

字段端口均从 bit 0 开始。例如表中 `c` 位于 `30:3`，模块端口为 `c[27:0]` 和 `c_hwset[27:0]`。
不需要硬件置位时，将 `*_hwset` 接全 0；需要硬件置位时，输入应是与 `pclk` 同步的事件信号。
持续拉高 `*_hwset` 会持续置位对应位，软件清零后仍保持 1。

同一个地址混合 `rw` 和 `rw1c` 时，32 bit 写入会同时作用于两类字段。
例如向地址 `0x0` 写 `32'h0000_0008`，会清除 `c[0]`，也会将 `a` 写成 0。
若需要保留 `a=1`，应写 `32'h0000_0009`。其他不需要清除的 `rw1c` 位必须写 0，不能直接把整寄存器读值原样写回。

```systemverilog
apb_csr #(.AW(16)) u_regs (
    .pclk(pclk), .presetn(presetn),
    .psel(psel), .penable(penable), .pwrite(pwrite),
    .paddr(paddr), .pwdata(pwdata),
    .prdata(prdata), .pready(pready), .pslverr(pslverr),
    .a(enable), .b(status), .c(irq_pending), .c_hwset(irq_event),
    .a1(enable1), .b1(status1), .c1(irq_pending1), .c1_hwset(irq_event1)
);
```

APB 使用 `pclk` 和异步低有效 `presetn`，`PREADY` 恒为 1，无额外等待周期。
写入仅在 `PSEL && PENABLE && PWRITE && PREADY` 且地址有效时发生。
内部生成 `csr_write` 写入使能和 `csr_read` 读采样使能。读采样提前到 SETUP 阶段，在 ACCESS 阶段提供已寄存的数据：

```systemverilog
assign csr_write = psel && penable &&  pwrite && pready && !pslverr;
assign csr_read  = psel && !penable && !pwrite && csr_addr_hit;
```

`prdata` 由 `always_ff @(posedge pclk or negedge presetn)` 直接驱动，异步复位为 0。
在 SETUP 结束的时钟上升沿锁存读值，并在整个 ACCESS 阶段保持，`PREADY` 仍恒为 1，无额外等待周期。
外部 `ro` 或硬件状态在 ACCESS 阶段变化时，不会改变本次读响应；下次读会重新采样。
`prdata` 仅在异步复位或命中地址的读 SETUP 采样沿更新；未选中、空闲和写操作时均保持最近一次有效读采样的值，不清零。
读未映射地址或非对齐地址时，`prdata` 保持访问前的当前值，在 SETUP 和 ACCESS 阶段均不更新，并在 ACCESS 阶段置 `PSLVERR=1`；不会修改寄存器。
有效地址的写操作忽略 `ro` 和保留位，仍正常完成。
接口和访问阶段依据 [Arm AMBA APB 协议规范](https://documentation-service.arm.com/static/63fe2c1356ea36189d4e79f3?token=)。

## 验证

Python 测试覆盖截图格式、指定 sheet、合并单元格、字段/地址错误和 CLI：

```powershell
python -m pip install -e ".[test]"
python -m pytest -q
```

RTL 仿真测试覆盖复位、SETUP 不写入、无选中不写入、RW、外部 RO、W1C、硬件置位优先、保留位、连续传输和地址错误。
另外对示例 `c[27:0]` 的全部 28 位逐位验证：硬件置位、软件写 0 保持、其他位清零不干扰当前位、软件写 1 清零，以及同时置位和清零时硬件优先。
使用 Verilator（需 C++ 编译环境）：

```powershell
New-Item -ItemType Directory -Force build/rtl_sim | Out-Null
verilator --binary --timing --top-module tb_apb_csr --Mdir build/rtl_sim -Wno-TIMESCALEMOD examples/apb_csr.sv tests/tb_apb_csr.sv
.\build\rtl_sim\Vtb_apb_csr.exe
```

本机 Windows Conda 版 Verilator 的构建配置包含失效的 Python 路径，动态链接后的仿真程序也存在启动问题。
已验证可通过指定当前 Python 和静态链接完成仿真，不需要修改 Verilator 安装：

```powershell
$csrgenPython = (Get-Command python).Source.Replace('\', '/')
verilator --binary --timing --top-module tb_apb_csr --Mdir build/rtl_sim -Wno-TIMESCALEMOD -MAKEFLAGS "PYTHON3=$csrgenPython" -LDFLAGS "-static" examples/apb_csr.sv tests/tb_apb_csr.sv
.\build\rtl_sim\Vtb_apb_csr.exe
```

当前验证结果：68 项 Python 测试通过；RTL 在 `AW=3/16/24/32` 的语法检查通过；行为仿真输出 `PASS`。仿真还验证读数据只在时钟沿变化、SETUP 采样、ACCESS 保持、未命中读地址保持当前值及外部 RO 变化不会影响已采样读响应。

`rwsc` 专项仿真覆盖单 bit、多 bit、完整 32 bit 字段、写 0、自动清零、复位值、连续写入及清零时的读采样：

```powershell
python tests/make_rwsc_fixture.py
New-Item -ItemType Directory -Force build/rwsc_sim | Out-Null
$csrgenPython = (Get-Command python).Source.Replace('\', '/')
verilator --binary --timing --top-module tb_rwsc_csr --Mdir build/rwsc_sim -Wno-TIMESCALEMOD -MAKEFLAGS "PYTHON3=$csrgenPython" -LDFLAGS "-static" build/rwsc_check/rwsc_apb_csr.sv tests/tb_rwsc_csr.sv
.\build\rwsc_sim\Vtb_rwsc_csr.exe
```

保留位专项仿真使用只定义 `[15:8]` 的寄存器，并将显式 `reserved[3:0]` 故意标成 `rw1c`、复位值 `FF`。
检查该错误只警告，且 `[31:16]`、`[7:4]` 和 `[3:0]` 在复位和软件写入后都读回 0：

```powershell
python tests/make_reserved_fixture.py
New-Item -ItemType Directory -Force build/reserved_sim | Out-Null
$csrgenPython = (Get-Command python).Source.Replace('\', '/')
verilator --binary --timing --top-module tb_reserved_csr --Mdir build/reserved_sim -Wno-TIMESCALEMOD -MAKEFLAGS "PYTHON3=$csrgenPython" -LDFLAGS "-static" build/reserved_check/sparse_apb_csr.sv tests/tb_reserved_csr.sv
.\build\reserved_sim\Vtb_reserved_csr.exe
```

也可用 Icarus Verilog：

```powershell
iverilog -g2012 -s tb_apb_csr -o build/tb_apb_csr examples/apb_csr.sv tests/tb_apb_csr.sv
vvp build/tb_apb_csr
```
