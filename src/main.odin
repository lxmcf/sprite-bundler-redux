package main

import "core:os"
import rl "vendor:raylib"

import "common"
import editor "screens/editor"
import projects "screens/project_picker"

import db "debug"
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

    rl.SetTraceLogLevel(.DEBUG when ODIN_DEBUG else .FATAL)
    rl.InitWindow(WINDOW_WIDTH, WINDOW_HEIGHT, WINDOW_TITLE)
    defer rl.CloseWindow()

    rl.SetWindowState({.WINDOW_RESIZABLE})
    rl.SetExitKey(.KEY_NULL)

    // Set max framerate without vsync
    max_fps := rl.GetMonitorRefreshRate(rl.GetCurrentMonitor())
    rl.SetTargetFPS(max_fps <= 0 ? FPS_MINIMUM : max_fps)

    if !os.is_dir("projects") {
        os.make_directory("projects")
    }

    current_screen := Application_Screen.Project_Picker
    current_project: common.Project
    defer common.unload_project(&current_project)

    init_current_screen(current_screen)
    defer unload_current_screen(current_screen)

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

            editor.init_scene()
        }

        if !current_project.is_loaded && current_screen != .Project_Picker {
            unload_current_screen(current_screen)
            current_screen = .Project_Picker

            projects.init_scene()
        }

        free_all(context.temp_allocator)
    }
}

init_current_screen :: proc(screen: Application_Screen) {
    switch screen {
    case .Editor:
        editor.init_scene()

    case .Project_Picker:
        projects.init_scene()
    }
}

update_current_screen :: proc(screen: Application_Screen, project: ^common.Project) {
    switch screen {
    case .Editor:
        editor.update_scene(project)

    case .Project_Picker:
        projects.update_scene(project)
    }
}

draw_current_screen :: proc(screen: Application_Screen, project: ^common.Project) {
    switch screen {
    case .Editor:
        editor.draw_scene(project)

    case .Project_Picker:
        projects.draw_scene()
    }
}

unload_current_screen :: proc(screen: Application_Screen) {
    switch screen {
    case .Editor:
        editor.unload_scene()

    case .Project_Picker:
        projects.unload_scene()
    }
}
