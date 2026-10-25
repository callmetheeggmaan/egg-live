# Egg LIVE test checklist

Updated: 23 October 2026. TikTok disconnected; local synthetic events only.

## Verified in BO3

- [x] +1, +10 and +50: exact additional actor count and placement beside the host on the same floor.
- [x] Spawn worker starts independently of the normal round timer.
- [x] Ammunition, magazine/reserve changes, owned-gun switching and Ammo Rain refill/expiry.
- [x] Points, health, nonlethal damage and combo packages.
- [x] Movement speeds, overlap handling, hop, stance and camera changes; timer restoration.
- [x] Real zombie health/speed changes and exact kill counts.
- [x] Seven perk grants and map-available perks; native power-up pickups.
- [x] Down Host enters native last stand/death on The Giant.
- [x] No shooting, no jumping, no aiming and no melee: actual input compared against normal input.
- [x] Centred notification: layered gold/purple effect name, cyan sender line; fades and destroys its HUD elements.
- [x] Actual TikTok username survives routing and sanitised native packet generation in automated tests. Synthetic events visibly say Test viewer.
- [x] 24 automated companion tests pass, including sender identity, gift combos, duplicates, cooldowns, bounds, pause, queue and acknowledgements.
- [x] No Sprint: corrected SDK movement-state flag and maintained restriction. Actual held-key retest passed: normal 284.788 / sprint on; blocked 186.097 / sprint off; restored 284.086 / sprint on.
- [x] Blurry vision: corrected to native screen blur; visible effect and automatic clearing inspected in BO3.

Roulette was smoke-tested with a bounded random choice. Its underlying actions were checked separately; every random sequence has not been exhausted.

## Measured nearby spawn timings

Timings start at the in-game request, excluding TikTok/network/companion transport latency.

| Map | Preset | First nearby placement | Full batch delivered |
| --- | --- | --- | --- |
| Eggstinction | +1 | 150 ms | 250 ms |
| Eggstinction | +10 | 150 ms | 750 ms |
| Eggstinction | +50 | 150 ms | 6.0 s |
| The Giant | +1 | 150 ms | 250 ms |
| The Giant | +10 | 150 ms | 750 ms |
| The Giant | +50, two crowded consecutive tests | 1.2–2.0 s | 10.5–11.75 s |

The fixture killed delivered zombies to release actor slots. Full-batch timings are controlled measurements, not a promise that 50 can be alive at once. All placements were checked after teleport, rather than inferred from acceptance or callbacks alone.

The Giant +50 tests missed the under-one-second first-placement target. Native actor limits and clear nearby space still apply. Further zombies wait for capacity; this limitation is unresolved for a guarantee of all 50 instantaneously.

The full Eggstinction functional audit completed with zero failed assertions. The Giant's earlier full effect audit passed the functional checks; its spawn-latency failure is retained above. Testing two maps does not certify every custom map. Nearby presets reject dog rounds; perk availability is map-dependent.

## Actual input evidence

- Normal fire: one shot; No Shooting: zero shots with input detected.
- Normal jump: 37.8224 units peak height; No Jump: zero, with input detected.
- Normal aim: ADS 1; No ADS: ADS 0, with input detected.
- Normal melee: melee state 1; No Melee: state 0, with input detected.
- Held-key retest passed all three stages with input detected. Original failed run retained in work/egg-live-sprint-first.log; corrected run in work/egg-live-sprint-pass.log.

## Evidence

- work/egg-live-measured-pass.log: full Eggstinction functional audit.
- work/egg-live-measured-inputs.log: actual control comparisons.
- work/egg-live-standard-effects.log: The Giant functional checks, aim and Down Host.
- work/egg-live-standard-instant-final.log and work/egg-live-blur-recheck.log: independent nearby-spawn checks and timings.
- trigger-notification.png: actual in-game notification screenshot.

## Release state

- [x] Normal receiver rebuilt and installed after the successful manual sprint test; QA automation and invulnerability removed.
- [x] Temporary input-test bindings removed; inbox cleared and completed protected game closed.
- Real LIVE/gift testing: deferred by owner; no paid gifts sent.
- Workshop upload and permanent companion download link: pending. No public subscription link exists.


Blur proof: blur-active.png and blur-restored.png show the actual before/after timer result.





## Compact gift panel verification

- [x] Gift actions use a compact two-column desktop grid (three on wide screens).
- [x] 728 unique gifts preloaded with source IDs, names, coin values and remote icon URLs.
- [x] Visual gift search, selection and creation of a second action card checked in the browser.
- [x] Saving automatically enables with a connected mod, or waits and enables when its heartbeat returns.
- [x] Explicit Pause cancels automatic enabling; tests cannot falsely report a skipped action as queued.
- [x] Previously connected game can receive a queued test after returning from the panel; stale actions expire.
- [x] Existing Rose mapping preserved; temporary Galaxy test card discarded.
- [x] TikTok remains disconnected. Live room catalogue refresh is implemented but not live-tested.

Catalogue: Euler Stream public US reference snapshot, 23 October 2026. Regional or newer gifts are merged from the room catalogue when LIVE connects. This is not a claim that one region contains every worldwide gift.


## Trigger queue and sounds — 24 October 2026

- [x] Independent presentation worker: successful effects ACK immediately; messages play one at a time, about 2.6 seconds each.
- [x] Original help/chaos/major PCM cues compiled into the mod's own three-alias sound bank. Native bank load succeeded with no missing-cue errors.
- [x] Owner heard cues and reported too quiet. Alias level increased from 75 to 90; normal build recompiled and used for the second burst. Final preferred loudness remains subjective.
- [x] Five native effects applied before the first banner finished, with the exact +900 net points result.
- [x] Five distinct fixture sender/effect pairs shown in order; only five HUD layers at once, then all destroyed.
- [x] Same pending sender/action/amount groups with xN; different senders stay separate.
- [x] Ten waiting messages maximum; 30-second visual expiry. Overflow/expiry appears in companion activity without retrying effects.
- [x] Pause clear signal, native down/death and queue/HUD cleanup passed. Spawn resets queue and cancels the previous worker; fresh normal launch had no previous messages.
- [x] Normal installed receiver: five synthetic gifts routed through GiftRouter and real GameBridge, five exact native ACKs and five sequential messages. No QA automation in this build.
- [x] 28 automated checks pass, including five distinct gifts, duplicate suppression, streak cap, queue backpressure and Pause control packet.
- [x] User's Rose and Heart Me mappings preserved. TikTok disconnected throughout.

Evidence: work/egg-live-notifications-first.log (native fixture, zero failures),
work/egg-live-normal-notifications.log (normal receiver), work/egg-live-normal-burst.json
(real bridge ACKs), queued-notification.png (native screenshot).
These are synthetic local tests, not a real paid LIVE validation. Initial sound heard
by owner; all three aliases are bank-loaded, but subjective listening for each cue
and the final louder mix is not certified by the automated checks.

## Panel volume and mute — 24 October 2026

- [x] Compact Trigger volume slider above the gift grid, 0–100% in 10% steps; separate Mute switch remembers the chosen level.
- [x] Automatic partial save preserves gift mappings, cooldowns and action queues, without enabling actions or connecting TikTok.
- [x] Local persistence across companion restart and browser reload checked; 70% unmuted restored at handoff.
- [x] Separate native control packet with matching acknowledgement; older acknowledgements cannot confirm newer settings. Settings resync after reconnect.
- [x] Real normal BO3 receiver acknowledged 40%, 100%, 0%, muted 70%, unmuted 70%.
- [x] Synthetic point triggers at 40% and 100% selected the correct sound aliases. Zero volume and mute produced text/effect acknowledgements with no cue call. Unmuting selected the 70% cue again.
- [x] Official soundbank build includes gain variants of the original cues. Only Egg LIVE trigger aliases change, with no game master/bus-volume changes.
- [x] 32 automated checks pass, including validation, audio packets, pending-action isolation, stale ACK rejection, reconnect and endpoint persistence.
- [x] Normal mod installed; no QA fixture added for this test. TikTok disconnected; Rose/Heart Me mappings preserved.

Evidence: work/egg-live-volume-native.log and work/egg-live-volume-results.json;
trigger-volume-panel.png shows the finished panel. Sound playback selection and
silence are verified by native cue-call logs; preferred subjective mix is user-adjustable.

## Public test preview — 24 October 2026

- [x] Owner approved public GitHub and Steam Workshop test-preview publication.
- [x] GitHub prerelease v0.2.0-preview.1 published with Windows/source/Workshop ZIPs and checksums.
- [x] Public Windows download fetched without authentication; SHA256 matches tested package.
- [x] Workshop item 3826163025 uploaded with official launcher and made Public. Anonymous Steam API result 1, visibility 0, banned 0.
- [x] Subscribed and downloaded on development PC; all eight compiled files match tested build.
- [x] Companion discovered subscribed receiver ID 3826163025.
- [x] README/release notes cross-link both public downloads. Profiles and logs excluded.
- [x] Real LIVE remains locked (testOnly=true), TikTok disconnected, owner mappings preserved.
- [ ] Independent clean-PC test and real LIVE validation remain pending.

Links: https://github.com/callmetheeggmaan/egg-live/releases/tag/v0.2.0-preview.1
https://steamcommunity.com/sharedfiles/filedetails/?id=3826163025
Evidence: outputs/releases/PUBLISHED.txt, steam-workshop-public-details.json,
RELEASE-REPORT.json and steam-workshop-published.png.

## Stacking timers and faster gift delivery — 24 October 2026 (candidate)
- [x] Stable-ID streak frames dispatch incremental counts immediately, not only final frame.
- [x] Final/duplicate/out-of-order frames do not add duplicate effects.
- [x] Timed combos combine into one exact duration request; separate gifts top up inside cooldown.
- [x] Native same-effect deadlines extend from remaining time; distinct effects keep separate timers.
- [x] Opposing speed effects replace one another and restore the original movement baseline.
- [x] Per-rule combo cap retained; active timer capped at60minutes and explained in UI.
- [x] Countdown HUD for15 timed effects; larger layered sender/effect/gift-count announcement.
- [x] V3 packets carry safe sender, gift and count, with duration beyond120seconds.
- [x] Legacy receivers explicitly reject timed stacking with update instructions.
- [x] Mod session connects from setup hub, before difficulty selection; paused signal shown separately.
- [x] Companion tick100ms; applied log includes queue-to-ACK latency. Actual LIVE latency not measured yet.
- [x] 43 automated checks; isolated candidate launcher smoke PASS.
- [x] Normal and QA scripts compiled; existing converted sound bank hash matches published bank despite converter warnings.
- [ ] Install and run native exact-duration/countdown/visual audit: current match restart approval pending.
- [ ] Real in-game LIVE trigger latency check after both receiver and companion update.
- [ ] Versioned public release / Workshop update after native audit. Nothing new published yet.


## Final local verification — 24 October 2026
- [x] User approved match restart; real gift actions paused for isolated QA.
- [x] 43 companion checks and18 in-game checks passed, zero native failures.
- [x] Timer bars shrink, refill on an extension, and stack separately on the right.
- [x] Timed gifts add exactly to remaining time; duplicate/final streak frames do not double count.
- [x] Refined medium-size announcement uses viewer/effect/gift lines, without the oversized timer.
- [x] Real bridge simulated burst ACKs421/595/766ms; no TikTok gift purchase or send.
- [x] Normal release receiver restored and isolated QA injection removed.
- [x] Normal map connects before difficulty selection (waiting state, V3, fresh heartbeat).
- [x] Five saved mappings and LIVE connection restored; no queued QA replay.
- [x] Local Windows0.3.1-beta.1 archive saved with fresh manifests.
- [ ] Publish this new version to GitHub/Workshop. Public release remains0.3.0-beta.1.
Evidence: work/timer-native-verified.log, work/native-timer-delivery-result.json,
outputs/releases/TIMER-UPDATE-REPORT.json, outputs/egg-live/stacked-timer-bars.png.
