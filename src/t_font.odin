package main

import "core:crypto"
import "core:encoding/uuid"
import fp "core:path/filepath"
import str "core:strings"

import rl "vendor:raylib"

Glyph :: struct {
    texture:   string,
    value:     i32,
    offset_x:  i32,
    offset_y:  i32,
    advance_x: i32,
}

Font :: struct {
    name:   string,
    id:     string,
    size:   i32,
    glyphs: []Glyph,
}

unload_font :: proc(font: ^Font) {
    delete(font.name)
    delete(font.id)

    for glyph in font.glyphs {
        delete(glyph.texture)
    }

    delete(font.glyphs)
}

generate_font :: proc(filename: cstring, font: rl.Font, config: Config, project: ^Project) -> (ok: bool) {
    context.random_generator = crypto.random_generator()
    image := rl.LoadImageFromTexture(font.texture)
    defer rl.UnloadImage(image)

    new_font: Font
    new_font.id = str.concatenate({uuid.to_string(uuid.generate_v7(), context.temp_allocator)})
    new_font.name = str.clone_from(rl.GetFileNameWithoutExt(filename))
    new_font.size = 32
    new_font.glyphs = make([]Glyph, font.glyphCount)

    for i in 0 ..< font.glyphCount {
        id := str.concatenate({uuid.to_string(uuid.generate_v7(), context.temp_allocator)})
        export := str.concatenate({project.working_directory, PROJECT_DIR_TEXTURES, fp.SEPARATOR_STRING, id, ".png"}, context.temp_allocator)

        glyph_image := rl.ImageFromImage(image, font.recs[i])
        rl.ExportImage(glyph_image, str.clone_to_cstring(export, context.temp_allocator))

        texture: Texture = {
            id     = id,
            type   = .Font_Glyph,
            font   = str.clone(new_font.id),
            image  = glyph_image,
            bounds = {0, 0, f32(glyph_image.width), f32(glyph_image.height)},
        }

        new_font.glyphs[i] = {
            texture   = str.clone(id),
            value     = i32(font.glyphs[i].value),
            offset_x  = font.glyphs[i].offsetX,
            offset_y  = font.glyphs[i].offsetY,
            advance_x = font.glyphs[i].advanceX,
        }

        append(&project.textures, texture)
        project.texture_lookup[id] = len(project.textures) - 1
    }

    append(&project.fonts, new_font)


    ok = true

    return
}

generate_raylib_font :: proc(config: Config, project: ^Project) -> (ok: bool) {
    font := rl.GetFontDefault()

    if !rl.IsFontValid(font) {
        return
    }

    generate_font("raylib.dummy", font, config, project)

    ok = true

    return
}
