package util

import "core:os"
import "core:path/filepath"
import "core:strings"

FileMode :: enum {
	WRITE,
	READ,
}

File :: os.Handle

CreatePath :: proc(items: []string, allocator := context.allocator) -> string {
	array: [dynamic]string
	defer delete(array)

	for item, index in items {
		if index > 0 do append(&array, filepath.SEPARATOR_STRING)

		append(&array, item)
	}

	return strings.concatenate(array[:], allocator)
}

DeleteStrings :: proc(items: ..string) {
	for item in items do delete(item)
}

// Simplification of os.open based on read/write_entire_file
OpenFile :: proc(filename: string, mode: FileMode, truncate := true) -> (File, bool) {
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

CloseFile :: proc(handle: File) -> bool {
	return os.close(handle) == os.ERROR_NONE
}

@(private)
GetPadding :: proc(data_length, alignment: int) -> int {
	return data_length % alignment == 0 ? 0 : alignment - (data_length % alignment) % alignment
}

WriteAligned :: proc(handle: File, data: []byte, alignment: int = 0) -> (int, os.Errno) {
	padding: int
	bytes_written, error := os.write(handle, data)

	if alignment > 0 {
		padding = GetPadding(len(data), alignment)

		if padding > 0 {
			bytes := make([]byte, padding, context.temp_allocator)
			os.write(handle, bytes)
		}
	}

	return bytes_written + padding, error
}

WriteStringAligned :: proc(handle: File, data: string, alignment: int = 0) -> (int, os.Errno) {
	padding: int
	bytes_written, error := os.write_string(handle, data)

	if alignment > 0 {
		padding = GetPadding(len(data), alignment)

		if padding > 0 {
			bytes := make([]byte, padding, context.temp_allocator)
			os.write(handle, bytes)
		}
	}

	return bytes_written + padding, error
}

WritePtrAligned :: proc(handle: File, data: rawptr, length: int, alignment: int = 0) -> (int, os.Errno) {
	padding: int
	bytes_written, error := os.write_ptr(handle, data, length)

	if alignment > 0 {
		padding = GetPadding(length, alignment)

		if padding > 0 {
			bytes := make([]byte, padding, context.temp_allocator)
			os.write(handle, bytes)
		}
	}

	return bytes_written + padding, error
}

ReadAligned :: proc(handle: File, data: []byte, alignment: int = 0) -> (int, os.Errno) {
	padding: int
	bytes_read, error := os.read(handle, data)

	if alignment > 0 {
		padding = GetPadding(len(data), alignment)

		if padding > 0 {
			bytes := make([]byte, padding, context.temp_allocator)
			os.read(handle, bytes)
		}
	}

	return bytes_read + padding, error
}

ReadPtrAligned :: proc(handle: File, data: rawptr, length: int, alignment: int = 0) -> (int, os.Errno) {
	padding: int
	bytes_read, error := os.read_ptr(handle, data, length)

	if alignment > 0 {
		padding = GetPadding(length, alignment)

		if padding > 0 {
			bytes := make([]byte, padding, context.temp_allocator)
			os.read(handle, bytes)
		}
	}

	return bytes_read + padding, error
}
