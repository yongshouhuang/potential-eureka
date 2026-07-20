# rng.gd — 基于 Godot RandomNumberGenerator 的种子化 RNG 封装
# 抽卡/事件等所有随机路径一律经此，保证测试可复现（测试策略 §3）。
# 管理器持有本封装实例，测试可注入固定种子。
class_name RNGWrapper
extends RefCounted

var _rng: RandomNumberGenerator


func _init(p_seed: int = 0) -> void:
	_rng = RandomNumberGenerator.new()
	if p_seed != 0:
		_rng.seed = p_seed


# 重新设定种子（默认 0 视为「由 Godot 随机播种」）
func reseed(p_seed: int) -> void:
	_rng.seed = p_seed


# [0,1) 浮点
func randf() -> float:
	return _rng.randf()


# [from, to] 闭区间整数
func randi_range(from: int, to: int) -> int:
	return _rng.randi_range(from, to)


# [0, to_exclusive) 整数（常用于按数组长度取索引）
func rand_index(length: int) -> int:
	if length <= 0:
		return 0
	return _rng.randi_range(0, length - 1)


# 以概率 p 命中
func chance(p: float) -> bool:
	return _rng.randf() < p
