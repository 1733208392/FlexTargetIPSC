extends SceneTree

func _initialize():
	print("=== Translation Test ===")
	print("Available locales: ", TranslationServer.get_loaded_locales())
	print("Current locale: ", TranslationServer.get_locale())
	
	# Test English
	TranslationServer.set_locale("en")
	print("English - complete: ", TranslationServer.translate("complete"))
	print("English - restart: ", TranslationServer.translate("restart"))
	print("English - replay: ", TranslationServer.translate("replay"))
	
	# Test Chinese
	TranslationServer.set_locale("zh_CN")
	print("Chinese - complete: ", TranslationServer.translate("complete"))
	print("Chinese - restart: ", TranslationServer.translate("restart"))
	print("Chinese - replay: ", TranslationServer.translate("replay"))
	
	# Test Japanese
	TranslationServer.set_locale("ja")
	print("Japanese - complete: ", TranslationServer.translate("complete"))
	print("Japanese - restart: ", TranslationServer.translate("restart"))
	print("Japanese - replay: ", TranslationServer.translate("replay"))
	
	quit()