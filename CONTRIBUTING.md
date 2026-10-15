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
- `window.luau` reads native state, preserves user colors in plugin storage, and schedules refreshes.
- `tests/behavior.luau` exercises color priorities and state transitions using a small Tern API fixture.
- `scripts/check.mjs` compiles the runtime files, executes the behavior suite, and checks the manifest and local documentation links.

Read status through Tern's agent and pane APIs. The plugin must not acknowledge native alerts, read conversation text, or install an OMP hook. Keep the plugin ID stable: it owns the saved color records. Preserve user colors when pausing, becoming idle, or ignoring non-OMP panes.

## Live acceptance in Tern

The automated suite uses a fixture and cannot prove host compatibility. Before shipping a behavior change:

1. Run `tern plugin link "$PWD"` from the repository root. Confirm `tern plugin list --json` reports this plugin as ready without problems.
2. Run a sufficiently long OMP request, switch away, and observe blue. Finish with attention pending and observe green. Focus that pane and confirm the original color returns.
3. Exercise an input/approval wait and a failed run. Observe yellow while waiting and red while failure attention remains. Viewing must clear completion/failure attention without dismissing an input wait.
4. Split a tab into two OMP panes. Acknowledge only one pane: the other's attention or running state must remain visible through the aggregated color.
5. Set an original tab color, run OMP, then change the color manually during activity. After the next refresh, pause and confirm the latest observed manual color is restored.
6. Reload while a status color is active. Confirm pausing still restores the original color. Resume afterward if that was the initial state.
7. Confirm a regular shell tab keeps its own color. Pause before uninstalling the test installation.

Use a separate Tern configuration and daemon socket when automating acceptance so the run does not change personal tabs or attention state. Report Tern version, OS, architecture, scenario, and observed result. Share neutral reproductions rather than conversation logs or plugin storage dumps.

## Changes and reports

Keep changes focused. For a user-visible fix, add a deterministic regression case for the failing transition and update `CHANGELOG.md`. Keep the English and Chinese READMEs equivalent whenever behavior, commands, compatibility, or limits change. Explain the problem, resulting behavior, checks run, and any unverified host behavior in a contribution.

Use [GitHub Issues](https://github.com/yoyooyooo/tern-tab-status/issues) for bugs and contribution discussions, and open pull requests against `main`. Use [SECURITY.md](./SECURITY.md) for private vulnerability reports.

## Versioning and distribution

The current source version is `0.1.0`. Keep `plugin.toml`, `package.json`, `package-lock.json`, and changelog versions consistent. During `0.x`, compatible fixes increment patch and behavior/compatibility changes increment minor. No compatibility aliases or generated runtime artifacts are required.

Distribution is the source directory consumed by `tern plugin link` or `tern plugin install`. Install the public repository with `tern plugin install https://github.com/yoyooyooo/tern-tab-status.git` or `tern plugin install github.com/yoyooyooo/tern-tab-status`; Git is required for URL installation. Keep `plugin.toml` and the runtime modules at the installation root. Copied installations update by repeating their original install command with `--force`; linked installations reload from the existing checkout. There is no npm publication, release automation, or registry channel. If release tags are introduced, use immutable `v<plugin-version>` tags; publish a new version to fix a released artifact. Do not reuse or move a published tag.

The [Check workflow](https://github.com/yoyooyooo/tern-tab-status/actions/workflows/ci.yml) runs `npm ci --ignore-scripts` and `npm run check` on pushes and pull requests. A maintainer must run live Tern acceptance separately; Linux CI does not establish macOS host compatibility.

Contributions are provided under the repository's [MIT license](./LICENSE).
