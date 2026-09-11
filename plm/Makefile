# 对 test/ 下每一套配置集重新跑 `python -m plm.cli.main generate rtl/tb`。
# 前提：先在仓库根目录跑一次 `pip install -e .`（一次性），把 plm 包装成
# 可 import 的形式——不然这里的每条命令都会因为 import 失败而报错。
#
# 用途：
#   - CSV 或生成器脚本改完之后，一键把所有配置集的生成物刷新到最新，
#     避免出现"改了脚本/CSV，但某套配置忘了重新生成"的漂移（demo 就在这上面
#     栽过一次：加了 tie_off 列之后没同步更新，直接跑就报错）。
#   - 配合 CI：生成后 `git status --porcelain` 应该为空，否则说明有配置集
#     的生成物没跟脚本/CSV 保持同步。
#
# RTL 和 testbench 由两个独立的 Python 工具生成，可以分别单独重新生成
# （make rtl-<SET> / make tb-<SET>），也可以像以前一样一次性生成一整套
# （make <SET>）。两边的 --pclk-mode 必须一致——testbench 按这个 flag
# 决定怎么实例化 DUT，不一致会导致 testbench 编不过、或者跟一份过期的
# rtl/ 对不上。
#
# 用法：
#   make              # 等价于 make all：生成所有配置集的 RTL + testbench，某一个失败就停
#   make -k           # 同上，但失败了继续跑完其余的（make 内置的 --keep-going）
#   make demo         # 只生成 demo 这一套（RTL + testbench）
#   make rtl-demo     # 只重新生成 demo 的 RTL
#   make tb-demo      # 只重新生成 demo 的 testbench
#   make list         # 列出 test/ 下识别到的配置集名字
#   make clean        # 删掉所有配置集的生成物（rtl/、tb/tb_pipe_lane_mapper.sv）
#   make clean-demo   # 只删掉 demo 这一套的生成物
#   make help         # 打印这份用法（含当前识别到的配置集名字）
#
# 透传额外参数（全局，适用于每一次 make 调用，跨所有配置集）：
#   GENFLAGS      两个工具都会收到，比如切时钟架构：
#                   make all GENFLAGS="--pclk-mode pclk_as_phy_input"
#   RTL_GENFLAGS  只传给 generate rtl，比如切到组合直通的 sel_sync：
#                   make all RTL_GENFLAGS="--sel-mode comb"
#   TB_GENFLAGS   只传给 generate tb
#
# 某个配置集本身就是为了演示某个非默认 flag 存在的（比如 maxpclk 演示
# --pclk-mode pclk_as_phy_input），这种 flag 不在这里配置——写在那套配置集
# 自己的 test/<SET>/config/gen_flags.txt 里（跟三个 CSV 放一起，两个
# Python 工具都会读，各自只认自己认识的 key），这样配置集本身就是自包含的，
# 不需要为了给它固定一个 flag 而回来改这个 Makefile。上面的 GENFLAGS 系列
# 变量地位更高，可以临时覆盖任何配置集自带的 gen_flags.txt。

PYTHON       ?= python3
GENFLAGS     ?=
RTL_GENFLAGS ?=
TB_GENFLAGS  ?=

# 自动发现 test/ 下的配置集：凡是 test/<name>/config/controllers.csv
# 存在的 <name> 都算一个集，不用每加一套配置就手改 Makefile。
CONFIG_MARKERS := $(wildcard test/*/config/controllers.csv)
CONFIGS        := $(patsubst test/%/config/controllers.csv,%,$(CONFIG_MARKERS))

.PHONY: all help list clean $(CONFIGS) FORCE

all: $(CONFIGS)

## Note: these @echo lines are deliberately English-only. This
## repo's make.exe (conda-forge GNU Make on Windows) mangles non-ASCII
## text piped through its shell -- confirmed with a minimal isolated
## repro (a one-line makefile with `@echo "<Chinese>"` alone), so it's
## the toolchain, not this file. See docs/tool_usage.md and this
## file's own (Chinese) comments for the full write-up.
help:
	@echo "Usage:"
	@echo "  make               same as make all: generate RTL + testbench for every config set"
	@echo "  make -k            same, but keep going past a failed config set"
	@echo "  make <SET>         generate RTL + testbench for one config set, e.g. make quad"
	@echo "  make rtl-<SET>     regenerate only that config set's RTL"
	@echo "  make tb-<SET>      regenerate only that config set's testbench"
	@echo "  make list          list the config sets found under test/"
	@echo "  make clean         delete every config set's generated output"
	@echo "  make clean-<SET>   delete one config set's generated output"
	@echo "  make help          print this"
	@echo ""
	@echo "Config sets found: $(CONFIGS)"
	@echo ""
	@echo "Pass-through vars (apply to every config set in this invocation, override"
	@echo "any config set's own gen_flags.txt):"
	@echo "  GENFLAGS      goes to both tools, e.g. make all GENFLAGS=\"--pclk-mode pclk_as_phy_input\""
	@echo "  RTL_GENFLAGS  only to generate rtl"
	@echo "  TB_GENFLAGS   only to generate tb"
	@echo ""
	@echo "A config set's own fixed flags go in test/<SET>/config/gen_flags.txt --"
	@echo "both tools read it automatically, no need to pass it on the command line."
	@echo ""
	@echo "See this file's own header comments and docs/tool_usage.md for more."

# 每套配置集：RTL 和 testbench 都刷新。
$(CONFIGS): %: rtl-% tb-%

# rtl-%/tb-% 是模式规则，光把展开后的名字塞进 .PHONY 并不能让 make 每次都
# 重新跑（GNU make 对模式规则生成的目标不会那样处理），所以用经典的 FORCE
# 依赖强制。
rtl-%: FORCE
	$(PYTHON) -m plm.cli.main generate rtl --config $* --quiet $(GENFLAGS) $(RTL_GENFLAGS)

tb-%: FORCE
	$(PYTHON) -m plm.cli.main generate tb --config $* --quiet $(GENFLAGS) $(TB_GENFLAGS)

list:
	@echo "Config sets found under test/: $(CONFIGS)"

clean: $(CONFIGS:%=clean-%)

clean-%: FORCE
	@echo "cleaning test/$*/rtl and test/$*/tb/tb_pipe_lane_mapper.sv"
	rm -rf test/$*/rtl test/$*/tb/tb_pipe_lane_mapper.sv

FORCE:
