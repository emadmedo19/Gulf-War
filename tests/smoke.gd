extends SceneTree

func _initialize():
	call_deferred("run")

func run():
	var game = load("res://main.tscn").instantiate()
	root.add_child(game)
	game.start_game(false)
	assert(game.players.size() == 1)
	var origin = game.players[0].x
	game.simulate(0.1, [false, true, true, true, false])
	assert(game.players[0].x > origin)
	assert(game.players[0].y < game.GROUND)
	assert(game.shots.size() > 0)
	game.simulate(0.1, [false, false, false, false, true])
	assert(game.players[0].grenades == 4)
	game.explode(650)
	assert(game.enemies[0].hp == 0)
	assert(game.score == 100)
	game.start_game(true)
	assert(game.players.size() == 2)
	game.remote_controls = [false, true, false, false, false]
	origin = game.players[1].x
	game.simulate(0.1, [false, false, false, false, false])
	assert(game.players[1].x > origin)
	game.boss_hp = 10
	game.explode(3160)
	game.simulate(0.01, [false, false, false, false, false])
	assert(game.finished and game.boss_hp == 0)
	game.start_game(false)
	game.players[0].hp = 0
	game.simulate(0.01, [false, false, false, false, false])
	assert(game.finished)
	print("PASS: movement, jump, fire, grenades, enemy damage, second-player input, victory and defeat")
	quit()
