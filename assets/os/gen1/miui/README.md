# Xiaomi MIUI V4 — Generation 1

This folder contains the Generation 1 Xiaomi MIUI V4 reference screens, based on Android 4.0 Ice Cream Sandwich.

Reference images currently present:
- `lockscreen.jpg`
- `homescreen.jpg`
- `appdrawer.jpg`
- `notification.jpg`
- `recentapps.jpg`

The OS preview routes `notification.jpg` only to Notifications. No `controlcenter.jpg` is present, so Control Center displays the pending-reference placeholder instead of incorrectly reusing the notification screenshot. Add `controlcenter.jpg` when its actual screenshot is available.

MIUI V4 remains separate from Samsung TouchWiz Nature UX and Google Stock Android 4.0. The live simulator builds a native, interactive recent-app task list; its launcher and app-drawer icons, notification entries, Quick Settings, brightness control, swipe-to-unlock, Back, Home, and Overview are handled by Godot. `recentapps.jpg` is retained as a visual reference and import asset.
