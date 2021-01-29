extends Spatial

# Based on: https://github.com/beneater/boids/blob/master/boids.js

onready var boid_scene = preload("res://Boid3D.tscn")

export var window_width = 24.0
export var window_height = 24.0
export var forward_depth = 16.0

export(int, 0, 1000) var numBoids = 20 # Number of boids spawned at the start (it should be adjustable dynamically).
export(float, 0.0, 9999.0) var visualRange = 20 # Visual range of the boids. Will determine who is a neighbour.

# keepWithinBounds
export(float, 0.0, 9999.0) var keepWithinBoundsMargin = 40 # keepWithinBoundskeepWithinBoundsMargin for out of bounds area.
export(float, -999.0, 999.0) var keepWithinBoundsFactor = 0.1 # Constant to adjust keepWithinBounds weight. Usually higher than anything else.

# flyTowardsCenter
export(float, -999.0, 999.0) var flyTowardsCenterFactor = 0.005; # Weight for flyTowardsCenter behaviour.

# avoidOthers
export(float, 0, 9999.0) var avoidOthersMinDistance = 1 # The distance to stay away from other boids.
export(float, -999.0, 999.0) var avoidOthersFactor = 0.05 # The rate at which boids correct their position.

# matchVelocity
export(float, -999.0, 999.0) var matchVelocityFactor = 0.05 # Boids adjust their velocity to match others at this rate.

# limitSpeed
export(float, 0, 9999.0) var speedLimit = 5 # Maximum speed of a boid.

# flyTowardsMouse
export(float, -999.0, 999.0) var flyTowardsMouseFactor = 0.005; # adjust velocity by this % # CONST?
export(float, 0, 9999.0) var flyTowardsMouseVisualRange = 200

# avoidMouse
export(float, 0, 9999.0) var avoidMouseMinDistance = 100 # The distance to stay away from other boids # CONST?
export(float, -999.0, 999.0) var avoidMouseFactor = 0.05 # Adjust velocity by this % # CONST?

export(bool) var trailEnabled = false
export(Color) var trailColor = Color(1.0, 0.0, 0.0, 1.0)
export(float) var trailWidth = 1.0
export var trailMaterial : Material
export(int, 0, 1000) var boidHistoryLength = 20 # Also trail length

var boids = []


func _ready():
	for i in range(numBoids):
		var new_boid = boid_scene.instance()
		add_child(new_boid) # This needs to be done first because boids call get_parent on initBoid()
		boids.push_back(new_boid.initBoid(window_width, window_height, forward_depth, trailEnabled, trailColor, trailWidth, trailMaterial, boidHistoryLength))

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	for boid in boids:
		# Update the velocities according to each rule
		flyTowardsCenter(boid)
		avoidOthers(boid)
		matchVelocity(boid)
		limitSpeed(boid)
		keepWithinBounds(boid)
		
		#Update the position based on the current velocity
		boid.x += boid.dx;
		boid.y += boid.dy;
		boid.z += boid.dz;
		boid.history.push_back([boid.x, boid.y, boid.z])
		if(boid.history.size() > 50): # This will probably give me some issues.
			boid.history.pop_front() # This will probably give me some issues.
		
		drawBoid(boid)


# Constrain a boid to within the window. If it gets too close to an edge,
# nudge it back in and reverse its direction.
func keepWithinBounds(boid : Boid3D):
	if (boid.x < keepWithinBoundsMargin):
		boid.dx += keepWithinBoundsFactor
	
	if (boid.x > window_width - keepWithinBoundsMargin):
		boid.dx -= keepWithinBoundsFactor
	
	if (boid.y < keepWithinBoundsMargin):
		boid.dy += keepWithinBoundsFactor
	
	if (boid.y > window_height - keepWithinBoundsMargin):
		boid.dy -= keepWithinBoundsFactor
	
	if (boid.z < keepWithinBoundsMargin):
		boid.dz += keepWithinBoundsFactor
	
	if (boid.z > forward_depth - keepWithinBoundsMargin):
		boid.dz -= keepWithinBoundsFactor


# Find the center of mass of the other boids and adjust velocity slightly to
# point towards the center of mass.
func flyTowardsCenter(boid : Boid3D):
	var boidPosition = Vector3(boid.x, boid.y, boid.z)
	var centerX = 0;
	var centerY = 0;
	var centerZ = 0;
	var numNeighbors = 0;
	
	for otherBoid in boids:
		var otherBoidPosition = Vector3(otherBoid.x, otherBoid.y, otherBoid.z)
		if(boidPosition.distance_to(otherBoidPosition) < visualRange):
			centerX += otherBoid.x
			centerY += otherBoid.y
			centerZ += otherBoid.z
			numNeighbors += 1
	
	if(numNeighbors >= 0):
		centerX = centerX / numNeighbors
		centerY = centerY / numNeighbors
		centerZ = centerZ / numNeighbors
		boid.dx += (centerX - boid.x) * flyTowardsCenterFactor
		boid.dy += (centerY - boid.y) * flyTowardsCenterFactor
		boid.dz += (centerZ - boid.z) * flyTowardsCenterFactor


# Move away from other boids that are too close to avoid colliding
func avoidOthers(boid : Boid3D):
	var boidPosition = Vector3(boid.x, boid.y, boid.z)
	var moveX = 0
	var moveY = 0
	var moveZ = 0
	
	for otherBoid in boids:
		var otherBoidPosition = Vector3(otherBoid.x, otherBoid.y, otherBoid.z)
		if(otherBoid != boid): # Is it really different as in javascript?
			if(boidPosition.distance_to(otherBoidPosition) < avoidOthersMinDistance):
				moveX += boid.x - otherBoid.x;
				moveY += boid.y - otherBoid.y;
				moveZ += boid.z - otherBoid.z;
	
	boid.dx += moveX * avoidOthersFactor
	boid.dy += moveY * avoidOthersFactor
	boid.dz += moveZ * avoidOthersFactor

# Find the average velocity (speed and direction) of the other boids and
# adjust velocity slightly to match.
func matchVelocity(boid : Boid3D):
	var boidPosition = Vector3(boid.x, boid.y, boid.z)
	var avgDX = 0
	var avgDY = 0
	var avgDZ = 0
	var numNeighbors = 0
	
	for otherBoid in boids:
		var otherBoidPosition = Vector3(otherBoid.x, otherBoid.y, otherBoid.z)
		if(boidPosition.distance_to(otherBoidPosition) < visualRange):
			avgDX += otherBoid.dx
			avgDY += otherBoid.dy
			avgDZ += otherBoid.dz
			numNeighbors += 1
	
	if(numNeighbors >= 0):
		avgDX = avgDX / numNeighbors
		avgDY = avgDY / numNeighbors
		avgDZ = avgDZ / numNeighbors
		
		boid.dx += (avgDX - boid.dx) * matchVelocityFactor
		boid.dy += (avgDY - boid.dy) * matchVelocityFactor
		boid.dz += (avgDZ - boid.dz) * matchVelocityFactor

# Speed will naturally vary in flocking behavior, but real animals can't go
# arbitrarily fast.
func limitSpeed(boid : Boid3D):
	var speed = pow(boid.dx * boid.dx + boid.dy * boid.dy + boid.dz * boid.dz, 1.0/3.0) # CONST?
	
	if(speed > speedLimit):
		boid.dx = (boid.dx / speed) * speedLimit
		boid.dy = (boid.dy / speed) * speedLimit
		boid.dz = (boid.dz / speed) * speedLimit

func drawBoid(boid : Boid3D):
	boid.translation = Vector3(boid.x, boid.y, boid.z)
	var target = Vector3(-boid.dx, -boid.dy, -boid.dz)*100.0
	boid.look_at(target, Vector3.UP)
