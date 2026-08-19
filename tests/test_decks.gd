class_name TestDecks
extends RefCounted
func run(t:TestHelpers)->void:
	var truco:=DeckBuilder.build_truco();var caxeta:=DeckBuilder.build_caxeta();var uno:=DeckBuilder.build_uno()
	t.equal(truco.size(),40,"Truco tem 40");t.equal(caxeta.size(),104,"Caxeta tem 104");t.equal(uno.size(),108,"Uno tem 108")
	t.check(DeckBuilder.validate_unique_uids(truco),"UID Truco");t.check(DeckBuilder.validate_unique_uids(caxeta),"UID Caxeta");t.check(DeckBuilder.validate_unique_uids(uno),"UID Uno")
	for suit in DeckBuilder.SUITS:t.equal(truco.filter(func(c:Dictionary)->bool:return c.suit==suit).size(),10,"10 por naipe")
	for color in DeckBuilder.UNO_COLORS:
		t.equal(uno.filter(func(c:Dictionary)->bool:return c.color==color and c.rank=="0").size(),1,"zero por cor")
		t.equal(uno.filter(func(c:Dictionary)->bool:return c.color==color and c.action=="skip").size(),2,"skip por cor")
	t.equal(uno.filter(func(c:Dictionary)->bool:return c.action=="wild").size(),4,"quatro wild")
	t.equal(uno.filter(func(c:Dictionary)->bool:return c.action=="wild_draw_four").size(),4,"quatro +4")
	var a:=RandomNumberGenerator.new();var b:=RandomNumberGenerator.new();a.seed=42;b.seed=42
	t.equal(DeckBuilder.shuffle(uno,a),DeckBuilder.shuffle(uno,b),"shuffle determinístico")
