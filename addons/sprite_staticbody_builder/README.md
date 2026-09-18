# Sprite StaticBody Builder (Godot 4.6.2+)

A production-ready Godot 4 EditorPlugin that automatically converts any 2D sprite (`Sprite2D` or raw imported texture) into a `StaticBody2D` with precision `CollisionPolygon2D` geometry extracted from the sprite's alpha channel.

Designed specifically for 2D level design (platforms, curved walls, jagged rocks, slopes, irregular obstacles, and shapes with transparent holes).

---

## Features

- **Alpha-Based Silhouette Extraction**: Automatically analyzes pixel opacity and traces precise collision boundaries.
- **Irregular & Concave Geometry**: Works out of the box with slopes, curved terrain, jagged rocks, organic platformers, L-shapes, and U-shapes.
- **Transparent Holes / Donut Shapes**: Detects inner transparent loops and subtracts them via `Geometry2D.clip_polygons`, preventing phantom solid centers.
- **Two Collision Modes**:
  - **Single Polygon**: Continuous closed contour suitable for static walls and platforms.
  - **Convex Decomposition**: Automatically subdivides complex concave geometries or shapes with holes into a set of convex `CollisionPolygon2D` nodes using `Geometry2D.decompose_polygon_in_convex`.
- **Polygon Simplification**:
  - Presets: *Low (1.0px)*, *Medium (2.5px)*, *High (5.0px)*, and *Custom*.
  - Ramer-Douglas-Peucker (RDP) algorithm eliminates collinear points and micro-jitter.
  - **Max Points Guard**: Progressively decimates high-density contours so large PNGs never overwhelm 2D physics.
- **Full Transform Preservation**: Accurately aligns coordinates taking into account:
  - Sprite `position`, `rotation`, and `scale`
  - Sprite `centered` property
  - Sprite `offset`
  - Sprite `flip_h` and `flip_v`
  - Sprite `region_enabled` and `region_rect`
- **Real-Time Editor Viewport Preview**: Shows translucent green collision fill, bright outline, and vertex handles directly in the 2D editor over the sprite before applying.
- **Complete Undo / Redo**: Integrates with Godot's `EditorUndoRedoManager` (supports `Ctrl+Z` and `Ctrl+Y`).
- **Zero External Dependencies**: 100% self-contained GDScript using native Godot 4 APIs (`BitMap`, `Geometry2D`, `EditorPlugin`).

---

## Directory Structure

```
res://addons/sprite_staticbody_builder/
│
├── plugin.cfg                         # Plugin metadata
├── sprite_staticbody_plugin.gd        # Main EditorPlugin (@tool) & 2D viewport renderer
├── sprite_staticbody_dock.gd          # Dock UI controller script
├── sprite_staticbody_dock.tscn        # Dock UI scene layout
├── collision_generator.gd             # Alpha extraction, BitMap conversion, hole subtraction
├── polygon_simplifier.gd              # RDP decimation, vertex cleanup, convex decomposition
├── collision_preview.gd               # Viewport canvas overlay rendering
│
├── ui/
│   └── icons/
│       ├── icon_plugin.svg            # Plugin & dock icon
│       ├── icon_create.svg            # Create StaticBody icon
│       ├── icon_regenerate.svg        # Regenerate Collision icon
│       └── icon_preview.svg           # Preview eye icon
│
├── resources/
│   ├── builder_settings.gd            # Settings resource script
│   └── default_settings.tres          # Default presets resource
│
├── examples/
│   ├── example_scene.tscn             # Interactive test level with physics ball
│   └── textures/
│       ├── platform_curved.svg        # Irregular curved platform
│       ├── rock_broken.svg            # Jagged boulder with slopes & overhangs
│       └── doughnut_obstacle.svg      # Ring obstacle with transparent center hole
│
└── README.md
```

---

## Installation

1. Copy the `sprite_staticbody_builder` folder into your project's `res://addons/` directory:
   ```
   res://addons/sprite_staticbody_builder/


   ```

func _input()
2. Open your Godot project.

3. In the top menu, navigate to:
   **Project → Project Settings → Plugins**
4. Locate **"Sprite StaticBody Builder"** and check the **Enable** box.
5. The dock will appear in the top-right dock panel, ready for use.

---

## How to Use

### Workflow 1: Convert an Existing Sprite2D
1. Select any `Sprite2D` node in your scene tree.
2. In the **Sprite StaticBody Builder** dock:
   - Adjust **Alpha Threshold** (default: `0.50`).
   - Choose a **Simplification** level (*Medium* is recommended for level design).
   - Set **Max Points** (default: `64`).
   - Toggle **Preview Collision** to see the outline directly over the sprite.
3. Click **Create StaticBody**.
4. The plugin converts the node into:
   ```
   SpriteNameBody (StaticBody2D)
   ├── SpriteName (Sprite2D)
   └── CollisionPolygon2D
   ```
5. You can now drag, rotate, scale, or duplicate the resulting `StaticBody2D` anywhere in your level!

### Workflow 2: Create from Texture in FileSystem
1. Select any `.png`, `.svg`, or `.webp` file in the **FileSystem** dock.
2. The dock will detect `[ Detected Texture: my_rock.png ]`.
3. Click **Create StaticBody**.
4. A new `StaticBody2D` with the sprite and matching collision is instantly placed in your active scene.

### Workflow 3: Regenerate Collision
1. If you replace the sprite's texture or alter its threshold/simplification settings, select the sprite and click **Regenerate Collision**.
2. Only the `CollisionPolygon2D` nodes are updated. Custom scripts, child nodes, transforms, and metadata are strictly preserved.

---

## How the Alpha-to-Collision Algorithm Works

1. **Image Acquisition**:
   - Safely acquires the texture data as an uncompressed `Image` in `FORMAT_RGBA8`.
   - If `sprite.region_enabled` is active, crops to the region bounds.
2. **BitMap Alpha Extraction**:
   - Converts the pixel buffer into a Godot `BitMap` using `create_from_image_alpha(image, alpha_threshold)`.
   - Pixels with alpha $\ge \text{threshold}$ evaluate to `1` (solid); below evaluate to `0` (empty).
3. **Contour Tracing**:
   - Traces closed outlines with `bitmap.opaque_to_polygons()`.
4. **Hole Detection & Boolean Subtraction**:
   - Identifies inner contours that lie completely inside outer contours.
   - Executes boolean difference clipping (`Geometry2D.clip_polygons(outer, hole)`), producing an open-hole geometry without bridging solid collisions across transparent gaps.
5. **Ramer-Douglas-Peucker (RDP) & Decimation**:
   - Strips redundant collinear vertices.
   - If vertex count exceeds `max_points`, runs iterative adaptive tolerance decimation to guarantee tight physics bounds without performance drops.
6. **Local Coordinate Transformation**:
   - Accounts for `flip_h`, `flip_v`, `centered`, and `offset` to produce local coordinates that line up with the sprite's visual geometry down to the exact pixel.
7. **Convex Decomposition (Optional)**:
   - When Convex Decomposition mode is selected, invokes `Geometry2D.decompose_polygon_in_convex()` to produce multiple non-overlapping convex hulls.
