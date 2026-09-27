@tool
extends RefCounted
class_name KeyframeGenerator

# 核心：为指定Sprite2D在AnimationPlayer中生成texture关键帧轨道
# 不破坏原有其他轨道，只新增/覆盖texture轨道
static func generate_texture_track(
	sprite: Sprite2D,
	anim_player: AnimationPlayer,
	anim_name: String,
	textures: Array[Texture2D],
	fps: float
) -> bool:
	if not sprite or not anim_player or textures.is_empty():
		return false

	var frame_duration = 1.0 / max(fps, 0.1)
	var animation: Animation

	# 获取或创建动画
	if anim_player.has_animation(anim_name):
		animation = anim_player.get_animation(anim_name)
	else:
		animation = Animation.new()
		animation.loop_mode = Animation.LOOP_LINEAR
		anim_player.add_animation(anim_name, animation)

	# 计算轨道路径
	# 用 AnimationPlayer 的 root_node 作为基准算相对路径
	var root_node := anim_player.get_node_or_null(anim_player.root_node)
	if root_node == null:
		root_node = anim_player.get_parent()
	var sprite_path_str := str(root_node.get_path_to(sprite))
	var track_path := NodePath(sprite_path_str + ":texture")

	# 查找已有 texture 轨道，没有则新建
	var track_idx = animation.find_track(track_path, Animation.TYPE_VALUE)
	if track_idx == -1:
		track_idx = animation.add_track(Animation.TYPE_VALUE)
		animation.track_set_path(track_idx, track_path)
		animation.value_track_set_update_mode(track_idx, Animation.UPDATE_DISCRETE)
	else:
		# Godot 4.x 没有 track_remove_all_keys，倒序逐个删除
		for i in range(animation.track_get_key_count(track_idx) - 1, -1, -1):
			animation.track_remove_key(track_idx, i)

	# 批量插入关键帧
	for i in textures.size():
		var time = i * frame_duration
		animation.track_insert_key(track_idx, time, textures[i])

	# 更新动画总长度
	animation.length = textures.size() * frame_duration

	return true
