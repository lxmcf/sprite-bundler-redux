package main

import "core:encoding/json"
import "core:fmt"
import "core:os"
import fp "core:path/filepath"
import str "core:strings"

Font :: struct {
    id:         string,
    size:       i32,
    padding:    i32,
    rectangles: [dynamic]Rectangle,
    glyphs:     [dynamic]GlyphInfo,
}

save_font :: proc(project: Project, font: Font) {
    font_file := str.concatenate({project.working_directory, PROJECT_DIR_FONTS, fp.SEPARATOR_STRING, font.id, ".fd"}, context.temp_allocator)

    options: json.Marshal_Options = {
        use_spaces = true,
        pretty     = true,
        spaces     = 4,
    }

    if font_data, error := json.marshal(font, options, context.temp_allocator); error == nil {
        os.write_entire_file(font_file, font_data)
    } else {
        fmt.eprintln("ERROR: FONT: Failed to serialise:", error)
    }
}

delete_font :: proc(font: ^Font) {
    delete(font.rectangles)
    delete(font.glyphs)
}
