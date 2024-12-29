package main

import "core:crypto"
import "core:encoding/uuid"
import fp "core:path/filepath"
import str "core:strings"


import rl "vendor:raylib"

Font :: struct {
    name:       string,
    size:       i32,
    padding:    i32,
    rectangles: []Rectangle,
    glyphs:     []Glyph_Info,
}

unload_font :: proc(font: ^Font) {
    delete(font.name)
    delete(font.rectangles)
    delete(font.glyphs)
}

generate_font :: proc(filename: cstring, font: rl.Font, config: Config, project: ^Project) {
    context.random_generator = crypto.random_generator()

    id := str.concatenate({uuid.to_string(uuid.generate_v7(), context.temp_allocator)})
    export := str.concatenate({project.working_directory, PROJECT_DIR_TEXTURES, fp.SEPARATOR_STRING, id, ".png"}, context.temp_allocator)

    image := rl.LoadImageFromTexture(font.texture)

    rl.ExportImage(image, str.clone_to_cstring(export, context.temp_allocator))

    texture: Texture = {
        id     = id,
        type   = .Font_Texture,
        image  = image,
        bounds = {0, 0, f32(image.width), f32(image.height)},
    }

    font_data: Font = {
        name    = str.clone_from(rl.GetFileNameWithoutExt(filename)),
        size    = font.baseSize,
        padding = font.glyphPadding,
    }

    font_data.rectangles = make([]Rectangle, font.glyphCount)
    font_data.glyphs = make([]Glyph_Info, font.glyphCount)

    for i in 0 ..< font.glyphCount {
        font_data.rectangles[i] = font.recs[i]
        font_data.glyphs[i] = {
            value    = i32(font.glyphs[i].value),
            offset_x = font.glyphs[i].offsetX,
            offset_y = font.glyphs[i].offsetY,
            advance  = font.glyphs[i].advanceX,
        }
    }

    if config.font_generate_sprite {
        sprite: Sprite = {
            name   = str.clone_from(rl.GetFileNameWithoutExt(filename)),
            bounds = {0, 0, f32(image.width), f32(image.height)},
        }

        append(&texture.sprites, sprite)
    }

    append(&texture.fonts, font_data)
    append(&project.textures, texture)
}

generate_raylib_font :: proc(config: Config, project: ^Project) -> (ok: bool) {
    font := rl.GetFontDefault()

    if !rl.IsFontValid(font) {
        return
    }

    generate_font("raylib", font, config, project)
    save_project(project^)

    ok = true

    return
}
