"""Simplified equipment model for LLM prompt context and rules lookups."""

from __future__ import annotations

from dataclasses import dataclass, field


# Cost conversion to gp
_COST_TO_GP: dict[str, float] = {
    "cp": 0.01,
    "sp": 0.1,
    "ep": 0.5,
    "gp": 1.0,
    "pp": 10.0,
}


@dataclass(frozen=True)
class EquipmentInfo:
    """Simplified 5e equipment for prompt context and rules resolution."""

    index: str
    name: str
    category: str
    cost_gp: float
    weight: float
    description: str
    damage_dice: str | None = None
    damage_type: str | None = None
    armor_class: int | None = None
    properties: list[str] = field(default_factory=list)

    def summary(self) -> str:
        """One-line summary for LLM context."""
        parts = [f"{self.name} — {self.category}"]
        if self.damage_dice:
            parts.append(f"{self.damage_dice} {self.damage_type or ''}")
        if self.armor_class is not None:
            parts.append(f"AC {self.armor_class}")
        if self.cost_gp > 0:
            parts.append(f"{self.cost_gp} gp")
        if self.weight > 0:
            parts.append(f"{self.weight} lb")
        return ", ".join(parts)


@dataclass(frozen=True)
class MagicItemInfo:
    """Simplified 5e magic item for prompt context."""

    index: str
    name: str
    category: str
    rarity: str
    description: str

    def summary(self) -> str:
        """One-line summary for LLM context."""
        return f"{self.name} — {self.category}, {self.rarity}"


def parse_equipment(raw: dict) -> EquipmentInfo:
    """Convert a 5e-database equipment entry to our simplified model."""
    # Category from equipment_category
    cat_obj = raw.get("equipment_category", {})
    category = cat_obj.get("name", "Unknown")

    # Cost conversion to gp
    cost_gp = 0.0
    cost = raw.get("cost")
    if cost:
        quantity = cost.get("quantity", 0)
        unit = cost.get("unit", "gp")
        cost_gp = quantity * _COST_TO_GP.get(unit, 1.0)

    weight = raw.get("weight", 0.0)

    # Damage info (weapons)
    damage_dice: str | None = None
    damage_type: str | None = None
    damage = raw.get("damage")
    if damage:
        damage_dice = damage.get("damage_dice")
        dt = damage.get("damage_type")
        if dt:
            damage_type = dt.get("name")

    # Armor class (armor)
    armor_class: int | None = None
    ac_obj = raw.get("armor_class")
    if ac_obj:
        armor_class = ac_obj.get("base")

    # Properties (weapons)
    properties = [p.get("name", "") for p in raw.get("properties", [])]

    # Description — equipment doesn't always have desc; build from category info
    desc_parts = raw.get("desc", [])
    description = " ".join(desc_parts) if desc_parts else ""

    return EquipmentInfo(
        index=raw.get("index", ""),
        name=raw.get("name", ""),
        category=category,
        cost_gp=cost_gp,
        weight=weight,
        description=description,
        damage_dice=damage_dice,
        damage_type=damage_type,
        armor_class=armor_class,
        properties=properties,
    )


def parse_magic_item(raw: dict) -> MagicItemInfo:
    """Convert a 5e-database magic item entry to our simplified model."""
    cat_obj = raw.get("equipment_category", {})
    category = cat_obj.get("name", "Unknown")

    rarity_obj = raw.get("rarity", {})
    rarity = rarity_obj.get("name", "Unknown")

    desc_parts = raw.get("desc", [])
    description = " ".join(desc_parts) if desc_parts else ""

    return MagicItemInfo(
        index=raw.get("index", ""),
        name=raw.get("name", ""),
        category=category,
        rarity=rarity,
        description=description,
    )
