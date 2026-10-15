---
name: verify-tern-tab-status
description: Drive Tern Tab Status through the real macOS Tern native window, command palette, OMP and Pi Agent Blocks; use for launch commands, status dots, attention, split panes, pause and color restoration verification.
---

# Verify Tern Tab Status

Read [features/README.md](features/README.md) first. The primary surface is Tern's native desktop window and its command palette. This plugin has no web UI. Node.js 22+, macOS, Tern 0.8.3 with plugin/control CLI, `omp` and `pi` on PATH are prerequisites. The known host baseline is OMP 18.11.0 and Pi 1.1.0. Other versions must be recorded rather than assumed compatible.

## Launch

From the repository root, check prerequisites and run the copied installation:

```sh
node scripts/verify-native.mjs --doctor
node scripts/verify-native.mjs --out /tmp/tern-status-proof-$(date +%s)
```

`TERN_BIN` overrides `/Applications/Tern.app/Contents/MacOS/tern`. `TERN_VERIFY_OMP_BIN` and `TERN_VERIFY_PI_BIN` override host executable lookup. They must name the real host executables. No global dependencies or model credentials are needed. A caller may omit `--out`; the runner prints its unique retained evidence directory.

The runner copies `plugin.toml`, `window.luau`, `status.luau` and `LICENSE` into `source-install`, then uses `tern plugin install` to copy that runtime into the isolated Tern configuration. It starts and owns a daemon and native window. Readiness requires the owned daemon socket, control socket, `ctl ready`, and an observer snapshot containing tabs. Launch is successful only after actual OMP/Pi extension initialization and idle Agent Blocks appear.

The entire run, including teardown, is one bounded command. It reports `Native verification passed` only when all selected assertions and cleanup succeed. Failure exits nonzero and retains artifacts. For an independent short skill evaluation, execute the mapped launch feature only:

```sh
node scripts/verify-native.mjs --case launch --out /tmp/tern-status-launch-$(date +%s)
```

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

The `ctl palette` query uses a JSON string including its quotes; native `tern send` takes plain text and routes through the isolated daemon environment. The helper obtains pane IDs from complete `cx.agents:list()` snapshots rather than guessing or truncating IDs. Its test-only observer reads `agents:list`, `session:tabs`, `session:panes`, focus and settings. It only uses native layout actions to focus, regroup or manually recolor owned panes; it never sets agent states or attention.

A host-only test plugin intercepts the plain production `omp`/`pi` launch in the private daemon and appends isolated startup flags and an offline provider extension. Only the external model boundary is deterministic. Real agent initialization, requests, stream processing, terminal/native UI, OSC/TSP lifecycle, completion/error and `ctx.ui.confirm` run in the real host. `/verify-confirm` opens a real blocking UI dialog; Escape dismisses it. Mock lifecycle events or source-text checks are not acceptable replacements.

## Evidence

Each case records its action, before/after native snapshots, intermediate transition snapshots, result and actual native screenshot path. `summary.json` also records installed source path, runtime SHA-256 hashes and manifest, plugin-list output, exact versions, provider request/response timestamps, process ownership and exit proof. Additional files include `installation.json`, `provider.jsonl`, `palette.jsonl`, native daemon/window stdout/stderr, Tern runtime logs and `runtime-hook-errors.json`.

Each snapshot request writes a unique nonce that the observer echoes into its snapshot. The runner requires an exact match, so a disabled or timed-out hook cannot silently reuse old state, including after reload. Observer revisions remain diagnostic evidence. The observer avoids action inventory work in its polling hook; palette receipts are captured separately.

Inspect the screenshots alongside state records. Require blue during observed real work; green for unseen completion; red for unseen failure; yellow during actual confirmation even while focused; clearing green/red when that pane is viewed; and original color restoration. Split-pane proof requires separate per-pane alert observations. A final screenshot by itself cannot prove these transitions. A nonempty runtime hook error scan fails the run. An unsupported capability must be explicitly recorded and reported as unverified, never counted as a pass.

Native completion can create new attention even while its pane is focused. After dismissing a dialog, require a fresh provider closure receipt and an idle state that has left yellow; then leave and reenter the pane to acknowledge any newly arrived result before requiring original color restoration. Split-pane cases separately reenter OMP and Pi so one pane's completion cannot hide the other's unread result.

Observed with OMP 18.11.0 and Tern 0.8.3: `/verify-confirm` opens the actual native Yes/No dialog, but the complete native agent snapshot remains `idle` rather than `waiting_input`. The runner records that unsupported report path with its screenshot/state, dismisses the dialog, and continues the remaining cases. Required unsupported assertions keep the overall result failed/nonzero; they are never counted as passes. See `summary.unsupported` and the failed case details.

This runner tests a fresh daemon. Daily daemons with large native IDs have a known SDK addressability constraint in Tern 0.8.3; fresh low-ID success does not establish daily-daemon compatibility. Do not normalize large IDs by guessing bit masks.

## Cleanup

The runner tears down in `finally`, including failures and interrupt signals: native window first, then daemon, using owned process groups with bounded SIGTERM/SIGKILL escalation. Agent PIDs come from the isolated provider's process receipts; their exit is recorded too. Never kill by executable/process name. Evidence, copied installation, configurations and screenshots survive cleanup at `<out>`.

Before claiming completion, inspect every `processes[].exitProof.observed` and every `agentProcesses[].exited` in `summary.json`, confirm screenshot files still exist, and include the retained evidence path. Do not remove failed output. If the parent agent is responsible for execution, hand over the exact command and mark execution pending; do not claim the skill is proven until that real run and the independent mapped-feature drive finish.

## Helpers

- `node scripts/verify-native.mjs --doctor`: prerequisite diagnosis, no native window.
- `node scripts/verify-native.mjs --case launch --out <new-directory>`: both palette launch commands, cwd, selection, no prompt and settings restoration.
- `node scripts/verify-native.mjs --out <new-directory>`: launch plus both hosts' state transitions, split-pane attention and manual/pause/resume/reload preservation.
- `scripts/fixtures/observer.luau`, `host.luau`, and `offline-provider.mjs`: copied into the private evidence directory by the runner; never install these in a daily configuration.

Use `/maintain-verification-skill` when updating the feature map or changing these user paths.
