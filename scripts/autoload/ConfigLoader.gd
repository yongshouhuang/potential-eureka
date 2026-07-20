# ConfigLoader.gd — 数据驱动配置表加载器（ADR-004）
# 测试策略 §3：内存覆盖接口 inject / reset + 真实 fallback 加载。
# 所有管理器经此取配置，故注入即生效、与真实 data/* 解耦、确定性可复现。
extends Node

# 内存假表：table_id -> 任意数据（Dict / Resource）
var _overrides: Dictionary = {}


# 取表：优先内存覆盖，否则加载 fallback_path。
# fallback 支持 .json（JSON.parse_string）或 .tres（load()）。
func load_table(id: String, fallback_path: String = ""):
	if _overrides.has(id):
		return _overrides[id]
	if fallback_path == "":
		push_error("ConfigLoader.load_table: 无覆盖且无 fallback -> " + id)
		return null
	if fallback_path.ends_with(".json"):
		return _load_json(fallback_path)
	return load(fallback_path)


# 注入内存假表（测试用）
func inject(id: String, data) -> void:
	_overrides[id] = data


# 清除全部内存覆盖（测试 after_each）
func reset() -> void:
	_overrides.clear()


# 是否已注入某表
func has_override(id: String) -> bool:
	return _overrides.has(id)


func _load_json(path: String):
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		push_error("ConfigLoader: 无法打开 " + path)
		return null
	var text := f.get_as_text()
	f.close()
	var parsed = JSON.parse_string(text)
	if parsed == null:
		push_error("ConfigLoader: JSON 解析失败 " + path)
	return parsed
