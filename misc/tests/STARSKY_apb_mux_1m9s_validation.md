Validation completed on 2026-10-15 using local PATH tools.

The supplied Downloads RTL already contained the valid 19-bit address decode
and the immediate reserved-address response. The repository had no existing
copy, so the delivered RTL is under `misc/`. It preserves those fixes,
simplifies PREADY to a masked reduction, and removes DATA_WIDTH as requested:
all data ports are fixed at 32 bits. All 90 port names and directions are
preserved, with widths matching the supplied module at DATA_WIDTH=32.
No registers, state machine, or new APB signals were added.

Address mapping is unchanged:

| Slave | First address | Last address | Size |
| --- | --- | --- | --- |
| PHY0 | 0x00000 | 0x0FFFF | 64 KB |
| PHY1 | 0x10000 | 0x1FFFF | 64 KB |
| PHY2 | 0x20000 | 0x2FFFF | 64 KB |
| PHY3 | 0x30000 | 0x3FFFF | 64 KB |
| PCIe0 | 0x40000 | 0x40FFF | 4 KB |
| PCIe1 | 0x41000 | 0x41FFF | 4 KB |
| PCIe2 | 0x42000 | 0x42FFF | 4 KB |
| PCIe3 | 0x43000 | 0x43FFF | 4 KB |
| TOP | 0x44000 | 0x443FF | 1 KB |
| Reserved | 0x44400 | 0x7FFFF | PREADY=1, PRDATA=0 |

Checks passed:

- Verilator RTL lint with Verilog-2005 and `-Wall`.
- Verilator timed Testbench lint with `-Wall`.
- Verible syntax checks and formatting; formatting is stable on a second pass.
- All 524,288 byte addresses against an independent full-range decode oracle.
- Nine slave start/end addresses, adjacent boundaries, and reserved addresses.
- Read, write, readback, and distinct per-slave response data.
- Setup/Access behavior, 0/1/3 wait cycles, no acceptance during Setup or wait.
- Slave PSEL one-hot-or-zero, selected-only PENABLE and response routing.
- Unselected slaves cannot force readiness or block completion.
- Consecutive transfers to different slaves with master PSEL held high.
- Forwarded address, clock, reset, write direction, and write data.

Simulation output (exit code 0):

```text
PASS data_bits=32 transactions=83 addresses=524288 checks=524636
```

To reproduce from the `misc/` directory in PowerShell with the installed Windows
Verilator toolchain:

```powershell
New-Item -ItemType Directory -Force -Path build/starsky_apb_mux/w32 | Out-Null
$env:LANG = 'C'
$env:LC_ALL = 'C'
$env:LC_CTYPE = 'C'
$taskPython = (Get-Command python).Source.Replace('\', '/')
verilator --lint-only --language 1364-2005 -Wall --top-module STARSKY_apb_mux_1m9s STARSKY_apb_mux_1m9s.v
if ($LASTEXITCODE -ne 0) { throw 'RTL lint failed' }
verilator --binary --timing --timescale 1ns/1ps --top-module tb_STARSKY_apb_mux_1m9s -Wall --Mdir build/starsky_apb_mux/w32 -j 4 -MAKEFLAGS "PYTHON3=$taskPython" -LDFLAGS '-static' STARSKY_apb_mux_1m9s.v tests/tb_STARSKY_apb_mux_1m9s.sv
if ($LASTEXITCODE -ne 0) { throw 'Simulation build failed' }
& ./build/starsky_apb_mux/w32/Vtb_STARSKY_apb_mux_1m9s.exe
if ($LASTEXITCODE -ne 0) { throw 'Simulation failed' }
```

Build products remain under the existing ignored `build/` directory.
The installed Windows toolchain emits nonfatal host-path/uname diagnostics and
C++ runtime macro-redefinition warnings; RTL and Testbench lint have no warnings.
No unresolved RTL functional issues were found. Icarus Verilog was not available;
the simulation used Verilator (two-state simulation, not X/Z propagation testing).
