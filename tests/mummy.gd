extends SceneTree
func _initialize(): call_deferred("run")
func run():
	var game = load("res://main.tscn").instantiate()
	root.add_child(game)
	game.set_process(false)
	game.set_physics_process(false)
	game.start_mummy()
	assert(game.players[0].skin == "mummy" and game.combat.stage == 2)
	var atlas = game.mummy_sprite
	assert(atlas.texture.get_size() == Vector2(920, 1009))
	assert(atlas.frames.walk_lower.size() == 12)
	assert(atlas.frames.fire_upper.size() == 12)
	for sequence in [atlas.frames.walk_lower, atlas.frames.walk_upper, atlas.frames.fire_upper]:
		for frame in sequence:
			var r = frame.rect
			assert(r[0] >= 0 and r[1] >= 0 and r[0] + r[2] <= 920 and r[1] + r[3] <= 1009)
			assert(frame.pivot[1] == r[3], "Every frame must share the bottom anchor")
	for i in range(30): game.simulate(1.0 / 60, [false, true, false, false, false, false])
	assert(game.players[0].vx == 130)
	game.simulate(1.0 / 60, [false, true, true, true, false, false])
	assert(game.players[0].y < game.GROUND and game.shots.size() > 0)
	print("PASS: original sheet dimensions, atlas rectangles, shared pivots, playable mummy movement, jump and fire")
	quit()
