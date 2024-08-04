package util

import "core:path/filepath"
import "core:strings"

CreatePath :: proc(items: ..string) -> string {
	array: [dynamic]string
	defer delete(array)

	for item, index in items {
		if index > 0 do append(&array, filepath.SEPARATOR_STRING)

		append(&array, item)
	}

	return strings.concatenate(array[:])
}
