package screens

import "core:crypto"
import "core:encoding/uuid"
import "core:os"
import "core:slice"
import "core:strings"

import mu "vendor:microui"
import rl "vendor:raylib"

import "bundler:core"
import "bundler:util"

@(private = "file")
EditorState :: struct {
    camera:               rl.Camera2D,
    cursor:               rl.MouseCursor,

    // Selected elements
    current_atlas_index:  int,
    current_atlas:        ^core.Atlas, // NOTE: May not need a pointer here just yet
    selected_sprite:      ^core.Sprite,

    // UI controls
    save_project:         bool,
    export_project:       bool,
    create_new_atlas:     bool,
    delete_current_atlas: bool,
}

@(private = "file")
state: EditorState

// ====== PUBLIC ====== \\
InitEditor :: proc(project: ^core.Project) {
    state.camera.zoom = 0.5

    state.current_atlas = &project.atlas[0]
}

UnloadEditor :: proc() {}

UpdateEditor :: proc(project: ^core.Project) {
    HandleEditorActions(project)

    state.cursor = .DEFAULT

    UpdateCamera()

    HandleShortcuts(project)
    HandleDroppedFiles(project)

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

    if rl.IsMouseButtonReleased(.LEFT) && state.selected_sprite != nil {
        if !rl.CheckCollisionPointRec(mouse_position, state.selected_sprite.source) {
            state.selected_sprite = nil
        }
    }

    rl.SetMouseCursor(state.cursor)
}

DrawEditor :: proc(project: ^core.Project) {
    DrawMainEditor(project)
    // DrawEditorGui(project)
    DrawEditorGuiTest()
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
    if state.delete_current_atlas do core.DeleteAtlas(project, state.current_atlas_index)

    ResetEditorActions()
}

@(private = "file")
ResetEditorActions :: proc() {
    state.export_project = false
    state.save_project = false
    state.create_new_atlas = false
    state.delete_current_atlas = false
}

@(private = "file")
HandleShortcuts :: proc(project: ^core.Project) {
    // Centre camera
    if rl.IsKeyReleased(.Z) {
        screen: rl.Vector2 = {f32(rl.GetScreenWidth()), f32(rl.GetScreenHeight())}

        state.camera.offset = screen / 2
        state.camera.target = {f32(project.config.atlas_size), f32(project.config.atlas_size)} / 2

        state.camera.zoom = 0.5
    }

    if rl.IsKeyDown(.LEFT_CONTROL) {
        if rl.IsKeyPressed(.S) do state.save_project = true
        if rl.IsKeyPressed(.E) do state.export_project = true
        if rl.IsKeyPressed(.N) do state.create_new_atlas = true
        if rl.IsKeyPressed(.Y) do state.delete_current_atlas = true

        change_atlas := int(rl.IsKeyPressed(.RIGHT_BRACKET)) - int(rl.IsKeyPressed(.LEFT_BRACKET))
        if change_atlas != 0 {
            state.current_atlas_index = clamp(state.current_atlas_index + change_atlas, 0, len(project.atlas) - 1)
            state.current_atlas = &project.atlas[state.current_atlas_index]
        }

        when ODIN_DEBUG {
            // Import Image
            if rl.IsKeyPressed(.R) {
                core.ImportBundle(
                    util.CreatePath({project.directory, "export", "bundle.lspx"}, context.temp_allocator),
                )
            }
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
            rl.TraceLog(.ERROR, "FILE: Did not find any files to sort!")
        }
    }
}

@(private = "file")
MassWidthSort :: proc(a, b: core.Sprite) -> bool {
    mass_a := a.source.width * a.source.height
    mass_b := b.source.width * b.source.height

    if mass_a == mass_b {
        if a.source.width < b.source.width do return false
        if a.source.width > b.source.width do return true

        if a.source.height < b.source.height do return false
        if a.source.height > b.source.height do return true

        return false
    }

    return mass_a > mass_b
}

@(private = "file")
PackSprites :: proc(project: ^core.Project) {
    slice.stable_sort_by(state.current_atlas.sprites[:], MassWidthSort)

    valignment, texture_placed := f32(project.config.atlas_size), 0

    for sprite in state.current_atlas.sprites {
        if sprite.source.height < valignment do valignment = sprite.source.height
    }

    // NOTE: I have no idea why I need a pointer... From a pointer... It doesn't sort correctly otherwise
    for &sprite, index in state.current_atlas.sprites {
        times_looped := 0

        current_rectangle := &sprite.source

        for j := 0; j < texture_placed; j += 1 {
            for rl.CheckCollisionRecs(current_rectangle^, state.current_atlas.sprites[j].source) {
                current_rectangle.x += state.current_atlas.sprites[j].source.width

                within_x := int(current_rectangle.x + current_rectangle.width) <= project.config.atlas_size

                if !within_x {
                    current_rectangle.x = 0
                    current_rectangle.y += valignment

                    j = 0
                }
            }
        }
        rl.TraceLog(.DEBUG, "Sprite [%s] looped %d times", sprite.name, times_looped)

        within_y := int(current_rectangle.y + current_rectangle.height) <= project.config.atlas_size
        if !within_y {
            rl.TraceLog(.DEBUG, "DELETE: Deleting sprite[%d] %s", index, sprite.name)

            if project.config.copy_files {
                error := os.remove(sprite.file)

                rl.TraceLog(.DEBUG, "Delete error ID [%d]", error)
            }

            util.DeleteStrings(sprite.name, sprite.file, sprite.atlas)

            rl.UnloadImage(sprite.image)
            ordered_remove(&state.current_atlas.sprites, index)
        } else {
            texture_placed += 1
        }
    }

    rl.TraceLog(.DEBUG, "Sorted %d textures!", texture_placed)
}

@(private = "file")
DrawMainEditor :: proc(project: ^core.Project) {
    rl.BeginMode2D(state.camera)
    defer rl.EndMode2D()

    rl.DrawTextureV(project.background, {}, rl.WHITE)
    rl.DrawTextureV(state.current_atlas.texture, {}, rl.WHITE)

    for sprite in state.current_atlas.sprites {
        if state.selected_sprite != nil {
            if strings.compare(state.selected_sprite.name, sprite.name) != 0 {
                rl.DrawRectangleRec(sprite.source, rl.Fade(rl.BLACK, 0.5))
            }
        }
    }

    rl.DrawText(strings.clone_to_cstring(state.current_atlas.name, context.temp_allocator), 0, -80, 80, rl.WHITE)
}

// TEMP: May rewrite some of the needed raygui components to avoid so much casting
@(private = "file")
DrawEditorGui :: proc(project: ^core.Project) {
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

        if !rl.Vector2Equals(state.selected_sprite.origin, {}) {
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

    // Set Style
    rl.GuiSetStyle(.BUTTON, .TEXT_ALIGNMENT, i32(rl.GuiTextAlignment.TEXT_ALIGN_LEFT))

    rl.GuiEnableTooltip()
    rl.GuiPanel({0, 0, f32(rl.GetScreenWidth()), 32}, nil)

    rl.GuiSetTooltip("Save Project [CTRL + S]")
    if rl.GuiButton({4, 4, 68, 24}, "#2# Save") do state.save_project = true

    rl.GuiSetTooltip("Export Project [CTRL + E]")
    if rl.GuiButton({76, 4, 68, 24}, "#200# Export") do state.export_project = true

    anchor: rl.Vector2 = {f32(rl.GetScreenWidth()), 0}

    rl.GuiSetTooltip("Delete Current Atlas [CTRL + Y]")
    if rl.GuiButton({anchor.x - 72, 4, 68, 24}, "#143# Delete") do state.delete_current_atlas = true

    rl.GuiSetTooltip("Create New Atlas [CTRL + N]")
    if rl.GuiButton({anchor.x - 144, 4, 68, 24}, "#197# Create") do state.create_new_atlas = true

    current_atlas := i32(state.current_atlas_index)
    rl.GuiSetTooltip("Change Atlas [CTRL + ANGLE BRACKET]")
    rl.GuiSpinner(
        {anchor.x - 224, 4, 76, 24},
        "Current Atlas: ",
        &current_atlas,
        0,
        i32(len(project.atlas) - 1),
        false,
    )

    if current_atlas != i32(state.current_atlas_index) {
        state.current_atlas_index = int(current_atlas)

        state.current_atlas = &project.atlas[state.current_atlas_index]
        state.selected_sprite = nil
    }

    rl.GuiDisableTooltip()

    HandleEditorActions(project)
    ResetEditorActions()
}

@(private = "file")
DrawEditorGuiTest :: proc() {
    ctx := core.Begin()

    if mu.window(ctx, "editor_toolbar", {0, 0, rl.GetScreenWidth(), 32}, {.NO_RESIZE, .NO_TITLE}) {
        mu.layout_width(ctx, rl.GetScreenWidth())
        mu.layout_row(ctx, {72, 72})

        if .SUBMIT in mu.button(ctx, "Save") {
            state.save_project = true
        }

        if .SUBMIT in mu.button(ctx, "Export") {
            state.export_project = true
        }
    }

    core.End()
}
