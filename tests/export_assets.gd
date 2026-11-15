extends SceneTree

func _initialize():
	var checks = {
		"res://assets/actors.webp": Vector2i(1448, 1086),
		"res://assets/cave.webp": Vector2i(1536, 1024),
		"res://assets/desert.webp": Vector2i(1536, 1024),
		"res://assets/drone.webp": Vector2i(1682, 935),
		"res://assets/mech.webp": Vector2i(1496, 1051),
		"res://assets/tank.webp": Vector2i(1774, 887),
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
	var music = load("res://assets/action_loop.wav")
	if music == null or not music is AudioStreamWAV or music.get_length() < 7:
		push_error("Music failed to load from export")
		quit(1)
		return
	print("PASS: music loaded from export")
	quit()
