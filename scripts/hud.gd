extends CanvasLayer

@export var tile_bar_scene: PackedScene

@onready var tile_bar_container = $TileBarContainer
@onready var coins_tile_bar = $TileBarContainer/CoinsTileBar
@onready var pause_menu = $PauseMenu
@onready var crafting_menu = $CraftingMenu
@onready var health_bar = $PlayerUI/HealthBar
@onready var stamina_bar = $PlayerUI/StaminaBar
@onready var death_screen = $DeathScreen
@onready var respawn_timer_label = $DeathScreen/RespawnLabel
@onready var collection_popup = $PlayerUI/CollectionPopup
@onready var inventory_slots = []

func _ready():
	# Initialize inventory slots
	for i in range(1, 10):
		var slot = $PlayerUI/InventoryContainer.get_node("Slot" + str(i))
		inventory_slots.append({
			"panel": slot,
			"icon": slot.get_node("ItemIcon" + str(i)),
			"count": slot.get_node("ItemCount" + str(i)),
			"item_type": "",
			"item_count": 0
		})
	
	# Set up health bar appearance
	setup_health_bar()
	setup_stamina_bar()
	setup_inventory_slots()
	setup_death_screen()
	setup_crafting_menu()
	setup_coins_tile_bar()

func setup_health_bar():
	# Create green style for health bar
	var style_box = StyleBoxFlat.new()
	style_box.bg_color = Color(0.2, 0.8, 0.2)  # Green color
	style_box.corner_radius_top_left = 4
	style_box.corner_radius_top_right = 4
	style_box.corner_radius_bottom_right = 4
	style_box.corner_radius_bottom_left = 4
	
	health_bar.add_theme_stylebox_override("fill", style_box)
	
	# Background style
	var bg_style = StyleBoxFlat.new()
	bg_style.bg_color = Color(0.3, 0.3, 0.3, 0.8)
	bg_style.corner_radius_top_left = 4
	bg_style.corner_radius_top_right = 4
	bg_style.corner_radius_bottom_right = 4
	bg_style.corner_radius_bottom_left = 4
	
	health_bar.add_theme_stylebox_override("background", bg_style)

func setup_stamina_bar():
	# Create blue style for stamina bar
	var style_box = StyleBoxFlat.new()
	style_box.bg_color = Color(0.2, 0.6, 1.0)  # Blue color
	style_box.corner_radius_top_left = 4
	style_box.corner_radius_top_right = 4
	style_box.corner_radius_bottom_right = 4
	style_box.corner_radius_bottom_left = 4
	
	stamina_bar.add_theme_stylebox_override("fill", style_box)
	
	# Background style
	var bg_style = StyleBoxFlat.new()
	bg_style.bg_color = Color(0.3, 0.3, 0.3, 0.8)
	bg_style.corner_radius_top_left = 4
	bg_style.corner_radius_top_right = 4
	bg_style.corner_radius_bottom_right = 4
	bg_style.corner_radius_bottom_left = 4
	
	stamina_bar.add_theme_stylebox_override("background", bg_style)

func setup_death_screen():
	death_screen.visible = false

func setup_crafting_menu():
	if crafting_menu != null:
		# Get player reference - we'll need to set this up when the player is ready
		var main_scene = get_tree().current_scene
		if main_scene:
			var player = main_scene.get_node_or_null("Player")
			crafting_menu.set_references(self, player)

func setup_coins_tile_bar():
	if coins_tile_bar != null:
		# Set up the coins tile bar with golden appearance
		coins_tile_bar.setup_tile("Coins", 0, 999999)  # Max coins set to 999999
		
		# Set coins icon
		var icon_node = coins_tile_bar.get_node("HBoxContainer/Icon")
		if icon_node:
			var coins_texture = load("res://images/icons/coins_icon.png")
			icon_node.texture = coins_texture
		
		# Set golden color for the progress bar background
		var value_bg = coins_tile_bar.get_node("HBoxContainer/ValueBackground")
		if value_bg:
			var gold_style = StyleBoxFlat.new()
			gold_style.bg_color = Color(1.0, 0.84, 0.0, 0.3)  # Golden color with transparency
			gold_style.corner_radius_top_left = 6
			gold_style.corner_radius_top_right = 6
			gold_style.corner_radius_bottom_right = 6
			gold_style.corner_radius_bottom_left = 6
			value_bg.add_theme_stylebox_override("panel", gold_style)
		
		# Set golden text color
		var value_label = coins_tile_bar.get_node("HBoxContainer/ValueBackground/ValueLabel")
		if value_label:
			value_label.add_theme_color_override("font_color", Color(1.0, 0.84, 0.0))  # Golden text
		
		# Set the label text to "Coins"
		var label_node = coins_tile_bar.get_node("HBoxContainer/Label")
		if label_node:
			label_node.text = "Coins"
			label_node.add_theme_color_override("font_color", Color(1.0, 0.84, 0.0))  # Golden text

func setup_inventory_slots():
	# Style each inventory slot
	for i in range(inventory_slots.size()):
		var slot_data = inventory_slots[i]
		var style_box = StyleBoxFlat.new()
		style_box.bg_color = Color(0.2, 0.2, 0.2, 0.8)
		style_box.border_color = Color(0.5, 0.5, 0.5)
		style_box.border_width_left = 2
		style_box.border_width_right = 2
		style_box.border_width_top = 2
		style_box.border_width_bottom = 2
		style_box.corner_radius_top_left = 4
		style_box.corner_radius_top_right = 4
		style_box.corner_radius_bottom_right = 4
		style_box.corner_radius_bottom_left = 4
		
		slot_data.panel.add_theme_stylebox_override("panel", style_box)
		
		# Add slot number labels for all 9 slots
		if i < 9:
			var slot_number_label = Label.new()
			slot_number_label.text = str(i + 1)
			slot_number_label.position = Vector2(2, 2)
			slot_number_label.size = Vector2(15, 15)
			slot_number_label.add_theme_color_override("font_color", Color.WHITE)
			slot_number_label.add_theme_color_override("font_shadow_color", Color.BLACK)
			slot_number_label.add_theme_constant_override("shadow_offset_x", 1)
			slot_number_label.add_theme_constant_override("shadow_offset_y", 1)
			slot_data.panel.add_child(slot_number_label)

func show_pause_menu(show: bool) -> void:
	pause_menu.visible = show

func show_crafting_menu() -> void:
	if crafting_menu != null:
		crafting_menu.show_crafting_menu()

# Health bar functions
func update_health(current_health: float, max_health: float = 100.0) -> void:
	health_bar.max_value = max_health
	health_bar.value = current_health
	
	# Update color based on health percentage
	var health_percentage = current_health / max_health
	var color = Color.GREEN
	
	if health_percentage < 0.3:
		color = Color.RED
	elif health_percentage < 0.6:
		color = Color.YELLOW
	
	var style_box = StyleBoxFlat.new()
	style_box.bg_color = color
	style_box.corner_radius_top_left = 4
	style_box.corner_radius_top_right = 4
	style_box.corner_radius_bottom_right = 4
	style_box.corner_radius_bottom_left = 4
	
	health_bar.add_theme_stylebox_override("fill", style_box)

# Stamina bar functions
func update_stamina(current_stamina: float, max_stamina: float = 100.0) -> void:
	stamina_bar.max_value = max_stamina
	stamina_bar.value = current_stamina
	
	# Update color based on stamina percentage
	var stamina_percentage = current_stamina / max_stamina
	var color = Color(0.2, 0.6, 1.0)  # Default blue
	
	if stamina_percentage < 0.3:
		color = Color(0.8, 0.4, 0.0)  # Orange when low
	elif stamina_percentage < 0.6:
		color = Color(0.6, 0.8, 0.2)  # Yellow-green when medium
	
	var style_box = StyleBoxFlat.new()
	style_box.bg_color = color
	style_box.corner_radius_top_left = 4
	style_box.corner_radius_top_right = 4
	style_box.corner_radius_bottom_right = 4
	style_box.corner_radius_bottom_left = 4
	
	stamina_bar.add_theme_stylebox_override("fill", style_box)

# Death screen functions
func show_death_screen(show: bool, time_remaining: float = 0.0) -> void:
	death_screen.visible = show
	if show:
		respawn_timer_label.text = "Respawning in " + str(int(ceil(time_remaining))) + " seconds"

# Inventory functions
func add_item_to_inventory(item_type: String, item_icon_path: String = "", count: int = 1) -> bool:
	# First, try to stack with existing items
	for slot_data in inventory_slots:
		if slot_data.item_type == item_type and slot_data.item_count > 0:
			slot_data.item_count += count
			slot_data.count.text = str(slot_data.item_count)
			return true
	
	# If no existing stack, find empty slot
	for slot_data in inventory_slots:
		if slot_data.item_count == 0:
			slot_data.item_type = item_type
			slot_data.item_count = count
			
			# Load and set icon if path provided
			if item_icon_path != "":
				var icon_texture = load(item_icon_path) as Texture2D
				if icon_texture:
					slot_data.icon.texture = icon_texture
			
			# Update count display
			slot_data.count.text = str(count) if count > 1 else ""
			
			return true
	
	return false  # Inventory full

func remove_item_from_inventory(item_type: String, count: int = 1) -> bool:
	for slot_data in inventory_slots:
		if slot_data.item_type == item_type and slot_data.item_count >= count:
			slot_data.item_count -= count
			
			if slot_data.item_count <= 0:
				# Clear the slot
				slot_data.item_type = ""
				slot_data.item_count = 0
				slot_data.icon.texture = null
				slot_data.count.text = ""
			else:
				# Update count display
				slot_data.count.text = str(slot_data.item_count) if slot_data.item_count > 1 else ""
			
			return true
	
	return false  # Item not found or insufficient quantity

func get_item_count(item_type: String) -> int:
	var total_count = 0
	for slot_data in inventory_slots:
		if slot_data.item_type == item_type:
			total_count += slot_data.item_count
	return total_count

func clear_inventory() -> void:
	for slot_data in inventory_slots:
		slot_data.item_type = ""
		slot_data.item_count = 0
		slot_data.icon.texture = null
		slot_data.count.text = ""

# Collection popup functions
var popup_tween: Tween

func show_collection_popup(message: String, color: Color = Color.WHITE) -> void:
	if collection_popup == null:
		return
	
	# Kill any existing tween to prevent conflicts
	if popup_tween:
		popup_tween.kill()
	
	# Reset popup state
	collection_popup.modulate = Color.WHITE
	collection_popup.text = message
	collection_popup.add_theme_color_override("font_color", color)
	collection_popup.add_theme_color_override("font_shadow_color", Color.BLACK)
	collection_popup.add_theme_constant_override("shadow_offset_x", 2)
	collection_popup.add_theme_constant_override("shadow_offset_y", 2)
	collection_popup.visible = true
	
	# Create a new tween to fade out the popup
	popup_tween = create_tween()
	popup_tween.parallel().tween_property(collection_popup, "modulate:a", 1.0, 0.0)
	popup_tween.parallel().tween_property(collection_popup, "modulate:a", 0.0, 1.5)
	popup_tween.tween_callback(func(): collection_popup.visible = false)

var tile_bars := {}

const MAX_TILE_TIME := 100.0

# Tiles that shouldn't show progress bars
const TILES_WITHOUT_BARS := ["HexTile_BlacksmithBuilding"]

func update_tiles(times: Dictionary) -> void:
	# Ensure nodes are ready before proceeding
	if tile_bar_container == null:
		tile_bar_container = get_node_or_null("TileBarContainer")
		if tile_bar_container == null:
			return
	
	for tile_name in times.keys():
		var time = times[tile_name]
		
		# Skip creating tile bars for certain tiles
		if tile_name in TILES_WITHOUT_BARS:
			continue

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
