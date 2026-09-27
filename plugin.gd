@tool
extends EditorPlugin

const InspectorPlugin = preload("res://addons/batch_sprite_keyframe/inspector_plugin.gd")

var inspector_plugin: EditorInspectorPlugin

func _enter_tree():
	inspector_plugin = InspectorPlugin.new()
	add_inspector_plugin(inspector_plugin)

func _exit_tree():
	remove_inspector_plugin(inspector_plugin)
	inspector_plugin = null
