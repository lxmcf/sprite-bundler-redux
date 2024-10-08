package common

import "core:fmt"
import "core:os"
import "core:path/filepath"

import rl "vendor:raylib"

BUNDLE_HEADER :: #config(CUSTOM_BUNDLE_HEADER, "LSPX")
BUNDLE_EOF :: #config(CUSTOM_BUNDLE_EOF, "BEOF")
BUNDLE_FILE :: #config(CUSTOM_BUNDLE_FILE, "bundle.lspx")

BUNDLE_ATLAS_HEADER :: #config(CUSTOM_ATLAS_HEADER, "ATLS")
BUNDLE_SPRITE_HEADER :: #config(CUSTOM_SPRITE_HEADER, "SPRT")
BUNDLE_FONT_HEADER :: #config(CUSTOM_FONT_HEADER, "FONT")

BUNDLE_BYTE_ALIGNMENT :: 4

Bundle_Error :: enum {
    None,
    Could_Not_Open,
    Invalid_Alignment,
    No_Sprites,
    No_Atlas,
}

@(private)
align_file :: proc(handle: os.Handle, alignment: i64) -> i64 {
    position, _ := os.seek(handle, 0, os.SEEK_CUR)
    offset := position % alignment

    if offset > 0 {
        result, _ := os.seek(handle, alignment - offset, os.SEEK_CUR)
        return result
    } else {
        return 0
    }
}

@(private)
pad_file :: proc(handle: os.Handle, alignment: i64) {
    position, _ := os.seek(handle, 0, os.SEEK_CUR)
    offset := position % alignment

    if offset > 0 {
        buffer := make([]byte, alignment - offset, context.temp_allocator)
        os.write(handle, buffer)
    }
}

export_bundle :: proc(project: Project) -> Bundle_Error {
    export_directory := fmt.tprint(project.working_directory, "export", sep = filepath.SEPARATOR_STRING)
    handle_file := fmt.tprint(export_directory, BUNDLE_FILE, sep = filepath.SEPARATOR_STRING)

    os.make_directory(export_directory)
    file_mode: int

    when ODIN_OS == .Linux || ODIN_OS == .Darwin {
        file_mode = os.S_IRUSR | os.S_IWUSR | os.S_IRGRP | os.S_IROTH
    }

    handle, err := os.open(handle_file, os.O_WRONLY | os.O_CREATE | os.O_TRUNC, file_mode)
    if err != os.ERROR_NONE {
        return .Could_Not_Open
    }

    defer os.close(handle)

    project_sprite_count: int
    for atlas in project.atlas {
        project_sprite_count += len(atlas.sprites)
    }

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

        raw_data_size: i32
        raw_data := rl.ExportImageToMemory(atlas.image, ".png", &raw_data_size)
        defer rl.MemFree(raw_data)

        // ATLAS INFO -> Layout
        // [4 BYTES] Sprite count
        // [4 BYTES] Name length
        // [^ BYTES] Name
        os.write_ptr(handle, &sprite_count, size_of(i32))
        os.write_ptr(handle, &name_length, size_of(i32))
        os.write_string(handle, atlas.name)
        pad_file(handle, BUNDLE_BYTE_ALIGNMENT)

        // ATLAS DATA -> Layout
        // [4 BYTES] Data size
        // [^ BYTES]
        os.write_ptr(handle, &raw_data_size, size_of(i32))
        os.write_ptr(handle, raw_data, int(raw_data_size))
        pad_file(handle, BUNDLE_BYTE_ALIGNMENT)
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
            pad_file(handle, BUNDLE_BYTE_ALIGNMENT)

            os.write_ptr(handle, &atlas_index, size_of(i32))
            os.write_ptr(handle, &name_length, size_of(i32))
            os.write_string(handle, sprite.name)
            pad_file(handle, BUNDLE_BYTE_ALIGNMENT)

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
