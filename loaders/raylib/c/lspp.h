// TODO: Create string pool for sprite names

#ifndef LSPP_H
#define LSPP_H

#include <raylib.h>

#if __SIZEOF_INT__ != 4 || __SIZEOF_FLOAT__ != 4
#error "Expected int and float with size of 4 bytes!"
#endif

#if __SIZEOF_LONG__ != 8
#error "Expected long with size of 8 bytes!"
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

int GetSpriteIndex (const char* name);

Bundle LoadBundle (const char* filename);
void SetActiveBundle (Bundle* bundle);
void UnloadBundle (Bundle bundle);

int IsBundleReady (Bundle bundle);

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

#define UNWRAP_RECTANGLE(r) r.x, r.y, r.width, r.height
#define UNWRAP_VECTOR2(v)   v.x, v.y

static Bundle* lspp__active_bundle = NULL;

static long falign (FILE* stream, int alignment) {
    long offset = ftell (stream) % alignment;
    return offset > 0 ? fseek (stream, alignment - offset, SEEK_CUR) : 0;
}

static int lspp__compare (const void* a, const void* b) {
    Sprite2D* sprite_a = (Sprite2D*)a;
    Sprite2D* sprite_b = (Sprite2D*)b;

    return strncmp (sprite_a->name, sprite_b->name, 128);
}

int GetSpriteIndex (const char* name) {
    if (lspp__active_bundle == NULL)
        return -1;

    int left  = 0;
    int right = lspp__active_bundle->sprite_count - 1;

    while (left <= right) {
        int middle = left + (right - left) / 2;

        int compare = strncmp (lspp__active_bundle->sprite[middle].name, name, 128);

        if (compare == 0) {
            return middle;
        } else if (compare < 0) {
            left = middle + 1;
        } else {
            right = middle - 1;
        }
    }

    return -1;
}

Bundle LoadBundle (const char* filename) {
    char* header_buffer = (char*)calloc (4, sizeof (char));
    FILE* handle        = fopen (filename, "rb");
    Bundle bundle       = CLITERAL (Bundle){0};

    if (handle == NULL) {
        free (header_buffer);

        return bundle;
    }

    fread (header_buffer, sizeof (char), LSPP__BUNDLE_ALIGNMENT, handle);

    if (strncmp (header_buffer, LSPP__BUNDLE_HEADER, 4) != 0) {
        free (header_buffer);
        fclose (handle);

        return bundle;
    }

    TraceLog (LOG_DEBUG, "--> Found header at chunk[%d]", ftell (handle) / LSPP__BUNDLE_ALIGNMENT);

    int bundle_version, atlas_count, sprite_count, atlas_size;
    fread (&bundle_version, sizeof (int), 1, handle);
    fread (&atlas_count, sizeof (int), 1, handle);
    fread (&sprite_count, sizeof (int), 1, handle);
    fread (&atlas_size, sizeof (int), 1, handle);

    TraceLog (LOG_DEBUG, "\t\tBundle Version: %d", bundle_version);
    TraceLog (LOG_DEBUG, "\t\tAtlas Count:    %d", atlas_count);
    TraceLog (LOG_DEBUG, "\t\tSprite Count:   %d", sprite_count);
    TraceLog (LOG_DEBUG, "\t\tAtlas Size:     %d", atlas_size);

    // Create Bundle
    bundle.sprite       = (Sprite2D*)calloc (sprite_count, sizeof (Sprite2D));
    bundle.atlas        = (Texture2D*)calloc (atlas_count, sizeof (Texture2D));
    bundle.atlas_count  = atlas_count;
    bundle.sprite_count = sprite_count;

    int atlas_loaded  = 0;
    int sprite_loaded = 0;

    while (strncmp (header_buffer, LSPP__BUNDLE_EOF, 4) != 0) {
        fread (header_buffer, sizeof (char), LSPP__BUNDLE_ALIGNMENT, handle);

        if (strncmp (header_buffer, LSPP__SPRITE_HEADER, 4) == 0) {
            TraceLog (LOG_DEBUG, "--> Found sprite at chunk[%d]", ftell (handle) / LSPP__BUNDLE_ALIGNMENT);

            Sprite2D* current_sprite = &bundle.sprite[sprite_loaded];

            int frame_count, atlas_name_length, name_length;
            fread (&frame_count, sizeof (int), 1, handle);
            fread (&atlas_name_length, sizeof (int), 1, handle);

            fseek (handle, atlas_name_length, SEEK_CUR);
            falign (handle, LSPP__BUNDLE_ALIGNMENT);

            fread (&current_sprite->atlas_index, sizeof (int), 1, handle);
            fread (&name_length, sizeof (int), 1, handle);

            current_sprite->name = (char*)calloc (name_length + 1, sizeof (char));
            fread (current_sprite->name, sizeof (char), name_length, handle);
            falign (handle, LSPP__BUNDLE_ALIGNMENT);
            current_sprite->name[name_length] = '\0';

            fread (&current_sprite->source.x, sizeof (float), 1, handle);
            fread (&current_sprite->source.y, sizeof (float), 1, handle);
            fread (&current_sprite->source.width, sizeof (float), 1, handle);
            fread (&current_sprite->source.height, sizeof (float), 1, handle);

            fread (&current_sprite->origin.x, sizeof (float), 1, handle);
            fread (&current_sprite->origin.y, sizeof (float), 1, handle);

            TraceLog (LOG_DEBUG, "\t\tFrame Count:    %d", frame_count);
            TraceLog (LOG_DEBUG, "\t\tAtlas Index:    %d", current_sprite->atlas_index);
            TraceLog (LOG_DEBUG, "\t\tSprite Name:    %s", current_sprite->name);
            TraceLog (LOG_DEBUG, "\t\tSprite Source:  [ %.f, %.f, %.f, %.f] ", UNWRAP_RECTANGLE (current_sprite->source));
            TraceLog (LOG_DEBUG, "\t\tSprite Origin:  [ %.f, %.f ] ", UNWRAP_VECTOR2 (current_sprite->origin));

            sprite_loaded++;

            continue;
        }

        if (strncmp (header_buffer, LSPP__ATLAS_HEADER, 4) == 0) {
            TraceLog (LOG_DEBUG, "--> Found atlas at chunk[%d]", ftell (handle) / LSPP__BUNDLE_ALIGNMENT);

            int sprite_count, name_length, compressed_size, decompressed_size;
            char* name;

            fread (&sprite_count, sizeof (int), 1, handle);
            fread (&name_length, sizeof (int), 1, handle);

            name = (char*)calloc (name_length + 1, sizeof (char));

            fread (name, sizeof (char), name_length, handle);
            falign (handle, LSPP__BUNDLE_ALIGNMENT);
            name[name_length] = '\0';

            TraceLog (LOG_DEBUG, "\t\tSprite Count:   %d", sprite_count);
            TraceLog (LOG_DEBUG, "\t\tAtlas Name:     %s", name);

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

    qsort (bundle.sprite, bundle.sprite_count, sizeof (Sprite2D), lspp__compare);
    return bundle;
}

void SetActiveBundle (Bundle* bundle) {
    lspp__active_bundle = bundle;
}

void UnloadBundle (Bundle bundle) {
    if (IsBundleReady (bundle)) {
        for (int i = 0; i < bundle.atlas_count; i++)
            UnloadTexture (bundle.atlas[i]);

        for (int i = 0; i < bundle.sprite_count; i++)
            free (bundle.sprite[i].name);

        free (bundle.sprite);
    }
}

int IsBundleReady (Bundle bundle) {
    return bundle.atlas_count > 0 && bundle.sprite_count > 0;
}

#endif // LSPP_IMPLEMENTATION || LSPP_IMPL

#ifdef __cplusplus
}
#endif // __cplusplus

#endif // LSPP_H
