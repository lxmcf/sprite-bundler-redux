package main

import "core:crypto"
import "core:encoding/uuid"
import "core:fmt"
import fp "core:path/filepath"
import str "core:strings"

import rl "vendor:raylib"

file_import_image :: proc(filename: cstring, project: ^Project) -> (ok: bool) {
    context.random_generator = crypto.random_generator()
    image := rl.LoadImage(filename)

    if !rl.IsImageValid(image) {
        rl.UnloadImage(image)
        return
    }

    id := uuid.generate_v7()
    new_file := str.concatenate({uuid.to_string(id, context.temp_allocator), ".png"})
    export := str.concatenate({project.working_directory, PROJECT_DIR_TEXTURES, fp.SEPARATOR_STRING, new_file}, context.temp_allocator)

    rl.ExportImage(image, str.clone_to_cstring(export, context.temp_allocator))

    texture: Texture = {
        name   = str.clone_from(rl.GetFileNameWithoutExt(filename)),
        file   = new_file,
        type   = .Texture,
        image  = image,
        bounds = {0, 0, f32(image.width), f32(image.height)},
        packed = false,
    }

    append(&project.textures, texture)

    ok = true

    return
}

file_import_font :: proc(filename: string, project: ^Project) {
    fmt.eprintln("ERROR: FONT: Font importing not yet implimented")
}
