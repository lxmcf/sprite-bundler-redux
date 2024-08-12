// CREDIT: https://gist.github.com/keenanwoodall/b6f7ecf6346ba3be4842c7d9fd1f372d

package myui

import "core:unicode/utf8"

import mu "vendor:microui"
import rl "vendor:raylib"

@(private)
Vector2i :: [2]i32

@(private)
Colour :: [4]u8

@(private)
global_context: mu.Context

@(private)
global_altas: rl.Texture

Init :: proc() {
    mu.init(&global_context)
    global_context.text_width = mu.default_atlas_text_width
    global_context.text_height = mu.default_atlas_text_height

    pixels := make([]Colour, mu.DEFAULT_ATLAS_WIDTH * mu.DEFAULT_ATLAS_HEIGHT)
    defer delete(pixels)

    for alpha, index in mu.default_atlas_alpha {
        pixels[index] = {255, 255, 255, alpha}
    }

    image := rl.Image {
        data    = raw_data(pixels),
        width   = mu.DEFAULT_ATLAS_WIDTH,
        height  = mu.DEFAULT_ATLAS_HEIGHT,
        format  = .UNCOMPRESSED_R8G8B8A8,
        mipmaps = 1,
    }

    global_altas = rl.LoadTextureFromImage(image)
}

Unload :: proc() {
    rl.UnloadTexture(global_altas)
}

Begin :: proc() -> ^mu.Context {
    HandleTextInput()
    HandleMouseInput()
    HandleKeyboardInput()

    mu.begin(&global_context)

    return &global_context
}

End :: proc() {
    mu.end(&global_context)

    command: ^mu.Command
    for command_variant in mu.next_command_iterator(&global_context, &command) {
        #partial switch cmd in command_variant {
        case ^mu.Command_Rect:
            rl.DrawRectangle(
                cmd.rect.x,
                cmd.rect.y,
                cmd.rect.w,
                cmd.rect.h,
                {cmd.color.r, cmd.color.g, cmd.color.b, cmd.color.a},
            )

        case ^mu.Command_Text:
            position: Vector2i = {cmd.pos.x, cmd.pos.y}

            for char in cmd.str {
                if char & 0xc0 != 0x80 {
                    rune := min(int(char), 127)
                    rect := mu.default_atlas[mu.DEFAULT_ATLAS_FONT + rune]

                    DrawFromAtlas(
                        rect,
                        {f32(position.x), f32(position.y)},
                        {cmd.color.r, cmd.color.g, cmd.color.b, cmd.color.a},
                    )

                    position.x += rect.w
                }
            }

        case ^mu.Command_Icon:
            rect := mu.default_atlas[cmd.id]
            position: Vector2i = {cmd.rect.x + (cmd.rect.w - rect.w) / 2, cmd.rect.y + (cmd.rect.h - rect.h) / 2}
            DrawFromAtlas(
                rect,
                {f32(position.x), f32(position.y)},
                {cmd.color.r, cmd.color.g, cmd.color.b, cmd.color.a},
            )

        case ^mu.Command_Clip:
            rl.EndScissorMode()
            rl.BeginScissorMode(cmd.rect.x, rl.GetScreenHeight() - (cmd.rect.y + cmd.rect.h), cmd.rect.w, cmd.rect.h)

        case ^mu.Command_Jump:
            unreachable()
        }
    }
}

@(private)
HandleTextInput :: proc() {
    input := make([]byte, 512, context.temp_allocator)
    offset: int

    for offset < len(input) {
        rune := rl.GetCharPressed()
        if rune == 0 do break

        bytes, count := utf8.encode_rune(rune)

        copy(input[offset:], bytes[:count])
        offset += count
    }

    mu.input_text(&global_context, string(input[:offset]))
}

@(private)
HandleMouseInput :: proc() {
    mouse_position: Vector2i = {rl.GetMouseX(), rl.GetMouseY()}
    mouse_scroll := rl.GetMouseWheelMoveV() * 5

    mu.input_mouse_move(&global_context, mouse_position.x, mouse_position.y)
    mu.input_scroll(&global_context, i32(mouse_scroll.x) * 5, i32(mouse_scroll.y) * -30)

    ButtonMap :: struct {
        rl: rl.MouseButton,
        mu: mu.Mouse,
    }

    button_mappings := [?]ButtonMap{{.LEFT, .LEFT}, {.RIGHT, .RIGHT}, {.MIDDLE, .MIDDLE}}

    for button in button_mappings {
        if rl.IsMouseButtonPressed(button.rl) {
            mu.input_mouse_down(&global_context, mouse_position.x, mouse_position.y, button.mu)
        } else if rl.IsMouseButtonReleased(button.rl) {
            mu.input_mouse_up(&global_context, mouse_position.x, mouse_position.y, button.mu)
        }
    }
}

@(private)
HandleKeyboardInput :: proc() {
    KeyMap :: struct {
        rl: rl.KeyboardKey,
        mu: mu.Key,
    }

    key_mappings := [?]KeyMap {
        {.LEFT_SHIFT, .SHIFT},
        {.RIGHT_SHIFT, .SHIFT},
        {.LEFT_CONTROL, .CTRL},
        {.RIGHT_CONTROL, .CTRL},
        {.LEFT_ALT, .ALT},
        {.RIGHT_ALT, .ALT},
        {.ENTER, .RETURN},
        {.KP_ENTER, .RETURN},
        {.BACKSPACE, .BACKSPACE},
    }

    for key in key_mappings {
        if rl.IsKeyPressed(key.rl) {
            mu.input_key_down(&global_context, key.mu)
        } else if rl.IsKeyReleased(key.rl) {
            mu.input_key_up(&global_context, key.mu)
        }
    }
}

@(private)
DrawFromAtlas :: proc(source: mu.Rect, position: rl.Vector2, colour: rl.Color) {
    global_atlas_source := rl.Rectangle{f32(source.x), f32(source.y), f32(source.w), f32(source.h)}

    rl.DrawTextureRec(global_altas, global_atlas_source, position, colour)
}
