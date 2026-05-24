# Verilog Extractor - Signal Connection Graph 功能说明

## 新增功能概述

在原有的 Verilog 模块提取功能基础上，增加了**信号连接关系图（Signal Connection Graph）**的分析和可视化功能。

## 核心类：SignalConnectionGraph

### 主要功能

#### 1. 信号连接追踪
- **追踪信号源和目标**：确定每个信号的驱动源和接收端
- **扇出分析**：计算每个信号驱动了多少个输入端口（fanout）
- **连接映射**：建立完整的信号连接关系映射

#### 2. 信号分析方法

```python
# 添加实例
graph.add_instance(instance_name, module_type)

# 添加信号连接
graph.add_connection(signal, instance, port, direction)

# 获取信号源
source = graph.get_signal_source(signal)  # 返回 (instance, port)

# 获取信号目标
destinations = graph.get_signal_destinations(signal)  # 返回 [(inst1, port1), ...]

# 获取扇出值
fanout = graph.get_signal_fanout(signal)  # 返回整数

# 完整追踪信号
trace = graph.trace_signal(signal)
# 返回：{
#     'signal': 'signal_name',
#     'source': (instance, port),
#     'destinations': [(inst1, port1), ...],
#     'fanout': 3,
#     'connections': [...]
# }

# 获取所有信号
all_signals = graph.get_all_signals()  # 返回 Set[str]
```

#### 3. 可视化和报告

```python
# 打印连接图
graph.print_connection_graph()

# 生成详细报告
report = graph.generate_connection_report()

# 通过 VerilogExtractor 直接使用
extractor = VerilogExtractor(code)
extractor.print_connection_graph()
```

## 使用示例

### 示例 1：简单的信号流
```python
from verilog_extractor import VerilogExtractor

code = """
module pipeline (
    input clk,
    input [15:0] data_in,
    output [15:0] data_out
);
    wire [15:0] stage1, stage2;
    
    stage u0 (.clk(clk), .data_in(data_in), .data_out(stage1));
    stage u1 (.clk(clk), .data_in(stage1), .data_out(stage2));
    stage u2 (.clk(clk), .data_in(stage2), .data_out(data_out));
endmodule
"""

extractor = VerilogExtractor(code)
extractor.print_connection_graph()
```

**输出内容包括：**
- 所有实例及其模块类型
- 每个信号的连接信息
- 信号的驱动源和接收端
- 高扇出信号识别

### 示例 2：扇出分析
```python
graph = extractor.build_signal_connection_graph()

# 分析时钟信号
clk_fanout = graph.get_signal_fanout('clk')
clk_dests = graph.get_signal_destinations('clk')

print(f"时钟信号 fanout: {clk_fanout}")
for dest_inst, dest_port in clk_dests:
    print(f"  -> {dest_inst}.{dest_port}")
```

### 示例 3：信号追踪
```python
trace = graph.trace_signal('shared_signal')

print(f"信号：{trace['signal']}")
if trace['source']:
    print(f"来源：{trace['source'][0]}.{trace['source'][1]}")
print(f"目标数：{trace['fanout']}")
for dest, port in trace['destinations']:
    print(f"  └─ {dest}.{port}")
```

## 报告内容详解

### 连接图输出

```
SIGNAL CONNECTION GRAPH
└─ Instances: 列出所有模块实例及其类型
└─ Signal Connections: 列出所有信号及其连接信息
   └─ Signal: 信号名称
   └─ Source: 驱动源（或标记为未驱动）
   └─ Fanout: 扇出（目标数量）
   └─ Destinations: 所有接收端
```

### 连接报告

```
SIGNAL CONNECTION REPORT
├─ Summary
│  ├─ Total Signals: 总信号数
│  ├─ Driven Signals: 被驱动的信号数
│  ├─ Undriven Signals: 未被驱动的信号数（问题诊断）
│  └─ Max Fanout: 最大扇出值
├─ High Fanout Signals: 识别扇出 >= 3 的信号
└─ Undriven Signals: 列出可能有问题的信号
```

## 应用场景

### 1. **设计验证**
- 检查信号连接是否正确
- 识别未驱动或浮空的信号
- 验证模块间的数据流向

### 2. **性能分析**
- 识别高扇出信号（可能影响时序）
- 分析信号负载
- 优化布线和时钟树

### 3. **设计文档**
- 自动生成信号连接文档
- 创建数据流图
- 用于代码审查

### 4. **调试和维护**
- 快速理解信号流向
- 追踪信号来源和目标
- 识别设计中的不一致

## 技术细节

### 信号方向识别

工具尝试从以下方式识别信号方向：
1. 查询顶层模块的端口定义
2. 分析模块实例化的端口连接
3. 默认使用 "unknown" 标记无法确定的方向

### 局限性和改进建议

**当前版本的限制：**
- 只能追踪通过端口连接的信号
- 不能识别赋值语句（assign）中的信号关系
- 不能处理生成块中的动态连接

**未来改进方向：**
- 支持 assign 语句的信号追踪
- 处理 generate 块
- 支持多层级模块的层次化分析
- 生成 Graphviz 或 HTML 可视化图表

## 文件和函数总结

### 新增类
- `SignalConnectionGraph`: 信号连接关系图的核心类

### 新增方法（VerilogExtractor）
- `build_signal_connection_graph()`: 构建连接图
- `print_connection_graph()`: 打印连接图和报告

### 测试文件
- `test_connection_graph.py`: 基础功能测试
- `test_connection_practical.py`: 实际应用示例

## 示例文件

项目包含以下测试文件：
- `test_verilog.v`: 多个模块的测试 Verilog 代码
- `test_extractor.py`: 基本提取功能测试
- `test_comprehensive.py`: 完整的功能测试套件
- `test_connection_graph.py`: 连接图功能测试
- `test_connection_practical.py`: 实用示例演示

## 快速开始

```python
from verilog_extractor import VerilogExtractor

# 读取 Verilog 文件
with open('design.v', 'r') as f:
    code = f.read()

# 创建提取器
extractor = VerilogExtractor(code)

# 提取所有信息
results = extractor.extract_all()

# 生成连接图报告
extractor.print_connection_graph()

# 手动分析
graph = extractor.build_signal_connection_graph()
for signal in sorted(graph.get_all_signals()):
    fanout = graph.get_signal_fanout(signal)
    if fanout > 2:
        print(f"高扇出信号: {signal} (fanout={fanout})")
```

---

**最后更新**: 2026年2月4日
