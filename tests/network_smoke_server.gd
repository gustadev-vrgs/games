extends SceneTree
var manager:Node
func _initialize()->void:call_deferred("_run")
func _run()->void:
	manager=load("res://autoloads/network_manager.gd").new();root.add_child(manager)
	var result:String=manager.create_server("Host","uno",{},17001)
	if result!="OK":push_error(result);quit(1);return
	print("NETWORK_SMOKE_SERVER_READY");await create_timer(12.0).timeout;manager.clean_session();quit(0)
