class_name TestUno
extends RefCounted
func run(t:TestHelpers)->void:
	var rules: UnoRules = UnoRules.new();var rng: RandomNumberGenerator = RandomNumberGenerator.new();rng.seed=7;var state: Dictionary=rules.create_initial_state([1,2],rng)
	t.equal(state.hands[1].size(),7,"sete cartas");t.equal(rules.validate_invariants(state),"OK","conservação Uno");t.check(state.discard.back().action.is_empty(),"descarte numérico")
	var top: Dictionary = state.discard.back() as Dictionary
	var same: Dictionary = CardData.make(999,"uno",String(top.get("rank", "")),"", "blue" if String(top.get("color", ""))!="blue" else "red")
	t.check(rules.is_playable(same,top,state.active_color),"mesmo número");t.check(rules.is_playable(CardData.make(998,"uno","","","","wild"),top,state.active_color),"wild")
	t.equal(rules.validate_action(state,2,{"type":"DRAW_ONE"}).reason_code,"NOT_YOUR_TURN","fora do turno")
	var version:int=state.state_version;rules.apply_action(state,1,{"type":"DRAW_ONE"},rng);t.equal(state.state_version,version+1,"versão incrementa")
	var recycle_state: Dictionary = rules.create_initial_state([1,2], rng)
	recycle_state.discard.append_array(recycle_state.draw_pile)
	recycle_state.draw_pile = []
	var recycle_top: Dictionary = recycle_state.discard.back()
	var total_before: int = recycle_state.discard.size()
	rules.apply_action(recycle_state, 1, {"type":"DRAW_ONE"}, rng)
	t.equal(recycle_state.discard.size(), 1, "reciclagem preserva somente o topo")
	t.equal(recycle_state.discard[0].uid, recycle_top.uid, "carta superior não é reciclada")
	t.equal(rules.validate_invariants(recycle_state), "OK", "reciclagem conserva UIDs")
	t.check(total_before > 1 and not recycle_state.draw_pile.is_empty(), "monte reciclável não entra em deadlock")
	var wild_state: Dictionary = rules.create_initial_state([1,2], rng)
	var wild_card: Dictionary = {}
	for candidate: Dictionary in wild_state.draw_pile:
		if candidate.action == "wild":
			wild_card = candidate
			break
	wild_state.draw_pile.erase(wild_card)
	wild_state.hands[1].append(wild_card)
	var missing_color: Dictionary = rules.validate_action(wild_state, 1, {"type":"PLAY_CARD","card_uid":wild_card.uid})
	t.equal(missing_color.reason_code, "INVALID_COLOR", "curinga sem cor é rejeitado")
	rules.apply_action(wild_state, 1, {"type":"PLAY_CARD","card_uid":wild_card.uid,"chosen_color":"blue"}, rng)
	t.equal(wild_state.active_color, "blue", "curinga atualiza cor ativa")
	var public: Dictionary = rules.build_public_snapshot(wild_state)
	t.equal(public.last_play.chosen_color, "blue", "snapshot público sincroniza cor escolhida")
	t.check(not public.last_play.has("hand"), "última jogada não contém mão privada")
