# InputBridge.gd — 输入抽象层（ADR-003 / E6-S2）
# 将键鼠与触控统一归一为抽象意图，屏幕只订阅意图、不直连硬件事件。
# 必须可单元注入：测试调用 inject_intent(...) 即可触发对应信号，无需真实设备。
extends Node

# 抽象意图信号（业务屏只认这些）
signal ui_select(payload = null)
signal ui_back(payload = null)
signal drag_started(payload = null)
signal drag_ended(payload = null)
signal long_pressed(payload = null)
signal hover_peeked(payload = null)

# 意图名常量（inject_intent 用）
const INTENT_SELECT := "ui_select"
const INTENT_BACK := "ui_back"
const INTENT_DRAG_START := "drag_start"
const INTENT_DRAG_END := "drag_end"
const INTENT_LONG_PRESS := "long_press"
const INTENT_HOVER_PEEK := "hover_peek"


# 单元注入入口：直接发出对应抽象意图信号（不依赖真实输入设备）
func inject_intent(intent: String, payload = null) -> void:
	match intent:
		INTENT_SELECT:
			ui_select.emit(payload)
		INTENT_BACK:
			ui_back.emit(payload)
		INTENT_DRAG_START:
			drag_started.emit(payload)
		INTENT_DRAG_END:
			drag_ended.emit(payload)
		INTENT_LONG_PRESS:
			long_pressed.emit(payload)
		INTENT_HOVER_PEEK:
			hover_peeked.emit(payload)
		_:
			push_warning("InputBridge: 未知意图 " + intent)


# 真实设备映射（场景运行时启用；测试不走此路径）。
# PC：左键/Enter/空格 -> ui_select；Esc/返回 -> ui_back；拖拽 -> drag；
#     右键长按 -> long_press；悬停 -> hover_peek。
# 移动：Tap -> ui_select；系统返回/底部 Tab -> ui_back；拖拽/滑动 -> drag；
#     长按 -> long_press；无 hover（由 long_press 承接）。
func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT:
			inject_intent(INTENT_SELECT)
		elif mb.pressed and mb.button_index == MOUSE_BUTTON_RIGHT:
			inject_intent(INTENT_LONG_PRESS)
	elif event is InputEventKey:
		var k := event as InputEventKey
		if k.pressed:
			if k.keycode == KEY_ESCAPE:
				inject_intent(INTENT_BACK)
			elif k.keycode == KEY_ENTER or k.keycode == KEY_SPACE:
				inject_intent(INTENT_SELECT)
	elif event is InputEventScreenTouch:
		var st := event as InputEventScreenTouch
		if st.pressed:
			inject_intent(INTENT_SELECT)
	elif event is InputEventScreenDrag:
		# 拖拽由具体控件分发 drag_start/drag_end；此处仅作钩子占位
		pass
