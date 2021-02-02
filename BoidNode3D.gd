extends Spatial

var timer

# Called when the node enters the scene tree for the first time.
func _ready():
	timer = Timer.new()
	timer.connect("timeout", $BoidNode3D, "OnDebugTimerTimeout")
	add_child(timer)
	timer.start(1.0)
