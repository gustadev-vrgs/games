class_name CardData
extends RefCounted
static func make(uid: int, game_id: String, rank: String, suit: String = "", color: String = "", action: String = "", deck_copy: int = 0) -> Dictionary:
	return {"uid":uid,"game_id":game_id,"rank":rank,"suit":suit,"color":color,"action":action,"deck_copy":deck_copy,"visual_key":"_".join([game_id,color if not color.is_empty() else suit,action if not action.is_empty() else rank])}
static func clone(card: Dictionary) -> Dictionary: return card.duplicate(true)
