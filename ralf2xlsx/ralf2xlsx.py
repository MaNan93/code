#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Thin wrapper kept for `python ralf2xlsx.py ...` direct usage.

The real implementation now lives in src/ralf2xlsx/ralf2xlsx.py and is
packaged as the `ralf2xlsx` wheel (console script: `ralf2xlsx`).
"""
import os
import sys

sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), 'src'))

from ralf2xlsx.ralf2xlsx import main  # noqa: E402

if __name__ == '__main__':
    sys.exit(main())
