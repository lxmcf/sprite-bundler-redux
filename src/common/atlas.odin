package common

import "core:strings"

import rl "vendor:raylib"

Atlas :: struct {
    name:    string,
    image:   rl.Image,
    texture: rl.Texture2D,
    sprites: [dynamic]Sprite,
}

@(private)
Writeable_Atlas :: struct {
    name:    string,
    sprites: [dynamic]Writeable_Sprite,
}

@(private)
atlas_to_writeable :: proc(atlas: Atlas) -> Writeable_Atlas {
    writeable: Writeable_Atlas = {
        name = atlas.name,
    }

    for sprite in atlas.sprites {
        append(&writeable.sprites, to_writeable(sprite))
    }

    return writeable
}

@(private)
atlas_to_readable :: proc(atlas: Writeable_Atlas) -> Atlas {
    readable: Atlas = {
        name = strings.clone(atlas.name),
    }

    for sprite in atlas.sprites {
        append(&readable.sprites, to_readable(sprite))
    }

    return readable
}

unload_writeable_atlas :: proc(atlas: ^Writeable_Atlas) {
    for &sprite in atlas.sprites {
        unload_writeable(&sprite)
    }

    delete(atlas.sprites)
}

generate_atlas :: proc(atlas: ^Atlas) {
    rl.ImageClearBackground(&atlas.image, rl.BLANK)

    for sprite in atlas.sprites {
        rl.ImageDraw(&atlas.image, sprite.image, {0, 0, sprite.source.width, sprite.source.height}, sprite.source, rl.WHITE)
    }

    rl.UnloadTexture(atlas.texture)
    atlas.texture = rl.LoadTextureFromImage(atlas.image)
}

create_new_atlas :: proc(project: ^Project, name: string) {
    new_atlas: Atlas = {
        name = strings.clone(name),
    }

    new_atlas.image = rl.GenImageColor(i32(project.config.atlas_size), i32(project.config.atlas_size), rl.BLANK)
    new_atlas.texture = rl.LoadTextureFromImage(new_atlas.image)

    append(&project.atlas, new_atlas)
}

rename_atlas :: proc(atlas: ^Atlas, name: string) {
    delete(atlas.name)
    atlas.name = strings.clone(name)

    for &sprite in atlas.sprites {
        delete(sprite.name)
        sprite.atlas = strings.clone(name)
    }
}

delete_atlas :: proc(project: ^Project, index: int) {
    atlas := project.atlas[index]

    for &sprite in atlas.sprites {
        delete_sprite(project, &sprite)
    }

    rl.UnloadImage(atlas.image)
    rl.UnloadTexture(atlas.texture)

    delete(atlas.name)
    delete(atlas.sprites)

    unordered_remove(&project.atlas, index)
}
