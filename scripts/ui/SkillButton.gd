# SkillButton.gd — S3-UI-Battle 选技/觉醒技按钮（双端热区 ≥44×44）
# 自绘：本行形状 + 技能名 + 气耗角标；气不足时置灰 + 对角划线 + 数字提示（不靠纯色）。
# 双端手势：PC 左键点击=选技、右键长按=窥视；移动 Tap=选技、长按=窥视。
# 经统一抽象意图（autoload InputBridge.inject_intent）转发，保证「屏幕只认意图不认硬件」。
extends Control

class_name SkillButton

signal skill_selected(skill_id: String)
signal skill_peeked(skill_id: String)

const LONG_PRESS_MS := 350

var skill_id: String = ""
var element: String = ""
var can_use: bool = true
var qi_cost: int = 0
var _pressing: bool = false
var _press_t: int = 0
var _peek_fired: bool = false

func _ready() -> void:
	focus_mode = Control.FOCUS_ALL
	# 高对比 / 缩放 / CVD 即时生效
	if UIThemeController != null:
		UIThemeController.layout_mode_changed.connect(_on_theme)
	if AccessibilitySettings != null:
		AccessibilitySettings.accessibility_changed.connect(_on_theme)
	_on_theme()

func _on_theme(_p = null) -> void:
	queue_redraw()

func set_skill(skill_id_: String, element_: String, can_use_: bool, qi_cost_: int) -> void:
	skill_id = skill_id_
	element = element_
	can_use = can_use_
	qi_cost = qi_cost_
	queue_redraw()

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT:
			if mb.pressed:
				_press_start()
			else:
				_press_end()
		elif mb.button_index == MOUSE_BUTTON_RIGHT and mb.pressed:
			skill_peeked.emit(skill_id)         # PC 右键 = 窥视
	elif event is InputEventScreenTouch:
		var st := event as InputEventScreenTouch
		if st.pressed:
			_press_start()
		else:
			_press_end()

func _press_start() -> void:
	_pressing = true
	_peek_fired = false
	_press_t = Time.get_ticks_msec()

func _press_end() -> void:
	if not _pressing:
		return
	_pressing = false
	var dt := Time.get_ticks_msec() - _press_t
	if not _peek_fired and dt < LONG_PRESS_MS:
		if can_use:
			skill_selected.emit(skill_id)        # Tap/点击 = 选技
	elif _peek_fired:
		pass
	else:
		skill_peeked.emit(skill_id)            # 长按 = 窥视

func _process(_dt: float) -> void:
	if _pressing and not _peek_fired:
		if Time.get_ticks_msec() - _press_t >= LONG_PRESS_MS:
			_peek_fired = true
			skill_peeked.emit(skill_id)        # 移动长按不松手也触发窥视

func _draw() -> void:
	var r := Rect2(Vector2.ZERO, size)
	var bg := UIThemeController.get_background_color()
	if not can_use:
		bg = bg * Color(1, 1, 1, 0.5)
	draw_rect(r, bg)
	# 本行形状（左上角小 glyph，形状冗余）
	if element != "":
		var shape := ElementShapeMap.shape_for(element)
		var sr := Rect2(4, 4, r.size.y - 8, r.size.y - 8)
		var pts := ElementShapeDrawer.build_element_points(shape, sr)
		var col := UIThemeController.get_element_color(element)
		draw_polygon(pts, PackedColorArray([col if can_use else col * Color(1, 1, 1, 0.4)]))
		draw_polyline(pts, UIThemeController.get_text_color() if UIThemeController.is_high_contrast() else col.lightened(0.25), 2.0)
	# 技能名（中）
	var nm := skill_id if skill_id != "" else "?"
	draw_string(nm, Vector2(r.size.y, r.size.y * 0.5 - 8), HORIZONTAL_ALIGNMENT.LEFT, 0, UIThemeController.get_text_color(), 16)
	# 气耗角标（右上，数字冗余）
	if qi_cost > 0:
		var q := "气%d" % qi_cost
		draw_string(q, Vector2(r.size.x - 44, 4), HORIZONTAL_ALIGNMENT.LEFT, 0, UIThemeController.get_text_color(), 13)
	# 气不足：对角划线（不靠纯色失效）
	if not can_use:
		draw_line(r.position, r.position + r.size, UIThemeController.get_text_color(), 2.0)
	# 双边界（高对比 / 户外强光）
	draw_rect(r, false, 2.0)
	if UIThemeController.is_high_contrast():
		draw_rect(Rect2(r.position + Vector2(2, 2), r.size - Vector2(4, 4)), false, 1.0)

# 最小命中区（双端≥44，移动 48）。
func get_minimum_size() -> Vector2:
	var cfg = ConfigLoader.load_table("battle/ui_constants", "res://data/battle/battle_ui_constants.json")
	var sb := cfg.get("skill_button", {}) if cfg != null else {}
	var base := int(sb.get("hotzone_min_px", 44))
	var m := base
	if UIThemeController != null and UIThemeController.layout_mode == "single":
		m = maxi(base, int(sb.get("mobile_min_px", 48)))
	return Vector2(float(m), float(m))
