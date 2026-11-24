# Godot-ready Android System UI assets

This folder contains Godot-importable SVG adaptations of the Android vector/drawable resources already present in this repository.

## Status bar
- `status-bar/status_bar_atlas.svg` is built from the source Android battery, cellular-signal, Wi-Fi, Bluetooth, and roaming vector paths in `assets/system-ui/android-systemui/Status-Bar/`.
- `scripts/status_bar_asset_library.gd` exposes ten complete status-bar style presets and the corresponding atlas textures.

## Lock-screen notifications and media
- `notifications/notification_source_icon_atlas.svg` uses source vector paths from the notification category and action icon folders.
- `notifications/notification_icon_atlas.svg` supplies the previous/next/play/pause and camera glyph assets used by the media card and camera shortcut.
- The card and shortcut SVG surfaces are Godot-ready adaptations of the notification background drawable resources.
- App icons and music-service logos continue to load from their original bundled repository assets.
- The music-player UI-kit screenshots remain visual references; they are not stretched into live notification cards.

## Clocks
- Analog lock-screen styles load 41 images from `assets/lock-screen/clocks/analog/` through `scripts/lock_screen_asset_library.gd`.
- Digital lock-screen faces are built from JSON definitions in `research/XMorphClock/Clock-Faces/Definitions/` and fonts in `research/XMorphClock/Fonts/Files/`.
- XMorph widget layouts are loaded from `research/XMorphClock/Widgets/Definitions/` by `scripts/ui/xmorph_widget_asset_library.gd`.

## Lock-screen PIN entry
- `pin-entry/pin_backspace.svg` is a Godot-ready explicit-color adaptation of the AOSP lock-screen backspace vector in `assets/lock-screen/aosp/SVG/ic_backspace_24dp.svg`.
- The PIN preview reuses the AOSP locked, unlocked and fingerprint SVGs in `assets/lock-screen/aosp/SVG/`.
- The AOSP lock-to-unlock and fingerprint animation exports remain in `assets/lock-screen/aosp/Animations/`; the PIN preview uses a short native Godot fade for its screen handoff.
