# Read activity and attention

Use the native tab dot to find running work, unseen results and blocking input in OMP/Pi tabs and split panes.

## Sub-features

- Blue during actual OMP and Pi provider work.
- Green after completion while away; red after failure while away.
- Viewing the affected pane clears completion/failure attention and restores its original tab color.
- Yellow during an actual blocking confirmation, including when focused and after leaving/returning.
- Mixed panes acknowledge separately: viewing OMP leaves an unseen Pi completion green until Pi is viewed.
- Mixed priority: green unseen completion beats blue work; yellow waiting beats blue work; red unseen failure beats yellow; viewing failure reveals the remaining yellow wait.

## How to get to it (user POV)

Choose **New OMP Tab** or **New Pi Tab** from **Agents** in the palette. Submit a request, switch to another tab, and inspect the dot. Return to the individual Agent Block to acknowledge a result. For split panes, select each pane separately. A blocking agent confirmation remains yellow until answered or dismissed.

## Driving it with verify-native

```sh
node scripts/verify-native.mjs --out /tmp/tern-status-proof-$(date +%s)
```

For both real hosts, the runner submits `VERIFY_SUCCESS` via `tern send <owned-pane> text VERIFY_SUCCESS`, then `tern send <owned-pane> keys enter`, with the isolated `TERN_CONFIG_DIR` and `TERN_DAEMON_SOCKET` environment, and focuses the owned initial pane. The deterministic external provider delays its reply so the observer can capture blue during `working`, then green with `idle` and unseen `alert`. It repeats with `VERIFY_FAILURE` for red, viewing each result to verify acknowledgment.

`/verify-confirm` uses the real host extension command UI and `ctx.ui.confirm`. The observer must see `waiting_input` plus yellow while the target is focused. Switching away/back must retain yellow. Escape dismisses the real dialog and native state must return to idle. Tern can create another attention flag even while the pane is focused. Switch away and return to acknowledge it, then require the original color. Provider receipts must contain confirmation open/closed events.

Finally the helper moves the existing Pi Agent Block beside OMP through the native layout API, submits to both, switches away and waits for both alerts. Focusing one must leave the other alert and green dot. Sending another request from the focused OMP pane must keep green for Pi's unread result while OMP works. After OMP finishes, switch away and return to OMP to acknowledge any new completion attention, then view Pi and require the original color. Inspect intermediate snapshots/screenshots in each case as well as final snapshots.

The `mixed-pane-priority` case leaves Pi in a real confirmation while OMP runs a failing request. Yellow must outrank OMP's blue work, then red must outrank Pi's yellow when failure completes away. Viewing OMP must return the tab to yellow until Pi's confirmation is dismissed.

## Gotchas

Green is native pending attention, not a review or quality guarantee. The helper never sets progress, attention or completion flags. A screenshot alone cannot prove a transition. The offline model failure still runs through real agent stream/error processing. Real confirm support is mandatory for this verification; a host/API version without it must be reported as unsupported with failed/unverified status, never replaced with an internal state setter. Fresh-daemon coverage does not prove high-ID daily-daemon compatibility.

Observed OMP 18.11.0/Tern 0.8.3 limitation: the standalone extension command's real native confirmation can remain `idle` in the native agent report. The helper retains the visible dialog and snapshot as an unsupported assertion, dismisses it, and continues reachable cases while keeping an overall failure. Pi and mixed-state cases must still execute; do not infer they pass from the OMP screenshot.
