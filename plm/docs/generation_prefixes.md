# Generation naming prefixes

The Generation page provides three independent text fields, persisted in the
workspace's `config/gen_flags.txt`. Nonempty prefixes get a trailing underscore
unless they already end with one. Empty fields keep the original names.
Configuration and manifests retain the entered values.

| Field | Scope | Example |
| --- | --- | --- |
| `module_prefix` | Generated and copied common module names, package name, testbench module name, and their references | `soc` or `soc_` produces `soc_pipe_lane_mapper` |
| `file_prefix` | Every emitted `.sv` filename, including common modules and testbench; flist and makefile paths follow those filenames | `rtl` or `rtl_` produces `rtl_pipe_lane_mapper.sv` |
| `macro_prefix` | PLM macros and the matching simulator define | `SOC` or `SOC_` produces `SOC_PIPE_USE_ICG_CELL`, `SOC_PIPE_ICG_CELL`, `SOC_PIPE_USE_CLKOR_CELL`, `SOC_PIPE_CLKOR_CELL`, `SOC_DUMP_FSDB` |

User signal/port names, struct fields, instance names and parameters keep their
existing names. Infrastructure filenames (`flist.f`, `makefile`, `manifest.json`)
also keep their existing names. Module prefixes cover the connection wrapper,
and package references follow the renamed package.

Module and macro prefixes must be empty or start with an ASCII letter or
underscore and contain only ASCII letters, digits and underscores. File prefixes
may contain ASCII letters, digits, underscores, dots and hyphens. Whitespace and
directory separators are rejected before saving or replacing generated outputs.

Changing any prefix makes existing output stale. Generation replaces the matched
RTL/TB set together and removes obsolete filenames. Generating again with the
same inputs skips generation after verifying the installed output files.

The CLI accepts the same options explicitly and does not read `gen_flags.txt`:

```sh
plm generate --config path/to/workspace --module-prefix soc --file-prefix rtl --macro-prefix SOC
```

In a source checkout, prepend `uv run`. Named configurations resolve under
`examples/`, so the editable DPR example can be generated with:

```sh
uv run plm generate --config dpr --dpr --module-prefix soc --file-prefix rtl --macro-prefix SOC
```

The CLI does not reuse the prefixes saved by Qt; pass all three explicitly when
the command should reproduce the same naming. See the
[examples guide](../examples/README.md) for sample-specific options.

External ICG/clock-OR cell integration must define the prefixed macros, such as
`SOC_PIPE_USE_ICG_CELL` and `SOC_PIPE_ICG_CELL`. The generated makefile already
passes the prefixed `SOC_DUMP_FSDB` define for VCS.
