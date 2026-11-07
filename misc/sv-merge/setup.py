#!/usr/bin/env python3
import os
from setuptools import setup, find_packages

here = os.path.abspath(os.path.dirname(__file__))

with open(os.path.join(here, "README.md"), "r", encoding="utf-8") as fh:
    long_description = fh.read()

setup(
    name="sv-merge",
    version="1.0.0",
    author="MaNan",
    description="Robust, Dependency-Aware SystemVerilog & Verilog Filelist Merger",
    long_description=long_description,
    long_description_content_type="text/markdown",
    url="https://github.com/MaNan93/sv-merge",
    package_dir={"": "src"},
    packages=find_packages(where="src"),
    classifiers=[
        "Programming Language :: Python :: 3",
        "Programming Language :: Python :: 3.6",
        "Programming Language :: Python :: 3.7",
        "Programming Language :: Python :: 3.8",
        "Programming Language :: Python :: 3.9",
        "Programming Language :: Python :: 3.10",
        "Programming Language :: Python :: 3.11",
        "Programming Language :: Python :: 3.12",
        "License :: OSI Approved :: MIT License",
        "Operating System :: OS Independent",
        "Topic :: Scientific/Engineering :: Electronic Design Automation (EDA)",
    ],
    python_requires=">=3.6",
    entry_points={
        "console_scripts": [
            "sv-merge = sv_merge.cli:main",
        ],
    },
)
