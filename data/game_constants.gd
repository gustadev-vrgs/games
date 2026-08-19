class_name GameConstants
extends RefCounted
const PROTOCOL_VERSION: int = 1
const DEFAULT_PORT: int = 7000
const MIN_PORT: int = 1024
const MAX_PORT: int = 65535
const MAX_TOTAL_PLAYERS: int = 6
const MAX_TRANSPORT_CLIENTS: int = 8
const CONNECTION_TIMEOUT_SECONDS: float = 8.0
const SCENE_READY_TIMEOUT_SECONDS: float = 15.0
const MAX_NICKNAME_LENGTH: int = 20
const MAX_ACTIONS_REMEMBERED_PER_PEER: int = 64
const GAMES: PackedStringArray = ["uno", "caxeta", "truco"]
static func valid_port(port: int) -> bool: return port >= MIN_PORT and port <= MAX_PORT
static func player_count_valid(game_id: String, count: int) -> bool:
	return (game_id == "uno" and count >= 2 and count <= 6) or (game_id == "caxeta" and count >= 2 and count <= 5) or (game_id == "truco" and count in [2, 4])
static func sanitize_nickname(value: String) -> String:
	var clean := ""; var space := false
	for character in value.strip_edges():
		if character.unicode_at(0) < 32: continue
		if character == " ":
			if space: continue
			space = true
		else: space = false
		clean += character
	return clean.left(MAX_NICKNAME_LENGTH)
