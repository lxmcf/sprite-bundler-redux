package main

import "core:os"
import rl "vendor:raylib"

main :: proc() {
    when ODIN_DEBUG {
        context.allocator = init_allocator()
        defer unload_allocator()
    }

    create_default_file_structure()

    rl.SetTraceLogLevel(.DEBUG when ODIN_DEBUG else .FATAL)
    rl.InitWindow(1280, 720, "lxmcf's sprite bundler")
    defer rl.CloseWindow()

    rl.SetWindowState({.WINDOW_RESIZABLE})

    max_fps := rl.GetMonitorRefreshRate(rl.GetCurrentMonitor())
    rl.SetTargetFPS(max_fps <= 0 ? FPS_MINIMUM : max_fps)

    project: Project
    defer unload_project(&project)

    ctx: Editor_Context
    config: Config = load_config(CONFIG_FILENAME)
    defer save_config(config, CONFIG_FILENAME)

    init_editor(&ctx)

    if !project_exists("nani") {
        create_project("nani", 1024)
    }

    project, _ = load_project("projects/nani/project.lspp")

    for !rl.WindowShouldClose() {
        update_editor(&ctx, &config, &project)

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

        draw_editor_ui(ctx, config, &project)

        when ODIN_DEBUG {
            draw_fps()
        }
    }
}

create_default_file_structure :: proc() {
    if !os.is_dir(PROJECT_DIRECTORY) {
        os.make_directory(PROJECT_DIRECTORY)
    }
}
