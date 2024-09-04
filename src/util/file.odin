package util

import "core:os"

FileMode :: enum {
    WRITE,
    READ,
}

// Simplification of os.open based on read/write_entire_file
OpenFile :: proc(filename: string, mode: FileMode, truncate := true) -> (os.Handle, bool) {
    file_flags, file_mode: int

    switch mode {
    case .WRITE:
        file_flags = os.O_WRONLY | os.O_CREATE
        if (truncate) do file_flags |= os.O_TRUNC

        when ODIN_OS == .Linux || ODIN_OS == .Darwin {
            file_mode = os.S_IRUSR | os.S_IWUSR | os.S_IRGRP | os.S_IROTH
        }
    case .READ:
        file_flags = os.O_RDONLY
    }

    if file_handle, error := os.open(filename, file_flags, file_mode); error != os.ERROR_NONE {
        return file_handle, false
    } else {
        return file_handle, true
    }
}

CloseFile :: proc(handle: os.Handle) -> bool {
    return os.close(handle) == os.ERROR_NONE
}

AlignFile :: proc(handle: os.Handle, alignment: i64) -> i64 {
    position, _ := os.seek(handle, 0, os.SEEK_CUR)
    offset := position % alignment

    if offset > 0 {
        result, _ := os.seek(handle, alignment - offset, os.SEEK_CUR)
        return result
    } else {
        return 0
    }
}

PadFile :: proc(handle: os.Handle, alignment: i64) {
    position, _ := os.seek(handle, 0, os.SEEK_CUR)
    offset := position % alignment

    if offset > 0 {
        buffer := make([]byte, alignment - offset, context.temp_allocator)
        os.write(handle, buffer)
    }
}
