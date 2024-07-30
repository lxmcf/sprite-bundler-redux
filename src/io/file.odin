package bundler_io

import "core:os"

FileMode :: enum {
	WRITE,
	READ,
}

// Simplification of os.open based on read/write_entire_file
OpenFile :: proc(filename: string, mode: FileMode, truncate := true) -> (handle: os.Handle, success: bool) {
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

	file_handle, error := os.open(filename, file_flags, file_mode)

	if file_handle, error := os.open(filename, file_flags, file_mode); error != os.ERROR_NONE {
		return file_handle, false
	} else {
		return file_handle, true
	}
}

CloseFile :: proc(handle: os.Handle) -> (succes: bool) {
	return os.close(handle) == os.ERROR_NONE
}
