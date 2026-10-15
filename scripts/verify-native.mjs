#!/usr/bin/env node
import assert from "node:assert/strict";
import { spawn, spawnSync } from "node:child_process";
import { constants } from "node:fs";
import { access, appendFile, copyFile, mkdir, mkdtemp, readFile, readdir, realpath, stat, writeFile } from "node:fs/promises";
import { createHash, randomUUID } from "node:crypto";
import { delimiter, dirname, join, resolve } from "node:path";
import { homedir, tmpdir } from "node:os";
import { fileURLToPath } from "node:url";

const root = resolve(dirname(fileURLToPath(import.meta.url)), "..");
const argv = process.argv.slice(2);
function option(name, fallback) {
  const index = argv.indexOf(name);
  if (index < 0) return fallback;
  assert.ok(argv[index + 1] && !argv[index + 1].startsWith("--"), `${name} requires a value`);
  return argv[index + 1];
}
const mode = option("--case", "all");
assert.ok(["all", "launch"].includes(mode), "--case must be all or launch");
const base = option("--out") ? resolve(option("--out")) : await mkdtemp(join(tmpdir(), "tern-tab-status-native-"));
await mkdir(base, { recursive: true });
const summaryPath = join(base, "summary.json");
const summary = { schema: 1, started: new Date().toISOString(), case: mode, evidenceDir: base, result: "running", installation: {}, versions: {}, cases: [], processes: [], unsupported: [] };
const save = () => writeFile(summaryPath, JSON.stringify(summary, null, 2) + "\n");
const socket = join(base, "control.sock");
const daemonSocket = join(base, "daemon.sock");
const ternDir = join(base, "tern");
const shots = join(base, "shots");
const cwd = join(base, "workspace");
const providerLog = join(base, "provider.jsonl");
const childLogs = [];
const owned = [];
let stopping = false;
const pause = ms => new Promise(resolve => setTimeout(resolve, ms));
const env = Object.fromEntries(Object.entries(process.env).filter(([key]) => !key.startsWith("TERN_") && !/^(PI_|OMP_|ANTHROPIC_|OPENAI_|GOOGLE_|GEMINI_|AWS_|AZURE_|NODE_OPTIONS)/.test(key)));
Object.assign(env, { TERN_CONFIG_DIR: ternDir, TERN_DAEMON_SOCKET: daemonSocket, STENCIL_LOG_DIR: join(base, "logs"), STENCIL_LOG: "warn,tern::plugin=debug", TERN_STATUS_VERIFY_DIR: base });

function command(file, args, options = {}) {
  const result = spawnSync(file, args, { cwd: base, env, encoding: "utf8", timeout: 30000, maxBuffer: 16 * 1024 * 1024, ...options });
  if (result.error || result.status !== 0) throw new Error(`${file} ${args.join(" ")}: ${result.error?.message ?? `exit ${result.status}`}\n${result.stdout ?? ""}\n${result.stderr ?? ""}`);
  return result.stdout;
}
async function executable(name, override) {
  if (override) { await access(override, constants.X_OK); return await realpath(override); }
  for (const dir of (process.env.PATH ?? "").split(delimiter)) {
    const candidate = join(dir, name);
    try { await access(candidate, constants.X_OK); return await realpath(candidate); }
    catch (error) { if (!["ENOENT", "ENOTDIR", "EACCES"].includes(error.code)) throw error; }
  }
  throw new Error(`Missing prerequisite: ${name} is not executable on PATH`);
}
async function hostExecutable(name) {
  const selected = await executable(name, process.env[`TERN_VERIFY_${name.toUpperCase()}_BIN`]);
  // Resolve Volta before isolating agent configuration. Its shim can otherwise use
  // the developer's package routing or recurse when launched from a fixture HOME.
  const prefix = (await readFile(selected)).subarray(0, 4096).toString("utf8");
  const volta = join(process.env.VOLTA_HOME ?? join(homedir(), ".volta"), "bin", "volta");
  if (selected.includes("/.volta/") || prefix.includes("/.volta/bin/")) {
    try { return command(volta, ["which", name], { env: process.env }).trim(); }
    catch (error) { throw new Error(`Cannot resolve ${name} Volta shim: ${error.message}`); }
  }
  return selected;
}
let ternBin;
function ctl(...args) {
  const text = command(ternBin, ["ctl", "--control", socket, ...args]);
  let result;
  try { result = JSON.parse(text); } catch { throw new Error(`Native control returned non-JSON: ${text}`); }
  assert.notEqual(result.ok, false, JSON.stringify(result));
  return result;
}
const action = id => ctl("plugins", "run", id);
async function until(label, predicate, timeout = 30000) {
  const deadline = Date.now() + timeout;
  while (Date.now() < deadline) {
    const dead = owned.find(({ child }) => child.exitCode !== null || child.signalCode !== null);
    if (dead && !stopping) throw new Error(`Owned ${dead.record.role} exited while waiting for ${label}`);
    const value = await predicate();
    if (value) return value;
    await pause(125);
  }
  throw new Error(`Timed out after ${timeout}ms: ${label}`);
}
async function snapshot() {
  const nonce = randomUUID();
  await writeFile(join(base, "snapshot-request.json"), JSON.stringify({ nonce }));
  action("plugin.tern-status-verification.snapshot");
  const value = JSON.parse(await readFile(join(base, "snapshot.json"), "utf8"));
  assert.equal(value.nonce, nonce, "Observer snapshot hook did not publish the requested fresh state; inspect native plugin errors");
  return value;
}
async function drive(request) {
  await writeFile(join(base, "drive.json"), JSON.stringify(request));
  action("plugin.tern-status-verification.drive");
  return snapshot();
}
const agent = (value, pane) => value.agents.find(item => item.pane === pane);
const tab = (value, id) => value.tabs.find(item => item.id === id);
const paneTab = (value, pane) => agent(value, pane)?.tab ?? value.panes.find(item => item.pane === pane)?.tab;
async function waitPane(label, pane, predicate, timeout) {
  return until(label, async () => { const value = await snapshot(); return predicate(agent(value, pane), tab(value, paneTab(value, pane)), value) && value; }, timeout);
}
async function providerEvents() {
  try { return (await readFile(providerLog, "utf8")).trim().split("\n").filter(Boolean).map(JSON.parse); }
  catch (error) { if (error.code === "ENOENT") return []; throw error; }
}
async function send(pane, text) {
  command(ternBin, ["send", String(pane), "text", text]);
  command(ternBin, ["send", String(pane), "keys", "enter"]);
}
async function palette(title) {
  const result = ctl("palette", JSON.stringify(title));
  await appendFile(join(base, "palette.jsonl"), JSON.stringify({ title, result }) + "\n");
  ctl("key", "enter");
}
async function capture(name) {
  const result = ctl("shot", name);
  await writeFile(join(base, `${name}-shot.json`), JSON.stringify(result, null, 2));
  assert.equal(typeof result.png, "string", `Native screenshot has no PNG path: ${JSON.stringify(result)}`);
  const file = await realpath(result.png);
  const ownedShots = await realpath(shots);
  assert.ok(file.startsWith(`${ownedShots}/`), `Screenshot escaped owned evidence directory: ${file}`);
  assert.ok((await stat(file)).isFile(), `Native screenshot missing: ${file}`);
  return file;
}
async function scenario(name, description, perform) {
  const record = { name, action: description, started: new Date().toISOString(), result: "running", before: await snapshot() };
  summary.cases.push(record);
  await save();
  try {
    await perform(record);
    record.after = await snapshot();
    record.screenshot = await capture(name);
    record.result = "passed";
  } catch (error) {
    record.result = "failed";
    record.error = error.stack;
    try { record.after = await snapshot(); record.screenshot = await capture(`${name}-failed`); } catch (captureError) { record.captureError = captureError.message; }
    summary.result = "failed";
    if (name.startsWith("launch-")) throw error;
    const events = await providerEvents();
    for (const host of ["omp", "pi"]) {
      const hostEvents = events.filter(event => event.host === host);
      const latestOpen = hostEvents.findLastIndex(event => event.event === "confirm_open");
      const latestClosed = hostEvents.findLastIndex(event => event.event === "confirm_closed");
      const target = record.after?.agents.find(item => (item.agent_command ?? item.command) === host);
      if (latestOpen > latestClosed && target) {
        if (name.endsWith("-confirmation")) summary.unsupported.push({ case: name, host, reason: "Actual blocking confirmation did not reach the required native waiting_input/yellow state", nativeState: target.state, screenshot: record.screenshot });
        await drive({ op: "focus", pane: target.pane });
        command(ternBin, ["send", String(target.pane), "keys", "esc"]);
        const openedAt = hostEvents[latestOpen].time;
        await until(`${host} actual confirmation closed during cleanup`, async () => (await providerEvents()).some(event => event.host === host && event.event === "confirm_closed" && event.time >= openedAt));
      }
    }
  } finally { record.finished = new Date().toISOString(); await save(); }
}
async function own(role, args) {
  const child = spawn(ternBin, args, { cwd: base, env, stdio: ["ignore", "pipe", "pipe"], detached: true });
  const record = { role, pid: child.pid, executable: ternBin, args, started: new Date().toISOString() };
  const entry = { child, record };
  owned.push(entry);
  summary.processes.push(record);
  let logs = Promise.resolve();
  for (const [streamName, stream] of [["stdout", child.stdout], ["stderr", child.stderr]]) stream.on("data", bytes => { logs = logs.then(() => appendFile(join(base, `${role}.${streamName}.log`), bytes)); });
  child.on("error", error => { record.spawnError = error.message; });
  child.on("exit", (code, signal) => { record.exit = { code, signal, at: new Date().toISOString() }; });
  childLogs.push(() => logs);
  await save();
  return entry;
}
async function stopOwned() {
  stopping = true;
  const hostPids = [...new Set((await providerEvents()).filter(event => event.event === "extension_loaded").map(event => event.pid))];
  // Each detached child owns its process group. This never signals a name or an
  // inherited daily Tern process; the daemon's PTYs are destroyed on its exit.
  for (const { child, record } of [...owned].reverse()) {
    if (child.pid && child.exitCode === null && child.signalCode === null) {
      record.teardown = { requested: "SIGTERM", at: new Date().toISOString() };
      try { process.kill(-child.pid, "SIGTERM"); } catch (error) { if (error.code !== "ESRCH") record.teardown.error = error.message; }
      const deadline = Date.now() + 4000;
      while (child.exitCode === null && child.signalCode === null && Date.now() < deadline) await pause(100);
      if (child.exitCode === null && child.signalCode === null) {
        record.teardown.escalated = "SIGKILL";
        try { process.kill(-child.pid, "SIGKILL"); } catch (error) { if (error.code !== "ESRCH") record.teardown.killError = error.message; }
        await Promise.race([new Promise(resolve => child.once("close", resolve)), pause(2000)]);
      }
    }
    record.exitProof = { code: child.exitCode, signal: child.signalCode, observed: child.exitCode !== null || child.signalCode !== null };
  }
  summary.agentProcesses = [];
  for (const pid of hostPids) {
    const proof = { pid, source: providerLog, exited: false };
    try { process.kill(pid, 0); } catch (error) { if (error.code === "ESRCH") proof.exited = true; else proof.error = error.message; }
    if (!proof.exited && !proof.error) {
      try { process.kill(pid, "SIGTERM"); } catch (error) { if (error.code === "ESRCH") proof.exited = true; else proof.error = error.message; }
      const deadline = Date.now() + 3000;
      while (Date.now() < deadline) {
        try { process.kill(pid, 0); } catch (error) { if (error.code === "ESRCH") { proof.exited = true; break; } proof.error = error.message; break; }
        await pause(100);
      }
      if (!proof.exited) {
        try { process.kill(pid, "SIGKILL"); } catch (error) { if (error.code === "ESRCH") proof.exited = true; else proof.error = error.message; }
      }
    }
    if (!proof.exited && !proof.error) {
      const deadline = Date.now() + 2000;
      while (Date.now() < deadline) {
        try { process.kill(pid, 0); } catch (error) { if (error.code === "ESRCH") { proof.exited = true; break; } proof.error = error.message; break; }
        await pause(100);
      }
    }
    summary.agentProcesses.push(proof);
  }
  for (const flush of childLogs) await flush();
}
async function logScan() {
  const findings = [];
  async function visit(path) {
    let entries;
    try { entries = await readdir(path, { withFileTypes: true }); } catch (error) { if (error.code === "ENOENT") return; throw error; }
    for (const entry of entries) {
      const file = join(path, entry.name);
      if (entry.isDirectory()) await visit(file);
      else if (entry.isFile()) {
        const lines = (await readFile(file, "utf8")).split("\n");
        lines.forEach((line, index) => { if (/(tern-tab-status|tern-status-verification)/i.test(line) && /(error|failed|panic|exception|stack traceback)/i.test(line)) findings.push({ file, line: index + 1, text: line }); });
      }
    }
  }
  await visit(join(base, "logs"));
  summary.runtimeHookErrors = findings;
  await writeFile(join(base, "runtime-hook-errors.json"), JSON.stringify(findings, null, 2));
}
async function main() {
  assert.equal(process.platform, "darwin", "Native verification requires macOS and Tern.app");
  ternBin = await executable("tern", process.env.TERN_BIN ?? "/Applications/Tern.app/Contents/MacOS/tern");
  summary.versions.tern = command(ternBin, ["--version"]).trim();
  const hosts = {};
  for (const host of ["omp", "pi"]) {
    const file = await hostExecutable(host);
    summary.versions[host] = { executable: file, version: command(file, ["--version"], { env: process.env }).trim() };
    const agentDir = join(base, `${host}-config`);
    const sessionDir = join(base, `${host}-sessions`);
    if (!argv.includes("--doctor")) {
      await mkdir(agentDir, { recursive: true });
      await mkdir(sessionDir, { recursive: true });
      await writeFile(join(agentDir, "config.yml"), "startup:\n  setupWizard: false\n  checkUpdate: false\ncompaction:\n  enabled: false\n");
      await writeFile(join(agentDir, "settings.json"), JSON.stringify({ defaultProvider: "tern-status-offline", defaultModel: "delayed", enableTerminalTitle: false }));
    }
    const common = ["--no-extensions", "--no-skills", "--no-tools", "-e", join(base, "offline-provider.mjs"), "--model", "tern-status-offline/delayed", "--session-dir", sessionDir];
    hosts[host] = { executable: file, agentDir, sessionDir, args: host === "omp" ? ["--no-rules", "--no-title", ...common] : ["--offline", "--no-mcp", "--no-prompt-templates", "--no-context-files", "--no-themes", "--no-approve", "--thinking", "off", ...common] };
  }
  if (argv.includes("--doctor")) {
    summary.result = "doctor-passed";
    summary.doctor = { platform: process.platform, isolatedConfig: ternDir, nativeExecutable: ternBin, note: "Read-only prerequisite check; no daemon/window started" };
    return;
  }
  for (const directory of [cwd, ternDir, shots, join(ternDir, "omp")]) await mkdir(directory, { recursive: true });
  await writeFile(join(ternDir, "omp/state.json"), JSON.stringify({ managed: false, checked: 0, no_build: false, offered: true }) + "\n");
  // A copied source installation tests what can be distributed, independent of
  // linked checkout state and unrelated development files.
  const source = join(base, "source-install");
  await mkdir(source);
  const hashes = {};
  for (const file of ["plugin.toml", "window.luau", "status.luau", "LICENSE"]) {
    await copyFile(join(root, file), join(source, file));
    hashes[file] = createHash("sha256").update(await readFile(join(source, file))).digest("hex");
  }
  await copyFile(join(root, "scripts/fixtures/offline-provider.mjs"), join(base, "offline-provider.mjs"));
  const observer = join(base, "observer");
  await mkdir(observer);
  await copyFile(join(root, "scripts/fixtures/observer.luau"), join(observer, "window.luau"));
  await copyFile(join(root, "scripts/fixtures/host.luau"), join(observer, "host.luau"));
  await writeFile(join(observer, "plugin.toml"), 'schema = 1\nid = "tern-status-verification"\nname = "Native verification observer"\nversion = "0.1.0"\nwindow = "window.luau"\nhost = "host.luau"\n');
  await writeFile(join(base, "host-config.json"), JSON.stringify({ ...hosts, daemonSocket, env: { TERN_STATUS_VERIFY_PROVIDER_LOG: providerLog, TERN_STATUS_VERIFY_DIR: base, TERN_CONFIG_DIR: ternDir, STENCIL_LOG_DIR: join(base, "logs") } }));
  command(ternBin, ["plugin", "install", source, "--json"]);
  command(ternBin, ["plugin", "install", observer, "--json"]);
  const installed = JSON.parse(command(ternBin, ["plugin", "list", "--json"]));
  assert.ok(installed.plugins.some(plugin => plugin.id === "tern-tab-status" && plugin.status === "ready"), JSON.stringify(installed));
  assert.deepEqual(installed.problems, []);
  const installedDirectory = join(ternDir, "plugins", "tern-tab-status");
  const installedHashes = {};
  for (const [file, hash] of Object.entries(hashes)) {
    installedHashes[file] = createHash("sha256").update(await readFile(join(installedDirectory, file))).digest("hex");
    assert.equal(installedHashes[file], hash, `Installed runtime differs from distributable source: ${file}`);
  }
  summary.installation = { source, installedDirectory, hashes, installedHashes, manifest: await readFile(join(source, "plugin.toml"), "utf8"), installed };
  await writeFile(join(base, "installation.json"), JSON.stringify(summary.installation, null, 2));
  await own("daemon", ["daemon", "--socket", daemonSocket]);
  await until("owned daemon socket", async () => { try { return (await stat(daemonSocket)).isSocket(); } catch (error) { if (error.code === "ENOENT") return false; throw error; } });
  await own("window", ["--control", socket, "--out", shots, cwd]);
  await until("owned window control socket", async () => { try { return (await stat(socket)).isSocket(); } catch (error) { if (error.code === "ENOENT") return false; throw error; } });
  ctl("ready");
  const initial = await snapshot();
  const homePane = initial.focused;
  assert.ok(homePane, "Owned window needs a focused initial pane");
  summary.doctor = { daemonSocket, controlSocket: socket, ownedPids: summary.processes.map(process => process.pid), snapshot: initial };
  await drive({ op: "settings", values: { agent_command: "omp --model preserved-default", agent_placement: "split" } });
  const launched = {};
  for (const host of ["omp", "pi"]) {
    await drive({ op: "focus", pane: homePane });
    await scenario(`launch-${host}`, `Command palette → Agents → New ${host === "omp" ? "OMP" : "Pi"} Tab`, async record => {
      const before = await snapshot();
      await palette(host === "omp" ? "New OMP Tab" : "New Pi Tab");
      const after = await until(`${host} Agent Block without initial prompt`, async () => {
        const value = await snapshot();
        const created = value.agents.find(item => !before.agents.some(old => old.pane === item.pane));
        const loaded = (await providerEvents()).some(event => event.host === host && event.event === "extension_loaded");
        return created && created.state === "idle" && value.focused === created.pane && loaded && value;
      }, 60000);
      const created = after.agents.find(item => !before.agents.some(old => old.pane === item.pane));
      assert.equal(created.agent_command ?? created.command, host, `Chosen Agent Block must retain plain ${host} command`);
      assert.equal(after.tabs.length, before.tabs.length + 1, "Launch must create exactly one tab");
      assert.ok(before.panes.every(pane => after.panes.some(current => current.pane === pane.pane)), "Existing panes must remain intact");
      assert.notEqual(created.tab, paneTab(before, homePane), "Launch must open a new tab");
      assert.equal(await realpath(created.cwd), await realpath(cwd));
      assert.deepEqual(after.settings, before.settings, "Default Agent command and placement must be restored");
      const loaded = (await providerEvents()).filter(event => event.host === host);
      assert.ok(loaded.some(event => event.event === "extension_loaded"), `Actual ${host} fixture must load`);
      assert.ok(!loaded.some(event => event.event === "request"), "Launch must not submit an initial prompt");
      launched[host] = { pane: created.pane, tab: created.tab };
      record.selected = created;
      record.providerEvents = loaded;
    });
  }
  if (mode === "launch") { summary.result = "passed"; return; }
  for (const host of ["omp", "pi"]) {
    const target = launched[host];
    await scenario(`${host}-working-completion`, `Send VERIFY_SUCCESS through owned pane ${target.pane}; switch away; view completion`, async record => {
      await drive({ op: "focus", pane: target.pane });
      await send(target.pane, "VERIFY_SUCCESS");
      await drive({ op: "focus", pane: homePane });
      record.working = await waitPane(`${host} real work is blue`, target.pane, (agent, tab) => agent?.state === "working" && tab?.color === "blue");
      record.workingScreenshot = await capture(`${host}-working`);
      record.completed = await waitPane(`${host} unseen completion is green`, target.pane, (agent, tab) => agent?.state === "idle" && agent.alert && tab?.color === "green");
      record.completedScreenshot = await capture(`${host}-completion-away`);
      await drive({ op: "focus", pane: target.pane });
      await waitPane(`${host} viewed completion restores color`, target.pane, (agent, tab) => !agent.alert && !tab?.color);
    });
    await scenario(`${host}-failure`, `Send VERIFY_FAILURE through owned pane ${target.pane}; switch away; view failure`, async record => {
      await drive({ op: "focus", pane: target.pane });
      await send(target.pane, "VERIFY_FAILURE");
      await drive({ op: "focus", pane: homePane });
      record.failed = await waitPane(`${host} unseen error is red`, target.pane, (agent, tab) => agent?.state === "idle" && agent.alert && tab?.color === "red");
      record.failureScreenshot = await capture(`${host}-failure-away`);
      await drive({ op: "focus", pane: target.pane });
      await waitPane(`${host} viewed failure restores color`, target.pane, (agent, tab) => !agent.alert && !tab?.color);
    });
    await scenario(`${host}-confirmation`, `Submit /verify-confirm in actual ${host} UI; retain yellow while focused; dismiss`, async record => {
      await drive({ op: "focus", pane: target.pane });
      await send(target.pane, "/verify-confirm");
      record.waitingFocused = await waitPane(`${host} actual focused confirmation is yellow`, target.pane, (agent, tab, value) => agent?.state === "waiting_input" && tab?.color === "yellow" && value.focused === target.pane);
      record.confirmationOpened = (await providerEvents()).findLast(event => event.host === host && event.event === "confirm_open");
      assert.ok(record.confirmationOpened, "Actual confirmation must publish an open receipt");
      record.waitingScreenshot = await capture(`${host}-confirmation-focused`);
      await drive({ op: "focus", pane: homePane });
      await drive({ op: "focus", pane: target.pane });
      await waitPane(`${host} viewing must not clear input wait`, target.pane, (agent, tab) => agent?.state === "waiting_input" && tab?.color === "yellow");
      command(ternBin, ["send", String(target.pane), "keys", "esc"]);
      record.dismissed = await waitPane(`${host} dismissed confirmation leaves waiting state`, target.pane, (agent, tab) => agent?.state === "idle" && tab?.color !== "yellow");
      await until(`${host} actual dismissed confirmation receipt`, async () => (await providerEvents()).some(event => event.host === host && event.event === "confirm_closed" && event.time >= record.confirmationOpened.time));
      await drive({ op: "focus", pane: homePane });
      await drive({ op: "focus", pane: target.pane });
      await waitPane(`${host} viewing new dismissal attention restores color`, target.pane, (agent, tab) => !agent.alert && !tab?.color);
    });
  }
  await scenario("mixed-pane-attention", "Move Pi beside OMP; complete both away; view one pane at a time", async record => {
    const omp = launched.omp.pane, pi = launched.pi.pane;
    await drive({ op: "move", pane: pi, tab: launched.omp.tab });
    await send(omp, "VERIFY_SUCCESS");
    await send(pi, "VERIFY_SUCCESS");
    await drive({ op: "focus", pane: homePane });
    record.bothUnread = await until("both real pane completions unseen", async () => {
      const value = await snapshot();
      return [omp, pi].every(pane => agent(value, pane)?.state === "idle" && agent(value, pane)?.alert) && tab(value, paneTab(value, omp))?.color === "green" && value;
    });
    await drive({ op: "focus", pane: omp });
    record.onlyPiUnread = await until("focusing OMP retains Pi attention", async () => { const value = await snapshot(); return !agent(value, omp)?.alert && agent(value, pi)?.alert && tab(value, paneTab(value, omp))?.color === "green" && value; });
    record.unreadScreenshot = await capture("mixed-pane-one-unread");
    await send(omp, "VERIFY_SUCCESS");
    record.unreadOverWorking = await until("green unread Pi outranks blue OMP work", async () => {
      const value = await snapshot();
      return agent(value, omp)?.state === "working" && agent(value, pi)?.alert && tab(value, paneTab(value, omp))?.color === "green" && value;
    });
    await until("focused OMP work completes while Pi remains unread", async () => {
      const value = await snapshot();
      return agent(value, omp)?.state === "idle" && agent(value, pi)?.alert;
    });
    await drive({ op: "focus", pane: homePane });
    await drive({ op: "focus", pane: omp });
    record.onlyPiUnreadAfterNewCompletion = await waitPane("viewing new OMP completion retains Pi attention", omp, (item, tab, value) => !item.alert && agent(value, pi)?.alert && tab?.color === "green");
    await drive({ op: "focus", pane: pi });
    await waitPane("viewing both panes restores tab", pi, (_agent, tab) => !tab?.color);
  });
  await scenario("mixed-pane-priority", "Run OMP while Pi waits; fail OMP away; view failure; dismiss Pi confirmation", async record => {
    const omp = launched.omp.pane, pi = launched.pi.pane;
    await drive({ op: "focus", pane: pi });
    await send(pi, "/verify-confirm");
    await waitPane("Pi confirmation established in mixed tab", pi, (agent, tab) => agent?.state === "waiting_input" && tab?.color === "yellow");
    const confirmationOpened = (await providerEvents()).findLast(event => event.host === "pi" && event.event === "confirm_open");
    assert.ok(confirmationOpened, "Mixed confirmation must publish an open receipt");
    await send(omp, "VERIFY_FAILURE");
    await drive({ op: "focus", pane: homePane });
    record.waitingOverWorking = await until("yellow outranks real blue work", async () => {
      const value = await snapshot();
      return agent(value, omp)?.state === "working" && agent(value, pi)?.state === "waiting_input" && tab(value, paneTab(value, omp))?.color === "yellow" && value;
    });
    record.yellowScreenshot = await capture("mixed-priority-yellow");
    record.failureOverWaiting = await until("red failure outranks yellow wait", async () => {
      const value = await snapshot();
      return agent(value, omp)?.state === "idle" && agent(value, omp)?.alert && agent(value, pi)?.state === "waiting_input" && tab(value, paneTab(value, omp))?.color === "red" && value;
    });
    record.redScreenshot = await capture("mixed-priority-red");
    await drive({ op: "focus", pane: omp });
    await waitPane("viewing failure leaves other pane yellow", omp, (agent, tab) => !agent.alert && tab?.color === "yellow");
    await drive({ op: "focus", pane: pi });
    command(ternBin, ["send", String(pi), "keys", "esc"]);
    record.dismissed = await waitPane("mixed confirmation leaves waiting state", pi, (agent, tab) => agent?.state === "idle" && tab?.color !== "yellow");
    await until("mixed actual dismissed confirmation receipt", async () => (await providerEvents()).some(event => event.host === "pi" && event.event === "confirm_closed" && event.time >= confirmationOpened.time));
    await drive({ op: "focus", pane: homePane });
    await drive({ op: "focus", pane: omp });
    await drive({ op: "focus", pane: pi });
    await waitPane("viewing new mixed completion attention restores tab", pi, (_agent, tab, value) => !agent(value, omp)?.alert && !agent(value, pi)?.alert && !tab?.color);
  });
  await scenario("manual-pause-resume-reload", "Set purple; run delayed work; pause/resume via palette; change manual color; reload copied plugin", async record => {
    const pane = launched.omp.pane;
    await drive({ op: "focus", pane: homePane });
    await drive({ op: "focus", pane: launched.omp.pane });
    await drive({ op: "focus", pane: launched.pi.pane });
    await drive({ op: "focus", pane });
    await waitPane("manual color scenario starts with all attention viewed", pane, (_agent, _tab, value) => !agent(value, launched.omp.pane)?.alert && !agent(value, launched.pi.pane)?.alert);
    const value = await snapshot();
    const targetTab = paneTab(value, pane);
    await drive({ op: "color", tab: targetTab, color: "purple" });
    await send(pane, "VERIFY_LONG");
    await drive({ op: "focus", pane: homePane });
    await waitPane("manual original becomes blue while working", pane, (agent, tab) => agent?.state === "working" && tab?.color === "blue");
    await palette("Tern Tab Status: Pause and Restore Tab Colors");
    record.paused = await waitPane("pause restores purple", pane, (_agent, tab) => tab?.color === "purple");
    await palette("Tern Tab Status: Resume");
    await waitPane("resume reapplies blue", pane, (agent, tab) => agent?.state === "working" && tab?.color === "blue");
    await drive({ op: "color", tab: targetTab, color: "orange" });
    await waitPane("manual orange captured during work", pane, (agent, tab) => agent?.state === "working" && tab?.color === "blue");
    command(ternBin, ["plugin", "reload"]);
    await waitPane("reload keeps real working state", pane, (agent, tab) => agent?.state === "working" && tab?.color === "blue");
    record.reloaded = await snapshot();
    await waitPane("completion after reload is green", pane, (agent, tab) => agent?.state === "idle" && agent.alert && tab?.color === "green");
    await drive({ op: "focus", pane });
    await waitPane("manual orange restored after viewing", pane, (agent, tab) => !agent.alert && tab?.color === "orange");
  });
  summary.result = summary.cases.every(record => record.result === "passed") ? "passed" : "failed";
  if (summary.result !== "passed") process.exitCode = 1;
}

for (const signal of ["SIGINT", "SIGTERM"]) process.once(signal, () => { summary.interrupted = signal; void stopOwned().finally(async () => { summary.result = "interrupted"; await save(); process.exit(1); }); });
try { await main(); }
catch (error) { summary.result = "failed"; summary.error = error.stack; process.exitCode = 1; }
finally {
  await stopOwned();
  await logScan();
  if (summary.runtimeHookErrors.length) { summary.result = "failed"; process.exitCode = 1; }
  if (summary.processes.some(process => !process.exitProof?.observed)) { summary.result = "failed"; summary.cleanupError = "An owned process did not provide exit proof"; process.exitCode = 1; }
  if (summary.agentProcesses?.some(process => !process.exited)) { summary.result = "failed"; summary.cleanupError = "An owned agent process did not provide exit proof"; process.exitCode = 1; }
  summary.finished = new Date().toISOString();
  await save();
  console.log(`Native verification ${summary.result}; evidence retained: ${base}`);
  console.log(`Summary: ${summaryPath}`);
  if (summary.error) console.error(summary.error);
}
