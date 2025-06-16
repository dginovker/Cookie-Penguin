extends Control
class_name InventoryManager

@onready var gear_container: GearContainer = $GearVBoxContainer
@onready var inventory_container: InventoryContainer = $BackpackVBoxContainer  
@onready var loot_container: LootContainer = $LootVBoxContainer

func _ready():
    # Add containers to appropriate groups
    gear_container.add_to_group("gear_containers")
    inventory_container.add_to_group("inventory_containers")
    loot_container.add_to_group("loot_containers")
    
    # Hide loot initially
    hide_loot_bag()

func show_loot_bag(loot_items: Array):
    loot_container.show_loot_items(loot_items)

func hide_loot_bag():
    loot_container.hide_loot_items()
