package core

import "core:encoding/json"
import "core:fmt"
import "core:os"
import "core:path/filepath"
import "core:strings"

import rl "vendor:raylib"

DEFAULT_PROJECT_DIRECTORY :: #config(CUSTOM_PROJECT_DIRECTORY, "projects")
DEFAULT_PROJECT_FILENAME :: #config(CUSTOM_PROJECT_FILENAME, "project.lspp")
DEFAULT_PROJECT_ASSETS :: #config(CUSTOM_ASSET_DIRECTORY, "assets")
DEFAULT_PROJECT_SCHEMA :: #config(
    CUSTOM_PROJECT_SCHEMA,
    "https://raw.githubusercontent.com/lxmcf/sprite-bundler-redux/main/data/lspp.scheme.json",
)

DEFAULT_ATLAS_NAME :: "atlas"
CURRENT_PROJECT_VERSION :: 100

Project :: struct {
    version:           int,
    name:              string,
    file:              string,
    background:        rl.Texture2D,
    atlas:             [dynamic]Atlas,
    config:            struct {
        assets_dir:  string,
        copy_files:  bool,
        auto_center: bool,
        atlas_size:  int,
    },

    // INTERNAL
    is_loaded:         bool,
    working_directory: string,
}

@(private)
WriteableProject :: struct {
    version: int,
    name:    string,
    atlas:   [dynamic]WriteableAtlas,
    config:  struct {
        assets_dir:  string,
        copy_files:  bool,
        auto_center: bool,
        atlas_size:  int,
    },
}

ProjectError :: enum {
    None,
    Invalid_File,
    Invalid_Data,
    Project_Exists,
    Project_Newer,
    Project_Older,
    Failed_Serialisation,
}

@(private)
ProjectToWriteable :: proc(project: Project) -> WriteableProject {
    writable: WriteableProject = {
        version = project.version,
        name = project.name,
        config = {
            assets_dir = project.config.assets_dir,
            copy_files = project.config.copy_files,
            auto_center = project.config.auto_center,
            atlas_size = project.config.atlas_size,
        },
    }

    for atlas in project.atlas {
        append(&writable.atlas, ToWriteable(atlas))
    }

    return writable
}

@(private)
ProjectToReadable :: proc(project: WriteableProject) -> Project {
    readable: Project = {
        version = project.version,
        config = {
            assets_dir = strings.clone(project.config.assets_dir),
            copy_files = project.config.copy_files,
            auto_center = project.config.auto_center,
            atlas_size = project.config.atlas_size,
        },
    }

    background_image := rl.GenImageChecked(
        i32(readable.config.atlas_size),
        i32(readable.config.atlas_size),
        i32(readable.config.atlas_size) / 32,
        i32(readable.config.atlas_size) / 32,
        rl.LIGHTGRAY,
        rl.GRAY,
    )
    defer rl.UnloadImage(background_image)

    readable.background = rl.LoadTextureFromImage(background_image)

    for atlas in project.atlas {
        append(&readable.atlas, ToReadable(atlas))
    }

    return readable
}

@(private)
UnloadWriteableProject :: proc(project: ^WriteableProject) {
    for &atlas in project.atlas do UnloadWriteable(&atlas)

    delete(project.atlas)
}

CreateNewProject :: proc(name: string, atlas_size: int, copy_files, auto_center: bool) -> ProjectError {
    project_directory := fmt.tprint(DEFAULT_PROJECT_DIRECTORY, name, sep = filepath.SEPARATOR_STRING)
    project_file := fmt.tprint(project_directory, DEFAULT_PROJECT_FILENAME, sep = filepath.SEPARATOR_STRING)
    project_assets := fmt.tprint(project_directory, DEFAULT_PROJECT_ASSETS, sep = filepath.SEPARATOR_STRING)

    os.make_directory(project_directory)
    os.make_directory(project_assets)
    if os.is_file(project_file) do return .Project_Exists

    project_to_create: Project = {
        version = CURRENT_PROJECT_VERSION,
        name = name,
        file = project_file,
        config = {
            assets_dir = DEFAULT_PROJECT_ASSETS,
            copy_files = copy_files,
            auto_center = auto_center,
            atlas_size = atlas_size,
        },
    }

    atlas_to_create: Atlas = {
        name = DEFAULT_ATLAS_NAME,
    }

    append(&project_to_create.atlas, atlas_to_create)
    defer delete(project_to_create.atlas)

    return WriteProject(&project_to_create)
}

LoadProject :: proc(filename: string) -> (Project, ProjectError) {
    loaded_project: WriteableProject
    new_project: Project

    if file_data, ok := os.read_entire_file(filename, context.temp_allocator); ok {
        json.unmarshal(file_data, &loaded_project, allocator = context.temp_allocator)

        new_project = ToReadable(loaded_project)

        new_project.working_directory = strings.concatenate(
            {filepath.dir(filename, context.temp_allocator), filepath.SEPARATOR_STRING},
        )

        new_project.file = strings.concatenate({new_project.working_directory, DEFAULT_PROJECT_FILENAME})

        for &atlas in new_project.atlas {
            atlas.image = rl.GenImageColor(i32(new_project.config.atlas_size), i32(new_project.config.atlas_size), rl.BLANK)

            for &sprite in atlas.sprites {
                sprite_file: string

                if new_project.config.copy_files {
                    sprite_file = strings.concatenate(
                        {new_project.working_directory, new_project.config.assets_dir, filepath.SEPARATOR_STRING, sprite.file},
                        context.temp_allocator,
                    )
                } else {
                    sprite_file = sprite.file
                }

                if os.is_file(sprite_file) {
                    sprite.image = rl.LoadImage(strings.clone_to_cstring(sprite_file, context.temp_allocator))
                } else {
                    rl.TraceLog(.ERROR, "[FILE] Failed to load file [%s]", sprite_file)

                    sprite.image = rl.GenImageColor(i32(sprite.source.width), i32(sprite.source.height), rl.MAGENTA)
                }
            }

            GenerateAtlas(&atlas)
        }
    } else {
        return new_project, .Invalid_Data
    }

    rl.SetWindowTitle(strings.clone_to_cstring(loaded_project.name, context.temp_allocator))

    new_project.is_loaded = true

    return new_project, .None
}

UnloadProject :: proc(project: ^Project) {
    delete(project.name)
    delete(project.file)
    delete(project.config.assets_dir)

    for atlas, atlas_index in project.atlas {
        rl.TraceLog(.DEBUG, "[DELETE] Deleting atlas[%d] %s", atlas_index, atlas.name)
        rl.UnloadImage(atlas.image)
        rl.UnloadTexture(atlas.texture)

        for sprite, sprite_index in atlas.sprites {
            rl.TraceLog(.DEBUG, "[DELETE] Deleting sprite[%d] %s", sprite_index, sprite.name)
            delete(sprite.name)
            delete(sprite.file)
            delete(sprite.atlas)

            rl.UnloadImage(sprite.image)
        }

        delete(atlas.name)
        delete(atlas.sprites)
    }

    delete(project.atlas)

    rl.UnloadTexture(project.background)

    delete(project.working_directory)

    project.is_loaded = false
}

WriteProject :: proc(project: ^Project) -> ProjectError {
    if os.is_file(project.file) do os.rename(project.file, strings.concatenate({project.file, ".bkp"}, context.temp_allocator))

    project_to_write := ToWriteable(project^)
    defer UnloadWriteable(&project_to_write)

    options: json.Marshal_Options = {
        use_spaces = true,
        pretty     = true,
        spaces     = 4,
    }

    if project_data, error := json.marshal(project_to_write, options, context.temp_allocator); error == nil {
        os.write_entire_file(project.file, project_data)
    } else {
        rl.TraceLog(.ERROR, "[JSON] Failed to serialise: %s", fmt.tprint(error))
        return .Failed_Serialisation
    }

    return .None
}
