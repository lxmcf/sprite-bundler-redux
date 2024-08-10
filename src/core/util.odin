package core

import "core:path/filepath"
import "core:strings"

ToWriteable :: proc {
    ProjectToWriteable,
    AtlasToWriteable,
    SpriteToWritable,
}

ToReadable :: proc {
    ProjectToReadable,
    AtlasToReadable,
    SpriteToReadable,
}

UnloadWriteable :: proc {
    UnloadWriteableProject,
    UnloadWriteableAtlas,
    UnloadWriteableSprite,
}

GetProjectFilenames :: proc(name: string, allocator := context.allocator) -> (string, string, string) {
    project_directory := strings.concatenate(
        {DEFAULT_PROJECT_DIRECTORY, filepath.SEPARATOR_STRING, name},
        allocator = allocator,
    )
    project_file := strings.concatenate(
        {project_directory, filepath.SEPARATOR_STRING, DEFAULT_PROJECT_FILENAME},
        allocator = allocator,
    )
    project_assets := strings.concatenate(
        {project_directory, filepath.SEPARATOR_STRING, DEFAULT_PROJECT_ASSETS},
        allocator = allocator,
    )

    return project_directory, project_file, project_assets
}
