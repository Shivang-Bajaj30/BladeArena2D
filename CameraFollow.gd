extends Camera2D

@export var target_path: NodePath = NodePath("../Player")
@export var follow_vertical: bool = false

var target: Node2D
var fixed_y: float

func _ready() -> void:
	target = get_node_or_null(target_path) as Node2D
	fixed_y = global_position.y
	if target:
		global_position.x = target.global_position.x
		if follow_vertical:
			global_position.y = target.global_position.y
	reset_smoothing()

func _physics_process(_delta: float) -> void:
	if not is_instance_valid(target):
		return
	global_position.x = target.global_position.x
	global_position.y = target.global_position.y if follow_vertical else fixed_y
