extends SceneTree
var game
var elapsed = 0.0

func _initialize():
	call_deferred("begin")

func begin():
	game = load("res://main.tscn").instantiate()
	root.add_child(game)
	game.start_game(true)
	game.online = false
	game.players[0].x = 2490.0
	game.players[1].x = 2580.0
	game.players[0].inv = 100.0
	game.players[1].inv = 100.0
	game.camera_x = 2200.0
	for e in game.enemies:
		if e.x < 2500: e.hp = 0
	process_frame.connect(drive)

func drive():
	if game == null: return
	elapsed += 1.0 / 30.0
	var move_right = elapsed < 1.4 or (elapsed > 3.7 and elapsed < 4.3)
	var move_left = elapsed > 2.8 and elapsed < 3.3
	var jump = (elapsed > 0.7 and elapsed < 1.05) or (elapsed > 3.7 and elapsed < 4.05)
	game.controls = [move_left, move_right, jump, elapsed < 5.6, elapsed > 2.0 and elapsed < 2.06]
	game.remote_controls = [false, elapsed < 0.8, elapsed > 1.3 and elapsed < 1.65, elapsed < 5.6, false]
	if elapsed > 5.7:
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://previews/Gulf-War-action.png")
		quit()
