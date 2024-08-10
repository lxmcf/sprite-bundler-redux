package core

import "core:encoding/json"
import "core:os"
import "core:strings"

import rl "vendor:raylib"

import "bundler:util"

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
    version:    int,
    name:       string,
    file:       string,
    directory:  string,
    background: rl.Texture2D,
    atlas:      [dynamic]Atlas,
    config:     struct {
        assets_dir:  string,
        copy_files:  bool,
        auto_center: bool,
        atlas_size:  int,
    },
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
    dir, file, _ := GetProjectFilenames(project.name, allocator = context.temp_allocator)


    readable: Project = {
        version = project.version,
        name = strings.clone(project.name),
        file = strings.clone(file),
        directory = strings.clone(dir),
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
    project_directory, project_file, project_assets := GetProjectFilenames(name, context.temp_allocator)

    os.make_directory(project_directory)
    os.make_directory(project_assets)
    if os.is_file(project_file) do return .Project_Exists

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

        for &atlas in new_project.atlas {
            atlas.image = rl.GenImageColor(
                i32(new_project.config.atlas_size),
                i32(new_project.config.atlas_size),
                rl.BLANK,
            )

            GenerateAtlas(&atlas)
        }
    } else {
        return new_project, .Invalid_Data
    }

    rl.SetWindowTitle(strings.unsafe_string_to_cstring(loaded_project.name))

    return new_project, .None
}

UnloadProject :: proc(project: ^Project) {
    util.DeleteStrings(project.name, project.file, project.directory, project.config.assets_dir)

    for atlas, atlas_index in project.atlas {
        rl.TraceLog(.DEBUG, "DELETE: Deleting atlas[%d] %s", atlas_index, atlas.name)
        rl.UnloadImage(atlas.image)
        rl.UnloadTexture(atlas.texture)

        for sprite, sprite_index in atlas.sprites {
            rl.TraceLog(.DEBUG, "DELETE: Deleting sprite[%d] %s", sprite_index, sprite.name)
            util.DeleteStrings(sprite.name, sprite.file, sprite.atlas)

            rl.UnloadImage(sprite.image)
        }

        delete(atlas.name)
        delete(atlas.sprites)
    }

    delete(project.atlas)

    rl.UnloadTexture(project.background)
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
        return .Failed_Serialisation
    }

    return .None
}
