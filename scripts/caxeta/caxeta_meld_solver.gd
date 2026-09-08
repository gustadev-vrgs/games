class_name CaxetaMeldSolver
extends RefCounted
const RANKS: PackedStringArray = ["A","2","3","4","5","6","7","8","9","10","J","Q","K"]
var _memo: Dictionary = {}
func can_partition_into_melds(cards: Array, _legacy_wild: Dictionary = {}) -> Dictionary:
	_memo.clear()
	var copied_cards: Array = cards.duplicate(true) as Array
	var result: Variant = _solve(copied_cards)
	var melds: Array = []
	if result != null:
		melds = result as Array
	return {"valid":result != null,"melds":melds}
func _solve(cards: Array) -> Variant:
	if cards.is_empty(): return []
	cards.sort_custom(func(a: Dictionary,b: Dictionary) -> bool: return a.uid < b.uid)
	var key: PackedInt32Array = PackedInt32Array(cards.map(func(card: Dictionary) -> int: return int(card.get("uid", -1))))
	var cache_key: String = str(key)
	if _memo.has(cache_key): return _memo[cache_key]
	var first: Dictionary = cards[0]
	for meld in _candidate_melds(cards):
		var contains: bool = false
		for item in meld:
			if item.uid == first.uid: contains = true
		if not contains: continue
		var remaining: Array = cards.filter(func(card: Dictionary) -> bool:
			for item in meld:
				if item.uid == card.uid: return false
			return true)
		var rest: Variant = _solve(remaining)
		if rest != null:
			var solved_rest: Array = rest as Array
			var answer: Array = [meld]
			answer.append_array(solved_rest)
			_memo[cache_key] = answer
			return answer
	_memo[cache_key] = null; return null
func _candidate_melds(cards: Array) -> Array:
	var result: Array = []
	for a in range(cards.size()):
		for b in range(a+1,cards.size()):
			for c in range(b+1,cards.size()):
				var triple: Array = [cards[a],cards[b],cards[c]]
				if is_set(triple) or is_run(triple): result.append(triple)
	# Ten cards require at least one four-card meld (3 + 3 + 4). Generate every
	# longer subset here so both runs and four-of-a-kind sets can participate.
	for size in range(4,cards.size()+1):
		_combinations(cards,size,0,[],result)
	return result
func _combinations(cards: Array, size: int, start: int, chosen: Array, output: Array) -> void:
	if chosen.size() == size:
		if is_set(chosen) or is_run(chosen): output.append(chosen.duplicate())
		return
	for index in range(start,cards.size()):
		chosen.append(cards[index]); _combinations(cards,size,index+1,chosen,output); chosen.pop_back()
func _is_joker(card: Dictionary) -> bool: return String(card.get("rank", "")) == "JOKER"
func is_set(cards: Array, _legacy_wild: Dictionary = {}) -> bool:
	if cards.size() not in [3, 4]: return false
	var rank: String = ""; var suits: Dictionary = {}; var wilds: int = 0
	for card in cards:
		if _is_joker(card): wilds += 1; continue
		if rank.is_empty(): rank = card.rank
		if card.rank != rank or suits.has(card.suit): return false
		suits[card.suit] = true
	return wilds <= 1 and not rank.is_empty()
func is_run(cards: Array, _legacy_wild: Dictionary = {}) -> bool:
	if cards.size() < 3: return false
	var naturals: Array = []; var wilds: int = 0; var suit: String = ""
	for card in cards:
		if _is_joker(card): wilds += 1; continue
		if suit.is_empty(): suit = card.suit
		if card.suit != suit: return false
		naturals.append(RANKS.find(card.rank))
	if wilds > 1 or naturals.size() < 2: return false
	for ace_high in [false,true]:
		var values: Array = naturals.duplicate() as Array
		if ace_high:
			for index in values.size():
				if values[index] == 0: values[index] = 13
		values.sort()
		var gaps: int = 0
		for index in range(1,values.size()):
			if values[index] == values[index-1]: gaps = 99; break
			gaps += values[index]-values[index-1]-1
		if gaps <= wilds and values.back()-values.front()+1 <= cards.size(): return true
	return false
