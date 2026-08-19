extends GameUI
func _ready()->void:
	super()
	%Draw.pressed.connect(func()->void:send("DRAW_ONE" if "uno"=="uno" else "DRAW_PILE"))
	%Pass.pressed.connect(func()->void:send("PASS"))
	%Knock.pressed.connect(func()->void:send("KNOCK_TEN"))
	%Truco.pressed.connect(func()->void:send("REQUEST_TRUCO"))
	%Accept.pressed.connect(func()->void:send("ACCEPT"))
	%Run.pressed.connect(func()->void:send("RUN"))
	%Raise.pressed.connect(func()->void:send("RAISE"))
	%Color.visible="uno"=="uno";%DeclareUno.visible="uno"=="uno"
	%Knock.visible="uno"=="caxeta";%KnockNormal.visible="uno"=="caxeta";%Truco.visible="uno"=="truco";%Accept.visible="uno"=="truco";%Run.visible="uno"=="truco";%Raise.visible="uno"=="truco"
