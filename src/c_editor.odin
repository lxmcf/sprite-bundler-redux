package main

import "core:fmt"
import str "core:strings"

import rl "vendor:raylib"

Editor_Context :: struct {}

Import_Mode :: enum u8 {
    None,
    Texture,
    Font,
}

handle_file_drop :: proc(project: ^Project) {
    if !rl.IsFileDropped() {
        return
    }

    dropped_files := rl.LoadDroppedFiles()
    defer rl.UnloadDroppedFiles(dropped_files)

    for i in 0 ..< dropped_files.count {
        path := dropped_files.paths[i]

        extension := rl.GetFileExtension(path)
        filename, err := str.clone_from_cstring(path, context.temp_allocator)

        _ = err

        // TODO: Test all these formats, taken from https://github.com/raysan5/raylib/blob/master/FAQ.md#what-file-formats-are-supported-by-raylib
        switch rl.TextToLower(extension) {
        case ".ttf", ".otf":
            fmt.println("Got a font")

        case ".png", ".bmp", ".tga", ".jpg", ".gif", ".qoi", ".psd", ".dds", ".hdr", ".ktx", ".astc", ".pkm", ".pvr":
            file_import_image(filename, project)
        }
    }
}
