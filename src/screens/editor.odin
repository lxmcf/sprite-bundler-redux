package screens

import "core:os"
import "core:slice"
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
	if mouse_wheel != 0 && !rl.IsMouseButtonDown(.MIDDLE) {
		mouse_world_position := rl.GetScreenToWorld2D(rl.GetMousePosition(), editor_camera)

		editor_camera.offset = rl.GetMousePosition()
		editor_camera.target = mouse_world_position

		scale_factor := 1 + (0.25 * abs(mouse_wheel))
		if mouse_wheel < 0 do scale_factor = 1.0 / scale_factor

		editor_camera.zoom = clamp(editor_camera.zoom * scale_factor, 0.125, 64)
	}
}

@(private)
MassWidthSort :: proc(a, b: core.Sprite) -> bool {
	mass_a := a.source.width * a.source.height
	mass_b := b.source.width * b.source.height

	if mass_a == mass_b {
		if a.source.width < b.source.width do return false
		if a.source.width > b.source.width do return true

		if a.source.height < b.source.height do return false
		if a.source.height > b.source.height do return true
	}

	return mass_a > mass_b
}

@(private)
PackSprites :: proc(project: ^core.Project) {
	slice.sort_by(project.sprites[:], MassWidthSort)

	valignment, texture_placed := f32(project.atlas.size), 0

	for sprite in project.sprites {
		if sprite.source.height < valignment do valignment = sprite.source.height
	}

	for &sprite in project.sprites {
		for j := 0; j < texture_placed; j += 1 {
			current_rect := project.sprites[j].source

			for rl.CheckCollisionRecs(sprite.source, current_rect) {
				sprite.source.x += current_rect.width

				within_x := int(sprite.source.x + sprite.source.width) <= project.atlas.size

				if !within_x {
					sprite.source.x = 0
					sprite.source.y += valignment

					j = 0
				}
			}
		}
		texture_placed += 1
	}

	rl.TraceLog(.INFO, "Sorted %d textures!", texture_placed)
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

			PackSprites(project)
		} else {
			rl.TraceLog(.ERROR, "FILE: Did not find any files to sort!")
		}
	}
}

DrawEditor :: proc(project: core.Project) {
	rl.BeginMode2D(editor_camera)
	defer rl.EndMode2D()

	rl.DrawRectangleRec({0, 0, f32(project.atlas.size), f32(project.atlas.size)}, rl.LIGHTGRAY)

	for sprite in project.sprites {
		rl.DrawTextureV(sprite.texture, {sprite.source.x, sprite.source.y}, rl.WHITE)
		rl.DrawRectangleLinesEx(sprite.source, 1, rl.RED)
	}
}
