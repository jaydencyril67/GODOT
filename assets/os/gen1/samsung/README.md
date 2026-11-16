# Gen 1 Samsung TouchWiz Nature UX assets

These five Galaxy S III-style Android 4.x screen references are loaded locally by the Gen 1 Samsung simulator.

## Required image files

- `lockscreen.jpg` — TouchWiz swipe-to-unlock lock screen
- `home_screen.jpg` — TouchWiz Nature UX home screen and launcher dock
- `app_drawer.jpg` — horizontally paginated TouchWiz application drawer (provided capture shows page 1 of 2)
- `notification.jpg` — combined Quick Settings toggles and notification panel
- `recent_apps.jpg` — Android recent-apps task switcher

## Integration notes

- Keep these exact filenames; the simulator loads them from this folder.
- JPG is supported and does not need conversion to PNG.
- Godot handles touch input, swipe-to-unlock, app shortcut taps, pull-down notifications, panel dismissal, and the Back/Home/Overview navigation controls.
- These images are visual reference layers rather than interactive source artwork.
