package main

import "core:encoding/json"
import "core:fmt"
import "core:os"
import fp "core:path/filepath"
import str "core:strings"

import rl "vendor:raylib"
import stb "vendor:stb/rect_pack"

Project :: struct {
    name:              string,
    version:           int,
    atlas_size:        int,
    textures:          [dynamic]Texture,

    // Internal
    file:              string `json:"-"`,
    atlas_image:       rl.Image `json:"-"`,
    atlas_texture:     rl.Texture `json:"-"`,
    back_texture:      rl.Texture `json:"-"`,
    working_directory: string `json:"-"`,
}

Project_Error :: enum u8 {
    None,
    Invalid_File,
    Failed_Serialisation,
    Failed_Deserialisation,
}

unload_project :: proc(project: ^Project) {
    delete(project.file)
    delete(project.name)
    delete(project.working_directory)

    rl.UnloadImage(project.atlas_image)
    rl.UnloadTexture(project.atlas_texture)
    rl.UnloadTexture(project.back_texture)

    for &texture in project.textures {
        unload_texture(&texture)
    }

    delete(project.textures)
}

save_project :: proc(project: Project) -> (err: Project_Error) {
    if os.is_file(project.file) {
        os.rename(project.file, str.concatenate({project.file, ".bkp"}, context.temp_allocator))
    }

    options: json.Marshal_Options = {
        use_enum_names = true,
        use_spaces     = true,
        pretty         = true,
        spaces         = 4,
    }

    if project_data, error := json.marshal(project, options, context.temp_allocator); error == nil {
        os.write_entire_file(project.file, project_data)
    } else {
        fmt.eprintln("ERROR: PROJECT: Failed to serialise:", error)
        err = .Failed_Serialisation
    }

    return
}

load_project :: proc(filename: string) -> (project: Project, err: Project_Error) {
    if project_data, ok := os.read_entire_file(filename, context.temp_allocator); ok {
        json_err := json.unmarshal(project_data, &project)

        if json_err == nil {
            fmt.eprintfln("ERROR: PROJECT: Failed to deserialise project {%v}", json_err)
            err = .Failed_Deserialisation
            return
        }

        atlas_size := i32(project.atlas_size)

        project.atlas_image = rl.GenImageColor(atlas_size, atlas_size, rl.BLANK)
        project.working_directory = str.concatenate({fp.dir(filename, context.temp_allocator), fp.SEPARATOR_STRING})

        background_image := rl.GenImageChecked(atlas_size, atlas_size, atlas_size / 32, atlas_size / 32, rl.LIGHTGRAY, rl.GRAY)
        defer rl.UnloadImage(background_image)

        project.back_texture = rl.LoadTextureFromImage(background_image)

        for &texture in project.textures {
            sprite_file := str.concatenate({project.working_directory, PROJECT_DIR_TEXTURES, fp.SEPARATOR_STRING, texture.file}, context.temp_allocator)

            if os.is_file(sprite_file) {
                texture.image = rl.LoadImage(str.clone_to_cstring(sprite_file, context.temp_allocator))
            } else {
                fmt.eprintfln("ERROR: TEXTURE: Failed to load file [%s]", sprite_file)

                texture.image = rl.GenImageChecked(i32(texture.bounds.width), i32(texture.bounds.height), i32(texture.bounds.width) / 32, i32(texture.bounds.height) / 32, rl.MAGENTA, rl.BLACK)
            }
        }

        generate_texture_atlas(&project)
    } else {
        fmt.eprintln("ERROR: PROJECT: Failed to open project")
        err = .Invalid_File
    }

    return
}

generate_texture_atlas :: proc(project: ^Project) {
    atlas_size := i32(project.atlas_size)
    ctx: stb.Context
    nodes := make([]stb.Node, atlas_size, context.temp_allocator)

    rectangles: [dynamic]stb.Rect
    defer delete(rectangles)

    stb.init_target(&ctx, atlas_size, atlas_size, raw_data(nodes[:]), atlas_size)
    for texture, index in project.textures {
        rect: stb.Rect = {
            id = i32(index),
            w  = stb.Coord(texture.image.width),
            h  = stb.Coord(texture.image.height),
        }

        append(&rectangles, rect)
    }

    result := stb.pack_rects(&ctx, raw_data(rectangles), i32(len(rectangles)))

    if result != 1 {
        fmt.eprintln("ERROR: ATLAS: Failed to pack all textures, suggest resizing atlas!")
    }

    rl.ImageClearBackground(&project.atlas_image, rl.BLANK)

    for rect in rectangles {
        texture := &project.textures[rect.id]

        if !rect.was_packed {
            fmt.eprintln("ERROR: ATLAS: Skipping texture[", rect.id, "]")

            // Force to be OOB
            texture.bounds.x = f32(-atlas_size)
            texture.bounds.y = f32(-atlas_size)

            continue
        }

        texture.bounds.x = f32(rect.x)
        texture.bounds.y = f32(rect.y)

        rl.ImageDraw(&project.atlas_image, texture.image, {0, 0, texture.bounds.width, texture.bounds.height}, texture.bounds, rl.WHITE)
    }

    rl.UnloadTexture(project.atlas_texture)
    project.atlas_texture = rl.LoadTextureFromImage(project.atlas_image)
}
