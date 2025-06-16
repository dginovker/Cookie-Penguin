extends Control
class_name InventoryManager

@onready var gear_container: GearContainer = $GearVBoxContainer
@onready var backpack_container: BackpackContainer = $BackpackVBoxContainer  
@onready var loot_container: LootContainer = $LootVBoxContainer

func _ready():
    # Add containers to appropriate groups
    # TODO - Change this to asserting that it's in a group so we don't get silent failures...
    gear_container.add_to_group("gear_containers")
    backpack_container.add_to_group("backpack_containers")
    loot_container.add_to_group("loot_containers")
    
    # Hide loot initially
    hide_loot_bag()

func show_loot_bag(loot_items: Array):
    loot_container.show_loot_items(loot_items)

func hide_loot_bag():
    loot_container.hide_loot_items()
