# class_name UnifiedBootstrapper
# Initializes the Data Management Framework and registers all 12 Unified Game Data Model repositories.
extends Node
class_name UnifiedBootstrapper

# Strongly-typed repository references
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

signal unified_data_ready

func _ready() -> void:
	_register_unified_repositories()
	_connect_signals()
	_load_initial_data()

func _get_data_manager() -> Node:
	var tree = Engine.get_main_loop() as SceneTree
	if tree and tree.root:
		return tree.root.get_node_or_null("DataManager")
	return get_node_or_null("/root/DataManager")

func _register_unified_repositories() -> void:
	var dm = _get_data_manager()
	if not dm:
		push_error("UnifiedBootstrapper: DataManager autoload not available.")
		return
		
	# Bind typed repository references directly from DataManager
	identity_repo = dm.identity_repo
	profile_repo = dm.profile_repo
	device_repo = dm.device_repo
	metadata_repo = dm.metadata_repo
	session_repo = dm.session_repo
	settings_repo = dm.settings_repo
	progression_repo = dm.progression_repo
	economy_repo = dm.economy_repo
	inventory_repo = dm.inventory_repo
	live_ops_repo = dm.live_ops_repo
	stats_repo = dm.stats_repo
	tutorials_repo = dm.tutorials_repo
	monetization_repo = dm.monetization_repo
	
	DataManagerLogger.info("Bound all 13 Unified Game Data Model repositories.", "UNIFIED_BOOT")

func _connect_signals() -> void:
	var tree = Engine.get_main_loop() as SceneTree
	var signals = tree.root.get_node_or_null("DataManagerSignals") if (tree and tree.root) else null
	if signals:
		signals.login_changed.connect(_on_login_changed)
		signals.sync_finished.connect(_on_sync_finished)

func _load_initial_data() -> void:
	var dm = _get_data_manager()
	if not dm:
		return
		
	var local_load = dm.load_local_data()
	if local_load.success:
		DataManagerLogger.info("Loaded local save successfully into unified models.", "UNIFIED_BOOT")
	else:
		DataManagerLogger.info("Starting with clean unified defaults (%s)." % local_load.error_message, "UNIFIED_BOOT")
	
	# Increment session count and update device info
	if session_repo:
		session_repo.increment_session()
	if device_repo:
		device_repo.set_app_version(ProjectSettings.get_setting("application/config/version", "1.0.0"))
	
	unified_data_ready.emit()

func _on_login_changed(user_id: String, is_logged_in: bool) -> void:
	if identity_repo == null:
		return
	if is_logged_in and not user_id.is_empty():
		identity_repo.set_identity(user_id, "auth", true)
		DataManagerLogger.info("User authenticated (%s). Starting cloud synchronization..." % user_id, "UNIFIED_BOOT")
		var result = await DataManager.sync()
		if result.success:
			DataManagerLogger.info("Cloud synchronization successful.", "UNIFIED_BOOT")
		else:
			DataManagerLogger.warning("Cloud synchronization warning: %s" % result.error_message, "UNIFIED_BOOT")
	else:
		identity_repo.set_identity("", "guest", false)

func _on_sync_finished(result: DataResult) -> void:
	if result.success:
		DataManagerLogger.info("Unified state synchronized with cloud.", "UNIFIED_BOOT")
