package main

import "core:crypto"
import "core:encoding/uuid"
import "core:fmt"
import fp "core:path/filepath"
import str "core:strings"
import "core:unicode/utf8"

import rl "vendor:raylib"

_ :: fmt

file_import_image :: proc(filename: cstring, config: Config, project: ^Project) -> (ok: bool) {
    context.random_generator = crypto.random_generator()
    image := rl.LoadImage(filename)

    if !rl.IsImageValid(image) {
        rl.UnloadImage(image)
        return
    }

    if config.trim_whitespace {
        rl.ImageAlphaCrop(&image, 0)
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

    if config.auto_centre_origin {
        sprite.origin = {texture.bounds.width, texture.bounds.height} / 2
    }

    append(&texture.sprites, sprite)
    append(&project.textures, texture)

    ok = true

    return
}

file_import_font :: proc(filename: cstring, config: Config, project: ^Project) -> (ok: bool) {
    character_runes := utf8.string_to_runes(FONT_CHARACTERS, context.temp_allocator)

    font := rl.LoadFontEx(filename, 32, raw_data(character_runes), i32(len(character_runes)))
    defer rl.UnloadFont(font)

    if !rl.IsFontValid(font) {
        return
    }

    generate_font(filename, font, config, project)

    ok = true

    return
}
