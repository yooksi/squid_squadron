extends Area2D

signal hit

# how fast the player will move (pixels/sec)
export (int) var MAX_VELOCITY = 350
export (int) var ACCELERATION = 20
export (int) var FRICTION = 7         # set to 0 to disable

# if set to false no player animations will be played
export (bool) var play_animation = true

var velocity = Velocity.new(self)
var screensize  # size of the game window

onready var HUD = get_node("../HUD")
onready var debug = get_node("../Debug")

class Velocity:
	# Use this instance to reach player variables
	var player setget constVar
	
	func _init(var owner):
		player = owner
	
	enum { AXIS_X, AXIS_Y }
	
	# Constant variables, DON'T ALTER VALUES!
	var north = Direction.new("ui_up", AXIS_Y, -1) setget constVar
	var south = Direction.new("ui_down", AXIS_Y, 1) setget constVar
	var east = Direction.new("ui_right", AXIS_X, 1) setget constVar
	var west = Direction.new("ui_left", AXIS_X, -1) setget constVar
	
	# Use this method as a 'setter' for all constant vars
	# Prevents functions outside local scope from changing values
	func constVar():
		pass
	
	class Direction:
		var key setget constVar
		var axis setget constVar
		var value setget constVar
		
		func constVar():
			pass
		
		func _init(var k, var a, var v):
			key = k
			axis = a
			value = v

	var motion_vector = Vector2()
	var input_key = [ null, null ]  # used for printing debug info
	
	# Input key should be reset on every tick if the player is not pressing
	# one of the two buttons on the given axis
	func resetInputKey(var axis):
		input_key[axis] = null
	
	func isKeyPressedOn(var axis):
		return input_key[axis] != null

	# Gets called each tick on every player control input
	func updateData(var direction):
		updateMotionVector(direction)
		input_key[direction.axis] = direction.key
	
	# Add motion to player by accelerating in the given direction
	func updateMotionVector(var direction):
		var acceleration = player.ACCELERATION * direction.value
		match direction.axis:
			AXIS_X:
				motion_vector.x += acceleration
				if (abs(motion_vector.x) > player.MAX_VELOCITY):
					motion_vector.x = player.MAX_VELOCITY if (motion_vector.x > 0) else -player.MAX_VELOCITY
			AXIS_Y:
				motion_vector.y += acceleration
				if (abs(motion_vector.y) > player.MAX_VELOCITY):
					motion_vector.y = player.MAX_VELOCITY if (motion_vector.y > 0) else -player.MAX_VELOCITY
	
	# Friction is the counter-force to player's movements.
	# It should be applied each tick regardless of player input
	func applyFriction():
		var f_vec = Vector2(0, 0)
		
		if (motion_vector.x > 0):
			var res = motion_vector.x - player.FRICTION
			f_vec.x = -player.FRICTION if (res > 0) else -motion_vector.x
		elif (motion_vector.x < 0):
			var res = motion_vector.x + player.FRICTION
			f_vec.x = player.FRICTION if (res < 0) else -motion_vector.x
		
		if (motion_vector.y > 0):
			var res = motion_vector.y - player.FRICTION
			f_vec.y = -player.FRICTION if (res > 0) else -motion_vector.y
		elif (motion_vector.y < 0):
			var res = motion_vector.y + player.FRICTION
			f_vec.y = player.FRICTION if (res < 0) else -motion_vector.y
			
		motion_vector += f_vec
	
	# Get magnitude of motion vector
	func getVelocity():
		return sqrt(pow(motion_vector.x, 2) + pow(motion_vector.y, 2))
	
	func move(var delta):
		# apply friction only if it's enabled
		if (player.FRICTION > 0):
			applyFriction()
		
		# Total player velocity should not exceed max velocity value
		var velocity = getVelocity()
		if (velocity > player.MAX_VELOCITY):
			motion_vector *= (1 - (velocity - player.MAX_VELOCITY)/motion_vector.length()) 
			motion_vector = motion_vector.floor()
			
		# Clamp the player position to prevent him from leaving the screen
		player.position += motion_vector * delta
		player.position.x = clamp(player.position.x, 0, player.screensize.x)
		player.position.y = clamp(player.position.y, 0, player.screensize.y)
		
		# Update debug panel with new data
		player.debug.updateMotionInfo(motion_vector.abs())
		player.debug.updatePositionInfo(player.position)
		player.debug.updateInputInfo(input_key)

func hasMomentum():
	return (velocity.motion_vector.length() > 0)

func getPlayerSpeed():
	return velocity.motion_vector.abs().x + velocity.motion_vector.abs().y

func start(pos):
	position = pos
	$AnimatedSprite.animation = "neutral"
	show()
	$CollisionShape2D.disabled = false

func _ready():
	hide()
	screensize = get_viewport_rect().size

# Called every frame. Delta is time since last frame.
# Update game logic here.
func _process(delta):

	if Input.is_action_pressed(velocity.east.key):
		velocity.updateData(velocity.east)
	elif Input.is_action_pressed(velocity.west.key):
		velocity.updateData(velocity.west)
	else: velocity.resetInputKey(Velocity.AXIS_X)
	
	if Input.is_action_pressed(velocity.south.key):
		velocity.updateData(velocity.south)
	elif Input.is_action_pressed(velocity.north.key):
		velocity.updateData(velocity.north)
	else: velocity.resetInputKey(Velocity.AXIS_Y)
		
	if (hasMomentum()):
		velocity.move(delta)
		if (play_animation == true):
			#if (getPlayerSpeed() / MAX_SPEED > 0.90):
			#	if ($AnimatedSprite.frame == 0):
			#		$AnimatedSprite.stop()
			#elif (!$AnimatedSprite.is_playing()):
			$AnimatedSprite.play()
				
			if (velocity.isKeyPressedOn(Velocity.AXIS_X)):
				$AnimatedSprite.animation = "right"
				$AnimatedSprite.flip_v = false
				$AnimatedSprite.flip_h = velocity.motion_vector.x < 0
			elif (velocity.isKeyPressedOn(Velocity.AXIS_Y)):
				$AnimatedSprite.animation = "up"
				$AnimatedSprite.flip_v = velocity.motion_vector.y > 0	
	elif (play_animation == true):
		$AnimatedSprite.stop()

func _on_Player_body_entered(body):
	emit_signal("hit")
	$CollisionShape2D.disabled = true   # makes the player invulnerable
	if (HUD.lives_remaining > 0):
		$HitRecovery.start()            # keeps the player invulnerable and blinking
		if (play_animation == true):
			$HitAnimation.start()       # regulates the blinking effect

# Gets called when the player hit recovery phase ends,
# stop blinking and become vulnerable again.
func _on_HitRecovery_timeout():
	$CollisionShape2D.disabled = false
	if (play_animation == true):
		if (!is_visible()): show()
		$HitAnimation.stop()

# This will produce a blinking affect indicating
# that the player has been recently hit and is recovering
func _on_HitAnimation_timeout():
	if (is_visible()): hide()
	else: show()