class_name TestHelpers
extends RefCounted
var passed:int=0;var failed:int=0
func check(condition:bool,message:String)->void:
	if condition:passed+=1
	else:failed+=1;push_error("TESTE: "+message)
func equal(actual:Variant,expected:Variant,message:String)->void:check(actual==expected,"%s — esperado %s, obtido %s"%[message,expected,actual])
