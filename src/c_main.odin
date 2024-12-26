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
    project.working_directory = "test/"
    project.file = "test.lspp"
    project.atlas_size = 1024
    defer unload_project(&project)

    ctx: Editor_Context

    init_editor(&ctx)

    for !rl.WindowShouldClose() {
        update_editor(&ctx, &project)

        when ODIN_DEBUG {
            if rl.IsKeyDown(.LEFT_CONTROL) {
                if rl.IsKeyPressed(.ONE) {
                    ctx.editor_mode = .None
                }

                if rl.IsKeyPressed(.TWO) {
                    ctx.editor_mode = .Edit_Texture
                }

                if rl.IsKeyPressed(.THREE) {
                    ctx.editor_mode = .Import
                }
            }
        }

        rl.BeginDrawing()
        defer rl.EndDrawing()

        rl.ClearBackground(rl.DARKGRAY)

        rl.BeginMode2D(ctx.camera)
        draw_editor(ctx, project)
        rl.EndMode2D()

        draw_editor_ui(ctx)

        when ODIN_DEBUG {
            draw_fps()
        }
    }
}
