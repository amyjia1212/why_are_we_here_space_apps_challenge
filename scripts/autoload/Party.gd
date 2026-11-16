# Party.gd
# The party: who is playing together and how they agree (MULTIPLAYER_PLAN_V6).
#   mode "solo"   = one player, exactly the game as before
#   mode "bots"   = 2-4 seats on ONE computer: you + bots (no internet)
#   mode "online" = 2-4 seats on separate computers, joined by a party code
#                   (Net.gd talks to the relay); empty seats can be bots
#
# THE BIG RULE: the party leader's game is the boss. It holds the real
# GameState, rolls every random number (bot scores, coin flips, the stage
# seed) and decides when the party moves on. The others send requests
# ("I vote 2", "my score is 91", "I'm ready", "GO") and follow the answers.
# In a bots party you are the leader, so the same code runs without a network.
#
# Screens ask:
#   Party.is_party()       2+ seats (bots or online)
#   Party.is_online()      separate computers
#   Party.is_leader()
#   Party.size()           players incl. bots (1 when solo)
#   Party.scale("ship_problems")   the team-size multiplier (multiplayer.json)
# Numbers: data/multiplayer.json. Words: story.json "party".
extends Node

signal seats_changed
signal scores_ready(game_id: String)
signal votes_changed(cat: String)
signal vote_done(cat: String, value, how: String)
signal go_calls_changed
signal launch_now

var mode: String = "solo"
# One entry per seat: { "kind": "me" / "human" / "bot" / "empty", "name": "", "character": "" }
var seats: Array = []
var my_seat: int = 0
var started: bool = false
var code: String = ""
# Per-seat totals for the report: str(seat) -> { "fixed": 0, "data": 0.0 }
var stats: Dictionary = {}
var fake_humans: Array = []   # bots party only: bot seats that act as humans (debug key)

const LEADER := 0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	Net.party_created.connect(_on_party_created)
	Net.joined.connect(_on_joined)
	Net.peer_joined.connect(_on_peer_joined)
	Net.peer_left.connect(_on_peer_left)
	Net.message.connect(_on_message)
	Net.failed.connect(_on_net_failed)
	build_overlay()


# ---------- questions every screen can ask ----------

func is_party() -> bool:
	return mode != "solo"


func is_online() -> bool:
	return mode == "online"


func is_leader() -> bool:
	return mode != "online" or my_seat == LEADER


func size() -> int:
	return seats.size() if is_party() else 1


func scale(key: String) -> float:
	var table: Dictionary = Data.mp["scaling"]
	var row: Dictionary = table.get(str(clampi(size(), 1, int(Data.mp["max_players"]))), table["1"])
	return float(row[key])


func is_bot(seat: int) -> bool:
	return seat >= 0 and seat < seats.size() and seats[seat]["kind"] == "bot"


# The seats that vote, call GO and must be ready: real people (and fake humans in a bots party).
func human_seats() -> Array:
	var list: Array = []
	for i in seats.size():
		if seats[i]["kind"] == "me" or seats[i]["kind"] == "human" or fake_humans.has(i):
			list.append(i)
	return list


# Real people only (no fake humans).
func real_humans() -> Array:
	var list: Array = []
	for i in seats.size():
		if seats[i]["kind"] == "me" or seats[i]["kind"] == "human":
			list.append(i)
	return list


func bot_seats() -> Array:
	var list: Array = []
	for i in seats.size():
		if seats[i]["kind"] == "bot" and not fake_humans.has(i):
			list.append(i)
	return list


func seat_name(seat: int) -> String:
	if not is_party() or seat < 0 or seat >= seats.size():
		return GameState.get_player_label(0)
	var entry: Dictionary = seats[seat]
	var words: Dictionary = Data.story["party"]
	match str(entry["kind"]):
		"me":
			return GameState.player_name if GameState.player_name != "" else words["player_n"].format({"n": seat + 1})
		"empty":
			return words["seat_waiting"]
	var name: String = str(entry.get("name", ""))
	return name if name != "" else words["player_n"].format({"n": seat + 1})


# Bots that help on MY ship: bots are shared out between the people, seat by seat.
func bots_on_my_ship() -> Array:
	var people: Array = real_humans()
	var list: Array = []
	if people.is_empty():
		return list
	var bots: Array = bot_seats()
	for k in bots.size():
		if people[k % people.size()] == my_seat:
			list.append(bots[k])
	return list


# How many times the ship problems on MY ship: all of them with bots, a fair share online.
func ship_problem_factor() -> int:
	if not is_party():
		return 1
	return int(ceil(scale("ship_problems") / float(maxi(real_humans().size(), 1))))


func add_stat(seat: int, key: String, amount: float = 1.0) -> void:
	if not is_party():
		return
	var entry: Dictionary = stats.get(str(seat), {"fixed": 0, "data": 0.0})
	entry[key] = float(entry.get(key, 0.0)) + amount
	stats[str(seat)] = entry


func stat(seat: int, key: String) -> float:
	return float(stats.get(str(seat), {}).get(key, 0.0))


# ---------- making a party ----------

func reset() -> void:
	if Net.in_party or Net.socket != null:
		Net.leave()
	mode = "solo"
	seats = []
	my_seat = 0
	started = false
	code = ""
	stats = {}
	fake_humans = []
	ready_targets = {}
	contribs = {}
	waiting = false
	votes = {}
	score_box = {}
	go_calls = {}
	hide_overlay()


func me_entry() -> Dictionary:
	return {"kind": "me", "name": GameState.player_name, "character": GameState.character_id}


# A party with bots on this computer: you and (count - 1) bots.
func start_bots(count: int) -> void:
	reset()
	mode = "bots"
	seats = [me_entry()]
	for i in range(1, count):
		seats.append(bot_entry(i))
	seats_changed.emit()


func bot_entry(seat: int) -> Dictionary:
	var names: Array = Data.story["bots"]["crew"]
	var characters: Array = ["scientist", "janitor", "student"]
	return {"kind": "bot", "name": names[(seat - 1) % names.size()], "character": characters[seat % characters.size()]}


var pending_size: int = 0

# Other players join: ask the relay for a code.
func create_online(count: int) -> void:
	reset()
	pending_size = count
	Net.create_party(count)


func join_online(party_code: String) -> void:
	reset()
	Net.join_party(party_code)


func _on_party_created(new_code: String, seat: int) -> void:
	mode = "online"
	code = new_code
	my_seat = seat
	seats = [me_entry()]
	for i in range(1, pending_size):
		seats.append({"kind": "empty", "name": "", "character": ""})
	seats_changed.emit()


func _on_joined(new_code: String, seat: int, _seat_list: Array) -> void:
	mode = "online"
	code = new_code
	my_seat = seat
	seats = []   # the leader sends the real seat list
	Net.send({"t": "hello", "name": GameState.player_name, "character": GameState.character_id}, LEADER)
	seats_changed.emit()


func _on_peer_joined(_seat: int) -> void:
	pass   # the new player says hello next


# The leader turns an empty seat into a bot (in the lobby).
func make_seat_bot(seat: int) -> void:
	if not is_leader() or started or seat <= 0 or seat >= seats.size() or seats[seat]["kind"] != "empty":
		return
	seats[seat] = bot_entry(seat)
	send_seats()


func can_start() -> bool:
	if not is_leader() or seats.size() < 2:
		return false
	return not seats.any(func(s): return s["kind"] == "empty")


func send_seats() -> void:
	if is_online():
		Net.send({"t": "seats", "seats": seats_for_net()})   # each computer marks its own seat "me"
	seats_changed.emit()


# The seat list as the others see it: "me" becomes "human" (each computer marks its own "me").
func seats_for_net() -> Array:
	var list: Array = []
	for entry in seats:
		var copy: Dictionary = entry.duplicate()
		if copy["kind"] == "me":
			copy["kind"] = "human"
			copy["name"] = GameState.player_name
			copy["character"] = GameState.character_id
		list.append(copy)
	return list


# START (the leader): nobody can join any more; everyone moves on together.
func start() -> void:
	if not can_start() and mode != "bots":
		return
	started = true
	GameState.player_count = seats.size()
	stats = {}
	if is_online():
		Net.lock_party()
		advance(next_stage_after("party"))
	else:
		StageManager.go_to(next_stage_after("party"))


func next_stage_after(stage_id: String) -> String:
	var order: Array = Data.game_data["stages"]["order"]
	return order[order.find(stage_id) + 1]


# ---------- moving together (online) ----------
# Every StageManager.go_to() in an online party comes here first. A screen
# that wants to move on means "I'm ready". The leader moves everyone when
# every person is ready (or presses "Go anyway" after a while).

var ready_targets: Dictionary = {}   # str(seat) -> the stage that seat wants next
var contribs: Dictionary = {}        # str(seat) -> what that player did on this stage (data, goals, damage)
var waiting: bool = false
var wait_clock: float = 0.0
var applying: bool = false
var stage_start_data: float = 0.0
var bot_data_this_stage: float = 0.0


# true = Party took care of it (the screen must not change now).
func wants_stage(stage_id: String) -> bool:
	if applying:
		return false
	if stage_id == "start_menu":
		if is_party():
			reset()
		return false
	if not is_party():
		return false
	var current: String = StageManager.get_current()
	if current == "debrief" and is_leader():
		stats = {}   # Redesign / New mission: a new run, new report lines
	if not is_online() or not started:
		note_my_stage_end()
		return false
	if stage_id == current:
		return false   # a restart of the same screen (a failed trip) stays on this computer
	if waiting:
		return true
	waiting = true
	wait_clock = 0.0
	var mine: Dictionary = my_contrib()
	if is_leader():
		ready_targets[str(my_seat)] = stage_id
		contribs[str(my_seat)] = mine
		check_ready()
	else:
		Net.send({"t": "ready", "stage": current, "target": stage_id, "contrib": mine}, LEADER)
	show_waiting()
	return true


# What I did on this screen, for the leader to add to the team.
func my_contrib() -> Dictionary:
	return {
		"stage": StageManager.get_current(),
		"data": maxf(GameState.data_sent - stage_start_data - bot_data_this_stage, 0.0),
		"bot_data": bot_data_this_stage,
		"goals": GameState.goals.duplicate(),
		"goal_progress": GameState.goal_progress.duplicate(),
		"damage": GameState.damage.duplicate(),
		"fixed": stat_this_stage.duplicate(),
		"bot_seats": bot_data_seats.duplicate(),
	}


var stat_this_stage: Dictionary = {}   # str(seat) -> problems fixed on my ship on this screen
var bot_data_seats: Dictionary = {}    # str(bot seat) -> data that bot gathered on my ship on this screen

func note_fixed(seat: int) -> void:
	if not is_party():
		return
	add_stat(seat, "fixed")
	stat_this_stage[str(seat)] = int(stat_this_stage.get(str(seat), 0)) + 1


func note_bot_data(seat: int, amount: float) -> void:
	add_stat(seat, "data", amount)
	bot_data_this_stage += amount
	bot_data_seats[str(seat)] = float(bot_data_seats.get(str(seat), 0.0)) + amount


# Bots party (or before START): my data on this screen goes on my report line.
func note_my_stage_end() -> void:
	add_stat(my_seat, "data", maxf(GameState.data_sent - stage_start_data - bot_data_this_stage, 0.0))
	start_stage_counters()


func start_stage_counters() -> void:
	stage_start_data = GameState.data_sent
	bot_data_this_stage = 0.0
	stat_this_stage = {}
	bot_data_seats = {}


func check_ready() -> void:
	if not is_leader() or not waiting or not ready_targets.has(str(my_seat)):
		send_ready_state()
		return
	for seat in real_humans():
		if not ready_targets.has(str(seat)):
			send_ready_state()
			return
	advance(ready_targets[str(my_seat)])


func send_ready_state() -> void:
	if is_online() and is_leader():
		Net.send({"t": "ready_state", "ready": ready_targets.keys()})
	update_waiting_text()


# The leader moves the whole party to a stage, with the real GameState.
func advance(stage_id: String) -> void:
	merge_contribs()
	var seed_value: int = randi()
	var note: Dictionary = {"t": "stage", "id": stage_id, "state": sync_state(), "seed": seed_value, "stats": stats, "seats": seats_for_net()}
	Net.send(note)
	apply_stage(stage_id, note["state"], seed_value)


# Adds what everyone did on this screen to the leader's GameState and report lines.
func merge_contribs() -> void:
	var damage_sum: Dictionary = {}
	var damage_count: int = 0
	for key in contribs:
		var c: Dictionary = contribs[key]
		var seat: int = int(key)
		add_stat(seat, "data", float(c.get("data", 0.0)))
		var fixed: Dictionary = c.get("fixed", {})
		if seat != my_seat:
			GameState.data_sent += float(c.get("data", 0.0)) + float(c.get("bot_data", 0.0))
			for fixer in fixed:
				add_stat(int(fixer), "fixed", float(fixed[fixer]))
			var bot_data: Dictionary = c.get("bot_seats", {})
			for bot in bot_data:
				add_stat(int(bot), "data", float(bot_data[bot]))
			# The checklist: an item counts as done if anyone did it.
			var goals: Dictionary = c.get("goals", {})
			for goal_id in goals:
				if goals[goal_id] == "done" and GameState.goals.has(goal_id):
					GameState.goals[goal_id] = "done"
			var progress: Dictionary = c.get("goal_progress", {})
			for goal_id in progress:
				GameState.goal_progress[goal_id] = maxf(float(GameState.goal_progress.get(goal_id, 0.0)), float(progress[goal_id]))
		if str(c.get("stage", "")) == "launch":
			damage_count += 1
			var damage: Dictionary = c.get("damage", {})
			for kind in damage:
				damage_sum[kind] = float(damage_sum.get(kind, 0.0)) + float(damage[kind])
	# The launch: everyone did the timed presses; the team gets the average damage (DEFAULT).
	if damage_count > 1:
		GameState.damage.clear()
		for kind in damage_sum:
			GameState.damage[kind] = damage_sum[kind] / damage_count
	contribs = {}


# GameState plus the few things to_dict() leaves out.
func sync_state() -> Dictionary:
	var state: Dictionary = GameState.to_dict()
	state["retry_mode"] = GameState.retry_mode
	state["last_attempt"] = GameState.last_attempt.duplicate(true)
	state["cml_events"] = GameState.cml_events.duplicate()
	state["segment_reached"] = GameState.segment_reached
	state["run_recorded"] = GameState.run_recorded
	return state


func apply_stage(stage_id: String, state: Dictionary, seed_value: int) -> void:
	if not is_leader():
		# Each player keeps their own name, character and inner voice.
		var my_name: String = GameState.player_name
		var my_character: String = GameState.character_id
		GameState.from_dict(state)
		GameState.player_name = my_name
		GameState.character_id = my_character
		GameState.retry_mode = str(state.get("retry_mode", ""))
		GameState.last_attempt = state.get("last_attempt", {})
		GameState.cml_events = state.get("cml_events", {})
		GameState.segment_reached = int(state.get("segment_reached", -1))
		GameState.run_recorded = bool(state.get("run_recorded", false))
	started = true
	waiting = false
	ready_targets = {}
	contribs = {}
	score_box = {}
	votes = {}
	go_calls = {}
	hide_overlay()
	start_stage_counters()
	seed(seed_value)   # the same dice on every screen for this stage
	applying = true
	StageManager.go_to(stage_id)
	applying = false


# ---------- minigame scores ----------
# Everyone plays at the same time on their own screen; the frame sends one score.

var score_box: Dictionary = {}   # game_id -> { str(seat): score }
var score_clock: float = -1.0    # the leader's wait for missing scores (-1 = not waiting)
var score_game: String = ""


func submit_score(game_id: String, score: int, embedded: bool = false) -> void:
	if not is_online() or embedded:
		# Bots party (or a minigame inside the flight): my score + a roll for every bot.
		var list: Array = []
		for i in size():
			if i == my_seat or not is_party():
				list.append(score)
			elif is_bot(i) and not fake_humans.has(i):
				list.append(roll_bot_score())
			else:
				list.append(score if fake_humans.has(i) else 0)
		GameState.minigame_scores[game_id] = list
		scores_ready.emit(game_id)
		return
	if is_leader():
		receive_score(my_seat, game_id, score)
	else:
		Net.send({"t": "score", "game": game_id, "score": score}, LEADER)


func roll_bot_score() -> int:
	var bots: Dictionary = Data.mp["bots"]
	return randi_range(int(bots["minigame_score_min"]), int(bots["minigame_score_max"]))


func receive_score(seat: int, game_id: String, score: int) -> void:
	var box: Dictionary = score_box.get(game_id, {})
	box[str(seat)] = score
	score_box[game_id] = box
	if box.has(str(my_seat)):
		score_game = game_id
		score_clock = float(Data.mp["score_wait_seconds"])   # each new score starts the wait again
	check_scores(game_id, false)


func check_scores(game_id: String, time_up: bool) -> void:
	var box: Dictionary = score_box.get(game_id, {})
	if not box.has(str(my_seat)):
		return
	for seat in real_humans():
		if not box.has(str(seat)) and not time_up:
			return
	var list: Array = []
	for i in seats.size():
		if is_bot(i):
			list.append(roll_bot_score())
		else:
			list.append(int(box.get(str(i), 0)))   # no score in time = 0
	score_clock = -1.0
	score_box.erase(game_id)
	Net.send({"t": "scores", "game": game_id, "list": list})
	apply_scores(game_id, list)


func apply_scores(game_id: String, list: Array) -> void:
	var clean: Array = []
	for value in list:
		clean.append(int(value))
	GameState.minigame_scores[game_id] = clean
	scores_ready.emit(game_id)


# ---------- votes (Mission Room and Design Rooms) ----------
# One vote per person per choice; Enter locks it (it can be changed until the
# vote ends). Ends when every person voted, or after vote_seconds. Most votes
# wins. Tie: "Tie! Talk it over." and one revote between the tied options;
# still tied: a coin flip. Bots vote with the humans' favorite, so they never
# change who wins. Instruments: an instrument is in when more than half the
# party wants it; exactly half = a coin flip (DEFAULT: no revote for instruments).

var votes: Dictionary = {}       # cat -> { str(seat): value }  (value = option id, or a list for instruments)
var vote_cat: String = ""
var vote_options: Array = []     # what can still be voted for (the tied ones in a revote)
var vote_round: int = 0          # 0 = the first vote, 1 = the tie revote
var vote_left: float = 0.0
var vote_multi: bool = false
var vote_open: bool = false
var vote_tick: float = 0.0


func begin_vote(cat: String, options: Array, multi: bool) -> void:
	vote_cat = cat
	vote_options = options.duplicate()
	vote_round = 0
	vote_multi = multi
	vote_open = true
	vote_left = float(Data.mp["vote_seconds"])
	fake_humans = []
	if not votes.has(cat):
		votes[cat] = {}
	votes_changed.emit(cat)
	if is_leader():
		check_votes(false)


func cast_vote(cat: String, value) -> void:
	if not vote_open or cat != vote_cat:
		return
	if is_leader():
		receive_vote(my_seat, cat, value, vote_round)
	else:
		var box: Dictionary = votes.get(cat, {})
		box[str(my_seat)] = value
		votes[cat] = box
		votes_changed.emit(cat)
		Net.send({"t": "vote", "cat": cat, "value": value, "round": vote_round}, LEADER)


func receive_vote(seat: int, cat: String, value, round_number: int) -> void:
	if cat == vote_cat and round_number != vote_round:
		return   # a vote from the first round that arrived after the revote started
	if cat == vote_cat and not vote_multi and not vote_options.has(value):
		return
	var box: Dictionary = votes.get(cat, {})
	box[str(seat)] = value
	votes[cat] = box
	if cat == vote_cat:
		send_votes()
		check_votes(false)


func my_vote(cat: String):
	return votes.get(cat, {}).get(str(my_seat), null)


func vote_count(cat: String) -> int:
	return votes.get(cat, {}).size()


# How many votes each option has, with the bots' votes added (for the dots).
func vote_tally(cat: String) -> Dictionary:
	var tally: Dictionary = {}
	var box: Dictionary = votes.get(cat, {})
	for seat in box:
		var value = box[seat]
		if value is Array:
			for id in value:
				tally[id] = int(tally.get(id, 0)) + 1
		else:
			tally[value] = int(tally.get(value, 0)) + 1
	return tally


func send_votes() -> void:
	if is_online() and is_leader():
		Net.send({"t": "votes", "cat": vote_cat, "votes": votes.get(vote_cat, {}), "round": vote_round, "options": vote_options, "left": vote_left})
	votes_changed.emit(vote_cat)


# Debug key (bots party): a bot seat becomes a fake human and votes for an
# option that is NOT yours, so ties, revotes and coin flips can be tested alone.
func cast_fake_vote(my_preview) -> void:
	if mode != "bots" or not vote_open or not is_leader():
		return
	var free: Array = []
	for i in seats.size():
		if seats[i]["kind"] == "bot" and not fake_humans.has(i):
			free.append(i)
	if free.is_empty():
		return
	var seat: int = free[0]
	fake_humans.append(seat)
	var value
	if vote_multi:
		value = vote_options.filter(func(id): return my_preview == null or not (my_preview as Array).has(id))
	else:
		value = vote_options[0]
		for id in vote_options:
			if str(id) != str(my_preview):
				value = id
				break
	Hud.flash(Data.story["party"]["fake_vote"].format({"name": seat_name(seat)}))
	receive_vote(seat, vote_cat, value, vote_round)


func check_votes(time_up: bool) -> void:
	if not is_leader() or not vote_open:
		return
	var box: Dictionary = votes.get(vote_cat, {})
	var people: Array = human_seats()
	var all_in: bool = people.all(func(seat): return box.has(str(seat)))
	if not all_in and not time_up:
		return
	if box.is_empty():
		vote_left = float(Data.mp["vote_seconds"])   # nobody voted: the timer starts again
		send_votes()
		return
	if vote_multi:
		finish_vote(instrument_result(box), "win")
		return
	# Count the people's votes; the bots join the favorite (they never change who wins).
	var tally: Dictionary = {}
	for seat in box:
		tally[box[seat]] = int(tally.get(box[seat], 0)) + 1
	var best: int = 0
	for id in tally:
		best = maxi(best, tally[id])
	var top: Array = vote_options.filter(func(id): return int(tally.get(id, 0)) == best)
	if top.size() == 1:
		finish_vote(top[0], "win")
	elif vote_round == 0:
		# Tie! Talk it over: one short revote between the tied options.
		vote_round = 1
		vote_options = top
		vote_left = float(Data.mp["tie_revote_seconds"])
		var fakes: Dictionary = {}
		for seat in fake_humans:
			var old = box.get(str(seat), top[0])
			fakes[str(seat)] = old if top.has(old) else top[0]   # fake humans keep their vote if they can
		votes[vote_cat] = fakes
		if is_online():
			Net.send({"t": "tie", "cat": vote_cat, "options": top})
		Hud.flash(Data.story["party"]["tie"])
		send_votes()
	else:
		finish_vote(top[randi() % top.size()], "coin")


func instrument_result(box: Dictionary) -> Array:
	var people: int = box.size()
	var party: int = size()
	var bots: int = party - human_seats().size()
	var result: Array = []
	for id in vote_options:
		var yes: int = 0
		for seat in box:
			if (box[seat] as Array).has(id):
				yes += 1
		if yes * 2 > people:
			yes += bots   # the bots want what most people want
		if yes * 2 > party:
			result.append(id)
		elif yes * 2 == party and randi() % 2 == 0:
			result.append(id)   # exactly half: a coin flip
	return result


func finish_vote(value, how: String) -> void:
	if is_online():
		Net.send({"t": "vote_result", "cat": vote_cat, "value": value, "how": how})
	apply_vote_result(vote_cat, value, how)


func apply_vote_result(cat: String, value, how: String) -> void:
	vote_open = false
	votes.erase(cat)
	fake_humans = []
	vote_done.emit(cat, value, how)


# ---------- the GO / NO-GO poll on the launch pad ----------
# Every person says GO or NO-GO; bots always say GO. GO FOR LAUNCH stays
# locked until every row says GO.

var go_calls: Dictionary = {}   # str(seat) -> "go" / "nogo" (missing = not decided yet)


func go_call(seat: int) -> String:
	if is_bot(seat) and not fake_humans.has(seat):
		return "go"
	return str(go_calls.get(str(seat), ""))


func all_go() -> bool:
	if not is_party():
		return true
	for i in seats.size():
		if go_call(i) != "go":
			return false
	return true


func set_go_call(call: String) -> void:
	if is_leader():
		receive_go_call(my_seat, call)
	else:
		go_calls[str(my_seat)] = call
		go_calls_changed.emit()
		Net.send({"t": "go_call", "call": call}, LEADER)


func receive_go_call(seat: int, call: String) -> void:
	go_calls[str(seat)] = call
	if is_online() and is_leader():
		Net.send({"t": "go_calls", "calls": go_calls})
	go_calls_changed.emit()


# Debug key (bots party): a bot becomes a fake human who says NO-GO; press again to flip it.
func flip_fake_go() -> void:
	if mode != "bots":
		return
	if fake_humans.is_empty():
		var bots: Array = bot_seats()
		if bots.is_empty():
			return
		fake_humans.append(bots[0])
		receive_go_call(bots[0], "nogo")
	else:
		var seat: int = fake_humans[0]
		receive_go_call(seat, "go" if go_call(seat) == "nogo" else "nogo")
	Hud.flash(Data.story["party"]["fake_go"].format({"name": seat_name(fake_humans[0]), "call": go_call(fake_humans[0]).to_upper()}))


# GO FOR LAUNCH: everyone's launch starts at the same moment.
func request_launch() -> void:
	if not all_go():
		return
	if not is_online():
		launch_now.emit()
	elif is_leader():
		Net.send({"t": "launch"})
		launch_now.emit()
	else:
		Net.send({"t": "launch_req"}, LEADER)


# ---------- notes from the other computers ----------

func _on_message(from_seat: int, data: Dictionary) -> void:
	var t: String = str(data.get("t", ""))
	if is_leader():
		match t:
			"hello":
				if from_seat > 0 and from_seat < seats.size() and not started:
					seats[from_seat] = {"kind": "human", "name": str(data.get("name", "")), "character": str(data.get("character", ""))}
					send_seats()
			"ready":
				if not started:
					return
				ready_targets[str(from_seat)] = str(data.get("target", ""))
				contribs[str(from_seat)] = data.get("contrib", {})
				check_ready()
			"score":
				receive_score(from_seat, str(data["game"]), int(data["score"]))
			"vote":
				receive_vote(from_seat, str(data["cat"]), data["value"], int(data.get("round", 0)))
			"go_call":
				receive_go_call(from_seat, str(data["call"]))
			"launch_req":
				request_launch()
		return
	if from_seat != LEADER:
		return   # only the leader's answers count
	match t:
		"seats":
			seats = data.get("seats", [])
			if my_seat < seats.size():
				seats[my_seat]["kind"] = "me"
			seats_changed.emit()
		"stage":
			seats = data.get("seats", seats)
			if my_seat < seats.size():
				seats[my_seat]["kind"] = "me"
			stats = data.get("stats", {})
			apply_stage(str(data["id"]), data.get("state", {}), int(data.get("seed", 0)))
		"ready_state":
			remote_ready = data.get("ready", [])
			update_waiting_text()
		"scores":
			apply_scores(str(data["game"]), data.get("list", []))
		"votes":
			if str(data["cat"]) == vote_cat:
				votes[vote_cat] = data.get("votes", {})
				vote_round = int(data.get("round", 0))
				vote_options = data.get("options", vote_options)
				vote_left = float(data.get("left", vote_left))
				votes_changed.emit(vote_cat)
		"tie":
			Hud.flash(Data.story["party"]["tie"])
		"vote_result":
			apply_vote_result(str(data["cat"]), data["value"], str(data.get("how", "win")))
		"go_calls":
			go_calls = data.get("calls", {})
			go_calls_changed.emit()
		"launch":
			launch_now.emit()

var remote_ready: Array = []


func _on_peer_left(seat: int) -> void:
	if seat == LEADER and not is_leader():
		party_over(Data.story["party"]["leader_left"])
		return
	if not is_leader() or seat >= seats.size():
		return
	if not started:
		seats[seat] = {"kind": "empty", "name": "", "character": ""}   # back to "Waiting…" in the lobby
	else:
		var name: String = seat_name(seat)
		seats[seat] = bot_entry(seat)   # a bot takes the seat and the mission goes on
		Hud.flash(Data.story["party"]["player_left"].format({"name": name}))
		ready_targets.erase(str(seat))
		check_ready()
		for game_id in score_box.keys():
			check_scores(game_id, false)
		if vote_open:
			votes.get(vote_cat, {}).erase(str(seat))
			check_votes(false)
		go_calls.erase(str(seat))
		if is_online():
			Net.send({"t": "go_calls", "calls": go_calls})
		go_calls_changed.emit()
	send_seats()


func _on_net_failed(reason: String) -> void:
	var words: Dictionary = Data.story["party"]["errors"]
	if started and reason == "lost":
		party_over(words["lost"])
		return
	party_error = words.get(reason, words["connect"])
	reset()
	seats_changed.emit()

var party_error: String = ""   # the last join/connect problem, for the party screen


# The mission ends for everyone (the leader left, or the connection is gone).
func party_over(text: String) -> void:
	reset()
	Hud.flash(text)
	party_error = text
	StageManager.go_to("start_menu")


# ---------- timers ----------

func _process(delta: float) -> void:
	if not is_party():
		return
	if waiting:
		wait_clock += delta
		if is_leader() and go_anyway_button != null:
			go_anyway_button.visible = wait_clock >= float(Data.mp["ready_go_anyway_seconds"]) and ready_targets.has(str(my_seat))
	if not is_leader():
		return
	if vote_open:
		vote_left -= delta
		vote_tick += delta
		if vote_tick >= 1.0:
			vote_tick = 0.0
			send_votes()
		if vote_left <= 0.0:
			check_votes(true)
	if score_clock >= 0.0:
		score_clock -= delta
		if score_clock < 0.0:
			check_scores(score_game, true)


# ---------- the waiting box ("Waiting for the others…") ----------

var overlay_layer: CanvasLayer
var overlay_panel: PanelContainer
var overlay_label: Label
var go_anyway_button: Button


func build_overlay() -> void:
	overlay_layer = CanvasLayer.new()
	overlay_layer.layer = 90
	add_child(overlay_layer)
	overlay_panel = PanelContainer.new()
	overlay_panel.theme_type_variation = &"GlassPanel"
	overlay_panel.anchor_left = 0.5
	overlay_panel.anchor_right = 0.5
	overlay_panel.anchor_top = 0.0
	overlay_panel.offset_left = -260
	overlay_panel.offset_right = 260
	overlay_panel.offset_top = 72
	overlay_panel.visible = false
	overlay_layer.add_child(overlay_panel)
	var row := VBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	overlay_panel.add_child(row)
	overlay_label = Label.new()
	overlay_label.theme_type_variation = &"BodyText"
	overlay_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	overlay_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	row.add_child(overlay_label)
	go_anyway_button = Button.new()
	go_anyway_button.theme_type_variation = &"SmallButton"
	go_anyway_button.visible = false
	go_anyway_button.pressed.connect(_on_go_anyway)
	row.add_child(go_anyway_button)


func show_waiting() -> void:
	go_anyway_button.text = Data.story["party"]["go_anyway"]
	go_anyway_button.visible = false
	overlay_panel.visible = true
	update_waiting_text()


func update_waiting_text() -> void:
	if not waiting or overlay_label == null:
		return
	var words: Dictionary = Data.story["party"]
	var ready_list: Array = ready_targets.keys() if is_leader() else remote_ready
	var total: int = real_humans().size()
	var count: int = clampi(ready_list.size(), 1, total)
	overlay_label.text = words["waiting_ready"].format({"ready": count, "total": total}) if is_leader() else words["waiting_leader"].format({"ready": count, "total": total})


func hide_overlay() -> void:
	if overlay_panel != null:
		overlay_panel.visible = false


func _on_go_anyway() -> void:
	if is_leader() and waiting and ready_targets.has(str(my_seat)):
		advance(ready_targets[str(my_seat)])
