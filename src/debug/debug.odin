package debug

import "core:fmt"
import "core:mem"

import rl "vendor:raylib"

@(private)
track: mem.Tracking_Allocator

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
    FPS_WARNING :: 60

    @(static)
    debug_show_fps: bool

    if rl.IsKeyPressed(.GRAVE) {
        debug_show_fps = !debug_show_fps
    }

    if debug_show_fps {
        current_fps := rl.TextFormat("%d FPS", rl.GetFPS())
        text_width := rl.MeasureText(current_fps, DEBUG_FONT_SIZE)
        text_colour := rl.GetFPS() < FPS_WARNING ? rl.ORANGE : rl.GREEN

        rl.DrawRectangle(0, 0, text_width + 16, 32, rl.Fade(rl.BLACK, 0.5))
        rl.DrawText(current_fps, 8, 8, DEBUG_FONT_SIZE, text_colour)
    }
}
