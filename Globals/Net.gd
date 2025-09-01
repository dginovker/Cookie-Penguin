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

func start_server() -> void:
    is_client = false
    rtc = WebRTCMultiplayerPeer.new()
    rtc.create_server()                                # ← WebRTC server role
    multiplayer.multiplayer_peer = rtc                 # Todo - Test what happens if I remove this then document it
    signal_mp = WebSocketMultiplayerPeer.new(); signal_mp.create_server(PORT)

func start_client() -> void:
    is_client = true
    rtc = WebRTCMultiplayerPeer.new()
    signal_mp = WebSocketMultiplayerPeer.new(); signal_mp.create_client(URL)
    #print("Done signalining start")

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
            rtc.create_client(my_id)                  # WebRTC client role
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
