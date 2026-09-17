class_name FirestoreStorage
extends "res://addons/datamanager/storage/ICloudStorage.gd"

## FirestoreStorage - Standard Cloud Provider & Simulation Engine

var _authenticated: bool = false
var _user_id: String = ""
var _online: bool = true

# Local in-memory fallback dictionary
# Format: user_id (String) -> key (String) -> data (Dictionary)
var _remote_db: Dictionary = {}

# Debug Statistics for Firestore read/write operations
var simulated_read_count: int = 0
var simulated_write_count: int = 0

# Single document cache
var _cached_single_doc: Dictionary = {}
var _is_single_doc_cached: bool = false

# Optional Custom Backend Adapter Delegates (allows plugging ANY custom SDK / REST API / Server)
var custom_save_handler: Callable = Callable()
var custom_load_handler: Callable = Callable()
var custom_delete_handler: Callable = Callable()

func _init() -> void:
	_connect_signals()

func _connect_signals() -> void:
	var tree = Engine.get_main_loop() as SceneTree
	if tree and tree.root:
		var signals = tree.root.get_node_or_null("DataManagerSignals")
		if signals:
			signals.sync_started.connect(_invalidate_cache)
			signals.save_started.connect(_invalidate_cache)
			signals.login_changed.connect(func(_uid, _authed): _invalidate_cache())
			signals.logout_completed.connect(_invalidate_cache)
			signals.account_deleted.connect(_invalidate_cache)

func _invalidate_cache() -> void:
	_cached_single_doc.clear()
	_is_single_doc_cached = false
	DataManagerLogger.debug("Single document read cache invalidated.", "CLOUD_PROVIDER")

func reset_simulated_counters() -> void:
	simulated_read_count = 0
	simulated_write_count = 0
	_is_single_doc_cached = false
	_cached_single_doc.clear()

func _get_config() -> Node:
	var tree = Engine.get_main_loop() as SceneTree
	if tree and tree.root:
		return tree.root.get_node_or_null("DataManagerConfig")
	return null

func _get_sync_mode() -> String:
	var config = _get_config()
	if config and "firestore_sync_mode" in config:
		return config.firestore_sync_mode
	return "SingleDocument"

func get_platform_name() -> String:
	if OS.has_feature("editor") or Engine.is_editor_hint():
		return "editor"
	var os_name = OS.get_name().to_lower()
	if os_name == "android":
		return "android"
	elif os_name == "ios":
		return "ios"
	return "editor"

func _get_parent_collection() -> String:
	var config = _get_config()
	var base_coll: String = "users"
	var segregate: bool = true
	var naming_style: String = "users_platform"

	if config:
		if "firestore_parent_collection" in config and not str(config.firestore_parent_collection).is_empty():
			base_coll = config.firestore_parent_collection
		if "segregate_by_platform" in config:
			segregate = config.segregate_by_platform
		if "collection_naming_style" in config:
			naming_style = config.collection_naming_style

	if not segregate:
		return base_coll

	var platform = get_platform_name()
	if naming_style == "platform_only":
		return platform
	elif naming_style == "platform_users":
		return "%s_users" % platform
	return "%s_%s" % [base_coll, platform]

## Smart Auto-Detection for Firebase Firestore plugin
func _get_firebase_firestore() -> Node:
	var tree = Engine.get_main_loop() as SceneTree
	if tree and tree.root:
		var firebase = tree.root.get_node_or_null("Firebase")
		if firebase and firebase.get("Firestore"):
			return firebase.Firestore
	return null

func set_online_status(is_online: bool) -> void:
	self._online = is_online
	DataManagerLogger.info("Cloud online status changed to: %s" % ("ONLINE" if is_online else "OFFLINE"), "CLOUD_PROVIDER")
	var tree = Engine.get_main_loop() as SceneTree
	if tree and tree.root:
		var signals = tree.root.get_node_or_null("DataManagerSignals")
		if signals:
			signals.connection_status_changed.emit(is_online)

func is_connected_to_backend() -> bool:
	var config = _get_config()
	if config and "cloud_enabled" in config and not config.cloud_enabled:
		return false
	return _online and _authenticated

func login_anonymous() -> DataResult:
	if not _online:
		return DataResult.fail(DataErrors.Code.CLOUD_ERROR, "Cannot login: offline.")
		
	_user_id = "anon_user_" + str(randi() % 10000)
	_authenticated = true
	DataManagerLogger.info("Logged in anonymously. UserID: %s" % _user_id, "CLOUD_PROVIDER")
	
	var tree = Engine.get_main_loop() as SceneTree
	if tree and tree.root:
		var signals = tree.root.get_node_or_null("DataManagerSignals")
		if signals:
			signals.login_changed.emit(_user_id, true)
	return DataResult.ok({"user_id": _user_id})

func login_with_provider(provider: String, token: String) -> DataResult:
	if not _online:
		return DataResult.fail(DataErrors.Code.CLOUD_ERROR, "Cannot login: offline.")
	if token.is_empty():
		return DataResult.fail(DataErrors.Code.AUTH_ERROR, "Auth token is empty.")
		
	var firebase = _get_firebase_firestore()
	if firebase and firebase.auth and firebase.auth.has("localid"):
		_user_id = firebase.auth["localid"]
	else:
		_user_id = provider + "_user_" + str(randi() % 10000)
		
	_authenticated = true
	DataManagerLogger.info("Logged in with provider '%s'. UserID: %s" % [provider, _user_id], "CLOUD_PROVIDER")
	
	var tree = Engine.get_main_loop() as SceneTree
	if tree and tree.root:
		var signals = tree.root.get_node_or_null("DataManagerSignals")
		if signals:
			signals.login_changed.emit(_user_id, true)
	return DataResult.ok({"user_id": _user_id})

func logout() -> DataResult:
	var prev_id = _user_id
	_user_id = ""
	_authenticated = false
	_cached_single_doc.clear()
	_is_single_doc_cached = false
	DataManagerLogger.info("Logged out user: %s" % prev_id, "CLOUD_PROVIDER")
	
	var tree = Engine.get_main_loop() as SceneTree
	if tree and tree.root:
		var signals = tree.root.get_node_or_null("DataManagerSignals")
		if signals:
			signals.logout_completed.emit()
			signals.login_changed.emit("", false)
	return DataResult.ok()

func delete_account() -> DataResult:
	if not _online:
		return DataResult.fail(DataErrors.Code.CLOUD_ERROR, "Cannot delete account: offline.")
	if not _authenticated:
		return DataResult.fail(DataErrors.Code.AUTH_ERROR, "Cannot delete account: not authenticated.")
		
	simulated_write_count += 1
	var fs = _get_firebase_firestore()
	if fs and not _user_id.is_empty():
		var coll = fs.collection(_get_parent_collection())
		if coll:
			await coll.delete(_user_id)
			DataManagerLogger.info("Deleted Firestore user document: %s" % _user_id, "CLOUD_PROVIDER")
			
	if _remote_db.has(_user_id):
		_remote_db.erase(_user_id)
	
	_cached_single_doc.clear()
	_is_single_doc_cached = false
	
	var deleted_id = _user_id
	_user_id = ""
	_authenticated = false
	
	var tree = Engine.get_main_loop() as SceneTree
	if tree and tree.root:
		var signals = tree.root.get_node_or_null("DataManagerSignals")
		if signals:
			signals.account_deleted.emit()
			signals.login_changed.emit("", false)
	return DataResult.ok()

func save_data(key: String, data: Dictionary) -> DataResult:
	var config = _get_config()
	if config and "cloud_enabled" in config and not config.cloud_enabled:
		return DataResult.fail(DataErrors.Code.CLOUD_ERROR, "Cloud storage is disabled in Config.")
	if not _online:
		return DataResult.fail(DataErrors.Code.CLOUD_ERROR, "Offline. Cloud save failed.")
	if not _authenticated:
		return DataResult.fail(DataErrors.Code.AUTH_ERROR, "Cloud save failed: Not authenticated.")
		
	if not _remote_db.has(_user_id):
		_remote_db[_user_id] = {}
		
	_remote_db[_user_id][key] = data.duplicate(true)
	_cached_single_doc[key] = data.duplicate(true)
	simulated_write_count += 1
	
	# 1. Custom backend adapter delegate hook (allows plugging ANY network / backend SDK)
	if custom_save_handler.is_valid():
		var custom_res = await custom_save_handler.call(key, data, _get_parent_collection(), _user_id)
		if custom_res is DataResult:
			return custom_res
		return DataResult.ok()

	# 2. Standard Firestore collection detection (if Firebase Firestore singleton exists)
	var fs = _get_firebase_firestore()
	if fs and not _user_id.is_empty():
		var coll_name = _get_parent_collection()
		var coll = fs.collection(coll_name) if fs.has_method("collection") else null
		if coll:
			var config_node = _get_config()
			var is_single_doc = config_node == null or config_node.firestore_sync_mode == "SingleDocument"
			var doc_id = _user_id if is_single_doc else key
			var data_to_save = _cached_single_doc if is_single_doc else data
			
			if coll.has_method("update"):
				var task = await coll.update(doc_id, data_to_save)
				if task and "error" in task and task.error is Dictionary and task.error.size() > 0:
					return DataResult.fail(DataErrors.Code.CLOUD_ERROR, "Firestore save failed: " + str(task.error))
				DataManagerLogger.info("Saved '%s' to Firestore document '%s/%s'" % [key, coll_name, doc_id], "CLOUD_PROVIDER")
			elif coll.has_method("add"):
				var task = await coll.add(doc_id, data_to_save)
				if task and "error" in task and task.error is Dictionary and task.error.size() > 0:
					return DataResult.fail(DataErrors.Code.CLOUD_ERROR, "Firestore save failed: " + str(task.error))
				DataManagerLogger.info("Saved '%s' to Firestore document '%s/%s'" % [key, coll_name, doc_id], "CLOUD_PROVIDER")

	return DataResult.ok()

func load_data(key: String) -> DataResult:
	var config = _get_config()
	if config and "cloud_enabled" in config and not config.cloud_enabled:
		return DataResult.fail(DataErrors.Code.CLOUD_ERROR, "Cloud storage is disabled in Config.")
	if not _online:
		return DataResult.fail(DataErrors.Code.CLOUD_ERROR, "Offline. Cloud load failed.")
	if not _authenticated:
		return DataResult.fail(DataErrors.Code.AUTH_ERROR, "Cloud load failed: Not authenticated.")
		
	# 1. Custom backend adapter delegate hook
	if custom_load_handler.is_valid():
		var custom_res = await custom_load_handler.call(key, _get_parent_collection(), _user_id)
		if custom_res is DataResult:
			return custom_res
		elif custom_res is Dictionary:
			return DataResult.ok(custom_res)

	var config_node = _get_config()
	var is_single_doc = config_node == null or config_node.firestore_sync_mode == "SingleDocument"
	if is_single_doc:
		if not _is_single_doc_cached:
			simulated_read_count += 1
			_is_single_doc_cached = true
			if _remote_db.has(_user_id) and _remote_db[_user_id] is Dictionary:
				for k in _remote_db[_user_id].keys():
					_cached_single_doc[k] = _remote_db[_user_id][k]
	else:
		simulated_read_count += 1
		
	var fs = _get_firebase_firestore()
	if fs and not _user_id.is_empty():
		var coll_name = _get_parent_collection()
		var coll = fs.collection(coll_name)
		if coll:
			var doc = await coll.get_doc(_user_id)
			if doc:
				var doc_dict = {}
				if doc.has_method("get_unsafe_document"):
					doc_dict = doc.get_unsafe_document()
				elif "doc_fields" in doc:
					doc_dict = doc.doc_fields
				
				if doc_dict.has(key):
					var val = doc_dict[key]
					_cached_single_doc[key] = val
					if not _remote_db.has(_user_id):
						_remote_db[_user_id] = {}
					_remote_db[_user_id][key] = val
					return DataResult.ok(val)

	if _cached_single_doc.has(key):
		return DataResult.ok(_cached_single_doc[key].duplicate(true))
	if _remote_db.has(_user_id) and _remote_db[_user_id].has(key):
		return DataResult.ok(_remote_db[_user_id][key].duplicate(true))
		
	return DataResult.fail(DataErrors.Code.NOT_FOUND, "Key '%s' not found on cloud database." % key)

func exists(key: String) -> bool:
	if not _online or not _authenticated:
		return false
	if _cached_single_doc.has(key):
		return true
	if _remote_db.has(_user_id) and _remote_db[_user_id].has(key):
		return true
	return false

func delete_data(key: String) -> DataResult:
	if not _online:
		return DataResult.fail(DataErrors.Code.CLOUD_ERROR, "Offline. Cloud delete failed.")
	if not _authenticated:
		return DataResult.fail(DataErrors.Code.AUTH_ERROR, "Cloud delete failed: Not authenticated.")
		
	if custom_delete_handler.is_valid():
		var custom_res = await custom_delete_handler.call(key, _get_parent_collection(), _user_id)
		if custom_res is DataResult:
			return custom_res
		return DataResult.ok()

	simulated_write_count += 1
	if _remote_db.has(_user_id) and _remote_db[_user_id].has(key):
		_remote_db[_user_id].erase(key)
	_cached_single_doc.erase(key)
	
	var fs = _get_firebase_firestore()
	if fs and not _user_id.is_empty():
		var coll = fs.collection(_get_parent_collection())
		if coll:
			await coll.delete(_user_id)
			
	return DataResult.ok()

func clear_all() -> DataResult:
	if not _online:
		return DataResult.fail(DataErrors.Code.CLOUD_ERROR, "Offline. Cloud clear failed.")
	if not _authenticated:
		return DataResult.fail(DataErrors.Code.AUTH_ERROR, "Cloud clear failed: Not authenticated.")
		
	simulated_write_count += 1
	if _remote_db.has(_user_id):
		_remote_db[_user_id].clear()
	_cached_single_doc.clear()
	return DataResult.ok()
