# Unified Game Data Persistence & Cloud Synchronization Framework (Godot 4.x)

A production-grade, offline-first data persistence and cloud synchronization framework for Godot 4.x, implementing the studio's **Unified Game Data Model** specification (`android_users/{uid}` and `ios_users/{uid}`).

---

## 🚀 Quick Setup: Dropping into Any New Game

Follow these 6 steps to integrate this framework into any new Godot 4.x project:

### Step 1: Copy the Addon Folder
Copy the entire `addons/datamanager/` folder into your new Godot project's root:
```
res://addons/datamanager/
```

---

### Step 2: Enable the Plugin & Autoloads
In the Godot Editor, go to **Project -> Project Settings -> Plugins** and enable **DataManager**.

*Or alternatively, add this to your new project's `project.godot` file:*
```ini
[autoload]
DataManagerConfig="*res://addons/datamanager/autoload/Config.gd"
DataManagerSignals="*res://addons/datamanager/autoload/Signals.gd"
SyncManager="*res://addons/datamanager/autoload/SyncManager.gd"
DataManager="*res://addons/datamanager/autoload/DataManager.gd"

[editor_plugins]
enabled=["res://addons/datamanager/plugin.cfg"]
```

---

### Step 3: Initialize the Bootstrapper on Startup
In whatever script runs first when your game boots up (e.g. `GameService.gd`, `Main.gd`, or your root startup node):

```gdscript
func _ready() -> void:
    # 1. Instantiate the Unified Bootstrapper
    var bootstrapper = UnifiedBootstrapper.new()
    bootstrapper.name = "UnifiedBootstrapper"
    add_child(bootstrapper)
```

> **What this does automatically:**
> - Registers all 13 unified data buckets into memory (`identity`, `profile`, `device`, `metadata`, `session`, `settings`, `progression`, `economy`, `inventory`, `liveOps`, `stats`, `tutorials`, `monetization`).
> - Loads existing local disk saves into cache (or creates fresh defaults).
> - Increments session counts and tracks player screen time.

---

### Step 4: Wire Auth Lifecycle (Login / Logout)
Whenever your game's authentication system (Firebase, Guest, Google Play Games, Apple Game Center) completes login or logout:

```gdscript
# When player logs in:
DataManagerSignals.login_changed.emit(player_uid, true)

# When player logs out / session ends:
DataManagerSignals.login_changed.emit("", false)
```

> **What this does automatically:**
> - Sets the user ID and credentials in the `identity` repository.
> - Automatically triggers cloud synchronization (downloading cloud backup and performing conflict resolution).

---

### Step 5: (Optional) Plug in a Custom Backend
If your game uses a custom backend (REST API, Supabase, Nakama, Custom WebSocket), inject your adapter:

```gdscript
# If you implemented a custom adapter extending ICloudStorage:
DataManager.set_cloud_storage(MyCustomBackendAdapter.new())
```
*(If omitted, it uses the built-in `FirestoreStorage` engine which works seamlessly offline and with standard Firestore).*

---

### Step 6: Use Player Data Anywhere in Your Game

```gdscript
# --- Economy Example ---
var economy = DataManager.economy_repo
if economy:
    var data = economy.get_economy_data()
    data.currencies["coins"] = int(data.currencies.get("coins", 0)) + 500
    economy.mark_dirty()
    DataManager.save()

# --- Progression Example ---
var progression = DataManager.progression_repo
if progression:
    var data = progression.get_progression_data()
    data.current_level = 5
    data.level_stars["stage_5"] = 3
    progression.mark_dirty()
    DataManager.save()

# --- Direct Mutation Callback Example ---
DataManager.profile_repo.mutate(func(prof: ProfileData):
    prof.display_name = "ShadowNinja"
)
DataManager.save()

# --- Metadata Key-Value Store ---
DataManager.set_metadata("favorite_mode", "endless")
DataManager.save()
```

---

## 📦 The 13 Unified Data Buckets & Repositories

| # | Bucket Name | Model Class | Repository Class | Description |
|---|---|---|---|---|
| 1 | `identity` | `IdentityData` | `IdentityRepository` | User UID, Auth Provider, Sign-in state, Email, FCM token |
| 2 | `profile` | `ProfileData` | `ProfileRepository` | Display name, custom name flag, avatar ID, frame ID, badge ID, country code |
| 3 | `device` | `DeviceData` | `DeviceRepository` | Installed app version & device info |
| 4 | `metadata` | `MetadataData` | `MetadataRepository` | Schema version, revision counter, created/login/saved timestamps, dirty map |
| 5 | `session` | `SessionData` | `SessionRepository` | Total screen time, session count, first/last session UTC dates |
| 6 | `settings` | `SettingsData` | `SettingsRepository` | Music, SFX, Haptics, Volume levels, Notifications, Locale |
| 7 | `progression` | `ProgressionData` | `ProgressionRepository` | Current level, highest unlocked level, level stars map, XP, achievements |
| 8 | `economy` | `EconomyData` | `EconomyRepository` | Multi-currency (Coins, Gems, Energy, Custom), refill timers, overdraft guards |
| 9 | `inventory` | `InventoryData` | `InventoryRepository` | Equipped cosmetics, consumables, items map, booster counts |
| 10 | `liveOps` | `LiveOpsData` | `LiveOpsRepository` | Daily reward streak/claim timestamps, active events, battle pass tier |
| 11 | `stats` | `StatsData` | `StatsRepository` | Matches played, matches won, win streaks, custom game statistics |
| 12 | `tutorials` | `TutorialsData` | `TutorialsRepository` | Map of seen tutorials, complete tutorial flags |
| 13 | `monetization` | `MonetizationData` | `MonetizationRepository` | Payer flag, total spend USD, purchase history ledger, Remove Ads status |

---

## 🧪 Running Automated Unit Tests

This addon includes a complete standalone test suite. You can run it via the Godot console:

```powershell
# 1. Run Unified Models & Repositories Test Suite (46 Tests)
godot --headless --path . -s addons/datamanager/tests/UnifiedModelsTest.gd

# 2. Run Core Framework Integration Test Suite (12 Tests)
godot --headless --path . addons/datamanager/tests/DataFrameworkTest.tscn
```
