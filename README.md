# BlueStacks War and Order cycle helper

A Windows PowerShell script that starts BlueStacks 5, sets the Android resolution through ADB, launches War and Order, and taps three configured screen coordinates. It repeats after a configurable interval, measured from the completion of the previous three-tap cycle.

## Requirements

- Windows with BlueStacks 5 installed at `C:\Program Files\BlueStacks_nxt`
- Android Debug Bridge enabled in BlueStacks under **Settings → Advanced**
- War and Order installed in the BlueStacks Android instance
- War and Order package ID: `com.camelgames.superking` (the script checks that it is installed)
- Windows PowerShell 5.1 or PowerShell 7+
- An internet connection; Git is optional because the ZIP can be downloaded directly

## Install and run (no Git required)

1. Install BlueStacks 5, then install and sign in to War and Order inside BlueStacks.
2. In BlueStacks, open **Settings → Advanced**, enable **Android Debug Bridge**, and save.
3. [Download the project ZIP](https://github.com/qodeseven/waoportal/archive/refs/heads/main.zip).
4. In File Explorer, open **Downloads**, right-click `main.zip`, and choose **Extract All**. Open the extracted `waoportal-main` folder.
5. Click the File Explorer address bar, type `powershell`, and press Enter. This opens PowerShell in that folder.
6. Run the script:

   ```powershell
   & ".\auto-monster\start-war-and-order.ps1"
   ```

   If Windows says the script is blocked, inspect it first, then unblock that file and run it:

   ```powershell
   Unblock-File ".\auto-monster\start-war-and-order.ps1"
   & ".\auto-monster\start-war-and-order.ps1"
   ```

The script does not require administrator privileges. The default BlueStacks folder is `C:\Program Files\BlueStacks_nxt`; if yours differs, pass `-BlueStacksDir 'C:\your\BlueStacks\folder'`. Keep the BlueStacks ADB port accessible only from the local machine. Watch the first cycle to confirm that the game opens and the taps reach the expected screens.

People who already use Git can optionally clone the project with `git clone https://github.com/qodeseven/waoportal.git`.

## Run with defaults

The defaults are 1080x1920 and these tap points: `1009x1520`, `114x1821`, and `540x1580`. The script waits 60 seconds after launching the game and waits one hour after each completed cycle. Press **Ctrl+C** to stop.

```powershell
& .\auto-monster\start-war-and-order.ps1
```

## Override settings

All click points use `XxY`; the screen size uses `WIDTHxHEIGHT`. The interval is in hours and may be fractional.

```powershell
& .\auto-monster\start-war-and-order.ps1 `
  -IntervalHours 0.5 `
  -BlueStacksDir 'D:\Apps\BlueStacks_nxt' `
  -ScreenSize '1080x1920' `
  -Click1 '1009x1520' `
  -Click2 '114x1821' `
  -Click3 '540x1580'
```

To change the initial game load wait:

```powershell
& .\auto-monster\start-war-and-order.ps1 -StartupWaitSeconds 90
```

The screen size is Android's coordinate space, not the outer Windows window dimensions. The script checks that each click falls inside the configured screen and stops if it cannot confirm the Android device, screen size, or installed package.

## Observed screen sequence

The three reference screenshots in `auto-monster/screenshots/` are all 1080x1920 and match the configured Android coordinate space:

1. [`screen-1-map.png`](auto-monster/screenshots/screen-1-map.png) is the game map. Tap `(1009,1520)` on the right-side scroll/map control to open the bottom activity panel.
2. [`screen-2-monster-panel.png`](auto-monster/screenshots/screen-2-monster-panel.png) shows the activity panel with the Monster tab selected. Tap `(114,1821)` on the Auto-Attack monster control to open its settings.
3. [`screen-3-auto-attack-dialog.png`](auto-monster/screenshots/screen-3-auto-attack-dialog.png) shows the Auto-Attack settings dialog. Tap `(540,1580)` on **Start Auto-Attack**.

These screenshots document the expected flow but the script currently does not compare live screens against them. They are included as public examples with the owner's approval. A visual screen guard would need to check stable UI regions at each step and stop on a mismatch.

## Safety and operation

- Keep BlueStacks ADB local to the machine; do not expose its debugging port to a network.
- The script uses static coordinates. Confirm them against the current game layout and keep the Android resolution and orientation fixed.
- The script does not recognize the game screen visually; it assumes the expected game screen is present when each tap sequence runs.
- Stay with the first run to confirm that the game has loaded and each point does what you expect.
- The loop runs until stopped with **Ctrl+C**.

## Repository access

If this repository is public, anyone can view and clone the script. GitHub authentication controls who can push changes; a public repository cannot require a password to view or clone. Do not put passwords, tokens, or account credentials in this repository.
