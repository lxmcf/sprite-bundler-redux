package main

import rl "vendor:raylib"

main :: proc() {
    when ODIN_DEBUG {
        context.allocator = init_allocator()
        defer unload_allocator()
    }

    rl.SetWindowState({.WINDOW_HIGHDPI})

    rl.SetTraceLogLevel(.DEBUG when ODIN_DEBUG else .FATAL)
    rl.InitWindow(1280, 720, "lxmcf's sprite bundler")
    defer rl.CloseWindow()

    rl.SetWindowState({.WINDOW_RESIZABLE})

    max_fps := rl.GetMonitorRefreshRate(rl.GetCurrentMonitor())
    rl.SetTargetFPS(max_fps <= 0 ? FPS_MINIMUM : max_fps)

    project: Project

    for !rl.WindowShouldClose() {
        handle_file_drop(&project)

        if rl.IsKeyReleased(.F1) {
            save_project(project)
        }

        rl.BeginDrawing()
        defer rl.EndDrawing()

        rl.ClearBackground(rl.DARKGRAY)

        draw_editor_toolbar()

        when ODIN_DEBUG {
            draw_fps()
        }
    }
}
