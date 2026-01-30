# AGENTS.md - DMS Emoji & Unicode Launcher

## Project Overview
A DankMaterialShell (DMS) launcher plugin providing quick access to emojis, unicode characters, Latin extended characters, math symbols, and Nerd Font glyphs with instant clipboard copying.

**Language**: QML (Qt Modeling Language) with Python build scripts
**Type**: Launcher plugin for DankMaterialShell
**Default Trigger**: `:e`
**Version**: 1.3.1

## Critical Information for AI Agents

### ⚠️ DO NOT READ catalog.js
**IMPORTANT**: `catalog.js` is auto-generated and extremely large (1.7MB, 200k+ characters). Reading it will cause crashes. Use `grep` or other tools to search it if needed.

### Architecture Overview

```
┌─────────────────────────────────────────────────────┐
│  Data Files (Plain Text)                            │
│  ├── data/emojis.txt          (emoji database)      │
│  ├── data/latin-extended.txt  (accented chars)      │
│  ├── data/math.txt            (unicode symbols)     │
│  └── data/nerdfont.txt        (nerd font glyphs)    │
└─────────────────────────────────────────────────────┘
                      ↓
┌─────────────────────────────────────────────────────┐
│  Build Script                                        │
│  scripts/generate_catalog.py                        │
│  - Parses plain text files                          │
│  - Generates keywords                               │
│  - Adds language context for latin-extended         │
│  - Outputs JavaScript catalog                       │
└─────────────────────────────────────────────────────┘
                      ↓
┌─────────────────────────────────────────────────────┐
│  Generated Catalog                                   │
│  catalog.js                                          │
│  - JavaScript library (.pragma library)             │
│  - Exports getEmojiEntries()                        │
│  - Exports getUnicodeEntries()                      │
│  - Exports getNerdFontEntries()                     │
│  - Exports getLatinExtendedEntries()                │
└─────────────────────────────────────────────────────┘
                      ↓
┌─────────────────────────────────────────────────────┐
│  QML Components                                      │
│  ├── EmojiLauncher.qml         (main component)     │
│  ├── EmojiLauncherSettings.qml (settings UI)        │
│  └── plugin.json               (metadata)           │
│                                                      │
│  Imports catalog.js as CatalogData                  │
│  Calls getXXXEntries() in loadBundledData()         │
└─────────────────────────────────────────────────────┘
```

## File Structure

### Core Files
- **plugin.json** - Plugin metadata, version, trigger, capabilities
- **EmojiLauncher.qml** - Main launcher component (~130KB, 5200+ lines)
- **EmojiLauncherSettings.qml** - Settings UI component
- **catalog.js** - Generated character database (DO NOT READ DIRECTLY)

### Data Files (Plain Text)
Format: `[character] [DESCRIPTION]`

- **data/emojis.txt** - 900+ emoji entries with descriptions
- **data/latin-extended.txt** - 219 accented Latin characters
  - Organized by language sections (Spanish, French, German, etc.)
  - Comments like `# Spanish` are parsed for language keywords
- **data/math.txt** - Mathematical and general unicode symbols
- **data/nerdfont.txt** - Nerd Font glyphs (VS Code Codicons, Powerline)

### Build Scripts
- **scripts/generate_catalog.py** - Main build script
  - Parses all data/*.txt files
  - Generates keywords from character names
  - Adds language context for latin-extended.txt
  - Outputs catalog.js

## Key Concepts

### Character Entry Structure
Each character is stored as a JSON object:
```javascript
{
  "char": "ñ",              // or "emoji" for emojis
  "name": "Latin Small Letter N With Tilde",
  "keywords": ["latin", "small", "letter", "n", "with", "tilde", "accented", "spanish", "español"]
}
```

### Keyword Generation
Keywords are automatically generated from:
1. Character description (split into tokens)
2. Extra keywords (passed to parser)
3. Language context (for latin-extended.txt)

The tokenizer preserves Unicode characters (français, español, etc.)

### Language Keywords (Latin Extended)
The `parse_latin_extended()` function tracks language sections via comments:
- Reads `# Spanish`, `# French`, etc. from latin-extended.txt
- Adds language keywords to all characters in that section
- Supports both English and native language names

## Development Workflow

### 1. Adding New Characters

**To add to existing category:**
```bash
# Edit the appropriate data file
vim data/latin-extended.txt  # or emojis.txt, math.txt, nerdfont.txt

# Format: [character] [DESCRIPTION]
ø LATIN SMALL LETTER O WITH STROKE

# Regenerate catalog
python3 scripts/generate_catalog.py

# Restart DMS to test
```

**To add a new category:**
1. Create new data file: `data/new-category.txt`
2. Add parser function in `generate_catalog.py`:
   ```python
   def parse_new_category(path: Path) -> list[dict]:
       return _parse_symbol_file(
           path,
           key_name="char",  # or "emoji" or custom
           extra_keywords=lambda raw: ["category", "keywords"],
       )
   ```
3. Update `main()` to call parser
4. Update `write_catalog()` to include new array
5. Update `EmojiLauncher.qml` to load new entries in `loadBundledData()`

### 2. Modifying the Generator

**Location**: `scripts/generate_catalog.py`

**Key functions:**
- `parse_emoji()` - Parses emojis.txt
- `parse_unicode()` - Parses math.txt
- `parse_latin_extended()` - Parses latin-extended.txt with language context
- `parse_nerdfont()` - Parses nerdfont.txt
- `_parse_symbol_file()` - Generic parser for symbol files
- `build_keywords()` - Generates keyword list from description + extras
- `prettify_name()` - Capitalizes names for display
- `write_catalog()` - Outputs catalog.js

**Important details:**
- The tokenizer uses `\w+` with `re.UNICODE` to preserve accented characters
- Lines starting with `#` are treated as comments
- Lines with `..` (ranges like `A..Z`) are skipped
- Each entry must have a symbol and description

### 3. Testing Changes

**Development setup (with symlinks):**
```bash
# Symlinks already created from dev repo to installed location:
# ~/.config/DankMaterialShell/plugins/emojiLauncher/

# After making changes:
1. Edit files in dev repo
2. Regenerate catalog if data files changed:
   python3 scripts/generate_catalog.py
3. Restart DMS
4. Test in launcher with :e [search term]
```

**Without symlinks:**
```bash
# Reinstall plugin
dms plugins install emojiLauncher --force

# Or manual copy
cp catalog.js ~/.config/DankMaterialShell/plugins/emojiLauncher/
```

### 4. Version Bumping

**Location**: `plugin.json` line 5

**Versioning scheme**: Semantic versioning (major.minor.patch)
- Patch (1.3.x): Bug fixes, keyword improvements
- Minor (1.x.0): New features, new character categories
- Major (x.0.0): Breaking changes, architecture changes

## Common Tasks

### Add a new language to Latin Extended
1. Edit `data/latin-extended.txt`
2. Add comment header: `# LanguageName`
3. Add characters below the header
4. Update language_map in `parse_latin_extended()` if needed:
   ```python
   "languagename": ["languagename", "native_name"],
   ```
5. Regenerate catalog: `python3 scripts/generate_catalog.py`

### Search for a character in catalog
```bash
# Use grep instead of reading the file
grep -F '"char": "ñ"' catalog.js | head -c 200

# Search by keyword
python3 -c "import json, re; s=open('catalog.js').read(); \
  m=re.search(r'var latinExtendedEntries = (\[.*?\]);', s, re.DOTALL); \
  entries=json.loads(m.group(1)); \
  print([e for e in entries if 'spanish' in e['keywords']][:3])"
```

### Verify catalog entries
```bash
# Count entries by type
grep -c "var emojiEntries" catalog.js
grep -c "var unicodeEntries" catalog.js
grep -c "var latinExtendedEntries" catalog.js
grep -c "var nerdFontEntries" catalog.js

# Check for specific character
grep '"char": "ñ"' catalog.js
```

## Git Workflow

### Commit Message Format
Use conventional commits:
- `feat:` - New features (bump minor version)
- `fix:` - Bug fixes (bump patch version)
- `docs:` - Documentation only
- `style:` - Formatting, no code change
- `refactor:` - Code restructuring

### Auto-closing Issues
Include `Fixes #N` or `Closes #N` in commit message to auto-close GitHub issues.

### Example Commit
```bash
git add data/latin-extended.txt scripts/generate_catalog.py catalog.js plugin.json
git commit -m "feat: add Nordic language characters

Adds Danish, Norwegian, and Swedish characters (å, ø, æ, etc.)
with language-specific keywords.

Fixes #10"
```

## Important QML Details

### Loading Character Entries
**Location**: `EmojiLauncher.qml` line ~5194-5201

```qml
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
```

**Note**: Latin extended and unicode entries are merged into the same `unicodeCharacters` array since they use the same key field ("char").

### Catalog Import
**Location**: `EmojiLauncher.qml` line 4

```qml
import "catalog.js" as CatalogData
```

QML caches imported JavaScript files, so DMS must be restarted after catalog.js changes.

## Troubleshooting

### Characters not showing in launcher
1. Verify catalog.js has the entries:
   ```bash
   grep '"char": "ñ"' catalog.js
   ```
2. Check EmojiLauncher.qml calls the getter:
   ```bash
   grep "getLatinExtendedEntries" EmojiLauncher.qml
   ```
3. **Restart DMS** - QML caches the catalog

### Catalog generation fails
1. Check data file syntax: `[char] [DESCRIPTION]`
2. Verify no syntax errors in Python script
3. Check for empty descriptions or malformed lines

### Keywords not working as expected
1. Verify keyword generation in catalog.js
2. Check tokenizer preserves Unicode (uses `\w` with `re.UNICODE`)
3. Ensure language sections have proper comment headers

## Plugin Installation Paths

**Development**: `/home/jon/Dev/github/dms-plugins/dms-emoji-launcher/`
**Installed**: `~/.config/DankMaterialShell/plugins/emojiLauncher/`
**Symlinks**: Files in installed location are symlinked to dev repo

## Dependencies

**Runtime**:
- DankMaterialShell >= 0.1.0
- wl-copy (wl-clipboard package)
- Wayland compositor (Niri, Hyprland, etc.)

**Build**:
- Python 3.x
- No external Python packages required (uses stdlib only)

## Testing Checklist

When making changes:
- [ ] Run `python3 scripts/generate_catalog.py` if data files changed
- [ ] Check catalog.js was updated (verify file timestamp)
- [ ] Restart DMS
- [ ] Test search with `:e [keyword]`
- [ ] Verify clipboard copy works
- [ ] Check search results include expected characters
- [ ] Test with multiple keywords (language names, diacritic names, etc.)
- [ ] Update version in plugin.json if needed
- [ ] Update README.md if adding new features
- [ ] Commit with conventional commit message

## Future Enhancements Ideas

- User-defined character libraries (custom data files)
- Favorites/recently used characters
- Character categories in UI
- Skin tone modifiers for emojis
- Custom keyword aliases
- Export/import custom character sets

## Resources

- [DankMaterialShell](https://github.com/AvengeMedia/DankMaterialShell)
- [Plugin Registry](https://github.com/AvengeMedia/dms-plugin-registry)
- [Unicode Character Database](https://www.unicode.org/charts/)
- [Nerd Fonts](https://www.nerdfonts.com/)

---

**Last Updated**: 2026-01-30
**Maintainer**: devnullvoid
**AI-Friendly**: This document is designed to help AI agents quickly understand and work with this project.
