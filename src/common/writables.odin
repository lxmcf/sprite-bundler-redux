package common

@(private)
to_writeable :: proc {
    project_to_writeable,
    atlas_to_writeable,
    sprite_to_writable,
}

@(private)
to_readable :: proc {
    project_to_readable,
    atlas_to_readable,
    sprite_to_readable,
}

@(private)
unload_writeable :: proc {
    unload_writeable_project,
    unload_writeable_atlas,
    unload_writeable_sprite,
}
