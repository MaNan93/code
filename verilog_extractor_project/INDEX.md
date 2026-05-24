# 项目文件导航 - Verilog Extractor

## 📚 文档快速导航

### 🎯 我应该读哪个文档？

#### 想快速上手？ ⏱️ 5分钟
→ 阅读 **`QUICK_REFERENCE.md`**
- 最常用的操作
- 代码示例
- 常见任务

#### 想全面了解功能？ ⏱️ 15分钟
→ 阅读 **`SIGNAL_CONNECTION_GUIDE.md`**
- 完整的功能说明
- 详细的 API 文档
- 应用场景说明

#### 想看实现细节？ ⏱️ 20分钟
→ 阅读 **`IMPLEMENTATION_SUMMARY.md`**
- 功能完成清单
- 技术细节
- 性能指标

#### 想要完整项目介绍？ ⏱️ 30分钟
→ 阅读 **`README_CONNECTION_GRAPH.md`**
- 项目概述
- 所有功能说明
- 学习路径

---

## 📁 文件结构说明

### 核心模块
```
verilog_extractor.py          主模块
├─ VerilogExtractor 类        - 提取 Verilog 信息
│  ├─ extract_module_ports()
│  ├─ extract_module_instantiations()
│  ├─ extract_signal_definitions()
│  ├─ build_signal_connection_graph()
│  └─ print_connection_graph()
│
└─ SignalConnectionGraph 类    - 信号连接分析（新增）
   ├─ add_instance()
   ├─ add_connection()
   ├─ get_signal_source()
   ├─ get_signal_destinations()
   ├─ get_signal_fanout()
   ├─ trace_signal()
   ├─ get_all_signals()
   ├─ print_connection_graph()
   └─ generate_connection_report()
```

### 示例程序
```
example_comprehensive_analysis.py    - 综合分析示例
├─ 复杂系统分析
├─ 完整的报告输出
└─ 数据路径追踪

test_connection_practical.py         - 实际应用示例
├─ 管道设计分析
├─ 扇出分析
└─ 信号追踪

test_connection_graph.py             - 功能测试
├─ 基础功能测试
├─ 复杂连接测试
└─ 问题诊断测试

test_comprehensive.py                - 完整测试
├─ Verilog95 风格
├─ SystemVerilog2018 风格
└─ 混合风格支持

test_extractor.py & test_cache.v    - 其他测试
```

### 文档文件
```
QUICK_REFERENCE.md                   - 快速参考（推荐首先阅读）
SIGNAL_CONNECTION_GUIDE.md           - 详细功能指南
IMPLEMENTATION_SUMMARY.md            - 实现总结
README_CONNECTION_GRAPH.md           - 完整项目说明
INDEX.md                             - 本文件（导航）
```

---

## 🎓 推荐学习路径

### 路径 1：快速入门（15分钟）
```
1. 阅读 QUICK_REFERENCE.md (5分钟)
   └─ 了解基本 API 和使用方法

2. 运行 example_comprehensive_analysis.py (5分钟)
   └─ 查看实际输出示例

3. 修改示例代码，尝试自己的设计 (5分钟)
   └─ 动手操作
```

### 路径 2：深度学习（30分钟）
```
1. 阅读 SIGNAL_CONNECTION_GUIDE.md (10分钟)
   └─ 了解完整功能

2. 运行所有测试文件 (10分钟)
   └─ test_connection_graph.py
   └─ test_connection_practical.py
   └─ example_comprehensive_analysis.py

3. 阅读源代码注释 (10分钟)
   └─ verilog_extractor.py 中的 SignalConnectionGraph 类
```

### 路径 3：项目开发（1小时）
```
1. 读 README_CONNECTION_GRAPH.md (15分钟)
   └─ 全面了解项目

2. 读 IMPLEMENTATION_SUMMARY.md (15分钟)
   └─ 了解技术细节

3. 阅读完整源代码 (20分钟)
   └─ 理解实现原理

4. 尝试扩展功能 (10分钟)
   └─ 添加自己的分析方法
```

---

## 🔍 快速查找

### 我想... 查看哪个文件？

| 需求 | 查看文件 | 具体位置 |
|------|---------|---------|
| 快速上手 | QUICK_REFERENCE.md | "最常用的操作" |
| API 文档 | SIGNAL_CONNECTION_GUIDE.md | "核心类：SignalConnectionGraph" |
| 代码示例 | QUICK_REFERENCE.md | "完整示例" |
| 功能列表 | IMPLEMENTATION_SUMMARY.md | "核心功能清单" |
| 使用案例 | SIGNAL_CONNECTION_GUIDE.md | "应用场景" |
| 性能指标 | IMPLEMENTATION_SUMMARY.md | "性能考虑" |
| 常见问题 | 各文档的末尾 | FAQ 部分 |
| 源代码 | verilog_extractor.py | 第 1-180 行 |
| 测试代码 | test_*.py | 各测试文件 |

---

## 📊 功能对应表

### 基础提取功能（原有）
```
extract_module_ports()              - 提取模块端口
extract_module_instantiations()     - 提取实例化信息
extract_signal_definitions()        - 提取信号定义
extract_all()                       - 一次性提取所有信息
print_report()                      - 打印基本报告
```

### 新增连接关系功能
```
build_signal_connection_graph()      - 构建连接图
print_connection_graph()             - 打印连接图
trace_signal()                       - 追踪信号路径
get_signal_fanout()                 - 获取扇出值
get_signal_source()                 - 获取驱动源
get_signal_destinations()            - 获取接收端
```

---

## 🚀 常见使用场景

### 场景 1：基本设计分析
**需要的文件：**
- `verilog_extractor.py`
- `QUICK_REFERENCE.md`

**步骤：**
1. 用 VerilogExtractor 加载 Verilog 文件
2. 调用 `print_report()` 查看基本信息
3. 调用 `print_connection_graph()` 查看连接

### 场景 2：信号连接分析
**需要的文件：**
- `verilog_extractor.py`
- `SIGNAL_CONNECTION_GUIDE.md`

**步骤：**
1. 构建连接图 `build_signal_connection_graph()`
2. 查询具体信号 `trace_signal()`
3. 分析扇出值 `get_signal_fanout()`

### 场景 3：自动化流程
**需要的文件：**
- `verilog_extractor.py`
- `example_comprehensive_analysis.py` （作为参考）

**步骤：**
1. 编写分析脚本
2. 遍历设计中的所有信号
3. 输出自定义报告

---

## 🐛 常见问题与解决

### Q: 如何查找高扇出信号？
A: 见 `QUICK_REFERENCE.md` → "找出高扇出信号"

### Q: 如何追踪信号路径？
A: 见 `QUICK_REFERENCE.md` → "追踪信号路径"

### Q: 如何检测设计问题？
A: 见 `QUICK_REFERENCE.md` → "检查设计中的问题"

### Q: API 具体有哪些？
A: 见 `SIGNAL_CONNECTION_GUIDE.md` → "核心类" 部分

### Q: 支持哪些 Verilog 风格？
A: 见 `IMPLEMENTATION_SUMMARY.md` → "功能特性"

### Q: 性能如何？
A: 见 `IMPLEMENTATION_SUMMARY.md` → "性能考虑"

---

## 📝 文件大小和内容量

| 文件 | 大小 | 内容 | 阅读时间 |
|-----|------|------|---------|
| QUICK_REFERENCE.md | 4KB | API 和示例 | 5-10 分钟 |
| SIGNAL_CONNECTION_GUIDE.md | 8KB | 详细功能说明 | 10-15 分钟 |
| IMPLEMENTATION_SUMMARY.md | 6KB | 实现总结 | 10-15 分钟 |
| README_CONNECTION_GRAPH.md | 10KB | 完整说明 | 15-20 分钟 |
| verilog_extractor.py | 25KB | 源代码 | 20-30 分钟 |

**总阅读时间：** 60-90 分钟（完全理解项目）

---

## ✅ 检查清单

在使用项目之前，确保：

- [ ] 阅读了至少一份文档（推荐 QUICK_REFERENCE.md）
- [ ] 运行过至少一个示例程序
- [ ] 理解了 SignalConnectionGraph 的基本操作
- [ ] 能够解释什么是 fanout（扇出）
- [ ] 知道如何追踪一个信号

---

## 🔄 文件更新日期

| 文件 | 更新日期 | 版本 |
|-----|---------|------|
| verilog_extractor.py | 2026-02-04 | 1.0 |
| QUICK_REFERENCE.md | 2026-02-04 | 1.0 |
| SIGNAL_CONNECTION_GUIDE.md | 2026-02-04 | 1.0 |
| IMPLEMENTATION_SUMMARY.md | 2026-02-04 | 1.0 |
| README_CONNECTION_GRAPH.md | 2026-02-04 | 1.0 |
| INDEX.md | 2026-02-04 | 1.0 |

---

## 📞 需要帮助？

### 按问题类型查找

**问题：** 如何安装和使用？
**查看：** `QUICK_REFERENCE.md` → "最常用的操作"

**问题：** API 有什么函数？
**查看：** `SIGNAL_CONNECTION_GUIDE.md` → "核心类"

**问题：** 源代码怎么写的？
**查看：** `verilog_extractor.py` 的注释

**问题：** 有没有更多示例？
**查看：** `example_*.py` 和 `test_*.py`

**问题：** 性能如何？
**查看：** `IMPLEMENTATION_SUMMARY.md` → "性能考虑"

---

## 🎯 下一步

选择您感兴趣的部分：

1. **[快速开始]** → 打开 `QUICK_REFERENCE.md`
2. **[深入学习]** → 打开 `SIGNAL_CONNECTION_GUIDE.md`
3. **[查看源代码]** → 打开 `verilog_extractor.py`
4. **[运行示例]** → 执行 `python example_comprehensive_analysis.py`
5. **[项目概览]** → 阅读 `README_CONNECTION_GRAPH.md`

---

**祝您使用愉快！** 🎉

*如有任何问题，请参考相应的文档部分。*

**最后更新：2026年2月4日**
