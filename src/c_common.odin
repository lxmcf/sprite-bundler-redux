package main

import rl "vendor:raylib"

FPS_MINIMUM :: 60

FOURCC_HEADER :: "LSPX"
FOURCC_SPRITE :: "SPRT"
FOURCC_ATLAS :: "ATLS"
FOURCC_FONT :: "FONT"
FOURCC_ANIMATION :: "ANIM"
FOURCC_TILESET :: "TILE"

FONT_CHARACTERS :: "!\"#$%&'()*+,-./0123456789:;<=>?@ABCDEFGHIJKLMNOPQRSTUVWXYZ[]^_`abcdefghijklmnopqrstuvwxyz{|}~¿ÀÁÂÃÄÅÆÇÈÉÊËÌÍÎÏÐÑÒÓÔÕÖ×ØÙÚÛÜÝÞßàáâãäåæçèéêëìíîïðñòóôõö÷øùúûüýþÿ"
FONT_CHARACTERS_MINIMAL :: "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz1234567890?!&.,_:[]-+"

PROJECT_DIR_TEXTURES :: "textures"
PROJECT_DIR_EXPORTS :: "exports"
PROJECT_DIRECTORY :: "projects"
PROJECT_VERSION :: 100

CONFIG_FILENAME :: "lspp.conf"
PROJECT_FILENAME :: "project.lspp"

EDITOR_TOOLBAR_HEIGHT :: 32

Vector2 :: [2]f32
Vector2i :: [2]int

// TODO: Move to i32 rect, can't have half a pixel and can just be converted to f32 in loader
Rectangle :: rl.Rectangle

// NOTE: Cannot serialise rl.GlyphInfo
GlyphInfo :: struct {
    value:    i32, // NOTE: Cannot unmarshal a rune?
    offset_x: i32,
    offset_y: i32,
    advance:  i32,
}
