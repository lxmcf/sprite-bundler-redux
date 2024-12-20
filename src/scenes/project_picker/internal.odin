package project_picker

import "core:path/filepath"

import rl "vendor:raylib"

WINDOW_WIDTH :: 640
WINDOW_HEIGHT :: 360

Project_Picker_Context :: struct {
    projects:            [dynamic]Project_List_Item,
    project_cstrings:    [dynamic]cstring,
    background_colour:   rl.Color,
    load_project:        bool,
    delete_project:      bool,
    create_project:      bool,
    list_scroll:         i32,
    list_active:         i32,
    list_focus:          i32,
    project_name_buffer: [128]byte,
    project_name_edit:   bool,
    atlas_index:         i32,
    config_copy_sprites: bool,
    config_auto_centre:  bool,
}

Project_List_Item :: struct {
    name:      string,
    directory: string,
    file:      string,
}

load_directory_of_files :: proc(pattern: string) -> []string {
    matches, err := filepath.glob(pattern)
    if err == .Syntax_Error {
        rl.TraceLog(.ERROR, "FILE: Invalid syntax: %s", pattern)
    }

    return matches
}
