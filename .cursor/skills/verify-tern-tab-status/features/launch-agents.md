# Launch OMP or Pi in its own tab

Open the chosen real agent at the current directory without changing the normal Agent Block defaults.

## Sub-features

- New OMP Tab launches a real OMP Agent Block in a selected new tab.
- New Pi Tab launches a real Pi Agent Block in a selected new tab.
- Both start without an initial prompt and preserve default Agent command and placement.
- Bindable action IDs reach the same commands registered in the palette.

## How to get to it (user POV)

Open Tern's command palette, search `new`, and choose **New OMP Tab** or **New Pi Tab** in the **Agents** group. Keyboard settings can bind `plugin.tern-tab-status.new_omp_tab` and `plugin.tern-tab-status.new_pi_tab`. The runner drives both palette entries and retains their native palette receipts.

## Driving it with verify-native

Run from the repository root:

```sh
node scripts/verify-native.mjs --doctor
node scripts/verify-native.mjs --case launch --out /tmp/tern-launch-proof-$(date +%s)
```

The helper launches a fresh isolated native daemon/window and installs `plugin.toml`, `host.luau`, `window.luau` and `LICENSE`; the former `status.luau` is excluded. It selects a distinctive default `omp --model preserved-default` with `split` placement, invokes `ctl palette '"New OMP Tab"'` or `'"New Pi Tab"'`, then `ctl key enter`. Each real Agent Block must be idle, focused and in a new tab at the original pane's cwd. The provider reports extension initialization under the chosen host with zero requests. Native `agent_command` and `agent_placement` settings must match before/after. Pause must not affect either launcher.

Inspect `launch-omp` and `launch-pi` in `summary.json`, the provider receipts, `palette.jsonl`, and both screenshot paths. The helper automatically cleans up; require recorded exit proof and retained screenshots. The full runner includes the same cases.

## Gotchas

The private host filter appends test flags/extensions to plain `omp` and `pi`; production launchers remain unchanged. A typed shell `pi` command does not prove an Agent Block exists, and a source-text assertion cannot prove initialization. Never reuse daily routing environment. Full native pane strings now target status CSS independently of SDK tab-color addressing; fresh-daemon launch proof still does not establish every daily lifecycle or legacy recovery. Retain evidence for failures too.
