# getaxiinfo

Summarize a generated DWC PCIe controller constants file without third-party
runtime dependencies.

```console
getaxiinfo
getaxiinfo --file path/to/generated/controller
getaxiinfo --file path/to/src/demo_pcie_ctl_cc_constants.svh --debug
getaxiinfo --file path/to/src/demo_pcie_ctl_cc_constants.svh -o report.md
getaxiinfo --file path/to/src/demo_pcie_ctl_cc_constants.svh --debug -o report-debug.md
getaxiinfo --version
```

Automatic discovery searches recursively below the current directory for a file
whose name contains `pcie_ctl_cc_constants.svh` and whose immediate parent is
`src`. Companion `*cap_port_cfg*.svh` files located in `include/` directories are
automatically detected and loaded to resolve PCIe capability linked lists.
Running inside `src` is supported. Multiple matching files are rejected;
select one with `--file`. Explicit file inputs can have any name. Different
controller files or macro prefixes are not silently merged.
The controller prefix is identified from core configuration macros; target names
then match in full within that namespace, keeping PF, VF and external-VF MSI
capability macros distinct.

Normal output contains `[PCIE]`, `[FUNCTIONS]`, `[AXI]`, `[OUTSTANDING]`,
`[EMBEDDED_DMA]`, `[IATU]`, `[REGISTER_MAPPING]`, `[MSIX]`, `[CAPABILITIES]`, and
`[NOTES]` when needed.
Only `--debug` prints `[SOURCE]` and `[MACRO_DETAILS]`.

`-o` / `--output REPORT.md` also saves a UTF-8 Markdown report with section
headings and tables, while retaining terminal output. Parent directories are
created as needed. `--debug` includes source locations, raw macro values and
derivation details in the Markdown report. Output cannot overwrite the input.

- Link width/speed, PF/VF counts and capabilities describe the generated
  configuration, rather than negotiated or software-enabled runtime state.
- AXI interfaces are displayed as AXI DMA (Manager), AXI Slave (Subordinate),
  and AXI CFG (DBI); extraction still uses the original DWC macro names.
  The AXI DMA interface label is independent of embedded DMA enablement.
  Dedicated AXI CFG accesses are Single
  transfers. That does not imply an outstanding count of one.
- The AXI table includes separate Read Outstanding and Write Outstanding
  columns using the project's empirical formulas, also shown in OUTSTANDING:
  AXI DMA read = `CC_MAX_MSTR_TAGS_AXI - 1` (independent of chunking enable),
  AXI DMA write = `CC_WR_CH_P_REQ_QUEUE_DP` (or `WR_CH_P_REQ_QUEUE_DP`),
  AXI Slave read = `CC_MAX_SLV_TAG`, and AXI Slave write =
  `CC_SLV_NUM_OUTSTND_WR_REQ`. Debug mode includes the formula derivations.
- These are empirical estimates. Shared NP pools, Posted tracking and buffer
  constraints are supplementary notes. An unestablished estimate is Unknown;
  disabled interfaces show N/A. AXI CFG has no empirical numeric formula.
- AXI payload widths exclude protection bits. CC_MSTR_BUS_* widths are used as
  fallbacks only when CX_RAS_EN is explicitly zero. Configured asynchronous
  clock frequencies are shown; synchronous operating frequency is core-dependent.
- HDMA and its Legacy DMA Map compatibility option are separate settings.
- Unroll existence and BAR mapping are separate settings. DMA/iATU use the
  selected UNROLL Function/BAR with independent offsets. CX_UNROLL_VIEW only
  selects documentation. Disabled unroll does not establish a legacy viewport.
- MSI-X values are per PF, including the settings for that PF's VFs. The 29-bit
  Table/PBA offset field is shifted left three bits to show a BAR-relative byte
  offset. VF macro suffixes index the owning PF.
- `Unknown` means absent/unresolved; `Disabled`, `N/A` and `Not mapped` have
  distinct meanings. Missing fields never suppress other sections.

The parser handles local object macros, comments, continuations, local conditional
definitions, references, integer literals, common integer operators, outer
ternaries and `$clog2`. It does not read external includes/compiler `-D` settings.
Unresolved expressions and X/Z literals are reported as Unknown, with reasons.
For known boolean configuration flags, an empty active definition means Enabled.
When the flag is absent, its numeric `*_VALUE` definition is used first; an
explicit generated ``// `define FLAG`` placeholder means Disabled. Comments inside
block comments or inactive conditional branches do not establish disabled flags.
Truly missing flags remain Unknown. Debug output identifies fallback sources.

The API `from getaxiinfo.main import getaxiinfo` returns raw macro strings
(or `None`), including indexed Function macros, without printing.

```console
uv build --python 3.12
python -m unittest discover -s tests -v
```
