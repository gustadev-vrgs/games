class_name TestCaxeta
extends RefCounted
func run(t:TestHelpers)->void:
	var solver: CaxetaMeldSolver=CaxetaMeldSolver.new();var wild: Dictionary={"rank":"7","suit":"clubs"}
	var set_cards=[CardData.make(1,"caxeta","5","clubs"),CardData.make(2,"caxeta","5","hearts"),CardData.make(3,"caxeta","5","spades")]
	t.check(solver.is_set(set_cards,wild),"trinca válida")
	var run=[CardData.make(4,"caxeta","Q","hearts"),CardData.make(5,"caxeta","K","hearts"),CardData.make(6,"caxeta","A","hearts")]
	t.check(solver.is_run(run,wild),"Q-K-A");run[0].rank="K";run[1].rank="A";run[2].rank="2";t.check(not solver.is_run(run,wild),"K-A-2 inválida")
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
