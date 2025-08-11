extends Control

@onready var recipe_container = $CraftingPanel/VBoxContainer/MainContainer/RecipeList/RecipeScrollContainer/RecipeContainer
@onready var selected_recipe_label = $CraftingPanel/VBoxContainer/MainContainer/CraftingArea/SelectedRecipeLabel
@onready var requirements_list = $CraftingPanel/VBoxContainer/MainContainer/CraftingArea/RequirementsContainer/RequirementsScrollContainer/RequirementsList
@onready var craft_button = $CraftingPanel/VBoxContainer/MainContainer/CraftingArea/CraftButton
@onready var close_button = $CraftingPanel/VBoxContainer/ButtonContainer/CloseButton

var hud = null
var player = null
var selected_recipe = null

# Crafting recipes - each recipe has name, requirements, and result
# Using "Item" versions to separate from tile bar currency
var recipes = {
	"Basic Bow": {
		"description": "A simple wooden bow for hunting",
		"requirements": {"Plains Item": 2, "Grass Item": 1},
		"result": {"item": "Basic Bow", "count": 1, "icon": "res://images/icons/bow_icon.png"}
	},
	"Wooden Arrow": {
		"description": "Basic arrows for your bow", 
		"requirements": {"Grass Item": 2},
		"result": {"item": "Wooden Arrow", "count": 5, "icon": "res://images/icons/arrow_icon.png"}
	},
	"Hunting Knife": {
		"description": "A sharp knife for cutting and hunting",
		"requirements": {"Plains Item": 1, "Water Item": 1},
		"result": {"item": "Hunting Knife", "count": 1, "icon": "res://images/icons/knife_icon.png"}
	},
	"Health Potion": {
		"description": "Restores 50 health when consumed",
		"requirements": {"Water Item": 2, "Grass Item": 1},
		"result": {"item": "Health Potion", "count": 1, "icon": "res://images/icons/health_potion_icon.png"}
	},
	"Stamina Elixir": {
		"description": "Restores 75 stamina when consumed", 
		"requirements": {"Wheat Item": 2, "Water Item": 1},
		"result": {"item": "Stamina Elixir", "count": 1, "icon": "res://images/icons/stamina_potion_icon.png"}
	},
	"Iron Sword": {
		"description": "A strong iron sword for combat",
		"requirements": {"Iron": 3, "Plains Item": 1},
		"result": {"item": "Iron Sword", "count": 1, "icon": "res://images/icons/sword_icon.png"}
	}
}

func _ready():
	setup_recipes()
	craft_button.pressed.connect(_on_craft_button_pressed)
	close_button.pressed.connect(_on_close_button_pressed)
	
	# Connect background click to close menu
	$Background.gui_input.connect(_on_background_input)

func _input(event):
	if not visible:
		return
		
	if event.is_action_pressed("ui_cancel"):
		hide_crafting_menu()
		get_viewport().set_input_as_handled()  # Prevent further processing

func setup_recipes():
	# Clear existing recipe buttons
	for child in recipe_container.get_children():
		child.queue_free()
	
	# Create recipe buttons
	for recipe_name in recipes.keys():
		var recipe_button = Button.new()
		recipe_button.text = recipe_name
		recipe_button.custom_minimum_size.y = 35
		recipe_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		recipe_button.pressed.connect(_on_recipe_selected.bind(recipe_name))
		recipe_container.add_child(recipe_button)

func _on_recipe_selected(recipe_name: String):
	selected_recipe = recipe_name
	var recipe = recipes[recipe_name]
	
	selected_recipe_label.text = recipe_name + "\n" + recipe.description
	
	# Clear and update requirements
	for child in requirements_list.get_children():
		child.queue_free()
	
	# Wait for children to be freed
	await get_tree().process_frame
	
	var can_craft = true
	for item_name in recipe.requirements.keys():
		var required_count = recipe.requirements[item_name]
		var available_count = 0
		
		if hud != null:
			available_count = hud.get_item_count(item_name)
		
		var requirement_label = Label.new()
		requirement_label.custom_minimum_size.y = 22
		requirement_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		requirement_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		requirement_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		
		var status_text = ""
		var label_color = Color.WHITE
		if available_count >= required_count:
			label_color = Color.GREEN
			status_text = "✓ "
		else:
			label_color = Color.RED
			status_text = "✗ "
			can_craft = false
		
		requirement_label.text = status_text + item_name + ": " + str(available_count) + "/" + str(required_count)
		requirement_label.add_theme_color_override("font_color", label_color)
		requirements_list.add_child(requirement_label)
	
	craft_button.disabled = not can_craft

func _on_craft_button_pressed():
	if selected_recipe == null or hud == null:
		return
	
	var recipe = recipes[selected_recipe]
	
	# Check if we still have all requirements
	var can_craft = true
	for item_name in recipe.requirements.keys():
		var required_count = recipe.requirements[item_name]
		var available_count = hud.get_item_count(item_name)
		if available_count < required_count:
			can_craft = false
			break
	
	if not can_craft:
		if hud.has_method("show_collection_popup"):
			hud.show_collection_popup("Not enough materials!", Color.RED)
		return
	
	# Remove required materials
	for item_name in recipe.requirements.keys():
		var required_count = recipe.requirements[item_name]
		hud.remove_item_from_inventory(item_name, required_count)
	
	# Add crafted item
	var result = recipe.result
	var success = hud.add_item_to_inventory(result.item, result.icon, result.count)
	
	if success:
		if hud.has_method("show_collection_popup"):
			hud.show_collection_popup("Crafted " + result.item + "!", Color.GREEN)
	else:
		if hud.has_method("show_collection_popup"):
			hud.show_collection_popup("Inventory full!", Color.RED)
		# Return materials if inventory is full
		for item_name in recipe.requirements.keys():
			var required_count = recipe.requirements[item_name]
			# Try to return materials (this might not work if inventory is truly full)
			hud.add_item_to_inventory(item_name, "", required_count)
	
	# Refresh the selected recipe to update requirements display
	_on_recipe_selected(selected_recipe)

func _on_close_button_pressed():
	hide_crafting_menu()

func _on_background_input(event):
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		hide_crafting_menu()

func show_crafting_menu():
	visible = true
	# Set mouse to visible mode for UI interaction
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	print("Crafting menu shown")

func hide_crafting_menu():
	visible = false
	# Return mouse to captured mode for player control
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	print("Crafting menu hidden")

func set_references(hud_ref, player_ref):
	hud = hud_ref
	player = player_ref
