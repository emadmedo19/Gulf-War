extends RefCounted

var game
var cave: Texture2D
var drone_texture: Texture2D
var tank_texture: Texture2D
var stage = 1
var units: Array = []
var loot: Array = []
var numbers: Array = []
var waves_sent = 0
var coins = 0
var skill_flash = 0.0
var kills = 0

func _init(owner):
	game = owner
	cave = load("res://assets/cave.webp")
	drone_texture = load("res://assets/drone.webp")
	tank_texture = load("res://assets/tank.webp")

func reset(mission: int):
	stage = mission
	units.clear()
	loot.clear()
	numbers.clear()
	waves_sent = 0
	coins = 0
	kills = 0
	skill_flash = 0

func visual_tick(dt: float):
	skill_flash = maxf(0, skill_flash - dt)
	for i in range(numbers.size() - 1, -1, -1):
		numbers[i].life -= dt
		numbers[i].y -= 42 * dt
		if numbers[i].life <= 0: numbers.remove_at(i)

func update(dt: float):
	var front = 0.0
	for p in game.players:
		p.skill_time = maxf(0, p.skill_time - dt)
		p.power = maxf(0, p.power - dt)
		if p.hp > 0: front = maxf(front, p.x)
	if waves_sent < 4 and front > 350 + waves_sent * 650:
		spawn_wave(front, waves_sent)
		waves_sent += 1
	for u in units:
		if u.hp <= 0: continue
		u.cd -= dt
		u.time += dt
		var target = game.nearest_player(u.x)
		if target.is_empty(): continue
		var direction = signf(target.x - u.x)
		u.face = 1 if direction > 0 else -1
		if u.kind == "drone":
			u.x = move_toward(u.x, clampf(target.x + 240, 250, 3250), dt * 64)
			u.y = 225 + sin(u.time * 2.4 + u.seed) * 28
		else:
			if absf(target.x - u.x) > 310: u.x += direction * 35 * dt
		if u.cd <= 0 and absf(target.x - u.x) < 750:
			var origin = Vector2(u.x + direction * (32 if u.kind == "drone" else 70), u.y - (0 if u.kind == "drone" else 49))
			var aim = (Vector2(target.x, target.y - 40) - origin).normalized() * (240 if u.kind == "drone" else 290)
			game.spawn_shot(origin.x, origin.y, aim.x, aim.y, true, false)
			u.cd = 1.5 if u.kind == "drone" else 2.1
			u.recoil = 0.12
			if u.kind == "tank": game.play_sound("tank")
		u.recoil = maxf(0, u.recoil - dt)
	for i in range(loot.size() - 1, -1, -1):
		var item = loot[i]
		item.life -= dt
		item.vy += 700 * dt
		item.y = minf(game.GROUND - 12, item.y + item.vy * dt)
		var target = game.nearest_player(item.x)
		if not target.is_empty():
			var destination = Vector2(target.x, target.y - 25)
			var location = Vector2(item.x, item.y)
			if location.distance_to(destination) < 120:
				location = location.move_toward(destination, dt * 330)
				item.x = location.x
				item.y = location.y
			if location.distance_to(destination) < 26:
				if item.kind == "weapon": target.power = 12.0
				else:
					coins += 10
					target.energy = minf(100, target.energy + 8)
				game.play_sound("coin")
				loot.remove_at(i)
				continue
		if item.life <= 0: loot.remove_at(i)
	# Dead units no longer participate in simulation or network updates.
	for i in range(units.size() - 1, -1, -1):
		if units[i].hp <= 0: units.remove_at(i)

func spawn_wave(front: float, number: int):
	var anchor = clampf(front + 590, 600, 3180)
	for i in range(2 if stage == 1 else 3):
		game.enemies.append({"x": minf(3250, anchor + i * 65), "hp": 16, "cd": 0.7 + i * 0.2, "vx": 0.0, "face": -1, "stun": 0.0})
	units.append({"kind": "drone", "x": anchor, "y": 220.0, "hp": 28, "cd": 0.6, "face": -1, "time": 0.0, "seed": float(number), "recoil": 0.0})
	if number % 2 == 1:
		units.append({"kind": "tank", "x": anchor + 50, "y": game.GROUND, "hp": 64, "cd": 1.0, "face": -1, "time": 0.0, "seed": 0.0, "recoil": 0.0})

func aim(origin: Vector2, facing: int) -> Vector2:
	var best = Vector2(facing, 0)
	var distance = 570.0
	var targets: Array = []
	for e in game.enemies:
		if e.hp > 0: targets.append(Vector2(e.x, game.GROUND - 45))
	for u in units:
		if u.hp > 0: targets.append(Vector2(u.x, u.y - (0 if u.kind == "drone" else 40)))
	if game.boss_hp > 0: targets.append(Vector2(game.boss_x - 70, game.GROUND - 85))
	for target in targets:
		var delta = target - origin
		if delta.x * facing > 30 and delta.length() < distance:
			distance = delta.length()
			best = delta.normalized()
	return best

func hit_unit(shot: Dictionary) -> bool:
	for u in units:
		var center = Vector2(u.x, u.y - (0 if u.kind == "drone" else 40))
		var extent = Vector2(43, 29) if u.kind == "drone" else Vector2(65, 44)
		if u.hp > 0 and absf(shot.x - center.x) < extent.x and absf(shot.y - center.y) < extent.y:
			damage(u, 4)
			return true
	return false

func damage(unit: Dictionary, amount: int):
	unit.hp -= amount
	game.show_damage(unit.x, unit.y - 30, amount)
	game.impact_event(unit.x, unit.y - 30, "spark")
	if unit.hp <= 0:
		game.score += 250 if unit.kind == "tank" else 150
		game.dispatch_burst(unit.x, unit.y - 20, unit.kind == "tank")
		drop(unit.x, unit.y)

func drop(x: float, y: float):
	kills += 1
	if loot.size() < 28:
		loot.append({"x": x, "y": y - 25, "vy": -170.0, "life": 14.0, "kind": "weapon" if kills % 5 == 0 else "coin"})
	for p in game.players:
		if p.hp > 0: p.energy = minf(100, p.energy + 10)

func activate(p: Dictionary, index: int):
	if p.energy < 100 or p.skill_time > 0: return
	p.energy = 0
	p.skill_time = 1.1
	p.inv = maxf(p.inv, 1.2)
	game.skill_event(index)
	for e in game.enemies:
		if e.hp > 0 and absf(e.x - p.x) < 570:
			game.show_damage(e.x, game.GROUND - 70, 45)
			e.hp = 0
			game.score += 100
			drop(e.x, game.GROUND)
			game.dispatch_burst(e.x, game.GROUND - 30, false)
	for u in units:
		if u.hp > 0 and absf(u.x - p.x) < 570: damage(u, 48)
	if game.boss_hp > 0 and absf(game.boss_x - p.x) < 600:
		game.boss_hp = maxi(0, game.boss_hp - 30)
		game.show_damage(game.boss_x, game.GROUND - 190, 30)
		if game.boss_hp == 0: game.dispatch_burst(game.boss_x, game.GROUND - 80, true)

func blast(x: float):
	for u in units:
		if u.hp > 0 and absf(u.x - x) < 170: damage(u, 36)

func pack() -> Array:
	return [stage, units, loot, waves_sent, coins]

func unpack(data: Array):
	if data.size() != 5: return
	stage = data[0]
	units = data[1]
	loot = data[2]
	waves_sent = data[3]
	coins = data[4]

func draw_world():
	for u in units:
		if u.hp <= 0: continue
		var texture = drone_texture if u.kind == "drone" else tank_texture
		if texture == null: continue
		var size = Vector2(110, 80) if u.kind == "drone" else Vector2(190, 110)
		var center = Vector2(u.x - game.camera_x, u.y - (0 if u.kind == "drone" else 40))
		var rect = Rect2(center - size * 0.5, size)
		if u.face > 0:
			rect.position.x += size.x
			rect.size.x = -size.x
		game.draw_texture_rect(texture, rect, false)
		if u.kind == "drone":
			for jet in range(2):
				var offset = Vector2(-18 + jet * 38, 24)
				game.draw_line(center + offset, center + offset + Vector2(0, 12 + sin(game.clock * 35 + jet) * 7), Color("ffc35c"), 5)
		else:
			for i in range(7):
				game.draw_circle(center + Vector2(-50 + i * 17, 36), 3, Color(0.65, 0.58, 0.36, 0.5 + sin(game.clock * 16 + i) * 0.4))
		game.draw_rect(Rect2(center.x - 25, center.y - size.y * 0.5 - 7, 50, 3), Color("292e2d"))
		game.draw_rect(Rect2(center.x - 25, center.y - size.y * 0.5 - 7, 50 * clampf(float(u.hp) / (28 if u.kind == "drone" else 64), 0, 1), 3), Color("e9ae53"))
	for item in loot:
		var pos = Vector2(item.x - game.camera_x, item.y)
		if item.kind == "coin":
			game.draw_set_transform(pos, 0, Vector2(0.35 + absf(sin(game.clock * 7)) * 0.65, 1))
			game.draw_circle(Vector2.ZERO, 8, Color("dc921e"))
			game.draw_arc(Vector2.ZERO, 6, 0, TAU, 16, Color("ffe691"), 2)
			game.draw_set_transform(Vector2.ZERO)
		else:
			game.draw_rect(Rect2(pos - Vector2(14, 10), Vector2(28, 20)), Color("316f88"))
			game.text_at(pos + Vector2(-9, 5), "H", 15, Color("b8f4ff"))
	for i in range(game.players.size()):
		var p = game.players[i]
		if p.get("skill_time", 0) > 0:
			for trail in range(1, 5):
				var x = p.x - game.camera_x - p.face * trail * 25
				game.soldier(x, p.y, i, p.face, true, false, false, Color(0.18, 0.65, 1, (5 - trail) * 0.14))
			game.draw_arc(Vector2(p.x - game.camera_x, p.y - 45), 62 + sin(game.clock * 30) * 7, 0, TAU, 40, Color(0.2, 0.75, 1, 0.85), 3)
	for n in numbers:
		game.text_at(Vector2(n.x - game.camera_x, n.y), str(n.amount), 17, Color(1, 0.9, 0.65, minf(n.life * 2, 1)))
