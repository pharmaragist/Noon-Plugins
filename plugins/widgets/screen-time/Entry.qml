import QtQuick
import QtQuick.Layouts
import qs.common
import qs.common.widgets
import qs.services

WidgetContainer {
    id: root

    color: Colors.colSurface
    clip: true

    function formatTime(secs) {
        if (secs < 60) return secs + "s";
        if (secs < 3600) return Math.floor(secs / 60) + "m " + (secs % 60) + "s";
        var h = Math.floor(secs / 3600);
        var m = Math.floor((secs % 3600) / 60);
        return h + "h " + m + "m";
    }

    function totalTime() {
        var t = 0;
        var arr = ScreenTimeService.appTimes;
        for (var i = 0; i < arr.length; i++) t += arr[i].timeSeconds;
        return t;
    }

    function topApps(n) {
        var arr = ScreenTimeService.appTimes.slice();
        arr.sort(function(a, b) { return b.timeSeconds - a.timeSeconds; });
        return arr.slice(0, n);
    }

    function maxTime() {
        var t = 0;
        var arr = ScreenTimeService.appTimes;
        for (var i = 0; i < arr.length; i++)
            if (arr[i].timeSeconds > t) t = arr[i].timeSeconds;
        return t;
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: Padding.large
        spacing: Padding.small

        RowLayout {
            Layout.fillWidth: true
            spacing: Padding.small

            StyledIconImage {
                _source: "timer"
                implicitSize: root.isSmall ? 0 : 24
                color: Colors.colPrimary
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 0

                StyledText {
                    text: formatTime(totalTime())
                    font.pixelSize: root.isSmall ? Fonts.sizes.normal : Fonts.sizes.large
                    font.weight: Font.Bold
                    font.family: Fonts.family.variable
                    font.variableAxes: Fonts.variableAxes.longNumbers
                    color: Colors.colOnSurface
                    horizontalAlignment: root.isSmall ? Text.AlignHCenter : Text.AlignLeft
                }

                StyledText {
                    visible: !root.isSmall
                    text: "Today"
                    font.pixelSize: Fonts.sizes.verysmall
                    color: Colors.colOnSurfaceVariant
                }
            }
        }

        Repeater {
            model: topApps(root.isSmall ? 1 : (root.isXLarge ? 6 : (root.isLarge ? 5 : 3)))

            delegate: Item {
                required property var modelData
                required property int index

                Layout.fillWidth: true
                height: root.isSmall ? 20 : 28

                RowLayout {
                    anchors.fill: parent
                    spacing: Padding.small

                    StyledIconImage {
                        _source: AppSearch.guessIcon(modelData?.class ?? "") ?? ""
                        implicitSize: 20
                    }

                    StyledText {
                        text: DesktopEntries.byId(modelData?.class).name ?? modelData.class
                        font.pixelSize: Fonts.sizes.verysmall
                        color: Colors.colOnSurface
                        Layout.fillWidth: true
                        elide: Text.ElideRight
                    }

                    StyledText {
                        text: formatTime(modelData.timeSeconds)
                        font.pixelSize: Fonts.sizes.verysmall
                        font.family: Fonts.family.monospace
                        color: Colors.colOnSurfaceVariant
                    }
                }

                StyledProgressBar {
                    anchors.bottom: parent.bottom
                    anchors.left: parent.left
                    anchors.right: parent.right
                    valueBarHeight: 2
                    value: maxTime() > 0 ? modelData.timeSeconds / maxTime() : 0
                    highlightColor: Colors.colPrimary
                    trackColor: Colors.colSurfaceVariant
                    showProgressIndicator: false
                }
            }
        }

        Item { Layout.fillHeight: true }

        StyledText {
            Layout.fillWidth: true
            visible: ScreenTimeService.appTimes.length === 0
            text: "No activity yet"
            font.pixelSize: Fonts.sizes.small
            color: Colors.colOnSurfaceVariant
            horizontalAlignment: Text.AlignHCenter
        }
    }
}
