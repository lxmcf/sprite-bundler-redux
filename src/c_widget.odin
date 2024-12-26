package main

import rl "vendor:raylib"

draw_editor_toolbar :: proc() {
    rl.GuiEnableTooltip()
    rl.GuiPanel({0, 0, f32(rl.GetRenderWidth()), 32}, nil)

    rl.GuiSetTooltip("Save Project [CTRL + S]")
    rl.GuiButton({4, 4, 24, 24}, "#2#")

    rl.GuiSetTooltip("Export Project [CTRL + E]")
    rl.GuiButton({32, 4, 24, 24}, "#7#")

    rl.GuiDisableTooltip()
}
