# PIPE Lane Mapper — 工程变更文档

> **日期**: 2026-08-25
> **范围**: 全工程结构分析、配置重构、生成器清理、层次拆分

---

## 1. 变更总览

本次工作对 PIPE Lane Mapper RTL 生成工程做了全面改进，涉及 5 个方面：

| # | 变更 | 涉及文件 |
|---|------|----------|
| 1 | 反馈时钟段冗余例化改为按 group 共享 | `tools/plm_gen.py` |
| 2 | 默认 mode 配置从 2 个改为 4 个 | `config/controllers.csv`, `config/lane_mapping.csv` |
| 3 | PIPE 信号表从 21 个扩充到 39 个 + `phy_rst_n` | `config/pipe_signals.csv` |
| 4 | Python 脚本添加 CSV 空字符去除 | `tools/plm_config.py` |
| 5 | 顶层层次拆分：383 行平铺 → 4 模块 | `tools/plm_gen.py` (全部重写) |

---

## 2. 配置变更

### 2.1 controllers.csv

Ctrl2 的 `max_width` 从 4 改为 8，以支持 mode1 中 Ctrl2 承载 x8 带宽。

| ctrl_id | name | max_width (旧) | max_width (新) |
|---------|------|----------------|----------------|
| 0 | Ctrl0 | 16 | 16 |
| 1 | Ctrl1 | 8 | 8 |
| 2 | Ctrl2 | **4** | **8** |
| 3 | Ctrl3 | 4 | 4 |

### 2.2 lane_mapping.csv

从 2 个 mode 扩展为 4 个 mode，覆盖 PCIe lane reversal 的典型带宽配置：

| Mode | Lane 分配 | 带宽描述 |
|------|-----------|----------|
| 0 | Ctrl0: lane0~15 | x16 (Ctrl0 独占) |
| 1 | Ctrl0: lane0~7, Ctrl2: lane8~15 | x8 + x8 |
| 2 | Ctrl0: lane0~7, Ctrl2: lane8~11, Ctrl3: lane12~15 | x8 + x4 + x4 |
| 3 | Ctrl0: lane0~3, Ctrl1: lane4~7, Ctrl2: lane8~11, Ctrl3: lane12~15 | x4 × 4 |

### 2.3 pipe_signals.csv

从 21 个 per-lane 信号扩充到 39 个，使用用户原始命名 `mac_phy_*` / `phy_mac_*`。

**mac2phy 方向 (22 个信号，含 `phy_rst_n`)**:

| 信号名 | 宽度 | safe_level | 说明 |
|--------|------|------------|------|
| mac_phy_txdata | 32 | 0 | 发送数据 |
| mac_phy_txdatak | 4 | 0 | 数据控制字符 |
| mac_phy_txdatavalid | 1 | 0 | 数据有效 |
| mac_phy_txstartblock | 1 | 0 | 块起始 |
| mac_phy_txsyncheader | 2 | 0 | 同步头 |
| mac_phy_txdetectrx_loopback | 1 | 0 | RX loopback 检测 |
| mac_phy_txelecidle | 1 | **1** | 电气空闲 (安全态=1) |
| mac_phy_txcompliance | 1 | 0 | 合规发送 |
| mac_phy_txdeemph | 18 | 0 | 去加重 |
| mac_phy_rxpolarity | 1 | 0 | RX 极性 |
| mac_phy_rxstandby | 1 | **1** | RX 待机 (安全态=1) |
| mac_phy_messagebus | 8 | 0 | 消息总线 |
| mac_phy_rxpresethint | 3 | 0 | RX 预置提示 |
| mac_phy_local_pset_index | 5 | 0 | 本地 Pset 索引 |
| mac_phy_getlocal_pset_coef | 1 | 0 | 获取本地 Pset 系数 |
| mac_phy_invalid_req | 1 | 0 | 无效请求 |
| mac_phy_rxeqeval | 1 | 0 | RX 均衡评估 |
| mac_phy_fs | 6 | 0 | 全摆幅 |
| mac_phy_lf | 6 | 0 | 低频 |
| mac_phy_dirchange | 1 | 0 | 方向改变 |
| mac_phy_rxeqinprogress | 1 | 0 | RX 均衡进行中 |
| **phy_rst_n** | **1** | **1** | **PHY 复位 (安全态=1)** |

**phy2mac 方向 (17 个信号)**:

| 信号名 | 宽度 | safe_level | 说明 |
|--------|------|------------|------|
| phy_mac_rxdata | 32 | 0 | 接收数据 |
| phy_mac_rxdatak | 4 | 0 | 数据控制字符 |
| phy_mac_rxdatavalid | 1 | 0 | 数据有效 |
| phy_mac_rxstartblock | 1 | 0 | 块起始 |
| phy_mac_rxsyncheader | 2 | 0 | 同步头 |
| phy_mac_rxvalid | 1 | 0 | RX 有效 |
| phy_mac_rxstatus | 3 | 0 | RX 状态 |
| phy_mac_rxelecidle | 1 | **1** | 电气空闲 (安全态=1) |
| phy_mac_rxstandbystatus | 1 | **1** | RX 待机状态 (安全态=1) |
| phy_mac_messagebus | 8 | 0 | 消息总线 |
| phy_mac_phystatus | 1 | 0 | PHY 状态 |
| phy_mac_local_tx_coef_valid | 1 | 0 | 本地 TX 系数有效 |
| phy_mac_local_tx_pset_coef | 18 | 0 | 本地 TX Pset 系数 |
| phy_mac_localfs | 6 | 0 | 本地全摆幅 |
| phy_mac_locallf | 6 | 0 | 本地低频 |
| phy_mac_dirfeedback | 6 | 0 | 方向反馈 |
| phy_mac_fomfeedback | 8 | 0 | FOM 反馈 |

> **注**: `phy_rst_n` 与 ResetN 是同一个信号。作为 `mac2phy` 方向的信号放入 `mac2phy_lane_t` struct，走 BBM，safe_level=1（交接窗口保持高即不复位）。shared 信号（PowerDown, Rate, phy_pclk_rate 等）不放入此 CSV。

---

## 3. Python 生成器变更

### 3.1 plm_config.py — CSV 空字符去除

在 `plm_config.py` 中新增 `_strip_dict()` 和 `_stripped()` 两个工具函数，统一在入口处去除 CSV 读取时的空白字符：

```python
def _strip_dict(row):
    """strip 所有 key 和 value，过滤掉值为空的 key。"""
    out = {}
    for k, v in (row or {}).items():
        if k is not None:
            k = k.strip()
        if isinstance(v, str):
            v = v.strip()
        out[k] = v
    return out

def _stripped(reader):
    """包装 DictReader，逐行 strip。"""
    for r in reader:
        yield _strip_dict(r)
```

三个加载函数 `_load_ctrl`、`_load_sig`、`_load_map` 都改用 `_stripped()` 包装 DictReader。`Controller.__init__` 和 `Signal.__init__` 里 `int()` 前加 `.strip()`。`_load_map` 的表头也做 strip。

**影响**: 用户在 CSV 中不小心加了空格（列名、值、甚至不可见字符）不再导致解析失败。

### 3.2 plm_gen.py — 生成器清理与层次拆分

#### 3.2.1 反馈时钟冗余消除

**旧**: 每条 lane 各例化一组 `clk_gate`，28 条 lane 产生 28 个例化。
**新**: 同 group 的 lane 共享一组 `clk_gate`，只例化 7 组（7 个 group 各一组）。

```systemverilog
// 旧: 逐 lane 例化
clk_gate u_pin_gate_g1_b0_l4 (...);
clk_gate u_pin_gate_g1_b0_l5 (...);  // 冗余
clk_gate u_pin_gate_g1_b0_l6 (...);  // 冗余
clk_gate u_pin_gate_g1_b0_l7 (...);  // 冗余

// 新: 同组第一条 lane 用 |pin_gated_gX，其余引用首条
assign phy_pclk_in[4] = |pin_gated_g1;
assign phy_pclk_in[5] = phy_pclk_in[4];  // 引用组内首条
assign phy_pclk_in[6] = phy_pclk_in[4];
assign phy_pclk_in[7] = phy_pclk_in[4];
```

#### 3.2.2 gen_decoder 端口列表清理

- 删除 `if False else` 死分支
- 删除倒序搜索逗号的循环
- 改为直接构建 ports 列表

#### 3.2.3 sel_tgt 冗余 if/else 合并

```python
# 旧: 多行 if/else 选择 sel_tgt 的值
# 新: 合并为一行
```

#### 3.2.4 空循环删除

controller 侧未被驱动的 tie 循环（循环体只有 `continue`）删除。

#### 3.2.5 phy_rst_n 归属演进

`phy_rst_n`（即 ResetN）从独立端口改为 `mac2phy_lane_t` struct 字段。访问方式演进过程：

1. ~~`ctrl_rst_n[NUM_CTRL]` 独立端口~~
2. ~~`phy_rst_n[cid]` 独立端口~~
3. ~~`ctrlX_phy_rst_n` 独立端口~~
4. ~~`ctrlX_mac2phy.phy_rst_n`（无 index）~~
5. **最终**: `ctrlX_mac2phy[0].phy_rst_n`（带 index 写法）

BBM 的 `branch_rst_n` 从各 controller 的 `mac2phy[0].phy_rst_n` 取：

```systemverilog
bbm_sel_onehot #(.N(2)) u_bbm_g1 (
    .branch_rst_n ({ctrl1_mac2phy[0].phy_rst_n, ctrl0_mac2phy[0].phy_rst_n}),
    ...
);
```

---

## 4. 顶层层次拆分

### 4.1 拆分前

```
pipe_lane_mapper_top (383 行，全部平铺)
├── 端口声明
├── pipe_lane_decoder 例化
├── ctrl_pclk 生成 (always_ff + bbm_sel_onehot + clk_gate)
├── group BBM 例化
├── 反馈时钟 mux (clk_gate + assign)
├── MAC->PHY 数据 mux (onehot_mux)
├── PHY->MAC 数据 mux (onehot_mux)
└── sel_tgt 直通信号 (如有)
```

### 4.2 拆分后

```
pipe_lane_mapper_top (103 行，纯例化层)
├── 端口声明 (对外接口不变)
├── lane_sel_t sel, sel_tgt 内部连线
├── pipe_lane_clk_top      u_clk_top   (例化)
├── pipe_lane_data_m2p     u_data_m2p  (例化)
├── pipe_lane_data_p2m     u_data_p2m  (例化)
└── sel_tgt 直通信号 (如有，留在顶层)

pipe_lane_clk_top (121 行)
├── pipe_lane_decoder 例化
├── ctrl_pclk 生成
├── group BBM
└── 反馈时钟 mux

pipe_lane_data_m2p (84 行)
└── per-lane mac2phy onehot_mux

pipe_lane_data_p2m (175 行)
└── per-controller-port phy2mac onehot_mux
```

### 4.3 模块接口

#### pipe_lane_clk_top

```
输入:
  phy_pclk_out [LANE_COUNT-1:0]   PHY 每 lane 输出的 pclk
  test_en                         DFT
  mode [$clog2(NUM_MODES)-1:0]    mode 选择
  ctrlX_mac2phy [max_width-1:0]   各 controller 的 mac2phy (取 phy_rst_n)

输出:
  ctrl_pclk [NUM_CTRL-1:0]        送给各 controller 的 pclk
  phy_pclk_in [LANE_COUNT-1:0]    反馈给 PHY 的 pclk
  sel (lane_sel_t)                 BBM 同步后的使能
  sel_tgt (lane_sel_t)             同步前的目标值 (供顶层 sel_tgt 信号直通)
```

#### pipe_lane_data_m2p

```
输入:
  sel (lane_sel_t)                 BBM 同步后的使能
  ctrlX_mac2phy [max_width-1:0]   各 controller 的 mac2phy 数据

输出:
  phy_mac2phy [LANE_COUNT-1:0]    送给 PHY 的 mac2phy 数据
```

#### pipe_lane_data_p2m

```
输入:
  sel (lane_sel_t)                 BBM 同步后的使能
  phy_phy2mac [LANE_COUNT-1:0]    PHY 输出的 phy2mac 数据

输出:
  ctrlX_phy2mac [max_width-1:0]   各 controller 的 phy2mac 数据
```

### 4.4 顶层端口

顶层对外端口**完全不变**，只是内部从平铺逻辑变成了三个子模块例化。外部使用者无需修改任何连接。

---

## 5. 生成的 RTL 文件

### 5.1 文件清单

| 文件 | 生成函数 | 行数 | 说明 |
|------|----------|------|------|
| `pipe_pkg.sv` | `gen_pkg` | 115 | 类型包: struct/SAFE/lane_sel_t |
| `pipe_lane_decoder.sv` | `gen_decoder` | — | mode 译码 (纯组合) |
| `pipe_lane_clk_top.sv` | `gen_clk_top` | 121 | 时钟子模块 |
| `pipe_lane_data_m2p.sv` | `gen_data_m2p` | 84 | MAC→PHY 数据 mux |
| `pipe_lane_data_p2m.sv` | `gen_data_p2m` | 175 | PHY→MAC 数据 mux |
| `pipe_lane_mapper_top.sv` | `gen_top` | 103 | 顶层 (纯例化) |

### 5.2 filelist (rtl.f)

```
rtl/common/sync2.sv
rtl/common/bbm_sel_onehot.sv
rtl/common/clk_gate.sv
rtl/common/onehot_mux.sv

rtl/gen/pipe_pkg.sv
rtl/gen/pipe_lane_decoder.sv
rtl/gen/pipe_lane_clk_top.sv
rtl/gen/pipe_lane_data_m2p.sv
rtl/gen/pipe_lane_data_p2m.sv
rtl/gen/pipe_lane_mapper_top.sv
```

---

## 6. Lane 分组结果

当前 4-mode 配置下，16 条 lane 按归属序列自动分为 4 组：

| Group | Lane 范围 | Mode0 | Mode1 | Mode2 | Mode3 | 候选 | 类型 |
|-------|-----------|-------|-------|-------|-------|------|------|
| G0 | lane0~3 | Ctrl0 | Ctrl0 | Ctrl0 | Ctrl0 | 1 | 直连 |
| G1 | lane4~7 | Ctrl0 | Ctrl0 | Ctrl0 | Ctrl1 | 2 | 2选1 BBM |
| G2 | lane8~11 | Ctrl0 | Ctrl2 | Ctrl2 | Ctrl2 | 2 | 2选1 BBM |
| G3 | lane12~15 | Ctrl0 | Ctrl2 | Ctrl3 | Ctrl3 | 3 | 3选1 BBM |

Controller pclk 来源 (组内最低编号 lane):

| Controller | 候选 | 类型 |
|------------|------|------|
| Ctrl0 | phy_pclk[0] | 直连 |
| Ctrl1 | phy_pclk[4] | 直连 |
| Ctrl2 | phy_pclk[8] | 直连 |
| Ctrl3 | phy_pclk[12] | 直连 |

---

## 7. 关键设计决策

### 7.1 phy_rst_n 放入 struct 而非独立端口

`phy_rst_n` 作为 shared 信号放在 `mac2phy_lane_t` 里，所有 lane 端口共享同一个值。BBM 的 `branch_rst_n` 从 `ctrlX_mac2phy[0].phy_rst_n` 取。好处：
- 减少顶层端口数量
- phy_rst_n 随数据一起走 BBM，天然同步
- 带宽切换时旧 controller 的 phy_rst_n 被 BBM 安全门控

### 7.2 sel_tgt 从 clk_top 输出

`sel_tgt`（同步前的目标值）从 `pipe_lane_clk_top` 输出给顶层，用于 sel_tgt 直通信号（如 ResetN，不走 BBM）。当前配置无此类信号，但接口已预留。

### 7.3 反馈时钟按 group 共享

同组 lane 共享一组 `clk_gate`，首条 lane 用 `|pin_gated_gX`，其余 `assign phy_pclk_in[N] = phy_pclk_in[g.lanes[0]]`。这大幅减少了 clk_gate 例化数量。

### 7.4 信号命名规范

使用用户原始命名 `mac_phy_*`（MAC→PHY 方向）和 `phy_mac_*`（PHY→MAC 方向），方向前缀天然区分，无需额外改名。方向前缀即 ownership：`mac_phy_*` 表示 MAC 侧驱动给 PHY，`phy_mac_*` 表示 PHY 侧驱动给 MAC。
