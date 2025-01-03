package main

import "core:os"

export_bundle :: proc(project: Project, config: Config) {

}

@(private)
align_file :: proc(handle: os.Handle, alignment: i64) -> i64 {
    position, _ := os.seek(handle, 0, os.SEEK_CUR)
    offset := position % alignment

    if offset > 0 {
        result, _ := os.seek(handle, alignment - offset, os.SEEK_CUR)
        return result
    } else {
        return 0
    }
}

@(private)
pad_file :: proc(handle: os.Handle, alignment: i64) {
    position, _ := os.seek(handle, 0, os.SEEK_CUR)
    offset := position % alignment

    if offset > 0 {
        buffer := make([]byte, alignment - offset, context.temp_allocator)
        os.write(handle, buffer)
    }
}
