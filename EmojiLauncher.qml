import QtQuick
import Quickshell
import qs.Services
import "catalog.js" as CatalogData
import "defaultData.js" as DefaultData

QtObject {
    id: root

    property var pluginService: null
    property string trigger: ":e"
    property bool pasteOnSelect: false
    property bool useDMS: true

    signal itemsChanged

    property var emojiDatabase: DefaultData.getEmojiEntries()
    property var unicodeCharacters: DefaultData.getUnicodeEntries()

    property var nerdfontGlyphs: []

    Component.onCompleted: {
        loadSettings();
        loadBundledData();
    }

    onPluginServiceChanged: {
        if (pluginService)
            loadSettings();
    }

    property var pluginDataChangedConnection: Connections {
        target: pluginService
        enabled: pluginService !== null

        function onPluginDataChanged(changedPluginId) {
            if (changedPluginId === "emojiLauncher")
                loadSettings();
        }
    }

    function loadSettings() {
        if (!pluginService)
            return;
        trigger = pluginService.loadPluginData("emojiLauncher", "trigger", ":e");
        pasteOnSelect = pluginService.loadPluginData("emojiLauncher", "pasteOnSelect", false);
        useDMS = pluginService.loadPluginData("emojiLauncher", "useDMS", true);
    }

    function loadBundledData() {
        mergeEntries(emojiDatabase, CatalogData.getEmojiEntries(), "emoji");
        mergeEntries(unicodeCharacters, CatalogData.getUnicodeEntries(), "char");
        mergeEntries(unicodeCharacters, CatalogData.getLatinExtendedEntries(), "char");
        const glyphs = CatalogData.getNerdFontEntries();
        if (glyphs.length > 0) {
            nerdfontGlyphs = glyphs;
        }
        itemsChanged();
    }

    function mergeEntries(target, additions, keyField) {
        if (!Array.isArray(target) || !Array.isArray(additions) || additions.length === 0) {
            return;
        }

        const seen = {};
        for (let i = 0; i < target.length; i++) {
            const key = target[i][keyField];
            if (key) {
                seen[key] = target[i];
            }
        }

        for (let i = 0; i < additions.length; i++) {
            const entry = additions[i];
            if (!entry) {
                continue;
            }

            const key = entry[keyField];
            if (!key) {
                continue;
            }

            const existing = seen[key];
            if (existing) {
                const incomingName = entry.name || "";
                const existingName = existing.name || "";
                if (incomingName.length > existingName.length) {
                    existing.name = incomingName;
                }

                const existingKeywords = Array.isArray(existing.keywords) ? existing.keywords : [];
                const incomingKeywords = Array.isArray(entry.keywords) ? entry.keywords : [];
                const keywordSet = {};

                function normalizeKeyword(keyword) {
                    if (!keyword || typeof keyword !== "string") {
                        return "";
                    }
                    return keyword.toLowerCase();
                }

                for (let j = 0; j < existingKeywords.length; j++) {
                    const normalized = normalizeKeyword(existingKeywords[j]);
                    if (normalized) {
                        existingKeywords[j] = normalized;
                        keywordSet[normalized] = true;
                    }
                }

                for (let j = 0; j < incomingKeywords.length; j++) {
                    const normalized = normalizeKeyword(incomingKeywords[j]);
                    if (normalized && !keywordSet[normalized]) {
                        existingKeywords.push(normalized);
                        keywordSet[normalized] = true;
                    }
                }
                existing.keywords = existingKeywords;
            } else {
                target.push(entry);
                seen[key] = entry;
            }
        }
    }

    function tokenizeQuery(query) {
        if (!query)
            return [];
        const trimmed = query.trim().toLowerCase();
        if (trimmed.length === 0)
            return [];
        return trimmed.split(/\s+/).filter(token => token.length > 0);
    }

    function normalizeKeywords(keywords) {
        if (!Array.isArray(keywords))
            return [];
        const normalized = [];
        for (let i = 0; i < keywords.length; i++) {
            normalized.push(String(keywords[i]).toLowerCase());
        }
        return normalized;
    }

    function extractBaseLetter(nameLower) {
        const match = nameLower.match(/\bletter\s+([a-z0-9])\b/);
        return match ? match[1] : "";
    }

    function tokenCost(token, nameLower, character, keywordsLower) {
        let best = 100000;
        const characterLower = String(character || "").toLowerCase();
        const baseLetter = extractBaseLetter(nameLower);

        if (characterLower === token)
            return 0;

        if (token.length === 1) {
            if (baseLetter === token)
                return 3;
            for (let i = 0; i < keywordsLower.length; i++) {
                if (keywordsLower[i] === token)
                    return 4 + Math.min(i, 10);
            }
            return 100000;
        }

        if (nameLower === token)
            best = 2;
        else if (nameLower.startsWith(token))
            best = Math.min(best, 8);
        else if (nameLower.includes(token))
            best = Math.min(best, 16);

        for (let i = 0; i < keywordsLower.length; i++) {
            const keyword = keywordsLower[i];
            if (keyword === token)
                best = Math.min(best, 1 + Math.min(i, 10));
            else if (keyword.startsWith(token))
                best = Math.min(best, 6 + Math.min(i, 15));
            else if (keyword.includes(token))
                best = Math.min(best, 14 + Math.min(i, 15));
        }

        return best;
    }

    function entryMatchesQuery(name, character, keywords, lowerQuery, queryTokens, query) {
        if (!query)
            return true;

        const nameLower = String(name || "").toLowerCase();
        const keywordsLower = normalizeKeywords(keywords);

        if (nameLower.includes(lowerQuery) || character.includes(query))
            return true;

        for (let i = 0; i < keywordsLower.length; i++) {
            if (keywordsLower[i].includes(lowerQuery))
                return true;
        }

        if (queryTokens.length <= 1)
            return false;

        for (let i = 0; i < queryTokens.length; i++) {
            if (tokenCost(queryTokens[i], nameLower, character, keywordsLower) >= 100000)
                return false;
        }
        return true;
    }

    // Returns a sort score for an item (higher = better match)
    function getMatchScore(name, character, keywords, lowerQuery, queryTokens, query) {
        if (!query)
            return 0;

        const nameLower = String(name || "").toLowerCase();
        const keywordsLower = normalizeKeywords(keywords);

        if (character === query)
            return 5000;

        let bestCost = 1000;
        if (nameLower === lowerQuery)
            bestCost = 1;

        for (let i = 0; i < keywordsLower.length; i++) {
            if (keywordsLower[i] === lowerQuery)
                bestCost = Math.min(bestCost, 2 + i);
        }

        if (nameLower.startsWith(lowerQuery))
            bestCost = Math.min(bestCost, 20);
        else if (nameLower.includes(lowerQuery))
            bestCost = Math.min(bestCost, 30);

        for (let i = 0; i < keywordsLower.length; i++) {
            const keyword = keywordsLower[i];
            if (keyword.startsWith(lowerQuery))
                bestCost = Math.min(bestCost, 24 + i);
            else if (keyword.includes(lowerQuery))
                bestCost = Math.min(bestCost, 34 + i);
        }

        if (queryTokens.length > 1) {
            let tokenAggregate = 0;
            for (let i = 0; i < queryTokens.length; i++) {
                const cost = tokenCost(queryTokens[i], nameLower, character, keywordsLower);
                if (cost >= 100000)
                    return 1;
                tokenAggregate += cost;
            }
            bestCost = Math.min(bestCost, 60 + tokenAggregate);
        }

        return Math.max(1, 5000 - bestCost);
    }

    function getItems(query) {
        const items = [];
        const trimmedQuery = query ? query.trim() : "";
        const lowerQuery = trimmedQuery.toLowerCase();
        const queryTokens = tokenizeQuery(trimmedQuery);
        const NERDFONT_SCORE_PENALTY = 200;

        for (let i = 0; i < emojiDatabase.length; i++) {
            const emoji = emojiDatabase[i];
            if (entryMatchesQuery(emoji.name, emoji.emoji, emoji.keywords, lowerQuery, queryTokens, trimmedQuery)) {
                items.push({
                    name: emoji.name,
                    comment: emoji.keywords.join(", "),
                    action: "copy:" + emoji.emoji,
                    icon: "unicode:" + emoji.emoji,
                    categories: ["Emoji & Unicode Launcher"],
                    _preScored: getMatchScore(emoji.name, emoji.emoji, emoji.keywords, lowerQuery, queryTokens, trimmedQuery)
                });
            }
        }

        for (let i = 0; i < unicodeCharacters.length; i++) {
            const unicode = unicodeCharacters[i];
            if (entryMatchesQuery(unicode.name, unicode.char, unicode.keywords, lowerQuery, queryTokens, trimmedQuery)) {
                items.push({
                    name: unicode.name,
                    comment: unicode.keywords.join(", "),
                    action: "copy:" + unicode.char,
                    icon: "unicode:" + unicode.char,
                    categories: ["Emoji & Unicode Launcher"],
                    _preScored: getMatchScore(unicode.name, unicode.char, unicode.keywords, lowerQuery, queryTokens, trimmedQuery)
                });
            }
        }

        for (let i = 0; i < nerdfontGlyphs.length; i++) {
            const glyph = nerdfontGlyphs[i];
            if (entryMatchesQuery(glyph.name, glyph.char, glyph.keywords, lowerQuery, queryTokens, trimmedQuery)) {
                items.push({
                    name: glyph.name + " (Nerd Font)",
                    comment: glyph.keywords.join(", "),
                    action: "copy:" + glyph.char,
                    icon: "unicode:" + glyph.char,
                    categories: ["Emoji & Unicode Launcher"],
                    _preScored: Math.max(1, getMatchScore(glyph.name, glyph.char, glyph.keywords, lowerQuery, queryTokens, trimmedQuery) - NERDFONT_SCORE_PENALTY)
                });
            }
        }

        if (trimmedQuery.length > 0)
            items.sort((a, b) => b._preScored - a._preScored);

        return items.slice(0, 50);
    }

    function executeItem(item) {
        if (!item?.action)
            return;
        const actionParts = item.action.split(":");
        const actionType = actionParts[0];
        const actionData = actionParts.slice(1).join(":");
        const copyCommand = useDMS
            ? "if command -v dms >/dev/null 2>&1; then printf '%s' \"$1\" | dms cl copy; else printf '%s' \"$1\" | wl-copy; fi"
            : "printf '%s' \"$1\" | wl-copy";

        if (pasteOnSelect)
            Quickshell.execDetached(["wtype", actionData]);

        switch (actionType) {
        case "copy":
            Quickshell.execDetached(["sh", "-c", copyCommand, "copy", actionData]);
            ToastService?.showInfo("Copied " + actionData + " to clipboard");
            break;
        }
    }

    function getPasteText(item) {
        if (!item?.action)
            return null;
        const actionParts = item.action.split(":");
        if (actionParts[0] !== "copy")
            return null;
        return actionParts.slice(1).join(":");
    }

    function getPasteArgs(item) {
        const text = getPasteText(item);
        if (!text)
            return null;

        const copyCommand = useDMS
            ? "if command -v dms >/dev/null 2>&1; then printf '%s' \"$1\" | dms cl copy; else printf '%s' \"$1\" | wl-copy; fi"
            : "printf '%s' \"$1\" | wl-copy";

        return ["sh", "-c", copyCommand, "copy", text];
    }

    onTriggerChanged: {
        if (!pluginService)
            return;
        pluginService.savePluginData("emojiLauncher", "trigger", trigger);
        itemsChanged();
    }

    onPasteOnSelectChanged: {
        if (!pluginService)
            return;
        pluginService.savePluginData("emojiLauncher", "pasteOnSelect", pasteOnSelect);
    }

    onUseDMSChanged: {
        if (!pluginService)
            return;
        pluginService.savePluginData("emojiLauncher", "useDMS", useDMS);
    }
}
