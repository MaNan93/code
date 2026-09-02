#=============================================================================
# Makefile for VCS & Verdi Simulation of PIPE Lane Mapper
#=============================================================================

# Tools
VCS      = vcs
SIMV     = ./simv

# Directories
RTL_DIR  = ../rtl
TB_DIR   = .

# Compilation Flags (Removed -lca, Added +define+DUMP_FSDB, Enabled KDB/Verdi debug)
VCS_FLAGS = -sverilog -full64 -kdb -debug_access+all \
            -timescale=1ns/1ps \
            +define+DUMP_FSDB

# Testbench Files
TB_FILES  = ../tb/tb_pipe_lane_mapper.sv

.PHONY: all compile run verdi clean

all: compile run

# Compile: cd to RTL directory to compile with relative paths in flist.f
# Outputs binary & log back to tb/ directory
compile:
	cd $(RTL_DIR) && $(VCS) $(VCS_FLAGS) -f flist.f $(TB_FILES) -o ../tb/simv -l ../tb/compile.log

# Run simulation in tb/ directory
run:
	$(SIMV) -l sim.log

# Open Verdi with both RTL code tree loaded and waves.fsdb opened
verdi:
	cd $(RTL_DIR) && verdi -sv -f flist.f $(TB_FILES) -ssf ../tb/waves.fsdb &

# Clean build and simulation artifacts
clean:
	rm -rf simv simv.daidir ucli.key waves.fsdb waves.vcd compile.log sim.log vcdplus.vpd DVEfiles verdi_log/ verdi_config_1/ Inter.vpd
	cd $(RTL_DIR) && rm -rf csrc simv simv.daidir ucli.key compile.log
