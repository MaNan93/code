# csrgen 分层架构

入口 `csrgen.py` 只负责加载包并调用 CLI；业务处理由 `pipeline.py` 组织。XLSX 模板和 APB3 行为保持兼容；CLI 和完整流程默认按输入文件主名命名模块，显式指定旧模块名时生成的 RTL 文本保持一致。

数据契约、寄存器规范、APB 时序、诊断及发布设计见 [设计文档](DESIGN.md)。

| 阶段 | 模块 | 输入 → 输出 | 职责 |
| --- | --- | --- | --- |
| 1. 文件读入 | `reader.py` | 路径、`ReadOptions` → `RawTable` | 文件格式分派、打开/关闭文件、选择 sheet、保留原始值及行号 |
| 2. 表格格式 | `layout.py` | `RawTable`、`TableLayout` → `MappedRow` 列表 | 明确指定 header 行数及字段列，校验列映射 |
| 3. 寄存器解析 | `parser.py`、`values.py`、`validation.py` | `MappedRow` 列表 → `Register`/`Field` | 值转换、地址继承、重复地址、对齐、范围、字段属性、复位值、重叠及名称冲突检查 |
| 4. 生成代码 | `rtl.py` | 寄存器模型、模块名、地址位宽 → RTL 字符串 | APB3、RW/RO/W1C/RWSC、reserved、读采样及读保持的代码生成 |
| 5. 代码质量审查 | `quality.py` | RTL 字符串 → `ToolReport` | 使用真实 Verilator 检查语法、类型和工具能诊断的 RTL 问题 |
| 6. 可选格式化 | `formatter.py` | RTL 字符串 → 格式化字符串 | 调用 Verible，不参与寄存器内容解析 |

`models.py` 定义寄存器模型，`diagnostics.py` 定义共享异常和警告，`tooling.py` 管理外部工具与临时文件，`naming.py` 独立处理模块命名和输出路径。`generator.py` 保留旧导入路径，只作为兼容入口。

## 执行顺序

```mermaid
flowchart LR
    A[文件读入] --> B[列映射与 header 处理]
    B --> C[寄存器解析与规范校验]
    C --> D[生成 RTL]
    D --> E[可选 Verilator 审查]
    E --> F[可选 Verible 格式化]
    F --> G[格式化后再次审查]
    G --> H[CLI 写入输出文件]
```

- 内容校验始终执行。Verilator 审查用 `--lint` 开启，Verible 格式化用 `--format` 开启；两者默认关闭，不增加普通 XLSX 生成的安装依赖。
- 同时启用两者时，先审查生成结果，再格式化，再审查最终结果。仅启用格式化时，Verible 自身会解析语法，错误不会被当作成功。
- 外部工具在独立临时目录运行，工具不存在、退出失败、超时或格式化结果为空均报错。审查/格式化失败时，CLI 不会覆盖已有输出文件，退出码为 2。
- Verilator lint 不等于硬件行为验证；SETUP/ACCESS、W1C 优先级、rwsc 清零和读保持仍由行为仿真覆盖。

## Header 和列位置

默认 `TableLayout()` 跳过一行、读取 B:G，不匹配 header 的文字，也不自动猜测是否存在 header。

- 无 header：`header_rows=0`，第一行直接作为数据。
- 标题加 header：按实际行数设置，例如 `header_rows=2`。
- `columns` 使用从 1 开始的物理列号；CLI 同时接受 Excel 列字母或数字，例如 `offset=A`、`offset=1`。
- `offset`、`signal`、`reset`、`bit`、`access` 必须映射到不同的有效列；`description` 可映射为 `None`。CLI 用 `--column description=none` 忽略该列。
- 行号始终保留原文件的行号，不因跳过 header 或重排列而改变。
- 内容层保留既有规则：同一寄存器的连续行可重复填写相同 offset；返回已被其他 offset 隔开的地址时报重复地址错误。

## Python 使用方式

旧接口继续有效：

```python
from csrgen import read_xlsx, generate_rtl

registers = read_xlsx("registers.xlsx", sheet="sheet1", aw=16)
rtl = generate_rtl(registers, module="apb_csr", aw=16)
```

通过配置对象调用完整流程：

```python
from csrgen import GenerationOptions, ReadOptions, TableLayout, run_pipeline

options = GenerationOptions(
    read=ReadOptions(sheet="Status"),
    layout=TableLayout(
        header_rows=0,
        columns={"offset": 1, "signal": 2, "reset": 3, "bit": 4, "access": 5},
    ),
    module="device_apb_csr",
    aw=20,
    lint=True,
    format=True,
)
result = run_pipeline("registers.xlsx", options)
print(result.rtl)
```

`run_pipeline()` 返回寄存器模型、最终 RTL 和审查报告，不写输出文件；CLI 负责文件名、模块名前缀、告警显示及最终写入。

`GenerationOptions.module` 默认为 None，使用输入文件主名；`module_prefix` 可在推导名或显式基础名前加前缀。例如 `GenerationOptions(module="ccc", module_prefix="AAA")` 生成 `AAA_ccc`。模块名不影响 CLI 默认输出文件名，文件名始终取输入主名，除非用 `--output` 或 `--file-prefix` 覆盖。没有文件上下文的 `generate_rtl(registers)` 仍默认生成 `apb_csr`。

## 后续扩展 CSV

内置文件读入目前仅支持 XLSX。CSV 的分隔符、编码、引号和空单元格处理应放在独立读入适配器中，返回同样的 `RawTable`；布局、寄存器解析和代码生成无需读取 CSV 文件细节。

读入适配器的签名是 `adapter(path: Path, options: ReadOptions) -> RawTable`，通过 `run_pipeline(..., readers={".csv": csv_adapter})` 注入。`ReadOptions.encoding` 提供给文本适配器，XLSX 不使用这个选项。自定义适配器应在返回前关闭文件。

新增 RTL 后端时，应消费同样的 `Register`/`Field` 模型，保留内容校验，不把另一种总线的生成规则放进 XLSX/CSV 读入代码。
