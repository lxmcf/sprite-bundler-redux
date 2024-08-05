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
	name:        string,
	file:        string,
	atlas_index: int,
	image:       rl.Image,
	source:      rl.Rectangle,
	origin:      rl.Vector2,
	animation:   struct {
		frames: [dynamic]rl.Rectangle,
		speed:  f32,
	},
}

@(private)
WriteableSprite :: struct {
	name:        string,
	file:        string,
	atlas_index: int,
	source:      rl.Rectangle,
	origin:      rl.Vector2,
	animation:   struct {
		frames: [dynamic]rl.Rectangle,
		speed:  f32,
	},
}

Atlas :: struct {
	name:    string,
	image:   rl.Image,
	texture: rl.Texture2D,
}

Project :: struct {
	version:    int,
	name:       string,
	file:       string,
	background: rl.Texture2D,
	atlas:      [dynamic]Atlas,
	config:     struct {
		assets_dir:  string,
		copy_files:  bool,
		auto_center: bool,
		atlas_size:  int,
	},
	sprites:    [dynamic]Sprite,
}

@(private)
WriteableProject :: struct {
	version: int,
	name:    string,
	atlas:   [dynamic]string,
	config:  struct {
		assets_dir:  string,
		copy_files:  bool,
		auto_center: bool,
		atlas_size:  int,
	},
	sprites: [dynamic]WriteableSprite,
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

GenerateAtlas :: proc(project: ^Project, index: int) {
	rl.ImageClearBackground(&project.atlas[index].image, rl.BLANK)

	for sprite in project.sprites {
		if sprite.atlas_index != index do continue

		rl.ImageDraw(
			&project.atlas[index].image,
			sprite.image,
			{0, 0, sprite.source.width, sprite.source.height},
			sprite.source,
			rl.WHITE,
		)
	}

	rl.UnloadTexture(project.atlas[index].texture)
	project.atlas[index].texture = rl.LoadTextureFromImage(project.atlas[index].image)
}

CreateNewAtlas :: proc(project: ^Project, name: string) {
	new_atlas: Atlas
	new_atlas.name = strings.clone(name)
	new_atlas.image = rl.GenImageColor(i32(project.config.atlas_size), i32(project.config.atlas_size), rl.BLANK)
	new_atlas.texture = rl.LoadTextureFromImage(new_atlas.image)

	append(&project.atlas, new_atlas)
}

CreateNewProject :: proc(name: string, atlas_size: int, copy_files, auto_center: bool) -> Error {
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
		config = {
			assets_dir = project_assets,
			copy_files = copy_files,
			auto_center = auto_center,
			atlas_size = atlas_size,
		},
	}

	empty_atlas: Atlas
	empty_atlas.name = "atlas"

	append(&project_to_create.atlas, empty_atlas)
	defer delete(project_to_create.atlas)

	_ = WriteProject(&project_to_create)

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
	new_project.name, _ = json.clone_string(root["name"].(json.String), context.allocator)
	new_project.file, _ = strings.clone(filename)

	config := root["config"].(json.Object)
	new_project.config.assets_dir, _ = json.clone_string(config["assets_dir"].(json.String), context.allocator)
	new_project.config.auto_center = config["auto_center"].(json.Boolean)
	new_project.config.copy_files = config["copy_files"].(json.Boolean)
	new_project.config.atlas_size = int(config["atlas_size"].(json.Float))

	background_image := rl.GenImageChecked(
		i32(new_project.config.atlas_size),
		i32(new_project.config.atlas_size),
		i32(new_project.config.atlas_size) / 32,
		i32(new_project.config.atlas_size) / 32,
		rl.LIGHTGRAY,
		rl.GRAY,
	)
	defer rl.UnloadImage(background_image)

	for name in root["atlas"].(json.Array) {
		atlas: Atlas
		atlas.name, _ = json.clone_string(name.(json.String), context.allocator)
		atlas.image = rl.GenImageColor(
			i32(new_project.config.atlas_size),
			i32(new_project.config.atlas_size),
			rl.BLANK,
		)
		atlas.texture = rl.LoadTextureFromImage(atlas.image)
		append(&new_project.atlas, atlas)
	}

	new_project.background = rl.LoadTextureFromImage(background_image)

	for element, index in root["sprites"].(json.Array) {
		element := element.(json.Object)
		element_source := element["source"].(json.Object)

		sprite: Sprite
		sprite.name, _ = json.clone_string(element["name"].(json.String), context.allocator)
		sprite.file, _ = json.clone_string(element["file"].(json.String), context.allocator)
		sprite.atlas_index = int(element["atlas_index"].(json.Float))

		sprite.source = {
			x      = f32(element_source["x"].(json.Float)),
			y      = f32(element_source["y"].(json.Float)),
			width  = f32(element_source["width"].(json.Float)),
			height = f32(element_source["height"].(json.Float)),
		}

		if os.is_file(sprite.file) {
			sprite.image = rl.LoadImage(strings.unsafe_string_to_cstring(sprite.file))
		} else {
			rl.TraceLog(.ERROR, "Failed to load file [%s] for sprite [%s, %d]", sprite.file, sprite.name, index)
			sprite.image = rl.GenImageColor(i32(sprite.source.width), i32(sprite.source.height), rl.MAGENTA)
		}

		array := element["origin"].(json.Array)
		sprite.origin = {f32(array[0].(json.Float)), f32(array[1].(json.Float))}

		append(&new_project.sprites, sprite)
	}

	for _, index in new_project.atlas do GenerateAtlas(&new_project, index)

	rl.SetWindowTitle(strings.unsafe_string_to_cstring(new_project.name))

	return new_project, .None
}

UnloadProject :: proc(project: ^Project) {
	delete(project.name)
	delete(project.file)

	delete(project.config.assets_dir)

	for sprite, index in project.sprites {
		rl.TraceLog(.DEBUG, "DELETE: Deleting sprite[%d] %s", index, sprite.name)

		delete(sprite.name)
		delete(sprite.file)

		rl.UnloadImage(sprite.image)
	}
	delete(project.sprites)

	for atlas, index in project.atlas {
		rl.TraceLog(.DEBUG, "DELETE: Deleting atlas[%d] %s", index, atlas.name)
		rl.UnloadImage(atlas.image)
		rl.UnloadTexture(atlas.texture)

		delete(atlas.name)
	}
	delete(project.atlas)

	rl.UnloadTexture(project.background)
}

WriteProject :: proc(project: ^Project) -> Error {
	if os.is_file(project.file) do os.rename(project.file, strings.concatenate({project.file, ".bkp"}, context.temp_allocator))

	project_to_write := WriteableProject {
		version = project.version,
		name = project.name,
		config = {
			assets_dir = project.config.assets_dir,
			copy_files = project.config.copy_files,
			auto_center = project.config.auto_center,
			atlas_size = project.config.atlas_size,
		},
	}

	for sprite in project.sprites {
		sprite_to_write := WriteableSprite {
			name = sprite.name,
			file = sprite.file,
			atlas_index = sprite.atlas_index,
			source = sprite.source,
			origin = sprite.origin,
			animation = {frames = sprite.animation.frames, speed = sprite.animation.speed},
		}

		append(&project_to_write.sprites, sprite_to_write)
	}
	defer delete(project_to_write.sprites)

	for atlas in project.atlas {
		append(&project_to_write.atlas, atlas.name)
	}
	defer delete(project_to_write.atlas)

	options: json.Marshal_Options = {
		use_spaces = true,
		pretty     = true,
		spaces     = 4,
	}

	if project_data, error := json.marshal(project_to_write, options, context.temp_allocator); error == nil {
		os.write_entire_file(project.file, project_data)
	} else {
		return .Failed_Serialisation
	}

	return .None
}
