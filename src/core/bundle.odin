package core

import "core:os"
import "core:strings"

import "bundler:util"
import rl "vendor:raylib"

BUNDLE_HEADER :: #config(CUSTOM_BUNDLE_HEADER, "LSPX")
BUNDLE_EOF :: #config(CUSTOM_BUNDLE_EOF, "BEOF")
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

    project_sprite_count: int
    for atlas in project.atlas do project_sprite_count += len(atlas.sprites)

    project_version := i32(project.version)
    atlas_count := i32(len(project.atlas))
    total_sprite_count := i32(project_sprite_count)
    atlas_size := i32(project.config.atlas_size)

    // BUNDLE INFO -> Layout
    // [4 BYTES] Header FourCC
    // [4 BYTES] Bundle version
    // [4 BYTES] Atlas count
    // [4 BYTES] Sprite count
    // [4 BYTES] Atlas size
    os.write_string(handle, BUNDLE_HEADER[:4])
    os.write_ptr(handle, &project_version, size_of(i32))
    os.write_ptr(handle, &atlas_count, size_of(i32))
    os.write_ptr(handle, &total_sprite_count, size_of(i32))
    os.write_ptr(handle, &atlas_size, size_of(i32))

    // ATLAS'
    for atlas in project.atlas {
        // [4 BYTES] FourCC
        os.write_string(handle, BUNDLE_ATLAS_HEADER[:4])

        name_length := i32(len(atlas.name))
        sprite_count := i32(len(atlas.sprites))

        raw_data_size, compressed_data_size: i32
        raw_data := rl.ExportImageToMemory(atlas.image, ".png", &raw_data_size)
        defer rl.MemFree(raw_data)

        compressed_data := rl.CompressData(raw_data, raw_data_size, &compressed_data_size)
        defer rl.MemFree(compressed_data)

        // ATLAS INFO -> Layout
        // [4 BYTES] Sprite count
        // [4 BYTES] Name length
        // [^ BYTES] Name
        os.write_ptr(handle, &sprite_count, size_of(i32))
        os.write_ptr(handle, &name_length, size_of(i32))
        os.write_string(handle, atlas.name)
        util.PadFile(handle, BUNDLE_BYTE_ALIGNMENT)

        // ATLAS DATA -> Layout
        // [4 BYTES] Data size
        // [^ BYTES]
        os.write_ptr(handle, &compressed_data_size, size_of(i32))
        os.write_ptr(handle, compressed_data, int(compressed_data_size))
        util.PadFile(handle, BUNDLE_BYTE_ALIGNMENT)
    }

    // SPRITES
    for atlas, index in project.atlas {
        for sprite in atlas.sprites {
            // [4 BYTES] FourCC
            os.write_string(handle, BUNDLE_SPRITE_HEADER[:4])

            frame_count := i32(len(sprite.animation.frames))
            frame_speed := sprite.animation.speed
            name_length := i32(len(sprite.name))

            atlas_name_length := i32(len(sprite.atlas))

            source := sprite.source
            origin := sprite.origin
            atlas_index := i32(index)

            // SPRITE INFO -> Layout
            // [4 BYTES] Animation frame count
            // [4 BYTES] Animation speed
            // [4 BYTES] Atlas name length
            // [4 BYTES] Atlas name
            // [4 BYTES] Atlas index
            // [4 BYTES] Name length
            // [^ BYTES] Name
            os.write_ptr(handle, &frame_count, size_of(i32))
            os.write_ptr(handle, &frame_speed, size_of(f32))
            os.write_ptr(handle, &atlas_name_length, size_of(i32))
            os.write_string(handle, sprite.atlas)
            util.PadFile(handle, BUNDLE_BYTE_ALIGNMENT)
            os.write_ptr(handle, &atlas_index, size_of(i32))
            os.write_ptr(handle, &name_length, size_of(i32))
            os.write_string(handle, sprite.name)
            util.PadFile(handle, BUNDLE_BYTE_ALIGNMENT)

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

    os.write_string(handle, BUNDLE_EOF)

    return .None
}

ImportBundle :: proc(filename: string) -> BundleError {
    handle, _ := util.OpenFile(filename, .READ)
    defer util.CloseFile(handle)

    file_size := os.file_size_from_path(filename)
    if file_size % BUNDLE_BYTE_ALIGNMENT != 0 do return .Invalid_Alignment

    chunk_header := make([]byte, BUNDLE_BYTE_ALIGNMENT, context.temp_allocator)

    for strings.compare(string(chunk_header), BUNDLE_EOF) != 0 {
        os.read(handle, chunk_header)

        if strings.compare(string(chunk_header), BUNDLE_HEADER) == 0 {
            project_version, atlas_count, sprite_count, atlas_size: i32
            current_position, _ := os.seek(handle, 0, os.SEEK_CUR)
            rl.TraceLog(.DEBUG, "---> Found bundle at chunk[%d]", current_position / BUNDLE_BYTE_ALIGNMENT)

            os.read_ptr(handle, &project_version, size_of(i32))
            os.read_ptr(handle, &atlas_count, size_of(i32))
            os.read_ptr(handle, &sprite_count, size_of(i32))
            os.read_ptr(handle, &atlas_size, size_of(i32))

            rl.TraceLog(.DEBUG, "\t\tProject version:  %d", project_version)
            rl.TraceLog(.DEBUG, "\t\tAtlas count:      %d", atlas_count)
            rl.TraceLog(.DEBUG, "\t\tSprite count:     %d", sprite_count)
            rl.TraceLog(.DEBUG, "\t\tAtlas Size:       %d", atlas_size)

            if sprite_count == 0 do return .No_Sprites
            if atlas_count == 0 do return .No_Atlas
        }

        if strings.compare(string(chunk_header), BUNDLE_ATLAS_HEADER) == 0 {
            current_position, _ := os.seek(handle, 0, os.SEEK_CUR)
            rl.TraceLog(.DEBUG, "---> Found atlas at chunk[%d]", current_position / BUNDLE_BYTE_ALIGNMENT)

            name_length, decompressed_data_size, compressed_data_size, sprite_count: i32
            os.read_ptr(handle, &sprite_count, size_of(i32))
            os.read_ptr(handle, &name_length, size_of(i32))

            atlas_name := make([]byte, name_length, context.temp_allocator)
            os.read(handle, atlas_name)
            util.AlignFile(handle, BUNDLE_BYTE_ALIGNMENT)

            os.read_ptr(handle, &compressed_data_size, size_of(i32))
            compressed_data := make([]byte, compressed_data_size, context.temp_allocator)

            rl.TraceLog(.DEBUG, "\t\tSprite count:     %d", sprite_count)
            rl.TraceLog(.DEBUG, "\t\tAtlas name:       %s", atlas_name)
            rl.TraceLog(.DEBUG, "\t\tData size:        %d", compressed_data_size)

            os.read(handle, compressed_data)
            util.AlignFile(handle, BUNDLE_BYTE_ALIGNMENT)

            decompressed_data := rl.DecompressData(raw_data(compressed_data), compressed_data_size, &decompressed_data_size)
            defer rl.MemFree(decompressed_data)

            // TEMP
            export_filename := strings.concatenate({string(atlas_name), ".png"}, context.temp_allocator)
            os.write_entire_file(export_filename, decompressed_data[:decompressed_data_size])

            continue
        }

        if strings.compare(string(chunk_header), BUNDLE_SPRITE_HEADER) == 0 {
            current_position, _ := os.seek(handle, 0, os.SEEK_CUR)
            rl.TraceLog(.DEBUG, "---> Found sprite at chunk[%d]", current_position / BUNDLE_BYTE_ALIGNMENT)

            frame_count, name_length, atlas_name_length, atlas_index: i32
            frame_speed: f32

            os.read_ptr(handle, &frame_count, size_of(i32))
            os.read_ptr(handle, &frame_speed, size_of(f32))
            os.read_ptr(handle, &atlas_name_length, size_of(i32))

            atlas_name := make([]byte, atlas_name_length, context.temp_allocator)
            os.read(handle, atlas_name)
            util.AlignFile(handle, BUNDLE_BYTE_ALIGNMENT)

            os.read_ptr(handle, &atlas_index, size_of(i32))
            os.read_ptr(handle, &name_length, size_of(i32))

            sprite_name := make([]byte, name_length, context.temp_allocator)
            os.read(handle, sprite_name)
            util.AlignFile(handle, BUNDLE_BYTE_ALIGNMENT)

            rl.TraceLog(.DEBUG, "\t\tFrame count:     %d", frame_count)
            rl.TraceLog(.DEBUG, "\t\tFrame speed:     %f", frame_speed)
            rl.TraceLog(.DEBUG, "\t\tAtlas name:      %s", atlas_name)
            rl.TraceLog(.DEBUG, "\t\tAtlas index:     %d", atlas_index)
            rl.TraceLog(.DEBUG, "\t\tSprite name:     %s", sprite_name)

            rect: [4]f32
            for i in 0 ..< 4 {
                os.read_ptr(handle, &rect[i], size_of(f32))
            }

            rl.TraceLog(.DEBUG, "\t\tSprite Source:   [ %.f, %.f, %.f, %.f ]", rect[0], rect[1], rect[2], rect[3])

            origin: [2]f32
            for i in 0 ..< 2 {
                os.read_ptr(handle, &origin[i], size_of(f32))
            }

            rl.TraceLog(.DEBUG, "\t\tSprite Origin:   [ %.f, %.f ]", origin[0], origin[1])

            continue
        }
    }

    return .None
}
