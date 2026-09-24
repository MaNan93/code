# Changelog

All notable changes to `ralf2xlsx` are recorded here. The release version
itself lives in [`pyproject.toml`](pyproject.toml) (single source of
truth); this file is just the history behind each bump.

## v3.4

- Move this changelog out of `cli.py`'s module docstring into
  `CHANGELOG.md`. The docstring now only keeps usage examples and a
  pointer here; `pyproject.toml` remains the single version source.
- Remove dead code left over from Excel sheets that no longer exist
  (`WARN_COLS`, `REGSUM_COLS`, `BLOCKTREE_COLS`, an unused `warn_fill`) --
  none had a second reference anywhere in the file.
- Trim the Overview row dicts to the four fields actually used
  (`instance`, `base`, `sheet`, `_base`); `definition`/`domains`/
  `bus_bytes`/`endian` were being computed and thrown away every run.
- Perf: memoize `--sort addr`'s block-root resolution. It was doing an
  O(#blocks) scan for every row whose block path wasn't already a
  `block_base` key -- on a large design (many rows, hundreds of blocks)
  that's O(rows * blocks) called twice (`ela.rows` and `ela.reg_rows`).
  Only a handful of distinct block paths actually occur, so caching
  turns repeat lookups into O(1).
- Perf: `build_block_tree_rows`' parent lookup no longer scans every
  other block path with `startswith` for each block (O(n^2)). Walk up
  one dot-segment at a time instead (`soc.a.b.c` -> `soc.a.b` -> `soc.a`
  -> `soc`), checking set membership at each step -- same result (the
  longest valid ancestor), O(depth) per block instead of O(n).

## v3.3

- Multi-domain block sheets (e.g. a bridge with pci/ahb) now get a
  Domain column back automatically, even under the compact column set,
  so same-address/same-name registers from different interfaces can
  still be told apart.
- Generate a sheet for every reachable block, even ones with no
  register rows (memory-only or genuinely empty) -- Overview/Block tree
  no longer link to a sheet that doesn't exist.
- Auto addr-map detection now only looks at blocks actually reachable
  from the selected top(s), not every block definition in the file --
  an unused block named e.g. VF1_PF0_unused no longer forces the whole
  file to 33-bit.
- VERSION is now read from installed package metadata
  (importlib.metadata) instead of a second hardcoded string; pyproject
  version is the single source of truth. Also wires up an actual
  `--version` flag (VERSION existed but nothing read it before).
- README: drop the hardcoded version from the title (it goes stale
  every release), fix the `--quiet` row (it hasn't written to a Warnings
  sheet since Warnings moved to terminal-only), and note the
  auto-detect addr-map scan is reachable-blocks-only.

## v3.2

- Refactor: the "strip a block path's trailing `.<domain>` segment" snippet
  was duplicated 4x (block tree, per-block sheet grouping, Overview,
  `--sort addr`); extract `strip_domain()`. The Overview node-collection loop
  duplicated `build_block_tree_rows`' node-collection loop almost verbatim;
  extract `_collect_block_nodes()` and have both call it. No behavior
  change (verified: Overview order/hyperlinks, per-block sheet names,
  and `--sort addr` domain grouping all still match).

## v3.1

- Batch mode (multiple `.ralf` on the command line): stop repeating
  `"[filename] "` on every terminal line. The filename now appears once,
  in the `"Summary [filename]:"` header; Block tree, warnings, address
  map detail and the final `[ok]` line are unprefixed. Fatal errors that
  can happen before a Summary is ever printed (file not found, parse
  failure, missing top, write failure, ...) still carry the
  `"[filename] "` tag so batch failures stay identifiable.

## v3.0

- **BREAKING**: `--addr-map` is no longer opt-in. When omitted, the source
  layout (Table 3-22 vs 3-23) is auto-detected from block names: a name
  containing `VF1_PF0` or `VF_PF0` (case-insensitive) implies the 33-bit
  layout, otherwise 32-bit. Passing `--addr-map 32bit/33bit` explicitly
  still overrides the detected value. This assumes every input `.ralf`
  uses one of these two DBI address layouts -- running this tool on an
  unrelated RALF file will now silently remap its addresses too.
- `print_summary`'s "address map" line now always prints and notes
  whether the layout was auto-detected or given via `--addr-map`.

## v2.23

- Simplify Table 3-22 CDM detection in `remap_dbi_address` to a single
  `(raw >> 21) == 0` check -- equivalent to the previous `high==0` and
  `bit21==0` pair, no behavior change.

## v2.22

- Reorder Block tree metadata to `(base=..., def=...)` -- base address first,
  definition name second.

## v2.21

- Recognize the Port Logic(CDM) address range (`DISABLE_CFG_MAP_PL_REG=1`)
  in both Table 3-22 and Table 3-23 `--addr-map` source layouts. It has no
  slot in the target layout, so it is explicitly skipped with a specific
  warning instead of falling through to the generic "unrecognized
  encoding" error.
- Fix Table 3-23 ELBI detection: it only checked `bits[32:30]==0b100`,
  missing ELBI addresses with bit 30 set (falls through to the generic
  error with a less specific message). Match on `bits[32:31]==0b10`, the
  only combination that actually distinguishes ELBI from every other
  Table 3-23 region.

## v2.20

- Hide Volatile from compact Excel sheets by default.
- Add `--show-violatile` to include Volatile in the compact view.

## v2.19

- Keep address-map terminal output concise by default.
- Add `--show-addr-map` to opt into per-register raw-to-mapped details.

## v2.18

- Show every raw-to-mapped register address in terminal output.
- Apply address mapping to block bases so Overview and the terminal block
  tree use converted addresses as well as each block sheet's Address column.

## v2.17

- Rename the explicit source selector to `--addr-map {32bit,33bit}`.
- Print mapped/unchanged/failed register counts so identity mappings are
  distinguishable from an option that was not applied.
  32bit uses the first supplied source layout and 33bit uses the second.
- Omitting `--addr-map` leaves addresses unchanged; converted addresses
  continue to drive `--sort addr`.

## v2.13

- Remove Enum, R/W Limit, Field Desc and Register Desc from the default
  compact block sheets, leaving only columns A-H.

## v2.12

- Reduce Overview to Block and Base Addr; Block remains the navigation link.
- Remove Block, Domain, Kind and Width(bit) from compact block sheets.

## v2.11

- Use a compact 16-column register view by default in Excel.
- Add `--full-columns` to restore all 29 detailed register columns.
- Keep CSV output full-width for machine processing.

## v2.10

- Fix Overview sheet hyperlinks: assigning a plain string to
  `cell.hyperlink` sets `Hyperlink.target`, which openpyxl always writes as
  an *external* relationship -- Excel/WPS then treats `"#'Sheet'!A1"` as a
  broken URL instead of jumping to the sheet. Use `Hyperlink(location=...)`
  with no target/id, which is how OOXML actually encodes an in-workbook
  jump.
- Fix `--sort addr` not affecting the terminal Block tree: it rendered
  `ela.blk_rows` in raw instantiation order regardless of `--sort`. Sort
  each node's children (and the root list) by base address when
  `--sort addr` is given.
- Stop emitting the RegisterMap sheet when per-block sheets are also
  being generated (the default) -- they already carry the same rows
  split by block, so RegisterMap was pure duplication. It still appears
  as the sole register-detail sheet under `--no-sheet-per-block`.

## v2.9

- Fix `--sort addr`: a multi-domain block (same base address, different
  domain interfaces, e.g. a bridge with pci/ahb domains) had its rows
  interleaved by address instead of staying grouped per domain, because
  the tie-break key collapsed both domains to the same block root.
  Tie-break on the full block path again so each block/domain stays
  contiguous while blocks are still ordered by base address.

## v2.8

- Move Summary, BlockTree and Warnings out of Excel and print them to the terminal.
- Remove the Registers summary worksheet.
- Keep Excel focused on RegisterMap, optional Memories/Enums, and per-block worksheets.

## v2.7

- Add BlockTree worksheet showing the instantiated system/block hierarchy.
- Show both block instance path and block definition name (e.g. `a=b` => Definition a, Instance b).
- Collapse multi-domain interfaces under one block-tree node.

## v2.6

- Generate one worksheet per instantiated block by default.
- Only blocks reachable from the selected system/top are emitted.
- Multi-domain blocks stay in one worksheet; Domain distinguishes interfaces.
- Add `--no-sheet-per-block` to disable per-block worksheets; keep `-s` for compatibility.

## v2.5

- Accept multiple `.ralf` files on the command line. Each file is parsed
  and elaborated independently (its own definition table, own top
  selection) and gets its own `.xlsx`; `-o`/`--csv` are treated as an output
  directory when more than one `.ralf` is given.

## v2.4

- Fix Tcl `#` comment lexing: `#` starts a comment only at command start;
  literal `#` inside words/doc text no longer truncates the line or loses braces.
- Catch XLSX/CSV output errors and return a clean tool error instead of traceback.

## v2.3

- Fix field access-mode validation: UVM and VMM RALF use different tables
  (only rw/ro/wo/w1/w1c/rc overlap). Accept the union by default; `--flavor`
  selects a single dialect.
- Fix mixed-language backdoor paths: keep ONE path chain and pick the
  separator per appended segment, so a Verilog hierarchy ending in a VHDL
  signal yields a complete path instead of two halves plus a bogus warning.
  The either/or rule is enforced per construct, as the UG states.
- Fix O(n^2) xlsx writing: assign merged ranges in bulk instead of calling
  openpyxl `merge_cells()` once per range.
- Report property statements at global scope as a warning instead of an
  AttributeError traceback; `main()` no longer lets exceptions escape.
- Accept `"hdl_path = (...)"` / `"vhdl_path = (...)"` with spaces around `'='`.

## v2.2

- Support static virtual-register address elaboration (memory/offset/increment).
- Propagate regfile read/write restrictions to contained registers.
- Build hierarchical Verilog HDL paths and add local/backdoor path columns.
- Support VHDL `vhdl_path` hierarchy.
- Add Shared/Domain-oriented review data and access-mode validation.
- Ignore `user_code` safely; improve doc HTML-to-text conversion.
- Preserve v2.1 fixes: `block.domain` selection, `left_to_right` gaps, `change_reset`,
  and single-interface bytes/endian handling.

## v2.1

- Fix `block.domain` elaboration.
- Fix `left_to_right` field layout with explicit gaps.
- Support `change_reset` overrides.
- Fix single-interface bytes/endian handling.

## v2.0

- Lexer/parser/elaborator based RALF -> XLSX implementation.
