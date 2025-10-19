import QtQuick
import QtQuick.Controls
import qs.Common
import qs.Widgets

FocusScope {
    id: root

    property var pluginService: null

    implicitHeight: settingsColumn.implicitHeight
    height: implicitHeight

    Column {
        id: settingsColumn
        anchors.fill: parent
        anchors.margins: 16
        spacing: 16

        StyledText {
            text: "Emoji & Unicode Launcher Settings"
            font.pixelSize: Theme.fontSizeLarge
            font.weight: Font.Bold
            color: Theme.surfaceText
        }

        StyledText {
            text: "Search and copy emojis and unicode characters directly from the launcher."
            font.pixelSize: Theme.fontSizeMedium
            color: Theme.surfaceVariantText
            wrapMode: Text.WordWrap
            width: parent.width - 32
        }

        StyledRect {
            width: parent.width - 32
            height: 1
            color: Theme.outlineVariant
        }

        Column {
            spacing: 12
            width: parent.width - 32

            StyledText {
                text: "Trigger Configuration"
                font.pixelSize: Theme.fontSizeLarge
                font.weight: Font.Medium
                color: Theme.surfaceText
            }

            StyledText {
                text: noTriggerToggle.checked ? "Items will always show in the launcher (no trigger needed)." : "Set the trigger text to activate this plugin. Type the trigger in the launcher to filter to emojis and unicode characters."
                font.pixelSize: Theme.fontSizeSmall
                color: Theme.surfaceVariantText
                wrapMode: Text.WordWrap
                width: parent.width
            }

            Row {
                spacing: 12

                CheckBox {
                    id: noTriggerToggle
                    text: "No trigger (always show)"
                    checked: loadSettings("noTrigger", false)

                    contentItem: StyledText {
                        text: noTriggerToggle.text
                        font.pixelSize: Theme.fontSizeMedium
                        color: Theme.surfaceText
                        leftPadding: noTriggerToggle.indicator.width + 8
                        verticalAlignment: Text.AlignVCenter
                    }

                    indicator: StyledRect {
                        implicitWidth: 20
                        implicitHeight: 20
                        radius: Theme.cornerRadiusSmall
                        border.color: noTriggerToggle.checked ? Theme.primary : Theme.outline
                        border.width: 2
                        color: noTriggerToggle.checked ? Theme.primary : "transparent"

                        StyledRect {
                            width: 12
                            height: 12
                            anchors.centerIn: parent
                            radius: 2
                            color: Theme.onPrimary
                            visible: noTriggerToggle.checked
                        }
                    }

                    onCheckedChanged: {
                        saveSettings("noTrigger", checked)
                        if (checked) {
                            saveSettings("trigger", "")
                        } else {
                            saveSettings("trigger", triggerField.text || ":")
                        }
                    }
                }
            }

            Row {
                spacing: 12
                anchors.left: parent.left
                anchors.right: parent.right
                visible: !noTriggerToggle.checked

                StyledText {
                    text: "Trigger:"
                    font.pixelSize: Theme.fontSizeMedium
                    color: Theme.surfaceText
                    anchors.verticalCenter: parent.verticalCenter
                }

                DankTextField {
                    id: triggerField
                    width: 100
                    height: 40
                    text: loadSettings("trigger", ":")
                    placeholderText: ":"
                    backgroundColor: Theme.surfaceContainer
                    textColor: Theme.surfaceText

                    onTextEdited: {
                        const newTrigger = text.trim()
                        saveSettings("trigger", newTrigger || ":")
                        saveSettings("noTrigger", newTrigger === "")
                    }
                }

                StyledText {
                    text: "Examples: :, ;, /emoji, etc."
                    font.pixelSize: Theme.fontSizeSmall
                    color: Theme.surfaceVariantText
                    anchors.verticalCenter: parent.verticalCenter
                }
            }
        }

        StyledRect {
            width: parent.width - 32
            height: 1
            color: Theme.outlineVariant
        }

        Column {
            spacing: 8
            width: parent.width - 32

            StyledText {
                text: "Features:"
                font.pixelSize: Theme.fontSizeMedium
                font.weight: Font.Medium
                color: Theme.surfaceText
            }

            Column {
                spacing: 4
                leftPadding: 16

                StyledText {
                    text: "• 300+ emojis with searchable names and keywords"
                    font.pixelSize: Theme.fontSizeSmall
                    color: Theme.surfaceVariantText
                }

                StyledText {
                    text: "• 100+ unicode characters (symbols, math, currency, etc.)"
                    font.pixelSize: Theme.fontSizeSmall
                    color: Theme.surfaceVariantText
                }

                StyledText {
                    text: "• Search by name, character, or keyword"
                    font.pixelSize: Theme.fontSizeSmall
                    color: Theme.surfaceVariantText
                }

                StyledText {
                    text: "• Click to copy to clipboard"
                    font.pixelSize: Theme.fontSizeSmall
                    color: Theme.surfaceVariantText
                }
            }
        }

        StyledRect {
            width: parent.width - 32
            height: 1
            color: Theme.outlineVariant
        }

        Column {
            spacing: 8
            width: parent.width - 32

            StyledText {
                text: "Usage:"
                font.pixelSize: Theme.fontSizeMedium
                font.weight: Font.Medium
                color: Theme.surfaceText
            }

            Column {
                spacing: 4
                leftPadding: 16
                bottomPadding: 24

                StyledText {
                    text: "1. Open Launcher (Ctrl+Space or click launcher button)"
                    font.pixelSize: Theme.fontSizeSmall
                    color: Theme.surfaceVariantText
                }

                StyledText {
                    text: noTriggerToggle.checked ? "2. Emojis are always visible in the launcher" : "2. Type your trigger (default: :) to filter to emojis/unicode"
                    font.pixelSize: Theme.fontSizeSmall
                    color: Theme.surfaceVariantText
                }

                StyledText {
                    text: noTriggerToggle.checked ? "3. Search by typing: 'smile', 'heart', 'copyright', etc." : "3. Search by typing: ': smile', ': heart', ': copyright', etc."
                    font.pixelSize: Theme.fontSizeSmall
                    color: Theme.surfaceVariantText
                }

                StyledText {
                    text: "4. Select and press Enter to copy to clipboard"
                    font.pixelSize: Theme.fontSizeSmall
                    color: Theme.surfaceVariantText
                }
            }
        }
    }

    function saveSettings(key, value) {
        if (pluginService) {
            pluginService.savePluginData("emojiLauncher", key, value)
        }
    }

    function loadSettings(key, defaultValue) {
        if (pluginService) {
            return pluginService.loadPluginData("emojiLauncher", key, defaultValue)
        }
        return defaultValue
    }
}
