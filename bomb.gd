extends Area2D

var in_area = []
var from_player

# Called from the animation.
func explode():
	if not is_network_master():
		# Explode only on master.
		return
	for p in in_area:
		if p.has_method("exploded"):
			# Exploded has a master keyword, so it will only be received by the master.
			###jwc o p.rpc("exploded", from_player)
			###jwc n nothing even when 'remote' on other side: p.rpc_id(1, "exploded", from_player)
			###jwc n even when restored back to orig on other side: p.rpc_id(1, "exploded", from_player)
			p.rpc("exploded", from_player)


func done():
	queue_free()


func _on_bomb_body_enter(body):
	if not body in in_area:
		in_area.append(body)


func _on_bomb_body_exit(body):
	in_area.erase(body)
	

###jwc copied from 'spacewar-networking-Zack'
###
###jwc o const speed = 375
###jwc too slow: const speed = 10
#const speed = 50
#func _physics_process(delta):
#	self.position += Vector2(cos(rotation - PI/2), sin(rotation - PI/2)) * delta * speed
#
#	if(is_network_master()):
#		rset("position", position)
		
		
###jwc o var lifetime = 0.75
###jwc y but faster for testing: var lifetime = 3.00
###jwc n too fast? var lifetime = 0.5
###jwc n var lifetime = 0.75
var lifetime = 3.00

###jwc o const speed = 375
###jwc too slow: const speed = 10
###jwc y but slower for test: const speed = 50
###jwc y good for slow test: const speed = 5
###jwc more playable as is, with stationary bomb
const speed = 0

var ignoredBodies = []

func _ready():
	set_network_master(1)
	# RPC_MODE_PUPPET = 3 --- Used with Node.rpc_config or Node.rset_config to set a method to be called or a property to be changed only on puppets for this node. Analogous to the puppet keyword. Only accepts calls or property changes from the node's network master, see Node.set_network_master.
	#
	###jwc o rset_config("position", MultiplayerAPI.RPC_MODE_PUPPET)
	###jwc o rset_config("rotation", MultiplayerAPI.RPC_MODE_PUPPET)
	rset_config("self.position", MultiplayerAPI.RPC_MODE_PUPPET)
	rset_config("self.rotation", MultiplayerAPI.RPC_MODE_PUPPET)
	
	###jwc not needed, 'ERROR: RSET 'rotation' is not allowed on node ... from: 1. Mode is 0, master is 1.
	### 
	###jwc o if(is_network_master()):
		###jwc o rset("self.rotation", self.rotation)
		###jwc o rset("rotation", self.rotation)
	
	connect("body_entered", self, "body_entered")

func _physics_process(delta):
	self.position += Vector2(cos(self.rotation - PI/2), sin(self.rotation - PI/2)) * delta * speed
	self.lifetime -= delta
	
	if(is_network_master()):
		if(self.lifetime <= 0):
			rpc("die")
		
		###jwc ERR_FAIL_COND(!is_inside_tree());: rset("position", position)

func body_entered(body):
	if(!body in ignoredBodies):
		if(body.has_method("die")):
			body.call("die")

remotesync func die():
	self.get_parent().remove_child(self)

