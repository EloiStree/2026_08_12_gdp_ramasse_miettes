extends Node

func _ready():
	list_download_files()

func list_download_files():
	# On Android, the Download directory is usually at:
	# /storage/emulated/0/Download
	var dir = DirAccess.open("user://")  # Try user:// first (internal storage)
	if dir:
		print("Listing files in user:// (internal storage):")
		dir.list_dir_begin()
		var file_name = dir.get_next()
		while file_name != "":
			print(file_name)
			file_name = dir.get_next()
		dir.list_dir_end()
	else:
		print("Could not open user:// directory.")

	# Try to open the Download directory directly (Android)
	var download_dir = DirAccess.open("res://android_assets/")  # Not standard, but for example
	if not download_dir:
		# On Android, you need to request permission and use the correct path
		# This is a placeholder; you need to use Android plugins or native code for full access
		print("To access the Download directory on Android, you need to use Android plugins or native code.")
		print("See: https://docs.godotengine.org/en/stable/tutorials/platform/android/android_plugin.html")
