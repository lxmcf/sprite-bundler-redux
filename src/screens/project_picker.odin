package screens

import rl "vendor:raylib"

WINDOW_SIZE :: rl.Vector2{640, 360}

@(private = "file")
ProjectPickerState :: struct {
    files:           rl.FilePathList,

    // File List
    scroll_index:    i32,
    active_index:    i32,

    // Dropdowns
    dropdown_active: bool,
    dropdown_index:  i32,

    // Textbox
    name_text:       cstring,
    name_edit:       bool,

    // Toggles
    copy_files:      bool,
    auto_center:     bool,
}

@(private = "file")
state: ProjectPickerState

ProjectListItem :: struct {
    name: string,
    file: string,
}

// TODO: Make something nicer, ported over from original

InitProjectPicker :: proc() {
    rl.SetWindowTitle("Projects")

    state.files = rl.LoadDirectoryFilesEx("projects", ".lspp", true)
    // state.name_text = strings.clone_to_cstring("Hello World")
}

UnloadProjectPicker :: proc() {
    rl.UnloadDirectoryFiles(state.files)
}

UpdateProjectPicker :: proc() {}

DrawProjectPicker :: proc() {
    rl.GuiSetStyle(.LISTVIEW, .TEXT_ALIGNMENT, i32(rl.GuiTextAlignment.TEXT_ALIGN_LEFT))

    anchor: rl.Vector2 = ({f32(rl.GetScreenWidth()), f32(rl.GetScreenHeight())} / 2) - (WINDOW_SIZE / 2)
    rl.GuiWindowBox({anchor.x, anchor.y, WINDOW_SIZE.x, WINDOW_SIZE.y}, "#207#LSPP Projects")

    anchor += {8, 32}
    rl.GuiListViewEx(
        {anchor.x, anchor.y, 624, 128},
        state.files.paths,
        i32(state.files.count),
        &state.scroll_index,
        &state.active_index,
        nil,
    )

    rl.GuiButton({anchor.x, anchor.y + 134, 308, 24}, "#005#Load Selected Project")
    rl.GuiButton({anchor.x + 316, anchor.y + 134, 308, 24}, "#143#Delete Selected Project")

    rl.GuiGroupBox({anchor.x, anchor.y + 176, 624, 144}, "#185#New Project")

    anchor += {8, 184}

    if rl.GuiTextBox({anchor.x, anchor.y, 128, 24}, state.name_text, 128, state.name_edit) {
        state.name_edit = !state.name_edit
    }

    if rl.IsKeyPressed(.BACKSPACE) {
        rl.TraceLog(.INFO, "You entered: %s", state.name_text)
    }

    // if rl.GuiDropdownBox(
    //     {anchor.x, anchor.y, 128, 24},
    //     "512;1024;2048;4096;8192",
    //     &state.dropdown_index,
    //     state.dropdown_active,
    // ) {
    //     state.dropdown_active = !state.dropdown_active
    // }

    active: bool
    rl.GuiToggle({anchor.x, anchor.y + 32, 24, 24}, nil, &active)
}
