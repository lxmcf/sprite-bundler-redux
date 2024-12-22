package main

FPS_MINIMUM :: 60

FOURCC_SPRITE :: "SPRT"
FOURCC_ATLAS :: "ATLS"
FOURCC_FONT :: "FONT"
FOURCC_ANIMATION :: "ANIM"

Vector2 :: [2]f32
Vector2i :: [2]int

Rectangle :: struct {
    x:      f32,
    y:      f32,
    width:  f32 `json:"w"`,
    height: f32 `json:"h"`,
}
