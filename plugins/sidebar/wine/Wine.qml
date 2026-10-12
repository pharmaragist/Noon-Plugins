import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import qs.common
import qs.common.widgets
import qs.services
import "pages"

Item {
    id: root
    clip: true
    property bool expanded
    property string searchQuery: ""
    signal dismiss
    signal searchFocusRequested
    signal contentFocusRequested

    property int currentPage: 0
    readonly property var tabs: [
        {
            icon: "checklist",
            name: "Installed"
        },
        {
            icon: "cloud_download",
            name: "Browse"
        },
        {
            icon: "stadia_controller",
            name: "Apps"
        },
        {
            icon: "tune",
            name: "Config"
        },
    ]

    Component {
        id: installedComp
        InstalledTab {}
    }
    Component {
        id: browseComp
        BrowseTab {}
    }
    Component {
        id: appsComp
        AppsTab {}
    }
    Component {
        id: configComp
        ConfigTab {}
    }
    readonly property var pageComps: [installedComp, browseComp, appsComp, configComp]

    function navigateTo(index) {
        currentPage = index;
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
        }

        PrimaryTabBar {
            tabButtonList: root.tabs
            externalTrackedTab: root.currentPage
            onCurrentIndexChanged: root.navigateTo(currentIndex)
        }
    }

    Component.onCompleted: navigateTo(root.currentPage)

    BottomDialog {
        id: cfgDialog
        property string appId: ""
        property var cfg: ({})
        collapsedHeight: 400
        expandedHeight: 400
        show: false
        onShowChanged: {
            if (show) {
                runnerCombo.currentIndex = cfg?.runner ? Math.max(0, runnerCombo.find(cfg.runner)) : 0;
                dxvkSwitch.checked = cfg?.dxvk ?? false;
                vkd3dSwitch.checked = cfg?.vkd3d ?? false;
                gamemodeSwitch.checked = cfg?.gamemode ?? false;
            }
        }

        contentItem: ColumnLayout {
            spacing: Padding.verylarge
            anchors.fill: parent
            anchors.margins: Padding.large

            PageHeader {
                title: cfgDialog.appId || "Configure App"
                subTitle: "Per-app runner configuration"
                target: cfgDialog
            }

            ContentSubsection {
                title: "Runner"
                RowLayout {
                    Layout.fillWidth: true
                    StyledText {
                        text: "Override default runner"
                        Layout.fillWidth: true
                        color: Colors.colOnLayer1
                    }
                    StyledComboBox {
                        id: runnerCombo
                        model: ["System default", "Proton Experimental", "Proton 9.0", "Proton 8.0", "Wine-GE 8.25"]
                    }
                }
            }

            ContentSubsection {
                title: "Options"
                RowLayout {
                    Layout.fillWidth: true
                    StyledText {
                        text: "DXVK"
                        Layout.fillWidth: true
                        color: Colors.colOnLayer1
                    }
                    StyledSwitch {
                        id: dxvkSwitch
                    }
                }
                RowLayout {
                    Layout.fillWidth: true
                    StyledText {
                        text: "VKD3D"
                        Layout.fillWidth: true
                        color: Colors.colOnLayer1
                    }
                    StyledSwitch {
                        id: vkd3dSwitch
                    }
                }
                RowLayout {
                    Layout.fillWidth: true
                    StyledText {
                        text: "Feral Gamemode"
                        Layout.fillWidth: true
                        color: Colors.colOnLayer1
                    }
                    StyledSwitch {
                        id: gamemodeSwitch
                    }
                }
            }

            DialogButton {
                Layout.alignment: Qt.AlignRight
                text: "Save"
                onClicked: {
                    WineManagerService.setAppConfig(cfgDialog.appId, {
                        runner: runnerCombo.currentIndex > 0 ? runnerCombo.currentText : "",
                        dxvk: dxvkSwitch.checked,
                        vkd3d: vkd3dSwitch.checked,
                        gamemode: gamemodeSwitch.checked
                    });
                    cfgDialog.show = false;
                }
            }
        }
    }
}
