package main

import rl "vendor:raylib"

FPS_MINIMUM :: 60

FOURCC_HEADER :: "LSPX"
FOURCC_SPRITE :: "SPRT"
FOURCC_ATLAS :: "ATLS"
FOURCC_FONT :: "FONT"
FOURCC_ANIMATION :: "ANIM"
FOURCC_TILESET :: "TILE"

FONT_CHARACTERS :: "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz1234567890?!&.,_:[]-+"

PROJECT_DIR_TEXTURES :: "textures"
PROJECT_DIR_FONTS :: "fonts"
PROJECT_DIR_EXPORTS :: "exports"
PROJECT_DIRECTORY :: "projects"
PROJECT_VERSION :: 100

CONFIG_FILENAME :: "project.conf"
PROJECT_FILENAME :: "project.lspp"

EDITOR_TOOLBAR_HEIGHT :: 32

Vector2 :: [2]f32
Vector2i :: [2]int

Rectangle :: rl.Rectangle

// NOTE: Cannot serialise rl.GlyphInfo
GlyphInfo :: struct {
    value:    rune,
    offset_x: i32,
    offset_y: i32,
    advance:  i32,
}
