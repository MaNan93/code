# pciegen / vutils / ramgen 缺陷复查

日期：2026-10-11。检查重点是源码解析、模块选择、接口读取、文本改写和 wrapper 参数/端口生成；结合最小复现检查最近的性能修改。

## 已复现并修复

| 工具 | 触发方式与修改前结果 | 修复 |
|---|---|---|
| vutils | 源码前面带中文注释，再添加端口、实例连接或 wire：Verible 字节偏移被用于 Python 字符串切片，导致位置错位或报错 | 在编辑边界转换字节偏移；公开 CST 和实例元数据继续使用字节偏移。实例已有表达式通过节点的字节文本读取 |
| vutils | 外层与嵌套模块有同名端口：内层声明覆盖外层接口；内层实例被外层识别，按实例自动选模块选到外层 | 模块作用域遍历跳过嵌套模块、函数、任务、类；端口、实例、实例编辑和自动选择都使用正确的模块归属 |
| vutils | `wire x = y;`、实例连接或位宽表达式中出现 `y`，再调用 `add_wire(y)`：误认为 `y` 已声明；纯 ANSI 输入端口则可能被重复声明 | 只检查真实声明的名字，并识别 ANSI 端口及继承声明的端口；跳过内部作用域 |
| vutils | 已有 `.a` 隐式连接，再请求 `.a(a)`：误判为已经连接到空表达式并报冲突 | 区分 `.a` 与 `.a()`，前者视为连接到同名信号 |
| vutils | 空连接列表、列表末尾的多行注释或条件编译指令：逗号位置错误，甚至将新增连接写进注释，语法检查仍可能通过 | 根据真实列表 token 定位分隔符；新增内容放在注释外，条件编译列表使用位于分支之外的前置逗号 |
| ramgen | `.WD((4+4))` 或 `.din(fn(a,b))`：表达式在第一个右括号处截断；字符串中的实例样例被误解析，甚至吞掉后续真实实例 | 使用共享的 token 扫描和配对括号解析；字符串与注释不会参与声明匹配，嵌套表达式完整保留 |
| ramgen | `ram_wrapper #(...) u0(...), u1(...);`：第二个实例未统计；不同替换类型无法作用于共享类型声明 | 分别统计所有实例；相同类型保留共享声明，不同类型拆分声明并复制参数覆盖 |
| ramgen | 多维实例数组漏统计；`module automatic top` 被识别为名叫 `automatic`；顶层改名后 `endmodule : top` 标签未同步 | 统计各数组维度的乘积，跳过 lifetime 关键字，同步顶层结束标签 |
| ramgen | 参数表达式或 Verilog 数值字面值直接进入生成的模块名，例如 `(4+4)`、`8'd8`，形成非法标识符 | 可求值的维度规范化为整数；无法求值的复杂维度仅在生成名字时使用稳定摘要，原始参数表达式继续保留 |
| ramgen | 多行宏定义中的实例模板被当作真实 RAM 实例统计和改写 | 扫描时跳过完整宏定义及续行，保留原始定义文本 |
| pciegen | `a` 与 `A` 两个不同端口，经 CSV/HTML 查找后使用同一规则或位宽 | 优先按原始大小写匹配；仅在源码与规则/报告双方都唯一时允许忽略大小写的兼容匹配 |
| pciegen | 模块无端口，但有参数：wrapper 有参数声明，内部实例没有参数覆盖；修改 wrapper 参数不能传递到子模块 | 无端口实例也生成命名参数覆盖 |
| pciegen | 单行模块头或多模块文件：按首个 `);` / `endmodule` 插入，漏改目标或改到辅助模块 | 使用配对 token 定位文件名对应模块的头部和结束位置；重复插入检查限定在目标模块内 |
| pciegen | 提取 `external_rams` 实例时丢失 `#(...)` 参数覆盖，或误取注释示例 | 使用共享声明扫描器，保留参数覆盖、数组与嵌套连接表达式，只改指定的类型和实例名 |

## 验证

本次缺陷复查新增 28 项回归：vutils 12 项，ramgen 9 项，pciegen 7 项。新增用例在修复前复现失败，或验证新边界行为；相邻正确场景也有覆盖。

- vutils 目标测试 65 项通过，包含原有接口读取、批量编辑、缓存、范围查询、宏实例和本次复现。
- pciegen 测试 33 项通过，包含接口 API 接入、wrapper 生成、大小写映射、无端口参数传递及插入/提取位置。
- ramgen 测试 14 项通过，包含 1,000 实例与原改写结果一致，以及本次分析/生成复现。新增生成源码经过真实 Verible 语法检查。
- 真实 RAM 生成的完整 PCIe 流程通过，对 11 个 SV 文件完成语法检查。
- `git diff --check` 通过。

针对原来的普通输入合成工程，7 个 SV 文件、15 个 RAM，每文件约 2,000 / 3,000 行，各复测三轮。最新全流程中位数为 1.8370 / 2.8323 秒，Verible 每轮仍调用 14 次。所有输出 SV 的内容哈希与上一轮普通输入结果一致。

这次性能复测没有和修复前代码配对，不能用它断言修复引起的提速或回退；上一轮测量为 1.7684 / 2.5841 秒。RAM 分析和改写继续按 token 扫描源码，没有增加 Verible 调用，也没有重新引入逐实例扫描整份源码。

## 范围与限制

用户已明确工具定位：按原有源码完成指定修改。检查范围是识别准确、修改位置正确、避免漏改和误改，并保留未要求修改的源码；硬件功能、RAM 读写时序和 `RD_LATENCY` 的模型实现不列入本次待修复项，沿用原有实现，无需补充该参数的实际取值。

ramgen 的轻量扫描没有实现宏展开、任意参数/函数求值及完整作用域符号解析。无法求值的复杂 RAM 维度保留原始表达式，生成名字时采用稳定摘要；不会据此拒绝原始源码。

这里不据此承诺工具已无其他缺陷，也未将 vutils 的历史路径依赖测试、旧 parser API 测试算作本次已通过的测试。

## 复现入口

- `vutils/test/test_review_regressions.py`
- `ramgen/test/test_analysis_regressions.py`
- `pciegen/test/test_pciegen_regression.py`
- 性能原始数据：`pciegen/test/bugfix_pipeline_measurements.json`

从各自工具目录执行：

```powershell
# vutils
python -c "import sys,unittest; sys.path[:0]=['src','test']; unittest.main(module=None,argv=['unittest','test_review_regressions','test_read_interface','test_edit_batch','test_inst_port_regression','test_add_inst_port_macro','test_gen_inst_cache','test_node_ranges'])"
# ramgen
python -m unittest discover -s test -p 'test_*.py'
# pciegen
python -m unittest discover -s test -p 'test_*.py'
python test/run_full_scenario.py
```
