# Read activity and attention

Use the right-side CSS status dot to find running work, unseen results and blocking input in OMP/Pi tabs and split panes, with native manual color preserved beneath.

## Sub-features

- Blue during actual OMP and Pi provider work.
- No Pi blue while only its long-lived launch shell is busy and daemon agent progress is idle.
- Green after completion while away; red after failure while away.
- Viewing the affected pane suppresses its completion/failure dot and reveals its native manual color, without mutating native attention or `tab.color`.
- Completion or failure while focused is already viewed; leaving and reload must not resurrect its dot. The next unseen result must still show green/red.
- Yellow during an actual blocking confirmation, including when focused and after leaving/returning.
- Mixed panes acknowledge separately: viewing OMP leaves an unseen Pi completion green until Pi is viewed.
- Mixed priority: green unseen completion beats blue work; yellow waiting beats blue work; red unseen failure beats yellow; viewing failure reveals the remaining yellow wait.
- Both horizontal and vertical tabs retain side-by-side pane icons, right-side dots and unobstructed shortcuts. Working/waiting remain visible while focused; read markers suppress only done/bell/failed.

## How to get to it (user POV)

Choose **New OMP Tab** or **New Pi Tab** from **Agents** in the palette. Submit a request, switch to another tab, and inspect the dot. Return to the individual Agent Block to acknowledge a result. For split panes, select each pane separately. A blocking agent confirmation remains yellow until answered or dismissed.

## Driving it with verify-native

```sh
node scripts/verify-native.mjs --out /tmp/tern-status-proof-$(date +%s)
```

For both real hosts, the runner submits `VERIFY_SUCCESS` via `tern send <owned-pane> text VERIFY_SUCCESS`, then `tern send <owned-pane> keys enter`, with the isolated `TERN_CONFIG_DIR` and `TERN_DAEMON_SOCKET` environment, and focuses the owned initial pane. The deterministic external provider delays its reply so the observer can capture blue during `working`, then green with `idle` and unseen `alert`. It repeats with `VERIFY_FAILURE` for red, viewing each result to verify acknowledgment.

The existing daily Pi pane exposed a window/daemon mismatch: window working with daemon `working=false`, producing a false blue dot. Verify that pane before/after the daemon-progress gate, then retain real Pi work/completion/failure/wait coverage in isolation. A fresh-daemon `ctl running pi` experiment kept window agent state idle and did not reproduce this mismatch; it is not a maintained passing regression. The failed attempt and actual daily screenshot evidence are recorded in [current cutover evidence](../../../../docs/readiness.md#current-css-cutover-evidence).

The `omp-focused-completion` and `pi-focused-completion` cases run both `VERIFY_SUCCESS` and `VERIFY_FAILURE` while the pane stays focused. Require blue during work and original color at completion; then leave and reload, requiring that original color to remain. Submit a subsequent request and leave before it completes; green must appear again, then restore on viewing.

`/verify-confirm` uses the real extension UI and `ctx.ui.confirm`. Its text says automatic acceptance/no user action. Observe native `waiting_input` and screenshot yellow while focused within five seconds; switching away/back retains yellow. An unsupported path remains a failed required assertion. The runner sends Escape to dismiss the dialog and requires idle/manual color while focused, with confirmation open/closed provider receipts.

Finally the helper moves the existing Pi Agent Block beside OMP through the native layout API, submits to both, switches away and waits for both alerts. Focusing one must leave the other alert and green dot. Sending another request from the focused OMP pane must keep green for Pi's unread result while OMP works and finishes. View Pi and require the original color. Inspect intermediate snapshots/screenshots in each case as well as final snapshots.

The `mixed-pane-priority` case leaves Pi in a real confirmation while OMP runs a failing request. Yellow must outrank blue, then red outranks yellow after unseen failure. Viewing OMP reveals the remaining yellow until Pi's confirmation is dismissed. Repeat priority in horizontal tabs and inspect both orientations. Assert screenshot-pixel `statusColor`, independently retaining real native manual `tab.color` in snapshots.

## Gotchas

Green is unseen native done/bell, not a review or quality guarantee. The helper never sets progress, attention or completion flags. Pixel status and native manual colors are distinct assertions. A screenshot alone cannot prove a transition. The offline model failure runs through real agent stream/error processing. Unsupported native confirm must remain failed/unverified, never replaced with an internal state setter. Current exact-pane CSS uses full native IDs rather than SDK color addressing. A separate controlled window on the existing daemon passes 12 selected OMP/pi high-ID lifecycle observations; it supplements fresh-daemon acceptance without proving all daily paths or legacy recovery.

Observed OMP 18.11.0–18.11.1/Tern 0.8.3–0.8.4 limitation: standalone real confirmation can remain native `idle`. Retain dialog/snapshot evidence, close it automatically and continue reachable Pi/mixed cases while keeping overall failure. Earlier tab-color runs are historical; the final copied-source CSS run and production daily lookup/display evidence are in [current cutover evidence](../../../../docs/readiness.md#current-css-cutover-evidence). Timer-budget and legacy restoration limits remain; do not describe every daily status path as blocked.
