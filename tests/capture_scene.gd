extends SceneTree

func _initialize():
	call_deferred("capture")

func capture():
	var game = load("res://main.tscn").instantiate()
	root.add_child(game)
	game.start_game(true)
	game.online = false
	game.set_process(false)
	game.players[0].x = 2650.0
	game.players[1].x = 2740.0
	game.players[0].cd = 0.12
	game.players[1].cd = 0.12
	game.camera_x = 2440.0
	game.clock = 0.18
	game.enemies = [{"x": 2930.0, "hp": 12, "cd": 1.4}]
	for x in [2800, 2880, 3010]:
		game.spawn_shot(x, 364, 760, 0, false, false)
	game.particles = []
	game.queue_redraw()
	await process_frame
	await RenderingServer.frame_post_draw
	var img = root.get_texture().get_image()
	var err = img.save_png("res://previews/Gulf-War-in-game.png")
	print("Scene screenshot saved: ", err)
	quit(err)
