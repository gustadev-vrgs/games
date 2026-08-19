class_name ActionResult
extends RefCounted
static func accepted(data: Dictionary = {}) -> Dictionary: return {"accepted":true,"reason_code":"OK","data":data}
static func rejected(reason: String) -> Dictionary: return {"accepted":false,"reason_code":reason,"data":{}}
