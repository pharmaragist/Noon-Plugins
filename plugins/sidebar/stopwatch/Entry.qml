import QtQuick
import QtQuick.Layouts
import qs.common
import qs.common.utils
import qs.common.widgets
import qs.services

StyledRect {
    id: root
    clip: true
    color: "transparent"
    radius: Rounding.small

    property string searchQuery: ""
    property bool expanded
    property bool detached
    signal dismiss
    signal searchFocusRequested
    signal contentFocusRequested

    PluginFileView {
        id: store
        fileName: "stopwatch"
        JsonAdapter {
            id: cfg
            property var elapsed: 0
            property var running: false
            property var laps: []
        }
    }

    readonly property var d: store.data
    property string displayTime: "00:00"

    Timer {
        id: ticker
        interval: 1000
        repeat: true
        onTriggered: {
            d.elapsed += 1000;
            displayTime = formatTime(d.elapsed);
        }
    }

    function formatTime(ms) {
        var total = Math.floor(ms);
        var m = Math.floor(total / 60000);
        var s = Math.floor((total % 60000) / 1000);
        return (m < 10 ? "0" : "") + m + ":" + (s < 10 ? "0" : "") + s;
    }

    function toggle() {
        d.running = !d.running;
        ticker.running = d.running;
        updateDisplay();
    }

    function lap() {
        if (d.running) {
            var arr = d.laps.slice();
            arr.push(formatTime(d.elapsed));
            d.laps = arr;
        }
    }

    function reset() {
        ticker.running = false;
        d.running = false;
        d.elapsed = 0;
        d.laps = [];
        updateDisplay();
    }

    function updateDisplay() {
        displayTime = formatTime(d.elapsed);
    }

    Component.onCompleted: updateDisplay()

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: Padding.normal
        spacing: Padding.large

        StyledRect {
            radius: Rounding.verylarge
            color: Colors.colLayer2
            Layout.fillWidth: true
            Layout.fillHeight: true

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: Padding.normal
                spacing: Padding.normal

                StyledText {
                    anchors.centerIn: parent
                    text: displayTime
                    font.family: Fonts.family.variable
                    font.variableAxes: Fonts.variableAxes.longNumbers
                    font.pixelSize: 115
                    color: Colors.colOnSurface
                }

                StyledRect {
                    radius: Rounding.large
                    Layout.alignment: Qt.AlignBottom
                    Layout.fillWidth: true
                    Layout.preferredHeight: 200
                    color: Colors.colLayer3

                    StyledListView {
                        anchors.fill: parent
                        radius: Rounding.large
                        _model: d.laps
                        delegate: StyledRect {
                            width: ListView.view.width
                            height: 30
                            color: Colors.m3.m3surfaceVariant
                            radius: Rounding.small

                            RowLayout {
                                anchors.fill: parent
                                anchors.margins: Padding.small

                                StyledText {
                                    text: "Lap " + (index + 1)
                                    font.family: Fonts.family.monospace
                                    font.pixelSize: Fonts.sizes.small
                                    color: Colors.m3.m3onSurfaceVariant
                                }

                                Item { Layout.fillWidth: true }

                                StyledText {
                                    text: modelData
                                    font.family: Fonts.family.monospace
                                    font.pixelSize: Fonts.sizes.small
                                    color: Colors.m3.m3onSurface
                                }
                            }
                        }

                        StyledText {
                            anchors.centerIn: parent
                            visible: d.laps.length === 0
                            text: "No laps yet"
                            font.pixelSize: Fonts.sizes.normal
                            color: Colors.m3.m3onSurfaceVariant
                        }
                    }
                }
            }
        }

        ButtonGroup {
            Layout.fillWidth: true
            Layout.preferredHeight: 50

            GroupButtonWithIcon {
                baseSize: 50
                Layout.fillWidth: true
                Layout.fillHeight: true

                materialIcon: d.running ? "pause" : "play_arrow"
                releaseAction: () => toggle()
            }

            GroupButtonWithIcon {
                baseSize: 50
                Layout.fillWidth: true
                Layout.fillHeight: true

                materialIcon: "flag"
                enabled: d.running
                releaseAction: () => lap()
            }

            GroupButtonWithIcon {
                baseSize: 50
                Layout.fillWidth: true
                Layout.fillHeight: true

                materialIcon: "restart_alt"
                releaseAction: () => reset()
            }
        }
    }
}
