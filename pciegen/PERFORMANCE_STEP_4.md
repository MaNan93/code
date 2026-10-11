# 渐进优化：接口读取接入 pciegen

日期：2026-10-11。承接 vutils 第三步的只读接口 API。

## 修改

pciegen 的两个接口读取调用改用 `read_interface_from_file(..., auto_select=True)`：

- `analyze_pcie_iip_subsystem_interface()`：读取子系统模块名、端口、参数及完整参数声明，用于生成 wrapper。
- `extract_pcie_ram_port_from_rams_file()`：读取 RAM 文件的端口，用于生成内部连线声明。

这两个调用不需要编辑 CST 或分析实例。继续保留文件名匹配优先、否则选择第一个模块的行为，ANSI/非 ANSI 接口字段，以及完整源码的语法检查。子系统分析失败仍打印警告并返回 `None`；RAM 源码语法错误仍抛出异常。需要编辑或按实例定位模块的路径继续使用现有编辑器。

## 全流程配对测量

两个合成工程均包含 7 个 SV 文件和 2 个列表文件，15 个 RAM 实例；每个 SV 文件分别约 2,000 或 3,000 行。两种读取方式各测五轮，交替先后顺序，每轮使用新 Python 进程与独立临时工程。测量真实 ramgen 和完整 PCIe 生成流程，排除 Python 启动/导入、工程构造、输出比较和临时工程清理。

基准的 `--interface-mode full` 临时将上述两个调用恢复为原有完整 CST 接口读取，其他代码保持一致。相比仅引用上轮历史测量，这样能够直接比较本次接入的影响。

| 指标 | 每文件约 2,000 行，原读取 | 每文件约 2,000 行，新读取 | 每文件约 3,000 行，原读取 | 每文件约 3,000 行，新读取 |
|---|---:|---:|---:|---:|
| 全流程中位耗时，秒 | 1.8956 | 1.7684 | 2.7794 | 2.5841 |
| 两个接口读取合计中位耗时，秒 | 0.3202 | 0.2558 | 0.4787 | 0.3515 |
| Verible 调用次数 | 14 | 14 | 14 | 14 |
| 完整 CST JSON 导出次数 | 9 | 9 | 9 | 9 |
| 原始 JSON 合计字节数 | 57,964,039 | 57,964,039 | 86,332,039 | 86,332,039 |

全流程耗时分别减少约 **6.7% 和 7.0%**。十组配对中九组新读取更快；一组 2,000 行场景新读取慢约 8 毫秒。结果仍受系统调度和文件写盘波动影响，不能承诺真实工程精确达到这个百分比。各阶段中位数独立计算，不要求精确相加。

两个场景各轮的全部 11 个输出 SV 文件，在将临时工程绝对路径规范化后，文件名与内容合计 SHA-256 完全一致。比较发生在计时结束后。这项比较不涵盖 Excel 等其他产物。

仍有 9 次完整 CST JSON 导出，因为本次筛选发生在 Python 节点构造之前。原生解析、JSON 序列化、进程传输和 JSON 解码成本仍存在。

## 验证

- 新增 6 项 pciegen 接入回归，覆盖 ANSI/非 ANSI、参数、中文前缀、带符号数组、按文件名选择模块、首模块回退、模块体及未选中模块的语法错误。
- pciegen 回归 26 项、vutils 目标回归 53 项通过。
- 真实 RAM 生成完整流程通过，对 11 个输出 SV 文件完成 Verible 语法检查。
- `git diff --check` 通过。

## 复现和后续方向

在 `C:/Users/1/Desktop/code/pciegen` 执行：

```powershell
python test/benchmark_interface_pipeline.py --repeats 5 --output test/interface_pipeline_measurements.json
python -m unittest discover -s test -p 'test_*.py'
python test/run_full_scenario.py
```

原始数据：`test/interface_pipeline_measurements.json`。接入回归：`test/test_interface_reads.py`。原有 `benchmark_pipeline.py` 增加参考读取模式和计时外的输出 SV 内容校验。

新读取下，RTL 编辑阶段中位耗时仍约为 1.4135 / 2.0924 秒，约占完整流程的 80% / 81%。下一步值得检查同一文件的重复解析能否继续合并或复用；需要确保源码修改后重新建立有效的树与偏移。本轮没有继续扩大修改范围。
