"""Register definitions independent of file formats and RTL backends."""
from dataclasses import dataclass, field


@dataclass(frozen=True)
class Field:
    name: str
    msb: int
    lsb: int
    reset: int
    access: str
    description: str = ""
    row: int = 0

    @property
    def width(self):
        return self.msb - self.lsb + 1

    @property
    def reserved(self):
        return self.name.lower() == "reserved"

    @property
    def bits(self):
        return f"[{self.msb}:{self.lsb}]" if self.width > 1 else f"[{self.lsb}]"



@dataclass
class Register:
    offset: int
    fields: list[Field] = field(default_factory=list)
