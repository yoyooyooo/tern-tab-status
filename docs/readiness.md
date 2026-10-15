# Source distribution readiness

Mode: `convert`. Scope: the public, source-only Tern plugin repository at https://github.com/yoyooyooo/tern-tab-status. Publication of `main` is authorized; no tagged release or universal host compatibility is claimed.

The English README addresses external Tern users; the Chinese version serves the original user community. Both are maintained and cross-linked. The canonical repository, package, and plugin ID is `tern-tab-status`; its display name is Tern Tab Status. Runtime entry points and status behavior are unchanged. Agent support currently covers OMP; pi and other agents are not yet supported.

| Area | Status | Evidence and boundary |
| --- | --- | --- |
| Identity and license | pass | `plugin.toml`, development manifest, and MIT `LICENSE` agree on the plugin identity and source version `0.1.0`. |
| Runtime distribution | pass | Three runtime files: `plugin.toml`, `status.luau`, `window.luau`; Tern loads source directly, with no build or production dependency. |
| Installation and removal contract | pass | Both READMEs document GitHub URL/shorthand and local link/copy installation, manual reload/update, pause before removal, and persistent state. URL formats and `--force` behavior match `tern plugin install --help` on Tern 0.8.3; Git is declared as the URL-install prerequisite. |
| Public reader path | pass | English and Chinese READMEs share installation, state meanings, limitations, privacy, and contribution links. |
| Collaboration | pass | `CONTRIBUTING.md`, `SECURITY.md`, and `CHANGELOG.md` describe the actual source-only workflow and maintenance boundary. |
| Compatibility | pass | Tern `0.8.3` (`e2b8656`), macOS arm64. Native acceptance and the active migrated installation load the plugin. Other hosts remain explicitly unverified. |
| Development dependency audit | pass | `npm audit --json` on 2026-10-15 returned zero known vulnerabilities; `luau-web@1.5.1` is development-only. |
| Portable source checks | pass | `npm run check`: both Luau runtime files compile, 14 behavioral scenarios pass, and 24 local documentation links resolve. The same command passes after `npm ci --ignore-scripts` in an extracted source copy. |
| Clean source installation and live load | pass | A source archive excluding `.git` and `node_modules` installs through `tern plugin install` into a separate config directory. Its plugin commands run in an isolated Tern process; native progress produces a blue tab, and Pause restores its original uncolored state. After migration to `tern-tab-status`, Tern reports the new ID ready without problems, completion state is retained, Resume produces blue/green status colors, and Pause restores all affected tabs to their original colors. |
| Documentation rendering and links | pass | Local previews were inspected at 1280 px and 390 px. The public GitHub English installation section and Chinese narrow README were visually inspected; both language directions and English/Chinese installation anchors were exercised. The 390 px GitHub view has no page overflow. |
| Privacy scan of distribution | pass | Source, docs, test fixture, and lockfile have no matches for maintainer home paths, old installation paths, private hostnames, private key headers, or common credential prefixes. Archive inventory contains the source, both READMEs, supporting docs, license, tests, and tooling; no local state or development packages. |
| Hosted CI | pass | [Check run 38683250332](https://github.com/yoyooyooo/tern-tab-status/actions/runs/38683250332) passed for source commit `ecdf8622083ea9f6242fb21cc90454c475c63af8`. GitHub reports successful checkout, Node.js setup, `npm ci --ignore-scripts`, and `npm run check`. |
| Public repository, support, private reporting | pass | GitHub API readback confirms `yoyooyooo/tern-tab-status` is public, Issues are enabled, and private vulnerability reporting returns `enabled: true`. README, contributor guidance, security policy, and package metadata point to the public repository. |
| GitHub installation of this project | pass | Clean isolated installs succeeded using both the HTTPS repository URL and `github.com/yoyooyooo/tern-tab-status` shorthand. Reinstallation with `--force` succeeded. The HTTPS-installed copy passed `npm ci --ignore-scripts` and all 14 behavior scenarios, loaded in isolated Tern, produced a native blue tab, and restored its original color when paused. Runtime file SHA-256 values match the published source. |
| Additional native wait screenshot | not_verified | The added wait-and-screenshot scenario timed out. Its screenshot is not counted as evidence; wait-state behavior is covered by the portable suite and earlier host acceptance. The rename changes command display titles only within the runtime source. |

## Not applicable to this distribution

- npm package publication, exports, registry name reservation, OIDC, release channels, and provenance: the npm manifest is private development tooling. Tern consumes a directory.
- Build outputs and generated runtime files: Luau source is the installed runtime. The npm lock pins the check dependency only.
- Hosted release automation and tag checks: there is no release workflow. Contributor guidance defines immutable tags if release tags are introduced.
- Issue/PR templates, dependency update bots, a governance board, and a separate conduct policy: this small repository uses GitHub Issues, pull requests, and documented contribution expectations without additional automation.
- Production dependency advisories and bundled third-party runtime notices: the plugin has no production packages and redistributes no third-party runtime code. The MIT development runtime remains an npm dependency under its own license.
- npm releases and tagged-release readback: distribution currently uses the default source branch; no release tag, GitHub Release, or npm publication is part of this conversion.

## Publication verification

The public repository, MIT license, default branch, Issues, and private reporting endpoint were read back through GitHub. Source commit `ecdf8622083ea9f6242fb21cc90454c475c63af8` is publicly reachable and its hosted CI passed. Direct GitHub installation, manual update, installed runtime behavior, and hosted README navigation were exercised. Source history begins with this repository conversion and contains no imported private history.

Readiness: **conditional** because the additional native wait screenshot remains unverified after a timeout; no 100% readiness claim is made. Public source distribution itself is verified. Platform support remains limited to Tern 0.8.3 on macOS arm64, and pi is not yet supported.

## Documentation audit

Audit date: 2026-10-15. Project: Tern Tab Status. Scope: both READMEs, contributor/security/changelog/readiness documents, plugin manifest, runtime modules, check script, behavior suite, dependency manifests, and CI workflow.

Conclusion: pass for the public source contract. Findings: P0: 0, P1: 0, P2: 0, P3: 0. Public push, hosted CI, GitHub URL installation/update, installed runtime smoke, and GitHub-rendered navigation have evidence above. An earlier optional native wait screenshot timed out and is not counted as a successful verification; portable input-wait tests and earlier host acceptance remain separate evidence.

Reviewed scenarios: GitHub URL/shorthand, repository subdirectory selection, local copy/link installation, and upgrade commands against Tern CLI help, plus clean local installation; state priority and read/unread behavior against `status.luau` and native pane alerts; manual-color restoration and shared pause against `window.luau`; runtime dependencies, bounded surface inspection, local persistence, and networking statements against the actual runtime API calls. All claims are limited to the evidence above.

No product demo, registry publication, tag, or release automation is required for source distribution. Changelog, consumer documentation, checks, and CI configuration are included. README screenshots are verification artifacts and are not distributed as product evidence.
