extends Node

@onready var status_label: Label = $VBoxContainer/StatusLabel
@onready var log_label: RichTextLabel = $VBoxContainer/LogLabel

var save: SaveManager:
	get:
		var gs = get_node_or_null("/root/GameService")
		return gs.save if gs else null

func _ready() -> void:
	_log("[color=green]Scene loaded. Connecting to DataManager signals...[/color]")

	var bs = get_node_or_null("/root/BackendService")
	if bs and bs.data_signals:
		bs.data_signals.save_finished.connect(_on_save_finished)
		bs.data_signals.sync_finished.connect(_on_sync_finished)

	refresh_display()

# ── Actions ───────────────────────────────────────────────────────────────────

func _on_add_coins_pressed() -> void:
	if save and save.economy:
		var econ = save.economy.get_economy_data()
		econ.currencies["coins"] = int(econ.currencies.get("coins", 0)) + 100
		save.economy.mark_dirty()
		_log_info("Added 100 coins")
		_log("Added 100 coins to economy_repo.")
		refresh_display()

func _on_spend_coins_pressed() -> void:
	if save and save.economy:
		var econ = save.economy.get_economy_data()
		var current = int(econ.currencies.get("coins", 0))
		if current >= 50:
			econ.currencies["coins"] = current - 50
			save.economy.mark_dirty()
			_log_info("Spent 50 coins successfully")
			_log("Spent 50 coins.")
		else:
			_log_warn("Failed to spend coins: Insufficient balance")
			_log("[color=red]Cannot spend 50 coins: Insufficient balance![/color]")
		refresh_display()

func _on_complete_level_pressed() -> void:
	if save and save.progression:
		var prog = save.progression.get_progression_data()
		var curr_lvl: int = prog.current_level
		prog.level_stars["stage_" + str(curr_lvl)] = 3
		prog.current_level += 1
		prog.unlocked_levels = maxi(prog.unlocked_levels, prog.current_level)
		prog.xp += 150
		save.progression.mark_dirty()
		_log_info("Completed Level %d (3 Stars), Advanced to Level %d" % [curr_lvl, curr_lvl + 1])
		_log("Completed Level %d with 3 Stars (+150 XP). Unlocked Level %d." % [curr_lvl, curr_lvl + 1])
		refresh_display()

func _on_set_meta_pressed() -> void:
	if save:
		save.set_value("vip_member", true)
		save.set_value("player_tag", "AlphaTester")
		_log_info("Metadata flags updated")
		_log("Set metadata: vip_member = true, player_tag = 'AlphaTester'")
		refresh_display()

func _on_what_pressed() -> void:
	if save and save.profile:
		save.profile.get_profile_data().player_title = "Dragon Slayer"
		save.profile.mark_dirty()
		_log("Updated Profile player_title to 'Dragon Slayer'")
		refresh_display()

func _on_save_pressed() -> void:
	if save:
		var res: DataResult = save.save_game()
		if res and res.success:
			_log("Saved all dirty models to user://saves/")
		elif res:
			_log("[color=red]Save failed: " + res.error_message + "[/color]")
		refresh_display()

func _on_reload_pressed() -> void:
	if save:
		var res: DataResult = save.load_game()
		if res and res.success:
			_log("Reloaded save files from disk into active memory caches.")
		elif res:
			_log("[color=yellow]Load result: " + res.error_message + "[/color]")
		refresh_display()

func _on_clear_pressed() -> void:
	if save:
		save.clear_all()
		_log("[color=orange]Wiped all local memory caches and save files from user://saves/.[/color]")
		refresh_display()

# ── Display ───────────────────────────────────────────────────────────────────

func refresh_display() -> void:
	if not save:
		status_label.text = "Error: SaveManager / BackendService not ready."
		return

	var econ_data = save.economy.get_economy_data() if save.economy else null
	var coins: int = int(econ_data.currencies.get("coins", 0)) if econ_data else 0
	var is_economy_dirty: bool = save.economy.is_dirty() if save.economy else false

	var prog_data = save.progression.get_progression_data() if save.progression else null
	var curr_lvl: int = prog_data.current_level if prog_data else 1
	var stars: Dictionary = prog_data.level_stars if prog_data else {}
	var is_prog_dirty: bool = save.progression.is_dirty() if save.progression else false

	var is_vip: bool = save.get_value("vip_member", false)
	var tag: String = save.get_value("player_tag", "None")

	var prof_data = save.profile.get_profile_data() if save.profile else null
	var title: String = prof_data.player_title if prof_data else "Novice"
	var is_prof_dirty: bool = save.profile.is_dirty() if save.profile else false

	status_label.text = """
	📊 LIVE IN-MEMORY STATE:
	🪙 Coins: %d  |  Dirty: %s
	🏆 Current Level: %d  |  Stars: %s  |  Dirty: %s
	🏷️ Metadata: VIP=%s, Tag=%s
	👤 Profile: Title=%s  |  Dirty: %s
	""" % [coins, str(is_economy_dirty), curr_lvl, str(stars), str(is_prog_dirty), str(is_vip), tag, title, str(is_prof_dirty)]

# ── Signal Listeners & Helpers ────────────────────────────────────────────────

func _on_save_finished(res: DataResult) -> void:
	_log("[color=green]Signal: save_finished (Success: %s)[/color]" % str(res.success))

func _on_sync_finished(res: DataResult) -> void:
	_log("[color=cyan]Signal: sync_finished (Success: %s)[/color]" % str(res.success))

func _log(message: String) -> void:
	var time_str = Time.get_time_string_from_system()
	log_label.append_text("[%s] %s\n" % [time_str, message])

func _log_info(message: String) -> void:
	var gs = get_node_or_null("/root/GameService")
	if gs and gs.logger:
		gs.logger.info(message)

func _log_warn(message: String) -> void:
	var gs = get_node_or_null("/root/GameService")
	if gs and gs.logger:
		gs.logger.warn(message)

# ── Scene Button Aliases ──────────────────────────────────────────────────────

func _on_btn_add_coins_pressed() -> void: _on_add_coins_pressed()
func _on_btn_spend_coins_pressed() -> void: _on_spend_coins_pressed()
func _on_btn_complete_level_pressed() -> void: _on_complete_level_pressed()
func _on_btn_set_meta_pressed() -> void: _on_set_meta_pressed()
func _on_btn_save_pressed() -> void: _on_save_pressed()
func _on_btn_reload_pressed() -> void: _on_reload_pressed()
func _on_btn_clear_pressed() -> void: _on_clear_pressed()
