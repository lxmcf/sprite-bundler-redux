package main

import "core:encoding/json"
import "core:fmt"
import "core:os"
import "core:strings"

Project :: struct {
    name:    string,
    file:    string,
    version: int,
    config:  struct {
        strip_whitespace: bool,
        auto_centre:      bool,
    },
}

Project_Error :: enum {
    None,
    Invalid_File,
    Failed_Serialisation,
}

unload_project :: proc(#by_ptr project: Project) {
    delete(project.file)
    delete(project.name)
}

save_project :: proc(#by_ptr project: Project) -> Project_Error {
    if os.is_file(project.file) {
        os.rename(project.file, strings.concatenate({project.file, ".bkp"}, context.temp_allocator))
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
