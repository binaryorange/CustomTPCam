extends Spatial


# Store the camera and camera targets in onready vars
onready var MainCamera = $XGimbal/Camera
onready var CameraTarget = $XGimbal/Target

# This is the assignable follow target
export (NodePath) var FollowTarget

# Export variables that can be used to modify camera behavior
export (int, 1, 3) var ViewDistances = 3
export (int, 3, 8) var ViewDistanceStep = 5
export (float, 0.01, 0.09) var CameraLerpSpeed = 0.03
enum FOLLOW_MODE {INSTANT, SMOOTH}
export (FOLLOW_MODE) var FollowMode = FOLLOW_MODE.SMOOTH
export (float, 0.01, 0.1) var FollowDelaySpeed = 0.05
export (float, 0.1, 0.9) var RaycastMargin = 0.5
export (float) var MinClampXAngle = -60.0
export (float) var MaxClampXAngle = 60.0

var follow_target = null
var view_distances = []
var probe_array = []
var raycasts = []
var default_view_distance
var current_view_distance

var gimbal_offset
var cam_up
var cam_right
var mouse_moved


# Called when the node enters the scene tree for the first time.
func _ready():
	# Store the follow target
	if FollowTarget:
		follow_target = get_node(FollowTarget)
	else:
		print("Oops, nothing assigned to FollowTarget! Try again!")
	
	# Create the different view distances
	for i in ViewDistances:
		view_distances.insert(view_distances.size(), ViewDistanceStep + ViewDistanceStep * i)
		print("Added view distance " + str(view_distances[i]))
		
	# Set the default view distance
	default_view_distance = view_distances[2]
	current_view_distance = 0

	
	# Store the offset of the gimbal/player
	gimbal_offset = global_transform.origin - follow_target.global_transform.origin
	
	# Store the raycasts in the raycast array
	for i in range($XGimbal/Raycasts.get_child_count()):
		raycasts.insert(raycasts.size(), $XGimbal/Raycasts.get_child(i))
		print(raycasts[i].name)
	
	# Hide the helper mesh
	$XGimbal/Target.hide()
	
	# Set the mouse mode to captured
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	
func _input(event):
	if event is InputEventMouseMotion:
			
		# Handle upwards movement
		cam_up = deg2rad(event.relative.y * -1)

		# Handle sideways movement
		cam_right = deg2rad(event.relative.x)
			
		# We are moving the mouse, so set this to true
		mouse_moved = true


# We use _physics_process because it will play better with KinematicBody
func _physics_process(delta):
	calculate_new_distance_if_hit()
	update_gimbal_position()
	update_camera_distance()
	rotate_gimbal(delta)
	
# This function rotates the gimbal
func rotate_gimbal(delta):
	if mouse_moved:
		self.rotate_y(-cam_right * 4 * delta)
		$XGimbal.rotate_x(cam_up * 4 * delta)
		
	var x_gimbal_rotation = $XGimbal.rotation_degrees
	x_gimbal_rotation.x = clamp(x_gimbal_rotation.x, MinClampXAngle, MaxClampXAngle)
	$XGimbal.rotation_degrees = x_gimbal_rotation
		
	mouse_moved = false

# This function updates the gimbal's position
func update_gimbal_position():
	if FollowMode == FOLLOW_MODE.SMOOTH:
		global_transform.origin = lerp(global_transform.origin, 
			follow_target.global_transform.origin + gimbal_offset, 
			CameraLerpSpeed)
	elif FollowMode == FOLLOW_MODE.INSTANT:
		global_transform.origin = follow_target.global_transform.origin + gimbal_offset

# This function updates the camera's distance
func update_camera_distance():
	
	# Check if hit the change zoom button/key
	if Input.is_action_just_released("ChangeDistance"):
		current_view_distance += 1
		
		# Cycle back
		if current_view_distance > view_distances.size() - 1:
			current_view_distance = 0
	
	# Position the camera accordingly
	MainCamera.transform.origin.z = lerp(MainCamera.transform.origin.z, 
		view_distances[current_view_distance],
		CameraLerpSpeed)
		
	# Adjust the length of the raycasts to accomodate the camera's distance
	for i in range(raycasts.size()):
		raycasts[i].set_cast_to(Vector3(0.0, 0.0, MainCamera.transform.origin.z + RaycastMargin))
		
# This function calculates if the raycast is hitting anything
func calculate_new_distance_if_hit():
	
	# Check if the raycast is hitting anything 
	for i in range(raycasts.size()):
		if raycasts[i].is_colliding():
			# Make sure we aren't in the noclip group
			if !raycasts[i].get_collider().is_in_group("noclip"):
				
				# Store the hit position
				var hit_position = raycasts[i].get_collision_point()
				
				# Measure the distance between the raycast's origin to the hit point
				var measure = raycasts[i].global_transform.origin - hit_position
				var new_distance = measure.length()
				
				# Adjust the camera's distance to the new measured distance
				if !probe_array.empty():
					MainCamera.transform.origin.z = new_distance - RaycastMargin
	
					# Cap the camera to a minimum distance, for now
					if MainCamera.transform.origin.z <= -3:
						MainCamera.transform.origin.z = -3

# This lets us know when a body has entered our CollisionProbe
func _on_CollisionProbe_body_entered(body):
	if !body.is_in_group("noclip"):
		if probe_array.find(body) == -1:
			probe_array.insert(probe_array.size(), body)
			print(probe_array)


# This lets us know when a body has exited our CollisionProbe
func _on_CollisionProbe_body_exited(body):
	if probe_array.size() != -1:
		var body_to_remove = probe_array.find(body)
		
		if body_to_remove != -1:
			probe_array.remove(body_to_remove)
			print(probe_array)
