extends RefCounted
## TownActions
##
## What happens when the player presses Enter at a spot in town: the shop,
## notice board, reflecting pool, foraging, gates, memorial, dice, bureau
## files and so on. main.gd finds the spot and calls run(); everything here
## is shown through the MenuUI or a small toast message.
##
## To add a new kind of spot: give it a "kind" in map_data.gd, then add a
## branch to run() and a function below.

const SHOP_STOCK_SIZE := 6
const DRINK_PRICE := 3
const POOL_PRICE := 1

const JUNK_ITEMS := ["rusty_knife", "old_coin", "old_photograph", "bone_dice", "paperback", "wooden_toy", "black_candle"]
const CREEK_ITEMS := ["old_coin", "prayer_beads", "holy_water", "sketchbook", "old_photograph", "herbal_tea"]

const CANDLE_LINES := [
	"You light a candle. The flame leans toward the unfinished roof, as if trying to reach it.",
	"You light a candle and whisper a wish. The chapel says nothing. It never has.",
	"The candle catches at once. Somewhere above, a hammer taps twice, then stops.",
]
const DRINK_LINES := [
	"It tastes like tap water with regret.",
	"Watered down. Of course it is. You find you don't mind.",
	"The barkeep pours it with terrifying confidence. It's mostly water.",
]

var main # the Main scene (left untyped on purpose)
var menu # the MenuUI


func _init(p_main, p_menu) -> void:
	main = p_main
	menu = p_menu


func run(spot: Dictionary) -> void:
	match str(spot.get("kind", "")):
		"shop":
			_open_shop()
		"board":
			_open_board()
		"pool":
			_open_pool()
		"forage":
			_forage(spot)
		"gate":
			_visit_gate(str(spot.get("gate", "bright")))
		"memorial":
			_open_memorial()
		"junk":
			_dig_junk()
		"creek":
			_fish()
		"candle":
			_light_candle()
		"drink":
			_order_drink()
		"dice":
			_open_dice("")
		"bureau_desk":
			_open_bureau()
		"number":
			_take_number()
		_:
			push_warning("TownActions: unknown spot kind '%s'" % str(spot.get("kind", "")))


# ------------------------------------------------------------ helpers

func _item_name(item_id: String) -> String:
	return str(CharacterDB.get_item(item_id).get("name", item_id))


func _char_name(character_id: String) -> String:
	return str(CharacterDB.get_character(character_id).get("name", character_id))


func _price(item_id: String) -> int:
	return int(CharacterDB.get_item(item_id).get("price", 8))


func _sell_value(item_id: String) -> int:
	return maxi(1, int(_price(item_id) * 0.4))


func _seeded_shuffle(ids: Array, seed_value: int) -> Array:
	# The same seed always gives the same order, so the shop and the
	# notice board stay consistent all day.
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var result := ids.duplicate()

	for i in range(result.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var swap: Variant = result[i]
		result[i] = result[j]
		result[j] = swap

	return result


func _item_ids() -> Array:
	var ids: Array = []
	for item in CharacterDB.get_all_items():
		ids.append(str(item.get("id", "")))
	return ids


func _items_with_tier(character_id: String, tier: String) -> Array:
	var result: Array = []
	for item_id in _item_ids():
		if CharacterDB.get_gift_tier(character_id, item_id) == tier:
			result.append(item_id)
	return result


func _day_text(day: int) -> String:
	return "Day %d" % day if day > 0 else "Day ?"


func _standing_text(character_id: String) -> String:
	var score := Relationships.get_score(character_id)

	if score > 0:
		return "Hearts: %d / 10" % score
	if score < 0:
		return "Skulls: %d / 10" % absi(score)

	return "Strangers"


# --------------------------------------------------------------- shop

func _shop_stock() -> Array:
	var shuffled := _seeded_shuffle(_item_ids(), Relationships.current_day * 7919 + 13)
	return shuffled.slice(0, SHOP_STOCK_SIZE)


func _open_shop() -> void:
	var options: Array = []

	for item_id in _shop_stock():
		var price := _price(str(item_id))
		options.append({
			"label": "Buy: %s   (%d coins)" % [_item_name(str(item_id)), price],
			"disabled": Relationships.coins < price,
			"call": _buy.bind(str(item_id)),
		})

	options.append({"label": "Sell something of yours...", "call": _open_sell})

	menu.open(
		"Lost & Found",
		"\"Everything here belonged to somebody. Now it belongs to whoever pays.\"\n\nYou have %d coins. The selection changes every day." % Relationships.coins,
		options
	)


func _buy(item_id: String) -> void:
	if Relationships.spend_coins(_price(item_id)):
		Relationships.add_item(item_id)
		main.show_toast("Bought %s." % _item_name(item_id))

	_open_shop()


func _open_sell() -> void:
	var options: Array = []

	for item_id in Relationships.owned_item_ids():
		var id := str(item_id)
		options.append({
			"label": "Sell: %s (x%d)   (%d coins each)" % [_item_name(id), Relationships.item_count(id), _sell_value(id)],
			"call": _sell.bind(id),
		})

	options.append({"label": "Back to the counter", "call": _open_shop})

	var body := "You have %d coins." % Relationships.coins
	if options.size() == 1:
		body = "You aren't carrying anything to sell."

	menu.open("Lost & Found: Selling", body, options)


func _sell(item_id: String) -> void:
	if Relationships.remove_item(item_id):
		Relationships.add_coins(_sell_value(item_id))
		main.show_toast("Sold %s." % _item_name(item_id))

	_open_sell()


# -------------------------------------------------------- notice board

func _board_requests() -> Array:
	var day := int(Relationships.board.get("day", 0))

	if day != Relationships.current_day:
		Relationships.board = _generate_requests()
		Relationships.save_data()

	return Relationships.board.get("requests", [])


func _generate_requests() -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = Relationships.current_day * 104729 + 17

	var requests: Array = []
	var residents := _seeded_shuffle(Roster.active_ids, rng.randi())

	for character_id in residents:
		if requests.size() >= 3:
			break

		var tier := "love"
		var wanted := _items_with_tier(str(character_id), "love")
		if wanted.is_empty():
			tier = "like"
			wanted = _items_with_tier(str(character_id), "like")
		if wanted.is_empty():
			continue

		var item_id := str(wanted[rng.randi_range(0, wanted.size() - 1)])
		requests.append({
			"character": str(character_id),
			"item": item_id,
			"tier": tier,
			"reward": _price(item_id) + 6,
			"done": false,
		})

	return {"day": Relationships.current_day, "requests": requests}


func _open_board() -> void:
	var requests := _board_requests()
	var lines: Array = []
	var options: Array = []

	for i in requests.size():
		var request: Dictionary = requests[i]
		var character_id := str(request.get("character", ""))
		var item_id := str(request.get("item", ""))
		var reward := int(request.get("reward", 0))
		var done := bool(request.get("done", false))

		# Reading a request teaches you something about that resident.
		Relationships.record_taste(character_id, item_id, str(request.get("tier", "love")))

		lines.append("%s is hoping someone brings them the %s. %s" % [
			_char_name(character_id), _item_name(item_id), "(Done.)" if done else ""])

		var have := Relationships.item_count(item_id) > 0
		var label := "Give the %s to %s   (+%d coins)" % [_item_name(item_id), _char_name(character_id), reward]
		if not done and not have:
			label += "   - you don't have one"

		options.append({
			"label": "Delivered: %s" % _char_name(character_id) if done else label,
			"disabled": done or not have,
			"call": _deliver.bind(i),
		})

	var body := "Today's requests. Neighbours pay in coins, and it's a decent hint about what they like.\n\n" + "\n".join(lines)
	if requests.is_empty():
		body = "The board is empty. Nobody in town needs anything today."

	menu.open("Notice Board", body, options)


func _deliver(index: int) -> void:
	var requests := _board_requests()
	if index >= requests.size():
		return

	var request: Dictionary = requests[index]
	var item_id := str(request.get("item", ""))

	if bool(request.get("done", false)) or not Relationships.remove_item(item_id):
		_open_board()
		return

	request["done"] = true
	Relationships.add_coins(int(request.get("reward", 0)))
	main.show_toast("%s thanks you. +%d coins." % [_char_name(str(request.get("character", ""))), int(request.get("reward", 0))])
	_open_board()


# ------------------------------------------------------ reflecting pool

func _open_pool() -> void:
	if Relationships.flag_today("pool"):
		menu.open("The Reflecting Pool", "The water is still. Whatever it had to show you today, it already has.")
		return

	menu.open(
		"The Reflecting Pool",
		"The water is clear, and deeper than it should be. Toss in a coin and it might show you something about one of your neighbours. Once a day.",
		[{
			"label": "Toss in a coin   (%d coin)" % POOL_PRICE,
			"disabled": Relationships.coins < POOL_PRICE,
			"call": _toss_coin,
		}]
	)


func _toss_coin() -> void:
	if not Relationships.spend_coins(POOL_PRICE):
		_open_pool()
		return

	Relationships.set_flag_today("pool")

	if Roster.active_ids.is_empty():
		menu.open("The Reflecting Pool", "The water ripples, and shows you nothing but yourself.")
		return

	var character_id := str(Roster.active_ids[randi() % Roster.active_ids.size()])
	var loved := _items_with_tier(character_id, "love")
	var hated := _items_with_tier(character_id, "hate")

	var show_love := randf() < 0.5
	if show_love and loved.is_empty():
		show_love = false
	if not show_love and hated.is_empty():
		show_love = true

	var pool: Array = loved if show_love else hated
	if pool.is_empty():
		menu.open("The Reflecting Pool", "The water ripples, and shows you nothing you can make sense of.")
		return

	var item_id := str(pool[randi() % pool.size()])
	var resident := _char_name(character_id)

	if show_love:
		Relationships.record_taste(character_id, item_id, "love")
		menu.open("The Reflecting Pool", "The water clears. You see %s smiling down at the %s." % [resident, _item_name(item_id)])
	else:
		Relationships.record_taste(character_id, item_id, "hate")
		menu.open("The Reflecting Pool", "The water darkens. You see %s flinching away from the %s." % [resident, _item_name(item_id)])


# ------------------------------------- foraging, junk, creek, candle, drink

func _forage(spot: Dictionary) -> void:
	var key := "forage:%s" % str(spot.get("id", ""))
	var place := str(spot.get("name", "this spot"))

	if Relationships.flag_today(key):
		main.show_toast("You've already picked over %s today. It will grow back by morning." % place)
		return

	Relationships.set_flag_today(key)
	var item_id := str(spot.get("item", ""))
	var amount := randi_range(1, 2)
	Relationships.add_item(item_id, amount)
	main.show_toast("You gather %d x %s." % [amount, _item_name(item_id)])


func _dig_junk() -> void:
	if Relationships.flag_today("junk"):
		main.show_toast("You've already picked through everything worth taking today.")
		return

	Relationships.set_flag_today("junk")
	_find_something(JUNK_ITEMS, "You dig up:", "Under the scrap you find %d coins.")


func _fish() -> void:
	if Relationships.flag_today("creek"):
		main.show_toast("The creek has nothing more to give you today.")
		return

	Relationships.set_flag_today("creek")
	_find_something(CREEK_ITEMS, "You fish something out of the water:", "Something glints in the mud: %d coins.")


func _find_something(pool: Array, item_text: String, coin_text: String) -> void:
	var valid: Array = []
	for item_id in pool:
		if not CharacterDB.get_item(str(item_id)).is_empty():
			valid.append(str(item_id))

	if valid.is_empty() or randf() < 0.4:
		var coins := randi_range(3, 8)
		Relationships.add_coins(coins)
		main.show_toast(coin_text % coins)
		return

	var found := str(valid[randi() % valid.size()])
	Relationships.add_item(found)
	main.show_toast("%s %s." % [item_text, _item_name(found)])


func _light_candle() -> void:
	main.show_toast(str(CANDLE_LINES[randi() % CANDLE_LINES.size()]))


func _order_drink() -> void:
	if not Relationships.spend_coins(DRINK_PRICE):
		main.show_toast("A drink costs %d coins. You can't quite scrape that together." % DRINK_PRICE)
		return

	main.show_toast(str(DRINK_LINES[randi() % DRINK_LINES.size()]))


func _take_number() -> void:
	main.show_toast("You take number %d. Now serving: 12." % randi_range(4000000, 4999999))


# ------------------------------------------------------------ gates

func _visit_gate(gate: String) -> void:
	var count := 0
	for id in Roster.departures.keys():
		if str(Roster.departures[id].get("gate", "")) == gate:
			count += 1

	var passed := "%d souls have passed through so far." % count
	if count == 1:
		passed = "One soul has passed through so far."
	elif count == 0:
		passed = "Nobody has passed through yet."

	if gate == "bright":
		menu.open("The Bright Gate", "Warm light spills out, and it smells like rain and fresh bread. It isn't for you. Not yet.\n\n" + passed)
	else:
		menu.open("The Ember Gate", "The air above the gate shimmers with heat, and something on the other side is laughing. It isn't for you either. Not yet.\n\n" + passed)


# --------------------------------------------------------- memorial

func _open_memorial() -> void:
	var lines: Array = []

	for id in Roster.departed_ids:
		var record: Dictionary = Roster.departures.get(str(id), {})
		var gate := "bright" if str(record.get("gate", "bright")) == "bright" else "ember"
		var mood := "fond of you" if str(record.get("mood", "hearts")) == "hearts" else "no friend of yours"
		lines.append("%s.  %s.  Through the %s gate, %s." % [_char_name(str(id)), _day_text(int(record.get("day", 0))), gate, mood])

	var body := "Nobody has left yet. The markers are ready, and so, in their way, are the gates."
	if not lines.is_empty():
		body = "Each marker is for someone whose case was called.\n\n" + "\n".join(lines)

	menu.open("Memorial Garden", body)


# ----------------------------------------------------------- bureau

func _open_bureau() -> void:
	menu.open(
		"Bureau of Case Review",
		"\"Please take a seat. Please do not take a seat. Someone will be with you shortly.\"",
		[
			{"label": "Look through the resident files", "call": _open_files},
			{"label": "Check on your own case", "call": _check_own_case},
		]
	)


func _open_files() -> void:
	var options: Array = []

	for id in Roster.active_ids + Roster.departed_ids:
		var closed := Roster.departed_ids.has(id)
		options.append({
			"label": _char_name(str(id)) + ("   (case closed)" if closed else ""),
			"call": _show_file.bind(str(id)),
		})

	options.append({"label": "Back", "call": _open_bureau})
	menu.open("Resident Files", "Handle with care. Or don't. Nobody checks.", options)


func _show_file(character_id: String) -> void:
	var lines: Array = ["Standing: %s" % _standing_text(character_id)]

	if Roster.departed_ids.has(character_id):
		var record: Dictionary = Roster.departures.get(character_id, {})
		lines.append("Status: CLOSED. %s, through the %s gate." % [_day_text(int(record.get("day", 0))), str(record.get("gate", "bright"))])
	else:
		lines.append("Status: PENDING REVIEW")

	var tastes: Dictionary = Relationships.known_tastes.get(character_id, {})
	var buckets := {"love": [], "like": [], "neutral": [], "dislike": [], "hate": []}
	var headings := {"love": "Loves", "like": "Likes", "neutral": "Indifferent to", "dislike": "Dislikes", "hate": "Hates"}

	for item_id in tastes.keys():
		var tier := str(tastes[item_id])
		if buckets.has(tier):
			buckets[tier].append(_item_name(str(item_id)))

	var learned := false
	for tier in ["love", "like", "neutral", "dislike", "hate"]:
		if not buckets[tier].is_empty():
			learned = true
			lines.append("%s: %s" % [headings[tier], ", ".join(buckets[tier])])

	if not learned:
		lines.append("You haven't learned anything about their tastes yet.")

	menu.open(_char_name(character_id), "\n".join(lines), [{"label": "Back to the files", "call": _open_files}])


func _check_own_case() -> void:
	var body := "File: Case #%d\nStatus: PENDING REVIEW\nDays waiting: %d\nEstimated review date: [ILLEGIBLE]\n\nA stamp on the folder reads: NOT YET." % [
		4000000 + Relationships.current_day * 37, Relationships.current_day]
	menu.open("Your Case", body, [{"label": "Back", "call": _open_bureau}])


# ------------------------------------------------------------- dice

func _open_dice(result: String) -> void:
	var options: Array = []

	for bet in [2, 5, 10]:
		options.append({
			"label": "Bet %d coins" % bet,
			"disabled": Relationships.coins < bet,
			"call": _roll.bind(bet),
		})

	var body := "Two dice each. Highest total wins. The house wins ties. The bone dice seem to land on the same numbers a lot, but that's probably nothing.\n\nYou have %d coins." % Relationships.coins
	if result != "":
		body = result + "\n\nYou have %d coins." % Relationships.coins

	menu.open("Bone Dice", body, options)


func _roll(bet: int) -> void:
	var mine := randi_range(1, 6) + randi_range(1, 6)
	var house := randi_range(1, 6) + randi_range(1, 6)
	var result := ""

	if mine > house:
		Relationships.add_coins(bet)
		result = "You rolled %d. The house rolled %d. You win %d coins!" % [mine, house, bet]
	elif mine == house:
		Relationships.add_coins(-bet)
		result = "You both rolled %d. Ties go to the house. You lose %d coins." % [mine, bet]
	else:
		Relationships.add_coins(-bet)
		result = "You rolled %d. The house rolled %d. You lose %d coins." % [mine, house, bet]

	_open_dice(result)
