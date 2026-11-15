extends SceneTree
var game
var time = 0.0
var captured = false
var added_wave = false
var captured_early = false
func _initialize(): call_deferred("begin")
func begin():
	game = load("res://main.tscn").instantiate()
	root.add_child(game)
	game.start_game(true, 2)
	game.online = false
	game.players[0].x = 1150.0
	game.players[1].x = 1240.0
	for p in game.players: p.inv = 50
	game.camera_x = 900
	for e in game.enemies: e.hp = 0
	game.combat.spawn_wave(1100, 1)
	game.combat.units[0].x = 1630
	game.combat.units[1].x = 1760
	game.combat.waves_sent = 2
	process_frame.connect(drive)
func drive():
	time += 1.0 / 30
	game.controls = [false, time < 1.6, time > 0.6 and time < 0.95, true, time > 3.2 and time < 3.25, time > 1.7 and time < 1.75]
	game.remote_controls = [false, time < 1.0, time > 2.8 and time < 3.2, true, false, false]
	if time > 4 and not added_wave:
		game.combat.spawn_wave(game.players[0].x, 3)
		added_wave = true
	if time > 1.05 and not captured_early:
		captured_early = true
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://previews/Gulf-War-cave-combat.png")
	if time > 2.0 and not captured:
		captured = true
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://previews/Gulf-War-cave.png")
	if time > 7.5: quit()
