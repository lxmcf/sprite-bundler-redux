#include <raylib.h>
#define LSPP_IMPL
#define LSPP_LOG_DEBUG
#include "lspp.h"

int main () {
    SetTraceLogLevel (LOG_DEBUG);

    InitWindow (1, 1, "");

    Bundle bundle = LoadBundle ("bundle.lspx");
    UnloadBundle (bundle);

    CloseWindow ();

    return 0;
}
