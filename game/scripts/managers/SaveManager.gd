class_name SaveManager
extends Node

## SaveManager — Core Game-Facing Save Facade (GameService.save)
##
## Acts as the clean bridge between gameplay scripts and the backend 13-bucket
## Unified Game Data Model. Manages disk persistence, in-memory cache clearing,
## transactions, and cloud synchronization.
##
## Devs can access buckets directly (`save.economy.get_economy_data()`) or add
## their own game-specific shortcut methods here.

var _dm: Node:
	get:
		var tree = Engine.get_main_loop() as SceneTree
		if tree and tree.root:
			var bs = tree.root.get_node_or_null("BackendService")
			if bs and bs.data:
				return bs.data
			return tree.root.get_node_or_null("DataManager")
		return null

# ==============================================================================
# 📦 TYPED REPOSITORY ACCESSORS (13 Domain Buckets)
# ==============================================================================

var identity: IdentityRepository:
	get: return _dm.identity_repo if _dm else null

var profile: ProfileRepository:
	get: return _dm.profile_repo if _dm else null

var device: DeviceRepository:
	get: return _dm.device_repo if _dm else null

var metadata: MetadataRepository:
	get: return _dm.metadata_repo if _dm else null

var session: SessionRepository:
	get: return _dm.session_repo if _dm else null

var settings: SettingsRepository:
	get: return _dm.settings_repo if _dm else null

var progression: ProgressionRepository:
	get: return _dm.progression_repo if _dm else null

var economy: EconomyRepository:
	get: return _dm.economy_repo if _dm else null

var inventory: InventoryRepository:
	get: return _dm.inventory_repo if _dm else null

var live_ops: LiveOpsRepository:
	get: return _dm.live_ops_repo if _dm else null

var stats: StatsRepository:
	get: return _dm.stats_repo if _dm else null

var tutorials: TutorialsRepository:
	get: return _dm.tutorials_repo if _dm else null

var monetization: MonetizationRepository:
	get: return _dm.monetization_repo if _dm else null

func _ready() -> void:
	_log_info("SaveManager initialized (backed by DataManager)")

# ==============================================================================
# 💾 PERSISTENCE & STORAGE LIFECYCLE
# ==============================================================================

## Saves all dirty repositories to local disk (user://saves/).
func save_game() -> DataResult:
	if _dm:
		var res: DataResult = _dm.save()
		if res.success:
			_log_info("SaveManager: Game saved successfully")
		else:
			_log_error("SaveManager: Save failed: " + res.error_message)
		return res
	return null

## Reloads local save files from disk into active memory caches.
func load_game() -> DataResult:
	if _dm:
		var res: DataResult = _dm.load_local_data()
		if res.success:
			_log_info("SaveManager: Game loaded successfully")
		else:
			_log_warn("SaveManager: Load result: " + res.error_message)
		return res
	return null

## Wipes all in-memory caches and clears local save files from disk.
func clear_all() -> void:
	if _dm:
		_dm.clear_local()
		_log_info("SaveManager: Cleared all local data")

## Explicitly triggers a 2-way cloud synchronization.
func sync_cloud() -> DataResult:
	if _dm:
		return await _dm.sync()
	return null

## Returns true if any in-memory repository has unsaved changes.
func has_unsaved_changes() -> bool:
	if _dm:
		for name in _dm._repos_map:
			var repo = _dm._repos_map[name] as BaseRepository
			if repo and repo.is_dirty():
				return true
	return false

# ==============================================================================
# 🔒 TRANSACTION MANAGEMENT
# ==============================================================================

## Begins an atomic transaction, snapshotting in-memory state.
func begin_transaction() -> void:
	if _dm:
		_dm.begin_transaction()

## Commits the transaction and persists modified dirty buckets.
func commit_transaction() -> DataResult:
	if _dm:
		return _dm.commit_transaction()
	return null

## Rolls back all memory caches to the state captured at begin_transaction().
func rollback_transaction() -> void:
	if _dm:
		_dm.rollback_transaction()

# ==============================================================================
# 🏷️ GLOBAL METADATA / KEY-VALUE STORE
# ==============================================================================

## Sets an arbitrary value in the global synced metadata store.
func set_value(key: String, value: Variant) -> void:
	if _dm:
		_dm.set_metadata(key, value)

## Retrieves a value from the metadata store with a fallback default.
func get_value(key: String, default_val: Variant = null) -> Variant:
	if _dm:
		return _dm.get_metadata(key, default_val)
	return default_val

## Checks if a key exists in the metadata store.
func has(key: String) -> bool:
	if metadata:
		var d = metadata.get_metadata_data()
		return d.values.has(key) if d else false
	return false

## Deletes a key from the metadata store.
func delete_value(key: String) -> void:
	if _dm:
		_dm.delete_metadata(key)

# ==============================================================================
# 🛠️ GENERIC MUTATION HELPER
# ==============================================================================

## Executes a callable mutation on a repository and automatically marks it dirty.
func mutate_repo(repo: BaseRepository, mutate_fn: Callable) -> void:
	if not repo:
		return
	repo.mutate(mutate_fn)

# ==============================================================================
# 🔄 BACKWARD-COMPATIBLE ALIASES
# ==============================================================================

func save_local() -> void:
	save_game()

func load_local() -> void:
	load_game()

func clear() -> void:
	clear_all()

# ==============================================================================
# 🔒 PRIVATE LOGGING HELPERS
# ==============================================================================

func _log_info(msg: String) -> void:
	var tree = Engine.get_main_loop() as SceneTree
	if tree and tree.root:
		var gs = tree.root.get_node_or_null("GameService")
		if gs and gs.logger:
			gs.logger.info(msg)

func _log_warn(msg: String) -> void:
	var tree = Engine.get_main_loop() as SceneTree
	if tree and tree.root:
		var gs = tree.root.get_node_or_null("GameService")
		if gs and gs.logger:
			gs.logger.warn(msg)

func _log_error(msg: String) -> void:
	var tree = Engine.get_main_loop() as SceneTree
	if tree and tree.root:
		var gs = tree.root.get_node_or_null("GameService")
		if gs and gs.logger:
			gs.logger.error(msg)
func is_sound_enabled() -> bool:
	var s: SettingsData = _settings_data()
	return (s.music_enabled or s.sfx_enabled) if s else true

func set_sound_enabled(enabled: bool) -> void:
	if not settings:
		return
	settings.mutate(func(s: SettingsData) -> void:
		s.music_enabled = enabled
		s.sfx_enabled = enabled
	)
	save_game()
	GameService.bus.sound_changed.emit(enabled)

func _settings_data() -> SettingsData:
	return settings.get_settings_data() if settings else null