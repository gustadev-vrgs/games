class_name BaseMatchController
extends Node

signal snapshots_ready(public_snapshot: Dictionary, private_snapshots: Dictionary)
signal match_finished(result: Dictionary)

var rules: RefCounted
var state: Dictionary = {}
var rng: RandomNumberGenerator = RandomNumberGenerator.new()
var match_end_emitted: bool = false

func initialize(engine: RefCounted, players: Array, random_seed: int, config: Dictionary = {}) -> void:
	rules = engine
	rng.seed = random_seed
	if engine is CaxetaRules:
		state = rules.create_initial_state(players, rng, int(config.get("lives", 7)))
	elif engine is TrucoRules:
		state = rules.create_initial_state(players, rng, config)
	else:
		state = rules.create_initial_state(players, rng)
	_publish()

func process_action(actor_id: int, action: Dictionary) -> Dictionary:
	if state.is_empty() or match_end_emitted:
		return ActionResult.rejected("INVALID_PHASE")
	# Engines mutate their argument. A candidate copy guarantees that every rejected
	# action, including an invariant failure, leaves authoritative state untouched.
	var candidate: Dictionary = state.duplicate(true)
	var rng_state_before: int = rng.state
	var result: Dictionary = rules.apply_action(candidate, actor_id, action, rng)
	if not bool(result.get("accepted", false)):
		rng.state = rng_state_before
		return result
	var invariant: String = String(rules.validate_invariants(candidate))
	if invariant != "OK":
		rng.state = rng_state_before
		return ActionResult.rejected("INTERNAL_STATE_ERROR")
	var previous_version: int = int(state.get("state_version", 0))
	if int(candidate.get("state_version", -1)) != previous_version + 1:
		rng.state = rng_state_before
		return ActionResult.rejected("INTERNAL_STATE_ERROR")
	state = candidate
	_publish()
	if rules.is_match_finished(state) and not match_end_emitted:
		match_end_emitted = true
		match_finished.emit(rules.build_public_snapshot(state))
	return result

func _publish() -> void:
	var private_snapshots: Dictionary = {}
	var players_value: Variant = state.get("players", [])
	if players_value is Array:
		for peer_value: Variant in players_value as Array:
			var peer_id: int = int(peer_value)
			private_snapshots[peer_id] = rules.build_private_snapshot(state, peer_id)
	snapshots_ready.emit(rules.build_public_snapshot(state), private_snapshots)

func advance_authoritative_transition() -> bool:
	if not rules.has_method("advance_reveal"):
		return false
	if not rules.advance_reveal(state, rng):
		return false
	_publish()
	if rules.is_match_finished(state) and not match_end_emitted:
		match_end_emitted = true
		match_finished.emit(rules.build_public_snapshot(state))
	return true
