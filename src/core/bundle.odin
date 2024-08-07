package core

import "core:os"
import "core:strings"

import rl "vendor:raylib"

import "bundler:util"

BUNDLE_HEADER :: #config(CUSTOM_BUNDLE_HEADER, "LSPP")
BUNDLE_FILE :: #config(CUSTOM_BUNDLE_FILE, "bundle.lspx")

BUNDLE_ATLAS_HEADER :: #config(CUSTOM_ATLAS_HEADER, "ATLS")
BUNDLE_SPRITE_HEADER :: #config(CUSTOM_SPRITE_HEADER, "SPRT")

BUNDLE_BYTE_ALIGNMENT :: 4

BundleError :: enum {
	None,
	Invalid_Alignment,
	No_Sprites,
	No_Atlas,
}

// TODO: Ignore empty bundles (Causes crashing 100% of the time)
ExportBundle :: proc(project: Project) -> BundleError {
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
	util.WriteStringAligned(handle, BUNDLE_HEADER[:4])
	util.WritePtrAligned(handle, &project_version, size_of(i32))
	util.WritePtrAligned(handle, &atlas_count, size_of(i32))
	util.WritePtrAligned(handle, &sprite_count, size_of(i32))

	// ATLAS'
	for atlas in project.atlas {
		// [4 BYTES] FourCC
		util.WriteStringAligned(handle, BUNDLE_ATLAS_HEADER[:4])

		name_length := i32(len(atlas.name))

		raw_data_size, compressed_data_size: i32
		raw_data := rl.ExportImageToMemory(atlas.image, ".png", &raw_data_size)
		defer rl.MemFree(raw_data)

		compressed_data := rl.CompressData(raw_data, raw_data_size, &compressed_data_size)
		defer rl.MemFree(compressed_data)

		// ATLAS INFO -> Layout
		// [4 BYTES] Name length
		// [^ BYTES] Name
		util.WritePtrAligned(handle, &name_length, size_of(i32))
		util.WriteStringAligned(handle, atlas.name, BUNDLE_BYTE_ALIGNMENT)

		// ATLAS DATA -> Layout
		// [4 BYTES] Data size
		// [^ BYTES]
		util.WritePtrAligned(handle, &compressed_data_size, size_of(i32))
		util.WritePtrAligned(handle, compressed_data, int(compressed_data_size), BUNDLE_BYTE_ALIGNMENT)
	}

	// SPRITES
	for sprite in project.sprites {
		// [4 BYTES] FourCC
		util.WriteStringAligned(handle, BUNDLE_SPRITE_HEADER[:4])

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
		util.WritePtrAligned(handle, &frame_count, size_of(i32))
		util.WritePtrAligned(handle, &atlas_index, size_of(i32))
		util.WritePtrAligned(handle, &name_length, size_of(i32))
		util.WriteStringAligned(handle, sprite.name, BUNDLE_BYTE_ALIGNMENT)

		// SOURCE DATA -> Layout
		// [4 BYTES] X
		// [4 BYTES] Y
		// [4 BYTES] Width
		// [4 BYTES] Height
		util.WritePtrAligned(handle, &source.x, size_of(f32))
		util.WritePtrAligned(handle, &source.y, size_of(f32))
		util.WritePtrAligned(handle, &source.width, size_of(f32))
		util.WritePtrAligned(handle, &source.height, size_of(f32))

		// ORIGIN DATA -> Layout
		// [4 BYTES] X
		// [4 BYTES] Y
		util.WritePtrAligned(handle, &origin.x, size_of(f32))
		util.WritePtrAligned(handle, &origin.y, size_of(f32))

		for &frame in sprite.animation.frames {
			// FRAME DATA -> Layout
			// [4 BYTES] X
			// [4 BYTES] Y
			// [4 BYTES] Width
			// [4 BYTES] Height
			util.WritePtrAligned(handle, &frame.x, size_of(f32))
			util.WritePtrAligned(handle, &frame.y, size_of(f32))
			util.WritePtrAligned(handle, &frame.width, size_of(f32))
			util.WritePtrAligned(handle, &frame.height, size_of(f32))
		}
	}

	return .None
}

ImportBundle :: proc(filename: string) -> BundleError {
	handle, _ := util.OpenFile(filename, .READ)
	defer util.CloseFile(handle)

	file_size := os.file_size_from_path(filename)
	if file_size % BUNDLE_BYTE_ALIGNMENT != 0 do return .Invalid_Alignment

	chunk_count := file_size / BUNDLE_BYTE_ALIGNMENT
	chunk_header := make([]byte, BUNDLE_BYTE_ALIGNMENT, context.temp_allocator)

	for i in 0 ..< chunk_count {
		os.read(handle, chunk_header)

		if strings.compare(string(chunk_header), BUNDLE_HEADER) == 0 {
			project_version, atlas_count, sprite_count: i32
			rl.TraceLog(.DEBUG, "---> Found bundle at block %d", i)

			util.ReadPtrAligned(handle, &project_version, size_of(i32), BUNDLE_BYTE_ALIGNMENT)
			util.ReadPtrAligned(handle, &atlas_count, size_of(i32), BUNDLE_BYTE_ALIGNMENT)
			util.ReadPtrAligned(handle, &sprite_count, size_of(i32), BUNDLE_BYTE_ALIGNMENT)

			rl.TraceLog(.DEBUG, "\t\tProject version:  %d", project_version)
			rl.TraceLog(.DEBUG, "\t\tAtlas count:      %d", atlas_count)
			rl.TraceLog(.DEBUG, "\t\tSprite count:     %d", sprite_count)

			if sprite_count == 0 do return .No_Sprites
			if atlas_count == 0 do return .No_Atlas
		}

		if strings.compare(string(chunk_header), BUNDLE_ATLAS_HEADER) == 0 {
			rl.TraceLog(.INFO, "---> Found atlas at block %d", i)

			name_length, decompressed_data_size, compressed_data_size: i32
			util.ReadPtrAligned(handle, &name_length, size_of(i32))

			name := make([]byte, name_length, context.temp_allocator)
			util.ReadAligned(handle, name, BUNDLE_BYTE_ALIGNMENT)

			util.ReadPtrAligned(handle, &compressed_data_size, size_of(i32))
			compressed_data := make([]byte, compressed_data_size, context.temp_allocator)

			rl.TraceLog(.DEBUG, "\t\tAtlas name:       %d", name)
			rl.TraceLog(.DEBUG, "\t\tData size:        %d", compressed_data_size)

			util.ReadAligned(handle, compressed_data, BUNDLE_BYTE_ALIGNMENT)

			decompressed_data := rl.DecompressData(
				raw_data(compressed_data),
				compressed_data_size,
				&decompressed_data_size,
			)
			defer rl.MemFree(decompressed_data)

			// TEMP
			// os.write_entire_file("output.png", decompressed_data[:decompressed_data_size])

			continue
		}

		if strings.compare(string(chunk_header), BUNDLE_SPRITE_HEADER) == 0 {
			rl.TraceLog(.INFO, "---> Found sprite at block %d", i)
		}
	}

	return .None

	// header := make([]byte, 4, context.temp_allocator)
	// os.read(handle, header)

	// project_version, atlas_count, sprite_count: i32

	// os.read_ptr(handle, &project_version, size_of(i32))
	// os.read_ptr(handle, &atlas_count, size_of(i32))
	// os.read_ptr(handle, &sprite_count, size_of(i32))
	// rl.TraceLog(
	// 	.INFO,
	// 	"Found project data:\n\tVersion: %d\n\tAtlas Count: %d\n\tSprite Count: %d",
	// 	project_version,
	// 	atlas_count,
	// 	sprite_count,
	// )

	// for atlas_index in 0 ..< atlas_count {
	// 	rl.TraceLog(.INFO, "Creating atlas[%d]", atlas_index)
	// 	atlas_header := make([]byte, 4, context.temp_allocator)
	// 	os.read(handle, atlas_header)
	// 	rl.TraceLog(.INFO, "Found header: %s", atlas_header)

	// 	name_length, data_size: i32
	// 	os.read_ptr(handle, &name_length, size_of(i32))

	// 	atlas_name := make([]byte, name_length, context.temp_allocator)
	// 	os.read(handle, atlas_name)
	// 	rl.TraceLog(.INFO, "Found name: %s", atlas_name)

	// 	os.read_ptr(handle, &data_size, size_of(i32))
	// 	raw_data := make([]byte, int(data_size), context.temp_allocator)
	// 	os.read(handle, raw_data)
	// }

	// for sprite_index in 0 ..< sprite_count {
	// 	rl.TraceLog(.INFO, "Creating sprite[%d]", sprite_index)
	// 	sprite_header := make([]byte, 4, context.temp_allocator)
	// 	os.read(handle, sprite_header)
	// 	rl.TraceLog(.INFO, "Found header: %s", sprite_header)

	// 	frame_count, atlas_index, name_length: i32
	// 	os.read_ptr(handle, &frame_count, size_of(i32))
	// 	os.read_ptr(handle, &atlas_index, size_of(i32))
	// 	os.read_ptr(handle, &name_length, size_of(i32))

	// 	rl.TraceLog(
	// 		.INFO,
	// 		"Found sprite info:\n\tFrame count: %d\n\tAtlas index: %d\n\tName Length: %d",
	// 		frame_count,
	// 		atlas_index,
	// 		name_length,
	// 	)

	// 	sprite_name := make([]byte, name_length, context.temp_allocator)
	// 	os.read(handle, sprite_name)

	// 	rl.TraceLog(.INFO, "Found name: %s", sprite_name)

	// 	// Temp for debugging
	// 	dummy: f32

	// 	for _ in 0 ..< 6 {
	// 		os.read_ptr(handle, &dummy, size_of(f32))
	// 	}
	// }
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
