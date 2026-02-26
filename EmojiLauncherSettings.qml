import QtQuick
import qs.Common
import qs.Widgets
import qs.Modules.Plugins

PluginSettings {
    id: root
    pluginId: "emojiLauncher"

    Component.onCompleted: {
        const currentTrigger = root.loadValue("trigger", ":e");
        if (!currentTrigger || currentTrigger.trim().length === 0)
            root.saveValue("trigger", ":e");
    }

    StyledText {
        width: parent.width
        text: "Emoji & Unicode Launcher"
        font.pixelSize: Theme.fontSizeLarge
        font.weight: Font.Bold
        color: Theme.surfaceText
    }

    StyledText {
        width: parent.width
        text: "Search and copy emojis and unicode characters directly from the launcher."
        font.pixelSize: Theme.fontSizeSmall
        color: Theme.surfaceVariantText
        wrapMode: Text.WordWrap
    }

    Rectangle {
        width: parent.width
        height: 1
        color: Theme.outline
        opacity: 0.3
    }

    StringSetting {
        id: triggerSetting
        settingKey: "trigger"
        label: "Trigger"
        description: "Examples: :, ;, em, etc. Avoid triggers reserved by DMS or other plugins (e.g., / for file search)."
        placeholder: ":e"
        defaultValue: ":e"
    }

    Rectangle {
        width: parent.width
        height: 1
        color: Theme.outline
        opacity: 0.3
    }

    ToggleSetting {
        id: pasteOnSelectToggle
        settingKey: "pasteOnSelect"
        label: "Paste on Select"
        description: value ? "Immediately paste as well as copying to the clipboard. Requires wtype" : "Use shift+return to directly paste."
        defaultValue: false
    }

    Rectangle {
        width: parent.width
        height: 1
        color: Theme.outline
        opacity: 0.3
    }

    ToggleSetting {
        id: useDMSToggle
        settingKey: "useDMS"
        label: "Clipboard Program"
        description: value ? "Use DMS clipboard command (dms cl copy) with wl-copy fallback." : "Use wl-copy for clipboard operations."
        defaultValue: true
    }

    Rectangle {
        width: parent.width
        height: 1
        color: Theme.outline
        opacity: 0.3
    }

    StyledText {
        width: parent.width
        text: "Features"
        font.pixelSize: Theme.fontSizeMedium
        font.weight: Font.Medium
        color: Theme.surfaceText
    }

    Column {
        width: parent.width
        spacing: Theme.spacingXS
        leftPadding: Theme.spacingM

        Repeater {
            model: ["1k+ emojis & unicode symbols (faces, tools, math, currency)", "Nerd Font glyph catalog for launcher / terminal icons", "Search by name, character, or keyword", "Click to copy to clipboard"]

            StyledText {
                required property string modelData
                text: "• " + modelData
                font.pixelSize: Theme.fontSizeSmall
                color: Theme.surfaceVariantText
            }
        }
    }

    Rectangle {
        width: parent.width
        height: 1
        color: Theme.outline
        opacity: 0.3
    }

    StyledText {
        width: parent.width
        text: "Usage"
        font.pixelSize: Theme.fontSizeMedium
        font.weight: Font.Medium
        color: Theme.surfaceText
    }

    Column {
        width: parent.width
        spacing: Theme.spacingXS
        leftPadding: Theme.spacingM
        bottomPadding: Theme.spacingL

        Repeater {
            model: ["1. Open Launcher (Ctrl+Space or click launcher button)", "2. Type your trigger (default: :e) to filter to emojis/unicode", "3. Search by typing: ':e smile', ':e heart', ':e copyright', etc.", "4. Press Enter to copy to clipboard", "5. Press Shift+Enter to paste directly into the focused app"]

            StyledText {
                required property string modelData
                text: modelData
                font.pixelSize: Theme.fontSizeSmall
                color: Theme.surfaceVariantText
            }
        }
    }
}
