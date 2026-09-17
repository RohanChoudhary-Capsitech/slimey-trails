extends Node

# GameBus — global signal bus
# Nothing talks to each other directly — everything goes through signals here
#
# Emit:   GameBus.player_died.emit()
# Listen: GameBus.player_died.connect(_on_player_died)

# ── Player ────────────────────────────────────────────────────────────────
signal player_died
signal player_respawned
signal score_changed(new_score: int)
signal health_changed(new_health: int, max_health: int)

# ── Game State ────────────────────────────────────────────────────────────
signal game_started
signal game_paused
signal game_resumed
signal game_over(reason: String)
signal level_started(level_id: String)
signal level_completed(level_id: String)

# ── Economy ───────────────────────────────────────────────────────────────
signal coins_changed(new_amount: int)
signal item_unlocked(item_id: String)
signal purchase_completed(product_id: String)

# ── UI ────────────────────────────────────────────────────────────────────
signal screen_opened(screen_name: String)
signal screen_closed(screen_name: String)

# ── Network ───────────────────────────────────────────────────────────────
signal auth_completed(uid: String)
signal auth_failed(reason: String)
signal sync_completed
signal sync_failed(reason: String)
