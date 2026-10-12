import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import qs.common
import qs.common.widgets
import qs.services

StyledRect {
    id: root
    property var svc
    property string soundId
    property real soundVolume
    property bool playerPlaying: false
    property bool effectivePlaying: false
    property var soundInfo
    property bool isMaster: false
    property bool isActive: false
    implicitHeight: 80
    color: Colors.colLayer1
    clip: true
    z: 0

    RowLayout {
        anchors.fill: parent
        anchors.margins: Padding.normal
        anchors.leftMargin: Padding.verylarge
        anchors.rightMargin: Padding.verylarge
        spacing: Padding.verylarge

        StyledRect {
            implicitSize: 45
            color: Colors.colPrimary
            radius: height / 2

            Symbol {
                anchors.centerIn: parent
                icon: isMaster ? "tune" : (soundInfo?.icon ?? "music_note")
                iconSize: 24
                Layout.alignment: Qt.AlignCenter
                color: Colors.colOnPrimary
            }
        }

        StyledText {
            Layout.fillWidth: true
            text: isMaster ? "Master" : soundInfo?.name ?? ""
            font: Fonts.request("title", "normal")
            color: Colors.colOnLayer0
            truncate: true
        }

        // Controls column
        RowLayout {
            Layout.fillHeight: true
            spacing: Padding.huge

            StyledSlider {
                id: slider
                Layout.preferredWidth: 220
                from: 0
                to: 1
                value: soundVolume
                highlightColor: Colors.colPrimary
                trackColor: Colors.colPrimaryContainer
                handleColor: Colors.colOnPrimaryContainer

                onMoved: {
                    if (isMaster) {
                        root.svc.masterVolume = value;
                    } else {
                        root.svc.setSoundVolume(soundId, value);
                    }
                }

                onValueChanged: {
                    if (Math.abs(value - soundVolume) > 0.001) {
                        if (isMaster) {
                            root.svc.masterVolume = value;
                        } else {
                            root.svc.setSoundVolume(soundId, value);
                        }
                    }
                }
            }
            ButtonGroup {
                id: row
                color: Colors.colLayer2
                Repeater {
                    model: [
                        {
                            visible: !isMaster,
                            materialIcon: playerPlaying ? "pause" : "play_arrow",
                            downAction: () => root.svc.toggleSoundPlayback(soundId)
                        },
                        {
                            visible: isMaster,
                            materialIcon: root.svc.masterPaused ? "play_arrow" : "pause",
                            downAction: () => root.svc.toggleMasterPause()
                        },
                        {
                            visible: !isMaster && isActive,
                            materialIcon: "close",
                            downAction: () => root.svc.stopSound(soundId)
                        }
                    ].filter(i => i.visible)

                    GroupButtonWithIcon {
                        baseSize: 32
                        layerNumber: 3
                        materialIcon: modelData?.materialIcon
                        releaseAction: () => modelData.downAction()
                    }
                }
            }
        }
    }
}
