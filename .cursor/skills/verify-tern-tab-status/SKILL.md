---
name: verify-tern-tab-status
description: Drive Tern Tab Status through the real macOS Tern native window, command palette, OMP and Pi Agent Blocks; use for launch commands, status dots, attention, split panes, pause and color restoration verification.
---

# Verify Tern Tab Status

Read [features/README.md](features/README.md) first. The primary surface is Tern's native desktop window and command palette; this plugin has no web UI. Node.js 22+, macOS, Tern with plugin/control CLI, and real `omp`/`pi` executables are prerequisites. Historical tab-color runs cover selected Tern 0.8.3–0.8.4, OMP 18.11.0–18.11.1 and Pi 1.1.0 scenarios. The latest copied-source host/window CSS run on Tern 0.9.2 (`23735aa`), OMP 18.11.3 and Pi 1.1.0 passes 14 of 15 cases, including opt-out sweep controls; unsupported OMP confirmation remains failed. These observations do not establish unconditional compatibility. Record exact versions and see [current evidence](../../../docs/readiness.md#current-css-cutover-evidence).

## Launch

From the repository root, check prerequisites and run the copied installation:

```sh
node scripts/verify-native.mjs --doctor
node scripts/verify-native.mjs --out /tmp/tern-status-proof-$(date +%s)
```

`TERN_BIN` overrides `/Applications/Tern.app/Contents/MacOS/tern`. `TERN_VERIFY_OMP_BIN` and `TERN_VERIFY_PI_BIN` override host executable lookup. They must name the real host executables. No global dependencies or model credentials are needed. A caller may omit `--out`; the runner prints its unique retained evidence directory.

The runner copies `plugin.toml`, `host.luau`, `window.luau` and `LICENSE` into `source-install`, then uses `tern plugin install` in the isolated configuration. `status.luau` is no longer runtime. It owns a daemon and native window; readiness requires owned sockets, `ctl ready` and fresh observer tabs. Launch succeeds only after real OMP/Pi extension initialization and idle Agent Blocks appear.

The entire run, including teardown, is one bounded command. It reports `Native verification passed` only when all selected assertions and cleanup succeed. Failure exits nonzero and retains artifacts. For an independent short skill evaluation, execute the mapped launch feature only:

```sh
node scripts/verify-native.mjs --case launch --out /tmp/tern-status-launch-$(date +%s)
```

For the appearance preference, run `node scripts/verify-native.mjs --case sweep --out <new-directory>`. It launches both real agents, submits delayed OMP work, then drives **Disable Sweep Effects** / **Enable Sweep Effects** through the actual palette in vertical and horizontal tabs. Native animation paths distinguish the title and icon sweep from the independent blue-dot pulse; screenshots and pixel status remain the visual evidence. Reload disabled in each orientation and enabled at the end; Pause restores native sweep without resetting the option, and Resume suppresses it again. Only the applicable sweep action appears. The full run includes this case as `sweep-effects`.

## Doctor

Run `node scripts/verify-native.mjs --doctor` whenever prerequisites look wrong. It reads the native executable/host versions, records resolved executable paths, and starts no daemon/window. The normal run additionally records an instance doctor snapshot containing the exact owned process IDs, daemon/control sockets, settings, panes, agents and tabs. Inspect `<out>/summary.json`: all paths must point inside that run except the declared real executable paths.

Do not attach to a daily daemon or reuse inherited `TERN_PANE`, window sockets, identity or routing environment. The helper clears inherited `TERN_*` fields before setting its private configuration/socket/log paths. An `omp/state.json` fixture remembers “Not Now” to avoid the managed-install prompt. Agent configurations and session directories are isolated; personal auth is never copied.

## Drive

Use the runner and the [feature map](features/README.md), which names the complete selected cases. Both modes invoke the actual palette path `Agents → New OMP Tab` and `Agents → New Pi Tab`. Stable production action IDs are `plugin.tern-tab-status.new_omp_tab` and `plugin.tern-tab-status.new_pi_tab`.

The native control protocol is:

```text
tern ctl --control <owned-control.sock> palette '"New Pi Tab"'
tern ctl --control <owned-control.sock> key enter
TERN_CONFIG_DIR=<out>/tern TERN_DAEMON_SOCKET=<out>/daemon.sock tern send <owned-pane-id> text VERIFY_SUCCESS
TERN_CONFIG_DIR=<out>/tern TERN_DAEMON_SOCKET=<out>/daemon.sock tern send <owned-pane-id> keys enter
tern ctl --control <owned-control.sock> shot <case-name>
```

The `ctl palette` query includes JSON string quotes; native `tern send` takes plain text and routes through the isolated daemon environment. The test-only observer may read `agents:list`, tabs, panes, focus and settings; it is distinct from production, which uses host full native pane strings, `session:pane(full-string)` identification and exact-pane CSS without agent-list polling. Preserve exact native IDs rather than guessing masks. Native layout actions focus, regroup or manually recolor owned panes; they never set agent state or attention.

Pi blue additionally requires asynchronous local CLI inspection of the exact daemon pane's `working` flag; window busy can retain a launch shell after the turn is idle. Keep the CLI routed to the isolated daemon/configuration. Native waiting and result states remain direct CSS. Daily false-blue before/after evidence is separate from fresh-daemon lifecycle coverage; `ctl running pi` on a fresh daemon did not reproduce the stale daily window record.

A host-only fixture intercepts plain production `omp`/`pi` launch in the private daemon and appends isolated startup flags and an offline provider extension. Only the external model boundary is deterministic. Real initialization, stream processing, terminal/native UI, OSC/TSP lifecycle, completion/error and `ctx.ui.confirm` run in the real host. Dialog text identifies automatic acceptance and says no user action is required. Observe native waiting for five seconds, record an unsupported required assertion as failed, then send Escape to close the dialog and retain closure receipts. Mock lifecycle events are not replacements.

## Evidence

Each case records actions, fresh snapshots, intermediate transitions, native screenshot paths, pixel-derived `tab.statusColor` and a snapshot-level `statusPixels` map using native layout coordinates. Read status from native PNG pixels, not `tab.color`; decode with Node's built-in zlib, without adding a dependency. Native `tab.color` independently verifies manual colors throughout work/pause/resume/reload. Vertical tabs are the default, with a separate horizontal priority case. `summary.json` also records installed source path, host/window SHA-256 hashes and manifest, plugin list, versions, provider timestamps, process ownership and exits. Additional files include installation/provider/palette receipts, native stdout/stderr, runtime logs and `runtime-hook-errors.json`.

Each snapshot request writes a unique nonce that the observer echoes into its snapshot. The runner requires an exact match, so a disabled or timed-out hook cannot silently reuse old state, including after reload. Observer revisions remain diagnostic evidence. The observer avoids action inventory work in its polling hook; palette receipts are captured separately.

Inspect screenshots alongside state and pixel records. Require blue during real work; green for unseen done/bell; red for unseen failure; yellow during native waiting even while focused; and viewing completion/failure revealing the manual color. `statusColor` is a visual observation and `tab.color` is the real native manual value; neither substitutes for the other. A final screenshot cannot prove transitions. Nonempty runtime hook errors fail the run. Unsupported required capabilities remain failed/nonzero.

Native completion can create attention while focused. Require immediate read suppression, persistence across leaving/reload, and green/red on a subsequent unseen result. Production read markers suppress only done/bell/failed, never working/waiting, and neither plugin nor observer clears native attention. Split cases must acknowledge each pane separately, retain side-by-side icons and verify red → yellow → green → blue priority in both tab orientations, with shortcuts unobstructed. After dialog dismissal require fresh closure receipts and idle/manual color while still focused.

Observed with OMP 18.11.0–18.11.1 on Tern 0.8.3–0.8.4, and OMP 18.11.3 on Tern 0.9.0–0.9.1: `/verify-confirm` opens the real Yes/No dialog but native agent metadata remains `idle` rather than `waiting_input`. Record the unsupported path with screenshot/state, dismiss automatically and continue reachable cases. Required unsupported assertions keep the overall result failed/nonzero. Pi confirmation reaches waiting/yellow, including while focused, in the latest copied-source CSS run. See `summary.unsupported`, failed case details and [current evidence](../../../docs/readiness.md#current-css-cutover-evidence).

The permanent runner owns a fresh daemon. Current production targets native `.tn-dk-c[data-pane][data-st]` with full pane strings, avoiding the SDK tab-color bridge for status display. Selected daily high-ID lookup/blue-dot display and a separate controlled window on the existing daemon supplement that evidence: 12 selected real OMP/pi lifecycle observations passed with native IDs above `2^44`, including work, unseen completion/failure, viewing, read persistence across reload and Pi waiting/dismissal. That controlled sample does not establish all daily paths, OMP confirmation or legacy recovery. The temporary high-ID driver encountered `ctl tab` timeouts; using `tern focus --window <owned-window> <full-native-pane-id>` completed the remaining observations. See [current cutover evidence](../../../docs/readiness.md#current-css-cutover-evidence).

The official [ID encoding](https://docs.stencil.so/tern/reference/api-window.md#pane-and-tab-ids), [number representation](https://docs.stencil.so/tern/concepts/runtime.md#numbers-and-ids) and [upstream collision report](https://github.com/stencil-hq/tern-sdk/issues/30) remain relevant to SDK color calls and legacy upgrade restoration. Restore an old original only while current color equals saved applied; clear the record only after successful native readback. A newer manual color must survive, and an ignored matching restoration must retain its record. High IDs do not imply every restoration fails. The rejected historical title-marker CSS only worked horizontally; current exact-pane CSS does not use titles or positions.

Tern's 50 ms wall-clock budget can disable plugin timers until reload, including after native waiting/descheduling; a ready listing does not prove maintenance continues. Daily instrumentation captured a stall in the now-removed production `agents:list()` path. Native `data-st` drives OMP and Pi waiting/result CSS without polling; Pi blue additionally requires asynchronous daemon observations. Lifecycle events synchronize recognition/styles directly rather than deferring through a timer; regression scenarios cover discovery/shared pause and window start without firing timers. Timer loss can still delay Pi observations and changes without a delivered lifecycle event, including cross-window pause in a quiet window. Do not claim timer immunity or treat finite samples as host repair. See [host evidence](../../../docs/readiness.md#known-native-blockers).

The isolated Tern 0.8.4 (`6b4535f`) protected-call experiment confirms `pcall`/`xpcall` cannot recover disabled timer hooks. That mechanism test does not reproduce the daily stall on 0.8.4 or approve all agent paths. Runtime CSS also depends on native markup and state vocabulary, so record exact host versions and orientation evidence.

## Cleanup

The runner tears down in `finally`, including failures and interrupt signals: native window first, then daemon, using owned process groups with bounded SIGTERM/SIGKILL escalation. Agent PIDs come from the isolated provider's process receipts; their exit is recorded too. Never kill by executable/process name. Evidence, copied installation, configurations and screenshots survive cleanup at `<out>`.

Before claiming completion, inspect every `processes[].exitProof.observed` and every `agentProcesses[].exited` in `summary.json`, confirm screenshot files still exist, and include the retained evidence path. Do not remove failed output. If the parent agent is responsible for execution, hand over the exact command and mark execution pending; do not claim the skill is proven until that real run and the independent mapped-feature drive finish.

## Helpers

- `node scripts/verify-native.mjs --doctor`: prerequisite diagnosis, no native window.
- `node scripts/verify-native.mjs --case launch --out <new-directory>`: both palette launch commands, cwd, selection, no prompt and settings restoration.
- `node scripts/verify-native.mjs --case sweep --out <new-directory>`: real palette sweep controls, both orientations, blue-dot preservation, persisted preference across reload and Pause/Resume.
- `node scripts/verify-native.mjs --out <new-directory>`: launch, real lifecycle, focused/read transitions, split/orientation priority, pixel status and native manual-color preservation across pause/resume/reload.
- `scripts/fixtures/observer.luau`, `host.luau`, and `offline-provider.mjs`: copied into the private evidence directory by the runner; never install these in a daily configuration.

Use `/maintain-verification-skill` when updating the feature map or changing these user paths.
