# Verible Windows binaries

本目录的 11 个 `.exe` 来自 CHIPS Alliance 官方发布包，保持原始二进制内容。

- 版本：`v0.0-4296-g0f262651`
- 平台：Windows x86-64
- 官方发布时间：2026-09-23
- 本地更新日期：2026-10-17
- [官方发布记录](https://github.com/chipsalliance/verible/releases/tag/v0.0-4296-g0f262651)
- [官方 Windows 压缩包](https://github.com/chipsalliance/verible/releases/download/v0.0-4296-g0f262651/verible-v0.0-4296-g0f262651-win64.zip)
- 压缩包 SHA-256：`4590841d91dadb108879aa261dbfd7081db06360484a7a21470174bf6fb3cf80`

下载后已按 GitHub 发布资产的 SHA-256 校验压缩包；各程序与解压出的官方文件
逐字节校验一致。[RELEASE.json](RELEASE.json) 记录来源及每个程序的 SHA-256。

从 `code` 根目录检查当前版本：

```powershell
.\misc\verible\verible-verilog-format.exe --version
.\misc\verible\verible-verilog-syntax.exe --version
```

此次从 `v0.0-4192-g682a1d50` 升级。全部 11 个程序的 `--version` 检查通过；
vutils 回归 12 项、PCIe 回归 33 项、PLM 格式化及预览检查 18 项全部通过。
另以真实新版本程序完成 PLM 严格格式化及结果重新解析。

`1`、`2` 为原有的语法标记输出记录，不属于官方发布包。
