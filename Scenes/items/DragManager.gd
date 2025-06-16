# DragManager.gd - Autoload Singleton
extends Node

var dragging_item: Dictionary = {}
var drag_visual: TextureButton = null

func _input(event: InputEvent):
    # Handle mouse release globally when dragging
    if dragging_item and event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and not event.pressed:
        finish_drag_global()

func start_drag(item_data: Dictionary, from_container: BaseContainer, from_slot: int):
    if dragging_item:
        return  # Already dragging something
    
    dragging_item = {
        "item_data": item_data,
        "from_container": from_container,
        "from_slot": from_slot
    }
    
    # Create visual drag element
    create_drag_visual(item_data)

func create_drag_visual(item_data: Dictionary):
    drag_visual = TextureButton.new()
    drag_visual.texture_normal = ItemRegistry.get_texture(item_data.item_name)
    drag_visual.custom_minimum_size = Vector2(40, 40)
    drag_visual.z_index = 1000
    drag_visual.mouse_filter = Control.MOUSE_FILTER_IGNORE
    
    var hud = get_tree().get_first_node_in_group("hud")
    hud.add_child(drag_visual)

func finish_drag_global():
    if not dragging_item:
        return
    
    var from_container = dragging_item.from_container
    var from_slot = dragging_item.from_slot
    var item_data = dragging_item.item_data
    
    # Find what container/slot we're hovering over (if any)
    var target_container = null
    var target_slot = -1
    
    for container: BaseContainer in get_all_containers():
        for i in range(container.slots.size()):
            var slot = container.slots[i]
            if slot.is_hovered():
                target_container = container
                target_slot = i
                break
        if target_container:
            break
    
    # Check if dropped on valid target
    if target_container and target_container.can_accept_item(ItemRegistry.get_item_data(item_data.item_name), target_slot):
        # Valid drop - send to ItemManager for server validation
        var item_manager = get_tree().get_first_node_in_group("item_manager")
        item_manager.request_item_move.rpc_id(1, from_container.get_path(), from_slot, target_container.get_path(), target_slot, item_data)
    else:
        # Check if dropped outside any container (drop to world)
        var mouse_pos = get_viewport().get_mouse_position()
        var dropped_outside = true
        
        # Check if mouse is over any container
        for container in get_all_containers():
            var container_rect = Rect2(container.global_position, container.size)
            if container_rect.has_point(mouse_pos):
                dropped_outside = false
                break
        
        if dropped_outside:
            # Drop to world
            var item_manager = get_tree().get_first_node_in_group("item_manager")
            item_manager.request_drop_to_world.rpc_id(1, from_container.get_path(), from_slot, item_data)
            print("Dropped to world!")
        else:
            print("Invalid drop - staying in place")
    
    cleanup_drag()

func cleanup_drag():
    if drag_visual:
        drag_visual.queue_free()
        drag_visual = null
    dragging_item = {}

func _process(_delta):
    if drag_visual:
        drag_visual.global_position = get_viewport().get_mouse_position() - Vector2(20, 20)

func get_all_containers() -> Array:
    var all_nodes = []
    all_nodes.append_array(get_tree().get_nodes_in_group("backpack_containers"))
    all_nodes.append_array(get_tree().get_nodes_in_group("gear_containers"))  
    all_nodes.append_array(get_tree().get_nodes_in_group("loot_containers"))
    
    for node in all_nodes:
        assert(node is BaseContainer, "" + str(node) + "is not a BaseContainer")
    return all_nodes
