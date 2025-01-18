package main

import "core:crypto"
import "core:encoding/uuid"
import fp "core:path/filepath"
import str "core:strings"

import rl "vendor:raylib"

file_import_image :: proc(filename: cstring, config: Config, project: ^Project) -> (ok: bool) {
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
    project.texture_lookup[id] = len(project.textures) - 1

    ok = true

    return
}

file_import_font :: proc(filename: cstring, config: Config, project: ^Project) -> (ok: bool) {
    context.random_generator = crypto.random_generator()
    font := rl.LoadFont(filename)

    if !rl.IsFontValid(font) {
        rl.UnloadFont(font)
        return
    }

    ok = generate_font(filename, font, config, project)

    return
}
