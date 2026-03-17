"""Simplified spell model for LLM prompt context and rules lookups."""

from __future__ import annotations

from dataclasses import dataclass, field


@dataclass(frozen=True)
class SpellInfo:
    """Simplified 5e spell for prompt context and rules resolution."""

    index: str
    name: str
    level: int
    school: str
    casting_time: str
    range: str
    duration: str
    concentration: bool
    description: str
    classes: list[str] = field(default_factory=list)
    damage_type: str | None = None
    damage_dice: str | None = None

    def summary(self) -> str:
        """One-line summary for LLM context."""
        conc = " (concentration)" if self.concentration else ""
        level_str = "Cantrip" if self.level == 0 else f"Level {self.level}"
        return (
            f"{self.name} — {level_str} {self.school}{conc}, "
            f"{self.casting_time}, {self.range}, {self.duration}"
        )


def parse_spell(raw: dict) -> SpellInfo:
    """Convert a 5e-database spell entry to our simplified model."""
    # Extract damage info if present
    damage_type: str | None = None
    damage_dice: str | None = None
    damage = raw.get("damage")
    if damage:
        dt = damage.get("damage_type")
        if dt:
            damage_type = dt.get("name")
        # Prefer slot-level damage at the spell's own level, else character-level
        slot_dmg = damage.get("damage_at_slot_level")
        char_dmg = damage.get("damage_at_character_level")
        if slot_dmg:
            level_key = str(raw.get("level", 0))
            damage_dice = slot_dmg.get(level_key) or next(iter(slot_dmg.values()), None)
        elif char_dmg:
            damage_dice = char_dmg.get("1") or next(iter(char_dmg.values()), None)

    # Join description paragraphs
    desc_parts = raw.get("desc", [])
    description = " ".join(desc_parts) if desc_parts else ""

    # Extract class names
    classes = [c["name"] for c in raw.get("classes", [])]

    # School name
    school_obj = raw.get("school", {})
    school = school_obj.get("name", "Unknown")

    return SpellInfo(
        index=raw.get("index", ""),
        name=raw.get("name", ""),
        level=raw.get("level", 0),
        school=school,
        casting_time=raw.get("casting_time", ""),
        range=raw.get("range", ""),
        duration=raw.get("duration", ""),
        concentration=raw.get("concentration", False),
        description=description,
        classes=classes,
        damage_type=damage_type,
        damage_dice=damage_dice,
    )
