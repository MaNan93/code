# ---------------------------------------------------------------------
# DWC_pcie XALI / TRGT1 BFM
# ---------------------------------------------------------------------
DW ?= 256

VERILATOR ?= verilator
VFLAGS = --binary -sv --timing -Wno-WIDTH -Wno-DECLFILENAME \
         -Wno-UNUSEDSIGNAL -Wno-VARHIDDEN -Wno-TIMESCALEMOD \
         +define+DWC_BFM_DW=$(DW)

.PHONY: all unit lint clean vcs xrun

# Default: what actually runs here -- the alignment round-trip unit test.
all: unit

unit:
	$(VERILATOR) $(VFLAGS) -f filelist_unit.f \
	    --top-module tb_dwc_align_unit -o align_ut
	./obj_dir/align_ut

# Synthesizable Non-Posted tracker, full -Wall lint.
lint:
	$(VERILATOR) --lint-only -sv -Wall -Wno-DECLFILENAME \
	    src/dwc_trgt1_pkt_halt_tracker.sv \
	    --top-module dwc_trgt1_pkt_halt_tracker

# Full BFM testbench -- needs clocking blocks + virtual interfaces.
vcs:
	vcs -full64 -sverilog -assert svaext -timescale=1ns/1ps \
	    -f filelist.f -o simv +define+DWC_BFM_DW=$(DW) && ./simv

xrun:
	xrun -64bit -sv -assert -timescale 1ns/1ps \
	    -f filelist.f +define+DWC_BFM_DW=$(DW)

clean:
	rm -rf obj_dir simv simv.daidir csrc ucli.key xcelium.d xrun.log
