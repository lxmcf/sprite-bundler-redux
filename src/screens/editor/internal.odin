package editor

import "core:crypto"
import "core:encoding/uuid"
import "core:os"
import "core:path/filepath"
import "core:strings"

import rl "vendor:raylib"
import stb "vendor:stb/rect_pack"

import "../../common"

TOOLBAR_HEIGHT :: 32

Editor_Context :: struct {
    camera:                rl.Camera2D,
    cursor:                rl.MouseCursor,

    // Selected elements
    current_atlas_index:   int,
    current_atlas:         ^common.Atlas,
    selected_sprite:       ^common.Sprite,
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

update_camera :: proc() {
    if ctx.is_dialog_open {
        return
    }

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

handle_editor_actions :: proc(project: ^common.Project) {
    if ctx.save_project {
        common.write_project(project)
    }

    if ctx.export_project {
        common.export_bundle(project^)
    }

    if ctx.create_new_atlas {
        common.create_new_atlas(project, "Blank Atlas")
    }

    if ctx.delete_current_atlas {
        common.delete_atlas(project, ctx.current_atlas_index)

        if len(project.atlas) == 0 {
            common.create_new_atlas(project, "Blank Atlas")
        }

        ctx.current_atlas_index = clamp(ctx.current_atlas_index, 0, len(project.atlas) - 1)
    }

    if ctx.delete_current_sprite {
        common.delete_sprite(project, ctx.selected_sprite)

        unordered_remove(&ctx.current_atlas.sprites, ctx.selected_sprite_index)

        pack_sprites(project)
        common.generate_atlas(ctx.current_atlas)

        ctx.selected_sprite = nil
    }

    ctx.export_project = false
    ctx.save_project = false
    ctx.create_new_atlas = false
    ctx.delete_current_atlas = false
    ctx.delete_current_sprite = false
}

handle_shortcuts :: proc(project: ^common.Project) {
    // Centre camera
    if rl.IsKeyReleased(.Z) && !ctx.should_edit_origin {
        screen: rl.Vector2 = {f32(rl.GetScreenWidth()), f32(rl.GetScreenHeight())}

        ctx.camera.offset = screen / 2
        ctx.camera.target = {f32(project.config.atlas_size), f32(project.config.atlas_size)} / 2

        ctx.camera.zoom = 0.5
    }

    // Centre sprite origin
    if rl.IsKeyReleased(.Z) && ctx.should_edit_origin {
        ctx.selected_sprite.origin = {ctx.selected_sprite.source.width, ctx.selected_sprite.source.height} / 2

        ctx.should_edit_origin = false
    }

    if rl.IsKeyPressed(.V) {
        ctx.should_edit_origin = !ctx.should_edit_origin
    }

    if rl.IsKeyDown(.LEFT_CONTROL) {
        if rl.IsKeyPressed(.S) {
            ctx.save_project = true
        }

        if rl.IsKeyPressed(.E) {
            ctx.export_project = true
        }

        if rl.IsKeyPressed(.N) {
            ctx.create_new_atlas = true
        }

        if rl.IsKeyPressed(.Y) {
            if ctx.selected_sprite != nil {
                ctx.delete_current_sprite = true
            } else {
                ctx.delete_current_atlas = true
            }
        }

        if rl.IsKeyPressed(.R) {
            if ctx.selected_sprite != nil {
                for i in 0 ..< len(ctx.selected_sprite.name) {
                    ctx.atlas_name_buffer[i] = ctx.selected_sprite.name[i]
                }

                ctx.is_sprite_rename = true
            } else {
                for i in 0 ..< len(ctx.current_atlas.name) {
                    ctx.atlas_name_buffer[i] = ctx.current_atlas.name[i]
                }

                ctx.is_atlas_rename = true
            }
        }

        change_atlas := int(rl.IsKeyPressed(.RIGHT_BRACKET)) - int(rl.IsKeyPressed(.LEFT_BRACKET))
        if change_atlas != 0 {
            ctx.current_atlas_index = clamp(ctx.current_atlas_index + change_atlas, 0, len(project.atlas) - 1)
            ctx.current_atlas = &project.atlas[ctx.current_atlas_index]
        }
    }
}

handle_dropped_files :: proc(project: ^common.Project) {
    if rl.IsFileDropped() {
        files := rl.LoadDroppedFiles()
        defer rl.UnloadDroppedFiles(files)

        if files.count > 0 {
            for i in 0 ..< files.count {
                path := files.paths[i]

                if !rl.IsFileExtension(path, ".png") {
                    continue
                }

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

                sprite: common.Sprite = {
                    name   = name,
                    file   = strings.clone_from_cstring(path),
                    atlas  = strings.clone(ctx.current_atlas.name),
                    image  = image,
                    source = {0, 0, f32(image.width), f32(image.height)},
                }

                if project.config.auto_center {
                    sprite.origin = {sprite.source.width, sprite.source.height} / 2
                }

                append(&ctx.current_atlas.sprites, sprite)
            }

            pack_sprites(project)

            common.generate_atlas(ctx.current_atlas)
        } else {
            rl.TraceLog(.ERROR, "[FILE] Did not find any files to sort!")
        }
    }
}

pack_sprites :: proc(project: ^common.Project) {
    atlas_size := i32(project.config.atlas_size)

    stb_context: stb.Context
    stb_nodes := make([]stb.Node, atlas_size, context.temp_allocator)
    stb_rects: [dynamic]stb.Rect
    defer delete(stb_rects)

    stb.init_target(&stb_context, atlas_size, atlas_size, raw_data(stb_nodes[:]), atlas_size)

    for sprite, index in ctx.current_atlas.sprites {
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

        ctx.current_atlas.sprites[rect.id].source.x = f32(rect.x)
        ctx.current_atlas.sprites[rect.id].source.y = f32(rect.y)
    }
}

draw_main_editor :: proc(project: ^common.Project) {
    rl.BeginMode2D(ctx.camera)
    defer rl.EndMode2D()

    rl.DrawTextureV(project.background, {}, rl.WHITE)
    rl.DrawTextureV(ctx.current_atlas.texture, {}, rl.WHITE)

    if ctx.selected_sprite != nil {
        rl.DrawRectangle(0, 0, i32(project.config.atlas_size), i32(project.config.atlas_size), rl.Fade(rl.BLACK, 0.5))
        rl.DrawTextureRec(project.background, ctx.selected_sprite.source, {ctx.selected_sprite.source.x, ctx.selected_sprite.source.y}, rl.WHITE)

        rl.DrawTextureRec(ctx.current_atlas.texture, ctx.selected_sprite.source, {ctx.selected_sprite.source.x, ctx.selected_sprite.source.y}, rl.WHITE)
    }
}

draw_editor_gui :: proc(project: ^common.Project) {
    should_regenerate_atlas: bool
    rl.DrawTextEx(rl.GetFontDefault(), strings.clone_to_cstring(ctx.current_atlas.name, context.temp_allocator), rl.GetWorldToScreen2D({}, ctx.camera) + {0, -48}, 40, 1, rl.WHITE)

    if ctx.selected_sprite != nil {
        position: rl.Vector2 = {ctx.selected_sprite.source.x, ctx.selected_sprite.source.y}
        adjusted_position: rl.Vector2 = rl.GetWorldToScreen2D(position, ctx.camera)

        scaled_rect_size: rl.Vector2 = {ctx.selected_sprite.source.width, ctx.selected_sprite.source.height} * ctx.camera.zoom

        rl.DrawRectangleLinesEx({adjusted_position.x, adjusted_position.y, scaled_rect_size.x, scaled_rect_size.y}, 1, rl.RED)

        position_origin := rl.GetWorldToScreen2D(position + ctx.selected_sprite.origin, ctx.camera)
        rl.DrawCircleLinesV(position_origin, 4, rl.RED)

        if !rl.Vector2Equals(ctx.selected_sprite.origin, {}) || ctx.should_edit_origin {
            rl.DrawLineV({adjusted_position.x, position_origin.y}, {adjusted_position.x + scaled_rect_size.x, position_origin.y}, rl.Fade(rl.RED, 0.5))
            rl.DrawLineV({position_origin.x, adjusted_position.y}, {position_origin.x, adjusted_position.y + scaled_rect_size.y}, rl.Fade(rl.RED, 0.5))
        }

        sprite_name := strings.clone_to_cstring(ctx.selected_sprite.name, context.temp_allocator)

        position += {0, ctx.selected_sprite.source.height}
        text_position := rl.GetWorldToScreen2D(position, ctx.camera)
        text_size := rl.MeasureTextEx(rl.GetFontDefault(), sprite_name, 30, 1) + 4

        text_size.x = max(text_size.x, ctx.selected_sprite.source.width * ctx.camera.zoom)

        rl.DrawRectangleV(text_position, text_size, rl.Fade(rl.BLACK, 0.5))
        rl.DrawTextEx(rl.GetFontDefault(), sprite_name, text_position + 2, 30, 1, rl.WHITE)
    }

    rl.GuiEnableTooltip()
    rl.GuiPanel({0, 0, f32(rl.GetRenderWidth()), 32}, nil)

    rl.GuiSetTooltip("Save Project [CTRL + S]")
    if rl.GuiButton({4, 4, 24, 24}, "#2#") {
        ctx.save_project = true
    }

    rl.GuiSetTooltip("Export Project [CTRL + E]")
    if rl.GuiButton({32, 4, 24, 24}, "#7#") {
        ctx.export_project = true
    }

    if ctx.selected_sprite != nil {
        rl.GuiSetTooltip("Rename Sprite [CTRL + R]")
        if rl.GuiButton({60, 4, 24, 24}, "#30#") {
            for i in 0 ..< len(ctx.selected_sprite.name) {
                ctx.sprite_name_buffer[i] = ctx.selected_sprite.name[i]
            }

            ctx.is_sprite_rename = true
        }

        rl.GuiSetTooltip("Set Origin Point [V]")
        if rl.GuiButton({88, 4, 24, 24}, "#50#") {
            ctx.should_edit_origin = true
        }

        rl.GuiSetTooltip("Rotate Sprite 90 Degrees")
        if rl.GuiButton({116, 4, 24, 24}, "#76#") {
            rl.ImageRotateCW(&ctx.selected_sprite.image)
            ctx.selected_sprite.source.width = f32(ctx.selected_sprite.image.width)
            ctx.selected_sprite.source.height = f32(ctx.selected_sprite.image.height)

            // TODO: Rotate origin point
            ctx.selected_sprite.origin = {}
            should_regenerate_atlas = true
        }

        rl.GuiSetTooltip("Flip Sprite Horizontally")
        if rl.GuiButton({144, 4, 24, 24}, "#40#") {
            rl.ImageFlipHorizontal(&ctx.selected_sprite.image)

            should_regenerate_atlas = true
        }

        rl.GuiSetTooltip("Flip Sprite Vertically")
        if rl.GuiButton({172, 4, 24, 24}, "#41#") {
            rl.ImageFlipVertical(&ctx.selected_sprite.image)

            should_regenerate_atlas = true
        }
    } else {
        rl.GuiSetTooltip("Rename Atlas [CTRL + R]")
        if rl.GuiButton({60, 4, 24, 24}, "#30#") {
            for i in 0 ..< len(ctx.current_atlas.name) {
                ctx.atlas_name_buffer[i] = ctx.current_atlas.name[i]
            }

            ctx.is_atlas_rename = true
        }
    }

    rl.GuiDisableTooltip()

    if ctx.is_atlas_rename {
        @(static)
        anchor := rl.Vector2{172, 36}

        if rl.GuiWindowBox({anchor.x, anchor.y, 256, 80}, "Rename Atlas") == 1 {
            ctx.is_atlas_rename = false
        }

        @(static)
        edit: bool

        // NOTE: WTF is this?
        if rl.GuiTextBox({anchor.x + 4, anchor.y + 28, 248, 20}, cstring(rawptr(&ctx.atlas_name_buffer)), 64, edit) {
            edit = !edit
        }

        rl.GuiEnableTooltip()

        rl.GuiSetTooltip("Submit rename [ENTER]")
        if rl.GuiButton({anchor.x + 4, anchor.y + 52, 122, 24}, "#112# Submit") || rl.IsKeyPressed(.ENTER) {
            temp_cstring := cstring(raw_data(ctx.atlas_name_buffer[:]))

            delete(ctx.current_atlas.name)
            ctx.current_atlas.name = strings.clone_from_cstring_bounded(temp_cstring, len(temp_cstring))

            edit = false
            ctx.is_atlas_rename = false

            for i in 0 ..< len(temp_cstring) {
                ctx.atlas_name_buffer[i] = 0
            }
        }

        rl.GuiSetTooltip("Cancel rename [ESCAPE]")
        if rl.GuiButton({anchor.x + 130, anchor.y + 52, 122, 24}, "#113# Cancel") || rl.IsKeyPressed(.ESCAPE) {
            ctx.is_atlas_rename = false
        }

        rl.GuiDisableTooltip()
    }

    if ctx.is_sprite_rename {
        @(static)
        anchor := rl.Vector2{172, 36}

        if rl.GuiWindowBox({anchor.x, anchor.y, 256, 80}, "Rename Sprite") == 1 {
            ctx.is_sprite_rename = false
        }

        @(static)
        edit: bool

        // NOTE: WTF is this?
        if rl.GuiTextBox({anchor.x + 4, anchor.y + 28, 248, 20}, cstring(rawptr(&ctx.sprite_name_buffer)), 64, edit) {
            edit = !edit
        }

        rl.GuiEnableTooltip()

        rl.GuiSetTooltip("Submit rename [ENTER]")
        if rl.GuiButton({anchor.x + 4, anchor.y + 52, 122, 24}, "#112# Submit") || rl.IsKeyPressed(.ENTER) {
            temp_cstring := cstring(raw_data(ctx.sprite_name_buffer[:]))

            delete(ctx.selected_sprite.name)
            ctx.selected_sprite.name = strings.clone_from_cstring_bounded(temp_cstring, len(temp_cstring))

            edit = false
            ctx.is_sprite_rename = false

            for i in 0 ..< len(temp_cstring) {
                ctx.sprite_name_buffer[i] = 0
            }
        }

        rl.GuiSetTooltip("Cancel rename [ESCAPE]")
        if rl.GuiButton({anchor.x + 130, anchor.y + 52, 122, 24}, "#113# Cancel") || rl.IsKeyPressed(.ESCAPE) {
            ctx.is_sprite_rename = false
        }
        rl.GuiDisableTooltip()
    }

    if should_regenerate_atlas {
        pack_sprites(project)
        common.generate_atlas(ctx.current_atlas)
    }
}
