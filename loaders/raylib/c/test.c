#define LSPP_IMPL
#define LSPP_LOG_DEBUG
#include "lspp.h"

int main () {
    SetTraceLogLevel (LOG_DEBUG);
    InitWindow (1280, 720, "LSPP Example C");
    SetTargetFPS (60);

    Bundle bundle = LoadBundle ("bundle.lspx");
    SetActiveBundle (&bundle);

    while (!WindowShouldClose ()) {
        BeginDrawing ();
        DrawTexture (bundle.atlas[0], 0, 0, WHITE);
        EndDrawing ();
    }

    UnloadBundle (bundle);

    CloseWindow ();

    return 0;
}
