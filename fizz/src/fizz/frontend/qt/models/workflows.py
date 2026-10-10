"""Navigation and page metadata, independent of Qt widgets."""

from dataclasses import dataclass


@dataclass(frozen=True)
class Workflow:
    key: str
    title: str
    icon: str
    description: str


WORKFLOWS = (
    Workflow(
        "merge",
        "文件合并",
        "file-code-corner",
        "解析源文件列表，按顺序合并 SystemVerilog 文件。",
    ),
    Workflow(
        "vcs",
        "VCS Protect",
        "file-braces-corner",
        "使用 VCS 密钥和保护选项加密源文件。",
    ),
    Workflow(
        "obf", "Obfuscator", "git-compare", "管理白名单和映射文件，生成混淆后的源代码。"
    ),
    Workflow(
        "rlskit", "RLskit", "archive", "打包发布目录、编辑 Release Note，并上传到 FTP。"
    ),
    Workflow(
        "postsim",
        "后仿分析",
        "search",
        "搜索仿真日志，提取 Timing violation 并管理 waive。",
    ),
)
