import QtQuick
import Quickshell
import Quickshell.Io
import "." as Plugin

ShellRoot {
    id: testRoot

    QtObject {
        id: settings
        property string recents: ""
        property var stateRecents: null
        property int recentWrites: 0
        property int stateWrites: 0
        property int settingsWriteAttempts: 0
        property bool readOnly: false
        property string tone: ""
        signal pluginDataChanged(string pluginId)
        function loadPluginState(pluginId, key, fallback) {
            if (key === "recentEmojis" && stateRecents !== null) return stateRecents;
            return fallback;
        }
        function savePluginState(pluginId, key, value) {
            if (key === "recentEmojis") { stateRecents = value; stateWrites++; }
        }
        function loadPluginData(pluginId, key, fallback) {
            if (key === "recentEmojis") return recents;
            if (key === "defaultSkinTone") return tone;
            return fallback;
        }
        function savePluginData(pluginId, key, value) {
            settingsWriteAttempts++;
            if (readOnly) throw new Error("Attempted to write read-only plugin settings");
            if (key === "recentEmojis") { recents = value; recentWrites++; }
            if (key === "defaultSkinTone") tone = value;
            pluginDataChanged(pluginId);
        }
    }
    Plugin.EmojiLauncher { id: current; pluginService: settings }
    Plugin.BaselineEmoji { id: baseline; pluginService: settings }

    property FileView completionFile: FileView {
        path: Quickshell.env("DMS_EMOJI_TEST_RESULT")
        blockWrites: true
    }

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
                settings.stateRecents = scenario.recents;
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
            const recentWrites = settings.recentWrites;
            current.trackRecentEmoji(lastNerdFont);
            if (current.getItems("")[0].action !== "copy:" + lastNerdFont)
                throw new Error("Recent selection did not invalidate the cache");
            if (settings.stateRecents.split(",")[0] !== lastNerdFont || settings.recentWrites !== recentWrites)
                throw new Error("Recent selection was not saved to plugin state");

            settings.readOnly = true;
            const writeAttemptsBeforeMigration = settings.settingsWriteAttempts;
            settings.stateRecents = null;
            settings.recents = "👍";
            const writesBeforeMigration = settings.stateWrites;
            settings.pluginDataChanged("emojiLauncher");
            if (settings.stateRecents !== "👍" || settings.recents !== "👍" || current.recentEmojis[0] !== "👍"
                    || settings.stateWrites !== writesBeforeMigration + 1 || settings.recentWrites !== recentWrites
                    || settings.settingsWriteAttempts !== writeAttemptsBeforeMigration)
                throw new Error("Migration did not preserve read-only settings and copy recents once");
            settings.pluginDataChanged("emojiLauncher");
            if (settings.stateWrites !== writesBeforeMigration + 1)
                throw new Error("Existing state was migrated again");
            // A deliberately cleared state must win over nonempty legacy settings.
            settings.stateRecents = "";
            settings.pluginDataChanged("emojiLauncher");
            if (current.recentEmojis.length !== 0 || settings.stateRecents !== ""
                    || settings.stateWrites !== writesBeforeMigration + 1)
                throw new Error("Empty state restored stale legacy recents");
            current.trackRecentEmoji(lastEmoji);
            if (settings.stateRecents !== lastEmoji || settings.recents !== "👍")
                throw new Error("Selection did not persist with read-only settings");
            // Even an empty legacy configuration is marked migrated once.
            settings.stateRecents = null;
            settings.recents = "";
            const writesBeforeEmptyMigration = settings.stateWrites;
            settings.pluginDataChanged("emojiLauncher");
            settings.pluginDataChanged("emojiLauncher");
            if (settings.stateRecents !== "" || settings.stateWrites !== writesBeforeEmptyMigration + 1)
                throw new Error("Missing state with empty settings was not initialized once");
            if (settings.settingsWriteAttempts !== writeAttemptsBeforeMigration)
                throw new Error("Read-only settings received a write attempt");

            // Count expensive keyword-to-comment conversions using a small
            // synthetic catalog. Empty search should construct only 50 rows.
            let joins = 0;
            const entries = [];
            for (let i = 0; i < 2000; i++)
                entries.push({emoji: "item-" + i, name: "Item " + i,
                              keywords: {join: function () { joins++; return "keyword"; }}});
            settings.recents = "";
            settings.stateRecents = "";
            settings.pluginDataChanged("emojiLauncher");
            current.emojiDatabase = entries;
            current.unicodeCharacters = [];
            current.nerdfontGlyphs = [];
            if (current.getItems("").length !== 50 || joins !== 50)
                throw new Error("Blank query constructed more than 50 catalog rows: " + joins);
            current.getItems(" ");
            if (joins !== 50)
                throw new Error("Repeated whitespace input rebuilt catalog rows");
            console.log("PASS: blank-query ordering, recents, skin tones, search, cache invalidation, recents migration and bounded work");
            completionFile.setText("passed");
            Qt.exit(0);
        } catch (error) {
            console.error("FAIL: " + error.message);
            Qt.exit(1);
        }
    }
}
