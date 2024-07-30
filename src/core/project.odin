package core

import "core:encoding/json"
import "core:fmt"
import "core:os"
import "core:path/filepath"
import "core:strings"

import rl "vendor:raylib"

DEFAULT_PROJECT_DIRECTORY :: "projects"
DEFAULT_PROJECT_FILENAME :: "project.lspp"

Sprite :: struct {
	name:      string,
	file:      string,
	texture:   rl.Image,
	source:    rl.Rectangle,
	origin:    rl.Vector2,
	animation: struct {
		frames: [dynamic]rl.Rectangle,
		speed:  f32,
	},
}

@(private)
WriteableSprite :: struct {
	name:      string,
	file:      string,
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
	file:    string,
	sprites: [dynamic]Sprite,
	atlas:   struct {
		size:               int,
		background_texture: rl.Texture2D,
		foreground_texture: rl.Texture2D,
		foreground_image:   rl.Image,
	},
	config:  struct {
		embed_files: bool,
		auto_centre: bool,
	},
}

@(private)
WriteableProject :: struct {
	version: int,
	name:    string,
	sprites: [dynamic]WriteableSprite,
	atlas:   struct {
		size: int,
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
	Project_Exists,
}

GetProjectFilenames :: proc(name: string, allocator := context.allocator) -> (directory: string, file: string) {
	project_directory := strings.concatenate({DEFAULT_PROJECT_DIRECTORY, filepath.SEPARATOR_STRING, name})
	project_file := strings.concatenate({project_directory, filepath.SEPARATOR_STRING, DEFAULT_PROJECT_FILENAME})

	return project_directory, project_file
}

CreateNewProject :: proc(name: string, atlas_size: int, embed_files, auto_centre: bool) -> (Project, Error) {
	project_directory, project_file := GetProjectFilenames(name)
	defer delete(project_directory)

	os.make_directory(project_directory)

	if os.is_file(project_file) do return {}, .Project_Exists

	project_to_create: Project
	project_to_create.version = 100
	project_to_create.name = name
	project_to_create.file = project_file
	project_to_create.atlas.size = atlas_size

	project_to_create.config.embed_files = embed_files
	project_to_create.config.auto_centre = auto_centre

	WriteProject(&project_to_create)

	return project_to_create, .None
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
	atlas := root["atlas"].(json.Object)

	atlas_size := i32(atlas["size"].(json.Float))

	new_project.version = int(root["version"].(json.Float))
	new_project.name, _ = json.clone_string(root["name"].(json.String), context.allocator)
	new_project.atlas.size = int(atlas_size)

	background_image := rl.GenImageChecked(
		i32(atlas_size),
		i32(atlas_size),
		i32(atlas_size) / 32,
		i32(atlas_size) / 32,
		rl.LIGHTGRAY,
		rl.GRAY,
	)
	defer rl.UnloadImage(background_image)

	new_project.atlas.foreground_image = rl.GenImageColor(atlas_size, atlas_size, rl.BLANK)

	new_project.atlas.background_texture = rl.LoadTextureFromImage(background_image)
	new_project.atlas.foreground_texture = rl.LoadTextureFromImage(new_project.atlas.foreground_image)

	return new_project, .None
}

UnloadProject :: proc(project: ^Project) {
	delete(project.name)
	delete(project.file)

	for sprite, index in project.sprites {
		rl.TraceLog(.DEBUG, "DELETE: Deleting sprite[%d] %s", index, sprite.name)

		delete(sprite.name)
		delete(sprite.file)

		rl.UnloadImage(sprite.texture)
	}

	rl.UnloadImage(project.atlas.foreground_image)

	rl.UnloadTexture(project.atlas.background_texture)
	rl.UnloadTexture(project.atlas.foreground_texture)

	delete(project.sprites)
}

WriteProject :: proc(project: ^Project) {
	if os.is_file(project.file) do os.rename(project.file, strings.concatenate({project.file, ".bkp"}, context.temp_allocator))

	project_to_write := WriteableProject {
		version = project.version,
		name = project.name,
		atlas = {size = project.atlas.size},
		config = {embed_files = project.config.embed_files, auto_centre = project.config.auto_centre},
	}
	defer delete(project_to_write.sprites)

	for sprite in project.sprites {
		sprite_to_write := WriteableSprite {
			name = sprite.name,
			file = sprite.file,
			source = sprite.source,
			origin = sprite.origin,
			animation = {frames = sprite.animation.frames, speed = sprite.animation.speed},
		}

		append(&project_to_write.sprites, sprite_to_write)
	}

	options: json.Marshal_Options
	options.pretty = true
	options.use_spaces = true
	options.spaces = 4

	if project_data, error := json.marshal(project_to_write, options, context.temp_allocator); error == nil {
		os.write_entire_file(project.file, project_data)
	}
}
