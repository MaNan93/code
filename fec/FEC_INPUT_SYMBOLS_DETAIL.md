# FEC Input Symbols 详解

## 概览
LL-FEC（RS(272,257+1)）中的 **FEC input symbols** 是编码器接收的消息符号序列，每个符号 10-bit（GF($2^{10}$)）。

---

## 1. 符号总数与 Pad 机制

| 项目 | 数值 | 说明 |
|------|------|------|
| 转码数据源 | 10×66b PCS block | 来自 PCS 层的 10 个编码块 |
| 转码输出 | 10×257b | 64B/66B → 256B/257B 转码后 |
| 转码总 bit | 2570 bit | 10 × 257 |
| Pad symbol | 1×10 bit | 对齐符号边界与 RS 编码要求 |
| FEC input 总 bit | 2580 bit | 2570 + 10 |
| **FEC input 符号数** | **258** | 2580 / 10（= 257 data + 1 pad） |

---

## 2. 符号编号与位置映射

### 2.1 50GE / 100GE（单路编码）

```
┌─────────────────────────────────────────┐
│  Transcoded Data (10×257b streams)      │
├─────────────────────────────────────────┤
│ m[0:256]      : Data symbols (257个)     │  来自 10×257b 转码数据
├─────────────────────────────────────────┤
│ m[257]        : Pad symbol (1个)        │  10-bit pad，固定值或 PRBS
├─────────────────────────────────────────┤
│ RS encoder   : 输入 = m[0:257]          │  
│              : 输出 = Codeword[0:271]   │  共 272 个符号
│              : 其中 m[0:257] 是消息     │  
│              : 校验 = 输出[258:271]     │  14个校验符号
└─────────────────────────────────────────┘
```

**关键点：**
- Pad symbol 位置：**m[257]（最后）**
- Pad 值：通常由 `free-running PRBS` 或编码器配置产生
- 编码后：消息符号序列保持（可作范围寻址），校验追加

### 2.2 200GE（双路编码）

```
┌──────────────────────────────────────────────────────────┐
│  Transcoded Data (10×257b) + Round-robin 拆分            │
├──────────────────────────────────────────────────────────┤
│  10-bit Round-robin Distribution 将符号交错分到 A/B      │
├──────────────┬──────────────────────────────────────────┤
│  Message A   │  Message B                               │
├──────────────┼──────────────────────────────────────────┤
│ mA[0:128]    │ mB[0:128]  (来自原 m[0:127])偶数索引    │
│              │            (来自原 m[128:255])奇数索引  │
│ mA_pad       │ mB_pad                                    │
├──────────────┼──────────────────────────────────────────┤
│ RS encA      │ RS encB                                   │
│ → cwA        │ → cwB                                     │
│   272 sym    │   272 sym                                 │
└──────────────┴──────────────────────────────────────────┘
```

**关键点：**
- 原始 258 个符号被 10-bit round-robin 拆分为两路，每路 129 个（包含 pad）
- Pad 在两路中各 1 个（总共还是贡献到两个独立 RS 编码过程）
- 双编码并行，降低单编码器时延，提高吞吐

---

## 3. Pad Symbol 详细说明

### 来源与特性

| 特性 | 说明 |
|------|------|
| 何时插入 | AM insertion 阶段之后、RS 编码之前 |
| 物理位置 | 消息符号序列末尾（m[257] in 50/100G；mA[128], mB[128] in 200G） |
| 生成方式 | 由 free-running PBS9 或 LFSR 生成，确保时钟与数据隐藏合规性 |
| 编码处理 | 参与 RS 编码计算（不被特殊处理，与普通消息等同） |
| 接收侧 | 在解码后丢弃（不进入上层 PCS） |

### Pad 值生成伪代码示例

```
LFSR_state = 0x3D9  // 初始化或从配置读入
pad_bit_0 = LFSR xor feedback
pad_bit_1 = ...
...
pad_bit_9 = ...
mA_pad = {pad_bit_0, ..., pad_bit_9}  // 形成 10-bit symbol
```

---

## 4. 各速率数据流详细对应

### 4.1 50GE 单路链路

```
Transcoded Blocks (10×257b)
    ↓
Concatenate → [2570 bits]
    ↓
Insert Pad (10 bits) → [2580 bits = 258 sym]
    ↓
RS(272,257+1) Encoder
    Input:  m[0:257] (258 symbols)
    Output: c[0:271] (272 symbols)
            = m[0:257] + parity[258:271] (14 symbols)
    ↓
10-bit Symbol Distribution
    Send to UNITDATA_0: symbols {c[0], c[2], c[4], ...} (136)
    Send to UNITDATA_1: symbols {c[1], c[3], c[5], ...} (136)
    ↓
PMA lanes
```

### 4.2 100GE 单路链路

```
（结构与 50GE 相同，但 distribution 到 4 个 lane）

Transcoded Blocks (10×257b)
    ↓
RS(272,257+1) Encoder → c[0:271]
    ↓
10-bit Symbol Distribution
    UNITDATA_0: {c[0], c[4], c[8], ...}  (68)
    UNITDATA_1: {c[1], c[5], c[9], ...}  (68)
    UNITDATA_2: {c[2], c[6], c[10], ...} (68)
    UNITDATA_3: {c[3], c[7], c[11], ...} (68)
    ↓
4×PMA lanes
```

### 4.3 200GE 双路链路

```
Transcoded Blocks (10×257b)
    ↓
10-bit Round-robin Distribution
    mA[0:128] + mA_pad → 129 symbols for encoder A
    mB[0:128] + mB_pad → 129 symbols for encoder B
    ↓
RS(272,257+1) Encoder A → cwA[0:271]
RS(272,257+1) Encoder B → cwB[0:271]
    ↓
Mux + 10-bit Symbol Distribution
    UNITDATA_0: {cwA[0], cwB[0], cwA[1], cwB[1], ...}
    UNITDATA_1: {cwA[4], cwB[4], cwA[5], cwB[5], ...}
    ...（总共 8 路）
    ↓
8×PMA lanes
```

---

## 5. RTL 信号命名建议

### 编码器输入信号

```verilog
// 50/100G 单路
input  [9:0]   fec_input_message_symbol;  // m[i]，i=0..257
input          fec_input_valid;           // m[i] 有效标志
input          fec_input_is_pad;          // 标志当前是 pad symbol

// 200G 双路
input  [9:0]   fec_input_messageA_symbol; // mA[i]
input  [9:0]   fec_input_messageB_symbol; // mB[i]
input          fec_input_A_valid;
input          fec_input_B_valid;
input          fec_input_A_is_pad;
input          fec_input_B_is_pad;
```

### 编码器输出信号

```verilog
// Codeword（包含消息 + 校验）
output [9:0]   fec_output_symbol;         // c[j]，j=0..271
output [11:0]  fec_output_symbol_index;   // 调试用：哪个符号
output         fec_output_valid;
```

---

## 6. Pad 在接收侧的处理

```
Received Codeword c[0:271]
    ↓
RS Decoder
    Syndrome calc → error location
    Fix errors in m[0:257]
    Discard parity & index 257（pad） output
    ↓
m_decoded[0:256] → 257 symbols (valid data)
    ↓
去 Pad + AM/扰码逆 → 66B decode
    ↓
上层 PCS
```

---

## 7. 快速查表

### Q: 50GE 中 pad symbol 的编号是什么？
**A:** m[257]，是第 258 个（0-indexed）FEC 输入符号，在转码数据末尾插入。

### Q: 200GE 中 mA 和 mB 各有多少个符号？
**A:** 各 129 个（128 data + 1 pad）。

### Q: Pad 会不会被输出到 lane？
**A:** 会。Pad 是消息的一部分，通过 RS 编码器处理，最终通过分发器映射到各 lane；接收侧在解码后舍弃。

### Q: RS 编码器的总输出符号数在 3 种速率下一样吗？
**A:** 是。都是 272 个（= 258 input + 14 parity），但 200G 中有两个编码器并行工作。

---

## 8. 参考规范位置

- **第 3.2 节**：10-bit Pad Symbol 生成方式与时序
- **第 3.3 节**：Symbol Distribution 规则（按速率）
- **图 1/2/3**：各速率数据流图示，标注符号分发到各 lane 的顺序

