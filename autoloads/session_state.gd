extends Node
enum AppPhase { BOOT, MAIN_MENU, HOST_SETUP, JOIN_SETUP, CONNECTING, LOBBY, LOADING_MATCH, IN_MATCH, RESULTS, DISCONNECTING }
var app_phase: AppPhase = AppPhase.BOOT
var session_id: String = ""; var match_id: int = 0; var game_id: String = ""; var local_peer_id: int = 1; var is_host: bool = false
var nickname: String = ""; var approved_config: Dictionary = {}; var players: Array[Dictionary] = []; var public_state: Dictionary = {}; var private_state: Dictionary = {}; var state_version: int = -1
func reset_match() -> void: match_id = 0; public_state.clear(); private_state.clear(); state_version = -1
func reset_all() -> void: reset_match(); session_id = ""; game_id = ""; is_host = false; approved_config.clear(); players.clear(); app_phase = AppPhase.MAIN_MENU
func accept_public_snapshot(snapshot: Dictionary) -> bool:
	if snapshot.get("session_id","") != session_id or snapshot.get("match_id",-1) != match_id: return false
	var version: int = snapshot.get("state_version",-1)
	if version < state_version: return false
	state_version = version; public_state = snapshot.duplicate(true); return true
func accept_private_snapshot(snapshot: Dictionary) -> bool:
	if snapshot.get("peer_id",-1) != local_peer_id or snapshot.get("state_version",-1) < state_version: return false
	private_state = snapshot.duplicate(true); return true
