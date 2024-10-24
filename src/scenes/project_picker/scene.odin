package project_picker

import "core:encoding/json"
import "core:fmt"
import "core:os"
import "core:path/filepath"
import "core:strings"

import "../../common"

import rl "vendor:raylib"

ctx: Project_Picker_Context

init_scene :: proc() {
    rl.SetWindowSize(WINDOW_WIDTH, WINDOW_HEIGHT)

    rl.GuiSetStyle(.LISTVIEW, i32(rl.GuiControlProperty.TEXT_ALIGNMENT), i32(rl.GuiTextAlignment.TEXT_ALIGN_LEFT))

    ctx.background_colour = rl.GetColor(u32(rl.GuiGetStyle(.DEFAULT, i32(rl.GuiDefaultProperty.BACKGROUND_COLOR))))

    matches, err := filepath.glob("projects/*/*.lspp", context.temp_allocator)
    if err == .Syntax_Error {
        rl.TraceLog(.ERROR, "JSON: Invalid JSON syntax")
        return
    }

    // TODO: Add some form of 'meta' file to avoid loading the full project file
    for match in matches {
        data, ok := os.read_entire_file(match)
        defer delete(data)

        if !ok {
            rl.TraceLog(.ERROR, "FILE: Failed to load file: %s", match)
            continue
        }

        json_data, err := json.parse(data, allocator = context.temp_allocator)
        if err != .None {
            rl.TraceLog(.ERROR, "JSON: Failed to parse JSON data: %s", fmt.tprint(err))
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

unload_scene :: proc() {
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

update_scene :: proc(project: ^common.Project) -> common.Application_Scene {
    next_scene: common.Application_Scene = .Project_Picker

    if rl.IsFileDropped() {
        files := rl.LoadDroppedFiles()
        defer rl.UnloadDroppedFiles(files)

        if files.count == 1 {
            project^, _ = common.load_project(string(files.paths[0]))
        }
    }

    if ctx.load_project {
        project^, _ = common.load_project(ctx.projects[ctx.list_active].file)
    }

    if ctx.delete_project {
        // TODO: Add
    }

    if ctx.create_project {
        atlas_lookup := [?]int{512, 1024, 2048, 4096, 8192, 16384}
        temp_cstring := cstring(raw_data(ctx.project_name_buffer[:]))

        err := common.create_new_project(string(temp_cstring), atlas_lookup[ctx.atlas_index], ctx.config_copy_sprites, ctx.config_auto_centre)

        #partial switch err {
        case .None:
            project_file_path := fmt.tprint("projects", string(temp_cstring), "project.lspp", sep = filepath.SEPARATOR_STRING)

            if os.is_file(project_file_path) {
                project^, _ = common.load_project(project_file_path)
            }
            break

        case:
            fmt.println("ERROR: PROJECT:", err)
        }
    }

    return next_scene
}

draw_scene :: proc() {
    rl.ClearBackground(ctx.background_colour)

    rl.GuiListViewEx({8, 8, WINDOW_WIDTH - 16, 144}, raw_data(ctx.project_cstrings), i32(len(ctx.project_cstrings)), &ctx.list_scroll, &ctx.list_active, &ctx.list_focus)

    ctx.load_project = rl.GuiButton({8, 160, 308, 24}, "#005# Load Selected Project")
    ctx.delete_project = rl.GuiButton({324, 160, 308, 24}, "#143# Delete Selected Project")

    rl.GuiGroupBox({8, 200, WINDOW_WIDTH - 16, 152}, "New Project")

    rl.GuiLabel({184, 216, 128, 24}, "Project Name")

    if rl.GuiTextBox({16, 216, 160, 24}, cstring(rawptr(&ctx.project_name_buffer)), i32(len(ctx.project_name_buffer)), ctx.project_name_edit) {
        ctx.project_name_edit = !ctx.project_name_edit
    }

    rl.GuiLabel({184, 248, 128, 24}, "Atlas Size")
    rl.GuiComboBox({16, 248, 160, 24}, "512;1024;2048;4096;8192;16384", &ctx.atlas_index)

    rl.GuiCheckBox({16, 280, 24, 24}, "Copy Sprite Files", &ctx.config_copy_sprites)
    rl.GuiCheckBox({16, 312, 24, 24}, "Auto Centre Origin", &ctx.config_auto_centre)

    ctx.create_project = rl.GuiButton({472, 320, 152, 24}, "#008# Create & Load Project")
}
