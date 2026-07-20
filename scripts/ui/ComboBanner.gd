# ComboBanner.gd — S3-UI-Battle 连携横幅（A3 锚点5 五行符文阵意象）
# 监听 EventBus.bond_combo(group_id, bonus_pct) → 渲染横幅；
# 数值 = bonus_pct（如 0.175 → 「+17.5%」，tabular）；
# 三通道：五行符文（形状）+ 组名文字 + 数值（不靠色，Basic E）。
# reduce_motion 时静态显符文环+终值，无旋转/滚动（Standard I）。
extends Control

class_name ComboBanner

signal banner_shown(group_id, bonus_pct)

# 组 → 激活行（A3.1）：仅高亮对应行符，其余暗描。
const GROUP_ELEMENTS := {
	"jian_zong": ["metal", "wood"],
	"tie_bi":     ["earth"],
	"yu_zu":      ["water", "fire"],
	"long_zu":     ["metal", "water"],
	"hu_zu":      ["metal"],
}

var _label: Label = null
var _group_id: String = ""
var _bonus: float = 0.0
var _tween: Tween = null

func _ready() -> void:
	_label = Label.new()
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT.CENTER
	_label.vertical_alignment = VERTICAL_ALIGNMENT.CENTER
	add_child(_label)
	if EventBus != null:
		EventBus.bond_combo.connect(_on_bond_combo)
	if UIThemeController != null:
		UIThemeController.layout_mode_changed.connect(_on_layout)
	if AccessibilitySettings != null:
		AccessibilitySettings.accessibility_changed.connect(_on_theme)
	visible = false
	_on_layout(UIThemeController.layout_mode if UIThemeController != null else "single")

# EventBus.bond_combo → 横幅
func _on_bond_combo(group_id: String, bonus_pct: float) -> void:
	_group_id = group_id
	_bonus = bonus_pct
	var name := _group_name(group_id)
	_label.text = "%s 连携   %s" % [name, format_bonus(bonus_pct)]
	_label.add_theme_color_override("font_color", UIThemeController.get_text_color())
	_show()
	banner_shown.emit(group_id, bonus_pct)

# 数值格式化：0.175 → "+17.5%"，tabular（防抖）。静态可测。
static func format_bonus(pct: float) -> String:
	return "+%.1f%%" % (pct * 100.0)

func _group_name(group_id: String) -> String:
	var cfg = ConfigLoader.load_table("battle/bond_combos", "res://data/battle/bond_combos.json")
	if cfg != null and cfg.get("groups", {}).has(group_id):
		return cfg["groups"][group_id].get("name", group_id)
	return group_id

func _show() -> void:
	visible = true
	queue_redraw()
	var ms := _stay_ms()
	var motion := 0.0
	if AccessibilitySettings != null:
		motion = AccessibilitySettings.get_motion_scale()
	if motion <= 0.0 or UIThemeController.is_performance_mode():
		# 减少动效 / 性能模式：静态等效（仅显符文终值，不滚动/旋转）
		_modulate_alpha(1.0)
		await get_tree().create_timer(ms / 1000.0).timeout
		_hide()
		return
	# 进场：自中心旋开 + 数值滚动由符文/文字直接显终值（视觉旋开用 tween）
	_play_in(motion)
	await get_tree().create_timer(ms / 1000.0).timeout
	_hide()

func _play_in(_motion: float) -> void:
	if _tween != null:
		_tween.kill()
	_tween = create_tween()
	_modulate_alpha(0.0)
	_tween.tween_method(_modulate_alpha, 0.0, 1.0, 0.4 * _motion)
	_tween.play()

func _modulate_alpha(a: float) -> void:
	modulate.a = a

func _hide() -> void:
	visible = false
	modulate.a = 1.0

func _on_layout(_mode: String) -> void:
	var cfg = ConfigLoader.load_table("battle/ui_constants", "res://data/battle/battle_ui_constants.json")
	var cb := cfg.get("combo_banner", {}) if cfg != null else {}
	var mobile := UIThemeController.layout_mode == "single"
	var w_pct: float = cb.get("max_width_pct", {}).get("mobile" if mobile else "pc", 0.6)
	var h: int = int(cb.get("max_height_px", {}).get("mobile" if mobile else "pc", 56))
	var mtop: int = int(cb.get("margin_top_px", {}).get("mobile" if mobile else "pc", 4))
	custom_minimum_size = Vector2(maxf(160.0, get_viewport().size.x * w_pct) if get_viewport() != null else 360.0, float(h))
	position = Vector2((get_viewport().size.x if get_viewport() != null else 1280.0) * 0.5 - custom_minimum_size.x * 0.5, float(mtop))
	queue_redraw()

func _on_theme(_p = null) -> void:
	queue_redraw()
	if _label != null:
		_label.add_theme_color_override("font_color", UIThemeController.get_text_color())

func _stay_ms() -> int:
	var cfg = ConfigLoader.load_table("battle/ui_constants", "res://data/battle/battle_ui_constants.json")
	var cb := cfg.get("combo_banner", {}) if cfg != null else {}
	return int(cb.get("stay_ms", 1500))

# 自绘：五行符文环（激活组对应行符高亮，其余暗描）+ 深墨底缎带。
func _draw() -> void:
	if not visible:
		return
	var w := size.x
	var h := size.y
	# 深墨底缎带（Basic A 对比度：深墨底 + 月白字）
	draw_rect(Rect2(0, 0, w, h), UIThemeController.get_background_color())
	draw_rect(Rect2(0, 0, w, h), false, 2.0)
	# 五行符文环：左起 5 个本行形状
	var r := 5
	var rad := h * 0.34
	var cx0 := h * 0.55
	var cy := h * 0.5
	var active := GROUP_ELEMENTS.get(_group_id, [])
	for i in r:
		var el := ["metal", "wood", "water", "fire", "earth"][i]
		var pos := Vector2(cx0 + float(i) * (rad * 2.2), cy)
		var shape := ElementShapeMap.shape_name_for(el)
		var pts := ElementShapeDrawer.build_element_points(shape, Rect2(pos - Vector2(rad, rad), Vector2(rad * 2, rad * 2)))
		var col := UIThemeController.get_element_color(el)
		var on := active.has(el)
		if on:
			draw_polygon(pts, PackedColorArray([col]))
		else:
			draw_polyline(pts, col * Color(1, 1, 1, 0.35), 2.0)
	# 文本区（Label 子节点已叠加），此处仅补右端数值描边占位
	_label.position = Vector2(h * 1.0, 0)
	_label.size = Vector2(w - h * 1.0, h)
