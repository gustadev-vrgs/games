class_name TestDecks
extends RefCounted
func run(t:TestHelpers)->void:
	var truco:Array[Dictionary]=DeckBuilder.build_truco();var caxeta:Array[Dictionary]=DeckBuilder.build_caxeta();var uno:Array[Dictionary]=DeckBuilder.build_uno()
	t.equal(truco.size(),40,"Truco tem 40");t.equal(caxeta.size(),104,"Caxeta tem 104");t.equal(uno.size(),108,"Uno tem 108")
	t.check(DeckBuilder.validate_unique_uids(truco),"UID Truco");t.check(DeckBuilder.validate_unique_uids(caxeta),"UID Caxeta");t.check(DeckBuilder.validate_unique_uids(uno),"UID Uno")
	for suit in DeckBuilder.TRUCO_SUITS:t.equal(truco.filter(func(c:Dictionary)->bool:return c.suit==suit).size(),10,"10 por naipe espanhol")
	t.equal(TrucoSpanishCardTextures.validate_catalog().size(), 0, "catálogo espanhol completo")
	t.equal(CaxetaCardTextures.validate_catalog().size(), 0, "catálogo Caxeta completo")
	for card: Dictionary in caxeta:
		var path: String = CaxetaCardTextures.face_path(String(card.rank), String(card.suit))
		t.check(ResourceLoader.exists(path), "frente Caxeta existe: " + path)
		t.check(CaxetaCardTextures.load_face(String(card.rank), String(card.suit)) is Texture2D, "frente Caxeta carrega como Texture2D")
	var first_copy: Dictionary = caxeta[0]
	var second_copy: Dictionary = caxeta[52]
	t.equal(first_copy.rank, second_copy.rank, "cópias mantêm o mesmo rank")
	t.equal(first_copy.suit, second_copy.suit, "cópias mantêm o mesmo naipe")
	t.check(first_copy.uid != second_copy.uid, "cópias da Caxeta têm UIDs distintos")
	t.check(CaxetaCardTextures.load_face(String(first_copy.rank), String(first_copy.suit)) == CaxetaCardTextures.load_face(String(second_copy.rank), String(second_copy.suit)), "cópias reutilizam a textura em cache")
	t.equal(CaxetaCardTextures.load_face("INVALID", "missing"), null, "textura ausente usa fallback")
	for card: Dictionary in truco:
		var path: String = TrucoSpanishCardTextures.face_path(String(card.rank), String(card.suit))
		t.check(ResourceLoader.exists(path), "frente espanhola existe: " + path)
		t.check(load(path) is Texture2D, "frente espanhola carrega como Texture2D")
	t.check(ResourceLoader.exists(TrucoSpanishCardTextures.BACK_PATH), "verso espanhol existe")
	t.check(TrucoSpanishCardTextures.load_back() is Texture2D, "verso espanhol carrega como Texture2D")
	t.equal(CardFormatter.card_name(CardData.make(1, "truco", "11", "copas")), "Cavalo de copas", "Truco localizado")
	t.equal(CardFormatter.card_name(CardData.make(1, "caxeta", "Q", "hearts")), "Dama de copas", "Caxeta localizada sem alterar ID")
	t.equal(CardFormatter.card_name(CardData.make(1, "uno", "", "", "blue", "skip")), "Bloqueio", "Uno localizado")
	t.equal(CardFormatter.cards(1), "1 carta", "singular de carta")
	t.equal(CardFormatter.cards(2), "2 cartas", "plural de carta")
	t.equal(CardFormatter.players(1), "1 jogador", "singular de jogador")
	for color in DeckBuilder.UNO_COLORS:
		t.equal(uno.filter(func(c:Dictionary)->bool:return c.color==color and c.rank=="0").size(),1,"zero por cor")
		t.equal(uno.filter(func(c:Dictionary)->bool:return c.color==color and c.action=="skip").size(),2,"skip por cor")
	t.equal(uno.filter(func(c:Dictionary)->bool:return c.action=="wild").size(),4,"quatro wild")
	t.equal(uno.filter(func(c:Dictionary)->bool:return c.action=="wild_draw_four").size(),4,"quatro +4")
	var a:RandomNumberGenerator=RandomNumberGenerator.new();var b:RandomNumberGenerator=RandomNumberGenerator.new();a.seed=42;b.seed=42
	t.equal(DeckBuilder.shuffle(uno,a),DeckBuilder.shuffle(uno,b),"shuffle determinístico")
