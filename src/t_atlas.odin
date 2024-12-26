package main

import "core:fmt"

import rl "vendor:raylib"
import stb "vendor:stb/rect_pack"

Atlas :: struct {
    name:     string,
    size:     i32,
    image:    rl.Image `json:"-"`,
    texture:  rl.Texture2D `json:"-"`,

    // Types and data
    textures: [dynamic]Texture,
}

generate_atlas :: proc(atlas: ^Atlas) {
    ctx: stb.Context
    nodes := make([]stb.Node, atlas.size, context.temp_allocator)

    rectangles: [dynamic]stb.Rect
    defer delete(rectangles)

    stb.init_target(&ctx, atlas.size, atlas.size, raw_data(nodes[:]), atlas.size)
    for texture, index in atlas.textures {
        rect: stb.Rect = {
            id = i32(index),
            w  = stb.Coord(texture.image.width),
            h  = stb.Coord(texture.image.height),
        }

        append(&rectangles, rect)
    }

    result := stb.pack_rects(&ctx, raw_data(rectangles), i32(len(rectangles)))

    if result != 1 {
        fmt.println("ERROR: ATLAS: Failed to pack all textures!")
    }

    rl.ImageClearBackground(&atlas.image, rl.BLANK)

    for rect in rectangles {
        if !rect.was_packed {
            fmt.println("ERROR: ATLAS: Skipping texture[", rect.id, "]")
            continue
        }

        texture := &atlas.textures[rect.id]
        texture.bounds.x = f32(rect.x)
        texture.bounds.y = f32(rect.y)

        rl.ImageDraw(&atlas.image, texture.image, {0, 0, texture.bounds.width, texture.bounds.height}, texture.bounds, rl.WHITE)
    }

    rl.UnloadTexture(atlas.texture)
    atlas.texture = rl.LoadTextureFromImage(atlas.image)
}
