package main

import "core:os"
import rl "vendor:raylib"

import "core"
import db "debug"
import "screens"

_ :: db

FPS_MINIMUM :: 60
WINDOW_WIDTH :: 1280
WINDOW_HEIGHT :: 720
WINDOW_TITLE :: "Sprite Packer"

Application_Screen :: enum {
    Project_Picker,
    Editor,
}

main :: proc() {
    when ODIN_DEBUG {
        context.allocator = db.init_allocator()
        defer db.unload_allocator()
    }

    rl.SetTraceLogLevel(.DEBUG when ODIN_DEBUG else .NONE)
    rl.InitWindow(WINDOW_WIDTH, WINDOW_HEIGHT, WINDOW_TITLE)
    defer rl.CloseWindow()

    // rl.SetWindowMinSize(640, 360)
    rl.SetWindowState({.WINDOW_RESIZABLE})
    rl.SetExitKey(.KEY_NULL)

    // Set max framerate without vsync
    max_fps := rl.GetMonitorRefreshRate(rl.GetCurrentMonitor())
    rl.SetTargetFPS(max_fps <= 0 ? FPS_MINIMUM : max_fps)

    if !os.is_dir("projects") {
        os.make_directory("projects")
    }

    current_screen := Application_Screen.Project_Picker
    current_project: core.Project
    defer core.unload_project(&current_project)

    init_current_screen(current_screen)
    defer unload_current_screen(current_screen)

    core.Init()
    defer core.Unload()

    for !rl.WindowShouldClose() {
        update_current_screen(current_screen, &current_project)

        rl.BeginDrawing()
        defer rl.EndDrawing()

        rl.ClearBackground(rl.DARKGRAY)
        draw_current_screen(current_screen, &current_project)

        when ODIN_DEBUG {
            db.draw_fps()
        }

        if current_project.is_loaded && current_screen != .Editor {
            unload_current_screen(current_screen)
            current_screen = .Editor

            screens.init_editor()
        }

        if !current_project.is_loaded && current_screen != .Project_Picker {
            unload_current_screen(current_screen)
            current_screen = .Project_Picker

            screens.init_project_picker()
        }

        free_all(context.temp_allocator)
    }
}

init_current_screen :: proc(screen: Application_Screen) {
    switch screen {
    case .Editor:
        screens.init_editor()

    case .Project_Picker:
        screens.init_project_picker()
    }
}

update_current_screen :: proc(screen: Application_Screen, project: ^core.Project) {
    switch screen {
    case .Editor:
        screens.update_editor(project)

    case .Project_Picker:
        screens.update_project_picker(project)
    }
}

draw_current_screen :: proc(screen: Application_Screen, project: ^core.Project) {
    switch screen {
    case .Editor:
        screens.draw_editor(project)

    case .Project_Picker:
        screens.draw_project_picker()
    }
}

unload_current_screen :: proc(screen: Application_Screen) {
    switch screen {
    case .Editor:
        screens.unload_editor()

    case .Project_Picker:
        screens.unload_project_picker()
    }
}
