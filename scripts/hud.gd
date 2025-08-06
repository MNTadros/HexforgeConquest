extends CanvasLayer

@export var tile_bar_scene: PackedScene

@onready var tile_bar_container = $TileBarContainer
@onready var pause_menu = $PauseMenu

func show_pause_menu(show: bool) -> void:
	pause_menu.visible = show

var tile_bars := {}

const MAX_TILE_TIME := 10.0

func update_tiles(times: Dictionary) -> void:
	for tile_name in times.keys():
		var time = times[tile_name]

		if not tile_bars.has(tile_name):
			var bar = tile_bar_scene.instantiate()
			bar.get_node("Label").text = tile_name
			bar.get_node("ProgressBar").max_value = MAX_TILE_TIME
			bar.get_node("ProgressBar").value = time
			tile_bar_container.add_child(bar)
			tile_bars[tile_name] = bar
		else:
			var bar = tile_bars[tile_name]
			bar.get_node("ProgressBar").value = time
