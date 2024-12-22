package main

import rl "vendor:raylib"

draw_toolbar :: proc() {
    rl.GuiEnableTooltip()
    rl.GuiPanel({0, 0, f32(rl.GetRenderWidth()), 32}, nil)

    rl.GuiSetTooltip("Save Project [CTRL + S]")
    rl.GuiButton({4, 4, 24, 24}, "#2#")

    rl.GuiSetTooltip("Export Project [CTRL + E]")
    rl.GuiButton({32, 4, 24, 24}, "#7#")

    rl.GuiSetTooltip("Rename Sprite [CTRL + R]")
    rl.GuiButton({60, 4, 24, 24}, "#30#")

    rl.GuiSetTooltip("Set Origin Point [V]")
    rl.GuiButton({88, 4, 24, 24}, "#50#")

    rl.GuiSetTooltip("Rotate Sprite 90 Degrees (CW)")
    rl.GuiButton({116, 4, 24, 24}, "#76#")

    rl.GuiSetTooltip("Flip Sprite Horizontally")
    rl.GuiButton({144, 4, 24, 24}, "#40#")

    rl.GuiSetTooltip("Flip Sprite Vertically")
    rl.GuiButton({172, 4, 24, 24}, "#41#")

    rl.GuiDisableTooltip()
}
