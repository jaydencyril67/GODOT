# DigitalWorld OS UI bridge notices

The Android bridge is first-party DigitalWorld code and uses the Godot Android
plugin v2 API.

At build time it links against `org.godotengine:godot:4.7.2.stable`, the Godot
Engine Android library, distributed under the MIT License by Godot Engine
contributors. See https://github.com/godotengine/godot/blob/master/LICENSE.txt.

The local preview document is bundled inside the DigitalWorld project. It does
not load remote scripts, stylesheets, fonts, images, frames, or network data.
