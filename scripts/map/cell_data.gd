class_name CellData
extends RefCounted


const TERRAIN_PLAIN := &"plain"
const TERRAIN_MOUNTAIN := &"mountain"
const TERRAIN_WATER := &"water"

var cell: Vector2i
var terrain: StringName = TERRAIN_PLAIN
var discovered := false
var buildable := true
var occupied := false
var walkable := true
var resource_type: StringName = &""
var building_runtime_id := -1
var unit_runtime_id := -1
var spawn_key: StringName = &""
var is_core := false


func is_terrain_blocking() -> bool:
	return terrain == TERRAIN_MOUNTAIN or terrain == TERRAIN_WATER


func set_base_terrain(value: StringName) -> void:
	terrain = value
	var blocked := is_terrain_blocking()
	walkable = not blocked
	buildable = not blocked
