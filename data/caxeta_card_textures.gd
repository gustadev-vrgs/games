class_name CaxetaCardTextures
extends RefCounted

const ROOT: String = "res://assets/cards/caxeta"
const RANK_NAMES: Dictionary = {
	"A": "ace",
	"J": "jack",
	"Q": "queen",
	"K": "king",
}

static var _cache: Dictionary = {}

static func face_path(rank: String, suit: String) -> String:
	var file_rank: String = String(RANK_NAMES.get(rank, rank))
	return "%s/%s_of_%s.png" % [ROOT, file_rank, suit]

static func load_face(rank: String, suit: String) -> Texture2D:
	var path: String = face_path(rank, suit)
	if _cache.has(path):
		return _cache[path] as Texture2D
	if not ResourceLoader.exists(path):
		if OS.is_debug_build():
			push_warning("Textura da Caxeta ausente — rank: %s, suit: %s, path esperado: %s" % [rank, suit, path])
		return null
	var resource: Resource = load(path)
	if not resource is Texture2D:
		if OS.is_debug_build():
			push_warning("Asset da Caxeta inválido — rank: %s, suit: %s, path esperado: %s" % [rank, suit, path])
		return null
	var texture: Texture2D = resource as Texture2D
	_cache[path] = texture
	return texture

static func validate_catalog() -> PackedStringArray:
	var missing: PackedStringArray = PackedStringArray()
	for suit: String in DeckBuilder.SUITS:
		for rank: String in DeckBuilder.CAXETA_RANKS:
			var path: String = face_path(rank, suit)
			if not ResourceLoader.exists(path):
				missing.append(path)
	return missing
