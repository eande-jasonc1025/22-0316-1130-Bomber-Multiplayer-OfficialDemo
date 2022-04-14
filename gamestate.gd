extends Node

# Default game server port. Can be any number between 1024 and 49151.
# Not on the list of registered or common ports as of November 2020:
# https://en.wikipedia.org/wiki/List_of_TCP_and_UDP_port_numbers
const DEFAULT_PORT = 10567

# Max number of players.
const MAX_PEERS = 12

var peer = null

# Name for my player.
var player_name = "The Warrior"

# Names for remote players in id:name format.
var playersOther_NetworkId_ToName_Array = {}
var playersAll_SetupDone_BoolArray = []

# Signals to let lobby GUI know what's going on via 'gamestate.connect()' definitions in lobby.gd
signal connection_succeeded()
signal connection_failed()
signal playersOther_List_Updated()
signal game_ended()
signal game_error(what)


func _ready():
	get_tree().connect("network_peer_connected", self, "_player_connected")
	get_tree().connect("network_peer_disconnected", self,"_player_disconnected")
	get_tree().connect("connected_to_server", self, "_connected_ok")
	get_tree().connect("connection_failed", self, "_connected_fail")
	get_tree().connect("server_disconnected", self, "_server_disconnected")


func gameState_01_HostPlayer_OnNetwork_Func(new_player_name):
	player_name = new_player_name
	peer = NetworkedMultiplayerENet.new()
	peer.create_server(DEFAULT_PORT, MAX_PEERS)
	get_tree().set_network_peer(peer)
	print("* gameState_01_HostPlayer_OnNetwork_Func(new_player_name)")

func gameState_02_GuestPlayer_OnNetwork_Func(ip, new_player_name):
	player_name = new_player_name
	peer = NetworkedMultiplayerENet.new()
	peer.create_client(ip, DEFAULT_PORT)
	get_tree().set_network_peer(peer)
	print("* gameState_02_GuestPlayer_OnNetwork_Func(ip, new_player_name)")
		

func get_PlayersOther_List_Func():
	print("* get_PlayersOther_List_Func()")
	return playersOther_NetworkId_ToName_Array.values()

func get_player_name():
	return player_name


func gameState_03_HostToAllPeers_SetupStart_Func():
	print('*** << gameState_03_HostToAllPeers_SetupStart_Func(): ' + str( get_tree().get_rpc_sender_id() ))

	assert(get_tree().is_network_server())
	###jwc
	print("** 0 gameState_03_HostToAllPeers_SetupStart_Func: ")
	
	# Create a dictionary with peer id and respective spawn points, could be improved by randomizing.
	var playersAll_SpawnId_Array = {}

	playersAll_SpawnId_Array[1] = 0 # Server in spawn point 0.
	var playersAll_SpawnId_Base0Num = 1

	for p in playersOther_NetworkId_ToName_Array:
		playersAll_SpawnId_Array[p] = playersAll_SpawnId_Base0Num
		playersAll_SpawnId_Base0Num += 1
		
		print("** 1a gameState_03_HostToAllPeers_SetupStart_Func: p: " + str(p))
		print("** 1b gameState_03_HostToAllPeers_SetupStart_Func: playersOther_NetworkId_ToName_Array: " + str(playersOther_NetworkId_ToName_Array))

	###jwc o: # Call to pre-start game with the spawn points.
	###jwc o: for p in playersOther_NetworkId_ToName_Array:
	###jwc o: 	print("** 2a gameState_03_HostToAllPeers_SetupStart_Func: p: " + str(p))
	###jwc o: 	rpc_id(p, "gameState_04_AllPeers_SetupDo_Func", playersAll_SpawnId_Array)
	###jwc o: 
	###jwc o: 	###jwc print('*2b gameState_03_HostToAllPeers_SetupStart_Func: rpc_id(p, "gameState_04_AllPeers_SetupDo_Func", playersAll_SpawnId_Array): ' + p + playersAll_SpawnId_Array)  
	###jwc o: gameState_04_AllPeers_SetupDo_Func(playersAll_SpawnId_Array)

	print("** 2a gameState_03_HostToAllPeers_SetupStart_Func:")
	print('*** rpc("gameState_04_AllPeers_SetupDo_Func", playersAll_SpawnId_Array): ' + str(get_tree().get_network_unique_id()) + ' >>')
	rpc("gameState_04_AllPeers_SetupDo_Func", playersAll_SpawnId_Array)

	print("* gameState_03_HostToAllPeers_SetupStart_Func()")
	print()
		
		

# Auto-Callback from SceneTree, for both clients and client-server (networkid=1).
func _player_connected(id):
	# Registration of a client beings here, tell the connected player that we are here.
	rpc_id(id, "playersOther_Register_Func", player_name)
	print("* _player_connected(id): " + str(id))


# Callback from SceneTree, for both clients and client-server (networkid=1).
func _player_disconnected(id):
	if has_node("/root/World"): # Game is in progress.
		if get_tree().is_network_server():
			emit_signal("game_error", "Player " + playersOther_NetworkId_ToName_Array[id] + " disconnected")
			gameState_07_Peer_End_Func()
	else: # Game is not in progress.
		# Unregister this player.
		playersOther_Unregister_Func(id)
	print("* _player_disconnected(id): " + str(id))


# Callback from SceneTree, only for clients (not client-server (networkid=1)).
func _connected_ok():
	# We just connected to a server
	emit_signal("connection_succeeded")
	print("* _connected_ok()")

# Callback from SceneTree, only for clients (not client-server (networkid=1)).
func _connected_fail():
	get_tree().set_network_peer(null) # Remove peer
	emit_signal("connection_failed")
	print("* _connected_fail()")

# Callback from SceneTree, only for clients (not client-server (networkid=1)).
func _server_disconnected():
	emit_signal("game_error", "Server disconnected")
	gameState_07_Peer_End_Func()
	print("* _server_disconnected()")
	

# Lobby management functions.

remote func playersOther_Register_Func(new_player_name):
	print("* << playersOther_Register_Func(new_player_name): " + str( get_tree().get_rpc_sender_id() ))

	var id = get_tree().get_rpc_sender_id()
	###jwc o print(id)
	print("** playersOther_Register_Func: id: " + str(id) + " / new_player_name: " + new_player_name)
	playersOther_NetworkId_ToName_Array[id] = new_player_name
	emit_signal("playersOther_List_Updated")
	print("* playersOther_Register_Func(new_player_name)")
	print()

func playersOther_Unregister_Func(id):
	playersOther_NetworkId_ToName_Array.erase(id)
	emit_signal("playersOther_List_Updated")
	print("* playersOther_Unregister_Func(id)")


###jwc o remote func gameState_04_AllPeers_SetupDo_Func(playersAll_SpawnId_Array_In):
remotesync func gameState_04_AllPeers_SetupDo_Func(playersAll_SpawnId_Array_In):
	###jwc
	###print("*1 gameState_04_AllPeers_SetupDo_Func" + playersAll_SpawnId_Array_In)
	print("*** << gameState_04_AllPeers_SetupDo_Func(playersAll_SpawnId_Array_In): " + str( get_tree().get_rpc_sender_id() ))

	# Change scene.
	var world = load("res://world.tscn").instance()
	get_tree().get_root().add_child(world)

	get_tree().get_root().get_node("Lobby").hide()

	var player_scene = load("res://player.tscn")

	for p_id in playersAll_SpawnId_Array_In:
		var spawn_pos = world.get_node("SpawnPoints/" + str(playersAll_SpawnId_Array_In[p_id])).position
		var player = player_scene.instance()

		player.set_name(str(p_id)) # Use unique ID as node name.
		player.position=spawn_pos
		player.set_network_master(p_id) #set unique id as master.
		print("** gameState_04_AllPeers_SetupDo_Func: p_id: " + str(p_id))

		if p_id == get_tree().get_network_unique_id():
			# If node for this peer id, set name.
			player.set_player_name(player_name)
		else:
			# Otherwise set name from peer.
			player.set_player_name(playersOther_NetworkId_ToName_Array[p_id])

		world.get_node("Players").add_child(player)

	# Set up score.
	world.get_node("Score").add_player(get_tree().get_network_unique_id(), player_name)
	for pn in playersOther_NetworkId_ToName_Array:
		world.get_node("Score").add_player(pn, playersOther_NetworkId_ToName_Array[pn])

	if not get_tree().is_network_server():
		# Tell server we are ready to start.
		###jwc o: 	###jwc o rpc_id(1, "gameState_05_AllPeersToHost_SetupDone_Func", get_tree().get_network_unique_id())
		print('*** rpc("gameState_05_AllPeersToHost_SetupDone_Func", get_tree().get_network_unique_id()): '  + str(get_tree().get_network_unique_id()) +' >>')
		##jwc 'ERROR: RPC 'gameState_05_AllPeersToHost_SetupDone_Func' is not allowed on node /root/gamestate from: 1708743429. Mode is 2, master is 1.' rpc("gameState_05_AllPeersToHost_SetupDone_Func", get_tree().get_network_unique_id())
		rpc_id(1, "gameState_05_AllPeersToHost_SetupDone_Func", get_tree().get_network_unique_id())
	###jwc o: ###jwc TODO: eliminate? move to 'remotesync'?
	# else no peer-guests, just peer-host
	elif get_tree().is_network_server() and playersOther_NetworkId_ToName_Array.size() == 0:
		gameState_06_HostToAllPeers_Start_Func()
	###jwc o: 
	###jwc ? print('*** rpc("gameState_05_AllPeersToHost_SetupDone_Func", get_tree().get_network_unique_id()): '  + str(get_tree().get_network_unique_id()) +' >>')
	###jwc ? rpc("gameState_05_AllPeersToHost_SetupDone_Func", get_tree().get_network_unique_id())

	print("* gameState_04_AllPeers_SetupDo_Func(playersAll_SpawnId_Array_In)")
	print()

###jwc o remote func gameState_05_AllPeersToHost_SetupDone_Func(id):
master func gameState_05_AllPeersToHost_SetupDone_Func(id):
	print('*** << gameState_05_AllPeersToHost_SetupDone_Func(id): ' + str( get_tree().get_rpc_sender_id() ))

	assert(get_tree().is_network_server())

	if not id in playersAll_SetupDone_BoolArray:
		playersAll_SetupDone_BoolArray.append(id)

	print('* gameState_05_AllPeersToHost_SetupDone_Func(id): if playersAll_SetupDone_BoolArray.size() == playersOther_NetworkId_ToName_Array.size(): ' + str(playersAll_SetupDone_BoolArray.size()) +' ==? '+ str(playersOther_NetworkId_ToName_Array.size()) )	
	if playersAll_SetupDone_BoolArray.size() == playersOther_NetworkId_ToName_Array.size():
		###jwc o for p in playersOther_NetworkId_ToName_Array:
		###jwc o 	rpc_id(p, "gameState_06_HostToAllPeers_Start_Func")
		###jwc o gameState_06_HostToAllPeers_Start_Func()
		print('*** rpc("gameState_06_HostToAllPeers_Start_Func"): ' + str(get_tree().get_network_unique_id()) +' >>')
		rpc("gameState_06_HostToAllPeers_Start_Func")

	print("* gameState_05_AllPeersToHost_SetupDone_Func(id)")

###jwc o remote func gameState_06_HostToAllPeers_Start_Func():
remotesync func gameState_06_HostToAllPeers_Start_Func():
	print("*** << gameState_06_HostToAllPeers_Start_Func(): " + str( get_tree().get_rpc_sender_id() ))

	get_tree().set_pause(false) # Unpause and unleash the game!
	print("* gameState_06_HostToAllPeers_Start_Func()")
	print()


func gameState_07_Peer_End_Func():
	if has_node("/root/World"): # Game is in progress.
		# End it
		get_node("/root/World").queue_free()

	emit_signal("game_ended")
	playersOther_NetworkId_ToName_Array.clear()
	print("* gameState_07_Peer_End_Func()")
