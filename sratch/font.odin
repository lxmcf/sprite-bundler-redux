import "core:unicode/utf8"

characters := "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz1234567890?!&.,_:[]-+"
font := rl.LoadFontEx("font.ttf", 32, raw_data(utf8.string_to_runes(characters)), i32(len(characters)))
defer rl.UnloadFont(font)
image := rl.LoadImageFromTexture(font.texture)
defer rl.UnloadImage(image)

rl.ExportImage(image, "tets.png")
