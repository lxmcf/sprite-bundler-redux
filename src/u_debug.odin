package main

import "core:fmt"
import "core:mem"

import rl "vendor:raylib"

FPS_WARNING :: #config(DEBUG_FPS_WARNING, 60)
FPS_CRITICAL :: #config(DEBUG_FPS_CRITICAL, 30)

@(private = "file")
track: mem.Tracking_Allocator

@(private = "file")
draw_debug: bool = true

init_allocator :: proc() -> mem.Allocator {
    mem.tracking_allocator_init(&track, context.allocator)
    return mem.tracking_allocator(&track)
}

unload_allocator :: proc() {
    if len(track.allocation_map) > 0 {
        fmt.eprintfln("DEBUG: %v leaked allocations", len(track.allocation_map))

        for _, entry in track.allocation_map {
            fmt.eprintfln("%v leaked %v bytes", entry.location, entry.size)
        }
    }

    if len(track.bad_free_array) > 0 {
        fmt.eprintfln("DEBUG: %v bad frees", len(track.bad_free_array))

        for entry in track.bad_free_array {
            fmt.eprintfln("%v bad free", entry.location)
        }
    }

    mem.tracking_allocator_destroy(&track)
}

draw_fps :: proc() {
    DEBUG_FONT_SIZE :: 20
    DEBUG_PADDING :: 8

    @(static) debug_min_fps: i32 = 256000
    @(static) debug_max_fps: i32 = 0
    @(static) debug_start_timer: f32 = 2

    if rl.IsKeyPressed(.GRAVE) {
        draw_debug = !draw_debug
    }

    fps := rl.GetFPS()

    if debug_start_timer <= 0 {
        if fps < debug_min_fps && fps != 0 {
            debug_min_fps = fps
        }

        if fps > debug_max_fps {
            debug_max_fps = fps
        }
    } else {
        debug_start_timer -= rl.GetFrameTime()
    }

    if draw_debug {
        fps_text_colour := rl.GREEN
        min_text_colour := rl.GREEN
        max_text_colour := rl.GREEN

        if fps <= FPS_WARNING && fps > FPS_CRITICAL {
            fps_text_colour = rl.ORANGE
        } else if fps <= FPS_CRITICAL {
            fps_text_colour = rl.RED
        }

        if debug_min_fps <= FPS_WARNING && debug_min_fps > FPS_CRITICAL {
            min_text_colour = rl.ORANGE
        } else if debug_min_fps <= FPS_CRITICAL {
            min_text_colour = rl.RED
        }

        if debug_max_fps <= FPS_WARNING && debug_max_fps > FPS_CRITICAL {
            max_text_colour = rl.ORANGE
        } else if debug_max_fps <= FPS_CRITICAL {
            max_text_colour = rl.RED
        }

        rl.DrawRectangle(0, 0, rl.GetRenderWidth(), DEBUG_FONT_SIZE + (DEBUG_PADDING * 2), rl.Fade(rl.BLACK, 0.5))

        rl.DrawText(rl.TextFormat("FPS: %2i", debug_start_timer > 0 ? 0 : fps), DEBUG_PADDING, DEBUG_PADDING, DEBUG_FONT_SIZE, fps_text_colour)
        rl.DrawText(rl.TextFormat("MIN: %2i", debug_start_timer > 0 ? 0 : debug_min_fps), 136, DEBUG_PADDING, DEBUG_FONT_SIZE, min_text_colour)
        rl.DrawText(rl.TextFormat("MAX: %2i", debug_start_timer > 0 ? 0 : debug_max_fps), 264, DEBUG_PADDING, DEBUG_FONT_SIZE, max_text_colour)
    }
}

draw_screen_centre :: proc(colour := rl.RED) {
    if draw_debug {
        width := f32(rl.GetRenderWidth())
        height := f32(rl.GetRenderHeight())

        rl.DrawLineV({width / 2, 0}, {width / 2, height}, colour)
        rl.DrawLineV({0, height / 2}, {width, height / 2}, colour)
    }
}
