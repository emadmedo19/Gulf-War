extends SceneTree

func _initialize():
	call_deferred("run")

func run():
	var game = load("res://main.tscn").instantiate()
	root.add_child(game)
	game.set_process(false)
	game.set_physics_process(false)
	game.start_game(false)
	game.enemies.clear()
	var p = game.players[0]
	for i in range(30): game.simulate(1.0 / 60, [false, true, false, false, false])
	assert(absf(p.vx - 255) < 0.1)
	for i in range(10): game.simulate(1.0 / 60, [false, false, false, false, false])
	assert(p.vx == 0)
	for i in range(100): game.simulate(1.0 / 60, [false, false, true, false, false])
	assert(p.y == game.GROUND, "Holding jump must not cause repeated jumping")
	game.simulate(1.0 / 60, [false, false, false, false, false])
	game.simulate(1.0 / 60, [false, false, true, false, false])
	assert(p.vy < -500)
	game.simulate(1.0 / 60, [false, false, false, false, false])
	assert(p.vy > -220, "Releasing jump should shorten the jump")
	game.start_game(false)
	var e = game.enemies[0]
	var before = e.x
	for i in range(30): game.simulate(1.0 / 60, [false, false, false, false, false])
	assert(e.x < before, "Enemies should approach the player")
	game.players[0].x = 2650
	var boss_before = game.boss_x
	game.boss_cooldown = 0
	game.simulate(1.0 / 60, [false, false, false, false, false])
	assert(game.boss_x < boss_before and game.boss_recoil > 0)
	game.effects.clear()
	game.dispatch_burst(100, 400, true)
	assert(game.effects.size() > 20)
	for i in range(100): game.local_fx(100, 400, "smoke", 20)
	assert(game.effects.size() <= 220)
	game._process(0.08)
	assert(game.effects.size() <= 220)
	game.host = false
	var packet = game.players.duplicate(true)
	packet[0].x = 800
	game.snapshot(packet, game.enemies, [], 80, 123, false, 3100, 1.5, 3)
	assert(game.players[0].x == 800 and game.boss_x == 3100 and game.score == 123)
	game.host = true
	game.start_game(true)
	game.online = false
	game.players[0].inv = 100
	game.players[1].inv = 100
	game.remote_controls = [false, false, false, true, false]
	var max_packet = 0
	for i in range(600):
		game.simulate(1.0 / 60, [false, false, false, true, false])
		max_packet = maxi(max_packet, game.make_snapshot().size())
	assert(max_packet < 1300, "Compressed update should fit the common ENet packet budget")
	var state = game.make_snapshot()
	var saved_x = game.players[0].x
	game.host = false
	game.players[0].x = 12
	game.compressed_snapshot(state)
	assert(game.players[0].x == saved_x, "Compressed snapshot must round-trip")
	game.queue_free()
	await process_frame
	print("PASS: acceleration, stopping, jump release/no repeat, enemy AI, boss motion, effect limits and guest snapshots")
	quit()
