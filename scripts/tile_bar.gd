extends Panel
class_name TileBar

@onready var icon: TextureRect = $HBoxContainer/Icon
@onready var label: Label = $HBoxContainer/Label
@onready var value_label: Label = $HBoxContainer/ValueBackground/ValueLabel
@onready var value_background: Panel = $HBoxContainer/ValueBackground

var tile_display_data = {
	"HexTile_Grass": {
		"display_name": "Grass",
		"icon_path": "res://images/icons/grass_icon.png",
		"increment_rate": 1.0  
	},
	"HexTile_Plains": {
		"display_name": "Plains",
		"icon_path": "res://images/icons/plains_icon.png",
		"increment_rate": 1.5  
	},
	"HexTile_Wheat": {
		"display_name": "Wheat",
		"icon_path": "res://images/icons/wheat_icon.png",
		"increment_rate": 2.0  
	},
	"HexTile_Water": {
		"display_name": "Water",
		"icon_path": "res://images/icons/water_icon.png",
		"increment_rate": 0.5  
	}
}

var current_tile_type: String = ""
var accumulated_value: float = 0.0

# Set up the tile bar with tile type, current value, and max value
func setup_tile(tile_type: String, current_value: float, max_value: float):
	current_tile_type = tile_type
	accumulated_value = 0.0
	
	# Set initial value display
	value_label.text = str(int(accumulated_value))
	
	# Check if we have custom display data for this tile type
	if tile_display_data.has(tile_type):
		var display_data = tile_display_data[tile_type]
		
		# Set custom display name
		label.text = display_data.display_name
		
		# Load and set icon
		var icon_texture = load(display_data.icon_path) as Texture2D
		if icon_texture:
			icon.texture = icon_texture
		else:
			icon.visible = false

func update_progress(current_time: float):
	if tile_display_data.has(current_tile_type):
		var increment_rate = tile_display_data[current_tile_type].increment_rate
		accumulated_value = current_time * increment_rate
		value_label.text = str(int(accumulated_value))

func add_tile_display_data(tile_type: String, display_name: String, icon_path: String, increment_rate: float = 1.0):
	tile_display_data[tile_type] = {
		"display_name": display_name,
		"icon_path": icon_path,
		"increment_rate": increment_rate
	}

func get_current_value() -> float:
	return accumulated_value

# Set custom colors for the value label and background based on tile type
func set_progress_bar_color(tile_type: String):
	var color_map = {
		"HexTile_Grass": Color(0.3, 0.8, 0.3),
		"HexTile_Plains": Color(0.8, 0.8, 0.3),
		"HexTile_Wheat": Color(0.9, 0.7, 0.2),
		"HexTile_Water": Color(0.2, 0.4, 0.9)
	}
	
	if color_map.has(tile_type):
		var base_color = color_map[tile_type]
		value_label.modulate = base_color
		
		# Create transparent background version
		var bg_color = base_color
		bg_color.a = 0.3  # Make it 30% transparent
		
		var style_box = StyleBoxFlat.new()
		style_box.bg_color = bg_color
		style_box.corner_radius_top_left = 6
		style_box.corner_radius_top_right = 6
		style_box.corner_radius_bottom_right = 6
		style_box.corner_radius_bottom_left = 6
		
		value_background.add_theme_stylebox_override("panel", style_box)
