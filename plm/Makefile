# Generate one matched RTL/testbench output set for each positive fixture.
# quad is intentionally invalid and exists only to prove validation failures.

PYTHON  ?= uv run python
GENFLAGS ?=

SETFLAGS_maxpclk := --arch serdes --pclk-mode pclk_as_phy_input
SETFLAGS_dpr     := --dpr

CONFIG_MARKERS   := $(wildcard test/*/config/controllers.csv)
ALL_CONFIGS      := $(patsubst test/%/config/controllers.csv,%,$(CONFIG_MARKERS))
NEGATIVE_CONFIGS := quad
CONFIGS          := $(filter-out $(NEGATIVE_CONFIGS),$(ALL_CONFIGS))

.PHONY: all help list clean $(CONFIGS) FORCE

all: $(CONFIGS)

help:
	@echo "Usage:"
	@echo "  make               generate matched RTL + testbench for every positive config"
	@echo "  make -k            same, but keep going past a failed config"
	@echo "  make <SET>         generate one config, e.g. make bifurcate"
	@echo "  make list          list positive configs found under test/"
	@echo "  make clean         delete generated output"
	@echo "  make clean-<SET>   delete one config's generated output"
	@echo ""
	@echo "Config sets: $(CONFIGS)"
	@echo "Negative fixtures skipped: $(NEGATIVE_CONFIGS)"

$(CONFIGS): %: FORCE
	$(PYTHON) -m plm.cli.main generate --config $* --quiet $(SETFLAGS_$*) $(GENFLAGS)

list:
	@echo "Config sets found under test/: $(CONFIGS)"

clean: $(ALL_CONFIGS:%=clean-%)

clean-%: FORCE
	@echo "cleaning test/$*/rtl and test/$*/tb"
	rm -rf test/$*/rtl test/$*/tb

FORCE:
