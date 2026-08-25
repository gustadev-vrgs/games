class_name ActionAvailability
extends RefCounted

static func is_local_turn(snapshot: Dictionary, local_peer_id: int) -> bool:
	return int(snapshot.get("current_player", -1)) == local_peer_id

static func uno_card_playable(snapshot: Dictionary, private_snapshot: Dictionary, card: Dictionary, local_peer_id: int) -> bool:
	var phase: int = int(snapshot.get("phase", -1))
	if not is_local_turn(snapshot, local_peer_id) or phase not in [1, 2] or card.is_empty():
		return false
	if phase == 2 and int(card.get("uid", -1)) != int(private_snapshot.get("drawn_uid", -2)):
		return false
	var action: String = String(card.get("action", ""))
	if action in ["wild", "wild_draw_four"]:
		return true
	var top_value: Variant = snapshot.get("top_card", {})
	var top: Dictionary = top_value as Dictionary if top_value is Dictionary else {}
	return (
		String(card.get("color", "")) == String(snapshot.get("active_color", ""))
		or (not String(card.get("rank", "")).is_empty() and card.get("rank") == top.get("rank"))
		or (not action.is_empty() and action == String(top.get("action", "")))
	)

static func caxeta_can_discard(snapshot: Dictionary, selected_uid: int, local_peer_id: int) -> bool:
	return is_local_turn(snapshot, local_peer_id) and int(snapshot.get("phase", -1)) == 2 and selected_uid != -1

static func truco_can_play(snapshot: Dictionary, selected_uid: int, local_peer_id: int) -> bool:
	return is_local_turn(snapshot, local_peer_id) and int(snapshot.get("phase", -1)) == 1 and selected_uid != -1

static func selection_still_valid(cards: Dictionary, selected_uid: int, snapshot: Dictionary, local_peer_id: int, valid_phases: Array[int]) -> bool:
	return selected_uid != -1 and cards.has(selected_uid) and is_local_turn(snapshot, local_peer_id) and int(snapshot.get("phase", -1)) in valid_phases
