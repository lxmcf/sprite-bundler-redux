// FIXME: This really does not need to be 400+ lines...
package screens

import "core:crypto"
import "core:encoding/uuid"
import "core:math"
import "core:os"
import "core:path/filepath"
import "core:strings"

// import mu "vendor:microui"
import rl "vendor:raylib"
import stb "vendor:stb/rect_pack"

import "bundler:core"

@(private = "file")
EditorState :: struct {
    camera:                rl.Camera2D,
    cursor:                rl.MouseCursor,

    // Selected elements
    current_atlas_index:   int,
    current_atlas:         ^core.Atlas,
    selected_sprite:       ^core.Sprite,
    selected_sprite_index: int,

    // Buffers
    is_dialog_open:        bool,
    is_atlas_rename:       bool,
    is_sprite_rename:      bool,
    atlas_name_buffer:     [64]byte,
    sprite_name_buffer:    [64]byte,

    // Editors
    should_edit_origin:    bool,

    // UI controls
    save_project:          bool,
    export_project:        bool,
    create_new_atlas:      bool,
    delete_current_atlas:  bool,
    delete_current_sprite: bool,
}

@(private = "file")
state: EditorState

TOOLBAR_HEIGHT :: 32

InitEditor :: proc(project: ^core.Project) {
    state.camera.zoom = 0.5

    state.current_atlas = &project.atlas[0]
    state.selected_sprite = nil
    state.selected_sprite_index = -1
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
    for &sprite, index in state.current_atlas.sprites {
        if rl.CheckCollisionPointRec(mouse_position, sprite.source) {
            state.cursor = .POINTING_HAND

            if rl.IsMouseButtonReleased(.LEFT) {
                state.selected_sprite = &sprite
                state.selected_sprite_index = index
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
                    state.selected_sprite_index = -1
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

@(private = "file")
UpdateCamera :: proc() {
    if state.is_dialog_open do return

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

// TODO: Move to an event queue
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

        state.current_atlas_index = clamp(state.current_atlas_index, 0, len(project.atlas) - 1)
    }

    if state.delete_current_sprite {
        core.DeleteSprite(project, state.selected_sprite)

        unordered_remove(&state.current_atlas.sprites, state.selected_sprite_index)

        PackSprites(project)
        core.GenerateAtlas(state.current_atlas)

        state.selected_sprite = nil
    }

    state.export_project = false
    state.save_project = false
    state.create_new_atlas = false
    state.delete_current_atlas = false
    state.delete_current_sprite = false
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

        if rl.IsKeyPressed(.Y) {
            if state.selected_sprite != nil {
                state.delete_current_sprite = true
            } else {
                state.delete_current_atlas = true
            }
        }

        if rl.IsKeyPressed(.R) {
            if state.selected_sprite != nil {
                for i in 0 ..< len(state.selected_sprite.name) do state.atlas_name_buffer[i] = state.selected_sprite.name[i]
                state.is_sprite_rename = true
            } else {
                for i in 0 ..< len(state.current_atlas.name) do state.atlas_name_buffer[i] = state.current_atlas.name[i]
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
                    context.random_generator = crypto.random_generator()

                    id := uuid.generate_v7_basic()
                    filename := strings.concatenate({uuid.to_string(id, context.temp_allocator), ".png"}, context.temp_allocator)

                    for os.is_file(filename) {
                        id = uuid.generate_v7_basic()
                        filename = strings.concatenate({uuid.to_string(id, context.temp_allocator), ".png"}, context.temp_allocator)
                    }

                    path = strings.clone_to_cstring(filename, context.temp_allocator)
                    export_path := strings.concatenate({project.working_directory, project.config.assets_dir, filepath.SEPARATOR_STRING, filename}, context.temp_allocator)

                    rl.ExportImage(image, strings.clone_to_cstring(export_path, context.temp_allocator))
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
        append(&stb_rects, stb.Rect{id = i32(index), w = stb.Coord(sprite.image.width), h = stb.Coord(sprite.image.height)})
    }

    pack_result := stb.pack_rects(&stb_context, raw_data(stb_rects), i32(len(stb_rects)))

    if pack_result != 1 {
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

    if state.selected_sprite != nil {
        rl.DrawRectangle(0, 0, i32(project.config.atlas_size), i32(project.config.atlas_size), rl.Fade(rl.BLACK, 0.5))
        rl.DrawTextureRec(project.background, state.selected_sprite.source, {state.selected_sprite.source.x, state.selected_sprite.source.y}, rl.WHITE)

        rl.DrawTextureRec(state.current_atlas.texture, state.selected_sprite.source, {state.selected_sprite.source.x, state.selected_sprite.source.y}, rl.WHITE)
    }
}

@(private = "file")
DrawEditorGui :: proc(project: ^core.Project) {
    should_regenerate_atlas: bool
    rl.DrawTextEx(rl.GetFontDefault(), strings.clone_to_cstring(state.current_atlas.name, context.temp_allocator), rl.GetWorldToScreen2D({}, state.camera) + {0, -48}, 40, 1, rl.WHITE)

    if state.selected_sprite != nil {
        position: rl.Vector2 = {state.selected_sprite.source.x, state.selected_sprite.source.y}
        adjusted_position: rl.Vector2 = rl.GetWorldToScreen2D(position, state.camera)

        scaled_rect_size: rl.Vector2 = {state.selected_sprite.source.width, state.selected_sprite.source.height} * state.camera.zoom

        rl.DrawRectangleLinesEx({adjusted_position.x, adjusted_position.y, scaled_rect_size.x, scaled_rect_size.y}, 1, rl.RED)

        position_origin := rl.GetWorldToScreen2D(position + state.selected_sprite.origin, state.camera)
        rl.DrawCircleLinesV(position_origin, 4, rl.RED)

        if !rl.Vector2Equals(state.selected_sprite.origin, {}) || state.should_edit_origin {
            rl.DrawLineV({adjusted_position.x, position_origin.y}, {adjusted_position.x + scaled_rect_size.x, position_origin.y}, rl.Fade(rl.RED, 0.5))
            rl.DrawLineV({position_origin.x, adjusted_position.y}, {position_origin.x, adjusted_position.y + scaled_rect_size.y}, rl.Fade(rl.RED, 0.5))
        }

        sprite_name := strings.clone_to_cstring(state.selected_sprite.name, context.temp_allocator)

        position += {0, state.selected_sprite.source.height}
        text_position := rl.GetWorldToScreen2D(position, state.camera)
        text_size := rl.MeasureTextEx(rl.GetFontDefault(), sprite_name, 30, 1) + 4

        text_size.x = max(text_size.x, state.selected_sprite.source.width * state.camera.zoom)

        rl.DrawRectangleV(text_position, text_size, rl.Fade(rl.BLACK, 0.5))
        rl.DrawTextEx(rl.GetFontDefault(), sprite_name, text_position + 2, 30, 1, rl.WHITE)
    }

    rl.GuiEnableTooltip()
    rl.GuiPanel({0, 0, f32(rl.GetRenderWidth()), 32}, nil)

    rl.GuiSetTooltip("Save Project [CTRL + S]")
    if rl.GuiButton({4, 4, 24, 24}, "#2#") do state.save_project = true

    rl.GuiSetTooltip("Export Project [CTRL + E]")
    if rl.GuiButton({32, 4, 24, 24}, "#7#") do state.export_project = true

    if state.selected_sprite != nil {
        rl.GuiSetTooltip("Rename Sprite [CTRL + R]")
        if rl.GuiButton({60, 4, 24, 24}, "#30#") {
            for i in 0 ..< len(state.selected_sprite.name) do state.sprite_name_buffer[i] = state.selected_sprite.name[i]
            state.is_sprite_rename = true
        }

        rl.GuiSetTooltip("Set Origin Point [V]")
        if rl.GuiButton({88, 4, 24, 24}, "#50#") do state.should_edit_origin = true

        rl.GuiSetTooltip("Rotate Sprite 90 Degrees")
        if rl.GuiButton({116, 4, 24, 24}, "#76#") {
            rl.ImageRotateCW(&state.selected_sprite.image)
            state.selected_sprite.source.width = f32(state.selected_sprite.image.width)
            state.selected_sprite.source.height = f32(state.selected_sprite.image.height)

            // TODO: Rotate origin point
            state.selected_sprite.origin = {}
            should_regenerate_atlas = true
        }

        rl.GuiSetTooltip("Flip Sprite Horizontally")
        if rl.GuiButton({144, 4, 24, 24}, "#40#") {
            rl.ImageFlipHorizontal(&state.selected_sprite.image)

            should_regenerate_atlas = true
        }

        rl.GuiSetTooltip("Flip Sprite Vertically")
        if rl.GuiButton({172, 4, 24, 24}, "#41#") {
            rl.ImageFlipVertical(&state.selected_sprite.image)

            should_regenerate_atlas = true
        }
    } else {
        rl.GuiSetTooltip("Rename Atlas [CTRL + R]")
        if rl.GuiButton({60, 4, 24, 24}, "#30#") {
            for i in 0 ..< len(state.current_atlas.name) do state.atlas_name_buffer[i] = state.current_atlas.name[i]
            state.is_atlas_rename = true
        }
    }

    rl.GuiDisableTooltip()

    if state.is_atlas_rename {
        @(static)
        anchor := rl.Vector2{172, 36}

        if rl.GuiWindowBox({anchor.x, anchor.y, 256, 80}, "Rename Atlas") == 1 do state.is_atlas_rename = false

        @(static)
        edit: bool

        // NOTE: WTF is this?
        if rl.GuiTextBox({anchor.x + 4, anchor.y + 28, 248, 20}, cstring(rawptr(&state.atlas_name_buffer)), 64, edit) do edit = !edit

        rl.GuiEnableTooltip()

        rl.GuiSetTooltip("Submit rename [ENTER]")
        if rl.GuiButton({anchor.x + 4, anchor.y + 52, 122, 24}, "#112# Submit") || rl.IsKeyPressed(.ENTER) {
            temp_cstring := cstring(raw_data(state.atlas_name_buffer[:]))

            delete(state.current_atlas.name)
            state.current_atlas.name = strings.clone_from_cstring_bounded(temp_cstring, len(temp_cstring))

            edit = false
            state.is_atlas_rename = false

            for i in 0 ..< len(temp_cstring) do state.atlas_name_buffer[i] = 0
        }

        rl.GuiSetTooltip("Cancel rename [ESCAPE]")
        if rl.GuiButton({anchor.x + 130, anchor.y + 52, 122, 24}, "#113# Cancel") || rl.IsKeyPressed(.ESCAPE) do state.is_atlas_rename = false
        rl.GuiDisableTooltip()
    }

    if state.is_sprite_rename {
        @(static)
        anchor := rl.Vector2{172, 36}

        if rl.GuiWindowBox({anchor.x, anchor.y, 256, 80}, "Rename Sprite") == 1 do state.is_sprite_rename = false

        @(static)
        edit: bool

        // NOTE: WTF is this?
        if rl.GuiTextBox({anchor.x + 4, anchor.y + 28, 248, 20}, cstring(rawptr(&state.sprite_name_buffer)), 64, edit) do edit = !edit

        rl.GuiEnableTooltip()

        rl.GuiSetTooltip("Submit rename [ENTER]")
        if rl.GuiButton({anchor.x + 4, anchor.y + 52, 122, 24}, "#112# Submit") || rl.IsKeyPressed(.ENTER) {
            temp_cstring := cstring(raw_data(state.sprite_name_buffer[:]))

            delete(state.selected_sprite.name)
            state.selected_sprite.name = strings.clone_from_cstring_bounded(temp_cstring, len(temp_cstring))

            edit = false
            state.is_sprite_rename = false

            for i in 0 ..< len(temp_cstring) do state.sprite_name_buffer[i] = 0
        }

        rl.GuiSetTooltip("Cancel rename [ESCAPE]")
        if rl.GuiButton({anchor.x + 130, anchor.y + 52, 122, 24}, "#113# Cancel") || rl.IsKeyPressed(.ESCAPE) do state.is_sprite_rename = false
        rl.GuiDisableTooltip()
    }

    if should_regenerate_atlas {
        PackSprites(project)
        core.GenerateAtlas(state.current_atlas)
    }
}
