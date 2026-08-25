extends Node
signal lobby_updated(players:Array)
signal connection_status(message:String)
signal action_answered(answer:Dictionary)
signal public_snapshot_received(snapshot:Dictionary)
signal private_snapshot_received(snapshot:Dictionary)
signal session_interrupted(reason:String)
enum SessionPhase { OFFLINE, LOBBY, LOCKED, LOADING, MATCH_ACTIVE, MATCH_PAUSED, MATCH_FINISHED }
var phase:SessionPhase=SessionPhase.OFFLINE;var players:Dictionary={};var config:Dictionary={};var session_id:String="";var match_id:int=0;var state_version:int=0
var _peer:ENetMultiplayerPeer;var _connection_timer:Timer;var _scene_timer:Timer;var _ready_peers:Dictionary={};var _action_cache:Dictionary={};var _controller:BaseMatchController;var _next_action_id:int=1
func _ready()->void:
	multiplayer.peer_connected.connect(_on_peer_connected);multiplayer.peer_disconnected.connect(_on_peer_disconnected);multiplayer.connected_to_server.connect(_on_connected);multiplayer.connection_failed.connect(_on_connection_failed);multiplayer.server_disconnected.connect(_on_server_disconnected)
func create_server(nickname:String,game_id:String,settings:Dictionary,port:int)->String:
	clean_session()
	var name:String=GameConstants.sanitize_nickname(nickname)
	if name.is_empty() or game_id not in GameConstants.GAMES or not GameConstants.valid_port(port):return "INVALID_CONFIG"
	_peer=ENetMultiplayerPeer.new();var error:Error=_peer.create_server(port,GameConstants.MAX_TRANSPORT_CLIENTS)
	if error!=OK:_peer=null;return "SERVER_CREATE_FAILED"
	multiplayer.multiplayer_peer=_peer;session_id="%s-%s"%[Time.get_unix_time_from_system(),randi()];phase=SessionPhase.LOBBY;config=settings.duplicate(true);config.game_id=game_id;config.port=port
	players[1]={"peer_id":1,"display_name":name,"seat":0,"ready":true,"connected":true};_sync_lobby();return "OK"
func create_client(nickname:String,address:String,port:int)->String:
	clean_session();var name:String=GameConstants.sanitize_nickname(nickname)
	if name.is_empty() or address.strip_edges().is_empty() or address.length()>255 or not GameConstants.valid_port(port):return "INVALID_CONFIG"
	SessionState.nickname=name;_peer=ENetMultiplayerPeer.new();var error:Error=_peer.create_client(address.strip_edges(),port)
	if error!=OK:_peer=null;return "CLIENT_CREATE_FAILED"
	multiplayer.multiplayer_peer=_peer;phase=SessionPhase.OFFLINE;_connection_timer=_timer(GameConstants.CONNECTION_TIMEOUT_SECONDS,_on_connection_timeout);return "OK"
func _timer(seconds:float,callback:Callable)->Timer:
	var timer:Timer=Timer.new();timer.one_shot=true;timer.wait_time=seconds;add_child(timer);timer.timeout.connect(callback);timer.start();return timer
func _on_connected()->void:
	_cancel_timer(_connection_timer);connection_status.emit("Conectado; registrando jogador...");register_player.rpc_id(1,GameConstants.PROTOCOL_VERSION,SessionState.nickname)
func _on_connection_failed()->void:clean_session();connection_status.emit("Não foi possível conectar.")
func _on_connection_timeout()->void:clean_session();connection_status.emit("Tempo de conexão esgotado. Verifique IP, porta, rede e firewall.")
func _on_server_disconnected()->void:clean_session();session_interrupted.emit("O host encerrou a sala.")
func _on_peer_connected(_id:int)->void:pass
func _on_peer_disconnected(id:int)->void:
	if not multiplayer.is_server():return
	if players.erase(id):
		_reseat()
		if phase==SessionPhase.LOBBY:_sync_lobby()
		elif phase in [SessionPhase.LOADING,SessionPhase.MATCH_ACTIVE]:phase=SessionPhase.MATCH_PAUSED;notify_interruption.rpc("Jogador desconectado; partida pausada.");session_interrupted.emit("Jogador desconectado; partida pausada.")
@rpc("any_peer","call_remote","reliable") func register_player(protocol:int,nickname:String)->void:
	var sender:int=multiplayer.get_remote_sender_id()
	if not multiplayer.is_server():return
	if protocol!=GameConstants.PROTOCOL_VERSION:_reject_and_disconnect(sender,"PROTOCOL_MISMATCH");return
	if phase!=SessionPhase.LOBBY:_reject_and_disconnect(sender,"MATCH_ALREADY_STARTED");return
	if players.size()>=GameConstants.MAX_TOTAL_PLAYERS:_reject_and_disconnect(sender,"ROOM_FULL");return
	var clean:String=GameConstants.sanitize_nickname(nickname)
	if clean.is_empty():_reject_and_disconnect(sender,"INVALID_MESSAGE");return
	clean=_unique_name(clean);players[sender]={"peer_id":sender,"display_name":clean,"seat":players.size(),"ready":true,"connected":true};receive_session.rpc_id(sender,session_id,config,players.values());_sync_lobby()
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
	phase=SessionPhase.LOBBY;SessionState.session_id=id;SessionState.game_id=config.game_id;SessionState.players.assign(normalized_players);SessionState.local_peer_id=multiplayer.get_unique_id();SceneRouter.request_transition("lobby")
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
		if typeof(player.get("ready",null))!=TYPE_BOOL:return []
		if typeof(player.get("connected",null))!=TYPE_BOOL:return []
		normalized.append(player)
	return normalized
func request_start()->String:
	if not multiplayer.is_server():return "NOT_HOST"
	if phase!=SessionPhase.LOBBY or not GameConstants.player_count_valid(config.game_id,players.size()):return "INVALID_PLAYER_COUNT"
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
func _scene_ready_timeout()->void:phase=SessionPhase.LOBBY;notify_interruption.rpc("Tempo de carregamento esgotado; início cancelado.");session_interrupted.emit("Tempo de carregamento esgotado; início cancelado.")

@rpc("authority","call_remote","reliable") func notify_interruption(reason:String)->void:
	session_interrupted.emit(reason)
func _begin_match()->void:
	_controller=BaseMatchController.new()
	add_child(_controller)
	var ids:Array=players.keys()
	ids.sort()
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
	_controller.snapshots_ready.connect(_broadcast_snapshots);_controller.match_finished.connect(_match_finished);_controller.initialize(engine,ids,randi(),config);phase=SessionPhase.MATCH_ACTIVE
func submit_action(action_type:String,payload:Dictionary={})->int:
	var action_id:int=_next_action_id;_next_action_id+=1;var envelope:Dictionary=NetworkProtocol.envelope(session_id,match_id,action_id,state_version,action_type,payload)
	if multiplayer.is_server():_process_action(1,envelope)
	else:request_action.rpc_id(1,envelope)
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
	if sender==1:action_answered.emit(answer)
	else:receive_action_answer.rpc_id(sender,answer)
@rpc("authority","call_remote","reliable") func receive_action_answer(answer:Dictionary)->void:action_answered.emit(answer)
func _broadcast_snapshots(public:Dictionary,private:Dictionary)->void:
	state_version=public.state_version;public.session_id=session_id;public.match_id=match_id;public.protocol_version=GameConstants.PROTOCOL_VERSION
	receive_public_snapshot.rpc(public);SessionState.accept_public_snapshot(public);public_snapshot_received.emit(public)
	for id in private:
		var snapshot:Dictionary=private[id];snapshot.session_id=session_id;snapshot.match_id=match_id
		if id==1:SessionState.accept_private_snapshot(snapshot);private_snapshot_received.emit(snapshot)
		else:receive_private_snapshot.rpc_id(id,snapshot)
@rpc("authority","call_remote","reliable") func receive_public_snapshot(snapshot:Dictionary)->void:
	if SessionState.accept_public_snapshot(snapshot):state_version=snapshot.state_version;public_snapshot_received.emit(snapshot)
@rpc("authority","call_remote","reliable") func receive_private_snapshot(snapshot:Dictionary)->void:
	if SessionState.accept_private_snapshot(snapshot):private_snapshot_received.emit(snapshot)
func _match_finished(result:Dictionary)->void:
	phase=SessionPhase.MATCH_FINISHED
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
func abort_match()->void:if multiplayer.is_server():return_to_lobby()
func clean_session()->void:
	_cancel_timer(_connection_timer);_cancel_timer(_scene_timer)
	if is_instance_valid(_controller):_controller.queue_free()
	multiplayer.multiplayer_peer=OfflineMultiplayerPeer.new();_peer=null;players.clear();config.clear();_ready_peers.clear();_action_cache.clear();session_id="";match_id=0;state_version=0;phase=SessionPhase.OFFLINE;SessionState.reset_all()
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
