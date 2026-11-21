extends Node

signal powers_changed
signal progression_changed
signal level_reward_granted(reward_data: Dictionary)
signal stats_changed

const MAX_LEVEL := 8
const POWER_SLOT_START := 1
const POWER_SLOT_UPGRADED := 3
const POWER_IDS = preload("res://scripts/powers/StainedGlassPower.gd").PowerId
const ALL_POWERS: Array[int] = [
	POWER_IDS.BLUE_VISION,
	POWER_IDS.RED_MIGHT,
	POWER_IDS.GREEN_NATURE,
	POWER_IDS.YELLOW_TIME,
	POWER_IDS.VIOLET_SHADOW,
	POWER_IDS.WHITE_LIGHT,
	POWER_IDS.BLACK_CORRUPTION,
	POWER_IDS.ORANGE_MOBILITY
]

var unlocked_powers: Array[int] = []
var equipped_powers: Array[int] = []
var max_power_slots := POWER_SLOT_START

var unlocked_levels: Array[String] = ["niveau_1"]
var completed_levels: Array[String] = []
var current_level_id := "niveau_1"
var fragments_collected := 0
var cathedral_restoration_stage := 0
var total_score := 0
var total_deaths := 0
var level_start_health := 3
var dev_infinite_health := false
var dev_damage_multiplier := 1.0

const SCORE_PER_ENEMY_KILL := 120
const SCORE_DEATH_PENALTY := 180
const SCORE_TIME_BONUS_MAX := 1400
const SCORE_TIME_BONUS_PER_SECOND := 12

func _ready() -> void:
	SaveSystem.load_game()

func can_equip_more() -> bool:
	return equipped_powers.size() < max_power_slots

func is_power_unlocked(power_id: int) -> bool:
	return unlocked_powers.has(power_id)

func is_power_equipped(power_id: int) -> bool:
	return equipped_powers.has(power_id)

func equip_power(power_id: int) -> bool:
	if not is_power_unlocked(power_id):
		return false
	if is_power_equipped(power_id):
		return false
	if not can_equip_more():
		return false
	equipped_powers.append(power_id)
	powers_changed.emit()
	SaveSystem.save_game()
	return true

func unequip_power(power_id: int) -> bool:
	if not is_power_equipped(power_id):
		return false
	equipped_powers.erase(power_id)
	powers_changed.emit()
	SaveSystem.save_game()
	return true

func unlock_power(power_id: int) -> void:
	if unlocked_powers.has(power_id):
		return
	unlocked_powers.append(power_id)
	progression_changed.emit()
	SaveSystem.save_game()

func unlock_level(level_id: String) -> void:
	if unlocked_levels.has(level_id):
		return
	unlocked_levels.append(level_id)
	progression_changed.emit()
	SaveSystem.save_game()

func collect_fragment() -> void:
	fragments_collected += 1
	cathedral_restoration_stage = mini(4, fragments_collected / 2)
	if fragments_collected >= 2:
		max_power_slots = POWER_SLOT_UPGRADED
	if fragments_collected >= 5:
		max_power_slots = 4
	progression_changed.emit()
	SaveSystem.save_game()

func grant_random_new_power() -> int:
	var candidates: Array[int] = []
	for power_id in ALL_POWERS:
		if not unlocked_powers.has(power_id):
			candidates.append(power_id)
	if candidates.is_empty():
		return -1
	var index := randi() % candidates.size()
	var chosen := candidates[index]
	unlock_power(chosen)
	return chosen

func complete_level(level_id: String) -> void:
	if not completed_levels.has(level_id):
		completed_levels.append(level_id)
	var idx := _level_id_to_index(level_id)
	if idx < MAX_LEVEL:
		var next_id := "niveau_%d" % (idx + 1)
		unlock_level(next_id)
		current_level_id = next_id
	SaveSystem.save_game()

func get_next_level_id(from_level_id: String) -> String:
	var idx := _level_id_to_index(from_level_id)
	if idx < MAX_LEVEL:
		return "niveau_%d" % (idx + 1)
	return ""

func _level_id_to_index(level_id: String) -> int:
	var parts := level_id.split("_")
	if parts.size() >= 2:
		return int(parts[1])
	return 1

func grant_level_completion_rewards(level_id: String) -> Dictionary:
	var already_completed := completed_levels.has(level_id)
	var new_power_id := -1
	var auto_equipped := false
	if not already_completed:
		collect_fragment()
		new_power_id = grant_random_new_power()
		if new_power_id != -1 and can_equip_more():
			auto_equipped = equip_power(new_power_id)
		complete_level(level_id)
	var next_level_id := get_next_level_id(level_id)
	var is_campaign_complete := next_level_id == ""
	var reward_data := {
		"completed_level_id": level_id,
		"next_level_id": next_level_id,
		"is_campaign_complete": is_campaign_complete,
		"new_power_id": new_power_id,
		"auto_equipped": auto_equipped,
		"already_completed": already_completed
	}
	level_reward_granted.emit(reward_data)
	SaveSystem.save_game()
	return reward_data

func get_current_level_index() -> int:
	return _level_id_to_index(current_level_id)

func export_save_data() -> Dictionary:
	return {
		"unlocked_powers": unlocked_powers,
		"equipped_powers": equipped_powers,
		"max_power_slots": max_power_slots,
		"unlocked_levels": unlocked_levels,
		"completed_levels": completed_levels,
		"current_level_id": current_level_id,
		"fragments_collected": fragments_collected,
		"cathedral_restoration_stage": cathedral_restoration_stage,
		"total_score": total_score,
		"total_deaths": total_deaths,
		"level_start_health": level_start_health
	}

func import_save_data(data: Dictionary) -> void:
	unlocked_powers = _to_int_array(data.get("unlocked_powers", unlocked_powers))
	equipped_powers = _to_int_array(data.get("equipped_powers", equipped_powers))
	max_power_slots = data.get("max_power_slots", POWER_SLOT_START)
	unlocked_levels = _to_string_array(data.get("unlocked_levels", unlocked_levels))
	if unlocked_levels.has("vieille_ville"):
		unlocked_levels.erase("vieille_ville")
		unlocked_levels.append("niveau_1")
	completed_levels = _to_string_array(data.get("completed_levels", completed_levels))
	current_level_id = data.get("current_level_id", current_level_id)
	fragments_collected = data.get("fragments_collected", 0)
	cathedral_restoration_stage = data.get("cathedral_restoration_stage", 0)
	total_score = maxi(0, int(data.get("total_score", total_score)))
	total_deaths = maxi(0, int(data.get("total_deaths", total_deaths)))
	level_start_health = maxi(1, int(data.get("level_start_health", level_start_health)))
	var repaired := ensure_valid_progression()
	powers_changed.emit()
	progression_changed.emit()
	stats_changed.emit()
	if repaired:
		SaveSystem.save_game()

func _to_int_array(value: Variant) -> Array[int]:
	var out: Array[int] = []
	if value is Array:
		for item in value:
			out.append(int(item))
	return out

func _to_string_array(value: Variant) -> Array[String]:
	var out: Array[String] = []
	if value is Array:
		for item in value:
			out.append(str(item))
	return out


func ensure_valid_progression() -> bool:
	var dirty := false
	var cleaned: Array[String] = []
	for item in unlocked_levels:
		var s := str(item).strip_edges()
		if s != "":
			cleaned.append(s)
	if cleaned.is_empty():
		cleaned.append("niveau_1")
		dirty = true
	if cleaned.size() != unlocked_levels.size():
		dirty = true
	else:
		for i in cleaned.size():
			if str(unlocked_levels[i]) != cleaned[i]:
				dirty = true
				break
	unlocked_levels = cleaned

	var lid := str(current_level_id).strip_edges()
	if lid == "" or not unlocked_levels.has(lid):
		current_level_id = "niveau_1" if unlocked_levels.has("niveau_1") else unlocked_levels[0]
		dirty = true
	return dirty


func reset_for_new_adventure() -> void:
	unlocked_powers.clear()
	equipped_powers.clear()
	max_power_slots = POWER_SLOT_START
	unlocked_levels = ["niveau_1"]
	completed_levels.clear()
	current_level_id = "niveau_1"
	fragments_collected = 0
	cathedral_restoration_stage = 0
	total_score = 0
	total_deaths = 0
	level_start_health = 3
	clear_dev_combat_modifiers()
	powers_changed.emit()
	progression_changed.emit()
	stats_changed.emit()
	SaveSystem.save_game()

func prepare_dev_vitraux_selection() -> void:
	for power_id in ALL_POWERS:
		if not unlocked_powers.has(power_id):
			unlocked_powers.append(power_id)
	max_power_slots = maxi(max_power_slots, 4)
	var candidates: Array[int] = []
	for power_id in unlocked_powers:
		if not candidates.has(power_id):
			candidates.append(power_id)
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	for i in range(candidates.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var tmp := candidates[i]
		candidates[i] = candidates[j]
		candidates[j] = tmp
	equipped_powers.clear()
	var target_count := mini(max_power_slots, 4)
	for i in range(mini(target_count, candidates.size())):
		equipped_powers.append(candidates[i])
	powers_changed.emit()
	progression_changed.emit()

func activate_dev_combat_modifiers() -> void:
	dev_infinite_health = true
	dev_damage_multiplier = 2.0

func clear_dev_combat_modifiers() -> void:
	dev_infinite_health = false
	dev_damage_multiplier = 1.0

func get_dev_damage_multiplier() -> float:
	return maxf(1.0, dev_damage_multiplier)

func add_score(points: int) -> void:
	if points == 0:
		return
	total_score = maxi(0, total_score + points)
	stats_changed.emit()
	SaveSystem.save_game()

func register_enemy_kill() -> void:
	add_score(SCORE_PER_ENEMY_KILL)

func register_death() -> void:
	total_deaths += 1
	add_score(-SCORE_DEATH_PENALTY)
	stats_changed.emit()
	SaveSystem.save_game()

func register_level_time_bonus(elapsed_seconds: float) -> void:
	var bonus := maxi(0, SCORE_TIME_BONUS_MAX - int(round(elapsed_seconds * SCORE_TIME_BONUS_PER_SECOND)))
	add_score(bonus)

func get_level_start_health() -> int:
	return maxi(1, level_start_health)

func register_level_completed_health(remaining_health: int) -> void:
	level_start_health = maxi(1, remaining_health) + 1
	SaveSystem.save_game()
