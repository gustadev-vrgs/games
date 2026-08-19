class_name TestCaxeta
extends RefCounted
func run(t:TestHelpers)->void:
	var solver:=CaxetaMeldSolver.new();var wild={"rank":"7","suit":"clubs"}
	var set_cards=[CardData.make(1,"caxeta","5","clubs"),CardData.make(2,"caxeta","5","hearts"),CardData.make(3,"caxeta","5","spades")]
	t.check(solver.is_set(set_cards,wild),"trinca válida")
	var run=[CardData.make(4,"caxeta","Q","hearts"),CardData.make(5,"caxeta","K","hearts"),CardData.make(6,"caxeta","A","hearts")]
	t.check(solver.is_run(run,wild),"Q-K-A");run[0].rank="K";run[1].rank="A";run[2].rank="2";t.check(not solver.is_run(run,wild),"K-A-2 inválida")
	var rng:=RandomNumberGenerator.new();rng.seed=9;var state:=CaxetaRules.new().create_initial_state([1,2],rng,7);t.equal(CaxetaRules.new().validate_invariants(state),"OK","conservação Caxeta")
