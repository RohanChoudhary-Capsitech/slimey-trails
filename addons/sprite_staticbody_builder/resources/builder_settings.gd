@tool
class_name SpriteStaticBodySettings
extends Resource

@export_range(0.01, 1.0, 0.01) var alpha_threshold: float = 0.5
@export var simplification_level: int = 1 # 0: Low, 1: Medium, 2: High, 3: Custom
@export_range(0.1, 20.0, 0.1) var custom_epsilon: float = 2.5
@export_range(3, 512, 1) var max_polygon_points: int = 64
@export var collision_mode: int = 0 # 0: Single Polygon, 1: Convex Decomposition
@export var create_staticbody: bool = true
@export var keep_original_sprite: bool = true
@export var generate_collision_auto: bool = true
