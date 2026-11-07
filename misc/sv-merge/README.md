# sv-merge: 依赖感知的 SystemVerilog / Verilog 文件列表合并工具

`sv-merge` 是一款专为数字 IC / FPGA 工程师设计的轻量级、零依赖命令行工具。它的唯一输入就是 EDA 工程师最熟悉的文件列表（`-f` / `-F`），通过 **DAG 拓扑排序** 与 **Include 智能哑化**，一键生成 **“100% 源码保真、完全自包含、编译 0 报错”** 的单文件 SystemVerilog 代码。

---

## 一、 为什么需要 sv-merge？（背景与痛点）

在大型商业 IP（如 Synopsys PCIe/AMBA/USB）或复杂 SoC 工程中，代码往往分散在数百上千个文件中。当工程师出于以下需求尝试将工程合并为一个文件时：
- 使用 **Verdi / Vivado / Quartus / DC** 快速打开原理图、浏览层级或追查信号；
- 交付给外部或兄弟团队做代码审查；
- 进行单文件快速 Lint 检查或形式验证；

直接使用操作系统的 `cat *.v > all.v` 必然引发海量编译报错，主要原因包括：

1. **依赖倒置与 1-Pass 局限**：原工程的 filelist（`.f` / `.lst`）往往存在包乱序（如先编译的使用模块排在前面，被 `import` 的 `package` 却排在后面）。多文件编译模式可以靠多次扫描解析，但在单文件中，编译器是从上往下严格单 pass 解析的，顺序颠倒立刻报错 `Package not found`。
2. **预处理器的磁盘路径硬绑定**：源码中存在数千处 `` `include "xxx.svh" ``。只要这些语句留在合并后的文本中，预处理器就会强制访问物理硬盘。脱离了原工程目录或没有指定 `+incdir+`，立即报错 `cannot be read`。
3. **编译器状态污染**：个别模块末尾遗漏恢复默认网表类型，其 `` `default_nettype none `` 会穿透污染后续所有合并文件，导致隐式 wire 全面报错。

`sv-merge` 就是为了从根本上彻底解决上述所有问题而生。

---

## 二、 核心设计思路与架构

`sv-merge` 采用清晰的五阶段流水线处理流程：

```
                    ┌─────────────────────────┐
                    │  1. 递归展开 Filelist   │ (-f / -F / 环境变量 / 过滤编译选项)
                    └────────────┬────────────┘
                                 │ (有序原始文件列表)
                                 ▼
                    ┌─────────────────────────┐
                    │   2. 语法与依赖扫描     │ (提取 Package, Import, Interface, Header)
                    └────────────┬────────────┘
                                 │
                                 ▼
                    ┌─────────────────────────┐
                    │   3. DAG 拓扑排序       │ (Kahn 算法排定严格依赖层次)
                    └────────────┬────────────┘
                                 │ (排序后的文件流)
                                 ▼
                    ┌─────────────────────────┐
                    │  4. Include 精准哑化    │ (已内嵌头文件转换为注释，切断磁盘依赖)
                    └────────────┬────────────┘
                                 │
                                 ▼
                    ┌─────────────────────────┐
                    │  5. 注入防污染安全守卫  │ (`default_nettype wire 隔离)
                    └─────────────────────────┘
```

### 1. 递归展开 Filelist
- 原生支持递归嵌套的 `-f`（相对于执行目录）和 `-F`（相对于当前 flist 所在目录）；
- 自动解析系统环境变量（`$PROJ_ROOT`、`${DESIGN_DIR}`）；
- 自动剔除 EDA 专用的编译参数（如 `-sverilog`、`-2012`、`+libext+`、`-y` 等），精准提纯出源文件物理路径。

### 2. 精准文件分类
- **纯头文件（Pure Headers）**：定义常量、宏、类型，但不包含 `module`、`interface` 且不 `import` 任何 package 的 `.vh` / `.svh` 文件；
- **包文件（Package Files）**：包含 `package <name>;` 声明的文件；
- **接口与模块文件（Interfaces & Modules）**：包含具体的硬件描述与逻辑实现；
- **清理文件（Undef Files）**：专门在最后清理全局宏定义的辅助文件（如 `*-undef.v`）。

### 3. DAG 有向无环图拓扑排序
- 扫描所有 Package 声明与 `import pkg::*` 依赖关系，构建有向图；
- 采用 **Kahn 算法** 计算入度并完成分层排序：
  $$\text{全局常量与宏} \longrightarrow \text{零依赖基础包} \longrightarrow \text{一级依赖包} \longrightarrow \text{深层高级包} \longrightarrow \text{接口与模块} \longrightarrow \text{顶层 Top} \longrightarrow \text{宏清理}$$
- 确保任何符号在使用之前，其定义已严格就绪。

### 4. Include 指令精准“哑化”（Neutralization）
- 建立全量已内嵌文件的白名单索引（包含相对路径与纯文件名）；
- 逐行扫描源码中的 `` `include "xxx" ``：
  - 若目标文件**已经在上方合并内嵌**，则转换为 `// [Merged] `include "xxx"`；
  - 若属于未被收录的外部宏库，则完整保留原指令。
- **收益**：合并后的单文件完全自包含，在任何没有原工程目录的新机器上无需 `+incdir+` 即可瞬间秒开。

### 5. 编译器状态安全守卫（Guard）
- 在每个文件拼接边界处垫入换行及 `` `default_nettype wire ``，彻底杜绝局部 `default_nettype none` 对后续模块的越界污染。

---

## 三、 安装与使用

`sv-merge` 仅依赖 **Python 3.6+ 标准库**，零第三方 pip 依赖，开箱即用。

### 1. 安装配置

#### 方式 A：使用 uv 管理（推荐）
如果你在当前或目标设备上使用现代包管理器 **`uv`**：
```bash
# 1. 极速构建 Wheel 包（生成在 dist/ 目录下）
uv build

# 2. 安装为独立全局 CLI 工具（自动隔离环境）
uv tool install .
# 或者在其他设备上直接安装构建好的 whl
uv tool install sv_merge-1.0.0-py3-none-any.whl

# 3. 若只需在当前 Python 环境/虚拟环境中安装
uv pip install sv_merge-1.0.0-py3-none-any.whl
```

#### 方式 B：使用 pip 离线安装
只需拷贝生成的 `.whl` 文件至目标机器并执行：
```bash
pip install sv_merge-1.0.0-py3-none-any.whl
# 或者用户级免 root 安装
pip install --user sv_merge-1.0.0-py3-none-any.whl
```

#### 方式 C：免安装直接执行
项目内保留了开箱即用的启动器，直接软链接即可：
```bash
chmod +x sv-merge
ln -sf $(pwd)/sv-merge ~/.local/bin/sv-merge
```

验证安装：
```bash
sv-merge --version
# 输出：sv-merge 1.0.0
```

### 2. 命令行参数

```text
用法: sv-merge [-h] [-f FILELISTS] [-F FILELISTS_F] -o OUTPUT [--top TOP]
                [-I INCDIRS] [--no-guard] [--no-neutralize-includes]
                [--dry-run] [-v] [--version] [files ...]

参数说明:
  -f, --filelist <file>     常规文件列表路径（支持多次指定，可嵌套）
  -F <file>                 以文件列表自身所在目录为相对基准的 flist
  -o, --output <file>       [必须] 合并生成的目标 SystemVerilog 单文件路径
  --top <name>              顶层模块名或文件名（自动将其排在模块末尾、清理文件之前）
  -I, --incdir <dir>        指定额外的头文件查找目录
  --no-guard                禁用文件间的 `default_nettype wire 隔离
  --no-neutralize-includes  禁用 include 自动哑化（保留原始 `include）
  --dry-run                 仅执行分析并打印排序结果，不实际写出大文件
  -v, --verbose             打印详细执行过程、依赖拓扑与统计数据
```

---

## 四、 典型使用场景示例

### 场景 1：基础合并
```bash
sv-merge -f run.flist -o my_design_all_in_one.sv
```

### 场景 2：基于子目录 flist 展开（推荐）
若 flist 文件存放在子目录 `src/` 下，且内部使用的是相对于 `src/` 的路径：
```bash
sv-merge -F src/DWC_pcie_ctl.lst -o DWC_pcie_ctl_all_in_one.sv -v
```

### 场景 3：预演与检查依赖顺序（Dry-run）
只查看识别出的包数量和拓扑排序结果，不生成文件：
```bash
sv-merge -F src/DWC_pcie_ctl.lst --dry-run
```

### 场景 4：生成单文件后在 Verdi 中秒开
```bash
# 生成自包含单文件
sv-merge -F src/DWC_pcie_ctl.lst -o DWC_pcie_ctl_all_in_one.sv

# 在 Verdi 中打开（由于使用了 ANSI localparam 端口，带上 -2012 标准即可）
verdi -2012 -sv DWC_pcie_ctl_all_in_one.sv &
```

---

## 五、 实测验证基准（Synopsys DWC PCIe）

在包含 **945 个源文件、30MB 源码、33 个 SystemVerilog Package** 的真实 PCIe 控制器工业级工程中进行实测：

* **执行耗时**：**1.1 秒**（包含完整文件展开、33 个包的依赖建图与 78 万行代码重构写入）；
* **Include 哑化处理**：自动精准哑化 **2,413 处** 内部头文件引用；
* **EDA 编译器验证**：
  ```bash
  vericom -2012 -sverilog DWC_pcie_ctl_all_in_one.sv
  ```
  **编译结果：`Linking... 0 error(s), 0 warning(s)`，全工程 `Total 0 error(s)`**，与原始 945 个文件独立编译时的结果完全一致。
