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
    property string defaultSkinTone: ""

    signal itemsChanged

    property var emojiDatabase: DefaultData.getEmojiEntries()
    property var unicodeCharacters: DefaultData.getUnicodeEntries()

    property var nerdfontGlyphs: []
    property var recentEmojis: []

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
        var storedRecent = pluginService.loadPluginData("emojiLauncher", "recentEmojis", "");
        recentEmojis = storedRecent.length > 0 ? storedRecent.split(",") : [];
        defaultSkinTone = pluginService.loadPluginData("emojiLauncher", "defaultSkinTone", "");
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
        const trimmedQuery = query ? query.trim().replace(/^\++/, "") : "";
        const lowerQuery = trimmedQuery.toLowerCase();
        const queryTokens = tokenizeQuery(trimmedQuery);
        const NERDFONT_SCORE_PENALTY = 200;
        const SKIN_TONE_PENALTY = 200;
        const SKIN_TONE_BOOST = 300;
        const SKIN_MODIFIERS = ["\uD83C\uDFFB", "\uD83C\uDFFC", "\uD83C\uDFFD", "\uD83C\uDFFE", "\uD83C\uDFFF"];

        // Build a recent-character lookup map (no-query only).
        // Scores > 900 are picked up by DMS's Scorer even for no-query,
        // while undefined _preScored lets DMS use its own default (900).
        const recentMap = {};
        if (trimmedQuery.length === 0 && pluginService) {
            const storedR = pluginService.loadPluginData("emojiLauncher", "recentEmojis", "");
            if (storedR && storedR.length > 0) {
                const storedArr = storedR.split(",");
                for (let r = 0; r < storedArr.length; r++) {
                    if (storedArr[r] && recentMap[storedArr[r]] === undefined)
                        recentMap[storedArr[r]] = Math.max(0, 3000 - r * 100);
                }
            }
        }

        for (let i = 0; i < emojiDatabase.length; i++) {
            const emoji = emojiDatabase[i];
            if (entryMatchesQuery(emoji.name, emoji.emoji, emoji.keywords, lowerQuery, queryTokens, trimmedQuery)) {
                let score = getMatchScore(emoji.name, emoji.emoji, emoji.keywords, lowerQuery, queryTokens, trimmedQuery);
                const isSkinToneVariant = emoji.name.toLowerCase().includes("skin tone");
                if (score > 0 && isSkinToneVariant) {
                    const isPreferred = defaultSkinTone.length > 0
                        && emoji.emoji.includes(defaultSkinTone)
                        && !SKIN_MODIFIERS.some(m => m !== defaultSkinTone && emoji.emoji.includes(m));
                    score = isPreferred ? score + SKIN_TONE_BOOST : Math.max(1, score - SKIN_TONE_PENALTY);
                }
                const recentBoost = recentMap[emoji.emoji];
                // For no-query: preferred single-modifier skin tone variants get _preScored=1200
                // (>900 threshold) so DMS floats them above the yellow base (900). Recently-used
                // items take priority. Non-preferred items leave _preScored undefined (DMS: 900).
                const skinToneBoost = (trimmedQuery.length === 0 && isSkinToneVariant
                    && defaultSkinTone.length > 0 && emoji.emoji.includes(defaultSkinTone)
                    && !SKIN_MODIFIERS.some(m => m !== defaultSkinTone && emoji.emoji.includes(m)))
                    ? 1200 : undefined;
                items.push({
                    name: emoji.name,
                    comment: emoji.keywords.join(", "),
                    action: "copy:" + emoji.emoji,
                    icon: "unicode:" + emoji.emoji,
                    categories: ["Emoji & Unicode Launcher"],
                    _preScored: trimmedQuery.length > 0 ? score : (recentBoost !== undefined ? recentBoost : skinToneBoost),
                    _idx: items.length
                });
            }
        }

        for (let i = 0; i < unicodeCharacters.length; i++) {
            const unicode = unicodeCharacters[i];
            if (entryMatchesQuery(unicode.name, unicode.char, unicode.keywords, lowerQuery, queryTokens, trimmedQuery)) {
                const recentBoost = recentMap[unicode.char];
                items.push({
                    name: unicode.name,
                    comment: unicode.keywords.join(", "),
                    action: "copy:" + unicode.char,
                    icon: "unicode:" + unicode.char,
                    categories: ["Emoji & Unicode Launcher"],
                    _preScored: trimmedQuery.length > 0 ? getMatchScore(unicode.name, unicode.char, unicode.keywords, lowerQuery, queryTokens, trimmedQuery) : recentBoost,
                    _idx: items.length
                });
            }
        }

        for (let i = 0; i < nerdfontGlyphs.length; i++) {
            const glyph = nerdfontGlyphs[i];
            if (entryMatchesQuery(glyph.name, glyph.char, glyph.keywords, lowerQuery, queryTokens, trimmedQuery)) {
                let nfScore = getMatchScore(glyph.name, glyph.char, glyph.keywords, lowerQuery, queryTokens, trimmedQuery);
                if (nfScore > 0)
                    nfScore = Math.max(1, nfScore - NERDFONT_SCORE_PENALTY);
                const recentBoost = recentMap[glyph.char];
                items.push({
                    name: glyph.name + " (Nerd Font)",
                    comment: glyph.keywords.join(", "),
                    action: "copy:" + glyph.char,
                    icon: "unicode:" + glyph.char,
                    categories: ["Emoji & Unicode Launcher"],
                    _preScored: trimmedQuery.length > 0 ? nfScore : recentBoost,
                    _idx: items.length
                });
            }
        }

        // Sort when there's a query or when recent items exist.
        // Recently-used items have _preScored set (3000-2600); others have undefined.
        // The sort ensures recently-used items land in the slice(0,50) regardless
        // of their position in the database. DMS then re-ranks using _preScored.
        const hasRecent = Object.keys(recentMap).length > 0;
        const hasSkinTonePref = defaultSkinTone.length > 0;
        if (trimmedQuery.length > 0 || hasRecent || hasSkinTonePref) {
            items.sort((a, b) => {
                const as = a._preScored !== undefined ? a._preScored : 0;
                const bs = b._preScored !== undefined ? b._preScored : 0;
                return bs - as || a._idx - b._idx;
            });
        }

        return items.slice(0, 50);
    }

    function trackRecentEmoji(character) {
        var arr = recentEmojis.slice();
        var idx = arr.indexOf(character);
        if (idx !== -1)
            arr.splice(idx, 1);
        arr.unshift(character);
        if (arr.length > 20)
            arr.length = 20;
        recentEmojis = arr;
        if (pluginService)
            pluginService.savePluginData("emojiLauncher", "recentEmojis", arr.join(","));
    }

    function executeItem(item) {
        if (!item?.action)
            return;
        const actionParts = item.action.split(":");
        const actionType = actionParts[0];
        const actionData = actionParts.slice(1).join(":");
        // setsid decouples dms cl copy from the parent process group so it is
        // not killed when the launcher window closes (unlike wl-copy, dms cl copy
        // does not self-daemonize and relies on staying alive to own the clipboard).
        const copyCommand = useDMS
            ? "if command -v dms >/dev/null 2>&1; then printf '%s' \"$1\" | setsid dms cl copy; else printf '%s' \"$1\" | wl-copy; fi"
            : "printf '%s' \"$1\" | wl-copy";

        switch (actionType) {
        case "copy":
            Quickshell.execDetached(["sh", "-c", copyCommand, "copy", actionData]);
            // Delay wtype so the launcher has time to close and the previously
            // focused window can regain focus before characters are typed.
            if (pasteOnSelect)
                Quickshell.execDetached(["sh", "-c", "sleep 0.15 && wtype \"$1\"", "paste", actionData]);
            ToastService?.showInfo("Copied " + actionData + " to clipboard");
            trackRecentEmoji(actionData);
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
            ? "if command -v dms >/dev/null 2>&1; then printf '%s' \"$1\" | setsid dms cl copy; else printf '%s' \"$1\" | wl-copy; fi"
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
