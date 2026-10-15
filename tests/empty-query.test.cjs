const assert = require('node:assert/strict');
const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');
const { spawnSync, execFileSync } = require('node:child_process');
const { test } = require('node:test');

test('empty-query fast path preserves catalog results and bounds work', () => {
    const repo = path.join(__dirname, '..');
    const fixture = fs.mkdtempSync(path.join(os.tmpdir(), 'dms-emoji-query-'));
    try {
        // Copy generated data as opaque assets; exercise its public QML API.
        for (const file of ['EmojiLauncher.qml', 'catalog.js', 'defaultData.js'])
            fs.copyFileSync(path.join(repo, file), path.join(fixture, file));
        fs.writeFileSync(path.join(fixture, 'BaselineEmoji.qml'), execFileSync('git', ['show', '8ff394e:EmojiLauncher.qml'], {cwd: repo}));
        fs.copyFileSync(path.join(__dirname, 'shell.qml'), path.join(fixture, 'shell.qml'));
        fs.mkdirSync(path.join(fixture, 'Services'));
        fs.writeFileSync(path.join(fixture, 'Services/qmldir'), 'module qs.Services\nsingleton ToastService 1.0 ToastService.qml\n');
        fs.writeFileSync(path.join(fixture, 'Services/ToastService.qml'), 'pragma Singleton\nimport QtQuick\nQtObject { function showInfo(message) {} }\n');
        const result = spawnSync('qs', ['-p', path.join(fixture, 'shell.qml')], {
            encoding: 'utf8', timeout: 120000,
            env: {...process.env, QT_QPA_PLATFORM: 'offscreen'},
        });
        assert.ifError(result.error);
        assert.equal(result.status, 0, result.stdout + result.stderr);
        assert.match(result.stdout + result.stderr, /PASS: blank-query ordering/);
        console.log((result.stdout + result.stderr).split('\n').filter(line => line.includes('BENCH:')).join('\n'));
    } finally {
        fs.rmSync(fixture, {recursive: true});
    }
});
