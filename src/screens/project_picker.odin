package screens

import "core:encoding/json"
import "core:fmt"
import "core:os"
import "core:path/filepath"
import "core:strings"

import "bundler:core"

import mu "vendor:microui"
import rl "vendor:raylib"

WINDOW_WIDTH :: 640
WINDOW_HEIGHT :: 332

@(private = "file")
ProjectPickerState :: struct {
    projects: [dynamic]ProjectListItem,
}

@(private = "file")
state: ProjectPickerState

ProjectListItem :: struct {
    name:      string,
    directory: string,
    file:      string,
}

InitProjectPicker :: proc() {
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

        item: ProjectListItem = {
            file = strings.clone(match),
            name = strings.clone(root["name"].(json.String)),
        }

        append(&state.projects, item)
    }
}

UnloadProjectPicker :: proc() {
    for project in state.projects {
        delete(project.name)
        delete(project.file)
    }

    delete(state.projects)
}

UpdateProjectPicker :: proc(project: ^core.Project) {
    ctx := core.Begin()
    defer core.End()

    rect: mu.Rect = {(rl.GetScreenWidth() / 2) - (WINDOW_WIDTH / 2), (rl.GetScreenHeight() / 2) - (WINDOW_HEIGHT / 2), WINDOW_WIDTH, WINDOW_HEIGHT}

    // NOTE: This is awful, maybe I should just remake raygui?
    if mu.window(ctx, "Projects", rect, {.NO_RESIZE, .NO_CLOSE}) {
        mu.layout_row(ctx, {-1}, 192)
        mu.begin_panel(ctx, "load_project_panel", {.NO_SCROLL})

        container := mu.get_current_container(ctx)
        label_width := container.rect.w - (mu.default_style.padding * 4) - 144

        if len(state.projects) > 0 {
            for project_item, index in state.projects {
                mu.layout_row(ctx, {label_width, 72, 72})
                mu.label(ctx, project_item.name)

                mu.push_id(ctx, uintptr(index))
                if .SUBMIT in mu.button(ctx, "Load") {
                    err: core.ProjectError
                    project^, err = core.LoadProject(project_item.file)
                }

                if .SUBMIT in mu.button(ctx, "Delete") {
                    rl.TraceLog(.WARNING, "[PROJECT] Deletion not yet added!")
                }

                mu.pop_id(ctx)
            }
        } else {
            mu.layout_row(ctx, {-1})
            mu.label(ctx, "No projects found!")
        }

        mu.end_panel(ctx)

        mu.layout_row(ctx, {-1}, -1)
        mu.begin_panel(ctx, "new_project_panel", {.NO_SCROLL})

        mu.layout_row(ctx, {-1, -1}, -1)

        @(static)
        copy_files, auto_center: bool

        mu.layout_row(ctx, {128, 128})
        mu.checkbox(ctx, "Copy Sprite Files", &copy_files)
        mu.checkbox(ctx, "Auto Center Origin", &auto_center)

        @(static)
        atlas_size: mu.Real

        @(static)
        project_name_buffer: [mu.MAX_TEXT_STORE]byte

        @(static)
        project_name_length: int
        mu.label(ctx, "Atlas Size")
        mu.slider(ctx, &atlas_size, 512, 8192, 512)

        mu.label(ctx, "Project Name")
        mu.textbox(ctx, project_name_buffer[:], &project_name_length)

        mu.layout_row(ctx, {-1})
        if .SUBMIT in mu.button(ctx, "Create Project") {
            project_name := string(project_name_buffer[:project_name_length])

            err := core.CreateNewProject(project_name, int(atlas_size), copy_files, auto_center)

            if err == .None {
                project_file_path := fmt.tprint("projects", project_name, "project.lspp", sep = filepath.SEPARATOR_STRING)

                if os.is_file(project_file_path) {
                    project^, err = core.LoadProject(project_file_path)
                }
            }
        }
        mu.end_panel(ctx)
    }
}

DrawProjectPicker :: proc() {}
