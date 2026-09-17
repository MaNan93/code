# DWC_pcie XALI / TRGT1 应用侧 BFM

针对 Synopsys DesignWare `DWC_pcie` 控制器 **native（非 AXI Bridge）应用接口** 的
SystemVerilog BFM：发送侧 XALI0/1/2，接收侧 TRGT1。

## 先说两个前提

1. **文档版本**：`dwc_spec/6.40a/` 目录里的 PDF 实际是 **Version 6.60a（July 2026）**，
   不是 6.40a。XALI/TRGT1 的协议规则两版一致，但请以你自己 coreConsultant 生成的 RTL
   端口为准。
2. **信号位宽/`tlp_type` 编码**：这些在 *Reference Manual* 的 “Signal Descriptions”
   章节，该目录里没有这本手册。因此本 BFM 里：
   - 位宽全部参数化，集中在 `src/dwc_pcie_bfm_defines.svh`；
   - `dwc_tlp_type_e` 的**名字**取自 Databook（MEM/MSG/MSGD/CPL…），**数值是占位的**，
     接真实 RTL 前必须按 Reference Manual 改掉。代码其余部分与编码无关。

---

## 一、时序规则（Databook 6.60a §4.1 / §4.6 / 附录 U）

### 1.1 XALI（发送客户端，app → controller）

握手只有一条规则：

```
某个周期被 XADM 接收  <=>  该周期 xadm_clienti_halt == 0
```

`xadm_clienti_halt` 是 **level 型反压**，不是 AXI 的 ready 取反语义上的“对称”握手：
空闲时控制器默认保持 `halt = 1`（§4.1.1），应用先把 `hv` 和头信号摆上去等控制器拉低 halt。

| 规则 | 说明 |
|---|---|
| 无气泡 | TLP 一旦开始（`hv`），必须连续送数据直到 `eot`；只有 halt 能插入等待 |
| 无 payload | `dv` **绝不能**拉高，`eot` 与 `hv` 同拍（MRd/Msg，Fig 4-1） |
| 有 payload | 首拍 `hv` 与 `dv` **必须同拍**；后续拍只有 `dv`（Fig 4-3） |
| `eot` | 只能在最后一拍 `dv` 上；无 payload 时在 `hv` 上 |
| halt 期间 | 头总线、数据总线、控制位**全部保持不变** |
| `bad_eot` | 只能与 `eot` 同拍，用于中途 abort |
| 背靠背 | `hv`/`eot` 可以跨 TLP 连续拉高，中间不留空拍 |

**地址对齐（§4.1.3）** —— 由 `clienti_addr_align_en` 逐包控制：

| | `addr_align_en = 0` | `addr_align_en = 1` |
|---|---|---|
| `tlp_addr` | 必须 DWORD 对齐（`[1:0]==0`） | 完整字节地址 |
| `tlp_byte_en` | 应用自己算 FBE/LBE，可非连续 | 置 0，不使用 |
| `tlp_byte_len` | 向上取整到 DWORD | 真实字节长度 |
| `tlp_data` | 应用负责按字节地址上移 | 首个有效字节放在 `data[7:0]` |

两个禁区：
- **Completion 必须 `addr_align_en = 0`**；
- **带 ECRC（TD=1）必须 `addr_align_en = 0`**（§4.1.3.4，控制器不知道低位字节值，
  ECRC 无法保证）。

Databook Fig 4-5 的四个 3 字节写（0x80000000..03）对应 `byte_en` = 0x07/0x0e/0x1c/0x38，
`byte_len` = 4/4/8/8 —— 这组向量已经写进单元测试当回归用了。

**Target Completion LUT（§4.1.4）**：`TRGT_CPL_LUT_EN=1` 时，应用只要存下入向请求带的
`trgt_lookup_id`，回 Completion 时放到 `clienti_cpl_lookup_id` 上，就不用再提供
`remote_req_id` / `cpl_byte_cnt` / `tlp_attr` / `tlp_addr` / `tlp_tid` / `tlp_tc`。
LUT 表项用完时 RADM 会自动 halt TRGT1。

### 1.2 TRGT1（接收请求，controller → app）

**这是最容易踩的地方**：`trgt1_radm_halt` **不是 ready**。

> §4.6.1 + Fig 4-14 下方的 Note：store-and-forward 模式下，应用拉高 halt 之后，
> `radm_trgt1_dv` 还会再持续若干拍（取决于流水线深度）才真正拉低。

也就是说：

```
应用必须在每一个 dv == 1 的周期吃掉一拍数据，不管 halt 是不是已经拉高；
应用 buffer 必须能吸收 halt 之后的那段“尾巴”。
```

等 `dv` 真正停下来之后，控制器才把总线冻结在原值。BFM 里 `dwc_trgt1_receiver`
就是这么写的，并且用 `max_inflight_after_halt` 统计尾巴实际有多深，方便你定 FIFO 深度。

其余规则：

- 所有头信号在 `radm_trgt1_hv` 那一拍有效（`trgt_lookup_id` 也是）；
- cut-through 模式下 `dv` **中途可能出现空洞**（Fig 4-12），应用必须能吸收；
- `tlp_abort` / `dllp_abort` / `ecrc_err` 与 `eot` 同拍；credit 返还策略见 Table 3-43：
  `tlp_abort` **要**还 credit，`dllp_abort` 可以不还；
- `radm_trgt1_dwen` 在 `dllp_abort` 的 eot 拍上**不可信**（附录 L 的 Attention），
  要整包丢弃。

### 1.3 Packet Grant / Halt（§4.6.3，死锁规避）

`trgt1_radm_halt` 是**全局**停止。一旦某个应用吃不下的 NP TLP 进了 output pipe，
它会挡住后面所有包（包括 Posted），可能死锁。正确做法是用
`trgt1_radm_pkt_halt[2:0]` 在**接收队列里**就按类型拦住：

- `radm_grant_tlp_type[2:0]`：**时钟脉冲**输出，表示该类型出队一个包，进入 3~4 拍的 output pipe；
- `trgt1_radm_pkt_halt[2:0]`：**电平**输入，而且必须**组合逻辑**驱动 ——
  因为 grant 是寄存器输出，晚一拍拦就已经多放出来了；
- `pkt_halt` 拉低到下一次 grant 至少间隔 1 拍（Fig 4-16）。

`src/dwc_trgt1_pkt_halt_tracker.sv` 就是 Databook 让你自己搭的那个 “Non-Posted TLP
Tracker”，可综合，counter = grant 加 / hv 减，`pkt_halt` 组合输出。

### 1.4 MultiStream / Gen6（附录 U）

- XALI 变成每 `<VC, FC>` 一条独立接口（`client_vc0_p0_*` / `np0` / `cpl0`），最少 3 条；
  TRGT1 同理（`radm_trgt1_p_0_*` 等），**没有单独的 RBYP**，Completion 走专用 TRGT1。
- 串行点从 client 接口下移到 XTLH ⇒ **XALI 上的接受顺序不再等于上线顺序**。
  需要保序时用 `xali_posted_tlp_sent` 脉冲，同 FC 两条并行接口之间用
  `tlp_order_seqnum`（3 bit 回绕计数，小的优先）。
- MultiStream 下不支持 Application Credit Control / Client Pullback / Global Address Alignment。
- halt 端口名变成 `trgt1_radm_intf_<fc>_0_halt`，Packet Grant/Halt 机制不再适用。

---

## 二、代码结构

```
src/
  dwc_pcie_bfm_defines.svh        编译期参数（DW / LUT_ID_W / PRFX_W ...）
  dwc_pcie_cfg_pkg.sv             常量、tlp_type 枚举、FC 映射、header 结构体
  dwc_pcie_core_pkg.sv            与接口无关的一半（可单独编译/单测）
    dwc_tlp_item.svh              TLP 事务对象 + 4.1.3 对齐打包/BE 计算
    dwc_bfm_util.svh              数据总线 <-> 字节流 的拆装
  dwc_pcie_xali_if.sv             XALI 接口 + 内嵌 SVA 检查器（R1~R10）
  dwc_pcie_trgt1_if.sv            TRGT1 接口 + 内嵌 SVA 检查器
  dwc_pcie_bfm_pkg.sv             需要 virtual interface 的一半
    dwc_xali_driver.svh           发送驱动（beat pump，严格遵守 halt 保持）
    dwc_xali_monitor.svh          被动重建发出的 TLP
    dwc_trgt1_receiver.svh        接收 + halt 反压（dv 即收，不看 halt）
    dwc_app_completer.svh         target completer，走 Completion LUT 自动回 Cpl
  dwc_trgt1_pkt_halt_tracker.sv   NP Tracker（可综合）
tb/
  dwc_pcie_ctrl_stub_pkg.sv       控制器侧 stub（含 halt 流水线延迟模型）
  tb_dwc_pcie_bfm.sv              自检 TB：发送回环 + 入向请求自动补完
  tb_dwc_align_unit.sv            地址对齐往返单测（纯 class，无时钟）
```

设计上**不依赖 UVM**。要接 UVM 的话，把 `dwc_xali_driver` / `dwc_trgt1_receiver`
包一层 `uvm_driver` / `uvm_monitor`，把 `req_mb` 换成 seq_item_port 即可；
`dwc_tlp_item` 加上 `uvm_object_utils` 就能直接当 sequence item。

---

## 三、跑起来

### 本机可跑的部分（Verilator 5.050）

```bash
wsl make -C /mnt/c/Users/1/Desktop/pcie_spec/dwc_bfm unit
```

地址对齐往返单测，已在 DW = 64/128/256/512/1024 全部通过：

| DW | checks | failures |
|---|---|---|
| 64 | 244 | 0 |
| 128 | 372 | 0 |
| 256 | 628 | 0 |
| 512 | 1140 | 0 |
| 1024 | 2164 | 0 |

NP Tracker 的 `-Wall` lint：

```bash
wsl make -C /mnt/c/Users/1/Desktop/pcie_spec/dwc_bfm lint
```

### 完整 TB（需要商业仿真器）

Verilator 5.050 **不支持 clocking block**（也不支持 `mailbox #(T)` 和
virtual interface 的完整语义），所以 `tb_dwc_pcie_bfm.sv` 跑不了，需要 VCS/Xcelium/Questa：

```bash
make vcs      # 或 make xrun
```

这个 TB 做两件事：
1. 应用侧随机发 40 个 TLP（随机对齐模式 + 随机长度），XADM stub 随机 halt，
   passive monitor 必须逐字节重建出一模一样的 TLP；
2. RADM stub 注入 24 个入向 MWr/MRd（带 halt 流水线延迟 + cut-through 空洞），
   receiver 必须吸收 halt 之后的尾巴，completer 必须通过 Completion LUT 把每个 NP 请求补完。

---

## 四、接真实 RTL 时要改的地方

1. `dwc_pcie_bfm_defines.svh` 里的 `DWC_BFM_DW` / `DWC_BFM_LUT_ID_W` / `DWC_BFM_PRFX_W`
   对齐 coreConsultant 配置（`LUT_ID_W = $clog2(CX_REMOTE_MAX_TAG)`）。
2. `dwc_pcie_cfg_pkg.sv` 里 `dwc_tlp_type_e` 的数值按 Reference Manual 改。
3. 接口里的信号名按实际端口接：legacy 是 `client0_tlp_hv` / `xadm_client0_halt` /
   `radm_trgt1_hv` / `trgt1_radm_halt`；MultiStream 是 `client_vc0_p0_*` /
   `radm_trgt1_p_0_*` / `trgt1_radm_intf_p_0_halt`。
4. 用不到的信号（Flit mode 的 segment、`order_seqnum`、`prfx` 等）在 DUT 端接 0 即可，
   BFM 里留着不影响。
5. `dwc_trgt1_pkt_halt_tracker` 的 `MARGIN` 至少要 ≥ output pipe 深度（Databook 说 3~4 拍）。
