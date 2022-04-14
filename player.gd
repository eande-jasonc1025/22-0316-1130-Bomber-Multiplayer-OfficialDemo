extends KinematicBody2D

const MOTION_SPEED = 90.0

puppet var puppet_Position_Vector2 = Vector2()
puppet var puppet_Motion_Vector2 = Vector2()

export var stunned = false

# Use sync because it will be called everywhere
remotesync func setup_bomb(bomb_name, pos, by_who):
	var bomb = preload("res://bomb.tscn").instance()
	bomb.set_name(bomb_name) # Ensure unique name for the bomb
	bomb.position = pos
	###jwc 2022-0405-0900
	bomb.rotation_degrees = randi() % 360
	bomb.from_player = by_who
	# Spawn under 'World'
	# No need to set network master to bomb, will be owned by server by default
	#    Thus the spawn up 2 levels
	###jwc o get_node("../..").add_child(bomb)
	###jwc n same level as player: self.get_parent().add_child(bomb)
	self.get_parent().get_parent().add_child(bomb)

var current_anim = ""
var prev_bombing = false
var bomb_index = 0


func _physics_process(_delta):
	var motion_Request_Vector2 = Vector2()

	if is_network_master():
		if Input.is_action_pressed("move_left"):
			motion_Request_Vector2 += Vector2(-1, 0)
		if Input.is_action_pressed("move_right"):
			motion_Request_Vector2 += Vector2(1, 0)
		if Input.is_action_pressed("move_up"):
			motion_Request_Vector2 += Vector2(0, -1)
		if Input.is_action_pressed("move_down"):
			motion_Request_Vector2 += Vector2(0, 1)

		var bombing = Input.is_action_pressed("set_bomb")

		if stunned:
			# 'bombing' deactivated
			bombing = false
			# clear 'motion_Request_Vector2'
			motion_Request_Vector2 = Vector2()

		# bombing cannot occur back-to-back
		if bombing and not prev_bombing:
			###jwc o: var bomb_name = String(get_name()) + str(bomb_index)
			###var bomb_name = String(get_name()) + str(bomb_index)
			var bomb_name = String(get_name()) +"-"+ str(bomb_index)
			var bomb_pos = self.position
			rpc("setup_bomb", bomb_name, bomb_pos, get_tree().get_network_unique_id())

		prev_bombing = bombing

		# Remote Set
		#
		rset("puppet_Motion_Vector2", motion_Request_Vector2)
		rset("puppet_Position_Vector2", self.position)
	else:
		# Remote Get
		#
		motion_Request_Vector2 = puppet_Motion_Vector2
		self.position = puppet_Position_Vector2

	# Set animation
	#
	var new_anim = "standing"
	if motion_Request_Vector2.y < 0:
		new_anim = "walk_up"
	elif motion_Request_Vector2.y > 0:
		new_anim = "walk_down"
	elif motion_Request_Vector2.x < 0:
		new_anim = "walk_left"
	elif motion_Request_Vector2.x > 0:
		new_anim = "walk_right"

	if stunned:
		new_anim = "stunned"

	if new_anim != current_anim:
		current_anim = new_anim
		get_node("anim").play(current_anim)

	# FIXME: Use move_and_slide
	move_and_slide(motion_Request_Vector2 * MOTION_SPEED)
	
	
	# jwc TODO Seems unecessary
	#
	if not is_network_master():
		puppet_Position_Vector2 = self.position # To avoid jitter

###jwc o puppet func stun():
###jwc ? remotesync func stun():
###jwc n puppetsync func stun():
###jwc n puppet func stun():
###jwc y/m remote func stun():
###jwc y puppet func stun():
puppetsync func stun():
	stunned = true

###jwc ERROR: RPC 'exploded' is not allowed on node /root/World/Players/1925601838 from: 1. Mode is 2, master is 1925601838. at: (core/io/multiplayer_api.cpp:285)

###jwc eande2 and eande3: has these warning but not fatal: scoring/stunning still works :)+
###jwc ERROR: RPC 'exploded' is not allowed on node /root/World/Players/178427738 from: 1. Mode is 2, master is 178427738.
###jwc ERROR: RPC 'exploded' is not allowed on node /root/World/Players/992867613 from: 1. Mode is 2, master is 992867613.
###jwc RPC_MODE_MASTER = 2 --- Used with Node.rpc_config or Node.rset_config to set a method to be called or a property to be changed only on the network master for this node. Analogous to the master keyword. Only accepts calls or property changes from the node's network puppets, see Node.set_network_master.
###jwc
###jwc o master func exploded(_by_who):
###jwc n mastersync func exploded(_by_who):
###jwc n master func exploded(_by_who):
###jwc worst remotesync func exploded(_by_who):
###jwc y remote func exploded(_by_who):
master func exploded(_by_who):
	if stunned:
		return
	rpc("stun") # Stun puppets
	###jwc o stun() # Stun master - could use sync to do both at once
	###jwc o $"../../Score".rpc("increase_score", _by_who)
	self.get_parent().get_parent().get_node("Score").rpc("increase_score", _by_who)

func set_player_name(new_name):
	get_node("label").set_text(new_name)


func _ready():
	stunned = false
	puppet_Position_Vector2 = self.position
