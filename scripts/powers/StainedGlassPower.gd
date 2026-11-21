class_name StainedGlassPower
extends Resource

enum PowerId {
	BLUE_VISION,
	RED_MIGHT,
	ORANGE_MOBILITY,
	GREEN_NATURE,
	YELLOW_TIME,
	VIOLET_SHADOW,
	WHITE_LIGHT,
	BLACK_CORRUPTION
}

@export var id: PowerId
@export var display_name: String = ""
@export_multiline var description: String = ""
