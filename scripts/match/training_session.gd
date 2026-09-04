class_name TrainingSession
extends RefCounted

static func configuration_valid(game_id: String, count: int, settings: Dictionary) -> bool:
	if game_id not in GameConstants.GAMES:
		return false
	if not GameConstants.player_count_valid(game_id, count, settings):
		return false
	match game_id:
		"uno":
			return int(settings.get("max_players", 0)) == count
		"caxeta":
			return int(settings.get("lives", 0)) in [7, 10]
		"truco":
			var mode: String = String(settings.get("truco_mode", ""))
			return (mode == "1v1" and count == 2) or (mode == "2v2" and count == 4)
	return false

static func build_players(game_id: String, count: int, truco_mode: String = "2v2") -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var expected: int = 2 if truco_mode == "1v1" else 4
	if game_id == "truco" and count != expected: return result
	if not GameConstants.player_count_valid(game_id, count, {"game_id":game_id, "truco_mode":truco_mode}): return result
	for index: int in count:
		result.append({"peer_id":index + 1, "display_name":"Jogador %d" % (index + 1), "seat":index, "team":index % 2 if game_id == "truco" else -1, "ready":true, "connected":true})
	return result

static func controlled_peer(public_snapshot: Dictionary, current: int = -1) -> int:
	if String(public_snapshot.get("game_id", "")) == "truco" and int(public_snapshot.get("phase", -1)) == TrucoRules.Phase.WAITING_TRUCO_RESPONSE:
		var team: int = int(public_snapshot.get("responding_team", -1))
		var candidates: Array = (public_snapshot.get("team_members", {}) as Dictionary).get(team, []) as Array
		if current in candidates: return current
		return int(candidates[0]) if not candidates.is_empty() else -1
	return int(public_snapshot.get("current_player", -1))

static func public_snapshot_has_private_hands(snapshot: Dictionary) -> bool:
	return snapshot.has("hands") or snapshot.has("hand") or snapshot.has("private_snapshots")
