class_name TrucoMatchController
extends BaseMatchController
func start(players:Array,seed:int,config:Dictionary={}) -> void:initialize(TrucoRules.new(),players,seed,config)
