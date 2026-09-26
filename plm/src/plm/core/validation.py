"""Four-layer validation used by the CLI, generators and front ends."""

import csv
from dataclasses import dataclass
import io
from pathlib import Path
import re

from plm.core.model import Config
from plm.core.plan import GenerationPlan
from plm.core.plan import CONFIG_FILES
from plm.core.workspace import config_snapshot_from_payload


@dataclass(frozen=True)
class ValidationIssue:
    layer: str
    message: str
    table: str = None
    row: int = None
    column: object = None

    def __str__(self):
        return f"[{self.layer}] {self.message}"


class ValidationError(ValueError):
    def __init__(self, issues):
        self.issues = tuple(issues)
        super().__init__("\n".join(str(issue) for issue in self.issues))

_TABLES = {
    "controllers.csv": ("controllers", ("ctrl_id", "ctrl_name", "max_width")),
    "pipe_signals.csv": (
        "signals",
        ("signal_name", "signal_type", "direction", "width", "safe_state", "tie_off"),
    ),
    "lane_mapping.csv": ("mapping", ()),
}


def _csv_rows(path, content=None):
    try:
        handle = (
            Path(path).open(newline="", encoding="utf-8")
            if content is None
            else io.StringIO(content.decode("utf-8"), newline="")
        )
        with handle:
            return list(csv.DictReader(handle))
    except (OSError, UnicodeError, csv.Error):
        return []


def _column_from_message(filename, message):
    _table, columns = _TABLES[filename]
    if filename == "lane_mapping.csv":
        lane = re.search(r"\b(lane\d+)\b", message)
        return int(lane.group(1)[4:]) + 1 if lane else 0
    for column in columns:
        if re.search(rf"\b{re.escape(column)}\b", message):
            return column
    if filename == "controllers.csv":
        return "ctrl_id"
    return "signal_name"


def _format_issues(config_dir, error, files=None):
    """Translate parser diagnostics into table coordinates for every front end."""
    message = str(error)
    filename = next((name for name in _TABLES if name in message), None)
    if filename is None:
        return [ValidationIssue("format", message)]

    table, _columns = _TABLES[filename]
    line = re.search(r"\bline (\d+)\b", message)
    row = max(0, int(line.group(1)) - 2) if line else 0
    column = _column_from_message(filename, message)
    path = Path(config_dir) / filename

    duplicate = None
    if filename == "controllers.csv":
        match = re.search(r"duplicate ctrl_id (\d+)", message)
        duplicate = ("ctrl_id", match.group(1)) if match else None
    elif filename == "pipe_signals.csv":
        match = re.search(r"signal (\S+) defined twice", message)
        duplicate = ("signal_name", match.group(1)) if match else None
    elif filename == "lane_mapping.csv":
        match = re.search(r"mode (\d+) defined twice", message)
        duplicate = ("mode", match.group(1)) if match else None

    if duplicate:
        key, value = duplicate
        display_message = message.replace("duplicate ctrl_id", "Duplicate ctrl_id")
        rows = [
            index for index, data in enumerate(
                _csv_rows(path, files.get(filename) if files else None)
            )
            if str(data.get(key, "")).strip() == value
        ]
        mapped_column = 0 if filename == "lane_mapping.csv" else key
        return [
            ValidationIssue("format", display_message, table, index, mapped_column)
            for index in rows
        ]

    if filename == "pipe_signals.csv" and "phy2mac signals must use" in message:
        display_message = "phy2mac signals must be perlane"
        return [
            ValidationIssue("format", display_message, table, row, "signal_type"),
            ValidationIssue("format", display_message, table, row, "direction"),
        ]
    return [ValidationIssue("format", message, table, row, column)]


def _topology_issue(config, message):
    table, row, column = None, None, None
    mode_lane = re.search(r"\[mode (\d+)\].*?lane(\d+)", message)
    lane = re.search(r"\blane(\d+)\b", message)
    controller = next(
        (cid for cid, value in config.controllers.items() if value.name in message),
        None,
    )
    if mode_lane:
        mode, lane_number = map(int, mode_lane.groups())
        table = "mapping"
        row = config.modes.index(mode) if mode in config.modes else 0
        column = lane_number + 1
    elif lane:
        table = "mapping"
        row = 0
        column = int(lane.group(1)) + 1
    elif controller is not None:
        table = "controllers"
        row = controller
        column = "max_width" if "max_width" in message else "ctrl_id"
    elif message.startswith("mode values"):
        table, row, column = "mapping", 0, 0
    elif message.startswith("Controller count"):
        table, row, column = "controllers", 0, "ctrl_id"
    return ValidationIssue("topology", message, table, row, column)


def _read_config_snapshot(config_dir):
    config_dir = Path(config_dir)
    return {name: (config_dir / name).read_bytes() for name in CONFIG_FILES}


def _load_validated_config(config_dir, files):
    """Run the file-format and topology layers and return Config."""
    try:
        config = Config(config_dir, file_contents=files)
    except (OSError, SystemExit, UnicodeError, csv.Error) as error:
        raise ValidationError(_format_issues(config_dir, error, files)) from error

    topology = [_topology_issue(config, message) for message in config.validate()]
    if topology:
        raise ValidationError(topology)
    return config


def load_validated_config(config_dir):
    try:
        files = _read_config_snapshot(config_dir)
    except OSError as error:
        raise ValidationError(_format_issues(config_dir, error)) from error
    return _load_validated_config(config_dir, files)


def load_generation_plan(config_dir, options):
    """Run format, topology and generation-option validation in order."""
    try:
        files = _read_config_snapshot(config_dir)
    except OSError as error:
        raise ValidationError(_format_issues(config_dir, error)) from error
    config = _load_validated_config(config_dir, files)

    return _build_generation_plan(config, options, files)


def load_generation_plan_from_payload(payload, options):
    """Validate unsaved front-end rows without creating a temporary workspace."""
    virtual_config_dir = Path("<editor>") / "config"
    try:
        files = config_snapshot_from_payload(payload)
    except ValueError as error:
        raise ValidationError([ValidationIssue("format", str(error))]) from error
    config = _load_validated_config(virtual_config_dir, files)
    return _build_generation_plan(config, options, files)


def _build_generation_plan(config, options, files):
    option_issues = [ValidationIssue("generation", message) for message in options.errors()]
    if option_issues:
        raise ValidationError(option_issues)
    try:
        return GenerationPlan.build(config, options, validated=True, config_files=files)
    except (OSError, UnicodeError, ValueError) as error:
        raise ValidationError(
            [ValidationIssue("generation", f"could not fingerprint generation inputs: {error}")]
        ) from error


def plan_from_config(config, options):
    """Validate an already parsed Config and create its shared plan."""
    topology = [_topology_issue(config, message) for message in config.validate()]
    generation = [ValidationIssue("generation", message) for message in options.errors()]
    issues = topology + generation
    if issues:
        raise ValidationError(issues)
    try:
        return GenerationPlan.build(config, options, validated=True)
    except (OSError, UnicodeError, ValueError) as error:
        raise ValidationError(
            [ValidationIssue("generation", f"could not fingerprint generation inputs: {error}")]
        ) from error
