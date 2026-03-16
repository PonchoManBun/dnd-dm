class_name AudioManager
extends Node

## Minimal procedural audio manager. Connects to World signals and plays
## simple synthesized placeholder sounds via AudioStreamGenerator.
##
## Registered as the "Audio" autoload in project.godot.

## Master volume (0.0 = silent, 1.0 = full).  Default is deliberately quiet
## because these are rough procedural placeholders.
var master_volume: float = 0.5

## Internal players — we keep a small pool so overlapping sounds don't cut
## each other off.
var _players: Array[AudioStreamPlayer] = []
const PLAYER_COUNT: int = 4
const SAMPLE_RATE: float = 22050.0
const MIX_RATE: int = 22050


func _ready() -> void:
	# Create the player pool
	for i in range(PLAYER_COUNT):
		var player := AudioStreamPlayer.new()
		player.bus = "Master"
		add_child(player)
		_players.append(player)

	# Connect to World signals (World is an autoload, guaranteed to exist)
	World.effect_occurred.connect(_on_effect_occurred)
	World.turn_started.connect(_on_turn_started)
	World.map_changed.connect(_on_map_changed)
	World.game_ended.connect(_on_game_ended)


# ── Signal handlers ──────────────────────────────────────────────────────

func _on_effect_occurred(effect: ActionEffect) -> void:
	if effect is MoveEffect:
		if effect.target == World.player:
			play_step()
	elif effect is AttackEffect:
		play_hit()
	elif effect is HitEffect:
		play_hit()
	elif effect is DeathEffect:
		play_death()
	elif effect is PickupEffect:
		play_pickup()


func _on_turn_started() -> void:
	# Subtle ambient tick each turn — very quiet
	_play_buffer(_generate_tick(), -20.0)


func _on_map_changed(_map: Map) -> void:
	play_level_change()


func _on_game_ended() -> void:
	play_death()


# ── Public API ───────────────────────────────────────────────────────────

func play_step() -> void:
	_play_buffer(_generate_step(), -16.0)


func play_hit() -> void:
	_play_buffer(_generate_hit(), -10.0)


func play_death() -> void:
	_play_buffer(_generate_death(), -8.0)


func play_pickup() -> void:
	_play_buffer(_generate_pickup(), -10.0)


func play_door() -> void:
	_play_buffer(_generate_door(), -10.0)


func play_combat_start() -> void:
	_play_buffer(_generate_combat_start(), -8.0)


func play_level_change() -> void:
	_play_buffer(_generate_level_change(), -10.0)


# ── Playback helpers ─────────────────────────────────────────────────────

## Pick the first idle player (or the oldest one) and play a buffer on it.
func _play_buffer(buffer: PackedVector2Array, volume_db: float) -> void:
	if master_volume <= 0.0:
		return

	var player := _get_available_player()
	# Build a fresh generator stream each time
	var stream := AudioStreamGenerator.new()
	stream.mix_rate = SAMPLE_RATE
	# Buffer length in seconds — enough for our longest sound (death ~0.5s) plus margin
	stream.buffer_length = 1.0

	player.stream = stream
	# Apply master volume as additional dB offset
	player.volume_db = volume_db + linear_to_db(master_volume)
	player.play()

	# Push frames into the playback
	var playback := player.get_stream_playback() as AudioStreamGeneratorPlayback
	if playback:
		for frame in buffer:
			if playback.can_push_buffer(1):
				playback.push_frame(frame)


func _get_available_player() -> AudioStreamPlayer:
	# Prefer a player that isn't currently playing
	for player in _players:
		if not player.playing:
			return player
	# All busy — reuse the first one
	_players[0].stop()
	return _players[0]


# ── Sound generators ─────────────────────────────────────────────────────
# Each returns a PackedVector2Array of stereo frames at SAMPLE_RATE Hz.

## Step: short quiet click — 50ms, low-frequency pulse.
func _generate_step() -> PackedVector2Array:
	var frames := int(SAMPLE_RATE * 0.05)
	var buf := PackedVector2Array()
	buf.resize(frames)
	for i in range(frames):
		var t := float(i) / SAMPLE_RATE
		var envelope := 1.0 - (float(i) / float(frames))  # linear decay
		var sample := sin(TAU * 80.0 * t) * envelope * 0.3
		buf[i] = Vector2(sample, sample)
	return buf


## Hit: short noise burst — 100ms, mid frequency with noise.
func _generate_hit() -> PackedVector2Array:
	var frames := int(SAMPLE_RATE * 0.1)
	var buf := PackedVector2Array()
	buf.resize(frames)
	for i in range(frames):
		var t := float(i) / SAMPLE_RATE
		var envelope := 1.0 - (float(i) / float(frames))
		envelope *= envelope  # exponential-ish decay
		var noise := randf_range(-1.0, 1.0)
		var tone := sin(TAU * 220.0 * t)
		var sample := (tone * 0.4 + noise * 0.6) * envelope * 0.4
		buf[i] = Vector2(sample, sample)
	return buf


## Death: descending tone — 500ms.
func _generate_death() -> PackedVector2Array:
	var frames := int(SAMPLE_RATE * 0.5)
	var buf := PackedVector2Array()
	buf.resize(frames)
	for i in range(frames):
		var t := float(i) / SAMPLE_RATE
		var progress := float(i) / float(frames)
		var envelope := 1.0 - progress
		# Descend from 440 Hz to 110 Hz
		var freq := lerpf(440.0, 110.0, progress)
		var sample := sin(TAU * freq * t) * envelope * 0.35
		buf[i] = Vector2(sample, sample)
	return buf


## Pickup: ascending two-note chime — 200ms total.
func _generate_pickup() -> PackedVector2Array:
	var frames := int(SAMPLE_RATE * 0.2)
	var buf := PackedVector2Array()
	buf.resize(frames)
	var half := frames / 2
	for i in range(frames):
		var t := float(i) / SAMPLE_RATE
		var local_progress: float
		var freq: float
		if i < half:
			local_progress = float(i) / float(half)
			freq = 523.25  # C5
		else:
			local_progress = float(i - half) / float(half)
			freq = 659.25  # E5
		var envelope := 1.0 - local_progress
		var sample := sin(TAU * freq * t) * envelope * 0.3
		buf[i] = Vector2(sample, sample)
	return buf


## Door: low creaky thud — 150ms.
func _generate_door() -> PackedVector2Array:
	var frames := int(SAMPLE_RATE * 0.15)
	var buf := PackedVector2Array()
	buf.resize(frames)
	for i in range(frames):
		var t := float(i) / SAMPLE_RATE
		var envelope := 1.0 - (float(i) / float(frames))
		var sample := sin(TAU * 120.0 * t) * envelope * 0.35
		buf[i] = Vector2(sample, sample)
	return buf


## Combat start: drum-like thump — 150ms, quick attack.
func _generate_combat_start() -> PackedVector2Array:
	var frames := int(SAMPLE_RATE * 0.15)
	var buf := PackedVector2Array()
	buf.resize(frames)
	for i in range(frames):
		var t := float(i) / SAMPLE_RATE
		var progress := float(i) / float(frames)
		# Fast attack, slow decay
		var envelope: float
		if progress < 0.05:
			envelope = progress / 0.05
		else:
			envelope = 1.0 - ((progress - 0.05) / 0.95)
		envelope *= envelope
		# Low thump with slight noise
		var tone := sin(TAU * 60.0 * t)
		var noise := randf_range(-1.0, 1.0)
		var sample := (tone * 0.7 + noise * 0.3) * envelope * 0.5
		buf[i] = Vector2(sample, sample)
	return buf


## Level change: short rising sweep — 300ms.
func _generate_level_change() -> PackedVector2Array:
	var frames := int(SAMPLE_RATE * 0.3)
	var buf := PackedVector2Array()
	buf.resize(frames)
	for i in range(frames):
		var t := float(i) / SAMPLE_RATE
		var progress := float(i) / float(frames)
		var envelope := sin(progress * PI)  # bell-shaped
		# Sweep from 200 Hz to 600 Hz
		var freq := lerpf(200.0, 600.0, progress)
		var sample := sin(TAU * freq * t) * envelope * 0.25
		buf[i] = Vector2(sample, sample)
	return buf


## Tick: very short, very quiet blip — 20ms.
func _generate_tick() -> PackedVector2Array:
	var frames := int(SAMPLE_RATE * 0.02)
	var buf := PackedVector2Array()
	buf.resize(frames)
	for i in range(frames):
		var t := float(i) / SAMPLE_RATE
		var envelope := 1.0 - (float(i) / float(frames))
		var sample := sin(TAU * 1000.0 * t) * envelope * 0.08
		buf[i] = Vector2(sample, sample)
	return buf
