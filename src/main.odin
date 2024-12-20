package main

import "core:os"
import rl "vendor:raylib"

import "common"
import "scenes"

import db "debug"
_ :: db

FPS_MINIMUM :: 60
WINDOW_WIDTH :: 1280
WINDOW_HEIGHT :: 720
WINDOW_TITLE :: "Sprite Packer"

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

    current_scene := common.Application_Scene.Project_Picker
    current_project: common.Project
    defer common.unload_project(&current_project)

    scenes.init_current_scene(current_scene)
    defer scenes.unload_current_scene(current_scene)

    for !rl.WindowShouldClose() {
        next_scene := scenes.update_current_scene(current_scene, &current_project)

        rl.BeginDrawing()
        defer rl.EndDrawing()

        rl.ClearBackground(rl.DARKGRAY)
        scenes.draw_current_scene(current_scene, &current_project)

        when ODIN_DEBUG {
            db.draw_fps()
        }

        if next_scene != current_scene {
            scenes.unload_current_scene(current_scene)
            current_scene = next_scene
            scenes.init_current_scene(current_scene)
        }

        free_all(context.temp_allocator)
    }
}
