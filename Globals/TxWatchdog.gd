# TxSweep.gd (Godot 4.5) — aggressive sweeper + logs for Web
extends Node

const ignoreGroup: StringName = &"txwatch_ignore"
const batchPerFrame: int = 20000 # crank up; you want one-frame coverage while reproducing

var nodes: Array[Node3D] = []
var multimeshes: Array[MultiMeshInstance3D] = []
var skeletons: Array[Skeleton3D] = []
var iN: int = 0
var iM: int = 0
var iS: int = 0

static func is_f(x: float) -> bool:
    return x == x and x < INF and x > -INF

static func is_f_v(v: Vector3) -> bool:
    return is_f(v.x) and is_f(v.y) and is_f(v.z)

static func is_f_b(b: Basis) -> bool:
    return is_f_v(b.x) and is_f_v(b.y) and is_f_v(b.z)

static func dump_t(prefix: String, t: Transform3D) -> String:
    return str(prefix,
        "\n  origin: (", t.origin.x, ", ", t.origin.y, ", ", t.origin.z, ")",
        "\n  basis.x: (", t.basis.x.x, ", ", t.basis.x.y, ", ", t.basis.x.z, ")",
        "\n  basis.y: (", t.basis.y.x, ", ", t.basis.y.y, ", ", t.basis.y.z, ")",
        "\n  basis.z: (", t.basis.z.x, ", ", t.basis.z.y, ", ", t.basis.z.z, ")",
        "\n  det: ", t.basis.determinant()
    )

static func log_bad(who: String, t: Transform3D) -> void:
    var msg: String = dump_t(str("NON-FINITE/DEGENERATE TRANSFORM @ ", who), t)
    print(msg)
    push_error(msg)
    if OS.has_feature("web"):
        JavaScriptBridge.eval("console.error(" + JSON.stringify(msg) + ");")

static func assert_tx_ok(t: Transform3D, who: String) -> void:
    var ok: bool = is_f_v(t.origin) and is_f_b(t.basis)
    var det: float = t.basis.determinant()
    if not ok or not is_f(det) or det == 0.0:
        log_bad(who, t)
    assert(ok, "NaN/Inf in " + who)
    assert(is_f(det) and det != 0.0, "degenerate basis in " + who)

func _enter_tree() -> void:
    get_tree().connect(&"node_added", Callable(self, &"_on_node_added"))
    get_tree().connect(&"node_removed", Callable(self, &"_on_node_removed"))

func _on_node_added(n: Node) -> void:
    if n.is_in_group(ignoreGroup):
        return
    if n is Node3D:
        nodes.append(n)
    if n is MultiMeshInstance3D:
        multimeshes.append(n)
    if n is Skeleton3D:
        skeletons.append(n)

func _on_node_removed(n: Node) -> void:
    if n is Node3D:
        var k: int = nodes.find(n)
        if k != -1: nodes.remove_at(k)
    if n is MultiMeshInstance3D:
        var k2: int = multimeshes.find(n)
        if k2 != -1: multimeshes.remove_at(k2)
    if n is Skeleton3D:
        var k3: int = skeletons.find(n)
        if k3 != -1: skeletons.remove_at(k3)

func _process(_dt: float) -> void:
    _sweep()

func _physics_process(_dt: float) -> void:
    _sweep()

func _sweep() -> void:
    var budget: int = batchPerFrame

    # Node3D globals
    while budget > 0 and nodes.size() > 0:
        if iN >= nodes.size(): iN = 0; break
        var n3: Node3D = nodes[iN]; iN += 1
        if n3.is_inside_tree() and not n3.is_in_group(ignoreGroup):
            assert_tx_ok(n3.global_transform, str(n3.get_path()))
        budget -= 1

    # MultiMesh instance transforms
    while budget > 0 and multimeshes.size() > 0:
        if iM >= multimeshes.size(): iM = 0; break
        var mmi: MultiMeshInstance3D = multimeshes[iM]; iM += 1
        if mmi.is_inside_tree() and not mmi.is_in_group("ignoreGroup"):
            var mm: MultiMesh = mmi.multimesh
            assert(mm != null, "MMI has null multimesh: " + str(mmi.get_path()))
            var c: int = mm.get_instance_count()
            for j in c:
                assert_tx_ok(mm.get_instance_transform(j), str(mmi.get_path(), " [MultiMesh idx=", j, "]"))
                budget -= 1
                if budget <= 0: break

    # Skeleton bone globals
    while budget > 0 and skeletons.size() > 0:
        if iS >= skeletons.size(): iS = 0; break
        var sk: Skeleton3D = skeletons[iS]; iS += 1
        if sk.is_inside_tree() and not sk.is_in_group(ignoreGroup):
            var bc: int = sk.get_bone_count()
            for b in bc:
                assert_tx_ok(sk.get_bone_global_pose(b), str(sk.get_path(), " [Bone ", b, ": ", sk.get_bone_name(b), "]"))
                budget -= 1
                if budget <= 0: break
