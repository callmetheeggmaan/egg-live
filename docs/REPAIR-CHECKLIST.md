# Repair checklist — 25 October 2026

- [x] Restore custom HUD. Removing 45 idle timer elements restored map prompts and counter; timer elements now allocate only for active effects, up to five rows plus overflow count.
- [x] Restore larger centre gift announcement, retaining username, gift, effect and right-side animated timers. Verified visually in BO3.
- [x] Verify Rose shooting restriction and presentation; Heart Me now requests and delivers five actual nearby zombies.
- [x] Run 45 companion regression checks (all passed), plus broad native action-family checks (104 passed). Two initial native failures resolved by targeted retests with zero failures.
- [x] Test +1, +10 and +50 native nearby spawn requests: exact counts and same-floor placement verified. First delivery observed at 150 ms locally; capacity/clear-space limits still apply.
- [x] Door collision repaired and rebuilt: all 10 lanes physically block walking/jumping before purchase; all 10 lanes allow safe purchased passage both directions. Forced locked-room breach returns safely. 66 native checks passed, zero failures; normal engine damage verified enabled.
- [x] Restore real death screen. R instant restart and F three-second restart both returned to fresh setup with closed doors and reset loadout.
- [x] Remove all diagnostic fixture code from normal receiver, match all eight compiled runtime files to the normal build, and verify clean launch with visible HUD.
- [x] Preserve six gift mappings, keep test buttons removed and save automatic readiness. BO3 connected at setup hub.

Limits: this repair was tested locally with TikTok disconnected. A post-repair real LIVE gift test remains. Seven input/visual effects received smoke checks in the broad run; no claim of exhaustive testing of every effect on every stock/custom map. Native actor limits and dog-round restrictions remain. Further active timers beyond five retain their effects and show an overflow count.

Current fixes are installed locally. GitHub/Workshop public releases were not updated this repair turn.
Evidence: HUD-REPAIR-REPORT.json; repaired-centre-gift.png; repaired-death-screen.png; repaired-restart-countdown.png; repaired-normal-hud.png.


Door evidence: [native audit](../../work/closed-door-native.log). Closed-door clip-only movers replaced with solid caulk movers; client door hiding removed. No diagnostic fixture remains in the installed receiver.
