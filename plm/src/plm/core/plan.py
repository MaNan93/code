"""Validated, shared intermediate plan for every generated artefact."""

from dataclasses import dataclass
import hashlib
import json
from pathlib import Path

from plm.core.gen_flags import GenerationOptions


CONFIG_FILES = ("controllers.csv", "lane_mapping.csv", "pipe_signals.csv")


def _config_hash(config_dir):
    digest = hashlib.sha256()
    for name in CONFIG_FILES:
        path = Path(config_dir) / name
        digest.update(name.encode("utf-8"))
        digest.update(b"\0")
        digest.update(path.read_bytes())
        digest.update(b"\0")
    return digest.hexdigest()


@dataclass(frozen=True)
class GenerationPlan:
    """Config-derived facts calculated once and shared by RTL, TB and Report.

    It intentionally presents the Config read API as properties so existing
    pure generator functions can consume a plan without duplicating topology
    derivation or carrying a second representation of the same design.
    """

    config: object
    options: GenerationOptions
    config_hash: str
    pclk_sources: object
    pclk_candidates: object

    @classmethod
    def build(cls, config, options, *, validated=False):
        if not validated:
            options.validated()
            topology_errors = config.validate()
            if topology_errors:
                raise ValueError("\n".join(topology_errors))
        return cls(
            config=config,
            options=options,
            config_hash=_config_hash(config.dir),
            pclk_sources=config.ctrl_pclk_src(),
            pclk_candidates=config.ctrl_pclk_cands(),
        )

    @property
    def generation_key(self):
        payload = {
            "config_hash": self.config_hash,
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
        return self.config.group_of_lane(lane)

    def ctrl_pclk_src(self):
        return self.pclk_sources

    def ctrl_pclk_cands(self):
        return self.pclk_candidates

    def report(self):
        return self.config.report()

    def manifest_base(self):
        return {
            "schema_version": 1,
            "generation_key": self.generation_key,
            "config_hash": self.config_hash,
            "options": self.options.manifest_dict(),
            "design": {
                "lane_count": self.lane_count,
                "mode_count": len(self.modes),
                "controller_count": self.num_ctrl,
                "group_count": len(self.groups),
            },
        }
