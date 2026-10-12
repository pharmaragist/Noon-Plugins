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
            title: "Recent Activity"

            subTitle: (SyncthingService.events.length || 0) + " events"
        }

        StyledFlickable {
            Layout.fillHeight: true
            Layout.fillWidth: true
            clip: true
            contentHeight: eventCol.implicitHeight + Padding.massive

            CLayout {
                id: eventCol
                width: parent.width
                spacing: 0

                Repeater {
                    model: {
                        var arr = [];
                        var evts = SyncthingService.events;
                        if (evts && evts.length) {
                            for (var i = evts.length - 1; i >= 0; i--)
                                arr.push(evts[i]);
                        }
                        return arr;
                    }

                    delegate: EventCard {
                        required property var modelData
                        eventType: modelData.type
                        eventData: modelData.data
                        eventTime: modelData.time
                    }
                }

                StyledText {
                    text: SyncthingService.events.length === 0 ? "No recent events" : ""
                    color: Colors.colSubtext
                    font.pixelSize: Fonts.sizes.small
                    font.weight: 500
                    Layout.alignment: Qt.AlignHCenter
                    Layout.topMargin: Padding.veryhuge
                }

                Item {
                    height: Padding.large
                    Layout.fillWidth: true
                }
            }
        }
    }

    component EventCard: StyledRect {
        property string eventType
        property var eventData
        property string eventTime

        enableBorders: true
        color: Colors.colLayer1
        radius: Rounding.verylarge
        Layout.fillWidth: true
        implicitHeight: eventBody.implicitHeight + Padding.huge * 2
        Layout.bottomMargin: Padding.small

        readonly property color typeColor: {
            switch (eventType) {
            case "ItemStarted":
                return Colors.colTertiary;
            case "ItemFinished":
                return eventData && eventData.error ? Colors.colError : Colors.colSuccess;
            case "StateChanged":
                return Colors.colPrimary;
            case "RemoteIndexUpdated":
                return Colors.colSecondary;
            case "LocalIndexUpdated":
                return Colors.colSecondary;
            default:
                return Colors.colSubtext;
            }
        }

        readonly property string typeLabel: {
            switch (eventType) {
            case "ItemStarted":
                return "Syncing";
            case "ItemFinished":
                return eventData && eventData.error ? "Failed" : "Synced";
            case "StateChanged":
                return "Folder State";
            case "RemoteIndexUpdated":
                return "Remote Update";
            case "LocalIndexUpdated":
                return "Local Update";
            default:
                return eventType;
            }
        }

        CLayout {
            id: eventBody
            anchors.fill: parent
            anchors.margins: Padding.huge
            spacing: Padding.small

            RowLayout {
                spacing: Padding.small
                Layout.fillWidth: true

                Symbol {
                    text: SyncthingService.eventIcon(eventType)
                    color: typeColor
                    font.pixelSize: 20
                }

                CLayout {
                    spacing: Padding.tiny
                    Layout.fillWidth: true

                    RowLayout {
                        spacing: Padding.small
                        Layout.fillWidth: true

                        StyledText {
                            text: typeLabel
                            color: Colors.colOnSurface
                            font.pixelSize: Fonts.sizes.normal
                            font.weight: 600
                            Layout.fillWidth: true
                        }

                        StyledRect {
                            color: Qt.rgba(typeColor.r, typeColor.g, typeColor.b, 0.15)
                            radius: Rounding.small
                            implicitHeight: 20
                            implicitWidth: evtBadge.implicitWidth + Padding.normal

                            StyledText {
                                id: evtBadge
                                anchors.centerIn: parent
                                text: typeLabel
                                color: typeColor
                                font.pixelSize: 10
                                font.weight: 700
                                visible: false
                            }
                        }
                    }

                    StyledText {
                        text: {
                            if (!eventData)
                                return "";
                            if (eventType === "ItemStarted" || eventType === "ItemFinished")
                                return (eventData.folder || "") + " / " + (eventData.item || "");
                            if (eventType === "StateChanged")
                                return (eventData.folder || "") + ": " + (eventData.from || "") + " \u2192 " + (eventData.to || "");
                            return eventData.folder || "";
                        }
                        color: Colors.colSubtext
                        font.pixelSize: 11
                        font.weight: 500
                        elide: Text.ElideRight
                        Layout.fillWidth: true
                        maximumLineCount: 2
                        wrapMode: Text.WordWrap
                    }
                }

                StyledText {
                    text: {
                        if (!eventTime)
                            return "";
                        try {
                            var d = new Date(eventTime);
                            var now = new Date();
                            var diff = Math.floor((now - d) / 1000);
                            if (diff < 60)
                                return "now";
                            if (diff < 3600)
                                return Math.floor(diff / 60) + "m";
                            if (diff < 86400)
                                return Math.floor(diff / 3600) + "h";
                            return Math.floor(diff / 86400) + "d";
                        } catch (e) {
                            return "";
                        }
                    }
                    color: Colors.colSubtext
                    font.pixelSize: 11
                    font.weight: 500
                    horizontalAlignment: Text.AlignRight
                }
            }
        }
    }
}
