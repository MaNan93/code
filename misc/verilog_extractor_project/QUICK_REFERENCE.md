# 快速参考指南 - Signal Connection Graph

## 最常用的操作

### 1. 基础使用
```python
from verilog_extractor import VerilogExtractor

# 从代码字符串创建
code = "module design(...); ... endmodule"
extractor = VerilogExtractor(code)

# 从文件创建
with open('design.v') as f:
    extractor = VerilogExtractor(f.read())
```

### 2. 提取所有信息
```python
# 一次性提取所有信息
results = extractor.extract_all()
# results['module_ports']
# results['instantiations']
# results['signal_definitions']

# 单独提取
ports = extractor.extract_module_ports()
insts = extractor.extract_module_instantiations()
signals = extractor.extract_signal_definitions()
```

### 3. 打印报告
```python
# 完整的提取报告
extractor.print_report()

# 连接关系图和分析
extractor.print_connection_graph()
```

### 4. 构建连接图
```python
graph = extractor.build_signal_connection_graph()

# 获取所有实例
instances = graph.instances  # {inst_name: module_type}

# 获取所有信号
all_signals = graph.get_all_signals()

# 查询单个信号
fanout = graph.get_signal_fanout('clk')
source = graph.get_signal_source('data')
dests = graph.get_signal_destinations('valid')
```

---

## SignalConnectionGraph API 速查

### 初始化
```python
graph = SignalConnectionGraph()
```

### 添加数据
```python
# 添加模块实例
graph.add_instance('u0', 'memory_controller')

# 添加信号连接
graph.add_connection('clk', 'u0', 'clk', 'input')
```

### 查询信息
```python
# 获取信号来源
source = graph.get_signal_source('clk')  # (instance, port)

# 获取信号目标
dests = graph.get_signal_destinations('clk')  # [(inst1, port1), ...]

# 获取扇出
fanout = graph.get_signal_fanout('clk')  # 5

# 追踪信号
trace = graph.trace_signal('clk')
# {
#   'signal': 'clk',
#   'source': (inst, port),
#   'destinations': [...],
#   'fanout': 5,
#   'connections': [...]
# }

# 获取所有信号
signals = graph.get_all_signals()  # Set[str]
```

### 报告和可视化
```python
# 打印连接图
graph.print_connection_graph()

# 生成报告
report = graph.generate_connection_report()
print(report)
```

---

## 常见任务

### 找出高扇出信号
```python
graph = extractor.build_signal_connection_graph()

high_fanout = []
for signal in graph.get_all_signals():
    fanout = graph.get_signal_fanout(signal)
    if fanout >= 3:
        high_fanout.append((signal, fanout))

for sig, fanout in sorted(high_fanout, key=lambda x: x[1], reverse=True):
    print(f"{sig}: {fanout} destinations")
```

### 追踪信号路径
```python
trace = graph.trace_signal('data_valid')

print(f"Signal: {trace['signal']}")
if trace['source']:
    inst, port = trace['source']
    print(f"Source: {inst}.{port}")

for inst, port in trace['destinations']:
    print(f"  -> {inst}.{port}")
```

### 检查设计中的问题
```python
all_signals = graph.get_all_signals()

# 未驱动的信号
undriven = []
for sig in all_signals:
    if graph.get_signal_source(sig) is None:
        undriven.append(sig)

if undriven:
    print("Warning: Undriven signals found:")
    for sig in undriven:
        print(f"  - {sig}")

# 未连接的输出
unconnected = []
for sig in all_signals:
    if graph.get_signal_fanout(sig) == 0:
        unconnected.append(sig)

if unconnected:
    print("Warning: Unconnected signals:")
    for sig in unconnected:
        print(f"  - {sig}")
```

### 分析特定模块实例
```python
# 查看某个实例连接了哪些信号
instance_signals = {}
for signal in graph.get_all_signals():
    for inst, port in graph.get_signal_destinations(signal):
        if inst == 'u0_ctrl':
            if inst not in instance_signals:
                instance_signals[inst] = []
            instance_signals[inst].append((signal, port))
```

---

## 输出格式

### 连接图格式
```
SIGNAL CONNECTION GRAPH
============================

Instances (N total):
  name1          : type1
  name2          : type2

Signal Connections (M total):
  Signal: signal_name
    Source: instance.port
    Fanout: N destinations
      -> dest1.port1
      -> dest2.port2
```

### 报告格式
```
SIGNAL CONNECTION REPORT
============================

Summary:
  Total Signals: N
  Driven Signals: M
  Undriven Signals: P
  Max Fanout: Q

High Fanout Signals (fanout >= 3):
  signal_name    : fanout = N

Undriven Signals:
  signal_name    used by M instance(s)
```

---

## 调试技巧

### 打印所有信息
```python
extractor = VerilogExtractor(code)

# 打印完整的模块信息
print(extractor.extract_module_ports())
print(extractor.extract_module_instantiations())
print(extractor.extract_signal_definitions())

# 打印连接图
extractor.print_connection_graph()
```

### 逐步分析
```python
graph = extractor.build_signal_connection_graph()

# 1. 查看实例
print(f"Found {len(graph.instances)} instances")

# 2. 查看信号
signals = graph.get_all_signals()
print(f"Found {len(signals)} signals")

# 3. 分析每个信号
for sig in signals:
    src = graph.get_signal_source(sig)
    fanout = graph.get_signal_fanout(sig)
    print(f"{sig}: source={src}, fanout={fanout}")
```

---

## 完整示例

```python
from verilog_extractor import VerilogExtractor

code = """
module pipeline (
    input clk, reset,
    input [7:0] data_in,
    output [7:0] data_out
);
    wire [7:0] s1, s2, s3;
    
    stage u0 (.clk(clk), .data_in(data_in), .data_out(s1));
    stage u1 (.clk(clk), .data_in(s1), .data_out(s2));
    stage u2 (.clk(clk), .data_in(s2), .data_out(s3));
    stage u3 (.clk(clk), .data_in(s3), .data_out(data_out));
endmodule
"""

# 创建和分析
extractor = VerilogExtractor(code)
graph = extractor.build_signal_connection_graph()

# 分析时钟分布
print("Clock Distribution:")
clk_fanout = graph.get_signal_fanout('clk')
clk_dests = graph.get_signal_destinations('clk')
print(f"  clk -> {clk_fanout} instances: {[d[0] for d in clk_dests]}")

# 分析数据路径
print("\nData Path:")
for sig in ['data_in', 's1', 's2', 's3', 'data_out']:
    dests = graph.get_signal_destinations(sig)
    if dests:
        print(f"  {sig} -> {dests[0][0]}")

# 完整报告
extractor.print_connection_graph()
```

---

## 性能提示

- 对于大型设计（>1000 instances），构建图仍然很快
- 查询单个信号是 O(1) 操作
- 完整遍历是 O(n)，其中 n 是总连接数
- 内存占用随着信号数量线性增长

---

**最后更新：2026年2月4日**
