# Changelog

## 0.2.0 (Unreleased)

- Add separate **New OMP Tab** and **New Pi Tab** commands without changing the configured default Agent command after launch.
- Recognize pi Agent Blocks and reuse the existing work, input-wait, failure, and native attention color rules.
- Launch empty conversations in the current directory; preserve the original Agent command even when block creation fails.
- Document pi 1.1.0 status support through OSC 7501 and the unverified ordinary-shell pi boundary.
- Put **New OMP Tab** and **New Pi Tab** in the palette's **Agents** group, with short titles so searching `new` surfaces them alongside built-in agent launchers.
- Fix launch commands reporting failure after starting the agent when moving the new pane fails. Create the Agent Block directly with `agent_placement = "new_tab"`, then restore both command and placement preferences.
- Replace status writes to native `tab.color` with exact-pane CSS over `.tn-dk-c[data-pane][data-st]`. Native working/waiting/done/bell/failed states drive the dot without production `cx.agents:list()` polling.
- Add `host.luau` to publish full native pane ID strings and retain `window.luau` for recognition, CSS, read markers, controls and launchers; remove the obsolete `status.luau` module.
- Preserve side-by-side pane icons and a right-side 7 px status dot in horizontal and vertical tabs. Overlapping dots use red → yellow → green → blue priority; native manual color remains beneath. Reserve right padding for shortcuts and hide the horizontal fallback icon.
- Keep manual native colors unchanged during activity, Pause, Resume and reload. Pause hides CSS status styling; persisted pause is shared across windows on their next refresh.
- Recover old original/applied color records only during upgrade: restore only while the observed color equals old applied, verify actual restoration before clearing that record, and preserve newer manual colors. Ignored large-ID native color calls remain an explicit recovery limitation.
- Persist per-pane viewed markers across leaving, Pause and reload without clearing native attention. Focused results are read; new unseen results remain green/red. Read suppression affects done/bell/failed only, so working and waiting stay visible while focused.
- Recognize direct omp/pi executable basenames and shell-hosted OMP through a one-node, depth-one, 128-character `omp.session` descriptor query. Refresh pane lists/recognition and shared pause on lifecycle events with a 750 ms fallback poll; skip identification while paused.
- Add isolated native verification and its reusable skill/feature map. Read status from screenshot pixels as `statusColor`, while checking real `tab.color` separately for manual colors. Decode native PNGs with Node's built-in zlib, without another dependency.
- Mark confirmation fixtures as automatic acceptance requiring no user action, allow five seconds for native wait reporting, retain unsupported failures and send Escape to dismiss dialogs. OMP standalone `ctx.ui.confirm` still reports idle on observed versions and remains unsupported.
- Retain historical native-ID collision, rejected title-marker CSS and timer-budget evidence with their original scope. The final copied-source CSS run passes 13 of 14 native cases, including manual-color preservation and horizontal/vertical priority; unsupported OMP confirmation keeps the result failed/nonzero. Production daily reload also shows Gmail's blue dot. Versions, hashes, cleanup and remaining high-ID limits are recorded in the readiness document.
- Remove the captured synchronous agent-list polling path without claiming host timer repair. Native CSS state changes no longer require that poll, and lifecycle events synchronize directly without waiting for timers. Disabled timers can still delay changes without a delivered event, including cross-window pause in a quiet window. Protected calls do not recover Tern's disabled timer hook.
- Keep both actual palette launchers and their preference-restoration behavior. Earlier Tern 0.8.3–0.8.4 acceptance remains historical evidence, not approval of the new runtime; required unsupported OMP confirmation keeps full native runs nonzero.
- Synchronize the native roster on host lifecycle events and synchronize window recognition/styles directly on window/pane/tab/command/directory/title events, with 750 ms polling only as fallback. A disabled timer no longer prevents a delivered lifecycle event from updating styles. Add regressions for discovery/shared pause and window-start styling without firing timers.
- Verify 12 selected real OMP/pi lifecycle observations in a controlled window on the existing daemon with native pane IDs above `2^44`: blue work, green/red unseen results, viewing, read persistence across reload and Pi yellow waiting/dismissal. Preserve the failed `ctl tab` attempt and complete Pi via full-native-ID focus without changing production runtime. This supplements the 13/14 copied-source result and does not resolve OMP confirmation, the host timer mechanism or universal legacy recovery.
- Add a focused New Pi Tab guide to both READMEs: separate pi installation and Node.js requirements, Tern-shell PATH/version checks, provider/model setup, verified Agent Block status and missing-command troubleshooting.
- Disable Tern 0.9.0's running-tab title shimmer and white icon sweep in horizontal and vertical tabs while status styling is enabled; restore native appearance on Pause.
- Give only blue working dots a gentle 2.4-second brightness cycle without transparency, scaling or a halo; respect reduced-motion preferences and keep other status dots static. Native screenshot classification recognizes the blue dot throughout its brightness cycle.

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
