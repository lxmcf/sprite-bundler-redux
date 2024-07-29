package core

import "core:encoding/json"
import "core:fmt"
import "core:os"

import rl "vendor:raylib"

Sprite :: struct {
	name:      string,
	file:      string,
	texture:   rl.Texture,
	source:    rl.Rectangle,
	origin:    rl.Vector2,
	animation: struct {
		frames: [dynamic]rl.Rectangle,
		speed:  f32,
	},
}

Project :: struct {
	version: int,
	name:    string,
	sprites: [dynamic]Sprite,
	atlas:   struct {
		size:    int,
		texture: rl.Texture2D,
		image:   rl.Image,
	},
	config:  struct {
		embed_files: bool,
		auto_centre: bool,
	},
}

Error :: enum {
	None,
	Invalid_File,
	Invalid_Data,
}

LoadProject :: proc(filename: string) -> (Project, Error) {
	new_project: Project

	data, ok := os.read_entire_file(filename)
	if !ok {
		rl.TraceLog(.ERROR, "FILE: Failed to load %s", filename)
		return new_project, .Invalid_File
	}
	defer delete(data)

	json_data, err := json.parse(data)
	if err != .None {
		error_name := fmt.tprint(err)
		rl.TraceLog(.ERROR, "FILE: Failed to parse json: %s", error_name)

		return new_project, .Invalid_Data
	}
	defer json.destroy_value(json_data)

	root := json_data.(json.Object)

	new_project.name, _ = json.clone_string(root["name"].(json.String), context.allocator)
	new_project.atlas.size = int(root["atlas_size"].(json.Float))

	rl.TraceLog(.INFO, "Atlas size: %d", new_project.atlas.size)

	return new_project, .None
}

UnloadProject :: proc(project: ^Project) {
	delete(project.name)

	for sprite, index in project.sprites {
		rl.TraceLog(.DEBUG, "DELETE: Deleting sprite[%d] %s", index, sprite.name)

		delete(sprite.name)
		delete(sprite.file)

		rl.UnloadTexture(sprite.texture)
	}

	rl.UnloadTexture(project.atlas.texture)
	rl.UnloadImage(project.atlas.image)

	delete(project.sprites)
}
