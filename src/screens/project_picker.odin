package screens

import "core:path/filepath"
import "core:strings"

import "bundler:myui"
import "bundler:util"

import mu "vendor:microui"
import rl "vendor:raylib"

WINDOW_WIDTH :: 640
WINDOW_HEIGHT :: 360

@(private = "file")
ProjectPickerState :: struct {
    projects: [dynamic]ProjectListItem,
}

@(private = "file")
state: ProjectPickerState

ProjectListItem :: struct {
    name: string,
    file: string,
}

InitProjectPicker :: proc() {
    matches, err := filepath.glob("projects/*", context.temp_allocator)
    if err == .Syntax_Error {
        rl.TraceLog(.ERROR, "INVALID SYNTAX")
        return
    }

    for match in matches {
        index := strings.last_index_any(match, filepath.SEPARATOR_STRING)

        item: ProjectListItem = {
            file = strings.clone(match),
            name = strings.clone(filepath.stem(match[index + 1:])),
        }

        append(&state.projects, item)
    }
}

UnloadProjectPicker :: proc() {
    for project in state.projects {
        util.DeleteStrings(project.name, project.file)
    }

    delete(state.projects)
}

UpdateProjectPicker :: proc() {}

DrawProjectPicker :: proc() {
    ctx := myui.Begin()
    defer myui.End()

    rect: mu.Rect = {
        (rl.GetScreenWidth() / 2) - (WINDOW_WIDTH / 2),
        (rl.GetScreenHeight() / 2) - (WINDOW_HEIGHT / 2),
        WINDOW_WIDTH,
        WINDOW_HEIGHT,
    }

    if mu.window(ctx, "Projects", rect, {.NO_RESIZE, .NO_CLOSE}) {
        mu.layout_row(ctx, {-1}, 192)
        mu.begin_panel(ctx, "Project Panel", {.NO_SCROLL})

        container := mu.get_current_container(ctx)
        label_width := container.rect.w - (mu.default_style.padding * 4) - 144

        for project, index in state.projects {
            mu.layout_row(ctx, {label_width, 72, 72})
            mu.label(ctx, project.name)

            mu.push_id(ctx, uintptr(index))
            if .SUBMIT in mu.button(ctx, "Load") {
                rl.TraceLog(.INFO, "You loaded on %s", project.name)
            }
            if .SUBMIT in mu.button(ctx, "Delete") {
                rl.TraceLog(.INFO, "You deleted on %s", project.name)
            }
            mu.pop_id(ctx)

        }

        mu.end_panel(ctx)

        mu.layout_row(ctx, {-1}, -1)
        mu.begin_panel(ctx, "New Project")

        mu.end_panel(ctx)
    }
}
