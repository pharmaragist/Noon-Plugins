import QtQuick
import QtQuick.Layouts
import qs.common
import qs.common.widgets
import qs.services
import "../"

Item {
    id: root

    CLayout {
        id: listCol
        anchors.fill: parent
        anchors.margins: Padding.small
        spacing: 0

        PageHeader {
            title: "Grades"

            subTitle: {
                var c = LMSService.totalSubjects(LMSService.grades);
                var a = LMSService.totalItems(LMSService.grades);
                return c + " courses  ·  " + a + " activities";
            }
        }

        StyledListView {
            clip: true
            radius: Rounding.verylarge
            Layout.fillHeight: true
            Layout.fillWidth: true
            spacing: Padding.normal
            model: ScriptModel {
                values: Object.keys(LMSService?.grades) ?? []
            }
            delegate: CourseGradeCard {
                required property string modelData
                anchors.right: parent?.right
                anchors.left: parent?.left
                courseName: modelData
                activities: LMSService ? (LMSService.grades[modelData] || []) : []
            }
        }
    }

    component CourseGradeCard: StyledRect {
        id: root
        property string courseName
        property var activities: []
        enableBorders: true
        color: Colors.colLayer1
        radius: Rounding.verylarge
        implicitHeight: cardContent.implicitHeight + Padding.veryhuge * 2
        clip: true

        property real avgPercent: {
            var total = 0, count = 0;
            for (var i = 0; i < activities.length; i++) {
                var p = parseFloat(activities[i].student_percent);
                if (!isNaN(p)) {
                    total += p;
                    count++;
                }
            }
            return count > 0 ? Math.round(total / count) : 0;
        }

        property color gradeColor: {
            if (avgPercent >= 90)
                return Colors.m3.m3success;
            if (avgPercent >= 75)
                return Colors.m3.m3tertiary;
            if (avgPercent >= 60)
                return Colors.m3.m3error;
            return Colors.m3.m3error;
        }

        CLayout {
            id: cardContent
            anchors.fill: parent
            anchors.margins: Padding.huge
            spacing: 4

            RLayout {
                Layout.preferredHeight: 45
                Layout.fillWidth: true
                Layout.leftMargin: Padding.large
                Layout.rightMargin: Padding.large
                spacing: Padding.huge

                StyledText {
                    text: root.courseName
                    color: Colors.colOnSurface
                    font.pixelSize: Fonts.sizes.large
                    Layout.fillWidth: true
                    truncate: true
                }

                CircularProgress {
                    implicitSize: 38
                    lineWidth: 4
                    colPrimary: root.gradeColor
                    colSecondary: Colors.m3.m3surfaceContainerHigh

                    Anim on value {
                        from: 0
                        to: root.avgPercent / 100
                        duration: 600
                    }

                    StyledText {
                        z: 999
                        anchors.centerIn: parent
                        text: root.avgPercent
                        color: root.gradeColor
                        font.pixelSize: 12
                        font.weight: 700
                    }
                }
            }

            Repeater {
                model: root.activities
                delegate: StyledRect {
                    required property var modelData
                    required property int index
                    topRadius: index === 0 ? Rounding.large : Rounding.tiny
                    bottomRadius: index === root.activities.length - 1 ? Rounding.large : Rounding.tiny

                    Layout.fillWidth: true
                    implicitHeight: 60
                    color: Colors.colLayer2

                    RLayout {
                        anchors.fill: parent
                        anchors.margins: Padding.large
                        spacing: Padding.large

                        CLayout {
                            spacing: 0
                            Layout.fillWidth: true
                            Layout.alignment: Qt.AlignVCenter
                            StyledText {
                                text: modelData.activity_name || ""
                                color: Colors.m3.m3onSurface
                                font.pixelSize: Fonts.sizes.normal
                                font.weight: 500
                                truncate: true
                                Layout.fillWidth: true
                                Layout.rightMargin: Padding.large
                            }
                            StyledText {
                                text: (modelData.activity_type || "") + "  ·  " + (modelData.attempts || "0") + " attempt" + ((modelData.attempts || 0) !== 1 ? "s" : "")
                                font.pixelSize: Fonts.sizes.small
                                font.weight: 500
                                Layout.fillWidth: true
                                Layout.rightMargin: Padding.large
                                truncate: true
                                color: Colors.colSubtext
                            }
                        }

                        StyledText {
                            text: {
                                const isValid = /[0-9]/.test(modelData.student_grade);
                                if (!isValid)
                                    return "-";
                                else
                                    return (modelData.student_grade || "0") + "/" + (modelData.activity_grade || "0");
                            }
                            color: Colors.colOnLayer2
                            truncate: true
                            font.pixelSize: Fonts.sizes.normal
                            font.weight: 700
                            horizontalAlignment: Text.AlignRight
                            Layout.alignment: Qt.AlignVCenter | Qt.AlignRight
                        }
                    }
                }
            }
        }
    }
}
