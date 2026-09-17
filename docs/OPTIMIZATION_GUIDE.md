# Mobile Game Optimization Guide

CPU & VRAM optimization architecture for this template — texture strategy, scene
structure, singleton services, and memory management.

Every manager in `game/` already cites these sections in its comments
(`# PDF §4 CPU`, `# PDF §5 (Big scenes)`, `# PDF §6 Time Complexity`, ...). This
file is what those comments point to — keep section numbers stable when editing
so the in-code references stay correct.

---

## §1 Texture & Atlas Strategy

Texture atlases are reserved for a specific purpose, not used everywhere by default:

- **Atlas textures** — only for node-specific assets (tied to one particular
  scene/node context) and sprite-sheet animations.
- **Reusable assets** (UI icons, shared props, common effects) — kept as single
  sprites, never packed into an atlas. Packing a shared asset into a scene-local
  atlas forces the *whole atlas* to stay resident in VRAM whenever any one asset
  from it is needed, even if the rest of the scene isn't loaded.

> Rule of thumb: **Atlas → animation frames & scene-local art. Single sprite →
> anything reused across scenes.**

**Applies to:** everything placed under `game/assets/sprites/` (see §3 for the
folder split that enforces this).

---

## §2 Project Architecture — Layered Monolith

The game is a layered monolith: every node/script is self-contained and
auto-initializes itself on `_ready()`. Cross-system communication never happens
through direct node references — it's routed through a single connection point.

- Each node/script owns its own setup logic — no external code is required to
  initialize it.
- The single connection point for all systems is **`ServiceLocator`**
  (`game/autoloads/ServiceLocator.gd`) — this template's equivalent of
  the "Game Manager singleton." Managers `register()` themselves in `_ready()`;
  controllers `get_service()` to resolve dependencies.
- This keeps systems decoupled: any node can be restructured, moved, or replaced
  later without breaking other systems, since nothing holds direct references to
  internal node structure.

### Sub-managers under the root singleton

| Sub-manager | File | Status |
|---|---|---|
| Sound Manager | `game/scripts/managers/AudioManager.gd` | ✅ implemented |
| Event Bus | `game/autoloads/GameBus.gd` | ✅ implemented (autoload) |
| Haptics Handler | `game/scripts/managers/HapticsManager.gd` | ✅ implemented |
| Save Manager | `game/scripts/managers/SaveManager.gd` | ✅ implemented |

Why: decoupled sub-managers mean any single system (e.g. Save Manager) can be
rewritten or swapped without touching Sound, Haptics, or Event Bus code —
restructuring stays cheap as the project grows.

**Bootstrap wiring:** these managers are plain `Node`s, not autoloads (only
`ServiceLocator`, `GameBus`, `GameConfig`, `Logger` are autoloaded — see
`project.godot`). Add one instance of each manager as a child of your root/
bootstrap scene; each registers itself with `ServiceLocator` in `_ready()`.

---

## §3 Folder Structure

Assets are organized by asset type, not by feature, so the same kind of file
always lives in a predictable place. The whole Godot client is one flat
`game/` tree — no per-game vs. shared split, since within a single game's own
repo that distinction has no one left to draw it against. The only thing that
splits by anything other than type is `scenes/ui/`, which splits by fidelity
(`mfw/` vs `hfw/`) — see the README's *Prototype → MFW → HFW* section for why:

```
game/
├─ autoloads/                  ServiceLocator, GameBus, GameConfig, Logger
├─ scripts/
│  ├─ managers/                game_manager, sound_manager, haptics_handler,
│  │                           save_manager, scene_manager, ui_manager, ...
│  ├─ controllers/             nodes/ui equivalent
│  └─ utils/
├─ scenes/
│  ├─ boot/                    bootstrap scene — wires every manager
│  ├─ home/
│  ├─ gameplay/                main_scenes equivalent
│  ├─ loading/
│  └─ ui/
│     ├─ mfw/                  placeholder panels — build here first
│     └─ hfw/                  polished panels — same UIManager call, new scene
└─ assets/
   ├─ audio/
   ├─ fonts/
   └─ sprites/
      ├─ atlases/              PDF §1: scene-local & animation only
      │  ├─ animations/
      │  └─ node_specific/
      ├─ single/                PDF §1: anything reused across scenes
      │  ├─ ui/
      │  └─ shared/
      └─ backgrounds/
```

---

## §4 CPU Optimization

- Any node that is **not visible on screen** and is **not a singleton** should
  have its process mode disabled (no `_process` / `_physics_process` ticking)
  while off-screen or inactive, to avoid paying per-frame CPU cost for idle nodes.
- Re-enable processing only when the node becomes active/visible again — flip it
  back off on exit.

**Implemented in:**
- `UIController.gd` — `set_process(false)` / `set_physics_process(false)` by
  default for every screen/panel; subclasses opt back in.
- `AudioManager.gd` — idle SFX pool players have `process_mode = DISABLED`,
  re-enabled on `play()`, disabled again when playback finishes.
- `HapticsManager.gd` — idle by construction; no per-frame ticking at all.

---

## §5 Panel & UI Memory Management

- **Small panels** (under ~5–10 MB) — do not preload. Use a manager that
  instantiates a panel on demand, opens it, and frees it once the user closes
  it. This keeps VRAM usage minimal since nothing sits resident until needed.
- **Large scenes** — preload but do not instantiate them ahead of time.
  Preloading the resource avoids a disk-read/parse stall at the moment of use,
  while withholding instantiation avoids paying the CPU/memory cost of a live
  scene tree running in the background before it's needed.

> Pattern: small UI = **on-demand instantiate + free** (queue-managed). Big
> scenes = **preload resource, instantiate late**.

**Implemented in:**
- `UIManager.gd` — `push_packed()` instantiates on demand; `pop()` calls
  `queue_free()` immediately.
- `SceneManager.gd` — `preload_scene()` loads the resource without touching the
  scene tree; `go_to()` reuses the cached resource for a zero-stall transition.

---

## §6 Dependency Injection & Code Principles

Every script self-initializes, but when it needs a reference to another system,
that reference is obtained via dependency injection from `ServiceLocator` —
**never** through a direct node reference/path (`get_node("../../Panel/Sound")`).

### SOLID & DRY — strictly enforced

- **Single Responsibility** — every script/class does exactly one job. A script
  handling more than one concern (e.g. UI + save logic + sound) gets split.
- **DRY** — no duplicated logic across scripts. Shared behavior goes into a
  common utility, base class, or manager, called from one place.

### Time complexity for long operations

For any operation over large data sets, loops per-frame, or many nodes
(searches, sorting, batch updates, pathfinding, save/load serialization), write
it with the lowest practical time complexity rather than the first working
approach:

- Prefer O(1)/O(log n) lookups (dictionaries, hash maps) over O(n) linear scans
  when checking membership or fetching by key.
- Avoid nested loops over large collections (O(n²)) where a single pass with a
  lookup table (O(n)) achieves the same result.
- Cache results of expensive repeated calculations instead of recomputing them
  every call/frame.
- Batch or amortize heavy one-off operations rather than blocking a single frame.

**Implemented in:** `ServiceLocator.gd` (DI hub), `Logger.gd` (O(1) level gate,
cached tag array), `PlatformUtils.gd` (cached platform detection),
`SaveManager.gd` / `SceneManager.gd` (O(1) Dictionary caches).

---

## §7 VRAM & Image Compression

- **Large images** — backgrounds, full play-area art, gradients — are exported
  with VRAM compression (ETC2/ASTC on mobile, BCn on desktop) rather than left
  as raw/lossless textures, since VRAM compression reduces both GPU memory
  footprint and bandwidth.
- **Images larger than 10 MB** are additionally run through **Basis Universal**
  transcoding, which produces a format that is small on disk *and* transcodes to
  a compressed GPU format at load time — cutting both disk size and VRAM usage.

**Where to set this:** Godot Editor → Import dock, per texture, or
Project Settings → Import Defaults for `texture` to set the default across the
whole project. Set the default before art starts landing in `assets/sprites/`
and `assets/backgrounds/` so nothing has to be re-imported later.

---

## Summary

| Concern | Technique | Benefit |
|---|---|---|
| Textures | Atlas = scene-local & animation only; reusable art = single sprite | Avoids forcing whole atlas into VRAM for shared assets |
| Architecture | Layered monolith, self-initializing nodes, single `ServiceLocator` | Decoupled code, cheap restructuring |
| Sub-systems | Sound / Event Bus / Haptics / Save as sub-managers | Isolated, swappable systems |
| Folders | `assets/` organized by type: atlases, single, backgrounds | Predictable, scalable project layout |
| CPU (idle nodes) | Disable process mode on off-screen, non-singleton nodes | Lower per-frame CPU cost |
| Small panels | Instantiate on demand, free after close | Clean VRAM, no idle instances |
| Big scenes | Preload resource, instantiate only when needed | Avoids background CPU cost while still avoiding load stalls |
| Large images | VRAM compression; Basis Universal for >10 MB | Smaller disk size and lower VRAM footprint |
| Dependencies | Self-init own state; inject external refs via `ServiceLocator` | Swappable, testable, loosely-coupled nodes |
| Code quality | Strict SOLID (esp. Single Responsibility) & DRY | Prevents architecture decay as project scales |
| Algorithms | Lowest practical time complexity for long/batch operations | Avoids frame drops and CPU spikes on heavy operations |

**Core principle:** keep everything that isn't currently needed either
disabled, unloaded, or compressed — and keep every system decoupled behind one
singleton entry point so the project stays easy to restructure as it grows.
