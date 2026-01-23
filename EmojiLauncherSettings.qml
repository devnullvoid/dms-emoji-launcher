import QtQuick
import qs.Common
import qs.Widgets
import qs.Modules.Plugins

PluginSettings {
    id: root
    pluginId: "emojiLauncher"

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

    ToggleSetting {
        id: noTriggerToggle
        settingKey: "noTrigger"
        label: "Always Active"
        description: value ? "Items will always show in the launcher (no trigger needed)." : "Set the trigger text to activate this plugin. Type the trigger in the launcher to filter to emojis and unicode characters."
        defaultValue: false
        onValueChanged: {
            if (value) {
                root.saveValue("trigger", "");
            } else {
                root.saveValue("trigger", triggerSetting.value || ":");
            }
        }
    }

    StringSetting {
        id: triggerSetting
        visible: !noTriggerToggle.value
        settingKey: "trigger"
        label: "Trigger"
        description: "Examples: :, ;, em, etc. Avoid triggers reserved by DMS or other plugins (e.g., / for file search)."
        placeholder: ":"
        defaultValue: ":"
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
            model: ["1. Open Launcher (Ctrl+Space or click launcher button)", noTriggerToggle.value ? "2. Emojis are always visible in the launcher" : "2. Type your trigger (default: :) to filter to emojis/unicode", noTriggerToggle.value ? "3. Search by typing: 'smile', 'heart', 'copyright', etc." : "3. Search by typing: ': smile', ': heart', ': copyright', etc.", "4. Select and press Enter to copy to clipboard"]

            StyledText {
                required property string modelData
                text: modelData
                font.pixelSize: Theme.fontSizeSmall
                color: Theme.surfaceVariantText
            }
        }
    }
}
