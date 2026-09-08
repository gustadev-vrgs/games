class_name TestCaxeta
extends RefCounted
func run(t:TestHelpers)->void:
	var solver: CaxetaMeldSolver=CaxetaMeldSolver.new();var wild: Dictionary={"rank":"7","suit":"clubs"}
	var set_cards=[CardData.make(1,"caxeta","5","clubs"),CardData.make(2,"caxeta","5","hearts"),CardData.make(3,"caxeta","5","spades")]
	t.check(solver.is_set(set_cards,wild),"trinca válida")
	var run=[CardData.make(4,"caxeta","Q","hearts"),CardData.make(5,"caxeta","K","hearts"),CardData.make(6,"caxeta","A","hearts")]
	t.check(solver.is_run(run,wild),"Q-K-A");run[0].rank="K";run[1].rank="A";run[2].rank="2";t.check(not solver.is_run(run,wild),"K-A-2 inválida")
	var joker: Dictionary = CardData.make(7,"caxeta","JOKER","black")
	t.check(solver.is_run([CardData.make(8,"caxeta","3","spades"), joker, CardData.make(9,"caxeta","5","spades")]), "coringa próprio completa sequência")
	t.check(not solver.is_run([CardData.make(10,"caxeta","3","spades"), CardData.make(11,"caxeta","7","clubs"), CardData.make(12,"caxeta","5","spades")], {"rank":"7","suit":"clubs"}), "vira não transforma carta comum em coringa")
	var quartet: Array = [CardData.make(13,"caxeta","4","clubs"), CardData.make(14,"caxeta","4","diamonds"), CardData.make(15,"caxeta","4","hearts"), CardData.make(16,"caxeta","4","spades")]
	t.check(solver.is_set(quartet), "quarteto de mesmo valor é um jogo válido")
	var rng: RandomNumberGenerator=RandomNumberGenerator.new();rng.seed=9
	var rules: CaxetaRules=CaxetaRules.new();var state: Dictionary=rules.create_initial_state([1,2],rng,7)
	t.equal(rules.validate_invariants(state),"OK","conservação Caxeta")
	# Com monte e descarte esgotados, a compra encerra e reinicia a rodada. Essa
	# ação ainda precisa avançar exatamente uma versão para o controlador aceitá-la.
	state.hands[1].append_array(state.draw_pile);state.draw_pile=[];state.discard=[]
	var previous_version: int=state.state_version
	var result: Dictionary=rules.apply_action(state,1,{"type":"DRAW_PILE"},rng)
	t.check(result.accepted,"Caxeta aceita fim de rodada por esgotamento do monte")
	t.equal(state.state_version,previous_version+1,"fim por esgotamento avança uma versão")
	t.equal(rules.validate_invariants(state),"OK","nova rodada após esgotamento conserva cartas")
	var knock_state: Dictionary = rules.create_initial_state([1,2],rng,1)
	knock_state.hands[1] = [
		CardData.make(201,"caxeta","3","clubs"), CardData.make(202,"caxeta","4","clubs"), CardData.make(203,"caxeta","5","clubs"),
		CardData.make(204,"caxeta","8","diamonds"), CardData.make(205,"caxeta","8","spades"), CardData.make(206,"caxeta","8","hearts"),
		CardData.make(207,"caxeta","Q","hearts"), CardData.make(208,"caxeta","K","hearts"), CardData.make(209,"caxeta","A","hearts")]
	t.check(rules.validate_action(knock_state,1,{"type":"KNOCK"}).accepted,"batida válida com nove cartas antes da compra")
	knock_state.hands[1][8] = CardData.make(210,"caxeta","2","diamonds")
	t.check(not rules.validate_action(knock_state,1,{"type":"KNOCK"}).accepted,"nove cartas inválidas não vencem")
	var ten_card_state: Dictionary = rules.create_initial_state([1,2],rng,7)
	ten_card_state.phase = CaxetaRules.Phase.MAY_KNOCK_TEN_OR_DISCARD
	ten_card_state.hands[1] = [
		CardData.make(301,"caxeta","7","clubs"), CardData.make(302,"caxeta","Q","diamonds"), CardData.make(303,"caxeta","4","hearts"),
		CardData.make(304,"caxeta","7","diamonds"), CardData.make(305,"caxeta","Q","clubs"), CardData.make(306,"caxeta","4","clubs"),
		CardData.make(307,"caxeta","7","hearts"), CardData.make(308,"caxeta","Q","hearts"), CardData.make(309,"caxeta","4","spades"), CardData.make(310,"caxeta","4","diamonds")]
	t.check(rules.validate_action(ten_card_state,1,{"type":"KNOCK"}).accepted,"duas trincas e um quarteto misturados formam batida de dez")
	# Use a controller-created state so conservation and the full authoritative
	# publish/finish path are exercised with real deck UIDs.
	var controller: CaxetaMatchController = CaxetaMatchController.new()
	controller.start([1,2],33,{"lives":7})
	var authoritative: Dictionary = controller.state
	var reserved: Array[Dictionary] = []
	for rank: String in ["7", "Q"]:
		for suit: String in ["clubs", "diamonds", "hearts"]:
			reserved.append(_take_card(authoritative, rank, suit))
	for suit: String in DeckBuilder.SUITS:
		reserved.append(_take_card(authoritative, "4", suit))
	_authoritative_replace_hand(authoritative, 1, reserved)
	authoritative.phase = CaxetaRules.Phase.MAY_KNOCK_TEN_OR_DISCARD
	var finish_events: Array[Dictionary] = []
	controller.match_finished.connect(func(snapshot: Dictionary) -> void: finish_events.append(snapshot))
	t.check(controller.process_action(1,{"type":"KNOCK"}).accepted,"autoridade aceita e processa batida completa")
	t.equal(controller.state.winner,1,"autoridade define quem bateu como vencedor")
	t.equal(controller.state.phase,CaxetaRules.Phase.MATCH_END,"batida encerra a partida")
	t.equal(finish_events.size(),1,"resultado final é emitido uma única vez")
	t.check(not controller.process_action(2,{"type":"DRAW_PILE"}).accepted,"ações são bloqueadas após a batida")

func _take_card(state: Dictionary, rank: String, suit: String) -> Dictionary:
	for zone_name: String in ["draw_pile", "discard"]:
		var zone: Array = state[zone_name]
		for index: int in zone.size():
			if zone[index].rank == rank and zone[index].suit == suit:
				return zone.pop_at(index)
	for peer_id: Variant in state.players:
		var player_hand: Array = state.hands[peer_id]
		for index: int in player_hand.size():
			if player_hand[index].rank == rank and player_hand[index].suit == suit:
				return player_hand.pop_at(index)
	return {}

func _authoritative_replace_hand(state: Dictionary, peer_id: int, replacement: Array[Dictionary]) -> void:
	state.draw_pile.append_array(state.hands[peer_id])
	state.hands[peer_id] = replacement
