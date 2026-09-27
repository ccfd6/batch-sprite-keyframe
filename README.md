# Batch Sprite Keyframe

A Godot 4 editor plugin that converts image sequences into texture keyframe animations for `Sprite2D` nodes.

一款 Godot 4 编辑器插件，用于将图片序列快速转换为 `Sprite2D` 的 texture 动画轨道。

---

## Features

- **Drag & drop import** — Drop multiple images from the FileSystem into the list.
- **Sprite sheet slicing** — Visual slicer with row/column or pixel-size modes, box selection, and Ctrl+scroll zoom.
- **Batch add** — Select multiple files at once, imported in natural filename order.
- **One-click generation** — Inserts texture keyframes on the target `Sprite2D` using the animation's current FPS.
- **Overwrite toggle** — Optionally overwrite existing tracks; preference is persisted across sessions.
- **Target binding** — Assign `Sprite2D` nodes via scene tree drag or picker, remembered per session.

---

## 功能说明

- **拖拽导入** —— 从文件系统拖入多张图片，自动追加到列表中。
- **精灵表切片** —— 提供可视化切片窗口，支持按行列或像素尺寸切割，支持框选、Ctrl + 滚轮缩放。
- **批量添加** —— 一次选取多张图片，按文件名自然排序导入。
- **一键生成** —— 依据当前动画的 FPS，在指定 `Sprite2D` 上批量插入 texture 关键帧。
- **覆盖控制** —— 可开关是否覆盖已有轨道，设置持久化保存。
- **目标绑定** —— 支持从场景树拖拽或选择器指定 `Sprite2D`，绑定关系按会话记忆。

---

## Installation

1. Download or clone this repository.
2. Copy the `addons/batch_sprite_keyframe/` folder into your project's `addons/` directory.
3. Open **Project → Project Settings → Plugins** and enable **Batch Sprite Keyframe**.

---

## 安装方法

1. 下载或克隆本仓库。
2. 将 `addons/batch_sprite_keyframe/` 文件夹复制到项目的 `addons/` 目录下。
3. 打开 **项目 → 项目设置 → 插件**，启用 **Batch Sprite Keyframe**。

---

## Usage

1. Select an `AnimationPlayer` node in the scene tree.
2. In the inspector, locate the **SpriteKeyFrame** section.
3. Choose the target `Sprite2D` (drag from scene tree or click **选择**).
4. Import images via drag & drop, the sheet slicer, or batch add.
5. Set the FPS and toggle the overwrite option as needed.
6. Click **✅ 生成关键帧** to create the texture track.

---

## 使用方法

1. 在场景树中选中一个 `AnimationPlayer` 节点。
2. 在检查器中找到 **SpriteKeyFrame** 区域。
3. 指定目标 `Sprite2D`（可从场景树拖拽，或点击 **选择**）。
4. 通过拖拽、精灵表切片或批量添加导入图片。
5. 按需设置 FPS 与覆盖开关。
6. 点击 **✅ 生成关键帧**，自动创建 texture 轨道。
