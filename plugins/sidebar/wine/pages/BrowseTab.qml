import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import qs.common
import qs.common.widgets
import qs.services
import "../"

Item {
    id: browseTab

    Connections {
        target: WineManagerService
        function onRemoteRefreshed() {
            browseList._model = WineManagerService.remoteVersions;
        }
    }

    Component.onCompleted: {
        browseList._model = WineManagerService.remoteVersions;
        WineManagerService.fetchRemoteVersions("all");
    }

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
                    onClicked: WineManagerService.fetchRemoteVersions("all")
                }
            }
        }

        StyledListView {
            id: browseList
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: Padding.tiny
            delegate: RemoteRow {
                width: browseList.width
                height: 60
            }
        }
    }

    component RemoteRow: StyledRect {
        required property var modelData
        required property int index
        radius: Rounding.medium
        color: Colors.colSurfaceContainerLow

        RowLayout {
            anchors.fill: parent
            anchors.margins: Padding.normal
            spacing: Padding.normal
            Symbol {
                text: "cloud_download"
                color: Colors.colOnSurfaceVariant
                font.pixelSize: 20
                fill: 0
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
                        text: modelData?.tag ?? ""
                        color: Colors.colPrimary
                        font.pixelSize: Fonts.sizes.small
                    }
                    StyledText {
                        text: modelData?.date ?? ""
                        color: Colors.colOnSurfaceVariant
                        font.pixelSize: Fonts.sizes.tiny
                        opacity: 0.6
                    }
                    StyledText {
                        text: (modelData?.size_mb ?? 0) > 0 ? modelData.size_mb + " MB" : ""
                        color: Colors.colOnSurfaceVariant
                        font.pixelSize: Fonts.sizes.tiny
                        opacity: 0.4
                    }
                }
            }
            RippleButtonWithIcon {
                materialIcon: "download"
                implicitSize: 36
                colBackground: Colors.colPrimaryContainer
                iconColor: Colors.colOnPrimaryContainer
                onClicked: WineManagerService.installVersion(modelData.source || "all", modelData.tag || modelData.name)
            }
        }
    }
}
