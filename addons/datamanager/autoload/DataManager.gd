# class_name DataManager
# Main orchestrator autoload class. Act as the single gateway for gameplay data.
extends Node

# Persistent providers and cache references
var local_storage: LocalStorage
var cloud_storage: RefCounted # ICloudStorage instance
var offline_queue: OfflineQueue
var memory_cache: MemoryCache

# Registered Repositories (The 13 Unified Game Data Model Repositories)
var identity_repo: IdentityRepository
var profile_repo: ProfileRepository
var device_repo: DeviceRepository
var metadata_repo: MetadataRepository
var session_repo: SessionRepository
var settings_repo: SettingsRepository
var progression_repo: ProgressionRepository
var economy_repo: EconomyRepository
var inventory_repo: InventoryRepository
var live_ops_repo: LiveOpsRepository
var stats_repo: StatsRepository
var tutorials_repo: TutorialsRepository
var monetization_repo: MonetizationRepository

var _repos_map: Dictionary = {}

# Transaction tracking state
var _in_transaction: bool = false
var _transaction_snapshots: Dictionary = {} # String (repo name) -> BaseModel clone

# Auto-save helper references
var _autosave_timer: Timer

func _ready() -> void:
	# 0. Auto-bootstrap companion nodes if not registered in project.godot
	var root = get_tree().root
	var config_node = get_node_or_null("/root/DataManagerConfig")
	if not config_node:
		var config_script = load("res://addons/datamanager/autoload/Config.gd")
		if config_script:
			config_node = config_script.new()
			config_node.name = "DataManagerConfig"
			root.add_child(config_node)

	var signals_node = get_node_or_null("/root/DataManagerSignals")
	if not signals_node:
		var signals_script = load("res://addons/datamanager/autoload/Signals.gd")
		if signals_script:
			signals_node = signals_script.new()
			signals_node.name = "DataManagerSignals"
			root.add_child(signals_node)

	var sync_node = get_node_or_null("/root/SyncManager")
	if not sync_node:
		var sync_script = load("res://addons/datamanager/autoload/SyncManager.gd")
		if sync_script:
			sync_node = sync_script.new()
			sync_node.name = "SyncManager"
			root.add_child(sync_node)

	if not config_node:
		DataManagerLogger.error("DataManagerConfig autoload not found.", "CORE")
		return
		
	var config = config_node
	
	# 1. Instantiate Core Abstractions
	local_storage = LocalStorage.new(
		config.local_save_directory,
		config.local_save_extension,
		config.encrypt_local_saves,
		config.encryption_key
	)
	cloud_storage = FirestoreStorage.new()
	offline_queue = OfflineQueue.new(local_storage, config.offline_queue_max_size)
	memory_cache = MemoryCache.new()
	
	# 2. Instantiate All 13 Repositories
	identity_repo = IdentityRepository.new(memory_cache)
	profile_repo = ProfileRepository.new(memory_cache)
	device_repo = DeviceRepository.new(memory_cache)
	metadata_repo = MetadataRepository.new(memory_cache)
	session_repo = SessionRepository.new(memory_cache)
	settings_repo = SettingsRepository.new(memory_cache)
	progression_repo = ProgressionRepository.new(memory_cache)
	economy_repo = EconomyRepository.new(memory_cache)
	inventory_repo = InventoryRepository.new(memory_cache)
	live_ops_repo = LiveOpsRepository.new(memory_cache)
	stats_repo = StatsRepository.new(memory_cache)
	tutorials_repo = TutorialsRepository.new(memory_cache)
	monetization_repo = MonetizationRepository.new(memory_cache)
	
	_repos_map = {
		identity_repo.repository_name: identity_repo,
		profile_repo.repository_name: profile_repo,
		device_repo.repository_name: device_repo,
		metadata_repo.repository_name: metadata_repo,
		session_repo.repository_name: session_repo,
		settings_repo.repository_name: settings_repo,
		progression_repo.repository_name: progression_repo,
		economy_repo.repository_name: economy_repo,
		inventory_repo.repository_name: inventory_repo,
		live_ops_repo.repository_name: live_ops_repo,
		stats_repo.repository_name: stats_repo,
		tutorials_repo.repository_name: tutorials_repo,
		monetization_repo.repository_name: monetization_repo
	}
	
	# 3. Setup SyncManager Autoload
	if sync_node:
		var strategy_enum = DataMergePolicy.Strategy.LATEST_TIMESTAMP
		match config.default_merge_policy:
			"PreferCloud": strategy_enum = DataMergePolicy.Strategy.PREFER_CLOUD
			"PreferLocal": strategy_enum = DataMergePolicy.Strategy.PREFER_LOCAL
			"LatestTimestamp": strategy_enum = DataMergePolicy.Strategy.LATEST_TIMESTAMP
			"Manual": strategy_enum = DataMergePolicy.Strategy.MANUAL
			
		sync_node.setup(
			local_storage,
			cloud_storage,
			offline_queue,
			_repos_map,
			strategy_enum,
			config.max_retry_attempts,
			config.retry_initial_delay,
			config.retry_max_delay
		)
		
	# 4. Load persistent saves from disk into memory
	var load_res = load_local_data()
	if not load_res.success:
		DataManagerLogger.warning("No local saves found, initialized new profiles.", "CORE")
		
	# 5. Configure periodic auto-saves
	if config.autosave_enabled:
		_setup_autosave_timer(config.autosave_interval_seconds)
		
	DataManagerLogger.info("DataManager initialized successfully.", "CORE")

# Catch system notifications for auto-saves (app quit / background pause)
func _notification(what: int) -> void:
	if not is_inside_tree():
		return
		
	var config_node = get_node_or_null("/root/DataManagerConfig")
	if not config_node:
		return
		
	var config = config_node
	
	match what:
		NOTIFICATION_WM_CLOSE_REQUEST:
			if config.autosave_on_quit:
				DataManagerLogger.info("App closing request. Auto-saving...", "CORE")
				save()
		NOTIFICATION_APPLICATION_FOCUS_OUT:
			if config.autosave_on_pause:
				DataManagerLogger.info("App lost focus / paused. Auto-saving...", "CORE")
				save()

## Loads all saves from disk into the cache.
func load_local_data() -> DataResult:
	DataManagerLogger.info("Loading local save data files...", "CORE")
	var failures: Array[String] = []
	
	for name in _repos_map:
		var repo = _repos_map[name] as BaseRepository
		if local_storage.exists(name):
			var res = local_storage.load_data(name)
			if res.success:
				var load_res = repo.load_from_dict(res.data)
				if not load_res.success:
					failures.append("Failed to apply %s data: %s" % [name, load_res.error_message])
			else:
				failures.append("Failed to read file %s: %s" % [name, res.error_message])
		else:
			repo.reset_to_default()
			
	if not failures.is_empty():
		return DataResult.fail(DataErrors.Code.DISK_ERROR, "\n".join(failures))
		
	return DataResult.ok()

## Saves all dirty repositories to the local disk and triggers async cloud uploads.
func save() -> DataResult:
	if DataManagerSignals:
		DataManagerSignals.save_started.emit()
		
	DataManagerLogger.info("Starting save process...", "CORE")
	var disk_errors: Array[String] = []
	var saved_any: bool = false
	
	for name in _repos_map:
		var repo = _repos_map[name] as BaseRepository
		if repo.is_dirty():
			var data = repo.save_to_dict()
			
			# Save to disk
			var disk_res = local_storage.save_data(name, data)
			if disk_res.success:
				saved_any = true
				
				# If remote connection is online and sync_on_save is enabled, upload immediately
				var config_node = get_node_or_null("/root/DataManagerConfig")
				var sync_on_save_enabled = config_node != null and config_node.sync_on_save
				
				if sync_on_save_enabled and cloud_storage.is_connected_to_backend():
					var sync_node = get_node_or_null("/root/SyncManager")
					if sync_node:
						sync_node.upload_repository(repo) # Executed async, no await here
				repo.clear_dirty()
			else:
				disk_errors.append("%s disk write failed: %s" % [name, disk_res.error_message])
				
	var final_result: DataResult
	if not disk_errors.is_empty():
		var msg = "Save failed with errors:\n" + "\n".join(disk_errors)
		DataManagerLogger.error(msg, "CORE")
		final_result = DataResult.fail(DataErrors.Code.DISK_ERROR, msg)
	else:
		if saved_any:
			DataManagerLogger.info("Save completed successfully (dirty files written).", "CORE")
		else:
			DataManagerLogger.debug("No dirty data found. Save skipped.", "CORE")
		final_result = DataResult.ok()
		
	if DataManagerSignals:
		DataManagerSignals.save_finished.emit(final_result)
		
	return final_result

## Syncs memory, local files, and remote database.
func sync() -> DataResult:
	var sync_node = get_node_or_null("/root/SyncManager")
	if not sync_node:
		return DataResult.fail(DataErrors.Code.CLOUD_ERROR, "SyncManager autoload not found.")
	return await sync_node.sync_all()

## Triggers an explicit refresh from cloud databases, replacing local cached states.
func refresh_from_cloud() -> DataResult:
	if not cloud_storage.is_connected_to_backend():
		return DataResult.fail(DataErrors.Code.CLOUD_ERROR, "Cannot refresh: offline.")
		
	DataManagerLogger.info("Refreshing local memory caches from cloud database...", "CORE")
	var failures: Array[String] = []
	
	for name in _repos_map:
		var repo = _repos_map[name] as BaseRepository
		var download_res = await cloud_storage.load_data(name)
		if download_res.success:
			var load_res = repo.load_from_dict(download_res.data)
			if load_res.success:
				local_storage.save_data(name, download_res.data)
			else:
				failures.append("Apply cloud data failed for %s: %s" % [name, load_res.error_message])
		else:
			if download_res.error_code != DataErrors.Code.NOT_FOUND:
				failures.append("Download failed for %s: %s" % [name, download_res.error_message])
				
	if not failures.is_empty():
		var fail_res = DataResult.fail(DataErrors.Code.CLOUD_ERROR, "\n".join(failures))
		var signals_node = get_node_or_null("/root/DataManagerSignals")
		if signals_node:
			signals_node.sync_finished.emit(fail_res)
		return fail_res
		
	var success_res = DataResult.ok()
	var signals_node = get_node_or_null("/root/DataManagerSignals")
	if signals_node:
		signals_node.sync_finished.emit(success_res)
	return success_res

## Clears all cached objects and erases disk contents.
func clear_local() -> void:
	DataManagerLogger.warning("Clearing all runtime caches and local storage files!", "CORE")
	memory_cache.clear()
	local_storage.clear_all()
	offline_queue.clear()
	for name in _repos_map:
		_repos_map[name].reset_to_default()

## Performs logout cleanup: syncs all pending data to cloud first.
## If cloud sync or backend logout fails, logout is aborted to prevent local data loss unless force = true.
func logout(force: bool = false) -> DataResult:
	DataManagerLogger.info("Logging out active session. Performing final cloud sync...", "CORE")
	if cloud_storage.is_connected_to_backend():
		var save_res = save()
		if not save_res.success and not force:
			DataManagerLogger.error("Logout aborted: Local save failed before sync.", "CORE")
			if DataManagerSignals:
				DataManagerSignals.logout_failed.emit(save_res.error_message)
			return save_res
			
		var sync_res = await sync()
		if not sync_res.success and not force:
			DataManagerLogger.error("Logout aborted: Cloud sync failed (%s). Local data preserved." % sync_res.error_message, "CORE")
			if DataManagerSignals:
				DataManagerSignals.logout_failed.emit(sync_res.error_message)
			return sync_res
			
	var cloud_res = await cloud_storage.logout()
	if not cloud_res.success and not force:
		DataManagerLogger.error("Logout aborted: Cloud backend logout failed (%s). Local data preserved." % cloud_res.error_message, "CORE")
		if DataManagerSignals:
			DataManagerSignals.logout_failed.emit(cloud_res.error_message)
		return cloud_res
		
	clear_local()
	if DataManagerSignals:
		DataManagerSignals.logout_completed.emit()
	return cloud_res

## Wipes cloud accounts and local caches permanently.
## If the backend delete fails (e.g. re-authentication required, network drop), local data is NOT wiped.
func delete_account() -> DataResult:
	DataManagerLogger.warning("Deleting user account from database...", "CORE")
	if not cloud_storage.is_connected_to_backend():
		var err = "Cannot delete account: not connected or not authenticated."
		DataManagerLogger.error(err, "CORE")
		if DataManagerSignals:
			DataManagerSignals.account_delete_failed.emit(err)
		return DataResult.fail(DataErrors.Code.AUTH_ERROR, err)
		
	var cloud_res = await cloud_storage.delete_account()
	if not cloud_res.success:
		DataManagerLogger.error("Account deletion failed on server (%s). Local data preserved." % cloud_res.error_message, "CORE")
		if DataManagerSignals:
			DataManagerSignals.account_delete_failed.emit(cloud_res.error_message)
		return cloud_res
		
	clear_local()
	if DataManagerSignals:
		DataManagerSignals.account_deleted.emit()
	return cloud_res

# ==============================================================================
# Transaction Support
# ==============================================================================

## Begins a transaction snapshot. Any modification operations can be rolled back.
func begin_transaction() -> void:
	if _in_transaction:
		DataManagerLogger.warning("Transaction already in progress. Resetting snapshots...", "CORE")
		
	_in_transaction = true
	_transaction_snapshots.clear()
	
	for name in _repos_map:
		var repo = _repos_map[name] as BaseRepository
		_transaction_snapshots[name] = repo.get_data().clone()
		
	DataManagerLogger.info("Data update transaction started.", "CORE")

## Commits modifications, persisting changes and clearing snapshots.
func commit_transaction() -> DataResult:
	if not _in_transaction:
		return DataResult.fail(DataErrors.Code.TRANSACTION_ERROR, "No transaction active.")
		
	_in_transaction = false
	_transaction_snapshots.clear()
	DataManagerLogger.info("Transaction changes committed successfully.", "CORE")
	
	# Save changes to disk
	return save()

## Discards modifications made since begin_transaction() was called.
func rollback_transaction() -> void:
	if not _in_transaction:
		DataManagerLogger.warning("Cannot rollback: No transaction active.", "CORE")
		return
		
	for name in _repos_map:
		if _transaction_snapshots.has(name):
			var snap = _transaction_snapshots[name] as BaseModel
			_repos_map[name].set_data(snap)
			_repos_map[name].clear_dirty()
			
	_in_transaction = false
	_transaction_snapshots.clear()
	DataManagerLogger.info("Transaction rolled back. Cache reverted to snapshots.", "CORE")


## Configures and restarts the autosave timer. Called automatically by Config settings at runtime.
func configure_autosave(enabled: bool, seconds: float) -> void:
	if _autosave_timer != null:
		_autosave_timer.queue_free()
		_autosave_timer = null
		
	if not enabled:
		DataManagerLogger.info("Autosave has been disabled.", "CORE")
		return
		
	_autosave_timer = Timer.new()
	_autosave_timer.name = "AutosaveTimer"
	_autosave_timer.one_shot = false
	_autosave_timer.wait_time = seconds
	_autosave_timer.timeout.connect(func():
		DataManagerLogger.info("Periodic autosave timer triggered.", "CORE")
		save()
	)
	add_child(_autosave_timer)
	_autosave_timer.start()
	DataManagerLogger.info("Periodic autosave timer started. Interval: %fs" % seconds, "CORE")

# Private helper to setup timed auto saves
func _setup_autosave_timer(seconds: float) -> void:
	configure_autosave(true, seconds)

# Automatically saves after critical action changes if configured (can be expanded)
func _check_autosave_important() -> void:
	# For production, you can choose to auto save instantly after key transactions
	# or let the periodic autosave handle it. We save on critical items if in transaction-less modes.
	pass

# ==============================================================================
# Dynamic Extensibility & Arbitrary Key-Value Storage
# ==============================================================================

## Dynamically registers multiple repositories in batch at runtime.
func register_repositories(repos: Array[BaseRepository]) -> DataResult:
	var failures: Array[String] = []
	for repo in repos:
		var res = register_repository(repo)
		if not res.success:
			failures.append("%s: %s" % [repo.repository_name, res.error_message])
	if not failures.is_empty():
		return DataResult.fail(DataErrors.Code.DISK_ERROR, "Batch registration errors:\n" + "\n".join(failures))
	return DataResult.ok()

## Dynamically registers a custom repository at runtime. Loads any existing local saves.
func register_repository(repo: BaseRepository) -> DataResult:
	var name = repo.repository_name
	_repos_map[name] = repo
	
	var sync_node = get_node_or_null("/root/SyncManager")
	if sync_node:
		sync_node._repositories[name] = repo
	
	# Load its local save if it exists
	if local_storage.exists(name):
		var res = local_storage.load_data(name)
		if res.success:
			var load_res = repo.load_from_dict(res.data)
			if not load_res.success:
				DataManagerLogger.warning("Failed to apply local save for registered repo %s: %s" % [name, load_res.error_message], "CORE")
				return load_res
		else:
			DataManagerLogger.warning("Failed to load save file for registered repo %s: %s" % [name, res.error_message], "CORE")
			return res
	else:
		repo.reset_to_default()
		
	# If online, sync it immediately
	if cloud_storage.is_connected_to_backend() and repo.is_cloud_synced:
		if sync_node:
			# Execute async sync in background
			sync_node.sync_repository(repo)
			
	DataManagerLogger.info("Dynamically registered repository: %s" % name, "CORE")
	return DataResult.ok()

## Fetches a registered repository dynamically by its name.
func get_repository(name: String) -> BaseRepository:
	if _repos_map.has(name):
		return _repos_map[name]
	return null

## Checks if a repository is registered.
func has_repository(name: String) -> bool:
	return _repos_map.has(name)

## Sets an arbitrary metadata value in the global synced Key-Value store.
func set_metadata(key: String, value: Variant) -> void:
	if metadata_repo:
		var d = metadata_repo.get_metadata_data()
		if d:
			d.values[key] = value
			metadata_repo.mark_dirty()

## Retrieves a value from the global synced Key-Value store. Returns default if not found.
func get_metadata(key: String, default_value: Variant = null) -> Variant:
	if metadata_repo:
		var d = metadata_repo.get_metadata_data()
		if d and d.values.has(key):
			return d.values[key]
	return default_value

## Deletes a key from the global synced Key-Value store.
func delete_metadata(key: String) -> void:
	if metadata_repo:
		var d = metadata_repo.get_metadata_data()
		if d and d.values.has(key):
			d.values.erase(key)
			metadata_repo.mark_dirty()

## Injects a custom cloud storage adapter conforming to ICloudStorage (e.g. Firebase, Supabase, REST, etc.)
func set_cloud_storage(p_storage: RefCounted) -> void:
	cloud_storage = p_storage
	var sync_node = get_node_or_null("/root/SyncManager")
	if sync_node:
		sync_node._cloud_storage = p_storage
	DataManagerLogger.info("Custom cloud storage adapter registered successfully.", "CORE")
