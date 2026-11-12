# pcie_pipe_loopback

可综合的双端 PIPE 数字直连模块，支持 Gen1–Gen4、参数化 NL（验证过 1/2/4/8/16），每 lane 32 bit。两端接口分别展平为 `dsp_...` / `usp_...`；对应工程中控制器运行时为 RP / EP。

## 文件与层次

```text
pcie_pipe_loopback
├── u_dsp_side / u_usp_side            pcie_pipe_side，shared
│   ├── u_clock_switch               pcie_pipe_pclk_switch
│   │   └── u_gate_pclk_*             pcie_pipe_clock_gate，显式实例化
│   └── g_lane[i].u_lane              pcie_pipe_lane，per-lane
│       ├── u_eq                     pcie_pipe_eq_lane
│       └── u_status                 pcie_pipe_status_lane
```

只有 NL 个 lane 的复制使用 generate。所有端口使用 logic，一行一个；非阻塞赋值一行一条。`flist.f` 仅列出这 7 个模块，不依赖控制器 RTL 或 vendor include。

## 时钟与复位

输入 `pclk_62p5`、`pclk_125`、`pclk_250`、`pclk_500` 分别对应 rate 0/1/2/3（MHz：62.5/125/250/500）；这些源时钟必须持续运行。`pclk_1000` 保留但不会选用，rate >=4 不支持。

输出 `dsp_pclk` / `usp_pclk` 分别按本端 mac_phy_rate 独立切换，允许请求先后到达。每端通过先关闭旧源、确认关闭再打开新源的状态机切换；门控请求经输入时钟正沿两级触发器同步，再由低电平透明锁存器保持使能，高电平期间使能不变，切换可拉长低电平。复位分别使用 `dsp_phy_rst_n` / `usp_phy_rst_n`，无额外全局 rst_n；复位恢复 Gen1。异步复位仍直接恢复门控初值，复位断言期间不保证 PCLK 脉宽。

两端频率不同或切换未完成时，接收侧输出电气空闲，数据/valid/block/header 被屏蔽；两端稳定在相同物理时钟源后恢复传输。无异步 FIFO，不缓存速率不一致期间的业务数据。

## EQ 与应答

参考控制器附带的 generic PHY，使用确定性的理想通道响应：Gen3 FS/LF=48/18、Gen4 FS/LF=47/15；preset 查询返回 `{C+1,C0,C-1}` 和单周期 CoefValid；RxEqEval 完成及中止均返回 PhyStatus，DirectionFeedback=0、FOM=255。并发完成事件串行输出，PhyStatus 脉冲之间保留低电平。EQ_CYCLES 和 ACK_CYCLES 默认 8，必须 >=1。

## 验证范围

- VCS：五种 NL、两端先后独立切频、非法速率、单侧 PHY 复位、preset 查询、EQ 完成/中止及并发应答通过。
- 完整控制器通过 DBI 请求从 Gen1 经 EQ0–EQ3 升至 Gen4 x4 L0，稳定 1000 周期，并生成 FSDB。
- Design Compiler：分析、展开、检查和 lsi_10k 示例库映射通过。未进行目标工艺时序/CDC/CTS 签核，也不模拟模拟 PHY 通道或验证 AXI/DMA 业务。

2026-11-12 门控改为正沿触发器＋低电平锁存器后，本地 Verilator 回归通过：四档速率全部 16 种切换组合、源时钟相位偏移、非法速率和复位恢复，检查 9880 个 PCLK 边沿及正常运行时的高低脉宽。顶层 lint 无错误，仍有位宽和未使用信号告警；集成展开另有 `NOLATCH` 告警，单独检查门控模块未出现此告警。本次未重跑上述 VCS 控制器 Link 或 DC 验证。

时钟回归入口为 `tests/run_clock_tests.py`，使用 Windows Verilator/GCC 工具链：

```powershell
python tests/run_clock_tests.py --verilator <verilator_bin.exe> --verilator-root <Verilator的Library目录> --cxx <g++.exe> --make <gnumake.exe>
```

`gcc-ar.exe` 须与 `g++.exe` 位于同一目录，构建输出位于 `build/clock_tests/`。

在集成工程中按文件列表编译：

```sh
vcs -full64 -sverilog -F /path/to/pcie_pipe_loopback/flist.f ...
```
