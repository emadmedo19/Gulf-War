extends Node2D

const PORT = 24765
const GROUND = 425.0
const END = 3400.0
var players: Array = []
var enemies: Array = []
var shots: Array = []
var particles: Array = []
var controls = [false, false, false, false, false, false]
var remote_controls = [false, false, false, false, false, false]
var touch_actions: Dictionary = {}
var playing = false
var online = false
var host = true
var camera_x = 0.0
var clock = 0.0
var sync_clock = 0.0
var boss_hp = 160
var boss_cooldown = 2.0
var score = 0
var finished = false
var menu: Control
var status: Label
var address: LineEdit
var hud: Label
var note: Label
var desert_texture: Texture2D
var actor_texture: Texture2D
var mech_texture: Texture2D
var visual_positions: Dictionary = {}
var local_controls = [false, false, false, false, false, false]
var boss_x = 3160.0
var boss_recoil = 0.0
var boss_phase = 0.0
var shake = 0.0
var effects: Array = []
var render_positions: Dictionary = {}
var last_remote_input = 0.0
var sound_bank: Dictionary = {}
var voices: Array = []
var voice_index = 0
var fire_audio_cooldown = 0.0
var muzzle_phase = 0.0
var combat
var next_packet = 0
var assembling_packet = -1
var packet_parts: Dictionary = {}
var finish_delay = 0.0
var music: AudioStreamPlayer

func _ready():
	RenderingServer.set_default_clear_color(Color("171d23"))
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	desert_texture = load("res://assets/desert.webp")
	actor_texture = load("res://assets/actors.webp")
	mech_texture = load("res://assets/mech.webp")
	combat = load("res://combat.gd").new(self)
	create_audio()
	music = AudioStreamPlayer.new()
	music.stream = load("res://assets/action_loop.wav")
	music.volume_db = -22
	add_child(music)
	menu = Control.new()
	add_child(menu)
	var panel = Panel.new()
	panel.position = Vector2(245, 70)
	panel.size = Vector2(470, 380)
	menu.add_child(panel)
	var title = Label.new()
	title.text = "GULF-WAR  /  حرب الخليج"
	title.position = Vector2(275, 94)
	title.add_theme_font_size_override("font_size", 27)
	menu.add_child(title)
	var city = make_button("مدينة / CITY", Vector2(290, 150), func(): start_game(false))
	city.size.x = 180
	var cave_button = make_button("كهف / CAVE", Vector2(490, 150), func(): start_game(false, 2))
	cave_button.size.x = 180
	if not OS.has_feature("web"):
		make_button("إنشاء غرفة / HOST", Vector2(290, 207), host_game)
	address = LineEdit.new()
	address.position = Vector2(290, 270)
	address.size = Vector2(380, 40)
	address.placeholder_text = "عنوان IP لجهاز صاحب الغرفة"
	menu.add_child(address)
	if not OS.has_feature("web"):
		make_button("انضمام / JOIN", Vector2(290, 325), join_game)
	else:
		address.hide()
	status = Label.new()
	status.position = Vector2(265, 387)
	status.size = Vector2(440, 50)
	status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	status.text = "تجربة المتصفح فردية. اللعب الجماعي متاح في نسخة أندرويد." if OS.has_feature("web") else "اتصلوا بنفس الواي فاي أو الهوت سبوت • UDP 24765"
	menu.add_child(status)
	hud = Label.new()
	hud.position = Vector2(24, 16)
	hud.add_theme_font_size_override("font_size", 21)
	add_child(hud)
	note = Label.new()
	note.position = Vector2(240, 75)
	note.add_theme_font_size_override("font_size", 22)
	add_child(note)
	multiplayer.peer_connected.connect(peer_joined)
	multiplayer.connected_to_server.connect(func(): status.text = "متصل، في انتظار بدء الجولة…")
	multiplayer.connection_failed.connect(func(): disconnect_game("تعذر الاتصال. راجع عنوان IP والشبكة."))
	multiplayer.server_disconnected.connect(func(): disconnect_game("انقطع الاتصال بالمضيف."))
	multiplayer.peer_disconnected.connect(func(_id):
		if online: disconnect_game("خرج اللاعب الآخر. أنشئ غرفة جديدة للعب معًا."))

func make_button(caption: String, pos: Vector2, action: Callable):
	var b = Button.new()
	b.text = caption
	b.position = pos
	b.size = Vector2(380, 45)
	b.pressed.connect(action)
	menu.add_child(b)
	return b

func disconnect_game(message: String):
	online = false
	playing = false
	if music != null: music.stop()
	multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()
	menu.show()
	hud.text = ""
	note.text = ""
	status.text = message

func host_game():
	var peer = ENetMultiplayerPeer.new()
	var err = peer.create_server(PORT, 1)
	if err != OK:
		status.text = "تعذر إنشاء الغرفة: " + error_string(err)
		return
	multiplayer.multiplayer_peer = peer
	host = true
	online = true
	var ips: Array = []
	for ip in IP.get_local_addresses():
		if ":" not in ip and not ip.begins_with("127."): ips.append(ip)
	status.text = "انتظار صديقك. عنوان جهازك: " + ", ".join(ips)

func join_game():
	var ip = address.text.strip_edges()
	if not ip.is_valid_ip_address():
		status.text = "اكتب عنوان IP الصحيح لجهاز صاحب الغرفة."
		return
	var peer = ENetMultiplayerPeer.new()
	var err = peer.create_client(ip, PORT)
	if err != OK:
		status.text = error_string(err)
		return
	host = false
	online = true
	multiplayer.multiplayer_peer = peer
	status.text = "جارٍ الاتصال…"

func peer_joined(id: int):
	if host and online:
		start_game(true)
		begin_round.rpc_id(id)

@rpc("authority", "reliable")
func begin_round():
	start_game(true)

func start_game(networked: bool, mission: int = 1):
	combat.reset(mission)
	if DisplayServer.get_name() != "headless" and not music.playing: music.play()
	finish_delay = 0.0
	next_packet = 0
	assembling_packet = -1
	packet_parts.clear()
	online = networked
	if not networked: host = true
	players.clear()
	for i in range(2 if networked else 1):
		players.append({"x": 120.0 + i * 65, "y": GROUND, "vx": 0.0, "vy": 0.0, "jump_held": false, "buffer": 0.0, "hp": 100, "face": 1, "cd": 0.0, "inv": 0.0, "grenades": 5, "gcd": 0.0, "energy": 100.0, "skill_time": 0.0, "power": 0.0})
	enemies.clear()
	for x in [650, 920, 1200, 1530, 1760, 2050, 2300, 2580, 2800]:
		enemies.append({"x": float(x), "hp": 12, "cd": randf_range(0.5, 2.0), "vx": 0.0, "face": -1, "stun": 0.0})
	shots.clear()
	particles.clear()
	effects.clear()
	render_positions.clear()
	local_controls.fill(false)
	boss_x = 3160.0
	boss_phase = 0.0
	shake = 0.0
	camera_x = 0.0
	controls.fill(false)
	remote_controls.fill(false)
	touch_actions.clear()
	boss_hp = 160
	boss_cooldown = 2.0
	score = 0
	finished = false
	playing = true
	menu.hide()

@rpc("any_peer", "unreliable_ordered")
func input_packet(values: Array):
	if host and values.size() in [5, 6] and multiplayer.get_remote_sender_id() in multiplayer.get_peers():
		for i in range(6): remote_controls[i] = i < values.size() and values[i] == true
		last_remote_input = clock

@rpc("authority", "unreliable_ordered")
func snapshot(p: Array, e: Array, s: Array, hp: int, points: int, done: bool, mech_x: float, phase: float, recoil: float):
	if not host:
		players = p
		enemies = e
		shots = s
		boss_hp = hp
		score = points
		finished = done
		boss_x = mech_x
		boss_phase = phase
		boss_recoil = recoil

func make_snapshot() -> PackedByteArray:
	return var_to_bytes([players, enemies, shots, boss_hp, score, finished, boss_x, boss_phase, boss_recoil, combat.pack()]).compress(FileAccess.COMPRESSION_DEFLATE)

@rpc("authority", "unreliable_ordered")
func compressed_snapshot(payload: PackedByteArray):
	if host or payload.size() > 32768: return
	var raw = payload.decompress_dynamic(262144, FileAccess.COMPRESSION_DEFLATE)
	if raw.is_empty(): return
	var decoded = bytes_to_var(raw)
	if decoded is Array and decoded.size() in [9, 10]:
		snapshot.callv(decoded.slice(0, 9))
		if decoded.size() == 10: combat.unpack(decoded[9])

func _input(event):
	if event is InputEventKey:
		var keys = [KEY_A, KEY_D, KEY_SPACE, KEY_J, KEY_K, KEY_L]
		for i in range(6):
			if event.physical_keycode == keys[i]:
				while controls.size() < 6: controls.append(false)
				controls[i] = event.pressed
		if event.pressed and event.physical_keycode == KEY_M: AudioServer.set_bus_mute(0, not AudioServer.is_bus_mute(0))
		if event.pressed and event.physical_keycode == KEY_ESCAPE: disconnect_game("اختر وضع اللعب")
	if event is InputEventScreenTouch:
		if event.pressed and Rect2(855, 85, 90, 40).has_point(event.position):
			AudioServer.set_bus_mute(0, not AudioServer.is_bus_mute(0))
			return
		if event.pressed: touch_actions[event.index] = action_at(event.position)
		else: touch_actions.erase(event.index)
	if event is InputEventScreenDrag:
		touch_actions[event.index] = action_at(event.position)
	if event is InputEventMouseButton and playing:
		if event.pressed and Rect2(855, 85, 90, 40).has_point(event.position):
			AudioServer.set_bus_mute(0, not AudioServer.is_bus_mute(0))
			return
		if event.pressed: touch_actions[-1] = action_at(event.position)
		else: touch_actions.erase(-1)
	if event is InputEventMouseMotion and touch_actions.has(-1): touch_actions[-1] = action_at(event.position)
	if event is InputEventKey and event.pressed and event.physical_keycode == KEY_BACK: disconnect_game("اختر وضع اللعب")

func _notification(what):
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		controls.fill(false)
		touch_actions.clear()

func action_at(pos: Vector2) -> int:
	var centers = [Vector2(68, 465), Vector2(174, 465), Vector2(720, 465), Vector2(884, 440), Vector2(802, 485), Vector2(620, 485)]
	for i in range(6):
		if pos.distance_to(centers[i]) < 45: return i
	return -1

func _process(dt):
	dt = minf(dt, 0.08)
	clock += dt
	combat.visual_tick(dt)
	fire_audio_cooldown = maxf(0, fire_audio_cooldown - dt)
	shake = move_toward(shake, 0, dt * 22)
	local_controls = controls.duplicate()
	for a in touch_actions.values():
		if a >= 0: local_controls[a] = true
	for n in range(effects.size() - 1, -1, -1):
		var fx = effects[n]
		fx.life -= dt
		fx.x += fx.vx * dt
		fx.y += fx.vy * dt
		fx.vy += (360 if fx.kind != "smoke" else -12) * dt
		if fx.life <= 0: effects.remove_at(n)
	if playing:
		for i in range(players.size()):
			var p = players[i]
			var target = Vector2(p.x, p.y)
			var previous: Vector2 = render_positions.get(i, target)
			if previous.distance_to(target) > 180: previous = target
			render_positions[i] = previous.lerp(target, 1.0 - exp(-dt * (55.0 if host else 24.0)))
		if not host and not finished:
			for shot in shots:
				shot.x += shot.vx * dt
				shot.y += shot.vy * dt
				if shot.grenade: shot.vy += 950 * dt
		var idx = 0 if host else 1
		if players.size() > idx:
			var wanted = clampf(players[idx].x - 330, 0, END - 960)
			camera_x = lerpf(camera_x, wanted, 1 - exp(-dt * 8))
		hud.text = ""
		note.text = ""
	queue_redraw()

func _physics_process(dt):
	if not playing: return
	if host and finished and boss_hp <= 0 and combat.stage == 1:
		finish_delay += dt
		if finish_delay > 2.0 and local_controls.size() > 3 and local_controls[3]:
			if online: enter_cave.rpc()
			else: enter_cave()
	if host and not finished:
		if online and clock - last_remote_input > 0.45: remote_controls.fill(false)
		simulate(dt, local_controls)
	sync_clock += dt
	if online and sync_clock >= 1.0 / 30.0:
		sync_clock = 0.0
		if host:
			var payload = make_snapshot()
			next_packet += 1
			var count = ceili(payload.size() / 1000.0)
			for part in range(count): snapshot_part.rpc(next_packet, part, count, payload.slice(part * 1000, (part + 1) * 1000))
		else: input_packet.rpc_id(1, local_controls)

func simulate(dt: float, local: Array):
	combat.update(dt)
	for i in range(players.size()):
		var p = players[i]
		var c = local if i == 0 else remote_controls
		p.cd -= dt
		p.gcd -= dt
		p.inv -= dt
		if p.hp <= 0: continue
		var direction = int(c[1]) - int(c[0])
		p.vx = move_toward(p.vx, direction * 255.0, (1900.0 if direction != 0 else 2400.0) * dt)
		p.x = clampf(p.x + p.vx * dt, 25, END - 130)
		if direction != 0: p.face = direction
		p.buffer = maxf(0, p.buffer - dt)
		if c[2] and not p.jump_held: p.buffer = 0.12
		if p.buffer > 0 and p.y >= GROUND:
			p.vy = -565.0
			p.buffer = 0.0
			local_fx(p.x, GROUND, "dust", 5)
		if not c[2] and p.jump_held and p.vy < -210: p.vy = -210.0
		p.jump_held = c[2]
		p.vy += 1350 * dt
		p.y = minf(GROUND, p.y + p.vy * dt)
		if p.y >= GROUND:
			if p.vy > 160: local_fx(p.x, GROUND, "dust", 8)
			p.vy = 0.0
		if c.size() > 5 and c[5]: combat.activate(p, i)
		if c[3] and p.cd <= 0:
			var origin = Vector2(p.x + p.face * 51, p.y - 61)
			var aim = combat.aim(origin, p.face)
			for spread in ([-0.1, 0.0, 0.1] if p.power > 0 else [0.0]):
				var velocity = aim.rotated(spread) * 760
				spawn_shot(origin.x, origin.y, velocity.x, velocity.y, false, false)
			p.cd = 0.09 if p.power > 0 else 0.115
			local_fx(p.x + p.face * 20, p.y - 58, "casing", 1)
			play_sound("fire")
		if c[4] and p.gcd <= 0 and p.grenades > 0:
			spawn_shot(p.x, p.y - 45, p.face * 360, -430, false, true)
			p.grenades -= 1
			p.gcd = 0.6
	for e in enemies:
		if e.hp <= 0: continue
		e.cd -= dt
		e.stun = maxf(0, e.stun - dt)
		var target = nearest_player(e.x)
		if target.is_empty(): continue
		var distance = absf(target.x - e.x)
		e.face = 1 if target.x > e.x else -1
		var speed = 0.0
		if distance < 720 and distance > 300: speed = e.face * 82.0
		elif distance < 160: speed = -e.face * 48.0
		if e.cd < 0.24 or e.cd > 1.3 or e.stun > 0: speed = 0
		e.vx = move_toward(e.vx, speed, dt * 540)
		e.x = clampf(e.x + e.vx * dt, 380, END - 150)
		if distance < 620 and e.cd <= 0 and e.stun <= 0:
			spawn_shot(e.x + e.face * 48, GROUND - 55, e.face * 300, 0, true, false)
			e.cd = randf_range(1.35, 1.9)
	boss_phase += dt
	boss_recoil = move_toward(boss_recoil, 0, dt * 25)
	if boss_hp > 0:
		boss_cooldown -= dt
		var target = nearest_player(boss_x)
		if not target.is_empty() and target.x > 2350:
			boss_x = move_toward(boss_x, 3040.0 + sin(boss_phase * 0.65) * 95, dt * 28)
			if boss_cooldown <= 0:
				var enraged = boss_hp < 65
				for y in [GROUND - 48, GROUND - 115]: spawn_shot(boss_x - 144, y, -370 if enraged else -320, 0, true, false)
				boss_cooldown = 0.65 if enraged else 1.05
				boss_recoil = 7.0
				local_fx(boss_x + 95, GROUND - 182, "smoke", 2)
	for p in players:
		if boss_hp > 0 and p.hp > 0 and p.inv <= 0 and absf(p.x - boss_x) < 115 and p.y > GROUND - 125:
			p.hp = maxi(0, p.hp - 20)
			p.inv = 1.0
			p.vx = -350.0
			p.x = maxf(25, boss_x - 125)
			shake = maxf(shake, 4)
			play_sound("hit")
	for n in range(shots.size() - 1, -1, -1):
		var s = shots[n]
		s.x += s.vx * dt
		s.y += s.vy * dt
		s.life -= dt
		if s.grenade: s.vy += 950 * dt
		var remove = s.life <= 0 or s.x < 0 or s.x > END
		if s.grenade and s.y >= GROUND:
			explode(s.x)
			remove = true
		elif not s.enemy and not s.grenade:
			for e in enemies:
				if e.hp > 0 and absf(s.x - e.x) < 23 and absf(s.y - (GROUND - 46)) < 48:
					e.hp -= 4
					show_damage(e.x, GROUND - 75, 4)
					e.stun = 0.12
					impact_event(s.x, s.y, "spark")
					remove = true
					if e.hp <= 0:
						score += 100
						combat.drop(e.x, GROUND)
						dispatch_burst(e.x, GROUND - 35, false)
					break
			if not remove: remove = combat.hit_unit(s)
			if not remove and boss_hp > 0 and s.x > boss_x - 135 and s.x < boss_x + 120 and s.y > GROUND - 155:
				boss_hp = maxi(0, boss_hp - 2)
				show_damage(boss_x, GROUND - 180, 2)
				impact_event(s.x, s.y, "spark")
				if boss_hp == 0: dispatch_burst(boss_x, GROUND - 85, true)
				remove = true
		elif s.enemy:
			for p in players:
				if p.hp > 0 and p.inv <= 0 and absf(p.x - s.x) < 20 and absf((p.y - 46) - s.y) < 48:
					p.hp = maxi(0, p.hp - 10)
					p.inv = 0.7
					shake = maxf(shake, 2.5)
					play_sound("hit")
					remove = true
		if remove: shots.remove_at(n)
	for n in range(particles.size() - 1, -1, -1):
		particles[n].life -= dt
		if particles[n].life <= 0: particles.remove_at(n)
	var alive = false
	for p in players:
		if p.hp > 0: alive = true
	finished = boss_hp <= 0 or not alive

func nearest_player(x: float) -> Dictionary:
	var best: Dictionary = {}
	var distance = INF
	for p in players:
		if p.hp > 0 and absf(p.x - x) < distance:
			best = p
			distance = absf(p.x - x)
	return best

func spawn_shot(x: float, y: float, vx: float, vy: float, enemy: bool, grenade: bool):
	shots.append({"x": x, "y": y, "vx": vx, "vy": vy, "enemy": enemy, "grenade": grenade, "life": 4.0})

func explode(x: float):
	dispatch_burst(x, GROUND - 25, true)
	combat.blast(x)
	for e in enemies:
		if e.hp > 0 and absf(e.x - x) < 135:
			e.hp = 0
			score += 100
			combat.drop(e.x, GROUND)
	if absf(boss_x - x) < 180:
		boss_hp = maxi(0, boss_hp - 30)
		if boss_hp == 0: dispatch_burst(boss_x, GROUND - 100, true)

func box(x: float, y: float, w: float, h: float, color: String):
	draw_rect(Rect2(minf(x, x + w), minf(y, y + h), absf(w), absf(h)), Color(color))

func soldier(x: float, y: float, row: int, face: int, moving: bool, firing: bool = false, airborne: bool = false, tint: Color = Color.WHITE):
	if actor_texture == null: return
	var frame = 1 + int(clock * 11) % 2 if moving else 0
	if airborne: frame = 2
	if firing and not moving and not airborne: frame = 3
	var cell = Vector2(actor_texture.get_width() / 4.0, actor_texture.get_height() / 3.0)
	var bob = sin(clock * 22) * 1.5 if moving else sin(clock * 3.5 + row) * 0.5
	var dest = Rect2(x - 55 - (face * 2 if firing else 0), y - 105 + bob, 110, 110)
	draw_ellipse_shadow(Vector2(x, y + 1), 24 if not airborne else 15)
	if face < 0:
		dest.position.x += dest.size.x
		dest.size.x = -dest.size.x
	draw_texture_rect_region(actor_texture, dest, Rect2(Vector2(frame, row) * cell, cell), tint)
	if firing and (moving or airborne):
		var muzzle = Vector2(x + face * 51, y - 61 + bob)
		draw_line(muzzle, muzzle + Vector2(face * 17, 0), Color("ffdc72"), 5)
		draw_line(muzzle, muzzle + Vector2(face * 10, -5), Color("fff3bb"), 3)

func text_at(pos: Vector2, value: String, size: int, color: Color = Color.WHITE):
	draw_string_outline(ThemeDB.fallback_font, pos, value, HORIZONTAL_ALIGNMENT_LEFT, -1, size, 4, Color("182129"))
	draw_string(ThemeDB.fallback_font, pos, value, HORIZONTAL_ALIGNMENT_LEFT, -1, size, color)

func _draw():
	var backdrop = combat.cave if combat != null and combat.stage == 2 else desert_texture
	if backdrop != null:
		# The artwork and live sprites use the same 960 x 540 coordinate system.
		var scroll = clampf(camera_x / (END - 960.0), 0, 1) * 160.0
		draw_texture_rect(backdrop, Rect2(-scroll, 0, 1120, 540), false)
	if not playing:
		draw_rect(Rect2(0, 0, 960, 540), Color(0.04, 0.07, 0.09, 0.62))
		return
	# World shake never shifts the HUD or touch controls.
	var jitter = Vector2(sin(clock * 87), cos(clock * 73)) * shake
	draw_set_transform(jitter)
	# Small atmospheric drifting dust motes, behind the actors.
	for i in range(22):
		var pos = Vector2(fposmod(i * 73.0 - clock * 15 - camera_x * 0.15, 960), 130 + fposmod(i * 43.0, 280))
		draw_circle(pos, 1.0, Color(1, 0.88, 0.64, 0.45))
	for e in enemies:
		if e.hp > 0:
			soldier(e.x - camera_x, GROUND, 2, e.get("face", -1), absf(e.get("vx", 0)) > 5, e.cd > 1.6)
	if boss_hp > 0 and mech_texture != null:
		var bx = boss_x - camera_x + boss_recoil
		draw_texture_rect(mech_texture, Rect2(bx - 150, GROUND - 218 + sin(boss_phase * 7) * 3, 300, 235), false)
		# The intact boss artwork rocks while exhaust, charge lights and gun flash animate separately.
		if boss_recoil > 2:
			draw_line(Vector2(bx - 143, GROUND - 115), Vector2(bx - 178, GROUND - 115), Color("fff1b0"), 9)
		for lamp in range(3):
			draw_circle(Vector2(bx + 30 + lamp * 13, GROUND - 192), 2.5, Color(1, 0.18, 0.06, 0.5 + sin(clock * 8 + lamp) * 0.4))
		box(bx - 95, GROUND - 223, 190, 7, "242d2d")
		box(bx - 94, GROUND - 222, 188.0 * boss_hp / 160, 5, "ed7145")
	combat.draw_world()
	for i in range(players.size()):
		var p = players[i]
		var moving = absf(p.get("vx", 0)) > 10
		var render_pos: Vector2 = render_positions.get(i, Vector2(p.x, p.y))
		if p.hp > 0:
			var tint = Color(0.7, 0.9, 1, 0.65) if p.inv > 0 and int(clock * 15) % 2 == 1 else Color.WHITE
			soldier(render_pos.x - camera_x, render_pos.y, i, p.face, moving, p.cd > 0.065, p.y < GROUND - 2, tint)
		visual_positions[i] = p.x
	for shot in shots:
		if shot.grenade:
			draw_circle(Vector2(shot.x - camera_x, shot.y), 6, Color("33453d"))
			box(shot.x - camera_x - 2, shot.y - 8, 4, 3, "f6ce7c")
		else:
			var pos = Vector2(shot.x - camera_x, shot.y)
			draw_line(pos - Vector2(signf(shot.vx) * 22, 0), pos, Color(1, 0.65, 0.16, 0.25), 8)
			draw_line(pos - Vector2(signf(shot.vx) * 15, 0), pos, Color("ffefb0"), 3)
	for fx in effects:
		var pos = Vector2(fx.x - camera_x, fx.y)
		var alpha = clampf(fx.life / fx.duration, 0, 1)
		match fx.kind:
			"spark", "casing":
				draw_line(pos, pos - Vector2(fx.vx, fx.vy).normalized() * 5, Color(1, 0.79, 0.33, alpha), 2)
			"flame":
				var radius = fx.size * (0.6 + alpha * 0.8)
				var points = PackedVector2Array()
				for k in range(10):
					points.append(pos + Vector2.from_angle(k * TAU / 10) * radius * (0.8 + sin(k * 7.1 + fx.seed) * 0.2))
				draw_colored_polygon(points, Color(1, 0.26 + alpha * 0.5, 0.06 + alpha * 0.18, alpha))
				if alpha > 0.65: draw_circle(pos, radius * 0.45, Color("fff0b1"))
			"smoke":
				draw_circle(pos, fx.size * (1.6 - alpha), Color(0.23, 0.22, 0.2, alpha * 0.48))
			"dust":
				draw_circle(pos, fx.size * (1.4 - alpha), Color(0.86, 0.67, 0.41, alpha * 0.35))
	draw_set_transform(Vector2.ZERO)
	# HUD is drawn in viewport coordinates with explicit margins, independent of text layout.
	draw_rect(Rect2(20, 16, 240, 65), Color(0.05, 0.1, 0.13, 0.87))
	text_at(Vector2(33, 39), "P1  /  FALCON", 17, Color("f7dca8"))
	box(34, 50, 210, 13, "3c423c")
	box(36, 52, 206.0 * players[0].hp / 100, 9, "81ba65")
	if players.size() > 1:
		draw_rect(Rect2(700, 16, 240, 65), Color(0.05, 0.1, 0.13, 0.87))
		text_at(Vector2(714, 39), "P2  /  EMBER", 17, Color("f7dca8"))
		box(714, 50, 210, 13, "3c423c")
		box(716, 52, 206.0 * players[1].hp / 100, 9, "df8661")
	text_at(Vector2(391, 35), "G U L F - W A R", 19, Color("ffe1a0"))
	text_at(Vector2(397, 61), "SCORE  %06d" % score, 16)
	text_at(Vector2(32, 110), "02 / CAVERN ASSAULT" if combat.stage == 2 else "01 / THE DUST DISTRICT", 15, Color("ffe4b2"))
	text_at(Vector2(395, 87), "COINS %04d" % combat.coins, 14, Color("ffe691"))
	text_at(Vector2(865, 109), "SND OFF" if AudioServer.is_bus_mute(0) else "SND ON", 13)
	var centers = [Vector2(68, 465), Vector2(174, 465), Vector2(720, 465), Vector2(884, 440), Vector2(802, 485), Vector2(620, 485)]
	for i in range(6):
		var active = (i < controls.size() and controls[i]) or i in touch_actions.values()
		var col = Color(0.09, 0.14, 0.17, 0.6) if not active else Color(0.55, 0.35, 0.12, 0.85)
		draw_circle(centers[i], 37, col)
		draw_arc(centers[i], 37, 0, TAU, 48, Color(0.95, 0.8, 0.54, 0.8), 1.7)
		if i < 3:
			var dir = Vector2(-1, 0) if i == 0 else (Vector2(1, 0) if i == 1 else Vector2(0, -1))
			var c = centers[i]
			draw_line(c - dir * 12, c + dir * 12, Color("ffe9bd"), 3)
			draw_line(c + dir * 12, c + dir * 3 + dir.orthogonal() * 9, Color("ffe9bd"), 3)
			draw_line(c + dir * 12, c + dir * 3 - dir.orthogonal() * 9, Color("ffe9bd"), 3)
		else:
			text_at(centers[i] + Vector2(-21, 5), "FIRE" if i == 3 else ("BOMB" if i == 4 else "SKILL"), 15, Color("ffe9bd"))
	var idx = 0 if host else 1
	if players.size() > idx:
		var energy = players[idx].get("energy", 0)
		draw_arc(Vector2(620, 485), 41, -PI * 0.5, -PI * 0.5 + TAU * energy / 100.0, 40, Color("68cfff"), 3)
		text_at(Vector2(500, 531), "HEAVY" if players[idx].get("power", 0) > 0 else "RIFLE", 13, Color("b6ddf5"))
		text_at(Vector2(745, 531), "GRENADES  %02d" % players[idx].grenades, 13, Color("e8d9bc"))

	if finished:
		draw_rect(Rect2(230, 190, 500, 125), Color(0.04, 0.08, 0.1, 0.93))
		text_at(Vector2(300, 238), "MISSION COMPLETE" if boss_hp <= 0 else "MISSION FAILED", 29, Color("ffdfa2"))
		text_at(Vector2(285, 283), "FIRE - NEXT MISSION" if boss_hp <= 0 and combat.stage == 1 else "BACK / ESC - MENU", 18)

func draw_ellipse_shadow(pos: Vector2, radius: float):
	draw_set_transform(pos, 0, Vector2(1, 0.18))
	draw_circle(Vector2.ZERO, radius, Color(0.06, 0.06, 0.05, 0.28))
	draw_set_transform(Vector2(sin(clock * 87), cos(clock * 73)) * shake)

func local_fx(x: float, y: float, kind: String, count: int):
	for i in range(count):
		if effects.size() >= 220: break
		var duration = randf_range(0.22, 0.7)
		var velocity = Vector2(randf_range(-95, 95), randf_range(-135, -35))
		var size = randf_range(3, 9)
		if kind == "flame":
			duration = randf_range(0.22, 0.5)
			velocity *= 1.5
			size = randf_range(12, 27)
		elif kind == "smoke":
			duration = randf_range(0.7, 1.2)
			velocity = Vector2(randf_range(-30, 30), randf_range(-90, -40))
			size = randf_range(9, 21)
		elif kind == "dust":
			velocity.y *= 0.2
		elif kind == "casing":
			size = 2
		effects.append({"x": x, "y": y, "vx": velocity.x, "vy": velocity.y, "kind": kind, "life": duration, "duration": duration, "size": size, "seed": randf() * 20})

func dispatch_burst(x: float, y: float, large: bool):
	if online and host: burst_event.rpc(x, y, large)
	else: burst_event(x, y, large)

@rpc("authority", "call_local", "reliable")
func burst_event(x: float, y: float, large: bool):
	local_fx(x, y, "flame", 18 if large else 6)
	local_fx(x, y, "smoke", 10 if large else 4)
	local_fx(x, y, "spark", 16 if large else 5)
	shake = maxf(shake, 7 if large else 2)
	play_sound("blast" if large else "hit")

func impact_event(x: float, y: float, kind: String):
	local_fx(x, y, kind, 5)

func create_audio():
	if DisplayServer.get_name() == "headless": return
	# Small original synthesized effects; no external sound downloads.
	for kind in ["fire", "hit", "blast", "coin", "skill", "tank"]:
		var duration = 0.09 if kind == "fire" else (0.16 if kind == "hit" else 0.55)
		var count = int(22050 * duration)
		var bytes = PackedByteArray()
		bytes.resize(count * 2)
		var filtered = 0.0
		var rng = RandomNumberGenerator.new()
		rng.seed = 1988
		for i in range(count):
			var t = float(i) / 22050
			var envelope = pow(1.0 - float(i) / count, 2.0)
			var noise = rng.randf_range(-1, 1)
			filtered = lerpf(filtered, noise, 0.12 if kind == "blast" else 0.6)
			var wave = (filtered * 0.8 + sin(t * (180 if kind == "blast" else 900) * TAU) * 0.2) * envelope
			if kind == "tank": wave = (filtered * 0.65 + sin(t * 110 * TAU) * 0.35) * envelope
			if kind == "coin": wave = sin(t * (1800 if t < 0.06 else 2400) * TAU) * envelope * 0.5
			if kind == "skill": wave = (sin(t * (400 + t * 2200) * TAU) * 0.7 + filtered * 0.3) * envelope
			bytes.encode_s16(i * 2, int(clampf(wave, -1, 1) * 26000))
		var stream = AudioStreamWAV.new()
		stream.format = AudioStreamWAV.FORMAT_16_BITS
		stream.mix_rate = 22050
		stream.data = bytes
		sound_bank[kind] = stream
	for i in range(8):
		var voice = AudioStreamPlayer.new()
		voice.volume_db = -15
		add_child(voice)
		voices.append(voice)

func play_sound(kind: String):
	if voices.is_empty(): return
	if kind == "fire":
		if fire_audio_cooldown > 0: return
		fire_audio_cooldown = 0.065
	var voice = voices[voice_index % voices.size()]
	voice_index += 1
	voice.stream = sound_bank[kind]
	voice.pitch_scale = randf_range(0.94, 1.06)
	voice.play()


@rpc("authority", "unreliable_ordered")
func snapshot_part(sequence: int, index: int, total: int, data: PackedByteArray):
	if host or total < 1 or total > 40 or index < 0 or index >= total or data.size() > 1000: return
	if sequence < assembling_packet: return
	if sequence != assembling_packet:
		assembling_packet = sequence
		packet_parts.clear()
	packet_parts[index] = data
	if packet_parts.size() == total:
		var payload = PackedByteArray()
		for i in range(total):
			if not packet_parts.has(i): return
			payload.append_array(packet_parts[i])
		compressed_snapshot(payload)
		packet_parts.clear()

func show_damage(x: float, y: float, amount: int):
	if online and host: damage_event.rpc(x, y, amount)
	else: damage_event(x, y, amount)

@rpc("authority", "call_local", "unreliable")
func damage_event(x: float, y: float, amount: int):
	if combat.numbers.size() < 35: combat.numbers.append({"x": x, "y": y, "amount": amount, "life": 0.65})

func skill_event(index: int):
	if online and host: skill_sound.rpc(index)
	else: skill_sound(index)

@rpc("authority", "call_local", "reliable")
func skill_sound(_index: int):
	combat.skill_flash = 0.35
	play_sound("skill")
	shake = maxf(shake, 4)

@rpc("authority", "call_local", "reliable")
func enter_cave():
	start_game(online, 2)

func _exit_tree():
	if music != null: music.stop()
	for voice in voices:
		if is_instance_valid(voice): voice.stop()
	if combat != null: combat.game = null
