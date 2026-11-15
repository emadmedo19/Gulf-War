extends SceneTree
func _initialize(): call_deferred("run")
func run():
	var g = load("res://main.tscn").instantiate()
	root.add_child(g)
	g.set_process(false)
	g.set_physics_process(false)
	g.start_game(false, 2)
	assert(g.combat.stage == 2 and g.combat.cave != null)
	g.players[0].x = 500
	g.simulate(1.0 / 60, [false, false, false, false, false, false])
	assert(g.combat.waves_sent == 1 and g.combat.units.size() == 1)
	var p = g.players[0]
	g.enemies.clear()
	g.combat.units[0].x = p.x + 230
	g.combat.units[0].y = 220
	var aim = g.combat.aim(Vector2(p.x + 50, p.y - 61), 1)
	assert(aim.y < -0.2, "Auto aim must target flying enemies")
	g.combat.units[0].hp = 4
	assert(g.combat.hit_unit({"x": g.combat.units[0].x, "y": 220}))
	assert(g.combat.units[0].hp <= 0 and g.combat.loot.size() == 1)
	g.combat.loot[0].x = p.x
	g.combat.loot[0].y = p.y - 25
	g.combat.loot[0].vy = 0
	g.combat.update(1.0 / 60)
	assert(g.combat.coins == 10)
	g.combat.loot.append({"x": p.x, "y": p.y - 25, "vy": 0.0, "life": 5.0, "kind": "weapon"})
	g.combat.update(1.0 / 60)
	assert(p.power > 10)
	g.combat.spawn_wave(p.x, 1)
	assert(g.combat.units.size() >= 2)
	g.combat.units[0].x = p.x + 200
	p.energy = 100
	g.combat.activate(p, 0)
	assert(p.skill_time > 1 and p.energy < 100)
	var encoded = g.make_snapshot()
	g.host = false
	g.combat.coins = 0
	var total = ceili(encoded.size() / 1000.0)
	for part in range(total - 1, -1, -1): g.snapshot_part(5, part, total, encoded.slice(part * 1000, (part + 1) * 1000))
	assert(g.combat.coins == 10 and g.combat.stage == 2)
	g.online = false
	g.host = true
	g.enter_cave()
	assert(g.combat.stage == 2 and not g.finished and g.players[0].hp == 100)
	print("PASS: cave stage, waves, aerial aim, drone damage, coins, weapon upgrade, skill, fragmented synchronization and mission transition")
	quit()
