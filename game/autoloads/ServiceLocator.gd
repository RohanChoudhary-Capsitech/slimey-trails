extends Node

# ServiceLocator — DI container for all managers
#
# Managers call register() in their _ready()
# Controllers call get_service() to resolve dependencies
#
# Usage:
#   ServiceLocator.register(&"AudioManager", self)
#   var audio: AudioManager = ServiceLocator.get_service(&"AudioManager")

var _registry: Dictionary = {}

func register(key: StringName, service: Node) -> void:
	if _registry.has(key):
		push_warning("ServiceLocator: Overwriting service: " + key)
	_registry[key] = service
	# Logger.debug("Service registered", { "key": str(key) })

func get_service(key: StringName) -> Node:
	if not _registry.has(key):
		push_error("ServiceLocator: Service not found: " + key)
		return null
	return _registry[key]

func has_service(key: StringName) -> bool:
	return _registry.has(key)

func unregister(key: StringName) -> void:
	_registry.erase(key)
	# Logger.debug("Service unregistered", { "key": str(key) })
