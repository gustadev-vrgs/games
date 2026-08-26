class_name TestTrainingMode
extends RefCounted

func run(t: TestHelpers) -> void:
	for count: int in [2, 8]: t.equal(TrainingSession.build_players("uno", count).size(), count, "treino Uno cria %d jogadores" % count)
	for count: int in [2, 5]: t.equal(TrainingSession.build_players("caxeta", count).size(), count, "treino Caxeta cria %d jogadores" % count)
	var one: Array[Dictionary] = TrainingSession.build_players("truco", 2, "1v1")
	t.equal(one.size(), 2, "treino Truco 1x1")
	var pairs: Array[Dictionary] = TrainingSession.build_players("truco", 4, "2v2")
	t.equal(pairs.map(func(p: Dictionary) -> int: return int(p.team)), [0, 1, 0, 1], "Truco 2x2 alterna equipes A/B")
	t.check(pairs.all(func(p: Dictionary) -> bool: return p.ready and p.connected), "virtuais conectados e prontos")
	var rng := RandomNumberGenerator.new(); rng.seed = 42
	var controller := BaseMatchController.new(); var rules := UnoRules.new()
	controller.initialize(rules, [1, 2], 42)
	var public: Dictionary = rules.build_public_snapshot(controller.state)
	t.check(not TrainingSession.public_snapshot_has_private_hands(public), "snapshot público não contém mãos")
	var current: int = int(public.current_player)
	t.equal(TrainingSession.controlled_peer(public), current, "controle segue current_player")
	var rejected: Dictionary = controller.process_action(3 - current, {"type":"DRAW_ONE"})
	t.check(not rejected.accepted, "jogada fora do turno é rejeitada")
	t.equal(int(rules.build_public_snapshot(controller.state).current_player), current, "rejeição mantém jogador")
	var truco_public: Dictionary = {"game_id":"truco", "phase":TrucoRules.Phase.WAITING_TRUCO_RESPONSE, "responding_team":1, "team_members":{0:[1,3], 1:[2,4]}, "current_player":1}
	t.equal(TrainingSession.controlled_peer(truco_public), 2, "pedido de Truco seleciona equipe autorizada")
	t.equal(TrainingSession.controlled_peer(truco_public, 4), 4, "dupla permite escolher respondente")
	t.equal(TrainingSession.controlled_peer(truco_public, 1), 2, "respondente de equipe errada é recusado")
