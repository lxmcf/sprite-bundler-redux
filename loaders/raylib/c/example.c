#include <math.h>

#define LSPX_IMPL
#include "lspx.h"

// NOTE: Will return sinf but between 0 and 1
#define SINE(x) ((sinf ((float)x) + 1.0f) / 2.0f)

int main () {
    InitWindow (640, 360, "LSPP Example C");
    SetTargetFPS (60);

    int current_sprite = 0;
    float rotation     = 0;

    Bundle bundle = LoadBundle ("example.lspx");
    SetActiveBundle (&bundle);

    while (!WindowShouldClose ()) {
        if (IsKeyReleased (KEY_SPACE))
            current_sprite++;

        rotation += GetFrameTime () * 90;
        const float time = GetTime () * 2;
        Vector2 scale    = CLITERAL (Vector2){1 + SINE (time), 1 + SINE (time)};

        BeginDrawing ();
        ClearBackground (RAYWHITE);

        if (IsBundleReady (bundle)) {
            DrawSpriteEx (current_sprite % bundle.sprite_count, CLITERAL (Vector2){320, 180}, scale, rotation, WHITE);

            DrawText ("Press [SPACE] to cycle sprites!", 8, 8, 20, LIGHTGRAY);
            DrawText (TextFormat ("Current sprite: %s", GetSpriteName (current_sprite % bundle.sprite_count)), 8, 32, 20, LIGHTGRAY);
        } else {
            DrawText ("Could not find the example bundle :-(", 8, 8, 20, LIGHTGRAY);
        }

        EndDrawing ();
    }

    UnloadBundle (bundle);

    CloseWindow ();

    return 0;
}
