package main

import rl "vendor:raylib"

Texture_Type :: enum u8 {
    None,
    Texture,
    Font_Texture,
}

Texture :: struct {
    name:       string,
    file:       string,
    type:       Texture_Type,
    bounds:     Rectangle,
    sprites:    [dynamic]Sprite `json:"sprites,omitempty"`,
    animations: [dynamic]Animation `json:"animations,omitempty"`,

    // INTERNAL
    image:      rl.Image `json:"-"`,
    packed:     bool `json:"-"`,
}

unload_texture :: proc(texture: ^Texture) {
    delete(texture.name)
    delete(texture.file)

    rl.UnloadImage(texture.image)

    delete(texture.sprites)
    delete(texture.animations)
}
