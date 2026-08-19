class_name NetworkProtocol
extends RefCounted
const REQUIRED: PackedStringArray = ["protocol_version","session_id","match_id","client_action_id","expected_state_version","action_type","payload"]
static func envelope(session_id: String, match_id: int, action_id: int, version: int, action_type: String, payload: Dictionary = {}) -> Dictionary:
	return {"protocol_version":GameConstants.PROTOCOL_VERSION,"session_id":session_id,"match_id":match_id,"client_action_id":action_id,"expected_state_version":version,"action_type":action_type,"payload":payload}
static func validate(value: Variant) -> String:
	if not value is Dictionary: return "INVALID_MESSAGE"
	var message: Dictionary = value
	for key in REQUIRED:
		if not message.has(key): return "INVALID_MESSAGE"
	if typeof(message.protocol_version) != TYPE_INT or typeof(message.session_id) != TYPE_STRING or typeof(message.match_id) != TYPE_INT or typeof(message.client_action_id) != TYPE_INT or typeof(message.expected_state_version) != TYPE_INT or typeof(message.action_type) != TYPE_STRING or typeof(message.payload) != TYPE_DICTIONARY: return "INVALID_MESSAGE"
	if message.protocol_version != GameConstants.PROTOCOL_VERSION: return "PROTOCOL_MISMATCH"
	if message.action_type.length() > 32 or message.payload.size() > 16: return "INVALID_MESSAGE"
	return "OK"
