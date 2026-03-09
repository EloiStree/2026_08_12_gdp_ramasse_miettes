extends Node
#
#func _ready():
	#list_and_move_first_file()
	#
## Function to list files in Downloads and move the first one to Documents
#func list_and_move_first_file():
	#var dir = Directory.new()
	#var download_dir = "/sdcard/Download"
	#var documents_dir = "/sdcard/Documents"
	#
	## Open the Downloads directory
	#var error = dir.open(download_dir)
	#if error != OK:
		#print("Failed to open Downloads directory: ", error)
		#return
	#
	## Start listing files
	#dir.list_dir_begin(true, true) # Skip directories and hidden files
	#var files = []
	#var file_name = dir.get_next()
	#
	## Collect all files in the Downloads directory
	#while file_name != "":
		#if not dir.current_is_dir():
			#files.append(file_name)
		#file_name = dir.get_next()
	#dir.list_dir_end()
	#
	## Print all files
	#if files.is_empty():
		#print("No files found in Downloads directory.")
		#return
	#
	#print("Files in Downloads directory:")
	#for file in files:
		#print("- ", file)
	#
	## Move the first file to Documents
	#var first_file = files[0]
	#var source_path = download_dir + "/" + first_file
	#var dest_path = documents_dir + "/" + first_file
	#
	## Copy the file
	#error = dir.copy(source_path, dest_path)
	#if error != OK:
		#print("Failed to copy file ", first_file, ": ", error)
		#return
	#
	## Delete the original file
	#error = dir.remove(source_path)
	#if error != OK:
		#print("Failed to delete original file ", first_file, ": ", error)
		#return
	#
	#print("Moved file ", first_file, " to Documents successfully!")
#
## Example: Trigger the function via a button press
#func _on_button_pressed():
	#list_and_move_first_file()
