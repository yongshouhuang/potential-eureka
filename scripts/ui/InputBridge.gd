# InputBridge.gd — S3-UI-Battle UI 层输入抽象（scripts/ui，非 autoload）
# 双端输入抽象：drag / long_press / hover_peek / select，供选技 / 目标选择 / 气槽使用。
# PC 用 hover/click、移动用 drag/long_press；底层由 autoload InputBridge 统一归一为意图，
# 本层再把意图翻译成「战斗语义手势」信号（skill_picked / target_picked / qi_picked / peeked），
# 业务（BattleHUD）只认语义手势，不直连硬件事件（对齐 ADR-003 / ux-spec §3）。
# 不 preload 任何管理器——仅经全局 autoload 名 InputBridge / EventBus 通信。
extends Node

class_name BattleInputBridge

signal skill_picked(skill_id: String)
signal target_picked(unit_id: String)
signal qi_picked(index: int)
signal peeked(payload: Dictionary)

func _ready() -> void:
	# autoload InputBridge 的原始意图 → 统一转发为「窥视」语义（PC hover / 移动 long_press 等价）
	if InputBridge != null:
		if InputBridge.has_signal("hover_peeked"):
			InputBridge.hover_peeked.connect(_on_peek)
		if InputBridge.has_signal("long_pressed"):
			InputBridge.long_pressed.connect(_on_peek)

func _on_peek(payload = null) -> void:
	peeked.emit(payload if payload is Dictionary else {})

# ---- 绑定工具：把控件手势经 autoload InputBridge 转发 + 发语义信号 ----
# 选技按钮（SkillButton 自带 PC 点击/移动 Tap=选技、右键/长按=窥视）。
func bind_skill(btn: SkillButton) -> void:
	if btn == null:
		return
	btn.skill_selected.connect(_on_skill_selected)
	btn.skill_peeked.connect(_on_skill_peek)

func _on_skill_selected(skill_id: String) -> void:
	if InputBridge != null:
		InputBridge.inject_intent(InputBridge.INTENT_SELECT, {"type": "skill", "id": skill_id})
	skill_picked.emit(skill_id)

func _on_skill_peek(skill_id: String) -> void:
	peeked.emit({"type": "skill", "id": skill_id})

# 目标选择控件（敌方单位卡）。点击/拖拽落点 = 选目标。
func bind_target(ctrl: Control, unit_id: String) -> void:
	if ctrl == null:
		return
	ctrl.gui_input.connect(_on_target_gui.bind(unit_id))

func _on_target_gui(unit_id: String, event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT:
			_emit_target(unit_id)
	elif event is InputEventScreenTouch:
		var st := event as InputEventScreenTouch
		if st.pressed:
			_emit_target(unit_id)

func _emit_target(unit_id: String) -> void:
	if InputBridge != null:
		InputBridge.inject_intent(InputBridge.INTENT_SELECT, {"type": "target", "id": unit_id})
	target_picked.emit(unit_id)

# 气格 pip（点击气格 = 选气 / 查看）。index 为第几格。
func bind_qi(ctrl: Control, index: int) -> void:
	if ctrl == null:
		return
	ctrl.gui_input.connect(_on_qi_gui.bind(index))

func _on_qi_gui(index: int, event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT:
			_emit_qi(index)
	elif event is InputEventScreenTouch:
		var st := event as InputEventScreenTouch
		if st.pressed:
			_emit_qi(index)

func _emit_qi(index: int) -> void:
	if InputBridge != null:
		InputBridge.inject_intent(InputBridge.INTENT_SELECT, {"type": "qi", "index": index})
	qi_picked.emit(index)

# 拖拽落点（PC 拖拽出招 / 移动滑动出招）→ 选目标。由 BattleHUD 在 drag 时调用。
func emit_drag_target(unit_id: String) -> void:
	if InputBridge != null:
		InputBridge.inject_intent(InputBridge.INTENT_DRAG_END, {"type": "target", "id": unit_id})
	target_picked.emit(unit_id)
