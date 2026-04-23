class_name ActionResult
extends RefCounted


static func ok(payload: Dictionary = {}, message: String = "") -> Dictionary:
	return {
		"ok": true,
		"code": &"OK",
		"message": message,
		"payload": payload
	}


static func err(code: StringName, message: String, payload: Dictionary = {}) -> Dictionary:
	return {
		"ok": false,
		"code": code,
		"message": message,
		"payload": payload
	}
