class_name BaseMatchController
extends Node
signal snapshots_ready(public_snapshot:Dictionary,private_snapshots:Dictionary)
signal match_finished(result:Dictionary)
var rules:RefCounted;var state:Dictionary={};var rng:=RandomNumberGenerator.new();var match_end_emitted:=false
func initialize(engine:RefCounted,players:Array,seed:int,config:Dictionary={})->void:
	rules=engine;rng.seed=seed
	if engine is CaxetaRules:state=rules.create_initial_state(players,rng,config.get("lives",7))
	else:state=rules.create_initial_state(players,rng)
	_publish()
func process_action(actor_id:int,action:Dictionary)->Dictionary:
	if state.is_empty() or match_end_emitted:return ActionResult.rejected("INVALID_PHASE")
	var result:Dictionary=rules.apply_action(state,actor_id,action,rng)
	if result.accepted:_publish()
	if result.accepted and rules.is_match_finished(state) and not match_end_emitted:match_end_emitted=true;match_finished.emit(rules.build_public_snapshot(state))
	return result
func _publish()->void:
	var private:={}
	for id in state.players:private[id]=rules.build_private_snapshot(state,id)
	snapshots_ready.emit(rules.build_public_snapshot(state),private)
