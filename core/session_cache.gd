@tool
extends RefCounted

# 编辑器会话级缓存。static var 的生命周期 = 编辑器进程生命周期。
# 重启 Godot 编辑器 → 自动清空。
# 用途：跨节点切换 / 场景 tab 切换 时保留插件状态。
#
# key 格式："<scene_id>::<anim_player_path>"
#   scene_id：已保存场景用 scene_file_path；未保存场景用 "unsaved::<root_instance_id>"
# value：NodePath —— 相对场景根的 Sprite2D 路径
static var sprite_paths: Dictionary = {}
