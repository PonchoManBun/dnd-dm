# 17 — Audio & TTS

## Sound Design Philosophy

Audio in TWW reinforces the tavern-to-dungeon contrast. Sound cues provide gameplay feedback (hit confirmation, death, item pickup, level transitions). All audio is currently **procedural** — synthesized at runtime via `AudioStreamGenerator`, not loaded from pre-made audio files.

## Audio Manager

The `AudioManager` class (`game/src/audio_manager.gd`) is registered as the `Audio` autoload. It:

- Creates a pool of 4 `AudioStreamPlayer` nodes to allow overlapping sounds
- Connects to `World` signals: `effect_occurred`, `turn_started`, `map_changed`, `game_ended`
- Generates sounds procedurally using simple waveform synthesis (sine waves, noise)
- Operates at 22,050 Hz sample rate
- Has a `master_volume` control (default 0.5, deliberately quiet for placeholder sounds)

## Sound Effects (All Procedural)

Every sound is generated at runtime as a `PackedVector2Array` of stereo frames, pushed into an `AudioStreamGenerator`:

| Sound | Trigger | Duration | Description |
|-------|---------|----------|-------------|
| **Step** | Player moves | 50ms | Low-frequency pulse (80 Hz sine), linear decay, quiet |
| **Hit** | Attack/hit effects | 100ms | Mid-frequency (220 Hz sine) mixed with noise, exponential decay |
| **Death** | Death effect or game end | 500ms | Descending tone from 440 Hz to 110 Hz, linear decay |
| **Pickup** | Item pickup effect | 200ms | Two-note ascending chime (C5 then E5), each with linear decay |
| **Door** | Door interaction | 150ms | Low creaky thud (120 Hz sine), linear decay |
| **Combat Start** | Combat mode entered | 150ms | Drum-like thump (60 Hz sine + noise), fast attack/slow decay |
| **Level Change** | Map transition | 300ms | Rising sweep from 200 Hz to 600 Hz, bell-shaped envelope |
| **Tick** | Each turn start | 20ms | Very quiet high-frequency blip (1000 Hz), played at -20 dB |

### Signal-to-Sound Mapping

```
MoveEffect (player)  -> play_step()
AttackEffect         -> play_hit()
HitEffect            -> play_hit()
DeathEffect          -> play_death()
PickupEffect         -> play_pickup()
turn_started         -> _generate_tick() (ambient)
map_changed          -> play_level_change()
game_ended           -> play_death()
```

## Music

**Not implemented.** There are no music files, no tavern music, no combat music, no ambient tracks. The procedural audio system covers only short sound effects.

**Planned:**
- Tavern: upbeat medieval tavern music (lute, fiddle, muffled chatter)
- Dungeon exploration: minimal, tension-building ambient
- Combat: percussive, urgent
- Boss encounters: unique arrangements
- Death: brief, somber motif

## Dice Sounds

**Not implemented.** Dice rolls are displayed as text only. There are no dice-rolling sound effects.

## Text-to-Speech

**Deferred to post-MVP.** No TTS functionality exists. No TTS icon or marker is implemented in the current UI. All narrative text is displayed as written text in the DM panel.

When TTS is eventually added:
- TTS voice will match the selected DM archetype personality
- Clicking a TTS icon on narrative text will play the narration aloud
- All narrative text is already written to sound natural when read aloud
