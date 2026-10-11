# PCIe 生成工具整体性能分析

本文保留优化前的测量和问题依据。2026-10-11 已完成一轮优化，最新实现、验证和前后对比见 [PERFORMANCE_OPTIMIZATION.md](PERFORMANCE_OPTIMIZATION.md)。下文描述的是这一轮优化之前的状态。

测量日期：2026-10-11。分析对象是当前工作区已修复后的 `pciegen`、相邻 `vutils` 和真实 `ramgen` 源码。

仍存在可复现的性能问题。大模块主要受反复导出和遍历完整语法树影响；大量 RAM 实例主要受逐实例扫描整份源码影响。优化应先减少重复工作，再考虑更换解析工具或并行化。

## 测量方法

- 在 Windows / Python 3.12 上，使用本地 `C:/Users/1/Desktop/code/verible/verible-verilog-syntax.exe`。
- 每个场景在独立 Python 进程和临时工作目录内运行，调用真实的五步 `pciegen.run()`，每个场景测三次，下面报告中位数。
- 使用可扩展的合成 RTL，分别改变模块体长度、端口数、RAM 实例数、文件数和单个文件中的模块数。它们不代表真实 Synopsys 工程的精确运行时间，也不验证 PCIe 功能。
- 时间不包含解释器启动、依赖导入、测试输入构造、测试后检查和临时目录清理。阶段时间包含轻量计时和解析器调用统计。
- 内存是 Python 进程的峰值工作集，包含准备阶段；不包含 Verible 子进程。JSON 体积是累计输出量，不能当作同时占用的内存。
- `cProfile` 单独运行，仅用来定位函数和调用关系。其运行时间明显膨胀，不混入基准中位数。

## 实测结果

基础场景：五个待编辑模块各有 100 行附加声明、32 个附加 subsystem 端口、1 个 RAM 实例。其余场景只改变表中对应维度。

| 场景 | 总耗时，秒 | 复制/准备 | ramgen | RTL 编辑 | wrapper 生成 | Python 峰值工作集，MiB |
|---|---:|---:|---:|---:|---:|---:|
| 基础场景 | 0.495 | 0.045 | 0.007 | 0.406 | 0.035 | 36.6 |
| 五个模块各增加到 2,000 行 | 2.744 | 0.218 | 0.008 | 2.335 | 0.186 | 76.8 |
| 五个模块各增加到 10,000 行 | 14.921 | 1.016 | 0.008 | 12.785 | 1.124 | 210.0 |
| 1,000 个附加端口 | 1.149 | 0.043 | 0.007 | 0.828 | 0.278 | 64.1 |
| 100 个 RAM 实例 | 0.598 | 0.043 | 0.037 | 0.480 | 0.033 | 45.6 |
| 500 个 RAM 实例 | 1.328 | 0.042 | 0.412 | 0.840 | 0.033 | 104.0 |
| 1,000 个 RAM 实例 | 2.904 | 0.043 | 1.470 | 1.377 | 0.032 | 175.6 |
| 2,000 个附加小文件 | 2.208 | 1.750 | 0.007 | 0.395 | 0.034 | 37.5 |
| 相同文件已完整存在于 rtl 中 | 2.280 | 1.847 | 0.007 | 0.381 | 0.034 | 36.9 |
| cdm.sv 中 16 个模块，目标模块最后 | 0.893 | 0.042 | 0.006 | 0.807 | 0.035 | 36.7 |
| cdm.sv 中 64 个模块，目标模块最后 | 2.449 | 0.042 | 0.007 | 2.364 | 0.033 | 43.0 |

阶段中位数分别计算，且省略输入验证和其他少量开销，因此各列相加不一定等于总耗时中位数。

## 主要问题与依据

### 1. 同一文件的完整语法树仍被反复生成和分析

普通单模块场景的完整流水线启动 Verible **22 次**，其中 **13 次导出完整 CST**、9 次只检查语法。前一轮优化中“10 次降到 4 次”指单次添加端口及实例连线，不是整条流水线。

在 10,000 行场景中，输入源码合计约 **1.50 MB**，累计解析输出约 **380.30 MB JSON**。RTL 编辑约占总耗时的 **86%**。`from_file()`、`add_port()`、`add_inst_port()`、wrapper 接口分析之间仍有重复解析。

函数级 profile 中，2,000 行场景的 `_analyze_modules()` 调用 13 次；树的 `find_all()` 及递归迭代占用大量 Python 时间。问题同时包含 JSON 传输/解码、Python 节点创建、反复遍历，而不只是外部程序启动。

位置：`vutils/src/vutils/vedit.py` 的 `_analyze_modules()`、`vedit.from_file()`、`vedit.add_port()`、`vedit.add_inst_port()`；`vutils/src/vutils/vparser.py` 的 `_parse()`、`_transform_tree()` 和遍历器。

建议：用文件级编辑事务收集所有修改，一次解析原文、一次拼接修改、统一语法验证；保留有效元数据供后续步骤使用。再优化遍历器的筛选谓词、实例索引、节点范围计算，减少完整树扫描。

### 2. 多模块选择路径会按候选模块重复解析整份文件

`_load_editor()` 首次解析多模块文件后丢弃结果；`_resolve_target_module_name()` 再获取模块列表，并对候选模块逐一打开编辑器，读取 `instances` 时又重新解析整个文件。

单个 cdm.sv 包含 16 / 64 个模块、目标位于最后时，全流程解析器调用分别由普通场景的 **22 次增至 40 / 88 次**。这是可避免的放大，并非这些小 helper 模块本身需要很长解析时间。

位置：`pciegen.py` 的 `_load_editor()`、`_resolve_target_module_name()`。

建议：一次解析得到所有模块及实例归属，在内存中选择目标，直接复用该模块元数据。

### 3. ramgen 的顶层 RTL 改写近似按实例数平方增长

`generate_output_sv()` 对每个 RAM 实例构造正则，并对整份不断变化的源码执行 `pattern.sub(..., count=1)`。实例数量增长的同时，文件本身也增长。

| RAM 实例数 | `generate_output_sv()` 中位耗时，秒 |
|---|---:|
| 100 | 0.0206 |
| 500 | 0.3759 |
| 1,000 | 1.4113 |

500 → 1,000 个实例时，这个函数耗时增加约 **3.75 倍**。在 1,000 实例场景中，它占 ramgen 阶段约 **96%**；分析、报表和仿真文件生成的耗时相对较小。profile 也显示主要时间落在正则替换中。

这些实例使用同一种 RAM 参数配置，因此主要结果并非由大量不同 wrapper 文件写盘引起；大量独特 RAM 类型会有额外文件生成成本，本次未测。

位置：`ramgen/src/ramgen/ram_generator.py` 的 `generate_output_sv()`。

建议：在一次扫描中记录需要替换的类型名范围，结合实例名称和 reference 映射，用原文片段和替换片段一次拼接输出。不要对每个实例重新搜索并复制全文。

### 4. 仅提取 RAM 接口时仍分析所有内部实例

`extract_pcie_ram_port_from_rams_file()` 只使用 `.ports`，但 `_load_editor()` → `from_file()` 默认计算整个文件的实例信息。1,000 RAM 场景的 RTL 编辑阶段约 1.38 秒，其中很大部分来自这一接口读取。

在该场景的 profile 中，接口提取路径调用的 `_extract_instances()` 和全树遍历占明显份额。`vedit.analyze(include_instances=False)` 虽然已有轻量选项，但在已经通过 `from_file()` 完整解析之后再调用，还会重新解析，不能解决首次开销。

建议：加载阶段支持只读取模块头/端口元数据，并按需延迟实例分析；保留 CST，避免轻量分析与完整分析之间再次启动工具。

### 5. 文件准备没有增量复用，遍历及权限处理有额外成本

附加 2,000 个小文件仅增加约 85 KB 源码，却使复制/准备阶段达到约 1.75 秒。预先把相同输入完整复制到 rtl 后再次运行，准备阶段仍约 1.85 秒。

`copytree(..., dirs_exist_ok=True)` 仍复制文件；`ensure_tree_user_writable()` 在复制前后递归遍历，调用 `stat()`、`is_dir()`、`chmod()`。文件个数比总字节数更影响这个场景。

建议：分开处理已有可写文件和必须解除只读的文件；根据可靠的文件状态或内容摘要跳过未变化的复制。首轮瓶颈仍应先处理语法树和 RAM 改写。

### 6. wrapper 去重和通用批量实例编辑仍有线性查找

wrapper 对每个端口使用 `next(... for ... in wrapper_ports)` 查询之前的同名端口，形成 O(P²) 查找。这是前一轮正确性修复新增的查询，应该改用字典。

隔离初始语法解析，仅测 wrapper 映射/输出时，500 / 2,000 / 8,000 端口分别约 0.023 / 0.118 / 1.004 秒。千端口场景目前还不是首要瓶颈。

`vedit.add_inst_port()` 对多个实例逐个查找 CST 节点，并复制中间源码。即使初始解析在计时外，编辑 400 个现有实例中的 1 / 20 / 100 个，耗时也约 0.021 / 0.137 / 0.624 秒，每次只启动一个语法验证进程。

建议：建立实例节点和端口映射索引；把多个实例的修改一起收集，单次组装输出。当前 pciegen 每次通常只修改一个目标实例，这部分优先级低于前四项。

## 优化顺序

1. 文件级解析结果复用、批量修改与统一验证；同时消除多模块选择的重复解析。
2. ramgen 顶层 RTL 使用一次扫描/一次拼接完成改写。
3. 端口读取延迟分析实例；优化 Python 树遍历及索引。
4. 文件复制和权限处理按需执行，避免每次覆盖整个工作树。
5. wrapper 去重字典和通用批量实例编辑索引。

此处是初次分析时的优化顺序；其中解析复用、RAM 改写、延迟实例分析、遍历及索引优化已在随后一轮实现。复制和权限处理仍待进一步优化。

## 复现与原始数据

在 `C:/Users/1/Desktop/code/pciegen` 中执行：

```powershell
python test/benchmark_pipeline.py --repeats 3 --output test/pipeline_results.json
python test/benchmark_pipeline.py --case body_2000 --profile test/profile_body_2000.prof --output test/profile_body_2000.json
python test/benchmark_pipeline.py --case ram_1000 --profile test/profile_ram_1000.prof --output test/profile_ram_1000.json
python test/benchmark_mapping.py
```

- 主流水线三轮原始数据：`test/pipeline_measurements_repeated.json`
- 预先存在的文件与千端口场景：`test/pipeline_additional_measurements.json`
- 独立映射/编辑测量：`test/mapping_measurements.json`
- 函数级 profile：`test/profile_body_2000.prof`、`test/profile_ram_1000.prof`
- 测量脚本：`test/benchmark_pipeline.py`、`test/benchmark_mapping.py`
