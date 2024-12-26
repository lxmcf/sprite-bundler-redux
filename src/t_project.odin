package main

import "core:encoding/json"
import "core:fmt"
import "core:os"
import str "core:strings"

Project :: struct {
    name:    string,
    file:    string,
    version: int,
    config:  struct {
        strip_whitespace: bool,
        auto_centre:      bool,
    },
    atlas:   [dynamic]Atlas,
}

Project_Error :: enum u8 {
    None,
    Invalid_File,
    Failed_Serialisation,
    Failed_Deserialisation,
}

unload_project :: proc(project: Project) {
    delete(project.file)
    delete(project.name)

    for _ in project.atlas {}
}

save_project :: proc(project: Project) -> Project_Error {
    if os.is_file(project.file) {
        os.rename(project.file, str.concatenate({project.file, ".bkp"}, context.temp_allocator))
    }

    options: json.Marshal_Options = {
        use_enum_names = true,
        use_spaces     = true,
        pretty         = true,
        spaces         = 4,
    }

    if project_data, error := json.marshal(project, options, context.temp_allocator); error == nil {
        os.write_entire_file(project.file, project_data)
    } else {
        fmt.println("[Error] JSON: Failed to serialise:", error)
        return .Failed_Serialisation
    }

    return .None
}

load_project :: proc(filename: string) -> (project: Project, err: Project_Error) {
    if project_data, ok := os.read_entire_file(filename, context.temp_allocator); ok {
        json.unmarshal(project_data, &project)
    } else {
        err = .Failed_Deserialisation
    }

    return
}
