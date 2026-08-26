class_name UnoRules
extends RefCounted
enum Phase { DEALING, PLAYER_TURN, AFTER_DRAW_CHOICE, RESOLVING_EFFECT, MATCH_END }
const COLORS: PackedStringArray = ["red","yellow","green","blue"]
func create_initial_state(peer_ids: Array, rng: RandomNumberGenerator) -> Dictionary:
	var deck: Array[Dictionary] = DeckBuilder.shuffle(DeckBuilder.build_uno(),rng); var hands: Dictionary = {}
	for id in peer_ids: hands[id] = []
	for round_index in 7:
		for id in peer_ids: hands[id].append(deck.pop_back())
	var held: Array = []; var top: Dictionary = deck.pop_back()
	while not top.action.is_empty(): held.append(top); top = deck.pop_back()
	deck.append_array(held); deck = DeckBuilder.shuffle(deck,rng)
	return {"game_id":"uno","phase":Phase.PLAYER_TURN,"players":peer_ids.duplicate(),"hands":hands,"draw_pile":deck,"discard":[top],"active_color":top.color,"current_index":0,"direction":1,"drawn_uid":-1,"winner":-1,"last_play":{},"last_draw":{},"state_version":0,"total_cards":108}
func validate_action(state: Dictionary, actor_id: int, action: Dictionary) -> Dictionary:
	if state.phase != Phase.PLAYER_TURN and state.phase != Phase.AFTER_DRAW_CHOICE: return ActionResult.rejected("INVALID_PHASE")
	if state.players[state.current_index] != actor_id: return ActionResult.rejected("NOT_YOUR_TURN")
	var kind: String = action.get("type","")
	if kind == "DRAW_ONE": return ActionResult.accepted() if state.phase == Phase.PLAYER_TURN else ActionResult.rejected("ALREADY_DREW")
	if kind == "PASS": return ActionResult.accepted() if state.phase == Phase.AFTER_DRAW_CHOICE else ActionResult.rejected("MUST_DRAW_FIRST")
	if kind not in ["PLAY_CARD", "PLAY_CARDS"]: return ActionResult.rejected("INVALID_MESSAGE")
	var uids: Array = _action_uids(action)
	if uids.is_empty(): return ActionResult.rejected("INVALID_MESSAGE")
	var seen: Dictionary = {}; var cards: Array[Dictionary] = []
	for uid_value: Variant in uids:
		var uid: int = int(uid_value)
		if seen.has(uid): return ActionResult.rejected("DUPLICATE_CARD_UID")
		seen[uid] = true
		var owned: Dictionary = _find(state.hands[actor_id], uid)
		if owned.is_empty(): return ActionResult.rejected("CARD_NOT_OWNED")
		cards.append(owned)
	var card: Dictionary = cards[0]
	if state.phase == Phase.AFTER_DRAW_CHOICE:
		if cards.size() != 1: return ActionResult.rejected("CANNOT_COMBINE_AFTER_DRAW")
		if card.uid != state.drawn_uid: return ActionResult.rejected("CARD_NOT_PLAYABLE")
	if cards.size() > 1:
		if not _is_number(card): return ActionResult.rejected("COMBINATION_NUMBERS_ONLY")
		for combined: Dictionary in cards:
			if not _is_number(combined): return ActionResult.rejected("COMBINATION_NUMBERS_ONLY")
			if combined.rank != card.rank: return ActionResult.rejected("COMBINATION_NUMBER_MISMATCH")
	var chosen: String = action.get("chosen_color","")
	if card.action in ["wild","wild_draw_four"] and chosen not in COLORS: return ActionResult.rejected("INVALID_COLOR")
	if card.action not in ["wild","wild_draw_four"] and not chosen.is_empty(): return ActionResult.rejected("INVALID_COLOR")
	if card.action == "wild_draw_four":
		for owned in state.hands[actor_id]:
			if owned.uid != card.uid and owned.color == state.active_color: return ActionResult.rejected("ILLEGAL_WILD_DRAW_FOUR")
	if not is_playable(card,state.discard.back(),state.active_color): return ActionResult.rejected("CARD_NOT_PLAYABLE")
	return ActionResult.accepted()
func apply_action(state: Dictionary, actor_id: int, action: Dictionary, rng: RandomNumberGenerator) -> Dictionary:
	var valid: Dictionary = validate_action(state,actor_id,action)
	if not valid.accepted: return valid
	match action.type:
		"DRAW_ONE":
			var card: Dictionary = _draw(state,rng)
			if card.is_empty():
				state.last_draw = {"peer_id":actor_id,"card_uid":-1,"playable":false}
				_advance(state)
			else:
				state.hands[actor_id].append(card)
				state.drawn_uid = card.uid
				var playable: bool = is_playable(card,state.discard.back(),state.active_color)
				state.last_draw = {"peer_id":actor_id,"card_uid":card.uid,"playable":playable}
				if playable:
					state.phase = Phase.AFTER_DRAW_CHOICE
				else:
					_advance(state)
		"PASS": _advance(state)
		"PLAY_CARD", "PLAY_CARDS": _play(state,actor_id,action,rng)
	state.state_version += 1
	var invariant: String = validate_invariants(state)
	if invariant != "OK": return ActionResult.rejected("INTERNAL_STATE_ERROR")
	return ActionResult.accepted()
func _play(state: Dictionary, actor_id: int, action: Dictionary, rng: RandomNumberGenerator) -> void:
	var hand: Array = state.hands[actor_id]; var played: Array[Dictionary] = []
	for uid_value: Variant in _action_uids(action):
		var index: int = _index(hand, int(uid_value)); var removed: Dictionary = hand.pop_at(index)
		state.discard.append(removed); played.append(removed)
	var card: Dictionary = played.back()
	var chosen_color: String = String(action.get("chosen_color", ""))
	state.active_color = chosen_color if card.action in ["wild","wild_draw_four"] else card.color
	state.last_play = {"peer_id":actor_id,"card":card.duplicate(true),"cards":played.duplicate(true),"chosen_color":chosen_color,"declared_uno":bool(action.get("declared_uno",false))}
	state.drawn_uid = -1
	if hand.is_empty(): state.winner = actor_id; state.phase = Phase.MATCH_END; return
	if hand.size() == 1 and not action.get("declared_uno",false): _draw_many(state,actor_id,2,rng)
	if card.action == "reverse":
		if state.players.size() == 2: _advance(state,2)
		else: state.direction *= -1; _advance(state)
	elif card.action == "skip": _advance(state,2)
	elif card.action == "draw_two": _draw_many(state,_next_player(state),2,rng); _advance(state,2)
	elif card.action == "wild_draw_four": _draw_many(state,_next_player(state),4,rng); _advance(state,2)
	else: _advance(state)
func is_playable(card: Dictionary, top: Dictionary, active_color: String) -> bool:
	return card.action in ["wild","wild_draw_four"] or card.color == active_color or (not card.rank.is_empty() and card.rank == top.rank) or (not card.action.is_empty() and card.action == top.action)
func _draw(state: Dictionary, rng: RandomNumberGenerator) -> Dictionary:
	if state.draw_pile.is_empty() and state.discard.size() > 1:
		var top: Dictionary = state.discard.pop_back(); var recycled: Array[Dictionary] = []
		for card in state.discard: recycled.append(card)
		state.draw_pile = DeckBuilder.shuffle(recycled,rng); state.discard = [top]
	return {} if state.draw_pile.is_empty() else state.draw_pile.pop_back()
func _draw_many(state: Dictionary, id: int, count: int, rng: RandomNumberGenerator) -> void:
	for amount in count:
		var card: Dictionary = _draw(state,rng)
		if card.is_empty(): break
		state.hands[id].append(card)
func _advance(state: Dictionary, steps: int = 1) -> void: state.current_index = posmod(state.current_index + state.direction * steps,state.players.size()); state.phase = Phase.PLAYER_TURN; state.drawn_uid = -1
func _next_player(state: Dictionary) -> int: return state.players[posmod(state.current_index + state.direction,state.players.size())]
func _find(cards: Array, uid: int) -> Dictionary:
	for card in cards:
		if card.uid == uid: return card
	return {}
func _index(cards: Array, uid: int) -> int:
	for index in cards.size():
		if cards[index].uid == uid: return index
	return -1
func _action_uids(action: Dictionary) -> Array:
	if String(action.get("type", "")) == "PLAY_CARDS":
		var value: Variant = action.get("card_uids", [])
		return value.duplicate() if value is Array else []
	return [int(action.get("card_uid", -1))]
func _is_number(card: Dictionary) -> bool:
	var rank: String = String(card.get("rank", ""))
	return String(card.get("action", "")).is_empty() and rank in ["0","1","2","3","4","5","6","7","8","9"]
func build_public_snapshot(state: Dictionary) -> Dictionary:
	var counts: Dictionary = {}
	for id in state.players: counts[id] = state.hands[id].size()
	return {"game_id":"uno","phase":state.phase,"current_player":state.players[state.current_index],"active_color":state.active_color,"direction":state.direction,"top_card":state.discard.back().duplicate(true),"card_counts":counts,"draw_count":state.draw_pile.size(),"can_draw":not state.draw_pile.is_empty() or state.discard.size()>1,"last_play":state.last_play.duplicate(true),"last_draw":{"peer_id":int(state.last_draw.get("peer_id",-1)),"playable":bool(state.last_draw.get("playable",false))},"winner":state.winner,"state_version":state.state_version}
func build_private_snapshot(state: Dictionary, peer_id: int) -> Dictionary: return {"peer_id":peer_id,"hand":state.hands.get(peer_id,[]).duplicate(true),"drawn_uid":state.drawn_uid,"state_version":state.state_version}
func validate_invariants(state: Dictionary) -> String:
	var cards: Array[Dictionary] = []; cards.append_array(state.draw_pile); cards.append_array(state.discard)
	for id in state.players: cards.append_array(state.hands[id])
	return "OK" if cards.size() == 108 and DeckBuilder.validate_unique_uids(cards) else "CARD_CONSERVATION"
func is_match_finished(state: Dictionary) -> bool: return state.phase == Phase.MATCH_END
