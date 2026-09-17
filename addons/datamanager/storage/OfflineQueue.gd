# class_name OfflineQueue
# A command-based queue that stores pending operations when offline.
# Persists to disk using LocalStorage to survive app restarts.
class_name OfflineQueue

var _local_storage: LocalStorage
var _queue_key: String = "offline_queue"
var _max_size: int = 100
var _operations: Array = [] # Array of Dictionaries

func _init(local_storage: LocalStorage, max_size: int = 100) -> void:
	self._local_storage = local_storage
	self._max_size = max_size
	var load_res = load_queue()
	if not load_res.success:
		DataManagerLogger.info("Offline operations queue initialized empty.", "OFFLINE_QUEUE")

## Loads the queue from disk.
func load_queue() -> DataResult:
	if not _local_storage.exists(_queue_key):
		_operations = []
		return DataResult.ok()
		
	var res = _local_storage.load_data(_queue_key)
	if not res.success:
		return res
		
	var dict = res.data as Dictionary
	if dict.has("operations") and dict["operations"] is Array:
		_operations = dict["operations"].duplicate()
		DataManagerLogger.info("Loaded %d pending offline operations from disk." % _operations.size(), "OFFLINE_QUEUE")
		return DataResult.ok()
		
	_operations = []
	return DataResult.fail(DataErrors.Code.CORRUPTED_SAVE, "Queue save file format was invalid.")

## Persists the current queue state to disk.
func save_queue() -> DataResult:
	var data = {
		"operations": _operations
	}
	var res = _local_storage.save_data(_queue_key, data)
	if not res.success:
		DataManagerLogger.error("Failed to save offline operations queue to disk: %s" % res.error_message, "OFFLINE_QUEUE")
	return res

## Adds an operation command to the queue.
func add_operation(op_type: String, payload: Dictionary) -> DataResult:
	if _operations.size() >= _max_size:
		# Circular buffer: discard the oldest pending command to prevent infinite memory growth
		var discarded = _operations.pop_front()
		DataManagerLogger.warning("Offline operations queue full (%d items). Discarding oldest operation: %s" % [_max_size, str(discarded)], "OFFLINE_QUEUE")
		
	var op_id = "op_" + str(Time.get_ticks_msec()) + "_" + str(randi() % 1000)
	var new_op = {
		"id": op_id,
		"timestamp": Time.get_unix_time_from_system(),
		"type": op_type,
		"payload": payload.duplicate(true),
		"retry_count": 0,
		"status": "pending"
	}
	
	_operations.append(new_op)
	var save_res = save_queue()
	if not save_res.success:
		return save_res
		
	DataManagerLogger.info("Added offline operation '%s' (ID: %s) to queue." % [op_type, op_id], "OFFLINE_QUEUE")
	if DataManagerSignals:
		DataManagerSignals.queue_changed.emit(_operations.size())
		
	return DataResult.ok(op_id)

## Returns a copy of the list of pending operations.
func get_pending_operations() -> Array:
	var pending = []
	for op in _operations:
		if op["status"] == "pending" or op["status"] == "retrying":
			pending.append(op.duplicate(true))
	return pending

## Removes a successfully processed operation from the queue.
func mark_success(op_id: String) -> void:
	var found_idx = -1
	for i in range(_operations.size()):
		if _operations[i]["id"] == op_id:
			found_idx = i
			break
			
	if found_idx != -1:
		_operations.remove_at(found_idx)
		save_queue()
		DataManagerLogger.info("Successfully executed offline operation: %s" % op_id, "OFFLINE_QUEUE")
		if DataManagerSignals:
			DataManagerSignals.queue_changed.emit(_operations.size())

## Marks an operation as failed and updates its retry counts and status.
func mark_failure(op_id: String, max_retries: int) -> void:
	for op in _operations:
		if op["id"] == op_id:
			op["retry_count"] += 1
			if op["retry_count"] >= max_retries:
				op["status"] = "failed"
				DataManagerLogger.error("Offline operation %s failed permanently after %d retries." % [op_id, max_retries], "OFFLINE_QUEUE")
			else:
				op["status"] = "retrying"
				DataManagerLogger.warning("Offline operation %s failed (Attempt %d/%d)." % [op_id, op["retry_count"], max_retries], "OFFLINE_QUEUE")
			save_queue()
			break

## Clears all operations from the queue.
func clear() -> void:
	_operations.clear()
	save_queue()
	if DataManagerSignals:
		DataManagerSignals.queue_changed.emit(0)
	DataManagerLogger.info("Cleared offline operations queue.", "OFFLINE_QUEUE")
