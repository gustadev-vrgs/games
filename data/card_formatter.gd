class_name CardFormatter
extends RefCounted

const SPANISH_RANKS: Dictionary = {"1":"Ás", "10":"Valete", "11":"Cavalo", "12":"Rei"}
const SPANISH_SUITS: Dictionary = {"ouros":"Ouros", "espadas":"Espadas", "copas":"Copas", "paus":"Paus"}
const UNO_COLORS: Dictionary = {"red":"Vermelho", "yellow":"Amarelo", "green":"Verde", "blue":"Azul"}
const UNO_ACTIONS: Dictionary = {"wild":"Curinga", "wild_draw_four":"Curinga comprar quatro", "skip":"Bloqueio", "reverse":"Inverter", "draw_two":"Comprar duas"}
const CAXETA_RANKS: Dictionary = {"A":"Ás", "J":"Valete", "Q":"Dama", "K":"Rei"}
const CAXETA_FACE_RANKS: Dictionary = {"A":"A", "J":"V", "Q":"D", "K":"R"}
const CAXETA_SUITS: Dictionary = {"clubs":"Paus", "hearts":"Copas", "spades":"Espadas", "diamonds":"Ouros"}

static func spanish_rank(rank: String) -> String:
	return String(SPANISH_RANKS.get(rank, rank))

static func spanish_suit(suit: String) -> String:
	return String(SPANISH_SUITS.get(suit, suit.capitalize()))

static func card_name(card: Dictionary) -> String:
	if bool(card.get("face_down", false)) or card.is_empty():
		return "Carta encoberta"
	if String(card.get("game_id", "")) == "truco":
		return "%s de %s" % [spanish_rank(String(card.get("rank", ""))), spanish_suit(String(card.get("suit", ""))).to_lower()]
	if String(card.get("game_id", "")) == "uno":
		var action: String = String(card.get("action", ""))
		return String(UNO_ACTIONS.get(action, card.get("rank", "Carta Uno")))
	return "%s de %s" % [caxeta_rank(String(card.get("rank", ""))), caxeta_suit(String(card.get("suit", ""))).to_lower()]

static func uno_color(color: String) -> String:
	return String(UNO_COLORS.get(color, color))

static func cards(count: int) -> String:
	return "%d %s" % [count, "carta" if count == 1 else "cartas"]

static func players(count: int) -> String:
	return "%d %s" % [count, "jogador" if count == 1 else "jogadores"]

static func caxeta_rank(rank: String) -> String:
	return String(CAXETA_RANKS.get(rank, rank))

static func caxeta_face_rank(rank: String) -> String:
	return String(CAXETA_FACE_RANKS.get(rank, rank))

static func caxeta_suit(suit: String) -> String:
	return String(CAXETA_SUITS.get(suit, suit))

static func uno_action(action: String) -> String:
	return String(UNO_ACTIONS.get(action, action))
