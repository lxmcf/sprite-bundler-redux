package main

import rl "vendor:raylib"

Texture_Type :: enum u8 {
    None,
    Texture,
    Font_Glyph,
}

Texture :: struct {
    id:         string,
    font:       string `json:font,omitempty`,
    type:       Texture_Type,
    bounds:     Rectangle,
    sprites:    [dynamic]Sprite `json:"sprites,omitempty"`,
    animations: [dynamic]Animation `json:"animations,omitempty"`,

    // INTERNAL
    image:      rl.Image `json:"-"`,
    packed:     bool `json:"-"`,
}

unload_texture :: proc(texture: ^Texture) {
    delete(texture.id)
    delete(texture.font)

    rl.UnloadImage(texture.image)

    for &sprite in texture.sprites {
        delete(sprite.name)
    }
    delete(texture.sprites)

    delete(texture.animations)
}
