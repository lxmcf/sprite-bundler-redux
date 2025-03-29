package main

Sprite :: struct {
    name:   string,
    origin: Vector2,
    bounds: Rectangle,
}

unload_sprite :: proc(sprite: ^Sprite) {
    delete(sprite.name)
}
