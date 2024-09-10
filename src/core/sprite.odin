package core

import "core:os"
import "core:strings"

import rl "vendor:raylib"

Sprite :: struct {
    name:      string,
    file:      string,
    atlas:     string,
    image:     rl.Image,
    source:    rl.Rectangle,
    origin:    rl.Vector2,
    animation: struct {
        speed:  f32,
        frames: [dynamic]rl.Rectangle,
    },
}

@(private)
WriteableSprite :: struct {
    name:      string,
    file:      string,
    atlas:     string,
    source:    rl.Rectangle,
    origin:    rl.Vector2,
    animation: struct {
        speed:  f32,
        frames: [dynamic]rl.Rectangle,
    },
}

@(private)
SpriteToWritable :: proc(sprite: Sprite) -> WriteableSprite {
    writable: WriteableSprite = {
        name = sprite.name,
        file = sprite.file,
        atlas = sprite.atlas,
        source = sprite.source,
        origin = sprite.origin,
        animation = {frames = sprite.animation.frames, speed = sprite.animation.speed},
    }

    return writable
}

@(private)
SpriteToReadable :: proc(sprite: WriteableSprite) -> Sprite {
    readable: Sprite = {
        name = strings.clone(sprite.name),
        file = strings.clone(sprite.file),
        atlas = strings.clone(sprite.atlas),
        source = {x = sprite.source.x, y = sprite.source.y, width = sprite.source.width, height = sprite.source.height},
        origin = {sprite.origin.x, sprite.origin.y},
    }

    if os.is_file(sprite.file) {
        readable.image = rl.LoadImage(strings.clone_to_cstring(sprite.file, context.temp_allocator))
    } else {
        rl.TraceLog(.ERROR, "[FILE] Failed to load file [%s]", sprite.file)

        readable.image = rl.GenImageColor(i32(sprite.source.width), i32(sprite.source.height), rl.MAGENTA)
    }

    return readable
}

@(private)
UnloadWriteableSprite :: proc(sprite: ^WriteableSprite) {}

DeleteSprite :: proc(project: ^Project, sprite: ^Sprite) {
    if project.config.copy_files {
        os.remove(sprite.file)
    }

    delete(sprite.name)
    delete(sprite.file)
    delete(sprite.atlas)

    rl.UnloadImage(sprite.image)

    delete(sprite.animation.frames)
}
