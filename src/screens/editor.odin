package screens

import "core:os"
import "core:slice"
import "core:strings"

import rl "vendor:raylib"

import "bundler:core"
import "bundler:util"

@(private = "file")
EditorState :: struct {
	camera:        rl.Camera2D,
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
			// Export Image
			if rl.IsKeyPressed(.E) {
				rl.ExportImage(project.atlas[state.current_atlas].image, "atlas.png")

				compressed_data_size, raw_data_size: i32

				raw_data := rl.ExportImageToMemory(project.atlas[state.current_atlas].image, ".png", &raw_data_size)
				compressed_data := rl.CompressData(raw_data, raw_data_size, &compressed_data_size)

				handle, _ := util.OpenFile("test.dat", .WRITE)
				defer util.CloseFile(handle)

				os.write_string(handle, "LSPP")
				os.write_ptr(handle, &compressed_data_size, size_of(i32))
				os.write_ptr(handle, compressed_data, int(compressed_data_size))
			}

			// Import Image
			if rl.IsKeyPressed(.R) {
				handle, _ := util.OpenFile("test.dat", .READ)
				defer util.CloseFile(handle)

				compressed_data_size, decompressed_data_size: i32

				header := make([]byte, 4, context.temp_allocator)

				os.read(handle, header)
				os.read_ptr(handle, &compressed_data_size, size_of(compressed_data_size))

				compressed_data := make([]byte, compressed_data_size, context.temp_allocator)
				os.read(handle, compressed_data)

				decompressed_data := rl.DecompressData(
					raw_data(compressed_data),
					compressed_data_size,
					&decompressed_data_size,
				)

				image := rl.LoadImageFromMemory(".png", decompressed_data, decompressed_data_size)
				defer rl.UnloadImage(image)

				rl.ExportImage(image, "decomp.png")
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
				if !rl.IsFileExtension(path, ".png") do continue

				texture := rl.LoadImage(path)

				if project.config.copy_files {
					current_filename := rl.GetFileName(path)
					new_path := util.CreatePath(project.assets, string(current_filename))
					defer delete(new_path)

					path = strings.unsafe_string_to_cstring(new_path)

					rl.ExportImage(texture, path)
				}

				sprite: core.Sprite = {
					name   = strings.clone_from_cstring(rl.GetFileName(path)),
					file   = strings.clone_from_cstring(path),
					image  = texture,
					source = {0, 0, f32(texture.width), f32(texture.height)},
				}

				if project.config.auto_centre {
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
MassWidthSort :: proc(a, b: core.Sprite) -> bool {
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
	slice.stable_sort_by(project.sprites[:], MassWidthSort)

	valignment, texture_placed := f32(project.config.atlas_size), 0

	for sprite in project.sprites {
		if sprite.source.height < valignment do valignment = sprite.source.height
	}

	// NOTE: I have no idea why I need a pointer... From a pointer... It doesn't sort correctly otherwise
	for &sprite in project.sprites {
		times_looped := 0

		current_rectangle := &sprite.source

		for j := 0; j < texture_placed; j += 1 {
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

		texture_placed += 1
	}

	rl.TraceLog(.DEBUG, "Sorted %d textures!", texture_placed)
}

InitEditor :: proc() {
	state.camera.zoom = 0.5
}

UpdateEditor :: proc(project: ^core.Project) {
	rl.SetMouseCursor(.DEFAULT)
	UpdateCamera()

	HandleShortcuts(project)
	HandleDroppedFiles(project)

	mouse_position := rl.GetScreenToWorld2D(rl.GetMousePosition(), state.camera)

	for sprite in project.sprites {
		if rl.CheckCollisionPointRec(mouse_position, sprite.source) {
			rl.SetMouseCursor(.POINTING_HAND)
			break
		}
	}
}

DrawEditor :: proc(project: core.Project) {
	rl.BeginMode2D(state.camera)
	defer rl.EndMode2D()

	rl.DrawTextureV(project.background, {}, rl.WHITE)
	rl.DrawTextureV(project.atlas[state.current_atlas].texture, {}, rl.WHITE)

	mouse_position := rl.GetScreenToWorld2D(rl.GetMousePosition(), state.camera)

	for sprite in project.sprites {
		if rl.CheckCollisionPointRec(mouse_position, sprite.source) {
			rl.DrawRectangleLinesEx(sprite.source, 2, rl.RED)
			break
		}
	}

	rl.DrawText(strings.unsafe_string_to_cstring(project.atlas[state.current_atlas].name), 0, -40, 40, rl.WHITE)
}

UnloadEditor :: proc() {}
