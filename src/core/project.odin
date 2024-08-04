package core

import "core:encoding/json"
import "core:fmt"
import "core:os"
import "core:path/filepath"
import "core:strings"

import rl "vendor:raylib"

DEFAULT_PROJECT_DIRECTORY :: "projects"
DEFAULT_PROJECT_FILENAME :: "project.lspp"
DEFAULT_PROJECT_ASSETS :: "assets"

CURRENT_PROJECT_VERSION :: 100

Sprite :: struct {
	name:      string,
	file:      string,
	image:     rl.Image,
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
	asssets: string,
	sprites: [dynamic]Sprite,
	atlas:   struct {
		size:               int,
		background_texture: rl.Texture2D,
		foreground_texture: rl.Texture2D,
		foreground_image:   rl.Image,
	},
	config:  struct {
		copy_files:  bool,
		auto_centre: bool,
	},
}

@(private)
WriteableProject :: struct {
	version: int,
	name:    string,
	assets:  string,
	sprites: [dynamic]WriteableSprite,
	atlas:   struct {
		size: int,
	},
	config:  struct {
		copy_files:  bool,
		auto_centre: bool,
	},
}

Error :: enum {
	None,
	Invalid_File,
	Invalid_Data,
	Project_Exists,
	Project_Newer,
	Project_Older,
	Failed_Serialisation,
}

GetProjectFilenames :: proc(name: string, allocator := context.allocator) -> (string, string, string) {
	project_directory := strings.concatenate({DEFAULT_PROJECT_DIRECTORY, filepath.SEPARATOR_STRING, name})
	project_file := strings.concatenate({project_directory, filepath.SEPARATOR_STRING, DEFAULT_PROJECT_FILENAME})
	project_assets := strings.concatenate({project_directory, filepath.SEPARATOR_STRING, DEFAULT_PROJECT_ASSETS})

	return project_directory, project_file, project_assets
}

GenerateAtlas :: proc(project: ^Project) {
	rl.ImageClearBackground(&project.atlas.foreground_image, rl.BLANK)

	for sprite in project.sprites {
		rl.ImageDraw(
			&project.atlas.foreground_image,
			sprite.image,
			{0, 0, sprite.source.width, sprite.source.height},
			sprite.source,
			rl.WHITE,
		)
	}

	rl.UnloadTexture(project.atlas.foreground_texture)
	project.atlas.foreground_texture = rl.LoadTextureFromImage(project.atlas.foreground_image)
}

CreateNewProject :: proc(name: string, atlas_size: int, copy_files, auto_centre: bool) -> Error {
	project_directory, project_file, project_assets := GetProjectFilenames(name, context.temp_allocator)
	defer delete(project_directory)
	defer delete(project_file)
	defer delete(project_assets)

	os.make_directory(project_directory)
	if os.is_file(project_file) do return .Project_Exists
	if copy_files do os.make_directory(project_assets)

	project_to_create: Project = {
		version = CURRENT_PROJECT_VERSION,
		name = name,
		file = project_file,
		asssets = project_assets,
		atlas = {size = atlas_size},
		config = {copy_files = copy_files, auto_centre = auto_centre},
	}

	WriteProject(&project_to_create)

	return .None
}

// NOTE: Should probably just unmarshal this?
LoadProject :: proc(filename: string) -> (Project, Error) {
	new_project: Project

	data, ok := os.read_entire_file(filename)
	if !ok {
		rl.TraceLog(.ERROR, "FILE: Failed to load %s", filename)
		return new_project, .Invalid_File
	}
	defer delete(data)

	json_data, error := json.parse(data)
	if error != .None {
		error_name := fmt.tprint(error)
		rl.TraceLog(.ERROR, "FILE: Failed to parse json: %s", error_name)

		return new_project, .Invalid_Data
	}
	defer json.destroy_value(json_data)

	root := json_data.(json.Object)
	new_project.version = int(root["version"].(json.Float))

	if new_project.version > CURRENT_PROJECT_VERSION {
		return new_project, .Project_Newer
	}

	new_project.name, _ = json.clone_string(root["name"].(json.String), context.allocator)
	new_project.file, _ = strings.clone(filename)
	new_project.asssets, _ = json.clone_string(root["assets"].(json.String), context.allocator)

	atlas := root["atlas"].(json.Object)
	atlas_size := i32(atlas["size"].(json.Float))

	config := root["config"].(json.Object)
	new_project.config.auto_centre = config["auto_centre"].(json.Boolean)
	new_project.config.copy_files = config["copy_files"].(json.Boolean)

	new_project.atlas.size = int(atlas_size)

	background_image := rl.GenImageChecked(
		atlas_size,
		atlas_size,
		atlas_size / 32,
		atlas_size / 32,
		rl.LIGHTGRAY,
		rl.GRAY,
	)
	defer rl.UnloadImage(background_image)

	new_project.atlas.foreground_image = rl.GenImageColor(atlas_size, atlas_size, rl.BLANK)

	new_project.atlas.background_texture = rl.LoadTextureFromImage(background_image)
	new_project.atlas.foreground_texture = rl.LoadTextureFromImage(new_project.atlas.foreground_image)

	for index in root["sprites"].(json.Array) {
		element := index.(json.Object)
		element_source := element["source"].(json.Object)

		sprite: Sprite
		sprite.name, _ = json.clone_string(element["name"].(json.String), context.allocator)
		sprite.file, _ = json.clone_string(element["file"].(json.String), context.allocator)

		sprite.source = {
			x      = f32(element_source["x"].(json.Float)),
			y      = f32(element_source["y"].(json.Float)),
			width  = f32(element_source["width"].(json.Float)),
			height = f32(element_source["height"].(json.Float)),
		}

		if os.is_file(element["file"].(json.String)) {
			sprite.image = rl.LoadImage(strings.unsafe_string_to_cstring(element["file"].(json.String)))
		} else {
			sprite.image = rl.GenImageColor(i32(sprite.source.width), i32(sprite.source.height), rl.MAGENTA)
		}

		array := element["origin"].(json.Array)

		sprite.origin = {f32(array[0].(json.Float)), f32(array[1].(json.Float))}

		append(&new_project.sprites, sprite)
	}

	return new_project, .None
}

UnloadProject :: proc(project: ^Project) {
	delete(project.name)
	delete(project.file)
	delete(project.asssets)

	for sprite, index in project.sprites {
		rl.TraceLog(.DEBUG, "DELETE: Deleting sprite[%d] %s", index, sprite.name)

		delete(sprite.name)
		delete(sprite.file)

		rl.UnloadImage(sprite.image)
	}

	rl.UnloadImage(project.atlas.foreground_image)

	rl.UnloadTexture(project.atlas.background_texture)
	rl.UnloadTexture(project.atlas.foreground_texture)

	delete(project.sprites)
}

WriteProject :: proc(project: ^Project) -> Error {
	if os.is_file(project.file) do os.rename(project.file, strings.concatenate({project.file, ".bkp"}, context.temp_allocator))

	project_to_write := WriteableProject {
		version = project.version,
		name = project.name,
		assets = project.asssets,
		atlas = {size = project.atlas.size},
		config = {copy_files = project.config.copy_files, auto_centre = project.config.auto_centre},
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

	options: json.Marshal_Options = {
		pretty     = true,
		use_spaces = true,
		spaces     = 4,
	}

	if project_data, error := json.marshal(project_to_write, options, context.temp_allocator); error == nil {
		os.write_entire_file(project.file, project_data)
	} else {
		return .Failed_Serialisation
	}

	return .None
}
