package main

import rl "vendor:raylib"

draw_editor_toolbar :: proc(config: Config, project: ^Project) {
    rl.GuiEnableTooltip()

    rl.GuiSetTooltip("Save Project")
    rl.GuiButton({4, 4, 24, 24}, "#2#")

    rl.GuiSetTooltip("Export Project")
    rl.GuiButton({32, 4, 24, 24}, "#7#")

    rl.GuiSetTooltip("Generate default raylib font")
    if rl.GuiButton({60, 4, 24, 24}, "#31#") {
        generate_raylib_font(config, project)
        generate_project_atlas(project)
    }

    rl.GuiSetTooltip("Generate primitive sprite")
    if rl.GuiButton({88, 4, 24, 24}, "#100#") {
        generate_primitive_sprites(project)
        generate_project_atlas(project)
    }

    rl.GuiSetTooltip("Resize Atlas")
    rl.GuiButton({116, 4, 24, 24}, "#69#")

    rl.GuiDisableTooltip()
}

draw_texture_toolbar :: proc(config: Config, project: ^Project) {
    rl.GuiEnableTooltip()

    rl.GuiSetTooltip("Create Sprite")
    rl.GuiButton({4, 4, 24, 24}, "#8#")

    rl.GuiSetTooltip("Create Tileset")
    rl.GuiButton({32, 4, 24, 24}, "#97#")

    rl.GuiSetTooltip("Create Animation")
    rl.GuiButton({60, 4, 24, 24}, "#150#")

    rl.GuiSetTooltip("Delete Texture")
    if rl.GuiButton({88, 4, 24, 24}, "#9#") {

    }

    rl.GuiDisableTooltip()
}

draw_font_toolbar :: proc(config: Config, project: ^Project) {
    rl.GuiEnableTooltip()

    rl.GuiSetTooltip("Delete Font")
    rl.GuiButton({4, 4, 24, 24}, "#8#")

    rl.GuiDisableTooltip()
}
