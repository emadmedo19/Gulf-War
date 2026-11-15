extends SceneTree

func _initialize():
	var checks = {
		"res://assets/desert.webp": Vector2i(1536, 1024),
		"res://assets/actors.webp": Vector2i(1448, 1086),
		"res://assets/mech.webp": Vector2i(1496, 1051),
	}
	for path in checks:
		var texture = load(path)
		if texture == null or not texture is Texture2D:
			push_error("Artwork could not be loaded: " + path)
			quit(1)
			return
		if texture.get_width() != checks[path].x or texture.get_height() != checks[path].y:
			push_error("Artwork dimensions do not match: " + path)
			quit(1)
			return
		var decoded = texture.get_image()
		if decoded == null or decoded.is_empty():
			push_error("Artwork has no decoded pixels: " + path)
			quit(1)
			return
		print("PASS: texture loaded from export: ", path)
	quit()
