extends EnemyBase
const POWER_IDS = preload("res://scripts/powers/StainedGlassPower.gd").PowerId

func _is_weak_to(power_id: int) -> bool:
	return power_id == POWER_IDS.WHITE_LIGHT or power_id == POWER_IDS.BLUE_VISION
