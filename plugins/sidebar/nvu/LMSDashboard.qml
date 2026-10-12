import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import qs.common
import qs.common.widgets
import "pages"

StyledRect {
    id: root
    color: "transparent"
    radius: Rounding.verylarge

    property bool expanded
    property string searchQuery: ""
    property bool detached
    signal dismiss
    signal searchFocusRequested
    signal contentFocusRequested

    property int currentPage: LMSService.data.currentPage
    readonly property bool immersiveMode: pageStack.currentItem?.immersiveMode ?? false
    readonly property var tabs: [
        {
            icon: "dashboard",
            name: "Overview"
        },
        {
            icon: "folder",
            name: "Materials"
        },
        {
            icon: "calendar_month",
            name: "Schedule"
        },
        {
            icon: "grade",
            name: "Grades"
        },
        {
            icon: "quiz",
            name: "Questions"
        },
    ]

    Component {
        id: overviewComp
        OverviewPage {}
    }
    Component {
        id: materialsComp
        MaterialsPage {}
    }
    Component {
        id: scheduleComp
        SchedulePage {}
    }
    Component {
        id: gradesComp
        GradesPage {}
    }
    Component {
        id: questionsComp
        QuestionsPage {}
    }
    readonly property var pageComps: [overviewComp, materialsComp, scheduleComp, gradesComp, questionsComp]

    function navigateTo(index) {
        pageStack.slideRight = index > currentPage;
        currentPage = index;
        LMSService.data.currentPage = index;
        pageStack.replace(pageComps[index]);
    }

    CLayout {
        anchors.fill: parent
        spacing: 0

        StyledText {
            text: LMSService.refreshStatus
            visible: LMSService.refreshStatus.length > 0 && !root.immersiveMode
            color: LMSService.refreshing ? Colors.m3.m3tertiary : Colors.m3.m3success
            font.pixelSize: 11
            font.weight: 600
            Layout.leftMargin: Padding.huge
            Layout.bottomMargin: Padding.tiny
        }

        StackView {
            id: pageStack
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true

            property bool slideRight: true

            replaceEnter: Transition {
                NumberAnimation {
                    property: "x"
                    from: pageStack.slideRight ? pageStack.width : -pageStack.width
                    to: 0
                    duration: Animations.durations.large
                    easing.type: Easing.BezierSpline
                    easing.bezierCurve: Animations.curves.emphasizedDecel
                }
                NumberAnimation {
                    property: "opacity"
                    from: 0
                    to: 1
                    duration: Animations.durations.small
                }
            }
            replaceExit: Transition {
                NumberAnimation {
                    property: "x"
                    from: 0
                    to: pageStack.slideRight ? -pageStack.width * 0.15 : pageStack.width * 0.15
                    duration: Animations.durations.large
                    easing.type: Easing.BezierSpline
                    easing.bezierCurve: Animations.curves.emphasizedAccel
                }
                NumberAnimation {
                    property: "opacity"
                    from: 1
                    to: 0
                    duration: Animations.durations.small
                }
            }
        }

        PrimaryTabBar {
            visible: !root.immersiveMode
            tabButtonList: root.tabs
            externalTrackedTab: root.currentPage
            onCurrentIndexChanged: root.navigateTo(currentIndex)
        }
    }

    Component.onCompleted: navigateTo(root.currentPage)
}
