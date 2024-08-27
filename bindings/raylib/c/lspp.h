#ifndef LSPP_H
#define LSPP_H

#include <raylib.h>
#include <stdint.h>

#if __SIZEOF_INT__ != 4 || __SIZEOF_FLOAT__ != 4
#error "Expected int and float with size of 4 bytes!"
#endif

typedef int Bundle;

#ifdef __cplusplus
extern "C" {
#endif

void TestFunc (const char* filename);

#ifdef __cplusplus
}
#endif

#define LSPP_IMPLEMENTATION
#if defined(LSPP_IMPLEMENTATION) || defined(LSPP_IMPL)

#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#define LSPP__BUNDLE_ALIGNMENT 4

#define LSPP__BUNDLE_HEADER "LSPX"
#define LSPP__ATLAS_HEADER  "ATLS"
#define LSPP__SPRITE_HEADER "SPRT"

typedef struct {

} lspp__sprite;

typedef struct {

} lspp__atlas;

typedef struct {
    int version;
    int atlas_count;
    int sprite_count;

    lspp__atlas* atlas;
    lspp__sprite* sprite;
} lspp__bundle;

#ifdef __cplusplus
extern "C" {
#endif

static long falgin (FILE* stream, int alignment) {
    static long offset = 0;

    offset = ftell (stream) % alignment;
    return offset > 0 ? fseek (stream, alignment - offset, SEEK_CUR) : 0;
}

void TestFunc (const char* filename) {
    int file_size   = GetFileLength (filename);
    int chunk_count = file_size / LSPP__BUNDLE_ALIGNMENT;

    char* header_buffer = (char*)malloc (sizeof (char) * 4);

    FILE* handle = fopen (filename, "rb");

    for (int i = 0; i < chunk_count; i++) {
        long offset = 0;

        fread (header_buffer, sizeof (char), LSPP__BUNDLE_ALIGNMENT, handle);

        if (strncmp (header_buffer, LSPP__BUNDLE_HEADER, 4) == 0) {
            TraceLog (LOG_INFO, "Found header at chunk[%d]", i);
            continue;
        }

        if (strncmp (header_buffer, LSPP__SPRITE_HEADER, 4) == 0) {
            TraceLog (LOG_INFO, "Found sprite at chunk[%d]", i);

            int frame_count, atlas_name_length, atlas_index, name_length;
            fread (&frame_count, sizeof (int), 1, handle);
            fread (&atlas_name_length, sizeof (int), 1, handle);

            char* atlas_name = (char*)calloc (atlas_name_length + 1, sizeof (char));
            fread (atlas_name, sizeof (char), atlas_name_length, handle);
            atlas_name[atlas_name_length] = '\0';

            falgin (handle, LSPP__BUNDLE_ALIGNMENT);

            fread (&atlas_index, sizeof (int), 1, handle);
            fread (&name_length, sizeof (int), 1, handle);

            char* name = (char*)calloc (name_length + 1, sizeof (char));
            fread (name, sizeof (char), name_length, handle);
            falgin (handle, LSPP__BUNDLE_ALIGNMENT);

            TraceLog (LOG_INFO, "\tFrame Count:    %d", frame_count);
            TraceLog (LOG_INFO, "\tAtlas Name:     %s", atlas_name);
            TraceLog (LOG_INFO, "\tAtlas Index:    %d", atlas_index);
            TraceLog (LOG_INFO, "\tSprite Name:    %s", name);

            float rect[4];
            for (int i = 0; i < 4; i++) {
                fread (&rect[i], sizeof (float), 1, handle);
            }

            TraceLog (LOG_INFO, "\tSpirce Source:   [ %.f, %.f, %.f, %.f] ", rect[0], rect[1], rect[2], rect[3]);

            float origin[2];
            // for (int i = 0; i < 2; i++) {
            //     fread (&origin[i], sizeof (float), 1, handle);
            // }

            TraceLog (LOG_INFO, "\tSpirce Origin:   [ %.f, %.f ] ", origin[0], origin[1]);

            free (atlas_name);
            free (name);

            continue;
        }

        if (strncmp (header_buffer, LSPP__ATLAS_HEADER, 4) == 0) {
            TraceLog (LOG_INFO, "Found atlas at chunk[%d]", i);

            int sprite_count, name_length, compressed_size, decompressed_size;
            char* name;

            fread (&sprite_count, sizeof (int), 1, handle);
            fread (&name_length, sizeof (int), 1, handle);

            name = (char*)malloc (name_length + 1);

            fread (name, sizeof (char), name_length, handle);
            name[name_length] = '\0';

            TraceLog (LOG_INFO, "\tSprite Count:   %d", sprite_count);
            TraceLog (LOG_INFO, "\tAtlas Name:     %s", name);

            falgin (handle, LSPP__BUNDLE_ALIGNMENT);

            // fread (&compressed_size, sizeof (int), 1, handle);
            // unsigned char* compressed_data = (unsigned char*)calloc (compressed_size, sizeof (char));
            // fread (compressed_data, sizeof (unsigned char), compressed_size, handle);

            // unsigned char* decompressed_data = DecompressData (compressed_data, compressed_size, &decompressed_size);

            // Image image = LoadImageFromMemory (".png", decompressed_data, decompressed_size);
            // ExportImage (image, "atlas.png");

            // falgin (handle, LSPP__BUNDLE_ALIGNMENT);

            // UnloadImage (image);

            // free (compressed_data);
            // free (decompressed_data);
            free (name);
        }
    }

    free (header_buffer);
    fclose (handle);
}

#ifdef __cplusplus
}
#endif

#endif

#endif // LSPP_H
