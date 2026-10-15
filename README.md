<h1 align="center">Tern Tab Status</h1>

> See which OMP sessions are working, waiting, or need your attention in Tern's tab bar.

<p align="center">
  <a href="./README.md">English</a> · <a href="./README.zh-CN.md">简体中文</a>
</p>
<p align="center">
  <a href="#install">Install</a> · <a href="#try-it">Try it</a> ·
  <a href="#read-the-colors">Colors</a> · <a href="#limitations">Limitations</a>
</p>

<p align="center">
  <img src="./docs/images/tab-status-sidebar.png" width="360" alt="Tern's vertical sidebar with blue, green, yellow, and red status dots, plus an idle tab without a dot.">
  <br>
  <sub>Session status demo in Tern 0.8.3.</sub>
</p>

When several OMP sessions run in different tabs or split panes, switching between them interrupts the work you are following. Tern Tab Status combines each tab's OMP state into its native color dot. Tab titles stay yours, and OMP needs no hooks or extensions.

Verified with **Tern 0.8.3 on macOS arm64**. Currently supports OMP only; other host versions and platforms are unverified.

## Read the colors

| Dot | Meaning |
| --- | --- |
| Blue | An OMP pane is working |
| Green | Native attention remains, usually after completion |
| Yellow | An OMP pane is waiting for input or confirmation |
| Red | Native attention remains after a failure, error, or nonzero exit |
| Original color | No OMP activity or attention; no dot if the tab had no color |

A tab combines all its OMP panes, in this priority order: **red → yellow → green → blue → original color**. A green dot means attention is pending, not that the task passed review.

## Install

You need Tern with its plugin CLI and an OMP session recognized by Tern. Git must be available for URL installation. The plugin has no runtime dependencies or build step. Node.js is only needed for development checks. If `tern` is not on your macOS PATH, use `/Applications/Tern.app/Contents/MacOS/tern` in its place.

### From GitHub

Tern can clone and install this plugin directly from GitHub:

```sh
tern plugin install https://github.com/yoyooyooo/tern-tab-status.git
tern plugin list --json
```

Confirm `tern-tab-status` is `ready` with no problem for this plugin. URL installation copies the plugin into Tern's plugin directory; you do not need to maintain a checkout. The equivalent GitHub shorthand is `tern plugin install github.com/yoyooyooo/tern-tab-status`.

<details>
<summary>Install from local source</summary>

From an extracted or cloned copy of this repository:

```sh
tern plugin link "$PWD"
tern plugin list --json
```

Run these commands at the repository root. The plugin list should contain `tern-tab-status` with `status: "ready"` and no problem for this plugin. A link loads files from this checkout; keep the directory in place.

For a copied installation that does not depend on the checkout location:

```sh
tern plugin install "$PWD"
```

For plugins in a repository subdirectory, Tern also accepts `github.com/OWNER/REPO/PATH`.

</details>

## Try it

1. Start an OMP request in a tab with no pending attention, then switch to another tab. The first tab shows blue while it works.
2. Let the request finish. If Tern marks the pane as needing attention, the tab shows green.
3. Return to that pane, or use Tern's **Needs attention** view. Once its attention clears, the idle tab returns to its original color.

With split panes, focusing one pane does not acknowledge the others. Input waits remain yellow until the agent leaves `waiting_input`.

## Controls

The command palette includes:

- **Tern Tab Status: Pause and Restore Tab Colors**: restore saved tab colors and suspend status colors.
- **Tern Tab Status: Resume**: enable status colors again.

Synchronization runs every 750 ms while a window is open. Focus, title, pane, tab, command, and completion events request an earlier refresh. Only color changes are written. A manual tab color observed during activity becomes the next color to restore.

### Update or uninstall

For a linked installation, update the source and run `tern plugin reload`. For a copied installation, repeat the original `tern plugin install` command with `--force`. A GitHub installation updates with `tern plugin install https://github.com/yoyooyooo/tern-tab-status.git --force`; a local copy updates with `tern plugin install "$PWD" --force` from the updated source directory. Updates are manual. `--force` replaces copied installations only; to replace a linked installation with a copy, pause, unlink, then install.

Before disabling, unlinking, or removing the plugin, run **Pause and Restore Tab Colors** so temporary status colors are restored. Then use the command for your installation:

```sh
tern plugin unlink tern-tab-status
# For a copied installation instead:
tern plugin remove tern-tab-status
```

Pause is persisted. Run **Resume** after reinstalling if status colors remain paused. Saved colors, enabled state, and completion results live in Tern's `plugin-data/tern-tab-status/kv.json` under its configuration directory. Unlinking does not erase that state.

## Limitations

- One dot shows only the highest-priority state. Use **Needs attention** and individual panes for details.
- Read/unread behavior follows Tern's pane attention flag. The plugin does not maintain a message unread count or acknowledge attention itself.
- Green covers native attention generally; it is not a separate record of successful completion. A completion already acknowledged by Tern may never show green.
- Only OMP entries from Tern's agent list are considered, recognized by an `omp.session` surface or an `omp` executable name. pi and other agents are not supported yet. Sessions Tern does not recognize as agents cannot be tracked.
- Very brief states can pass between refreshes. A manual color identical to the current status color cannot be distinguished from that status color.
- Pausing affects all windows through shared plugin storage; other windows restore their colors on their next refresh. No window means no window-plugin synchronization.

## Privacy

The plugin reads Tern's agent state, pane metadata, a bounded surface descriptor, and tab colors. It writes tab colors and its own local key/value state. It makes no network requests, spawns no processes, installs no OMP extension, and does not store conversation text. See [SECURITY.md](./SECURITY.md) for reporting and trust boundaries.

## Development

Node.js 22 or later and npm are required for checks:

```sh
npm ci --ignore-scripts
npm run check
```

This compiles and executes the actual Luau modules using a pinned development-only Luau runtime, checks behavior across status transitions and color restoration, and validates local documentation links and the plugin manifest. It does not replace a live Tern smoke run.

See [CONTRIBUTING.md](./CONTRIBUTING.md) for architecture and manual acceptance steps, [CHANGELOG.md](./CHANGELOG.md) for changes, and [the readiness record](./docs/readiness.md) for verification scope. The npm manifest is private development tooling; installation uses Tern, not npm.

Report bugs and discuss contributions in [GitHub Issues](https://github.com/yoyooyooo/tern-tab-status/issues). Report vulnerabilities privately through [GitHub Security Advisories](https://github.com/yoyooyooo/tern-tab-status/security/advisories/new).

## License

[MIT](./LICENSE). This is an independent plugin, not an official Tern or OMP project.
