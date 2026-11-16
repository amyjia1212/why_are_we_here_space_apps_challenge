# relay.gd
# The party relay (MULTIPLAYER_PLAN_V6 section 4): a "mail carrier" between the
# computers of one party. It runs as a small Godot program with no window:
#
#   Godot.exe --headless --path relay -s relay.gd -- 9080
#
# (or serve_relay.ps1 in the game folder). It does only this:
#   1. "create" makes a party and hands back a 4-letter code (seat 0 = leader)
#   2. "join" lets a player in by code (at most the party's max players)
#   3. "msg" passes a note to everyone else in the party (or to one seat)
#   4. tells the party when someone joins or leaves; closes an empty party
#   5. "lock" (from the leader, after START) stops new joins
# It saves nothing, keeps no names and never reads the notes.
# Codes use no vowels and no look-alike letters, so they never spell a word.
extends SceneTree

const LETTERS := "BCDFGHJKMNPQRSTVWXZ"
const CODE_LENGTH := 4
const MAX_PLAYERS := 4

var server := TCPServer.new()
var clients: Array = []      # { "peer": WebSocketPeer, "code": "", "seat": -1 }
var parties: Dictionary = {} # code -> { "max": 4, "locked": false, "seats": { seat: client } }


func _initialize() -> void:
	var port: int = 9080
	var args: PackedStringArray = OS.get_cmdline_user_args()
	if args.size() > 0 and args[0].is_valid_int():
		port = int(args[0])
	elif OS.has_environment("PORT"):   # most hosting services give the port this way
		port = int(OS.get_environment("PORT"))
	var error: int = server.listen(port, "*")
	if error != OK:
		print("Relay: could not listen on port ", port, " (error ", error, ")")
		quit(1)
		return
	print("Relay: listening on port ", port, ". Press Ctrl+C to stop.")
	# A second number = stop after that many seconds (for self-tests).
	if args.size() > 1 and args[1].is_valid_float():
		create_timer(float(args[1])).timeout.connect(quit)


func _process(_delta: float) -> bool:
	while server.is_connection_available():
		var peer := WebSocketPeer.new()
		peer.accept_stream(server.take_connection())
		clients.append({"peer": peer, "code": "", "seat": -1})
	for i in range(clients.size() - 1, -1, -1):
		var client: Dictionary = clients[i]
		var peer: WebSocketPeer = client["peer"]
		peer.poll()
		var state: int = peer.get_ready_state()
		if state == WebSocketPeer.STATE_OPEN:
			while peer.get_available_packet_count() > 0:
				var note = JSON.parse_string(peer.get_packet().get_string_from_utf8())
				if note is Dictionary:
					handle(client, note)
		elif state == WebSocketPeer.STATE_CLOSED:
			drop(client)
			clients.remove_at(i)
	return false


func handle(client: Dictionary, note: Dictionary) -> void:
	match str(note.get("op", "")):
		"create":
			if client["code"] != "":
				return
			var code: String = new_code()
			var max_players: int = clampi(int(note.get("max", MAX_PLAYERS)), 2, MAX_PLAYERS)
			parties[code] = {"max": max_players, "locked": false, "seats": {0: client}}
			client["code"] = code
			client["seat"] = 0
			send(client, {"op": "created", "code": code, "seat": 0})
		"join":
			if client["code"] != "":
				return
			var code: String = str(note.get("code", "")).to_upper()
			if not parties.has(code):
				send(client, {"op": "error", "reason": "no_party"})
				return
			var party: Dictionary = parties[code]
			if party["locked"]:
				send(client, {"op": "error", "reason": "locked"})
				return
			var seat: int = -1
			for s in party["max"]:
				if not party["seats"].has(s):
					seat = s
					break
			if seat < 0:
				send(client, {"op": "error", "reason": "full"})
				return
			for other in party["seats"].values():
				send(other, {"op": "peer_joined", "seat": seat})
			party["seats"][seat] = client
			client["code"] = code
			client["seat"] = seat
			send(client, {"op": "joined", "code": code, "seat": seat, "seats": party["seats"].keys()})
		"lock":
			if parties.has(client["code"]) and client["seat"] == 0:
				parties[client["code"]]["locked"] = true
		"msg":
			if not parties.has(client["code"]):
				return
			var out: Dictionary = {"op": "msg", "from": client["seat"], "data": note.get("data", {})}
			var seats: Dictionary = parties[client["code"]]["seats"]
			if note.has("to"):
				var to: int = int(note["to"])
				if seats.has(to):
					send(seats[to], out)
			else:
				for seat in seats:
					if seat != client["seat"]:
						send(seats[seat], out)


# A player hung up: tell the others, close the party when it is empty.
func drop(client: Dictionary) -> void:
	var code: String = client["code"]
	if not parties.has(code):
		return
	var seats: Dictionary = parties[code]["seats"]
	seats.erase(client["seat"])
	for other in seats.values():
		send(other, {"op": "peer_left", "seat": client["seat"]})
	if seats.is_empty():
		parties.erase(code)


func send(client: Dictionary, note: Dictionary) -> void:
	var peer: WebSocketPeer = client["peer"]
	if peer.get_ready_state() == WebSocketPeer.STATE_OPEN:
		peer.send_text(JSON.stringify(note))


func new_code() -> String:
	while true:
		var code: String = ""
		for i in CODE_LENGTH:
			code += LETTERS[randi() % LETTERS.length()]
		if not parties.has(code):
			return code
	return ""
