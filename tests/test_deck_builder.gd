# test_deck_builder.gd — E4-S1 卡组构筑（验证驱动）
# 覆盖：编队 4 式神 + 1 法宝位；超出规模拦截；写入 GameState.deck。
extends GutTest


var _db: DeckBuilder


func before_each() -> void:
	ConfigLoader.reset()
	GameState.reset_all()
	_db = DeckBuilder.new()


func after_each() -> void:
	ConfigLoader.reset()


# --- 恰好 4 式神 + 1 法宝 -> 成功写入 GameState.deck ---
func test_set_deck_exactly_four_plus_treasure() -> void:
	var ok := _db.set_deck(["a", "b", "c", "d"], "treasure1")
	assert_true(ok, "4 式神 + 1 法宝 设编队成功")
	assert_eq(GameState.deck, ["a", "b", "c", "d", "treasure1"], "写入 GameState.deck")


# --- 超出 4 式神规模拦截（E4-S1 AC1）---
func test_overrun_intercept() -> void:
	var ok := _db.set_deck(["a", "b", "c", "d", "e"], "")
	assert_false(ok, "5 式神超出规模被拦截")
	assert_eq(GameState.deck, [], "被拦截后 deck 不变")


# --- 增量 add：满 4 后第 5 个拦截 ---
func test_add_shikigami_overrun() -> void:
	assert_true(_db.add_shikigami("a"))
	assert_true(_db.add_shikigami("b"))
	assert_true(_db.add_shikigami("c"))
	assert_true(_db.add_shikigami("d"))
	assert_false(_db.add_shikigami("e"), "已满 4，第 5 个拦截")
	assert_eq(GameState.deck.size(), 4, "deck 仅 4 式神")


# --- 法宝位设置 ---
func test_set_treasure() -> void:
	_db.set_deck(["a", "b", "c", "d"], "")
	assert_true(_db.set_treasure("t1"), "设法宝位成功")
	assert_eq(GameState.deck, ["a", "b", "c", "d", "t1"])


# --- 移除式神 ---
func test_remove_shikigami() -> void:
	_db.add_shikigami("a")
	_db.add_shikigami("b")
	assert_true(_db.remove_shikigami("a"), "移除成功")
	assert_eq(GameState.deck, ["b"], "deck 剩 b")
