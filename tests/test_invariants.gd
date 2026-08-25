class_name TestInvariants
extends RefCounted
func run(t:TestHelpers)->void:
	var message: Dictionary=NetworkProtocol.envelope("s",1,1,0,"PLAY_CARD",{"card_uid":2});t.equal(NetworkProtocol.validate(message),"OK","envelope válido")
	message.protocol_version=99;t.equal(NetworkProtocol.validate(message),"PROTOCOL_MISMATCH","protocolo incompatível")
	t.equal(GameConstants.sanitize_nickname("  Ana   Maria\n"),"Ana Maria","apelido sanitizado")
