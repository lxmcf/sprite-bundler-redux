package main

import rl "vendor:raylib"

Texture_Type :: enum u8 {
    None,
    Texture,
    Font_Texture,
}

Texture :: struct {
    id:         string,
    type:       Texture_Type,
    bounds:     Rectangle,
    fonts:      [dynamic]Font `json:"fonts,omitempty"`,
    sprites:    [dynamic]Sprite `json:"sprites,omitempty"`,
    animations: [dynamic]Animation `json:"animations,omitempty"`,

    // INTERNAL
    image:      rl.Image `json:"-"`,
    packed:     bool `json:"-"`,
}

unload_texture :: proc(texture: ^Texture) {
    delete(texture.id)

    rl.UnloadImage(texture.image)

    for &sprite in texture.sprites {
        delete(sprite.name)
    }
    delete(texture.sprites)

    for &font in texture.fonts {
        unload_font(&font)
    }
    delete(texture.fonts)

    delete(texture.animations)
}
