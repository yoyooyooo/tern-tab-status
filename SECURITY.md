# Security

## Scope and support

This experimental plugin is currently maintained at source version `0.2.0`. Fixes target the latest source revision; older snapshots have no backport commitment. Maintainer response times are best effort, with no promised service level.

Tern plugins are trusted local code. Inspect source before installing. Tern Tab Status uses Tern's agent, surface, tab, timer, event, command, settings, action, and key/value APIs. Status polling reads direct `cx.agents:list()` metadata, including native attention, without reading each pane separately. Explicit **New OMP Tab** and **New Pi Tab** commands ask Tern to start `omp` or `pi` without an initial prompt. Tern 0.8.3 requires temporarily selecting the Agent command and `new_tab` placement while synchronously creating a block; both original preferences are restored immediately, including on creation errors. The plugin makes no network requests, installs no agent hooks, and stores no conversation text. Its fallback surface query is bounded to one node, depth one, and 128 characters to identify the `omp.session` role; the returned content is not persisted.

Saved plugin state includes enabled/paused status, per-tab original/applied colors, and per-pane completion results. Tern owns its storage under `plugin-data/tern-tab-status/kv.json`. Records may remain after panes close or the plugin is unlinked. Pause and restore colors before disabling or removing the plugin. Do not publish storage files: they contain local pane/session identifiers.

The plugin has no production dependencies. The pinned development-only Luau runtime is installed through npm for checks. npm installation contacts the configured registry; plugin execution does not.

The separate development runner, `node scripts/verify-native.mjs`, starts real agents with a test-only offline provider in its own Tern configuration and daemon. It retains native metadata, screenshots, logs, source hashes, and process receipts at the printed evidence directory. These are local verification artifacts, not plugin runtime storage. Review artifacts before sharing; do not publish daily-session captures or raw conversation data. The [verification skill](./.cursor/skills/verify-tern-tab-status/SKILL.md) defines the isolation and cleanup contract.

## Reporting privately

Use [GitHub's private vulnerability reporting form](https://github.com/yoyooyooo/tern-tab-status/security/advisories/new). Private reporting is enabled for this public repository. Do not post credentials, full conversation logs, or plugin storage in a public issue.

Include the plugin and Tern versions, OS/architecture, expected and observed behavior, impact, and the smallest reproduction that avoids private session data. Reports are handled on a best-effort basis as described above.

## Limit of the indicator

Tab colors are attention hints. A green dot does not verify task success, and the absence of a dot does not prove no agent is running: Tern must recognize the session and a window must be synchronizing. The plugin does not acknowledge native attention. Tern 0.8.3 can silently ignore color calls for large native tab IDs, affecting status colors and Pause restoration. OMP standalone extension confirmation dialogs can remain native `idle` and produce no yellow dot. See the [known native blockers](./docs/readiness.md#known-native-blockers); do not use the indicator as an approval or security boundary.
