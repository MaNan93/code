# Obfuscator 标签页 -- 加扰工具流程

记录 Obfuscator 标签页各字段的作用、执行顺序，以及 token 白名单功能背后
的设计依据。这些依据先来自对 `verible-verilog-obfuscate`
（chipsalliance/verible）源码/文档的查证，后来又用本地下载的
`verible-v0.0-4296-g0f262651-win64` 实际跑通验证过，不是猜的；具体来源
见文末。

## 一次完整流程

1. **源文件 / 输出文件**：待混淆的 `.sv` 文件，以及混淆结果写到哪。
2. **Map 文件 (load_map / save_map)**：
   - `save_map`：本次运行把"原名 → 混淆名"的映射表写到这个文件。
   - `load_map`：预加载一份已有的映射表，里面已经登记的名字会按表里的
     映射走，不会重新随机生成——这是让同一个 IP 多次发版时标识符保持
     稳定（不必每次都变）的机制。
   - 默认：`obf_out`/`save_map` 跟着源文件路径自动带出
     （`<name>_obf.sv` / `restore.map`），方便连续多次混淆时自然形成
     "上一次的 save_map = 这一次的 load_map" 的链条。
3. **Token 白名单 + 首次混淆 (first_obf)**：见下一节。
4. **混淆器路径**：`obf_tool_edit`，只读，通过 File → preference 修改。

fizz 不会给 `--preserve_interface` / `--preserve_builtin_functions` 传任
何显式值，完全交给 verible 自己的默认：`preserve_builtin_functions`
默认 `true`（内置函数名如 `sin`/`ceil` 自动保留），`preserve_interface`
默认 `false`——**module 名、port 名、parameter 名默认会被混淆**。之前
版本 fizz 曾经把 `preserve_interface` 硬编码成默认开启，后来改掉了：
接口名要不要保留，改用 token 白名单显式列出，不再由 fizz 替用户做主。
用实际二进制验证过（见下）：不加白名单时 `pcie_ctrl_wrapper` 这种顶层
module 名和 `link_up` 这种 port 名都被换成了随机名。

## 白名单是全局的，不是按项目的

`whitelist_file` 默认固定指向 `~/.fizz_whitelist.map`（`core.DEFAULT_WHITELIST_FILE`），
跟 `~/.fizz.ini` 放在一起，不会因为换了源文件/换了项目而变。同一个信号
名（比如 `pcie_clk`）只需要在这一份文件里登记一次，不管拿哪个项目跑
obfuscate 都生效。`FizzConfig.load()` 里空字符串也会回退到这个默认路
径（不只是 key 缺失时），所以升级前的旧配置文件也会自动接上这个全局
默认，不需要用户手动改一次。想按项目单独维护也可以——在 Obfuscator 标
签页把白名单路径改成别的文件即可，只是不再是默认行为。

## Token 白名单是怎么做到的

verible 的 map 文件格式很简单（`verible/common/strings/obfuscator.h/.cc`）：
一行一条，`原名 混淆名`，单个空格分隔。一条"原名和混淆名写成同一个词"
的记录，就是一条恒等映射——这正是 `--preserve_interface` /
`--preserve_builtin_functions` 内部保留名字的实现方式。既然如此，**白
名单本身就可以直接是一份恒等映射的 map 文件**，不需要 fizz 自己再包一
层文本替换逻辑：

- `fizz.core.write_whitelist_tokens(path, tokens)`：把用户在"编辑"弹窗
  里输入的每行一个 token，写成 `token token` 格式，直接落盘为一份合法
  的 verible map 文件。
- 勾选"首次混淆"时，这次运行的 `--load_map` 就直接指向这份白名单文件
  （而不是 `obf_load_map_edit` 里的普通链式 map）。
- verible 官方文档说明：显式写在 map 文件里的映射，优先级高于
  `--preserve_*` 开关——所以白名单里的 token 一定会被保留，不受其它开
  关影响。
- 因为 `--save_map` 会把它加载进来的映射（含白名单的恒等映射）连同新
  生成的映射一起写出，所以**白名单只需要在"第一次"混淆时显式加载一
  次**。运行成功后 fizz 会自动把这次的 `save_map` 路径填回
  `load_map` 输入框，并取消勾选"首次混淆"——后续混淆正常走
  save_map/load_map 链条，白名单条目已经在链条里，无需再单独加载。

## 用本地二进制验证过的例子

用 `verible-v0.0-4296-g0f262651-win64` 实测（白名单 = `pcie_clk`,
`pcie_rst_n`）：

```
module pcie_ctrl_wrapper (...)          →  module WzQNOwsfD1qWYWTGD (...)
    input  wire pcie_clk,               →      input  wire pcie_clk,        (白名单，未变)
    input  wire pcie_rst_n,             →      input  wire pcie_rst_n,      (白名单，未变)
    output wire link_up                 →      output wire h3kIEXU          (未加白名单，被混淆)
```

第二次混淆（源码改了一点，`load_map` 换成第一次的 `save_map`，不再直接
传白名单文件）：`pcie_clk`/`pcie_rst_n` 依然原样，`top`/`sig_a` 等第一
次已经生成的映射也保持不变，只有新出现的标识符被随机分配——白名单和历
史映射都"继承"下来了，跟设计的一致。

## --preserve_interface 是整个文件级别的，不能按 module 区分

同样用真实二进制测过：一个文件里有 `top_module` 例化 `sub_module`，开
`--preserve_interface=true` 后，**两个 module 的名字/port 名全部保
留**——这个开关不认"谁是顶层"，只要是文件里的 module 声明就都保留，粒
度到不了单个 module。

如果只想保留其中一个 module 的接口（比如只保留 `top_module`，让
`sub_module` 正常被混淆），`--preserve_interface` 做不到，得完全不用
这个开关，把想保留的那个 module 的名字和它的 port/parameter 名一个个
写进 Token 白名单——白名单是按 token 精确匹配的，天然支持"只保留这几
个"。测过：白名单只写 `top_module`/`top_clk`/`top_out`，`sub_module`
整个接口（模块名+两个 port）照样被混淆，符合预期。

## 参考来源

- <https://github.com/chipsalliance/verible/tree/master/verible/verilog/tools/obfuscator>
  （`--load_map`/`--save_map`/`--preserve_interface`/
  `--preserve_builtin_functions` 参数说明）
- <https://github.com/chipsalliance/verible/blob/master/verible/common/strings/obfuscator.h>
  （load()/save() 的 map 文件格式：一行一条，空格分隔的一对标识符）
- 本地 `verible-verilog-obfuscate.exe --helpfull`（`verible-v0.0-4296-g0f262651-win64`）：
  确认了上面两份文档的说法和实际二进制一致。

## 相关代码

- [`src/fizz/core.py`](../src/fizz/core.py)：
  `run_obfuscate`、`read_whitelist_tokens`、`write_whitelist_tokens`、
  `DEFAULT_WHITELIST_FILE`（`~/.fizz_whitelist.map`）、
  `FizzConfig`（`whitelist_file` 持久化设置，空值/缺失都回退到全局默认路径）。
- [`src/fizz/frontend/qt/main_window.py`](../src/fizz/frontend/qt/main_window.py)：
  Obfuscator 标签页 UI、`_run_obfuscate`/`_on_obf_done` 里的 first_obf
  自动切换逻辑。
- [`src/fizz/frontend/qt/widgets/whitelist_dialog.py`](../src/fizz/frontend/qt/widgets/whitelist_dialog.py)：
  白名单编辑弹窗。
