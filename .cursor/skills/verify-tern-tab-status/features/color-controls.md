# Preserve manual colors and pause synchronization

Keep chosen native tab colors while CSS status temporarily overlays agent work, and suspend/resume styling from the palette.

## Sub-features

- A native purple tab shows blue status pixels during real work while `tab.color` stays purple.
- Pause hides status styling and reveals purple; Resume overlays the current status again.
- A manual orange choice during work remains the real native color and is revealed when status clears.
- Reload preserves native manual colors, persisted read/pause state and current status styling.
- Old original/applied records restore only while current equals applied, clear only after observed success, preserve newer manual colors and remain available for retry after ignored restoration.

## How to get to it (user POV)

Choose a native tab color, then start work in its OMP/Pi Agent Block. Search **Tern Tab Status: Pause and Restore Tab Colors** or **Tern Tab Status: Resume** in the palette. For copied-install updates use `tern plugin reload` after applying changes. Pause before removal to hide status styling and retry old color recovery.

## Driving it with verify-native

```sh
node scripts/verify-native.mjs --out /tmp/tern-colors-proof-$(date +%s)
```

The `manual-pause-resume-reload` case selects native purple on the owned OMP tab, submits `VERIFY_LONG` and switches away. It requires screenshot `statusColor=blue` while native `tab.color=purple`, then invokes Pause through the palette and requires visible purple with native purple unchanged. Resume returns blue pixels. Selecting orange during that work changes only the real manual color; blue status must still be visible above it. The work fixture runs 45 seconds for the sequence, with a 60-second completion allowance.

Reload the isolated copied installation, require blue while real work continues and native orange remains, then observe green completion and focus that pane to reveal orange. Inspect intermediate snapshots/screenshots, pixel status and native colors separately, plus clean hook scan and owned-process exit receipts. Include horizontal/vertical priority with a manual color underneath: native deck animation/stacking contexts must not let manual color cover status.

## Gotchas

Pause is shared through plugin KV; the isolated configuration keeps daily state separate. Manual color is independent of status even when both use the same color. The delayed provider is an external fixture; settings, layout, reload and lifecycle use native APIs. Do not edit KV to manufacture manual preservation. Exercise legacy records separately through a controlled fixture, retaining unresolved records after ignored color calls. Large IDs are a known SDK boundary, not proof that every recovery fails; selected daily old-record clears have succeeded. See [current evidence](../../../../docs/readiness.md#current-css-cutover-evidence).
