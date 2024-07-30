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
	if rl.IsMouseButtonDown(.MIDDLE) || rl.IsKeyDown(.LEFT_ALT) {
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
HandleShortcuts :: proc(project: ^core.Project) {
	// Centre camera
	if rl.IsKeyReleased(.Z) {
		screen: rl.Vector2 = {f32(rl.GetScreenWidth()), f32(rl.GetScreenHeight())}

		editor_camera.offset = screen / 2
		editor_camera.target = {f32(project.atlas.size), f32(project.atlas.size)} / 2
		editor_camera.zoom = 0.5
	}

	if rl.IsKeyDown(.LEFT_CONTROL) {
		// Save Project
		if rl.IsKeyPressed(.S) {
			core.WriteProject(project)
		}

		// Export Image
		if rl.IsKeyPressed(.E) {
			rl.ExportImage(project.atlas.foreground_image, "atlas.png")
		}
	}
}

@(private)
HandleDroppedFiles :: proc(project: ^core.Project) {
	if rl.IsFileDropped() {
		files := rl.LoadDroppedFiles()
		defer rl.UnloadDroppedFiles(files)

		if files.count > 0 {
			for i in 0 ..< files.count {
				path := files.paths[i]
				if !rl.IsFileExtension(path, ".png") do continue

				texture := rl.LoadImage(path)

				sprite: core.Sprite = {
					name    = strings.clone_from_cstring(rl.GetFileName(path)),
					file    = strings.clone_from_cstring(path),
					texture = texture,
					source  = {0, 0, f32(texture.width), f32(texture.height)},
				}

				if project.config.auto_centre {
					sprite.origin = {sprite.source.width, sprite.source.height} / 2
				}

				append(&project.sprites, sprite)
			}

			PackSprites(project)

			rl.ImageClearBackground(&project.atlas.foreground_image, rl.BLANK)

			for sprite in project.sprites {
				rl.ImageDraw(
					&project.atlas.foreground_image,
					sprite.texture,
					{0, 0, sprite.source.width, sprite.source.height},
					sprite.source,
					rl.WHITE,
				)
			}

			rl.UnloadTexture(project.atlas.foreground_texture)
			project.atlas.foreground_texture = rl.LoadTextureFromImage(project.atlas.foreground_image)
		} else {
			rl.TraceLog(.ERROR, "FILE: Did not find any files to sort!")
		}
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

	rl.TraceLog(.DEBUG, "Sorted %d textures!", texture_placed)
}

InitEditor :: proc() {
	editor_camera.zoom = 0.5
}

UpdateEditor :: proc(project: ^core.Project) {
	rl.SetMouseCursor(.DEFAULT)
	UpdateCamera()

	HandleShortcuts(project)
	HandleDroppedFiles(project)

	mouse_position := rl.GetScreenToWorld2D(rl.GetMousePosition(), editor_camera)

	for sprite in project.sprites {
		if rl.CheckCollisionPointRec(mouse_position, sprite.source) {
			rl.SetMouseCursor(.POINTING_HAND)
			break
		}
	}
}

DrawEditor :: proc(project: core.Project) {
	rl.BeginMode2D(editor_camera)
	defer rl.EndMode2D()

	rl.DrawTextureV(project.atlas.background_texture, {}, rl.WHITE)
	// rl.DrawTextureV(project.atlas.foreground_texture, {}, rl.WHITE)

	for sprite in project.sprites {
		rl.DrawTexturePro(project.atlas.foreground_texture, sprite.source, sprite.source, {}, 0, rl.WHITE)
	}

	mouse_position := rl.GetScreenToWorld2D(rl.GetMousePosition(), editor_camera)

	for sprite in project.sprites {
		if rl.CheckCollisionPointRec(mouse_position, sprite.source) {
			rl.DrawRectangleLinesEx(sprite.source, 2, rl.RED)
			break
		}
	}
}

UnloadEditor :: proc() {}
