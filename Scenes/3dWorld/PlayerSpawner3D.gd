extends MultiplayerSpawner
class_name PlayerSpawner3D

const PlayerScene := preload("res://Scenes/3dWorld/Player3D.tscn")

func _ready():
    spawn_function = _spawn_player_custom
    
func _spawn_player_custom(data: Variant) -> Node:
    var peer_id = data as int
    print("Custom spawning player:", peer_id)
    
    var p = PlayerScene.instantiate()
    p.name = "Player_%d" % peer_id
    p.peer_id = peer_id
    p.position = Vector3.ZERO
    
    p.set_multiplayer_authority(peer_id)	
    p.get_node("MultiplayerSynchronizer").set_multiplayer_authority(1)
    
    PlayerManager.players[peer_id] = p
    return p
