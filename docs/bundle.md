# Bundle File Structure

The sprite bundle structure (LSPX) is very simple, all data is aligned to 4 bytes; refered to as a 'chunk', meaning all integers and floats are 32 bit, file structure is very loosely inspired by [rres](https://github.com/raysan5/rres)

The structure is split into different types of 'blocks', as listed below...
`LSPX` - Header (20 Bytes)
`SPRT` - Sprite (52 Bytes^)
`ATLS` - Atlas (16 Bytes^)

Using this information you can easily follow [this guide](/docs/make-loader.md) to build a loader for your potential needs and/or integrations.

> [!NOTE]
> Block size marked with ^ indicates they will contain data than can also be of variable length!

Below you will see the data layout for each type of block...

```c
// File layout
Header
    FourCC ID           (4 Bytes) // LSPX
    Version             (4 Bytes) // Bundle version
    Atlas Count         (4 Bytes) // Total stored atlas'
    Sprite Count        (4 Bytes) // Total stored sprites
    Atlas Size          (4 Bytes) // Size of texture atlas (size x size)

Atlas[]
{
    FourCC ID           (4 Bytes) // ATLS
    Sprite Count        (4 Bytes) // Amount of sprites in current atlas
    Name Length         (4 Bytes) // Length of atlas name
    Name                (^ Bytes) // Name of atlas (Appended with 0-3 bytes of padding)
    Data Size           (4 Bytes) // Length of stored atlas data
    Data                (^ Bytes) // Raw PNG data
}

Sprite[]
{
    FourCC ID           (4 Bytes) // SPRT
    Frame Count         (4 Bytes) // Amount of animation frames in current sprite (Not yet used)
    Frame Speed         (4 Bytes) // Speed of animation (Stored as f32)
    Atlas Name Length   (4 Bytes) // Length of parent atlas' name
    Atlas Name          (^ Bytes) // Name of parent atlas (Appended with 0-3 bytes of padding)
    Atlas Index         (4 Bytes) // Index of parent atlas (Only valid if bundle exported in order)
    Name Length         (4 Bytes) // Length of sprite name
    Name                (^ Bytes) // Name of sprite

    Source
        X               (4 Bytes) // x position of source rectangle
        Y               (4 Bytes) // y position of source rectangle
        Width           (4 Bytes) // Width of source rectangle
        Height          (4 Bytes) // Height of source rectangle

    Origin
        X               (4 Bytes) // Origin x point
        Y               (4 Bytes) // Origin y point

    Animation Frames[]
    {
        X               (4 Bytes) // x position of frame rectangle
        Y               (4 Bytes) // y position of frame rectangle
        Width           (4 Bytes) // Width of frame rectangle
        Height          (4 Bytes) // Height of frame rectangle
    }
}

EOF
    FourCC ID       (4 Bytes) //BEOF
```
