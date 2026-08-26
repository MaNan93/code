# PLM Project Memory

## Project: PIPE Lane Mapper (C:\Users\man\Desktop\plm)

### Architecture
- CSV-driven RTL generation (Python -> SystemVerilog)
- Config: controllers.csv, lane_mapping.csv, pipe_signals.csv
- Generator: tools/plm_gen.py, config parser: tools/plm_config.py
- Output: rtl/gen/ (6 SV files), filelist/ (rtl.f, sim.f)
- Common RTL: rtl/common/ (sync2.sv, bbm_sel_onehot.sv, clk_gate.sv, onehot_mux.sv)

### Hierarchy (after 2026-08-25 refactor)
- pipe_lane_mapper_top  -- pure instantiation layer (103 lines)
  - pipe_lane_clk_top    -- decoder + ctrl_pclk + BBM + feedback clk (121 lines)
  - pipe_lane_data_m2p   -- mac2phy data mux (84 lines)
  - pipe_lane_data_p2m   -- phy2mac data mux by controller port (175 lines)
- pipe_lane_decoder     -- mode decode (combinational)
- pipe_pkg              -- struct types, SAFE constants, lane_sel_t

### Key Conventions
- Signal names: user's original mac_phy_* / phy_mac_* prefix (DO NOT change)
- phy_rst_n: lives inside mac2phy_lane_t struct, accessed as ctrlX_mac2phy[0].phy_rst_n
- CSV: all entries stripped by _strip_dict() in plm_config.py
- Feedback clock: same-group lanes share one set of clk_gate, first lane uses |pin_gated_gX, rest reference phy_pclk_in[g.lanes[0]]
- 4 modes: m0=x16(C0), m1=x8(C0)+x8(C2), m2=x8(C0)+x4(C2)+x4(C3), m3=x4*4

### User Preferences
- User is very particular about signal names -- never auto-rename
- User prefers indexed struct access: ctrl0_mac2phy[0].phy_rst_n (not .phy_rst_n)
- User dislikes redundant code and will call it out
