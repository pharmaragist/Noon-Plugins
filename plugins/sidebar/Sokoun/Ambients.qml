import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import qs.common
import qs.common.widgets
import qs.services
import "./"

Item {
    id: root
    readonly property var svc: AmbientSoundsService
    ColumnLayout {
        anchors.fill: parent
        spacing: Padding.huge

        SoundItemContainer {
            height: 72
            radius: Rounding.verylarge
            Layout.fillWidth: true
            soundId: ""
            soundVolume: root.svc.states.masterVolume
            playerPlaying: false
            effectivePlaying: !root.svc.states.masterPaused
            soundInfo: null
            isMaster: true
            isActive: true
        }

        StyledListView {
            id: activeList
            Layout.fillHeight: true
            Layout.fillWidth: true
            spacing: 3
            model: root.svc.states.activeSounds
            delegate: SoundItemContainer {
                required property var modelData
                required property int index
                svc: root.svc
                property var _soundInfo: root.svc.states.availableSounds.find(s => s.id === modelData.id)
                topRadius: index === 0 ? Rounding.verylarge : Rounding.verytiny
                bottomRadius: index === root.svc.states.activeSounds.length - 1 ? Rounding.verylarge : Rounding.verytiny
                anchors.right: parent?.right
                anchors.left: parent?.left
                soundId: modelData.id
                soundVolume: modelData.volume
                playerPlaying: modelData.isPlaying ?? false
                effectivePlaying: (modelData.isPlaying ?? false) && !root.svc.states.masterPaused
                soundInfo: _soundInfo ?? null
                isMaster: false
                isActive: true
            }

            PagePlaceholder {
                z: -1
                anchors.centerIn: parent
                shown: root.svc.states.activeSounds.length === 0
                icon: "relax"
                title: "Seems Quiet here"
                description: "Play some noise from tray below"
            }
        }
    }
    StyledRect {
        anchors.bottom: parent.bottom
        anchors.right: parent.right
        anchors.left: parent.left
        implicitHeight: 80
        radius: Rounding.veryhuge
        color: Colors.colLayer1
        ListView {
            anchors.fill: parent
            anchors.margins: Padding.large
            clip: true
            spacing: Padding.normal
            orientation: Qt.Horizontal
            model: root.svc.states.availableSounds
            delegate: RippleButtonWithIcon {
                materialIcon: modelData?.icon ?? ""
                toggled: root.svc.states.activeSounds.indexOf(i => i.id === modelData.id) !== -1
                implicitSize: 50
                anchors.verticalCenter: parent?.verticalCenter
                downAction: () => root.svc.playSound(modelData?.id)

                StyledToolTip {
                    content: modelData.name
                }
            }
        }
    }
}
