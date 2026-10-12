import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.common
import qs.common.widgets
import qs.services

StyledRect {
    id: root
    color: Colors.colLayer1
    radius: Rounding.verylarge

    property string searchQuery: ""
    property bool expanded
    property bool detached
    signal dismiss
    signal searchFocusRequested
    signal contentFocusRequested

    readonly property int columns: Math.max(2, Math.floor(width / 110))

    function copyIcon(name) {
        ClipboardService.copy(name);
        Qt.callLater(() => {
            NoonUtils.callIpc("sidebar hide");
        });
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: Padding.small

        ScriptModel {
            id: iconModel
            values: M3IconsService.allIcons.length > 0 ? M3IconsService.filterIcons(root.searchQuery) : []
        }

        StyledGridView {
            id: gridView
            Layout.fillWidth: true
            Layout.fillHeight: true
            Layout.leftMargin: Padding.verylarge
            Layout.rightMargin: Padding.verylarge
            Layout.bottomMargin: Padding.verylarge
            Layout.topMargin: Padding.verylarge
            cellWidth: Math.floor(width / root.columns)
            cellHeight: cellWidth + 30
            clip: true
            currentIndex: -1
            model: iconModel

            Connections {
                target: root
                function onContentFocusRequested() {
                    if (gridView.count > 0) {
                        gridView.currentIndex = 0;
                        gridView.forceActiveFocus();
                    }
                }
            }

            delegate: iconDelegate
        }
    }

    Component {
        id: iconDelegate
        StyledRect {
            required property int index
            required property var modelData

            implicitHeight: gridView.cellHeight
            implicitWidth: gridView.cellWidth
            property bool isSelected: gridView.currentIndex === index && gridView.activeFocus

            radius: Rounding.large
            color: isSelected ? Colors.colSecondaryContainerActive : (mouseArea.containsMouse ? Colors.colSecondaryContainerHover : "transparent")

            MouseArea {
                id: mouseArea
                hoverEnabled: true
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: root.copyIcon(modelData.name)
            }

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: Padding.tiny
                spacing: Padding.tiny

                Item {
                    Layout.fillWidth: true
                    Layout.fillHeight: true

                    Symbol {
                        fill: mouseArea.containsMouse ? 1 : 0
                        anchors.centerIn: parent
                        text: modelData.name
                        font.family: Fonts.family.iconMaterial
                        font.pixelSize: 54
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                    }
                }

                StyledText {
                    Layout.fillWidth: true
                    Layout.maximumHeight: 20
                    text: modelData.name
                    font.pixelSize: Fonts.sizes.normal
                    horizontalAlignment: Text.AlignHCenter
                    elide: Text.ElideRight
                    maximumLineCount: 1
                }
            }
        }
    }
}
