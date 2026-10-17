# Generate one matched RTL/testbench output set for each config under examples/.

PYTHON  ?= uv run python
GENFLAGS ?=

SETFLAGS_maxpclk := --arch serdes --pclk-mode pclk_as_phy_input
SETFLAGS_dpr     := --dpr

CONFIG_MARKERS   := $(wildcard examples/*/config/controllers.csv)
CONFIGS          := $(patsubst examples/%/config/controllers.csv,%,$(CONFIG_MARKERS))

.PHONY: all help list clean $(CONFIGS) FORCE

all: $(CONFIGS)

help:
	@echo "Usage:"
	@echo "  make               generate matched RTL + testbench for every positive config"
	@echo "  make -k            same, but keep going past a failed config"
	@echo "  make <SET>         generate one config, e.g. make bifurcate"
	@echo "  make list          list positive configs found under examples/"
	@echo "  make clean         delete generated output"
	@echo "  make clean-<SET>   delete one config's generated output"
	@echo ""
	@echo "Config sets: $(CONFIGS)"

$(CONFIGS): %: FORCE
	$(PYTHON) -m plm.cli.main generate --config $* --quiet $(SETFLAGS_$*) $(GENFLAGS)

list:
	@echo "Config sets found under examples/: $(CONFIGS)"

clean: $(CONFIGS:%=clean-%)

clean-%: FORCE
	@echo "cleaning examples/$*/rtl and examples/$*/tb"
	rm -rf examples/$*/rtl examples/$*/tb

FORCE:
