extends GameUI
func _ready()->void:
	super()
	%Draw.pressed.connect(func()->void:send("DRAW_ONE" if "caxeta"=="uno" else "DRAW_PILE"))
	%Pass.pressed.connect(func()->void:send("PASS"))
	%Knock.pressed.connect(func()->void:send("KNOCK_TEN"))
	%Truco.pressed.connect(func()->void:send("REQUEST_TRUCO"))
	%Accept.pressed.connect(func()->void:send("ACCEPT"))
	%Run.pressed.connect(func()->void:send("RUN"))
	%Raise.pressed.connect(func()->void:send("RAISE"))
	%Color.visible="caxeta"=="uno";%DeclareUno.visible="caxeta"=="uno"
	%Knock.visible="caxeta"=="caxeta";%KnockNormal.visible="caxeta"=="caxeta";%Truco.visible="caxeta"=="truco";%Accept.visible="caxeta"=="truco";%Run.visible="caxeta"=="truco";%Raise.visible="caxeta"=="truco"
