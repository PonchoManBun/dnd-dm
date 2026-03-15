# 17 — Audio & TTS

## Sound Design Philosophy

Audio in TWW reinforces the tavern-to-dungeon contrast. The tavern is warm and lively. Dungeons are oppressive and sparse. Sound cues provide critical gameplay information (combat alerts, trap triggers, ambient danger).

## Music

- **Tavern** — Upbeat medieval tavern music. Lute, fiddle, muffled chatter. Feels safe.
- **Overworld travel** — Ambient, atmospheric. Varies by region and time of day.
- **Dungeon exploration** — Minimal, tension-building. Low drones, distant drips, occasional stingers.
- **Combat** — Percussive, urgent. Tempo increases with danger.
- **Boss encounters** — Unique arrangements per boss type (or DM-selected from a themed pool).
- **Death** — A brief, somber motif. Then silence before the eulogy.

Music sourced from open-license libraries (OpenGameArt, Pixabay, or similar).

## Sound Effects

- **UI** — Menu navigation, item pickup, inventory management
- **Combat** — Sword swings, spell impacts, shield blocks, critical hits
- **Environment** — Doors, chests, traps, water, fire, footsteps on different surfaces
- **Dice** — Physical dice-rolling sounds synchronized with the animated dice in the DM panel
- **Ambient** — Dungeon atmosphere, tavern chatter, wind, rain

## Text-to-Speech (Deferred)

TTS is planned but **deferred to post-MVP**. Current implementation:

- DM narrative text that would be voiced is marked with a **TTS icon** (speaker symbol)
- The icon is non-functional in MVP — it serves as a visual marker for future implementation
- When TTS is added, clicking the icon will play the narration aloud
- TTS voice will match the selected DM archetype personality

All narrative design assumes TTS will eventually exist — text is written to sound natural when read aloud.
