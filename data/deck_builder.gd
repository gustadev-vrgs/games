class_name DeckBuilder
extends RefCounted
const SUITS: PackedStringArray = ["diamonds","spades","hearts","clubs"]
const TRUCO_RANKS: PackedStringArray = ["4","5","6","7","Q","J","K","A","2","3"]
const CAXETA_RANKS: PackedStringArray = ["A","2","3","4","5","6","7","8","9","10","J","Q","K"]
const UNO_COLORS: PackedStringArray = ["red","yellow","green","blue"]
static func build_truco() -> Array[Dictionary]:
	var deck: Array[Dictionary] = []; var uid := 1
	for suit in SUITS:
		for rank in TRUCO_RANKS: deck.append(CardData.make(uid,"truco",rank,suit)); uid += 1
	return deck
static func build_caxeta() -> Array[Dictionary]:
	var deck: Array[Dictionary] = []; var uid := 1
	for copy in 2:
		for suit in SUITS:
			for rank in CAXETA_RANKS: deck.append(CardData.make(uid,"caxeta",rank,suit,"","",copy)); uid += 1
	return deck
static func build_uno() -> Array[Dictionary]:
	var deck: Array[Dictionary] = []; var uid := 1
	for color in UNO_COLORS:
		deck.append(CardData.make(uid,"uno","0","",color)); uid += 1
		for rank_value in range(1,10):
			for copy in 2: deck.append(CardData.make(uid,"uno",str(rank_value),"",color,"",copy)); uid += 1
		for action in ["draw_two","reverse","skip"]:
			for copy in 2: deck.append(CardData.make(uid,"uno","","",color,action,copy)); uid += 1
	for copy in 4: deck.append(CardData.make(uid,"uno","","","","wild",copy)); uid += 1
	for copy in 4: deck.append(CardData.make(uid,"uno","","","","wild_draw_four",copy)); uid += 1
	return deck
static func shuffle(cards: Array[Dictionary], rng: RandomNumberGenerator) -> Array[Dictionary]:
	var result: Array[Dictionary] = cards.duplicate(true)
	for index in range(result.size()-1,0,-1):
		var swap_index := rng.randi_range(0,index); var temporary := result[index]; result[index] = result[swap_index]; result[swap_index] = temporary
	return result
static func validate_unique_uids(cards: Array[Dictionary]) -> bool:
	var seen := {}
	for card in cards:
		var uid: int = card.get("uid",-1)
		if uid <= 0 or seen.has(uid): return false
		seen[uid] = true
	return true
