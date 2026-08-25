extends Control
const CARD_SCENE: PackedScene = preload("res://scenes/shared/card_visual.tscn")
func _ready() -> void:
	for suit: String in DeckBuilder.TRUCO_SUITS:
		var title: Label = Label.new(); title.text = CardFormatter.spanish_suit(suit); %Cards.add_child(title)
		var row: HBoxContainer = HBoxContainer.new(); %Cards.add_child(row)
		for rank: String in DeckBuilder.TRUCO_RANKS:
			var card: CardVisual = CARD_SCENE.instantiate() as CardVisual; row.add_child(card)
			card.configure(CardData.make(1, "truco", rank, suit), true, CardVisual.DisplayMode.HISTORY_MINI)
	var back: CardVisual = CARD_SCENE.instantiate() as CardVisual; %Cards.add_child(back)
	back.configure({"game_id":"truco"}, false, CardVisual.DisplayMode.HISTORY_MINI)
