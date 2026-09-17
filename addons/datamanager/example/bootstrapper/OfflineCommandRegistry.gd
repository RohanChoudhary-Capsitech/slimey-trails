extends RefCounted
class_name OfflineCommandRegistry

## Registers all offline command handlers to the SyncManager.
static func register_handlers() -> void:
	var sync_manager = Engine.get_main_loop().root.get_node_or_null("/root/SyncManager")
	if not sync_manager:
		push_error("[OfflineCommandRegistry] SyncManager autoload not found.")
		return

	# Handler for adding coins earned offline
	sync_manager.register_command_handler("add_offline_coins", func(payload: Dictionary) -> DataResult:
		var repo = Engine.get_main_loop().root.get_node("/root/DataManager").get_repository("Currency") as ExampleCurrencyRepository
		if repo:
			repo.add_coins(int(payload.get("amount", 0)))
			repo.add_gold_stamps(int(payload.get("gold_stamps", 0)))
			return DataResult.ok()
		return DataResult.fail(DataErrors.Code.VALIDATION_ERROR, "Currency repository not found.")
	)

	# Handler for unlocking skins purchased offline
	sync_manager.register_command_handler("unlock_offline_skin", func(payload: Dictionary) -> DataResult:
		var repo = Engine.get_main_loop().root.get_node("/root/DataManager").get_repository("Cosmetics") as ExampleCosmeticsRepository
		if repo:
			repo.unlock_skin(str(payload.get("skin_id", "")))
			return DataResult.ok()
		return DataResult.fail(DataErrors.Code.VALIDATION_ERROR, "Cosmetics repository not found.")
	)

	# Handler for recording gameplay runs completed offline
	sync_manager.register_command_handler("record_offline_run", func(payload: Dictionary) -> DataResult:
		var repo = Engine.get_main_loop().root.get_node("/root/DataManager").get_repository("Progression") as ExampleProgressionRepository
		if repo:
			var score = int(payload.get("score", 0))
			var jumps = int(payload.get("jumps", 0))
			repo.update_high_score(score)
			repo.record_jumps(jumps)
			repo.record_height(score)
			return DataResult.ok()
		return DataResult.fail(DataErrors.Code.VALIDATION_ERROR, "Progression repository not found.")
	)

	DataManagerLogger.info("Offline command handlers successfully registered.", "EXAMPLE_BOOT")
