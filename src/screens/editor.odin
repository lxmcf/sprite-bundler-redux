package screens

import "core:os"
import "core:strings"

import rl "vendor:raylib"

import "bundler:core"

@(private = "file")
editor_camera: rl.Camera2D

@(private)
UpdateCamera :: proc() {
	if rl.IsMouseButtonDown(.MIDDLE) {
		delta := rl.GetMouseDelta()

		delta *= -1.0 / editor_camera.zoom
		editor_camera.target += delta
	}

	mouse_wheel := rl.GetMouseWheelMove()
	if mouse_wheel != 0 {
		mouse_world_position := rl.GetScreenToWorld2D(rl.GetMousePosition(), editor_camera)

		editor_camera.offset = rl.GetMousePosition()
		editor_camera.target = mouse_world_position

		scale_factor := 1 + (0.25 * abs(mouse_wheel))
		if mouse_wheel < 0 {
			scale_factor = 1.0 / scale_factor
		}

		editor_camera.zoom = clamp(editor_camera.zoom * scale_factor, 0.125, 64)
	}
}

InitEditor :: proc() {
	editor_camera.zoom = 0.5
}

UpdateEditor :: proc(project: ^core.Project) {
	UpdateCamera()

	if rl.IsFileDropped() {
		files := rl.LoadDroppedFiles()
		defer rl.UnloadDroppedFiles(files)

		if files.count > 0 {
			for i in 0 ..< files.count {
				path := files.paths[i]
				if !rl.IsFileExtension(path, ".png") do continue

				texture := rl.LoadTexture(path)

				sprite: core.Sprite = {
					name    = strings.clone_from_cstring(rl.GetFileName(path)),
					file    = strings.clone_from_cstring(path),
					texture = texture,
					source  = {0, 0, f32(texture.width), f32(texture.height)},
				}

				append(&project.sprites, sprite)
			}
		} else {
			rl.TraceLog(.ERROR, "FILE: Did not find any files to sort!")
		}
	}
}

DrawEditor :: proc(project: core.Project) {
	rl.BeginMode2D(editor_camera)
	defer rl.EndMode2D()

	rl.DrawRectangleRec({0, 0, f32(project.atlas.size), f32(project.atlas.size)}, rl.LIGHTGRAY)

	position: rl.Vector2

	for sprite in project.sprites {
		rl.DrawTextureV(sprite.texture, position, rl.WHITE)
		position += {f32(sprite.texture.width), 0}
	}
}
