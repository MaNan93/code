# pcie_pipe_link

模块设计文档见 [DESIGN.md](DESIGN.md)，包含 overview、description（IO list）和 function。

## 目录结构

```text
pcie_pipe_link/
├── rtl/                  设计 RTL
├── tests/                功能回归及运行脚本
├── synth/                综合检查脚本
├── docs/
│   ├── figures/          时序图 PNG / SVG
│   └── render_timing.py  时序图生成脚本
├── build/                本地构建输出，不纳入交付源码
├── flist.f               RTL 编译清单
├── DESIGN.md             模块设计文档
└── README.md             目录及运行说明
```

可综合的双端 PIPE 数字直连模块，支持 Gen1–Gen5、参数化 NL，每 lane 32 bit。两端接口分别展平为 `dsp_...` / `usp_...`；对应工程中控制器运行时为 RP / EP。

## 文件与层次

```text
pcie_pipe_link
├── u_dsp_side / u_usp_side            pcie_pipe_side，shared
│   ├── u_clock_switch               pcie_pipe_pclk_switch
│   │   └── u_gate_pclk_*             pcie_pipe_clock_gate，显式实例化
│   └── g_lane[i].u_lane              pcie_pipe_lane，per-lane
│       ├── u_eq                     pcie_pipe_eq_lane
│       └── u_status                 pcie_pipe_status_lane
```

只有 NL 个 lane 的复制使用 generate。所有端口使用 logic，一行一个；非阻塞赋值一行一条。`flist.f` 仅列出这 7 个模块，不依赖控制器 RTL 或 vendor include。

## 时钟与复位

输入 `pclk_62p5`、`pclk_125`、`pclk_250`、`pclk_500`、`pclk_1000` 分别对应 rate 0/1/2/3/4（MHz：62.5/125/250/500/1000）。两侧 `mac_phy_rate` 和 `active_rate` 均为 3 bit，rate=4 表示 Gen5，5～7 不支持。固定每 lane 32 bit 时，Gen5 选用 1 GHz PCLK。速率编码依据 DWC 6.30a EP Reference §2.140，p.1690。

五路 `pclk_*` 输入在复位、切频和低功耗期间均持续运行。`pclk_62p5` 同时用于管理逻辑。PowerDown 不关闭输出 PCLK，切速期间允许输出低电平延长；`phy_ref_clk_req_n` 仅表示参考时钟请求，不用于关闭这些输入源。

两侧增加兼容输入 `dsp_mac_phy_txmargin` / `usp_mac_phy_txmargin`（每侧共享 3 bit，所有 lane 共用）和 `dsp_mac_phy_pclk_rate` / `usp_mac_phy_pclk_rate`（每侧共享 3 bit）。这些输入不参与逻辑，改变其值不影响数据、时钟或状态应答；时钟选择仍由 `mac_phy_rate` 控制。

两侧还提供下列兼容接口，名称均带 `dsp_` / `usp_` 前缀：

| 信号 | 方向（相对本模块） | 每侧总位宽 | 行为 |
|---|---|---|---|
| `mac_phy_width` | 输入 | 2 | 不使用，数据路径固定为每 lane 32 bit |
| `mac_phy_rxpolarity` | 输入 | `NL` | 不使用 |
| `mac_phy_messagebus` | 输入 | `NL*8` | 不使用 |
| `phy_mac_messagebus` | 输出 | `NL*8` | 已有接口，保持输出 0，不产生消息应答 |
| `mac_phy_txcompliance` | 输入 | `NL` | 不使用 |
| `mac_phy_lf` / `mac_phy_fs` | 输入 | 各 `NL*6` | 不使用 |
| `mac_phy_rxpresethint` | 输入 | `NL*3` | 不使用 |

每 lane 信号按 lane 0 位于最低位展平。新增输入的声明宽度参考本地控制器 RTL 及 DWC 6.30a EP Reference 的信号表（§2.139、§2.141）；仅用于端口连接兼容，不增加对应 PHY 功能。

输出 `dsp_pclk` / `usp_pclk` 分别按本端 mac_phy_rate 独立切换，允许请求先后到达。每端通过先关闭旧源、确认关闭再打开新源的状态机切换；门控请求经输入时钟正沿两级触发器同步，再由低电平透明锁存器保持使能，高电平期间使能不变，切换可拉长低电平。复位分别使用 `dsp_phy_rst_n` / `usp_phy_rst_n`，无额外全局 rst_n；复位恢复 Gen1。异步复位仍直接恢复门控初值，复位断言期间不保证 PCLK 脉宽。

两端频率不同或切换未完成时，接收侧输出电气空闲，数据/valid/block/header 被屏蔽；两端稳定在相同物理时钟源后恢复传输。无异步 FIFO，不缓存速率不一致期间的业务数据。

## EQ 与应答

参考控制器附带的 generic PHY，使用确定性的理想通道响应：Gen3 FS/LF=48/18、Gen4/Gen5 FS/LF=47/15；preset 查询返回 `{C+1,C0,C-1}` 和单周期 CoefValid；RxEqEval 完成及中止均返回 PhyStatus，DirectionFeedback=0、FOM=255。LocalPresetIndex 按项目接口扩展为每 lane 6 bit，总位宽为 `NL*6`；保留 PIPE 4.4 风格的 preset 编码：Gen3 P0～P10 为 0～10，Gen4/Gen5 为 11～21。普通并发完成事件串行输出，PhyStatus 脉冲之间保留低电平。EQ_CYCLES 和 ACK_CYCLES 默认 8，必须 >=1。

## L1 低功耗与时钟请求

两侧 `mac_phy_powerdown` 为共享 4 bit，按工程约定解释 4=L1 Idle、5=L1.1、6=L1.2。任一侧进入这些状态时，双向 RX 数据、valid、block、header 被屏蔽并输出电气空闲，不缓存期间的业务数据。4 对应 P1.CPM，使用普通的延迟 PhyStatus 脉冲；确认全部 lane 的共享完成应答已发出且脉冲回低后，释放参考时钟请求，不等待 AsyncPowerChangeAck。

每侧共享输入 `mac_phy_asyncpowerchangeack` 和共享输出 `phy_ref_clk_req_n` 均为 1 bit，带 `dsp_` / `usp_` 前缀。对 5/6，在常开的 `pclk_62p5` 域等待 ACK_CYCLES 个周期后，全部 lane 的 PhyStatus 拉高；收到 AsyncPowerChangeAck=1 后拉低 PhyStatus，再等 ACK 返回 0，完成本次握手。`phy_ref_clk_req_n` 为 0 表示请求时钟，为 1 表示允许停钟。若此前尚未允许停钟，则握手完成后拉高；若已在 PowerDown=4 获得停钟许可，则进入 5/6 及 5/6 之间切换时保持为 1。只有复位或退出 4/5/6 时才重新拉低，不依赖已停止的 PCLK。两端独立完成握手，MAC 须保持每次请求至应答完成。

依据：DWC 6.30a EP Reference Table 1-20 的 L1 Substates/L1.CPM 参数表 p.145（默认 P1.CPM/P1.1/P1.2 编码为 4/5/6；P1.CPM 是手册名称），EP Databook §3.18.5.2 p.352–353（普通 L1 的 P1.CPM 允许移除 REFCLK，Figure 3-97 给出时序），§2.139 p.1688（四相异步握手）；EP Databook §2.3.5.1 p.71–72、Figure 2-15（PHY 参考时钟请求与外部时钟控制）。集成时配置 `CX_PIPE43_ASYNC_HS_BYPASS=0`，并连接 AsyncPowerChangeAck；本模型不实现 bypass 模式。

## 验证范围

以下为原 Gen4 版本的历史验证记录，本次 Gen5/低功耗扩展未重跑 VCS 或 DC：

- VCS：五种 NL（1/2/4/8/16）、两端先后独立切频、非法速率、单侧 PHY 复位、preset 查询、EQ 完成/中止及并发应答通过。
- 完整控制器通过 DBI 请求从 Gen1 经 EQ0–EQ3 升至 Gen4 x4 L0，稳定 1000 周期，并生成 FSDB。
- Design Compiler：分析、展开、检查和 lsi_10k 示例库映射通过。未进行目标工艺时序/CDC/CTS 签核，也不模拟模拟 PHY 通道或验证 AXI/DMA 业务。

2026-11-12 门控改为正沿触发器＋低电平锁存器后，本地 Verilator 回归通过：四档速率全部 16 种切换组合、源时钟相位偏移、非法速率和复位恢复，检查 9880 个 PCLK 边沿及正常运行时的高低脉宽。顶层 lint 无错误，仍有位宽和未使用信号告警；集成展开另有 `NOLATCH` 告警，单独检查门控模块未出现此告警。本次未重跑上述 VCS 控制器 Link 或 DC 验证。

时钟回归入口为 `tests/run_clock_tests.py`，使用 Windows Verilator/GCC 工具链：

```powershell
python tests/run_clock_tests.py --verilator <verilator_bin.exe> --verilator-root <Verilator的Library目录> --cxx <g++.exe> --make <gnumake.exe>
```

`gcc-ar.exe` 须与 `g++.exe` 位于同一目录，构建输出位于 `build/clock_tests/`。添加 `--case link` 可运行顶层 Gen5/低功耗回归，输出位于 `build/link_tests/`。

Gen5 扩展后的本地回归：五档速率全部 25 种切换组合、源时钟相位偏移、非法速率 5～7、复位恢复通过，检查 24165 个 PCLK 边沿。顶层回归覆盖两端先后升到 Gen5、双向 valid、Gen5 FS/LF、preset 与 EQ 完成、单侧独立进入低功耗、PowerDown 4/5/6、异步四相握手，以及停止 1 GHz 源后的时钟请求恢复。未使用真实控制器复现 Gen5 Link，也未完成工艺综合、CDC/RDC 或 1 GHz STA。

在集成工程中按文件列表编译：

```sh
vcs -full64 -sverilog -F /path/to/pcie_pipe_link/flist.f ...
```
