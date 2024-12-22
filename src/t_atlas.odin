package main

import rl "vendor:raylib"

Atlas :: struct {
    name:       string,
    image:      rl.Image,
    texture:    rl.Texture2D,

    // Types and data
    textures:   [dynamic]Texture,
    sprites:    [dynamic]Sprite,
    animations: [dynamic]Animation,
}
