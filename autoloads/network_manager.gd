extends Node
signal lobby_updated(players:Array)
signal connection_status(message:String)
signal action_answered(answer:Dictionary)
signal public_snapshot_received(snapshot:Dictionary)
signal private_snapshot_received(snapshot:Dictionary)
signal session_interrupted(reason:String)
signal session_leave_started()
signal session_leave_completed()
enum SessionPhase { OFFLINE, LOBBY, LOCKED, LOADING, MATCH_ACTIVE, MATCH_PAUSED, MATCH_FINISHED }
var phase:SessionPhase=SessionPhase.OFFLINE;var players:Dictionary={};var config:Dictionary={};var session_id:String="";var match_id:int=0;var state_version:int=0
var _peer:ENetMultiplayerPeer;var _connection_timer:Timer;var _scene_timer:Timer;var _ready_peers:Dictionary={};var _action_cache:Dictionary={};var _controller:BaseMatchController;var _next_action_id:int=1
var _reveal_timer: Timer
var _reveal_token: int = 0
var _processed_departures: Dictionary = {}
var _shutting_down: bool = false
var _is_leaving_session: bool = false
var _intentional_disconnect: bool = false
var is_training_mode: bool = false
var _training_private_snapshots: Dictionary = {}
var _training_controlled_peer: int = -1
func _ready()->void:
	multiplayer.peer_connected.connect(_on_peer_connected);multiplayer.peer_disconnected.connect(_on_peer_disconnected);multiplayer.connected_to_server.connect(_on_connected);multiplayer.connection_failed.connect(_on_connection_failed);multiplayer.server_disconnected.connect(_on_server_disconnected)
func create_server(nickname:String,game_id:String,settings:Dictionary,port:int)->String:
	clean_session()
	var player_name:String=GameConstants.sanitize_nickname(nickname)
	if player_name.is_empty() or game_id not in GameConstants.GAMES or not GameConstants.valid_port(port):return "INVALID_CONFIG"
	_peer=ENetMultiplayerPeer.new();var error:Error=_peer.create_server(port,GameConstants.MAX_TRANSPORT_CLIENTS)
	if error!=OK:_peer=null;return "SERVER_CREATE_FAILED"
	multiplayer.multiplayer_peer=_peer;session_id="%s-%s"%[Time.get_unix_time_from_system(),randi()];phase=SessionPhase.LOBBY;config=settings.duplicate(true);config.game_id=game_id;config.port=port
	players[1]={"peer_id":1,"display_name":player_name,"seat":0,"team":-1,"ready":false,"connected":true}
	SessionState.session_id=session_id
	SessionState.game_id=game_id
	SessionState.local_peer_id=1
	SessionState.is_host=true
	SessionState.approved_config=config.duplicate(true)
	_sync_lobby()
	return "OK"
func create_client(nickname:String,address:String,port:int)->String:
	clean_session();var player_name:String=GameConstants.sanitize_nickname(nickname)
	if player_name.is_empty() or address.strip_edges().is_empty() or address.length()>255 or not GameConstants.valid_port(port):return "INVALID_CONFIG"
	SessionState.nickname=player_name;_peer=ENetMultiplayerPeer.new();var error:Error=_peer.create_client(address.strip_edges(),port)
	if error!=OK:_peer=null;return "CLIENT_CREATE_FAILED"
	multiplayer.multiplayer_peer=_peer;phase=SessionPhase.OFFLINE;_connection_timer=_timer(GameConstants.CONNECTION_TIMEOUT_SECONDS,_on_connection_timeout);return "OK"
func _timer(seconds:float,callback:Callable)->Timer:
	var timer:Timer=Timer.new();timer.one_shot=true;timer.wait_time=seconds;add_child(timer);timer.timeout.connect(callback);timer.start();return timer
func _on_connected()->void:
	_cancel_timer(_connection_timer);connection_status.emit("Conectado; registrando jogador...");register_player.rpc_id(1,GameConstants.PROTOCOL_VERSION,SessionState.nickname)
func _on_connection_failed()->void:clean_session();connection_status.emit("Não foi possível conectar.")
func _on_connection_timeout()->void:clean_session();connection_status.emit("Tempo de conexão esgotado. Verifique IP, porta, rede e firewall.")
func _on_server_disconnected()->void:
	if _intentional_disconnect or _is_leaving_session: return
	clean_session();session_interrupted.emit("O host encerrou a sala.");_transition_to_menu()
func _on_peer_connected(_id:int)->void:pass
func _on_peer_disconnected(id:int)->void:
	if not multiplayer.is_server():return
	_process_departure(id, "")

@rpc("any_peer", "call_remote", "reliable") func notify_voluntary_leave() -> void:
	if not multiplayer.is_server():
		return
	_process_departure(multiplayer.get_remote_sender_id(), "voluntary")

func _process_departure(id: int, _cause: String) -> void:
	if _processed_departures.has(id) or not players.has(id):
		return
	_processed_departures[id] = true
	var departed_name: String = String(players[id].get("display_name", "Jogador"))
	players.erase(id)
	_reseat()
	if phase in [SessionPhase.LOADING, SessionPhase.MATCH_ACTIVE, SessionPhase.MATCH_PAUSED]:
		_cancel_match_resources()
		for remaining: Dictionary in players.values():
			remaining["ready"] = false
		phase = SessionPhase.LOBBY
		var reason: String = "%s saiu. A partida foi encerrada." % departed_name
		notify_return_to_lobby.rpc(reason)
		SessionState.reset_match()
		SceneRouter.request_transition("lobby")
		session_interrupted.emit(reason)
	_sync_lobby()
@rpc("any_peer","call_remote","reliable") func register_player(protocol:int,nickname:String)->void:
	var sender:int=multiplayer.get_remote_sender_id()
	if not multiplayer.is_server():return
	if protocol!=GameConstants.PROTOCOL_VERSION:_reject_and_disconnect(sender,"PROTOCOL_MISMATCH");return
	if phase!=SessionPhase.LOBBY:_reject_and_disconnect(sender,"MATCH_ALREADY_STARTED");return
	if players.size() >= GameConstants.maximum_players_for(config):
		_reject_and_disconnect(sender, "ROOM_FULL")
		return
	var clean:String=GameConstants.sanitize_nickname(nickname)
	if clean.is_empty():_reject_and_disconnect(sender,"INVALID_MESSAGE");return
	clean = _unique_name(clean)
	players[sender] = {"peer_id":sender,"display_name":clean,"seat":players.size(),"team":-1,"ready":false,"connected":true}
	receive_session.rpc_id(sender, session_id, config, players.values())
	_sync_lobby()
func _unique_name(base:String)->String:
	var names:Array=players.values().map(func(player:Dictionary)->String:return String(player.get("display_name", "")))
	if base not in names:return base
	var suffix:int=2
	while "%s (%d)"%[base,suffix] in names:suffix+=1
	return "%s (%d)"%[base,suffix]
func _reject_and_disconnect(id:int,reason:String)->void:receive_rejection.rpc_id(id,reason);await get_tree().create_timer(0.2).timeout;_peer.disconnect_peer(id)
@rpc("authority","call_remote","reliable") func receive_rejection(reason:String)->void:connection_status.emit(reason);clean_session()
@rpc("authority","call_remote","reliable") func receive_session(id:String,settings:Dictionary,list:Array)->void:
	var normalized_players:Array[Dictionary]=_normalize_player_list(list)
	if normalized_players.is_empty():
		connection_status.emit("Lista de jogadores inválida.");clean_session();return
	session_id=id;config=settings.duplicate(true);players.clear()
	for player:Dictionary in normalized_players:players[int(player.get("peer_id",-1))]=player
	phase=SessionPhase.LOBBY;SessionState.session_id=id;SessionState.game_id=config.game_id;SessionState.approved_config=config.duplicate(true);SessionState.is_host=false;SessionState.players.assign(normalized_players);SessionState.local_peer_id=multiplayer.get_unique_id();SceneRouter.request_transition("lobby")
func _sync_lobby()->void:
	var normalized_players:Array[Dictionary]=_normalize_player_list(players.values())
	if normalized_players.is_empty():
		connection_status.emit("Lista de jogadores inválida.");clean_session();return
	SessionState.players.assign(normalized_players);lobby_state.rpc(session_id,config,normalized_players);lobby_updated.emit(normalized_players)
@rpc("authority","call_remote","reliable") func lobby_state(id:String,settings:Dictionary,list:Array)->void:
	if not session_id.is_empty() and id!=session_id:return
	var normalized_players:Array[Dictionary]=_normalize_player_list(list)
	if normalized_players.is_empty():
		connection_status.emit("Lista de jogadores inválida.");clean_session();return
	session_id=id;config=settings.duplicate(true);players.clear()
	for player:Dictionary in normalized_players:players[int(player.get("peer_id",-1))]=player
	SessionState.players.assign(normalized_players);lobby_updated.emit(normalized_players)
func _normalize_player_list(raw_players:Array)->Array[Dictionary]:
	var normalized:Array[Dictionary]=[]
	for raw_player:Variant in raw_players:
		if not raw_player is Dictionary:return []
		var player:Dictionary=(raw_player as Dictionary).duplicate(true)
		if typeof(player.get("peer_id",null))!=TYPE_INT:return []
		if typeof(player.get("display_name",null))!=TYPE_STRING:return []
		if typeof(player.get("seat",null))!=TYPE_INT:return []
		if typeof(player.get("team",null))!=TYPE_INT:return []
		if int(player.get("team", -1)) not in [-1, 0, 1]:return []
		if typeof(player.get("ready",null))!=TYPE_BOOL:return []
		if typeof(player.get("connected",null))!=TYPE_BOOL:return []
		normalized.append(player)
	return normalized
func request_team_change(team: int) -> String:
	return _change_team(1, team) if multiplayer.is_server() else _send_team_request(team)

func _send_team_request(team: int) -> String:
	request_team.rpc_id(1, team)
	return "PENDING"

@rpc("any_peer", "call_remote", "reliable") func request_team(team: int) -> void:
	if not multiplayer.is_server():
		return
	var sender: int = multiplayer.get_remote_sender_id()
	var result: String = _change_team(sender, team)
	receive_lobby_answer.rpc_id(sender, result)

func _change_team(peer_id: int, team: int) -> String:
	if phase != SessionPhase.LOBBY:
		return "LOBBY_LOCKED"
	if String(config.get("game_id", "")) != "truco" or team not in [-1, 0, 1]:
		return "INVALID_TEAM"
	if not players.has(peer_id):
		return "UNREGISTERED_PEER"
	if team in [0, 1]:
		var capacity: int = 1 if String(config.get("truco_mode", "2v2")) == "1v1" else 2
		var members: int = 0
		for player: Dictionary in players.values():
			if int(player.get("peer_id", -1)) != peer_id and int(player.get("team", -1)) == team:
				members += 1
		if members >= capacity:
			return "TEAM_FULL"
	players[peer_id]["team"] = team
	players[peer_id]["ready"] = false
	_sync_lobby()
	return "OK"

func request_lobby_ready(is_ready: bool) -> String:
	return _change_ready(1, is_ready) if multiplayer.is_server() else _send_ready_request(is_ready)

func _send_ready_request(is_ready: bool) -> String:
	request_ready_state.rpc_id(1, is_ready)
	return "PENDING"

@rpc("any_peer", "call_remote", "reliable") func request_ready_state(is_ready: bool) -> void:
	if not multiplayer.is_server():
		return
	var sender: int = multiplayer.get_remote_sender_id()
	var result: String = _change_ready(sender, is_ready)
	receive_lobby_answer.rpc_id(sender, result)

func _change_ready(peer_id: int, is_ready: bool) -> String:
	if phase != SessionPhase.LOBBY:
		return "LOBBY_LOCKED"
	if not players.has(peer_id):
		return "UNREGISTERED_PEER"
	if is_ready and String(config.get("game_id", "")) == "truco" and int(players[peer_id].get("team", -1)) == -1:
		return "TEAM_REQUIRED"
	players[peer_id]["ready"] = is_ready
	_sync_lobby()
	return "OK"

@rpc("authority", "call_remote", "reliable") func receive_lobby_answer(result: String) -> void:
	connection_status.emit(result)

func _ordered_match_players() -> Array:
	var ordered: Array[Dictionary] = _normalize_player_list(players.values())
	ordered.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return int(a.seat) < int(b.seat))
	if String(config.get("game_id", "")) != "truco":
		return ordered.map(func(player: Dictionary) -> int: return int(player.peer_id))
	var team_a: Array[Dictionary] = []
	var team_b: Array[Dictionary] = []
	for player: Dictionary in ordered:
		(team_a if int(player.team) == 0 else team_b).append(player)
	var result: Array = []
	for index: int in mini(team_a.size(), team_b.size()):
		result.append(int(team_a[index].peer_id))
		result.append(int(team_b[index].peer_id))
	return result

func request_start()->String:
	if not multiplayer.is_server():return "NOT_HOST"
	if phase != SessionPhase.LOBBY:
		return "LOBBY_LOCKED"
	var list: Array[Dictionary] = _normalize_player_list(players.values())
	var validation: String = GameConstants.lobby_configuration_valid(String(config.get("game_id", "")), config, list)
	if validation != "OK":
		return validation
	phase=SessionPhase.LOADING;match_id+=1;_ready_peers.clear();var screen:String=config.game_id;load_match.rpc(session_id,match_id,screen);_load_local_match(screen);_scene_timer=_timer(GameConstants.SCENE_READY_TIMEOUT_SECONDS,_scene_ready_timeout);return "OK"
@rpc("authority","call_remote","reliable") func load_match(id:String,new_match_id:int,screen:String)->void:
	if id!=session_id or screen not in GameConstants.GAMES:return
	match_id=new_match_id;SessionState.match_id=match_id;SceneRouter.request_transition(screen)
func _load_local_match(screen:String)->void:SessionState.match_id=match_id;SceneRouter.request_transition(screen);await SceneRouter.transition_finished;client_scene_ready(match_id)
func notify_scene_ready()->void:
	if multiplayer.is_server():client_scene_ready(match_id)
	else:client_scene_ready.rpc_id(1,match_id)
@rpc("any_peer","call_local","reliable") func client_scene_ready(ready_match:int)->void:
	var sender:int=multiplayer.get_remote_sender_id();if sender==0:sender=1
	if not multiplayer.is_server() or phase!=SessionPhase.LOADING or ready_match!=match_id:return
	_ready_peers[sender]=true
	if _ready_peers.size()==players.size():_cancel_timer(_scene_timer);_begin_match()
func _scene_ready_timeout()->void:
	if phase != SessionPhase.LOADING:
		return
	var reason: String = "Tempo de carregamento esgotado; início cancelado."
	_cancel_match_resources()
	for player: Dictionary in players.values():
		player["ready"] = false
	phase = SessionPhase.LOBBY
	SessionState.reset_match()
	notify_return_to_lobby.rpc(reason)
	SceneRouter.request_transition("lobby")
	session_interrupted.emit(reason)
	_sync_lobby()

@rpc("authority","call_remote","reliable") func notify_interruption(reason:String)->void:
	session_interrupted.emit(reason)
func _begin_match()->void:
	_controller=BaseMatchController.new()
	add_child(_controller)
	var ids: Array = _ordered_match_players()
	var game_id: String = String(config.get("game_id", ""))
	var engine:RefCounted
	match game_id:
		"uno":
			engine=UnoRules.new()
		"caxeta":
			engine=CaxetaRules.new()
		"truco":
			engine=TrucoRules.new()
		_:
			push_error("Jogo inválido ao iniciar partida: %s" % game_id)
			_controller.queue_free()
			_controller = null
			phase=SessionPhase.LOBBY
			return
	if game_id == "truco":
		var team_by_peer: Dictionary = {}
		for player: Dictionary in players.values():
			team_by_peer[int(player.peer_id)] = int(player.team)
		config["team_by_peer"] = team_by_peer
	_controller.snapshots_ready.connect(_broadcast_snapshots)
	_controller.match_finished.connect(_match_finished)
	_controller.initialize(engine, ids, randi(), config)
	phase = SessionPhase.MATCH_ACTIVE

func start_training(game_id: String, player_count: int, settings: Dictionary) -> String:
	clean_session()
	# This is the second validation boundary after the setup screen.  Signals or
	# callers cannot start a session by bypassing the disabled button.
	if not TrainingSession.configuration_valid(game_id, player_count, settings):
		return "INVALID_CONFIG"
	is_training_mode = true
	SessionState.is_training = true
	SessionState.is_host = true
	session_id = "training-%s" % Time.get_ticks_msec()
	match_id = 1
	phase = SessionPhase.LOADING
	config = settings.duplicate(true)
	config["game_id"] = game_id
	players.clear()
	var generated: Array[Dictionary] = TrainingSession.build_players(game_id, player_count, String(settings.get("truco_mode", "2v2")))
	if generated.is_empty(): clean_session(); return "INVALID_CONFIG"
	for player: Dictionary in generated: players[int(player.peer_id)] = player
	SessionState.session_id = session_id
	SessionState.match_id = match_id
	SessionState.game_id = game_id
	SessionState.approved_config = config.duplicate(true)
	SessionState.players.assign(_normalize_player_list(players.values()))
	_begin_match()
	SceneRouter.request_transition(game_id)
	return "OK"

func replay_training() -> void:
	if not is_training_mode: return
	_cancel_match_resources()
	SessionState.reset_match()
	match_id += 1
	SessionState.match_id = match_id
	state_version = 0
	_next_action_id = 1
	_training_private_snapshots.clear()
	_training_controlled_peer = -1
	phase = SessionPhase.LOADING
	_begin_match()
	SceneRouter.request_transition(String(config.get("game_id", "")))
func submit_action(action_type: String, payload: Dictionary = {}) -> int:
	if _is_leaving_session:
		return -1
	var action_id: int = _next_action_id
	_next_action_id += 1
	var envelope: Dictionary = NetworkProtocol.envelope(session_id, match_id, action_id, state_version, action_type, payload)
	# O host obedece ao mesmo contrato assíncrono do cliente: o chamador sempre
	# recebe e registra o ID antes que action_answered possa ser emitido.
	if is_training_mode:
		call_deferred("_process_action", SessionState.local_peer_id, envelope)
	elif multiplayer.is_server():
		call_deferred("_process_action", 1, envelope)
	else:
		request_action.rpc_id(1, envelope)
	return action_id
@rpc("any_peer","call_remote","reliable") func request_action(envelope:Dictionary)->void:
	var sender:int=multiplayer.get_remote_sender_id();if not multiplayer.is_server():return
	_process_action(sender,envelope)
func _process_action(sender:int,envelope:Dictionary)->void:
	var validation:String=NetworkProtocol.validate(envelope)
	if validation!="OK":_answer(sender,int(envelope.get("client_action_id",-1)),false,validation);return
	if envelope.session_id!=session_id:_answer(sender,envelope.client_action_id,false,"INVALID_SESSION");return
	if envelope.match_id!=match_id:_answer(sender,envelope.client_action_id,false,"INVALID_MATCH");return
	if not players.has(sender):_answer(sender,envelope.client_action_id,false,"UNREGISTERED_PEER");return
	var key:String="%d:%d"%[sender,int(envelope.get("client_action_id", -1))]
	if _action_cache.has(key):_send_answer(sender,_action_cache[key]);return
	if phase!=SessionPhase.MATCH_ACTIVE:_answer(sender,envelope.client_action_id,false,"INVALID_PHASE");return
	if envelope.expected_state_version!=state_version:_answer(sender,envelope.client_action_id,false,"STALE_STATE");return
	var payload_value: Variant = envelope.get("payload", {})
	var action: Dictionary = (payload_value as Dictionary).duplicate(true)
	action.type=String(envelope.get("action_type", ""))
	var result:Dictionary=_controller.process_action(sender,action)
	_answer(sender,int(envelope.get("client_action_id", -1)),bool(result.get("accepted", false)),String(result.get("reason_code", "INVALID_MESSAGE")))
func _answer(sender:int,id:int,accepted:bool,reason:String)->void:
	var answer:Dictionary={"client_action_id":id,"accepted":accepted,"reason_code":reason,"state_version":state_version};var key:String="%d:%d"%[sender,id];_action_cache[key]=answer
	while _action_cache.size()>GameConstants.MAX_ACTIONS_REMEMBERED_PER_PEER*players.size():_action_cache.erase(_action_cache.keys()[0])
	_send_answer(sender,answer)
func _send_answer(sender:int,answer:Dictionary)->void:
	if is_training_mode:
		action_answered.emit(answer)
		if bool(answer.get("accepted", false)):
			call_deferred("_training_follow_authority")
	elif sender==1:action_answered.emit(answer)
	else:receive_action_answer.rpc_id(sender,answer)
@rpc("authority","call_remote","reliable") func receive_action_answer(answer:Dictionary)->void:action_answered.emit(answer)
func _broadcast_snapshots(public:Dictionary,private:Dictionary)->void:
	state_version=public.state_version;public.session_id=session_id;public.match_id=match_id;public.protocol_version=GameConstants.PROTOCOL_VERSION
	if is_training_mode:
		_training_private_snapshots = private.duplicate(true)
		for id: Variant in _training_private_snapshots:
			_training_private_snapshots[id].session_id = session_id
			_training_private_snapshots[id].match_id = match_id
		SessionState.accept_public_snapshot(public)
		public_snapshot_received.emit(public)
		if _training_controlled_peer == -1:
			_training_follow_authority()
		if String(public.get("game_id", "")) == "truco" and int(public.get("phase", -1)) == TrucoRules.Phase.TRICK_REVEAL:
			_schedule_reveal(int(public.get("state_version", -1)))
		return
	receive_public_snapshot.rpc(public);SessionState.accept_public_snapshot(public);public_snapshot_received.emit(public)
	for id in private:
		var snapshot:Dictionary=private[id];snapshot.session_id=session_id;snapshot.match_id=match_id
		if id==1:SessionState.accept_private_snapshot(snapshot);private_snapshot_received.emit(snapshot)
		else:receive_private_snapshot.rpc_id(id,snapshot)
	if multiplayer.is_server() and String(public.get("game_id", "")) == "truco" and int(public.get("phase", -1)) == TrucoRules.Phase.TRICK_REVEAL:
		_schedule_reveal(int(public.get("state_version", -1)))

func _training_follow_authority() -> void:
	if not is_training_mode or SessionState.public_state.is_empty(): return
	var target: int = TrainingSession.controlled_peer(SessionState.public_state, _training_controlled_peer)
	set_training_control_peer(target)

func set_training_control_peer(peer_id: int) -> bool:
	if not is_training_mode or not players.has(peer_id) or not _training_private_snapshots.has(peer_id): return false
	if String(SessionState.public_state.get("game_id", "")) == "truco" and int(SessionState.public_state.get("phase", -1)) == TrucoRules.Phase.WAITING_TRUCO_RESPONSE:
		var mapping: Dictionary = SessionState.public_state.get("team_by_peer", {}) as Dictionary
		if int(mapping.get(peer_id, -1)) != int(SessionState.public_state.get("responding_team", -2)): return false
	_training_controlled_peer = peer_id
	SessionState.local_peer_id = peer_id
	var snapshot: Dictionary = (_training_private_snapshots[peer_id] as Dictionary).duplicate(true)
	SessionState.private_state = snapshot
	private_snapshot_received.emit(snapshot)
	return true

func _schedule_reveal(version: int) -> void:
	_cancel_timer(_reveal_timer)
	_reveal_token = version
	_reveal_timer = _timer(2.5, func() -> void: _advance_reveal(version))

func _advance_reveal(token: int) -> void:
	if token != _reveal_token or phase != SessionPhase.MATCH_ACTIVE or state_version != token:
		return
	if is_instance_valid(_controller):
		if _controller.advance_authoritative_transition() and is_training_mode:
			call_deferred("_training_follow_authority")
@rpc("authority","call_remote","reliable") func receive_public_snapshot(snapshot:Dictionary)->void:
	if SessionState.accept_public_snapshot(snapshot):state_version=snapshot.state_version;public_snapshot_received.emit(snapshot)
@rpc("authority","call_remote","reliable") func receive_private_snapshot(snapshot:Dictionary)->void:
	if SessionState.accept_private_snapshot(snapshot):private_snapshot_received.emit(snapshot)
func _match_finished(result:Dictionary)->void:
	phase=SessionPhase.MATCH_FINISHED
	if is_training_mode:
		SessionState.public_state=result.duplicate(true)
		SceneRouter.request_transition("results")
		return
	show_results.rpc(result)
	SessionState.public_state=result.duplicate(true)
	SceneRouter.request_transition("results")
@rpc("authority","call_remote","reliable") func show_results(result:Dictionary)->void:
	SessionState.public_state=result.duplicate(true)
	SceneRouter.request_transition("results")
func return_to_lobby()->void:
	if not multiplayer.is_server():return
	if is_instance_valid(_controller):_controller.queue_free()
	SessionState.reset_match();state_version=0;_action_cache.clear();phase=SessionPhase.LOBBY;return_lobby.rpc();SceneRouter.request_transition("lobby")
@rpc("authority","call_remote","reliable") func return_lobby()->void:SessionState.reset_match();phase=SessionPhase.LOBBY;SceneRouter.request_transition("lobby")
@rpc("authority", "call_remote", "reliable") func notify_return_to_lobby(reason: String) -> void:
	SessionState.reset_match()
	phase = SessionPhase.LOBBY
	session_interrupted.emit(reason)
	SceneRouter.request_transition("lobby")
func abort_match()->void:if multiplayer.is_server():return_to_lobby()
func leave_room() -> void: leave_session()
func close_room() -> void: leave_session()

func leave_session() -> void:
	if _is_leaving_session: return
	_is_leaving_session = true
	_shutting_down = true
	_intentional_disconnect = true
	session_leave_started.emit()
	_cancel_match_resources()
	_cancel_timer(_connection_timer)
	_cancel_timer(_scene_timer)
	var was_host: bool = multiplayer.is_server() and phase != SessionPhase.OFFLINE
	var connected: bool = multiplayer.multiplayer_peer != null and not multiplayer.multiplayer_peer is OfflineMultiplayerPeer
	if is_training_mode:
		_finish_session_leave()
		return
	if connected:
		if was_host:
			host_closed_room.rpc()
		else:
			notify_voluntary_leave.rpc_id(1)
		# Give reliable RPCs a bounded opportunity to reach ENet. No ACK can trap UI.
		await get_tree().create_timer(0.25).timeout
	_finish_session_leave()

func _finish_session_leave() -> void:
	if not _is_leaving_session: return
	clean_session(true)
	await _transition_to_menu()
	_is_leaving_session = false
	_shutting_down = false
	_intentional_disconnect = false
	session_leave_completed.emit()

@rpc("authority", "call_remote", "reliable") func host_closed_room() -> void:
	if _is_leaving_session: return
	_is_leaving_session = true
	_intentional_disconnect = true
	session_interrupted.emit("O host encerrou a sala.")
	_finish_session_leave()

func _transition_to_menu() -> void:
	for attempt: int in 10:
		if await SceneRouter.request_transition("menu"):
			return
		await get_tree().process_frame
	push_error("Não foi possível voltar ao menu principal após sair da sessão.")

func _cancel_match_resources() -> void:
	_reveal_token += 1
	_cancel_timer(_reveal_timer)
	if is_instance_valid(_controller):
		_controller.queue_free()
	_controller = null
	_ready_peers.clear()
	_action_cache.clear()
func clean_session(preserve_leave_guard: bool = false)->void:
	_cancel_timer(_connection_timer);_cancel_timer(_scene_timer);_cancel_match_resources()
	multiplayer.multiplayer_peer=OfflineMultiplayerPeer.new();_peer=null;players.clear();config.clear();_ready_peers.clear();_action_cache.clear();session_id="";match_id=0;state_version=0;phase=SessionPhase.OFFLINE;SessionState.reset_all()
	_processed_departures.clear()
	is_training_mode = false
	_training_private_snapshots.clear()
	_training_controlled_peer = -1
	_next_action_id = 1
	if not preserve_leave_guard:
		_shutting_down = false
		_is_leaving_session = false
		_intentional_disconnect = false
func _cancel_timer(timer:Timer)->void:
	if is_instance_valid(timer):timer.stop();timer.queue_free()
func _reseat()->void:
	var list:Array=players.values();list.sort_custom(func(a:Dictionary,b:Dictionary)->bool:return a.seat<b.seat)
	for index in list.size():list[index].seat=index
func get_lan_addresses()->PackedStringArray:
	var result:PackedStringArray=PackedStringArray()
	for address in IP.get_local_addresses():
		if address in ["127.0.0.1","0.0.0.0","::1",""] or address.contains(":"):continue
		if address not in result:result.append(address)
	return result
