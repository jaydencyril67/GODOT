# DigitalWorld — Native Godot Game

DigitalWorld is an offline-first company-building and operations game implemented with **Godot 4 and GDScript**.

This repository contains the game itself, not a website wrapper. The running game uses native Godot Node3D, MeshInstance3D, Camera3D, WorldEnvironment, Control, and CanvasLayer nodes. It does not embed React, a browser, or Three.js.

## Current game flow

1. **Main menu** — Start Game, Load Game, Settings, and Exit Game.
2. **Founder setup** — enter the founder's name, company name, and choose a company insignia.
3. **Career preparation** — generate the walkable company campus and prepare the phone and creation workspaces.
4. **Company campus career home** — the campus is the persistent home world. The player explores it in eye-level first-person view while the career HUD displays the company insignia and name, available balance, in-game date, and Pause/Play control.
5. **Phone apps** — open the phone to access Explore, Worksite, Research, Staffs, Create, Products, Marketing, Media, Office, and Statistics. Worksite, Research, Staffs, and Explore open their destination lists inside the phone; available scenes launch from those lists and return to the same campus career.
6. **Career operations** — manage staff, research and product workspaces from the phone while retaining the same company career and campus session.

## Company campus

The career home is an **800 m × 600 m** walkable campus covering **480,000 m² (48 hectares)**. Its sixteen independent plots are arranged as four columns by four rows, with each plot measuring approximately **188 m × 138 m**. The original campus footprint is unchanged.

1. Main Entrance, Security & Reception
2. Administration & Corporate Offices
3. Staff Facilities, Cafeteria & Recreation
4. Parking, Roads & Transport
5. Research & Technology
6. Production & Operations
7. Logistics, Warehouses & Loading
8. Landscaping, Green Spaces & Utilities
9. Expansion Zone A
10. Expansion Zone B
11. Innovation Hub
12. Future Projects
13. R&D Extension
14. Manufacturing Expansion
15. Global Business Hub
16. Special Projects

The twelve-metre internal road corridors use a shared, merged asphalt surface with lightweight instanced lane markings; plot ground remains grass. Every plot owns a physical gate on each side that borders another plot. Gate fronts face the internal roads so neighbouring gates face one another, while the outer campus perimeter has no plot gates. Plot 1 starts accessible with its two internal entrances open; the other fifteen plots start locked.

The player begins on the central east-west asphalt aisle, outside the plots, and uses direct analogue joystick movement with an eye-only first-person camera. Existing careers keep their saved access and tenure for plots 1–8; plots 9–16 are added as locked plots. The campus is generated as part of the career loading flow and remains the home world while phone apps and external workspaces are opened.

The old ten-level headquarters showroom, its building tiers, office purchase/downgrade flow, and monthly headquarters rent system have been removed. Hiring is no longer locked behind owning or upgrading a headquarters building.

## Game timeline

Every new career begins on **1 January 2020**. The in-game calendar advances as the company operates; loading an existing career preserves its saved date. The campus Pause/Play control is connected to the career clock.

## Research and development

The company R&D centre uses funded engineering projects rather than Research Points or department percentage allocations.

- The CEO commissions a project against one or more of the phone technology components.
- Company funds are reserved for the approved project budget.
- Research department employees are assigned to projects; an employee cannot be allocated to multiple active projects.
- Project progress is based on productive engineering hours contributed by the assigned team's combined efficiency.
- Completed projects move to technical validation. Recorded findings must be approved before they are stored as company technology results.
- Project records and approved technology findings are saved with the company career.

The R&D workflow is an active foundation. Automatic technical-result generation and the integration of approved discoveries into phone-creation specifications are still in development.

## Native project structure

- **scenes/main.tscn** — Godot startup scene.
- **scenes/company_campus.tscn** — generated career home world.
- **scripts/digitalworld_game.gd** — main menu, founder setup, local career save/load, campus generation, phone routing, worksite and staff/research integration.
- **scripts/world/company_campus.gd** — campus world, first-person controls, career HUD, and in-phone app system.
- **scripts/world/digitalworld_staff_market.gd** — staff recruitment and management scenes.
- **scripts/digitalworld_research_manager.gd** — project funding, research staffing, engineering-work progress, and technical validation records.
- **scripts/research_allocation_dashboard.gd** — the R&D management centre interface (the filename is retained for scene compatibility).
- **assets/** — locally bundled image, insignia, font, and PBR texture resources.

## Local save data

Career information is stored in a Godot ConfigFile at **user://digitalworld_save.cfg**. It includes the founder and company identity, balance, game date, staff records, research projects and approved technology results, and product/worksite design data. Legacy headquarters-tier and rent fields are no longer read or written.

On Android, this is in the app's private user-data directory. It is not stored in a browser database or browser local storage.

## Build and validation

Open this repository's project.godot in Godot 4. The project is configured for the Compatibility renderer to support a broad range of mobile devices.

The DigitalWorld Godot Checks GitHub Actions workflow imports the project and smoke-tests the company campus career home, phone navigation, and the other major workspaces. Android APK builds are handled by the separate android-debug-apk.yml workflow.

## Implementation notes

The ten-level headquarters progression and its associated building/rent economy are no longer part of the career. The campus is now the single career home; the former bottom navigation destinations are available from its phone launcher. Products, Marketing, Media, and Statistics have phone entry screens ready for their future feature implementations.

The R&D workflow uses the existing technology components as its research catalogue. The 3D campus and other workspaces are built with Godot-native nodes and materials.
