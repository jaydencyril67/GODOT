# Godot-ready System UI assets

This folder contains Godot-compatible SVG conversions for selected Android SystemUI and QuickSettings source vectors. The source XML resources remain untouched.

- Status-bar icon silhouettes were converted from `assets/system-ui/android-systemui/Status-Bar` (Apache-2.0, see `assets/system-ui/android-systemui/SOURCE-LICENSE`).
- Notification category icon silhouettes were converted from `assets/system-ui/Notifications/Category-Icons` (MIT, see `assets/system-ui/Notifications/SOURCE-LICENSE`).
- Notification card geometry follows `assets/system-ui/Notifications/Backgrounds/bg_notif_card.xml` and its Android notification layout reference.
- Media controls and the camera glyph are original simple SVG artwork for the Godot preview.
- Analog clock face and hand PNGs are used from `assets/widgets/clock` (CC0, see its SOURCE.md).

The SVG atlases are decorative assets only. Dynamic values such as time, notification titles, track names, and playback progress remain live UI data.
