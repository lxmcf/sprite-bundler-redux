package main

import "core:fmt"
import "core:mem"
import "core:os"

import rl "vendor:raylib"

// import "bundler:core"
import "bundler:myui"
import "bundler:screens"

FPS_MINIMUM :: 60
WINDOW_WIDTH :: 1280
WINDOW_HEIGHT :: 720
WINDOW_TITLE :: "Sprite Bundler"

TEST_PROJECT :: "Hello World"

ApplicationScreen :: enum {
    PROJECT_PICKER,
    EDITOR,
}

debug_show_fps: bool
current_screen: ApplicationScreen

DebugDrawFPS :: proc() {
    DEBUG_FONT_SIZE :: 20

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

    // _, file, _ := core.GetProjectFilenames(TEST_PROJECT, allocator = context.temp_allocator)

    // core.CreateNewProject(TEST_PROJECT, 1024, false, false)
    // project, _ := core.LoadProject(file)
    // defer core.UnloadProject(&project)

    // screens.InitEditor(&project)
    // defer screens.UnloadEditor()

    screens.InitProjectPicker()
    defer screens.UnloadProjectPicker()

    myui.Init()
    defer myui.Unload()

    for !rl.WindowShouldClose() {
        // screens.UpdateEditor(&project)
        screens.UpdateProjectPicker()

        rl.BeginDrawing()
        defer rl.EndDrawing()

        rl.ClearBackground(rl.DARKGRAY)
        // screens.DrawEditor(&project)
        screens.DrawProjectPicker()

        free_all(context.temp_allocator)
        when ODIN_DEBUG do DebugDrawFPS()
    }

    free_all(context.temp_allocator)
}
