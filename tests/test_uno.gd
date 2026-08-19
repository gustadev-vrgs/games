class_name TestUno
extends RefCounted
func run(t:TestHelpers)->void:
	var rules:=UnoRules.new();var rng:=RandomNumberGenerator.new();rng.seed=7;var state:=rules.create_initial_state([1,2],rng)
	t.equal(state.hands[1].size(),7,"sete cartas");t.equal(rules.validate_invariants(state),"OK","conservação Uno");t.check(state.discard.back().action.is_empty(),"descarte numérico")
	var top:=state.discard.back();var same:=CardData.make(999,"uno",top.rank,"", "blue" if top.color!="blue" else "red")
	t.check(rules.is_playable(same,top,state.active_color),"mesmo número");t.check(rules.is_playable(CardData.make(998,"uno","","","","wild"),top,state.active_color),"wild")
	t.equal(rules.validate_action(state,2,{"type":"DRAW_ONE"}).reason_code,"NOT_YOUR_TURN","fora do turno")
	var version:int=state.state_version;rules.apply_action(state,1,{"type":"DRAW_ONE"},rng);t.equal(state.state_version,version+1,"versão incrementa")
