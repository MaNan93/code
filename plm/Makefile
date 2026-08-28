# 对 configs/ 下每一套配置集重新跑 tool/plm_gen.py。
#
# 用途：
#   - CSV 或 tool/plm_gen.py 改完之后，一键把所有配置集的生成物刷新到最新，
#     避免出现"改了脚本/CSV，但某套配置忘了重新生成"的漂移（demo 就在这上面
#     栽过一次：加了 tie_off 列之后没同步更新，直接跑就报错）。
#   - 配合 CI：生成后 `git status --porcelain` 应该为空，否则说明有配置集
#     的生成物没跟脚本/CSV 保持同步。
#
# 用法：
#   make            # 等价于 make all：生成所有配置集，某一个失败就停
#   make -k         # 同上，但失败了继续跑完其余的（make 内置的 --keep-going）
#   make demo       # 只生成 demo 这一套
#   make list       # 列出 configs/ 下识别到的配置集名字
#   make clean      # 删掉所有配置集的生成物（rtl/、tb/tb_pipe_lane_mapper.sv）
#   make lint       # 对所有配置集的生成物跑 verilator --lint-only
#   make lint-demo  # 只 lint demo 这一套
#
# 透传额外参数给 plm_gen.py，例如切到组合直通的 sel_sync：
#   make all GENFLAGS="--sel-mode comb"

PYTHON    ?= python3
GENFLAGS  ?=
VERILATOR ?= verilator
LINTFLAGS ?= --lint-only -Wall -Wno-fatal

# 自动发现 configs/ 下的配置集：凡是 configs/<name>/config/controllers.csv
# 存在的 <name> 都算一个集，不用每加一套配置就手改 Makefile。
CONFIG_MARKERS := $(wildcard configs/*/config/controllers.csv)
CONFIGS        := $(patsubst configs/%/config/controllers.csv,%,$(CONFIG_MARKERS))
LINT_TARGETS   := $(CONFIGS:%=lint-%)

.PHONY: all list clean lint $(CONFIGS) FORCE

all: $(CONFIGS)

$(CONFIGS):
	$(PYTHON) tool/plm_gen.py --config $@ --quiet $(GENFLAGS)

list:
	@echo "configs/ 下的配置集：$(CONFIGS)"

clean:
	@for c in $(CONFIGS); do \
		echo "清理 configs/$$c/rtl 与 configs/$$c/tb/tb_pipe_lane_mapper.sv"; \
		rm -rf configs/$$c/rtl configs/$$c/tb/tb_pipe_lane_mapper.sv; \
	done

# lint 只检查生成物的语法/语义是否合法（比如上次那个 onehot_mux 的 SAFE
# 参数错误），不代表功能正确——功能正确性还是要靠 tb/仿真。
# 依赖生成物已存在（先 make 或 make <config>），这里不会自动重新生成。
lint: $(LINT_TARGETS)

# lint-% 是模式规则，光把展开后的名字塞进 .PHONY 并不能让 make 每次都重新跑
# （GNU make 对模式规则生成的目标不会那样处理），所以用经典的 FORCE 依赖强制。
lint-%: FORCE
	@echo "lint configs/$*"
	cd configs/$*/rtl && $(VERILATOR) $(LINTFLAGS) -f flist.f --top-module pipe_lane_mapper_top

FORCE:
