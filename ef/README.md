# ef - File List Expander

Verilog/SystemVerilog file list expander with recursive parsing support.

## Features

- **Two parsing modes:**
  - `-f`: Direct parsing, compilation options remain unchanged
  - `-F`: Path-relative expansion based on filelist directory
- **Recursive parsing** with cycle detection
- **Quote-aware comment handling** to prevent accidental truncation
- **Three verbosity levels** for debugging:
  - Normal: Show expanded items only
  - `-v/-vv`: Show trace information
  - `--very-verbose` (or `-vv`): Show source file:line:content tracing
- **Environment variable expansion** with `$VAR` and `${VAR}` support
- **Library API** for integration into other tools

## Installation

### Using pip (recommended)

```bash
pip install -e .
```

Or for normal installation:

```bash
pip install .
```

### From source

```bash
cd ef
python -m pip install -e .
```

## Usage

### Command Line

```bash
# Direct parsing mode (-f)
ef filelist.f

# Path-relative expansion mode (-F)
ef -F filelist.f

# With verbose output
ef -vv filelist.f

# With very verbose output
ef --very-verbose filelist.f

# Save output to file
ef -F filelist.f -o expanded.f
```

### As a Library

```python
from ef import ef

# Simple usage
result = ef('main.f', mode='F', verbose=False)
if result['success']:
    for item in result['items']:
        print(item)
else:
    print("Parse failed:")
    for error in result['errors']:
        print(f"  {error}")
```

## Options

```
-f FILE              Direct parsing, compilation options unchanged
-F FILE              Parse with path expansion relative to filelist
-o FILE, --output    Output file path
-v, --verbose        Show detailed debug info (can repeat: -vv)
--very-verbose       Very verbose (equivalent to -vv)
```

## Examples

### Expand a filelist
```bash
ef -F design.f -o expanded.f
```

### Debug parsing with verbose output
```bash
ef -vv design.f
```

### Use as library with different verbosity
```python
from ef import ef

# Normal mode
result = ef('flist.f', mode='F', verbose=0)

# Verbose mode
result = ef('flist.f', mode='F', verbose=1)

# Very verbose mode
result = ef('flist.f', mode='F', verbose=2)
```

## Result Structure

The `ef()` function returns a dictionary with:

- `success` (bool): True if parsing succeeded without critical errors
- `items` (list): Expanded files and compilation options
- `errors` (list): Critical errors (missing files, circular references)
- `warnings` (list): Non-critical issues (missing directories, etc.)
- `output` (list or None): Debug output in verbose mode

## Error Handling

The tool provides detailed error messages for:
- Missing files/directories
- Circular references with full chain visualization
- Permission errors
- Encoding errors
- Invalid paths

## Performance

- Stack-based recursion tracking allows repeated (non-circular) includes
- Efficient cycle detection using set lookups
- Linear time complexity relative to total file size

## License

MIT

## Support

For issues or questions, please refer to the project documentation.
