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

    property int currentPage: SyncthingService.data.currentPage
    readonly property bool immersiveMode: false
    readonly property var tabs: [
        { icon: "dashboard", name: "Overview" },
        { icon: "folder", name: "Folders" },
        { icon: "devices", name: "Devices" },
        { icon: "history", name: "History" },
    ]

    Component { id: overviewComp; OverviewPage {} }
    Component { id: foldersComp; FoldersPage {} }
    Component { id: devicesComp; DevicesPage {} }
    Component { id: historyComp; HistoryPage {} }
    readonly property var pageComps: [overviewComp, foldersComp, devicesComp, historyComp]

    function navigateTo(index) {
        pageStack.slideRight = index > currentPage;
        currentPage = index;
        SyncthingService.data.currentPage = index;
        pageStack.replace(pageComps[index]);
    }

    CLayout {
        anchors.fill: parent
        spacing: 0

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
            tabButtonList: root.tabs
            externalTrackedTab: root.currentPage
            onCurrentIndexChanged: root.navigateTo(currentIndex)
        }
    }

    Component.onCompleted: navigateTo(root.currentPage)
}
