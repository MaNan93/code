"""Shared generation workflow for the CLI and interactive front ends."""

from dataclasses import dataclass
from pathlib import Path

from plm.core.exporter import export_all, output_set_matches_plan, read_manifests
from plm.core.validation import load_generation_plan


@dataclass(frozen=True)
class GenerationResult:
    plan: object
    manifests: dict
    generated: bool


def generate(config_dir, out_rtl, options, progress=None):
    """Validate and produce one current output set, skipping a true no-op."""
    notify = progress or (lambda _phase: None)
    notify("VALIDATING")
    plan = load_generation_plan(config_dir, options)
    workspace = Path(out_rtl).parent
    if output_set_matches_plan(plan, workspace, verify_files=True):
        notify("UP_TO_DATE")
        return GenerationResult(plan, read_manifests(workspace), False)

    notify("GENERATING")
    manifests = export_all(plan, out_rtl)
    return GenerationResult(plan, manifests, True)
