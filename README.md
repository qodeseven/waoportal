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

## Apple Mac users

This PowerShell script is for **Windows and BlueStacks 5**. It calls Windows-only files (`HD-Adb.exe` and `HD-Player.exe`) from a Windows install path, so it will not run on macOS as written.

BlueStacks Air is BlueStacks' Mac option for Apple Silicon. BlueStacks lists an M1–M4 chip and at least 8 GB RAM as minimum requirements; 16 GB RAM is recommended. See [BlueStacks Air installation, requirements, and game setup](https://support.bluestacks.com/hc/en-us/articles/32272892398093-How-to-install-and-play-games-with-BlueStacks-Air-on-Mac).

A Mac user can install BlueStacks Air and War and Order to inspect or manually verify the game screens. The current official BlueStacks Air instructions do not document an ADB enable/connect workflow, so this project does not yet include a Mac automation script. To test the automated taps, use a Windows PC with BlueStacks 5 and follow the Windows instructions above. A separate Mac version would need a confirmed ADB connection method for BlueStacks Air first.

## Run with defaults

The defaults are 1080x1920 and these tap points: `1009x1520`, `114x1821`, and `540x1580`. After launching the game, the script checks every 5 seconds for up to 3 minutes for Android to report War and Order as the foreground activity. If it does not, the script stops before tapping. If the script had to start BlueStacks, it then pauses for you to close any splash, promotion, or purchase screens. Press any key only after the normal game screen is visible. After each completed tap sequence, it waits one hour before the next cycle. Press **Ctrl+C** to stop.

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

To change the foreground polling timeout or polling interval:

```powershell
& .\auto-monster\start-war-and-order.ps1 -GameStartupTimeoutSeconds 240 -PollIntervalSeconds 5
```

The screen size is Android's coordinate space, not the outer Windows window dimensions. The script checks that each click falls inside the configured screen and stops if it cannot confirm the Android device, screen size, installed package, or foreground activity. The activity check confirms Android reports the game as foreground; it does not inspect screen pixels or prove that all game loading animations have finished.

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
