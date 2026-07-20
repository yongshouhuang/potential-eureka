# BattleHUD.gd — S3-UI-Battle 双端战斗 HUD 编排（E4-S6 / D-4）
# 只经 EventBus / GameState / ConfigLoader / UIThemeController / AccessibilitySettings /
# BattleManager / StatusManager / InputBridge（全局 autoload 名）通信；
# 严禁 preload/import 任何管理器脚本（解耦红线）。
# 职责：监听战斗事件 → 渲染连携横幅 / 状态图标 / 选技·目标 UI / 气槽；
# 按 compute_layout_mode 切换 PC 多栏 / 移动精简 HUD；订阅可访问性即时生效。
extends Control

class_name BattleHUD

var _banner: ComboBanner = null
var _unit_layer: Control = null
var _skill_panel: VBoxContainer = null
var _target_panel: HBoxContainer = null
var _input: BattleInputBridge = null

var _unit_panels := {}        # unit_id -> {root, hp, qi, status, element}
var _selected_skill: String = ""
var _selected_actor: String = ""

func _ready() -> void:
	_build_children()
	_connect_events()
	apply_layout(UIThemeController.layout_mode if UIThemeController != null else "single")

# ---------- 构建子控件 ----------
func _build_children() -> void:
	_banner = ComboBanner.new()
	_banner.name = "ComboBanner"
	_banner.visible = false
	add_child(_banner)

	_unit_layer = Control.new()
	_unit_layer.name = "UnitLayer"
	_unit_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_unit_layer)

	_skill_panel = VBoxContainer.new()
	_skill_panel.name = "SkillPanel"
	_skill_panel.visible = false
	add_child(_skill_panel)

	_target_panel = HBoxContainer.new()
	_target_panel.name = "TargetPanel"
	_target_panel.visible = false
	add_child(_target_panel)

	_input = BattleInputBridge.new()
	_input.name = "BattleInput"
	add_child(_input)
	_input.skill_picked.connect(_on_skill_picked)
	_input.target_picked.connect(_on_target_picked)
	_input.qi_picked.connect(_on_qi_picked)
	_input.peeked.connect(_on_peek)

# ---------- 事件接线（全经 EventBus）----------
func _connect_events() -> void:
	if EventBus == null:
		return
	EventBus.battle_started.connect(_on_battle_started)
	EventBus.battle_turn_begin.connect(_on_turn_begin)
	EventBus.battle_turn_resolved.connect(_on_turn_resolved)
	EventBus.battle_victory.connect(_on_battle_ended)
	EventBus.battle_defeat.connect(_on_battle_ended)
	EventBus.status_applied.connect(_on_status_changed)
	EventBus.status_changed.connect(_on_status_changed)
	EventBus.status_expired.connect(_on_status_expired)
	if UIThemeController != null:
		UIThemeController.layout_mode_changed.connect(apply_layout)
	if AccessibilitySettings != null:
		AccessibilitySettings.accessibility_changed.connect(_on_accessibility)

# ---------- 开局：建单位卡 ----------
func _on_battle_started(_chapter: int, _stage: int) -> void:
	_clear_unit_panels()
	if BattleManager == null:
		return
	for snap in BattleManager.get_all_units():
		_add_unit_panel(snap)
	apply_layout(UIThemeController.layout_mode if UIThemeController != null else "single")
	_hide_action_panels()

func _add_unit_panel(snap: Dictionary) -> void:
	var uid: String = snap.get("id", "")
	if uid == "":
		return
	var root := Control.new()
	root.name = "Unit_" + uid
	root.custom_minimum_size = Vector2(180, 64)
	_unit_layer.add_child(root)

	var name_l := Label.new()
	name_l.text = uid
	name_l.position = Vector2(4, 2)
	root.add_child(name_l)

	var hp := Label.new()
	hp.name = "hp"
	hp.position = Vector2(4, 22)
	root.add_child(hp)

	var qi := QiGauge.new()
	qi.name = "qi"
	qi.element = snap.get("element", "wood")
	qi.position = Vector2(4, 40)
	qi.size = Vector2(160, 22)
	root.add_child(qi)

	var st := HBoxContainer.new()
	st.name = "status"
	st.position = Vector2(110, 2)
	st.size = Vector2(70, 60)
	root.add_child(st)

	_unit_panels[uid] = {
		"root": root, "hp": hp, "qi": qi, "status": st,
		"element": snap.get("element", ""),
	}

func _clear_unit_panels() -> void:
	for uid in _unit_panels.keys():
		var p: Dictionary = _unit_panels[uid]
		if p.has("root") and is_instance_valid(p["root"]):
			p["root"].queue_free()
	_unit_panels.clear()

# ---------- 回合流程 ----------
func _on_turn_begin(actor_id: String, side: String) -> void:
	_refresh_all_units()
	if side == "player":
		_selected_actor = actor_id
		_show_skill_panel(actor_id)
	else:
		_hide_action_panels()

func _on_turn_resolved(_aid: String, _tid: String, _dmg: int, _rel: String) -> void:
	_refresh_all_units()

func _on_battle_ended(_a: int, _b: int) -> void:
	_hide_action_panels()

# ---------- 选技 / 目标 ----------
func _show_skill_panel(actor_id: String) -> void:
	_clear_container(_skill_panel)
	if BattleManager == null:
		return
	for sid in BattleManager.get_active_skills(actor_id):
		var sd: Dictionary = BattleManager._skill_def(sid) if BattleManager.has_method("_skill_def") else {}
		var el: String = sd.get("element", _unit_element(actor_id))
		var cost: int = 1 if BattleManager._is_awakened(BattleManager._find_actor(actor_id), sid) else 0
		var can := BattleManager.can_use_skill(actor_id, sid)
		var b := SkillButton.new()
		b.set_skill(sid, el, can, cost)
		_input.bind_skill(b)
		_skill_panel.add_child(b)
	if _skill_panel.get_child_count() > 0:
		_skill_panel.visible = true

func _on_skill_picked(skill_id: String) -> void:
	_selected_skill = skill_id
	if BattleManager == null:
		return
	var enemies := []
	for u in BattleManager.get_all_units():
		if u.get("side", "") == "enemy" and int(u.get("hp", 0)) > 0:
			enemies.append(u)
	if enemies.size() <= 1:
		var tid: String = enemies[0].get("id", "") if enemies.size() == 1 else ""
		_submit(skill_id, tid)
	else:
		_show_target_panel(enemies)

func _show_target_panel(enemies: Array) -> void:
	_clear_container(_target_panel)
	for e in enemies:
		var uid: String = e.get("id", "")
		# 目标芯片用纯 Control（仅绑定 target 语义，避免与 SkillButton 的 skill 语义双发）
		var chip := Control.new()
		chip.custom_minimum_size = Vector2(160, 56)
		var lab := Label.new()
		lab.text = "目标 " + uid
		lab.position = Vector2(8, 18)
		chip.add_child(lab)
		_input.bind_target(chip, uid)
		_target_panel.add_child(chip)
	_target_panel.visible = true

func _on_target_picked(unit_id: String) -> void:
	if _selected_skill != "":
		_submit(_selected_skill, unit_id)

func _on_qi_picked(_index: int) -> void:
	pass   # 气格点击留作「查看/选气」扩展，当前静态等效展示

func _on_peek(_payload: Dictionary) -> void:
	pass   # 窥视：PC hover / 移动长按 → tooltip；占位（不阻断主路径）

# 提交一次玩家行动（HUD 经全局名调用 BattleManager.step；不 preload）。
func _submit(skill_id: String, target_id: String) -> void:
	_selected_skill = ""
	_hide_action_panels()
	if BattleManager != null:
		BattleManager.step({"skill_id": skill_id, "target_id": target_id})
	_refresh_all_units()

# ---------- 状态图标（三重冗余）----------
func _on_status_changed(unit_id: String, _type: String, _stacks: int, _turns: int) -> void:
	_rebuild_status(unit_id)

func _on_status_expired(unit_id: String, _type: String) -> void:
	_rebuild_status(unit_id)

func _rebuild_status(unit_id: String) -> void:
	if not _unit_panels.has(unit_id):
		return
	var st = _unit_panels[unit_id]["status"]
	var element: String = _unit_panels[unit_id]["element"]
	_clear_container(st)
	if StatusManager == null:
		return
	for s in StatusManager.get_statuses(unit_id):
		var ic := StatusIcon.new()
		ic.set_status(s.get("type", ""), int(s.get("stacks", 0)), _cfg_max_stacks(s.get("type", "")), int(s.get("turns_left", 0)), element)
		st.add_child(ic)

func _cfg_max_stacks(type: String) -> int:
	var cfg = ConfigLoader.load_table("battle/status_config", "res://data/battle/status_config.json")
	if cfg != null and cfg.get("status", {}).has(type):
		return int(cfg["status"][type].get("max_stacks", 3))
	return 3

# ---------- 刷新全部单位 ----------
func _refresh_all_units() -> void:
	if BattleManager == null:
		return
	for snap in BattleManager.get_all_units():
		var uid: String = snap.get("id", "")
		if not _unit_panels.has(uid):
			continue
		var p: Dictionary = _unit_panels[uid]
		var hp: Label = p["hp"]
		hp.text = "HP %d/%d" % [int(snap.get("hp", 0)), int(snap.get("max_hp", 0))]
		var qi: QiGauge = p["qi"]
		qi.set_qi(int(snap.get("qi", 0)), int(snap.get("qi_max", 3)), snap.get("element", ""))
		_rebuild_status(uid)

func _unit_element(uid: String) -> String:
	if _unit_panels.has(uid):
		return _unit_panels[uid]["element"]
	return ""

# ---------- 双端布局 ----------
# PC ≥1024 多栏（左单位 / 中战场由场景其他层负责 / 右信息 + 底部技能）；
# 移动 <768 精简 HUD（单位卡堆叠、技能栏贴底、无横向滚动）。
func apply_layout(mode: String) -> void:
	if _banner != null:
		_banner._on_layout(mode)
	var mobile := mode == "single"
	var w := get_viewport().size.x if get_viewport() != null else 1280.0
	var h := get_viewport().size.y if get_viewport() != null else 720.0
	if _unit_layer != null:
		_unit_layer.anchor_right = 1.0
		_unit_layer.anchor_bottom = 1.0
		_unit_layer.position = Vector2(8, 64 if not mobile else 56)
		_unit_layer.size = Vector2(w - 16, h * (0.5 if mobile else 0.6))
	if _skill_panel != null:
		_skill_panel.anchor_left = 0.0
		_skill_panel.anchor_right = 1.0
		_skill_panel.anchor_bottom = 1.0
		_skill_panel.anchor_top = 1.0
		_skill_panel.offset_left = 8
		_skill_panel.offset_right = -8
		_skill_panel.offset_bottom = -8
		_skill_panel.offset_top = -((160.0 if mobile else 120.0))
	if _target_panel != null:
		_target_panel.anchor_left = 0.0
		_target_panel.anchor_right = 1.0
		_target_panel.anchor_top = 0.0
		_target_panel.anchor_bottom = 0.0
		_target_panel.offset_top = (h * 0.5 if mobile else h * 0.6)
		_target_panel.offset_left = 8
		_target_panel.offset_right = -8
		_target_panel.custom_minimum_size = Vector2(0, 120)
	queue_redraw_all()

# ---------- 可访问性 ----------
func _on_accessibility(_snap: Dictionary) -> void:
	queue_redraw_all()

func queue_redraw_all() -> void:
	queue_redraw()
	if _banner != null:
		_banner.queue_redraw()
	for uid in _unit_panels.keys():
		var p: Dictionary = _unit_panels[uid]
		if p.has("qi") and is_instance_valid(p["qi"]):
			p["qi"].queue_redraw()

# ---------- 工具 ----------
func _hide_action_panels() -> void:
	if _skill_panel != null:
		_skill_panel.visible = false
	if _target_panel != null:
		_target_panel.visible = false

func _clear_container(c: Container) -> void:
	if c == null:
		return
	for ch in c.get_children():
		ch.queue_free()
