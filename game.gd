extends Node2D

const PORT = 24765
const GROUND = 425.0
const END = 3400.0
var players: Array = []
var enemies: Array = []
var shots: Array = []
var particles: Array = []
var controls = [false, false, false, false, false]
var remote_controls = [false, false, false, false, false]
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

func _ready():
	RenderingServer.set_default_clear_color(Color("d69a63"))
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
	make_button("تجربة فردية / SOLO", Vector2(290, 150), func(): start_game(false))
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

func disconnect_game(message: String):
	online = false
	playing = false
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

func start_game(networked: bool):
	online = networked
	if not networked: host = true
	players.clear()
	for i in range(2 if networked else 1):
		players.append({"x": 120.0 + i * 65, "y": GROUND, "vy": 0.0, "hp": 100, "face": 1, "cd": 0.0, "inv": 0.0, "grenades": 5, "gcd": 0.0})
	enemies.clear()
	for x in [650, 920, 1200, 1530, 1760, 2050, 2300, 2580, 2800]:
		enemies.append({"x": float(x), "hp": 12, "cd": randf_range(0.5, 2.0)})
	shots.clear()
	particles.clear()
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
	if host and values.size() == 5 and multiplayer.get_remote_sender_id() in multiplayer.get_peers():
		for i in range(5): remote_controls[i] = values[i] == true

@rpc("authority", "unreliable_ordered")
func snapshot(p: Array, e: Array, s: Array, hp: int, points: int, done: bool):
	if not host:
		players = p
		enemies = e
		shots = s
		boss_hp = hp
		score = points
		finished = done

func _input(event):
	if event is InputEventKey:
		var keys = [KEY_A, KEY_D, KEY_SPACE, KEY_J, KEY_K]
		for i in range(5):
			if event.physical_keycode == keys[i]: controls[i] = event.pressed
		if event.pressed and event.physical_keycode == KEY_ESCAPE: disconnect_game("اختر وضع اللعب")
	if event is InputEventScreenTouch:
		if event.pressed: touch_actions[event.index] = action_at(event.position)
		else: touch_actions.erase(event.index)
	if event is InputEventScreenDrag:
		touch_actions[event.index] = action_at(event.position)
	if event is InputEventMouseButton and playing:
		if event.pressed: touch_actions[-1] = action_at(event.position)
		else: touch_actions.erase(-1)
	if event is InputEventMouseMotion and touch_actions.has(-1): touch_actions[-1] = action_at(event.position)
	if event is InputEventKey and event.pressed and event.physical_keycode == KEY_BACK: disconnect_game("اختر وضع اللعب")

func _notification(what):
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		controls.fill(false)
		touch_actions.clear()

func action_at(pos: Vector2) -> int:
	var centers = [Vector2(68, 465), Vector2(174, 465), Vector2(720, 465), Vector2(884, 440), Vector2(802, 485)]
	for i in range(5):
		if pos.distance_to(centers[i]) < 45: return i
	return -1

func _process(dt):
	dt = min(dt, 0.04)
	clock += dt
	if playing:
		var local = controls.duplicate()
		for a in touch_actions.values():
			if a >= 0: local[a] = true
		if host and not finished:
			simulate(dt, local)
		sync_clock += dt
		if online and sync_clock > 0.033:
			sync_clock = 0.0
			if host: snapshot.rpc(players, enemies, shots, boss_hp, score, finished)
			else: input_packet.rpc_id(1, local)
		var idx = 0 if host else 1
		if players.size() > idx: camera_x = clampf(players[idx].x - 350, 0, END - 960)
		var health = ""
		for i in range(players.size()): health += "P%d  ♥ %d    " % [i + 1, players[i].hp]
		hud.text = health + "     SCORE %06d" % score
		if finished: note.text = "المهمة اكتملت!" if boss_hp <= 0 else "انتهت المحاولة • ارجع للقائمة وأعد اللعب"
		else: note.text = "BOSS  %d" % boss_hp if camera_x > 2000 else "DUNE OUTPOST  •  MISSION 01"
	queue_redraw()

func simulate(dt: float, local: Array):
	for i in range(players.size()):
		var p = players[i]
		var c = local if i == 0 else remote_controls
		p.cd -= dt
		p.gcd -= dt
		p.inv -= dt
		if p.hp <= 0: continue
		var direction = int(c[1]) - int(c[0])
		p.x = clampf(p.x + direction * 235 * dt, 25, END - 130)
		if direction != 0: p.face = direction
		if c[2] and p.y >= GROUND:
			p.vy = -540.0
		p.vy += 1350 * dt
		p.y = minf(GROUND, p.y + p.vy * dt)
		if p.y >= GROUND: p.vy = 0.0
		if c[3] and p.cd <= 0:
			spawn_shot(p.x + p.face * 28, p.y - 36, p.face * 760, 0, false, false)
			p.cd = 0.13
		if c[4] and p.gcd <= 0 and p.grenades > 0:
			spawn_shot(p.x, p.y - 45, p.face * 360, -430, false, true)
			p.grenades -= 1
			p.gcd = 0.6
	for e in enemies:
		if e.hp <= 0: continue
		e.cd -= dt
		var target = nearest_player(e.x)
		if target.is_empty(): continue
		if absf(target.x - e.x) < 620 and e.cd <= 0:
			spawn_shot(e.x, GROUND - 33, signf(target.x - e.x) * 275, 0, true, false)
			e.cd = 1.5
	if boss_hp > 0:
		boss_cooldown -= dt
		var target = nearest_player(3160)
		if not target.is_empty() and target.x > 2450 and boss_cooldown <= 0:
			for y in [GROUND - 30, GROUND - 95]: spawn_shot(3070, y, -330, 0, true, false)
			boss_cooldown = 1.1
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
				if e.hp > 0 and absf(s.x - e.x) < 23 and absf(s.y - (GROUND - 28)) < 32:
					e.hp -= 4
					remove = true
					if e.hp <= 0: score += 100
					break
			if not remove and boss_hp > 0 and s.x > 3075 and s.x < 3270 and s.y > GROUND - 155:
				boss_hp = maxi(0, boss_hp - 2)
				remove = true
		elif s.enemy:
			for p in players:
				if p.hp > 0 and p.inv <= 0 and absf(p.x - s.x) < 20 and absf((p.y - 30) - s.y) < 30:
					p.hp = maxi(0, p.hp - 10)
					p.inv = 0.7
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
	particles.append({"x": x, "life": 0.45})
	for e in enemies:
		if e.hp > 0 and absf(e.x - x) < 135:
			e.hp = 0
			score += 100
	if absf(3160 - x) < 180: boss_hp = maxi(0, boss_hp - 30)

func box(x: float, y: float, w: float, h: float, color: String):
	draw_rect(Rect2(minf(x, x + w), minf(y, y + h), absf(w), absf(h)), Color(color))

func soldier(x: float, y: float, color: String, face: int, moving: bool):
	var step = sin(clock * 14) * 5 if moving else 0.0
	box(x - 14, y - 25, 10, 22 + step, "34352e")
	box(x + 3, y - 25, 10, 22 - step, "34352e")
	box(x - 18, y - 4 + step, 16, 6, "202c30")
	box(x + 2, y - 4 - step, 17, 6, "202c30")
	box(x - 15, y - 48, 30, 27, color)
	box(x - 10, y - 66, 22, 21, "e2ad7d")
	box(x - 12, y - 69, 25, 9, "30302e")
	box(x - 15, y - 61, 28, 5, color)
	box(x + face * 6 - 6, y - 38, 22 * face, 9, "e2ad7d")
	box(x + face * 12, y - 40, 31 * face, 8, "29363a")
	box(x + face * 31, y - 43, 9 * face, 5, "667375")

func _draw():
	box(0, 0, 960, 540, "e7ad75")
	draw_circle(Vector2(740, 110), 53, Color("ffdc9a"))
	for i in range(12):
		var x = i * 170 - fmod(camera_x * 0.22, 170)
		draw_colored_polygon(PackedVector2Array([Vector2(x - 90, 330), Vector2(x + 70, 140 + (i % 3) * 28), Vector2(x + 210, 330)]), Color("bb7d63"))
	for i in range(17):
		var x = i * 235 - fmod(camera_x * 0.55, 235)
		var height = 130 + (i % 3) * 32
		box(x, GROUND - height, 180, height, "bd865b")
		box(x - 5, GROUND - height, 190, 10, "f1c58a")
		for j in range(3):
			box(x + 20 + j * 51, GROUND - height + 30, 22, 39, "624d42")
			box(x + 23 + j * 51, GROUND - height + 32, 5, 35, "d7a16c")
		box(x + 45, GROUND - 64, 50, 64, "66513d")
		box(x + 16, GROUND - 91, 148, 14, "913f35")
		for j in range(7): box(x + 18 + j * 21, GROUND - 91, 10, 14, "ead8b0")
	box(0, GROUND, 960, 115, "92704f")
	box(0, GROUND, 960, 12, "f3ca8b")
	for i in range(70): box(fposmod(i * 83.0 - camera_x, 960), 448 + (i % 6) * 15, 15, 3, "b48b5b")
	if not playing: return
	for e in enemies:
		if e.hp > 0: soldier(e.x - camera_x, GROUND, "71794a", -1, false)
	if boss_hp > 0:
		var bx = 3160 - camera_x
		box(bx - 90, GROUND - 42, 170, 39, "323f3e")
		for i in range(6): draw_circle(Vector2(bx - 70 + i * 27, GROUND - 20), 14, Color("827f63"))
		box(bx - 75, GROUND - 100, 145, 62, "646d4b")
		box(bx - 45, GROUND - 147, 89, 50, "7f8052")
		box(bx - 125, GROUND - 128, 100, 19, "3c4941")
		box(bx - 25, GROUND - 135, 28, 13, "ef9b41")
		box(bx - 75, GROUND - 165, 150, 7, "302f30")
		box(bx - 75, GROUND - 165, 150.0 * boss_hp / 160, 7, "dd633d")
	for i in range(players.size()):
		var p = players[i]
		if p.hp > 0 and (p.inv <= 0 or int(clock * 15) % 2 == 0):
			soldier(p.x - camera_x, p.y, "397fbb" if i == 0 else "b54f40", p.face, true)
	for s in shots:
		if s.grenade: draw_circle(Vector2(s.x - camera_x, s.y), 6, Color("394c38"))
		else: box(s.x - camera_x, s.y, 15, 4, "ffdf74" if not s.enemy else "ff6645")
	for p in particles:
		draw_circle(Vector2(p.x - camera_x, GROUND - 25), (0.5 - p.life) * 200, Color(1, 0.5, 0.1, p.life * 2))
	var centers = [Vector2(68, 465), Vector2(174, 465), Vector2(720, 465), Vector2(884, 440), Vector2(802, 485)]
	var labels = ["◀", "▶", "↑", "FIRE", "BOMB"]
	for i in range(5):
		draw_circle(centers[i], 39, Color(0.08, 0.12, 0.15, 0.55))
		draw_arc(centers[i], 39, 0, TAU, 36, Color(1, 0.86, 0.65, 0.7), 2)
		draw_string(ThemeDB.fallback_font, centers[i] + Vector2(-22, 7), labels[i], HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color.WHITE)
	var idx = 0 if host else 1
	if players.size() > idx:
		draw_string(ThemeDB.fallback_font, Vector2(750, 532), "GRENADES: %d" % players[idx].grenades, HORIZONTAL_ALIGNMENT_LEFT, -1, 15)
