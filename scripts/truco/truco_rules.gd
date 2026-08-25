class_name TrucoRules
extends RefCounted
enum Phase { DEALING, PLAYING_TRICK, WAITING_TRUCO_RESPONSE, HAND_END, MATCH_END }
const TEAM_A: int = 0; const TEAM_B: int = 1; const DRAW: int = -1; const UNDECIDED: int = -2
func compare_truco_cards(a:Dictionary,b:Dictionary,manilha:String)->int:
	var am: bool = String(a.get("rank", "")) == manilha
	var bm: bool = String(b.get("rank", "")) == manilha
	if am and bm:return sign(DeckBuilder.SUITS.find(a.suit)-DeckBuilder.SUITS.find(b.suit))
	if am:return 1
	if bm:return -1
	return sign(DeckBuilder.TRUCO_RANKS.find(a.rank)-DeckBuilder.TRUCO_RANKS.find(b.rank))
func hand_result(results:Array)->int:
	if results.size()>=2:
		if results[0]==results[1] and results[0] in [TEAM_A,TEAM_B]:return results[0]
		if results[0]==DRAW and results[1] in [TEAM_A,TEAM_B]:return results[1]
		if results[1]==DRAW and results[0] in [TEAM_A,TEAM_B]:return results[0]
	if results.size()<3:return UNDECIDED
	if results[2] in [TEAM_A,TEAM_B]:return results[2]
	for value in results:
		if value in [TEAM_A,TEAM_B]:return value
	return DRAW
func create_initial_state(peer_ids:Array,rng:RandomNumberGenerator)->Dictionary:
	var state: Dictionary={"game_id":"truco","players":peer_ids.duplicate(),"hands":{},"scores":[0,0],"dealer_index":0,"state_version":0,"winner":-1,"match_end_emitted":false,"total_cards":40}
	_start_hand(state,rng);return state
func _start_hand(state:Dictionary,rng:RandomNumberGenerator)->void:
	var deck: Array[Dictionary]=DeckBuilder.shuffle(DeckBuilder.build_truco(),rng)
	for id in state.players:state.hands[id]=[]
	for amount in 3:
		for id in state.players:state.hands[id].append(deck.pop_back())
	state.turn_card=deck.pop_back();state.manilha=DeckBuilder.TRUCO_RANKS[(DeckBuilder.TRUCO_RANKS.find(state.turn_card.rank)+1)%10];state.draw_pile=deck;state.played=[];state.completed_cards=[];state.trick_results=[];state.current_index=state.dealer_index;state.trick_leader=state.dealer_index;state.accepted_value=1;state.target_value=0;state.requesting_team=-1;state.responding_team=-1;state.last_raise_team=-1;state.interrupted_index=-1;state.phase=Phase.PLAYING_TRICK;state.hand_end_emitted=false
func validate_action(state:Dictionary,actor_id:int,action:Dictionary)->Dictionary:
	if actor_id not in state.players:return ActionResult.rejected("UNREGISTERED_PEER")
	var players: Array = state.get("players", []) as Array
	var team: int = players.find(actor_id) % 2
	var kind:String=String(action.get("type",""))
	if state.phase==Phase.WAITING_TRUCO_RESPONSE:
		if kind not in ["ACCEPT","RUN","RAISE"] or team!=state.responding_team:return ActionResult.rejected("INVALID_TRUCO_RESPONSE")
		if kind=="RAISE" and state.target_value>=12:return ActionResult.rejected("INVALID_TRUCO_RESPONSE")
		return ActionResult.accepted()
	if state.phase!=Phase.PLAYING_TRICK:return ActionResult.rejected("INVALID_PHASE")
	if state.players[state.current_index]!=actor_id:return ActionResult.rejected("NOT_YOUR_TURN")
	if kind=="REQUEST_TRUCO":
		if state.accepted_value>=12 or state.last_raise_team==team:return ActionResult.rejected("INVALID_TRUCO_RESPONSE")
		return ActionResult.accepted()
	if kind!="PLAY_CARD":return ActionResult.rejected("INVALID_MESSAGE")
	for card in state.hands[actor_id]:
		if card.uid==action.get("card_uid",-1):return ActionResult.accepted()
	return ActionResult.rejected("CARD_NOT_OWNED")
func apply_action(state:Dictionary,actor_id:int,action:Dictionary,rng:RandomNumberGenerator)->Dictionary:
	var result: Dictionary=validate_action(state,actor_id,action)
	if not result.accepted:return result
	var players: Array = state.get("players", []) as Array
	var team: int = players.find(actor_id) % 2
	match action.type:
		"REQUEST_TRUCO":
			state.target_value=3 if state.accepted_value==1 else state.accepted_value+3;state.requesting_team=team;state.responding_team=1-team;state.interrupted_index=state.current_index;state.phase=Phase.WAITING_TRUCO_RESPONSE
		"ACCEPT":state.accepted_value=state.target_value;state.last_raise_team=state.requesting_team;state.target_value=0;state.current_index=state.interrupted_index;state.phase=Phase.PLAYING_TRICK
		"RAISE":
			var old: int = int(state.get("requesting_team", -1))
			state.requesting_team=state.responding_team
			state.responding_team=old
			state.target_value=state.target_value+3
		"RUN":_finish_hand(state,state.requesting_team,state.accepted_value,rng)
		"PLAY_CARD":_play_card(state,actor_id,action.card_uid,rng)
	state.state_version+=1
	return ActionResult.accepted() if validate_invariants(state)=="OK" else ActionResult.rejected("INTERNAL_STATE_ERROR")
func _play_card(state:Dictionary,actor_id:int,uid:int,rng:RandomNumberGenerator)->void:
	var hand:Array=state.hands[actor_id];var card:Dictionary={}
	for index in hand.size():
		if hand[index].uid==uid:card=hand.pop_at(index);break
	state.played.append({"peer_id":actor_id,"team":state.players.find(actor_id)%2,"card":card})
	if state.played.size()<state.players.size():state.current_index=(state.current_index+1)%state.players.size();return
	var best: Dictionary=state.played[0] as Dictionary
	var tied: bool=false
	for play in state.played.slice(1):
		var current_play: Dictionary = play as Dictionary
		var played_card: Dictionary = current_play.get("card", {}) as Dictionary
		var best_card: Dictionary = best.get("card", {}) as Dictionary
		var comparison: int=compare_truco_cards(played_card,best_card,String(state.get("manilha", "")))
		if comparison>0:best=current_play;tied=false
		elif comparison==0:
			if play.team!=best.team:tied=true
	var winner_team: int=DRAW if tied else int(best.get("team", DRAW));state.trick_results.append(winner_team)
	var resolution: int=hand_result(state.trick_results)
	if resolution!=UNDECIDED:_finish_hand(state,resolution,state.accepted_value,rng);return
	for completed in state.played:state.completed_cards.append(completed.card)
	if tied:state.current_index=state.trick_leader
	else:state.current_index=state.players.find(best.peer_id);state.trick_leader=state.current_index
	state.played=[]
func _finish_hand(state:Dictionary,team:int,value:int,rng:RandomNumberGenerator)->void:
	if state.hand_end_emitted:return
	state.hand_end_emitted=true
	if team in [TEAM_A,TEAM_B]:state.scores[team]+=value
	if state.scores[0]>=12 or state.scores[1]>=12:state.winner=0 if state.scores[0]>=12 else 1;state.phase=Phase.MATCH_END;state.match_end_emitted=true;return
	state.dealer_index=(state.dealer_index+1)%state.players.size();_start_hand(state,rng)
func build_public_snapshot(state:Dictionary)->Dictionary:
	var counts: Dictionary={}
	for id in state.players:counts[id]=state.hands[id].size()
	return {"game_id":"truco","phase":state.phase,"current_player":state.players[state.current_index],"turn_card":state.turn_card,"manilha":state.manilha,"played":state.played.duplicate(true),"scores":state.scores.duplicate(),"accepted_value":state.accepted_value,"target_value":state.target_value,"requesting_team":state.requesting_team,"responding_team":state.responding_team,"last_raise_team":state.last_raise_team,"card_counts":counts,"winner":state.winner,"state_version":state.state_version}
func build_private_snapshot(state:Dictionary,peer_id:int)->Dictionary:return {"peer_id":peer_id,"hand":state.hands.get(peer_id,[]).duplicate(true),"team":state.players.find(peer_id)%2,"state_version":state.state_version}
func validate_invariants(state:Dictionary)->String:
	var cards:Array[Dictionary]=[];cards.append_array(state.draw_pile);cards.append(state.turn_card)
	for id in state.players:cards.append_array(state.hands[id])
	for play in state.played:cards.append(play.card)
	cards.append_array(state.completed_cards)
	return "OK" if cards.size()==40 and DeckBuilder.validate_unique_uids(cards) else "CARD_CONSERVATION"
func is_match_finished(state:Dictionary)->bool:return state.phase==Phase.MATCH_END
