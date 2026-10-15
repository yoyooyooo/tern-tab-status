# Preserve manual colors and pause synchronization

Keep chosen native tab colors while status colors temporarily show agent work, and suspend/resume the plugin from the palette.

## Sub-features

- A manual purple tab becomes blue while real work runs.
- Pause restores purple; Resume reapplies the current status.
- A manual orange change observed during work becomes the next restored color.
- Reloading a copied installation preserves the saved original/manual color and current status.

## How to get to it (user POV)

Choose a native tab color, then start work in its OMP/Pi Agent Block. Search **Tern Tab Status: Pause and Restore Tab Colors** or **Tern Tab Status: Resume** in the command palette. Developers updating the copied installation can run `tern plugin reload` after applying changes. Pause before uninstalling or disabling to restore temporary colors.

## Driving it with verify-native

```sh
node scripts/verify-native.mjs --out /tmp/tern-colors-proof-$(date +%s)
```

The `manual-pause-resume-reload` case uses the native layout color operation on the owned OMP tab to select purple, submits `VERIFY_LONG` to the real host, and switches away. It requires working/blue before invoking Pause through the actual palette. Purple must return. Resume must return to blue. A second native manual color selection changes the saved original to orange; blue must reappear during the same work.

The helper reloads plugins through the isolated Tern CLI, observes blue while the real delayed request continues, waits for green completion, and focuses that individual pane. Orange must be restored. Inspect the case's before/after states, paused/reloaded intermediate snapshots, native screenshot and logs. Require a clean runtime-hook scan and process exit receipts after cleanup.

## Gotchas

Pause is stored in plugin KV state and affects windows using that same configuration. The helper uses a unique configuration, so the daily instance remains separate. A manual color identical to the currently applied status cannot be distinguished; this case deliberately uses purple and orange. The delayed model response is an external boundary fixture; pause, settings, layout, reload and lifecycle all use real native APIs. Do not edit KV state to manufacture an expected result.
