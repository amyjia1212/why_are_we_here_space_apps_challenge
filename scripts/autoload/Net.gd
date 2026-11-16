# Net.gd
# Talks to the relay (MULTIPLAYER_PLAN_V6 section 4). The relay is a "mail
# carrier": it makes party codes, lets players join by code, and passes notes
# between the computers of one party. It knows nothing about the game.
# All game rules are in Party.gd. This file only sends and receives notes.
#     Net.create_party(4)          make a party; party_created(code, seat) comes back
#     Net.join_party("KXTR")       join one; joined(code, seat, seats) comes back
#     Net.send({"t": "vote", ...}) a note to every other player in the party
#     Net.send({...}, 2)           a note to seat 2 only
#     Net.leave()                  hang up
# Notes are small JSON dictionaries. Settings: data/multiplayer.json.
extends Node

signal party_created(code: String, seat: int)
signal joined(code: String, seat: int, seats: Array)
signal peer_joined(seat: int)
signal peer_left(seat: int)
signal message(from_seat: int, data: Dictionary)
signal failed(reason: String)     # "no_party", "full", "locked", "connect", "lost"

var socket: WebSocketPeer = null
var pending: Dictionary = {}       # the first request, sent once the socket is open
var connect_clock: float = 0.0
var opened: bool = false
var in_party: bool = false
var code: String = ""
var seat: int = -1


# The relay to use: relay_url, or the local one while relay_url is a PLACEHOLDER.
func relay_url() -> String:
	var url: String = str(Data.mp.get("relay_url", ""))
	if url.begins_with("PLACEHOLDER") or url == "":
		url = str(Data.mp["local_relay_url"])
	# A web page on https can only talk to wss:// (secure) relays; on http (localhost) ws:// works.
	return url


func create_party(max_players: int) -> void:
	open({"op": "create", "max": max_players})


func join_party(party_code: String) -> void:
	open({"op": "join", "code": party_code.strip_edges().to_upper()})


func send(data: Dictionary, to_seat: int = -1) -> void:
	if not in_party or socket == null:
		return
	var note: Dictionary = {"op": "msg", "data": data}
	if to_seat >= 0:
		note["to"] = to_seat
	socket.send_text(JSON.stringify(note))


# The party leader closes the door after START: nobody can join any more.
func lock_party() -> void:
	if in_party and socket != null:
		socket.send_text(JSON.stringify({"op": "lock"}))


func leave() -> void:
	if socket != null:
		socket.close()
	socket = null
	pending = {}
	opened = false
	in_party = false
	code = ""
	seat = -1


func open(first_request: Dictionary) -> void:
	leave()
	socket = WebSocketPeer.new()
	var error: int = socket.connect_to_url(relay_url())
	if error != OK:
		socket = null
		failed.emit("connect")
		return
	pending = first_request
	connect_clock = 0.0


func _process(delta: float) -> void:
	if socket == null:
		return
	socket.poll()
	var state: int = socket.get_ready_state()
	if state == WebSocketPeer.STATE_CONNECTING:
		connect_clock += delta
		if connect_clock > float(Data.mp["connect_timeout_seconds"]):
			leave()
			failed.emit("connect")
		return
	if state == WebSocketPeer.STATE_OPEN:
		if not opened:
			opened = true
			socket.send_text(JSON.stringify(pending))
			pending = {}
		while socket != null and socket.get_available_packet_count() > 0:
			var text: String = socket.get_packet().get_string_from_utf8()
			var note = JSON.parse_string(text)
			if note is Dictionary:
				handle(note)
		return
	if state == WebSocketPeer.STATE_CLOSED:
		var was_in_party: bool = in_party
		var was_opened: bool = opened
		leave()
		if was_in_party:
			failed.emit("lost")
		elif not was_opened:
			failed.emit("connect")


func handle(note: Dictionary) -> void:
	match str(note.get("op", "")):
		"created":
			in_party = true
			code = str(note["code"])
			seat = int(note["seat"])
			party_created.emit(code, seat)
		"joined":
			in_party = true
			code = str(note["code"])
			seat = int(note["seat"])
			joined.emit(code, seat, note.get("seats", []))
		"peer_joined":
			peer_joined.emit(int(note["seat"]))
		"peer_left":
			peer_left.emit(int(note["seat"]))
		"msg":
			if note.get("data") is Dictionary:
				message.emit(int(note.get("from", -1)), note["data"])
		"error":
			var reason: String = str(note.get("reason", "connect"))
			leave()
			failed.emit(reason)
