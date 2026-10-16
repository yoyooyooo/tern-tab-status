# Tern Tab Status feature map

The maintained verification surface is Tern's native command palette, tab dots and individual OMP/Pi Agent Blocks. Read the skill before driving a feature. Each full run covers all three entries below; `--case launch` covers the first entry for a fresh independent skill evaluation.

| Feature | User entry points | Runner cases | Proof |
| --- | --- | --- | --- |
| [Launch OMP or Pi](launch-agents.md) | Agents → New OMP Tab; Agents → New Pi Tab; corresponding bindable action IDs | `launch-omp`, `launch-pi` | Selected new tab, current cwd, correct real host, no initial prompt, default command/placement restored |
| [Read activity and attention](status-attention.md) | Request; switch tabs; view individual pane; finish while focused; automatic confirmation fixture | `omp-working-completion`, `omp-focused-completion`, `omp-failure`, `omp-confirmation`; same four for `pi`; `mixed-pane-attention`, `mixed-pane-priority`, `horizontal-mixed-priority` | Screenshot-pixel `statusColor`, read persistence, per-pane acknowledgment, horizontal/vertical priority, side-by-side icons and clear shortcuts |
| [Preserve manual colors and pause](color-controls.md) | Native tab color; palette Pause/Resume; `tern plugin reload` | `manual-pause-resume-reload` | Real native `tab.color` stays manual throughout CSS status, pause and reload; legacy recovery is verified separately |

Real OMP/Pi lifecycle is mandatory; only the provider is offline. Confirmation text says automatic acceptance/no user action; allow five seconds for waiting, retain unsupported failures and close with Escape. Evidence survives owned-process cleanup and includes exact versions and install hashes. Full native pane strings avoid the SDK status color bridge. Separate selected daily lookup/blue-dot observations and 12 controlled high-ID lifecycle observations supplement the fresh-daemon run; they do not establish every daily path or legacy recovery. See [current cutover evidence](../../../../docs/readiness.md#current-css-cutover-evidence).
