// TODO: Create string pool for sprite names
// TODO: Potentially move to a basic maps for sprites and atlas'

#ifndef LSPX_H
#define LSPX_H

#include <raylib.h>

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

typedef enum {
    FLIP_NONE       = 0x00000001,
    FLIP_HORIZONTAL = 0x00000002,
    FLIP_VERTICAL   = 0x00000004,
} FlipMode;

#ifdef __cplusplus
extern "C" {
#endif

void DrawSprite (int index, Vector2 position, Color color);
void DrawSpriteEx (int index, Vector2 position, float scale, float rotation, Color color);
void DrawSpritePro (int index, Vector2 position, Vector2 scale, float rotation, int flip_mode, Color color);
void DrawSpriteNineSlice (int index, Rectangle bounds, Color color);

Vector2 GetSpriteOrigin (int index);

Vector2 GetSpriteSize (int index);
const char* GetSpriteName (int index);

int GetSpriteIndex (const char* name);

Bundle LoadBundle (const char* filename);
void SetActiveBundle (Bundle* bundle);
void UnloadBundle (Bundle bundle);

int IsBundleReady (Bundle bundle);

#if defined(LSPX_IMPLEMENTATION) || defined(LSPX_IMPL)

#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#define LSPX__BUNDLE_ALIGNMENT 4

#define LSPX__BUNDLE_HEADER "LSPX"
#define LSPX__BUNDLE_EOF    "BEOF"
#define LSPX__ATLAS_HEADER  "ATLS"
#define LSPX__SPRITE_HEADER "SPRT"

#define UNWRAP_RECTANGLE(r) r.x, r.y, r.width, r.height
#define UNWRAP_VECTOR2(v)   v.x, v.y

static Bundle* lspx__active_bundle = NULL;

static long falign (FILE* stream, int alignment) {
    long offset = ftell (stream) % alignment;
    return offset > 0 ? fseek (stream, alignment - offset, SEEK_CUR) : 0;
}

static int lspx__compare (const void* a, const void* b) {
    Sprite2D* sprite_a = (Sprite2D*)a;
    Sprite2D* sprite_b = (Sprite2D*)b;

    return strncmp (sprite_a->name, sprite_b->name, 128);
}

void DrawSprite (int index, Vector2 position, Color color) {
    if (lspx__active_bundle == NULL)
        return;
    if (index == -1 || index > lspx__active_bundle->sprite_count - 1)
        return;

    Sprite2D* sprite = &lspx__active_bundle->sprite[index];

    DrawTexturePro (
        lspx__active_bundle->atlas[sprite->atlas_index],
        sprite->source,
        CLITERAL (Rectangle){position.x, position.y, sprite->source.width, sprite->source.height},
        sprite->origin,
        0,
        color);
}

void DrawSpriteEx (int index, Vector2 position, float scale, float rotation, Color color) {
    if (lspx__active_bundle == NULL)
        return;
    if (index == -1 || index > lspx__active_bundle->sprite_count - 1)
        return;

    Sprite2D* sprite = &lspx__active_bundle->sprite[index];

    Rectangle destination = CLITERAL (Rectangle){
        position.x,
        position.y,
        sprite->source.width * scale,
        sprite->source.height * scale,
    };

    DrawTexturePro (
        lspx__active_bundle->atlas[sprite->atlas_index],
        sprite->source,
        destination,
        CLITERAL (Vector2){sprite->origin.x * scale, sprite->origin.y * scale},
        rotation,
        color);
}

void DrawSpritePro (int index, Vector2 position, Vector2 scale, float rotation, int flip_mode, Color color) {
    if (lspx__active_bundle == NULL)
        return;
    if (index == -1 || index > lspx__active_bundle->sprite_count - 1)
        return;

    Sprite2D* sprite = &lspx__active_bundle->sprite[index];

    Rectangle source = sprite->source;

    if (flip_mode | FLIP_HORIZONTAL)
        source.width *= -1;
    if (flip_mode | FLIP_VERTICAL)
        source.height *= -1;

    Rectangle destination = CLITERAL (Rectangle){
        position.x,
        position.y,
        sprite->source.width * scale.x,
        sprite->source.height * scale.y,
    };

    DrawTexturePro (
        lspx__active_bundle->atlas[sprite->atlas_index],
        source,
        destination,
        CLITERAL (Vector2){sprite->origin.x * scale.x, sprite->origin.y * scale.y},
        rotation,
        color);
}

void DrawSpriteNineSlice (int index, Rectangle bounds, Color color) {
    if (lspx__active_bundle == NULL)
        return;
    if (index == -1 || index > lspx__active_bundle->sprite_count - 1)
        return;

    Sprite2D* sprite = &lspx__active_bundle->sprite[index];
    Texture atlas    = lspx__active_bundle->atlas[sprite->atlas_index];
    Rectangle source = sprite->source;

    float cell_width  = source.width / 2;
    float cell_height = source.height / 2;

    Rectangle top_left   = CLITERAL (Rectangle){source.x, source.y, cell_width, cell_height};
    Rectangle top_middle = CLITERAL (Rectangle){source.x + cell_width, source.y, cell_width, cell_height};
    Rectangle top_right  = CLITERAL (Rectangle){source.x + (cell_width * 2.0f), source.y, cell_width, cell_height};

    Rectangle middle_left   = CLITERAL (Rectangle){source.x, source.y + cell_height, cell_width, cell_height};
    Rectangle middle_middle = CLITERAL (Rectangle){source.x + cell_width, source.y + cell_height, cell_width, cell_height};
    Rectangle middle_right  = CLITERAL (Rectangle){source.x + (cell_width * 2.0f), source.y + cell_height, cell_width, cell_height};

    Rectangle bottom_left   = CLITERAL (Rectangle){source.x, source.y + (cell_height * 2.0f), cell_width, cell_height};
    Rectangle bottom_middle = CLITERAL (Rectangle){source.x + cell_width, source.y + (cell_height * 2.0f), cell_width, cell_height};
    Rectangle bottom_right  = CLITERAL (Rectangle){source.x + (cell_width * 2.0f), source.y + (cell_height * 2.0f), cell_width, cell_height};

    // Corners
    DrawTextureRec (atlas, top_left, {bounds.x, bounds.y}, color);
    DrawTextureRec (atlas, top_right, {bounds.x + (bounds.width - cell_width), bounds.y}, color);
    DrawTextureRec (atlas, bottom_left, {bounds.x, bounds.y + (bounds.height - cell_height)}, color);
    DrawTextureRec (atlas, bottom_right, {bounds.x + (bounds.width - cell_width), bounds.y + (bounds.height - cell_height)}, color);

    // Connectors
    DrawTexturePro (atlas, top_middle, {bounds.x + cell_width, bounds.y, bounds.width - (cell_width * 2.0f), cell_height}, {}, 0, color);
    DrawTexturePro (atlas, middle_left, {bounds.x, bounds.y + cell_height, cell_width, bounds.height - (cell_height * 2.0f)}, {}, 0, color);
    DrawTexturePro (atlas, middle_right, {bounds.x + bounds.width - cell_width, bounds.y + cell_height, cell_width, bounds.height - (cell_height * 2.0f)}, {}, 0, color);
    DrawTexturePro (atlas, bottom_middle, {bounds.x + cell_width, bounds.y + (bounds.height - cell_height), bounds.width - (cell_width * 2.0f), cell_height}, {}, 0, color);

    // Centre
    DrawTexturePro (atlas, middle_middle, {bounds.x + cell_width, bounds.y + cell_height, bounds.width - (cell_width * 2.0f), bounds.height - (cell_height * 2.0f)}, {}, 0, color);
}

Vector2 GetSpriteOrigin (int index) {
    if (lspx__active_bundle == NULL)
        return CLITERAL (Vector2){0, 0};
    if (index == -1 || index > lspx__active_bundle->sprite_count - 1)
        return CLITERAL (Vector2){0, 0};

    Sprite2D* sprite = &lspx__active_bundle->sprite[index];

    return sprite->origin;
}

Vector2 GetSpriteSize (int index) {
    if (lspx__active_bundle == NULL)
        return CLITERAL (Vector2){0, 0};
    if (index == -1 || index > lspx__active_bundle->sprite_count - 1)
        return CLITERAL (Vector2){0, 0};

    Sprite2D* sprite = &lspx__active_bundle->sprite[index];

    return CLITERAL (Vector2){sprite->source.width, sprite->source.height};
}

const char* GetSpriteName (int index) {
    if (index == -1 || index > lspx__active_bundle->sprite_count - 1)
        return NULL;

    return lspx__active_bundle->sprite[index].name;
}

int GetSpriteIndex (const char* name) {
    if (lspx__active_bundle == NULL)
        return -1;

    int left  = 0;
    int right = lspx__active_bundle->sprite_count - 1;

    while (left <= right) {
        int middle = left + (right - left) / 2;

        int compare = strncmp (lspx__active_bundle->sprite[middle].name, name, 128);

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

    fread (header_buffer, sizeof (char), LSPX__BUNDLE_ALIGNMENT, handle);

    if (strncmp (header_buffer, LSPX__BUNDLE_HEADER, 4) != 0) {
        free (header_buffer);
        fclose (handle);
        return bundle;
    }

    TraceLog (LOG_DEBUG, "--> Found header at chunk[%d]", ftell (handle) / LSPX__BUNDLE_ALIGNMENT);

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

    while (strncmp (header_buffer, LSPX__BUNDLE_EOF, 4) != 0) {
        fread (header_buffer, sizeof (char), LSPX__BUNDLE_ALIGNMENT, handle);

        if (strncmp (header_buffer, LSPX__SPRITE_HEADER, 4) == 0) {
            TraceLog (LOG_DEBUG, "--> Found sprite at chunk[%d]", ftell (handle) / LSPX__BUNDLE_ALIGNMENT);

            Sprite2D* current_sprite = &bundle.sprite[sprite_loaded];

            int frame_count, atlas_name_length, name_length;
            float frame_speed;

            fread (&frame_count, sizeof (int), 1, handle);
            fread (&frame_speed, sizeof (float), 1, handle);
            fread (&atlas_name_length, sizeof (int), 1, handle);

            fseek (handle, atlas_name_length, SEEK_CUR);
            falign (handle, LSPX__BUNDLE_ALIGNMENT);

            fread (&current_sprite->atlas_index, sizeof (int), 1, handle);
            fread (&name_length, sizeof (int), 1, handle);

            current_sprite->name = (char*)calloc (name_length + 1, sizeof (char));
            fread (current_sprite->name, sizeof (char), name_length, handle);
            falign (handle, LSPX__BUNDLE_ALIGNMENT);
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

        if (strncmp (header_buffer, LSPX__ATLAS_HEADER, 4) == 0) {
            TraceLog (LOG_DEBUG, "--> Found atlas at chunk[%d]", ftell (handle) / LSPX__BUNDLE_ALIGNMENT);

            int sprite_count, name_length, atlas_data_size;
            char* name;

            fread (&sprite_count, sizeof (int), 1, handle);
            fread (&name_length, sizeof (int), 1, handle);

            name = (char*)calloc (name_length + 1, sizeof (char));

            fread (name, sizeof (char), name_length, handle);
            falign (handle, LSPX__BUNDLE_ALIGNMENT);
            name[name_length] = '\0';

            TraceLog (LOG_DEBUG, "\t\tSprite Count:   %d", sprite_count);
            TraceLog (LOG_DEBUG, "\t\tAtlas Name:     %s", name);

            fread (&atlas_data_size, sizeof (int), 1, handle);

            unsigned char* atlas_data = (unsigned char*)calloc (atlas_data_size, sizeof (char));
            fread (atlas_data, sizeof (unsigned char), atlas_data_size, handle);
            falign (handle, LSPX__BUNDLE_ALIGNMENT);

            Image image                = LoadImageFromMemory (".png", atlas_data, atlas_data_size);
            bundle.atlas[atlas_loaded] = LoadTextureFromImage (image);

            UnloadImage (image);

            free (atlas_data);
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

    qsort (bundle.sprite, bundle.sprite_count, sizeof (Sprite2D), lspx__compare);
    return bundle;
}

void SetActiveBundle (Bundle* bundle) {
    lspx__active_bundle = bundle;
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

#endif // LSPX_IMPLEMENTATION || LSPX_IMPL

#ifdef __cplusplus
}
#endif // __cplusplus

#endif // LSPX_H
