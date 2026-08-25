class_name TrucoSpanishCardTextures
extends RefCounted

const ROOT: String = "res://assets/cards/truco_spanish"
const BACK_PATH: String = ROOT + "/back/truco_back.svg"

static func face_path(rank: String, suit: String) -> String:
	return "%s/faces/%s_%s.svg" % [ROOT, suit, rank]

static func load_face(rank: String, suit: String) -> Texture2D:
	return _load_texture(face_path(rank, suit))

static func load_back() -> Texture2D:
	return _load_texture(BACK_PATH)

static func _load_texture(path: String) -> Texture2D:
	if not ResourceLoader.exists(path):
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
