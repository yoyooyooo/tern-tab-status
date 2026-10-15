# Security

## Scope and support

This experimental plugin is currently maintained at source version `0.1.0`. Fixes target the latest source revision; older snapshots have no backport commitment. Maintainer response times are best effort, with no promised service level.

Tern plugins are trusted local code. Inspect source before installing. Tern Tab Status uses Tern's agent, pane, surface, tab, timer, event, command, and key/value APIs. It does not request network access, spawn processes, install OMP hooks, or store conversation text. Its surface query is bounded to one node, depth one, and 128 characters to identify the `omp.session` role; the returned content is not persisted.

Saved plugin state includes enabled/paused status, per-tab original/applied colors, and per-pane completion results. Tern owns its storage under `plugin-data/tern-tab-status/kv.json`. Records may remain after panes close or the plugin is unlinked. Pause and restore colors before disabling or removing the plugin. Do not publish storage files: they contain local pane/session identifiers.

The plugin has no production dependencies. The pinned development-only Luau runtime is installed through npm for checks. npm installation contacts the configured registry; plugin execution does not.

## Reporting privately

Use [GitHub's private vulnerability reporting form](https://github.com/yoyooyooo/tern-tab-status/security/advisories/new). Private reporting is enabled for this public repository. Do not post credentials, full conversation logs, or plugin storage in a public issue.

Include the plugin and Tern versions, OS/architecture, expected and observed behavior, impact, and the smallest reproduction that avoids private session data. Reports are handled on a best-effort basis as described above.

## Limit of the indicator

Tab colors are attention hints. A green dot does not verify task success, and the absence of a dot does not prove no agent is running: Tern must recognize the session and a window must be synchronizing.
