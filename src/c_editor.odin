package main

import "core:fmt"
import "core:math"

import rl "vendor:raylib"

Editor_Context :: struct {
    // CORE
    camera:           rl.Camera2D,
    target_zoom:      f32,
    editor_mode:      Editor_Mode,
    import_mode:      Import_Mode,

    // SELECTED
    selected_texture: int,
}

Editor_Mode :: enum u8 {
    None,
    Edit_Texture,
    Import,
}

Import_Mode :: enum u8 {
    None,
    Texture,
    Font,
}

init_editor :: proc(ctx: ^Editor_Context) {
    ctx.camera.zoom = 1
    ctx.target_zoom = 1
    ctx.selected_texture = -1
}

update_editor :: proc(ctx: ^Editor_Context, config: ^Config, project: ^Project) {
    handle_camera(ctx)
    handle_file_drop(ctx^, config^, project)

    mouse := rl.GetMousePosition()
    mouse_world := rl.GetScreenToWorld2D(mouse, ctx.camera)
    cursor: rl.MouseCursor = .DEFAULT
    defer rl.SetMouseCursor(cursor)

    if mouse.y < EDITOR_TOOLBAR_HEIGHT {
        return
    }

    if rl.IsKeyDown(.LEFT_CONTROL) && rl.IsKeyReleased(.S) {
        save_project(project^)
    }

    for texture, index in project.textures {
        if !texture.packed {
            continue
        }

        if rl.CheckCollisionPointRec(mouse_world, texture.bounds) {
            cursor = .POINTING_HAND

            if rl.IsMouseButtonReleased(.LEFT) {
                ctx.selected_texture = index
                ctx.editor_mode = .Edit_Texture
            }
            break
        }
    }

    if ctx.selected_texture > -1 {
        if rl.IsMouseButtonReleased(.LEFT) {
            bounds := project.textures[ctx.selected_texture].bounds

            if !rl.CheckCollisionPointRec(mouse_world, bounds) {
                ctx.selected_texture = -1
                ctx.editor_mode = .None
            }
        }
    }
}

draw_editor :: proc(ctx: Editor_Context, project: Project) {
    rl.DrawTexture(project.back_texture, 0, 0, rl.WHITE)
    rl.DrawTexture(project.atlas_texture, 0, 0, rl.WHITE)

    if ctx.selected_texture > -1 {
        bounds := project.textures[ctx.selected_texture].bounds

        rl.DrawRectangle(0, 0, i32(project.atlas_size), i32(project.atlas_size), {0, 0, 0, 190})
        rl.DrawTextureRec(project.atlas_texture, bounds, {bounds.x, bounds.y}, rl.WHITE)
    }
}

draw_editor_ui :: proc(ctx: Editor_Context, config: Config, project: ^Project) {
    if ctx.selected_texture > -1 {
        bounds := project.textures[ctx.selected_texture].bounds

        position := rl.GetWorldToScreen2D({bounds.x, bounds.y}, ctx.camera)
        size: Vector2 = {bounds.width, bounds.height} * ctx.camera.zoom

        rl.DrawRectangleLinesEx({position.x, position.y, size.x, size.y}, 1, rl.RED)
    }

    rl.GuiPanel({0, 0, f32(rl.GetRenderWidth()), EDITOR_TOOLBAR_HEIGHT}, nil)

    #partial switch ctx.editor_mode {
    case .None:
        draw_editor_toolbar(config, project)

    case .Edit_Texture:
        draw_texture_toolbar(config, project)
    }
}

handle_file_drop :: proc(ctx: Editor_Context, config: Config, project: ^Project) {
    if !rl.IsFileDropped() {
        return
    }

    should_regenerate_atlas: bool
    dropped_files := rl.LoadDroppedFiles()
    defer rl.UnloadDroppedFiles(dropped_files)

    for i in 0 ..< dropped_files.count {
        path := dropped_files.paths[i]

        extension := rl.GetFileExtension(path)

        // TODO: Test all these formats, taken from https://github.com/raysan5/raylib/blob/master/FAQ.md#what-file-formats-are-supported-by-raylib
        switch rl.TextToLower(extension) {
        case ".lspp":
            fmt.println("Got a project file")

        case ".ttf", ".otf":
            ok := file_import_font(path, config, project)

            if ok {
                should_regenerate_atlas = true
            } else {
                fmt.eprintfln("ERROR: FILE: Failed to load font [%s]!", path)
            }

        case ".png", ".bmp", ".tga", ".jpg", ".gif", ".qoi", ".psd", ".dds", ".hdr", ".ktx", ".astc", ".pkm", ".pvr":
            ok := file_import_image(path, config, project)

            if ok {
                should_regenerate_atlas = true
            } else {
                fmt.eprintfln("ERROR: FILE: Failed to load image [%s]!", path)
            }
        }
    }

    if should_regenerate_atlas {
        generate_project_atlas(project)
    }

    save_project(project^)
}

handle_camera :: proc(ctx: ^Editor_Context) {
    if rl.IsMouseButtonDown(.MIDDLE) || rl.IsKeyDown(.LEFT_ALT) {
        delta := rl.GetMouseDelta()

        delta *= -1.0 / ctx.camera.zoom
        ctx.camera.target += delta
    }

    mouse_wheel := rl.GetMouseWheelMove()
    if mouse_wheel != 0 && !rl.IsMouseButtonDown(.MIDDLE) {
        mouse_world_position := rl.GetScreenToWorld2D(rl.GetMousePosition(), ctx.camera)

        ctx.camera.offset = rl.GetMousePosition()
        ctx.camera.target = mouse_world_position

        scale_factor := 1 + (0.25 * abs(mouse_wheel))
        if mouse_wheel < 0 {
            scale_factor = 1.0 / scale_factor
        }

        ctx.target_zoom = clamp(ctx.target_zoom * scale_factor, 0.25, 64)
    }

    ctx.camera.zoom = math.lerp(ctx.camera.zoom, ctx.target_zoom, rl.GetFrameTime() * 15)
}
