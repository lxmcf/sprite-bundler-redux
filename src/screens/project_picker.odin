package screens

import "core:encoding/json"
import "core:fmt"
import "core:os"
import "core:path/filepath"
import "core:strings"

import "../common"

import rl "vendor:raylib"

WINDOW_WIDTH :: 640
WINDOW_HEIGHT :: 360

@(private = "file")
Project_Picker_Context :: struct {
    projects:          [dynamic]Project_List_Item,
    project_cstrings:  [dynamic]cstring,
    background_colour: rl.Color,
}

@(private = "file")
ctx: Project_Picker_Context

Project_List_Item :: struct {
    name:      string,
    directory: string,
    file:      string,
}

init_project_picker :: proc() {
    rl.SetWindowSize(WINDOW_WIDTH, WINDOW_HEIGHT)

    rl.GuiSetStyle(.LISTVIEW, i32(rl.GuiControlProperty.TEXT_ALIGNMENT), i32(rl.GuiTextAlignment.TEXT_ALIGN_LEFT))

    ctx.background_colour = rl.GetColor(u32(rl.GuiGetStyle(.DEFAULT, i32(rl.GuiDefaultProperty.BACKGROUND_COLOR))))

    matches, err := filepath.glob("projects/*/*.lspp", context.temp_allocator)
    if err == .Syntax_Error {
        rl.TraceLog(.ERROR, "[JSON] Invalid JSON syntax")
        return
    }

    // TODO: Add some form of 'meta' file to avoid loading the full project file
    for match in matches {
        data, ok := os.read_entire_file(match)
        defer delete(data)

        if !ok {
            rl.TraceLog(.ERROR, "[FILE] Failed to load file: %s", match)
            continue
        }

        json_data, err := json.parse(data, allocator = context.temp_allocator)
        if err != .None {
            rl.TraceLog(.ERROR, "[JSON] Failed to parse JSON data: %s", fmt.tprint(err))
            continue
        }

        root := json_data.(json.Object)

        item: Project_List_Item = {
            file = strings.clone(match),
            name = strings.clone(root["name"].(json.String)),
        }

        append(&ctx.project_cstrings, strings.clone_to_cstring(item.name))
        append(&ctx.projects, item)
    }
}

unload_project_picker :: proc() {
    for project in ctx.projects {
        delete(project.name)
        delete(project.file)
    }

    delete(ctx.projects)

    for text in ctx.project_cstrings {
        delete(text)
    }

    delete(ctx.project_cstrings)
}

update_project_picker :: proc(project: ^common.Project) {
    if rl.IsFileDropped() {
        files := rl.LoadDroppedFiles()
        defer rl.UnloadDroppedFiles(files)

        if files.count == 1 {
            project^, _ = common.load_project(string(files.paths[0]))
        }
    }
}

draw_project_picker :: proc() {
    rl.ClearBackground(ctx.background_colour)

    @(static)
    scroll, active, focus: i32
    rl.GuiListViewEx({8, 8, WINDOW_WIDTH - 16, 144}, raw_data(ctx.project_cstrings), i32(len(ctx.project_cstrings)), &scroll, &active, &focus)

    if rl.GuiButton({8, 160, 308, 24}, "#005# Load Selected Project") {}
    if rl.GuiButton({324, 160, 308, 24}, "#143# Delete Selected Project") {}

    rl.GuiGroupBox({8, 200, WINDOW_WIDTH - 16, 152}, "New Project")

    rl.GuiLabel({152, 216, 128, 24}, "Project Name")
    rl.GuiDummyRec({16, 216, 128, 24}, "[PROJECT NAME]")

    @(static)
    value: i32

    rl.GuiLabel({152, 248, 128, 24}, "Atlas Size")
    rl.GuiComboBox({16, 248, 128, 24}, "512;1024;2048;4096;8192;16384", &value)

    temp_bool: bool
    rl.GuiCheckBox({16, 280, 24, 24}, "Copy Sprite Files", &temp_bool)
    rl.GuiCheckBox({16, 312, 24, 24}, "Auto Centre Origin", &temp_bool)

    rl.GuiButton({472, 320, 152, 24}, "#008# Create & Load Project")
}
