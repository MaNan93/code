# Changelog

## 0.2.7 - 2026-11-17

- Gate VF Capability linked list parsing by SR-IOV enablement and VF count (suppress VF capabilities when SR-IOV is disabled or VF count is 0).
- Remove `--caps` CLI option; `[CAPABILITIES]` is integrated in the standard summary report.

## 0.2.6 - 2026-11-17

- Add PCIe Capability linked list parsing (Standard PCI 0x00-0xFF and PCIe Extended 0x100-0xFFF).
- Report each capability's base address, next offset pointer, capability ID, name, description, and byte size.
- Support PF0 and VF linked list resolution, including automatic detection and companion loading of `cap_port_cfg.svh`.
- Export `get_pcie_capabilities()` API.

## 0.2.5 - 2026-11-05

- Restore the project's four empirical Outstanding formulas in both AXI columns
  and the OUTSTANDING table; AXI DMA reads always use tags minus one.
- Mark results as empirical estimates and retain resource-sharing constraints
  as notes, with the exact formulas included in debug output.

## 0.2.4 - 2026-11-05

- Rename displayed AXI interfaces to AXI DMA, AXI Slave and AXI CFG.
- Add separate Read Outstanding and Write Outstanding columns to the AXI
  specification table in terminal and Markdown reports, retaining detailed
  shared NP, Posted tracking and set-aside capacity conditions.

## 0.2.3 - 2026-11-05

- Add `-o` / `--output REPORT.md` to export UTF-8 Markdown headings and tables.
- Include source provenance and macro derivations in reports with `--debug`.
- Keep terminal output available and prevent reports from overwriting the input.

## 0.2.2 - 2026-11-05

- Restore PCIe, PF/VF, AXI, Outstanding, DMA/HDMA, iATU, Unroll/BAR mapping,
  and per-PF/VF MSI-X specification summaries.
- Read empty boolean definitions, numeric `*_VALUE` fallbacks, and explicit
  disabled flag placeholders with source provenance and conditional handling.
- Use AXI payload widths without protection bits and ignore inactive settings.
- Retain numeric-expression evaluation and partial-configuration reporting;
  display source locations and macro details only in debug mode.
