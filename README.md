# DigitalWorld — Native Godot Game

DigitalWorld is an offline-first company-building and operations game implemented with **Godot 4 and GDScript**.

This repository contains the game itself, not a website wrapper. The running game uses native Godot Node3D, MeshInstance3D, Camera3D, WorldEnvironment, Control, and CanvasLayer nodes. It does not embed React, a browser, or Three.js.

## Current game flow

1. **Main menu** — Start Game, Load Game, Settings, and Exit Game.
2. **Founder setup** — enter the founder's name, company name, and choose from the 50 DigitalWorld insignia names.
3. **Company territory** — a fixed-angle 3D view of ten development plots arranged in five columns and two rows. The starting headquarters is on the centre plot.
4. **Headquarters interior** — tap the headquarters to open the roof-off, fixed-camera operations cutaway.
5. **Headquarters development** — view ten building tiers from Starter Headquarters through Mega Skyscraper in a 3D showroom, then save a higher tier.

## The starting headquarters

The interior is built as a native Godot 3D scene and keeps the three original DigitalWorld departments:

- **Programming Studio:** workstations, monitors, keyboards, office chairs, shared bench, and plants.
- **Manufacturing:** roller conveyor, assembly stations, machine cabinets, control displays, and status lights.
- **Packaging & Stacking:** dispatch bench, carton stacks, and warehouse shelving.

The cutaway has low exterior walls, department partitions, floor guides, room signs, visible lighting, and a fixed isometric-style camera. It intentionally has no first-person controller or movement joystick.

## Research and development

The company R&D centre uses funded engineering projects rather than Research Points or department percentage allocations.

- The CEO commissions a project against one or more of the 37 phone technology components.
- Company funds are reserved for the approved project budget.
- Research department employees are assigned to projects; an employee cannot be allocated to multiple active projects.
- Project progress is based on productive engineering hours contributed by the assigned team's combined efficiency.
- Completed projects move to technical validation. Recorded findings must be approved before they are stored as company technology results.
- Project records and approved technology findings are saved with the company career.

The R&D workflow is an active foundation. Automatic technical-result generation and the integration of approved discoveries into phone-creation specifications are still in development.

## Native project structure

- **scenes/main.tscn** — Godot startup scene.
- **scripts/digitalworld_game.gd** — main menu, founder setup, local career save/load, screen flow, R&D integration, settings, and upgrade showroom UI.
- **scripts/digitalworld_research_manager.gd** — project funding, research staffing, engineering-work progress, and technical validation records.
- **scripts/research_allocation_dashboard.gd** — the R&D management centre interface (the filename is retained for scene compatibility).
- **scripts/world/hq_world.gd** — the ten-plot world and headquarters selection.
- **scripts/world/hq_cutaway.gd** — the roof-off production interior.
- **scripts/world/hq_building_factory.gd** — the starter headquarters and ten-tier building models.
- **assets/** — locally bundled image and PBR texture resources.

## Local save data

Career information and the purchased headquarters level are stored in a Godot ConfigFile at **user://digitalworld_save.cfg**.

On Android, this is in the app's private user-data directory. It is not stored in a browser database or browser local storage.

## Build and validation

Open this repository's project.godot in Godot 4. The project is configured for the Compatibility renderer to support a broad range of mobile devices.

The DigitalWorld Godot Checks GitHub Actions workflow imports the project and smoke-tests main-scene startup. Android APK builds are handled by the separate android-debug-apk.yml workflow.

## Implementation notes

The original DigitalWorld prototype exposed additional management controls (Build, Downgrade, Demolish, Create, Inventory, History, and Staffs) without implementing their underlying economy or department simulation. Some controls remain future-facing entries; they do not pretend to perform systems that do not yet exist.

The R&D interface has replaced the old percentage-allocation and Research Point dashboard. The existing 37 technology components remain the research catalogue.

The 3D assets have been rebuilt with Godot-native meshes and materials. The original layout, departments, object placement, camera presentation, upgrade progression, and save flow are being carried across without bringing the web application runtime into the game.