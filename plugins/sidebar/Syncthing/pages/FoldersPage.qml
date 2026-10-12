import QtQuick
import QtQuick.Layouts
import qs.common
import qs.common.widgets
import "../"

Item {
    id: root
    property bool expanded: false
    signal navigateTo(int page)

    CLayout {
        anchors.fill: parent
        spacing: 0

        PageHeader {
            title: "Folders"

            subTitle: {
                var total = SyncthingService.folderCount();
                var pending = SyncthingService.totalNeedFiles();
                var needBytes = SyncthingService.totalNeedBytes();
                return total + " folders  \u00B7  " + (pending > 0 ? pending + " pending  \u00B7  " + SyncthingService.formatBytes(needBytes) : "all synced");
            }
        }

        StyledFlickable {
            Layout.fillHeight: true
            Layout.fillWidth: true
            clip: true
            contentHeight: folderCol.implicitHeight + Padding.massive

            CLayout {
                id: folderCol
                width: parent.width
                spacing: Padding.small

                Repeater {
                    model: {
                        var arr = [];
                        for (var k in SyncthingService.folders) {
                            if (SyncthingService.folders.hasOwnProperty(k))
                                arr.push(SyncthingService.folders[k]);
                        }
                        return arr;
                    }

                    delegate: FolderCard {
                        required property var modelData
                        folderId: modelData.id
                        label: modelData.label
                        folderPath: modelData.path
                        completion: modelData.completion
                        needFiles: modelData.needFiles
                        needBytes: modelData.needBytes
                        globalBytes: modelData.globalBytes
                        needDeletes: modelData.needDeletes
                        paused: modelData.paused
                    }
                }

                Item {
                    height: Padding.large
                    Layout.fillWidth: true
                }
            }
        }
    }

    component FolderCard: StyledRect {
        property string folderId
        property string label
        property string folderPath
        property real completion
        property int needFiles
        property int needBytes
        property int globalBytes
        property int needDeletes
        property bool paused

        enableBorders: true
        color: Colors.colLayer1
        radius: Rounding.verylarge
        Layout.fillWidth: true
        implicitHeight: folderBody.implicitHeight + Padding.veryhuge * 2

        readonly property string status: SyncthingService.folderStatus(folderId)
        readonly property color statusColor: SyncthingService.folderStatusColor(status)

        CLayout {
            id: folderBody
            anchors.fill: parent
            anchors.margins: Padding.huge
            spacing: Padding.normal

            RowLayout {
                spacing: Padding.small
                Layout.fillWidth: true

                Symbol {
                    text: paused ? "pause_circle" : (needFiles > 0 ? "sync" : "check_circle")
                    color: statusColor
                    font.pixelSize: 24
                }

                CLayout {
                    spacing: Padding.tiny
                    Layout.fillWidth: true

                    StyledText {
                        text: label
                        color: Colors.colOnSurface
                        font.pixelSize: Fonts.sizes.normal
                        font.weight: 600
                        elide: Text.ElideRight
                        Layout.fillWidth: true
                    }
                    StyledText {
                        text: folderPath
                        color: Colors.colSubtext
                        font.pixelSize: 11
                        font.weight: 400
                        elide: Text.ElideMiddle
                        Layout.fillWidth: true
                    }
                }

                StyledRect {
                    color: Qt.rgba(statusColor.r, statusColor.g, statusColor.b, 0.15)
                    radius: Rounding.small
                    implicitHeight: 24
                    implicitWidth: badgeText.implicitWidth + Padding.normal * 2

                    StyledText {
                        id: badgeText
                        anchors.centerIn: parent
                        text: {
                            if (paused)
                                return "Paused";
                            if (needFiles > 0)
                                return needFiles + " pending";
                            return "Synced";
                        }
                        color: statusColor
                        font.pixelSize: 11
                        font.weight: 700
                    }
                }
            }

            StyledRect {
                implicitHeight: 6
                radius: Rounding.small
                color: Colors.colLayer2
                Layout.fillWidth: true
                clip: true

                StyledRect {
                    width: parent.width * Math.min(completion / 100, 1)
                    height: parent.height
                    radius: Rounding.small
                    color: statusColor

                    Behavior on width {
                        NumberAnimation {
                            duration: 500
                            easing.type: Easing.BezierSpline
                            easing.bezierCurve: Animations.curves.emphasizedDecel
                        }
                    }
                }
            }

            RowLayout {
                spacing: Padding.small
                Layout.fillWidth: true

                StyledText {
                    text: needFiles > 0 ? needFiles + " files \u00B7 " + SyncthingService.formatBytes(needBytes) : (completion + "% complete")
                    color: Colors.colSubtext
                    font.pixelSize: 11
                    font.weight: 500
                    Layout.fillWidth: true
                }
                StyledText {
                    text: needDeletes > 0 ? needDeletes + " deletes" : SyncthingService.formatBytes(globalBytes)
                    color: needDeletes > 0 ? Colors.colError : Colors.colSubtext
                    font.pixelSize: 11
                    font.weight: 500
                }
            }

            RowLayout {
                spacing: Padding.small
                Layout.fillWidth: true
                Layout.topMargin: Padding.tiny

                ActionIcon {
                    iconText: "sync"
                    tooltip: paused ? "Resume" : "Pause"
                    accent: statusColor
                    onClicked: {
                        if (paused)
                            SyncthingService.folderResume(folderId);
                        else
                            SyncthingService.folderPause(folderId);
                    }
                }

                ActionIcon {
                    iconText: "more_horiz"
                    tooltip: "Rescan"
                    accent: Colors.colTertiary
                    onClicked: SyncthingService.folderRescan(folderId)
                }

                StyledText {
                    text: paused ? "Paused" : (status === "syncing" ? "Syncing\u2026" : "Idle")
                    color: Colors.colSubtext
                    font.pixelSize: 10
                    font.weight: 500
                    Layout.alignment: Qt.AlignVCenter
                    Layout.fillWidth: true
                    horizontalAlignment: Text.AlignRight
                }
            }
        }
    }

    component ActionIcon: Item {
        property string iconText
        property string tooltip: ""
        property color accent: Colors.colOnSurface
        signal clicked

        implicitWidth: 32
        implicitHeight: 32

        StyledRect {
            anchors.fill: parent
            color: Colors.colLayer2
            radius: Rounding.small
            opacity: area.containsMouse ? 1 : 0.7

            Symbol {
                anchors.centerIn: parent
                text: iconText
                color: accent
                font.pixelSize: 16
            }
        }

        MouseArea {
            id: area
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: parent.clicked()
        }
    }
}
