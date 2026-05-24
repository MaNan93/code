# smics28-mem-gen

Parallel MEM_COMPILER runner for all `.spec` files in the script directory.

## Requirements

- Python >= 3.6.8

## Install

```bash
pip install -e .
```

Run after install:

```bash
smics28-mem-gen --max-job=5 --mem-compiler=/path/to/mem_compiler --out-dir=./out
```

Or run directly:

```bash
python smics28_mem_gen.py --max-job=5 --mem-compiler=/path/to/mem_compiler --out-dir=./out
```
