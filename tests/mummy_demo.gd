extends SceneTree
var game
var elapsed = 0.0
var captured = false
func _initialize(): call_deferred("begin")
func begin():
	game = load("res://main.tscn").instantiate()
	root.add_child(game)
	game.start_mummy()
	game.players[0].x = 650.0
	game.players[0].inv = 0
	game.enemies.clear()
	game.combat.waves_sent = 4
	game.boss_hp = 160
	game.camera_x = 320
	process_frame.connect(drive)
func drive():
	elapsed += 1.0 / 30
	game.controls = [elapsed > 5.1, elapsed < 2.1, elapsed > 4.1 and elapsed < 4.45, elapsed > 2.6 and elapsed < 3.9, false, false]
	if elapsed > 1.0 and not captured:
		captured = true
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://previews/Gulf-War-mummy.png")
	if elapsed > 6.5: quit()
