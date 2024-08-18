package core

import "core:strings"

import "bundler:util"
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

CreateNewAtlas :: proc(project: ^Project, name: string) {
    new_atlas: Atlas = {
        name = strings.clone(name),
    }

    new_atlas.image = rl.GenImageColor(i32(project.config.atlas_size), i32(project.config.atlas_size), rl.BLANK)
    new_atlas.texture = rl.LoadTextureFromImage(new_atlas.image)

    append(&project.atlas, new_atlas)
}

RenameAtlas :: proc(atlas: ^Atlas, name: string) {
    delete(atlas.name)
    atlas.name = strings.clone(name)

    for &sprite in atlas.sprites {
        delete(sprite.name)
        sprite.atlas = strings.clone(name)
    }
}

DeleteAtlas :: proc(project: ^Project, index: int) {
    atlas := project.atlas[index]

    for sprite in atlas.sprites {
        util.DeleteStrings(sprite.name, sprite.file, sprite.atlas)

        rl.UnloadImage(sprite.image)

        delete(sprite.animation.frames)
    }

    rl.UnloadImage(atlas.image)
    rl.UnloadTexture(atlas.texture)

    delete(atlas.name)
    delete(atlas.sprites)

    unordered_remove(&project.atlas, index)
}
