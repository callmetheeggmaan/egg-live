# Egg LIVE — 25 additional interactions

Additive pack: all 69 original action IDs remain available. Existing profiles are preserved. New effects have their own IDs and the same viewer notifications, sounds and timed HUD system.

## Help the player

| Interaction | Default duration | What it does |
|---|---|---|
| Ammo drip | 15 seconds | Adds one round to your current magazine every half second. |
| Blood bank: heal on kills | 20 seconds | Each kill restores 15 health, up to your normal maximum. |
| Bottomless magazine | 10 seconds | Keeps the current magazine full; does not refill reserves. |
| Bounty hunt | 20 seconds | Earn 250 bonus points per zombie kill. |
| Bullet bounty: ammo on kills | 20 seconds | Each kill adds three rounds to your current magazine. |
| Clutch recovery | 20 seconds | Once during the window, recover half health when below 25%. |
| Interest bank | 20 seconds | Earn 10% of your points every two seconds, capped at 500 per payment. |
| One-hit zombies | Instant | Sets current ordinary zombies to one health; excludes the Egg Warden. |
| Refill lethal grenades | Instant | Refills an already-owned lethal grenade slot to four. |
| Refill tactical grenades | Instant | Refills an already-owned tactical grenade slot to two; requires map support. |
| Regeneration | 15 seconds | Restores ten health each second. Normal zombie damage still applies. |
| Ring of safety | Instant | Eliminates ordinary zombies within 256 game units; excludes the Egg Warden. |

## Create chaos

| Interaction | Default duration | What it does |
|---|---|---|
| Floor Is Lava | 12 seconds | After a two-second grace period, being on the ground costs five health per second. Jump to avoid it; cannot directly down you. |
| Hot Potato: weapon shuffle | 15 seconds | Switches among your owned guns every two seconds. Requires two guns. |
| Keep moving! | 15 seconds | Standing still costs five health per second; cannot directly down you. |
| Leaky magazine | 15 seconds | Loses one magazine round every half second. |
| Leaky wallet | 15 seconds | Loses up to 50 points each second; never creates negative points. |
| Magazine roulette | Instant | Randomizes rounds in the current magazine from one to its normal capacity. |
| Personal-space penalty | 15 seconds | Lose up to 25 points each second an ordinary zombie is very close. |
| Red Light / Green Light | 15 seconds | Alternates three-second phases. Moving during red costs five health, never the final health point. |
| Reload tax | 20 seconds | Each detected magazine reload costs up to 250 points. |
| Reverse toll | 15 seconds | Moving backwards costs up to 50 points each second. |
| Standing tax | 15 seconds | Standing upright costs up to 25 points per second. Crouch or go prone to avoid it. |
| Weapon jam | 12 seconds | Empties the current magazine every three seconds. Reserves stay intact. |
| Zombie medic aura | 15 seconds | Nearby ordinary zombies regenerate 10% health each second. |

## Compatibility and checks

The new native scripts compile with BO3 Mod Tools. All 52 automated checks pass, including all 25 routes and alphabetical Help/Chaos grouping. In-game testing and runtime installation are pending the owner’s match-restart response. Do not describe compilation as completed gameplay verification.

Grenade refills require an owned, map-supported slot. Hot Potato requires two owned primary guns. Ordinary-zombie effects exclude the Egg Warden. Non-lethal challenge penalties never directly down the player; normal zombie damage remains enabled. New timed effects stack with matching gift top-ups and share the existing five-row timer HUD. Some help and chaos actions deliberately counteract one another when active together.

## Research

The spectator reward/disruption pattern was informed by the official [Crowd Control customization guide](https://crowdcontrol.live/blog/how-to-customize-your-crowd-control-effects-2026-update) and [BO3 setup/compatibility guide](https://crowdcontrol.live/guides/blackops3zombies). These are design references; no third-party effect implementation or asset pack was installed. Native API behavior was checked against installed official BO3 Mod Tools scripts, including _zm_spawner, _globallogic_score, _zm and callbacks_shared.
