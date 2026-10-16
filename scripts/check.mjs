import assert from 'node:assert/strict';
import { readFile, readdir, stat } from 'node:fs/promises';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import { LuauState } from 'luau-web';

const root = fileURLToPath(new URL('../', import.meta.url));
const text = (name) => readFile(path.join(root, name), 'utf8');
const manifest = await text('plugin.toml');
const pkg = JSON.parse(await text('package.json'));
const lock = JSON.parse(await text('package-lock.json'));
const field = (key) => {
    const match = manifest.match(new RegExp(`^${key} = "([^"]+)"$`, 'm'));
    assert.ok(match, `Missing plugin manifest field: ${key}`);
    return match[1];
};
assert.match(manifest, /^schema = 1$/m);
assert.equal(field('id'), pkg.name);
assert.equal(field('version'), pkg.version);
assert.equal(lock.packages[''].version, pkg.version);
assert.equal(lock.packages[''].license, pkg.license);
assert.equal(pkg.private, true, 'npm is development tooling, not plugin distribution');
assert.equal(field('host'), 'host.luau');
assert.equal(field('window'), 'window.luau');
await stat(path.join(root, field('host')));
await stat(path.join(root, field('window')));

const hostSource = await text(field('host'));
const windowSource = await text(field('window'));
const behaviorSource = await text('tests/behavior.luau');
const vm = await LuauState.createAsync();
try {
    vm.loadstring(hostSource, field('host'), true);
    vm.loadstring(windowSource, field('window'), true);
    const run = vm.loadstring(`
local function load_host_plugin(api)
    local tern = api
${hostSource}
end
local function load_window_plugin(api)
    local tern = api
${windowSource}
end
${behaviorSource}
`, 'behavior.luau', true);
    const [cases] = await run();
    assert.equal(typeof cases, 'number');
    console.log(`Luau: runtime modules compile; ${cases} behavioral scenarios pass.`);
} finally {
    vm.destroy();
}

const docs = (await readdir(root)).filter((name) => name.endsWith('.md'));
for (const name of await readdir(path.join(root, 'docs'))) {
    if (name.endsWith('.md')) docs.push(`docs/${name}`);
}
const slug = (heading) => heading.toLowerCase()
    .replace(/[`*_]/g, '')
    .replace(/[^\p{L}\p{N}\p{M}\s_-]/gu, '')
    .replace(/ /g, '-');
let links = 0;
for (const name of docs) {
    const source = (await text(name)).replace(/^```[^\n]*\n[\s\S]*?^```/gm, '');
    const hrefs = [
        ...source.matchAll(/\[[^\]]*\]\(([^\s)]+)\)/g),
        ...source.matchAll(/\bhref=["']([^"']+)["']/g),
    ].map((match) => match[1]);
    for (const href of hrefs) {
        if (/^[a-z]+:/i.test(href)) continue;
        const [file, anchor] = href.split('#');
        const target = path.resolve(root, path.dirname(name), decodeURIComponent(file || path.basename(name)));
        assert.ok(target.startsWith(root), `${name}: link escapes repository: ${href}`);
        const info = await stat(target);
        assert.ok(info.isFile(), `${name}: link is not a file: ${href}`);
        if (anchor) {
            const headings = [...(await readFile(target, 'utf8')).matchAll(/^#{1,6}\s+(.+)$/gm)]
                .map((item) => slug(item[1]));
            assert.ok(headings.includes(decodeURIComponent(anchor)), `${name}: missing anchor: ${href}`);
        }
        links += 1;
    }
}
console.log(`Contract: manifest versions match; ${links} local documentation links resolve.`);
