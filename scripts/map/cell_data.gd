class_name CellData
extends RefCounted


var cell: Vector2i
var terrain: StringName = &"plain"
var discovered := false
var buildable := true
var occupied := false
var walkable := true
var resource_type: StringName = &""
var building_runtime_id := -1
var unit_runtime_id := -1
var spawn_key: StringName = &""
var is_core := false
