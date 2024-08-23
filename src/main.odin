package main

import "core:fmt"
import "core:mem"
import "core:os"

import rl "vendor:raylib"

import "bundler:core"
import "bundler:screens"

FPS_MINIMUM :: 60
WINDOW_WIDTH :: 1280
WINDOW_HEIGHT :: 720
WINDOW_TITLE :: "Sprite Packer"

TEST_PROJECT :: "Hello World"

ApplicationScreen :: enum {
    PROJECT_PICKER,
    EDITOR,
}

DebugDrawFPS :: proc() {
    DEBUG_FONT_SIZE :: 20

    @(static)
    debug_show_fps: bool

    if rl.IsKeyPressed(.GRAVE) do debug_show_fps = !debug_show_fps

    if debug_show_fps {
        current_fps := rl.TextFormat("%d FPS", rl.GetFPS())
        text_width := rl.MeasureText(current_fps, DEBUG_FONT_SIZE)
        text_colour := rl.GetFPS() < FPS_MINIMUM ? rl.ORANGE : rl.GREEN

        rl.DrawRectangle(0, 0, text_width + 16, 32, rl.Fade(rl.BLACK, 0.5))
        rl.DrawText(current_fps, 8, 8, DEBUG_FONT_SIZE, text_colour)
    }
}

UnloadTrackingAllocator :: proc(track: ^mem.Tracking_Allocator) {
    if len(track.allocation_map) > 0 {
        fmt.eprintfln("<------ %v leaked allocations ------>", len(track.allocation_map))
        for _, entry in track.allocation_map do fmt.eprintfln("%v leaked %v bytes", entry.location, entry.size)
    }

    if len(track.bad_free_array) > 0 {
        fmt.eprintfln("<------ %v bad frees          ------>", len(track.bad_free_array))
        for entry in track.bad_free_array do fmt.eprintfln("%v bad free", entry.location)
    }

    mem.tracking_allocator_destroy(track)
}

main :: proc() {
    track: mem.Tracking_Allocator
    mem.tracking_allocator_init(&track, context.allocator)
    context.allocator = mem.tracking_allocator(&track)
    defer UnloadTrackingAllocator(&track)

    rl.InitWindow(WINDOW_WIDTH, WINDOW_HEIGHT, WINDOW_TITLE)
    defer rl.CloseWindow()

    rl.SetWindowMinSize(640, 360)
    rl.SetWindowState({.WINDOW_RESIZABLE})
    rl.SetTraceLogLevel(.DEBUG)

    // Set max framerate without vsync
    max_fps := rl.GetMonitorRefreshRate(rl.GetCurrentMonitor())
    rl.SetTargetFPS(max_fps <= 0 ? FPS_MINIMUM : max_fps)

    if !os.is_dir("projects") do os.make_directory("projects")

    current_screen := ApplicationScreen.PROJECT_PICKER
    current_project: core.Project
    defer core.UnloadProject(&current_project)

    screens.InitProjectPicker()
    defer UnloadCurrentScreen(current_screen)

    core.Init()
    defer core.Unload()

    for !rl.WindowShouldClose() {
        UpdateCurrentScreen(current_screen, &current_project)

        rl.BeginDrawing()
        defer rl.EndDrawing()

        rl.ClearBackground(rl.DARKGRAY)
        DrawCurrentScreen(current_screen, &current_project)

        when ODIN_DEBUG {
            DebugDrawFPS()
        }

        if current_project.is_loaded && current_screen != .EDITOR {
            UnloadCurrentScreen(current_screen)
            current_screen = .EDITOR

            screens.InitEditor(&current_project)
        }

        if !current_project.is_loaded && current_screen != .PROJECT_PICKER {
            UnloadCurrentScreen(current_screen)
            current_screen = .PROJECT_PICKER

            screens.InitProjectPicker()
        }

        free_all(context.temp_allocator)
    }
}

UpdateCurrentScreen :: proc(screen: ApplicationScreen, project: ^core.Project) {
    switch screen {
    case .EDITOR:
        screens.UpdateEditor(project)

    case .PROJECT_PICKER:
        screens.UpdateProjectPicker(project)
    }
}

DrawCurrentScreen :: proc(screen: ApplicationScreen, project: ^core.Project) {
    switch screen {
    case .EDITOR:
        screens.DrawEditor(project)

    case .PROJECT_PICKER:
        screens.DrawProjectPicker()
    }
}

UnloadCurrentScreen :: proc(screen: ApplicationScreen) {
    switch screen {
    case .EDITOR:
        screens.UnloadEditor()

    case .PROJECT_PICKER:
        screens.UnloadProjectPicker()
    }
}
