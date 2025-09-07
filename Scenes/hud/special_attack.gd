extends Button

var cooldown_seconds := 1.0
var veil_color := Color(0, 0, 0, 0.45)  # shade over the button during cooldown
@onready var veil := $"Cooldown"
@onready var hud: HUD = $"../../.."

var ice_barrage_anim_scene: PackedScene = preload("res://Scenes/animations/icicle_barrage/icycle_barrage_animation.tscn")

func _ready() -> void:
    # press feedback: quick lighten while held
    button_down.connect(func(): self_modulate = Color(1.08, 1.08, 1.08))
    button_up.connect(func(): self_modulate = Color(1, 1, 1))

    pressed.connect(_trigger_cooldown)

    # minimal shader for a top→bottom wipe controlled by "cd" in [0..1]
    var sh := Shader.new()
    sh.code = """
        shader_type canvas_item;
        uniform float cd = 0.0;                  // 1 = fully covered, 0 = uncovered
        uniform vec4 veil = vec4(0.0,0.0,0.0,0.45);
        void fragment() {
            float cover = step(1.0 - UV.y, clamp(cd, 0.0, 1.0));
            COLOR = mix(vec4(0.0), veil, cover);
        }
    """
    veil.material = ShaderMaterial.new()
    veil.material.shader = sh
    veil.material.set_shader_parameter("veil", veil_color)
    veil.visible = false

func _trigger_cooldown() -> void:
    if disabled: return

    var anim: AnimatedSprite3D = ice_barrage_anim_scene.instantiate()
    hud.player.add_child(anim)
    anim.play()
    anim.animation_finished.connect(func(): anim.queue_free())

    activate_special.rpc_id(1)

    disabled = true
    veil.visible = true
    veil.material.set_shader_parameter("cd", 1.0)

    var t := create_tween().set_trans(Tween.TRANS_LINEAR).set_ease(Tween.EASE_IN_OUT)
    t.tween_property(veil.material, "shader_parameter/cd", 0.0, cooldown_seconds)
    t.finished.connect(func():
        veil.visible = false
        disabled = false
    )

@rpc("reliable", "call_local", "any_peer")
func activate_special():
    assert(multiplayer.is_server())
    # Todo - check they have enough Mana
    # LOOK AT MY MANA, WHAT DO YOU WANT ME TO DO?
    var player: Player3D = PlayerManager.players[multiplayer.get_remote_sender_id()].player
    var spawner: BulletSpawner = get_tree().get_first_node_in_group("bullet_spawner")
    for mob: MobNode in player.mobs_in_range:
        # Shoot at all of them mwaha
        var dir: Vector3 = (mob.global_position - player.global_position).normalized()
        dir.y = 0
        spawner.spawn_bullet(
            BulletData.new(
                5, # damage
                10, # speed
                "tier_3_bullet.png",
                player.global_position,
                dir,
                Yeet.MOB_LAYER
            )
        )
