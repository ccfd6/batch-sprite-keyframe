@tool
extends VBoxContainer

const KeyframeGenerator = preload("res://addons/batch_sprite_keyframe/core/keyframe_generator.gd")
const SheetSlicer = preload("res://addons/batch_sprite_keyframe/ui/sheet_slicer.gd")

# 与 sheet_slicer 共用同一个配置文件
const SETTINGS_PATH := "res://addons/batch_sprite_keyframe/ui/sheet_slicer.cfg"
const SETTINGS_SECTION := "frames"
const SETTINGS_KEY_BATCH_DIR := "batch_last_dir"
const SETTINGS_KEY_OVERWRITE := "overwrite_existing"

# 【新增】会话缓存
const SessionCache = preload("res://addons/batch_sprite_keyframe/core/session_cache.gd")

# 选中的资源与节点
# 选中的资源与节点
var selected_textures: Array[Texture2D] = []
var target_sprite: Sprite2D
var target_anim_player: AnimationPlayer

# 参数
var anim_name: String = "texture_anim"
var fps: float = 10.0

# UI控件
var texture_list: ItemList
var _sprite_field: LineEdit
var label_current_anim: Label
var fps_input: LineEdit
var _btn_sheet: Button
var _btn_batch: Button   # 【新增】
var _overwrite_checkbox: CheckBox

# 延迟 setup 支持
var _is_ready := false
var _pending_anim_player: AnimationPlayer = null

# 用于检测 assigned_animation 是否变化
var _last_assigned: String = ""

# 切片弹窗实例
var _slicer = null

# 【新增】批量选择对话框 + 记忆路径
var _batch_file_dialog: EditorFileDialog
var _batch_last_dir: String = ""


func _ready():
	_is_ready = true

	# 顶部留白
	add_custom_spacer(6)

	# === 动画参数区 ===
	add_section_title("动画参数")

	# FPS
	var row_fps = HBoxContainer.new()
	add_child(row_fps)
	var label_fps = Label.new()
	label_fps.text = "FPS："
	row_fps.add_child(label_fps)
	fps_input = LineEdit.new()
	fps_input.text = str(fps)
	fps_input.size_flags_horizontal = SIZE_EXPAND_FILL
	fps_input.custom_minimum_size.x = 80
	row_fps.add_child(fps_input)

	# 覆盖开关
	_overwrite_checkbox = CheckBox.new()
	_overwrite_checkbox.text = "覆盖已有轨道"
	_overwrite_checkbox.tooltip_text = "开启：目标 texture 轨道已存在时，清空并重新插入帧。\n关闭：轨道已存在时跳过，不做任何修改。"
	_overwrite_checkbox.button_pressed = true
	_overwrite_checkbox.toggled.connect(_on_overwrite_toggled)
	add_child(_overwrite_checkbox)

	add_custom_spacer(8)

	# === 节点选择区 ===
	add_section_title("目标节点")

	var row_sprite = HBoxContainer.new()
	add_child(row_sprite)

	_sprite_field = NodeDropField.new()
	_sprite_field.size_flags_horizontal = SIZE_EXPAND_FILL
	_sprite_field.size_flags_stretch_ratio = 2.0
	_sprite_field.custom_minimum_size.y = 32
	_sprite_field.node_dropped.connect(_on_sprite_node_dropped)
	row_sprite.add_child(_sprite_field)

	var btn_sprite = Button.new()
	btn_sprite.text = "选择"
	btn_sprite.size_flags_horizontal = SIZE_EXPAND_FILL
	btn_sprite.size_flags_stretch_ratio = 1.0
	btn_sprite.custom_minimum_size.y = 32
	btn_sprite.add_theme_font_size_override("font_size", 15)
	btn_sprite.pressed.connect(_pick_sprite)
	row_sprite.add_child(btn_sprite)

	add_custom_spacer(8)

	# === 当前动画区 ===
	add_section_title("当前动画")

	var row_anim = HBoxContainer.new()
	add_child(row_anim)
	label_current_anim = Label.new()
	label_current_anim.text = "当前没有动画"
	label_current_anim.size_flags_horizontal = SIZE_EXPAND_FILL
	label_current_anim.add_theme_color_override("font_color", Color(0.7, 0.5, 0.5))
	row_anim.add_child(label_current_anim)

	add_custom_spacer(8)

	# === 图片列表区 ===
	add_section_title("图片列表（拖拽导入）")

	# 第一行：从精灵表添加（50%）+ 批量添加（50%）
	var row_sheet = HBoxContainer.new()
	row_sheet.add_theme_constant_override("separation", 8)
	add_child(row_sheet)

	_btn_sheet = Button.new()
	_btn_sheet.text = "从精灵表添加"
	_btn_sheet.add_theme_font_size_override("font_size", 14)
	_btn_sheet.custom_minimum_size.y = 32
	_btn_sheet.size_flags_horizontal = SIZE_EXPAND_FILL
	_btn_sheet.size_flags_stretch_ratio = 1.0
	var sheet_icon := EditorInterface.get_editor_theme().get_icon("Load", "EditorIcons")
	if sheet_icon:
		_btn_sheet.icon = sheet_icon
	_btn_sheet.pressed.connect(_on_open_slicer)
	row_sheet.add_child(_btn_sheet)

	# 【新增】批量添加按钮
	_btn_batch = Button.new()
	_btn_batch.text = "批量添加"
	_btn_batch.add_theme_font_size_override("font_size", 14)
	_btn_batch.custom_minimum_size.y = 32
	_btn_batch.size_flags_horizontal = SIZE_EXPAND_FILL
	_btn_batch.size_flags_stretch_ratio = 1.0
	var batch_icon := EditorInterface.get_editor_theme().get_icon("Filesystem", "EditorIcons")
	if batch_icon:
		_btn_batch.icon = batch_icon
	_btn_batch.pressed.connect(_on_open_batch)
	row_sheet.add_child(_btn_batch)

	add_custom_spacer(4)

	# 列表
	var list_wrapper := MarginContainer.new()
	list_wrapper.custom_minimum_size.y = 150
	list_wrapper.size_flags_horizontal = SIZE_EXPAND_FILL
	add_child(list_wrapper)

	texture_list = ItemList.new()
	texture_list.mouse_filter = MOUSE_FILTER_PASS
	texture_list.size_flags_horizontal = SIZE_EXPAND_FILL
	texture_list.size_flags_vertical = SIZE_EXPAND_FILL
	list_wrapper.add_child(texture_list)

	add_custom_spacer(4)

	# 第二行：清空（1/4）+ 生成关键帧（3/4）
	var row_actions = HBoxContainer.new()
	row_actions.add_theme_constant_override("separation", 8)
	add_child(row_actions)

	var btn_clear = Button.new()
	btn_clear.text = "清空"
	btn_clear.add_theme_font_size_override("font_size", 14)
	btn_clear.custom_minimum_size.y = 32
	btn_clear.size_flags_horizontal = SIZE_EXPAND_FILL
	btn_clear.size_flags_stretch_ratio = 1.0
	btn_clear.pressed.connect(_clear_list)
	row_actions.add_child(btn_clear)

	var btn_generate = Button.new()
	btn_generate.text = "✅ 生成关键帧"
	btn_generate.add_theme_font_size_override("font_size", 14)
	btn_generate.custom_minimum_size.y = 32
	btn_generate.size_flags_horizontal = SIZE_EXPAND_FILL
	btn_generate.size_flags_stretch_ratio = 3.0
	btn_generate.pressed.connect(_on_generate)
	row_actions.add_child(btn_generate)

	add_custom_spacer(12)

	if _pending_anim_player:
		_apply_anim_player(_pending_anim_player)
		_pending_anim_player = null

	# 【新增】配置读取 + 批量对话框创建（放在最后，等 UI 就绪）
	_load_batch_dir()
	_load_overwrite_setting()
	_create_batch_file_dialog()


# ==============================
# 【新增】批量文件对话框
# ==============================
func _create_batch_file_dialog() -> void:
	_batch_file_dialog = EditorFileDialog.new()
	_batch_file_dialog.file_mode = EditorFileDialog.FILE_MODE_OPEN_FILES
	_batch_file_dialog.access = EditorFileDialog.ACCESS_RESOURCES
	_batch_file_dialog.filters = PackedStringArray([
		"*.png", "*.jpg", "*.jpeg", "*.webp", "*.bmp"
	])
	_batch_file_dialog.display_mode = EditorFileDialog.DISPLAY_THUMBNAILS
	_batch_file_dialog.files_selected.connect(_on_batch_files_selected)
	_batch_file_dialog.visibility_changed.connect(_update_button_disabled)
	# 挂到编辑器根，避免 VBoxContainer 挂 Window 的警告
	var base := EditorInterface.get_base_control()
	if base:
		base.add_child(_batch_file_dialog)
	else:
		add_child(_batch_file_dialog)


func _load_batch_dir() -> void:
	var cfg := ConfigFile.new()
	var err := cfg.load(SETTINGS_PATH)
	if err != OK:
		_batch_last_dir = ""
		return
	_batch_last_dir = str(cfg.get_value(SETTINGS_SECTION, SETTINGS_KEY_BATCH_DIR, ""))


func _save_batch_dir() -> void:
	var cfg := ConfigFile.new()
	cfg.load(SETTINGS_PATH)   # 先读，避免覆盖 width/height/last_dir
	cfg.set_value(SETTINGS_SECTION, SETTINGS_KEY_BATCH_DIR, _batch_last_dir)
	cfg.save(SETTINGS_PATH)

func _load_overwrite_setting() -> void:
	var cfg := ConfigFile.new()
	var err := cfg.load(SETTINGS_PATH)
	if err != OK:
		# 首次使用 → 默认 true
		if _overwrite_checkbox:
			_overwrite_checkbox.button_pressed = true
		return
	var v: bool = cfg.get_value(SETTINGS_SECTION, SETTINGS_KEY_OVERWRITE, true)
	if _overwrite_checkbox:
		_overwrite_checkbox.button_pressed = v


func _save_overwrite_setting() -> void:
	var cfg := ConfigFile.new()
	cfg.load(SETTINGS_PATH)
	cfg.set_value(SETTINGS_SECTION, SETTINGS_KEY_OVERWRITE, _overwrite_checkbox.button_pressed)
	cfg.save(SETTINGS_PATH)


func _on_overwrite_toggled(_pressed: bool) -> void:
	_save_overwrite_setting()

func _on_open_batch() -> void:
	if _batch_file_dialog == null or not is_instance_valid(_batch_file_dialog):
		return
	if _batch_file_dialog.visible:
		return
	_update_button_disabled()
	if _batch_last_dir != "" and DirAccess.dir_exists_absolute(_batch_last_dir):
		_batch_file_dialog.current_dir = _batch_last_dir
	_batch_file_dialog.popup_centered(Vector2i(900, 600))


func _on_batch_files_selected(paths: PackedStringArray) -> void:
	if paths.is_empty():
		return

	# 记住这次打开文件所在的目录
	var dir := paths[0].get_base_dir()
	if dir != "":
		_batch_last_dir = dir
		_save_batch_dir()

	# 先清空
	selected_textures.clear()

	# 自然排序后逐个加载
	var sorted_paths := _natural_sort_paths(paths)
	for p in sorted_paths:
		var ext := p.get_extension().to_lower()
		if ext not in ["png", "jpg", "jpeg", "webp", "bmp"]:
			continue
		var tex := load(p) as Texture2D
		if tex and not selected_textures.has(tex):
			selected_textures.append(tex)

	_refresh_list()


# ==============================
# 【新增】自然排序
# ==============================
func _natural_sort_paths(paths: PackedStringArray) -> Array[String]:
	var arr: Array[String] = []
	for p in paths:
		arr.append(p)
	arr.sort_custom(_natural_compare)
	return arr


func _natural_compare(a: String, b: String) -> bool:
	return _natural_less(a.get_file(), b.get_file())


func _natural_less(a: String, b: String) -> bool:
	var i := 0
	var j := 0
	while i < a.length() and j < b.length():
		var ca := a[i]
		var cb := b[j]
		if _is_digit_char(ca) and _is_digit_char(cb):
			var na := ""
			var nb := ""
			while i < a.length() and _is_digit_char(a[i]):
				na += a[i]
				i += 1
			while j < b.length() and _is_digit_char(b[j]):
				nb += b[j]
				j += 1
			var va := int(na)
			var vb := int(nb)
			if va != vb:
				return va < vb
			# 数值相同则按长度（"001" > "1"）
			if na.length() != nb.length():
				return na.length() < nb.length()
		else:
			var la := ca.to_lower()
			var lb := cb.to_lower()
			if la != lb:
				return la < lb
			i += 1
			j += 1
	return a.length() < b.length()


func _is_digit_char(c: String) -> bool:
	return c >= "0" and c <= "9"


# ==============================
# 按钮互斥
# ==============================
func _update_button_disabled() -> void:
	var any_open := false
	if _slicer != null and is_instance_valid(_slicer) and _slicer.visible:
		any_open = true
	if _batch_file_dialog != null and is_instance_valid(_batch_file_dialog) and _batch_file_dialog.visible:
		any_open = true
	if _btn_sheet and is_instance_valid(_btn_sheet):
		_btn_sheet.disabled = any_open
	if _btn_batch and is_instance_valid(_btn_batch):
		_btn_batch.disabled = any_open


# ==============================
# 实时同步：assigned_animation → Label
# ==============================
func _process(_delta: float) -> void:
	if not _is_ready or not target_anim_player or not label_current_anim:
		return
	var assigned := target_anim_player.assigned_animation
	if assigned != _last_assigned:
		_last_assigned = assigned
		_update_anim_label(assigned)


func _update_anim_label(assigned: String) -> void:
	if assigned.is_empty():
		label_current_anim.text = "当前没有动画"
		label_current_anim.add_theme_color_override("font_color", Color(0.7, 0.5, 0.5))
	else:
		label_current_anim.text = assigned
		label_current_anim.add_theme_color_override("font_color", Color(0.6, 0.9, 0.6))


# ==============================
# 外部入口
# ==============================
func setup(anim_player: AnimationPlayer) -> void:
	if _is_ready:
		_apply_anim_player(anim_player)
	else:
		_pending_anim_player = anim_player


func _apply_anim_player(anim_player: AnimationPlayer) -> void:
	target_anim_player = anim_player
	_last_assigned = anim_player.assigned_animation
	_update_anim_label(_last_assigned)

	# 【新增】从会话缓存恢复
	target_sprite = null
	var key := _make_session_key(anim_player)
	if key == "":
		_sprite_field.text = ""
		return

	var cached = SessionCache.sprite_paths.get(key)
	if cached == null:
		_sprite_field.text = ""
		return

	var rel_path: NodePath = cached if cached is NodePath else NodePath(str(cached))
	var root := EditorInterface.get_edited_scene_root()
	if root == null or rel_path == NodePath(""):
		_sprite_field.text = ""
		return

	var node := root.get_node_or_null(rel_path)
	if node is Sprite2D:
		target_sprite = node
		_sprite_field.text = str(rel_path)
	else:
		# 节点没了，清理无效缓存
		SessionCache.sprite_paths.erase(key)
		_sprite_field.text = ""


# ==============================
# 工具方法
# ==============================
func add_section_title(text: String):
	var lbl = Label.new()
	lbl.text = text
	lbl.add_theme_font_size_override("font_size", 14)
	lbl.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
	add_child(lbl)


func add_custom_spacer(px: int):
	var sp = Control.new()
	sp.custom_minimum_size.y = px
	add_child(sp)

# 【新增】生成会话缓存的 key
func _make_session_key(anim_player: AnimationPlayer) -> String:
	if anim_player == null or not is_instance_valid(anim_player):
		return ""
	var root := EditorInterface.get_edited_scene_root()
	if root == null:
		return ""
	var scene_id := root.scene_file_path
	if scene_id.is_empty():
		scene_id = "unsaved::" + str(root.get_instance_id())
	var anim_path := str(root.get_path_to(anim_player))
	return scene_id + "::" + anim_path
	
# ==============================
# 节点选择
# ==============================
func _pick_sprite():
	EditorInterface.popup_node_selector(_on_sprite_selected, ["Sprite2D"])


func _on_sprite_selected(path: NodePath):
	if path.is_empty():
		return
	var node = EditorInterface.get_edited_scene_root().get_node(path)
	if node is Sprite2D:
		_assign_sprite(node)


func _on_sprite_node_dropped(node: Node) -> void:
	if node is Sprite2D:
		_assign_sprite(node)


func _assign_sprite(node: Sprite2D) -> void:
	target_sprite = node
	var root := EditorInterface.get_edited_scene_root()
	if root:
		var rel_path := root.get_path_to(node)
		_sprite_field.text = str(rel_path)
		# 【新增】写入会话缓存
		var key := _make_session_key(target_anim_player)
		if key != "":
			SessionCache.sprite_paths[key] = rel_path
	else:
		_sprite_field.text = node.name

# ==============================
# 拖拽导入（保持原样）
# ==============================
func _can_drop_data(pos: Vector2, data: Variant) -> bool:
	if data is Dictionary and data.has("type") and data["type"] == "files":
		var files = data["files"]
		if files is PackedStringArray:
			for path in files:
				var ext = path.get_extension().to_lower()
				if ext in ["png", "jpg", "jpeg", "webp", "bmp"]:
					return true
	return false


func _drop_data(pos: Vector2, data: Variant) -> void:
	if data is Dictionary and data.has("type") and data["type"] == "files":
		var files = data["files"]
		if files is PackedStringArray:
			for path in files:
				var ext = path.get_extension().to_lower()
				if ext in ["png", "jpg", "jpeg", "webp", "bmp"]:
					var tex: Texture2D = load(path)
					if tex and !selected_textures.has(tex):
						selected_textures.append(tex)
			_refresh_list()


func _refresh_list():
	texture_list.clear()
	var atlas_counter := {}
	for tex in selected_textures:
		if tex is AtlasTexture:
			var at := tex as AtlasTexture
			var src_name := "?"
			if at.atlas and at.atlas.resource_path != "":
				src_name = at.atlas.resource_path.get_file()
			var cnt: int = atlas_counter.get(src_name, 0) + 1
			atlas_counter[src_name] = cnt
			texture_list.add_item("%s#%d" % [src_name, cnt])
		else:
			var name := tex.resource_path.get_file()
			if name == "":
				name = "(内存纹理)"
			texture_list.add_item(name)


func _clear_list():
	selected_textures.clear()
	texture_list.clear()


# ==============================
# 打开切片弹窗
# ==============================
func _on_open_slicer() -> void:
	if _slicer != null and is_instance_valid(_slicer) and _slicer.visible:
		return

	if _slicer == null or not is_instance_valid(_slicer):
		_slicer = SheetSlicer.new()
		var base := EditorInterface.get_base_control()
		if base:
			base.add_child(_slicer)
		_slicer.frames_selected.connect(_on_slicer_frames_selected)
		_slicer.visibility_changed.connect(_update_button_disabled)

	_update_button_disabled()
	_slicer.open()


func _on_slicer_frames_selected(textures: Array[Texture2D]) -> void:
	# 【修改】先清空旧列表，再追加本次切片结果
	selected_textures.clear()
	for tex in textures:
		if not selected_textures.has(tex):
			selected_textures.append(tex)
	_refresh_list()

# ==============================
# 生成关键帧
# ==============================
func _has_existing_texture_track(anim_player: AnimationPlayer, anim_name: String, sprite: Sprite2D) -> bool:
	if anim_player == null or sprite == null:
		return false
	if not anim_player.has_animation(anim_name):
		return false
	var anim := anim_player.get_animation(anim_name)
	var track_path := NodePath(str(sprite.get_path()) + ":texture")
	return anim.find_track(track_path, Animation.TYPE_VALUE) != -1

func _on_generate():
	if !target_sprite:
		print("警告：请先选择目标 Sprite2D 节点")
		return
	if !target_anim_player:
		print("警告：请先选择目标 AnimationPlayer 节点")
		return
	if selected_textures.is_empty():
		print("警告：请先拖拽导入图片")
		return

	var current := target_anim_player.assigned_animation
	if current.is_empty():
		print("警告：请先在 AnimationPlayer 动画面板里选择一个动画")
		return
	anim_name = current
	
	if not fps_input.text.is_valid_float():
		print("错误：FPS 必须是数字")
		return
	fps = float(fps_input.text)
	
	# 判断目标轨道是否已存在
	if _has_existing_texture_track(target_anim_player, current, target_sprite):
		if not _overwrite_checkbox.button_pressed:
			print("ℹ️ texture 轨道已存在，覆盖开关已关闭，跳过")
			return
	
	var ok = KeyframeGenerator.generate_texture_track(
		target_sprite,
		target_anim_player,
		anim_name,
		selected_textures,
		fps
	)

	if ok:
		print("✅ 生成成功：", anim_name, " 共", selected_textures.size(), "帧")
		EditorInterface.inspect_object(target_anim_player)
	else:
		print("❌ 生成失败，请检查控制台")

# ==============================================================
# 内部类：可接收场景树拖拽的节点字段
# ==============================================================
class NodeDropField extends LineEdit:
	signal node_dropped(node: Node)

	func _init():
		editable = false
		placeholder_text = "拖拽场景节点到此处"
		size_flags_horizontal = SIZE_EXPAND_FILL
		mouse_filter = MOUSE_FILTER_STOP
		tooltip_text = "从场景树拖拽 Sprite2D 到这里"

	func _can_drop_data(_pos: Vector2, data: Variant) -> bool:
		var node := _extract_node(data)
		return node is Sprite2D

	func _drop_data(_pos: Vector2, data: Variant) -> void:
		var node := _extract_node(data)
		if node:
			node_dropped.emit(node)

	func _extract_node(data: Variant) -> Node:
		if not (data is Dictionary):
			return null
		if not data.has("type") or data["type"] != "nodes":
			return null
		if not data.has("nodes"):
			return null

		var nodes = data["nodes"]
		if not (nodes is Array) or nodes.is_empty():
			return null

		var n = nodes[0]
		if n is Node:
			return n
		if n is NodePath:
			var root = EditorInterface.get_edited_scene_root()
			if root:
				return root.get_node_or_null(n)
		return null
