class_name CaxetaRules
extends RefCounted
enum Phase { DEALING, MUST_DRAW, MAY_KNOCK_TEN_OR_DISCARD, ROUND_END, MATCH_END }
var solver: CaxetaMeldSolver = CaxetaMeldSolver.new()
func create_initial_state(peer_ids: Array, rng: RandomNumberGenerator, lives: int = 7) -> Dictionary:
	var state: Dictionary = {"game_id":"caxeta","players":peer_ids.duplicate(),"hands":{},"lives":{},"eliminated":[],"starter_index":0,"current_index":0,"state_version":0,"winner":-1,"round_end_emitted":false,"total_cards":106}
	for id in peer_ids: state.hands[id]=[]; state.lives[id]=lives
	_start_round(state,rng); return state
func _start_round(state: Dictionary, rng: RandomNumberGenerator) -> void:
	var deck: Array[Dictionary] = DeckBuilder.shuffle(DeckBuilder.build_caxeta(),rng)
	for id in state.players: state.hands[id] = []
	for amount in 9:
		for id in state.players:
			if id not in state.eliminated: state.hands[id].append(deck.pop_back())
	state.draw_pile=deck; state.discard=[]; state.phase=Phase.MUST_DRAW; state.current_index=state.starter_index; state.round_end_emitted=false
func validate_action(state: Dictionary, actor_id: int, action: Dictionary) -> Dictionary:
	if state.players[state.current_index] != actor_id: return ActionResult.rejected("NOT_YOUR_TURN")
	var kind: String = action.get("type","")
	if state.phase == Phase.MUST_DRAW:
		if kind == "DRAW_PILE": return ActionResult.accepted()
		if kind == "DRAW_DISCARD" and not state.discard.is_empty(): return ActionResult.accepted()
		if kind == "KNOCK":
			if _is_complete_hand(state.hands[actor_id], 9): return ActionResult.accepted()
			return ActionResult.rejected("INVALID_KNOCK")
		return ActionResult.rejected("MUST_DRAW_FIRST")
	if state.phase != Phase.MAY_KNOCK_TEN_OR_DISCARD: return ActionResult.rejected("INVALID_PHASE")
	if kind in ["KNOCK", "KNOCK_TEN"]:
		return ActionResult.accepted() if _is_complete_hand(state.hands[actor_id], 10) else ActionResult.rejected("INVALID_KNOCK")
	if kind == "DISCARD":
		var hand: Array = state.hands[actor_id]; var uid: int = action.get("card_uid",-1)
		if not hand.any(func(card: Dictionary) -> bool: return card.uid == uid): return ActionResult.rejected("CARD_NOT_OWNED")
		if action.get("declare_knock",false):
			var remaining: Array = hand.filter(func(card: Dictionary) -> bool: return card.uid != uid)
			if not solver.can_partition_into_melds(remaining).valid: return ActionResult.rejected("INVALID_KNOCK")
		return ActionResult.accepted()
	return ActionResult.rejected("INVALID_MESSAGE")
func apply_action(state: Dictionary, actor_id: int, action: Dictionary, rng: RandomNumberGenerator) -> Dictionary:
	var result: Dictionary = validate_action(state,actor_id,action)
	if not result.accepted: return result
	if action.type == "DRAW_PILE":
		if state.draw_pile.is_empty(): _recycle(state,rng)
		if state.draw_pile.is_empty():
			_end_round(state,-1,0,rng)
			state.state_version += 1
			return ActionResult.accepted() if validate_invariants(state)=="OK" else ActionResult.rejected("INTERNAL_STATE_ERROR")
		state.hands[actor_id].append(state.draw_pile.pop_back()); state.phase=Phase.MAY_KNOCK_TEN_OR_DISCARD
	elif action.type == "DRAW_DISCARD": state.hands[actor_id].append(state.discard.pop_back()); state.phase=Phase.MAY_KNOCK_TEN_OR_DISCARD
	elif action.type in ["KNOCK", "KNOCK_TEN"]: _finish_match(state, actor_id)
	else:
		var hand: Array=state.hands[actor_id]
		for index in hand.size():
			if hand[index].uid == action.card_uid: state.discard.append(hand.pop_at(index)); break
		if action.get("declare_knock",false): _finish_match(state, actor_id)
		else: _advance(state)
	state.state_version += 1
	return ActionResult.accepted() if validate_invariants(state)=="OK" else ActionResult.rejected("INTERNAL_STATE_ERROR")
func _is_complete_hand(hand: Array, expected_size: int) -> bool:
	return hand.size() == expected_size and solver.can_partition_into_melds(hand).valid
func _finish_match(state: Dictionary, winner: int) -> void:
	state.round_end_emitted = true
	state.winner = winner
	state.phase = Phase.MATCH_END
func _recycle(state: Dictionary, rng: RandomNumberGenerator) -> void:
	if state.discard.size() <= 1: return
	var top: Dictionary=state.discard.pop_back(); var cards: Array[Dictionary]=[]
	for card in state.discard: cards.append(card)
	state.draw_pile=DeckBuilder.shuffle(cards,rng); state.discard=[top]
func _end_round(state: Dictionary, winner: int, loss: int, rng: RandomNumberGenerator) -> void:
	if state.round_end_emitted: return
	state.round_end_emitted=true
	if winner != -1:
		for id in state.players:
			if id != winner and id not in state.eliminated: state.lives[id]-=loss
	for id in state.players:
		if state.lives[id]<=0 and id not in state.eliminated: state.eliminated.append(id)
	var active: Array=state.players.filter(func(id: int)->bool:return id not in state.eliminated)
	if active.size()==1: state.winner=active[0]; state.phase=Phase.MATCH_END; return
	state.starter_index=_next_active_index(state,state.starter_index); _start_round(state,rng)
func _advance(state: Dictionary) -> void: state.current_index=_next_active_index(state,state.current_index); state.phase=Phase.MUST_DRAW
func _next_active_index(state: Dictionary, from: int) -> int:
	for offset in range(1,state.players.size()+1):
		var candidate: int=(from+offset)%state.players.size()
		if state.players[candidate] not in state.eliminated:return candidate
	return from
func build_public_snapshot(state: Dictionary)->Dictionary:
	var counts: Dictionary={}
	for id in state.players: counts[id]=state.hands[id].size()
	return {"game_id":"caxeta","phase":state.phase,"current_player":state.players[state.current_index],"lives":state.lives.duplicate(),"eliminated":state.eliminated.duplicate(),"discard_top":{} if state.discard.is_empty() else state.discard.back(),"card_counts":counts,"draw_count":state.draw_pile.size(),"winner":state.winner,"state_version":state.state_version}
func build_private_snapshot(state:Dictionary,peer_id:int)->Dictionary:return {"peer_id":peer_id,"hand":state.hands.get(peer_id,[]).duplicate(true),"state_version":state.state_version}
func validate_invariants(state:Dictionary)->String:
	var cards:Array[Dictionary]=[];cards.append_array(state.draw_pile);cards.append_array(state.discard)
	for id in state.players:cards.append_array(state.hands[id])
	return "OK" if cards.size()==106 and DeckBuilder.validate_unique_uids(cards) else "CARD_CONSERVATION"
func is_match_finished(state:Dictionary)->bool:return state.phase==Phase.MATCH_END
