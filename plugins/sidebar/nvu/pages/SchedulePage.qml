import QtQuick
import QtQuick.Layouts
import qs.common
import qs.common.widgets
import "../"

Item {
    id: root
    property bool expanded: false

    readonly property var dayOrder: ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"]
    readonly property var dayNames: {
        "Sun": "Sunday",
        "Mon": "Monday",
        "Tue": "Tuesday",
        "Wed": "Wednesday",
        "Thu": "Thursday",
        "Fri": "Friday",
        "Sat": "Saturday"
    }

    property string todayKey: {
        var d = new Date();
        var days = ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"];
        return days[d.getDay()];
    }

    CLayout {
        anchors.fill: parent
        anchors.margins: Padding.small
        spacing: 0

        PageHeader {
            title: "Weekly Schedule"
        }

        StyledListView {
            clip: true
            radius: Rounding.verylarge
            Layout.fillHeight: true
            Layout.fillWidth: true
            spacing: Padding.normal
            Layout.topMargin: Padding.small
            model: ScriptModel {
                values: {
                    var days = [];
                    var order = root.dayOrder;
                    for (var i = 0; i < order.length; i++) {
                        if (LMSService?.schedule[order[i]])
                            days.push(order[i]);
                    }
                    return days;
                }
            }
            delegate: DayCard {
                required property string modelData
                anchors.right: parent?.right
                anchors.left: parent?.left
                dayKey: modelData
                dayLabel: root.dayNames[modelData] || modelData
                entries: LMSService ? (LMSService.schedule[modelData] || []) : []
                isToday: modelData === root.todayKey
            }
        }
    }

    component DayCard: StyledRect {
        id: root
        property string dayKey
        property string dayLabel
        property var entries: []
        property bool isToday: false

        enableBorders: true
        color: Colors.colLayer1
        radius: Rounding.verylarge
        implicitHeight: cardContent.implicitHeight + Padding.veryhuge * 2

        CLayout {
            id: cardContent
            anchors.fill: parent
            anchors.margins: Padding.huge
            spacing: 2

            RLayout {
                Layout.fillWidth: true
                Layout.leftMargin: Padding.large
                Layout.bottomMargin: Padding.large
                spacing: Padding.huge

                StyledText {
                    Layout.fillWidth: true
                    text: root.dayLabel
                    color: isToday ? Colors.colPrimary : Colors.colOnSurface
                    font.pixelSize: Fonts.sizes.large
                    font.weight: isToday ? 600 : 400
                    Layout.alignment: Qt.AlignVCenter | Qt.AlignLeft
                }

                StyledText {
                    text: root.entries.length + " session" + (root.entries.length !== 1 ? "s" : "")
                    color: Colors.colSubtext
                    font.pixelSize: Fonts.sizes.small
                    font.weight: 400
                    Layout.alignment: Qt.AlignVCenter
                }
            }

            Repeater {
                model: root.entries
                delegate: StyledRect {
                    required property var modelData
                    required property int index
                    topRadius: index === 0 ? Rounding.large : Rounding.tiny
                    bottomRadius: index === root.entries.length - 1 ? Rounding.large : Rounding.tiny

                    Layout.fillWidth: true
                    implicitHeight: 60
                    color: Colors.colLayer2

                    RLayout {
                        anchors.fill: parent
                        anchors.margins: Padding.large
                        spacing: Padding.large

                        StyledRect {
                            implicitWidth: 4
                            Layout.fillHeight: true
                            Layout.topMargin: Padding.large
                            Layout.bottomMargin: Padding.large
                            radius: 4
                            color: LMSService.subjectColor(modelData.course)
                            Layout.alignment: Qt.AlignVCenter
                        }

                        CLayout {
                            spacing: 0
                            Layout.fillWidth: true
                            Layout.alignment: Qt.AlignVCenter
                            StyledText {
                                text: modelData.course || ""
                                color: Colors.colOnSurface
                                font.pixelSize: Fonts.sizes.normal
                                font.weight: 600
                                truncate: true
                            }
                            StyledText {
                                text: {
                                    var parts = [];
                                    if (modelData.start_time)
                                        parts.push(modelData.start_time);
                                    if (modelData.end_time)
                                        parts.push(" - " + modelData.end_time);
                                    if (modelData.hall)
                                        parts.push("  ·  " + modelData.hall);
                                    return parts.join("");
                                }
                                color: Colors.colSubtext
                                font.pixelSize: Fonts.sizes.small
                                font.weight: 500
                                truncate: true
                            }
                        }

                        StyledRect {
                            visible: modelData.group && modelData.group.length > 0
                            color: Colors.colLayer4
                            radius: Rounding.small
                            implicitHeight: 26
                            implicitWidth: groupText.contentWidth + Padding.normal * 2
                            Layout.alignment: Qt.AlignVCenter
                            StyledText {
                                id: groupText
                                anchors.centerIn: parent
                                text: modelData.group || ""
                                color: Colors.colOnSurface
                                font.pixelSize: Fonts.sizes.verysmall
                                font.weight: 600
                            }
                        }
                    }
                }
            }
        }
    }
}
