// RTL filelist. The package must come before the modules that use it.

+incdir+common
+incdir+src

common/pipe_lane_sync2.sv
common/pipe_lane_sel_sync.sv
common/pipe_lane_clk_gate.sv
common/pipe_lane_data_mux.sv

src/pipe_lane_signal_pkg.sv
src/pipe_lane_mode_dec.sv
src/pipe_lane_sel_gen.sv
src/pipe_lane_clk_mux.sv
src/pipe_lane_rst_mux.sv
src/pipe_lane_data_m2p.sv
src/pipe_lane_data_p2m.sv
src/pipe_lane_mapper_top.sv
