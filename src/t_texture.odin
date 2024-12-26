package main

import rl "vendor:raylib"

Texture :: struct {
    name:       string,
    file:       string,
    image:      rl.Image `json:"-"`,
    bounds:     Rectangle,
    sprites:    [dynamic]Sprite,
    animations: [dynamic]Animation,
}
