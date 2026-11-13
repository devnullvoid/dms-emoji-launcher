const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const vm = require('node:vm');
const { execFileSync } = require('node:child_process');
const { test } = require('node:test');

const repo = path.join(__dirname, '..');
const before = execFileSync('git', ['show', 'fc38590:EmojiLauncher.qml'], {cwd: repo, encoding: 'utf8'});
const after = fs.readFileSync(path.join(repo, 'EmojiLauncher.qml'), 'utf8');

function component(source, tone = '') {
    const context = vm.createContext({
        emojiDatabase: [
            {emoji: '👍', name: 'Thumbs Up', keywords: ['thumb', 'UP', 'hand']},
            {emoji: '👍🏽', name: 'Thumbs Up Medium Skin Tone', keywords: ['Thumb', 'up', 'hand', 'skin', 'tone']},
            ...Array.from({length: 200}, (_, i) => ({emoji: 'symbol-' + i, name: 'Match Name ' + i, keywords: ['MATCH', 'shared', 'name', 'group-' + i % 7]})),
        ],
        unicodeCharacters: [
            {char: 'é', name: 'Latin Small Letter E With Acute', keywords: ['French', 'letter', 'acute']},
            {char: 'ñ', name: 'Latin Small Letter N With Tilde', keywords: ['Spanish', 'tilde']},
            {char: 'É', name: 'Latin Capital Letter E With Acute', keywords: ['French', 'capital']},
        ],
        nerdfontGlyphs: [{char: '\uf120', name: 'Terminal', keywords: ['TERM', 'shell', 'match']}],
        searchIndex: null, emptyQueryCache: null, emptyQueryCacheKey: '',
        recentEmojis: [], defaultSkinTone: tone,
    });
    // Execute the actual QML methods; generated catalog assets are not read.
    const methods = source.match(/^    function \w+\([^\n]*\) \{[\s\S]*?^    \}/gm);
    vm.runInContext(methods.join('\n'), context);
    return context;
}

test('cached search preserves matching, ranking, metadata and the top-50 cutoff', () => {
    for (const tone of ['', '🏽']) {
        const previous = component(before, tone);
        const current = component(after, tone);
        const queries = ['match', 'MATCH', ' match ', '+match', 'group-3', 'match shared', 'shared name',
            'match  name', 'match\tname', 'thumb up', 'hand', 'skin tone', '👍', '👍🏽',
            'french e', 'french É', 'latin tilde n', 'spanish n', 'é', 'É', 'terminal', 'shell', 'absent'];
        for (const query of queries)
            assert.equal(JSON.stringify(current.getItems(query)), JSON.stringify(previous.getItems(query)), query + ' / tone ' + tone);
    }
});

test('search index is lazy, reused, and rebuilt after invalidation', () => {
    const current = component(after);
    current.getItems('');
    assert.equal(current.searchIndex, null, 'blank queries should not build the index');
    current.getItems('match');
    const index = current.searchIndex;
    current.getItems('shell');
    assert.equal(current.searchIndex, index);
    current.emojiDatabase = [{emoji: '🔬', name: 'Replacement', keywords: ['NEW', 'search']}];
    current.unicodeCharacters = [];
    current.nerdfontGlyphs = [];
    current.invalidateCaches();
    assert.equal(current.searchIndex, null);
    assert.equal(current.getItems('new')[0].action, 'copy:🔬');
    assert.notEqual(current.searchIndex, index);
});

test('nonempty search constructs display rows only for the returned results', () => {
    const current = component(after);
    let comments = 0;
    current.emojiDatabase.forEach(entry => {
        const join = entry.keywords.join;
        entry.keywords.join = function (...args) { comments++; return join.apply(this, args); };
    });
    assert.equal(current.getItems('match').length, 50);
    assert.equal(comments, 50);
});
