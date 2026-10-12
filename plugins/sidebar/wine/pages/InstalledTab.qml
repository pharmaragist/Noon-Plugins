import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import qs.common
import qs.common.widgets
import qs.services
import "../"

Item {
    id: installedTab

    CLayout {
        anchors.fill: parent
        spacing: 0

        PageHeader {
            title: "Compatibility Tools"

            subTitle: Object.keys(WineManagerService.installedTools).length + " installed"
        }

        StyledListView {
            id: installedList
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: Padding.tiny
            delegate: ToolCard {
                required property var modelData
                required property int index

                topRadius: index === 0 ? Rounding.verylarge : Rounding.tiny
                bottomRadius: index === installedList.count - 1 ? Rounding.verylarge : Rounding.tiny

                anchors.right: parent?.right
                anchors.left: parent?.left
                height: 72
            }

            Connections {
                target: WineManagerService
                function onToolsRefreshed() {
                    var arr = [];
                    var map = WineManagerService.installedTools;
                    for (var k in map)
                        arr.push(map[k]);
                    installedList._model = arr;
                }
            }

            Component.onCompleted: {
                var arr = [];
                var map = WineManagerService.installedTools;
                for (var k in map)
                    arr.push(map[k]);
                installedList._model = arr;
            }
        }
    }

    StyledRect {
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        visible: WineManagerService.downloading
        height: visible ? 48 : 0
        radius: Rounding.normal
        color: Colors.colSecondaryContainer

        RowLayout {
            anchors.fill: parent
            anchors.margins: Padding.normal
            spacing: Padding.small
            MaterialLoadingIndicator {
                implicitSize: 20
                Layout.preferredWidth: 20
                Layout.preferredHeight: 20
            }
            StyledText {
                text: WineManagerService.downloadProgress || "Downloading..."
                color: Colors.colOnSecondaryContainer
                Layout.fillWidth: true
                truncate: true
            }
        }
    }

    StyledRect {
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        visible: WineManagerService.lastError.length > 0
        height: visible ? 44 : 0
        radius: Rounding.normal
        color: Colors.colErrorContainer
        RowLayout {
            anchors.fill: parent
            anchors.margins: Padding.small
            StyledText {
                text: WineManagerService.lastError
                color: Colors.colOnErrorContainer
                Layout.fillWidth: true
            }
            RippleButtonWithIcon {
                materialIcon: "close"
                implicitSize: 28
                colBackground: "transparent"
                onClicked: WineManagerService.lastError = ""
            }
        }
    }

    component ToolCard: StyledRect {
        color: Colors.colSurfaceContainerLow

        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: Padding.veryhuge
            anchors.rightMargin: Padding.veryhuge
            spacing: Padding.huge

            Symbol {
                text: modelData?.type === "wine" ? "liquor" : "shield"
                color: Colors.colPrimary
                font.pixelSize: 26
                fill: 1
            }

            ColumnLayout {
                spacing: 1
                Layout.fillWidth: true
                StyledText {
                    text: modelData?.name ?? ""
                    font.variableAxes: Fonts.variableAxes.title
                    font.pixelSize: Fonts.sizes.normal
                    color: Colors.colOnSurface
                    truncate: true
                }
                RowLayout {
                    spacing: Padding.small
                    StyledText {
                        text: modelData?.version ?? ""
                        color: Colors.colOnSurfaceVariant
                        font.pixelSize: Fonts.sizes.small
                    }
                    StyledText {
                        text: (modelData?.size_mb ?? 0) > 0 ? modelData.size_mb + " MB" : ""
                        color: Colors.colOnSurfaceVariant
                        opacity: 0.5
                        font.pixelSize: Fonts.sizes.verysmall
                    }
                }
            }
            RippleButtonWithIcon {
                materialIcon: "delete"
                implicitSize: 34
                colBackground: "transparent"
                onClicked: WineManagerService.uninstallVersion(modelData.name)
            }
        }
    }
}
