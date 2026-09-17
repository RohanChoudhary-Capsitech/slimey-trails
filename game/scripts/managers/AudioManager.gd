class_name AudioManager
extends Node

# AudioManager — music and pooled SFX playback
# PDF §4 CPU: idle SFX pool players have process_mode = DISABLED.
#   Re-enabled on play(), disabled again when playback finishes.
# PDF §6 SOLID: one job — audio. Volume/mute only. No game logic here.

var _music_player: AudioStreamPlayer
var _sfx_pool:     Array[AudioStreamPlayer] = []

const _POOL_SIZE := 8

func _ready() -> void:
	ServiceLocator.register(&"AudioManager", self)
	_setup_music_player()
	_setup_sfx_pool()

# ── Music ──────────────────────────────────────────────────────────────────

func play_music(stream: AudioStream, volume_db: float = 0.0) -> void:
	_music_player.stream    = stream
	_music_player.volume_db = volume_db
	_music_player.play()

func stop_music() -> void:
	_music_player.stop()

func set_music_volume(linear: float) -> void:
	_music_player.volume_db = linear_to_db(clampf(linear, 0.0, 1.0))

# ── SFX ───────────────────────────────────────────────────────────────────

func play_sfx(stream: AudioStream, volume_db: float = 0.0) -> void:
	var player := _get_free_sfx_player()
	if player == null:
		return
	# PDF §4: re-enable before playing
	player.process_mode = Node.PROCESS_MODE_INHERIT
	player.stream       = stream
	player.volume_db    = volume_db
	player.play()

func set_sfx_volume(linear: float) -> void:
	var db := linear_to_db(clampf(linear, 0.0, 1.0))
	for p in _sfx_pool:
		p.volume_db = db

# ── Global mute ───────────────────────────────────────────────────────────

func mute(muted: bool) -> void:
	AudioServer.set_bus_mute(AudioServer.get_bus_index("Master"), muted)

# ── Setup ─────────────────────────────────────────────────────────────────

func _setup_music_player() -> void:
	_music_player = AudioStreamPlayer.new()
	_music_player.bus = "Master"
	add_child(_music_player)

func _setup_sfx_pool() -> void:
	var bus := "SFX" if AudioServer.get_bus_index("SFX") >= 0 else "Master"
	for i in _POOL_SIZE:
		var p := AudioStreamPlayer.new()
		p.bus = bus
		# PDF §4: all pool players start disabled — zero CPU cost until needed
		p.process_mode = Node.PROCESS_MODE_DISABLED
		p.finished.connect(_on_sfx_finished.bind(p))
		add_child(p)
		_sfx_pool.append(p)

# ── Internals ─────────────────────────────────────────────────────────────

func _get_free_sfx_player() -> AudioStreamPlayer:
	# PDF §6 Time Complexity: O(n) scan on pool of 8 — acceptable fixed size
	for p in _sfx_pool:
		if not p.playing:
			return p
	# Logger.warn("AudioManager: SFX pool exhausted")
	return null

func _on_sfx_finished(player: AudioStreamPlayer) -> void:
	# PDF §4: disable the player once done — no idle CPU ticking
	player.process_mode = Node.PROCESS_MODE_DISABLED
