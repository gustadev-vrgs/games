extends SceneTree
const SCENES=["app_root","main_menu","how_to_play","host_setup","join_setup","training_setup","lobby","loading_match","results_screen","shared/card_visual","shared/player_panel","shared/message_banner","uno/uno_game","caxeta/caxeta_game","truco/truco_game","../tests/scenes/truco_spanish_deck_gallery"]
const VIEWPORTS: Array[Vector2i]=[Vector2i(1280,674),Vector2i(1280,720),Vector2i(1366,768),Vector2i(1600,900),Vector2i(1920,1080)]
func _initialize()->void:call_deferred("_run")
func _run()->void:
	var failures: int=0
	for viewport_size: Vector2i in VIEWPORTS:
		root.size=viewport_size
		for name in SCENES:
			var path: String="res://scenes/%s.tscn"%name;var packed: PackedScene=load(path) as PackedScene
			if packed==null:push_error("Cena não carregou: "+path);failures+=1;continue
			var instance: Node=packed.instantiate();root.add_child(instance);await process_frame;await process_frame
			if instance is Control and not _controls_fit(instance as Control,Vector2(viewport_size)):
				push_error("Cena excede %s: %s"%[viewport_size,path]);failures+=1
			instance.queue_free();await process_frame
	print("SCENE_SMOKE falhas=%d"%failures);quit(0 if failures==0 else 1)

func _controls_fit(control: Control, viewport_size: Vector2) -> bool:
	for child: Node in control.find_children("*","Control",true,false):
		var item: Control=child as Control
		if not item.is_visible_in_tree():
			continue
		var rect: Rect2=item.get_global_rect()
		if rect.position.x < -0.5 or rect.position.y < -0.5 or rect.end.x > viewport_size.x+0.5 or rect.end.y > viewport_size.y+0.5:
			return false
	return true
