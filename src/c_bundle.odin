package main

import "core:fmt"
import "core:os"
import fp "core:path/filepath"
import str "core:strings"

import rl "vendor:raylib"

Bundle_Error :: enum u8 {
    None,
    Could_Not_Export,
}

export_bundle :: proc(project: Project, config: Config) -> Bundle_Error {
    export_directory := str.concatenate({project.working_directory, PROJECT_DIR_EXPORTS}, context.temp_allocator)
    export_file := str.concatenate({export_directory, fp.SEPARATOR_STRING, BUNDLE_FILENAME}, context.temp_allocator)

    if !os.is_dir(export_directory) {
        os.make_directory(export_directory)
    }

    file_mode: int

    when ODIN_OS == .Linux || ODIN_OS == .Darwin {
        file_mode = os.S_IRUSR | os.S_IWUSR | os.S_IRGRP | os.S_IROTH
    }

    handle, err := os.open(export_file, os.O_WRONLY | os.O_CREATE | os.O_TRUNC, file_mode)
    if err != os.ERROR_NONE {
        fmt.eprintfln("ERROR: BUNDLE: Could not export [%v]", err)
        return .Could_Not_Export
    }

    defer os.close(handle)

    sprite_count: int
    animation_count: int

    for texture in project.textures {
        sprite_count += len(texture.sprites)
        animation_count += len(texture.animations)
    }

    project_version := i32(project.version)
    total_sprite_count := i32(sprite_count)
    atlas_size := i32(project.atlas_size)

    // BUNDLE INFO -> Layout
    // [4 BYTES] Header FourCC
    // [4 BYTES] Bundle version
    // [4 BYTES] Sprite count
    // [4 BYTES] Atlas size
    os.write_string(handle, FOURCC_HEADER[:4])
    os.write_ptr(handle, &project_version, size_of(i32))
    os.write_ptr(handle, &total_sprite_count, size_of(i32))
    os.write_ptr(handle, &atlas_size, size_of(i32))
    pad_file(handle, BUNDLE_BYTE_ALIGNMENT)

    raw_data_size: i32
    raw_data := rl.ExportImageToMemory(project.atlas_image, ".png", &raw_data_size)
    defer rl.MemFree(raw_data)

    // ATLAS DATA -> Layout
    // [4 BYTES] FourCC
    // [4 BYTES] Data size
    // [^ BYTES]
    os.write_string(handle, FOURCC_ATLAS[:4])
    os.write_ptr(handle, &raw_data_size, size_of(i32))
    os.write_ptr(handle, raw_data, int(raw_data_size))
    pad_file(handle, BUNDLE_BYTE_ALIGNMENT)

    for texture in project.textures {
        texture_position: Vector2 = {texture.bounds.x, texture.bounds.y}

        for font in texture.fonts {
            // [4 BYTES] FourCC
            os.write_string(handle, FOURCC_FONT[:4])

            name_length := i32(len(font.name))
            rect_count := i32(len(font.rectangles))
            glyph_count := i32(len(font.glyphs))

            // FONT INFO -> Layout
            // [4 BYTES] Name length
            // [^ BYTES] Name
            // [4 BYTES] Rectangle count
            // [4 BYTES] Glyph count
            os.write_ptr(handle, &name_length, size_of(i32))
            os.write_string(handle, font.name)
            os.write_ptr(handle, &rect_count, size_of(i32))
            os.write_ptr(handle, &glyph_count, size_of(i32))
            pad_file(handle, BUNDLE_BYTE_ALIGNMENT)

            for &rectangle in font.rectangles {
                // RECTANGLE DATA -> Layout
                // [4 BYTES] X
                // [4 BYTES] Y
                // [4 BYTES] Width
                // [4 BYTES] Height
                os.write_ptr(handle, &rectangle.x, size_of(f32))
                os.write_ptr(handle, &rectangle.y, size_of(f32))
                os.write_ptr(handle, &rectangle.width, size_of(f32))
                os.write_ptr(handle, &rectangle.height, size_of(f32))
                pad_file(handle, BUNDLE_BYTE_ALIGNMENT)
            }

            for &glyph in font.glyphs {
                // GLYPH DATA -> Layout
                // [4 BYTES] Value
                // [4 BYTES] X offset
                // [4 BYTES] Y offset
                // [4 BYTES] Advancement
                os.write_ptr(handle, &glyph.value, size_of(f32))
                os.write_ptr(handle, &glyph.offset_x, size_of(f32))
                os.write_ptr(handle, &glyph.offset_y, size_of(f32))
                os.write_ptr(handle, &glyph.advance, size_of(f32))
                pad_file(handle, BUNDLE_BYTE_ALIGNMENT)
            }
        }

        for sprite in texture.sprites {
            // [4 BYTES] FourCC
            os.write_string(handle, FOURCC_SPRITE[:4])

            name_length := i32(len(sprite.name))
            bounds: Rectangle = {
                x      = texture_position.x + sprite.bounds.x,
                y      = texture_position.y + sprite.bounds.y,
                width  = sprite.bounds.width,
                height = sprite.bounds.height,
            }

            origin := sprite.origin

            // SPRITE INFO -> Layout
            // [4 BYTES] Name length
            // [^ BYTES] Name
            os.write_ptr(handle, &name_length, size_of(i32))
            os.write_string(handle, sprite.name)
            pad_file(handle, BUNDLE_BYTE_ALIGNMENT)

            // BOUNDS DATA -> Layout
            // [4 BYTES] X
            // [4 BYTES] Y
            // [4 BYTES] Width
            // [4 BYTES] Height
            os.write_ptr(handle, &bounds.x, size_of(f32))
            os.write_ptr(handle, &bounds.y, size_of(f32))
            os.write_ptr(handle, &bounds.width, size_of(f32))
            os.write_ptr(handle, &bounds.height, size_of(f32))

            // ORIGIN DATA -> Layout
            // [4 BYTES] X
            // [4 BYTES] Y
            os.write_ptr(handle, &origin.x, size_of(f32))
            os.write_ptr(handle, &origin.y, size_of(f32))
        }

        for &animation in texture.animations {
            // [4 BYTES] FourCC
            os.write_string(handle, FOURCC_ANIMATION[:4])

            name_length := i32(len(animation.name))
            frame_count := i32(len(animation.frames))

            // ANIMATION INFO -> Layout
            // [4 BYTES] Name length
            // [^ BYTES] Name
            os.write_ptr(handle, &name_length, size_of(i32))
            os.write_string(handle, animation.name)
            os.write_ptr(handle, &frame_count, size_of(i32))
            os.write_ptr(handle, &animation.speed, size_of(i32))
            pad_file(handle, BUNDLE_BYTE_ALIGNMENT)

            for frame in animation.frames {
                new_frame: Rectangle = {
                    x      = texture_position.x + frame.x,
                    y      = texture_position.y + frame.y,
                    width  = frame.width,
                    height = frame.height,
                }

                // FRAME DATA -> Layout
                // [4 BYTES] X
                // [4 BYTES] Y
                // [4 BYTES] Width
                // [4 BYTES] Height
                os.write_ptr(handle, &new_frame.x, size_of(f32))
                os.write_ptr(handle, &new_frame.y, size_of(f32))
                os.write_ptr(handle, &new_frame.width, size_of(f32))
                os.write_ptr(handle, &new_frame.height, size_of(f32))
            }
        }
    }

    os.write_string(handle, FOURCC_EOF)

    return .None
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
