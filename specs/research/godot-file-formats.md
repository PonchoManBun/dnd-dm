# Godot 4 File Formats: Analysis for AI Content Generation

## Overview

Godot 4 uses three primary text-based file formats. All are designed to be human-readable and version-control-friendly.

| Format | Purpose | AI Generation Reliability |
|--------|---------|--------------------------|
| `.gd` | GDScript behavior scripts | **HIGH** |
| `.tres` | Resource files (data) | **HIGH** |
| `.tscn` | Scene files (node trees) | **MODERATE** |

---

## 1. .tscn (Scene Files)

### Format Structure

TSCN files use `format=3` in Godot 4. Five sections in strict order:

1. **File descriptor** (header)
2. **External resources** (`ext_resource`)
3. **Internal resources** (`sub_resource`)
4. **Nodes** (`node`)
5. **Connections** (`connection`)

### Example

```
[gd_scene format=3 uid="uid://cecaux1sm7mo0"]

[ext_resource type="Script" path="res://player.gd" id="1_abc"]

[sub_resource type="CircleShape2D" id="CircleShape2D_xyz"]
radius = 16.0

[node name="Player" type="CharacterBody2D"]
script = ExtResource("1_abc")

[node name="Collision" type="CollisionShape2D" parent="."]
shape = SubResource("CircleShape2D_xyz")

[connection signal="body_entered" from="Area2D" to="." method="_on_body_entered"]
```

### Key Rules
- Root node has no `parent` attribute
- Direct children use `parent="."`
- Deeper children use paths: `parent="Arm/Hand"`
- Only non-default property values are stored
- UIDs can be omitted -- Godot will generate them on first save
- Resource IDs just need internal consistency

### TileMap Data: The Major Limitation

TileMap data is stored as a `PackedByteArray` -- **opaque binary**, not human-readable:

```
[node name="TileMapLayer" type="TileMapLayer" parent="."]
tile_map_data = PackedByteArray(0, 0, 0, 0, 0, 0, 1, 0, ...)
```

**Claude cannot generate tilemap binary data.** Solution: store level layouts as JSON grids and use GDScript `set_cell()` calls at runtime.

### AI Editability: MODERATE

- **Can generate:** Simple scene trees, node hierarchy, standard properties, signal connections, external resource references
- **Cannot generate:** TileMap binary data, mesh data, PackedByteArrays, vertex arrays

---

## 2. .tres (Resource Files)

### Format Structure

Nearly identical to `.tscn` but uses `gd_resource` header and a `[resource]` section:

```
[gd_resource type="Resource" script_class="MonsterStats" format=3 uid="uid://xyz789"]

[ext_resource type="Script" path="res://scripts/monster_stats.gd" id="1_abc"]

[resource]
script = ExtResource("1_abc")
name = "Goblin"
max_hp = 7
armor_class = 15
attack_bonus = 4
damage_dice = "1d6+2"
speed = 30
challenge_rating = 0.25
abilities = { "str": 8, "dex": 14, "con": 10, "int": 10, "wis": 8, "cha": 8 }
```

### Custom Resources

Backed by GDScript classes extending `Resource`:

```gdscript
class_name MonsterStats
extends Resource

@export var name: String
@export var max_hp: int
@export var armor_class: int
@export var attack_bonus: int
@export var damage_dice: String
@export var speed: int
@export var challenge_rating: float
@export var abilities: Dictionary
```

### Advantages Over JSON for Game Data
- Type-safe via `@export` annotations
- Editor-friendly (Inspector UI widgets)
- Auto-serialized (no custom save/load code)
- Nestable (loot table -> items -> effects)
- Memory-efficient (loaded once, shared instances)
- Converted to binary `.res` on export for speed

### AI Editability: HIGH

This is Claude's **sweet spot**. Game data resources are structured text with known property names and types. Claude can generate monster stats, items, loot tables, dialogue trees, and spell data extremely reliably.

---

## 3. .gd (GDScript Files)

### Syntax Overview

Python-like, indentation-based, tightly integrated with Godot:

```gdscript
class_name SimpleNPC
extends CharacterBody2D

signal spoke(dialogue_text: String)

enum AIState { IDLE, PATROL, TALK, FLEE }

@export var npc_name: String = "Villager"
@export var patrol_speed: float = 50.0

var current_state: AIState = AIState.IDLE

@onready var sprite = $AnimatedSprite2D

func _physics_process(delta: float):
    match current_state:
        AIState.IDLE:
            sprite.play("idle")
        AIState.PATROL:
            _do_patrol(delta)
    move_and_slide()
```

### State Machine Patterns

**Simple (enum + match):**
```gdscript
enum States { IDLE, RUNNING, JUMPING }
var state: States = States.IDLE

func _physics_process(delta):
    match state:
        States.IDLE: ...
        States.RUNNING: ...
```

**Node-based (scalable):**
```gdscript
class_name State extends Node
signal finished(next_state_path: String, data: Dictionary)
func enter(previous_state_path: String, data := {}) -> void: pass
func exit() -> void: pass
func update(_delta: float) -> void: pass
```

### AI Editability: HIGH

GDScript is one of the **most AI-friendly** scripting languages. Concise, minimal boilerplate, Python-like syntax. Claude can reliably generate complete classes, state machines, signal connections, and game logic.

---

## 4. Recommended Hybrid Approach for AI-Generated Content

| Content Type | Format | Why |
|-------------|--------|-----|
| Dynamic content (encounters, loot, dialogue) | **JSON** | Claude generates reliably; loaded at runtime |
| Static game data (base stats, item defs, spells) | **.tres** | Type-safe, editor-friendly, Claude generates well |
| Game logic, AI behavior, state machines | **.gd** | Claude's strongest format |
| UI layouts, node structure | **.tscn** | Claude can generate simple scenes |
| Level layouts / tilemaps | **JSON grid -> GDScript loader** | Avoids binary PackedByteArray |

### JSON Loading in Godot

```gdscript
func load_monster_data(path: String) -> Dictionary:
    var file = FileAccess.open(path, FileAccess.READ)
    var data = JSON.parse_string(file.get_as_text())
    return data
```

### Level Data as JSON (instead of binary tilemap)

```json
{
  "width": 32, "height": 32,
  "tiles": [
    [1, 1, 1, 0, 0, 1, 1, 1],
    [1, 0, 0, 0, 0, 0, 0, 1],
    ...
  ],
  "rooms": [
    {"x": 5, "y": 3, "w": 8, "h": 6, "type": "boss"},
    ...
  ]
}
```

GDScript loader calls `set_cell()` for each tile at runtime.

---

## 5. Content Directory Conventions

### Recommended Structure

```
project.godot
/scenes/
    /player/
        player.tscn, player.gd
    /enemies/
        goblin/goblin.tscn, goblin.gd
    /levels/
        dungeon_01.tscn
/scripts/
    game_manager.gd
    combat_system.gd
/resources/
    /items/      (sword.tres, potion.tres)
    /monsters/   (goblin_stats.tres)
    /loot_tables/
/assets/
    /sprites/
    /tilesets/
    /audio/
/data/
    monsters.json
    items.json
    dialogue.json
/forge_output/    # Claude-generated content lands here
    /dungeons/
    /encounters/
```

### Naming Conventions
- `snake_case` for all files and folders
- PascalCase for node names
- `res://` prefix for all resource paths
- `.gdignore` file to exclude folders from import

### Hot-Reloading
- **Scripts:** Detected when editor regains focus
- **Resources (.tres):** Reloaded when editor regains focus or `ResourceLoader.load()` called
- **Scenes (.tscn):** Detected but running instances NOT auto-updated
- **Exported games:** No automatic hot-reload. Must explicitly reload via `ResourceLoader` or polling mechanism.

For an AI Forge workflow: Claude writes files to `forge_output/`, a GDScript polling mechanism detects changes and loads new content.
