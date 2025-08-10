extends CanvasLayer

@export var tile_bar_scene: PackedScene

@onready var tile_bar_container = $TileBarContainer
@onready var pause_menu = $PauseMenu

func show_pause_menu(show: bool) -> void:
	pause_menu.visible = show

var tile_bars := {}

const MAX_TILE_TIME := 100.0

func update_tiles(times: Dictionary) -> void:
	# Ensure nodes are ready before proceeding
	if tile_bar_container == null:
		tile_bar_container = get_node_or_null("TileBarContainer")
		if tile_bar_container == null:
			return
	
	for tile_name in times.keys():
		var time = times[tile_name]

		if not tile_bars.has(tile_name):
			var bar = tile_bar_scene.instantiate()
			
			tile_bar_container.add_child(bar)
			tile_bars[tile_name] = bar
			
			# Wait one frame to ensure the node is fully in the scene tree
			await get_tree().process_frame
			
			bar.setup_tile(tile_name, time, MAX_TILE_TIME)
			bar.set_progress_bar_color(tile_name)
		else:
			var bar = tile_bars[tile_name]
			bar.update_progress(time)
