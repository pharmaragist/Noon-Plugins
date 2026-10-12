import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.common
import qs.common.utils
import qs.common.widgets
import qs.services

SidebarItemContainer {
    id: root

    property var allIcons: []

    onContentFocusRequested: {
        if (gridView.count > 0) {
            gridView.currentIndex = 0;
            gridView.forceActiveFocus();
        }
    }

    FileView {
        id: iconsFile
        path: Qt.resolvedUrl("./db.json")
        onTextChanged: {
            const raw = JSON.parse(iconsFile.text());
            const icons = [];
            const entries = Object.entries(raw);
            for (let i = 0; i < entries.length; i++) {
                const entry = entries[i];
                const name = entry[0];
                const data = entry[1];
                icons.push({
                    name: name,
                    tags: data.tags || []
                });
            }
            allIcons = icons;
        }
    }

    ScriptModel {
        id: iconModel
        values: root.filterIcons(root.debouncedQuery)
    }

    function filterIcons(query) {
        let result = root.allIcons;
        const q = query.toLowerCase().trim();
        if (!q)
            return result;
        const m = i => {
            return i.toLowerCase().trim().includes(q);
        };

        const filtered = [];
        for (const icon of result) {
            if (m(icon.name)) {
                filtered.push(icon);
                continue;
            }
            const tags = icon.tags;
            let matched = false;
            for (let j = 0; j < tags.length; j++) {
                if (m(tags[j])) {
                    matched = true;
                    break;
                }
            }
            if (matched) {
                filtered.push(icon);
            }
        }
        return filtered;
    }

    function copyIcon(name) {
        ClipboardService.copy(name);
        Ipc.call(["sidebar", "hide"]);
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: Padding.verylarge
        spacing: Padding.small

        StyledGridView {
            id: gridView
            Layout.fillWidth: true
            Layout.fillHeight: true
            columns: root.expanded ? 6 : 3
            hinter.color: Colors.colLayer0
            hint: true
            reuseItems: false
            cellHeight: 120
            clip: true
            currentIndex: -1
            model: iconModel

            delegate: Item {
                required property int index
                required property var modelData
                property bool isSelected: gridView.currentIndex === index && gridView.activeFocus

                implicitHeight: gridView.cellHeight - Padding.small
                implicitWidth: gridView.cellWidth - Padding.small

                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: Padding.tiny
                    spacing: Padding.tiny

                    Item {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        StyledRect {
                            anchors.centerIn: parent
                            implicitSize: 80
                            color: isSelected ? Colors.colSecondaryContainer : "transparent"
                            radius: isSelected ? Rounding.veryhuge : Rounding.tiny
                            bouncy: true

                            Behavior on radius {
                                SAnim {
                                    duration: 1000
                                }
                            }

                            Symbol {
                                fill: mouseArea.containsMouse ? 1 : 0
                                anchors.centerIn: parent
                                icon: modelData.name
                                iconSize: 54
                                color: Colors.colOnLayer0
                            }
                        }
                    }

                    StyledText {
                        Layout.fillWidth: true
                        Layout.maximumHeight: 20
                        text: modelData.name
                        font: Fonts.request("main", "normal")
                        horizontalAlignment: Text.AlignHCenter
                        truncate: true
                        color: Colors.colOnLayer0
                    }
                }

                MouseArea {
                    id: mouseArea
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.copyIcon(modelData.name)
                }
            }
        }
    }
}
