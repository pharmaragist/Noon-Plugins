import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import qs.common
import qs.common.widgets
import qs.services
import "../"

Item {
    id: configTab

    StyledFlickable {
        anchors.fill: parent
        clip: true
        contentHeight: contentCol.implicitHeight + Padding.massive

        CLayout {
            id: contentCol
            width: parent.width
            spacing: Padding.large

            ContentSection {
                title: "Default Runner"
                ContentSubsection {
                    title: "Compatibility tool"
                    StyledComboBox {
                        Layout.fillWidth: true
                        model: ["System default", "Proton Experimental", "Proton 9.0", "Proton 8.0", "Wine-GE 8.25"]
                        onCurrentTextChanged: WineManagerService.setDefaultRunner(currentText)
                    }
                }
                ContentSubsection {
                    title: "Automation"
                    RowLayout {
                        Layout.fillWidth: true
                        StyledText {
                            text: "Check updates on startup"
                            Layout.fillWidth: true
                            color: Colors.colOnSurface
                        }
                        StyledSwitch {
                            checked: true
                        }
                    }
                }
            }

            ContentSection {
                title: "Storage"
                ContentSubsection {
                    title: "Installation directory"
                    RowLayout {
                        Layout.fillWidth: true
                        StyledTextField {
                            Layout.fillWidth: true
                            readOnly: true
                            placeholderText: WineManagerService.installDir || "..."
                            background: Item {}
                        }
                    }
                }
                ContentSubsection {
                    title: "Usage"
                    RowLayout {
                        Layout.fillWidth: true
                        StyledText {
                            text: "Installed tools"
                            color: Colors.colOnSurface
                        }
                        StyledText {
                            text: Object.keys(WineManagerService.installedTools).length + " tools"
                            color: Colors.colOnSurfaceVariant
                            Layout.alignment: Qt.AlignRight
                        }
                    }
                }
            }

            ContentSection {
                title: "Advanced"
                StyledRect {
                    Layout.fillWidth: true
                    height: 48
                    radius: Rounding.medium
                    color: Colors.colErrorContainer
                    RowLayout {
                        anchors.fill: parent
                        anchors.margins: Padding.normal
                        spacing: Padding.normal
                        Symbol {
                            text: "warning"
                            color: Colors.colOnErrorContainer
                            font.pixelSize: 20
                            fill: 1
                        }
                        StyledText {
                            text: "Remove all tools"
                            color: Colors.colOnErrorContainer
                            Layout.fillWidth: true
                        }
                        RippleButtonWithIcon {
                            materialIcon: "delete_forever"
                            implicitSize: 34
                            colBackground: Colors.colError
                            iconColor: Colors.colOnError
                        }
                    }
                }
            }
        }
    }
}
