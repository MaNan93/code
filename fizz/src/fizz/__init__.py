"""
fizz - SV文件合并工具
支持从 generalMessage.txt 提取文件路径，按顺序合并为一个文件，
同时提供 VCS Protect、Obfuscator、RLskit 打包上传等功能。

The Qt frontend (`fizz.frontend.qt.main:main`) is the packaged `fizz`
console script; importing it here would pull in PyQt5 just to import this
package, so it's left as a submodule import (`from fizz.frontend.qt.main
import main`) rather than re-exported at the top level.
"""

__version__ = "0.3.1"
