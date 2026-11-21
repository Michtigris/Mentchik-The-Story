class_name PowerManager
extends Node

signal powers_refreshed
const POWER_IDS = preload("res://scripts/powers/StainedGlassPower.gd").PowerId

var active_powers: Dictionary = {}

func _ready() -> void:
	GameState.powers_changed.connect(_refresh_active_powers)
	_refresh_active_powers()

func _refresh_active_powers() -> void:
	active_powers.clear()
	for power_id in GameState.equipped_powers:
		active_powers[power_id] = true
	powers_refreshed.emit()

func has_power(power_id: int) -> bool:
	return active_powers.has(power_id)

func orange_dash_speed_multiplier() -> float:
	if has_power(POWER_IDS.ORANGE_MOBILITY):
		return 1.35
	return 1.0

func orange_attack_cooldown_multiplier() -> float:
	if has_power(POWER_IDS.ORANGE_MOBILITY):
		return 1.3
	return 1.0

func red_reflection_enabled() -> bool:
	return has_power(POWER_IDS.RED_MIGHT)

func blue_reveals_hidden() -> bool:
	return has_power(POWER_IDS.BLUE_VISION)

func yellow_time_scale() -> float:
	return 1.0


func black_corruption_attack_bonus() -> float:
	if has_power(POWER_IDS.BLACK_CORRUPTION):
		return 2.0
	return 1.0

func can_dash_ability() -> bool:
	return has_power(POWER_IDS.VIOLET_SHADOW)

func green_speed_multiplier() -> float:
	if has_power(POWER_IDS.GREEN_NATURE):
		return 1.35
	return 1.0

func green_cooldown_multiplier() -> float:
	if has_power(POWER_IDS.GREEN_NATURE):
		return 0.7
	return 1.0

func blue_extra_jump_count() -> int:
	if has_power(POWER_IDS.BLUE_VISION):
		return 1
	return 0

func white_heal_kill_threshold() -> int:
	if has_power(POWER_IDS.WHITE_LIGHT):
		return 2
	return 0

func black_forced_one_heart() -> bool:
	return has_power(POWER_IDS.BLACK_CORRUPTION)

func yellow_stomp_enabled() -> bool:
	return has_power(POWER_IDS.YELLOW_TIME)
