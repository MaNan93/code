# Generation naming prefixes

The Generation page provides three independent text fields, persisted in the
workspace's `config/gen_flags.txt`. Prefixes are prepended exactly as entered;
no separator is added automatically. Empty fields keep the original names.

| Field | Scope | Example |
| --- | --- | --- |
| `module_prefix` | Generated and copied common module names, package name, testbench module name, and their references | `soc_` produces `soc_pipe_lane_mapper` |
| `file_prefix` | Every emitted `.sv` filename, including common modules and testbench; flist and makefile paths follow those filenames | `rtl_` produces `rtl_pipe_lane_mapper.sv` |
| `macro_prefix` | PLM macros and the matching simulator define | `SOC_` produces `SOC_PIPE_USE_ICG_CELL`, `SOC_PIPE_ICG_CELL`, `SOC_PIPE_USE_CLKOR_CELL`, `SOC_PIPE_CLKOR_CELL`, `SOC_DUMP_FSDB` |

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
plm generate --config path/to/workspace --module-prefix soc_ --file-prefix rtl_ --macro-prefix SOC_
```

External ICG/clock-OR cell integration must define the prefixed macros, such as
`SOC_PIPE_USE_ICG_CELL` and `SOC_PIPE_ICG_CELL`. The generated makefile already
passes the prefixed `SOC_DUMP_FSDB` define for VCS.
