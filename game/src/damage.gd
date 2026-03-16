class_name Damage
extends RefCounted

## D&D 5e damage types. Kept backward-compatible with existing code
## (BLUNT→BLUDGEONING, PIERCE→PIERCING, SLASH→SLASHING, SAW removed).

enum Type {
	# Physical
	BLUDGEONING,
	PIERCING,
	SLASHING,
	# Elemental
	ACID,
	COLD,
	FIRE,
	LIGHTNING,
	THUNDER,
	# Magical
	FORCE,
	NECROTIC,
	POISON,
	PSYCHIC,
	RADIANT,
}

# Ammo types - see also item_factory.gd
enum AmmoType {
	NONE,
	ARROW,
	BOLT,
}

# Aliases for backward compatibility with existing CSV/code that uses old names
const BLUNT := Type.BLUDGEONING
const PIERCE := Type.PIERCING
const SLASH := Type.SLASHING
const SAW := Type.SLASHING  # SAW mapped to SLASHING

static func type_to_string(type: Type) -> String:
	match type:
		Type.BLUDGEONING: return "bludgeoning"
		Type.PIERCING: return "piercing"
		Type.SLASHING: return "slashing"
		Type.ACID: return "acid"
		Type.COLD: return "cold"
		Type.FIRE: return "fire"
		Type.LIGHTNING: return "lightning"
		Type.THUNDER: return "thunder"
		Type.FORCE: return "force"
		Type.NECROTIC: return "necrotic"
		Type.POISON: return "poison"
		Type.PSYCHIC: return "psychic"
		Type.RADIANT: return "radiant"
	Log.e("Invalid damage type: %s" % type)
	return "unknown"


static func string_to_type(s: String) -> Type:
	match s.to_lower():
		"bludgeoning", "blunt": return Type.BLUDGEONING
		"piercing", "pierce": return Type.PIERCING
		"slashing", "slash", "saw": return Type.SLASHING
		"acid": return Type.ACID
		"cold": return Type.COLD
		"fire": return Type.FIRE
		"lightning": return Type.LIGHTNING
		"thunder": return Type.THUNDER
		"force": return Type.FORCE
		"necrotic": return Type.NECROTIC
		"poison": return Type.POISON
		"psychic": return Type.PSYCHIC
		"radiant": return Type.RADIANT
	Log.e("Invalid damage type string: %s" % s)
	return Type.BLUDGEONING


static func ammo_type_to_string(ammo_type: AmmoType) -> String:
	match ammo_type:
		AmmoType.NONE: return "none"
		AmmoType.ARROW: return "arrow"
		AmmoType.BOLT: return "bolt"
	Log.e("Invalid ammo type: %s" % ammo_type)
	return "unknown"
