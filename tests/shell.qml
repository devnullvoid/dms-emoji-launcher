import QtQuick
import Quickshell
import "." as Plugin

ShellRoot {
    id: testRoot

    QtObject {
        id: settings
        property string recents: ""
        property string tone: ""
        signal pluginDataChanged(string pluginId)
        function loadPluginData(pluginId, key, fallback) {
            if (key === "recentEmojis") return recents;
            if (key === "defaultSkinTone") return tone;
            return fallback;
        }
        function savePluginData(pluginId, key, value) {
            if (key === "recentEmojis") recents = value;
            if (key === "defaultSkinTone") tone = value;
            pluginDataChanged(pluginId);
        }
    }
    Plugin.EmojiLauncher { id: current; pluginService: settings }
    Plugin.BaselineEmoji { id: baseline; pluginService: settings }

    Component.onCompleted: Qt.callLater(runChecks)

    function equal(actual, expected, label) {
        if (JSON.stringify(actual) !== JSON.stringify(expected))
            throw new Error(label + " changed result ordering or metadata");
    }

    function runChecks() {
        try {
            let start = Date.now();
            baseline.getItems("");
            const beforeMs = Date.now() - start;
            start = Date.now();
            current.getItems("");
            const firstMs = Date.now() - start;
            start = Date.now();
            for (let i = 0; i < 20; i++) current.getItems(i % 2 ? "" : "  ");
            const repeatMs = Date.now() - start;
            console.log("BENCH: " + JSON.stringify({entries: current.emojiDatabase.length + current.unicodeCharacters.length + current.nerdfontGlyphs.length,
                         beforeMs: beforeMs, firstMs: firstMs, repeated20Ms: repeatMs}));
            const lastEmoji = current.emojiDatabase[current.emojiDatabase.length - 1].emoji;
            const lastUnicode = current.unicodeCharacters[current.unicodeCharacters.length - 1].char;
            const lastNerdFont = current.nerdfontGlyphs[current.nerdfontGlyphs.length - 1].char;
            const scenarios = [
                {recents: "", tone: ""},
                {recents: [lastNerdFont, lastUnicode, lastEmoji].join(","), tone: ""},
                {recents: "", tone: "\uD83C\uDFFD"},
                {recents: [lastNerdFont, "👍", lastUnicode, lastEmoji].join(","), tone: "\uD83C\uDFFD"},
                {recents: "", tone: ""}
            ];
            for (const scenario of scenarios) {
                settings.recents = scenario.recents;
                settings.tone = scenario.tone;
                settings.pluginDataChanged("emojiLauncher");
                const expected = baseline.getItems("");
                equal(current.getItems(""), expected, "Blank query");
                equal(current.getItems("  \t "), expected, "Whitespace query");
            }
            for (const query of ["melting", "french e", "latin tilde n", "👍", "nerd"])
                equal(current.getItems(query), baseline.getItems(query), "Search " + query);
            const result = current.getItems("");
            result[0].name = "mutated by caller";
            result[0].categories.push("mutated");
            equal(current.getItems(""), baseline.getItems(""), "Cache isolation");
            current.trackRecentEmoji(lastNerdFont);
            if (current.getItems("")[0].action !== "copy:" + lastNerdFont)
                throw new Error("Recent selection did not invalidate the cache");

            // Count expensive keyword-to-comment conversions using a small
            // synthetic catalog. Empty search should construct only 50 rows.
            let joins = 0;
            const entries = [];
            for (let i = 0; i < 2000; i++)
                entries.push({emoji: "item-" + i, name: "Item " + i,
                              keywords: {join: function () { joins++; return "keyword"; }}});
            settings.recents = "";
            settings.pluginDataChanged("emojiLauncher");
            current.emojiDatabase = entries;
            current.unicodeCharacters = [];
            current.nerdfontGlyphs = [];
            if (current.getItems("").length !== 50 || joins !== 50)
                throw new Error("Blank query constructed more than 50 catalog rows: " + joins);
            current.getItems(" ");
            if (joins !== 50)
                throw new Error("Repeated whitespace input rebuilt catalog rows");
            console.log("PASS: blank-query ordering, recents, skin tones, search, cache invalidation and bounded work");
            Qt.exit(0);
        } catch (error) {
            console.error("FAIL: " + error.message);
            Qt.exit(1);
        }
    }
}
