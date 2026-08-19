extends SceneTree
const SCENES=["app_root","main_menu","host_setup","join_setup","lobby","loading_match","results_screen","shared/card_visual","shared/player_panel","shared/message_banner","uno/uno_game","caxeta/caxeta_game","truco/truco_game"]
func _initialize()->void:call_deferred("_run")
func _run()->void:
	var failures:=0
	for name in SCENES:
		var path:="res://scenes/%s.tscn"%name;var packed:=load(path) as PackedScene
		if packed==null:push_error("Cena não carregou: "+path);failures+=1;continue
		var instance:=packed.instantiate();root.add_child(instance);await process_frame;instance.queue_free();await process_frame
	print("SCENE_SMOKE falhas=%d"%failures);quit(0 if failures==0 else 1)
