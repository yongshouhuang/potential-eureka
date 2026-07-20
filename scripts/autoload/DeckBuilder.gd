# DeckBuilder.gd — 卡组构筑（B4 / E4-S1）
# 编队 4 式神 + 1 法宝位；超出规模拦截；写入 GameState.deck。
# 硬约束：只与 GameState / ConfigLoader（全局 autoload 名）交互，不 preload/import 其它管理器。
extends Node

const MAX_SHIKIGAMI := 4


var _shikigami_ids: Array[String] = []
var _treasure_id: String = ""


# 增 1 式神；已满 4 个则拦截返回 false（E4-S1 AC1 超出规模拦截）。
func add_shikigami(id: String) -> bool:
	if _shikigami_ids.size() >= MAX_SHIKIGAMI:
		return false
	if _shikigami_ids.has(id):
		return false
	_shikigami_ids.append(id)
	_sync()
	return true


# 移除 1 式神
func remove_shikigami(id: String) -> bool:
	if _shikigami_ids.has(id):
		_shikigami_ids.erase(id)
		_sync()
		return true
	return false


# 设法宝位（可空串表示未装备）
func set_treasure(id: String) -> bool:
	_treasure_id = id
	_sync()
	return true


# 整体设编队：必须恰好 4 式神，否则拦截返回 false（E4-S1 AC1）。
func set_deck(shikigami_ids: Array[String], treasure_id: String = "") -> bool:
	if shikigami_ids.size() != MAX_SHIKIGAMI:
		return false
	_shikigami_ids = shikigami_ids.duplicate()
	_treasure_id = treasure_id
	_sync()
	return true


# 当前卡组（GameState.deck：4 式神 id + 1 法宝 id）
func get_deck() -> Array:
	return GameState.deck.duplicate()


func _sync() -> void:
	var d: Array = []
	for s in _shikigami_ids:
		d.append(s)
	if _treasure_id != "":
		d.append(_treasure_id)
	GameState.deck = d
