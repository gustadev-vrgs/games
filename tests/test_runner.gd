extends SceneTree
func _initialize()->void:call_deferred("_run")
func _run()->void:
	var helper: TestHelpers=TestHelpers.new()
	for suite in [TestDecks.new(),TestUno.new(),TestCaxeta.new(),TestTruco.new(),TestInvariants.new()]:suite.run(helper)
	print("TESTES: %d sucessos, %d falhas"%[helper.passed,helper.failed]);quit(0 if helper.failed==0 else 1)
