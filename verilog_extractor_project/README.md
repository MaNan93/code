# Verilog Extractor Project

A comprehensive Python tool for extracting and analyzing Verilog/SystemVerilog source code structure, including port definitions, module instantiations, signal definitions, and signal connection relationships.

## 📁 Project Structure

```
verilog_extractor_project/
├── verilog_extractor.py                    # Core library (主库)
├── test_verilog.v                          # Test Verilog design (测试文件)
├── test_comprehensive.py                   # Comprehensive tests (全面测试)
├── test_connection_graph.py                # Connection graph tests (连接图测试)
├── test_connection_practical.py            # Practical connection examples (实用例子)
├── example_comprehensive_analysis.py       # Full analysis example (完整分析示例)
│
├── README.md                               # This file
├── QUICK_REFERENCE.md                      # Quick start guide (快速参考)
├── IMPLEMENTATION_SUMMARY.md               # Implementation details (实现细节)
├── README_CONNECTION_GRAPH.md              # Connection graph documentation (连接图文档)
├── SIGNAL_CONNECTION_GUIDE.md              # Signal connection guide (信号连接指南)
├── INDEX.md                                # Documentation index (文档索引)
└── COMPLETION_REPORT.txt                   # Completion report (完成报告)
```

## 🚀 Quick Start

### Basic Usage

```python
from verilog_extractor import VerilogExtractor

# From string
code = """
module counter (
    input clk,
    input reset,
    output reg [7:0] count
);
    // ...
endmodule
"""

extractor = VerilogExtractor(code)
extractor.print_report()
```

### Extract Data

```python
# Extract all information
results = extractor.extract_all()

# Get specific information
ports = extractor.extract_module_ports()
instantiations = extractor.extract_module_instantiations()
signals = extractor.extract_signal_definitions()
```

## ✨ Features

### 1. Module Port Extraction
- ✅ Supports Verilog95 style: `input clk`, `output reg [7:0] data`
- ✅ Supports SystemVerilog2018 style: `input logic clk`, `output logic [7:0] data`
- ✅ Automatic type inference for implicit declarations
- ✅ Extracts direction, data type, and bit width

### 2. Signal Definition Extraction
- ✅ **Verilog95**: wire, reg
- ✅ **SystemVerilog**: logic, bit, int, real, string
- ✅ Parameters and localparams
- ✅ Support for complex declarations with multiple signals

### 3. Module Instantiation Extraction
- ✅ Extract all module instances
- ✅ Parse port connections (named and positional)
- ✅ Handle complex hierarchical designs

### 4. Signal Connection Graph (NEW!)
- ✅ Build signal connectivity map
- ✅ Track signal flow through modules
- ✅ Identify connected ports and nets
- ✅ Export connectivity data

## 📖 Documentation

| Document | Purpose |
|----------|---------|
| [QUICK_REFERENCE.md](QUICK_REFERENCE.md) | Quick command reference and examples |
| [IMPLEMENTATION_SUMMARY.md](IMPLEMENTATION_SUMMARY.md) | Technical implementation details |
| [README_CONNECTION_GRAPH.md](README_CONNECTION_GRAPH.md) | Connection graph feature documentation |
| [SIGNAL_CONNECTION_GUIDE.md](SIGNAL_CONNECTION_GUIDE.md) | How to use signal connection features |
| [INDEX.md](INDEX.md) | Complete documentation index |

## 🧪 Testing

Run comprehensive tests:

```bash
python test_comprehensive.py          # All basic tests
python test_connection_graph.py       # Connection graph tests
python test_connection_practical.py   # Practical examples
python example_comprehensive_analysis.py  # Full analysis demo
```

## 📊 Supported Verilog Standards

- ✅ **Verilog 1995**: Classic Verilog syntax
- ✅ **Verilog 2001/2005**: Enhanced features
- ✅ **SystemVerilog 2017/2018**: Modern SystemVerilog features

## 🔧 Core Classes

### VerilogExtractor
Main class for parsing Verilog code.

Methods:
- `extract_module_ports()` - Get port definitions
- `extract_module_instantiations()` - Get module instances
- `extract_signal_definitions()` - Get signal declarations
- `extract_all()` - Get all information
- `print_report()` - Print formatted report

### SignalConnectionGraph (NEW!)
Analyze signal connectivity relationships.

Methods:
- `build_connection_map()` - Build connectivity graph
- `get_signal_destinations()` - Find where signals go
- `get_signal_sources()` - Find signal origins
- `print_connectivity_report()` - Print detailed report
- `export_connectivity()` - Export as JSON/dict

## 📊 Example Output

```
================================================================================
VERILOG MODULE EXTRACTION REPORT
================================================================================

[1] MODULE PORTS
Module Name: counter

Ports (3 total):
  input   wire   1            clk
  input   wire   1            reset
  output  reg    [7:0]        count

[2] MODULE INSTANTIATIONS
Total Instantiations: 1

  Module Type: counter_logic
  Instance Name: u0_logic
  Port Connections:
    .clk(clk)
    .reset(reset)
    .count(count)

[3] SIGNAL DEFINITIONS
Wires (1 total):
  wire 1            temp_signal

Parameters (1 total):
  parameter MAX_COUNT            = 255
```

## 🎯 Use Cases

1. **Design Analysis** - Understand complex module hierarchies
2. **Design Documentation** - Auto-generate signal lists
3. **Port Analysis** - Verify port connections
4. **Connectivity Verification** - Check signal routing
5. **Design Reviews** - Quick design structure inspection

## 🐛 Known Limitations

- Comments within port declarations may affect parsing
- Complex parameterized ports need manual inspection
- Mixed comment styles in signal declarations require careful formatting

## 📝 License

This tool is provided as-is for educational and professional use.

## 🤝 Contributing

Feel free to extend and improve:
- Add more signal type support
- Improve regex patterns for edge cases
- Add export formats (JSON, CSV, HTML)
- Add timing constraint extraction

## 📞 Support

Refer to the documentation files for:
- Detailed API reference
- Usage examples
- Troubleshooting
- Advanced features

---

**Last Updated**: February 4, 2026
**Version**: 2.0 (With Signal Connection Graph)
