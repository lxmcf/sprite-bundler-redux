package main

Animation :: struct {
    name:   string,
    speed:  f32,
    frames: [dynamic]Rectangle,
}

unload_animation :: proc(animation: ^Animation) {
    delete(animation.name)
    delete(animation.frames)
}
