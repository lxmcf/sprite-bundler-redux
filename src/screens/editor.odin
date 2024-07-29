package screens

import "core:encoding/json"
import "core:fmt"
import "core:os"

import rl "vendor:raylib"

import "bundler:common"

@(private = "file")
current_project: common.Project
editor_camera: rl.Camera

InitEditor :: proc(filename: string) {
	data, ok := os.read_entire_file(filename)
	if !ok {
		rl.TraceLog(.ERROR, "FILE: Failed to load %s", filename)
		return
	}
	defer delete(data)

	json_data, err := json.parse(data)
	if err != .None {
		error_name := fmt.tprint(err)
		rl.TraceLog(.ERROR, "Failed to parse json: %s", error_name)

		return
	}
	defer json.destroy_value(json_data)

	root := json_data.(json.Object)

	for element in root["sprites"].(json.Array) {
		sprite := element.(json.Object)

		new_sprite: common.Sprite
		new_sprite.name, _ = json.clone_string(sprite["name"].(json.String), context.allocator)

		append(&current_project.sprites, new_sprite)
	}
}

UpdateEditor :: proc() {

}

DrawEditor :: proc() {

}

UnloadEditor :: proc() {
	for sprite, index in current_project.sprites {
		rl.UnloadTexture(sprite.texture)
		delete(sprite.name)
	}

	delete(current_project.sprites)
}

@(private = "file")
SaveProject :: proc() {

}
