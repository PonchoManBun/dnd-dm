"""D&D 5e enums and constants, ported from GDScript CharacterData.

All enums use (str, Enum) for clean lowercase JSON serialization.
"""

from __future__ import annotations

from enum import Enum


# ---------------------------------------------------------------------------
# Core enums
# ---------------------------------------------------------------------------


class Race(str, Enum):
    HUMAN = "human"
    ELF = "elf"
    DWARF = "dwarf"
    HALFLING = "halfling"
    HALF_ORC = "half_orc"
    GNOME = "gnome"


class DndClass(str, Enum):
    FIGHTER = "fighter"
    WIZARD = "wizard"
    ROGUE = "rogue"
    CLERIC = "cleric"
    RANGER = "ranger"
    PALADIN = "paladin"


class Ability(str, Enum):
    STRENGTH = "strength"
    DEXTERITY = "dexterity"
    CONSTITUTION = "constitution"
    INTELLIGENCE = "intelligence"
    WISDOM = "wisdom"
    CHARISMA = "charisma"


class Skill(str, Enum):
    ACROBATICS = "acrobatics"
    ANIMAL_HANDLING = "animal_handling"
    ARCANA = "arcana"
    ATHLETICS = "athletics"
    DECEPTION = "deception"
    HISTORY = "history"
    INSIGHT = "insight"
    INTIMIDATION = "intimidation"
    INVESTIGATION = "investigation"
    MEDICINE = "medicine"
    NATURE = "nature"
    PERCEPTION = "perception"
    PERFORMANCE = "performance"
    PERSUASION = "persuasion"
    RELIGION = "religion"
    SLEIGHT_OF_HAND = "sleight_of_hand"
    STEALTH = "stealth"
    SURVIVAL = "survival"


class Condition(str, Enum):
    BLINDED = "blinded"
    CHARMED = "charmed"
    DEAFENED = "deafened"
    FRIGHTENED = "frightened"
    GRAPPLED = "grappled"
    INCAPACITATED = "incapacitated"
    INVISIBLE = "invisible"
    PARALYZED = "paralyzed"
    PETRIFIED = "petrified"
    POISONED = "poisoned"
    PRONE = "prone"
    RESTRAINED = "restrained"
    STUNNED = "stunned"
    UNCONSCIOUS = "unconscious"


class ArmorCategory(str, Enum):
    LIGHT = "light"
    MEDIUM = "medium"
    HEAVY = "heavy"
    SHIELDS = "shields"


class DamageType(str, Enum):
    SLASHING = "slashing"
    PIERCING = "piercing"
    BLUDGEONING = "bludgeoning"
    FIRE = "fire"
    COLD = "cold"
    LIGHTNING = "lightning"
    THUNDER = "thunder"
    POISON = "poison"
    ACID = "acid"
    NECROTIC = "necrotic"
    RADIANT = "radiant"
    FORCE = "force"
    PSYCHIC = "psychic"


class DmArchetype(str, Enum):
    STORYTELLER = "storyteller"
    TASKMASTER = "taskmaster"
    TRICKSTER = "trickster"
    HISTORIAN = "historian"
    GUIDE = "guide"


class ActionType(str, Enum):
    MOVE = "move"
    ATTACK = "attack"
    SPEAK = "speak"
    USE_ITEM = "use_item"
    CAST_SPELL = "cast_spell"
    INTERACT = "interact"
    REST = "rest"
    LOOK = "look"
    CUSTOM = "custom"


# ---------------------------------------------------------------------------
# Constants
# ---------------------------------------------------------------------------

# Maps each skill to its governing ability score.
SKILL_ABILITIES: dict[Skill, Ability] = {
    Skill.ACROBATICS: Ability.DEXTERITY,
    Skill.ANIMAL_HANDLING: Ability.WISDOM,
    Skill.ARCANA: Ability.INTELLIGENCE,
    Skill.ATHLETICS: Ability.STRENGTH,
    Skill.DECEPTION: Ability.CHARISMA,
    Skill.HISTORY: Ability.INTELLIGENCE,
    Skill.INSIGHT: Ability.WISDOM,
    Skill.INTIMIDATION: Ability.CHARISMA,
    Skill.INVESTIGATION: Ability.INTELLIGENCE,
    Skill.MEDICINE: Ability.WISDOM,
    Skill.NATURE: Ability.INTELLIGENCE,
    Skill.PERCEPTION: Ability.WISDOM,
    Skill.PERFORMANCE: Ability.CHARISMA,
    Skill.PERSUASION: Ability.CHARISMA,
    Skill.RELIGION: Ability.INTELLIGENCE,
    Skill.SLEIGHT_OF_HAND: Ability.DEXTERITY,
    Skill.STEALTH: Ability.DEXTERITY,
    Skill.SURVIVAL: Ability.WISDOM,
}

# XP thresholds per level (index 0 = level 1, index 19 = level 20).
XP_THRESHOLDS: list[int] = [
    0, 300, 900, 2700, 6500, 14000, 23000, 34000, 48000, 64000,
    85000, 100000, 120000, 140000, 165000, 195000, 225000, 265000, 305000, 355000,
]


class _RaceInfo:
    """Container for race configuration data."""

    __slots__ = ("name", "ability_bonuses", "speed", "size")

    def __init__(
        self,
        name: str,
        ability_bonuses: dict[Ability, int],
        speed: int,
        size: str,
    ) -> None:
        self.name = name
        self.ability_bonuses = ability_bonuses
        self.speed = speed
        self.size = size


class _ClassInfo:
    """Container for class configuration data."""

    __slots__ = (
        "name",
        "hit_die",
        "primary_ability",
        "saving_throws",
        "armor_proficiencies",
        "num_skills",
        "skill_choices",
    )

    def __init__(
        self,
        name: str,
        hit_die: int,
        primary_ability: Ability,
        saving_throws: list[Ability],
        armor_proficiencies: list[ArmorCategory],
        num_skills: int,
        skill_choices: list[Skill],
    ) -> None:
        self.name = name
        self.hit_die = hit_die
        self.primary_ability = primary_ability
        self.saving_throws = saving_throws
        self.armor_proficiencies = armor_proficiencies
        self.num_skills = num_skills
        self.skill_choices = skill_choices


RACE_DATA: dict[Race, _RaceInfo] = {
    Race.HUMAN: _RaceInfo(
        name="Human",
        ability_bonuses={
            Ability.STRENGTH: 1,
            Ability.DEXTERITY: 1,
            Ability.CONSTITUTION: 1,
            Ability.INTELLIGENCE: 1,
            Ability.WISDOM: 1,
            Ability.CHARISMA: 1,
        },
        speed=30,
        size="Medium",
    ),
    Race.ELF: _RaceInfo(
        name="Elf",
        ability_bonuses={Ability.DEXTERITY: 2},
        speed=30,
        size="Medium",
    ),
    Race.DWARF: _RaceInfo(
        name="Dwarf",
        ability_bonuses={Ability.CONSTITUTION: 2},
        speed=25,
        size="Medium",
    ),
    Race.HALFLING: _RaceInfo(
        name="Halfling",
        ability_bonuses={Ability.DEXTERITY: 2},
        speed=25,
        size="Small",
    ),
    Race.HALF_ORC: _RaceInfo(
        name="Half-Orc",
        ability_bonuses={Ability.STRENGTH: 2, Ability.CONSTITUTION: 1},
        speed=30,
        size="Medium",
    ),
    Race.GNOME: _RaceInfo(
        name="Gnome",
        ability_bonuses={Ability.INTELLIGENCE: 2},
        speed=25,
        size="Small",
    ),
}

CLASS_DATA: dict[DndClass, _ClassInfo] = {
    DndClass.FIGHTER: _ClassInfo(
        name="Fighter",
        hit_die=10,
        primary_ability=Ability.STRENGTH,
        saving_throws=[Ability.STRENGTH, Ability.CONSTITUTION],
        armor_proficiencies=[
            ArmorCategory.LIGHT,
            ArmorCategory.MEDIUM,
            ArmorCategory.HEAVY,
            ArmorCategory.SHIELDS,
        ],
        num_skills=2,
        skill_choices=[
            Skill.ACROBATICS, Skill.ANIMAL_HANDLING, Skill.ATHLETICS,
            Skill.HISTORY, Skill.INSIGHT, Skill.INTIMIDATION,
            Skill.PERCEPTION, Skill.SURVIVAL,
        ],
    ),
    DndClass.WIZARD: _ClassInfo(
        name="Wizard",
        hit_die=6,
        primary_ability=Ability.INTELLIGENCE,
        saving_throws=[Ability.INTELLIGENCE, Ability.WISDOM],
        armor_proficiencies=[],
        num_skills=2,
        skill_choices=[
            Skill.ARCANA, Skill.HISTORY, Skill.INSIGHT,
            Skill.INVESTIGATION, Skill.MEDICINE, Skill.RELIGION,
        ],
    ),
    DndClass.ROGUE: _ClassInfo(
        name="Rogue",
        hit_die=8,
        primary_ability=Ability.DEXTERITY,
        saving_throws=[Ability.DEXTERITY, Ability.INTELLIGENCE],
        armor_proficiencies=[ArmorCategory.LIGHT],
        num_skills=4,
        skill_choices=[
            Skill.ACROBATICS, Skill.ATHLETICS, Skill.DECEPTION,
            Skill.INSIGHT, Skill.INTIMIDATION, Skill.INVESTIGATION,
            Skill.PERCEPTION, Skill.PERFORMANCE, Skill.PERSUASION,
            Skill.SLEIGHT_OF_HAND, Skill.STEALTH,
        ],
    ),
    DndClass.CLERIC: _ClassInfo(
        name="Cleric",
        hit_die=8,
        primary_ability=Ability.WISDOM,
        saving_throws=[Ability.WISDOM, Ability.CHARISMA],
        armor_proficiencies=[
            ArmorCategory.LIGHT, ArmorCategory.MEDIUM, ArmorCategory.SHIELDS,
        ],
        num_skills=2,
        skill_choices=[
            Skill.HISTORY, Skill.INSIGHT, Skill.MEDICINE,
            Skill.PERSUASION, Skill.RELIGION,
        ],
    ),
    DndClass.RANGER: _ClassInfo(
        name="Ranger",
        hit_die=10,
        primary_ability=Ability.DEXTERITY,
        saving_throws=[Ability.STRENGTH, Ability.DEXTERITY],
        armor_proficiencies=[
            ArmorCategory.LIGHT, ArmorCategory.MEDIUM, ArmorCategory.SHIELDS,
        ],
        num_skills=3,
        skill_choices=[
            Skill.ANIMAL_HANDLING, Skill.ATHLETICS, Skill.INSIGHT,
            Skill.INVESTIGATION, Skill.NATURE, Skill.PERCEPTION,
            Skill.STEALTH, Skill.SURVIVAL,
        ],
    ),
    DndClass.PALADIN: _ClassInfo(
        name="Paladin",
        hit_die=10,
        primary_ability=Ability.STRENGTH,
        saving_throws=[Ability.WISDOM, Ability.CHARISMA],
        armor_proficiencies=[
            ArmorCategory.LIGHT, ArmorCategory.MEDIUM, ArmorCategory.HEAVY,
            ArmorCategory.SHIELDS,
        ],
        num_skills=2,
        skill_choices=[
            Skill.ATHLETICS, Skill.INSIGHT, Skill.INTIMIDATION,
            Skill.MEDICINE, Skill.PERSUASION, Skill.RELIGION,
        ],
    ),
}
