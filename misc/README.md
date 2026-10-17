# Misc

本目录收纳九个独立项目以外的工具、示例和历史资料，由父仓库
[`MaNan93/code`](https://github.com/MaNan93/code) 管理。

- `getaxiinfo/`、`runall/`、`smics28_mem_gen/`、
  [`verible/verilog_extractor_project/`](verible/verilog_extractor_project/README.md)
  是普通子目录，不再各自建立 Git 仓库。
- `dwc_bfm_gpt/`、`pcie_native_bfm/`、`postsim_analyzer/`、`fec/`、`ffe/`、
  `gen_excel/`、`vtags-3.11/`、散落脚本、`examples/` 和 `src/` 保留原有内容。
- [`verible/`](verible/README.md) 保存官方 Windows 共享工具，当前版本为
  `v0.0-4296-g0f262651`。`vutils` 支持从此处自动发现语法解析程序；其他工具
  如需通过 PATH 调用 Verible，可在当前 PowerShell 会话中执行：

  ```powershell
  $env:PATH = "$((Resolve-Path ./misc/verible).Path);$env:PATH"
  ```

  上述命令从 `code` 根目录执行；环境变量中的旧 `code/verible` 路径需更新为
  `code/misc/verible`。
- `.github/workflows/` 是原父仓库工作流的归档，不会在此路径触发 Actions。
  PLM 和 ralf2xlsx 的现用工作流已迁入各自仓库，并更新为独立仓库路径。

本地缓存、IDE 配置、Git 备份和原根目录虚拟环境也移至此处，但继续排除在提交外。
虚拟环境中可能包含旧绝对路径；需要使用时应在目标工具目录重新创建环境。
