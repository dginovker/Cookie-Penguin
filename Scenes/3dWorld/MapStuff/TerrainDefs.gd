# TerrainDefs.gd
class_name TerrainDefs

# Enum order == mask packing order (0..8). Changing it requires a re-bake.
enum Type { GRASS, SAND, FOREST, PLATEAU, ICE, DESOLATE, SHALLOW, DEEP, LAVA }

# Constant-friendly palette (hex RGB). Index matches Type value.
const COLORS_HEX := [
    0x96F06E, # GRASS
    0xFFFFBE, # SAND
    0x4BAF00, # FOREST
    0x4C4C4C, # PLATEAU
    0xFFFFFF, # ICE
    0x4E4E4E, # DESOLATE
    0x6EC8FA, # SHALLOW
    0x143DA5, # DEEP
    0xFFA500, # LAVA
]

static func color_from_hex(h:int)->Color:
    return Color8((h>>16)&0xFF, (h>>8)&0xFF, h&0xFF, 255)
