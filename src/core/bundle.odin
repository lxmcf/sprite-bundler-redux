package core

import "core:os"

import rl "vendor:raylib"

import "bundler:util"

BUNDLE_HEADER :: #config(CUSTOM_BUNDLE_HEADER, "LSPP")
BUNDLE_FILE :: #config(CUSTOM_BUNDLE_FILE, "bundle.lspx")

BUNDLE_ATLAS_HEADER :: #config(CUSTOM_ATLAS_HEADER, "ATLS")
BUNDLE_SPRITE_HEADER :: #config(CUSTOM_SPRITE_HEADER, "SPRT")

// TODO: Align to 4 bytes
ExportBundle :: proc(project: Project) {
	export_directory := util.CreatePath({project.directory, "export"}, context.temp_allocator)
	os.make_directory(export_directory)

	handle_file := util.CreatePath({export_directory, BUNDLE_FILE}, context.temp_allocator)
	handle, _ := util.OpenFile(handle_file, .WRITE)
	defer util.CloseFile(handle)

	project_version := i32(project.version)
	atlas_count := i32(len(project.atlas))
	sprite_count := i32(len(project.sprites))

	// BUNDLE INFO -> Layout
	// [4 BYTES] Header FourCC
	// [4 BYTES] Bundle version
	// [4 BYTES] Texture atlas count
	// [4 BYTES] Sprite count
	os.write_string(handle, BUNDLE_HEADER[:4])
	os.write_ptr(handle, &project_version, size_of(i32))
	os.write_ptr(handle, &atlas_count, size_of(i32))
	os.write_ptr(handle, &sprite_count, size_of(i32))

	// ATLAS'
	for atlas in project.atlas {
		// [4 BYTES] FourCC
		os.write_string(handle, BUNDLE_ATLAS_HEADER[:4])

		name_length := i32(len(atlas.name))

		raw_data_size, compressed_data_size: i32
		raw_data := rl.ExportImageToMemory(atlas.image, ".png", &raw_data_size)
		defer rl.MemFree(raw_data)

		compressed_data := rl.CompressData(raw_data, raw_data_size, &compressed_data_size)
		defer rl.MemFree(compressed_data)

		// ATLAS INFO -> Layout
		// [4 BYTES] Name length
		// [^ BYTES] Name
		os.write_ptr(handle, &name_length, size_of(i32))
		os.write_string(handle, atlas.name)

		// ATLAS DATA -> Layout
		// [4 BYTES] Data size
		// [^ BYTES]
		os.write_ptr(handle, &compressed_data_size, size_of(i32))
		os.write_ptr(handle, compressed_data, int(compressed_data_size))
	}

	// SPRITES
	for sprite in project.sprites {
		// [4 BYTES] FourCC
		os.write_string(handle, BUNDLE_SPRITE_HEADER[:4])

		frame_count := i32(len(sprite.animation.frames))
		atlas_index := i32(sprite.atlas_index)
		name_length := i32(len(sprite.name))
		source := sprite.source
		origin := sprite.origin

		// SPRITE INFO -> Layout
		// [4 BYTES] Animation frame count
		// [4 BYTES] Texture atlas index
		// [4 BYTES] Name length
		// [^ BYTES] Name
		os.write_ptr(handle, &frame_count, size_of(i32))
		os.write_ptr(handle, &atlas_index, size_of(i32))
		os.write_ptr(handle, &name_length, size_of(i32))
		os.write_string(handle, sprite.name)

		// SOURCE DATA -> Layout
		// [4 BYTES] X
		// [4 BYTES] Y
		// [4 BYTES] Width
		// [4 BYTES] Height
		os.write_ptr(handle, &source.x, size_of(f32))
		os.write_ptr(handle, &source.y, size_of(f32))
		os.write_ptr(handle, &source.width, size_of(f32))
		os.write_ptr(handle, &source.height, size_of(f32))

		// ORIGIN DATA -> Layout
		// [4 BYTES] X
		// [4 BYTES] Y
		os.write_ptr(handle, &origin.x, size_of(f32))
		os.write_ptr(handle, &origin.y, size_of(f32))

		for &frame in sprite.animation.frames {
			// FRAME DATA -> Layout
			// [4 BYTES] X
			// [4 BYTES] Y
			// [4 BYTES] Width
			// [4 BYTES] Height
			os.write_ptr(handle, &frame.x, size_of(f32))
			os.write_ptr(handle, &frame.y, size_of(f32))
			os.write_ptr(handle, &frame.width, size_of(f32))
			os.write_ptr(handle, &frame.height, size_of(f32))
		}
	}
}

ImportBundle :: proc(filename: string) {
	handle, _ := util.OpenFile(filename, .READ)
	defer util.CloseFile(handle)

	header := make([]byte, 4, context.temp_allocator)
	os.read(handle, header)

	project_version, atlas_count, sprite_count: i32

	os.read_ptr(handle, &project_version, size_of(i32))
	os.read_ptr(handle, &atlas_count, size_of(i32))
	os.read_ptr(handle, &sprite_count, size_of(i32))
	rl.TraceLog(
		.INFO,
		"Found project data:\n\tVersion: %d\n\tAtlas Count: %d\n\tSprite Count: %d",
		project_version,
		atlas_count,
		sprite_count,
	)

	for atlas_index in 0 ..< atlas_count {
		rl.TraceLog(.INFO, "Creating atlas[%d]", atlas_index)
		atlas_header := make([]byte, 4, context.temp_allocator)
		os.read(handle, atlas_header)
		rl.TraceLog(.INFO, "Found header: %s", atlas_header)

		name_length, data_size: i32
		os.read_ptr(handle, &name_length, size_of(i32))

		atlas_name := make([]byte, name_length, context.temp_allocator)
		os.read(handle, atlas_name)
		rl.TraceLog(.INFO, "Found name: %s", atlas_name)

		os.read_ptr(handle, &data_size, size_of(i32))
		raw_data := make([]byte, int(data_size), context.temp_allocator)
		os.read(handle, raw_data)
	}

	for sprite_index in 0 ..< sprite_count {
		rl.TraceLog(.INFO, "Creating sprite[%d]", sprite_index)
		sprite_header := make([]byte, 4, context.temp_allocator)
		os.read(handle, sprite_header)
		rl.TraceLog(.INFO, "Found header: %s", sprite_header)

		frame_count, atlas_index, name_length: i32
		os.read_ptr(handle, &frame_count, size_of(i32))
		os.read_ptr(handle, &atlas_index, size_of(i32))
		os.read_ptr(handle, &name_length, size_of(i32))

		rl.TraceLog(
			.INFO,
			"Found sprite info:\n\tFrame count: %d\n\tAtlas index: %d\n\tName Length: %d",
			frame_count,
			atlas_index,
			name_length,
		)

		sprite_name := make([]byte, name_length, context.temp_allocator)
		os.read(handle, sprite_name)

		rl.TraceLog(.INFO, "Found name: %s", sprite_name)

		// Temp for debugging
		dummy: f32

		for _ in 0 ..< 6 {
			os.read_ptr(handle, &dummy, size_of(f32))
		}
	}
}

when false {
	DO_NOT_CALL :: proc(project: Project) {
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
