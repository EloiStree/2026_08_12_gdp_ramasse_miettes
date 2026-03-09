extends Control

@export var camera_view: TextureRect
@export var debug_label: Label
@export var cam_id: int = 0
@export var format_id: int = 0
## list of cameras found 
@export var found_camera_debug_text: String
## formats found in the selected camera
@export var found_camera_format_debug_text: String
@export var selected_width: int
@export var selected_height: int

signal on_camera_list_updated(camera_found: Array[String])
signal on_camera_selected_format_updated(camera_selected_format_found: Array[String])

var feed: CameraFeed
var cam_tex: CameraTexture
var connected: bool = false
var lost_frames_timer: float = 0.0
var last_reconnect_time: int = 0

const LOST_FRAME_TIMEOUT := 5.0    # seconds without frames before reconnect
const RECONNECT_COOLDOWN := 10.0   # minimum delay between reconnects

func _ready() -> void:
	debug_label.text = "📷 Initializing camera system...\n"
	CameraServer.camera_feeds_updated.connect(_on_camera_feeds_updated)
	CameraServer.monitoring_feeds = true
	_log("🔍 Searching for available camera feeds...")
	_on_camera_feeds_updated()

func _on_camera_feeds_updated() -> void:
	var feeds: Array = CameraServer.feeds()
	var camera_names: Array[String] = []

	if feeds.is_empty():
		_log("❌ No camera feeds detected. Please connect a camera (MiraBox).")
		found_camera_debug_text = "No camera feeds detected."
		emit_signal("on_camera_list_updated", [])
		return

	for i in range(feeds.size()):
		var name: String = str(feeds[i].get_name())
		camera_names.append(name)
		_log("   • [%d] %s" % [i, name])

	found_camera_debug_text = "\n".join(camera_names)
	emit_signal("on_camera_list_updated", camera_names)

	# 🎯 Choose camera
	if cam_id >= feeds.size():
		cam_id = 0
	_log("🎥 Selecting camera index %d: %s" % [cam_id, feeds[cam_id].get_name()])
	feed = feeds[cam_id]

	# 🛑 Deactivate feed before setting format
	if feed.is_active():
		_log("🛑 Deactivating feed before format change...")
		feed.set_active(false)
		await get_tree().process_frame

	# 📋 Get formats
	var formats: Array = feed.get_formats()
	var format_strings: Array[String] = []

	if formats.is_empty():
		_log("⚠️ No formats reported by device.")
		found_camera_format_debug_text = "No formats available."
		emit_signal("on_camera_selected_format_updated", [])
		return

	_log("📋 Available formats:")
	for i in range(formats.size()):
		var f: Dictionary = formats[i]
		var fmt_text := "%dx%d %s" % [f.get("width", 0), f.get("height", 0), f.get("format", "unknown")]
		format_strings.append(fmt_text)
		_log("   • [%d] %s" % [i, fmt_text])

	found_camera_format_debug_text = "\n".join(format_strings)
	emit_signal("on_camera_selected_format_updated", format_strings)

	# Pick format
	if format_id >= formats.size():
		format_id = 0

	var fmt_name: String = str(formats[format_id].get("format", "unknown"))
	_log("🧩 Selecting format index %d (%s)" % [format_id, fmt_name])

	var ok: bool = feed.set_format(format_id, {})
	if ok:
		_log("✅ Format set successfully.")
	else:
		_log("⚠️ Failed to set format — driver may use default.")

	# 📏 Fetch width and height of the selected format
	if formats.size() > format_id:
		var selected_format: Dictionary = formats[format_id]
		selected_width = int(selected_format.get("width", 0))
		selected_height = int(selected_format.get("height", 0))
		_log("📏 Selected resolution: %dx%d" % [selected_width, selected_height])
	else:
		selected_width = 0
		selected_height = 0
		_log("⚠️ Invalid format index; width and height set to 0.")

	# 🎥 Activate feed
	feed.set_active(true)
	await get_tree().process_frame

	if feed.is_active():
		_log("✅ Feed active.")
		cam_tex = CameraTexture.new()
		cam_tex.camera_feed_id = feed.get_id()
		on_camera_texture_created.emit(cam_tex)
		connected = true
		lost_frames_timer = 0.0
		if camera_view != null:
			camera_view.texture = cam_tex
		
		
	else:
		_log("❌ Feed activation failed — check permissions or device availability.")
		connected = false
		
signal on_camera_texture_created(new_camera_texture: CameraTexture)

func _process(delta: float) -> void:
	if connected and cam_tex:
		var w: int = cam_tex.get_width()
		var h: int = cam_tex.get_height()

		if w > 32 and h > 32: # ignore transient 0x0 frames
			lost_frames_timer = 0.0
			debug_label.text = "✅ Receiving frames: %dx%d" % [w, h]
		else:
			lost_frames_timer += delta
			debug_label.text = "⏳ Waiting for frames... %.1fs" % [lost_frames_timer]

			if lost_frames_timer > LOST_FRAME_TIMEOUT \
			and (Time.get_ticks_msec() - last_reconnect_time) > (RECONNECT_COOLDOWN * 1000):
				last_reconnect_time = Time.get_ticks_msec()
				_log("⚠️ No frames for %.1fs — attempting to refresh..." % LOST_FRAME_TIMEOUT)
				await _refresh_feed()
				lost_frames_timer = 0.0

func _refresh_feed() -> void:
	if not feed:
		_log("⚠️ No feed to refresh — rescanning feeds.")
		_on_camera_feeds_updated()
		return

	_log("♻️ Refreshing camera feed...")
	feed.set_active(false)
	await get_tree().process_frame
	feed.set_active(true)
	await get_tree().process_frame

	if feed.is_active():
		_log("✅ Feed reactivated successfully.")
	else:
		_log("❌ Feed reactivation failed — will retry later.")
		connected = false

func _update_camera_view_scale() -> void:
	if not camera_view:
		return

	if selected_width <= 0 or selected_height <= 0:
		return

	var viewport_size: Vector2 = get_viewport_rect().size
	var aspect_ratio := float(selected_width) / float(selected_height)
	var target_width := viewport_size.x
	var target_height := target_width / aspect_ratio

	# Fit inside window bounds
	if target_height > viewport_size.y:
		target_height = viewport_size.y
		target_width = target_height * aspect_ratio

	camera_view.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	camera_view.size = Vector2(target_width, target_height)
	camera_view.position = (viewport_size - camera_view.size) / 2.0
	_log("🖥️ Camera view resized to fit %.0fx%.0f (aspect %.2f)" % [target_width, target_height, aspect_ratio])

func _log(msg: String) -> void:
	print(msg)
	debug_label.text += msg + "\n"
