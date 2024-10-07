package screens

import "core:encoding/json"
import "core:fmt"
import "core:os"
import "core:path/filepath"
import "core:strings"

import "../core"

import mu "vendor:microui"
import rl "vendor:raylib"

WINDOW_WIDTH :: 640
WINDOW_HEIGHT :: 332

@(private = "file")
Project_Picker_Context :: struct {
    projects: [dynamic]Project_List_Item,
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

        append(&ctx.projects, item)
    }
}

unload_project_picker :: proc() {
    for project in ctx.projects {
        delete(project.name)
        delete(project.file)
    }

    delete(ctx.projects)
}

update_project_picker :: proc(project: ^core.Project) {
    if rl.IsFileDropped() {
        files := rl.LoadDroppedFiles()
        defer rl.UnloadDroppedFiles(files)

        if files.count == 1 {
            project^, _ = core.load_project(string(files.paths[0]))
        }
    }

    mu_ctx := core.Begin()
    defer core.End()

    rect: mu.Rect = {0, 0, WINDOW_WIDTH, WINDOW_HEIGHT}

    // NOTE: This is awful, maybe I should just remake raygui?
    if mu.window(mu_ctx, "Projects", rect, {.NO_RESIZE, .NO_CLOSE}) {
        mu.layout_row(mu_ctx, {-1}, 192)
        mu.begin_panel(mu_ctx, "load_project_panel", {.NO_SCROLL})

        container := mu.get_current_container(mu_ctx)
        label_width := container.rect.w - (mu.default_style.padding * 4) - 144

        if len(ctx.projects) > 0 {
            for project_item, index in ctx.projects {
                mu.layout_row(mu_ctx, {label_width, 72, 72})
                mu.label(mu_ctx, project_item.name)

                mu.push_id(mu_ctx, uintptr(index))
                if .SUBMIT in mu.button(mu_ctx, "Load") {
                    err: core.Project_Error
                    project^, err = core.load_project(project_item.file)
                }

                if .SUBMIT in mu.button(mu_ctx, "Delete") {
                    rl.TraceLog(.WARNING, "[PROJECT] Deletion not yet added!")
                }

                mu.pop_id(mu_ctx)
            }
        } else {
            mu.layout_row(mu_ctx, {-1})
            mu.label(mu_ctx, "No projects found!")
        }

        mu.end_panel(mu_ctx)

        mu.layout_row(mu_ctx, {-1}, -1)
        mu.begin_panel(mu_ctx, "new_project_panel", {.NO_SCROLL})

        mu.layout_row(mu_ctx, {-1, -1}, -1)

        @(static)
        copy_files, auto_center: bool

        mu.layout_row(mu_ctx, {128, 128})
        mu.checkbox(mu_ctx, "Copy Sprite Files", &copy_files)
        mu.checkbox(mu_ctx, "Auto Center Origin", &auto_center)

        @(static)
        atlas_size: mu.Real

        @(static)
        project_name_buffer: [mu.MAX_TEXT_STORE]byte

        @(static)
        project_name_length: int
        mu.label(mu_ctx, "Atlas Size")
        mu.slider(mu_ctx, &atlas_size, 512, 8192, 512)

        mu.label(mu_ctx, "Project Name")
        mu.textbox(mu_ctx, project_name_buffer[:], &project_name_length)

        mu.layout_row(mu_ctx, {-1})
        if .SUBMIT in mu.button(mu_ctx, "Create Project") {
            project_name := string(project_name_buffer[:project_name_length])

            err := core.create_new_project(project_name, int(atlas_size), copy_files, auto_center)

            if err == .None {
                project_file_path := fmt.tprint("projects", project_name, "project.lspp", sep = filepath.SEPARATOR_STRING)

                if os.is_file(project_file_path) {
                    project^, err = core.load_project(project_file_path)
                }
            }
        }
        mu.end_panel(mu_ctx)
    }
}

draw_project_picker :: proc() {}
