# 对 configs/ 下每一套配置集重新跑 tool/plm_gen_rtl.py / tool/plm_gen_tb.py。
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
#   make list         # 列出 configs/ 下识别到的配置集名字
#   make clean        # 删掉所有配置集的生成物（rtl/、tb/tb_pipe_lane_mapper.sv）
#
# 透传额外参数：
#   GENFLAGS      两个工具都会收到，比如切时钟架构：
#                   make all GENFLAGS="--pclk-mode phy-input-max-pclk"
#   RTL_GENFLAGS  只传给 plm_gen_rtl.py，比如切到组合直通的 sel_sync：
#                   make all RTL_GENFLAGS="--sel-mode comb"
#   TB_GENFLAGS   只传给 plm_gen_tb.py
#
# 某个配置集本身就是为了演示某个非默认 flag 存在的（比如 test_maxpclk 演示
# --pclk-mode phy-input-max-pclk，RTL 和 TB 都要用这个 flag），这种 flag 要
# 跟着配置集本身固定下来，不能指望每次手动传 GENFLAGS——在下面用
# GENFLAGS_<配置集名> 声明，会同时叠加给 RTL 和 TB 两边的生成命令。

PYTHON       ?= python3
GENFLAGS     ?=
RTL_GENFLAGS ?=
TB_GENFLAGS  ?=

# 每个配置集固定绑定的额外生成参数（不需要的配置集不用列在这里），同时
# 传给 plm_gen_rtl.py 和 plm_gen_tb.py。
GENFLAGS_test_maxpclk := --pclk-mode phy-input-max-pclk

# 自动发现 configs/ 下的配置集：凡是 configs/<name>/config/controllers.csv
# 存在的 <name> 都算一个集，不用每加一套配置就手改 Makefile。
CONFIG_MARKERS := $(wildcard configs/*/config/controllers.csv)
CONFIGS        := $(patsubst configs/%/config/controllers.csv,%,$(CONFIG_MARKERS))

.PHONY: all list clean $(CONFIGS) FORCE

all: $(CONFIGS)

# 每套配置集：RTL 和 testbench 都刷新。
$(CONFIGS): %: rtl-% tb-%

# rtl-%/tb-% 是模式规则，光把展开后的名字塞进 .PHONY 并不能让 make 每次都
# 重新跑（GNU make 对模式规则生成的目标不会那样处理），所以用经典的 FORCE
# 依赖强制。
rtl-%: FORCE
	$(PYTHON) tool/plm_gen_rtl.py --config $* --quiet $(GENFLAGS) $(RTL_GENFLAGS) $(GENFLAGS_$*)

tb-%: FORCE
	$(PYTHON) tool/plm_gen_tb.py --config $* --quiet $(GENFLAGS) $(TB_GENFLAGS) $(GENFLAGS_$*)

list:
	@echo "configs/ 下的配置集：$(CONFIGS)"

clean:
	@for c in $(CONFIGS); do \
		echo "清理 configs/$$c/rtl 与 configs/$$c/tb/tb_pipe_lane_mapper.sv"; \
		rm -rf configs/$$c/rtl configs/$$c/tb/tb_pipe_lane_mapper.sv; \
	done

FORCE:
