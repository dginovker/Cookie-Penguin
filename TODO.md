> First 5 seconds improvements <
2. Figure out why FPS so bad on mobile
b) Pretty sure it maps to the number of mobs in the world. Visibility filter updates should fix it.
3. Make text font bigger on mobile
a) This is actually an issue of text size on large resolutions
2. Get Chongho's kids to playtest again

> First 60 seconds improvements <
0. Figure out how to make drinking healthpotions and stuff better. Maybe if on mobile, you get an option menu of things to do (buttons for take and drink, with info on the bottom) everytime you click on an item?
1. Come up with a way to make lootbag loot appear faster1. Record hit sounds
2. Improve item stats UI panel
3. Add mana bar for special attacks
4. Make monsters drop a tier 1 sword
5. Make it so you see other players' movement animation

> Bugs <
1. Browser clients see mobs clipping. Clipping only happens when they're over the ground.
2. Bullets stop spawning sometimes
a) I suspect this is reliable UDP packet issue. Settings debug panel will help confirm.

> ok but I wanna fix it <

> Networking improvements <
1. Move away from all the multiplayer synchronizers and stuff so it stops spamming errors
2. Visibility filter updates
a) This basically will test throttling snapshots. Don't worry about case where lots of people in 1 space for now
2. Set up a TURN relay so people blocked on UDP can connect (add readme instructions)
3. Make it so when you disconnect, you get notified/kicked out of game
b) There should be a UI indication that you've disconnected
4. Make mobs send their movement ahead of time ("move here in 0.5s")
a) pre-req for making mob bullets schedule shoot in 0.5s
5. Make player bullets come from client location
a) Just do a distance check to be sure it's within 2 squares of server location or something
b) or see if Netfox rollback states work here
6. Make a second world scene: Going to have to make the server player be in all scenes/adjust all the spawners to grab where the local player is..
