extends SceneTree
var game
var server_mode = false
var elapsed = 0.0
var passed_at = -1.0

func _initialize():
	server_mode = "host" in OS.get_cmdline_user_args()
	call_deferred("begin")

func begin():
	game = load("res://main.tscn").instantiate()
	root.add_child(game)
	if server_mode: game.host_game()
	else:
		game.address.text = "127.0.0.1"
		game.join_game()
	process_frame.connect(check)

func check():
	elapsed += root.get_process_delta_time()
	if not server_mode: game.controls = [false, true, false, true, false]
	if game.players.size() == 2 and game.players[1].x > (550 if server_mode else 600) and game.combat.waves_sent > 0 and passed_at < 0:
		passed_at = elapsed
		print("PASS: ENet ", "host received remote input" if server_mode else "guest received authoritative movement and state")
	if passed_at >= 0 and elapsed > passed_at + (0.8 if server_mode else 0.05):
		quit()
	if elapsed > 10:
		push_error("ENet integration timed out")
		quit(1)
