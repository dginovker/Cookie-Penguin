> First 5 seconds improvements <
1. Improve mobile controls more. Joystick should take up like 5cm min
  a) Make UI on the top and bottom if in portrait mode
2. Figure out why the client doesn't have the right location of the server..
3. Get Chongho's kids to playtest again

> First 60 seconds improvements <
1. Record hit sounds
2. Improve item stats UI panel
3. Add special attacks
4. Make monsters drop a tier 1 sword
5. Make it so you see other players' movement animation

> ok but I wanna fix it <
1. Chat

> Networking improvements <
1. Look into changing unreliable_lifetime to not backlog buffer: https://docs.godotengine.org/en/stable/classes/class_webrtcmultiplayerpeer.html#method-descriptions
a) mp.add_peer(p, id, 150) # packets older than 150ms get dropped I think
2. Look into using more different stream channels
a) Snapshot update should def be different channel than movement RBSes 
3. Visibility filter updates
a) This basically will test throttling snapshots. Don't worry about case where lots of people in 1 space for now
2. Set up a TURN relay so people blocked on UDP can connect (add readme instructions)
3. Make disconnecting work
4. Make a second world scene: Going to have to make the server player be in all scenes/adjust all the spawners to grab where the local player is..
