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
WINDOW_TITLE :: "Sprite Bundler"

TEST_PROJECT :: "Hello World"

debug_show_fps: bool

project: core.Project

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

main :: proc() {
	track: mem.Tracking_Allocator
	mem.tracking_allocator_init(&track, context.allocator)
	context.allocator = mem.tracking_allocator(&track)
	defer {
		for _, entry in track.allocation_map do fmt.eprintf("%v leaked %v bytes\n", entry.location, entry.size)
		for entry in track.bad_free_array do fmt.eprintf("%v bad free\n", entry.location)

		mem.tracking_allocator_destroy(&track)
	}

	rl.InitWindow(WINDOW_WIDTH, WINDOW_HEIGHT, WINDOW_TITLE)
	defer rl.CloseWindow()

	rl.SetWindowMinSize(WINDOW_WIDTH / 2, WINDOW_HEIGHT / 2)
	rl.SetWindowState({.WINDOW_RESIZABLE})
	rl.SetTraceLogLevel(.DEBUG)

	// Set max framerate without vsync
	max_fps := rl.GetMonitorRefreshRate(rl.GetCurrentMonitor())
	rl.SetTargetFPS(max_fps <= 0 ? FPS_MINIMUM : max_fps)

	if !os.is_dir("projects") do os.make_directory("projects")

	project_directory, project_file := core.GetProjectFilenames(TEST_PROJECT)
	defer delete(project_directory)
	defer delete(project_file)

	core.CreateNewProject(TEST_PROJECT, 1024, false, false)
	project, err := core.LoadProject(project_file)
	defer core.UnloadProject(&project)

	screens.InitEditor()
	defer screens.UnloadEditor()

	list := rl.LoadDirectoryFilesEx("src", nil, true)
	defer rl.UnloadDirectoryFiles(list)

	for !rl.WindowShouldClose() {
		screens.UpdateEditor(&project)

		rl.BeginDrawing()
		defer rl.EndDrawing()

		rl.ClearBackground(rl.DARKGRAY)
		screens.DrawEditor(project)

		when ODIN_DEBUG do DebugDrawFPS()
	}

	free_all(context.temp_allocator)
}
