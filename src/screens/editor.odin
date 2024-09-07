// FIXME: This really does not need to be 400+ lines...
package screens

import "core:crypto"
import "core:encoding/uuid"
import "core:math"
import "core:os"
import "core:strings"

import mu "vendor:microui"
import rl "vendor:raylib"
import stb "vendor:stb/rect_pack"

import "bundler:core"

@(private = "file")
EditorState :: struct {
    camera:               rl.Camera2D,
    cursor:               rl.MouseCursor,

    // Selected elements
    current_atlas_index:  int,
    current_atlas:        ^core.Atlas,
    selected_sprite:      ^core.Sprite,

    // Buffers
    is_dialog_open:       bool,
    is_atlas_rename:      bool,
    is_sprite_rename:     bool,

    // Editors
    should_edit_origin:   bool,

    // UI controls
    save_project:         bool,
    export_project:       bool,
    create_new_atlas:     bool,
    delete_current_atlas: bool,
}

@(private = "file")
state: EditorState

TOOLBAR_HEIGHT :: 32

// ====== PUBLIC ====== \\
InitEditor :: proc(project: ^core.Project) {
    state.camera.zoom = 0.5

    state.current_atlas = &project.atlas[0]
    state.selected_sprite = nil
}

UnloadEditor :: proc() {}

UpdateEditor :: proc(project: ^core.Project) {
    HandleEditorActions(project)

    state.cursor = .DEFAULT

    state.is_dialog_open = state.is_atlas_rename || state.is_sprite_rename

    UpdateCamera()

    HandleShortcuts(project)
    HandleDroppedFiles(project)

    if rl.GetMouseY() < i32(TOOLBAR_HEIGHT) || state.is_dialog_open {
        rl.SetMouseCursor(.DEFAULT)
        return
    }

    mouse_position := rl.GetScreenToWorld2D(rl.GetMousePosition(), state.camera)
    for &sprite in state.current_atlas.sprites {
        if rl.CheckCollisionPointRec(mouse_position, sprite.source) {
            state.cursor = .POINTING_HAND

            if rl.IsMouseButtonReleased(.LEFT) {
                state.selected_sprite = &sprite
            }
            break
        }
    }

    if state.selected_sprite != nil {
        if state.should_edit_origin {
            offset := mouse_position - {state.selected_sprite.source.x, state.selected_sprite.source.y}

            offset.x = clamp(math.round(offset.x), 0, state.selected_sprite.source.width)
            offset.y = clamp(math.round(offset.y), 0, state.selected_sprite.source.height)

            state.selected_sprite.origin = offset

            state.cursor = .RESIZE_ALL

            if rl.IsMouseButtonPressed(.LEFT) {
                state.should_edit_origin = false
            }
        } else {
            if rl.IsMouseButtonReleased(.LEFT) {
                if !rl.CheckCollisionPointRec(mouse_position, state.selected_sprite.source) {
                    state.selected_sprite = nil
                }
            }
        }
    }

    rl.SetMouseCursor(state.cursor)
}

DrawEditor :: proc(project: ^core.Project) {
    DrawMainEditor(project)
    DrawEditorGui(project)
}

// ====== PRIVATE ====== \\
@(private = "file")
UpdateCamera :: proc() {
    if rl.IsMouseButtonDown(.MIDDLE) || rl.IsKeyDown(.LEFT_ALT) {
        delta := rl.GetMouseDelta()

        delta *= -1.0 / state.camera.zoom
        state.camera.target += delta
    }

    mouse_wheel := rl.GetMouseWheelMove()
    if mouse_wheel != 0 && !rl.IsMouseButtonDown(.MIDDLE) {
        mouse_world_position := rl.GetScreenToWorld2D(rl.GetMousePosition(), state.camera)

        state.camera.offset = rl.GetMousePosition()
        state.camera.target = mouse_world_position

        scale_factor := 1 + (0.25 * abs(mouse_wheel))
        if mouse_wheel < 0 do scale_factor = 1.0 / scale_factor

        state.camera.zoom = clamp(state.camera.zoom * scale_factor, 0.125, 64)
    }
}

@(private = "file")
HandleEditorActions :: proc(project: ^core.Project) {
    if state.save_project do core.WriteProject(project)
    if state.export_project do core.ExportBundle(project^)
    if state.create_new_atlas do core.CreateNewAtlas(project, "Blank Atlas")

    if state.delete_current_atlas {
        core.DeleteAtlas(project, state.current_atlas_index)

        if len(project.atlas) == 0 {
            core.CreateNewAtlas(project, "Blank Atlas")
        }
    }

    state.export_project = false
    state.save_project = false
    state.create_new_atlas = false
    state.delete_current_atlas = false
}

@(private = "file")
HandleShortcuts :: proc(project: ^core.Project) {
    // Centre camera
    if rl.IsKeyReleased(.Z) && !state.should_edit_origin {
        screen: rl.Vector2 = {f32(rl.GetScreenWidth()), f32(rl.GetScreenHeight())}

        state.camera.offset = screen / 2
        state.camera.target = {f32(project.config.atlas_size), f32(project.config.atlas_size)} / 2

        state.camera.zoom = 0.5
    }

    // Centre sprite origin
    if rl.IsKeyReleased(.Z) && state.should_edit_origin {
        state.selected_sprite.origin = {state.selected_sprite.source.width, state.selected_sprite.source.height} / 2

        state.should_edit_origin = false
    }

    if rl.IsKeyPressed(.V) do state.should_edit_origin = !state.should_edit_origin

    if rl.IsKeyDown(.LEFT_CONTROL) {
        if rl.IsKeyPressed(.S) do state.save_project = true
        if rl.IsKeyPressed(.E) do state.export_project = true
        if rl.IsKeyPressed(.N) do state.create_new_atlas = true
        if rl.IsKeyPressed(.Y) do state.delete_current_atlas = true

        if rl.IsKeyPressed(.R) {
            if state.selected_sprite != nil {
                state.is_sprite_rename = true
            } else {
                state.is_atlas_rename = true
            }
        }

        change_atlas := int(rl.IsKeyPressed(.RIGHT_BRACKET)) - int(rl.IsKeyPressed(.LEFT_BRACKET))
        if change_atlas != 0 {
            state.current_atlas_index = clamp(state.current_atlas_index + change_atlas, 0, len(project.atlas) - 1)
            state.current_atlas = &project.atlas[state.current_atlas_index]
        }

        if rl.IsKeyPressed(.P) {
            core.ImportBundle("bundle.lspx")
        }
    }
}

@(private = "file")
HandleDroppedFiles :: proc(project: ^core.Project) {
    context.random_generator = crypto.random_generator()
    if rl.IsFileDropped() {
        files := rl.LoadDroppedFiles()
        defer rl.UnloadDroppedFiles(files)

        if files.count > 0 {
            for i in 0 ..< files.count {
                path := files.paths[i]

                if !rl.IsFileExtension(path, ".png") do continue

                image := rl.LoadImage(path)
                name := strings.clone_from_cstring(rl.GetFileNameWithoutExt(path))

                if project.config.copy_files {
                    id := uuid.generate_v7_basic()
                    filename := strings.concatenate(
                        {project.config.assets_dir, uuid.to_string(id, context.temp_allocator), ".png"},
                        context.temp_allocator,
                    )

                    for os.is_file(filename) {
                        id = uuid.generate_v7_basic()
                        filename = strings.concatenate(
                            {project.config.assets_dir, uuid.to_string(id, context.temp_allocator), ".png"},
                            context.temp_allocator,
                        )
                    }

                    path = strings.clone_to_cstring(filename, context.temp_allocator)

                    rl.ExportImage(image, path)
                }

                sprite: core.Sprite = {
                    name   = name,
                    file   = strings.clone_from_cstring(path),
                    atlas  = strings.clone(state.current_atlas.name),
                    image  = image,
                    source = {0, 0, f32(image.width), f32(image.height)},
                }

                if project.config.auto_center {
                    sprite.origin = {sprite.source.width, sprite.source.height} / 2
                }

                append(&state.current_atlas.sprites, sprite)
            }

            PackSprites(project)

            core.GenerateAtlas(state.current_atlas)
        } else {
            rl.TraceLog(.ERROR, "[FILE] Did not find any files to sort!")
        }
    }
}

@(private = "file")
PackSprites :: proc(project: ^core.Project) {
    atlas_size := i32(project.config.atlas_size)

    stb_context: stb.Context
    stb_nodes := make([]stb.Node, atlas_size, context.temp_allocator)
    stb_rects: [dynamic]stb.Rect
    defer delete(stb_rects)

    stb.init_target(&stb_context, atlas_size, atlas_size, raw_data(stb_nodes[:]), atlas_size)

    for sprite, index in state.current_atlas.sprites {
        append(
            &stb_rects,
            stb.Rect{id = i32(index), w = stb.Coord(sprite.image.width), h = stb.Coord(sprite.image.height)},
        )
    }

    pack_result := stb.pack_rects(&stb_context, raw_data(stb_rects), i32(len(stb_rects)))

    if pack_result == 1 {
        rl.TraceLog(.ERROR, "[PACK] Did not pack all sprites!")
    }

    for rect in stb_rects {
        if !rect.was_packed {
            // TODO: Cleanup
            continue
        }

        state.current_atlas.sprites[rect.id].source.x = f32(rect.x)
        state.current_atlas.sprites[rect.id].source.y = f32(rect.y)
    }
}

@(private = "file")
DrawMainEditor :: proc(project: ^core.Project) {
    rl.BeginMode2D(state.camera)
    defer rl.EndMode2D()

    rl.DrawTextureV(project.background, {}, rl.WHITE)
    rl.DrawTextureV(state.current_atlas.texture, {}, rl.WHITE)

    // TODO: Work out how to properly use the scissor modes to minimise this
    if state.selected_sprite != nil {
        for sprite in state.current_atlas.sprites {
            if state.selected_sprite.name != sprite.name {
                rl.DrawRectangleRec(sprite.source, rl.Fade(rl.BLACK, 0.5))
            }
        }
    }
}

@(private = "file")
DrawEditorGui :: proc(project: ^core.Project) {
    rl.DrawTextEx(
        rl.GetFontDefault(),
        strings.clone_to_cstring(state.current_atlas.name, context.temp_allocator),
        rl.GetWorldToScreen2D({}, state.camera) + {0, -48},
        40,
        1,
        rl.WHITE,
    )

    if state.selected_sprite != nil {
        position: rl.Vector2 = {state.selected_sprite.source.x, state.selected_sprite.source.y}
        adjusted_position: rl.Vector2 = rl.GetWorldToScreen2D(position, state.camera)

        scaled_rect_size: rl.Vector2 =
            {state.selected_sprite.source.width, state.selected_sprite.source.height} * state.camera.zoom

        rl.DrawRectangleLinesEx(
            {adjusted_position.x, adjusted_position.y, scaled_rect_size.x, scaled_rect_size.y},
            1,
            rl.RED,
        )

        position_origin := rl.GetWorldToScreen2D(position + state.selected_sprite.origin, state.camera)
        rl.DrawCircleLinesV(position_origin, 4, rl.RED)

        if !rl.Vector2Equals(state.selected_sprite.origin, {}) || state.should_edit_origin {
            rl.DrawLineV(
                {adjusted_position.x, position_origin.y},
                {adjusted_position.x + scaled_rect_size.x, position_origin.y},
                rl.Fade(rl.RED, 0.5),
            )

            rl.DrawLineV(
                {position_origin.x, adjusted_position.y},
                {position_origin.x, adjusted_position.y + scaled_rect_size.y},
                rl.Fade(rl.RED, 0.5),
            )
        }
    }

    ctx := core.Begin()
    defer core.End()

    if mu.window(ctx, "editor_toolbar", {0, 0, rl.GetScreenWidth(), TOOLBAR_HEIGHT}, {.NO_RESIZE, .NO_TITLE}) {
        container := mu.get_current_container(ctx)
        container.rect.w = rl.GetScreenWidth()

        mu.layout_row(ctx, {64, 64, 96, 96})

        if .SUBMIT in mu.button(ctx, "Save") {
            state.save_project = true
        }

        if .SUBMIT in mu.button(ctx, "Export") {
            state.export_project = true
        }

        if .SUBMIT in mu.button(ctx, "Rename Atlas") {
            state.is_atlas_rename = true
        }

        if .SUBMIT in mu.button(ctx, "Rename Sprite") {
            if state.selected_sprite != nil {
                state.is_sprite_rename = true
            }
        }
    }

    if state.is_atlas_rename {
        mu.begin_window(ctx, "Rename Atlas", {128, 128, 256, 80}, {.NO_RESIZE, .NO_CLOSE})
        defer mu.end_window(ctx)
        @(static)
        length: int

        @(static)
        atlas_rename_buffer: [mu.MAX_TEXT_STORE]byte

        mu.layout_row(ctx, {-1})
        mu.textbox(ctx, atlas_rename_buffer[:], &length)

        if .SUBMIT in mu.button(ctx, "Submit") {
            should_close := true

            for atlas in project.atlas {
                if atlas.name == string(atlas_rename_buffer[:length]) {
                    should_close = false
                    break
                }
            }

            if should_close {
                delete(state.current_atlas.name)
                state.current_atlas.name = strings.clone_from_bytes(atlas_rename_buffer[:length])

                for &sprite in state.current_atlas.sprites {
                    delete(sprite.atlas)

                    sprite.atlas = strings.clone_from_bytes(atlas_rename_buffer[:length])
                }

                state.is_atlas_rename = false
                length = 0
            }
        }
    }

    if state.is_sprite_rename {
        mu.begin_window(ctx, "Rename Sprite", {128, 128, 256, 80}, {.NO_RESIZE, .NO_CLOSE})
        defer mu.end_window(ctx)
        @(static)
        length: int

        @(static)
        sprite_rename_buffer: [mu.MAX_TEXT_STORE]byte

        mu.layout_row(ctx, {-1})
        mu.textbox(ctx, sprite_rename_buffer[:], &length)

        if .SUBMIT in mu.button(ctx, "Submit") {
            should_close := true

            for sprite in state.current_atlas.sprites {
                if sprite.name == string(sprite_rename_buffer[:length]) {
                    should_close = false
                    break
                }
            }

            if should_close {
                delete(state.selected_sprite.name)
                state.selected_sprite.name = strings.clone_from_bytes(sprite_rename_buffer[:length])

                state.is_sprite_rename = false
                length = 0
            }
        }
    }
}
