# class_name SyncManager
# Autoload class responsible for cloud synchronisation, conflict resolution, and offline queue processing.
extends Node

var _local_storage: LocalStorage
var _cloud_storage_ref: RefCounted
var _cloud_storage: RefCounted:
	get:
		var data_mgr = get_node_or_null("/root/DataManager")
		if data_mgr and data_mgr.get("cloud_storage"):
			return data_mgr.cloud_storage
		return _cloud_storage_ref
var _offline_queue: OfflineQueue
var _retry_manager: RetryManager

var _repositories: Dictionary = {} # String (name) -> BaseRepository
var _merge_strategy: DataMergePolicy.Strategy = DataMergePolicy.Strategy.LATEST_TIMESTAMP
var _custom_resolver: Callable = Callable()
var _command_handlers: Dictionary = {} # String (op_type) -> Callable

var _is_syncing: bool = false
var _sync_timer: Timer

## Registers a custom Callable to execute when an offline operation of this type is replayed.
## The handler must take a Dictionary payload and return a DataResult.
func register_command_handler(op_type: String, handler: Callable) -> void:
	_command_handlers[op_type] = handler
	DataManagerLogger.info("Registered command handler for: %s" % op_type, "SYNC_MANAGER")

func setup(
	local: LocalStorage,
	cloud: RefCounted,
	queue: OfflineQueue,
	repositories: Dictionary,
	strategy: DataMergePolicy.Strategy,
	max_attempts: int,
	initial_delay: float,
	max_delay: float
) -> void:
	self._local_storage = local
	self._cloud_storage_ref = cloud
	self._offline_queue = queue
	self._repositories = repositories
	self._merge_strategy = strategy
	self._retry_manager = RetryManager.new(max_attempts, initial_delay, 2.0, max_delay)
	
	# Connect to connection status changes
	if DataManagerSignals:
		DataManagerSignals.connection_status_changed.connect(_on_connection_status_changed)
		
	# Start periodic sync timer if cloud is enabled
	_setup_periodic_sync()

## Starts the full synchronization process across all registered repositories.
func sync_all() -> DataResult:
	if _is_syncing:
		DataManagerLogger.debug("Sync requested while sync in progress — awaiting active sync completion.", "SYNC_MANAGER")
		if DataManagerSignals:
			var sig_val = await DataManagerSignals.sync_finished
			if sig_val is DataResult:
				return sig_val
			elif sig_val is Array and not sig_val.is_empty() and sig_val[0] is DataResult:
				return sig_val[0]
		return DataResult.ok()
		
	if not _cloud_storage or not _cloud_storage.is_connected_to_backend():
		return DataResult.fail(DataErrors.Code.CLOUD_ERROR, "Cannot sync: Cloud storage is offline.")
		
	_is_syncing = true
	DataManagerLogger.info("Starting synchronization...", "SYNC_MANAGER")
	if DataManagerSignals:
		DataManagerSignals.sync_started.emit()
		
	# 1. First replay any pending offline actions
	var replay_res = await replay_offline_queue()
	if not replay_res.success:
		DataManagerLogger.warning("Offline queue replay failed during sync: %s" % replay_res.error_message, "SYNC_MANAGER")
		
	# 2. Sync each repository
	var sync_errors: Array[String] = []
	for repo_name in _repositories:
		if not _cloud_storage.is_connected_to_backend():
			_is_syncing = false
			DataManagerLogger.warning("Cloud backend disconnected mid-sync -> Cancelling sync operation.", "SYNC_MANAGER")
			var abort_res = DataResult.fail(DataErrors.Code.CLOUD_ERROR, "Sync aborted: Cloud storage went offline.")
			if DataManagerSignals:
				DataManagerSignals.sync_finished.emit(abort_res)
			return abort_res

		var repo = _repositories[repo_name] as BaseRepository
		if not repo.is_cloud_synced:
			continue
		var res = await sync_repository(repo)
		if not res.success:
			sync_errors.append("%s: %s" % [repo_name, res.error_message])
			
	_is_syncing = false
	
	if not sync_errors.is_empty():
		var msg = "Sync completed with errors:\n" + "\n".join(sync_errors)
		DataManagerLogger.error(msg, "SYNC_MANAGER")
		var fail_res = DataResult.fail(DataErrors.Code.CLOUD_ERROR, msg)
		if DataManagerSignals:
			DataManagerSignals.sync_finished.emit(fail_res)
		return fail_res
		
	DataManagerLogger.info("Synchronization completed successfully.", "SYNC_MANAGER")
	var success_res = DataResult.ok()
	if DataManagerSignals:
		DataManagerSignals.sync_finished.emit(success_res)
	return success_res

## Synchronizes a single repository with the cloud database.
func sync_repository(repo: BaseRepository) -> DataResult:
	var key = repo.repository_name
	DataManagerLogger.info("Syncing repository: %s" % key, "SYNC_MANAGER")
	
	var local_data = repo.save_to_dict()
	
	# Fetch remote save data from cloud
	var download_callable = Callable(_cloud_storage, "load_data")
	var download_res = await _retry_manager.execute_with_retry(download_callable, [key])
	
	if not download_res.success:
		# If remote file is missing, upload local data to establish baseline
		if download_res.error_code == DataErrors.Code.NOT_FOUND:
			DataManagerLogger.info("No cloud save found for %s. Uploading local save as baseline..." % key, "SYNC_MANAGER")
			return await upload_repository(repo)
		else:
			return download_res
			
	var remote_data = download_res.data as Dictionary
	
	# Check if local and remote data differ
	var mock_model_local = repo.model_script.new() as BaseModel
	var mock_model_remote = repo.model_script.new() as BaseModel
	mock_model_local.deserialize(local_data)
	mock_model_remote.deserialize(remote_data)
	mock_model_local.schema_version = int(local_data.get("schema_version", 1))
	mock_model_remote.schema_version = int(remote_data.get("schema_version", 1))
	mock_model_local.last_saved_timestamp = float(local_data.get("last_saved_timestamp", 0.0))
	mock_model_remote.last_saved_timestamp = float(remote_data.get("last_saved_timestamp", 0.0))
	
	if mock_model_local.equals(mock_model_remote):
		DataManagerLogger.debug("Repository '%s' matches cloud save. No sync required." % key, "SYNC_MANAGER")
		repo.clear_dirty()
		return DataResult.ok()
		
	# Conflict detected! Resolve it.
	var winner_data: Dictionary = {}
	var model_merged = mock_model_local.merge(mock_model_remote)
	if model_merged != null:
		DataManagerLogger.info("Resolved conflict for '%s' using model-specific merge()." % key, "SYNC_MANAGER")
		winner_data = model_merged.serialize()
		winner_data["schema_version"] = model_merged.schema_version
		winner_data["last_saved_timestamp"] = model_merged.last_saved_timestamp
	else:
		var resolve_res = await ConflictResolver.resolve(local_data, remote_data, _merge_strategy, _custom_resolver)
		if not resolve_res.success:
			return resolve_res
		winner_data = resolve_res.data as Dictionary
	
	# Apply winning data locally
	var load_res = repo.load_from_dict(winner_data)
	if not load_res.success:
		return load_res
		
	# Save locally to ensure persistent synchronization
	var local_save_res = _local_storage.save_data(key, winner_data)
	if not local_save_res.success:
		return local_save_res
		
	# Upload to cloud to keep both sides aligned
	var upload_callable = Callable(_cloud_storage, "save_data")
	var upload_res = await _retry_manager.execute_with_retry(upload_callable, [key, winner_data])
	if not upload_res.success:
		return upload_res
		
	repo.clear_dirty()
	if DataManagerSignals:
		DataManagerSignals.cloud_updated.emit(key, winner_data)
	return DataResult.ok()

## Forces upload of repository data to cloud.
func upload_repository(repo: BaseRepository) -> DataResult:
	if not repo.is_cloud_synced:
		return DataResult.ok()
	var key = repo.repository_name
	var data = repo.save_to_dict()
	
	var upload_callable = Callable(_cloud_storage, "save_data")
	var upload_res = await _retry_manager.execute_with_retry(upload_callable, [key, data])
	
	if upload_res.success:
		repo.clear_dirty()
		
	return upload_res

## Replays pending operations in the offline queue.
func replay_offline_queue() -> DataResult:
	var pending_ops = _offline_queue.get_pending_operations()
	if pending_ops.is_empty():
		return DataResult.ok()
		
	DataManagerLogger.info("Replaying %d queued offline operations..." % pending_ops.size(), "SYNC_MANAGER")
	
	for op in pending_ops:
		var op_id = op["id"]
		var op_type = op["type"]
		var payload = op["payload"] as Dictionary
		
		# Execute operation against targets
		var result = _execute_offline_operation(op_type, payload)
		if result.success:
			_offline_queue.mark_success(op_id)
		else:
			# If the error is fatal/validation, discard it but mark success to unblock the queue
			if result.error_code == DataErrors.Code.VALIDATION_ERROR:
				DataManagerLogger.error("Failed offline operation %s permanently (Validation: %s). Discarding." % [op_id, result.error_message], "SYNC_MANAGER")
				_offline_queue.mark_success(op_id)
			else:
				# Transient network error, stop queue playback and retry later
				_offline_queue.mark_failure(op_id, _retry_manager.max_attempts)
				return DataResult.fail(
					DataErrors.Code.CLOUD_ERROR,
					"Offline queue replay paused. Operation failed: %s" % result.error_message
				)
				
	return DataResult.ok()

# Processes a single command payload against repositories.
func _execute_offline_operation(op_type: String, payload: Dictionary) -> DataResult:
	if _command_handlers.has(op_type):
		var handler = _command_handlers[op_type] as Callable
		if handler.is_valid():
			var res = handler.call(payload)
			if res is DataResult:
				return res
			else:
				return DataResult.ok()
		else:
			return DataResult.fail(DataErrors.Code.VALIDATION_ERROR, "Command handler is invalid for op: " + op_type)
	return DataResult.fail(DataErrors.Code.VALIDATION_ERROR, "No registered handler for offline operation type: " + op_type)

func _setup_periodic_sync() -> void:
	if _sync_timer != null:
		_sync_timer.queue_free()
		
	var config_node = get_node_or_null("/root/DataManagerConfig")
	var periodic_enabled = config_node != null and config_node.periodic_sync_enabled
	
	if not periodic_enabled:
		DataManagerLogger.info("Periodic synchronization is disabled.", "SYNC_MANAGER")
		return
		
	_sync_timer = Timer.new()
	_sync_timer.name = "SyncTimer"
	_sync_timer.one_shot = false
	
	var interval = 120.0
	if config_node:
		interval = config_node.sync_interval_seconds
		
	_sync_timer.wait_time = interval
	_sync_timer.timeout.connect(_on_sync_timeout)
	add_child(_sync_timer)
	_sync_timer.start()
	DataManagerLogger.info("Periodic synchronization timer started. Interval: %fs" % interval, "SYNC_MANAGER")

func _on_sync_timeout() -> void:
	if _cloud_storage and _cloud_storage.is_connected_to_backend():
		DataManagerLogger.info("Periodic timed sync triggered.", "SYNC_MANAGER")
		sync_all()

func _on_connection_status_changed(is_online: bool) -> void:
	if is_online:
		var config_node = get_node_or_null("/root/DataManagerConfig")
		var auto_sync_on_reconnect = config_node != null and config_node.periodic_sync_enabled
		if auto_sync_on_reconnect:
			DataManagerLogger.info("Network restored. Triggering cloud synchronization...", "SYNC_MANAGER")
			sync_all()
		else:
			DataManagerLogger.info("Network restored. Automatic sync on reconnect is disabled.", "SYNC_MANAGER")
