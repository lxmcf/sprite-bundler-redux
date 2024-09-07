package core

@(private)
ToWriteable :: proc {
    ProjectToWriteable,
    AtlasToWriteable,
    SpriteToWritable,
}

@(private)
ToReadable :: proc {
    ProjectToReadable,
    AtlasToReadable,
    SpriteToReadable,
}

@(private)
UnloadWriteable :: proc {
    UnloadWriteableProject,
    UnloadWriteableAtlas,
    UnloadWriteableSprite,
}
