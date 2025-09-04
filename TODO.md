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

> Bugs <
1. You can't see lootbag loot if the lootbag spawned before you

> ok but I wanna fix it <
1. Chat

> Networking improvements <
1. Try exporting web builds with threads. Need to verify it still works on Itch 
2. Without interpolation, my NPCs look like they're teleporting. With interpolation, they're sliding and stopping, then sliding and stopping again. I'm not too sure how to describe this issue well, but is it a common thing, and is there a way to fix it? 
3. Visibility filter updates
a) This basically will test throttling snapshots. Don't worry about case where lots of people in 1 space for now
4. Set up a TURN relay so people blocked on UDP can connect (add readme instructions)
5. Make disconnecting work
a) Disconnected peers should disappear
b) There should be a UI indication that you've disconnected
6. Make a second world scene: Going to have to make the server player be in all scenes/adjust all the spawners to grab where the local player is..
