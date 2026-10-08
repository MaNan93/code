# Regression data

`samples/` contains fixed, reviewed inputs for automatic tests. These files are
independent of the editable workspaces in the repository's `test/` directory.
Tests read these inputs or copy them into temporary directories before writing.
They do not read Git history or regenerate data in this directory.

The four positive samples cover both clock architectures, DPR, lane grouping,
and mode transitions. `quad` is a negative topology fixture. The initial
`maxpclk` fixture uses the original reviewed sample, so changing the user's
`test/maxpclk/config/` cannot change test behavior.

Each positive sample's `expected.json` records SHA-256 hashes of generated text
with normalized LF line endings. Manifest source fingerprints and generation
keys are checked against the current generation plan instead of being golden
constants. This keeps source-only refactoring from invalidating RTL baselines,
while still detecting added, missing, or changed generated files.

Change a baseline only after reviewing an intentional RTL/TB change. Generate
into a temporary directory with Verible disabled, inspect the changed output,
and update the corresponding hashes explicitly. Never refresh the baselines as
part of running tests or building a release.
