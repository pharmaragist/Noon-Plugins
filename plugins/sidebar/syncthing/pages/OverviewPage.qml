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
            title: "Syncthing"

            subTitle: {
                var f = SyncthingService.folderCount();
                var d = SyncthingService.deviceCount();
                var c = SyncthingService.connectedDeviceCount();
                return f + " folders  \u00B7  " + c + "/" + d + " devices online";
            }
        }

        StyledFlickable {
            Layout.fillHeight: true
            Layout.fillWidth: true
            clip: true
            contentHeight: contentCol.implicitHeight + Padding.massive

            CLayout {
                id: contentCol
                width: parent.width
                spacing: Padding.large

                StyledRect {
                    visible: !SyncthingService.connected && SyncthingService.connectionStatus.length > 0
                    color: Colors.colErrorContainer
                    radius: Rounding.small
                    Layout.fillWidth: true
                    implicitHeight: 32

                    MouseArea {
                        anchors.fill: parent
                        onClicked: SyncthingService.refreshNow()

                        RowLayout {
                            anchors.centerIn: parent
                            spacing: Padding.small

                            Symbol {
                                text: "warning"
                                color: Colors.colOnErrorContainer
                                font.pixelSize: 16
                            }
                            StyledText {
                                text: SyncthingService.connectionStatus
                                color: Colors.colOnErrorContainer
                                font.pixelSize: 11
                                font.weight: 600
                            }
                            Symbol {
                                text: "refresh"
                                color: Colors.colOnErrorContainer
                                font.pixelSize: 14
                            }
                        }
                    }
                }

                StyledRect {
                    visible: SyncthingService.actionFeedback.length > 0
                    color: Colors.colSuccessContainer
                    radius: Rounding.small
                    Layout.fillWidth: true
                    implicitHeight: 28

                    RowLayout {
                        anchors.centerIn: parent
                        spacing: Padding.small

                        Symbol {
                            text: "check_circle"
                            color: Colors.colOnSuccessContainer
                            font.pixelSize: 14
                        }
                        StyledText {
                            text: SyncthingService.actionFeedback
                            color: Colors.colOnSuccessContainer
                            font.pixelSize: 10
                            font.weight: 500
                        }
                    }
                }

                StyledRect {
                    enableBorders: true
                    color: SyncthingService.connected ? Colors.colLayer1 : Colors.colErrorContainer
                    radius: Rounding.verylarge
                    Layout.fillWidth: true
                    implicitHeight: statusRow.implicitHeight + Padding.huge * 2
                    Behavior on color {
                        ColorAnimation {
                            duration: 300
                        }
                    }

                    RowLayout {
                        id: statusRow
                        anchors.centerIn: parent
                        spacing: Padding.large

                        Symbol {
                            text: SyncthingService.connected ? "check_circle" : "error"
                            color: SyncthingService.connected ? Colors.colSuccess : Colors.colOnErrorContainer
                            font.pixelSize: 28
                        }
                        CLayout {
                            spacing: Padding.tiny
                            StyledText {
                                text: SyncthingService.connected ? "All Systems Operational" : "Disconnected"
                                color: SyncthingService.connected ? Colors.colOnSurface : Colors.colOnErrorContainer
                                font.pixelSize: Fonts.sizes.large
                                font.weight: 700
                            }
                            StyledText {
                                text: SyncthingService.connected ? ("v" + (SyncthingService.systemInfo.version || "\u2014")) : ""
                                color: SyncthingService.connected ? Colors.colSubtext : Colors.colOnErrorContainer
                                font.pixelSize: Fonts.sizes.small
                                font.weight: 500
                            }
                        }
                        Item {
                            Layout.fillWidth: true
                        }
                        StyledText {
                            text: SyncthingService.connected ? "\u25CF Live" : "\u25CF Offline"
                            color: SyncthingService.connected ? Colors.colSuccess : Colors.colError
                            font.pixelSize: 11
                            font.weight: 700
                            visible: SyncthingService.connected
                        }
                    }
                }

                RLayout {
                    spacing: Padding.small
                    Layout.fillWidth: true
                    StatCard {
                        icon: "folder"
                        value: SyncthingService.folderCount()
                        label: "Folders"
                        accentColor: Colors.colPrimary
                    }
                    StatCard {
                        icon: "devices"
                        value: SyncthingService.connectedDeviceCount() + "/" + SyncthingService.deviceCount()
                        label: "Devices Online"
                        accentColor: Colors.colSecondary
                    }
                }

                RLayout {
                    spacing: Padding.small
                    Layout.fillWidth: true
                    StatCard {
                        icon: "sync"
                        value: SyncthingService.totalNeedFiles()
                        label: "Pending Files"
                        accentColor: Colors.colTertiary
                    }
                    StatCard {
                        icon: "download"
                        value: SyncthingService.formatBytes(SyncthingService.connections.totalIn || 0)
                        label: "Downloaded"
                        accentColor: Colors.colPrimary
                    }
                    StatCard {
                        icon: "upload"
                        value: SyncthingService.formatBytes(SyncthingService.connections.totalOut || 0)
                        label: "Uploaded"
                        accentColor: Colors.colSecondary
                    }
                }

                StyledRect {
                    visible: SyncthingService.connected
                    enableBorders: true
                    color: Colors.colLayer1
                    radius: Rounding.verylarge
                    Layout.fillWidth: true
                    implicitHeight: actionsCol.implicitHeight + Padding.veryhuge * 2

                    CLayout {
                        id: actionsCol
                        anchors.fill: parent
                        anchors.margins: Padding.huge
                        spacing: Padding.normal

                        StyledText {
                            text: "Actions"
                            font.pixelSize: Fonts.sizes.large
                            font.weight: 600
                            color: Colors.colOnLayer2
                        }

                        RLayout {
                            spacing: Padding.small
                            Layout.fillWidth: true

                            ActionBtn {
                                materialIcon: "refresh"
                                label: "Refresh Now"
                                loading: SyncthingService.refreshing
                                onClicked: SyncthingService.refreshNow()
                            }
                            ActionBtn {
                                materialIcon: "restart_alt"
                                label: "Restart Syncthing"
                                loading: SyncthingService.actionInProgress
                                onClicked: SyncthingService.restartSt()
                            }
                        }

                        RowLayout {
                            spacing: Padding.small
                            Layout.fillWidth: true

                            StatAction {
                                icon: "schedule"
                                label: "Uptime"
                                value: SyncthingService.formatUptime(SyncthingService.systemInfo.uptime)
                            }
                            StatAction {
                                icon: "memory"
                                label: "Memory"
                                value: (SyncthingService.systemInfo.memUsageMB || 0) + " MB"
                            }
                            StatAction {
                                icon: "trending_up"
                                label: "CPU"
                                value: (SyncthingService.systemInfo.cpuPercent || 0) + "%"
                            }
                        }
                    }
                }

                StyledRect {
                    visible: SyncthingService.connected
                    enableBorders: true
                    color: Colors.colLayer1
                    radius: Rounding.verylarge
                    Layout.fillWidth: true
                    implicitHeight: sysCol.implicitHeight + Padding.veryhuge * 2

                    CLayout {
                        id: sysCol
                        anchors.fill: parent
                        anchors.margins: Padding.huge
                        spacing: Padding.normal

                        StyledText {
                            text: "System"
                            font.pixelSize: Fonts.sizes.large
                            font.weight: 600
                            color: Colors.colOnLayer2
                        }

                        GridLayout {
                            columns: 2
                            columnSpacing: Padding.huge
                            rowSpacing: Padding.small
                            Layout.fillWidth: true

                            SysInfoRow {
                                label: "Device ID"
                                value: (SyncthingService.systemInfo.myID || "\u2014").substring(0, 20) + "\u2026"
                            }
                            SysInfoRow {
                                label: "Version"
                                value: SyncthingService.systemInfo.version || "\u2014"
                            }
                            SysInfoRow {
                                label: "Uptime"
                                value: SyncthingService.formatUptime(SyncthingService.systemInfo.uptime)
                            }
                            SysInfoRow {
                                label: "Last Dial"
                                value: SyncthingService.systemInfo.lastDialSuccess || "\u2014"
                            }
                        }
                    }
                }

                Item {
                    height: Padding.large
                    Layout.fillWidth: true
                }
            }
        }
    }

    component StatCard: StyledRect {
        property string icon
        property var value
        property string label
        property color accentColor

        enableBorders: true
        color: Colors.colLayer1
        radius: Rounding.verylarge
        implicitHeight: 96
        Layout.fillWidth: true

        CLayout {
            anchors.centerIn: parent
            spacing: Padding.tiny

            Symbol {
                text: icon
                color: accentColor
                font.pixelSize: 22
                Layout.alignment: Qt.AlignHCenter
            }
            StyledText {
                text: value
                color: Colors.colOnSurface
                font.pixelSize: Fonts.sizes.verylarge
                font.weight: 700
                Layout.alignment: Qt.AlignHCenter
            }
            StyledText {
                text: label
                color: Colors.colSubtext
                font.pixelSize: Fonts.sizes.small
                font.weight: 500
                Layout.alignment: Qt.AlignHCenter
            }
        }
    }

    component ActionBtn: GroupButton {
        property string materialIcon
        property string label
        property bool loading: false

        buttonRadius: Rounding.normal
        baseHeight: 52
        Layout.fillWidth: true
        enabled: !loading

        contentItem: Column {
            spacing: Padding.tiny
            Symbol {
                text: loading ? "refresh" : materialIcon
                color: Colors.colOnLayer2
                font.pixelSize: 22
                anchors.horizontalCenter: parent.horizontalCenter
                NumberAnimation on rotation {
                    running: loading
                    from: 0
                    to: 360
                    duration: 1000
                    loops: Animation.Infinite
                    easing.type: Easing.Linear
                }
            }
            StyledText {
                text: loading ? "Working\u2026" : label
                color: Colors.colSubtext
                font.pixelSize: Fonts.sizes.small
                font.weight: 500
                anchors.horizontalCenter: parent.horizontalCenter
            }
        }
    }

    component StatAction: StyledRect {
        property string icon
        property string label
        property string value

        enableBorders: true
        color: Colors.colLayer2
        radius: Rounding.normal
        Layout.fillWidth: true
        implicitHeight: 56

        RowLayout {
            anchors.fill: parent
            anchors.margins: Padding.small
            spacing: Padding.small

            Symbol {
                text: icon
                color: Colors.colSubtext
                font.pixelSize: 18
            }
            GridLayout {
                columns: 1
                rowSpacing: 0
                Layout.fillWidth: true

                StyledText {
                    text: value
                    color: Colors.colOnSurface
                    font.pixelSize: Fonts.sizes.normal
                    font.weight: 600
                }
                StyledText {
                    text: label
                    color: Colors.colSubtext
                    font.pixelSize: 10
                    font.weight: 500
                }
            }
        }
    }

    component SysInfoRow: RowLayout {
        property string label
        property string value

        spacing: Padding.small
        Layout.fillWidth: true

        StyledText {
            text: label
            color: Colors.colSubtext
            font.pixelSize: Fonts.sizes.small
            font.weight: 500
            Layout.minimumWidth: 80
        }
        StyledText {
            text: value
            color: Colors.colOnSurface
            font.pixelSize: Fonts.sizes.small
            font.weight: 600
            horizontalAlignment: Text.AlignRight
            Layout.fillWidth: true
        }
    }
}
