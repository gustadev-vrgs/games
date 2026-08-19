extends GameUI
func _ready()->void:
	super()
	%Draw.pressed.connect(func()->void:send("DRAW_ONE" if "truco"=="uno" else "DRAW_PILE"))
	%Pass.pressed.connect(func()->void:send("PASS"))
	%Knock.pressed.connect(func()->void:send("KNOCK_TEN"))
	%Truco.pressed.connect(func()->void:send("REQUEST_TRUCO"))
	%Accept.pressed.connect(func()->void:send("ACCEPT"))
	%Run.pressed.connect(func()->void:send("RUN"))
	%Raise.pressed.connect(func()->void:send("RAISE"))
	%Color.visible="truco"=="uno";%DeclareUno.visible="truco"=="uno"
	%Knock.visible="truco"=="caxeta";%KnockNormal.visible="truco"=="caxeta";%Truco.visible="truco"=="truco";%Accept.visible="truco"=="truco";%Run.visible="truco"=="truco";%Raise.visible="truco"=="truco"
