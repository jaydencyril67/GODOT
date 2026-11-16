# Clock widget — Dot Matrix

## Sourced design

The first clock design is based on the dot-matrix clock direction documented by Tessera:

- Project: https://github.com/MalicKAbdullah/tessera
- Reference: Dot Matrix clock design (Doto-inspired dot display)
- Repository licence: MIT

The DigitalWorld implementation is an independent Godot rendering. It does not copy Tessera source code, images, or bundled font files. The time digits are drawn from an original 5×7 dot grid using Godot canvas primitives.

## DigitalWorld implementation

- Widget type: `clock`
- Renderer: `scripts/generated_phone_ui.gd`
- Live local time with a date line
- Theme-aware illuminated dots and subdued unlit dots
- No network access or external runtime assets

Tessera is credited here as the design-source reference. Its name and marks remain the property of their respective owners; no affiliation or endorsement is implied.
