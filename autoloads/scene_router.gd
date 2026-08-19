extends Node
signal transition_finished(screen_id: String)
const SCREENS := {"menu":"res://scenes/main_menu.tscn","host":"res://scenes/host_setup.tscn","join":"res://scenes/join_setup.tscn","lobby":"res://scenes/lobby.tscn","loading":"res://scenes/loading_match.tscn","results":"res://scenes/results_screen.tscn","uno":"res://scenes/uno/uno_game.tscn","caxeta":"res://scenes/caxeta/caxeta_game.tscn","truco":"res://scenes/truco/truco_game.tscn"}
var transition_in_progress := false
func request_transition(screen_id: String, payload: Dictionary = {}) -> bool:
	if transition_in_progress or not SCREENS.has(screen_id): return false
	var path: String = SCREENS[screen_id]
	if not ResourceLoader.exists(path): push_error("Cena inexistente: " + path); return false
	transition_in_progress = true
	for key in payload:
		if key in ["game_id","match_id"]:
			SessionState.set(key,payload[key])
	var error := get_tree().change_scene_to_file(path)
	if error != OK: transition_in_progress = false; push_error("Falha de transição: %s" % error); return false
	await get_tree().process_frame
	transition_in_progress = false; transition_finished.emit(screen_id); return true
