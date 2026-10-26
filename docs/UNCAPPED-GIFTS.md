# Uncapped gift delivery — local update, 26 October 2026

Uncapped mode is now the default and is enabled in the installed owner profile.
Every distinct gift counts, regardless of legacy per-rule maxRepeat, cooldown or
once-per-combo values. Progressive streak frames add only the new count; final
frames do not replay the streak. Timed top-ups waiting in the queue combine by
sender, gift and action without losing seconds. Instant effects queue each gift.

Removed in uncapped mode: combo limits, instant-effect cooldown drops, queue-size
and queue-age drops, 60-minute effect duration ceiling, the 20-gift display clamp,
the 500-ticket near-zombie queue limit, and the ten-entry/60-second notice limits.
The native v4 protocol is required; older receivers retain queued work rather
than silently truncating durations. Explicit Pause, death/restart and uncertain
unacknowledged actions retain their existing cancellation behavior.

Native BO3 actor capacity still limits simultaneous zombies. Pending spawn
requests wait for room; the engine cannot spawn infinitely many active actors.
Action amounts still describe each gift's configured effect (+50 means +50 per
gift). Per-effect health, weapon capacities, score behavior and conflicting-effect
rules remain unchanged. Numeric values remain subject to JS/BO3 representation.

Verification: 57 automated tests pass. Native test through the actual HTTP test
endpoint, router, packet and v4 receiver confirmed 150 Roses at five seconds each
add exactly 750 seconds. Another 1,500-Rose test extended the active timer beyond
8,200 seconds; weapon jam actually emptied the magazine. Logs:
work/uncapped-native.log and work/uncapped-unit.log. Test gifts only, TikTok was
disconnected. Diagnostics removed from the final installed receiver. Original
gift rules retained. Included in the 0.3.3 beta release.
