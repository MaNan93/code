# Verilog Extractor Project - Getting Started Guide

## 📂 File Organization

### Core Files
- **verilog_extractor.py** - Main library with VerilogExtractor and SignalConnectionGraph classes

### Test/Example Files
- **test_verilog.v** - Sample Verilog designs for testing
- **test_comprehensive.py** - Basic functionality tests
- **test_connection_graph.py** - Signal connection graph tests
- **test_connection_practical.py** - Practical usage examples
- **example_comprehensive_analysis.py** - Full analysis walkthrough

### Documentation
- **README.md** - Project overview (start here!)
- **QUICK_REFERENCE.md** - Command cheat sheet
- **IMPLEMENTATION_SUMMARY.md** - Technical details
- **README_CONNECTION_GRAPH.md** - Connection graph feature doc
- **SIGNAL_CONNECTION_GUIDE.md** - Signal connection how-to
- **INDEX.md** - Full documentation index
- **COMPLETION_REPORT.txt** - Development report

## 🎯 Where to Start

### 1️⃣ First Time Users
```
1. Read README.md (overview)
2. Check QUICK_REFERENCE.md (quick start)
3. Run: python test_comprehensive.py
```

### 2️⃣ Connection Graph Users
```
1. Read README_CONNECTION_GRAPH.md
2. Run: python test_connection_graph.py
3. Study: test_connection_practical.py
```

### 3️⃣ Full Deep Dive
```
1. Read IMPLEMENTATION_SUMMARY.md
2. Read SIGNAL_CONNECTION_GUIDE.md
3. Run: python example_comprehensive_analysis.py
4. Check INDEX.md for advanced topics
```

## 💻 Basic Commands

### Extract from string
```python
from verilog_extractor import VerilogExtractor

code = "module test (input a, output b); endmodule"
ex = VerilogExtractor(code)
ex.print_report()
```

### Extract from file
```python
from verilog_extractor import extract_from_file

results = extract_from_file('design.v')
print(results['module_ports'])
```

### Use connection graph
```python
from verilog_extractor import VerilogExtractor, SignalConnectionGraph

code = "..."
ex = VerilogExtractor(code)
graph = SignalConnectionGraph(ex.extract_all())
graph.print_connectivity_report()
```

## 🧪 Run Tests

```bash
# Test basic functionality
python test_comprehensive.py

# Test connection graph
python test_connection_graph.py

# Practical examples
python test_connection_practical.py

# Complete analysis
python example_comprehensive_analysis.py
```

## 📊 Features by Category

### Data Extraction
- Module ports (input, output, inout)
- Signal definitions (wire, reg, logic, bit, int, real, string)
- Module instantiations
- Parameters and localparams

### Analysis
- Signal connectivity mapping
- Port connection tracing
- Signal flow analysis
- Hierarchical design understanding

### Output
- Formatted text reports
- Python dictionary format
- JSON export (via connectivity graph)
- Connectivity reports

## 🔄 Workflow Example

```python
# 1. Parse design
from verilog_extractor import VerilogExtractor, SignalConnectionGraph

with open('design.v') as f:
    code = f.read()

# 2. Extract structure
extractor = VerilogExtractor(code)
results = extractor.extract_all()

# 3. Analyze connections
graph = SignalConnectionGraph(results)
graph.build_connection_map()

# 4. Get insights
connectivity = graph.export_connectivity()
sources = graph.get_signal_sources('output_signal')
destinations = graph.get_signal_destinations('input_signal')

# 5. Generate reports
extractor.print_report()
graph.print_connectivity_report()
```

## 📚 Documentation Quick Links

| Need | File |
|------|------|
| Quick reference | QUICK_REFERENCE.md |
| How it works | IMPLEMENTATION_SUMMARY.md |
| Connection graph API | README_CONNECTION_GRAPH.md |
| Connection examples | SIGNAL_CONNECTION_GUIDE.md |
| All topics | INDEX.md |

## 🎓 Learning Path

**Beginner** → Read README.md + run test_comprehensive.py
↓
**Intermediate** → Read QUICK_REFERENCE.md + try basic extraction
↓
**Advanced** → Read IMPLEMENTATION_SUMMARY.md + use SignalConnectionGraph
↓
**Expert** → Read all documentation + contribute improvements

## ⚙️ Python Requirements

- Python 3.6+
- Standard library only (no external dependencies)

## 🚨 Troubleshooting

**"No module found" error**
- Make sure you're in the correct directory
- Use: `from verilog_extractor import VerilogExtractor`

**Unicode errors on Windows**
- Set encoding in file read: `open(file, encoding='utf-8')`

**Parsing issues**
- Check for comments that interfere with declarations
- Simplify test case to debug

## 📈 Project Statistics

- **Core Library**: 1 main file (verilog_extractor.py)
- **Test Files**: 4 comprehensive test suites
- **Documentation**: 6 detailed guides + 1 README
- **Lines of Code**: 500+ (core) + 300+ (tests)
- **Supported Standards**: Verilog95, Verilog2001/2005, SystemVerilog2018

## 🎉 Ready to Start?

1. Choose your learning path from "Learning Path" section above
2. Read the appropriate documentation
3. Run a test to see it in action
4. Try it on your own Verilog designs!

---

**Next Steps**: Open `README.md` or run `python test_comprehensive.py`
