@tool
extends Window

signal frames_selected(textures: Array[Texture2D])

const MAX_FRAMES := 4096
const FALLBACK_FRAME_SIZE := 16
const MIN_ZOOM := 0.2
const MAX_ZOOM := 4.0

const SETTINGS_PATH := "res://addons/batch_sprite_keyframe/ui/sheet_slicer.cfg"
const SETTINGS_SECTION := "frames"
const SETTINGS_KEY_W := "width"
const SETTINGS_KEY_H := "height"
const SETTINGS_KEY_DIR := "last_dir"   # 【新增】

var _sheet: Texture2D = null
var _sheet_path: String = ""

var _h_count: int = 1
var _v_count: int = 1
var _frame_w: int = FALLBACK_FRAME_SIZE
var _frame_h: int = FALLBACK_FRAME_SIZE

var _selected: Array[int] = []
var _ui_built := false
var _syncing := false
var _remembered_w: int = FALLBACK_FRAME_SIZE
var _remembered_h: int = FALLBACK_FRAME_SIZE
var _last_dir: String = ""   # 【新增】上次打开图片的目录

var _path_label: Label
var _h_spin: SpinBox
var _v_spin: SpinBox
var _w_spin: SpinBox
var _h_px_spin: SpinBox
var _add_btn: Button
var _select_all_btn: Button
var _deselect_all_btn: Button
var _canvas: PreviewCanvas
var _file_dialog: EditorFileDialog


func _init() -> void:
	title = "选择帧"
	exclusive = false
	visible = false
	close_requested.connect(_on_close_requested)


func _ready() -> void:
	if _ui_built:
		return
	_ui_built = true
	_load_settings()
	_build_ui()
	_set_ui_enabled(false)


func open() -> void:
	popup_centered(Vector2i(1200, 780))


# ============================================================
# 持久化
# ============================================================
func _load_settings() -> void:
	var cfg := ConfigFile.new()
	var err := cfg.load(SETTINGS_PATH)
	if err != OK:
		_remembered_w = FALLBACK_FRAME_SIZE
		_remembered_h = FALLBACK_FRAME_SIZE
		_last_dir = ""
		return
	_remembered_w = max(1, int(cfg.get_value(SETTINGS_SECTION, SETTINGS_KEY_W, FALLBACK_FRAME_SIZE)))
	_remembered_h = max(1, int(cfg.get_value(SETTINGS_SECTION, SETTINGS_KEY_H, FALLBACK_FRAME_SIZE)))
	_last_dir = str(cfg.get_value(SETTINGS_SECTION, SETTINGS_KEY_DIR, ""))   # 【新增】


func _save_settings() -> void:
	var cfg := ConfigFile.new()
	cfg.load(SETTINGS_PATH)
	cfg.set_value(SETTINGS_SECTION, SETTINGS_KEY_W, _remembered_w)
	cfg.set_value(SETTINGS_SECTION, SETTINGS_KEY_H, _remembered_h)
	cfg.set_value(SETTINGS_SECTION, SETTINGS_KEY_DIR, _last_dir)   # 【新增】
	var err := cfg.save(SETTINGS_PATH)
	if err != OK:
		push_warning("[SheetSlicer] 无法保存配置到 %s (err=%d)" % [SETTINGS_PATH, err])


# ============================================================
# UI 构建
# ============================================================
func _build_ui() -> void:
	var bg := PanelContainer.new()
	var bg_style := StyleBoxFlat.new()
	bg_style.bg_color = Color8(54, 61, 74)
	bg.add_theme_stylebox_override("panel", bg_style)
	add_child(bg)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 12)
	margin.add_theme_constant_override("margin_right", 12)
	margin.add_theme_constant_override("margin_top", 12)
	margin.add_theme_constant_override("margin_bottom", 12)
	bg.add_child(margin)

	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 8)
	margin.add_child(root)

	# === 顶栏 ===
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 8)
	root.add_child(top)

	_select_all_btn = Button.new()
	_select_all_btn.text = "全选"
	_select_all_btn.pressed.connect(_on_select_all)
	top.add_child(_select_all_btn)

	_deselect_all_btn = Button.new()
	_deselect_all_btn.text = "全不选"
	_deselect_all_btn.pressed.connect(_on_deselect_all)
	top.add_child(_deselect_all_btn)

	var top_spacer := Control.new()
	top_spacer.custom_minimum_size.x = 24
	top.add_child(top_spacer)

	var pick_btn := Button.new()
	pick_btn.text = "选择图片"
	var icon := EditorInterface.get_editor_theme().get_icon("Load", "EditorIcons")
	if icon:
		pick_btn.icon = icon
	pick_btn.pressed.connect(_on_pick_image)
	top.add_child(pick_btn)

	_path_label = Label.new()
	_path_label.text = "未选择图片"
	_path_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(_path_label)

	# === 中部：预览 + 参数 ===
	var mid := HBoxContainer.new()
	mid.size_flags_vertical = Control.SIZE_EXPAND_FILL
	mid.add_theme_constant_override("separation", 8)
	root.add_child(mid)

	var preview_bg := PanelContainer.new()
	preview_bg.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	preview_bg.size_flags_vertical = Control.SIZE_EXPAND_FILL
	mid.add_child(preview_bg)
	var preview_bg_style := StyleBoxFlat.new()
	preview_bg_style.bg_color = Color8(33, 38, 46)
	preview_bg.add_theme_stylebox_override("panel", preview_bg_style)

	_canvas = PreviewCanvas.new()
	_canvas.clip_contents = true
	_canvas.focus_mode = Control.FOCUS_CLICK
	_canvas.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_canvas.frame_clicked.connect(_on_frame_clicked)
	_canvas.zoom_requested.connect(_on_zoom_requested)
	preview_bg.add_child(_canvas)

	var param_panel := VBoxContainer.new()
	param_panel.custom_minimum_size.x = 220
	param_panel.add_theme_constant_override("separation", 6)
	mid.add_child(param_panel)

	_h_spin = _make_spin(param_panel, "水平", 1, 256, 1)
	_h_spin.value_changed.connect(_on_h_changed)

	_v_spin = _make_spin(param_panel, "垂直", 1, 256, 1)
	_v_spin.value_changed.connect(_on_v_changed)

	_w_spin = _make_spin(param_panel, "宽", 1, 4096, _remembered_w)
	_w_spin.value_changed.connect(_on_w_changed)

	_h_px_spin = _make_spin(param_panel, "高", 1, 4096, _remembered_h)
	_h_px_spin.value_changed.connect(_on_h_px_changed)


	# === 底栏 ===
	var bottom := HBoxContainer.new()
	bottom.add_theme_constant_override("separation", 8)
	root.add_child(bottom)

	var cancel_btn := Button.new()
	cancel_btn.text = "取消"
	cancel_btn.custom_minimum_size = Vector2(100, 32)
	cancel_btn.pressed.connect(_on_cancel)
	bottom.add_child(cancel_btn)

	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bottom.add_child(spacer)

	_add_btn = Button.new()
	_add_btn.text = "未选择帧"
	_add_btn.disabled = true
	_add_btn.custom_minimum_size = Vector2(160, 32)
	_add_btn.pressed.connect(_on_confirm)
	bottom.add_child(_add_btn)

	var save_png_btn := Button.new()
	save_png_btn.text = "保存切片为 PNG"
	save_png_btn.disabled = true
	save_png_btn.custom_minimum_size.y = 32
	bottom.add_child(save_png_btn)

	_file_dialog = EditorFileDialog.new()
	_file_dialog.file_mode = EditorFileDialog.FILE_MODE_OPEN_FILE
	_file_dialog.access = EditorFileDialog.ACCESS_RESOURCES
	_file_dialog.filters = PackedStringArray([
		"*.png", "*.jpg", "*.jpeg", "*.webp", "*.bmp"
	])
	_file_dialog.display_mode = EditorFileDialog.DISPLAY_THUMBNAILS
	_file_dialog.file_selected.connect(_on_file_selected)
	add_child(_file_dialog)


func _make_spin(parent: Node, label_text: String, min_v: int, max_v: int, default_v: int) -> SpinBox:
	var row := HBoxContainer.new()
	parent.add_child(row)

	var lbl := Label.new()
	lbl.text = label_text
	lbl.custom_minimum_size.x = 50
	row.add_child(lbl)

	var spin := SpinBox.new()
	spin.min_value = min_v
	spin.max_value = max_v
	spin.step = 1
	spin.value = default_v
	spin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	spin.value_changed.connect(_on_spin_value_changed.bind(spin))
	row.add_child(spin)

	return spin


func _on_spin_value_changed(v: float, spin: SpinBox) -> void:
	var iv := int(round(v))
	if abs(v - float(iv)) > 0.001:
		spin.set_value_no_signal(float(iv))


# ============================================================
# 图片加载
# ============================================================
func _on_pick_image() -> void:
	if _last_dir != "":
		if DirAccess.dir_exists_absolute(_last_dir):
			_file_dialog.current_dir = _last_dir
		else:
			_last_dir = ""
			_save_settings()
	_file_dialog.popup_centered(Vector2i(900, 600))


func _on_file_selected(path: String) -> void:
	# 【新增】记住这次打开文件所在的目录
	var dir := path.get_base_dir()
	if dir != "":
		_last_dir = dir
		_save_settings()
	_load_sheet(path)


func _load_sheet(path: String) -> void:
	var tex := load(path) as Texture2D
	if tex == null:
		push_error("[SheetSlicer] 无法加载图片: %s" % path)
		return

	_sheet = tex
	_sheet_path = path
	_path_label.text = path

	var img_w := tex.get_width()
	var img_h := tex.get_height()

	_h_count = max(1, int(round(float(img_w) / float(_remembered_w))))
	_v_count = max(1, int(round(float(img_h) / float(_remembered_h))))

	if _h_count == 1 and _v_count == 1:
		_h_count = max(1, int(round(float(img_w) / float(FALLBACK_FRAME_SIZE))))
		_v_count = max(1, int(round(float(img_h) / float(FALLBACK_FRAME_SIZE))))

	_frame_w = max(1, int(img_w / _h_count))
	_frame_h = max(1, int(img_h / _v_count))

	if _h_count * _v_count > MAX_FRAMES:
		push_warning("[SheetSlicer] 帧数超过上限 %d" % MAX_FRAMES)

	_syncing = true
	_h_spin.set_value_no_signal(_h_count)
	_v_spin.set_value_no_signal(_v_count)
	_w_spin.set_value_no_signal(_frame_w)
	_h_px_spin.set_value_no_signal(_frame_h)
	_syncing = false

	_selected.clear()
	_canvas.zoom = 1.0
	_center_canvas_deferred()

	_update_canvas()
	_set_ui_enabled(true)


func _center_canvas_deferred() -> void:
	await get_tree().process_frame
	if is_instance_valid(_canvas):
		_canvas.center_view()


# ============================================================
# 参数联动
# ============================================================
func _on_h_changed(v: float) -> void:
	if _syncing or _sheet == null:
		return
	_h_count = max(1, int(round(v)))
	_frame_w = max(1, int(_sheet.get_width() / _h_count))
	_remembered_w = _frame_w
	_syncing = true
	_w_spin.set_value_no_signal(_frame_w)
	_syncing = false
	_after_param_change()


func _on_v_changed(v: float) -> void:
	if _syncing or _sheet == null:
		return
	_v_count = max(1, int(round(v)))
	_frame_h = max(1, int(_sheet.get_height() / _v_count))
	_remembered_h = _frame_h
	_syncing = true
	_h_px_spin.set_value_no_signal(_frame_h)
	_syncing = false
	_after_param_change()


func _on_w_changed(v: float) -> void:
	if _syncing or _sheet == null:
		return
	var iv := max(1, int(round(v)))
	_h_count = max(1, int(round(float(_sheet.get_width()) / float(iv))))
	_frame_w = max(1, int(_sheet.get_width() / _h_count))
	_remembered_w = _frame_w
	_syncing = true
	_h_spin.set_value_no_signal(_h_count)
	_w_spin.set_value_no_signal(_frame_w)
	_syncing = false
	_after_param_change()


func _on_h_px_changed(v: float) -> void:
	if _syncing or _sheet == null:
		return
	var iv := max(1, int(round(v)))
	_v_count = max(1, int(round(float(_sheet.get_height()) / float(iv))))
	_frame_h = max(1, int(_sheet.get_height() / _v_count))
	_remembered_h = _frame_h
	_syncing = true
	_v_spin.set_value_no_signal(_v_count)
	_h_px_spin.set_value_no_signal(_frame_h)
	_syncing = false
	_after_param_change()


func _after_param_change() -> void:
	_save_settings()
	_selected.clear()
	_update_canvas()
	_update_add_btn()


# ============================================================
# 状态同步
# ============================================================
func _update_canvas() -> void:
	if _canvas == null:
		return
	_canvas.sheet = _sheet
	_canvas.h_count = _h_count
	_canvas.v_count = _v_count
	_canvas.frame_w = _frame_w
	_canvas.frame_h = _frame_h
	_canvas.selected = _selected
	_canvas.queue_redraw()


func _set_ui_enabled(enabled: bool) -> void:
	_h_spin.editable = enabled
	_v_spin.editable = enabled
	_w_spin.editable = enabled
	_h_px_spin.editable = enabled
	_select_all_btn.disabled = not enabled
	_deselect_all_btn.disabled = not enabled
	_update_add_btn()


func _update_add_btn() -> void:
	var n := _selected.size()
	if n > 0:
		_add_btn.text = "添加 %d 帧" % n
		_add_btn.disabled = false
	else:
		_add_btn.text = "未选择帧"
		_add_btn.disabled = true


# ============================================================
# 交互
# ============================================================
func _on_frame_clicked(idx: int) -> void:
	var existing := _selected.find(idx)
	if existing >= 0:
		_selected.remove_at(existing)
	else:
		_selected.append(idx)
	_canvas.selected = _selected
	_canvas.queue_redraw()
	_update_add_btn()


func _on_zoom_requested(factor: float, mouse_pos: Vector2) -> void:
	var old_zoom := _canvas.zoom
	var new_zoom := clampf(old_zoom * factor, MIN_ZOOM, MAX_ZOOM)
	if abs(new_zoom - old_zoom) < 0.0001:
		return
	var local_before := (mouse_pos - _canvas.view_offset) / old_zoom
	_canvas.zoom = new_zoom
	_canvas.view_offset = mouse_pos - local_before * new_zoom
	_canvas.queue_redraw()


func _on_select_all() -> void:
	var total := _h_count * _v_count
	if total > MAX_FRAMES:
		total = MAX_FRAMES
		push_warning("[SheetSlicer] 帧数超过上限，已截断到 %d" % MAX_FRAMES)
	_selected.clear()
	for i in range(total):
		_selected.append(i)
	_canvas.selected = _selected
	_canvas.queue_redraw()
	_update_add_btn()


func _on_deselect_all() -> void:
	_selected.clear()
	_canvas.selected = _selected
	_canvas.queue_redraw()
	_update_add_btn()


func _on_cancel() -> void:
	_reset_selection()
	hide()

func _reset_selection() -> void:
	_selected.clear()
	if _canvas and is_instance_valid(_canvas):
		_canvas.selected = _selected
		_canvas.queue_redraw()
	_update_add_btn()

func _on_close_requested() -> void:
	_reset_selection()
	hide()

func _on_confirm() -> void:
	if _selected.is_empty():
		return
	var textures := _build_atlas_textures()
	frames_selected.emit(textures)
	_reset_selection()
	hide()

func _build_atlas_textures() -> Array[Texture2D]:
	var out: Array[Texture2D] = []
	if _sheet == null:
		return out
	for idx in _selected:
		var at := AtlasTexture.new()
		at.atlas = _sheet
		var fx := idx % _h_count
		var fy := idx / _h_count
		at.region = Rect2(fx * _frame_w, fy * _frame_h, _frame_w, _frame_h)
		out.append(at)
	return out


# ============================================================
# 内部类：预览画布
# ============================================================
class PreviewCanvas extends Control:
	var sheet: Texture2D = null
	var h_count: int = 1
	var v_count: int = 1
	var frame_w: int = 32
	var frame_h: int = 32
	var zoom: float = 1.0
	var view_offset: Vector2 = Vector2.ZERO
	var selected: Array[int] = []

	var _is_panning := false
	var _pan_start_mouse := Vector2.ZERO
	var _pan_start_offset := Vector2.ZERO

	var _is_painting := false
	var _last_painted_idx := -1

	signal frame_clicked(idx: int)
	signal zoom_requested(factor: float, mouse_pos: Vector2)

	func center_view() -> void:
		if sheet == null:
			return
		var img_center := Vector2(sheet.get_width(), sheet.get_height()) * 0.5
		view_offset = size * 0.5 - img_center * zoom
		queue_redraw()

	func _draw() -> void:
		draw_rect(Rect2(Vector2.ZERO, size), Color8(33, 38, 46), true)

		var hint_font := ThemeDB.fallback_font
		var hint_size := 14
		var hint_text := "按住 Ctrl 滚轮缩放"
		var hint_pos := Vector2(8, hint_size + 4)
		draw_string(hint_font, hint_pos + Vector2(1, 1), hint_text,
			HORIZONTAL_ALIGNMENT_LEFT, -1, hint_size, Color(0, 0, 0, 0.7))
		draw_string(hint_font, hint_pos, hint_text,
			HORIZONTAL_ALIGNMENT_LEFT, -1, hint_size, Color(0.55, 0.58, 0.62, 0.85))

		if sheet == null:
			return

		draw_set_transform(view_offset, 0.0, Vector2(zoom, zoom))

		var img_rect := Rect2(0, 0, sheet.get_width(), sheet.get_height())
		draw_texture_rect(sheet, img_rect, false)

		var line_color := Color(1.0, 1.0, 1.0, 0.55)
		var line_width := 2.0 / zoom
		for i in range(1, h_count):
			var x := float(i * frame_w)
			draw_line(Vector2(x, 0), Vector2(x, sheet.get_height()), line_color, line_width)
		for j in range(1, v_count):
			var y := float(j * frame_h)
			draw_line(Vector2(0, y), Vector2(sheet.get_width(), y), line_color, line_width)

		var border_rect := Rect2(0, 0, sheet.get_width(), sheet.get_height())
		draw_rect(border_rect, Color(1.0, 1.0, 1.0, 0.85), false, 2.0 / zoom)

		var font := ThemeDB.fallback_font
		var font_size := 12
		for order_idx in range(selected.size()):
			var frame_idx: int = selected[order_idx]
			var fx := frame_idx % h_count
			var fy := frame_idx / h_count
			var rect := Rect2(fx * frame_w, fy * frame_h, frame_w, frame_h)
			draw_rect(rect, Color(0.2, 0.55, 1.0, 0.95), false, 2.0 / zoom)
			var num := str(order_idx + 1)
			var text_pos := rect.position + Vector2(4, 14)
			draw_string(font, text_pos + Vector2(1, 1), num,
				HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, Color(0, 0, 0, 0.85))
			draw_string(font, text_pos, num,
				HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, Color(1, 1, 1))

		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

	func _gui_input(event: InputEvent) -> void:
		if event is InputEventMouseButton:
			var mb := event as InputEventMouseButton
			if mb.pressed:
				if mb.button_index == MOUSE_BUTTON_LEFT:
					if sheet != null:
						_is_painting = true
						_last_painted_idx = -1
						_paint_at(mb.position)
				elif mb.button_index == MOUSE_BUTTON_MIDDLE:
					_is_panning = true
					_pan_start_mouse = mb.position
					_pan_start_offset = view_offset
				elif mb.button_index == MOUSE_BUTTON_WHEEL_UP:
					if mb.ctrl_pressed:
						zoom_requested.emit(1.1, mb.position)
					else:
						view_offset.y += 30
						queue_redraw()
				elif mb.button_index == MOUSE_BUTTON_WHEEL_DOWN:
					if mb.ctrl_pressed:
						zoom_requested.emit(1.0 / 1.1, mb.position)
					else:
						view_offset.y -= 30
						queue_redraw()
			else:
				if mb.button_index == MOUSE_BUTTON_LEFT:
					_is_painting = false
					_last_painted_idx = -1
				elif mb.button_index == MOUSE_BUTTON_MIDDLE:
					_is_panning = false
		elif event is InputEventMouseMotion:
			var mm := event as InputEventMouseMotion
			if _is_panning:
				view_offset = _pan_start_offset + (mm.position - _pan_start_mouse)
				queue_redraw()
			elif _is_painting:
				_paint_at(mm.position)

	func _paint_at(screen_pos: Vector2) -> void:
		var idx := _pos_to_frame(screen_pos)
		if idx == _last_painted_idx:
			return
		_last_painted_idx = idx
		if idx >= 0:
			frame_clicked.emit(idx)

	func _pos_to_frame(pos: Vector2) -> int:
		if sheet == null:
			return -1
		var local := (pos - view_offset) / zoom
		var fx := int(floor(local.x / float(frame_w)))
		var fy := int(floor(local.y / float(frame_h)))
		if fx < 0 or fy < 0 or fx >= h_count or fy >= v_count:
			return -1
		return fy * h_count + fx
