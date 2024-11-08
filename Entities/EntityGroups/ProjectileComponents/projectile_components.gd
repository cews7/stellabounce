extends Node2D

signal out_of_projectiles

@onready var projectiles: Array[RigidBody2D] = []
@onready var sling: Node2D = $Slingshot
@onready var pull_line: Line2D = $PullLine
@onready var trajectory_line: PackedScene = preload("res://Entities/Projectiles/trajectory_line.tscn")

var trajectory_line_instance: Line2D
var active_projectile: RigidBody2D = null
var dragging = false
var max_drag_distance = 100
var launch_power_multiplier = 2.0  # Replace the hardcoded *2 with this

var current_drag_direction := Vector2.ZERO
var current_drag_power := 0.0

func _ready():
    out_of_projectiles.connect(get_parent()._on_projectile_components_empty)
    pull_line.hide()
    for projectile in projectiles:
        projectile.freeze = true
    trajectory_line_instance = trajectory_line.instantiate()
    add_child(trajectory_line_instance)

    # Create a gradient for the trajectory line
    var gradient = Gradient.new()
    gradient.colors = [Color(1, 1, 1, 1), Color(1, 1, 1, 0.2)]  # Solid white to transparent white
    trajectory_line_instance.width = 5.0
    trajectory_line_instance.gradient = gradient
    trajectory_line_instance.z_index = 1000
    trajectory_line_instance.show()

    # Add test points in world space
    trajectory_line_instance.clear_points()
    trajectory_line_instance.add_point(sling.global_position)  # Start at sling
    trajectory_line_instance.add_point(sling.global_position + Vector2(100, -100))  # Up and right
    trajectory_line_instance.add_point(sling.global_position + Vector2(200, 0))  # Back to original height

func _process(_delta):
    if dragging and active_projectile:
        var mouse_position = get_global_mouse_position()
        var drag_vector = sling.global_position - mouse_position
        drag_vector = drag_vector.limit_length(max_drag_distance)
        active_projectile.global_position = sling.global_position - drag_vector
        update_pull_line(mouse_position)

        # Calculate launch velocity to match actual launch
        var launch_vector = sling.global_position - active_projectile.global_position
        var launch_power = launch_vector.length() * launch_power_multiplier
        var launch_velocity = launch_vector.normalized() * launch_power

        trajectory_line_instance.update_trajectory(active_projectile.global_position, launch_velocity)
        trajectory_line_instance.show()
    else:
        trajectory_line_instance.hide()

func handle_mouse_release():
    if dragging:
        launch_projectile()
    dragging = false
    active_projectile = null
    pull_line.hide()
    trajectory_line_instance.hide()

func _unhandled_input(event):
    if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
        if event.pressed:
            handle_mouse_press()
        elif event.is_released():
            handle_mouse_release()

func remove_projectile(projectile: RigidBody2D):
    projectiles.erase(projectile)
    if projectiles.size() == 0:
        out_of_projectiles.emit()

func add_projectile(projectile: RigidBody2D):
    projectiles.append(projectile)
    projectile.freeze = true

    # Calculate position for the new projectile
    var spacing = 32  # Adjust this value to control space between projectiles
    var start_x = sling.global_position.x - spacing
    var index = projectiles.size() - 1
    projectile.global_position = Vector2(start_x - (spacing * index), sling.global_position.y + 110)

func handle_mouse_press():
    var mouse_position = get_global_mouse_position()

    for projectile in projectiles:
        if projectile.freeze:  # Only consider frozen (unused) projectiles
            var shape = projectile.get_node("CollisionShape2D").shape
            var local_mouse_position = projectile.to_local(mouse_position)

            if shape.get_class() == "CircleShape2D":
                if local_mouse_position.length() <= shape.radius:
                    start_dragging(projectile)
                    return
            elif shape.get_class() == "RectangleShape2D":
                if abs(local_mouse_position.x) <= shape.size.x / 2 and abs(local_mouse_position.y) <= shape.size.y / 2:
                    start_dragging(projectile)
                    return

func start_dragging(projectile: RigidBody2D):
    active_projectile = projectile
    dragging = true
    active_projectile.global_position = sling.global_position
    pull_line.show()  # Show the line when dragging starts
    update_pull_line(sling.global_position)  # Initialize the line

func update_pull_line(end_position: Vector2):
    pull_line.clear_points()

    # Convert sling position to pull_line's local coordinates
    var local_sling_pos = pull_line.to_local(sling.global_position)
    pull_line.add_point(local_sling_pos)

    var drag_vector = sling.global_position - end_position
    drag_vector = drag_vector.limit_length(max_drag_distance)
    var end_point = pull_line.to_local(sling.global_position - drag_vector)

    pull_line.add_point(end_point)

func launch_projectile():
    if active_projectile:
        var launch_vector = sling.global_position - active_projectile.global_position
        active_projectile.freeze = false
        var launch_power = launch_vector.length() * launch_power_multiplier
        active_projectile.launch(launch_vector.normalized(), launch_power)

        # Reset the projectile's position to the sling position before launch
        active_projectile.global_position = sling.global_position

