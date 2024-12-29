package main

import "core:encoding/json"
import "core:fmt"
import "core:os"

Config :: struct {
    auto_centre_origin:              bool, // Centre sprite origin
    trim_whitespace:                 bool, // Trim whitespace on image import
    auto_generate_sprite:            bool, // Generate a sprite in texture import
    font_generate_character_sprites: bool, // Generate a sprite for each character (Not recommended)
    font_generate_sprite:            bool, // Generates a sprite for the font texture
}

load_default_config :: proc() -> Config {
    config: Config = {
        auto_generate_sprite = true,
    }

    return config
}

load_config :: proc(filename: string) -> Config {
    config: Config

    if os.is_file(CONFIG_FILENAME) {
        if config_data, ok := os.read_entire_file(CONFIG_FILENAME, context.temp_allocator); ok {
            json_err := json.unmarshal(config_data, &config)

            if json_err != nil {
                fmt.eprintfln("ERROR: CONFIG: Failed to deserialise config [%v]", json_err)
            }
        }
    } else {
        config = load_default_config()
    }

    return config
}

save_config :: proc(config: Config, filename: string) -> (ok: bool) {
    options: json.Marshal_Options = {
        use_spaces = true,
        pretty     = true,
        spaces     = 4,
    }

    if config_data, error := json.marshal(config, options, context.temp_allocator); error == nil {
        os.write_entire_file(filename, config_data)
        ok = true
    } else {
        fmt.eprintln("ERROR: PROJECT: Failed to serialise:", error)
    }

    return
}
