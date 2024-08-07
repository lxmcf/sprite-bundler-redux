package screens

import "core:os"
import "core:slice"
import "core:strconv"
import "core:strings"

import rl "vendor:raylib"

import "bundler:core"
import "bundler:util"

@(private = "file")
EditorState :: struct {
	camera:        rl.Camera2D,
	cursor:        rl.MouseCursor,
	current_atlas: int,
}

@(private = "file")
state: EditorState

@(private)
UpdateCamera :: proc() {
	if rl.IsMouseButtonDown(.MIDDLE) || rl.IsKeyDown(.LEFT_ALT) {
		delta := rl.GetMouseDelta()

		delta *= -1.0 / state.camera.zoom
		state.camera.target += delta
	}

	mouse_wheel := rl.GetMouseWheelMove()
	if mouse_wheel != 0 && !rl.IsMouseButtonDown(.MIDDLE) {
		mouse_world_position := rl.GetScreenToWorld2D(rl.GetMousePosition(), state.camera)

		state.camera.offset = rl.GetMousePosition()
		state.camera.target = mouse_world_position

		scale_factor := 1 + (0.25 * abs(mouse_wheel))
		if mouse_wheel < 0 do scale_factor = 1.0 / scale_factor

		state.camera.zoom = clamp(state.camera.zoom * scale_factor, 0.125, 64)
	}
}

@(private)
HandleShortcuts :: proc(project: ^core.Project) {
	// Centre camera
	if rl.IsKeyReleased(.Z) {
		screen: rl.Vector2 = {f32(rl.GetScreenWidth()), f32(rl.GetScreenHeight())}

		state.camera.offset = screen / 2
		state.camera.target = {f32(project.config.atlas_size), f32(project.config.atlas_size)} / 2

		state.camera.zoom = 0.5
	}

	if rl.IsKeyDown(.LEFT_CONTROL) {
		// Save Project
		if rl.IsKeyPressed(.S) {
			core.WriteProject(project)
		}

		if rl.IsKeyPressed(.N) {
			core.CreateNewAtlas(project, "test")
		}

		change_page := int(rl.IsKeyPressed(.RIGHT_BRACKET)) - int(rl.IsKeyPressed(.LEFT_BRACKET))
		if change_page != 0 {
			state.current_atlas += change_page

			if state.current_atlas > len(project.atlas) - 1 do state.current_atlas = 0
			if state.current_atlas < 0 do state.current_atlas = len(project.atlas) - 1
		}

		when ODIN_DEBUG {
			if rl.IsKeyPressed(.E) {
				core.ExportBundle(project^)
			}

			// Import Image
			if rl.IsKeyPressed(.R) {
				core.ImportBundle(
					util.CreatePath({project.directory, "export", "bundle.lspx"}, context.temp_allocator),
				)
			}
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
				defer if project.config.copy_files do delete(path)

				if !rl.IsFileExtension(path, ".png") do continue
				texture := rl.LoadImage(path)

				if project.config.copy_files {
					buffer: [4]u8
					result := strconv.itoa(buffer[:], len(project.sprites))
					current_filename := rl.GetFileNameWithoutExt(path)
					current_extension := rl.GetFileExtension(path)

					new_filename := strings.concatenate(
						{string(current_filename), "_", result, string(current_extension)},
						context.temp_allocator,
					)

					new_path := util.CreatePath({project.config.assets_dir, string(new_filename)})

					path = strings.unsafe_string_to_cstring(new_path)

					rl.ExportImage(texture, path)
				}

				sprite: core.Sprite = {
					name        = strings.clone_from_cstring(rl.GetFileNameWithoutExt(path)),
					file        = strings.clone_from_cstring(path),
					atlas_index = state.current_atlas,
					image       = texture,
					source      = {0, 0, f32(texture.width), f32(texture.height)},
				}

				if project.config.auto_center {
					sprite.origin = {sprite.source.width, sprite.source.height} / 2
				}

				append(&project.sprites, sprite)
			}

			PackSprites(project)

			core.GenerateAtlas(project, state.current_atlas)
		} else {
			rl.TraceLog(.ERROR, "FILE: Did not find any files to sort!")
		}
	}
}

@(private)
AtlasIndexSort :: proc(a, b: core.Sprite) -> bool {
	return a.atlas_index < b.atlas_index
}

@(private)
MassWidthSort :: proc(a, b: core.Sprite) -> bool {
	if a.atlas_index != b.atlas_index do return false

	mass_a := a.source.width * a.source.height
	mass_b := b.source.width * b.source.height

	if mass_a == mass_b {
		if a.source.width < b.source.width do return false
		if a.source.width > b.source.width do return true

		if a.source.height < b.source.height do return false
		if a.source.height > b.source.height do return true

		return false
	}

	return mass_a > mass_b
}

@(private)
PackSprites :: proc(project: ^core.Project) {
	slice.stable_sort_by(project.sprites[:], AtlasIndexSort)
	slice.stable_sort_by(project.sprites[:], MassWidthSort)

	valignment, texture_placed := f32(project.config.atlas_size), 0

	// TODO: Wrap this in yet another loop to only loop over a slice of each atlas index
	// NOTE: Should only impact performance when using 'A LOT' of sprites
	for sprite in project.sprites {
		if sprite.source.height < valignment do valignment = sprite.source.height
	}

	// NOTE: I have no idea why I need a pointer... From a pointer... It doesn't sort correctly otherwise
	for &sprite, index in project.sprites {
		times_looped := 0

		current_rectangle := &sprite.source

		for j := 0; j < texture_placed; j += 1 {
			if sprite.atlas_index != project.sprites[j].atlas_index do continue

			for rl.CheckCollisionRecs(current_rectangle^, project.sprites[j].source) {
				current_rectangle.x += project.sprites[j].source.width

				within_x := int(current_rectangle.x + current_rectangle.width) <= project.config.atlas_size

				if !within_x {
					current_rectangle.x = 0
					current_rectangle.y += valignment

					j = 0
				}
			}
		}
		rl.TraceLog(.DEBUG, "Sprite [%s] looped %d times", sprite.name, times_looped)

		within_y := int(current_rectangle.y + current_rectangle.height) <= project.config.atlas_size
		if !within_y {
			rl.TraceLog(.DEBUG, "DELETE: Deleting sprite[%d] %s", index, sprite.name)

			if project.config.copy_files {
				error := os.remove(sprite.file)

				rl.TraceLog(.DEBUG, "Delete error ID [%d]", error)
			}

			delete(sprite.name)
			delete(sprite.file)

			rl.UnloadImage(sprite.image)
			ordered_remove(&project.sprites, index)
		} else {
			texture_placed += 1
		}
	}

	rl.TraceLog(.DEBUG, "Sorted %d textures!", texture_placed)
}

InitEditor :: proc() {
	state.camera.zoom = 0.5
}

UpdateEditor :: proc(project: ^core.Project) {
	state.cursor = .DEFAULT

	UpdateCamera()

	HandleShortcuts(project)
	HandleDroppedFiles(project)

	mouse_position := rl.GetScreenToWorld2D(rl.GetMousePosition(), state.camera)
	for sprite in project.sprites {
		if sprite.atlas_index != state.current_atlas do continue
		if rl.CheckCollisionPointRec(mouse_position, sprite.source) {
			state.cursor = .POINTING_HAND
			break
		}
	}

	rl.SetMouseCursor(state.cursor)
}

DrawEditor :: proc(project: core.Project) {
	rl.BeginMode2D(state.camera)
	defer rl.EndMode2D()

	rl.DrawTextureV(project.background, {}, rl.WHITE)
	rl.DrawTextureV(project.atlas[state.current_atlas].texture, {}, rl.WHITE)

	mouse_position := rl.GetScreenToWorld2D(rl.GetMousePosition(), state.camera)

	for sprite in project.sprites {
		if sprite.atlas_index != state.current_atlas do continue

		if rl.CheckCollisionPointRec(mouse_position, sprite.source) {
			rl.DrawRectangleLinesEx(sprite.source, 2, rl.RED)
			break
		}
	}

	rl.DrawText(strings.unsafe_string_to_cstring(project.atlas[state.current_atlas].name), 0, -80, 80, rl.WHITE)
}

UnloadEditor :: proc() {}
