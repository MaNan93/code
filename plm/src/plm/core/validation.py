"""Four-layer validation used by the CLI, generators and front ends."""

from dataclasses import dataclass

from plm.core.model import Config
from plm.core.plan import GenerationPlan


@dataclass(frozen=True)
class ValidationIssue:
    layer: str
    message: str

    def __str__(self):
        return f"[{self.layer}] {self.message}"


class ValidationError(ValueError):
    def __init__(self, issues):
        self.issues = tuple(issues)
        super().__init__("\n".join(str(issue) for issue in self.issues))


def load_validated_config(config_dir):
    """Run the file-format and topology layers and return Config."""
    try:
        config = Config(config_dir)
    except (OSError, SystemExit) as error:
        raise ValidationError([ValidationIssue("format", str(error))]) from error

    topology = [ValidationIssue("topology", message) for message in config.validate()]
    if topology:
        raise ValidationError(topology)
    return config


def load_generation_plan(config_dir, options):
    """Run format, topology and generation-option validation in order."""
    config = load_validated_config(config_dir)

    option_issues = [
        ValidationIssue("generation", message) for message in options.errors()
    ]
    if option_issues:
        raise ValidationError(option_issues)

    return GenerationPlan.build(config, options, validated=True)


def plan_from_config(config, options):
    """Validate an already parsed Config and create its shared plan."""
    topology = [ValidationIssue("topology", message) for message in config.validate()]
    generation = [ValidationIssue("generation", message) for message in options.errors()]
    issues = topology + generation
    if issues:
        raise ValidationError(issues)
    return GenerationPlan.build(config, options, validated=True)
