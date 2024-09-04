package main

import "core:math"
import ls "lspx"
import rl "vendor:raylib"

main :: proc() {
    rl.InitWindow(640, 360, "LSPP Example Odin")
    rl.SetTargetFPS(60)

    bundle, _ := ls.LoadBundle("example.lspx")
    ls.SetActiveBundle(bundle)

    current_sprite: int
    rotation: f32

    sprite_names := [?]string{"Blue Ship", "Pink Ship", "Green Ship", "Beige Ship", "Yellow Ship"}

    for !rl.WindowShouldClose() {
        if rl.IsKeyPressed(.SPACE) do current_sprite += 1

        rotation += rl.GetFrameTime() * 90
        time := sine(f32(rl.GetTime()) * 2)

        rl.BeginDrawing()
        defer rl.EndDrawing()

        rl.ClearBackground(rl.RAYWHITE)

        if ls.IsBundleReady(bundle) {
            ls.DrawSpriteEx(sprite_names[current_sprite % len(sprite_names)], {320, 180}, {1 + time, 1 + time}, rotation)

            rl.DrawText("Press [SPACE] to cycle sprites!", 8, 8, 20, rl.LIGHTGRAY)
            rl.DrawText(rl.TextFormat("Current sprite: %s", sprite_names[current_sprite % len(sprite_names)]), 8, 32, 20, rl.LIGHTGRAY)
        } else {
            rl.DrawText("Could not find the example bundle :-(", 8, 8, 20, rl.LIGHTGRAY)
        }
    }

    ls.UnloadBundle(bundle)
}

// NOTE: Will return sinf but between 0 and 1
sine :: proc(x: f32) -> f32 {
    return (math.sin_f32(x) + 1) / 2
}
