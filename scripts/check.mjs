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
await stat(path.join(root, field('window')));

const statusSource = await text('status.luau');
const windowSource = await text('window.luau');
const behaviorSource = await text('tests/behavior.luau');
const vm = await LuauState.createAsync();
try {
    vm.loadstring(statusSource, 'status.luau', true);
    vm.loadstring(windowSource, 'window.luau', true);
    const run = vm.loadstring(`
local status = (function()
${statusSource}
end)()
local function load_plugin(api)
    local tern = api
    local function require(name)
        assert(name == "./status", "Unexpected module " .. name)
        return status
    end
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
    for (const match of source.matchAll(/\[[^\]]*\]\(([^\s)]+)\)/g)) {
        const href = match[1];
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
