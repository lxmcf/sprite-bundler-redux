package screens

import "core:os"
import "core:slice"
import "core:strings"

import rl "vendor:raylib"

import "bundler:core"

@(private = "file")
editor_camera: rl.Camera2D

FileMode :: enum {
	WRITE,
	READ,
}

File :: os.Handle

// Simplification of os.open based on read/write_entire_file
OpenFile :: proc(filename: string, mode: FileMode, truncate := true) -> (File, bool) {
	file_flags, file_mode: int

	switch mode {
	case .WRITE:
		file_flags = os.O_WRONLY | os.O_CREATE
		if (truncate) do file_flags |= os.O_TRUNC

		when ODIN_OS == .Linux || ODIN_OS == .Darwin {
			file_mode = os.S_IRUSR | os.S_IWUSR | os.S_IRGRP | os.S_IROTH
		}
	case .READ:
		file_flags = os.O_RDONLY
	}

	if file_handle, error := os.open(filename, file_flags, file_mode); error != os.ERROR_NONE {
		return file_handle, false
	} else {
		return file_handle, true
	}
}

CloseFile :: proc(handle: File) -> bool {
	return os.close(handle) == os.ERROR_NONE
}

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

			when ODIN_DEBUG {
				compressed_data_size, raw_data_size: i32

				raw_data := rl.ExportImageToMemory(project.atlas.foreground_image, ".png", &raw_data_size)
				compressed_data := rl.CompressData(raw_data, raw_data_size, &compressed_data_size)

				handle, _ := OpenFile("test.dat", .WRITE)
				defer CloseFile(handle)

				os.write_string(handle, "LSPP")
				os.write_ptr(handle, &compressed_data_size, size_of(i32))
				os.write_ptr(handle, compressed_data, int(compressed_data_size))
			}
		}

		// Import image
		when ODIN_DEBUG {
			if rl.IsKeyPressed(.R) {
				handle, _ := OpenFile("test.dat", .READ)
				defer CloseFile(handle)

				compressed_data_size, decompressed_data_size: i32

				header := make([]byte, 4, context.temp_allocator)

				os.read(handle, header)

				os.read_ptr(handle, &compressed_data_size, size_of(compressed_data_size))
				rl.TraceLog(.DEBUG, "Compressed Size: %d", compressed_data_size)

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

			core.GenerateAtlas(project)
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

	valignment, texture_placed := f32(project.atlas.size), 0

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

				within_x := int(current_rectangle.x + current_rectangle.width) <= project.atlas.size

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
	rl.DrawTextureV(project.atlas.foreground_texture, {}, rl.WHITE)

	mouse_position := rl.GetScreenToWorld2D(rl.GetMousePosition(), editor_camera)

	for sprite in project.sprites {
		if rl.CheckCollisionPointRec(mouse_position, sprite.source) {
			rl.DrawRectangleLinesEx(sprite.source, 2, rl.RED)
			break
		}
	}
}

UnloadEditor :: proc() {}
