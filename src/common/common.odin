package common

import rl "vendor:raylib"

Sprite :: struct {
	name:      string,
	file:      string,
	texture:   rl.Texture2D,
	source:    rl.Rectangle,
	origin:    rl.Vector2,
	animation: struct {
		frames: [dynamic]rl.Rectangle,
		speed:  f32,
	},
}

Project :: struct {
	version:            int,
	name:               string,
	should_embed_files: bool,
	sprites:            [dynamic]Sprite,
}
