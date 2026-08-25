extends SceneTree
const SCENES=["app_root","main_menu","how_to_play","host_setup","join_setup","lobby","loading_match","results_screen","shared/card_visual","shared/player_panel","shared/message_banner","uno/uno_game","caxeta/caxeta_game","truco/truco_game","../tests/scenes/truco_spanish_deck_gallery"]
func _initialize()->void:call_deferred("_run")
func _run()->void:
	var failures: int=0
	for name in SCENES:
		var path: String="res://scenes/%s.tscn"%name;var packed: PackedScene=load(path) as PackedScene
		if packed==null:push_error("Cena não carregou: "+path);failures+=1;continue
		var instance: Node=packed.instantiate();root.add_child(instance);await process_frame;instance.queue_free();await process_frame
	print("SCENE_SMOKE falhas=%d"%failures);quit(0 if failures==0 else 1)
