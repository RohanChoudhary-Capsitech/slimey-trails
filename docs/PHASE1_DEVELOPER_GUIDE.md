# 🎮 Phase 1 Developer Guide — Architecture & Data Management

Welcome to the Godot Template! This guide explains how to build gameplay features, manage game state, and persist data during **Phase 1** of development.

---

## 🧭 Architecture Overview

The project uses a structured two-pillar service architecture to keep gameplay code clean, decoupled, and forward-compatible:

```
                  ┌───────────────────────────────┐
                  │       Godot Engine Root       │
                  └───────────────┬───────────────┘
                                  │
         ┌────────────────────────┴────────────────────────┐
         ▼                                                 ▼
┌───────────────────┐                             ┌───────────────────┐
│    GameService    │                             │  BackendService   │
├───────────────────┤                             ├───────────────────┤
│ • audio           │                             │ • data (DM)       │
│ • game            │                             │ • data_signals    │
│ • haptics         │                             │ • data_config     │
│ • network         │                             │ • data_sync       │
│ • save (Facade)   │                             │ • firebase (stub) │
│ • scene           │                             │ • ads (stub)      │
│ • ui              │                             │ • analytics (stub)│
│ • logger          │                             └───────────────────┘
│ • bus (signals)   │
└───────────────────┘
```

* **`GameService`**: Single entry point for runtime gameplay managers, the save facade, and event bus (`.save`, `.audio`, `.game`, `.ui`, `.scene`, `.logger`, `.bus`).
* **`BackendService`**: Single entry point for persistent game data (`.data`), data lifecycle signals (`.data_signals`), storage settings (`.data_config`), and cloud synchronization (`.data_sync`).

---

## 📌 The 4 Golden Rules for Phase 1

1. **Access all gameplay features via `GameService`**:
   - `GameService.save.save_game()`
   - `GameService.audio.play_sfx("click")`
   - `GameService.ui.show_screen("MainMenu")`
   - `GameService.logger.info("Player spawned")`
2. **Access persistent state via `GameService.save` or `BackendService.data`**:
   - Typed bucket data: `GameService.save.profile.get_profile_data().display_name = "Alex"`
   - Metadata key-value: `GameService.save.set_value("vip_member", true)`
   - **Never** write raw files (`FileAccess`, `ConfigFile`) inside gameplay scripts.
3. **Never write Firebase / Cloud networking code in Phase 1**:
   - Cloud synchronization is completely decoupled and will be enabled in Phase 2 via configuration alone.
4. **Mark dirty on direct model mutations**:
   - When modifying a model property directly, call `repo.mark_dirty()` or use `repo.mutate(func)`.

---

## 🛠️ Data Access Cheat Sheet

### 1. Direct Typed Access on Repositories (Standard Pattern)

All persistent data is organized into 13 typed domain buckets accessible via `GameService.save.<bucket>` or `BackendService.data.<bucket>_repo`:

```gdscript
# 🪙 Economy (currencies dictionary)
var econ = GameService.save.economy.get_economy_data()
econ.currencies["coins"] = int(econ.currencies.get("coins", 0)) + 100
GameService.save.economy.mark_dirty()

# 🏆 Progression (level, stars, xp)
var prog = GameService.save.progression.get_progression_data()
prog.current_level = 2
prog.level_stars["stage_1"] = 3
prog.xp += 150
GameService.save.progression.mark_dirty()

# 👤 Profile (name, avatar)
var prof = GameService.save.profile.get_profile_data()
prof.display_name = "ShadowNinja"
prof.avatar_id = "ninja_01"
GameService.save.profile.mark_dirty()

# 🎒 Inventory (boosters, equipped)
var inv = GameService.save.inventory.get_inventory_data()
inv.boosters["bomb_booster"] = int(inv.boosters.get("bomb_booster", 0)) + 3
inv.equipped["trail"] = "trail_fire"
GameService.save.inventory.mark_dirty()

# ⚙️ Settings (volumes, locale)
var s = GameService.save.settings.get_settings_data()
s.music_enabled = true
s.sfx_volume = 0.8
s.locale = "en"
GameService.save.settings.mark_dirty()
```

---

### 2. Functional `mutate(Callable)` Pattern

If you prefer a callback pattern, `mutate()` automatically calls `mark_dirty()`:

```gdscript
GameService.save.inventory.mutate(func(inv: InventoryData):
    inv.equipped["skin"] = "skin_gold"
)
```

---

### 3. Arbitrary Metadata (Key-Value Store)

For quick, custom flags that don't need dedicated models:

```gdscript
# Write
GameService.save.set_value("vip_member", true)
GameService.save.set_value("selected_mode", "hardcore")

# Read with fallback
var is_vip: bool = GameService.save.get_value("vip_member", false)
var has_key: bool = GameService.save.has("vip_member")
```

---

### 4. Persistence Lifecycle & Transactions

```gdscript
# Save dirty buckets to local disk
GameService.save.save_game()

# Reload from local disk
GameService.save.load_game()

# Wipe memory & local disk saves
GameService.save.clear_all()

# Atomic multi-bucket transaction
GameService.save.begin_transaction()
# ... modify multiple buckets ...
GameService.save.commit_transaction() # Or GameService.save.rollback_transaction()
```

---

## 💾 Saving Data: Local Auto-Save vs Explicit Save

### 1. Explicit Save (Always Call on Key Events)
Always explicitly call `save_game()` after meaningful game actions (e.g. completing a stage, purchasing an item, upgrading a stat, or exiting to the main menu):
```gdscript
GameService.save.save_game()
```
> ⚠️ **Important for Editor Testing:** When running the game from the Godot Editor, clicking the editor's **"Stop" button (F8)** forcibly terminates the process without sending close notifications. Always call `save_game()` explicitly in your game logic so you don't lose test progress!

---

### 2. Built-In Local Auto-Save (Configured in `Config.gd`)
Local auto-saving is enabled by default to protect player progress:
* **Periodic Timer (`autosave_enabled = true`)**: Saves dirty models to local disk every **5 minutes** (`autosave_interval_seconds = 300.0`).
* **App Pause / Focus Loss (`autosave_on_pause = true`)**: Automatically saves when the player minimizes the game or switches apps on mobile.
* **Graceful App Quit (`autosave_on_quit = true`)**: Automatically saves when the game window is closed gracefully.

---

### 3. What is Disabled in Phase 1? (Cloud Sync)
To keep Phase 1 strictly offline and local, all cloud-related syncing is disabled in `Config.gd`:
* `cloud_enabled = false` ➔ All cloud network calls and Firestore authentication are turned off.
* `sync_on_save = false` ➔ `save()` writes directly to local disk without attempting cloud uploads.
* `periodic_sync_enabled = false` ➔ Background cloud sync timers are disabled.

---

## 🔍 Save File Formats: `.json` (Debug) vs `.dat` (Release)

The framework automatically manages save formats based on your build environment:

* **In Editor & Debug Builds (`.json`)**:
  Saves are stored as **plain, human-readable JSON files** under `user://saves/`:
  ```
  user://saves/
  ├── economy.json
  ├── progression.json
  ├── inventory.json
  ├── profile.json
  ├── settings.json
  └── metadata.json
  ```
  > 💡 **Developer Cheat**: You can open any `.json` file in VS Code or Notepad, edit `coins: 999999`, save the file, and reload the game to test features immediately.

* **In Exported Release Builds (`.dat`)**:
  When exported as a non-debug release (e.g. production APK or iOS build), `Config.gd` automatically enables password encryption and switches file extensions:
  ```
  user://saves/
  ├── economy.dat
  ├── progression.dat
  ├── inventory.dat
  └── ... (encrypted binary files)
  ```
  This protects player saves from casual file modification and hex-editing on end-user devices.

* **Automatic Dual Fallback**:
  `LocalStorage` automatically detects and supports both formats (`.json` and `.dat`). Switching between debug and release builds occurs seamlessly without losing data.

* **Save Directory Location on Disk**:
  - **Windows**: `%APPDATA%\Godot\app_userdata\GameTemplate\saves\`
  - **macOS**: `~/Library/Application Support/Godot/app_userdata\GameTemplate\saves\`
  - **Linux**: `~/.local/share/godot/app_userdata/GameTemplate/saves/`

---

## ➕ How to Add or Remove Fields in Models

Thanks to **Automatic Reflection in `BaseModel`**, adding or removing persistent fields is **just a 1-line variable declaration**. You do **NOT** need to write `serialize()`, `deserialize()`, `clone()`, or `equals()` by hand!

### 1. Adding a Strongly-Typed Field
If you want to add a variable to a model (e.g., adding `player_title` to `ProfileData.gd`):

1. Open `addons/datamanager/models/ProfileData.gd`.
2. Add your variable:
   ```gdscript
   var player_title: String = "Novice"
   ```
3. **Done!** Read and write to it immediately:
   ```gdscript
   # Write
   GameService.save.profile.get_profile_data().player_title = "Dragon Slayer"
   GameService.save.profile.mark_dirty()

   # Read
   var title = GameService.save.profile.get_profile_data().player_title
   ```

### 2. Removing a Field
Simply delete the variable line from the model file. Obsolete keys in older save files will be safely ignored on load.

---

### 💡 Alternative: Zero-Code Dynamic Key-Values
If you don't want to edit model files, use the built-in metadata store:
```gdscript
GameService.save.set_value("unlocked_secret_skin", true)
GameService.save.set_value("boss_attempts", 3)
```

---

## 🚫 Common Pitfalls to Avoid

| ❌ What NOT to do | ✅ What to do instead |
| :--- | :--- |
| Writing raw `FileAccess` or `ConfigFile` saves | Use `GameService.save.save_game()` |
| Modifying a model without marking dirty | Call `repo.mark_dirty()` or `repo.mutate(func)` |
| Storing runtime node references in data models | Only store serializable primitives (ints, floats, strings, dicts, arrays) |
| Calling Firebase/Firestore directly in gameplay code | Let `DataManager` handle cloud sync in Phase 2 |

---

## 🚀 Phase 2 Cloud Readiness & Sync Examples

Because Phase 1 strictly adheres to this repository structure:
- **Zero Rework**: When Phase 2 begins, flipping `cloud_enabled = true` in `Config.gd` will automatically sync all Phase 1 local progress to Firestore.
- **Offline Mode for Free**: When Phase 2 ships, if a player loses internet connection, the game automatically falls back to Phase 1 offline behavior seamlessly.

### Phase 2 Code Patterns

#### 1. Triggering Authentication & Automatic Cloud Sync
When the player logs in (via Guest, Google Play Games, or Apple Game Center), emitting `login_changed` automatically connects and triggers the initial synchronization:
```gdscript
# When login succeeds:
BackendService.data_signals.login_changed.emit(player_uid, true)
```

#### 2. Manual Cloud Synchronization
To explicitly trigger a two-way sync (uploading local dirty data and pulling down newer cloud changes):
```gdscript
var res: DataResult = await GameService.save.sync_cloud()
if res.success:
    GameService.logger.info("Cloud synchronization complete!")
else:
    GameService.logger.warning("Sync failed: " + res.error_message)
```

#### 3. Registering Offline Queue Command Handlers (Via `data_sync`)
If you have custom actions that occurred while offline (e.g. claiming a timed reward) and need custom processing when the game reconnects:
```gdscript
func _ready() -> void:
    BackendService.data_sync.register_command_handler("claim_timed_reward", func(payload: Dictionary) -> DataResult:
        var reward_id = payload.get("reward_id", "")
        var econ = GameService.save.economy.get_economy_data()
        econ.currencies["coins"] = int(econ.currencies.get("coins", 0)) + 100
        GameService.save.economy.mark_dirty()
        return DataResult.ok()
    )
```
