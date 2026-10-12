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
            title: "Devices"
            
            subTitle: {
                var c = SyncthingService.connectedDeviceCount();
                var t = SyncthingService.deviceCount();
                var p = SyncthingService.pausedDeviceCount();
                return c + "/" + t + " connected" + (p > 0 ? "  \u00B7  " + p + " paused" : "");
            }
        }

        StyledFlickable {
            Layout.fillHeight: true
            Layout.fillWidth: true
            clip: true
            contentHeight: deviceCol.implicitHeight + Padding.massive

            CLayout {
                id: deviceCol
                width: parent.width
                spacing: Padding.small

                Repeater {
                    model: {
                        var arr = [];
                        for (var k in SyncthingService.devices) {
                            if (SyncthingService.devices.hasOwnProperty(k))
                                arr.push(SyncthingService.devices[k]);
                        }
                        return arr;
                    }

                    delegate: DeviceCard {
                        required property var modelData
                        deviceId: modelData.deviceID
                        deviceName: modelData.name
                        deviceShort: modelData.shortID
                        connected: modelData.connected
                        address: modelData.address
                        inBytes: modelData.inBytesTotal
                        outBytes: modelData.outBytesTotal
                        compression: modelData.compression
                        introducer: modelData.introducer
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

    component DeviceCard: StyledRect {
        property string deviceId
        property string deviceName
        property string deviceShort
        property bool connected
        property string address
        property int inBytes
        property int outBytes
        property string compression
        property bool introducer
        property bool paused

        enableBorders: true
        color: Colors.colLayer1
        radius: Rounding.verylarge
        Layout.fillWidth: true
        implicitHeight: deviceBody.implicitHeight + Padding.veryhuge * 2

        CLayout {
            id: deviceBody
            anchors.fill: parent
            anchors.margins: Padding.huge
            spacing: Padding.normal

            RowLayout {
                spacing: Padding.small
                Layout.fillWidth: true

                Symbol {
                    text: paused ? "device_hub" : "dns"
                    color: paused ? Colors.colSubtext : (connected ? Colors.colSuccess : Colors.colError)
                    font.pixelSize: 24
                }

                CLayout {
                    spacing: Padding.tiny
                    Layout.fillWidth: true

                    RowLayout {
                        spacing: Padding.small
                        Layout.fillWidth: true

                        StyledText {
                            text: deviceName
                            color: Colors.colOnSurface
                            font.pixelSize: Fonts.sizes.normal
                            font.weight: 600
                            elide: Text.ElideRight
                            Layout.fillWidth: true
                        }
                        StyledRect {
                            implicitWidth: 8
                            implicitHeight: 8
                            radius: 4
                            color: paused ? Colors.colSubtext : (connected ? Colors.colSuccess : Colors.colError)
                            Layout.alignment: Qt.AlignVCenter
                        }
                    }

                    StyledText {
                        text: deviceShort
                        color: Colors.colSubtext
                        font.pixelSize: 11
                        font.weight: 500
                        font.letterSpacing: 0.5
                    }
                }

                ActionIcon {
                    iconText: paused ? "play_arrow" : "pause"
                    tooltip: paused ? "Resume" : "Pause"
                    accent: paused ? Colors.colSuccess : Colors.colSubtext
                    onClicked: {
                        if (paused) SyncthingService.deviceResume(deviceId);
                        else SyncthingService.devicePause(deviceId);
                    }
                }
            }

            RowLayout {
                spacing: Padding.small
                Layout.fillWidth: true
                visible: connected && !paused

                StyledText {
                    text: address
                    color: Colors.colSubtext
                    font.pixelSize: 11
                    font.weight: 500
                    Layout.fillWidth: true
                }
                StyledText {
                    text: "\u25BC " + SyncthingService.formatBytes(inBytes)
                    color: Colors.colSubtext
                    font.pixelSize: 11
                    font.weight: 500
                }
                StyledText {
                    text: "\u25B2 " + SyncthingService.formatBytes(outBytes)
                    color: Colors.colSubtext
                    font.pixelSize: 11
                    font.weight: 500
                }
            }

            RowLayout {
                spacing: Padding.small
                visible: introducer || compression !== "never"

                StyledRect {
                    visible: introducer
                    color: Qt.rgba(Colors.colSecondary.r, Colors.colSecondary.g, Colors.colSecondary.b, 0.15)
                    radius: Rounding.small
                    implicitHeight: 20
                    implicitWidth: introText.implicitWidth + Padding.normal * 2

                    StyledText {
                        id: introText
                        anchors.centerIn: parent
                        text: "Introducer"
                        color: Colors.colSecondary
                        font.pixelSize: 10
                        font.weight: 700
                    }
                }
                StyledRect {
                    visible: compression !== "never"
                    color: Qt.rgba(Colors.colTertiary.r, Colors.colTertiary.g, Colors.colTertiary.b, 0.15)
                    radius: Rounding.small
                    implicitHeight: 20
                    implicitWidth: compText.implicitWidth + Padding.normal * 2

                    StyledText {
                        id: compText
                        anchors.centerIn: parent
                        text: "Compression: " + compression
                        color: Colors.colTertiary
                        font.pixelSize: 10
                        font.weight: 700
                    }
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
