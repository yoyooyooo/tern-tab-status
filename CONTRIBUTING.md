# Contributing

## Setup and checks

Use Node.js 22 or later and npm:

```sh
npm ci --ignore-scripts
npm run check
```

`luau-web` is a pinned development dependency with no transitive production dependencies. It executes the Luau source without translating it to Lua or JavaScript. The plugin itself runs entirely inside Tern and needs no Node.js installation.

## Source layout

- `plugin.toml` declares the plugin ID, version, and window entry point.
- `status.luau` chooses a tab color from a group of pane states.
- `window.luau` polls direct `cx.agents:list()` metadata, preserves user colors, launches separate OMP/pi tabs, and schedules refreshes.
- `tests/behavior.luau` exercises color priorities and state transitions using a small Tern API fixture.
- `scripts/check.mjs` compiles the runtime files, executes the behavior suite, and checks the manifest and local documentation links.
- `scripts/verify-native.mjs` runs isolated native Tern acceptance with real OMP and pi processes and retains evidence.
- `.cursor/skills/verify-tern-tab-status/` maps launch, status/attention, and color-control features to their native verification paths.

Read status, tab, focus, and attention from Tern's direct agent metadata. Normalize `tern.json.null` before testing optional fields. Only shell-hosted OMP identification needs a bounded `omp.session` descriptor fallback. The plugin must not acknowledge native alerts, read conversation text, or install agent hooks. Completion results affect red or green only while native attention remains. Viewing a pane clears its completion/failure indication according to Tern; it does not dismiss a reported `waiting_input` state. Keep the plugin ID stable: it owns the saved color records. Preserve user colors when pausing, becoming idle, or ignoring unsupported panes. Launch commands must restore both `agent_command` and `agent_placement` even if block creation fails; never submit a placeholder prompt through `cx.agents:start` to create an empty conversation.

## Live acceptance in Tern

The automated suite uses a fixture and cannot prove host compatibility. Use the [verification skill](./.cursor/skills/verify-tern-tab-status/SKILL.md) and [feature map](./.cursor/skills/verify-tern-tab-status/features/README.md) for repeatable native acceptance:

```sh
node scripts/verify-native.mjs --doctor
node scripts/verify-native.mjs --case launch
node scripts/verify-native.mjs
```

The doctor checks executable prerequisites without starting Tern. `--case launch` drives both actual palette commands. The default full run also exercises status, attention, splits, and color controls. Use `--out <new-directory>` to retain evidence at a chosen path; otherwise the runner prints a unique temporary directory. `TERN_BIN`, `TERN_VERIFY_OMP_BIN`, and `TERN_VERIFY_PI_BIN` select the real host executables. The runner copies and installs the distributable runtime into an isolated configuration, starts an owned daemon and window, and uses an offline model provider in real agent processes. Inspect `summary.json`, native snapshots, screenshots, runtime errors, and owned-process exit receipts together. Failed or unsupported cases exit nonzero and retain their evidence.

Before shipping a behavior change, include these acceptance observations:

1. Run `tern plugin link "$PWD"` from the repository root. Confirm `tern plugin list --json` reports this plugin as ready without problems.
2. Run **New OMP Tab** and **New Pi Tab** from the plugin commands. Confirm they directly open separate tabs in the focused directory, run the chosen program without an initial prompt, preserve existing panes, and restore both the default Agent command and placement. Exercise `split`, `replace_if_alone`, and `new_tab` preferences. No launch-failure toast should appear. In each supported agent, send a sufficiently long request, switch away, and observe blue. Finish with attention pending and observe green. Focus that pane and confirm the original color returns.
3. Exercise a reported input/approval wait and a failed run. Observe yellow only when native metadata reports `waiting_input`, and red while failure attention remains. Viewing must clear completion/failure attention without dismissing a reported input wait. OMP 18.11.0 standalone extension `ctx.ui.confirm` can show a real dialog while Tern reports `idle`; record that path as unsupported, not a passed yellow scenario.
4. Split a tab into OMP and pi panes. Acknowledge only one pane: the other's attention or running state must remain visible through the aggregated color.
5. Set an original tab color, run OMP, then change the color manually during activity. After the next refresh, pause and confirm the latest observed manual color is restored.
6. Reload while a status color is active. Confirm pausing still restores the original color. Resume afterward if that was the initial state.
7. Confirm a regular shell tab keeps its own color. Pause before uninstalling the test installation.

Use a separate Tern configuration and daemon socket when automating acceptance so the run does not change personal tabs or attention state. Report Tern version, OS, architecture, scenario, and observed result. Share neutral reproductions rather than conversation logs or plugin storage dumps.

Before starting an isolated native window, create `omp/state.json` under its temporary `TERN_CONFIG_DIR` with `{"managed":false,"checked":0,"no_build":false,"offered":true}`. This remembers **Not Now** and suppresses the first-run **Manage omp** dialog for that test configuration. Keep the daily configuration and its update preference intact; repeat this initialization for each new temporary config.

Tern 0.8.3 has an observed addressability gap for large native tab IDs in existing daemons. In one reproduction, native tab `281994667753473` appeared as SDK ID `519691042817`; `color_tab` accepted the SDK ID and full numeric/string IDs without changing the native color. Loss of ID bits is a suspected cause, not an established upstream diagnosis. `arrange` could change a color but could not safely restore it and could reorder tabs, so it is not a supported workaround. Do not guess bit masks, attach acceptance tooling to a daily daemon, or recommend restarting it as a fix. Fresh low-ID success does not prove daily-session coloring or Pause restoration. Local reproduction paths and current release boundaries are in the [readiness record](./docs/readiness.md#known-native-blockers).

## Changes and reports

Keep changes focused. For a user-visible fix, add a deterministic regression case for the failing transition and update `CHANGELOG.md`. Keep the English and Chinese READMEs equivalent whenever behavior, commands, compatibility, or limits change. Explain the problem, resulting behavior, checks run, and any unverified host behavior in a contribution.

Use [GitHub Issues](https://github.com/yoyooyooo/tern-tab-status/issues) for bugs and contribution discussions, and open pull requests against `main`. Use [SECURITY.md](./SECURITY.md) for private vulnerability reports.

## Versioning and distribution

The current source version is `0.2.0`. Keep `plugin.toml`, `package.json`, `package-lock.json`, and changelog versions consistent. During `0.x`, compatible fixes increment patch and behavior/compatibility changes increment minor. No compatibility aliases or generated runtime artifacts are required.

Distribution is the source directory consumed by `tern plugin link` or `tern plugin install`. Install the public repository with `tern plugin install https://github.com/yoyooyooo/tern-tab-status.git` or `tern plugin install github.com/yoyooyooo/tern-tab-status`; Git is required for URL installation. Keep `plugin.toml` and the runtime modules at the installation root. Copied installations update by repeating their original install command with `--force`; linked installations reload from the existing checkout. There is no npm publication, release automation, or registry channel. If release tags are introduced, use immutable `v<plugin-version>` tags; publish a new version to fix a released artifact. Do not reuse or move a published tag.

The [Check workflow](https://github.com/yoyooyooo/tern-tab-status/actions/workflows/ci.yml) runs `npm ci --ignore-scripts` and `npm run check` on pushes and pull requests. A maintainer must run live Tern acceptance separately; Linux CI does not establish macOS host compatibility.

Contributions are provided under the repository's [MIT license](./LICENSE).
