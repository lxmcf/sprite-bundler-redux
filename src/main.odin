package main

import "core:fmt"
import "core:mem"
import "core:os"

import rl "vendor:raylib"

import "bundler:screens"

FPS_MINIMUM :: 60

debug_show_fps: bool

main :: proc() {
	track: mem.Tracking_Allocator
	mem.tracking_allocator_init(&track, context.allocator)
	context.allocator = mem.tracking_allocator(&track)
	defer {
		for _, entry in track.allocation_map {
			fmt.eprintf("%v leaked %v bytes\n", entry.location, entry.size)
		}

		for entry in track.bad_free_array {
			fmt.eprintf("%v bad free\n", entry.location)
		}

		mem.tracking_allocator_destroy(&track)
	}

	rl.InitWindow(1280, 720, "Sprite Bundler")
	defer rl.CloseWindow()

	rl.SetWindowMinSize(640, 480)
	rl.SetWindowState({.WINDOW_RESIZABLE})
	rl.SetTraceLogLevel(.INFO)

	// Set max framerate without vsync
	max_fps := rl.GetMonitorRefreshRate(rl.GetCurrentMonitor())
	rl.SetTargetFPS(max_fps <= 0 ? FPS_MINIMUM : max_fps)

	camera := rl.Camera2D {
		zoom = 1.0,
	}

	screens.InitEditor("data/test.json")
	defer screens.UnloadEditor()

	for !rl.WindowShouldClose() {
		if rl.IsMouseButtonDown(.MIDDLE) {
			delta := rl.GetMouseDelta()

			delta *= -1.0 / camera.zoom
			camera.target += delta
		}

		mouse_wheel := rl.GetMouseWheelMove()
		if mouse_wheel != 0 {
			mouse_world_position := rl.GetScreenToWorld2D(rl.GetMousePosition(), camera)

			camera.offset = rl.GetMousePosition()
			camera.target = mouse_world_position

			scale_factor := 1 + (0.25 * abs(mouse_wheel))
			if mouse_wheel < 0 {
				scale_factor = 1.0 / scale_factor
			}

			camera.zoom = clamp(camera.zoom * scale_factor, 0.125, 64)
		}

		rl.BeginDrawing()
		defer rl.EndDrawing()

		rl.ClearBackground(rl.DARKGRAY)

		rl.BeginMode2D(camera)
		rl.DrawRectangle(0, 0, 1024, 1024, rl.GREEN)

		rl.EndMode2D()

		if ODIN_DEBUG {
			DEBUG_FONT_SIZE :: 20

			if rl.IsKeyPressed(.GRAVE) {
				debug_show_fps = !debug_show_fps
			}

			if debug_show_fps {
				current_fps := rl.TextFormat("%d FPS", rl.GetFPS())
				text_width := rl.MeasureText(current_fps, DEBUG_FONT_SIZE)
				text_colour := rl.GetFPS() < FPS_MINIMUM ? rl.ORANGE : rl.GREEN

				rl.DrawRectangle(0, 0, text_width + 16, 32, rl.Fade(rl.BLACK, 0.5))
				rl.DrawText(current_fps, 8, 8, DEBUG_FONT_SIZE, text_colour)
			}
		}
	}

	free_all(context.temp_allocator)
}
