// TODO: Create string pool for sprite names

#ifndef LSPP_H
#define LSPP_H

#include <raylib.h>
#include <stdint.h>

#if __SIZEOF_INT__ != 4 || __SIZEOF_FLOAT__ != 4
#error "Expected int and float with size of 4 bytes!"
#endif

typedef struct {
    char* name;

    int atlas_index;

    Rectangle source;
    Vector2 origin;
} Sprite2D;

typedef struct {
    int atlas_count;
    int sprite_count;

    Texture2D* atlas;
    Sprite2D* sprite;
} Bundle;

#ifdef __cplusplus
extern "C" {
#endif

Bundle LoadBundle (const char* filename);
void UnloadBundle (Bundle bundle);

#define LSPP_IMPLEMENTATION
#if defined(LSPP_IMPLEMENTATION) || defined(LSPP_IMPL)

#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#define LSPP__BUNDLE_ALIGNMENT 4

#define LSPP__BUNDLE_HEADER "LSPX"
#define LSPP__BUNDLE_EOF    "BEOF"
#define LSPP__ATLAS_HEADER  "ATLS"
#define LSPP__SPRITE_HEADER "SPRT"

static long falign (FILE* stream, int alignment) {
    long offset = ftell (stream) % alignment;
    return offset > 0 ? fseek (stream, alignment - offset, SEEK_CUR) : 0;
}

Bundle LoadBundle (const char* filename) {
    char* header_buffer = (char*)malloc (sizeof (char) * 4);
    FILE* handle        = fopen (filename, "rb");

    fread (header_buffer, sizeof (char), LSPP__BUNDLE_ALIGNMENT, handle);

    if (strncmp (header_buffer, LSPP__BUNDLE_HEADER, 4) != 0)
        return CLITERAL (Bundle){0}; // Return an empty bundle

#ifdef LSPP_LOG_DEBUG
    TraceLog (LOG_DEBUG, "--> Found header at chunk[%d]", ftell (handle) / LSPP__BUNDLE_ALIGNMENT);
#endif

    int bundle_version, atlas_count, sprite_count, atlas_size;
    fread (&bundle_version, sizeof (int), 1, handle);
    fread (&atlas_count, sizeof (int), 1, handle);
    fread (&sprite_count, sizeof (int), 1, handle);
    fread (&atlas_size, sizeof (int), 1, handle);

#ifdef LSPP_LOG_DEBUG
    TraceLog (LOG_DEBUG, "\t\tBundle Version: %d", bundle_version);
    TraceLog (LOG_DEBUG, "\t\tAtlas Count:    %d", atlas_count);
    TraceLog (LOG_DEBUG, "\t\tSprite Count:   %d", sprite_count);
    TraceLog (LOG_DEBUG, "\t\tAtlas Size:     %d", atlas_size);
#endif

    // Create Bundle
    Bundle bundle       = {0};
    bundle.sprite       = (Sprite2D*)calloc (sprite_count, sizeof (Sprite2D));
    bundle.atlas        = (Texture2D*)calloc (atlas_count, sizeof (Texture2D));
    bundle.atlas_count  = atlas_count;
    bundle.sprite_count = sprite_count;

    int atlas_loaded  = 0;
    int sprite_loaded = 0;

    while (strncmp (header_buffer, LSPP__BUNDLE_EOF, 4) != 0) {
        fread (header_buffer, sizeof (char), LSPP__BUNDLE_ALIGNMENT, handle);

        if (strncmp (header_buffer, LSPP__SPRITE_HEADER, 4) == 0) {
#ifdef LSPP_LOG_DEBUG
            TraceLog (LOG_DEBUG, "--> Found sprite at chunk[%d]", ftell (handle) / LSPP__BUNDLE_ALIGNMENT);
#endif

            int frame_count, atlas_name_length, atlas_index, name_length;
            fread (&frame_count, sizeof (int), 1, handle);
            fread (&atlas_name_length, sizeof (int), 1, handle);

            char* atlas_name = (char*)calloc (atlas_name_length + 1, sizeof (char));
            fread (atlas_name, sizeof (char), atlas_name_length, handle);
            falign (handle, LSPP__BUNDLE_ALIGNMENT);
            atlas_name[atlas_name_length] = '\0';

            fread (&atlas_index, sizeof (int), 1, handle);
            fread (&name_length, sizeof (int), 1, handle);

            char* name = (char*)calloc (name_length + 1, sizeof (char));
            fread (name, sizeof (char), name_length, handle);
            falign (handle, LSPP__BUNDLE_ALIGNMENT);
            name[name_length] = '\0';

            float rect[4];
            for (int i = 0; i < 4; i++)
                fread (&rect[i], sizeof (float), 1, handle);

            float origin[2];
            for (int i = 0; i < 2; i++)
                fread (&origin[i], sizeof (float), 1, handle);

#ifdef LSPP_LOG_DEBUG
            TraceLog (LOG_DEBUG, "\t\tFrame Count:    %d", frame_count);
            TraceLog (LOG_DEBUG, "\t\tAtlas Name:     %s", atlas_name);
            TraceLog (LOG_DEBUG, "\t\tAtlas Index:    %d", atlas_index);
            TraceLog (LOG_DEBUG, "\t\tSprite Name:    %s", name);
            TraceLog (LOG_DEBUG, "\t\tSprite Source:  [ %.f, %.f, %.f, %.f] ", rect[0], rect[1], rect[2], rect[3]);
            TraceLog (LOG_DEBUG, "\t\tSprite Origin:  [ %.f, %.f ] ", origin[0], origin[1]);
#endif
            free (atlas_name);
            free (name);

            sprite_loaded++;

            continue;
        }

        if (strncmp (header_buffer, LSPP__ATLAS_HEADER, 4) == 0) {
#ifdef LSPP_LOG_DEBUG
            TraceLog (LOG_DEBUG, "--> Found atlas at chunk[%d]", ftell (handle) / LSPP__BUNDLE_ALIGNMENT);
#endif

            int sprite_count, name_length, compressed_size, decompressed_size;
            char* name;

            fread (&sprite_count, sizeof (int), 1, handle);
            fread (&name_length, sizeof (int), 1, handle);

            name = (char*)malloc (name_length + 1);

            fread (name, sizeof (char), name_length, handle);
            falign (handle, LSPP__BUNDLE_ALIGNMENT);
            name[name_length] = '\0';

#ifdef LSPP_LOG_DEBUG
            TraceLog (LOG_DEBUG, "\t\tSprite Count:   %d", sprite_count);
            TraceLog (LOG_DEBUG, "\t\tAtlas Name:     %s", name);
#endif

            fread (&compressed_size, sizeof (int), 1, handle);

            unsigned char* compressed_data = (unsigned char*)calloc (compressed_size, sizeof (char));
            fread (compressed_data, sizeof (unsigned char), compressed_size, handle);
            falign (handle, LSPP__BUNDLE_ALIGNMENT);

            unsigned char* decompressed_data = DecompressData (compressed_data, compressed_size, &decompressed_size);

            Image image                = LoadImageFromMemory (".png", decompressed_data, decompressed_size);
            bundle.atlas[atlas_loaded] = LoadTextureFromImage (image);

            UnloadImage (image);

            free (compressed_data);
            free (decompressed_data);
            free (name);

            atlas_loaded++;
        }
    }

    if (bundle.sprite_count != sprite_loaded || bundle.atlas_count != atlas_loaded) {
        TraceLog (LOG_ERROR, "Sprite or atlas count did not match, free'd bundle!");
        TraceLog (LOG_ERROR, "Sprites: %d/%d", sprite_loaded, bundle.sprite_count);
        TraceLog (LOG_ERROR, "Atlas':  %d/%d", atlas_loaded, bundle.atlas_count);

        UnloadBundle (bundle);
    }

    free (header_buffer);
    fclose (handle);

    return bundle;
}

void UnloadBundle (Bundle bundle) {
    for (int i = 0; i < bundle.atlas_count; i++)
        UnloadTexture (bundle.atlas[i]);

    for (int i = 0; i < bundle.sprite_count; i++)
        free (bundle.sprite[i].name);

    free (bundle.sprite);
}

#ifdef __cplusplus
}
#endif // __cplusplus

#endif // LSPP_IMPLEMENTATION || LSPP_IMPL

#endif // LSPP_H
