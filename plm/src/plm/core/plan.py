"""Validated, shared intermediate plan for every generated artefact."""

from dataclasses import dataclass
import hashlib
import json
from pathlib import Path

from plm.core.gen_flags import GenerationOptions
from plm.core.verible import formatter_identity


CONFIG_FILES = ("controllers.csv", "lane_mapping.csv", "pipe_signals.csv")
MANIFEST_SCHEMA_VERSION = 2
GENERATOR_FILES = (
    "plan.py",
    "exporter.py",
    "gen_flags.py",
    "naming.py",
    "model.py",
    "verible.py",
    "generator/rtl.py",
    "generator/tb.py",
    "tb_makefile.mk",
)


def _normalized_text_bytes(path):
    """Hash text by content, independent of the checkout's line endings."""
    text = Path(path).read_text(encoding="utf-8")
    return text.replace("\r\n", "\n").replace("\r", "\n").encode("utf-8")


def _generator_fingerprint():
    """Hash every source asset that can change generated RTL/TB semantics."""
    core_dir = Path(__file__).resolve().parent
    paths = [core_dir / name for name in GENERATOR_FILES]
    paths.extend(sorted((core_dir / "common").glob("*.sv")))
    digest = hashlib.sha256()
    for path in paths:
        relative = path.relative_to(core_dir).as_posix()
        digest.update(relative.encode("utf-8"))
        digest.update(b"\0")
        digest.update(_normalized_text_bytes(path))
        digest.update(b"\0")
    return digest.hexdigest()


def _normalized_content_bytes(content):
    text = content.decode("utf-8")
    return text.replace("\r\n", "\n").replace("\r", "\n").encode("utf-8")


def _config_hash(config_dir, file_contents=None):
    digest = hashlib.sha256()
    for name in CONFIG_FILES:
        digest.update(name.encode("utf-8"))
        digest.update(b"\0")
        if file_contents is None:
            content = _normalized_text_bytes(Path(config_dir) / name)
        else:
            content = _normalized_content_bytes(file_contents[name])
        digest.update(content)
        digest.update(b"\0")
    return digest.hexdigest()


@dataclass(frozen=True)
class GenerationPlan:
    """Config-derived facts calculated once and shared by RTL, TB and Report.

    It intentionally presents the Config read API as properties so existing
    pure generator functions can consume a plan without duplicating topology
    derivation or carrying a second representation of the same design.
    Build detaches the source Config; edit that source and build a new plan
    for a new generation. The plan's copied inputs are one generation snapshot.
    """

    config: object
    options: GenerationOptions
    config_hash: str
    generator_fingerprint: str
    formatter: object
    pclk_sources: object
    pclk_candidates: object
    topology: object

    @classmethod
    def build(cls, config, options, *, validated=False, config_files=None):
        config = config.snapshot()
        topology = config.topology_indexes()
        if not validated:
            options.validated()
            topology_errors = config.validate(_topology=topology)
            topology_errors.extend(
                error[0] for error in config.generated_name_errors(options.pclk_mode, options.dpr)
            )
            if topology_errors:
                raise ValueError("\n".join(topology_errors))
        return cls(
            config=config,
            options=options,
            config_hash=_config_hash(config.dir, config_files),
            generator_fingerprint=_generator_fingerprint(),
            formatter=formatter_identity(options.verible_path, options.verible_flags),
            pclk_sources=topology.pclk_sources,
            pclk_candidates=topology.pclk_candidates,
            topology=topology,
        )

    @property
    def generation_key(self):
        payload = {
            "config_hash": self.config_hash,
            "generator_fingerprint": self.generator_fingerprint,
            "formatter": self.formatter,
            "options": self.options.manifest_dict(),
        }
        encoded = json.dumps(payload, sort_keys=True, separators=(",", ":")).encode("utf-8")
        return hashlib.sha256(encoded).hexdigest()

    @property
    def controllers(self):
        return self.config.controllers

    @property
    def signals(self):
        return self.config.signals

    @property
    def modes(self):
        return self.config.modes

    @property
    def lane_count(self):
        return self.config.lane_count

    @property
    def mapping(self):
        return self.config.mapping

    @property
    def num_ctrl(self):
        return self.config.num_ctrl

    @property
    def groups(self):
        return self.config.groups

    def group_of_lane(self, lane):
        return self.topology.lane_groups[lane]

    def ctrl_pclk_src(self):
        return self.pclk_sources

    def ctrl_pclk_cands(self):
        return self.pclk_candidates

    def report(self):
        return self.config.report(_topology=self.topology)

    def manifest_base(self):
        return {
            "schema_version": MANIFEST_SCHEMA_VERSION,
            "generation_key": self.generation_key,
            "config_hash": self.config_hash,
            "generator_fingerprint": self.generator_fingerprint,
            "formatter": self.formatter,
            "options": self.options.manifest_dict(),
            "design": {
                "lane_count": self.lane_count,
                "mode_count": len(self.modes),
                "controller_count": self.num_ctrl,
                "group_count": len(self.groups),
            },
        }
