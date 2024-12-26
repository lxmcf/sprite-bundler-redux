package main

import rl "vendor:raylib"

draw_editor_toolbar :: proc() {
    rl.GuiEnableTooltip()

    rl.GuiSetTooltip("Save Project")
    rl.GuiButton({4, 4, 24, 24}, "#2#")

    rl.GuiSetTooltip("Export Project")
    rl.GuiButton({32, 4, 24, 24}, "#7#")

    rl.GuiDisableTooltip()
}

draw_texture_toolbar :: proc() {
    rl.GuiEnableTooltip()

    rl.GuiSetTooltip("Create Sprite")
    rl.GuiButton({4, 4, 24, 24}, "#8#")

    rl.GuiSetTooltip("Create Tileset")
    rl.GuiButton({32, 4, 24, 24}, "#97#")

    rl.GuiSetTooltip("Create Animation")
    rl.GuiButton({60, 4, 24, 24}, "#150#")

    rl.GuiDisableTooltip()
}
