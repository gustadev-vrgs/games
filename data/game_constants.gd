class_name GameConstants
extends RefCounted

const PROTOCOL_VERSION: int = 2
const DEFAULT_PORT: int = 7000
const MIN_PORT: int = 1024
const MAX_PORT: int = 65535
const MAX_TOTAL_PLAYERS: int = 8
const MAX_UNO_PLAYERS: int = 8
const MAX_CAXETA_PLAYERS: int = 5
const MAX_TRUCO_PLAYERS: int = 4
const MAX_TRANSPORT_CLIENTS: int = 7
const CONNECTION_TIMEOUT_SECONDS: float = 8.0
const SCENE_READY_TIMEOUT_SECONDS: float = 15.0
const MAX_NICKNAME_LENGTH: int = 20
const MAX_ACTIONS_REMEMBERED_PER_PEER: int = 64
const GAMES: PackedStringArray = ["uno", "caxeta", "truco"]

static func valid_port(port: int) -> bool:
	return port >= MIN_PORT and port <= MAX_PORT

static func minimum_players_for(config: Dictionary) -> int:
	var game_id: String = String(config.get("game_id", ""))
	if game_id == "truco":
		return 2 if String(config.get("truco_mode", "2v2")) == "1v1" else 4
	return 2

static func maximum_players_for(config: Dictionary) -> int:
	var game_id: String = String(config.get("game_id", ""))
	match game_id:
		"uno":
			return clampi(int(config.get("max_players", MAX_UNO_PLAYERS)), 2, MAX_UNO_PLAYERS)
		"caxeta":
			return MAX_CAXETA_PLAYERS
		"truco":
			return 2 if String(config.get("truco_mode", "2v2")) == "1v1" else MAX_TRUCO_PLAYERS
	return 0

static func player_count_valid(game_id: String, count: int, config: Dictionary = {}) -> bool:
	var settings: Dictionary = config.duplicate(true)
	settings["game_id"] = game_id
	return count >= minimum_players_for(settings) and count <= maximum_players_for(settings)

static func lobby_configuration_valid(game_id: String, config: Dictionary, players: Array[Dictionary]) -> String:
	var settings: Dictionary = config.duplicate(true)
	settings["game_id"] = game_id
	if game_id == "truco" and String(settings.get("truco_mode", "2v2")) not in ["1v1", "2v2"]:
		return "INVALID_TRUCO_MODE"
	var required: int = minimum_players_for(settings)
	if game_id == "truco" and players.size() != required:
		return "WRONG_PLAYER_COUNT"
	if players.size() < required:
		return "WRONG_PLAYER_COUNT"
	if players.size() > maximum_players_for(settings):
		return "ROOM_FULL"
	if game_id == "truco":
		var capacity: int = 1 if String(settings.get("truco_mode", "2v2")) == "1v1" else 2
		var counts: Array[int] = [0, 0]
		for player: Dictionary in players:
			var team: int = int(player.get("team", -1))
			if team not in [0, 1]:
				return "TEAM_REQUIRED"
			counts[team] += 1
		if counts[0] > capacity or counts[1] > capacity:
			return "TEAM_FULL"
		if counts[0] != capacity or counts[1] != capacity:
			return "TEAMS_UNBALANCED"
	for player: Dictionary in players:
		if not bool(player.get("ready", false)):
			return "PLAYER_NOT_READY"
	return "OK"

static func sanitize_nickname(value: String) -> String:
	var clean: String = ""
	var space: bool = false
	for character: String in value.strip_edges():
		if character.unicode_at(0) < 32:
			continue
		if character == " ":
			if space:
				continue
			space = true
		else:
			space = false
		clean += character
	return clean.left(MAX_NICKNAME_LENGTH)
