class_name SaveManager
extends Node

# SaveManager — local encrypted save with O(1) in-memory cache
# PDF §6 Time Complexity: all reads are O(1) Dictionary lookups against
#   _data — disk is only touched on explicit load_local() / save_local().
# PDF §6 SOLID: one job — local persistence. Cloud sync lives in NetworkManager.

const _SAVE_PATH := "user://save.dat"
const _SAVE_KEY  := "CHANGE_THIS_KEY"   # TODO: replace before shipping

# PDF §6: in-memory cache — O(1) get/set after initial load
var _data:  Dictionary = {}
var _dirty: bool       = false

func _ready() -> void:
	ServiceLocator.register(&"SaveManager", self)
	load_local()   # warm cache once at startup

# ── Read / Write (all O(1) — in-memory only) ──────────────────────────────

func set_value(key: String, value: Variant) -> void:
	_data[key] = value
	_dirty = true

func get_value(key: String, default: Variant = null) -> Variant:
	return _data.get(key, default)   # O(1) Dictionary lookup

func has(key: String) -> bool:
	return _data.has(key)            # O(1)

func has_unsaved_changes() -> bool:
	return _dirty

# ── Persistence (disk I/O — call explicitly, never per-frame) ─────────────

func save_local() -> void:
	# PDF §6: build ConfigFile in one pass — O(n) over keys, written once
	var file := ConfigFile.new()
	for key in _data:
		file.set_value("save", key, _data[key])
	var err := file.save_encrypted_pass(_SAVE_PATH, _SAVE_KEY)
	if err != OK:
		# Logger.error("SaveManager: local save failed", { "err": err })
		return
	_dirty = false
	# Logger.info("Saved locally", { "keys": _data.size() })

func load_local() -> void:
	var file := ConfigFile.new()
	var err   := file.load_encrypted_pass(_SAVE_PATH, _SAVE_KEY)
	if err != OK:
		# Logger.info("SaveManager: no save found, starting fresh")
		return
	# PDF §6: single pass load into Dictionary — subsequent reads are O(1)
	for key in file.get_section_keys("save"):
		_data[key] = file.get_value("save", key)
	# Logger.info("Save loaded", { "keys": _data.size() })

func clear() -> void:
	_data.clear()
	_dirty = false
	DirAccess.remove_absolute(_SAVE_PATH)
	# Logger.info("SaveManager: save cleared")
