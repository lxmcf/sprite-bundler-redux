package common

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
Writeable_Sprite :: struct {
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
sprite_to_writable :: proc(sprite: Sprite) -> Writeable_Sprite {
    writable: Writeable_Sprite = {
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
sprite_to_readable :: proc(sprite: Writeable_Sprite) -> Sprite {
    readable: Sprite = {
        name = strings.clone(sprite.name),
        file = strings.clone(sprite.file),
        atlas = strings.clone(sprite.atlas),
        source = {x = sprite.source.x, y = sprite.source.y, width = sprite.source.width, height = sprite.source.height},
        origin = {sprite.origin.x, sprite.origin.y},
    }

    return readable
}

@(private)
unload_writeable_sprite :: proc(sprite: ^Writeable_Sprite) {}

delete_sprite :: proc(project: ^Project, sprite: ^Sprite) {
    if project.config.copy_files {
        os.remove(sprite.file)
    }

    delete(sprite.name)
    delete(sprite.file)
    delete(sprite.atlas)

    rl.UnloadImage(sprite.image)

    delete(sprite.animation.frames)
}
