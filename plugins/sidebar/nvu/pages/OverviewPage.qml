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
        anchors.margins: Padding.small
        spacing: 0

        PageHeader {
            title: "Overview"

            subTitle: {
                var s = LMSService.totalSubjects(LMSService.materials);
                var f = LMSService.totalItems(LMSService.materials);
                var g = LMSService.totalItems(LMSService.grades);
                var q = LMSService.totalItems(LMSService.questions);
                return s + " subjects  ·  " + f + " files  ·  " + g + " grades  ·  " + q + " questions";
            }
        }

        StyledFlickable {
            Layout.fillHeight: true
            Layout.fillWidth: true
            clip: true
            contentHeight: contentCol.implicitHeight + Padding.massive

            CLayout {
                id: contentCol
                width: parent.width
                spacing: Padding.large
                Layout.topMargin: Padding.normal

                RLayout {
                    spacing: Padding.small
                    Layout.fillWidth: true
                    StatCard {
                        icon: "book_2"
                        value: LMSService.totalSubjects(LMSService.materials)
                        label: "Subjects"
                        accentColor: Colors.colPrimary
                    }
                    StatCard {
                        icon: "description"
                        value: LMSService.totalItems(LMSService.materials)
                        label: "Materials"
                        accentColor: Colors.colPrimary
                    }
                }

                RLayout {
                    spacing: Padding.small
                    Layout.fillWidth: true
                    StatCard {
                        icon: "calendar_month"
                        value: LMSService.totalSubjects(LMSService.schedule)
                        label: "Schedule"
                        accentColor: Colors.colSecondary
                    }
                    StatCard {
                        icon: "grade"
                        value: LMSService.totalItems(LMSService.grades)
                        label: "Graded"
                        accentColor: Colors.colPrimary
                    }
                    StatCard {
                        icon: "quiz"
                        value: LMSService.totalItems(LMSService.questions)
                        label: "Questions"
                        accentColor: Colors.colSecondary
                    }
                }

                StyledRect {
                    enableBorders: true
                    color: Colors.colLayer1
                    radius: Rounding.verylarge
                    Layout.fillWidth: true
                    implicitHeight: quickCol.implicitHeight + Padding.veryhuge * 2

                    CLayout {
                        id: quickCol
                        anchors.fill: parent
                        anchors.margins: Padding.huge
                        spacing: Padding.normal

                        StyledText {
                            text: "Quick Actions"
                            font.pixelSize: Fonts.sizes.large
                            font.weight: 600
                            color: Colors.colOnLayer2
                        }

                        RLayout {
                            spacing: Padding.small
                            Layout.fillWidth: true
                            QuickBtn {
                                materialIcon: "refresh"
                                label: "Refresh All"
                                onClicked: LMSService.refreshAll()
                            }
                            QuickBtn {
                                materialIcon: "download"
                                label: "Download All"
                                onClicked: NoonUtils.toast("Coming soon", "download", "success")
                            }
                        }

                        RLayout {
                            spacing: Padding.small
                            Layout.fillWidth: true
                            QuickBtn {
                                materialIcon: "quiz"
                                label: "Questions"
                                onClicked: root.navigateTo(4)
                            }
                            QuickBtn {
                                materialIcon: "calendar_view_week"
                                label: "Schedule"
                                onClicked: root.navigateTo(2)
                            }
                        }
                    }
                }

                StyledRect {
                    visible: LMSService.refreshStatus.length > 0
                    enableBorders: true
                    color: Colors.colLayer1
                    radius: Rounding.large
                    Layout.fillWidth: true
                    implicitHeight: 44
                    StyledText {
                        anchors.centerIn: parent
                        text: LMSService.refreshStatus
                        color: Colors.colOnLayer2
                        font.pixelSize: Fonts.sizes.small
                        font.weight: 500
                    }
                }

                Item {
                    height: Padding.large
                    Layout.fillWidth: true
                }
            }
        }
    }

    component StatCard: StyledRect {
        property string icon
        property var value
        property string label
        property color accentColor

        enableBorders: true
        color: Colors.colLayer1
        radius: Rounding.verylarge
        implicitHeight: 96
        Layout.fillWidth: true

        CLayout {
            anchors.centerIn: parent
            spacing: Padding.tiny

            Symbol {
                text: parent.parent.icon
                color: accentColor
                font.pixelSize: 22
                Layout.alignment: Qt.AlignHCenter
            }
            StyledText {
                text: parent.parent.value
                color: Colors.colOnSurface
                font.pixelSize: Fonts.sizes.verylarge
                font.weight: 700
                Layout.alignment: Qt.AlignHCenter
            }
            StyledText {
                text: parent.parent.label
                color: Colors.colSubtext
                font.pixelSize: Fonts.sizes.small
                font.weight: 500
                Layout.alignment: Qt.AlignHCenter
            }
        }
    }

    component QuickBtn: GroupButton {
        property alias materialIcon: icon.icon
        property string label

        buttonRadius: Rounding.normal
        baseHeight: 52
        Layout.fillWidth: true

        contentItem: Column {
            spacing: Padding.tiny
            Symbol {
                id: icon
                text: parent.parent.materialIcon
                color: Colors.colOnLayer2
                font.pixelSize: 22
                anchors.horizontalCenter: parent.horizontalCenter
            }
            StyledText {
                text: parent.parent.label
                color: Colors.colSubtext
                font.pixelSize: Fonts.sizes.small
                font.weight: 500
                anchors.horizontalCenter: parent.horizontalCenter
            }
        }
    }
}
