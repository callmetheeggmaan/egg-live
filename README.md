# Egg LIVE — test preview

Configurable local viewer-style interactions for Black Ops III Zombies.

**This preview is locked to synthetic test gifts. Real TikTok LIVE connectivity is disabled pending validation.** It does not require paid gifts or paid hosting.

## Download

Get the **Windows ZIP** from the [test-preview release](https://github.com/callmetheeggmaan/egg-live/releases/tag/v0.2.0-preview.1), extract it completely, and run `Start-Egg-LIVE.cmd`. Node, Python and dependencies are included. The source ZIP is for developers.

Install the in-game Egg LIVE receiver as well. The preview ZIP includes a receiver for local installation; the Steam Workshop link will be added here after publication. The Workshop item alone does not install the companion.

Choose your BO3 folder in the panel, save your settings, then use **Open BO3 with the mod** while BO3 is closed. Enter a solo/private Zombies match, configure a gift action, save, click **Try in BO3**, and return focus to the game. See `START-HERE.txt` for installation and troubleshooting.

## Features

- Gift picture library and configurable host effects, cooldowns and combo caps.
- +1/+10/+50 nearby zombie requests, point/ammo rewards and movement challenges.
- Sequential viewer notifications, trigger sound volume and mute.
- Local foreground-only F10 bridge; no process-memory injection.

## Limits and release status

33 automated checks pass and the receiver has been tested locally on Eggstinction and The Giant. Clean-folder portable startup was checked using bundled runtimes; a separate clean-PC Workshop subscription test remains pending.

Native actor limits and clear space constrain nearby spawning. +50 does not guarantee 50 simultaneous or instantaneous zombies. Nearby spawn is unavailable on dog rounds. Perks, powerups and custom-map compatibility depend on map assets and scripts. BO3 supports one gameplay mod at a time.

Real LIVE gifting has **not** been validated. Keep this version in test mode. It is an experimental preview, not a verified LIVE release.

## Source and licenses

See `BUILDING.txt`, `LICENSE`, `THIRD-PARTY.txt` and the pinned `companion/package-lock.json`. Egg LIVE source is distributed under AGPL-3.0-or-later; third-party software retains its respective licenses.

Unofficial and not affiliated with TikTok/ByteDance, Activision, Treyarch or Valve.
