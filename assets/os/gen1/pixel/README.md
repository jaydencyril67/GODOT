# Gen 1 Google Pixel / Stock Android 4.0 Ice Cream Sandwich assets

All six Android 4.0 visual components for the Gen 1 Pixel simulator live together in this folder, matching the single-folder layout used by `assets/os/gen1/samsung/`.

## Required image files

- `lockscreen.jpg` — Android 4.0 lock screen
- `homescreen.jpg` — Android 4.0 home screen
- `appsdrawer.jpg` — Android 4.0 app drawer
- `controlcenter.jpg` — Android 4.0 quick settings / control panel
- `notification.jpg` — Android 4.0 notification shade
- `recentapps.jpg` — Android 4.0 recent-apps overview

Keep all six files directly inside this folder. Do not create a separate folder for each component.

These JPGs remain visual references for the Android 4-era interface. The live simulator uses native, interactive recent-app task cards; home-screen icons, app-drawer icons, notification entries, Quick Settings, swipe-to-unlock, Back, Home, and Overview are handled by Godot rather than relying on static screenshot taps alone. The `recentapps.jpg` file is retained as a visual reference and import asset.
