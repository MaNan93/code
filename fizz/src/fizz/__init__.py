"""
fizz - SV文件合并工具
支持从 generalMessage.txt 提取文件路径，按顺序合并为一个文件，
同时提供 VCS Protect、Obfuscator、RLskit 打包上传等功能。
"""

from .fizz import FizzApp, main

__version__ = "0.2.0"
__all__ = ["FizzApp", "main"]
