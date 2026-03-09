
extends Node

func _ready():
	copy_files_from_downloads_to_user_import_here("Download", "Download")
	# copy_files_from_downloads_to_user_import_here("Download", "OpenBrush")
	# copy_files_from_downloads_to_user_import_here("Download", "OpenBox")
	# copy_files_from_downloads_to_user_import_here("Download", "PaingVR")
	# copy_files_from_downloads_to_user_import_here("Download", "GravitySketch")

func copy_files_from_downloads_to_user_import_here(relative_storage_source: String, project_relative_path: String) -> void:
	var downloads_path = "/storage/emulated/0/" + relative_storage_source
	var target_path = "res://ImportHere/" + project_relative_path

	# Print absolute paths
	print("Source (Download) path: ", downloads_path)
	print("Target path: ", target_path)

	# Create target directory if it doesn't exist
	if not DirAccess.dir_exists_absolute(ProjectSettings.globalize_path(target_path)):
		var mk_err = DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(target_path))
		if mk_err == OK:
			print("Created target directory: ", target_path)
		else:
			print("Failed to create target directory: ", mk_err)

	# List and copy files
	var dir := DirAccess.open(downloads_path)
	if dir:
		dir.list_dir_begin()
		var file_name = dir.get_next()
		while file_name != "":
			if not dir.current_is_dir():  # Skip directories
				var source = downloads_path.path_join(file_name)
				var dest = ProjectSettings.globalize_path(target_path).path_join(file_name)

				# Skip .zip files
				if file_name.to_lower().ends_with(".zip"):
					print("Skipped (.zip file): ", file_name)
				else:
					var f := FileAccess.open(source, FileAccess.READ)
					if f:
						var size_bytes = f.get_length()
						f.close()

						if size_bytes <= 24 * 1024 * 1024:  # 24 MB
							var err = DirAccess.copy_absolute(source, dest)
							if err == OK:
								print("Copied: ", file_name, " (", size_bytes / (1024 * 1024.0), " MB ) → ", dest)
							else:
								print("Failed to copy: ", file_name, " Error code: ", err)
						else:
							print("Skipped (too large): ", file_name, " (", size_bytes / (1024 * 1024.0), " MB )")
					else:
						print("Could not open file to check size: ", source)

				# 🗑️ Delete the file in all cases (copied, skipped, or failed)
				var del_err = DirAccess.remove_absolute(source)
				if del_err == OK:
					print("Deleted source file: ", source)
				else:
					print("Failed to delete source file: ", source, " Error code: ", del_err)

			file_name = dir.get_next()
		dir.list_dir_end()
	else:
		print("Could not open Download directory at: ", downloads_path)

	# 🔄 Refresh Godot FileSystem (editor only)
	if Engine.is_editor_hint():
		EditorInterface.get_resource_filesystem().scan()
		print("FileSystem refreshed.")
