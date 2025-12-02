<div align="center">
  <h1><code>Shavit Fixed Camera</code></h1>
  <p>
    <strong>90's-inspired fixed camera style for shavit's CS:S bhop timer including camera rotation system and more</strong>
  </p>
</div>

[![Youtube Video](https://github.com/user-attachments/assets/26b380df-fd56-4ff4-b5e6-d89d2b79796b)](https://www.youtube.com/watch?v=dWhMiE7PMRY)

---

## Features

- **Fixed camera** with 4-way rotation (behind/left/front/right) with diagonal camera angles mode included
- **Automatic binds**: Shift / E keys are binded automatically to rotate the camera (toggleable)
- **Manual binds**: If you don't like the default keybinds you can bind `fcleft` / `fcright` to any key you want to rotate the camera
- **Interactive settings menu**: Change FOV, toggle binds and night vision directly in the menu
- **Shavit integration**: Seamless with shavit's timer

## Installation

> **⚠️ IMPORTANT NOTICE:**  
> Add `bash_bypass` to your Fixed Camera style's specialstrings to avoid Bash warnings:
> ```
> "specialstring" "fixedcamera; bash_bypass"
> ```

1. **Compile**: `spcomp -include shavit-style-fixedcamera.sp` (or download the compiled plugin directly from the [releases](https://github.com/NSchrot/shavit-style-fixedcamera/releases) page)
2. **Install**: Place the compiled `.smx` in `addons/sourcemod/plugins/`
3. **Configure**: Add your style with `"specialstring" "fixedcamera"` in your shavit-styles.cfg
4. **Restart your server**

## Commands & Controls

| Command         | Key/Usage     | Description                              |
|-----------------|---------------|------------------------------------------|
| `/fcmenu`       | -             | Open the Fixed Camera settings menu      |
| `/fchelp`       | -             | Show all Fixed Camera commands and binds |
| `/fccamera`     | -             | Opens Camera Rotation Menu               |
| `/fcdelay `     | -             | Opens Camera Delay Offset Menu           |
| `/fcdiagonal`   | -             | Toggle diagonal camera angle             |
| `/fcnvg`        | -             | Toggle night vision                      |
| `/fcfov <val>`  | -             | Set camera FOV                           |
| `/fctogglebinds`| -             | Toggle auto-binded camera rotation       |
| `+speed`        | **Shift**     | Rotate camera left (if enabled)          |
| `+use`          | **E**         | Rotate camera right (if enabled)         |
| `fcleft`        | -             | Rotate camera left                       |
| `fcright`       | -             | Rotate camera right                      |
| `fc180  `       | -             | Rotate camera 180 degrees                |


## Usage

1. Select **Fixed Camera** style in the `/style` menu
2. Camera switches to third-person automatically
3. Use **Shift / E** or manual commands to rotate the camera
4. Use `/fcmenu` for all settings (Camera Rotation, FOV, Binds, Night Vision, etc)
5. Use `/fchelp` for a quick in-game reference of all commands

## Menu System

- **Main Menu**:  
  - Camera Controls Menu
  - FOV Menu
  - Toggle Shift/E Binds  
  - Toggle Night Vision  
  - Commands Menu

- **Camera Controls Menu**:  
  - Full Camera Rotation options (Rotate Left, Right, 180, Toggle Diagonal Angles)

- **FOV Menu**:  
  - FOV options

- **Commands Menu**:  
  - Shows available commands and binds
  - Accessible via `/fchelp`, `/fccommands` or `/fcbinds`


## Configuration Example

Add to your `shavit-styles.cfg`:

```json
"<styleNumber>"
{
    "name"              "Fixed Camera"
    "shortname"         "Fixed"
    "clantag"           "Fixed"
    "htmlcolor"         "FFFFFF"
    "command"           "fc; fixed; fixedcamera"
    "specialstring"     "fixedcamera; bash_bypass"
    // ... other style settings
}
```

## ConVars

| ConVar                          | Default       | Description                        |
|---------------------------------|---------------|------------------------------------|
| `ss_fixedcamera_specialstring`  | `fixedcamera` | Special string for style detection |

## Requirements

- SourceMod 1.10+
- Shavit Timer
- Counter-Strike: Source
- SDKHooks extension
- ClientPrefs extension

## Troubleshooting

- **Camera is not switching to fixed mode when entering style**:  
  Ensure your style configuration has `"specialstring" "fixedcamera"` inside shavit-styles.cfg.

- **Camera Rotation binds not working**:  
  Type `/fctogglebinds`, ensure that it is enabled and also check if your **Shift / E** keys are bound to +speed and +use respectively. 
  It is also possible to bind the camera controls to a key manually (`/fchelp` to see binds and commands)

- **Can't switch weapons**:  
  This is a limitation of the third-person implementation, which uses the Spectator Camera. Unless the camera system is somehow changed, this can't be fixed.
  The workaround is to get a weapon by typing it's related command: `/glock`, `/usp`, etc.


---


