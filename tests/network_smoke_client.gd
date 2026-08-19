extends SceneTree
var manager:Node
func _initialize()->void:call_deferred("_run")
func _run()->void:
	manager=load("res://autoloads/network_manager.gd").new();root.add_child(manager)
	var result:String=manager.create_client("Cliente","127.0.0.1",17001)
	if result!="OK":push_error(result);quit(1);return
	await create_timer(10.0).timeout
	if manager.players.is_empty():push_error("Lobby não sincronizou");quit(1)
	else:manager.clean_session();quit(0)
