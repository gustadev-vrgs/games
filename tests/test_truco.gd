class_name TestTruco
extends RefCounted
func run(t:TestHelpers)->void:
	var rules:=TrucoRules.new();var four:=CardData.make(1,"truco","4","clubs");var three:=CardData.make(2,"truco","3","diamonds")
	t.equal(rules.compare_truco_cards(three,four,"5"),1,"ordem normal");t.equal(rules.compare_truco_cards(four,four,"5"),0,"empate")
	var clubs:=CardData.make(3,"truco","5","clubs");var diamonds:=CardData.make(4,"truco","5","diamonds");t.equal(rules.compare_truco_cards(clubs,diamonds,"5"),1,"força manilha")
	t.equal(rules.hand_result([0,0]),0,"duas vazas");t.equal(rules.hand_result([-1,1]),1,"empate primeira")
	var rng:=RandomNumberGenerator.new();rng.seed=4;var state:=rules.create_initial_state([1,2,3,4],rng);t.equal(rules.validate_invariants(state),"OK","conservação Truco 2x2")
