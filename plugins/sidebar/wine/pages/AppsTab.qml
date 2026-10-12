import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import qs.common
import qs.common.widgets
import qs.services
import "../"

Item {
    id: appsTab

    function rebuild() {
        var map = WineManagerService.appConfigs;
        var arr = [];
        for (var k in map)
            arr.push({
                id: k,
                config: map[k]
            });
        appsList._model = arr;
    }

    Connections {
        target: WineManagerService
        function onToolsRefreshed() {
            appsTab.rebuild();
        }
    }

    Component.onCompleted: appsTab.rebuild()

    CLayout {
        anchors.fill: parent
        spacing: Padding.small

        StyledRect {
            Layout.fillWidth: true
            Layout.preferredHeight: 40
            radius: Rounding.medium
            color: Colors.colLayer2
            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: Padding.normal
                spacing: Padding.small
                Symbol {
                    text: "search"
                    font.pixelSize: 18
                    color: Colors.colOnSurfaceVariant
                    fill: 0
                }
                StyledTextField {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    placeholderText: "Search..."
                    background: Item {}
                }
                RippleButtonWithIcon {
                    materialIcon: "refresh"
                    implicitSize: 32
                    onClicked: WineManagerService.refreshAppConfigs()
                }
            }
        }

        StyledListView {
            id: appsList
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: Padding.tiny
            delegate: AppRow {
                width: appsList.width
                height: 64
            }
        }
    }

    component AppRow: StyledRect {
        required property var modelData
        required property int index
        radius: Rounding.large
        color: Colors.colSurfaceContainerLow

        RowLayout {
            anchors.fill: parent
            anchors.margins: Padding.normal
            spacing: Padding.normal
            StyledRect {
                width: 36
                height: 36
                radius: Rounding.medium
                color: Colors.colTertiaryContainer
                StyledText {
                    anchors.centerIn: parent
                    text: modelData?.id ? String(modelData.id).charAt(0).toUpperCase() : "?"
                    font.pixelSize: 16
                    color: Colors.colOnTertiaryContainer
                    font.weight: 600
                }
            }
            ColumnLayout {
                spacing: 1
                Layout.fillWidth: true
                StyledText {
                    text: modelData?.id ?? ""
                    font.variableAxes: Fonts.variableAxes.title
                    font.pixelSize: Fonts.sizes.normal
                    color: Colors.colOnSurface
                    truncate: true
                }
                RowLayout {
                    spacing: Padding.small
                    StyledText {
                        text: modelData?.config?.runner ?? "Default"
                        color: Colors.colOnSurfaceVariant
                        font.pixelSize: Fonts.sizes.small
                    }
                    StyledText {
                        text: modelData?.config?.app_path ?? modelData?.config?.appPath ?? ""
                        color: Colors.colOnSurfaceVariant
                        font.pixelSize: Fonts.sizes.tiny
                        truncate: true
                        opacity: 0.5
                        Layout.fillWidth: true
                    }
                }
            }
            RippleButtonWithIcon {
                materialIcon: "settings"
                implicitSize: 34
                colBackground: "transparent"
                onClicked: {
                    cfgDialog.appId = modelData?.id ?? "";
                    cfgDialog.cfg = modelData?.config ?? {};
                    cfgDialog.show = true;
                }
            }
            RippleButtonWithIcon {
                materialIcon: "play_arrow"
                implicitSize: 34
                colBackground: Colors.colPrimaryContainer
                iconColor: Colors.colOnPrimaryContainer
                onClicked: WineManagerService.runApp(modelData?.id ?? "")
            }
        }
    }
}
