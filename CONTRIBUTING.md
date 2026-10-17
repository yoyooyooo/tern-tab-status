# Contributing

## Setup and checks

Use Node.js 22 or later and npm:

```sh
npm ci --ignore-scripts
npm run check
```

`luau-web` is a pinned development dependency with no transitive production dependencies. It executes the Luau source without translating it to Lua or JavaScript. The plugin itself runs entirely inside Tern and needs no Node.js installation.

## Source layout

- `plugin.toml` declares the plugin ID, version, and host/window entry points.
- `host.luau` publishes the native pane list as full decimal ID strings on shell lifecycle events and a 750 ms fallback poll, writing shared storage only when the list changes.
- `window.luau` identifies supported panes, emits exact-pane CSS, persists read markers, handles legacy color recovery, and launches separate OMP/pi tabs. The former `status.luau` color-selection module has been removed.
- `tests/behavior.luau` exercises the host/window contracts using a small Tern API fixture.
- `scripts/check.mjs` compiles the runtime files, executes the behavior suite, and checks the manifest and local documentation links.
- `scripts/verify-native.mjs` runs isolated native Tern acceptance with real OMP and pi processes and retains evidence.
- `.cursor/skills/verify-tern-tab-status/` maps launch, status/attention, and color-control features to their native verification paths.

Use `tern.pane.list()` in the host to preserve full native pane identity. Window `session:pane(full-string)` resolves pane metadata and the SDK event ID; retain the full string for CSS `data-pane` matching and the SDK ID for focus/completion read markers. Do not guess bit masks. Recognize direct `omp`/`pi` executable basenames; shell-hosted OMP identification uses a bounded `omp.session` surface query (one node, depth one, 128 characters). Normalize `tern.json.null` before testing optional fields. Production must not call `agents:list()`, acknowledge native alerts, read conversation text, or install agent hooks.

Native `.tn-dk-c[data-pane][data-st]` drives the status: `working` blue, `waiting` yellow, `done`/`bell` green and `failed` red. Pane icons remain side by side. The 7 px pseudo-element dots overlap at the tab's right edge with red/yellow/green/blue z-indices 4/3/2/1; native manual `.tn-tc` sits beneath at z-index 0. Set deck z-index 1 and disable pane-wrapper animation with z-index auto so split animation cannot create a stacking context below manual color. Both orientations expose the deck; horizontal `.fc` is hidden and right padding is 24 px to avoid shortcut overlap. Keep title text and native manual colors intact.

Pi blue requires an additional asynchronous `tern inspect --json` observation of the exact native pane's daemon `working` flag. Window `busy`/`data-st=working` can retain the Pi launch shell after the actual turn is idle. Keep one CLI query in flight per window, bound it to 1.5 seconds, and extract only IDs/boolean progress without persisting the raw pane/session/client response. Reuse lifecycle events and the 750 ms poll; a missing/failed observation must not assert Pi work. Native waiting and result states still use CSS directly. This path requires Tern's CLI on its PATH and depends on observation refresh; do not claim complete timer independence.

Persist each pane's viewed marker across leaving, Pause and reload. `agent_finished` replaces the marker according to focus; focus marks the viewed pane, and close removes its marker. Suppress only `done`, `bell` and `failed` for read results. Never suppress `working` or `waiting` on focus. A later result completed away can become unread again. Launch commands must restore both `agent_command` and `agent_placement` even if block creation fails; never submit a placeholder prompt to create an empty conversation.

Status styling must not write `tab.color`. Pause removes status CSS, exposing the native manual color; Resume reapplies current status. Window start and pane/tab/command/directory/title events synchronize identification and shared pause directly with their fresh context. Do not defer event work through a timer: Tern can disable timer hooks. The host publishes its roster on command/directory/title/exit events. Both halves also poll every 750 ms for changes without a corresponding event, including shared pause in a quiet window. Paused window refreshes skip pane identification and surface reads. Keep the plugin ID stable because it owns persisted pause/read state and upgrade records.

Legacy `tab:<session>:<id>` records are upgrade-only. Restore a saved original only if the observed native color still equals `applied`, then read back actual color before deleting the record. If it differs from `applied`, preserve that manual color and discard the obsolete record. `color_tab` has no success receipt and can silently fail for large IDs: retain a still-matching unresolved record for retry. Do not convert that failure into a success or resume writing status colors.

The former daily failure was captured at synchronous `cx.agents:list()`; that production call has been removed. Tern's 50 ms wall-clock timer mechanism remains: native waiting/descheduling can consume it, and a budget failure can disable timers until reload. OMP states and Pi waiting/result states follow native `data-st` directly; Pi blue also needs asynchronous daemon observations. Lifecycle events synchronize directly even without a timer callback; timer loss can still delay Pi observations and other changes for which no event is delivered. Neither protected calls nor a finite passing sample proves host-level repair. See the [captured evidence and current limits](./docs/readiness.md#known-native-blockers).

## Live acceptance in Tern

The automated suite uses a fixture and cannot prove host compatibility. Use the [verification skill](./.cursor/skills/verify-tern-tab-status/SKILL.md) and [feature map](./.cursor/skills/verify-tern-tab-status/features/README.md) for repeatable native acceptance:

```sh
node scripts/verify-native.mjs --doctor
node scripts/verify-native.mjs --case launch
node scripts/verify-native.mjs
```

The doctor checks executable prerequisites without starting Tern. `--case launch` drives both actual palette commands. The default full run also exercises status, attention, splits, orientations and color controls. Use `--out <new-directory>` to retain evidence at a chosen path; otherwise the runner prints a unique temporary directory. `TERN_BIN`, `TERN_VERIFY_OMP_BIN`, and `TERN_VERIFY_PI_BIN` select the real executables. The runner installs `plugin.toml`, `host.luau`, `window.luau` and `LICENSE` in an isolated configuration and uses an offline provider in real agent processes. Status assertions read screenshot pixels as `statusColor`; native `tab.color` independently verifies manual color preservation. PNG decoding uses Node's built-in zlib without another dependency. Inspect summary, snapshots, screenshots, runtime errors and owned-process exit receipts together. Failed or unsupported cases exit nonzero.

Before shipping a behavior change, include these acceptance observations:

1. Run `tern plugin link "$PWD"` from the repository root. Confirm `tern plugin list --json` reports this plugin as ready without problems.
2. Run **New OMP Tab** and **New Pi Tab** from the plugin commands. Confirm they directly open separate tabs in the focused directory, run the chosen program without an initial prompt, preserve existing panes, and restore both the default Agent command and placement. Exercise `split`, `replace_if_alone`, and `new_tab` preferences. No launch-failure toast should appear. In each supported agent, send a sufficiently long request, switch away, and observe blue. Finish with attention pending and observe green. Focus that pane and confirm the original color returns.
   For an existing Pi pane with window busy but daemon `working=false`, capture before/after metadata and pixels; it must have no blue after the gate. A fresh-daemon `ctl running pi` experiment did not reproduce the old window mismatch and is not a substitute for this evidence.
3. Finish successful and failed work while keeping its pane focused: reveal the native manual color immediately, keep it after leaving/reload, and show green/red for the next result completed away. Exercise a native input wait and failed run. Viewing clears completion/failure dots without dismissing waiting. Confirmation fixtures must say they are automatic acceptance checks requiring no user action; observe native waiting for five seconds, report unsupported paths as failed, and send Escape to close the dialog. OMP 18.11.0–18.11.1 standalone `ctx.ui.confirm` can remain `idle` and is unsupported.
4. Split a tab into OMP and pi panes. Acknowledge only one pane: the other's attention or running state must remain visible. Verify red over yellow, yellow over green/blue, and green over blue in horizontal and vertical tabs, with icons and shortcuts unobstructed.
5. Set a native purple tab color, run OMP, and confirm blue pixels while native `tab.color` remains purple. Pause reveals purple. Resume restores the status overlay; select orange during work and require native `tab.color` to remain orange throughout.
6. Reload while a status dot is active. Confirm it returns without changing manual orange, then view the result and reveal orange. Exercise upgrade records separately: matching old applied color restores only with observed success; a newer manual color is preserved; an ignored native restoration retains the old record.
7. Confirm a regular shell tab keeps its own color. Pause before uninstalling the test installation.

Use a separate Tern configuration and daemon socket when automating acceptance so the run does not change personal tabs or attention state. Report Tern version, OS, architecture, scenario, and observed result. Share neutral reproductions rather than conversation logs or plugin storage dumps.

Before starting an isolated native window, create `omp/state.json` under its temporary `TERN_CONFIG_DIR` with `{"managed":false,"checked":0,"no_build":false,"offered":true}`. This remembers **Not Now** and suppresses the first-run **Manage omp** dialog for that test configuration. Keep the daily configuration and its update preference intact; repeat this initialization for each new temporary config.

The official [ID encoding](https://docs.stencil.so/tern/reference/api-window.md#pane-and-tab-ids), [number representation](https://docs.stencil.so/tern/concepts/runtime.md#numbers-and-ids) and [upstream collision report](https://github.com/stencil-hq/tern-sdk/issues/30) remain relevant to the low-44-bit SDK color bridge and legacy restoration. Current status display bypasses that bridge using full native pane strings and existing `data-pane` markup. The earlier title-marker CSS experiment failed in the vertical sidebar; it is distinct from the current exact-pane CSS. Production daily reload evidence establishes precise large-ID lookup and blue-dot display, not the entire high-ID lifecycle. Never attach the acceptance runner to a daily daemon, replay full layouts, or recommend restarting a daemon as a fix. Local evidence and version boundaries are in the [readiness record](./docs/readiness.md#current-css-cutover-evidence).

## Changes and reports

Keep changes focused. For a user-visible fix, add a deterministic regression case for the failing transition and update `CHANGELOG.md`. Keep the English and Chinese READMEs equivalent whenever behavior, commands, compatibility, or limits change. Explain the problem, resulting behavior, checks run, and any unverified host behavior in a contribution.

Use [GitHub Issues](https://github.com/yoyooyooo/tern-tab-status/issues) for bugs and contribution discussions, and open pull requests against `main`. Use [SECURITY.md](./SECURITY.md) for private vulnerability reports.

## Versioning and distribution

The current source version is `0.2.0`. Keep `plugin.toml`, `package.json`, `package-lock.json`, and changelog versions consistent. During `0.x`, compatible fixes increment patch and behavior/compatibility changes increment minor. No compatibility aliases or generated runtime artifacts are required.

Distribution is the source directory consumed by `tern plugin link` or `tern plugin install`. Install the public repository with `tern plugin install https://github.com/yoyooyooo/tern-tab-status.git` or `tern plugin install github.com/yoyooyooo/tern-tab-status`; Git is required for URL installation. Keep `plugin.toml`, `host.luau`, `window.luau` and `LICENSE` at the installation root; `status.luau` is no longer runtime. Copied installations update by repeating their original install command with `--force`; linked installations reload from the existing checkout. There is no npm publication, release automation or registry channel. If release tags are introduced, use immutable `v<plugin-version>` tags; publish a new version to fix a released artifact. Do not reuse or move a published tag.

The [Check workflow](https://github.com/yoyooyooo/tern-tab-status/actions/workflows/ci.yml) runs `npm ci --ignore-scripts` and `npm run check` on pushes and pull requests. A maintainer must run live Tern acceptance separately; Linux CI does not establish macOS host compatibility.

Contributions are provided under the repository's [MIT license](./LICENSE).
