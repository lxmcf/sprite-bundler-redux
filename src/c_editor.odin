package main

import "core:fmt"

import rl "vendor:raylib"

Editor_Context :: struct {
    // CORE
    camera:           rl.Camera2D,
    editor_mode:      Editor_Mode,
    import_mode:      Import_Mode,

    // SELECTED
    current_atlas:    int,
    selected_texture: ^Texture,
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
}

update_editor :: proc(ctx: ^Editor_Context, project: ^Project) {
    handle_camera(ctx)
    handle_file_drop(ctx^, project)

    if rl.IsKeyDown(.LEFT_CONTROL) && rl.IsKeyReleased(.S) {
        save_project(project^)
    }
}

draw_editor :: proc(ctx: Editor_Context, project: Project) {
    rl.DrawTexture(project.back_texture, 0, 0, rl.WHITE)
    rl.DrawTexture(project.atlas_texture, 0, 0, rl.WHITE)
    rl.DrawRectangleLines(0, 0, i32(project.atlas_size), i32(project.atlas_size), rl.RED)
}

draw_editor_ui :: proc(ctx: Editor_Context) {
    rl.GuiPanel({0, 0, f32(rl.GetRenderWidth()), 32}, nil)

    #partial switch ctx.editor_mode {
    case .None:
        draw_editor_toolbar()

    case .Edit_Texture:
        draw_texture_toolbar()
    }
}

handle_file_drop :: proc(ctx: Editor_Context, project: ^Project) {
    if !rl.IsFileDropped() {
        return
    }

    dropped_files := rl.LoadDroppedFiles()
    defer rl.UnloadDroppedFiles(dropped_files)

    for i in 0 ..< dropped_files.count {
        path := dropped_files.paths[i]

        extension := rl.GetFileExtension(path)

        // TODO: Test all these formats, taken from https://github.com/raysan5/raylib/blob/master/FAQ.md#what-file-formats-are-supported-by-raylib
        switch rl.TextToLower(extension) {
        case ".ttf", ".otf":
            fmt.println("Got a font")

        case ".png", ".bmp", ".tga", ".jpg", ".gif", ".qoi", ".psd", ".dds", ".hdr", ".ktx", ".astc", ".pkm", ".pvr":
            file_import_image(path, project)
        }
    }
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

        ctx.camera.zoom = clamp(ctx.camera.zoom * scale_factor, 0.125, 64)
    }
}
