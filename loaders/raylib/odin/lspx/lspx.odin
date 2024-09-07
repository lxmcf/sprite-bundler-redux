package lspx

import "core:os"
import "core:strings"
import rl "vendor:raylib"

Sprite :: struct {
    source: rl.Rectangle,
    origin: rl.Vector2,
    atlas:  string,
}

Atlas :: struct {
    sprite_count: int,
    texture:      rl.Texture2D,
}

Bundle :: struct {
    sprites:      map[string]Sprite,
    atlas:        map[string]Atlas,
    version:      i32,
    atlas_count:  i32,
    sprite_count: i32,
    atlas_size:   i32,
}

@(private)
active_bundle: Bundle

LoadBundle :: proc(filename: string) -> (Bundle, bool) {
    CHUNK_SIZE :: 4

    CHUNK_HEADER :: "LSPX"
    CHUNK_EOF :: "BEOF"
    CHUNK_SPRITE :: "SPRT"
    CHUNK_ATLAS :: "ATLS"

    AlignBytes :: proc(handle: os.Handle) {
        position, _ := os.seek(handle, 0, os.SEEK_CUR)
        offset := position % CHUNK_SIZE

        if offset > 0 do os.seek(handle, CHUNK_SIZE - offset, os.SEEK_CUR)
    }

    bundle: Bundle
    handle, _ := os.open(filename, 0)
    defer os.close(handle)

    chunk := make([]byte, CHUNK_SIZE)
    defer delete(chunk)

    os.read(handle, chunk)

    if strings.compare(string(chunk), CHUNK_HEADER) != 0 {
        rl.TraceLog(.ERROR, "[BUNDLE] Expected header LSPX but got %s!", chunk)
        return bundle, false
    }

    os.read_ptr(handle, &bundle.version, size_of(i32))
    os.read_ptr(handle, &bundle.atlas_count, size_of(i32))
    os.read_ptr(handle, &bundle.sprite_count, size_of(i32))
    os.read_ptr(handle, &bundle.atlas_size, size_of(i32))

    if bundle.sprite_count == 0 || bundle.atlas_count == 0 {
        return bundle, false
    }

    for strings.compare(string(chunk), CHUNK_EOF) != 0 {
        os.read(handle, chunk)

        if strings.compare(string(chunk), CHUNK_ATLAS) == 0 {
            atlas: Atlas
            name_length, decompressed_size, compressed_size: i32

            os.read_ptr(handle, &atlas.sprite_count, size_of(i32))
            os.read_ptr(handle, &name_length, size_of(i32))

            name := make([]byte, name_length)
            os.read(handle, name)
            AlignBytes(handle)

            os.read_ptr(handle, &compressed_size, size_of(i32))
            compressed_data := make([]byte, compressed_size, context.temp_allocator)

            os.read(handle, compressed_data)
            AlignBytes(handle)

            decompressed_data := rl.DecompressData(raw_data(compressed_data), compressed_size, &decompressed_size)
            defer rl.MemFree(decompressed_data)

            image := rl.LoadImageFromMemory(".png", decompressed_data, decompressed_size)
            defer rl.UnloadImage(image)

            atlas.texture = rl.LoadTextureFromImage(image)

            bundle.atlas[string(name)] = atlas
        }

        if strings.compare(string(chunk), CHUNK_SPRITE) == 0 {
            sprite: Sprite

            name_length, atlas_name_length: i32

            os.seek(handle, size_of(i32), os.SEEK_CUR) // Skip frame count
            os.seek(handle, size_of(f32), os.SEEK_CUR) // Skip frame speed
            os.read_ptr(handle, &atlas_name_length, size_of(i32))

            atlas_name := make([]byte, atlas_name_length)
            os.read(handle, atlas_name)
            AlignBytes(handle)

            sprite.atlas = string(atlas_name)

            os.seek(handle, size_of(i32), os.SEEK_CUR) // Skip atlas index
            os.read_ptr(handle, &name_length, size_of(i32))

            name := make([]byte, name_length)
            os.read(handle, name)
            AlignBytes(handle)

            os.read_ptr(handle, &sprite.source.x, size_of(f32))
            os.read_ptr(handle, &sprite.source.y, size_of(f32))
            os.read_ptr(handle, &sprite.source.width, size_of(f32))
            os.read_ptr(handle, &sprite.source.height, size_of(f32))

            os.read_ptr(handle, &sprite.origin.x, size_of(f32))
            os.read_ptr(handle, &sprite.origin.y, size_of(f32))

            bundle.sprites[string(name)] = sprite
        }
    }

    return bundle, true
}

UnloadBundle :: proc(bundle: Bundle) {
    for key, atlas in bundle.atlas {
        rl.UnloadTexture(atlas.texture)

        delete(key)
    }

    for key, sprite in bundle.sprites {
        delete(sprite.atlas)
        delete(key)
    }

    delete(bundle.atlas)
    delete(bundle.sprites)
}

SetActiveBundle :: proc(bundle: Bundle) {
    active_bundle = bundle
}

IsBundleReady :: proc(bundle: Bundle) -> bool {
    return bundle.atlas_count > 0 && bundle.sprite_count > 0
}

DrawSprite :: proc(sprite: string, position: rl.Vector2, color: rl.Color = rl.WHITE) {
    if !IsBundleReady(active_bundle) do return

    current_sprite := active_bundle.sprites[sprite]
    current_atlas := active_bundle.atlas[current_sprite.atlas]

    destination := rl.Rectangle{position.x, position.y, current_sprite.source.width, current_sprite.source.height}

    rl.DrawTexturePro(current_atlas.texture, current_sprite.source, destination, current_sprite.origin, 0, color)
}

DrawSpriteEx :: proc(sprite: string, position: rl.Vector2, scale: rl.Vector2, rotation: f32, color: rl.Color = rl.WHITE) {
    if !IsBundleReady(active_bundle) do return

    current_sprite := active_bundle.sprites[sprite]
    current_atlas := active_bundle.atlas[current_sprite.atlas]

    destination := rl.Rectangle{position.x, position.y, current_sprite.source.width * scale.x, current_sprite.source.height * scale.y}

    rl.DrawTexturePro(current_atlas.texture, current_sprite.source, destination, current_sprite.origin * scale, rotation, color)
}

GetSpriteOrigin :: proc(sprite: string) -> rl.Vector2 {
    return active_bundle.sprites[sprite].origin
}

GetSpriteSize :: proc(sprite: string) -> rl.Vector2 {
    source := active_bundle.sprites[sprite].source

    return {source.width, source.height}
}