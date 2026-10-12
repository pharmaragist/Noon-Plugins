import QtQuick
import QtQuick.Layouts
import qs.common
import qs.common.widgets
import qs.common.utils
import qs.services

SidebarItemContainer {
    id: root

    readonly property var svc: VirtManagerService

    function actionForVM(vm) {
        if (svc.isRunning(vm.state))
            return {
                icon: "power_settings_new",
                action: () => svc.shutdownVM(vm.name)
            };
        if (svc.isStopped(vm.state))
            return {
                icon: "play_arrow",
                action: () => svc.startVM(vm.name)
            };
        return {
            icon: "help",
            action: () => {}
        };
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: Padding.normal
        spacing: Padding.huge

        PageHeader {
            title: "Virtual Machines"
            subTitle: svc.loading ? "..." : svc.runningCount() + " / " + svc.vms.length

            RippleButtonWithIcon {
                implicitSize: 55
                buttonRadius: Rounding.full
                colBackground: "transparent"
                releaseAction: () => svc.refresh()
                materialIcon: "refresh"
            }
        }

        Item {
            Layout.fillWidth: true
            Layout.fillHeight: true

            StyledListView {
                id: vmList
                anchors.fill: parent
                visible: !svc.errorMessage

                _model: {
                    var q = root.searchQuery.toLowerCase().trim();
                    var src = svc.vms;
                    if (!q)
                        return src;
                    var out = [];
                    for (var i = 0; i < src.length; i++)
                        if (src[i].name.toLowerCase().indexOf(q) !== -1)
                            out.push(src[i]);
                    return out;
                }

                delegate: StyledRect {
                    required property var modelData
                    required property int index

                    anchors.left: parent?.left
                    anchors.right: parent?.right

                    implicitHeight: 64
                    color: Colors.colLayer2
                    topRadius: index === 0 ? Rounding.huge : Rounding.tiny
                    bottomRadius: index === vmList.count - 1 ? Rounding.huge : Rounding.tiny

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: Padding.huge
                        anchors.rightMargin: Padding.huge
                        spacing: Padding.huge

                        Symbol {
                            icon: svc.stateIcon(modelData.state)
                            iconSize: 24
                            color: svc.stateColor(modelData.state)
                            Layout.alignment: Qt.AlignVCenter
                        }

                        ColumnLayout {
                            Layout.fillWidth: true
                            Layout.alignment: Qt.AlignLeft | Qt.AlignVCenter
                            spacing: 0

                            StyledText {
                                text: modelData.name
                                Layout.fillWidth: true
                                horizontalAlignment: Text.AlignLeft
                                font: Fonts.request("title", "normal")
                                color: Colors.colOnSurface
                                truncate: true
                            }

                            StyledText {
                                text: modelData.state + (modelData.isActive ? " (ID: " + modelData.id + ")" : "")
                                font.pixelSize: Fonts.sizes.verysmall
                                color: Colors.m3.m3onSurfaceVariant
                                Layout.fillWidth: true
                                horizontalAlignment: Text.AlignLeft
                            }
                        }

                        RippleButtonWithIcon {
                            id: actBtn
                            implicitWidth: 32
                            implicitHeight: 32
                            buttonRadius: Rounding.full
                            colBackground: Colors.colLayer3
                            materialIcon: actBtn.a.icon

                            readonly property var a: root.actionForVM(modelData)
                            releaseAction: a.action
                        }
                    }
                }

                PagePlaceholder {
                    shown: vmList._model.length === 0 && !svc.loading && !svc.errorMessage
                    anchors.centerIn: parent
                    icon: "desktop_windows"
                    title: root.searchQuery ? "No matching VMs" : "No virtual machines"
                }
            }

            ColumnLayout {
                anchors.centerIn: parent
                visible: !!svc.errorMessage && !svc.loading
                spacing: Padding.small

                Symbol {
                    Layout.alignment: Qt.AlignHCenter
                    icon: "error_outline"
                    iconSize: 32
                    color: Colors.colError
                }

                StyledText {
                    Layout.alignment: Qt.AlignHCenter
                    Layout.maximumWidth: 250
                    text: svc.errorMessage
                    font.pixelSize: Fonts.sizes.small
                    color: Colors.colError
                    horizontalAlignment: Text.AlignHCenter
                    wrapMode: Text.WordWrap
                }

                RippleButton {
                    Layout.alignment: Qt.AlignHCenter
                    buttonText: "Retry"
                    buttonRadius: Rounding.medium
                    releaseAction: () => svc.refresh()
                }
            }

            StyledText {
                anchors.centerIn: parent
                visible: svc.loading && !svc.errorMessage
                text: "Loading..."
                font.pixelSize: Fonts.sizes.normal
                color: Colors.m3.m3onSurfaceVariant
            }
        }
    }

    Component.onCompleted: {
        if (svc.vms.length === 0 && !svc.loading)
            svc.refresh();
    }
}
