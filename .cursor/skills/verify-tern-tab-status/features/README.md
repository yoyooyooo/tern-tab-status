# Tern Tab Status feature map

The maintained verification surface is Tern's native command palette, tab dots and individual OMP/Pi Agent Blocks. Read the skill before driving a feature. Each full run covers all three entries below; `--case launch` covers the first entry for a fresh independent skill evaluation.

| Feature | User entry points | Runner cases | Proof |
| --- | --- | --- | --- |
| [Launch OMP or Pi](launch-agents.md) | Agents → New OMP Tab; Agents → New Pi Tab; corresponding bindable action IDs | `launch-omp`, `launch-pi` | Selected new tab, current cwd, correct real host, no initial prompt, default command/placement restored |
| [Read activity and attention](status-attention.md) | Send request; switch tabs; return to individual pane; respond to confirmation | `omp-working-completion`, `omp-failure`, `omp-confirmation`; same three for `pi`; `mixed-pane-attention`, `mixed-pane-priority` | Blue/green/red/yellow native dots, per-pane acknowledgment, yellow over blue and red over yellow |
| [Preserve manual colors and pause](color-controls.md) | Manual native tab color; palette Pause/Resume; `tern plugin reload` | `manual-pause-resume-reload` | Original/manual color survives temporary status, pause and reload |

Real OMP/Pi lifecycle is mandatory. Only the model provider is offline. Evidence goes in the directory printed by `scripts/verify-native.mjs`, persists after owned-process cleanup, and includes exact versions and installation hashes. This map does not assert compatibility with a daily daemon containing high native IDs; the isolated runner covers a newly owned daemon.
