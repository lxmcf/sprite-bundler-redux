package core

import "core:strings"

import rl "vendor:raylib"

Atlas :: struct {
    name:    string,
    image:   rl.Image,
    texture: rl.Texture2D,
    sprites: [dynamic]Sprite,
}

@(private)
WriteableAtlas :: struct {
    name:    string,
    sprites: [dynamic]WriteableSprite,
}

@(private)
AtlasToWriteable :: proc(atlas: Atlas) -> WriteableAtlas {
    writeable: WriteableAtlas = {
        name = atlas.name,
    }

    for sprite in atlas.sprites {
        append(&writeable.sprites, ToWriteable(sprite))
    }

    return writeable
}

@(private)
AtlasToReadable :: proc(atlas: WriteableAtlas) -> Atlas {
    readable: Atlas = {
        name = strings.clone(atlas.name),
    }

    for sprite in atlas.sprites {
        append(&readable.sprites, ToReadable(sprite))
    }

    return readable
}

UnloadWriteableAtlas :: proc(atlas: ^WriteableAtlas) {
    for &sprite in atlas.sprites do UnloadWriteable(&sprite)

    delete(atlas.sprites)
}

GenerateAtlas :: proc(atlas: ^Atlas) {
    rl.ImageClearBackground(&atlas.image, rl.BLANK)

    for sprite in atlas.sprites {
        rl.ImageDraw(
            &atlas.image,
            sprite.image,
            {0, 0, sprite.source.width, sprite.source.height},
            sprite.source,
            rl.WHITE,
        )
    }

    rl.UnloadTexture(atlas.texture)
    atlas.texture = rl.LoadTextureFromImage(atlas.image)
}

CreateNewAtlas :: proc(project: ^Project, name: string, generate: bool = true) {
    new_atlas: Atlas = {
        name = strings.clone(name, context.temp_allocator),
    }

    if generate {
        new_atlas.image = rl.GenImageColor(i32(project.config.atlas_size), i32(project.config.atlas_size), rl.BLANK)
        new_atlas.texture = rl.LoadTextureFromImage(new_atlas.image)
    }

    append(&project.atlas, new_atlas)
}

// TODO: Store sprites in atlas rather than 1 list to make it easier to delete an atlas
DeleteAtlas :: proc() {}
