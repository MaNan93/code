#!/usr/bin/env python
"""Setup script for fizz package"""

from setuptools import setup, find_packages

setup(
    name="fizz",
    version="0.3.1",
    packages=find_packages(where="src"),
    package_dir={"": "src"},
    package_data={
        "fizz.frontend.qt": [
            "assets/fonts/*.ttf", "assets/fonts/*.txt", "assets/fonts/*.md",
            "assets/icons/*.svg", "assets/icons/*.txt", "styles/*.qss",
        ],
    },
    python_requires=">=3.12",
    install_requires=["PyQt5>=5.15"],
    author="Developer",
    description="SV file merger with VCS Protect, Obfuscator and RLskit support",
    long_description=open("README.md", encoding="utf-8").read(),
    long_description_content_type="text/markdown",
    url="https://github.com/MaNan93/code",
    keywords=["verilog", "systemverilog", "merge", "vcs", "obfuscate", "rlskit"],
    classifiers=[
        "Development Status :: 4 - Beta",
        "Intended Audience :: Developers",
        "License :: OSI Approved :: MIT License",
        "Programming Language :: Python :: 3",
        "Programming Language :: Python :: 3.12",
        "Programming Language :: Python :: 3.13",
        "Topic :: Software Development :: Libraries :: Python Modules",
        "Topic :: Utilities",
    ],
    entry_points={
        "console_scripts": [
            "fizz=fizz.frontend.qt.main:main",
        ],
    },
)
