extends Node
class_name ExampleGameBootstrapper

## Reference repository instances
var profile_repo: ExampleProfileRepository
var currency_repo: ExampleCurrencyRepository
var cosmetics_repo: ExampleCosmeticsRepository
var progression_repo: ExampleProgressionRepository
var settings_repo: ExampleSettingsRepository

func _ready() -> void:
	# 1. Register our dynamic repositories on bootup
	_register_game_repositories()
	
	# 2. Register our offline command handlers
	OfflineCommandRegistry.register_handlers()
	
	# 3. Configure manual merge conflict resolver popup
	_setup_conflict_resolver()
	
	# 4. Listen to Login Signals
	if DataManagerSignals:
		DataManagerSignals.login_changed.connect(_on_user_login_changed)
		DataManagerSignals.sync_finished.connect(_on_sync_finished)
	
	# 5. Initialize from Local Saves
	var local_load = DataManager.load_local_data()
	if local_load.success:
		DataManagerLogger.info("Loaded local profile data successfully.", "EXAMPLE_BOOT")
	else:
		DataManagerLogger.warning("Failed to load local data: %s. Starting fresh." % local_load.error_message, "EXAMPLE_BOOT")

func _register_game_repositories() -> void:
	# Instantiate and dynamically plug our Pogo-Pencil models
	profile_repo = ExampleProfileRepository.new(DataManager.memory_cache)
	currency_repo = ExampleCurrencyRepository.new(DataManager.memory_cache)
	cosmetics_repo = ExampleCosmeticsRepository.new(DataManager.memory_cache)
	progression_repo = ExampleProgressionRepository.new(DataManager.memory_cache)
	settings_repo = ExampleSettingsRepository.new(DataManager.memory_cache)
	
	DataManager.register_repositories([
		profile_repo,
		currency_repo,
		cosmetics_repo,
		progression_repo,
		settings_repo
	])

func _setup_conflict_resolver() -> void:
	# Switch default merge policy to MANUAL to trigger popups on conflict
	var config = get_node_or_null("/root/DataManagerConfig")
	if config:
		config.default_merge_policy = "Manual"
	
	var sync_node = get_node_or_null("/root/SyncManager")
	if sync_node:
		# Bind the manual merge popup handler
		sync_node._custom_resolver = Callable(self, "_resolve_account_conflict")

## Runs when there is a local and cloud timestamp save mismatch.
## This is an async Callable, allowing us to yield and wait for User UI inputs!
func _resolve_account_conflict(local_data: Dictionary, remote_data: Dictionary) -> Dictionary:
	DataManagerLogger.info("Conflict detected between Local device and Cloud backup!", "EXAMPLE_BOOT")
	
	# Instantiate a popup scene, add to tree, and await its choice
	var popup_scene = load("res://addons/datamanager/example/ui/ExampleConflictPopup.gd")
	var popup = popup_scene.new()
	add_child(popup)
	
	# Call show to populate data
	popup.setup_conflict(local_data, remote_data)
	
	# Await the selection signal emitted when player clicks a button
	var chosen_option = await popup.conflict_resolved
	popup.queue_free()
	
	match chosen_option:
		"local":
			DataManagerLogger.info("Player chose Local Device Save. Overwriting cloud...", "EXAMPLE_BOOT")
			return local_data
		"remote":
			DataManagerLogger.info("Player chose Cloud Backup Save. Restoring locally...", "EXAMPLE_BOOT")
			return remote_data
		"merge":
			DataManagerLogger.info("Player chose to merge values selectively...", "EXAMPLE_BOOT")
			return _merge_profiles_selectively(local_data, remote_data)
			
	return remote_data # Fallback

func _merge_profiles_selectively(local: Dictionary, remote: Dictionary) -> Dictionary:
	var merged = remote.duplicate(true)
	# Custom rule: take highest highscore
	merged["high_score"] = max(int(local.get("high_score", 0)), int(remote.get("high_score", 0)))
	# Custom rule: combine coins
	merged["coins"] = int(local.get("coins", 0)) + int(remote.get("coins", 0))
	return merged

## Triggers when authentication completes (e.g. Firebase Auth)
func _on_user_login_changed(user_id: String, is_logged_in: bool) -> void:
	if is_logged_in:
		DataManagerLogger.info("User logged in. Starting full Cloud Synchronization...", "EXAMPLE_BOOT")
		var result = await DataManager.sync()
		if result.success:
			DataManagerLogger.info("Sync complete. User data is aligned and fresh.", "EXAMPLE_BOOT")
		else:
			DataManagerLogger.error("Sync failed: " + result.error_message, "EXAMPLE_BOOT")

func _on_sync_finished(result: DataResult) -> void:
	if result.success:
		# Repositories now have updated cached data. Refresh UI views.
		DataManagerLogger.info("State synchronized. Refreshing gameplay UI elements.", "EXAMPLE_BOOT")

# ==============================================================================
# Simulation Gameplay Methods (Showing how game code interacts)
# ==============================================================================

## Call this when a gameplay run ends
func simulate_run_end(score: int, coins_collected: int) -> void:
	# 1. Start an atomic transaction
	DataManager.begin_transaction()
	
	# 2. Mutate progression stats
	progression_repo.update_high_score(score)
	progression_repo.record_jumps(score / 2) # Mock math
	progression_repo.record_height(score)
	
	# 3. Add currencies
	currency_repo.add_coins(coins_collected)
	
	# 4. Commit changes (persists locally and queues uploads if online)
	var commit_res = DataManager.commit_transaction()
	if commit_res.success:
		DataManagerLogger.info("Run progress saved locally and synchronized.", "EXAMPLE_BOOT")
	else:
		DataManagerLogger.error("Failed to commit run progress: " + commit_res.error_message, "EXAMPLE_BOOT")

## Simulates modifying local-only settings (will save to disk but never sync to cloud)
func simulate_local_settings_modification(new_volume: float) -> void:
	settings_repo.set_volume(new_volume)
	DataManager.save()
	DataManagerLogger.info("Local settings saved to disk (Cloud-sync bypassed).", "EXAMPLE_BOOT")

## Simulates using the generic synced Key-Value store APIs directly
func simulate_synced_metadata_usage() -> void:
	# Set a value (this will auto-save and sync with cloud)
	DataManager.set_metadata("last_played_device", OS.get_name())
	DataManager.set_metadata("graphics_quality_preset", "Ultra")
	
	# Retrieve it
	var device = DataManager.get_metadata("last_played_device", "Unknown")
	var quality = DataManager.get_metadata("graphics_quality_preset", "Medium")
	
	DataManagerLogger.info("Metadata read back: Device=%s, Quality=%s" % [device, quality], "EXAMPLE_BOOT")
