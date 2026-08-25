extends SceneTree

func _initialize() -> void: call_deferred("_run")

func _run() -> void:
	var failures: int = 0
	for scene_path: String in ["res://scenes/uno/uno_game.tscn", "res://scenes/caxeta/caxeta_game.tscn", "res://scenes/truco/truco_game.tscn"]:
		NetworkManager.clean_session()
		var scene: Control = (load(scene_path) as PackedScene).instantiate() as Control
		root.add_child(scene); await process_frame
		var leave: Button = scene.get_node("%Leave") as Button
		if leave == null or leave.get_global_rect().end.x > 1280.0 or leave.get_global_rect().end.y > 720.0:
			push_error("Botão de saída inválido em " + scene_path); failures += 1; continue
		leave.pressed.emit(); await process_frame
		var dialog: ConfirmationDialog = null
		for child: Node in scene.get_children():
			if child is ConfirmationDialog: dialog = child as ConfirmationDialog
		if dialog == null:
			push_error("Modal de saída ausente em " + scene_path); failures += 1; continue
		dialog.canceled.emit(); await process_frame
		if NetworkManager._is_leaving_session:
			push_error("Cancelar iniciou saída em " + scene_path); failures += 1
		leave.pressed.emit(); await process_frame; dialog.confirmed.emit()
		await NetworkManager.session_leave_completed
		if NetworkManager.phase != NetworkManager.SessionPhase.OFFLINE or not SessionState.session_id.is_empty():
			push_error("Sessão não foi limpa em " + scene_path); failures += 1
		if current_scene == null or current_scene.scene_file_path != "res://scenes/main_menu.tscn":
			push_error("Não retornou ao menu em " + scene_path); failures += 1
		await process_frame
	print("LEAVE_FLOW falhas=%d" % failures)
	quit(0 if failures == 0 else 1)
