package main

import "core:crypto"
import "core:encoding/uuid"
import "core:fmt"
import fp "core:path/filepath"
import str "core:strings"
import "core:unicode/utf8"

import rl "vendor:raylib"

_ :: fmt

file_import_image :: proc(filename: cstring, project: ^Project) -> (ok: bool) {
    context.random_generator = crypto.random_generator()
    image := rl.LoadImage(filename)

    if !rl.IsImageValid(image) {
        rl.UnloadImage(image)
        return
    }

    id := str.concatenate({uuid.to_string(uuid.generate_v7(), context.temp_allocator)})
    export := str.concatenate({project.working_directory, PROJECT_DIR_TEXTURES, fp.SEPARATOR_STRING, id, ".png"}, context.temp_allocator)

    rl.ExportImage(image, str.clone_to_cstring(export, context.temp_allocator))

    texture: Texture = {
        id     = id,
        type   = .Texture,
        image  = image,
        bounds = {0, 0, f32(image.width), f32(image.height)},
    }

    sprite: Sprite = {
        name   = str.clone_from(rl.GetFileNameWithoutExt(filename)),
        bounds = {0, 0, texture.bounds.width, texture.bounds.height},
    }

    append(&texture.sprites, sprite)
    append(&project.textures, texture)

    ok = true

    return
}

file_import_font :: proc(filename: cstring, project: ^Project) -> (ok: bool) {
    context.random_generator = crypto.random_generator()
    character_runes := utf8.string_to_runes(FONT_CHARACTERS, context.temp_allocator)

    font := rl.LoadFontEx(filename, 32, raw_data(character_runes), i32(len(character_runes)))
    defer rl.UnloadFont(font)

    if !rl.IsFontValid(font) {
        return
    }

    id := str.concatenate({uuid.to_string(uuid.generate_v7(), context.temp_allocator)})
    export := str.concatenate({project.working_directory, PROJECT_DIR_TEXTURES, fp.SEPARATOR_STRING, id}, context.temp_allocator)

    image := rl.LoadImageFromTexture(font.texture)

    rl.ExportImage(image, str.clone_to_cstring(export, context.temp_allocator))

    texture: Texture = {
        id     = id,
        type   = .Font_Texture,
        image  = image,
        bounds = {0, 0, f32(image.width), f32(image.height)},
    }

    font_data: Font = {
        id      = id,
        size    = font.baseSize,
        padding = font.glyphPadding,
    }

    font_data.rectangles = make([dynamic]Rectangle, font.glyphCount)
    font_data.glyphs = make([dynamic]GlyphInfo, font.glyphCount)

    for i in 0 ..< font.glyphCount {
        font_data.rectangles[i] = font.recs[i]
        font_data.glyphs[i] = {
            value    = font.glyphs[i].value,
            offset_x = font.glyphs[i].offsetX,
            offset_y = font.glyphs[i].offsetY,
            advance  = font.glyphs[i].advanceX,
        }
    }

    save_font(project^, font_data)
    delete_font(&font_data)

    append(&project.textures, texture)

    ok = true

    return
}
