"""
Useful for debugging the un-debuggables, like:
* on_despawn_receive: Condition "!pinfo.recv_nodes.has(net_id)" is true. Returning: ERR_UNAUTHORIZED
"""
# ReplicationProbe.gd — activate after the client is actually connected
extends Node

var disabled: bool = true

func _ready():
    if disabled:
        return
    multiplayer.connected_to_server.connect(_activate)
    if multiplayer.has_multiplayer_peer() and not multiplayer.is_server(): _activate()

func _activate():
    get_tree().node_added.connect(func(n):
        if n is MultiplayerSpawner:
            n.despawned.connect(func(x):
                print("[DESPAWN] name=", x.name, " id=", x.get_instance_id(),
                      " last_path=", x.get_meta("last_path", NodePath("<unset>")),
                      " class=", x.get_class(), " auth=", x.get_multiplayer_authority()))
        call_deferred("_tag", n)  # snapshot after it’s in-tree
        n.renamed.connect(func(): n.set_meta("last_path", n.get_path()))
        n.tree_exiting.connect(func():
            print("[EXIT_TREE] ", n.get_meta("last_path", NodePath("<unset>")),
                  " class=", n.get_class(), " auth=", n.get_multiplayer_authority()))
    )
    _scan(get_tree().root)

func _scan(n):
    if n is MultiplayerSpawner:
        n.despawned.connect(func(x):
            print("[DESPAWN] name=", x.name, " id=", x.get_instance_id(),
                  " last_path=", x.get_meta("last_path", NodePath("<unset>")),
                  " class=", x.get_class(), " auth=", x.get_multiplayer_authority()))
    call_deferred("_tag", n)
    n.renamed.connect(func(): n.set_meta("last_path", n.get_path()))
    n.tree_exiting.connect(func():
        print("[EXIT_TREE] ", n.get_meta("last_path", NodePath("<unset>")),
              " class=", n.get_class(), " auth=", n.get_multiplayer_authority()))
    for c in n.get_children(): _scan(c)

func _tag(n): n.set_meta("last_path", n.get_path())
