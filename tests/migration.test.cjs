const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const vm = require('node:vm');
const { execFileSync } = require('node:child_process');
const { test } = require('node:test');

const repo = path.join(__dirname, '..');
const source = process.env.MIGRATION_BASELINE_REF
    ? execFileSync('git', ['show', process.env.MIGRATION_BASELINE_REF + ':EmojiLauncher.qml'], {cwd: repo, encoding: 'utf8'})
    : fs.readFileSync(path.join(repo, 'EmojiLauncher.qml'), 'utf8');
// Exercise the actual QML method with an explicit read-only settings contract.
const method = source.match(/function loadRecentEmojis\(\) \{[\s\S]*?\n    \}(?=\s*function loadBundledData)/)[0];

function fixture(initialState, legacy) {
    let state = initialState;
    let stateWrites = 0;
    const pluginService = {
        loadPluginState(id, key, fallback) { return state === undefined ? fallback : state; },
        loadPluginData() { return legacy; },
        savePluginState(id, key, value) { state = value; stateWrites++; },
        savePluginData() { throw new Error('read-only settings'); },
    };
    const load = vm.runInNewContext('(' + method + ')', {pluginService});
    return {load, get state() { return state; }, get writes() { return stateWrites; }};
}

test('legacy recents migrate once without writing read-only settings', () => {
    const context = fixture(undefined, '👍,😀');
    assert.equal(context.load(), '👍,😀');
    assert.equal(context.state, '👍,😀');
    assert.equal(context.load(), '👍,😀');
    assert.equal(context.writes, 1);
});

test('intentionally empty state overrides legacy recents', () => {
    const context = fixture('', '👍');
    assert.equal(context.load(), '');
    assert.equal(context.state, '');
    assert.equal(context.writes, 0);
});

test('existing state overrides legacy settings without another migration', () => {
    const context = fixture('😀', '👍');
    assert.equal(context.load(), '😀');
    assert.equal(context.writes, 0);
});

test('empty legacy recents initialize state only once', () => {
    const context = fixture(undefined, '');
    assert.equal(context.load(), '');
    assert.equal(context.state, '');
    assert.equal(context.load(), '');
    assert.equal(context.writes, 1);
});
