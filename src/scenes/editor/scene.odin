
package editor

import "core:math"

import rl "vendor:raylib"

import "../../common"

ctx: Editor_Context

init_scene :: proc() {
    rl.SetWindowSize (1280, 720)
    rl.SetWindowState({.WINDOW_MAXIMIZED})

    ctx.camera.zoom = 0.5

    ctx.current_atlas = nil
    ctx.selected_sprite = nil
    ctx.selected_sprite_index = -1
}

unload_scene :: proc() {}

update_scene :: proc(project: ^common.Project) -> common.Application_Scene {
    next_scene: common.Application_Scene = .Editor

    if ctx.current_atlas == nil {
        ctx.current_atlas = &project.atlas[0]
    }

    handle_editor_actions(project)

    ctx.cursor = .DEFAULT

    ctx.is_dialog_open = ctx.is_atlas_rename || ctx.is_sprite_rename

    update_camera()

    handle_shortcuts(project)
    handle_dropped_files(project)

    if rl.GetMouseY() < i32(TOOLBAR_HEIGHT) || ctx.is_dialog_open {
        rl.SetMouseCursor(.DEFAULT)
        return next_scene
    }

    mouse_position := rl.GetScreenToWorld2D(rl.GetMousePosition(), ctx.camera)
    for &sprite, index in ctx.current_atlas.sprites {
        if rl.CheckCollisionPointRec(mouse_position, sprite.source) {
            ctx.cursor = .POINTING_HAND

            if rl.IsMouseButtonReleased(.LEFT) {
                ctx.selected_sprite = &sprite
                ctx.selected_sprite_index = index
            }
            break
        }
    }

    if ctx.selected_sprite != nil {
        if ctx.should_edit_origin {
            offset := mouse_position - {ctx.selected_sprite.source.x, ctx.selected_sprite.source.y}

            offset.x = clamp(math.round(offset.x), 0, ctx.selected_sprite.source.width)
            offset.y = clamp(math.round(offset.y), 0, ctx.selected_sprite.source.height)

            ctx.selected_sprite.origin = offset

            ctx.cursor = .RESIZE_ALL

            if rl.IsMouseButtonPressed(.LEFT) {
                ctx.should_edit_origin = false
            }
        } else {
            if rl.IsMouseButtonReleased(.LEFT) {
                if !rl.CheckCollisionPointRec(mouse_position, ctx.selected_sprite.source) {
                    ctx.selected_sprite = nil
                    ctx.selected_sprite_index = -1
                }
            }
        }
    }

    rl.SetMouseCursor(ctx.cursor)

    return next_scene
}

draw_scene :: proc(project: ^common.Project) {
    draw_main_editor(project)
    draw_editor_gui(project)
}
