@tool
extends EditorInspectorPlugin

const BatchKeyframePanel = preload("res://addons/batch_sprite_keyframe/batch_keyframe_dock.gd")

var _current_anim_player: AnimationPlayer = null
var _current_panel: Control = null
var _current_header: Control = null

func _can_handle(object: Object) -> bool:
	return object is AnimationPlayer

# 【本轮修改】从 _parse_end 改为 _parse_begin
# 面板会出现在 AnimationPlayer 标题下方、属性之上，避免被属性推到看不见的地方
func _parse_begin(object: Object) -> void:
	var anim_player := object as AnimationPlayer
	if anim_player == null:
		return

	if _current_anim_player != anim_player \
			or _current_panel == null or not is_instance_valid(_current_panel):
		_current_anim_player = anim_player
		_current_panel = BatchKeyframePanel.new()
		_current_panel.setup(anim_player)
		_current_header = CategoryHeader.new("SpriteKeyFrame", _get_anim_sprite_icon())

	add_custom_control(_current_header)
	add_custom_control(_current_panel)

func _get_anim_sprite_icon() -> Texture2D:
	# 拿编辑器主题里 AnimatedSprite2D 的图标
	var theme := EditorInterface.get_editor_theme()
	if theme:
		var tex := theme.get_icon("AnimatedSprite2D", "EditorIcons")
		if tex:
			return tex
	return null

# ==============================================================
# 内联：检查器分类栏（和 AS2P 一致）
# ==============================================================
class CategoryHeader extends Control:
	var title: String = ""
	var icon: Texture2D = null

	func _init(p_title: String, p_icon: Texture2D = null):
		title = p_title
		icon = p_icon
		tooltip_text = "Batch Sprite Keyframe"

	func _get_minimum_size() -> Vector2:
		var font := get_theme_font(&"bold", &"EditorFonts")
		var font_size := get_theme_font_size(&"bold_size", &"EditorFonts")

		var ms: Vector2
		ms.y = font.get_height(font_size)
		if icon:
			ms.y = max(icon.get_height(), ms.y)

		ms.y += get_theme_constant(&"v_separation", &"Tree")
		return ms

	func _draw() -> void:
		var sb := get_theme_stylebox(&"bg", &"EditorInspectorCategory")
		draw_style_box(sb, Rect2(Vector2.ZERO, size))

		var font := get_theme_font(&"bold", &"EditorFonts")
		var font_size := get_theme_font_size(&"bold_size", &"EditorFonts")
		var hs := get_theme_constant(&"h_separation", &"Tree")

		var w: int = font.get_string_size(
			title, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size
		).x
		if icon:
			w += hs + icon.get_width()

		var ofs := (get_size().x - w) / 2

		if icon:
			draw_texture(icon, Vector2(ofs, (get_size().y - icon.get_height()) / 2).floor())
			ofs += hs + icon.get_width()

		var color := get_theme_color(&"font_color", &"Tree")
		draw_string(
			font,
			Vector2(
				ofs,
				font.get_ascent(font_size) + (get_size().y - font.get_height(font_size)) / 2
			).floor(),
			title,
			HORIZONTAL_ALIGNMENT_LEFT,
			get_size().x,
			font_size,
			color
		)
