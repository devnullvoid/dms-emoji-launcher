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
    property var emptyQueryCache: null
    property string emptyQueryCacheKey: ""

    onEmojiDatabaseChanged: emptyQueryCache = null
    onUnicodeCharactersChanged: emptyQueryCache = null
    onNerdfontGlyphsChanged: emptyQueryCache = null

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
        emptyQueryCache = null;
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

    function getEmptyQueryItems() {
        const cacheKey = JSON.stringify([recentEmojis, defaultSkinTone]);
        if (emptyQueryCache === null || emptyQueryCacheKey !== cacheKey) {
            const recentMap = {};
            for (let i = 0; i < recentEmojis.length; i++) {
                const character = recentEmojis[i];
                if (character && recentMap[character] === undefined)
                    recentMap[character] = Math.max(0, 3000 - i * 100);
            }
            const skinModifiers = ["\uD83C\uDFFB", "\uD83C\uDFFC", "\uD83C\uDFFD", "\uD83C\uDFFE", "\uD83C\uDFFF"];
            const ranked = [];
            const needsRanking = recentEmojis.length > 0 || defaultSkinTone.length > 0;

            function consider(entry, character, nerdFont, index, emoji) {
                let score = recentMap[character];
                if (score === undefined && emoji && defaultSkinTone.length > 0
                        && character.includes(defaultSkinTone)
                        && entry.name.toLowerCase().includes("skin tone")
                        && !skinModifiers.some(m => m !== defaultSkinTone && character.includes(m)))
                    score = 1200;
                const rank = score === undefined ? 0 : score;
                // Keep at most 50 lightweight references. Constructing comments,
                // actions and icons for the entire catalog blocks the QML thread.
                if (ranked.length === 50 && rank <= ranked[49].rank)
                    return;
                let position = ranked.length;
                while (position > 0 && rank > ranked[position - 1].rank)
                    position--;
                ranked.splice(position, 0, {entry: entry, character: character, nerdFont: nerdFont,
                                           index: index, score: score, rank: rank});
                if (ranked.length > 50)
                    ranked.pop();
            }

            const groups = [emojiDatabase, unicodeCharacters, nerdfontGlyphs];
            let index = 0;
            for (let group = 0; group < groups.length; group++) {
                const entries = groups[group];
                for (let i = 0; i < entries.length; i++, index++) {
                    const entry = entries[i];
                    consider(entry, group === 0 ? entry.emoji : entry.char, group === 2, index, group === 0);
                    if (!needsRanking && ranked.length === 50)
                        break;
                }
                if (!needsRanking && ranked.length === 50)
                    break;
            }

            emptyQueryCache = ranked.map(candidate => ({
                name: candidate.entry.name + (candidate.nerdFont ? " (Nerd Font)" : ""),
                comment: candidate.entry.keywords.join(", "),
                action: "copy:" + candidate.character,
                icon: "unicode:" + candidate.character,
                categories: ["Emoji & Unicode Launcher"],
                _preScored: candidate.score,
                _idx: candidate.index
            }));
            emptyQueryCacheKey = cacheKey;
        }
        // Return fresh result objects so launcher-side edits cannot corrupt
        // subsequent searches. The retained cache is bounded to 50 items.
        return emptyQueryCache.map(item => Object.assign({}, item, {categories: item.categories.slice()}));
    }

    function getItems(query) {
        const items = [];
        const trimmedQuery = query ? query.trim().replace(/^\++/, "") : "";
        if (trimmedQuery.length === 0)
            return getEmptyQueryItems();
        const lowerQuery = trimmedQuery.toLowerCase();
        const queryTokens = tokenizeQuery(trimmedQuery);
        const NERDFONT_SCORE_PENALTY = 200;
        const SKIN_TONE_PENALTY = 200;
        const SKIN_TONE_BOOST = 300;
        const SKIN_MODIFIERS = ["\uD83C\uDFFB", "\uD83C\uDFFC", "\uD83C\uDFFD", "\uD83C\uDFFE", "\uD83C\uDFFF"];

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
                items.push({
                    name: emoji.name,
                    comment: emoji.keywords.join(", "),
                    action: "copy:" + emoji.emoji,
                    icon: "unicode:" + emoji.emoji,
                    categories: ["Emoji & Unicode Launcher"],
                    _preScored: score,
                    _idx: items.length
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
                    _preScored: getMatchScore(unicode.name, unicode.char, unicode.keywords, lowerQuery, queryTokens, trimmedQuery),
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
                items.push({
                    name: glyph.name + " (Nerd Font)",
                    comment: glyph.keywords.join(", "),
                    action: "copy:" + glyph.char,
                    icon: "unicode:" + glyph.char,
                    categories: ["Emoji & Unicode Launcher"],
                    _preScored: nfScore,
                    _idx: items.length
                });
            }
        }

        items.sort((a, b) => b._preScored - a._preScored || a._idx - b._idx);

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
