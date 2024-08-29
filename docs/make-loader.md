# Making a Loader

Building a loader for sprite bundles is a very easy task, all data is written in 4 byte chunks and each section (Atlas, Sprite, Etc) is identified by a simple [FourCC](https://en.wikipedia.org/wiki/FourCC) style code from one of the below...
- `LSPX` - Bundle header, contains basic information for the bundle and should always be first!
- `SPRT` - Sprite, containing all information for a sprite
- `ATLS` - Atlas, containing all information for a sprite
- `BEOF` - Bundle end of file, identifies where the end of file is, should ALWAYS be at the end!

For a more in depth breakdown of the file structure and what order to read data; please see the [bundle structure](/docs/bundle.md) documentation, some simple loaders can also be found in the [loaders](/loaders) directory!

If this does not cover your needs and you wish to make one for you prefered language, graphics library, mental torture, etc; a loader will follow the same structure as shown by the below psuedo code...

> [!IMPORTANT]
> When reading data that may not always align to 4 bytes (EG. Names) you will need to align to the next 4th byte!

```js
// Basic Example
function LoadBundle () {
    OpenFile();

    header = ReadFourBytes()

    if (header == "RSPX") {
        // Process bundle data
    }

    while (header != "BEOF") {
        header = ReadFourBytes()

        if (header == "ATLS") {
            // Process atlas data
        }

        if (header == "SPRT") {
            // Process sprite data
        }
    }
}
```

Nice and simple! However the complexity comes in interpreting the data for your graphics library whether that be raylib, SDL or intergrating into an existing game engine.

With all data being aligned to 4 bytes; it is easy to skip over data you may need, for example you may not need the name of each atlas to be loaded; simply skip over that data!

```js
// Step by Step Example
function LoadBundle () {
    OpenFile ()

    header = ReadFourBytes ()

    if (header == "RSPX") {
        // Process bundle data
        version = ReadInteger ()
        atlas_count = ReadInteger ()
        sprite_count = ReadInteger ()
        atlas_size = ReadInteger ()
    }

    while (header != "BEOF") {
        header = ReadFourBytes ()

        if (header == "ATLS") {
            sprite_count = ReadInteger ()
            name_length = ReadInteger ()
            name = ReadString ()

            AlignOffset ()

            data_size = ReadInteger ()
            data = ReadBytes ()

            AlignOffset ()
        }

        if (header == "SPRT") {
            animation_frame_count = ReadInteger ()
            animation_speed = ReadFloat ()

            atlas_name_length = ReadInteger ()
            atlas_name = ReadBytes ()

            AlignOffset ()

            atlas_index = ReadInteger () // Will match the nth exported atlas

            name_length = ReadInteger ()
            name = ReadBytes ()

            AlignOffset ()

            source.x = ReadFloat ()
            source.y = ReadFloat ()
            source.width = ReadFloat ()
            source.height = ReadFloat ()

            origin.x = ReadFloat ()
            origin.y = ReadFloat ()

            // NOTE: Not yet used!
            for animation_frame_count {
                frame.x = ReadFloat ()
                frame.y = ReadFloat ()
                frame.width = ReadFloat ()
                frame.height = ReadFloat ()
            }
        }
    }
}
```

> [!WARNING]
> Saved strings are NOT null terminated when exported and this WILL need to be manually added when loading in languages such as C!

Following these examples you will be able to load all the data in from a sprite bundle and store this in your preferred way.

> [!NOTE]
> While the official sprite bundler will export LSPX, ATLS, SPRT, BEOF; in that order, only LSPX and BEOF are required to be in that order, sprites and atlas' do not need to be stored in any order!
