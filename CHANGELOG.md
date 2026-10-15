# Changelog

## 0.2.0 (Unreleased)

- Add separate **New OMP Tab** and **New Pi Tab** commands without changing the configured default Agent command after launch.
- Recognize pi Agent Blocks and reuse the existing work, input-wait, failure, and native attention color rules.
- Launch empty conversations in the current directory; preserve the original Agent command even when block creation fails.
- Document pi 1.1.0 status support through OSC 7501 and the ordinary-shell boundary.
- Put **New OMP Tab** and **New Pi Tab** in the palette's **Agents** group, with short titles so searching `new` surfaces them alongside built-in agent launchers.
- Fix launch commands reporting failure after starting the agent when moving the new pane fails. Create the Agent Block directly with `agent_placement = "new_tab"`, then restore both command and placement preferences.
- Poll direct `cx.agents:list()` snapshots instead of per-agent pane reads, normalize native JSON null values, and retain completion/failure results only while native attention remains.
- Add `scripts/verify-native.mjs` prerequisite, launch, and full native checks with a reusable verification skill and feature map.
- Reject stale native observer snapshots and retain confirmation-dismissal and owned-process exit receipts after failed cases.
- Document Tern 0.8.3 large-tab-ID color/restoration limits and OMP standalone extension confirmations that remain `idle`; unsupported native scenarios are not counted as passed.

## 0.1.0 (Unreleased)

- Use `tern-tab-status` as the repository, package, and Tern plugin ID, with Tern Tab Status as the display name. Initial agent support covers OMP.
- Mirror OMP work, native attention, input waits, and failures in Tern's tab color dot.
- Aggregate OMP panes by failure, waiting, attention, then working priority.
- Preserve original tab colors, including manual changes observed during activity and plugin reloads.
- Provide persisted pause/restore and resume commands.
- Add English and Chinese installation docs, MIT licensing, contributor guidance, and portable behavior checks.
- Document direct GitHub URL installation, repository subdirectory syntax, and manual updates with `--force`.
- Document the isolated native window's **Not Now** update preference to avoid repeated **Manage omp** prompts from fresh test configs.
- Reorganize both READMEs around a centered title, a short outcome description, color meanings, and a three-step first use; fold local installation details.
- Include HTML navigation links in the documentation check.
- Add a native vertical-sidebar screenshot to both READMEs, showing the plugin's four status colors and an idle tab with staged agent signals.

Source is distributed from the public GitHub repository's `main` branch. No tagged release has been created.
