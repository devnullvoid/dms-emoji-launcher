# Emoji & Unicode Launcher

A DankMaterialShell launcher plugin that provides quick access to thousands of emojis, mathematical symbols, and Nerd Font glyphs with instant clipboard copying.

![Emoji & Unicode Launcher Screenshot](screenshot.png)

## Features

- **Expanded Emoji Catalog** - 900+ curated emoji entries combined with the bundled emoji dataset for complete coverage (gear, toolbox, etc.)
- **Unicode & Math Symbols** - Hundreds of useful unicode characters from arrows to operators and currency signs
- **Nerd Font Glyphs** - Searchable Nerd Font icons for launcher, terminal, and code workflows
- **Instant Copy** - One-click copy to clipboard with visual confirmation
- **Smart Search** - Search by name, character, or keywords
- **Configurable Trigger** - Default `:` or set your own trigger (or disable for always-on)
- **Toast Notifications** - Visual feedback for every action

## Installation

### From Plugin Registry (Recommended)
```bash
# Coming soon - will be available via DMS plugin manager
```

### Manual Installation
```bash
# Copy plugin to DMS plugins directory
cp -r EmojiLauncher ~/.config/DankMaterialShell/plugins/

# Enable in DMS
# 1. Open Settings (Ctrl+,)
# 2. Go to Plugins tab
# 3. Click "Scan for Plugins"
# 4. Toggle "Emoji & Unicode Launcher" to enable
```

## Usage

### Default Trigger Mode
1. Open launcher (Ctrl+Space)
2. Type `:` followed by search query
3. Examples:
   - `:smile` - Find smiling emojis
   - `:heart` - Find heart emojis
   - `:copyright` - Find © symbol
   - `:arrow` - Find arrow characters
4. Select item and press Enter to copy

### Always-On Mode
Configure in settings to show emoji/unicode items without a trigger prefix.

## Search Examples

**Emojis:**
- `smile` → 😀 😃 😄 😁 😊
- `heart` → ❤️ 🧡 💛 💚 💙 💜
- `fire` → 🔥
- `star` → ⭐ ✨ 🌟

**Unicode Characters:**
- `copyright` → ©
- `trademark` → ™
- `degree` → °
- `pi` → π
- `arrow` → → ← ↑ ↓
- `infinity` → ∞
- `euro` → €

## Configuration

Access settings via DMS Settings → Plugins → Emoji & Unicode Launcher:

- **Trigger**: Set custom trigger character (`:`, `;`, `/emoji`, etc.) or disable for always-on mode
- **No Trigger Mode**: Toggle to show items without trigger prefix

## Character Database

### Data Sources
- `data/emojis.txt` — comprehensive emoji list (Terminal Root)
- `data/math.txt` — math and general-purpose unicode symbols
- `data/nerdfont.txt` — curated Nerd Font glyph export

All files ship with the plugin, so search works fully offline.

### Highlights
- **Emoji coverage:** faces, hands, tools, activities, symbols, and flags (including gear ⚙️ and toolbox 🧰)
- **Unicode symbols:** math operators, arrows, currency, Greek letters, quotes, and miscellaneous symbols
- **Nerd Font glyphs:** VS Code Codicons, Powerline (ple-) separators, development icons, and other monospace-friendly glyphs for terminal/theming

### Updating the catalog
1. Modify the plain-text sources in `data/` (`emojis.txt`, `math.txt`, `nerdfont.txt`).
2. Run `scripts/generate_catalog.py` to rebuild `catalog.js` (the file bundled with the plugin). The script parses the text files, normalizes names, and refreshes search keywords.

## Requirements

- DankMaterialShell >= 0.1.0
- `wl-copy` (from wl-clipboard package)
- Wayland compositor (Niri, Hyprland, etc.)

## Compatibility

- **Compositors**: Niri and Hyprland
- **Distros**: Universal - works on any Linux distribution

## Technical Details

- **Type**: Launcher plugin
- **Trigger**: `:` (configurable)
- **Language**: QML (Qt Modeling Language)
- **Dependencies**: None (uses built-in character database)

## Contributing

Found a bug or want to add more characters? Open an issue or submit a pull request!

## Credits

Emoji database sourced from [Terminal Root's emoji collection](https://terminalroot.com/emojis.txt) - a comprehensive list of emojis with searchable names.

## License

MIT License - See LICENSE file for details

## Author

Created for the DankMaterialShell community

## Links

- [DankMaterialShell](https://github.com/AvengeMedia/DankMaterialShell)
- [Plugin Registry](https://github.com/AvengeMedia/dms-plugin-registry)
