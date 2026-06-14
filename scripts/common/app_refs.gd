class_name AppRefs
extends RefCounted


static func _root() -> Node:
	var main_loop := Engine.get_main_loop()
	if main_loop is SceneTree:
		return (main_loop as SceneTree).root
	return null


static func event_bus():
	var root := _root()
	return root.get_node_or_null("/root/EventBus") if root != null else null


static func run_state():
	var root := _root()
	return root.get_node_or_null("/root/RunState") if root != null else null


static func data_repo():
	var root := _root()
	return root.get_node_or_null("/root/DataRepo") if root != null else null


static func scene_router():
	var root := _root()
	return root.get_node_or_null("/root/SceneRouter") if root != null else null


static func story_director():
	var root := _root()
	return root.get_node_or_null("/root/StoryDirector") if root != null else null
