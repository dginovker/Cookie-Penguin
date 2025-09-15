# Globally persistent networking (signaling + WebRTC)
extends Node

var rtc: WebRTCMultiplayerPeer
var signal_mp: WebSocketMultiplayerPeer
var next_id: int = 2
const PORT: int = 10000
const URL: String = "ws://127.0.0.1:%d" % PORT
#const URL: String = "wss://duck.openredsoftware.com/pinkdragon"
const ICE: Array[Dictionary] = [{ "urls": "stun:stun.l.google.com:19302" }]

var ws_hello_sent: bool = false
var client_pc: WebRTCPeerConnection
var is_client: bool = false

# called with create_client and create_server
const SNAPSHOT_CHANNEL = 1 # Channel id 3
const SPAWN_CHANNEL = 2 # Channel id 4
const LOOTBAG_CHANNEL = 3 # Channel id 5, mostly for debugging to see if all channels are blocked
const MOB_HEALTH_UPDATES = 4 # Channel id 6
const DEBUG_HEALTH_CHANNEL = 5 # Channel id 7
const ADDITIONAL_CHANNELS = [
    MultiplayerPeer.TransferMode.TRANSFER_MODE_UNRELIABLE,
    MultiplayerPeer.TransferMode.TRANSFER_MODE_RELIABLE,
    MultiplayerPeer.TransferMode.TRANSFER_MODE_RELIABLE,
    MultiplayerPeer.TransferMode.TRANSFER_MODE_UNRELIABLE,
    MultiplayerPeer.TransferMode.TRANSFER_MODE_RELIABLE
]

func start_server() -> void:
    is_client = false
    rtc = WebRTCMultiplayerPeer.new()
    rtc.create_server(ADDITIONAL_CHANNELS)  # ← WebRTC server role
    multiplayer.multiplayer_peer = rtc                 # Todo - Test what happens if I remove this then document it
    signal_mp = WebSocketMultiplayerPeer.new(); signal_mp.create_server(PORT)

func start_client() -> void:
    is_client = true
    rtc = WebRTCMultiplayerPeer.new()
    signal_mp = WebSocketMultiplayerPeer.new(); signal_mp.create_client(URL)
    #print("Done signalining start")

var _time = 0
var _health_timer = 0.0

func _process(_dt: float) -> void:
    if signal_mp:
        signal_mp.poll()
        if is_client and signal_mp.get_connection_status() == MultiplayerPeer.CONNECTION_CONNECTED and !ws_hello_sent:
            signal_mp.put_packet(JSON.stringify({ "type":"hello" }).to_utf8_buffer()); ws_hello_sent = true
            #print("Sent hello")
        while signal_mp.get_available_packet_count() > 0:
            var sender_id: int = signal_mp.get_packet_peer() # read sender first
            var raw: PackedByteArray = signal_mp.get_packet()
            var msg: Dictionary = JSON.parse_string(raw.get_string_from_utf8()) as Dictionary
            if is_client: _client_handle_signal(msg)
            else: _server_handle_signal(sender_id, msg)
    if rtc: rtc.poll()
    if multiplayer.is_server():
        _time -= _dt
        if _time < 0:
            _time = 1
            print_buffers()
        
        # Send health data every second
        _health_timer += _dt
        if _health_timer >= 1.0:
            _health_timer = 0.0
            _send_server_health_data()

func print_buffers():
    if true:
        return
    for pid: int in PlayerManager.players.keys():
        if pid == 1:
            continue
        for channel: WebRTCDataChannel in rtc.get_peer(pid)["channels"]:
            var b: int = channel.get_buffered_amount()
            print("pid ", pid, ", channel id: ", channel.get_id(), " label: ", channel.get_label(), " is_ordered(): ", channel.is_ordered(), ", buffered bytes=", b)


func get_backpressure(pid: int, channel_id: int) -> int:
    """
    Godot exposes 3 channels by default
    So i.e. SNAPSHOT_CHANNEL is channel 2, despite being value 1 in RPCs
    ...But also, rtc.get_peer(pid)["channels"] is an array, so the index of SNAPSHOT_CHANNEL is 3-1 = 2
    (The first 3 are default channels)
    Confusing, right?
    """
    if pid == 1:
        return 0
    return rtc.get_peer(pid)["channels"][channel_id].get_buffered_amount()

# ---------- Server signaling over WebSocketMultiplayerPeer ----------

func _server_handle_signal(ws_id: int, msg: Dictionary) -> void:
    #print("Server got a signal: ", ws_id, msg)
    match String(msg.get("type", "")):
        "hello":
            var peer_id: int = next_id; next_id += 1
            _sig_send(ws_id, { "type":"assign_id", "id":peer_id })

            var pc: WebRTCPeerConnection = WebRTCPeerConnection.new()
            pc.initialize({ "iceServers": ICE })

            pc.session_description_created.connect(func(t: String, s: String):
                pc.set_local_description(t, s)
                # on server we only expect an OFFER here
                if t == "offer": _sig_send(ws_id, { "type":"offer", "id":peer_id, "sdp":s })
            )
            pc.ice_candidate_created.connect(func(mid: String, i: int, c: String):
                _sig_send(ws_id, { "type":"ice", "id":peer_id, "mid":mid, "index":i, "cand":c })
            )

            rtc.add_peer(pc, peer_id)        # must be STATE_NEW at this point
            pc.create_offer()                 # emits session_description_created → send offer

        "answer":
            var pid: int = int(msg["id"])
            var peer_info: Dictionary = rtc.get_peer(pid)              # { "connection", "channels", "connected" }
            var pc: WebRTCPeerConnection = peer_info["connection"]
            pc.set_remote_description("answer", String(msg["sdp"]))    # finishes handshake on server

        "ice":
            var pid2: int = int(msg["id"])
            var peer_info2: Dictionary = rtc.get_peer(pid2)
            var pc2: WebRTCPeerConnection = peer_info2["connection"]
            pc2.add_ice_candidate(String(msg["mid"]), int(msg["index"]), String(msg["cand"]))

func _sig_send(target_id: int, obj: Dictionary) -> void:
    #print("Sent signal to ", target_id, " of ", obj)
    signal_mp.set_target_peer(target_id)
    signal_mp.put_packet(JSON.stringify(obj).to_utf8_buffer())

# ---------- Client signaling over WebSocketMultiplayerPeer ----------

func _client_handle_signal(msg: Dictionary) -> void:
    #print("Got a signal: ", msg)
    match String(msg.get("type", "")):
        "assign_id":
            var my_id: int = int(msg["id"])
            rtc.create_client(my_id, ADDITIONAL_CHANNELS)                  # WebRTC client role
            multiplayer.multiplayer_peer = rtc

        "offer":
            client_pc = WebRTCPeerConnection.new()
            client_pc.initialize({ "iceServers": ICE })

            client_pc.session_description_created.connect(func(t: String, s: String):
                # this is the ANSWER auto-generated after set_remote_description("offer", ...)
                client_pc.set_local_description(t, s)
                signal_mp.put_packet(JSON.stringify({ "type":"answer", "id":rtc.get_unique_id(), "sdp":s }).to_utf8_buffer())
            )
            client_pc.ice_candidate_created.connect(func(mid: String, i: int, c: String):
                signal_mp.put_packet(JSON.stringify({ "type":"ice", "id":rtc.get_unique_id(), "mid":mid, "index":i, "cand":c }).to_utf8_buffer())
            )

            rtc.add_peer(client_pc, 1)                                # add while STATE_NEW
            client_pc.set_remote_description("offer", String(msg["sdp"]))  # triggers session_description_created with "answer"

        "ice":
            client_pc.add_ice_candidate(String(msg["mid"]), int(msg["index"]), String(msg["cand"]))

func _send_server_health_data() -> void:
    if not multiplayer.is_server():
        return
    
    var delta = get_process_delta_time()
    var process_fps: float = 0.0
    if delta > 0.0:
        process_fps = 1.0 / delta
    
    # Send individual health data to each connected client
    for pid: int in PlayerManager.players.keys():
        # Calculate total backpressure for this client across all channels
        var total_backpressure: int = 0
        for channel_id in range(len(ADDITIONAL_CHANNELS) + 3):  # +3 for default channels
            total_backpressure += get_backpressure(pid, channel_id)
        
        var health_data = {
            "physics_fps": Engine.get_frames_per_second(),
            "process_fps": process_fps,
            "timestamp": Time.get_ticks_msec(),
            "backpressure": total_backpressure
        }
        
        # Send to specific client
        _send_health_data_to_client.rpc_id(pid, health_data)

@rpc("any_peer", "call_local", "reliable", DEBUG_HEALTH_CHANNEL)
func _send_health_data_to_client(health_data: Dictionary) -> void:
    # Update client UI directly
    var client_network_control = get_tree().get_first_node_in_group("client_network_control")
    if client_network_control:
        client_network_control._receive_server_health_data(health_data)
