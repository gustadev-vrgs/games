class_name TrucoRules
extends RefCounted

enum Phase { DEALING, PLAYING_TRICK, WAITING_TRUCO_RESPONSE, TRICK_REVEAL, HAND_END, MATCH_END }
const TEAM_A: int = 0
const TEAM_B: int = 1
const DRAW: int = -1
const UNDECIDED: int = -2
const VALUES: Array[int] = [1, 3, 6, 9, 12]

func compare_truco_cards(a: Dictionary, b: Dictionary, manilha: String) -> int:
	var am: bool = String(a.get("rank", "")) == manilha
	var bm: bool = String(b.get("rank", "")) == manilha
	if am and bm:
		return sign(DeckBuilder.TRUCO_SUITS.find(a.suit) - DeckBuilder.TRUCO_SUITS.find(b.suit))
	if am:
		return 1
	if bm:
		return -1
	return sign(DeckBuilder.TRUCO_RANKS.find(a.rank) - DeckBuilder.TRUCO_RANKS.find(b.rank))

func hand_result(results: Array) -> int:
	if results.size() >= 2:
		if results[0] == results[1] and results[0] in [TEAM_A, TEAM_B]:
			return results[0]
		if results[0] == DRAW and results[1] in [TEAM_A, TEAM_B]:
			return results[1]
		if results[1] == DRAW and results[0] in [TEAM_A, TEAM_B]:
			return results[0]
	if results.size() < 3:
		return UNDECIDED
	if results[2] in [TEAM_A, TEAM_B]:
		return results[2]
	for value: int in results:
		if value in [TEAM_A, TEAM_B]:
			return value
	return DRAW

func next_raise_value(value: int) -> int:
	var index: int = VALUES.find(value)
	return VALUES[index + 1] if index >= 0 and index + 1 < VALUES.size() else 0

func create_initial_state(peer_ids: Array, rng: RandomNumberGenerator, config: Dictionary = {}) -> Dictionary:
	var team_by_peer: Dictionary = {}
	var configured: Dictionary = config.get("team_by_peer", {}) as Dictionary
	for index: int in peer_ids.size():
		var peer_id: int = int(peer_ids[index])
		team_by_peer[peer_id] = int(configured.get(peer_id, TEAM_A if index in [0, 2] else TEAM_B))
	var team_members: Dictionary = {0: [], 1: []}
	for peer_id: int in peer_ids:
		team_members[int(team_by_peer[peer_id])].append(peer_id)
	var state: Dictionary = {"game_id":"truco","players":peer_ids.duplicate(),"team_by_peer":team_by_peer,"team_members":team_members,"hands":{},"scores":[0,0],"dealer_index":0,"state_version":0,"winner":-1,"match_end_emitted":false,"total_cards":40,"hand_number":0,"trick_history":[]}
	_start_hand(state, rng)
	return state

func _start_hand(state: Dictionary, rng: RandomNumberGenerator) -> void:
	var deck: Array[Dictionary] = DeckBuilder.shuffle(DeckBuilder.build_truco(), rng)
	state.hand_number = int(state.get("hand_number", 0)) + 1
	for id: int in state.players:
		state.hands[id] = []
	for amount: int in 3:
		for id: int in state.players:
			state.hands[id].append(deck.pop_back())
	state.turn_card = deck.pop_back()
	state.manilha = DeckBuilder.TRUCO_RANKS[(DeckBuilder.TRUCO_RANKS.find(state.turn_card.rank) + 1) % 10]
	state.draw_pile = deck
	state.played = []
	state.completed_cards = []
	state.trick_results = []
	state.trick_number = 1
	state.current_index = state.dealer_index
	state.trick_leader = state.dealer_index
	state.accepted_value = 1
	state.target_value = 0
	state.requesting_peer = -1
	state.requesting_team = -1
	state.responding_team = -1
	state.responding_peer = -1
	state.action_history = []
	state.last_raise_team = -1
	state.interrupted_index = -1
	state.pending_resolution = UNDECIDED
	state.reveal_result = {}
	state.phase = Phase.PLAYING_TRICK
	state.hand_end_emitted = false

func team_for_player(state: Dictionary, peer_id: int) -> int:
	var mapping: Dictionary = state.get("team_by_peer", {}) as Dictionary
	return int(mapping.get(peer_id, -1))

func validate_action(state: Dictionary, actor_id: int, action: Dictionary) -> Dictionary:
	if actor_id not in state.players:
		return ActionResult.rejected("UNREGISTERED_PEER")
	var team: int = team_for_player(state, actor_id)
	var kind: String = String(action.get("type", ""))
	if state.phase == Phase.WAITING_TRUCO_RESPONSE:
		if kind not in ["ACCEPT", "RUN", "RAISE"] or team != state.responding_team:
			return ActionResult.rejected("INVALID_TRUCO_RESPONSE")
		if kind == "RAISE" and next_raise_value(int(state.target_value)) == 0:
			return ActionResult.rejected("INVALID_TRUCO_RESPONSE")
		return ActionResult.accepted()
	if state.phase != Phase.PLAYING_TRICK:
		return ActionResult.rejected("INVALID_PHASE")
	if state.players[state.current_index] != actor_id:
		return ActionResult.rejected("NOT_YOUR_TURN")
	if kind == "REQUEST_TRUCO":
		if next_raise_value(int(state.accepted_value)) == 0 or state.last_raise_team == team:
			return ActionResult.rejected("INVALID_TRUCO_RESPONSE")
		return ActionResult.accepted()
	if kind == "PLAY_CARD_FACE_DOWN" and int(state.trick_number) == 1:
		return ActionResult.rejected("FACE_DOWN_FIRST_TRICK")
	if kind not in ["PLAY_CARD", "PLAY_CARD_FACE_DOWN"]:
		return ActionResult.rejected("INVALID_MESSAGE")
	for card: Dictionary in state.hands[actor_id]:
		if card.uid == action.get("card_uid", -1):
			return ActionResult.accepted()
	return ActionResult.rejected("CARD_NOT_OWNED")

func apply_action(state: Dictionary, actor_id: int, action: Dictionary, rng: RandomNumberGenerator) -> Dictionary:
	var result: Dictionary = validate_action(state, actor_id, action)
	if not result.accepted:
		return result
	var team: int = team_for_player(state, actor_id)
	match String(action.type):
		"REQUEST_TRUCO":
			state.target_value = next_raise_value(int(state.accepted_value))
			state.requesting_peer = actor_id
			state.requesting_team = team
			state.responding_team = 1 - team
			state.interrupted_index = state.current_index
			state.phase = Phase.WAITING_TRUCO_RESPONSE
			state.action_history.append({"type":"REQUEST","peer_id":actor_id,"team":team,"value":state.target_value})
		"ACCEPT":
			state.responding_peer = actor_id
			state.action_history.append({"type":"ACCEPT","peer_id":actor_id,"team":team,"value":state.target_value})
			state.accepted_value = state.target_value
			state.last_raise_team = state.requesting_team
			_clear_request(state)
			state.current_index = state.interrupted_index
			state.phase = Phase.PLAYING_TRICK
		"RAISE":
			state.responding_peer = actor_id
			state.action_history.append({"type":"RAISE","peer_id":actor_id,"team":team,"value":next_raise_value(int(state.target_value))})
			var previous_requesting_team: int = int(state.requesting_team)
			state.requesting_peer = actor_id
			state.requesting_team = state.responding_team
			state.responding_team = previous_requesting_team
			state.target_value = next_raise_value(int(state.target_value))
		"RUN":
			state.responding_peer = actor_id
			state.action_history.append({"type":"RUN","peer_id":actor_id,"team":team,"value":state.accepted_value})
			_finish_hand(state, int(state.requesting_team), int(state.accepted_value), rng)
		"PLAY_CARD":
			_play_card(state, actor_id, int(action.card_uid), false)
		"PLAY_CARD_FACE_DOWN":
			_play_card(state, actor_id, int(action.card_uid), true)
	state.state_version += 1
	return ActionResult.accepted() if validate_invariants(state) == "OK" else ActionResult.rejected("INTERNAL_STATE_ERROR")

func _clear_request(state: Dictionary) -> void:
	state.target_value = 0
	state.requesting_peer = -1
	state.requesting_team = -1
	state.responding_team = -1

func _play_card(state: Dictionary, actor_id: int, uid: int, face_down: bool) -> void:
	var hand: Array = state.hands[actor_id]
	var card: Dictionary = {}
	for index: int in hand.size():
		if hand[index].uid == uid:
			card = hand.pop_at(index)
			break
	state.played.append({"peer_id":actor_id,"team":team_for_player(state, actor_id),"face_down":face_down,"card":card})
	if state.played.size() < state.players.size():
		state.current_index = (state.current_index + 1) % state.players.size()
		return
	var open_plays: Array[Dictionary] = []
	for play_value: Variant in state.played:
		var candidate: Dictionary = play_value as Dictionary
		if not bool(candidate.get("face_down", false)):
			open_plays.append(candidate)
	var best: Dictionary = {} if open_plays.is_empty() else open_plays[0]
	var tied: bool = false
	for play_value: Variant in open_plays.slice(1):
		var play: Dictionary = play_value as Dictionary
		var comparison: int = compare_truco_cards(play.card, best.card, String(state.manilha))
		if comparison > 0:
			best = play
			tied = false
		elif comparison == 0 and play.team != best.team:
			tied = true
	var winner_team: int = DRAW if tied or best.is_empty() else int(best.team)
	state.trick_results.append(winner_team)
	state.pending_resolution = hand_result(state.trick_results)
	state.reveal_result = {"trick_number":state.trick_number,"winner_team":winner_team,"tied":winner_team == DRAW,"winning_peer":-1 if winner_team == DRAW else int(best.peer_id),"hand_winner":state.pending_resolution,"points":state.accepted_value}
	state.phase = Phase.TRICK_REVEAL

func advance_reveal(state: Dictionary, rng: RandomNumberGenerator) -> bool:
	if state.phase != Phase.TRICK_REVEAL:
		return false
	var history_entry: Dictionary = {"hand_number":state.hand_number,"trick_number":state.trick_number,"plays":state.played.duplicate(true),"winner_team":state.reveal_result.winner_team,"tied":state.reveal_result.tied}
	state.trick_history.append(history_entry)
	for play: Dictionary in state.played:
		state.completed_cards.append(play.card)
	if state.pending_resolution != UNDECIDED:
		_finish_hand(state, int(state.pending_resolution), int(state.accepted_value), rng)
	else:
		if bool(state.reveal_result.tied):
			state.current_index = state.trick_leader
		else:
			state.current_index = state.players.find(int(state.reveal_result.winning_peer))
			state.trick_leader = state.current_index
		state.played = []
		state.trick_number += 1
		state.reveal_result = {}
		state.phase = Phase.PLAYING_TRICK
	state.state_version += 1
	return true

func _finish_hand(state: Dictionary, team: int, value: int, rng: RandomNumberGenerator) -> void:
	if state.hand_end_emitted:
		return
	state.hand_end_emitted = true
	if team in [TEAM_A, TEAM_B]:
		state.scores[team] += value
	if state.scores[0] >= 12 or state.scores[1] >= 12:
		state.winner = 0 if state.scores[0] >= 12 else 1
		state.phase = Phase.MATCH_END
		state.match_end_emitted = true
		return
	state.dealer_index = (state.dealer_index + 1) % state.players.size()
	_start_hand(state, rng)

func build_public_snapshot(state: Dictionary) -> Dictionary:
	var counts: Dictionary = {}
	for id: int in state.players:
		counts[id] = state.hands[id].size()
	return {"game_id":"truco","players":state.players.duplicate(),"turn_order":state.players.duplicate(),"team_by_peer":state.team_by_peer.duplicate(true),"team_members":state.team_members.duplicate(true),"phase":state.phase,"current_player":state.players[state.current_index],"turn_card":state.turn_card.duplicate(true),"manilha":state.manilha,"played":_sanitize_plays(state.played),"scores":state.scores.duplicate(),"accepted_value":state.accepted_value,"target_value":state.target_value,"requesting_peer":state.requesting_peer,"responding_peer":state.responding_peer,"action_history":state.action_history.duplicate(true),"requesting_team":state.requesting_team,"responding_team":state.responding_team,"last_raise_team":state.last_raise_team,"next_raise_value":next_raise_value(int(state.target_value if state.phase==Phase.WAITING_TRUCO_RESPONSE else state.accepted_value)),"hand_number":state.hand_number,"trick_number":state.trick_number,"trick_history":_sanitize_history(state.trick_history),"reveal_result":state.reveal_result.duplicate(true),"card_counts":counts,"draw_count":state.draw_pile.size(),"winner":state.winner,"state_version":state.state_version}

func _sanitize_plays(plays: Array) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for value: Variant in plays:
		var play: Dictionary = value as Dictionary
		if bool(play.get("face_down", false)):
			result.append({"peer_id":int(play.get("peer_id", -1)), "team":int(play.get("team", -1)), "face_down":true, "card":{}})
		else:
			result.append(play.duplicate(true))
	return result

func _sanitize_history(history: Array) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for value: Variant in history:
		var entry: Dictionary = (value as Dictionary).duplicate(true)
		entry["plays"] = _sanitize_plays(entry.get("plays", []) as Array)
		result.append(entry)
	return result

func build_private_snapshot(state: Dictionary, peer_id: int) -> Dictionary:
	return {"peer_id":peer_id,"hand":state.hands.get(peer_id,[]).duplicate(true),"team":team_for_player(state, peer_id),"state_version":state.state_version}

func validate_invariants(state: Dictionary) -> String:
	var cards: Array[Dictionary] = []
	cards.append_array(state.draw_pile)
	cards.append(state.turn_card)
	for id: int in state.players:
		cards.append_array(state.hands[id])
	for play: Dictionary in state.played:
		cards.append(play.card)
	cards.append_array(state.completed_cards)
	return "OK" if cards.size() == 40 and DeckBuilder.validate_unique_uids(cards) else "CARD_CONSERVATION"

func is_match_finished(state: Dictionary) -> bool:
	return state.phase == Phase.MATCH_END
