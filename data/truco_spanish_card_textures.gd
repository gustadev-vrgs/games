class_name TrucoSpanishCardTextures
extends RefCounted

const ROOT: String = "res://assets/cards/truco_custom"
const LEGACY_ROOT: String = "res://assets/cards/truco_spanish"
const BACK_PATH: String = LEGACY_ROOT + "/back/truco_back.svg"

static var _face_cache: Dictionary = {}
static var _back_cache: Texture2D

static func face_path(rank: String, suit: String) -> String:
	return "%s/%s_%s.png" % [ROOT, rank, suit]

static func legacy_face_path(rank: String, suit: String) -> String:
	return "%s/faces/%s_%s.svg" % [LEGACY_ROOT, suit, rank]

static func load_face(rank: String, suit: String) -> Texture2D:
	var key: String = "%s_%s" % [rank, suit]
	if _face_cache.has(key):
		return _face_cache[key] as Texture2D
	var path: String = face_path(rank, suit)
	var texture: Texture2D = _load_texture(path, false)
	if texture == null:
		push_warning("Arte customizada do Truco ausente (rank=%s, suit=%s, path=%s); usando baralho espanhol." % [rank, suit, path])
		texture = _load_texture(legacy_face_path(rank, suit))
	if texture != null:
		_face_cache[key] = texture
	return texture

static func load_back() -> Texture2D:
	if _back_cache == null:
		_back_cache = _load_texture(BACK_PATH)
	return _back_cache

static func _load_texture(path: String, report_error: bool = true) -> Texture2D:
	if not ResourceLoader.exists(path):
		if report_error:
			push_error("Textura obrigatória do Truco ausente: %s" % path)
		return null
	var resource: Resource = load(path)
	if not resource is Texture2D:
		push_error("Asset do Truco não é Texture2D: %s" % path)
		return null
	return resource as Texture2D

static func validate_catalog() -> PackedStringArray:
	var errors: PackedStringArray = PackedStringArray()
	for suit: String in DeckBuilder.TRUCO_SUITS:
		for rank: String in DeckBuilder.TRUCO_RANKS:
			var path: String = face_path(rank, suit)
			if not ResourceLoader.exists(path): errors.append(path)
	if not ResourceLoader.exists(BACK_PATH): errors.append(BACK_PATH)
	return errors
